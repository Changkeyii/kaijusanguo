-- ============================================================================
-- systems/save_system.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 设置存取
-- ============================================================================
function SaveSettings()
    local cjson_m = rawget(_G, "cjson") ---@type table
    local data = cjson_m.encode(gameSettings)
    local file = File(FILE_SETTINGS, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(data)
        file:Close()
    end
end


function LoadSettings()
    if not fileSystem:FileExists(FILE_SETTINGS) then return end
    local cjson_m = rawget(_G, "cjson") ---@type table
    local file = File(FILE_SETTINGS, FILE_READ)
    if file:IsOpen() then
        local ok, data = pcall(cjson_m.decode, file:ReadString())
        file:Close()
        if ok and data then
            gameSettings.musicVolume = data.musicVolume or 0.6
            gameSettings.sfxVolume = data.sfxVolume or 0.8
            gameSettings.defaultAutoMarch = data.defaultAutoMarch or false
            gameSettings.btnOffsetX = data.btnOffsetX or 0
            gameSettings.btnOffsetY = data.btnOffsetY or 0
            gameSettings.btnScale = data.btnScale or 1.0
            gameSettings.rightBtnOffsetX = data.rightBtnOffsetX or 0
            gameSettings.rightBtnOffsetY = data.rightBtnOffsetY or 0
            gameSettings.infoPanelOffsetX = data.infoPanelOffsetX or 0
            gameSettings.infoPanelOffsetY = data.infoPanelOffsetY or 0
            gameSettings.hudOffsetX = data.hudOffsetX or 0
            gameSettings.hudOffsetY = data.hudOffsetY or 0
            -- 兼容旧存档字体key: fangzheng→wenkai, default→xingshu, kai→kuaile
            local savedFont = data.fontStyle or "misans"
            local fontKeyMap = { fangzheng = "wenkai", default = "xingshu", kai = "kuaile" }
            gameSettings.fontStyle = fontKeyMap[savedFont] or savedFont
            gameSettings.defaultBattlefield = data.defaultBattlefield or 1
            if data.tutorialCompleted then gameSettings.tutorialCompleted = true end
            if data.tutorialRewardClaimed then gameSettings.tutorialRewardClaimed = true end
            -- 每日免广告卡
            gameSettings.dailyAdCount = data.dailyAdCount or 0
            gameSettings.dailyAdDate = data.dailyAdDate or ""
            -- 每日广告总上限
            gameSettings.dailyTotalAdCount = data.dailyTotalAdCount or 0
            gameSettings.dailyTotalAdDate = data.dailyTotalAdDate or ""
            -- 预编队
            if type(data.formation) == "table" then
                gameSettings.formation = data.formation
            end
        end
    end
    -- 应用音量
    if audioState.bgmSource then audioState.bgmSource.gain = gameSettings.musicVolume end

    -- 跨日重置每日广告计数
    local today = os.date("%Y-%m-%d")
    if gameSettings.dailyAdDate ~= today then
        gameSettings.dailyAdCount = 0
        gameSettings.dailyAdDate = today
    end
    -- 跨日重置每日广告总次数上限
    if gameSettings.dailyTotalAdDate ~= today then
        gameSettings.dailyTotalAdCount = 0
        gameSettings.dailyTotalAdDate = today
    end
end


-- ============================================================================
-- 游戏进度存档/读档
-- ============================================================================
function SaveGameProgress()
    -- 委托给 CloudManager 多domain保存 (本地JSON + 云端BatchSet)
    local CloudMgr = rawget(_G, 'CloudManager')
    if CloudMgr then
        CloudMgr.SaveAll()
        return
    end

    -- 降级: CloudManager 未加载时，使用旧逻辑
    local cjson_m = rawget(_G, "cjson") ---@type table
    if not cjson_m then return end
    local data = {
        savedAt = os.time(),
        playerInfo = {
            name = playerInfo.name, level = playerInfo.level, exp = playerInfo.exp,
            rankIdx = playerInfo.rankIdx, jade = playerInfo.jade, avatarIdx = playerInfo.avatarIdx,
            profileSet = playerInfo.profileSet, abyssTickets = playerInfo.abyssTickets,
            lingshi = playerInfo.lingshi, totalBattles = playerInfo.totalBattles,
            totalWins = playerInfo.totalWins, totalGachas = playerInfo.totalGachas,
            totalEquips = playerInfo.totalEquips, totalDecompose = playerInfo.totalDecompose,
            totalEnhance = playerInfo.totalEnhance,
            totalFriends = playerInfo.totalFriends, totalFriendReqs = playerInfo.totalFriendReqs,
            totalFactionChat = playerInfo.totalFactionChat, factionJoined = playerInfo.factionJoined,
            totalFactionCreated = playerInfo.totalFactionCreated, totalRankedBattles = playerInfo.totalRankedBattles,
            totalRankedWins = playerInfo.totalRankedWins, totalExplores = playerInfo.totalExplores,
            tradeData = playerInfo.tradeData,
            tradeProcessed = playerInfo.tradeProcessed,
        },
    }
    local ok, json = pcall(cjson_m.encode, data)
    if ok then
        local file = File(FILE_SAVEGAME, FILE_WRITE)
        if file:IsOpen() then file:WriteString(json); file:Close() end
    end
end


-- 同步玩家头像/装备数据到探索模块
function SyncPlayerDataToExploration()
    local tierNames, tierColors = {}, {}
    for i, t in ipairs(EQUIP_TIERS) do
        tierNames[i] = t.name
        tierColors[i] = t.color
    end
    local setNames, pieceNames = {}, {}
    for i, s in ipairs(EQUIPMENT_SETS) do
        setNames[i] = s.name
        pieceNames[i] = {}
        for j, p in ipairs(s.pieces) do pieceNames[i][j] = p.name end
    end
    if not rawget(_G, "Exploration") then return end -- 已移除探索系统
    --[=[ Exploration removed
    Exploration.SetPlayerData({
        avatarSheet = IMG.avatarSheet,
        avatarIdx = playerInfo.avatarIdx,
        avatarData = AVATAR_DATA,
        avatarCols = AVATAR_COLS,
        avatarRows = AVATAR_ROWS,
        avatarImgW = 858,
        avatarImgH = 1280,
        equipSheet = IMG.equipmentSheet,
        equipCols = EQUIP_SHEET_COLS,
        equipRows = EQUIP_SHEET_ROWS,
        equipTierNames = tierNames,
        equipTierColors = tierColors,
        equipSetNames = setNames,
        equipSlotNames = EQUIP_SLOT_NAMES,
        equipPieceNames = pieceNames,
    })
    --]=]
end


-- 从存档数据恢复游戏状态（本地/云端共用）
function ApplySaveData(data)
    if not data then return end
    -- playerInfo
    if data.playerInfo then
        for k, v in pairs(data.playerInfo) do playerInfo[k] = v end
    end
    -- Heroes
    if data.playerHeroes then
        -- 清空已有英雄数据再恢复，避免多次 ApplySaveData 调用时新旧数据混合
        for k in pairs(playerHeroes) do playerHeroes[k] = nil end
        for k, v in pairs(data.playerHeroes) do
            local idx = tonumber(k) or k
            if type(v) == "table" then
                -- 防御性校验：确保 owned 和 constellation 字段存在且类型正确
                if v.owned == nil then v.owned = true end
                if v.constellation == nil then v.constellation = 0 end
                v.constellation = tonumber(v.constellation) or 0
                playerHeroes[idx] = v
            end
        end
        print("[存档] playerHeroes 已加载, 共 " .. tostring(#playerHeroes > 0 and #playerHeroes or (function() local n=0; for _ in pairs(playerHeroes) do n=n+1 end; return n end)()) .. " 个英雄")
    end
    -- Equipment (含旧存档迁移)
    if data.playerEquipment then
        local savedOwned = data.playerEquipment.owned
        local savedEquipped = data.playerEquipment.equipped
        local savedNextUid = data.playerEquipment.nextUid
        -- 判断是否为新格式: 新格式owned是数组(第一个元素有uid字段)
        local isNewFormat = false
        if savedOwned and #savedOwned > 0 and type(savedOwned[1]) == "table" and savedOwned[1].uid then
            isNewFormat = true
        end
        if isNewFormat then
            -- 新格式: 直接加载
            playerEquipment.owned = savedOwned
            playerEquipment.nextUid = savedNextUid or 1
            if savedEquipped then
                for k, v in pairs(savedEquipped) do
                    playerEquipment.equipped[tonumber(k) or k] = v
                end
            end
            -- 确保nextUid大于所有已有uid + 迁移旧equipLevel为level
            for _, item in ipairs(playerEquipment.owned) do
                if item.uid >= playerEquipment.nextUid then
                    playerEquipment.nextUid = item.uid + 1
                end
                -- 迁移: 旧存档没有level字段时，给一个随机等级
                if not item.level then
                    item.level = RollEquipLevel(item.tier)
                end
                item.equipLevel = nil  -- 清理旧字段
            end
        else
            -- 旧格式迁移: owned是map (key→true/number/{enhanceLv=N})
            playerEquipment.owned = {}
            playerEquipment.nextUid = 1
            if savedOwned then
                local savedEnhance = data.playerEquipment.savedEnhance or {}
                for key, val in pairs(savedOwned) do
                    local s, p, t = key:match("^(%d+)_(%d+)_(%d+)$")
                    if s then
                        s, p, t = tonumber(s), tonumber(p), tonumber(t)
                        local enhLv = 0
                        -- 旧格式强化等级来源: owned[key]={enhanceLv=N} 或 savedEnhance[key]
                        if type(val) == "table" and val.enhanceLv then
                            enhLv = val.enhanceLv
                        elseif savedEnhance[key] then
                            enhLv = savedEnhance[key]
                        end
                        -- 旧格式计数: true→1, number→N, table→1
                        local count = 1
                        if type(val) == "number" then count = math.max(1, math.floor(val)) end
                        for _ = 1, count do
                            local item = CreateEquipItem(s, p, t, math.random(20, 80))
                            item.enhanceLv = enhLv
                            enhLv = 0 -- 只有第一件继承强化等级
                        end
                    end
                end
            end
            -- 迁移equipped: 旧格式是 {setIdx=n, tier=t, enhanceLv=0}
            if savedEquipped then
                for k, v in pairs(savedEquipped) do
                    local slotIdx = tonumber(k) or k
                    if type(v) == "table" and v.setIdx then
                        -- 查找匹配的owned兵甲并绑定uid
                        local found = false
                        for _, item in ipairs(playerEquipment.owned) do
                            if item.setIdx == v.setIdx and item.slotIdx == slotIdx and item.tier == (v.tier or 1) then
                                item.enhanceLv = v.enhanceLv or 0
                                playerEquipment.equipped[slotIdx] = item.uid
                                found = true
                                break
                            end
                        end
                        if not found then
                            -- 没找到对应owned, 创建一件
                            local newItem = CreateEquipItem(v.setIdx, slotIdx, v.tier or 1, math.random(20, 80))
                            newItem.enhanceLv = v.enhanceLv or 0
                            playerEquipment.equipped[slotIdx] = newItem.uid
                        end
                    elseif type(v) == "number" then
                        -- 新格式的uid, 直接用
                        playerEquipment.equipped[slotIdx] = v
                    end
                end
            end
        end
        -- 恢复仓库解锁格子数（unlockedSlots = 额外格子数，总格子 = BASE + extra）
        if data.playerEquipment.unlockedSlots then
            playerEquipment.unlockedSlots = data.playerEquipment.unlockedSlots
        else
            playerEquipment.unlockedSlots = 0
        end
        -- 老玩家兼容：自动扩容到足够容纳已有兵甲
        local ownedCount = #playerEquipment.owned
        local totalSlots = BASE_EQUIP_SLOTS + playerEquipment.unlockedSlots
        if ownedCount > totalSlots then
            local extraNeeded = math.ceil((ownedCount - BASE_EQUIP_SLOTS) / UNLOCK_PER_AD_SLOTS) * UNLOCK_PER_AD_SLOTS
            playerEquipment.unlockedSlots = math.max(playerEquipment.unlockedSlots, extraNeeded)
        end
    end
    if data.playerEquippedSkills then playerEquippedSkills = data.playerEquippedSkills end
    if data.unlockedSkills then
        for _, idx in ipairs(data.unlockedSkills) do
            if SKILL_DEFS[idx] then SKILL_DEFS[idx].unlocked = true end
        end
    end
    if data.skillFragments then
        for k, v in pairs(data.skillFragments) do skillFragments[tonumber(k) or k] = v end
    end
    if data.skillLayers then
        for k, v in pairs(data.skillLayers) do skillLayers[tonumber(k) or k] = v end
    end
    -- 向下兼容: 已解锁但无层数数据的武技默认1层
    for idx = 1, #SKILL_DEFS do
        if SKILL_DEFS[idx].unlocked and not skillLayers[idx] then
            skillLayers[idx] = 1
        end
    end
    if data.heroFragments then
        for k, v in pairs(data.heroFragments) do heroFragments[tonumber(k) or k] = v end
    end
    if data.stageMaxUnlocked then stageState.maxUnlocked = data.stageMaxUnlocked end
    if data.stageCurrentPage then stageState.currentPage = data.stageCurrentPage end
    if data.stageStars then stageStars = data.stageStars end
    if data.stageStarClaimed then stageStarClaimed = data.stageStarClaimed end
    if data.stageChestClaimed then stageChestClaimed = data.stageChestClaimed end
    -- 兼容旧存档: stageFirstClear → stageStars (1星)
    if data.stageFirstClear and not data.stageStars then
        for k, v in pairs(data.stageFirstClear) do
            if v then stageStars[k] = 1 end
        end
    end
    if data.abyssCleared then abyssCleared = data.abyssCleared end
    if data.towerHighestFloor then towerState.highestFloor = data.towerHighestFloor end
    if data.towerCurrentFloor then towerState.currentFloor = math.min(data.towerCurrentFloor, 1000) end
    if data.rankedScore then rankedState.score = data.rankedScore end
    if data.rankedWins then rankedState.wins = data.rankedWins end
    if data.rankedLosses then rankedState.losses = data.rankedLosses end
    if data.rankedStreak then rankedState.streak = data.rankedStreak end
    if data.rankedHighestScore then rankedState.highestScore = data.rankedHighestScore end
    if data.gachaPity then gachaState.pityCounter = data.gachaPity end
    if data.limitedGachaPity then gachaState.limitedPityCounter = data.limitedGachaPity end
    if data.dailyTaskState then
        dailyTaskState.lastResetDay = data.dailyTaskState.lastResetDay or ""
        dailyTaskState.progress = data.dailyTaskState.progress or {}
        dailyTaskState.claimed = data.dailyTaskState.claimed or {}
        dailyTaskState.allClaimedBonus = data.dailyTaskState.allClaimedBonus or false
    end
    if data.weeklyTaskState then
        weeklyTaskState.lastResetWeek = data.weeklyTaskState.lastResetWeek or ""
        weeklyTaskState.progress = data.weeklyTaskState.progress or {}
        weeklyTaskState.claimed = data.weeklyTaskState.claimed or {}
        weeklyTaskState.allClaimedBonus = data.weeklyTaskState.allClaimedBonus or false
    end
    if data.achievementClaimed then achievementClaimed = data.achievementClaimed end
    if data.welfareState then
        local ws = data.welfareState
        if ws.signInClaimed then welfareState.signInClaimed = ws.signInClaimed end
        if ws.signInTimestamps then welfareState.signInTimestamps = ws.signInTimestamps end
        if ws.dailySignInClaimed then welfareState.dailySignInClaimed = ws.dailySignInClaimed end
        if ws.dailySignInTimestamps then welfareState.dailySignInTimestamps = ws.dailySignInTimestamps end
        if ws.onlineRewards then welfareState.onlineRewards = ws.onlineRewards end
        if ws.onlineTime then welfareState.onlineTime = ws.onlineTime end

        if ws.spinWheel then
            welfareState.spinWheel.lastDate = ws.spinWheel.lastDate or ""
            welfareState.spinWheel.freeUsed = ws.spinWheel.freeUsed or false
            welfareState.spinWheel.adSpins = ws.spinWheel.adSpins or 0
        end
        if ws.cardFlip then
            welfareState.cardFlip.lastDate = ws.cardFlip.lastDate or ""
            welfareState.cardFlip.freeUsed = ws.cardFlip.freeUsed or false
            welfareState.cardFlip.adFlips = ws.cardFlip.adFlips or 0
            welfareState.cardFlip.cards = ws.cardFlip.cards or {}
            welfareState.cardFlip.flipped = ws.cardFlip.flipped or {}
        end


    end
    if data.cdkRedeemed then
        cdkState.redeemed = data.cdkRedeemed
    end
    -- 邮件系统已领取状态
    if data.mailClaimed then
        for k, v in pairs(data.mailClaimed) do
            welfareState.mail.claimed[k] = v
        end
    end
    -- 云邮件已领取状态
    if data.cloudMailClaimed then
        for k, v in pairs(data.cloudMailClaimed) do
            CloudManager._mailClaimed[k] = v
        end
    end
    -- 免广告特权
    if data.playerInfo and data.playerInfo.ad_free then
        playerInfo.ad_free = true
    end
    -- 每周排行榜奖励结算标记
    if data.lastWeeklySettled then
        welfareState.lastWeeklySettled = data.lastWeeklySettled
    end
    -- 新手引导奖励领取标记（终身只领一次）
    if data.tutorialRewardClaimed then
        gameSettings.tutorialRewardClaimed = true
    end
    -- 兵符系统数据恢复 (JSON序列化会将数字key变为字符串key，必须修复)
    if data.sealData then
        sealData = {}
        for k, v in pairs(data.sealData) do
            local cardIdx = tonumber(k) or k
            if type(v) == "table" then
                local fixedSlots = {}
                if v.slots then
                    for sk, sv in pairs(v.slots) do
                        fixedSlots[tonumber(sk) or sk] = sv
                    end
                end
                sealData[cardIdx] = { slots = fixedSlots }
            end
        end
    end
    if data.sealExpItems then
        sealExpItems = {}
        for k, v in pairs(data.sealExpItems) do
            sealExpItems[tonumber(k) or k] = v
        end
    end
    if data.sealInventory then
        sealInventory = data.sealInventory
    end
    if data.sealInventoryNextId then
        sealInventoryNextId = tonumber(data.sealInventoryNextId) or data.sealInventoryNextId
    end
    -- sealGachaPity 已移除 (无保底机制), 忽略旧存档字段
    -- 每日副本数据恢复
    if data.dailyDungeonState then
        dailyDungeonState.lastResetDay = data.dailyDungeonState.lastResetDay or ""
        dailyDungeonState.completed = data.dailyDungeonState.completed or { false, false, false }
        dailyDungeonState.todaySlot = data.dailyDungeonState.todaySlot or 1
        dailyDungeonState.selectedSet = data.dailyDungeonState.selectedSet or 1
    end
    -- 探索资源副本数据恢复
    if data.resourceDungeonState then
        resourceDungeonState.lastResetDay = data.resourceDungeonState.lastResetDay or ""
        resourceDungeonState.completed = data.resourceDungeonState.completed or { false, false, false }
    end
    -- 战令通行证数据恢复
    if data.battlePassState then
        local bp = data.battlePassState
        battlePassState.seasonStartDay = bp.seasonStartDay or ""
        battlePassState.level = bp.level or 0
        battlePassState.exp = bp.exp or 0
        battlePassState.dailyProgress = bp.dailyProgress or {}
        battlePassState.weeklyProgress = bp.weeklyProgress or {}
        battlePassState.seasonProgress = bp.seasonProgress or {}
        battlePassState.dailyClaimed = bp.dailyClaimed or {}
        battlePassState.weeklyClaimed = bp.weeklyClaimed or {}
        battlePassState.seasonClaimed = bp.seasonClaimed or {}
        battlePassState.freeRewardClaimed = bp.freeRewardClaimed or {}
        battlePassState.premiumRewardClaimed = bp.premiumRewardClaimed or {}
        battlePassState.lastDailyReset = bp.lastDailyReset or ""
        battlePassState.lastWeeklyReset = bp.lastWeeklyReset or ""
    end
    -- 探索状态恢复（已移除探索系统）
    -- if data.explorationState then
    --     Exploration.Init(vg, fontId, IMG)
    --     SyncPlayerDataToExploration()
    --     Exploration.RestoreState(data.explorationState)
    --     print("[存档] 探索状态已恢复（不自动进入）")
    -- end
    -- 向下兼容: 同步 level 与 rankIdx，修复旧存档可能的不一致
    playerInfo.level = playerInfo.rankIdx or 1
    -- 检查是否有未处理的升级（旧存档经验够但没升级）
    CheckPlayerLevelUp()
end


-- 计算存档数据的进度权重（用于判断是否为空数据）
function GetSaveWeight(data)
    if not data or not data.playerInfo then return 0 end
    local pi = data.playerInfo
    return (pi.totalBattles or 0) + (pi.totalWins or 0) + (pi.rankIdx or 0) * 100
        + (pi.totalGachas or 0) + (pi.totalEquips or 0)
end


-- 判断存档是否为有效数据（非空/非默认初始状态）
function IsSaveValid(data)
    if not data or not data.playerInfo then return false end
    return data.playerInfo.profileSet == true
end


function LoadGameProgress(callback)
    -- 委托给 CloudManager 多domain加载 (本地优先 + 云端对比)
    local CloudMgr = rawget(_G, 'CloudManager')
    if CloudMgr then
        CloudMgr.LoadAll(function(source)
            if callback then callback(source) end
            print("[存档] 加载完成, source=" .. tostring(source))
        end)
        return
    end

    -- 降级: CloudManager 未加载时，使用旧逻辑
    local localData = nil
    if fileSystem:FileExists(FILE_SAVEGAME) then
        local cjson_m = rawget(_G, "cjson") ---@type table
        if cjson_m then
            local file = File(FILE_SAVEGAME, FILE_READ)
            if file:IsOpen() then
                local ok, data = pcall(cjson_m.decode, file:ReadString())
                file:Close()
                if ok and data then localData = data end
            end
        end
    end
    if localData then
        ApplySaveData(localData)
        print("[存档] 本地存档已加载(降级模式)")
    end
    if callback then callback(localData and "local" or "none") end
end
