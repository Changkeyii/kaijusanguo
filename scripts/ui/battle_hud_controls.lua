-- ui/battle_hud_controls.lua - 三国武灵录 (从 battle_hud.lua 拆分)
-- ============================================================================
-- 战斗按钮 (右侧垂直排列, 设计坐标)
-- ============================================================================

function DrawBattleButtons()
    if fontId < 0 then return end

    -- 三国群英传模式: 无SHOP阶段, 直接进入FIGHT
    local t = gameState.gameTime

    nvgFontFaceId(vg, GetMainFont())

    -- 右侧按钮参数 (放大以适配手机操作)
    local btnW = 72
    local btnH = 30
    local btnGap = 6
    local rightMargin = 4  -- 距离设计区右边缘

    -- 应用右上角按钮组偏移量
    local rbOfsX = gameSettings.rightBtnOffsetX or 0
    local rbOfsY = gameSettings.rightBtnOffsetY or 0

    -- 所有按钮从上到下排列，基准Y=136避免被TapTap右上角按钮遮挡
    local startY = 136 + rbOfsY
    local bx = DESIGN_W - btnW - rightMargin + rbOfsX
    local curY = startY

    -- 清除不再使用的按钮矩形
    shopFightBtnRect = nil
    shopRefreshBtnRect = nil
    battleChangeBgBtnRect = nil
    autoMarchBtnRect = nil

    do
        -- FIGHT阶段：精简显示 (三国群英传模式: 无军资/刷新)

        -- 1. 倍速按钮
        do
            local spd = gameState.battleSpeed or 1
            local spdLabel = "×" .. tostring(spd)
            local spdOn = spd > 1
            local spdPulse = spdOn and (0.7 + 0.3 * math.sin(t * 5)) or 1.0
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 3)
            if spdOn then
                nvgFillColor(vg, nvgRGBA(60, 40, 10, math.floor(200 * spdPulse))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(255, 200, 60, math.floor(180 * spdPulse)))
            else
                nvgFillColor(vg, nvgRGBA(25, 22, 18, 190)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(120, 110, 100, 120))
            end
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + btnW / 2, curY + btnH / 2, "倍速" .. spdLabel)
            battleSpeedBtnRect = { x = bx, y = curY, w = btnW, h = btnH, isDesign = true }
            curY = curY + btnH + btnGap
        end

        -- 7. 自动战斗按钮 (教程中隐藏)
        if not tutorialState.active then
            local isAuto = gameState.autoBattle
            local blocked = gameState.noFullAuto  -- 副本模式禁用全自动
            local autoPulse = isAuto and (0.7 + 0.3 * math.sin(t * 4)) or 1.0
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 3)
            if blocked then
                nvgFillColor(vg, nvgRGBA(40, 35, 35, 160)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 100))
            elseif isAuto then
                nvgFillColor(vg, nvgRGBA(15, 50, 30, math.floor(220 * autoPulse))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 255, 140, math.floor(180 * autoPulse)))
            else
                nvgFillColor(vg, nvgRGBA(25, 22, 18, 190)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(120, 110, 100, 120))
            end
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local autoLabel = blocked and "禁用" or (isAuto and "自动 ON" or "自动 OFF")
            DrawWhiteInkText(bx + btnW / 2, curY + btnH / 2, autoLabel)
            autoBattleBtnRect = { x = bx, y = curY, w = btnW, h = btnH, isDesign = true }
            curY = curY + btnH + btnGap
        end

        -- 8. 规则按钮
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 3)
        nvgFillColor(vg, nvgRGBA(30, 30, 50, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(140, 140, 180, 120)); nvgStrokeWidth(vg, 0.6); nvgStroke(vg)
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(bx + btnW / 2, curY + btnH / 2, "规则")
        battleRuleBtnRect = { x = bx, y = curY, w = btnW, h = btnH, isDesign = true }
        curY = curY + btnH + btnGap

        -- 9. 退出按钮 (教程战斗阶段step>=8也显示)
        if not tutorialState.active or tutorialState.step >= 8 then
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, btnW, btnH, 3)
            nvgFillColor(vg, nvgRGBA(60, 20, 20, 160)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 100, 80, 120)); nvgStrokeWidth(vg, 0.6); nvgStroke(vg)
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + btnW / 2, curY + btnH / 2, "退出")
            battleBackBtnRect = { x = bx, y = curY, w = btnW, h = btnH, isDesign = true }
        else
            battleBackBtnRect = nil
        end

        shopFightBtnRect = nil
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
    if gameState.battlePhase ~= "FIGHT" then
        autoMarchBtnRect = nil
        skillBtnRects = {}
        return
    end

    local t = gameState.gameTime
    nvgFontFaceId(vg, GetMainFont())

    -- ======== 右下角武技技能圈 (三国群英传模式: 移除自动行军, 只保留武技) ========
    local btnSc = gameSettings.btnScale or 1.0
    local R = math.floor(26 * btnSc)        -- 圆形按钮半径 (受缩放)
    local gap = math.floor(6 * btnSc)       -- 圈之间间距
    local marginR = 8 + safeInsets.right   -- 右边距(含安全区)
    local marginB = 12 + safeInsets.bottom -- 底部边距(含安全区)

    -- 应用设置中自定义的按钮位置偏移
    local btnOfsX = gameSettings.btnOffsetX or 0
    local btnOfsY = gameSettings.btnOffsetY or 0
    local bottomCY = BATTLE_ZONE.bottom - marginB - R + R * 2 + btnOfsY
    -- 底部两圈: 右圈和左圈
    local rightCX = DESIGN_W - marginR - R + btnOfsX
    local leftCX  = rightCX - R * 2 - gap

    skillBtnRects = {}
    autoMarchBtnRect = nil  -- 三国群英传模式: 无自动行军

    -- ---- 武技技能圈 (底部两个) ----
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

            if sk.cooldown > 0 then
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
                nvgFontSize(vg, math.floor(16 * btnSc))
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
            nvgFontSize(vg, math.floor(9 * btnSc))
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
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(cc.hi[1], cc.hi[2], cc.hi[3], 180))
        nvgText(vg, tx, ty + 18, st.desc, nil)
    end

    -- 提示文字
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local hintAlpha = math.floor(100 + 60 * math.sin(t * 2.5))
    nvgFillColor(vg, nvgRGBA(180, 165, 130, hintAlpha))
    nvgText(vg, startX - (#MARCH_STRATEGIES * (cardW + gap)) / 2, cardCY + cardH / 2 + 10, "点击选择策略", nil)

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
        { "★ 三国群英传模式", "开战即决胜负！所有兵力在战斗开始时一次性投入战场，无增援补给。\n武技技能: 右下角武技图标短按后拖拽释放，造成范围伤害。\n每个小兵代表100名士兵，战场气势恢宏。" },
        { "基本玩法", "阵容中的武灵自动部署上阵，所有兵力一次性投入战场，战损不补充。" },
        { "阵容布置", "最多上阵" .. #PLAYER_SLOTS .. "位武灵，在世界地图编辑阵容后进入战斗。" },
        { "武技技能", "装备武技后战斗中可拖拽释放，造成范围伤害。" },
        { "突破机制", "己方兵突破敌方临界线可直接攻击敌方大本营。" },
        { "胜负判定", "率先摧毁对方大本营获胜。" },
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
    nvgFontSize(vg, 16)
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
    nvgFontSize(vg, 16)
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
    nvgFontSize(vg, 14)
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
    nvgFontSize(vg, 15)
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
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(210, 200, 190, 220))
    nvgTextBox(vg, px + 20, py + 50, pw - 40, tech.desc, nil)

    -- CD信息
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
    nvgText(vg, px + 20, py + 130, string.format("冷却: %.0f秒  伤害: %d  类型: %s",
        sk.maxCooldown, sk.damage, sk.skillType == "line" and "直线" or (sk.skillType == "rect" and "矩形" or "圆形")), nil)

    -- 当前状态
    nvgFontSize(vg, 13)
    if sk.cooldown > 0 then
        nvgFillColor(vg, nvgRGBA(255, 120, 80, 200))
        nvgText(vg, px + 20, py + 148, string.format("冷却中: %.1f秒", sk.cooldown), nil)
    else
        nvgFillColor(vg, nvgRGBA(100, 255, 120, 200))
        nvgText(vg, px + 20, py + 148, "可释放", nil)
    end

    -- 关闭提示
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(160, 150, 140, 160))
    nvgText(vg, DESIGN_W / 2, py + ph - 16, "点击任意处关闭", nil)

    nvgRestore(vg)
end


-- ============================================================================
-- RTS 兵种选择栏 + 指令按钮 (底部左侧)
-- ============================================================================

--- 兵种颜色映射 (用于快速栏图标底色)
local RTS_CLASS_COLORS = {
    [1]  = { 200, 180, 140 },  -- 虎贲刀兵 土金
    [2]  = { 140, 200, 140 },  -- 连弩射手 绿
    [3]  = { 120, 150, 200 },  -- 铁盾重卫 蓝
    [4]  = { 200, 120, 160 },  -- 火攻术士 粉红
    [5]  = { 100, 220, 180 },  -- 军医道士 青绿
    [9]  = { 220, 180, 80 },   -- 铁骑先锋 金
    [10] = { 180, 130, 80 },   -- 战象巨兽 棕
    [11] = { 160, 100, 200 },  -- 夜行刺客 紫
    [12] = { 180, 180, 180 },  -- 长枪兵 银灰
    [13] = { 255, 140, 60 },   -- 火牛突袭 橙
    [14] = { 140, 100, 180 },  -- 驯兽使 暗紫
    [15] = { 100, 180, 240 },  -- 寒冰术士 冰蓝
    [16] = { 200, 200, 100 },  -- 蜂巢蝗群 黄绿
}

--- 全局碰撞矩形存储 (供 input 模块使用)
rtsClassBtnRects = rtsClassBtnRects or {}
rtsCmdBtnRects   = rtsCmdBtnRects or {}
rtsAllBtnRect    = nil  -- "全选" 按钮
rtsCancelBtnRect = nil  -- "取消" 按钮

function DrawRTSClassBar()
    if fontId < 0 then return end
    if gameState.phase ~= "BATTLE" or gameState.battlePhase ~= "FIGHT" or gameState.autoBattle then
        rtsClassBtnRects = {}
        rtsCmdBtnRects = {}
        rtsAllBtnRect = nil
        rtsCancelBtnRect = nil
        return
    end

    local t = gameState.gameTime
    local rts = rtsState
    if not rts then return end

    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())

    -- ======== 底部兵种快捷栏 ========
    local barH = 44
    local barY = DESIGN_H - barH - 2 - safeInsets.bottom
    local iconSize = 34
    local iconGap = 4
    local barX = 6 + safeInsets.left
    local classBar = rts.classBar or {}

    -- 全选按钮
    local allBtnW = 36
    local allBtnH = iconSize
    local allSelected = (rts.selectedClassId == nil and rts.activeCmd ~= nil)
    local allBtnX = barX
    local allBtnY = barY + (barH - allBtnH) / 2

    -- 底部栏背景
    local totalW = allBtnW + iconGap + #classBar * (iconSize + iconGap)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX - 4, barY, totalW + 12, barH, 6)
    nvgFillColor(vg, nvgRGBA(15, 12, 10, 180))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 100))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- "全" 按钮
    do
        local pulse = allSelected and (0.7 + 0.3 * math.sin(t * 4)) or 1.0
        nvgBeginPath(vg)
        nvgRoundedRect(vg, allBtnX, allBtnY, allBtnW, allBtnH, 4)
        if allSelected then
            nvgFillColor(vg, nvgRGBA(255, 200, 60, math.floor(60 * pulse)))
        else
            nvgFillColor(vg, nvgRGBA(60, 55, 50, 160))
        end
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 160, 120, allSelected and 200 or 80))
        nvgStrokeWidth(vg, allSelected and 1.2 or 0.6)
        nvgStroke(vg)

        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if allSelected then
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
        else
            nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
        end
        nvgText(vg, allBtnX + allBtnW / 2, allBtnY + allBtnH / 2, "全", nil)

        rtsAllBtnRect = { x = allBtnX, y = allBtnY, w = allBtnW, h = allBtnH, isDesign = true }
    end

    -- 各兵种按钮
    rtsClassBtnRects = {}
    local curX = allBtnX + allBtnW + iconGap

    for i, entry in ipairs(classBar) do
        local cid = entry.classId
        local selected = (rts.selectedClassId == cid)
        local cc = RTS_CLASS_COLORS[cid] or { 160, 160, 160 }
        local pulse = selected and (0.7 + 0.3 * math.sin(t * 4 + i * 0.5)) or 1.0
        local ix = curX
        local iy = barY + (barH - iconSize) / 2

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, ix, iy, iconSize, iconSize, 5)
        if selected then
            nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], math.floor(80 * pulse)))
        else
            nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 30))
        end
        nvgFill(vg)

        -- 边框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, ix, iy, iconSize, iconSize, 5)
        nvgStrokeColor(vg, nvgRGBA(cc[1], cc[2], cc[3], selected and math.floor(240 * pulse) or 80))
        nvgStrokeWidth(vg, selected and 1.5 or 0.6)
        nvgStroke(vg)

        -- 兵种缩写 (2字)
        local shortName = string.sub(entry.name, 1, 6)  -- UTF-8前2个中文字
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if selected then
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        else
            nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 200))
        end
        nvgText(vg, ix + iconSize / 2, iy + iconSize / 2 - 4, shortName, nil)

        -- 数量
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 160))
        nvgText(vg, ix + iconSize / 2, iy + iconSize - 1, "×" .. entry.count, nil)

        rtsClassBtnRects[i] = { x = ix, y = iy, w = iconSize, h = iconSize, classId = cid, isDesign = true }
        curX = curX + iconSize + iconGap
    end

    -- ======== 指令按钮 (选中兵种后在栏上方显示) ========
    rtsCmdBtnRects = {}
    rtsCancelBtnRect = nil

    if rts.selectedClassId ~= nil then
        local cmdTypes = { "move", "attack", "defend" }
        local cmdBtnW = 52
        local cmdBtnH = 28
        local cmdGap = 6
        local cmdY = barY - cmdBtnH - 6
        local cmdStartX = barX

        for ci, cmd in ipairs(cmdTypes) do
            local cc = RTS_CMD_COLORS[cmd]
            local isActive = (rts.activeCmd == cmd)
            local pulse = isActive and (0.7 + 0.3 * math.sin(t * 5)) or 1.0
            local bx = cmdStartX + (ci - 1) * (cmdBtnW + cmdGap)

            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, cmdY, cmdBtnW, cmdBtnH, 4)
            if isActive then
                nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], math.floor(100 * pulse)))
            else
                nvgFillColor(vg, nvgRGBA(25, 22, 18, 180))
            end
            nvgFill(vg)

            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, cmdY, cmdBtnW, cmdBtnH, 4)
            nvgStrokeColor(vg, nvgRGBA(cc[1], cc[2], cc[3], isActive and math.floor(240 * pulse) or 100))
            nvgStrokeWidth(vg, isActive and 1.5 or 0.8)
            nvgStroke(vg)

            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if isActive then
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            else
                nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 200))
            end
            local iconKey = RTS_CMD_ICONS[cmd]
            local cmdLabel = RTS_CMD_NAMES[cmd] or ""
            if iconKey and IMG[iconKey] and IsImageReady(IMG[iconKey]) then
                local icoSz = 12
                local pat = nvgImagePattern(vg, bx + 4, cmdY + cmdBtnH / 2 - icoSz / 2, icoSz, icoSz, 0, IMG[iconKey], 1.0)
                nvgBeginPath(vg); nvgRect(vg, bx + 4, cmdY + cmdBtnH / 2 - icoSz / 2, icoSz, icoSz)
                nvgFillPaint(vg, pat); nvgFill(vg)
                nvgFillColor(vg, isActive and nvgRGBA(255,255,255,255) or nvgRGBA(cc[1],cc[2],cc[3],200))
                nvgText(vg, bx + 4 + icoSz + 2 + (cmdBtnW - icoSz - 6) / 2, cmdY + cmdBtnH / 2, cmdLabel, nil)
            else
                nvgText(vg, bx + cmdBtnW / 2, cmdY + cmdBtnH / 2, cmdLabel, nil)
            end

            rtsCmdBtnRects[ci] = { x = bx, y = cmdY, w = cmdBtnW, h = cmdBtnH, cmd = cmd, isDesign = true }
        end

        -- 取消按钮
        local cancelX = cmdStartX + 3 * (cmdBtnW + cmdGap)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cancelX, cmdY, 36, cmdBtnH, 4)
        nvgFillColor(vg, nvgRGBA(80, 40, 30, 180))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 100, 80, 120))
        nvgStrokeWidth(vg, 0.8)
        nvgStroke(vg)

        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 150, 130, 220))
        nvgText(vg, cancelX + 18, cmdY + cmdBtnH / 2, "×", nil)

        rtsCancelBtnRect = { x = cancelX, y = cmdY, w = 36, h = cmdBtnH, isDesign = true }
    end

    -- ======== 指令目标标记 (战场中显示) ========
    if rts.showCmdMarker and rts.cmdTargetX then
        local mx = rts.cmdTargetX
        local my = rts.cmdTargetY
        local alpha = math.floor(255 * math.min(1, rts.cmdMarkerTimer / 0.3))
        local ring = 15 + 10 * (1 - math.min(1, rts.cmdMarkerTimer / 1.5))
        local cmdColor = RTS_CMD_COLORS[rts._lastCmd or "move"] or { 255, 255, 255 }

        -- 十字准心
        nvgBeginPath(vg)
        nvgMoveTo(vg, mx - ring, my); nvgLineTo(vg, mx + ring, my)
        nvgMoveTo(vg, mx, my - ring); nvgLineTo(vg, mx, my + ring)
        nvgStrokeColor(vg, nvgRGBA(cmdColor[1], cmdColor[2], cmdColor[3], alpha))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        -- 外圈
        nvgBeginPath(vg)
        nvgCircle(vg, mx, my, ring)
        nvgStrokeColor(vg, nvgRGBA(cmdColor[1], cmdColor[2], cmdColor[3], math.floor(alpha * 0.6)))
        nvgStrokeWidth(vg, 1.0)
        nvgStroke(vg)
    end

    nvgRestore(vg)
end


