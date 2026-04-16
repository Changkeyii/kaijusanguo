-- admin/admin_mail_ui.lua - 管理员邮件界面渲染（仅管理员构建时加载）
-- 此文件包含：写信/发奖励邮件弹窗、玩家管理面板的完整渲染逻辑

local M = {}

--- 绘制管理员专属按钮：写信、发奖励邮件、玩家管理（在玩家邮件Tab顶部）
---@param W number 设计宽度
---@param compBtnX number 写信按钮X
---@param compBtnY number 写信按钮Y
---@param compBtnW number 写信按钮宽
---@param compBtnH number 写信按钮高
---@param pad number 边距
function M.DrawAdminMailButtons(W, compBtnX, compBtnY, compBtnW, compBtnH, pad)
    if not CloudManager.IsAdmin() then return end
    -- 写信按钮
    nvgBeginPath(vg); nvgRoundedRect(vg, compBtnX, compBtnY, compBtnW, compBtnH, 6)
    nvgFillColor(vg, nvgRGBA(50, 90, 140, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 220, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 230, 255, 240))
    nvgText(vg, compBtnX + compBtnW / 2, compBtnY + compBtnH / 2, "写信", nil)
    menuBtnRects.mailCompose = { x = compBtnX, y = compBtnY, w = compBtnW, h = compBtnH }

    -- 发奖励邮件按钮
    local admBtnW, admBtnH = 110, 32
    local admBtnX = compBtnX - admBtnW - 8
    nvgBeginPath(vg); nvgRoundedRect(vg, admBtnX, compBtnY, admBtnW, admBtnH, 6)
    nvgFillColor(vg, nvgRGBA(140, 70, 20, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 180, 60, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 240))
    nvgText(vg, admBtnX + admBtnW / 2, compBtnY + admBtnH / 2, "发奖励邮件", nil)
    menuBtnRects.mailAdminReward = { x = admBtnX, y = compBtnY, w = admBtnW, h = admBtnH }

    -- 玩家管理按钮
    local mgBtnW, mgBtnH = 90, 32
    local mgBtnX = admBtnX - mgBtnW - 8
    nvgBeginPath(vg); nvgRoundedRect(vg, mgBtnX, compBtnY, mgBtnW, mgBtnH, 6)
    nvgFillColor(vg, nvgRGBA(100, 30, 30, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 80, 80, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 180, 180, 240))
    nvgText(vg, mgBtnX + mgBtnW / 2, compBtnY + mgBtnH / 2, "玩家管理", nil)
    menuBtnRects.mailAdminManage = { x = mgBtnX, y = compBtnY, w = mgBtnW, h = mgBtnH }
end

--- 绘制写信/发奖励/管理弹窗（完整管理员弹窗UI）
---@param W number 设计宽度
---@param H number 设计高度
---@param cx number 中心X
---@param t number 动画计时器
---@param ms table welfareState.mail
function M.DrawAdminPopup(W, H, cx, t, ms)
    local cd = ms.composeData
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180)); nvgFill(vg)

    if cd.isManage then
        M._DrawManagePanel(W, H, cx, t, cd)
    else
        M._DrawComposePanel(W, H, cx, t, cd)
    end
end

