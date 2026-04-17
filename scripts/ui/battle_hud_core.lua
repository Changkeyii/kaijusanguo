-- ui/battle_hud_core.lua - 三国武灵录 (从 battle_hud.lua 拆分)
-- ============================================================================
-- ui/battle_hud.lua - 三国武灵录
-- ============================================================================


--- 绘制技能序列帧的单帧 (设计坐标)
function DrawSkillFrame(cx, cy, renderW, frameIdx, alpha, techIdx)
    -- 根据技能的 iconIdx 查找对应的 FX 精灵图
    local skill = techIdx and SKILL_DEFS[techIdx]
    local iconIdx = skill and skill.iconIdx or 20
    local fxData = SKILL_FX_SHEETS[iconIdx]

    -- 有专属精灵图 >> 用 crop-aware 渲染
    if fxData and fxData.handle > 0 then
        local cols = fxData.cols
        local rows = fxData.rows
        local totalFrames = fxData.frames
        local fi = math.min(frameIdx % totalFrames, totalFrames - 1)
        local fcol = fi % cols
        local frow = math.floor(fi / cols)
        local crop = fxData.crop

        local imgW, imgH = nvgImageSize(vg, fxData.handle)
        local cellW = imgW / cols
        local cellH = imgH / rows

        -- crop 值基于原始图片尺寸, 需按实际尺寸缩放
        local cropScale = fxData.origW and (imgW / fxData.origW) or 1
        local srcX = fcol * cellW + crop.x * cropScale
        local srcY = frow * cellH + crop.y * cropScale
        local srcW = crop.w * cropScale
        local srcH = crop.h * cropScale

        -- 按宽度缩放, 确保可见宽度 == renderW (匹配瞄准圈直径)
        local contentScale = renderW / srcW
        local scaledW = renderW
        local scaledH = srcH * contentScale
        local centeredX = cx - scaledW / 2
        local centeredY = cy - scaledH / 2

        -- 逐帧视觉中心校正 (消除序列帧抖动)
        local offsets = fxData.frameOffsets
        if offsets then
            local fo = offsets[fi + 1]  -- Lua 1-based
            if fo then
                centeredX = centeredX + fo[1] * contentScale
                centeredY = centeredY + fo[2] * contentScale
            end
        end

        local patX = centeredX - srcX * contentScale
        local patY = centeredY - srcY * contentScale

        local pat = nvgImagePattern(vg, patX, patY, imgW * contentScale, imgH * contentScale, 0, fxData.handle, alpha)
        nvgBeginPath(vg)
        nvgRect(vg, centeredX, centeredY, scaledW, scaledH)
        nvgFillPaint(vg, pat)
        nvgFill(vg)
        return
    end

    -- 无专属精灵图 >> 通用粒子爆发效果 (基于技能颜色)
    local sc = skill and skill.color or { 255, 160, 60 }
    local progress = frameIdx / 15  -- 0~1
    local burstR = renderW * 0.4 * (0.3 + progress * 0.7)
    local burstAlpha = math.floor(255 * alpha * (1.0 - progress * 0.6))
    -- 外圈光晕
    local glow = nvgRadialGradient(vg, cx, cy, burstR * 0.2, burstR,
        nvgRGBA(sc[1], sc[2], sc[3], math.floor(burstAlpha * 0.6)),
        nvgRGBA(sc[1], sc[2], sc[3], 0))
    nvgBeginPath(vg); nvgCircle(vg, cx, cy, burstR)
    nvgFillPaint(vg, glow); nvgFill(vg)
    -- 内核
    local coreR = burstR * 0.3
    local coreGlow = nvgRadialGradient(vg, cx, cy, 0, coreR,
        nvgRGBA(255, 255, 255, math.floor(burstAlpha * 0.8)),
        nvgRGBA(sc[1], sc[2], sc[3], math.floor(burstAlpha * 0.3)))
    nvgBeginPath(vg); nvgCircle(vg, cx, cy, coreR)
    nvgFillPaint(vg, coreGlow); nvgFill(vg)
end


