-- ui/battle_hud_controls.lua - 三国武灵录 (从 battle_hud.lua 拆分)
-- ============================================================================
-- 战斗按钮 (右侧垂直排列, 设计坐标)
-- ============================================================================

function DrawBattleButtons()
    if fontId < 0 then return end

    local isSHOP = (gameState.battlePhase == "DEPLOY")
    local t = gameState.gameTime

    nvgFontFaceId(vg, GetMainFont())

    -- 右侧按钮参数
    local btnW = 80
    local btnH = 36
    local btnGap = 10
    local rightMargin = 6

    local rbOfsX = gameSettings.rightBtnOffsetX or 0
    local rbOfsY = gameSettings.rightBtnOffsetY or 0

    -- 基准Y=136 避免被TapTap右上角按钮遮挡
    local startY = 136 + rbOfsY
    local bx = DESIGN_W - btnW - rightMargin + rbOfsX
    local curY = startY

    -- 清空不再使用的按钮 rect
    shopRefreshBtnRect      = nil
    battleChangeBgBtnRect   = nil
    battleRuleBtnRect       = nil


    if isSHOP then
        -- ========== SHOP 阶段: [开始] 大绿按钮 + [撤退] ==========

        -- [开始] 大按钮 - 绿色脉冲, 更高
        local startBtnH = 50
        local pulse = 0.7 + 0.3 * math.sin(t * 2.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, startBtnH, 6)
        nvgFillColor(vg, nvgRGBA(15, 80, 35, math.floor(230 * pulse))); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, startBtnH, 6)
        nvgStrokeColor(vg, nvgRGBA(60, 255, 120, math.floor(220 * pulse)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local startLabel = (gameState.battlePhase == "DEPLOY") and "出征" or "开始"
        DrawWhiteInkText(bx + btnW / 2, curY + startBtnH / 2, startLabel)
        shopFightBtnRect = { x = bx, y = curY, w = btnW, h = startBtnH, isDesign = true }
        curY = curY + startBtnH + btnGap

        -- [撤退] 小按钮 - 红色
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 4)
        nvgFillColor(vg, nvgRGBA(70, 18, 18, 200)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 4)
        nvgStrokeColor(vg, nvgRGBA(200, 80, 60, 160))
        nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(bx + btnW / 2, curY + btnH / 2, "撤退")
        battleBackBtnRect = { x = bx, y = curY, w = btnW, h = btnH, isDesign = true }

        -- SHOP阶段无倍速/自动按钮
        battleSpeedBtnRect  = nil
        autoBattleBtnRect   = nil
        autoMarchBtnRect    = nil
        behaviorModeBtnRect = nil

    else
        -- ========== FIGHT 阶段: [撤退] + [自动] + [倍速] ==========

        shopFightBtnRect = nil

        -- [撤退] 按钮
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 4)
        nvgFillColor(vg, nvgRGBA(70, 18, 18, 200)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 4)
        nvgStrokeColor(vg, nvgRGBA(200, 80, 60, 160))
        nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(bx + btnW / 2, curY + btnH / 2, "撤退")
        battleBackBtnRect = { x = bx, y = curY, w = btnW, h = btnH, isDesign = true }
        curY = curY + btnH + btnGap

        -- [自动 ON/OFF] 按钮
        do
            local isAuto = gameState.autoBattle
            local blocked = gameState.noFullAuto
            local autoPulse = isAuto and (0.7 + 0.3 * math.sin(t * 4)) or 1.0
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 4)
            if blocked then
                nvgFillColor(vg, nvgRGBA(40, 35, 35, 160)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 100))
            elseif isAuto then
                nvgFillColor(vg, nvgRGBA(15, 60, 30, math.floor(230 * autoPulse))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 255, 140, math.floor(200 * autoPulse)))
            else
                nvgFillColor(vg, nvgRGBA(28, 24, 20, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(130, 120, 110, 130))
            end
            nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local autoLabel = blocked and "禁用" or (isAuto and "自动 ON" or "自动 OFF")
            DrawWhiteInkText(bx + btnW / 2, curY + btnH / 2, autoLabel)
            autoBattleBtnRect = { x = bx, y = curY, w = btnW, h = btnH, isDesign = true }
            curY = curY + btnH + btnGap
        end

        -- [倍速 ×N] 按钮
        do
            local spd = gameState.battleSpeed or 1
            local spdOn = spd > 1
            local spdPulse = spdOn and (0.7 + 0.3 * math.sin(t * 5)) or 1.0
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 4)
            if spdOn then
                nvgFillColor(vg, nvgRGBA(70, 45, 8, math.floor(220 * spdPulse))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(255, 200, 60, math.floor(200 * spdPulse)))
            else
                nvgFillColor(vg, nvgRGBA(28, 24, 20, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(130, 120, 110, 130))
            end
            nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + btnW / 2, curY + btnH / 2, "倍速 ×" .. tostring(spd))
            battleSpeedBtnRect = { x = bx, y = curY, w = btnW, h = btnH, isDesign = true }
            curY = curY + btnH + btnGap
        end

        behaviorModeBtnRect = nil

        -- 战术标签 (行为指令按钮下方, 有战术时显示)
        do
            local tacticId = rawget(_G, "battleTacticId")
            if tacticId then
                local tacticName = tacticId
                for _, td in ipairs(TACTIC_DEFS or {}) do
                    if td.id == tacticId then tacticName = td.name; break end
                end
                local tagH = 24
                nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, tagH, 3)
                nvgFillColor(vg, nvgRGBA(45, 15, 65, 190)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(180, 90, 255, 150))
                nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(bx + btnW / 2, curY + tagH / 2, tacticName)
            end
        end

        autoMarchBtnRect = nil  -- 自动行军圈在 DrawBottomActionBar 中处理
    end
