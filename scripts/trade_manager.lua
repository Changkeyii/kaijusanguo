-- ============================================================================
-- TradeManager - 浜ゆ槗琛岀郴缁?(鍗曚竴鍏叡甯傚満琛ㄦ灦鏋?
-- 鍩轰簬 CloudAPI 鎺掕姒?API 瀹炵幇璺ㄧ帺瀹惰澶囦氦鏄?
--
-- 鏋舵瀯璇存槑:
--   浣跨敤鍚屼竴涓?rank list (trade_ts / trade_data) 浣滀负"鍏叡甯傚満琛?
--   姣忎釜鐜╁鐨?slot 鍖呭惈: listings(涓婃灦) + purchases(璐拱璁板綍)
--   涔板璐拱鍚?鈫?鍐欏叆鑷繁 slot 鐨?purchases 鈫?鍗栧鎵弿鍏叡琛ㄥ嵆鍙彂鐜?
--   鍗栧棰嗗彇鍚?鈫?鍒犻櫎 listing + 娓呯悊鍏叡琛?
-- ============================================================================
---@diagnostic disable: undefined-global

local TradeManager = {}

local GameConfig = require("game_config")
local TRADE = GameConfig.TRADE

-- ============================================================================
-- 浜戠 Key 瀹氫箟 (鍗曚竴鍏叡甯傚満琛?
-- ============================================================================
local PREFIX = "p_49dd_"
local KEYS = {
    trade_ts   = PREFIX .. "trade_ts",    -- SetInt: 鏇存柊鏃堕棿鎴?鎺掑簭鐢?
    trade_data = PREFIX .. "trade_data",  -- Set: { listings, purchases, pendingJade, soldCount }
}

-- ============================================================================
-- 鏈湴鐘舵€?
-- ============================================================================
local state = {
    inited = false,
    -- 鎴戠殑浜ゆ槗鏁版嵁 (鍚屾鍒颁簯绔?trade_data)
    myData = {
        listings = {},      -- 鍦ㄥ敭瑁呭: { [listingKey] = { equip, price, listTime, sellerName } }
        purchases = {},     -- 鎴戠殑璐拱璁板綍(閫氱煡鍗栧): { [listingKey] = { sellerId, price, buyTime, buyerName } }
        pendingJade = 0,    -- 寰呴鍙栬檸绗?
        soldCount = 0,      -- 绱鍞嚭
    },
    -- 鍏煎鏃х増: myPurchases 鎸囧悜 myData.purchases (UI 杩囨护鐢?
    myPurchases = nil,      -- 浼氬湪 Init 涓缃负 myData.purchases 鐨勫紩鐢?
    -- 鏁版嵁鏄惁闇€瑕侀噸鏂颁笂浼?(涓婁紶澶辫触/鍚姩鏃跺緟鍚屾)
    dataNeedUpload = false,
    -- 甯傚満缂撳瓨
    marketItems = {},       -- 鏁村悎鍚庣殑甯傚満鍒楄〃
    marketLoading = false,
    marketLoaded = false,
    lastRefreshTime = 0,
    lastCheckSalesTime = 0,
    -- 宸插鐞嗙殑鍞嚭璁板綍 (閬垮厤閲嶅澶勭悊)
    processedSales = {},
}

TradeManager.state = state

-- ============================================================================
-- 鍒濆鍖?
-- ============================================================================
function TradeManager.Init()
    if state.inited then return end
    state.inited = true

    -- 浠庢湰鍦板瓨妗ｆ仮澶嶄氦鏄撴暟鎹?
    if playerInfo and playerInfo.tradeData then
        state.myData = playerInfo.tradeData
        if not state.myData.listings then state.myData.listings = {} end
        if not state.myData.purchases then state.myData.purchases = {} end
        if not state.myData.pendingJade then state.myData.pendingJade = 0 end
        if not state.myData.soldCount then state.myData.soldCount = 0 end
    end

    -- 鍏煎鏃х増: 杩佺Щ tradePurchases 鍒?myData.purchases
    if playerInfo and playerInfo.tradePurchases then
        for lk, purchase in pairs(playerInfo.tradePurchases) do
            if not state.myData.purchases[lk] then
                state.myData.purchases[lk] = purchase
            end
        end
        playerInfo.tradePurchases = nil  -- 娓呴櫎鏃у瓧娈?
        state.dataNeedUpload = true      -- 闇€瑕侀噸鏂颁笂浼犲悎骞跺悗鐨勬暟鎹?
    end

    if playerInfo and playerInfo.tradeProcessed then
        state.processedSales = playerInfo.tradeProcessed
    end

    -- myPurchases 浣滀负 myData.purchases 鐨勫紩鐢?(UI 鍏煎)
    state.myPurchases = state.myData.purchases

    -- 娓呯悊杩囨湡鏁版嵁
    TradeManager._cleanupOldData()

    print("[TradeManager] 鍒濆鍖栧畬鎴? 鍦ㄥ敭" .. TradeManager.GetListingCount() ..
          "浠? 璐拱璁板綍" .. TradeManager._countPurchases() .. "鏉?)

    -- 鍚姩鏃剁珛鍗充笂浼? 纭繚鏈湴鏁版嵁鍚屾鍒颁簯绔帓琛屾
    -- (閲嶇櫥鍚庝簯绔?slot 鍙兘涓虹┖, 蹇呴』閲嶆柊涓婁紶 listings 鎵嶈兘璁╁叾浠栫帺瀹剁湅鍒?
    if TradeManager.GetListingCount() > 0 or TradeManager._hasPendingPurchases() then
        state.dataNeedUpload = true
        TradeManager._publishMyData(function(ok)
            if ok then
                print("[TradeManager] 鍚姩鏃舵暟鎹悓姝ユ垚鍔?)
            else
                print("[TradeManager] 鍚姩鏃舵暟鎹悓姝ュけ璐? 灏嗗湪Tick涓噸璇?)
            end
        end)
    end
end

--- 淇濆瓨浜ゆ槗鏁版嵁鍒版湰鍦板瓨妗?
local function saveLocal()
    if playerInfo then
        playerInfo.tradeData = state.myData
        playerInfo.tradeProcessed = state.processedSales
        -- 娓呴櫎鏃х増瀛楁
        playerInfo.tradePurchases = nil
    end
end

-- ============================================================================
-- 鍐呴儴宸ュ叿鍑芥暟
-- ============================================================================

--- 缁熻璐拱璁板綍鏁伴噺
function TradeManager._countPurchases()
    local count = 0
    for _ in pairs(state.myData.purchases) do count = count + 1 end
    return count
end

--- 妫€鏌ユ槸鍚︽湁闇€瑕佷笂浼犵殑璐拱璁板綍
function TradeManager._hasPendingPurchases()
    return next(state.myData.purchases) ~= nil
end

--- 娓呯悊杩囨湡鏁版嵁 (7澶╁墠鐨勮喘涔拌褰曞拰宸插鐞嗚褰?
function TradeManager._cleanupOldData()
    local now = os.time()
    local CLEANUP_AGE = 7 * 86400  -- 7澶?
    local changed = false

    -- 娓呯悊鏃х殑璐拱璁板綍
    for lk, purchase in pairs(state.myData.purchases) do
        if now - (purchase.buyTime or 0) > CLEANUP_AGE then
            state.myData.purchases[lk] = nil
            changed = true
        end
    end

    -- 娓呯悊鏃х殑宸插鐞嗗敭鍑鸿褰?
    for lk, timestamp in pairs(state.processedSales) do
        if now - timestamp > CLEANUP_AGE then
            state.processedSales[lk] = nil
            changed = true
        end
    end

    if changed then
        saveLocal()
        print("[TradeManager] 娓呯悊杩囨湡鏁版嵁瀹屾垚")
    end
end

-- ============================================================================
-- 鍏叡宸ュ叿鍑芥暟
-- ============================================================================

--- 鐢熸垚涓婃灦鍞竴鏍囪瘑 key
---@param sellerId number
---@param setIdx number
---@param uid number
---@return string
local function makeListingKey(sellerId, setIdx, uid)
    return tostring(sellerId) .. "_" .. tostring(setIdx) .. "_" .. tostring(uid)
end

--- 缁熻鍦ㄥ敭鏁伴噺
function TradeManager.GetListingCount()
    local count = 0
    for _ in pairs(state.myData.listings) do count = count + 1 end
    return count
end

--- 娓呴櫎鎵€鏈変笂鏋惰褰曪紙CDK閲嶇疆鐢級
function TradeManager.ClearAllListings()
    state.myData.listings = {}
    state.myData.pendingJade = 0
    state.myData.soldCount = 0
    saveLocal()
    TradeManager._publishMyData(function(ok)
        if ok then print("[TradeManager] 浜戠涓婃灦鏁版嵁宸叉竻闄?) end
    end)
end

--- 妫€鏌ヨ澶囨槸鍚﹀彲浜ゆ槗
---@param tier number
---@return boolean, string?
function TradeManager.CanTrade(tier)
    if tier < 4 then
        return false, "浠呬警鍝佸強浠ヤ笂鍙氦鏄?
    end
    if not TRADE.PRICE_RANGE[tier] then
        return false, "璇ュ搧闃朵笉鏀寔浜ゆ槗"
    end
    return true
end

--- 鑾峰彇浠锋牸鑼冨洿
---@param tier number
---@return number, number
function TradeManager.GetPriceRange(tier)
    local range = TRADE.PRICE_RANGE[tier]
    if range then
        return range.min, range.max
    end
    return 0, 0
end

--- 璁＄畻鍒版墜閲戦 (鎵ｉ櫎鎵嬬画璐?
---@param price number
---@return number
function TradeManager.CalcNetIncome(price)
    return math.floor(price * (1 - TRADE.COMMISSION))
end

-- ============================================================================
-- 涓婃灦
-- ============================================================================

--- 涓婃灦瑁呭鍒颁氦鏄撹
---@param equipUid number 瑁呭UID
---@param price number 鍞环
---@param callback? fun(ok:boolean, msg:string)
function TradeManager.ListItem(equipUid, price, callback)
    callback = callback or function() end

    if TradeManager.GetListingCount() >= TRADE.MAX_LISTINGS then
        callback(false, "涓婃灦鏁伴噺宸茶揪涓婇檺(" .. TRADE.MAX_LISTINGS .. "浠?")
        return
    end

    local item, _ = FindOwnedByUid(equipUid)
    if not item then
        callback(false, "鏈壘鍒拌瑁呭")
        return
    end

    if playerEquipment and playerEquipment.equipped then
        for _, eqUid in pairs(playerEquipment.equipped) do
            if eqUid == equipUid then
                callback(false, "璇峰厛鍗镐笅瑁呭鍐嶄笂鏋?)
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
        callback(false, "浠锋牸闇€鍦? .. minP .. "~" .. maxP .. "铏庣涔嬮棿")
        return
    end

    local removed = RemoveOwnedByUid(equipUid)
    if not removed then
        callback(false, "绉婚櫎瑁呭澶辫触")
        return
    end

    local myUid = CloudAPI.GetUserId()
    local listingKey = makeListingKey(myUid, item.setIdx, item.uid)
    local sellerName = (playerInfo and playerInfo.nickname) or ("鐜╁" .. tostring(myUid))

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
            print("[TradeManager] 涓婃灦鎴愬姛: " .. listingKey .. " 浠锋牸" .. price)
            callback(true, "涓婃灦鎴愬姛")
        else
            -- 涓婁紶澶辫触锛屾仮澶嶈澶?
            table.insert(playerEquipment.owned, removed)
            state.myData.listings[listingKey] = nil
            saveLocal()
            if SaveGameProgress then SaveGameProgress() end
            callback(false, "浜戠鍚屾澶辫触锛岃澶囧凡鎭㈠")
        end
    end)
end

-- ============================================================================
-- 涓嬫灦 / 棰嗗彇杩囨湡
-- ============================================================================

--- 涓诲姩涓嬫灦 (灏嗚澶囪繕鍥炰粨搴?
---@param listingKey string
---@param callback? fun(ok:boolean, msg:string)
function TradeManager.UnlistItem(listingKey, callback)
    callback = callback or function() end
    local listing = state.myData.listings[listingKey]
    if not listing then
        callback(false, "鏈壘鍒拌涓婃灦璁板綍")
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
            print("[TradeManager] 涓嬫灦鎴愬姛: " .. listingKey)
            callback(true, "瑁呭宸茶繑鍥炰粨搴?)
        else
            callback(true, "瑁呭宸茶繑鍥炰粨搴?浜戠绋嶅悗鍚屾)")
        end
    end)
end

--- 棰嗗彇杩囨湡瑁呭 (涓庝笅鏋堕€昏緫鐩稿悓)
function TradeManager.ClaimExpired(listingKey, callback)
    TradeManager.UnlistItem(listingKey, callback)
end

-- ============================================================================
-- 棰嗗彇铏庣
-- ============================================================================

--- 棰嗗彇寰呮敹铏庣
---@param callback? fun(amount:number)
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
        print("[TradeManager] 棰嗗彇铏庣: " .. amount)
        callback(amount)
    end)
end

-- ============================================================================
-- 鍒锋柊甯傚満 (娴忚鍏叡甯傚満琛?
-- ============================================================================

--- 鍒锋柊甯傚満鍒楄〃
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
    local myUid = CloudAPI.GetUserId()

    -- 璇诲彇鍏叡甯傚満琛?(鎵€鏈変汉鐨?trade_data)
    CloudAPI:GetRankList(KEYS.trade_ts, 0, 200, {
        ok = function(rankList)
            local items = {}
            local nowTime = os.time()

            -- ========================================
            -- 鍚屾椂澶勭悊涓や欢浜?
            -- 1. 鎻愬彇浠栦汉鐨勪笂鏋跺垪琛?鈫?甯傚満娴忚
            -- 2. 鎵弿浠栦汉鐨勮喘涔拌褰?鈫?妫€鏌ユ垜鐨勭墿鍝佹槸鍚﹀凡鍞嚭
            -- ========================================
            local soldCount = 0
            local jadeEarned = 0
            local salesChanged = false

            for _, entry in ipairs(rankList) do
                local playerId = entry.player or entry.userId
                local tradeData = entry.score and entry.score[KEYS.trade_data]

                if tradeData then
                    local isMe = (playerId == myUid)

                    -- (1) 鎻愬彇鎵€鏈変汉鐨勪笂鏋跺垪琛紙鍖呭惈鑷繁鐨勶紝鏍囪 isMine锛?
                    if tradeData.listings then
                        for lk, listing in pairs(tradeData.listings) do
                            local elapsed = nowTime - (listing.listTime or 0)
                            if elapsed < TRADE.EXPIRE_SECONDS then
                                table.insert(items, {
                                    listingKey = lk,
                                    equip = listing.equip,
                                    price = listing.price,
                                    sellerName = listing.sellerName or ("鐜╁" .. tostring(playerId)),
                                    sellerId = playerId,
                                    listTime = listing.listTime,
                                    remainSec = TRADE.EXPIRE_SECONDS - elapsed,
                                    isMine = isMe,  -- 鏍囪鏄惁涓鸿嚜宸辩殑鍟嗗搧
                                })
                            end
                        end
                    end

                    -- (2) 鎵弿浠栦汉鐨勮喘涔拌褰?鈫?鎴戠殑鐗╁搧鏄惁宸插敭鍑猴紙鍙湅浠栦汉鏁版嵁锛?
                    if not isMe and tradeData.purchases then
                        for lk, purchase in pairs(tradeData.purchases) do
                            local pSellerId = purchase.sellerId
                            -- 鍏煎 JSON 瑙ｇ爜鍚?sellerId 鍙兘涓?string
                            if type(pSellerId) == "string" then pSellerId = tonumber(pSellerId) end
                            if pSellerId == myUid and state.myData.listings[lk] then
                                if not state.processedSales[lk] then
                                    local listing = state.myData.listings[lk]
                                    local netIncome = TradeManager.CalcNetIncome(listing.price)
                                    state.myData.pendingJade = (state.myData.pendingJade or 0) + netIncome
                                    state.myData.soldCount = (state.myData.soldCount or 0) + 1
                                    state.myData.listings[lk] = nil  -- 绉婚櫎宸插敭
                                    state.processedSales[lk] = os.time()
                                    soldCount = soldCount + 1
                                    jadeEarned = jadeEarned + netIncome
                                    salesChanged = true
                                    print("[TradeManager] 鍞嚭: " .. lk .. " 鍒拌处" .. netIncome .. "铏庣")
                                end
                            end
                        end
                    end
                end
            end

            -- 杩囨护鎺夎嚜宸卞凡鍞嚭/宸蹭笅鏋剁殑鍟嗗搧
            -- (浜戠鏁版嵁鍙兘灏氭湭鏇存柊, 浣嗘湰鍦?listings 宸茬Щ闄?
            do
                local filtered = {}
                for _, it in ipairs(items) do
                    if not (it.isMine and not state.myData.listings[it.listingKey]) then
                        filtered[#filtered + 1] = it
                    end
                end
                items = filtered
            end

            -- 鎸夊搧闃堕檷搴? 鍚屽搧闃舵寜浠锋牸鍗囧簭
            table.sort(items, function(a, b)
                if a.equip.tier ~= b.equip.tier then return a.equip.tier > b.equip.tier end
                return a.price < b.price
            end)

            state.marketItems = items
            state.marketLoaded = true
            state.lastRefreshTime = os.time()
            state.lastCheckSalesTime = os.time()  -- RefreshMarket 宸插寘鍚?CheckSales
            print("[TradeManager] 甯傚満鍒锋柊瀹屾垚, " .. #items .. "浠跺湪鍞?)

            -- 濡傛灉鍙戠幇鏈夊敭鍑? 淇濆瓨骞朵笂浼?
            if salesChanged then
                saveLocal()
                if SaveGameProgress then SaveGameProgress() end
                TradeManager._publishMyData()
                print("[TradeManager] 鍙戠幇" .. soldCount .. "绗斿敭鍑? 鍏? .. jadeEarned .. "铏庣寰呴鍙?)
            end

            -- 鎵归噺瑙ｆ瀽鍗栧鏄电О
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
                    print("[TradeManager] GetUserNickname寮傚父: " .. tostring(nickErr))
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
            print("[TradeManager] 甯傚満鍒锋柊澶辫触: " .. tostring(reason))
            callback(state.marketItems)
        end,
    }, KEYS.trade_data)
end

-- ============================================================================
-- 璐拱
-- ============================================================================

--- 璐拱瑁呭 (鍚埛鏂伴獙璇?
---@param listingKey string
---@param expectedSellerId number
---@param expectedPrice number
---@param callback fun(ok:boolean, msg:string)
function TradeManager.BuyItem(listingKey, expectedSellerId, expectedPrice, callback)
    callback = callback or function() end

    -- 闃叉鑷喘
    local myUid = CloudAPI.GetUserId()
    if expectedSellerId == myUid then
        callback(false, "涓嶈兘璐拱鑷繁涓婃灦鐨勮澶?)
        return
    end

    if (playerInfo.jade or 0) < expectedPrice then
        callback(false, "铏庣涓嶈冻")
        return
    end

    -- 鍒锋柊楠岃瘉: 閲嶆柊鎷夊彇鍏叡甯傚満琛? 纭 listing 浠嶅瓨鍦?
    state.marketLoading = true
    CloudAPI:GetRankList(KEYS.trade_ts, 0, 200, {
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
                callback(false, "璇ヨ澶囧凡琚叾浠栫帺瀹朵拱涓嬫垨宸蹭笅鏋?)
                state.lastRefreshTime = 0
                return
            end

            if listing.price ~= expectedPrice then
                callback(false, "浠锋牸宸插彉鍔?璇峰埛鏂板悗閲嶈瘯")
                state.lastRefreshTime = 0
                return
            end

            -- 鎵ｉ櫎铏庣
            playerInfo.jade = playerInfo.jade - expectedPrice

            -- 鍒涘缓瑁呭鍒颁拱瀹朵粨搴?
            local eq = listing.equip
            local newItem = CreateEquipItem(eq.setIdx, eq.slotIdx, eq.tier, eq.quality, eq.level)
            newItem.enhanceLv = eq.enhanceLv or 0

            -- 鍐欏叆璐拱璁板綍鍒板叕鍏卞競鍦鸿〃 (鏍囪宸插嚭鍞?
            local buyerName = (playerInfo and playerInfo.nickname) or ("鐜╁" .. tostring(myUid))
            state.myData.purchases[listingKey] = {
                sellerId = expectedSellerId,
                price = expectedPrice,
                buyTime = os.time(),
                buyerName = buyerName,
            }
            state.dataNeedUpload = true  -- 鏍囪寰呬笂浼?

            saveLocal()
            if SaveGameProgress then SaveGameProgress() end

            -- 涓婁紶鍒板叕鍏卞競鍦鸿〃
            TradeManager._publishMyData(function(ok)
                if ok then
                    print("[TradeManager] 璐拱璁板綍宸蹭笂浼? " .. listingKey)
                else
                    print("[TradeManager] 璐拱璁板綍涓婁紶澶辫触,灏嗗湪Tick閲嶈瘯: " .. listingKey)
                end
            end)

            -- 鍒锋柊甯傚満缂撳瓨
            state.lastRefreshTime = 0

            callback(true, "璐拱鎴愬姛! " .. EQUIP_TIER_NAMES[eq.tier] .. " " ..
                EQUIP_SLOT_NAMES[eq.slotIdx] .. " 宸插姞鍏ヤ粨搴?)
        end,
        error = function(code, reason)
            state.marketLoading = false
            callback(false, "缃戠粶閿欒,璇风◢鍚庨噸璇?)
        end,
    }, KEYS.trade_data)
end

-- ============================================================================
-- 鍗栧鏀舵 (鎵弿鍏叡甯傚満琛ㄤ腑鐨勮喘涔拌褰?
-- ============================================================================

--- 鎵弿鍏叡甯傚満琛? 妫€鏌ユ垜鐨勪笂鏋剁墿鍝佹槸鍚﹀凡琚喘涔?
---@param callback? fun(soldCount:number, jadeEarned:number)
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

    -- 璇诲彇鍚屼竴涓叕鍏卞競鍦鸿〃
    CloudAPI:GetRankList(KEYS.trade_ts, 0, 200, {
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
                                    print("[TradeManager] 鍞嚭: " .. lk .. " 鍒拌处" .. netIncome .. "铏庣")
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

--- 閲嶇疆 CheckSales 鍐峰嵈 (杩涘叆浜ゆ槗琛屾椂璋冪敤)
function TradeManager.ResetCheckSalesCD()
    state.lastCheckSalesTime = 0
end

-- ============================================================================
-- 杩囨湡妫€娴?
-- ============================================================================

--- 鑾峰彇杩囨湡鐨勪笂鏋跺垪琛?
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

--- 鑾峰彇鍦ㄥ敭(鏈繃鏈?鐨勪笂鏋跺垪琛?
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
-- 瀹氭椂浠诲姟 (鍦?HandleUpdate 涓皟鐢?
-- ============================================================================

local tickAccum = 0
function TradeManager.Tick(dt)
    if not state.inited then return end
    tickAccum = tickAccum + dt
    if tickAccum < 30 then return end
    tickAccum = 0

    -- 閲嶈瘯澶辫触鐨勬暟鎹笂浼?
    if state.dataNeedUpload then
        TradeManager._publishMyData(function(ok)
            if ok then
                print("[TradeManager] 鏁版嵁閲嶈瘯涓婁紶鎴愬姛")
            end
        end)
    end

    -- 鑷姩妫€鏌ユ敹娆?
    if TradeManager.GetListingCount() > 0 then
        TradeManager.CheckSales()
    end
end

-- ============================================================================
-- 浜戠鍚屾 (鍗曚竴涓婁紶鍑芥暟)
-- ============================================================================

--- 涓婁紶鎴戠殑浜ゆ槗鏁版嵁鍒板叕鍏卞競鍦鸿〃 (listings + purchases + pendingJade + soldCount)
---@param callback? fun(ok:boolean)
function TradeManager._publishMyData(callback)
    callback = callback or function() end
    if not CloudAPI.IsAvailable() then callback(false) return end

    CloudAPI:BatchSet()
        :SetInt(KEYS.trade_ts, os.time())
        :Set(KEYS.trade_data, state.myData)
        :Save("浜ゆ槗琛?鏁版嵁鍚屾", {
            ok = function()
                state.dataNeedUpload = false
                callback(true)
            end,
            error = function(code, reason)
                print("[TradeManager] 涓婁紶浜ゆ槗鏁版嵁澶辫触: " .. tostring(reason))
                state.dataNeedUpload = true  -- 鏍囪闇€閲嶈瘯
                callback(false)
            end,
        })
end

return TradeManager

