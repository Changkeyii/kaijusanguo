-- ============================================================================
-- cloud_manager_features.lua - 涓夊浗姝︾伒褰?(浠?cloud_manager.lua 鎷嗗垎)
-- 鍔熻兘妯″潡: 鑱婂ぉ銆佹湰鍦癐O銆佹洿鏂板惊鐜€佸皝绂佺鐞嗐€佺鐞嗗憳銆侀偖浠?"
-- ============================================================================
---@diagnostic disable: undefined-global

-- 浠?core 妯″潡瀵煎叆甯搁噺鍜屽叡浜姸鎬?"
local C = CloudManager._C
local S = CloudManager._S
local PREFIX = C.PREFIX
local DOMAINS = C.DOMAINS
local KEYS = C.KEYS
local SAVE_VERSION = C.SAVE_VERSION
local FACTION_ROLES = C.FACTION_ROLES
local ROLE_SUCCESSION = C.ROLE_SUCCESSION
local BAN_LEVEL_NONE = C.BAN_LEVEL_NONE
local BAN_LEVEL_SOCIAL = C.BAN_LEVEL_SOCIAL
local BAN_LEVEL_CORE = C.BAN_LEVEL_CORE
local BAN_LEVEL_FULL = C.BAN_LEVEL_FULL
local HASH_SEED = C.HASH_SEED
local HASH_SECRET = C.HASH_SECRET
local _getRoleLevel = C._getRoleLevel
local _getRoleName = C._getRoleName

local function _getRankItemUserId(item)
    if rawget(_G, "ResolveRankListUserId") then
        return ResolveRankListUserId(item)
    end
    return tonumber(item and (item.userId or item.player or item.uid)) or 0
end

-- ============================================================================
-- 闃佃惀鑱婂ぉ (浜戠鍚屾)
-- ============================================================================

