-- ui/battle_hud_units.lua - 三国武灵录 (从 battle_hud.lua 拆分)
-- ============================================================================
-- 战斗单位渲染
-- ============================================================================

function DrawBattleUnits()
    -- 战区分割线 (淡墨, 横屏: 垂直中线)
    nvgBeginPath(vg)
    local lineGrad = nvgLinearGradient(vg, BATTLE_ZONE.centerX, BATTLE_ZONE.top + 30,
        BATTLE_ZONE.centerX, BATTLE_ZONE.bottom - 30,
        nvgRGBA(200, 160, 80, 0), nvgRGBA(200, 160, 80, 30))
    nvgMoveTo(vg, BATTLE_ZONE.centerX, BATTLE_ZONE.top + 30)
    nvgLineTo(vg, BATTLE_ZONE.centerX, BATTLE_ZONE.bottom - 30)
    nvgStrokePaint(vg, lineGrad)
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 云 (底层)
    for _, u in ipairs(playerUnits) do if u.alive then DrawUnitCloud(u) end end
    for _, u in ipairs(enemyUnits) do if u.alive then DrawUnitCloud(u) end end
    -- 角色 (上层)
    for _, u in ipairs(playerUnits) do if u.alive then DrawUnitSprite(u) end end
    for _, u in ipairs(enemyUnits) do if u.alive then DrawUnitSprite(u) end end
end


function DrawUnitCloud(u)
    local t = gameState.gameTime + u.cloudSeed
    local bob = math.sin(u.animTimer) * 2.0
    local px, py = u.x, u.y + bob
    local cImg = (math.floor(u.cloudSeed * 10) % 2 == 0) and IMG.cloudA or IMG.cloudB
    if not cImg or cImg <= 0 then return end

    local cloudW = 46 + math.sin(t * 1.5) * 5
    local cloudH = cloudW * 0.5
    local cloudX = px - cloudW / 2 + math.sin(t * 0.8) * 2
    local cloudY = py + 5 - math.sin(t * 1.2) * 1
    local alpha = 0.5 + 0.2 * math.sin(t * 2)

    nvgSave(vg); nvgGlobalAlpha(vg, alpha)
    local imgPat = nvgImagePattern(vg, cloudX, cloudY, cloudW, cloudH, 0, cImg, 1.0)
    nvgBeginPath(vg)
    nvgEllipse(vg, cloudX + cloudW / 2, cloudY + cloudH / 2, cloudW / 2, cloudH / 2)
    nvgFillPaint(vg, imgPat); nvgFill(vg)
    nvgRestore(vg)
end


function DrawUnitSprite(u)
    local uc = u.unitClass
    local spriteImg = IMG.unitSprites[uc and uc.sprite or "sword"]
    local uScale = uc and uc.unitScale or 1.0
    local sz = 38 * uScale
    local bob = math.sin(u.animTimer) * 2.5
    local px, py = u.x, u.y + bob

    -- === 序列帧动画：行走摇摆 + 攻击放大 + 受伤抖动 ===
    local animAngle = 0       -- 旋转角度(弧度)
    local animScaleX = 1.0    -- X缩放
    local animScaleY = 1.0    -- Y缩放
    local shakeX, shakeY = 0, 0  -- 抖动偏移

    -- 行走摇摆动画：左右轻微倾斜模拟跑步
    local walkCycle = math.sin(u.animTimer * 4)
    animAngle = walkCycle * 0.12  -- ±7度摇摆
    -- 模拟脚步弹跳
    local stepBounce = math.abs(math.sin(u.animTimer * 4))
    animScaleY = 1.0 + stepBounce * 0.06  -- 轻微纵向拉伸
    animScaleX = 1.0 - stepBounce * 0.03  -- 对应横向压缩

    -- 攻击动画：攻击瞬间短暂放大+前倾
    if u.atkAnimTimer and u.atkAnimTimer > 0 then
        local atkT = u.atkAnimTimer
        local atkPulse = math.sin(atkT * 12) * math.max(0, 1 - atkT * 3)
        animScaleX = animScaleX + atkPulse * 0.2
        animScaleY = animScaleY + atkPulse * 0.15
        -- 攻击前倾
        local leanDir = u.isPlayer and -1 or 1
        animAngle = animAngle + leanDir * math.max(0, 0.3 - atkT) * 0.5
    end

    -- 受伤抖动
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
        nvgScale(vg, animScaleX, animScaleY)
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
        nvgScale(vg, animScaleX, animScaleY)
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
        u.healerAura = false  -- 每帧重置
    end

    -- 自爆亡魂脉冲特效
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

    local hpBarY = py - sz / 2 - 5
    local hpBarW = sz * 0.8
    DrawHP(px, hpBarY, hpBarW, 3.0 * uScale, u.hp / u.maxHp, u.isPlayer)

    -- === 兵种克制标识 (战争版) ===
    if u.troopType and rawget(_G, "TROOP_TYPES") then
        local tt = TROOP_TYPES[u.troopType]
        if tt then
            local badgeSz = 9 * uScale
            local bx = px - hpBarW / 2 - badgeSz - 1
            local by = hpBarY - 1
            -- 兵种背景圆
            nvgBeginPath(vg); nvgCircle(vg, bx, by + badgeSz * 0.4, badgeSz * 0.65)
            nvgFillColor(vg, nvgRGBA(tt.color[1], tt.color[2], tt.color[3], 160)); nvgFill(vg)
            -- 兵种首字
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, badgeSz * 1.1)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
            nvgText(vg, bx, by + badgeSz * 0.4, tt.icon, nil)
        end
    end
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
-- 粒子渲染 (设计坐标)
-- ============================================================================

