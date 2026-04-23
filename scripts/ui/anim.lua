-- ============================================================================
-- ui/anim.lua - 共享动画工具库 (零分配, 纯数学)
-- ============================================================================
---@diagnostic disable: undefined-global
local Anim = {}

-- ============================================================================
-- Part A: 缓动函数 (输入 t=[0,1], 输出 [0,1])
-- ============================================================================
function Anim.linear(t) return t end

function Anim.easeOutQuad(t) return t * (2 - t) end

function Anim.easeInQuad(t) return t * t end

function Anim.easeOutCubic(t)
    t = t - 1; return t * t * t + 1
end

function Anim.easeInCubic(t) return t * t * t end

function Anim.easeInOutCubic(t)
    if t < 0.5 then return 4 * t * t * t end
    t = t - 1; return 1 + 4 * t * t * t
end

function Anim.easeOutBack(t)
    local s = 1.70158
    t = t - 1; return t * t * ((s + 1) * t + s) + 1
end

function Anim.easeOutBounce(t)
    if t < 1 / 2.75 then return 7.5625 * t * t
    elseif t < 2 / 2.75 then t = t - 1.5 / 2.75; return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then t = t - 2.25 / 2.75; return 7.5625 * t * t + 0.9375
    else t = t - 2.625 / 2.75; return 7.5625 * t * t + 0.984375
    end
end

-- ============================================================================
-- Part B: 无状态 Tween 求值
-- ============================================================================

--- 计算动画进度 0~1, 未激活返回 nil
function Anim.progress(now, startTime, duration)
    if not startTime or startTime <= 0 then return nil end
    local elapsed = now - startTime
    if elapsed < 0 then return 0 end
    if elapsed >= duration then return 1 end
    return elapsed / duration
end

--- 求值缓动后的 0~1, 未激活返回 nil
function Anim.eval(now, startTime, duration, easeFn)
    local p = Anim.progress(now, startTime, duration)
    if not p then return nil end
    return (easeFn or Anim.easeOutCubic)(p)
end

--- 线性插值
function Anim.lerp(a, b, t) return a + (b - a) * t end

-- ============================================================================
-- Part C: 屏幕转场 (fade-to-black-and-back)
-- ============================================================================
Anim.transition = {
    active = false,
    phase = 0,        -- 0=inactive, 1=fading-out, 2=fading-in
    timer = 0,
    duration = 0.25,  -- 每半段 250ms
    alpha = 0,
    pendingFn = nil,
}

function Anim.StartTransition(onMidpoint, halfDur)
    local tr = Anim.transition
    tr.active = true
    tr.phase = 1
    tr.timer = 0
    tr.duration = halfDur or 0.25
    tr.alpha = 0
    tr.pendingFn = onMidpoint
end

function Anim.UpdateTransition(dt)
    local tr = Anim.transition
    if not tr.active then return end
    tr.timer = tr.timer + dt
    if tr.phase == 1 then
        local p = math.min(1, tr.timer / tr.duration)
        tr.alpha = Anim.easeInCubic(p)
        if p >= 1 then
            if tr.pendingFn then tr.pendingFn() end
            tr.pendingFn = nil
            tr.phase = 2
            tr.timer = 0
        end
    elseif tr.phase == 2 then
        local p = math.min(1, tr.timer / tr.duration)
        tr.alpha = 1 - Anim.easeOutCubic(p)
        if p >= 1 then
            tr.active = false
            tr.phase = 0
            tr.alpha = 0
        end
    end
end

function Anim.DrawTransition(W, H)
    local tr = Anim.transition
    if not tr.active or tr.alpha <= 0 then return end
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(8, 6, 4, math.floor(255 * tr.alpha)))
    nvgFill(vg)
end

-- ============================================================================
-- Part D: Toast 颜色预设 (预分配)
-- ============================================================================
Anim.toastColors = {
    info    = { bg = {60, 50, 35},   fg = {235, 215, 175} },
    success = { bg = {30, 60, 35},   fg = {150, 240, 160} },
    warning = { bg = {70, 55, 20},   fg = {255, 220, 120} },
    error   = { bg = {70, 25, 20},   fg = {255, 160, 140} },
    reward  = { bg = {50, 35, 65},   fg = {220, 190, 255} },
}

-- ============================================================================
-- Part E: 面板滑入辅助
-- ============================================================================
Anim.panelSlide = {
    lastPhase = nil,
    startTime = 0,
    duration = 0.3,
}

--- 返回面板 X 偏移量, 0 表示已就位
function Anim.GetPanelSlideOffset(currentPhase, now, panelW)
    local ps = Anim.panelSlide
    if currentPhase ~= ps.lastPhase then
        ps.lastPhase = currentPhase
        ps.startTime = now
    end
    local p = Anim.eval(now, ps.startTime, ps.duration, Anim.easeOutCubic)
    if not p or p >= 1 then return 0 end
    return panelW * (1 - p)
end

-- ============================================================================
-- Part F: 按钮按压反馈 (预分配状态)
-- ============================================================================
Anim.btnPress = {
    x = 0, y = 0,
    time = 0,
    duration = 0.15,
}

