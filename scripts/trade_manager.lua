-- ============================================================================
-- TradeManager - 交易行系统 (单一公共市场表架构)
-- 基于 clientCloud 排行榜 API 实现跨玩家装备交易
--
-- 架构说明:
--   使用同一个 rank list (trade_ts / trade_data) 作为"公共市场表"
--   每个玩家的 slot 包含: listings(上架) + purchases(购买记录)
--   买家购买后 → 写入自己 slot 的 purchases → 卖家扫描公共表即可发现
--   卖家领取后 → 删除 listing + 清理公共表
-- ============================================================================
---@diagnostic disable: undefined-global

local TradeManager = {}

local CWP = require("network.CloudWriteProxy")
local GameConfig = require("game_config")
local TRADE = GameConfig.TRADE

-- ============================================================================
-- 云端 Key 定义 (单一公共市场表)
-- ============================================================================
local PREFIX = "p_49dd_"
local KEYS = {
    trade_ts   = PREFIX .. "trade_ts",    -- SetInt: 更新时间戳(排序用)
    trade_data = PREFIX .. "trade_data",  -- Set: { listings, purchases, pendingJade, soldCount }
}

-- ============================================================================
-- 本地状态
-- ============================================================================
local state = {
    inited = false,
    -- 我的交易数据 (同步到云端 trade_data)
    myData = {
        listings = {},      -- 在售装备: { [listingKey] = { equip, price, listTime, sellerName } }
        purchases = {},     -- 我的购买记录(通知卖家): { [listingKey] = { sellerId, price, buyTime, buyerName } }
        pendingJade = 0,    -- 待领取虎符
        soldCount = 0,      -- 累计售出
    },
    -- 兼容旧版: myPurchases 指向 myData.purchases (UI 过滤用)
    myPurchases = nil,      -- 会在 Init 中设置为 myData.purchases 的引用
    -- 数据是否需要重新上传 (上传失败/启动时待同步)
    dataNeedUpload = false,
    -- 市场缓存
    marketItems = {},       -- 整合后的市场列表
    marketLoading = false,
    marketLoaded = false,
    lastRefreshTime = 0,
    lastCheckSalesTime = 0,
    -- 已处理的售出记录 (避免重复处理)
    processedSales = {},
}

TradeManager.state = state

-- ============================================================================
-- 初始化
-- ============================================================================
function TradeManager.Init()
    if state.inited then return end
    state.inited = true

    -- 从本地存档恢复交易数据
    if playerInfo and playerInfo.tradeData then
        state.myData = playerInfo.tradeData
        if not state.myData.listings then state.myData.listings = {} end
        if not state.myData.purchases then state.myData.purchases = {} end
        if not state.myData.pendingJade then state.myData.pendingJade = 0 end
        if not state.myData.soldCount then state.myData.soldCount = 0 end
    end

    -- 兼容旧版: 迁移 tradePurchases 到 myData.purchases
    if playerInfo and playerInfo.tradePurchases then
        for lk, purchase in pairs(playerInfo.tradePurchases) do
            if not state.myData.purchases[lk] then
                state.myData.purchases[lk] = purchase
            end
        end
        playerInfo.tradePurchases = nil  -- 清除旧字段
        state.dataNeedUpload = true      -- 需要重新上传合并后的数据
    end

    if playerInfo and playerInfo.tradeProcessed then
        state.processedSales = playerInfo.tradeProcessed
    end

    -- myPurchases 作为 myData.purchases 的引用 (UI 兼容)
    state.myPurchases = state.myData.purchases

    -- 清理过期数据
    TradeManager._cleanupOldData()

    print("[TradeManager] 初始化完成, 在售" .. TradeManager.GetListingCount() ..
          "件, 购买记录" .. TradeManager._countPurchases() .. "条")

    -- 启动时立即上传: 确保本地数据同步到云端排行榜
    -- (重登后云端 slot 可能为空, 必须重新上传 listings 才能让其他玩家看到)
    if TradeManager.GetListingCount() > 0 or TradeManager._hasPendingPurchases() then
        state.dataNeedUpload = true
        TradeManager._publishMyData(function(ok)
            if ok then
                print("[TradeManager] 启动时数据同步成功")
            else
                print("[TradeManager] 启动时数据同步失败, 将在Tick中重试")
            end
        end)
    end
