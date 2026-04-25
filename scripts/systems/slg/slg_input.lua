-- ============================================================================
-- slg/slg_input.lua - 三国武灵传：SLG输入处理 + 行军动画 + 新手引导
-- 适配新UI: 左侧城池卡片列表 + 右侧操作面板 (无地图城池点击)
-- ============================================================================

---@diagnostic disable: undefined-global

local Data   = require("systems.slg.slg_data")
local Render = require("systems.slg.slg_render")

local STRATAGEMS = Data.STRATAGEMS
local GetFC            = Render.GetFC
local DrawBtn          = Render.DrawBtn
local DrawTextOutlined = Render.DrawTextOutlined

local M = {}

-- 前向声明: HitRect 在下方定义，TryEndTurnBtn 需要提前引用
local HitRect

-- 辅助: 检测结束回合按钮点击, 返回 true 表示已处理
local function TryEndTurnBtn(st, dx, dy)
    if st.btn_endTurn and HitRect(st.btn_endTurn, dx, dy) then
        local Anim = require("ui.anim")
        Anim.StartTransition(function() WorldMap.EndTurn() end, 0.2)
        PlaySFX(AUDIO.sfx_click)
        return true
    end
    return false
end

-- ============================================================================
-- 地图拖拽+缩放 (每帧轮询鼠标状态)
-- ============================================================================

--- 限制地图中心点，确保地图边缘不露出视口空白
local function ClampMapCenter(st)
    local rs = st._mapRenderScale or 1
    local vw = (st._mapViewW or 0) / rs  -- 视口在地图坐标中的宽度
    local vh = (st._mapViewH or 0) / rs  -- 视口在地图坐标中的高度
    local MAP_W = Render.MAP_W
    local MAP_H = Render.MAP_H
    -- 如果视口比地图小, 限制中心点使边缘不露白
    if vw < MAP_W then
        st.mapCenterX = math.max(vw / 2, math.min(MAP_W - vw / 2, st.mapCenterX))
    else
        st.mapCenterX = MAP_W / 2  -- 地图比视口小，居中
    end
    if vh < MAP_H then
        st.mapCenterY = math.max(vh / 2, math.min(MAP_H - vh / 2, st.mapCenterY))
    else
        st.mapCenterY = MAP_H / 2
    end
end

--- 设计坐标系下的鼠标位置 (使用全局 ScreenToDesign)
local function GetDesignMousePos()
    local pos = input.mousePosition
    return ScreenToDesign(pos.x, pos.y)
end

--- 每帧调用: 处理地图拖拽平移
function M.UpdateMapDrag(dt)
    local st = worldMapState
    if not st or not st.inited then return end

    -- 强引导: 自动滚动/自动计时步骤禁止地图拖拽
    if wmGuide and wmGuide.active and WM_GUIDE_STEPS then
        local stepData = WM_GUIDE_STEPS[wmGuide.step]
        if stepData then
            local wf = stepData.waitFor
            if wf == "auto_timer" or wf == "scroll_to_enemy" then
                st.mapDragging = false
                st._heroPanelDragging = false
                return
            end
        end
    end

    -- 双指缩放时抑制拖拽，避免双指操作被误判为平移
    if input:GetNumTouches() >= 2 then
        st.mapDragging = false
        st._heroPanelDragging = false
        return
    end

    local mouseDown = input:GetMouseButtonDown(MOUSEB_LEFT)
    local dmx, dmy = GetDesignMousePos()

    -- 弹窗打开时，仅允许弹窗外区域拖拽（点击弹窗内不启动拖拽）
    local popRect = st.heroPopup and st._heroPopupRect
    if popRect and dmx >= popRect.x and dmx <= popRect.x + popRect.w
       and dmy >= popRect.y and dmy <= popRect.y + popRect.h then
        -- 鼠标在弹窗区域内，不处理拖拽
        st.mapDragging = false
        st._heroPanelDragging = false
        return
    end

    -- ======== 右侧面板触摸拖拽滚动 ========
    -- 确定当前 phase 的可滚动区域和滚动状态键
    local heroScrollArea = nil
    local heroScrollKey = nil
    local heroTotalHKey = nil
    if st.phase == "MAP" and st._mapPanelHeroScrollArea then
        heroScrollArea = st._mapPanelHeroScrollArea
        heroScrollKey = "mapPanelHeroScroll"
        heroTotalHKey = "_mapPanelHeroTotalH"
    elseif st.phase == "HERO_MANAGE" then
        heroScrollArea = st._heroManageScrollArea
        heroScrollKey = "heroManageScroll"
        heroTotalHKey = "_heroManageTotalH"
    elseif st.phase == "TRANSFER_HERO_SELECT" and st._transferHeroScrollArea then
        heroScrollArea = st._transferHeroScrollArea
        heroScrollKey = "_transferHeroScroll"
        heroTotalHKey = "_transferHeroTotalH"
    elseif st.phase == "DEPLOY" and st._deployHeroScrollArea then
        heroScrollArea = st._deployHeroScrollArea
        heroScrollKey = "deployHeroScroll"
        heroTotalHKey = "_deployHeroTotalH"
    end

    -- 检测触摸是否在英雄滚动子区域内
    local inHeroArea = false
    if heroScrollArea then
        local sa = heroScrollArea
        inHeroArea = dmx >= sa.x and dmx <= sa.x + sa.w
                     and dmy >= sa.y and dmy <= sa.y + sa.h
    end

    -- 检测触摸是否在整个右侧面板区域内 (面板展开时)
    local L = Render.LAYOUT
    local panelCollapsed = st.rightPanelCollapsed or false
    local hasPanel = (st.selectedCity ~= nil) or (st.phase ~= "MAP" and st.phase ~= "BATTLE_ANIM")
    local isFullscreenPhase = (st.phase == "CAMPAIGN_SELECT" or st.phase == "FACTION_SELECT" or st.phase == "TURN_REPORT")
    -- 非MAP阶段的面板(HERO_MANAGE/APPRENTICE/AFFAIRS等)始终可见可交互，不受收缩状态影响
    local isSubPhasePanel = (st.phase ~= "MAP" and st.phase ~= "BATTLE_ANIM" and not isFullscreenPhase)
    local panelVisible = isSubPhasePanel or (not panelCollapsed and hasPanel)
    local inPanelArea = false
    if panelVisible and not isFullscreenPhase then
        local panelX = DESIGN_W - L.RIGHT_W
        local panelY = L.TOP_BAR_H
        inPanelArea = dmx >= panelX and dmx <= DESIGN_W
                      and dmy >= panelY and dmy <= DESIGN_H
    end

    if mouseDown then
        if st._heroPanelDragging then
            -- 面板拖拽中: 垂直增量 → 滚动
            local ddy = dmy - (st._heroPanelDragLastY or dmy)
            if math.abs(ddy) > 1 then
                st._heroPanelDragMoved = true
                if heroScrollArea then
                    local totalH = st[heroTotalHKey] or 0
                    local visH = heroScrollArea.h or 1
                    local maxScroll = math.max(0, totalH - visH)
                    local scroll = (st[heroScrollKey] or 0) - ddy
                    st[heroScrollKey] = math.max(0, math.min(maxScroll, scroll))
                end
            end
            st._heroPanelDragLastY = dmy
            return  -- 面板拖拽时不处理地图拖拽
        end
        if not st.mapDragging and not st._heroPanelDragging then
            if inPanelArea then
                -- 触摸在右侧面板任意位置 → 启动面板拖拽 (阻止地图拖拽 + 允许滚动)
                st._heroPanelDragging = true
                st._heroPanelDragMoved = false
                st._heroPanelDragLastY = dmy
                return
            end
        end
    else
        if st._heroPanelDragging then
            -- 释放拖拽: 如果没有实际移动, 则视为点击
            if not st._heroPanelDragMoved and st._pendingHeroClick then
                st.heroPopup = st._pendingHeroClick
                if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
            end
            st._pendingHeroClick = nil
            st._heroPanelDragging = false
        elseif st._pendingHeroClick then
            -- 极短点击: 拖拽未启动就释放了, 直接视为点击
            st.heroPopup = st._pendingHeroClick
            if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
            st._pendingHeroClick = nil
        end
    end

    -- ======== 地图拖拽 ========
    -- 检查鼠标是否在地图视口内
    local inMapView = false
    if st._mapViewX then
        inMapView = dmx >= st._mapViewX and dmx <= st._mapViewX + (st._mapViewW or 0)
                    and dmy >= st._mapViewY and dmy <= st._mapViewY + (st._mapViewH or 0)
    end

    if mouseDown then
        if not st.mapDragging then
            -- 开始拖拽 (仅在地图视口内)
            if inMapView then
                st.mapDragging = true
                st.mapDragMoved = false
                st.mapDragLastPX = dmx
                st.mapDragLastPY = dmy
            end
        else
            -- 拖拽中: 计算增量并平移地图中心
            local ddx = dmx - st.mapDragLastPX
            local ddy = dmy - st.mapDragLastPY
            if math.abs(ddx) > 1 or math.abs(ddy) > 1 then
                st.mapDragMoved = true
                -- 设计坐标增量 → 地图坐标增量
                local rs = st._mapRenderScale or 1
                st.mapCenterX = st.mapCenterX - ddx / rs
                st.mapCenterY = st.mapCenterY - ddy / rs
                -- 清除自动居中/缩放目标
                st.mapTargetX = nil
                st.mapTargetY = nil
                st.mapTargetZoom = nil
                -- 限制边界 (确保不露出视口空白)
                ClampMapCenter(st)
            end
            st.mapDragLastPX = dmx
            st.mapDragLastPY = dmy
        end
    else
        if st.mapDragging then
            st.mapDragging = false
            -- 如果没有发生移动，当作点击处理 — 检查是否点中城池
            if not st.mapDragMoved and inMapView then
                M.HandleMapClick(st.mapDragLastPX, st.mapDragLastPY)
            end
        end
    end
