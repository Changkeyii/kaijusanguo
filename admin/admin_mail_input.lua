-- admin/admin_mail_input.lua - 管理员邮件点击交互（仅管理员构建时加载）
-- 此文件包含：写信弹窗/管理面板的完整点击处理逻辑

local M = {}

--- 处理写信/管理弹窗内的点击事件
--- 返回 true 表示已消费此事件，调用方应 return
---@return boolean consumed
function M.HandleComposeClick()
    local ms = welfareState.mail
    if not ms.composing or not ms.composeData then return false end

    local cd = ms.composeData
    -- 关闭按钮
    if cd.closeBtnRect and HitRect(cd.closeBtnRect) then
        ms.composing = false; ms.composeData = nil
        input:SetScreenKeyboardVisible(false); PlaySFX(AUDIO.sfx_click)
        return true
    end

    -- ========= 管理面板专属按钮 =========
    if cd.isManage then
        return M._HandleManageClick(ms, cd)
    end

    -- ========= 写信面板按钮 =========
    return M._HandleComposeFormClick(ms, cd)
end

--- 处理管理面板点击
function M._HandleManageClick(ms, cd)
    -- 确认删除弹窗优先处理
    if cd.confirmDeleteUid then
        if cd.confirmYesRect and HitRect(cd.confirmYesRect) then
            PlaySFX(AUDIO.sfx_click)
            local delUid = cd.confirmDeleteUid
            cd.confirmDeleteUid = nil
            cd.resultMsg = "正在永久封禁..."; cd.resultOk = true; cd.resultTimer = 10.0
            CloudManager.AdminPermanentBan(delUid, function(ok, msg)
                cd.resultMsg = ok and ("已永久封禁 UID: " .. tostring(delUid)) or ("永久封禁失败: " .. tostring(msg))
                cd.resultOk = ok; cd.resultTimer = 3.0
                cd.banListLoaded = false; cd.banListLoading = false
            end)
            return true
        end
        if cd.confirmNoRect and HitRect(cd.confirmNoRect) then
            PlaySFX(AUDIO.sfx_click); cd.confirmDeleteUid = nil; return true
        end
        return true -- 确认弹窗打开时拦截所有点击
    end

    -- 关闭按钮
    if cd.closeBtnRect and HitRect(cd.closeBtnRect) then
        ms.composing = false; ms.composeData = nil
        input:SetScreenKeyboardVisible(false); PlaySFX(AUDIO.sfx_click)
        return true
    end

    -- 标签切换
    if cd.tabBtnRects then
        for tabId, rect in pairs(cd.tabBtnRects) do
            if HitRect(rect) then
                if cd.banTab ~= tabId then
                    cd.banTab = tabId
                    if tabId == "tempList" or tabId == "permList" then
                        cd.banListLoaded = false; cd.banListLoading = false
                        cd.banListScroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil }
                        cd.banListItemRects = {}
                    end
                end
                PlaySFX(AUDIO.sfx_click); return true
            end
        end
    end

    if cd.banTab == "operate" then
        -- UID粘贴按钮
        if cd.uidPasteRect and HitRect(cd.uidPasteRect) then
            local clipText = SafeGetClipboard()
            if clipText and #clipText > 0 then
                local cleaned = clipText:gsub("[^0-9]", "")
                if #cleaned > 15 then cleaned = cleaned:sub(1, 15) end
                if #cleaned > 0 then
                    cd.targetUid = cleaned
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "已粘贴UID: " .. cleaned, 1.5, {100,220,160}, 14)
                else
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "剪贴板内容不是有效UID", 1.5, {255,180,80}, 14)
                end
            else
                cd.inputFocus = "uid"; input:SetScreenKeyboardVisible(true)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "请在键盘中长按粘贴", 2.0, {255,220,100}, 14)
            end
            PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.uidRect and HitRect(cd.uidRect) then
            cd.inputFocus = "uid"; input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return true
        end
        -- 暂时封禁
        if cd.banBtnRect and HitRect(cd.banBtnRect) then
            PlaySFX(AUDIO.sfx_click)
            local uid = tonumber(cd.targetUid)
            if not uid or uid <= 0 then
                cd.resultMsg = "请输入有效的UID"; cd.resultOk = false; cd.resultTimer = 3.0; return true
            end
            cd.resultMsg = "正在暂时封禁..."; cd.resultOk = true; cd.resultTimer = 10.0
            CloudManager.AdminGetBanList(function(bans)
                local uidStr = tostring(uid)
                bans[uidStr] = bans[uidStr] or {}
                bans[uidStr].level = 3; bans[uidStr].reason = "管理员暂时封禁"
                bans[uidStr]["until"] = 0; bans[uidStr].rankHidden = true
                CloudManager.AdminPublishBanList(bans, function(ok, err)
                    if ok then
                        if not CloudManager._hiddenPlayers then CloudManager._hiddenPlayers = {} end
                        CloudManager._hiddenPlayers[uidStr] = true
                        cd.resultMsg = "已暂时封禁 UID: " .. uidStr; cd.resultOk = true; cd.resultTimer = 3.0
                    else
                        cd.resultMsg = "封禁失败: " .. tostring(err); cd.resultOk = false; cd.resultTimer = 3.0
                    end
                end)
            end)
            return true
        end
        -- 解禁
        if cd.unbanBtnRect and HitRect(cd.unbanBtnRect) then
            PlaySFX(AUDIO.sfx_click)
            local uid = tonumber(cd.targetUid)
            if not uid or uid <= 0 then
                cd.resultMsg = "请输入有效的UID"; cd.resultOk = false; cd.resultTimer = 3.0; return true
            end
            cd.resultMsg = "正在解禁..."; cd.resultOk = true; cd.resultTimer = 10.0
            CloudManager.AdminFullUnban(uid, function(ok, msg)
                cd.resultMsg = ok and ("已解禁 UID: " .. tostring(uid)) or ("解禁失败: " .. tostring(msg))
                cd.resultOk = ok; cd.resultTimer = 3.0
            end)
            return true
        end
        -- 隐藏排行榜
        if cd.hideRankBtnRect and HitRect(cd.hideRankBtnRect) then
            PlaySFX(AUDIO.sfx_click)
            local uid = tonumber(cd.targetUid)
            if not uid or uid <= 0 then
                cd.resultMsg = "请输入有效的UID"; cd.resultOk = false; cd.resultTimer = 3.0; return true
            end
            cd.resultMsg = "正在隐藏排行榜..."; cd.resultOk = true; cd.resultTimer = 10.0
            CloudManager.AdminHidePlayerRank(uid, function(ok, err)
                cd.resultMsg = ok and ("已隐藏 UID: " .. tostring(uid) .. " 的排行榜") or ("隐藏失败: " .. tostring(err))
                cd.resultOk = ok; cd.resultTimer = 3.0
            end)
            return true
        end
        -- 恢复排行榜
        if cd.unhideRankBtnRect and HitRect(cd.unhideRankBtnRect) then
            PlaySFX(AUDIO.sfx_click)
            local uid = tonumber(cd.targetUid)
            if not uid or uid <= 0 then
                cd.resultMsg = "请输入有效的UID"; cd.resultOk = false; cd.resultTimer = 3.0; return true
            end
            cd.resultMsg = "正在恢复排行榜..."; cd.resultOk = true; cd.resultTimer = 10.0
            CloudManager.AdminUnhidePlayerRank(uid, function(ok, err)
                cd.resultMsg = ok and ("已恢复 UID: " .. tostring(uid) .. " 的排行榜") or ("恢复失败: " .. tostring(err))
                cd.resultOk = ok; cd.resultTimer = 3.0
            end)
            return true
        end
        -- 永久封禁
        if cd.permBanBtnRect and HitRect(cd.permBanBtnRect) then
            PlaySFX(AUDIO.sfx_click)
            local uid = tonumber(cd.targetUid)
            if not uid or uid <= 0 then
                cd.resultMsg = "请输入有效的UID"; cd.resultOk = false; cd.resultTimer = 3.0; return true
            end
            cd.confirmDeleteUid = tostring(uid); return true
        end

    elseif cd.banTab == "tempList" then
        if cd.banRefreshBtnRect and HitRect(cd.banRefreshBtnRect) then
            PlaySFX(AUDIO.sfx_click); cd.banListLoaded = false; cd.banListLoading = false; return true
        end
        if cd.banListItemRects then
            for _, itemRect in pairs(cd.banListItemRects) do
                if itemRect.permBtn and HitRect(itemRect.permBtn) then
                    PlaySFX(AUDIO.sfx_click); cd.confirmDeleteUid = itemRect.uid; return true
                end
                if itemRect.unbanBtn and HitRect(itemRect.unbanBtn) then
                    PlaySFX(AUDIO.sfx_click)
                    cd.resultMsg = "正在解禁..."; cd.resultOk = true; cd.resultTimer = 10.0
                    CloudManager.AdminFullUnban(itemRect.uid, function(ok, msg)
                        cd.resultMsg = ok and ("已解禁 UID: " .. itemRect.uid) or ("解禁失败: " .. tostring(msg))
                        cd.resultOk = ok; cd.resultTimer = 3.0
                        cd.banListLoaded = false; cd.banListLoading = false
                    end)
                    return true
                end
            end
        end

    elseif cd.banTab == "permList" then
        if cd.banRefreshBtnRect and HitRect(cd.banRefreshBtnRect) then
            PlaySFX(AUDIO.sfx_click); cd.banListLoaded = false; cd.banListLoading = false; return true
        end
    end

    -- 点击弹窗外部关闭
    if cd.bgRect and not HitRect(cd.bgRect) then
        ms.composing = false; ms.composeData = nil
        input:SetScreenKeyboardVisible(false)
        return true
    end
    return true -- 管理面板打开时拦截所有点击
