-- ============================================================================
-- TradeManager - 交易行系统 (市场表 + 个人表 分离架构)
--
-- 架构说明:
--   市场表 (mkt_ts + mkt_data): 公共排行榜, 用于市场浏览和交易交互
--     - mkt_ts (SetInt): 最新活动时间戳, 用于排行排序
--     - mkt_data (Set): { listings = {...}, purchases = {...} }
--   个人表 (my_trade): 玩家私有交易数据 (含 pendingJade/soldCount)
--     - my_trade (Set): { listings, purchases, pendingJade, soldCount }
--
--   上架: 写市场表(listings) + 写个人表
--   购买: 验证市场表 → 原子扣款 → 写购买记录到市场表+个人表
--   市场浏览: 分页读市场表 (每次一页, PAGE_SIZE 个玩家)
--   收款检测: 扫描市场表最近活跃的玩家的 purchases
-- ============================================================================
---@diagnostic disable: undefined-global

local TradeManager = {}

local GameConfig = require("game_config")
local TRADE = GameConfig.TRADE

-- ============================================================================
-- 云端 Key 定义
-- ============================================================================
local PREFIX = "p_49dd_"
local KEYS = {
    -- 市场表 (公共排行榜)
    mkt_ts   = PREFIX .. "mkt_ts",     -- SetInt: 最新活动时间戳
    mkt_data = PREFIX .. "mkt_data",   -- Set: { listings, purchases }
    -- 个人表 (私有数据)
    my_trade = PREFIX .. "my_trade",   -- Set: full myData
}

-- 分页配置
local PAGE_SIZE = 20