--- 绘制底层技能特效 (renderBehind=true, 在 DrawBattleUnits 之前调用)
function DrawGroundSkillEffects()
    for _, eff in ipairs(activeSkillEffects) do
        local skill = SKILL_DEFS[eff.skillIdx]
        if not skill or not skill.renderBehind then goto continue end

        local progress = eff.timer / eff.duration
        -- alpha: 渐入渐出
        local alpha = 1.0
        if progress < 0.15 then
            alpha = progress / 0.15
        elseif progress > 0.75 then
            alpha = (1.0 - progress) / 0.25
        end
        alpha = math.max(0, math.min(1, alpha))

        local sc = skill.color
        -- ======== 底层渲染: 柔和光圈 + 序列帧 ========
        local glowPulse = 0.4 + 0.3 * math.sin(eff.timer * 4)  -- 缓慢呼吸
        local isRectBehind = skill.skillType == "rect" and skill.rectW

        if isRectBehind then
            -- 矩形技能底层: 矩形光圈
            local rw = skill.rectW * (0.7 + progress * 0.3)
            local rh = skill.rectH * (0.7 + progress * 0.3)
            local rx, ry = eff.x - rw / 2, eff.y - rh / 2
            local groundGlow = nvgBoxGradient(vg, rx, ry, rw, rh, 10, rw * 0.3,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(35 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgRoundedRect(vg, rx - rw * 0.15, ry - rh * 0.15, rw * 1.3, rh * 1.3, 10)
            nvgFillPaint(vg, groundGlow); nvgFill(vg)
            -- 序列帧
            DrawSkillFrame(eff.x, eff.y, rw, eff.frameIdx, alpha * 0.85, eff.skillIdx)
        else
            -- 圆形技能底层: 圆形光圈 (治疗/区域)
            local glowR = skill.radius * (0.7 + progress * 0.3)

            -- 底层柔光圈 (更大范围, 低透明度)
            local groundGlow = nvgRadialGradient(vg, eff.x, eff.y, glowR * 0.1, glowR * 1.2,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(35 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, eff.x, eff.y, glowR * 1.2)
            nvgFillPaint(vg, groundGlow); nvgFill(vg)

            -- 内层光圈 (较亮)
            local innerGlow = nvgRadialGradient(vg, eff.x, eff.y, glowR * 0.05, glowR * 0.7,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(50 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, eff.x, eff.y, glowR * 0.7)
            nvgFillPaint(vg, innerGlow); nvgFill(vg)

            -- 序列帧动画
            local effectDiameter = skill.radius * 2
            DrawSkillFrame(eff.x, eff.y, effectDiameter * (0.7 + progress * 0.3), eff.frameIdx, alpha * 0.85, eff.skillIdx)
        end

        ::continue::
    end
end


--- 绘制所有活跃的技能特效 (设计坐标, 在 DrawBattleUnits 之后调用)
function DrawSkillEffects()
    for _, eff in ipairs(activeSkillEffects) do
        local skill = SKILL_DEFS[eff.skillIdx]
        if not skill then goto continue end
        -- renderBehind 效果已在 DrawGroundSkillEffects 中绘制
        if skill.renderBehind then goto continue end
        local progress = eff.timer / eff.duration
        -- alpha: 渐入渐出
        local alpha = 1.0
        if progress < 0.15 then
            alpha = progress / 0.15
        elseif progress > 0.75 then
            alpha = (1.0 - progress) / 0.25
        end
        alpha = math.max(0, math.min(1, alpha))

        local sc = skill.color

        if eff.isLine then
            -- ======== 线型技能渲染: 横向光带尾迹 ========
            local halfH = (skill.lineWidth or 50) / 2
            local trailLen = 80  -- 尾迹长度

            -- 光带主体 (横屏: 沿X轴飞行, 从当前位置向后拖尾)
            local headX = eff.x
            local tailX
            if eff.isEnemySkill then
                tailX = math.min(headX + trailLen, BATTLE_ZONE.enemyLine)
            else
                tailX = math.max(headX - trailLen, BATTLE_ZONE.playerLine)
            end
            local glowPulse = 0.7 + 0.3 * math.sin(eff.timer * 10)
            local bodyAlpha = math.floor(50 * alpha * glowPulse)

            -- 光带渐变 (头部亮, 尾部暗)
            local gradX1 = math.min(headX, tailX)
            local gradX2 = math.max(headX, tailX)
            local grad
            if eff.isEnemySkill then
                grad = nvgLinearGradient(vg, headX, eff.y, tailX, eff.y,
                    nvgRGBA(sc[1], sc[2], sc[3], math.floor(bodyAlpha * 1.2)),
                    nvgRGBA(sc[1], sc[2], sc[3], 0))
            else
                grad = nvgLinearGradient(vg, headX, eff.y, tailX, eff.y,
                    nvgRGBA(sc[1], sc[2], sc[3], math.floor(bodyAlpha * 1.2)),
                    nvgRGBA(sc[1], sc[2], sc[3], 0))
            end
            nvgBeginPath(vg)
            nvgRect(vg, gradX1, eff.y - halfH, gradX2 - gradX1, halfH * 2)
            nvgFillPaint(vg, grad); nvgFill(vg)

            -- 头部高亮光晕
            local headGlow = nvgRadialGradient(vg, headX, eff.y, 5, halfH * 1.5,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(100 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, headX, eff.y, halfH * 1.5)
            nvgFillPaint(vg, headGlow); nvgFill(vg)

            -- 序列帧动画 (在弹头位置绘制)
            local frameSize = skill.renderSize * (0.8 + 0.2 * glowPulse)
            DrawSkillFrame(eff.x, eff.y, frameSize, eff.frameIdx, alpha, eff.skillIdx)
        elseif skill.skillType == "rect" then
            -- ======== 矩形技能渲染: 矩形光框 + 序列帧 ========
            local rw, rh = skill.rectW, skill.rectH
            local glowPulse = 0.5 + 0.5 * math.sin(eff.timer * 8)
            local rectScale = 0.6 + progress * 0.4
            local gw, gh = rw * rectScale, rh * rectScale

            -- 矩形范围光晕
            local rx, ry = eff.x - gw / 2, eff.y - gh / 2
            local grad = nvgLinearGradient(vg, rx, ry, rx, ry + gh,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(50 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(15 * alpha * glowPulse)))
            nvgBeginPath(vg); nvgRect(vg, rx, ry, gw, gh)
            nvgFillPaint(vg, grad); nvgFill(vg)

            -- 矩形边框
            nvgBeginPath(vg); nvgRect(vg, rx, ry, gw, gh)
            nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], math.floor(40 * alpha * glowPulse)))
            nvgStrokeWidth(vg, 1.0); nvgStroke(vg)

            -- 序列帧动画 (用矩形宽度匹配)
            local fxScale = 0.7 + progress * 0.3
            DrawSkillFrame(eff.x, eff.y, rw * fxScale, eff.frameIdx, alpha, eff.skillIdx)
        else
            -- ======== AOE技能渲染: 圆形光圈 + 序列帧 ========
            -- 底部光圈(范围指示, 使用技能颜色)
            local glowPulse = 0.5 + 0.5 * math.sin(eff.timer * 8)
            local glowR = skill.radius * (0.6 + progress * 0.4)
            local glow = nvgRadialGradient(vg, eff.x, eff.y, glowR * 0.2, glowR,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(60 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, eff.x, eff.y, glowR)
            nvgFillPaint(vg, glow); nvgFill(vg)

            -- 序列帧动画 (用 radius*2 匹配瞄准圈直径)
            local effectDiameter = skill.radius * 2
            DrawSkillFrame(eff.x, eff.y, effectDiameter * (0.7 + progress * 0.3), eff.frameIdx, alpha, eff.skillIdx)
        end
        ::continue::
    end
end


--- 绘制技能瞄准指示器 (设计坐标, 拖拽中调用)
function DrawSkillTargetingDesign()
    if not skillTargeting.active then return end
    local skill = SKILL_DEFS[skillTargeting.skillIdx]
    if not skill then return end

    local tx, ty = skillTargeting.dx, skillTargeting.dy
    local bz = BATTLE_ZONE
    local t = gameState.gameTime

    -- 检查是否在战场范围内 (横屏: X在两条临界线之间, Y在战区范围内)
    local inZone = tx >= bz.playerLine and tx <= bz.enemyLine
        and ty >= bz.top and ty <= bz.bottom

    local baseAlpha = inZone and 180 or 80
    local pulseAlpha = math.floor(baseAlpha * (0.6 + 0.4 * math.sin(t * 5)))

    if skill.skillType == "line" then
        -- ======== 线型技能瞄准: 高亮水平条带(跟随手指Y) ========
        local bandH = 50  -- 条带高度
        local bandTop = math.max(bz.top, ty - bandH * 0.5)
        local bandBot = math.min(bz.bottom, bandTop + bandH)
        local bandCY = (bandTop + bandBot) * 0.5
        local laneLeft = bz.playerLine
        local laneRight = bz.enemyLine
        local laneW = laneRight - laneLeft
        local pulse = 0.6 + 0.4 * math.sin(t * 5)

        if inZone then
            -- 条带背景高亮
            local grad = nvgLinearGradient(vg, laneLeft, bandCY, laneRight, bandCY,
                nvgRGBA(255, 120, 40, math.floor(55 * pulse)),
                nvgRGBA(255, 80, 20, math.floor(20 * pulse)))
            nvgBeginPath(vg)
            nvgRect(vg, laneLeft, bandTop, laneW, bandBot - bandTop)
            nvgFillPaint(vg, grad); nvgFill(vg)

            -- 条带边框
            nvgBeginPath(vg)
            nvgRect(vg, laneLeft, bandTop, laneW, bandBot - bandTop)
            nvgStrokeColor(vg, nvgRGBA(255, 140, 60, math.floor(pulseAlpha * 0.8)))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

            -- 箭头指示 (横屏: 从左向右的方向箭头)
            local arrowY = bandCY
            for ax = laneLeft + 40, laneRight - 20, 80 do
                local aAlpha = math.floor(120 * pulse * ((ax - laneLeft) / laneW))
                nvgBeginPath(vg)
                nvgMoveTo(vg, ax - 8, arrowY - 8)
                nvgLineTo(vg, ax + 4, arrowY)
                nvgLineTo(vg, ax - 8, arrowY + 8)
                nvgStrokeColor(vg, nvgRGBA(255, 200, 100, math.max(30, aAlpha)))
                nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            end
        else
            -- 超出范围: 淡色提示
            nvgBeginPath(vg)
            nvgRect(vg, laneLeft, bandTop, laneW, bandBot - bandTop)
            nvgFillColor(vg, nvgRGBA(150, 130, 110, math.floor(15 * pulse)))
            nvgFill(vg)
        end

        -- 技能名 (横屏: 显示在条带左侧)
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, pulseAlpha))
            nvgText(vg, laneLeft - 6, bandCY, skill.name, nil)
        end
    elseif skill.skillType == "rect" then
        -- ======== 矩形技能瞄准: 矩形范围框 ========
        local rw, rh = skill.rectW, skill.rectH
        local rx, ry = tx - rw / 2, ty - rh / 2
        local pulse = 0.6 + 0.4 * math.sin(t * 5)

        nvgBeginPath(vg); nvgRect(vg, rx, ry, rw, rh)
        nvgStrokeWidth(vg, 1.5)
        if inZone then
            nvgStrokeColor(vg, nvgRGBA(255, 120, 40, pulseAlpha))
            -- 填充淡色渐变
            local fill = nvgLinearGradient(vg, rx, ry, rx, ry + rh,
                nvgRGBA(255, 100, 30, math.floor(50 * pulse)),
                nvgRGBA(255, 60, 10, math.floor(15 * pulse)))
            nvgFillPaint(vg, fill); nvgFill(vg)
        else
            nvgStrokeColor(vg, nvgRGBA(180, 150, 130, math.floor(pulseAlpha * 0.5)))
        end
        nvgStroke(vg)

        -- 十字准星
        local crossSize = 10
        nvgBeginPath(vg)
        nvgMoveTo(vg, tx - crossSize, ty); nvgLineTo(vg, tx + crossSize, ty)
        nvgMoveTo(vg, tx, ty - crossSize); nvgLineTo(vg, tx, ty + crossSize)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, pulseAlpha))
        nvgStrokeWidth(vg, 1.0); nvgStroke(vg)

        -- 技能名
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, pulseAlpha))
            nvgText(vg, tx, ry - 6, skill.name, nil)
        end
    else
        -- ======== AOE技能瞄准: 范围圈 ========
        -- 范围圈
        nvgBeginPath(vg); nvgCircle(vg, tx, ty, skill.radius)
        nvgStrokeWidth(vg, 1.5)
        if inZone then
            nvgStrokeColor(vg, nvgRGBA(255, 120, 40, pulseAlpha))
            -- 填充淡色
            local fill = nvgRadialGradient(vg, tx, ty, 5, skill.radius,
                nvgRGBA(255, 100, 30, math.floor(40 * (0.6 + 0.4 * math.sin(t * 5)))),
                nvgRGBA(255, 60, 10, 0))
            nvgFillPaint(vg, fill); nvgFill(vg)
        else
            nvgStrokeColor(vg, nvgRGBA(180, 150, 130, math.floor(pulseAlpha * 0.5)))
        end
        nvgStroke(vg)

        -- 十字准星
        local crossSize = 10
        nvgBeginPath(vg)
        nvgMoveTo(vg, tx - crossSize, ty); nvgLineTo(vg, tx + crossSize, ty)
        nvgMoveTo(vg, tx, ty - crossSize); nvgLineTo(vg, tx, ty + crossSize)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, pulseAlpha))
        nvgStrokeWidth(vg, 1.0); nvgStroke(vg)

        -- 技能名
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, pulseAlpha))
            nvgText(vg, tx, ty - skill.radius - 6, skill.name, nil)
        end
    end
