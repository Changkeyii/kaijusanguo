-- ============================================================================
-- ui/summon_screen.lua - 召唤系统主界面
-- 用途: SUMMON phase 页签分发 (兵符召唤 / 武将召唤)
-- 依赖: seal_gacha.lua (兵符召唤UI), G_data (全局状态)
-- [TECH_DEBT] 全局函数模式: 延续 UI 模块的全局渲染设计
-- ============================================================================
---@diagnostic disable: undefined-global

require "ui.seal_gacha"

-- ============================================================================
-- 召唤主界面渲染
-- ============================================================================
function DrawSummonScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer

    -- 背景
    DrawSocialBg(W, H)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(12, 6, 24, 80)); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- ============ 顶部栏 ============
    local topBarY = 14
    local backW, backH = 80, 40
    local backX = 12

    -- 返回按钮
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, topBarY, backW, backH, 4)
    nvgFillColor(vg, nvgRGBA(20, 15, 35, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 80, 220, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, topBarY + backH / 2, "< 返回")
    summonBackBtnRect = { x = backX, y = topBarY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 36)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, topBarY + backH / 2, "召 唤")
    DrawHelpBtn(DESIGN_W - 14 - 30, topBarY + (backH - 30) / 2, 30)

    -- 玉壁显示
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(DESIGN_W - 14 - 30 - 10, topBarY + backH / 2, "玉壁: " .. (playerInfo.jade or 0))

    -- ============ 页签 ============
    local tabY = topBarY + backH + 8
    local tabH = 36
    local tabW = 120
    local tabGap = 8
    local tabNames = { "兵符召唤", "武将召唤", "武技召唤" }
    local tabStartX = cx - (#tabNames * tabW + (#tabNames - 1) * tabGap) / 2
    summonTabRects = {}

    for i, name in ipairs(tabNames) do
        local tx = tabStartX + (i - 1) * (tabW + tabGap)
        local isActive = (summonTab == i)

        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 4)
        if isActive then
            local tabGrad = nvgLinearGradient(vg, tx, tabY, tx + tabW, tabY + tabH,
                nvgRGBA(120, 60, 180, 230), nvgRGBA(90, 40, 150, 230))
            nvgFillPaint(vg, tabGrad); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 140, 255, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        else
            nvgFillColor(vg, nvgRGBA(30, 20, 45, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 70, 140, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end

        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
        else
            nvgFillColor(vg, nvgRGBA(180, 160, 200, 180))
        end
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, name, nil)

        summonTabRects[i] = { x = tx, y = tabY, w = tabW, h = tabH }
    end

    -- ============ 页签内容区域 ============
    -- 内容区上边界 = 页签底部 + 间距，下边界 = 屏幕底
    local contentTop = tabY + tabH + 8
    local contentBottom = H

    if summonTab == 1 then
        DrawSealSummonContent(t, contentTop, contentBottom)
    elseif summonTab == 2 then
        DrawHeroSummonContent(t, contentTop, contentBottom)
    elseif summonTab == 3 then
        DrawSkillSummonContent(t, contentTop, contentBottom)
    end
end


-- ============================================================================
-- 兵符召唤内容 (包裹现有 seal_gacha 函数)
-- ============================================================================
function DrawSealSummonContent(t, contentTop, contentBottom)
    -- 检查是否有动画/结果/规则弹窗
    if sealGachaState.pulling then
        DrawSealGachaPullAnimation(t)
        return
    end
    if sealGachaState.showResults then
        DrawSealGachaResults()
        return
    end
    -- 正常待机界面
    DrawSealGachaIdle(t, contentTop, contentBottom)
    -- 概率规则弹窗 (叠加在上面)
    if sealGachaState.showRules then
        DrawSealGachaRulesPopup()
    end
end


-- ============================================================================
-- 武将召唤 - 内容分发（动画/结果/待机）
-- ============================================================================
function DrawHeroSummonContent(t, contentTop, contentBottom)
    -- 检查是否有动画/结果弹窗（与兵符召唤同模式）
    if heroGachaState.pulling then
        DrawHeroGachaPullAnimation(t)
        return
    end
    if heroGachaState.showResults then
        DrawHeroGachaResults()
        return
    end
    -- 正常待机界面
    DrawHeroSummonIdle(t, contentTop, contentBottom)
    -- 概率规则弹窗 (叠加在上面)
    if heroGachaState.showRules then
        DrawHeroGachaRulesPopup()
    end
end


-- ============================================================================
-- 武将召唤 - 待机界面
-- ============================================================================
function DrawHeroSummonIdle(t, contentTop, contentBottom)
    local W = DESIGN_W
    local cx = W / 2
    -- 内容区高度和中心
    local areaH = contentBottom - contentTop
    -- 召唤阵居内容区上部 35% 处
    local circleY = contentTop + areaH * 0.30

    nvgFontFaceId(vg, GetMainFont())

    -- 召唤阵动画 (金色调/暖色调)
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2 + t * 0.6
        local r = 85 + 5 * math.sin(t * 1.6 + i)
        local px = cx + math.cos(angle) * r
        local py = circleY + math.sin(angle) * r
        local dotR = 3 + math.sin(t * 2.2 + i * 1.1) * 1.5
        nvgBeginPath(vg); nvgCircle(vg, px, py, dotR)
        local pulse = 0.5 + 0.5 * math.sin(t * 2 + i * 0.8)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, math.floor(160 * pulse))); nvgFill(vg)
        -- 连线
        local nextAngle = ((i % 8) + 1) / 8 * math.pi * 2 + t * 0.6
        local nr = 85 + 5 * math.sin(t * 1.6 + (i % 8 + 1))
        local nx = cx + math.cos(nextAngle) * nr
        local ny = circleY + math.sin(nextAngle) * nr
        nvgBeginPath(vg); nvgMoveTo(vg, px, py); nvgLineTo(vg, nx, ny)
        nvgStrokeColor(vg, nvgRGBA(255, 180, 60, math.floor(50 * pulse)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end

    -- 内旋弧
    for i = 1, 6 do
        local angle = -(i / 6) * math.pi * 2 + t * 0.8
        local arcLen = math.pi / 5
        nvgBeginPath(vg)
        nvgArc(vg, cx, circleY, 70, angle, angle + arcLen, NVG_CW)
        local pulse = 0.3 + 0.7 * math.sin(t * 2 + i * 0.6)
        nvgStrokeColor(vg, nvgRGBA(255, 210, 100, math.floor(60 * pulse)))
        nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
    end

    -- 中心光晕 (金色)
    local glowPulse = 0.5 + 0.5 * math.sin(t * 1.5)
    local glow = nvgRadialGradient(vg, cx, circleY, 5, 60,
        nvgRGBA(255, 200, 80, math.floor(50 * glowPulse)),
        nvgRGBA(200, 150, 40, 0))
    nvgBeginPath(vg); nvgCircle(vg, cx, circleY, 60)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 中心文字
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local textPulse = 0.6 + 0.4 * math.sin(t * 1.4)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, math.floor(200 * textPulse)))
    nvgText(vg, cx, circleY, "武 将 召 唤", nil)

    nvgFontSize(vg, 22)
    DrawWhiteInkText(cx, circleY + areaH * 0.055, "召唤强力武将加入阵营")

    -- 已拥有武将数量提示
    local ownedCount = 0
    for _, info in pairs(playerHeroes) do
        if info and info.owned then ownedCount = ownedCount + 1 end
    end
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, circleY + areaH * 0.09, "已拥有武将: " .. ownedCount .. "/" .. #HERO_CARDS)

    -- ===========================
    -- 抽卡按钮 (费用与兵符一致)
    -- ===========================
    local unitCost = SEAL_GACHA_COST
    local bigPull = playerInfo.jadeUnlockedBigPull

    heroGachaHundredBtnRect = nil

    -- 底部辅助按钮区: 距底边 areaH*0.02
    local auxBtnH = areaH * 0.07
    local auxBtnY = contentBottom - areaH * 0.02 - auxBtnH

    if bigPull then
        -- 增强模式: 3个按钮 (10连/50连/100连)
        local btnW = W * 0.156
        local btnH = areaH * 0.085
        local btnGap = areaH * 0.015
        local totalBtnH = btnH * 3 + btnGap * 2
        -- 按钮组在召唤阵与辅助按钮之间居中
        local btnZoneTop = circleY + areaH * 0.12
        local btnZoneBottom = auxBtnY - areaH * 0.06
        local btnY1 = btnZoneTop + math.max(0, (btnZoneBottom - btnZoneTop - totalBtnH) / 2)
        local btnY2 = btnY1 + btnH + btnGap
        local btnY3 = btnY2 + btnH + btnGap

        -- 10连
        local b1x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b1x, btnY1, btnW, btnH, 6)
        nvgFillColor(vg, nvgRGBA(50, 35, 20, 200)); nvgFill(vg)
        local bp1 = 0.7 + 0.3 * math.sin(t * 2)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 80, math.floor(180 * bp1)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 - 6, "十 连 召 唤")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 + 10, math.floor(unitCost * 10 * 0.9) .. " 玉壁 (9折)")
        heroGachaSingleBtnRect = { x = b1x, y = btnY1, w = btnW, h = btnH }

        -- 50连
        local b2x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        local g50 = nvgLinearGradient(vg, b2x, btnY2, b2x + btnW, btnY2 + btnH,
            nvgRGBA(65, 45, 20, 220), nvgRGBA(80, 55, 25, 220))
        nvgFillPaint(vg, g50); nvgFill(vg)
        local bp2 = 0.6 + 0.4 * math.sin(t * 2.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, math.floor(200 * bp2)))
        nvgStrokeWidth(vg, 1.8); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 - 6, "五十连召唤")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 + 10, math.floor(unitCost * 50 * 0.9) .. " 玉壁 (9折)")
        heroGachaTenBtnRect = { x = b2x, y = btnY2, w = btnW, h = btnH }

        -- 100连
        local b3x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b3x, btnY3, btnW, btnH, 6)
        local g100 = nvgLinearGradient(vg, b3x, btnY3, b3x + btnW, btnY3 + btnH,
            nvgRGBA(80, 50, 15, 230), nvgRGBA(90, 55, 10, 230))
        nvgFillPaint(vg, g100); nvgFill(vg)
        local bp3 = 0.5 + 0.5 * math.sin(t * 3)
        nvgBeginPath(vg); nvgRoundedRect(vg, b3x, btnY3, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(255, 240, 140, math.floor(220 * bp3)))
        nvgStrokeWidth(vg, 2.0); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY3 + btnH / 2 - 6, "百 连 召 唤")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY3 + btnH / 2 + 10, math.floor(unitCost * 100 * 0.9) .. " 玉壁 (9折)")
        heroGachaHundredBtnRect = { x = b3x, y = btnY3, w = btnW, h = btnH }
    else
        -- 标准模式: 2个按钮 (单抽/十连)
        local btnW = W * 0.156
        local btnH = areaH * 0.10
        local btnGap = areaH * 0.02
        local totalBtnH = btnH * 2 + btnGap
        local btnZoneTop = circleY + areaH * 0.12
        local btnZoneBottom = auxBtnY - areaH * 0.06
        local btnY1 = btnZoneTop + math.max(0, (btnZoneBottom - btnZoneTop - totalBtnH) / 2)
        local btnY2 = btnY1 + btnH + btnGap

        -- 单抽
        local b1x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b1x, btnY1, btnW, btnH, 6)
        nvgFillColor(vg, nvgRGBA(50, 35, 20, 200)); nvgFill(vg)
        local borderPulse1 = 0.7 + 0.3 * math.sin(t * 2)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 80, math.floor(180 * borderPulse1)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 - 8, "单 抽")
        nvgFontSize(vg, 18)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 + 12, SEAL_GACHA_COST .. " 玉壁")
        heroGachaSingleBtnRect = { x = b1x, y = btnY1, w = btnW, h = btnH }

        -- 十连
        local b2x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        local tenGrad = nvgLinearGradient(vg, b2x, btnY2, b2x + btnW, btnY2 + btnH,
            nvgRGBA(65, 45, 20, 220), nvgRGBA(80, 55, 25, 220))
        nvgFillPaint(vg, tenGrad); nvgFill(vg)
        local borderPulse2 = 0.6 + 0.4 * math.sin(t * 2.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, math.floor(200 * borderPulse2)))
        nvgStrokeWidth(vg, 1.8); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 - 8, "十 连 召 唤")
        nvgFontSize(vg, 18)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 + 12, SEAL_GACHA_TEN_COST .. " 玉壁 (9折)")
        heroGachaTenBtnRect = { x = b2x, y = btnY2, w = btnW, h = btnH }
    end

    -- 最后按钮底部
    local lastBtnBottom = heroGachaHundredBtnRect and (heroGachaHundredBtnRect.y + heroGachaHundredBtnRect.h)
        or (heroGachaTenBtnRect.y + heroGachaTenBtnRect.h)

    -- 武将录入口按钮 — 锚定: 距底边 areaH*0.02
    local mgrBtnW = W * 0.088
    local mgrBtnH = auxBtnH
    local mgrBtnX = W * 0.012
    local mgrBtnY = auxBtnY
    nvgBeginPath(vg); nvgRoundedRect(vg, mgrBtnX, mgrBtnY, mgrBtnW, mgrBtnH, 6)
    nvgFillColor(vg, nvgRGBA(35, 30, 50, 210)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(mgrBtnX + mgrBtnW / 2, mgrBtnY + mgrBtnH / 2, "武将录")
    heroGachaCodexBtnRect = { x = mgrBtnX, y = mgrBtnY, w = mgrBtnW, h = mgrBtnH }

    -- "?" 概率规则按钮 (右下) — 锚定: 与武将录同行
    local qBtnSize = areaH * 0.06
    local qBtnX = W - qBtnSize - W * 0.012
    local qBtnY = auxBtnY + (auxBtnH - qBtnSize) / 2
    nvgBeginPath(vg); nvgCircle(vg, qBtnX + qBtnSize / 2, qBtnY + qBtnSize / 2, qBtnSize / 2)
    nvgFillColor(vg, nvgRGBA(50, 40, 25, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(qBtnX + qBtnSize / 2, qBtnY + qBtnSize / 2, "?")
    heroGachaRulesBtnRect = { x = qBtnX, y = qBtnY, w = qBtnSize, h = qBtnSize }

end


-- ============================================================================
-- 武将召唤 - 抽卡动画
-- ============================================================================
function DrawHeroGachaPullAnimation(t)
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local cy = H * 0.40
    local progress = math.min(1, heroGachaState.pullTimer / 1.2)

    -- 金色扩散光圈
    local maxR = 120
    local r = maxR * progress
    local glow = nvgRadialGradient(vg, cx, cy, r * 0.3, r,
        nvgRGBA(255, 220, 100, math.floor(120 * (1 - progress * 0.5))),
        nvgRGBA(200, 160, 40, 0))
    nvgBeginPath(vg); nvgCircle(vg, cx, cy, r)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 旋转光线
    local lineCount = heroGachaState.pullCount >= 10 and 20 or 8
    for i = 1, lineCount do
        local angle = (i / lineCount) * math.pi * 2 + t * 4
        local len = 30 + 80 * progress
        local lsx = cx + math.cos(angle) * 10
        local lsy = cy + math.sin(angle) * 10
        local lex = cx + math.cos(angle) * len
        local ley = cy + math.sin(angle) * len
        nvgBeginPath(vg)
        nvgMoveTo(vg, lsx, lsy); nvgLineTo(vg, lex, ley)
        local la = math.floor(180 * (1 - progress * 0.3))
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, la))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- 中心金色闪光
    local flashA = math.floor(255 * math.max(0, progress - 0.6) / 0.4)
    if flashA > 0 then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(255, 240, 180, flashA)); nvgFill(vg)
    end

    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, H * 0.72, "点击跳过")
