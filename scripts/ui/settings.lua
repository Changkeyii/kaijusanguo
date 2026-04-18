-- ============================================================================
-- ui/settings.lua - 涓夊浗姝︾伒褰?"
-- ============================================================================


-- ============================================================================
-- 璁剧疆鐣岄潰 (璁捐鍧愭爣, 瑕嗙洊鍦ㄨ彍鍗曚笂鏂?"
-- ============================================================================
function DrawSettingsScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime

    -- 鍗婇€忔槑鍏ㄥ睆閬僵
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95)); nvgFill(vg)

    -- 璁剧疆闈㈡澘 (妯睆閫傞厤: 瀹介潰鏉?绱у噾琛岃窛)
    local panW = 520
    local panH = 480
    local panX = cx - panW / 2
    local panY = (H - panH) / 2

    -- 闈㈡澘鑳屾櫙
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 8)
    nvgFillColor(vg, nvgRGBA(30, 38, 58, 220)); nvgFill(vg)
    -- 閾滆壊杈规
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 8)
    nvgStrokeWidth(vg, 2)
    nvgStrokeColor(vg, nvgRGBA(162, 128, 78, 200)); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 鏍囬
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, panY + 32, "璁剧疆")

    -- UID 鏄剧ず + 涓€閿鍒舵寜閽?(鍒嗛殧绾夸笅鏂圭嫭绔嬭)
    local leftM = panX + 24
    local rightM = panX + panW - 24
    local uidRowY = panY + 80
    do
        local uid = CloudAPI.GetUserId()
        local uidStr = uid ~= 0 and tostring(uid) or "---"
        -- UID 鏍囩 + 鏁板€?"
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 135, 120, 180))
        nvgText(vg, leftM, uidRowY, "UID:", nil)
        nvgFillColor(vg, nvgRGBA(220, 215, 200, 230))
        nvgText(vg, leftM + 40, uidRowY, uidStr, nil)
        -- 澶嶅埗鎸夐挳
        local cpBtnW, cpBtnH = 52, 22
        local cpBtnX = leftM + 40 + nvgTextBounds(vg, 0, 0, uidStr, nil) + 10
        local cpBtnY = uidRowY - cpBtnH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, cpBtnX, cpBtnY, cpBtnW, cpBtnH, 4)
        -- 澶嶅埗鎴愬姛闂儊鏁堟灉
        local copyFlash = settingsPage.uidCopyTimer and settingsPage.uidCopyTimer > 0
        if copyFlash then
            nvgFillColor(vg, nvgRGBA(60, 160, 80, 220))
        else
            nvgFillColor(vg, nvgRGBA(60, 80, 120, 200))
        end
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 140, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 230, 255, 230))
        nvgText(vg, cpBtnX + cpBtnW / 2, cpBtnY + cpBtnH / 2, copyFlash and "已复制" or "复制", nil)
        settingsPage.uidCopyBtnRect = { x = cpBtnX, y = cpBtnY, w = cpBtnW, h = cpBtnH }
        settingsPage.uidValue = uidStr
        -- 澶嶅埗鎴愬姛鎻愮ず璁℃椂琛板噺
        if settingsPage.uidCopyTimer and settingsPage.uidCopyTimer > 0 then
            settingsPage.uidCopyTimer = settingsPage.uidCopyTimer - (1.0 / 60.0)
        end
    end

    -- 鍒嗛殧绾?"
    nvgBeginPath(vg)
    nvgMoveTo(vg, panX + 20, panY + 56)
    nvgLineTo(vg, panX + panW - 20, panY + 56)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local contentW = rightM - leftM
    local rowY = panY + 100
    local rowGap = 46

    -- ======== 闊充箰闊抽噺 ========
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "闊充箰")

    local sliderX = leftM + 80
    local sliderW = contentW - 80
    local sliderH = 8
    local sliderY = rowY - sliderH / 2
    -- 婊戞潯鑳屾櫙
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, sliderY, sliderW, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
    -- 婊戞潯濉厖
    local musicFill = sliderW * gameSettings.musicVolume
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, sliderY, musicFill, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(120, 50, 55, 200)); nvgFill(vg)
    -- 婊戝潡
    local knobX = sliderX + musicFill
    nvgBeginPath(vg); nvgCircle(vg, knobX, rowY, 8)
    nvgFillColor(vg, nvgRGBA(200, 180, 190, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    -- 鐧惧垎姣?(鏄剧ず鍦ㄦ粦鏉″彸绔笂鏂?"
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    DrawWhiteInkText(rightM, rowY - 10, math.floor(gameSettings.musicVolume * 100) .. "%")
    settingsPage.musicSliderRect = { x = sliderX, y = sliderY - 10, w = sliderW, h = sliderH + 20 }

    -- ======== 闊虫晥闊抽噺 ========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "闊虫晥")

    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, rowY - sliderH / 2, sliderW, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
    local sfxFill = sliderW * gameSettings.sfxVolume
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, rowY - sliderH / 2, sfxFill, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(120, 50, 55, 200)); nvgFill(vg)
    local sfxKnobX = sliderX + sfxFill
    nvgBeginPath(vg); nvgCircle(vg, sfxKnobX, rowY, 8)
    nvgFillColor(vg, nvgRGBA(200, 180, 190, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    DrawWhiteInkText(rightM, rowY - 10, math.floor(gameSettings.sfxVolume * 100) .. "%")
    settingsPage.sfxSliderRect = { x = sliderX, y = rowY - sliderH / 2 - 10, w = sliderW, h = sliderH + 20 }

    -- ======== 鎸夐挳浣嶇疆涓庡ぇ灏?========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "鎸夐挳浣嶇疆涓庡ぇ灏?")

    local adjBtnW = 80
    local adjBtnH = 28
    local adjBtnX = rightM - adjBtnW
    local adjBtnY = rowY - adjBtnH / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, adjBtnX, adjBtnY, adjBtnW, adjBtnH, 6)
    nvgFillPaint(vg, nvgLinearGradient(vg, adjBtnX, adjBtnY, adjBtnX, adjBtnY + adjBtnH,
        nvgRGBA(100, 140, 200, 220), nvgRGBA(60, 90, 150, 220)))
    nvgFill(vg)
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(adjBtnX + adjBtnW / 2, adjBtnY + adjBtnH / 2, "璋冩暣")
    settingsPage.adjustPosBtnRect = { x = adjBtnX, y = adjBtnY, w = adjBtnW, h = adjBtnH }

    -- ======== 榛樿鑷姩琛屽啗 ========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "榛樿鑷姩琛屽啗")

    -- 寮€鍏虫寜閽?"
    local toggleW = 44
    local toggleH = 22
    local toggleX = rightM - toggleW
    local toggleY = rowY - toggleH / 2
    local isOn = gameSettings.defaultAutoMarch
    -- 搴曞骇
    nvgBeginPath(vg); nvgRoundedRect(vg, toggleX, toggleY, toggleW, toggleH, toggleH / 2)
    nvgFillColor(vg, isOn and nvgRGBA(80, 180, 100, 200) or nvgRGBA(60, 55, 70, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    -- 婊戝潡鍦?"
    local toggleKnobX = isOn and (toggleX + toggleW - toggleH / 2 - 2) or (toggleX + toggleH / 2 + 2)
    nvgBeginPath(vg); nvgCircle(vg, toggleKnobX, rowY, toggleH / 2 - 3)
    nvgFillColor(vg, nvgRGBA(240, 230, 210, 240)); nvgFill(vg)
    settingsPage.autoMarchToggleRect = { x = toggleX, y = toggleY, w = toggleW, h = toggleH }

    -- ======== 瀛椾綋椋庢牸 ========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "瀛椾綋椋庢牸")

    -- 鍥涗釜瀛椾綋閫夐」鎸夐挳: MiSans / 蹇箰浣?/ 鏂囨シ / 琛屼功
    local fontOptW = 42
    local fontOptH = 28
    local fontOptGap = 4
    local curFontStyle = gameSettings.fontStyle or "misans"

    local fontBtns = {
        { key = "misans",  label = "榛樿" },
        { key = "kuaile",  label = "蹇箰" },
        { key = "wenkai",  label = "鏂囨シ" },
        { key = "xingshu", label = "琛屼功" },
    }
    local totalBtnW = #fontBtns * fontOptW + (#fontBtns - 1) * fontOptGap
    local fontOptStartX = rightM - totalBtnW
    for i, btn in ipairs(fontBtns) do
        local bx = fontOptStartX + (i - 1) * (fontOptW + fontOptGap)
        local by = rowY - fontOptH / 2
        local isActive = (curFontStyle == btn.key)
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, fontOptW, fontOptH, 5)
        if isActive then
            nvgFillPaint(vg, nvgLinearGradient(vg, bx, by, bx, by + fontOptH,
                nvgRGBA(90, 45, 55, 220), nvgRGBA(60, 25, 35, 220)))
        else
            nvgFillColor(vg, nvgRGBA(40, 38, 50, 200))
        end
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            DrawWhiteInkText(bx + fontOptW / 2, by + fontOptH / 2, btn.label)
        else
            nvgFillColor(vg, nvgRGBA(160, 145, 120, 180))
            nvgText(vg, bx + fontOptW / 2, by + fontOptH / 2, btn.label, nil)
        end
        -- 瀛樺偍鎸夐挳鍖哄煙鐢ㄤ簬鐐瑰嚮妫€娴?"
        settingsPage["font_" .. btn.key .. "_rect"] = { x = bx, y = by, w = fontOptW, h = fontOptH }
    end

    -- ======== 榛樿鎴樺満 ========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "榛樿鎴樺満")

    -- 鍒囨崲鎸夐挳 (鏄剧ず褰撳墠鎴樺満鍚? 鐐瑰嚮鍒囨崲)
    local bfBtnW = 120
    local bfBtnH = 28
    local bfBtnX = rightM - bfBtnW
    local bfBtnY = rowY - bfBtnH / 2
    local curBf = gameSettings.defaultBattlefield or 1
    local bfLayout = BATTLE_LAYOUTS[curBf]
    local bfName = bfLayout and bfLayout.name or "榛樿鎴樺満"
    nvgBeginPath(vg); nvgRoundedRect(vg, bfBtnX, bfBtnY, bfBtnW, bfBtnH, 5)
    nvgFillColor(vg, nvgRGBA(25, 35, 55, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 23)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(bfBtnX + bfBtnW / 2, bfBtnY + bfBtnH / 2, bfName)
    -- 宸﹀彸灏忕澶存彁绀?"
    nvgFontSize(vg, 19)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(bfBtnX - 2, bfBtnY + bfBtnH / 2, "鈼€")
    DrawWhiteInkText(bfBtnX + bfBtnW + 2, bfBtnY + bfBtnH / 2, "鈻?")
    settingsPage.battlefieldBtnRect = { x = bfBtnX - 14, y = bfBtnY, w = bfBtnW + 28, h = bfBtnH }

    -- ======== CDK 鍏戞崲 ========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "CDK鍏戞崲")

    local cdkBtnW = 80
    local cdkBtnH = 28
    local cdkBtnX = rightM - cdkBtnW
    local cdkBtnY = rowY - cdkBtnH / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, cdkBtnX, cdkBtnY, cdkBtnW, cdkBtnH, 6)
    nvgFillPaint(vg, nvgLinearGradient(vg, cdkBtnX, cdkBtnY, cdkBtnX, cdkBtnY + cdkBtnH,
        nvgRGBA(80, 140, 180, 220), nvgRGBA(50, 100, 140, 220)))
    nvgFill(vg)
    nvgFontSize(vg, 25)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cdkBtnX + cdkBtnW / 2, cdkBtnY + cdkBtnH / 2, "输入兑换码")
    settingsPage.cdkBtnRect = { x = cdkBtnX, y = cdkBtnY, w = cdkBtnW, h = cdkBtnH }

    -- ======== 浠婃棩鍏嶅箍鍛婂崱 (鐪?娆″箍鍛婂厤鎴樻枟骞垮憡) ========
    rowY = rowY + rowGap
    do
        -- 璺ㄦ棩閲嶇疆妫€鏌?"
        local today = os.date("%Y-%m-%d")
        if gameSettings.dailyAdDate ~= today then
            gameSettings.dailyAdCount = 0
            gameSettings.dailyAdDate = today
        end
        local adCount = math.min(gameSettings.dailyAdCount, 3)
        local isActive = adCount >= 3
        local isPermanent = playerInfo.ad_free

        nvgFontSize(vg, 27)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(leftM, rowY, "鍏嶅箍鍛婂崱")

        -- 鍙充晶: 杩涘害鏉?+ 鐪嬪箍鍛婃寜閽?"
        local adBtnW = 72
        local adBtnGap = 8
        local barW = contentW - 90 - adBtnW - adBtnGap
        local barH = 10
        local barX = leftM + 90
        local barY = rowY - barH / 2

        if isPermanent then
            -- 姘镐箙鍏嶅箍鍛婄壒鏉?"
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(100, 255, 150, 220))
            nvgText(vg, rightM, rowY, "永久免广告", nil)
            settingsPage.adCardBtnRect = nil
        else
            -- 杩涘害鏉¤儗鏅?"
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 5)
            nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
            -- 杩涘害鏉″～鍏?"
            local fillW = barW * (adCount / 3)
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, fillW, barH, 5)
            if isActive then
                nvgFillColor(vg, nvgRGBA(80, 200, 120, 220))
            else
                nvgFillColor(vg, nvgRGBA(200, 160, 60, 200))
            end
            nvgFill(vg)
            -- 3涓埢搴︾偣
            for i = 1, 3 do
                local dotX = barX + barW * (i / 3) - barW / 6
                local filled = i <= adCount
                nvgBeginPath(vg); nvgCircle(vg, dotX, rowY, 5)
                if filled then
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
                else
                    nvgFillColor(vg, nvgRGBA(60, 55, 70, 200))
                end
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(90, 80, 70, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            end
            -- 鐘舵€佹枃瀛?"
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            if isActive then
                nvgFillColor(vg, nvgRGBA(100, 255, 180, 220))
                nvgText(vg, barX + barW / 2, rowY + barH / 2 + 4, "宸叉縺娲?- 鎴樻枟骞垮憡宸插厤闄?", nil)
            else
                nvgFillColor(vg, nvgRGBA(180, 170, 150, 160))
                nvgText(vg, barX + barW / 2, rowY + barH / 2 + 4, adCount .. "/3 看广告激活", nil)
            end
            -- 鈽?鐪嬪箍鍛婃寜閽?(鏈縺娲绘椂鏄剧ず)
            local adBtnX = barX + barW + adBtnGap
            local adBtnH = 28
            local adBtnY = rowY - adBtnH / 2
            if not isActive then
                nvgBeginPath(vg); nvgRoundedRect(vg, adBtnX, adBtnY, adBtnW, adBtnH, 6)
                nvgFillColor(vg, nvgRGBA(200, 160, 50, 220)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(255, 210, 80, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 16)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(40, 30, 10, 240))
                nvgText(vg, adBtnX + adBtnW / 2, adBtnY + adBtnH / 2, "看广告", nil)
                settingsPage.adCardBtnRect = { x = adBtnX, y = adBtnY, w = adBtnW, h = adBtnH }
            else
                settingsPage.adCardBtnRect = nil
            end
        end
    end

    -- ======== 淇濆瓨 & 鍏抽棴鎸夐挳 ========
    local btnRowY = panY + panH - 48
    local saveBtnW = 100
    local saveBtnH = 36
    local closeBtnW = 80
    local closeBtnH = 36

    -- 淇濆瓨鎸夐挳
    local saveBtnX = cx - saveBtnW / 2 - closeBtnW / 2 - 10
    nvgBeginPath(vg); nvgRoundedRect(vg, saveBtnX, btnRowY, saveBtnW, saveBtnH, 6)
    local saveGrad = nvgLinearGradient(vg, saveBtnX, btnRowY, saveBtnX, btnRowY + saveBtnH,
        nvgRGBA(90, 45, 55, 220), nvgRGBA(60, 25, 35, 220))
    nvgFillPaint(vg, saveGrad); nvgFill(vg)
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(saveBtnX + saveBtnW / 2, btnRowY + saveBtnH / 2, "淇濆瓨")
    settingsPage.saveBtnRect = { x = saveBtnX, y = btnRowY, w = saveBtnW, h = saveBtnH }

    -- 鍏抽棴鎸夐挳
    local closeBtnX = cx + saveBtnW / 2 - closeBtnW / 2 + 10
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, btnRowY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(50, 45, 60, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(closeBtnX + closeBtnW / 2, btnRowY + closeBtnH / 2, "鍏抽棴")
    settingsPage.closeBtnRect = { x = closeBtnX, y = btnRowY, w = closeBtnW, h = closeBtnH }
end


-- ============================================================================
-- CDK 鍏戞崲寮圭獥 (浣跨敤鍘熺敓閿洏杈撳叆)
-- ============================================================================
function DrawCDKPopup()
    if not cdkState.inputOpen then return end
    local W = DESIGN_W
    local H = DESIGN_H
    -- 閬僵
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 130)); nvgFill(vg)

    -- 绱у噾寮圭獥闈㈡澘
    local pw, ph = 420, 200
    local px = (W - pw) / 2
    local py = (H - ph) / 2 - 80  -- 鍋忎笂锛岀粰鍘熺敓閿洏鐣欑┖闂?"
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(30, 28, 40, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 鏍囬
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(px + pw / 2, py + 24, "输入兑换码")

    -- 杈撳叆妗?"
    local inputX = px + 20
    local inputY = py + 50
    local inputW = pw - 40
    local inputH = 46
    nvgBeginPath(vg); nvgRoundedRect(vg, inputX, inputY, inputW, inputH, 6)
    nvgFillColor(vg, nvgRGBA(15, 14, 22, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 80, 50, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    cdkState.inputBoxRect = { x = inputX, y = inputY, w = inputW, h = inputH }
    -- 杈撳叆鏂囧瓧 / 鍗犱綅绗?"
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local textY = inputY + inputH / 2
    if #cdkState.inputText > 0 then
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, inputX + 10, textY, cdkState.inputText, nil)
        -- 鍏夋爣闂儊
        if math.floor(os.clock() * 2) % 2 == 0 then
            local tw = nvgTextBounds(vg, 0, 0, cdkState.inputText, nil)
            nvgBeginPath(vg); nvgRect(vg, inputX + 10 + tw + 2, inputY + 8, 2, inputH - 16)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 200)); nvgFill(vg)
        end
    else
        nvgFillColor(vg, nvgRGBA(150, 140, 130, 120))
        nvgText(vg, inputX + 10, textY, "请用键盘输入兑换码", nil)
        -- 鍏夋爣
        if math.floor(os.clock() * 2) % 2 == 0 then
            nvgBeginPath(vg); nvgRect(vg, inputX + 10, inputY + 8, 2, inputH - 16)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 200)); nvgFill(vg)
        end
    end

    -- 缁撴灉鍙嶉 (鍦ㄨ緭鍏ユ涓嬫柟)
    local feedbackY = inputY + inputH + 4
    if cdkState.resultTimer > 0 then
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if cdkState.resultOk then
            nvgFillColor(vg, nvgRGBA(80, 230, 80, 230))
        else
            nvgFillColor(vg, nvgRGBA(255, 80, 80, 230))
        end
        nvgText(vg, W / 2, feedbackY + 8, cdkState.resultText, nil)
    end

    -- ======== 鎸夐挳琛? 绮樿创 | 娓呯┖ | 鍏戞崲 | 鍏抽棴 ========
    local btnY = inputY + inputH + 32
    local btnH = 42
    local btnGap = 8
    local btnTotalW = pw - 40
    local btnStartX = px + 20
    -- 4涓寜閽潎鍒嗗搴?"
    local btnW = math.floor((btnTotalW - btnGap * 3) / 4)

    -- 绮樿创
    local pasteX = btnStartX
    nvgBeginPath(vg); nvgRoundedRect(vg, pasteX, btnY, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(50, 80, 120, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 150, 200, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(pasteX + btnW / 2, btnY + btnH / 2, "绮樿创")
    cdkState.pasteBtnRect = { x = pasteX, y = btnY, w = btnW, h = btnH }

    -- 娓呯┖
    local clearX = pasteX + btnW + btnGap
    nvgBeginPath(vg); nvgRoundedRect(vg, clearX, btnY, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 55, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(clearX + btnW / 2, btnY + btnH / 2, "娓呯┖")
    cdkState.clearBtnRect = { x = clearX, y = btnY, w = btnW, h = btnH }

    -- 鍏戞崲
    local redeemX = clearX + btnW + btnGap
    nvgBeginPath(vg); nvgRoundedRect(vg, redeemX, btnY, btnW, btnH, 6)
    nvgFillPaint(vg, nvgLinearGradient(vg, redeemX, btnY, redeemX, btnY + btnH,
        nvgRGBA(160, 120, 40, 230), nvgRGBA(120, 80, 20, 230)))
    nvgFill(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(redeemX + btnW / 2, btnY + btnH / 2, "鍏戞崲")
    cdkState.redeemBtnRect = { x = redeemX, y = btnY, w = btnW, h = btnH }

    -- 鍏抽棴
    local closeX = redeemX + btnW + btnGap
    local closeW = btnStartX + btnTotalW - closeX  -- 鏈€鍚庝竴涓寜閽悆鎺変綑閲?"
    nvgBeginPath(vg); nvgRoundedRect(vg, closeX, btnY, closeW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 55, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(closeX + closeW / 2, btnY + btnH / 2, "鍏抽棴")
    cdkState.closeBtnRect = { x = closeX, y = btnY, w = closeW, h = btnH }
end

