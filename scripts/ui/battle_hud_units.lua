-- ui/battle_hud_units.lua - 三国武灵录 (从 battle_hud.lua 拆分, dummy cleanup done)
-- ============================================================================
-- 战斗单位渲染
-- ============================================================================

-- LOD 逻辑已移除: 所有单位统一完整渲染
local _leftFacingSprites = { cavalry = true, lancer = true, demon_warrior = true, demon_archer = true, demon_tank = true }

function DrawBattleUnits()
    -- ★ 战旗模式分支
    if gameState.battlePhase == "TACTICS" and tacticState then
        DrawTacticGrid()
        return
    end

    -- ★ 回合制模式分支
    if gameState.battlePhase == "FIGHT" and rawget(_G, "tbState") then
        DrawTBGrid()
        return
    end

    -- 战区分割线 (淡墨, 横屏: 垂直中线)
    nvgBeginPath(vg)
    local lineGrad = nvgLinearGradient(vg, BATTLE_ZONE.centerX, BATTLE_ZONE.top + 30,
        BATTLE_ZONE.centerX, BATTLE_ZONE.bottom - 30,
        nvgRGBA(200, 160, 80, 0), nvgRGBA(200, 160, 80, 30))
    nvgMoveTo(vg, BATTLE_ZONE.centerX, BATTLE_ZONE.top + 30)
    nvgLineTo(vg, BATTLE_ZONE.centerX, BATTLE_ZONE.bottom - 30)
    nvgStrokePaint(vg, lineGrad)
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- ★ 云层渲染已移除 (战旗模式不需要)
    -- 精灵 (所有LOD都绘制，但内部根据LOD简化)
    for _, u in ipairs(playerUnits) do if u.alive then DrawUnitSprite(u) end end
    for _, u in ipairs(enemyUnits) do if u.alive then DrawUnitSprite(u) end end

    -- ★ 兵种选中高亮已移除 (视觉效果不佳)

    -- ★ 集结点标记渲染 (战场上的移动/进攻指令位置)
    DrawRallyMarkers()
end

-- ============================================================================
-- 回合制网格 + 军团渲染 (5×9, 列5=中间分隔)
-- 不绘制棋盘色块, 直接使用战斗背景图, 仅画半透明网格线分隔
-- ============================================================================
function DrawTBGrid()
    local ts = tbState
    if not ts then return end
    local t = gameState.gameTime or 0
    local TBModule = require("systems.battle.turnbased")

    -- 1) 半透明网格线 (不画色块, 让背景图透出)
    nvgStrokeWidth(vg, 1)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 35))
    for r = 1, TB_ROWS do
        for c = 1, TB_COLS do
            local cx, cy = TBModule.GridToScreen(r, c)
            local hw = TB_CELL_W / 2
            local hh = TB_CELL_H / 2
            nvgBeginPath(vg)
            nvgRect(vg, cx - hw, cy - hh, TB_CELL_W, TB_CELL_H)
            nvgStroke(vg)
        end
    end

    -- 2) 移动范围高亮 (蓝色半透明)
    local pulse = 0.5 + 0.3 * math.sin(t * 4)
    for _, mt in ipairs(ts.moveTargets) do
        local cx, cy = TBModule.GridToScreen(mt.row, mt.col)
        local hw, hh = TB_CELL_W / 2, TB_CELL_H / 2
        nvgBeginPath(vg); nvgRect(vg, cx - hw, cy - hh, TB_CELL_W, TB_CELL_H)
        nvgFillColor(vg, nvgRGBA(60, 140, 255, math.floor(70 * pulse))); nvgFill(vg)
    end

    -- 3) 攻击范围高亮 (红色半透明)
    local atkPulse = 0.5 + 0.3 * math.sin(t * 5)
    for _, at in ipairs(ts.attackTargets) do
        local cx, cy = TBModule.GridToScreen(at.row, at.col)
        local hw, hh = TB_CELL_W / 2, TB_CELL_H / 2
        nvgBeginPath(vg); nvgRect(vg, cx - hw, cy - hh, TB_CELL_W, TB_CELL_H)
        nvgFillColor(vg, nvgRGBA(255, 80, 60, math.floor(70 * atkPulse))); nvgFill(vg)
    end

    -- 4) 选中军团高亮 (黄色边框)
    if ts.selectedIdx then
        local g = ts.playerRegiments[ts.selectedIdx]
        if g and g.alive then
            local cx, cy = TBModule.GridToScreen(g.row, g.col)
            local hw, hh = TB_CELL_W / 2, TB_CELL_H / 2
            local selPulse = 0.5 + 0.4 * math.sin(t * 6)
            nvgBeginPath(vg); nvgRect(vg, cx - hw, cy - hh, TB_CELL_W, TB_CELL_H)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(220 * selPulse)))
            nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
        end
    end

    -- 5) 绘制军团 (先敌后我)
    nvgFontFaceId(vg, GetMainFont())
    for _, g in ipairs(ts.enemyRegiments) do
        if g.alive then DrawTBRegiment(g, t) end
    end
    for _, g in ipairs(ts.playerRegiments) do
        if g.alive then DrawTBRegiment(g, t) end
    end

    -- 6) 回合横幅
    if ts.bannerTimer and ts.bannerTimer > 0 and ts.bannerText then
        DrawTacticBanner(ts.bannerText, ts.isPlayerTurn)
    end

    -- 7) 回合/行动点信息 (网格上方, 紧贴顶部HUD下)
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(220, 210, 180, 220))
    nvgText(vg, TB_GRID_LEFT, TB_GRID_TOP - 4,
        string.format("回合 %d | %s | AP: %d/%d",
            ts.turnNumber,
            ts.isPlayerTurn and "我方行动" or "敌方行动",
            ts.ap, TB_MAX_AP))

    -- 8) 战场播报面板 (右上角)
    DrawBattleLog(ts)
end