-- ============================================================================
-- 本地状态
-- ============================================================================
local state = {
    inited = false,
    -- 我的交易数据 (同步到云端 my_trade + mkt_data)
    myData = {
        listings = {},      -- 在售装备: { [listingKey] = { equip, price, listTime, sellerName } }
        purchases = {},     -- 我的购买记录: { [listingKey] = { sellerId, price, buyTime, buyerName } }
        pendingJade = 0,    -- 待领取玉壁
        soldCount = 0,      -- 累计售出
    },
    -- 兼容: myPurchases 指向 myData.purchases (UI 过滤用)
    myPurchases = nil,
    -- 数据是否需要重新上传
    dataNeedUpload = false,
    -- 市场缓存
    marketItems = {},       -- 当前页的市场列表
    marketPage = 1,         -- 当前页码 (1-based)
    marketHasNextPage = false,
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
        playerInfo.tradePurchases = nil
        state.dataNeedUpload = true
    end

    if playerInfo and playerInfo.tradeProcessed then
        state.processedSales = playerInfo.tradeProcessed
    end

    state.myPurchases = state.myData.purchases

    -- 清理过期数据
    TradeManager._cleanupOldData()

    print("[TradeManager] 初始化完成, 在售" .. TradeManager.GetListingCount() ..
          "件, 购买记录" .. TradeManager._countPurchases() .. "条")

    -- 启动时同步: 确保本地数据上传到云端 (重登后云端 slot 可能为空)
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
        playerInfo.tradePurchases = nil
    end
end

-- ============================================================================
-- 内部工具函数
-- ============================================================================

function TradeManager._countPurchases()
    local count = 0
    for _ in pairs(state.myData.purchases) do count = count + 1 end
    return count
end

function TradeManager._hasPendingPurchases()
    return next(state.myData.purchases) ~= nil
end

function TradeManager._cleanupOldData()
    local now = os.time()
    local CLEANUP_AGE = 7 * 86400
    local changed = false

    for lk, purchase in pairs(state.myData.purchases) do
        if now - (purchase.buyTime or 0) > CLEANUP_AGE then
            state.myData.purchases[lk] = nil
            changed = true
        end
    end

    for lk, timestamp in pairs(state.processedSales) do
        if now - timestamp > CLEANUP_AGE then
            state.processedSales[lk] = nil
            changed = true
        end
    end

    if changed then
        saveLocal()
        print("[TradeManager] 已清理过期数据")
    end
end

-- ============================================================================
-- 公共工具函数
-- ============================================================================

local function makeListingKey(sellerId, setIdx, uid)
    return tostring(sellerId) .. "_" .. tostring(setIdx) .. "_" .. tostring(uid)
end

function TradeManager.GetListingCount()
    local count = 0
    for _ in pairs(state.myData.listings) do count = count + 1 end
    return count
end

function TradeManager.ClearAllListings()
    state.myData.listings = {}
    state.myData.pendingJade = 0
    state.myData.soldCount = 0
    saveLocal()
    TradeManager._publishMyData(function(ok)
        if ok then print("[TradeManager] 云端上架数据已清除") end
    end)
end

function TradeManager.CanTrade(tier)
    if tier < 4 then
        return false, "品阶过低，无法交易"
    end
    if not TRADE.PRICE_RANGE[tier] then
        return false, "该品阶不支持交易"
    end
    return true
end

function TradeManager.GetPriceRange(tier)
    local range = TRADE.PRICE_RANGE[tier]
    if range then
        return range.min, range.max
    end
    return 0, 0
end

function TradeManager.CalcNetIncome(price)
    return math.floor(price * (1 - TRADE.COMMISSION))
end

-- ============================================================================
-- 数据发布 (写市场表 + 个人表)
-- ============================================================================

--- 过滤出未过期的在售 listings
local function getActiveListings()
    local active = {}
    local now = os.time()
    for lk, listing in pairs(state.myData.listings) do
        if now - (listing.listTime or 0) < TRADE.EXPIRE_SECONDS then
            active[lk] = listing
        end
    end
    return active
end

--- 上传交易数据到云端 (市场表 + 个人表)
---@param callback? fun(ok:boolean, reason?:string)
function TradeManager._publishMyData(callback)
    callback = callback or function() end
    if not CloudAPI.IsAvailable() then callback(false, "not_available") return end
    if not CloudAPI.IsReady() then
        -- 云端已启用但客户端未就绪, 标记等待 Tick 自动重试
        state.dataNeedUpload = true
        print("[TradeManager] 云端未就绪, 等待自动重试")
        callback(false, "not_ready")
        return
    end

    local activeListings = getActiveListings()

    -- 市场表: 仅包含展示和交互所需数据
    local marketData = {
        listings = activeListings,
        purchases = state.myData.purchases,
    }

    -- 个人表: 完整交易数据
    local personalData = state.myData

    CloudAPI:BatchSet()
        :SetInt(KEYS.mkt_ts, os.time())
        :Set(KEYS.mkt_data, marketData)
        :Set(KEYS.my_trade, personalData)
        :Save("交易行数据同步", {
            ok = function()
                state.dataNeedUpload = false
                print("[TradeManager] 数据发布成功 (市场+个人)")
                callback(true)
            end,
            error = function(code, reason)
                print("[TradeManager] 数据发布失败: " .. tostring(reason))
                state.dataNeedUpload = true
                callback(false, "sync_error")
            end,
        })
end

-- ============================================================================
-- 上架
-- ============================================================================

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
        callback(false, "价格需在" .. minP .. "~" .. maxP .. "虎珀之间")
        return
    end

    local removed = RemoveOwnedByUid(equipUid)
    if not removed then
        callback(false, "移除装备失败")
        return
    end

    local myUid = CloudAPI.GetUserId()
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

    TradeManager._publishMyData(function(ok, pubReason)
        if ok then
            print("[TradeManager] 上架成功: " .. listingKey .. " 价格" .. price)
            state.lastRefreshTime = 0
            -- 将新上架物品立即加入本地市场缓存
            table.insert(state.marketItems, {
                listingKey = listingKey,
                equip = state.myData.listings[listingKey].equip,
                price = price,
                sellerName = sellerName,
                sellerId = myUid,
                listTime = os.time(),
                remainSec = TRADE.EXPIRE_SECONDS,
                isMine = true,
            })
            callback(true, "上架成功")
        elseif pubReason == "not_ready" then
            -- 云端未就绪: 保留本地上架数据, Tick 会自动重试同步
            print("[TradeManager] 上架已保存本地, 等待云端就绪后自动同步")
            table.insert(state.marketItems, {
                listingKey = listingKey,
                equip = state.myData.listings[listingKey].equip,
                price = price,
                sellerName = sellerName,
                sellerId = myUid,
                listTime = os.time(),
                remainSec = TRADE.EXPIRE_SECONDS,
                isMine = true,
            })
            callback(true, "上架成功(等待云端同步)")
        else
            -- 真正的上传失败，恢复装备
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

    -- 从本地市场缓存中移除
    for i = #state.marketItems, 1, -1 do
        if state.marketItems[i].listingKey == listingKey then
            table.remove(state.marketItems, i)
            break
        end
    end
    state.lastRefreshTime = 0

    TradeManager._publishMyData(function(ok)
        if ok then
            print("[TradeManager] 下架成功: " .. listingKey)
            callback(true, "装备已返回仓库")
        else
            callback(true, "装备已返回仓库（云端稍后同步）")
        end
    end)
end

function TradeManager.ClaimExpired(listingKey, callback)
    TradeManager.UnlistItem(listingKey, callback)
end

-- ============================================================================
-- 领取玉壁
-- ============================================================================

function TradeManager.ClaimJade(callback)
    callback = callback or function() end
    local amount = state.myData.pendingJade or 0
    if amount <= 0 then
        callback(0)
        return
    end

    playerInfo.jade = (playerInfo.jade or 0) + amount
    state.myData.pendingJade = 0
    saveLocal()
    if SaveGameProgress then SaveGameProgress() end

    TradeManager._publishMyData(function()
        print("[TradeManager] 领取玉壁: " .. amount)
        callback(amount)
    end)
end

-- ============================================================================
-- 刷新市场 (分页)
-- ============================================================================

--- 从排行榜条目中提取市场物品列表
---@param rankList table[] 排行榜条目
---@param myUid number 当前玩家 ID
---@return table[] items 市场物品列表
---@return boolean salesChanged 是否发现新的售出
local function extractMarketItems(rankList, myUid)
    local items = {}
    local nowTime = os.time()
    local salesChanged = false

    for _idx, entry in ipairs(rankList) do
        local playerId = entry.player or entry.userId
        local mktData = entry.score and entry.score[KEYS.mkt_data]

        -- ★ 调试日志: 排查市场数据读取
        print(string.format("[TradeManager] entry#%d userId=%s hasScore=%s hasMktData=%s",
            _idx, tostring(playerId),
            tostring(entry.score ~= nil),
            tostring(mktData ~= nil)))
        if entry.score and not mktData then
            -- 打印 score 中的实际 key, 帮助定位字段名问题
            local scoreKeys = {}
            for k, _ in pairs(entry.score) do scoreKeys[#scoreKeys+1] = tostring(k) end
            print("[TradeManager]   score keys: " .. table.concat(scoreKeys, ", "))
        end

        if mktData then
            local isMe = (playerId == myUid)

            -- 提取所有人的在售 listings
            if mktData.listings then
                for lk, listing in pairs(mktData.listings) do
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
                            isMine = isMe,
                        })
                    end
                end
            end

            -- 扫描他人的购买记录 → 检测我的物品是否已售出
            if not isMe and mktData.purchases then
                for lk, purchase in pairs(mktData.purchases) do
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
                            salesChanged = true
                            print("[TradeManager] 售出: " .. lk .. " 到账" .. netIncome .. "玉壁")
                        end
                    end
                end
            end
        end
    end

    return items, salesChanged
end

--- 过滤和排序市场物品
local function filterAndSortItems(items)
    -- 过滤已售出/已下架的自己的商品
    local filtered = {}
    local myPurchases = state.myData.purchases or {}
    for _, it in ipairs(items) do
        local selfRemoved = it.isMine and not state.myData.listings[it.listingKey]
        local alreadyBought = myPurchases[it.listingKey]
        if not selfRemoved and not alreadyBought then
            filtered[#filtered + 1] = it
        end
    end

    -- 按品阶降序, 同品阶按价格升序
    table.sort(filtered, function(a, b)
        if a.equip.tier ~= b.equip.tier then return a.equip.tier > b.equip.tier end
        return a.price < b.price
    end)

    return filtered
end

--- 批量解析卖家昵称
local function resolveSellerNames(items, callback)
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
                    for _, it in ipairs(items) do
                        if nameMap[it.sellerId] then
                            it.sellerName = nameMap[it.sellerId]
                        end
                    end
                    callback()
                end,
                onError = function()
                    callback()
                end,
            })
        end)
        if not nickOk then
            print("[TradeManager] GetUserNickname异常: " .. tostring(nickErr))
            callback()
        end
    else
        callback()
    end