--- 玩家管理面板（内部函数）
function M._DrawManagePanel(W, H, cx, t, cd)
    if not cd.banTab then cd.banTab = "operate" end
    local pw, ph = 420, 440
    local px, py = cx - pw / 2, H / 2 - ph / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 14)
    nvgFillColor(vg, nvgRGBA(30, 18, 18, 245)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 80, 80, 160)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
    cd.bgRect = { x = px, y = py, w = pw, h = ph }

    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 180, 180, 240))
    nvgText(vg, cx, py + 24, "玩家管理(管理员)", nil)

    -- 标签按钮
    local fieldX, fieldW = px + 16, pw - 32
    local mTabY = py + 44
    local mTabNames = { { id = "operate", name = "操作" }, { id = "tempList", name = "暂时封禁" }, { id = "permList", name = "永久封禁" } }
    local mTabW = math.floor((fieldW - 8) / 3)
    local mTabH = 28
    cd.tabBtnRects = {}
    for ti, tab in ipairs(mTabNames) do
        local tx = fieldX + (ti - 1) * (mTabW + 4)
        local isSel = (cd.banTab == tab.id)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, mTabY, mTabW, mTabH, 5)
        if isSel then
            nvgFillColor(vg, nvgRGBA(160, 60, 60, 240)); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(60, 30, 30, 200)); nvgFill(vg)
        end
        nvgStrokeColor(vg, nvgRGBA(180, 80, 80, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isSel and nvgRGBA(255, 240, 240, 255) or nvgRGBA(180, 140, 140, 200))
        nvgText(vg, tx + mTabW / 2, mTabY + mTabH / 2, tab.name, nil)
        cd.tabBtnRects[tab.id] = { x = tx, y = mTabY, w = mTabW, h = mTabH }
    end

    local contentY = mTabY + mTabH + 10
    local contentH = py + ph - contentY - 50

    if cd.banTab == "operate" then
        M._DrawOperateTab(cx, fieldX, fieldW, contentY, contentH, cd)
    elseif cd.banTab == "tempList" or cd.banTab == "permList" then
        M._DrawBanListTab(cx, fieldX, fieldW, contentY, contentH, cd)
    end

    -- 操作结果提示
    if cd.resultMsg and cd.resultTimer and cd.resultTimer > 0 then
        local msgY = py + ph - 36
        local alpha = math.min(255, math.floor(cd.resultTimer / 3.0 * 255))
        local rc = cd.resultOk and nvgRGBA(100, 255, 150, alpha) or nvgRGBA(255, 120, 120, alpha)
        nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, rc)
        nvgText(vg, cx, msgY, cd.resultMsg, nil)
        cd.resultTimer = cd.resultTimer - 0.016
    end

    -- 确认删除弹窗
    if cd.confirmDeleteUid then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 150)); nvgFill(vg)
        local dw, dh = 300, 140
        local dx, dy = cx - dw / 2, H / 2 - dh / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, dx, dy, dw, dh, 10)
        nvgFillColor(vg, nvgRGBA(40, 20, 20, 250)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 60, 60, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 240))
        nvgText(vg, cx, dy + 30, "确认永久封禁(删除)?", nil)
        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(200, 160, 160, 200))
        nvgText(vg, cx, dy + 54, "UID: " .. tostring(cd.confirmDeleteUid), nil)
        nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(255, 120, 120, 180))
        nvgText(vg, cx, dy + 72, "此操作不可恢复!", nil)

        local cbW, cbH = 100, 32
        local cfmX = cx - cbW - 8
        local cfmY = dy + dh - cbH - 16
        nvgBeginPath(vg); nvgRoundedRect(vg, cfmX, cfmY, cbW, cbH, 6)
        nvgFillColor(vg, nvgRGBA(160, 20, 20, 230)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 60, 60, 200)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 250))
        nvgText(vg, cfmX + cbW / 2, cfmY + cbH / 2, "确认删除", nil)
        cd.confirmYesRect = { x = cfmX, y = cfmY, w = cbW, h = cbH }
        local cnlX = cx + 8
        nvgBeginPath(vg); nvgRoundedRect(vg, cnlX, cfmY, cbW, cbH, 6)
        nvgFillColor(vg, nvgRGBA(60, 60, 70, 230)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(140, 140, 160, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFillColor(vg, nvgRGBA(200, 200, 210, 240))
        nvgText(vg, cnlX + cbW / 2, cfmY + cbH / 2, "取消", nil)
        cd.confirmNoRect = { x = cnlX, y = cfmY, w = cbW, h = cbH }
    end

    -- 关闭按钮
    local clR = 16
    local clX = px + pw - 25
    local clY = py + 20
    nvgBeginPath(vg); nvgCircle(vg, clX, clY, clR)
    nvgFillColor(vg, nvgRGBA(60, 40, 40, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 100, 100, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 180, 180, 220))
    nvgText(vg, clX, clY, "X", nil)
    cd.closeBtnRect = { x = clX - clR, y = clY - clR, w = clR * 2, h = clR * 2 }
end

--- 操作标签
function M._DrawOperateTab(cx, fieldX, fieldW, contentY, contentH, cd)
    local fy = contentY
    -- UID输入
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 180, 180, 200))
    nvgText(vg, fieldX, fy, "目标玩家UID:", nil)
    fy = fy + 18
    nvgBeginPath(vg); nvgRoundedRect(vg, fieldX, fy, fieldW, 28, 4)
    nvgFillColor(vg, nvgRGBA(15, 15, 20, 200)); nvgFill(vg)
    nvgStrokeColor(vg, cd.inputFocus == "uid" and nvgRGBA(255, 120, 120, 200) or nvgRGBA(80, 50, 50, 150))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    local uidPasteW = 50
    nvgFillColor(vg, nvgRGBA(240, 220, 220, 230)); nvgFontSize(vg, 15)
    nvgText(vg, fieldX + 8, fy + 5, cd.targetUid .. (cd.inputFocus == "uid" and "|" or ""), nil)
    cd.uidRect = { x = fieldX, y = fy, w = fieldW - uidPasteW - 6, h = 28 }
    local upX = fieldX + fieldW - uidPasteW
    nvgBeginPath(vg); nvgRoundedRect(vg, upX, fy, uidPasteW, 28, 4)
    nvgFillColor(vg, nvgRGBA(100, 60, 60, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 120, 120, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 200, 200, 230))
    nvgText(vg, upX + uidPasteW / 2, fy + 14, "粘贴", nil)
    cd.uidPasteRect = { x = upX, y = fy, w = uidPasteW, h = 28 }

    -- 登录管理
    fy = fy + 42
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 180, 180, 180))
    nvgText(vg, fieldX, fy, "登录管理:", nil)
    fy = fy + 18
    local btnW, btnH = (fieldW - 12) / 2, 32
    -- 暂时封禁
    nvgBeginPath(vg); nvgRoundedRect(vg, fieldX, fy, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(140, 90, 20, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 160, 60, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 140, 240))
    nvgText(vg, fieldX + btnW / 2, fy + btnH / 2, "暂时封禁", nil)
    cd.banBtnRect = { x = fieldX, y = fy, w = btnW, h = btnH }
    -- 解禁
    local ubX = fieldX + btnW + 12
    nvgBeginPath(vg); nvgRoundedRect(vg, ubX, fy, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(30, 100, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 200, 120, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(200, 255, 200, 240))
    nvgText(vg, ubX + btnW / 2, fy + btnH / 2, "解禁", nil)
    cd.unbanBtnRect = { x = ubX, y = fy, w = btnW, h = btnH }

    -- 排行榜管理
    fy = fy + btnH + 14
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 180, 180, 180))
    nvgText(vg, fieldX, fy, "排行榜管理:", nil)
    fy = fy + 18
    nvgBeginPath(vg); nvgRoundedRect(vg, fieldX, fy, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(120, 80, 20, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 160, 60, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 140, 240))
    nvgText(vg, fieldX + btnW / 2, fy + btnH / 2, "隐藏排行榜", nil)
    cd.hideRankBtnRect = { x = fieldX, y = fy, w = btnW, h = btnH }
    nvgBeginPath(vg); nvgRoundedRect(vg, ubX, fy, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(30, 80, 120, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 220, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 240))
    nvgText(vg, ubX + btnW / 2, fy + btnH / 2, "恢复排行榜", nil)
    cd.unhideRankBtnRect = { x = ubX, y = fy, w = btnW, h = btnH }

    -- 永久封禁按钮
    fy = fy + btnH + 14
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 180, 180, 180))
    nvgText(vg, fieldX, fy, "永久封禁(不可恢复):", nil)
    fy = fy + 18
    nvgBeginPath(vg); nvgRoundedRect(vg, fieldX, fy, fieldW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(120, 10, 10, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 40, 40, 200)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 160, 160, 255))
    nvgText(vg, fieldX + fieldW / 2, fy + btnH / 2, "永久封禁(删除数据)", nil)
    cd.permBanBtnRect = { x = fieldX, y = fy, w = fieldW, h = btnH }