end

--- 保存交易数据到本地存档
local function saveLocal()
    if playerInfo then
        playerInfo.tradeData = state.myData
        playerInfo.tradeProcessed = state.processedSales
        -- 清除旧版字段
        playerInfo.tradePurchases = nil
    end
end

-- ============================================================================
-- 内部工具函数
-- ============================================================================

--- 统计购买记录数量
function TradeManager._countPurchases()
    local count = 0
    for _ in pairs(state.myData.purchases) do count = count + 1 end
    return count
end

--- 检查是否有需要上传的购买记录
function TradeManager._hasPendingPurchases()
    return next(state.myData.purchases) ~= nil
end

--- 清理过期数据 (7天前的购买记录和已处理记录)
function TradeManager._cleanupOldData()
    local now = os.time()
    local CLEANUP_AGE = 7 * 86400  -- 7天
    local changed = false

    -- 清理旧的购买记录
    for lk, purchase in pairs(state.myData.purchases) do
        if now - (purchase.buyTime or 0) > CLEANUP_AGE then
            state.myData.purchases[lk] = nil
            changed = true
        end
    end

    -- 清理旧的已处理售出记录
    for lk, timestamp in pairs(state.processedSales) do
        if now - timestamp > CLEANUP_AGE then
            state.processedSales[lk] = nil
            changed = true
        end
    end

    if changed then
        saveLocal()
        print("[TradeManager] 清理过期数据完成")
    end
end

-- ============================================================================
-- 公共工具函数
-- ============================================================================

--- 生成上架唯一标识 key
---@param sellerId number
---@param setIdx number
---@param uid number
---@return string
local function makeListingKey(sellerId, setIdx, uid)
    return tostring(sellerId) .. "_" .. tostring(setIdx) .. "_" .. tostring(uid)
end

--- 统计在售数量
function TradeManager.GetListingCount()
    local count = 0
    for _ in pairs(state.myData.listings) do count = count + 1 end
    return count
end

--- 清除所有上架记录（CDK重置用）
function TradeManager.ClearAllListings()
    state.myData.listings = {}
    state.myData.pendingJade = 0
    state.myData.soldCount = 0
    saveLocal()
    TradeManager._publishMyData(function(ok)
        if ok then print("[TradeManager] 云端上架数据已清除") end
    end)
end

--- 检查装备是否可交易
---@param tier number
---@return boolean, string?
function TradeManager.CanTrade(tier)
    if tier < 4 then
        return false, "仅侯品及以上可交易"
    end
    if not TRADE.PRICE_RANGE[tier] then
        return false, "该品阶不支持交易"
    end
    return true
end

--- 获取价格范围
---@param tier number
---@return number, number
function TradeManager.GetPriceRange(tier)
    local range = TRADE.PRICE_RANGE[tier]
    if range then
        return range.min, range.max
    end
    return 0, 0
end

--- 计算到手金额 (扣除手续费)
---@param price number
---@return number
function TradeManager.CalcNetIncome(price)
    return math.floor(price * (1 - TRADE.COMMISSION))
end

-- ============================================================================
-- 上架
-- ============================================================================