end

--- 地图区域点击: 检测点中的城池
function M.HandleMapClick(dx, dy)
    local st = worldMapState
    if not st._mapViewX or not st._mapRenderScale then return end

    -- 地图点击时自动关闭武将弹窗
    if st.heroPopup then
        st.heroPopup = nil; st._heroPopupRect = nil
    end

    -- 设计坐标 → 地图坐标
    local vpCx = st._mapViewX + (st._mapViewW or 0) / 2
    local vpCy = st._mapViewY + (st._mapViewH or 0) / 2
    local rs = st._mapRenderScale or 1
    local mapX = (dx - vpCx) / rs + st.mapCenterX
    local mapY = (dy - vpCy) / rs + st.mapCenterY

    -- 检查是否命中城池
    if st._mapCityRects then
        for cid, rect in pairs(st._mapCityRects) do
            if mapX >= rect.x and mapX <= rect.x + rect.w
               and mapY >= rect.y and mapY <= rect.y + rect.h then
                -- 命中城池
                if st.selectedCity == cid then
                    st.selectedCity = nil
                    -- 取消选中: 缩小回全览
                    st.mapTargetZoom = 1.0
                else
                    st.selectedCity = cid
                    st.scoutResult = nil
                    st.mapPanelHeroScroll = 0
                    -- 自动展开右侧面板
                    st.rightPanelCollapsed = false
                    -- 自动居中+放大到该城池
                    M.CenterOnCity(cid)
                end
                if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
                return
            end
        end
    end
end

--- 设置自动居中+放大到某城池 (供外部调用)
function M.CenterOnCity(cityId)
    local st = worldMapState
    local city = WORLD_CITIES[cityId]
    if city then
        st.mapTargetX = city.x
        st.mapTargetY = city.y
        -- 放大到 1.8 倍以聚焦城池 (如果当前缩放已更大则保持)
        local targetZ = 1.8
        if st.mapZoom < targetZ then
            st.mapTargetZoom = targetZ
        end
    end
end

-- ============================================================================
-- ============================================================================
-- 子模块加载: 行军/战斗动画 + 新手引导
-- ============================================================================
local Anim  = require("systems.slg.slg_anim")
local Guide = require("systems.slg.slg_guide")

-- 转发动画函数
M.StartMarchAnim       = Anim.StartMarchAnim
M.IsMarchActive        = Anim.IsMarchActive
M.UpdateMarch          = Anim.UpdateMarch
M.DrawMarch            = Anim.DrawMarch
M.AdvanceBattleAnimPhase = Anim.AdvanceBattleAnimPhase
M.UpdateBattleAnim     = Anim.UpdateBattleAnim

-- 转发引导函数
M.StartGuide           = Guide.StartGuide
M.IsGuideActive        = Guide.IsGuideActive
M.CheckGuideProgress   = Guide.CheckGuideProgress
M.UpdateGuide          = Guide.UpdateGuide
M.DrawGuide            = Guide.DrawGuide
M.HandleGuideInput     = Guide.HandleGuideInput

-- ============================================================================
-- 辅助: 命中检测 (赋值给顶部前向声明的 local HitRect)
-- ============================================================================
HitRect = function(r, dx, dy)
    return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
end

