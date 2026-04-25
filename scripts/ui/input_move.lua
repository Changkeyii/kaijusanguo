-- ui/input_move.lua - 三国武灵录 (从 input.lua 拆分)
function HandleMoveLogic(sx, sy, touchId)
    -- GM手势检测 (仅主界面可触发, 其他界面忽略)
    if gameState.phase == "MENU" or gameState.phase == "HOME" then
        local _gdx, _gdy = ScreenToDesign(sx, sy)
        local GMGesture = require("ui.gm_gesture")
        if GMGesture.OnMove(_gdx, _gdy) then
            -- 触发! 打开GM面板
            local GMPanel = require("ui.gm_panel")
            GMPanel.Open()
            gameState.phase = "GM_PANEL"
            return
        end
    end

    -- GM面板移动处理
    if gameState.phase == "GM_PANEL" then
        local GMPanel = require("ui.gm_panel")
        if GMPanel.IsActive() then
            if GMPanel.GetTab() == "editor" then
                local TDEditor = require("systems.td.td_editor")
                if TDEditor.IsActive() then TDEditor.handleMove(sx, sy) end
            end
        end
        return
    end

    -- 战斗地图拖拽平移
    if _battlePanning and (touchId == _battlePanTouchId or touchId == -1) then
        local curDX, curDY = ScreenToDesign(sx, sy)
        local deltaDX = curDX - _battlePanLastDX
        local deltaDY = curDY - _battlePanLastDY
        -- 设计坐标中移动量 → 转换为战场平移 (拖拽方向与平移方向相反)
        battlePanX = battlePanX - deltaDX / battleZoom
        battlePanY = battlePanY - deltaDY / battleZoom
        ClampBattlePan()
        _battlePanLastDX = curDX
        _battlePanLastDY = curDY
        return
    end

    -- 塔防编辑器移动 (已合并到 GM_PANEL, 在顶部处理)
    -- 塔防选择界面滚动
    if gameState.phase == "TD_SELECT" and tdSelectState and tdSelectState.isDragging then
        local TDSelect = require("systems.td.td_select")
        TDSelect.handleMove(sx, sy, touchId)
        return
    end
    -- 塔防战斗移动
    if gameState.phase == "TD_BATTLE" and tdState then
        -- 转盘奖励动画期间屏蔽移动
        local TDReward = require("systems.td.td_reward")
        if TDReward.IsActive() then return end
        local TDInput = require("systems.td.td_input")
        TDInput.handleMove(sx, sy, touchId)
        return
    end

    -- 世界地图城池列表拖拽滚动
    if gameState.phase == "WORLD_MAP" and worldMapState.cityListDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if worldMapState.cityListDragLastY then
            local delta = worldMapState.cityListDragLastY - dy  -- 向上拖=向下滚
            local totalH = worldMapState._cityListTotalH or 0
            local visibleH = worldMapState._cityListVisibleH or 1
            if totalH > visibleH then
                local scroll = worldMapState.cityListScroll or 0
                scroll = scroll + delta
                scroll = math.max(0, math.min(totalH - visibleH, scroll))
                worldMapState.cityListScroll = scroll
            end
        end
        worldMapState.cityListDragLastY = dy
        return
    end

    -- 世界地图回合报告拖拽滚动
    if gameState.phase == "WORLD_MAP" and worldMapState.phase == "TURN_REPORT" and worldMapState.reportDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if worldMapState.reportDragLastY then
            local delta = worldMapState.reportDragLastY - dy  -- 向上拖=正值=向下滚
            local lineH = 19
            local lineDelta = delta / lineH
            local totalItems = worldMapState.turnReport and #worldMapState.turnReport or 0
            local maxScroll = math.max(0, totalItems - 5)
            worldMapState.reportScroll = math.max(0, math.min(maxScroll, (worldMapState.reportScroll or 0) + lineDelta))
        end
        worldMapState.reportDragLastY = dy
        return
    end

    -- 左侧栏拖拽滚动
    if leftSidebarScroll.isDragging and gameState.phase == "MENU" then
        local _, dy = ScreenToDesign(sx, sy)
        if leftSidebarScroll.dragLastY then
            local delta = leftSidebarScroll.dragLastY - dy  -- 向上拖 = 正值 = 向下滚
            leftSidebarScroll.y = leftSidebarScroll.y + delta
            local maxScroll = math.max(0, leftSidebarScroll.contentH - leftSidebarScroll.viewH)
            leftSidebarScroll.y = math.max(0, math.min(leftSidebarScroll.y, maxScroll))
            local newVel = delta / (1 / 60)
            leftSidebarScroll.vel = leftSidebarScroll.vel * 0.3 + newVel * 0.7
        end
        leftSidebarScroll.dragLastY = dy
        return
    end

    -- 英雄选择弹窗滚动
    if sealMgrState.showHeroPicker and heroPickerScroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local delta = (heroPickerScroll.dragLastY or dy) - dy
        heroPickerScroll.vel = delta / (1 / 60)
        heroPickerScroll.y = (heroPickerScroll.y or 0) + delta
        local maxScroll = math.max(0, (heroPickerScroll.contentH or 0) - (heroPickerScroll.viewH or 0))
        heroPickerScroll.y = math.max(0, math.min(heroPickerScroll.y, maxScroll))
        heroPickerScroll.dragLastY = dy
        return
    end

    -- 兵符替换弹窗滚动
    if sealReplaceState.show and sealReplaceState.scroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local scrl = sealReplaceState.scroll
        local delta = (scrl.dragLastY or dy) - dy
        scrl.vel = delta / (1 / 60)
        scrl.y = (scrl.y or 0) + delta
        local maxScroll = math.max(0, (scrl.contentH or 0) - (scrl.viewH or 0))
        scrl.y = math.max(0, math.min(scrl.y, maxScroll))
        scrl.dragLastY = dy
        return
    end

    -- 奖励弹窗滚动
    if gameState.rewardDragging and gameState.showRewardPopup then
        local _, dy = ScreenToDesign(sx, sy)
        local delta = (gameState.rewardLastTouchY or dy) - dy
        gameState.rewardVel = delta / (1 / 60)
        gameState.rewardScrollY = (gameState.rewardScrollY or 0) + delta
        -- 使用与渲染一致的 clamping（scrollY ≤ 0 向上滚）
        local contentH = gameState.rewardContentH or 0
        local listH = gameState.rewardListH or 300
        local minScroll = math.min(0, -(contentH - listH))
        gameState.rewardScrollY = math.max(minScroll, math.min(0, gameState.rewardScrollY))
        gameState.rewardLastTouchY = dy
        return
    end

    -- 统一规则弹窗滚动
    if phaseRulePopup.show and phaseRulePopup.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local delta = phaseRulePopup.lastTouchY - dy
        phaseRulePopup.vel = delta / (1 / 60)
        phaseRulePopup.scrollY = (phaseRulePopup.scrollY or 0) + delta
        local maxScroll = math.max(0, (phaseRulePopup.contentH or 0) - (phaseRulePopup.viewH or 0))
        phaseRulePopup.scrollY = math.max(0, math.min(phaseRulePopup.scrollY, maxScroll))
        phaseRulePopup.lastTouchY = dy
        return
    end

    -- 战斗规则弹窗滚动
    if battleRulesState.show and battleRulesState.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local delta = battleRulesState.lastTouchY - dy
        battleRulesState.vel = delta / (1 / 60)  -- 估算速度
        battleRulesState.scrollY = battleRulesState.scrollY + delta
        local maxScroll = math.max(0, battleRulesState.contentH - battleRulesState.viewH)
        battleRulesState.scrollY = math.max(0, math.min(battleRulesState.scrollY, maxScroll))
        battleRulesState.lastTouchY = dy
        return
    end



    -- ======== 按钮位置调整模式拖拽 ========
    if settingsPage.btnAdjustMode then
        local dx, dy = ScreenToDesign(sx, sy)
        -- 缩放滑条拖拽
        if settingsPage.adjDraggingScale and settingsPage.adjScaleSliderRect then
            local r = settingsPage.adjScaleSliderRect
            local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
            settingsPage.adjScale = 0.5 + ratio * 1.5  -- 0.5~2.0
            return
        end
        -- 当前选中组拖拽
        if settingsPage.adjDragging then
            local deltaX = dx - settingsPage.adjDragStartX
            local deltaY = dy - settingsPage.adjDragStartY
            local ag = settingsPage.adjActiveGroup or "skill"
            if ag == "skill" then
                settingsPage.adjOffsetX = settingsPage.adjOffsetX + deltaX
                settingsPage.adjOffsetY = settingsPage.adjOffsetY + deltaY
            elseif ag == "rightBtn" then
                settingsPage.adjRightBtnOffsetX = settingsPage.adjRightBtnOffsetX + deltaX
                settingsPage.adjRightBtnOffsetY = settingsPage.adjRightBtnOffsetY + deltaY
            elseif ag == "infoPanel" then
                settingsPage.adjInfoPanelOffsetX = settingsPage.adjInfoPanelOffsetX + deltaX
                settingsPage.adjInfoPanelOffsetY = settingsPage.adjInfoPanelOffsetY + deltaY
            elseif ag == "hud" then
                settingsPage.adjHudOffsetX = settingsPage.adjHudOffsetX + deltaX
                settingsPage.adjHudOffsetY = settingsPage.adjHudOffsetY + deltaY
            end
            settingsPage.adjDragStartX = dx
            settingsPage.adjDragStartY = dy
            return
        end
        return
    end

    -- ======== 设置界面拖拽 ========
    if settingsPage.isOpen and gameState.phase == "MENU" then
        local dx, dy = ScreenToDesign(sx, sy)
        -- 音乐滑条拖拽
        if settingsPage.draggingMusic and settingsPage.musicSliderRect then
            local r = settingsPage.musicSliderRect
            local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
            gameSettings.musicVolume = ratio
            if audioState.bgmSource then audioState.bgmSource.gain = ratio end
            return
        end
        -- 音效滑条拖拽
        if settingsPage.draggingSfx and settingsPage.sfxSliderRect then
            local r = settingsPage.sfxSliderRect
            local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
            gameSettings.sfxVolume = ratio
            return
        end
        -- 精灵上限滑条拖拽
        if settingsPage.draggingSpriteLimit and settingsPage.spriteLimitSliderRect then
            local r = settingsPage.spriteLimitSliderRect
            local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
            gameSettings.spriteLimit = math.floor(500 + ratio * 4500 + 0.5)
            gameSettings.spriteLimit = math.floor(gameSettings.spriteLimit / 50 + 0.5) * 50
            gameSettings.spriteLimit = math.max(500, math.min(5000, gameSettings.spriteLimit))
            return
        end
        return
    end

    -- 策略选项条: 长按检测 + 拖拽高亮（也支持松手后点击）
    if strategyWheelState.pressing and touchId == strategyWheelState.touchId then
        local elapsed = gameState.gameTime - strategyWheelState.startTime
        if not strategyWheelState.show and elapsed >= STRATEGY_LONG_PRESS then
            strategyWheelState.show = true
        end
        if strategyWheelState.show and autoMarchBtnRect then
            local dx2, dy2 = ScreenToDesign(sx, sy)
            local ab = autoMarchBtnRect
            local cardW, cardH, gap2 = 115, 64, 8
            local sX = ab.cx - ab.r - 12
            local cCY = ab.cy - ab.r - cardH / 2 - 16
            local newSel = 0
            for i = 1, #MARCH_STRATEGIES do
                local cRight = sX - (i - 1) * (cardW + gap2)
                local cLeft = cRight - cardW
                local cTop = cCY - cardH / 2
                local cBot = cCY + cardH / 2
                if dx2 >= cLeft and dx2 <= cRight and dy2 >= cTop - 10 and dy2 <= cBot + 10 then
                    newSel = i
                    break
                end
            end
            strategyWheelState.selected = newSel
        end
        return
    end

    -- 武技技能瞄准拖拽
    if skillTargeting.active and touchId == skillTargeting.touchId then
        local tdx, tdy = ScreenToDesign(sx, sy)
        -- 限制在战场区域内
        skillTargeting.dx = math.max(BATTLE_ZONE.left, math.min(BATTLE_ZONE.right, tdx))
        skillTargeting.dy = math.max(BATTLE_ZONE.top, math.min(BATTLE_ZONE.bottom, tdy))
        return
    end

    -- 天命赐福滚动拖拽（贡献榜独立滚动）
    if gameState.phase == "WELFARE" and welfareState.contribScroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local cs = welfareState.contribScroll
        if cs.dragLastY then
            local delta = dy - cs.dragLastY
            cs.offset = cs.offset + delta
            cs.vel = delta * 15
        end
        cs.dragLastY = dy
        return
    end

    -- 战令通行证横向拖拽（奖励轨道）
    if gameState.phase == "BATTLE_PASS" and battlePassUIState.isDraggingReward then
        local dx2, _ = ScreenToDesign(sx, sy)
        local delta = dx2 - battlePassUIState.dragStartX
        local bpCfg = GameConfig.BATTLE_PASS
        local cellW, cellGap = 90, 8
        local totalScrollW = bpCfg.maxLevel * (cellW + cellGap) - cellGap + 40
        local maxScroll = math.max(0, totalScrollW - (DESIGN_W - 50))
        battlePassUIState.rewardScrollX = math.max(-maxScroll, math.min(0, battlePassUIState.dragStartScrollX + delta))
        return
    end

    -- 战令通行证纵向拖拽（任务列表）
    if gameState.phase == "BATTLE_PASS" and battlePassUIState.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if battlePassUIState.dragLastY then
            local delta = dy - battlePassUIState.dragLastY
            battlePassUIState.scrollY = battlePassUIState.scrollY + delta
            local newVel = delta * 18
            battlePassUIState.scrollVel = (battlePassUIState.scrollVel or 0) * 0.3 + newVel * 0.7
        end
        battlePassUIState.dragLastY = dy
        return
    end

    -- 天命赐福滚动拖拽（下方内容区）
    -- 阵营成员列表滚动拖拽
    if gameState.phase == "FACTION" and factionUI.scroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local fs = factionUI.scroll
        if fs.dragLastY then
            local delta = fs.dragLastY - dy
            fs.offset = (fs.offset or 0) + delta
            fs.vel = delta / (1 / 60)
            if fs.offset < 0 then fs.offset = 0 end
        end
        fs.dragLastY = dy
        return
    end

    -- 交易行滚动拖拽
    if gameState.phase == "TRADE" and tradeState.scroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local ts = tradeState.scroll
        if ts.dragLastY then
            local delta = ts.dragLastY - dy
            ts.offset = (ts.offset or 0) + delta
            ts.vel = delta / (1 / 60)
            if ts.offset < 0 then ts.offset = 0 end
        end
        ts.dragLastY = dy
        return
    end

    -- 邮件列表滚动拖拽
    if gameState.phase == "MAIL_BOX" and welfareState.mail.scroll and welfareState.mail.scroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local ms = welfareState.mail.scroll
        if ms.dragLastY then
            local delta = ms.dragLastY - dy
            ms.offset = (ms.offset or 0) + delta
            ms.vel = delta / (1 / 60)
            if ms.offset < 0 then ms.offset = 0 end
        end
        ms.dragLastY = dy
        return
    end

    if gameState.phase == "WELFARE" and welfareState.scroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        local ws = welfareState.scroll
        if ws.dragLastY then
            local delta = dy - ws.dragLastY
            ws.offset = ws.offset + delta
            ws.vel = delta * 15
        end
        ws.dragLastY = dy
        return
    end

    -- 每日任务/成就滚动拖拽（改进触摸跟踪）
    if gameState.phase == "PROGRESS" and progressUIState.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if progressUIState.dragLastY then
            local delta = dy - progressUIState.dragLastY
            progressUIState.scrollY = progressUIState.scrollY + delta
            -- 加权移动平均速度（更稳定的惯性）
            local newVel = delta * 18
            progressUIState.scrollVel = progressUIState.scrollVel * 0.3 + newVel * 0.7
        end
        progressUIState.dragLastY = dy
        return
    end

    -- 编辑器石台: 多选拖拽
    if gameState.phase == "DEV_EDITOR" and editorState.slotPressKey then
        local dx, dy = ScreenToDesign(sx, sy)
        local pr = editorState.previewRect
        if not pr then return end
        local DRAG_THRESHOLD = 3 -- 设计像素
        -- 尚未开始拖拽 → 检测是否超过阈值
        if not editorState.slotDragging then
            local mdx = math.abs(dx - (editorState.slotPressStartX or dx))
            local mdy = math.abs(dy - (editorState.slotPressStartY or dy))
            if mdx < DRAG_THRESHOLD and mdy < DRAG_THRESHOLD then return end
            -- 超过阈值 → 开始拖拽, 记录所有选中槽位的原始位置 + undo 快照
            editorState.slotDragging = true
            local startBgX = (dx - pr.x) * (BG_W / pr.w)
            local startBgY = (dy - pr.y) * (BG_H / pr.h)
            editorState.dragStartBgX = startBgX
            editorState.dragStartBgY = startBgY
            local lidx = editorState.editLayoutIdx or 1
            local layout = BATTLE_LAYOUTS[lidx]
            if not layout then return end
            -- 保存原始位置 + 批量 undo 快照
            local origPos = {}
            local batch = {}
            for key, _ in pairs(editorState.selectedSlots) do
                local stype, sidxStr = key:match("^(%a+)_(%d+)$")
                local sidx = tonumber(sidxStr)
                if stype and sidx then
                    local slots = stype == "player" and layout.playerSlots or layout.enemySlots
                    if slots[sidx] then
                        origPos[key] = { slots[sidx][1], slots[sidx][2] }
                        batch[#batch + 1] = { layoutIdx = lidx, slotType = stype, slotIdx = sidx,
                            oldX = slots[sidx][1], oldY = slots[sidx][2] }
                    end
                end
            end
            editorState.dragOrigPositions = origPos
            if #batch > 0 then
                if #slotUndoStack >= 50 then table.remove(slotUndoStack, 1) end
                slotUndoStack[#slotUndoStack + 1] = { batch = batch }
            end
        end
        -- 已在拖拽中 → 计算 delta, 应用到所有选中槽位
        if editorState.slotDragging and editorState.dragOrigPositions then
            local curBgX = (dx - pr.x) * (BG_W / pr.w)
            local curBgY = (dy - pr.y) * (BG_H / pr.h)
            local deltaBgX = curBgX - (editorState.dragStartBgX or curBgX)
            local deltaBgY = curBgY - (editorState.dragStartBgY or curBgY)
            local lidx = editorState.editLayoutIdx or 1
            local layout = BATTLE_LAYOUTS[lidx]
            if layout then
                for key, orig in pairs(editorState.dragOrigPositions) do
                    local stype, sidxStr = key:match("^(%a+)_(%d+)$")
                    local sidx = tonumber(sidxStr)
                    if stype and sidx then
                        local slots = stype == "player" and layout.playerSlots or layout.enemySlots
                        if slots[sidx] then
                            slots[sidx][1] = math.floor(math.max(0, math.min(BG_W, orig[1] + deltaBgX)))
                            slots[sidx][2] = math.floor(math.max(0, math.min(BG_H, orig[2] + deltaBgY)))
                        end
                    end
                end
            end
        end
        return
    end

    -- 编辑器滚动拖拽
    if gameState.phase == "DEV_EDITOR" and editorState.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if editorState.dragLastY then
            local delta = dy - editorState.dragLastY
            editorState.scrollY = editorState.scrollY + delta
            local newVel = delta * 18
            editorState.scrollVel = editorState.scrollVel * 0.3 + newVel * 0.7
        end
        editorState.dragLastY = dy
        return
    end

    -- 残片仓库滚动拖拽
    if gameState.phase == "GACHA" and gachaState.showFragShop and fragShopScroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if fragShopScroll.dragLastY then
            local delta = dy - fragShopScroll.dragLastY
            fragShopScroll.offset = fragShopScroll.offset + delta
            fragShopScroll.vel = delta * 15
        end
        fragShopScroll.dragLastY = dy
        return
    end

    -- 战力排行榜独立界面滚动拖拽
    if gameState.phase == "POWER_RANK" then
        local curScroll
        if welfareState.rankTab == "realm" then
            curScroll = welfareState.realmScroll
        elseif welfareState.rankTab == "faction" then
            curScroll = welfareState.factionRankScroll
        else curScroll = welfareState.powerScroll end
        if curScroll.isDragging then
            local _, dy = ScreenToDesign(sx, sy)
            if curScroll.dragLastY then
                local delta = dy - curScroll.dragLastY
                curScroll.offset = curScroll.offset + delta
                curScroll.vel = delta * 15
            end
            curScroll.dragLastY = dy
            return
        end
    end

    -- 贡献榜详情页滚动拖拽
    if gameState.phase == "CONTRIB_RANK" and welfareState.contribDetailScroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if welfareState.contribDetailScroll.dragLastY then
            local delta = dy - welfareState.contribDetailScroll.dragLastY
            welfareState.contribDetailScroll.offset = welfareState.contribDetailScroll.offset + delta
            welfareState.contribDetailScroll.vel = delta * 15
        end
        welfareState.contribDetailScroll.dragLastY = dy
        return
    end

    -- 新版EquipUI触摸移动委托
    if gameState.phase == "EQUIP" and EquipUI.isVisible then
        local dx, dy = ScreenToDesign(sx, sy)
        EquipUI.HandleTouchMove(dx, dy)
        return
    end

    -- 兵甲列表滚动拖拽（旧版）
    if gameState.phase == "EQUIP" and equipScreenState.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if equipScreenState.dragLastY then
            local delta = dy - equipScreenState.dragLastY
            equipScreenState.scrollY = equipScreenState.scrollY + delta
            equipScreenState.scrollVel = delta * 15
        end
        equipScreenState.dragLastY = dy
        return
    end

    -- 兵甲图录滚动拖拽
    if gameState.phase == "EQUIP_CODEX" and equipCodexState.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if equipCodexState.dragLastY then
            local delta = dy - equipCodexState.dragLastY
            equipCodexState.scrollY = equipCodexState.scrollY + delta
            equipCodexState.scrollVel = delta * 15
        end
        equipCodexState.dragLastY = dy
        return
    end

    -- 兵符管理滚动拖拽（选中分解列表）
    if gameState.phase == "SEAL_MGR" and sealMgrScroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if sealMgrScroll.dragLastY then
            local delta = (sealMgrScroll.dragLastY) - dy
            sealMgrScroll.vel = delta / (1 / 60)
            sealMgrScroll.y = (sealMgrScroll.y or 0) + delta
        end
        sealMgrScroll.dragLastY = dy
        return
    end

    -- 武灵详情页滚动拖拽
    if gameState.phase == "HERO_DETAIL" and heroDetailScroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if heroDetailScroll.dragLastY then
            local delta = dy - heroDetailScroll.dragLastY
            heroDetailScroll.y = heroDetailScroll.y + delta
            heroDetailScroll.vel = delta * 15
        end
        heroDetailScroll.dragLastY = dy
        return
    end

    -- 玩家详情页滚动拖拽
    if gameState.phase == "PLAYER_DETAIL" and playerDetailScroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if playerDetailScroll.dragLastY then
            local delta = dy - playerDetailScroll.dragLastY
            playerDetailScroll.y = playerDetailScroll.y + delta
            playerDetailScroll.vel = delta * 15
        end
        playerDetailScroll.dragLastY = dy
        return
    end

    -- 武将录滚动拖拽
    if gameState.phase == "CODEX" and codexScroll.isDragging then
        local _, dy = ScreenToDesign(sx, sy)
        if codexScroll.dragLastY then
            local delta = dy - codexScroll.dragLastY
            codexScroll.y = codexScroll.y + delta
            codexScroll.vel = delta * 15  -- 用于惯性
        end
        codexScroll.dragLastY = dy
        return
    end

    -- 武技横向滚动拖拽
    if gameState.phase == "SKILL_CODEX" and skillCodexState.isDragging then
        local dx, dy = ScreenToDesign(sx, sy)
        if skillCodexState.dragLastX then
            local deltaX = dx - skillCodexState.dragLastX
            skillCodexState.scrollX = (skillCodexState.scrollX or 0) - deltaX
            skillCodexState.scrollVelX = -deltaX * 15
        end
        skillCodexState.dragLastX = dx
        skillCodexState.dragLastY = dy
        return
    end



    -- 天命赐福无滚动，不需要拖拽处理

    if not longPressState.pressing then
        if dragState.active and (touchId == dragState.touchId) then
            dragState.lx, dragState.ly = ScreenToLogical(sx, sy)
        end
        return
    end

    local moveDist = math.abs(sx - pressStartSX) + math.abs(sy - pressStartSY)
    local dpr = GetTouchDPR()
    if moveDist > 10 * dpr then
        longPressState.pressing = false
        longPressState.active = false

        -- 石台己方卡牌 >> 拖拽移位 (DEPLOY: 换位, FIGHT: 换线/部署)
        if longPressState.card and longPressState.isSlot and not longPressState.isEnemy
           and (gameState.battlePhase == "DEPLOY" or gameState.battlePhase == "FIGHT") then
            local slotIdx = longPressState.slotIdx
            local slot = PLAYER_SLOTS[slotIdx]
            if slot and slot.filled and slot.card then
                dragState.active = true
                dragState.card = slot.card
                dragState.fromSlot = true
                dragState.fromSlotIdx = slotIdx
                dragState.fromShop = false
                dragState.fromInventory = false
                dragState.lx, dragState.ly = ScreenToLogical(sx, sy)
                dragState.touchId = touchId
                -- 暂时清空源槽位 (拖拽中显示为空)
                slot.filled = false
                slot.card = nil
            end
        -- 背包卡牌 >> 拖拽
        elseif longPressState.card and not longPressState.isSlot and not longPressState.isEnemy then
            dragState.active = true
            dragState.card = longPressState.card
            dragState.invIdx = longPressState.slotIdx
            dragState.fromInventory = true
            dragState.fromSlot = false
            dragState.fromShop = false
            dragState.lx, dragState.ly = ScreenToLogical(sx, sy)
            dragState.touchId = touchId
        end
        longPressState.card = nil
    end
end


--- 残片仓库松手处理