end

--- 处理写信面板点击
function M._HandleComposeFormClick(ms, cd)
    -- 发送按钮
    if cd.sendBtnRect and HitRect(cd.sendBtnRect) then
        PlaySFX(AUDIO.sfx_click)
        local uidNum = tonumber(cd.targetUid)
        if not uidNum then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "请输入有效的UID数字", 1.5, {255,100,100}, 16); return true
        end
        if #cd.subject == 0 then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "请输入邮件主题", 1.5, {255,100,100}, 16); return true
        end
        local rewards = {}
        if cd.isAdmin then
            if (cd.rewardJade or 0) > 0 then
                rewards[#rewards + 1] = { type = "jade", amount = cd.rewardJade, label = "虎符 x" .. cd.rewardJade }
            end
            if cd.adFree then
                rewards[#rewards + 1] = { type = "ad_free", label = "免广告特权" }
            end
            if cd.sealHeroIdx and cd.sealSlots then
                local heroCard = HERO_CARDS[cd.sealHeroIdx]
                local heroName = heroCard and heroCard.name or ("武灵#" .. cd.sealHeroIdx)
                for s = 1, SEAL_MAX_SLOTS do
                    local val = cd.sealSlots[s]
                    if val ~= nil then
                        local q = val
                        if val == 0 then q = math.random(1, 7) end
                        local tierName = SEAL_TIER_NAMES[q] or "未知"
                        rewards[#rewards + 1] = {
                            type = "seal", slotType = s, sealQ = q, level = 1,
                            fromHero = cd.sealHeroIdx,
                            label = heroName .. " " .. SEAL_SLOT_NAMES[s] .. "(" .. tierName .. ")",
                        }
                    end
                end
            end
        end
        if uidNum == 0 then
            CloudManager.BroadcastMail(cd.subject, cd.body, rewards, function(ok, err)
                if ok then AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "全服邮件发送成功!", 1.5, {100,255,150}, 16)
                else AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "发送失败: " .. tostring(err), 2.0, {255,100,100}, 14) end
            end)
        else
            CloudManager.SendMail(uidNum, cd.subject, cd.body, rewards, function(ok, err)
                if ok then AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "邮件发送成功!", 1.5, {100,255,150}, 16)
                else AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "发送失败: " .. tostring(err), 2.0, {255,100,100}, 14) end
            end)
        end
        ms.composing = false; ms.composeData = nil; input:SetScreenKeyboardVisible(false)
        return true
    end

    -- UID粘贴按钮
    if cd.uidPasteRect and HitRect(cd.uidPasteRect) then
        local clipText = SafeGetClipboard()
        if clipText and #clipText > 0 then
            local cleaned = clipText:gsub("[^0-9]", "")
            if #cleaned > 15 then cleaned = cleaned:sub(1, 15) end
            if #cleaned > 0 then
                cd.targetUid = cleaned; cd.inputFocus = "uid"
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "已粘贴UID: " .. cleaned, 1.5, { 100, 220, 160 }, 14)
            else
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "剪贴板内容不是有效UID", 1.5, { 255, 180, 80 }, 14)
            end
        else
            cd.inputFocus = "uid"; input:SetScreenKeyboardVisible(true)
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "请在键盘中长按粘贴", 2.0, { 255, 220, 100 }, 14)
        end
        PlaySFX(AUDIO.sfx_click); return true
    end

    -- 输入框焦点
    if cd.uidRect and HitRect(cd.uidRect) then
        cd.inputFocus = "uid"; input:SetScreenKeyboardVisible(true); PlaySFX(AUDIO.sfx_click); return true
    end
    if cd.subjectRect and HitRect(cd.subjectRect) then
        cd.inputFocus = "subject"; input:SetScreenKeyboardVisible(true); PlaySFX(AUDIO.sfx_click); return true
    end
    if cd.bodyRect and HitRect(cd.bodyRect) then
        cd.inputFocus = "body"; input:SetScreenKeyboardVisible(true); PlaySFX(AUDIO.sfx_click); return true
    end

    -- 管理员奖励控件
    if cd.isAdmin then
        if cd.jadeMinus and HitRect(cd.jadeMinus) then
            cd.rewardJade = math.max(0, (cd.rewardJade or 0) - 500)
            cd.jadeInputText = tostring(cd.rewardJade); cd.inputFocus = nil
            PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.jadePlus and HitRect(cd.jadePlus) then
            cd.rewardJade = (cd.rewardJade or 0) + 500
            cd.jadeInputText = tostring(cd.rewardJade); cd.inputFocus = nil
            PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.jadeInputRect and HitRect(cd.jadeInputRect) then
            cd.inputFocus = "jade"; cd.jadeInputText = tostring(cd.rewardJade or 0)
            input:SetScreenKeyboardVisible(true); PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.adFreeRect and HitRect(cd.adFreeRect) then
            cd.adFree = not cd.adFree; PlaySFX(AUDIO.sfx_click); return true
        end
        -- 兵符翻页
        if cd.sealHeroPrev and HitRect(cd.sealHeroPrev) then
            local cur = cd.sealHeroIdx or 1
            cd.sealHeroIdx = cur > 1 and (cur - 1) or #HERO_CARDS
            cd.sealSlots = {}; PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.sealHeroNext and HitRect(cd.sealHeroNext) then
            local cur = cd.sealHeroIdx or 0
            cd.sealHeroIdx = cur < #HERO_CARDS and (cur + 1) or 1
            cd.sealSlots = {}; PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.sealHeroSelRect and HitRect(cd.sealHeroSelRect) then
            local cur = cd.sealHeroIdx or 0
            cd.sealHeroIdx = cur < #HERO_CARDS and (cur + 1) or 1
            cd.sealSlots = {}; PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.sealHeroClear and HitRect(cd.sealHeroClear) then
            cd.sealHeroIdx = nil; cd.sealSlots = {}; PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.sealAllRandom and HitRect(cd.sealAllRandom) then
            if not cd.sealSlots then cd.sealSlots = {} end
            for s = 1, SEAL_MAX_SLOTS do cd.sealSlots[s] = 0 end
            PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.sealAllClear and HitRect(cd.sealAllClear) then
            cd.sealSlots = {}; PlaySFX(AUDIO.sfx_click); return true
        end
        if cd.sealSlotRects then
            for s = 1, SEAL_MAX_SLOTS do
                if cd.sealSlotRects[s] and HitRect(cd.sealSlotRects[s]) then
                    local cur = cd.sealSlots[s]
                    if cur == nil then cd.sealSlots[s] = 0
                    elseif cur == 0 then cd.sealSlots[s] = 1
                    elseif cur < 7 then cd.sealSlots[s] = cur + 1
                    else cd.sealSlots[s] = nil end
                    PlaySFX(AUDIO.sfx_click); return true
                end
            end
        end
    end

    -- 点击弹窗外部关闭
    if cd.bgRect and not HitRect(cd.bgRect) then
        ms.composing = false; ms.composeData = nil
        input:SetScreenKeyboardVisible(false)
        return true
    end
    return true -- 弹窗打开时拦截所有点击
