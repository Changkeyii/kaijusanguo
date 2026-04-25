-- ============================================================================
-- ui/input_press_dungeon.lua - 副本/关卡点击处理
-- 用途: BeginPress 子处理器 - WORLD_MAP, STAGE_SELECT, DAILY_DUNGEON, RESOURCE_DUNGEON
-- 依赖: 全局变量 (gameState, ScreenToDesign, DrawBtn 等)
-- 导出: M.handle(sx, sy, touchId) -> boolean (是否已处理)
-- [TECH_DEBT] 全局变量模式: 延续 input 模块的全局状态设计
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

--- 处理点击事件 (仅处理本模块负责的 phase)
---@param sx number 屏幕坐标X
---@param sy number 屏幕坐标Y
---@param touchId number 触摸ID
---@return boolean handled 是否已处理
function M.handle(sx, sy, touchId)
    local dx, dy = ScreenToDesign(sx, sy)
    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    -- if gameState.phase == "EXPLORATION" then
    --     Exploration.HandlePress(dx, dy)
    --     return
    -- end

    if gameState.phase == "WORLD_MAP" then
        -- 行军动画期间屏蔽输入
        if rawget(_G, "WorldMap") and WorldMap.IsMarchActive and WorldMap.IsMarchActive() then
            return
        end
        -- 新手引导优先拦截输入
        if WorldMap.HandleGuideInput(dx, dy) then
            return
        end
        -- 回合报告拖拽滚动: 记录起始Y
        if worldMapState.phase == "TURN_REPORT" then
            worldMapState.reportDragging = true
            worldMapState.reportDragLastY = dy
        end
        -- 城池列表拖拽滚动: 记录起始Y (左侧230px区域)
        if dx < 230 then
            worldMapState.cityListDragging = true
            worldMapState.cityListDragStartY = dy
            worldMapState.cityListDragLastY = dy
        end
        WorldMap.HandleInput(dx, dy)
        return
    end

    if gameState.phase == "STAGE_SELECT" then
        -- 爆装弹窗关闭
        if stageState.showDropPopup then
            if stageDropCloseRect and HitRect(stageDropCloseRect) then
                stageState.showDropPopup = false
                stageState.lastDropReward = nil
                return
            end
            return  -- 弹窗打开时屏蔽其他点击
        end
        -- 预览弹窗
        if stageState.showPreview then
            if stagePreviewCloseRect and HitRect(stagePreviewCloseRect) then
                stageState.showPreview = false
                return
            end
            if stageStartBtnRect and HitRect(stageStartBtnRect) then
                -- 开始探索 (搜打撤模式)
                local stageIdx = stageState.currentStage
                local stage = STAGES[stageIdx]
                stageMaxTier = stage.maxTier or 1
                stageState.showPreview = false
                -- [EXPLORATION REMOVED] 探索模块已移除
                PlaySFX(AUDIO.sfx_click)
                return
                --[=[ EXPLORATION REMOVED: 以下探索代码已注释

                -- 初始化探索模块 (首次)
                if not Exploration.IsActive() then
                    Exploration.Init(vg, fontId, IMG)
                end

                SyncPlayerDataToExploration()

                -- 配置探索地图
                local gs = GameConfig.STAGE_GRID_SIZES[stageIdx] or 4
                Exploration.StartMap({
                    mode = "stage",
                    stageIdx = stageIdx,
                    stageName = stage.name,
                    gridSize = gs,
                    enemyScale = stage.enemyScale or 1.0,
                    maxTier = stage.maxTier or 1,
                    dropSets = stage.dropSets,
                    dropRateBonus = 0,
                })

                -- 设置回调
                Exploration.onStartBattle = function(enemyScale, maxTier, dropSets)
                    -- 从探索进入战斗
                    gameState.explorationMode = true
                    gameState.abyssFloor = nil
                    gameState.towerFloor = nil
                    gameState.isRanked = false
                    gameState.phase = "BATTLE"
                    gameState.battlePhase = "DEPLOY"
                    gameState.playerBaseHP = BASE_HP_MAX
                    gameState.enemyBaseHP = BASE_HP_MAX
                    gameState.gold = GameConfig.INITIAL_GOLD
                    gameState.totalKills = 0
                    gameState.battleTime = 0
                    gameState.drawCount = 0
                    gameState.goldTimer = 0
                    gameState.resultTimer = 0
                    gameState.autoMarch = false
                    stageMaxTier = maxTier or 1
                    for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                    activeSkillEffects = {}
                    skillTargeting.active = false
                    for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                    for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                    playerUnits = {}
                    enemyUnits = {}
                    inventory = {}
                    RefreshShop()
                    -- 应用探索增益
                    local buff = Exploration.GetBuff()
                    gameState.exploreBuff = buff  -- 存储供 AggregateBaseStats 使用
                    if buff then
                        if buff.type == "hp_bonus" then
                            gameState.playerBaseHP = BASE_HP_MAX + buff.value
                            gameState.playerBaseMax = BASE_HP_MAX + buff.value
                        end
                    end
                    -- 敌方部署 (按敌人规模调整)
                    local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 2))
                    local used = {}
                    for i = 1, enemyCount do
                        local idx
                        repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
                        used[idx] = true
                        if i <= #ENEMY_SLOTS then
                            local card = DeepCopy(ENEMY_CARDS[idx])
                            card.level = 1
                            card.constellation = 0
                            card.cardIdx = idx
                            ENEMY_SLOTS[i].filled = true
                            ENEMY_SLOTS[i].card = card
                        end
                    end
                    print("=== 探索战斗开始 (关卡: " .. stage.name .. ") ===")
                end

                Exploration.onComplete = function(result)
                    -- 探索完成回调: 发放奖励
                    if result then
                        if result.success then
                            playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                        end
                        local jadeReward = result.totalJade or 0
                        if exploreAdDoubleJade then
                            jadeReward = jadeReward * 2
                            exploreAdDoubleJade = false
                        end
                        result.totalJade = jadeReward  -- 更新用于后续显示
                        playerInfo.jade = playerInfo.jade + jadeReward
                        -- 按武技分配残片
                        if result.fragList then
                            for _, fi in ipairs(result.fragList) do
                                skillFragments[fi.skillIdx] = (skillFragments[fi.skillIdx] or 0) + fi.count
                            end
                        elseif (result.totalFrag or 0) > 0 then
                            -- 兼容旧数据: 随机分配
                            for _ = 1, result.totalFrag do
                                local idx = math.random(1, #SKILL_TECHNIQUES)
                                skillFragments[idx] = (skillFragments[idx] or 0) + 1
                            end
                        end
                        -- 装备掉落：直接使用探索中已确定的品级/套装/部位（保证显示与实际一致）
                        local equipDrops = {}
                        if result.equipCount and result.equipCount > 0 then
                            for _, loot in ipairs(result.loot) do
                                if loot.hasEquipment then
                                    local tier = loot.equipTier or 1
                                    local si = loot.equipSet or math.random(1, #EQUIPMENT_SETS)
                                    local pi = loot.equipSlotIdx or math.random(1, 7)
                                    local minQ = loot.equipMinQuality or 0
                                    local q = math.random(math.max(0, minQ), 100)
                                    local item = CreateEquipItem(si, pi, tier, q)
                                    playerInfo.totalEquips = playerInfo.totalEquips + 1
                                    table.insert(equipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                                end
                            end
                        end
                        -- 显示装备掉落通知（每件单独提示，告知品阶、槽位和品质）
                        for i, eqDrop in ipairs(equipDrops) do
                            local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "未知"
                            local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "未知"
                            local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                            local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255, 255, 255}
                            local qLabel = GetQualityLabel(eqDrop.quality or 0)
                            local eLv = eqDrop.level or 1
                            local dropMsg = "获得兵甲: " .. tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i - 1) * 30, dropMsg, 3.0, tc, 20)
                        end
                        -- 历劫模式: 星级奖励 + 关卡解锁
                        if result.mode == "stage" and result.success then
                            local si = result.stageIdx
                            local key = tostring(si)
                            -- 计算星级 (基于基地HP)
                            local hpPct = (gameState.playerBaseHP or 0) / (BASE_HP_MAX or 1)
                            local earnedStars = 1
                            if hpPct > 0.8 then
                                earnedStars = 3
                            elseif hpPct > 0.5 then earnedStars = 2 end
                            local prevStars = stageStars[key] or 0
                            if earnedStars > prevStars then
                                stageStars[key] = earnedStars
                                local totalJadeReward = 0
                                for s = prevStars + 1, earnedStars do
                                    local claimKey = key .. "_" .. s
                                    if not stageStarClaimed[claimKey] then
                                        stageStarClaimed[claimKey] = true
                                        totalJadeReward = totalJadeReward + (STAGE_STAR_JADE[s] or 0)
                                    end
                                end
                                if totalJadeReward > 0 then
                                    playerInfo.jade = playerInfo.jade + totalJadeReward
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "★" .. earnedStars .. " 星级奖励: +" .. totalJadeReward .. " 玉壁", 2.0, {255, 220, 80}, 20)
                                end
                            end
                            if si >= stageState.maxUnlocked and si < #STAGES then
                                stageState.maxUnlocked = si + 1
                            end
                        end
                        -- 讨伐模式: 记录通关
                        if result.mode == "abyss" and result.success and result.abyssFloor then
                            local floorKey = tostring(result.abyssFloor)
                            if not abyssCleared[floorKey] then
                                abyssCleared[floorKey] = true
                            end
                            TrackDailyTask("abyss1", 1)
                            TrackWeeklyTask("wabyss3", 1)
                            TrackBattlePassTask("bp_wabyss3", 1)
                            TrackBattlePassTask("bp_sabyss10", 1)
                        end
                        if result.success or jadeReward > 0 or #equipDrops > 0 then
                            local rewardStr = "探索结束: +" .. (result.totalJade or 0) .. " 玉壁"
                            if result.fragList and #result.fragList > 0 then
                                local totalF = 0
                                for _, fi in ipairs(result.fragList) do totalF = totalF + fi.count end
                                rewardStr = rewardStr .. " +" .. totalF .. "武技残片"
                            end
                            if #equipDrops > 0 then
                                rewardStr = rewardStr .. " +" .. #equipDrops .. "件兵甲"
                            end
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, rewardStr, 2.0, {255, 220, 80}, 22)
                        else
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "探索放弃, 未获得奖励", 2.0, {180, 180, 180}, 18)
                        end
                        -- 战令: 探索完成 (仅成功/撤离时追踪, 放弃不算)
                        if result.success then
                            TrackBattlePassTask("bp_explore1", 1)
                            TrackBattlePassTask("bp_wexplore5", 1)
                            TrackBattlePassTask("bp_sexplore15", 1)
                        end
                    end
                    gameState.explorationMode = false
                    gameState.noFullAuto = false  -- 离开探索, 恢复全自动可用
                    PopPhase("MENU")
                    SaveGameProgress()
                end

                Exploration.onShopPurchase = function(cost)
                    playerInfo.jade = math.max(0, playerInfo.jade - cost)
                end
                Exploration.onShowToast = function(msg)
                    ShowToast(msg, 2.0)
                end
                Exploration.canWatchAd = function()
                    if IsBattleAdFree() then return false end
                    return not IsDailyAdLimitReached()
                end
                Exploration.isBattleAdFree = function() return IsBattleAdFree() end
                Exploration.onWatchAdForDouble = function(callback)
                    if sdk then
                        ShowAdSafe(SafeAdCallback(function(result)
                            if result.success then
                                ReportAdWatch()
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "玉壁已翻倍!", 1.5, { 120, 255, 180 }, 18)
                                if callback then callback(true) end
                            else
                                if callback then callback(false) end
                            end
                        end))
                    else
                        ReportAdWatch()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "玉壁已翻倍!", 1.5, { 120, 255, 180 }, 18)
                        if callback then callback(true) end
                    end
                end

                PushPhase("EXPLORATION")
                PlaySFX(AUDIO.sfx_click)
                print("=== 开始探索: " .. stage.name .. " (" .. gs .. "×" .. gs .. ") ===")
                return
                --]=] -- END EXPLORATION REMOVED (STAGE_SELECT)
            end
            return
        end
        -- 返回按钮
        if stageBackBtnRect and HitRect(stageBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            return
        end
        -- 翻页按钮
        if stagePagePrevRect and HitRect(stagePagePrevRect) then
            if stageState.currentPage > 1 then
                stageState.currentPage = stageState.currentPage - 1
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        if stagePageNextRect and HitRect(stagePageNextRect) then
            if stageState.currentPage < STAGE_TOTAL_PAGES then
                stageState.currentPage = stageState.currentPage + 1
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        -- 宝箱点击
        for ci, cRect in ipairs(stageChestRects) do
            if cRect and HitRect(cRect) then
                local chestKey = tostring(cRect.page) .. "_" .. tostring(cRect.threshold)
                local pageStars = GetPageStars(cRect.page)
                if pageStars >= cRect.threshold and not stageChestClaimed[chestKey] then
                    stageChestClaimed[chestKey] = true
                    local reward = STAGE_CHEST_REWARDS[ci]
                    if reward then
                        GrantRewardTable(reward)
                        local msg = "宝箱奖励: +" .. reward.jade .. " 玉壁"
                        if reward.frag and reward.frag > 0 then
                            msg = msg .. " +" .. reward.frag .. " 武技残片"
                        end
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, msg, 2.0, {255, 220, 80}, 20)
                    end
                    PlaySFX(AUDIO.sfx_click)
                    SaveGameProgress()
                else
                    if stageChestClaimed[chestKey] then
                        ShowToast("已领取")
                    else
                        ShowToast("需要 " .. cRect.threshold .. " 星才能领取")
                    end
                end
                return
            end
        end
        -- 关卡节点点击 (stageNodeRects 现在携带 stageIdx)
        for i, rect in ipairs(stageNodeRects) do
            if rect and HitRect(rect) then
                local stageIdx = rect.stageIdx
                if stageIdx and stageIdx <= stageState.maxUnlocked then
                    stageState.currentStage = stageIdx
                    stageState.showPreview = true
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        return
    end

    -- === 个人资料界面输入 ===
    if gameState.phase == "DAILY_DUNGEON" then
        if phaseChangeCooldown > 0 then return end

        -- 确认弹窗
        if dailyDungeonState.showConfirm then
            -- 关闭
            if dailyDungeonCloseRect and HitRect(dailyDungeonCloseRect) then
                dailyDungeonState.showConfirm = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 副本2: 套装选择按钮
            local di = dailyDungeonState.selectedDungeon
            if di == 2 then
                for si = 1, 7 do
                    if dailyDungeonSetBtnRects[si] and HitRect(dailyDungeonSetBtnRects[si]) then
                        dailyDungeonState.selectedSet = si
                        PlaySFX(AUDIO.sfx_click)
                        return
                    end
                end
            end
            -- 消耗玉壁进入按钮
            if dailyDungeonConfirmBtnRect and HitRect(dailyDungeonConfirmBtnRect) then
                if not di or dailyDungeonState.completed[di] then return end
                PlaySFX(AUDIO.sfx_click)

                local function EnterDailyDungeon()
                    -- [EXPLORATION REMOVED] 探索模块已移除
                    dailyDungeonState.showConfirm = false
                    ShowToast("探索功能暂未开放")
                    return
                    --[=[ EXPLORATION REMOVED: 以下探索代码已注释
                    SaveGameProgress()

                    -- 初始化探索模块
                    if not Exploration.IsActive() then
                        Exploration.Init(vg, fontId, IMG)
                    end
                    SyncPlayerDataToExploration()

                    -- 副本配置
                    local eScale = 1.0 + (playerInfo.rankIdx or 1) * 0.15
                    local highTierMul = (di == 3) and 10 or 1
                    local dailyMode = "daily" .. di

                    Exploration.StartMap({
                        mode = dailyMode,
                        gridSize = 5,
                        enemyScale = eScale,
                        maxTier = 6,
                        dropSets = (di == 2) and { dailyDungeonState.selectedSet } or {1,2,3,4,5,6,7},
                        highTierMultiplier = highTierMul,
                        dropRateBonus = 0.3,
                    })

                    -- 战斗回调
                    Exploration.onStartBattle = function(enemyScale, maxTier, dropSets)
                        gameState.explorationMode = true
                        gameState.noFullAuto = true   -- 每日副本禁止全自动
                        gameState.autoBattle = false
                        gameState.abyssFloor = nil
                        gameState.towerFloor = nil
                        gameState.isRanked = false
                        gameState.phase = "BATTLE"
                        gameState.battlePhase = "DEPLOY"
                        gameState.playerBaseHP = BASE_HP_MAX
                        gameState.enemyBaseHP = BASE_HP_MAX
                        gameState.gold = GameConfig.INITIAL_GOLD
                        gameState.totalKills = 0
                        gameState.battleTime = 0
                        gameState.drawCount = 0
                        gameState.goldTimer = 0
                        gameState.resultTimer = 0
                        gameState.autoMarch = false
                        stageMaxTier = maxTier or 1
                        for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                        activeSkillEffects = {}
                        skillTargeting.active = false
                        for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                        for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                        playerUnits = {}
                        enemyUnits = {}
                        inventory = {}
                        RefreshShop()
                        local buff = Exploration.GetBuff()
                        gameState.exploreBuff = buff
                        if buff then
                            if buff.type == "hp_bonus" then
                                gameState.playerBaseHP = BASE_HP_MAX + buff.value
                                gameState.playerBaseMax = BASE_HP_MAX + buff.value
                            end
                        end
                        local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 2))
                        local used = {}
                        for i = 1, enemyCount do
                            local idx
                            repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
                            used[idx] = true
                            if i <= #ENEMY_SLOTS then
                                local card = DeepCopy(ENEMY_CARDS[idx])
                                card.level = 1
                                card.constellation = 0
                                card.cardIdx = idx
                                ENEMY_SLOTS[i].filled = true
                                ENEMY_SLOTS[i].card = card
                            end
                        end
                        -- 敌方战力匹配玩家当前战力
                        local ppTotal = CalcPlayerTotalPower()
                        local nonHP = CalcRankPowerScore() + CalcEquipPowerScore() + CalcSkillPowerScore()
                        local targetHP = math.max(1, ppTotal - nonHP)
                        local rawEP = 0
                        for _, s in ipairs(ENEMY_SLOTS) do
                            if s.filled and s.card then
                                rawEP = rawEP + (s.card.atk * 2 + s.card.def + s.card.hp * 0.1)
                            end
                        end
                        if rawEP > 0 then
                            local sc = targetHP / rawEP
                            for _, s in ipairs(ENEMY_SLOTS) do
                                if s.filled and s.card then
                                    s.card.atk = math.floor(s.card.atk * sc)
                                    s.card.def = math.floor(s.card.def * sc)
                                    s.card.hp  = math.floor(s.card.hp * sc)
                                end
                            end
                        end
                        ApplyBattleLayout(1)
                        InitAISkills()
                        print("=== 每日副本战斗 (类型" .. di .. ") ===")
                    end

                    Exploration.onComplete = function(result)
                        if result then
                            if result.success then
                                dailyDungeonState.completed[di] = true  -- 只有走撤离通道才标记通关
                                playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                            end
                            local jadeReward = result.totalJade or 0
                            if exploreAdDoubleJade then
                                jadeReward = jadeReward * 2
                                exploreAdDoubleJade = false
                            end
                            result.totalJade = jadeReward  -- 更新用于后续显示
                            playerInfo.jade = playerInfo.jade + jadeReward
                            if result.fragList then
                                for _, fItem in ipairs(result.fragList) do
                                    skillFragments[fItem.skillIdx] = (skillFragments[fItem.skillIdx] or 0) + fItem.count
                                end
                            end
                            -- 每日副本专属掉落逻辑
                            local ddEquipDrops = {}
                            if result.equipCount and result.equipCount > 0 then
                                for _, loot in ipairs(result.loot) do
                                    if loot.hasEquipment then
                                        local tier = loot.equipTier or 2
                                        local si = loot.equipSet or math.random(1, #EQUIPMENT_SETS)
                                        local pi = loot.equipSlotIdx or math.random(1, 7)
                                        -- 副本1: 强制指定部位
                                        if di == 1 then
                                            pi = dailyDungeonState.todaySlot
                                        end
                                        -- 副本2: 强制指定套装
                                        if di == 2 then
                                            si = dailyDungeonState.selectedSet
                                        end
                                        local minQ = loot.equipMinQuality or 0
                                        local q = math.random(math.max(0, minQ), 100)
                                        local item = CreateEquipItem(si, pi, tier, q)
                                        playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                                        table.insert(ddEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                                    end
                                end
                            end
                            -- 保底: 每个副本至少掉1件装备 (仅成功/撤离时触发, 放弃不保底)
                            if #ddEquipDrops == 0 and result.success then
                                local si = (di == 2) and dailyDungeonState.selectedSet or math.random(1, #EQUIPMENT_SETS)
                                local pi = (di == 1) and dailyDungeonState.todaySlot or math.random(1, 7)
                                local tier = (di == 3) and math.random(4, 6) or math.random(2, 4)
                                local item = CreateEquipItem(si, pi, tier, math.random(40, 100))
                                playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                                table.insert(ddEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                            end
                            if result.success or jadeReward > 0 or #ddEquipDrops > 0 then
                                for i, eqDrop in ipairs(ddEquipDrops) do
                            local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "未知"
                            local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "未知"
                                    local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                                    local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255,255,255}
                                    local qLabel = GetQualityLabel(eqDrop.quality or 0)
                                    local eLv = eqDrop.level or 1
                                    local dropMsg = tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i - 1) * 30, dropMsg, 3.0, tc, 20)
                                end
                                local ddStr = "副本完成: +" .. #ddEquipDrops .. "件兵甲"
                                if jadeReward > 0 then ddStr = ddStr .. " +" .. jadeReward .. " 玉壁" end
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, ddStr, 2.5, {80, 220, 160}, 22)
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "副本放弃, 未获得奖励", 2.0, {180, 180, 180}, 18)
                            end
                        end
                        gameState.explorationMode = false
                        gameState.noFullAuto = false  -- 离开副本, 恢复全自动可用
                        PopPhase("MENU")
                        SaveGameProgress()
                    end

                    Exploration.onShopPurchase = function(cost)
                        playerInfo.jade = math.max(0, playerInfo.jade - cost)
                    end
                    Exploration.onShowToast = function(msg)
                        ShowToast(msg, 2.0)
                    end
                    Exploration.canWatchAd = function()
                        if IsBattleAdFree() then return false end
                        return not IsDailyAdLimitReached()
                    end
                    Exploration.isBattleAdFree = function() return IsBattleAdFree() end
                    Exploration.onWatchAdForDouble = function(callback)
                        if sdk then
                            ShowAdSafe(SafeAdCallback(function(res)
                                if res.success then
                                    ReportAdWatch()
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "玉壁已翻倍!", 1.5, {120,255,180}, 18)
                                    if callback then callback(true) end
                                else
                                    if callback then callback(false) end
                                end
                            end))
                        else
                            ReportAdWatch()
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "玉壁已翻倍!", 1.5, {120,255,180}, 18)
                            if callback then callback(true) end
                        end
                    end

                    PushPhase("EXPLORATION")
                    PlaySFX(AUDIO.sfx_click)
                    print("=== 开始每日副本" .. di .. ": " .. DAILY_DUNGEON_NAMES[di] .. " (5×5) ===")
                    --]=] -- END EXPLORATION REMOVED (DAILY_DUNGEON)
                end

                -- 扣除300玉壁入场
                local DUNGEON_ENTRY_COST = 300
                if playerInfo.jade >= DUNGEON_ENTRY_COST then
                    playerInfo.jade = playerInfo.jade - DUNGEON_ENTRY_COST
                    EnterDailyDungeon()
                else
                    ShowToast("玉壁不足，需要 " .. DUNGEON_ENTRY_COST .. " 玉壁", 2.0)
                end
                return
            end
            return
        end

        -- 返回按钮
        if dailyDungeonBackRect and HitRect(dailyDungeonBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 副本卡片点击
        for di = 1, 3 do
            if dailyDungeonCardRects[di] and HitRect(dailyDungeonCardRects[di]) then
                if dailyDungeonState.completed[di] then
                    ShowToast("不能添加自己为好友")
                else
                    dailyDungeonState.selectedDungeon = di
                    dailyDungeonState.showConfirm = true
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        return
    end

    -- === 个人资料界面输入 ===
    if gameState.phase == "RESOURCE_DUNGEON" then
        if phaseChangeCooldown > 0 then return end

        -- 确认弹窗
        if resourceDungeonState.showConfirm then
            -- 关闭按钮
            if resourceDungeonConfirmRect and resourceDungeonConfirmRect.close and HitRect(resourceDungeonConfirmRect.close) then
                resourceDungeonState.showConfirm = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 确认进入按钮
            if resourceDungeonConfirmRect and resourceDungeonConfirmRect.enter and HitRect(resourceDungeonConfirmRect.enter) then
                local ti = resourceDungeonState.selectedType
                if not ti or resourceDungeonState.completed[ti] then return end
                local rdCfg = GameConfig.RESOURCE_DUNGEON
                local typeInfo = rdCfg.types[ti]
                if not typeInfo then return end
                -- 检查玉壁
                if playerInfo.jade < rdCfg.entryCost then
                    ShowToast("玉壁不足! 需要 " .. rdCfg.entryCost .. " 玉壁")
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                PlaySFX(AUDIO.sfx_click)

                local function EnterResourceDungeon()
                    -- [EXPLORATION REMOVED] 探索模块已移除
                    resourceDungeonState.showConfirm = false
                    ShowToast("探索功能暂未开放")
                    return
                    --[=[ EXPLORATION REMOVED: 以下探索代码已注释
                    -- 扣除门票
                    playerInfo.jade = playerInfo.jade - rdCfg.entryCost
                    resourceDungeonState.showConfirm = false
                    -- 不立即标记完成, 通关才算
                    SaveGameProgress()

                    -- 初始化探索模块
                    if not Exploration.IsActive() then
                        Exploration.Init(vg, fontId, IMG)
                    end
                    SyncPlayerDataToExploration()

                    -- 副本配置: 遭遇战模式
                    local eScale = 1.0 + (playerInfo.rankIdx or 1) * 0.15
                    local ppTotal = CalcPlayerTotalPower()
                    -- 略高于玩家战力
                    eScale = eScale * (1.0 + math.random() * 0.1)

                    Exploration.StartMap({
                        mode = "resource_" .. typeInfo.id,
                        gridSize = rdCfg.gridSize,
                        enemyScale = eScale,
                        maxTier = typeInfo.maxTier,
                        dropSets = {1, 2, 3, 4, 5, 6, 7},
                        highTierMultiplier = typeInfo.highTierMultiplier or 1,
                        dropRateBonus = typeInfo.dropRateBonus or 0,
                        fragMultiplier = typeInfo.fragMultiplier or 1.0,
                        jadeMultiplier = typeInfo.jadeMultiplier or 1.0,
                        -- 遭遇战模式参数
                        encounterMode = true,
                        encounterRate = rdCfg.encounterRate,
                        enemyDensityOverride = rdCfg.enemyDensity,
                        chestCountOverride = rdCfg.chestCount,
                        blockedRatioOverride = rdCfg.blockedRatio,
                        eventRatioOverride = rdCfg.eventRatio,
                        chestGuardOverride = rdCfg.chestGuardChance,
                    })

                    -- 战斗回调
                    Exploration.onStartBattle = function(enemyScale2, maxTier2, dropSets2)
                        gameState.explorationMode = true
                        gameState.noFullAuto = true   -- 探索副本禁止全自动
                        gameState.autoBattle = false
                        gameState.abyssFloor = nil
                        gameState.towerFloor = nil
                        gameState.isRanked = false
                        gameState.phase = "BATTLE"
                        gameState.battlePhase = "DEPLOY"
                        gameState.playerBaseHP = BASE_HP_MAX
                        gameState.enemyBaseHP = BASE_HP_MAX
                        gameState.gold = GameConfig.INITIAL_GOLD
                        gameState.totalKills = 0
                        gameState.battleTime = 0
                        gameState.drawCount = 0
                        gameState.goldTimer = 0
                        gameState.resultTimer = 0
                        gameState.autoMarch = false
                        stageMaxTier = maxTier2 or typeInfo.maxTier or 1
                        for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                        activeSkillEffects = {}
                        skillTargeting.active = false
                        for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                        for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                        playerUnits = {}
                        enemyUnits = {}
                        inventory = {}
                        RefreshShop()
                        local buff = Exploration.GetBuff()
                        gameState.exploreBuff = buff
                        if buff then
                            if buff.type == "hp_bonus" then
                                gameState.playerBaseHP = BASE_HP_MAX + buff.value
                                gameState.playerBaseMax = BASE_HP_MAX + buff.value
                            end
                        end
                        -- 敌方单位
                        local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 2))
                        local used = {}
                        for i = 1, enemyCount do
                            local idx
                            repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
                            used[idx] = true
                            if i <= #ENEMY_SLOTS then
                                local card = DeepCopy(ENEMY_CARDS[idx])
                                card.level = 1
                                card.constellation = 0
                                card.cardIdx = idx
                                ENEMY_SLOTS[i].filled = true
                                ENEMY_SLOTS[i].card = card
                            end
                        end
                        -- 敌方战力匹配玩家当前战力 (略高)
                        local nonHP = CalcRankPowerScore() + CalcEquipPowerScore() + CalcSkillPowerScore()
                        local targetHP = math.max(1, ppTotal - nonHP)
                        targetHP = math.floor(targetHP * (1.0 + math.random() * 0.15))
                        local rawEP = 0
                        for _, s in ipairs(ENEMY_SLOTS) do
                            if s.filled and s.card then
                                rawEP = rawEP + (s.card.atk * 2 + s.card.def + s.card.hp * 0.1)
                            end
                        end
                        if rawEP > 0 then
                            local sc = targetHP / rawEP
                            for _, s in ipairs(ENEMY_SLOTS) do
                                if s.filled and s.card then
                                    s.card.atk = math.floor(s.card.atk * sc)
                                    s.card.def = math.floor(s.card.def * sc)
                                    s.card.hp  = math.floor(s.card.hp * sc)
                                end
                            end
                        end
                        ApplyBattleLayout(1)
                        InitAISkills()
                        print("=== 探索副本战斗 (" .. typeInfo.name .. ") ===")
                    end

                    Exploration.onComplete = function(result)
                        if result then
                            -- 只有撤离成功才标记通关 (退出=0收益不算完成)
                            if result.success then
                                resourceDungeonState.completed[ti] = true
                                playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                            end
                            local jadeReward = result.totalJade or 0
                            if exploreAdDoubleJade then
                                jadeReward = jadeReward * 2
                                exploreAdDoubleJade = false
                            end
                            result.totalJade = jadeReward  -- 更新用于后续显示
                            playerInfo.jade = playerInfo.jade + jadeReward
                            if result.fragList then
                                for _, fItem in ipairs(result.fragList) do
                                    skillFragments[fItem.skillIdx] = (skillFragments[fItem.skillIdx] or 0) + fItem.count
                                end
                            end
                            -- 探索副本专属掉落
                            local rdEquipDrops = {}
                            if result.equipCount and result.equipCount > 0 then
                                for _, loot in ipairs(result.loot) do
                                    if loot.hasEquipment then
                                        local tier = loot.equipTier or 2
                                        local si = loot.equipSet or math.random(1, #EQUIPMENT_SETS)
                                        local pi = loot.equipSlotIdx or math.random(1, 7)
                                        local minQ = loot.equipMinQuality or 0
                                        local q = math.random(math.max(0, minQ), 100)
                                        local item = CreateEquipItem(si, pi, tier, q)
                                        playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                                        table.insert(rdEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                                    end
                                end
                            end
                            -- 保底: 至少掉1件装备 (仅成功/撤离时触发, 放弃不保底)
                            if #rdEquipDrops == 0 and result.success then
                                local si = math.random(1, #EQUIPMENT_SETS)
                                local pi = math.random(1, 7)
                                local tier = math.random(2, math.min(typeInfo.maxTier, 4))
                                local item = CreateEquipItem(si, pi, tier, math.random(30, 90))
                                playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                                table.insert(rdEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                            end
                            if result.success or jadeReward > 0 or #rdEquipDrops > 0 then
                                for i2, eqDrop in ipairs(rdEquipDrops) do
                            local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "未知"
                            local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "未知"
                                    local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                                    local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255,255,255}
                                    local qLabel = GetQualityLabel(eqDrop.quality or 0)
                                    local eLv = eqDrop.level or 1
                                    local dropMsg = tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i2 - 1) * 30, dropMsg, 3.0, tc, 20)
                                end
                                local rdStr = typeInfo.name .. "完成: +" .. #rdEquipDrops .. "件兵甲"
                                if jadeReward > 0 then rdStr = rdStr .. " +" .. jadeReward .. " 玉壁" end
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, rdStr, 2.5, {typeInfo.color[1], typeInfo.color[2], typeInfo.color[3]}, 22)
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "探索放弃, 未获得奖励", 2.0, {180, 180, 180}, 18)
                            end
                        end
                        -- 战令: 探索完成 (仅成功/撤离时追踪, 放弃不算)
                        if result and result.success then
                            TrackBattlePassTask("bp_explore1", 1)
                            TrackBattlePassTask("bp_wexplore5", 1)
                            TrackBattlePassTask("bp_sexplore15", 1)
                        end
                        gameState.explorationMode = false
                        gameState.noFullAuto = false  -- 离开探索, 恢复全自动可用
                        PopPhase("MENU")
                        SaveGameProgress()
                    end

                    Exploration.onShopPurchase = function(cost)
                        playerInfo.jade = math.max(0, playerInfo.jade - cost)
                    end
                    Exploration.onShowToast = function(msg)
                        ShowToast(msg, 2.0)
                    end
                    Exploration.canWatchAd = function()
                        if IsBattleAdFree() then return false end
                        return not IsDailyAdLimitReached()
                    end
                    Exploration.isBattleAdFree = function() return IsBattleAdFree() end
                    Exploration.onWatchAdForDouble = function(callback)
                        if sdk then
                            ShowAdSafe(SafeAdCallback(function(res)
                                if res.success then
                                    ReportAdWatch()
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "玉壁已翻倍!", 1.5, {120,255,180}, 18)
                                    if callback then callback(true) end
                                else
                                    if callback then callback(false) end
                                end
                            end))
                        else
                            ReportAdWatch()
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "玉壁已翻倍!", 1.5, {120,255,180}, 18)
                            if callback then callback(true) end
                        end
                    end

                    PushPhase("EXPLORATION")
                    PlaySFX(AUDIO.sfx_click)
                    print("=== 开始探索副本: " .. typeInfo.name .. " (7×7 遭遇战) ===")
                    --]=] -- END EXPLORATION REMOVED (RESOURCE_DUNGEON)
                end

                -- 直接进入 (门票制, 非广告制)
                EnterResourceDungeon()
                return
            end
            return
        end

        -- 返回按钮
        if resourceDungeonBackRect and HitRect(resourceDungeonBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 副本类型卡片点击
        for di = 1, 3 do
            if resourceDungeonCardRects[di] and HitRect(resourceDungeonCardRects[di]) then
                if resourceDungeonState.completed[di] then
                    ShowToast("不能添加自己为好友")
                else
                    resourceDungeonState.selectedType = di
                    resourceDungeonState.showConfirm = true
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        return
    end


    return false  -- 未匹配任何 phase
end

return M
