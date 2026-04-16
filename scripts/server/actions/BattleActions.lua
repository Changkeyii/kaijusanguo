-- ============================================================================
-- server/actions/BattleActions.lua
-- 战斗结算 + 广告奖励 Actions（服务端权威）
-- ============================================================================
local Protocol = require("network.Protocol")
local PlayerDataManager = require("server.PlayerDataManager")
local GameActions       = require("server.GameActions")

local CODE = Protocol.CODE
local CK   = Protocol.CLOUD_KEYS

-- ============================================================================
-- 战斗结算配置（与 game_config.lua 保持一致）
-- ============================================================================
local BATTLE_CONFIG = {
    JADE_PER_WIN_MIN  = 50,
    JADE_PER_WIN_MAX  = 80,
    JADE_PER_LOSE     = 3,
    EXP_PER_WIN       = 30,
    EXP_PER_LOSE      = 10,
    AD_REVIVE_BONUS   = 20,
    AD_JADE_REWARD    = 2000,
    MAX_EQUIP_TIER    = 6,
    MAX_AD_PER_TYPE   = 20,
}

-- ============================================================================
-- battle_settle: 战斗结算（胜利/失败/超时）
-- 客户端发送战斗结果摘要，服务端验证并发放奖励
-- ============================================================================
GameActions.Register("battle_settle", {
    rateLimit  = { interval = 2, burst = 3 },
    needDomains = { "core", "equip", "skills", "progress" },
    handler = function(userId, params, replyFn)
        local result    = params.result      -- "win" / "lose" / "draw"
        local stageId   = tonumber(params.stageId) or 0
        local battleTime = tonumber(params.battleTime) or 0

        if not result or (result ~= "win" and result ~= "lose" and result ~= "draw") then
            replyFn(false, CODE.ERR_PARAMS, nil, "无效战斗结果")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 验证战斗时间合理性（0-200秒）
        if battleTime < 0 or battleTime > 200 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "战斗时间异常")
            return
        end

        local rewardJade = 0
        local rewardExp  = 0

        if result == "win" then
            -- 胜利奖励：随机虎符 + 固定经验
            rewardJade = math.random(BATTLE_CONFIG.JADE_PER_WIN_MIN, BATTLE_CONFIG.JADE_PER_WIN_MAX)
            rewardExp  = BATTLE_CONFIG.EXP_PER_WIN
        else
            -- 失败/平局奖励
            rewardJade = BATTLE_CONFIG.JADE_PER_LOSE
            rewardExp  = BATTLE_CONFIG.EXP_PER_LOSE
        end

        -- 发放货币（修改缓存 + 同步到 core domain）
        cache.money.jade = (cache.money.jade or 0) + rewardJade

        -- 发放经验到 core domain，同时同步 jade
        local coreDomain = cache.domains.core
        if coreDomain and coreDomain.playerInfo then
            coreDomain.playerInfo.exp = (coreDomain.playerInfo.exp or 0) + rewardExp
            coreDomain.playerInfo.jade = cache.money.jade
            PlayerDataManager.SetDomain(userId, "core", coreDomain) -- 自动 dirty
        end

        -- 更新关卡进度
        if result == "win" and stageId > 0 then
            local progressDomain = cache.domains.progress or {}
            local maxStage = progressDomain.maxStage or 0
            if stageId >= maxStage then
                progressDomain.maxStage = stageId + 1
                PlayerDataManager.SetDomain(userId, "progress", progressDomain) -- 自动 dirty
            end
        end

        -- 记录日志
        PlayerDataManager.LogOp(userId, "battle_settle", {
            result = result, stage = stageId,
            jade = rewardJade, exp = rewardExp,
        })

        replyFn(true, CODE.OK, {
            jade     = rewardJade,
            exp      = rewardExp,
            totalJade = cache.money.jade,
        })
    end,
})

