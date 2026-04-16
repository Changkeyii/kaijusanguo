-- ============================================================================
-- CurrencyActions.lua - 服务端货币验证 Actions
-- 职责：所有关键货币消费必须经过服务端验证
-- 操作：spend_jade, spend_lingshi, grant_rewards, ad_reward
-- ============================================================================

local Protocol = require("network.Protocol")
local CODE = Protocol.CODE
local GameActions = require("server.GameActions")
local PlayerDataManager = require("server.PlayerDataManager")

-- ============================================================================
-- 花费虎符（jade）
-- 场景：改名、入场费、购买、深渊门票等
-- ============================================================================
GameActions.Register("spend_jade", {
    rateLimit = { maxCount = 10, windowSec = 1 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local amount = tonumber(params.amount)
        local reason = params.reason or "unknown"

        -- 验证参数
        if not amount or amount <= 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "无效的消费金额")
            return
        end

        -- 金额上限校验（单次消费不超过 100000）
        if amount > 100000 then
            replyFn(false, CODE.ERR_PARAMS, nil, "单次消费金额过大")
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

        -- 同步到 core domain 的 playerInfo
        if cache.domains.core and cache.domains.core.playerInfo then
            cache.domains.core.playerInfo.jade = cache.money.jade
        end

        cache.dirty.core = true
        PlayerDataManager.LogOp(userId, "spend_jade",
            { amount = amount, reason = reason, after = cache.money.jade })

        -- 推送货币更新
        replyFn(true, nil, { jade = cache.money.jade })
    end,
})

-- ============================================================================
-- 花费军资（lingshi）
-- 场景：装备强化
-- ============================================================================
GameActions.Register("spend_lingshi", {
    rateLimit = { maxCount = 10, windowSec = 1 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local amount = tonumber(params.amount)
        local reason = params.reason or "unknown"

        if not amount or amount <= 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "无效的消费金额")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        local currentLingshi = cache.money.lingshi or 0
        if currentLingshi < amount then
            replyFn(false, CODE.ERR_INSUFFICIENT, nil,
                "军资不足: 需要" .. amount .. " 当前" .. currentLingshi)
            return
        end

        cache.money.lingshi = currentLingshi - amount

        if cache.domains.core and cache.domains.core.playerInfo then
            cache.domains.core.playerInfo.lingshi = cache.money.lingshi
        end

        cache.dirty.core = true
        PlayerDataManager.LogOp(userId, "spend_lingshi",
            { amount = amount, reason = reason, after = cache.money.lingshi })

        replyFn(true, nil, { lingshi = cache.money.lingshi })
    end,
})

-- ============================================================================
-- 发放奖励（服务端验证版）
-- 场景：战斗胜利、任务完成、签到等 —— 由服务端计算并发放
-- ============================================================================
GameActions.Register("grant_rewards", {
    rateLimit = { maxCount = 5, windowSec = 1 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local rewards = params.rewards -- { jade=N, lingshi=N, exp=N }
        local reason = params.reason or "unknown"

        if not rewards or type(rewards) ~= "table" then
            replyFn(false, CODE.ERR_PARAMS, nil, "无效的奖励数据")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 验证奖励合法性（防止客户端伪造过大的奖励）
        local jadeGrant = tonumber(rewards.jade) or 0
        local lingshiGrant = tonumber(rewards.lingshi) or 0
        local expGrant = tonumber(rewards.exp) or 0

        -- 单次奖励上限
        if jadeGrant > 50000 or lingshiGrant > 100000 or expGrant > 100000 then
            replyFn(false, CODE.ERR_PARAMS, nil, "奖励数值异常")
            PlayerDataManager.LogOp(userId, "grant_rewards_rejected",
                { rewards = rewards, reason = reason })
            return
        end

        -- 负值保护
        if jadeGrant < 0 or lingshiGrant < 0 or expGrant < 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "奖励不能为负")
            return
        end

        -- 发放
        if jadeGrant > 0 then
            cache.money.jade = (cache.money.jade or 0) + jadeGrant
            if cache.domains.core and cache.domains.core.playerInfo then
                cache.domains.core.playerInfo.jade = cache.money.jade
            end
        end
        if lingshiGrant > 0 then
            cache.money.lingshi = (cache.money.lingshi or 0) + lingshiGrant
            if cache.domains.core and cache.domains.core.playerInfo then
                cache.domains.core.playerInfo.lingshi = cache.money.lingshi
            end
        end

        cache.dirty.core = true
        PlayerDataManager.LogOp(userId, "grant_rewards",
            { rewards = rewards, reason = reason,
              afterJade = cache.money.jade, afterLingshi = cache.money.lingshi })

        replyFn(true, nil, {
            jade = cache.money.jade,
            lingshi = cache.money.lingshi,
        })
    end,
})

-- ============================================================================
-- 广告奖励（服务端验证版）
-- 场景：看完广告后发放奖励，需服务端记录防止刷广告
-- ============================================================================
GameActions.Register("ad_reward", {
    rateLimit = { maxCount = 1, windowSec = 5 }, -- 最短5秒看一次广告
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local adType = params.adType or "unknown"
        local reward = tonumber(params.reward) or 0

        if reward <= 0 or reward > 10000 then
            replyFn(false, CODE.ERR_PARAMS, nil, "广告奖励金额异常")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 每日广告次数限制
        local today = os.date("%Y%m%d")
        cache._adCounts = cache._adCounts or {}
        cache._adCounts[today] = cache._adCounts[today] or {}
        local todayCount = cache._adCounts[today][adType] or 0

        local maxDaily = 20 -- 每种广告每日最多20次
        if todayCount >= maxDaily then
            replyFn(false, CODE.ERR_RATE_LIMIT, nil, "今日广告次数已用完")
            return
        end

        cache._adCounts[today][adType] = todayCount + 1

        -- 发放奖励
        cache.money.jade = (cache.money.jade or 0) + reward
        if cache.domains.core and cache.domains.core.playerInfo then
            cache.domains.core.playerInfo.jade = cache.money.jade
        end

        cache.dirty.core = true
        PlayerDataManager.LogOp(userId, "ad_reward",
            { adType = adType, reward = reward, count = todayCount + 1 })

        replyFn(true, nil, {
            jade = cache.money.jade,
            adCount = todayCount + 1,
        })
    end,
})

print("[CurrencyActions] 已注册: spend_jade, spend_lingshi, grant_rewards, ad_reward")
