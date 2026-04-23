local function FactionLooksGarbage(text)
    return type(text) == "string" and string.find(text, "[闂傚☉閺夐柛閻忕紒婵濡崗]")
end

local function FactionSafeText(text, fallback)
    if type(text) ~= "string" or text == "" or FactionLooksGarbage(text) then return fallback end
    return text
end

local function FactionButton(x, y, w, h, label, active)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, active and nvgRGBA(90, 60, 30, 220) or nvgRGBA(32, 34, 44, 210)); nvgFill(vg)
    nvgStrokeColor(vg, active and nvgRGBA(255, 180, 60, 180) or nvgRGBA(110, 130, 165, 120)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE); DrawWhiteInkText(x + w / 2, y + h / 2, label)
end

local function FactionPanel(x, y, w, h)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 10)
    nvgFillColor(vg, nvgRGBA(20, 20, 30, 215)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 110, 150, 110)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
end

local function FactionRoleName(role)
    if rawget(_G, "CloudManager") and CloudManager.GetRoleName then
        local ok, name = pcall(CloudManager.GetRoleName, role)
        if ok and type(name) == "string" and name ~= "" and not FactionLooksGarbage(name) then return name end
    end
    local map = { leader = "盟主", vice_leader = "副盟主", strategist = "军师", vanguard = "先锋", diplomat = "外交官", elite = "精英", member = "成员" }
    return map[role] or "成员"
end

local function FactionRoleLevel(role)
    if rawget(_G, "CloudManager") and CloudManager.GetRoleLevel then
        local ok, lv = pcall(CloudManager.GetRoleLevel, role)
        if ok and type(lv) == "number" then return lv end
    end
    local map = { leader = 6, vice_leader = 5, strategist = 4, vanguard = 3, diplomat = 2, elite = 1, member = 0 }
    return map[role] or 0
end

local function ResetFactionRects()
    for i = 1, 50 do
        menuBtnRects["factionApply_" .. i] = nil
        menuBtnRects["factionAccept_" .. i] = nil
        menuBtnRects["factionReject_" .. i] = nil
        menuBtnRects["factionDonateAmt_" .. i] = nil
    end
    for _, key in ipairs({
        "factionBack","factionSubBack","factionRankBtn","factionRankClose","factionRankOverlay",
        "factionDonate","factionAnnounceInput","factionAnnounceSave","factionRefreshApply",
        "factionNameInput","factionDescInput","factionCreate","factionRename","factionLeave",
        "factionPopupYes","factionPopupNo","factionRenameYes","factionRenameNo","factionRenameInput",
        "factionChatInput","factionChatSend","factionTab_info","factionTab_members","factionTab_chat",
        "factionTab_apply","factionTab_list","factionTab_create"
    }) do menuBtnRects[key] = nil end
    for _, id in ipairs({ "manage", "chat", "upgrade", "donate", "signIn", "announce", "rank", "contrib" }) do
        menuBtnRects["factionFeat_" .. id] = nil
    end
end

local function DrawFactionRankOverlay(W, H)
    local cx = W / 2
    if not factionUI.rankLoaded and not factionUI.rankLoading and rawget(_G, "LoadFactionLevelRank") then LoadFactionLevelRank() end
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H); nvgFillColor(vg, nvgRGBA(0, 0, 0, 175)); nvgFill(vg)
    menuBtnRects.factionRankOverlay = { x = 0, y = 0, w = W, h = H }
    local px, py, pw, ph = 40, 45, W - 80, H - 90
    FactionPanel(px, py, pw, ph)
    DrawWhiteInkText(cx, py + 30, "联盟排行")
    menuBtnRects.factionRankClose = { x = cx - 45, y = py + ph - 46, w = 90, h = 36 }
    FactionButton(cx - 45, py + ph - 46, 90, 36, "关闭", false)
    local rows = factionUI.rankList or {}
    if factionUI.rankLoading then DrawWhiteInkText(cx, py + ph / 2, "加载中..."); return end
    if #rows == 0 then DrawWhiteInkText(cx, py + ph / 2, "暂无排行数据"); return end
    for i, entry in ipairs(rows) do
        local y = py + 70 + (i - 1) * 36
        if y + 36 > py + ph - 58 then break end
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE); nvgFillColor(vg, nvgRGBA(255, 220, 140, 230))
        nvgText(vg, px + 16, y + 18, "#" .. i, nil); nvgFillColor(vg, nvgRGBA(230, 230, 235, 230))
        nvgText(vg, px + 70, y + 18, FactionSafeText(entry.name, "联盟 " .. i), nil); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, px + pw - 16, y + 18, "Lv." .. tostring(entry.level or 1), nil)
    end
