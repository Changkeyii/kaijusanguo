-- ============================================================================
-- systems/battle/update.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 战斗结算: 胜利/结束 统一入口
-- ============================================================================

--- 战斗胜利时调用 (统计、首通、讨伐通关、解锁下一关)
function OnBattleVictory()
    -- 0) 探索模式已移除
    -- if gameState.explorationMode then ... end

    -- 1) 统计
    playerInfo.totalWins = playerInfo.totalWins + 1
    playerInfo.totalBattles = playerInfo.totalBattles + 1
    TrackDailyTask("battle3", 1)
    TrackDailyTask("win2", 1)
    TrackWeeklyTask("wbattle15", 1)
    TrackWeeklyTask("wwin10", 1)
    TrackBattlePassTask("bp_battle3", 1)
    TrackBattlePassTask("bp_win2", 1)
    TrackBattlePassTask("bp_wbattle20", 1)
    TrackBattlePassTask("bp_wwin12", 1)
    TrackBattlePassTask("bp_sbattle100", 1)
    TrackBattlePassTask("bp_swin50", 1)

    -- 2) 关卡星级奖励 (非讨伐/爬塔)
    if not gameState.abyssFloor and not gameState.towerFloor and not gameState.isRanked then
        local stageIdx = stageState.currentStage
        local key = tostring(stageIdx)
        -- 计算星级: 基于基地剩余HP百分比
        local hpPct = (gameState.playerBaseHP or 0) / (BASE_HP_MAX or 1)
        local earnedStars = 1
        if hpPct > 0.8 then
            earnedStars = 3
        elseif hpPct > 0.5 then earnedStars = 2 end
        -- 更新最高星级
        local prevStars = stageStars[key] or 0
        if earnedStars > prevStars then
            stageStars[key] = earnedStars
            -- 发放新达到星级的虎符奖励
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
                gameState.firstClearReward = { jade = totalJadeReward }
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "★" .. earnedStars .. " 星级奖励: +" .. totalJadeReward .. " 虎符", 2.0, {255, 220, 80}, 20)
            end
        end
        gameState.lastEarnedStars = earnedStars  -- 保存用于结算展示
        -- 自动解锁下一关
        if stageIdx >= stageState.maxUnlocked and stageIdx < #STAGES then
            stageState.maxUnlocked = stageIdx + 1
        end
    end

    -- 3) 讨伐通关奖励
    if gameState.abyssFloor then
        local floorIdx = gameState.abyssFloor
        local floorKey = tostring(floorIdx)
        TrackDailyTask("abyss1", 1)
        TrackWeeklyTask("wabyss3", 1)
        TrackBattlePassTask("bp_wabyss3", 1)
        TrackBattlePassTask("bp_sabyss10", 1)
        if not abyssCleared[floorKey] then
            abyssCleared[floorKey] = true
        end
        local abReward = ABYSS_REWARDS[floorIdx]
        if abReward then
            GrantRewardTable(abReward)
            gameState.abyssReward = abReward  -- 保存用于弹窗展示
        end
    end

    -- 3.5) 爬塔通关奖励
    if gameState.towerFloor then
        local fl = gameState.towerFloor
        -- 递增奖励 (适度降低)
        local towerJade = 20 + fl * 7
        local towerFrag = math.min(12, math.floor(fl / 4) + 1)
        local towerReward = { jade = towerJade, frag = towerFrag }
        GrantRewardTable(towerReward)
        gameState.towerReward = towerReward  -- 保存用于弹窗展示
        -- 推进层数 (上限999层)
        towerState.currentFloor = math.min(fl + 1, 1000)  -- 1000表示已通关999层，不可再挑战
        if fl > towerState.highestFloor then
            towerState.highestFloor = fl
            ReportTowerFloor()  -- 上报云端排行榜
        end
    end

    -- 3.8) 排位胜利
    if gameState.isRanked then
        playerInfo.totalRankedBattles = (playerInfo.totalRankedBattles or 0) + 1
        playerInfo.totalRankedWins = (playerInfo.totalRankedWins or 0) + 1
        rankedState.wins = rankedState.wins + 1
        if rankedState.streak < 0 then rankedState.streak = 0 end
        rankedState.streak = rankedState.streak + 1
        local delta = CalcRankedScoreChange(true, rankedState.streak)
        rankedState.score = math.max(0, rankedState.score + delta)
        if rankedState.score > rankedState.highestScore then
            rankedState.highestScore = rankedState.score
        end
        gameState.rankedDelta = delta  -- 保存用于弹窗展示
        ReportRankedScore()
        -- 网络模式: 上报服务端进行权威 Elo 结算
        if rawget(_G, "IsNetworkMode") and IsNetworkMode() then
            local Client = require("network.Client")
            Client.ReportRankedBattleResult(true, rankedState.score, delta, rankedState.streak)
        end
    end

    -- 3.9) 战场招揽 (战争版: 战斗胜利后有概率招揽一名未拥有武将)
    do
        local recruitResult = nil
        -- 收集所有未拥有的武将 (品质越低越容易招揽)
        local candidates = {}
        for idx = 1, #HERO_CARDS do
            local hero = playerHeroes[idx]
            if not hero or not hero.owned then
                table.insert(candidates, idx)
            end
        end
        if #candidates > 0 then
            -- 招揽概率: 基础20%, 随关卡/讨伐进度提升
            local recruitChance = 0.20
            if gameState.abyssFloor then
                recruitChance = 0.30 + gameState.abyssFloor * 0.05
            elseif gameState.towerFloor then
                recruitChance = 0.15 + math.min(0.25, gameState.towerFloor * 0.005)
            end
            recruitChance = math.min(0.60, recruitChance)

            if math.random() < recruitChance then
                -- 按品质权重选择 (N=40, R=30, SR=15, SSR=10, 限定=5)
                local RECRUIT_WEIGHTS = { [1] = 40, [2] = 30, [3] = 15, [4] = 10, [5] = 5 }
                local weighted = {}
                for _, idx in ipairs(candidates) do
                    local q = HERO_CARDS[idx].quality or 1
                    local w = RECRUIT_WEIGHTS[q] or 20
                    table.insert(weighted, { idx = idx, weight = w })
                end
                -- 加权随机选择
                local totalW = 0
                for _, e in ipairs(weighted) do totalW = totalW + e.weight end
                local roll = math.random() * totalW
                local acc = 0
                local chosenIdx = weighted[1].idx
                for _, e in ipairs(weighted) do
                    acc = acc + e.weight
                    if roll <= acc then chosenIdx = e.idx; break end
                end
                -- 招揽成功
                playerHeroes[chosenIdx] = { owned = true, constellation = 0, level = 1 }
                recruitResult = {
                    cardIdx = chosenIdx,
                    name = HERO_CARDS[chosenIdx].name,
                    quality = HERO_CARDS[chosenIdx].quality,
                    faction = HERO_CARDS[chosenIdx].faction,
                }
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                    "招揽成功: " .. HERO_CARDS[chosenIdx].name .. "!",
                    2.5, QUALITY_COLORS[HERO_CARDS[chosenIdx].quality] or {255, 255, 255}, 22)
            end
        end
        gameState.recruitResult = recruitResult  -- 保存用于结算界面展示
    end

    -- 3.10) 大地图战斗胜利回调
    if gameState.worldMapBattle and rawget(_G, "WorldMap") then
        WorldMap.OnBattleResult(true)
    end

    -- 4) 保存
    SaveGameProgress()