--- 绘制单个回合制军团 (武将半身像 + 小兵精灵 + 人数)
function DrawTBRegiment(g, t)
    local px, py = g.screenX, g.screenY

    -- 受击闪烁
    local flashAlpha = 0
    if g.flashTimer and g.flashTimer > 0 then
        flashAlpha = math.floor(180 * (g.flashTimer / 0.5))
    end

    -- 军团区域
    local boxW = TB_CELL_W - 6
    local boxH = TB_CELL_H - 14
    local boxX = px - boxW / 2
    local boxY = py - boxH / 2 + 1
    local c = g.troopColor
    local globalAlpha = g.acted and 0.5 or 1.0

    -- 浅底色
    nvgBeginPath(vg)
    nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 3)
    nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], g.acted and 25 or 45))
    nvgFill(vg)

    -- 阵营边框 (蓝=我方, 红=敌方)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 3)
    if g.isPlayer then
        nvgStrokeColor(vg, nvgRGBA(80, 150, 255, g.acted and 60 or 180))
    else
        nvgStrokeColor(vg, nvgRGBA(255, 80, 60, g.acted and 60 or 180))
    end
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- === 布局: 左50%=武将缩小立绘, 右50%=兵种立绘 ===
    local halfW = math.floor(boxW / 2)
    local leftX = boxX + 1
    local rightX = boxX + halfW
    local areaH = boxH - 2

    -- === 左半: 武将缩小立绘 ===
    local heroImgKey = g.card and g.card.singleImg
    local heroImg = heroImgKey and IMG and IMG[heroImgKey]
    if heroImg and heroImg > 0 then
        nvgSave(vg)
        nvgGlobalAlpha(vg, globalAlpha)
        local hAreaW = halfW - 2
        nvgIntersectScissor(vg, leftX, boxY + 1, hAreaW, areaH)
        -- 立绘比例约2:3, 宽度适配左半区
        local imgW = hAreaW
        local imgH = imgW * 1.5
        -- 如果图片高度不够填满, 按高度适配
        if imgH < areaH then
            imgH = areaH
            imgW = imgH / 1.5
        end
        local imgX = leftX + (hAreaW - imgW) / 2
        local imgY = boxY + 1   -- 顶部对齐, 显示头部
        local imgPat = nvgImagePattern(vg, imgX, imgY, imgW, imgH, 0, heroImg, 1.0)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, leftX, boxY + 1, hAreaW, areaH, 2)
        nvgFillPaint(vg, imgPat)
        nvgFill(vg)
        nvgRestore(vg)
    else
        -- 无武将图时用武将名 fallback
        nvgSave(vg)
        nvgGlobalAlpha(vg, globalAlpha)
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
        nvgText(vg, leftX + halfW / 2 - 1, boxY + boxH / 2, string.sub(g.heroName or "?", 1, 2))
        nvgRestore(vg)
    end

    -- === 右半: 兵种立绘 ===
    local spName = g.spriteName or "sword"
    local sprImg = IMG.unitSprites[spName]
    local nDir = _leftFacingSprites[spName] and -1 or 1
    local wDir = g.isPlayer and 1 or -1
    local flipX = nDir * wDir

    if sprImg and sprImg > 0 then
        local rAreaW = boxW - halfW - 2
        local sprSz = math.min(rAreaW, areaH) * 0.9
        local sprCX = rightX + rAreaW / 2
        local sprCY = boxY + 1 + areaH / 2
        local half = sprSz / 2
        nvgSave(vg)
        nvgGlobalAlpha(vg, globalAlpha)
        nvgTranslate(vg, sprCX, sprCY)
        if flipX < 0 then nvgScale(vg, -1, 1) end
        local imgPat = nvgImagePattern(vg, -half, -half, sprSz, sprSz, 0, sprImg, 1.0)
        nvgBeginPath(vg)
        nvgRect(vg, -half, -half, sprSz, sprSz)
        nvgFillPaint(vg, imgPat)
        nvgFill(vg)
        nvgRestore(vg)
    else
        -- 无精灵图时用兵种汉字 fallback
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, g.acted and 100 or 240))
        nvgText(vg, rightX + (boxW - halfW) / 2, boxY + boxH / 2, g.icon)
    end

    -- 受击闪白
    if flashAlpha > 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 3)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, flashAlpha))
        nvgFill(vg)
    end

    -- 已行动遮罩
    if g.acted then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 3)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 60))
        nvgFill(vg)
    end

    -- 兵力人数 (右下角, 显示实际人数)
    local unitCnt = g.unitCount or 1
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    -- 黑色描边增加可读性
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
    nvgText(vg, boxX + boxW - 1, boxY + boxH, tostring(unitCnt))
    nvgFillColor(vg, nvgRGBA(255, 255, 220, 230))
    nvgText(vg, boxX + boxW - 2, boxY + boxH - 1, tostring(unitCnt))

    -- HP 条 (军团下方)
    local hpBarW = boxW
    local hpBarH = 3
    local hpBarX = boxX
    local hpBarY = boxY + boxH + 1
    local hpRatio = g.hp / g.maxHP
    nvgBeginPath(vg)
    nvgRoundedRect(vg, hpBarX, hpBarY, hpBarW, hpBarH, 1)
    nvgFillColor(vg, nvgRGBA(30, 20, 15, 180))
    nvgFill(vg)
    local hpR, hpG, hpB = 80, 200, 80
    if hpRatio < 0.3 then hpR, hpG, hpB = 220, 60, 60
    elseif hpRatio < 0.6 then hpR, hpG, hpB = 220, 180, 60 end
    nvgBeginPath(vg)
    nvgRoundedRect(vg, hpBarX, hpBarY, hpBarW * hpRatio, hpBarH, 1)
    nvgFillColor(vg, nvgRGBA(hpR, hpG, hpB, 220))
    nvgFill(vg)

    -- 武将名 (军团上方)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    local nameAlpha = g.acted and 100 or 220
    if g.isPlayer then
        nvgFillColor(vg, nvgRGBA(160, 210, 255, nameAlpha))
    else
        nvgFillColor(vg, nvgRGBA(255, 170, 150, nameAlpha))
    end
    nvgText(vg, px, boxY - 1, g.heroName)
end


