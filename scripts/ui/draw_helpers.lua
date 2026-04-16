-- ============================================================================
-- ui/draw_helpers.lua - 三国武灵录
-- ============================================================================


--- 绘制武技图标 (按实际像素边界裁切，统一居中)
--- @param iconIdx number 图标索引 1-36
--- @param drawX number 绘制区域左上角X
--- @param drawY number 绘制区域左上角Y
--- @param drawSize number 绘制区域边长(正方形)
--- @param radius number 圆角半径
function drawSkillIcon(iconIdx, drawX, drawY, drawSize, radius)
    if IMG.skillIconSheet < 0 then return end
    local bbox = SKILL_ICON_BBOX[iconIdx]
    if not bbox then return end

    local imgW, imgH = nvgImageSize(vg, IMG.skillIconSheet)
    local cellW = imgW / SKILL_ICON_COLS
    local cellH = imgH / SKILL_ICON_ROWS

    local row = math.floor((iconIdx - 1) / SKILL_ICON_COLS)
    local col = (iconIdx - 1) % SKILL_ICON_COLS

    -- bbox 值基于原始 1500×1500 图片 (单元格 250×250), 需按实际尺寸缩放
    local bboxScale = cellW / 250
    local srcX = col * cellW + bbox.bx * bboxScale
    local srcY = row * cellH + bbox.by * bboxScale
    local srcW = bbox.bw * bboxScale
    local srcH = bbox.bh * bboxScale

    -- 等比缩放让内容 fit 进 drawSize，并居中
    local contentScale = math.min(drawSize / srcW, drawSize / srcH)
    local scaledW = srcW * contentScale
    local scaledH = srcH * contentScale
    local centeredX = drawX + (drawSize - scaledW) / 2
    local centeredY = drawY + (drawSize - scaledH) / 2

    -- nvgImagePattern 需要整张精灵图的缩放和偏移
    local patScale = contentScale
    local patX = centeredX - srcX * patScale
    local patY = centeredY - srcY * patScale

    local pat = nvgImagePattern(vg, patX, patY, imgW * patScale, imgH * patScale, 0, IMG.skillIconSheet, 1.0)
    nvgBeginPath(vg); nvgRoundedRect(vg, drawX, drawY, drawSize, drawSize, radius)
    nvgFillPaint(vg, pat); nvgFill(vg)
end


--- 绘制万能残片图标（程序化绘制，彩虹棱形残片）
function drawUniversalFragIcon(drawX, drawY, drawSize, radius)
    local cx = drawX + drawSize / 2
    local cy = drawY + drawSize / 2
    local r = drawSize * 0.38

    -- 背景圆
    nvgBeginPath(vg); nvgRoundedRect(vg, drawX, drawY, drawSize, drawSize, radius)
    nvgFillColor(vg, nvgRGBA(40, 20, 60, 220)); nvgFill(vg)

    -- 外圈光晕
    local glow = nvgRadialGradient(vg, cx, cy, r * 0.3, r * 1.4,
        nvgRGBA(200, 160, 255, 100), nvgRGBA(200, 160, 255, 0))
    nvgBeginPath(vg); nvgCircle(vg, cx, cy, r * 1.4)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 菱形残片主体（彩虹渐变效果）
    local t = time:GetElapsedTime() * 1.5
    local hueShift = math.sin(t) * 30

    -- 上半菱形
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - r)        -- 顶点
    nvgLineTo(vg, cx + r * 0.7, cy)  -- 右
    nvgLineTo(vg, cx, cy + r * 0.2)  -- 中偏下
    nvgLineTo(vg, cx - r * 0.7, cy)  -- 左
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(
        math.floor(180 + 60 * math.sin(t)),
        math.floor(140 + 80 * math.sin(t + 2)),
        math.floor(220 + 35 * math.sin(t + 4)), 230))
    nvgFill(vg)

    -- 下半菱形（略暗）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - r * 0.7, cy)  -- 左
    nvgLineTo(vg, cx, cy + r)        -- 底
    nvgLineTo(vg, cx + r * 0.7, cy)  -- 右
    nvgLineTo(vg, cx, cy + r * 0.2)  -- 中偏下
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(
        math.floor(140 + 50 * math.sin(t + 1)),
        math.floor(100 + 60 * math.sin(t + 3)),
        math.floor(190 + 40 * math.sin(t + 5)), 220))
    nvgFill(vg)

    -- 中心高光
    nvgBeginPath(vg); nvgCircle(vg, cx, cy - r * 0.15, r * 0.18)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 160)); nvgFill(vg)

    -- 边框描边
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - r)
    nvgLineTo(vg, cx + r * 0.7, cy)
    nvgLineTo(vg, cx, cy + r)
    nvgLineTo(vg, cx - r * 0.7, cy)
    nvgClosePath(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 230, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
end


-- 绘制红点 (带白描边的小红圆)
function DrawRedDot(rx, ry, rr)
    rr = rr or 6
    nvgBeginPath(vg)
    nvgCircle(vg, rx, ry, rr)
    nvgFillColor(vg, nvgRGBA(255, 45, 45, 235))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)
