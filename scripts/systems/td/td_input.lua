-- ============================================================================
-- systems/td/td_input.lua - 塔防模式输入处理 (纯塔防重构版)
-- 用途: 武将选择/放置、HUD按钮、技能释放、聚焦/升级/重定位
-- ============================================================================
---@diagnostic disable: undefined-global

local TDData  = require("systems.td.td_data")
local TDLogic = require("systems.td.td_logic")

local M = {}

-- 长按检测
local pressStartTime = 0       -- 按下时间戳
local pressStartDX = 0         -- 按下的设计坐标
local pressStartDY = 0
local pressHeroIdx = 0         -- 长按的武将索引
local LONG_PRESS_DUR = 0.5     -- 长按阈值(秒)
local pressActive = false      -- 是否有活跃按压

-- ============================================================================
-- BeginPress 处理
-- ============================================================================

---@param sx number 屏幕坐标X
---@param sy number 屏幕坐标Y
---@param touchId number
function M.handlePress(sx, sy, touchId)
    local st = tdState
    if not st then return end

    local dx, dy = ScreenToDesign(sx, sy)

    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    local function HitCircle(cx, cy, radius)
        local ddx, ddy = dx - cx, dy - cy
        return (ddx * ddx + ddy * ddy) <= radius * radius
    end

    -- 记录按压起始信息
    pressStartTime = st.gameTime or 0
    pressStartDX = dx
    pressStartDY = dy
    pressHeroIdx = 0
    pressActive = true

    -- ======== 游戏结束返回按钮 ========
    if st.phase == "GAME_OVER" then
        if st.btnRects.gameOverBack and HitRect(st.btnRects.gameOverBack) then
            local TDState = require("systems.td.td_state")
            TDState.Reset()
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        return
    end

    -- ======== 技能目标选择模式 ========
    if st.targetingSkill and st.targetingSkill > 0 then
        local def = TDData.SKILL_DEFS[st.targetingSkill]
        if def then
            -- 点击地图区域释放技能
            if dx >= TDData.MAP_AREA_LEFT and dx <= TDData.MAP_AREA_RIGHT
                and dy >= TDData.MAP_AREA_TOP and dy <= TDData.MAP_AREA_BOTTOM then
                TDLogic.CastSkill(st.targetingSkill, dx, dy)
                st.targetingSkill = 0
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 点击其他地方取消
            st.targetingSkill = 0
            return
        end
    end

    -- ======== 重定位模式: 选择目标塔位 ========
    if st.repositionMode then
        if dx >= TDData.MAP_AREA_LEFT and dx <= TDData.MAP_AREA_RIGHT
            and dy >= TDData.MAP_AREA_TOP and dy <= TDData.MAP_AREA_BOTTOM then
            local slotKey = TDData.FindNearestSlot(dx, dy, 55)
            if slotKey then
                if st.placedHeroMap[slotKey] then
                    if rawget(_G, "ShowToast") then ShowToast("该位置已有武将") end
                else
                    local ok = TDLogic.RelocateHero(st.focusedHeroIdx, slotKey)
                    if ok then
                        st.repositionMode = false
                        PlaySFX(AUDIO.sfx_click)
                    end
                end
            else
                if rawget(_G, "ShowToast") then ShowToast("不可放置") end
            end
        else
            -- 点击非地图区域取消重定位
            st.repositionMode = false
        end
        return
    end

    -- ======== HUD 按钮 ========
    -- 暂停按钮
    if st.btnRects.pause and HitRect(st.btnRects.pause) then
        st.paused = not st.paused
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 倍速按钮
    if st.btnRects.speed and HitRect(st.btnRects.speed) then
        if st.speed == 1 then
            st.speed = 2
        elseif st.speed == 2 then
            st.speed = 3
        else
            st.speed = 1
        end
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 自动战斗按钮
    if st.btnRects.autoBattle and HitRect(st.btnRects.autoBattle) then
        st.autoBattle = not st.autoBattle
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 开战/下一波按钮
    if st.btnRects.startWave and HitRect(st.btnRects.startWave) then
        if st.phase == "PREPARE" or st.phase == "WAVE_CLEAR" then
            TDLogic.StartNextWave()
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- ======== 技能栏按钮 ========
    if st.btnRects.skillBtns then
        for i = 1, 5 do
            local rect = st.btnRects.skillBtns[i]
            if rect and HitRect(rect) then
                local def = TDData.SKILL_DEFS[i]
                if def then
                    -- 检查是否可用
                    local canUse = (st.totalEnergy >= def.energyCost) and (st.skills[i].cdTimer <= 0)
                    if canUse then
                        if def.needTarget then
                            -- 需要选目标: 进入目标选择模式
                            st.targetingSkill = i
                        else
                            -- 不需要目标: 直接释放
                            TDLogic.CastSkill(i, TDData.DESIGN_W / 2, TDData.DESIGN_H / 2)
                        end
                        PlaySFX(AUDIO.sfx_click)
                    else
                        if st.totalEnergy < def.energyCost then
                            if rawget(_G, "ShowToast") then ShowToast("能量不足") end
                        else
                            if rawget(_G, "ShowToast") then ShowToast("技能冷却中") end
                        end
                    end
                end
                return
            end
        end
    end

    -- ======== 升级按钮 ========
    if st.btnRects.upgradeBtn and HitRect(st.btnRects.upgradeBtn) then
        if st.focusedHeroIdx > 0 then
            TDLogic.UpgradeHero(st.focusedHeroIdx)
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- ======== 返回按钮 (底部栏) ========
    if st.btnRects.back and HitRect(st.btnRects.back) then
        local TDState = require("systems.td.td_state")
        TDState.Reset()
        PopPhase("MENU")
        phaseChangeCooldown = 0.3
        PlaySFX(AUDIO.sfx_click)
        SaveGameProgress()
        return
    end

    -- ======== 底部武将栏点击 ========
    for i = 1, 8 do
        local slotRect = st.btnRects.heroSlots and st.btnRects.heroSlots[i]
        if slotRect and HitRect(slotRect) then
            -- 检查是否已部署
            local alreadyPlaced = false
            for _, hero in ipairs(st.heroes) do
                if hero.rosterIdx == i then
                    alreadyPlaced = true
                    break
                end
            end
            if alreadyPlaced then
                if rawget(_G, "ShowToast") then ShowToast("此武将已部署") end
            else
                if st.selectedHeroIdx == i then
                    st.selectedHeroIdx = 0
                else
                    local cardIdx = st.roster[i]
                    local card = cardIdx and HERO_CARDS[cardIdx]
                    if card then
                        local cost = TDData.HERO_COST[card.quality] or 200
                        if st.gold < cost then
                            if rawget(_G, "ShowToast") then ShowToast("军资不足 (需要" .. cost .. ")") end
                        else
                            st.selectedHeroIdx = i
                        end
                    end
                end
            end
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end

    -- ======== 地图点击 ========
    if dx >= TDData.MAP_AREA_LEFT and dx <= TDData.MAP_AREA_RIGHT
        and dy >= TDData.MAP_AREA_TOP and dy <= TDData.MAP_AREA_BOTTOM then

        -- 放置武将模式
        if st.selectedHeroIdx > 0 then
            local slotKey = TDData.FindNearestSlot(dx, dy, 55)
            if slotKey then
                if st.placedHeroMap[slotKey] then
                    if rawget(_G, "ShowToast") then ShowToast("该位置已有武将") end
                else
                    local ok = TDLogic.PlaceHero(st.selectedHeroIdx, slotKey)
                    if ok then
                        st.selectedHeroIdx = 0
                        PlaySFX(AUDIO.sfx_click)
                    end
                end
            else
                if rawget(_G, "ShowToast") then ShowToast("不可放置") end
            end
            return
        end

        -- 点击已放置武将 → 聚焦
        local slotKey = TDData.FindNearestSlot(dx, dy, 40)
        if slotKey and st.placedHeroMap[slotKey] then
            local heroIdx = st.placedHeroMap[slotKey]
            if st.focusedHeroIdx == heroIdx then
                -- 再次点击同一武将: 取消聚焦
                st.focusedHeroIdx = 0
            else
                st.focusedHeroIdx = heroIdx
            end
            -- 记录长按检测的武将索引
            pressHeroIdx = st.focusedHeroIdx
            st.selectedHeroIdx = 0
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 点击空白地图: 取消聚焦
        if st.focusedHeroIdx > 0 then
            st.focusedHeroIdx = 0
        end
    end