end

function DrawFactionSubView(W, H, bodyTop, pad, cx, info)
    local top = bodyTop + 48
    menuBtnRects.factionSubBack = { x = pad, y = bodyTop + 4, w = 80, h = 32 }
    FactionButton(pad, bodyTop + 4, 80, 32, "< 返回", false)
    local panelW = W - pad * 2
    if factionUI.subView == "upgrade" then
        local lvInfo = CloudManager.GetFactionLevelInfo and CloudManager.GetFactionLevelInfo() or { level = 1, exp = 0, nextLevelExp = 100, buffPercent = 2 }
        FactionPanel(pad, top, panelW, 210)
        DrawWhiteInkText(cx, top + 24, "联盟升级")
        DrawWhiteInkText(cx, top + 66, "Lv." .. tostring(lvInfo.level or 1))
        nvgText(vg, cx, top + 106, "战力加成 +" .. tostring(lvInfo.buffPercent or 0) .. "%", nil)
        nvgText(vg, cx, top + 138, tostring(lvInfo.exp or 0) .. " / " .. tostring(lvInfo.nextLevelExp or 0), nil)
        nvgText(vg, cx, top + 166, "捐献可获得经验", nil)
        menuBtnRects.factionRankBtn = { x = cx - 85, y = top + 180, w = 170, h = 34 }
        FactionButton(cx - 85, top + 180, 170, 34, "查看排行", false)
        return
    end
    if factionUI.subView == "donate" then
        FactionPanel(pad, top, panelW, 250)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP); nvgFillColor(vg, nvgRGBA(220, 210, 190, 220))
        nvgText(vg, pad + 18, top + 18, "玉璧: " .. tostring(playerInfo.jade or 0), nil)
        nvgText(vg, pad + 18, top + 46, "我的贡献: " .. tostring(CloudManager.GetMyContribution and CloudManager.GetMyContribution() or 0), nil)
        nvgText(vg, pad + 18, top + 74, "联盟资金: " .. tostring(CloudManager.GetFactionFunds and CloudManager.GetFactionFunds() or 0), nil)
        nvgText(vg, cx, top + 116, "选择捐献数量", nil)
        local amounts, btnW, y = { 100, 300, 500, 1000 }, math.floor((panelW - 48) / 4), top + 136
        for i, amt in ipairs(amounts) do
            local x = pad + 12 + (i - 1) * (btnW + 8)
            menuBtnRects["factionDonateAmt_" .. i] = { x = x, y = y, w = btnW, h = 34, amount = amt }
            FactionButton(x, y, btnW, 34, tostring(amt), factionUI.donateAmount == amt)
        end
        menuBtnRects.factionDonate = { x = cx - 90, y = top + 188, w = 180, h = 42 }
        FactionButton(cx - 90, top + 188, 180, 42, factionUI.donating and "处理中..." or ("捐献 " .. tostring(factionUI.donateAmount or 0)), not factionUI.donating)
        return
    end
    if factionUI.subView == "announce" then
        FactionPanel(pad, top, panelW, 190)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP); nvgFillColor(vg, nvgRGBA(210, 210, 220, 220))
        nvgText(vg, pad + 14, top + 12, "公告:", nil)
        nvgText(vg, pad + 14, top + 38, FactionSafeText(CloudManager.GetFactionAnnouncement and CloudManager.GetFactionAnnouncement() or "", "暂无公告"), nil)
        menuBtnRects.factionAnnounceInput = { x = pad + 12, y = top + 104, w = panelW - 24, h = 40 }
        FactionPanel(pad + 12, top + 104, panelW - 24, 40)
        nvgText(vg, pad + 22, top + 126, factionUI.announceInput ~= "" and factionUI.announceInput or "点击输入", nil)
        menuBtnRects.factionAnnounceSave = { x = cx - 60, y = top + 152, w = 120, h = 38 }
        FactionButton(cx - 60, top + 152, 120, 38, "保存", true)
        return
    end
    if factionUI.subView == "contrib" then
        if not factionUI.contribLoaded and not factionUI.contribLoading then
            factionUI.contribLoading = true
            factionUI.contribList = CloudManager.GetContributionRank and (CloudManager.GetContributionRank() or {}) or {}
            factionUI.contribLoaded = true
            factionUI.contribLoading = false
        end
        FactionPanel(pad, top, panelW, H - top - 18)
        if factionUI.contribLoading then DrawWhiteInkText(cx, top + 80, "加载中..."); return end
        if #(factionUI.contribList or {}) == 0 then DrawWhiteInkText(cx, top + 80, "暂无贡献数据"); return end
        for i, entry in ipairs(factionUI.contribList or {}) do
            local y = top + 12 + (i - 1) * 38
            if y + 38 > H - 26 then break end
            nvgText(vg, pad + 12, y + 18, "#" .. i, nil)
            nvgText(vg, pad + 60, y + 18, FactionSafeText(entry.name, "成员 " .. tostring(entry.uid or i)), nil)
            nvgText(vg, pad + panelW - 16, y + 18, tostring(entry.amount or 0), nil)
        end
        return
    end
    DrawWhiteInkText(cx, top + 40, "功能整理中")
