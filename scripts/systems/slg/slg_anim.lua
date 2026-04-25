-- ============================================================================
-- slg/slg_anim.lua - SLG行军动画与战斗动画模块
-- 用途: 行军视觉效果(城池间兵力移动)、AI战斗动画队列(攻城/换旗/欢呼)
-- 依赖: worldMapState(全局), WORLD_CITIES(全局), ui.anim(延迟加载)
-- 导出: StartMarchAnim, IsMarchActive, UpdateMarch, DrawMarch,
--       AdvanceBattleAnimPhase, UpdateBattleAnim
-- ============================================================================
---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 行军动画系统 (城池间兵力移动的视觉效果)
-- ============================================================================

---@class MarchAnimState
---@field active boolean 是否正在播放
---@field fromCityId number|nil 出发城池ID
---@field toCityId number|nil 目标城池ID
---@field progress number 动画进度 0~1
---@field duration number 动画时长(秒)
---@field callback function|nil 动画结束回调
---@field troops number 行军兵力数

---@type MarchAnimState
local marchAnim = {
    active = false,
    fromCityId = nil,
    toCityId = nil,
    progress = 0,
    duration = 1.2,
    callback = nil,
    troops = 0,
}

function M.StartMarchAnim(fromId, toId, troops, cb)
    marchAnim.active = true
    marchAnim.fromCityId = fromId
    marchAnim.toCityId = toId
    marchAnim.progress = 0
    marchAnim.troops = troops or 0
    marchAnim.callback = cb
    marchAnim.duration = 1.2
end

function M.IsMarchActive()
    return marchAnim.active
end

function M.UpdateMarch(dt)
    if not marchAnim.active then return end
    marchAnim.progress = marchAnim.progress + dt / marchAnim.duration
    if marchAnim.progress >= 1.0 then
        marchAnim.active = false
        marchAnim.progress = 1.0
        if marchAnim.callback then marchAnim.callback() end
        marchAnim.callback = nil
    end
end

