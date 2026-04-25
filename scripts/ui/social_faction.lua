-- ui/social_faction.lua - 三国武灵录 (从 social.lua 拆分)
function DrawFactionSubView(W, H, bodyTop, pad, cx, info)
    local sv = factionUI.subView
    -- 子视图返回按钮
    local sbW, sbH = 80, 32
    local sbX, sbY = pad, bodyTop + 4
    nvgBeginPath(vg); nvgRoundedRect(vg, sbX, sbY, sbW, sbH, 6)
    nvgFillColor(vg, nvgRGBA(40, 40, 55, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 100, 140, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 240))
    nvgText(vg, sbX + sbW / 2, sbY + sbH / 2, "< 杩斿洖", nil)
    menuBtnRects.factionSubBack = { x = sbX, y = sbY, w = sbW, h = sbH }

    local panelTop = sbY + sbH + 12
    local panelW = W - pad * 2

    if sv == "upgrade" then
        -- ======== 阵营升级 ========
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
        nvgText(vg, cx, panelTop, "阵营升级", nil)
        panelTop = panelTop + 36

        local lvInfo = CloudManager.GetFactionLevelInfo()

        -- 等级卡片
        local cardH = 180
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, panelTop, panelW, cardH, 10)
        nvgFillColor(vg, nvgRGBA(20, 20, 30, 210)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 140, 220, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 大等级数字
        nvgFontSize(vg, 48); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 200, 255, 255))
        nvgText(vg, cx, panelTop + 40, "Lv." .. lvInfo.level, nil)

        -- 等级名称
        local lvNames = { "新立", "初建", "崛起", "壮大", "兴盛", "鼎盛", "强盛", "霸业", "至尊", "无双" }
        nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(255, 220, 140, 220))
        nvgText(vg, cx, panelTop + 70, lvNames[lvInfo.level] or "未知", nil)

        -- 经验进度条
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
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        local expStr = lvInfo.level >= lvInfo.maxLevel and "经验 MAX" or ("经验 " .. lvInfo.exp .. " / " .. lvInfo.nextLevelExp)
        nvgText(vg, barX + barW / 2, barY + barH / 2, expStr, nil)

        -- 等级加成说明
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 200))
        local roleBonus = lvInfo.roleBonusPercent or 0
        if roleBonus > 0 then
            nvgText(vg, cx, panelTop + 124, "当前加成: 全员 +" .. lvInfo.buffPercent .. "% | 职位额外 +" .. string.format("%.1f", roleBonus) .. "%", nil)
        else
            nvgText(vg, cx, panelTop + 124, "当前加成: 全员战力 +" .. lvInfo.buffPercent .. "%", nil)
        end

        -- 下级预览
        if lvInfo.level < lvInfo.maxLevel then
            nvgFontSize(vg, 20); nvgFillColor(vg, nvgRGBA(160, 160, 170, 180))
            nvgText(vg, cx, panelTop + 148, "下一级 Lv." .. (lvInfo.level + 1) .. ": 全员战力 +" .. ((lvInfo.level + 1) * 2) .. "%", nil)
        else
            nvgFontSize(vg, 20); nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
            nvgText(vg, cx, panelTop + 148, "已达最高等级!", nil)
        end

        -- 升级方式提示
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 190, 170, 180))
        nvgText(vg, cx, panelTop + cardH + 16, "通过「阵营捐献」积累经验来升级", nil)

        -- 资金统计
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 220, 140, 220))
        nvgText(vg, cx, panelTop + cardH + 44, "阵营资金: " .. CloudManager.GetFactionFunds() .. " 玉壁", nil)

        -- 阵营排行榜按钮
        local rankBtnW, rankBtnH = 160, 38
        local rankBtnX = cx - rankBtnW / 2
        local rankBtnY = panelTop + cardH + 72
        nvgBeginPath(vg); nvgRoundedRect(vg, rankBtnX, rankBtnY, rankBtnW, rankBtnH, 8)
        nvgFillColor(vg, nvgRGBA(50, 40, 80, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(140, 120, 220, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 255, 240))
        nvgText(vg, cx, rankBtnY + rankBtnH / 2, "阵营等级排行榜", nil)
        menuBtnRects.factionRankBtn = { x = rankBtnX, y = rankBtnY, w = rankBtnW, h = rankBtnH }

    elseif sv == "donate" then
        -- ======== 阵营升级 ========
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
        nvgText(vg, cx, panelTop, "阵营升级", nil)
        panelTop = panelTop + 36

        local cardH = 260
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, panelTop, panelW, cardH, 10)
        nvgFillColor(vg, nvgRGBA(20, 20, 30, 210)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        local donateConf = CloudManager.GetDonateConfig()
        local todayDone = CloudManager.GetTodayDonation()
        local myContrib = CloudManager.GetMyContribution()
        local myJade = playerInfo.jade or 0

        -- 个人信息
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local iy = panelTop + 16
        nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
        nvgText(vg, pad + 16, iy, "我的玉壁:", nil)
        nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
        nvgText(vg, pad + 120, iy, tostring(myJade), nil)

        iy = iy + 28
        nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
        nvgText(vg, pad + 16, iy, "累计贡献:", nil)
        nvgFillColor(vg, nvgRGBA(255, 220, 140, 240))
        nvgText(vg, pad + 120, iy, tostring(myContrib), nil)

        iy = iy + 28
        nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
        nvgText(vg, pad + 16, iy, "今日已捐:", nil)
        nvgFillColor(vg, nvgRGBA(200, 200, 210, 240))
        nvgText(vg, pad + 120, iy, tostring(todayDone) .. " 玉壁", nil)

        -- 捐献额度选择
        iy = iy + 40
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
        nvgText(vg, cx, iy, "选择捐献数量", nil)
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
            nvgFontSize(vg, 22)
            nvgFillColor(vg, isSel and nvgRGBA(220, 255, 180, 255) or nvgRGBA(200, 200, 210, 220))
            nvgText(vg, ax + aBtnW / 2, iy + aBtnH / 2, tostring(amt), nil)
            menuBtnRects["factionDonateAmt_" .. ai] = { x = ax, y = iy, w = aBtnW, h = aBtnH, amount = amt }
        end

        -- 捐献按钮
        iy = iy + aBtnH + 20
        local dBtnW, dBtnH = 180, 44
        local dBtnX = cx - dBtnW / 2
        local canDonate = myJade >= factionUI.donateAmount and not factionUI.donating
        nvgBeginPath(vg); nvgRoundedRect(vg, dBtnX, iy, dBtnW, dBtnH, 8)
        nvgFillColor(vg, canDonate and nvgRGBA(60, 120, 40, 230) or nvgRGBA(50, 50, 50, 200)); nvgFill(vg)
        nvgStrokeColor(vg, canDonate and nvgRGBA(140, 220, 80, 180) or nvgRGBA(80, 80, 80, 120)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, canDonate and nvgRGBA(255, 255, 230, 255) or nvgRGBA(120, 120, 120, 200))
        local donateLabel = factionUI.donating and "捐献中..." or ("捐献 " .. factionUI.donateAmount .. " 玉壁")
        nvgText(vg, cx, iy + dBtnH / 2, donateLabel, nil)
        if canDonate then
            menuBtnRects.factionDonate = { x = dBtnX, y = iy, w = dBtnW, h = dBtnH }
        end

    elseif sv == "announce" then
        -- ======== 阵营升级 ========
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
        nvgText(vg, cx, panelTop, "阵营升级", nil)
        panelTop = panelTop + 36

        local cardH = 220
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, panelTop, panelW, cardH, 10)
        nvgFillColor(vg, nvgRGBA(20, 20, 30, 210)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        local currentAnn = CloudManager.GetFactionAnnouncement()
        local myLevel = CloudManager.GetRoleLevel(info.role)
        local canEdit = myLevel >= CloudManager.GetRoleLevel("vice_leader")

        -- 当前公告显示
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
        nvgText(vg, pad + 16, panelTop + 16, "当前公告:", nil)

        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(255, 240, 210, 230))
        local dispAnn = (#currentAnn > 0) and currentAnn or "(暂无公告)"
        -- 自动折行显示公告
        nvgTextBox(vg, pad + 16, panelTop + 42, panelW - 32, dispAnn, nil)

        if canEdit then
            -- 编辑区
            local editY = panelTop + 110
            nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
            nvgFontSize(vg, 22)
            nvgText(vg, pad + 16, editY, "编辑新公告 (200字内):", nil)

            -- 输入框
            local inputY = editY + 22
            local inputH = 42
            nvgBeginPath(vg); nvgRoundedRect(vg, pad + 12, inputY, panelW - 24, inputH, 6)
            nvgFillColor(vg, nvgRGBA(10, 10, 18, 200)); nvgFill(vg)
            nvgStrokeColor(vg, factionUI.inputTarget == "announce" and nvgRGBA(200, 180, 80, 200) or nvgRGBA(80, 70, 60, 150))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if #factionUI.announceInput > 0 then
                nvgFillColor(vg, nvgRGBA(255, 240, 210, 240))
                nvgText(vg, pad + 18, inputY + inputH / 2, factionUI.announceInput, nil)
            else
                nvgFillColor(vg, nvgRGBA(120, 115, 100, 150))
                nvgText(vg, pad + 18, inputY + inputH / 2, "点击输入公告内容...", nil)
            end
            menuBtnRects.factionAnnounceInput = { x = pad + 12, y = inputY, w = panelW - 24, h = inputH }

            -- 保存按钮
            local saveBtnW, saveBtnH = 140, 40
            local saveBtnX = cx - saveBtnW / 2
            local saveBtnY = inputY + inputH + 14
            nvgBeginPath(vg); nvgRoundedRect(vg, saveBtnX, saveBtnY, saveBtnW, saveBtnH, 8)
            nvgFillColor(vg, nvgRGBA(60, 100, 140, 230)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 160, 220, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 240, 255))
            nvgText(vg, saveBtnX + saveBtnW / 2, saveBtnY + saveBtnH / 2, "保存公告", nil)
            menuBtnRects.factionAnnounceSave = { x = saveBtnX, y = saveBtnY, w = saveBtnW, h = saveBtnH }
        else
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(160, 150, 140, 180))
            nvgText(vg, cx, panelTop + 130, "副盟主及以上可编辑公告", nil)
        end

    elseif sv == "contrib" then
        -- ======== 阵营升级 ========
        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
        nvgText(vg, cx, panelTop, "阵营升级", nil)
        panelTop = panelTop + 36

        -- 加载贡献数据
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
                            e.name = nameMap[e.uid] or ("玩家" .. tostring(e.uid))
                        end
                        factionUI.contribList = rawList; factionUI.contribLoaded = true; factionUI.contribLoading = false
                    end,
                    onError = function()
                        for _, e in ipairs(rawList) do e.name = "玩家" .. tostring(e.uid) end
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
            nvgText(vg, cx, baseY2 + listH2 / 2, "加载中...", nil)
        elseif cCount == 0 then
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 180, 190, 200))
            nvgText(vg, cx, baseY2 + listH2 / 2, "暂无贡献数据", nil)
        else
            local myUid = CloudAPI.GetUserId()
            local medals = {"[1]", "[2]", "[3]"}
            for i, e in ipairs(cList) do
                local ry = baseY2 + 10 + (i - 1) * rowH2
                local isMe = (e.uid == myUid)
                -- 行背景
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
                -- 排名
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
                -- 名字
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if isMe then
                    nvgFillColor(vg, nvgRGBA(120, 200, 255, 240))
                elseif i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 235, 175, 230))
                else nvgFillColor(vg, nvgRGBA(210, 200, 180, 220)) end
                nvgText(vg, pad + 54, ry + rowH2 / 2, (e.name or "?") .. (isMe and " (我)" or ""), nil)
                -- 贡献值
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 200, 80, 240))
                else nvgFillColor(vg, nvgRGBA(220, 180, 120, 210)) end
                nvgText(vg, pad + panelW - 16, ry + rowH2 / 2, FormatPower(e.amount or 0), nil)
                -- 分隔线
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
-- 阵营界面 (完整实现)
-- ===========================
function DrawFactionScreen()
    local W, H = DESIGN_W, DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0
    DrawSocialBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 每帧清除所有阵营 tab 内的按钮 rect，防止切换 tab 时旧按钮残留导致点击穿透
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

    -- 返回按钮
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 杩斿洖")
    menuBtnRects.factionBack = { x = backX, y = backY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 30); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 32, "阵营")

    local info = CloudManager.GetFactionInfo()
    local hasFaction = info and info.id and info.id > 0
    local contentTop = 64
    local pad = 14

    if hasFaction then
        -- ======== 已加入阵营 ========
        -- Tab 栏: 信息 | 成员
        local tabs = { { id = "info", label = "信息" }, { id = "members", label = "成员" } } -- 聊天暂时隐藏
        -- 有管理权限时增加申请标签
        local myLevel = CloudManager.GetRoleLevel(info.role)
        if myLevel >= 5 then
            table.insert(tabs, { id = "apply", label = "申请" })
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
            -- 盟主首次打开信息页时，后台验证成员是否已离开（自动清理camp_meta）
            if info.role == "leader" and not factionUI.memberValidated then
                factionUI.memberValidated = true
                CloudManager.GetFactionMembers(function(_) end)  -- 触发内部清理逻辑
            end
            -- 异步查询盟主昵称 (仅查一次)
            if info.meta and info.meta.leaderId and not factionUI.leaderNickLoaded then
                factionUI.leaderNickLoaded = true
                factionUI.leaderNickname = nil
                if rawget(_G, "GetUserNickname") then
                    GetUserNickname({
                        userIds = { info.meta.leaderId },
                        onSuccess = function(nicknames)
                            if nicknames and #nicknames > 0 then
                                factionUI.leaderNickname = nicknames[1].nickname or "未知"
                            end
                        end,
                        onError = function() end,
                    })
                end
            end

            -- 阵营名称
            nvgFontSize(vg, 28); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 255))
            nvgText(vg, cx, bodyTop + 20, info.name or "未知阵营", nil)
            -- 盟主改名按钮
            if info.role == "leader" then
                local rnBtnW, rnBtnH = 48, 24
                local nameTextW = nvgTextBounds(vg, 0, 0, info.name or "未知阵营", nil)
                local rnBtnX = cx + nameTextW / 2 + 8
                local rnBtnY = bodyTop + 20 - rnBtnH / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, rnBtnX, rnBtnY, rnBtnW, rnBtnH, 4)
                nvgFillColor(vg, nvgRGBA(60, 55, 40, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 160)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 220, 130, 230))
                nvgText(vg, rnBtnX + rnBtnW / 2, rnBtnY + rnBtnH / 2, "改名", nil)
                menuBtnRects.factionRename = { x = rnBtnX, y = rnBtnY, w = rnBtnW, h = rnBtnH }
            end

            -- ======== 子视图: 升级/捐献/公告 ========
            if factionUI.subView then
                DrawFactionSubView(W, H, bodyTop, pad, cx, info)
            else
            -- 阵营信息卡片
            local lvInfo = CloudManager.GetFactionLevelInfo()
            local cardY = bodyTop + 50
            local cardH = 230
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, cardY, W - pad * 2, cardH, 10)
            nvgFillColor(vg, nvgRGBA(20, 20, 30, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 60, 40, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            local leaderDisplay = factionUI.leaderNickname or "加载中..."
            local roleBonus2 = lvInfo.roleBonusPercent or 0
            local buffDisplay = "战力+" .. lvInfo.buffPercent .. "%"
            if roleBonus2 > 0 then
                buffDisplay = buffDisplay .. " +职位" .. string.format("%.1f", roleBonus2) .. "%"
            end
            local infoLines = {
                { "阵营等级", "Lv." .. lvInfo.level .. " (" .. buffDisplay .. ")" },
                { "我的职位", CloudManager.GetRoleName(info.role) or "成员" },
                { "成员数", info.meta and tostring(info.meta.memberCount or 0) .. "/" .. tostring(info.meta.maxMembers or 20) or "?" },
                { "阵营资金", tostring(CloudManager.GetFactionFunds()) .. " 玉壁" },
                { "盟主", leaderDisplay },
            }
            if info.meta and info.meta.desc and #info.meta.desc > 0 then
                table.insert(infoLines, { "简介", info.meta.desc })
            end
            for j, line in ipairs(infoLines) do
                local ly = cardY + 14 + (j - 1) * 30
                nvgFillColor(vg, nvgRGBA(160, 150, 130, 200))
                nvgText(vg, pad + 16, ly, line[1] .. ":", nil)
                nvgFillColor(vg, nvgRGBA(255, 240, 210, 240))
                nvgText(vg, pad + 110, ly, line[2], nil)
            end

            -- 经验条 (紧贴信息行下方)
            local expBarY = cardY + 14 + #infoLines * 30 + 4
            local expBarX = pad + 16
            local expBarW = W - pad * 2 - 32
            local expBarH = 14
            local expRange = lvInfo.nextLevelExp - lvInfo.curLevelExp
            local expProgress = expRange > 0 and math.min(1.0, (lvInfo.exp - lvInfo.curLevelExp) / expRange) or 1.0
            if lvInfo.level >= lvInfo.maxLevel then expProgress = 1.0 end
            -- 背景
            nvgBeginPath(vg); nvgRoundedRect(vg, expBarX, expBarY, expBarW, expBarH, 4)
            nvgFillColor(vg, nvgRGBA(15, 15, 25, 200)); nvgFill(vg)
            -- 填充
            if expProgress > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, expBarX, expBarY, expBarW * expProgress, expBarH, 4)
                nvgFillColor(vg, nvgRGBA(80, 180, 255, 200)); nvgFill(vg)
            end
            -- 经验文字
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
            local expText = lvInfo.level >= lvInfo.maxLevel and "MAX" or (lvInfo.exp .. "/" .. lvInfo.nextLevelExp)
            nvgText(vg, expBarX + expBarW / 2, expBarY + expBarH / 2, expText, nil)

            -- 公告显示
            local annText = CloudManager.GetFactionAnnouncement()
            local annY = cardY + cardH + 8
            if annText and #annText > 0 then
                nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 200, 80, 180))
                nvgText(vg, pad + 6, annY, "公告:", nil)
                nvgFillColor(vg, nvgRGBA(230, 225, 210, 200))
                nvgText(vg, pad + 52, annY, annText, nil)
                annY = annY + 22
            end

            -- 退出阵营按钮
            local leaveW, leaveH = 160, 42
            local leaveX = cx - leaveW / 2
            local leaveY = annY + 10
            nvgBeginPath(vg); nvgRoundedRect(vg, leaveX, leaveY, leaveW, leaveH, 8)
            nvgFillColor(vg, nvgRGBA(120, 30, 30, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 60, 60, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
            nvgText(vg, cx, leaveY + leaveH / 2, info.role == "leader" and "解散阵营" or "退出阵营", nil)
            menuBtnRects.factionLeave = { x = leaveX, y = leaveY, w = leaveW, h = leaveH }

            -- ======== 阵营功能入口网格 ========
            local featureTop = leaveY + leaveH + 18
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 180, 140, 200))
            nvgText(vg, pad + 4, featureTop, "阵营功能", nil)
            featureTop = featureTop + 26

            local hasSignedIn = CloudManager.HasSignedInToday()
            local features = {
                { id = "manage",   icon = "👑", label = "成员管理", ready = true },
                -- { id = "chat",     icon = "💬", label = "阵营聊天", ready = true }, -- 暂时隐藏
                { id = "upgrade",  icon = "⬆", label = "阵营升级", ready = true },
                { id = "donate",   icon = "💰", label = "阵营捐献", ready = true },
                { id = "signIn",   icon = "📅", label = hasSignedIn and "已签到" or "每日签到", ready = true, done = hasSignedIn },
                { id = "announce", icon = "📢", label = "阵营公告", ready = true },
                { id = "rank",     icon = "🏆", label = "阵营排行", ready = true },
                { id = "contrib",  icon = "📊", label = "成员贡献", ready = true },
                { id = "shop",     icon = "🏪", label = "阵营商店" },
                { id = "war",      icon = "⚔", label = "阵营战争" },
                { id = "task",     icon = "馃搵", label = "阵营任务" },
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
                -- 背景
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
                -- 图标
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if feat.done then
                    nvgFillColor(vg, nvgRGBA(120, 200, 120, 180))
                elseif feat.ready then
                    nvgFillColor(vg, nvgRGBA(120, 200, 255, 240))
                else nvgFillColor(vg, nvgRGBA(255, 220, 120, 220)) end
                nvgText(vg, fx + fBtnW / 2, fy + fBtnH / 2 - 10, feat.icon, nil)
                -- 文字
                nvgFontSize(vg, 20)
                if feat.done then
                    nvgFillColor(vg, nvgRGBA(150, 200, 150, 200))
                elseif feat.ready then
                    nvgFillColor(vg, nvgRGBA(220, 230, 240, 240))
                else nvgFillColor(vg, nvgRGBA(180, 175, 160, 200)) end
                nvgText(vg, fx + fBtnW / 2, fy + fBtnH / 2 + 16, feat.label, nil)
                -- "待开发"角标（仅未就绪的功能）
                if not feat.ready then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(255, 120, 60, 180))
                    nvgText(vg, fx + fBtnW - 4, fy + 3, "待开发", nil)
                end
                -- 注册点击区
                menuBtnRects["factionFeat_" .. feat.id] = { x = fx, y = fy, w = fBtnW, h = fBtnH }
            end
            end -- subView else

            -- ======== 阵营排行榜弹出面板（覆盖在 info tab 之上） ========
            if factionUI.showRank then
                -- 加载数据
                if not factionUI.rankLoaded and not factionUI.rankLoading then
                    LoadFactionLevelRank()
                end

                -- 暗幕
                nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
                menuBtnRects.factionRankOverlay = { x = 0, y = 0, w = W, h = H }

                local rpW = W - 50
                local rpH = H * 0.72
                local rpX = 25
                local rpY = (H - rpH) / 2

                -- 面板背景
                nvgBeginPath(vg); nvgRoundedRect(vg, rpX, rpY, rpW, rpH, 12)
                nvgFillColor(vg, nvgRGBA(20, 18, 35, 245)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(140, 120, 220, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

                -- 标题
                nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(cx, rpY + 30, "阵营等级排行榜")

                -- 排行列表
                local listTop = rpY + 58
                local listH = rpH - 110
                local rowH = 38

                if factionUI.rankLoading then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(180, 180, 190, 200))
                    nvgText(vg, cx, rpY + rpH / 2, "加载中...", nil)
                elseif #factionUI.rankList == 0 then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(180, 180, 190, 200))
                    nvgText(vg, cx, rpY + rpH / 2, "暂无排行数据", nil)
                else
                    local lvNames = { "新立", "初建", "崛起", "壮大", "兴盛", "鼎盛", "强盛", "霸业", "至尊", "无双" }
                    local myCampId = CloudManager._factionId or 0
                    -- 表头
                    nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(140, 130, 160, 180))
                    nvgText(vg, rpX + 12, listTop, "排名", nil)
                    nvgText(vg, rpX + 52, listTop, "阵营名", nil)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgText(vg, rpX + rpW - 120, listTop, "等级", nil)
                    nvgText(vg, rpX + rpW - 45, listTop, "加成", nil)
                    listTop = listTop + 22

                    local maxShow = math.min(#factionUI.rankList, math.floor(listH / rowH))
                    for i = 1, maxShow do
                        local r = factionUI.rankList[i]
                        local ry = listTop + (i - 1) * rowH
                        local isMe = (r.campId == myCampId)

                        -- 行背景
                        if isMe then
                            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + 6, ry, rpW - 12, rowH - 2, 4)
                            nvgFillColor(vg, nvgRGBA(80, 100, 50, 120)); nvgFill(vg)
                        elseif i % 2 == 0 then
                            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + 6, ry, rpW - 12, rowH - 2, 4)
                            nvgFillColor(vg, nvgRGBA(30, 28, 45, 100)); nvgFill(vg)
                        end

                        -- 排名
                        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
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

                        -- 阵营名
                        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
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

                        -- 等级
                        local lvName = lvNames[r.level] or "?"
                        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(100, 200, 255, 240))
                        nvgText(vg, rpX + rpW - 120, ry + rowH / 2, "Lv." .. r.level .. " " .. lvName, nil)

                        -- 加成
                        nvgFillColor(vg, nvgRGBA(255, 220, 140, 220))
                        nvgText(vg, rpX + rpW - 45, ry + rowH / 2, "+" .. (r.level * 2) .. "%", nil)
                    end
                end

                -- 关闭按钮
                local closeBtnW, closeBtnH = 100, 36
                local closeBtnX = cx - closeBtnW / 2
                local closeBtnY = rpY + rpH - 48
                nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
                nvgFillColor(vg, nvgRGBA(60, 50, 80, 230)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(140, 120, 200, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(220, 210, 240, 240))
                nvgText(vg, cx, closeBtnY + closeBtnH / 2, "关闭", nil)
                menuBtnRects.factionRankClose = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }
            end

        elseif factionUI.tab == "members" then
            -- 成员列表
            if not factionUI.loaded and not factionUI.loading then
                factionUI.loading = true
                CloudManager.GetFactionMembers(function(members)
                    factionUI.members = members or {}
                    -- 按职位等级降序, 同职位按战力降序排序
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
                    -- 缓存当前玩家的平台昵称 (用于聊天显示)
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
                nvgText(vg, cx, bodyTop + 60, "加载中...", nil)
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
                    -- 名字
                    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
                    nvgText(vg, pad + 14, cy + cardH / 2 - 8, mem.nickname or ("玩家" .. tostring(mem.userId or "")), nil)
                    -- 职位
                    local role, roleName = CloudManager.GetMemberRole(mem.userId)
                    nvgFontSize(vg, 22); nvgFillColor(vg, nvgRGBA(255, 180, 80, 200))
                    nvgText(vg, pad + 14, cy + cardH / 2 + 14, roleName or "成员", nil)
                    -- 战力 + 设职按钮
                    local rightX = W - pad - 14
                    if canSetRole and mem.userId ~= myUid and role ~= "leader" then
                        local cursorX = rightX
                        -- 踢出按钮 (盟主/副盟主对下级可见)
                        local kickBtnW, kickBtnH = 48, 28
                        local kickBtnX = cursorX - kickBtnW
                        local kickBtnY = cy + (cardH - kickBtnH) / 2
                        nvgBeginPath(vg); nvgRoundedRect(vg, kickBtnX, kickBtnY, kickBtnW, kickBtnH, 5)
                        nvgFillColor(vg, nvgRGBA(90, 30, 30, 220)); nvgFill(vg)
                        nvgStrokeColor(vg, nvgRGBA(200, 80, 80, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(255, 180, 180, 240))
                        nvgText(vg, kickBtnX + kickBtnW / 2, kickBtnY + kickBtnH / 2, "踢出", nil)
                        menuBtnRects["factionKick_" .. mi] = { x = kickBtnX, y = kickBtnY, w = kickBtnW, h = kickBtnH, userId = mem.userId, nickname = mem.nickname }
                        cursorX = kickBtnX - 6
                        -- 设置职位按钮
                        local setBtnW, setBtnH = 52, 28
                        local setBtnX = cursorX - setBtnW
                        local setBtnY = cy + (cardH - setBtnH) / 2
                        nvgBeginPath(vg); nvgRoundedRect(vg, setBtnX, setBtnY, setBtnW, setBtnH, 5)
                        nvgFillColor(vg, nvgRGBA(60, 50, 90, 220)); nvgFill(vg)
                        nvgStrokeColor(vg, nvgRGBA(160, 140, 200, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(220, 210, 255, 240))
                        nvgText(vg, setBtnX + setBtnW / 2, setBtnY + setBtnH / 2, "职位", nil)
                        menuBtnRects["factionSetRole_" .. mi] = { x = setBtnX, y = setBtnY, w = setBtnW, h = setBtnH, userId = mem.userId, currentRole = role, nickname = mem.nickname }
                        -- 战力放在按钮左边
                        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                        nvgFontSize(vg, 22); nvgFillColor(vg, nvgRGBA(160, 160, 160, 180))
                        nvgText(vg, setBtnX - 8, cy + cardH / 2, "战力 " .. tostring(mem.combatPower or 0), nil)
                    else
                        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                        nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(160, 160, 160, 180))
                        nvgText(vg, rightX, cy + cardH / 2, "战力 " .. tostring(mem.combatPower or 0), nil)
                    end
                end
                if #factionUI.members == 0 then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                    nvgText(vg, cx, bodyTop + 60, "暂无成员数据", nil)
                end
                nvgRestore(vg)

                -- 职位选择弹窗
                if factionUI.rolePopup then
                    local rp = factionUI.rolePopup
                    local roleList = { "vice_leader", "strategist", "vanguard", "diplomat", "elite", "member" }
                    local roleNames = { vice_leader="副盟主", strategist="军师", vanguard="先锋官", diplomat="外交官", elite="精英", member="成员" }
                    local popW, popItemH = 140, 36
                    local popH = #roleList * popItemH + 40
                    local popX = (W - popW) / 2
                    local popY = (H - popH) / 2
                    -- 遮罩
                    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150)); nvgFill(vg)
                    -- 弹窗背景
                    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
                    nvgFillColor(vg, nvgRGBA(30, 28, 40, 245)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(120, 100, 180, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                    -- 标题
                    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 220, 160, 240))
                    nvgText(vg, popX + popW / 2, popY + 18, "设置职位", nil)
                    -- 选项
                    for ri, rk in ipairs(roleList) do
                        local iy = popY + 36 + (ri - 1) * popItemH
                        local isCurrent = (rk == rp.currentRole)
                        nvgBeginPath(vg); nvgRoundedRect(vg, popX + 8, iy, popW - 16, popItemH - 4, 6)
                        if isCurrent then
                            nvgFillColor(vg, nvgRGBA(80, 70, 50, 200)); nvgFill(vg)
                        else
                            nvgFillColor(vg, nvgRGBA(40, 38, 55, 180)); nvgFill(vg)
                        end
                        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, isCurrent and nvgRGBA(255, 200, 100, 255) or nvgRGBA(210, 205, 195, 230))
                        nvgText(vg, popX + popW / 2, iy + (popItemH - 4) / 2, roleNames[rk] or rk, nil)
                        menuBtnRects["factionRoleOption_" .. ri] = { x = popX + 8, y = iy, w = popW - 16, h = popItemH - 4, roleKey = rk }
                    end