-- ============================================================================
-- report_score: 上报排行榜分数（服务端验证后写 serverCloud）
-- ============================================================================
GameActions.Register("report_score", {
    rateLimit  = { interval = 3, burst = 5 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local scoreType = params.scoreType   -- "combat_power" / "realm_level" / "tower_floor" / "dummy_damage" / "ranked_score"
        local scoreVal  = tonumber(params.value)

        if not scoreType or not scoreVal then
            replyFn(false, CODE.ERR_PARAMS, nil, "缺少分数类型或值")
            return
        end

        -- 分数类型 → serverCloud key 映射
        local keyMap = {
            combat_power = CK.COMBAT_POWER,
            realm_level  = CK.REALM_LEVEL,
            tower_floor  = CK.TOWER_FLOOR,
            dummy_damage = CK.DUMMY_DAMAGE,
            ranked_score = CK.RANKED_ELO,
        }

        local cloudKey = keyMap[scoreType]
        if not cloudKey then
            replyFn(false, CODE.ERR_PARAMS, nil, "未知排行榜类型: " .. tostring(scoreType))
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 基础验证：分数范围
        if scoreVal < 0 or scoreVal > 999999999 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "分数超出合理范围")
            return
        end

        -- 特定类型验证
        if scoreType == "realm_level" then
            local coreDomain = cache.domains.core
            local actualRank = coreDomain and coreDomain.playerInfo
                and coreDomain.playerInfo.rankIdx or 1
            if scoreVal > actualRank + 1 then
                replyFn(false, CODE.ERR_VALIDATE, nil, "境界等级异常")
                return
            end
        elseif scoreType == "tower_floor" then
            local progressDomain = cache.domains.progress or {}
            local maxTower = progressDomain.towerMaxFloor or 0
            if scoreVal > maxTower + 5 then
                replyFn(false, CODE.ERR_VALIDATE, nil, "爬塔层数异常")
                return
            end
        end

        -- 写 serverCloud 排行榜
        if rawget(_G, "serverCloud") then
            serverCloud:SetInt(userId, cloudKey, scoreVal, {
                ok = function()
                    print("[BattleActions] report_score OK: " .. scoreType
                        .. "=" .. scoreVal .. " user=" .. tostring(userId))

                    -- 附带上报额外字段（战力榜需要技能数/武灵数）
                    if scoreType == "combat_power" then
                        local skillCount = tonumber(params.skillCount) or 0
                        local heroCount  = tonumber(params.heroCount) or 0
                        serverCloud:SetInt(userId, "slg_skill_count", skillCount, {})
                        serverCloud:SetInt(userId, "slg_hero_count", heroCount, {})
                    end
                end,
                error = function(err)
                    print("[BattleActions] report_score FAIL: " .. tostring(err))
                end,
            })
        end

        replyFn(true, CODE.OK, { scoreType = scoreType, value = scoreVal })
    end,
})

-- ============================================================================
-- report_ad_watch: 上报广告观看（服务端写排行榜 + quota）
-- ============================================================================
GameActions.Register("report_ad_watch", {
    rateLimit  = { interval = 5, burst = 3 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local adType = params.adType or "general"

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 每日限制
        cache._adCounts = cache._adCounts or {}
        local today = os.date("%Y%m%d")
        cache._adCounts[today] = cache._adCounts[today] or {}
        local todayCount = cache._adCounts[today][adType] or 0

        if todayCount >= BATTLE_CONFIG.MAX_AD_PER_TYPE then
            replyFn(false, CODE.ERR_RATE_LIMIT, nil, "今日广告次数已用完")
            return
        end

        cache._adCounts[today][adType] = todayCount + 1

        -- 写 serverCloud 广告贡献榜
        if rawget(_G, "serverCloud") then
            serverCloud:Add(userId, CK.AD_WATCH, 1, {
                ok = function()
                    print("[BattleActions] ad_watch +1 user=" .. tostring(userId))
                end,
                error = function(err)
                    print("[BattleActions] ad_watch FAIL: " .. tostring(err))
                end,
            })
        end

        replyFn(true, CODE.OK, {
            adType = adType,
            todayCount = cache._adCounts[today][adType],
        })
    end,
})

print("[BattleActions] 已注册: battle_settle, report_score, report_ad_watch")
return true
