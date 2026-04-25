-- ============================================================================
-- ui/input_press_endgame.lua - 终局/战令/战果点击处理
-- 用途: BeginPress 子处理器 - BATTLE_PASS, ABYSS_SELECT, TOWER_SELECT, RANKED_SELECT, WIN, LOSE
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
    local lx, ly = ScreenToLogical(sx, sy)
    local dx, dy = ScreenToDesign(sx, sy)
    -- 战场设计坐标 (考虑 battleZoom/Pan, 用于战场内单位/区域交互)
    local bdx, bdy = ScreenToBattleDesign(sx, sy)
    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    if gameState.phase == "BATTLE_PASS" then
        if phaseChangeCooldown > 0 then return end

        -- 返回按钮
        if battlePassBackRect and HitRect(battlePassBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- Tab切换
        for ti = 1, 4 do
            if battlePassTabRects[ti] and HitRect(battlePassTabRects[ti]) then
                if battlePassUIState.tab ~= ti then
                    battlePassUIState.tab = ti
                    battlePassUIState.scrollY = 0
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end

        -- Tab 1: 奖励总览 - 领取按钮
        if battlePassUIState.tab == 1 then
            -- 高级奖励领取（看广告 / 免广告特权直接领取）
            for lv, rect in pairs(battlePassClaimPremiumRects) do
                if HitRect(rect) then
                    if playerInfo.ad_free then
                        -- 免广告特权: 直接领取
                        if ClaimBattlePassPremiumReward(lv) then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "免广告直接领取!", 1.5, { 100, 255, 200 }, 18)
                        end
                    elseif sdk then
                        local capturedLv = lv
                        ShowAdSafe(SafeAdCallback(function(result)
                            if result.success then
                                ReportAdWatch()
                                if ClaimBattlePassPremiumReward(capturedLv) then
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "高级奖励已领取!", 1.5, { 255, 220, 100 }, 18)
                                end
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "广告播放失败", 1.5, { 255, 120, 80 }, 18)
                            end
                        end))
                    else
                        ReportAdWatch()
                        if ClaimBattlePassPremiumReward(lv) then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "高级奖励已领取!", 1.5, { 255, 220, 100 }, 18)
                        end
                    end
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 普通奖励领取（免费）
            for lv, rect in pairs(battlePassClaimFreeRects) do
                if HitRect(rect) then
                    if ClaimBattlePassFreeReward(lv) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "奖励已领取!", 1.5, { 120, 255, 180 }, 18)
                    end
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 横向拖拽滚动（奖励轨道）
            battlePassUIState.isDraggingReward = true
            battlePassUIState.dragStartX = dx
            battlePassUIState.dragStartScrollX = battlePassUIState.rewardScrollX
            return
        end

        -- Tab 2/3/4: 任务列表 - 领取按钮
        for _, btnInfo in ipairs(battlePassTaskBtnRects) do
            if HitRect(btnInfo) then
                ClaimBattlePassTaskReward(btnInfo.taskType, btnInfo.taskId)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 纵向拖拽滚动（任务列表）
        battlePassUIState.isDragging = true
        battlePassUIState.dragStartY = dy
        battlePassUIState.dragLastY = dy
        battlePassUIState.scrollVel = 0
        return
    end

    -- === 讨伐战界面输入 ===
    if gameState.phase == "ABYSS_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 预览弹窗
        if abyssState.showPreview then
            if abyssState.previewCloseRect and HitRect(abyssState.previewCloseRect) then
                abyssState.showPreview = false
                return
            end
            if abyssState.startBtnRect and HitRect(abyssState.startBtnRect) then
                -- 讨伐入场费：100玉壁
                local ABYSS_COST = 100
                if playerInfo.jade < ABYSS_COST then
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "玉壁不足! 需要" .. ABYSS_COST .. " 玉壁", 1.5, { 255, 80, 80 }, 18)
                    return
                end
                -- 扣除玉壁
                playerInfo.jade = playerInfo.jade - ABYSS_COST
                SaveGameProgress()

                -- 讨伐探索模式 (搜打撤)
                local fi = abyssState.selectedFloor
                abyssState.showPreview = false

                -- 随机地图大小 (4~8)
                local abyssGridSizes = {4, 5, 5, 6, 6, 7, 8}
                local gs = abyssGridSizes[fi] or math.random(4, 8)

                -- 将品及以上概率为普通探索的3倍
                local highTierMul = 3

                -- [EXPLORATION REMOVED] 探索模块已移除
                ShowToast("探索功能暂未开放")
                return
                --[=[ EXPLORATION REMOVED: 以下探索代码已注释

                -- 初始化探索模块
                if not Exploration.IsActive() then
                    Exploration.Init(vg, fontId, IMG)
                end
                SyncPlayerDataToExploration()

                Exploration.StartMap({
                    mode = "abyss",
                    abyssFloor = fi,
                    gridSize = gs,
                    enemyScale = abyssState.floors[fi] and abyssState.floors[fi].enemyScale or (1.8 + fi * 0.5),
                    maxTier = math.min(6, math.max(1, fi)),
                    dropSets = {1,2,3,4,5,6,7},
                    highTierMultiplier = highTierMul,
                    dropRateBonus = 0,
                })

                -- 设置回调 (与历劫共用 onComplete, 但标记为 abyss)
                Exploration.onStartBattle = function(enemyScale, maxTier, dropSets)
                    gameState.explorationMode = true
                    gameState.abyssFloor = fi
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
                    gameState.exploreBuff = buff
                    if buff then
                        if buff.type == "hp_bonus" then
                            gameState.playerBaseHP = BASE_HP_MAX + buff.value
                            gameState.playerBaseMax = BASE_HP_MAX + buff.value
                        end
                    end
                    -- 敌方部署
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
                    InitAISkills()  -- 讨伐模式启用AI技能
                    print("=== 讨伐探索战斗 第" .. fi .. "层 ===")
                end

                Exploration.onComplete = function(result)
                    if result then
                        if result.success then
                            playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                        end
                        local jadeReward = result.totalJade or 0
                        if exploreAdDoubleJade then
                            jadeReward = jadeReward * 2
                            exploreAdDoubleJade = false
                        end
                        result.totalJade = jadeReward
                        playerInfo.jade = playerInfo.jade + jadeReward
                        -- 按武技分配残片
                        if result.fragList then
                            for _, fItem in ipairs(result.fragList) do
                                skillFragments[fItem.skillIdx] = (skillFragments[fItem.skillIdx] or 0) + fItem.count
                            end
                        elseif (result.totalFrag or 0) > 0 then
                            for _ = 1, result.totalFrag do
                                local idx = math.random(1, #SKILL_TECHNIQUES)
                                skillFragments[idx] = (skillFragments[idx] or 0) + 1
                            end
                        end
                        local abEquipDrops = {}
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
                                    table.insert(abEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                                end
                            end
                        end
                        -- 显示装备掉落通知（含品质+装等）
                        for i, eqDrop in ipairs(abEquipDrops) do
                            local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "未知"
                            local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "未知"
                            local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                            local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255, 255, 255}
                            local qLabel = GetQualityLabel(eqDrop.quality or 0)
                            local eLv = eqDrop.level or 1
                            local dropMsg = "获得兵甲: " .. tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45 + (i - 1) * 30, dropMsg, 3.0, tc, 20)
                        end
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
                        local abRewardStr = "讨伐探索: +" .. (result.totalJade or 0) .. " 玉壁"
                        if result.fragList and #result.fragList > 0 then
                            local totalF = 0
                            for _, fItem in ipairs(result.fragList) do totalF = totalF + fItem.count end
                            abRewardStr = abRewardStr .. " +" .. totalF .. "武技残片"
                        end
                        if #abEquipDrops > 0 then
                            abRewardStr = abRewardStr .. " +" .. #abEquipDrops .. "件兵甲"
                        end
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, abRewardStr, 2.5, {180, 120, 255}, 22)
                    end
                    -- 战令: 探索完成
                    TrackBattlePassTask("bp_explore1", 1)
                    TrackBattlePassTask("bp_wexplore5", 1)
                    TrackBattlePassTask("bp_sexplore15", 1)
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

                -- 显示爆率信息
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                    "讨伐探索 " .. gs .. "×" .. gs .. " 将品↑概率×" .. highTierMul,
                    3.0, {180, 120, 255}, 20)

                PushPhase("EXPLORATION")
                PlaySFX(AUDIO.sfx_click)
                print("=== 讨伐探索 第" .. fi .. "层 " .. gs .. "×" .. gs .. " 将品↑概率×" .. highTierMul .. " ===")
                return
                --]=] -- END EXPLORATION REMOVED (ABYSS_SELECT)
            end
            return
        end

        -- 返回按钮
        if abyssState.backBtnRect and HitRect(abyssState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 关卡列表点击
        for i, rect in ipairs(abyssState.floorRects) do
            if rect and HitRect(rect) then
                local floor = abyssState.floors[i]
                if stageState.maxUnlocked >= floor.unlockStage then
                    abyssState.selectedFloor = i
                    abyssState.showPreview = true
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        return
    end

    -- === 个人资料界面输入 ===
    if gameState.phase == "TOWER_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 排行榜面板打开时，优先处理排行榜交互
        if towerState.showLeaderboard then
            if towerState.leaderboardBackRect and HitRect(towerState.leaderboardBackRect) then
                towerState.showLeaderboard = false
                PlaySFX(AUDIO.sfx_click)
            end
            return  -- 排行榜打开时吞噬所有点击
        end

        -- 预览弹窗（挑战确认）
        if towerState.showPreview then
            if towerState.startBtnRect and HitRect(towerState.startBtnRect) then
                -- 999层上限检查
                if towerState.currentFloor > 999 then
                    ShowToast("已达本赛季最高层(999层)，请等待下个赛季")
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                -- 爬塔战斗开始（无需门票）
                towerState.showPreview = false
                local fl = towerState.currentFloor
                gameState.towerFloor = fl  -- 标记爬塔模式
                gameState.phase = "BATTLE"
                gameState.battlePhase = "DEPLOY"
                gameState.playerBaseHP = BASE_HP_MAX
                gameState.enemyBaseHP = BASE_HP_MAX
                gameState.gold = GameConfig.INITIAL_GOLD
                gameState.totalKills = 0
                gameState.gameTime = 0
                gameState.battleTime = 0
                gameState.drawCount = 0
                gameState.goldTimer = 0
                gameState.resultTimer = 0
                gameState.autoMarch = false
                -- 阶级随层数递增 (每10层+1阶, 爬塔最高王品5阶)
                stageMaxTier = math.min(5, math.max(1, math.floor((fl - 1) / 10) + 1))
                for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                activeSkillEffects = {}
                skillTargeting.active = false
                for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                playerUnits = {}
                enemyUnits = {}
                inventory = {}
                RefreshShop()
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
                PlaySFX(AUDIO.sfx_click)
                print("=== 进入爬塔战斗 第" .. fl .. "层 ===")
                return
            end
            -- 关闭预览
            towerState.showPreview = false
            return
        end

        -- 返回按钮
        if towerState.backBtnRect and HitRect(towerState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 排行榜按钮
        if towerState.leaderboardBtnRect and HitRect(towerState.leaderboardBtnRect) then
            towerState.showLeaderboard = true
            if not towerState.rankLoaded then
                LoadTowerLeaderboard()
            end
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 点击主区域打开预览
        towerState.showPreview = true
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- === 排位赛界面输入 ===
    if gameState.phase == "RANKED_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 匹配中不允许其他操作
        if rankedState.isMatching then return end

        -- 排行榜弹窗
        if rankedState.showLeaderboard then
            -- 关闭排行榜
            if rankedState.backBtnRect and HitRect(rankedState.backBtnRect) then
                rankedState.showLeaderboard = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            return
        end

        -- 开始匹配按钮
        if rankedState.startBtnRect and HitRect(rankedState.startBtnRect) then
            rankedState.isMatching = true
            rankedState.matchAnim = 0
            rankedState.matchReady = false
            rankedState.opponentName = ""
            rankedState.opponentPower = 0
            rankedState.opponentCards = {}
            if rawget(_G, "IsNetworkMode") and IsNetworkMode() then
                local Client = _G._ClientNet
                local ok = Client.JoinRanked()
                if not ok then
                    rankedState.isMatching = false
                    if rawget(_G, "ShowToast") then ShowToast("排位服务器连接失败", 2.0) end
                    return
                end
            else
                rankedState.isMatching = false
                if rawget(_G, "ShowToast") then ShowToast("排位模式仅支持联机匹配", 2.0) end
                return
            end
            PlaySFX(AUDIO.sfx_click)
            print("=== 排位匹配开始 ===")
            return
        end

        -- 排行榜按钮
        if rankedState.rankBtnRect and HitRect(rankedState.rankBtnRect) then
            rankedState.showLeaderboard = true
            if not rankedState.rankLoaded then
                LoadRankedLeaderboard()
            end
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 返回按钮
        if rankedState.backBtnRect and HitRect(rankedState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        return
    end

    -- 探索战斗确认弹窗: 拦截所有点击 (退出/死亡)
    if gameState.exploreExitConfirm then
        local ddx, ddy = ScreenToDesign(sx, sy)
        local function HitECR(r)
            return r and ddx >= r.x and ddx <= r.x + r.w and ddy >= r.y and ddy <= r.y + r.h
        end

        -- 广告翻倍玉壁按钮
        if HitECR(exploreConfirmBtnRects.adDouble) then
            PlaySFX(AUDIO.sfx_click)
            if not exploreAdDoubleJade then
                if playerInfo.ad_free then
                    exploreAdDoubleJade = true
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "免广告翻倍!", 1.5, { 100, 255, 200 }, 18)
                    print("[探索] [免广告] 翻倍玉壁已激活")
                elseif sdk then
                    ShowAdSafe(SafeAdCallback(function(result)
                        if result.success then
                            exploreAdDoubleJade = true
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "玉壁将翻倍!", 1.5, { 120, 255, 180 }, 18)
                            ReportAdWatch()
                            print("[探索] 广告翻倍玉壁已激活")
                        end
                    end))
                else
                    exploreAdDoubleJade = true
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "[DEV] 玉壁将翻倍!", 1.5, { 120, 255, 180 }, 18)
                    ReportAdWatch()
                    print("[探索] [DEV] 广告翻倍玉壁已激活")
                end
            end
            return
        end

        -- 确认按钮
        if HitECR(exploreConfirmBtnRects.confirm) then
            PlaySFX(AUDIO.sfx_click)
            if gameState.exploreExitConfirm.type == "abyss_exit" then
                -- 讨伐战退出: 保留30%收获, 返回讨伐战页面
                gameState.exploreExitConfirm = nil
                -- Exploration.ForceAbandonWithRetain(0.3)  -- 30%淇濈暀 [EXPLORATION REMOVED]
                gameState.explorationMode = false
                gameState.noFullAuto = false
                gameState.abyssFloor = nil
                PopPhase("ABYSS_SELECT")
                abyssState.showPreview = false
                phaseChangeCooldown = 0.3
                SaveGameProgress()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "讨伐撤退 (保留30%收获)", 2.0, { 255, 200, 100 }, 18)
                print("[讨伐] 中途退出, 保留30%收获, 返回讨伐战页面")
            else
                -- 探索战斗退出: 回到探索地图 (丢失10%-30%已有战利品) [EXPLORATION REMOVED]
                gameState.exploreExitConfirm = nil
                -- Exploration.OnBattleReturn(false)  -- [EXPLORATION REMOVED]
                -- local lostCount = Exploration.GetState().lastBattleLostCount or 0
                -- if lostCount > 0 then
                --     AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "丢失了 " .. lostCount .. " 件战利品", 2.0, { 255, 120, 80 }, 18)
                -- end
                gameState.explorationMode = false
                gameState.phase = "MENU"  -- 探索已移除, 直接回主菜单
                phaseChangeCooldown = 0.3
                print("[探索] 探索模块已移除, 返回主菜单")
            end
            return
        end

        -- 名字选择 (含自定义选项)
        if gameState.exploreExitConfirm.type == "death"
           and HitECR(exploreConfirmBtnRects.revive) then
            PlaySFX(AUDIO.sfx_click)
            -- 复活成功的通用处理
            local function doRevive()
                -- Exploration.OnBattleReturn(false)  -- [EXPLORATION REMOVED]
                gameState.explorationMode = false
                gameState.exploreExitConfirm = nil
                gameState.phase = "MENU"  -- 探索已移除, 直接回主菜单
                phaseChangeCooldown = 0.3
            end
            if playerInfo.ad_free then
                doRevive()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "免广告复活成功!", 1.5, { 100, 255, 200 }, 18)
                print("[探索] [免广告] 复活, 返回探索地图")
            elseif sdk then
                ShowAdSafe(SafeAdCallback(function(result)
                    if result.success then
                        doRevive()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "复活成功! 继续探索", 1.5, { 120, 255, 180 }, 18)
                        ReportAdWatch()
                print("[探索] 探索模块已移除, 返回主菜单")
                    end
                end))
            else
                -- DEV模式: 模拟广告成功
                doRevive()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "[DEV] 复活成功!", 1.5, { 120, 255, 180 }, 18)
                ReportAdWatch()
                print("[探索] [DEV] 广告复活, 返回探索地图")
            end
            return
        end

        return  -- 弹窗显示时拦截所有其他点击
    end

        if gameState.phase == "WIN" or gameState.phase == "LOSE" then
        if gameState.phase == "WIN" then
            -- WIN: 奖励弹窗流程
            if gameState.showRewardPopup then
                -- 弹窗已显示, 响应确认按钮和广告翻倍按钮
                local ddx, ddy = ScreenToDesign(sx, sy)
                -- 广告翻倍按钮
                if rewardAdDoubleRect then
                    local r = rewardAdDoubleRect
                    if ddx >= r.x and ddx <= r.x + r.w and ddy >= r.y and ddy <= r.y + r.h then
                        WatchAdForDoubleReward()
                        return
                    end
                end
                -- 奖励列表拖拽滚动初始化
                gameState.rewardDragging = true
                gameState.rewardLastTouchY = ddy
                gameState.rewardVel = 0
                -- 确认按钮
                if rewardPopupConfirmRect then
                    local r = rewardPopupConfirmRect
                    if ddx >= r.x and ddx <= r.x + r.w and ddy >= r.y and ddy <= r.y + r.h then
                        gameState.showRewardPopup = false
                        rewardPopupConfirmRect = nil
                        rewardAdDoubleRect = nil
                        if gameState.isRanked then
                            gameState.phase = "RANKED_SELECT"
                            gameState.isRanked = false
                            gameState.rankedDelta = nil
                            rankedState.showPreview = false
                        elseif gameState.abyssFloor then
                            gameState.phase = "ABYSS_SELECT"
                            abyssState.showPreview = false
                            gameState.abyssFloor = nil
                        elseif gameState.towerFloor then
                            gameState.phase = "TOWER_SELECT"
                            towerState.showPreview = false
                            gameState.towerFloor = nil
                        elseif gameState.isQuickBattle then
                            gameState.phase = "MENU"
                            gameState.isQuickBattle = false
                            gameState.useTacticsMode = false
                        elseif gameState.worldMapBattle then
                            gameState.phase = "WORLD_MAP"
                            gameState.worldMapBattle = nil
                            gameState.useTacticsMode = false
                            gameState.retreatPursued = nil
                            gameState.retreatPopup = nil
                            gameState.enemyRetreatPopup = nil
                            gameState.enemyRetreatTriggered = nil
                            gameState.enemyRetreatedSuccess = nil
                            gameState.pursuitResultPopup = nil
                            gameState.enemyRetreatCheckCD = nil
                            if WorldMap and WorldMap.ActivatePendingPlayerAnim then
                                WorldMap.ActivatePendingPlayerAnim()
                            end
                        else
                            gameState.phase = "MENU"
                        end
                        phaseChangeCooldown = 0.3
                        print("=== 奖励确认, 返回 ===")
                    end
                end
            end
            -- 弹窗未弹出时不响应点击
            return
        end
        -- LOSE: 原有逻辑
        if gameState.resultTimer > 1.5 then
            -- 探索模式: 弹出死亡确认弹窗 (确认放弃 / 看广告复活) [EXPLORATION REMOVED]
            -- explorationMode is always false since exploration module was removed
            -- if gameState.explorationMode then
            --     if not gameState.exploreExitConfirm then
            --         gameState.exploreExitConfirm = { type = gameState.abyssFloor and "abyss_exit" or "death" }
            --     end
            --     -- 弹窗按钮点击在下方统一处理
            --     return
            -- end
            adRects.revive = nil
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "再接再厉!", 2.0, { 200, 160, 100 }, 20)
            if gameState.isRanked then
                gameState.phase = "RANKED_SELECT"
                gameState.isRanked = false
                gameState.rankedDelta = nil
                rankedState.showPreview = false
            elseif gameState.abyssFloor then
                gameState.phase = "ABYSS_SELECT"
                abyssState.showPreview = false
                gameState.abyssFloor = nil
            elseif gameState.towerFloor then
                gameState.phase = "TOWER_SELECT"
                towerState.showPreview = false
                gameState.towerFloor = nil
            elseif gameState.isQuickBattle then
                gameState.phase = "MENU"
                gameState.isQuickBattle = false
                gameState.useTacticsMode = false
            elseif gameState.worldMapBattle then
                gameState.phase = "WORLD_MAP"
                gameState.worldMapBattle = nil
                gameState.useTacticsMode = false
                gameState.retreatPursued = nil
                gameState.retreatPopup = nil
                gameState.enemyRetreatPopup = nil
                gameState.enemyRetreatTriggered = nil
                gameState.enemyRetreatedSuccess = nil
                gameState.pursuitResultPopup = nil
                gameState.enemyRetreatCheckCD = nil
                if WorldMap and WorldMap.ActivatePendingPlayerAnim then
                    WorldMap.ActivatePendingPlayerAnim()
                end
            else
                gameState.phase = "MENU"
            end
            phaseChangeCooldown = 0.3
            print("=== 杩斿洖 ===")
        end
        return
    end

    -- (已移除武技详情弹窗)

    -- 战斗规则弹窗: 拦截所有点击，支持滚动
    if battleRulesState.show then
        local cr = battleRulesState.closeBtnRect
        if cr and dx >= cr.x and dx <= cr.x + cr.w and dy >= cr.y and dy <= cr.y + cr.h then
            battleRulesState.show = false
            battleRulesState.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 面板区域内开始拖拽滚动
        local pr = battleRulesState.panelRect
        if pr and dx >= pr.x and dx <= pr.x + pr.w and dy >= pr.y and dy <= pr.y + pr.h then
            battleRulesState.isDragging = true
            battleRulesState.lastTouchY = dy
            battleRulesState.vel = 0
        else
            -- 点击弹窗外关闭
            battleRulesState.show = false
            battleRulesState.isDragging = false
        end
        return
    end

        -- 名字选择 (含自定义选项)
    local function HitDesignRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    -- === 敌方撤退弹窗交互: 追击 / 放行 ===
    if gameState.enemyRetreatPopup then
        if HitDesignRect(gameState.btn_enemyRetreatPursue) then
            -- 玩家选择追击
            local pursueSuccess = math.random() < 0.60
            gameState.enemyRetreatPopup = nil
            gameState.btn_enemyRetreatPursue = nil
            gameState.btn_enemyRetreatLetGo = nil
            if pursueSuccess then
                -- 追击成功: 敌方溃不成军, 战力-50%, 战斗继续
                for _, u in ipairs(enemyUnits) do
                    u.routDebuff = true
                end
                gameState.pursuitResultPopup = {
                    msg = "追击成功! 敌军溃不成军, 战力-50%!",
                    timer = 3.0, success = true,
                }
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                    "敌军溃不成军!", 2.0, { 80, 255, 120 }, 24)
            else
                -- 追击失败: 敌方成功撤退, 战斗结束(玩家胜利)
                gameState.pursuitResultPopup = {
                    msg = "追击失败! 敌军成功撤退!",
                    timer = 3.0, success = false,
                }
                gameState.enemyRetreatedSuccess = true
                -- 敌方撤退视同玩家胜利
                gameState.phase = "WIN"
                gameState.resultTimer = 0
                gameState.winJade = 0
                gameState.winExp = GameConfig.EXP_PER_WIN
                playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_WIN
                CheckPlayerLevelUp()
                OnBattleVictory()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                    "敌军撤退, 我军获胜!", 2.0, { 255, 220, 80 }, 24)
                PlaySFX(AUDIO.sfx_win)
            end
            PlaySFX(AUDIO.sfx_click)
            return
        elseif HitDesignRect(gameState.btn_enemyRetreatLetGo) then
            -- 玩家选择放行: 敌方成功撤退, 战斗结束(玩家胜利)
            gameState.enemyRetreatPopup = nil
            gameState.btn_enemyRetreatPursue = nil
            gameState.btn_enemyRetreatLetGo = nil
            gameState.enemyRetreatedSuccess = true
            gameState.phase = "WIN"
            gameState.resultTimer = 0
            gameState.winJade = 0
            gameState.winExp = GameConfig.EXP_PER_WIN
            playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_WIN
            CheckPlayerLevelUp()
            OnBattleVictory()
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                "放行敌军, 我军获胜!", 2.0, { 255, 220, 80 }, 24)
            PlaySFX(AUDIO.sfx_win)
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 弹窗期间吞掉其他点击
        return
    end

    -- ========================================================================
    -- 战旗回合制 (TACTICS) 输入处理
    -- ========================================================================
    if gameState.battlePhase == "TACTICS" and tacticState then
        local TacticsModule = require("systems.battle.tactics")

        -- 动画播放中不响应输入
        if tacticState.animType then return true end

        -- 战旗操作按钮: 移动
        if tacticBtnMove and HitDesignRect(tacticBtnMove) then
            TacticsModule.HandleMoveBtn()
            PlaySFX(AUDIO.sfx_click)
            return true
        end
        -- 战旗操作按钮: 攻击
        if tacticBtnAttack and HitDesignRect(tacticBtnAttack) then
            TacticsModule.HandleAttackBtn()
            PlaySFX(AUDIO.sfx_click)
            return true
        end
        -- 战旗操作按钮: 待机
        if tacticBtnWait and HitDesignRect(tacticBtnWait) then
            TacticsModule.HandleWait()
            PlaySFX(AUDIO.sfx_click)
            return true
        end
        -- 战旗操作按钮: 结束回合
        if tacticBtnEnd and HitDesignRect(tacticBtnEnd) then
            TacticsModule.HandleEndTurn()
            PlaySFX(AUDIO.sfx_click)
            return true
        end

        -- 撤退按钮 (战旗模式下也通过 battleBackBtnRect 处理, 跳到下方统一逻辑)
        if HitDesignRect(battleBackBtnRect) then
            -- 战旗模式撤退: 直接返回
            if gameState.worldMapBattle then
                gameState.retreated = true
                local retreatExp = math.max(1, math.floor(GameConfig.EXP_PER_WIN * 0.3))
                playerInfo.exp = playerInfo.exp + retreatExp
                CheckPlayerLevelUp()
                playerInfo.totalBattles = (playerInfo.totalBattles or 0) + 1
                TrackDailyTask("battle3", 1)
                TrackWeeklyTask("wbattle15", 1)
                TrackBattlePassTask("bp_battle3", 1)
                TrackBattlePassTask("bp_wbattle20", 1)
                TrackBattlePassTask("bp_sbattle100", 1)
                WorldMap.OnBattleResult(false)
                SaveGameProgress()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "鸣金收兵!", 1.5, { 255, 200, 100 }, 24)
                gameState.battlePhase = "RESULT"
                gameState.battleResult = "LOSE"
                if OnBattleDefeat then OnBattleDefeat() end
            elseif gameState.towerFloor then
                PopPhase("TOWER_SELECT")
                towerState.showPreview = false
                gameState.towerFloor = nil
            elseif gameState.abyssFloor then
                PopPhase("ABYSS_SELECT")
                abyssState.showPreview = false
                gameState.abyssFloor = nil
            elseif gameState.isRanked then
                PopPhase("RANKED_SELECT")
                gameState.isRanked = false
                rankedState.showPreview = false
            elseif gameState.isQuickBattle then
                PopPhase("MENU")
                gameState.isQuickBattle = false
            else
                PopPhase("MENU")
            end
            gameState.useTacticsMode = false
            phaseChangeCooldown = 0.3
            for _, slot in ipairs(PLAYER_SLOTS) do slot.filled = false; slot.card = nil end
            playerUnits = {}
            enemyUnits = {}
            PlaySFX(AUDIO.sfx_click)
            print("=== 战旗模式撤退 ===")
            return true
        end

        -- 网格点击: 选中/移动/攻击
        if tacticState.isPlayerTurn then
            local row, col = TacticsModule.ScreenToGrid(dx, dy)
            if row and col then
                TacticsModule.HandleTap(row, col)
                PlaySFX(AUDIO.sfx_click)
                return true
            end
        end

        return true  -- 战旗模式吞掉所有未匹配的点击
    end

    ---------------------------------------------------------------------------
    -- 回合制(TB)模式输入 --------------------------------------------------------
    ---------------------------------------------------------------------------
    if gameState.battlePhase == "FIGHT" and rawget(_G, "tbState") then
        local TBModule = require("systems.battle.turnbased")

        -- 动画中屏蔽所有输入
        if tbState.animState ~= "idle" then return true end

        -- [结束回合] 按钮
        if rawget(_G, "tbBtnEndTurn") and HitDesignRect(tbBtnEndTurn) then
            if tbState.isPlayerTurn and not tbState.battleOver then
                TBModule.EndTurn()
                PlaySFX(AUDIO.sfx_click)
            end
            return true
        end

        -- 技能按钮
        if rawget(_G, "tbSkillBtnRects") then
            for _, rect in ipairs(tbSkillBtnRects) do
                if HitDesignRect(rect) then
                    if tbState.isPlayerTurn and not tbState.battleOver and rect.regIdx then
                        TBModule.UseHeroSkill(rect.regIdx)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return true
                end
            end
        end

        -- [自动战斗] 按钮
        if rawget(_G, "tbAutoBattleBtnRect") and HitDesignRect(tbAutoBattleBtnRect) then
            gameSettings.tbAutoBattle = not gameSettings.tbAutoBattle
            SaveSettings()
            PlaySFX(AUDIO.sfx_click)
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
                gameSettings.tbAutoBattle and "自动战斗 已开启" or "自动战斗 已关闭",
                0.8, gameSettings.tbAutoBattle and {80, 255, 140} or {255, 180, 60}, 14)
            return true
        end

        -- [撤退] 按钮 (复用 battleBackBtnRect)
        if HitDesignRect(battleBackBtnRect) then
            tbState.battleOver = true
            tbState.winner = "enemy"
            gameState.battlePhase = "RESULT"
            gameState.playerWon = false
            PlaySFX(AUDIO.sfx_click)
            return true
        end

        -- 网格点击 → 选择 / 移动 / 攻击
        TBModule.HandleClick(dx, dy)
        PlaySFX(AUDIO.sfx_click)
        return true  -- 回合制模式吞掉所有未匹配的点击
    end

    if HitDesignRect(battleBackBtnRect) then
        -- [EXPLORATION REMOVED] explorationMode is always false, removed two branches
        -- if gameState.explorationMode and gameState.abyssFloor then
        --     gameState.exploreExitConfirm = { type = "abyss_exit" }
        --     PlaySFX(AUDIO.sfx_click)
        --     return
        -- elseif gameState.explorationMode then
        --     gameState.exploreExitConfirm = { type = "exit" }
        --     PlaySFX(AUDIO.sfx_click)
        --     return
        if gameState.isRanked then
            -- 排位中途退出 = 判负扣分
            local shouldLeaveRankedBattle = true
            if IsServerAuthoritativeRankedMode and IsServerAuthoritativeRankedMode() then
                gameState.awaitingRankedResult = true
                gameState.rankedDelta = nil
                local Client = _G._ClientNet
                local ok = Client.ForfeitRanked()
                if not ok then
                    gameState.awaitingRankedResult = false
                    shouldLeaveRankedBattle = false
                else
                    SaveGameProgress()
                end
            elseif rankedState.score > 0 then
                rankedState.losses = rankedState.losses + 1
                if rankedState.streak > 0 then rankedState.streak = 0 end
                rankedState.streak = rankedState.streak - 1
                local delta = CalcRankedScoreChange(false, rankedState.streak)
                rankedState.score = math.max(0, rankedState.score + delta)
                ReportRankedScore()
                -- 网络模式: 通知服务端弃权
                SaveGameProgress()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "退出判负 " .. delta .. "分", 2.0, { 255, 100, 80 }, 18)
            end
            if shouldLeaveRankedBattle then
                PopPhase("RANKED_SELECT")
                gameState.isRanked = false
                gameState.rankedDelta = nil
                rankedState.showPreview = false
            end
        elseif gameState.abyssFloor then
            PopPhase("ABYSS_SELECT")
            abyssState.showPreview = false
            gameState.abyssFloor = nil
        elseif gameState.towerFloor then
            PopPhase("TOWER_SELECT")
            towerState.showPreview = false
            gameState.towerFloor = nil
        else
            if gameState.battlePhase == "FIGHT" then
                if gameState.worldMapBattle then
                    -- === SLG战斗撤退: AI决定是否追击 ===
                    local pursueChance = 0.60
                    if math.random() < pursueChance then
                        -- AI选择追击 -> 溃不成军, 战力-50%, 战斗继续
                        gameState.retreatPursued = true
                        for _, u in ipairs(playerUnits) do
                            u.routDebuff = true
                        end
                        gameState.retreatPopup = {
                            type = "player_pursued",
                            msg = "敌军发起追击! 我军溃不成军, 战力下降50%!",
                            timer = 3.0,
                        }
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                            "撤退失败! 敌军追击!", 2.0, { 255, 80, 80 }, 24)
                        PlaySFX(AUDIO.sfx_lose)
                    else
                        -- AI放弃追击 -> 成功撤退, 存活兵力回城
                        gameState.retreated = true
                        local retreatExp = math.max(1, math.floor(GameConfig.EXP_PER_WIN * 0.3))
                        playerInfo.exp = playerInfo.exp + retreatExp
                        CheckPlayerLevelUp()
                        playerInfo.totalBattles = (playerInfo.totalBattles or 0) + 1
                        TrackDailyTask("battle3", 1)
                        TrackWeeklyTask("wbattle15", 1)
                        TrackBattlePassTask("bp_battle3", 1)
                        TrackBattlePassTask("bp_wbattle20", 1)
                        TrackBattlePassTask("bp_sbattle100", 1)
                        WorldMap.OnBattleResult(false)
                        SaveGameProgress()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                            "鸣金收兵!", 1.5, { 255, 200, 100 }, 24)
                        gameState.battlePhase = "RESULT"
                        gameState.battleResult = "LOSE"
                        if OnBattleDefeat then OnBattleDefeat() end
                    end
                else
                    -- === 非SLG战斗: 原有撤退逻辑 ===
                    gameState.retreated = true
                    local retreatExp = math.max(1, math.floor(GameConfig.EXP_PER_WIN * 0.3))
                    playerInfo.exp = playerInfo.exp + retreatExp
                    CheckPlayerLevelUp()
                    playerInfo.totalBattles = (playerInfo.totalBattles or 0) + 1
                    TrackDailyTask("battle3", 1)
                    TrackWeeklyTask("wbattle15", 1)
                    TrackBattlePassTask("bp_battle3", 1)
                    TrackBattlePassTask("bp_wbattle20", 1)
                    TrackBattlePassTask("bp_sbattle100", 1)
                    SaveGameProgress()
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                        "鸣金收兵!", 1.5, { 255, 200, 100 }, 18)
                    gameState.battlePhase = "RESULT"
                    gameState.battleResult = "LOSE"
                    if OnBattleDefeat then OnBattleDefeat() end
                end
                phaseChangeCooldown = 0.3
                PlaySFX(AUDIO.sfx_click)
                return  -- 不清理units，结果界面需要计算存活率
            else
                -- DEPLOY阶段退出: 未开战，直接返回
                PopPhase("MENU")
            end
        end
        phaseChangeCooldown = 0.3
        -- 清理战斗状态
        for _, slot in ipairs(PLAYER_SLOTS) do
            slot.filled = false; slot.card = nil
        end
        playerUnits = {}
        enemyUnits = {}
        print("=== 战斗中返回首页 ===")
        return
    end

            -- 打开仓库弹窗 (显示当前选中英雄的第一个可用孔位, 或全部)
    -- 换战场按钮 (普通战斗, 非讨伐/爬塔, 设计坐标)
    if not gameState.abyssFloor and not gameState.towerFloor and not gameState.isRanked and battleChangeBgBtnRect then
        local r = battleChangeBgBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            local newIdx = (currentLayoutIdx % #BATTLE_LAYOUTS) + 1
            ApplyBattleLayout(newIdx)
            local layoutName = BATTLE_LAYOUTS[newIdx] and BATTLE_LAYOUTS[newIdx].name or "默认"
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, layoutName, 1.0, { 180, 220, 255 }, 18)
            PlaySFX(AUDIO.sfx_click)
            print("=== 切换战场背景: " .. newIdx .. " " .. layoutName .. " ===")
            return
        end
    end

    -- 兵种位置交换 (DEPLOY 阶段, 点击战场上的兵种单位)
    if gameState.battlePhase == "DEPLOY" then
        -- 检测点击了哪个兵种 (在战场区域内找最近的己方单位)
        local inBattleArea = bdx >= BATTLE_ZONE.left and bdx <= BATTLE_ZONE.right
            and bdy >= BATTLE_ZONE.top and bdy <= BATTLE_ZONE.bottom
        if inBattleArea and #playerUnits > 0 then
            local nearDist = 30  -- 点击检测半径
            local nearTroop = nil
            for _, u in ipairs(playerUnits) do
                if u.alive then
                    local udx = bdx - u.x
                    local udy = bdy - u.y
                    local d = math.sqrt(udx * udx + udy * udy)
                    if d < nearDist then
                        nearDist = d
                        local bt = (u.unitClass and u.unitClass.baseTroop) or "infantry"
                        nearTroop = bt
                    end
                end
            end
            if nearTroop then
                if not deploySwapFirstTroop then
                    -- 第一次点击: 选中该兵种
                    deploySwapFirstTroop = nearTroop
                    local TROOP_NAMES = { infantry = "步兵", archer = "弓兵", cavalry = "骑兵", spear = "枪兵" }
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45,
                        "已选中 " .. (TROOP_NAMES[nearTroop] or nearTroop) .. " (点击另一兵种交换)",
                        1.2, { 120, 220, 255 }, 16)
                    PlaySFX(AUDIO.sfx_click)
                    return
                elseif nearTroop == deploySwapFirstTroop then
                    -- 点击同一兵种: 取消选中
                    deploySwapFirstTroop = nil
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "取消选择", 0.8, { 180, 170, 160 }, 16)
                    PlaySFX(AUDIO.sfx_click)
                    return
                else
                    -- 点击不同兵种: 执行交换
                    SwapDeployTroopZones(deploySwapFirstTroop, nearTroop)
                    deploySwapFirstTroop = nil
                    return
                end
            end
        end
    end

    -- 车道指示器点击 (仅 DEPLOY 阶段, 点击循环切换 1~5 路)
    if gameState.battlePhase == "DEPLOY" then
        for _, slot in ipairs(PLAYER_SLOTS) do
            if slot.filled and slot.card and slot.laneBadgeRect then
                local r = slot.laneBadgeRect
                if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                    local cur = slot.deployLane or 1
                    local next = cur % NUM_LANES + 1
                    slot.deployLane = next
                    local laneColors = {
                        { 80, 180, 255 }, { 100, 220, 120 }, { 255, 210, 60 },
                        { 255, 150, 60 }, { 220, 100, 180 },
                    }
                    local lc = laneColors[next] or { 200, 180, 160 }
                    AddFloatText(slot.cx, slot.cy + 30, next .. "路", 0.8, lc, 18)
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
        end
    end

    -- 阵型切换按钮 (仅 DEPLOY 阶段, 设计坐标)
    if gameState.battlePhase == "DEPLOY" and deployFormationBtnRects then
        for formId, rect in pairs(deployFormationBtnRects) do
            if dx >= rect.x and dx <= rect.x + rect.w and dy >= rect.y and dy <= rect.y + rect.h then
                if formId ~= deploySelectedFormation then
                    SwitchDeployFormation(formId)
                end
                return
            end
        end
    end

    -- 开战/出征按钮 (SHOP或DEPLOY阶段可用, 设计坐标)
    if HitFightButton(dx, dy) then
        if gameState.battlePhase == "DEPLOY" then
            -- DEPLOY阶段: 兵力已预生成, 点击出征解冻开战
            StartBattleFromDeploy()
            -- 新手出兵策略提示 (仅首次)
            if not gameSettings.shownMarchHint then
                gameSettings.shownMarchHint = true
                ShowToast("提示: 自动行军已开启，长按行军按钮可切换出兵策略", 4.0)
            end
            gameSettings.battleCount = (gameSettings.battleCount or 0) + 1
            SaveSettings()
            print("=== 出征! (DEPLOY→FIGHT) ===")

        end
        return
    end

    -- 刷新按钮 (SHOP和FIGHT阶段都可用, 设计坐标)
    if shopRefreshBtnRect then
        local r = shopRefreshBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            if gameState.gold >= GameConfig.REFRESH_COST then
                gameState.gold = gameState.gold - GameConfig.REFRESH_COST
                RefreshShop()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "-" .. GameConfig.REFRESH_COST .. " 刷新", 1.0, { 180, 200, 255 }, 18)
            else
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.6, "军资不足!", 1.2, { 255, 100, 100 }, 18)
            end
            return
        end
    end
    -- 倍速按钮点击
    if battleSpeedBtnRect then
        local r = battleSpeedBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            -- 循环切换: 1 → 2 → 3 → 5 → 10 → 1
            local SPEED_CYCLE = { 1, 2, 3, 5, 10 }
            local spd = gameState.battleSpeed or 1
            local nextIdx = 1
            for i, v in ipairs(SPEED_CYCLE) do
                if v == spd then nextIdx = (i % #SPEED_CYCLE) + 1; break end
            end
            gameState.battleSpeed = SPEED_CYCLE[nextIdx]
            local spdLabel = "脳" .. tostring(gameState.battleSpeed)
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "倍速 " .. spdLabel, 1.0, { 255, 220, 80 }, 18)
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- 自动战斗按钮点击
    if autoBattleBtnRect then
        local r = autoBattleBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            if gameState.noFullAuto then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "副本模式禁用全自动", 1.5, { 255, 140, 100 }, 18)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            gameState.autoBattle = not gameState.autoBattle
            autoBattleTimer = 0
            local txt = gameState.autoBattle and "自动战斗 开启" or "自动战斗 关闭"
            local clr = gameState.autoBattle and { 120, 255, 160 } or { 200, 180, 160 }
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, txt, 1.2, clr, 18)
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- [已移除] 旧的武将头像行为模式切换和全局行为指令按钮
    -- 新机制: 通过底部兵种按钮选择兵种 → 点击战场下达移动/进攻指令

    -- 兵种选择按钮点击 (FIGHT阶段)
    if gameState.battlePhase == "FIGHT" and troopBtnRects then
        for troopKey, r in pairs(troopBtnRects) do
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                local tt = TROOP_TYPES[troopKey]
                if gameState.selectedTroopType == troopKey then
                    -- 再次点击取消选择
                    gameState.selectedTroopType = nil
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "取消选择", 0.8, { 200, 180, 160 }, 18)
                else
                    gameState.selectedTroopType = troopKey
                    -- 统计该兵种活着的单位数
                    local cnt = 0
                    for _, u in ipairs(playerUnits) do
                        if u.alive and u.troopType == troopKey then cnt = cnt + 1 end
                    end
                    local c = tt.color
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45,
                        tt.name .. " 已选(" .. cnt .. "人)", 1.0, { c[1], c[2], c[3] }, 18)
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
    end

    -- 战场点击: 已选兵种时点击战场下达移动/进攻指令
    -- 使用 bdx/bdy (战场设计坐标, 已考虑缩放/平移)
    if gameState.battlePhase == "FIGHT" and gameState.selectedTroopType then
        -- 检查点击是否在战场区域内 (排除UI按钮区域)
        local inBattleZone = bdx >= BATTLE_ZONE.left and bdx <= BATTLE_ZONE.right
            and bdy >= BATTLE_ZONE.top and bdy <= BATTLE_ZONE.bottom
        if inBattleZone then
            -- 检查点击位置附近是否有敌军 → 进攻指令; 否则 → 移动指令
            local nearEnemy = nil
            local nearDist = 60  -- 60px范围内视为点击敌人
            for _, e in ipairs(enemyUnits) do
                if e.alive then
                    local edx, edy = e.x - bdx, e.y - bdy
                    local ed = math.sqrt(edx * edx + edy * edy)
                    if ed < nearDist then
                        nearDist = ed
                        nearEnemy = e
                    end
                end
            end

            gameState.troopOrders = gameState.troopOrders or {}
            local tk = gameState.selectedTroopType
            if nearEnemy then
                -- 进攻指令: 朝敌人位置集结进攻
                gameState.troopOrders[tk] = {
                    type = "attack",
                    x = nearEnemy.x, y = nearEnemy.y,
                    time = gameState.gameTime,
                }
                local tt = TROOP_TYPES[tk]
                AddFloatText(bdx, bdy - 20, tt.name .. " 进攻!", 1.0, { 255, 100, 60 }, 18)
            else
                -- 移动指令: 朝点击位置集结
                gameState.troopOrders[tk] = {
                    type = "move",
                    x = bdx, y = bdy,
                    time = gameState.gameTime,
                }
                local tt = TROOP_TYPES[tk]
                AddFloatText(bdx, bdy - 20, tt.name .. " 集结", 1.0, { 60, 200, 255 }, 18)
            end

            -- 添加集结点视觉标记
            gameState.rallyMarkers = gameState.rallyMarkers or {}
            table.insert(gameState.rallyMarkers, {
                x = gameState.troopOrders[tk].x,
                y = gameState.troopOrders[tk].y,
                troopType = tk,
                time = gameState.gameTime,
                duration = 3.0,  -- 显示3秒
                isAttack = (nearEnemy ~= nil),
            })

            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- 规则按钮点击 (FIGHT阶段)
    if battleRuleBtnRect then
        local r = battleRuleBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            battleRulesState.show = true
            battleRulesState.scrollY = 0
            battleRulesState.vel = 0
            battleRulesState.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- 策略选项条点击 (show=true时优先检测)
    if strategyWheelState.show and autoMarchBtnRect then
        local ab = autoMarchBtnRect
        local cardW, cardH, gap2 = 115, 64, 8
        local sX = ab.cx - ab.r - 12
        local cCY = ab.cy - ab.r - cardH / 2 - 16
        local hitCard = 0
        for i = 1, #MARCH_STRATEGIES do
            local cRight = sX - (i - 1) * (cardW + gap2)
            local cLeft = cRight - cardW
            local cTop = cCY - cardH / 2
            local cBot = cCY + cardH / 2
            if dx >= cLeft and dx <= cRight and dy >= cTop and dy <= cBot then
                hitCard = i
                break
            end
        end
        if hitCard > 0 then
            local st = MARCH_STRATEGIES[hitCard]
            gameState.autoMarchStrategy = st.id
            gameState.autoMarch = true
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "绛栫暐: " .. st.name, 1.2, st.color, 18)
            PlaySFX(AUDIO.sfx_march)
        end
        strategyWheelState.show = false
        strategyWheelState.selected = 0
        return
    end
    -- 自动行军按钮 (FIGHT阶段, 圆形碰撞检测, 支持长按弹出策略选项)
    if autoMarchBtnRect and autoMarchBtnRect.isCircle then
        local ab = autoMarchBtnRect
        local ddx, ddy = dx - ab.cx, dy - ab.cy
        if ddx * ddx + ddy * ddy <= ab.r * ab.r then
            -- 记录按下，等release时判断是短按toggle还是长按选策略
            strategyWheelState.pressing = true
            strategyWheelState.startTime = gameState.gameTime
            strategyWheelState.touchId = touchId
            strategyWheelState.sx = sx
            strategyWheelState.sy = sy
            strategyWheelState.selected = 0
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end

    -- 武技技能圈已移除 (武技改为全自动释放)

    -- 商店卡牌 >> 拖拽放置 (DEPLOY和FIGHT阶段均可)
    if gameState.battlePhase == "DEPLOY" or gameState.battlePhase == "FIGHT" then
        local shopIdx, shopItem = HitShopCard(lx, ly)
        if shopIdx > 0 and shopItem then
            -- 检查军资够不够
            if gameState.gold < shopItem.cost then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.6, "军资不足!", 1.2, { 255, 100, 100 }, 18)
                return
            end
            -- 扣除军资, 标记已售, 开始拖拽
            gameState.gold = gameState.gold - shopItem.cost
            shopItem.sold = true
            local cardData = DeepCopy(HERO_CARDS[shopItem.cardIdx])
            cardData.cardIdx = shopItem.cardIdx
            cardData.constellation = shopItem.constellation or 0
            cardData.level = 1
            dragState.active = true
            dragState.card = cardData
            dragState.fromShop = true
            dragState.shopIdx = shopIdx
            dragState.fromInventory = false
            dragState.fromSlot = false
            dragState.lx = lx
            dragState.ly = ly
            dragState.touchId = touchId
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "-" .. shopItem.cost .. " 军资 - 拖至石台放置", 1.2, { 255, 180, 80 }, 18)
            return
        end
    end

    -- 战斗地图拖拽平移 (缩放>1时, 空白区域)
    if gameState.phase == "BATTLE" and battleZoom > 1.0 then
        local inBZ = bdx >= BATTLE_ZONE.left - 30 and bdx <= BATTLE_ZONE.right + 30
            and bdy >= BATTLE_ZONE.top - 10 and bdy <= BATTLE_ZONE.bottom + 10
        if inBZ then
            _battlePanning = true
            _battlePanLastDX = dx
            _battlePanLastDY = dy
            _battlePanTouchId = touchId
            return
        end
    end

    longPressState.pressing = true
    longPressState.active = false
    longPressState.startTime = gameState.gameTime

    -- 石台卡牌 (点击查看详情, 拖拽换位)
    local slotCard, slotIdx, isEnemy = HitSlotCard(dx, dy)
    if slotCard then
        longPressState.card = slotCard
        longPressState.isSlot = true
        longPressState.slotIdx = slotIdx
        longPressState.isEnemy = isEnemy
        dragState.touchId = touchId
        return
    end

    -- 背包卡牌 (拖拽上阵, DEPLOY和FIGHT阶段均可)
    if gameState.battlePhase == "DEPLOY" or gameState.battlePhase == "FIGHT" then
        local invCard, invIdx = HitInventoryCard(lx, ly)
        if invCard then
            local fullCard = DeepCopy(HERO_CARDS[invCard.cardIdx])
            fullCard.constellation = invCard.constellation
            fullCard.cardIdx = invCard.cardIdx
            fullCard.level = 1
            longPressState.card = fullCard
            longPressState.isSlot = false
            longPressState.slotIdx = invIdx
            longPressState.isEnemy = false
            dragState.touchId = touchId
            return
        end
    end


    return false  -- 未匹配任何 phase
end

return M