-- ============================================================================
-- 战旗网格 + 兵团精灵群渲染 (v2)
-- ============================================================================
function DrawTacticGrid()
    local ts = tacticState
    if not ts then return end
    local t = gameState.gameTime or 0
    local TacticsModule = require("systems.battle.tactics")

    -- 1) 纯色棋盘网格 (交替深浅, 12×7)
    for r = 1, TACTIC_ROWS do
        for c = 1, TACTIC_COLS do
            local cx, cy = TacticsModule.GridToScreen(r, c)
            local hw = TACTIC_CELL_W / 2
            local hh = TACTIC_CELL_H / 2
            local isDark = ((r + c) % 2 == 0)
            nvgBeginPath(vg)
            nvgRect(vg, cx - hw, cy - hh, TACTIC_CELL_W, TACTIC_CELL_H)
            if isDark then
                nvgFillColor(vg, nvgRGBA(45, 55, 35, 255))
            else
                nvgFillColor(vg, nvgRGBA(60, 75, 45, 255))
            end
            nvgFill(vg)
            -- 网格线
            nvgBeginPath(vg)
            nvgRect(vg, cx - hw, cy - hh, TACTIC_CELL_W, TACTIC_CELL_H)
            nvgStrokeColor(vg, nvgRGBA(90, 100, 70, 80))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)
        end
    end

    -- 2) 移动范围高亮 (蓝色半透明)
    local pulse = 0.5 + 0.3 * math.sin(t * 4)
    for _, mt in ipairs(ts.moveTargets) do
        local cx, cy = TacticsModule.GridToScreen(mt.row, mt.col)
        local hw, hh = TACTIC_CELL_W / 2, TACTIC_CELL_H / 2
        nvgBeginPath(vg); nvgRect(vg, cx - hw, cy - hh, TACTIC_CELL_W, TACTIC_CELL_H)
        nvgFillColor(vg, nvgRGBA(60, 140, 255, math.floor(70 * pulse))); nvgFill(vg)
    end

    -- 3) 攻击范围高亮 (红色半透明)
    local atkPulse = 0.5 + 0.3 * math.sin(t * 5)
    for _, at in ipairs(ts.attackTargets) do
        local cx, cy = TacticsModule.GridToScreen(at.row, at.col)
        local hw, hh = TACTIC_CELL_W / 2, TACTIC_CELL_H / 2
        nvgBeginPath(vg); nvgRect(vg, cx - hw, cy - hh, TACTIC_CELL_W, TACTIC_CELL_H)
        nvgFillColor(vg, nvgRGBA(255, 80, 60, math.floor(70 * atkPulse))); nvgFill(vg)
    end

    -- 4) 选中格子高亮 (黄色边框)
    if ts.selectedGroup then
        local g = ts.playerGroups[ts.selectedGroup]
        if g and g.alive then
            local cx, cy = TacticsModule.GridToScreen(g.row, g.col)
            local hw, hh = TACTIC_CELL_W / 2, TACTIC_CELL_H / 2
            local selPulse = 0.5 + 0.4 * math.sin(t * 6)
            nvgBeginPath(vg); nvgRect(vg, cx - hw, cy - hh, TACTIC_CELL_W, TACTIC_CELL_H)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(220 * selPulse)))
            nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
        end
    end

    -- 5) 绘制兵团 (先敌后我)
    nvgFontFaceId(vg, GetMainFont())
    for _, g in ipairs(ts.enemyGroups) do
        if g.alive then DrawTacticGroup(g, t) end
    end
    for _, g in ipairs(ts.playerGroups) do
        if g.alive then DrawTacticGroup(g, t) end
    end

    -- 6) 弹道特效
    DrawTacticProjectiles(ts, t)

    -- 7) 回合横幅
    if ts.bannerTimer and ts.bannerTimer > 0 and ts.bannerText then
        DrawTacticBanner(ts.bannerText, ts.isPlayerTurn)
    end

    -- 8) 回合信息 (左上角)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(220, 210, 180, 220))
    nvgText(vg, BATTLE_ZONE.left + 5, BATTLE_ZONE.top - 8,
        "回合 " .. ts.turnNumber)

    -- 9) 战场播报面板 (右上角)
    DrawBattleLog(ts)
end

--- 绘制单个战旗兵团 (实际精灵图阵列版)
function DrawTacticGroup(g, t)
    local px, py = g.screenX, g.screenY

    -- 受击闪烁
    local flashAlpha = 0
    if g.flashTimer and g.flashTimer > 0 then
        flashAlpha = math.floor(180 * (g.flashTimer / 0.5))
    end

    -- 兵团区域
    local boxW = TACTIC_CELL_W - 6
    local boxH = TACTIC_CELL_H - 14
    local boxX = px - boxW / 2
    local boxY = py - boxH / 2 + 1
    local c = g.troopColor

    -- 浅底色
    nvgBeginPath(vg)
    nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 3)
    nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], g.acted and 25 or 45))
    nvgFill(vg)

    -- 阵营边框 (蓝=我方, 红=敌方)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 3)
    if g.isPlayer then
        nvgStrokeColor(vg, nvgRGBA(80, 150, 255, g.acted and 60 or 180))
    else
        nvgStrokeColor(vg, nvgRGBA(255, 80, 60, g.acted and 60 or 180))
    end
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- === 精灵图阵列 ===
    local sprImg = IMG.unitSprites[g.spriteName or "sword"]
    local count = g.unitCount or 1

    -- 根据人数决定显示数量（上限16个精灵，以看清为主）
    local displayCount = math.min(count, 16)
    local cols, rows
    if displayCount <= 2 then cols = displayCount; rows = 1
    elseif displayCount <= 4 then cols = 2; rows = 2
    elseif displayCount <= 6 then cols = 3; rows = 2
    elseif displayCount <= 9 then cols = 3; rows = 3
    elseif displayCount <= 12 then cols = 4; rows = 3
    elseif displayCount <= 16 then cols = 4; rows = 4
    else cols = 4; rows = 4
    end
    count = displayCount

    local padX, padY = 2, 2
    local areaW = boxW - padX * 2
    local areaH = boxH - padY * 2
    local spacingX = areaW / cols
    local spacingY = areaH / rows
    -- 每个精灵尺寸 = 间距的最小值, 不超出格子
    local sprSz = math.min(spacingX, spacingY) * 0.92

    -- 朝向: 我方朝右, 敌方朝左
    local spName = g.spriteName or "sword"
    local nDir = _leftFacingSprites[spName] and -1 or 1
    local wDir = g.isPlayer and 1 or -1
    local flipX = nDir * wDir

    local globalAlpha = g.acted and 0.5 or 1.0

    if sprImg and sprImg > 0 then
        local soldierIdx = 0
        for row = 1, rows do
            for col = 1, cols do
                soldierIdx = soldierIdx + 1
                if soldierIdx > count then break end
                local sx = boxX + padX + (col - 0.5) * spacingX
                local sy = boxY + padY + (row - 0.5) * spacingY
                local half = sprSz / 2
                nvgSave(vg)
                nvgGlobalAlpha(vg, globalAlpha)
                nvgTranslate(vg, sx, sy)
                if flipX < 0 then nvgScale(vg, -1, 1) end
                local imgPat = nvgImagePattern(vg, -half, -half, sprSz, sprSz, 0, sprImg, 1.0)
                nvgBeginPath(vg)
                nvgRect(vg, -half, -half, sprSz, sprSz)
                nvgFillPaint(vg, imgPat)
                nvgFill(vg)
                nvgRestore(vg)
            end
            if soldierIdx >= count then break end
        end
    else
        -- 无精灵图时用兵种汉字 fallback
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, g.acted and 100 or 240))
        nvgText(vg, px, py, g.icon)
    end

    -- 受击闪白
    if flashAlpha > 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 3)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, flashAlpha))
        nvgFill(vg)
    end

    -- 已行动遮罩
    if g.acted then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 3)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 60))
        nvgFill(vg)
    end

    -- 兵力数字 (右下角)
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(255, 255, 220, 200))
    nvgText(vg, boxX + boxW - 2, boxY + boxH - 1, tostring(count))

    -- HP 条 (兵团下方)
    local hpBarW = boxW
    local hpBarH = 3
    local hpBarX = boxX
    local hpBarY = boxY + boxH + 1
    local hpRatio = g.hp / g.maxHP
    nvgBeginPath(vg)
    nvgRoundedRect(vg, hpBarX, hpBarY, hpBarW, hpBarH, 1)
    nvgFillColor(vg, nvgRGBA(30, 20, 15, 180))
    nvgFill(vg)
    local hpR, hpG, hpB = 80, 200, 80
    if hpRatio < 0.3 then hpR, hpG, hpB = 220, 60, 60
    elseif hpRatio < 0.6 then hpR, hpG, hpB = 220, 180, 60 end
    nvgBeginPath(vg)
    nvgRoundedRect(vg, hpBarX, hpBarY, hpBarW * hpRatio, hpBarH, 1)
    nvgFillColor(vg, nvgRGBA(hpR, hpG, hpB, 220))
    nvgFill(vg)

    -- 武将名 (兵团上方)
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    local nameAlpha = g.acted and 100 or 220
    if g.isPlayer then
        nvgFillColor(vg, nvgRGBA(160, 210, 255, nameAlpha))
    else
        nvgFillColor(vg, nvgRGBA(255, 170, 150, nameAlpha))
    end
    nvgText(vg, px, boxY - 1, g.heroName)
