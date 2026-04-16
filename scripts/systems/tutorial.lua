-- ============================================================================
-- systems/tutorial.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 新手引导系统
-- ============================================================================

--- 教程 Update 逻辑 (step 1 = 漫画, step 11 = 胜利过渡)
function UpdateTutorial(dt)
    local ts = tutorialState
    ts.hintTimer = ts.hintTimer + dt
    ts.fingerY = math.sin(ts.hintTimer * 3) * 6  -- 手指浮动动画

    -- (step 1 视频/漫画已移除，教程从 step 2 开始)
    if ts.step == 2 then
        -- 等待玩家点击设置按钮 (拦截在点击处理中)
        -- menuAnimTimer 已由 MENU 分支更新, 此处不重复
        ts.stepTimer = ts.stepTimer + dt
    elseif ts.step == 3 then
        -- 等待玩家点击"自动行军"开关
        ts.stepTimer = ts.stepTimer + dt
    elseif ts.step == 4 then
        -- 等待玩家点击"调整位置"
        ts.stepTimer = ts.stepTimer + dt
    elseif ts.step == 5 then
        -- 等待 btnAdjustMode 关闭
        ts.stepTimer = ts.stepTimer + dt
        if not settingsPage.btnAdjustMode then
            -- UI调整完成, 关闭设置
            settingsPage.isOpen = false
            ts.step = 6
            ts.stepTimer = 0
            phaseChangeCooldown = 0.3
            print("=== 教程: UI调整完成, 进入抽卡引导 ===")
        end
    elseif ts.step == 6 then
        -- 等待玩家点击"召唤武灵"
        -- menuAnimTimer 已由 MENU 分支更新, 此处不重复
        ts.stepTimer = ts.stepTimer + dt
    elseif ts.step == 7 then
        -- 抽卡界面中, 等待抽卡完成
        gachaState.animTimer = gachaState.animTimer + dt
        if gachaState.pulling then
            gachaState.pullTimer = gachaState.pullTimer + dt
            if gachaState.pullTimer >= 1.2 then
                gachaState.pulling = false
                gachaState.showResults = true
            end
        end
        -- 检测抽卡结果确认后进入教程战斗
        if ts.waitingGachaConfirm and not gachaState.showResults then
            ts.waitingGachaConfirm = false
            -- 进入教程战斗
            StartTutorialBattle()
        end
    elseif ts.step >= 8 and ts.step <= 13 then
        -- 教程战斗中, 使用正常战斗 update
        UpdateBattle(dt)
        ts.stepTimer = ts.stepTimer + dt
        -- step 8: 等待玩家放置武灵到石台 (自由操作, 无遮罩)
        -- 必须全部拖到石台上才进入下一步
        if ts.step == 8 then
            if GetUnsoldShopCardCount() == 0 and not IsDraggingCard() then
                ts.heroPlaced = true
                ts.step = 9
                ts.stepTimer = 0
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "点击「换战场」切换战斗风格!", 2.5, {255, 220, 80}, 14)
                print("=== 教程: 武灵已全部放置, 引导换战场 ===")
            end
        end
        -- step 9: 等待玩家点击"换战场"按钮 (遮罩高亮)
        -- (推进逻辑在 HandleTutorialClick 中处理)
        -- step 10: 等待玩家点击"开战"按钮 (遮罩高亮)
        if ts.step == 10 then
            if gameState.battlePhase == "FIGHT" then
                ts.fightStarted = true
                ts.step = 11
                ts.stepTimer = 0
                gameState.gold = math.max(gameState.gold, 10)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "点击「刷新」获取新武灵!", 2.0, {255, 220, 80}, 14)
                print("=== 教程: 已开战, 引导刷新 ===")
            end
        end
        -- step 11: 等待玩家点击"刷新"按钮 (遮罩高亮)
        -- (推进逻辑在 HandleTutorialClick 中处理)
        -- step 12: 提示拖拽派放小兵, 几秒后自动进入自由战斗
        if ts.step == 12 then
            if ts.stepTimer >= 4.0 then
                ts.step = 13
                ts.stepTimer = 0
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "消灭所有敌人!", 2.0, {255, 220, 80}, 14)
                print("=== 教程: 自由战斗 ===")
            end
        end
    elseif ts.step == 14 then
        -- 胜利过渡: 淡出效果
        ts.fadeTimer = ts.fadeTimer + dt
        if ts.fadeTimer >= 3.0 then
            -- 进入奖励弹窗
            ts.step = 15
            ts.stepTimer = 0
            ts.fadeTimer = 0
            -- 发放凡品兵甲奖励
            ts.tutorialReward = GrantRandomEquipment(1)  -- maxTier=1, 凡品
            print("=== 教程: 进入初始奖励弹窗 ===")
        end
    elseif ts.step == 15 then
        -- 等待玩家点击领取 (在 HandleTutorialClick 中处理)
        ts.stepTimer = ts.stepTimer + dt
    end
