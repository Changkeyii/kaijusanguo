-- ============================================================================
-- systems/td/td_render.lua - 塔防模式NanoVG渲染 (纯塔防重构版)
-- 用途: 高清背景、固定路径、固定塔位、武将、敌人、技能栏、能量条、HUD
-- ============================================================================
---@diagnostic disable: undefined-global

local TDData = require("systems.td.td_data")

local M = {}

-- ============================================================================
-- 工具: Cover-fit 图片绘制
-- ============================================================================
local function DrawImageCover(imgHandle, dx, dy, dw, dh, alpha, radius)
    if not imgHandle or imgHandle <= 0 then return end
    alpha = alpha or 1.0
    radius = radius or 0
    local iw, ih = nvgImageSize(vg, imgHandle)
    if not iw or iw <= 0 then return end
    local scaleX = dw / iw
    local scaleY = dh / ih
    local scale = math.max(scaleX, scaleY)
    local pw = iw * scale
    local ph = ih * scale
    local px = dx + (dw - pw) / 2
    local py = dy + (dh - ph) / 2
    local pat = nvgImagePattern(vg, px, py, pw, ph, 0, imgHandle, alpha)
    nvgBeginPath(vg)
    if radius > 0 then
        nvgRoundedRect(vg, dx, dy, dw, dh, radius)
    else
        nvgRect(vg, dx, dy, dw, dh)
    end
    nvgFillPaint(vg, pat)
    nvgFill(vg)
end

-- ============================================================================
-- 精灵图工具
-- ============================================================================
local ENEMY_SPRITE_MAP = {
    infantry = "demon_warrior",
    archer   = "demon_archer",
    cavalry  = "demon_tank",
    spear    = "demon_warrior",
}

local function DrawUnitSprite(spriteKey, cx, cy, size, alpha)
    local img = IMG and IMG.unitSprites and IMG.unitSprites[spriteKey]
    if img and img > 0 then
        alpha = alpha or 1.0
        local half = size / 2
        DrawImageCover(img, cx - half, cy - half, size, size, alpha, 2)
        return true
    end
    return false
end

-- ============================================================================
-- 颜色常量
-- ============================================================================
local TROOP_CLR = {
    infantry = { 120, 160, 255 },
    archer   = { 80, 220, 120 },
    cavalry  = { 255, 180, 80 },
    spear    = { 200, 120, 255 },
}

-- ============================================================================
-- 主渲染入口
-- ============================================================================

function M.Draw()
    local st = tdState
    if not st then return end

    M.DrawMap()
    M.DrawPath()
    M.DrawPlaceableSlots()
    M.DrawBase()
    M.DrawGameObjectsSorted()
    M.DrawFlyingSwords()
    M.DrawSkillFX()
    M.DrawFloatTexts()
    M.DrawHUD()
    -- M.DrawSwordCD()  -- 旧飞剑CD已移除，飞剑通过技能栏释放
    M.DrawHeroBar()    -- 先画底部栏背景+武将槽
    M.DrawSkillBar()   -- 再画技能栏(在上层)
    M.DrawPhaseOverlay()
end

-- ============================================================================
-- 2.5D 地图背景
-- ============================================================================

function M.DrawMap()
    local DW = TDData.DESIGN_W
    local DH = TDData.DESIGN_H

    local bgImg = IMG and IMG.tdMapBg
    if bgImg and bgImg > 0 then
        DrawImageCover(bgImg, 0, 0, DW, DH, 1.0)
    else
        local skyPaint = nvgLinearGradient(vg, 0, 0, 0, DH,
            nvgRGBA(100, 180, 220, 255), nvgRGBA(60, 140, 100, 255))
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, DW, DH)
        nvgFillPaint(vg, skyPaint)
        nvgFill(vg)
    end
end

-- ============================================================================
-- 路径
-- ============================================================================

function M.DrawPath()
    local st = tdState
    if not st or not st.smoothPath or #st.smoothPath < 2 then return end

    if st.phase == "PREPARE" or st.phase == "WAVE_CLEAR" then
        nvgBeginPath(vg)
        nvgMoveTo(vg, st.smoothPath[1].x, st.smoothPath[1].y)
        for i = 2, #st.smoothPath do
            nvgLineTo(vg, st.smoothPath[i].x, st.smoothPath[i].y)
        end
        nvgStrokeColor(vg, nvgRGBA(255, 230, 160, 25))
        nvgStrokeWidth(vg, 3)
        nvgStroke(vg)
    end

    local ep = st.smoothPath[1]
    local flagImg = IMG and IMG.tdEntranceFlag
    if flagImg and flagImg > 0 then
        DrawImageCover(flagImg, ep.x - 12, ep.y - 28, 20, 20, 0.9, 2)
    end

    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(vg, nvgRGBA(255, 220, 140, 200))
        nvgText(vg, ep.x, ep.y - 22, "入口", nil)
    end
end

-- ============================================================================
-- 可放置塔位
-- ============================================================================

function M.DrawPlaceableSlots()
    local st = tdState
    if not st then return end

    local t = st.gameTime or 0
    local selecting = st.selectedHeroIdx > 0
    local repositioning = st.repositionMode

    for _, slot in ipairs(TDData.TOWER_SLOTS) do
        if not st.placedHeroMap[slot.key] then
            local cx, cy = slot.x, slot.y
            local r = 22

            local pulse = (selecting or repositioning) and (0.6 + 0.3 * math.sin(t * 3)) or 0.3
            nvgBeginPath(vg)
            nvgEllipse(vg, cx, cy, r, r * 0.55)
            nvgFillColor(vg, nvgRGBA(100, 90, 70, math.floor(100 * pulse)))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgEllipse(vg, cx, cy, r, r * 0.55)
            nvgStrokeColor(vg, nvgRGBA(180, 170, 140, math.floor(80 * pulse)))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)

            if selecting or repositioning then
                local hlClr = repositioning and {80, 160, 255} or {80, 220, 80}
                nvgBeginPath(vg)
                nvgEllipse(vg, cx, cy, r + 3, (r + 3) * 0.55)
                nvgStrokeColor(vg, nvgRGBA(hlClr[1], hlClr[2], hlClr[3],
                    math.floor(100 + 80 * math.sin(t * 3))))
                nvgStrokeWidth(vg, 2)
                nvgStroke(vg)
            end

            if fontId >= 0 and (selecting or repositioning) then
                nvgFontFaceId(vg, GetMainFont())
                nvgFontSize(vg, 9)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 60))
                nvgText(vg, cx, cy, slot.key, nil)
            end
        end
    end
