-- ============================================================================
-- server/actions/SocialActions.lua
-- 社交系统 Actions（服务端权威）
-- 阵营捐献、签到、公开档案上报等涉及货币/排行的操作
-- ============================================================================
local Protocol = require("network.Protocol")
local PlayerDataManager = require("server.PlayerDataManager")
local GameActions       = require("server.GameActions")

local CODE = Protocol.CODE
local CK   = Protocol.CLOUD_KEYS

-- ============================================================================
-- faction_donate: 阵营捐献虎符（服务端验证扣款 + 上报排行）
-- 阵营元数据(camp_meta)仍由客户端写 clientCloud（多人共享数据）
-- 服务端负责：验证虎符余额、扣款、上报阵营等级排行
-- ============================================================================
GameActions.Register("faction_donate", {
    rateLimit  = { interval = 2, burst = 3 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local amount    = tonumber(params.amount) or 0
        local rankScore = tonumber(params.rankScore) or 0

        if amount <= 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "捐献金额无效")
            return
        end

        -- 每日捐献上限
        if amount > 50000 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "单次捐献上限50000")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 验证余额
        local currentJade = cache.money.jade or 0
        if currentJade < amount then
            replyFn(false, CODE.ERR_INSUFFICIENT, nil,
                "虎符不足: 需要" .. amount .. " 当前" .. currentJade)
            return
        end

        -- 扣款
        cache.money.jade = currentJade - amount
        local coreDomain = cache.domains.core
        if coreDomain and coreDomain.playerInfo then
            coreDomain.playerInfo.jade = cache.money.jade
            PlayerDataManager.SetDomain(userId, "core", coreDomain)
        end

        -- 上报阵营等级排行（如果提供了分数）
        if rankScore > 0 and rawget(_G, "serverCloud") then
            serverCloud:SetInt(userId, "p_49dd_faction_level", rankScore, {
                ok = function()
                    print("[SocialActions] faction_level 排行已更新: " .. rankScore)
                end,
                error = function(err)
                    print("[SocialActions] faction_level 上报失败: " .. tostring(err))
                end,
            })
        end

        PlayerDataManager.LogOp(userId, "faction_donate", {
            amount = amount, after = cache.money.jade,
        })

        replyFn(true, CODE.OK, {
            jade = cache.money.jade,
            donated = amount,
        })
    end,
})

-- ============================================================================
-- publish_profile: 发布公开档案（服务端验证 + 写排行榜）
-- 客户端请求发布公开资料时，服务端验证战力等数据并写 serverCloud
-- ============================================================================
GameActions.Register("publish_profile", {
    rateLimit  = { interval = 5, burst = 2 },
    needDomains = { "core", "heroes" },
    handler = function(userId, params, replyFn)
        local power      = tonumber(params.power) or 0
        local realmLevel  = tonumber(params.realmLevel) or 0
        local skillCount  = tonumber(params.skillCount) or 0
        local heroCount   = tonumber(params.heroCount) or 0

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 基础验证
        if power < 0 or power > 999999999 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "战力数据异常")
            return
        end

        -- 写 serverCloud 排行榜
        if rawget(_G, "serverCloud") then
            local batch = serverCloud:BatchCommit("publish_profile")
            if power > 0 then
                batch:SetInt(userId, CK.COMBAT_POWER, power)
            end
            if realmLevel > 0 then
                batch:SetInt(userId, CK.REALM_LEVEL, realmLevel)
            end
            batch:Commit({
                ok = function()
                    print("[SocialActions] profile published for " .. tostring(userId))
                end,
                error = function(err)
                    print("[SocialActions] profile publish failed: " .. tostring(err))
                end,
            })
        end

        replyFn(true, CODE.OK, { power = power })
    end,
})

-- ============================================================================
-- faction_signin: 阵营签到（服务端记录 + 上报排行）
-- 签到不扣货币，但需要服务端记录防重复 + 上报排行
-- ============================================================================
GameActions.Register("faction_signin", {
    rateLimit  = { interval = 5, burst = 2 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local rankScore = tonumber(params.rankScore) or 0

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 上报阵营等级排行
        if rankScore > 0 and rawget(_G, "serverCloud") then
            serverCloud:SetInt(userId, "p_49dd_faction_level", rankScore, {
                ok = function()
                    print("[SocialActions] faction_signin 排行已更新: " .. rankScore)
                end,
                error = function(err)
                    print("[SocialActions] faction_signin 上报失败: " .. tostring(err))
                end,
            })
        end

        PlayerDataManager.LogOp(userId, "faction_signin", {})

        replyFn(true, CODE.OK, { ok = true })
    end,
})

-- ============================================================================
-- faction_create: 创建阵营（服务端验证扣款 5000 虎符）
-- 阵营元数据(camp_meta)由客户端写 clientCloud（多人共享数据）
-- 服务端负责：验证虎符余额、扣款
-- ============================================================================
GameActions.Register("faction_create", {
    rateLimit  = { interval = 10, burst = 1 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local CAMP_CREATE_COST = 5000

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 验证余额
        local currentJade = cache.money.jade or 0
        if currentJade < CAMP_CREATE_COST then
            replyFn(false, CODE.ERR_INSUFFICIENT, nil,
                "虎符不足: 需要" .. CAMP_CREATE_COST .. " 当前" .. currentJade)
            return
        end

        -- 扣款
        cache.money.jade = currentJade - CAMP_CREATE_COST
        local coreDomain = cache.domains.core
        if coreDomain and coreDomain.playerInfo then
            coreDomain.playerInfo.jade = cache.money.jade
            PlayerDataManager.SetDomain(userId, "core", coreDomain)
        end

        PlayerDataManager.LogOp(userId, "faction_create", {
            cost = CAMP_CREATE_COST, after = cache.money.jade,
        })

        replyFn(true, CODE.OK, {
            jade = cache.money.jade,
            cost = CAMP_CREATE_COST,
        })
    end,
})

print("[SocialActions] 已注册: faction_donate, publish_profile, faction_signin, faction_create")
return true