end


-- ============================================================================
-- 武将召唤 - 结果展示
-- ============================================================================
function DrawHeroGachaResults()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local results = heroGachaState.results
    local count = #results

    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180)); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    nvgFontSize(vg, 33)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 40, "召唤结果")

    if count == 0 then return end

    -- ★ 排序只执行一次（避免 table.sort 不稳定导致每帧闪烁）
    if not heroGachaState._resultsSorted then
        table.sort(results, function(a, b)
            if a.quality ~= b.quality then return a.quality > b.quality end
            if a.isFullCard and not b.isFullCard then return true end
            if not a.isFullCard and b.isFullCard then return false end
            if a.isNew and not b.isNew then return true end
            if not a.isNew and b.isNew then return false end
            return (a.cardIdx or 0) < (b.cardIdx or 0) -- 最终稳定排序键
        end)
        heroGachaState._resultsSorted = true
    end

    if count == 1 then
        -- 单抽: 居中大卡
        DrawHeroResultCard(cx, H * 0.14, results[1], true)
    else
        -- 多连: 5列网格
        local cols = 5
        local cardW = 92
        local cardH = 135
        local gapX = 6
        local gapY = 8
        local gridW = cols * cardW + (cols - 1) * gapX
        local startX = cx - gridW / 2
        local startY = 62

        for i, r in ipairs(results) do
            local col = ((i - 1) % cols)
            local row = math.floor((i - 1) / cols)
            local x = startX + col * (cardW + gapX) + cardW / 2
            local y = startY + row * (cardH + gapY)
            DrawHeroResultCard(x, y, r, false)
        end
    end

    -- 确认按钮
    local confirmW = 140
    local confirmH = 38
    local confirmX = cx - confirmW / 2
    local confirmY = H - 50
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, confirmY, confirmW, confirmH, 5)
    nvgFillColor(vg, nvgRGBA(50, 35, 20, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, confirmY + confirmH / 2, "确 认")
    heroGachaConfirmBtnRect = { x = confirmX, y = confirmY, w = confirmW, h = confirmH }
end


--- 绘制单个武将结果卡片（含立绘头像）
---@param cx number 卡片中心X
---@param cy number 卡片顶部Y
---@param r table 结果数据
---@param isBig boolean 是否大卡
function DrawHeroResultCard(cx, cy, r, isBig)
    local qc = QUALITY_COLORS[r.quality] or { 200, 195, 180 }
    local qTag = QUALITY_TAGS[r.quality] or "?"

    -- 卡片尺寸
    local cardW = isBig and 180 or 88
    local cardH = isBig and 260 or 130
    local cardX = cx - cardW / 2
    local cardY = cy

    -- 整卡: 金色外发光
    if r.isFullCard then
        local glowR = isBig and 8 or 5
        local glowGrad = nvgLinearGradient(vg, cardX - glowR, cardY - glowR,
            cardX + cardW + glowR, cardY + cardH + glowR,
            nvgRGBA(255, 220, 80, 120), nvgRGBA(255, 180, 40, 60))
        nvgBeginPath(vg); nvgRoundedRect(vg, cardX - glowR, cardY - glowR,
            cardW + glowR * 2, cardH + glowR * 2, 8)
        nvgFillPaint(vg, glowGrad); nvgFill(vg)
    end

    -- 卡片底色（品质渐变）
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, cardW, cardH, 6)
    local bgGrad = nvgLinearGradient(vg, cardX, cardY, cardX, cardY + cardH,
        nvgRGBA(qc[1], qc[2], qc[3], 50), nvgRGBA(20, 15, 10, 200))
    nvgFillPaint(vg, bgGrad); nvgFill(vg)
    local strokeAlpha = r.isFullCard and 240 or 140
    nvgStrokeColor(vg, nvgRGBA(qc[1], qc[2], qc[3], strokeAlpha))
    nvgStrokeWidth(vg, r.isFullCard and 2.0 or 1.0); nvgStroke(vg)

    -- ★ 英雄立绘图片
    local portraitH = isBig and 160 or 72
    local portraitW = cardW - 6
    local portraitX = cardX + 3
    local portraitY = cardY + 3
    local heroImg = IMG and IMG["hero" .. (r.cardIdx or 1)]
    if heroImg and heroImg > 0 then
        local imgW, imgH = nvgImageSize(vg, heroImg)
        if imgW > 0 and imgH > 0 then
            local imgAspect = imgW / imgH
            local boxAspect = portraitW / portraitH
            local drawW, drawH, drawX, drawY
            if imgAspect > boxAspect then
                drawH = portraitH
                drawW = portraitH * imgAspect
                drawX = portraitX - (drawW - portraitW) / 2
                drawY = portraitY
            else
                drawW = portraitW
                drawH = portraitW / imgAspect
                drawX = portraitX
                drawY = portraitY  -- 顶部对齐（显示头脸）
            end
            nvgSave(vg)
            nvgIntersectScissor(vg, portraitX, portraitY, portraitW, portraitH)
            local imgPat = nvgImagePattern(vg, drawX, drawY, drawW, drawH, 0, heroImg, 1.0)
            nvgBeginPath(vg); nvgRoundedRect(vg, portraitX, portraitY, portraitW, portraitH, 4)
            nvgFillPaint(vg, imgPat); nvgFill(vg)
            nvgRestore(vg)
        end
    else
        -- 无立绘时用品质色占位 + 兵种首字
        nvgBeginPath(vg); nvgRoundedRect(vg, portraitX, portraitY, portraitW, portraitH, 4)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 40)); nvgFill(vg)
        nvgFontSize(vg, isBig and 48 or 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 120))
        nvgText(vg, cx, portraitY + portraitH / 2, string.sub(r.name or "?", 1, 3), nil)
    end

    -- 立绘底部渐变遮罩（让文字更清晰）
    local maskH = isBig and 40 or 20
    local maskGrad = nvgLinearGradient(vg, cardX, portraitY + portraitH - maskH,
        cardX, portraitY + portraitH, nvgRGBA(20, 15, 10, 0), nvgRGBA(20, 15, 10, 200))
    nvgBeginPath(vg); nvgRect(vg, portraitX, portraitY + portraitH - maskH, portraitW, maskH)
    nvgFillPaint(vg, maskGrad); nvgFill(vg)

    -- 品质标签 (左上角)
    local tagFontSz = isBig and 16 or 10
    nvgFontSize(vg, tagFontSz)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    -- 品质底色小条
    local qTagW = isBig and 36 or 22
    local qTagH = isBig and 20 or 14
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, qTagW, qTagH, 4)
    nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 180)); nvgFill(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
    nvgText(vg, cardX + 3, cardY + 2, qTag, nil)

    -- 整卡/碎片标识 (右上角)
    local typeFontSz = isBig and 13 or 9
    local typeTagW = isBig and 38 or 26
    local typeTagH = isBig and 18 or 13
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX + cardW - typeTagW, cardY, typeTagW, typeTagH, 4)
    if r.isFullCard then
        nvgFillColor(vg, nvgRGBA(200, 160, 40, 200)); nvgFill(vg)
        nvgFontSize(vg, typeFontSz)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
        nvgText(vg, cardX + cardW - typeTagW / 2, cardY + typeTagH / 2, "整卡", nil)
    else
        nvgFillColor(vg, nvgRGBA(80, 100, 160, 200)); nvgFill(vg)
        nvgFontSize(vg, typeFontSz)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 230, 255, 240))
        nvgText(vg, cardX + cardW - typeTagW / 2, cardY + typeTagH / 2, "碎片", nil)
    end

    -- === 下半部分: 名字 + 状态信息 ===
    local infoY = cardY + portraitH + (isBig and 8 or 4)

    -- 武将名
    local nameSize = isBig and 24 or 13
    nvgFontSize(vg, nameSize)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
    nvgText(vg, cx, infoY, r.name, nil)
    infoY = infoY + (isBig and 22 or 13)

    -- 状态标签
    local statusFontSz = isBig and 20 or 11
    nvgFontSize(vg, statusFontSz)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if r.isFullCard then
        if r.isNew then
            nvgFillColor(vg, nvgRGBA(120, 255, 160, 230))
            nvgText(vg, cx, infoY, "新获得!", nil)
        elseif r.maxed then
            nvgFillColor(vg, nvgRGBA(255, 180, 80, 230))
            nvgText(vg, cx, infoY, "满命 +" .. (r.refund or 0) .. "玉壁", nil)
        else
            nvgFillColor(vg, nvgRGBA(255, 215, 0, 230))
            nvgText(vg, cx, infoY, "命" .. (r.oldConst or 0) .. " → " .. (r.newConst or 0), nil)
        end
    else
        local totalFrag = heroFragments[r.cardIdx] or 0
        local needFrag = HERO_FRAG_EXCHANGE[r.quality] or 50
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 230))
        nvgText(vg, cx, infoY, "×" .. (r.fragCount or 0) .. " (" .. totalFrag .. "/" .. needFrag .. ")", nil)

        -- 碎片进度条（小卡也画，让玩家直观看到收集进度）
        if isBig then
            infoY = infoY + 20
            local barW = cardW * 0.7
            local barH = 6
            local barX = cx - barW / 2
            local barY = infoY
            local pct = math.min(1, totalFrag / needFrag)
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 3)
            nvgFillColor(vg, nvgRGBA(40, 40, 60, 180)); nvgFill(vg)
            if pct > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW * pct, barH, 3)
                nvgFillColor(vg, nvgRGBA(100, 180, 255, 200)); nvgFill(vg)
            end
        end
    end