end

-- ============================================================================
-- 基地
-- ============================================================================

function M.DrawBase()
    local st = tdState
    if not st or not st.smoothPath or #st.smoothPath == 0 then return end

    local lastPt = st.smoothPath[#st.smoothPath]
    local bx, by = lastPt.x, lastPt.y

    local castleImg = IMG and IMG.tdCastle
    local castleW = 60
    local castleH = 60
    if castleImg and castleImg > 0 then
        DrawImageCover(castleImg, bx - castleW / 2, by - castleH + 10, castleW, castleH, 1.0, 3)
    end

    local hpRatio = st.baseHP / st.baseMaxHP
    local barW = 50
    local barH = 5
    local barX = bx - barW / 2
    local barY = by - castleH + 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 2)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
    nvgFill(vg)
    local fillW = barW * hpRatio
    if fillW > 0 then
        local clrR = hpRatio > 0.5 and 80 or 220
        local clrG = hpRatio > 0.5 and 200 or 60
        local clrB = hpRatio > 0.5 and 120 or 60
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, fillW, barH, 2)
        nvgFillColor(vg, nvgRGBA(clrR, clrG, clrB, 230))
        nvgFill(vg)
    end

    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        local hClr = hpRatio > 0.5 and {80, 220, 120} or {255, 80, 80}
        nvgFillColor(vg, nvgRGBA(hClr[1], hClr[2], hClr[3], 240))
        nvgText(vg, bx, barY - 1, st.baseHP .. "/" .. st.baseMaxHP, nil)
    end
end

-- ============================================================================
-- 深度排序绘制 (移除troop)
-- ============================================================================

function M.DrawGameObjectsSorted()
    local st = tdState
    if not st then return end

    local drawList = {}

    for idx, hero in ipairs(st.heroes) do
        drawList[#drawList + 1] = { type = "hero", data = hero, y = hero.y, idx = idx }
    end

    for _, enemy in ipairs(st.enemies) do
        if not enemy.dead then
            drawList[#drawList + 1] = { type = "enemy", data = enemy, y = enemy.y }
        end
    end

    for _, p in ipairs(st.projectiles) do
        local t = p.timer / p.duration
        local cy = p.sy + (p.ty - p.sy) * t
        drawList[#drawList + 1] = { type = "proj", data = p, y = cy }
    end

    table.sort(drawList, function(a, b) return a.y < b.y end)

    for _, item in ipairs(drawList) do
        if item.type == "hero" then
            M.DrawSingleHero(item.data, item.idx)
        elseif item.type == "enemy" then
            M.DrawSingleEnemy(item.data)
        elseif item.type == "proj" then
            M.DrawSingleProjectile(item.data)
        end
    end
end

-- ============================================================================
-- 单个敌人绘制
-- ============================================================================

function M.DrawSingleEnemy(enemy)
    local st = tdState
    local gt = st.gameTime or 0

    local swayX = 0
    if enemy.swayPhase then
        swayX = math.sin(gt * 6 + enemy.swayPhase) * (enemy.swayAmp or 2)
    end

    local drawX = enemy.x + swayX
    local drawY = enemy.y

    -- 脚底阴影
    nvgBeginPath(vg)
    nvgEllipse(vg, drawX, drawY + 2, 10, 5)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 50))
    nvgFill(vg)

    local spriteSize = enemy.elite and 36 or 28
    local spriteKey = ENEMY_SPRITE_MAP[enemy.troop] or "demon_warrior"

    local spriteY = drawY - spriteSize * 0.55
    if not DrawUnitSprite(spriteKey, drawX, spriteY, spriteSize, 1.0) then
        local tc = TROOP_CLR[enemy.troop] or { 200, 200, 200 }
        nvgBeginPath(vg)
        nvgCircle(vg, drawX, spriteY, spriteSize / 2)
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 230))
        nvgFill(vg)
    end

    -- 精英金边
    if enemy.elite then
        nvgBeginPath(vg)
        nvgCircle(vg, drawX, spriteY, spriteSize / 2 + 2)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 80, 220))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
    end

    -- HP条
    local hpRatio = enemy.hp / enemy.maxHP
    if hpRatio < 1 then
        local barW = spriteSize + 4
        local barH = 3
        local barX = drawX - barW / 2
        local barY = spriteY - spriteSize / 2 - 5
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW, barH, 1.5)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW * hpRatio, barH, 1.5)
        nvgFillColor(vg, nvgRGBA(220, 60, 60, 230))
        nvgFill(vg)
    end

    -- 减速蓝圈指示
    if enemy.slowTimer and enemy.slowTimer > 0 then
        nvgBeginPath(vg)
        nvgCircle(vg, drawX, spriteY, spriteSize / 2 + 4)
        nvgStrokeColor(vg, nvgRGBA(80, 180, 255, 120))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)
    end

    -- 眩晕标记
    if enemy.stunTimer and enemy.stunTimer > 0 then
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(255, 255, 80, 200))
            nvgText(vg, drawX, spriteY - spriteSize / 2 - 8, "晕", nil)
        end
    end
end

-- ============================================================================
-- 单个武将绘制 (含HP条、死亡灰显、升级星标、聚焦)
-- ============================================================================

