-- ui/screens_battlepass.lua - 三国武灵录 (从 screens.lua 拆分)
function DrawBattlePassScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0
    local bpCfg = GameConfig.BATTLE_PASS

    -- 1. 背景 (深紫+金色国风主题)
    DrawWelfareBg(W, H)
    -- 战令主题覆盖层: 从暗紫到深褐渐变
    local bgGrad = nvgLinearGradient(vg, 0, 0, 0, H,
        nvgRGBA(25, 15, 35, 140), nvgRGBA(35, 20, 10, 120))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillPaint(vg, bgGrad); nvgFill(vg)
    -- 顶部金色光晕装饰
    local glowAlpha = math.floor(40 + 20 * math.sin(t * 1.5))
    local topGlow = nvgRadialGradient(vg, cx, 0, 10, W * 0.6,
        nvgRGBA(255, 200, 80, glowAlpha), nvgRGBA(255, 200, 80, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, 120)
    nvgFillPaint(vg, topGlow); nvgFill(vg)

    -- 战令横幅背景装饰 (保持原图比例, 居中裁切顶部区域)
    if IsImageReady(IMG.bpBanner) then
        local bannerH = 52
        -- 原图 512x382, 按宽度匹配: 显示高度 = W * (382/512) ≈ 426
        -- 只显示顶部 bannerH 高的区域
        local imgDispH = W * (382 / 512)
        local bannerPat = nvgImagePattern(vg, 0, 0, W, imgDispH, 0, IMG.bpBanner, 0.25)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, bannerH)
        nvgFillPaint(vg, bannerPat); nvgFill(vg)
    end

    -- 面板双层金色外框
    local fm = 3 -- frame margin
    nvgBeginPath(vg); nvgRoundedRect(vg, fm, fm, W - fm * 2, H - fm * 2, 8)
    nvgStrokeColor(vg, nvgRGBA(180, 130, 50, 100)); nvgStrokeWidth(vg, 2.0); nvgStroke(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, fm + 3, fm + 3, W - fm * 2 - 6, H - fm * 2 - 6, 6)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 60)); nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
    -- 四边内阴影
    local isGradT = nvgLinearGradient(vg, 0, 0, 0, 18, nvgRGBA(0, 0, 0, 80), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, 18); nvgFillPaint(vg, isGradT); nvgFill(vg)
    local isGradB = nvgLinearGradient(vg, 0, H - 14, 0, H, nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 80))
    nvgBeginPath(vg); nvgRect(vg, 0, H - 14, W, 14); nvgFillPaint(vg, isGradB); nvgFill(vg)
    local isGradL = nvgLinearGradient(vg, 0, 0, 12, 0, nvgRGBA(0, 0, 0, 60), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, 12, H); nvgFillPaint(vg, isGradL); nvgFill(vg)
    local isGradR = nvgLinearGradient(vg, W - 12, 0, W, 0, nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 60))
    nvgBeginPath(vg); nvgRect(vg, W - 12, 0, 12, H); nvgFillPaint(vg, isGradR); nvgFill(vg)

    -- 四角云纹角饰
    if IsImageReady(IMG.bpFrameCorner) then
        local cs = 32 -- corner size
        -- 左上角 (原始方向)
        local cPat1 = nvgImagePattern(vg, 0, 0, cs, cs, 0, IMG.bpFrameCorner, 0.7)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, cs, cs); nvgFillPaint(vg, cPat1); nvgFill(vg)
        -- 右上角 (水平翻转: 通过反向UV)
        nvgSave(vg); nvgTranslate(vg, W, 0); nvgScale(vg, -1, 1)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, cs, cs); nvgFillPaint(vg, cPat1); nvgFill(vg)
        nvgRestore(vg)
        -- 左下角 (垂直翻转)
        nvgSave(vg); nvgTranslate(vg, 0, H); nvgScale(vg, 1, -1)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, cs, cs); nvgFillPaint(vg, cPat1); nvgFill(vg)
        nvgRestore(vg)
        -- 右下角 (双翻转)
        nvgSave(vg); nvgTranslate(vg, W, H); nvgScale(vg, -1, -1)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, cs, cs); nvgFillPaint(vg, cPat1); nvgFill(vg)
        nvgRestore(vg)
    end

    nvgFontFaceId(vg, GetMainFont())

    -- 2. 顶部栏: 返回 + 标题 + 赛季天数
    local topBarH = 56
    -- 返回按钮 (国风圆角)
    local backW, backH = 80, 36
    local backX, backY = 12, 10
    local backGrad = nvgLinearGradient(vg, backX, backY, backX, backY + backH,
        nvgRGBA(50, 30, 20, 230), nvgRGBA(30, 18, 12, 240))
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillPaint(vg, backGrad); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 150, 60, 140)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    battlePassBackRect = { x = backX, y = backY, w = backW, h = backH }

    -- 标题 (金色描边效果)
    nvgFontSize(vg, 34)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 描边层
    nvgFillColor(vg, nvgRGBA(120, 70, 20, 180))
    _nvgTextOrig(vg, cx + 1, 29, "战令通行证", nil)
    -- 金色主体
    nvgFillColor(vg, nvgRGBA(255, 215, 100, 255))
    _nvgTextOrig(vg, cx, 28, "战令通行证", nil)

    -- 标题下方国风分割线 (保持原图比例, 原图512x286)
    if IsImageReady(IMG.bpDivider) then
        local divW = 160
        local divH = divW * (286 / 512)  -- ≈89, 保持原图比例
        local divDispH = 16  -- 只显示居中一条窄带
        local divY = 44 - divDispH / 2
        -- 让图片居中, 只裁切中间水平带
        local patY = divY - (divH - divDispH) / 2
        local divPat = nvgImagePattern(vg, cx - divW / 2, patY, divW, divH, 0, IMG.bpDivider, 0.5)
        nvgBeginPath(vg); nvgRect(vg, cx - divW / 2, divY, divW, divDispH)
        nvgFillPaint(vg, divPat); nvgFill(vg)
    end

    -- 赛季剩余天数 (右上角)
    local remainDays = GetBattlePassRemainingDays()
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 180, 140, 200))
    nvgText(vg, W - 14, 20, "赛季剩余", nil)
    nvgFontSize(vg, 22)
    nvgFillColor(vg, remainDays <= 7 and nvgRGBA(255, 100, 80, 255) or nvgRGBA(255, 220, 120, 255))
    nvgText(vg, W - 14, 38, remainDays .. " 天", nil)

    -- 3. 等级 + 经验进度条 (精致圆角带光效)
    local barX, barY = 16, topBarH + 2
    local barW, barH = W - 32, 30

    local curLv = battlePassState.level
    local curExp = battlePassState.exp
    local maxLv = bpCfg.maxLevel
    local neededExp = (curLv < maxLv) and (bpCfg.expPerLevel[curLv + 1] or 999) or 1
    local expRatio = (curLv >= maxLv) and 1.0 or math.min(1.0, curExp / neededExp)

    -- 进度条背景 (深色内凹效果)
    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 6)
    nvgFillColor(vg, nvgRGBA(12, 10, 8, 230)); nvgFill(vg)
    -- 内部凹陷边框
    nvgStrokeColor(vg, nvgRGBA(60, 45, 25, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 经验填充 (渐变+高光条)
    if expRatio > 0 then
        local fillW = math.max(6, (barW - 4) * expRatio)
        local expGrad = nvgLinearGradient(vg, barX + 2, barY, barX + 2, barY + barH,
            nvgRGBA(255, 210, 60, 245), nvgRGBA(210, 140, 30, 245))
        nvgBeginPath(vg); nvgRoundedRect(vg, barX + 2, barY + 2, fillW, barH - 4, 5)
        nvgFillPaint(vg, expGrad); nvgFill(vg)
        -- 顶部高光线
        local hlGrad = nvgLinearGradient(vg, barX + 2, barY + 2, barX + 2, barY + barH * 0.4,
            nvgRGBA(255, 255, 200, 100), nvgRGBA(255, 255, 200, 0))
        nvgBeginPath(vg); nvgRoundedRect(vg, barX + 3, barY + 3, fillW - 2, barH * 0.35, 4)
        nvgFillPaint(vg, hlGrad); nvgFill(vg)
        -- 流光动画 (沿填充区域移动的亮条)
        local shimmerX = barX + 2 + ((t * 60) % (fillW + 30)) - 15
        if shimmerX < barX + 2 + fillW then
            nvgSave(vg)
            nvgScissor(vg, barX + 2, barY + 2, fillW, barH - 4)
            local shimGrad = nvgLinearGradient(vg, shimmerX - 10, 0, shimmerX + 10, 0,
                nvgRGBA(255, 255, 220, 0), nvgRGBA(255, 255, 240, 90))
            nvgBeginPath(vg); nvgRect(vg, shimmerX - 10, barY + 2, 20, barH - 4)
            nvgFillPaint(vg, shimGrad); nvgFill(vg)
            nvgRestore(vg)
        end
    end
    -- 进度条两端装饰端帽 (小金色菱形)
    local capY = barY + barH / 2
    for _, capX in ipairs({ barX - 1, barX + barW + 1 }) do
        nvgBeginPath(vg)
        nvgMoveTo(vg, capX, capY - 5)
        nvgLineTo(vg, capX + 4, capY)
        nvgLineTo(vg, capX, capY + 5)
        nvgLineTo(vg, capX - 4, capY)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 180)); nvgFill(vg)
    end

    -- 等级徽章 (左侧凸出圆形)
    local badgeR = 20
    local badgeCX = barX + badgeR + 4
    local badgeCY = barY + barH / 2
    nvgBeginPath(vg); nvgCircle(vg, badgeCX, badgeCY, badgeR)
    local badgeGrad = nvgRadialGradient(vg, badgeCX, badgeCY - 3, 2, badgeR,
        nvgRGBA(255, 220, 80, 255), nvgRGBA(180, 110, 30, 255))
    nvgFillPaint(vg, badgeGrad); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 60, 15, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(50, 25, 0, 255))
    nvgText(vg, badgeCX, badgeCY, tostring(curLv), nil)

    -- 经验文字 (右侧)
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    if curLv >= maxLv then
        nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
        nvgText(vg, barX + barW - 8, barY + barH / 2, "MAX", nil)
    else
        nvgFillColor(vg, nvgRGBA(230, 210, 180, 230))
        nvgText(vg, barX + barW - 8, barY + barH / 2, curExp .. "/" .. neededExp, nil)
    end

    -- 4. Tab 切换按钮 (圆角胶囊样式)
    local tabNames = { "奖励总览", "每日任务", "周任务", "赛季任务" }
    local tabH = 34
    local tabGap = 5
    local tabPad = 12
    local tabTotalW = W - tabPad * 2
    local tabBtnW = (tabTotalW - (#tabNames - 1) * tabGap) / #tabNames
    local tabY = barY + barH + 10

    -- Tab 背景条 (双层底框)
    nvgBeginPath(vg); nvgRoundedRect(vg, tabPad - 3, tabY - 3, tabTotalW + 6, tabH + 6, 9)
    nvgFillColor(vg, nvgRGBA(10, 8, 6, 220)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, tabPad - 3, tabY - 3, tabTotalW + 6, tabH + 6, 9)
    nvgStrokeColor(vg, nvgRGBA(120, 90, 40, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    battlePassTabRects = {}
    for i, name in ipairs(tabNames) do
        local tx = tabPad + (i - 1) * (tabBtnW + tabGap)
        local isActive = (battlePassUIState.tab == i)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabBtnW, tabH, 6)
        if isActive then
            local tGrad = nvgLinearGradient(vg, tx, tabY, tx, tabY + tabH,
                nvgRGBA(210, 150, 50, 245), nvgRGBA(155, 95, 28, 245))
            nvgFillPaint(vg, tGrad); nvgFill(vg)
            -- 内顶高光
            local tabHL = nvgLinearGradient(vg, tx, tabY, tx, tabY + tabH * 0.4,
                nvgRGBA(255, 240, 180, 80), nvgRGBA(255, 240, 180, 0))
            nvgBeginPath(vg); nvgRoundedRect(vg, tx + 1, tabY + 1, tabBtnW - 2, tabH * 0.4, 5)
            nvgFillPaint(vg, tabHL); nvgFill(vg)
            -- 金色边框
            nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabBtnW, tabH, 6)
            nvgStrokeColor(vg, nvgRGBA(255, 210, 100, 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            -- 底部高光指示条
            nvgBeginPath(vg); nvgRoundedRect(vg, tx + tabBtnW * 0.15, tabY + tabH - 3, tabBtnW * 0.7, 2.5, 1)
            nvgFillColor(vg, nvgRGBA(255, 240, 200, 220)); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(25, 20, 18, 180)); nvgFill(vg)
            -- 暗色边框
            nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabBtnW, tabH, 6)
            nvgStrokeColor(vg, nvgRGBA(80, 60, 30, 50)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        end
        nvgFontSize(vg, 19)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(255, 248, 220, 255) or nvgRGBA(160, 140, 110, 200))
        nvgText(vg, tx + tabBtnW / 2, tabY + tabH / 2, name, nil)
        battlePassTabRects[i] = { x = tx, y = tabY, w = tabBtnW, h = tabH }
    end

    -- Tab 红点
    local tabHasRed = { false, false, false, false }
    for _, tt in ipairs(bpCfg.dailyTasks) do
        local p = battlePassState.dailyProgress[tt.id] or 0
        if p >= tt.target and not battlePassState.dailyClaimed[tt.id] then tabHasRed[2] = true; break end
    end
    for _, tt in ipairs(bpCfg.weeklyTasks) do
        local p = battlePassState.weeklyProgress[tt.id] or 0
        if p >= tt.target and not battlePassState.weeklyClaimed[tt.id] then tabHasRed[3] = true; break end
    end
    for _, tt in ipairs(bpCfg.seasonTasks) do
        local p = battlePassState.seasonProgress[tt.id] or 0
        if p >= tt.target and not battlePassState.seasonClaimed[tt.id] then tabHasRed[4] = true; break end
    end
    for lv = 1, math.min(curLv, maxLv) do
        if not battlePassState.freeRewardClaimed[lv] then tabHasRed[1] = true; break end
    end
    for i, hr in ipairs(tabHasRed) do
        if hr and battlePassTabRects[i] then
            local tr = battlePassTabRects[i]
            DrawRedDot(tr.x + tr.w - 5, tr.y + 5, 5)
        end
    end

    -- 5. 内容区域 (带裁剪)
    local contentTop = tabY + tabH + 8
    local contentBottom = H - 4
    local contentH = contentBottom - contentTop

    nvgSave(vg)
    nvgScissor(vg, 0, contentTop, W, contentH)

    if battlePassUIState.tab == 1 then
        DrawBattlePassRewardsTab(W, H, contentTop, contentH, t)
    else
        DrawBattlePassTasksTab(W, H, contentTop, contentH, t)
    end

    nvgRestore(vg)
end


--- 战令奖励总览 Tab (双轨道横向滚动, 精致卡片)
function DrawBattlePassRewardsTab(W, H, contentTop, contentH, t)
    local bpCfg = GameConfig.BATTLE_PASS
    local maxLv = bpCfg.maxLevel
    local curLv = battlePassState.level
    local cx = W / 2

    local cellW = 94
    local cellH = 105
    local cellGap = 8
    local trackGap = 14
    local sOff = battlePassUIState.rewardScrollX

    -- 标签区域
    local labelW = 48
    local trackAreaX = labelW
    local trackAreaW = W - labelW

    -- ===== 上轨道标签 (高级/广告) =====
    local upperY = contentTop + 8
    -- 标签背景卡片
    local lblX, lblY2 = 2, upperY + 8
    local lblW2, lblH2 = labelW - 4, cellH - 16
    nvgBeginPath(vg); nvgRoundedRect(vg, lblX, lblY2, lblW2, lblH2, 5)
    local premLabelGrad = nvgLinearGradient(vg, lblX, lblY2, lblX, lblY2 + lblH2,
        nvgRGBA(80, 50, 15, 220), nvgRGBA(50, 30, 10, 220))
    nvgFillPaint(vg, premLabelGrad); nvgFill(vg)
    -- 徽章底纹 (原图128x128正方形, 按短边适配避免拉伸)
    if IsImageReady(IMG.bpBadgeVip) then
        local badgeSz = math.max(lblW2, lblH2)  -- 按长边撑满, 保持正方形
        local bPat = nvgImagePattern(vg, lblX + (lblW2 - badgeSz) / 2, lblY2 + (lblH2 - badgeSz) / 2,
            badgeSz, badgeSz, 0, IMG.bpBadgeVip, 0.25)
        nvgBeginPath(vg); nvgRoundedRect(vg, lblX, lblY2, lblW2, lblH2, 5)
        nvgFillPaint(vg, bPat); nvgFill(vg)
    end
    -- 金色边框
    nvgBeginPath(vg); nvgRoundedRect(vg, lblX, lblY2, lblW2, lblH2, 5)
    nvgStrokeColor(vg, nvgRGBA(220, 170, 60, 120)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 210, 80, 240))
    nvgText(vg, labelW / 2, upperY + cellH / 2 - 8, "高级", nil)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(220, 180, 100, 160))
    nvgText(vg, labelW / 2, upperY + cellH / 2 + 10, "(广告)", nil)

    -- ===== 下轨道标签 (普通/免费) =====
    local lowerY = upperY + cellH + trackGap
    local flblY = lowerY + 8
    nvgBeginPath(vg); nvgRoundedRect(vg, lblX, flblY, lblW2, lblH2, 5)
    local freeLabelGrad = nvgLinearGradient(vg, lblX, flblY, lblX, flblY + lblH2,
        nvgRGBA(20, 40, 60, 220), nvgRGBA(15, 25, 40, 220))
    nvgFillPaint(vg, freeLabelGrad); nvgFill(vg)
    -- 徽章底纹 (原图128x128正方形, 按短边适配避免拉伸)
    if IsImageReady(IMG.bpBadgeFree) then
        local badgeSz2 = math.max(lblW2, lblH2)
        local bPat2 = nvgImagePattern(vg, lblX + (lblW2 - badgeSz2) / 2, flblY + (lblH2 - badgeSz2) / 2,
            badgeSz2, badgeSz2, 0, IMG.bpBadgeFree, 0.25)
        nvgBeginPath(vg); nvgRoundedRect(vg, lblX, flblY, lblW2, lblH2, 5)
        nvgFillPaint(vg, bPat2); nvgFill(vg)
    end
    -- 蓝色边框
    nvgBeginPath(vg); nvgRoundedRect(vg, lblX, flblY, lblW2, lblH2, 5)
    nvgStrokeColor(vg, nvgRGBA(80, 140, 220, 100)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 17)
    nvgFillColor(vg, nvgRGBA(140, 200, 255, 240))
    nvgText(vg, labelW / 2, lowerY + cellH / 2 - 8, "普通", nil)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(120, 160, 200, 160))
    nvgText(vg, labelW / 2, lowerY + cellH / 2 + 10, "(免费)", nil)

    -- 裁剪轨道区域
    nvgSave(vg)
    nvgScissor(vg, trackAreaX, contentTop, trackAreaW, contentH)

    battlePassClaimFreeRects = {}
    battlePassClaimPremiumRects = {}

    for lv = 1, maxLv do
        local cellX = trackAreaX + 10 + (lv - 1) * (cellW + cellGap) + sOff
        if cellX + cellW < trackAreaX - 10 or cellX > W + 10 then goto continue_lv end

        local unlocked = curLv >= lv
        local freeR = bpCfg.freeRewards[lv]
        local premR = bpCfg.premiumRewards[lv]
        local freeClaimed = battlePassState.freeRewardClaimed[lv]
        local premClaimed = battlePassState.premiumRewardClaimed[lv]

        -- ===== 里程碑标记 (Lv10/20/30 顶部金色旗帜 + 发光光柱) =====
        if lv == 10 or lv == 20 or lv == 30 then
            local flagX = cellX + cellW / 2
            local flagY = upperY - 4
            -- 光柱连接上下轨道
            local pillarAlpha = math.floor(30 + 15 * math.sin(t * 2.0 + lv * 0.3))
            local pillarGrad = nvgLinearGradient(vg, flagX - 3, upperY, flagX - 3, lowerY + cellH,
                nvgRGBA(255, 210, 70, pillarAlpha), nvgRGBA(255, 210, 70, 0))
            nvgBeginPath(vg); nvgRect(vg, flagX - 3, upperY, 6, lowerY + cellH - upperY)
            nvgFillPaint(vg, pillarGrad); nvgFill(vg)
            -- 旗帜形状 (加大)
            nvgBeginPath(vg)
            nvgMoveTo(vg, flagX - 12, flagY - 10)
            nvgLineTo(vg, flagX + 12, flagY - 10)
            nvgLineTo(vg, flagX + 12, flagY + 5)
            nvgLineTo(vg, flagX, flagY)
            nvgLineTo(vg, flagX - 12, flagY + 5)
            nvgClosePath(vg)
            local flagGrad = nvgLinearGradient(vg, flagX, flagY - 10, flagX, flagY + 5,
                nvgRGBA(255, 220, 80, 240), nvgRGBA(200, 140, 30, 240))
            nvgFillPaint(vg, flagGrad); nvgFill(vg)
            -- 旗帜边框
            nvgBeginPath(vg)
            nvgMoveTo(vg, flagX - 12, flagY - 10)
            nvgLineTo(vg, flagX + 12, flagY - 10)
            nvgLineTo(vg, flagX + 12, flagY + 5)
            nvgLineTo(vg, flagX, flagY)
            nvgLineTo(vg, flagX - 12, flagY + 5)
            nvgClosePath(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 240, 160, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            DrawBPIcon(IMG.bpIconMilestone, flagX - 9, flagY - 4, 11, 255)
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(60, 25, 0, 255))
            nvgText(vg, flagX + 3, flagY - 3, tostring(lv), nil)
        end

        -- ===== 上轨道: 高级奖励卡片 =====
        nvgBeginPath(vg); nvgRoundedRect(vg, cellX, upperY, cellW, cellH, 7)
        if premClaimed then
            nvgFillColor(vg, nvgRGBA(22, 22, 18, 150))
        elseif unlocked then
            local glow = 0.75 + 0.25 * math.sin(t * 2.5 + lv * 0.5)
            local cardGrad = nvgLinearGradient(vg, cellX, upperY, cellX, upperY + cellH,
                nvgRGBA(65, 45, 15, math.floor(230 * glow)),
                nvgRGBA(40, 25, 8, math.floor(240 * glow)))
            nvgFillPaint(vg, cardGrad)
        else
            nvgFillColor(vg, nvgRGBA(22, 20, 16, 200))
        end
        nvgFill(vg)
        -- 边框 (解锁时金色发光)
        nvgBeginPath(vg); nvgRoundedRect(vg, cellX, upperY, cellW, cellH, 7)
        if premClaimed then
            nvgStrokeColor(vg, nvgRGBA(50, 50, 35, 80))
        elseif unlocked then
            local ba = math.floor(140 + 40 * math.sin(t * 3 + lv))
            nvgStrokeColor(vg, nvgRGBA(255, 200, 60, ba))
        else
            nvgStrokeColor(vg, nvgRGBA(60, 45, 25, 80))
        end
        nvgStrokeWidth(vg, unlocked and not premClaimed and 1.5 or 1); nvgStroke(vg)
        -- 金色卡片纹饰覆盖 (原图129x160, 按比例居中铺设)
        if IsImageReady(IMG.bpCardGold) then
            local ovA = premClaimed and 0.08 or (unlocked and 0.2 or 0.1)
            local imgRatio = 129 / 160
            local cellRatio = cellW / cellH
            local ovW, ovH
            if cellRatio > imgRatio then
                ovW = cellW; ovH = cellW / imgRatio
            else
                ovH = cellH; ovW = cellH * imgRatio
            end
            local ovPat = nvgImagePattern(vg, cellX + (cellW - ovW) / 2, upperY + (cellH - ovH) / 2,
                ovW, ovH, 0, IMG.bpCardGold, ovA)
            nvgBeginPath(vg); nvgRoundedRect(vg, cellX, upperY, cellW, cellH, 7)
            nvgFillPaint(vg, ovPat); nvgFill(vg)
        end
        -- 内阴影 (四边向内暗角)
        local isTG = nvgLinearGradient(vg, cellX, upperY, cellX, upperY + 10,
            nvgRGBA(0, 0, 0, 50), nvgRGBA(0, 0, 0, 0))
        nvgBeginPath(vg); nvgRoundedRect(vg, cellX, upperY, cellW, 10, 7)
        nvgFillPaint(vg, isTG); nvgFill(vg)
        local isBG = nvgLinearGradient(vg, cellX, upperY + cellH - 8, cellX, upperY + cellH,
            nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 60))
        nvgBeginPath(vg); nvgRoundedRect(vg, cellX, upperY + cellH - 8, cellW, 8, 7)
        nvgFillPaint(vg, isBG); nvgFill(vg)

        -- 等级号 (顶部小标签 带底色背景)
        local lvTagW = 36
        local lvTagH = 16
        local lvTagX = cellX + (cellW - lvTagW) / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, lvTagX, upperY + 1, lvTagW, lvTagH, 3)
        nvgFillColor(vg, nvgRGBA(40, 25, 8, unlocked and 200 or 120)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, lvTagX, upperY + 1, lvTagW, lvTagH, 3)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 60, unlocked and 120 or 40)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, unlocked and 255 or 100))
        nvgText(vg, cellX + cellW / 2, upperY + 1 + lvTagH / 2, "Lv." .. lv, nil)

        -- 奖励内容
        DrawBPRewardContent(cellX, upperY + 20, cellW, cellH - 28, premR, premClaimed)

        -- 底部按钮/状态
        if premClaimed then
            local checkY = upperY + cellH - 10
            DrawBPIcon(IMG.bpIconCheck, cellX + cellW / 2 - 16, checkY, 12, 160)
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(100, 100, 85, 160))
            nvgText(vg, cellX + cellW / 2 + 4, upperY + cellH - 4, "已领", nil)
        elseif unlocked then
            local btnW2, btnH2 = cellW - 8, 24
            local btnX2 = cellX + 4
            local btnY2 = upperY + cellH - btnH2 - 4
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 5)
            local adGrad = nvgLinearGradient(vg, btnX2, btnY2, btnX2, btnY2 + btnH2,
                nvgRGBA(220, 155, 40, 245), nvgRGBA(180, 110, 25, 245))
            nvgFillPaint(vg, adGrad); nvgFill(vg)
            nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 240, 255))
            nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "看广告领取", nil)
            battlePassClaimPremiumRects[lv] = { x = btnX2, y = btnY2, w = btnW2, h = btnH2 }
        else
            local lockY = upperY + cellH - 10
            DrawBPIcon(IMG.bpIconLock, cellX + cellW / 2 - 18, lockY, 11, 130)
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(80, 65, 45, 130))
            nvgText(vg, cellX + cellW / 2 + 4, upperY + cellH - 4, "未解锁", nil)
        end

        -- ===== 下轨道: 免费奖励卡片 =====
        nvgBeginPath(vg); nvgRoundedRect(vg, cellX, lowerY, cellW, cellH, 7)
        if freeClaimed then
            nvgFillColor(vg, nvgRGBA(18, 22, 28, 150))
        elseif unlocked then
            local glow = 0.75 + 0.25 * math.sin(t * 2.0 + lv * 0.4)
            local cardGrad = nvgLinearGradient(vg, cellX, lowerY, cellX, lowerY + cellH,
                nvgRGBA(20, 40, 60, math.floor(230 * glow)),
                nvgRGBA(12, 25, 38, math.floor(240 * glow)))
            nvgFillPaint(vg, cardGrad)
        else
            nvgFillColor(vg, nvgRGBA(16, 20, 26, 200))
        end
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, cellX, lowerY, cellW, cellH, 7)
        if freeClaimed then
            nvgStrokeColor(vg, nvgRGBA(40, 60, 40, 80))
        elseif unlocked then
            local ba = math.floor(120 + 30 * math.sin(t * 2.5 + lv))
            nvgStrokeColor(vg, nvgRGBA(80, 170, 255, ba))
        else
            nvgStrokeColor(vg, nvgRGBA(40, 50, 60, 80))
        end
        nvgStrokeWidth(vg, unlocked and not freeClaimed and 1.5 or 1); nvgStroke(vg)
        -- 蓝色卡片纹饰覆盖 (原图129x160, 按比例居中铺设)
        if IsImageReady(IMG.bpCardBlue) then
            local ovA2 = freeClaimed and 0.08 or (unlocked and 0.2 or 0.1)
            local imgR2 = 129 / 160
            local cellR2 = cellW / cellH
            local ovW2, ovH2
            if cellR2 > imgR2 then
                ovW2 = cellW; ovH2 = cellW / imgR2
            else
                ovH2 = cellH; ovW2 = cellH * imgR2
            end
            local ovPat2 = nvgImagePattern(vg, cellX + (cellW - ovW2) / 2, lowerY + (cellH - ovH2) / 2,
                ovW2, ovH2, 0, IMG.bpCardBlue, ovA2)
            nvgBeginPath(vg); nvgRoundedRect(vg, cellX, lowerY, cellW, cellH, 7)
            nvgFillPaint(vg, ovPat2); nvgFill(vg)
        end
        -- 内阴影
        local isTG2 = nvgLinearGradient(vg, cellX, lowerY, cellX, lowerY + 10,
            nvgRGBA(0, 0, 0, 45), nvgRGBA(0, 0, 0, 0))
        nvgBeginPath(vg); nvgRoundedRect(vg, cellX, lowerY, cellW, 10, 7)
        nvgFillPaint(vg, isTG2); nvgFill(vg)
        local isBG2 = nvgLinearGradient(vg, cellX, lowerY + cellH - 8, cellX, lowerY + cellH,
            nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 55))
        nvgBeginPath(vg); nvgRoundedRect(vg, cellX, lowerY + cellH - 8, cellW, 8, 7)
        nvgFillPaint(vg, isBG2); nvgFill(vg)

        -- 等级号 (带底色标签)
        local lvTagX2 = cellX + (cellW - 36) / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, lvTagX2, lowerY + 1, 36, 16, 3)
        nvgFillColor(vg, nvgRGBA(12, 25, 40, unlocked and 200 or 120)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, lvTagX2, lowerY + 1, 36, 16, 3)
        nvgStrokeColor(vg, nvgRGBA(80, 150, 220, unlocked and 100 or 35)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(130, 190, 255, unlocked and 255 or 100))
        nvgText(vg, cellX + cellW / 2, lowerY + 9, "Lv." .. lv, nil)

        DrawBPRewardContent(cellX, lowerY + 20, cellW, cellH - 28, freeR, freeClaimed)

        if freeClaimed then
            local checkY2 = lowerY + cellH - 10
            DrawBPIcon(IMG.bpIconCheck, cellX + cellW / 2 - 16, checkY2, 12, 160)
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(100, 120, 100, 160))
            nvgText(vg, cellX + cellW / 2 + 4, lowerY + cellH - 4, "已领", nil)
        elseif unlocked then
            local btnW2, btnH2 = cellW - 8, 24
            local btnX2 = cellX + 4
            local btnY2 = lowerY + cellH - btnH2 - 4
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 5)
            local freeGrad = nvgLinearGradient(vg, btnX2, btnY2, btnX2, btnY2 + btnH2,
                nvgRGBA(50, 150, 220, 245), nvgRGBA(35, 110, 180, 245))
            nvgFillPaint(vg, freeGrad); nvgFill(vg)
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "免费领取", nil)
            battlePassClaimFreeRects[lv] = { x = btnX2, y = btnY2, w = btnW2, h = btnH2 }
        else
            local lockY2 = lowerY + cellH - 10
            DrawBPIcon(IMG.bpIconLock, cellX + cellW / 2 - 18, lockY2, 11, 130)
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(70, 80, 90, 130))
            nvgText(vg, cellX + cellW / 2 + 4, lowerY + cellH - 4, "未解锁", nil)
        end

        ::continue_lv::
    end

    nvgRestore(vg)

    -- 底部滑动提示 (带动画箭头 - NanoVG三角形)
    local arrowOff = math.floor(4 * math.sin(t * 3))
    local arrowAlpha = math.floor(120 + 40 * math.sin(t * 2))
    local hintY = H - 12
    local hintText = "左右滑动查看全部" .. maxLv .. "级奖励"
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 140, 100, arrowAlpha))
    nvgText(vg, cx, hintY, hintText, nil)
    -- 左箭头三角形
    local arrX1 = cx - 120 + arrowOff
    nvgBeginPath(vg)
    nvgMoveTo(vg, arrX1, hintY)
    nvgLineTo(vg, arrX1 + 7, hintY - 5)
    nvgLineTo(vg, arrX1 + 7, hintY + 5)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(160, 140, 100, arrowAlpha)); nvgFill(vg)
    -- 右箭头三角形
    local arrX2 = cx + 120 - arrowOff
    nvgBeginPath(vg)
    nvgMoveTo(vg, arrX2, hintY)
    nvgLineTo(vg, arrX2 - 7, hintY - 5)
    nvgLineTo(vg, arrX2 - 7, hintY + 5)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(160, 140, 100, arrowAlpha)); nvgFill(vg)