end


-- ============================================================================
-- 渲染主流程
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if not vg then return end

    local g = GetGraphics()
    local physW = g:GetWidth()
    local physH = g:GetHeight()
    local dpr = g:GetDPR()

    -- DPR 安全校验：部分华为/鸿蒙设备可能返回异常值
    if dpr ~= dpr or dpr <= 0 then dpr = 1.0 end  -- NaN/负值/零 → 回退1.0
    if dpr > 4.0 then dpr = 3.0 end                -- 目前无 DPR>4 的手机

    screenW = physW / dpr
    screenH = physH / dpr

    -- 首帧设备诊断日志（帮助定位华为等设备的兼容性问题）
    if not _deviceInfoLogged then
        _deviceInfoLogged = true
        local rawDpr = g:GetDPR()
        print(string.format("[DeviceInfo] physW=%d physH=%d rawDPR=%.3f usedDPR=%.3f logW=%.1f logH=%.1f",
            physW, physH, rawDpr, dpr, screenW, screenH))
        local platform = GetPlatform and GetPlatform() or "unknown"
        print(string.format("[DeviceInfo] platform=%s designW=%d designH=%d", platform, DESIGN_W, DESIGN_H))
    end

    -- 战斗界面预留底部商店区域，其他界面全屏
    local isBattle = (gameState.phase == "BATTLE" or gameState.phase == "WIN" or gameState.phase == "LOSE" or gameState.phase == "SHOP")
    local reservedH = isBattle and SHOP_RESERVED_H or 0
    local availH = screenH - reservedH
    local scaleX = screenW / DESIGN_W
    local scaleY = availH / DESIGN_H
    scale = math.min(scaleX, scaleY)
    offsetX = (screenW - DESIGN_W * scale) / 2
    offsetY = (availH - DESIGN_H * scale) / 2

    -- 布局安全限制：防止部分设备因分辨率报告异常导致面板过度下移
    -- 正常手机 offsetY 一般不超过 screenH 的 15%
    local maxOffsetY = screenH * 0.18
    if offsetY > maxOffsetY then
        if not _layoutWarnLogged then
            _layoutWarnLogged = true
            print(string.format("[LayoutWarn] offsetY=%.1f > max=%.1f, clamped. physW=%d physH=%d dpr=%.3f scaleX=%.4f scaleY=%.4f scale=%.4f",
                offsetY, maxOffsetY, physW, physH, dpr, scaleX, scaleY, scale))
        end
        offsetY = maxOffsetY
    end
    if offsetX > screenW * 0.18 then
        offsetX = screenW * 0.18
    end

    -- 刘海屏安全区: 物理像素 >> 逻辑像素 >> 设计坐标
    local safeRect = GetSafeAreaInsets(false)
    if safeRect then
        safeInsets.top    = (safeRect.min.y / dpr) / scale
        safeInsets.bottom = (safeRect.max.y / dpr) / scale
        safeInsets.left   = (safeRect.min.x / dpr) / scale
        safeInsets.right  = (safeRect.max.x / dpr) / scale
    end

    CalcShopLayout()

    -- 将屏幕尺寸传递给 EquipUI overlay（避免全局事件中 graphics 返回错误值）
    if EquipUI then
        EquipUI._physW = physW
        EquipUI._physH = physH
        EquipUI._dpr = dpr
        EquipUI._logW = screenW
        EquipUI._logH = screenH
    end

    nvgBeginFrame(vg, physW, physH, dpr)
    nvgSave(vg)

    -- 黑色底色
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(28, 24, 38, 255)); nvgFill(vg)

    -- 字体预热：用透明色渲染常用字符，避免后续首次显示时卡顿（尤其高DPI华为设备）
    if not fontsWarmed and fontId >= 0 then
        nvgSave(vg)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 0))  -- 完全透明，不可见
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local warmStr = "三国武灵录正在加载请稍候0123456789%讨伐将启"
            .. "确定取消返回开始继续退出设置保存装备背包技能商店"
            .. "排位讨伐挑战关卡胜利失败战斗等级经验金币钻石体力"
            .. "攻击防御生命暴击闪避速度选择头像道号蚀骨幽火白骨"
            .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        local warmFonts = { fontId, fontArt, fontGame, fontKai, fontFZ }
        local warmedCount = 0
        for _, fid in ipairs(warmFonts) do
            if fid and fid >= 0 then
                nvgFontFaceId(vg, fid)
                nvgFontSize(vg, 24)
                nvgText(vg, -9999, -9999, warmStr, nil)  -- 屏幕外渲染
                warmedCount = warmedCount + 1
            end
        end
        -- 只有至少主字体预热成功才标记完成
        if warmedCount > 0 then
            fontsWarmed = true
        end
        nvgRestore(vg)
    end

    -- === LOADING 界面 (屏幕逻辑坐标，不用设计坐标) ===
    if gameState.phase == "LOADING" then
        local cx = screenW / 2
        local cy = screenH / 2
        local t = menuAnimTimer

        -- 游戏标题 (行书字体)
        nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 标题投影
        nvgFontSize(vg, 30)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
        nvgText(vg, cx + 2, cy - 35 + 2, "三国武灵录", nil)
        -- 标题主层
        DrawWhiteInkText(cx, cy - 35, "三国武灵录")

        -- 进度条
        local barW = screenW * 0.6
        local barH = 8
        local barX = cx - barW / 2
        local barY = cy + 10
        local pct = blockingLoadState.progress or 0

        -- 进度条背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW, barH, 4)
        nvgFillColor(vg, nvgRGBA(40, 40, 55, 200)); nvgFill(vg)

        -- 进度填充
        local fillW = barW * pct
        if fillW > 1 then
            local grad = nvgLinearGradient(vg, barX, barY, barX + fillW, barY,
                nvgRGBA(180, 150, 90, 220), nvgRGBA(220, 190, 120, 220))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, fillW, barH, 4)
            nvgFillPaint(vg, grad); nvgFill(vg)
        end

        -- 进度文字
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(215, 190, 120, 220))
        local loadText = string.format("正在加载 %d%%", math.floor(pct * 100))
        nvgText(vg, cx, barY + barH + 8, loadText, nil)

        -- 底部提示 (呼吸)
        local tipAlpha = math.floor(100 + 60 * math.sin(t * 2.0))
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(140, 130, 110, tipAlpha))
        nvgText(vg, cx, barY + barH + 32, "讨伐将启，请稍候...", nil)

        -- 具体进度数字
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(120, 115, 100, 160))
        local detailText = string.format("(%d/%d)", blockingLoadState.completedCount or 0, blockingLoadState.totalCount or 0)
        nvgText(vg, cx, barY + barH + 50, detailText, nil)

        -- 点击提示（玩家点击屏幕时显示）
        if loadingClickTipTimer and loadingClickTipTimer > 0 then
            local tipA = math.min(1, loadingClickTipTimer / 0.3)
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 120, math.floor(220 * tipA)))
            nvgText(vg, cx, cy + 80, "资源加载中，请耐心等待~", nil)
        end

        nvgRestore(vg)
        nvgEndFrame(vg)
        return  -- LOADING 阶段不渲染其他内容
    end

    -- === SERVER_SELECT 界面 (屏幕逻辑坐标) ===
    if gameState.phase == "SERVER_SELECT" then
        local cx = screenW / 2
        local cy = screenH / 2
        local t = menuAnimTimer

        -- 背景渐变
        local bgGrad = nvgLinearGradient(vg, 0, 0, 0, screenH,
            nvgRGBA(18, 14, 28, 255), nvgRGBA(35, 28, 50, 255))
        nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
        nvgFillPaint(vg, bgGrad); nvgFill(vg)

        -- 装饰底纹 (微弱网格)
        nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 12))
        nvgStrokeWidth(vg, 0.5)
        for gx = 0, screenW, 40 do
            nvgBeginPath(vg); nvgMoveTo(vg, gx, 0); nvgLineTo(vg, gx, screenH); nvgStroke(vg)
        end
        for gy = 0, screenH, 40 do
            nvgBeginPath(vg); nvgMoveTo(vg, 0, gy); nvgLineTo(vg, screenW, gy); nvgStroke(vg)
        end

        nvgFontFaceId(vg, GetMainFont())

        -- 标题
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 28)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
        nvgText(vg, cx + 1.5, cy - screenH * 0.32 + 1.5, "三国武灵录", nil)
        DrawWhiteInkText(cx, cy - screenH * 0.32, "三国武灵录")

        -- 副标题
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(180, 165, 130, 180))
        nvgText(vg, cx, cy - screenH * 0.32 + 24, "— 选择服务器 —", nil)

        -- 玩家 UID
        local uid = GetMyUid()
        if uid > 0 then
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(140, 130, 110, 140))
            nvgText(vg, screenW - 12, 8, "UID: " .. tostring(uid), nil)
        end

        -- 服务器卡片
        local cardW = math.min(280, screenW * 0.7)
        local cardH = 56
        local gap = 14
        local totalH = #SERVER_LIST * cardH + (#SERVER_LIST - 1) * gap
        local startY = cy - totalH / 2 - 8

        serverSelectRects = serverSelectRects or {}

        for i, sv in ipairs(SERVER_LIST) do
            local y = startY + (i - 1) * (cardH + gap)
            local x = cx - cardW / 2
            local selected = (gameState.selectedServer == sv.id)

            -- 卡片存储点击区域
            serverSelectRects[i] = { x = x, y = y, w = cardW, h = cardH, serverId = sv.id }

            -- 卡片背景
            nvgBeginPath(vg); nvgRoundedRect(vg, x, y, cardW, cardH, 8)
            if selected then
                local selGrad = nvgLinearGradient(vg, x, y, x + cardW, y + cardH,
                    nvgRGBA(60, 50, 35, 230), nvgRGBA(45, 38, 28, 230))
                nvgFillPaint(vg, selGrad); nvgFill(vg)
                -- 金色边框
                nvgStrokeColor(vg, nvgRGBA(220, 190, 120, 200))
                nvgStrokeWidth(vg, 2.0); nvgStroke(vg)
                -- 外发光
                local glowA = math.floor(25 + 15 * math.sin(t * 3))
                nvgBeginPath(vg); nvgRoundedRect(vg, x - 3, y - 3, cardW + 6, cardH + 6, 10)
                nvgStrokeColor(vg, nvgRGBA(220, 190, 120, glowA))
                nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            else
                nvgFillColor(vg, nvgRGBA(35, 30, 45, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(100, 90, 75, 80))
                nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
            end

            -- 服务器名
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 18)
            if selected then
                nvgFillColor(vg, nvgRGBA(240, 220, 160, 255))
            else
                nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
            end
            nvgText(vg, x + 18, y + cardH / 2, sv.name, nil)

            -- 状态标签
            local tagText = sv.desc
            local tagColor
            if sv.status == "hot" then
                tagColor = { 220, 80, 60 }
            elseif sv.status == "new" then
                tagColor = { 80, 180, 120 }
            else
                tagColor = { 140, 130, 120 }
            end
            local tagW = 36
            local tagH = 18
            local tagX = x + cardW - tagW - 14
            local tagY = y + (cardH - tagH) / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, tagX, tagY, tagW, tagH, 4)
            nvgFillColor(vg, nvgRGBA(tagColor[1], tagColor[2], tagColor[3], 40)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(tagColor[1], tagColor[2], tagColor[3], 120))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(tagColor[1], tagColor[2], tagColor[3], 220))
            nvgText(vg, tagX + tagW / 2, tagY + tagH / 2, tagText, nil)

            -- 选中对勾
            if selected then
                nvgFontSize(vg, 16)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(220, 190, 120, 240))
                nvgText(vg, tagX - 8, y + cardH / 2, ">>", nil)
            end
        end

        -- "进入游戏" 按钮
        local btnW = math.min(200, screenW * 0.5)
        local btnH = 40
        local btnX = cx - btnW / 2
        local btnY = startY + totalH + 28
        serverSelectEnterRect = { x = btnX, y = btnY, w = btnW, h = btnH }

        local canEnter = (gameState.selectedServer ~= nil)
        if canEnter then
            local btnPulse = 0.85 + 0.15 * math.sin(t * 2.5)
            local btnGrad = nvgLinearGradient(vg, btnX, btnY, btnX + btnW, btnY + btnH,
                nvgRGBA(math.floor(180 * btnPulse), math.floor(150 * btnPulse), math.floor(80 * btnPulse), 240),
                nvgRGBA(math.floor(140 * btnPulse), math.floor(110 * btnPulse), math.floor(50 * btnPulse), 240))
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 6)
            nvgFillPaint(vg, btnGrad); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(230, 200, 130, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 18)
            nvgFillColor(vg, nvgRGBA(255, 245, 220, 255))
            nvgText(vg, cx, btnY + btnH / 2, "进入游戏", nil)
        else
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 6)
            nvgFillColor(vg, nvgRGBA(40, 35, 50, 160)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 80)); nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 18)
            nvgFillColor(vg, nvgRGBA(120, 110, 100, 120))
            nvgText(vg, cx, btnY + btnH / 2, "请选择服务器", nil)
        end

        -- 底部提示
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(vg, nvgRGBA(110, 100, 85, 100))
        nvgText(vg, cx, screenH - 10, "每服同时在线上限 2000 人", nil)

        nvgRestore(vg)
        nvgEndFrame(vg)
        return  -- SERVER_SELECT 阶段不渲染其他内容
    end

    -- === 游戏区域 (设计坐标) ===
    nvgSave(vg)
    nvgTranslate(vg, offsetX, offsetY)
    nvgScale(vg, scale, scale)

    if gameState.phase == "PROFILE" then
        DrawProfileScreen()
        DrawFloatTexts()
    elseif gameState.phase == "MENU" then
        if settingsPage.btnAdjustMode then
            DrawBtnAdjustMode()
        else
            DrawMenuScreen()
            DrawFloatTexts()
            if settingsPage.isOpen then DrawSettingsScreen() end
            if cdkState.inputOpen then DrawCDKPopup() end
            DrawPowerExplainPopup()  -- 战力说明弹窗
        end
    -- elseif gameState.phase == "GACHA" then  -- 已移除抽卡系统
    --     DrawGachaScreen()
    --     DrawFloatTexts()
    elseif gameState.phase == "CODEX" then
        DrawCodexScreen()
        DrawFloatTexts()
    elseif gameState.phase == "HERO_DETAIL" then
        DrawHeroDetailScreen()
        DrawFloatTexts()
    elseif gameState.phase == "PLAYER_DETAIL" then
        DrawPlayerDetailScreen()
        DrawFloatTexts()
        DrawPowerExplainPopup()  -- 战力说明弹窗 (覆盖在详情上层)
    elseif gameState.phase == "SKILL_CODEX" then
        DrawSkillCodexScreen()
        DrawFloatTexts()
    elseif gameState.phase == "SKILL_DETAIL" then
        DrawSkillDetailScreen()
        DrawFloatTexts()
    elseif gameState.phase == "WELFARE" then
        DrawWelfareScreen()
        DrawFloatTexts()
    elseif gameState.phase == "PROGRESS" then
        DrawDailyTasksAndAchievements()
        DrawFloatTexts()
    elseif gameState.phase == "EQUIP" then
        DrawEquipScreen()
    elseif gameState.phase == "EQUIP_CODEX" then
        DrawEquipCodexScreen()
    elseif gameState.phase == "SEAL_MGR" then
        DrawSealMgrScreen()
        DrawFloatTexts()
    elseif gameState.phase == "MAIL_BOX" then
        DrawMailBoxScreen()
        DrawFloatTexts()
    elseif gameState.phase == "POWER_RANK" then
        DrawPowerRankScreen()
        DrawFloatTexts()
    elseif gameState.phase == "TRADE" then
        DrawTradeScreen()
        DrawFloatTexts()
    elseif gameState.phase == "FACTION" then
        DrawFactionScreen()
        DrawFloatTexts()
    elseif gameState.phase == "FRIENDS" then
        DrawFriendsScreen()
        DrawFloatTexts()
    elseif gameState.phase == "FORMATION" then
        DrawFormationScreen()
        DrawFloatTexts()
    elseif gameState.phase == "CONTRIB_RANK" then
        DrawContribRankScreen()
        DrawFloatTexts()
    elseif gameState.phase == "WORLD_MAP" then
        DrawWorldMapScreen()
        WorldMap.DrawMarch()
        WorldMap.DrawGuide()
        DrawFloatTexts()
    --[=[ 已移除关卡/副本系统
    elseif gameState.phase == "STAGE_SELECT" then
        DrawStageSelectScreen()
        DrawFloatTexts()
    elseif gameState.phase == "DAILY_DUNGEON" then
        DrawDailyDungeonScreen()
        DrawFloatTexts()
    elseif gameState.phase == "RESOURCE_DUNGEON" then
        DrawResourceDungeonScreen()
        DrawFloatTexts()
    --]=]
    elseif gameState.phase == "BATTLE_PASS" then
        DrawBattlePassScreen()
        DrawFloatTexts()
    --[=[ 已移除: 讨伐/爬塔/排位/探索
    elseif gameState.phase == "ABYSS_SELECT" then
        DrawAbyssSelectScreen()
        DrawFloatTexts()
    elseif gameState.phase == "EXPLORATION" then
        Exploration.Draw(DESIGN_W, DESIGN_H, gameState.gameTime)
        DrawFloatTexts()
    elseif gameState.phase == "TOWER_SELECT" then
        DrawTowerSelectScreen()
        DrawFloatTexts()
    elseif gameState.phase == "RANKED_SELECT" then
        DrawRankedSelectScreen()
        DrawFloatTexts()
    --]=]
    elseif gameState.phase == "DUMMY_SELECT" then
        DrawDummySelectScreen()
        DrawFloatTexts()
    elseif gameState.phase == "DUMMY_RESULT" then
        DrawDummyResultScreen()
        DrawFloatTexts()
    elseif gameState.phase == "DEV_EDITOR" then
        DrawDevEditorScreen()
        DrawFloatTexts()
        DrawFloatTexts()
    else
        DrawBackground()
        DrawCriticalLines()
        DrawLaneDividers()
        DrawTerrainZones()       -- 地形区块 (底层, 在单位之下)
        DrawBaseHPBars()
        DrawGroundSkillEffects() -- 底层技能特效 (在单位之下, 如治疗法阵)
        DrawBattleUnits()
        DrawCardSlots()          -- 武将卡牌 (石台上的武灵卡)
        DrawSkillEffects()       -- 武技技能特效 (在单位之上)
        DrawSkillTargetingDesign()  -- 技能瞄准指示器
        DrawParticles()
        UpdateAndDrawProjectiles(time:GetTimeStep())
        DrawHUD()
        DrawBattleButtons()  -- 右侧按钮在设计坐标空间绘制
        DrawBottomActionBar()  -- 右下角操作栏(武技技能)
        DrawRTSClassBar()     -- 底部RTS兵种选择栏+指令按钮
        DrawFloatTexts()
        DrawGameResultOverlay()
        DrawRewardPopup()
        DrawExploreExitConfirmPopup()  -- 探索退出/死亡确认弹窗
        DrawBattleRulesPopup()  -- 战斗规则弹窗
        -- DrawSkillInfoPopup()    -- 已移除武技详情弹窗 (改为按下即拖拽)
    end

    -- === 统一规则弹窗 (叠加在所有界面之上) ===
    DrawPhaseRulePopup()

    nvgRestore(vg)

    -- === 以下全部在屏幕逻辑坐标 ===
    -- 三国群英传模式: 移除商店/卡牌拖拽/信息面板

    -- 全局 Toast 提示（覆盖在最上层）
    DrawToast(DESIGN_W, DESIGN_H)

    -- 云数据加载中遮罩（半透明，显示加载提示）
    if CloudManager.IsCloudLoading() then
        local cW, cH = DESIGN_W, DESIGN_H
        nvgBeginPath(vg); nvgRect(vg, 0, 0, cW, cH)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
        -- 加载提示框
        local boxW, boxH = 260, 80
        local boxX, boxY = (cW - boxW) / 2, (cH - boxH) / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 12)
        nvgFillColor(vg, nvgRGBA(30, 30, 40, 230)); nvgFill(vg)
        -- 旋转加载点动画
        local dotPhase = (os.clock() * 3) % 3
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 220, 220, 255))
        local dots = dotPhase < 1 and "." or (dotPhase < 2 and ".." or "...")
        nvgText(vg, cW / 2, cH / 2, "正在同步云端数据" .. dots)
    end

    -- 封禁全屏遮罩（最高层级，阻止一切操作）
    if gameState.isBanned then
        local bW, bH = DESIGN_W, DESIGN_H
        nvgBeginPath(vg); nvgRect(vg, 0, 0, bW, bH)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 220)); nvgFill(vg)

        local bcx, bcy = bW / 2, bH / 2
        -- 红色警告框
        local boxW, boxH = 380, 160
        local boxX, boxY = bcx - boxW / 2, bcy - boxH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 14)
        nvgFillColor(vg, nvgRGBA(40, 10, 10, 240)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 60, 60, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 100, 100, 255))
        nvgText(vg, bcx, boxY + 40, "账号已封禁", nil)

        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(220, 200, 200, 220))
        nvgText(vg, bcx, boxY + 75, "您的账户经检测数据异常，已暂时被封禁", nil)
        nvgText(vg, bcx, boxY + 100, "请联系版主处理", nil)

        nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(150, 150, 160, 160))
        nvgText(vg, bcx, boxY + 130, "如有疑问请通过社区反馈", nil)
    end

    nvgRestore(vg)
    nvgEndFrame(vg)