function M.DrawMarch()
    if not marchAnim.active then return end
    local st = worldMapState
    local W, H = DESIGN_W, DESIGN_H
    local p = marchAnim.progress
    local t = gameState.gameTime or 0

    local midX = W / 2
    local midY = H / 2

    -- 半透明遮罩 (聚焦注意力)
    nvgBeginPath(vg); nvgRect(vg, 0, midY - 60, W, 120)
    nvgFillColor(vg, nvgRGBA(10, 5, 2, math.floor(100 * math.min(1, p * 3)))); nvgFill(vg)

    -- 行军路径动态光线 (屏幕中央横向)
    local pathW = 200
    local pathX0 = midX - pathW / 2
    local pathY = midY
    -- 底层路径描边
    nvgBeginPath(vg)
    nvgMoveTo(vg, pathX0, pathY)
    nvgLineTo(vg, pathX0 + pathW * p, pathY)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 60))
    nvgStrokeWidth(vg, 6); nvgLineCap(vg, NVG_ROUND); nvgStroke(vg)
    -- 高亮路径
    nvgBeginPath(vg)
    nvgMoveTo(vg, pathX0, pathY)
    nvgLineTo(vg, pathX0 + pathW * p, pathY)
    nvgStrokeColor(vg, nvgRGBA(255, 220, 120, 120))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)
    -- 流动光点
    local flowDots = 8
    for i = 0, flowDots do
        local dotP = ((i / flowDots) + t * 0.8) % 1.0
        if dotP <= p then
            local dx = pathX0 + pathW * dotP
            local da = math.floor(140 * (1 - math.abs(dotP / p - 0.5) * 2))
            nvgBeginPath(vg); nvgCircle(vg, dx, pathY, 2)
            nvgFillColor(vg, nvgRGBA(255, 230, 160, da)); nvgFill(vg)
        end
    end

    -- 部队图标 (沿路径移动)
    local armyX = pathX0 + pathW * p
    local armyY = pathY

    -- 尘土粒子
    if p > 0.05 and p < 0.95 then
        for i = 1, 4 do
            local dp = (t * 1.5 + i * 0.25) % 1.0
            local dustX = armyX - 10 - i * 6 - dp * 8
            local dustY = armyY + 4 - dp * 10
            local dustA = math.floor(60 * (1 - dp))
            local dustS = 2 + dp * 5
            nvgBeginPath(vg); nvgCircle(vg, dustX, dustY, dustS)
            nvgFillColor(vg, nvgRGBA(180, 160, 120, dustA)); nvgFill(vg)
        end
    end

    -- 外层光晕
    local pulse = 0.8 + 0.2 * math.sin(t * 6)
    local glow = nvgRadialGradient(vg, armyX, armyY, 6, 28,
        nvgRGBA(255, 210, 60, math.floor(120 * pulse)), nvgRGBA(255, 180, 40, 0))
    nvgBeginPath(vg); nvgCircle(vg, armyX, armyY, 28)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 部队主体
    nvgBeginPath(vg); nvgCircle(vg, armyX, armyY, 14)
    nvgFillColor(vg, nvgRGBA(230, 180, 50, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 230, 160, 220))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 剑图标
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 250, 230, 255))
    nvgText(vg, armyX, armyY, "⚔", nil)

    -- 小旗帜
    local fxb = armyX - 8
    local fyb = armyY - 18
    local fw = math.sin(t * 8) * 2
    nvgBeginPath(vg)
    nvgMoveTo(vg, fxb, fyb + 10); nvgLineTo(vg, fxb, fyb - 4)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 100, 220))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, fxb, fyb - 4)
    nvgLineTo(vg, fxb + 10 + fw, fyb - 2 + fw * 0.3)
    nvgLineTo(vg, fxb + 8 + fw * 0.5, fyb + 2)
    nvgLineTo(vg, fxb, fyb + 1)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(220, 180, 60, 230)); nvgFill(vg)

    -- 兵力文字
    if marchAnim.troops > 0 then
        nvgFontSize(vg, 20); nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
        nvgText(vg, midX + 1, midY + 23, "行军中 " .. tostring(marchAnim.troops) .. " 人", nil)
        nvgFillColor(vg, nvgRGBA(255, 240, 180, 230))
        nvgText(vg, midX, midY + 22, "行军中 " .. tostring(marchAnim.troops) .. " 人", nil)
    end

    -- 进度条 (带渐变)
    local barW2, barH2 = 120, 5
    local barX = midX - barW2 / 2
    local barY2 = midY + 44
    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY2, barW2, barH2, 2.5)
    nvgFillColor(vg, nvgRGBA(40, 25, 10, 140)); nvgFill(vg)
    -- 填充渐变
    local fillW = barW2 * p
    if fillW > 1 then
        local barGrad = nvgLinearGradient(vg, barX, barY2, barX + fillW, barY2,
            nvgRGBA(255, 180, 40, 220), nvgRGBA(255, 230, 100, 220))
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY2, fillW, barH2, 2.5)
        nvgFillPaint(vg, barGrad); nvgFill(vg)
    end
    -- 高光条
    nvgBeginPath(vg); nvgRoundedRect(vg, barX + 1, barY2 + 1, fillW - 2, barH2 * 0.35, 1)
    nvgFillColor(vg, nvgRGBA(255, 255, 220, 60)); nvgFill(vg)
end

-- ============================================================================
-- AI 战斗动画队列 (结束回合后, 地图上展示行军/攻城/换旗/欢呼/通知)
-- ============================================================================

---@type table<string, number> 各动画阶段持续时间(秒)
local BATTLE_ANIM_DUR = {
    march   = 1.5,
    siege   = 0.6,
    capture = 0.8,
    cheer   = 0.8,
    notify  = 2.0,
}