--- 上架装备到交易行
---@param equipUid number 装备UID
---@param price number 售价
---@param callback? fun(ok:boolean, msg:string)
function TradeManager.ListItem(equipUid, price, callback)
    callback = callback or function() end

    if TradeManager.GetListingCount() >= TRADE.MAX_LISTINGS then
        callback(false, "上架数量已达上限(" .. TRADE.MAX_LISTINGS .. "件)")
        return
    end

    local item, _ = FindOwnedByUid(equipUid)
    if not item then
        callback(false, "未找到该装备")
        return
    end

    if playerEquipment and playerEquipment.equipped then
        for _, eqUid in pairs(playerEquipment.equipped) do
            if eqUid == equipUid then
                callback(false, "请先卸下装备再上架")
                return
            end
        end
    end

    local canTrade, reason = TradeManager.CanTrade(item.tier)
    if not canTrade then
        callback(false, reason)
        return
    end

    local minP, maxP = TradeManager.GetPriceRange(item.tier)
    price = math.floor(price)
    if price < minP or price > maxP then
        callback(false, "价格需在" .. minP .. "~" .. maxP .. "虎符之间")
        return
    end

    local removed = RemoveOwnedByUid(equipUid)
    if not removed then
        callback(false, "移除装备失败")
        return
    end

    local myUid = clientCloud and clientCloud.userId or 0
    local listingKey = makeListingKey(myUid, item.setIdx, item.uid)
    local sellerName = (playerInfo and playerInfo.nickname) or ("玩家" .. tostring(myUid))

    state.myData.listings[listingKey] = {
        equip = {
            setIdx = item.setIdx,
            slotIdx = item.slotIdx,
            tier = item.tier,
            quality = item.quality or 0,
            enhanceLv = item.enhanceLv or 0,
            level = item.level or 1,
        },
        price = price,
        listTime = os.time(),
        sellerName = sellerName,
    }

    saveLocal()
    if SaveGameProgress then SaveGameProgress() end

    TradeManager._publishMyData(function(ok)
        if ok then
            print("[TradeManager] 上架成功: " .. listingKey .. " 价格" .. price)
            callback(true, "上架成功")
        else
            -- 上传失败，恢复装备
            table.insert(playerEquipment.owned, removed)
            state.myData.listings[listingKey] = nil
            saveLocal()
            if SaveGameProgress then SaveGameProgress() end
            callback(false, "云端同步失败，装备已恢复")
        end
    end)
end

-- ============================================================================
-- 下架 / 领取过期
-- ============================================================================

--- 主动下架 (将装备还回仓库)
---@param listingKey string
---@param callback? fun(ok:boolean, msg:string)
function TradeManager.UnlistItem(listingKey, callback)
    callback = callback or function() end
    local listing = state.myData.listings[listingKey]
    if not listing then
        callback(false, "未找到该上架记录")
        return
    end

    local eq = listing.equip
    local newItem = CreateEquipItem(eq.setIdx, eq.slotIdx, eq.tier, eq.quality, eq.level)
    newItem.enhanceLv = eq.enhanceLv or 0

    state.myData.listings[listingKey] = nil
    saveLocal()
    if SaveGameProgress then SaveGameProgress() end

    TradeManager._publishMyData(function(ok)
        if ok then
            print("[TradeManager] 下架成功: " .. listingKey)
            callback(true, "装备已返回仓库")
        else
            callback(true, "装备已返回仓库(云端稍后同步)")
        end
    end)
end

--- 领取过期装备 (与下架逻辑相同)
function TradeManager.ClaimExpired(listingKey, callback)
    TradeManager.UnlistItem(listingKey, callback)
end

-- ============================================================================
-- 领取虎符
-- ============================================================================

--- 领取待收虎符
---@param callback? fun(amount:number)
function TradeManager.ClaimJade(callback)
    callback = callback or function() end
    local amount = state.myData.pendingJade or 0
    if amount <= 0 then
        callback(0)
        return
    end

    -- 服务端权威模式：加款走 RPC
    if rawget(_G, "cl_state") then
        local ClientNet = require("network.Client")
        local claimId = tostring(os.time()) .. "_" .. tostring(amount)
        ClientNet.Request("trade_claim_sales", {
            jadeEarned = amount,
            soldCount = state.myData.soldCount or 0,
            claimId = claimId,
        }, function(resp)
            if not resp.ok then
                print("[TradeManager] 领取失败: " .. tostring(resp.msg))
                callback(0)
                return
            end
            -- 服务端加款成功，同步本地
            playerInfo.jade = resp.data and resp.data.jade or ((playerInfo.jade or 0) + amount)
            state.myData.pendingJade = 0
            saveLocal()
            if SaveGameProgress then SaveGameProgress() end
            TradeManager._publishMyData(function()
                print("[TradeManager] 领取虎符(RPC): " .. amount)
                callback(amount)
            end)
        end)
        return
    end

    -- 单机模式：本地加款
    playerInfo.jade = (playerInfo.jade or 0) + amount
    state.myData.pendingJade = 0
    saveLocal()
    if SaveGameProgress then SaveGameProgress() end

    TradeManager._publishMyData(function()
        print("[TradeManager] 领取虎符: " .. amount)
        callback(amount)
    end)
