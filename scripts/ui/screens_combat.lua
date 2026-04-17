-- ui/screens_combat.lua - 涓夊浗姝︾伒褰?(浠?screens.lua 鎷嗗垎)
function DrawAbyssSelectScreen()
    if gameState.phase ~= "ABYSS_SELECT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime

    -- 璁ㄤ紣涓撳睘鑳屾櫙 (鏂板摜鐗归)
    DrawBgImage(IMG.abyssSelectBg, W, H, 572, 1025)
    -- 椤堕儴鏆楀寲娓愬彉
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, H * 0.15,
        nvgRGBA(8, 4, 16, 180), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H * 0.15)
    nvgFillPaint(vg, topGrad); nvgFill(vg)
    -- 搴曢儴璁ㄤ紣杩烽浘
    local botGrad = nvgLinearGradient(vg, 0, H * 0.75, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(12, 4, 20, 160))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.75, W, H * 0.25)
    nvgFillPaint(vg, botGrad); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 椤堕儴杩斿洖鎸夐挳 (鏆楃孩鍝ョ壒杈规)
    local topY = 14
    local backW, backH = 90, 34
    nvgBeginPath(vg); nvgRoundedRect(vg, 14, topY, backW, backH, 4)
    local backBg = nvgLinearGradient(vg, 14, topY, 14, topY + backH,
        nvgRGBA(40, 12, 18, 220), nvgRGBA(20, 8, 12, 220))
    nvgFillPaint(vg, backBg); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 50, 50, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(14 + backW/2, topY + backH/2, "< 杩斿洖")
    abyssState.backBtnRect = { x = 14, y = topY, w = backW, h = backH }

    -- 鏍囬鍖哄煙 (鐧借壊+榛戞弿杈?
    local titleCY = topY + backH / 2
    nvgFontSize(vg, 40); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, titleCY, "璁ㄤ紣鎴?)
    DrawHelpBtn(DESIGN_W - 14 - 30, topY + (backH - 30) / 2, 30)

    -- 瑁呴グ: 宸﹀彸琛€绾㈡笎鍙樺垎闅旂嚎
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
    -- 涓績楠烽珔鑿卞舰
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, sepY2 - 4); nvgLineTo(vg, cx + 4, sepY2)
    nvgLineTo(vg, cx, sepY2 + 4); nvgLineTo(vg, cx - 4, sepY2)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(180, 80, 80, 200)); nvgFill(vg)

    -- 璁ㄤ紣鍏ュ満璐?& 鐖嗙巼鎻愮ず
    nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 140, 100, 180))
    nvgText(vg, cx, sepY2 + 16, "姣忔娑堣€?00铏庣 | 澶ч噺瑁呭鎺夎惤", nil)

    -- 鍏冲崱鍒楄〃
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

        -- 鍗＄墖鑳屾櫙 (娣辫壊鍝ョ壒娓愬彉搴曟澘)
        nvgBeginPath(vg); nvgRoundedRect(vg, 16, cy, cardW, cardH, 5)
        if isUnlocked then
            local cardBg = nvgLinearGradient(vg, 16, cy, 16 + cardW, cy,
                nvgRGBA(18, 10, 28, 200), nvgRGBA(28, 16, 22, 200))
            nvgFillPaint(vg, cardBg)
        else
            nvgFillColor(vg, nvgRGBA(20, 18, 24, 210))
        end
        nvgFill(vg)

        -- 宸︿晶绔栨潯瑁呴グ (棰滆壊鏍囪瘑)
        nvgBeginPath(vg); nvgRoundedRect(vg, 16, cy, 4, cardH, 2)
        if isUnlocked then
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 200))
        else
            nvgFillColor(vg, nvgRGBA(50, 45, 55, 120))
        end
        nvgFill(vg)

        -- 杈规 (鏆楃孩鎻忚竟)
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

        -- 宸︿晶鍥炬爣 (鏂瑰舰鍦嗚)
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
        -- 鍥炬爣杈规
        nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 6)
        if isUnlocked then
            nvgStrokeColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 120))
        else
            nvgStrokeColor(vg, nvgRGBA(45, 40, 50, 70))
        end
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 鍙充晶鏂囧瓧鍖哄煙
        local textX = iconX + iconSize + 12
        local textCY2 = cy + cardH / 2
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

        if isUnlocked then
            -- 灞傛暟 + 鍚嶇О
            local floorTitle = "绗? .. i .. "灞?路 " .. floor.name
            nvgFontSize(vg, 27)
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 240))
            nvgText(vg, textX, textCY2 - 22, floorTitle, nil)

            -- 鎻忚堪
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(160, 150, 140, 180))
            nvgText(vg, textX, textCY2 + 2, floor.desc, nil)

            -- 鎴樺姏璇勪及
            local myP = CalcPlayerTotalPower()
            local ePow, minReq, recReq = CalcStageRequiredPower(floor.enemyScale)
            local pRatio = (ePow > 0) and (myP / ePow) or 99.0
            local gT, gC = GetPowerGrade(pRatio)
            nvgFontSize(vg, 20)
            nvgFillColor(vg, (myP >= minReq) and nvgRGBA(80, 200, 110, 210) or nvgRGBA(220, 70, 70, 210))
            nvgText(vg, textX, textCY2 + 24, "闇€ " .. FormatPower(minReq), nil)
            local recColor = (myP >= recReq) and nvgRGBA(80, 200, 110, 210) or nvgRGBA(220, 170, 60, 210)
            nvgFillColor(vg, recColor)
            nvgText(vg, textX + 80, textCY2 + 24, "鑽?" .. FormatPower(recReq), nil)
            nvgFillColor(vg, nvgRGBA(gC[1], gC[2], gC[3], 200))
            nvgText(vg, textX + 160, textCY2 + 24, gT, nil)

            -- 鍙充晶绠ご
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 28)
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 100))
            nvgText(vg, 16 + cardW - 10, textCY2, ">", nil)
        else
            -- 閿佸畾
            nvgFontSize(vg, 27)
            nvgFillColor(vg, nvgRGBA(80, 75, 85, 180))
            nvgText(vg, textX, textCY2 - 12, "绗? .. i .. "灞?路 ???", nil)
            nvgFontSize(vg, 22)
            local reqStage = STAGES[floor.unlockStage]
            local reqName = reqStage and reqStage.name or ("鍏冲崱" .. floor.unlockStage)
            nvgFillColor(vg, nvgRGBA(100, 80, 80, 150))
            nvgText(vg, textX, textCY2 + 12, "閫氬叧銆? .. reqName .. "銆嶈В閿?, nil)
            -- 閿佸浘鏍?
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 26)
            nvgFillColor(vg, nvgRGBA(80, 60, 60, 120))
            nvgText(vg, 16 + cardW - 10, textCY2, "閿?, nil)
        end
    end

    -- ===========================
    -- 璁ㄤ紣鍏冲崱棰勮寮圭獥 (閲嶅埗)
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

            -- 鍏ㄥ睆閬僵
            nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 140)); nvgFill(vg)

            -- 寮圭獥搴曟澘 (鏆楃孩娓愬彉+鍙屽眰杈规)
            nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 8)
            local popBg = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
                nvgRGBA(35, 15, 22, 245), nvgRGBA(18, 10, 16, 245))
            nvgFillPaint(vg, popBg); nvgFill(vg)
            -- 澶栬竟妗?(鏆楃孩)
            nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 8)
            nvgStrokeColor(vg, nvgRGBA(140, 50, 50, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            -- 鍐呰竟妗?(鏇存殫)
            nvgBeginPath(vg); nvgRoundedRect(vg, popX + 3, popY + 3, popW - 6, popH - 6, 6)
            nvgStrokeColor(vg, nvgRGBA(80, 30, 30, 60)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

            -- 鑳屾櫙棰勮 (妯潯缂╃暐鍥?
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
                -- 鏆楀寲
                nvgBeginPath(vg); nvgRoundedRect(vg, prevX, prevY, prevW, prevH, 4)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 40)); nvgFill(vg)
            else
                nvgBeginPath(vg); nvgRoundedRect(vg, prevX, prevY, prevW, prevH, 4)
                nvgFillColor(vg, nvgRGBA(20, 12, 25, 200)); nvgFill(vg)
                DrawSpinner(prevX + prevW / 2, prevY + prevH / 2, 14)
            end

            -- 鏍囬 (琛€绾㈡姇褰?
            local popTitle = "绗? .. fi .. "灞?路 " .. floor.name
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 32)
            nvgFillColor(vg, nvgRGBA(60, 10, 10, 100))
            nvgText(vg, cx + 1, popY + 24 + 1, popTitle, nil)
            nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 240))
            nvgText(vg, cx, popY + 24, popTitle, nil)

            -- 鎻忚堪 + 鏁屾柟寮哄害
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(180, 160, 150, 200))
            nvgText(vg, cx, popY + 140, floor.desc, nil)
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(200, 120, 100, 200))
            nvgText(vg, cx, popY + 164, "鏁屾柟寮哄害: 脳" .. string.format("%.1f", floor.enemyScale), nil)

            -- 鍑烘垬鎸夐挳 (鏆楃孩娓愬彉)
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
            nvgText(vg, cx, startBtnY + startBtnH / 2, "鎸? 鎴?, nil)
            abyssState.startBtnRect = { x = startBtnX, y = startBtnY, w = startBtnW, h = startBtnH }

            -- 鍏抽棴鎸夐挳
            local closeBtnW = 28
            local closeBtnX = popX + popW - closeBtnW - 6
            local closeBtnY3 = popY + 6
            nvgBeginPath(vg); nvgCircle(vg, closeBtnX + closeBtnW/2, closeBtnY3 + closeBtnW/2, closeBtnW/2)
            nvgFillColor(vg, nvgRGBA(50, 20, 20, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(120, 50, 50, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 150, 130, 200))
            nvgText(vg, closeBtnX + closeBtnW/2, closeBtnY3 + closeBtnW/2, "脳", nil)
            abyssState.previewCloseRect = { x = closeBtnX, y = closeBtnY3, w = closeBtnW, h = closeBtnW }
        end
    end
end


-- ============================================================================
-- 鏃犲敖鐖 閫夋嫨鐣岄潰
-- ============================================================================
function DrawTowerSelectScreen()
    if gameState.phase ~= "TOWER_SELECT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime
    local fl = towerState.currentFloor
    local towerScale = math.pow(1.15, fl)

    -- 鐖涓撳睘鑳屾櫙
    DrawBgImage(IMG.towerSelectBg, W, H, 1143, 2048)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 8, 18, 40)); nvgFill(vg)
    local botGrad = nvgLinearGradient(vg, 0, H * 0.7, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(10, 5, 25, 120))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.7, W, H * 0.3)
    nvgFillPaint(vg, botGrad); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 椤堕儴杩斿洖鎸夐挳
    local topY = 14
    local backW, backH = 100, 38
    nvgBeginPath(vg); nvgRoundedRect(vg, 14, topY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(15, 12, 30, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 140)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95))
    nvgText(vg, 14 + backW/2 + 1, topY + backH/2 + 1, "< 杩斿洖", nil)
    DrawWhiteInkText(14 + backW/2, topY + backH/2, "< 杩斿洖")
    towerState.backBtnRect = { x = 14, y = topY, w = backW, h = backH }

    -- 鏍囬
    local titleCY = topY + backH/2
    nvgFontSize(vg, 38); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 130))
    nvgText(vg, cx + 2, titleCY + 2, "鏃犲敖鐖", nil)
    nvgFillColor(vg, nvgRGBA(60, 120, 180, 180))
    nvgText(vg, cx + 1, titleCY + 1, "鏃犲敖鐖", nil)
    DrawWhiteInkText(cx, titleCY, "鏃犲敖鐖")
    DrawHelpBtn(DESIGN_W - 14 - 30, topY + (backH - 30) / 2, 30)

    -- 鍓爣棰?
    nvgFontSize(vg, 27)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 80))
    local subTitle = "- 灞傚眰閫掕繘 - 鏈€楂?99灞?-"
    nvgText(vg, cx + 1, titleCY + 22, subTitle, nil)
    DrawWhiteInkText(cx, titleCY + 21, subTitle)

    -- 瑁呴グ鍒嗛殧绾?
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

    -- 涓诲唴瀹瑰尯鍩? 褰撳墠灞傛暟澶у瓧
    local contentY = sepY2 + 30
    local cardW = W - 60
    local cardH = 200
    local cardX = 30

    -- 鍗＄墖搴曟澘
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, contentY, cardW, cardH, 8)
    nvgFillColor(vg, nvgRGBA(22, 20, 40, 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, contentY, cardW, cardH, 8)
    local cardPulse = 0.7 + 0.3 * math.sin(t * 2)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 240, math.floor(150 * cardPulse)))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    -- 褰撳墠灞傛暟
    local towerMaxReached = (fl > 999)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 60)
    local floorText = towerMaxReached and "宸茶揪宸呭嘲" or ("绗?" .. fl .. " 灞?)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95))
    nvgText(vg, cx + 2, contentY + 60 + 2, floorText, nil)
    nvgFillColor(vg, towerMaxReached and nvgRGBA(255, 200, 80, 250) or nvgRGBA(100, 200, 255, 250))
    nvgText(vg, cx, contentY + 60, floorText, nil)
    if towerMaxReached then
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(255, 180, 80, 200))
        nvgText(vg, cx, contentY + 90, "鏈禌瀛ｆ渶楂?99灞傦紝鏁鏈熷緟涓嬭禌瀛?, nil)
    end

    -- 闅惧害淇℃伅
    nvgFontSize(vg, 27)
    DrawWhiteInkText(cx, contentY + 105, "鏁屾柟寮哄害: 脳" .. string.format("%.2f", towerScale))

    -- 鎴樺姏棰勪及
    local myP = CalcPlayerTotalPower()
    local ePow, minReq, recReq = CalcStageRequiredPower(towerScale)
    local pRatio = (ePow > 0) and (myP / ePow) or 99.0
    local gT, gC = GetPowerGrade(pRatio)
    nvgFontSize(vg, 25)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, (myP >= minReq) and nvgRGBA(100, 220, 130, 230) or nvgRGBA(255, 90, 90, 230))
    nvgText(vg, cx - 80, contentY + 130, "鏈€浣?" .. FormatPower(minReq), nil)
    local recColor = (myP >= recReq) and nvgRGBA(100, 220, 130, 230) or nvgRGBA(255, 200, 80, 230)
    nvgFillColor(vg, recColor)
    nvgText(vg, cx + 20, contentY + 130, "鎺ㄨ崘 " .. FormatPower(recReq), nil)
    nvgFillColor(vg, nvgRGBA(gC[1], gC[2], gC[3], 225))
    nvgText(vg, cx + 110, contentY + 130, "[" .. gT .. "]", nil)

    -- 鍘嗗彶鏈€楂?
    nvgFontSize(vg, 25)
    DrawWhiteInkText(cx, contentY + 160, "鍘嗗彶鏈€楂? 绗? .. towerState.highestFloor .. "灞?)

    -- 濂栧姳棰勮
    local rewardY = contentY + cardH + 16
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local towerJade = 20 + fl * 7
    local towerFrag = math.min(12, math.floor(fl / 4) + 1)
    DrawWhiteInkText(cx, rewardY, "閫氬叧濂栧姳: 铏庣+" .. towerJade .. "  姝︽妧娈嬬墖+" .. towerFrag)

    -- 鎸夐挳琛? 鎸戞垬 + 鎺掕姒?
    local btnY = rewardY + 30
    local btnH = 44
    local gap = 16

    -- 鎸戞垬鎸夐挳
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
    local startBtnLabel = towerMaxReached and "宸插皝椤? or "鎸? 鎴?
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 130))
    nvgText(vg, startBtnX + startBtnW / 2 + 1, btnY + btnH / 2 + 1, startBtnLabel, nil)
    if towerMaxReached then
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
        nvgText(vg, startBtnX + startBtnW / 2, btnY + btnH / 2, startBtnLabel, nil)
    else
        DrawWhiteInkText(startBtnX + startBtnW / 2, btnY + btnH / 2, startBtnLabel)
    end
    towerState.startBtnRect = { x = startBtnX, y = btnY, w = startBtnW, h = btnH }

    -- 鎺掕姒滄寜閽?
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
    nvgText(vg, rankBtnX + rankBtnW / 2 + 1, btnY + btnH / 2 + 1, "鎺掕姒?, nil)
    DrawWhiteInkText(rankBtnX + rankBtnW / 2, btnY + btnH / 2, "鎺掕姒?)
    towerState.leaderboardBtnRect = { x = rankBtnX, y = btnY, w = rankBtnW, h = btnH }

    -- 鎺掕姒滈潰鏉?(鍙犲姞灞?
    if towerState.showLeaderboard then
        DrawTowerLeaderboardPanel(W, H, t)
    end
end


-- 鐖鎺掕姒滈潰鏉?
function DrawTowerLeaderboardPanel(W, H, t)
    -- 鏆楀箷
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)

    local panelW = W - 60
    local panelH = H * 0.7
    local panelX = 30
    local panelY = (H - panelH) / 2
    local cx = W / 2

    -- 闈㈡澘鑳屾櫙
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgFillColor(vg, nvgRGBA(15, 12, 30, 240)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 240, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 鏍囬
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 34); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 240))
    nvgText(vg, cx, panelY + 30, "鐖鎺掕姒?, nil)

    -- 鍏抽棴鎸夐挳
    local closeBtnW, closeBtnH = 80, 34
    local closeBtnX = cx - closeBtnW / 2
    local closeBtnY = panelY + panelH - 50
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(80, 40, 40, 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgStrokeColor(vg, nvgRGBA(200, 100, 100, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, closeBtnY + closeBtnH / 2, "鍏抽棴")
    towerState.leaderboardBackRect = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }

    -- 鍒楄〃鍖哄煙
    local listY = panelY + 55
    local listH = closeBtnY - listY - 10
    local rowH = 32
    local maxVisible = math.floor(listH / rowH)

    if towerState.rankLoading then
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
        nvgText(vg, cx, listY + listH / 2, "鍔犺浇涓?..", nil)
    elseif #towerState.rankList == 0 then
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(150, 150, 150, 200))
        nvgText(vg, cx, listY + listH / 2, "鏆傛棤鏁版嵁", nil)
    else
        -- 琛ㄥご
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 180, 220, 180))
        nvgText(vg, panelX + 16, listY + rowH / 2, "鎺掑悕", nil)
        nvgText(vg, panelX + 60, listY + rowH / 2, "鐜╁", nil)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, panelX + panelW - 16, listY + rowH / 2, "鏈€楂樺眰", nil)
        listY = listY + rowH

        -- 鍒嗗壊绾?
        nvgBeginPath(vg)
        nvgMoveTo(vg, panelX + 12, listY); nvgLineTo(vg, panelX + panelW - 12, listY)
        nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        for i = 1, math.min(#towerState.rankList, maxVisible - 1) do
            local entry = towerState.rankList[i]
            local ry = listY + (i - 1) * rowH + rowH / 2

            -- 浜ゆ浛琛岃儗鏅?
            if i % 2 == 0 then
                nvgBeginPath(vg); nvgRect(vg, panelX + 8, listY + (i - 1) * rowH, panelW - 16, rowH)
                nvgFillColor(vg, nvgRGBA(40, 50, 80, 60)); nvgFill(vg)
            end

            -- 鎺掑悕 (鍓?鍚嶉珮浜?
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

            -- 鐜╁鍚?
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 220, 230, 230))
            local displayName = entry.name or "???"
            if #displayName > 18 then displayName = string.sub(displayName, 1, 16) .. ".." end
            nvgText(vg, panelX + 60, ry, displayName, nil)

            -- 灞傛暟
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(100, 200, 255, 240))
            nvgText(vg, panelX + panelW - 16, ry, "绗? .. (entry.floor or 0) .. "灞?, nil)
        end
    end

    -- 鑷繁鐨勮褰?(搴曢儴)
    nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 180))
    nvgText(vg, cx, closeBtnY - 16, "鎴戠殑鏈€楂? 绗? .. towerState.highestFloor .. "灞?, nil)