--- 推进到下一动画阶段, 或下一事件, 或结束进入战报
function M.AdvanceBattleAnimPhase()
    local st = worldMapState
    local data = st.battleAnimData
    if not data then
        if st.battleAnimIsPlayer then
            st.battleAnimIsPlayer = nil
            -- 检查是否有招降阶段
            if st.capturedHeroes and #st.capturedHeroes > 0 then
                st.phase = "SURRENDER"
            else
                st.phase = "MAP"
            end
            -- 启动延迟的攻占 ActionCard 弹窗
            if st._pendingActionCard then
                local AnimFX = require("ui.anim")
                local now = gameState.gameTime or 0
                local ac = st._pendingActionCard
                AnimFX.StartFlash(255, 200, 50, 0.4, now)
                AnimFX.StartActionCard(ac.icon, ac.title, ac.desc, ac.color, now)
                AnimFX.StartShake(5, 0.35, now)
                if rawget(_G, "AddFloatText") then
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, ac.title .. "!", 2.5, ac.color, 24)
                end
                st._pendingActionCard = nil
            end
        else
            st.phase = "TURN_REPORT"
        end
        return
    end
    local phase = st.battleAnimPhase
    local isConquest = (data.type == "conquest")

    -- 确定下一阶段
    local nextPhase
    if phase == "march" then
        nextPhase = "siege"
    elseif phase == "siege" then
        nextPhase = isConquest and "capture" or "notify"
    elseif phase == "capture" then
        nextPhase = "cheer"
    elseif phase == "cheer" then
        nextPhase = "notify"
    else
        nextPhase = nil  -- notify 结束
    end

    if nextPhase then
        st.battleAnimPhase = nextPhase
        st.battleAnimT = 0
        -- capture 阶段触发震屏 + 闪烁
        if nextPhase == "capture" then
            local AnimFX = require("ui.anim")
            AnimFX.StartShake(8, 0.5, gameState.gameTime or 0)
            AnimFX.StartFlash(255, 100, 30, 0.3, gameState.gameTime or 0)
        end
        -- 攻城/换旗/欢呼/通知: 聚焦目标城
        if nextPhase ~= "march" and data.toId then
            local toCity = WORLD_CITIES[data.toId]
            if toCity then
                st.mapTargetX = toCity.x
                st.mapTargetY = toCity.y
                st.mapTargetZoom = 2.0
            end
        end
    else
        -- 当前事件播放完毕, 尝试下一事件
        local idx = st.battleAnimIdx + 1
        if st.battleAnims and idx <= #st.battleAnims then
            st.battleAnimIdx = idx
            st.battleAnimData = st.battleAnims[idx]
            st.battleAnimPhase = "march"
            st.battleAnimT = 0
            local nd = st.battleAnims[idx]
            if nd and nd.fromId then
                local fc = WORLD_CITIES[nd.fromId]
                if fc then
                    st.mapTargetX = fc.x
                    st.mapTargetY = fc.y
                    st.mapTargetZoom = 2.0
                end
            end
        else
            -- 全部播放完毕
            local isPlayer = st.battleAnimIsPlayer
            st.battleAnims = nil
            st.battleAnimIdx = 0
            st.battleAnimPhase = nil
            st.battleAnimT = 0
            st.battleAnimData = nil
            st.battleAnimIsPlayer = nil
            if isPlayer then
                -- 检查是否有招降阶段
                if st.capturedHeroes and #st.capturedHeroes > 0 then
                    st.phase = "SURRENDER"
                else
                    st.phase = "MAP"
                end
                -- 启动延迟的攻占 ActionCard 弹窗
                if st._pendingActionCard then
                    local AnimFX = require("ui.anim")
                    local now = gameState.gameTime or 0
                    local ac = st._pendingActionCard
                    AnimFX.StartFlash(255, 200, 50, 0.4, now)
                    AnimFX.StartActionCard(ac.icon, ac.title, ac.desc, ac.color, now)
                    AnimFX.StartShake(5, 0.35, now)
                    if rawget(_G, "AddFloatText") then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, ac.title .. "!", 2.5, ac.color, 24)
                    end
                    st._pendingActionCard = nil
                end
            else
                st.phase = "TURN_REPORT"
            end
        end
    end
end

--- 每帧更新战斗动画计时 + 自动推进 + 镜头跟随
function M.UpdateBattleAnim(dt)
    local st = worldMapState
    if st.phase ~= "BATTLE_ANIM" then return end
    if not st.battleAnims or not st.battleAnimData then
        st.phase = "TURN_REPORT"; return
    end

    -- AI vs AI 战斗3倍速播放
    local speed = (st.battleAnimData and st.battleAnimData.isAIBattle) and 3.0 or 1.0
    st.battleAnimT = st.battleAnimT + dt * speed
    local phase = st.battleAnimPhase
    local dur = BATTLE_ANIM_DUR[phase] or 1.0

    -- 行军阶段: 镜头跟随部队
    if phase == "march" then
        local data = st.battleAnimData
        local fromCity = WORLD_CITIES[data.fromId]
        local toCity   = WORLD_CITIES[data.toId]
        if fromCity and toCity then
            local p = math.min(1, st.battleAnimT / dur)
            st.mapTargetX = fromCity.x + (toCity.x - fromCity.x) * p
            st.mapTargetY = fromCity.y + (toCity.y - fromCity.y) * p
        end
    end

    -- 超过时长自动推进
    if st.battleAnimT >= dur then
        M.AdvanceBattleAnimPhase()
    end
end


return M