function M.DrawSingleHero(hero, idx)
    local st = tdState
    local card = hero.card
    local qc = QUALITY_COLORS and QUALITY_COLORS[card.quality] or { 200, 190, 170 }
    local cx, cy = hero.x, hero.y

    -- 死亡状态: 灰显
    local isDead = hero.dead
    local globalAlpha = isDead and 0.35 or 1.0

    nvgSave(vg)
    nvgGlobalAlpha(vg, globalAlpha)

    -- 1. 脚底椭圆阴影
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy + 3, 22, 9)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 70))
    nvgFill(vg)

    -- 2. 品质色底座光圈
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy + 2, 20, 8)
    nvgStrokeColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 180))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 聚焦高亮
    if st.focusedHeroIdx > 0 and st.heroes[st.focusedHeroIdx] == hero then
        nvgBeginPath(vg)
        nvgEllipse(vg, cx, cy + 2, 24, 10)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 100, math.floor(120 + 80 * math.sin((st.gameTime or 0) * 4))))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
    end

    -- 3. Q萌立绘
    local spriteH = 52
    local spriteW = 35
    local spriteTopY = cy - spriteH
    local imgH2 = GetHeroSheet and GetHeroSheet(card) or -1
    if imgH2 and imgH2 > 0 then
        local _sh, _sc, _sr = GetHeroSheetInfo(card)
        DrawCardImage(cx - spriteW / 2, spriteTopY, spriteW, spriteH, _sh, card.row, card.col, _sc, _sr, true)
    end

    -- 4. 武将名 + 升级星标
    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 240))
        local nameText = string.sub(card.name, 1, 4)
        if hero.level and hero.level > 1 then
            nameText = nameText .. " Lv" .. hero.level
        end
        nvgText(vg, cx, cy + 1, nameText, nil)
    end

    nvgRestore(vg)  -- 恢复globalAlpha

    -- 5. HP条 (在灰显之外绘制, 始终可见)
    if hero.maxHP and hero.maxHP > 0 then
        local hpRatio = (hero.currentHP or 0) / hero.maxHP
        hpRatio = math.max(0, math.min(1, hpRatio))
        local hpBarW = 32
        local hpBarH = 3
        local hpBarX = cx - hpBarW / 2
        local hpBarY = cy + 5
        nvgBeginPath(vg)
        nvgRoundedRect(vg, hpBarX, hpBarY, hpBarW, hpBarH, 1.5)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
        nvgFill(vg)
        if hpRatio > 0 then
            local hpClrR = hpRatio > 0.5 and 80 or 255
            local hpClrG = hpRatio > 0.5 and 220 or 80
            nvgBeginPath(vg)
            nvgRoundedRect(vg, hpBarX, hpBarY, hpBarW * hpRatio, hpBarH, 1.5)
            nvgFillColor(vg, nvgRGBA(hpClrR, hpClrG, 80, 220))
            nvgFill(vg)
        end
    end

    -- 6. 死亡: 复活倒计时
    if isDead and fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 80, 80, 220))
        local secs = math.ceil(hero.respawnTimer or 0)
        nvgText(vg, cx, cy - 20, secs .. "s", nil)
    end

    -- 7. 攻击范围 (选中时显示)
    if not isDead and st.focusedHeroIdx > 0 and st.heroes[st.focusedHeroIdx] == hero then
        local rangeR = hero.tdStats.atkRange
        nvgBeginPath(vg)
        nvgEllipse(vg, cx, cy, rangeR, rangeR * 0.55)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 100, 40))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
    end
end

-- ============================================================================
-- 弹道 (箭矢/技能弹道)
-- ============================================================================

function M.DrawSingleProjectile(p)
    local t = p.timer / p.duration
    local cx = p.sx + (p.tx - p.sx) * t
    local cy = p.sy + (p.ty - p.sy) * t
    local arcH = -25 * math.sin(t * math.pi)
    cy = cy + arcH

    if p.kind == "arrow" then
        -- 箭矢: 图片渲染 + 拖尾光晕
        local dx = p.tx - p.sx
        local dy = p.ty - p.sy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then dx, dy = dx / len, dy / len end

        local arrowImg = IMG and IMG.tdFxArrow
        if arrowImg and arrowImg > 0 then
            local arrowW, arrowH = 32, 16
            local angle = math.atan(dy, dx)
            local alpha = math.max(0.3, 1 - t * 0.3)
            nvgSave(vg)
            nvgTranslate(vg, cx, cy)
            nvgRotate(vg, angle)
            local pat = nvgImagePattern(vg, -arrowW / 2, -arrowH / 2, arrowW, arrowH, 0, arrowImg, alpha)
            nvgBeginPath(vg)
            nvgRect(vg, -arrowW / 2, -arrowH / 2, arrowW, arrowH)
            nvgFillPaint(vg, pat)
            nvgFill(vg)
            nvgRestore(vg)
        else
            -- fallback: 小三角
            local px, py = -dy, dx
            nvgBeginPath(vg)
            nvgMoveTo(vg, cx + dx * 6, cy + dy * 6)
            nvgLineTo(vg, cx + px * 2, cy + py * 2)
            nvgLineTo(vg, cx - dx * 4, cy - dy * 4)
            nvgLineTo(vg, cx - px * 2, cy - py * 2)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(255, 240, 200, math.floor(230 * (1 - t * 0.3))))
            nvgFill(vg)
        end

        -- 拖尾光晕
        nvgBeginPath(vg)
        nvgCircle(vg, cx - dx * 3, cy - dy * 3, 5)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, math.floor(100 * (1 - t))))
        nvgFill(vg)
    else
        local clr = p.color or { 255, 200, 100 }
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, 3)
        nvgFillColor(vg, nvgRGBA(clr[1], clr[2], clr[3], math.floor(230 * (1 - t * 0.5))))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, 5)
        nvgFillColor(vg, nvgRGBA(clr[1], clr[2], clr[3], math.floor(60 * (1 - t))))
        nvgFill(vg)
    end
end

-- ============================================================================
-- 技能特效 (含 melee 扇形斩击)
-- ============================================================================

local function DrawTDSkillFrame(cx, cy, renderW, frameIdx, alpha, iconIdx)
    local fxData = iconIdx and SKILL_FX_SHEETS and SKILL_FX_SHEETS[iconIdx]
    if not fxData or not fxData.handle or fxData.handle <= 0 then return false end

    local cols = fxData.cols
    local rows = fxData.rows
    local totalFrames = fxData.frames
    local fi = math.min(frameIdx % totalFrames, totalFrames - 1)
    local fcol = fi % cols
    local frow = math.floor(fi / cols)
    local crop = fxData.crop

    local imgW, imgH = nvgImageSize(vg, fxData.handle)
    if not imgW or imgW <= 0 then return false end
    local cellW = imgW / cols
    local cellH = imgH / rows

    local cropScale = fxData.origW and (imgW / fxData.origW) or 1
    local srcX = fcol * cellW + crop.x * cropScale
    local srcY = frow * cellH + crop.y * cropScale
    local srcW = crop.w * cropScale
    local srcH = crop.h * cropScale

    local contentScale = renderW / srcW
    local scaledW = renderW
    local scaledH = srcH * contentScale
    local centeredX = cx - scaledW / 2
    local centeredY = cy - scaledH / 2

    local offsets = fxData.frameOffsets
    if offsets then
        local fo = offsets[fi + 1]
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
    return true
end