end

function DrawFactionScreen()
    local W, H, cx, pad = DESIGN_W, DESIGN_H, DESIGN_W / 2, 14
    factionUI.tab = factionUI.tab or "list"
    factionUI.chatInput = factionUI.chatInput or ""
    factionUI.announceInput = factionUI.announceInput or ""
    factionUI.createName = factionUI.createName or ""
    factionUI.createDesc = factionUI.createDesc or ""
    factionUI.renameInput = factionUI.renameInput or ""
    factionUI.donateAmount = factionUI.donateAmount or 100
    DrawSocialBg(W, H); nvgFontFaceId(vg, GetMainFont()); ResetFactionRects()
    menuBtnRects.factionBack = { x = 10, y = 10, w = 100, h = 44 }; FactionButton(10, 10, 100, 44, "< 返回", false)
    DrawWhiteInkText(cx, 32, "联盟")

    if factionUI.renamePopup then
        local pw, ph = W - 220, 190
        local px, py = cx - pw / 2, H / 2 - ph / 2
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H); nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg); FactionPanel(px, py, pw, ph)
        DrawWhiteInkText(cx, py + 30, "重命名联盟")
        nvgText(vg, cx, py + 56, "花费: 1000 玉璧", nil)
        menuBtnRects.factionRenameInput = { x = px + 24, y = py + 76, w = pw - 48, h = 38 }
        FactionPanel(px + 24, py + 76, pw - 48, 38); nvgText(vg, px + 34, py + 95, factionUI.renameInput or "", nil)
        menuBtnRects.factionRenameYes = { x = cx - 120, y = py + ph - 50, w = 110, h = 38 }
        menuBtnRects.factionRenameNo = { x = cx + 10, y = py + ph - 50, w = 110, h = 38 }
        FactionButton(menuBtnRects.factionRenameYes.x, menuBtnRects.factionRenameYes.y, 110, 38, "确认", true)
        FactionButton(menuBtnRects.factionRenameNo.x, menuBtnRects.factionRenameNo.y, 110, 38, "取消", false)
    end
    if factionUI.confirmPopup then
        local pw, ph = W - 180, 160
        local px, py = cx - pw / 2, H / 2 - ph / 2
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H); nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg); FactionPanel(px, py, pw, ph)
        DrawWhiteInkText(cx, py + 46, FactionSafeText(factionUI.confirmPopup.msg, "确认此操作?"))
        menuBtnRects.factionPopupYes = { x = cx - 120, y = py + ph - 52, w = 110, h = 38 }
        menuBtnRects.factionPopupNo = { x = cx + 10, y = py + ph - 52, w = 110, h = 38 }
        FactionButton(menuBtnRects.factionPopupYes.x, menuBtnRects.factionPopupYes.y, 110, 38, "确认", true)
        FactionButton(menuBtnRects.factionPopupNo.x, menuBtnRects.factionPopupNo.y, 110, 38, "取消", false)
    end

    local info = CloudManager.GetFactionInfo and CloudManager.GetFactionInfo() or nil
    local hasFaction = info and info.id and info.id > 0
    local contentTop = 64
    if hasFaction then
        local tabs = { { id = "info", label = "信息" }, { id = "members", label = "成员" }, { id = "chat", label = "聊天" } }
        local myLevel = FactionRoleLevel(info.role)
        if myLevel >= 5 then table.insert(tabs, { id = "apply", label = "申请" }) end
        if factionUI.tab ~= "info" and factionUI.tab ~= "members" and factionUI.tab ~= "chat" and factionUI.tab ~= "apply" then factionUI.tab = "info" end
        local tabW = (W - pad * 2) / #tabs
        for i, tb in ipairs(tabs) do
            local x = pad + (i - 1) * tabW
            menuBtnRects["factionTab_" .. tb.id] = { x = x + 2, y = contentTop, w = tabW - 4, h = 38 }
            FactionButton(x + 2, contentTop, tabW - 4, 38, tb.label, factionUI.tab == tb.id)
        end
        local bodyTop = contentTop + 48
        if factionUI.subView then
            DrawFactionSubView(W, H, bodyTop, pad, cx, info)
        elseif factionUI.tab == "info" then
            FactionPanel(pad, bodyTop, W - pad * 2, 180)
            DrawWhiteInkText(cx, bodyTop + 22, FactionSafeText(info.name, "未知联盟"))
            nvgText(vg, pad + 14, bodyTop + 56, "职位: " .. FactionRoleName(info.role), nil)
            nvgText(vg, pad + 14, bodyTop + 84, "盟主: " .. FactionSafeText(factionUI.leaderNickname or info.leaderName, "未知"), nil)
            nvgText(vg, pad + 14, bodyTop + 112, "资金: " .. tostring(CloudManager.GetFactionFunds and CloudManager.GetFactionFunds() or 0), nil)
            nvgText(vg, pad + 14, bodyTop + 140, "公告: " .. FactionSafeText(CloudManager.GetFactionAnnouncement and CloudManager.GetFactionAnnouncement() or "", "无"), nil)
            menuBtnRects.factionLeave = { x = cx - 70, y = bodyTop + 190, w = 140, h = 38 }
            FactionButton(cx - 70, bodyTop + 190, 140, 38, info.role == "leader" and "解散" or "退出", false)
            if myLevel >= 5 then menuBtnRects.factionRename = { x = pad, y = bodyTop + 190, w = 140, h = 38 }; FactionButton(pad, bodyTop + 190, 140, 38, "重命名", false) end
            local feats = {
                { id = "manage", label = "管理" }, { id = "chat", label = "聊天" }, { id = "upgrade", label = "升级" }, { id = "donate", label = "捐献" },
                { id = "signIn", label = (CloudManager.HasSignedInToday and CloudManager.HasSignedInToday()) and "已签到" or "签到" },
                { id = "announce", label = "公告" }, { id = "rank", label = "排行" }, { id = "contrib", label = "贡献" }
            }
            local btnW = math.floor((W - pad * 2 - 24) / 4)
            for i, feat in ipairs(feats) do
                local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
                local x, y = pad + col * (btnW + 8), bodyTop + 276 + row * 64
                menuBtnRects["factionFeat_" .. feat.id] = { x = x, y = y, w = btnW, h = 56 }
                FactionButton(x, y, btnW, 56, feat.label, false)
            end
        elseif factionUI.tab == "members" then
            if not factionUI.loaded and not factionUI.loading and CloudManager.GetFactionMembers then
                factionUI.loading = true
                CloudManager.GetFactionMembers(function(members) factionUI.members = members or {}; factionUI.loaded = true; factionUI.loading = false end)
            end
            if factionUI.loading then DrawWhiteInkText(cx, bodyTop + 60, "加载中...")
            elseif #(factionUI.members or {}) == 0 then DrawWhiteInkText(cx, bodyTop + 60, "暂无成员")
            else
                for i, mem in ipairs(factionUI.members or {}) do
                    local y = bodyTop + (i - 1) * 62
                    if y + 56 > H - 10 then break end
                    FactionPanel(pad, y, W - pad * 2, 56)
                    nvgText(vg, pad + 14, y + 20, FactionSafeText(mem.nickname, "玩家 " .. tostring(mem.userId or i)), nil)
                    nvgText(vg, pad + 14, y + 40, FactionRoleName(CloudManager.GetMemberRole and CloudManager.GetMemberRole(mem.userId) or mem.role), nil)
                end
            end
        elseif factionUI.tab == "apply" then
            if not factionUI.applyLoaded and not factionUI.applyLoading and CloudManager.CheckFactionApplications then
                factionUI.applyLoading = true
                CloudManager.CheckFactionApplications(function(apps) factionUI.applications = apps or {}; factionUI.applyLoaded = true; factionUI.applyLoading = false end)
            end
            if factionUI.applyLoading then DrawWhiteInkText(cx, bodyTop + 60, "加载中...")
            elseif #(factionUI.applications or {}) == 0 then DrawWhiteInkText(cx, bodyTop + 60, "暂无申请")
            else
                for i, app in ipairs(factionUI.applications or {}) do
                    local y = bodyTop + (i - 1) * 62
                    if y + 56 > H - 10 then break end
                    FactionPanel(pad, y, W - pad * 2, 56)
                    nvgText(vg, pad + 14, y + 28, FactionSafeText(app.nickname, "玩家 " .. tostring(app.userId or i)), nil)
                    menuBtnRects["factionAccept_" .. i] = { x = W - pad - 122, y = y + 13, w = 56, h = 30, userId = app.userId }
                    menuBtnRects["factionReject_" .. i] = { x = W - pad - 56, y = y + 13, w = 56, h = 30, userId = app.userId }
                    FactionButton(W - pad - 122, y + 13, 56, 30, "同意", true)
                    FactionButton(W - pad - 56, y + 13, 56, 30, "拒绝", false)
                end
            end
        else
            local chatAreaH = H - bodyTop - 70
            FactionPanel(pad, bodyTop, W - pad * 2, chatAreaH)
            local msgs = CloudManager.GetFactionChatMessages and CloudManager.GetFactionChatMessages() or {}
            if #msgs == 0 then DrawWhiteInkText(cx, bodyTop + chatAreaH / 2, "暂无聊天记录")
            else
                local startIdx = math.max(1, #msgs - 7)
                for i = startIdx, #msgs do
                    local msg, y = msgs[i], bodyTop + 16 + (i - startIdx) * 28
                    nvgText(vg, pad + 12, y, FactionSafeText(msg.senderName or msg.name, "成员") .. ": " .. FactionSafeText(msg.text, ""), nil)
                end
            end
            menuBtnRects.factionChatInput = { x = pad, y = H - 46, w = W - pad * 2 - 90, h = 34 }
            menuBtnRects.factionChatSend = { x = W - pad - 80, y = H - 46, w = 80, h = 34 }
            FactionPanel(pad, H - 46, W - pad * 2 - 90, 34)
            nvgText(vg, pad + 10, H - 29, factionUI.chatInput ~= "" and factionUI.chatInput or "点击输入", nil)
            FactionButton(W - pad - 80, H - 46, 80, 34, "发送", true)
        end
        if factionUI.showRank then DrawFactionRankOverlay(W, H) end
        return
    end

    if factionUI.tab ~= "list" and factionUI.tab ~= "create" then factionUI.tab = "list" end
    local tabW = (W - pad * 2) / 2
    menuBtnRects.factionTab_list = { x = pad + 2, y = contentTop, w = tabW - 4, h = 38 }
    menuBtnRects.factionTab_create = { x = pad + tabW + 2, y = contentTop, w = tabW - 4, h = 38 }
    FactionButton(pad + 2, contentTop, tabW - 4, 38, "联盟列表", factionUI.tab == "list")
    FactionButton(pad + tabW + 2, contentTop, tabW - 4, 38, "创建", factionUI.tab == "create")
    local bodyTop = contentTop + 48
    if factionUI.tab == "list" then
        if not factionUI.loaded and not factionUI.loading and CloudManager.ListFactions then
            factionUI.loading = true
            CloudManager.ListFactions(function(factions) factionUI.factions = factions or {}; factionUI.loaded = true; factionUI.loading = false end)
        end
        if factionUI.applyStatus == "pending" then
            menuBtnRects.factionRefreshApply = { x = cx - 55, y = bodyTop, w = 110, h = 36 }
            FactionButton(cx - 55, bodyTop, 110, 36, "刷新", false)
            nvgText(vg, cx, bodyTop + 54, "申请处理中...", nil)
            bodyTop = bodyTop + 84
        end
        if factionUI.loading then DrawWhiteInkText(cx, bodyTop + 80, "加载联盟列表...")
        elseif #(factionUI.factions or {}) == 0 then DrawWhiteInkText(cx, bodyTop + 80, "暂无联盟")
        else
            for i, fac in ipairs(factionUI.factions or {}) do
                local y = bodyTop + (i - 1) * 86
                if y + 78 > H - 10 then break end
                FactionPanel(pad, y, W - pad * 2, 78)
                nvgText(vg, pad + 12, y + 10, FactionSafeText(fac.name, "联盟 " .. i), nil)
                nvgText(vg, pad + 12, y + 40, "Lv." .. tostring(fac.level or 1), nil)
                nvgText(vg, pad + 120, y + 40, "成员 " .. tostring(fac.memberCount or 0), nil)
                menuBtnRects["factionApply_" .. i] = { x = W - pad - 104, y = y + 22, w = 92, h = 34, campId = fac.id, campName = fac.name }
                FactionButton(W - pad - 104, y + 22, 92, 34, "申请", true)
            end
        end
    else
        FactionPanel(pad, bodyTop, W - pad * 2, 200)
        DrawWhiteInkText(cx, bodyTop + 26, "创建联盟")
        nvgText(vg, cx, bodyTop + 52, "花费: 5000 玉璧", nil)
        menuBtnRects.factionNameInput = { x = pad + 12, y = bodyTop + 74, w = W - pad * 2 - 24, h = 38 }
        menuBtnRects.factionDescInput = { x = pad + 12, y = bodyTop + 126, w = W - pad * 2 - 24, h = 38 }
        FactionPanel(menuBtnRects.factionNameInput.x, menuBtnRects.factionNameInput.y, menuBtnRects.factionNameInput.w, 38)
        FactionPanel(menuBtnRects.factionDescInput.x, menuBtnRects.factionDescInput.y, menuBtnRects.factionDescInput.w, 38)
        nvgText(vg, pad + 22, bodyTop + 93, factionUI.createName ~= "" and factionUI.createName or "点击输入联盟名", nil)
        nvgText(vg, pad + 22, bodyTop + 145, factionUI.createDesc ~= "" and factionUI.createDesc or "点击输入联盟简介", nil)
        menuBtnRects.factionCreate = { x = cx - 75, y = bodyTop + 184, w = 150, h = 40 }
        FactionButton(cx - 75, bodyTop + 184, 150, 40, "创建", true)
    end
end