end


-- ============================================================================
-- 墨字辅助: 黑色毛笔字 + 轻微白色描边
-- ============================================================================
--- 绘制墨字风格文本 (使用前需已设好 nvgFontSize/nvgTextAlign/nvgFontFaceId)
function DrawInkText(x, y, text)
    -- 轻微白色描边 (4方向偏移1px) — 使用原始函数避免双重描边
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 130))
    _nvgTextOrig(vg, x - 1, y, text, nil)
    _nvgTextOrig(vg, x + 1, y, text, nil)
    _nvgTextOrig(vg, x, y - 1, text, nil)
    _nvgTextOrig(vg, x, y + 1, text, nil)
    -- 黑色墨字主体
    nvgFillColor(vg, nvgRGBA(30, 25, 20, 240))
    _nvgTextOrig(vg, x, y, text, nil)
end


function DrawWhiteInkText(x, y, text)
    -- 黑色描边 (8方向偏移1.5px，更粗更清晰) — 使用原始函数避免双重描边
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 210))
    for _, off in ipairs({{-1.5,0},{1.5,0},{0,-1.5},{0,1.5},{-1,-1},{1,-1},{-1,1},{1,1}}) do
        _nvgTextOrig(vg, x + off[1], y + off[2], text, nil)
    end
    -- 白色主体
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    _nvgTextOrig(vg, x, y, text, nil)
end


-- 转圈 loading 动画（资源下载中占位）
function DrawSpinner(cx, cy, radius)
    local t = gameState.gameTime or 0
    local arcLen = math.pi * 0.8
    local startAngle = t * 4.0
    nvgSave(vg)
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy, radius, startAngle, startAngle + arcLen, NVG_CW)
    nvgStrokeWidth(vg, math.max(2, radius * 0.2))
    nvgStrokeColor(vg, nvgRGBA(200, 170, 100, 180))
    nvgStroke(vg)
    nvgRestore(vg)
end


-- 判断 NanoVG 图片是否已就绪（DWP 占位图尺寸极小）
function IsImageReady(handle)
    if not handle or handle < 0 then return false end
    local iw, ih = nvgImageSize(vg, handle)
    return iw > 4 and ih > 4
end


-- 绘制全屏背景图（带 DWP 占位 spinner）
function DrawBgImage(handle, W, H, imgW, imgH, offsetY)
    if not IsImageReady(handle) then
        DrawSpinner(W / 2, H / 2, 20)
        return
    end
    local bgScale = math.max(W / imgW, H / imgH)
    local drawW = imgW * bgScale
    local drawH = imgH * bgScale
    local oy = (offsetY or 0)
    local pat = nvgImagePattern(vg, (W - drawW) / 2, (H - drawH) / 2 + oy, drawW, drawH, 0, handle, 1.0)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillPaint(vg, pat); nvgFill(vg)
end