end


-- ============================================================================
-- 背景
-- ============================================================================

function DrawBackground()
    -- 统一走 BATTLE_LAYOUTS 背景 (InitBattle 中已设置 currentLayoutIdx)
    local bgHandle = nil
    if currentLayoutIdx and BATTLE_LAYOUTS[currentLayoutIdx] then
        bgHandle = BATTLE_LAYOUTS[currentLayoutIdx].bgHandle
    end

    if not bgHandle or not IsImageReady(bgHandle) then
        -- 无背景图(默认战场)或图片未就绪: 绘制纯色深色背景
        nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
        nvgFillColor(vg, nvgRGBA(22, 18, 30, 255)); nvgFill(vg)
        -- 如果有图但还在加载中，显示加载动画
        if bgHandle and not IsImageReady(bgHandle) then
            DrawSpinner(DESIGN_W / 2, DESIGN_H / 2, 20)
            return
        end
    else
        -- 有背景图: 横版战斗背景 1024×571 (BG_W×BG_H = DESIGN_W×DESIGN_H)，直接铺满
        local p = nvgImagePattern(vg, 0, 0, DESIGN_W, DESIGN_H, 0, bgHandle, 1.0)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
        nvgFillPaint(vg, p); nvgFill(vg)
    end

    -- ★ 横屏战场遮罩: 左右添加暗色渐变, 确保石台卡牌区清晰可见
    -- 左侧玩家区 (X 0~80): 从左往右渐变, 暗→透明
    local leftZoneW = 80
    local leftGrad = nvgLinearGradient(vg, 0, 0, leftZoneW, 0,
        nvgRGBA(18, 12, 28, 120), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, leftZoneW, DESIGN_H)
    nvgFillPaint(vg, leftGrad); nvgFill(vg)

    -- 右侧敌方区 (X 940~1024): 从右往左渐变, 暗→透明
    local rightStart = DESIGN_W - 84
    local rightGrad = nvgLinearGradient(vg, DESIGN_W, 0, rightStart, 0,
        nvgRGBA(18, 12, 28, 140), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, rightStart, 0, DESIGN_W - rightStart, DESIGN_H)
    nvgFillPaint(vg, rightGrad); nvgFill(vg)
