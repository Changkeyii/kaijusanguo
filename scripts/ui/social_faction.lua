-- ui/social_faction.lua - 涓夊浗姝︾伒褰?(浠?social.lua 鎷嗗垎)
function DrawFactionSubView(W, H, bodyTop, pad, cx, info)
    local sv = factionUI.subView
    -- 瀛愯鍥捐繑鍥炴寜閽?
    local sbW, sbH = 80, 32
    local sbX, sbY = pad, bodyTop + 4
    nvgBeginPath(vg); nvgRoundedRect(vg, sbX, sbY, sbW, sbH, 6)
    nvgFillColor(vg, nvgRGBA(40, 40, 55, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 100, 140, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 240))
    nvgText(vg, sbX + sbW / 2, sbY + sbH / 2, "< 杩斿洖", nil)
    menuBtnRects.factionSubBack = { x = sbX, y = sbY, w = sbW, h = sbH }

    local panelTop = sbY + sbH + 12
    local panelW = W - pad * 2

    if sv == "upgrade" then
        -- ======== 闃佃惀鍗囩骇 ========
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
        nvgText(vg, cx, panelTop, "闃佃惀鍗囩骇", nil)
        panelTop = panelTop + 36

        local lvInfo = CloudManager.GetFactionLevelInfo()

        -- 绛夌骇鍗＄墖
        local cardH = 180
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, panelTop, panelW, cardH, 10)
        nvgFillColor(vg, nvgRGBA(20, 20, 30, 210)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 140, 220, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 澶х瓑绾ф暟瀛?
        nvgFontSize(vg, 48); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 200, 255, 255))
        nvgText(vg, cx, panelTop + 40, "Lv." .. lvInfo.level, nil)

        -- 绛夌骇鍚嶇О
        local lvNames = { "鏂扮珛", "鍒濆缓", "宕涜捣", "澹ぇ", "鍏寸洓", "榧庣洓", "寮虹洓", "闇镐笟", "鑷冲皧", "鏃犲弻" }
        nvgFontSize(vg, 16); nvgFillColor(vg, nvgRGBA(255, 220, 140, 220))
        nvgText(vg, cx, panelTop + 70, lvNames[lvInfo.level] or "鏈煡", nil)

        -- 缁忛獙杩涘害鏉?
        local barX = pad + 20
        local barW = panelW - 40
        local barY = panelTop + 95
        local barH = 18
        local expRange = lvInfo.nextLevelExp - lvInfo.curLevelExp
        local expProg = expRange > 0 and math.min(1.0, (lvInfo.exp - lvInfo.curLevelExp) / expRange) or 1.0
        if lvInfo.level >= lvInfo.maxLevel then expProg = 1.0 end
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 5)
        nvgFillColor(vg, nvgRGBA(15, 15, 25, 200)); nvgFill(vg)
        if expProg > 0 then
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW * expProg, barH, 5)
            nvgFillColor(vg, nvgRGBA(60, 160, 255, 220)); nvgFill(vg)
        end
        nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        local expStr = lvInfo.level >= lvInfo.maxLevel and "缁忛獙 MAX" or ("缁忛獙 " .. lvInfo.exp .. " / " .. lvInfo.nextLevelExp)
        nvgText(vg, barX + barW / 2, barY + barH / 2, expStr, nil)

        -- 绛夌骇鍔犳垚璇存槑
        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 200))
        local roleBonus = lvInfo.roleBonusPercent or 0
        if roleBonus > 0 then
            nvgText(vg, cx, panelTop + 124, "褰撳墠鍔犳垚: 鍏ㄥ憳 +" .. lvInfo.buffPercent .. "% | 鑱屼綅棰濆 +" .. string.format("%.1f", roleBonus) .. "%", nil)
        else
            nvgText(vg, cx, panelTop + 124, "褰撳墠鍔犳垚: 鍏ㄥ憳鎴樺姏 +" .. lvInfo.buffPercent .. "%", nil)
        end

        -- 涓嬬骇棰勮
        if lvInfo.level < lvInfo.maxLevel then
            nvgFontSize(vg, 13); nvgFillColor(vg, nvgRGBA(160, 160, 170, 180))
            nvgText(vg, cx, panelTop + 148, "涓嬩竴绾?Lv." .. (lvInfo.level + 1) .. ": 鍏ㄥ憳鎴樺姏 +" .. ((lvInfo.level + 1) * 2) .. "%", nil)
        else
            nvgFontSize(vg, 13); nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
            nvgText(vg, cx, panelTop + 148, "宸茶揪鏈€楂樼瓑绾?", nil)
        end

        -- 鍗囩骇鏂瑰紡鎻愮ず
        nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 190, 170, 180))
        nvgText(vg, cx, panelTop + cardH + 16, "閫氳繃銆岄樀钀ユ崘鐚€嶇Н绱粡楠屾潵鍗囩骇", nil)

        -- 璧勯噾缁熻
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 220, 140, 220))
        nvgText(vg, cx, panelTop + cardH + 44, "闃佃惀璧勯噾: " .. CloudManager.GetFactionFunds() .. " 铏庣", nil)

        -- 闃佃惀鎺掕姒滄寜閽?
        local rankBtnW, rankBtnH = 160, 38
        local rankBtnX = cx - rankBtnW / 2
        local rankBtnY = panelTop + cardH + 72
        nvgBeginPath(vg); nvgRoundedRect(vg, rankBtnX, rankBtnY, rankBtnW, rankBtnH, 8)
        nvgFillColor(vg, nvgRGBA(50, 40, 80, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(140, 120, 220, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 255, 240))
        nvgText(vg, cx, rankBtnY + rankBtnH / 2, "闃佃惀绛夌骇鎺掕姒?, nil)
        menuBtnRects.factionRankBtn = { x = rankBtnX, y = rankBtnY, w = rankBtnW, h = rankBtnH }

    elseif sv == "donate" then
        -- ======== 闃佃惀鎹愮尞 ========
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
        nvgText(vg, cx, panelTop, "闃佃惀鎹愮尞", nil)
        panelTop = panelTop + 36

        local cardH = 260
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, panelTop, panelW, cardH, 10)
        nvgFillColor(vg, nvgRGBA(20, 20, 30, 210)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        local donateConf = CloudManager.GetDonateConfig()
        local todayDone = CloudManager.GetTodayDonation()
        local myContrib = CloudManager.GetMyContribution()
        local myJade = playerInfo.jade or 0

        -- 涓汉淇℃伅
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local iy = panelTop + 16
        nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
        nvgText(vg, pad + 16, iy, "鎴戠殑铏庣:", nil)
        nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
        nvgText(vg, pad + 120, iy, tostring(myJade), nil)

        iy = iy + 28
        nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
        nvgText(vg, pad + 16, iy, "绱璐＄尞:", nil)
        nvgFillColor(vg, nvgRGBA(255, 220, 140, 240))
        nvgText(vg, pad + 120, iy, tostring(myContrib), nil)

        iy = iy + 28
        nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
        nvgText(vg, pad + 16, iy, "浠婃棩宸叉崘:", nil)
        nvgFillColor(vg, nvgRGBA(200, 200, 210, 240))
        nvgText(vg, pad + 120, iy, tostring(todayDone) .. " 铏庣", nil)

        -- 鎹愮尞棰濆害閫夋嫨
        iy = iy + 40
        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
        nvgText(vg, cx, iy, "閫夋嫨鎹愮尞鏁伴噺", nil)
        iy = iy + 24

        local amounts = { 100, 300, 500, 1000 }
        local aBtnW = math.floor((panelW - 48) / #amounts)
        local aBtnH = 36
        for ai, amt in ipairs(amounts) do
            local ax = pad + 12 + (ai - 1) * (aBtnW + 8)
            local isSel = (factionUI.donateAmount == amt)
            nvgBeginPath(vg); nvgRoundedRect(vg, ax, iy, aBtnW, aBtnH, 6)
            if isSel then
                nvgFillColor(vg, nvgRGBA(80, 120, 60, 230)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(160, 220, 80, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            else
                nvgFillColor(vg, nvgRGBA(40, 40, 55, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 80, 100, 150)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            end
            nvgFontSize(vg, 15)
            nvgFillColor(vg, isSel and nvgRGBA(220, 255, 180, 255) or nvgRGBA(200, 200, 210, 220))
            nvgText(vg, ax + aBtnW / 2, iy + aBtnH / 2, tostring(amt), nil)
            menuBtnRects["factionDonateAmt_" .. ai] = { x = ax, y = iy, w = aBtnW, h = aBtnH, amount = amt }
        end

        -- 鎹愮尞鎸夐挳
        iy = iy + aBtnH + 20
        local dBtnW, dBtnH = 180, 44
        local dBtnX = cx - dBtnW / 2
        local canDonate = myJade >= factionUI.donateAmount and not factionUI.donating
        nvgBeginPath(vg); nvgRoundedRect(vg, dBtnX, iy, dBtnW, dBtnH, 8)
        nvgFillColor(vg, canDonate and nvgRGBA(60, 120, 40, 230) or nvgRGBA(50, 50, 50, 200)); nvgFill(vg)
        nvgStrokeColor(vg, canDonate and nvgRGBA(140, 220, 80, 180) or nvgRGBA(80, 80, 80, 120)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, canDonate and nvgRGBA(255, 255, 230, 255) or nvgRGBA(120, 120, 120, 200))
        local donateLabel = factionUI.donating and "鎹愮尞涓?.." or ("鎹愮尞 " .. factionUI.donateAmount .. " 铏庣")
        nvgText(vg, cx, iy + dBtnH / 2, donateLabel, nil)
        if canDonate then
            menuBtnRects.factionDonate = { x = dBtnX, y = iy, w = dBtnW, h = dBtnH }
        end

    elseif sv == "announce" then
        -- ======== 闃佃惀鍏憡 ========
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
        nvgText(vg, cx, panelTop, "闃佃惀鍏憡", nil)
        panelTop = panelTop + 36

        local cardH = 220
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, panelTop, panelW, cardH, 10)
        nvgFillColor(vg, nvgRGBA(20, 20, 30, 210)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        local currentAnn = CloudManager.GetFactionAnnouncement()
        local myLevel = CloudManager.GetRoleLevel(info.role)
        local canEdit = myLevel >= CloudManager.GetRoleLevel("vice_leader")

        -- 褰撳墠鍏憡鏄剧ず
        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
        nvgText(vg, pad + 16, panelTop + 16, "褰撳墠鍏憡:", nil)

        nvgFontSize(vg, 16)
        nvgFillColor(vg, nvgRGBA(255, 240, 210, 230))
        local dispAnn = (#currentAnn > 0) and currentAnn or "(鏆傛棤鍏憡)"
        -- 鑷姩鎶樿鏄剧ず鍏憡
        nvgTextBox(vg, pad + 16, panelTop + 42, panelW - 32, dispAnn, nil)

        if canEdit then
            -- 缂栬緫鍖?
            local editY = panelTop + 110
            nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
            nvgFontSize(vg, 14)
            nvgText(vg, pad + 16, editY, "缂栬緫鏂板叕鍛?(200瀛楀唴):", nil)

            -- 杈撳叆妗?
            local inputY = editY + 22
            local inputH = 36
            nvgBeginPath(vg); nvgRoundedRect(vg, pad + 12, inputY, panelW - 24, inputH, 6)
            nvgFillColor(vg, nvgRGBA(10, 10, 18, 200)); nvgFill(vg)
            nvgStrokeColor(vg, factionUI.inputTarget == "announce" and nvgRGBA(200, 180, 80, 200) or nvgRGBA(80, 70, 60, 150))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if #factionUI.announceInput > 0 then
                nvgFillColor(vg, nvgRGBA(255, 240, 210, 240))
                nvgText(vg, pad + 18, inputY + inputH / 2, factionUI.announceInput, nil)
            else
                nvgFillColor(vg, nvgRGBA(120, 115, 100, 150))
                nvgText(vg, pad + 18, inputY + inputH / 2, "鐐瑰嚮杈撳叆鍏憡鍐呭...", nil)
            end
            menuBtnRects.factionAnnounceInput = { x = pad + 12, y = inputY, w = panelW - 24, h = inputH }

            -- 淇濆瓨鎸夐挳
            local saveBtnW, saveBtnH = 140, 40
            local saveBtnX = cx - saveBtnW / 2
            local saveBtnY = inputY + inputH + 14
            nvgBeginPath(vg); nvgRoundedRect(vg, saveBtnX, saveBtnY, saveBtnW, saveBtnH, 8)
            nvgFillColor(vg, nvgRGBA(60, 100, 140, 230)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 160, 220, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 240, 255))
            nvgText(vg, saveBtnX + saveBtnW / 2, saveBtnY + saveBtnH / 2, "淇濆瓨鍏憡", nil)
            menuBtnRects.factionAnnounceSave = { x = saveBtnX, y = saveBtnY, w = saveBtnW, h = saveBtnH }
        else
            nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(160, 150, 140, 180))
            nvgText(vg, cx, panelTop + 130, "鍓洘涓诲強浠ヤ笂鍙紪杈戝叕鍛?, nil)
        end

    elseif sv == "contrib" then
        -- ======== 鎴愬憳璐＄尞鎺掕 ========
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
        nvgText(vg, cx, panelTop, "鎴愬憳璐＄尞鎺掕", nil)
        panelTop = panelTop + 36

        -- 鍔犺浇璐＄尞鏁版嵁
        if not factionUI.contribLoaded and not factionUI.contribLoading then
            factionUI.contribLoading = true
            local rawList = CloudManager.GetContributionRank()
            if #rawList > 0 then
                local uids = {}
                for _, e in ipairs(rawList) do table.insert(uids, e.uid) end
                GetUserNickname({
                    userIds = uids,
                    onSuccess = function(nicknames)
                        local nameMap = {}
                        for _, ni in ipairs(nicknames) do nameMap[ni.userId] = ni.nickname end
                        for _, e in ipairs(rawList) do
                            e.name = nameMap[e.uid] or ("鐜╁" .. tostring(e.uid))
                        end
                        factionUI.contribList = rawList; factionUI.contribLoaded = true; factionUI.contribLoading = false
                    end,
                    onError = function()
                        for _, e in ipairs(rawList) do e.name = "鐜╁" .. tostring(e.uid) end
                        factionUI.contribList = rawList; factionUI.contribLoaded = true; factionUI.contribLoading = false
                    end,
                })
            else
                factionUI.contribList = {}; factionUI.contribLoaded = true; factionUI.contribLoading = false
            end
        end

        local listH2 = H - panelTop - 20
        local rowH2 = 44
        local cList = factionUI.contribList or {}
        local cCount = #cList
        local contentH2 = math.max(listH2, cCount * rowH2 + 20)

        local scrollOff2 = factionUI.contribScroll.offset
        local minScroll2 = math.min(0, listH2 - contentH2)
        scrollOff2 = math.max(minScroll2, math.min(0, scrollOff2))
        factionUI.contribScroll.offset = scrollOff2

        nvgSave(vg)
        nvgScissor(vg, 0, panelTop, W, listH2)
        local baseY2 = panelTop + scrollOff2

        nvgBeginPath(vg); nvgRoundedRect(vg, pad, baseY2, panelW, contentH2, 10)
        nvgFillColor(vg, nvgRGBA(15, 15, 25, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 80, 40, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        if factionUI.contribLoading then
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 180, 190, 200))
            nvgText(vg, cx, baseY2 + listH2 / 2, "鍔犺浇涓?..", nil)
        elseif cCount == 0 then
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 180, 190, 200))
            nvgText(vg, cx, baseY2 + listH2 / 2, "鏆傛棤璐＄尞鏁版嵁", nil)
        else
            local myUid = CloudAPI.GetUserId()
            local medals = {"[1]", "[2]", "[3]"}
            for i, e in ipairs(cList) do
                local ry = baseY2 + 10 + (i - 1) * rowH2
                local isMe = (e.uid == myUid)
                -- 琛岃儗鏅?
                if i <= 3 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, pad + 6, ry + 2, panelW - 12, rowH2 - 4, 6)
                    nvgFillColor(vg, nvgRGBA(255, 215, 80, 15 + (4 - i) * 8)); nvgFill(vg)
                elseif isMe then
                    nvgBeginPath(vg); nvgRoundedRect(vg, pad + 6, ry + 2, panelW - 12, rowH2 - 4, 6)
                    nvgFillColor(vg, nvgRGBA(80, 140, 255, 20)); nvgFill(vg)
                elseif i % 2 == 0 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, pad + 6, ry + 2, panelW - 12, rowH2 - 4, 4)
                    nvgFillColor(vg, nvgRGBA(255, 240, 200, 5)); nvgFill(vg)
                end
                -- 鎺掑悕
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFontSize(vg, 24)
                    nvgFillColor(vg, nvgRGBA(255, 215, 80, 255))
                    nvgText(vg, pad + 28, ry + rowH2 / 2, medals[i], nil)
                else
                    nvgFontSize(vg, 18)
                    nvgFillColor(vg, nvgRGBA(180, 170, 150, 200))
                    nvgText(vg, pad + 28, ry + rowH2 / 2, "#" .. i, nil)
                end
                -- 鍚嶅瓧
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if isMe then
                    nvgFillColor(vg, nvgRGBA(120, 200, 255, 240))
                elseif i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 235, 175, 230))
                else nvgFillColor(vg, nvgRGBA(210, 200, 180, 220)) end
                nvgText(vg, pad + 54, ry + rowH2 / 2, (e.name or "?") .. (isMe and " (鎴?" or ""), nil)
                -- 璐＄尞鍊?
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 200, 80, 240))
                else nvgFillColor(vg, nvgRGBA(220, 180, 120, 210)) end
                nvgText(vg, pad + panelW - 16, ry + rowH2 / 2, FormatPower(e.amount or 0), nil)
                -- 鍒嗛殧绾?
                if i < cCount then
                    nvgBeginPath(vg); nvgMoveTo(vg, pad + 16, ry + rowH2); nvgLineTo(vg, pad + panelW - 16, ry + rowH2)
                    nvgStrokeColor(vg, nvgRGBA(100, 80, 40, 30)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                end
            end
        end
        nvgRestore(vg)
    end
end


-- ===========================
-- 闃佃惀鐣岄潰 (瀹屾暣瀹炵幇)
-- ===========================
function DrawFactionScreen()
    local W, H = DESIGN_W, DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0
    DrawSocialBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 姣忓抚娓呴櫎鎵€鏈夐樀钀?tab 鍐呯殑鎸夐挳 rect锛岄槻姝㈠垏鎹?tab 鏃舵棫鎸夐挳娈嬬暀瀵艰嚧鐐瑰嚮绌块€?
    local factionRectPrefixes = {
        "factionRename", "factionLeave", "factionFeat_",
        "factionKick_", "factionSetRole_", "factionRoleOption_", "factionRolePopupBg",
        "factionAccept_", "factionReject_",
        "factionChatInput", "factionChatSend", "factionChatAddFriend", "factionChatPopupArea",
        "factionRefreshApply", "factionApply_",
        "factionNameInput", "factionDescInput", "factionCreate",
        "factionRenameInput", "factionRenameYes", "factionRenameNo",
        "factionPopupYes", "factionPopupNo",
        "factionDonate", "factionDonateAmt_", "factionAnnounceInput", "factionAnnounceSave",
        "factionSubBack", "factionRankBtn", "factionRankClose", "factionRankOverlay",
    }
    local keysToRemove = {}
    for k, _ in pairs(menuBtnRects) do
        for _, prefix in ipairs(factionRectPrefixes) do
            if k == prefix or (string.sub(prefix, -1) == "_" and string.sub(k, 1, #prefix) == prefix) then
                keysToRemove[#keysToRemove + 1] = k
                break
            end
        end
    end
    for _, k in ipairs(keysToRemove) do menuBtnRects[k] = nil end

    -- 杩斿洖鎸夐挳
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 杩斿洖")
    menuBtnRects.factionBack = { x = backX, y = backY, w = backW, h = backH }

    -- 鏍囬
    nvgFontSize(vg, 30); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 32, "闃佃惀")

    local info = CloudManager.GetFactionInfo()
    local hasFaction = info and info.id and info.id > 0
    local contentTop = 64
    local pad = 14

    if hasFaction then
        -- ======== 宸插姞鍏ラ樀钀?========
        -- Tab 鏍? 淇℃伅 | 鎴愬憳
        local tabs = { { id = "info", label = "淇℃伅" }, { id = "members", label = "鎴愬憳" }, { id = "chat", label = "鑱婂ぉ" } }
        -- 鏈夌鐞嗘潈闄愭椂澧炲姞鐢宠鏍囩
        local myLevel = CloudManager.GetRoleLevel(info.role)
        if myLevel >= 5 then
            table.insert(tabs, { id = "apply", label = "鐢宠" })
        end
        local tabW = (W - pad * 2) / #tabs
        local tabH = 38
        local tabY = contentTop
        for i, tb in ipairs(tabs) do
            local tx = pad + (i - 1) * tabW
            local sel = (factionUI.tab == tb.id)
            nvgBeginPath(vg); nvgRoundedRect(vg, tx + 2, tabY, tabW - 4, tabH, 6)
            nvgFillColor(vg, sel and nvgRGBA(90, 60, 30, 220) or nvgRGBA(30, 30, 40, 180)); nvgFill(vg)
            if sel then nvgStrokeColor(vg, nvgRGBA(255, 180, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg) end
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, sel and nvgRGBA(255, 220, 100, 255) or nvgRGBA(180, 180, 180, 200))
            nvgText(vg, tx + tabW / 2, tabY + tabH / 2, tb.label, nil)
            menuBtnRects["factionTab_" .. tb.id] = { x = tx + 2, y = tabY, w = tabW - 4, h = tabH }
        end

        local bodyTop = tabY + tabH + 10

        if factionUI.tab == "info" then
            -- 鐩熶富棣栨鎵撳紑淇℃伅椤垫椂锛屽悗鍙伴獙璇佹垚鍛樻槸鍚﹀凡绂诲紑锛堣嚜鍔ㄦ竻鐞哻amp_meta锛?
            if info.role == "leader" and not factionUI.memberValidated then
                factionUI.memberValidated = true
                CloudManager.GetFactionMembers(function(_) end)  -- 瑙﹀彂鍐呴儴娓呯悊閫昏緫
            end
            -- 寮傛鏌ヨ鐩熶富鏄电О (浠呮煡涓€娆?
            if info.meta and info.meta.leaderId and not factionUI.leaderNickLoaded then
                factionUI.leaderNickLoaded = true
                factionUI.leaderNickname = nil
                if rawget(_G, "GetUserNickname") then
                    GetUserNickname({
                        userIds = { info.meta.leaderId },
                        onSuccess = function(nicknames)
                            if nicknames and #nicknames > 0 then
                                factionUI.leaderNickname = nicknames[1].nickname or "鏈煡"
                            end
                        end,
                        onError = function() end,
                    })
                end
            end

            -- 闃佃惀鍚嶇О
            nvgFontSize(vg, 28); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
            nvgText(vg, cx, bodyTop + 20, info.name or "鏈煡闃佃惀", nil)
            -- 鐩熶富鏀瑰悕鎸夐挳
            if info.role == "leader" then
                local rnBtnW, rnBtnH = 48, 24
                local nameTextW = nvgTextBounds(vg, 0, 0, info.name or "鏈煡闃佃惀", nil)
                local rnBtnX = cx + nameTextW / 2 + 8
                local rnBtnY = bodyTop + 20 - rnBtnH / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, rnBtnX, rnBtnY, rnBtnW, rnBtnH, 4)
                nvgFillColor(vg, nvgRGBA(60, 55, 40, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 160)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 220, 130, 230))
                nvgText(vg, rnBtnX + rnBtnW / 2, rnBtnY + rnBtnH / 2, "鏀瑰悕", nil)
                menuBtnRects.factionRename = { x = rnBtnX, y = rnBtnY, w = rnBtnW, h = rnBtnH }
            end

            -- ======== 瀛愯鍥? 鍗囩骇/鎹愮尞/鍏憡 ========
            if factionUI.subView then
                DrawFactionSubView(W, H, bodyTop, pad, cx, info)
            else
            -- 闃佃惀淇℃伅鍗＄墖
            local lvInfo = CloudManager.GetFactionLevelInfo()
            local cardY = bodyTop + 50
            local cardH = 230
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cardY, W - pad * 2, cardH, 10)
            nvgFillColor(vg, nvgRGBA(20, 20, 30, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 60, 40, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            local leaderDisplay = factionUI.leaderNickname or "鍔犺浇涓?.."
            local roleBonus2 = lvInfo.roleBonusPercent or 0
            local buffDisplay = "鎴樺姏+" .. lvInfo.buffPercent .. "%"
            if roleBonus2 > 0 then
                buffDisplay = buffDisplay .. " +鑱屼綅" .. string.format("%.1f", roleBonus2) .. "%"
            end
            local infoLines = {
                { "闃佃惀绛夌骇", "Lv." .. lvInfo.level .. " (" .. buffDisplay .. ")" },
                { "鎴戠殑鑱屼綅", CloudManager.GetRoleName(info.role) or "鎴愬憳" },
                { "鎴愬憳鏁?, info.meta and tostring(info.meta.memberCount or 0) .. "/" .. tostring(info.meta.maxMembers or 20) or "?" },
                { "闃佃惀璧勯噾", tostring(CloudManager.GetFactionFunds()) .. " 铏庣" },
                { "鐩熶富", leaderDisplay },
            }
            if info.meta and info.meta.desc and #info.meta.desc > 0 then
                table.insert(infoLines, { "绠€浠?, info.meta.desc })
            end
            for j, line in ipairs(infoLines) do
                local ly = cardY + 14 + (j - 1) * 30
                nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
                nvgText(vg, pad + 16, ly, line[1] .. ":", nil)
                nvgFillColor(vg, nvgRGBA(255, 240, 210, 240))
                nvgText(vg, pad + 110, ly, line[2], nil)
            end

            -- 缁忛獙鏉?(绱ц创淇℃伅琛屼笅鏂?
            local expBarY = cardY + 14 + #infoLines * 30 + 4
            local expBarX = pad + 16
            local expBarW = W - pad * 2 - 32
            local expBarH = 14
            local expRange = lvInfo.nextLevelExp - lvInfo.curLevelExp
            local expProgress = expRange > 0 and math.min(1.0, (lvInfo.exp - lvInfo.curLevelExp) / expRange) or 1.0
            if lvInfo.level >= lvInfo.maxLevel then expProgress = 1.0 end
            -- 鑳屾櫙
            nvgBeginPath(vg); nvgRoundedRect(vg, expBarX, expBarY, expBarW, expBarH, 4)
            nvgFillColor(vg, nvgRGBA(15, 15, 25, 200)); nvgFill(vg)
            -- 濉厖
            if expProgress > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, expBarX, expBarY, expBarW * expProgress, expBarH, 4)
                nvgFillColor(vg, nvgRGBA(80, 180, 255, 200)); nvgFill(vg)
            end
            -- 缁忛獙鏂囧瓧
            nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
            local expText = lvInfo.level >= lvInfo.maxLevel and "MAX" or (lvInfo.exp .. "/" .. lvInfo.nextLevelExp)
            nvgText(vg, expBarX + expBarW / 2, expBarY + expBarH / 2, expText, nil)

            -- 鍏憡鏄剧ず
            local annText = CloudManager.GetFactionAnnouncement()
            local annY = cardY + cardH + 8
            if annText and #annText > 0 then
                nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 200, 80, 180))
                nvgText(vg, pad + 6, annY, "鍏憡:", nil)
                nvgFillColor(vg, nvgRGBA(230, 225, 210, 200))
                nvgText(vg, pad + 52, annY, annText, nil)
                annY = annY + 22
            end

            -- 閫€鍑洪樀钀ユ寜閽?
            local leaveW, leaveH = 160, 42
            local leaveX = cx - leaveW / 2
            local leaveY = annY + 10
            nvgBeginPath(vg); nvgRoundedRect(vg, leaveX, leaveY, leaveW, leaveH, 8)
            nvgFillColor(vg, nvgRGBA(120, 30, 30, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 60, 60, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
            nvgText(vg, cx, leaveY + leaveH / 2, info.role == "leader" and "瑙ｆ暎闃佃惀" or "閫€鍑洪樀钀?, nil)
            menuBtnRects.factionLeave = { x = leaveX, y = leaveY, w = leaveW, h = leaveH }

            -- ======== 闃佃惀鍔熻兘鍏ュ彛缃戞牸 ========
            local featureTop = leaveY + leaveH + 18
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 180, 140, 200))
            nvgText(vg, pad + 4, featureTop, "闃佃惀鍔熻兘", nil)
            featureTop = featureTop + 26

            local hasSignedIn = CloudManager.HasSignedInToday()
            local features = {
                { id = "manage",   icon = "馃憫", label = "鎴愬憳绠＄悊", ready = true },
                { id = "chat",     icon = "馃挰", label = "闃佃惀鑱婂ぉ", ready = true },
                { id = "upgrade",  icon = "猬?, label = "闃佃惀鍗囩骇", ready = true },
                { id = "donate",   icon = "馃挵", label = "闃佃惀鎹愮尞", ready = true },
                { id = "signIn",   icon = "馃搮", label = hasSignedIn and "宸茬鍒? or "姣忔棩绛惧埌", ready = true, done = hasSignedIn },
                { id = "announce", icon = "馃摙", label = "闃佃惀鍏憡", ready = true },
                { id = "rank",     icon = "馃弳", label = "闃佃惀鎺掕", ready = true },
                { id = "contrib",  icon = "馃搳", label = "鎴愬憳璐＄尞", ready = true },
                { id = "shop",     icon = "馃彧", label = "闃佃惀鍟嗗簵" },
                { id = "war",      icon = "鈿?, label = "闃佃惀鎴樹簤" },
                { id = "task",     icon = "馃搵", label = "闃佃惀浠诲姟" },
            }
            local cols = 4
            local fGap = 8
            local fBtnW = math.floor((W - pad * 2 - fGap * (cols - 1)) / cols)
            local fBtnH = 65
            for fi, feat in ipairs(features) do
                local col = (fi - 1) % cols
                local row = math.floor((fi - 1) / cols)
                local fx = pad + col * (fBtnW + fGap)
                local fy = featureTop + row * (fBtnH + fGap)
                -- 鑳屾櫙
                nvgBeginPath(vg); nvgRoundedRect(vg, fx, fy, fBtnW, fBtnH, 8)
                if feat.done then
                    nvgFillColor(vg, nvgRGBA(35, 50, 35, 220)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(80, 160, 80, 130)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                elseif feat.ready then
                    nvgFillColor(vg, nvgRGBA(40, 45, 60, 220)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100, 140, 200, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                else
                    nvgFillColor(vg, nvgRGBA(30, 30, 40, 200)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(70, 60, 50, 130)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                end
                -- 鍥炬爣
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if feat.done then
                    nvgFillColor(vg, nvgRGBA(120, 200, 120, 180))
                elseif feat.ready then
                    nvgFillColor(vg, nvgRGBA(120, 200, 255, 240))
                else nvgFillColor(vg, nvgRGBA(255, 220, 120, 220)) end
                nvgText(vg, fx + fBtnW / 2, fy + fBtnH / 2 - 10, feat.icon, nil)
                -- 鏂囧瓧
                nvgFontSize(vg, 13)
                if feat.done then
                    nvgFillColor(vg, nvgRGBA(150, 200, 150, 200))
                elseif feat.ready then
                    nvgFillColor(vg, nvgRGBA(220, 230, 240, 240))
                else nvgFillColor(vg, nvgRGBA(180, 175, 160, 200)) end
                nvgText(vg, fx + fBtnW / 2, fy + fBtnH / 2 + 16, feat.label, nil)
                -- "寰呭紑鍙?瑙掓爣锛堜粎鏈氨缁殑鍔熻兘锛?
                if not feat.ready then
                    nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(255, 120, 60, 180))
                    nvgText(vg, fx + fBtnW - 4, fy + 3, "寰呭紑鍙?, nil)
                end
                -- 娉ㄥ唽鐐瑰嚮鍖?
                menuBtnRects["factionFeat_" .. feat.id] = { x = fx, y = fy, w = fBtnW, h = fBtnH }
            end
            end -- subView else

            -- ======== 闃佃惀鎺掕姒滃脊鍑洪潰鏉匡紙瑕嗙洊鍦?info tab 涔嬩笂锛?========
            if factionUI.showRank then
                -- 鍔犺浇鏁版嵁
                if not factionUI.rankLoaded and not factionUI.rankLoading then
                    LoadFactionLevelRank()
                end

                -- 鏆楀箷
                nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
                menuBtnRects.factionRankOverlay = { x = 0, y = 0, w = W, h = H }

                local rpW = W - 50
                local rpH = H * 0.72
                local rpX = 25
                local rpY = (H - rpH) / 2

                -- 闈㈡澘鑳屾櫙
                nvgBeginPath(vg); nvgRoundedRect(vg, rpX, rpY, rpW, rpH, 12)
                nvgFillColor(vg, nvgRGBA(20, 18, 35, 245)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(140, 120, 220, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

                -- 鏍囬
                nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(cx, rpY + 30, "闃佃惀绛夌骇鎺掕姒?)

                -- 鎺掕鍒楄〃
                local listTop = rpY + 58
                local listH = rpH - 110
                local rowH = 38

                if factionUI.rankLoading then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(180, 180, 190, 200))
                    nvgText(vg, cx, rpY + rpH / 2, "鍔犺浇涓?..", nil)
                elseif #factionUI.rankList == 0 then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(180, 180, 190, 200))
                    nvgText(vg, cx, rpY + rpH / 2, "鏆傛棤鎺掕鏁版嵁", nil)
                else
                    local lvNames = { "鏂扮珛", "鍒濆缓", "宕涜捣", "澹ぇ", "鍏寸洓", "榧庣洓", "寮虹洓", "闇镐笟", "鑷冲皧", "鏃犲弻" }
                    local myCampId = CloudManager._factionId or 0
                    -- 琛ㄥご
                    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(140, 130, 160, 180))
                    nvgText(vg, rpX + 12, listTop, "鎺掑悕", nil)
                    nvgText(vg, rpX + 52, listTop, "闃佃惀鍚?, nil)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgText(vg, rpX + rpW - 120, listTop, "绛夌骇", nil)
                    nvgText(vg, rpX + rpW - 45, listTop, "鍔犳垚", nil)
                    listTop = listTop + 22

                    local maxShow = math.min(#factionUI.rankList, math.floor(listH / rowH))
                    for i = 1, maxShow do
                        local r = factionUI.rankList[i]
                        local ry = listTop + (i - 1) * rowH
                        local isMe = (r.campId == myCampId)

                        -- 琛岃儗鏅?
                        if isMe then
                            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + 6, ry, rpW - 12, rowH - 2, 4)
                            nvgFillColor(vg, nvgRGBA(80, 100, 50, 120)); nvgFill(vg)
                        elseif i % 2 == 0 then
                            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + 6, ry, rpW - 12, rowH - 2, 4)
                            nvgFillColor(vg, nvgRGBA(30, 28, 45, 100)); nvgFill(vg)
                        end

                        -- 鎺掑悕
                        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        local rankColor
                        if i == 1 then
                            rankColor = nvgRGBA(255, 215, 0, 255)
                        elseif i == 2 then
                            rankColor = nvgRGBA(200, 200, 210, 255)
                        elseif i == 3 then
                            rankColor = nvgRGBA(205, 127, 50, 255)
                        else rankColor = nvgRGBA(180, 180, 190, 220) end
                        nvgFillColor(vg, rankColor)
                        nvgText(vg, rpX + 28, ry + rowH / 2, tostring(i), nil)

                        -- 闃佃惀鍚?
                        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, isMe and nvgRGBA(200, 255, 160, 255) or nvgRGBA(240, 235, 220, 240))
                        local dispName = r.name or "???"
                        if utf8.len(dispName) > 10 then
                            local cnt = 0
                            local cutPos = #dispName
                            for p, _ in utf8.codes(dispName) do
                                cnt = cnt + 1
                                if cnt == 10 then cutPos = p; break end
                            end
                            dispName = dispName:sub(1, cutPos) .. ".."
                        end
                        nvgText(vg, rpX + 52, ry + rowH / 2, dispName, nil)

                        -- 绛夌骇
                        local lvName = lvNames[r.level] or "?"
                        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(100, 200, 255, 240))
                        nvgText(vg, rpX + rpW - 120, ry + rowH / 2, "Lv." .. r.level .. " " .. lvName, nil)

                        -- 鍔犳垚
                        nvgFillColor(vg, nvgRGBA(255, 220, 140, 220))
                        nvgText(vg, rpX + rpW - 45, ry + rowH / 2, "+" .. (r.level * 2) .. "%", nil)
                    end
                end

                -- 鍏抽棴鎸夐挳
                local closeBtnW, closeBtnH = 100, 36
                local closeBtnX = cx - closeBtnW / 2
                local closeBtnY = rpY + rpH - 48
                nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
                nvgFillColor(vg, nvgRGBA(60, 50, 80, 230)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(140, 120, 200, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(220, 210, 240, 240))
                nvgText(vg, cx, closeBtnY + closeBtnH / 2, "鍏抽棴", nil)
                menuBtnRects.factionRankClose = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }
            end

        elseif factionUI.tab == "members" then
            -- 鎴愬憳鍒楄〃
            if not factionUI.loaded and not factionUI.loading then
                factionUI.loading = true
                CloudManager.GetFactionMembers(function(members)
                    factionUI.members = members or {}
                    -- 鎸夎亴浣嶇瓑绾ч檷搴? 鍚岃亴浣嶆寜鎴樺姏闄嶅簭鎺掑簭
                    table.sort(factionUI.members, function(a, b)
                        local ra = CloudManager.GetMemberRole(a.userId)
                        local rb = CloudManager.GetMemberRole(b.userId)
                        local la = CloudManager.GetRoleLevel(ra)
                        local lb = CloudManager.GetRoleLevel(rb)
                        if la ~= lb then return la > lb end
                        return (a.combatPower or 0) > (b.combatPower or 0)
                    end)
                    factionUI.loaded = true
                    factionUI.loading = false
                    -- 缂撳瓨褰撳墠鐜╁鐨勫钩鍙版樀绉?(鐢ㄤ簬鑱婂ぉ鏄剧ず)
                    local myUid = CloudAPI.GetUserId()
                    for _, mem in ipairs(factionUI.members) do
                        if mem.userId == myUid and mem.nickname then
                            factionUI.myNickname = mem.nickname
                            break
                        end
                    end
                end)
            end
            if factionUI.loading then
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
                nvgText(vg, cx, bodyTop + 60, "鍔犺浇涓?..", nil)
            else
                local cardH = 60
                local cardGap = 6
                local myUid = CloudAPI.GetUserId()
                local myRole = CloudManager.GetFactionInfo().role or "none"
                local canSetRole = (myRole == "leader" or myRole == "vice_leader")
                local scrollOff = factionUI.scroll.offset or 0
                local visibleH = H - bodyTop - 12
                nvgSave(vg)
                nvgScissor(vg, 0, bodyTop, W, visibleH)
                for mi, mem in ipairs(factionUI.members) do
                    local cy = bodyTop + (mi - 1) * (cardH + cardGap) - scrollOff
                    nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, cardH, 8)
                    nvgFillColor(vg, nvgRGBA(25, 25, 35, 200)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(70, 60, 50, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                    -- 鍚嶅瓧
                    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
                    nvgText(vg, pad + 14, cy + cardH / 2 - 8, mem.nickname or ("鐜╁" .. tostring(mem.userId or "")), nil)
                    -- 鑱屼綅
                    local role, roleName = CloudManager.GetMemberRole(mem.userId)
                    nvgFontSize(vg, 15); nvgFillColor(vg, nvgRGBA(255, 180, 80, 200))
                    nvgText(vg, pad + 14, cy + cardH / 2 + 14, roleName or "鎴愬憳", nil)
                    -- 鎴樺姏 + 璁捐亴鎸夐挳
                    local rightX = W - pad - 14
                    if canSetRole and mem.userId ~= myUid and role ~= "leader" then
                        local cursorX = rightX
                        -- 韪㈠嚭鎸夐挳 (鐩熶富/鍓洘涓诲涓嬬骇鍙)
                        local kickBtnW, kickBtnH = 48, 28
                        local kickBtnX = cursorX - kickBtnW
                        local kickBtnY = cy + (cardH - kickBtnH) / 2
                        nvgBeginPath(vg); nvgRoundedRect(vg, kickBtnX, kickBtnY, kickBtnW, kickBtnH, 5)
                        nvgFillColor(vg, nvgRGBA(90, 30, 30, 220)); nvgFill(vg)
                        nvgStrokeColor(vg, nvgRGBA(200, 80, 80, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(255, 180, 180, 240))
                        nvgText(vg, kickBtnX + kickBtnW / 2, kickBtnY + kickBtnH / 2, "韪㈠嚭", nil)
                        menuBtnRects["factionKick_" .. mi] = { x = kickBtnX, y = kickBtnY, w = kickBtnW, h = kickBtnH, userId = mem.userId, nickname = mem.nickname }
                        cursorX = kickBtnX - 6
                        -- 璁剧疆鑱屼綅鎸夐挳
                        local setBtnW, setBtnH = 52, 28
                        local setBtnX = cursorX - setBtnW
                        local setBtnY = cy + (cardH - setBtnH) / 2
                        nvgBeginPath(vg); nvgRoundedRect(vg, setBtnX, setBtnY, setBtnW, setBtnH, 5)
                        nvgFillColor(vg, nvgRGBA(60, 50, 90, 220)); nvgFill(vg)
                        nvgStrokeColor(vg, nvgRGBA(160, 140, 200, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(220, 210, 255, 240))
                        nvgText(vg, setBtnX + setBtnW / 2, setBtnY + setBtnH / 2, "鑱屼綅", nil)
                        menuBtnRects["factionSetRole_" .. mi] = { x = setBtnX, y = setBtnY, w = setBtnW, h = setBtnH, userId = mem.userId, currentRole = role, nickname = mem.nickname }
                        -- 鎴樺姏鏀惧湪鎸夐挳宸﹁竟
                        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(160, 160, 160, 180))
                        nvgText(vg, setBtnX - 8, cy + cardH / 2, "鎴樺姏 " .. tostring(mem.combatPower or 0), nil)
                    else
                        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                        nvgFontSize(vg, 16); nvgFillColor(vg, nvgRGBA(160, 160, 160, 180))
                        nvgText(vg, rightX, cy + cardH / 2, "鎴樺姏 " .. tostring(mem.combatPower or 0), nil)
                    end
                end
                if #factionUI.members == 0 then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                    nvgText(vg, cx, bodyTop + 60, "鏆傛棤鎴愬憳鏁版嵁", nil)
                end
                nvgRestore(vg)

                -- 鑱屼綅閫夋嫨寮圭獥
                if factionUI.rolePopup then
                    local rp = factionUI.rolePopup
                    local roleList = { "vice_leader", "strategist", "vanguard", "diplomat", "elite", "member" }
                    local roleNames = { vice_leader="鍓洘涓?, strategist="鍐涘笀", vanguard="鍏堥攱瀹?, diplomat="澶栦氦瀹?, elite="绮捐嫳", member="鎴愬憳" }
                    local popW, popItemH = 140, 36
                    local popH = #roleList * popItemH + 40
                    local popX = (W - popW) / 2
                    local popY = (H - popH) / 2
                    -- 閬僵
                    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150)); nvgFill(vg)
                    -- 寮圭獥鑳屾櫙
                    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
                    nvgFillColor(vg, nvgRGBA(30, 28, 40, 245)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(120, 100, 180, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                    -- 鏍囬
                    nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 220, 160, 240))
                    nvgText(vg, popX + popW / 2, popY + 18, "璁剧疆鑱屼綅", nil)
                    -- 閫夐」
                    for ri, rk in ipairs(roleList) do
                        local iy = popY + 36 + (ri - 1) * popItemH
                        local isCurrent = (rk == rp.currentRole)
                        nvgBeginPath(vg); nvgRoundedRect(vg, popX + 8, iy, popW - 16, popItemH - 4, 6)
                        if isCurrent then
                            nvgFillColor(vg, nvgRGBA(80, 70, 50, 200)); nvgFill(vg)
                        else
                            nvgFillColor(vg, nvgRGBA(40, 38, 55, 180)); nvgFill(vg)
                        end
                        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, isCurrent and nvgRGBA(255, 200, 100, 255) or nvgRGBA(210, 205, 195, 230))
                        nvgText(vg, popX + popW / 2, iy + (popItemH - 4) / 2, roleNames[rk] or rk, nil)
                        menuBtnRects["factionRoleOption_" .. ri] = { x = popX + 8, y = iy, w = popW - 16, h = popItemH - 4, roleKey = rk }
                    end
                    -- 鍏抽棴鍖哄煙 (鐐瑰脊绐楀鍏抽棴)
                    menuBtnRects.factionRolePopupBg = { x = 0, y = 0, w = W, h = H, isOverlay = true }
                end
            end

        elseif factionUI.tab == "apply" then
            -- 鍏ラ槦鐢宠 (鍓洘涓讳互涓婂彲瑙?
            if not factionUI.applyLoaded and not factionUI.applyLoading then
                factionUI.applyLoading = true
                CloudManager.CheckFactionApplications(function(apps)
                    factionUI.applications = apps or {}
                    factionUI.applyLoaded = true
                    factionUI.applyLoading = false
                end)
            end
            if factionUI.applyLoading then
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
                nvgText(vg, cx, bodyTop + 60, "鍔犺浇鐢宠...", nil)
            else
                local cardH = 56
                local cardGap = 6
                for ai, app in ipairs(factionUI.applications) do
                    local cy = bodyTop + (ai - 1) * (cardH + cardGap)
                    nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, cardH, 8)
                    nvgFillColor(vg, nvgRGBA(25, 25, 35, 200)); nvgFill(vg)
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
                    nvgText(vg, pad + 14, cy + cardH / 2, app.nickname or ("鐜╁" .. tostring(app.userId)), nil)
                    -- 鍚屾剰鎸夐挳
                    local btnW, btnH = 56, 32
                    local acceptX = W - pad - btnW * 2 - 10
                    local rejectX = W - pad - btnW
                    nvgBeginPath(vg); nvgRoundedRect(vg, acceptX, cy + (cardH - btnH) / 2, btnW, btnH, 6)
                    nvgFillColor(vg, nvgRGBA(40, 100, 40, 220)); nvgFill(vg)
                    nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(200, 255, 200, 255))
                    nvgText(vg, acceptX + btnW / 2, cy + cardH / 2, "鍚屾剰", nil)
                    menuBtnRects["factionAccept_" .. ai] = { x = acceptX, y = cy + (cardH - btnH) / 2, w = btnW, h = btnH, userId = app.userId }
                    -- 鎷掔粷鎸夐挳
                    nvgBeginPath(vg); nvgRoundedRect(vg, rejectX, cy + (cardH - btnH) / 2, btnW, btnH, 6)
                    nvgFillColor(vg, nvgRGBA(100, 30, 30, 220)); nvgFill(vg)
                    nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
                    nvgText(vg, rejectX + btnW / 2, cy + cardH / 2, "鎷掔粷", nil)
                    menuBtnRects["factionReject_" .. ai] = { x = rejectX, y = cy + (cardH - btnH) / 2, w = btnW, h = btnH, userId = app.userId }
                end
                if #factionUI.applications == 0 then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                    nvgText(vg, cx, bodyTop + 60, "鏆傛棤鍏ラ槦鐢宠", nil)
                end
            end

        elseif factionUI.tab == "chat" then
            -- ======== 闃佃惀鑱婂ぉ (浜戠鍚屾) ========
            local chatAreaH = H - bodyTop - 70
            -- 娑堟伅鍖哄煙鑳屾櫙
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, bodyTop, W - pad * 2, chatAreaH, 8)
            nvgFillColor(vg, nvgRGBA(15, 15, 20, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(60, 55, 50, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 棣栨杩涘叆鑱婂ぉtab绔嬪嵆鎷夊彇涓€娆?
            if not factionUI.chatPolled then
                factionUI.chatPolled = true
                CloudManager.PollFactionChat()
            end

            -- 娑堟伅鍒楄〃 (浠嶤loudManager璇诲彇)
            nvgSave(vg)
            nvgScissor(vg, pad, bodyTop, W - pad * 2, chatAreaH)
            local fcAvS = 28  -- 闃佃惀鑱婂ぉ澶村儚灏哄
            local msgH = fcAvS + 12
            local msgs = CloudManager.GetFactionChatMessages()
            local visibleCount = math.floor(chatAreaH / msgH)
            local startIdx = math.max(1, #msgs - visibleCount + 1)
            factionUI._chatAvatarRects = factionUI._chatAvatarRects or {}
            factionUI._chatAvatarRects = {}
            for i = startIdx, #msgs do
                local msg = msgs[i]
                local my = bodyTop + (i - startIdx) * msgH + 4
                -- 澶村儚 (鍙偣鍑?
                local fcAvX = pad + 8
                local fcAvY = my
                local fcAvIdx = msg.av or 1
                if IMG.avatarSheet >= 0 then
                    local avData = AVATAR_DATA[fcAvIdx] or AVATAR_DATA[1]
                    local imgW2, imgH2 = 512, 768
                    local cellW2 = imgW2 / AVATAR_COLS
                    local cellH2 = imgH2 / AVATAR_ROWS
                    local sx2 = avData.col * cellW2
                    local sy2 = avData.row * cellH2
                    nvgBeginPath(vg); nvgRoundedRect(vg, fcAvX - 1, fcAvY - 1, fcAvS + 2, fcAvS + 2, 4)
                    nvgFillColor(vg, nvgRGBA(30, 25, 40, 200)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 150)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    local pat4 = nvgImagePattern(vg, fcAvX - sx2 * (fcAvS / cellW2),
                        fcAvY - sy2 * (fcAvS / cellH2),
                        imgW2 * (fcAvS / cellW2), imgH2 * (fcAvS / cellH2), 0, IMG.avatarSheet, 1.0)
                    nvgBeginPath(vg); nvgRoundedRect(vg, fcAvX, fcAvY, fcAvS, fcAvS, 3)
                    nvgFillPaint(vg, pat4); nvgFill(vg)
                else
                    nvgBeginPath(vg); nvgRoundedRect(vg, fcAvX, fcAvY, fcAvS, fcAvS, 3)
                    nvgFillColor(vg, nvgRGBA(50, 60, 80, 200)); nvgFill(vg)
                end
                if msg.uid and msg.uid > 0 then
                    factionUI._chatAvatarRects[#factionUI._chatAvatarRects + 1] = {
                        x = fcAvX, y = fcAvY, w = fcAvS, h = fcAvS,
                        uid = msg.uid, name = msg.name or "???", av = fcAvIdx,
                    }
                end
                -- 鍚嶅瓧 + 鏃堕棿
                local fcTxtX = fcAvX + fcAvS + 8
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(120, 200, 255, 220))
                nvgText(vg, fcTxtX, my, msg.name or "???", nil)
                -- 鏃堕棿
                nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(120, 120, 120, 150))
                nvgText(vg, W - pad - 10, my, msg.time or "", nil)
                -- 鍐呭
                nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(230, 225, 215, 240))
                nvgText(vg, fcTxtX, my + 16, msg.text or "", nil)
            end
            if #msgs == 0 then
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(130, 130, 130, 160))
                nvgText(vg, cx, bodyTop + chatAreaH / 2, "鏆傛棤娑堟伅锛岃鐐逛粈涔堝惂", nil)
            end
            nvgRestore(vg)

            -- 闃佃惀鑱婂ぉ鐜╁淇℃伅寮圭獥锛堢偣鍑诲ご鍍忓脊鍑猴級
            if factionUI.chatNamePopup then
                local pp = factionUI.chatNamePopup
                local ppW, ppH = 160, 60
                local ppX = math.min(pp.x + fcAvS + 4, W - pad - ppW - 4)
                local ppY = pp.y - 4
                if ppY + ppH > bodyTop + chatAreaH then ppY = pp.y - ppH - 4 end
                if ppY < bodyTop then ppY = bodyTop + 4 end
                -- 寮圭獥鑳屾櫙
                nvgBeginPath(vg); nvgRoundedRect(vg, ppX, ppY, ppW, ppH, 8)
                nvgFillColor(vg, nvgRGBA(40, 35, 55, 245)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(100, 160, 240, 200)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
                -- 寮圭獥鍐呭ご鍍?
                local ppAvS2 = 32
                local ppAvX2 = ppX + 8
                local ppAvY2 = ppY + (ppH - ppAvS2) / 2
                local ppAvIdx2 = pp.av or 1
                if IMG.avatarSheet >= 0 then
                    local avData = AVATAR_DATA[ppAvIdx2] or AVATAR_DATA[1]
                    local imgW2, imgH2 = 512, 768
                    local cellW2 = imgW2 / AVATAR_COLS
                    local cellH2 = imgH2 / AVATAR_ROWS
                    local sx2 = avData.col * cellW2
                    local sy2 = avData.row * cellH2
                    nvgBeginPath(vg); nvgRoundedRect(vg, ppAvX2 - 1, ppAvY2 - 1, ppAvS2 + 2, ppAvS2 + 2, 4)
                    nvgFillColor(vg, nvgRGBA(20, 15, 30, 200)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 160)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    local pat5 = nvgImagePattern(vg, ppAvX2 - sx2 * (ppAvS2 / cellW2),
                        ppAvY2 - sy2 * (ppAvS2 / cellH2),
                        imgW2 * (ppAvS2 / cellW2), imgH2 * (ppAvS2 / cellH2), 0, IMG.avatarSheet, 1.0)
                    nvgBeginPath(vg); nvgRoundedRect(vg, ppAvX2, ppAvY2, ppAvS2, ppAvS2, 3)
                    nvgFillPaint(vg, pat5); nvgFill(vg)
                end
                -- 鍚嶅瓧
                local ppTxtX2 = ppAvX2 + ppAvS2 + 8
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 15)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(120, 200, 255, 240))
                nvgText(vg, ppTxtX2, ppY + ppH / 2 - 8, pp.name or "???", nil)
                -- 娣诲姞濂藉弸鎸夐挳
                local addBtnW2, addBtnH2 = 70, 22
                local addBtnX2 = ppTxtX2
                local addBtnY2 = ppY + ppH / 2 + 6
                local isFriend2 = CloudManager.IsFriend(pp.uid)
                local isMe2 = (CloudAPI.IsAvailable() and pp.uid == CloudAPI.GetUserId())
                if isMe2 then
                    nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(120, 120, 120, 180))
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgText(vg, addBtnX2, addBtnY2 + addBtnH2 / 2, "锛堣嚜宸憋級", nil)
                elseif isFriend2 then
                    nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(100, 200, 140, 200))
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgText(vg, addBtnX2, addBtnY2 + addBtnH2 / 2, "宸叉槸濂藉弸", nil)
                else
                    nvgBeginPath(vg); nvgRoundedRect(vg, addBtnX2, addBtnY2, addBtnW2, addBtnH2, 4)
                    nvgFillColor(vg, nvgRGBA(40, 100, 60, 220)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100, 220, 140, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(100, 240, 140, 255))
                    nvgText(vg, addBtnX2 + addBtnW2 / 2, addBtnY2 + addBtnH2 / 2, "+ 鍔犲ソ鍙?, nil)
                    menuBtnRects.factionChatAddFriend = { x = addBtnX2, y = addBtnY2, w = addBtnW2, h = addBtnH2, uid = pp.uid, name = pp.name }
                end
                menuBtnRects.factionChatPopupArea = { x = ppX, y = ppY, w = ppW, h = ppH }
                if not menuBtnRects.factionChatAddFriend or isMe2 or isFriend2 then
                    menuBtnRects.factionChatAddFriend = nil
                end
            else
                menuBtnRects.factionChatAddFriend = nil
                menuBtnRects.factionChatPopupArea = nil
            end

            -- 杈撳叆鏍?
            local inputY = bodyTop + chatAreaH + 6
            local sendW = 60
            local inputW2 = W - pad * 2 - sendW - 6
            -- 杈撳叆妗?
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, inputY, inputW2, 40, 6)
            nvgFillColor(vg, nvgRGBA(20, 20, 28, 220)); nvgFill(vg)
            local chatActive = (factionUI.inputTarget == "chat")
            nvgStrokeColor(vg, chatActive and nvgRGBA(120, 180, 255, 200) or nvgRGBA(60, 60, 70, 150))
            nvgStrokeWidth(vg, chatActive and 2 or 1); nvgStroke(vg)
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if factionUI.chatInput and #factionUI.chatInput > 0 then
                nvgFillColor(vg, nvgRGBA(240, 235, 220, 240))
                nvgText(vg, pad + 10, inputY + 20, factionUI.chatInput, nil)
            else
                nvgFillColor(vg, nvgRGBA(110, 110, 110, 150))
                nvgText(vg, pad + 10, inputY + 20, "杈撳叆娑堟伅...", nil)
            end
            menuBtnRects.factionChatInput = { x = pad, y = inputY, w = inputW2, h = 40 }
            -- 鍙戦€佹寜閽?
            local sendX = pad + inputW2 + 6
            nvgBeginPath(vg); nvgRoundedRect(vg, sendX, inputY, sendW, 40, 6)
            nvgFillColor(vg, nvgRGBA(50, 90, 140, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 160, 240, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 230, 255, 255))
            nvgText(vg, sendX + sendW / 2, inputY + 20, "鍙戦€?, nil)
            menuBtnRects.factionChatSend = { x = sendX, y = inputY, w = sendW, h = 40 }
        end

    else
        -- ======== 鏈姞鍏ラ樀钀?========
        -- Tab鏍? 闃佃惀鍒楄〃 | 鍒涘缓闃佃惀
        local tabs = { { id = "list", label = "闃佃惀鍒楄〃" }, { id = "create", label = "鍒涘缓闃佃惀" } }
        local tabW = (W - pad * 2) / #tabs
        local tabH = 38
        local tabY = contentTop
        for i, tb in ipairs(tabs) do
            local tx = pad + (i - 1) * tabW
            local sel = (factionUI.tab == tb.id)
            nvgBeginPath(vg); nvgRoundedRect(vg, tx + 2, tabY, tabW - 4, tabH, 6)
            nvgFillColor(vg, sel and nvgRGBA(90, 60, 30, 220) or nvgRGBA(30, 30, 40, 180)); nvgFill(vg)
            if sel then nvgStrokeColor(vg, nvgRGBA(255, 180, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg) end
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, sel and nvgRGBA(255, 220, 100, 255) or nvgRGBA(180, 180, 180, 200))
            nvgText(vg, tx + tabW / 2, tabY + tabH / 2, tb.label, nil)
            menuBtnRects["factionTab_" .. tb.id] = { x = tx + 2, y = tabY, w = tabW - 4, h = tabH }
        end
        local bodyTop = tabY + tabH + 10

        -- 妫€鏌ョ敵璇风姸鎬?
        if factionUI.applyStatus == "pending" then
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
            nvgText(vg, cx, bodyTop, "宸叉彁浜ょ敵璇凤紝绛夊緟瀹℃壒涓?..", nil)
            local refreshW, refreshH = 120, 36
            local refreshX = cx - refreshW / 2
            local refreshY = bodyTop + 28
            nvgBeginPath(vg); nvgRoundedRect(vg, refreshX, refreshY, refreshW, refreshH, 6)
            nvgFillColor(vg, nvgRGBA(50, 50, 70, 200)); nvgFill(vg)
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
            nvgText(vg, cx, refreshY + refreshH / 2, "鍒锋柊鐘舵€?, nil)
            menuBtnRects.factionRefreshApply = { x = refreshX, y = refreshY, w = refreshW, h = refreshH }
            bodyTop = refreshY + refreshH + 12
        end

        if factionUI.tab == "list" then
            -- 闃佃惀鍒楄〃
            if not factionUI.loaded and not factionUI.loading then
                factionUI.loading = true
                CloudManager.ListFactions(function(factions)
                    factionUI.factions = factions or {}
                    factionUI.loaded = true
                    factionUI.loading = false
                end)
            end
            if factionUI.loading then
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
                nvgText(vg, cx, bodyTop + 80, "鍔犺浇闃佃惀鍒楄〃...", nil)
            else
                local cardH = 80
                local cardGap = 8
                nvgSave(vg)
                nvgScissor(vg, 0, bodyTop, W, H - bodyTop - 12)
                for fi, fac in ipairs(factionUI.factions) do
                    local cy = bodyTop + (fi - 1) * (cardH + cardGap)
                    nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, cardH, 10)
                    nvgFillColor(vg, nvgRGBA(25, 20, 15, 210)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100, 75, 40, 130)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                    -- 闃佃惀鍚?
                    nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(255, 220, 120, 240))
                    nvgText(vg, pad + 14, cy + 10, fac.name or "?", nil)
                    -- 鐩熶富 & 浜烘暟
                    nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(170, 160, 140, 200))
                    nvgText(vg, pad + 14, cy + 36, "鐩熶富: " .. (fac.leaderNickname or "?"), nil)
                    nvgText(vg, pad + 14, cy + 56, "鎴愬憳: " .. tostring(fac.memberCount or 0) .. "/20", nil)
                    -- 鐢宠鎸夐挳 (妫€鏌ユ槸鍚﹀凡鐢宠)
                    local applyBtnW, applyBtnH = 70, 32
                    local applyBtnX = W - pad - applyBtnW - 10
                    local applyBtnY = cy + (cardH - applyBtnH) / 2
                    local outApply = CloudManager._campOutApply
                    local alreadyApplied = outApply and outApply.campId == fac.campId
                    nvgBeginPath(vg); nvgRoundedRect(vg, applyBtnX, applyBtnY, applyBtnW, applyBtnH, 6)
                    if alreadyApplied then
                        nvgFillColor(vg, nvgRGBA(50, 50, 45, 180)); nvgFill(vg)
                        nvgStrokeColor(vg, nvgRGBA(80, 80, 70, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                        nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(160, 160, 140, 180))
                        nvgText(vg, applyBtnX + applyBtnW / 2, applyBtnY + applyBtnH / 2, "宸茬敵璇?, nil)
                    else
                        nvgFillColor(vg, nvgRGBA(60, 90, 40, 220)); nvgFill(vg)
                        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(220, 255, 200, 255))
                        nvgText(vg, applyBtnX + applyBtnW / 2, applyBtnY + applyBtnH / 2, "鐢宠", nil)
                        menuBtnRects["factionApply_" .. fi] = { x = applyBtnX, y = applyBtnY, w = applyBtnW, h = applyBtnH, campId = fac.campId, campName = fac.name }
                    end
                end
                nvgRestore(vg)
                if #factionUI.factions == 0 then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                    nvgText(vg, cx, bodyTop + 80, "鏆傛棤闃佃惀锛屾潵鍒涘缓绗竴涓惂锛?, nil)
                end
            end

        elseif factionUI.tab == "create" then
            -- 鍒涘缓闃佃惀
            local formY = bodyTop + 10
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
            nvgText(vg, pad + 8, formY, "闃佃惀鍚嶇О:", nil)

            local inputW = W - pad * 2
            local inputH = 40
            local nameInputY = formY + 24
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, nameInputY, inputW, inputH, 6)
            nvgFillColor(vg, nvgRGBA(15, 15, 20, 220)); nvgFill(vg)
            local nameActive = (factionUI.inputTarget == "name")
            nvgStrokeColor(vg, nameActive and nvgRGBA(255, 180, 60, 200) or nvgRGBA(60, 60, 70, 150))
            nvgStrokeWidth(vg, nameActive and 2 or 1); nvgStroke(vg)
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if #factionUI.createName > 0 then
                nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
                nvgText(vg, pad + 10, nameInputY + inputH / 2, factionUI.createName, nil)
            else
                nvgFillColor(vg, nvgRGBA(120, 120, 120, 150))
                nvgText(vg, pad + 10, nameInputY + inputH / 2, "璇疯緭鍏ラ樀钀ュ悕绉?2-8瀛?", nil)
            end
            menuBtnRects.factionNameInput = { x = pad, y = nameInputY, w = inputW, h = inputH }

            nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
            nvgText(vg, pad + 8, nameInputY + inputH + 16, "闃佃惀绠€浠?鍙€?:", nil)
            local descInputY = nameInputY + inputH + 40
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, descInputY, inputW, inputH, 6)
            nvgFillColor(vg, nvgRGBA(15, 15, 20, 220)); nvgFill(vg)
            local descActive = (factionUI.inputTarget == "desc")
            nvgStrokeColor(vg, descActive and nvgRGBA(255, 180, 60, 200) or nvgRGBA(60, 60, 70, 150))
            nvgStrokeWidth(vg, descActive and 2 or 1); nvgStroke(vg)
            if #factionUI.createDesc > 0 then
                nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
                nvgText(vg, pad + 10, descInputY + inputH / 2, factionUI.createDesc, nil)
            else
                nvgFillColor(vg, nvgRGBA(120, 120, 120, 150))
                nvgText(vg, pad + 10, descInputY + inputH / 2, "涓€鍙ヨ瘽浠嬬粛浣犵殑闃佃惀", nil)
            end
            menuBtnRects.factionDescInput = { x = pad, y = descInputY, w = inputW, h = inputH }

            -- 璐圭敤鎻愮ず
            nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 180, 80, 180))
            nvgText(vg, cx, descInputY + inputH + 14, "鍒涘缓娑堣€?5000 铏庣", nil)

            -- 鍒涘缓鎸夐挳
            local createW, createH = 180, 46
            local createX = cx - createW / 2
            local createY = descInputY + inputH + 44
            local canCreate = #factionUI.createName >= 2
            nvgBeginPath(vg); nvgRoundedRect(vg, createX, createY, createW, createH, 8)
            nvgFillColor(vg, canCreate and nvgRGBA(100, 70, 20, 230) or nvgRGBA(50, 50, 50, 150)); nvgFill(vg)
            nvgStrokeColor(vg, canCreate and nvgRGBA(255, 180, 60, 180) or nvgRGBA(80, 80, 80, 100)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, canCreate and nvgRGBA(255, 230, 150, 255) or nvgRGBA(120, 120, 120, 150))
            nvgText(vg, cx, createY + createH / 2, "鍒涘缓闃佃惀", nil)
            menuBtnRects.factionCreate = { x = createX, y = createY, w = createW, h = createH }
        end
    end

    -- 鏀瑰悕寮圭獥
    if factionUI.renamePopup then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
        local rpW, rpH = 320, 180
        local rpX, rpY = cx - rpW / 2, H / 2 - rpH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX, rpY, rpW, rpH, 12)
        nvgFillColor(vg, nvgRGBA(30, 25, 20, 245)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 150, 60, 160)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 160, 240))
        nvgText(vg, cx, rpY + 26, "淇敼闃佃惀鍚嶇О", nil)
        nvgFontSize(vg, 13); nvgFillColor(vg, nvgRGBA(255, 200, 100, 180))
        nvgText(vg, cx, rpY + 46, "璐圭敤: 1000 铏庣", nil)
        -- 杈撳叆妗?
        local riX, riY, riW, riH = rpX + 20, rpY + 60, rpW - 40, 36
        nvgBeginPath(vg); nvgRoundedRect(vg, riX, riY, riW, riH, 6)
        nvgFillColor(vg, nvgRGBA(10, 10, 15, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(120, 100, 60, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local renameText = factionUI.renameInput or ""
        if #renameText > 0 then
            nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
            nvgText(vg, riX + 10, riY + riH / 2, renameText, nil)
        else
            nvgFillColor(vg, nvgRGBA(120, 110, 90, 150))
            nvgText(vg, riX + 10, riY + riH / 2, "杈撳叆鏂板悕绉?鏈€澶?瀛?", nil)
        end
        menuBtnRects.factionRenameInput = { x = riX, y = riY, w = riW, h = riH }
        -- 纭/鍙栨秷鎸夐挳
        local rbW, rbH = 100, 36
        local rbY = rpY + rpH - 50
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - rbW - 10, rbY, rbW, rbH, 6)
        nvgFillColor(vg, nvgRGBA(60, 100, 40, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(220, 255, 200, 255)); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, cx - rbW / 2 - 10, rbY + rbH / 2, "纭", nil)
        menuBtnRects.factionRenameYes = { x = cx - rbW - 10, y = rbY, w = rbW, h = rbH }
        nvgBeginPath(vg); nvgRoundedRect(vg, cx + 10, rbY, rbW, rbH, 6)
        nvgFillColor(vg, nvgRGBA(80, 30, 30, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
        nvgText(vg, cx + 10 + rbW / 2, rbY + rbH / 2, "鍙栨秷", nil)
        menuBtnRects.factionRenameNo = { x = cx + 10, y = rbY, w = rbW, h = rbH }
    end

    -- 纭寮圭獥
    if factionUI.confirmPopup then
        local pop = factionUI.confirmPopup
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
        local popW, popH = 340, 160
        local popX, popY = cx - popW / 2, H / 2 - popH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 12)
        nvgFillColor(vg, nvgRGBA(30, 25, 20, 240)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 150, 60, 160)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
        nvgText(vg, cx, popY + 50, pop.msg or "纭鎿嶄綔?", nil)
        local btnW2, btnH2 = 100, 38
        local yBtn = popY + popH - 50
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - btnW2 - 10, yBtn, btnW2, btnH2, 6)
        nvgFillColor(vg, nvgRGBA(60, 100, 40, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(220, 255, 200, 255)); nvgFontSize(vg, 18)
        nvgText(vg, cx - btnW2 / 2 - 10, yBtn + btnH2 / 2, "纭", nil)
        menuBtnRects.factionPopupYes = { x = cx - btnW2 - 10, y = yBtn, w = btnW2, h = btnH2 }
        nvgBeginPath(vg); nvgRoundedRect(vg, cx + 10, yBtn, btnW2, btnH2, 6)
        nvgFillColor(vg, nvgRGBA(80, 30, 30, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
        nvgText(vg, cx + 10 + btnW2 / 2, yBtn + btnH2 / 2, "鍙栨秷", nil)
        menuBtnRects.factionPopupNo = { x = cx + 10, y = yBtn, w = btnW2, h = btnH2 }
    end
end


-- ===========================
-- 濂藉弸鐣岄潰 (瀹屾暣瀹炵幇)
-- ===========================
-- ============================================================================
-- 浜ゆ槗琛岀晫闈?
-- ============================================================================