end


--- 战斗结束时调用 (失败/平局)
function OnBattleEnd()
    -- 探索模式已移除
    -- if gameState.explorationMode then ... end

    playerInfo.totalBattles = playerInfo.totalBattles + 1
    TrackDailyTask("battle3", 1)
    TrackWeeklyTask("wbattle15", 1)
    TrackBattlePassTask("bp_battle3", 1)
    TrackBattlePassTask("bp_wbattle20", 1)
    TrackBattlePassTask("bp_sbattle100", 1)
    -- 讨伐失败也计入讨伐任务
    if gameState.abyssFloor then
        TrackDailyTask("abyss1", 1)
        TrackWeeklyTask("wabyss3", 1)
        TrackBattlePassTask("bp_wabyss3", 1)
        TrackBattlePassTask("bp_sabyss10", 1)
    end
    -- 排位失败
    if gameState.isRanked then
        playerInfo.totalRankedBattles = (playerInfo.totalRankedBattles or 0) + 1
        rankedState.losses = rankedState.losses + 1
        if rankedState.streak > 0 then rankedState.streak = 0 end
        rankedState.streak = rankedState.streak - 1
        local delta = CalcRankedScoreChange(false, rankedState.streak)
        rankedState.score = math.max(0, rankedState.score + delta)
        gameState.rankedDelta = delta  -- 保存用于弹窗展示
        ReportRankedScore()
        -- 网络模式: 上报服务端进行权威 Elo 结算
        if rawget(_G, "IsNetworkMode") and IsNetworkMode() then
            local Client = require("network.Client")
            Client.ReportRankedBattleResult(false, rankedState.score, delta, rankedState.streak)
        end
    end
    -- 大地图战斗失败回调
    if gameState.worldMapBattle and rawget(_G, "WorldMap") then
        WorldMap.OnBattleResult(false)
    end
    SaveGameProgress()
end