end


-- ============================================================================
-- 鎺掍綅璧?- 閫夋嫨鐣岄潰
-- ============================================================================
function DrawRankedSelectScreen()
    if gameState.phase ~= "RANKED_SELECT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime
    local tier = GetRankedTier(rankedState.score)
    local tc = tier.color

    -- 鎺掍綅涓撳睘鑳屾櫙
    DrawBgImage(IMG.rankedSelectBg, W, H, 1143, 2048)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(15, 10, 5, 60)); nvgFill(vg)
    local botGrad = nvgLinearGradient(vg, 0, H * 0.7, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(20, 10, 0, 140))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.7, W, H * 0.3)
    nvgFillPaint(vg, botGrad); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 鍖归厤涓鐩栧眰
    if rankedState.isMatching then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 130)); nvgFill(vg)
        -- 鍖归厤鍔ㄧ敾
        local dots = string.rep(".", math.floor(rankedState.matchAnim * 4) % 4)
        nvgFontSize(vg, 36)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, H * 0.35, "姝ｅ湪鍖归厤瀵规墜" .. dots)
        -- 鏃嬭浆鍦?
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
        if rankedState.matchReady and rankedState.opponentName and rankedState.opponentName ~= "" then
            DrawWhiteInkText(cx, H * 0.65, "对手: " .. rankedState.opponentName)
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, 200))
            nvgText(vg, cx, H * 0.7, "战力: " .. FormatPower(rankedState.opponentPower), nil)
        else
            DrawWhiteInkText(cx, H * 0.65, "正在等待另一名玩家")
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, 200))
            nvgText(vg, cx, H * 0.7, "服务端确认后自动开战", nil)
        end
        return
    end

    -- 鎺掕姒滃脊绐?
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
        -- 鏍囬
        nvgFontSize(vg, 34); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, popY + 28, "鎺掍綅鎺掕姒?)
        -- 鍏抽棴鎸夐挳
        local closeBtnW, closeBtnH = 80, 34
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - closeBtnW/2, popY + popH - 46, closeBtnW, closeBtnH, 6)
        nvgFillColor(vg, nvgRGBA(60, 40, 30, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 80, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 26)
        DrawWhiteInkText(cx, popY + popH - 29, "鍏抽棴")
        rankedState.backBtnRect = { x = cx - closeBtnW/2, y = popY + popH - 46, w = closeBtnW, h = closeBtnH }
        -- 鍒楄〃
        if rankedState.rankLoading and not rankedState.rankLoaded then
            nvgFontSize(vg, 26)
            DrawWhiteInkText(cx, popY + popH/2, "鍔犺浇涓?..")
        elseif #rankedState.rankList == 0 then
            nvgFontSize(vg, 26)
            DrawWhiteInkText(cx, popY + popH/2, "鏆傛棤鎺掕鏁版嵁")
        else
            nvgSave(vg)
            nvgScissor(vg, popX + 8, popY + 54, popW - 16, popH - 110)
            local listY = popY + 72 - rankedState.rankScroll.offset
            for i, entry in ipairs(rankedState.rankList) do
                local ey = listY + (i - 1) * 36
                if ey > popY + 54 and ey < popY + popH - 55 then
                    local eTier = GetRankedTier(entry.score)
                    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    -- 鎺掑悕
                    local rankStr = "#" .. i
                    local rankColor = (i <= 3) and nvgRGBA(255, 200, 60, 240) or nvgRGBA(200, 200, 200, 200)
                    nvgFillColor(vg, rankColor)
                    nvgText(vg, popX + 16, ey, rankStr, nil)
                    -- 鍚嶅瓧锛堟牴鎹帓鍚嶅搴﹀姩鎬佸亸绉伙級
                    local nameX = popX + 70
                    nvgFillColor(vg, nvgRGBA(220, 220, 220, 230))
                    nvgText(vg, nameX, ey, entry.name, nil)
                    -- 娈典綅鍚嶇О
                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(eTier.color[1], eTier.color[2], eTier.color[3], 230))
                    nvgFontSize(vg, 20)
                    nvgText(vg, popX + popW - 20, ey, eTier.name .. " " .. tostring(entry.score) .. "鍒?, nil)
                end
            end
            nvgRestore(vg)
        end
        return
    end

    -- 椤堕儴杩斿洖鎸夐挳
    local topY = 14
    local backW, backH = 100, 38
    nvgBeginPath(vg); nvgRoundedRect(vg, 14, topY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(15, 12, 30, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 140)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95))
    nvgText(vg, 14 + backW/2 + 1, topY + backH/2 + 1, "< 杩斿洖", nil)
    DrawWhiteInkText(14 + backW/2, topY + backH/2, "< 杩斿洖")
    rankedState.backBtnRect = { x = 14, y = topY, w = backW, h = backH }

    -- 鏍囬
    local titleCY = topY + backH/2
    nvgFontSize(vg, 38); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 130))
    nvgText(vg, cx + 2, titleCY + 2, "鎺掍綅璧?, nil)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200))
    nvgText(vg, cx + 1, titleCY + 1, "鎺掍綅璧?, nil)
    DrawWhiteInkText(cx, titleCY, "鎺掍綅璧?)
    DrawHelpBtn(DESIGN_W - 14 - 30, topY + (backH - 30) / 2, 30)

    -- 鍓爣棰?
    nvgFontSize(vg, 27)
    DrawWhiteInkText(cx, titleCY + 22, "- 姝︾伒瀵瑰喅 - 娈典綅鏀€鍗?-")

    -- 瑁呴グ鍒嗛殧绾?
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

    -- 娈典綅鍗＄墖
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

    -- 娈典綅澶у浘鏍?
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 56)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
    nvgText(vg, cardX + 50, contentY + 55, tier.icon, nil)

    -- 娈典綅鍚嶇О
    nvgFontSize(vg, 38)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
    nvgText(vg, cardX + 85, contentY + 40, tier.name, nil)

    -- 绉垎
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(220, 220, 220, 220))
    nvgText(vg, cardX + 85, contentY + 68, "绉垎: " .. rankedState.score, nil)

    -- 涓嬩竴娈典綅杩涘害
    local nextTierIdx = math.min(#RANKED_TIERS, tier.index + 1)
    local nextTier = RANKED_TIERS[nextTierIdx]
    if tier.index < #RANKED_TIERS then
        local progress = (rankedState.score - tier.minScore) / (nextTier.minScore - tier.minScore)
        progress = math.max(0, math.min(1, progress))
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 180))
        nvgText(vg, cardX + 85, contentY + 92, "璺? .. nextTier.name .. ": " .. (nextTier.minScore - rankedState.score) .. "鍒?, nil)
        -- 杩涘害鏉?
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
        nvgText(vg, cardX + 85, contentY + 92, "宸茶揪鏈€楂樻浣?", nil)
    end

    -- 鎴樼哗缁熻
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(100, 220, 130, 220))
    nvgText(vg, cardX + cardW - 15, contentY + 40, rankedState.wins .. "鑳?, nil)
    nvgFillColor(vg, nvgRGBA(255, 100, 100, 220))
    nvgText(vg, cardX + cardW - 15, contentY + 65, rankedState.losses .. "璐?, nil)
    local winRate = (rankedState.wins + rankedState.losses > 0)
        and math.floor(rankedState.wins / (rankedState.wins + rankedState.losses) * 100) or 0
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
    nvgText(vg, cardX + cardW - 15, contentY + 90, "鑳滅巼" .. winRate .. "%", nil)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 200))
    nvgFontSize(vg, 22)
    nvgText(vg, cardX + cardW - 15, contentY + 115, "鏈€楂? .. rankedState.highestScore .. "鍒?, nil)

    -- 鎴戠殑鎴樺姏
    local myPower = CalcPlayerTotalPower()
    local powerY = contentY + cardH + 14
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, powerY, "褰撳墠鎴樺姏: " .. FormatPower(myPower))

    -- 鎸夐挳鍖哄煙
    local btnY = powerY + 30
    -- 寮€濮嬪尮閰嶆寜閽?
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
    nvgText(vg, cx + 1, btnY + startBtnH / 2 + 1, "寮€濮嬪尮閰?, nil)
    DrawWhiteInkText(cx, btnY + startBtnH / 2, "寮€濮嬪尮閰?)
    rankedState.startBtnRect = { x = startBtnX, y = btnY, w = startBtnW, h = startBtnH }

    -- 鎺掕姒滄寜閽?
    local rankBtnW = 100
    local rankBtnH = 36
    local rankBtnX = cx - rankBtnW / 2
    local rankBtnY = btnY + startBtnH + 12
    nvgBeginPath(vg); nvgRoundedRect(vg, rankBtnX, rankBtnY, rankBtnW, rankBtnH, 6)
    nvgFillColor(vg, nvgRGBA(30, 28, 50, 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, rankBtnX, rankBtnY, rankBtnW, rankBtnH, 6)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, rankBtnY + rankBtnH / 2, "鎺掕姒?)
    rankedState.rankBtnRect = { x = rankBtnX, y = rankBtnY, w = rankBtnW, h = rankBtnH }
end


-- ============================================================================
-- 30s鎵撴々 - 閫夊皢鐣岄潰
-- ============================================================================
function DrawDummySelectScreen()
    if gameState.phase ~= "DUMMY_SELECT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0

    DrawCombatBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 妯睆甯冨眬: 宸︿晶=宸查€夋鐏?寮€濮嬫寜閽? 鍙充晶=姝︾伒閫夋嫨缃戞牸
    local leftW = 220  -- 宸︽爮瀹藉害
    local rightX = leftW + 8

    -- 椤堕儴鏍? 杩斿洖 + 鏍囬
    local topY = 8
    local backW, backH = 80, 32
    local backX, backY = 10, topY
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 杩斿洖")
    dummyState.backBtnRect = { x = backX, y = backY, w = backW, h = backH }

    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 100, 80, 240))
    nvgText(vg, cx, topY + backH / 2, "30s 鎵撴々鎸戞垬", nil)

    -- 宸︿晶: 宸查€夋鐏甸瑙堝尯 (绾靛悜鎺掑垪)
    local selStartY = topY + backH + 10
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftW / 2, selStartY, "閫夋嫨鏈€澶?鍚嶆鐏?)
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

    -- 寮€濮嬫寜閽?(宸︿晶搴曢儴)
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
    nvgText(vg, startX + startW / 2, startY + startH / 2, "寮€濮嬫寫鎴?(" .. #dummyState.selected .. "/4)", nil)
    dummyState.startBtnRect = canStart and { x = startX, y = startY, w = startW, h = startH } or nil

    -- 鍙充晶: 姝︾伒閫夋嫨缃戞牸锛堝凡鎷ユ湁鐨勬鐏碉紝鏀寔鎷栨嫿婊氬姩锛?
    local gridY = topY + backH + 6
    local gridH = H - gridY - 8
    dummyState.gridH = gridH
    nvgSave(vg)
    nvgScissor(vg, rightX, gridY, W - rightX, gridH)

    dummyState.cardRects = {}
    local gridW = W - rightX - 12
    local cols = 6  -- 妯睆瀹藉害鏇村ぇ锛岀敤6鍒?
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
                    nvgText(vg, cxp + cardW2 - 3, cyp + 2, "鉁?, nil)
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
-- 30s鎵撴々 - 缁撴灉鐣岄潰
-- ============================================================================
function DrawDummyResultScreen()
    if gameState.phase ~= "DUMMY_RESULT" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0

    DrawCombatBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 妯睆甯冨眬: 涓婂崐=鏍囬+浼ゅ+DPS, 涓嬪崐=姝︾伒+鎸夐挳 (姘村钩鍏呰冻锛屽瀭鐩寸揣鍑?
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 鏍囬
    nvgFontSize(vg, 36)
    nvgFillColor(vg, nvgRGBA(255, 100, 80, 240))
    nvgText(vg, cx, 40, "鎸戞垬缁撴潫!", nil)

    -- 鎬讳激瀹虫爣绛?
    nvgFontSize(vg, 24)
    DrawWhiteInkText(cx, 72, "30绉掑唴绱浼ゅ")

    -- 浼ゅ鏁板瓧锛堝ぇ瀛楋級
    nvgFontSize(vg, 52)
    local dmgPulse = 0.9 + 0.1 * math.sin(t * 3)
    nvgFillColor(vg, nvgRGBA(255, 200, 60, math.floor(240 * dmgPulse)))
    nvgText(vg, cx, 115, tostring(math.floor(dummyState.totalDamage)), nil)

    -- DPS
    local dps = dummyState.totalDamage / 30
    nvgFontSize(vg, 26)
    nvgFillColor(vg, nvgRGBA(130, 200, 255, 220))
    nvgText(vg, cx, 150, string.format("DPS: %.0f", dps), nil)

    -- 鍙傛垬姝︾伒
    nvgFontSize(vg, 22)
    DrawWhiteInkText(cx, 180, "鍙傛垬姝︾伒")

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

    -- 杩斿洖鎸夐挳
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
    nvgText(vg, cx, btnY + btnH / 2, "杩斿洖涓昏彍鍗?, nil)
    dummyState.resultBackRect = { x = btnX, y = btnY, w = btnW, h = btnH }
end


-- ============================================================================
-- 寮€鍙戣€呮垬鍦虹紪杈戝櫒
-- ============================================================================