end


-- ============================================================================
-- 临界线 (突破扣血线)
-- ============================================================================

function DrawCriticalLines()
    local t = gameState.gameTime
    local bz = BATTLE_ZONE

    -- 敌方临界线 (横屏: 右侧垂直线, 绿色 — 玩家兵到达此处扣敌方血)
    local ePulse = 0.4 + 0.3 * math.sin(t * 3)
    local eLineX = bz.enemyLine
    -- 渐变发光带
    local eGlow = nvgLinearGradient(vg, eLineX - 6, 0, eLineX + 6, 0,
        nvgRGBA(80, 255, 150, 0),
        nvgRGBA(80, 255, 150, math.floor(25 * ePulse)))
    nvgBeginPath(vg); nvgRect(vg, eLineX - 6, bz.top, 12, bz.bottom - bz.top)
    nvgFillPaint(vg, eGlow); nvgFill(vg)
    -- 主线
    nvgBeginPath(vg)
    nvgMoveTo(vg, eLineX, bz.top + 10); nvgLineTo(vg, eLineX, bz.bottom - 10)
    nvgStrokeColor(vg, nvgRGBA(80, 255, 150, math.floor(50 + 40 * ePulse)))
    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

    -- 玩家临界线 (横屏: 左侧垂直线, 红色 — 敌方兵到达此处扣玩家血)
    local pPulse = 0.4 + 0.3 * math.sin(t * 3 + 1.5)
    local pLineX = bz.playerLine
    -- 渐变发光带
    local pGlow = nvgLinearGradient(vg, pLineX - 6, 0, pLineX + 6, 0,
        nvgRGBA(255, 80, 60, math.floor(25 * pPulse)),
        nvgRGBA(255, 80, 60, 0))
    nvgBeginPath(vg); nvgRect(vg, pLineX - 6, bz.top, 12, bz.bottom - bz.top)
    nvgFillPaint(vg, pGlow); nvgFill(vg)
    -- 主线
    nvgBeginPath(vg)
    nvgMoveTo(vg, pLineX, bz.top + 10); nvgLineTo(vg, pLineX, bz.bottom - 10)
    nvgStrokeColor(vg, nvgRGBA(255, 80, 60, math.floor(50 + 40 * pPulse)))
    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