end


--- 战令任务列表 Tab (精致卡片式列表)
function DrawBattlePassTasksTab(W, H, contentTop, contentH, t)
    local bpCfg = GameConfig.BATTLE_PASS
    local tab = battlePassUIState.tab
    local tasks, progress, claimed
    local taskType

    if tab == 2 then
        tasks = bpCfg.dailyTasks
        progress = battlePassState.dailyProgress
        claimed = battlePassState.dailyClaimed
        taskType = "daily"
    elseif tab == 3 then
        tasks = bpCfg.weeklyTasks
        progress = battlePassState.weeklyProgress
        claimed = battlePassState.weeklyClaimed
        taskType = "weekly"
    else
        tasks = bpCfg.seasonTasks
        progress = battlePassState.seasonProgress
        claimed = battlePassState.seasonClaimed
        taskType = "season"
    end

    local sOff = battlePassUIState.scrollY
    local secPad = 12
    local secW = W - secPad * 2
    local cardH = 72
    local cardGap = 8
    local startY = contentTop + 10 + sOff

    -- 标题提示 (带装饰线)
    local headerTexts = {
        [2] = "每日任务",
        [3] = "周任务",
        [4] = "赛季任务",
    }
    local headerSubs = {
        [2] = "每日0点重置",
        [3] = "每周一重置",
        [4] = "赛季结束重置",
    }
    nvgFontSize(vg, 21)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 140, 230))
    nvgText(vg, W / 2, startY, headerTexts[tab] or "", nil)
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(180, 160, 120, 160))
    nvgText(vg, W / 2, startY + 16, headerSubs[tab] or "", nil)
    -- 装饰分割线 (保持原图比例, 原图512x286, 裁切中间水平带)
    local lineY2 = startY + 28
    if IsImageReady(IMG.bpDivider) then
        local divW = 140
        local divH = divW * (286 / 512)  -- 保持比例
        local divDispH = 14  -- 只显示窄带
        local divY = lineY2 - divDispH / 2
        local patY = divY - (divH - divDispH) / 2
        local divPat = nvgImagePattern(vg, W / 2 - divW / 2, patY, divW, divH, 0, IMG.bpDivider, 0.45)
        nvgBeginPath(vg); nvgRect(vg, W / 2 - divW / 2, divY, divW, divDispH)
        nvgFillPaint(vg, divPat); nvgFill(vg)
    else
        local lineW2 = 60
        local decGradL = nvgLinearGradient(vg, W/2 - lineW2, lineY2, W/2 - 4, lineY2,
            nvgRGBA(200, 150, 60, 0), nvgRGBA(200, 150, 60, 120))
        nvgBeginPath(vg); nvgMoveTo(vg, W/2 - lineW2, lineY2); nvgLineTo(vg, W/2 - 4, lineY2)
        nvgStrokeWidth(vg, 1); nvgStrokePaint(vg, decGradL); nvgStroke(vg)
        local decGradR = nvgLinearGradient(vg, W/2 + 4, lineY2, W/2 + lineW2, lineY2,
            nvgRGBA(200, 150, 60, 120), nvgRGBA(200, 150, 60, 0))
        nvgBeginPath(vg); nvgMoveTo(vg, W/2 + 4, lineY2); nvgLineTo(vg, W/2 + lineW2, lineY2)
        nvgStrokeWidth(vg, 1); nvgStrokePaint(vg, decGradR); nvgStroke(vg)
    end
    startY = startY + 36

    battlePassTaskBtnRects = {}

    for i, task in ipairs(tasks) do
        local cy = startY + (i - 1) * (cardH + cardGap)
        local prog = progress[task.id] or 0
        local done = prog >= task.target
        local isClaimed = claimed[task.id] or false

        -- 卡片背景 (渐变+圆角+纹理)
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cy, secW, cardH, 8)
        if isClaimed then
            nvgFillColor(vg, nvgRGBA(18, 22, 16, 150))
        else
            local cardBg = nvgLinearGradient(vg, secPad, cy, secPad + secW, cy,
                nvgRGBA(28, 22, 16, 230), nvgRGBA(22, 18, 14, 230))
            nvgFillPaint(vg, cardBg)
        end
        nvgFill(vg)
        -- 卡片内阴影 (上下两侧)
        if not isClaimed then
            nvgSave(vg)
            nvgIntersectScissor(vg, secPad, cy, secW, cardH)
            local isTop = nvgLinearGradient(vg, 0, cy, 0, cy + 10,
                nvgRGBA(0, 0, 0, 60), nvgRGBA(0, 0, 0, 0))
            nvgBeginPath(vg); nvgRect(vg, secPad, cy, secW, 10)
            nvgFillPaint(vg, isTop); nvgFill(vg)
            local isBot = nvgLinearGradient(vg, 0, cy + cardH - 10, 0, cy + cardH,
                nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 50))
            nvgBeginPath(vg); nvgRect(vg, secPad, cy + cardH - 10, secW, 10)
            nvgFillPaint(vg, isBot); nvgFill(vg)
            nvgRestore(vg)
        end
        -- 卡片角饰纹理
        if not isClaimed and IsImageReady(IMG.bpFrameCorner) then
            local cornerSz = 20
            local ca = done and 0.35 or 0.15
            nvgSave(vg)
            nvgIntersectScissor(vg, secPad, cy, secW, cardH)
            -- 左上
            local cPat = nvgImagePattern(vg, secPad, cy, cornerSz, cornerSz, 0, IMG.bpFrameCorner, ca)
            nvgBeginPath(vg); nvgRect(vg, secPad, cy, cornerSz, cornerSz)
            nvgFillPaint(vg, cPat); nvgFill(vg)
            -- 右上
            nvgSave(vg); nvgTranslate(vg, secPad + secW, cy); nvgScale(vg, -1, 1)
            local cPat2 = nvgImagePattern(vg, 0, 0, cornerSz, cornerSz, 0, IMG.bpFrameCorner, ca)
            nvgBeginPath(vg); nvgRect(vg, 0, 0, cornerSz, cornerSz)
            nvgFillPaint(vg, cPat2); nvgFill(vg); nvgRestore(vg)
            -- 左下
            nvgSave(vg); nvgTranslate(vg, secPad, cy + cardH); nvgScale(vg, 1, -1)
            local cPat3 = nvgImagePattern(vg, 0, 0, cornerSz, cornerSz, 0, IMG.bpFrameCorner, ca)
            nvgBeginPath(vg); nvgRect(vg, 0, 0, cornerSz, cornerSz)
            nvgFillPaint(vg, cPat3); nvgFill(vg); nvgRestore(vg)
            -- 右下
            nvgSave(vg); nvgTranslate(vg, secPad + secW, cy + cardH); nvgScale(vg, -1, -1)
            local cPat4 = nvgImagePattern(vg, 0, 0, cornerSz, cornerSz, 0, IMG.bpFrameCorner, ca)
            nvgBeginPath(vg); nvgRect(vg, 0, 0, cornerSz, cornerSz)
            nvgFillPaint(vg, cPat4); nvgFill(vg); nvgRestore(vg)
            nvgRestore(vg)
        end
        -- 双层边框
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad, cy, secW, cardH, 8)
        if isClaimed then
            nvgStrokeColor(vg, nvgRGBA(50, 70, 45, 70))
        elseif done then
            local bda = math.floor(100 + 40 * math.sin(t * 3 + i))
            nvgStrokeColor(vg, nvgRGBA(255, 200, 60, bda))
        else
            nvgStrokeColor(vg, nvgRGBA(80, 55, 25, 60))
        end
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        -- 外层细描边 (可领取时金色呼吸)
        if done and not isClaimed then
            nvgBeginPath(vg); nvgRoundedRect(vg, secPad - 1, cy - 1, secW + 2, cardH + 2, 9)
            local oa = math.floor(30 + 25 * math.sin(t * 2.5 + i * 0.7))
            nvgStrokeColor(vg, nvgRGBA(255, 210, 80, oa))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end

        -- 左侧状态指示条 (渐变)
        nvgBeginPath(vg); nvgRoundedRect(vg, secPad + 2, cy + 10, 3.5, cardH - 20, 2)
        if isClaimed then
            local sGrad = nvgLinearGradient(vg, 0, cy + 10, 0, cy + cardH - 10,
                nvgRGBA(60, 160, 60, 200), nvgRGBA(40, 120, 40, 160))
            nvgFillPaint(vg, sGrad)
        elseif done then
            local sGrad = nvgLinearGradient(vg, 0, cy + 10, 0, cy + cardH - 10,
                nvgRGBA(255, 210, 60, 230), nvgRGBA(200, 150, 40, 200))
            nvgFillPaint(vg, sGrad)
        else
            nvgFillColor(vg, nvgRGBA(60, 45, 30, 100))
        end
        nvgFill(vg)

        -- 任务名称
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, isClaimed and nvgRGBA(130, 130, 115, 150) or nvgRGBA(245, 225, 185, 255))
        nvgText(vg, secPad + 14, cy + 8, task.name, nil)

        -- 任务描述
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(150, 140, 120, 170))
        nvgText(vg, secPad + 14, cy + 30, task.desc, nil)

        -- 经验奖励 (图标+文字)
        DrawBPIcon(IMG.bpIconExp, secPad + 20, cy + 54, 14, 200)
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
        nvgText(vg, secPad + 30, cy + 48, "+" .. task.exp .. " 经验", nil)

        -- 进度条 (精致+条纹动画)
        local pbW = 110
        local pbH = 12
        local pbX = secW + secPad - pbW - 72
        local pbY = cy + 10
        -- 进度条凹槽背景
        nvgBeginPath(vg); nvgRoundedRect(vg, pbX, pbY, pbW, pbH, 4)
        nvgFillColor(vg, nvgRGBA(20, 18, 14, 220)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, pbX, pbY, pbW, pbH, 4)
        nvgStrokeColor(vg, nvgRGBA(50, 40, 25, 80)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        local progRatio = math.min(1.0, prog / math.max(1, task.target))
        if progRatio > 0 then
            local fillW = math.max(4, (pbW - 2) * progRatio)
            nvgBeginPath(vg); nvgRoundedRect(vg, pbX + 1, pbY + 1, fillW, pbH - 2, 3)
            if done then
                local pGrad = nvgLinearGradient(vg, pbX, pbY, pbX, pbY + pbH,
                    nvgRGBA(80, 210, 120, 230), nvgRGBA(50, 170, 90, 220))
                nvgFillPaint(vg, pGrad)
            else
                local pGrad = nvgLinearGradient(vg, pbX, pbY, pbX, pbY + pbH,
                    nvgRGBA(220, 170, 60, 220), nvgRGBA(180, 130, 40, 200))
                nvgFillPaint(vg, pGrad)
            end
            nvgFill(vg)
            -- 条纹动画 (斜线移动)
            if not isClaimed then
                nvgSave(vg)
                nvgIntersectScissor(vg, pbX + 1, pbY + 1, fillW, pbH - 2)
                local stripeW = 6
                local stripeOff = (t * 20) % (stripeW * 2)
                for sx = -stripeW * 2, pbW + stripeW * 2, stripeW * 2 do
                    local sx2 = pbX + sx + stripeOff
                    nvgBeginPath(vg)
                    nvgMoveTo(vg, sx2, pbY)
                    nvgLineTo(vg, sx2 + stripeW, pbY)
                    nvgLineTo(vg, sx2 + stripeW - 4, pbY + pbH)
                    nvgLineTo(vg, sx2 - 4, pbY + pbH)
                    nvgClosePath(vg)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 18))
                    nvgFill(vg)
                end
                nvgRestore(vg)
            end
            -- 填充区域顶部高光
            nvgBeginPath(vg); nvgRoundedRect(vg, pbX + 1, pbY + 1, fillW, (pbH - 2) * 0.4, 3)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 25)); nvgFill(vg)
        end

        -- 进度文字
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
        nvgText(vg, pbX + pbW / 2, pbY + pbH + 14,
            math.min(prog, task.target) .. "/" .. task.target, nil)

        -- 右侧按钮 (更大更醒目)
        local btnW2 = 64
        local btnH2 = 32
        local btnX2 = secW + secPad - btnW2 - 4
        local btnY2 = cy + (cardH - btnH2) / 2
        if isClaimed then
            local taskCheckCx = btnX2 + btnW2 / 2
            local taskCheckCy = btnY2 + btnH2 / 2
            DrawBPIcon(IMG.bpIconCheck, taskCheckCx - 14, taskCheckCy, 14, 150)
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(90, 110, 90, 150))
            nvgText(vg, taskCheckCx + 6, taskCheckCy, "已领", nil)
        elseif done then
            -- 可领取: 外发光光晕
            local glowA = math.floor(35 + 25 * math.sin(t * 3.5 + i * 1.3))
            local glowR = nvgRadialGradient(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2,
                btnW2 * 0.3, btnW2 * 0.8,
                nvgRGBA(255, 200, 60, glowA), nvgRGBA(255, 200, 60, 0))
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2 - 8, btnY2 - 6, btnW2 + 16, btnH2 + 12, 12)
            nvgFillPaint(vg, glowR); nvgFill(vg)
            -- 按钮主体
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 6)
            local clGrad = nvgLinearGradient(vg, btnX2, btnY2, btnX2, btnY2 + btnH2,
                nvgRGBA(230, 180, 50, 245), nvgRGBA(190, 130, 30, 245))
            nvgFillPaint(vg, clGrad); nvgFill(vg)
            -- 按钮高光
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2 + 1, btnY2 + 1, btnW2 - 2, btnH2 * 0.4, 5)
            nvgFillColor(vg, nvgRGBA(255, 255, 200, 40)); nvgFill(vg)
            -- 金色边框
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 6)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 100, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 17)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 240, 255))
            nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "领取", nil)
            battlePassTaskBtnRects[#battlePassTaskBtnRects + 1] = {
                x = btnX2, y = btnY2, w = btnW2, h = btnH2,
                taskType = taskType, taskId = task.id
            }
        else
            -- 进行中: 暗色背景框
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 6)
            nvgFillColor(vg, nvgRGBA(30, 25, 20, 100)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 6)
            nvgStrokeColor(vg, nvgRGBA(60, 50, 35, 80)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(110, 90, 65, 130))
            nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "进行中", nil)
        end
    end

    -- 更新滚动内容高度
    local totalContentH = 36 + #tasks * (cardH + cardGap)
    battlePassUIState.contentHeight = math.max(0, totalContentH - contentH)
end



-- ============================================================================
-- 讨伐战 选择界面
-- ============================================================================