end


-- ============================================================================
-- 右下角操作栏: 自动行军 + 预留技能按钮区域 (设计坐标)
-- ============================================================================
function DrawBottomActionBar()
    if fontId < 0 then return end
    if gameState.phase ~= "BATTLE" and gameState.phase ~= "WIN" and gameState.phase ~= "LOSE" then
        autoMarchBtnRect = nil
        skillBtnRects = {}
        return
    end
    local isDeployPhase = (gameState.battlePhase == "DEPLOY")
    if gameState.battlePhase ~= "FIGHT" and not isDeployPhase then
        autoMarchBtnRect = nil
        skillBtnRects = {}
        return
    end

    local t = gameState.gameTime
    nvgFontFaceId(vg, GetMainFont())

    -- ======== 右下角武技圈 (两个并排) ========
    --        [武技1][武技2]
    local btnSc = gameSettings.btnScale or 1.0
    local R = math.floor(46 * btnSc)        -- 圆形按钮半径 (放大至46, 直径92px)
    local gap = math.floor(10 * btnSc)      -- 圈之间间距
    local marginR = 10 + safeInsets.right  -- 右边距(含安全区)
    local marginB = 14 + safeInsets.bottom -- 底部边距(含安全区)

    local btnOfsX = gameSettings.btnOffsetX or 0
    local btnOfsY = gameSettings.btnOffsetY or 0
    local bottomCY = BATTLE_ZONE.bottom - marginB - R + btnOfsY
    local rightCX = DESIGN_W - marginR - R + btnOfsX
    -- 边界钳制: 确保按钮不超出安全区域 (无论 btnScale/btnOffset 如何)
    bottomCY = math.min(bottomCY, BATTLE_ZONE.bottom - marginB - R)
    rightCX  = math.min(rightCX,  DESIGN_W - marginR - R)
    local leftCX  = rightCX - R * 2 - gap

    skillBtnRects = {}
    autoMarchBtnRect = nil  -- 自动行军已移除
    troopBtnRects = {}  -- 兵种选择按钮碰撞区域

    -- ---- 兵种选择按钮 (4个方形, 在武技圈左侧) ----
    if gameState.battlePhase == "FIGHT" then
        local troopKeys = { "infantry", "archer", "cavalry", "spear" }
        local tbSize = math.floor(38 * btnSc)   -- 方形按钮边长
        local tbGap = math.floor(6 * btnSc)     -- 按钮间距
        local tbTotal = #troopKeys * tbSize + (#troopKeys - 1) * tbGap
        -- 起始X: 武技圈左侧再偏移
        local tbStartX = leftCX - R - 16 - tbTotal
        local tbCY = bottomCY  -- 与武技圈同一水平线

        for i, tk in ipairs(troopKeys) do
            local tt = TROOP_TYPES[tk]
            local c = tt.color
            local bx = tbStartX + (i - 1) * (tbSize + tbGap)
            local by = tbCY - tbSize / 2
            local isSel = (gameState.selectedTroopType == tk)

            -- 统计该兵种活着的单位数
            local cnt = 0
            for _, u in ipairs(playerUnits) do
                if u.alive and u.troopType == tk then cnt = cnt + 1 end
            end
            local hasUnits = (cnt > 0)

            -- 按钮背景
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, tbSize, tbSize, 5)
            if isSel then
                local pulse = 0.7 + 0.3 * math.sin(t * 4)
                nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(120 * pulse)))
            elseif hasUnits then
                nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 40))
            else
                nvgFillColor(vg, nvgRGBA(30, 25, 20, 180))
            end
            nvgFill(vg)

            -- 边框
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, tbSize, tbSize, 5)
            if isSel then
                local pulse = 0.7 + 0.3 * math.sin(t * 4)
                nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(255 * pulse)))
                nvgStrokeWidth(vg, 2.0)
            elseif hasUnits then
                nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], 140))
                nvgStrokeWidth(vg, 1.0)
            else
                nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 80))
                nvgStrokeWidth(vg, 0.8)
            end
            nvgStroke(vg)

            -- 兵种图标文字
            nvgFontSize(vg, math.floor(20 * btnSc))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if hasUnits then
                nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 255))
            else
                nvgFillColor(vg, nvgRGBA(120, 110, 100, 120))
            end
            nvgText(vg, bx + tbSize / 2, by + tbSize / 2 - 4, tt.icon, nil)

            -- 数量小字
            nvgFontSize(vg, math.floor(14 * btnSc))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            if hasUnits then
                nvgFillColor(vg, nvgRGBA(220, 210, 200, 200))
            else
                nvgFillColor(vg, nvgRGBA(100, 90, 80, 100))
            end
            nvgText(vg, bx + tbSize / 2, by + tbSize - 1, tostring(cnt), nil)

            -- 选中指示器 (底部小三角)
            if isSel then
                local triCX = bx + tbSize / 2
                local triY = by - 4
                nvgBeginPath(vg)
                nvgMoveTo(vg, triCX - 5, triY - 6)
                nvgLineTo(vg, triCX + 5, triY - 6)
                nvgLineTo(vg, triCX, triY)
                nvgClosePath(vg)
                nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 220))
                nvgFill(vg)
            end

            -- 注册碰撞区域
            troopBtnRects[tk] = { x = bx, y = by, w = tbSize, h = tbSize, isDesign = true }
        end
    end

    -- ---- 武技技能圈 (两个) ----
    local slotPositions = {
        { cx = leftCX,  cy = bottomCY },  -- slot 1 左
        { cx = rightCX, cy = bottomCY },  -- slot 2 右
    }

    for slot = 1, 2 do
        local pos = slotPositions[slot]
        local techIdx = playerEquippedSkills[slot]
        local sk = techIdx and SKILL_DEFS[techIdx]

        if sk then
            local sc = sk.color
            local skPulse = 0.6 + 0.4 * math.sin(t * 2.5 + slot * 1.2)

            if isDeployPhase then
                -- ---- DEPLOY阶段: 灰色禁用显示 ----
                nvgBeginPath(vg); nvgCircle(vg, pos.cx, pos.cy, R)
                nvgFillColor(vg, nvgRGBA(30, 25, 20, 200)); nvgFill(vg)
                nvgBeginPath(vg); nvgCircle(vg, pos.cx, pos.cy, R)
                nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 100))
                nvgStrokeWidth(vg, 1.0); nvgStroke(vg)

                nvgGlobalAlpha(vg, 0.25)
                drawSkillIcon(sk.iconIdx, pos.cx - R + 5, pos.cy - R + 5, (R - 5) * 2, R)
                nvgGlobalAlpha(vg, 1.0)

                -- 不注册点击区域 (DEPLOY阶段不可用)
            elseif sk.cooldown > 0 then
                -- ---- 冷却中: 暗色底 + 扇形冷却覆盖 ----
                local cdRatio = sk.cooldown / sk.maxCooldown
                -- 暗底
                nvgBeginPath(vg); nvgCircle(vg, pos.cx, pos.cy, R)
                nvgFillColor(vg, nvgRGBA(20, 15, 12, 220)); nvgFill(vg)

                -- 冷却扇形 (从顶部顺时针擦除)
                local angle = (1 - cdRatio) * math.pi * 2  -- 已冷却的角度
                if angle > 0.01 then
                    nvgBeginPath(vg)
                    nvgMoveTo(vg, pos.cx, pos.cy)
                    nvgArc(vg, pos.cx, pos.cy, R, -math.pi / 2, -math.pi / 2 + angle, 1)  -- NVG_CW = 1
                    nvgClosePath(vg)
                    nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 50)); nvgFill(vg)
                end

                -- 边框
                nvgBeginPath(vg); nvgCircle(vg, pos.cx, pos.cy, R)
                nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 80))
                nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

                -- 图标 (半透明)
                nvgGlobalAlpha(vg, 0.4)
                drawSkillIcon(sk.iconIdx, pos.cx - R + 5, pos.cy - R + 5, (R - 5) * 2, R)
                nvgGlobalAlpha(vg, 1.0)

                -- 冷却秒数
                nvgFontSize(vg, math.floor(26 * btnSc))
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(pos.cx, pos.cy + 2, string.format("%.0f", math.ceil(sk.cooldown)))
            else
                -- ---- 可用: 发光底 + 图标 ----
                local glow = nvgRadialGradient(vg, pos.cx, pos.cy, R * 0.3, R,
                    nvgRGBA(sc[1], sc[2], sc[3], math.floor(80 * skPulse)),
                    nvgRGBA(sc[1], sc[2], sc[3], math.floor(20 * skPulse)))
                nvgBeginPath(vg); nvgCircle(vg, pos.cx, pos.cy, R)
                nvgFillPaint(vg, glow); nvgFill(vg)

                -- 边框脉冲
                nvgBeginPath(vg); nvgCircle(vg, pos.cx, pos.cy, R)
                nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], math.floor(220 * skPulse)))
                nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

                -- 图标
                drawSkillIcon(sk.iconIdx, pos.cx - R + 5, pos.cy - R + 5, (R - 5) * 2, R)
            end

            skillBtnRects[slot] = { cx = pos.cx, cy = pos.cy, r = R, isCircle = true, isDesign = true, techIdx = techIdx }
        else
            -- 空槽位: 虚线圆
            nvgBeginPath(vg); nvgCircle(vg, pos.cx, pos.cy, R)
            nvgStrokeColor(vg, nvgRGBA(100, 90, 80, 60))
            nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
            nvgFontSize(vg, math.floor(18 * btnSc))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(pos.cx, pos.cy, "空")
        end
    end

