-- ui/screens_misc.lua - 三国武灵录 (从 screens.lua 拆分)
function DrawDevEditorScreen()
    if gameState.phase ~= "DEV_EDITOR" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0

    DrawSettingsBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 返回按钮
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 200, 255, 240))
    nvgText(vg, backX + backW / 2, backY + backH / 2, "< 返回", nil)
    editorState.backBtnRect = { x = backX, y = backY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 37)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 200, 255, 240))
    nvgText(vg, cx, 32, "开发者·战场编辑器", nil)

    -- Tab 切换
    local tabNames = { "关卡编辑", "战斗参数", "快速测试", "石台编辑" }
    local tabW = 90
    local tabH = 36
    local tabGap = 6
    local tabStartX = cx - (#tabNames * tabW + (#tabNames - 1) * tabGap) / 2
    local tabY = 56
    editorState.tabRects = {}
    for i, name in ipairs(tabNames) do
        local tx = tabStartX + (i - 1) * (tabW + tabGap)
        local isActive = (editorState.tab == i)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 6)
        if isActive then
            nvgFillColor(vg, nvgRGBA(50, 100, 180, 240)); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(25, 30, 45, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 130, 200, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end
        nvgFontSize(vg, 23)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(240, 248, 255, 255) or nvgRGBA(140, 160, 190, 200))
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, name, nil)
        editorState.tabRects[i] = { x = tx, y = tabY, w = tabW, h = tabH }
    end

    local clipTop = tabY + tabH + 8
    local clipH = H - clipTop - 4
    local sOff = editorState.scrollY

    nvgSave(vg)
    nvgScissor(vg, 0, clipTop, W, clipH)

    local pad = 14
    local secW = W - pad * 2

    if editorState.tab == 1 then
        -- =====================
        -- Tab 1: 关卡编辑
        -- =====================
        local startY = clipTop + 10 + sOff
        editorState.btnRects = {}

        -- 关卡列表
        local cardH = 90
        local cardGap = 8
        for si, stage in ipairs(STAGES) do
            local cy = startY + (si - 1) * (cardH + cardGap)
            local isSelected = (editorState.selectedStage == si)
            local sc = stage.color or {180, 180, 180}

            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, secW, cardH, 8)
            if isSelected then
                nvgFillColor(vg, nvgRGBA(30, 50, 80, 230))
            else
                nvgFillColor(vg, nvgRGBA(18, 22, 38, 220))
            end
            nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, secW, cardH, 8)
            nvgStrokeColor(vg, isSelected and nvgRGBA(sc[1], sc[2], sc[3], 200) or nvgRGBA(60, 70, 90, 100))
            nvgStrokeWidth(vg, isSelected and 2 or 1); nvgStroke(vg)

            -- 左侧颜色标记
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy + 6, 4, cardH - 12, 2)
            nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 220)); nvgFill(vg)

            -- 关卡名
            nvgFontSize(vg, 27)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 240))
            nvgText(vg, pad + 16, cy + 22, si .. ". " .. stage.name, nil)

            -- 描述
            nvgFontSize(vg, 19)
            DrawWhiteInkText(pad + 16, cy + 46, stage.desc)

            -- 参数
            local sOver = editorState.stageOverrides[si]
            local eScale = sOver and sOver.enemyScale or stage.enemyScale
            nvgFontSize(vg, 18)
            DrawWhiteInkText(pad + 16, cy + 68, string.format("难度x%.1f  掉落阶%d", eScale, stage.maxTier))

            -- 难度调整按钮 (- / +)
            local adjBtnW = 34
            local adjBtnH = 28
            local adjY = cy + cardH / 2 - adjBtnH / 2

            -- 减
            local minusBtnX = secW - 10 - adjBtnW * 2 - 8
            nvgBeginPath(vg); nvgRoundedRect(vg, minusBtnX, adjY, adjBtnW, adjBtnH, 5)
            nvgFillColor(vg, nvgRGBA(180, 60, 50, 200)); nvgFill(vg)
            nvgFontSize(vg, 25); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(minusBtnX + adjBtnW / 2, adjY + adjBtnH / 2, "-")

            -- 加
            local plusBtnX = secW - 10 - adjBtnW
            nvgBeginPath(vg); nvgRoundedRect(vg, plusBtnX, adjY, adjBtnW, adjBtnH, 5)
            nvgFillColor(vg, nvgRGBA(50, 140, 80, 200)); nvgFill(vg)
            nvgFontSize(vg, 25); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(plusBtnX + adjBtnW / 2, adjY + adjBtnH / 2, "+")

            editorState.btnRects["stage_" .. si] = { x = pad, y = cy, w = secW, h = cardH }
            editorState.btnRects["stage_minus_" .. si] = { x = minusBtnX, y = adjY, w = adjBtnW, h = adjBtnH }
            editorState.btnRects["stage_plus_" .. si] = { x = plusBtnX, y = adjY, w = adjBtnW, h = adjBtnH }
        end

        -- 重置按钮
        local resetY = startY + #STAGES * (cardH + cardGap) + 12
        local resetW = 160
        local resetH = 40
        local resetX = cx - resetW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, resetX, resetY, resetW, resetH, 8)
        nvgFillColor(vg, nvgRGBA(120, 50, 40, 200)); nvgFill(vg)
        nvgFontSize(vg, 23); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, resetY + resetH / 2, "重置全部难度")
        editorState.btnRects["reset_stages"] = { x = resetX, y = resetY, w = resetW, h = resetH }

        local totalH = #STAGES * (cardH + cardGap) + 12 + resetH + 30
        editorState.contentHeight = math.max(0, totalH - clipH)

    elseif editorState.tab == 2 then
        -- =====================
        -- Tab 2: 战斗参数
        -- =====================
        local startY = clipTop + 10 + sOff
        editorState.btnRects = {}

        local params = {
            { key = "baseHpMax",        label = "基地血量",     default = GameConfig.BASE_HP_MAX,       step = 50, min = 100, max = 5000 },
            { key = "initialGold",      label = "初始军资",     default = GameConfig.INITIAL_GOLD,      step = 5,  min = 0,   max = 200 },
            { key = "enemySpawnCd",     label = "敌方出兵CD",   default = GameConfig.ENEMY_SPAWN_CD,    step = 0.1, min = 0.3, max = 10, fmt = "%.1f秒" },
            { key = "playerSpawnCd",    label = "我方出兵CD",   default = GameConfig.PLAYER_SPAWN_CD,   step = 0.1, min = 0.3, max = 10, fmt = "%.1f秒" },
            { key = "battleTimeLimit",  label = "战斗时限",     default = GameConfig.BATTLE_TIME_LIMIT or 180, step = 15, min = 30, max = 600, fmt = "%d秒" },
            { key = "soldierStatScale", label = "兵属性倍率",   default = GameConfig.SOLDIER_STAT_SCALE, step = 0.05, min = 0.05, max = 2.0, fmt = "%.2f" },
            { key = "deployCd",         label = "部署冷却",     default = GameConfig.DEPLOY_CD or 3.5,  step = 0.5, min = 1, max = 20, fmt = "%.1f秒" },
        }

        local cardH = 60
        local cardGap = 6
        for pi, p in ipairs(params) do
            local cy = startY + (pi - 1) * (cardH + cardGap)
            local curVal = editorState.overrides[p.key] or p.default

            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, secW, cardH, 8)
            nvgFillColor(vg, nvgRGBA(18, 24, 40, 220)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, secW, cardH, 8)
            nvgStrokeColor(vg, nvgRGBA(60, 90, 140, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 参数名
            nvgFontSize(vg, 23)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(160, 200, 255, 230))
            nvgText(vg, pad + 14, cy + cardH / 2, p.label, nil)

            -- 当前值
            local valStr = p.fmt and string.format(p.fmt, curVal) or tostring(math.floor(curVal))
            local isModified = editorState.overrides[p.key] ~= nil
            nvgFontSize(vg, 23)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, isModified and nvgRGBA(255, 200, 80, 255) or nvgRGBA(220, 220, 220, 220))
            nvgText(vg, cx + 20, cy + cardH / 2, valStr, nil)

            -- 减/加按钮
            local adjBtnW = 36
            local adjBtnH = 30
            local adjY = cy + cardH / 2 - adjBtnH / 2

            local minusBtnX = secW - 10 - adjBtnW * 2 - 10
            nvgBeginPath(vg); nvgRoundedRect(vg, minusBtnX, adjY, adjBtnW, adjBtnH, 5)
            nvgFillColor(vg, nvgRGBA(160, 50, 40, 200)); nvgFill(vg)
            nvgFontSize(vg, 25); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(minusBtnX + adjBtnW / 2, adjY + adjBtnH / 2, "-")

            local plusBtnX = secW - 10 - adjBtnW
            nvgBeginPath(vg); nvgRoundedRect(vg, plusBtnX, adjY, adjBtnW, adjBtnH, 5)
            nvgFillColor(vg, nvgRGBA(40, 130, 70, 200)); nvgFill(vg)
            nvgFontSize(vg, 25); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(plusBtnX + adjBtnW / 2, adjY + adjBtnH / 2, "+")

            editorState.btnRects["param_minus_" .. pi] = { x = minusBtnX, y = adjY, w = adjBtnW, h = adjBtnH }
            editorState.btnRects["param_plus_" .. pi] = { x = plusBtnX, y = adjY, w = adjBtnW, h = adjBtnH }
        end

        -- 重置按钮
        local resetY = startY + #params * (cardH + cardGap) + 12
        local resetW = 160
        local resetH = 40
        local resetX = cx - resetW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, resetX, resetY, resetW, resetH, 8)
        nvgFillColor(vg, nvgRGBA(120, 50, 40, 200)); nvgFill(vg)
        nvgFontSize(vg, 23); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, resetY + resetH / 2, "重置全部参数")
        editorState.btnRects["reset_params"] = { x = resetX, y = resetY, w = resetW, h = resetH }

        -- 应用提示
        local tipY = resetY + resetH + 16
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, tipY, "修改后的参数将在下次战斗生效")

        local totalH = #params * (cardH + cardGap) + 12 + resetH + 40
        editorState.contentHeight = math.max(0, totalH - clipH)

    elseif editorState.tab == 3 then
        -- =====================
        -- Tab 3: 快速测试
        -- =====================
        local startY = clipTop + 30 + sOff
        editorState.btnRects = {}

        -- 关卡选择
        nvgFontSize(vg, 25)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 200, 255, 230))
        nvgText(vg, cx, startY, "选择测试关卡", nil)
        startY = startY + 36

        local cols = 3
        local btnW2 = math.floor((secW - (cols - 1) * 8) / cols)
        local btnH2 = 50
        for si, stage in ipairs(STAGES) do
            local col = (si - 1) % cols
            local row = math.floor((si - 1) / cols)
            local bx = pad + col * (btnW2 + 8)
            local by = startY + row * (btnH2 + 8)
            local isSelected = (editorState.testStage == si)
            local sc = stage.color or {180, 180, 180}

            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, btnW2, btnH2, 6)
            if isSelected then
                nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 60)); nvgFill(vg)
                nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, btnW2, btnH2, 6)
                nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 220)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
            else
                nvgFillColor(vg, nvgRGBA(25, 30, 45, 200)); nvgFill(vg)
                nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, btnW2, btnH2, 6)
                nvgStrokeColor(vg, nvgRGBA(60, 70, 90, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            end
            nvgFontSize(vg, 21)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, isSelected and nvgRGBA(255, 255, 255, 240) or nvgRGBA(sc[1], sc[2], sc[3], 200))
            nvgText(vg, bx + btnW2 / 2, by + btnH2 / 2, stage.name, nil)

            editorState.btnRects["test_stage_" .. si] = { x = bx, y = by, w = btnW2, h = btnH2 }
        end

        local rows = math.ceil(#STAGES / cols)
        local gridBottom = startY + rows * (btnH2 + 8)

        -- 配置摘要
        local sumY = gridBottom + 20
        nvgFontSize(vg, 21)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 190, 140, 200))
        local selectedStage = STAGES[editorState.testStage]
        local sOver = editorState.stageOverrides[editorState.testStage]
        local eScale = sOver and sOver.enemyScale or selectedStage.enemyScale
        nvgText(vg, cx, sumY, string.format("当前: %s (难度x%.1f)", selectedStage.name, eScale), nil)

        -- 显示修改过的参数
        sumY = sumY + 28
        local hasOverrides = false
        for k, v in pairs(editorState.overrides) do
            if v ~= nil then hasOverrides = true; break end
        end
        if hasOverrides then
            nvgFontSize(vg, 18)
            DrawWhiteInkText(cx, sumY, "⚠ 存在参数覆盖（黄色标记）")
            sumY = sumY + 24
        end

        -- 开始测试按钮
        local testBtnW = 240
        local testBtnH = 52
        local testBtnX = cx - testBtnW / 2
        local testBtnY = sumY + 10
        local pulse = 0.8 + 0.2 * math.sin(t * 3)
        nvgBeginPath(vg); nvgRoundedRect(vg, testBtnX, testBtnY, testBtnW, testBtnH, 10)
        local testGrad = nvgLinearGradient(vg, testBtnX, testBtnY, testBtnX, testBtnY + testBtnH,
            nvgRGBA(50, math.floor(140 * pulse), math.floor(220 * pulse), 230),
            nvgRGBA(30, math.floor(90 * pulse), math.floor(160 * pulse), 230))
        nvgFillPaint(vg, testGrad); nvgFill(vg)
        nvgFontSize(vg, 29)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, testBtnY + testBtnH / 2, "开始测试战斗")
        editorState.btnRects["start_test"] = { x = testBtnX, y = testBtnY, w = testBtnW, h = testBtnH }

        editorState.contentHeight = 0  -- 单屏即可

    elseif editorState.tab == 4 then
        -- =====================
        -- Tab 4: 石台编辑
        -- =====================
        editorState.btnRects = {}
        local layoutIdx = editorState.editLayoutIdx or 1
        local layout = BATTLE_LAYOUTS[layoutIdx]
        if not layout then layout = BATTLE_LAYOUTS[1]; layoutIdx = 1 end

        -- 布局选择器 (顶部两行按钮: 第1行=默认+讨伐1~4, 第2行=讨伐5~7)
        local selY = clipTop + 4
        local selBtnH = 24
        local selGap = 3
        local availW = W - pad * 2
        -- 简短标签
        local shortNames = { "默认", "讨伐1", "讨伐2", "讨伐3", "讨伐4", "讨伐5", "讨伐6", "讨伐7" }
        -- 第1行: 布局 1~4
        local row1Count = 4
        local selBtnW1 = math.floor((availW - selGap * (row1Count - 1)) / row1Count)
        for li = 1, row1Count do
            local bx = pad + (li - 1) * (selBtnW1 + selGap)
            local isActive = (li == layoutIdx)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, selY, selBtnW1, selBtnH, 4)
            nvgFillColor(vg, isActive and nvgRGBA(50, 100, 180, 230) or nvgRGBA(25, 30, 45, 200)); nvgFill(vg)
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, isActive and nvgRGBA(240, 248, 255, 255) or nvgRGBA(140, 160, 190, 200))
            nvgText(vg, bx + selBtnW1 / 2, selY + selBtnH / 2, shortNames[li] or ("L" .. li), nil)
            editorState.btnRects["layout_" .. li] = { x = bx, y = selY, w = selBtnW1, h = selBtnH }
        end
        -- 第2行: 布局 5~8
        local selY2 = selY + selBtnH + selGap
        local row2Count = #BATTLE_LAYOUTS - row1Count
        local selBtnW2 = math.floor((availW - selGap * (row2Count - 1)) / row2Count)
        for li = row1Count + 1, #BATTLE_LAYOUTS do
            local ri = li - row1Count
            local bx = pad + (ri - 1) * (selBtnW2 + selGap)
            local isActive = (li == layoutIdx)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, selY2, selBtnW2, selBtnH, 4)
            nvgFillColor(vg, isActive and nvgRGBA(50, 100, 180, 230) or nvgRGBA(25, 30, 45, 200)); nvgFill(vg)
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, isActive and nvgRGBA(240, 248, 255, 255) or nvgRGBA(140, 160, 190, 200))
            nvgText(vg, bx + selBtnW2 / 2, selY2 + selBtnH / 2, shortNames[li] or ("L" .. li), nil)
            editorState.btnRects["layout_" .. li] = { x = bx, y = selY2, w = selBtnW2, h = selBtnH }
        end

        -- 背景预览区域 (尽可能大, 等比缩放)
        local prevTop = selY2 + selBtnH + 8
        local prevAvailH = H - prevTop - 88  -- 底部留按钮栏+图例
        local prevAvailW = W - pad * 2
        -- 背景原始比例 BG_W:BG_H = 1142:2048
        local bgAspect = BG_W / BG_H
        local prevH = prevAvailH
        local prevW = prevH * bgAspect
        if prevW > prevAvailW then
            prevW = prevAvailW
            prevH = prevW / bgAspect
        end
        local prevX = cx - prevW / 2
        local prevY = prevTop

        editorState.previewRect = { x = prevX, y = prevY, w = prevW, h = prevH }

        -- 绘制背景图
        local bgH = layout.bgHandle or IMG.bg
        if bgH and IsImageReady(bgH) then
            local pat = nvgImagePattern(vg, prevX, prevY, prevW, prevH, 0, bgH, 0.85)
            nvgBeginPath(vg); nvgRoundedRect(vg, prevX, prevY, prevW, prevH, 4)
            nvgFillPaint(vg, pat); nvgFill(vg)
        else
            nvgBeginPath(vg); nvgRoundedRect(vg, prevX, prevY, prevW, prevH, 4)
            nvgFillColor(vg, nvgRGBA(30, 35, 50, 200)); nvgFill(vg)
        end
        -- 坐标转换: 背景像素 → 预览坐标
        local function BgToPreview(bgPx, bgPy)
            return prevX + bgPx * (prevW / BG_W), prevY + bgPy * (prevH / BG_H)
        end

        -- 卡牌缩略图尺寸 (按背景像素空间中的卡牌占位计算)
        local cardBgW = SLOT_CARD_W / BG2D_X  -- 设计尺寸→背景像素
        local cardBgH = SLOT_CARD_H / BG2D_Y
        local cardPrevW = cardBgW * (prevW / BG_W)  -- 背景像素→预览像素
        local cardPrevH = cardBgH * (prevH / BG_H)
        local slotR = math.max(8, prevW * 0.025)
        local hitR = math.max(slotR, cardPrevW * 0.6)  -- 点击区域

        -- 绘制敌方石台 (红色)
        for ei, pos in ipairs(layout.enemySlots) do
            local sx, sy = BgToPreview(pos[1], pos[2])
            local key = "enemy_" .. ei
            local isSel = editorState.selectedSlots[key]
            local isDragging = editorState.slotDragging and isSel
            -- 卡牌缩略图 (使用武灵独立图)
            local previewCard = ENEMY_CARDS[((ei - 1) % #ENEMY_CARDS) + 1]
            local prevImg = previewCard and GetHeroSheet(previewCard) or -1
            if prevImg and prevImg > 0 then
                local imgW, imgH = nvgImageSize(vg, prevImg)
                if imgW > 4 and imgH > 4 then
                    local p = nvgImagePattern(vg, sx - cardPrevW / 2, sy - cardPrevH / 2, cardPrevW, cardPrevH, 0, prevImg, 0.7)
                    nvgBeginPath(vg); nvgRoundedRect(vg, sx - cardPrevW / 2, sy - cardPrevH / 2, cardPrevW, cardPrevH, 2)
                    nvgFillPaint(vg, p); nvgFill(vg)
                end
            end
            -- 选中高亮圈
            if isSel then
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, slotR + 4)
                nvgStrokeColor(vg, nvgRGBA(255, 230, 60, 220))
                nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
            end
            -- 外圈
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, slotR + 1)
            nvgStrokeColor(vg, isDragging and nvgRGBA(255, 255, 100, 240) or nvgRGBA(255, 80, 60, 200))
            nvgStrokeWidth(vg, isDragging and 3 or 1.5); nvgStroke(vg)
            -- 标号
            nvgFontSize(vg, math.max(10, slotR * 1.0))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(sx, sy, "E" .. ei)
            editorState.btnRects["eslot_" .. ei] = { x = sx - hitR, y = sy - hitR, w = hitR * 2, h = hitR * 2 }
        end

        -- 绘制玩家石台 (蓝色)
        for pi, pos in ipairs(layout.playerSlots) do
            local sx, sy = BgToPreview(pos[1], pos[2])
            local key = "player_" .. pi
            local isSel = editorState.selectedSlots[key]
            local isDragging = editorState.slotDragging and isSel
            -- 卡牌缩略图 (玩家第一张卡: row=0, col=0)
            if IMG.heroSheet and IMG.heroSheet > 0 then
                nvgSave(vg)
                nvgScissor(vg, sx - cardPrevW / 2, sy - cardPrevH / 2, cardPrevW, cardPrevH)
                local totalImgW = cardPrevW * SHEET_COLS
                local totalImgH = cardPrevH * SHEET_ROWS
                local ox = sx - cardPrevW / 2
                local oy = sy - cardPrevH / 2
                local p = nvgImagePattern(vg, ox, oy, totalImgW, totalImgH, 0, IMG.heroSheet, 0.7)
                nvgBeginPath(vg); nvgRoundedRect(vg, ox, oy, cardPrevW, cardPrevH, 2)
                nvgFillPaint(vg, p); nvgFill(vg)
                nvgRestore(vg)
            end
            -- 选中高亮圈
            if isSel then
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, slotR + 4)
                nvgStrokeColor(vg, nvgRGBA(255, 230, 60, 220))
                nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
            end
            -- 外圈
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, slotR + 1)
            nvgStrokeColor(vg, isDragging and nvgRGBA(255, 255, 100, 240) or nvgRGBA(60, 140, 255, 200))
            nvgStrokeWidth(vg, isDragging and 3 or 1.5); nvgStroke(vg)
            -- 标号
            nvgFontSize(vg, math.max(10, slotR * 1.0))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(sx, sy, "P" .. pi)
            editorState.btnRects["pslot_" .. pi] = { x = sx - hitR, y = sy - hitR, w = hitR * 2, h = hitR * 2 }
        end

        -- === 底部: 选中数量 + 坐标信息 ===
        local infoY = prevY + prevH + 4
        local selCount = 0
        for _ in pairs(editorState.selectedSlots) do selCount = selCount + 1 end
        nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(pad, infoY + 7,
            string.format("敌%d 我%d | 选中%d", #layout.enemySlots, #layout.playerSlots, selCount))
        -- 拖拽坐标实时显示
        if editorState.slotDragging and editorState.slotPressKey then
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(W - pad, infoY + 7, "拖拽中...")
        else
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(W - pad, infoY + 7, "点选+拖拽移动")
        end

        -- === 底部: 操作按钮行 (2行: 选择按钮 + 撤销/保存) ===
        local btnY1 = infoY + 18
        local btnH = 26
        local btnGap = 4
        -- 第1行: 选我方 | 选敌方 | 清除选择
        local row1Btns = {
            { "sel_player", "选我方",  {50, 80, 160},  {180, 210, 255} },
            { "sel_enemy",  "选敌方",  {160, 60, 50},  {255, 200, 180} },
            { "sel_clear",  "清除",    {60, 60, 70},   {160, 160, 170} },
        }
        local r1BtnW = math.floor((availW - btnGap * (#row1Btns - 1)) / #row1Btns)
        for bi, btn in ipairs(row1Btns) do
            local bx = pad + (bi - 1) * (r1BtnW + btnGap)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, btnY1, r1BtnW, btnH, 4)
            nvgFillColor(vg, nvgRGBA(btn[3][1], btn[3][2], btn[3][3], 200)); nvgFill(vg)
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(btn[4][1], btn[4][2], btn[4][3], 240))
            nvgText(vg, bx + r1BtnW / 2, btnY1 + btnH / 2, btn[2], nil)
            editorState.btnRects[btn[1]] = { x = bx, y = btnY1, w = r1BtnW, h = btnH }
        end
        -- 第2行: 撤销 | 保存配置
        local btnY2 = btnY1 + btnH + btnGap
        local undoCount = #slotUndoStack
        local saveFlash = editorState.saveFlashT and (os.clock() - editorState.saveFlashT) < 1.5
        local row2Btns = {
            { "slot_undo", "撤销(" .. undoCount .. ")",
              undoCount > 0 and {180, 140, 50} or {60, 60, 70},
              undoCount > 0 and {255, 240, 180} or {100, 100, 110} },
            { "slot_save", saveFlash and "已导出!" or "导出配置",
              saveFlash and {60, 200, 100} or {40, 140, 80},
              saveFlash and {255, 255, 255} or {220, 255, 230} },
        }
        local r2BtnW = math.floor((availW - btnGap * (#row2Btns - 1)) / #row2Btns)
        for bi, btn in ipairs(row2Btns) do
            local bx = pad + (bi - 1) * (r2BtnW + btnGap)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, btnY2, r2BtnW, btnH, 4)
            nvgFillColor(vg, nvgRGBA(btn[3][1], btn[3][2], btn[3][3], 200)); nvgFill(vg)
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(btn[4][1], btn[4][2], btn[4][3], 240))
            nvgText(vg, bx + r2BtnW / 2, btnY2 + btnH / 2, btn[2], nil)
            editorState.btnRects[btn[1]] = { x = bx, y = btnY2, w = r2BtnW, h = btnH }
        end

        editorState.contentHeight = 0
    end

    nvgRestore(vg)
end


--- 应用编辑器参数覆盖到战斗系统
function ApplyEditorOverrides()
    local o = editorState.overrides
    if o.baseHpMax then
        BASE_HP_MAX = o.baseHpMax
    end
    if o.initialGold then
        GameConfig.INITIAL_GOLD = o.initialGold
    end
    if o.enemySpawnCd then
        ENEMY_SPAWN_CD = o.enemySpawnCd
        GameConfig.ENEMY_SPAWN_CD = o.enemySpawnCd
    end
    if o.playerSpawnCd then
        PLAYER_SPAWN_CD = o.playerSpawnCd
        GameConfig.PLAYER_SPAWN_CD = o.playerSpawnCd
    end
    if o.battleTimeLimit then
        BATTLE_TIME_LIMIT = o.battleTimeLimit
        GameConfig.BATTLE_TIME_LIMIT = o.battleTimeLimit
    end
    if o.soldierStatScale then
        SOLDIER_STAT_SCALE = o.soldierStatScale
        GameConfig.SOLDIER_STAT_SCALE = o.soldierStatScale
    end
    if o.deployCd then
        DEPLOY_CD = o.deployCd
        GameConfig.DEPLOY_CD = o.deployCd
    end
    -- 应用关卡难度覆盖
    for si, sOver in pairs(editorState.stageOverrides) do
        if STAGES[si] and sOver.enemyScale then
            STAGES[si].enemyScale = sOver.enemyScale
        end
    end
end


-- ============================================================================

--- 绘制教程引导遮罩 + 高亮 + 提示文字 (step 2-13)
function DrawTutorialGuideOverlay()
    local ts = tutorialState
    if not ts.active then return end
    local W, H = DESIGN_W, DESIGN_H
    local step = ts.step

    -- 确定当前步骤的目标按钮和提示文字
    local targetRect = nil
    local hintText = nil

    if step == 2 then
        targetRect = settingsPage.btnRect
        hintText = "点击「设置」按钮"
    elseif step == 3 then
        targetRect = settingsPage.autoMarchToggleRect
        hintText = "开启「自动行军」"
    elseif step == 4 then
        targetRect = settingsPage.adjustPosBtnRect
        hintText = "点击「调整位置」适配UI"
    elseif step == 5 then
        hintText = "拖动调整UI位置，完成后点击确认"
    elseif step == 6 then
        targetRect = menuBtnRects and menuBtnRects.gacha
        hintText = "点击「召唤武灵」抽取角色"
    elseif step == 7 then
        if gachaState.showResults and gachaConfirmBtnRect then
            targetRect = gachaConfirmBtnRect
            hintText = "点击确认召唤结果"
        elseif gachaState.pulling then
            hintText = "召唤中..."
        else
            targetRect = gachaSingleBtnRect
            hintText = "点击「单抽」召唤武灵"
        end
    elseif step == 8 then
        hintText = "将武灵拖放到石台上"
    elseif step == 9 then
        targetRect = battleChangeBgBtnRect
        hintText = "点击「换战场」切换战斗风格"
    elseif step == 10 then
        targetRect = shopFightBtnRect
        hintText = "点击「开战」开始战斗!"
    elseif step == 11 then
        targetRect = shopRefreshBtnRect
        hintText = "点击「刷新」获取新武灵"
    elseif step == 12 then
        hintText = "拖拽武灵部署到石台上"
    elseif step == 13 then
        hintText = "消灭所有敌人!"
    else
        return
    end

    -- 半透明遮罩 (有目标按钮时镂空高亮)
    if targetRect then
        local r = targetRect
        local pad = 8
        local hx, hy = r.x - pad, r.y - pad
        local hw, hh = r.w + pad * 2, r.h + pad * 2

        -- 四周遮罩 (上/下/左/右)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, hy)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 160)); nvgFill(vg)
        nvgBeginPath(vg); nvgRect(vg, 0, hy + hh, W, H - hy - hh)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 160)); nvgFill(vg)
        nvgBeginPath(vg); nvgRect(vg, 0, hy, hx, hh)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 160)); nvgFill(vg)
        nvgBeginPath(vg); nvgRect(vg, hx + hw, hy, W - hx - hw, hh)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 160)); nvgFill(vg)

        -- 高亮边框 (金色脉动)
        local pulse = 0.7 + 0.3 * math.sin(ts.hintTimer * 4)
        local ga = math.floor(200 * pulse)
        nvgBeginPath(vg); nvgRoundedRect(vg, hx, hy, hw, hh, 6)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 80, ga))
        nvgStrokeWidth(vg, 2.5); nvgStroke(vg)

        -- 手指动画 (在目标下方)
        local fingerX = r.x + r.w / 2
        local fingerY = r.y + r.h + 18 + ts.fingerY
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 28)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, 230))
        nvgText(vg, fingerX, fingerY, "^", nil)
    else
        -- 无目标按钮: 淡遮罩 + 居中提示
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 80)); nvgFill(vg)
    end

    -- 提示文字 (显示在屏幕上方)
    if hintText then
        local textY = 80
        if targetRect and targetRect.y < H * 0.3 then
            textY = targetRect.y + targetRect.h + 60
        end
        nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 文字背景条
        nvgFontSize(vg, 24)
        local tw = nvgTextBounds(vg, 0, 0, hintText, nil)
        local bgW = tw + 40
        local bgH = 44
        local bgX = (W - bgW) / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, bgX, textY - bgH / 2, bgW, bgH, 10)
        nvgFillColor(vg, nvgRGBA(20, 15, 35, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 140, 255, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 文字
        DrawWhiteInkText(W / 2, textY, hintText)
    end

    -- 退出按钮 (步骤 8-13 战斗中可退出)
    if step >= 8 and step <= 13 then
        local exitW, exitH = 80, 32
        local exitX, exitY = W - exitW - 12, 10
        nvgBeginPath(vg); nvgRoundedRect(vg, exitX, exitY, exitW, exitH, 6)
        nvgFillColor(vg, nvgRGBA(60, 40, 80, 180)); nvgFill(vg)
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(exitX + exitW / 2, exitY + exitH / 2, "跳过")
        ts.tutorialSkipBtnRect = { x = exitX, y = exitY, w = exitW, h = exitH }
    end
end


function DrawTutorialExitConfirmPopup()
    local ts = tutorialState
    if not ts.exitConfirm then return end
    local W, H = DESIGN_W, DESIGN_H

    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 120)); nvgFill(vg)

    -- 弹窗面板 (放大)
    local pw, ph = 380, 220
    local px, py = (W - pw) / 2, (H - ph) / 2 - 20
    -- 底板
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
    local bg = nvgLinearGradient(vg, px, py, px, py + ph,
        nvgRGBA(40, 30, 60, 245), nvgRGBA(25, 18, 40, 245))
    nvgFillPaint(vg, bg); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 255, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 标题
    nvgFontFaceId(vg, GetMainFont())
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 32)
    DrawWhiteInkText(W / 2, py + 48, "退出战斗引导")

    -- 说明文字
    nvgFontSize(vg, 24)
    DrawWhiteInkText(W / 2, py + 95, "确认退出并直接领取奖励？")

    -- 按钮
    local btnW2, btnH2 = 130, 44
    local gap = 28
    local btnY = py + ph - 64
    local confirmX = W / 2 - btnW2 - gap / 2
    local cancelX = W / 2 + gap / 2

    -- 确认按钮
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, btnY, btnW2, btnH2, 8)
    local cbg = nvgLinearGradient(vg, confirmX, btnY, confirmX, btnY + btnH2,
        nvgRGBA(255, 200, 80, 220), nvgRGBA(220, 160, 40, 220))
    nvgFillPaint(vg, cbg); nvgFill(vg)
    nvgFontSize(vg, 26)
    nvgFillColor(vg, nvgRGBA(50, 30, 10, 255))
    nvgText(vg, confirmX + btnW2 / 2, btnY + btnH2 / 2, "确认退出", nil)
    ts.exitConfirmBtnRect = { x = confirmX, y = btnY, w = btnW2, h = btnH2 }

    -- 取消按钮
    nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, btnY, btnW2, btnH2, 8)
    nvgFillColor(vg, nvgRGBA(60, 50, 80, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(140, 120, 180, 140)); nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
    nvgFontSize(vg, 26)
    DrawWhiteInkText(cancelX + btnW2 / 2, btnY + btnH2 / 2, "继续战斗")
    ts.exitCancelBtnRect = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
end


--- 绘制胜利过渡 (step 14)
function DrawTutorialVictoryTransition()
    local ts = tutorialState
    local W, H = DESIGN_W, DESIGN_H
    local t = ts.fadeTimer

    -- 渐黑遮罩
    local alpha = math.min(1, t / 2.0)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 10, math.floor(255 * alpha))); nvgFill(vg)

    -- 文字 "试炼完成!"
    if t > 0.5 then
        local textAlpha = math.min(1, (t - 0.5) / 1.0)
        nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 光晕
        local glowR = 60 * textAlpha
        local glow = nvgRadialGradient(vg, W / 2, H / 2 - 20, 5, glowR,
            nvgRGBA(255, 220, 80, math.floor(60 * textAlpha)),
            nvgRGBA(255, 200, 50, 0))
        nvgBeginPath(vg); nvgCircle(vg, W / 2, H / 2 - 20, glowR)
        nvgFillPaint(vg, glow); nvgFill(vg)

        nvgFontSize(vg, 43)
        nvgFillColor(vg, nvgRGBA(255, 230, 100, math.floor(255 * textAlpha)))
        nvgText(vg, W / 2, H / 2 - 20, "试炼完成!", nil)

        nvgFontSize(vg, 23)
        nvgFillColor(vg, nvgRGBA(220, 200, 150, math.floor(200 * textAlpha)))
        nvgText(vg, W / 2, H / 2 + 20, "欢迎来到讨伐...", nil)
    end