end


-- ============================================================================
-- 车道分割线 (战斗中显示, 设计坐标)
-- ============================================================================

function DrawLaneDividers()
    if gameState.battlePhase ~= "FIGHT" then return end

    local bz = BATTLE_ZONE
    local t = gameState.gameTime

    -- 检测拖拽悬停车道 (横屏: 车道沿Y轴排列, 用ddy检测)
    local highlightLane = 0
    local isDraggingSlot = dragState.active and dragState.fromSlot and dragState.card
    if isDraggingSlot then
        local ddx, ddy = LogicalToDesign(dragState.lx, dragState.ly)
        local hitMarginLane = 60
        if ddx >= bz.playerLine - hitMarginLane and ddx <= bz.enemyLine + hitMarginLane
           and ddy >= bz.top and ddy <= bz.bottom then
            highlightLane = math.floor((ddy - bz.top) / LANE_WIDTH) + 1
            highlightLane = math.max(1, math.min(NUM_LANES, highlightLane))
        end
    end

    -- 拖拽时显示所有车道背景 + 高亮悬停车道
    if isDraggingSlot then
        for i = 1, NUM_LANES do
            local laneY = bz.top + (i - 1) * LANE_WIDTH
            local laneW = bz.enemyLine - bz.playerLine
            nvgBeginPath(vg)
            nvgRect(vg, bz.playerLine, laneY, laneW, LANE_WIDTH)
            if i == highlightLane then
                -- 高亮车道: 明亮蓝色
                local pulse = 0.6 + 0.4 * math.sin(t * 4)
                nvgFillColor(vg, nvgRGBA(80, 180, 255, math.floor(45 * pulse)))
            else
                -- 其他车道: 淡色
                nvgFillColor(vg, nvgRGBA(100, 140, 180, 12))
            end
            nvgFill(vg)
        end
    end

    -- 绘制4条车道分割线 (横屏: 水平线, 5条车道有4条分割线)
    for i = 1, NUM_LANES - 1 do
        local ly = bz.top + i * LANE_WIDTH
        local isNearHighlight = (highlightLane > 0) and (i == highlightLane or i == highlightLane - 1)
        local alpha = isNearHighlight
            and math.floor(80 + 40 * math.sin(t * 3))
            or math.floor(18 + 8 * math.sin(t * 1.5 + i * 0.8))
        local lineW = isNearHighlight and 1.2 or 0.6

        -- 虚线效果 (水平)
        local dashLen = 8
        local gapLen = 6
        local x = bz.playerLine + 4
        while x < bz.enemyLine - 4 do
            local segEnd = math.min(x + dashLen, bz.enemyLine - 4)
            nvgBeginPath(vg)
            nvgMoveTo(vg, x, ly)
            nvgLineTo(vg, segEnd, ly)
            if isNearHighlight then
                nvgStrokeColor(vg, nvgRGBA(100, 200, 255, alpha))
            else
                nvgStrokeColor(vg, nvgRGBA(140, 180, 220, alpha))
            end
            nvgStrokeWidth(vg, lineW)
            nvgStroke(vg)
            x = segEnd + gapLen
        end
    end

    -- 车道编号 (拖拽时更明显, 横屏: 显示在左侧临界线旁)
    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        local lblSize = isDraggingSlot and 18 or 12
        nvgFontSize(vg, lblSize)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local laneNames = { "一", "二", "三", "四", "五" }
        for i = 1, NUM_LANES do
            local cy = GetLaneCenterY(i)
            if isDraggingSlot then
                local isHL = (i == highlightLane)
                local a = isHL and 220 or 90
                nvgFillColor(vg, nvgRGBA(isHL and 120 or 160, isHL and 220 or 180, 255, a))
                nvgText(vg, bz.playerLine - 12, cy, laneNames[i], nil)
            else
                nvgFillColor(vg, nvgRGBA(160, 180, 210, 40))
                nvgText(vg, bz.playerLine - 6, cy, tostring(i), nil)
            end
        end
    end
end


-- ============================================================================
-- 石台卡牌 (透明角色 + 品质底光)
-- ============================================================================

-- 根据卡牌返回对应的精灵图句柄 (所有武灵均为独立图)
function GetHeroSheet(card)
    if card.singleImg then return IMG[card.singleImg] or -1 end
    return -1
