-- ui/social_mail.lua - 涓夊浗姝︾伒褰?(浠?social.lua 鎷嗗垎)

-- ============================================================================
-- 璐＄尞姒滆鎯呯嫭绔嬬晫闈紙涓庢垬鍔涙帓琛屾鍚屾鏍峰紡锛屾樉绀烘鏁帮級
-- ============================================================================

function DrawContribRankScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0

    -- 1. 缁熶竴鑿滃崟鑳屾櫙
    DrawSocialBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 2. 杩斿洖鎸夐挳
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 杩斿洖")
    menuBtnRects.contribRankBack = { x = backX, y = backY, w = backW, h = backH }

    -- 3. 鏍囬
    nvgFontSize(vg, 39)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 32, "璐＄尞鎺掕姒?)

    nvgFontSize(vg, 25)
    DrawWhiteInkText(cx, 56, "鎰熻阿姣忎竴娆℃敮鎸?)

    -- 4. 鎺掕鍒楄〃鍖哄煙
    local listTop = 76
    local listBottom = H - 12
    local listH = listBottom - listTop
    local secPad = 16
    local secW = W - secPad * 2

    local contribData = welfareState.contribRank
    local contribCount = contribData and #contribData or 0
    local rowH = 56
    local headerH = 44
    local contentH = math.max(listH, headerH + contribCount * rowH + 20)

    -- 婊氬姩鍋忕Щ
    local scrollOff = welfareState.contribDetailScroll.offset
    local minScroll = math.min(0, listH - contentH)
    scrollOff = math.max(minScroll, math.min(0, scrollOff))
    welfareState.contribDetailScroll.offset = scrollOff

    nvgSave(vg)
    nvgScissor(vg, 0, listTop, W, listH)

    local baseY = listTop + scrollOff

    -- 搴曟澘锛堟殩鑹插崐閫忔槑锛屾殫榛戝湴鐗㈤鏍硷級
    nvgBeginPath(vg); nvgRoundedRect(vg, secPad, baseY, secW, contentH, 10)
    nvgFillColor(vg, nvgRGBA(15, 12, 8, 190)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 80)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 琛ㄥご
    local hy = baseY + 8
    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, hy, secW - 12, headerH - 4, 6)
    local headerGrad = nvgLinearGradient(vg, secPad, hy, secPad + secW, hy,
        nvgRGBA(80, 60, 30, 100), nvgRGBA(60, 45, 20, 60))
    nvgFillPaint(vg, headerGrad); nvgFill(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 180, 140, 200))
    nvgText(vg, secPad + 30, hy + headerH / 2 - 2, "鎺掑悕", nil)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgText(vg, secPad + 60, hy + headerH / 2 - 2, "閬撳彿", nil)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg, secPad + secW - 16, hy + headerH / 2 - 2, "娆℃暟", nil)

    -- 琛ㄥご鍒嗛殧绾?
    nvgBeginPath(vg); nvgMoveTo(vg, secPad + 10, hy + headerH - 2); nvgLineTo(vg, secPad + secW - 10, hy + headerH - 2)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    if welfareState.contribLoading and not welfareState.contribLoaded then
        nvgFontSize(vg, 26)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, baseY + listH / 2, "鍔犺浇涓?..")
    elseif contribCount == 0 then
        nvgFontSize(vg, 26)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, baseY + listH / 2, "鏆傛棤鏁版嵁锛屽揩鍘荤湅骞垮憡涓婃鍚э紒")
    else
        local medals = {"[1]", "[2]", "[3]"}
        local rankColors = {
            nvgRGBA(255, 215, 80, 35),   -- 绗?鍚?閲?
            nvgRGBA(210, 210, 220, 25),  -- 绗?鍚?閾?
            nvgRGBA(200, 160, 90, 20),   -- 绗?鍚?閾?
        }
        for i, entry in ipairs(contribData) do
            local ry = baseY + headerH + 8 + (i - 1) * rowH
            -- 鍓?鍚嶆殩閲戦珮浜簳鑹?
            if i <= 3 then
                nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 6)
                nvgFillColor(vg, rankColors[i]); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(180, 145, 60, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
            elseif i % 2 == 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 4)
                nvgFillColor(vg, nvgRGBA(255, 240, 200, 6)); nvgFill(vg)
            end

            -- 鎺掑悕
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if i <= 3 then
                nvgFontSize(vg, 28)
                nvgText(vg, secPad + 30, ry + rowH / 2, medals[i], nil)
            else
                nvgFontSize(vg, 22)
                nvgFillColor(vg, nvgRGBA(180, 165, 130, 200))
                nvgText(vg, secPad + 30, ry + rowH / 2, "#" .. i, nil)
            end

            -- 閬撳彿
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if i <= 3 then
                nvgFillColor(vg, nvgRGBA(255, 235, 175, 240))
            else
                nvgFillColor(vg, nvgRGBA(220, 210, 190, 220))
            end
            nvgText(vg, secPad + 60, ry + rowH / 2, entry.name, nil)

            -- 娆℃暟锛堟殩閲戣壊锛?
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            if i <= 3 then
                nvgFillColor(vg, nvgRGBA(255, 200, 80, 240))
            else
                nvgFillColor(vg, nvgRGBA(220, 180, 100, 210))
            end
            nvgText(vg, secPad + secW - 16, ry + rowH / 2, tostring(entry.count) .. " 娆?, nil)

            -- 琛岄棿鍒嗛殧绾?
            if i < contribCount then
                nvgBeginPath(vg)
                nvgMoveTo(vg, secPad + 20, ry + rowH)
                nvgLineTo(vg, secPad + secW - 20, ry + rowH)
                nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 25))
                nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
            end
        end
    end

    nvgRestore(vg)

    -- 骞藉啣绮掑瓙
    for i = 1, 6 do
        local px = W * (0.1 + 0.8 * ((i * 131 + math.floor(t * 16)) % 100) / 100)
        local py = H * (0.04 + 0.12 * math.sin(t * 0.5 + i * 1.5))
        local pr = 1 + math.sin(t * 1.8 + i) * 0.5
        local pa = math.floor(22 + 16 * math.sin(t * 1.3 + i * 0.9))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(220, 195, 140, pa)); nvgFill(vg)
    end