end


-- ============================================================================
-- 武将召唤 - 概率规则弹窗
-- ============================================================================
function DrawHeroGachaRulesPopup()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    -- 遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 110)); nvgFill(vg)

    -- 弹窗面板
    local panelW = W * 0.84
    local panelH = 520
    local panelX = cx - panelW / 2
    local panelY = H / 2 - panelH / 2

    local panelGrad = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + panelH,
        nvgRGBA(60, 40, 20, 240), nvgRGBA(45, 30, 15, 245))
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgFillPaint(vg, panelGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    local titleY = panelY + 28
    nvgFontSize(vg, 35)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, titleY, "武将召唤规则")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, titleY + 18)
    nvgLineTo(vg, panelX + panelW - 20, titleY + 18)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local lineH = 26
    local startY = titleY + 38
    local leftX = panelX + 24

    -- 品质概率
    nvgFontSize(vg, 25)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftX, startY, "武将品质概率")
    startY = startY + lineH

    local probs = {
        { name = "人品(N)",    prob = "40%",   quality = 1 },
        { name = "地品(R)",    prob = "29%",   quality = 2 },
        { name = "天品(SR)",   prob = "20%",   quality = 3 },
        { name = "神品(SSR)",  prob = "10%",   quality = 4 },
        { name = "限定(SSR+)", prob = "1%",    quality = 5 },
    }
    nvgFontSize(vg, 18)
    for _, p in ipairs(probs) do
        local c = QUALITY_COLORS[p.quality] or { 200, 200, 200 }
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 220))
        nvgText(vg, leftX + 10, startY, "· " .. p.name .. ": " .. p.prob, nil)
        startY = startY + lineH * 0.7
    end
    startY = startY + 8

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, startY)
    nvgLineTo(vg, panelX + panelW - 20, startY)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    startY = startY + 12

    -- 规则说明
    nvgFontSize(vg, 25)
    DrawWhiteInkText(leftX, startY, "规则说明")
    startY = startY + lineH

    nvgFontSize(vg, 19)
    DrawWhiteInkText(leftX + 10, startY, "· 单抽 " .. SEAL_GACHA_COST .. " 玉壁, 十连及以上享9折")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 普通抽取获得武将碎片")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 碎片达标可在残片仓库合成整卡")
    startY = startY + lineH * 0.75
    local pityN = HERO_GACHA_PITY_THRESHOLD or 70
    DrawWhiteInkText(leftX + 10, startY, "· 每 " .. pityN .. " 抽大保底必出SSR+整卡")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 满命(C6)武将再获得返还玉壁")

    -- 关闭按钮
    local closeBtnW = 120
    local closeBtnH = 36
    local closeBtnX = cx - closeBtnW / 2
    local closeBtnY = panelY + panelH - closeBtnH - 14
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 45, 25, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, closeBtnY + closeBtnH / 2, "知道了")
    heroGachaRulesCloseBtnRect = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }
