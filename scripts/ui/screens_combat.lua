-- ui/screens_combat.lua (dummy cleanup done)

local function DrawScreenOverlay(W, H, topAlpha, bottomAlpha)
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, H * 0.18,
        nvgRGBA(8, 8, 18, topAlpha or 180), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H * 0.18)
    nvgFillPaint(vg, topGrad)
    nvgFill(vg)

    local bottomGrad = nvgLinearGradient(vg, 0, H * 0.72, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(10, 8, 18, bottomAlpha or 170))
    nvgBeginPath(vg)
    nvgRect(vg, 0, H * 0.72, W, H * 0.28)
    nvgFillPaint(vg, bottomGrad)
    nvgFill(vg)
end

local function DrawSoftPanel(x, y, w, h, radius, fill, stroke)
    fill = fill or nvgRGBA(20, 18, 32, 220)
    stroke = stroke or nvgRGBA(120, 90, 70, 120)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, radius or 8)
    nvgFillColor(vg, fill)
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, radius or 8)
    nvgStrokeColor(vg, stroke)
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)
end

local function DrawButton(x, y, w, h, label, opts)
    opts = opts or {}
    local radius = opts.radius or 6
    local fillTop = opts.fillTop or nvgRGBA(140, 70, 50, 220)
    local fillBottom = opts.fillBottom or nvgRGBA(90, 40, 24, 230)
    local stroke = opts.stroke or nvgRGBA(240, 200, 150, 150)
    local textColor = opts.textColor or nvgRGBA(245, 232, 215, 240)
    local shadowColor = opts.shadowColor or nvgRGBA(0, 0, 0, 130)
    local fontSize = opts.fontSize or 26

    -- 按压缩放反馈
    local AnimBtn = require("ui.anim")
    local now = gameState.gameTime or 0
    local sc = AnimBtn.GetBtnScaleFor(now, x, y, w, h)
    if sc < 0.999 then
        local cx, cy = x + w * 0.5, y + h * 0.5
        nvgSave(vg)
        nvgTranslate(vg, cx, cy); nvgScale(vg, sc, sc); nvgTranslate(vg, -cx, -cy)
    end

    local grad = nvgLinearGradient(vg, x, y, x, y + h, fillTop, fillBottom)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, radius)
    nvgFillPaint(vg, grad)
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, radius)
    nvgStrokeColor(vg, stroke)
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    nvgFontSize(vg, fontSize)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, shadowColor)
    nvgText(vg, x + w / 2 + 1, y + h / 2 + 1, label, nil)
    nvgFillColor(vg, textColor)
    nvgText(vg, x + w / 2, y + h / 2, label, nil)

    if sc < 0.999 then nvgRestore(vg) end
end

local function DrawTopBar(W, title, accent)
    local topY = 14
    local backW, backH = 100, 42
    local backX = 14

    DrawButton(backX, topY, backW, backH, "< 返回", {
        fillTop = nvgRGBA(55, 28, 28, 220),
        fillBottom = nvgRGBA(25, 12, 12, 230),
        stroke = nvgRGBA(180, 90, 90, 130),
        fontSize = 24,
    })

    local cx = W / 2
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 38)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
    nvgText(vg, cx + 2, topY + backH / 2 + 2, title, nil)
    nvgFillColor(vg, accent or nvgRGBA(255, 220, 190, 240))
    nvgText(vg, cx, topY + backH / 2, title, nil)

    DrawHelpBtn(DESIGN_W - 44, topY + 3, 30)

    return {
        x = backX,
        y = topY,
        w = backW,
        h = backH,
        centerY = topY + backH / 2,
    }
end