function M.DrawSkillFX()
    local st = tdState
    if not st or not st.skillFXList then return end

    for _, fx in ipairs(st.skillFXList) do
        local t = fx.timer / fx.duration
        local a = math.floor(200 * (1 - t))
        local c = fx.color or {255, 180, 80}

        local alpha = 1.0
        if t < 0.15 then alpha = t / 0.15
        elseif t > 0.75 then alpha = (1.0 - t) / 0.25 end
        alpha = math.max(0, math.min(1, alpha))

        local frameIdx = fx.frameIdx or 0
        local iconIdx = fx.iconIdx
        local renderSize = (fx.radius or 60) * 2 * (0.7 + t * 0.3)
        local spriteDrawn = false

        if iconIdx then
            spriteDrawn = DrawTDSkillFrame(fx.cx, fx.cy, renderSize, frameIdx, alpha, iconIdx)
        end

        -- 底层光晕
        if fx.kind == "aoe" or fx.kind == "targeted" then
            local glowR = (fx.radius or 60) * (0.5 + t * 0.5)
            local glowPulse = 0.4 + 0.3 * math.sin(fx.timer * 4)
            local glow = nvgRadialGradient(vg, fx.cx, fx.cy, glowR * 0.1, glowR,
                nvgRGBA(c[1], c[2], c[3], math.floor(40 * alpha * glowPulse)),
                nvgRGBA(c[1], c[2], c[3], 0))
            nvgBeginPath(vg)
            nvgEllipse(vg, fx.cx, fx.cy, glowR, glowR * 0.55)
            nvgFillPaint(vg, glow)
            nvgFill(vg)
        end

        if spriteDrawn then goto continue end

        if fx.kind == "melee" then
            -- 近战斩击图片特效
            local slashImg = IMG and IMG.tdFxSlash
            if slashImg and slashImg > 0 then
                local slashSize = (fx.radius or 60) * 2 * (0.6 + t * 0.4)
                local slashAlpha = alpha * (1 - t * 0.5)
                local angle = (fx.angle or 0) + t * 1.2  -- 旋转动画
                nvgSave(vg)
                nvgTranslate(vg, fx.cx, fx.cy)
                nvgRotate(vg, angle)
                local pat = nvgImagePattern(vg, -slashSize / 2, -slashSize / 2, slashSize, slashSize, 0, slashImg, slashAlpha)
                nvgBeginPath(vg)
                nvgRect(vg, -slashSize / 2, -slashSize / 2, slashSize, slashSize)
                nvgFillPaint(vg, pat)
                nvgFill(vg)
                nvgRestore(vg)
            else
                -- fallback: 扇形白光
                local flashAlpha = math.floor(200 * alpha * (1 - t))
                local r = fx.radius or 60
                nvgBeginPath(vg)
                nvgArc(vg, fx.cx, fx.cy, r * (0.3 + t * 0.7), -math.pi * 0.6, math.pi * 0.6, 2)
                nvgLineTo(vg, fx.cx, fx.cy)
                nvgClosePath(vg)
                nvgFillColor(vg, nvgRGBA(255, 255, 240, flashAlpha))
                nvgFill(vg)
            end
        elseif fx.kind == "aoe" then
            local r = fx.radius * (0.3 + t * 0.7)
            nvgBeginPath(vg)
            nvgEllipse(vg, fx.cx, fx.cy, r, r * 0.55)
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(a * 0.3)))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgEllipse(vg, fx.cx, fx.cy, r, r * 0.55)
            nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], a))
            nvgStrokeWidth(vg, 3 * (1 - t))
            nvgStroke(vg)
        elseif fx.kind == "line" then
            local lineLen = fx.radius or 200
            local lineW = 8 * (1 - t)
            nvgBeginPath(vg)
            nvgRect(vg, fx.cx, fx.cy - lineW / 2, lineLen * (0.3 + t * 0.7), lineW)
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], a))
            nvgFill(vg)
        elseif fx.kind == "heal" then
            local colH = 40 * (1 - t * 0.5)
            nvgBeginPath(vg)
            nvgRect(vg, fx.cx - 6, fx.cy - colH - 20 * t, 12, colH)
            nvgFillColor(vg, nvgRGBA(80, 255, 120, a))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRect(vg, fx.cx - 12, fx.cy - 3, 24, 6)
            nvgFillColor(vg, nvgRGBA(80, 255, 120, math.floor(a * 0.7)))
            nvgFill(vg)
        elseif fx.kind == "buff" then
            for ring = 1, 3 do
                local rOff = ring * 0.15
                local r2 = fx.radius * (0.2 + (t + rOff) * 0.6)
                local a2 = math.floor(a * (1 - ring * 0.25))
                if a2 > 0 then
                    nvgBeginPath(vg)
                    nvgEllipse(vg, fx.cx, fx.cy, r2, r2 * 0.55)
                    nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], a2))
                    nvgStrokeWidth(vg, 2)
                    nvgStroke(vg)
                end
            end
        else
            local r3 = 18 + 22 * t
            nvgBeginPath(vg)
            nvgEllipse(vg, fx.cx, fx.cy, r3, r3 * 0.55)
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(a * 0.5)))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgEllipse(vg, fx.cx, fx.cy, r3, r3 * 0.55)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, a))
            nvgStrokeWidth(vg, 2.5 * (1 - t))
            nvgStroke(vg)
        end

        ::continue::
    end
end

-- ============================================================================
-- 飞行剑渲染
-- ============================================================================