end


-- ============================================================================
-- 策略选项条 (长按自动行军 → 向左弹出选项)
-- ============================================================================
function DrawStrategyWheel()
    if not strategyWheelState.show then return end
    if not autoMarchBtnRect then return end

    local ab = autoMarchBtnRect
    local t = gameState.gameTime or 0

    -- 布局参数（与 BeginPress 碰撞检测保持一致）
    local cardW = 115
    local cardH = 64
    local gap = 8
    local startX = ab.cx - ab.r - 12   -- 卡片右边缘起点
    local cardCY = ab.cy - ab.r - cardH / 2 - 16  -- 按钮上方
    local cornerR = 10

    -- 暗黑配色
    local cardColors = {
        { bg = { 40, 65, 45 }, hi = { 120, 220, 160 } },
        { bg = { 70, 50, 22 }, hi = { 255, 200, 80  } },
        { bg = { 28, 48, 72 }, hi = { 100, 180, 255 } },
    }

    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())

    -- 连接线（从按钮顶部斜向卡片右端）
    local lineX0 = ab.cx - 4
    local lineY0 = ab.cy - ab.r
    local lineX1 = startX
    local lineY1 = cardCY + cardH / 2 - 2
    nvgBeginPath(vg)
    nvgMoveTo(vg, lineX0, lineY0)
    nvgLineTo(vg, lineX1, lineY1)
    nvgStrokeColor(vg, nvgRGBA(140, 120, 70, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 绘制3张策略卡片
    for i = 1, #MARCH_STRATEGIES do
        local st = MARCH_STRATEGIES[i]
        local cc = cardColors[i]
        local sel = (strategyWheelState.selected == i)

        local cRight = startX - (i - 1) * (cardW + gap)
        local cLeft = cRight - cardW
        local cTop = cardCY - cardH / 2
        local cBot = cardCY + cardH / 2

        -- 卡片背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cLeft, cTop, cardW, cardH, cornerR)
        if sel then
            local pulse = 0.8 + 0.2 * math.sin(t * 5)
            local a = math.floor(220 * pulse)
            local grad = nvgLinearGradient(vg, cLeft, cTop, cLeft, cBot,
                nvgRGBA(cc.hi[1], cc.hi[2], cc.hi[3], math.floor(a * 0.6)),
                nvgRGBA(cc.bg[1], cc.bg[2], cc.bg[3], a))
            nvgFillPaint(vg, grad); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(cc.bg[1], cc.bg[2], cc.bg[3], 180))
            nvgFill(vg)
        end

        -- 卡片边框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cLeft, cTop, cardW, cardH, cornerR)
        if sel then
            nvgStrokeColor(vg, nvgRGBA(cc.hi[1], cc.hi[2], cc.hi[3], 220))
            nvgStrokeWidth(vg, 1.5)
        else
            nvgStrokeColor(vg, nvgRGBA(140, 120, 80, 80))
            nvgStrokeWidth(vg, 0.8)
        end
        nvgStroke(vg)

        -- 策略名
        local tx = cLeft + cardW / 2
        local ty = cardCY - 6
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 18)
        DrawWhiteInkText(tx, ty, st.name)

        -- 简短描述（始终显示）
        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(cc.hi[1], cc.hi[2], cc.hi[3], 180))
        nvgText(vg, tx, ty + 18, st.desc, nil)
    end

    -- 提示文字
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local hintAlpha = math.floor(100 + 60 * math.sin(t * 2.5))
    nvgFillColor(vg, nvgRGBA(180, 165, 130, hintAlpha))
    nvgText(vg, startX - (#MARCH_STRATEGIES * (cardW + gap)) / 2, cardCY + cardH / 2 + 10, "点击选择策略", nil)

    nvgRestore(vg)
end

-- ============================================================================
-- 撤退/追击弹窗渲染
-- ============================================================================

--- 玩家撤退被追击的提示 (倒计时自动消失)
function DrawRetreatPursuitNotice()
    local popup = gameState.retreatPopup
    if not popup then return end
    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())
    local pw, ph = 420, 80
    local px = (DESIGN_W - pw) / 2
    local py = DESIGN_H * 0.25
    -- 暗红背景
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgFillColor(vg, nvgRGBA(80, 15, 15, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 80, 60, 200))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    -- 文字
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 200, 180, 255))
    nvgText(vg, px + pw / 2, py + ph / 2, popup.msg, nil)
    nvgRestore(vg)