end

-- ============================================================================
-- 刷新市场 (浏览公共市场表)
-- ============================================================================

--- 刷新市场列表
---@param callback? fun(items:table)
function TradeManager.RefreshMarket(callback)
    callback = callback or function() end

    local now = os.time()
    if now - state.lastRefreshTime < TRADE.REFRESH_CD then
        callback(state.marketItems)
        return
    end

    if state.marketLoading then
        callback(state.marketItems)
        return
    end

    state.marketLoading = true
    local myUid = clientCloud and clientCloud.userId or 0

    if not rawget(_G, "clientCloud") then
        state.marketLoading = false
        callback(state.marketItems)
        return
    end

    -- 读取公共市场表 (所有人的 trade_data)
    clientCloud:GetRankList(KEYS.trade_ts, 0, 200, {
        ok = function(rankList)
            local items = {}
            local nowTime = os.time()

            -- ========================================
            -- 同时处理两件事:
            -- 1. 提取他人的上架列表 → 市场浏览
            -- 2. 扫描他人的购买记录 → 检查我的物品是否已售出
            -- ========================================
            local soldCount = 0
            local jadeEarned = 0
            local salesChanged = false

            for _, entry in ipairs(rankList) do
                local playerId = entry.player or entry.userId
                local tradeData = entry.score and entry.score[KEYS.trade_data]

                if tradeData then
                    local isMe = (playerId == myUid)

                    -- (1) 提取所有人的上架列表（包含自己的，标记 isMine）
                    if tradeData.listings then
                        for lk, listing in pairs(tradeData.listings) do
                            local elapsed = nowTime - (listing.listTime or 0)
                            if elapsed < TRADE.EXPIRE_SECONDS then
                                table.insert(items, {
                                    listingKey = lk,
                                    equip = listing.equip,
                                    price = listing.price,
                                    sellerName = listing.sellerName or ("玩家" .. tostring(playerId)),
                                    sellerId = playerId,
                                    listTime = listing.listTime,
                                    remainSec = TRADE.EXPIRE_SECONDS - elapsed,
                                    isMine = isMe,  -- 标记是否为自己的商品
                                })
                            end
                        end
                    end

                    -- (2) 扫描他人的购买记录 → 我的物品是否已售出（只看他人数据）
                    if not isMe and tradeData.purchases then
                        for lk, purchase in pairs(tradeData.purchases) do
                            local pSellerId = purchase.sellerId
                            -- 兼容 JSON 解码后 sellerId 可能为 string
                            if type(pSellerId) == "string" then pSellerId = tonumber(pSellerId) end
                            if pSellerId == myUid and state.myData.listings[lk] then
                                if not state.processedSales[lk] then
                                    local listing = state.myData.listings[lk]
                                    local netIncome = TradeManager.CalcNetIncome(listing.price)
                                    state.myData.pendingJade = (state.myData.pendingJade or 0) + netIncome
                                    state.myData.soldCount = (state.myData.soldCount or 0) + 1
                                    state.myData.listings[lk] = nil  -- 移除已售
                                    state.processedSales[lk] = os.time()
                                    soldCount = soldCount + 1
                                    jadeEarned = jadeEarned + netIncome
                                    salesChanged = true
                                    print("[TradeManager] 售出: " .. lk .. " 到账" .. netIncome .. "虎符")
                                end
                            end
                        end
                    end
                end
            end

            -- 过滤掉自己已售出/已下架的商品
            -- (云端数据可能尚未更新, 但本地 listings 已移除)
            do
                local filtered = {}
                for _, it in ipairs(items) do
                    if not (it.isMine and not state.myData.listings[it.listingKey]) then
                        filtered[#filtered + 1] = it
                    end
                end
                items = filtered
            end

            -- 按品阶降序, 同品阶按价格升序
            table.sort(items, function(a, b)
                if a.equip.tier ~= b.equip.tier then return a.equip.tier > b.equip.tier end
                return a.price < b.price
            end)

            state.marketItems = items
            state.marketLoaded = true
            state.lastRefreshTime = os.time()
            state.lastCheckSalesTime = os.time()  -- RefreshMarket 已包含 CheckSales
            print("[TradeManager] 市场刷新完成, " .. #items .. "件在售")

            -- 如果发现有售出, 保存并上传
            if salesChanged then
                saveLocal()
                if SaveGameProgress then SaveGameProgress() end
                TradeManager._publishMyData()
                print("[TradeManager] 发现" .. soldCount .. "笔售出, 共" .. jadeEarned .. "虎符待领取")
            end

            -- 批量解析卖家昵称
            local sellerIdSet = {}
            local sellerIds = {}
            for _, it in ipairs(items) do
                local sid = it.sellerId
                if sid and not sellerIdSet[sid] then
                    sellerIdSet[sid] = true
                    sellerIds[#sellerIds + 1] = sid
                end
            end

            if #sellerIds > 0 and rawget(_G, "GetUserNickname") then
                local nickOk, nickErr = pcall(function()
                    GetUserNickname({
                        userIds = sellerIds,
                        onSuccess = function(nicknames)
                            local nameMap = {}
                            for _, info in ipairs(nicknames) do
                                nameMap[info.userId] = info.nickname
                            end
                            for _, it in ipairs(state.marketItems) do
                                if nameMap[it.sellerId] then
                                    it.sellerName = nameMap[it.sellerId]
                                end
                            end
                            state.marketLoading = false
                            callback(state.marketItems)
                        end,
                        onError = function()
                            state.marketLoading = false
                            callback(state.marketItems)
                        end,
                    })
                end)
                if not nickOk then
                    print("[TradeManager] GetUserNickname异常: " .. tostring(nickErr))
                    state.marketLoading = false
                    callback(state.marketItems)
                end
            else
                state.marketLoading = false
                callback(items)
            end
        end,
        error = function(code, reason)
            state.marketLoading = false
            print("[TradeManager] 市场刷新失败: " .. tostring(reason))
            callback(state.marketItems)
        end,
    }, KEYS.trade_data)
end

-- ============================================================================
-- 购买
-- ============================================================================

--- 购买装备 (含刷新验证)
---@param listingKey string
---@param expectedSellerId number
---@param expectedPrice number
---@param callback fun(ok:boolean, msg:string)
function TradeManager.BuyItem(listingKey, expectedSellerId, expectedPrice, callback)
    callback = callback or function() end

    -- 防止自购
    local myUid = clientCloud and clientCloud.userId or 0
    if expectedSellerId == myUid then
        callback(false, "不能购买自己上架的装备")
        return
    end

    if (playerInfo.jade or 0) < expectedPrice then
        callback(false, "虎符不足")
        return
    end

    -- 刷新验证: 重新拉取公共市场表, 确认 listing 仍存在
    if not rawget(_G, "clientCloud") then
        callback(false, "云服务不可用")
        return
    end
    state.marketLoading = true
    clientCloud:GetRankList(KEYS.trade_ts, 0, 200, {
        ok = function(rankList)
            state.marketLoading = false

            local found = false
            local listing = nil
            for _, entry in ipairs(rankList) do
                local sellerId = entry.player or entry.userId
                if sellerId == expectedSellerId then
                    local tradeData = entry.score and entry.score[KEYS.trade_data]
                    if tradeData and tradeData.listings and tradeData.listings[listingKey] then
                        listing = tradeData.listings[listingKey]
                        if os.time() - (listing.listTime or 0) < TRADE.EXPIRE_SECONDS then
                            found = true
                        end
                    end
                    break
                end
            end

            if not found or not listing then
                callback(false, "该装备已被其他玩家买下或已下架")
                state.lastRefreshTime = 0
                return
            end

            if listing.price ~= expectedPrice then
                callback(false, "价格已变动,请刷新后重试")
                state.lastRefreshTime = 0
                return
            end

            -- 完成购买的内部逻辑（扣款后调用）
            local function _finalizePurchase(finalJade)
                -- 同步本地虎符
                playerInfo.jade = finalJade

                -- 创建装备到买家仓库
                local eq = listing.equip
                local newItem = CreateEquipItem(eq.setIdx, eq.slotIdx, eq.tier, eq.quality, eq.level)
                newItem.enhanceLv = eq.enhanceLv or 0

                -- 写入购买记录到公共市场表 (标记已出售)
                local buyerName = (playerInfo and playerInfo.nickname) or ("玩家" .. tostring(myUid))
                state.myData.purchases[listingKey] = {
                    sellerId = expectedSellerId,
                    price = expectedPrice,
                    buyTime = os.time(),
                    buyerName = buyerName,
                }
                state.dataNeedUpload = true  -- 标记待上传

                saveLocal()
                if SaveGameProgress then SaveGameProgress() end

                -- 上传到公共市场表
                TradeManager._publishMyData(function(ok2)
                    if ok2 then
                        print("[TradeManager] 购买记录已上传: " .. listingKey)
                    else
                        print("[TradeManager] 购买记录上传失败,将在Tick重试: " .. listingKey)
                    end
                end)

                -- 刷新市场缓存
                state.lastRefreshTime = 0

                callback(true, "购买成功! " .. EQUIP_TIER_NAMES[eq.tier] .. " " ..
                    EQUIP_SLOT_NAMES[eq.slotIdx] .. " 已加入仓库")
            end

            -- 服务端权威模式：扣款走 RPC
            if rawget(_G, "cl_state") then
                local ClientNet = require("network.Client")
                ClientNet.Request("trade_buy", {
                    price = expectedPrice,
                    listingKey = listingKey,
                    sellerId = expectedSellerId,
                }, function(resp)
                    if not resp.ok then
                        callback(false, tostring(resp.msg or "服务端扣款失败"))
                        state.lastRefreshTime = 0
                        return
                    end
                    local serverJade = resp.data and resp.data.jade or (playerInfo.jade - expectedPrice)
                    _finalizePurchase(serverJade)
                end)
                return
            end

            -- 单机模式：本地扣款
            _finalizePurchase(playerInfo.jade - expectedPrice)
        end,
        error = function(code, reason)
            state.marketLoading = false
            callback(false, "网络错误,请稍后重试")
        end,
    }, KEYS.trade_data)
end

-- ============================================================================
-- 卖家收款 (扫描公共市场表中的购买记录)
-- ============================================================================

--- 扫描公共市场表, 检查我的上架物品是否已被购买
---@param callback? fun(soldCount:number, jadeEarned:number)
function TradeManager.CheckSales(callback)
    callback = callback or function() end

    local now = os.time()
    if now - state.lastCheckSalesTime < TRADE.CHECK_SALES_CD then
        callback(0, 0)
        return
    end
    state.lastCheckSalesTime = now

    local myUid = clientCloud and clientCloud.userId or 0
    if myUid == 0 then
        callback(0, 0)
        return
    end

    if TradeManager.GetListingCount() == 0 then
        callback(0, 0)
        return
    end

    -- 读取同一个公共市场表
    if not rawget(_G, "clientCloud") then
        callback(0, 0)
        return
    end
    clientCloud:GetRankList(KEYS.trade_ts, 0, 200, {
        ok = function(rankList)
            local soldCount = 0
            local jadeEarned = 0
            local changed = false

            for _, entry in ipairs(rankList) do
                local playerId = entry.player or entry.userId
                if playerId ~= myUid then
                    local tradeData = entry.score and entry.score[KEYS.trade_data]
                    if tradeData and tradeData.purchases then
                        for lk, purchase in pairs(tradeData.purchases) do
                            local pSellerId = purchase.sellerId
                            if type(pSellerId) == "string" then pSellerId = tonumber(pSellerId) end
                            if pSellerId == myUid and state.myData.listings[lk] then
                                if not state.processedSales[lk] then
                                    local listing = state.myData.listings[lk]
                                    local netIncome = TradeManager.CalcNetIncome(listing.price)
                                    state.myData.pendingJade = (state.myData.pendingJade or 0) + netIncome
                                    state.myData.soldCount = (state.myData.soldCount or 0) + 1
                                    state.myData.listings[lk] = nil
                                    state.processedSales[lk] = os.time()
                                    soldCount = soldCount + 1
                                    jadeEarned = jadeEarned + netIncome
                                    changed = true
                                    print("[TradeManager] 售出: " .. lk .. " 到账" .. netIncome .. "虎符")
                                end
                            end
                        end
                    end
                end
            end

            if changed then
                saveLocal()
                if SaveGameProgress then SaveGameProgress() end
                TradeManager._publishMyData()
            end

            callback(soldCount, jadeEarned)
        end,
        error = function()
            callback(0, 0)
        end,
    }, KEYS.trade_data)
end

--- 重置 CheckSales 冷却 (进入交易行时调用)
function TradeManager.ResetCheckSalesCD()
    state.lastCheckSalesTime = 0
end

-- ============================================================================
-- 过期检测
-- ============================================================================

--- 获取过期的上架列表
---@return table[] expiredKeys
function TradeManager.GetExpiredListings()
    local expired = {}
    local now = os.time()
    for lk, listing in pairs(state.myData.listings) do
        if now - (listing.listTime or 0) >= TRADE.EXPIRE_SECONDS then
            table.insert(expired, lk)
        end
    end
    return expired
end

--- 获取在售(未过期)的上架列表
---@return table[] activeListings
function TradeManager.GetActiveListings()
    local active = {}
    local now = os.time()
    for lk, listing in pairs(state.myData.listings) do
        if now - (listing.listTime or 0) < TRADE.EXPIRE_SECONDS then
            table.insert(active, { key = lk, listing = listing, remainSec = TRADE.EXPIRE_SECONDS - (now - listing.listTime) })
        end
    end
    return active
end

-- ============================================================================
-- 定时任务 (在 HandleUpdate 中调用)
-- ============================================================================

local tickAccum = 0
function TradeManager.Tick(dt)
    if not state.inited then return end
    tickAccum = tickAccum + dt
    if tickAccum < 30 then return end
    tickAccum = 0

    -- 重试失败的数据上传
    if state.dataNeedUpload then
        TradeManager._publishMyData(function(ok)
            if ok then
                print("[TradeManager] 数据重试上传成功")
            end
        end)
    end

    -- 自动检查收款
    if TradeManager.GetListingCount() > 0 then
        TradeManager.CheckSales()
    end
end

-- ============================================================================
-- 云端同步 (单一上传函数)
-- ============================================================================

--- 上传我的交易数据到公共市场表 (listings + purchases + pendingJade + soldCount)
---@param callback? fun(ok:boolean)
function TradeManager._publishMyData(callback)
    callback = callback or function() end
    if not CWP.IsAvailable() then callback(false) return end

    CWP.Write({
        { key = KEYS.trade_ts, value = os.time(), int = true },
        { key = KEYS.trade_data, value = state.myData },
    }, "交易行-数据同步", {
        ok = function()
            state.dataNeedUpload = false
            callback(true)
        end,
        error = function(code, reason)
            print("[TradeManager] 上传交易数据失败: " .. tostring(reason))
            state.dataNeedUpload = true  -- 标记需重试
            callback(false)
        end,
    })
end

return TradeManager
