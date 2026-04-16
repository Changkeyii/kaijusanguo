-- ui/social_friends.lua - 三国武灵录 (从 social.lua 拆分)
function DrawFriendsScreen()
    local W, H = DESIGN_W, DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0
    DrawSocialBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 返回按钮
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(45, 55, 90, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    menuBtnRects.friendsBack = { x = backX, y = backY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 30); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 32, "好友")

    local contentTop = 64
    local pad = 14

    -- Tab 栏: 好友列表 | 添加好友 | 好友请求
    local tabs = {
        { id = "list", label = "好友列表" },
        { id = "add", label = "添加好友" },
        { id = "requests", label = "好友请求" },
    }
    local tabW = (W - pad * 2) / #tabs
    local tabH = 38
    local tabY = contentTop
    for i, tb in ipairs(tabs) do
        local tx = pad + (i - 1) * tabW
        local sel = (friendsUI.tab == tb.id)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx + 2, tabY, tabW - 4, tabH, 6)
        nvgFillColor(vg, sel and nvgRGBA(30, 60, 90, 220) or nvgRGBA(30, 30, 40, 180)); nvgFill(vg)
        if sel then nvgStrokeColor(vg, nvgRGBA(80, 180, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg) end
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, sel and nvgRGBA(150, 220, 255, 255) or nvgRGBA(180, 180, 180, 200))
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, tb.label, nil)
        menuBtnRects["friendsTab_" .. tb.id] = { x = tx + 2, y = tabY, w = tabW - 4, h = tabH }
    end
    -- 请求数提示
    if #friendsUI.requests > 0 then
        local reqTabR = menuBtnRects["friendsTab_requests"]
        if reqTabR then DrawRedDot(reqTabR.x + reqTabR.w - 6, reqTabR.y + 6, 7) end
    end
    local bodyTop = tabY + tabH + 10

    if friendsUI.tab == "list" then
        -- 好友列表
        if not friendsUI.loaded and not friendsUI.loading then
            friendsUI.loading = true
            CloudManager.GetFriendProfiles(function(friends)
                friendsUI.friends = friends or {}
                friendsUI.loaded = true
                friendsUI.loading = false
            end)
        end
        local friendIds = CloudManager.GetFriendIds()
        local friendCount = friendIds and #friendIds or 0
        -- 好友计数
        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(160, 160, 160, 180))
        nvgText(vg, W - pad, bodyTop - 6, tostring(friendCount) .. "/50", nil)

        if friendsUI.loading then
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
            nvgText(vg, cx, bodyTop + 80, "加载中...", nil)
        else
            local cardH = 64
            local cardGap = 6
            nvgSave(vg)
            nvgScissor(vg, 0, bodyTop, W, H - bodyTop - 12)
            for fi, fr in ipairs(friendsUI.friends) do
                local cy = bodyTop + (fi - 1) * (cardH + cardGap)
                nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, cardH, 8)
                nvgFillColor(vg, nvgRGBA(20, 25, 35, 210)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(50, 70, 100, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                -- 名字
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(200, 230, 255, 240))
                nvgText(vg, pad + 14, cy + cardH / 2 - 8, fr.nickname or ("玩家" .. tostring(fr.userId or "")), nil)
                -- 战力
                nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(160, 160, 170, 180))
                nvgText(vg, pad + 14, cy + cardH / 2 + 14, "战力 " .. tostring(fr.combatPower or 0), nil)
                -- 删除按钮
                local delW, delH = 56, 30
                local delX = W - pad - delW - 10
                local delY = cy + (cardH - delH) / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, delX, delY, delW, delH, 6)
                nvgFillColor(vg, nvgRGBA(90, 30, 30, 200)); nvgFill(vg)
                nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 180, 180, 240))
                nvgText(vg, delX + delW / 2, delY + delH / 2, "删除", nil)
                menuBtnRects["friendDel_" .. fi] = { x = delX, y = delY, w = delW, h = delH, userId = fr.userId }
            end
            nvgRestore(vg)
            if #friendsUI.friends == 0 and friendCount == 0 then
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                nvgText(vg, cx, bodyTop + 80, "还没有好友，去添加吧！", nil)
            elseif #friendsUI.friends == 0 and friendCount > 0 then
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                nvgText(vg, cx, bodyTop + 80, "好友数据加载中...", nil)
            end
        end

    elseif friendsUI.tab == "add" then
        -- 添加好友: 推荐玩家 + 搜索
        -- 搜索栏
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
        nvgText(vg, pad + 8, bodyTop + 4, "输入玩家ID搜索:", nil)

        local searchInputW = W - pad * 2 - 80
        local searchInputH = 36
        local searchInputY = bodyTop + 22
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, searchInputY, searchInputW, searchInputH, 6)
        nvgFillColor(vg, nvgRGBA(15, 15, 20, 220)); nvgFill(vg)
        local searchActive = (friendsUI.inputActive == true)
        nvgStrokeColor(vg, searchActive and nvgRGBA(80, 180, 255, 200) or nvgRGBA(60, 60, 70, 150))
        nvgStrokeWidth(vg, searchActive and 2 or 1); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        if #friendsUI.searchId > 0 then
            nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
            nvgText(vg, pad + 10, searchInputY + searchInputH / 2, friendsUI.searchId, nil)
        else
            nvgFillColor(vg, nvgRGBA(100, 100, 100, 150))
            nvgText(vg, pad + 10, searchInputY + searchInputH / 2, "玩家ID", nil)
        end
        menuBtnRects.friendSearchInput = { x = pad, y = searchInputY, w = searchInputW, h = searchInputH }

        -- 搜索按钮
        local sBtnW, sBtnH = 70, searchInputH
        local sBtnX = pad + searchInputW + 6
        nvgBeginPath(vg); nvgRoundedRect(vg, sBtnX, searchInputY, sBtnW, sBtnH, 6)
        nvgFillColor(vg, nvgRGBA(40, 70, 110, 220)); nvgFill(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 255))
        nvgText(vg, sBtnX + sBtnW / 2, searchInputY + sBtnH / 2, "搜索", nil)
        menuBtnRects.friendSearchBtn = { x = sBtnX, y = searchInputY, w = sBtnW, h = sBtnH }

        -- 搜索结果
        local recTop = searchInputY + searchInputH + 12
        if friendsUI.searchResult then
            local sr = friendsUI.searchResult
            local cardH = 60
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, recTop, W - pad * 2, cardH, 8)
            nvgFillColor(vg, nvgRGBA(30, 40, 50, 210)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 140, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 230, 255, 240))
            nvgText(vg, pad + 14, recTop + cardH / 2, sr.nickname or ("玩家" .. tostring(sr.userId or "")), nil)
            -- 添加按钮
            local addW, addH = 56, 30
            local addX = W - pad - addW - 10
            local addY = recTop + (cardH - addH) / 2
            local isFr = CloudManager.IsFriend(sr.userId)
            nvgBeginPath(vg); nvgRoundedRect(vg, addX, addY, addW, addH, 6)
            nvgFillColor(vg, isFr and nvgRGBA(60, 60, 60, 150) or nvgRGBA(40, 90, 50, 220)); nvgFill(vg)
            nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 255, 200, isFr and 120 or 255))
            nvgText(vg, addX + addW / 2, addY + addH / 2, isFr and "已添加" or "添加", nil)
            if not isFr then
                menuBtnRects.friendSearchAdd = { x = addX, y = addY, w = addW, h = addH, userId = sr.userId }
            end
            recTop = recTop + cardH + 12
        elseif friendsUI.searchNotFound then
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(200, 120, 120, 200))
            nvgText(vg, cx, recTop, "未找到该玩家", nil)
            recTop = recTop + 26
        end

        -- 推荐标题
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(180, 180, 180, 180))
        nvgText(vg, pad + 4, recTop + 4, "推荐玩家:", nil)
        recTop = recTop + 26

        -- 推荐玩家列表
        if not friendsUI.recLoaded and not friendsUI.recLoading then
            friendsUI.recLoading = true
            CloudManager.GetRandomPlayers(10, function(players)
                friendsUI.recommended = players or {}
                friendsUI.recLoaded = true
                friendsUI.recLoading = false
            end)
        end
        local cardH2 = 54
        local cardGap2 = 5
        nvgSave(vg)
        nvgScissor(vg, 0, recTop, W, H - recTop - 12)
        for ri, rp in ipairs(friendsUI.recommended) do
            local cy = recTop + (ri - 1) * (cardH2 + cardGap2)
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, cardH2, 7)
            nvgFillColor(vg, nvgRGBA(20, 25, 35, 200)); nvgFill(vg)
            nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 220, 240, 230))
            nvgText(vg, pad + 12, cy + cardH2 / 2, rp.nickname or ("玩家" .. tostring(rp.userId or "")), nil)
            -- 添加按钮
            local addW2, addH2 = 56, 28
            local addX2 = W - pad - addW2 - 10
            local addY2 = cy + (cardH2 - addH2) / 2
            local isFr2 = CloudManager.IsFriend(rp.userId)
            nvgBeginPath(vg); nvgRoundedRect(vg, addX2, addY2, addW2, addH2, 6)
            nvgFillColor(vg, isFr2 and nvgRGBA(60, 60, 60, 150) or nvgRGBA(40, 90, 50, 220)); nvgFill(vg)
            nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 255, 200, isFr2 and 120 or 255))
            nvgText(vg, addX2 + addW2 / 2, addY2 + addH2 / 2, isFr2 and "已添加" or "添加", nil)
            if not isFr2 then
                menuBtnRects["friendRecAdd_" .. ri] = { x = addX2, y = addY2, w = addW2, h = addH2, userId = rp.userId }
            end
        end
        nvgRestore(vg)
        if #friendsUI.recommended == 0 and not friendsUI.recLoading then
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(140, 140, 140, 160))
            nvgText(vg, cx, recTop + 40, "暂无推荐玩家", nil)
        end

    elseif friendsUI.tab == "requests" then
        -- 收到的好友请求
        if not friendsUI.reqLoaded and not friendsUI.reqLoading then
            friendsUI.reqLoading = true
            CloudManager.CheckIncomingRequests(function(reqs)
                friendsUI.requests = reqs or {}
                friendsUI.reqLoaded = true
                friendsUI.reqLoading = false
            end)
        end
        if friendsUI.reqLoading then
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
            nvgText(vg, cx, bodyTop + 80, "加载请求...", nil)
        else
            local cardH = 56
            local cardGap = 6
            nvgSave(vg)
            nvgScissor(vg, 0, bodyTop, W, H - bodyTop - 12)
            for ri, req in ipairs(friendsUI.requests) do
                local cy = bodyTop + (ri - 1) * (cardH + cardGap)
                nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, cardH, 8)
                nvgFillColor(vg, nvgRGBA(20, 25, 35, 210)); nvgFill(vg)
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(200, 230, 255, 240))
                nvgText(vg, pad + 14, cy + cardH / 2, req.nickname or ("玩家" .. tostring(req.fromUid or "")), nil)
                -- 同意/拒绝
                local btnW3, btnH3 = 52, 30
                local accX = W - pad - btnW3 * 2 - 10
                local rejX = W - pad - btnW3
                local btnY3 = cy + (cardH - btnH3) / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, accX, btnY3, btnW3, btnH3, 6)
                nvgFillColor(vg, nvgRGBA(40, 100, 40, 220)); nvgFill(vg)
                nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(200, 255, 200, 255))
                nvgText(vg, accX + btnW3 / 2, btnY3 + btnH3 / 2, "同意", nil)
                menuBtnRects["friendAccept_" .. ri] = { x = accX, y = btnY3, w = btnW3, h = btnH3, fromUid = req.fromUid }
                nvgBeginPath(vg); nvgRoundedRect(vg, rejX, btnY3, btnW3, btnH3, 6)
                nvgFillColor(vg, nvgRGBA(100, 30, 30, 220)); nvgFill(vg)
                nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
                nvgText(vg, rejX + btnW3 / 2, btnY3 + btnH3 / 2, "拒绝", nil)
                menuBtnRects["friendReject_" .. ri] = { x = rejX, y = btnY3, w = btnW3, h = btnH3, fromUid = req.fromUid }
            end
            nvgRestore(vg)
            if #friendsUI.requests == 0 then
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                nvgText(vg, cx, bodyTop + 80, "暂无好友请求", nil)
            end
        end
    end

    -- 确认弹窗
    if friendsUI.confirmPopup then
        local pop = friendsUI.confirmPopup
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
        local popW, popH = 340, 160
        local popX, popY = cx - popW / 2, H / 2 - popH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 12)
        nvgFillColor(vg, nvgRGBA(25, 30, 40, 240)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 140, 200, 160)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 235, 255, 240))
        nvgText(vg, cx, popY + 50, pop.msg or "确认操作?", nil)
        local btnW4, btnH4 = 100, 38
        local yBtn2 = popY + popH - 50
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - btnW4 - 10, yBtn2, btnW4, btnH4, 6)
        nvgFillColor(vg, nvgRGBA(40, 100, 40, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(220, 255, 200, 255)); nvgFontSize(vg, 18)
        nvgText(vg, cx - btnW4 / 2 - 10, yBtn2 + btnH4 / 2, "确认", nil)
        menuBtnRects.friendPopupYes = { x = cx - btnW4 - 10, y = yBtn2, w = btnW4, h = btnH4 }
        nvgBeginPath(vg); nvgRoundedRect(vg, cx + 10, yBtn2, btnW4, btnH4, 6)
        nvgFillColor(vg, nvgRGBA(80, 30, 30, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
        nvgText(vg, cx + 10 + btnW4 / 2, yBtn2 + btnH4 / 2, "取消", nil)
        menuBtnRects.friendPopupNo = { x = cx + 10, y = yBtn2, w = btnW4, h = btnH4 }
    end
end


function DrawPowerRankScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0
    local curTab = welfareState.rankTab or "power"

    -- 1. 统一菜单背景（与首页一致）
    DrawSocialBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 2. 返回按钮（与天命赐福同款）
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    menuBtnRects.powerRankBack = { x = backX, y = backY, w = backW, h = backH }

    -- 3. 页签栏 (4个页签: 战力榜 / 职务榜 / 桩逼王 / 阵营榜)
    local tabW = 82
    local tabH = 36
    local tabGap = 5
    local tabCount = 4
    local totalTabW = tabW * tabCount + tabGap * (tabCount - 1)
    local tabStartX = cx - totalTabW / 2
    local tabY = 14

    local tabDefs = {
        { id = "power",   label = "战力榜",  colorA = {180,120,50},  colorS = {255,200,80},  colorT = {255,240,200} },
        { id = "realm",   label = "职务榜",  colorA = {80,50,160},   colorS = {180,140,255}, colorT = {220,200,255} },
        { id = "dummy",   label = "桩逼王",  colorA = {160,40,40},   colorS = {255,100,80},  colorT = {255,200,200} },
        { id = "faction", label = "阵营榜",  colorA = {40,100,140},  colorS = {80,180,220},  colorT = {200,240,255} },
    }
    for ti, td in ipairs(tabDefs) do
        local tx = tabStartX + (ti - 1) * (tabW + tabGap)
        local isActive = (curTab == td.id)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 6)
        if isActive then
            nvgFillColor(vg, nvgRGBA(td.colorA[1], td.colorA[2], td.colorA[3], 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(td.colorS[1], td.colorS[2], td.colorS[3], 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        else
            nvgFillColor(vg, nvgRGBA(40, 35, 30, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(90, 80, 60, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            nvgFillColor(vg, nvgRGBA(td.colorT[1], td.colorT[2], td.colorT[3], 255))
        else
            nvgFillColor(vg, nvgRGBA(180, 170, 150, 180))
        end
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, td.label, nil)
        menuBtnRects["rankTab_" .. td.id] = { x = tx, y = tabY, w = tabW, h = tabH }
    end

    -- 4. 我的信息（页签下方）
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if curTab == "power" then
        local myPower = CalcPlayerTotalPower()
        DrawWhiteInkText(cx, tabY + tabH + 16, "我的战力: " .. FormatPower(myPower))
    elseif curTab == "dummy" then
        local myBest = playerInfo.bestDummyDamage or 0
        DrawWhiteInkText(cx, tabY + tabH + 16, "我的最高伤害: " .. FormatPower(math.floor(myBest)))
    elseif curTab == "faction" then
        local fLvInfo = CloudManager.GetFactionLevelInfo()
        local fInfo = CloudManager.GetFactionInfo()
        local fName = (fInfo and fInfo.name and #fInfo.name > 0) and fInfo.name or "无阵营"
        DrawWhiteInkText(cx, tabY + tabH + 16, "我的阵营: " .. fName .. " (Lv." .. (fLvInfo.level or 1) .. ")")
    else
        local fInfoRank = CloudManager.GetFactionInfo()
        local myRoleRank = (fInfoRank and fInfoRank.name and #fInfoRank.name > 0) and (CloudManager.GetRoleName(fInfoRank.role) or "成员") or "无阵营"
        DrawWhiteInkText(cx, tabY + tabH + 16, "我的职务: " .. myRoleRank)
    end

    -- 5. 排行列表区域
    local listTop = tabY + tabH + 36
    local listBottom = H - 12
    local listH = listBottom - listTop
    local secPad = 16
    local secW = W - secPad * 2
    local rowH = 56
    local headerH = 44

    if curTab == "power" then
        -- ==================== 战力排行榜 ====================
        local powerData = welfareState.powerRank or {}
        local powerCount = #powerData
        local contentH = math.max(listH, headerH + powerCount * rowH + 20)

        local scrollOff = welfareState.powerScroll.offset
        local minScroll = math.min(0, listH - contentH)
        scrollOff = math.max(minScroll, math.min(0, scrollOff))
        welfareState.powerScroll.offset = scrollOff

        nvgSave(vg)
        nvgScissor(vg, 0, listTop, W, listH)
        local baseY = listTop + scrollOff

        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, baseY, secW, contentH, 10)
        nvgFillColor(vg, nvgRGBA(15, 12, 8, 190)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 80)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- 表头
        local hy = baseY + 8
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, hy, secW - 12, headerH - 4, 6)
        local headerGrad = nvgLinearGradient(vg, secPad, hy, secPad + secW, hy,
            nvgRGBA(80, 60, 30, 100), nvgRGBA(60, 45, 20, 60))
        nvgFillPaint(vg, headerGrad); nvgFill(vg)
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 140, 200))
        nvgText(vg, secPad + 30, hy + headerH / 2 - 2, "排名", nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, secPad + 60, hy + headerH / 2 - 2, "道号", nil)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, secPad + secW - 16, hy + headerH / 2 - 2, "战力", nil)

        nvgBeginPath(vg); nvgMoveTo(vg, secPad + 10, hy + headerH - 2); nvgLineTo(vg, secPad + secW - 10, hy + headerH - 2)
        nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        if welfareState.powerLoading and not welfareState.powerLoaded then
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, baseY + listH / 2, "加载中...")
        elseif powerCount == 0 then
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, baseY + listH / 2, "暂无数据，提升战力来上榜吧！")
        else
            local medals = {"[1]", "[2]", "[3]"}
            local rankColors = {
                nvgRGBA(255, 215, 80, 35),
                nvgRGBA(210, 210, 220, 25),
                nvgRGBA(200, 160, 90, 20),
            }
            for i, entry in ipairs(powerData) do
                local ry = baseY + headerH + 8 + (i - 1) * rowH
                if i <= 3 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 6)
                    nvgFillColor(vg, rankColors[i]); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(180, 145, 60, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                elseif i % 2 == 0 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 4)
                    nvgFillColor(vg, nvgRGBA(255, 240, 200, 6)); nvgFill(vg)
                end
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFontSize(vg, 28)
                    nvgText(vg, secPad + 30, ry + rowH / 2, medals[i], nil)
                else
                    nvgFontSize(vg, 22)
                    nvgFillColor(vg, nvgRGBA(180, 165, 130, 200))
                    nvgText(vg, secPad + 30, ry + rowH / 2, "#" .. i, nil)
                end
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 235, 175, 240))
                else nvgFillColor(vg, nvgRGBA(220, 210, 190, 220)) end
                nvgText(vg, secPad + 60, ry + rowH / 2, entry.name, nil)
                nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 200, 80, 240))
                else nvgFillColor(vg, nvgRGBA(220, 180, 100, 210)) end
                nvgText(vg, secPad + secW - 70, ry + rowH / 2, FormatPower(entry.power), nil)
                -- 查看按钮
                local vbW, vbH = 50, 28
                local vbX = secPad + secW - 60
                local vbY = ry + (rowH - vbH) / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, vbX, vbY, vbW, vbH, 5)
                nvgFillColor(vg, nvgRGBA(80, 60, 40, 180)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 230, 180, 220))
                nvgText(vg, vbX + vbW / 2, vbY + vbH / 2, "查看")
                welfareState.rankViewBtnRects[i] = { x = vbX, y = vbY, w = vbW, h = vbH, userId = entry.userId, filteredIdx = i }
                if i < powerCount then
                    nvgBeginPath(vg); nvgMoveTo(vg, secPad + 20, ry + rowH); nvgLineTo(vg, secPad + secW - 20, ry + rowH)
                    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 25)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                end
            end
        end
        nvgRestore(vg)

    elseif curTab == "realm" then
        -- ==================== 境界排行榜 ====================
        local realmData = welfareState.realmRank or {}
        local realmCount = #realmData
        local contentH = math.max(listH, headerH + realmCount * rowH + 20)

        local scrollOff = welfareState.realmScroll.offset
        local minScroll = math.min(0, listH - contentH)
        scrollOff = math.max(minScroll, math.min(0, scrollOff))
        welfareState.realmScroll.offset = scrollOff

        nvgSave(vg)
        nvgScissor(vg, 0, listTop, W, listH)
        local baseY = listTop + scrollOff

        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, baseY, secW, contentH, 10)
        nvgFillColor(vg, nvgRGBA(12, 8, 18, 190)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 50, 120, 80)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- 表头
        local hy = baseY + 8
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, hy, secW - 12, headerH - 4, 6)
        local headerGrad = nvgLinearGradient(vg, secPad, hy, secPad + secW, hy,
            nvgRGBA(60, 40, 80, 100), nvgRGBA(40, 30, 60, 60))
        nvgFillPaint(vg, headerGrad); nvgFill(vg)
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(190, 170, 220, 200))
        nvgText(vg, secPad + 30, hy + headerH / 2 - 2, "排名", nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, secPad + 60, hy + headerH / 2 - 2, "道号", nil)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, secPad + secW - 16, hy + headerH / 2 - 2, "职务", nil)

        nvgBeginPath(vg); nvgMoveTo(vg, secPad + 10, hy + headerH - 2); nvgLineTo(vg, secPad + secW - 10, hy + headerH - 2)
        nvgStrokeColor(vg, nvgRGBA(80, 50, 120, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        if welfareState.realmLoading and not welfareState.realmLoaded then
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, baseY + listH / 2, "加载中...")
        elseif realmCount == 0 then
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, baseY + listH / 2, "暂无数据，加入阵营来上榜吧！")
        else
            local medals = {"[1]", "[2]", "[3]"}
            local rankColors = {
                nvgRGBA(180, 140, 255, 35),
                nvgRGBA(210, 210, 220, 25),
                nvgRGBA(160, 130, 200, 20),
            }
            -- 境界颜色映射（与 PLAYER_REALMS 对应）
            local realmColors = {
                nvgRGBA(180, 175, 165, 220),  -- 新生 灰
                nvgRGBA(120, 200, 160, 230),  -- 侍僧 绿
                nvgRGBA(100, 170, 240, 240),  -- 巫师 蓝
                nvgRGBA(220, 180, 80, 240),   -- 领主 金
                nvgRGBA(255, 100, 100, 250),  -- 魔君 红
            }
            for i, entry in ipairs(realmData) do
                local ry = baseY + headerH + 8 + (i - 1) * rowH
                if i <= 3 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 6)
                    nvgFillColor(vg, rankColors[i]); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(140, 100, 200, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                elseif i % 2 == 0 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 4)
                    nvgFillColor(vg, nvgRGBA(200, 180, 255, 6)); nvgFill(vg)
                end
                -- 排名
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFontSize(vg, 28)
                    nvgText(vg, secPad + 30, ry + rowH / 2, medals[i], nil)
                else
                    nvgFontSize(vg, 22)
                    nvgFillColor(vg, nvgRGBA(170, 155, 200, 200))
                    nvgText(vg, secPad + 30, ry + rowH / 2, "#" .. i, nil)
                end
                -- 道号
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(230, 220, 255, 240))
                else nvgFillColor(vg, nvgRGBA(210, 200, 230, 220)) end
                nvgText(vg, secPad + 60, ry + rowH / 2, entry.name, nil)
                -- 境界名称（用对应境界颜色）
                local rIdx = entry.rankIdx or 1
                local layers = GameConfig.REALM_LAYERS or 10
                local realmIdx = math.ceil(rIdx / layers)
                local realmClr = realmColors[realmIdx] or nvgRGBA(200, 180, 160, 220)
                nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, realmClr)
                nvgText(vg, secPad + secW - 70, ry + rowH / 2, GetRankDisplayName(rIdx), nil)
                -- 查看按钮
                local vbW, vbH = 50, 28
                local vbX = secPad + secW - 60
                local vbY = ry + (rowH - vbH) / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, vbX, vbY, vbW, vbH, 5)
                nvgFillColor(vg, nvgRGBA(60, 40, 80, 180)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(150, 120, 200, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(220, 210, 255, 220))
                nvgText(vg, vbX + vbW / 2, vbY + vbH / 2, "查看")
                welfareState.rankViewBtnRects[i] = { x = vbX, y = vbY, w = vbW, h = vbH, userId = entry.userId, filteredIdx = i }
                -- 分隔线
                if i < realmCount then
                    nvgBeginPath(vg); nvgMoveTo(vg, secPad + 20, ry + rowH); nvgLineTo(vg, secPad + secW - 20, ry + rowH)
                    nvgStrokeColor(vg, nvgRGBA(80, 50, 120, 25)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                end
            end
        end
        nvgRestore(vg)

    elseif curTab == "dummy" then
        -- ==================== 桩逼王排行榜 ====================
        local dummyData = welfareState.dummyRank or {}
        local dummyCount = #dummyData
        local contentH = math.max(listH, headerH + dummyCount * rowH + 20)

        local scrollOff = welfareState.dummyScroll.offset
        local minScroll = math.min(0, listH - contentH)
        scrollOff = math.max(minScroll, math.min(0, scrollOff))
        welfareState.dummyScroll.offset = scrollOff

        nvgSave(vg)
        nvgScissor(vg, 0, listTop, W, listH)
        local baseY = listTop + scrollOff

        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, baseY, secW, contentH, 10)
        nvgFillColor(vg, nvgRGBA(18, 8, 8, 190)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(120, 45, 45, 80)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- 表头
        local hy = baseY + 8
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, hy, secW - 12, headerH - 4, 6)
        local headerGrad = nvgLinearGradient(vg, secPad, hy, secPad + secW, hy,
            nvgRGBA(80, 30, 30, 100), nvgRGBA(60, 20, 20, 60))
        nvgFillPaint(vg, headerGrad); nvgFill(vg)
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 180, 160, 200))
        nvgText(vg, secPad + 30, hy + headerH / 2 - 2, "排名", nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, secPad + 60, hy + headerH / 2 - 2, "道号", nil)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, secPad + secW - 16, hy + headerH / 2 - 2, "伤害", nil)

        nvgBeginPath(vg); nvgMoveTo(vg, secPad + 10, hy + headerH - 2); nvgLineTo(vg, secPad + secW - 10, hy + headerH - 2)
        nvgStrokeColor(vg, nvgRGBA(120, 45, 45, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        if welfareState.dummyLoading and not welfareState.dummyLoaded then
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, baseY + listH / 2, "加载中...")
        elseif dummyCount == 0 then
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, baseY + listH / 2, "暂无数据，去打桩挑战吧！")
        else
            local medals = {"[1]", "[2]", "[3]"}
            local rankColors = {
                nvgRGBA(255, 100, 80, 35),
                nvgRGBA(210, 210, 220, 25),
                nvgRGBA(200, 130, 100, 20),
            }
            for i, entry in ipairs(dummyData) do
                local ry = baseY + headerH + 8 + (i - 1) * rowH
                if i <= 3 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 6)
                    nvgFillColor(vg, rankColors[i]); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(200, 80, 60, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                elseif i % 2 == 0 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 4)
                    nvgFillColor(vg, nvgRGBA(255, 200, 200, 6)); nvgFill(vg)
                end
                -- 排名
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFontSize(vg, 28)
                    nvgText(vg, secPad + 30, ry + rowH / 2, medals[i], nil)
                else
                    nvgFontSize(vg, 22)
                    nvgFillColor(vg, nvgRGBA(200, 160, 140, 200))
                    nvgText(vg, secPad + 30, ry + rowH / 2, "#" .. i, nil)
                end
                -- 道号
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 220, 200, 240))
                else nvgFillColor(vg, nvgRGBA(220, 200, 190, 220)) end
                nvgText(vg, secPad + 60, ry + rowH / 2, entry.name, nil)
                -- 伤害数值
                nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 120, 80, 240))
                else nvgFillColor(vg, nvgRGBA(230, 150, 100, 210)) end
                nvgText(vg, secPad + secW - 70, ry + rowH / 2, FormatPower(entry.damage or 0), nil)
                -- 查看按钮
                local vbW, vbH = 50, 28
                local vbX = secPad + secW - 60
                local vbY = ry + (rowH - vbH) / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, vbX, vbY, vbW, vbH, 5)
                nvgFillColor(vg, nvgRGBA(80, 40, 40, 180)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(200, 120, 80, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 220, 180, 220))
                nvgText(vg, vbX + vbW / 2, vbY + vbH / 2, "查看")
                welfareState.rankViewBtnRects[i] = { x = vbX, y = vbY, w = vbW, h = vbH, userId = entry.userId, filteredIdx = i }
                -- 分隔线
                if i < dummyCount then
                    nvgBeginPath(vg); nvgMoveTo(vg, secPad + 20, ry + rowH); nvgLineTo(vg, secPad + secW - 20, ry + rowH)
                    nvgStrokeColor(vg, nvgRGBA(120, 45, 45, 25)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                end
            end
        end
        nvgRestore(vg)

    elseif curTab == "faction" then
        -- ==================== 阵营等级排行榜 ====================
        if not welfareState.factionRankLoaded and not welfareState.factionRankLoading then
            LoadFactionLevelRankForTab()
        end
        local factionData = welfareState.factionRank or {}
        local factionCount = #factionData
        local contentH = math.max(listH, headerH + factionCount * rowH + 20)

        local scrollOff = welfareState.factionRankScroll.offset
        local minScroll = math.min(0, listH - contentH)
        scrollOff = math.max(minScroll, math.min(0, scrollOff))
        welfareState.factionRankScroll.offset = scrollOff

        nvgSave(vg)
        nvgScissor(vg, 0, listTop, W, listH)
        local baseY = listTop + scrollOff

        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, baseY, secW, contentH, 10)
        nvgFillColor(vg, nvgRGBA(8, 15, 22, 190)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(50, 100, 140, 80)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- 表头
        local hy = baseY + 8
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, hy, secW - 12, headerH - 4, 6)
        local headerGrad = nvgLinearGradient(vg, secPad, hy, secPad + secW, hy,
            nvgRGBA(30, 60, 80, 100), nvgRGBA(20, 45, 60, 60))
        nvgFillPaint(vg, headerGrad); nvgFill(vg)
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 210, 240, 200))
        nvgText(vg, secPad + 30, hy + headerH / 2 - 2, "排名", nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, secPad + 60, hy + headerH / 2 - 2, "阵营", nil)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, secPad + secW - 16, hy + headerH / 2 - 2, "等级", nil)

        nvgBeginPath(vg); nvgMoveTo(vg, secPad + 10, hy + headerH - 2); nvgLineTo(vg, secPad + secW - 10, hy + headerH - 2)
        nvgStrokeColor(vg, nvgRGBA(50, 100, 140, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        if welfareState.factionRankLoading and not welfareState.factionRankLoaded then
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, baseY + listH / 2, "加载中...")
        elseif factionCount == 0 then
            nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, baseY + listH / 2, "暂无数据，创建阵营来上榜吧！")
        else
            local medals = {"[1]", "[2]", "[3]"}
            local rankColors = {
                nvgRGBA(80, 180, 220, 35),
                nvgRGBA(210, 210, 220, 25),
                nvgRGBA(100, 160, 200, 20),
            }
            local lvNames = { "新立", "初建", "崛起", "壮大", "兴盛", "鼎盛", "强盛", "霸业", "至尊", "无双" }
            for i, entry in ipairs(factionData) do
                local ry = baseY + headerH + 8 + (i - 1) * rowH
                if i <= 3 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 6)
                    nvgFillColor(vg, rankColors[i]); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(60, 140, 200, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                elseif i % 2 == 0 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 6, ry + 2, secW - 12, rowH - 4, 4)
                    nvgFillColor(vg, nvgRGBA(100, 200, 255, 6)); nvgFill(vg)
                end
                -- 排名
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFontSize(vg, 28)
                    nvgText(vg, secPad + 30, ry + rowH / 2, medals[i], nil)
                else
                    nvgFontSize(vg, 22)
                    nvgFillColor(vg, nvgRGBA(140, 190, 220, 200))
                    nvgText(vg, secPad + 30, ry + rowH / 2, "#" .. i, nil)
                end
                -- 阵营名
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(200, 240, 255, 240))
                else nvgFillColor(vg, nvgRGBA(180, 215, 235, 220)) end
                nvgText(vg, secPad + 60, ry + rowH / 2, entry.name or "?", nil)
                -- 等级
                local lvl = entry.level or 1
                local lvName = lvNames[lvl] or ("Lv." .. lvl)
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(80, 200, 255, 240))
                else nvgFillColor(vg, nvgRGBA(100, 180, 220, 210)) end
                nvgText(vg, secPad + secW - 16, ry + rowH / 2, "Lv." .. lvl .. " " .. lvName, nil)
                -- 分隔线
                if i < factionCount then
                    nvgBeginPath(vg); nvgMoveTo(vg, secPad + 20, ry + rowH); nvgLineTo(vg, secPad + secW - 20, ry + rowH)
                    nvgStrokeColor(vg, nvgRGBA(50, 100, 140, 25)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                end
            end
        end
        nvgRestore(vg)
    end

    -- ==================== 玩家详情弹窗 ====================
    if welfareState.rankViewPopup then
        local popup = welfareState.rankViewPopup
        local e = popup.entry
        -- 半透明遮罩
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
        -- 弹窗卡片
        local popW, popH = 360, 340
        local popX = (W - popW) / 2
        local popY = (H - popH) / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 12)
        nvgFillColor(vg, nvgRGBA(20, 18, 30, 245)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 12)
        nvgStrokeColor(vg, nvgRGBA(180, 140, 80, 120)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        -- 标题
        nvgFontSize(vg, 31)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, popY + 28, e.name or "未知")
        -- 排名
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(200, 180, 140, 200))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, cx, popY + 56, "排名: #" .. (e.rank or "?"))
        -- UID 行 + 复制按钮
        local uidY = popY + 78
        local uidStr = tostring(e.userId or 0)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 180))
        nvgText(vg, popX + 40, uidY, "UID: " .. uidStr, nil)
        -- 复制按钮
        local cpW, cpH = 56, 24
        local cpX = popX + popW - 40 - cpW
        local cpY2 = uidY - cpH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, cpX, cpY2, cpW, cpH, 4)
        if popup.copyFlash and popup.copyFlash > 0 then
            nvgFillColor(vg, nvgRGBA(60, 160, 80, 220)); nvgFill(vg)
            nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 255, 220, 240))
            nvgText(vg, cpX + cpW / 2, cpY2 + cpH / 2, "已复制", nil)
            popup.copyFlash = popup.copyFlash - (1.0 / 60.0)
        else
            nvgFillColor(vg, nvgRGBA(70, 60, 50, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 160, 220))
            nvgText(vg, cpX + cpW / 2, cpY2 + cpH / 2, "复制", nil)
        end
        popup.copyBtnRect = { x = cpX, y = cpY2, w = cpW, h = cpH }
        -- 信息行
        local infoStartY = popY + 100
        local lineH = 36
        local labelX = popX + 40
        local valX = popX + popW - 40
        local infos = {}
        if curTab == "dummy" and e.damage then
            infos = {
                { label = "打桩伤害", value = FormatPower(e.damage or 0), color = nvgRGBA(255, 120, 80, 240) },
                { label = "DPS", value = string.format("%.0f", (e.damage or 0) / 30), color = nvgRGBA(255, 200, 60, 240) },
                { label = "战力", value = FormatPower(e.power or 0), color = nvgRGBA(200, 180, 140, 220) },
            }
        else
            infos = {
                { label = "战力", value = FormatPower(e.power or 0), color = nvgRGBA(255, 200, 80, 240) },
                { label = "职务", value = GetRankDisplayName(e.realmIdx or 1), color = nvgRGBA(160, 200, 255, 240) },
                { label = "武技拥有", value = tostring(e.skillCount or 0) .. " 个", color = nvgRGBA(255, 160, 120, 240) },
                { label = "武灵收集", value = tostring(e.heroCount or 0) .. " 个", color = nvgRGBA(120, 220, 180, 240) },
            }
        end
        for j, info in ipairs(infos) do
            local ly = infoStartY + (j - 1) * lineH
            if j > 1 then
                nvgBeginPath(vg); nvgMoveTo(vg, popX + 20, ly - 4); nvgLineTo(vg, popX + popW - 20, ly - 4)
                nvgStrokeColor(vg, nvgRGBA(100, 80, 60, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
            end
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 170, 150, 200))
            nvgText(vg, labelX, ly + lineH / 2, info.label)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, info.color)
            nvgText(vg, valX, ly + lineH / 2, info.value)
        end
        -- 关闭按钮
        local cbW, cbH = 90, 36
        local cbX = cx - cbW / 2
        local cbY = popY + popH - 48
        nvgBeginPath(vg); nvgRoundedRect(vg, cbX, cbY, cbW, cbH, 6)
        local cbGrad = nvgLinearGradient(vg, cbX, cbY, cbX, cbY + cbH,
            nvgRGBA(120, 80, 40, 220), nvgRGBA(90, 60, 30, 220))
        nvgFillPaint(vg, cbGrad); nvgFill(vg)
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cbX + cbW / 2, cbY + cbH / 2, "关闭")
        popup.closeBtnRect = { x = cbX, y = cbY, w = cbW, h = cbH }
        popup.bgRect = { x = popX, y = popY, w = popW, h = popH }
    end

    -- 幽冥粒子（暖金色调，与首页一致）
    for i = 1, 6 do
        local px = W * (0.1 + 0.8 * ((i * 131 + math.floor(t * 16)) % 100) / 100)
        local py = H * (0.04 + 0.12 * math.sin(t * 0.5 + i * 1.5))
        local pr = 1 + math.sin(t * 1.8 + i) * 0.5
        local pa = math.floor(22 + 16 * math.sin(t * 1.3 + i * 0.9))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(220, 195, 140, pa)); nvgFill(vg)
    end
end
