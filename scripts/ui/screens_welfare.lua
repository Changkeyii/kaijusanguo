-- ui/screens_welfare.lua - 三国武灵录 (从 screens.lua 拆分)
-- ============================================================================
-- ui/screens.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 天命赐福界面 - 设计坐标 (三日广告签到 + 在线时长奖励)
-- ============================================================================

function DrawWelfareScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0

    -- 签到奖励配置 (前两天武技残片, 第三天兵符)
    local SIGN_SKILL_IDS = { 18, 19, nil }  -- 武技索引
    local SIGN_LABELS  = { "第一天", "第二天", "第三天" }
    -- 在线时长奖励配置: {所需秒数, 虎符数}
    local ONLINE_MILESTONES = {
        { time = 180,  jade = 300,  label = "3分钟"  },
        { time = 600,  jade = 500,  label = "10分钟" },
        { time = 1200, jade = 800,  label = "20分钟" },
        { time = 1800, jade = 1000, label = "30分钟" },
    }

    -- 1. 统一菜单背景
    DrawWelfareBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 2. 返回按钮
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    welfareState.backBtnRect = { x = backX, y = backY, w = backW, h = backH }

    -- 3. 标题
    nvgFontSize(vg, 39)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 32, "天命赐福")
    DrawHelpBtn(DESIGN_W - 14 - 30, backY + (backH - 30) / 2, 30)

    nvgFontSize(vg, 25)
    DrawWhiteInkText(cx, 56, "每日登录领取虎符奖励")



    -- 共用参数
    local secPad = 16
    local secW = W - secPad * 2

    -- ==========================================
    -- 贡献榜（固定在顶部，独立滚动区域）
    -- ==========================================
    local contribClipTop = 72
    local contribData = welfareState.contribRank
    local contribCount = contribData and #contribData or 0
    local contribRowH = 48  -- 加大行高
    -- 天命赐福内只显示前3，详情跳转到独立页面
    local contribDisplayCount = math.min(3, contribCount)
    local contribHasMore = contribCount > 0  -- 有数据就显示查看详情
    local contribBtnH = contribHasMore and 36 or 0  -- 查看详情按钮高度
    local contribContentH = 52 + math.max(1, contribDisplayCount) * contribRowH + contribBtnH + 20
    local contribMaxVisH = 360  -- 拉长可见区域
    local contribVisH = math.min(contribMaxVisH, contribContentH)
    welfareState.contribFixedH = contribVisH

    nvgSave(vg)
    nvgScissor(vg, 0, contribClipTop, W, contribVisH)

    do
        local csOff = welfareState.contribScroll.offset
        local cY = contribClipTop + csOff

        -- 底板
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cY, secW, contribContentH, 10)
        nvgFillColor(vg, nvgRGBA(18, 22, 38, 220)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cY, secW, contribContentH, 10)
        nvgStrokeColor(vg, nvgRGBA(255, 140, 60, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        nvgFontSize(vg, 31)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(secPad + 16, cY + 26, "贡献榜")
        -- 今日总贡献次数
        local totalContrib = 0
        if contribData then
            for _, e in ipairs(contribData) do totalContrib = totalContrib + (e.count or 0) end
        end
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 220))
        nvgText(vg, secPad + secW - 16, cY + 26, "今日总贡献 " .. totalContrib .. " 次", nil)

        -- 列表
        local listY = cY + 52
        if welfareState.contribLoading and not welfareState.contribLoaded then
            nvgFontSize(vg, 25)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, listY + 24, "加载中...")
        elseif contribCount == 0 then
            nvgFontSize(vg, 25)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, listY + 24, "暂无数据，快去看广告上榜吧！")
        else
            -- 奖牌图标
            local medals = {"[1]", "[2]", "[3]"}
            for i = 1, contribDisplayCount do
                local entry = contribData[i]
                local ry = listY + (i - 1) * contribRowH
                -- 交替行底色
                if i % 2 == 0 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 8, ry, secW - 16, contribRowH, 4)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 8)); nvgFill(vg)
                end
                -- 排名 (前3用奖牌)
                nvgFontSize(vg, 26)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if i <= 3 then
                    nvgFillColor(vg, nvgRGBA(255, 210, 60, 240))
                    nvgText(vg, secPad + 36, ry + contribRowH / 2, medals[i], nil)
                else
                    nvgFillColor(vg, nvgRGBA(180, 175, 160, 200))
                    nvgText(vg, secPad + 36, ry + contribRowH / 2, "#" .. i, nil)
                end
                -- 名字
                nvgFontSize(vg, 25)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(220, 215, 200, 230))
                nvgText(vg, secPad + 64, ry + contribRowH / 2, entry.name, nil)
                -- 次数
                nvgFontSize(vg, 25)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(130, 200, 255, 220))
                nvgText(vg, secPad + secW - 20, ry + contribRowH / 2, tostring(entry.count) .. " 次", nil)
            end
        end

        -- "查看详情" / "收起" 按钮
        if contribHasMore then
            local dtBtnW = 120
            local dtBtnH2 = 30
            local dtBtnX = cx - dtBtnW / 2
            local dtBtnY = listY + contribDisplayCount * contribRowH + 6
            nvgBeginPath(vg); nvgRoundedRect(vg, dtBtnX, dtBtnY, dtBtnW, dtBtnH2, 6)
            nvgFillColor(vg, nvgRGBA(60, 55, 80, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local dtLabel = "查看详情"
            DrawWhiteInkText(dtBtnX + dtBtnW / 2, dtBtnY + dtBtnH2 / 2, dtLabel)
            welfareState.contribDetailBtnRect = { x = dtBtnX, y = dtBtnY, w = dtBtnW, h = dtBtnH2 }
        else
            welfareState.contribDetailBtnRect = nil
        end
    end

    -- 贡献榜滚动范围限制
    local contribMinScroll = math.min(0, contribVisH - contribContentH)
    welfareState.contribScroll.offset = math.max(contribMinScroll, math.min(0, welfareState.contribScroll.offset))

    nvgRestore(vg)

    -- 分隔线
    local mainClipTop = contribClipTop + contribVisH + 2
    nvgBeginPath(vg)
    nvgMoveTo(vg, secPad, mainClipTop)
    nvgLineTo(vg, W - secPad, mainClipTop)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 60))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    mainClipTop = mainClipTop + 2

    -- ==========================================
    -- 下方内容滚动区域
    -- ==========================================
    local clipBottom = H - 4
    local mainClipH = clipBottom - mainClipTop
    local sOff = welfareState.scroll.offset

    nvgSave(vg)
    nvgScissor(vg, 0, mainClipTop, W, mainClipH)

    -- ==========================================
    -- 4. 三日广告签到区域
    -- ==========================================
    local secY = mainClipTop + 8 + sOff
    local secH = 260
    -- 区域底板
    nvgBeginPath(vg); nvgRoundedRect(vg, secPad, secY, secW, secH, 10)
    nvgFillColor(vg, nvgRGBA(18, 22, 38, 220)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, secPad, secY, secW, secH, 10)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 区域标题
    nvgFontSize(vg, 31)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(secPad + 16, secY + 24, "三日签到")

    nvgFontSize(vg, 23)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(secPad + secW - 16, secY + 24, "观看广告领取奖励")

    -- 签到卡片
    welfareState.signInBtnRects = {}
    local cardW3 = math.floor((secW - 64) / 3)
    local cardH3 = 170
    local cardStartX = secPad + 16
    local cardStartY = secY + 50

    for i = 1, 3 do
        local cx2 = cardStartX + (i - 1) * (cardW3 + 16)
        local cy2 = cardStartY
        local isClaimed = welfareState.signInClaimed[i]
        -- 判断是否可领取: 前面的天数都领了，当前天还没领，且距上次领取已过24小时
        local canClaim = not isClaimed
        if i > 1 then
            canClaim = canClaim and welfareState.signInClaimed[i - 1]
            -- 24小时间隔检查
            if canClaim then
                local prevTs = welfareState.signInTimestamps[i - 1] or 0
                if prevTs > 0 and (os.time() - prevTs) < 86400 then
                    canClaim = false
                end
            end
        end

        -- 卡片底板
        nvgBeginPath(vg); nvgRoundedRect(vg, cx2, cy2, cardW3, cardH3, 8)
        if isClaimed then
            nvgFillColor(vg, nvgRGBA(25, 40, 30, 220))
        elseif canClaim then
            local pulse = 0.85 + 0.15 * math.sin(t * 3 + i)
            nvgFillColor(vg, nvgRGBA(35, 30, 18, math.floor(230 * pulse)))
        else
            nvgFillColor(vg, nvgRGBA(20, 22, 30, 200))
        end
        nvgFill(vg)

        -- 边框
        nvgBeginPath(vg); nvgRoundedRect(vg, cx2, cy2, cardW3, cardH3, 8)
        if isClaimed then
            nvgStrokeColor(vg, nvgRGBA(80, 180, 100, 120))
        elseif canClaim then
            nvgStrokeColor(vg, nvgRGBA(255, 200, 60, 140))
        else
            nvgStrokeColor(vg, nvgRGBA(80, 75, 60, 80))
        end
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- 天数标题
        nvgFontSize(vg, 25)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 210, 180, isClaimed and 160 or 240))
        nvgText(vg, cx2 + cardW3 / 2, cy2 + 22, SIGN_LABELS[i], nil)

        -- 奖励图标和文字
        local alpha2 = isClaimed and 160 or 240
        if SIGN_SKILL_IDS[i] then
            -- 武技奖励: 显示武技图标+名字
            local sk = SKILL_TECHNIQUES[SIGN_SKILL_IDS[i]]
            if sk then
                local skTier = SKILL_TIERS[sk.tier]
                local stc = skTier.color
                -- 武技图标
                local iconSz = 44
                local iconX = cx2 + (cardW3 - iconSz) / 2
                local iconY = cy2 + 42
                nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSz, iconSz, 5)
                nvgFillColor(vg, nvgRGBA(15, 18, 30, 220)); nvgFill(vg)
                drawSkillIcon(sk.iconIdx, iconX + 3, iconY + 3, iconSz - 6, 3)
                nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSz, iconSz, 5)
                nvgStrokeColor(vg, nvgRGBA(stc[1], stc[2], stc[3], isClaimed and 100 or 180))
                nvgStrokeWidth(vg, 1); nvgStroke(vg)
                -- 武技名
                nvgFontSize(vg, 23)
                nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], alpha2))
                nvgText(vg, cx2 + cardW3 / 2, cy2 + 98, sk.name, nil)
                -- 残片数量
                nvgFontSize(vg, 21)
                nvgFillColor(vg, nvgRGBA(220, 210, 180, alpha2))
                nvgText(vg, cx2 + cardW3 / 2, cy2 + 118, "×49残片", nil)
            end
        else
            -- 第3天: 20000虎符
            nvgFontSize(vg, 23)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, alpha2))
            nvgText(vg, cx2 + cardW3 / 2, cy2 + 58, "虎符", nil)
            nvgFontSize(vg, 35)
            nvgFillColor(vg, nvgRGBA(255, 200, 60, alpha2))
            nvgText(vg, cx2 + cardW3 / 2, cy2 + 88, "×20000", nil)
        end

        -- 底部按钮/状态
        local btnW2 = cardW3 - 16
        local btnH2 = 30
        local btnX2 = cx2 + 8
        local btnY2 = cy2 + cardH3 - btnH2 - 10
        if isClaimed then
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 5)
            nvgFontSize(vg, 25)
            DrawWhiteInkText(btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "已领取 ✓")
        elseif canClaim then
            local pulse2 = 0.8 + 0.2 * math.sin(t * 4 + i * 0.7)
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 5)
            local btnGrad = nvgLinearGradient(vg, btnX2, btnY2, btnX2, btnY2 + btnH2,
                nvgRGBA(210, 170, 50, math.floor(220 * pulse2)),
                nvgRGBA(170, 120, 30, math.floor(220 * pulse2)))
            nvgFillPaint(vg, btnGrad); nvgFill(vg)
            nvgFontSize(vg, 25)
            nvgFillColor(vg, nvgRGBA(40, 20, 0, 240))
            nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "看广告领取", nil)
            welfareState.signInBtnRects[i] = { x = btnX2, y = btnY2, w = btnW2, h = btnH2 }
        else
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 5)
            nvgFillColor(vg, nvgRGBA(25, 28, 38, 180)); nvgFill(vg)
            nvgFontSize(vg, 25)
            DrawWhiteInkText(btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "未到时间")
        end
    end

    -- ==========================================
    -- 5. 十日签到（每日广告领5000虎符）
    -- ==========================================
    local dsecY = secY + secH + 16
    local dsecH = 230
    -- 区域底板
    nvgBeginPath(vg); nvgRoundedRect(vg, secPad, dsecY, secW, dsecH, 10)
    nvgFillColor(vg, nvgRGBA(18, 22, 38, 220)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, secPad, dsecY, secW, dsecH, 10)
    nvgStrokeColor(vg, nvgRGBA(255, 180, 60, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 区域标题
    nvgFontSize(vg, 31)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(secPad + 16, dsecY + 24, "十日签到")

    -- 已签到进度
    local dailyClaimed = 0
    for i = 1, 10 do
        if welfareState.dailySignInClaimed[i] then dailyClaimed = dailyClaimed + 1 end
    end
    nvgFontSize(vg, 23)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(secPad + secW - 16, dsecY + 24,
        "进度 " .. dailyClaimed .. "/10  |  每日广告×5000虎符")

    -- 10天网格: 5列×2行
    welfareState.dailySignInBtnRects = {}
    local dCols = 5
    local dGap = 8
    local dCardW = math.floor((secW - 32 - (dCols - 1) * dGap) / dCols)
    local dCardH = 78
    local dStartX = secPad + 16
    local dStartY = dsecY + 48

    for i = 1, 10 do
        local col = ((i - 1) % dCols)
        local row = math.floor((i - 1) / dCols)
        local dx = dStartX + col * (dCardW + dGap)
        local dy = dStartY + row * (dCardH + dGap)

        local isClaimed = welfareState.dailySignInClaimed[i]
        -- 可领取条件: 前一天已领 且 当天未领 且 距前一天领取已过24小时
        local canClaim = not isClaimed
        if i > 1 then
            canClaim = canClaim and welfareState.dailySignInClaimed[i - 1]
            -- 24小时间隔检查
            if canClaim then
                local prevTs = welfareState.dailySignInTimestamps[i - 1] or 0
                if prevTs > 0 and (os.time() - prevTs) < 86400 then
                    canClaim = false
                end
            end
        end

        -- 卡片背景
        nvgBeginPath(vg); nvgRoundedRect(vg, dx, dy, dCardW, dCardH, 6)
        if isClaimed then
            nvgFillColor(vg, nvgRGBA(25, 40, 30, 220))
        elseif canClaim then
            local pulse = 0.85 + 0.15 * math.sin(t * 3 + i)
            nvgFillColor(vg, nvgRGBA(40, 32, 15, math.floor(230 * pulse)))
        else
            nvgFillColor(vg, nvgRGBA(20, 22, 30, 180))
        end
        nvgFill(vg)

        -- 边框
        nvgBeginPath(vg); nvgRoundedRect(vg, dx, dy, dCardW, dCardH, 6)
        if isClaimed then
            nvgStrokeColor(vg, nvgRGBA(80, 180, 100, 100))
        elseif canClaim then
            nvgStrokeColor(vg, nvgRGBA(255, 200, 60, 140))
        else
            nvgStrokeColor(vg, nvgRGBA(70, 65, 55, 70))
        end
        nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

        -- 天数
        nvgFontSize(vg, 17)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 190, 160, isClaimed and 150 or 230))
        nvgText(vg, dx + dCardW / 2, dy + 14, "第" .. i .. "天", nil)

        -- 奖励
        if isClaimed then
            nvgFontSize(vg, 25)
            DrawWhiteInkText(dx + dCardW / 2, dy + 36, "✓")
            nvgFontSize(vg, 15)
            DrawWhiteInkText(dx + dCardW / 2, dy + 54, "已领取")
        elseif canClaim then
            -- 虎符数量
            nvgFontSize(vg, 21)
            DrawWhiteInkText(dx + dCardW / 2, dy + 34, "+5000")
            -- 领取按钮
            local btnW3 = dCardW - 8
            local btnH3 = 18
            local btnX3 = dx + 4
            local btnY3 = dy + dCardH - btnH3 - 5
            local pulse2 = 0.8 + 0.2 * math.sin(t * 4 + i * 0.5)
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX3, btnY3, btnW3, btnH3, 4)
            nvgFillColor(vg, nvgRGBA(210, 160, 40, math.floor(220 * pulse2))); nvgFill(vg)
            nvgFontSize(vg, 15)
            nvgFillColor(vg, nvgRGBA(40, 20, 0, 240))
            nvgText(vg, btnX3 + btnW3 / 2, btnY3 + btnH3 / 2, "领取", nil)
            welfareState.dailySignInBtnRects[i] = { x = btnX3, y = btnY3, w = btnW3, h = btnH3 }
        else
            -- 锁定状态
            nvgFontSize(vg, 19)
            DrawWhiteInkText(dx + dCardW / 2, dy + 34, "5000")
            nvgFontSize(vg, 14)
            DrawWhiteInkText(dx + dCardW / 2, dy + 54, "未解锁")
        end
    end

    -- ==========================================
    -- 6. 今日在线时长奖励区域
    -- ==========================================
    local sec2Y = dsecY + dsecH + 16
    local sec2H = 530
    -- 区域底板
    nvgBeginPath(vg); nvgRoundedRect(vg, secPad, sec2Y, secW, sec2H, 10)
    nvgFillColor(vg, nvgRGBA(18, 22, 38, 220)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, secPad, sec2Y, secW, sec2H, 10)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 255, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 区域标题
    nvgFontSize(vg, 31)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(secPad + 16, sec2Y + 24, "在线时长奖励")

    -- 累计在线时间显示
    local totalMin = math.floor(welfareState.onlineTime / 60)
    local totalSec = math.floor(welfareState.onlineTime % 60)
    nvgFontSize(vg, 23)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(secPad + secW - 16, sec2Y + 24,
        string.format("已在线 %d分%02d秒", totalMin, totalSec))

    -- 进度条
    local barX = secPad + 20
    local barY = sec2Y + 50
    local barW = secW - 40
    local barH = 8
    local maxTime = ONLINE_MILESTONES[#ONLINE_MILESTONES].time
    local progress = math.min(1.0, welfareState.onlineTime / maxTime)

    -- 进度条底
    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 4)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 200)); nvgFill(vg)

    -- 进度条填充
    if progress > 0 then
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW * progress, barH, 4)
        local barGrad = nvgLinearGradient(vg, barX, barY, barX + barW * progress, barY,
            nvgRGBA(80, 160, 255, 200), nvgRGBA(130, 200, 255, 220))
        nvgFillPaint(vg, barGrad); nvgFill(vg)
    end

    -- 里程碑节点
    for i, ms in ipairs(ONLINE_MILESTONES) do
        local nodeX = barX + barW * (ms.time / maxTime)
        local reached = welfareState.onlineTime >= ms.time
        local claimed = welfareState.onlineRewards[i]
        nvgBeginPath(vg); nvgCircle(vg, nodeX, barY + barH / 2, 6)
        if claimed then
            nvgFillColor(vg, nvgRGBA(80, 200, 120, 240))
        elseif reached then
            nvgFillColor(vg, nvgRGBA(255, 210, 60, 240))
        else
            nvgFillColor(vg, nvgRGBA(50, 55, 70, 220))
        end
        nvgFill(vg)
        nvgBeginPath(vg); nvgCircle(vg, nodeX, barY + barH / 2, 6)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, reached and 100 or 40))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end

    -- 奖励卡片
    welfareState.onlineBtnRects = {}
    local olCardH = 100
    local olCardGap = 12
    local olStartY = barY + barH + 20
    local olCardW = secW - 32

    for i, ms in ipairs(ONLINE_MILESTONES) do
        local oy = olStartY + (i - 1) * (olCardH + olCardGap)
        local reached = welfareState.onlineTime >= ms.time
        local claimed = welfareState.onlineRewards[i]

        -- 卡片底板
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 16, oy, olCardW, olCardH, 8)
        if claimed then
            nvgFillColor(vg, nvgRGBA(22, 35, 28, 200))
        elseif reached then
            nvgFillColor(vg, nvgRGBA(30, 28, 18, 210))
        else
            nvgFillColor(vg, nvgRGBA(20, 22, 32, 180))
        end
        nvgFill(vg)

        nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 16, oy, olCardW, olCardH, 8)
        if claimed then
            nvgStrokeColor(vg, nvgRGBA(80, 180, 100, 80))
        elseif reached then
            nvgStrokeColor(vg, nvgRGBA(255, 200, 60, 100))
        else
            nvgStrokeColor(vg, nvgRGBA(60, 65, 80, 60))
        end
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 左侧: 时长图标 + 标签
        local iconCX = secPad + 50
        local iconCY = oy + olCardH / 2
        -- 时钟图标（圆圈+指针）
        nvgBeginPath(vg); nvgCircle(vg, iconCX, iconCY, 18)
        nvgFillColor(vg, nvgRGBA(25, 30, 45, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(130, 200, 255, reached and 200 or 100))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        -- 时钟指针
        nvgBeginPath(vg)
        nvgMoveTo(vg, iconCX, iconCY)
        nvgLineTo(vg, iconCX, iconCY - 10)
        nvgMoveTo(vg, iconCX, iconCY)
        nvgLineTo(vg, iconCX + 8, iconCY + 2)
        nvgStrokeColor(vg, nvgRGBA(130, 200, 255, reached and 220 or 120))
        nvgStrokeWidth(vg, 2); nvgStroke(vg)

        -- 时长文字
        local textLX = secPad + 78
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 29)
        nvgFillColor(vg, nvgRGBA(220, 215, 200, reached and 240 or 180))
        nvgText(vg, textLX, oy + 30, "在线 " .. ms.label, nil)

        nvgFontSize(vg, 25)
        nvgFillColor(vg, nvgRGBA(255, 210, 80, reached and 230 or 160))
        nvgText(vg, textLX, oy + 58, "+" .. ms.jade .. " 虎符", nil)

        -- 进度百分比
        if not reached then
            local pct = math.min(100, math.floor(welfareState.onlineTime / ms.time * 100))
            nvgFontSize(vg, 21)
            DrawWhiteInkText(textLX, oy + 80, pct .. "%")
        end

        -- 右侧: 领取按钮
        local btnW2 = 90
        local btnH2 = 36
        local btnX2 = secPad + 16 + olCardW - btnW2 - 12
        local btnY2 = oy + (olCardH - btnH2) / 2
        if claimed then
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 6)
            nvgFillColor(vg, nvgRGBA(30, 55, 35, 200)); nvgFill(vg)
            nvgFontSize(vg, 25)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "已领取 ✓")
        elseif reached then
            local pulse3 = 0.8 + 0.2 * math.sin(t * 4 + i * 0.9)
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 6)
            local btnGrad2 = nvgLinearGradient(vg, btnX2, btnY2, btnX2, btnY2 + btnH2,
                nvgRGBA(80, 160, 255, math.floor(220 * pulse3)),
                nvgRGBA(50, 120, 210, math.floor(220 * pulse3)))
            nvgFillPaint(vg, btnGrad2); nvgFill(vg)
            nvgFontSize(vg, 25)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "领取")
            welfareState.onlineBtnRects[i] = { x = btnX2, y = btnY2, w = btnW2, h = btnH2 }
        else
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 6)
            nvgFillColor(vg, nvgRGBA(25, 28, 38, 180)); nvgFill(vg)
            nvgFontSize(vg, 25)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "未达成")
        end
    end

    -- ==========================================
    -- (大转盘和每日翻牌已移除)
    -- ==========================================

    -- ==========================================
    -- 下方内容滚动范围限制
    local lastSecBottom = sec2Y + sec2H
    local totalContentH = (lastSecBottom - sOff - mainClipTop) + 20
    local maxScroll = 0
    local minScroll = math.min(0, mainClipH - totalContentH)
    welfareState.scroll.offset = math.max(minScroll, math.min(maxScroll, welfareState.scroll.offset))

    nvgRestore(vg)  -- 恢复裁剪

    -- 装饰粒子
    for i = 1, 4 do
        local px = W * (0.1 + 0.8 * ((i * 173 + math.floor(t * 12)) % 100) / 100)
        local py = H * (0.03 + 0.05 * math.sin(t * 0.4 + i * 1.7))
        local pr = 1.0 + math.sin(t * 1.8 + i) * 0.5
        local pa = math.floor(20 + 15 * math.sin(t * 1.2 + i * 0.8))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, pa)); nvgFill(vg)
    end
