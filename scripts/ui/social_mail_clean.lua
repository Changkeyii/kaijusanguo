local function MailLooksGarbage(text)
    return type(text) == "string" and string.find(text, "[闂傚☉閺夐柛閻忕紒婵濡崗]")
end

local function MailSafeText(text, fallback)
    if type(text) ~= "string" or text == "" or MailLooksGarbage(text) then
        return fallback
    end
    return text
end

local function MailRewardLabel(rw)
    if not rw then return "Reward" end
    if rw.type == "jade" then return "Jade x" .. tostring(rw.amount or 0) end
    if rw.type == "ad_free" then return "No-Ads Pass" end
    if rw.type == "full_skill" then
        local techniques = rawget(_G, "SKILL_TECHNIQUES")
        local skillName = techniques and rw.skillIdx and techniques[rw.skillIdx] and techniques[rw.skillIdx].name
        return "Full Skill: " .. MailSafeText(skillName, "Skill " .. tostring(rw.skillIdx or ""))
    end
    if rw.type == "seal" then return "Seal Reward" end
    return MailSafeText(rw.label, "Reward")
end

local function DrawMailButton(x, y, w, h, label, active)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, active and nvgRGBA(110, 72, 38, 220) or nvgRGBA(34, 36, 48, 210)); nvgFill(vg)
    nvgStrokeColor(vg, active and nvgRGBA(255, 196, 96, 150) or nvgRGBA(110, 120, 150, 110)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE); DrawWhiteInkText(x + w / 2, y + h / 2, label)
end

local function DrawMailBackButton(x, y, w, h)
    DrawMailButton(x, y, w, h, "< Back", false)
end

local function GetSystemMailMeta(mail, idx)
    if not mail then return "System Mail", "System" end
    if mail.id == "welcome_gift" then return "Welcome Gift", "Dev Team" end
    if mail.id == "self_recommend" then return "Letter", "Dev Team" end
    return MailSafeText(mail.title, "System Mail " .. tostring(idx or "")), MailSafeText(mail.sender, "System")
end

function DrawContribRankScreen()
    local W, H, cx = DESIGN_W, DESIGN_H, DESIGN_W / 2
    DrawSocialBg(W, H); nvgFontFaceId(vg, GetMainFont())
    DrawMailBackButton(10, 10, 100, 44); menuBtnRects.contribRankBack = { x = 10, y = 10, w = 100, h = 44 }
    nvgFontSize(vg, 39); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE); DrawWhiteInkText(cx, 32, "Support Rank")
    nvgFontSize(vg, 24); DrawWhiteInkText(cx, 58, "Thanks for every bit of support")
    local listTop, listBottom, pad, panelW, rowH = 80, H - 12, 16, W - 32, 56
    local data = welfareState.contribRank or {}
    nvgBeginPath(vg); nvgRoundedRect(vg, pad, listTop, panelW, listBottom - listTop, 10)
    nvgFillColor(vg, nvgRGBA(15, 12, 8, 190)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 80)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE); nvgFillColor(vg, nvgRGBA(220, 190, 140, 220))
    nvgText(vg, pad + 30, listTop + 28, "No.", nil); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE); nvgText(vg, pad + 60, listTop + 28, "Player", nil)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE); nvgText(vg, pad + panelW - 16, listTop + 28, "Count", nil)
    if welfareState.contribLoading and not welfareState.contribLoaded then DrawWhiteInkText(cx, listTop + 120, "Loading..."); return end
    if #data == 0 then DrawWhiteInkText(cx, listTop + 120, "No data yet"); return end
    for i, entry in ipairs(data) do
        local y = listTop + 44 + (i - 1) * rowH
        if y + rowH > listBottom then break end
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE); nvgFillColor(vg, nvgRGBA(230, 230, 235, 230))
        nvgText(vg, pad + 16, y + 26, "#" .. tostring(i), nil)
        nvgText(vg, pad + 60, y + 26, MailSafeText(entry.name, "Player " .. tostring(i)), nil)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE); nvgText(vg, pad + panelW - 16, y + 26, tostring(entry.count or 0), nil)
    end
end