end

--- 封禁名单标签
function M._DrawBanListTab(cx, fieldX, fieldW, contentY, contentH, cd)
    local isTemp = (cd.banTab == "tempList")
    if not cd.banListLoaded and not cd.banListLoading then
        cd.banListLoading = true
        CloudManager.AdminGetBanListSummary(function(tempList, permList, err)
            cd.banTempList = tempList or {}
            cd.banPermList = permList or {}
            cd.banListLoaded = true
            cd.banListLoading = false
        end)
    end

    local listData = isTemp and cd.banTempList or cd.banPermList
    local fy = contentY

    if cd.banListLoading then
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 180, 200))
        nvgText(vg, cx, fy + contentH / 2, "加载中...", nil)
    elseif #listData == 0 then
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 140, 140, 180))
        nvgText(vg, cx, fy + contentH / 2, isTemp and "暂无暂时封禁玩家" or "暂无永久封禁玩家", nil)
    else
        -- 刷新按钮
        local refBtnW, refBtnH = 60, 24
        local refBtnX = fieldX + fieldW - refBtnW
        nvgBeginPath(vg); nvgRoundedRect(vg, refBtnX, fy, refBtnW, refBtnH, 4)
        nvgFillColor(vg, nvgRGBA(60, 80, 100, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 150, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 230))
        nvgText(vg, refBtnX + refBtnW / 2, fy + refBtnH / 2, "刷新", nil)
        cd.banRefreshBtnRect = { x = refBtnX, y = fy, w = refBtnW, h = refBtnH }

        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 160, 160, 180))
        nvgText(vg, fieldX, fy + refBtnH / 2, "共 " .. #listData .. " 人", nil)
        fy = fy + refBtnH + 6

        local banListH = contentH - (refBtnH + 6)
        local itemH = 44
        local totalH = #listData * itemH
        local scroll = cd.banListScroll
        if not scroll then scroll = { offset = 0, vel = 0 }; cd.banListScroll = scroll end
        local maxScroll = math.max(0, totalH - banListH)
        if scroll.offset < 0 then scroll.offset = 0 end
        if scroll.offset > maxScroll then scroll.offset = maxScroll end

        nvgSave(vg)
        nvgScissor(vg, fieldX, fy, fieldW, banListH)
        cd.banListItemRects = {}

        for i, item in ipairs(listData) do
            local iy = fy + (i - 1) * itemH - scroll.offset
            if iy + itemH > fy and iy < fy + banListH then
                local bgAlpha = (i % 2 == 0) and 40 or 25
                nvgBeginPath(vg); nvgRoundedRect(vg, fieldX, iy, fieldW, itemH - 2, 4)
                nvgFillColor(vg, nvgRGBA(80, 40, 40, bgAlpha)); nvgFill(vg)

                nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(240, 210, 210, 230))
                nvgText(vg, fieldX + 8, iy + itemH / 2 - 8, "UID: " .. item.uid, nil)
                nvgFontSize(vg, 11); nvgFillColor(vg, nvgRGBA(180, 150, 150, 180))
                local statusTxt = ""
                if item.permanent then
                    statusTxt = "永久封禁"
                else
                    if item.level >= 3 then statusTxt = "全面封禁"
                    elseif item.level >= 2 then statusTxt = "核心封禁"
                    elseif item.level >= 1 then statusTxt = "社交封禁"
                    end
                    if item.rankHidden then statusTxt = statusTxt .. "+排行隐藏" end
                end
                nvgText(vg, fieldX + 8, iy + itemH / 2 + 8, statusTxt, nil)

                local actBtnW, actBtnH = 72, 26
                local actBtnX = fieldX + fieldW - actBtnW - 8
                local actBtnY = iy + (itemH - actBtnH) / 2

                if isTemp then
                    nvgBeginPath(vg); nvgRoundedRect(vg, actBtnX, actBtnY, actBtnW, actBtnH, 4)
                    nvgFillColor(vg, nvgRGBA(140, 20, 20, 220)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(255, 60, 60, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                    nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 180, 180, 240))
                    nvgText(vg, actBtnX + actBtnW / 2, actBtnY + actBtnH / 2, "永久删除", nil)

                    local unBtnX = actBtnX - actBtnW - 6
                    nvgBeginPath(vg); nvgRoundedRect(vg, unBtnX, actBtnY, actBtnW, actBtnH, 4)
                    nvgFillColor(vg, nvgRGBA(30, 90, 50, 220)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(80, 200, 120, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                    nvgFillColor(vg, nvgRGBA(180, 255, 200, 240))
                    nvgText(vg, unBtnX + actBtnW / 2, actBtnY + actBtnH / 2, "解禁", nil)
                    cd.banListItemRects[i] = {
                        permBtn = { x = actBtnX, y = actBtnY, w = actBtnW, h = actBtnH },
                        unbanBtn = { x = unBtnX, y = actBtnY, w = actBtnW, h = actBtnH },
                        uid = item.uid,
                    }
                else
                    nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 80, 80, 160))
                    nvgText(vg, actBtnX + actBtnW / 2, actBtnY + actBtnH / 2, "已删除", nil)
                end
            end
        end
        nvgRestore(vg)
    end