function Anim.OnBtnPress(px, py, now)
    local bp = Anim.btnPress
    bp.x = px
    bp.y = py
    bp.time = now
end

--- 返回按钮缩放系数 (1.0 -> 0.92 -> 1.0)
function Anim.GetBtnScale(now)
    local bp = Anim.btnPress
    local p = Anim.eval(now, bp.time, bp.duration, Anim.easeOutBack)
    if not p then return 1.0 end
    if p < 0.5 then
        return 1.0 - 0.08 * (p / 0.5)
    else
        return 0.92 + 0.08 * ((p - 0.5) / 0.5)
    end
end

--- 判断按压是否在按钮矩形内, 并返回缩放
function Anim.GetBtnScaleFor(now, bx, by, bw, bh)
    local bp = Anim.btnPress
    if bp.time <= 0 then return 1.0 end
    if now - bp.time > bp.duration then return 1.0 end
    if bp.x < bx or bp.x > bx + bw or bp.y < by or bp.y > by + bh then return 1.0 end
    return Anim.GetBtnScale(now)
end

-- ============================================================================
-- Part G: 弹窗动画辅助
-- ============================================================================

--- 计算弹窗缩放和透明度
--- popTimer: 弹窗已存在时间
--- 返回 scale, alphaScale
function Anim.PopupScaleAlpha(popTimer)
    if not popTimer or popTimer < 0 then return 1.0, 1.0 end
    local dur = 0.3
    if popTimer >= dur then return 1.0, 1.0 end
    local p = popTimer / dur
    local scale = 0.85 + 0.15 * Anim.easeOutBack(p)
    local alpha = Anim.easeOutQuad(p)
    return scale, alpha
end

-- ============================================================================
-- Part H: 浮动飘字 (预分配 8 slots, 零分配)
-- ============================================================================
local FLOAT_MAX = 8
Anim.floatSlots = {}
for _fi = 1, FLOAT_MAX do
    Anim.floatSlots[_fi] = {
        active = false,
        text = "",
        x = 0, y = 0,
        r = 200, g = 255, b = 160,
        startTime = 0,
        duration = 0.9,
        rise = 36,
    }
end

--- 添加一条飘字
function Anim.AddFloatNumber(text, x, y, r, g, b, now)
    local slots = Anim.floatSlots
    local best, bestTime = 1, now + 1
    for i = 1, FLOAT_MAX do
        if not slots[i].active then best = i; break end
        if slots[i].startTime < bestTime then
            bestTime = slots[i].startTime; best = i
        end
    end
    local s = slots[best]
    s.active = true
    s.text = text
    s.x = x; s.y = y
    s.r = r or 200; s.g = g or 255; s.b = b or 160
    s.startTime = now
end

--- 绘制所有活跃飘字 (在 DrawUI 末尾调用)
function Anim.DrawFloatNumbers(now)
    local slots = Anim.floatSlots
    for i = 1, FLOAT_MAX do
        local s = slots[i]
        if s.active then
            local elapsed = now - s.startTime
            if elapsed > s.duration then
                s.active = false
            else
                local p = elapsed / s.duration
                local easedP = Anim.easeOutCubic(p)
                local dy = -s.rise * easedP
                local alpha = math.floor(255 * (1 - Anim.easeInQuad(p)))
                if alpha > 0 then
                    nvgFontFaceId(vg, GetMainFont())
                    nvgFontSize(vg, 22)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.6)))
                    nvgText(vg, s.x + 1, s.y + dy + 1, s.text, nil)
                    nvgFillColor(vg, nvgRGBA(s.r, s.g, s.b, alpha))
                    nvgText(vg, s.x, s.y + dy, s.text, nil)
                end
            end
        end
    end
end

-- ============================================================================
-- Part I: 屏幕闪烁 (预分配, 零分配)
-- ============================================================================
Anim.flash = {
    active = false,
    r = 200, g = 0, b = 0,
    startTime = 0,
    duration = 0.3,
}

--- 启动屏幕闪烁
function Anim.StartFlash(r, g, b, duration, now)
    local f = Anim.flash
    f.active = true
    f.r = r or 200; f.g = g or 0; f.b = b or 0
    f.startTime = now
    f.duration = duration or 0.3
end

--- 绘制屏幕闪烁 (在 DrawUI 中转场之前调用)
function Anim.DrawFlash(W, H, now)
    local f = Anim.flash
    if not f.active then return end
    local elapsed = now - f.startTime
    if elapsed > f.duration then f.active = false; return end
    local p = elapsed / f.duration
    local intensity
    if p < 0.3 then
        intensity = p / 0.3
    else
        intensity = 1 - (p - 0.3) / 0.7
    end
    local alpha = math.floor(140 * intensity * intensity)
    if alpha > 0 then
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(f.r, f.g, f.b, alpha))
        nvgFill(vg)
    end
end