function DrawMailBoxScreen()
    local W, H, cx = DESIGN_W, DESIGN_H, DESIGN_W / 2
    welfareState.mail = welfareState.mail or {}
    local ms = welfareState.mail
    ms.claimed = ms.claimed or {}
    ms.tab = ms.tab or "system"
    ms.btnRects = {}
    ms.cloudBtnRects = {}
    DrawSocialBg(W, H); nvgFontFaceId(vg, GetMainFont())
    DrawMailBackButton(10, 10, 100, 44); menuBtnRects.mailBack = { x = 10, y = 10, w = 100, h = 44 }
    nvgFontSize(vg, 30); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE); DrawWhiteInkText(cx, 32, "Mail")
    local uid = CloudAPI and CloudAPI.GetUserId and CloudAPI.GetUserId() or 0
    local isAdmin = CloudManager.IsAdmin and CloudManager.IsAdmin()
    nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP); nvgFillColor(vg, nvgRGBA(100, 100, 110, 140)); nvgText(vg, W - 10, 6, "UID:" .. tostring(uid), nil)
    if isAdmin then nvgText(vg, W - 10, 20, "[Admin]", nil) end
    if playerInfo.ad_free then nvgText(vg, W - 10, isAdmin and 34 or 20, "[No Ads]", nil) end
    if not isAdmin and ms.tab == "cloud" then ms.tab = "system" end
    local tabs = isAdmin and { { id = "system", label = "System" }, { id = "cloud", label = "Player" } } or { { id = "system", label = "Mail" } }
    local pad, tabY, tabH, tabW = 14, 56, 36, (W - 28) / #tabs
    for i, tb in ipairs(tabs) do
        local x = pad + (i - 1) * tabW
        DrawMailButton(x + 2, tabY, tabW - 4, tabH, tb.label, ms.tab == tb.id)
        menuBtnRects["mailTab_" .. tb.id] = { x = x + 2, y = tabY, w = tabW - 4, h = tabH }
    end
    local listTop, listH, rowH = tabY + tabH + 10, H - (tabY + tabH + 22), 92
    ms.scroll = ms.scroll or { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
    if ms.tab == "cloud" then
        DrawMailButton(W - 94, listTop - 6, 80, 30, "Refresh", false)
        menuBtnRects.mailRefresh = { x = W - 94, y = listTop - 6, w = 80, h = 30 }
    else
        menuBtnRects.mailRefresh = nil
    end
    nvgSave(vg); nvgScissor(vg, 0, listTop, W, listH)
    local baseY = listTop + (ms.scroll.offset or 0)
    if ms.tab == "system" then
        local defs = welfareState.mailDefs or {}
        for i, mail in ipairs(defs) do
            local y = baseY + (i - 1) * rowH
            local title, sender = GetSystemMailMeta(mail, i)
            DrawMailButton(pad, y, W - pad * 2, rowH - 8, "", false)
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP); nvgFillColor(vg, nvgRGBA(255, 232, 190, 235))
            nvgText(vg, pad + 12, y + 10, title, nil)
            nvgFontSize(vg, 15); nvgFillColor(vg, nvgRGBA(170, 175, 190, 220))
            nvgText(vg, pad + 12, y + 40, "From: " .. sender, nil)
            nvgText(vg, pad + 12, y + 60, "Reward: " .. MailRewardLabel(mail.rewards and mail.rewards[1]), nil)
            local claimed = ms.claimed[mail.id]
            local btnX, btnY = W - pad - 108, y + 25
            DrawMailButton(btnX, btnY, 98, 34, claimed and "Claimed" or "Claim", not claimed)
            if not claimed then ms.btnRects[i] = { x = btnX, y = btnY, w = 98, h = 34 } end
        end
        if #defs == 0 then DrawWhiteInkText(cx, listTop + listH / 2, "No mail") end
    else
        local inbox = CloudManager._mailInbox or {}
        for i, cm in ipairs(inbox) do
            local y = baseY + (i - 1) * rowH
            DrawMailButton(pad, y, W - pad * 2, rowH - 8, "", false)
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP); nvgFillColor(vg, nvgRGBA(255, 232, 190, 235))
            nvgText(vg, pad + 12, y + 10, MailSafeText(cm.subject, "Player Mail"), nil)
            nvgFontSize(vg, 15); nvgFillColor(vg, nvgRGBA(170, 175, 190, 220))
            nvgText(vg, pad + 12, y + 40, "From: " .. MailSafeText(cm.fromName or cm.senderName, "Player"), nil)
            nvgText(vg, pad + 12, y + 60, "Rewards: " .. tostring(#(cm.rewards or {})), nil)
            local claimed = CloudManager.IsMailClaimed and CloudManager.IsMailClaimed(cm.id)
            local btnX, btnY = W - pad - 108, y + 25
            DrawMailButton(btnX, btnY, 98, 34, claimed and "Claimed" or "Claim", not claimed)
            if not claimed then ms.cloudBtnRects[i] = { x = btnX, y = btnY, w = 98, h = 34 } end
        end
        if CloudManager._mailLoading then DrawWhiteInkText(cx, listTop + listH / 2, "Loading...")
        elseif #inbox == 0 then DrawWhiteInkText(cx, listTop + listH / 2, "No mail") end
    end
    nvgRestore(vg)
    if not ms.confirmPopup then return end
    local popup = ms.confirmPopup
    local px, py, pw, ph = cx - (W - 120) / 2, H / 2 - 110, W - 120, 220
    popup.bgRect = { x = px, y = py, w = pw, h = ph }
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H); nvgFillColor(vg, nvgRGBA(0, 0, 0, 165)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 10); nvgFillColor(vg, nvgRGBA(28, 24, 34, 245)); nvgFill(vg)
    local mail = popup.cloudMail or (welfareState.mailDefs or {})[popup.mailIdx]
    local title = popup.cloudMail and MailSafeText(mail and mail.subject, "Player Mail") or select(1, GetSystemMailMeta(mail, popup.mailIdx))
    DrawWhiteInkText(cx, py + 28, "Claim: " .. tostring(title))
    local rewards = (mail and mail.rewards) or {}
    if #rewards == 0 then nvgText(vg, cx, py + 86, "No rewards available", nil)
    else for i, rw in ipairs(rewards) do if i > 4 then break end nvgText(vg, cx, py + 70 + (i - 1) * 24, MailRewardLabel(rw), nil) end end
    popup.confirmBtnRect = { x = cx - 128, y = py + ph - 52, w = 120, h = 38 }
    popup.closeBtnRect = { x = cx + 8, y = py + ph - 52, w = 100, h = 38 }
    DrawMailButton(popup.confirmBtnRect.x, popup.confirmBtnRect.y, 120, 38, "Confirm", true)
    DrawMailButton(popup.closeBtnRect.x, popup.closeBtnRect.y, 100, 38, "Close", false)
end
