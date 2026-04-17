-- ============================================================================
-- cloud_manager_features.lua - 三国武灵录 (从 cloud_manager.lua 拆分)
-- 功能模块: 聊天、本地IO、更新循环、封禁管理、管理员、邮件
-- ============================================================================
---@diagnostic disable: undefined-global

local CWP = require("network.CloudWriteProxy")

-- 从 core 模块导入常量和共享状态
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

-- ============================================================================
-- 阵营聊天 (云端同步)
-- ============================================================================

local MAX_CHAT_HISTORY = 10   -- 每人在排行榜保留的最近消息数
local CHAT_POLL_INTERVAL = 12 -- 聊天轮询间隔(秒)
CloudManager._chatLastPoll = 0
CloudManager._chatLastSentTs = 0
CloudManager._chatPendingMsgs = {}  -- 待发布的本地消息队列
CloudManager._chatMerged = {}       -- 合并后的全部消息 (按 ts 排序)
CloudManager._chatSeenTs = {}       -- 已见过的最大 ts (per uid)

--- 发送阵营聊天消息 (写入本地队列 + 立即发布到排行榜)
---@param text string 消息内容
---@param senderName string 发送者昵称
function CloudManager.SendFactionChat(text, senderName)
    if CloudManager._factionId == 0 then return false, "未加入阵营" end
    if not rawget(_G, "cl_state") then return false, "服务端未连接" end
    if not text or #text == 0 then return false, "消息为空" end

    local avIdx = (rawget(_G, "playerInfo") and playerInfo.avatarIdx) or 1
    local ts = os.time()
    local msg = {
        text = text,
        name = senderName or "???",
        time = os.date("%H:%M", ts),
        ts = ts,
        uid = GetMyUid(),
        av = avIdx,
    }
    -- 追加到本地队列
    table.insert(CloudManager._chatPendingMsgs, msg)
    -- 也追加到合并列表以便立刻显示
    table.insert(CloudManager._chatMerged, msg)

    -- 标记自己的时间戳已见，防止轮询时重复拉取本条消息
    CloudManager._chatSeenTs[GetMyUid()] = ts

    -- 发布到排行榜 (保留最近 N 条)
    local toPublish = {}
    local start = math.max(1, #CloudManager._chatPendingMsgs - MAX_CHAT_HISTORY + 1)
    for i = start, #CloudManager._chatPendingMsgs do
        local m = CloudManager._chatPendingMsgs[i]
        toPublish[#toPublish + 1] = { text = m.text, name = m.name, time = m.time, ts = m.ts, av = m.av }
    end

    CWP.Write({
        { key = KEYS.camp_chat_ts, value = ts, int = true },
        { key = KEYS.camp_chat, value = toPublish },
    }, "发送阵营聊天")

    CloudManager._chatLastSentTs = ts
    return true
end

--- 生成类型安全的聊天去重 key（避免 int/float tostring 差异导致去重失败）
local function chatMsgKey(uid, ts)
    return string.format("%d_%d", math.floor(tonumber(uid) or 0), math.floor(tonumber(ts) or 0))
end

--- 拉取阵营聊天消息 (从排行榜获取所有成员的最近消息)
---@param callback? fun(messages: table[])
function CloudManager.PollFactionChat(callback)
    if CloudManager._factionId == 0 then
        if callback then callback({}) end
        return
    end
    if not rawget(_G, "cl_state") then
        if callback then callback({}) end
        return
    end

    ClientNet.Request("get_rank_list", {
        key = KEYS.camp_chat_ts, start = 0, count = 100,
    }, function(ok, code, data, msg)
        if not ok or not data or not data.list then
            if callback then callback(CloudManager._chatMerged) end
            return
        end
        local rankList = data.list
        local newMsgs = {}
        for _, item in ipairs(rankList) do
            local chatData = item.score and item.score[KEYS.camp_chat]
            if type(chatData) == "table" then
                local senderUid = item.userId or 0
                local seenTs = CloudManager._chatSeenTs[senderUid] or 0
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
                    CloudManager._chatSeenTs[senderUid] = maxTs
                end
            end
        end

        -- 合并到全局列表 (去重, 使用类型安全的 key)
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

        table.sort(CloudManager._chatMerged, function(a, b) return (a.ts or 0) < (b.ts or 0) end)

        while #CloudManager._chatMerged > 50 do
            table.remove(CloudManager._chatMerged, 1)
        end

        if callback then callback(CloudManager._chatMerged) end
    end)
end

--- 获取当前合并的聊天消息列表 (供UI直接读取)
---@return table[]
function CloudManager.GetFactionChatMessages()
    return CloudManager._chatMerged
end

-- ============================================================================
-- 世界聊天 (全服公共频道, 排行榜存储)
-- ============================================================================
local WORLD_CHAT_MAX_PER_USER = 5     -- 每人在排行榜保留的最近消息数
local WORLD_CHAT_POLL_INTERVAL = 6    -- 世界聊天轮询间隔(秒) - 更实时
local WORLD_CHAT_MAX_MERGED = 100     -- 本地合并列表最大条数

CloudManager._worldChatLastPoll = 0
CloudManager._worldChatPendingMsgs = {}
CloudManager._worldChatMerged = {}
CloudManager._worldChatSeenTs = {}

--- 发送世界聊天消息
---@param text string 消息内容
---@param senderName string 发送者名字
---@return boolean, string?
function CloudManager.SendWorldChat(text, senderName)
    if not rawget(_G, "cl_state") then return false, "服务端未连接" end
    if not text or #text == 0 then return false, "消息为空" end

    local avIdx = (rawget(_G, "playerInfo") and playerInfo.avatarIdx) or 1
    local ts = os.time()
    -- 防止同一秒内重复发送相同内容（移动端键盘回车+按钮可能双触发）
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
        uid = GetMyUid(),
        av = avIdx,
    }
    table.insert(CloudManager._worldChatPendingMsgs, msg)
    table.insert(CloudManager._worldChatMerged, msg)

    -- 标记自己的时间戳已见，防止轮询时重复拉取本条消息
    CloudManager._worldChatSeenTs[GetMyUid()] = ts

    -- 发布到排行榜 (保留最近 N 条)
    local toPublish = {}
    local start = math.max(1, #CloudManager._worldChatPendingMsgs - WORLD_CHAT_MAX_PER_USER + 1)
    for i = start, #CloudManager._worldChatPendingMsgs do
        local m = CloudManager._worldChatPendingMsgs[i]
        toPublish[#toPublish + 1] = { text = m.text, name = m.name, time = m.time, ts = m.ts, av = m.av }
    end

    CWP.Write({
        { key = KEYS.world_chat_ts, value = ts, int = true },
        { key = KEYS.world_chat, value = toPublish },
    }, "发送世界聊天")

    return true
end

--- 拉取世界聊天消息 (从排行榜获取最近30个用户的消息)
---@param callback? fun(messages: table[])
function CloudManager.PollWorldChat(callback)
    if not rawget(_G, "cl_state") then
        if callback then callback({}) end
        return
    end

    ClientNet.Request("get_rank_list", {
        key = KEYS.world_chat_ts, start = 0, count = 30,
    }, function(ok, code, data, msg)
        if not ok or not data or not data.list then
            if callback then callback(CloudManager._worldChatMerged) end
            return
        end
        local rankList = data.list
        local newMsgs = {}
        for _, item in ipairs(rankList) do
            local chatData = item.score and item.score[KEYS.world_chat]
            if type(chatData) == "table" then
                local senderUid = item.userId or 0
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

        -- 合并到全局列表 (去重, 使用类型安全的 key)
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

        table.sort(CloudManager._worldChatMerged, function(a, b) return (a.ts or 0) < (b.ts or 0) end)

        while #CloudManager._worldChatMerged > WORLD_CHAT_MAX_MERGED do
            table.remove(CloudManager._worldChatMerged, 1)
        end

        -- 批量查询 nickname 覆盖 name 字段
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
                        local myUid = GetMyUid()
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
    end)
end

--- 获取当前世界聊天消息列表 (供UI直接读取)
---@return table[]
function CloudManager.GetWorldChatMessages()
    return CloudManager._worldChatMerged
end

-- ============================================================================
-- 内部工具函数
-- ============================================================================

--- 保存本地JSON (多domain格式)
function CloudManager._saveLocalJSON(allData)
    local cjson_m = rawget(_G, "cjson")
    if not cjson_m then return end

    -- 如果没传allData, 重新收集
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

--- 加载本地JSON
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

--- 从多domain数据恢复游戏状态
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
        -- 复用 ApplySaveData 的装备恢复逻辑 (含新旧格式迁移)
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

    -- welfare (复用 ApplySaveData 的恢复逻辑)
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
            print("[CloudManager] 探索状态已恢复")
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
            -- 恢复外交
            if wd.diplomacy then
                wms.diplomacy = wd.diplomacy
            else
                wms.diplomacy = {
                    shu = { relation = 30, treaty = nil },
                    wei = { relation = 20, treaty = nil },
                    qun = { relation = 40, treaty = nil },
                }
            end
            -- 恢复城池数据
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
            -- 恢复兵种选择 (key从string转回number)
            wms.heroTroopChoice = {}
            if wd.heroTroopChoice then
                for k, v in pairs(wd.heroTroopChoice) do
                    local idx = tonumber(k)
                    if idx then wms.heroTroopChoice[idx] = v end
                end
            end
            -- 恢复已学武技
            wms.heroLearnedSkills = {}
            if wd.heroLearnedSkills then
                for k, v in pairs(wd.heroLearnedSkills) do
                    local idx = tonumber(k)
                    if idx then wms.heroLearnedSkills[idx] = v end
                end
            end
            print("[CloudManager] 大地图状态已恢复, 回合=" .. tostring(wms.turn))
        end
    end

    -- 向下兼容: level 与 rankIdx 同步
    playerInfo.level = playerInfo.rankIdx or 1
    if rawget(_G, "CheckPlayerLevelUp") then
        CheckPlayerLevelUp()
    end
end

--- 构建旧格式存档数据 (向下兼容)
function CloudManager._buildLegacyData(allData)
    -- 合并所有domain到一个扁平table (与旧 SaveGameProgress 结构一致)
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

-- ── 社交轮询定时器 ──
local socialPollTimer = 0
local SOCIAL_POLL_INTERVAL = 15  -- 每15秒轮询一次社交状态
local socialPollBusy = false     -- 防止并发轮询

--- 更新重试定时器 + 社交轮询 (在 HandleUpdate 中调用)
function CloudManager.Update(dt)
    if S.retryTimer > 0 then
        S.retryTimer = S.retryTimer - dt
        if S.retryTimer <= 0 and S.retryData then
            print("[CloudManager] 重试云端同步...")
            CloudManager.SaveAll()
            S.retryData = nil
        end
    end

    -- 社交轮询: 好友回复 + 阵营审批结果
    if not rawget(_G, "cl_state") then return end
    socialPollTimer = socialPollTimer + dt
    if socialPollTimer >= SOCIAL_POLL_INTERVAL and not socialPollBusy then
        socialPollTimer = 0
        socialPollBusy = true

        -- 1) 好友回复轮询: 检查我发出的好友请求是否被对方回复
        CloudManager.CheckMyRequestResponses(function(results)
            if results and #results > 0 then
                for _, r in ipairs(results) do
                    if r.accepted then
                        print("[社交轮询] 好友请求被 " .. tostring(r.toUid) .. " 同意, 已互加!")
                        if rawget(_G, "ShowToast") then ShowToast("你与玩家" .. tostring(r.toUid) .. "已成为好友!") end
                        if rawget(_G, "playerInfo") then
                            playerInfo.totalFriends = (playerInfo.totalFriends or 0) + 1
                        end
                    end
                end
                -- 刷新好友界面
                if rawget(_G, "friendsUI") then
                    friendsUI.loaded = false; friendsUI.loading = false
                end
            end

            -- 2) 阵营审批轮询: 检查我的入营申请是否被批准
            CloudManager.CheckMyFactionApplication(function(result)
                socialPollBusy = false
                if result == "approved" then
                    print("[社交轮询] 入营申请已通过!")
                    if rawget(_G, "ShowToast") then ShowToast("你的入营申请已通过!") end
                    if rawget(_G, "playerInfo") then playerInfo.factionJoined = 1 end
                    if rawget(_G, "factionUI") then
                        factionUI.loaded = false; factionUI.loading = false
                        factionUI.applyStatus = nil
                    end
                elseif result == "rejected" then
                    print("[社交轮询] 入营申请被拒绝")
                    if rawget(_G, "ShowToast") then ShowToast("你的入营申请被拒绝") end
                    if rawget(_G, "factionUI") then factionUI.applyStatus = nil end
                end
            end)
        end)
    end

    -- 阵营聊天轮询
    if CloudManager._factionId ~= 0 then
        CloudManager._chatLastPoll = (CloudManager._chatLastPoll or 0) + dt
        if CloudManager._chatLastPoll >= CHAT_POLL_INTERVAL then
            CloudManager._chatLastPoll = 0
            CloudManager.PollFactionChat()
        end
    end

    -- 世界聊天轮询 (始终运行)
    CloudManager._worldChatLastPoll = (CloudManager._worldChatLastPoll or 0) + dt
    if CloudManager._worldChatLastPoll >= WORLD_CHAT_POLL_INTERVAL then
        CloudManager._worldChatLastPoll = 0
        CloudManager.PollWorldChat()
    end
end

-- ============================================================================
-- 便捷访问
-- ============================================================================

--- 获取所有domain key名
function CloudManager.GetDomainKeys()
    return DOMAINS
end

--- 获取前缀
function CloudManager.GetPrefix()
    return PREFIX
end

--- 获取上次同步时间
function CloudManager.GetLastSyncTime()
    return S.lastSyncTime
end

--- 云端数据是否正在加载中 (LoadAll 异步期间为 true)
--- 用于 UI 层阻断玩家操作, 防止在云数据到达前产生脏数据
---@return boolean
function CloudManager.IsCloudLoading()
    return S.cloudLoadPending
end

-- ============================================================================
-- 封禁系统
-- ============================================================================

--- 封禁等级常量 (供外部使用)
CloudManager.BAN_LEVEL_NONE   = BAN_LEVEL_NONE
CloudManager.BAN_LEVEL_SOCIAL = BAN_LEVEL_SOCIAL
CloudManager.BAN_LEVEL_CORE   = BAN_LEVEL_CORE
CloudManager.BAN_LEVEL_FULL   = BAN_LEVEL_FULL

--- 检查当前玩家是否被封禁 (启动时调用)
--- 原理: 扫描 ban_ts 排行榜, 找到管理员发布的封禁名单, 检查自己是否在列表中
---@param callback fun(level: number, reason: string)
function CloudManager.CheckBanStatus(callback)
    if not rawget(_G, "cl_state") then
        S.banChecked = true
        if callback then callback(BAN_LEVEL_NONE, "") end
        return
    end

    local myUid = GetMyUid()
    local myUidStr = tostring(myUid)

    -- 扫描 ban_ts 排行榜
    ClientNet.Request("get_rank_list", {
        key = KEYS.ban_ts, start = 0, count = 50,
    }, function(ok, code, data, msg)
        if not ok or not data or not data.list then
            print("[封禁] 检查封禁状态失败: " .. tostring(msg))
            S.banChecked = true
            if callback then callback(BAN_LEVEL_NONE, "") end
            return
        end
        local rankList = data.list
        local foundLevel = BAN_LEVEL_NONE
        local foundReason = ""

        for _, item in ipairs(rankList) do
            local banData = item.score and item.score[KEYS.ban_data]
            if type(banData) == "table" then
                local bans = banData.bans
                if type(bans) == "table" and bans[myUidStr] then
                    local entry = bans[myUidStr]
                    local untilTime = entry["until"] or 0
                    if untilTime == 0 or untilTime > os.time() then
                        local lvl = entry.level or BAN_LEVEL_FULL
                        if lvl > foundLevel then
                            foundLevel = lvl
                            foundReason = entry.reason or "违规操作"
                        end
                    end
                end
            end
        end

        -- 加载隐藏名单 (管理员用)
        if not CloudManager._hiddenPlayers then CloudManager._hiddenPlayers = {} end
        for _, item2 in ipairs(rankList) do
            local bd2 = item2.score and item2.score[KEYS.ban_data]
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
            print("[封禁] 检测到封禁: 等级=" .. foundLevel .. " 原因=" .. foundReason)
        else
            print("[封禁] 未被封禁")
        end

        if callback then callback(foundLevel, foundReason) end
    end)
end

--- 获取当前封禁等级
---@return number 0=无, 1=社交, 2=核心, 3=全封
function CloudManager.GetBanLevel()
    return S.banLevel
end

--- 获取封禁原因
---@return string
function CloudManager.GetBanReason()
    return S.banReason
end

--- 是否已完成封禁检查
---@return boolean
function CloudManager.IsBanChecked()
    return S.banChecked
end

--- 检查是否被封禁到指定等级
---@param level number 要检查的等级
---@return boolean
function CloudManager.IsBanned(level)
    return S.banLevel >= (level or BAN_LEVEL_SOCIAL)
end

--- 获取封禁等级的中文描述
---@param level number
---@return string
function CloudManager.GetBanLevelName(level)
    if level >= BAN_LEVEL_FULL then return "全面封禁"
    elseif level >= BAN_LEVEL_CORE then return "核心功能封禁"
    elseif level >= BAN_LEVEL_SOCIAL then return "社交封禁"
    else return "无" end
end

--- 管理员: 获取当前封禁名单 (从排行榜读取自己发布的)
---@param callback fun(bans: table|nil, err: string|nil)
function CloudManager.AdminGetBanList(callback)
    if not rawget(_G, "cl_state") then
        if callback then callback(nil, "服务端未连接") end
        return
    end
    ClientNet.Request("cloud_get", {
        key = KEYS.ban_data,
    }, function(ok, code, data, msg)
        if not ok or not data then
            if callback then callback(nil, tostring(msg)) end
            return
        end
        local val = data.value
        if type(val) == "table" and type(val.bans) == "table" then
            if callback then callback(val.bans, nil) end
        else
            if callback then callback({}, nil) end
        end
    end)
end

--- 管理员: 发布封禁名单 (覆盖式写入)
--- bans 格式: { ["uid_str"] = { level=1-3, reason="...", until=0 }, ... }
---@param bans table 封禁名单
---@param callback fun(ok: boolean, err: string|nil)
function CloudManager.AdminPublishBanList(bans, callback)
    if not rawget(_G, "cl_state") then
        if callback then callback(false, "服务端未连接") end
        return
    end
    local ts = os.time()
    CWP.Write({
        { key = KEYS.ban_ts, value = ts, int = true },
        { key = KEYS.ban_data, value = { bans = bans, updated = ts } },
    }, "admin_ban_update", {
        ok = function()
            print("[管理员] 封禁名单已发布, 条目数: " .. CloudManager._tableCount(bans))
            if callback then callback(true, nil) end
        end,
        error = function(_, reason)
            if callback then callback(false, tostring(reason)) end
        end,
    })
end

--- 管理员: 将排行榜分数设为极小值来隐藏 (SetInt 设为 -999999)
---@param targetUid number 目标玩家UID
---@param callback fun(ok: boolean, msg: string)
function CloudManager.AdminHidePlayerRank(targetUid, callback)
    -- 注意: clientCloud 只能操作自己的数据, 无法直接删除他人排行榜
    -- 隐藏策略: 将该 UID 加入本地隐藏列表, 在排行榜渲染时过滤
    if not CloudManager._hiddenPlayers then
        CloudManager._hiddenPlayers = {}
    end
    CloudManager._hiddenPlayers[tostring(targetUid)] = true
    -- 持久化到 ban_data 中
    CloudManager.AdminGetBanList(function(bans, err)
        if not bans then bans = {} end
        local uidStr = tostring(targetUid)
        if not bans[uidStr] then
            bans[uidStr] = { level = 0, reason = "排行榜隐藏", ["until"] = 0 }
        end
        bans[uidStr].rankHidden = true
        CloudManager.AdminPublishBanList(bans, function(ok)
            if callback then callback(ok, ok and "已隐藏" or "操作失败") end
        end)
    end)
end

--- 管理员: 恢复玩家排行榜显示
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
            -- 如果这条记录只有 rankHidden, level=0, 那就删掉整条
            if (bans[uidStr].level or 0) == 0 then
                bans[uidStr] = nil
            end
        end
        CloudManager.AdminPublishBanList(bans, function(ok)
            if callback then callback(ok, ok and "已恢复显示" or "操作失败") end
        end)
    end)