-- ============================================================================
-- Part J: 飞卡动画 (搜索人才成功时, 卡牌从右侧飞入中央)
-- ============================================================================
Anim.flyingCard = {
    active = false,
    heroIdx = 0,
    startTime = 0,
    phase = 1,        -- 1=飞入, 2=停留, 3=确认(等待点击)
    confirmed = false,
}
local FC_FLY_DUR   = 0.5   -- 飞入动画时长
local FC_HOLD_DUR  = 0.3   -- 停留后进入确认

function Anim.StartFlyingCard(heroIdx, now)
    local fc = Anim.flyingCard
    fc.active = true
    fc.heroIdx = heroIdx
    fc.startTime = now
    fc.phase = 1
    fc.confirmed = false
end

function Anim.StopFlyingCard()
    Anim.flyingCard.active = false
    Anim.flyingCard.phase = 1
end

--- 更新飞卡阶段
function Anim.UpdateFlyingCard(now)
    local fc = Anim.flyingCard
    if not fc.active then return end
    local elapsed = now - fc.startTime
    if fc.phase == 1 and elapsed >= FC_FLY_DUR then
        fc.phase = 2
        fc.startTime = now
    elseif fc.phase == 2 and (now - fc.startTime) >= FC_HOLD_DUR then
        fc.phase = 3
    end
end