end

--- 写信/发奖励面板
function M._DrawComposePanel(W, H, cx, t, cd)
    local sealSectionH = (cd.isAdmin and cd.sealHeroIdx) and 180 or (cd.isAdmin and 30 or 0)
    local pw, ph = 420, 340 + sealSectionH
    local px, py = cx - pw / 2, H / 2 - ph / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 14)
    nvgFillColor(vg, nvgRGBA(25, 28, 40, 245)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 220, 160)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
    cd.bgRect = { x = px, y = py, w = pw, h = ph }

    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, py + 28, cd.isAdmin and "发奖励邮件(管理员)" or "写信")

    -- 收件人UID
    local fieldX, fieldW = px + 20, pw - 40
    local fy = py + 56
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
    nvgText(vg, fieldX, fy, cd.isAdmin and "收件人UID (0=全服广播):" or "收件人UID:", nil)
    fy = fy + 20
    nvgBeginPath(vg); nvgRoundedRect(vg, fieldX, fy, fieldW, 30, 4)
    nvgFillColor(vg, nvgRGBA(15, 15, 25, 200)); nvgFill(vg)
    nvgStrokeColor(vg, cd.inputFocus == "uid" and nvgRGBA(100, 180, 255, 200) or nvgRGBA(60, 60, 80, 150))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    local uidPasteW = 50
    nvgFillColor(vg, nvgRGBA(220, 220, 240, 230)); nvgFontSize(vg, 16)
    nvgText(vg, fieldX + 8, fy + 6, cd.targetUid .. (cd.inputFocus == "uid" and "|" or ""), nil)
    cd.uidRect = { x = fieldX, y = fy, w = fieldW - uidPasteW - 6, h = 30 }
    local upX = fieldX + fieldW - uidPasteW
    nvgBeginPath(vg); nvgRoundedRect(vg, upX, fy, uidPasteW, 30, 4)
    nvgFillColor(vg, nvgRGBA(60, 100, 160, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 255, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(upX + uidPasteW / 2, fy + 15, "粘贴")
    cd.uidPasteRect = { x = upX, y = fy, w = uidPasteW, h = 30 }
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    -- 主题
    fy = fy + 38
    nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
    nvgText(vg, fieldX, fy, "主题:", nil)
    fy = fy + 20
    nvgBeginPath(vg); nvgRoundedRect(vg, fieldX, fy, fieldW, 30, 4)
    nvgFillColor(vg, nvgRGBA(15, 15, 25, 200)); nvgFill(vg)
    nvgStrokeColor(vg, cd.inputFocus == "subject" and nvgRGBA(100, 180, 255, 200) or nvgRGBA(60, 60, 80, 150))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(220, 220, 240, 230)); nvgFontSize(vg, 16)
    nvgText(vg, fieldX + 8, fy + 6, cd.subject .. (cd.inputFocus == "subject" and "|" or ""), nil)
    cd.subjectRect = { x = fieldX, y = fy, w = fieldW, h = 30 }

    -- 正文
    fy = fy + 38
    nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
    nvgText(vg, fieldX, fy, "正文:", nil)
    fy = fy + 20
    nvgBeginPath(vg); nvgRoundedRect(vg, fieldX, fy, fieldW, 50, 4)
    nvgFillColor(vg, nvgRGBA(15, 15, 25, 200)); nvgFill(vg)
    nvgStrokeColor(vg, cd.inputFocus == "body" and nvgRGBA(100, 180, 255, 200) or nvgRGBA(60, 60, 80, 150))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(220, 220, 240, 230)); nvgFontSize(vg, 14)
    nvgText(vg, fieldX + 8, fy + 6, cd.body .. (cd.inputFocus == "body" and "|" or ""), nil)
    cd.bodyRect = { x = fieldX, y = fy, w = fieldW, h = 50 }

    -- 管理员: 奖励选项
    if cd.isAdmin then
        fy = fy + 58
        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
        nvgText(vg, fieldX, fy, "附件奖励:", nil)
        fy = fy + 18
        -- 虎符
        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(255, 220, 100, 220))
        nvgText(vg, fieldX, fy, "虎符:", nil)
        local jInputX, jInputW, jbH = fieldX + 42, 80, 22
        nvgBeginPath(vg); nvgRoundedRect(vg, jInputX, fy - 2, jInputW, jbH, 4)
        nvgFillColor(vg, nvgRGBA(15, 15, 25, 200)); nvgFill(vg)
        nvgStrokeColor(vg, cd.inputFocus == "jade" and nvgRGBA(255, 200, 80, 200) or nvgRGBA(80, 70, 40, 150))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFillColor(vg, nvgRGBA(255, 230, 130, 240)); nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local jadeDisplayStr = cd.inputFocus == "jade" and ((cd.jadeInputText or "0") .. "|") or tostring(cd.rewardJade or 0)
        nvgText(vg, jInputX + jInputW / 2, fy + jbH / 2 - 2, jadeDisplayStr, nil)
        cd.jadeInputRect = { x = jInputX, y = fy - 2, w = jInputW, h = jbH }
        local jbW = 36
        local jMinusX = jInputX + jInputW + 6
        nvgBeginPath(vg); nvgRoundedRect(vg, jMinusX, fy - 2, jbW, jbH, 4)
        nvgFillColor(vg, nvgRGBA(80, 40, 40, 200)); nvgFill(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 220))
        nvgText(vg, jMinusX + jbW / 2, fy + jbH / 2 - 2, "-500", nil)
        cd.jadeMinus = { x = jMinusX, y = fy - 2, w = jbW, h = jbH }
        local jPlusX = jMinusX + jbW + 6
        nvgBeginPath(vg); nvgRoundedRect(vg, jPlusX, fy - 2, jbW, jbH, 4)
        nvgFillColor(vg, nvgRGBA(40, 80, 40, 200)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(200, 255, 200, 220))
        nvgText(vg, jPlusX + jbW / 2, fy + jbH / 2 - 2, "+500", nil)
        cd.jadePlus = { x = jPlusX, y = fy - 2, w = jbW, h = jbH }

        -- 免广告
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local adFreeX = jPlusX + jbW + 14
        nvgFontSize(vg, 14)
        nvgFillColor(vg, cd.adFree and nvgRGBA(100, 255, 150, 230) or nvgRGBA(160, 160, 170, 180))
        nvgText(vg, adFreeX, fy, cd.adFree and "[v] 免广告" or "[ ] 免广告", nil)
        cd.adFreeRect = { x = adFreeX, y = fy - 2, w = 90, h = jbH }

        -- 兵符派发
        fy = fy + 28
        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(180, 140, 255, 220))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgText(vg, fieldX, fy, "兵符派发:", nil)

        local heroSelX = fieldX + 68
        local heroSelW, heroSelH = 140, 22
        local heroName = "未选择"
        if cd.sealHeroIdx and HERO_CARDS[cd.sealHeroIdx] then
            heroName = cd.sealHeroIdx .. "." .. HERO_CARDS[cd.sealHeroIdx].name
        end
        nvgBeginPath(vg); nvgRoundedRect(vg, heroSelX, fy - 2, heroSelW, heroSelH, 4)
        nvgFillColor(vg, nvgRGBA(30, 20, 50, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(140, 100, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 200, 255, 230))
        nvgText(vg, heroSelX + heroSelW / 2, fy + heroSelH / 2 - 2, heroName, nil)
        cd.sealHeroSelRect = { x = heroSelX, y = fy - 2, w = heroSelW, h = heroSelH }

        local arrW = 22
        local arrLX = heroSelX - arrW - 4
        nvgBeginPath(vg); nvgRoundedRect(vg, arrLX, fy - 2, arrW, heroSelH, 4)
        nvgFillColor(vg, nvgRGBA(60, 40, 80, 200)); nvgFill(vg)
        nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 255, 220))
        nvgText(vg, arrLX + arrW / 2, fy + heroSelH / 2 - 2, "<", nil)
        cd.sealHeroPrev = { x = arrLX, y = fy - 2, w = arrW, h = heroSelH }

        local arrRX = heroSelX + heroSelW + 4
        nvgBeginPath(vg); nvgRoundedRect(vg, arrRX, fy - 2, arrW, heroSelH, 4)
        nvgFillColor(vg, nvgRGBA(60, 40, 80, 200)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(200, 180, 255, 220))
        nvgText(vg, arrRX + arrW / 2, fy + heroSelH / 2 - 2, ">", nil)
        cd.sealHeroNext = { x = arrRX, y = fy - 2, w = arrW, h = heroSelH }

        local clrX = arrRX + arrW + 6
        local clrW = 36
        nvgBeginPath(vg); nvgRoundedRect(vg, clrX, fy - 2, clrW, heroSelH, 4)
        nvgFillColor(vg, nvgRGBA(80, 40, 40, 200)); nvgFill(vg)
        nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(255, 180, 180, 220))
        nvgText(vg, clrX + clrW / 2, fy + heroSelH / 2 - 2, "清除", nil)
        cd.sealHeroClear = { x = clrX, y = fy - 2, w = clrW, h = heroSelH }

        if cd.sealHeroIdx then
            if not cd.sealSlots then cd.sealSlots = {} end
            cd.sealSlotRects = {}
            fy = fy + 26

            local qkBtnW, qkBtnH = 64, 20
            local qkX1 = fieldX
            nvgBeginPath(vg); nvgRoundedRect(vg, qkX1, fy - 1, qkBtnW, qkBtnH, 4)
            nvgFillColor(vg, nvgRGBA(50, 50, 20, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 200, 100, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 220, 120, 230))
            nvgText(vg, qkX1 + qkBtnW / 2, fy + qkBtnH / 2 - 1, "全随机", nil)
            cd.sealAllRandom = { x = qkX1, y = fy - 1, w = qkBtnW, h = qkBtnH }

            local qkX2 = qkX1 + qkBtnW + 8
            nvgBeginPath(vg); nvgRoundedRect(vg, qkX2, fy - 1, qkBtnW, qkBtnH, 4)
            nvgFillColor(vg, nvgRGBA(50, 20, 20, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 100, 100, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFillColor(vg, nvgRGBA(220, 150, 150, 230))
            nvgText(vg, qkX2 + qkBtnW / 2, fy + qkBtnH / 2 - 1, "全不选", nil)
            cd.sealAllClear = { x = qkX2, y = fy - 1, w = qkBtnW, h = qkBtnH }

            local selCount = 0
            for s = 1, SEAL_MAX_SLOTS do if cd.sealSlots[s] ~= nil then selCount = selCount + 1 end end
            nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(160, 140, 200, 160))
            nvgText(vg, fieldX + fieldW, fy + qkBtnH / 2 - 1, selCount .. "/6 已选", nil)

            fy = fy + qkBtnH + 6
            local colW = (fieldW) / 3
            for s = 1, SEAL_MAX_SLOTS do
                local col = (s - 1) % 3
                local row = (s - 1) < 3 and 0 or 1
                local sx = fieldX + col * colW
                local sy = fy + row * 50
                local slotVal = cd.sealSlots[s]

                local tc = SEAL_SLOT_THEME_COLORS[s] or {180,180,180}
                nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220))
                nvgText(vg, sx, sy, SEAL_SLOT_NAMES[s], nil)

                local btnX = sx + 36
                local btnW2, btnH2 = 80, 20
                local label = "跳过"
                local lblClr = nvgRGBA(100, 100, 110, 150)
                local bgAlpha = 180
                if slotVal == 0 then
                    label = "随机"; lblClr = nvgRGBA(220, 220, 100, 240); bgAlpha = 220
                elseif slotVal and slotVal >= 1 then
                    label = SEAL_TIER_NAMES[slotVal] or ("Lv" .. slotVal)
                    local qc = SEAL_QUALITY_COLORS[slotVal] or {200,200,200}
                    lblClr = nvgRGBA(qc[1], qc[2], qc[3], 250); bgAlpha = 230
                end
                nvgBeginPath(vg); nvgRoundedRect(vg, btnX, sy - 1, btnW2, btnH2, 4)
                nvgFillColor(vg, nvgRGBA(20, 15, 30, bgAlpha)); nvgFill(vg)
                nvgStrokeColor(vg, slotVal ~= nil and nvgRGBA(tc[1], tc[2], tc[3], 140) or nvgRGBA(tc[1], tc[2], tc[3], 50))
                nvgStrokeWidth(vg, slotVal ~= nil and 1.5 or 0.8); nvgStroke(vg)
                nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, lblClr)
                nvgText(vg, btnX + btnW2 / 2, sy + btnH2 / 2 - 1, label, nil)
                cd.sealSlotRects[s] = { x = btnX, y = sy - 1, w = btnW2, h = btnH2 }
            end
            fy = fy + 100
        end
    end

    -- 发送按钮
    local sendBtnW, sendBtnH = 120, 40
    local sendBtnX = cx - sendBtnW / 2
    local sendBtnY = py + ph - sendBtnH - 16
    local sp = 0.85 + 0.15 * math.sin(t * 3.0)
    nvgBeginPath(vg); nvgRoundedRect(vg, sendBtnX, sendBtnY, sendBtnW, sendBtnH, 8)
    nvgFillColor(vg, nvgRGBA(50, 100, 170, math.floor(230 * sp))); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 180, 255, math.floor(180 * sp))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, 240))
    nvgText(vg, sendBtnX + sendBtnW / 2, sendBtnY + sendBtnH / 2, "发送", nil)
    cd.sendBtnRect = { x = sendBtnX, y = sendBtnY, w = sendBtnW, h = sendBtnH }

    -- 关闭按钮
    local clR = 16
    local clX = px + pw - 25
    local clY = py + 20
    nvgBeginPath(vg); nvgCircle(vg, clX, clY, clR)
    nvgFillColor(vg, nvgRGBA(60, 50, 40, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 140, 110, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
    nvgText(vg, clX, clY, "X", nil)
    cd.closeBtnRect = { x = clX - clR, y = clY - clR, w = clR * 2, h = clR * 2 }
end

return M