end


--- 获取无背景版精灵图 (石台上渲染用，武灵独立图复用原图)
function GetHeroSheetNoBg(card)
    if card.singleImg then return IMG[card.singleImg] or -1 end
    return -1
end


-- 返回精灵图句柄及其网格列数/行数 (所有武灵均为1×1独立图)
function GetHeroSheetInfo(card)
    return GetHeroSheet(card), 1, 1
end


--- 绘制单个程序化石台
function DrawSinglePlatform(cx, cy, w, h, colors, t)
    local r = 6      -- 圆角
    local sideH = 8  -- 侧面厚度
    local shadowOff = 4

    -- 1) 阴影 (模糊椭圆)
    local sc = colors.shadow
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy + sideH + shadowOff, w * 0.48, h * 0.22)
    nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 100))
    nvgFill(vg)

    -- 2) 侧面 (深色矩形, 表示石台厚度)
    local sd = colors.side
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w / 2, cy - h / 2 + sideH, w, h, r)
    nvgFillColor(vg, nvgRGBA(sd[1], sd[2], sd[3], 220))
    nvgFill(vg)
    -- 侧面底部高光线
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w / 2 + r, cy + h / 2 + sideH - 1)
    nvgLineTo(vg, cx + w / 2 - r, cy + h / 2 + sideH - 1)
    nvgStrokeColor(vg, nvgRGBA(sd[1] + 30, sd[2] + 30, sd[3] + 30, 80))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 3) 顶面 (渐变矩形, 从亮到暗)
    local tl = colors.topLight
    local td = colors.topDark
    local topGrad = nvgLinearGradient(vg,
        cx, cy - h / 2, cx, cy + h / 2,
        nvgRGBA(tl[1], tl[2], tl[3], 200),
        nvgRGBA(td[1], td[2], td[3], 210))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w / 2, cy - h / 2, w, h, r)
    nvgFillPaint(vg, topGrad)
    nvgFill(vg)

    -- 4) 顶面内部纹理线 (模拟石纹)
    nvgSave(vg)
    nvgScissor(vg, cx - w / 2, cy - h / 2, w, h)
    for li = 1, 3 do
        local offX = math.sin(li * 2.7 + cx * 0.1) * (w * 0.3)
        local offY = -h * 0.3 + li * (h * 0.25)
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - w / 2 + 4 + offX, cy - h / 2 + offY)
        nvgQuadTo(vg, cx + offX * 0.3, cy - h / 2 + offY + 6,
                      cx + w / 2 - 4 + offX * 0.5, cy - h / 2 + offY - 2)
        nvgStrokeColor(vg, nvgRGBA(tl[1] + 15, tl[2] + 15, tl[3] + 15, 25))
        nvgStrokeWidth(vg, 0.6)
        nvgStroke(vg)
    end
    nvgRestore(vg)

    -- 5) 阵营色边缘光 (顶面外描边 + 微弱脉动)
    local rm = colors.rim
    local pulse = 0.5 + 0.3 * math.sin((t or 0) * 2.0 + cx * 0.05)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w / 2, cy - h / 2, w, h, r)
    nvgStrokeColor(vg, nvgRGBA(rm[1], rm[2], rm[3], math.floor(50 * pulse)))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    -- 6) 顶面高光 (左上角微弱高光点)
    local hlGrad = nvgRadialGradient(vg,
        cx - w * 0.25, cy - h * 0.25, 2, w * 0.4,
        nvgRGBA(255, 255, 255, 30), nvgRGBA(255, 255, 255, 0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w / 2, cy - h / 2, w, h, r)
    nvgFillPaint(vg, hlGrad)
    nvgFill(vg)
end


function DrawSlotPlatforms()
    local layout = BATTLE_LAYOUTS[currentLayoutIdx] or BATTLE_LAYOUTS[1]
    local faction = layout.platformFaction or "shu"
    local colors = PLATFORM_COLORS[faction] or PLATFORM_COLORS.shu
    local platW = SLOT_CARD_W + 14
    local platH = SLOT_CARD_H + 12
    local t = gameState and gameState.gameTime or 0
    for _, slot in ipairs(ENEMY_SLOTS) do
        DrawSinglePlatform(slot.cx, slot.cy, platW, platH, colors, t)
    end
    for _, slot in ipairs(PLAYER_SLOTS) do
        DrawSinglePlatform(slot.cx, slot.cy, platW, platH, colors, t)
    end
end


function DrawCardSlots()
    -- DrawSlotPlatforms()  -- 石台已融入背景图
    for _, slot in ipairs(ENEMY_SLOTS) do DrawSlotCard(slot, false) end
    for _, slot in ipairs(PLAYER_SLOTS) do DrawSlotCard(slot, true) end
end


function DrawSlotCard(slot, isPlayer)
    local cx, cy = slot.cx, slot.cy
    local w, h = SLOT_CARD_W, SLOT_CARD_H

    if slot.filled and slot.card then
        local card = slot.card
        local t = gameState.gameTime
        local qg = QUALITY_GLOW[card.quality]
        local qc = QUALITY_COLORS[card.quality]

        -- 角色图 (使用原始带背景卡牌图)
        local useSheet, useRow, useCol, useCols, useRows
        -- 所有卡牌统一使用武灵独立图
        local _sh, _sc, _sr = GetHeroSheetInfo(card)
        useSheet = _sh; useRow = card.row; useCol = card.col
        useCols = _sc; useRows = _sr
        if useSheet and useSheet > 0 then
            DrawCardImage(cx - w / 2, cy - h / 2, w, h, useSheet, useRow, useCol, useCols, useRows)
        end

        -- 等阶标签 (N/R/SR/SSR, 左下角)
        if fontId >= 0 then
            local qTag = QUALITY_TAGS[card.quality] or "N"
            local qc2 = QUALITY_COLORS[card.quality] or { 200, 195, 180 }
            local tagW = #qTag > 2 and 24 or (#qTag > 1 and 18 or 12)
            local tagH = 11
            local tagX = cx - w / 2 + 1
            local tagY = cy + h / 2 - tagH - 1
            nvgBeginPath(vg); nvgRoundedRect(vg, tagX, tagY, tagW, tagH, 2)
            nvgFillColor(vg, nvgRGBA(qc2[1], qc2[2], qc2[3], 180)); nvgFill(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(tagX + tagW / 2, tagY + tagH / 2, qTag)
        end

        -- 等级标记 (Lv2+ 古铜标记)
        if fontId >= 0 and card.level and card.level > 1 then
            local lvW = 22
            local lvH = 10
            local lvX = cx - lvW / 2
            local lvY = cy - h / 2 - lvH - 1
            nvgBeginPath(vg); nvgRoundedRect(vg, lvX, lvY, lvW, lvH, 2)
            nvgFillColor(vg, nvgRGBA(20, 15, 5, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 210, 70, 60))
            nvgStrokeWidth(vg, 0.4); nvgStroke(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, lvY + lvH / 2, "Lv" .. card.level)
        end

        -- === 兵种徽章 (右下角, 战争版) ===
        if card.troopType and rawget(_G, "TROOP_TYPES") then
            local tt = TROOP_TYPES[card.troopType]
            if tt then
                local tbW, tbH = 14, 11
                local tbX = cx + w / 2 - tbW - 1
                local tbY = cy + h / 2 - tbH - 1
                nvgBeginPath(vg); nvgRoundedRect(vg, tbX, tbY, tbW, tbH, 2)
                nvgFillColor(vg, nvgRGBA(tt.color[1], tt.color[2], tt.color[3], 200)); nvgFill(vg)
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 12)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(tbX + tbW / 2, tbY + tbH / 2, tt.icon)
            end
        end

        -- 命格徽标 (C0不显示, C1+显示)
        local cons = card.constellation or 0
        if fontId >= 0 and cons > 0 then
            local cc = GameConfig.CONSTELLATION_COLORS[cons] or { 180, 175, 165 }
            local badgeR = 6
            local badgeX = cx + w / 2 - 2
            local badgeY = cy - h / 2 - 2
            nvgBeginPath(vg); nvgCircle(vg, badgeX, badgeY, badgeR)
            nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 150))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(badgeX, badgeY, "C" .. cons)
        end

        -- === 阵营标识 (战争版) ===
        -- 有命格时放在命格徽标左侧, 无命格时放在右上角
        if card.faction and rawget(_G, "FACTIONS") then
            local fc = FACTIONS[card.faction]
            if fc then
                local fbR = 5
                local fbX, fbY
                if cons > 0 then
                    -- 命格存在: 阵营标识挪到左上角
                    fbX = cx - w / 2 + 2
                    fbY = cy - h / 2 - 2
                else
                    -- 无命格: 占用右上角
                    fbX = cx + w / 2 - 2
                    fbY = cy - h / 2 - 2
                end
                nvgBeginPath(vg); nvgCircle(vg, fbX, fbY, fbR)
                nvgFillColor(vg, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 220)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(0, 0, 0, 100))
                nvgStrokeWidth(vg, 0.6); nvgStroke(vg)
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 10)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(fbX, fbY, fc.icon)
            end
        end

        -- 出兵计数 (战斗中显示)
        if slot.filled and card and fontId >= 0 and gameState.battlePhase == "FIGHT" then
            -- 出兵计数 (卡牌左上角醒目显示)
            local sc = slot.spawnCount or 0
            if sc > 0 then
                local isFlashing = slot.spawnFlash and slot.spawnFlash > 0
                local flashP = isFlashing and math.min(1, slot.spawnFlash / 0.3) or 0

                -- 出兵数字背景圆 (放在卡牌上方, 避免被精灵遮挡)
                local badgeX = cx - w / 2 + 6
                local badgeY = cy - h / 2 - 14
                local badgeR = 9 + (isFlashing and (4 * flashP) or 0)
                -- 闪光时放大+高亮
                nvgBeginPath(vg); nvgCircle(vg, badgeX, badgeY, badgeR)
                if isFlashing then
                    nvgFillColor(vg, nvgRGBA(80, 255, 120, math.floor(180 + 75 * flashP)))
                else
                    nvgFillColor(vg, nvgRGBA(40, 160, 80, 200))
                end
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(200, 255, 200, 180))
                nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

                -- 数字
                nvgFontFaceId(vg, GetMainFont())
                nvgFontSize(vg, isFlashing and 17 or 14)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(badgeX, badgeY, tostring(sc))

                -- 出兵闪光: 向上飘动的 "兵" 字动画
                if isFlashing then
                    local floatY = cy - h / 2 - 18 - (1 - flashP) * 20
                    local floatA = math.floor(220 * flashP)
                    nvgFontSize(vg, 16)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(120, 255, 160, floatA))
                    nvgText(vg, cx, floatY, "+1", nil)
                end
            end

            -- 部署冷却覆盖层 (己方卡牌, 冷却中暗化并显示倒计时)
            if isPlayer and slot.deployCD and slot.deployCD > 0 then
                -- 暗色遮罩
                nvgBeginPath(vg); nvgRoundedRect(vg, cx - w / 2, cy - h / 2, w, h, 3)
                nvgFillColor(vg, nvgRGBA(5, 5, 12, 110)); nvgFill(vg)

                -- 冷却进度环 (圆弧)
                local cdRatio = slot.deployCD / DEPLOY_CD
                local arcR = math.min(w, h) / 2 - 4
                nvgBeginPath(vg)
                nvgArc(vg, cx, cy, arcR, -math.pi / 2, -math.pi / 2 + cdRatio * math.pi * 2, 1)
                nvgStrokeColor(vg, nvgRGBA(255, 200, 100, 160))
                nvgStrokeWidth(vg, 2.5); nvgStroke(vg)

                -- CD倒计时数字
                if fontId >= 0 then
                    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    DrawWhiteInkText(cx, cy, string.format("%.1f", slot.deployCD))
                end
            end
        end
    end