end


--- 教程初始奖励弹窗 (step 15)
function DrawTutorialRewardPopup()
    local ts = tutorialState
    local W, H = DESIGN_W, DESIGN_H
    local reward = ts.tutorialReward
    if not reward then return end

    -- 全屏黑底
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(12, 12, 22, 230)); nvgFill(vg)

    local popAlpha = math.min(1, ts.stepTimer / 0.5)
    nvgSave(vg)
    nvgGlobalAlpha(vg, popAlpha)

    -- 标题
    nvgFontFaceId(vg, GetMainFont())
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 39)
    DrawWhiteInkText(W / 2, H * 0.22, "初始奖励")

    nvgFontSize(vg, 19)
    DrawWhiteInkText(W / 2, H * 0.28, "恭喜完成试炼，获得初始奖励！")

    -- 兵甲展示卡片
    local cardW, cardH = 140, 180
    local cx = W / 2 - cardW / 2
    local cy = H * 0.34
    local tierInfo = EQUIP_TIERS[reward.tier]
    local setInfo = EQUIPMENT_SETS[reward.setIdx]
    local piece = setInfo.pieces[reward.slotIdx]
    local tc = tierInfo.color

    -- 卡片背景
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 8)
    nvgFillColor(vg, nvgRGBA(25, 20, 35, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 光晕
    local glowPulse = 0.7 + 0.3 * math.sin(ts.stepTimer * 2)
    local glowR = 50 * glowPulse
    local glow = nvgRadialGradient(vg, W / 2, cy + cardH / 2 - 20, 5, glowR,
        nvgRGBA(tc[1], tc[2], tc[3], math.floor(60 * glowPulse)),
        nvgRGBA(tc[1], tc[2], tc[3], 0))
    nvgBeginPath(vg); nvgCircle(vg, W / 2, cy + cardH / 2 - 20, glowR)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 兵甲图标
    local iconSize = 80
    local iconX = W / 2 - iconSize / 2
    local iconY = cy + 15
    if IMG.equipmentSheet and IMG.equipmentSheet > 0 then
        DrawEquipTierBg(iconX, iconY, iconSize, iconSize, reward.tier, 5)
        DrawCardImage(iconX, iconY, iconSize, iconSize,
            IMG.equipmentSheet, reward.slotIdx - 1, reward.setIdx - 1,
            EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
    end

    -- 兵甲名称
    nvgFontSize(vg, 21)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 255))
    nvgText(vg, W / 2, iconY + iconSize + 18, piece.name, nil)

    -- 品阶
    nvgFontSize(vg, 17)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180))
    nvgText(vg, W / 2, iconY + iconSize + 40, tierInfo.name, nil)

    -- 套装名
    nvgFontSize(vg, 15)
    DrawWhiteInkText(W / 2, iconY + iconSize + 58, setInfo.name)

    -- 武技奖励展示 (武技7)
    local skillRewardIdx = 7
    local skillRewardTech = SKILL_TECHNIQUES[skillRewardIdx]
    if skillRewardTech then
        local skTier = SKILL_TIERS[skillRewardTech.tier]
        local stc = skTier.color
        local skCardW, skCardH = 80, 90
        local skCx = W / 2 - skCardW / 2
        local skCy = cy + cardH + 12
        -- 小标题
        nvgFontSize(vg, 17)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(W / 2, skCy - 6, "额外赠送武技")
        -- 武技小卡片
        nvgBeginPath(vg); nvgRoundedRect(vg, skCx, skCy + 6, skCardW, skCardH, 6)
        nvgFillColor(vg, nvgRGBA(25, 20, 35, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(stc[1], stc[2], stc[3], 180))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        -- 武技图标
        local skIconSz = 48
        drawSkillIcon(skillRewardTech.iconIdx, W / 2 - skIconSz / 2, skCy + 12, skIconSz, 4)
        -- 武技名
        nvgFontSize(vg, 17)
        nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], 240))
        nvgText(vg, W / 2, skCy + 12 + skIconSz + 16, skillRewardTech.name, nil)
        -- 调整领取按钮Y位置
        cy = skCy + skCardH -- 更新基准
    end

    -- 领取按钮
    local btnW, btnH = 160, 44
    local btnX = W / 2 - btnW / 2
    local btnY = cy + 30
    local btnPulse = 0.85 + 0.15 * math.sin(ts.stepTimer * 3)

    nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 8)
    local btnGrad = nvgLinearGradient(vg, btnX, btnY, btnX, btnY + btnH,
        nvgRGBA(255, 200, 60, math.floor(255 * btnPulse)),
        nvgRGBA(220, 160, 30, math.floor(255 * btnPulse)))
    nvgFillPaint(vg, btnGrad); nvgFill(vg)

    nvgFontSize(vg, 23)
    nvgFillColor(vg, nvgRGBA(40, 20, 0, 255))
    nvgText(vg, W / 2, btnY + btnH / 2, "领取", nil)

    -- 保存按钮区域供点击检测
    ts.rewardBtnRect = { x = btnX, y = btnY, w = btnW, h = btnH }

    nvgRestore(vg)
end
