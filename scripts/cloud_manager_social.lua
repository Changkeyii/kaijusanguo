-- ============================================================================
-- cloud_manager_social.lua - 涓夊浗姝︾伒褰?(浠?cloud_manager.lua 鎷嗗垎)
-- 绀句氦绯荤粺: 鍏紑璧勬枡銆佸ソ鍙嬨€佸叕浼?闃佃惀)
-- ============================================================================
---@diagnostic disable: undefined-global

-- 浠?core 妯″潡瀵煎叆甯搁噺鍜屽叡浜姸鎬?
local C = CloudManager._C
local S = CloudManager._S
local KEYS = C.KEYS
local DOMAINS = C.DOMAINS
local MAX_FRIENDS = C.MAX_FRIENDS
local REQUEST_EXPIRE_SECONDS = C.REQUEST_EXPIRE_SECONDS
local MAX_OUTBOX = C.MAX_OUTBOX
local MAX_CAMP_MEMBERS = C.MAX_CAMP_MEMBERS
local CAMP_CREATE_COST = C.CAMP_CREATE_COST
local FACTION_ROLES = C.FACTION_ROLES
local ROLE_SUCCESSION = C.ROLE_SUCCESSION
local BAN_LEVEL_SOCIAL = C.BAN_LEVEL_SOCIAL
local BAN_LEVEL_CORE = C.BAN_LEVEL_CORE
local COOLDOWN_FRIEND_REQUEST = C.COOLDOWN_FRIEND_REQUEST
local COOLDOWN_PROFILE_PUBLISH = C.COOLDOWN_PROFILE_PUBLISH
local COOLDOWN_REJECTED_RETRY = C.COOLDOWN_REJECTED_RETRY
local _getRoleLevel = C._getRoleLevel
local _getRoleName = C._getRoleName
local _hasAuthorityOver = C._hasAuthorityOver
local _countRole = C._countRole

local function _getRankItemUserId(item)
    if rawget(_G, "ResolveRankListUserId") then
        return ResolveRankListUserId(item)
    end
    return tonumber(item and (item.userId or item.player or item.uid)) or 0
end

-- ============================================================================
-- 鍏紑妗ｆ
-- ============================================================================