--- 绘制飞卡 (全屏覆盖层, 在 DrawUI 末尾调用)
--- 返回确认按钮的 rect {x,y,w,h} 或 nil
function Anim.DrawFlyingCard(W, H, now)
    local fc = Anim.flyingCard
    if not fc.active then return nil end
    local card = rawget(_G, "HERO_CARDS") and HERO_CARDS[fc.heroIdx]
    if not card then fc.active = false; return nil end

    local elapsed = now - fc.startTime

    -- 品质数据
    local qIdx = card.quality or 1
    local qc = rawget(_G, "QUALITY_COLORS") and QUALITY_COLORS[qIdx] or {200,195,180}
    local qg = rawget(_G, "QUALITY_GLOW") and QUALITY_GLOW[qIdx] or {200,195,180,0}
    local qName = rawget(_G, "QUALITY_NAMES") and QUALITY_NAMES[qIdx] or "N"

    -- 半透明遮罩
    local dimAlpha = 0
    if fc.phase == 1 then
        dimAlpha = math.floor(160 * math.min(1, elapsed / FC_FLY_DUR))
    else
        dimAlpha = 160
    end
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(10, 5, 2, dimAlpha)); nvgFill(vg)

    -- 卡牌位置: 从右侧飞到中央 (放大版)
    local cardW, cardH = 240, 420
    local targetX = W / 2 - cardW / 2
    local targetY = H / 2 - cardH / 2 - 10
    local startX = W + 30
    local startY = targetY

    local cx, cy = targetX, targetY
    if fc.phase == 1 then
        local p = Anim.easeOutBack(math.min(1, elapsed / FC_FLY_DUR))
        cx = startX + (targetX - startX) * p
        cy = startY + (targetY - startY) * p
    end

    -- 品质光晕脉冲动画 (高品质更强烈)
    local glowCenter = cx + cardW / 2
    local glowMid = cy + cardH / 2
    local baseGlowA = qg[4] or 0
    local glowPulse = 0
    if fc.phase >= 2 and baseGlowA > 0 then
        glowPulse = math.sin(now * 3.0) * 0.35 + 0.65  -- 脉冲 0.3~1.0
    else
        glowPulse = 1.0
    end
    local glowAlpha = (fc.phase >= 2)
        and math.floor(math.min(255, baseGlowA + 80) * glowPulse)
        or math.floor((baseGlowA + 80) * math.min(1, elapsed / FC_FLY_DUR))
    local glow = nvgRadialGradient(vg, glowCenter, glowMid, 10, cardW * 0.8,
        nvgRGBA(qc[1], qc[2], qc[3], glowAlpha), nvgRGBA(qc[1], qc[2], qc[3], 0))
    nvgBeginPath(vg); nvgRect(vg, cx - 60, cy - 60, cardW + 120, cardH + 120)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 卡牌背景 (品质色渐变)
    local bgR1 = math.floor(qc[1] * 0.3 + 40)
    local bgG1 = math.floor(qc[2] * 0.3 + 30)
    local bgB1 = math.floor(qc[3] * 0.3 + 15)
    local bgR2 = math.floor(qc[1] * 0.15 + 25)
    local bgG2 = math.floor(qc[2] * 0.15 + 15)
    local bgB2 = math.floor(qc[3] * 0.15 + 5)
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 12)
    local cardGrad = nvgLinearGradient(vg, cx, cy, cx, cy + cardH,
        nvgRGBA(bgR1, bgG1, bgB1, 240), nvgRGBA(bgR2, bgG2, bgB2, 250))
    nvgFillPaint(vg, cardGrad); nvgFill(vg)
    -- 品质色边框
    local borderPulse = (fc.phase >= 2 and qIdx >= 3) and (math.sin(now * 4) * 0.2 + 0.8) or 1.0
    local borderA = math.floor(220 * borderPulse)
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 12)
    nvgStrokeColor(vg, nvgRGBA(qc[1], qc[2], qc[3], borderA))
    nvgStrokeWidth(vg, 2.5); nvgStroke(vg)

    -- 头像区域 (保持原图宽高比, 不拉伸)
    local portraitW = cardW - 40
    local portraitH = 180
    local portraitX = cx + 20
    local portraitY = cy + 18
    local heroImgHandle = IMG and IMG["hero" .. fc.heroIdx]
    if heroImgHandle and heroImgHandle > 0 then
        local imgW, imgH = nvgImageSize(vg, heroImgHandle)
        if imgW > 0 and imgH > 0 then
            local imgAspect = imgW / imgH
            local boxAspect = portraitW / portraitH
            local drawW, drawH, drawX, drawY
            if imgAspect > boxAspect then
                -- 图片更宽: 填满高度, 水平居中
                drawH = portraitH
                drawW = portraitH * imgAspect
                drawX = portraitX - (drawW - portraitW) / 2
                drawY = portraitY
            else
                -- 图片更高(全身立绘): 填满宽度, 顶部对齐(显示头脸)
                drawW = portraitW
                drawH = portraitW / imgAspect
                drawX = portraitX
                drawY = portraitY  -- 顶部对齐, 不居中
            end
            nvgSave(vg)
            nvgIntersectScissor(vg, portraitX, portraitY, portraitW, portraitH)
            local imgPaint = nvgImagePattern(vg, drawX, drawY, drawW, drawH, 0, heroImgHandle, 1.0)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, portraitX, portraitY, portraitW, portraitH, 8)
            nvgFillPaint(vg, imgPaint); nvgFill(vg)
            nvgRestore(vg)
        end
    else
        nvgBeginPath(vg); nvgRoundedRect(vg, portraitX, portraitY, portraitW, portraitH, 8)
        nvgFillColor(vg, nvgRGBA(60, 45, 25, 200)); nvgFill(vg)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 36)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 120, 200))
        nvgText(vg, portraitX + portraitW / 2, portraitY + portraitH / 2, card.name:sub(1,3), nil)
    end
    -- 头像边框
    nvgBeginPath(vg); nvgRoundedRect(vg, portraitX, portraitY, portraitW, portraitH, 8)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 90, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())
    local midX = cx + cardW / 2
    local textY = portraitY + portraitH + 14

    -- 品质徽章 (卡牌左上角)
    local badgeW = 38
    local badgeH = 22
    local badgeX = cx + 6
    local badgeY = cy + 6
    nvgBeginPath(vg); nvgRoundedRect(vg, badgeX, badgeY, badgeW, badgeH, 4)
    nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 200)); nvgFill(vg)
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
    nvgText(vg, badgeX + badgeW / 2, badgeY + badgeH / 2, qName, nil)

    -- "招揽成功!" 标题 (品质色)
    nvgFontSize(vg, 26); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
    nvgText(vg, midX, textY, "招揽成功!", nil)

    -- 武将名 (品质色, 大字)
    nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
    nvgText(vg, midX, textY + 28, card.name, nil)

    -- 独特招揽台词 (带引号)
    local quote = card.recruitQuote or ("末将" .. card.name .. "，愿为主公效力！")
    nvgFontSize(vg, 18); nvgFillColor(vg, nvgRGBA(255, 240, 200, 200))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 台词可能较长，分行显示
    local quoteStr = "\"" .. quote .. "\""
    local maxQuoteW = cardW - 30
    nvgSave(vg)
    local quoteTextW = nvgTextBounds(vg, 0, 0, quoteStr, nil) or 0
    if quoteTextW > maxQuoteW then
        -- 分两行：找中间位置断行
        local halfLen = math.floor(#quoteStr / 2)
        -- 往前找标点或空格断行
        local breakPos = halfLen
        for bi = halfLen, math.max(1, halfLen - 10), -1 do
            local ch = quoteStr:sub(bi, bi)
            if ch == "，" or ch == "、" or ch == "！" or ch == "。" or ch == " " then
                breakPos = bi; break
            end
        end
        -- UTF-8 安全断行：找到完整字符边界
        local bytePos = 0
        local charCount = 0
        local safeByte = breakPos
        while bytePos < #quoteStr do
            local b = quoteStr:byte(bytePos + 1)
            if b < 0x80 then bytePos = bytePos + 1
            elseif b < 0xE0 then bytePos = bytePos + 2
            elseif b < 0xF0 then bytePos = bytePos + 3
            else bytePos = bytePos + 4 end
            charCount = charCount + 1
            if bytePos <= breakPos then safeByte = bytePos end
        end
        local line1 = quoteStr:sub(1, safeByte)
        local line2 = quoteStr:sub(safeByte + 1)
        nvgText(vg, midX, textY + 56, line1, nil)
        nvgText(vg, midX, textY + 76, line2, nil)
    else
        nvgText(vg, midX, textY + 66, quoteStr, nil)
    end
    nvgRestore(vg)

    -- 五维属性 (stats5: str/int/vit/tec/spd)
    local attrY = textY + 96
    local s5 = card.stats5 or { str = 50, int = 50, vit = 50, tec = 50, spd = 50 }
    nvgFontSize(vg, 18); nvgFillColor(vg, nvgRGBA(220, 210, 180, 220))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local line1 = "武:" .. s5.str .. "  智:" .. s5.int .. "  体:" .. s5.vit
    nvgText(vg, midX, attrY, line1, nil)
    local line2 = "技:" .. s5.tec .. "  速:" .. s5.spd
    nvgText(vg, midX, attrY + 22, line2, nil)

    -- 兵种
    local troopKey = card.troopType or card.unitClass or ""
    local ttData = troopKey ~= "" and rawget(_G, "TROOP_TYPES") and TROOP_TYPES[troopKey]
    local troopDisp = ttData and ttData.name or ""
    if troopDisp ~= "" then
        nvgFontSize(vg, 18); nvgFillColor(vg, nvgRGBA(180, 170, 140, 200))
        nvgText(vg, midX, attrY + 46, "兵种: " .. troopDisp, nil)
    end

    -- 确认按钮 (phase 3 才显示, 内联绘制避免循环依赖)
    local btnRect = nil
    if fc.phase >= 3 then
        local btnW2 = 140
        local btnH2 = 40
        local btnX = cx + (cardW - btnW2) / 2
        local btnY = cy + cardH + 18
        local br, bg2, bb = 140, 110, 30
        local bAlpha = 200
        local bRadius = 6
        -- 阴影
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX + 1, btnY + 1, btnW2, btnH2, bRadius)
        nvgFillColor(vg, nvgRGBA(60, 40, 20, 40)); nvgFill(vg)
        -- 渐变填充
        local bGrad = nvgLinearGradient(vg, btnX, btnY, btnX, btnY + btnH2,
            nvgRGBA(math.min(255, br + 40), math.min(255, bg2 + 30), math.min(255, bb + 20), bAlpha),
            nvgRGBA(br, bg2, bb, bAlpha))
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW2, btnH2, bRadius)
        nvgFillPaint(vg, bGrad); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 170, 90, 140))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        -- 文字
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(60, 30, 10, 160))
        nvgText(vg, btnX + btnW2 / 2 + 1, btnY + btnH2 / 2 + 1, "确 认", nil)
        nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
        nvgText(vg, btnX + btnW2 / 2, btnY + btnH2 / 2, "确 认", nil)
        btnRect = { x = btnX, y = btnY, w = btnW2, h = btnH2 }
    end

    return btnRect