local MAX_CHAT_HISTORY = 10   -- 姣忎汉鍦ㄦ帓琛屾淇濈暀鐨勬渶杩戞秷鎭暟
local CHAT_POLL_INTERVAL = 12 -- 鑱婂ぉ杞闂撮殧(绉?"
CloudManager._chatLastPoll = 0
CloudManager._chatLastSentTs = 0
CloudManager._chatPendingMsgs = {}  -- 寰呭彂甯冪殑鏈湴娑堟伅闃熷垪
CloudManager._chatMerged = {}       -- 鍚堝苟鍚庣殑鍏ㄩ儴娑堟伅 (鎸?ts 鎺掑簭)
CloudManager._chatSeenTs = {}       -- 宸茶杩囩殑鏈€澶?ts (per uid)

--- 鍙戦€侀樀钀ヨ亰澶╂秷鎭?(鍐欏叆鏈湴闃熷垪 + 绔嬪嵆鍙戝竷鍒版帓琛屾)
---@param text string 娑堟伅鍐呭
---@param senderName string 鍙戦€佽€呮樀绉?"
function CloudManager.SendFactionChat(text, senderName)
    if CloudManager._factionId == 0 then return false, "未加入阵营" end
    if not CloudAPI.IsAvailable() then return false, "云端不可用" end
    if not text or #text == 0 then return false, "消息为空" end

    local avIdx = (rawget(_G, "playerInfo") and playerInfo.avatarIdx) or 1
    local ts = os.time()
    local msg = {
        text = text,
        name = senderName or "???",
        time = os.date("%H:%M", ts),
        ts = ts,
        uid = CloudAPI.GetUserId(),
        av = avIdx,
    }
    -- 杩藉姞鍒版湰鍦伴槦鍒?"
    table.insert(CloudManager._chatPendingMsgs, msg)
    -- 涔熻拷鍔犲埌鍚堝苟鍒楄〃浠ヤ究绔嬪埢鏄剧ず
    table.insert(CloudManager._chatMerged, msg)

    -- 鏍囪鑷繁鐨勬椂闂存埑宸茶锛岄槻姝㈣疆璇㈡椂閲嶅鎷夊彇鏈潯娑堟伅
    CloudManager._chatSeenTs[CloudAPI.GetUserId()] = ts

    -- 鍙戝竷鍒版帓琛屾 (淇濈暀鏈€杩?N 鏉?"
    local toPublish = {}
    local start = math.max(1, #CloudManager._chatPendingMsgs - MAX_CHAT_HISTORY + 1)
    for i = start, #CloudManager._chatPendingMsgs do
        local m = CloudManager._chatPendingMsgs[i]
        toPublish[#toPublish + 1] = { text = m.text, name = m.name, time = m.time, ts = m.ts, av = m.av }
    end

    CloudAPI:BatchSet()
        :SetInt(KEYS.camp_chat_ts, ts)
        :Set(KEYS.camp_chat, toPublish)
        :Save("发送阵营聊天")

    CloudManager._chatLastSentTs = ts
    return true
end

--- 鐢熸垚绫诲瀷瀹夊叏鐨勮亰澶╁幓閲?key锛堥伩鍏?int/float tostring 宸紓瀵艰嚧鍘婚噸澶辫触锛?"
local function chatMsgKey(uid, ts)
    return string.format("%d_%d", math.floor(tonumber(uid) or 0), math.floor(tonumber(ts) or 0))
end

--- 鎷夊彇闃佃惀鑱婂ぉ娑堟伅 (浠庢帓琛屾鑾峰彇鎵€鏈夋垚鍛樼殑鏈€杩戞秷鎭?"
---@param callback? fun(messages: table[])
function CloudManager.PollFactionChat(callback)
    if CloudManager._factionId == 0 then
        if callback then callback({}) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end

    CloudAPI:GetRankList(KEYS.camp_chat_ts, 0, 100, {
        ok = function(rankList)
            local newMsgs = {}
            for _, item in ipairs(rankList) do
                local chatData = item.score[KEYS.camp_chat]
                if type(chatData) == "table" then
                    local senderUid = _getRankItemUserId(item)
                    local seenTs = CloudManager._chatSeenTs[senderUid] or 0
                    for _, m in ipairs(chatData) do
                        if type(m) == "table" and m.ts and m.ts > seenTs then
                            -- 鏂版秷鎭?"
                            newMsgs[#newMsgs + 1] = {
                                text = m.text or "",
                                name = m.name or "???",
                                time = m.time or "",
                                ts = m.ts,
                                uid = senderUid,
                                av = m.av or 1,
                            }
                        end
                    end
                    -- 鏇存柊宸茶鏃堕棿鎴?"
                    if #chatData > 0 then
                        local maxTs = seenTs
                        for _, m in ipairs(chatData) do
                            if type(m) == "table" and m.ts and m.ts > maxTs then maxTs = m.ts end
                        end
                        CloudManager._chatSeenTs[senderUid] = maxTs
                    end
                end
            end

            -- 鍚堝苟鍒板叏灞€鍒楄〃 (鍘婚噸, 浣跨敤绫诲瀷瀹夊叏鐨?key)
            local existingTs = {}
            for _, m in ipairs(CloudManager._chatMerged) do
                existingTs[chatMsgKey(m.uid, m.ts)] = true
            end
            for _, m in ipairs(newMsgs) do
                local key = chatMsgKey(m.uid, m.ts)
                if not existingTs[key] then
                    table.insert(CloudManager._chatMerged, m)
                end
            end

            -- 鎸?ts 鎺掑簭
            table.sort(CloudManager._chatMerged, function(a, b) return (a.ts or 0) < (b.ts or 0) end)

            -- 淇濈暀鏈€杩?50 鏉?"
            while #CloudManager._chatMerged > 50 do
                table.remove(CloudManager._chatMerged, 1)
            end

            if callback then callback(CloudManager._chatMerged) end
        end,
        error = function()
            if callback then callback(CloudManager._chatMerged) end
        end,
    }, KEYS.camp_chat)
end

--- 鑾峰彇褰撳墠鍚堝苟鐨勮亰澶╂秷鎭垪琛?(渚沀I鐩存帴璇诲彇)
---@return table[]
function CloudManager.GetFactionChatMessages()
    return CloudManager._chatMerged
end

-- ============================================================================
-- 涓栫晫鑱婂ぉ (鍏ㄦ湇鍏叡棰戦亾, 鎺掕姒滃瓨鍌?"
-- ============================================================================
local WORLD_CHAT_MAX_PER_USER = 5     -- 姣忎汉鍦ㄦ帓琛屾淇濈暀鐨勬渶杩戞秷鎭暟
local WORLD_CHAT_POLL_INTERVAL = 6    -- 涓栫晫鑱婂ぉ杞闂撮殧(绉? - 鏇村疄鏃?"
local WORLD_CHAT_MAX_MERGED = 100     -- 鏈湴鍚堝苟鍒楄〃鏈€澶ф潯鏁?"

CloudManager._worldChatLastPoll = 0
CloudManager._worldChatPendingMsgs = {}
CloudManager._worldChatMerged = {}
CloudManager._worldChatSeenTs = {}

--- 鍙戦€佷笘鐣岃亰澶╂秷鎭?"
---@param text string 娑堟伅鍐呭
---@param senderName string 鍙戦€佽€呭悕瀛?"
---@return boolean, string?"
function CloudManager.SendWorldChat(text, senderName)
    if not CloudAPI.IsAvailable() then return false, "云端不可用" end
    if not text or #text == 0 then return false, "消息为空" end

    local avIdx = (rawget(_G, "playerInfo") and playerInfo.avatarIdx) or 1
    local ts = os.time()
    -- 闃叉鍚屼竴绉掑唴閲嶅鍙戦€佺浉鍚屽唴瀹癸紙绉诲姩绔敭鐩樺洖杞?鎸夐挳鍙兘鍙岃Е鍙戯級
    if CloudManager._lastWorldChatTs == ts and CloudManager._lastWorldChatText == text then
        return true
    end
    CloudManager._lastWorldChatTs = ts
    CloudManager._lastWorldChatText = text
    local msg = {
        text = text,
        name = senderName or "???",
        time = os.date("%H:%M", ts),
        ts = ts,
        uid = CloudAPI.GetUserId(),
        av = avIdx,
    }
    table.insert(CloudManager._worldChatPendingMsgs, msg)
    table.insert(CloudManager._worldChatMerged, msg)

    -- 鏍囪鑷繁鐨勬椂闂存埑宸茶锛岄槻姝㈣疆璇㈡椂閲嶅鎷夊彇鏈潯娑堟伅
    CloudManager._worldChatSeenTs[CloudAPI.GetUserId()] = ts

    -- 鍙戝竷鍒版帓琛屾 (淇濈暀鏈€杩?N 鏉?"
    local toPublish = {}
    local start = math.max(1, #CloudManager._worldChatPendingMsgs - WORLD_CHAT_MAX_PER_USER + 1)
    for i = start, #CloudManager._worldChatPendingMsgs do
        local m = CloudManager._worldChatPendingMsgs[i]
        toPublish[#toPublish + 1] = { text = m.text, name = m.name, time = m.time, ts = m.ts, av = m.av }
    end

    CloudAPI:BatchSet()
        :SetInt(KEYS.world_chat_ts, ts)
        :Set(KEYS.world_chat, toPublish)
        :Save("发送世界聊天")

    return true
end

--- 鎷夊彇涓栫晫鑱婂ぉ娑堟伅 (浠庢帓琛屾鑾峰彇鏈€杩?0涓敤鎴风殑娑堟伅)
---@param callback? fun(messages: table[])
function CloudManager.PollWorldChat(callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end

    CloudAPI:GetRankList(KEYS.world_chat_ts, 0, 30, {
        ok = function(rankList)
            local newMsgs = {}
            for _, item in ipairs(rankList) do
                local chatData = item.score[KEYS.world_chat]
                if type(chatData) == "table" then
                    local senderUid = _getRankItemUserId(item)
                    local seenTs = CloudManager._worldChatSeenTs[senderUid] or 0
                    for _, m in ipairs(chatData) do
                        if type(m) == "table" and m.ts and m.ts > seenTs then
                            newMsgs[#newMsgs + 1] = {
                                text = m.text or "",
                                name = m.name or "???",
                                time = m.time or "",
                                ts = m.ts,
                                uid = senderUid,
                                av = m.av or 1,
                            }
                        end
                    end
                    if #chatData > 0 then
                        local maxTs = seenTs
                        for _, m in ipairs(chatData) do
                            if type(m) == "table" and m.ts and m.ts > maxTs then maxTs = m.ts end
                        end
                        CloudManager._worldChatSeenTs[senderUid] = maxTs
                    end
                end
            end

            -- 鍚堝苟鍒板叏灞€鍒楄〃 (鍘婚噸, 浣跨敤绫诲瀷瀹夊叏鐨?key)
            local existingTs = {}
            for _, m in ipairs(CloudManager._worldChatMerged) do
                existingTs[chatMsgKey(m.uid, m.ts)] = true
            end
            for _, m in ipairs(newMsgs) do
                local key = chatMsgKey(m.uid, m.ts)
                if not existingTs[key] then
                    table.insert(CloudManager._worldChatMerged, m)
                end
            end

            -- 鎸?ts 鎺掑簭
            table.sort(CloudManager._worldChatMerged, function(a, b) return (a.ts or 0) < (b.ts or 0) end)

            -- 淇濈暀鏈€杩?100 鏉?"
            while #CloudManager._worldChatMerged > WORLD_CHAT_MAX_MERGED do
                table.remove(CloudManager._worldChatMerged, 1)
            end

            -- 鎵归噺鏌ヨ nickname 瑕嗙洊 name 瀛楁
            local uidSet = {}
            local uidList = {}
            for _, m in ipairs(CloudManager._worldChatMerged) do
                local uid = m.uid or 0
                if uid > 0 and not uidSet[uid] then
                    uidSet[uid] = true
                    uidList[#uidList + 1] = uid
                end
            end
            if #uidList > 0 and rawget(_G, "GetUserNickname") then
                pcall(function()
                    GetUserNickname({
                        userIds = uidList,
                        onSuccess = function(nicknames)
                            local nameMap = {}
                            for _, info in ipairs(nicknames) do
                                nameMap[info.userId] = info.nickname
                            end
                            -- 缂撳瓨鑷繁鐨?TapTap nickname锛屼緵鍙戦€佹椂鐩存帴浣跨敤
                            local myUid = CloudAPI.GetUserId()
                            if myUid and nameMap[myUid] and #nameMap[myUid] > 0 then
                                CloudManager._myTapNickname = nameMap[myUid]
                            end
                            for _, m in ipairs(CloudManager._worldChatMerged) do
                                local nick = nameMap[m.uid or 0]
                                if nick and #nick > 0 then m.name = nick end
                            end
                            if callback then callback(CloudManager._worldChatMerged) end
                        end,
                        onError = function()
                            if callback then callback(CloudManager._worldChatMerged) end
                        end,
                    })
                end)
            else
                if callback then callback(CloudManager._worldChatMerged) end
            end
        end,
        error = function()
            if callback then callback(CloudManager._worldChatMerged) end
        end,
    }, KEYS.world_chat)
end

--- 鑾峰彇褰撳墠涓栫晫鑱婂ぉ娑堟伅鍒楄〃 (渚沀I鐩存帴璇诲彇)
---@return table[]
function CloudManager.GetWorldChatMessages()
    return CloudManager._worldChatMerged
end

-- ============================================================================
-- 鍐呴儴宸ュ叿鍑芥暟
-- ============================================================================

--- 淇濆瓨鏈湴JSON (澶歞omain鏍煎紡)
function CloudManager._saveLocalJSON(allData)
    local cjson_m = rawget(_G, "cjson")
    if not cjson_m then return end

    -- 濡傛灉娌′紶allData, 閲嶆柊鏀堕泦
    if not allData then
        allData = {}
        for name, _ in pairs(DOMAINS) do
            allData[name] = CloudManager.CollectDomainData(name)
        end
    end

    local saveObj = {
        _multiDomain = true,
        _version = SAVE_VERSION,
        savedAt = os.time(),
        domains = allData,
    }

    local ok, json = pcall(cjson_m.encode, saveObj)
    if ok then
        local file = File("p_49dd_savegame.json", FILE_WRITE)
        if file:IsOpen() then
            file:WriteString(json)
            file:Close()
        end
    end
end

--- 鍔犺浇鏈湴JSON
---@return table|nil
function CloudManager._loadLocalJSON()
    if not fileSystem:FileExists("p_49dd_savegame.json") then
        return nil
    end
    local cjson_m = rawget(_G, "cjson")
    if not cjson_m then return nil end

    local file = File("p_49dd_savegame.json", FILE_READ)
    if not file:IsOpen() then return nil end

    local ok, data = pcall(cjson_m.decode, file:ReadString())
    file:Close()
    if ok and data then return data end
    return nil
end

--- 浠庡domain鏁版嵁鎭㈠娓告垙鐘舵€?"
function CloudManager._applyMultiDomain(saveObj)
    local domains = saveObj.domains
    if not domains then return end

    -- core -> playerInfo
    if domains.core and domains.core.playerInfo then
        for k, v in pairs(domains.core.playerInfo) do
            playerInfo[k] = v
        end
    end

    -- heroes
    if domains.heroes then
        local d = domains.heroes
        if d.playerHeroes then
            for k in pairs(playerHeroes) do playerHeroes[k] = nil end
            for k, v in pairs(d.playerHeroes) do
                local idx = tonumber(k) or k
                if type(v) == "table" then
                    if v.owned == nil then v.owned = true end
                    if v.constellation == nil then v.constellation = 0 end
                    v.constellation = tonumber(v.constellation) or 0
                    playerHeroes[idx] = v
                end
            end
        end
        if d.heroFragments then
            for k, v in pairs(d.heroFragments) do heroFragments[tonumber(k) or k] = v end
        end
    end

    -- equip
    if domains.equip and domains.equip.playerEquipment then
        -- 澶嶇敤 ApplySaveData 鐨勮澶囨仮澶嶉€昏緫 (鍚柊鏃ф牸寮忚縼绉?"
        if rawget(_G, "ApplySaveData") then
            ApplySaveData({ playerEquipment = domains.equip.playerEquipment })
        end
    end

    -- skills
    if domains.skills then
        local d = domains.skills
        if d.playerEquippedSkills then playerEquippedSkills = d.playerEquippedSkills end
        if d.unlockedSkills then
            for _, idx in ipairs(d.unlockedSkills) do
                if SKILL_DEFS[idx] then SKILL_DEFS[idx].unlocked = true end
            end
        end
        if d.skillFragments then
            for k, v in pairs(d.skillFragments) do skillFragments[tonumber(k) or k] = v end
        end
        if d.skillLayers then
            for k, v in pairs(d.skillLayers) do skillLayers[tonumber(k) or k] = v end
        end
        for idx = 1, #SKILL_DEFS do
            if SKILL_DEFS[idx].unlocked and not skillLayers[idx] then
                skillLayers[idx] = 1
            end
        end
    end

    -- progress
    if domains.progress then
        local d = domains.progress
        if d.stageMaxUnlocked then stageState.maxUnlocked = d.stageMaxUnlocked end
        if d.stageCurrentPage then stageState.currentPage = d.stageCurrentPage end
        if d.stageStars then stageStars = d.stageStars end
        if d.stageStarClaimed then stageStarClaimed = d.stageStarClaimed end
        if d.stageChestClaimed then stageChestClaimed = d.stageChestClaimed end
        if d.abyssCleared then abyssCleared = d.abyssCleared end
        if d.towerHighestFloor then towerState.highestFloor = d.towerHighestFloor end
        if d.towerCurrentFloor then towerState.currentFloor = math.min(d.towerCurrentFloor, 1000) end
        if d.rankedScore then rankedState.score = d.rankedScore end
        if d.rankedWins then rankedState.wins = d.rankedWins end
        if d.rankedLosses then rankedState.losses = d.rankedLosses end
        if d.rankedStreak then rankedState.streak = d.rankedStreak end
        if d.rankedHighestScore then rankedState.highestScore = d.rankedHighestScore end
        if d.gachaPity then gachaState.pityCounter = d.gachaPity end
        if d.limitedGachaPity then gachaState.limitedPityCounter = d.limitedGachaPity end
    end

    -- welfare (澶嶇敤 ApplySaveData 鐨勬仮澶嶉€昏緫)
    if domains.welfare then
        if rawget(_G, "ApplySaveData") then
            ApplySaveData(domains.welfare)
        end
    end

    -- social
    if domains.social then
        local d = domains.social
        CloudManager._friendIds = d.friendIds or {}
        CloudManager._factionId = d.factionId or 0
        CloudManager._factionName = d.factionName or ""
        CloudManager._factionRole = d.factionRole or "none"
    end

    -- explore
    if domains.explore and domains.explore.explorationState then
        if rawget(_G, "Exploration") and Exploration.RestoreState then
            Exploration.Init(vg, fontId, IMG)
            if rawget(_G, "SyncPlayerDataToExploration") then
                SyncPlayerDataToExploration()
            end
            Exploration.RestoreState(domains.explore.explorationState)
            print("[CloudManager] 鎺㈢储鐘舵€佸凡鎭㈠")
        end
    end

    -- worldmap
    if domains.worldmap and domains.worldmap.turn then
        local wm = rawget(_G, "WorldMap")
        local wms = rawget(_G, "worldMapState")
        if wm and wms then
            local wd = domains.worldmap
            wms.turn = wd.turn or 1
            wms.totalTurns = wd.totalTurns or wms.turn
            wms.gold = wd.gold or 500
            wms.food = wd.food or 300
            wms.troops = wd.troops or 200
            wms.playerFaction = wd.playerFaction or "shu"
            wms.phase = "MAP"
            wms.inited = true
            -- 鎭㈠澶栦氦
            if wd.diplomacy then
                wms.diplomacy = wd.diplomacy
            else
                wms.diplomacy = {
                    shu = { relation = 30, treaty = nil },
                    wei = { relation = 20, treaty = nil },
                    qun = { relation = 40, treaty = nil },
                }
            end
            -- 鎭㈠鍩庢睜鏁版嵁
            if wd.cityData then
                for _, c in ipairs(WORLD_CITIES) do
                    local saved = wd.cityData[tostring(c.id)]
                    if saved then
                        wms.cityData[c.id] = {
                            owner = saved.owner or c.faction,
                            garrison = saved.garrison or 50,
                            level = saved.level or 1,
                            heroes = saved.heroes or {},
                            morale = saved.morale or 80,
                        }
                    else
                        wms.cityData[c.id] = {
                            owner = c.faction, garrison = 50, level = 1, heroes = {}, morale = 80,
                        }
                    end
                end
            end
            -- 鎭㈠鍏电閫夋嫨 (key浠巗tring杞洖number)
            wms.heroTroopChoice = {}
            if wd.heroTroopChoice then
                for k, v in pairs(wd.heroTroopChoice) do
                    local idx = tonumber(k)
                    if idx then wms.heroTroopChoice[idx] = v end
                end
            end
            -- 鎭㈠宸插姝︽妧
            wms.heroLearnedSkills = {}
            if wd.heroLearnedSkills then
                for k, v in pairs(wd.heroLearnedSkills) do
                    local idx = tonumber(k)
                    if idx then wms.heroLearnedSkills[idx] = v end
                end
            end
            print("[CloudManager] 澶у湴鍥剧姸鎬佸凡鎭㈠, 鍥炲悎=" .. tostring(wms.turn))
        end
    end

    -- 鍚戜笅鍏煎: level 涓?rankIdx 鍚屾
    playerInfo.level = playerInfo.rankIdx or 1
    if rawget(_G, "CheckPlayerLevelUp") then
        CheckPlayerLevelUp()
    end
end

--- 鏋勫缓鏃ф牸寮忓瓨妗ｆ暟鎹?(鍚戜笅鍏煎)
function CloudManager._buildLegacyData(allData)
    -- 鍚堝苟鎵€鏈塪omain鍒颁竴涓墎骞硉able (涓庢棫 SaveGameProgress 缁撴瀯涓€鑷?"
    local legacy = { savedAt = os.time() }

    if allData.core then
        legacy.playerInfo = allData.core.playerInfo
    end
    if allData.heroes then
        legacy.playerHeroes = allData.heroes.playerHeroes
        legacy.heroFragments = allData.heroes.heroFragments
    end
    if allData.equip then
        legacy.playerEquipment = allData.equip.playerEquipment
    end
    if allData.skills then
        legacy.playerEquippedSkills = allData.skills.playerEquippedSkills
        legacy.unlockedSkills = allData.skills.unlockedSkills
        legacy.skillFragments = allData.skills.skillFragments
        legacy.skillLayers = allData.skills.skillLayers
    end
    if allData.progress then
        local d = allData.progress
        legacy.stageMaxUnlocked = d.stageMaxUnlocked
        legacy.stageCurrentPage = d.stageCurrentPage
        legacy.stageStars = d.stageStars
        legacy.stageStarClaimed = d.stageStarClaimed
        legacy.stageChestClaimed = d.stageChestClaimed
        legacy.abyssCleared = d.abyssCleared
        legacy.towerHighestFloor = d.towerHighestFloor
        legacy.towerCurrentFloor = d.towerCurrentFloor
        legacy.rankedScore = d.rankedScore
        legacy.rankedWins = d.rankedWins
        legacy.rankedLosses = d.rankedLosses
        legacy.rankedStreak = d.rankedStreak
        legacy.rankedHighestScore = d.rankedHighestScore
        legacy.gachaPity = d.gachaPity
        legacy.limitedGachaPity = d.limitedGachaPity
    end
    if allData.welfare then
        local d = allData.welfare
        legacy.dailyTaskState = d.dailyTaskState
        legacy.weeklyTaskState = d.weeklyTaskState
        legacy.achievementClaimed = d.achievementClaimed
        legacy.welfareState = d.welfareState
        legacy.cdkRedeemed = d.cdkRedeemed
        legacy.mailClaimed = d.mailClaimed
        legacy.tutorialRewardClaimed = d.tutorialRewardClaimed
        legacy.sealData = d.sealData
        legacy.sealExpItems = d.sealExpItems
        legacy.sealInventory = d.sealInventory
        legacy.sealInventoryNextId = d.sealInventoryNextId
        legacy.dailyDungeonState = d.dailyDungeonState
        legacy.resourceDungeonState = d.resourceDungeonState
        legacy.battlePassState = d.battlePassState
    end
    if allData.explore then
        legacy.explorationState = allData.explore.explorationState
    end

    return legacy
end

-- 鈹€鈹€ 绀句氦杞瀹氭椂鍣?鈹€鈹€
local socialPollTimer = 0
local SOCIAL_POLL_INTERVAL = 15  -- 姣?5绉掕疆璇竴娆＄ぞ浜ょ姸鎬?"
local socialPollBusy = false     -- 闃叉骞跺彂杞

--- 鏇存柊閲嶈瘯瀹氭椂鍣?+ 绀句氦杞 (鍦?HandleUpdate 涓皟鐢?"
function CloudManager.Update(dt)
    if S.retryTimer > 0 then
        S.retryTimer = S.retryTimer - dt
        if S.retryTimer <= 0 and S.retryData then
            print("[CloudManager] 閲嶈瘯浜戠鍚屾...")
            CloudManager.SaveAll()
            S.retryData = nil
        end
    end

    -- 绀句氦杞: 濂藉弸鍥炲 + 闃佃惀瀹℃壒缁撴灉
    if not CloudAPI.IsAvailable() then return end
    socialPollTimer = socialPollTimer + dt
    if socialPollTimer >= SOCIAL_POLL_INTERVAL and not socialPollBusy then
        socialPollTimer = 0
        socialPollBusy = true

        -- 1) 濂藉弸鍥炲杞: 妫€鏌ユ垜鍙戝嚭鐨勫ソ鍙嬭姹傛槸鍚﹁瀵规柟鍥炲
        CloudManager.CheckMyRequestResponses(function(results)
            if results and #results > 0 then
                for _, r in ipairs(results) do
                    if r.accepted then
                        print("[绀句氦杞] 濂藉弸璇锋眰琚?" .. tostring(r.toUid) .. " 鍚屾剰, 宸蹭簰鍔?")
                        if rawget(_G, "ShowToast") then ShowToast("浣犱笌玩家" .. tostring(r.toUid) .. "宸叉垚涓哄ソ鍙?") end
                        if rawget(_G, "playerInfo") then
                            playerInfo.totalFriends = (playerInfo.totalFriends or 0) + 1
                        end
                    end
                end
                -- 鍒锋柊濂藉弸鐣岄潰
                if rawget(_G, "friendsUI") then
                    friendsUI.loaded = false; friendsUI.loading = false
                end
            end

            -- 2) 闃佃惀瀹℃壒杞: 妫€鏌ユ垜鐨勫叆钀ョ敵璇锋槸鍚﹁鎵瑰噯
            CloudManager.CheckMyFactionApplication(function(result)
                socialPollBusy = false
                if result == "approved" then
                    print("[绀句氦杞] 鍏ヨ惀鐢宠宸查€氳繃!")
                    if rawget(_G, "ShowToast") then ShowToast("浣犵殑鍏ヨ惀鐢宠宸查€氳繃!") end
                    if rawget(_G, "playerInfo") then playerInfo.factionJoined = 1 end
                    if rawget(_G, "factionUI") then
                        factionUI.loaded = false; factionUI.loading = false
                        factionUI.applyStatus = nil
                    end
                elseif result == "rejected" then
                    print("[绀句氦杞] 鍏ヨ惀鐢宠琚嫆缁?")
                    if rawget(_G, "ShowToast") then ShowToast("浣犵殑鍏ヨ惀鐢宠琚嫆缁?") end
                    if rawget(_G, "factionUI") then factionUI.applyStatus = nil end
                end
            end)
        end)
    end

    -- 闃佃惀鑱婂ぉ杞
    if CloudManager._factionId ~= 0 then
        CloudManager._chatLastPoll = (CloudManager._chatLastPoll or 0) + dt
        if CloudManager._chatLastPoll >= CHAT_POLL_INTERVAL then
            CloudManager._chatLastPoll = 0
            CloudManager.PollFactionChat()
        end
    end

    -- 涓栫晫鑱婂ぉ杞 (濮嬬粓杩愯)
    CloudManager._worldChatLastPoll = (CloudManager._worldChatLastPoll or 0) + dt
    if CloudManager._worldChatLastPoll >= WORLD_CHAT_POLL_INTERVAL then
        CloudManager._worldChatLastPoll = 0
        CloudManager.PollWorldChat()
    end
end

-- ============================================================================
-- 渚挎嵎璁块棶
-- ============================================================================

--- 鑾峰彇鎵€鏈塪omain key鍚?"
function CloudManager.GetDomainKeys()
    return DOMAINS
end

--- 鑾峰彇鍓嶇紑
function CloudManager.GetPrefix()
    return PREFIX
end

--- 鑾峰彇涓婃鍚屾鏃堕棿
function CloudManager.GetLastSyncTime()
    return S.lastSyncTime
end

--- 浜戠鏁版嵁鏄惁姝ｅ湪鍔犺浇涓?(LoadAll 寮傛鏈熼棿涓?true)
--- 鐢ㄤ簬 UI 灞傞樆鏂帺瀹舵搷浣? 闃叉鍦ㄤ簯鏁版嵁鍒拌揪鍓嶄骇鐢熻剰鏁版嵁
---@return boolean
function CloudManager.IsCloudLoading()
    return S.cloudLoadPending
end

-- ============================================================================
-- 灏佺绯荤粺
-- ============================================================================

--- 灏佺绛夌骇甯搁噺 (渚涘閮ㄤ娇鐢?"
CloudManager.BAN_LEVEL_NONE   = BAN_LEVEL_NONE
CloudManager.BAN_LEVEL_SOCIAL = BAN_LEVEL_SOCIAL
CloudManager.BAN_LEVEL_CORE   = BAN_LEVEL_CORE
CloudManager.BAN_LEVEL_FULL   = BAN_LEVEL_FULL

--- 妫€鏌ュ綋鍓嶇帺瀹舵槸鍚﹁灏佺 (鍚姩鏃惰皟鐢?"
--- 鍘熺悊: 鎵弿 ban_ts 鎺掕姒? 鎵惧埌绠＄悊鍛樺彂甯冪殑灏佺鍚嶅崟, 妫€鏌ヨ嚜宸辨槸鍚﹀湪鍒楄〃涓?"
---@param callback fun(level: number, reason: string)
function CloudManager.CheckBanStatus(callback)
    if not CloudAPI.IsAvailable() then
        S.banChecked = true
        if callback then callback(BAN_LEVEL_NONE, "") end
        return
    end

    local myUid = CloudAPI.GetUserId()
    local myUidStr = tostring(myUid)

    -- 鎵弿 ban_ts 鎺掕姒?(绠＄悊鍛橀€氳繃 SetInt 鍙戝竷, 鎸夋椂闂村€掑簭)
    CloudAPI:GetRankList(KEYS.ban_ts, 0, 50, {
        ok = function(rankList)
            local foundLevel = BAN_LEVEL_NONE
            local foundReason = ""

            for _, item in ipairs(rankList) do
                local banData = item.score[KEYS.ban_data]
                if type(banData) == "table" then
                    -- 灏佺鍚嶅崟鏍煎紡: { bans = { ["uid"] = { level=1-3, reason="...", until=timestamp } } }
                    local bans = banData.bans
                    if type(bans) == "table" and bans[myUidStr] then
                        local entry = bans[myUidStr]
                        -- 妫€鏌ユ槸鍚﹀凡杩囨湡
                        local untilTime = entry["until"] or 0
                        if untilTime == 0 or untilTime > os.time() then
                            local lvl = entry.level or BAN_LEVEL_FULL
                            if lvl > foundLevel then
                                foundLevel = lvl
                                foundReason = entry.reason or "杩濊鎿嶄綔"
                            end
                        end
                    end
                end
            end

            -- 鍔犺浇闅愯棌鍚嶅崟 (绠＄悊鍛樼敤)
            if not CloudManager._hiddenPlayers then CloudManager._hiddenPlayers = {} end
            for _, item2 in ipairs(rankList) do
                local bd2 = item2.score[KEYS.ban_data]
                if type(bd2) == "table" and type(bd2.bans) == "table" then
                    for uid2, info2 in pairs(bd2.bans) do
                        if type(info2) == "table" and info2.rankHidden then
                            CloudManager._hiddenPlayers[tostring(uid2)] = true
                        end
                    end
                end
            end

            S.banLevel = foundLevel
            S.banReason = foundReason
            S.banChecked = true

            if foundLevel > BAN_LEVEL_NONE then
                print("[灏佺] 妫€娴嬪埌灏佺: 绛夌骇=" .. foundLevel .. " 鍘熷洜=" .. foundReason)
            else
                print("[灏佺] 鏈灏佺")
            end

            if callback then callback(foundLevel, foundReason) end
        end,
        error = function(_, reason)
            print("[灏佺] 妫€鏌ュ皝绂佺姸鎬佸け璐? " .. tostring(reason))
            S.banChecked = true
            -- 缃戠粶澶辫触鏃朵笉灏佺 (瀹芥澗绛栫暐)
            if callback then callback(BAN_LEVEL_NONE, "") end
        end,
    }, KEYS.ban_data)
end

--- 鑾峰彇褰撳墠灏佺绛夌骇
---@return number 0=鏃? 1=绀句氦, 2=鏍稿績, 3=鍏ㄥ皝
function CloudManager.GetBanLevel()
    return S.banLevel
end

--- 鑾峰彇灏佺鍘熷洜
---@return string
function CloudManager.GetBanReason()
    return S.banReason
end

--- 鏄惁宸插畬鎴愬皝绂佹鏌?"
---@return boolean
function CloudManager.IsBanChecked()
    return S.banChecked
end

--- 妫€鏌ユ槸鍚﹁灏佺鍒版寚瀹氱瓑绾?"
---@param level number 瑕佹鏌ョ殑绛夌骇
---@return boolean
function CloudManager.IsBanned(level)
    return S.banLevel >= (level or BAN_LEVEL_SOCIAL)
end

--- 鑾峰彇灏佺绛夌骇鐨勪腑鏂囨弿杩?"
---@param level number
---@return string
function CloudManager.GetBanLevelName(level)
    if level >= BAN_LEVEL_FULL then return "鍏ㄩ潰灏佺"
    elseif level >= BAN_LEVEL_CORE then return "鏍稿績鍔熻兘灏佺"
    elseif level >= BAN_LEVEL_SOCIAL then return "绀句氦灏佺"
    else return "鏃?" end
end

--- 绠＄悊鍛? 鑾峰彇褰撳墠灏佺鍚嶅崟 (浠庢帓琛屾璇诲彇鑷繁鍙戝竷鐨?"
---@param callback fun(bans: table|nil, err: string|nil)
function CloudManager.AdminGetBanList(callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback(nil, "CloudAPI不可用") end
        return
    end
    local myUid = CloudAPI.GetUserId()
    CloudAPI:Get(KEYS.ban_data, {
        ok = function(values)
            local data = values and values[KEYS.ban_data]
            if type(data) == "table" and type(data.bans) == "table" then
                if callback then callback(data.bans, nil) end
            else
                if callback then callback({}, nil) end
            end
        end,
        error = function(_, reason)
            if callback then callback(nil, tostring(reason)) end
        end,
    })
end

--- 绠＄悊鍛? 鍙戝竷灏佺鍚嶅崟 (瑕嗙洊寮忓啓鍏?"
--- bans 鏍煎紡: { ["uid_str"] = { level=1-3, reason="...", until=0 }, ... }
---@param bans table 灏佺鍚嶅崟
---@param callback fun(ok: boolean, err: string|nil)
function CloudManager.AdminPublishBanList(bans, callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "CloudAPI不可用") end
        return
    end
    local ts = os.time()
    CloudAPI:BatchSet()
        :SetInt(KEYS.ban_ts, ts)
        :Set(KEYS.ban_data, { bans = bans, updated = ts })
        :Save("admin_ban_update", {
            ok = function()
                print("[绠＄悊鍛榏 灏佺鍚嶅崟宸插彂甯? 鏉＄洰鏁? " .. CloudManager._tableCount(bans))
                if callback then callback(true, nil) end
            end,
            error = function(_, reason)
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 绠＄悊鍛? 灏嗘帓琛屾鍒嗘暟璁句负鏋佸皬鍊兼潵闅愯棌 (SetInt 璁句负 -999999)
---@param targetUid number 鐩爣玩家UID
---@param callback fun(ok: boolean, msg: string)
function CloudManager.AdminHidePlayerRank(targetUid, callback)
    -- 娉ㄦ剰: CloudAPI 鍙兘鎿嶄綔鑷繁鐨勬暟鎹? 鏃犳硶鐩存帴鍒犻櫎浠栦汉鎺掕姒?"
    -- 闅愯棌绛栫暐: 灏嗚 UID 鍔犲叆鏈湴闅愯棌鍒楄〃, 鍦ㄦ帓琛屾娓叉煋鏃惰繃婊?"
    if not CloudManager._hiddenPlayers then
        CloudManager._hiddenPlayers = {}
    end
    CloudManager._hiddenPlayers[tostring(targetUid)] = true
    -- 鎸佷箙鍖栧埌 ban_data 涓?"
    CloudManager.AdminGetBanList(function(bans, err)
        if not bans then bans = {} end
        local uidStr = tostring(targetUid)
        if not bans[uidStr] then
            bans[uidStr] = { level = 0, reason = "鎺掕姒滈殣钘?", ["until"] = 0 }
        end
        bans[uidStr].rankHidden = true
        CloudManager.AdminPublishBanList(bans, function(ok)
            if callback then callback(ok, ok and "宸查殣钘?" or "鎿嶄綔澶辫触") end
        end)
    end)
end

--- 绠＄悊鍛? 鎭㈠玩家鎺掕姒滄樉绀?"
---@param targetUid number
---@param callback fun(ok: boolean, msg: string)
function CloudManager.AdminUnhidePlayerRank(targetUid, callback)
    if CloudManager._hiddenPlayers then
        CloudManager._hiddenPlayers[tostring(targetUid)] = nil
    end
    CloudManager.AdminGetBanList(function(bans, err)
        if not bans then bans = {} end
        local uidStr = tostring(targetUid)
        if bans[uidStr] then
            bans[uidStr].rankHidden = nil
            -- 濡傛灉杩欐潯璁板綍鍙湁 rankHidden, level=0, 閭ｅ氨鍒犳帀鏁存潯
            if (bans[uidStr].level or 0) == 0 then
                bans[uidStr] = nil
            end
        end
        CloudManager.AdminPublishBanList(bans, function(ok)
            if callback then callback(ok, ok and "宸叉仮澶嶆樉绀?" or "鎿嶄綔澶辫触") end
        end)
    end)
end

--- 妫€鏌ユ煇涓帺瀹舵槸鍚﹁闅愯棌鎺掕姒?"
---@param uid number|string
---@return boolean
function CloudManager.IsPlayerRankHidden(uid)
    if not CloudManager._hiddenPlayers then return false end
    return CloudManager._hiddenPlayers[tostring(uid)] == true
end

--- 绠＄悊鍛? 鑾峰彇灏佺鍚嶅崟鎽樿锛堜緵 UI 鍒楄〃灞曠ず锛?"
--- 杩斿洖涓や釜鏁扮粍: tempBans(鏆傛椂灏佺), permBans(姘镐箙灏佺/宸插垹闄?"
---@param callback fun(tempBans: table, permBans: table, err: string|nil)
function CloudManager.AdminGetBanListSummary(callback)
    CloudManager.AdminGetBanList(function(bans, err)
        if err then
            if callback then callback({}, {}, err) end
            return
        end
        local tempList = {}
        local permList = {}
        for uidStr, info in pairs(bans or {}) do
            if type(info) == "table" then
                local entry = {
                    uid = uidStr,
                    level = info.level or 0,
                    reason = info.reason or "",
                    rankHidden = info.rankHidden or false,
                    permanent = info.permanent or false,
                }
                if info.permanent then
                    table.insert(permList, entry)
                elseif (info.level or 0) > 0 or info.rankHidden then
                    table.insert(tempList, entry)
                end
            end
        end
        -- 鎸?UID 鎺掑簭
        table.sort(tempList, function(a, b) return a.uid < b.uid end)
        table.sort(permList, function(a, b) return a.uid < b.uid end)
        if callback then callback(tempList, permList, nil) end
    end)
end

--- 绠＄悊鍛? 姘镐箙灏佺锛堟爣璁颁负宸插垹闄わ紝鍏ㄩ潰灏佺 + 鎺掕姒滈殣钘忥級
---@param targetUid number|string 鐩爣UID
---@param callback fun(ok: boolean, msg: string)
function CloudManager.AdminPermanentBan(targetUid, callback)
    local uidStr = tostring(targetUid)
    -- 鍔犲叆闅愯棌鍒楄〃
    if not CloudManager._hiddenPlayers then CloudManager._hiddenPlayers = {} end
    CloudManager._hiddenPlayers[uidStr] = true

    CloudManager.AdminGetBanList(function(bans, err)
        if not bans then bans = {} end
        bans[uidStr] = bans[uidStr] or {}
        bans[uidStr].level = 3          -- BAN_LEVEL_FULL
        bans[uidStr].reason = "姘镐箙灏佺(鏁版嵁宸插垹闄?"
        bans[uidStr]["until"] = 0       -- 姘镐箙
        bans[uidStr].rankHidden = true  -- 闅愯棌鎺掕姒?"
        bans[uidStr].permanent = true   -- 鏍囪涓烘案涔呭皝绂?"
        CloudManager.AdminPublishBanList(bans, function(ok)
            if callback then callback(ok, ok and "宸叉案涔呭皝绂?" or "鎿嶄綔澶辫触") end
        end)
    end)
end

--- 绠＄悊鍛? 灏嗘殏鏃跺皝绂佹仮澶嶏紙瀹屽叏瑙ｇ锛屽寘鎷帓琛屾锛?"
---@param targetUid number|string
---@param callback fun(ok: boolean, msg: string)
function CloudManager.AdminFullUnban(targetUid, callback)
    local uidStr = tostring(targetUid)
    -- 绉诲嚭闅愯棌鍒楄〃
    if CloudManager._hiddenPlayers then
        CloudManager._hiddenPlayers[uidStr] = nil
    end

    CloudManager.AdminGetBanList(function(bans, err)
        if not bans then bans = {} end
        bans[uidStr] = nil  -- 瀹屽叏绉婚櫎
        CloudManager.AdminPublishBanList(bans, function(ok)
            if callback then callback(ok, ok and "宸插畬鍏ㄨВ绂?" or "鎿嶄綔澶辫触") end
        end)
    end)
end

--- 鍐呴儴宸ュ叿: 璁＄畻table鍏冪礌鏁?"
function CloudManager._tableCount(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- ============================================================================
-- 棰戠巼闄愬埗
-- ============================================================================

--- 妫€鏌ユ搷浣滃喎鍗?(閫氳繃杩斿洖true/false琛ㄧず鏄惁鍙墽琛?"
--- 濡傛灉鍙墽琛? 鍚屾椂鏇存柊鏃堕棿鎴?"
---@param action string 鎿嶄綔鍚嶇О
---@param cooldownSeconds number 鍐峰嵈绉掓暟
---@return boolean 鏄惁鍏佽鎵ц
function CloudManager._checkCooldown(action, cooldownSeconds)
    local now = os.time()
    local lastTime = S.cooldownTimestamps[action] or 0
    if (now - lastTime) < cooldownSeconds then
        return false
    end
    S.cooldownTimestamps[action] = now
    return true
end

--- 鑾峰彇鎿嶄綔鍓╀綑鍐峰嵈鏃堕棿
---@param action string
---@param cooldownSeconds number
---@return number 鍓╀綑绉掓暟 (0=鍙墽琛?"
function CloudManager.GetCooldownRemaining(action, cooldownSeconds)
    local now = os.time()
    local lastTime = S.cooldownTimestamps[action] or 0
    local elapsed = now - lastTime
    if elapsed >= cooldownSeconds then return 0 end
    return cooldownSeconds - elapsed
end

-- ============================================================================
-- 璐熷€奸槻鎶?"
-- ============================================================================

--- 娓呯悊鍏抽敭璧勬簮鐨勮礋鍊?(闃叉浣滃紛/鏁版嵁寮傚父)
function CloudManager._sanitizeResources()
    if not rawget(_G, "playerInfo") then return end
    local pi = playerInfo
    -- 铏庣 (jade)
    if (pi.jade or 0) < 0 then
        print("[瀹夊叏] 铏庣涓鸿礋鍊?" .. tostring(pi.jade) .. "), 寮哄埗褰掗浂")
        pi.jade = 0
    end
    -- 鐏电煶 (lingshi)
    if (pi.lingshi or 0) < 0 then
        print("[瀹夊叏] 鐏电煶涓鸿礋鍊?" .. tostring(pi.lingshi) .. "), 寮哄埗褰掗浂")
        pi.lingshi = 0
    end
    -- 缁忛獙 (exp)
    if (pi.exp or 0) < 0 then
        print("[瀹夊叏] 缁忛獙涓鸿礋鍊?" .. tostring(pi.exp) .. "), 寮哄埗褰掗浂")
        pi.exp = 0
    end
    -- 绛夌骇 (rankIdx)
    if (pi.rankIdx or 1) < 1 then
        print("[瀹夊叏] 绛夌骇涓鸿礋鍊?" .. tostring(pi.rankIdx) .. "), 寮哄埗褰?")
        pi.rankIdx = 1
        pi.level = 1
    end
    -- 娣辨笂闂ㄧエ
    if (pi.abyssTickets or 0) < 0 then
        print("[瀹夊叏] 娣辨笂闂ㄧエ涓鸿礋鍊? 寮哄埗褰掗浂")
        pi.abyssTickets = 0
    end
end

-- ============================================================================
-- 瀛樻。鍝堝笇鏍￠獙
-- ============================================================================

--- 璁＄畻瀛樻。鍝堝笇 (绠€鍗曟贩娣嗘牎楠? 闈炲姞瀵嗙骇鍒?"
--- 鍘熺悊: 鎻愬彇鍏抽敭瀛楁 鈫?鏁板€兼眰鍜?鈫?娣峰悎uid鍜宻ecret 鈫?鍙栨ā寰楀埌鏍￠獙鍊?"
---@param allData table 鎵€鏈塪omain鏁版嵁 (鎴杁omain鍚嶁啋data鐨勬槧灏?"
---@return number hash鍊?"
function CloudManager._computeSaveHash(allData)
    local uid = 0
    if CloudAPI.IsAvailable() then
        uid = CloudAPI.GetUserId()
    end

    local sum = 0

    -- 浠?core 鎻愬彇鍏抽敭瀛楁
    local coreData = allData.core or allData[DOMAINS.core]
    if coreData and coreData.playerInfo then
        local pi = coreData.playerInfo
        sum = sum + (pi.jade or 0)
        sum = sum + (pi.lingshi or 0)
        sum = sum + (pi.rankIdx or 0) * 137
        sum = sum + (pi.totalBattles or 0) * 7
        sum = sum + (pi.totalWins or 0) * 13
        sum = sum + (pi.totalGachas or 0) * 31
        sum = sum + (pi.totalEquips or 0) * 17
        sum = sum + (pi.exp or 0)
    end

    -- 浠?progress 鎻愬彇
    local progData = allData.progress or allData[DOMAINS.progress]
    if progData then
        sum = sum + (progData.stageMaxUnlocked or 0) * 53
        sum = sum + (progData.towerHighestFloor or 0) * 41
        sum = sum + (progData.rankedHighestScore or 0) * 3
    end

    -- 娣峰悎 uid 鍜?secret
    local mixed = (uid * HASH_SEED + sum) ~ HASH_SECRET
    -- 纭繚姝ｆ暣鏁?(Lua 5.4 鏁存暟鍙兘涓鸿礋)
    if mixed < 0 then mixed = -mixed end
    return mixed % 999999937  -- 澶х礌鏁板彇妯?"
end

--- 妫€鏌ュ瓨妗ｅ搱甯屾槸鍚︿笉鍖归厤
---@return boolean true=鍝堝笇涓嶅尮閰?鍙兘琚鏀?"
function CloudManager.IsHashMismatch()
    return CloudManager._hashMismatch == true
end

-- ============================================================================
-- 闃佃惀鑱屼綅鏌ヨ (瀵煎嚭渚涘閮ㄤ娇鐢?"
-- ============================================================================

--- 瀵煎嚭鑱屼綅瀹氫箟琛?(渚沀I娓叉煋鐢?"
CloudManager.FACTION_ROLES = FACTION_ROLES

--- 鑾峰彇鎸囧畾瑙掕壊鐨勪腑鏂囧悕
---@param role string
---@return string
function CloudManager.GetRoleName(role)
    return _getRoleName(role)
end

--- 鑾峰彇鎸囧畾瑙掕壊鐨勭瓑绾?"
---@param role string
---@return number
function CloudManager.GetRoleLevel(role)
    return _getRoleLevel(role)
end

--- 鑾峰彇鎵€鏈夊彲鍒嗛厤鑱屼綅鍒楄〃 (涓嶅惈 leader, 渚沀I涓嬫媺妗嗙敤)
---@return table[] { id, name, level, max }
function CloudManager.GetAssignableRoles()
    local result = {}
    for _, roleName in ipairs(ROLE_SUCCESSION) do
        local def = FACTION_ROLES[roleName]
        result[#result + 1] = {
            id = roleName,
            name = def.name,
            level = def.level,
            max = def.max,
        }
    end
    return result
end

--- 鑾峰彇闃佃惀鎴愬憳鐨勮亴浣嶄俊鎭?(甯︿腑鏂囧悕)
---@param userId number
---@return string role, string roleName
function CloudManager.GetMemberRole(userId)
    local meta = CloudManager._factionMeta
    if not meta or not meta.roles then
        return "member", "鎴愬憳"
    end
    local role = meta.roles[tostring(userId)] or "member"
    return role, _getRoleName(role)
end

--- 鑾峰彇鑱屼綅绛夌骇鏁板€?(鏁板瓧瓒婂ぇ鏉冮檺瓒婇珮, leader=6, member=0)
function CloudManager.GetRoleLevel(role)
    return _getRoleLevel(role)
end

-- ============================================================================
-- 閭欢绯荤粺 (鍏叡淇＄妯″紡: 鍙戜欢浜哄啓 outbox, 鏀朵欢浜鸿疆璇㈡壂鎻?"
-- ============================================================================

local MAIL_MAX_OUTBOX = 20         -- 姣忎汉鍙戜欢绠辨渶澶氫繚鐣?0灏?"
local MAIL_EXPIRE_DAYS = 7        -- 閭欢7澶╄繃鏈?"
local MAIL_POLL_CD = 30           -- 杞鍐峰嵈绉掓暟

CloudManager._mailOutbox = {}     -- 鏈湴鍙戜欢绠辩紦瀛?"
CloudManager._mailOutboxLoaded = false -- 鏄惁宸蹭粠浜戠鍔犺浇杩囧彂浠剁
CloudManager._mailInbox = {}      -- 鎵弿鍒扮殑鏀朵欢鍒楄〃
CloudManager._mailLastPoll = 0    -- 涓婃杞鏃堕棿
CloudManager._mailLoading = false
CloudManager._mailClaimed = {}    -- 宸查鍙栫殑閭欢ID闆嗗悎 {[mailId]=true}
CloudManager.ADMIN_UIDS = {}      -- 绠＄悊鍛楿ID鍒楄〃, 鐢?main.lua 璁剧疆

--- 浠庝簯绔姞杞藉凡鏈夊彂浠剁锛堥槻姝㈤噸鍚悗瑕嗙洊锛?"
---@param callback? fun(ok:boolean)
function CloudManager.LoadMailOutbox(callback)
    if CloudManager._mailOutboxLoaded then
        if callback then callback(true) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback(false) end
        return
    end
    CloudAPI:BatchGet()
        :Key(KEYS.mail_outbox)
        :Fetch({
            ok = function(values, iscores)
                local outbox = values and values[KEYS.mail_outbox]
                if outbox and type(outbox) == "table" then
                    -- 杩囨护杩囨湡閭欢
                    local now = os.time()
                    local kept = {}
                    for _, m in ipairs(outbox) do
                        if (now - (m.time or 0)) < MAIL_EXPIRE_DAYS * 86400 then
                            kept[#kept + 1] = m
                        end
                    end
                    CloudManager._mailOutbox = kept
                    print("[邮件] 浜戠鍙戜欢绠卞姞杞芥垚鍔? " .. #kept .. " 灏?")
                else
                    CloudManager._mailOutbox = {}
                    print("[邮件] 浜戠鍙戜欢绠变负绌?")
                end
                CloudManager._mailOutboxLoaded = true
                if callback then callback(true) end
            end,
            error = function(_, reason)
                print("[邮件] 浜戠鍙戜欢绠卞姞杞藉け璐? " .. tostring(reason))
                -- 鍔犺浇澶辫触涔熸爣璁帮紝閬垮厤鍙嶅閲嶈瘯闃诲鍙戜俊
                CloudManager._mailOutboxLoaded = true
                if callback then callback(false) end
            end,
        })
end

--- 鍙戦€侀偖浠剁粰鎸囧畾玩家
---@param targetUid number 鐩爣玩家 UID
---@param subject string 鏍囬
---@param body string 姝ｆ枃
---@param rewards? table 闄勪欢濂栧姳 [{type,amount,label}] (浠呯鐞嗗憳鍙彂)
---@param callback? fun(ok:boolean, msg:string)
function CloudManager.SendMail(targetUid, subject, body, rewards, callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback(false, "云端不可用") end
        return
    end

    -- 濡傛灉鍙戜欢绠辨湭浠庝簯绔姞杞借繃锛屽厛鍔犺浇鍐嶅彂閫侊紙闃叉瑕嗙洊鏃ч偖浠讹級
    if not CloudManager._mailOutboxLoaded then
        print("[邮件] 鍙戜欢绠辨湭鍔犺浇锛屽厛浠庝簯绔姞杞?..")
        CloudManager.LoadMailOutbox(function(ok)
            -- 鏃犺鍔犺浇鎴愬姛澶辫触閮界户缁彂閫?"
            CloudManager.SendMail(targetUid, subject, body, rewards, callback)
        end)
        return
    end

    local myUid = CloudAPI.GetUserId()
    local myName = rawget(_G, "playerInfo") and playerInfo.name or ("玩家" .. tostring(myUid))

    -- 鍙湁绠＄悊鍛樺彲浠ュ彂甯﹀鍔辩殑閭欢
    if rewards and #rewards > 0 then
        if not CloudManager.IsAdmin() then
            if callback then callback(false, "仅管理员可发带奖励邮件") end
            return
        end
    end

    local mailId = tostring(myUid) .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    local mailItem = {
        id = mailId,
        to = targetUid,
        from = myUid,
        fromName = myName,
        subject = subject,
        body = body,
        rewards = rewards or {},
        time = os.time(),
    }

    -- 鍔犲叆鏈湴鍙戜欢绠?"
    table.insert(CloudManager._mailOutbox, 1, mailItem)
    -- 瑁佸壀杩囧 / 杩囨湡
    local now = os.time()
    local kept = {}
    for i, m in ipairs(CloudManager._mailOutbox) do
        if i <= MAIL_MAX_OUTBOX and (now - m.time) < MAIL_EXPIRE_DAYS * 86400 then
            kept[#kept + 1] = m
        end
    end
    CloudManager._mailOutbox = kept

    -- 涓婁紶鍒颁簯绔?"
    CloudAPI:BatchSet()
        :SetInt(KEYS.mail_ts, os.time())
        :Set(KEYS.mail_outbox, CloudManager._mailOutbox)
        :Save("发送邮件", {
            ok = function()
                print("[邮件] 发送成功 → " .. tostring(targetUid) .. ": " .. subject)
                if callback then callback(true, "发送成功") end
            end,
            error = function(_, reason)
                print("[邮件] 发送失败 " .. tostring(reason))
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 骞挎挱閭欢 (绠＄悊鍛樺悜鎵€鏈変汉鍙?"
---@param subject string 鏍囬
---@param body string 姝ｆ枃
---@param rewards? table 闄勪欢濂栧姳
---@param callback? fun(ok:boolean, msg:string)
function CloudManager.BroadcastMail(subject, body, rewards, callback)
    if not CloudManager.IsAdmin() then
        if callback then callback(false, "浠呯鐞嗗憳鍙箍鎾?") end
        return
    end
    -- to=0 琛ㄧず骞挎挱缁欐墍鏈変汉
    CloudManager.SendMail(0, subject, body, rewards, callback)
end

--- 杞鏀朵欢绠?(鎵弿鎵€鏈夌帺瀹剁殑 outbox, 杩囨护鍙戠粰鑷繁鐨?"
---@param callback? fun(mails:table)
function CloudManager.PollInbox(callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end
    local now = os.time()
    if now - CloudManager._mailLastPoll < MAIL_POLL_CD and #CloudManager._mailInbox > 0 then
        if callback then callback(CloudManager._mailInbox) end
        return
    end
    if CloudManager._mailLoading then
        if callback then callback(CloudManager._mailInbox) end
        return
    end
    CloudManager._mailLoading = true
    local myUid = CloudAPI.GetUserId()

    CloudAPI:GetRankList(KEYS.mail_ts, 0, 200, {
        ok = function(rankList)
            local inbox = {}
            local expireThreshold = now - MAIL_EXPIRE_DAYS * 86400
            for _, entry in ipairs(rankList) do
                local senderId = _getRankItemUserId(entry)
                local outbox = entry.score and entry.score[KEYS.mail_outbox]
                if outbox and type(outbox) == "table" then
                    for _, m in ipairs(outbox) do
                        -- to==myUid 鎴?to==0(骞挎挱)
                        if (m.to == myUid or m.to == 0) and (m.time or 0) > expireThreshold then
                            -- 骞挎挱閭欢涓嶆樉绀鸿嚜宸卞彂缁欒嚜宸辩殑
                            if not (m.to == 0 and senderId == myUid) then
                                inbox[#inbox + 1] = {
                                    id = m.id,
                                    from = senderId,  -- 濮嬬粓浣跨敤骞冲彴璁よ瘉ID锛屼笉淇′换鑷姤m.from
                                    fromName = m.fromName or ("玩家" .. tostring(senderId)),
                                    subject = m.subject or "",
                                    body = m.body or "",
                                    rewards = m.rewards or {},
                                    time = m.time or 0,
                                    isBroadcast = (m.to == 0),
                                }
                            end
                        end
                    end
                end
            end
            -- 鎸夋椂闂撮檷搴?"
            table.sort(inbox, function(a, b) return a.time > b.time end)
            CloudManager._mailInbox = inbox
            CloudManager._mailLastPoll = now
            CloudManager._mailLoading = false
            print("[邮件] 鏀朵欢绠卞埛鏂? " .. #inbox .. " 灏?")
            if callback then callback(inbox) end
        end,
        error = function(_, reason)
            CloudManager._mailLoading = false
            print("[邮件] 鏀朵欢绠卞埛鏂板け璐? " .. tostring(reason))
            if callback then callback(CloudManager._mailInbox) end
        end,
    }, KEYS.mail_outbox)
end

--- 寮哄埗鍒锋柊鏀朵欢绠?(閲嶇疆鍐峰嵈)
function CloudManager.ForceRefreshInbox(callback)
    CloudManager._mailLastPoll = 0
    CloudManager.PollInbox(callback)
end

--- 鍒ゆ柇褰撳墠玩家鏄惁涓虹鐞嗗憳
---@return boolean
function CloudManager.IsAdmin()
    if not CloudAPI.IsAvailable() then return false end
    local ADMIN_UIDS = CloudManager.ADMIN_UIDS or {}
    local myUid = CloudAPI.GetUserId()
    for _, uid in ipairs(ADMIN_UIDS) do
        if uid == myUid then return true end
    end
    return false
end

--- 鏍囪閭欢宸查鍙?"
---@param mailId string
function CloudManager.ClaimMail(mailId)
    CloudManager._mailClaimed[mailId] = true
end

--- 妫€鏌ラ偖浠舵槸鍚﹀凡棰嗗彇
---@param mailId string
---@return boolean
function CloudManager.IsMailClaimed(mailId)
    return CloudManager._mailClaimed[mailId] == true
end

return CloudManager