end

--- 绘制弹道特效 (弓兵箭矢)
function DrawTacticProjectiles(ts, t)
    if not ts.projectiles then return end
    for _, p in ipairs(ts.projectiles) do
        local progress = 1 - math.max(0, p.timer / p.totalTime)
        local cx = p.sx + (p.ex - p.sx) * progress
        local cy = p.sy + (p.ey - p.sy) * progress - 30 * math.sin(progress * math.pi)
        local c = p.color
        -- 箭矢
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, 3)
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 255))
        nvgFill(vg)
        -- 尾迹
        for ti2 = 1, 3 do
            local tp = math.max(0, progress - ti2 * 0.05)
            local tx = p.sx + (p.ex - p.sx) * tp
            local ty = p.sy + (p.ey - p.sy) * tp - 30 * math.sin(tp * math.pi)
            local alpha = math.floor(150 * (1 - ti2 / 3))
            nvgBeginPath(vg)
            nvgCircle(vg, tx, ty, 2)
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], alpha))
            nvgFill(vg)
        end
    end
end

--- 绘制战场播报面板 (右上角)
function DrawBattleLog(ts)
    if not ts.battleLog or #ts.battleLog == 0 then return end

    local logX = DESIGN_W - 220
    local logY = TB_GRID_TOP
    local logW = 210
    local maxVisible = 6
    local lineH = 16

    local visibleCount = math.min(#ts.battleLog, maxVisible)
    local bgH = visibleCount * lineH + 8
    nvgBeginPath(vg)
    nvgRoundedRect(vg, logX - 5, logY - 4, logW + 10, bgH, 4)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
    nvgFill(vg)

    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    local startIdx = math.max(1, #ts.battleLog - maxVisible + 1)
    local drawY = logY
    for i = startIdx, #ts.battleLog do
        local entry = ts.battleLog[i]
        local alpha = 220
        if entry.timer < 1.0 then
            alpha = math.max(0, math.floor(220 * entry.timer))
        end
        local ec = entry.color
        nvgFillColor(vg, nvgRGBA(ec[1], ec[2], ec[3], alpha))
        nvgText(vg, logX, drawY, entry.text)
        drawY = drawY + lineH
    end
end

--- 绘制回合横幅 (屏幕中央纯色banner)
function DrawTacticBanner(text, isPlayer)
    local bannerH = 50
    local by = DESIGN_H / 2 - bannerH / 2 - 30

    -- 全宽半透明条
    nvgBeginPath(vg)
    nvgRect(vg, 0, by, DESIGN_W, bannerH)
    if isPlayer then
        nvgFillColor(vg, nvgRGBA(30, 60, 120, 200))
    else
        nvgFillColor(vg, nvgRGBA(120, 30, 30, 200))
    end
    nvgFill(vg)

    -- 边线
    nvgBeginPath(vg); nvgMoveTo(vg, 0, by); nvgLineTo(vg, DESIGN_W, by)
    nvgStrokeColor(vg, nvgRGBA(255, 220, 120, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, by + bannerH); nvgLineTo(vg, DESIGN_W, by + bannerH)
    nvgStrokeColor(vg, nvgRGBA(255, 220, 120, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 200, 255))
    nvgText(vg, DESIGN_W / 2, by + bannerH / 2, text)
end


--- 绘制集结点标记 (十字准星 + 脉冲圈)
function DrawRallyMarkers()
    local markers = gameState.rallyMarkers
    if not markers then return end
    local t = gameState.gameTime or 0

    for i = #markers, 1, -1 do
        local m = markers[i]
        local age = t - m.time
        if age > m.duration then
            table.remove(markers, i)
        else
            local fadeAlpha = 1.0
            if age > m.duration - 0.5 then
                fadeAlpha = (m.duration - age) / 0.5
            end
            local tc = TROOP_TYPES[m.troopType] and TROOP_TYPES[m.troopType].color or {200, 200, 200}
            local a = math.floor(200 * fadeAlpha)

            -- 脉冲扩散圈
            local ringPulse = (age * 2) % 1.0  -- 每0.5秒一波
            local ringR = 10 + ringPulse * 25
            local ringA = math.floor(a * (1.0 - ringPulse))
            nvgBeginPath(vg)
            nvgCircle(vg, m.x, m.y, ringR)
            nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], ringA))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)

            -- 中心标记
            if m.isAttack then
                -- 进攻: ✕ 十字
                local cs = 8
                nvgBeginPath(vg)
                nvgMoveTo(vg, m.x - cs, m.y - cs); nvgLineTo(vg, m.x + cs, m.y + cs)
                nvgMoveTo(vg, m.x + cs, m.y - cs); nvgLineTo(vg, m.x - cs, m.y + cs)
                nvgStrokeColor(vg, nvgRGBA(255, 80, 60, a))
                nvgStrokeWidth(vg, 2.0)
                nvgStroke(vg)
            else
                -- 移动: ◇ 菱形
                local ds = 7
                nvgBeginPath(vg)
                nvgMoveTo(vg, m.x, m.y - ds)
                nvgLineTo(vg, m.x + ds, m.y)
                nvgLineTo(vg, m.x, m.y + ds)
                nvgLineTo(vg, m.x - ds, m.y)
                nvgClosePath(vg)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], math.floor(a * 0.6)))
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], a))
                nvgStrokeWidth(vg, 1.5)
                nvgStroke(vg)
            end
        end
    end
