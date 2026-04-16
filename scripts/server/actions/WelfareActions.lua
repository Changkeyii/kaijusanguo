-- ============================================================================
-- server/actions/WelfareActions.lua
-- 福利系统 Actions（服务端权威）
-- 签到、转盘、翻牌、在线奖励、每日/周任务全勤奖、战令领取
-- ============================================================================
local Protocol = require("network.Protocol")
local PlayerDataManager = require("server.PlayerDataManager")
local GameActions       = require("server.GameActions")

local CODE = Protocol.CODE

-- ============================================================================
-- claim_signin: 签到领取（三日签到 / 十日签到）
-- ============================================================================
GameActions.Register("claim_signin", {
    rateLimit  = { interval = 1, burst = 5 },
    needDomains = { "core", "welfare" },
    handler = function(userId, params, replyFn)
        local signinType = params.signinType   -- "three_day" / "ten_day"
        local day        = tonumber(params.day) -- 第几天

        if not signinType or not day or day < 1 then
            replyFn(false, CODE.ERR_PARAMS, nil, "参数缺失")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        local welfareDomain = cache.domains.welfare or {}

        -- 获取签到状态
        local stateKey = signinType == "three_day" and "signInClaimed" or "dailySignInClaimed"
        local claimedList = welfareDomain[stateKey] or {}

        -- 检查是否已领取
        if claimedList[day] or claimedList[tostring(day)] then
            replyFn(false, CODE.ERR_DUPLICATE, nil, "已领取第" .. day .. "天奖励")
            return
        end

        -- 验证天数顺序（必须按顺序签到）
        if signinType == "three_day" and day > 3 then
            replyFn(false, CODE.ERR_PARAMS, nil, "三日签到最多3天")
            return
        end
        if signinType == "ten_day" and day > 10 then
            replyFn(false, CODE.ERR_PARAMS, nil, "十日签到最多10天")
            return
        end

        -- 标记已领取
        claimedList[day] = true
        welfareDomain[stateKey] = claimedList
        PlayerDataManager.SetDomain(userId, "welfare", welfareDomain)

        -- 奖励由客户端本地发放（jade 等），服务端只做验证和状态记录
        PlayerDataManager.LogOp(userId, "claim_signin", {
            type = signinType, day = day,
        })

        replyFn(true, CODE.OK, { signinType = signinType, day = day })
    end,
})

-- ============================================================================
-- claim_task_reward: 领取每日/周任务奖励
-- ============================================================================
GameActions.Register("claim_task_reward", {
    rateLimit  = { interval = 0.5, burst = 10 },
    needDomains = { "core", "welfare" },
    handler = function(userId, params, replyFn)
        local taskType = params.taskType      -- "daily" / "weekly" / "daily_all" / "weekly_all"
        local taskId   = params.taskId        -- 任务ID（all 类型不需要）
        local jadeReward = tonumber(params.jade) or 0
        local lingshiReward = tonumber(params.lingshi) or 0

        if not taskType then
            replyFn(false, CODE.ERR_PARAMS, nil, "缺少任务类型")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 全勤奖励上限验证
        if taskType == "daily_all" and jadeReward > 500 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "每日全勤奖励异常")
            return
        end
        if taskType == "weekly_all" and jadeReward > 1300 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "每周全勤奖励异常")
            return
        end

        -- 发放货币
        if jadeReward > 0 then
            cache.money.jade = (cache.money.jade or 0) + jadeReward
            local coreDomain = cache.domains.core
            if coreDomain and coreDomain.playerInfo then
                coreDomain.playerInfo.jade = cache.money.jade
                PlayerDataManager.SetDomain(userId, "core", coreDomain)
            end
        end
        if lingshiReward > 0 then
            cache.money.lingshi = (cache.money.lingshi or 0) + lingshiReward
            local coreDomain = cache.domains.core
            if coreDomain and coreDomain.playerInfo then
                coreDomain.playerInfo.lingshi = cache.money.lingshi
                PlayerDataManager.SetDomain(userId, "core", coreDomain)
            end
        end

        PlayerDataManager.LogOp(userId, "claim_task_reward", {
            taskType = taskType, taskId = taskId,
            jade = jadeReward, lingshi = lingshiReward,
        })

        replyFn(true, CODE.OK, {
            jade = cache.money.jade,
            lingshi = cache.money.lingshi,
        })
    end,
})