-- ============================================================================
-- 更新逻辑
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    gameState.gameTime = gameState.gameTime + dt

    -- 驱动网络客户端帧更新（不能用 SubscribeToEvent 否则会覆盖本 HandleUpdate）
    if netState and netState.connected and rawget(_G, "HandleClientUpdate") then
        HandleClientUpdate(eventType, eventData)
    end

    -- DWP 回调设置的字体重建标志：在主线程执行字体重建
    if fontRebuildNeeded then
        fontRebuildNeeded = false
        if fontId < 0 then
            fontId = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
            print("[MainThread] 重建主字体 fontId=" .. tostring(fontId))
        end
    end

    -- 自动存档（每60秒保存一次，防止意外退出丢失进度）
    -- 仅在完成资料设置且进入主菜单后才自动存档，避免在加载/选资料阶段覆盖正确数据
    autoSaveTimer = (autoSaveTimer or 0) + dt
    if autoSaveTimer >= 60 then
        autoSaveTimer = 0
        if playerInfo.profileSet and gameState.phase ~= "LOADING" and gameState.phase ~= "PROFILE" then
            SaveGameProgress()
        end
    end

    -- 虎符≥20万一次性解锁连抽增强 (10/50/100连抽)
    if not playerInfo.jadeUnlockedBigPull and playerInfo.jade >= 200000 then
        playerInfo.jadeUnlockedBigPull = true
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "连抽增强已解锁! 10/50/100连抽", 2.5, { 255, 220, 80 }, 20)
        print("[连抽增强] 虎符≥20万, 永久解锁10/50/100连抽!")
    end

    -- 云存档重试 (委托给 CloudManager)
    if rawget(_G, 'CloudManager') then CloudManager.Update(dt) end

    -- 交易行定时扫描
    TradeManager.Tick(dt)

    -- 广告限制已移除

    -- 战斗规则弹窗滚动惯性
    if battleRulesState.show and not battleRulesState.isDragging and math.abs(battleRulesState.vel) > 1 then
        battleRulesState.scrollY = battleRulesState.scrollY + battleRulesState.vel * dt
        battleRulesState.vel = battleRulesState.vel * 0.92
        local maxScroll = math.max(0, battleRulesState.contentH - battleRulesState.viewH)
        battleRulesState.scrollY = math.max(0, math.min(battleRulesState.scrollY, maxScroll))
    elseif battleRulesState.show and not battleRulesState.isDragging then
        battleRulesState.vel = 0
    end

    -- 新手指引弹窗滚动惯性
    if newbieGuidePopup.show and not newbieGuidePopup.isDragging and math.abs(newbieGuidePopup.vel or 0) > 1 then
        newbieGuidePopup.scrollY = (newbieGuidePopup.scrollY or 0) + (newbieGuidePopup.vel or 0) * dt
        newbieGuidePopup.vel = (newbieGuidePopup.vel or 0) * 0.92
        local maxScroll = math.max(0, (newbieGuidePopup.contentH or 0) - (newbieGuidePopup.viewH or 0))
        newbieGuidePopup.scrollY = math.max(0, math.min(newbieGuidePopup.scrollY, maxScroll))
    elseif newbieGuidePopup.show and not newbieGuidePopup.isDragging then
        newbieGuidePopup.vel = 0
    end

    -- 统一规则弹窗滚动惯性
    if phaseRulePopup.show and not phaseRulePopup.isDragging and math.abs(phaseRulePopup.vel or 0) > 1 then
        phaseRulePopup.scrollY = (phaseRulePopup.scrollY or 0) + (phaseRulePopup.vel or 0) * dt
        phaseRulePopup.vel = (phaseRulePopup.vel or 0) * 0.92
        local maxScroll = math.max(0, (phaseRulePopup.contentH or 0) - (phaseRulePopup.viewH or 0))
        phaseRulePopup.scrollY = math.max(0, math.min(phaseRulePopup.scrollY, maxScroll))
    elseif phaseRulePopup.show and not phaseRulePopup.isDragging then
        phaseRulePopup.vel = 0
    end

    -- 兵符替换弹窗滚动惯性
    if sealReplaceState.show then
        local scrl = sealReplaceState.scroll
        if not scrl.isDragging and math.abs(scrl.vel or 0) > 1 then
            scrl.y = (scrl.y or 0) + (scrl.vel or 0) * dt
            scrl.vel = (scrl.vel or 0) * 0.92
            local maxScroll = math.max(0, (scrl.contentH or 0) - (scrl.viewH or 0))
            scrl.y = math.max(0, math.min(scrl.y, maxScroll))
        elseif not scrl.isDragging then
            scrl.vel = 0
        end
    end

    -- 策略选项条: 每帧检测长按（不依赖手指移动）
    if strategyWheelState.pressing and not strategyWheelState.show then
        local elapsed = gameState.gameTime - strategyWheelState.startTime
        if elapsed >= STRATEGY_LONG_PRESS then
            strategyWheelState.show = true
        end
    end

    -- (已移除武技长按弹窗, 改为按下即拖拽瞄准)

    -- 探索模式帧更新 (已移除探索系统)
    -- if gameState.phase == "EXPLORATION" then
    --     Exploration.Update(dt)
    -- end

    -- 累计在线时间（全局，不仅限于福利页）
    welfareState.onlineTime = welfareState.onlineTime + dt

    -- BGM 场景切换
    UpdateBGM()

    -- 天命赐福滚动惯性
    if gameState.phase == "WELFARE" then
        local ws = welfareState.scroll
        if not ws.isDragging and math.abs(ws.vel) > 0.5 then
            ws.offset = ws.offset + ws.vel * dt
            ws.vel = ws.vel * 0.92
        elseif not ws.isDragging then
            ws.vel = 0
        end
        -- 贡献榜独立滚动惯性
        local cs = welfareState.contribScroll
        if not cs.isDragging and math.abs(cs.vel) > 0.5 then
            cs.offset = cs.offset + cs.vel * dt
            cs.vel = cs.vel * 0.92
        elseif not cs.isDragging then
            cs.vel = 0
        end
        -- 战力排行榜独立滚动惯性
        local ps2 = welfareState.powerScroll
        if not ps2.isDragging and math.abs(ps2.vel) > 0.5 then
            ps2.offset = ps2.offset + ps2.vel * dt
            ps2.vel = ps2.vel * 0.92
        elseif not ps2.isDragging then
            ps2.vel = 0
        end
        -- 桩逼王排行榜滚动惯性
        local ds = welfareState.dummyScroll
        if not ds.isDragging and math.abs(ds.vel) > 0.5 then
            ds.offset = ds.offset + ds.vel * dt
            ds.vel = ds.vel * 0.92
        elseif not ds.isDragging then
            ds.vel = 0
        end
    end

    -- 阵营成员列表滚动惯性
    if gameState.phase == "FACTION" then
        local fs = factionUI.scroll
        if not fs.isDragging and math.abs(fs.vel) > 0.5 then
            fs.offset = fs.offset + fs.vel * dt
            fs.vel = fs.vel * 0.92
            if fs.offset < 0 then fs.offset = 0; fs.vel = 0 end
        elseif not fs.isDragging then
            fs.vel = 0
        end
    end

    -- 交易行滚动惯性
    if gameState.phase == "TRADE" then
        local ts = tradeState.scroll
        if not ts.isDragging and math.abs(ts.vel) > 0.5 then
            ts.offset = ts.offset + ts.vel * dt
            ts.vel = ts.vel * 0.92
            if ts.offset < 0 then ts.offset = 0; ts.vel = 0 end
        elseif not ts.isDragging then
            ts.vel = 0
        end
        -- toast 计时
        if tradeState.toastTimer > 0 then
            tradeState.toastTimer = tradeState.toastTimer - dt
        end
    end

    -- 编队界面滚动惯性
    if gameState.phase == "FORMATION" and formationUI then
        menuAnimTimer = menuAnimTimer + dt
        if not formationUI.isDragging and math.abs(formationUI.scrollVel or 0) > 0.5 then
            formationUI.scrollY = (formationUI.scrollY or 0) + formationUI.scrollVel * dt
            formationUI.scrollVel = formationUI.scrollVel * 0.92
        elseif not formationUI.isDragging then
            formationUI.scrollVel = 0
        end
    end

    -- 邮件列表滚动惯性
    if gameState.phase == "MAIL_BOX" then
        local ms = welfareState.mail.scroll
        if ms and not ms.isDragging and math.abs(ms.vel) > 0.5 then
            ms.offset = ms.offset + ms.vel * dt
            ms.vel = ms.vel * 0.92
            if ms.offset < 0 then ms.offset = 0; ms.vel = 0 end
        elseif ms and not ms.isDragging then
            ms.vel = 0
        end
    end

    -- 战令通行证任务列表滚动惯性
    if gameState.phase == "BATTLE_PASS" and battlePassUIState.tab ~= 1 then
        local bs = battlePassUIState
        if not bs.isDragging then
            if math.abs(bs.scrollVel or 0) > 0.3 then
                bs.scrollY = bs.scrollY + bs.scrollVel * dt
                bs.scrollVel = bs.scrollVel * math.pow(0.12, dt)
            else
                bs.scrollVel = 0
            end
            -- 边界回弹
            local maxY = 0
            local minY = -math.max(0, (bs.contentHeight or 0))
            if bs.scrollY > maxY then
                bs.scrollY = bs.scrollY + (maxY - bs.scrollY) * math.min(1, 12 * dt)
                bs.scrollVel = (bs.scrollVel or 0) * 0.5
                if math.abs(bs.scrollY - maxY) < 0.5 then bs.scrollY = maxY end
            elseif bs.scrollY < minY then
                bs.scrollY = bs.scrollY + (minY - bs.scrollY) * math.min(1, 12 * dt)
                bs.scrollVel = (bs.scrollVel or 0) * 0.5
                if math.abs(bs.scrollY - minY) < 0.5 then bs.scrollY = minY end
            end
        end
    end

    -- 每日任务/成就滚动惯性 (带边界回弹)
    if gameState.phase == "PROGRESS" then
        local ps = progressUIState
        if not ps.isDragging then
            -- 惯性衰减（更平滑的指数衰减）
            if math.abs(ps.scrollVel) > 0.3 then
                ps.scrollY = ps.scrollY + ps.scrollVel * dt
                ps.scrollVel = ps.scrollVel * math.pow(0.12, dt) -- 时间无关衰减
            else
                ps.scrollVel = 0
            end
            -- 边界回弹
            local maxScroll = ps.contentHeight or 0
            local minY = -math.max(0, maxScroll)
            local maxY = 0
            if ps.scrollY > maxY then
                -- 顶部超出，弹回
                ps.scrollY = ps.scrollY + (maxY - ps.scrollY) * math.min(1, 12 * dt)
                ps.scrollVel = ps.scrollVel * 0.5
                if math.abs(ps.scrollY - maxY) < 0.5 then ps.scrollY = maxY end
            elseif ps.scrollY < minY then
                -- 底部超出，弹回
                ps.scrollY = ps.scrollY + (minY - ps.scrollY) * math.min(1, 12 * dt)
                ps.scrollVel = ps.scrollVel * 0.5
                if math.abs(ps.scrollY - minY) < 0.5 then ps.scrollY = minY end
            end
        else
            -- 拖拽中的橡皮筋效果（超出边界时阻力变大）
            local maxScroll = ps.contentHeight or 0
            local minY = -math.max(0, maxScroll)
            if ps.scrollY > 0 then
                ps.scrollY = ps.scrollY * 0.6  -- 顶部橡皮筋阻力
            elseif ps.scrollY < minY then
                local over = minY - ps.scrollY
                ps.scrollY = minY - over * 0.6  -- 底部橡皮筋阻力
            end
        end
    end

    -- 编辑器滚动惯性 (带边界回弹)
    if gameState.phase == "DEV_EDITOR" then
        local es = editorState
        if not es.isDragging then
            if math.abs(es.scrollVel) > 0.3 then
                es.scrollY = es.scrollY + es.scrollVel * dt
                es.scrollVel = es.scrollVel * math.pow(0.12, dt)
            else
                es.scrollVel = 0
            end
            local maxScroll = es.contentHeight or 0
            local minY = -math.max(0, maxScroll)
            local maxY = 0
            if es.scrollY > maxY then
                es.scrollY = es.scrollY + (maxY - es.scrollY) * math.min(1, 12 * dt)
                es.scrollVel = es.scrollVel * 0.5
                if math.abs(es.scrollY - maxY) < 0.5 then es.scrollY = maxY end
            elseif es.scrollY < minY then
                es.scrollY = es.scrollY + (minY - es.scrollY) * math.min(1, 12 * dt)
                es.scrollVel = es.scrollVel * 0.5
                if math.abs(es.scrollY - minY) < 0.5 then es.scrollY = minY end
            end
        else
            local maxScroll = es.contentHeight or 0
            local minY = -math.max(0, maxScroll)
            if es.scrollY > 0 then
                es.scrollY = es.scrollY * 0.6
            elseif es.scrollY < minY then
                local over = minY - es.scrollY
                es.scrollY = minY - over * 0.6
            end
        end
    end

    -- 相位切换防穿透冷却递减
    if phaseChangeCooldown > 0 then
        phaseChangeCooldown = phaseChangeCooldown - dt
    end

    -- CDK 结果提示倒计时
    if cdkState.resultTimer > 0 then
        cdkState.resultTimer = cdkState.resultTimer - dt
    end

    -- Toast 计时器递减
    if toastState.timer > 0 then
        toastState.timer = toastState.timer - dt
    end

    -- (长按不再触发弹窗, 改为单击触发 infoPopupState)

    -- LOADING 阶段：阻塞资源下载完成后跳转选服
    if gameState.phase == "LOADING" then
        menuAnimTimer = menuAnimTimer + dt
        if blockingLoadState.ready then
            gameState.phase = "SERVER_SELECT"
            gameState.selectedServer = nil  -- 每次登录重新选服
            print("=== 阻塞加载完成，进入 SERVER_SELECT ===")
        end
        -- 点击提示倒计时
        if loadingClickTipTimer and loadingClickTipTimer > 0 then
            loadingClickTipTimer = loadingClickTipTimer - dt
        end
        return
    end

    -- SERVER_SELECT 阶段：等待玩家选服
    if gameState.phase == "SERVER_SELECT" then
        menuAnimTimer = menuAnimTimer + dt
        return
    end

    if gameState.phase == "PROFILE" then
        menuAnimTimer = menuAnimTimer + dt
    elseif gameState.phase == "MENU" then
        menuAnimTimer = menuAnimTimer + dt
        -- 左侧栏滚动惯性
        if not leftSidebarScroll.isDragging and math.abs(leftSidebarScroll.vel) > 0.5 then
            leftSidebarScroll.y = leftSidebarScroll.y + leftSidebarScroll.vel * dt
            leftSidebarScroll.vel = leftSidebarScroll.vel * 0.92
            local maxScroll = math.max(0, leftSidebarScroll.contentH - leftSidebarScroll.viewH)
            leftSidebarScroll.y = math.max(0, math.min(leftSidebarScroll.y, maxScroll))
        elseif not leftSidebarScroll.isDragging then
            leftSidebarScroll.vel = 0
        end
    elseif gameState.phase == "GACHA" then
        do
            gachaState.animTimer = gachaState.animTimer + dt
            if gachaState.pulling then
                gachaState.pullTimer = gachaState.pullTimer + dt
                if gachaState.pullTimer >= 1.2 then
                    gachaState.pulling = false
                    gachaState.showResults = true
                end
            end
            if sealGachaState.pulling then
                sealGachaState.pullTimer = sealGachaState.pullTimer + dt
                if sealGachaState.pullTimer >= 1.2 then
                    sealGachaState.pulling = false
                    sealGachaState.showResults = true
                end
            end
        end
        -- 残片仓库惯性滚动
        if gachaState.showFragShop and not fragShopScroll.isDragging and math.abs(fragShopScroll.vel) > 0.5 then
            fragShopScroll.offset = fragShopScroll.offset + fragShopScroll.vel * dt
            fragShopScroll.vel = fragShopScroll.vel * 0.92
        elseif gachaState.showFragShop then
            fragShopScroll.vel = 0
        end
    elseif gameState.phase == "CODEX" then
        menuAnimTimer = menuAnimTimer + dt
        -- 滚动惯性
        if not codexScroll.isDragging and math.abs(codexScroll.vel) > 0.5 then
            codexScroll.y = codexScroll.y + codexScroll.vel * dt
            codexScroll.vel = codexScroll.vel * 0.92  -- 摩擦力衰减
        else
            codexScroll.vel = 0
        end
    elseif gameState.phase == "HERO_DETAIL" then
        menuAnimTimer = menuAnimTimer + dt
        -- 滚动惯性
        if not heroDetailScroll.isDragging and math.abs(heroDetailScroll.vel) > 0.5 then
            heroDetailScroll.y = heroDetailScroll.y + heroDetailScroll.vel * dt
            heroDetailScroll.vel = heroDetailScroll.vel * 0.92
        else
            heroDetailScroll.vel = 0
        end
    elseif gameState.phase == "PLAYER_DETAIL" then
        menuAnimTimer = menuAnimTimer + dt
        -- 滚动惯性
        if not playerDetailScroll.isDragging and math.abs(playerDetailScroll.vel) > 0.5 then
            playerDetailScroll.y = playerDetailScroll.y + playerDetailScroll.vel * dt
            playerDetailScroll.vel = playerDetailScroll.vel * 0.92
        else
            playerDetailScroll.vel = 0
        end
    elseif gameState.phase == "SKILL_CODEX" then
        menuAnimTimer = menuAnimTimer + dt
        -- 滚动惯性
        if not skillCodexState.isDragging and math.abs(skillCodexState.scrollVel) > 0.5 then
            skillCodexState.scrollY = skillCodexState.scrollY + skillCodexState.scrollVel * dt
            skillCodexState.scrollVel = skillCodexState.scrollVel * 0.92
        else
            skillCodexState.scrollVel = 0
        end
        -- 滚动范围限制
        local maxScroll = math.max(0, (skillCodexState.contentH or 0) - (DESIGN_H - 68))
        skillCodexState.scrollY = math.max(0, math.min(maxScroll, skillCodexState.scrollY))
    elseif gameState.phase == "EQUIP" then
        menuAnimTimer = menuAnimTimer + dt
        -- 新版EquipUI更新（滚动惯性、长按计时等）
        if EquipUI.isVisible then
            EquipUI.Update(dt)
        else
            -- 旧版滚动惯性
            if not equipScreenState.isDragging and math.abs(equipScreenState.scrollVel) > 0.5 then
                equipScreenState.scrollY = equipScreenState.scrollY + equipScreenState.scrollVel * dt
                equipScreenState.scrollVel = equipScreenState.scrollVel * 0.92
            elseif not equipScreenState.isDragging then
                equipScreenState.scrollVel = 0
            end
        end
    elseif gameState.phase == "EQUIP_CODEX" then
        menuAnimTimer = menuAnimTimer + dt
        -- 兵甲图录滚动惯性
        if not equipCodexState.isDragging and math.abs(equipCodexState.scrollVel) > 0.5 then
            equipCodexState.scrollY = equipCodexState.scrollY + equipCodexState.scrollVel * dt
            equipCodexState.scrollVel = equipCodexState.scrollVel * 0.92
        elseif not equipCodexState.isDragging then
            equipCodexState.scrollVel = 0
        end
    elseif gameState.phase == "SEAL_MGR" then
        menuAnimTimer = menuAnimTimer + dt
        -- 兵符管理滚动惯性（选中分解列表）
        if not sealMgrScroll.isDragging and math.abs(sealMgrScroll.vel) > 0.5 then
            sealMgrScroll.y = (sealMgrScroll.y or 0) + sealMgrScroll.vel * dt
            sealMgrScroll.vel = sealMgrScroll.vel * 0.92
            -- 边界限制
            local maxS = math.max(0, (sealMgrScroll.contentH or 0) - (sealMgrScroll.viewH or 0))
            sealMgrScroll.y = math.max(0, math.min(sealMgrScroll.y, maxS))
        elseif not sealMgrScroll.isDragging then
            sealMgrScroll.vel = 0
        end
        -- 英雄选择弹窗滚动惯性
        if sealMgrState.showHeroPicker and not heroPickerScroll.isDragging and math.abs(heroPickerScroll.vel) > 0.5 then
            heroPickerScroll.y = (heroPickerScroll.y or 0) + heroPickerScroll.vel * dt
            local maxScroll = math.max(0, (heroPickerScroll.contentH or 0) - (heroPickerScroll.viewH or 0))
            heroPickerScroll.y = math.max(0, math.min(heroPickerScroll.y, maxScroll))
            heroPickerScroll.vel = heroPickerScroll.vel * 0.92
        elseif sealMgrState.showHeroPicker and not heroPickerScroll.isDragging then
            heroPickerScroll.vel = 0
        end
    elseif gameState.phase == "WELFARE" then
        menuAnimTimer = menuAnimTimer + dt
    elseif gameState.phase == "MAIL_BOX" then
        menuAnimTimer = menuAnimTimer + dt
    elseif gameState.phase == "POWER_RANK" then
        menuAnimTimer = menuAnimTimer + dt
        -- 战力/境界排行榜滚动惯性（根据当前页签）
        local ps2 = welfareState.powerScroll
        if not ps2.isDragging and math.abs(ps2.vel) > 0.5 then
            ps2.offset = ps2.offset + ps2.vel * dt
            ps2.vel = ps2.vel * 0.92
        elseif not ps2.isDragging then
            ps2.vel = 0
        end
        local rs2 = welfareState.realmScroll
        if not rs2.isDragging and math.abs(rs2.vel) > 0.5 then
            rs2.offset = rs2.offset + rs2.vel * dt
            rs2.vel = rs2.vel * 0.92
        elseif not rs2.isDragging then
            rs2.vel = 0
        end
    elseif gameState.phase == "CONTRIB_RANK" then
        menuAnimTimer = menuAnimTimer + dt
        -- 贡献榜详情页滚动惯性
        local cs2 = welfareState.contribDetailScroll
        if not cs2.isDragging and math.abs(cs2.vel) > 0.5 then
            cs2.offset = cs2.offset + cs2.vel * dt
            cs2.vel = cs2.vel * 0.92
        elseif not cs2.isDragging then
            cs2.vel = 0
        end
    elseif gameState.phase == "WORLD_MAP" then
        menuAnimTimer = menuAnimTimer + dt
        WorldMap.UpdateGuide(dt)
        WorldMap.UpdateMarch(dt)
        WorldMap.UpdateMapDrag(dt)
    elseif gameState.phase == "RANKED_SELECT" then
        menuAnimTimer = menuAnimTimer + dt
        -- 排位匹配动画 (1.5秒假匹配后进入战斗)
        if rankedState.isMatching then
            rankedState.matchAnim = rankedState.matchAnim + dt
            if rankedState.matchAnim >= 1.5 then
                rankedState.isMatching = false
                rankedState.matchAnim = 0
                -- 进入战斗
                gameState.isRanked = true
                gameState.phase = "BATTLE"
                gameState.battlePhase = "FIGHT"  -- 三国群英传模式: 直接战斗
                gameState.playerBaseHP = BASE_HP_MAX
                gameState.enemyBaseHP = BASE_HP_MAX
                gameState.gold = 0
                gameState.totalKills = 0
                gameState.gameTime = 0
                gameState.battleTime = 0
                gameState.drawCount = 0
                gameState.goldTimer = 0
                gameState.resultTimer = 0
                gameState.autoMarch = true  -- 始终自动行军
                -- 阶级: 根据段位递增
                local tierIdx = GetRankedTier(rankedState.score).index
                stageMaxTier = math.min(6, math.max(1, tierIdx))
                for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                activeSkillEffects = {}
                skillTargeting.active = false
                for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                playerUnits = {}
                enemyUnits = {}
                inventory = {}
                -- 部署AI对手的武灵到敌方槽位 (stats已bake, eScale=1.0)
                local oppCards = rankedState.opponentCards
                for i = 1, math.min(#oppCards, #ENEMY_SLOTS) do
                    local card = DeepCopy(oppCards[i])
                    ENEMY_SLOTS[i].filled = true
                    ENEMY_SLOTS[i].card = card
                    ENEMY_SLOTS[i].spawnTimer = 0
                    ENEMY_SLOTS[i].spawnCount = 0
                    ENEMY_SLOTS[i].spawnFlash = 0
                end
                -- 使用随机战场背景
                local bgIdx = math.random(1, 8)
                ApplyBattleLayout(bgIdx)
                -- 三国群英传模式: 自动部署玩家编队
                ValidateFormation()
                local rPool = {}
                if #gameSettings.formation > 0 then
                    for _, idx in ipairs(gameSettings.formation) do
                        local info = playerHeroes[idx]
                        if info and info.owned and idx <= #HERO_CARDS then
                            table.insert(rPool, { cardIdx = idx, quality = HERO_CARDS[idx].quality, constellation = info.constellation or 0 })
                        end
                    end
                end
                if #rPool == 0 then
                    for idx, info in pairs(playerHeroes) do
                        if info.owned and idx <= #HERO_CARDS then
                            table.insert(rPool, { cardIdx = idx, quality = HERO_CARDS[idx].quality, constellation = info.constellation or 0 })
                        end
                    end
                end
                for i = 1, math.min(#rPool, #PLAYER_SLOTS) do
                    local item = rPool[i]
                    local heroData = HERO_CARDS[item.cardIdx]
                    if heroData then
                        local rCard = DeepCopy(heroData)
                        rCard.level = playerHeroes[item.cardIdx] and playerHeroes[item.cardIdx].level or 1
                        rCard.constellation = item.constellation
                        rCard.cardIdx = item.cardIdx
                        SetupSlotHero(PLAYER_SLOTS[i], rCard)
                    end
                end
                AggregateBaseStats()
                -- 一次性生成全部兵力
                for si, slot in ipairs(PLAYER_SLOTS) do
                    if slot.filled and slot.card then
                        local batch = GetBatchSizeForSlot(slot)
                        for _ = 1, math.min(batch * 2, MAX_PLAYER_UNITS - #playerUnits) do
                            SpawnUnitFromSlot(slot, true, math.random(1, NUM_LANES), si)
                        end
                        slot.deployCD = 9999
                    end
                end
                for _, slot in ipairs(ENEMY_SLOTS) do
                    if slot.filled and slot.card then
                        local batch = GetBatchSizeForSlot(slot)
                        for _ = 1, math.min(batch * 2, MAX_ENEMY_UNITS - #enemyUnits) do
                            SpawnUnitFromSlot(slot, false, math.random(1, NUM_LANES))
                        end
                        slot.deployCD = 9999
                    end
                end
                InitAISkills()  -- 排位模式启用AI技能
                PlaySFX(AUDIO.sfx_click)
                print(string.format("=== 排位匹配完成 vs %s | 我军:%d 敌军:%d ===", rankedState.opponentName, #playerUnits, #enemyUnits))
            end
        end
        -- 排行榜滚动惯性
        if rankedState.showLeaderboard and not rankedState.rankScroll.isDragging then
            if math.abs(rankedState.rankScroll.vel) > 0.5 then
                rankedState.rankScroll.offset = rankedState.rankScroll.offset + rankedState.rankScroll.vel * dt
                rankedState.rankScroll.vel = rankedState.rankScroll.vel * 0.92
            else
                rankedState.rankScroll.vel = 0
            end
            rankedState.rankScroll.offset = math.max(0, rankedState.rankScroll.offset)
        end
    elseif gameState.phase == "DUMMY_SELECT" then
        menuAnimTimer = menuAnimTimer + dt
        -- 打桩选将滚动惯性
        if not dummyState.isDragging and math.abs(dummyState.scrollVel) > 0.5 then
            dummyState.scrollY = dummyState.scrollY + dummyState.scrollVel * dt
            dummyState.scrollVel = dummyState.scrollVel * 0.92
        elseif not dummyState.isDragging then
            dummyState.scrollVel = 0
        end
        local maxScroll = math.max(0, dummyState.contentH - dummyState.gridH)
        dummyState.scrollY = math.max(0, math.min(maxScroll, dummyState.scrollY))
    elseif gameState.phase == "DUMMY_RESULT" then
        menuAnimTimer = menuAnimTimer + dt
    elseif gameState.phase == "SKILL_DETAIL" then
        menuAnimTimer = menuAnimTimer + dt
        -- skillFxTimer 复用 menuAnimTimer
    elseif gameState.phase == "BATTLE" then
        -- 战斗倍速: 乘以倍率
        local battleDt = dt * (gameState.battleSpeed or 1)
        UpdateAutoBattle(dt)  -- 自动战斗用原始dt节流
        UpdateBattle(battleDt)
    elseif gameState.phase == "WIN" or gameState.phase == "LOSE" then
        gameState.resultTimer = gameState.resultTimer + dt
        if gameState.showRewardPopup then
            gameState.rewardPopupTimer = (gameState.rewardPopupTimer or 0) + dt
        end
    end

    -- 飘字
    for i = #floatTexts, 1, -1 do
        floatTexts[i].timer = floatTexts[i].timer + dt
        if floatTexts[i].timer >= floatTexts[i].duration then table.remove(floatTexts, i) end
    end

    -- 粒子
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.timer = p.timer + dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 50 * dt  -- 重力
        if p.timer >= p.life then table.remove(particles, i) end
    end
end


--- 根据自动行军策略选择车道
function PickLaneByStrategy(strategy)
    if strategy == "mid_focus" then
        -- 全歼中路: 全部兵力集中第3道
        return 3
    elseif strategy == "side_spread" then
        -- 分散侧翼: 全部兵力只走第1和第5道
        if math.random(2) == 1 then return 1 else return 5 end
    else
        -- 五路并进(默认): 随机全车道
        return math.random(1, NUM_LANES)
    end
end


--- 自动释放玩家技能 (autoMarch开启时, 手动操作优先)
function UpdateAutoSkills(dt)
    if not gameState.autoMarch then return end
    if skillTargeting.active then return end  -- 玩家正在手动瞄准，跳过
    if #playerEquippedSkills == 0 then return end
    if #playerUnits == 0 then return end  -- 没有己方单位不释放

    autoSkillState.timer = autoSkillState.timer + dt
    if autoSkillState.timer < autoSkillState.nextTime then return end

    autoSkillState.timer = 0
    autoSkillState.nextTime = autoSkillState.interval + (math.random() - 0.5) * 2.0

    -- 筛选可用(不在CD)的已装备技能
    local readySkills = {}
    for _, techIdx in ipairs(playerEquippedSkills) do
        local skill = SKILL_DEFS[techIdx]
        if skill and skill.unlocked and skill.cooldown <= 0 then
            table.insert(readySkills, techIdx)
        end
    end
    if #readySkills == 0 then return end

    -- 随机选一个技能
    local chosenIdx = readySkills[math.random(1, #readySkills)]
    local skill = SKILL_DEFS[chosenIdx]
    if not skill then return end

    -- 计算目标: 优先瞄准敌方单位
    local targetX, targetY
    if skill.skillType == "line" then
        -- 已去除车道吸附，随机Y位置
        targetX = BATTLE_ZONE.centerX
        targetY = BATTLE_ZONE.top + math.random() * (BATTLE_ZONE.bottom - BATTLE_ZONE.top)
    else
        if #enemyUnits > 0 then
            local target = enemyUnits[math.random(1, #enemyUnits)]
            if target and target.alive then
                targetX = target.x + (math.random() - 0.5) * 30
                targetY = target.y + (math.random() - 0.5) * 20
            end
        end
        if not targetX then
            targetX = BATTLE_ZONE.left + math.random() * (BATTLE_ZONE.right - BATTLE_ZONE.left)
            targetY = BATTLE_ZONE.centerY - math.random() * (BATTLE_ZONE.centerY - BATTLE_ZONE.enemyLine) * 0.5
        end
    end

    -- 释放技能 (复用 CastSkill)
    CastSkill(chosenIdx, targetX, targetY)
    AddFloatText(targetX, targetY - 50, "自动: " .. skill.name, 1.0, { skill.color[1], skill.color[2], skill.color[3] }, 14)
end


-- (武将主动技能系统已移除: techIdx仅作拜师学武技数据, 战斗中不自动释放)


-- ============================================================================
-- 全自动战斗 AI (简单逻辑: 自动买卡上阵、开战、行军、刷新)
-- ============================================================================

--- 自动从商店购买卡牌并放入空槽位
--- @return boolean 是否成功购买了至少一张
function AutoBuyAndPlace()
    local bought = false

    -- 优先级策略:
    -- 1. 优先购买能与已上阵武灵合并升级的卡牌 (同名)
    -- 2. 其次按费用降序购买高品质卡牌
    -- 3. 有空槽才放新卡

    -- 收集已上阵武灵名称 (用于合并升级判断)
    local onBoardNames = {}
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            onBoardNames[slot.card.name] = true
        end
    end

    -- 按费用降序排列索引
    local sortedIndices = {}
    for i = 1, #shopCards do sortedIndices[i] = i end

    -- 排序: 可合并的优先, 同优先级按费用降序
    table.sort(sortedIndices, function(a, b)
        local sa, sb = shopCards[a], shopCards[b]
        local heroA = HERO_CARDS[sa.cardIdx]
        local heroB = HERO_CARDS[sb.cardIdx]
        local mergeA = (heroA and onBoardNames[heroA.name]) and 1 or 0
        local mergeB = (heroB and onBoardNames[heroB.name]) and 1 or 0
        if mergeA ~= mergeB then return mergeA > mergeB end
        return sa.cost > sb.cost
    end)

    for _, i in ipairs(sortedIndices) do
        local shopItem = shopCards[i]
        if not shopItem.sold and gameState.gold >= shopItem.cost then
            -- 先检查能否合并到已有同名槽位
            local heroData = HERO_CARDS[shopItem.cardIdx]
            local mergeSlot = nil
            if heroData then
                for _, slot in ipairs(PLAYER_SLOTS) do
                    if slot.filled and slot.card and slot.card.name == heroData.name then
                        mergeSlot = slot
                        break
                    end
                end
            end

            if mergeSlot then
                -- 合并升级: 购买后升级已有卡牌
                gameState.gold = gameState.gold - shopItem.cost
                shopItem.sold = true
                -- 升级: 等级+1, 属性提升
                local mc = mergeSlot.card
                mc.level = (mc.level or 1) + 1
                mc.constellation = (mc.constellation or 0) + (shopItem.constellation or 0)
                bought = true
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.5,
                    mc.name .. " 升级 Lv" .. mc.level, 1.0, { 255, 220, 80 }, 14)
            else
                -- 找一个空槽位放新卡
                local emptySlot = nil
                for _, slot in ipairs(PLAYER_SLOTS) do
                    if not slot.filled then
                        emptySlot = slot
                        break
                    end
                end
                if not emptySlot then break end -- 没有空槽位了
                -- 购买并放置
                gameState.gold = gameState.gold - shopItem.cost
                shopItem.sold = true
                local cardData = DeepCopy(HERO_CARDS[shopItem.cardIdx])
                cardData.cardIdx = shopItem.cardIdx
                cardData.constellation = shopItem.constellation or 0
                cardData.level = 1
                SetupSlotHero(emptySlot, cardData)
                bought = true
            end
        end
    end
    if bought then RefreshBaseStats() end
    return bought
end


--- 自动战斗主更新 (用原始dt节流, 不受倍速影响)
function UpdateAutoBattle(dt)
    if not gameState.autoBattle then return end
    if gameState.noFullAuto then gameState.autoBattle = false; return end -- 副本禁用全自动

    autoBattleTimer = (autoBattleTimer or 0) + dt

    if gameState.battlePhase == "SHOP" then
        -- SHOP阶段: 每0.3s执行一次, 买卡上阵然后开战
        if autoBattleTimer < 0.3 then return end
        autoBattleTimer = 0

        -- 自动购买并上阵
        local bought = AutoBuyAndPlace()

        -- 如果买不到更多卡 (钱不够或槽位满), 自动开战
        if not bought and GetPlayerFilledSlotCount() > 0 then
            gameState.battlePhase = "FIGHT"
            AggregateBaseStats()
            gameState.autoMarch = true
            gameState.battleTime = 0
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "自动开战!", 1.5, { 120, 255, 180 }, 18)
            PlaySFX(AUDIO.sfx_march)
        end

    elseif gameState.battlePhase == "FIGHT" then
        -- FIGHT阶段: 每1s执行一次
        if autoBattleTimer < 1.0 then return end
        autoBattleTimer = 0

        -- 确保自动行军开启
        if not gameState.autoMarch then
            gameState.autoMarch = true
        end

        -- 商店售罄且有军资时自动刷新
        if GetUnsoldShopCardCount() == 0 and gameState.gold >= GameConfig.REFRESH_COST then
            gameState.gold = gameState.gold - GameConfig.REFRESH_COST
            RefreshShop()
        end

        -- 自动购买新卡并放入空槽位
        AutoBuyAndPlace()
    end
end


function UpdateBattle(dt)
    -- ============================
    -- SHOP: 布阵购卡阶段 - 不出兵, 等玩家点击开战
    -- ============================
    if gameState.battlePhase == "SHOP" then
        return
    end

    -- ============================
    -- FIGHT: 连续出兵+战斗 (无回合, 直到一方基地血量归零)
    -- ============================

    -- === 打桩模式: 30s倒计时 + 伤害追踪 ===
    if gameState.isDummy then
        -- 准备阶段不计时
        if dummyState.prepPhase then return end

        local prevHP = gameState.enemyBaseHP
        -- 继续正常战斗更新（下方逻辑会减少enemyBaseHP）
        -- 但先处理计时
        dummyState.timer = dummyState.timer - dt
        if dummyState.timer <= 0 then
            -- 计算本帧最后伤害
            local frameDmg = prevHP - gameState.enemyBaseHP
            if frameDmg > 0 then
                dummyState.totalDamage = dummyState.totalDamage + frameDmg
            end
            -- 时间到，进入结果页
            gameState.phase = "DUMMY_RESULT"
            gameState.isDummy = false
            gameState.abyssFloor = nil
            gameState.towerFloor = nil
            gameState.isRanked = false
            dummyState.prepPhase = false
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "时间到!", 2.0, { 255, 200, 60 }, 36)
            PlaySFX(AUDIO.sfx_click)
            print(string.format("=== 30s打桩结束 | 总伤害: %d | DPS: %.0f ===",
                math.floor(dummyState.totalDamage), dummyState.totalDamage / 30))
            -- 记录最高打桩伤害 & 上报到桩逼王排行榜
            if dummyState.totalDamage > (playerInfo.bestDummyDamage or 0) then
                playerInfo.bestDummyDamage = dummyState.totalDamage
            end
            ReportDummyScore(dummyState.totalDamage)
            return
        end
    end

    gameState.battleTime = gameState.battleTime + dt

    -- 三国群英传模式: 无军资增长, 无连续出兵
    -- 所有兵力在 InitBattle 中一次性生成, 战损不补充

    -- === 出兵闪光衰减 (原在 UpdateHeroSkills 中) ===
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.spawnFlash and slot.spawnFlash > 0 then slot.spawnFlash = slot.spawnFlash - dt end
    end
    for _, slot in ipairs(ENEMY_SLOTS) do
        if slot.spawnFlash and slot.spawnFlash > 0 then slot.spawnFlash = slot.spawnFlash - dt end
    end

    -- 更新武技技能特效
    UpdateSkillEffects(dt)

    -- AI对手释放武技技能 (排位/讨伐模式)
    UpdateAISkills(dt)

    -- 玩家自动释放技能 (自动行军开启时, 手动优先)
    UpdateAutoSkills(dt)

    -- 更新兵力战斗
    -- RTS 指令标记更新
    if UpdateRTSMarker then UpdateRTSMarker(dt) end

    UpdateUnits(dt, playerUnits, enemyUnits, true)
    UpdateUnits(dt, enemyUnits, playerUnits, false)

    -- === 玩家兵突破敌方临界线 >> 直接攻击敌方大本营 ===
    -- 皇室战争设计: 突破=大伤害, 一个兵过线就很痛
    for i = #playerUnits, 1, -1 do
        local u = playerUnits[i]
        if u.alive and u.x >= BATTLE_ZONE.enemyLine - 8 then
            -- 突破伤害 = 兵ATK全额 + 兵种额外突破 + 剩余HP占比加成
            local classBreak = (u.unitClass and u.unitClass.breakDmg or 1) * 15
            local hpRatio = u.hp / math.max(1, u.maxHp)
            local rawDmg = math.ceil(u.atk * 1.0 + classBreak + u.atk * hpRatio * 0.5)
            -- 突破伤害加成: 兵符 + 装备词条
            local totalBreakPct = (u.sealBreakDmgPct or 0) + (u.equipBreakDmgPct or 0)
            if totalBreakPct > 0 then
                rawDmg = math.ceil(rawDmg * (1 + totalBreakPct / 100))
            end
            local breakDmg = math.max(5, rawDmg)
            gameState.enemyBaseHP = gameState.enemyBaseHP - breakDmg
            AddFloatText(BATTLE_ZONE.enemyLine - 5, u.y, "-" .. breakDmg, 1.0, { 100, 255, 150 }, 26)
            -- 突破爆炸特效 (更大更亮)
            for _ = 1, 8 do
                AddParticle(BATTLE_ZONE.enemyLine, u.y, {
                    vx = (math.random() * 50 + 15), vy = (math.random() - 0.5) * 100,
                    life = 0.6, size = 3, color = { 100, 255, 180 },
                })
            end
            u.alive = false
        end
        if not u.alive then table.remove(playerUnits, i) end
    end

    -- === 敌方兵突破玩家临界线 >> 直接攻击玩家大本营 ===
    for i = #enemyUnits, 1, -1 do
        local u = enemyUnits[i]
        -- 打桩老虎不移动(speed=0)，不会突破临界线，但以防万一也跳过
        if u.alive and u.x <= BATTLE_ZONE.playerLine + 8 then
            if not u.isDummyTiger then
                local classBreak = (u.unitClass and u.unitClass.breakDmg or 1) * 15
                local hpRatio = u.hp / math.max(1, u.maxHp)
                local rawDmg = math.ceil(u.atk * 1.0 + classBreak + u.atk * hpRatio * 0.5)
                local breakDmg = math.max(5, rawDmg)
                gameState.playerBaseHP = gameState.playerBaseHP - breakDmg
                AddFloatText(BATTLE_ZONE.playerLine + 5, u.y, "-" .. breakDmg, 1.0, { 255, 100, 80 }, 26)
                for _ = 1, 8 do
                    AddParticle(BATTLE_ZONE.playerLine, u.y, {
                        vx = -(math.random() * 50 + 15), vy = (math.random() - 0.5) * 100,
                        life = 0.6, size = 3, color = { 255, 80, 60 },
                    })
                end
                u.alive = false
            end
        end
        -- 打桩老虎死亡后不移除，留给下面的复活逻辑处理
        if not u.alive and not u.isDummyTiger then table.remove(enemyUnits, i) end
    end

    -- === 打桩模式: 每帧伤害累计 + 老虎无限轮回 ===
    if gameState.isDummy then
        -- 记录本帧造成的伤害 (enemyBaseHP在上方被减少了)
        local curHP = gameState.enemyBaseHP
        local expectedHP = 999999
        local frameDmg = expectedHP - curHP
        if frameDmg > 0 then
            dummyState.totalDamage = dummyState.totalDamage + frameDmg
            gameState.enemyBaseHP = expectedHP
        end
        -- 统计被击杀老虎的伤害并复活
        local bz = BATTLE_ZONE
        local tigerUC = UNIT_CLASS.DEMON_WARRIOR
        for i = #enemyUnits, 1, -1 do
            local u = enemyUnits[i]
            if u.isDummyTiger and not u.alive then
                -- 累计击杀伤害
                dummyState.totalDamage = dummyState.totalDamage + (u.maxHp or 8000)
                -- 原地复活：在战区随机位置重生
                u.y = bz.top + 20 + math.random() * (bz.bottom - bz.top - 40)
                u.x = bz.centerX + (math.random() - 0.5) * (bz.right - bz.left) * 0.3
                u.hp = u.maxHp
                u.alive = true
                u.flashTimer = 0
                u.animTimer = math.random() * 6.28
            end
        end
        -- 打桩模式也不让玩家基地被打死
        gameState.playerBaseHP = math.max(gameState.playerBaseHP, gameState.playerBaseMax)
        return  -- 打桩模式不走正常超时/胜负判定
    end

    -- 超时判定 (3分钟时限，按剩余HP比例决定胜负)
    if gameState.battleTime >= BATTLE_TIME_LIMIT then
        local pRatio = gameState.playerBaseHP / math.max(1, gameState.playerBaseMax)
        local eRatio = gameState.enemyBaseHP / math.max(1, gameState.enemyBaseMax)
        if pRatio > eRatio then
            -- 玩家HP比例更高 >> 胜利
            gameState.enemyBaseHP = 0
            gameState.phase = "WIN"
            gameState.resultTimer = 0
            gameState.winJade = math.random(GameConfig.JADE_PER_WIN_MIN, GameConfig.JADE_PER_WIN_MAX)
            gameState.winExp = GameConfig.EXP_PER_WIN
            playerInfo.jade = playerInfo.jade + gameState.winJade
            playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_WIN
            CheckPlayerLevelUp()
            local reward = GrantRandomEquipment(stageMaxTier or 2)
            gameState.winEquip = reward
            gameState.winFragDrops = GenerateBattleSkillFragDrop(stageMaxTier or 2)
            OnBattleVictory()
            AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "时间到-大捷!", 3.0, { 255, 230, 80 }, 48)
            PlaySFX(AUDIO.sfx_win)
        elseif eRatio > pRatio then
            -- 敌方HP比例更高 >> 失败
            gameState.playerBaseHP = 0
            gameState.phase = "LOSE"
            gameState.resultTimer = 0
            playerInfo.jade = playerInfo.jade + GameConfig.JADE_PER_LOSE
            playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_LOSE
            CheckPlayerLevelUp()
            OnBattleEnd()
            AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "时间到-败北...", 3.0, { 255, 80, 80 }, 48)
            PlaySFX(AUDIO.sfx_lose)
        else
            -- 完全平局 >> 判定为失败
            gameState.playerBaseHP = 0
            gameState.phase = "LOSE"
            gameState.resultTimer = 0
            playerInfo.jade = playerInfo.jade + GameConfig.JADE_PER_LOSE
            playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_LOSE
            CheckPlayerLevelUp()
            OnBattleEnd()
            AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "时间到-平局", 3.0, { 200, 180, 120 }, 48)
            PlaySFX(AUDIO.sfx_lose)
        end
        return
    end

    -- 胜负判定
    if gameState.enemyBaseHP <= 0 then
        gameState.enemyBaseHP = 0
        gameState.phase = "WIN"
        gameState.resultTimer = 0
        -- 保存奖励信息用于结算界面展示
        gameState.winJade = math.random(GameConfig.JADE_PER_WIN_MIN, GameConfig.JADE_PER_WIN_MAX)
        gameState.winExp = GameConfig.EXP_PER_WIN
        playerInfo.jade = playerInfo.jade + gameState.winJade
        playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_WIN
        CheckPlayerLevelUp()
        -- 战斗胜利奖励随机兵甲
        local reward = GrantRandomEquipment(stageMaxTier or 2)
        gameState.winEquip = reward  -- 保存装备掉落用于展示
        gameState.winFragDrops = GenerateBattleSkillFragDrop(stageMaxTier or 2)
        OnBattleVictory()
        AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "大捷!", 3.0, { 255, 230, 80 }, 48)
        PlaySFX(AUDIO.sfx_win)
        return
    elseif gameState.playerBaseHP <= 0 then
        gameState.playerBaseHP = 0
        gameState.phase = "LOSE"
        gameState.resultTimer = 0
        playerInfo.jade = playerInfo.jade + GameConfig.JADE_PER_LOSE
        playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_LOSE
        CheckPlayerLevelUp()
        OnBattleEnd()
        AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "败北...", 3.0, { 255, 80, 80 }, 48)
        PlaySFX(AUDIO.sfx_lose)
        return
    end
end
