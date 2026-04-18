local function FriendBtn(x, y, w, h, label, active)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, active and nvgRGBA(90, 60, 30, 220) or nvgRGBA(32, 34, 44, 210)); nvgFill(vg)
    nvgStrokeColor(vg, active and nvgRGBA(255, 180, 60, 180) or nvgRGBA(110, 130, 165, 120)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE); DrawWhiteInkText(x + w / 2, y + h / 2, label)
end

function DrawFriendsScreen()
    local W, H, cx, pad = DESIGN_W, DESIGN_H, DESIGN_W / 2, 14
    friendsUI.tab = friendsUI.tab or "list"
    friendsUI.searchId = friendsUI.searchId or ""
    friendsUI.friends = friendsUI.friends or {}
    friendsUI.requests = friendsUI.requests or {}
    friendsUI.recommended = friendsUI.recommended or {}
    DrawSocialBg(W, H); nvgFontFaceId(vg, GetMainFont())
    menuBtnRects.friendsBack = { x = 10, y = 10, w = 100, h = 44 }; FriendBtn(10, 10, 100, 44, "< Back", false)
    DrawWhiteInkText(cx, 32, "Friends")
    local tabs = { { id = "list", label = "List" }, { id = "add", label = "Add" }, { id = "requests", label = "Requests" } }
    local tabW = (W - pad * 2) / #tabs
    for i, tb in ipairs(tabs) do
        local x = pad + (i - 1) * tabW
        menuBtnRects["friendsTab_" .. tb.id] = { x = x + 2, y = 56, w = tabW - 4, h = 36 }
        FriendBtn(x + 2, 56, tabW - 4, 36, tb.label, friendsUI.tab == tb.id)
    end
    local bodyTop = 102

    if friendsUI.tab == "list" then
        if not friendsUI.loaded and not friendsUI.loading and CloudManager.GetFriendProfiles then
            friendsUI.loading = true
            CloudManager.GetFriendProfiles(function(friends) friendsUI.friends = friends or {}; friendsUI.loaded = true; friendsUI.loading = false end)
        end
        if friendsUI.loading then DrawWhiteInkText(cx, bodyTop + 80, "Loading...")
        elseif #(friendsUI.friends or {}) == 0 then DrawWhiteInkText(cx, bodyTop + 80, "No friends yet")
        else
            for i, fr in ipairs(friendsUI.friends or {}) do
                local y = bodyTop + (i - 1) * 70
                if y + 64 > H - 10 then break end
                nvgBeginPath(vg); nvgRoundedRect(vg, pad, y, W - pad * 2, 64, 8); nvgFillColor(vg, nvgRGBA(20, 25, 35, 210)); nvgFill(vg)
                nvgText(vg, pad + 14, y + 22, tostring(fr.nickname or ("Player " .. tostring(fr.userId or i))), nil)
                nvgText(vg, pad + 14, y + 44, "Power " .. tostring(fr.combatPower or 0), nil)
                menuBtnRects["friendDel_" .. i] = { x = W - pad - 66, y = y + 17, w = 56, h = 30, userId = fr.userId }
                FriendBtn(W - pad - 66, y + 17, 56, 30, "Del", false)
            end
        end
    elseif friendsUI.tab == "add" then
        nvgText(vg, pad + 8, bodyTop + 4, "Player ID:", nil)
        menuBtnRects.friendSearchInput = { x = pad, y = bodyTop + 22, w = W - pad * 2 - 80, h = 36 }
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, bodyTop + 22, W - pad * 2 - 80, 36, 6); nvgFillColor(vg, nvgRGBA(15, 15, 20, 220)); nvgFill(vg)
        nvgText(vg, pad + 10, bodyTop + 40, friendsUI.searchId ~= "" and friendsUI.searchId or "Tap to input", nil)
        menuBtnRects.friendSearchBtn = { x = W - pad - 70, y = bodyTop + 22, w = 70, h = 36 }
        FriendBtn(W - pad - 70, bodyTop + 22, 70, 36, "Search", true)
        local y = bodyTop + 72
        if friendsUI.searchResult then
            local sr = friendsUI.searchResult
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, y, W - pad * 2, 60, 8); nvgFillColor(vg, nvgRGBA(30, 40, 50, 210)); nvgFill(vg)
            nvgText(vg, pad + 14, y + 30, tostring(sr.nickname or ("Player " .. tostring(sr.userId or ""))), nil)
            if not (CloudManager.IsFriend and CloudManager.IsFriend(sr.userId)) then
                menuBtnRects.friendSearchAdd = { x = W - pad - 66, y = y + 15, w = 56, h = 30, userId = sr.userId }
                FriendBtn(W - pad - 66, y + 15, 56, 30, "Add", true)
            end
            y = y + 72
        elseif friendsUI.searchNotFound then
            DrawWhiteInkText(cx, y + 18, "Player not found")
            y = y + 36
        end
        nvgText(vg, pad + 4, y + 4, "Recommended:", nil)
        y = y + 26
        if not friendsUI.recLoaded and not friendsUI.recLoading and CloudManager.GetRandomPlayers then
            friendsUI.recLoading = true
            CloudManager.GetRandomPlayers(10, function(players) friendsUI.recommended = players or {}; friendsUI.recLoaded = true; friendsUI.recLoading = false end)
        end
        for i, rp in ipairs(friendsUI.recommended or {}) do
            local cy = y + (i - 1) * 58
            if cy + 54 > H - 10 then break end
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, 54, 7); nvgFillColor(vg, nvgRGBA(20, 25, 35, 200)); nvgFill(vg)
            nvgText(vg, pad + 12, cy + 27, tostring(rp.nickname or ("Player " .. tostring(rp.userId or ""))), nil)
            if not (CloudManager.IsFriend and CloudManager.IsFriend(rp.userId)) then
                menuBtnRects["friendRecAdd_" .. i] = { x = W - pad - 66, y = cy + 13, w = 56, h = 28, userId = rp.userId }
                FriendBtn(W - pad - 66, cy + 13, 56, 28, "Add", true)
            end
        end
    else
        if not friendsUI.reqLoaded and not friendsUI.reqLoading and CloudManager.CheckIncomingRequests then
            friendsUI.reqLoading = true
            CloudManager.CheckIncomingRequests(function(reqs) friendsUI.requests = reqs or {}; friendsUI.reqLoaded = true; friendsUI.reqLoading = false end)
        end
        if friendsUI.reqLoading then DrawWhiteInkText(cx, bodyTop + 80, "Loading requests...")
        elseif #(friendsUI.requests or {}) == 0 then DrawWhiteInkText(cx, bodyTop + 80, "No requests")
        else
            for i, req in ipairs(friendsUI.requests or {}) do
                local y = bodyTop + (i - 1) * 62
                if y + 56 > H - 10 then break end
                nvgBeginPath(vg); nvgRoundedRect(vg, pad, y, W - pad * 2, 56, 8); nvgFillColor(vg, nvgRGBA(20, 25, 35, 210)); nvgFill(vg)
                nvgText(vg, pad + 14, y + 28, tostring(req.nickname or ("Player " .. tostring(req.fromUid or i))), nil)
                menuBtnRects["friendAccept_" .. i] = { x = W - pad - 122, y = y + 13, w = 52, h = 30, fromUid = req.fromUid }
                menuBtnRects["friendReject_" .. i] = { x = W - pad - 56, y = y + 13, w = 52, h = 30, fromUid = req.fromUid }
                FriendBtn(W - pad - 122, y + 13, 52, 30, "Yes", true)
                FriendBtn(W - pad - 56, y + 13, 52, 30, "No", false)
            end
        end
    end

    if not friendsUI.confirmPopup then return end
    local px, py, pw, ph = 40, H / 2 - 90, W - 80, 180
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H); nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 10); nvgFillColor(vg, nvgRGBA(28, 24, 34, 245)); nvgFill(vg)
    DrawWhiteInkText(cx, py + 30, tostring(friendsUI.confirmPopup.title or "Confirm"))
    nvgText(vg, cx, py + 76, tostring(friendsUI.confirmPopup.msg or ""), nil)
    menuBtnRects.friendPopupYes = { x = cx - 120, y = py + ph - 50, w = 110, h = 38 }
    menuBtnRects.friendPopupNo = { x = cx + 10, y = py + ph - 50, w = 110, h = 38 }
    FriendBtn(cx - 120, py + ph - 50, 110, 38, "Confirm", true)
    FriendBtn(cx + 10, py + ph - 50, 110, 38, "Cancel", false)
end