end


-- DrawUnitCloud 已移除 (战旗模式不需要云层)


function DrawUnitSprite(u)
    local uc = u.unitClass
    local uScale = uc and uc.unitScale or 1.0
    local sz = 24 * uScale          -- ★ 基础精灵尺寸放大 (原18, 看不清)
    local bob = math.sin(u.animTimer) * 2.5
    local px, py = u.x, u.y + bob

    -- === 完整精灵渲染 ===
    local spriteImg = IMG.unitSprites[uc and uc.sprite or "sword"]

    -- === 序列帧动画：行走摇摆 + 攻击放大 + 受伤抖动 ===
    local animAngle = 0
    local animScaleX = 1.0
    local animScaleY = 1.0
    local shakeX, shakeY = 0, 0
    local spriteName = uc and uc.sprite or "sword"
    local nativeDir = _leftFacingSprites[spriteName] and -1 or 1
    local wantDir = u.isPlayer and 1 or -1
    local flipX = nativeDir * wantDir

    local walkCycle = math.sin(u.animTimer * 4)
    animAngle = walkCycle * 0.12
    local stepBounce = math.abs(math.sin(u.animTimer * 4))
    animScaleY = 1.0 + stepBounce * 0.06
    animScaleX = 1.0 - stepBounce * 0.03

    if u.atkAnimTimer and u.atkAnimTimer > 0 then
        local atkT = u.atkAnimTimer
        local atkPulse = math.sin(atkT * 12) * math.max(0, 1 - atkT * 3)
        animScaleX = animScaleX + atkPulse * 0.2
        animScaleY = animScaleY + atkPulse * 0.15
        local leanDir = u.isPlayer and -1 or 1
        animAngle = animAngle + leanDir * math.max(0, 0.3 - atkT) * 0.5
    end

    if u.flashTimer > 0 then
        shakeX = math.sin(u.flashTimer * 60) * 2
        shakeY = math.cos(u.flashTimer * 45) * 1
    end

    local drawX = px + shakeX
    local drawY = py + shakeY

    if spriteImg and spriteImg > 0 then
        local alpha = 1.0
        if u.flashTimer > 0 then alpha = 0.4 + 0.6 * math.sin(u.flashTimer * 40) end
        if u.stealthing then alpha = alpha * 0.45 end
        nvgSave(vg); nvgGlobalAlpha(vg, alpha)
        -- 应用旋转和缩放变换
        nvgTranslate(vg, drawX, drawY)
        nvgRotate(vg, animAngle)
        nvgScale(vg, flipX * animScaleX, animScaleY)
        local halfSz = sz / 2
        local imgPat = nvgImagePattern(vg, -halfSz, -halfSz, sz, sz, 0, spriteImg, 1.0)
        nvgBeginPath(vg); nvgRect(vg, -halfSz, -halfSz, sz, sz)
        nvgFillPaint(vg, imgPat); nvgFill(vg)
        nvgRestore(vg)
    else
        -- 无精灵图时用彩色圆圈 + 兵种标记
        local ucId = uc and uc.id or 1
        local r = sz * 0.4
        local alpha = u.stealthing and 120 or 200
        nvgSave(vg)
        nvgTranslate(vg, drawX, drawY)
        nvgRotate(vg, animAngle)
        nvgScale(vg, flipX * animScaleX, animScaleY)
        nvgBeginPath(vg); nvgCircle(vg, 0, 0, r)
        if ucId == 9 then
            nvgFillColor(vg, u.isPlayer and nvgRGBA(255, 160, 50, alpha) or nvgRGBA(200, 60, 60, alpha))
        elseif ucId == 10 then
            nvgFillColor(vg, u.isPlayer and nvgRGBA(180, 100, 255, alpha) or nvgRGBA(200, 60, 60, alpha))
        elseif ucId == 11 then
            nvgFillColor(vg, u.isPlayer and nvgRGBA(160, 60, 120, alpha) or nvgRGBA(200, 60, 60, alpha))
        elseif ucId == 12 then
            nvgFillColor(vg, u.isPlayer and nvgRGBA(60, 200, 180, alpha) or nvgRGBA(200, 60, 60, alpha))
        elseif ucId == 13 then
            nvgFillColor(vg, u.isPlayer and nvgRGBA(255, 200, 50, alpha) or nvgRGBA(200, 60, 60, alpha))
        elseif ucId == 14 then
            nvgFillColor(vg, u.isPlayer and nvgRGBA(160, 80, 200, alpha) or nvgRGBA(200, 60, 60, alpha))
        elseif ucId == 15 then
            nvgFillColor(vg, u.isPlayer and nvgRGBA(80, 200, 255, alpha) or nvgRGBA(200, 60, 60, alpha))
        elseif ucId == 16 then
            nvgFillColor(vg, u.isPlayer and nvgRGBA(240, 180, 40, alpha) or nvgRGBA(200, 60, 60, alpha))
        else
            nvgFillColor(vg, u.isPlayer and nvgRGBA(100, 180, 255, alpha) or nvgRGBA(200, 60, 60, alpha))
        end
        nvgFill(vg)
        -- 兵种首字标记
        if uc and uc.name then
            nvgFontSize(vg, sz * 0.45)
            nvgFontFace(vg, "sans")
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(0, 0, string.sub(uc.name, 1, 3))
        end
        nvgRestore(vg)
    end

    -- 噩梦骑兵冲锋拖尾特效
    if uc and uc.id == 9 then
        local trailAlpha = math.floor(80 + 40 * math.sin(u.animTimer * 2))
        nvgBeginPath(vg)
        nvgMoveTo(vg, px - sz * 0.3, py + sz * 0.5)
        nvgLineTo(vg, px, py + sz * 0.9)
        nvgLineTo(vg, px + sz * 0.3, py + sz * 0.5)
        nvgFillColor(vg, u.isPlayer and nvgRGBA(255, 200, 80, trailAlpha) or nvgRGBA(200, 80, 80, trailAlpha))
        nvgFill(vg)
    end

    -- 讨伐巨兽光环特效
    if uc and uc.id == 10 then
        nvgBeginPath(vg); nvgCircle(vg, px, py, sz * 0.55)
        nvgStrokeColor(vg, u.isPlayer and nvgRGBA(180, 100, 255, 60) or nvgRGBA(200, 60, 60, 60))
        nvgStrokeWidth(vg, 2); nvgStroke(vg)
    end

    -- 腐灵祭司攻速光环标记（绿色小箭头）
    if u.healerAura then
        nvgBeginPath(vg)
        nvgMoveTo(vg, px - 4, py - sz * 0.5 - 2)
        nvgLineTo(vg, px, py - sz * 0.5 - 7)
        nvgLineTo(vg, px + 4, py - sz * 0.5 - 2)
        nvgFillColor(vg, nvgRGBA(80, 255, 120, 160)); nvgFill(vg)
        u.healerAura = false  -- 姣忓抚重置
    end

    -- 自分英雄脉冲特效
    if uc and uc.id == 13 then
        local pulse = 0.5 + 0.5 * math.sin(u.animTimer * 6)
        local pulseA = math.floor(40 + 60 * pulse)
        nvgBeginPath(vg); nvgCircle(vg, px, py, sz * (0.45 + 0.15 * pulse))
        nvgFillColor(vg, nvgRGBA(255, 200, 50, pulseA)); nvgFill(vg)
    end

    -- 傀儡操师操控丝线特效
    if uc and uc.id == 14 and not u.isPuppet then
        nvgStrokeColor(vg, nvgRGBA(180, 100, 255, 80))
        nvgStrokeWidth(vg, 1)
        nvgBeginPath(vg)
        nvgMoveTo(vg, px - sz * 0.3, py - sz * 0.4)
        nvgLineTo(vg, px - sz * 0.5, py - sz * 0.9)
        nvgMoveTo(vg, px + sz * 0.3, py - sz * 0.4)
        nvgLineTo(vg, px + sz * 0.5, py - sz * 0.9)
        nvgStroke(vg)
    end

    -- 霜骨冰巫霜冻光环
    if uc and uc.id == 15 then
        nvgBeginPath(vg); nvgCircle(vg, px, py, sz * 0.6)
        nvgStrokeColor(vg, nvgRGBA(100, 220, 255, 60 + math.floor(30 * math.sin(u.animTimer * 3))))
        nvgStrokeWidth(vg, 2); nvgStroke(vg)
    end

    -- 腐蝇虫群震动偏移（小型抖动）
    if uc and (uc.id == 16 or u.isSwarmling) then
        -- 额外小蜂翅膀闪烁
        local wingA = math.floor(80 + 60 * math.sin(u.animTimer * 12))
        nvgBeginPath(vg)
        nvgEllipse(vg, px - sz * 0.25, py - sz * 0.15, sz * 0.12, sz * 0.08)
        nvgEllipse(vg, px + sz * 0.25, py - sz * 0.15, sz * 0.12, sz * 0.08)
        nvgFillColor(vg, nvgRGBA(255, 240, 200, wingA)); nvgFill(vg)
    end

    -- 区域减速冰冻标记
    if u.isZoneSlowed then
        nvgBeginPath(vg); nvgCircle(vg, px, py, sz * 0.55)
        nvgFillColor(vg, nvgRGBA(100, 200, 255, 50)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(120, 210, 255, 120))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- ★ 小兵血条已移除(太密集影响观感)，仅保留变量供兵种徽章定位用
    local hpBarY = py - sz / 2 - 5
    local hpBarW = sz * 0.8
    -- DrawHP(px, hpBarY, hpBarW, 3.0 * uScale, u.hp / u.maxHp, u.isPlayer)

    -- === 兵种克制标识已移除（遮挡视野） ===