end


--- 启动教程战斗
function StartTutorialBattle()
    local ts = tutorialState
    -- 教程战斗: 临时解锁武技7和19供体验
    playerEquippedSkills = { 7, 19 }
    if SKILL_DEFS[7] then SKILL_DEFS[7].unlocked = true end
    if SKILL_DEFS[19] then SKILL_DEFS[19].unlocked = true end
    -- 初始化战斗
    InitBattle()
    gameState.phase = "BATTLE"
    gameState.battlePhase = "SHOP"
    -- 敌人较弱但不会秒杀 (给玩家时间学习操作)
    gameState.enemyBaseHP = 50
    gameState.enemyBaseMax = 50
    -- 教程战敌方大幅削弱，确保新手顺利破局
    local tutorialWeaken = 0.4
    for _, slot in ipairs(ENEMY_SLOTS) do
        if slot.filled and slot.card then
            slot.card.atk = math.floor(slot.card.atk * tutorialWeaken)
            slot.card.def = math.floor(slot.card.def * tutorialWeaken)
            slot.card.hp  = math.floor(slot.card.hp  * tutorialWeaken)
        end
    end
    -- 教程: 给足金币让玩家能买完所有商店卡牌
    local totalCost = 0
    for _, card in ipairs(shopCards) do
        totalCost = totalCost + card.cost
    end
    gameState.gold = totalCost
    -- 标记为教程战斗
    ts.step = 8
    ts.stepTimer = 0
    ts.heroPlaced = false
    ts.unitSpawned = false
    ts.skillUsed = false
    ts.shopRefreshed = false
    ts.fightStarted = false
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "将武灵拖到石台上部署", 3.0, {255, 220, 80}, 14)
    print("=== 教程: 进入教程战斗 (先放置武灵) ===")
end


-- DrawTutorialFinger 已移除