end

--- 处理管理员按钮点击（写信、发奖励、管理 三个入口按钮）
--- 返回 true 表示已消费
function M.HandleAdminButtonClick()
    -- 写信按钮
    if menuBtnRects.mailCompose and HitRect(menuBtnRects.mailCompose) then
        welfareState.mail.composing = true
        welfareState.mail.composeData = {
            targetUid = "", subject = "", body = "",
            isAdmin = false, rewardJade = 0, adFree = false,
            inputFocus = "uid",
        }
        PlaySFX(AUDIO.sfx_click); return true
    end
    -- 发奖励邮件
    if menuBtnRects.mailAdminReward and HitRect(menuBtnRects.mailAdminReward) then
        if CloudManager.IsAdmin() then
            welfareState.mail.composing = true
            welfareState.mail.composeData = {
                targetUid = "0", subject = "", body = "",
                isAdmin = true, rewardJade = 0, adFree = false,
                inputFocus = "subject",
            }
            PlaySFX(AUDIO.sfx_click)
        end
        return true
    end
    -- 玩家管理
    if menuBtnRects.mailAdminManage and HitRect(menuBtnRects.mailAdminManage) then
        if CloudManager.IsAdmin() then
            welfareState.mail.composing = true
            welfareState.mail.composeData = {
                targetUid = "", isManage = true, inputFocus = "uid",
                banTab = "operate", banListLoaded = false, banListLoading = false,
                banTempList = {}, banPermList = {},
                banListScroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil },
                confirmDeleteUid = nil,
            }
            PlaySFX(AUDIO.sfx_click)
        end
        return true
    end
    return false
end

return M