end


-- ============================================================================
-- 每日任务 & 成就界面 - 设计坐标
-- ============================================================================
function DrawDailyTasksAndAchievements()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0

    -- 1. 统一菜单背景
    DrawWelfareBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- 2. 返回按钮
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    progressUIState.backBtnRect = { x = backX, y = backY, w = backW, h = backH }

    -- 3. 标题
    nvgFontSize(vg, 39)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 32, "修行日录")

    -- 4. Tab 切换按钮
    local tabNames = { "每日任务", "周任务", "成就" }
    local tabW = 110
    local tabH = 38
    local tabGap = 10
    local tabStartX = cx - (#tabNames * tabW + (#tabNames - 1) * tabGap) / 2
    local tabY = 56
    progressTabRects = {}
    for i, name in ipairs(tabNames) do
        local tx = tabStartX + (i - 1) * (tabW + tabGap)
        local isActive = (progressUIState.tab == i)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 6)
        if isActive then
            nvgFillColor(vg, nvgRGBA(90, 45, 55, 240)); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(30, 35, 50, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end
        nvgFontSize(vg, 25)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(255, 240, 200, 255) or nvgRGBA(180, 170, 140, 200))
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, name, nil)
        progressTabRects[i] = { x = tx, y = tabY, w = tabW, h = tabH }
    end

    -- 4.5 Tab 红点穿透
    local tabRedDots = { HasDailyTaskRedDot(), HasWeeklyTaskRedDot(), HasAchievementRedDot() }
    for i, hasRd in ipairs(tabRedDots) do
        if hasRd and progressTabRects[i] then
            local tr = progressTabRects[i]
            DrawRedDot(tr.x + tr.w - 6, tr.y + 6, 5)
        end
    end

    -- 5. 滚动区域
    local clipTop = tabY + tabH + 8
    local clipBottom = H - 4
    local clipH = clipBottom - clipTop
    local sOff = progressUIState.scrollY

    nvgSave(vg)
    nvgScissor(vg, 0, clipTop, W, clipH)

    if progressUIState.tab == 1 then
        -- =====================
        -- Tab 1: 每日任务
        -- =====================
        local secPad = 14
        local secW = W - secPad * 2
        local cardH = 56
        local cardGap = 6
        local startY = clipTop + 10 + sOff

        dailyTaskBtnRects = {}

        -- 任务完成计数
        local claimedCount = 0
        local allDone = true
        for _, task in ipairs(DAILY_TASKS) do
            if dailyTaskState.claimed[task.id] then
                claimedCount = claimedCount + 1
            else
                allDone = false
            end
        end

        -- 顶部进度提示
        nvgFontSize(vg, 21)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, startY, "今日进度: " .. claimedCount .. " / " .. #DAILY_TASKS)
        startY = startY + 28

        for i, task in ipairs(DAILY_TASKS) do
            local cy = startY + (i - 1) * (cardH + cardGap)
            local prog = dailyTaskState.progress[task.id] or 0
            local done = prog >= task.target
            local claimed = dailyTaskState.claimed[task.id] or false

            -- 卡片背景
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cy, secW, cardH, 7)
            if claimed then
                nvgFillColor(vg, nvgRGBA(20, 30, 20, 160))
            else
                nvgFillColor(vg, nvgRGBA(18, 22, 38, 220))
            end
            nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cy, secW, cardH, 7)
            nvgStrokeColor(vg, claimed and nvgRGBA(80, 120, 80, 80) or nvgRGBA(90, 45, 55, 70))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 左侧状态指示条
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 1, cy + 6, 3, cardH - 12, 1.5)
            if claimed then
                nvgFillColor(vg, nvgRGBA(80, 160, 80, 180))
            elseif done then
                nvgFillColor(vg, nvgRGBA(220, 180, 60, 220))
            else nvgFillColor(vg, nvgRGBA(120, 80, 90, 140)) end
            nvgFill(vg)

            -- Row 1: 任务名 + 进度
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, claimed and nvgRGBA(120, 160, 120, 180) or nvgRGBA(255, 220, 140, 240))
            nvgText(vg, secPad + 16, cy + 17, task.name, nil)

            nvgFontSize(vg, 16)
            nvgFillColor(vg, done and nvgRGBA(80, 200, 80, 220) or nvgRGBA(180, 170, 140, 170))
            nvgText(vg, secPad + 128, cy + 17, prog .. "/" .. task.target, nil)

            -- Row 2: 描述 + 奖励标签
            nvgFontSize(vg, 16)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(150, 145, 125, 170))
            nvgText(vg, secPad + 16, cy + 39, task.desc, nil)

            local rwX = secPad + secW * 0.52
            nvgFontSize(vg, 15)
            nvgFillColor(vg, nvgRGBA(200, 190, 130, 190))
            local rwStr = ""
            if task.reward.jade then rwStr = rwStr .. "石+" .. task.reward.jade .. " " end
            if task.reward.frag then rwStr = rwStr .. "残片+" .. task.reward.frag .. " " end
            if task.reward.ticket then rwStr = rwStr .. "票+" .. task.reward.ticket end
            nvgText(vg, rwX, cy + 39, rwStr, nil)

            -- 领取按钮
            local btnW2 = 58
            local btnH2 = 26
            local btnX = secPad + secW - btnW2 - 8
            local btnY2 = cy + cardH / 2 - btnH2 / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY2, btnW2, btnH2, 5)
            if claimed then
                nvgFillColor(vg, nvgRGBA(50, 60, 50, 140)); nvgFill(vg)
                nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "已领取")
            elseif done then
                nvgFillColor(vg, nvgRGBA(180, 140, 40, 230)); nvgFill(vg)
                nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "领取")
            else
                nvgFillColor(vg, nvgRGBA(40, 45, 55, 180)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 75, 65, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "未完成")
            end
            dailyTaskBtnRects[i] = { x = btnX, y = btnY2, w = btnW2, h = btnH2 }
        end

        -- 全勤奖励卡片
        local allY = startY + #DAILY_TASKS * (cardH + cardGap) + 8
        local allH = 48
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, allY, secW, allH, 8)
        if dailyTaskState.allClaimedBonus then
            nvgFillColor(vg, nvgRGBA(20, 30, 20, 180))
        else
            local glow = math.floor(30 + 20 * math.sin(t * 2.5))
            nvgFillColor(vg, nvgRGBA(30 + glow, 25, 15, 220))
        end
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, allY, secW, allH, 8)
        nvgStrokeColor(vg, nvgRGBA(220, 180, 60, allDone and 180 or 60)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        nvgFontSize(vg, 25)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(secPad + 14, allY + allH / 2, "全勤奖励")

        nvgFontSize(vg, 19)
        DrawWhiteInkText(secPad + 120, allY + allH / 2, "虎符+50")

        local abtnW = 64
        local abtnH = 30
        local abtnX = secPad + secW - abtnW - 10
        local abtnY = allY + allH / 2 - abtnH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, abtnX, abtnY, abtnW, abtnH, 5)
        if dailyTaskState.allClaimedBonus then
            nvgFillColor(vg, nvgRGBA(50, 60, 50, 150)); nvgFill(vg)
            nvgFontSize(vg, 19)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(abtnX + abtnW / 2, abtnY + abtnH / 2, "已领取")
        elseif allDone then
            nvgFillColor(vg, nvgRGBA(220, 170, 30, 240)); nvgFill(vg)
            nvgFontSize(vg, 19)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(abtnX + abtnW / 2, abtnY + abtnH / 2, "领取")
        else
            nvgFillColor(vg, nvgRGBA(40, 45, 55, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 75, 65, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 19)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(abtnX + abtnW / 2, abtnY + abtnH / 2, claimedCount .. "/" .. #DAILY_TASKS)
        end
        dailyTaskAllBtnRect = { x = abtnX, y = abtnY, w = abtnW, h = abtnH }

        -- 计算滚动内容高度
        local totalH = 28 + #DAILY_TASKS * (cardH + cardGap) + 20 + abtnH + 20
        progressUIState.contentHeight = math.max(0, totalH - clipH)

    elseif progressUIState.tab == 2 then
        -- =====================
        -- Tab 2: 周任务
        -- =====================
        local secPad = 14
        local secW = W - secPad * 2
        local cardH = 56
        local cardGap = 6
        local startY = clipTop + 10 + sOff

        weeklyTaskBtnRects = {}

        -- 周任务完成计数
        CheckWeeklyReset()
        local claimedCount = 0
        local allDone = true
        for _, task in ipairs(WEEKLY_TASKS) do
            if weeklyTaskState.claimed[task.id] then
                claimedCount = claimedCount + 1
            else
                allDone = false
            end
        end

        -- 顶部进度提示
        nvgFontSize(vg, 21)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, startY, "本周进度: " .. claimedCount .. " / " .. #WEEKLY_TASKS)
        startY = startY + 28

        for i, task in ipairs(WEEKLY_TASKS) do
            local cy = startY + (i - 1) * (cardH + cardGap)
            local prog = weeklyTaskState.progress[task.id] or 0
            local done = prog >= task.target
            local claimed = weeklyTaskState.claimed[task.id] or false

            -- 卡片背景
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cy, secW, cardH, 7)
            if claimed then
                nvgFillColor(vg, nvgRGBA(20, 25, 35, 160))
            else
                nvgFillColor(vg, nvgRGBA(14, 20, 38, 220))
            end
            nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cy, secW, cardH, 7)
            nvgStrokeColor(vg, claimed and nvgRGBA(80, 100, 140, 80) or nvgRGBA(90, 120, 180, 70))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 左侧状态指示条
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 1, cy + 6, 3, cardH - 12, 1.5)
            if claimed then
                nvgFillColor(vg, nvgRGBA(80, 160, 80, 180))
            elseif done then
                nvgFillColor(vg, nvgRGBA(220, 180, 60, 220))
            else nvgFillColor(vg, nvgRGBA(80, 120, 180, 140)) end
            nvgFill(vg)

            -- Row 1: 任务名 + 进度
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, claimed and nvgRGBA(100, 140, 180, 180) or nvgRGBA(160, 200, 255, 240))
            nvgText(vg, secPad + 16, cy + 17, task.name, nil)

            nvgFontSize(vg, 16)
            nvgFillColor(vg, done and nvgRGBA(80, 180, 220, 220) or nvgRGBA(140, 160, 180, 170))
            nvgText(vg, secPad + 128, cy + 17, prog .. "/" .. task.target, nil)

            -- Row 2: 描述 + 奖励标签
            nvgFontSize(vg, 16)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(140, 145, 155, 170))
            nvgText(vg, secPad + 16, cy + 39, task.desc, nil)

            local rwX = secPad + secW * 0.52
            nvgFontSize(vg, 15)
            nvgFillColor(vg, nvgRGBA(180, 200, 230, 190))
            local rwStr = ""
            if task.reward.jade then rwStr = rwStr .. "石+" .. task.reward.jade .. " " end
            if task.reward.frag then rwStr = rwStr .. "残片+" .. task.reward.frag .. " " end
            if task.reward.ticket then rwStr = rwStr .. "票+" .. task.reward.ticket end
            nvgText(vg, rwX, cy + 39, rwStr, nil)

            -- 领取按钮
            local btnW2 = 58
            local btnH2 = 26
            local btnX = secPad + secW - btnW2 - 8
            local btnY2 = cy + cardH / 2 - btnH2 / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY2, btnW2, btnH2, 5)
            if claimed then
                nvgFillColor(vg, nvgRGBA(40, 50, 60, 140)); nvgFill(vg)
                nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "已领取")
            elseif done then
                nvgFillColor(vg, nvgRGBA(60, 140, 200, 230)); nvgFill(vg)
                nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "领取")
            else
                nvgFillColor(vg, nvgRGBA(35, 40, 55, 180)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(70, 80, 100, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "未达成")
            end
            weeklyTaskBtnRects[i] = { x = btnX, y = btnY2, w = btnW2, h = btnH2 }
        end

        -- 周全勤奖励
        local lastCardBottom = startY + #WEEKLY_TASKS * (cardH + cardGap)
        local abtnW = secW - 20
        local abtnH = 40
        local abtnX = secPad + 10
        local abtnY = lastCardBottom + 8
        nvgBeginPath(vg); nvgRoundedRect(vg, abtnX, abtnY, abtnW, abtnH, 8)
        if weeklyTaskState.allClaimedBonus then
            nvgFillColor(vg, nvgRGBA(30, 40, 50, 180)); nvgFill(vg)
            nvgFontSize(vg, 21)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(abtnX + abtnW / 2, abtnY + abtnH / 2, "周全勤奖励已领取")
        elseif allDone then
            local glow = 0.7 + 0.3 * math.sin(t * 3)
            nvgFillColor(vg, nvgRGBA(math.floor(60 * glow), math.floor(150 * glow), math.floor(220 * glow), 230)); nvgFill(vg)
            nvgFontSize(vg, 21)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(abtnX + abtnW / 2, abtnY + abtnH / 2, "领取周全勤 +1300虎符")
        else
            nvgFillColor(vg, nvgRGBA(35, 40, 55, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(70, 80, 100, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 19)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(abtnX + abtnW / 2, abtnY + abtnH / 2, claimedCount .. "/" .. #WEEKLY_TASKS)
        end
        weeklyTaskAllBtnRect = { x = abtnX, y = abtnY, w = abtnW, h = abtnH }

        -- 计算滚动内容高度
        local totalH = 28 + #WEEKLY_TASKS * (cardH + cardGap) + 12 + abtnH + 20
        progressUIState.contentHeight = math.max(0, totalH - clipH)

    elseif progressUIState.tab == 3 then
        -- =====================
        -- Tab 3: 成就图鉴
        -- =====================
        local secPad = 14
        local secW = W - secPad * 2
        local cardH = 80
        local cardGap = 8
        local startY = clipTop + 10 + sOff

        progressUIState.achBtnRects = {}
        progressUIState.achOrigIdx = {}  -- 排序后的原始索引映射

        -- 成就总计
        local achDoneCount = 0
        for _, ach in ipairs(ACHIEVEMENTS) do
            if achievementClaimed[ach.id] then achDoneCount = achDoneCount + 1 end
        end
        nvgFontSize(vg, 21)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, startY, "已解锁: " .. achDoneCount .. " / " .. #ACHIEVEMENTS)
        startY = startY + 28

        -- 排序：可领取 > 进行中 > 已领取（同组内保持原顺序）
        local sortedAch = {}
        for origIdx, ach in ipairs(ACHIEVEMENTS) do
            local sv = GetAchievementStatValue(ach.stat)
            local d = sv >= ach.target
            local c = achievementClaimed[ach.id] or false
            local order = c and 3 or (d and 1 or 2)  -- 1=可领取, 2=进行中, 3=已领取
            sortedAch[#sortedAch + 1] = { ach = ach, origIdx = origIdx, order = order }
        end
        table.sort(sortedAch, function(a, b)
            if a.order ~= b.order then return a.order < b.order end
            return a.origIdx < b.origIdx
        end)

        for si = 1, #sortedAch do
            local ach = sortedAch[si].ach
            local origIdx = sortedAch[si].origIdx
            progressUIState.achOrigIdx[si] = origIdx
            local cy = startY + (si - 1) * (cardH + cardGap)
            local statVal = GetAchievementStatValue(ach.stat)
            local done = statVal >= ach.target
            local claimed = achievementClaimed[ach.id] or false

            -- 卡片背景
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cy, secW, cardH, 8)
            if claimed then
                nvgFillColor(vg, nvgRGBA(20, 30, 20, 180))
            elseif done then
                local glow = math.floor(15 + 10 * math.sin(t * 2.0 + si))
                nvgFillColor(vg, nvgRGBA(28 + glow, 25, 12, 220))
            else
                nvgFillColor(vg, nvgRGBA(18, 22, 38, 220))
            end
            nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cy, secW, cardH, 8)
            nvgStrokeColor(vg, claimed and nvgRGBA(80, 120, 80, 100) or (done and nvgRGBA(220, 180, 60, 120) or nvgRGBA(80, 75, 100, 80)))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 成就名称
            nvgFontSize(vg, 25)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, claimed and nvgRGBA(120, 160, 120, 180) or nvgRGBA(255, 220, 140, 240))
            nvgText(vg, secPad + 14, cy + 22, ach.name, nil)

            -- 成就描述
            nvgFontSize(vg, 19)
            DrawWhiteInkText(secPad + 14, cy + 46, ach.desc)

            -- 进度
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(secPad + 14, cy + 66, "进度: " .. math.min(statVal, ach.target) .. "/" .. ach.target)

            -- 进度条
            local barX = secPad + secW * 0.38
            local barW = secW * 0.22
            local barH2 = 8
            local barY = cy + 62
            local ratio = math.min(1, statVal / ach.target)
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH2, 3)
            nvgFillColor(vg, nvgRGBA(40, 40, 50, 180)); nvgFill(vg)
            if ratio > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW * ratio, barH2, 3)
                nvgFillColor(vg, done and nvgRGBA(80, 200, 80, 220) or nvgRGBA(120, 100, 60, 200))
                nvgFill(vg)
            end

            -- 奖励
            local rwX = secPad + secW * 0.64
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 190, 130, 200))
            local rwStr = ""
            if ach.reward.jade then rwStr = rwStr .. "虎符+" .. ach.reward.jade .. " " end
            if ach.reward.ticket then rwStr = rwStr .. "虎符+" .. (ach.reward.ticket * 10) end
            nvgText(vg, rwX, cy + 22, rwStr, nil)

            -- 领取按钮
            local btnW2 = 64
            local btnH2 = 30
            local btnX = secPad + secW - btnW2 - 10
            local btnY2 = cy + cardH / 2 - btnH2 / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY2, btnW2, btnH2, 5)
            if claimed then
                nvgFillColor(vg, nvgRGBA(50, 60, 50, 150)); nvgFill(vg)
                nvgFontSize(vg, 19)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "已领取")
            elseif done then
                nvgFillColor(vg, nvgRGBA(180, 140, 40, 230)); nvgFill(vg)
                nvgFontSize(vg, 19)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "领取")
            else
                nvgFillColor(vg, nvgRGBA(40, 45, 55, 180)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 75, 65, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 19)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW2 / 2, btnY2 + btnH2 / 2, "未达成")
            end
            progressUIState.achBtnRects[si] = { x = btnX, y = btnY2, w = btnW2, h = btnH2 }
        end

        -- 计算滚动内容高度
        local totalH = 28 + #ACHIEVEMENTS * (cardH + cardGap) + 20
        progressUIState.contentHeight = math.max(0, totalH - clipH)
    end

    nvgRestore(vg)

    -- 顶部粒子装饰
    for i = 1, 8 do
        local px = W * (0.05 + 0.12 * i) + math.sin(t * 0.5 + i * 1.3) * 10
        local py = H * (0.02 + 0.04 * math.sin(t * 0.4 + i * 1.7))
        local pr = 1.0 + math.sin(t * 1.8 + i) * 0.5
        local pa = math.floor(18 + 12 * math.sin(t * 1.2 + i * 0.8))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, pa)); nvgFill(vg)
    end
end