--- 鍙戝竷鍏紑妗ｆ (鑷姩浠庡叏灞€鍙橀噺鎻愬彇, 鏈夐鐜囬檺鍒?
function CloudManager._publishProfile(allData)
    if not CloudAPI.IsAvailable() then return end
    -- 灏佺妫€鏌?
    if S.banLevel >= BAN_LEVEL_CORE then return end
    -- 棰戠巼闄愬埗
    if not CloudManager._checkCooldown("publish_profile", COOLDOWN_PROFILE_PUBLISH) then return end

    local coreData = allData and allData.core or CloudManager.CollectDomainData("core")
    local pi = coreData.playerInfo or {}

    -- 鏋勫缓杞婚噺鍏紑璧勬枡
    local profile = {
        heroLineup = {},
        skillLineup = {},
        mainEquipTier = 0,
        level = pi.rankIdx or 1,
        totalWins = pi.totalWins or 0,
        totalBattles = pi.totalBattles or 0,
        avatarIdx = pi.avatarIdx or 1,
        factionId = CloudManager._factionId or 0,
        factionName = CloudManager._factionName or "",
        updatedAt = os.time(),
    }

    -- 涓婇樀姝︾伒
    if rawget(_G, "playerHeroes") then
        for idx, hero in pairs(playerHeroes) do
            if hero.owned then
                profile.heroLineup[#profile.heroLineup + 1] = tonumber(idx) or idx
            end
        end
        -- 鍙繚鐣欏墠6涓?
        while #profile.heroLineup > 6 do table.remove(profile.heroLineup) end
    end

    -- 瑁呭姝︽妧
    if rawget(_G, "playerEquippedSkills") then
        for _, skillIdx in ipairs(playerEquippedSkills) do
            profile.skillLineup[#profile.skillLineup + 1] = skillIdx
        end
    end

    -- 鏈€楂樿澶囧搧闃?
    if rawget(_G, "playerEquipment") and playerEquipment.owned then
        for _, item in ipairs(playerEquipment.owned) do
            if item.tier and item.tier > profile.mainEquipTier then
                profile.mainEquipTier = item.tier
            end
        end
    end

    -- 璁＄畻鎴樺姏 (涓庣幇鏈夐€昏緫淇濇寔涓€鑷?
    local combatPower = 0
    if rawget(_G, "CalcPlayerTotalPower") then
        combatPower = CalcPlayerTotalPower() or 0
    else
        combatPower = (pi.rankIdx or 1) * 100 + (pi.totalWins or 0) * 10
    end

    -- BatchSet: 鍏紑璧勬枡 + 鎴樺姏鎺掕
    CloudAPI:BatchSet()
        :Set(KEYS.pub_profile, profile)
        :SetInt(KEYS.combat_power, combatPower)
        :SetInt(KEYS.realm_level, pi.rankIdx or 1)
        :Save("鍙戝竷鍏紑妗ｆ")
end

--- 鎵嬪姩鍙戝竷鍏紑妗ｆ
function CloudManager.PublishProfile()
    CloudManager._publishProfile(nil)
end

--- 鑾峰彇鍏朵粬鐜╁鐨勫叕寮€妗ｆ (閫氳繃鎴樺姏鎺掕姒?
---@param start number 璧峰浣嶇疆 (0寮€濮?
---@param count number 鑾峰彇鏁伴噺
---@param callback fun(profiles: table[])
function CloudManager.GetPublicProfiles(start, count, callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end

    CloudAPI:GetRankList(KEYS.combat_power, start, count, {
        ok = function(rankList)
            local profiles = {}
            local userIds = {}

            for i, item in ipairs(rankList) do
                local profile = item.score[KEYS.pub_profile] or {}
                local uid = _getRankItemUserId(item)
                local entry = {
                    rank = start + i,
                    userId = uid,
                    combatPower = (item.iscore and item.iscore[KEYS.combat_power]) or 0,
                    realmLevel = (item.iscore and item.iscore[KEYS.realm_level]) or 1,
                    profile = profile,
                    nickname = "",
                    isMe = uid == CloudAPI.GetUserId(),
                }
                profiles[#profiles + 1] = entry
                userIds[#userIds + 1] = entry.userId
            end

            -- 鎵归噺鏌ヨ鏄电О
            if #userIds > 0 and rawget(_G, "GetUserNickname") then
                GetUserNickname({
                    userIds = userIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do
                            map[info.userId] = info.nickname or ""
                        end
                        for _, entry in ipairs(profiles) do
                            entry.nickname = map[entry.userId] or "鏈煡"
                        end
                        if callback then callback(profiles) end
                    end,
                    onError = function()
                        if callback then callback(profiles) end
                    end,
                })
            else
                if callback then callback(profiles) end
            end
        end,
        error = function(code, reason)
            print("[CloudManager] 鑾峰彇鎺掕姒滃け璐? " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.pub_profile, KEYS.realm_level)
end

-- ============================================================================
-- 濂藉弸绯荤粺 (鍏叡鐢宠姹犳ā鍨?鈥?瀹夊叏鐗?
-- 鏍稿績: 鎺掕姒滃仛鍏叡淇＄, 姣忎汉鍙啓鑷繁鏁版嵁, 姘镐笉鍐欏埆浜哄瓨妗?
-- ============================================================================

CloudManager._friendIds = {}           -- 宸茬‘璁ゅソ鍙?{ userId1, userId2, ... }
CloudManager._outgoingRequests = {}    -- 鏈湴缂撳瓨: 鎴戝彂鍑虹殑鐢宠 { [toUid]={time=ts}, ... }
CloudManager._outgoingResponses = {}   -- 鏈湴缂撳瓨: 鎴戠殑鍥炲 { [toUid]={accepted=bool, time=ts}, ... }

-- 鈹€鈹€ 宸ュ叿: 杩囨湡娓呯悊 鈹€鈹€

local function _purgeExpired(tbl)
    local now = os.time()
    local removed = 0
    for uid, entry in pairs(tbl) do
        if entry.time and (now - entry.time) > REQUEST_EXPIRE_SECONDS then
            tbl[uid] = nil
            removed = removed + 1
        end
    end
    return removed
end

local function _tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- 鈹€鈹€ 鍒濆鍖栨椂浠庝簯绔媺鍙栬嚜宸辩殑鍑虹珯淇＄ 鈹€鈹€

function CloudManager._loadMyOutbox(callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback() end
        return
    end
    CloudAPI:BatchGet()
        :Key(KEYS.freq_outbox)
        :Key(KEYS.freq_resp)
        :Key(KEYS.camp_apply)
        :Key(KEYS.camp_resp)
        :Key(KEYS.camp_meta)
        :Fetch({
            ok = function(values, _)
                -- 濂藉弸鍑虹珯
                if values[KEYS.freq_outbox] then
                    CloudManager._outgoingRequests = values[KEYS.freq_outbox] or {}
                    _purgeExpired(CloudManager._outgoingRequests)
                end
                if values[KEYS.freq_resp] then
                    CloudManager._outgoingResponses = values[KEYS.freq_resp] or {}
                    _purgeExpired(CloudManager._outgoingResponses)
                end
                -- 闃佃惀鍑虹珯
                if values[KEYS.camp_apply] and type(values[KEYS.camp_apply]) == "table"
                   and values[KEYS.camp_apply].campId then
                    CloudManager._campOutApply = values[KEYS.camp_apply]
                end
                if values[KEYS.camp_resp] and type(values[KEYS.camp_resp]) == "table" then
                    CloudManager._campOutResp = values[KEYS.camp_resp]
                end
                -- 鐩熶富闃佃惀鍏冩暟鎹?
                if values[KEYS.camp_meta] and type(values[KEYS.camp_meta]) == "table"
                   and values[KEYS.camp_meta].id then
                    CloudManager._factionMeta = values[KEYS.camp_meta]
                end
                print("[绀句氦] 鍑虹珯淇＄宸插姞杞? 濂藉弸鐢宠=" .. _tableCount(CloudManager._outgoingRequests)
                    .. " 濂藉弸鍥炲=" .. _tableCount(CloudManager._outgoingResponses)
                    .. " 闃佃惀鐢宠=" .. (CloudManager._campOutApply and "鏈? or "鏃?))
                -- 闃佃惀缁т綅妫€娴? 濡傛灉鏈夐樀钀ュ綊灞? 鑷姩妫€鏌ユ槸鍚﹀彂鐢熶簡鐩熶富杞
                if CloudManager._factionId ~= 0 then
                    CloudManager._refreshFactionStatus()
                end
                if callback then callback() end
            end,
            error = function(_, reason)
                print("[绀句氦] 鍔犺浇鍑虹珯淇＄澶辫触: " .. tostring(reason))
                if callback then callback() end
            end,
        })
end

-- 鈹€鈹€ 鍙戝竷鑷繁鐨勫嚭绔欎俊绠卞埌鎺掕姒?鈹€鈹€

function CloudManager._publishOutbox()
    if not CloudAPI.IsAvailable() then return end
    _purgeExpired(CloudManager._outgoingRequests)
    CloudAPI:BatchSet()
        :SetInt(KEYS.freq_outbox_ts, os.time())
        :Set(KEYS.freq_outbox, CloudManager._outgoingRequests)
        :Save("鍙戝竷濂藉弸鐢宠鍑虹珯")
end

function CloudManager._publishResponses()
    if not CloudAPI.IsAvailable() then return end
    _purgeExpired(CloudManager._outgoingResponses)
    CloudAPI:BatchSet()
        :SetInt(KEYS.freq_resp_ts, os.time())
        :Set(KEYS.freq_resp, CloudManager._outgoingResponses)
        :Save("鍙戝竷濂藉弸鍥炲")
end

-- 鈹€鈹€ 鍙戦€佸ソ鍙嬬敵璇?鈹€鈹€

--- 鍚戠洰鏍囩帺瀹跺彂閫佸ソ鍙嬬敵璇?(鍐欏叆鑷繁鐨勫嚭绔欎俊绠?
---@param targetUserId number
---@param message? string 鐢宠鐣欒█
---@return boolean success
---@return string? reason
function CloudManager.SendFriendRequest(targetUserId, message)
    -- 灏佺妫€鏌? 绀句氦灏佺鍙婁互涓婄姝?
    if S.banLevel >= BAN_LEVEL_SOCIAL then
        return false, "绀句氦鍔熻兘宸茶闄愬埗"
    end
    if not targetUserId or targetUserId == 0 then
        return false, "鏃犳晥鐨勭敤鎴稩D"
    end
    local myUid = CloudAPI.GetUserId()
    if targetUserId == myUid then
        return false, "涓嶈兘娣诲姞鑷繁"
    end
    -- 棰戠巼闄愬埗
    if not CloudManager._checkCooldown("friend_request", COOLDOWN_FRIEND_REQUEST) then
        return false, "鎿嶄綔杩囦簬棰戠箒, 璇? .. COOLDOWN_FRIEND_REQUEST .. "绉掑悗鍐嶈瘯"
    end
    -- 宸叉槸濂藉弸
    if CloudManager.IsFriend(targetUserId) then
        return false, "宸叉槸濂藉弸"
    end
    -- 宸叉湁寰呭鐞嗙敵璇?(7澶╁唴闃查噸澶?
    local uidKey = tostring(targetUserId)
    if CloudManager._outgoingRequests[uidKey] then
        return false, "宸插彂閫佽繃鐢宠, 绛夊緟瀵规柟鍥炲簲"
    end
    -- 琚嫆缁濆喎鍗? 24灏忔椂鍐呬笉鑳介噸澶嶇敵璇峰悓涓€浜?
    local rejectTime = S.rejectedByCache[uidKey]
    if rejectTime and (os.time() - rejectTime) < COOLDOWN_REJECTED_RETRY then
        local remaining = COOLDOWN_REJECTED_RETRY - (os.time() - rejectTime)
        local hours = math.ceil(remaining / 3600)
        return false, "瀵规柟鏇炬嫆缁濅綘鐨勭敵璇? " .. hours .. "灏忔椂鍚庡彲閲嶈瘯"
    end
    -- 鍑虹珯涓婇檺
    if _tableCount(CloudManager._outgoingRequests) >= MAX_OUTBOX then
        _purgeExpired(CloudManager._outgoingRequests)
        if _tableCount(CloudManager._outgoingRequests) >= MAX_OUTBOX then
            return false, "寰呭鐞嗙敵璇疯繃澶? 璇风瓑寰呭洖搴旀垨娓呯悊"
        end
    end

    CloudManager._outgoingRequests[uidKey] = {
        time = os.time(),
        msg = message or "",
    }
    CloudManager._publishOutbox()
    print("[濂藉弸] 宸插彂閫佺敵璇风粰 " .. uidKey)
    return true
end

-- 鈹€鈹€ 鎷夊彇鍙戠粰鎴戠殑濂藉弸鐢宠 (鎵弿鎵€鏈変汉鐨勫嚭绔欎俊绠? 鈹€鈹€

--- 妫€鏌ユ敹鍒扮殑濂藉弸鐢宠
---@param callback fun(requests: table[]) {fromUid, time, msg, nickname}
function CloudManager.CheckIncomingRequests(callback)
    if S.banLevel >= BAN_LEVEL_SOCIAL then
        if callback then callback({}) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end
    local myUid = CloudAPI.GetUserId()

    -- 鎵弿 freq_outbox_ts 鎺掕姒?(鎸夋渶杩戞洿鏂版帓搴? 鎷?00浜?
    CloudAPI:GetRankList(KEYS.freq_outbox_ts, 0, 200, {
        ok = function(rankList)
            local incoming = {}
            local senderIds = {}
            local myUidStr = tostring(myUid)

            for _, item in ipairs(rankList) do
                local senderId = _getRankItemUserId(item)
                if senderId ~= myUid then
                    local outbox = item.score[KEYS.freq_outbox]
                    if type(outbox) == "table" and outbox[myUidStr] then
                        local req = outbox[myUidStr]
                        -- 妫€鏌ヨ繃鏈?
                        if req.time and (os.time() - req.time) <= REQUEST_EXPIRE_SECONDS then
                            -- 鎺掗櫎宸叉槸濂藉弸 & 宸插洖澶嶇殑
                            if not CloudManager.IsFriend(senderId)
                               and not CloudManager._outgoingResponses[tostring(senderId)] then
                                table.insert(incoming, {
                                    fromUid = senderId,
                                    time = req.time,
                                    msg = req.msg or "",
                                    nickname = "",
                                })
                                table.insert(senderIds, senderId)
                            end
                        end
                    end
                end
            end

            -- 鎵归噺鏌ユ樀绉?
            if #senderIds > 0 and rawget(_G, "GetUserNickname") then
                GetUserNickname({
                    userIds = senderIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do
                            map[info.userId] = info.nickname or ""
                        end
                        for _, r in ipairs(incoming) do
                            r.nickname = map[r.fromUid] or "鏈煡"
                        end
                        if callback then callback(incoming) end
                    end,
                    onError = function()
                        if callback then callback(incoming) end
                    end,
                })
            else
                if callback then callback(incoming) end
            end
        end,
        error = function(_, reason)
            print("[濂藉弸] 鎵弿鍏ョ珯鐢宠澶辫触: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.freq_outbox)
end

-- 鈹€鈹€ 鍚屾剰濂藉弸鐢宠 鈹€鈹€

--- 鍚屾剰鏉ヨ嚜 fromUserId 鐨勫ソ鍙嬬敵璇?
---@param fromUserId number
---@return boolean
function CloudManager.AcceptFriendRequest(fromUserId)
    if S.banLevel >= BAN_LEVEL_SOCIAL then return false end
    if not fromUserId or fromUserId == 0 then return false end
    if CloudManager.IsFriend(fromUserId) then return false end
    if #CloudManager._friendIds >= MAX_FRIENDS then
        print("[濂藉弸] 濂藉弸鏁板凡婊?" .. MAX_FRIENDS)
        return false
    end

    -- 1. 鍔犲叆鑷繁濂藉弸鍒楄〃
    table.insert(CloudManager._friendIds, fromUserId)

    -- 2. 鍙戝竷鍥炲鍒拌嚜宸辩殑 resp 淇＄ (瀵规柟涓嬫鐧诲綍浼氭壂鍒?
    CloudManager._outgoingResponses[tostring(fromUserId)] = {
        accepted = true,
        time = os.time(),
    }
    CloudManager._publishResponses()
    CloudManager._syncSocialDomain()

    print("[濂藉弸] 宸插悓鎰?" .. tostring(fromUserId) .. " 鐨勭敵璇? 褰撳墠濂藉弸 " .. #CloudManager._friendIds .. " 浜?)
    return true
end

--- 鎷掔粷鏉ヨ嚜 fromUserId 鐨勫ソ鍙嬬敵璇?(浠呮爣璁? 涓嶅姞濂藉弸)
---@param fromUserId number
function CloudManager.RejectFriendRequest(fromUserId)
    if not fromUserId or fromUserId == 0 then return end
    CloudManager._outgoingResponses[tostring(fromUserId)] = {
        accepted = false,
        time = os.time(),
    }
    CloudManager._publishResponses()
    print("[濂藉弸] 宸叉嫆缁?" .. tostring(fromUserId) .. " 鐨勭敵璇?)
end

-- 鈹€鈹€ 妫€鏌ユ垜鍙戝嚭鐨勭敵璇风殑鍥炲 (鑷姩瀹屾垚鍙屽悜鍔犲ソ鍙? 鈹€鈹€

--- 妫€鏌ユ垜鍙戝嚭鐨勭敵璇锋槸鍚﹁瀵规柟鍥炲, 鑷姩瀹屾垚浜掑姞
---@param callback? fun(results: table[]) {toUid, accepted, nickname}
function CloudManager.CheckMyRequestResponses(callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end
    local myUid = CloudAPI.GetUserId()
    local myUidStr = tostring(myUid)

    -- 鎴戞湁鍝簺寰呭鐞嗙殑鍑虹珯鐢宠?
    local pendingUids = {}
    for uidStr, _ in pairs(CloudManager._outgoingRequests) do
        table.insert(pendingUids, tonumber(uidStr))
    end
    if #pendingUids == 0 then
        if callback then callback({}) end
        return
    end

    -- 鎵弿 freq_resp_ts 鎺掕姒? 鎵惧鏂圭殑鍥炲
    CloudAPI:GetRankList(KEYS.freq_resp_ts, 0, 200, {
        ok = function(rankList)
            local results = {}
            local completedUids = {}

            for _, item in ipairs(rankList) do
                local responder = _getRankItemUserId(item)
                local respData = item.score[KEYS.freq_resp]
                if type(respData) == "table" and respData[myUidStr] then
                    local resp = respData[myUidStr]
                    if resp.accepted then
                        -- 瀵规柟鍚屾剰浜? 鍔犲叆鎴戠殑濂藉弸鍒楄〃
                        if not CloudManager.IsFriend(responder)
                           and #CloudManager._friendIds < MAX_FRIENDS then
                            table.insert(CloudManager._friendIds, responder)
                            table.insert(completedUids, responder)
                        end
                    else
                        -- 瀵规柟鎷掔粷浜? 璁板綍鍒拌鎷掔紦瀛?(24h鍐峰嵈)
                        S.rejectedByCache[tostring(responder)] = os.time()
                    end
                    table.insert(results, {
                        toUid = responder,
                        accepted = resp.accepted or false,
                    })
                    -- 浠庡嚭绔欎俊绠辩Щ闄ゅ凡澶勭悊鐨?
                    CloudManager._outgoingRequests[tostring(responder)] = nil
                end
            end

            -- 濡傛灉鏈夋柊澧炲ソ鍙? 鍚屾
            if #completedUids > 0 then
                CloudManager._publishOutbox()  -- 鏇存柊鍑虹珯 (绉婚櫎宸插鐞?
                CloudManager._syncSocialDomain()
                print("[濂藉弸] 鑷姩浜掑姞瀹屾垚: +" .. #completedUids .. " 浜?)
            end

            if callback then callback(results) end
        end,
        error = function(_, reason)
            print("[濂藉弸] 鎵弿鍥炲澶辫触: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.freq_resp)
end

-- 鈹€鈹€ 闅忔満鎺ㄨ崘鐜╁ 鈹€鈹€

--- 浠庢垬鍔涙帓琛屾闅忔満鎶藉彇 count 涓帺瀹?(鎺掗櫎鑷繁鍜屽凡鏈夊ソ鍙?
---@param count number
---@param callback fun(players: table[])
function CloudManager.GetRandomPlayers(count, callback)
    count = count or 10
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end

    -- 鍏堣幏鍙栨帓琛屾鎬讳汉鏁?
    CloudAPI:GetRankTotal(KEYS.combat_power, {
        ok = function(total)
            if total <= 0 then
                if callback then callback({}) end
                return
            end
            -- 闅忔満鍋忕Щ, 鎷?count*3 鏉?(鐣欎綑閲忚繃婊?
            local fetchCount = math.min(total, count * 3, 200)
            local maxStart = math.max(0, total - fetchCount)
            local startPos = math.random(0, maxStart)

            CloudManager.GetPublicProfiles(startPos, fetchCount, function(profiles)
                -- 杩囨护鑷繁銆佸ソ鍙嬨€?澶╂湭鍦ㄧ嚎
                local myUid = CloudAPI.GetUserId()
                local now = os.time()
                local friendSet = {}
                for _, fid in ipairs(CloudManager._friendIds) do friendSet[fid] = true end

                local candidates = {}
                for _, p in ipairs(profiles) do
                    if p.userId ~= myUid and not friendSet[p.userId] then
                        local updatedAt = (p.profile and p.profile.updatedAt) or 0
                        if updatedAt > 0 and (now - updatedAt) <= 3 * 86400 then
                            table.insert(candidates, p)
                        end
                    end
                end

                -- 闅忔満鎵撲贡 & 鎴彇
                for i = #candidates, 2, -1 do
                    local j = math.random(1, i)
                    candidates[i], candidates[j] = candidates[j], candidates[i]
                end
                local result = {}
                for i = 1, math.min(count, #candidates) do
                    result[i] = candidates[i]
                end
                if callback then callback(result) end
            end)
        end,
        error = function()
            if callback then callback({}) end
        end,
    })
end

--- 鎼滅储鐜╁ (鎸塽serId绮剧‘鍖归厤)
---@param targetUserId number
---@param callback fun(player: table|nil)
function CloudManager.SearchPlayer(targetUserId, callback)
    if not CloudAPI.IsAvailable() or not targetUserId then
        if callback then callback(nil) end
        return
    end

    -- 閫氳繃 GetUserRank 鏌ユ壘
    CloudAPI:GetUserRank(targetUserId, KEYS.combat_power, {
        ok = function(rank, scoreValue)
            if not rank then
                if callback then callback(nil) end
                return
            end
            -- 鎵惧埌浜? 鎷夊彇璇︾粏璧勬枡 (浠庢帓琛屾鍋忕Щ)
            local startPos = math.max(0, rank - 1)
            CloudManager.GetPublicProfiles(startPos, 1, function(profiles)
                local found = nil
                for _, p in ipairs(profiles) do
                    if p.userId == targetUserId then
                        found = p
                        break
                    end
                end
                if callback then callback(found) end
            end)
        end,
        error = function()
            if callback then callback(nil) end
        end,
    })
end

-- 鈹€鈹€ 濂藉弸绠＄悊 鈹€鈹€

--- 绉婚櫎濂藉弸
---@param userId number
---@return boolean
function CloudManager.RemoveFriend(userId)
    for i, id in ipairs(CloudManager._friendIds) do
        if id == userId then
            table.remove(CloudManager._friendIds, i)
            CloudManager._syncSocialDomain()
            print("[濂藉弸] 绉婚櫎濂藉弸: " .. tostring(userId))
            return true
        end
    end
    return false
end

--- 鑾峰彇濂藉弸ID鍒楄〃
---@return number[]
function CloudManager.GetFriendIds()
    return CloudManager._friendIds
end

-- ============================================================================
-- 闃佃惀鍏绘垚绯荤粺 (鍗囩骇 / 鎹愮尞 / 鍏憡)
-- ============================================================================

-- 闃佃惀绛夌骇缁忛獙琛? 鍗囧埌璇ョ瓑绾ф墍闇€鐨勭疮璁＄粡楠?
-- 鍏紡: Lv N 鈫?鎴愬憳涓婇檺 (10+10N), 姣忎汉鎹?N脳10000, 鍗曠骇闇€ (10+10N)脳N脳10000
local FACTION_LEVEL_EXP = {
    [1]  = 0,          -- 璧峰
    [2]  = 200000,     -- 20浜好?w = 20w
    [3]  = 800000,     -- +30浜好?w = +60w
    [4]  = 2000000,    -- +40浜好?w = +120w
    [5]  = 4000000,    -- +50浜好?w = +200w
    [6]  = 7000000,    -- +60浜好?w = +300w
    [7]  = 11200000,   -- +70浜好?w = +420w
    [8]  = 16800000,   -- +80浜好?w = +560w
    [9]  = 24000000,   -- +90浜好?w = +720w
    [10] = 33000000,   -- +100浜好?w = +900w
}
-- 闃佃惀姣忕骇鎴愬憳涓婇檺: Lv N 鈫?10 + 10脳N
local FACTION_LEVEL_MAX_MEMBERS = {
    [1]  = 20,  [2]  = 30,  [3]  = 40,  [4]  = 50,  [5]  = 60,
    [6]  = 70,  [7]  = 80,  [8]  = 90,  [9]  = 100, [10] = 100,
}
local FACTION_MAX_LEVEL = 10
local FACTION_DONATE_MIN = 100         -- 鍗曟鏈€灏戞崘鐚?

-- 鑱屼綅棰濆鍔犳垚绯绘暟 (姣忛樀钀ョ瓑绾ч澶?x%鎴樺姏, 鐩熶富鏈€楂? 鎴愬憳鏃犻澶?
local ROLE_BUFF_PER_LEVEL = {
    leader      = 0.6,
    vice_leader = 0.5,
    strategist  = 0.4,
    vanguard    = 0.3,
    diplomat    = 0.2,
    elite       = 0.1,
    member      = 0,
}

--- 鑾峰彇闃佃惀绛夌骇淇℃伅
---@return table { level, exp, nextExp, maxLevel, buffPercent, roleBonusPercent, totalBuffPercent }
function CloudManager.GetFactionLevelInfo()
    local meta = CloudManager._factionMeta
    local lv = (meta and meta.level) or 1
    local exp = (meta and meta.exp) or 0
    if lv < 1 then lv = 1 end
    if lv > FACTION_MAX_LEVEL then lv = FACTION_MAX_LEVEL end
    local nextExp = FACTION_LEVEL_EXP[lv + 1] or FACTION_LEVEL_EXP[FACTION_MAX_LEVEL]
    local curNeed = FACTION_LEVEL_EXP[lv] or 0
    local baseBuff = lv * 2  -- 姣忕骇+2%鎴樺姏鍔犳垚(鍏ㄥ憳)
    local role = CloudManager._factionRole or "member"
    local roleCoeff = ROLE_BUFF_PER_LEVEL[role] or 0
    local roleBonus = lv * roleCoeff  -- 鑱屼綅棰濆鍔犳垚
    return {
        level = lv,
        exp = exp,
        curLevelExp = curNeed,
        nextLevelExp = nextExp,
        maxLevel = FACTION_MAX_LEVEL,
        buffPercent = baseBuff,          -- 鍏ㄥ憳鍩虹鍔犳垚%
        roleBonusPercent = roleBonus,    -- 鑱屼綅棰濆鍔犳垚%
        totalBuffPercent = baseBuff + roleBonus,  -- 鎬诲姞鎴?
        maxMembers = FACTION_LEVEL_MAX_MEMBERS[lv] or 20,
    }
end

--- 鑾峰彇褰撴棩涓汉宸叉崘鐚搴?(鏈湴杩借釜)
---@return number
function CloudManager.GetTodayDonation()
    local meta = CloudManager._factionMeta
    if not meta then return 0 end
    local myUid = CloudAPI.GetUserId()
    local uidStr = tostring(myUid)
    local today = os.date("%Y%m%d")
    if not meta.donateDaily then return 0 end
    if not meta.donateDaily[uidStr] then return 0 end
    if meta.donateDaily[uidStr].day ~= today then return 0 end
    return meta.donateDaily[uidStr].amount or 0
end

--- 鎹愮尞铏庣缁欓樀钀?
---@param amount number 鎹愮尞鏁伴噺
---@param callback? fun(success: boolean, reason: string)
function CloudManager.DonateFaction(amount, callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "闃佃惀鏁版嵁鏈姞杞?) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end
    amount = math.floor(amount)
    if amount < FACTION_DONATE_MIN then
        if callback then callback(false, "鏈€灏戞崘鐚? .. FACTION_DONATE_MIN .. "铏庣") end
        return
    end
    if not rawget(_G, "playerInfo") or (playerInfo.jade or 0) < amount then
        if callback then callback(false, "铏庣涓嶈冻") end
        return
    end

    local myUid = CloudAPI.GetUserId()
    local uidStr = tostring(myUid)
    local today = os.date("%Y%m%d")

    -- 妫€鏌ユ瘡鏃ラ檺棰?
    if not meta.donateDaily then meta.donateDaily = {} end
    if not meta.donateDaily[uidStr] then meta.donateDaily[uidStr] = { day = today, amount = 0 } end
    if meta.donateDaily[uidStr].day ~= today then
        meta.donateDaily[uidStr] = { day = today, amount = 0 }
    end
    local todayDone = meta.donateDaily[uidStr].amount or 0

    -- 鎵ｈ檸绗?
    playerInfo.jade = playerInfo.jade - amount

    -- 鏇存柊 meta
    meta.exp = (meta.exp or 0) + amount
    meta.funds = (meta.funds or 0) + amount
    meta.donateDaily[uidStr].amount = todayDone + amount

    -- 涓汉绱璐＄尞
    if not meta.contributions then meta.contributions = {} end
    meta.contributions[uidStr] = (meta.contributions[uidStr] or 0) + amount

    -- 妫€鏌ュ崌绾?
    local oldLevel = meta.level or 1
    local newLevel = oldLevel
    for lv = oldLevel + 1, FACTION_MAX_LEVEL do
        if meta.exp >= (FACTION_LEVEL_EXP[lv] or 999999999) then
            newLevel = lv
        else
            break
        end
    end
    local leveled = newLevel > oldLevel
    meta.level = newLevel
    -- 鍗囩骇鍚庢洿鏂版垚鍛樹笂闄?
    if leveled then
        meta.maxMembers = FACTION_LEVEL_MAX_MEMBERS[newLevel] or meta.maxMembers
    end

    CloudAPI:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("闃佃惀鎹愮尞", {
            ok = function()
                print("[闃佃惀] 鎹愮尞鎴愬姛: " .. amount .. "铏庣, 缁忛獙=" .. meta.exp .. ", 绛夌骇=" .. meta.level)
                -- 涓婃姤闃佃惀绛夌骇鍒版帓琛屾 (绛夌骇*1000000+缁忛獙, 绛夌骇浼樺厛)
                local rankScore = meta.level * 1000000 + math.min(meta.exp, 999999)
                local rankKey = (rawget(_G, "PROJECT_PREFIX") or "p_49dd_") .. "faction_level"
                CloudAPI:SetInt(rankKey, rankScore, {})
                if rawget(_G, "SaveGameProgress") then SaveGameProgress() end
                if callback then callback(true, leveled and ("闃佃惀鍗囩骇鍒癓v." .. newLevel .. "!") or nil) end
            end,
            error = function(_, reason)
                -- 鍥炴粴
                playerInfo.jade = playerInfo.jade + amount
                meta.exp = meta.exp - amount
                meta.funds = meta.funds - amount
                meta.donateDaily[uidStr].amount = todayDone
                meta.contributions[uidStr] = (meta.contributions[uidStr] or 0) - amount
                meta.level = oldLevel
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 妫€鏌ヤ粖鏃ユ槸鍚﹀凡绛惧埌
---@return boolean
function CloudManager.HasSignedInToday()
    local meta = CloudManager._factionMeta
    if not meta then return false end
    local myUid = CloudAPI.GetUserId()
    local uidStr = tostring(myUid)
    local today = os.date("%Y%m%d")
    if not meta.donateDaily then return false end
    if not meta.donateDaily[uidStr] then return false end
    return meta.donateDaily[uidStr].day == today and meta.donateDaily[uidStr].signedIn == true
end

--- 闃佃惀绛惧埌 (姣忔棩鍏嶈垂鎹愮尞500缁忛獙锛屼笉娑堣€楄檸绗?
---@param callback? fun(success: boolean, reason: string)
function CloudManager.FactionSignIn(callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "闃佃惀鏁版嵁鏈姞杞?) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end

    local myUid = CloudAPI.GetUserId()
    local uidStr = tostring(myUid)
    local today = os.date("%Y%m%d")
    local signInAmount = 500

    -- 鍒濆鍖栨瘡鏃ヨ褰?
    if not meta.donateDaily then meta.donateDaily = {} end
    if not meta.donateDaily[uidStr] then meta.donateDaily[uidStr] = { day = today, amount = 0 } end
    if meta.donateDaily[uidStr].day ~= today then
        meta.donateDaily[uidStr] = { day = today, amount = 0 }
    end

    -- 妫€鏌ユ槸鍚﹀凡绛惧埌
    if meta.donateDaily[uidStr].signedIn then
        if callback then callback(false, "浠婃棩宸茬鍒?) end
        return
    end

    -- 鏇存柊 meta (涓嶆墸铏庣)
    meta.exp = (meta.exp or 0) + signInAmount
    meta.funds = (meta.funds or 0) + signInAmount
    meta.donateDaily[uidStr].signedIn = true
    meta.donateDaily[uidStr].amount = (meta.donateDaily[uidStr].amount or 0) + signInAmount

    -- 涓汉绱璐＄尞
    if not meta.contributions then meta.contributions = {} end
    meta.contributions[uidStr] = (meta.contributions[uidStr] or 0) + signInAmount

    -- 妫€鏌ュ崌绾?
    local oldLevel = meta.level or 1
    local newLevel = oldLevel
    for lv = oldLevel + 1, FACTION_MAX_LEVEL do
        if meta.exp >= (FACTION_LEVEL_EXP[lv] or 999999999) then
            newLevel = lv
        else
            break
        end
    end
    local leveled = newLevel > oldLevel
    meta.level = newLevel
    if leveled then
        meta.maxMembers = FACTION_LEVEL_MAX_MEMBERS[newLevel] or meta.maxMembers
    end

    CloudAPI:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("闃佃惀绛惧埌", {
            ok = function()
                print("[闃佃惀] 绛惧埌鎴愬姛: +" .. signInAmount .. " 缁忛獙")
                local rankScore = meta.level * 1000000 + math.min(meta.exp, 999999)
                local rankKey = (rawget(_G, "PROJECT_PREFIX") or "p_49dd_") .. "faction_level"
                CloudAPI:SetInt(rankKey, rankScore, {})
                if rawget(_G, "SaveGameProgress") then SaveGameProgress() end
                if callback then callback(true, leveled and ("闃佃惀鍗囩骇鍒癓v." .. newLevel .. "!") or nil) end
            end,
            error = function(_, reason)
                -- 鍥炴粴
                meta.exp = meta.exp - signInAmount
                meta.funds = meta.funds - signInAmount
                meta.donateDaily[uidStr].signedIn = false
                meta.donateDaily[uidStr].amount = meta.donateDaily[uidStr].amount - signInAmount
                meta.contributions[uidStr] = (meta.contributions[uidStr] or 0) - signInAmount
                meta.level = oldLevel
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 鑾峰彇闃佃惀鎴愬憳璐＄尞鎺掕 (浠巑eta.contributions鎺掑簭)
---@return table[] { uid, amount, name }
function CloudManager.GetContributionRank()
    local meta = CloudManager._factionMeta
    if not meta or not meta.contributions then return {} end
    local list = {}
    for uid, amt in pairs(meta.contributions) do
        table.insert(list, { uid = tonumber(uid) or 0, amount = amt })
    end
    table.sort(list, function(a, b) return a.amount > b.amount end)
    return list
end

--- 璁剧疆闃佃惀鍏憡 (鐩熶富/鍓洘涓?
---@param text string 鍏憡鍐呭
---@param callback? fun(success: boolean, reason: string)
function CloudManager.SetFactionAnnouncement(text, callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "闃佃惀鏁版嵁鏈姞杞?) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end
    local myRole = CloudManager._factionRole
    if _getRoleLevel(myRole) < _getRoleLevel("vice_leader") then
        if callback then callback(false, "鍓洘涓诲強浠ヤ笂鎵嶈兘璁剧疆鍏憡") end
        return
    end
    if text and #text > 200 then
        if callback then callback(false, "鍏憡鏈€澶?00瀛?) end
        return
    end

    local oldAnn = meta.announcement
    meta.announcement = text or ""

    CloudAPI:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("璁剧疆鍏憡", {
            ok = function()
                print("[闃佃惀] 鍏憡宸叉洿鏂?)
                if callback then callback(true, nil) end
            end,
            error = function(_, reason)
                meta.announcement = oldAnn
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 鑾峰彇涓汉绱璐＄尞
---@return number
function CloudManager.GetMyContribution()
    local meta = CloudManager._factionMeta
    if not meta or not meta.contributions then return 0 end
    local myUid = CloudAPI.GetUserId()
    return meta.contributions[tostring(myUid)] or 0
end

--- 鑾峰彇闃佃惀鍏憡
---@return string
function CloudManager.GetFactionAnnouncement()
    local meta = CloudManager._factionMeta
    if not meta then return "" end
    return meta.announcement or ""
end

--- 鑾峰彇闃佃惀璧勯噾鎬婚
---@return number
function CloudManager.GetFactionFunds()
    local meta = CloudManager._factionMeta
    if not meta then return 0 end
    return meta.funds or 0
end

--- 鑾峰彇鎹愮尞閰嶇疆甯搁噺
---@return table { minAmount: number }
function CloudManager.GetDonateConfig()
    return { minAmount = FACTION_DONATE_MIN }
end

--- 鑾峰彇濂藉弸妗ｆ鍒楄〃 (閫氳繃鎺掕姒滃尮閰?
---@param callback fun(friends: table[])
function CloudManager.GetFriendProfiles(callback)
    if #CloudManager._friendIds == 0 then
        if callback then callback({}) end
        return
    end
    CloudManager.GetPublicProfiles(0, 100, function(profiles)
        local friendSet = {}
        for _, id in ipairs(CloudManager._friendIds) do friendSet[id] = true end
        local friends = {}
        for _, p in ipairs(profiles) do
            if friendSet[p.userId] then
                friends[#friends + 1] = p
            end
        end
        if callback then callback(friends) end
    end)
end

--- 鏄惁鏄ソ鍙?
---@param userId number
---@return boolean
function CloudManager.IsFriend(userId)
    for _, id in ipairs(CloudManager._friendIds) do
        if id == userId then return true end
    end
    return false
end

--- 鍚屾绀句氦鍩熷埌浜戠 (濂藉弸鍒楄〃 + 闃佃惀褰掑睘)
function CloudManager._syncSocialDomain()
    if not CloudAPI.IsAvailable() then return end
    local data = CloudManager.CollectDomainData("social")
    CloudAPI:Set(DOMAINS.social, data, {
        ok = function()
            print("[绀句氦] social鍩熷凡鍚屾")
        end,
    })
end

-- ============================================================================
-- 闃佃惀绯荤粺 (鍏叡鐢宠姹犳ā鍨?鈥?瀹夊叏鐗?
-- 鏍稿績: 鐩熶富閫氳繃鎺掕姒滃彂甯冮樀钀? 鐢宠鑰呴€氳繃鎺掕姒滄彁浜? 鐩熶富瀹℃壒鍚庢洿鏂版垚鍛樿〃
-- 瑙掕壊浣撶郴: leader(鐩熶富) > vice_leader(鍓洘涓? > member(鎴愬憳)
-- 缁ф壙閾? 鐩熶富閫€鍑?鈫?鍓洘涓荤户浣?鈫?鏈€鏃╂垚鍛樼户浣?鈫?鏈€鍚庝竴浜洪€€鍑?瑙ｆ暎
-- ============================================================================

CloudManager._factionId = 0
CloudManager._factionName = ""
CloudManager._factionRole = "none"  -- "leader" / "vice_leader" / "member" / "none"
CloudManager._factionMeta = nil     -- 闃佃惀鍏冩暟鎹?(鐩熶富缁存姢, 鍚?roles 瀛楁)
CloudManager._campOutApply = nil    -- 鏈湴缂撳瓨: 鎴戠殑鍏ヨ惀鐢宠
CloudManager._campOutResp = {}      -- 鏈湴缂撳瓨: 鐩熶富鐨勫鎵瑰洖澶?

-- 鈹€鈹€ 鍒涘缓闃佃惀 鈹€鈹€

--- 鍒涘缓闃佃惀 (娑堣€楄檸绗? 鍏堟墸鍐嶅缓)
---@param name string
---@param desc string
---@param callback? fun(success: boolean, reason: string)
function CloudManager.CreateFaction(name, desc, callback)
    -- 灏佺妫€鏌?
    if S.banLevel >= BAN_LEVEL_SOCIAL then
        if callback then callback(false, "绀句氦鍔熻兘宸茶闄愬埗") end
        return
    end
    if CloudManager._factionId ~= 0 then
        if callback then callback(false, "宸叉湁闃佃惀, 璇峰厛绂诲紑") end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end
    -- 妫€鏌ヨ檸绗?
    if not rawget(_G, "playerInfo") or (playerInfo.jade or 0) < CAMP_CREATE_COST then
        if callback then callback(false, "铏庣涓嶈冻(闇€瑕? .. CAMP_CREATE_COST .. ")") end
        return
    end

    local uid = CloudAPI.GetUserId()
    local ts = os.time()
    -- 鐢熸垚鍞竴闃佃惀ID: 鏃堕棿鎴冲悗6浣?* 10000 + uid鍚?浣?
    local campId = (ts % 1000000) * 10000 + (uid % 10000)

    -- 1. 鍏堟墸铏庣 (鍐欏叆鑷繁瀛樻。)
    playerInfo.jade = playerInfo.jade - CAMP_CREATE_COST

    local uidStr = tostring(uid)
    local meta = {
        id = campId,
        name = name,
        desc = desc or "",
        leaderId = uid,
        createdAt = ts,
        maxMembers = MAX_CAMP_MEMBERS,
        members = { uid },  -- 鐩熶富鑷繁鏄涓垚鍛?
        memberCount = 1,
        roles = { [uidStr] = "leader" },  -- 瑙掕壊鏄犲皠: uid鈫掕鑹?
    }

    CloudManager._factionId = campId
    CloudManager._factionName = name
    CloudManager._factionRole = "leader"
    CloudManager._factionMeta = meta

    -- 2. 鍙戝竷鍒版帓琛屾 (camp_leader_ts + camp_meta)
    CloudAPI:BatchSet()
        :SetInt(KEYS.camp_leader_ts, ts)
        :Set(KEYS.camp_meta, meta)
        :Save("鍒涘缓闃佃惀", {
            ok = function()
                print("[闃佃惀] 鍒涘缓鎴愬姛: " .. name .. " (ID=" .. campId .. "), 鐩熶富, 娑堣€? .. CAMP_CREATE_COST .. "铏庣")
                CloudManager._syncSocialDomain()
                CloudManager.PublishProfile()
                if callback then callback(true, "鍒涘缓鎴愬姛") end
            end,
            error = function(_, reason)
                -- 鍥炴粴铏庣
                playerInfo.jade = playerInfo.jade + CAMP_CREATE_COST
                CloudManager._factionId = 0
                CloudManager._factionName = ""
                CloudManager._factionRole = "none"
                CloudManager._factionMeta = nil
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- 鈹€鈹€ 鍒楀嚭鎵€鏈夐樀钀?鈹€鈹€

--- 鍒楀嚭闃佃惀鍒楄〃 (浠?camp_leader_ts 鎺掕姒? 鎸塩ampId鍘婚噸淇濈暀鏈€鏂?
---@param callback fun(factions: table[])
function CloudManager.ListFactions(callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end

    CloudAPI:GetRankList(KEYS.camp_leader_ts, 0, 100, {
        ok = function(rankList)
            -- 鎸?campId 鍘婚噸: 鐩熶富杞鍚庡彲鑳藉瓨鍦ㄦ柊鏃т袱鏉? 淇濈暀鎺掕闈犲墠(鏃堕棿鎴虫洿澶?鐨?
            local campMap = {}  -- campId 鈫?faction entry
            local campOrder = {} -- 淇濇寔椤哄簭

            for _, item in ipairs(rankList) do
                local meta = item.score[KEYS.camp_meta]
                if type(meta) == "table" and meta.id then
                    local cid = meta.id
                    local ts = (item.iscore and item.iscore[KEYS.camp_leader_ts]) or 0
                    if not campMap[cid] or ts > (campMap[cid]._ts or 0) then
                        if not campMap[cid] then
                            table.insert(campOrder, cid)
                        end
                        campMap[cid] = {
                            _ts = ts,
                            campId = cid,
                            name = meta.name or "鏈懡鍚?,
                            desc = meta.desc or "",
                            leaderId = meta.leaderId or _getRankItemUserId(item),
                            leaderNickname = "",
                            createdAt = meta.createdAt or 0,
                            maxMembers = meta.maxMembers or MAX_CAMP_MEMBERS,
                            memberCount = meta.memberCount or 0,
                            members = meta.members or {},
                            roles = meta.roles or {},
                            level = meta.level or 1,
                            exp = meta.exp or 0,
                        }
                    end
                end
            end

            -- 杞负鏈夊簭鍒楄〃
            local factions = {}
            local leaderIds = {}
            for _, cid in ipairs(campOrder) do
                local f = campMap[cid]
                f._ts = nil  -- 娓呴櫎鍐呴儴瀛楁
                table.insert(factions, f)
                table.insert(leaderIds, f.leaderId)
            end

            -- 鎵归噺鏌ユ樀绉?
            if #leaderIds > 0 and rawget(_G, "GetUserNickname") then
                GetUserNickname({
                    userIds = leaderIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do map[info.userId] = info.nickname or "" end
                        for _, f in ipairs(factions) do f.leaderNickname = map[f.leaderId] or "鏈煡" end
                        if callback then callback(factions) end
                    end,
                    onError = function() if callback then callback(factions) end end,
                })
            else
                if callback then callback(factions) end
            end
        end,
        error = function(_, reason)
            print("[闃佃惀] 鍒楀嚭闃佃惀澶辫触: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.camp_meta)
end

-- 鈹€鈹€ 鐢宠鍔犲叆闃佃惀 鈹€鈹€

--- 鐢宠鍔犲叆鎸囧畾闃佃惀
---@param campId number
---@param campName string
---@param callback? fun(success: boolean, reason: string)
function CloudManager.ApplyToFaction(campId, campName, callback)
    -- 灏佺妫€鏌?
    if S.banLevel >= BAN_LEVEL_SOCIAL then
        if callback then callback(false, "绀句氦鍔熻兘宸茶闄愬埗") end
        return
    end
    if CloudManager._factionId ~= 0 then
        if callback then callback(false, "宸叉湁闃佃惀, 璇峰厛绂诲紑") end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end

    local apply = {
        campId = campId,
        campName = campName or "",
        time = os.time(),
    }
    CloudManager._campOutApply = apply

    CloudAPI:BatchSet()
        :SetInt(KEYS.camp_apply_ts, os.time())
        :Set(KEYS.camp_apply, apply)
        :Save("鐢宠鍔犲叆闃佃惀", {
            ok = function()
                print("[闃佃惀] 宸叉彁浜ょ敵璇? " .. (campName or "") .. " (ID=" .. campId .. ")")
                if callback then callback(true, "鐢宠宸叉彁浜?) end
            end,
            error = function(_, reason)
                CloudManager._campOutApply = nil
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- 鈹€鈹€ 鐩熶富瀹℃壒 鈹€鈹€

--- 鐩熶富/鍓洘涓绘煡鐪嬮樀钀ョ敵璇?(鎵弿 camp_apply_ts 鎺掕姒?
---@param callback fun(applications: table[])
function CloudManager.CheckFactionApplications(callback)
    -- 鍓洘涓诲強浠ヤ笂鍙鎵?(level >= 5)
    if _getRoleLevel(CloudManager._factionRole) < _getRoleLevel("vice_leader")
       or CloudManager._factionId == 0 then
        if callback then callback({}) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end
    local myCampId = CloudManager._factionId

    CloudAPI:GetRankList(KEYS.camp_apply_ts, 0, 200, {
        ok = function(rankList)
            local applications = {}
            local applicantIds = {}

            for _, item in ipairs(rankList) do
                local applyData = item.score[KEYS.camp_apply]
                if type(applyData) == "table" and applyData.campId == myCampId then
                    local applicantId = _getRankItemUserId(item)
                    -- 鎺掗櫎杩囨湡 & 宸插湪鎴愬憳鍒楄〃涓?
                    if applyData.time and (os.time() - applyData.time) <= REQUEST_EXPIRE_SECONDS then
                        local alreadyMember = false
                        if CloudManager._factionMeta and CloudManager._factionMeta.members then
                            for _, mid in ipairs(CloudManager._factionMeta.members) do
                                if mid == applicantId then alreadyMember = true; break end
                            end
                        end
                        -- 鎺掗櫎宸插洖澶嶆嫆缁?鍚屾剰鐨?
                        local alreadyResp = CloudManager._campOutResp[tostring(applicantId)]
                        if not alreadyMember and not alreadyResp then
                            table.insert(applications, {
                                userId = applicantId,
                                time = applyData.time,
                                nickname = "",
                            })
                            table.insert(applicantIds, applicantId)
                        end
                    end
                end
            end

            if #applicantIds > 0 and rawget(_G, "GetUserNickname") then
                GetUserNickname({
                    userIds = applicantIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do map[info.userId] = info.nickname or "" end
                        for _, a in ipairs(applications) do a.nickname = map[a.userId] or "鏈煡" end
                        if callback then callback(applications) end
                    end,
                    onError = function() if callback then callback(applications) end end,
                })
            else
                if callback then callback(applications) end
            end
        end,
        error = function(_, reason)
            print("[闃佃惀] 鎵弿鐢宠澶辫触: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.camp_apply)
end

--- 鐩熶富/鍓洘涓诲悓鎰忕敵璇?
---@param applicantUserId number
---@param callback? fun(success: boolean)
function CloudManager.ApproveFactionApplication(applicantUserId, callback)
    -- 鍓洘涓诲強浠ヤ笂鍙鎵?
    if _getRoleLevel(CloudManager._factionRole) < _getRoleLevel("vice_leader")
       or not CloudManager._factionMeta then
        if callback then callback(false) end
        return
    end

    local meta = CloudManager._factionMeta
    -- 浜烘暟涓婇檺
    if (meta.memberCount or 0) >= (meta.maxMembers or MAX_CAMP_MEMBERS) then
        print("[闃佃惀] 鎴愬憳宸叉弧")
        if callback then callback(false) end
        return
    end

    -- 杩藉姞鎴愬憳
    if not meta.members then meta.members = {} end
    -- 妫€鏌ラ噸澶?
    for _, mid in ipairs(meta.members) do
        if mid == applicantUserId then
            if callback then callback(true) end -- 宸插湪鍒楄〃
            return
        end
    end
    table.insert(meta.members, applicantUserId)
    meta.memberCount = #meta.members
    -- 鏂版垚鍛橀粯璁よ鑹?
    if not meta.roles then meta.roles = {} end
    meta.roles[tostring(applicantUserId)] = "member"

    -- 璁板綍瀹℃壒鍥炲
    CloudManager._campOutResp[tostring(applicantUserId)] = {
        approved = true,
        campId = meta.id,
        campName = meta.name,
        time = os.time(),
    }

    -- 鍏堣鍐嶅悎骞? 鏇存柊 camp_meta + 鍙戝竷瀹℃壒鍥炲
    CloudAPI:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :SetInt(KEYS.camp_resp_ts, os.time())
        :Set(KEYS.camp_resp, CloudManager._campOutResp)
        :Save("鍚屾剰鍏ヨ惀", {
            ok = function()
                print("[闃佃惀] 宸插悓鎰?" .. tostring(applicantUserId) .. " 鍔犲叆, 褰撳墠" .. meta.memberCount .. "浜?)
                if callback then callback(true) end
            end,
            error = function()
                -- 鍥炴粴
                for i, mid in ipairs(meta.members) do
                    if mid == applicantUserId then table.remove(meta.members, i); break end
                end
                meta.memberCount = #meta.members
                CloudManager._campOutResp[tostring(applicantUserId)] = nil
                if callback then callback(false) end
            end,
        })
end

--- 鐩熶富鎷掔粷鐢宠
---@param applicantUserId number
function CloudManager.RejectFactionApplication(applicantUserId)
    CloudManager._campOutResp[tostring(applicantUserId)] = {
        approved = false,
        campId = CloudManager._factionId,
        time = os.time(),
    }
    if CloudAPI.IsAvailable() then
        CloudAPI:BatchSet()
            :SetInt(KEYS.camp_resp_ts, os.time())
            :Set(KEYS.camp_resp, CloudManager._campOutResp)
            :Save("鎷掔粷鍏ヨ惀")
    end
end

-- 鈹€鈹€ 鐢宠鑰呮鏌ュ鎵圭粨鏋?鈹€鈹€

--- 妫€鏌ユ垜鐨勫叆钀ョ敵璇锋槸鍚﹁鎵瑰噯 (鑷姩瀹屾垚鍏ヨ惀)
---@param callback? fun(result: string) "approved" | "rejected" | "pending" | "none"
function CloudManager.CheckMyFactionApplication(callback)
    if not CloudManager._campOutApply then
        if callback then callback("none") end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback("pending") end
        return
    end

    local myUid = CloudAPI.GetUserId()
    local myUidStr = tostring(myUid)
    local targetCampId = CloudManager._campOutApply.campId

    -- 鎵弿鐩熶富鐨勫鎵瑰洖澶?
    CloudAPI:GetRankList(KEYS.camp_resp_ts, 0, 100, {
        ok = function(rankList)
            for _, item in ipairs(rankList) do
                local respData = item.score[KEYS.camp_resp]
                if type(respData) == "table" and respData[myUidStr] then
                    local resp = respData[myUidStr]
                    if resp.campId == targetCampId then
                        if resp.approved then
                            -- 鍏ヨ惀鎴愬姛!
                            CloudManager._factionId = targetCampId
                            CloudManager._factionName = CloudManager._campOutApply.campName or ""
                            CloudManager._factionRole = "member"
                            CloudManager._campOutApply = nil
                            -- 娓呯悊鐢宠鎺掕
                            CloudAPI:BatchSet()
                                :SetInt(KEYS.camp_apply_ts, 0)
                                :Set(KEYS.camp_apply, {})
                                :Save("娓呯悊鍏ヨ惀鐢宠")
                            CloudManager._syncSocialDomain()
                            CloudManager.PublishProfile()
                            -- 鎷夊彇闃佃惀meta(鐩熶富鍚?浜烘暟绛?, 渚沀I鏄剧ず
                            CloudManager._refreshFactionStatus()
                            print("[闃佃惀] 鍏ヨ惀瀹℃壒閫氳繃!")
                            if callback then callback("approved") end
                        else
                            CloudManager._campOutApply = nil
                            print("[闃佃惀] 鍏ヨ惀鐢宠琚嫆缁?)
                            if callback then callback("rejected") end
                        end
                        return
                    end
                end
            end
            if callback then callback("pending") end
        end,
        error = function()
            if callback then callback("pending") end
        end,
    }, KEYS.camp_resp)
end

-- 鈹€鈹€ 绂诲紑闃佃惀 鈹€鈹€

--- 浠庢垚鍛樺垪琛ㄤ腑鎵惧埌缁т换鑰?(鎸夌巼鍦熻亴浣嶇户鎵块摼: 鍓洘涓烩啋鍐涘笀鈫掑厛閿嬪畼鈫掑浜ゅ畼鈫掔簿鑻扁啋鎴愬憳)
--- 鍚岀骇鍒唴鎸夊姞鍏ラ『搴?members鏁扮粍椤哄簭)浼樺厛
---@param meta table 闃佃惀鍏冩暟鎹?
---@param excludeUid number 瑕佹帓闄ょ殑uid(鍗冲皢绂诲紑鐨勪汉)
---@return number|nil successorUid
local function _findSuccessor(meta, excludeUid)
    if not meta or not meta.members then return nil end
    local roles = meta.roles or {}
    -- 鎸夌户鎵块摼椤哄簭閫愮骇鏌ユ壘
    for _, roleName in ipairs(ROLE_SUCCESSION) do
        for _, mid in ipairs(meta.members) do
            if mid ~= excludeUid and (roles[tostring(mid)] or "member") == roleName then
                return mid
            end
        end
    end
    return nil  -- 娌℃湁鍏朵粬浜轰簡
end

--- 绂诲紑褰撳墠闃佃惀
--- 鐩熶富閫€鍑? 鏈夊叾浠栨垚鍛樷啋杞鐩熶富(鍓洘涓讳紭鍏?, 鏃犲叾浠栨垚鍛樷啋瑙ｆ暎
--- 闈炵洘涓婚€€鍑? 鐩存帴绂诲紑, 鏈湴娓呴櫎
---@param callback? fun(success: boolean, info: string)
function CloudManager.LeaveFaction(callback)
    if CloudManager._factionId == 0 then
        if callback then callback(true, "鏈姞鍏ラ樀钀?) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end

    local myUid = CloudAPI.GetUserId()
    local oldName = CloudManager._factionName
    local wasLeader = CloudManager._factionRole == "leader"
    local meta = CloudManager._factionMeta

    if wasLeader and meta then
        -- 鈹€鈹€ 鐩熶富绂诲紑 鈹€鈹€
        local successor = _findSuccessor(meta, myUid)

        if successor then
            -- 鏈夌户浠昏€? 杞鐩熶富, 闃佃惀瀛樼画
            -- 浠庢垚鍛樺垪琛ㄧЩ闄よ嚜宸?
            local newMembers = {}
            for _, mid in ipairs(meta.members) do
                if mid ~= myUid then
                    table.insert(newMembers, mid)
                end
            end
            meta.members = newMembers
            meta.memberCount = #newMembers
            meta.leaderId = successor
            -- 鏇存柊瑙掕壊: 缁т换鑰呪啋leader, 绉婚櫎鏃х洘涓?
            if not meta.roles then meta.roles = {} end
            meta.roles[tostring(myUid)] = nil
            meta.roles[tostring(successor)] = "leader"

            -- 娓呴櫎鏈湴鐘舵€?
            CloudManager._factionId = 0
            CloudManager._factionName = ""
            CloudManager._factionRole = "none"

            -- 鍙戝竷鏇存柊鍚庣殑meta (鏃х洘涓绘渶鍚庝竴娆″啓鍏? 淇濈暀鎺掕鏉＄洰渚涢樀钀ョ户缁彲瑙?
            CloudAPI:BatchSet()
                :Set(KEYS.camp_meta, meta)
                :SetInt(KEYS.camp_resp_ts, 0)
                :Set(KEYS.camp_resp, {})
                :Save("鐩熶富閫€浣? 杞缁? .. tostring(successor), {
                    ok = function()
                        print("[闃佃惀] 鐩熶富閫€鍑? " .. oldName
                            .. ", 杞缁?" .. tostring(successor)
                            .. ", 鍓╀綑" .. meta.memberCount .. "浜?)
                        CloudManager._factionMeta = nil
                        CloudManager._campOutResp = {}
                        CloudManager._syncSocialDomain()
                        CloudManager.PublishProfile()
                        if callback then callback(true, "宸查€€鍑? 鐩熶富宸茶浆璁?) end
                    end,
                    error = function()
                        -- 鍥炴粴
                        CloudManager._factionId = meta.id
                        CloudManager._factionName = oldName
                        CloudManager._factionRole = "leader"
                        if callback then callback(false, "閫€鍑哄け璐?) end
                    end,
                })
        else
            -- 鏃犵户浠昏€? 鏈€鍚庝竴浜? 瑙ｆ暎闃佃惀
            CloudManager._factionId = 0
            CloudManager._factionName = ""
            CloudManager._factionRole = "none"

            CloudAPI:BatchSet()
                :SetInt(KEYS.camp_leader_ts, 0)
                :Set(KEYS.camp_meta, {})
                :SetInt(KEYS.camp_resp_ts, 0)
                :Set(KEYS.camp_resp, {})
                :Save("瑙ｆ暎闃佃惀(鏈€鍚庝竴浜?", {
                    ok = function()
                        print("[闃佃惀] 鏈€鍚庝竴浜虹寮€, 闃佃惀宸茶В鏁? " .. oldName)
                        CloudManager._factionMeta = nil
                        CloudManager._campOutResp = {}
                        CloudManager._syncSocialDomain()
                        CloudManager.PublishProfile()
                        if callback then callback(true, "闃佃惀宸茶В鏁?) end
                    end,
                    error = function()
                        if callback then callback(false, "瑙ｆ暎澶辫触") end
                    end,
                })
        end
    else
        -- 鈹€鈹€ 闈炵洘涓荤寮€ 鈹€鈹€
        -- 闈炵洘涓绘棤娉曠洿鎺ヤ慨鏀筩amp_meta(瀛樺湪鐩熶富鐨勬帓琛屾潯鐩笅)
        -- 鍙兘娓呴櫎鏈湴鐘舵€? 鐩熶富渚т細閫氳繃鎴愬憳娲昏穬搴︽娴嬪埌绂诲紑
        CloudManager._factionId = 0
        CloudManager._factionName = ""
        CloudManager._factionRole = "none"
        CloudManager._campOutApply = nil

        -- 娓呯悊鑷繁鐨勭敵璇锋帓琛屾潯鐩?
        CloudAPI:BatchSet()
            :SetInt(KEYS.camp_apply_ts, 0)
            :Set(KEYS.camp_apply, {})
            :Save("鎴愬憳閫€鍑洪樀钀?, {
                ok = function()
                    print("[闃佃惀] 宸查€€鍑? " .. oldName)
                    CloudManager._syncSocialDomain()
                    CloudManager.PublishProfile()
                    if callback then callback(true, "宸查€€鍑洪樀钀?) end
                end,
                error = function()
                    if callback then callback(false, "閫€鍑哄け璐?) end
                end,
            })
    end
end

-- 鈹€鈹€ 鑾峰彇闃佃惀鎴愬憳鍒楄〃 鈹€鈹€

--- 鑾峰彇褰撳墠闃佃惀鎴愬憳妗ｆ
---@param callback fun(members: table[])
function CloudManager.GetFactionMembers(callback)
    if CloudManager._factionId == 0 then
        if callback then callback({}) end
        return
    end

    -- 濡傛灉鏄洘涓? 鐩存帴鐢ㄦ湰鍦?meta
    if CloudManager._factionRole == "leader" and CloudManager._factionMeta then
        local memberIds = CloudManager._factionMeta.members or {}
        if #memberIds == 0 then
            if callback then callback({}) end
            return
        end

        --- 鍐呴儴: 鎷垮埌鍏ㄩ噺 profiles 鍚? 杩囨护 + 鏍￠獙绂诲紑 + 琛ユ煡缂哄け鎴愬憳
        local function _processMembers(profiles)
            local memberSet = {}
            for _, mid in ipairs(memberIds) do memberSet[mid] = true end
            local result = {}
            local profileMap = {}
            for _, p in ipairs(profiles) do
                profileMap[p.userId] = p
                if memberSet[p.userId] then table.insert(result, p) end
            end

            -- 鎵惧嚭鎺掕姒滀腑鏈嚭鐜扮殑鎴愬憳, 鐢?SearchPlayer 琛ユ煡
            local missing = {}
            for _, mid in ipairs(memberIds) do
                if not profileMap[mid] then missing[#missing + 1] = mid end
            end

            -- 琛ユ煡瀹屾垚鍚庢墽琛岄獙璇佹竻鐞?
            local function _afterFetchMissing()
                -- 楠岃瘉: 鍙竻鐞?factionId>0 涓?!= myFid 鐨勶紙鏄庣‘鍔犲叆浜嗗叾浠栭樀钀ワ級
                local myFid = CloudManager._factionId
                local myUid = CloudAPI.GetUserId()
                local removed = {}
                for _, mid in ipairs(memberIds) do
                    if mid ~= myUid then
                        local mp = profileMap[mid]
                        if mp and mp.profile then
                            local theirFid = mp.profile.factionId
                            if theirFid and theirFid ~= 0 and theirFid ~= myFid then
                                removed[#removed + 1] = mid
                                print("[闃佃惀] 妫€娴嬪埌鎴愬憳 " .. tostring(mid) .. " 宸插姞鍏ュ叾浠栭樀钀?factionId=" .. tostring(theirFid) .. ")")
                            end
                        end
                        -- 娉ㄦ剰: 鎵句笉鍒扮殑鎴愬憳(mp==nil)涓嶆竻鐞? 鍙兘鏄柊鎴愬憳杩樻病鍙戝竷profile
                    end
                end
                if #removed > 0 then
                    local meta = CloudManager._factionMeta
                    local removedSet = {}
                    for _, rid in ipairs(removed) do removedSet[rid] = true end
                    local newMembers = {}
                    for _, mid in ipairs(meta.members or {}) do
                        if not removedSet[mid] then newMembers[#newMembers + 1] = mid end
                    end
                    meta.members = newMembers
                    meta.memberCount = #newMembers
                    local cleanResult = {}
                    for _, r in ipairs(result) do
                        if not removedSet[r.userId] then cleanResult[#cleanResult + 1] = r end
                    end
                    result = cleanResult
                    CloudAPI:BatchSet()
                        :Set(KEYS.camp_meta, meta)
                        :Save("鐩熶富鑷姩娓呯悊宸茬寮€鎴愬憳", {
                            ok = function()
                                print("[闃佃惀] 宸茶嚜鍔ㄦ竻鐞?" .. #removed .. " 鍚嶇寮€鎴愬憳, 鍓╀綑" .. meta.memberCount .. "浜?)
                            end,
                        })
                end
                if callback then callback(result) end
            end

            if #missing == 0 then
                _afterFetchMissing()
            else
                -- 閫愪釜琛ユ煡缂哄け鎴愬憳
                local pending = #missing
                for _, mid in ipairs(missing) do
                    CloudManager.SearchPlayer(mid, function(found)
                        if found then
                            profileMap[found.userId] = found
                            table.insert(result, found)
                        end
                        pending = pending - 1
                        if pending <= 0 then _afterFetchMissing() end
                    end)
                end
            end
        end

        -- 鍏堟媺鍙?top-200 profiles, 瑕嗙洊澶у鏁版垚鍛?
        CloudManager.GetPublicProfiles(0, 200, function(profiles)
            _processMembers(profiles)
        end)
        return
    end

    -- 鏅€氭垚鍛? 浠庣洘涓荤殑 camp_meta 鑾峰彇鎴愬憳鍒楄〃
    CloudAPI:GetRankList(KEYS.camp_leader_ts, 0, 50, {
        ok = function(rankList)
            local memberIds = {}
            for _, item in ipairs(rankList) do
                local meta = item.score[KEYS.camp_meta]
                if type(meta) == "table" and meta.id == CloudManager._factionId then
                    memberIds = meta.members or {}
                    break
                end
            end
            if #memberIds == 0 then
                if callback then callback({}) end
                return
            end
            CloudManager.GetPublicProfiles(0, 100, function(profiles)
                local memberSet = {}
                for _, mid in ipairs(memberIds) do memberSet[mid] = true end
                local result = {}
                for _, p in ipairs(profiles) do
                    if memberSet[p.userId] then table.insert(result, p) end
                end
                if callback then callback(result) end
            end)
        end,
        error = function()
            if callback then callback({}) end
        end,
    }, KEYS.camp_meta)
end

--- 鑾峰彇褰撳墠闃佃惀淇℃伅
---@return table
function CloudManager.GetFactionInfo()
    return {
        id = CloudManager._factionId,
        name = CloudManager._factionName,
        role = CloudManager._factionRole,
        meta = CloudManager._factionMeta,
    }
end

-- 鈹€鈹€ 璁剧疆鎴愬憳鑱屼綅 (浠跨巼鍦熶箣婊? 鈹€鈹€

--- 璁剧疆鎴愬憳鑱屼綅 (闇€瑕佹搷浣滆€呮潈闄愰珮浜庣洰鏍囧綋鍓嶈亴浣嶅拰鐩爣鑱屼綅)
--- 鏈夋晥鑱屼綅: "vice_leader"(鍓洘涓?, "strategist"(鍐涘笀), "vanguard"(鍏堥攱瀹?,
---           "diplomat"(澶栦氦瀹?, "elite"(绮捐嫳), "member"(鎴愬憳)
---@param targetUserId number 鐩爣鎴愬憳uid
---@param newRole string 鏂拌亴浣嶅悕绉?
---@param callback? fun(success: boolean, reason: string)
function CloudManager.SetMemberRole(targetUserId, newRole, callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "闃佃惀鏁版嵁鏈姞杞?) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end

    local myUid = CloudAPI.GetUserId()
    local myRole = CloudManager._factionRole
    if targetUserId == myUid then
        if callback then callback(false, "涓嶈兘瀵硅嚜宸辨搷浣?) end
        return
    end

    -- 楠岃瘉鐩爣鑱屼綅鍚堟硶鎬?
    if newRole == "leader" then
        if callback then callback(false, "鐩熶富鍙兘閫氳繃杞璁剧疆") end
        return
    end
    if not FACTION_ROLES[newRole] then
        if callback then callback(false, "鏃犳晥鐨勮亴浣? " .. tostring(newRole)) end
        return
    end

    -- 妫€鏌ョ洰鏍囨槸鍚﹀湪闃佃惀涓?
    local isMember = false
    for _, mid in ipairs(meta.members or {}) do
        if mid == targetUserId then isMember = true; break end
    end
    if not isMember then
        if callback then callback(false, "瀵规柟涓嶅湪闃佃惀涓?) end
        return
    end

    if not meta.roles then meta.roles = {} end
    local targetUidStr = tostring(targetUserId)
    local oldRole = meta.roles[targetUidStr] or "member"

    -- 鏉冮檺妫€鏌? 鎿嶄綔鑰呭繀椤绘瘮鐩爣褰撳墠鑱屼綅楂? 涔熷繀椤绘瘮鐩爣鏂拌亴浣嶉珮
    if not _hasAuthorityOver(myRole, oldRole) then
        if callback then callback(false, "浣犵殑鑱屼綅涓嶅, 鏃犳硶鎿嶄綔" .. _getRoleName(oldRole)) end
        return
    end
    if not _hasAuthorityOver(myRole, newRole) then
        if callback then callback(false, "浣犵殑鑱屼綅涓嶅, 鏃犳硶鎺堜簣" .. _getRoleName(newRole)) end
        return
    end

    -- 浜烘暟涓婇檺妫€鏌?(鏈夐檺鑱屼綅)
    local roleDef = FACTION_ROLES[newRole]
    if roleDef.max > 0 then
        local current = _countRole(meta.roles, newRole)
        -- 濡傛灉鐩爣宸茬粡鏄繖涓亴浣? 涓嶅崰棰濆鍚嶉
        if oldRole ~= newRole and current >= roleDef.max then
            if callback then callback(false, _getRoleName(newRole) .. "鍚嶉宸叉弧(涓婇檺" .. roleDef.max .. "浜?") end
            return
        end
    end

    if oldRole == newRole then
        if callback then callback(true, "宸茬粡鏄? .. _getRoleName(newRole)) end
        return
    end

    meta.roles[targetUidStr] = newRole

    -- 鍙戝竷鏇存柊
    CloudAPI:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("璁剧疆鑱屼綅", {
            ok = function()
                print("[闃佃惀] " .. tostring(targetUserId) .. " "
                    .. _getRoleName(oldRole) .. "鈫? .. _getRoleName(newRole))
                if callback then callback(true, "宸茶涓? .. _getRoleName(newRole)) end
            end,
            error = function(_, reason)
                -- 鍥炴粴
                meta.roles[targetUidStr] = oldRole
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 鍏煎鏃ф帴鍙? 璁剧疆/鍙栨秷鍓洘涓?
---@param targetUserId number
---@param setAsVice boolean
---@param callback? fun(success: boolean, reason: string)
function CloudManager.SetViceLeader(targetUserId, setAsVice, callback)
    CloudManager.SetMemberRole(targetUserId, setAsVice and "vice_leader" or "member", callback)
end

-- 鈹€鈹€ 闃佃惀鏀瑰悕 (浠呯洘涓? 鈹€鈹€

---@param newName string
---@param callback? fun(success: boolean, reason: string)
function CloudManager.RenameFaction(newName, callback)
    if CloudManager._factionRole ~= "leader" then
        if callback then callback(false, "鍙湁鐩熶富鎵嶈兘鏀瑰悕") end
        return
    end
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "闃佃惀鏁版嵁鏈姞杞?) end
        return
    end
    if not newName or #newName == 0 then
        if callback then callback(false, "鍚嶇О涓嶈兘涓虹┖") end
        return
    end
    if #newName > 24 then
        if callback then callback(false, "鍚嶇О杩囬暱(鏈€澶?涓眽瀛?") end
        return
    end
    local oldName = meta.name
    meta.name = newName
    CloudManager._factionName = newName

    CloudAPI:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("闃佃惀鏀瑰悕", {
            ok = function()
                print("[闃佃惀] 鏀瑰悕鎴愬姛: " .. tostring(oldName) .. " 鈫?" .. newName)
                if callback then callback(true, nil) end
            end,
            error = function(_, reason)
                meta.name = oldName
                CloudManager._factionName = oldName
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- 鈹€鈹€ 韪㈠嚭鎴愬憳 (鍓洘涓诲強浠ヤ笂, 鍙兘韪綆浜庤嚜宸辫亴浣嶇殑) 鈹€鈹€

--- 韪㈠嚭鎸囧畾鎴愬憳
---@param targetUserId number
---@param callback? fun(success: boolean, reason: string)
function CloudManager.KickMember(targetUserId, callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "闃佃惀鏁版嵁鏈姞杞?) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end

    local myUid = CloudAPI.GetUserId()
    local myRole = CloudManager._factionRole
    if targetUserId == myUid then
        if callback then callback(false, "涓嶈兘韪㈣嚜宸? 璇蜂娇鐢ㄩ€€鍑?) end
        return
    end

    -- 鎿嶄綔鏉冮檺: 鍓洘涓诲強浠ヤ笂
    if _getRoleLevel(myRole) < _getRoleLevel("vice_leader") then
        if callback then callback(false, "鍓洘涓诲強浠ヤ笂鎵嶈兘韪汉") end
        return
    end

    -- 妫€鏌ョ洰鏍囨槸鍚﹀湪闃佃惀涓?
    local targetIdx = nil
    for i, mid in ipairs(meta.members or {}) do
        if mid == targetUserId then targetIdx = i; break end
    end
    if not targetIdx then
        if callback then callback(false, "瀵规柟涓嶅湪闃佃惀涓?) end
        return
    end

    if not meta.roles then meta.roles = {} end
    local targetUidStr = tostring(targetUserId)
    local targetRole = meta.roles[targetUidStr] or "member"

    -- 鍙兘韪綆浜庤嚜宸辫亴浣嶇殑
    if not _hasAuthorityOver(myRole, targetRole) then
        if callback then callback(false, "鏃犳硶韪㈠嚭" .. _getRoleName(targetRole) .. ", 鑱屼綅涓嶄綆浜庝綘") end
        return
    end

    -- 浠庢垚鍛樺垪琛ㄧЩ闄?
    local removedUid = table.remove(meta.members, targetIdx)
    meta.memberCount = #meta.members
    meta.roles[targetUidStr] = nil

    -- 鍙戝竷鏇存柊
    CloudAPI:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("韪㈠嚭鎴愬憳", {
            ok = function()
                print("[闃佃惀] 韪㈠嚭 " .. tostring(targetUserId) .. " (" .. _getRoleName(targetRole) .. ")"
                    .. ", 鍓╀綑" .. meta.memberCount .. "浜?)
                if callback then callback(true, "宸茶涪鍑?) end
            end,
            error = function(_, reason)
                -- 鍥炴粴
                table.insert(meta.members, targetIdx, removedUid)
                meta.memberCount = #meta.members
                meta.roles[targetUidStr] = targetRole
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- 鈹€鈹€ 杞鐩熶富 鈹€鈹€

--- 鐩熶富涓诲姩杞缁欐寚瀹氭垚鍛?
---@param targetUserId number
---@param callback? fun(success: boolean, reason: string)
function CloudManager.TransferLeadership(targetUserId, callback)
    if CloudManager._factionRole ~= "leader" then
        if callback then callback(false, "鍙湁鐩熶富鎵嶈兘杞") end
        return
    end
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "闃佃惀鏁版嵁鏈姞杞?) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "浜戠涓嶅彲鐢?) end
        return
    end

    local myUid = CloudAPI.GetUserId()
    if targetUserId == myUid then
        if callback then callback(false, "涓嶈兘杞缁欒嚜宸?) end
        return
    end

    -- 妫€鏌ョ洰鏍囨槸鍚﹀湪闃佃惀涓?
    local isMember = false
    for _, mid in ipairs(meta.members or {}) do
        if mid == targetUserId then isMember = true; break end
    end
    if not isMember then
        if callback then callback(false, "瀵规柟涓嶅湪闃佃惀涓?) end
        return
    end

    if not meta.roles then meta.roles = {} end
    local myUidStr = tostring(myUid)
    local targetUidStr = tostring(targetUserId)

    -- 杞: 鑷繁闄嶄负鎴愬憳, 鐩爣鍗囦负鐩熶富
    meta.leaderId = targetUserId
    meta.roles[myUidStr] = "member"
    meta.roles[targetUidStr] = "leader"

    CloudManager._factionRole = "member"

    CloudAPI:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("杞鐩熶富", {
            ok = function()
                print("[闃佃惀] 鐩熶富宸茶浆璁╃粰 " .. tostring(targetUserId))
                CloudManager._factionMeta = nil  -- 涓嶅啀鏄洘涓? 涓嶆寔鏈塵eta
                CloudManager._syncSocialDomain()
                if callback then callback(true, "鐩熶富宸茶浆璁?) end
            end,
            error = function(_, reason)
                -- 鍥炴粴
                meta.leaderId = myUid
                meta.roles[myUidStr] = "leader"
                meta.roles[targetUidStr] = meta.roles[targetUidStr]  -- 淇濇寔
                CloudManager._factionRole = "leader"
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- 鈹€鈹€ 缁т綅妫€娴? 鏂扮洘涓讳笂绾垮悗鎺ョ 鈹€鈹€

--- 鍒锋柊闃佃惀鐘舵€?(鐧诲綍鏃惰嚜鍔ㄨ皟鐢?
--- 妫€娴嬪綋鍓嶇帺瀹舵槸鍚﹀洜鐩熶富閫€鍑鸿€岃鎻愬崌涓烘柊鐩熶富, 濡傛灉鏄垯閲嶆柊鍙戝竷 camp_meta
---@param callback? fun(transferred: boolean)
function CloudManager._refreshFactionStatus(callback)
    if CloudManager._factionId == 0 then
        if callback then callback(false) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false) end
        return
    end

    local myUid = CloudAPI.GetUserId()
    local myCampId = CloudManager._factionId

    -- 浠庢帓琛屾鑾峰彇褰撳墠闃佃惀鐨?meta
    CloudAPI:GetRankList(KEYS.camp_leader_ts, 0, 100, {
        ok = function(rankList)
            local latestMeta = nil
            local latestTs = 0

            -- 鎵惧埌鑷繁闃佃惀鐨勬渶鏂癿eta (鎸塩ampId鍘婚噸, 淇濈暀鏈€鏂版椂闂存埑)
            for _, item in ipairs(rankList) do
                local meta = item.score[KEYS.camp_meta]
                if type(meta) == "table" and meta.id == myCampId then
                    local ts = (item.iscore and item.iscore[KEYS.camp_leader_ts]) or 0
                    if ts > latestTs then
                        latestTs = ts
                        latestMeta = meta
                    end
                end
            end

            if not latestMeta then
                -- 闃佃惀宸蹭笉瀛樺湪 (鍙兘宸茶В鏁?
                print("[闃佃惀] 闃佃惀宸蹭笉瀛樺湪, 娓呴櫎鏈湴鐘舵€?)
                CloudManager._factionId = 0
                CloudManager._factionName = ""
                CloudManager._factionRole = "none"
                CloudManager._factionMeta = nil
                CloudManager._syncSocialDomain()
                if callback then callback(false) end
                return
            end

            -- 妫€鏌ヨ嚜宸辨槸鍚﹀湪鎴愬憳鍒楄〃涓?
            local inMembers = false
            for _, mid in ipairs(latestMeta.members or {}) do
                if mid == myUid then inMembers = true; break end
            end

            if not inMembers then
                -- 鎴戝凡涓嶅湪闃佃惀涓?(鍙兘琚涪)
                print("[闃佃惀] 鎴戝凡涓嶅湪闃佃惀鎴愬憳涓? 娓呴櫎鏈湴鐘舵€?)
                CloudManager._factionId = 0
                CloudManager._factionName = ""
                CloudManager._factionRole = "none"
                CloudManager._factionMeta = nil
                CloudManager._syncSocialDomain()
                if callback then callback(false) end
                return
            end

            -- 鍚屾闃佃惀鍚嶇О鍜宮eta
            CloudManager._factionName = latestMeta.name or CloudManager._factionName

            -- 鍏抽敭: 妫€鏌?leaderId 鏄惁鏄嚜宸?
            if latestMeta.leaderId == myUid then
                if CloudManager._factionRole ~= "leader" then
                    -- 鎴戣鎻愬崌涓烘柊鐩熶富! 閲嶆柊鍙戝竷 camp_meta 鍒拌嚜宸辩殑鎺掕鏉＄洰
                    print("[闃佃惀] 妫€娴嬪埌鐩熶富缁т綅! 閲嶆柊鍙戝竷 camp_meta")
                    CloudManager._factionRole = "leader"
                    CloudManager._factionMeta = latestMeta

                    CloudAPI:BatchSet()
                        :SetInt(KEYS.camp_leader_ts, os.time())
                        :Set(KEYS.camp_meta, latestMeta)
                        :Save("鏂扮洘涓绘帴绠￠樀钀?, {
                            ok = function()
                                print("[闃佃惀] 鏂扮洘涓绘帴绠″畬鎴? " .. (latestMeta.name or ""))
                                CloudManager._syncSocialDomain()
                                CloudManager.PublishProfile()
                                if callback then callback(true) end
                            end,
                            error = function()
                                print("[闃佃惀] 鎺ョ鍙戝竷澶辫触, 涓嬫鐧诲綍閲嶈瘯")
                                if callback then callback(false) end
                            end,
                        })
                    return
                else
                    -- 宸茬粡鏄洘涓? 鏇存柊meta缂撳瓨
                    CloudManager._factionMeta = latestMeta
                end
            else
                -- 闈炵洘涓? 鏇存柊瑙掕壊, 淇濈暀meta渚沀I鏄剧ず(鐩熶富鍚?浜烘暟绛?
                local roles = latestMeta.roles or {}
                local myRole = roles[tostring(myUid)] or "member"
                CloudManager._factionRole = myRole
                CloudManager._factionMeta = latestMeta
            end

            if callback then callback(false) end
        end,
        error = function(_, reason)
            print("[闃佃惀] 鍒锋柊闃佃惀鐘舵€佸け璐? " .. tostring(reason))
            if callback then callback(false) end
        end,
    }, KEYS.camp_meta)
end