end


function DrawHP(cx, cy, w, h, ratio, isP)
    local x = cx - w / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, x, cy, w, h, 1)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 120)); nvgFill(vg)
    local fw = w * math.max(0, math.min(1, ratio))
    if fw > 0 then
        nvgBeginPath(vg); nvgRoundedRect(vg, x, cy, fw, h, 1)
        nvgFillColor(vg, isP and nvgRGBA(60, 210, 100, 230) or nvgRGBA(210, 50, 50, 230))
        nvgFill(vg)
    end
end


-- ============================================================================
    -- 云 (底层)
-- ============================================================================

function DrawParticles()
    for _, p in ipairs(particles) do
        if p.isDesign then
            local life = p.timer / p.life
            local alpha = math.floor(255 * (1 - life))
            local sz = p.size * (1 - life * 0.5)

            -- 冲击环特效 (大型粒子, size > 8)
            if p.isImpact then
                local ringR = 4 + sz * life * 3
                local ringA = math.floor(200 * (1 - life))
                -- 外环
                nvgBeginPath(vg); nvgCircle(vg, p.x, p.y, ringR)
                nvgStrokeColor(vg, nvgRGBA(p.color[1], p.color[2], p.color[3], ringA))
                nvgStrokeWidth(vg, math.max(0.5, 2 * (1 - life))); nvgStroke(vg)
                -- 内部渐变光晕
                local glowG = nvgRadialGradient(vg, p.x, p.y, 1, ringR * 0.7,
                    nvgRGBA(255, 255, 220, math.floor(ringA * 0.4)),
                    nvgRGBA(p.color[1], p.color[2], p.color[3], 0))
                nvgBeginPath(vg); nvgCircle(vg, p.x, p.y, ringR * 0.7)
                nvgFillPaint(vg, glowG); nvgFill(vg)
            -- 火花尾迹特效 (带轨迹的星形粒子)
            elseif p.isSpark then
                -- 星形粒子: 四角十字
                local half = sz * 0.5
                nvgBeginPath(vg)
                nvgMoveTo(vg, p.x - half, p.y)
                nvgLineTo(vg, p.x, p.y - half * 1.5)
                nvgLineTo(vg, p.x + half, p.y)
                nvgLineTo(vg, p.x, p.y + half * 1.5)
                nvgClosePath(vg)
                nvgFillColor(vg, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha)); nvgFill(vg)
                -- 微弱拖尾线
                if p.vx and p.vy then
                    local tailLen = math.sqrt(p.vx * p.vx + p.vy * p.vy) * 0.06
                    local nx = p.vx ~= 0 and -p.vx / math.abs(p.vx) or 0
                    local ny = p.vy ~= 0 and -p.vy / math.abs(p.vy) or 0
                    nvgBeginPath(vg)
                    nvgMoveTo(vg, p.x, p.y)
                    nvgLineTo(vg, p.x + nx * tailLen, p.y + ny * tailLen)
                    nvgStrokeColor(vg, nvgRGBA(p.color[1], p.color[2], p.color[3], math.floor(alpha * 0.5)))
                    nvgStrokeWidth(vg, 1); nvgStroke(vg)
                end
            else
                -- 标准圆形粒子 (带渐变发光)
                local glow = nvgRadialGradient(vg, p.x, p.y, sz * 0.2, sz,
                    nvgRGBA(p.color[1], p.color[2], p.color[3], alpha),
                    nvgRGBA(p.color[1], p.color[2], p.color[3], 0))
                nvgBeginPath(vg); nvgCircle(vg, p.x, p.y, sz)
                nvgFillPaint(vg, glow); nvgFill(vg)
                -- 中心亮点
                nvgBeginPath(vg); nvgCircle(vg, p.x, p.y, sz * 0.3)
                nvgFillColor(vg, nvgRGBA(255, 255, 240, math.floor(alpha * 0.8))); nvgFill(vg)
            end
        end
    end
