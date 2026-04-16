-- ui/screens_combat.lua - 三国武灵录 (从 screens.lua 拆分)
function DrawAbyssSelectScreen()
    if gameState.phase ~= "ABYSS_SELECT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime

    -- 讨伐专属背景 (新哥特风)
    DrawBgImage(IMG.abyssSelectBg, W, H, 572, 1025)
    -- 顶部暗化渐变
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, H * 0.15,
        nvgRGBA(8, 4, 16, 180), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H * 0.15)
    nvgFillPaint(vg, topGrad); nvgFill(vg)
    -- 底部讨伐迷雾
    local botGrad = nvgLinearGradient(vg, 0, H * 0.75, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(12, 4, 20, 160))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.75, W, H * 0.25)
    nvgFillPaint(vg, botGrad); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 顶部返回按钮 (暗红哥特边框)
    local topY = 14
    local backW, backH = 90, 34
    nvgBeginPath(vg); nvgRoundedRect(vg, 14, topY, backW, backH, 4)
    local backBg = nvgLinearGradient(vg, 14, topY, 14, topY + backH,
        nvgRGBA(40, 12, 18, 220), nvgRGBA(20, 8, 12, 220))
    nvgFillPaint(vg, backBg); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 50, 50, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(14 + backW/2, topY + backH/2, "< 返回")
    abyssState.backBtnRect = { x = 14, y = topY, w = backW, h = backH }

    -- 标题区域 (白色+黑描边)
    local titleCY = topY + backH / 2
    nvgFontSize(vg, 40); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, titleCY, "讨伐战")
    DrawHelpBtn(DESIGN_W - 14 - 30, topY + (backH - 30) / 2, 30)

    -- 装饰: 左右血红渐变分隔线
    local sepY2 = titleCY + 24
    local sepHW = 120
    local sepGradL = nvgLinearGradient(vg, cx - sepHW, sepY2, cx - 6, sepY2,
        nvgRGBA(120, 40, 40, 0), nvgRGBA(160, 60, 60, 160))
    nvgBeginPath(vg); nvgMoveTo(vg, cx - sepHW, sepY2); nvgLineTo(vg, cx - 6, sepY2)
    nvgStrokeWidth(vg, 1); nvgStrokePaint(vg, sepGradL); nvgStroke(vg)
    local sepGradR = nvgLinearGradient(vg, cx + 6, sepY2, cx + sepHW, sepY2,
        nvgRGBA(160, 60, 60, 160), nvgRGBA(120, 40, 40, 0))
    nvgBeginPath(vg); nvgMoveTo(vg, cx + 6, sepY2); nvgLineTo(vg, cx + sepHW, sepY2)
    nvgStrokeWidth(vg, 1); nvgStrokePaint(vg, sepGradR); nvgStroke(vg)
    -- 中心骷髅菱形
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, sepY2 - 4); nvgLineTo(vg, cx + 4, sepY2)
    nvgLineTo(vg, cx, sepY2 + 4); nvgLineTo(vg, cx - 4, sepY2)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(180, 80, 80, 200)); nvgFill(vg)

    -- 讨伐入场费 & 爆率提示
    nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 140, 100, 180))
    nvgText(vg, cx, sepY2 + 16, "每次消耗100虎符 | 大量装备掉落", nil)

    -- 关卡列表
    local cardW = W - 32
    local cardH = 110
    local cardGap = 10
    local listStartY = sepY2 + 34
    abyssState.floorRects = {}

    for i = 1, #abyssState.floors do
        local floor = abyssState.floors[i]
        local fc = floor.color
        local cy = listStartY + (i - 1) * (cardH + cardGap)
        local isUnlocked = (stageState.maxUnlocked >= floor.unlockStage)

        abyssState.floorRects[i] = { x = 16, y = cy, w = cardW, h = cardH }

        -- 卡片背景 (深色哥特渐变底板)
        nvgBeginPath(vg); nvgRoundedRect(vg, 16, cy, cardW, cardH, 5)
        if isUnlocked then
            local cardBg = nvgLinearGradient(vg, 16, cy, 16 + cardW, cy,
                nvgRGBA(18, 10, 28, 200), nvgRGBA(28, 16, 22, 200))
            nvgFillPaint(vg, cardBg)
        else
            nvgFillColor(vg, nvgRGBA(20, 18, 24, 210))
        end
        nvgFill(vg)

        -- 左侧竖条装饰 (颜色标识)
        nvgBeginPath(vg); nvgRoundedRect(vg, 16, cy, 4, cardH, 2)
        if isUnlocked then
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 200))
        else
            nvgFillColor(vg, nvgRGBA(50, 45, 55, 120))
        end
        nvgFill(vg)

        -- 边框 (暗红描边)
        nvgBeginPath(vg); nvgRoundedRect(vg, 16, cy, cardW, cardH, 5)
        if isUnlocked then
            local bPulse = 0.6 + 0.4 * math.sin(t * 1.8 + i * 0.9)
            nvgStrokeColor(vg, nvgRGBA(
                math.floor(fc[1] * 0.5 + 120 * 0.5),
                math.floor(fc[2] * 0.3 + 40 * 0.7),
                math.floor(fc[3] * 0.3 + 40 * 0.7),
                math.floor(100 * bPulse)))
        else
            nvgStrokeColor(vg, nvgRGBA(45, 40, 50, 80))
        end
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 左侧图标 (方形圆角)
        local iconSize = 56
        local iconX = 28
        local iconY = cy + (cardH - iconSize) / 2

        if IsImageReady(IMG.abyssIcon and IMG.abyssIcon[i]) then
            local pat = nvgImagePattern(vg, iconX, iconY, iconSize, iconSize, 0, IMG.abyssIcon[i], isUnlocked and 1.0 or 0.25)
            nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 6)
            nvgFillPaint(vg, pat); nvgFill(vg)
        else
            nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 6)
            nvgFillColor(vg, nvgRGBA(25, 18, 35, 200)); nvgFill(vg)
            DrawSpinner(iconX + iconSize/2, iconY + iconSize/2, 12)
        end
        -- 图标边框
        nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 6)
        if isUnlocked then
            nvgStrokeColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 120))
        else
            nvgStrokeColor(vg, nvgRGBA(45, 40, 50, 70))
        end
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 右侧文字区域
        local textX = iconX + iconSize + 12
        local textCY2 = cy + cardH / 2
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

        if isUnlocked then
            -- 层数 + 名称
            local floorTitle = "第" .. i .. "层 · " .. floor.name
            nvgFontSize(vg, 27)
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 240))
            nvgText(vg, textX, textCY2 - 22, floorTitle, nil)

            -- 描述
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(160, 150, 140, 180))
            nvgText(vg, textX, textCY2 + 2, floor.desc, nil)

            -- 战力评估
            local myP = CalcPlayerTotalPower()
            local ePow, minReq, recReq = CalcStageRequiredPower(floor.enemyScale)
            local pRatio = (ePow > 0) and (myP / ePow) or 99.0
            local gT, gC = GetPowerGrade(pRatio)
            nvgFontSize(vg, 20)
            nvgFillColor(vg, (myP >= minReq) and nvgRGBA(80, 200, 110, 210) or nvgRGBA(220, 70, 70, 210))
            nvgText(vg, textX, textCY2 + 24, "需 " .. FormatPower(minReq), nil)
            local recColor = (myP >= recReq) and nvgRGBA(80, 200, 110, 210) or nvgRGBA(220, 170, 60, 210)
            nvgFillColor(vg, recColor)
            nvgText(vg, textX + 80, textCY2 + 24, "荐 " .. FormatPower(recReq), nil)
            nvgFillColor(vg, nvgRGBA(gC[1], gC[2], gC[3], 200))
            nvgText(vg, textX + 160, textCY2 + 24, gT, nil)

            -- 右侧箭头
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 28)
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 100))
            nvgText(vg, 16 + cardW - 10, textCY2, ">", nil)
        else
            -- 锁定
            nvgFontSize(vg, 27)
            nvgFillColor(vg, nvgRGBA(80, 75, 85, 180))
            nvgText(vg, textX, textCY2 - 12, "第" .. i .. "层 · ???", nil)
            nvgFontSize(vg, 22)
            local reqStage = STAGES[floor.unlockStage]
            local reqName = reqStage and reqStage.name or ("关卡" .. floor.unlockStage)
            nvgFillColor(vg, nvgRGBA(100, 80, 80, 150))
            nvgText(vg, textX, textCY2 + 12, "通关「" .. reqName .. "」解锁", nil)
            -- 锁图标
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 26)
            nvgFillColor(vg, nvgRGBA(80, 60, 60, 120))
            nvgText(vg, 16 + cardW - 10, textCY2, "锁", nil)
        end
    end

    -- ===========================
    -- 讨伐关卡预览弹窗 (重制)
    -- ===========================
    if abyssState.showPreview then
        local fi = abyssState.selectedFloor
        local floor = abyssState.floors[fi]
        if floor then
            local fc = floor.color
            local popW = W - 32
            local popH = 240
            local popX = 16
            local popY = H / 2 - popH / 2 - 20

            -- 全屏遮罩
            nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 140)); nvgFill(vg)

            -- 弹窗底板 (暗红渐变+双层边框)
            nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 8)
            local popBg = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
                nvgRGBA(35, 15, 22, 245), nvgRGBA(18, 10, 16, 245))
            nvgFillPaint(vg, popBg); nvgFill(vg)
            -- 外边框 (暗红)
            nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 8)
            nvgStrokeColor(vg, nvgRGBA(140, 50, 50, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            -- 内边框 (更暗)
            nvgBeginPath(vg); nvgRoundedRect(vg, popX + 3, popY + 3, popW - 6, popH - 6, 6)
            nvgStrokeColor(vg, nvgRGBA(80, 30, 30, 60)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

            -- 背景预览 (横条缩略图)
            local prevW = popW - 20
            local prevH = 80
            local prevX = popX + 10
            local prevY = popY + 44
            if IsImageReady(IMG.abyssBg and IMG.abyssBg[fi]) then
                local imgW, imgH = 714, 1280
                local pScale = math.max(prevW / imgW, prevH / imgH)
                local pat = nvgImagePattern(vg, prevX + (prevW - imgW * pScale)/2,
                    prevY + (prevH - imgH * pScale)/2,
                    imgW * pScale, imgH * pScale, 0, IMG.abyssBg[fi], 0.6)
                nvgBeginPath(vg); nvgRoundedRect(vg, prevX, prevY, prevW, prevH, 4)
                nvgFillPaint(vg, pat); nvgFill(vg)
                -- 暗化
                nvgBeginPath(vg); nvgRoundedRect(vg, prevX, prevY, prevW, prevH, 4)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 40)); nvgFill(vg)
            else
                nvgBeginPath(vg); nvgRoundedRect(vg, prevX, prevY, prevW, prevH, 4)
                nvgFillColor(vg, nvgRGBA(20, 12, 25, 200)); nvgFill(vg)
                DrawSpinner(prevX + prevW / 2, prevY + prevH / 2, 14)
            end

            -- 标题 (血红投影)
            local popTitle = "第" .. fi .. "层 · " .. floor.name
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 32)
            nvgFillColor(vg, nvgRGBA(60, 10, 10, 100))
            nvgText(vg, cx + 1, popY + 24 + 1, popTitle, nil)
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 240))
            nvgText(vg, cx, popY + 24, popTitle, nil)

            -- 描述 + 敌方强度
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(180, 160, 150, 200))
            nvgText(vg, cx, popY + 140, floor.desc, nil)
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(200, 120, 100, 200))
            nvgText(vg, cx, popY + 164, "敌方强度: ×" .. string.format("%.1f", floor.enemyScale), nil)

            -- 出战按钮 (暗红渐变)
            local startBtnW = 160
            local startBtnH = 40
            local startBtnX = cx - startBtnW / 2
            local startBtnY = popY + popH - 52
            local btnPulse = 0.7 + 0.3 * math.sin(t * 2.5)
            nvgBeginPath(vg); nvgRoundedRect(vg, startBtnX, startBtnY, startBtnW, startBtnH, 6)
            local sBtnBg = nvgLinearGradient(vg, startBtnX, startBtnY, startBtnX, startBtnY + startBtnH,
                nvgRGBA(100, 30, 30, 230), nvgRGBA(60, 15, 15, 230))
            nvgFillPaint(vg, sBtnBg); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, startBtnX, startBtnY, startBtnW, startBtnH, 6)
            nvgStrokeColor(vg, nvgRGBA(200, 100, 80, math.floor(160 * btnPulse)))
            nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            nvgFontSize(vg, 28); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(240, 210, 190, 240))
            nvgText(vg, cx, startBtnY + startBtnH / 2, "挑  战", nil)
            abyssState.startBtnRect = { x = startBtnX, y = startBtnY, w = startBtnW, h = startBtnH }

            -- 关闭按钮
            local closeBtnW = 28
            local closeBtnX = popX + popW - closeBtnW - 6
            local closeBtnY3 = popY + 6
            nvgBeginPath(vg); nvgCircle(vg, closeBtnX + closeBtnW/2, closeBtnY3 + closeBtnW/2, closeBtnW/2)
            nvgFillColor(vg, nvgRGBA(50, 20, 20, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(120, 50, 50, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 150, 130, 200))
            nvgText(vg, closeBtnX + closeBtnW/2, closeBtnY3 + closeBtnW/2, "×", nil)
            abyssState.previewCloseRect = { x = closeBtnX, y = closeBtnY3, w = closeBtnW, h = closeBtnW }
        end
    end
end


-- ============================================================================
-- 无尽爬塔 选择界面
-- ============================================================================
function DrawTowerSelectScreen()
    if gameState.phase ~= "TOWER_SELECT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime
    local fl = towerState.currentFloor
    local towerScale = math.pow(1.15, fl)

    -- 爬塔专属背景
    DrawBgImage(IMG.towerSelectBg, W, H, 1143, 2048)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 8, 18, 40)); nvgFill(vg)
    local botGrad = nvgLinearGradient(vg, 0, H * 0.7, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(10, 5, 25, 120))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.7, W, H * 0.3)
    nvgFillPaint(vg, botGrad); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 顶部返回按钮
    local topY = 14
    local backW, backH = 100, 38
    nvgBeginPath(vg); nvgRoundedRect(vg, 14, topY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(15, 12, 30, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 140)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95))
    nvgText(vg, 14 + backW/2 + 1, topY + backH/2 + 1, "< 返回", nil)
    DrawWhiteInkText(14 + backW/2, topY + backH/2, "< 返回")
    towerState.backBtnRect = { x = 14, y = topY, w = backW, h = backH }

    -- 标题
    local titleCY = topY + backH/2
    nvgFontSize(vg, 38); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 130))
    nvgText(vg, cx + 2, titleCY + 2, "无尽爬塔", nil)
    nvgFillColor(vg, nvgRGBA(60, 120, 180, 180))
    nvgText(vg, cx + 1, titleCY + 1, "无尽爬塔", nil)
    DrawWhiteInkText(cx, titleCY, "无尽爬塔")
    DrawHelpBtn(DESIGN_W - 14 - 30, topY + (backH - 30) / 2, 30)

    -- 副标题
    nvgFontSize(vg, 27)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 80))
    local subTitle = "- 层层递进 - 最高999层 -"
    nvgText(vg, cx + 1, titleCY + 22, subTitle, nil)
    DrawWhiteInkText(cx, titleCY + 21, subTitle)

    -- 装饰分隔线
    local sepY2 = titleCY + 36
    local sepHalfW2 = 130
    local lineGradL2 = nvgLinearGradient(vg, cx - sepHalfW2, sepY2, cx - 8, sepY2,
        nvgRGBA(60, 120, 200, 0), nvgRGBA(80, 150, 220, 160))
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - sepHalfW2, sepY2); nvgLineTo(vg, cx - 8, sepY2)
    nvgStrokeWidth(vg, 1.2); nvgStrokePaint(vg, lineGradL2); nvgStroke(vg)
    local lineGradR2 = nvgLinearGradient(vg, cx + 8, sepY2, cx + sepHalfW2, sepY2,
        nvgRGBA(80, 150, 220, 160), nvgRGBA(60, 120, 200, 0))
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + 8, sepY2); nvgLineTo(vg, cx + sepHalfW2, sepY2)
    nvgStrokeWidth(vg, 1.2); nvgStrokePaint(vg, lineGradR2); nvgStroke(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, sepY2 - 4); nvgLineTo(vg, cx + 4, sepY2)
    nvgLineTo(vg, cx, sepY2 + 4); nvgLineTo(vg, cx - 4, sepY2)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(100, 180, 240, 200)); nvgFill(vg)

    -- 主内容区域: 当前层数大字
    local contentY = sepY2 + 30
    local cardW = W - 60
    local cardH = 200
    local cardX = 30

    -- 卡片底板
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, contentY, cardW, cardH, 8)
    nvgFillColor(vg, nvgRGBA(22, 20, 40, 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, contentY, cardW, cardH, 8)
    local cardPulse = 0.7 + 0.3 * math.sin(t * 2)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 240, math.floor(150 * cardPulse)))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    -- 当前层数
    local towerMaxReached = (fl > 999)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 60)
    local floorText = towerMaxReached and "已达巅峰" or ("第 " .. fl .. " 层")
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95))
    nvgText(vg, cx + 2, contentY + 60 + 2, floorText, nil)
    nvgFillColor(vg, towerMaxReached and nvgRGBA(255, 200, 80, 250) or nvgRGBA(100, 200, 255, 250))
    nvgText(vg, cx, contentY + 60, floorText, nil)
    if towerMaxReached then
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(255, 180, 80, 200))
        nvgText(vg, cx, contentY + 90, "本赛季最高999层，敬请期待下赛季", nil)
    end

    -- 难度信息
    nvgFontSize(vg, 27)
    DrawWhiteInkText(cx, contentY + 105, "敌方强度: ×" .. string.format("%.2f", towerScale))

    -- 战力预估
    local myP = CalcPlayerTotalPower()
    local ePow, minReq, recReq = CalcStageRequiredPower(towerScale)
    local pRatio = (ePow > 0) and (myP / ePow) or 99.0
    local gT, gC = GetPowerGrade(pRatio)
    nvgFontSize(vg, 25)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, (myP >= minReq) and nvgRGBA(100, 220, 130, 230) or nvgRGBA(255, 90, 90, 230))
    nvgText(vg, cx - 80, contentY + 130, "最低 " .. FormatPower(minReq), nil)
    local recColor = (myP >= recReq) and nvgRGBA(100, 220, 130, 230) or nvgRGBA(255, 200, 80, 230)
    nvgFillColor(vg, recColor)
    nvgText(vg, cx + 20, contentY + 130, "推荐 " .. FormatPower(recReq), nil)
    nvgFillColor(vg, nvgRGBA(gC[1], gC[2], gC[3], 225))
    nvgText(vg, cx + 110, contentY + 130, "[" .. gT .. "]", nil)

    -- 历史最高
    nvgFontSize(vg, 25)
    DrawWhiteInkText(cx, contentY + 160, "历史最高: 第" .. towerState.highestFloor .. "层")

    -- 奖励预览
    local rewardY = contentY + cardH + 16
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local towerJade = 20 + fl * 7
    local towerFrag = math.min(12, math.floor(fl / 4) + 1)
    DrawWhiteInkText(cx, rewardY, "通关奖励: 虎符+" .. towerJade .. "  武技残片+" .. towerFrag)

    -- 按钮行: 挑战 + 排行榜
    local btnY = rewardY + 30
    local btnH = 44
    local gap = 16

    -- 挑战按钮
    local startBtnW = 140
    local startBtnX = cx - startBtnW - gap / 2
    local btnPulse = 0.7 + 0.3 * math.sin(t * 2.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, startBtnX, btnY, startBtnW, btnH, 6)
    local startGrad
    if towerMaxReached then
        startGrad = nvgLinearGradient(vg, startBtnX, btnY, startBtnX, btnY + btnH,
            nvgRGBA(80, 80, 80, 180), nvgRGBA(60, 60, 60, 200))
    else
        startGrad = nvgLinearGradient(vg, startBtnX, btnY, startBtnX, btnY + btnH,
            nvgRGBA(40, 100, 200, math.floor(220 * btnPulse)),
            nvgRGBA(20, 60, 160, math.floor(240 * btnPulse)))
    end
    nvgFillPaint(vg, startGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, startBtnX, btnY, startBtnW, btnH, 6)
    nvgStrokeColor(vg, towerMaxReached and nvgRGBA(100, 100, 100, 120) or nvgRGBA(120, 200, 255, math.floor(180 * btnPulse)))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 33); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local startBtnLabel = towerMaxReached and "已封顶" or "挑  战"
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 130))
    nvgText(vg, startBtnX + startBtnW / 2 + 1, btnY + btnH / 2 + 1, startBtnLabel, nil)
    if towerMaxReached then
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
        nvgText(vg, startBtnX + startBtnW / 2, btnY + btnH / 2, startBtnLabel, nil)
    else
        DrawWhiteInkText(startBtnX + startBtnW / 2, btnY + btnH / 2, startBtnLabel)
    end
    towerState.startBtnRect = { x = startBtnX, y = btnY, w = startBtnW, h = btnH }

    -- 排行榜按钮
    local rankBtnW = 140
    local rankBtnX = cx + gap / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, rankBtnX, btnY, rankBtnW, btnH, 6)
    local rankGrad = nvgLinearGradient(vg, rankBtnX, btnY, rankBtnX, btnY + btnH,
        nvgRGBA(160, 100, 40, 210), nvgRGBA(120, 60, 20, 230))
    nvgFillPaint(vg, rankGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, rankBtnX, btnY, rankBtnW, btnH, 6)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 100, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 30); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 130))
    nvgText(vg, rankBtnX + rankBtnW / 2 + 1, btnY + btnH / 2 + 1, "排行榜", nil)
    DrawWhiteInkText(rankBtnX + rankBtnW / 2, btnY + btnH / 2, "排行榜")
    towerState.leaderboardBtnRect = { x = rankBtnX, y = btnY, w = rankBtnW, h = btnH }

    -- 排行榜面板 (叠加层)
    if towerState.showLeaderboard then
        DrawTowerLeaderboardPanel(W, H, t)
    end