--- 纯代码绘制等阶边框（向外延伸，不遮挡图标区域）
--- @param x number 图标区域左上角X（与DrawCardImage一致）
--- @param y number 图标区域左上角Y（与DrawCardImage一致）
--- @param iconW number 图标宽度
--- @param iconH number 图标高度
--- @param tier number 等阶1-6
--- @param radius number 圆角半径
function DrawEquipTierBg(x, y, iconW, iconH, tier, radius)
    if not tier or tier < 1 or tier > 6 then return end
    local rd = radius or 4
    local tc = EQUIP_TIERS[tier].color
    local ix = math.floor(x)
    local iy = math.floor(y)
    local cx = ix + iconW / 2
    local cy = iy + iconH / 2
    local bw = 2.0 + tier * 0.5  -- 边框宽度随品阶递增

    -- ① 外层辉光 (径向渐变, 高阶更浓烈)
    if tier >= 2 then
        local gp = bw + 2 + tier
        local glowInner = math.min(30 + tier * 12, 100)
        local gr = nvgRadialGradient(vg, cx, cy,
            math.min(iconW, iconH) * 0.3,
            math.max(iconW, iconH) * 0.5 + gp,
            nvgRGBA(tc[1], tc[2], tc[3], glowInner),
            nvgRGBA(tc[1], tc[2], tc[3], 0))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, ix - gp, iy - gp, iconW + gp * 2, iconH + gp * 2, rd + 4)
        nvgFillPaint(vg, gr); nvgFill(vg)
    end

    -- ② 外边框 — 双层描边: 暗底 + 品阶色渐变
    local outerW = bw + 1.5
    -- 暗底层
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix - outerW, iy - outerW, iconW + outerW * 2, iconH + outerW * 2, rd + 2)
    nvgFillColor(vg, nvgRGBA(8, 6, 14, 240))
    nvgFill(vg)
    -- 品阶色渐变层 (上亮下暗)
    local r2 = math.min(tc[1] + 40, 255)
    local g2 = math.min(tc[2] + 40, 255)
    local b2 = math.min(tc[3] + 40, 255)
    local borderGrad = nvgLinearGradient(vg, ix, iy - bw, ix, iy + iconH + bw,
        nvgRGBA(r2, g2, b2, 240),
        nvgRGBA(math.floor(tc[1] * 0.5), math.floor(tc[2] * 0.5), math.floor(tc[3] * 0.5), 240))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix - bw, iy - bw, iconW + bw * 2, iconH + bw * 2, rd + 1)
    nvgFillPaint(vg, borderGrad); nvgFill(vg)

    -- ③ 内底 (图标背景)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix, iy, iconW, iconH, rd)
    nvgFillColor(vg, nvgRGBA(12, 14, 24, 235))
    nvgFill(vg)

    -- ④ 内侧高光描边 (上边+左边亮, 下边+右边暗 — 立体)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, ix + 0.5, iy + 0.5, iconW - 1, iconH - 1, rd)
    local innerGrad = nvgLinearGradient(vg, ix, iy, ix, iy + iconH,
        nvgRGBA(255, 255, 255, 30 + tier * 12),
        nvgRGBA(0, 0, 0, 20 + tier * 5))
    nvgStrokeWidth(vg, 1.0)
    nvgStrokePaint(vg, innerGrad); nvgStroke(vg)

    -- ⑤ 四角菱形装饰 (将品以上)
    if tier >= 4 then
        local ds = 2.2 + (tier - 4) * 0.6  -- 菱形大小
        local cornerInset = rd + 1
        local cAlpha = 120 + (tier - 4) * 50
        local corners = {
            { ix + cornerInset,          iy + cornerInset },
            { ix + iconW - cornerInset,  iy + cornerInset },
            { ix + cornerInset,          iy + iconH - cornerInset },
            { ix + iconW - cornerInset,  iy + iconH - cornerInset },
        }
        for _, c in ipairs(corners) do
            nvgBeginPath(vg)
            nvgMoveTo(vg, c[1], c[2] - ds)
            nvgLineTo(vg, c[1] + ds, c[2])
            nvgLineTo(vg, c[1], c[2] + ds)
            nvgLineTo(vg, c[1] - ds, c[2])
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], cAlpha))
            nvgFill(vg)
        end
    end

    -- ⑥ 顶部高光条纹 (模拟金属反光)
    if tier >= 3 then
        nvgSave(vg)
        nvgScissor(vg, ix, iy, iconW, iconH * 0.35)
        local shineA = 15 + tier * 8
        local shineGrad = nvgLinearGradient(vg, ix, iy, ix, iy + iconH * 0.35,
            nvgRGBA(255, 255, 255, shineA), nvgRGBA(255, 255, 255, 0))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, ix, iy, iconW, iconH * 0.35, rd)
        nvgFillPaint(vg, shineGrad); nvgFill(vg)
        nvgRestore(vg)
    end
end