--- 教程点击处理 (拦截非目标区域)
--- 返回 true 表示教程已处理此点击, 外部不应继续处理
function HandleTutorialClick(sx, sy)
    local ts = tutorialState
    if not ts.active then return false end

    local dx, dy = ScreenToDesign(sx, sy)

    -- 退出确认弹窗点击处理
    if ts.exitConfirm then
        if ts.exitConfirmBtnRect then
            local r = ts.exitConfirmBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                -- 确认退出: 直接跳到奖励领取页
                ts.exitConfirm = false
                ts.step = 15
                ts.stepTimer = 0
                ts.fadeTimer = 0
                ts.tutorialReward = GrantRandomEquipment(1)
                print("=== 教程: 玩家确认退出引导, 直接领取奖励 ===")
                return true
            end
        end
        if ts.exitCancelBtnRect then
            local r = ts.exitCancelBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                ts.exitConfirm = false
                print("=== 教程: 取消退出 ===")
                return true
            end
        end
        return true  -- 弹窗期间拦截所有点击
    end

    -- 教程战斗阶段(step 8-13): "跳过"按钮 → 弹出退出确认框
    if ts.step >= 8 and ts.step <= 13 then
        if ts.tutorialSkipBtnRect then
            local r = ts.tutorialSkipBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                ts.exitConfirm = true
                print("=== 教程: 点击跳过, 弹出确认框 ===")
                return true
            end
        end
        if battleBackBtnRect then
            local r = battleBackBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                ts.exitConfirm = true
                print("=== 教程: 点击退出, 弹出确认框 ===")
                return true
            end
        end
    end

    -- (step 1 视频/漫画已移除，教程从 step 2 开始)

    if ts.step == 2 then
        -- 只允许点击设置按钮
        if settingsPage.btnRect then
            local r = settingsPage.btnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                settingsPage.isOpen = true
                ts.step = 3
                ts.stepTimer = 0
                print("=== 教程: 打开设置 ===")
                return false  -- 让正常逻辑也处理
            end
        end
        return true  -- 拦截其他点击
    end

    if ts.step == 3 then
        -- 只允许点击"自动行军"开关
        if settingsPage.autoMarchToggleRect then
            local r = settingsPage.autoMarchToggleRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                -- 强制开启自动行军
                gameSettings.defaultAutoMarch = true
                ts.step = 4
                ts.stepTimer = 0
                ShowToast("提示：可在设置中随时切换字体风格~", 3.0)
                print("=== 教程: 已开启自动行军 ===")
                return true  -- 拦截, 由教程控制状态
            end
        end
        return true  -- 拦截其他点击
    end

    if ts.step == 4 then
        -- 只允许点击"调整位置"
        if settingsPage.adjustPosBtnRect then
            local r = settingsPage.adjustPosBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                settingsPage.btnAdjustMode = true
                ts.step = 5
                ts.stepTimer = 0
                print("=== 教程: 进入UI调整 ===")
                return false  -- 让正常逻辑处理
            end
        end
        return true  -- 拦截其他点击
    end

    if ts.step == 6 then
        -- 只允许点击召唤武灵按钮
        if menuBtnRects.gacha then
            local r = menuBtnRects.gacha
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                -- 确保有足够虎符
                if playerInfo.jade < GameConfig.GACHA_COST_SINGLE then
                    playerInfo.jade = playerInfo.jade + GameConfig.GACHA_COST_SINGLE
                end
                PushPhase("GACHA")
                ts.step = 7
                ts.stepTimer = 0
                phaseChangeCooldown = 0.3
                print("=== 教程: 进入抽卡 ===")
                return true
            end
        end
        return true  -- 拦截其他点击
    end

    if ts.step == 7 then
        -- 抽卡界面: 拦截部分按钮
        -- 允许: 单抽, 确认结果
        -- 不允许: 十连, 返回, tab切换, 规则

        if gachaState.showResults then
            -- 允许确认结果
            if gachaConfirmBtnRect then
                local r = gachaConfirmBtnRect
                if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                    gachaState.showResults = false
                    gachaState.results = {}
                    gachaState.skillResults = {}
                    ts.waitingGachaConfirm = true
                    return true
                end
            end
            return true
        end

        if gachaState.pulling then
            -- 允许跳过动画
            gachaState.pulling = false
            gachaState.showResults = true
            return true
        end

        -- 单抽按钮
        if gachaSingleBtnRect then
            local r = gachaSingleBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                -- 确保有足够虎符
                if playerInfo.jade < GameConfig.GACHA_COST_SINGLE then
                    playerInfo.jade = playerInfo.jade + GameConfig.GACHA_COST_SINGLE
                end
                -- ExecuteGachaPull(1, 6)  -- 已移除抽卡系统，新手引导跳过此步
                -- 直接赠送SR武灵(cardIdx=6)作为新手奖励
                if not playerHeroes[6] or not playerHeroes[6].owned then
                    playerHeroes[6] = { owned = true, constellation = 0 }
                end
                return true
            end
        end
        return true  -- 拦截其他点击
    end

    if ts.step == 8 then
        -- 放置武灵阶段: 允许拖拽操作, 但阻止点击开战按钮(必须先放完所有武灵)
        if shopFightBtnRect then
            local r = shopFightBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "请先将武灵全部拖到石台上!", 1.5, {255, 100, 100}, 14)
                return true  -- 阻止开战
            end
        end
        -- 同时阻止换战场按钮(step 9 才允许)
        if battleChangeBgBtnRect then
            local r = battleChangeBgBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                return true  -- 阻止换战场
            end
        end
        return false  -- 其他操作(拖拽等)放行
    end

    if ts.step == 9 then
        -- 只允许点击"换战场"按钮
        if battleChangeBgBtnRect then
            local r = battleChangeBgBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                -- 执行换战场逻辑
                local newIdx = (currentLayoutIdx % 8) + 1
                ApplyBattleLayout(newIdx)
                local layoutName = BATTLE_LAYOUTS[newIdx] and BATTLE_LAYOUTS[newIdx].name or "默认"
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, layoutName, 1.0, { 180, 220, 255 }, 14)
                PlaySFX(AUDIO.sfx_click)
                -- 进入下一步: 引导开战
                ts.step = 10
                ts.stepTimer = 0
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "点击「开战」开始战斗!", 2.5, {255, 220, 80}, 14)
                print("=== 教程: 已换战场, 引导开战 ===")
                return true
            end
        end
        return true  -- 拦截其他点击
    end

    if ts.step == 10 then
        -- 只允许点击"开战"按钮
        if shopFightBtnRect then
            local r = shopFightBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                return false  -- 让正常逻辑处理开战
            end
        end
        return true  -- 拦截其他点击
    end

    if ts.step == 11 then
        -- 只允许点击"刷新"按钮
        if shopRefreshBtnRect then
            local r = shopRefreshBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                -- 确保有足够金币
                if gameState.gold < GameConfig.REFRESH_COST then
                    gameState.gold = gameState.gold + GameConfig.REFRESH_COST
                end
                ts.shopRefreshed = true
                ts.step = 12
                ts.stepTimer = 0
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "拖拽武灵到底座部署小兵!", 2.5, {255, 220, 80}, 14)
                print("=== 教程: 已刷新, 引导拖拽部署 ===")
                return false  -- 让正常逻辑也执行刷新
            end
        end
        return true  -- 拦截其他点击
    end

    if ts.step == 14 then
        return true  -- 过渡中拦截所有点击
    end

    if ts.step == 15 then
        -- 奖励弹窗: 只允许点击"领取"按钮
        if ts.rewardBtnRect then
            local r = ts.rewardBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                -- 领取奖励, 完成教程
                gameSettings.tutorialCompleted = true
                -- 奖励终身只领一次：检查是否已领取过
                if not gameSettings.tutorialRewardClaimed then
                    gameSettings.tutorialRewardClaimed = true
                    -- 教程完成奖励: 永久解锁武技7, 回收临时体验的武技19
                    if SKILL_DEFS[19] then SKILL_DEFS[19].unlocked = false end
                    -- 武技7作为教程奖励永久解锁(已在StartTutorialBattle中解锁, 保持)
                    playerEquippedSkills = { 7 }  -- 只保留武技7
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
                        "习得武技: " .. (SKILL_DEFS[7] and SKILL_DEFS[7].name or "武技"), 2.0, { 255, 180, 60 }, 20)
                    print("=== 教程完成! 已领取初始兵甲奖励, 赠送武技7 ===")
                else
                    print("=== 教程完成! 奖励已领取过，不再重复发放 ===")
                end
                SaveSettings()
                SaveGameProgress()
                tutorialState.active = false
                tutorialState.step = 0
                -- 教程完成后直接进入世界地图并启动新手引导
                WorldMap.Init()
                gameState.phase = "WORLD_MAP"
                phaseChangeCooldown = 0.3
                WorldMap.StartGuide()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "进入天下大势！", 2.5, {255, 230, 100}, 20)
            end
        end
        return true  -- 拦截所有点击
    end

    -- step 5, 12-13: 不拦截, 让正常逻辑处理
    return false
end