end

--- 敌方撤退弹窗 (暂停战斗, 玩家选择追击/放行)
function DrawEnemyRetreatPopup()
    local popup = gameState.enemyRetreatPopup
    if not popup then return end
    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())
    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120)); nvgFill(vg)
    -- 弹窗面板
    local pw, ph = 380, 180
    local px = (DESIGN_W - pw) / 2
    local py = (DESIGN_H - ph) / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 10)
    nvgFillColor(vg, nvgRGBA(35, 30, 25, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 180, 80, 200))
    nvgStrokeWidth(vg, 2.0); nvgStroke(vg)
    -- 标题
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
    nvgText(vg, px + pw / 2, py + 36, "敌军试图撤退!", nil)
    -- 说明
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(220, 210, 190, 220))
    nvgText(vg, px + pw / 2, py + 72, "是否下令追击?", nil)
    -- 按钮
    local btnW, btnH = 120, 40
    local gap = 30
    local btnY = py + ph - 56
    local btn1X = px + pw / 2 - btnW - gap / 2
    local btn2X = px + pw / 2 + gap / 2
    -- [追击] 按钮 - 红色
    nvgBeginPath(vg); nvgRoundedRect(vg, btn1X, btnY, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(160, 50, 30, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 120, 80, 180))
    nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 220, 255))
    nvgText(vg, btn1X + btnW / 2, btnY + btnH / 2, "追击", nil)
    gameState.btn_enemyRetreatPursue = { x = btn1X, y = btnY, w = btnW, h = btnH }
    -- [放行] 按钮 - 灰色
    nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, btnY, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 60, 55, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(140, 140, 120, 150))
    nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 210, 190, 255))
    nvgText(vg, btn2X + btnW / 2, btnY + btnH / 2, "放行", nil)
    gameState.btn_enemyRetreatLetGo = { x = btn2X, y = btnY, w = btnW, h = btnH }
    nvgRestore(vg)