end


-- ============================================================================
-- 武技召唤 - 内容分发
-- ============================================================================
function DrawSkillSummonContent(t, contentTop, contentBottom)
    if skillGachaState.pulling then
        DrawSkillGachaPullAnimation(t)
        return
    end
    if skillGachaState.showResults then
        DrawSkillGachaResults()
        return
    end
    DrawSkillSummonIdle(t, contentTop, contentBottom)
    if skillGachaState.showRules then
        DrawSkillGachaRulesPopup()
    end
end


-- ============================================================================
-- 武技召唤 - 待机界面
-- ============================================================================
function DrawSkillSummonIdle(t, contentTop, contentBottom)
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local areaH = contentBottom - contentTop
    local unitCost = SEAL_GACHA_COST

    nvgFontFaceId(vg, GetMainFont())

    -- 武技召唤圈动画 (紫色系)
    local circleY = contentTop + areaH * 0.30
    local circleR = areaH * 0.18
    -- 外圈
    nvgBeginPath(vg); nvgCircle(vg, cx, circleY, circleR)
    nvgStrokeColor(vg, nvgRGBA(180, 100, 255, math.floor(80 + 40 * math.sin(t * 1.5))))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)
    -- 内圈旋转
    local innerR = circleR * 0.7
    for i = 1, 6 do
        local angle = (i / 6) * math.pi * 2 + t * 1.2
        local px = cx + math.cos(angle) * innerR
        local py = circleY + math.sin(angle) * innerR
        nvgBeginPath(vg); nvgCircle(vg, px, py, 3)
        nvgFillColor(vg, nvgRGBA(200, 140, 255, math.floor(120 + 60 * math.sin(t * 2 + i))))
        nvgFill(vg)
    end
    -- 中心图标
    nvgFontSize(vg, 40)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 170, 255, math.floor(180 + 40 * math.sin(t * 1.8))))
    nvgText(vg, cx, circleY, "武", nil)

    -- 保底进度
    local pityCount = skillGachaState.pityCounter or 0
    local pityMax = SKILL_GACHA_PITY_THRESHOLD or 70
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, contentTop + areaH * 0.52, "保底进度: " .. pityCount .. "/" .. pityMax)

    -- 已拥有武技数
    local ownedCount = 0
    for _ in pairs(skillLayers) do ownedCount = ownedCount + 1 end
    nvgFontSize(vg, 15)
    DrawWhiteInkText(cx, contentTop + areaH * 0.57, "已拥有: " .. ownedCount .. "/" .. #SKILL_TECHNIQUES .. " 武技")

    -- 辅助按钮行锚定 (距底边 areaH*0.02)
    local auxBtnH = areaH * 0.07
    local auxBtnY = contentBottom - auxBtnH - areaH * 0.02

    -- 抽卡按钮
    local bigPull = playerInfo.jadeUnlockedBigPull
    if bigPull then
        local btnW = W * 0.156
        local btnH = areaH * 0.085
        local btnGap = areaH * 0.015
        local totalBtnH = btnH * 3 + btnGap * 2
        local btnZoneTop = circleY + areaH * 0.12
        local btnZoneBottom = auxBtnY - areaH * 0.06
        local btnY1 = btnZoneTop + math.max(0, (btnZoneBottom - btnZoneTop - totalBtnH) / 2)
        local btnY2 = btnY1 + btnH + btnGap
        local btnY3 = btnY2 + btnH + btnGap

        -- 10连
        local b1x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b1x, btnY1, btnW, btnH, 6)
        nvgFillColor(vg, nvgRGBA(40, 25, 55, 200)); nvgFill(vg)
        local bp1 = 0.7 + 0.3 * math.sin(t * 2)
        nvgStrokeColor(vg, nvgRGBA(200, 140, 255, math.floor(180 * bp1)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 - 6, "十 连 召 唤")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 + 10, math.floor(unitCost * 10 * 0.9) .. " 玉壁 (9折)")
        skillGachaSingleBtnRect = { x = b1x, y = btnY1, w = btnW, h = btnH }

        -- 50连
        local b2x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        local g50 = nvgLinearGradient(vg, b2x, btnY2, b2x + btnW, btnY2 + btnH,
            nvgRGBA(50, 30, 65, 220), nvgRGBA(60, 35, 75, 220))
        nvgFillPaint(vg, g50); nvgFill(vg)
        local bp2 = 0.6 + 0.4 * math.sin(t * 2.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(220, 160, 255, math.floor(200 * bp2)))
        nvgStrokeWidth(vg, 1.8); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 - 6, "五十连召唤")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 + 10, math.floor(unitCost * 50 * 0.9) .. " 玉壁 (9折)")
        skillGachaTenBtnRect = { x = b2x, y = btnY2, w = btnW, h = btnH }

        -- 100连
        local b3x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b3x, btnY3, btnW, btnH, 6)
        local g100 = nvgLinearGradient(vg, b3x, btnY3, b3x + btnW, btnY3 + btnH,
            nvgRGBA(60, 35, 75, 230), nvgRGBA(70, 40, 85, 230))
        nvgFillPaint(vg, g100); nvgFill(vg)
        local bp3 = 0.5 + 0.5 * math.sin(t * 3)
        nvgBeginPath(vg); nvgRoundedRect(vg, b3x, btnY3, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(240, 180, 255, math.floor(220 * bp3)))
        nvgStrokeWidth(vg, 2.0); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY3 + btnH / 2 - 6, "百 连 召 唤")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY3 + btnH / 2 + 10, math.floor(unitCost * 100 * 0.9) .. " 玉壁 (9折)")
        skillGachaHundredBtnRect = { x = b3x, y = btnY3, w = btnW, h = btnH }
    else
        local btnW = W * 0.156
        local btnH = areaH * 0.10
        local btnGap = areaH * 0.02
        local totalBtnH = btnH * 2 + btnGap
        local btnZoneTop = circleY + areaH * 0.12
        local btnZoneBottom = auxBtnY - areaH * 0.06
        local btnY1 = btnZoneTop + math.max(0, (btnZoneBottom - btnZoneTop - totalBtnH) / 2)
        local btnY2 = btnY1 + btnH + btnGap

        -- 单抽
        local b1x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b1x, btnY1, btnW, btnH, 6)
        nvgFillColor(vg, nvgRGBA(40, 25, 55, 200)); nvgFill(vg)
        local borderPulse1 = 0.7 + 0.3 * math.sin(t * 2)
        nvgStrokeColor(vg, nvgRGBA(200, 140, 255, math.floor(180 * borderPulse1)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 - 8, "单 抽")
        nvgFontSize(vg, 18)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 + 12, SEAL_GACHA_COST .. " 玉壁")
        skillGachaSingleBtnRect = { x = b1x, y = btnY1, w = btnW, h = btnH }

        -- 十连
        local b2x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        local tenGrad = nvgLinearGradient(vg, b2x, btnY2, b2x + btnW, btnY2 + btnH,
            nvgRGBA(50, 30, 65, 220), nvgRGBA(60, 35, 75, 220))
        nvgFillPaint(vg, tenGrad); nvgFill(vg)
        local borderPulse2 = 0.6 + 0.4 * math.sin(t * 2.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(220, 160, 255, math.floor(200 * borderPulse2)))
        nvgStrokeWidth(vg, 1.8); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 - 8, "十 连 召 唤")
        nvgFontSize(vg, 18)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 + 12, SEAL_GACHA_TEN_COST .. " 玉壁 (9折)")
        skillGachaTenBtnRect = { x = b2x, y = btnY2, w = btnW, h = btnH }
    end

    -- "?" 概率规则按钮 (右下)
    local qBtnSize = areaH * 0.06
    local qBtnX = W - qBtnSize - W * 0.012
    local qBtnY = auxBtnY + (auxBtnH - qBtnSize) / 2
    nvgBeginPath(vg); nvgCircle(vg, qBtnX + qBtnSize / 2, qBtnY + qBtnSize / 2, qBtnSize / 2)
    nvgFillColor(vg, nvgRGBA(40, 30, 55, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 140, 255, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(qBtnX + qBtnSize / 2, qBtnY + qBtnSize / 2, "?")
    skillGachaRulesBtnRect = { x = qBtnX, y = qBtnY, w = qBtnSize, h = qBtnSize }
end


-- ============================================================================
-- 武技召唤 - 抽卡动画
-- ============================================================================
function DrawSkillGachaPullAnimation(t)
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local cy = H * 0.40
    local progress = math.min(1, skillGachaState.pullTimer / 1.2)

    -- 紫色扩散光圈
    local maxR = 120
    local r = maxR * progress
    local glow = nvgRadialGradient(vg, cx, cy, r * 0.3, r,
        nvgRGBA(200, 140, 255, math.floor(120 * (1 - progress * 0.5))),
        nvgRGBA(140, 80, 200, 0))
    nvgBeginPath(vg); nvgCircle(vg, cx, cy, r)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 旋转光线
    local lineCount = skillGachaState.pullCount >= 10 and 20 or 8
    for i = 1, lineCount do
        local angle = (i / lineCount) * math.pi * 2 + t * 4
        local len = 30 + 80 * progress
        local lsx = cx + math.cos(angle) * 10
        local lsy = cy + math.sin(angle) * 10
        local lex = cx + math.cos(angle) * len
        local ley = cy + math.sin(angle) * len
        nvgBeginPath(vg)
        nvgMoveTo(vg, lsx, lsy); nvgLineTo(vg, lex, ley)
        local la = math.floor(180 * (1 - progress * 0.3))
        nvgStrokeColor(vg, nvgRGBA(200, 140, 255, la))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- 中心紫色闪光
    local flashA = math.floor(255 * math.max(0, progress - 0.6) / 0.4)
    if flashA > 0 then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(220, 180, 255, flashA)); nvgFill(vg)
    end

    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, H * 0.72, "点击跳过")