function DrawAbyssSelectScreen()
    if gameState.phase ~= "ABYSS_SELECT" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    DrawBgImage(IMG.abyssSelectBg, W, H, 572, 1025)
    DrawScreenOverlay(W, H, 190, 180)
    nvgFontFaceId(vg, GetMainFont())

    local topBar = DrawTopBar(W, "深渊试炼", nvgRGBA(230, 150, 150, 240))
    abyssState.backBtnRect = { x = topBar.x, y = topBar.y, w = topBar.w, h = topBar.h }

    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 200, 180, 200))
    nvgText(vg, cx, topBar.centerY + 30, "首通可得 100 玉石 | 层数越高敌人越强", nil)

    local listStartY = topBar.centerY + 50
    local cardW = W - 32
    local cardH = 110
    local gap = 10
    abyssState.floorRects = {}
    abyssState.startBtnRect = nil
    abyssState.previewCloseRect = nil

    for i = 1, #abyssState.floors do
        local floor = abyssState.floors[i]
        local fc = floor.color or { 180, 120, 120 }
        local y = listStartY + (i - 1) * (cardH + gap)
        local unlocked = stageState.maxUnlocked >= floor.unlockStage

        abyssState.floorRects[i] = { x = 16, y = y, w = cardW, h = cardH }
        DrawSoftPanel(16, y, cardW, cardH, 6,
            unlocked and nvgRGBA(28, 18, 28, 220) or nvgRGBA(22, 20, 24, 220),
            unlocked and nvgRGBA(fc[1], fc[2], fc[3], 150) or nvgRGBA(90, 80, 90, 90))

        nvgBeginPath(vg)
        nvgRoundedRect(vg, 16, y, 5, cardH, 3)
        nvgFillColor(vg, unlocked and nvgRGBA(fc[1], fc[2], fc[3], 220) or nvgRGBA(70, 70, 70, 140))
        nvgFill(vg)

        local iconSize = 56
        local iconX = 30
        local iconY = y + (cardH - iconSize) / 2
        if IsImageReady(IMG.abyssIcon and IMG.abyssIcon[i]) then
            local pat = nvgImagePattern(vg, iconX, iconY, iconSize, iconSize, 0, IMG.abyssIcon[i], unlocked and 1 or 0.28)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 6)
            nvgFillPaint(vg, pat)
            nvgFill(vg)
        else
            nvgBeginPath(vg)
            nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 6)
            nvgFillColor(vg, nvgRGBA(30, 24, 36, 220))
            nvgFill(vg)
            DrawSpinner(iconX + iconSize / 2, iconY + iconSize / 2, 12)
        end

        local textX = iconX + iconSize + 14
        local midY = y + cardH / 2
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

        if unlocked then
            local myPower = CalcPlayerTotalPower()
            local enemyPower, minReq, recReq = CalcStageRequiredPower(floor.enemyScale)
            local ratio = enemyPower > 0 and (myPower / enemyPower) or 99
            local gradeText, gradeColor = GetPowerGrade(ratio)

            nvgFontSize(vg, 28)
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 245))
            nvgText(vg, textX, midY - 24, "第" .. i .. "层 · " .. floor.name, nil)

            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(220, 210, 200, 220))
            nvgText(vg, textX, midY + 2, floor.desc or "", nil)

            nvgFontSize(vg, 20)
            nvgFillColor(vg, myPower >= minReq and nvgRGBA(100, 220, 140, 220) or nvgRGBA(240, 110, 110, 220))
            nvgText(vg, textX, midY + 28, "最低 " .. FormatPower(minReq), nil)
            nvgFillColor(vg, myPower >= recReq and nvgRGBA(120, 220, 150, 220) or nvgRGBA(255, 200, 100, 220))
            nvgText(vg, textX + 90, midY + 28, "推荐 " .. FormatPower(recReq), nil)
            nvgFillColor(vg, nvgRGBA(gradeColor[1], gradeColor[2], gradeColor[3], 220))
            nvgText(vg, textX + 190, midY + 28, gradeText, nil)
        else
            local reqStage = STAGES[floor.unlockStage]
            local reqName = reqStage and reqStage.name or ("关卡" .. floor.unlockStage)

            nvgFontSize(vg, 28)
            nvgFillColor(vg, nvgRGBA(150, 140, 150, 190))
            nvgText(vg, textX, midY - 14, "第" .. i .. "层 · 未解锁", nil)

            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(180, 150, 150, 180))
            nvgText(vg, textX, midY + 16, "通关《" .. reqName .. "》后解锁", nil)

            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(120, 90, 90, 180))
            nvgText(vg, 16 + cardW - 14, midY, "锁", nil)
        end
    end

    if not abyssState.showPreview then
        return
    end

    local idx = abyssState.selectedFloor
    local floor = abyssState.floors[idx]
    if not floor then
        return
    end

    local fc = floor.color or { 180, 120, 120 }
    local popW = W - 40
    local popH = 250
    local popX = 20
    local popY = H / 2 - popH / 2 - 10

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 155))
    nvgFill(vg)

    DrawSoftPanel(popX, popY, popW, popH, 10, nvgRGBA(32, 16, 20, 245), nvgRGBA(fc[1], fc[2], fc[3], 150))

    local previewX = popX + 12
    local previewY = popY + 48
    local previewW = popW - 24
    local previewH = 84
    if IsImageReady(IMG.abyssBg and IMG.abyssBg[idx]) then
        local imgW, imgH = 714, 1280
        local scale = math.max(previewW / imgW, previewH / imgH)
        local px = previewX + (previewW - imgW * scale) / 2
        local py = previewY + (previewH - imgH * scale) / 2
        local pat = nvgImagePattern(vg, px, py, imgW * scale, imgH * scale, 0, IMG.abyssBg[idx], 0.75)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, previewX, previewY, previewW, previewH, 6)
        nvgFillPaint(vg, pat)
        nvgFill(vg)
    else
        nvgBeginPath(vg)
        nvgRoundedRect(vg, previewX, previewY, previewW, previewH, 6)
        nvgFillColor(vg, nvgRGBA(22, 18, 28, 220))
        nvgFill(vg)
        DrawSpinner(previewX + previewW / 2, previewY + previewH / 2, 14)
    end

    nvgFontSize(vg, 32)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 245))
    nvgText(vg, cx, popY + 24, "第" .. idx .. "层 · " .. floor.name, nil)

    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(230, 220, 210, 220))
    nvgText(vg, cx, popY + 152, floor.desc or "", nil)

    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(255, 190, 160, 220))
    nvgText(vg, cx, popY + 178, "敌方强度: x" .. string.format("%.1f", floor.enemyScale or 1), nil)

    local startW = 180
    local startH = 42
    local startX = cx - startW / 2
    local startY = popY + popH - 54
    DrawButton(startX, startY, startW, startH, "开始挑战", {
        fillTop = nvgRGBA(170, 70, 60, 230),
        fillBottom = nvgRGBA(110, 35, 35, 235),
        stroke = nvgRGBA(255, 180, 160, 150),
        fontSize = 28,
    })
    abyssState.startBtnRect = { x = startX, y = startY, w = startW, h = startH }

    local closeSize = 28
    local closeX = popX + popW - closeSize - 8
    local closeY = popY + 8
    nvgBeginPath(vg)
    nvgCircle(vg, closeX + closeSize / 2, closeY + closeSize / 2, closeSize / 2)
    nvgFillColor(vg, nvgRGBA(60, 28, 28, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 140, 140, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(240, 210, 200, 230))
    nvgText(vg, closeX + closeSize / 2, closeY + closeSize / 2, "X", nil)
    abyssState.previewCloseRect = { x = closeX, y = closeY, w = closeSize, h = closeSize }
end

function DrawTowerSelectScreen()
    if gameState.phase ~= "TOWER_SELECT" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime or 0
    local floor = towerState.currentFloor or 1
    local towerScale = math.pow(1.15, floor)

    DrawBgImage(IMG.towerSelectBg, W, H, 1143, 2048)
    DrawScreenOverlay(W, H, 170, 150)
    nvgFontFaceId(vg, GetMainFont())

    local topBar = DrawTopBar(W, "无尽爬塔", nvgRGBA(140, 210, 255, 240))
    towerState.backBtnRect = { x = topBar.x, y = topBar.y, w = topBar.w, h = topBar.h }

    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(210, 225, 240, 200))
    nvgText(vg, cx, topBar.centerY + 28, "- 层层递进 - 最高 999 层 -", nil)

    local contentX = 30
    local contentY = topBar.centerY + 50
    local contentW = W - 60
    local contentH = 210
    DrawSoftPanel(contentX, contentY, contentW, contentH, 10, nvgRGBA(22, 24, 42, 215), nvgRGBA(100, 170, 240, 130))

    local towerMaxReached = floor > 999
    local floorText = towerMaxReached and "已达巅峰" or ("第" .. floor .. "层")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 60)
    nvgFillColor(vg, towerMaxReached and nvgRGBA(255, 210, 110, 245) or nvgRGBA(120, 220, 255, 245))
    nvgText(vg, cx, contentY + 64, floorText, nil)

    if towerMaxReached then
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 200, 120, 210))
        nvgText(vg, cx, contentY + 96, "已达到最高 999 层，后续仅保留挑战记录", nil)
    end

    nvgFontSize(vg, 26)
    DrawWhiteInkText(cx, contentY + 108, "敌方强度: x" .. string.format("%.2f", towerScale))

    local myPower = CalcPlayerTotalPower()
    local enemyPower, minReq, recReq = CalcStageRequiredPower(towerScale)
    local ratio = enemyPower > 0 and (myPower / enemyPower) or 99
    local gradeText, gradeColor = GetPowerGrade(ratio)

    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, myPower >= minReq and nvgRGBA(120, 230, 150, 225) or nvgRGBA(255, 120, 120, 225))
    nvgText(vg, cx - 110, contentY + 138, "最低 " .. FormatPower(minReq), nil)
    nvgFillColor(vg, myPower >= recReq and nvgRGBA(120, 230, 150, 225) or nvgRGBA(255, 205, 120, 225))
    nvgText(vg, cx + 5, contentY + 138, "推荐 " .. FormatPower(recReq), nil)
    nvgFillColor(vg, nvgRGBA(gradeColor[1], gradeColor[2], gradeColor[3], 230))
    nvgText(vg, cx + 135, contentY + 138, "[" .. gradeText .. "]", nil)

    nvgFontSize(vg, 24)
    DrawWhiteInkText(cx, contentY + 172, "历史最高 第" .. (towerState.highestFloor or 0) .. "层")

    local rewardY = contentY + contentH + 18
    local towerJade = 20 + floor * 7
    local towerFrag = math.min(12, math.floor(floor / 4) + 1)
    nvgFontSize(vg, 25)
    DrawWhiteInkText(cx, rewardY, "首通奖励: 玉石" .. towerJade .. "  武灵碎片+" .. towerFrag)

    local btnY = rewardY + 32
    local startW = 150
    local startH = 44
    local gap = 18
    local startX = cx - startW - gap / 2
    local rankX = cx + gap / 2
    local rankW = 150
    local startLabel = towerMaxReached and "已满层" or "开始挑战"

    DrawButton(startX, btnY, startW, startH, startLabel, {
        fillTop = towerMaxReached and nvgRGBA(90, 90, 90, 210) or nvgRGBA(50, 120, 220, 230),
        fillBottom = towerMaxReached and nvgRGBA(65, 65, 65, 220) or nvgRGBA(24, 80, 180, 235),
        stroke = towerMaxReached and nvgRGBA(140, 140, 140, 110) or nvgRGBA(150, 220, 255, 140),
        fontSize = 30,
    })
    towerState.startBtnRect = { x = startX, y = btnY, w = startW, h = startH }

    DrawButton(rankX, btnY, rankW, startH, "排行榜", {
        fillTop = nvgRGBA(180, 120, 50, 225),
        fillBottom = nvgRGBA(125, 70, 22, 235),
        stroke = nvgRGBA(255, 215, 140, 145),
        fontSize = 30,
    })
    towerState.leaderboardBtnRect = { x = rankX, y = btnY, w = rankW, h = startH }

    if towerState.showLeaderboard then
        DrawTowerLeaderboardPanel(W, H, t)
    end
