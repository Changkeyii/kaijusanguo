-- ============================================================================
-- server/actions/TradeActions.lua
-- 交易行 Actions（服务端权威）
-- 购买装备时验证虎符余额、扣款，防止客户端篡改
-- 上架/下架的数据仍通过 clientCloud 公共市场表同步（跨玩家共享）
-- ============================================================================
local Protocol = require("network.Protocol")
local PlayerDataManager = require("server.PlayerDataManager")
local GameActions       = require("server.GameActions")

local CODE = Protocol.CODE

-- ============================================================================
-- trade_buy: 购买装备（服务端验证扣款）
-- 客户端负责：验证 listing 存在性（通过 GetRankList 二次确认）
-- 服务端负责：验证虎符余额、扣款、记录日志
-- ============================================================================
GameActions.Register("trade_buy", {
    rateLimit  = { interval = 2, burst = 3 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local price      = tonumber(params.price) or 0
        local listingKey = tostring(params.listingKey or "")
        local sellerId   = tonumber(params.sellerId) or 0

        -- 参数验证
        if price <= 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "价格无效")
            return
        end
        if listingKey == "" then
            replyFn(false, CODE.ERR_PARAMS, nil, "缺少上架标识")
            return
        end
        if sellerId <= 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "卖家ID无效")
            return
        end

        -- 防止自购
        if sellerId == userId then
            replyFn(false, CODE.ERR_VALIDATE, nil, "不能购买自己的装备")
            return
        end

        -- 价格上限校验（防止异常大额）
        if price > 999999 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "价格超出上限")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 验证余额
        local currentJade = cache.money.jade or 0
        if currentJade < price then
            replyFn(false, CODE.ERR_INSUFFICIENT, nil,
                "虎符不足: 需要" .. price .. " 当前" .. currentJade)
            return
        end

        -- 幂等检查（防止重复购买同一个 listing）
        local txKey = "trade_buy_" .. listingKey
        if PlayerDataManager.IsProcessed(userId, txKey) then
            replyFn(false, CODE.ERR_DUPLICATE, nil, "该交易已处理")
            return
        end

        -- 扣款
        cache.money.jade = currentJade - price
        local coreDomain = cache.domains.core
        if coreDomain and coreDomain.playerInfo then
            coreDomain.playerInfo.jade = cache.money.jade
            PlayerDataManager.SetDomain(userId, "core", coreDomain)
        end

        PlayerDataManager.MarkProcessed(userId, txKey)

        PlayerDataManager.LogOp(userId, "trade_buy", {
            listingKey = listingKey,
            sellerId = sellerId,
            price = price,
            after = cache.money.jade,
        })

        replyFn(true, CODE.OK, {
            jade = cache.money.jade,
            price = price,
            listingKey = listingKey,
        })
    end,
})

-- ============================================================================
-- trade_claim_sales: 卖家领取销售收入（服务端验证加款）
-- 客户端扫描公共市场表发现被购买后，请求服务端加虎符
-- ============================================================================
GameActions.Register("trade_claim_sales", {
    rateLimit  = { interval = 3, burst = 5 },
    needDomains = { "core" },
    handler = function(userId, params, replyFn)
        local jadeEarned = tonumber(params.jadeEarned) or 0
        local soldCount  = tonumber(params.soldCount) or 0
        local claimId    = tostring(params.claimId or "")

        if jadeEarned <= 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "领取金额无效")
            return
        end

        -- 单次领取上限
        if jadeEarned > 5000000 then
            replyFn(false, CODE.ERR_VALIDATE, nil, "单次领取金额超限")
            return
        end

        if claimId == "" then
            replyFn(false, CODE.ERR_PARAMS, nil, "缺少领取标识")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 幂等检查
        local txKey = "trade_claim_" .. claimId
        if PlayerDataManager.IsProcessed(userId, txKey) then
            replyFn(false, CODE.ERR_DUPLICATE, nil, "该收入已领取")
            return
        end

        -- 加款
        cache.money.jade = (cache.money.jade or 0) + jadeEarned
        local coreDomain = cache.domains.core
        if coreDomain and coreDomain.playerInfo then
            coreDomain.playerInfo.jade = cache.money.jade
            PlayerDataManager.SetDomain(userId, "core", coreDomain)
        end

        PlayerDataManager.MarkProcessed(userId, txKey)

        PlayerDataManager.LogOp(userId, "trade_claim_sales", {
            jadeEarned = jadeEarned,
            soldCount = soldCount,
            claimId = claimId,
            after = cache.money.jade,
        })

        replyFn(true, CODE.OK, {
            jade = cache.money.jade,
            jadeEarned = jadeEarned,
            soldCount = soldCount,
        })
    end,
})

print("[TradeActions] 已注册: trade_buy, trade_claim_sales")
return true