end

--- 检查某个玩家是否被隐藏排行榜
---@param uid number|string
---@return boolean
function CloudManager.IsPlayerRankHidden(uid)
    if not CloudManager._hiddenPlayers then return false end
    return CloudManager._hiddenPlayers[tostring(uid)] == true
end

--- 管理员: 获取封禁名单摘要（供 UI 列表展示）
--- 返回两个数组: tempBans(暂时封禁), permBans(永久封禁/已删除)
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
        -- 按 UID 排序
        table.sort(tempList, function(a, b) return a.uid < b.uid end)
        table.sort(permList, function(a, b) return a.uid < b.uid end)
        if callback then callback(tempList, permList, nil) end
    end)
end

--- 管理员: 永久封禁（标记为已删除，全面封禁 + 排行榜隐藏）
---@param targetUid number|string 目标UID
---@param callback fun(ok: boolean, msg: string)
function CloudManager.AdminPermanentBan(targetUid, callback)
    local uidStr = tostring(targetUid)
    -- 加入隐藏列表
    if not CloudManager._hiddenPlayers then CloudManager._hiddenPlayers = {} end
    CloudManager._hiddenPlayers[uidStr] = true

    CloudManager.AdminGetBanList(function(bans, err)
        if not bans then bans = {} end
        bans[uidStr] = bans[uidStr] or {}
        bans[uidStr].level = 3          -- BAN_LEVEL_FULL
        bans[uidStr].reason = "永久封禁(数据已删除)"
        bans[uidStr]["until"] = 0       -- 永久
        bans[uidStr].rankHidden = true  -- 隐藏排行榜
        bans[uidStr].permanent = true   -- 标记为永久封禁
        CloudManager.AdminPublishBanList(bans, function(ok)
            if callback then callback(ok, ok and "已永久封禁" or "操作失败") end
        end)
    end)