end


-- 爬塔排行榜面板
function DrawTowerLeaderboardPanel(W, H, t)
    -- 暗幕
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)

    local panelW = W - 60
    local panelH = H * 0.7
    local panelX = 30
    local panelY = (H - panelH) / 2
    local cx = W / 2

    -- 面板背景
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgFillColor(vg, nvgRGBA(15, 12, 30, 240)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 240, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 标题
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 34); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 240))
    nvgText(vg, cx, panelY + 30, "爬塔排行榜", nil)

    -- 关闭按钮
    local closeBtnW, closeBtnH = 80, 34
    local closeBtnX = cx - closeBtnW / 2
    local closeBtnY = panelY + panelH - 50
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(80, 40, 40, 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgStrokeColor(vg, nvgRGBA(200, 100, 100, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, closeBtnY + closeBtnH / 2, "关闭")
    towerState.leaderboardBackRect = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }

    -- 列表区域
    local listY = panelY + 55
    local listH = closeBtnY - listY - 10
    local rowH = 32
    local maxVisible = math.floor(listH / rowH)

    if towerState.rankLoading then
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
        nvgText(vg, cx, listY + listH / 2, "加载中...", nil)
    elseif #towerState.rankList == 0 then
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(150, 150, 150, 200))
        nvgText(vg, cx, listY + listH / 2, "暂无数据", nil)
    else
        -- 表头
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 180, 220, 180))
        nvgText(vg, panelX + 16, listY + rowH / 2, "排名", nil)
        nvgText(vg, panelX + 60, listY + rowH / 2, "玩家", nil)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, panelX + panelW - 16, listY + rowH / 2, "最高层", nil)
        listY = listY + rowH

        -- 分割线
        nvgBeginPath(vg)
        nvgMoveTo(vg, panelX + 12, listY); nvgLineTo(vg, panelX + panelW - 12, listY)
        nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        for i = 1, math.min(#towerState.rankList, maxVisible - 1) do
            local entry = towerState.rankList[i]
            local ry = listY + (i - 1) * rowH + rowH / 2

            -- 交替行背景
            if i % 2 == 0 then
                nvgBeginPath(vg); nvgRect(vg, panelX + 8, listY + (i - 1) * rowH, panelW - 16, rowH)
                nvgFillColor(vg, nvgRGBA(40, 50, 80, 60)); nvgFill(vg)
            end

            -- 排名 (前3名高亮)
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if i == 1 then
                nvgFillColor(vg, nvgRGBA(255, 215, 0, 240))
            elseif i == 2 then
                nvgFillColor(vg, nvgRGBA(200, 210, 220, 230))
            elseif i == 3 then
                nvgFillColor(vg, nvgRGBA(210, 160, 90, 220))
            else
                nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
            end
            nvgText(vg, panelX + 32, ry, tostring(i), nil)

            -- 玩家名
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 220, 230, 230))
            local displayName = entry.name or "???"
            if #displayName > 18 then displayName = string.sub(displayName, 1, 16) .. ".." end
            nvgText(vg, panelX + 60, ry, displayName, nil)

            -- 层数
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(100, 200, 255, 240))
            nvgText(vg, panelX + panelW - 16, ry, "第" .. (entry.floor or 0) .. "层", nil)
        end
    end

    -- 自己的记录 (底部)
    nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 180))
    nvgText(vg, cx, closeBtnY - 16, "我的最高: 第" .. towerState.highestFloor .. "层", nil)