end


--- 更新并绘制远程弹道特效
function UpdateAndDrawProjectiles(dt)
    local i = 1
    while i <= #projectiles do
        local p = projectiles[i]
        p.timer = p.timer + dt
        if p.timer >= p.maxTime then
            -- 着弹点微型冲击波
            AddParticle(p.tx, p.ty, {
                vx = 0, vy = 0, life = 0.25, size = 5,
                color = p.color, isImpact = true,
            })
            table.remove(projectiles, i)
        else
            -- 线性插值 + 弧线偏移 (抛物线效果)
            local t = p.timer / p.maxTime
            local cx = p.sx + (p.tx - p.sx) * t
            local cy = p.sy + (p.ty - p.sy) * t
            -- 抛物线弧度: 上弓型
            local arcH = math.abs(p.tx - p.sx) * 0.15
            cy = cy - math.sin(t * math.pi) * arcH
            local c = p.color
            -- 弹道尾迹 (多段渐隐)
            local segments = 4
            for s = 1, segments do
                local st2 = math.max(0, t - s * 0.08)
                local sx2 = p.sx + (p.tx - p.sx) * st2
                local sy2 = p.sy + (p.ty - p.sy) * st2 - math.sin(st2 * math.pi) * arcH
                local et2 = math.max(0, t - (s - 1) * 0.08)
                local ex2 = p.sx + (p.tx - p.sx) * et2
                local ey2 = p.sy + (p.ty - p.sy) * et2 - math.sin(et2 * math.pi) * arcH
                local segA = math.floor(120 * (1 - s / segments) * (1 - t * 0.3))
                if segA > 5 then
                    nvgBeginPath(vg)
                    nvgMoveTo(vg, sx2, sy2)
                    nvgLineTo(vg, ex2, ey2)
                    nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], segA))
                    nvgStrokeWidth(vg, math.max(0.5, 2 - s * 0.3)); nvgStroke(vg)
                end
            end
            -- 弹道头部发光体
            local headGlow = nvgRadialGradient(vg, cx, cy, 1, 7,
                nvgRGBA(255, 255, 240, 200), nvgRGBA(c[1], c[2], c[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, 7)
            nvgFillPaint(vg, headGlow); nvgFill(vg)
            -- 核心亮点
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, 2.5)
            nvgFillColor(vg, nvgRGBA(255, 255, 240, 240)); nvgFill(vg)
            i = i + 1
        end
    end
end


-- ============================================================================
-- HUD (暗黑地牢风)
-- ============================================================================

function DrawHUD()
    if fontId < 0 then return end

    -- 应用HUD偏移量
    local hOfsX = gameSettings.hudOffsetX or 0
    local hOfsY = gameSettings.hudOffsetY or 0

    -- ======== 精简顶部信息条 (军资/击杀/兵力) ========
    local hudH = 32
    local hudBg = nvgLinearGradient(vg, 0, 2 + hOfsY, 0, hudH + 2 + hOfsY,
        nvgRGBA(30, 25, 16, 190), nvgRGBA(20, 16, 10, 200))
    nvgBeginPath(vg); nvgRoundedRect(vg, 4 + hOfsX, 2 + hOfsY, DESIGN_W - 8, hudH, 4)
    nvgFillPaint(vg, hudBg); nvgFill(vg)

    -- 装饰线
    local topLine = nvgLinearGradient(vg, 60 + hOfsX, 3 + hOfsY, DESIGN_W - 60 + hOfsX, 3 + hOfsY,
        nvgRGBA(200, 165, 80, 0), nvgRGBA(200, 165, 80, 50))
    nvgBeginPath(vg)
    nvgMoveTo(vg, 60 + hOfsX, 3 + hOfsY); nvgLineTo(vg, DESIGN_W - 60 + hOfsX, 3 + hOfsY)
    nvgStrokePaint(vg, topLine); nvgStrokeWidth(vg, 0.6); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())
    local midY = 18 + hOfsY

    -- TB模式: 精简顶部信息 (仅显示双方兵团存活数)
    if rawget(_G, "tbState") then
        local ts = tbState
        local pAlive, eAlive = 0, 0
        for _, g in ipairs(ts.playerRegiments) do if g.alive then pAlive = pAlive + 1 end end
        for _, g in ipairs(ts.enemyRegiments) do if g.alive then eAlive = eAlive + 1 end end
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(16 + hOfsX, midY, "我军 " .. pAlive .. " 兵团")
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(DESIGN_W - 12 + hOfsX, midY, "敌军 " .. eAlive .. " 兵团")
    else
        -- 实时战斗模式: 完整信息 (军资/击杀/兵力)
        -- 军资
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(16 + hOfsX, midY, "军资")
        nvgFontSize(vg, 22)
        DrawWhiteInkText(50 + hOfsX, midY, tostring(gameState.gold))

        -- 击杀
        nvgFontSize(vg, 20)
        DrawWhiteInkText(120 + hOfsX, midY, "KO")
        nvgFontSize(vg, 22)
        DrawWhiteInkText(140 + hOfsX, midY, tostring(gameState.totalKills * TROOP_DISPLAY_SCALE))

        -- 兵力对比
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(DESIGN_W - 12 + hOfsX, midY, "己方 " .. (#playerUnits * TROOP_DISPLAY_SCALE) .. " 敌方 " .. (#enemyUnits * TROOP_DISPLAY_SCALE))
    end

    -- ======== FIGHT 阶段倒计时 (正上方居中) - TB模式跳过 ========
    if gameState.battlePhase == "FIGHT" and not rawget(_G, "tbState") then
        local t = gameState.gameTime
        local remainSec
        remainSec = math.max(0, math.ceil(BATTLE_TIME_LIMIT - gameState.battleTime))

        local timerStr = string.format("%d:%02d", math.floor(remainSec / 60), remainSec % 60)

        -- 倒计时背景胶囊
        local timerW = 72
        local timerH = 28
        local timerX = DESIGN_W / 2 - timerW / 2 + hOfsX
        local timerY = hudH + 4 + hOfsY
        nvgBeginPath(vg); nvgRoundedRect(vg, timerX, timerY, timerW, timerH, 10)
        if remainSec <= 30 then
            local urgPulse = 0.6 + 0.4 * math.sin(t * 6)
            nvgFillColor(vg, nvgRGBA(40, 8, 8, math.floor(180 * urgPulse))); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 80, 60, math.floor(160 * urgPulse))); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        else
            nvgFillColor(vg, nvgRGBA(12, 10, 6, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 80)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        end

        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(DESIGN_W / 2 + hOfsX, timerY + timerH / 2, timerStr)

        -- 阵型徽章 (计时器左侧)
        local formId = rawget(_G, "battleFormationId")
        if formId then
            local formName = formId
            for _, f in ipairs(FORMATIONS or {}) do
                if f.id == formId then formName = f.name; break end
            end
            local badgeW = 56
            local badgeH = timerH
            local badgeX = timerX - badgeW - 6 + hOfsX
            nvgBeginPath(vg); nvgRoundedRect(vg, badgeX, timerY, badgeW, badgeH, 4)
            nvgFillColor(vg, nvgRGBA(18, 35, 55, 185)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 160, 220, 130))
            nvgStrokeWidth(vg, 0.7); nvgStroke(vg)
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(badgeX + badgeW / 2, timerY + badgeH / 2, formName)
        end

        -- 士气标签 (计时器右侧)
        local moraleLabel = rawget(_G, "battleMoraleLabel")
        if moraleLabel and moraleLabel ~= "" then
            local mlW = 44
            local mlH = timerH
            local mlX = timerX + timerW + 6 + hOfsX
            nvgBeginPath(vg); nvgRoundedRect(vg, mlX, timerY, mlW, mlH, 4)
            nvgFillColor(vg, nvgRGBA(35, 18, 10, 185)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 160, 80, 120))
            nvgStrokeWidth(vg, 0.7); nvgStroke(vg)
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(mlX + mlW / 2, timerY + mlH / 2, moraleLabel)
        end
    end