end

function DrawTowerLeaderboardPanel(W, H, t)
    local cx = W / 2
    local panelW = W - 60
    local panelH = H * 0.72
    local panelX = 30
    local panelY = (H - panelH) / 2

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 170))
    nvgFill(vg)

    DrawSoftPanel(panelX, panelY, panelW, panelH, 10, nvgRGBA(16, 18, 34, 242), nvgRGBA(110, 170, 240, 140))

    nvgFontSize(vg, 34)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 225, 130, 240))
    nvgText(vg, cx, panelY + 30, "爬塔排行榜", nil)

    local closeW, closeH = 84, 36
    local closeX = cx - closeW / 2
    local closeY = panelY + panelH - 50
    DrawButton(closeX, closeY, closeW, closeH, "关闭", {
        fillTop = nvgRGBA(90, 45, 45, 220),
        fillBottom = nvgRGBA(60, 25, 25, 225),
        stroke = nvgRGBA(220, 140, 140, 120),
        fontSize = 24,
    })
    towerState.leaderboardBackRect = { x = closeX, y = closeY, w = closeW, h = closeH }

    local listX = panelX + 16
    local listY = panelY + 62
    local listW = panelW - 32
    local listH = closeY - listY - 12
    local rowH = 34
    local maxVisible = math.floor((listH - rowH) / rowH)

    if towerState.rankLoading then
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(210, 210, 210, 220))
        nvgText(vg, cx, listY + listH / 2, "加载中...", nil)
        return
    end

    if #towerState.rankList == 0 then
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 210))
        nvgText(vg, cx, listY + listH / 2, "暂无数据", nil)
        return
    end

    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 205, 240, 200))
    nvgText(vg, listX, listY + rowH / 2, "排名", nil)
    nvgText(vg, listX + 56, listY + rowH / 2, "玩家", nil)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg, listX + listW - 8, listY + rowH / 2, "层数", nil)

    nvgBeginPath(vg)
    nvgMoveTo(vg, listX, listY + rowH)
    nvgLineTo(vg, listX + listW, listY + rowH)
    nvgStrokeColor(vg, nvgRGBA(90, 130, 200, 90))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    for i = 1, math.min(#towerState.rankList, maxVisible) do
        local entry = towerState.rankList[i]
        local rowTop = listY + rowH + (i - 1) * rowH
        local rowCY = rowTop + rowH / 2

        if i % 2 == 0 then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, listX - 4, rowTop, listW + 8, rowH, 4)
            nvgFillColor(vg, nvgRGBA(42, 56, 84, 70))
            nvgFill(vg)
        end

        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if i == 1 then
            nvgFillColor(vg, nvgRGBA(255, 220, 90, 240))
        elseif i == 2 then
            nvgFillColor(vg, nvgRGBA(220, 230, 240, 235))
        elseif i == 3 then
            nvgFillColor(vg, nvgRGBA(220, 165, 95, 230))
        else
            nvgFillColor(vg, nvgRGBA(205, 205, 210, 220))
        end
        nvgText(vg, listX + 18, rowCY, tostring(i), nil)

        local displayName = entry.name or "???"
        if #displayName > 18 then
            displayName = string.sub(displayName, 1, 16) .. ".."
        end
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(230, 230, 235, 230))
        nvgText(vg, listX + 56, rowCY, displayName, nil)

        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 210, 255, 235))
        nvgText(vg, listX + listW - 8, rowCY, "第" .. (entry.floor or 0) .. "层", nil)
    end

    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(190, 225, 255, 190))
    nvgText(vg, cx, closeY - 18, "我的最高 第" .. (towerState.highestFloor or 0) .. "层", nil)
