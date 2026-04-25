-- ============================================================================
-- ui/seal_gacha.lua - 三国武灵录 (兵符召唤: 动画/结果/规则)
-- ============================================================================


--- 武技召唤专属规则弹窗（显示阶级概率 + 75抽保底）
-- ============================================================================
-- 兵符召唤 - 待机界面
-- ============================================================================
function DrawSealGachaIdle(t, contentTop, contentBottom)
    local W = DESIGN_W
    local cx = W / 2
    -- 内容区高度
    local areaH = contentBottom - contentTop
    -- 召唤阵居内容区上部 30% 处
    local circleY = contentTop + areaH * 0.30
    local circleR = 90

    nvgFontFaceId(vg, GetMainFont())

    -- 召唤阵: 六芒兵符旋转 (六德主题)
    for i = 1, 6 do
        local angle = (i / 6) * math.pi * 2 + t * 0.5
        local r = circleR + 6 + 4 * math.sin(t * 1.8 + i)
        -- 六角星点
        local px = cx + math.cos(angle) * r
        local py = circleY + math.sin(angle) * r
        local dotR = 3 + math.sin(t * 2.5 + i * 1.2) * 1.5
        nvgBeginPath(vg); nvgCircle(vg, px, py, dotR)
        local pulse = 0.5 + 0.5 * math.sin(t * 2 + i * 0.9)
        nvgFillColor(vg, nvgRGBA(200, 100, 255, math.floor(160 * pulse))); nvgFill(vg)
        -- 连线到下一点
        local nextAngle = ((i % 6) + 1) / 6 * math.pi * 2 + t * 0.5
        local nr = circleR + 6 + 4 * math.sin(t * 1.8 + (i % 6 + 1))
        local nx = cx + math.cos(nextAngle) * nr
        local ny = circleY + math.sin(nextAngle) * nr
        nvgBeginPath(vg)
        nvgMoveTo(vg, px, py); nvgLineTo(vg, nx, ny)
        nvgStrokeColor(vg, nvgRGBA(160, 80, 220, math.floor(60 * pulse)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end

    -- 内旋转弧
    for i = 1, 8 do
        local angle = -(i / 8) * math.pi * 2 + t * 0.9
        local arcLen = math.pi / 7
        nvgBeginPath(vg)
        nvgArc(vg, cx, circleY, circleR - 8, angle, angle + arcLen, NVG_CW)
        local pulse = 0.3 + 0.7 * math.sin(t * 2 + i * 0.7)
        nvgStrokeColor(vg, nvgRGBA(180, 130, 255, math.floor(70 * pulse)))
        nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
    end

    -- 中心光晕 (紫色调)
    local glowPulse = 0.5 + 0.5 * math.sin(t * 1.6)
    local glow = nvgRadialGradient(vg, cx, circleY, 5, circleR * 0.7,
        nvgRGBA(160, 80, 220, math.floor(50 * glowPulse)),
        nvgRGBA(100, 50, 180, 0))
    nvgBeginPath(vg); nvgCircle(vg, cx, circleY, circleR * 0.7)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 中心文字
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local textPulse = 0.6 + 0.4 * math.sin(t * 1.5)
    nvgFillColor(vg, nvgRGBA(200, 140, 255, math.floor(200 * textPulse)))
    nvgText(vg, cx, circleY, "咒 印 铭 刻", nil)

    nvgFontSize(vg, 22)
    DrawWhiteInkText(cx, circleY + areaH * 0.055, "满命武灵专属强化")

    -- 满命武灵数量提示
    local maxHeroes = GetMaxConstellationHeroes()
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, circleY + areaH * 0.09, "可铭刻武灵: " .. #maxHeroes .. " 位")

    -- ===========================
    -- 抽卡按钮
    -- ===========================
    local bigPull = playerInfo.jadeUnlockedBigPull
    gachaHundredBtnRect = nil

    -- 底部辅助按钮区: 锚定距底边 areaH*0.02
    local auxBtnH = areaH * 0.07
    local auxBtnY = contentBottom - areaH * 0.02 - auxBtnH

    if bigPull then
        -- 增强模式: 3个按钮 (10连/50连/100连) 紫色调
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
        local unitCost = SEAL_GACHA_COST

        -- 10连
        local b1x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b1x, btnY1, btnW, btnH, 6)
        nvgFillColor(vg, nvgRGBA(35, 20, 50, 200)); nvgFill(vg)
        local bp1 = 0.7 + 0.3 * math.sin(t * 2)
        nvgStrokeColor(vg, nvgRGBA(180, 100, 220, math.floor(180 * bp1)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 - 6, "十 连 铭 刻")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 + 10, math.floor(unitCost * 10 * 0.9) .. " 玉壁 (9折)")
        gachaSingleBtnRect = { x = b1x, y = btnY1, w = btnW, h = btnH }

        -- 50连
        local b2x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        local g50 = nvgLinearGradient(vg, b2x, btnY2, b2x + btnW, btnY2 + btnH,
            nvgRGBA(45, 20, 65, 220), nvgRGBA(60, 25, 80, 220))
        nvgFillPaint(vg, g50); nvgFill(vg)
        local bp2 = 0.6 + 0.4 * math.sin(t * 2.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(220, 140, 255, math.floor(200 * bp2)))
        nvgStrokeWidth(vg, 1.8); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 - 6, "五十连铭刻")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 + 10, math.floor(unitCost * 50 * 0.9) .. " 玉壁 (9折)")
        gachaTenBtnRect = { x = b2x, y = btnY2, w = btnW, h = btnH }

        -- 100连
        local b3x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b3x, btnY3, btnW, btnH, 6)
        local g100 = nvgLinearGradient(vg, b3x, btnY3, b3x + btnW, btnY3 + btnH,
            nvgRGBA(55, 15, 80, 230), nvgRGBA(70, 10, 90, 230))
        nvgFillPaint(vg, g100); nvgFill(vg)
        local bp3 = 0.5 + 0.5 * math.sin(t * 3)
        nvgBeginPath(vg); nvgRoundedRect(vg, b3x, btnY3, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(255, 180, 255, math.floor(220 * bp3)))
        nvgStrokeWidth(vg, 2.0); nvgStroke(vg)
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY3 + btnH / 2 - 6, "百 连 铭 刻")
        nvgFontSize(vg, 16)
        DrawWhiteInkText(cx, btnY3 + btnH / 2 + 10, math.floor(unitCost * 100 * 0.9) .. " 玉壁 (9折)")
        gachaHundredBtnRect = { x = b3x, y = btnY3, w = btnW, h = btnH }
    else
        -- 原始模式: 2个按钮 (单抽/十连)
        local btnW = W * 0.156
        local btnH = areaH * 0.10
        local btnGap = areaH * 0.02
        local totalBtnH = btnH * 2 + btnGap
        local btnZoneTop = circleY + areaH * 0.12
        local btnZoneBottom = auxBtnY - areaH * 0.06
        local btnY1 = btnZoneTop + math.max(0, (btnZoneBottom - btnZoneTop - totalBtnH) / 2)
        local btnY2 = btnY1 + btnH + btnGap

        -- 单抽按钮
        local b1x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b1x, btnY1, btnW, btnH, 6)
        nvgFillColor(vg, nvgRGBA(35, 20, 50, 200)); nvgFill(vg)
        local borderPulse1 = 0.7 + 0.3 * math.sin(t * 2)
        nvgStrokeColor(vg, nvgRGBA(180, 100, 220, math.floor(180 * borderPulse1)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 - 8, "单 抽")
        nvgFontSize(vg, 18)
        DrawWhiteInkText(cx, btnY1 + btnH / 2 + 12, SEAL_GACHA_COST .. " 玉壁")
        gachaSingleBtnRect = { x = b1x, y = btnY1, w = btnW, h = btnH }

        -- 十连按钮
        local b2x = cx - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        local tenGrad = nvgLinearGradient(vg, b2x, btnY2, b2x + btnW, btnY2 + btnH,
            nvgRGBA(45, 20, 65, 220), nvgRGBA(60, 25, 80, 220))
        nvgFillPaint(vg, tenGrad); nvgFill(vg)
        local borderPulse2 = 0.6 + 0.4 * math.sin(t * 2.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, b2x, btnY2, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(220, 140, 255, math.floor(200 * borderPulse2)))
        nvgStrokeWidth(vg, 1.8); nvgStroke(vg)
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 - 8, "十 连 铭 刻")
        nvgFontSize(vg, 18)
        DrawWhiteInkText(cx, btnY2 + btnH / 2 + 12, SEAL_GACHA_TEN_COST .. " 玉壁 (9折)")
        gachaTenBtnRect = { x = b2x, y = btnY2, w = btnW, h = btnH }
    end

    -- 计算最后一个按钮底部Y (兼容增强模式3按钮)
    local lastBtnBottom = gachaHundredBtnRect and (gachaHundredBtnRect.y + gachaHundredBtnRect.h) or (gachaTenBtnRect.y + gachaTenBtnRect.h)

    -- 兵符持有概览
    local totalSeals = 0
    local totalSlots = 0
    for cardIdx, sd in pairs(sealData) do
        for s = 1, SEAL_MAX_SLOTS do
            if sd.slots[s] then
                totalSeals = totalSeals + 1
                totalSlots = totalSlots + 1
            end
        end
    end
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, lastBtnBottom + areaH * 0.02, "已开启兵符孔: " .. totalSeals)

    -- 经验道具概览
    local expText = ""
    for idx, item in ipairs(SEAL_EXP_ITEMS) do
        local cnt = sealExpItems[idx] or 0
        if cnt > 0 then
            if #expText > 0 then expText = expText .. "  " end
            expText = expText .. item.name .. "×" .. cnt
        end
    end
    if #expText > 0 then
        nvgFontSize(vg, 20)
        DrawWhiteInkText(cx, lastBtnBottom + areaH * 0.045, expText)
    end

    -- "?" 概率规则按钮 (右下角) — 锚定: 与兵符管理同行
    local qBtnSize = areaH * 0.06
    local qBtnX = W - qBtnSize - W * 0.012
    local qBtnY = auxBtnY + (auxBtnH - qBtnSize) / 2
    nvgBeginPath(vg); nvgCircle(vg, qBtnX + qBtnSize / 2, qBtnY + qBtnSize / 2, qBtnSize / 2)
    nvgFillColor(vg, nvgRGBA(50, 30, 65, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 120, 220, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(qBtnX + qBtnSize / 2, qBtnY + qBtnSize / 2, "?")
    gachaRulesBtnRect = { x = qBtnX, y = qBtnY, w = qBtnSize, h = qBtnSize }

    -- 兵符管理入口按钮（左下角）— 锚定: 与 "?" 同行
    local mgrBtnW = W * 0.088
    local mgrBtnH = auxBtnH
    local mgrBtnX = W * 0.012
    local mgrBtnY = auxBtnY
    nvgBeginPath(vg); nvgRoundedRect(vg, mgrBtnX, mgrBtnY, mgrBtnW, mgrBtnH, 6)
    nvgFillColor(vg, nvgRGBA(35, 30, 50, 210)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 100, 220, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(mgrBtnX + mgrBtnW / 2, mgrBtnY + mgrBtnH / 2, "兵符管理")
    sealMgrBtnRect = { x = mgrBtnX, y = mgrBtnY, w = mgrBtnW, h = mgrBtnH }
end


-- ============================================================================
-- 兵符召唤 - 抽卡动画
-- ============================================================================
function DrawSealGachaPullAnimation(t)
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local cy = H * 0.40
    local progress = math.min(1, sealGachaState.pullTimer / 1.2)

    -- 紫色扩散光圈
    local maxR = 120
    local r = maxR * progress
    local glow = nvgRadialGradient(vg, cx, cy, r * 0.3, r,
        nvgRGBA(200, 120, 255, math.floor(120 * (1 - progress * 0.5))),
        nvgRGBA(140, 60, 200, 0))
    nvgBeginPath(vg); nvgCircle(vg, cx, cy, r)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 旋转咒纹光线
    local lineCount = sealGachaState.pullCount == 10 and 20 or 8
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

    -- 提示文字
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, H * 0.72, "点击跳过")
end


-- ============================================================================
-- 兵符召唤 - 结果展示
-- ============================================================================
function DrawSealGachaResults()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local results = sealGachaState.results
    local count = #results

    -- 半透明全屏遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    nvgFontSize(vg, 33)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 65, "铭刻结果")

    if count == 0 then return end

    if count == 1 then
        -- 单抽: 大卡居中
        local r = results[1]
        local cardY = H * 0.25
        DrawSealResultCard(cx, cardY, r, true)
    else
        -- 按品质降序排序（高品质排前面，兵符优先于经验道具）
        table.sort(results, function(a, b)
            -- 兵符(seal/seal_dupe)排在经验道具(exp_item)前面
            local typeOrder = { seal = 3, seal_dupe = 2, exp_item = 1 }
            local ta = typeOrder[a.type] or 0
            local tb = typeOrder[b.type] or 0
            if ta ~= tb then return ta > tb end
            -- 同类型按品质降序
            local qa = a.sealQ or 0
            local qb = b.sealQ or 0
            return qa > qb
        end)
        -- 十连: 5列×2行 网格
        local cols = 5
        local cardW = 80
        local cardH = 90
        local gap = 8
        local gridW = cols * cardW + (cols - 1) * gap
        local startX = cx - gridW / 2
        local startY = 90

        for i, r in ipairs(results) do
            local col = ((i - 1) % cols)
            local row = math.floor((i - 1) / cols)
            local x = startX + col * (cardW + gap) + cardW / 2
            local y = startY + row * (cardH + 30 + gap)
            DrawSealResultCard(x, y, r, false)
        end
    end

    -- 确认按钮
    local confirmW = 140
    local confirmH = 38
    local confirmX = cx - confirmW / 2
    local confirmY = H * 0.88
    nvgBeginPath(vg)
    nvgRoundedRect(vg, confirmX, confirmY, confirmW, confirmH, 5)
    nvgFillColor(vg, nvgRGBA(35, 20, 50, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 120, 220, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, confirmY + confirmH / 2, "确 认")
    gachaConfirmBtnRect = { x = confirmX, y = confirmY, w = confirmW, h = confirmH }
end


--- 绘制单个兵符结果卡片
--- @param cx number 卡片中心X
--- @param cy number 卡片顶部Y
--- @param r table 结果数据
--- @param isBig boolean 是否大卡
function DrawSealResultCard(cx, cy, r, isBig)
    local fontSize = isBig and 25 or 14
    local nameSize = isBig and 28 or 16
    local tagY = cy

    if r.type == "seal" then
        -- 兵符: 新开孔
        local qc = SEAL_QUALITY_COLORS[r.sealQ] or { 180, 175, 165 }
        local qName = SEAL_QUALITY_NAMES[r.sealQ] or "?"

        -- 兵符图标 (六边形)
        local iconR = isBig and 40 or 22
        DrawSealHexIcon(cx, tagY + iconR + 5, iconR, qc, r.sealQ)

        tagY = tagY + iconR * 2 + 14

        nvgFontSize(vg, nameSize)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 240))
        nvgText(vg, cx, tagY, r.slotName .. "兵符", nil)
        tagY = tagY + (isBig and 24 or 16)

        nvgFontSize(vg, fontSize)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
        nvgText(vg, cx, tagY, r.heroName, nil)
        tagY = tagY + (isBig and 22 or 14)

        nvgFontSize(vg, fontSize - 2)
        nvgFillColor(vg, nvgRGBA(120, 255, 160, 220))
        nvgText(vg, cx, tagY, "新!", nil)

    elseif r.type == "seal_dupe" then
        -- 重复兵符: 返还玉壁
        local qc = SEAL_QUALITY_COLORS[r.sealQ] or { 180, 175, 165 }

        local iconR = isBig and 40 or 22
        DrawSealHexIcon(cx, tagY + iconR + 5, iconR, qc, r.sealQ)
        tagY = tagY + iconR * 2 + 14

        nvgFontSize(vg, nameSize)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 180))
        nvgText(vg, cx, tagY, r.heroName, nil)
        tagY = tagY + (isBig and 24 or 16)

        nvgFontSize(vg, fontSize)
        nvgFillColor(vg, nvgRGBA(255, 215, 0, 220))
        nvgText(vg, cx, tagY, "重复 +" .. r.refund .. " 玉壁", nil)

    elseif r.type == "exp_item" then
        -- 经验道具 (正式图片渲染)
        local itemIdx = r.itemIdx
        local itemColors = {
            [1] = { 180, 200, 220 },  -- 微光: 浅蓝
            [2] = { 140, 160, 200 },  -- 幽暗: 灰蓝
            [3] = { 160, 100, 220 },  -- 讨伐: 紫
            [4] = { 80, 50, 120 },    -- 虚无: 暗紫
        }
        local ic = itemColors[itemIdx] or { 180, 180, 180 }

        -- 经验道具图标 (使用图片)
        local iconSize = isBig and 64 or 36
        local imgHandle = sealExpItemImages[itemIdx]
        if imgHandle and imgHandle > 0 then
            local imgPat = nvgImagePattern(vg, cx - iconSize / 2, tagY + 5, iconSize, iconSize, 0, imgHandle, 1.0)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx - iconSize / 2, tagY + 5, iconSize, iconSize, 6)
            nvgFillPaint(vg, imgPat); nvgFill(vg)
            -- 品质边框光晕
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx - iconSize / 2, tagY + 5, iconSize, iconSize, 6)
            nvgStrokeColor(vg, nvgRGBA(ic[1], ic[2], ic[3], 160))
            nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        else
            -- 图片未加载时的回退: 圆形
            local iconR = isBig and 32 or 18
            nvgBeginPath(vg); nvgCircle(vg, cx, tagY + iconR + 5, iconR)
            local igr = nvgRadialGradient(vg, cx, tagY + iconR + 5, 3, iconR,
                nvgRGBA(ic[1], ic[2], ic[3], 200), nvgRGBA(ic[1] * 0.5, ic[2] * 0.5, ic[3] * 0.5, 150))
            nvgFillPaint(vg, igr); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(ic[1], ic[2], ic[3], 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, isBig and 18 or 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
            nvgText(vg, cx, tagY + iconR + 5, "墨", nil)
        end

        tagY = tagY + iconSize + 14

        nvgFontSize(vg, nameSize)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(ic[1], ic[2], ic[3], 240))
        nvgText(vg, cx, tagY, r.itemName, nil)
        tagY = tagY + (isBig and 22 or 14)

        nvgFontSize(vg, fontSize)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
        nvgText(vg, cx, tagY, "EXP +" .. r.itemExp, nil)
    end