function DrawCardImage(x, y, w, h, sheet, row, col, gridCols, gridRows)
    -- 图片未就绪时显示转圈
    if not sheet or sheet < 0 then
        nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 3)
        nvgFillColor(vg, nvgRGBA(30, 25, 20, 120)); nvgFill(vg)
        DrawSpinner(x + w / 2, y + h / 2, math.min(w, h) * 0.2)
        return
    end
    -- DWP 占位检测：图片存在但尚未下载完成（尺寸为占位图 4x4）
    local imgW, imgH = nvgImageSize(vg, sheet)
    if imgW <= 4 or imgH <= 4 then
        nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 3)
        nvgFillColor(vg, nvgRGBA(30, 25, 20, 120)); nvgFill(vg)
        DrawSpinner(x + w / 2, y + h / 2, math.min(w, h) * 0.2)
        return
    end
    local cols = gridCols or SHEET_COLS
    local rows = gridRows or SHEET_ROWS
    -- 根据实际图片尺寸计算每格宽高比, 避免拉伸
    local cellW = imgW / cols
    local cellH = imgH / rows
    local cellAspect = cellW / cellH   -- 图片格子的宽高比
    local drawAspect = w / h           -- 绘制区域的宽高比
    local fitW, fitH
    if cellAspect > drawAspect then
        -- 图片格子更宽: 以宽度为基准, 高度按比例缩放
        fitW = w
        fitH = w / cellAspect
    else
        -- 图片格子更高或相同: 以高度为基准
        fitH = h
        fitW = h * cellAspect
    end
    local fitX = x + (w - fitW) / 2
    local fitY = y + (h - fitH) / 2
    local totalW = fitW * cols
    local totalH = fitH * rows
    local ox = fitX - col * fitW
    local oy = fitY - row * fitH
    nvgSave(vg)
    nvgIntersectScissor(vg, x, y, w, h)
    local p = nvgImagePattern(vg, ox, oy, totalW, totalH, 0, sheet, 1.0)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 3)
    nvgFillPaint(vg, p); nvgFill(vg)
    nvgRestore(vg)
end


-- ============================================================================
-- 统一帮助按钮 "?" (各界面顶栏通用)
-- ============================================================================
function DrawHelpBtn(x, y, size)
    local r = size / 2
    local cx, cy = x + r, y + r
    -- 外圈光晕
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r + 2)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 30))
    nvgFill(vg)
    -- 背景圆
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, nvgRGBA(50, 40, 30, 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 180, 120, 200))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)
    -- 问号文字
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, size * 0.55)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 245))
    nvgText(vg, cx, cy, "?", nil)
    -- 保存按钮位置
    phaseRulePopup.helpBtnRect = { x = x, y = y, w = size, h = size }
end


--- 在指定位置绘制小图标 (战令专用)
function DrawBPIcon(imgHandle, cx, cy, size, alpha)
    alpha = alpha or 255
    if not IsImageReady(imgHandle) then return end
    local hs = size / 2
    local pat = nvgImagePattern(vg, cx - hs, cy - hs, size, size, 0, imgHandle, alpha / 255)
    nvgBeginPath(vg)
    nvgRect(vg, cx - hs, cy - hs, size, size)
    nvgFillPaint(vg, pat)
    nvgFill(vg)
end


--- 绘制单个奖励格子的内容 (使用图标素材替代emoji)
function DrawBPRewardContent(x, y, w, h, reward, claimed)
    if not reward then return end
    local alpha = claimed and 100 or 255
    local lines = {}
    if reward.jade and reward.jade > 0 then
        table.insert(lines, { text = reward.jade .. " 虎符", color = { 255, 220, 100 }, img = IMG.bpIconJade })
    end
    if reward.frag and reward.frag > 0 then
        table.insert(lines, { text = reward.frag .. " 残片", color = { 180, 160, 255 }, img = IMG.bpIconFrag })
    end
    if reward.equipDrop and reward.equipDrop > 0 then
        local tier = reward.equipTier or 3
        local tierName = EQUIP_TIER_NAMES[tier] or ("T" .. tier)
        local qc = QUALITY_COLORS[math.min(tier, #QUALITY_COLORS)] or { 200, 200, 200 }
        table.insert(lines, { text = reward.equipDrop .. "x" .. tierName, color = qc, img = IMG.bpIconEquip })
    end
    local lineH = 18
    local iconSize = 14
    local startY = y + (h - #lines * lineH) / 2
    for i, ln in ipairs(lines) do
        local ly = startY + (i - 1) * lineH + lineH / 2
        -- 图标在左侧
        DrawBPIcon(ln.img, x + 14, ly, iconSize, alpha)
        -- 文字在图标右侧
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(ln.color[1], ln.color[2], ln.color[3], alpha))
        nvgText(vg, x + 23, ly, ln.text, nil)
    end
end