end

-- ============================================================================
-- Part J2: 通用操作反馈弹窗 (征兵/升级城防/犒赏三军等)
-- 固定图标(NanoVG绘制) + 标题 + 描述文字, 从右侧飞入, 自动消失
-- ============================================================================
Anim.actionCard = {
    active = false,
    startTime = 0,
    phase = 1,         -- 1=飞入, 2=停留展示, 3=淡出
    -- 内容
    icon = "",         -- 图标类型: "recruit","upgrade","morale","reinforce"
    title = "",
    desc = "",
    color = {255,220,80},  -- 主题色
}
local AC_FLY_DUR  = 0.4
local AC_SHOW_DUR = 1.2    -- 展示时长
local AC_FADE_DUR = 0.4    -- 淡出时长

--- 启动通用操作反馈弹窗
--- @param icon string 图标类型 "recruit"|"upgrade"|"morale"|"reinforce"
--- @param title string 标题文字
--- @param desc string 描述文字
--- @param color table {r,g,b} 主题色
--- @param now number 当前时间
function Anim.StartActionCard(icon, title, desc, color, now)
    local ac = Anim.actionCard
    ac.active = true
    ac.startTime = now
    ac.phase = 1
    ac.icon = icon or ""
    ac.title = title or ""
    ac.desc = desc or ""
    ac.color = color or {255,220,80}
end

function Anim.StopActionCard()
    Anim.actionCard.active = false
    Anim.actionCard.phase = 1
end

function Anim.UpdateActionCard(now)
    local ac = Anim.actionCard
    if not ac.active then return end
    local elapsed = now - ac.startTime
    if ac.phase == 1 and elapsed >= AC_FLY_DUR then
        ac.phase = 2; ac.startTime = now
    elseif ac.phase == 2 and (now - ac.startTime) >= AC_SHOW_DUR then
        ac.phase = 3; ac.startTime = now
    elseif ac.phase == 3 and (now - ac.startTime) >= AC_FADE_DUR then
        ac.active = false; ac.phase = 1
    end
end