end

--- 追击结果通知 (倒计时自动消失)
function DrawPursuitResultNotice()
    local popup = gameState.pursuitResultPopup
    if not popup then return end
    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())
    local pw, ph = 420, 80
    local px = (DESIGN_W - pw) / 2
    local py = DESIGN_H * 0.25
    local bgR, bgG, bgB = 15, 60, 25
    local borderR, borderG, borderB = 80, 220, 120
    if not popup.success then
        bgR, bgG, bgB = 60, 50, 15
        borderR, borderG, borderB = 200, 180, 60
    end
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgFillColor(vg, nvgRGBA(bgR, bgG, bgB, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(borderR, borderG, borderB, 200))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 200, 255))
    nvgText(vg, px + pw / 2, py + ph / 2, popup.msg, nil)
    nvgRestore(vg)
end

-- ============================================================================
-- 战斗规则弹窗
-- ============================================================================
function DrawBattleRulesPopup()
    if not battleRulesState.show then return end

    nvgSave(vg)
    -- 全屏半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180)); nvgFill(vg)

    -- 规则数据
    local rules = {
        { "★ 新手必读", "核心流程: 商店购买武灵→拖到石台上阵→点击「开战」→拖拽已上阵武灵到车道派兵。\n手动派兵: 将上阵武灵拖到指定车道精准出击。\n自动行军: 右下角行军按钮开启后自动派兵；长按按钮可切换策略(五路并进/全歼中路/分散侧翼)。\n查看详情: 点击商店卡牌可查看武灵属性。\n武技技能: 战斗中长按右下角武技图标可查看技能详情，短按后拖拽释放。" },
        { "基本玩法", "从商店购买武灵放置到石台上阵，拖拽武灵到战场选择车道派兵。" },
        { "军资经济", "每" .. tostring(math.floor(GameConfig.GOLD_INTERVAL)) .. "秒自动获得1军资，合理分配军资购买和刷新。" },
        { "阵容布置", "最多上阵" .. #PLAYER_SLOTS .. "位武灵，品质越高费用越高但属性更强。" },
        { "自动行军", "开启后武灵CD就绪即自动派兵。长按可选择策略：五路并进、全歼中路、分散侧翼。" },
        { "武技技能", "装备武技后战斗中可拖拽释放，造成范围伤害。自动行军时也会自动释放。" },
        { "突破机制", "己方兵突破敌方临界线可直接攻击敌方大本营。" },
        { "胜负判定", "率先摧毁对方大本营获胜。" },
        { "武灵升级", "出卡阶段将同名武灵拖放到已上阵武灵身上即可升级。每次升级属性提升：攻击×1.15  防御×1.10  生命×1.20。可多次叠加，等级越高越强。" },
        { "兵种特性", "虎贲刀兵：近战推进  连弩射手/火攻术士：远程射击  铁盾重卫：驻守半场嘲讽敌人  夜行刺客：绕后暗杀1.5倍  铁骑先锋：冲锋撞击  长枪兵：贯穿2人  战象巨兽：范围震击  军医道士：治疗+攻速光环" },
        { "特殊兵种", "火牛突袭：全速冲锋引爆(250%范围伤害)  驯兽使：每4秒召唤走兽(上限4只)  寒冰术士：远程攻击附带40%减速  蜂巢蝗群：一次6只攻速极快" },
        { "敌军差异", "黄巾力士死亡时自爆(120%范围伤害)  铁甲悍将受到伤害降低15%  山贼弓手远程射击" },
    }

    local titleFontSize = 24
    local ruleTitleSize = 16
    local ruleBodySize = 14
    local pw = 380
    local wrapW = pw - 48
    local titleAreaH = 20 + 32 + 12  -- padding + 标题 + 分隔线

    -- 第一遍：计算内容总高度
    nvgFontFaceId(vg, GetMainFont())
    local contentH = 0
    for _, rule in ipairs(rules) do
        contentH = contentH + 22  -- 规则标题行
        nvgFontSize(vg, ruleBodySize)
        local bounds = nvgTextBoxBounds(vg, 0, 0, wrapW, rule[2], nil)
        local textH = bounds and (bounds[4] - bounds[2]) or 18
        contentH = contentH + textH + 10
    end
    contentH = contentH + 10  -- 底部padding

    -- 面板尺寸
    local closeBtnAreaH = 48
    local maxH = DESIGN_H - 40
    local ph = math.min(titleAreaH + contentH + closeBtnAreaH, maxH)
    local viewH = ph - titleAreaH - closeBtnAreaH
    local px = (DESIGN_W - pw) / 2
    local py = (DESIGN_H - ph) / 2

    -- 保存到状态供滚动使用
    battleRulesState.contentH = contentH
    battleRulesState.viewH = viewH
    battleRulesState.panelRect = { x = px, y = py, w = pw, h = ph }

    -- 背景
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 10)
    nvgFillColor(vg, nvgRGBA(25, 22, 18, 245)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 160, 120, 150)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 标题（固定不滚动）
    local titleY = py + 20
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFontSize(vg, titleFontSize)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
    nvgText(vg, DESIGN_W / 2, titleY, "战斗规则", nil)

    -- 分隔线
    local sepY = titleY + 32
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 20, sepY); nvgLineTo(vg, px + pw - 20, sepY)
    nvgStrokeColor(vg, nvgRGBA(180, 160, 120, 100)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

    -- 裁剪滚动区域
    local scrollTop = py + titleAreaH
    local scrollBot = scrollTop + viewH
    nvgScissor(vg, px, scrollTop, pw, viewH)

    -- 规则内容（随滚动偏移）
    local scrollY = battleRulesState.scrollY or 0
    local ty = scrollTop - scrollY + 6
    local lx = px + 20
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    for _, rule in ipairs(rules) do
        -- 规则标题
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 240))
        nvgFontSize(vg, ruleTitleSize)
        nvgText(vg, lx, ty, "· " .. rule[1], nil)
        ty = ty + 22
        -- 规则正文
        nvgFillColor(vg, nvgRGBA(220, 210, 190, 210))
        nvgFontSize(vg, ruleBodySize)
        local bounds = nvgTextBoxBounds(vg, lx + 10, ty, wrapW, rule[2], nil)
        nvgTextBox(vg, lx + 10, ty, wrapW, rule[2], nil)
        local textH = bounds and (bounds[4] - bounds[2]) or 18
        ty = ty + textH + 10
    end

    nvgResetScissor(vg)

    -- 滚动条指示器（内容超出时显示）
    if contentH > viewH then
        local maxScroll = contentH - viewH
        local barH = math.max(20, viewH * (viewH / contentH))
        local barY = scrollTop + (scrollY / maxScroll) * (viewH - barH)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px + pw - 8, barY, 4, barH, 2)
        nvgFillColor(vg, nvgRGBA(180, 160, 120, 80))
        nvgFill(vg)
    end

    -- 关闭按钮（固定在底部）
    local closeBtnW, closeBtnH = 100, 32
    local closeBtnX = (DESIGN_W - closeBtnW) / 2
    local closeBtnY = py + ph - 42
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 50, 35, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 180, 120, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
    nvgText(vg, DESIGN_W / 2, closeBtnY + closeBtnH / 2, "知道了", nil)

    battleRulesState.closeBtnRect = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }

    nvgRestore(vg)