-- ============================================================================
-- 输入处理 (适配新 卡片列表 + 右侧面板 布局)
-- ============================================================================
function M.HandleInput(dx, dy)
    local st = worldMapState
    local t = gameState.gameTime or 0  -- 当前游戏时间, 供 StartFlash/AddFloatNumber 使用
    local rpX = DESIGN_W - Render.LAYOUT.RIGHT_W  -- 右侧面板X起点
    local L = Render.LAYOUT

    -- === 强引导: 屏蔽无关操作 ===
    if wmGuide and wmGuide.active then
        local stepData = WM_GUIDE_STEPS[wmGuide.step]
        if stepData then
            -- 跳过按钮始终可用
            if wmGuide.skipRect and HitRect(wmGuide.skipRect, dx, dy) then
                wmGuide.active = false; wmGuide.step = 0
                gameSettings.guideCompleted = true; SaveSettings()
                if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
                print("=== 世界地图引导: 跳过 ==="); return
            end
            -- 完成按钮始终可用
            if wmGuide.btnRect and HitRect(wmGuide.btnRect, dx, dy) then
                wmGuide.active = false; wmGuide.step = 0
                gameSettings.guideCompleted = true; SaveSettings()
                if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
                print("=== 世界地图引导: 完成 ==="); return
            end
            -- 人才弹窗打开时: 关闭按钮和弹窗外点击始终可关闭 (避免误触弹窗后卡住)
            if st.heroPopup then
                local popRect = st._heroPopupRect
                local inPopup = popRect and HitRect(popRect, dx, dy)
                if not inPopup then
                    st.heroPopup = nil; st._heroPopupRect = nil
                    if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
                    return
                end
                if st.btn_heroPopupClose and HitRect(st.btn_heroPopupClose, dx, dy) then
                    st.heroPopup = nil; st._heroPopupRect = nil
                    if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
                    return
                end
            end
            local wf = stepData.waitFor
            -- 自动步骤: 屏蔽所有点击
            if wf == "auto_timer" or wf == "scroll_to_enemy" then return end
            -- 按步骤过滤允许的点击区域
            local allowed = false
            if wf == "select_city" then
                -- 仅允许左侧城池列表点击
                if dx < L.LEFT_W and dy > L.TOP_BAR_H then allowed = true end
            elseif wf == "select_enemy_city" then
                -- 仅允许左侧点击敌方城池卡片
                if dx < L.LEFT_W and dy > L.TOP_BAR_H and st._cityCardRects then
                    for cid, rect in pairs(st._cityCardRects) do
                        if HitRect(rect, dx, dy) then
                            local cd = st.cityData[cid]
                            if cd and cd.owner ~= "player" then allowed = true end
                            break
                        end
                    end
                end
            elseif wf == "open_hero_popup" then
                -- 仅允许右侧面板武将区域
                if dx >= rpX then allowed = true end
            elseif wf == "enter_hero_manage" then
                -- 仅允许弹窗内部点击
                if st.heroPopup and st._heroPopupRect and HitRect(st._heroPopupRect, dx, dy) then
                    allowed = true
                end
            elseif wf == "back_to_map" then
                -- 允许右侧面板 (返回按钮在右面板底部)
                if dx >= rpX then allowed = true end
            elseif wf == "enter_affairs" then
                -- 允许右面板 + 左面板 (可能需要先选城池)
                if dx >= rpX or (dx < L.LEFT_W and dy > L.TOP_BAR_H) then allowed = true end
            elseif wf == "click_recruit" then
                if st.btn_recruit and HitRect(st.btn_recruit, dx, dy) then allowed = true end
            elseif wf == "click_reinforce" then
                if st.btn_reinforce and HitRect(st.btn_reinforce, dx, dy) then allowed = true end
            elseif wf == "click_upgrade" then
                if st.btn_upgrade and HitRect(st.btn_upgrade, dx, dy) then allowed = true end
            elseif wf == "click_search" then
                if st.btn_search and HitRect(st.btn_search, dx, dy) then allowed = true end
            elseif wf == "confirm_talent" then
                if st.btn_talentOk and HitRect(st.btn_talentOk, dx, dy) then allowed = true end
            elseif wf == "click_morale" then
                if st.btn_morale and HitRect(st.btn_morale, dx, dy) then allowed = true end
            elseif wf == "enter_diplomacy" or wf == "enter_stratagem" or wf == "enter_attack" then
                -- 仅允许右侧面板按钮
                if dx >= rpX then allowed = true end
            elseif wf == "end_turn" then
                -- 仅允许结束回合按钮
                if st.btn_endTurn and HitRect(st.btn_endTurn, dx, dy) then allowed = true end
            end
            if not allowed then
                if not wmGuide._blockToastCD or wmGuide._blockToastCD <= 0 then
                    if rawget(_G, "ShowToast") then ShowToast("请按引导操作", 1.2) end
                    wmGuide._blockToastCD = 2.0
                end
                return
            end
        end
    end

    -- 武将弹窗: 弹窗内点击处理按钮，弹窗外点击自动关闭并继续处理
    if st.heroPopup then
        local popRect = st._heroPopupRect
        local inPopup = popRect and HitRect(popRect, dx, dy)
        if inPopup then
            -- 点击在弹窗内部：处理按钮
            if st.btn_heroPopupClose and HitRect(st.btn_heroPopupClose, dx, dy) then
                st.heroPopup = nil; st._heroPopupRect = nil
                PlaySFX(AUDIO.sfx_click); return
            end
            if st.btn_heroPopupManage and HitRect(st.btn_heroPopupManage, dx, dy) then
                local hIdx = st.heroPopup
                for cid, cd in pairs(st.cityData) do
                    if cd.owner == "player" then
                        for _, h in ipairs(cd.heroes) do
                            if h == hIdx then
                                st.heroManageCity = cid; st.heroManageScroll = 0
                                st.phase = "HERO_MANAGE"
                                st.heroPopup = nil; st._heroPopupRect = nil
                                PlaySFX(AUDIO.sfx_click); return
                            end
                        end
                    end
                end
            end
            if st.btn_heroPopupApprentice and HitRect(st.btn_heroPopupApprentice, dx, dy) then
                local hIdx = st.heroPopup
                for cid, cd in pairs(st.cityData) do
                    if cd.owner == "player" then
                        for _, h in ipairs(cd.heroes) do
                            if h == hIdx then
                                st.heroManageCity = cid
                                st.apprenticeStudent = hIdx
                                st.phase = "APPRENTICE"
                                st.heroPopup = nil; st._heroPopupRect = nil
                                PlaySFX(AUDIO.sfx_click); return
                            end
                        end
                    end
                end
            end
            if st.btn_heroPopupTroop and HitRect(st.btn_heroPopupTroop, dx, dy) then
                local hIdx = st.heroPopup
                local card = HERO_CARDS[hIdx]
                if card then
                    local opts = card.troopOptions or { card.troopType }
                    if #opts > 1 then
                        local cur = st.heroTroopChoice[hIdx] or card.troopType
                        local nextIdx = 1
                        for i, o in ipairs(opts) do
                            if o == cur then nextIdx = (i % #opts) + 1; break end
                        end
                        WorldMap.SetHeroTroop(hIdx, opts[nextIdx])
                        if rawget(_G, "ShowToast") then
                            local tt = TROOP_TYPES[opts[nextIdx]]
                            ShowToast("兵种切换: " .. (tt and tt.name or opts[nextIdx]))
                        end
                        PlaySFX(AUDIO.sfx_click)
                    end
                end
                return
            end
            return  -- 弹窗内其他区域点击 → 不穿透
        else
            -- 点击在弹窗外部：自动关闭弹窗，继续处理后续逻辑（城池切换等）
            st.heroPopup = nil; st._heroPopupRect = nil
            PlaySFX(AUDIO.sfx_click)
            -- 不 return，让后续城池卡片/地图点击逻辑继续执行
        end
    end

    -- ========== 剧本选择阶段 (全屏弹窗，拦截所有输入) ==========
    if st.phase == "CAMPAIGN_SELECT" then
        -- 经典模式按钮
        if st._classicModeBtn and HitRect(st._classicModeBtn, dx, dy) then
            local Logic = require("systems.slg.slg_logic")
            Logic.StartClassicMode()
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 剧本卡片点击
        if st._campaignBtns then
            for _, btn in ipairs(st._campaignBtns) do
                if HitRect(btn, dx, dy) then
                    local Logic = require("systems.slg.slg_logic")
                    Logic.SelectCampaign(btn.campaignId)
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
        end
        return  -- 全屏拦截
    end

    -- ========== 阵营选择阶段 (全屏弹窗) ==========
    if st.phase == "FACTION_SELECT" then
        -- 返回按钮
        if st._factionBackBtn and HitRect(st._factionBackBtn, dx, dy) then
            local Logic = require("systems.slg.slg_logic")
            Logic.EnterCampaignSelect()
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 阵营卡片点击
        if st._factionBtns then
            for _, btn in ipairs(st._factionBtns) do
                if HitRect(btn, dx, dy) then
                    local Logic = require("systems.slg.slg_logic")
                    Logic.StartCampaign(st.selectedCampaignId, btn.factionId)
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
        end
        return  -- 全屏拦截
    end

    -- ========== 回合报告阶段 (全屏弹窗，拦截所有输入) ==========
    if st.phase == "TURN_REPORT" then
        if st.btn_newgame and HitRect(st.btn_newgame, dx, dy) then
            local Logic = require("systems.slg.slg_logic")
            Logic.NewGame()
            PlaySFX(AUDIO.sfx_click)
        elseif st.btn_continue and HitRect(st.btn_continue, dx, dy) then
            st.phase = "MAP"; st.turnReport = nil; st.reportScroll = 0
            st._reportOpenTime = nil  -- 清理报告动画计时
            PlaySFX(AUDIO.sfx_click)
        end
        return  -- 全屏拦截
    end

    -- ========== 战斗动画阶段 (点击跳过) ==========
    if st.phase == "BATTLE_ANIM" then
        -- AI战斗: 点击跳过所有剩余AI战斗, 直到遇到玩家战斗或结束
        if st.battleAnimData and st.battleAnimData.isAIBattle then
            while st.phase == "BATTLE_ANIM" do
                local cur = st.battleAnimData
                if not cur or not cur.isAIBattle then break end
                -- 快进到下一个事件
                local idx = st.battleAnimIdx + 1
                if st.battleAnims and idx <= #st.battleAnims then
                    st.battleAnimIdx = idx
                    st.battleAnimData = st.battleAnims[idx]
                    st.battleAnimPhase = "march"
                    st.battleAnimT = 0
                else
                    -- 全部播完
                    local isPlayer = st.battleAnimIsPlayer
                    st.battleAnims = nil
                    st.battleAnimIdx = 0
                    st.battleAnimPhase = nil
                    st.battleAnimT = 0
                    st.battleAnimData = nil
                    st.battleAnimIsPlayer = nil
                    if isPlayer then
                        if st.capturedHeroes and #st.capturedHeroes > 0 then
                            st.phase = "SURRENDER"
                        else
                            st.phase = "MAP"
                        end
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
                    break
                end
            end
        else
            M.AdvanceBattleAnimPhase()
        end
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 面板收缩 Tab 按钮 (最高优先级，任何阶段均可用)
    if st.btn_toggleLeft and HitRect(st.btn_toggleLeft, dx, dy) then
        st.leftPanelCollapsed = not (st.leftPanelCollapsed or false)
        PlaySFX(AUDIO.sfx_click); return
    end
    if st.btn_toggleRight and HitRect(st.btn_toggleRight, dx, dy) then
        st.rightPanelCollapsed = not (st.rightPanelCollapsed or false)
        if st.rightPanelCollapsed then
            st.heroPopup = nil; st._heroPopupRect = nil
            st._mapPanelHeroRects = nil
        end
        PlaySFX(AUDIO.sfx_click); return
    end

    -- 面板收缩状态: 收缩时禁用面板内部所有点击区域
    local leftCollapsed  = st.leftPanelCollapsed  or false
    local rightCollapsed = st.rightPanelCollapsed or false

    -- 规则按钮 (顶部栏，所有阶段可用)
    if st.btn_rules and HitRect(st.btn_rules, dx, dy) then
        if st.phase == "RULES" then
            st.phase = "MAP"
        else
            st._rulesReturnPhase = st.phase
            st.phase = "RULES"
            st.rulesScroll = 0
        end
        PlaySFX(AUDIO.sfx_click); return
    end

    -- 规则面板内部点击
    if st.phase == "RULES" then
        if st.btn_rules_close and HitRect(st.btn_rules_close, dx, dy) then
            st.phase = st._rulesReturnPhase or "MAP"
            st._rulesReturnPhase = nil
            PlaySFX(AUDIO.sfx_click); return
        end
        return  -- 规则面板时拦截其他点击
    end

    -- 存档/读档按钮 (顶部栏，所有阶段可用，但仅在 MAP 阶段处理)
    if st.phase == "MAP" then
        if st.btn_save and HitRect(st.btn_save, dx, dy) then
            local ok, msg = WorldMap.SaveSLG()
            if rawget(_G, "ShowToast") then ShowToast(msg) end
            PlaySFX(AUDIO.sfx_click); return
        end
        if st.btn_load and HitRect(st.btn_load, dx, dy) then
            local ok, msg = WorldMap.LoadSLG()
            if rawget(_G, "ShowToast") then ShowToast(msg) end
            PlaySFX(AUDIO.sfx_click); return
        end
    end

    -- 战败通报阶段 (全军覆没后展示武将命运)
    if st.phase == "DEFEAT_REPORT" then
        if st.btn_defeatReportDone and HitRect(st.btn_defeatReportDone, dx, dy) then
            st.defeatHeroReport = nil
            st._defeatRptOpenTime = nil
            st.phase = "MAP"
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- 招降阶段
    if st.phase == "SURRENDER" and not rightCollapsed then
        local heroes = st.capturedHeroes or {}
        local results = st.surrenderResults or {}
        local idx = st.surrenderCurrentIdx or 1
        local hIdx = heroes[idx]

        -- 对话已显示时: 只响应 "确认" / "下一位" / "完成" 按钮
        if st.surrenderDialogue then
            if st.btn_surrender_next and HitRect(st.btn_surrender_next, dx, dy) then
                st.surrenderDialogue = nil
                -- 拒绝招降: 停留在当前武将，等待释放/处刑选择
                if results[hIdx] ~= "refused" then
                    st.surrenderCurrentIdx = (st.surrenderCurrentIdx or 1) + 1
                    if st.surrenderCurrentIdx > #heroes then
                        -- 留在面板，显示 "所有武将已处理完毕" + 继续按钮
                    end
                end
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end

        -- 操作按钮 (首次三选一; 拒绝后可释放/处刑)
        if hIdx and (results[hIdx] == nil or results[hIdx] == "refused") then
            -- 招降 (仅首次未处理时)
            if results[hIdx] == nil and st.btn_surrender_action and HitRect(st.btn_surrender_action, dx, dy) then
                local ok, msg = WorldMap.TrySurrender(hIdx, st.capturedCityId)
                local AnimF = require("ui.anim")
                if ok then
                    results[hIdx] = true
                    st.surrenderDialogue = "承蒙不弃，愿效犬马之劳！"
                    AnimF.StartFlash(220, 200, 50, 0.3, t)
                    if rawget(_G, "ShowToast") then ShowToast("招降成功!", 1.2, "success") end
                    PlaySFX(AUDIO.sfx_win)
                else
                    results[hIdx] = "refused"
                    st.surrenderDialogue = "宁死不降！休要多言！"
                    AnimF.StartFlash(180, 40, 30, 0.2, t)
                    PlaySFX(AUDIO.sfx_hit)
                end
                return
            end
            -- 释放
            if st.btn_release_action and HitRect(st.btn_release_action, dx, dy) then
                results[hIdx] = false
                st.surrenderDialogue = "多谢不杀之恩，后会有期。"
                if rawget(_G, "ShowToast") then ShowToast("已释放俘虏", 1.2, "info") end
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 处刑
            if st.btn_execute_action and HitRect(st.btn_execute_action, dx, dy) then
                results[hIdx] = "executed"
                st.surrenderDialogue = "大丈夫死则死耳，何惧之有！"
                local AnimF = require("ui.anim")
                AnimF.StartFlash(160, 10, 10, 0.35, t)
                PlaySFX(AUDIO.sfx_slash); return
            end
        end

        -- 完成按钮 (所有处理完毕后)
        if st.btn_surrenderDone and HitRect(st.btn_surrenderDone, dx, dy) then
            WorldMap.FinishSurrender()
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- 武将管理 (右侧面板内点击拦截, 左侧穿透到城池卡片)
    if st.phase == "HERO_MANAGE" and not rightCollapsed then
        if dx >= rpX then
            local cityId = st.heroManageCity
            local cd = cityId and st.cityData[cityId]
            if cd then
                -- 兵种切换按钮
                for i, hIdx in ipairs(cd.heroes) do
                    local card = HERO_CARDS[hIdx]
                    if card then
                        local opts = card.troopOptions or { card.troopType }
                        for j, ttype in ipairs(opts) do
                            local key = "btn_troop_" .. hIdx .. "_" .. j
                            if st[key] and HitRect(st[key], dx, dy) then
                                local ok, msg = WorldMap.SetHeroTroop(hIdx, ttype)
                                if ok and rawget(_G, "ShowToast") then ShowToast("兵种切换: " .. msg) end
                                PlaySFX(AUDIO.sfx_click); return
                            end
                        end
                    end
                    -- 拜师按钮
                    if st["btn_apprentice_" .. i] and HitRect(st["btn_apprentice_" .. i], dx, dy) then
                        local realIdx = st["_heroManage_idx_" .. i]
                        if realIdx then
                            st.apprenticeStudent = realIdx
                            st.phase = "APPRENTICE"
                            PlaySFX(AUDIO.sfx_click)
                        end
                        return
                    end
                end
            end
            if st.btn_heroManageBack and HitRect(st.btn_heroManageBack, dx, dy) then
                st.phase = "MAP"; st.heroManageCity = nil; st.heroManageScroll = 0
                PlaySFX(AUDIO.sfx_click)
            end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
        -- dx < rpX: 点击在左侧, 穿透到下方城池卡片逻辑
    end

    -- 拜师阶段 (右侧面板内点击拦截, 左侧穿透到城池卡片)
    if st.phase == "APPRENTICE" and not rightCollapsed then
        if dx >= rpX then
            local teacherCount = st._apprenticeTeacherCount or 0
            for i = 1, teacherCount do
                if st["btn_learn_" .. i] and HitRect(st["btn_learn_" .. i], dx, dy) then
                    -- 引导期间禁止学习技能，避免金币不足导致后续引导步骤卡住
                    if wmGuide and wmGuide.active then
                        if rawget(_G, "ShowToast") then ShowToast("引导中暂不可学习技能") end
                        PlaySFX(AUDIO.sfx_click); return
                    end
                    local teacherIdx = st["_apprentice_teacher_" .. i]
                    if teacherIdx and st.apprenticeStudent then
                        local ok, msg = WorldMap.LearnSkill(st.apprenticeStudent, teacherIdx)
                        if rawget(_G, "ShowToast") then ShowToast(msg) end
                        if ok then
                            st.phase = "HERO_MANAGE"
                            st.apprenticeStudent = nil
                        end
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            if st.btn_apprenticeBack and HitRect(st.btn_apprenticeBack, dx, dy) then
                st.phase = "HERO_MANAGE"; st.apprenticeStudent = nil
                PlaySFX(AUDIO.sfx_click)
            end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
        -- dx < rpX: 点击在左侧, 穿透到下方城池卡片逻辑
    end


    -- 人才飞卡确认按钮: 精确命中检测, 不阻断左侧城池点击
    if st.phase == "AFFAIRS" and st.searchResult and st.btn_talentOk then
        if HitRect(st.btn_talentOk, dx, dy) then
            local AnimFC = require("ui.anim")
            AnimFC.StopFlyingCard()
            st.searchResult = nil; st._talentFlyStarted = nil
            if rawget(_G, "ShowToast") then ShowToast("武将已加入麾下", 1.5, "reward") end
            if wmGuide.active then wmGuide._affairsDone = "talent_confirmed" end
            PlaySFX(AUDIO.sfx_win); return
        end
    end

    if st.phase == "AFFAIRS" and not rightCollapsed then
        if dx >= rpX then
            -- 飞卡动画期间: 右面板点击拦截, 左侧穿透到城池卡片
            if st.searchResult then
                return
            end
            if st.btn_recruit and HitRect(st.btn_recruit, dx, dy) then
                local ok, actual = WorldMap.Recruit(st.affairsCity, 5000)
                if ok then
                    local dispNum = FormatTroops(actual)
                    local AnimF = require("ui.anim")
                    AnimF.AddFloatNumber("+" .. dispNum, dx, dy, 150, 240, 120, t)
                    AnimF.StartFlash(60, 180, 60, 0.2, t)
                    AnimF.StartActionCard("recruit", "征兵成功", "新募兵卒" .. dispNum .. "编入军中,\n枕戈待旦,随时听候调遣!", {60,180,60}, t)
                    PlaySFX(AUDIO.sfx_coin)
                    if wmGuide.active then wmGuide._affairsDone = "recruit" end
                else
                    PlaySFX(AUDIO.sfx_click)
                    if wmGuide.active then wmGuide._affairsDone = "recruit" end
                end
            elseif st.btn_reinforce and HitRect(st.btn_reinforce, dx, dy) then
                local ok, actual = WorldMap.Reinforce(st.affairsCity, 3000)
                if ok then
                    local dispNum = FormatTroops(actual)
                    local AnimF = require("ui.anim")
                    AnimF.AddFloatNumber("+" .. dispNum, dx, dy, 150, 240, 120, t)
                    AnimF.StartFlash(60, 180, 60, 0.2, t)
                    AnimF.StartActionCard("reinforce", "补兵成功", "援军" .. dispNum .. "已补入前线,\n兵力恢复,战力重振!", {100,180,220}, t)
                    PlaySFX(AUDIO.sfx_coin)
                    if wmGuide.active then wmGuide._affairsDone = "reinforce" end
                else
                    if rawget(_G, "ShowToast") and actual then ShowToast(actual, 1.5, "warning") end
                    PlaySFX(AUDIO.sfx_click)
                    if wmGuide.active then wmGuide._affairsDone = "reinforce" end
                end
            elseif st.btn_upgrade and HitRect(st.btn_upgrade, dx, dy) then
                local ok = WorldMap.UpgradeCity(st.affairsCity)
                if ok then
                    local cd = st.cityData[st.affairsCity]
                    local lvStr = "Lv" .. (cd and cd.level or "?")
                    local AnimF = require("ui.anim")
                    AnimF.AddFloatNumber(lvStr, dx, dy, 255, 220, 80, t)
                    AnimF.StartFlash(200, 180, 50, 0.25, t)
                    AnimF.StartActionCard("upgrade", "城防升级", "城墙加固至" .. lvStr .. ",\n固若金汤,敌军不敢轻犯!", {255,200,60}, t)
                    PlaySFX(AUDIO.sfx_win)
                    if wmGuide.active then wmGuide._affairsDone = "upgrade" end
                else
                    PlaySFX(AUDIO.sfx_click)
                    if wmGuide.active then wmGuide._affairsDone = "upgrade" end
                end
            elseif st.btn_search and HitRect(st.btn_search, dx, dy) then
                local ok = WorldMap.SearchTalent(st.affairsCity)
                if ok and st.searchResult then
                    PlaySFX(AUDIO.sfx_win)
                    local AnimF = require("ui.anim")
                    AnimF.StartFlash(220, 190, 50, 0.3, t)
                    if wmGuide.active then wmGuide._affairsDone = "search" end
                else
                    PlaySFX(AUDIO.sfx_click)
                end
            elseif st.btn_morale and HitRect(st.btn_morale, dx, dy) then
                local ok = WorldMap.BoostMorale(st.affairsCity)
                if ok then
                    local AnimF = require("ui.anim")
                    AnimF.AddFloatNumber("+15", dx, dy, 255, 200, 100, t)
                    AnimF.StartActionCard("morale", "犒赏三军", "主公犒赏三军将士,\n士气大振,军心如铁!", {255,180,60}, t)
                    PlaySFX(AUDIO.sfx_coin)
                    if wmGuide.active then wmGuide._affairsDone = "morale" end
                else
                    PlaySFX(AUDIO.sfx_click)
                    if wmGuide.active then wmGuide._affairsDone = "morale" end
                end
            elseif st.btn_affairsBack and HitRect(st.btn_affairsBack, dx, dy) then st.phase = "MAP"; st.searchResult = nil; st._talentFoundTime = nil; PlaySFX(AUDIO.sfx_click)
            end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
        -- dx < rpX: 点击在左侧, 穿透到下方城池卡片逻辑
    end

    -- 外交
    if st.phase == "DIPLOMACY" and not rightCollapsed then
        if dx >= rpX then
            for _, fac in ipairs({"wei", "shu", "qun"}) do
                if st["btn_gift_" .. fac] and HitRect(st["btn_gift_" .. fac], dx, dy) then
                    WorldMap.SendGift(fac); PlaySFX(AUDIO.sfx_click); return
                end
                if st["btn_treaty_" .. fac] and HitRect(st["btn_treaty_" .. fac], dx, dy) then
                    WorldMap.SignTreaty(fac); PlaySFX(AUDIO.sfx_click); return
                end
            end
            if st.btn_diploBack and HitRect(st.btn_diploBack, dx, dy) then st.phase = "MAP"; PlaySFX(AUDIO.sfx_click) end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
        -- dx < rpX: 点击在左侧, 穿透到下方城池卡片逻辑
    end

    -- 计略: 点击左侧城池卡片选敌城作目标 + 右侧计略按钮
    if st.phase == "STRATAGEM" then
        -- 右侧计略按钮
        if not rightCollapsed then
            for _, strat in ipairs(STRATAGEMS) do
                if st["btn_strat_" .. strat.id] and HitRect(st["btn_strat_" .. strat.id], dx, dy) then
                    if st.stratagemTarget then
                        WorldMap.ExecuteStratagem(strat.id, st.stratagemTarget)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            if st.btn_stratBack and HitRect(st.btn_stratBack, dx, dy) then
                st.phase = "MAP"; st.stratagemTarget = nil; PlaySFX(AUDIO.sfx_click); return
            end
            if TryEndTurnBtn(st, dx, dy) then return end
        end
        -- 点击左侧城池卡片选敌城作为计略目标
        if not leftCollapsed and st._cityCardRects then
            for _, city in ipairs(WORLD_CITIES) do
                local rect = st._cityCardRects[city.id]
                if rect and HitRect(rect, dx, dy) then
                    local cd = st.cityData[city.id]
                    if cd.owner ~= "player" then
                        st.stratagemTarget = city.id
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
        end
        return
    end

    -- 调兵: 点击左侧城池卡片选相邻我方城池
    if st.phase == "MOVE_SELECT" then
        if not rightCollapsed and st.btn_moveBack and HitRect(st.btn_moveBack, dx, dy) then
            st.phase = "MAP"; PlaySFX(AUDIO.sfx_click); return
        end
        if not rightCollapsed and TryEndTurnBtn(st, dx, dy) then return end
        -- 点击左侧城池卡片选目标
        if not leftCollapsed and st._cityCardRects then
            for _, city in ipairs(WORLD_CITIES) do
                local rect = st._cityCardRects[city.id]
                if rect and HitRect(rect, dx, dy) then
                    local cd = st.cityData[city.id]
                    if cd.owner == "player" and city.id ~= st.selectedCity then
                        if WorldMap.IsConnected(st.selectedCity, city.id) then
                            local fromData = st.cityData[st.selectedCity]
                            local moveTroops = math.floor(fromData.garrison * 0.5)
                            if moveTroops > 0 then
                                local fId, tId = st.selectedCity, city.id
                                local tName = city.name
                                local heroList = {}
                                for _, h in ipairs(fromData.heroes) do table.insert(heroList, h) end
                                M.StartMarchAnim(fId, tId, moveTroops, function()
                                    WorldMap.MoveArmy(fId, tId, moveTroops, heroList)
                                    if rawget(_G, "ShowToast") then ShowToast("调兵" .. moveTroops .. "至" .. tName) end
                                end)
                            end
                            st.phase = "MAP"; PlaySFX(AUDIO.sfx_click)
                        else
                            if rawget(_G, "ShowToast") then ShowToast("城池不相邻") end
                        end
                    end
                    return
                end
            end
        end
        return
    end

    -- 攻击目标选择: 使用右侧面板的 _atkTargetRects
    if st.phase == "ATK_TARGET" and not rightCollapsed then
        if dx >= rpX then  -- 只拦截右侧面板内点击, 左侧穿透到城池卡片
            if st.btn_atkTargetBack and HitRect(st.btn_atkTargetBack, dx, dy) then
                st.phase = "MAP"; PlaySFX(AUDIO.sfx_click); return
            end
            -- 点击右侧面板中的敌城卡片
            if st._atkTargetRects then
                for eid, rect in pairs(st._atkTargetRects) do
                    if HitRect(rect, dx, dy) then
                        local cd = st.cityData[eid]
                        if cd and cd.owner ~= "player" and WorldMap.IsConnected(st.selectedCity, eid) then
                            st.targetCity = eid
                            st.deployHeroes = {}
                            st.deployTroops = 0
                            st.phase = "CONFIRM_ATTACK"
                            PlaySFX(AUDIO.sfx_click)
                        end
                        return
                    end
                end
            end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
    end

    -- 出征出发城池选择 (多个临近我方城池时)
    if st.phase == "ATK_SOURCE_SELECT" and not rightCollapsed then
        if dx >= rpX then  -- 只拦截右侧面板内点击
            if st.btn_atkSourceBack and HitRect(st.btn_atkSourceBack, dx, dy) then
                st.phase = "MAP"; st.attackSources = nil; st.targetCity = nil
                PlaySFX(AUDIO.sfx_click); return
            end
            if st._atkSourceRects then
                for srcId, rect in pairs(st._atkSourceRects) do
                    if HitRect(rect, dx, dy) then
                        st.attackFromCity = srcId
                        st.deployHeroes = {}; st.deployTroops = 0
                        st.phase = "CONFIRM_ATTACK"
                        PlaySFX(AUDIO.sfx_click); return
                    end
                end
            end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
    end

    -- 调兵遣将: 选择来源城池 → 进入武将选择面板
    if st.phase == "TRANSFER_SELECT" and not rightCollapsed then
        if dx >= rpX then  -- 只拦截右侧面板内点击
            if st.btn_transferBack and HitRect(st.btn_transferBack, dx, dy) then
                st.phase = "MAP"; PlaySFX(AUDIO.sfx_click); return
            end
            if st._transferSourceRects then
                for srcId, rect in pairs(st._transferSourceRects) do
                    if HitRect(rect, dx, dy) then
                        -- 进入武将选择面板
                        st.transferFromCity = srcId
                        st._transferHeroSelected = nil  -- 重置选择状态 (面板会默认全选)
                        st._transferHeroScroll = 0
                        st.phase = "TRANSFER_HERO_SELECT"
                        PlaySFX(AUDIO.sfx_click); return
                    end
                end
            end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
    end

    -- 调兵武将选择: 勾选武将 + 确认调兵
    if st.phase == "TRANSFER_HERO_SELECT" and not rightCollapsed then
        if dx >= rpX then
            -- 返回按钮
            if st.btn_transferHeroBack and HitRect(st.btn_transferHeroBack, dx, dy) then
                st._transferHeroSelected = nil
                st.transferFromCity = nil
                st.phase = "TRANSFER_SELECT"
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 确认调兵按钮
            if st.btn_transferConfirm and HitRect(st.btn_transferConfirm, dx, dy) then
                local srcId = st.transferFromCity
                local srcData = srcId and st.cityData[srcId]
                if srcData and st._transferHeroSelected then
                    local heroes = {}
                    for _, hIdx in ipairs(srcData.heroes) do
                        if st._transferHeroSelected[hIdx] then
                            table.insert(heroes, hIdx)
                        end
                    end
                    if #heroes > 0 then
                        -- 按选中武将比例计算兵力
                        local ratio = #heroes / math.max(1, #srcData.heroes) * 0.5
                        local troops = math.floor(srcData.garrison * ratio)
                        local ok, msg = WorldMap.MoveArmy(srcId, st.selectedCity, troops, heroes)
                        if rawget(_G, "ShowToast") then ShowToast(msg or "调兵完成") end
                    else
                        if rawget(_G, "ShowToast") then ShowToast("请至少选择一名武将") end
                    end
                end
                st._transferHeroSelected = nil
                st.transferFromCity = nil
                st.phase = "MAP"
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 武将勾选切换
            if st._transferHeroCheckRects then
                for hIdx, rect in pairs(st._transferHeroCheckRects) do
                    if HitRect(rect, dx, dy) then
                        if st._transferHeroSelected then
                            st._transferHeroSelected[hIdx] = not st._transferHeroSelected[hIdx]
                        end
                        PlaySFX(AUDIO.sfx_click); return
                    end
                end
            end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
    end

    -- 战前部署
    if st.phase == "CONFIRM_ATTACK" and not rightCollapsed then
        if dx >= rpX then  -- 只拦截右侧面板内点击, 左侧穿透到城池卡片
            local fromId = st.attackFromCity or st.selectedCity
            local fromData = st.cityData[fromId]
            if fromData then
                for i, ratio in ipairs({0.3, 0.5, 0.7}) do
                    if st["btn_ratio" .. i] and HitRect(st["btn_ratio" .. i], dx, dy) then
                        st.deployTroops = math.floor(fromData.garrison * ratio)
                        PlaySFX(AUDIO.sfx_click); return
                    end
                end
                for i, hIdx in ipairs(fromData.heroes) do
                    if st["btn_hero_" .. i] and HitRect(st["btn_hero_" .. i], dx, dy) then
                        local found = false
                        for j, dh in ipairs(st.deployHeroes) do
                            if dh == hIdx then table.remove(st.deployHeroes, j); found = true; break end
                        end
                        if not found then table.insert(st.deployHeroes, hIdx) end
                        PlaySFX(AUDIO.sfx_click); return
                    end
                end
            end
            -- 阵型按钮
            for _, btn in ipairs(st.formationBtns or {}) do
                if HitRect(btn, dx, dy) then
                    st.selectedFormation = btn.formId
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
            -- 战术按钮（再次点击同一战术则取消）
            for _, btn in ipairs(st.tacticBtns or {}) do
                if HitRect(btn, dx, dy) then
                    if st.selectedTactic == btn.tacticId then
                        st.selectedTactic = nil
                    else
                        st.selectedTactic = btn.tacticId
                    end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
            if st.btn_confirmAtk and HitRect(st.btn_confirmAtk, dx, dy) then
                local AnimUI = require("ui.anim")
                if AnimUI.transition.active then return end
                local Logic = require("systems.slg.slg_logic")
                if not Logic.CanAct("attack") then
                    if rawget(_G, "ShowToast") then ShowToast("行动点不足!(需2点)", 1.5, "warning") end
                    PlaySFX(AUDIO.sfx_click); return
                end
                local fromId2 = st.attackFromCity or st.selectedCity
                local fromData2 = st.cityData[fromId2]
                local foodCost = math.floor(st.deployTroops * 0.5)
                if st.deployTroops >= 20 and st.food >= foodCost then
                    if #st.deployHeroes == 0 and fromData2 then
                        for _, h in ipairs(fromData2.heroes) do table.insert(st.deployHeroes, h) end
                    end
                    AnimUI.StartTransition(function()
                        WorldMap.StartAttack(fromId2, st.targetCity)
                    end, 0.25)
                    PlaySFX(AUDIO.sfx_march)
                end
                return
            end
            if st.btn_cancelAtk and HitRect(st.btn_cancelAtk, dx, dy) then
                st.phase = "MAP"; st.targetCity = nil; st.deployHeroes = {}; st.deployTroops = 0
                st.attackFromCity = nil; st.attackSources = nil
                PlaySFX(AUDIO.sfx_click)
            end
            if TryEndTurnBtn(st, dx, dy) then return end
            return
        end
    end

    -- 功能面板阶段: 点击左侧城池切换选中城池并重置右面板到初始态
    do
        local resetPhases = {
            AFFAIRS = true, DIPLOMACY = true,
            TRANSFER_SELECT = true, TRANSFER_HERO_SELECT = true,
            ATK_TARGET = true, CONFIRM_ATTACK = true,
        }
        if resetPhases[st.phase] and not leftCollapsed and st._cityCardRects then
            for _, city in ipairs(WORLD_CITIES) do
                local rect = st._cityCardRects[city.id]
                if rect and HitRect(rect, dx, dy) then
                    if city.id ~= st.selectedCity then
                        -- 清理各阶段临时状态
                        st.searchResult = nil; st._talentFoundTime = nil; st._talentFlyStarted = nil
                        st.transferFromCity = nil; st._transferHeroSelected = nil; st._transferHeroScroll = 0
                        st.stratagemTarget = nil
                        st.targetCity = nil; st.deployHeroes = {}; st.deployTroops = 0
                        st.attackFromCity = nil; st.attackSources = nil
                        st.scoutResult = nil
                        -- 切换城池, 重置到 MAP
                        st.selectedCity = city.id
                        st.phase = "MAP"
                        st.mapPanelHeroScroll = 0
                        st.rightPanelCollapsed = false
                        M.CenterOnCity(city.id)
                    end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
    end

    -- 默认 MAP 阶段
    if st.phase == "MAP" then
        -- 右侧面板按钮 (选中我方城池时, 面板展开时才响应)
        if not rightCollapsed and st.selectedCity then
            local cd = st.cityData[st.selectedCity]
            if cd and cd.owner == "player" then
                -- 我方城池: 内政/补兵/调兵遣将 (武将管理已移至武将详情弹窗)
                if st.btn_affairs and HitRect(st.btn_affairs, dx, dy) then
                    st.affairsCity = st.selectedCity; st.phase = "AFFAIRS"; st.searchResult = nil
                    PlaySFX(AUDIO.sfx_click); return
                end
                if st.btn_reinforce and HitRect(st.btn_reinforce, dx, dy) then
                    -- 补兵: 一键补满到有效上限 (领兵上限和人口上限取较小值)
                    local Logic = require("systems.slg.slg_logic")
                    local troopCapVal = Logic.CalcCityTroopCap(st.selectedCity)
                    if troopCapVal <= 0 then
                        if rawget(_G, "ShowToast") then ShowToast("无武将驻守，无法补兵", 1.5, "warning") end
                        PlaySFX(AUDIO.sfx_click)
                    else
                        local popCapVal = Logic.CalcCityPopCap(st.selectedCity)
                        local cap = math.min(troopCapVal, popCapVal)
                        local maxAdd = math.max(0, cap - (cd.garrison or 0))
                        if maxAdd <= 0 then
                            if rawget(_G, "ShowToast") then ShowToast("兵力已达上限(" .. FormatTroops(cap) .. ")", 1.5, "warning") end
                            PlaySFX(AUDIO.sfx_click)
                        else
                            local ok, msg = WorldMap.Reinforce(st.selectedCity, maxAdd)
                            if ok then
                                if rawget(_G, "ShowToast") then ShowToast(msg, 1.2, "success") end
                                local AnimF = require("ui.anim")
                                AnimF.AddFloatNumber("+" .. FormatTroops(maxAdd), dx, dy, 150, 240, 120, t)
                                AnimF.StartFlash(60, 180, 60, 0.2, t)
                                PlaySFX(AUDIO.sfx_coin)
                            else
                                if rawget(_G, "ShowToast") and msg then ShowToast(msg, 1.5, "warning") end
                                PlaySFX(AUDIO.sfx_click)
                            end
                        end
                    end
                    return
                end
                if st.btn_transfer and HitRect(st.btn_transfer, dx, dy) then
                    st.phase = "TRANSFER_SELECT"; PlaySFX(AUDIO.sfx_click); return
                end
            end
            -- 敌方城池: 外交/计略/出征
            if cd and cd.owner ~= "player" then
                if st.btn_diplomacy and HitRect(st.btn_diplomacy, dx, dy) then
                    st.phase = "DIPLOMACY"; PlaySFX(AUDIO.sfx_click); return
                end
                if st.btn_stratagem and HitRect(st.btn_stratagem, dx, dy) then
                    st.phase = "STRATAGEM"; st.stratagemTarget = st.selectedCity
                    PlaySFX(AUDIO.sfx_click); return
                end
                if st.btn_attack and HitRect(st.btn_attack, dx, dy) then
                    -- 出征: 从敌方城池视角, 查找临近的我方城池作为出发点
                    local targetCity = WORLD_CITIES[st.selectedCity]
                    local sources = {}
                    for _, connId in ipairs(targetCity.conn) do
                        local connCd = st.cityData[connId]
                        if connCd and connCd.owner == "player" and #(connCd.heroes or {}) > 0 then
                            table.insert(sources, connId)
                        end
                    end
                    if #sources == 0 then
                        if rawget(_G, "ShowToast") then ShowToast("临近无我方城池可出征(需有武将驻守)") end
                    elseif #sources == 1 then
                        st.attackFromCity = sources[1]
                        st.targetCity = st.selectedCity
                        st.deployHeroes = {}; st.deployTroops = 0
                        st.phase = "CONFIRM_ATTACK"
                    else
                        st.attackSources = sources
                        st.targetCity = st.selectedCity
                        st.phase = "ATK_SOURCE_SELECT"
                    end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end

        -- 结束回合 (右侧面板底部按钮)
        if st.btn_endTurn and HitRect(st.btn_endTurn, dx, dy) then
            local AnimUI = require("ui.anim")
            AnimUI.StartTransition(function() WorldMap.EndTurn() end, 0.2)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 放弃征途确认弹窗交互（优先拦截）
        if st.abandonConfirm then
            if st.btn_abandonOk and HitRect(st.btn_abandonOk, dx, dy) then
                st.abandonConfirm = false
                PlaySFX(AUDIO.sfx_click)
                local Logic = require("systems.slg.slg_logic")
                Logic.NewGame()
                return
            end
            if st.btn_abandonCancel and HitRect(st.btn_abandonCancel, dx, dy) then
                st.abandonConfirm = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 弹窗打开时吞掉所有点击
            return
        end
        -- 放弃征途按钮
        if st.btn_abandon and HitRect(st.btn_abandon, dx, dy) then
            st.abandonConfirm = true
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 返回大厅 (顶栏按钮) — 自动存档
        if st.btn_back and HitRect(st.btn_back, dx, dy) then
            if rawget(_G, "SaveGameProgress") then SaveGameProgress() end
            PopPhase("MENU"); PlaySFX(AUDIO.sfx_click); return
        end

        -- 点击右侧面板武将小图 → 延迟判断(允许拖拽滚动)
        if not rightCollapsed and st._mapPanelHeroRects then
            for hIdx, rect in pairs(st._mapPanelHeroRects) do
                if HitRect(rect, dx, dy) then
                    -- 先记录待定点击, 在 UpdateMapDrag 释放时若未滚动才打开弹窗
                    st._pendingHeroClick = hIdx
                    return
                end
            end
        end

        -- 点击左侧城池卡片 (选择/取消选择 + 自动定位地图)
        if not leftCollapsed and st._cityCardRects then
            for _, city in ipairs(WORLD_CITIES) do
                local rect = st._cityCardRects[city.id]
                if rect and HitRect(rect, dx, dy) then
                    if st.selectedCity == city.id then
                        st.selectedCity = nil
                        -- 取消选中: 缩小回全览
                        st.mapTargetZoom = 1.0
                    else
                        st.selectedCity = city.id
                        st.scoutResult = nil
                        st.mapPanelHeroScroll = 0
                        -- 切换城池时: 关闭飞卡动画, 重置右面板到初始态
                        if st.searchResult then
                            local AnimFC = require("ui.anim")
                            AnimFC.StopFlyingCard()
                            st.searchResult = nil; st._talentFlyStarted = nil
                        end
                        st.phase = "MAP"
                        -- 自动展开右侧详情面板
                        st.rightPanelCollapsed = false
                        -- 自动将地图定位+放大到选中城池
                        M.CenterOnCity(city.id)
                    end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
    end
end

-- ============================================================================
-- 滚动处理 (城池列表滚动 + 回合报告滚动)
-- ============================================================================
function M.HandleScroll(delta)
    local st = worldMapState

    -- 强引导: 自动滚动步骤禁止手动滚动
    if wmGuide and wmGuide.active and WM_GUIDE_STEPS then
        local stepData = WM_GUIDE_STEPS[wmGuide.step]
        if stepData and (stepData.waitFor == "auto_timer" or stepData.waitFor == "scroll_to_enemy") then
            return
        end
    end

    -- 规则面板滚动
    if st.phase == "RULES" then
        local maxScroll = st._rulesMaxScroll or 0
        if maxScroll > 0 then
            local scroll = (st.rulesScroll or 0) + delta * 30
            st.rulesScroll = math.max(0, math.min(maxScroll, scroll))
        end
        return
    end

    -- 回合报告滚动 (像素级)
    if st.phase == "TURN_REPORT" and st.turnReport then
        local maxScroll = st._reportMaxScroll or 0
        if maxScroll > 0 then
            local scroll = (st.reportScroll or 0) + delta * 30
            st.reportScroll = math.max(0, math.min(maxScroll, scroll))
        end
        return
    end

    -- 武将管理面板滚动
    if st.phase == "HERO_MANAGE" then
        local totalH = st._heroManageTotalH or 0
        local visibleH = st._heroManageVisibleH or 1
        if totalH > visibleH then
            local scroll = st.heroManageScroll or 0
            scroll = scroll + delta * 30
            scroll = math.max(0, math.min(totalH - visibleH, scroll))
            st.heroManageScroll = scroll
        end
        return
    end

    -- 检查鼠标位置决定滚动目标
    local dmx, dmy = GetDesignMousePos()

    -- 右侧面板区域滚动 (鼠标在面板区域内 → 滚动英雄列表)
    if st.phase == "MAP" then
        local panelVis = not (st.rightPanelCollapsed or false) and st.selectedCity
        if panelVis then
            local panelX = DESIGN_W - Render.LAYOUT.RIGHT_W
            if dmx >= panelX and dmx <= DESIGN_W and dmy >= Render.LAYOUT.TOP_BAR_H and dmy <= DESIGN_H then
                if st._mapPanelHeroScrollArea then
                    local sa = st._mapPanelHeroScrollArea
                    local totalH = st._mapPanelHeroTotalH or 0
                    if totalH > sa.h then
                        local scroll = st.mapPanelHeroScroll or 0
                        scroll = scroll + delta * 30
                        scroll = math.max(0, math.min(totalH - sa.h, scroll))
                        st.mapPanelHeroScroll = scroll
                    end
                end
                return  -- 面板内滚轮不传递给地图缩放
            end
        end
    end

    local inMapView = false
    if st._mapViewX then
        inMapView = dmx >= st._mapViewX and dmx <= st._mapViewX + (st._mapViewW or 0)
                    and dmy >= st._mapViewY and dmy <= st._mapViewY + (st._mapViewH or 0)
    end

    if inMapView then
        -- 地图缩放
        local zoomDelta = -delta * 0.15  -- 负号: 向上滚=放大
        local oldZoom = st.mapZoom
        st.mapZoom = math.max(Render.MAP_ZOOM_MIN, math.min(Render.MAP_ZOOM_MAX, st.mapZoom + zoomDelta))

        -- 缩放时以鼠标位置为中心 (保持鼠标指向的地图点不动)
        if st.mapZoom ~= oldZoom and st._mapRenderScale then
            local vpCx = st._mapViewX + (st._mapViewW or 0) / 2
            local vpCy = st._mapViewY + (st._mapViewH or 0) / 2
            local oldRS = st._mapRenderScale
            local fitScale = st._mapFitScale or 1
            local newRS = fitScale * st.mapZoom

            -- 鼠标在旧变换下对应的地图坐标
            local mapX = (dmx - vpCx) / oldRS + st.mapCenterX
            local mapY = (dmy - vpCy) / oldRS + st.mapCenterY
            -- 新变换下该地图坐标应保持在相同屏幕位置 → 调整中心
            st.mapCenterX = mapX - (dmx - vpCx) / newRS
            st.mapCenterY = mapY - (dmy - vpCy) / newRS

            -- 限制边界 (需要用新的renderScale来计算)
            st._mapRenderScale = newRS  -- 临时更新以便ClampMapCenter正确计算
            ClampMapCenter(st)
        end
        return
    end

    -- 城池列表滚动 (鼠标在左侧列表区域)
    local totalH = st._cityListTotalH or 0
    local visibleH = st._cityListVisibleH or 1
    if totalH > visibleH then
        local scroll = st.cityListScroll or 0
        scroll = scroll + delta * 30  -- 每格30像素
        scroll = math.max(0, math.min(totalH - visibleH, scroll))
        st.cityListScroll = scroll
    end
end

return M