--- 绘制 NanoVG 图标 (纯矢量, 不依赖图片资源)
local function DrawActionIcon(cx, cy, size, iconType, color, now)
    local r, g, b = color[1], color[2], color[3]
    local halfSz = size * 0.5
    if iconType == "recruit" then
        -- 征兵: 盾牌 + 剑
        -- 盾牌
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx, cy - halfSz * 0.9)
        nvgLineTo(vg, cx + halfSz * 0.7, cy - halfSz * 0.5)
        nvgLineTo(vg, cx + halfSz * 0.6, cy + halfSz * 0.5)
        nvgLineTo(vg, cx, cy + halfSz * 0.9)
        nvgLineTo(vg, cx - halfSz * 0.6, cy + halfSz * 0.5)
        nvgLineTo(vg, cx - halfSz * 0.7, cy - halfSz * 0.5)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(r, g, b, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        -- 盾牌中央十字
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx, cy - halfSz * 0.35); nvgLineTo(vg, cx, cy + halfSz * 0.35)
        nvgMoveTo(vg, cx - halfSz * 0.25, cy); nvgLineTo(vg, cx + halfSz * 0.25, cy)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 220)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
    elseif iconType == "upgrade" then
        -- 升级城防: 城墙 + 箭头上
        -- 城墙
        local wY = cy + halfSz * 0.15
        nvgBeginPath(vg)
        nvgRect(vg, cx - halfSz * 0.7, wY, halfSz * 1.4, halfSz * 0.6)
        nvgFillColor(vg, nvgRGBA(r, g, b, 180)); nvgFill(vg)
        -- 城垛
        local merlonW = halfSz * 0.25
        local merlonH = halfSz * 0.25
        for i = -1, 1 do
            nvgBeginPath(vg)
            nvgRect(vg, cx + i * merlonW * 1.4 - merlonW * 0.5, wY - merlonH, merlonW, merlonH)
            nvgFillColor(vg, nvgRGBA(r, g, b, 200)); nvgFill(vg)
        end
        -- 向上箭头
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx, cy - halfSz * 0.8)
        nvgLineTo(vg, cx + halfSz * 0.3, cy - halfSz * 0.4)
        nvgLineTo(vg, cx - halfSz * 0.3, cy - halfSz * 0.4)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230)); nvgFill(vg)
    elseif iconType == "morale" then
        -- 犒赏三军: 旗帜
        -- 旗杆
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - halfSz * 0.3, cy - halfSz * 0.85)
        nvgLineTo(vg, cx - halfSz * 0.3, cy + halfSz * 0.85)
        nvgStrokeColor(vg, nvgRGBA(200, 180, 140, 240)); nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
        -- 旗面 (飘动)
        local wave = math.sin(now * 4) * halfSz * 0.08
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - halfSz * 0.3, cy - halfSz * 0.85)
        nvgLineTo(vg, cx + halfSz * 0.6 + wave, cy - halfSz * 0.65)
        nvgLineTo(vg, cx + halfSz * 0.5 + wave * 0.5, cy - halfSz * 0.2)
        nvgLineTo(vg, cx - halfSz * 0.3, cy - halfSz * 0.05)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(r, g, b, 200)); nvgFill(vg)
        -- 旗面"令"字
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, size * 0.3)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, cx + halfSz * 0.1, cy - halfSz * 0.45, "令", nil)
    elseif iconType == "conquest" then
        -- 攻占城池: 城门 + 旗帜飘扬
        -- 城门主体
        nvgBeginPath(vg)
        nvgRect(vg, cx - halfSz * 0.6, cy - halfSz * 0.2, halfSz * 1.2, halfSz * 0.9)
        nvgFillColor(vg, nvgRGBA(r, g, b, 160)); nvgFill(vg)
        -- 城门洞 (拱形)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - halfSz * 0.2, cy + halfSz * 0.1, halfSz * 0.4, halfSz * 0.6, halfSz * 0.2)
        nvgFillColor(vg, nvgRGBA(20, 15, 10, 200)); nvgFill(vg)
        -- 城垛
        local mW = halfSz * 0.2
        for i = -2, 2 do
            nvgBeginPath(vg)
            nvgRect(vg, cx + i * mW * 1.2 - mW * 0.5, cy - halfSz * 0.45, mW, halfSz * 0.25)
            nvgFillColor(vg, nvgRGBA(r, g, b, 200)); nvgFill(vg)
        end
        -- 旗帜 (城墙上方飘动)
        local wave = math.sin(now * 5) * halfSz * 0.06
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + halfSz * 0.15, cy - halfSz * 0.45)
        nvgLineTo(vg, cx + halfSz * 0.15, cy - halfSz * 0.95)
        nvgStrokeColor(vg, nvgRGBA(200, 180, 140, 240)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + halfSz * 0.15, cy - halfSz * 0.95)
        nvgLineTo(vg, cx + halfSz * 0.55 + wave, cy - halfSz * 0.82)
        nvgLineTo(vg, cx + halfSz * 0.45 + wave * 0.5, cy - halfSz * 0.6)
        nvgLineTo(vg, cx + halfSz * 0.15, cy - halfSz * 0.5)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 60, 40, 220)); nvgFill(vg)
    elseif iconType == "reinforce" then
        -- 补兵: 人形剪影 + 加号
        -- 人形
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy - halfSz * 0.35, halfSz * 0.25)
        nvgFillColor(vg, nvgRGBA(r, g, b, 180)); nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - halfSz * 0.3, cy, halfSz * 0.6, halfSz * 0.55, 4)
        nvgFillColor(vg, nvgRGBA(r, g, b, 160)); nvgFill(vg)
        -- 右上角加号
        local px, py = cx + halfSz * 0.45, cy - halfSz * 0.5
        nvgBeginPath(vg)
        nvgMoveTo(vg, px - halfSz * 0.2, py); nvgLineTo(vg, px + halfSz * 0.2, py)
        nvgMoveTo(vg, px, py - halfSz * 0.2); nvgLineTo(vg, px, py + halfSz * 0.2)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 240)); nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
    else
        -- 默认: 圆形图标
        nvgBeginPath(vg); nvgCircle(vg, cx, cy, halfSz * 0.7)
        nvgFillColor(vg, nvgRGBA(r, g, b, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end
end

--- 绘制通用操作反馈弹窗 (全屏覆盖层)
function Anim.DrawActionCard(W, H, now)
    local ac = Anim.actionCard
    if not ac.active then return end

    local elapsed = now - ac.startTime
    local color = ac.color

    -- 全局透明度
    local alpha = 1.0
    if ac.phase == 1 then
        alpha = math.min(1, elapsed / AC_FLY_DUR)
    elseif ac.phase == 3 then
        alpha = math.max(0, 1 - elapsed / AC_FADE_DUR)
    end

    -- 半透明遮罩
    local dimAlpha = math.floor(120 * alpha)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(10, 5, 2, dimAlpha)); nvgFill(vg)

    -- 卡片位置: 从右侧飞入中央
    local cardW, cardH = 260, 180
    local targetX = W / 2 - cardW / 2
    local targetY = H / 2 - cardH / 2
    local startX = W + 30

    local cx = targetX
    if ac.phase == 1 then
        local p = Anim.easeOutBack(math.min(1, elapsed / AC_FLY_DUR))
        cx = startX + (targetX - startX) * p
    end

    nvgSave(vg)
    nvgGlobalAlpha(vg, alpha)

    -- 光晕
    local glowPulse = (ac.phase == 2) and (math.sin(now * 3) * 0.25 + 0.75) or 1.0
    local glowA = math.floor(90 * glowPulse)
    local glow = nvgRadialGradient(vg, cx + cardW / 2, targetY + cardH / 2, 10, cardW * 0.7,
        nvgRGBA(color[1], color[2], color[3], glowA), nvgRGBA(color[1], color[2], color[3], 0))
    nvgBeginPath(vg); nvgRect(vg, cx - 40, targetY - 40, cardW + 80, cardH + 80)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 卡片背景
    local bgR = math.floor(color[1] * 0.2 + 30)
    local bgG = math.floor(color[2] * 0.2 + 20)
    local bgB = math.floor(color[3] * 0.2 + 10)
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, targetY, cardW, cardH, 10)
    local grad = nvgLinearGradient(vg, cx, targetY, cx, targetY + cardH,
        nvgRGBA(bgR + 20, bgG + 15, bgB + 10, 235), nvgRGBA(bgR, bgG, bgB, 245))
    nvgFillPaint(vg, grad); nvgFill(vg)
    -- 边框
    nvgBeginPath(vg); nvgRoundedRect(vg, cx, targetY, cardW, cardH, 10)
    nvgStrokeColor(vg, nvgRGBA(color[1], color[2], color[3], 180))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 图标区域 (左侧)
    local iconSize = 60
    local iconCx = cx + 55
    local iconCy = targetY + cardH / 2 - 8
    DrawActionIcon(iconCx, iconCy, iconSize, ac.icon, color, now)

    -- 文字区域 (右侧)
    local textX = cx + 110
    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], 255))
    nvgText(vg, textX, targetY + 50, ac.title, nil)

    -- 描述 (支持多行自动换行 + 手动\n换行)
    nvgFontSize(vg, 18); nvgFillColor(vg, nvgRGBA(230, 220, 190, 220))
    local descMaxW = cardW - 120
    local descText = ac.desc
    -- 按\n手动分段, 每段再按宽度自动换行
    local lines = {}
    for segment in (descText .. "\n"):gmatch("(.-)\n") do
        -- 逐UTF-8字符测量, 超宽则断行
        local lineStart = 1
        local lastBreak = 0
        local bytePos = 0
        while bytePos < #segment do
            local b = segment:byte(bytePos + 1)
            local charLen
            if b < 0x80 then charLen = 1
            elseif b < 0xE0 then charLen = 2
            elseif b < 0xF0 then charLen = 3
            else charLen = 4 end
            bytePos = bytePos + charLen
            local ch = segment:sub(bytePos - charLen + 1, bytePos)
            if ch == "，" or ch == "、" or ch == "！" or ch == "。" or ch == " " or ch == "+" then
                lastBreak = bytePos
            end
            local lineW = nvgTextBounds(vg, 0, 0, segment:sub(lineStart, bytePos), nil) or 0
            if lineW > descMaxW and bytePos > lineStart then
                local breakAt = (lastBreak > lineStart) and lastBreak or (bytePos - charLen)
                lines[#lines + 1] = segment:sub(lineStart, breakAt)
                lineStart = breakAt + 1
                lastBreak = 0
            end
        end
        if lineStart <= #segment then
            lines[#lines + 1] = segment:sub(lineStart)
        elseif #lines == 0 or segment == "" then
            lines[#lines + 1] = ""
        end
    end
    local lineH = 22
    local descStartY = targetY + 80
    for li, line in ipairs(lines) do
        nvgText(vg, textX, descStartY + (li - 1) * lineH, line, nil)
    end
    -- 动态扩展卡片高度 (超过2行时)
    if #lines > 2 then
        local extraH = (#lines - 2) * lineH
        -- 重绘卡片底部扩展 (覆盖原有边界)
        nvgBeginPath(vg); nvgRoundedRect(vg, cx, targetY + cardH - 10, cardW, extraH + 10, 10)
        local bgR2 = math.floor(color[1] * 0.2 + 30)
        local bgG2 = math.floor(color[2] * 0.2 + 20)
        local bgB2 = math.floor(color[3] * 0.2 + 10)
        nvgFillColor(vg, nvgRGBA(bgR2, bgG2, bgB2, 245)); nvgFill(vg)
    end

    -- 顶部装饰线
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + 12, targetY + 2); nvgLineTo(vg, cx + cardW - 12, targetY + 2)
    nvgStrokeColor(vg, nvgRGBA(color[1], color[2], color[3], 100))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgRestore(vg)
end

-- ============================================================================
-- Part K: 屏幕震动 (预分配, 零分配)
-- ============================================================================
Anim.shake = {
    active = false,
    startTime = 0,
    duration = 0.4,
    intensity = 6,
    offsetX = 0,
    offsetY = 0,
}

function Anim.StartShake(intensity, duration, now)
    local s = Anim.shake
    s.active = true
    s.startTime = now
    s.duration = duration or 0.4
    s.intensity = intensity or 6
end

function Anim.UpdateShake(now)
    local s = Anim.shake
    if not s.active then s.offsetX = 0; s.offsetY = 0; return end
    local elapsed = now - s.startTime
    if elapsed > s.duration then
        s.active = false; s.offsetX = 0; s.offsetY = 0; return
    end
    local decay = 1 - (elapsed / s.duration)
    local freq = elapsed * 30
    s.offsetX = math.sin(freq * 1.3) * s.intensity * decay
    s.offsetY = math.cos(freq * 1.7) * s.intensity * decay * 0.7
end

--- 在绘制开始时应用震动偏移 (nvgTranslate)
function Anim.ApplyShake()
    local s = Anim.shake
    if not s.active then return end
    nvgTranslate(vg, s.offsetX, s.offsetY)
end

-- ============================================================================
-- Part L: 回合播报 (预分配, "第N回合 - 群雄逐鹿")
-- ============================================================================
Anim.turnAnnounce = {
    active = false,
    startTime = 0,
    duration = 2.0,
    text = "",
    subText = "",
}

function Anim.StartTurnAnnounce(mainText, subText, now)
    local ta = Anim.turnAnnounce
    ta.active = true
    ta.startTime = now
    ta.text = mainText or ""
    ta.subText = subText or ""
end

function Anim.DrawTurnAnnounce(W, H, now)
    local ta = Anim.turnAnnounce
    if not ta.active then return end
    local elapsed = now - ta.startTime
    if elapsed > ta.duration then ta.active = false; return end

    local p = elapsed / ta.duration
    -- 淡入 0~0.15, 停留 0.15~0.7, 淡出 0.7~1.0
    local alpha
    if p < 0.15 then alpha = p / 0.15
    elseif p < 0.7 then alpha = 1.0
    else alpha = 1.0 - (p - 0.7) / 0.3
    end
    local a = math.floor(255 * alpha)
    if a <= 0 then return end

    -- 横幅背景
    local bannerH = 70
    local bannerY = H * 0.28
    nvgBeginPath(vg); nvgRect(vg, 0, bannerY, W, bannerH)
    nvgFillColor(vg, nvgRGBA(15, 10, 5, math.floor(200 * alpha))); nvgFill(vg)
    -- 金边
    nvgBeginPath(vg); nvgMoveTo(vg, 0, bannerY); nvgLineTo(vg, W, bannerY)
    nvgStrokeColor(vg, nvgRGBA(220, 180, 60, math.floor(a * 0.7)))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, bannerY + bannerH); nvgLineTo(vg, W, bannerY + bannerH)
    nvgStrokeColor(vg, nvgRGBA(220, 180, 60, math.floor(a * 0.7)))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 主标题 (滑入效果)
    local slideX = 0
    if p < 0.15 then
        slideX = (1 - p / 0.15) * 80
    end
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(a * 0.5)))
    nvgText(vg, W / 2 + slideX + 1, bannerY + bannerH * 0.38 + 1, ta.text, nil)
    nvgFillColor(vg, nvgRGBA(255, 230, 150, a))
    nvgText(vg, W / 2 + slideX, bannerY + bannerH * 0.38, ta.text, nil)

    -- 副标题
    if ta.subText ~= "" then
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(200, 185, 145, math.floor(a * 0.8)))
        nvgText(vg, W / 2, bannerY + bannerH * 0.72, ta.subText, nil)
    end
end

return Anim