end

--- 管理员: 将暂时封禁恢复（完全解禁，包括排行榜）
---@param targetUid number|string
---@param callback fun(ok: boolean, msg: string)
function CloudManager.AdminFullUnban(targetUid, callback)
    local uidStr = tostring(targetUid)
    -- 移出隐藏列表
    if CloudManager._hiddenPlayers then
        CloudManager._hiddenPlayers[uidStr] = nil
    end

    CloudManager.AdminGetBanList(function(bans, err)
        if not bans then bans = {} end
        bans[uidStr] = nil  -- 完全移除
        CloudManager.AdminPublishBanList(bans, function(ok)
            if callback then callback(ok, ok and "已完全解禁" or "操作失败") end
        end)
    end)
end

--- 内部工具: 计算table元素数
function CloudManager._tableCount(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- ============================================================================
-- 频率限制
-- ============================================================================

--- 检查操作冷却 (通过返回true/false表示是否可执行)
--- 如果可执行, 同时更新时间戳
---@param action string 操作名称
---@param cooldownSeconds number 冷却秒数
---@return boolean 是否允许执行
function CloudManager._checkCooldown(action, cooldownSeconds)
    local now = os.time()
    local lastTime = S.cooldownTimestamps[action] or 0
    if (now - lastTime) < cooldownSeconds then
        return false
    end
    S.cooldownTimestamps[action] = now
    return true
end

--- 获取操作剩余冷却时间
---@param action string
---@param cooldownSeconds number
---@return number 剩余秒数 (0=可执行)
function CloudManager.GetCooldownRemaining(action, cooldownSeconds)
    local now = os.time()
    local lastTime = S.cooldownTimestamps[action] or 0
    local elapsed = now - lastTime
    if elapsed >= cooldownSeconds then return 0 end
    return cooldownSeconds - elapsed
end

-- ============================================================================
-- 负值防护
-- ============================================================================

--- 清理关键资源的负值 (防止作弊/数据异常)
function CloudManager._sanitizeResources()
    if not rawget(_G, "playerInfo") then return end
    local pi = playerInfo
    -- 虎符 (jade)
    if (pi.jade or 0) < 0 then
        print("[安全] 虎符为负值(" .. tostring(pi.jade) .. "), 强制归零")
        pi.jade = 0
    end
    -- 灵石 (lingshi)
    if (pi.lingshi or 0) < 0 then
        print("[安全] 灵石为负值(" .. tostring(pi.lingshi) .. "), 强制归零")
        pi.lingshi = 0
    end
    -- 经验 (exp)
    if (pi.exp or 0) < 0 then
        print("[安全] 经验为负值(" .. tostring(pi.exp) .. "), 强制归零")
        pi.exp = 0
    end
    -- 等级 (rankIdx)
    if (pi.rankIdx or 1) < 1 then
        print("[安全] 等级为负值(" .. tostring(pi.rankIdx) .. "), 强制归1")
        pi.rankIdx = 1
        pi.level = 1
    end
    -- 深渊门票
    if (pi.abyssTickets or 0) < 0 then
        print("[安全] 深渊门票为负值, 强制归零")
        pi.abyssTickets = 0
    end
end

-- ============================================================================
-- 存档哈希校验
-- ============================================================================

--- 计算存档哈希 (简单混淆校验, 非加密级别)
--- 原理: 提取关键字段 → 数值求和 → 混合uid和secret → 取模得到校验值
---@param allData table 所有domain数据 (或domain名→data的映射)
---@return number hash值
function CloudManager._computeSaveHash(allData)
    local uid = GetMyUid()

    local sum = 0

    -- 从 core 提取关键字段
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

    -- 从 progress 提取
    local progData = allData.progress or allData[DOMAINS.progress]
    if progData then
        sum = sum + (progData.stageMaxUnlocked or 0) * 53
        sum = sum + (progData.towerHighestFloor or 0) * 41
        sum = sum + (progData.rankedHighestScore or 0) * 3
    end

    -- 混合 uid 和 secret
    local mixed = (uid * HASH_SEED + sum) ~ HASH_SECRET
    -- 确保正整数 (Lua 5.4 整数可能为负)
    if mixed < 0 then mixed = -mixed end
    return mixed % 999999937  -- 大素数取模
end

--- 检查存档哈希是否不匹配
---@return boolean true=哈希不匹配(可能被篡改)
function CloudManager.IsHashMismatch()
    return CloudManager._hashMismatch == true
end

-- ============================================================================
-- 阵营职位查询 (导出供外部使用)
-- ============================================================================

--- 导出职位定义表 (供UI渲染用)
CloudManager.FACTION_ROLES = FACTION_ROLES

--- 获取指定角色的中文名
---@param role string
---@return string
function CloudManager.GetRoleName(role)
    return _getRoleName(role)
end

--- 获取指定角色的等级
---@param role string
---@return number
function CloudManager.GetRoleLevel(role)
    return _getRoleLevel(role)
end

--- 获取所有可分配职位列表 (不含 leader, 供UI下拉框用)
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

--- 获取阵营成员的职位信息 (带中文名)
---@param userId number
---@return string role, string roleName
function CloudManager.GetMemberRole(userId)
    local meta = CloudManager._factionMeta
    if not meta or not meta.roles then
        return "member", "成员"
    end
    local role = meta.roles[tostring(userId)] or "member"
    return role, _getRoleName(role)
end

--- 获取职位等级数值 (数字越大权限越高, leader=6, member=0)
function CloudManager.GetRoleLevel(role)
    return _getRoleLevel(role)
end

-- ============================================================================
-- 邮件系统 (公共信箱模式: 发件人写 outbox, 收件人轮询扫描)
-- ============================================================================

local MAIL_MAX_OUTBOX = 20         -- 每人发件箱最多保留20封
local MAIL_EXPIRE_DAYS = 7        -- 邮件7天过期
local MAIL_POLL_CD = 30           -- 轮询冷却秒数

CloudManager._mailOutbox = {}     -- 本地发件箱缓存
CloudManager._mailOutboxLoaded = false -- 是否已从云端加载过发件箱
CloudManager._mailInbox = {}      -- 扫描到的收件列表
CloudManager._mailLastPoll = 0    -- 上次轮询时间
CloudManager._mailLoading = false
CloudManager._mailClaimed = {}    -- 已领取的邮件ID集合 {[mailId]=true}
CloudManager.ADMIN_UIDS = {}      -- 管理员UID列表, 由 main.lua 设置

--- 从云端加载已有发件箱（防止重启后覆盖）
---@param callback? fun(ok:boolean)
function CloudManager.LoadMailOutbox(callback)
    if CloudManager._mailOutboxLoaded then
        if callback then callback(true) end
        return
    end
    if not rawget(_G, "cl_state") then
        if callback then callback(false) end
        return
    end
    ClientNet.Request("cloud_batch_get", {
        keys = { KEYS.mail_outbox },
    }, function(ok, code, data, msg)
        if not ok or not data then
            print("[邮件] 云端发件箱加载失败: " .. tostring(msg))
            CloudManager._mailOutboxLoaded = true
            if callback then callback(false) end
            return
        end
        local values = data.scores or {}
        local outbox = values[KEYS.mail_outbox]
        if outbox and type(outbox) == "table" then
            local now = os.time()
            local kept = {}
            for _, m in ipairs(outbox) do
                if (now - (m.time or 0)) < MAIL_EXPIRE_DAYS * 86400 then
                    kept[#kept + 1] = m
                end
            end
            CloudManager._mailOutbox = kept
            print("[邮件] 云端发件箱加载成功: " .. #kept .. " 封")
        else
            CloudManager._mailOutbox = {}
            print("[邮件] 云端发件箱为空")
        end
        CloudManager._mailOutboxLoaded = true
        if callback then callback(true) end
    end)
end

--- 发送邮件给指定玩家
---@param targetUid number 目标玩家 UID
---@param subject string 标题
---@param body string 正文
---@param rewards? table 附件奖励 [{type,amount,label}] (仅管理员可发)
---@param callback? fun(ok:boolean, msg:string)
function CloudManager.SendMail(targetUid, subject, body, rewards, callback)
    if not rawget(_G, "cl_state") then
        if callback then callback(false, "服务端未连接") end
        return
    end

    -- 如果发件箱未从云端加载过，先加载再发送（防止覆盖旧邮件）
    if not CloudManager._mailOutboxLoaded then
        print("[邮件] 发件箱未加载，先从云端加载...")
        CloudManager.LoadMailOutbox(function(ok)
            -- 无论加载成功失败都继续发送
            CloudManager.SendMail(targetUid, subject, body, rewards, callback)
        end)
        return
    end

    local myUid = GetMyUid()
    local myName = rawget(_G, "playerInfo") and playerInfo.name or ("玩家" .. tostring(myUid))

    -- 只有管理员可以发带奖励的邮件
    if rewards and #rewards > 0 then
        if not CloudManager.IsAdmin() then
            if callback then callback(false, "只有管理员可以发送奖励邮件") end
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

    -- 加入本地发件箱
    table.insert(CloudManager._mailOutbox, 1, mailItem)
    -- 裁剪过多 / 过期
    local now = os.time()
    local kept = {}
    for i, m in ipairs(CloudManager._mailOutbox) do
        if i <= MAIL_MAX_OUTBOX and (now - m.time) < MAIL_EXPIRE_DAYS * 86400 then
            kept[#kept + 1] = m
        end
    end
    CloudManager._mailOutbox = kept

    -- 上传到云端
    CWP.Write({
        { key = KEYS.mail_ts, value = os.time(), int = true },
        { key = KEYS.mail_outbox, value = CloudManager._mailOutbox },
    }, "发送邮件", {
        ok = function()
            print("[邮件] 发送成功 → " .. tostring(targetUid) .. ": " .. subject)
            if callback then callback(true, "发送成功") end
        end,
        error = function(_, reason)
            print("[邮件] 发送失败: " .. tostring(reason))
            if callback then callback(false, tostring(reason)) end
        end,
    })
end

--- 广播邮件 (管理员向所有人发)
---@param subject string 标题
---@param body string 正文
---@param rewards? table 附件奖励
---@param callback? fun(ok:boolean, msg:string)
function CloudManager.BroadcastMail(subject, body, rewards, callback)
    if not CloudManager.IsAdmin() then
        if callback then callback(false, "仅管理员可广播") end
        return
    end
    -- to=0 表示广播给所有人
    CloudManager.SendMail(0, subject, body, rewards, callback)
end

--- 轮询收件箱 (扫描所有玩家的 outbox, 过滤发给自己的)
---@param callback? fun(mails:table)
function CloudManager.PollInbox(callback)
    if not rawget(_G, "cl_state") then
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
    local myUid = GetMyUid()

    ClientNet.Request("get_rank_list", {
        key = KEYS.mail_ts, start = 0, count = 200,
    }, function(ok, code, data, msg)
        if not ok or not data or not data.list then
            CloudManager._mailLoading = false
            print("[邮件] 收件箱刷新失败: " .. tostring(msg))
            if callback then callback(CloudManager._mailInbox) end
            return
        end
        local rankList = data.list
        local inbox = {}
        local expireThreshold = now - MAIL_EXPIRE_DAYS * 86400
        for _, entry in ipairs(rankList) do
            local senderId = entry.userId
            local outbox = entry.score and entry.score[KEYS.mail_outbox]
            if outbox and type(outbox) == "table" then
                for _, m in ipairs(outbox) do
                    if (m.to == myUid or m.to == 0) and (m.time or 0) > expireThreshold then
                        if not (m.to == 0 and senderId == myUid) then
                            inbox[#inbox + 1] = {
                                id = m.id,
                                from = senderId,
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
        table.sort(inbox, function(a, b) return a.time > b.time end)
        CloudManager._mailInbox = inbox
        CloudManager._mailLastPoll = now
        CloudManager._mailLoading = false
        print("[邮件] 收件箱刷新: " .. #inbox .. " 封")
        if callback then callback(inbox) end
    end)
end

--- 强制刷新收件箱 (重置冷却)
function CloudManager.ForceRefreshInbox(callback)
    CloudManager._mailLastPoll = 0
    CloudManager.PollInbox(callback)
end

--- 判断当前玩家是否为管理员
---@return boolean
function CloudManager.IsAdmin()
    if not rawget(_G, "cl_state") then return false end
    local ADMIN_UIDS = CloudManager.ADMIN_UIDS or {}
    local myUid = GetMyUid()
    for _, uid in ipairs(ADMIN_UIDS) do
        if uid == myUid then return true end
    end
    return false
end

--- 标记邮件已领取
---@param mailId string
function CloudManager.ClaimMail(mailId)
    CloudManager._mailClaimed[mailId] = true
end

--- 检查邮件是否已领取
---@param mailId string
---@return boolean
function CloudManager.IsMailClaimed(mailId)
    return CloudManager._mailClaimed[mailId] == true
end

return CloudManager