-- 阵营界面 (完整实现)
                    menuBtnRects.factionRolePopupBg = { x = 0, y = 0, w = W, h = H, isOverlay = true }
                end
            end

        elseif factionUI.tab == "apply" then
            -- 入队申请 (副盟主以上可见)
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
                nvgText(vg, cx, bodyTop + 60, "加载中...", nil)
            else
                local cardH = 56
                local cardGap = 6
                for ai, app in ipairs(factionUI.applications) do
                    local cy = bodyTop + (ai - 1) * (cardH + cardGap)
                    nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, cardH, 8)
                    nvgFillColor(vg, nvgRGBA(25, 25, 35, 200)); nvgFill(vg)
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
                    nvgText(vg, pad + 14, cy + cardH / 2, app.nickname or ("玩家" .. tostring(app.userId)), nil)
                    -- 同意按钮
                    local btnW, btnH = 56, 32
                    local acceptX = W - pad - btnW * 2 - 10
                    local rejectX = W - pad - btnW
                    nvgBeginPath(vg); nvgRoundedRect(vg, acceptX, cy + (cardH - btnH) / 2, btnW, btnH, 6)
                    nvgFillColor(vg, nvgRGBA(40, 100, 40, 220)); nvgFill(vg)
                    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(200, 255, 200, 255))
                    nvgText(vg, acceptX + btnW / 2, cy + cardH / 2, "同意", nil)
                    menuBtnRects["factionAccept_" .. ai] = { x = acceptX, y = cy + (cardH - btnH) / 2, w = btnW, h = btnH, userId = app.userId }
                    -- 拒绝按钮
                    nvgBeginPath(vg); nvgRoundedRect(vg, rejectX, cy + (cardH - btnH) / 2, btnW, btnH, 6)
                    nvgFillColor(vg, nvgRGBA(100, 30, 30, 220)); nvgFill(vg)
                    nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
                    nvgText(vg, rejectX + btnW / 2, cy + cardH / 2, "拒绝", nil)
                    menuBtnRects["factionReject_" .. ai] = { x = rejectX, y = cy + (cardH - btnH) / 2, w = btnW, h = btnH, userId = app.userId }
                end
                if #factionUI.applications == 0 then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                    nvgText(vg, cx, bodyTop + 60, "暂无入队申请", nil)
                end
            end

        elseif factionUI.tab == "chat" then
            -- ======== 阵营聊天 (云端同步) ========
            local chatAreaH = H - bodyTop - 70
            -- 消息区域背景
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, bodyTop, W - pad * 2, chatAreaH, 8)
            nvgFillColor(vg, nvgRGBA(15, 15, 20, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(60, 55, 50, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 首次进入聊天tab立即拉取一次
            if not factionUI.chatPolled then
                factionUI.chatPolled = true
                CloudManager.PollFactionChat()
            end

            -- 消息列表 (从CloudManager读取)
            nvgSave(vg)
            nvgScissor(vg, pad, bodyTop, W - pad * 2, chatAreaH)
            local fcAvS = 28  -- 阵营聊天头像尺寸
            local msgH = fcAvS + 12
            local msgs = CloudManager.GetFactionChatMessages()
            local visibleCount = math.floor(chatAreaH / msgH)
            local startIdx = math.max(1, #msgs - visibleCount + 1)
            factionUI._chatAvatarRects = factionUI._chatAvatarRects or {}
            factionUI._chatAvatarRects = {}
            for i = startIdx, #msgs do
                local msg = msgs[i]
                local my = bodyTop + (i - startIdx) * msgH + 4
                -- 头像 (可点击)
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
                -- 名字 + 时间
                local fcTxtX = fcAvX + fcAvS + 8
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(120, 200, 255, 220))
                nvgText(vg, fcTxtX, my, msg.name or "???", nil)
                -- 时间
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(120, 120, 120, 150))
                nvgText(vg, W - pad - 10, my, msg.time or "", nil)
                -- 内容
                nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(230, 225, 215, 240))
                nvgText(vg, fcTxtX, my + 16, msg.text or "", nil)
            end
            if #msgs == 0 then
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(130, 130, 130, 160))
                nvgText(vg, cx, bodyTop + chatAreaH / 2, "暂无消息，说点什么吧", nil)
            end
            nvgRestore(vg)

            -- 阵营聊天玩家信息弹窗（点击头像弹出）
            if factionUI.chatNamePopup then
                local pp = factionUI.chatNamePopup
                local ppW, ppH = 160, 60
                local ppX = math.min(pp.x + fcAvS + 4, W - pad - ppW - 4)
                local ppY = pp.y - 4
                if ppY + ppH > bodyTop + chatAreaH then ppY = pp.y - ppH - 4 end
                if ppY < bodyTop then ppY = bodyTop + 4 end
                -- 弹窗背景
                nvgBeginPath(vg); nvgRoundedRect(vg, ppX, ppY, ppW, ppH, 8)
                nvgFillColor(vg, nvgRGBA(40, 35, 55, 245)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(100, 160, 240, 200)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
                -- 弹窗内头像
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
                -- 名字
                local ppTxtX2 = ppAvX2 + ppAvS2 + 8
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(120, 200, 255, 240))
                nvgText(vg, ppTxtX2, ppY + ppH / 2 - 8, pp.name or "???", nil)
                -- 添加好友按钮
                local addBtnW2, addBtnH2 = 70, 22
                local addBtnX2 = ppTxtX2
                local addBtnY2 = ppY + ppH / 2 + 6
                local isFriend2 = CloudManager.IsFriend(pp.uid)
                local isMe2 = (CloudAPI.IsAvailable() and pp.uid == CloudAPI.GetUserId())
                if isMe2 then
                    nvgFontSize(vg, 20); nvgFillColor(vg, nvgRGBA(120, 120, 120, 180))
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgText(vg, addBtnX2, addBtnY2 + addBtnH2 / 2, "锛堣嚜宸憋級", nil)
                elseif isFriend2 then
                    nvgFontSize(vg, 20); nvgFillColor(vg, nvgRGBA(100, 200, 140, 200))
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgText(vg, addBtnX2, addBtnY2 + addBtnH2 / 2, "已是好友", nil)
                else
                    nvgBeginPath(vg); nvgRoundedRect(vg, addBtnX2, addBtnY2, addBtnW2, addBtnH2, 4)
                    nvgFillColor(vg, nvgRGBA(40, 100, 60, 220)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100, 220, 140, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(100, 240, 140, 255))
                    nvgText(vg, addBtnX2 + addBtnW2 / 2, addBtnY2 + addBtnH2 / 2, "+ 加好友", nil)
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

            -- 输入栏
            local inputY = bodyTop + chatAreaH + 6
            local sendW = 60
            local inputW2 = W - pad * 2 - sendW - 6
            -- 输入框
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, inputY, inputW2, 40, 6)
            nvgFillColor(vg, nvgRGBA(20, 20, 28, 220)); nvgFill(vg)
            local chatActive = (factionUI.inputTarget == "chat")
            nvgStrokeColor(vg, chatActive and nvgRGBA(120, 180, 255, 200) or nvgRGBA(60, 60, 70, 150))
            nvgStrokeWidth(vg, chatActive and 2 or 1); nvgStroke(vg)
            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if factionUI.chatInput and #factionUI.chatInput > 0 then
                nvgFillColor(vg, nvgRGBA(240, 235, 220, 240))
                nvgText(vg, pad + 10, inputY + 20, factionUI.chatInput, nil)
            else
                nvgFillColor(vg, nvgRGBA(110, 110, 110, 150))
                nvgText(vg, pad + 10, inputY + 20, "杈撳叆娑堟伅...", nil)
            end
            menuBtnRects.factionChatInput = { x = pad, y = inputY, w = inputW2, h = 40 }
            -- 发送按钮
            local sendX = pad + inputW2 + 6
            nvgBeginPath(vg); nvgRoundedRect(vg, sendX, inputY, sendW, 40, 6)
            nvgFillColor(vg, nvgRGBA(50, 90, 140, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 160, 240, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 230, 255, 255))
            nvgText(vg, sendX + sendW / 2, inputY + 20, "发送", nil)
            menuBtnRects.factionChatSend = { x = sendX, y = inputY, w = sendW, h = 40 }
        end

    else
        -- ======== 未加入阵营 ========
        -- Tab栏: 阵营列表 | 创建阵营
        local tabs = { { id = "list", label = "阵营列表" }, { id = "create", label = "创建阵营" } }
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

        -- 检查申请状态
        if factionUI.applyStatus == "pending" then
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
            nvgText(vg, cx, bodyTop, "已提交申请，等待审批中...", nil)
            local refreshW, refreshH = 120, 36
            local refreshX = cx - refreshW / 2
            local refreshY = bodyTop + 28
            nvgBeginPath(vg); nvgRoundedRect(vg, refreshX, refreshY, refreshW, refreshH, 6)
            nvgFillColor(vg, nvgRGBA(50, 50, 70, 200)); nvgFill(vg)
            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
            nvgText(vg, cx, refreshY + refreshH / 2, "刷新状态", nil)
            menuBtnRects.factionRefreshApply = { x = refreshX, y = refreshY, w = refreshW, h = refreshH }
            bodyTop = refreshY + refreshH + 12
        end

        if factionUI.tab == "list" then
            -- 阵营列表
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
                nvgText(vg, cx, bodyTop + 80, "加载阵营列表...", nil)
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
                    -- 阵营名
                    nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(255, 220, 120, 240))
                    nvgText(vg, pad + 14, cy + 10, fac.name or "?", nil)
                    -- 盟主 & 浜烘暟
                    nvgFontSize(vg, 22); nvgFillColor(vg, nvgRGBA(170, 160, 140, 200))
                    nvgText(vg, pad + 14, cy + 36, "盟主: " .. (fac.leaderNickname or "?"), nil)
                    nvgText(vg, pad + 14, cy + 56, "成员: " .. tostring(fac.memberCount or 0) .. "/20", nil)