end


-- ============================================================================
-- 统一规则弹窗 (所有界面通用)
-- ============================================================================
function DrawPhaseRulePopup()
    if not phaseRulePopup.show then return end

    local ruleData = PHASE_RULES[phaseRulePopup.phase]
    if not ruleData then
        phaseRulePopup.show = false
        return
    end

    nvgSave(vg)
    -- 全屏半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180)); nvgFill(vg)

    local rules = ruleData.rules
    local themeColor = ruleData.color or { 180, 160, 120 }
    local titleText = ruleData.title or "规则说明"

    local titleFontSize = 24
    local ruleTitleSize = 16
    local ruleBodySize = 14
    local pw = 380
    local wrapW = pw - 48
    local titleAreaH = 20 + 32 + 12  -- padding + 标题 + 分隔线

    -- 计算内容总高度
    nvgFontFaceId(vg, GetMainFont())
    local contentH = 0
    for _, rule in ipairs(rules) do
        contentH = contentH + 22
        nvgFontSize(vg, ruleBodySize)
        local bounds = nvgTextBoxBounds(vg, 0, 0, wrapW, rule[2], nil)
        local textH = bounds and (bounds[4] - bounds[2]) or 18
        contentH = contentH + textH + 10
    end
    contentH = contentH + 10

    -- 面板尺寸
    local closeBtnAreaH = 48
    local maxH = DESIGN_H - 40
    local ph = math.min(titleAreaH + contentH + closeBtnAreaH, maxH)
    local viewH = ph - titleAreaH - closeBtnAreaH
    local px = (DESIGN_W - pw) / 2
    local py = (DESIGN_H - ph) / 2

    phaseRulePopup.contentH = contentH
    phaseRulePopup.viewH = viewH
    phaseRulePopup.panelRect = { x = px, y = py, w = pw, h = ph }

    -- 背景
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 10)
    nvgFillColor(vg, nvgRGBA(25, 22, 18, 245)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(themeColor[1], themeColor[2], themeColor[3], 150))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 标题（固定不滚动）
    local titleY = py + 20
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFontSize(vg, titleFontSize)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
    nvgText(vg, DESIGN_W / 2, titleY, titleText, nil)

    -- 分隔线
    local sepY = titleY + 32
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 20, sepY); nvgLineTo(vg, px + pw - 20, sepY)
    nvgStrokeColor(vg, nvgRGBA(themeColor[1], themeColor[2], themeColor[3], 100))
    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

    -- 裁剪滚动区域
    local scrollTop = py + titleAreaH
    nvgScissor(vg, px, scrollTop, pw, viewH)

    -- 规则内容（随滚动偏移）
    local scrollY = phaseRulePopup.scrollY or 0
    local ty = scrollTop - scrollY + 6
    local lx = px + 20
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    for _, rule in ipairs(rules) do
        -- 规则标题
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 240))
        nvgFontSize(vg, ruleTitleSize)
        nvgText(vg, lx, ty, "· " .. rule[1], nil)
        ty = ty + 22
        -- 规则正文
        nvgFillColor(vg, nvgRGBA(220, 210, 190, 210))
        nvgFontSize(vg, ruleBodySize)
        local bounds = nvgTextBoxBounds(vg, lx + 10, ty, wrapW, rule[2], nil)
        nvgTextBox(vg, lx + 10, ty, wrapW, rule[2], nil)
        local textH = bounds and (bounds[4] - bounds[2]) or 18
        ty = ty + textH + 10
    end

    nvgResetScissor(vg)

    -- 滚动条指示器
    if contentH > viewH then
        local maxScroll = contentH - viewH
        local barH = math.max(20, viewH * (viewH / contentH))
        local barY = scrollTop + (scrollY / maxScroll) * (viewH - barH)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px + pw - 8, barY, 4, barH, 2)
        nvgFillColor(vg, nvgRGBA(themeColor[1], themeColor[2], themeColor[3], 80))
        nvgFill(vg)
    end

    -- 关闭按钮（固定在底部）
    local closeBtnW, closeBtnH = 100, 32
    local closeBtnX = (DESIGN_W - closeBtnW) / 2
    local closeBtnY = py + ph - 42
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 50, 35, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(themeColor[1], themeColor[2], themeColor[3], 180))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
    nvgText(vg, DESIGN_W / 2, closeBtnY + closeBtnH / 2, "知道了", nil)

    phaseRulePopup.closeBtnRect = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }

    nvgRestore(vg)