end


-- ============================================================================
-- 武技召唤 - 结果展示
-- ============================================================================
function DrawSkillGachaResults()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local results = skillGachaState.results
    local count = #results

    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180)); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    nvgFontSize(vg, 33)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 40, "武技召唤结果")

    if count == 0 then return end

    -- 排序 (只执行一次)
    if not skillGachaState._resultsSorted then
        table.sort(results, function(a, b)
            if a.tier ~= b.tier then return a.tier > b.tier end
            if a.isFullCard and not b.isFullCard then return true end
            if not a.isFullCard and b.isFullCard then return false end
            if a.isNew and not b.isNew then return true end
            if not a.isNew and b.isNew then return false end
            return (a.skillIdx or 0) < (b.skillIdx or 0)
        end)
        skillGachaState._resultsSorted = true
    end

    if count == 1 then
        DrawSkillResultCard(cx, H * 0.14, results[1], true)
    else
        local cols = 5
        local cardW = 92
        local cardH = 120
        local gapX = 6
        local gapY = 8
        local gridW = cols * cardW + (cols - 1) * gapX
        local startX = cx - gridW / 2
        local startY = 62

        for i, r in ipairs(results) do
            local col = ((i - 1) % cols)
            local row = math.floor((i - 1) / cols)
            local x = startX + col * (cardW + gapX) + cardW / 2
            local y = startY + row * (cardH + gapY)
            DrawSkillResultCard(x, y, r, false)
        end
    end

    -- 确认按钮
    local confirmW = 140
    local confirmH = 38
    local confirmX = cx - confirmW / 2
    local confirmY = H - 50
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, confirmY, confirmW, confirmH, 5)
    nvgFillColor(vg, nvgRGBA(40, 25, 55, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 140, 255, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, confirmY + confirmH / 2, "确 认")
    skillGachaConfirmBtnRect = { x = confirmX, y = confirmY, w = confirmW, h = confirmH }
end


--- 绘制单个武技结果卡片
---@param cx number 卡片中心X
---@param cy number 卡片顶部Y
---@param r table 结果数据
---@param isBig boolean 是否大卡
function DrawSkillResultCard(cx, cy, r, isBig)
    local tierData = SKILL_TIERS[r.tier] or SKILL_TIERS[1]
    local tc = tierData.color

    local cardW = isBig and 180 or 88
    local cardH = isBig and 240 or 115
    local cardX = cx - cardW / 2
    local cardY = cy

    -- 整卡外发光
    if r.isFullCard then
        local glowR = isBig and 8 or 5
        local glowGrad = nvgLinearGradient(vg, cardX - glowR, cardY - glowR,
            cardX + cardW + glowR, cardY + cardH + glowR,
            nvgRGBA(tc[1], tc[2], tc[3], 120), nvgRGBA(tc[1], tc[2], tc[3], 60))
        nvgBeginPath(vg); nvgRoundedRect(vg, cardX - glowR, cardY - glowR,
            cardW + glowR * 2, cardH + glowR * 2, 8)
        nvgFillPaint(vg, glowGrad); nvgFill(vg)
    end

    -- 卡片底色
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, cardW, cardH, 6)
    local bgGrad = nvgLinearGradient(vg, cardX, cardY, cardX, cardY + cardH,
        nvgRGBA(tc[1], tc[2], tc[3], 50), nvgRGBA(20, 15, 30, 200))
    nvgFillPaint(vg, bgGrad); nvgFill(vg)
    local strokeAlpha = r.isFullCard and 240 or 140
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], strokeAlpha))
    nvgStrokeWidth(vg, r.isFullCard and 2.0 or 1.0); nvgStroke(vg)

    -- 武技图标区 (使用武技icon精灵图)
    local iconH = isBig and 120 or 52
    local iconW = cardW - 6
    local iconX = cardX + 3
    local iconY = cardY + 3
    -- 品质底色
    nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconW, iconH, 4)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 40)); nvgFill(vg)
    -- 使用 drawSkillIcon 渲染武技图标
    local skillData = SKILL_TECHNIQUES and SKILL_TECHNIQUES[r.skillIdx]
    local sheetIconIdx = skillData and skillData.iconIdx
    local iconDrawn = false
    if sheetIconIdx and drawSkillIcon then
        local iconSize = math.min(iconW, iconH)
        local iconDrawX = iconX + (iconW - iconSize) / 2
        local iconDrawY = iconY + (iconH - iconSize) / 2
        drawSkillIcon(sheetIconIdx, iconDrawX, iconDrawY, iconSize, 4)
        iconDrawn = IMG.skillIconSheet >= 0 and SKILL_ICON_BBOX[sheetIconIdx] ~= nil
    end
    if not iconDrawn then
        -- fallback: 显示武技名首字
        nvgFontSize(vg, isBig and 48 or 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180))
        nvgText(vg, cx, iconY + iconH / 2, string.sub(r.name or "?", 1, 3), nil)
    end

    -- 品质标签 (左上角)
    local tagFontSz = isBig and 14 or 10
    local qTagW = isBig and 40 or 26
    local qTagH = isBig and 18 or 13
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, qTagW, qTagH, 4)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180)); nvgFill(vg)
    nvgFontSize(vg, tagFontSz)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
    nvgText(vg, cardX + 3, cardY + 2, tierData.name, nil)

    -- 整卡/碎片标识 (右上角)
    local typeFontSz = isBig and 13 or 9
    local typeTagW = isBig and 38 or 26
    local typeTagH = isBig and 18 or 13
    nvgBeginPath(vg); nvgRoundedRect(vg, cardX + cardW - typeTagW, cardY, typeTagW, typeTagH, 4)
    if r.isFullCard then
        nvgFillColor(vg, nvgRGBA(200, 120, 255, 200)); nvgFill(vg)
        nvgFontSize(vg, typeFontSz)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
        nvgText(vg, cardX + cardW - typeTagW / 2, cardY + typeTagH / 2, "整卡", nil)
    else
        nvgFillColor(vg, nvgRGBA(80, 80, 140, 200)); nvgFill(vg)
        nvgFontSize(vg, typeFontSz)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 210, 255, 240))
        nvgText(vg, cardX + cardW - typeTagW / 2, cardY + typeTagH / 2, "碎片", nil)
    end

    -- 武技名
    local infoY = cardY + iconH + (isBig and 8 or 4)
    local nameSize = isBig and 22 or 12
    nvgFontSize(vg, nameSize)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 255))
    nvgText(vg, cx, infoY, r.name, nil)
    infoY = infoY + (isBig and 20 or 12)

    -- 状态标签
    local statusFontSz = isBig and 18 or 10
    nvgFontSize(vg, statusFontSz)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local totalFrag = skillFragments[r.skillIdx] or 0
    local needFrag = SKILL_FRAG_EXCHANGE or 20
    if r.isFullCard then
        nvgFillColor(vg, nvgRGBA(255, 220, 120, 230))
        nvgText(vg, cx, infoY, "×" .. (r.fragCount or 0) .. " (" .. totalFrag .. "/" .. needFrag .. ")", nil)
    else
        nvgFillColor(vg, nvgRGBA(180, 200, 255, 230))
        nvgText(vg, cx, infoY, "×" .. (r.fragCount or 0) .. " (" .. totalFrag .. "/" .. needFrag .. ")", nil)
    end