-- ============================================================================
-- spin_wheel: 转盘抽奖（服务端生成随机结果）
-- ============================================================================
GameActions.Register("spin_wheel", {
    rateLimit  = { interval = 3, burst = 2 },
    needDomains = { "core", "welfare" },
    handler = function(userId, params, replyFn)
        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        local welfareDomain = cache.domains.welfare or {}
        local spinState = welfareDomain.spinWheel or {}

        -- 每日次数限制
        local today = os.date("%Y%m%d")
        if spinState.lastDate ~= today then
            spinState.lastDate = today
            spinState.count = 0
        end

        local maxSpins = 5
        if (spinState.count or 0) >= maxSpins then
            replyFn(false, CODE.ERR_RATE_LIMIT, nil, "今日转盘次数已用完")
            return
        end

        -- 服务端生成随机结果（8个扇区）
        local sectorCount = 8
        local resultIdx = math.random(1, sectorCount)

        -- 转盘奖励表（与客户端一致）
        local SPIN_REWARDS = {
            { type = "jade", amount = 100 },
            { type = "jade", amount = 200 },
            { type = "jade", amount = 500 },
            { type = "lingshi", amount = 50 },
            { type = "lingshi", amount = 100 },
            { type = "jade", amount = 50 },
            { type = "jade", amount = 1000 },
            { type = "lingshi", amount = 200 },
        }

        local reward = SPIN_REWARDS[resultIdx]

        -- 发放奖励
        if reward.type == "jade" then
            cache.money.jade = (cache.money.jade or 0) + reward.amount
            local coreDomain = cache.domains.core
            if coreDomain and coreDomain.playerInfo then
                coreDomain.playerInfo.jade = cache.money.jade
                PlayerDataManager.SetDomain(userId, "core", coreDomain)
            end
        elseif reward.type == "lingshi" then
            cache.money.lingshi = (cache.money.lingshi or 0) + reward.amount
            local coreDomain = cache.domains.core
            if coreDomain and coreDomain.playerInfo then
                coreDomain.playerInfo.lingshi = cache.money.lingshi
                PlayerDataManager.SetDomain(userId, "core", coreDomain)
            end
        end

        spinState.count = (spinState.count or 0) + 1
        welfareDomain.spinWheel = spinState
        PlayerDataManager.SetDomain(userId, "welfare", welfareDomain)

        PlayerDataManager.LogOp(userId, "spin_wheel", {
            sector = resultIdx, reward = reward,
        })

        replyFn(true, CODE.OK, {
            resultIdx  = resultIdx,
            rewardType = reward.type,
            amount     = reward.amount,
            spinsLeft  = maxSpins - spinState.count,
        })
    end,
})

-- ============================================================================
-- card_flip: 翻牌抽奖（服务端生成随机结果）
-- ============================================================================
GameActions.Register("card_flip", {
    rateLimit  = { interval = 2, burst = 3 },
    needDomains = { "core", "welfare" },
    handler = function(userId, params, replyFn)
        local cardIdx = tonumber(params.cardIdx)

        if not cardIdx or cardIdx < 1 or cardIdx > 9 then
            replyFn(false, CODE.ERR_PARAMS, nil, "无效卡牌索引")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        local welfareDomain = cache.domains.welfare or {}
        local flipState = welfareDomain.cardFlip or {}

        -- 每日重置
        local today = os.date("%Y%m%d")
        if flipState.lastDate ~= today then
            flipState.lastDate = today
            flipState.flipped = {}
            flipState.count = 0
        end

        -- 检查已翻
        if flipState.flipped and flipState.flipped[cardIdx] then
            replyFn(false, CODE.ERR_DUPLICATE, nil, "该卡牌已翻开")
            return
        end

        local maxFlips = 3
        if (flipState.count or 0) >= maxFlips then
            replyFn(false, CODE.ERR_RATE_LIMIT, nil, "今日翻牌次数已用完")
            return
        end

        -- 服务端生成奖励
        local jadeReward = math.random(50, 300)

        cache.money.jade = (cache.money.jade or 0) + jadeReward
        local coreDomain = cache.domains.core
        if coreDomain and coreDomain.playerInfo then
            coreDomain.playerInfo.jade = cache.money.jade
            PlayerDataManager.SetDomain(userId, "core", coreDomain)
        end

        flipState.flipped = flipState.flipped or {}
        flipState.flipped[cardIdx] = true
        flipState.count = (flipState.count or 0) + 1
        welfareDomain.cardFlip = flipState
        PlayerDataManager.SetDomain(userId, "welfare", welfareDomain)

        PlayerDataManager.LogOp(userId, "card_flip", {
            card = cardIdx, jade = jadeReward,
        })

        replyFn(true, CODE.OK, {
            cardIdx   = cardIdx,
            jade      = jadeReward,
            totalJade = cache.money.jade,
            flipsLeft = maxFlips - flipState.count,
        })
    end,
})

-- ============================================================================
-- claim_online_reward: 在线时长奖励
-- ============================================================================
GameActions.Register("claim_online_reward", {
    rateLimit  = { interval = 1, burst = 5 },
    needDomains = { "core", "welfare" },
    handler = function(userId, params, replyFn)
        local tier = tonumber(params.tier)  -- 奖励档位
        local jadeReward = tonumber(params.jade) or 0

        if not tier or tier < 1 then
            replyFn(false, CODE.ERR_PARAMS, nil, "无效档位")
            return
        end

        if jadeReward > 2000 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "在线奖励金额异常")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        local welfareDomain = cache.domains.welfare or {}
        local onlineRewards = welfareDomain.onlineRewards or {}

        if onlineRewards[tier] or onlineRewards[tostring(tier)] then
            replyFn(false, CODE.ERR_DUPLICATE, nil, "已领取该档位奖励")
            return
        end

        -- 发放
        if jadeReward > 0 then
            cache.money.jade = (cache.money.jade or 0) + jadeReward
            local coreDomain = cache.domains.core
            if coreDomain and coreDomain.playerInfo then
                coreDomain.playerInfo.jade = cache.money.jade
                PlayerDataManager.SetDomain(userId, "core", coreDomain)
            end
        end

        onlineRewards[tier] = true
        welfareDomain.onlineRewards = onlineRewards
        PlayerDataManager.SetDomain(userId, "welfare", welfareDomain)

        PlayerDataManager.LogOp(userId, "claim_online_reward", {
            tier = tier, jade = jadeReward,
        })

        replyFn(true, CODE.OK, {
            tier = tier,
            jade = cache.money.jade,
        })
    end,
})

print("[WelfareActions] 已注册: claim_signin, claim_task_reward, spin_wheel, card_flip, claim_online_reward")
return true