end


-- ============================================================================
-- 战力说明弹窗
-- ============================================================================
function DrawPowerExplainPopup()
    if not powerExplainPopup.show then return end

    nvgSave(vg)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 170)); nvgFill(vg)

    local pw = 340
    local ph = 230
    local px = (DESIGN_W - pw) / 2
    local py = (DESIGN_H - ph) / 2

    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 10)
    nvgFillColor(vg, nvgRGBA(25, 20, 30, 245)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 70, 150)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    powerExplainPopup.panelRect = { x = px, y = py, w = pw, h = ph }

    nvgFontFaceId(vg, GetMainFont())
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    nvgText(vg, DESIGN_W / 2, py + 16, "战力计算说明", nil)

    local sepY2 = py + 42
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 20, sepY2); nvgLineTo(vg, px + pw - 20, sepY2)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 70, 100)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(vg, 22)
    local lx2 = px + 20
    local ly = sepY2 + 10
    local lines = {
        { "公式:", nvgRGBA(255, 200, 100, 240) },
        { "总战力 = 武灵战力(前4强)", nvgRGBA(210, 200, 190, 220) },
        { "       + 兵甲分 + 武技分", nvgRGBA(210, 200, 190, 220) },
        { "", nvgRGBA(0, 0, 0, 0) },
        { "· 武灵战力: 取拥有的最强4只武灵评分", nvgRGBA(200, 190, 180, 200) },
        { "· 兵甲分: 已装备兵甲的属性总和", nvgRGBA(200, 190, 180, 200) },
        { "· 武技分: 已解锁武技的阶级评分", nvgRGBA(200, 190, 180, 200) },
    }
    for _, ln in ipairs(lines) do
        nvgFillColor(vg, ln[2])
        nvgText(vg, lx2, ly, ln[1], nil)
        ly = ly + 18
    end

    -- 关闭按钮
    local cbW, cbH = 80, 28
    local cbX = (DESIGN_W - cbW) / 2
    local cbY = py + ph - 38
    nvgBeginPath(vg); nvgRoundedRect(vg, cbX, cbY, cbW, cbH, 6)
    nvgFillColor(vg, nvgRGBA(50, 40, 30, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 70, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
    nvgText(vg, DESIGN_W / 2, cbY + cbH / 2, "关闭", nil)
    powerExplainPopup.closeBtnRect = { x = cbX, y = cbY, w = cbW, h = cbH }

    nvgRestore(vg)
end


-- ============================================================================
-- 武技技能详情弹窗 (战斗中长按查看)
-- ============================================================================
function DrawSkillInfoPopup()
    if not skillLongPressState.showPopup then return end

    local skIdx = skillLongPressState.popupSkillIdx
    local tech = SKILL_TECHNIQUES[skIdx]
    local sk = SKILL_DEFS[skIdx]
    if not tech or not sk then
        skillLongPressState.showPopup = false
        return
    end
    local tier = SKILL_TIERS[tech.tier]

    nvgSave(vg)
    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 140)); nvgFill(vg)

    local pw = 320
    local ph = 200
    local px = (DESIGN_W - pw) / 2
    local py = (DESIGN_H - ph) / 2

    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 10)
    nvgFillColor(vg, nvgRGBA(20, 15, 25, 245)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(tier.color[1], tier.color[2], tier.color[3], 180))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    skillLongPressState.popupRect = { x = px, y = py, w = pw, h = ph }

    nvgFontFaceId(vg, GetMainFont())

    -- 技能名 + 阶级
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(tier.color[1], tier.color[2], tier.color[3], 255))
    nvgText(vg, DESIGN_W / 2, py + 16, tech.name .. " [" .. tier.name .. "]", nil)

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 20, py + 42); nvgLineTo(vg, px + pw - 20, py + 42)
    nvgStrokeColor(vg, nvgRGBA(tier.color[1], tier.color[2], tier.color[3], 80))
    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

    -- 描述
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(210, 200, 190, 220))
    nvgTextBox(vg, px + 20, py + 50, pw - 40, tech.desc, nil)

    -- CD信息
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
    nvgText(vg, px + 20, py + 130, string.format("冷却: %.0f秒  伤害: %d  类型: %s",
        sk.maxCooldown, sk.damage, sk.skillType == "line" and "直线" or (sk.skillType == "rect" and "矩形" or "圆形")), nil)

    -- 当前状态
    nvgFontSize(vg, 20)
    if sk.cooldown > 0 then
        nvgFillColor(vg, nvgRGBA(255, 120, 80, 200))
        nvgText(vg, px + 20, py + 148, string.format("冷却中: %.1f秒", sk.cooldown), nil)
    else
        nvgFillColor(vg, nvgRGBA(100, 255, 120, 200))
        nvgText(vg, px + 20, py + 148, "可释放", nil)
    end

    -- 关闭提示
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(160, 150, 140, 160))
    nvgText(vg, DESIGN_W / 2, py + ph - 16, "点击任意处关闭", nil)

    nvgRestore(vg)