end


-- ============================================================================
-- 武技召唤 - 概率规则弹窗
-- ============================================================================
function DrawSkillGachaRulesPopup()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 110)); nvgFill(vg)

    local panelW = W * 0.84
    local panelH = 520
    local panelX = cx - panelW / 2
    local panelY = H / 2 - panelH / 2

    local panelGrad = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + panelH,
        nvgRGBA(45, 25, 60, 240), nvgRGBA(35, 20, 50, 245))
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgFillPaint(vg, panelGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgStrokeColor(vg, nvgRGBA(200, 140, 255, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    local titleY = panelY + 28
    nvgFontSize(vg, 35)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, titleY, "武技召唤规则")

    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, titleY + 18)
    nvgLineTo(vg, panelX + panelW - 20, titleY + 18)
    nvgStrokeColor(vg, nvgRGBA(200, 140, 255, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local lineH = 26
    local startY = titleY + 38
    local leftX = panelX + 24

    nvgFontSize(vg, 25)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftX, startY, "武技品阶概率")
    startY = startY + lineH

    local probs = {
        { name = "凡品(N)",  prob = "40%",  tier = 1 },
        { name = "良品+优品(R)", prob = "29%", tier = 2 },
        { name = "将品+侯品(SR)", prob = "20%", tier = 4 },
        { name = "王品(SSR)",  prob = "10%",  tier = 6 },
        { name = "帝品(限定)", prob = "1%",   tier = 7 },
    }
    nvgFontSize(vg, 18)
    for _, p in ipairs(probs) do
        local td = SKILL_TIERS[p.tier] or SKILL_TIERS[1]
        local c = td.color
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 220))
        nvgText(vg, leftX + 10, startY, "· " .. p.name .. ": " .. p.prob, nil)
        startY = startY + lineH * 0.7
    end
    startY = startY + 8

    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, startY)
    nvgLineTo(vg, panelX + panelW - 20, startY)
    nvgStrokeColor(vg, nvgRGBA(200, 140, 255, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    startY = startY + 12

    nvgFontSize(vg, 25)
    DrawWhiteInkText(leftX, startY, "规则说明")
    startY = startY + lineH

    nvgFontSize(vg, 19)
    DrawWhiteInkText(leftX + 10, startY, "· 单抽 " .. SEAL_GACHA_COST .. " 玉壁, 十连及以上享9折")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 普通抽取获得武技碎片")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 碎片达标(" .. (SKILL_FRAG_EXCHANGE or 20) .. "个)可合成武技")
    startY = startY + lineH * 0.75
    local pityN = SKILL_GACHA_PITY_THRESHOLD or 70
    DrawWhiteInkText(leftX + 10, startY, "· 每 " .. pityN .. " 抽大保底必出王品+整卡")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 保底触发后计数器重置为0")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 满层(Lv5)武技再获得返还玉壁")

    local closeBtnW = 120
    local closeBtnH = 36
    local closeBtnX = cx - closeBtnW / 2
    local closeBtnY = panelY + panelH - closeBtnH - 14
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(45, 30, 60, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 140, 255, 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, closeBtnY + closeBtnH / 2, "知道了")
    skillGachaRulesCloseBtnRect = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }
end