end


-- ============================================================================
-- 鎴樺姏鎺掕姒滅嫭绔嬬晫闈?
-- ============================================================================

function DrawMailBoxScreen()
    local W, H = DESIGN_W, DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0
    local ms = welfareState.mail

    -- 1. 鑳屾櫙
    DrawSocialBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 2. 杩斿洖鎸夐挳
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 杩斿洖")
    menuBtnRects.mailBack = { x = backX, y = backY, w = backW, h = backH }

    -- 3. 鏍囬 + UID鏄剧ず
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 32, "閭欢")

    -- 鍙充笂瑙掓樉绀虹帺瀹禪ID (鏂逛究绠＄悊鍛樼‘璁よ韩浠?
    local myUid = CloudAPI.GetUserId()
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(100, 100, 110, 140))
    nvgText(vg, W - 10, 6, "UID:" .. tostring(myUid), nil)
    -- 绠＄悊鍛樻爣璇?
    if CloudManager.IsAdmin() then
        nvgFillColor(vg, nvgRGBA(255, 200, 60, 200))
        nvgText(vg, W - 10, 20, "[绠＄悊鍛榏", nil)
    end
    -- 鍏嶅箍鍛婄姸鎬?
    if playerInfo.ad_free then
        nvgFillColor(vg, nvgRGBA(100, 255, 150, 180))
        nvgText(vg, W - 10, CloudManager.IsAdmin() and 34 or 20, "[鍏嶅箍鍛奭", nil)
    end

    -- 4. Tab 鏍? 绯荤粺閭欢 / 鐜╁閭欢 (闈炵鐞嗗憳鍙樉绀虹郴缁熼偖浠?
    local pad = 14
    local tabY = 56
    local tabH = 36
    local isMailAdmin = CloudManager.IsAdmin()
    local tabs
    if isMailAdmin then
        tabs = { { id = "system", label = "绯荤粺閭欢" }, { id = "cloud", label = "鐜╁閭欢" } }
    else
        tabs = { { id = "system", label = "閭欢" } }
        -- 闈炵鐞嗗憳寮哄埗鍒囧埌 system tab
        if ms.tab == "cloud" then ms.tab = "system" end
    end
    -- 浜戦偖浠舵湭璇绘暟
    local cloudUnread = 0
    for _, cm in ipairs(CloudManager._mailInbox or {}) do
        if not CloudManager.IsMailClaimed(cm.id) and #(cm.rewards or {}) > 0 then
            cloudUnread = cloudUnread + 1
        end
    end
    local tabW = (W - pad * 2) / #tabs
    for i, tb in ipairs(tabs) do
        local tx = pad + (i - 1) * tabW
        local sel = (ms.tab == tb.id)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx + 2, tabY, tabW - 4, tabH, 6)
        nvgFillColor(vg, sel and nvgRGBA(90, 60, 30, 220) or nvgRGBA(30, 30, 40, 180)); nvgFill(vg)
        if sel then nvgStrokeColor(vg, nvgRGBA(255, 180, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg) end
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, sel and nvgRGBA(255, 220, 100, 255) or nvgRGBA(180, 180, 180, 200))
        local lbl = tb.label
        if tb.id == "cloud" and cloudUnread > 0 then lbl = lbl .. "(" .. cloudUnread .. ")" end
        -- 闈炵鐞嗗憳鍦ㄩ偖浠禩ab涓婃樉绀烘湭璇讳簯閭欢鏁?
        if not isMailAdmin and tb.id == "system" and cloudUnread > 0 then lbl = lbl .. "(" .. cloudUnread .. ")" end
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, lbl, nil)
        menuBtnRects["mailTab_" .. tb.id] = { x = tx + 2, y = tabY, w = tabW - 4, h = tabH }
    end

    local listTop = tabY + tabH + 8
    local listBottom = H - 12
    local listH = listBottom - listTop
    local cardGap = 10

    -- =============== 绯荤粺閭欢 Tab ===============
    if ms.tab == "system" then
        local mailCardH = 220
        local cloudCardH = 130  -- 浜戦偖浠跺崱鐗囬珮搴?
        ms.btnRects = {}
        if not isMailAdmin then ms.cloudBtnRects = {} end  -- 闈炵鐞嗗憳涔熼渶瑕佷簯閭欢棰嗗彇鎸夐挳

        nvgSave(vg)
        nvgScissor(vg, 0, listTop, W, listH)

        local scrollOff = ms.scroll and ms.scroll.offset or 0
        local mailCount = #welfareState.mailDefs
        local inbox = not isMailAdmin and (CloudManager._mailInbox or {}) or {}
        local contentH = mailCount * (mailCardH + cardGap) - cardGap
        -- 闈炵鐞嗗憳: 绯荤粺閭欢搴曢儴杩藉姞浜戦偖浠?
        if #inbox > 0 then
            contentH = contentH + (mailCount > 0 and cardGap or 0) + #inbox * (cloudCardH + cardGap) - cardGap
        end
        local maxScroll = math.max(0, contentH - listH)
        if ms.scroll then
            if ms.scroll.offset > maxScroll then ms.scroll.offset = maxScroll; ms.scroll.vel = 0 end
            if ms.scroll.offset < 0 then ms.scroll.offset = 0; ms.scroll.vel = 0 end
            scrollOff = ms.scroll.offset
        end

        for i, mail in ipairs(welfareState.mailDefs) do
            local isClaimed = ms.claimed[mail.id] == true
            local cardY = listTop + (i - 1) * (mailCardH + cardGap) - scrollOff
            local cardX = pad
            local cardW = W - pad * 2

            nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, cardW, mailCardH, 10)
            if isClaimed then
                nvgFillColor(vg, nvgRGBA(20, 20, 25, 180)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(60, 60, 70, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            else
                local glow = 0.8 + 0.2 * math.sin(t * 2.5)
                nvgFillColor(vg, nvgRGBA(30, 18, 10, math.floor(210 * glow))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(255, 180, 80, math.floor(140 * glow))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            end

            nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(140, 130, 110, isClaimed and 120 or 200))
            nvgText(vg, cardX + 12, cardY + 8, "鏉ヨ嚜: " .. mail.sender, nil)

            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            if isClaimed then
                nvgFillColor(vg, nvgRGBA(120, 120, 120, 160))
                nvgText(vg, cardX + 12, cardY + 26, mail.title, nil)
            else
                DrawWhiteInkText(cardX + 12, cardY + 26, mail.title)
            end

            nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(190, 180, 170, isClaimed and 100 or 210))
            local contentLines = {}
            local lineLen = 22
            local txt = mail.content
            while #txt > 0 do
                local seg, count, pos = "", 0, 1
                while pos <= #txt and count < lineLen do
                    local b = string.byte(txt, pos)
                    if b >= 0xE0 then
                        seg = seg .. txt:sub(pos, pos + 2); pos = pos + 3
                    elseif b >= 0xC0 then
                        seg = seg .. txt:sub(pos, pos + 1); pos = pos + 2
                    else seg = seg .. txt:sub(pos, pos); pos = pos + 1 end
                    count = count + 1
                end
                contentLines[#contentLines + 1] = seg
                txt = txt:sub(pos)
                if #contentLines >= 5 then break end
            end
            for li, line in ipairs(contentLines) do
                nvgText(vg, cardX + 12, cardY + 54 + (li - 1) * 22, line, nil)
            end

            local rwY = cardY + 54 + #contentLines * 22 + 8
            for ri, rw in ipairs(mail.rewards) do
                local rwX = cardX + 12 + (ri - 1) * 160
                nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(rw.type == "jade" and 255 or 200, rw.type == "jade" and 220 or 160, rw.type == "jade" and 100 or 255, isClaimed and 100 or 230))
                nvgText(vg, rwX, rwY, rw.label, nil)
            end

            local btnW2, btnH2 = 100, 36
            local btnX2 = cardX + cardW - btnW2 - 12
            local btnY2 = cardY + mailCardH - btnH2 - 10
            if isClaimed then
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(100, 100, 100, 140))
                nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "宸查鍙?, nil)
            else
                local bp = 0.85 + 0.15 * math.sin(t * 3.5 + i)
                nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 8)
                nvgFillColor(vg, nvgRGBA(180, 80, 30, math.floor(220 * bp))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(255, 200, 100, math.floor(180 * bp))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "棰嗗彇")
                ms.btnRects[i] = { x = btnX2, y = btnY2, w = btnW2, h = btnH2 }
            end

            if not isClaimed then
                local sparkle = math.sin(t * 4.0 + i * 2.0)
                if sparkle > 0.7 then
                    local sa = math.floor((sparkle - 0.7) / 0.3 * 80)
                    nvgBeginPath(vg); nvgRoundedRect(vg, cardX - 1, cardY - 1, cardW + 2, mailCardH + 2, 11)
                    nvgStrokeColor(vg, nvgRGBA(255, 220, 120, sa)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
                end
            end
        end

        -- 闈炵鐞嗗憳: 绯荤粺閭欢搴曢儴杩藉姞浜戦偖浠?
        if not isMailAdmin and #inbox > 0 then
            local cloudStartY = listTop + mailCount * (mailCardH + cardGap)
            for i, cm in ipairs(inbox) do
                local isClaimed = CloudManager.IsMailClaimed(cm.id)
                local hasRewards = #(cm.rewards or {}) > 0
                local cardY = cloudStartY + (i - 1) * (cloudCardH + cardGap) - scrollOff
                local cardX = pad
                local cardW = W - pad * 2

                nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, cardW, cloudCardH, 10)
                if isClaimed or not hasRewards then
                    nvgFillColor(vg, nvgRGBA(20, 20, 25, 180)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(60, 60, 70, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                else
                    local glow = 0.8 + 0.2 * math.sin(t * 2.5)
                    nvgFillColor(vg, nvgRGBA(20, 25, 40, math.floor(210 * glow))); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100, 160, 255, math.floor(140 * glow))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                end

                -- 骞挎挱鏍囪瘑
                if cm.isBroadcast then
                    nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(255, 180, 60, 180))
                    nvgText(vg, cardX + cardW - 8, cardY + 4, "[鍏ㄦ湇]", nil)
                end

                -- 鍙戜欢浜?+ 鏃堕棿
                nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(140, 140, 160, 180))
                nvgText(vg, cardX + 10, cardY + 6, "鏉ヨ嚜: " .. (cm.fromName or "绯荤粺"), nil)
                local timeStr = ""
                if cm.time and cm.time > 0 then
                    local dt2 = os.time() - cm.time
                    if dt2 < 60 then
                        timeStr = "鍒氬垰"
                    elseif dt2 < 3600 then
                        timeStr = math.floor(dt2 / 60) .. "鍒嗛挓鍓?
                    elseif dt2 < 86400 then
                        timeStr = math.floor(dt2 / 3600) .. "灏忔椂鍓?
                    else timeStr = math.floor(dt2 / 86400) .. "澶╁墠" end
                end
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgText(vg, cardX + cardW - 10, cardY + 6 + (cm.isBroadcast and 14 or 0), timeStr, nil)

                -- 鏍囬
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                if isClaimed or not hasRewards then
                    nvgFillColor(vg, nvgRGBA(160, 160, 170, 180))
                else
                    nvgFillColor(vg, nvgRGBA(220, 230, 255, 240))
                end
                nvgText(vg, cardX + 10, cardY + 24, cm.subject or "(鏃犱富棰?", nil)

                -- 姝ｆ枃棰勮
                nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(160, 160, 170, isClaimed and 100 or 180))
                local bodyPreview = (cm.body or "")
                if #bodyPreview > 60 then bodyPreview = bodyPreview:sub(1, 60) .. "..." end
                nvgText(vg, cardX + 10, cardY + 48, bodyPreview, nil)

                -- 濂栧姳棰勮
                if hasRewards then
                    local rwY2 = cardY + 70
                    for ri, rw in ipairs(cm.rewards) do
                        local rwX = cardX + 10 + (ri - 1) * 140
                        nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                        if rw.type == "jade" then
                            nvgFillColor(vg, nvgRGBA(255, 220, 100, isClaimed and 80 or 220))
                        elseif rw.type == "ad_free" then
                            nvgFillColor(vg, nvgRGBA(100, 255, 150, isClaimed and 80 or 220))
                        else
                            nvgFillColor(vg, nvgRGBA(200, 160, 255, isClaimed and 80 or 220))
                        end
                        nvgText(vg, rwX, rwY2, rw.label or "", nil)
                    end
                end

                -- 棰嗗彇鎸夐挳 / 宸茶鏍囩
                local btnW2, btnH2 = 80, 30
                local btnX2 = cardX + cardW - btnW2 - 10
                local btnY2 = cardY + cloudCardH - btnH2 - 8
                if hasRewards then
                    if isClaimed then
                        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(100, 100, 100, 140))
                        nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "宸查鍙?, nil)
                    else
                        local bp = 0.85 + 0.15 * math.sin(t * 3.5 + i)
                        nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 8)
                        nvgFillColor(vg, nvgRGBA(50, 90, 160, math.floor(220 * bp))); nvgFill(vg)
                        nvgStrokeColor(vg, nvgRGBA(100, 180, 255, math.floor(180 * bp))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                        nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(220, 240, 255, 240))
                        nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "棰嗗彇", nil)
                        ms.cloudBtnRects[i] = { x = btnX2, y = btnY2, w = btnW2, h = btnH2 }
                    end
                end
            end
        end

        if #welfareState.mailDefs == 0 and #inbox == 0 then
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(120, 110, 100, 160))
            nvgText(vg, cx, listTop + listH / 2, "鏆傛棤閭欢", nil)
        end

        nvgRestore(vg)

    -- =============== 鐜╁閭欢 Tab ===============
    elseif ms.tab == "cloud" then
        local mailCardH = 130
        ms.cloudBtnRects = {}
        local inbox = CloudManager._mailInbox or {}

        -- 鍐欎俊鎸夐挳浣嶇疆 (鍏朵粬鎸夐挳涔熶緷璧栬繖浜涘潗鏍?
        local compBtnW, compBtnH = 90, 32
        local compBtnX = W - pad - compBtnW
        local compBtnY = listTop

        -- 绠＄悊鍛樻寜閽紙浠呯鐞嗗憳鏋勫缓鍙锛屼唬鐮佸湪 admin/ 鐩綍锛?
        menuBtnRects.mailCompose = nil
        if IS_ADMIN_BUILD and _AdminMailUI and CloudManager.IsAdmin() then
            _AdminMailUI.DrawAdminMailButtons(W, compBtnX, compBtnY, compBtnW, compBtnH, pad)
        end

        -- 鍒锋柊鎸夐挳
        local refBtnW, refBtnH = 60, 32
        local refBtnX = pad
        nvgBeginPath(vg); nvgRoundedRect(vg, refBtnX, compBtnY, refBtnW, refBtnH, 6)
        nvgFillColor(vg, nvgRGBA(40, 60, 50, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 160, 120, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 220, 180, 220))
        nvgText(vg, refBtnX + refBtnW / 2, compBtnY + refBtnH / 2, "鍒锋柊", nil)
        menuBtnRects.mailRefresh = { x = refBtnX, y = compBtnY, w = refBtnW, h = refBtnH }

        local cloudListTop = compBtnY + compBtnH + 8
        local cloudListH = listBottom - cloudListTop

        nvgSave(vg)
        nvgScissor(vg, 0, cloudListTop, W, cloudListH)

        local scrollOff = ms.scroll and ms.scroll.offset or 0
        local contentH = #inbox * (mailCardH + cardGap) - cardGap
        local maxScroll = math.max(0, contentH - cloudListH)
        if ms.scroll then
            if ms.scroll.offset > maxScroll then ms.scroll.offset = maxScroll; ms.scroll.vel = 0 end
            if ms.scroll.offset < 0 then ms.scroll.offset = 0; ms.scroll.vel = 0 end
            scrollOff = ms.scroll.offset
        end

        for i, cm in ipairs(inbox) do
            local isClaimed = CloudManager.IsMailClaimed(cm.id)
            local hasRewards = #(cm.rewards or {}) > 0
            local cardY = cloudListTop + (i - 1) * (mailCardH + cardGap) - scrollOff
            local cardX = pad
            local cardW = W - pad * 2

            nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, cardW, mailCardH, 10)
            if isClaimed or not hasRewards then
                nvgFillColor(vg, nvgRGBA(20, 20, 25, 180)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(60, 60, 70, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            else
                local glow = 0.8 + 0.2 * math.sin(t * 2.5)
                nvgFillColor(vg, nvgRGBA(20, 25, 40, math.floor(210 * glow))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(100, 160, 255, math.floor(140 * glow))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            end

            -- 骞挎挱鏍囪瘑
            if cm.isBroadcast then
                nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 180, 60, 180))
                nvgText(vg, cardX + cardW - 8, cardY + 4, "[鍏ㄦ湇]", nil)
            end

            -- 鍙戜欢浜?+ 鏃堕棿
            nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(140, 140, 160, 180))
            nvgText(vg, cardX + 10, cardY + 6, "鏉ヨ嚜: " .. (cm.fromName or "鏈煡"), nil)
            -- 鏃堕棿
            local timeStr = ""
            if cm.time and cm.time > 0 then
                local dt2 = os.time() - cm.time
                if dt2 < 60 then
                    timeStr = "鍒氬垰"
                elseif dt2 < 3600 then
                    timeStr = math.floor(dt2 / 60) .. "鍒嗛挓鍓?
                elseif dt2 < 86400 then
                    timeStr = math.floor(dt2 / 3600) .. "灏忔椂鍓?
                else
                    timeStr = math.floor(dt2 / 86400) .. "澶╁墠"
                end
            end
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgText(vg, cardX + cardW - 10, cardY + 6 + (cm.isBroadcast and 14 or 0), timeStr, nil)

            -- 鏍囬
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            if isClaimed or not hasRewards then
                nvgFillColor(vg, nvgRGBA(160, 160, 170, 180))
            else
                nvgFillColor(vg, nvgRGBA(220, 230, 255, 240))
            end
            nvgText(vg, cardX + 10, cardY + 24, cm.subject or "(鏃犱富棰?", nil)

            -- 姝ｆ枃棰勮 (鏈€澶?琛?
            nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(160, 160, 170, isClaimed and 100 or 180))
            local bodyPreview = (cm.body or "")
            if #bodyPreview > 60 then bodyPreview = bodyPreview:sub(1, 60) .. "..." end
            nvgText(vg, cardX + 10, cardY + 48, bodyPreview, nil)

            -- 濂栧姳棰勮
            if hasRewards then
                local rwY2 = cardY + 70
                for ri, rw in ipairs(cm.rewards) do
                    local rwX = cardX + 10 + (ri - 1) * 140
                    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    if rw.type == "jade" then
                        nvgFillColor(vg, nvgRGBA(255, 220, 100, isClaimed and 80 or 220))
                    elseif rw.type == "ad_free" then
                        nvgFillColor(vg, nvgRGBA(100, 255, 150, isClaimed and 80 or 220))
                    else
                        nvgFillColor(vg, nvgRGBA(200, 160, 255, isClaimed and 80 or 220))
                    end
                    nvgText(vg, rwX, rwY2, rw.label or "", nil)
                end
            end

            -- 棰嗗彇鎸夐挳 / 宸茶鏍囩
            local btnW2, btnH2 = 80, 30
            local btnX2 = cardX + cardW - btnW2 - 10
            local btnY2 = cardY + mailCardH - btnH2 - 8
            if hasRewards then
                if isClaimed then
                    nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(100, 100, 100, 140))
                    nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "宸查鍙?, nil)
                else
                    local bp = 0.85 + 0.15 * math.sin(t * 3.5 + i)
                    nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 8)
                    nvgFillColor(vg, nvgRGBA(50, 90, 160, math.floor(220 * bp))); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, math.floor(180 * bp))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                    nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(220, 240, 255, 240))
                    nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "棰嗗彇", nil)
                    ms.cloudBtnRects[i] = { x = btnX2, y = btnY2, w = btnW2, h = btnH2 }
                end
            end
        end

        if #inbox == 0 then
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(120, 120, 140, 160))
            nvgText(vg, cx, cloudListTop + cloudListH / 2, CloudManager._mailLoading and "鍔犺浇涓?.." or "鏆傛棤鐜╁閭欢", nil)
        end

        nvgRestore(vg)
    end

    -- =============== 鍐欎俊寮圭獥 / 绠＄悊闈㈡澘寮圭獥锛堢鐞嗗憳涓撶敤锛屼唬鐮佸湪 admin/ 鐩綍锛?===============
    if IS_ADMIN_BUILD and _AdminMailUI and ms.composing and ms.composeData then
        _AdminMailUI.DrawAdminPopup(W, H, cx, t, ms)
    end

    -- =============== 绯荤粺閭欢纭寮圭獥 ===============
    if ms.confirmPopup and not ms.composing then
        local popup = ms.confirmPopup
        local mail = popup.cloudMail or welfareState.mailDefs[popup.mailIdx]
        if mail then
            nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)

            local pw, ph = 380, 280
            local px, py = cx - pw / 2, H / 2 - ph / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 14)
            nvgFillColor(vg, nvgRGBA(25, 20, 15, 240)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 160, 80, 160)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
            popup.bgRect = { x = px, y = py, w = pw, h = ph }

            local popTitle = popup.cloudMail and (mail.subject or "棰嗗彇") or mail.title
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, py + 30, "棰嗗彇: " .. popTitle)

            local rewards = popup.cloudMail and (mail.rewards or {}) or (mail.rewards or {})
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            local ry0 = py + 60
            for ri, rw in ipairs(rewards) do
                if rw.type == "jade" then
                    nvgFillColor(vg, nvgRGBA(255, 220, 100, 240))
                elseif rw.type == "ad_free" then
                    nvgFillColor(vg, nvgRGBA(100, 255, 150, 240))
                else
                    nvgFillColor(vg, nvgRGBA(200, 160, 255, 240))
                end
                nvgText(vg, cx, ry0 + (ri - 1) * 30, rw.label or "", nil)
            end

            if not popup.cloudMail then
                nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(160, 150, 130, 180))
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgText(vg, cx, ry0 + #rewards * 30 + 16, "姝︽妧娈嬬墖灏嗗垎閰嶇粰姣忎釜宸插紑鏀剧殑姝︽妧", nil)
            end

            local cbW, cbH = 140, 42
            local cbX = cx - cbW / 2
            local cbY = py + ph - cbH - 20
            local cbP = 0.85 + 0.15 * math.sin(t * 3.0)
            nvgBeginPath(vg); nvgRoundedRect(vg, cbX, cbY, cbW, cbH, 8)
            nvgFillColor(vg, nvgRGBA(180, 80, 30, math.floor(230 * cbP))); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 200, 100, math.floor(180 * cbP))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cbX + cbW / 2, cbY + cbH / 2, "纭棰嗗彇")
            popup.confirmBtnRect = { x = cbX, y = cbY, w = cbW, h = cbH }

            local clR = 16
            local clX = px + pw - 25
            local clY = py + 20
            nvgBeginPath(vg); nvgCircle(vg, clX, clY, clR)
            nvgFillColor(vg, nvgRGBA(60, 50, 40, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(160, 140, 110, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
            nvgText(vg, clX, clY, "X", nil)
            popup.closeBtnRect = { x = clX - clR, y = clY - clR, w = clR * 2, h = clR * 2 }
        end
    end
end