end


-- ============================================================================
-- DEPLOY 阶段阵型选择面板 (顶部水平排列, 设计坐标)
-- ============================================================================
function DrawDeployFormationPanel()
    if fontId < 0 then return end
    if gameState.battlePhase ~= "DEPLOY" then return end

    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())

    local selId = deploySelectedFormation or DEFAULT_FORMATION_ID
    local enemyFormId = gameState.enemyFormationId or DEFAULT_FORMATION_ID

    -- 面板布局参数 (设计坐标 1024×571)
    local panelW = 520
    local panelH = 130
    local panelX = (DESIGN_W - panelW) / 2
    local panelY = 28

    -- 半透明背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 8)
    nvgFillColor(vg, nvgRGBA(10, 8, 6, 180))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 8)
    nvgStrokeColor(vg, nvgRGBA(120, 100, 70, 120))
    nvgStrokeWidth(vg, 1.0)
    nvgStroke(vg)

    -- 标题
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 180, 140, 200))
    nvgText(vg, panelX + 8, panelY + 3, "阵型选择", nil)

    -- 5个阵型按钮
    local btnW = 92
    local btnH = 72
    local btnGap = 6
    local totalBtnsW = #FORMATIONS * btnW + (#FORMATIONS - 1) * btnGap
    local startX = panelX + (panelW - totalBtnsW) / 2
    local btnY = panelY + 26

    deployFormationBtnRects = {}

    for i, form in ipairs(FORMATIONS) do
        local bx = startX + (i - 1) * (btnW + btnGap)
        local isSel = (form.id == selId)

        -- 按钮背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, btnY, btnW, btnH, 5)
        if isSel then
            nvgFillColor(vg, nvgRGBA(40, 65, 30, 230))
        else
            nvgFillColor(vg, nvgRGBA(25, 22, 18, 200))
        end
        nvgFill(vg)

        -- 按钮边框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, btnY, btnW, btnH, 5)
        if isSel then
            local pulse = 0.7 + 0.3 * math.sin(gameState.gameTime * 3)
            nvgStrokeColor(vg, nvgRGBA(100, 255, 140, math.floor(220 * pulse)))
            nvgStrokeWidth(vg, 1.5)
        else
            nvgStrokeColor(vg, nvgRGBA(100, 90, 70, 130))
            nvgStrokeWidth(vg, 0.8)
        end
        nvgStroke(vg)

        -- 阵型名称
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        if isSel then
            nvgFillColor(vg, nvgRGBA(255, 240, 200, 255))
        else
            nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
        end
        nvgText(vg, bx + btnW / 2, btnY + 4, form.name, nil)

        -- 克制指示 (vs 敌方阵型)
        local counterMult = GetFormationCounterMult(form.id, enemyFormId)
        local counterLabel, counterColor
        if counterMult > 1.05 then
            counterLabel = "▲克制"
            counterColor = {100, 255, 120, 255}
        elseif counterMult < 0.95 then
            counterLabel = "▼被克"
            counterColor = {255, 100, 80, 255}
        else
            counterLabel = "—中立"
            counterColor = {180, 170, 160, 180}
        end
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(counterColor[1], counterColor[2], counterColor[3], counterColor[4]))
        nvgText(vg, bx + btnW / 2, btnY + 28, counterLabel, nil)

        -- 攻防倍率小字
        local statStr = string.format("攻%.0f%% 防%.0f%%", form.playerAtkMult * 100, form.playerDefMult * 100)
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(160, 150, 140, 180))
        nvgText(vg, bx + btnW / 2, btnY + 50, statStr, nil)

        -- 记录碰撞矩形
        deployFormationBtnRects[form.id] = { x = bx, y = btnY, w = btnW, h = btnH }
    end

    -- 底部信息条: 当前阵型描述 + 适合兵种
    local selForm = nil
    for _, f in ipairs(FORMATIONS) do if f.id == selId then selForm = f; break end end
    if selForm then
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(180, 170, 140, 200))
        local infoStr = selForm.desc .. "  |  适合: " .. selForm.suitFor
        nvgText(vg, DESIGN_W / 2, panelY + panelH - 24, infoStr, nil)
    end

    -- 敌方阵型提示
    local enemyForm = nil
    for _, f in ipairs(FORMATIONS) do if f.id == enemyFormId then enemyForm = f; break end end
    if enemyForm then
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 140, 100, 180))
        nvgText(vg, panelX + panelW - 8, panelY + 3, "敌阵: " .. enemyForm.name, nil)
    end

    nvgRestore(vg)
end