end


-- ============================================================================
-- 排位赛 - 选择界面
-- ============================================================================
function DrawRankedSelectScreen()
    if gameState.phase ~= "RANKED_SELECT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime
    local tier = GetRankedTier(rankedState.score)
    local tc = tier.color

    -- 排位专属背景
    DrawBgImage(IMG.rankedSelectBg, W, H, 1143, 2048)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(15, 10, 5, 60)); nvgFill(vg)
    local botGrad = nvgLinearGradient(vg, 0, H * 0.7, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(20, 10, 0, 140))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.7, W, H * 0.3)
    nvgFillPaint(vg, botGrad); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 匹配中覆盖层
    if rankedState.isMatching then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 130)); nvgFill(vg)
        -- 匹配动画
        local dots = string.rep(".", math.floor(rankedState.matchAnim * 4) % 4)
        nvgFontSize(vg, 36)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, H * 0.35, "正在匹配对手" .. dots)
        -- 旋转圈
        local angle = rankedState.matchAnim * 6
        local ringR = 30
        local ringCY = H * 0.5
        for i = 0, 7 do
            local a = angle + i * math.pi / 4
            local px = cx + math.cos(a) * ringR
            local py = ringCY + math.sin(a) * ringR
            local alpha = math.floor(255 * (1 - i / 8))
            nvgBeginPath(vg); nvgCircle(vg, px, py, 4)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, alpha)); nvgFill(vg)
        end
        -- 对手信息预览
        nvgFontSize(vg, 28)
        DrawWhiteInkText(cx, H * 0.65, "对手: " .. rankedState.opponentName)
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 200))
        nvgText(vg, cx, H * 0.7, "战力: " .. FormatPower(rankedState.opponentPower), nil)
        return
    end

    -- 排行榜弹窗
    if rankedState.showLeaderboard then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180)); nvgFill(vg)
        local popW = W - 40
        local popH = H - 60
        local popX = 20
        local popY = 30
        nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
        nvgFillColor(vg, nvgRGBA(20, 18, 35, 240)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        -- 标题
        nvgFontSize(vg, 34); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, popY + 28, "排位排行榜")
        -- 关闭按钮
        local closeBtnW, closeBtnH = 80, 34
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - closeBtnW/2, popY + popH - 46, closeBtnW, closeBtnH, 6)
        nvgFillColor(vg, nvgRGBA(60, 40, 30, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 80, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 26)
        DrawWhiteInkText(cx, popY + popH - 29, "关闭")
        rankedState.backBtnRect = { x = cx - closeBtnW/2, y = popY + popH - 46, w = closeBtnW, h = closeBtnH }
        -- 列表
        if rankedState.rankLoading and not rankedState.rankLoaded then
            nvgFontSize(vg, 26)
            DrawWhiteInkText(cx, popY + popH/2, "加载中...")
        elseif #rankedState.rankList == 0 then
            nvgFontSize(vg, 26)
            DrawWhiteInkText(cx, popY + popH/2, "暂无排行数据")
        else
            nvgSave(vg)
            nvgScissor(vg, popX + 8, popY + 54, popW - 16, popH - 110)
            local listY = popY + 72 - rankedState.rankScroll.offset
            for i, entry in ipairs(rankedState.rankList) do
                local ey = listY + (i - 1) * 36
                if ey > popY + 54 and ey < popY + popH - 55 then
                    local eTier = GetRankedTier(entry.score)
                    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    -- 排名
                    local rankStr = "#" .. i
                    local rankColor = (i <= 3) and nvgRGBA(255, 200, 60, 240) or nvgRGBA(200, 200, 200, 200)
                    nvgFillColor(vg, rankColor)
                    nvgText(vg, popX + 16, ey, rankStr, nil)
                    -- 名字（根据排名宽度动态偏移）
                    local nameX = popX + 70
                    nvgFillColor(vg, nvgRGBA(220, 220, 220, 230))
                    nvgText(vg, nameX, ey, entry.name, nil)
                    -- 段位名称
                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(eTier.color[1], eTier.color[2], eTier.color[3], 230))
                    nvgFontSize(vg, 20)
                    nvgText(vg, popX + popW - 20, ey, eTier.name .. " " .. tostring(entry.score) .. "分", nil)
                end
            end
            nvgRestore(vg)
        end
        return
    end

    -- 顶部返回按钮
    local topY = 14
    local backW, backH = 100, 38
    nvgBeginPath(vg); nvgRoundedRect(vg, 14, topY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(15, 12, 30, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 140)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95))
    nvgText(vg, 14 + backW/2 + 1, topY + backH/2 + 1, "< 返回", nil)
    DrawWhiteInkText(14 + backW/2, topY + backH/2, "< 返回")
    rankedState.backBtnRect = { x = 14, y = topY, w = backW, h = backH }

    -- 标题
    local titleCY = topY + backH/2
    nvgFontSize(vg, 38); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 130))
    nvgText(vg, cx + 2, titleCY + 2, "排位赛", nil)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200))
    nvgText(vg, cx + 1, titleCY + 1, "排位赛", nil)
    DrawWhiteInkText(cx, titleCY, "排位赛")
    DrawHelpBtn(DESIGN_W - 14 - 30, topY + (backH - 30) / 2, 30)

    -- 副标题
    nvgFontSize(vg, 27)
    DrawWhiteInkText(cx, titleCY + 22, "- 武灵对决 - 段位攀升 -")

    -- 装饰分隔线
    local sepY2 = titleCY + 36
    local sepHalfW2 = 130
    local lineGradL2 = nvgLinearGradient(vg, cx - sepHalfW2, sepY2, cx - 8, sepY2,
        nvgRGBA(tc[1], tc[2], tc[3], 0), nvgRGBA(tc[1], tc[2], tc[3], 160))
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - sepHalfW2, sepY2); nvgLineTo(vg, cx - 8, sepY2)
    nvgStrokeWidth(vg, 1.2); nvgStrokePaint(vg, lineGradL2); nvgStroke(vg)
    local lineGradR2 = nvgLinearGradient(vg, cx + 8, sepY2, cx + sepHalfW2, sepY2,
        nvgRGBA(tc[1], tc[2], tc[3], 160), nvgRGBA(tc[1], tc[2], tc[3], 0))
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + 8, sepY2); nvgLineTo(vg, cx + sepHalfW2, sepY2)
    nvgStrokeWidth(vg, 1.2); nvgStrokePaint(vg, lineGradR2); nvgStroke(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, sepY2 - 4); nvgLineTo(vg, cx + 4, sepY2)
    nvgLineTo(vg, cx, sepY2 + 4); nvgLineTo(vg, cx - 4, sepY2)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200)); nvgFill(vg)

    -- 段位卡片
    local contentY = sepY2 + 25
    local cardW = W - 60
    local cardH = 150
    local cardX = 30
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, contentY, cardW, cardH, 8)
    nvgFillColor(vg, nvgRGBA(22, 20, 40, 200)); nvgFill(vg)
    local cardPulse = 0.7 + 0.3 * math.sin(t * 2)
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, contentY, cardW, cardH, 8)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], math.floor(150 * cardPulse)))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    -- 段位大图标
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 56)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
    nvgText(vg, cardX + 50, contentY + 55, tier.icon, nil)

    -- 段位名称
    nvgFontSize(vg, 38)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
    nvgText(vg, cardX + 85, contentY + 40, tier.name, nil)

    -- 积分
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(220, 220, 220, 220))
    nvgText(vg, cardX + 85, contentY + 68, "积分: " .. rankedState.score, nil)

    -- 下一段位进度
    local nextTierIdx = math.min(#RANKED_TIERS, tier.index + 1)
    local nextTier = RANKED_TIERS[nextTierIdx]
    if tier.index < #RANKED_TIERS then
        local progress = (rankedState.score - tier.minScore) / (nextTier.minScore - tier.minScore)
        progress = math.max(0, math.min(1, progress))
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 180))
        nvgText(vg, cardX + 85, contentY + 92, "距" .. nextTier.name .. ": " .. (nextTier.minScore - rankedState.score) .. "分", nil)
        -- 进度条
        local barX = cardX + 85
        local barY = contentY + 106
        local barW = cardW - 120
        local barH = 8
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 4)
        nvgFillColor(vg, nvgRGBA(40, 40, 50, 200)); nvgFill(vg)
        if progress > 0 then
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW * progress, barH, 4)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220)); nvgFill(vg)
        end
    else
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
        nvgText(vg, cardX + 85, contentY + 92, "已达最高段位!", nil)
    end

    -- 战绩统计
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(100, 220, 130, 220))
    nvgText(vg, cardX + cardW - 15, contentY + 40, rankedState.wins .. "胜", nil)
    nvgFillColor(vg, nvgRGBA(255, 100, 100, 220))
    nvgText(vg, cardX + cardW - 15, contentY + 65, rankedState.losses .. "负", nil)
    local winRate = (rankedState.wins + rankedState.losses > 0)
        and math.floor(rankedState.wins / (rankedState.wins + rankedState.losses) * 100) or 0
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
    nvgText(vg, cardX + cardW - 15, contentY + 90, "胜率" .. winRate .. "%", nil)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 200))
    nvgFontSize(vg, 22)
    nvgText(vg, cardX + cardW - 15, contentY + 115, "最高" .. rankedState.highestScore .. "分", nil)

    -- 我的战力
    local myPower = CalcPlayerTotalPower()
    local powerY = contentY + cardH + 14
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, powerY, "当前战力: " .. FormatPower(myPower))

    -- 按钮区域
    local btnY = powerY + 30
    -- 开始匹配按钮
    local startBtnW = 160
    local startBtnH = 44
    local startBtnX = cx - startBtnW / 2
    local btnPulse = 0.7 + 0.3 * math.sin(t * 2.5)
    nvgBeginPath(vg); nvgRoundedRect(vg, startBtnX, btnY, startBtnW, startBtnH, 6)
    local startGrad = nvgLinearGradient(vg, startBtnX, btnY, startBtnX, btnY + startBtnH,
        nvgRGBA(200, 150, 30, math.floor(220 * btnPulse)),
        nvgRGBA(160, 100, 10, math.floor(240 * btnPulse)))
    nvgFillPaint(vg, startGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, startBtnX, btnY, startBtnW, startBtnH, 6)
    nvgStrokeColor(vg, nvgRGBA(255, 230, 120, math.floor(180 * btnPulse)))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 33); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 120))
    nvgText(vg, cx + 1, btnY + startBtnH / 2 + 1, "开始匹配", nil)
    DrawWhiteInkText(cx, btnY + startBtnH / 2, "开始匹配")
    rankedState.startBtnRect = { x = startBtnX, y = btnY, w = startBtnW, h = startBtnH }

    -- 排行榜按钮
    local rankBtnW = 100
    local rankBtnH = 36
    local rankBtnX = cx - rankBtnW / 2
    local rankBtnY = btnY + startBtnH + 12
    nvgBeginPath(vg); nvgRoundedRect(vg, rankBtnX, rankBtnY, rankBtnW, rankBtnH, 6)
    nvgFillColor(vg, nvgRGBA(30, 28, 50, 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, rankBtnX, rankBtnY, rankBtnW, rankBtnH, 6)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, rankBtnY + rankBtnH / 2, "排行榜")
    rankedState.rankBtnRect = { x = rankBtnX, y = rankBtnY, w = rankBtnW, h = rankBtnH }