function M.DrawFlyingSwords()
    local st = tdState
    if not st or not st.flyingSwords then return end
    if not st.smoothPath or #st.smoothPath < 2 then return end

    for _, sword in ipairs(st.flyingSwords) do
        if not sword.active then goto nextSword end

        local sx, sy
        if sword.travelDist <= 0 then
            sx, sy = st.smoothPath[1].x, st.smoothPath[1].y
        else
            sx, sy = TDData.GetPositionOnPath(st.smoothPath, sword.travelDist)
        end
        local c = sword.color or {200, 220, 255}

        -- 拖尾
        if #sword.trail >= 2 then
            for ti = 2, #sword.trail do
                local p1 = sword.trail[ti - 1]
                local p2 = sword.trail[ti]
                local trailAlpha = math.floor(180 * (ti / #sword.trail))
                local trailW = 1.0 + 2.5 * (ti / #sword.trail)
                nvgBeginPath(vg)
                nvgMoveTo(vg, p1.x, p1.y)
                nvgLineTo(vg, p2.x, p2.y)
                nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], trailAlpha))
                nvgStrokeWidth(vg, trailW)
                nvgStroke(vg)
            end
        end

        -- 光晕
        local gt = st.gameTime or 0
        local glowPulse = 0.6 + 0.4 * math.sin(gt * 8)
        local glowR = 18 * glowPulse
        local glow = nvgRadialGradient(vg, sx, sy, 2, glowR,
            nvgRGBA(c[1], c[2], c[3], math.floor(120 * glowPulse)),
            nvgRGBA(c[1], c[2], c[3], 0))
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, glowR)
        nvgFillPaint(vg, glow)
        nvgFill(vg)

        -- 剑体菱形
        local dirX, dirY = -1, 0  -- 默认朝入口方向
        if #sword.trail >= 2 then
            local last = sword.trail[#sword.trail]
            local prev = sword.trail[#sword.trail - 1]
            dirX = last.x - prev.x
            dirY = last.y - prev.y
            local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
            if dirLen > 0.1 then
                dirX = dirX / dirLen
                dirY = dirY / dirLen
            end
        end
        local perpX, perpY = -dirY, dirX
        local swordLen = 12
        local swordW = 4

        nvgBeginPath(vg)
        nvgMoveTo(vg, sx + dirX * swordLen, sy + dirY * swordLen)
        nvgLineTo(vg, sx + perpX * swordW, sy + perpY * swordW)
        nvgLineTo(vg, sx - dirX * swordLen * 0.4, sy - dirY * swordLen * 0.4)
        nvgLineTo(vg, sx - perpX * swordW, sy - perpY * swordW)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], 255))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        ::nextSword::
    end
end

-- ============================================================================
-- 飞行剑全局CD指示器 (HUD右上区域)
-- ============================================================================

function M.DrawSwordCD()
    local st = tdState
    if not st then return end
    if st.phase ~= "PLAYING" and st.phase ~= "PREPARE" then return end

    local DW = TDData.DESIGN_W
    local cdX = DW - 70
    local cdY = 42
    local cdR = 16

    local effectiveCd = st.swordEffectiveCd or st.swordCdBase
    local cdPct = math.min(1, (st.swordCdTimer or 0) / effectiveCd)

    -- 背景圆
    nvgBeginPath(vg)
    nvgCircle(vg, cdX, cdY, cdR + 2)
    nvgFillColor(vg, nvgRGBA(10, 8, 5, 180))
    nvgFill(vg)

    -- CD弧
    local startAngle = -math.pi / 2
    local endAngle = startAngle + math.pi * 2 * cdPct
    if cdPct < 1 then
        nvgBeginPath(vg)
        nvgArc(vg, cdX, cdY, cdR, startAngle, endAngle, 2)
        nvgStrokeColor(vg, nvgRGBA(80, 180, 255, 200))
        nvgStrokeWidth(vg, 3)
        nvgStroke(vg)
    else
        local gt = st.gameTime or 0
        local pulse = 0.5 + 0.5 * math.sin(gt * 6)
        nvgBeginPath(vg)
        nvgCircle(vg, cdX, cdY, cdR)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(120 + 135 * pulse)))
        nvgStrokeWidth(vg, 2.5)
        nvgStroke(vg)
    end

    -- 剑图标
    nvgBeginPath(vg)
    nvgMoveTo(vg, cdX, cdY - 8)
    nvgLineTo(vg, cdX + 4, cdY)
    nvgLineTo(vg, cdX, cdY + 8)
    nvgLineTo(vg, cdX - 4, cdY)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, cdPct >= 1 and 255 or 120))
    nvgFill(vg)
end

-- ============================================================================
-- 飘字
-- ============================================================================

function M.DrawFloatTexts()
    local st = tdState
    if not st then return end
    if fontId < 0 then return end

    nvgFontFaceId(vg, GetMainFont())
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for _, ft in ipairs(st.floatTexts) do
        local a = 1 - (ft.timer / ft.duration)
        a = math.max(0, math.min(1, a))
        local c = ft.color or { 255, 255, 255 }
        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(255 * a)))
        nvgText(vg, ft.x, ft.y, ft.text, nil)
    end
end

-- ============================================================================
-- HUD (顶栏)
-- ============================================================================

function M.DrawHUD()
    local st = tdState
    if not st then return end

    local DW = TDData.DESIGN_W
    local hudY = 0
    local hudH = 36

    local bgPaint = nvgLinearGradient(vg, 0, hudY, 0, hudY + hudH,
        nvgRGBA(10, 8, 5, 210), nvgRGBA(20, 16, 10, 200))
    nvgBeginPath(vg)
    nvgRect(vg, 0, hudY, DW, hudH)
    nvgFillPaint(vg, bgPaint)
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, hudY + hudH)
    nvgLineTo(vg, DW, hudY + hudH)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 80))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    if fontId < 0 then return end
    nvgFontFaceId(vg, GetMainFont())
    local cy = hudY + hudH / 2

    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 230, 160, 255))
    nvgText(vg, 12, cy, "第" .. st.level .. "关", nil)

    nvgBeginPath(vg)
    nvgMoveTo(vg, 72, hudY + 6)
    nvgLineTo(vg, 72, hudY + hudH - 6)
    nvgStrokeColor(vg, nvgRGBA(120, 100, 60, 80))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(200, 190, 160, 220))
    nvgText(vg, 84, cy, "波次 " .. st.currentWave .. "/" .. #st.waves, nil)

    local goldIcon = IMG and IMG.tdGoldIcon
    if goldIcon and goldIcon > 0 then
        DrawImageCover(goldIcon, 206, cy - 9, 18, 18, 1.0, 2)
    end
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 250))
    nvgText(vg, 228, cy, st.gold .. "", nil)

    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(220, 180, 140, 200))
    nvgText(vg, 330, cy, "击杀 " .. st.totalKills, nil)

    nvgFontSize(vg, 14)
    local hpClr = (st.baseHP / st.baseMaxHP > 0.5) and {80, 220, 120} or {255, 80, 80}
    nvgFillColor(vg, nvgRGBA(hpClr[1], hpClr[2], hpClr[3], 220))
    nvgText(vg, 440, cy, "城池 " .. st.baseHP .. "/" .. st.baseMaxHP, nil)

    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local btnW, btnH = 54, 26
    local btnY = hudY + (hudH - btnH) / 2

    local function DrawHudBtn(bx, text, active, activeClr, normalClr)
        activeClr = activeClr or {160, 120, 40}
        normalClr = normalClr or {50, 45, 38}
        local clr = active and activeClr or normalClr
        local glow = nvgLinearGradient(vg, bx, btnY, bx, btnY + btnH,
            nvgRGBA(clr[1]+30, clr[2]+20, clr[3]+10, 220),
            nvgRGBA(clr[1], clr[2], clr[3], 240))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, btnY, btnW, btnH, 4)
        nvgFillPaint(vg, glow)
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, btnY, btnW, btnH, 4)
        nvgStrokeColor(vg, nvgRGBA(200, 180, 120, active and 120 or 40))
        nvgStrokeWidth(vg, 0.8)
        nvgStroke(vg)
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(255, 250, 230, active and 255 or 180))
        nvgText(vg, bx + btnW / 2, btnY + btnH / 2, text, nil)
        return { x = bx, y = btnY, w = btnW, h = btnH }
    end

    st.btnRects.pause = DrawHudBtn(DW - 180, st.paused and "继续" or "暂停", st.paused, {180, 80, 40})
    local speedText = st.speed == 1 and "x1" or (st.speed == 2 and "x2" or "x3")
    st.btnRects.speed = DrawHudBtn(DW - 122, speedText, st.speed > 1, {60, 80, 160})
    st.btnRects.autoBattle = DrawHudBtn(DW - 64, st.autoBattle and "自动中" or "自动", st.autoBattle, {60, 140, 70})