function DrawParticles()
    for _, p in ipairs(particles) do
        if p.isDesign then
            local alpha = math.floor(255 * (1 - p.timer / p.life))
            local sz = p.size * (1 - p.timer / p.life * 0.5)
            nvgBeginPath(vg); nvgCircle(vg, p.x, p.y, sz)
            nvgFillColor(vg, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
            nvgFill(vg)
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
            table.remove(projectiles, i)
        else
            -- 线性插值当前位置
            local t = p.timer / p.maxTime
            local cx = p.sx + (p.tx - p.sx) * t
            local cy = p.sy + (p.ty - p.sy) * t
            local c = p.color
            -- 弹道头部光点
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, 3)
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 240)); nvgFill(vg)
            -- 弹道尾迹线
            local tailT = math.max(0, t - 0.4)
            local tailX = p.sx + (p.tx - p.sx) * tailT
            local tailY = p.sy + (p.ty - p.sy) * tailT
            nvgBeginPath(vg)
            nvgMoveTo(vg, tailX, tailY)
            nvgLineTo(vg, cx, cy)
            nvgStrokeColor(vg, nvgRGBA(c[1], c[2], c[3], math.floor(160 * (1 - t))))
            nvgStrokeWidth(vg, 2); nvgStroke(vg)
            -- 外发光
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, 6)
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 40)); nvgFill(vg)
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
    local hudH = 22
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
    local midY = 13 + hOfsY

    -- 军资
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(16 + hOfsX, midY, "军资")
    nvgFontSize(vg, 22)
    DrawWhiteInkText(50 + hOfsX, midY, tostring(gameState.gold))

    -- 击杀
    nvgFontSize(vg, 20)
    DrawWhiteInkText(120 + hOfsX, midY, "斩")
    nvgFontSize(vg, 22)
    DrawWhiteInkText(140 + hOfsX, midY, tostring(gameState.totalKills))

    -- 兵力 (右侧)
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(DESIGN_W - 12 + hOfsX, midY, "我:" .. #playerUnits .. " 敌:" .. #enemyUnits)

    -- ======== FIGHT 阶段倒计时 (正上方居中) ========
    if gameState.battlePhase == "FIGHT" then
        local t = gameState.gameTime
        local remainSec
        local isDummyBattle = gameState.isDummy
        if isDummyBattle then
            remainSec = math.max(0, math.ceil(dummyState.timer))
        else
            remainSec = math.max(0, math.ceil(BATTLE_TIME_LIMIT - gameState.battleTime))
        end

        local timerStr
        if isDummyBattle and dummyState.prepPhase then
            timerStr = "准备中"
        elseif isDummyBattle then
            timerStr = string.format("%ds", remainSec)
        else
            timerStr = string.format("%d:%02d", math.floor(remainSec / 60), remainSec % 60)
        end

        -- 倒计时背景胶囊
        local timerW = 72
        local timerH = 20
        local timerX = DESIGN_W / 2 - timerW / 2 + hOfsX
        local timerY = hudH + 4 + hOfsY
        nvgBeginPath(vg); nvgRoundedRect(vg, timerX, timerY, timerW, timerH, 10)
        if (isDummyBattle and not dummyState.prepPhase) or remainSec <= 30 then
            local urgPulse = 0.6 + 0.4 * math.sin(t * 6)
            nvgFillColor(vg, nvgRGBA(40, 8, 8, math.floor(180 * urgPulse))); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 80, 60, math.floor(160 * urgPulse))); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        else
            nvgFillColor(vg, nvgRGBA(12, 10, 6, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 80)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        end

        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(DESIGN_W / 2 + hOfsX, timerY + timerH / 2, timerStr)
    end
end


-- ============================================================================
-- 基地血条 (贴在临界线旁边, 战场内显示)
-- ============================================================================

function DrawBaseHPBars()
    if fontId < 0 then return end

    local bz = BATTLE_ZONE
    local barW = 200
    local barH = 7
    local centerX = DESIGN_W / 2

    nvgFontFaceId(vg, GetMainFont())

    -- ======== 敌方基地血条 (横屏: 右侧临界线旁) ========
    local eBarX = bz.enemyLine - barW - 20
    local eBarY = bz.top + 10

    -- 半透明底板
    nvgBeginPath(vg); nvgRoundedRect(vg, eBarX - 28, eBarY - 8, barW + 56, 16, 4)
    nvgFillColor(vg, nvgRGBA(15, 8, 5, 160)); nvgFill(vg)

    -- 标签
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(eBarX - 6, eBarY, "敌")

    -- 血量条背景
    nvgBeginPath(vg); nvgRoundedRect(vg, eBarX, eBarY - barH / 2, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(40, 15, 10, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 80, 60, 50))
    nvgStrokeWidth(vg, 0.4); nvgStroke(vg)

    -- 血量条填充
    local eMax = gameState.enemyBaseMax or BASE_HP_MAX
    local eRatio = math.max(0, gameState.enemyBaseHP / eMax)
    if eRatio > 0 then
        local fillW = barW * eRatio
        local eGrad = nvgLinearGradient(vg, eBarX, eBarY, eBarX + fillW, eBarY,
            nvgRGBA(180, 40, 25, 220), nvgRGBA(255, 90, 50, 240))
        nvgBeginPath(vg); nvgRoundedRect(vg, eBarX, eBarY - barH / 2, fillW, barH, 3)
        nvgFillPaint(vg, eGrad); nvgFill(vg)
        -- 高光
        nvgBeginPath(vg); nvgRoundedRect(vg, eBarX, eBarY - barH / 2, fillW, barH * 0.35, 2)
        nvgFillColor(vg, nvgRGBA(255, 200, 180, 30)); nvgFill(vg)
    end

    -- 血量数字
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(eBarX + barW + 6, eBarY, gameState.enemyBaseHP .. "/" .. eMax)

    -- ======== 玩家基地血条 (横屏: 左侧临界线旁) ========
    local pBarX = bz.playerLine + 20
    local pBarY = bz.top + 10

    -- 半透明底板
    nvgBeginPath(vg); nvgRoundedRect(vg, pBarX - 28, pBarY - 8, barW + 56, 16, 4)
    nvgFillColor(vg, nvgRGBA(5, 10, 15, 160)); nvgFill(vg)

    -- 标签
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(pBarX - 6, pBarY, "我")

    -- 血量条背景
    nvgBeginPath(vg); nvgRoundedRect(vg, pBarX, pBarY - barH / 2, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(10, 20, 35, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 130, 170, 50))
    nvgStrokeWidth(vg, 0.4); nvgStroke(vg)

    -- 血量条填充
    local pMax = gameState.playerBaseMax or BASE_HP_MAX
    local pRatio = math.max(0, gameState.playerBaseHP / pMax)
    if pRatio > 0 then
        local fillW = barW * pRatio
        local pGrad = nvgLinearGradient(vg, pBarX, pBarY, pBarX + fillW, pBarY,
            nvgRGBA(35, 150, 190, 220), nvgRGBA(70, 220, 180, 240))
        nvgBeginPath(vg); nvgRoundedRect(vg, pBarX, pBarY - barH / 2, fillW, barH, 3)
        nvgFillPaint(vg, pGrad); nvgFill(vg)
        -- 高光
        nvgBeginPath(vg); nvgRoundedRect(vg, pBarX, pBarY - barH / 2, fillW, barH * 0.35, 2)
        nvgFillColor(vg, nvgRGBA(200, 255, 255, 30)); nvgFill(vg)
    end

    -- 血量数字
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(pBarX + barW + 6, pBarY, gameState.playerBaseHP .. "/" .. pMax)

    -- ======== 血量低警告 ========
    local warningThreshold = math.floor((gameState.playerBaseMax or BASE_HP_MAX) * 0.15)
    if gameState.playerBaseHP <= warningThreshold and gameState.phase == "BATTLE" then
        local pulse = 0.5 + 0.5 * math.sin(gameState.gameTime * 6)
        -- 玩家血条闪红边框
        nvgBeginPath(vg); nvgRoundedRect(vg, pBarX - 1, pBarY - barH / 2 - 1, barW + 2, barH + 2, 4)
        nvgStrokeColor(vg, nvgRGBA(255, 60, 40, math.floor(80 + 120 * pulse)))
        nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    end
end