end


-- ============================================================================
-- 30s打桩 - 选将界面
-- ============================================================================
function DrawDummySelectScreen()
    if gameState.phase ~= "DUMMY_SELECT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0

    DrawCombatBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 横屏布局: 左侧=已选武灵+开始按钮, 右侧=武灵选择网格
    local leftW = 220  -- 左栏宽度
    local rightX = leftW + 8

    -- 顶部栏: 返回 + 标题
    local topY = 8
    local backW, backH = 80, 32
    local backX, backY = 10, topY
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    dummyState.backBtnRect = { x = backX, y = backY, w = backW, h = backH }

    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 100, 80, 240))
    nvgText(vg, cx, topY + backH / 2, "30s 打桩挑战", nil)

    -- 左侧: 已选武灵预览区 (纵向排列)
    local selStartY = topY + backH + 10
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftW / 2, selStartY, "选择最多4名武灵")
    selStartY = selStartY + 16

    local selSlotW = 46
    local selSlotH = 62
    local selGap = 6
    local selCardW = selSlotW - 6
    local selCardH = selCardW / CARD_RATIO
    local totalSelW = 4 * selSlotW + 3 * selGap
    local selStartX = (leftW - totalSelW) / 2
    for i = 1, 4 do
        local sx2 = selStartX + (i - 1) * (selSlotW + selGap)
        nvgBeginPath(vg); nvgRoundedRect(vg, sx2, selStartY, selSlotW, selSlotH, 4)
        if dummyState.selected[i] then
            local card = HERO_CARDS[dummyState.selected[i]]
            local qc = QUALITY_COLORS[card.quality]
            nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 40)); nvgFill(vg)
            DrawInventoryCard(sx2 + 3, selStartY + 3, selCardW, selCardH, card,
                playerHeroes[dummyState.selected[i]] and playerHeroes[dummyState.selected[i]].constellation or 0, false, true)
        else
            nvgFillColor(vg, nvgRGBA(20, 22, 35, 180)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, sx2, selStartY, selSlotW, selSlotH, 4)
            nvgStrokeColor(vg, nvgRGBA(80, 75, 60, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(sx2 + selSlotW / 2, selStartY + selSlotH / 2, "+")
        end
    end

    -- 开始按钮 (左侧底部)
    local startW = 180
    local startH = 38
    local startX = (leftW - startW) / 2
    local startY = selStartY + selSlotH + 12
    local canStart = #dummyState.selected >= 1
    nvgBeginPath(vg); nvgRoundedRect(vg, startX, startY, startW, startH, 8)
    if canStart then
        local sp = 0.85 + 0.15 * math.sin(t * 4)
        local startGrad = nvgLinearGradient(vg, startX, startY, startX, startY + startH,
            nvgRGBA(220, 60, 40, math.floor(230 * sp)),
            nvgRGBA(160, 30, 20, math.floor(230 * sp)))
        nvgFillPaint(vg, startGrad); nvgFill(vg)
    else
        nvgFillColor(vg, nvgRGBA(40, 38, 35, 200)); nvgFill(vg)
    end
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 210, canStart and 240 or 100))
    nvgText(vg, startX + startW / 2, startY + startH / 2, "开始挑战 (" .. #dummyState.selected .. "/4)", nil)
    dummyState.startBtnRect = canStart and { x = startX, y = startY, w = startW, h = startH } or nil

    -- 右侧: 武灵选择网格（已拥有的武灵，支持拖拽滚动）
    local gridY = topY + backH + 6
    local gridH = H - gridY - 8
    dummyState.gridH = gridH
    nvgSave(vg)
    nvgScissor(vg, rightX, gridY, W - rightX, gridH)

    dummyState.cardRects = {}
    local gridW = W - rightX - 12
    local cols = 6  -- 横屏宽度更大，用6列
    local cardW2 = math.floor((gridW - (cols - 1) * 6) / cols)
    local cardImgW = cardW2 - 6
    local cardImgH = cardImgW / CARD_RATIO
    local cardH2 = math.floor(cardImgH + 22)
    local scrollY = dummyState.scrollY
    local cardIdx = 0
    for ci = 1, #HERO_CARDS do
        if playerHeroes[ci] and playerHeroes[ci].owned then
            local col = cardIdx % cols
            local row = math.floor(cardIdx / cols)
            local cxp = rightX + 4 + col * (cardW2 + 6)
            local cyp = gridY + row * (cardH2 + 6) - scrollY
            cardIdx = cardIdx + 1

            local isSelected = false
            for _, si in ipairs(dummyState.selected) do
                if si == ci then isSelected = true; break end
            end

            if cyp + cardH2 >= gridY and cyp <= gridY + gridH then
                local card = HERO_CARDS[ci]

                DrawInventoryCard(cxp, cyp, cardW2, cardH2, card,
                    playerHeroes[ci].constellation, false)

                if isSelected then
                    nvgBeginPath(vg); nvgRoundedRect(vg, cxp, cyp, cardW2, cardH2, 4)
                    nvgStrokeColor(vg, nvgRGBA(80, 220, 100, 200))
                    nvgStrokeWidth(vg, 2); nvgStroke(vg)

                    nvgFontFaceId(vg, GetMainFont())
                    nvgFontSize(vg, 18)
                    nvgFillColor(vg, nvgRGBA(80, 255, 120, 240))
                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                    nvgText(vg, cxp + cardW2 - 3, cyp + 2, "✓", nil)
                end

                dummyState.cardRects[ci] = { x = cxp, y = cyp, w = cardW2, h = cardH2 }
            end
        end
    end
    local totalRows = math.ceil(cardIdx / cols)
    dummyState.contentH = totalRows * (cardH2 + 6) - 6
    nvgRestore(vg)
end


-- ============================================================================
-- 30s打桩 - 结果界面
-- ============================================================================
function DrawDummyResultScreen()
    if gameState.phase ~= "DUMMY_RESULT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0

    DrawCombatBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 横屏布局: 上半=标题+伤害+DPS, 下半=武灵+按钮 (水平充足，垂直紧凑)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题
    nvgFontSize(vg, 36)
    nvgFillColor(vg, nvgRGBA(255, 100, 80, 240))
    nvgText(vg, cx, 40, "挑战结束!", nil)

    -- 总伤害标签
    nvgFontSize(vg, 24)
    DrawWhiteInkText(cx, 72, "30秒内累计伤害")

    -- 伤害数字（大字）
    nvgFontSize(vg, 52)
    local dmgPulse = 0.9 + 0.1 * math.sin(t * 3)
    nvgFillColor(vg, nvgRGBA(255, 200, 60, math.floor(240 * dmgPulse)))
    nvgText(vg, cx, 115, tostring(math.floor(dummyState.totalDamage)), nil)

    -- DPS
    local dps = dummyState.totalDamage / 30
    nvgFontSize(vg, 26)
    nvgFillColor(vg, nvgRGBA(130, 200, 255, 220))
    nvgText(vg, cx, 150, string.format("DPS: %.0f", dps), nil)

    -- 参战武灵
    nvgFontSize(vg, 22)
    DrawWhiteInkText(cx, 180, "参战武灵")

    local cardW3 = 65
    local resCardImgW = cardW3 - 6
    local resCardImgH = resCardImgW / CARD_RATIO
    local cardH3 = math.floor(resCardImgH + 22)
    local gap3 = 10
    local selCount = #dummyState.selected
    local totalW3 = selCount * cardW3 + (selCount - 1) * gap3
    local sx3 = cx - totalW3 / 2
    for i, ci in ipairs(dummyState.selected) do
        local card = HERO_CARDS[ci]
        local px = sx3 + (i - 1) * (cardW3 + gap3)
        local py = 195
        DrawInventoryCard(px, py, cardW3, cardH3, card,
            playerHeroes[ci] and playerHeroes[ci].constellation or 0, false)
    end

    -- 返回按钮
    local btnW = 180
    local btnH = 40
    local btnX = cx - btnW / 2
    local btnY = H - 60
    nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 8)
    local btnGrad = nvgLinearGradient(vg, btnX, btnY, btnX, btnY + btnH,
        nvgRGBA(200, 160, 60, 220), nvgRGBA(160, 110, 30, 220))
    nvgFillPaint(vg, btnGrad); nvgFill(vg)
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(40, 20, 0, 240))
    nvgText(vg, cx, btnY + btnH / 2, "返回主菜单", nil)
    dummyState.resultBackRect = { x = btnX, y = btnY, w = btnW, h = btnH }
end


-- ============================================================================
-- 开发者战场编辑器
-- ============================================================================