end

-- ============================================================================
-- 技能栏 + 能量条 (底部栏上层, y约493)
-- ============================================================================

function M.DrawSkillBar()
    local st = tdState
    if not st then return end

    local DW = TDData.DESIGN_W
    local DH = TDData.DESIGN_H
    local barH = 78
    local barY = DH - barH
    local skillRowY = barY + 2    -- 技能行顶部
    local skillRowH = 32          -- 技能栏高度

    -- 技能栏背景条 (半透明深色，略带金边)
    local skillBg = nvgLinearGradient(vg, 0, skillRowY, 0, skillRowY + skillRowH,
        nvgRGBA(25, 20, 15, 230), nvgRGBA(15, 12, 8, 240))
    nvgBeginPath(vg)
    nvgRect(vg, 0, skillRowY, DW, skillRowH)
    nvgFillPaint(vg, skillBg)
    nvgFill(vg)
    -- 上边金色分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, skillRowY)
    nvgLineTo(vg, DW, skillRowY)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 80, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    -- 下边分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, skillRowY + skillRowH)
    nvgLineTo(vg, DW, skillRowY + skillRowH)
    nvgStrokeColor(vg, nvgRGBA(120, 100, 50, 60))
    nvgStrokeWidth(vg, 0.5)
    nvgStroke(vg)

    -- 能量条 (左侧)
    local energyBarW = 140
    local energyBarH = 6
    local energyBarX = 52
    local energyBarY = skillRowY + (skillRowH - energyBarH) / 2
    local energyPct = (st.totalEnergy or 0) / TDData.ENERGY_MAX

    nvgBeginPath(vg)
    nvgRoundedRect(vg, energyBarX, energyBarY, energyBarW, energyBarH, 3)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgFill(vg)

    if energyPct > 0 then
        local eClrR = energyPct > 0.8 and 255 or 80
        local eClrG = energyPct > 0.8 and 220 or 180
        local eClrB = energyPct > 0.8 and 80 or 255
        nvgBeginPath(vg)
        nvgRoundedRect(vg, energyBarX, energyBarY, energyBarW * energyPct, energyBarH, 3)
        nvgFillColor(vg, nvgRGBA(eClrR, eClrG, eClrB, 220))
        nvgFill(vg)
    end

    -- "能量"标签
    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 100, 180))
        nvgText(vg, energyBarX - 3, energyBarY + energyBarH / 2, "能量", nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 180))
        nvgText(vg, energyBarX + energyBarW + 4, energyBarY + energyBarH / 2,
            math.floor(st.totalEnergy) .. "/" .. TDData.ENERGY_MAX, nil)
    end

    -- 5个技能圆钮 (增大尺寸)
    local skillR = 13
    local skillGap = 8
    local totalSkillW = 5 * (skillR * 2) + 4 * skillGap
    local skillStartX = DW / 2 - totalSkillW / 2 + skillR
    local skillCY = skillRowY + skillRowH / 2

    st.btnRects.skillBtns = st.btnRects.skillBtns or {}

    local SKILL_COLORS = {
        {200, 220, 255},  -- 飞剑 白蓝
        {255, 120, 40},   -- 天火 橙红
        {80, 180, 255},   -- 冰霜 蓝
        {80, 255, 120},   -- 春风 绿
        {180, 120, 255},  -- 雷霆 紫
    }

    for i = 1, 5 do
        local def = TDData.SKILL_DEFS[i]
        if not def then goto nextSkill end

        local scx = skillStartX + (i - 1) * (skillR * 2 + skillGap)
        local scy = skillCY

        local canUse = (st.totalEnergy >= def.energyCost) and (st.skills[i].cdTimer <= 0)
        local isTargeting = (st.targetingSkill == i)
        local clr = SKILL_COLORS[i] or {200, 200, 200}

        -- 按钮背景圆
        nvgBeginPath(vg)
        nvgCircle(vg, scx, scy, skillR)
        if canUse then
            nvgFillColor(vg, nvgRGBA(clr[1], clr[2], clr[3], isTargeting and 200 or 100))
        else
            nvgFillColor(vg, nvgRGBA(40, 40, 40, 180))
        end
        nvgFill(vg)

        -- 技能图标 (优先使用图片)
        local skillIcon = IMG and IMG.tdSkillIcons and IMG.tdSkillIcons[i]
        if skillIcon and skillIcon > 0 then
            local iconSize = skillR * 1.8
            local iconAlpha = canUse and 1.0 or 0.4
            local pat = nvgImagePattern(vg, scx - iconSize / 2, scy - iconSize / 2, iconSize, iconSize, 0, skillIcon, iconAlpha)
            nvgBeginPath(vg)
            nvgCircle(vg, scx, scy, skillR - 1)
            nvgFillPaint(vg, pat)
            nvgFill(vg)
        else
            -- fallback: 文字
            if fontId >= 0 then
                nvgFontFaceId(vg, GetMainFont())
                nvgFontSize(vg, 9)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, canUse and 230 or 100))
                nvgText(vg, scx, scy, string.sub(def.name, 1, 2), nil)
            end
        end

        -- 边框
        nvgBeginPath(vg)
        nvgCircle(vg, scx, scy, skillR)
        if isTargeting then
            nvgStrokeColor(vg, nvgRGBA(255, 255, 100, 255))
            nvgStrokeWidth(vg, 2.5)
        else
            nvgStrokeColor(vg, nvgRGBA(clr[1], clr[2], clr[3], canUse and 220 or 60))
            nvgStrokeWidth(vg, 1.2)
        end
        nvgStroke(vg)

        -- CD覆盖层 (扇形遮罩)
        if st.skills[i].cdTimer > 0 then
            local cdPct = st.skills[i].cdTimer / def.cd
            local startA = -math.pi / 2
            local endA = startA + math.pi * 2 * cdPct
            nvgBeginPath(vg)
            nvgMoveTo(vg, scx, scy)
            nvgArc(vg, scx, scy, skillR, startA, endA, 2)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 140))
            nvgFill(vg)
        end

        -- 能量消耗标签 (图标下方)
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 140))
            nvgText(vg, scx, scy + skillR + 1, def.energyCost .. "", nil)
        end

        st.btnRects.skillBtns[i] = { x = scx - skillR, y = scy - skillR, w = skillR * 2, h = skillR * 2 }

        ::nextSkill::
    end

    -- 聚焦武将升级按钮
    if st.focusedHeroIdx > 0 then
        local hero = st.heroes[st.focusedHeroIdx]
        if hero and not hero.dead and hero.level < 5 then
            local upgCost = TDData.UPGRADE_COST[hero.level]
            if upgCost then
                local ubW, ubH = 48, 18
                local ubX = DW - 56
                local ubY = skillRowY + 8
                local canAfford = st.gold >= upgCost

                nvgBeginPath(vg)
                nvgRoundedRect(vg, ubX, ubY, ubW, ubH, 3)
                nvgFillColor(vg, canAfford and nvgRGBA(80, 160, 60, 220) or nvgRGBA(60, 60, 60, 180))
                nvgFill(vg)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, ubX, ubY, ubW, ubH, 3)
                nvgStrokeColor(vg, nvgRGBA(180, 255, 120, canAfford and 150 or 40))
                nvgStrokeWidth(vg, 0.8)
                nvgStroke(vg)

                if fontId >= 0 then
                    nvgFontFaceId(vg, GetMainFont())
                    nvgFontSize(vg, 10)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, canAfford and 240 or 120))
                    nvgText(vg, ubX + ubW / 2, ubY + ubH / 2, "升级 " .. upgCost, nil)
                end

                st.btnRects.upgradeBtn = { x = ubX, y = ubY, w = ubW, h = ubH }
            end
        else
            st.btnRects.upgradeBtn = nil
        end
    else
        st.btnRects.upgradeBtn = nil
    end