-- 阵营界面 (完整实现)
                    local applyBtnW, applyBtnH = 70, 32
                    local applyBtnX = W - pad - applyBtnW - 10
                    local applyBtnY = cy + (cardH - applyBtnH) / 2
                    local outApply = CloudManager._campOutApply
                    local alreadyApplied = outApply and outApply.campId == fac.campId
                    nvgBeginPath(vg); nvgRoundedRect(vg, applyBtnX, applyBtnY, applyBtnW, applyBtnH, 6)
                    if alreadyApplied then
                        nvgFillColor(vg, nvgRGBA(50, 50, 45, 180)); nvgFill(vg)
                        nvgStrokeColor(vg, nvgRGBA(80, 80, 70, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(160, 160, 140, 180))
                        nvgText(vg, applyBtnX + applyBtnW / 2, applyBtnY + applyBtnH / 2, "已申请", nil)
                    else
                        nvgFillColor(vg, nvgRGBA(60, 90, 40, 220)); nvgFill(vg)
                        nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(220, 255, 200, 255))
                        nvgText(vg, applyBtnX + applyBtnW / 2, applyBtnY + applyBtnH / 2, "已申请", nil)
                        menuBtnRects["factionApply_" .. fi] = { x = applyBtnX, y = applyBtnY, w = applyBtnW, h = applyBtnH, campId = fac.campId, campName = fac.name }
                    end
                end
                nvgRestore(vg)
                if #factionUI.factions == 0 then
                    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                    nvgText(vg, cx, bodyTop + 80, "暂无阵营，来创建第一个吧！", nil)
                end
            end

        elseif factionUI.tab == "create" then
            -- 创建阵营
            local formY = bodyTop + 10
            nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
            nvgText(vg, pad + 8, formY, "阵营名称:", nil)

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
                nvgText(vg, pad + 10, nameInputY + inputH / 2, "请输入阵营名称(2-8字)", nil)
            end
            menuBtnRects.factionNameInput = { x = pad, y = nameInputY, w = inputW, h = inputH }

            nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
            nvgText(vg, pad + 8, nameInputY + inputH + 16, "阵营简介(可选):", nil)
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
                nvgText(vg, pad + 10, descInputY + inputH / 2, "一句话介绍你的阵营", nil)
            end
            menuBtnRects.factionDescInput = { x = pad, y = descInputY, w = inputW, h = inputH }

            -- 费用提示
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 180, 80, 180))
            nvgText(vg, cx, descInputY + inputH + 14, "创建消耗 5000 玉壁", nil)

            -- 创建按钮
            local createW, createH = 180, 46
            local createX = cx - createW / 2
            local createY = descInputY + inputH + 44
            local canCreate = #factionUI.createName >= 2
            nvgBeginPath(vg); nvgRoundedRect(vg, createX, createY, createW, createH, 8)
            nvgFillColor(vg, canCreate and nvgRGBA(100, 70, 20, 230) or nvgRGBA(50, 50, 50, 150)); nvgFill(vg)
            nvgStrokeColor(vg, canCreate and nvgRGBA(255, 180, 60, 180) or nvgRGBA(80, 80, 80, 100)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, canCreate and nvgRGBA(255, 230, 150, 255) or nvgRGBA(120, 120, 120, 150))
            nvgText(vg, cx, createY + createH / 2, "创建阵营", nil)
            menuBtnRects.factionCreate = { x = createX, y = createY, w = createW, h = createH }
        end
    end

    -- 改名弹窗
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
        nvgText(vg, cx, rpY + 26, "修改阵营名称", nil)
        nvgFontSize(vg, 20); nvgFillColor(vg, nvgRGBA(255, 200, 100, 180))
        nvgText(vg, cx, rpY + 46, "费用: 1000 玉壁", nil)
        -- 输入框
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
            nvgText(vg, riX + 10, riY + riH / 2, "输入新名称(最多8字)", nil)
        end
        menuBtnRects.factionRenameInput = { x = riX, y = riY, w = riW, h = riH }
        -- 确认/取消按钮
        local rbW, rbH = 100, 36
        local rbY = rpY + rpH - 50
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - rbW - 10, rbY, rbW, rbH, 6)
        nvgFillColor(vg, nvgRGBA(60, 100, 40, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(220, 255, 200, 255)); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, cx - rbW / 2 - 10, rbY + rbH / 2, "确认", nil)
        menuBtnRects.factionRenameYes = { x = cx - rbW - 10, y = rbY, w = rbW, h = rbH }
        nvgBeginPath(vg); nvgRoundedRect(vg, cx + 10, rbY, rbW, rbH, 6)
        nvgFillColor(vg, nvgRGBA(80, 30, 30, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
        nvgText(vg, cx + 10 + rbW / 2, rbY + rbH / 2, "取消", nil)
        menuBtnRects.factionRenameNo = { x = cx + 10, y = rbY, w = rbW, h = rbH }
    end

    -- 确认弹窗
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
        nvgText(vg, cx, popY + 50, pop.msg or "确认操作?", nil)
        local btnW2, btnH2 = 100, 38
        local yBtn = popY + popH - 50
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - btnW2 - 10, yBtn, btnW2, btnH2, 6)
        nvgFillColor(vg, nvgRGBA(60, 100, 40, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(220, 255, 200, 255)); nvgFontSize(vg, 18)
        nvgText(vg, cx - btnW2 / 2 - 10, yBtn + btnH2 / 2, "确认", nil)
        menuBtnRects.factionPopupYes = { x = cx - btnW2 - 10, y = yBtn, w = btnW2, h = btnH2 }
        nvgBeginPath(vg); nvgRoundedRect(vg, cx + 10, yBtn, btnW2, btnH2, 6)
        nvgFillColor(vg, nvgRGBA(80, 30, 30, 220)); nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(255, 200, 200, 255))
        nvgText(vg, cx + 10 + btnW2 / 2, yBtn + btnH2 / 2, "取消", nil)
        menuBtnRects.factionPopupNo = { x = cx + 10, y = yBtn, w = btnW2, h = btnH2 }
    end
end


-- ===========================
-- 阵营界面 (完整实现)
-- ===========================
-- ============================================================================
-- 交易行界面
-- ============================================================================