end


--- 绘制六边形兵符图标
function DrawSealHexIcon(cx, cy, r, color, quality)
    nvgBeginPath(vg)
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 2
        local px = cx + math.cos(angle) * r
        local py = cy + math.sin(angle) * r
        if i == 0 then
            nvgMoveTo(vg, px, py)
        else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    local gr = nvgRadialGradient(vg, cx, cy, 2, r,
        nvgRGBA(color[1], color[2], color[3], 160),
        nvgRGBA(color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 100))
    nvgFillPaint(vg, gr); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(color[1], color[2], color[3], 200))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 品质文字 (上半区, 避免与 Lv 文字重叠)
    local qName = SEAL_QUALITY_NAMES[quality] or "?"
    nvgFontSize(vg, math.max(9, r * 0.38))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgText(vg, cx, cy - r * 0.32, qName, nil)
end


-- ============================================================================
-- 兵符召唤 - 概率规则弹窗
-- ============================================================================
function DrawSealGachaRulesPopup()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 110)); nvgFill(vg)

    -- 弹窗面板
    local panelW = W * 0.84
    local panelH = 1380
    local panelX = cx - panelW / 2
    local panelY = H / 2 - panelH / 2 - 10

    -- 面板背景（暗紫色调）
    local panelGrad = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + panelH,
        nvgRGBA(50, 25, 65, 240), nvgRGBA(35, 18, 50, 245))
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgFillPaint(vg, panelGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 10)
    nvgStrokeColor(vg, nvgRGBA(180, 100, 255, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    local titleY = panelY + 28
    nvgFontSize(vg, 35)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, titleY, "兵符铭刻规则")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, titleY + 18)
    nvgLineTo(vg, panelX + panelW - 20, titleY + 18)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 220, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local lineH = 26
    local startY = titleY + 38
    local leftX = panelX + 24

    -- 解锁条件
    nvgFontSize(vg, 25)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftX, startY, "解锁条件")
    startY = startY + lineH
    nvgFontSize(vg, 19)
    DrawWhiteInkText(leftX + 10, startY, "· 拥有至少 1 个满命格(C6)武灵")
    startY = startY + lineH * 0.9

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, startY)
    nvgLineTo(vg, panelX + panelW - 20, startY)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 220, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    startY = startY + 12

    -- 产出概率
    nvgFontSize(vg, 25)
    DrawWhiteInkText(leftX, startY, "产出概率")
    startY = startY + lineH

    nvgFontSize(vg, 19)
    nvgFillColor(vg, nvgRGBA(200, 140, 255, 220))
    nvgText(vg, leftX + 10, startY, "· 兵符(开孔): 60%", nil)
    startY = startY + lineH * 0.8
    nvgFillColor(vg, nvgRGBA(180, 200, 220, 220))
    nvgText(vg, leftX + 10, startY, "· 兵符经验道具: 40%", nil)
    startY = startY + lineH * 0.9

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, startY)
    nvgLineTo(vg, panelX + panelW - 20, startY)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 220, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    startY = startY + 12

    -- 兵符等阶概率 (与装备相同)
    nvgFontSize(vg, 25)
    DrawWhiteInkText(leftX, startY, "兵符等阶 (无保底)")
    startY = startY + lineH

    local tierProbs = {
        { name = "凡品",   prob = "52.5%", color = SEAL_QUALITY_COLORS[1] },
        { name = "良品",   prob = "25%",   color = SEAL_QUALITY_COLORS[2] },
        { name = "优品",   prob = "15%",   color = SEAL_QUALITY_COLORS[3] },
        { name = "将品", prob = "5%",    color = SEAL_QUALITY_COLORS[4] },
        { name = "王品", prob = "2%",    color = SEAL_QUALITY_COLORS[5] },
        { name = "帝品", prob = "0.5%",  color = SEAL_QUALITY_COLORS[6] },
    }
    nvgFontSize(vg, 18)
    for _, tp in ipairs(tierProbs) do
        local c = tp.color
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 220))
        nvgText(vg, leftX + 10, startY, "· " .. tp.name .. ": " .. tp.prob, nil)
        startY = startY + lineH * 0.7
    end
    startY = startY + 4

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, startY)
    nvgLineTo(vg, panelX + panelW - 20, startY)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 220, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    startY = startY + 12

    -- 兵符说明
    nvgFontSize(vg, 25)
    DrawWhiteInkText(leftX, startY, "兵符系统")
    startY = startY + lineH

    nvgFontSize(vg, 19)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftX + 10, startY, "· 兵符独特绑定特定武灵")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 每位武灵最多开 " .. SEAL_MAX_SLOTS .. " 孔(六德)")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 可消耗咒墨强化至 Lv." .. SEAL_MAX_LEVEL)
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 强化难度大, 但提升显著")
    startY = startY + lineH * 0.9

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, startY)
    nvgLineTo(vg, panelX + panelW - 20, startY)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 220, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    startY = startY + 12

    -- 六德效果详解
    nvgFontSize(vg, 25)
    DrawWhiteInkText(leftX, startY, "六德孔位详解")
    startY = startY + lineH

    local qualityNames = { "凡", "良", "优", "将", "侯", "王", "帝" }
    nvgFontSize(vg, 24)
    for si = 1, 6 do
        local eff = SEAL_SLOT_EFFECTS[si]
        local stc = SEAL_SLOT_THEME_COLORS[si]
        if eff and stc then
            -- 孔位名称 + 主题
            nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], 240))
            nvgFontSize(vg, 18)
            nvgText(vg, leftX + 10, startY, "· " .. SEAL_SLOT_NAMES[si] .. " - " .. eff.theme, nil)
            startY = startY + lineH * 0.7
            -- 效果描述
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(210, 190, 230, 210))
            nvgText(vg, leftX + 18, startY, eff.desc, nil)
            startY = startY + lineH * 0.65
            -- 属性数值范围
            nvgFillColor(vg, nvgRGBA(200, 200, 180, 200))
            if eff.mainName then
                local v1 = eff[1] and eff[1].main or 0
                local v7 = eff[7] and eff[7].main or 0
                local unitStr = (eff.mainKey == "critRate") and "%" or ""
                local mainLine = eff.mainName .. "  " .. qualityNames[1] .. "+" .. string.format("%.1f", v1) .. unitStr
                    .. " → " .. qualityNames[7] .. "+" .. string.format("%.1f", v7) .. unitStr .. " (每级)"
                nvgText(vg, leftX + 18, startY, mainLine, nil)
                startY = startY + lineH * 0.6
            end
            startY = startY + 4
            nvgFontSize(vg, 24)
        end
    end
    startY = startY + 4

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, startY)
    nvgLineTo(vg, panelX + panelW - 20, startY)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 220, 50)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    startY = startY + 12

    -- 重复兵符 & 费用
    nvgFontSize(vg, 25)
    DrawWhiteInkText(leftX, startY, "重复兵符 & 费用")
    startY = startY + lineH

    nvgFontSize(vg, 19)
    DrawWhiteInkText(leftX + 10, startY, "· 已满 " .. SEAL_MAX_SLOTS .. " 孔再抽到兵符 → 返还 " .. SEAL_DUPE_REFUND .. " 玉壁")
    startY = startY + lineH * 0.75
    DrawWhiteInkText(leftX + 10, startY, "· 单抽 " .. SEAL_GACHA_COST .. " 玉壁 / 十连 " .. SEAL_GACHA_TEN_COST .. " 玉壁(9折)")

    -- 关闭按钮
    local closeBtnW = 120
    local closeBtnH = 36
    local closeBtnX = cx - closeBtnW / 2
    local closeBtnY = panelY + panelH - closeBtnH - 14
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(50, 30, 65, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 140, 255, 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 29)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, closeBtnY + closeBtnH / 2, "知道了")
    gachaRulesCloseBtnRect = { x = closeBtnX, y = closeBtnY, w = closeBtnW, h = closeBtnH }
end