end

-- ============================================================================
-- 底部武将选择栏 (下层)
-- ============================================================================

function M.DrawHeroBar()
    local st = tdState
    if not st then return end

    local DW = TDData.DESIGN_W
    local DH = TDData.DESIGN_H
    local barH = 78
    local barY = DH - barH
    local heroRowY = barY + 34   -- 武将行偏移(技能栏占上部)
    local heroRowH = barH - 34

    -- 背景 (整个底部栏)
    local barBg = nvgLinearGradient(vg, 0, barY, 0, barY + barH,
        nvgRGBA(15, 12, 8, 240), nvgRGBA(8, 6, 4, 250))
    nvgBeginPath(vg)
    nvgRect(vg, 0, barY, DW, barH)
    nvgFillPaint(vg, barBg)
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, barY)
    nvgLineTo(vg, DW, barY)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 80))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 返回按钮
    local backW, backH = 36, heroRowH - 4
    local backX, backY2 = 4, heroRowY + 2
    local backBg = nvgLinearGradient(vg, backX, backY2, backX, backY2 + backH,
        nvgRGBA(140, 65, 50, 210), nvgRGBA(90, 40, 30, 230))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, backX, backY2, backW, backH, 4)
    nvgFillPaint(vg, backBg)
    nvgFill(vg)
    st.btnRects.back = { x = backX, y = backY2, w = backW, h = backH }
    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 180, 230))
        nvgText(vg, backX + backW / 2, backY2 + backH / 2, "返回", nil)
    end

    -- 开战按钮
    if st.phase == "PREPARE" or st.phase == "WAVE_CLEAR" then
        local startW, startH = 50, heroRowH - 4
        local startX = DW - startW - 4
        local startY = heroRowY + 2
        local t3 = st.gameTime or 0
        local startPulse = 0.85 + 0.15 * math.sin(t3 * 3)
        local startBg = nvgLinearGradient(vg, startX, startY, startX, startY + startH,
            nvgRGBA(math.floor(100 * startPulse), math.floor(200 * startPulse), math.floor(100 * startPulse), 230),
            nvgRGBA(60, 140, 60, 240))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, startX, startY, startW, startH, 4)
        nvgFillPaint(vg, startBg)
        nvgFill(vg)
        st.btnRects.startWave = { x = startX, y = startY, w = startW, h = startH }
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
            local txt = st.phase == "PREPARE" and "开战" or "下一波"
            nvgText(vg, startX + startW / 2, startY + startH / 2, txt, nil)
        end
    else
        st.btnRects.startWave = nil
    end

    -- 武将卡牌槽 (紧凑版)
    local slotW = 36
    local slotH = heroRowH - 4
    local slotGap = 5
    local totalSlotsW = 8 * slotW + 7 * slotGap
    local slotsStartX = 44 + (DW - 44 - 58 - totalSlotsW) / 2

    st.btnRects.heroSlots = {}

    for i = 1, 8 do
        local sx2 = slotsStartX + (i - 1) * (slotW + slotGap)
        local sy2 = heroRowY + 2

        local cardIdx = st.roster[i]
        local card = cardIdx and HERO_CARDS[cardIdx]

        local alreadyPlaced = false
        for _, hero in ipairs(st.heroes) do
            if hero.rosterIdx == i then
                alreadyPlaced = true
                break
            end
        end

        nvgBeginPath(vg)
        nvgRoundedRect(vg, sx2, sy2, slotW, slotH, 3)
        if st.selectedHeroIdx == i then
            nvgFillColor(vg, nvgRGBA(60, 100, 60, 220))
        elseif alreadyPlaced then
            nvgFillColor(vg, nvgRGBA(30, 28, 24, 150))
        else
            nvgFillColor(vg, nvgRGBA(25, 22, 18, 200))
        end
        nvgFill(vg)

        st.btnRects.heroSlots[i] = { x = sx2, y = sy2, w = slotW, h = slotH }

        if card then
            local qc = QUALITY_COLORS and QUALITY_COLORS[card.quality] or { 180, 170, 155 }

            nvgBeginPath(vg)
            nvgRoundedRect(vg, sx2, sy2, slotW, slotH, 3)
            nvgStrokeColor(vg, nvgRGBA(qc[1], qc[2], qc[3], alreadyPlaced and 50 or 200))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            local imgH2 = GetHeroSheet and GetHeroSheet(card) or -1
            if imgH2 and imgH2 > 0 then
                local _sh, _sc, _sr = GetHeroSheetInfo(card)
                local cardAlpha = alreadyPlaced and 0.3 or 0.95
                nvgSave(vg)
                nvgGlobalAlpha(vg, cardAlpha)
                DrawCardImage(sx2 + 2, sy2 + 2, slotW - 4, slotH - 12, _sh, card.row, card.col, _sc, _sr, true)
                nvgRestore(vg)
            end

            if fontId >= 0 then
                nvgFontFaceId(vg, GetMainFont())
                nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                local a3 = alreadyPlaced and 100 or 230
                nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], a3))
                nvgText(vg, sx2 + slotW / 2, sy2 + slotH - 1, string.sub(card.name, 1, 2), nil)

                local cost = TDData.HERO_COST[card.quality] or 200
                nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                local canAfford = st.gold >= cost and not alreadyPlaced
                nvgFillColor(vg, nvgRGBA(canAfford and 255 or 150, canAfford and 220 or 100, 80, canAfford and 230 or 120))
                nvgText(vg, sx2 + 2, sy2 + 1, cost .. "", nil)
            end
        end
    end