end

-- ============================================================================
-- HandleMove 处理
-- ============================================================================

function M.handleMove(sx, sy, touchId)
    -- 如果移动距离过大, 取消长按判定
    if pressActive and pressHeroIdx > 0 then
        local dx, dy = ScreenToDesign(sx, sy)
        local moveDist = math.sqrt((dx - pressStartDX) ^ 2 + (dy - pressStartDY) ^ 2)
        if moveDist > 15 then
            pressHeroIdx = 0  -- 取消长按检测
        end
    end
end

-- ============================================================================
-- EndPress 处理 (长按检测)
-- ============================================================================

function M.handleEndPress(sx, sy, touchId)
    if not pressActive then return end
    pressActive = false

    local st = tdState
    if not st then return end

    -- 长按武将 → 进入重定位模式
    if pressHeroIdx > 0 then
        local elapsed = (st.gameTime or 0) - pressStartTime
        if elapsed >= LONG_PRESS_DUR then
            local hero = st.heroes[pressHeroIdx]
            if hero and not hero.dead then
                st.focusedHeroIdx = pressHeroIdx
                st.repositionMode = true
                if rawget(_G, "ShowToast") then ShowToast("选择新位置") end
                PlaySFX(AUDIO.sfx_click)
            end
        end
    end

    pressHeroIdx = 0
end

return M