end

--- 刷新市场列表 (分页)
---@param page? number 页码 (1-based, 默认当前页)
---@param callback? fun(items:table)
function TradeManager.RefreshMarket(page, callback)
    -- 兼容旧调用: RefreshMarket(callback) 无页码参数
    if type(page) == "function" then
        callback = page
        page = nil
    end
    callback = callback or function() end
    page = page or state.marketPage or 1
    if page < 1 then page = 1 end

    local now = os.time()
    -- 同一页 10 秒冷却
    if page == state.marketPage and now - state.lastRefreshTime < TRADE.REFRESH_CD then
        callback(state.marketItems)
        return
    end

    if state.marketLoading then
        callback(state.marketItems)
        return
    end

    state.marketLoading = true
    local myUid = CloudAPI.GetUserId()

    local startIdx = (page - 1) * PAGE_SIZE

    CloudAPI:GetRankList(KEYS.mkt_ts, startIdx, PAGE_SIZE, {
        ok = function(rankList)
            -- 判断是否有下一页
            state.marketHasNextPage = (#rankList >= PAGE_SIZE)

            -- 提取市场物品 + 检测售出
            local items, salesChanged = extractMarketItems(rankList, myUid)

            -- 过滤和排序
            items = filterAndSortItems(items)

            state.marketItems = items
            state.marketPage = page
            state.marketLoaded = true
            state.lastRefreshTime = os.time()
            state.lastCheckSalesTime = os.time()

            print("[TradeManager] 市场刷新完成, 第" .. page .. "页, " .. #items .. "件在售" ..
                  (state.marketHasNextPage and " (有下一页)" or " (末页)"))

            -- 如果发现有售出, 保存并上传
            if salesChanged then
                saveLocal()
                if SaveGameProgress then SaveGameProgress() end
                TradeManager._publishMyData()
            end

            -- 批量解析卖家昵称
            resolveSellerNames(items, function()
                state.marketLoading = false
                callback(state.marketItems)
            end)
        end,
        error = function(code, reason)
            state.marketLoading = false
            print("[TradeManager] 市场刷新失败: " .. tostring(reason))
            callback(state.marketItems)
        end,
    }, KEYS.mkt_data)
end

-- ============================================================================
-- 购买
-- ============================================================================

--- 验证卖家的 listing 是否仍然存在 (大范围扫描)
---@param listingKey string
---@param expectedSellerId number
---@param callback fun(found:boolean, listing:table?)
local function verifyListing(listingKey, expectedSellerId, callback)
    -- 扫描前 200 个最近活跃的玩家
    CloudAPI:GetRankList(KEYS.mkt_ts, 0, 200, {
        ok = function(rankList)
            for _, entry in ipairs(rankList) do
                local playerId = entry.player or entry.userId
                if playerId == expectedSellerId then
                    local mktData = entry.score and entry.score[KEYS.mkt_data]
                    if mktData and mktData.listings and mktData.listings[listingKey] then
                        local listing = mktData.listings[listingKey]
                        if os.time() - (listing.listTime or 0) < TRADE.EXPIRE_SECONDS then
                            callback(true, listing)
                            return
                        end
                    end
                    break
                end
            end
            callback(false, nil)
        end,
        error = function()
            callback(false, nil)
        end,
    }, KEYS.mkt_data)
end

--- 购买装备
---@param listingKey string
---@param expectedSellerId number
---@param expectedPrice number
---@param callback fun(ok:boolean, msg:string)
function TradeManager.BuyItem(listingKey, expectedSellerId, expectedPrice, callback)
    callback = callback or function() end

    local myUid = CloudAPI.GetUserId()
    if expectedSellerId == myUid then
        callback(false, "不能购买自己上架的装备")
        return
    end

    if (playerInfo.jade or 0) < expectedPrice then
        callback(false, "虎珀不足")
        return
    end

    state.marketLoading = true

    -- 验证 listing 仍然存在
    verifyListing(listingKey, expectedSellerId, function(found, listing)
        if not found or not listing then
            state.marketLoading = false
            callback(false, "该装备已被其他玩家买走或已下架")
            state.lastRefreshTime = 0
            return
        end

        if listing.price ~= expectedPrice then
            state.marketLoading = false
            callback(false, "价格已变动，请刷新后重试")
            state.lastRefreshTime = 0
            return
        end

        -- 服务端原子扣除虎珀
        local eq = listing.equip
        CloudAPI:TradeBuy(PREFIX .. "sv_core", expectedPrice, {
            ok = function(newJade)
                state.marketLoading = false
                playerInfo.jade = newJade or (playerInfo.jade - expectedPrice)

                -- 创建装备到买家仓库
                local newItem = CreateEquipItem(eq.setIdx, eq.slotIdx, eq.tier, eq.quality, eq.level)
                newItem.enhanceLv = eq.enhanceLv or 0

                -- 写入购买记录
                local buyerName = (playerInfo and playerInfo.nickname) or ("玩家" .. tostring(myUid))
                state.myData.purchases[listingKey] = {
                    sellerId = expectedSellerId,
                    price = expectedPrice,
                    buyTime = os.time(),
                    buyerName = buyerName,
                }
                state.dataNeedUpload = true

                saveLocal()
                if SaveGameProgress then SaveGameProgress() end

                -- 上传到市场表+个人表
                TradeManager._publishMyData(function(pubOk)
                    if pubOk then
                        print("[TradeManager] 购买记录已上传: " .. listingKey)
                    else
                        print("[TradeManager] 购买记录上传失败,将在Tick重试: " .. listingKey)
                    end
                end)

                state.lastRefreshTime = 0
                callback(true, "购买成功！" .. EQUIP_TIER_NAMES[eq.tier] .. " " ..
                    EQUIP_SLOT_NAMES[eq.slotIdx] .. " 已加入仓库")
            end,
            error = function(reason)
                state.marketLoading = false
                callback(false, "购买失败：" .. tostring(reason))
            end,
        })
    end)
end

-- ============================================================================
-- 卖家收款 (扫描市场表中的购买记录)
-- ============================================================================

function TradeManager.CheckSales(callback)
    callback = callback or function() end

    local now = os.time()
    if now - state.lastCheckSalesTime < TRADE.CHECK_SALES_CD then
        callback(0, 0)
        return
    end
    state.lastCheckSalesTime = now

    local myUid = CloudAPI.GetUserId()
    if myUid == 0 then
        callback(0, 0)
        return
    end

    if TradeManager.GetListingCount() == 0 then
        callback(0, 0)
        return
    end

    -- 扫描最近活跃的 100 个玩家
    CloudAPI:GetRankList(KEYS.mkt_ts, 0, 100, {
        ok = function(rankList)
            local soldCount = 0
            local jadeEarned = 0
            local changed = false

            for _, entry in ipairs(rankList) do
                local playerId = entry.player or entry.userId
                if playerId ~= myUid then
                    local mktData = entry.score and entry.score[KEYS.mkt_data]
                    if mktData and mktData.purchases then
                        for lk, purchase in pairs(mktData.purchases) do
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
                                    print("[TradeManager] 售出: " .. lk .. " 到账" .. netIncome .. "玉壁")
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
    }, KEYS.mkt_data)
end

function TradeManager.ResetCheckSalesCD()
    state.lastCheckSalesTime = 0
end

-- ============================================================================
-- 过期检测
-- ============================================================================

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
                print("[TradeManager] 定时重试数据同步成功")
            end
        end)
    end

    -- 自动检查收款
    if TradeManager.GetListingCount() > 0 then
        TradeManager.CheckSales()
    end
end

return TradeManager