end

function DrawRankedSelectScreen()
    if gameState.phase ~= "RANKED_SELECT" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local tier = GetRankedTier(rankedState.score or 0)
    local tc = tier.color or { 255, 180, 100 }

    DrawBgImage(IMG.rankedSelectBg, W, H, 1143, 2048)
    DrawScreenOverlay(W, H, 150, 160)
    nvgFontFaceId(vg, GetMainFont())

    if rankedState.isMatching then
        rankedState.startBtnRect = nil
        rankedState.rankBtnRect = nil
        rankedState.backBtnRect = nil

        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 150))
        nvgFill(vg)

        local dots = string.rep(".", math.floor((rankedState.matchAnim or 0) * 4) % 4)
        nvgFontSize(vg, 36)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, H * 0.35, "正在匹配中" .. dots)

        local angle = (rankedState.matchAnim or 0) * 6
        local ringR = 30
        local ringCY = H * 0.5
        for i = 0, 7 do
            local a = angle + i * math.pi / 4
            local px = cx + math.cos(a) * ringR
            local py = ringCY + math.sin(a) * ringR
            local alpha = math.floor(255 * (1 - i / 8))
            nvgBeginPath(vg)
            nvgCircle(vg, px, py, 4)
            nvgFillColor(vg, nvgRGBA(255, 210, 100, alpha))
            nvgFill(vg)
        end

        nvgFontSize(vg, 28)
        if rankedState.matchReady and rankedState.opponentName and rankedState.opponentName ~= "" then
            DrawWhiteInkText(cx, H * 0.65, "对手: " .. rankedState.opponentName)
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(255, 210, 120, 210))
            nvgText(vg, cx, H * 0.7, "战力: " .. FormatPower(rankedState.opponentPower or 0), nil)
        else
            DrawWhiteInkText(cx, H * 0.65, "正在等待另一名玩家")
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(255, 210, 120, 210))
            nvgText(vg, cx, H * 0.7, "服务器确认后自动开战", nil)
        end
        return
    end

    if rankedState.showLeaderboard then
        local popW = W - 40
        local popH = H - 60
        local popX = 20
        local popY = 30

        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 185))
        nvgFill(vg)
        DrawSoftPanel(popX, popY, popW, popH, 10, nvgRGBA(20, 18, 35, 244), nvgRGBA(255, 200, 100, 160))

        nvgFontSize(vg, 34)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, popY + 28, "排位排行榜")

        local closeW, closeH = 84, 36
        local closeX = cx - closeW / 2
        local closeY = popY + popH - 46
        DrawButton(closeX, closeY, closeW, closeH, "关闭", {
            fillTop = nvgRGBA(85, 50, 35, 220),
            fillBottom = nvgRGBA(58, 30, 18, 230),
            stroke = nvgRGBA(220, 180, 110, 130),
            fontSize = 24,
        })
        rankedState.backBtnRect = { x = closeX, y = closeY, w = closeW, h = closeH }

        if rankedState.rankLoading and not rankedState.rankLoaded then
            nvgFontSize(vg, 26)
            DrawWhiteInkText(cx, popY + popH / 2, "加载中...")
        elseif #rankedState.rankList == 0 then
            nvgFontSize(vg, 26)
            DrawWhiteInkText(cx, popY + popH / 2, "暂无排行榜数据")
        else
            local offset = 0
            if rankedState.rankScroll and rankedState.rankScroll.offset then
                offset = rankedState.rankScroll.offset
            end

            nvgSave(vg)
            nvgScissor(vg, popX + 8, popY + 54, popW - 16, popH - 110)

            local listY = popY + 72 - offset
            for i, entry in ipairs(rankedState.rankList) do
                local rowY = listY + (i - 1) * 36
                if rowY > popY + 54 and rowY < popY + popH - 55 then
                    local entryTier = GetRankedTier(entry.score or 0)
                    local name = entry.name or "???"
                    local rankColor = (i <= 3) and nvgRGBA(255, 210, 80, 240) or nvgRGBA(210, 210, 210, 220)

                    nvgFontSize(vg, 24)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, rankColor)
                    nvgText(vg, popX + 16, rowY, "#" .. i, nil)

                    nvgFillColor(vg, nvgRGBA(230, 230, 235, 230))
                    nvgText(vg, popX + 72, rowY, name, nil)

                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(entryTier.color[1], entryTier.color[2], entryTier.color[3], 235))
                    nvgText(vg, popX + popW - 20, rowY, entryTier.name .. " " .. tostring(entry.score or 0) .. "分", nil)
                end
            end

            nvgRestore(vg)
        end
        return
    end

    local topBar = DrawTopBar(W, "排位赛", nvgRGBA(tc[1], tc[2], tc[3], 240))
    rankedState.backBtnRect = { x = topBar.x, y = topBar.y, w = topBar.w, h = topBar.h }

    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, topBar.centerY + 28, "- 实时匹配 - 赛季积分 -")

    local cardX = 30
    local cardY = topBar.centerY + 48
    local cardW = W - 60
    local cardH = 156
    DrawSoftPanel(cardX, cardY, cardW, cardH, 10, nvgRGBA(24, 22, 38, 215), nvgRGBA(tc[1], tc[2], tc[3], 150))

    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 56)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 245))
    nvgText(vg, cardX + 52, cardY + 54, tier.icon or "*", nil)

    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 38)
    nvgText(vg, cardX + 92, cardY + 42, tier.name or "段位", nil)

    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(225, 225, 225, 225))
    nvgText(vg, cardX + 92, cardY + 72, "积分: " .. (rankedState.score or 0), nil)

    local nextTierIdx = math.min(#RANKED_TIERS, tier.index + 1)
    local nextTier = RANKED_TIERS[nextTierIdx]
    if tier.index < #RANKED_TIERS then
        local denom = nextTier.minScore - tier.minScore
        local progress = denom > 0 and ((rankedState.score - tier.minScore) / denom) or 1
        progress = math.max(0, math.min(1, progress))

        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 190))
        nvgText(vg, cardX + 92, cardY + 98, "距离 " .. nextTier.name .. ": " .. (nextTier.minScore - rankedState.score) .. "分", nil)

        local barX = cardX + 92
        local barY = cardY + 112
        local barW = cardW - 132
        local barH = 8
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW, barH, 4)
        nvgFillColor(vg, nvgRGBA(48, 48, 58, 200))
        nvgFill(vg)
        if progress > 0 then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW * progress, barH, 4)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220))
            nvgFill(vg)
        end
    else
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 210, 120, 210))
        nvgText(vg, cardX + 92, cardY + 98, "已达最高段位", nil)
    end

    local totalGames = (rankedState.wins or 0) + (rankedState.losses or 0)
    local winRate = totalGames > 0 and math.floor((rankedState.wins or 0) / totalGames * 100) or 0
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(120, 225, 145, 225))
    nvgText(vg, cardX + cardW - 16, cardY + 40, (rankedState.wins or 0) .. "胜", nil)
    nvgFillColor(vg, nvgRGBA(255, 120, 120, 225))
    nvgText(vg, cardX + cardW - 16, cardY + 66, (rankedState.losses or 0) .. "负", nil)
    nvgFillColor(vg, nvgRGBA(220, 220, 220, 220))
    nvgText(vg, cardX + cardW - 16, cardY + 92, "胜率 " .. winRate .. "%", nil)
    nvgFillColor(vg, nvgRGBA(255, 225, 120, 220))
    nvgText(vg, cardX + cardW - 16, cardY + 118, "最高 " .. (rankedState.highestScore or 0) .. "分", nil)

    local powerY = cardY + cardH + 18
    local myPower = CalcPlayerTotalPower()
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, powerY, "当前战力: " .. FormatPower(myPower))

    local startW = 160
    local startH = 44
    local startX = cx - startW / 2
    local startY = powerY + 32
    DrawButton(startX, startY, startW, startH, "开始匹配", {
        fillTop = nvgRGBA(220, 165, 40, 230),
        fillBottom = nvgRGBA(168, 108, 18, 235),
        stroke = nvgRGBA(255, 232, 150, 145),
        fontSize = 30,
    })
    rankedState.startBtnRect = { x = startX, y = startY, w = startW, h = startH }

    local rankW = 110
    local rankH = 38
    local rankX = cx - rankW / 2
    local rankY = startY + startH + 12
    DrawButton(rankX, rankY, rankW, rankH, "排行榜", {
        fillTop = nvgRGBA(48, 46, 66, 220),
        fillBottom = nvgRGBA(28, 26, 40, 230),
        stroke = nvgRGBA(195, 165, 110, 120),
        fontSize = 24,
    })
    rankedState.rankBtnRect = { x = rankX, y = rankY, w = rankW, h = rankH }
end