end


-- 拖拽时的槽位高亮 (设计坐标, 用圆形匹配石台视觉)
function DrawSlotHighlights()
    if not dragState.active then return end
    local t = gameState.gameTime
    for _, slot in ipairs(PLAYER_SLOTS) do
        local pulse = 0.5 + 0.5 * math.sin(t * 5)
        -- 石台是近似圆形, 用圆形高亮匹配
        local r = SLOT_CARD_W / 2 + 3
        nvgBeginPath(vg); nvgCircle(vg, slot.cx, slot.cy, r)
        nvgStrokeColor(vg, nvgRGBA(255, 230, 100, math.floor(50 + 80 * pulse)))
        nvgStrokeWidth(vg, 1.8); nvgStroke(vg)
        -- 内圈微光
        local innerGrad = nvgRadialGradient(vg, slot.cx, slot.cy, r * 0.3, r,
            nvgRGBA(255, 230, 100, math.floor(15 * pulse)),
            nvgRGBA(255, 230, 100, 0))
        nvgBeginPath(vg); nvgCircle(vg, slot.cx, slot.cy, r)
        nvgFillPaint(vg, innerGrad); nvgFill(vg)
    end
end


-- 统一菜单背景（与首页相同：背景图 + 遮罩 + 渐变）
function DrawMenuBg(W, H)
    DrawBgImage(IMG.menuBg, W, H, 1376, 768, 0)
    -- 轻微暗色覆盖 (国风二次元，保持明亮)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 15)); nvgFill(vg)
    -- 底部轻微渐暗 (不遮挡底栏)
    local botGrad = nvgLinearGradient(vg, 0, H * 0.75, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(60, 40, 20, 40))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.75, W, H * 0.25)
    nvgFillPaint(vg, botGrad); nvgFill(vg)
    -- 顶部轻微渐暗 (让标题可读)
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, H * 0.10,
        nvgRGBA(60, 40, 20, 25), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H * 0.10)
    nvgFillPaint(vg, topGrad); nvgFill(vg)
end

-- 通用场景背景（指定图片 + 统一国风遮罩渐变）
local function DrawSceneBg(imgHandle, W, H)
    DrawBgImage(imgHandle or IMG.menuBg, W, H, 1376, 768, 0)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 12)); nvgFill(vg)
    local botGrad = nvgLinearGradient(vg, 0, H * 0.78, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(60, 40, 20, 35))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.78, W, H * 0.22)
    nvgFillPaint(vg, botGrad); nvgFill(vg)
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, H * 0.08,
        nvgRGBA(60, 40, 20, 20), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H * 0.08)
    nvgFillPaint(vg, topGrad); nvgFill(vg)
end

-- 图鉴/英雄/技能/装备背景
function DrawCodexBg(W, H)  DrawSceneBg(IMG.codexBg, W, H) end
-- 设置界面背景
function DrawSettingsBg(W, H) DrawSceneBg(IMG.settingsBg, W, H) end
-- 社交面板背景（邮件/好友/交易/势力）
function DrawSocialBg(W, H) DrawSceneBg(IMG.panelBg, W, H) end
-- 征途/战斗选择背景
function DrawCombatBg(W, H) DrawSceneBg(IMG.battleBgNew, W, H) end
-- 出征/部署背景
function DrawDeployBg(W, H) DrawSceneBg(IMG.deployBg, W, H) end
-- 福利/签到背景
function DrawWelfareBg(W, H) DrawSceneBg(IMG.homeBg, W, H) end


function DrawToast(W, H)
    if toastState.timer <= 0 then return end
    local alpha = math.min(1.0, toastState.timer * 3.0) -- 淡出
    local a = math.floor(alpha * 220)
    local msg = toastState.text
    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local tw = nvgTextBounds(vg, 0, 0, msg, nil) + 30
    local th = 36
    local tx = W / 2 - tw / 2
    local ty = H * 0.38
    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, tx, ty, tw, th, 8)
    nvgFillColor(vg, nvgRGBA(235, 215, 175, a)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, math.floor(alpha * 150)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    -- 文字
    nvgFillColor(vg, nvgRGBA(80, 40, 10, a))
    nvgText(vg, W / 2, ty + th / 2, msg, nil)
    nvgRestore(vg)
end


