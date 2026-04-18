-- ============================================================================
-- ui/settings.lua - 濞戞挸顦ù妤€顫㈤敂鍙ョ触鐟?"
-- ============================================================================


-- ============================================================================
-- 閻犱礁澧介悿鍡涙偩瀹€鍕〃 (閻犱焦宕橀鎼佸锤閹邦厾鍨? 閻熸洖妫涘ú濠囧捶閵娿劌缍呴柛妤佹磻缁楀倿寮?"
-- ============================================================================
function DrawSettingsScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime

    -- 闁告锕埀顒€绻戝Σ鎴﹀礂閵娿儳娼岄梺顒夊枤閸?
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95)); nvgFill(vg)

    -- 閻犱礁澧介悿鍡涙閵忊剝绶?(婵☆垼浜滈惈鍡涙焻閸岀偛甯? 閻庨€涚矙濞间即寮?缂佹瘱鍐ㄦ閻炴稑鐭佺粣?
    local panW = 520
    local panH = 480
    local panX = cx - panW / 2
    local panY = (H - panH) / 2

    -- 闂傚牄鍨哄姗€鎳楃仦鐐彲
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 8)
    nvgFillColor(vg, nvgRGBA(30, 38, 58, 220)); nvgFill(vg)
    -- 闂佺偓绮忔竟濠冩綇鐟欏嫷鏀?
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 8)
    nvgStrokeWidth(vg, 2)
    nvgStrokeColor(vg, nvgRGBA(162, 128, 78, 200)); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 闁哄秴娲。?
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, panY + 32, "Settings")

    -- UID 闁哄嫬澧介妵?+ 濞戞挴鍋撻梺娆惧枛椤︽煡宕氶懜闈涚樆闂?(闁告帒妫濆▓褏鐥径鍝ョ憮闁哄倸婀辩€氼厾绮╃€ｎ収鏀?
    local leftM = panX + 24
    local rightM = panX + panW - 24
    local uidRowY = panY + 80
    do
        local uid = CloudAPI.GetUserId()
        local uidStr = uid ~= 0 and tostring(uid) or "---"
        -- UID 闁哄秴娲ㄩ?+ 闁轰焦婢橀埀?"
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 135, 120, 180))
        nvgText(vg, leftM, uidRowY, "UID:", nil)
        nvgFillColor(vg, nvgRGBA(220, 215, 200, 230))
        nvgText(vg, leftM + 40, uidRowY, uidStr, nil)
        -- 濠㈣泛绉撮崺妤呭箰婢舵劖灏?
        local cpBtnW, cpBtnH = 52, 22
        local cpBtnX = leftM + 40 + nvgTextBounds(vg, 0, 0, uidStr, nil) + 10
        local cpBtnY = uidRowY - cpBtnH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, cpBtnX, cpBtnY, cpBtnW, cpBtnH, 4)
        -- 濠㈣泛绉撮崺妤呭箣閹邦剙顫犻梻鍌や簽閸庡﹪寮崼鐔轰函
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
        nvgText(vg, cpBtnX + cpBtnW / 2, cpBtnY + cpBtnH / 2, copyFlash and "Copied" or "Copy", nil)
        settingsPage.uidCopyBtnRect = { x = cpBtnX, y = cpBtnY, w = cpBtnW, h = cpBtnH }
        settingsPage.uidValue = uidStr
        -- 濠㈣泛绉撮崺妤呭箣閹邦剙顫犻柟缁樺姉閵囨氨鎷嬮埄鍐╊槯閻炴稒婢橀崳?
        if settingsPage.uidCopyTimer and settingsPage.uidCopyTimer > 0 then
            settingsPage.uidCopyTimer = settingsPage.uidCopyTimer - (1.0 / 60.0)
        end
    end

    -- 闁告帒妫濆▓褏鐥?"
    nvgBeginPath(vg)
    nvgMoveTo(vg, panX + 20, panY + 56)
    nvgLineTo(vg, panX + panW - 20, panY + 56)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local contentW = rightM - leftM
    local rowY = panY + 100
    local rowGap = 46

    -- ======== 闂傚﹤鍘栫粻浼存閹惰棄娅?========
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "Music")

    local sliderX = leftM + 80
    local sliderW = contentW - 80
    local sliderH = 8
    local sliderY = rowY - sliderH / 2
    -- 婵犲﹥鍨跺顖炴嚄鐏炵偓鐝?
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, sliderY, sliderW, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
    -- 婵犲﹥鍨跺顖涚箙椤愩垹甯?
    local musicFill = sliderW * gameSettings.musicVolume
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, sliderY, musicFill, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(120, 50, 55, 200)); nvgFill(vg)
    -- 婵犲﹥鍨靛?
    local knobX = sliderX + musicFill
    nvgBeginPath(vg); nvgCircle(vg, knobX, rowY, 8)
    nvgFillColor(vg, nvgRGBA(200, 180, 190, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    -- 闁谎勫劤閸ㄥ骸袙?(闁哄嫬澧介妵姘跺捶閵婏妇鎷ㄩ柡澶嗏偓鍐茬缂佹棏鍨粭鍌炲棘?"
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    DrawWhiteInkText(rightM, rowY - 10, math.floor(gameSettings.musicVolume * 100) .. "%")
    settingsPage.musicSliderRect = { x = sliderX, y = sliderY - 10, w = sliderW, h = sliderH + 20 }

    -- ======== 闂傚﹨娅曢弲銉╂閹惰棄娅?========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "SFX")

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

    -- ======== 闁圭顦甸幐铏媴瀹ュ洨鏋傚☉鎾抽閵囧洨浜?========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "HUD Position")

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
    DrawWhiteInkText(adjBtnX + adjBtnW / 2, adjBtnY + adjBtnH / 2, "Adjust HUD")
    settingsPage.adjustPosBtnRect = { x = adjBtnX, y = adjBtnY, w = adjBtnW, h = adjBtnH }

    -- ======== 濮掓稒顭堥濠氭嚊椤忓嫬袟閻炴稑鑻崯?========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "Font")

    -- 鐎殿喒鍋撻柛蹇氭珪鐎垫粓鏌?"
    local toggleW = 44
    local toggleH = 22
    local toggleX = rightM - toggleW
    local toggleY = rowY - toggleH / 2
    local isOn = gameSettings.defaultAutoMarch
    -- 閹煎瓨娲栨?
    nvgBeginPath(vg); nvgRoundedRect(vg, toggleX, toggleY, toggleW, toggleH, toggleH / 2)
    nvgFillColor(vg, isOn and nvgRGBA(80, 180, 100, 200) or nvgRGBA(60, 55, 70, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    -- 婵犲﹥鍨靛锟犲捶?"
    local toggleKnobX = isOn and (toggleX + toggleW - toggleH / 2 - 2) or (toggleX + toggleH / 2 + 2)
    nvgBeginPath(vg); nvgCircle(vg, toggleKnobX, rowY, toggleH / 2 - 3)
    nvgFillColor(vg, nvgRGBA(240, 230, 210, 240)); nvgFill(vg)
    settingsPage.autoMarchToggleRect = { x = toggleX, y = toggleY, w = toggleW, h = toggleH }

    -- ======== 閻庢稒銇炵紞瀣槹鎼淬垻澹?========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "Font Pack")

    -- 闁搞儲绋愰柌婊呪偓娑欍仦缂嶅鏌呮径鎰┾偓宥夊箰婢舵劖灏? MiSans / 闊浂鍋傜粻鐗堟媴?/ 闁哄倸娲﹂妶?/ 閻炴稑濂旈崝?
    local fontOptW = 42
    local fontOptH = 28
    local fontOptGap = 4
    local curFontStyle = gameSettings.fontStyle or "misans"

    local fontBtns = {
        { key = "misans",  label = "MiSans" },
        { key = "kuaile",  label = "KuaiLe" },
        { key = "wenkai",  label = "WenKai" },
        { key = "xingshu", label = "XingShu" },
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
        -- 閻庢稒锚閸嬪秹骞愭径鎰唉闁告牕鎼悡娆撴偨閵娿倗鑹鹃柣鎰嚀閸ゎ喖螞閳ь剙霉?"
        settingsPage["font_" .. btn.key .. "_rect"] = { x = bx, y = by, w = fontOptW, h = fontOptH }
    end

    -- ======== 濮掓稒顭堥濠氬箣濡儤绨?========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "Battlefield")

    -- 闁告帒娲﹀畷鏌ュ箰婢舵劖灏?(闁哄嫬澧介妵姘炽亹閹惧啿顤呴柟瀛樏┃鈧柛? 闁绘劗鎳撻崵顕€宕氶崶銊ュ簥)
    local bfBtnW = 120
    local bfBtnH = 28
    local bfBtnX = rightM - bfBtnW
    local bfBtnY = rowY - bfBtnH / 2
    local curBf = gameSettings.defaultBattlefield or 1
    local bfLayout = BATTLE_LAYOUTS[curBf]
    local bfName = bfLayout and bfLayout.name or "Default"
    nvgBeginPath(vg); nvgRoundedRect(vg, bfBtnX, bfBtnY, bfBtnW, bfBtnH, 5)
    nvgFillColor(vg, nvgRGBA(25, 35, 55, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 23)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(bfBtnX + bfBtnW / 2, bfBtnY + bfBtnH / 2, bfName)
    -- 鐎归潻绠戣ぐ鍝ヤ焊韫囨洦鍞插璺虹摠瑜颁胶绮?"
    nvgFontSize(vg, 19)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(bfBtnX - 2, bfBtnY + bfBtnH / 2, "<")
    DrawWhiteInkText(bfBtnX + bfBtnW + 2, bfBtnY + bfBtnH / 2, ">")
    settingsPage.battlefieldBtnRect = { x = bfBtnX - 14, y = bfBtnY, w = bfBtnW + 28, h = bfBtnH }

    -- ======== CDK 闁稿繑鍨跺畷?========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "CDK")

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
    DrawWhiteInkText(cdkBtnX + cdkBtnW / 2, cdkBtnY + cdkBtnH / 2, "Redeem Code")
    settingsPage.cdkBtnRect = { x = cdkBtnX, y = cdkBtnY, w = cdkBtnW, h = cdkBtnH }

    -- ======== 濞寸姴锕ュΛ鈺呭礂瀹ュ懐鐣柛娑橈工瀹?(闁?婵炲棌鈧磭鐣柛娑橈工閸樸倝骞嬪Ο缁樼亶妤犵偛鐏濋幉? ========
    rowY = rowY + rowGap
    do
        -- 閻犳亽鍔嶅Λ鈺呮煂瀹ュ洨鏋傛俊顐熷亾闁?"
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
        DrawWhiteInkText(leftM, rowY, "Ad Rewards")

        -- 闁告瑥鍘栭弲? 閺夆晜绋戠€规娊寮?+ 闁活亜顑呯粻宥夊川婵犲啫鐦婚梺?"
        local adBtnW = 72
        local adBtnGap = 8
        local barW = contentW - 90 - adBtnW - adBtnGap
        local barH = 10
        local barX = leftM + 90
        local barY = rowY - barH / 2

        if isPermanent then
            -- 婵﹢鏅茬粻娆撳礂瀹ュ懐鐣柛娑橈功婢规帡寮?"
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(100, 255, 150, 220))
            nvgText(vg, rightM, rowY, "Ads removed permanently", nil)
            settingsPage.adCardBtnRect = nil
        else
            -- 閺夆晜绋戠€规娊寮堕檱閸庢寮?"
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 5)
            nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
            -- 閺夆晜绋戠€规娊寮堕垾绛圭稏闁?"
            local fillW = barW * (adCount / 3)
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, fillW, barH, 5)
            if isActive then
                nvgFillColor(vg, nvgRGBA(80, 200, 120, 220))
            else
                nvgFillColor(vg, nvgRGBA(200, 160, 60, 200))
            end
            nvgFill(vg)
            -- 3濞戞搩浜滈崺銏℃償閿旀儳浠?
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
            -- 闁绘鍩栭埀顑跨劍閺嬪啰鈧?"
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            if isActive then
                nvgFillColor(vg, nvgRGBA(100, 255, 180, 220))
                nvgText(vg, barX + barW / 2, rowY + barH / 2 + 4, "鐎圭寮剁缓鍝劽?- 闁瑰瓨蓱閺嬬喖鐛崹顔藉暈鐎瑰憡褰冮崢銈夋⒔?", nil)
            else
                nvgFillColor(vg, nvgRGBA(180, 170, 150, 160))
                nvgText(vg, barX + barW / 2, rowY + barH / 2 + 4, adCount .. "/3 ads watched", nil)
            end
            -- 闁?闁活亜顑呯粻宥夊川婵犲啫鐦婚梺?(闁哄牜浜濈缓鍝劽虹紒妯活槯闁哄嫬澧介妵?
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
                nvgText(vg, adBtnX + adBtnW / 2, adBtnY + adBtnH / 2, "Watch Ad", nil)
                settingsPage.adCardBtnRect = { x = adBtnX, y = adBtnY, w = adBtnW, h = adBtnH }
            else
                settingsPage.adCardBtnRect = nil
            end
        end
    end

    -- ======== 濞ｅ洦绻傞悺?& 闁稿繑濞婂Λ鎾箰婢舵劖灏?========
    local btnRowY = panY + panH - 48
    local saveBtnW = 100
    local saveBtnH = 36
    local closeBtnW = 80
    local closeBtnH = 36

    -- 濞ｅ洦绻傞悺銊╁箰婢舵劖灏?
    local saveBtnX = cx - saveBtnW / 2 - closeBtnW / 2 - 10
    nvgBeginPath(vg); nvgRoundedRect(vg, saveBtnX, btnRowY, saveBtnW, saveBtnH, 6)
    local saveGrad = nvgLinearGradient(vg, saveBtnX, btnRowY, saveBtnX, btnRowY + saveBtnH,
        nvgRGBA(90, 45, 55, 220), nvgRGBA(60, 25, 35, 220))
    nvgFillPaint(vg, saveGrad); nvgFill(vg)
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(saveBtnX + saveBtnW / 2, btnRowY + saveBtnH / 2, "Save")
    settingsPage.saveBtnRect = { x = saveBtnX, y = btnRowY, w = saveBtnW, h = saveBtnH }

    -- 闁稿繑濞婂Λ鎾箰婢舵劖灏?
    local closeBtnX = cx + saveBtnW / 2 - closeBtnW / 2 + 10
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, btnRowY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(50, 45, 60, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(closeBtnX + closeBtnW / 2, btnRowY + closeBtnH / 2, "Close")
    settingsPage.closeBtnRect = { x = closeBtnX, y = btnRowY, w = closeBtnW, h = closeBtnH }
end


-- ============================================================================
-- CDK 闁稿繑鍨跺畷鎻掝嚕閸︻厾宕?(濞达綀娉曢弫銈夊储閻旂儤鏅搁梺娆惧枤濞插繑娼忛幘鍐插汲)
-- ============================================================================
function DrawCDKPopup()
    if not cdkState.inputOpen then return end
    local W = DESIGN_W
    local H = DESIGN_H
    -- 闂侇剦鍠氶崓?
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 130)); nvgFill(vg)

    -- 缂佹瘱鍐ㄦ鐎殿喖婀遍悰銉╂閵忊剝绶?
    local pw, ph = 420, 200
    local px = (W - pw) / 2
    local py = (H - ph) / 2 - 80  -- 闁稿绻嬬粭鍌炴晬瀹€鈧划浼村储閻旂儤鏅搁梺娆惧枤濞插繘鎮惧▎鎴旀晞闂?"
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(30, 28, 40, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 闁哄秴娲。?
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(px + pw / 2, py + 24, "Enter Redeem Code")

    -- 閺夊牊鎸搁崣鍡楊浖?"
    local inputX = px + 20
    local inputY = py + 50
    local inputW = pw - 40
    local inputH = 46
    nvgBeginPath(vg); nvgRoundedRect(vg, inputX, inputY, inputW, inputH, 6)
    nvgFillColor(vg, nvgRGBA(15, 14, 22, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 80, 50, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    cdkState.inputBoxRect = { x = inputX, y = inputY, w = inputW, h = inputH }
    -- 閺夊牊鎸搁崣鍡涘棘閸パ呮憻 / 闁告濮崇紞鍛箔?"
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local textY = inputY + inputH / 2
    if #cdkState.inputText > 0 then
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, inputX + 10, textY, cdkState.inputText, nil)
        -- 闁稿繐顦伴悥锝夋⒒椤忓棗鍓?
        if math.floor(os.clock() * 2) % 2 == 0 then
            local tw = nvgTextBounds(vg, 0, 0, cdkState.inputText, nil)
            nvgBeginPath(vg); nvgRect(vg, inputX + 10 + tw + 2, inputY + 8, 2, inputH - 16)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 200)); nvgFill(vg)
        end
    else
        nvgFillColor(vg, nvgRGBA(150, 140, 130, 120))
        nvgText(vg, inputX + 10, textY, "Use the keyboard to enter a redeem code", nil)
        -- 闁稿繐顦伴悥?
        if math.floor(os.clock() * 2) % 2 == 0 then
            nvgBeginPath(vg); nvgRect(vg, inputX + 10, inputY + 8, 2, inputH - 16)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 200)); nvgFill(vg)
        end
    end

    -- 缂備焦鎸婚悘澶愬矗瀹ュ娲?(闁革负鍔忕欢顓㈠礂閵夛富鏀卞☉鎾愁儐閺?
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

    -- ======== 闁圭顦甸幐宕囨偘? 缂侇喗顭堥崚?| 婵炴挸鎳愰埞?| 闁稿繑鍨跺畷?| 闁稿繑濞婂Λ?========
    local btnY = inputY + inputH + 32
    local btnH = 42
    local btnGap = 8
    local btnTotalW = pw - 40
    local btnStartX = px + 20
    -- 4濞戞搩浜濈€垫粓鏌﹂鍏肩秵闁告帒妫楅鏃€鎯?"
    local btnW = math.floor((btnTotalW - btnGap * 3) / 4)

    -- 缂侇喗顭堥崚?
    local pasteX = btnStartX
    nvgBeginPath(vg); nvgRoundedRect(vg, pasteX, btnY, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(50, 80, 120, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 150, 200, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(pasteX + btnW / 2, btnY + btnH / 2, "Paste")
    cdkState.pasteBtnRect = { x = pasteX, y = btnY, w = btnW, h = btnH }

    -- 婵炴挸鎳愰埞?
    local clearX = pasteX + btnW + btnGap
    nvgBeginPath(vg); nvgRoundedRect(vg, clearX, btnY, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 55, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(clearX + btnW / 2, btnY + btnH / 2, "Clear")
    cdkState.clearBtnRect = { x = clearX, y = btnY, w = btnW, h = btnH }

    -- 闁稿繑鍨跺畷?
    local redeemX = clearX + btnW + btnGap
    nvgBeginPath(vg); nvgRoundedRect(vg, redeemX, btnY, btnW, btnH, 6)
    nvgFillPaint(vg, nvgLinearGradient(vg, redeemX, btnY, redeemX, btnY + btnH,
        nvgRGBA(160, 120, 40, 230), nvgRGBA(120, 80, 20, 230)))
    nvgFill(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(redeemX + btnW / 2, btnY + btnH / 2, "Redeem")
    cdkState.redeemBtnRect = { x = redeemX, y = btnY, w = btnW, h = btnH }

    -- 闁稿繑濞婂Λ?
    local closeX = redeemX + btnW + btnGap
    local closeW = btnStartX + btnTotalW - closeX  -- 闁哄牃鍋撻柛姘凹缁斿瓨绋夐鍛樆闂佺瓔鍠栭幃鍡涘箳婢跺绋囬梺?"
    nvgBeginPath(vg); nvgRoundedRect(vg, closeX, btnY, closeW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 55, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(closeX + closeW / 2, btnY + btnH / 2, "Close")
    cdkState.closeBtnRect = { x = closeX, y = btnY, w = closeW, h = btnH }
end