end


-- ============================================================================
-- 基地血条 (贴在临界线旁边, 战场内显示)
-- ============================================================================

function DrawBaseHPBars()
    if fontId < 0 then return end
    -- TB模式不需要基地血条
    if rawget(_G, "tbState") then return end

    local bz = BATTLE_ZONE
    local barW = 200
    local barH = 7
    local centerX = DESIGN_W / 2

    nvgFontFaceId(vg, GetMainFont())

    -- ======== 敌方兵力条 (横屏: 右侧, 紧贴顶部信息栏下方) ========
    local eBarX = bz.enemyLine - barW - 20
    local eBarY = 48  -- 紧贴顶部信息栏 (hudH=32, Y=2~34) 下方

    local eAlive = #enemyUnits
    local eTotal = math.max(1, gameState.initialEnemyUnits or eAlive)

    -- 半透明底板
    nvgBeginPath(vg); nvgRoundedRect(vg, eBarX - 28, eBarY - 14, barW + 56, 28, 4)
    nvgFillColor(vg, nvgRGBA(15, 8, 5, 160)); nvgFill(vg)

    -- 标签
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(eBarX - 6, eBarY, "敌军")

    -- 兵力条背景
    nvgBeginPath(vg); nvgRoundedRect(vg, eBarX, eBarY - barH / 2, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(40, 15, 10, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 80, 60, 50))
    nvgStrokeWidth(vg, 0.4); nvgStroke(vg)

    -- 兵力条填充
    local eRatio = math.max(0, eAlive / eTotal)
    if eRatio > 0 then
        local fillW = barW * eRatio
        local eGrad = nvgLinearGradient(vg, eBarX, eBarY, eBarX + fillW, eBarY,
            nvgRGBA(180, 40, 25, 220), nvgRGBA(255, 90, 50, 240))
        nvgBeginPath(vg); nvgRoundedRect(vg, eBarX, eBarY - barH / 2, fillW, barH, 3)
        nvgFillPaint(vg, eGrad); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, eBarX, eBarY - barH / 2, fillW, barH * 0.35, 2)
        nvgFillColor(vg, nvgRGBA(255, 200, 180, 30)); nvgFill(vg)
    end

    -- 兵力数字
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(eBarX + barW + 6, eBarY, (eAlive * TROOP_DISPLAY_SCALE) .. "/" .. (eTotal * TROOP_DISPLAY_SCALE))

    -- ======== 玩家兵力条 (横屏: 左侧, 紧贴顶部信息栏下方) ========
    local pBarX = bz.playerLine + 20
    local pBarY = 48  -- 紧贴顶部信息栏下方

    local pAlive = #playerUnits
    local pTotal = math.max(1, gameState.initialPlayerUnits or pAlive)

    -- 半透明底板
    nvgBeginPath(vg); nvgRoundedRect(vg, pBarX - 28, pBarY - 14, barW + 56, 28, 4)
    nvgFillColor(vg, nvgRGBA(5, 10, 15, 160)); nvgFill(vg)

    -- 标签
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(pBarX - 6, pBarY, "我军")

    -- 兵力条背景
    nvgBeginPath(vg); nvgRoundedRect(vg, pBarX, pBarY - barH / 2, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(10, 20, 35, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 130, 170, 50))
    nvgStrokeWidth(vg, 0.4); nvgStroke(vg)

    -- 兵力条填充
    local pRatio = math.max(0, pAlive / pTotal)
    if pRatio > 0 then
        local fillW = barW * pRatio
        local pGrad = nvgLinearGradient(vg, pBarX, pBarY, pBarX + fillW, pBarY,
            nvgRGBA(35, 150, 190, 220), nvgRGBA(70, 220, 180, 240))
        nvgBeginPath(vg); nvgRoundedRect(vg, pBarX, pBarY - barH / 2, fillW, barH, 3)
        nvgFillPaint(vg, pGrad); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, pBarX, pBarY - barH / 2, fillW, barH * 0.35, 2)
        nvgFillColor(vg, nvgRGBA(200, 255, 255, 30)); nvgFill(vg)
    end

    -- 兵力数字
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(pBarX + barW + 6, pBarY, (pAlive * TROOP_DISPLAY_SCALE) .. "/" .. (pTotal * TROOP_DISPLAY_SCALE))

    -- ======== 兵力低警告 ========
    if pAlive <= math.floor(pTotal * 0.15) and pAlive > 0 and gameState.phase == "BATTLE" then
        local pulse = 0.5 + 0.5 * math.sin(gameState.gameTime * 6)
        nvgBeginPath(vg); nvgRoundedRect(vg, pBarX - 1, pBarY - barH / 2 - 1, barW + 2, barH + 2, 4)
        nvgStrokeColor(vg, nvgRGBA(255, 60, 40, math.floor(80 + 120 * pulse)))
        nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    end

end