end

-- ============================================================================
-- 阶段覆盖层
-- ============================================================================

function M.DrawPhaseOverlay()
    local st = tdState
    if not st then return end

    local DW = TDData.DESIGN_W
    local DH = TDData.DESIGN_H

    if st.phase == "LEVEL_CLEAR" then
        local clearBg = nvgLinearGradient(vg, 0, DH * 0.3, 0, DH * 0.7,
            nvgRGBA(20, 18, 8, 160), nvgRGBA(0, 0, 0, 120))
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, DW, DH)
        nvgFillPaint(vg, clearBg)
        nvgFill(vg)
        if fontId >= 0 then
            local cx = DW / 2
            local cy2 = DH / 2
            nvgFontFaceId(vg, GetMainFont())
            nvgBeginPath(vg)
            nvgMoveTo(vg, cx - 140, cy2 - 40)
            nvgLineTo(vg, cx + 140, cy2 - 40)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 100, 120))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)
            nvgFontSize(vg, 34)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, cy2 - 18, "第" .. st.level .. "关 通过!")
            nvgBeginPath(vg)
            nvgMoveTo(vg, cx - 140, cy2 + 5)
            nvgLineTo(vg, cx + 140, cy2 + 5)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 100, 120))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)
            nvgFontSize(vg, 16)
            nvgFillColor(vg, nvgRGBA(200, 190, 160, 200))
            nvgText(vg, cx, cy2 + 24, "击杀 " .. st.totalKills, nil)
            local jadeReward = 50 + st.level * 20
            nvgFillColor(vg, nvgRGBA(120, 220, 255, 230))
            nvgText(vg, cx, cy2 + 46, "获得 " .. jadeReward .. " 玉璧", nil)
        end
    elseif st.phase == "GAME_OVER" then
        local failBg = nvgLinearGradient(vg, 0, DH * 0.3, 0, DH * 0.7,
            nvgRGBA(30, 5, 5, 180), nvgRGBA(0, 0, 0, 160))
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, DW, DH)
        nvgFillPaint(vg, failBg)
        nvgFill(vg)
        if fontId >= 0 then
            local cx = DW / 2
            local cy2 = DH / 2
            nvgFontFaceId(vg, GetMainFont())
            local panW, panH = 280, 150
            local panX, panY = cx - panW / 2, cy2 - panH / 2 - 10
            local panBg = nvgLinearGradient(vg, panX, panY, panX, panY + panH,
                nvgRGBA(50, 15, 10, 230), nvgRGBA(25, 8, 5, 240))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, panX, panY, panW, panH, 8)
            nvgFillPaint(vg, panBg)
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, panX, panY, panW, panH, 8)
            nvgStrokeColor(vg, nvgRGBA(200, 60, 40, 100))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            nvgFontSize(vg, 28)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 80, 80, 250))
            nvgText(vg, cx, panY + 38, "基地陷落!", nil)

            nvgFontSize(vg, 16)
            nvgFillColor(vg, nvgRGBA(200, 190, 160, 200))
            nvgText(vg, cx, panY + 68, "坚守了 " .. st.level .. " 关", nil)
            nvgText(vg, cx, panY + 92, "击杀: " .. st.totalKills, nil)

            local retW, retH = 120, 36
            local retX = cx - retW / 2
            local retY2 = panY + panH - retH - 10
            local retBg = nvgLinearGradient(vg, retX, retY2, retX, retY2 + retH,
                nvgRGBA(180, 80, 55, 230), nvgRGBA(120, 50, 35, 240))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, retX, retY2, retW, retH, 6)
            nvgFillPaint(vg, retBg)
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, retX, retY2, retW, retH, 6)
            nvgStrokeColor(vg, nvgRGBA(255, 140, 120, 80))
            nvgStrokeWidth(vg, 0.8)
            nvgStroke(vg)
            st.btnRects.gameOverBack = { x = retX, y = retY2, w = retW, h = retH }
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 240, 220, 240))
            nvgText(vg, cx, retY2 + retH / 2, "返回主菜单", nil)
        end
    elseif st.phase == "PREPARE" then
        if fontId >= 0 and st.currentWave == 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local t2 = st.gameTime or 0
            local a2 = math.floor(160 + 60 * math.sin(t2 * 2))
            nvgFillColor(vg, nvgRGBA(255, 220, 140, a2))
            nvgText(vg, DW / 2, TDData.MAP_AREA_TOP + 20, "选择武将 → 点击格子放置 → 开战!", nil)
        end
    end

    -- 技能目标选择模式提示
    if st.targetingSkill and st.targetingSkill > 0 then
        local def = TDData.SKILL_DEFS[st.targetingSkill]
        if def and fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 16)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local gt = st.gameTime or 0
            local a = math.floor(180 + 60 * math.sin(gt * 3))
            nvgFillColor(vg, nvgRGBA(255, 220, 80, a))
            nvgText(vg, DW / 2, TDData.MAP_AREA_TOP + 20, "点击地图释放 " .. def.name, nil)
        end
    end
end

return M
