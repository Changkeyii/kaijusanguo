-- ============================================================================
-- slg/slg_input.lua - 三国武灵传：SLG输入处理 + 行军动画 + 新手引导
-- 适配新UI: 左侧城池卡片列表 + 右侧操作面板 (无地图城池点击)
-- ============================================================================

---@diagnostic disable: undefined-global

local Data   = require("systems.slg.slg_data")
local Render = require("systems.slg.slg_render")

local STRATAGEMS = Data.STRATAGEMS
local GetFC      = Render.GetFC
local DrawBtn    = Render.DrawBtn

local M = {}

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

    -- 双指缩放时抑制拖拽，避免双指操作被误判为平移
    if input:GetNumTouches() >= 2 then
        st.mapDragging = false
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
        return
    end

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
-- 行军动画系统 (卡片到卡片的视觉效果)
-- ============================================================================
local marchAnim = {
    active = false,
    fromCityId = nil,
    toCityId = nil,
    progress = 0,     -- 0~1
    duration = 1.2,   -- 秒
    callback = nil,   -- 动画结束后回调
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

    -- 获取来源和目标卡片位置 (如果可用)
    local fromRect = st._cityCardRects and st._cityCardRects[marchAnim.fromCityId]
    local toRect   = st._cityCardRects and st._cityCardRects[marchAnim.toCityId]

    -- 在屏幕中央区域展示行军动画
    local midX = W / 2
    local midY = H / 2

    -- 发光脉冲
    local pulse = 0.8 + 0.2 * math.sin(p * 20)

    -- 外圈光晕
    nvgBeginPath(vg); nvgCircle(vg, midX, midY, 28 * pulse)
    local glow = nvgRadialGradient(vg, midX, midY, 8, 28,
        nvgRGBA(255, 220, 80, math.floor(160 * (1 - p))),
        nvgRGBA(255, 180, 40, 0))
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 部队主体
    nvgBeginPath(vg); nvgCircle(vg, midX, midY, 14)
    nvgFillColor(vg, nvgRGBA(230, 180, 50, math.floor(240 * (1 - p * 0.5)))); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 20, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 旗帜图标
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(80, 30, 10, 255))
    nvgText(vg, midX, midY, "⚔", nil)

    -- 兵力
    if marchAnim.troops > 0 then
        nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 240, 180, math.floor(220 * (1 - p * 0.3))))
        nvgText(vg, midX, midY + 20, "行军中 " .. tostring(marchAnim.troops) .. " 人", nil)
    end

    -- 进度条
    local barW, barH = 80, 4
    nvgBeginPath(vg); nvgRoundedRect(vg, midX - barW / 2, midY + 42, barW, barH, 2)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 120)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, midX - barW / 2, midY + 42, barW * p, barH, 2)
    nvgFillColor(vg, nvgRGBA(255, 210, 80, 200)); nvgFill(vg)
end

-- ============================================================================
-- 新手引导系统（交互式）
-- ============================================================================
local wmGuide = {
    active = false,
    step = 0,       -- 0=未开始, 1~5=引导步骤
    timer = 0,
    fingerY = 0,
    btnRect = nil,
    skipRect = nil,
    waitAction = false,  -- 是否等待玩家操作
}

-- 引导步骤：交互式，玩家按提示操作后自动推进
local WM_GUIDE_STEPS = {
    {
        title = "① 选择城池",
        desc = "点击左侧城池查看详情",
        hint = "👆 点击左侧列表中的金色城池",
        highlight = "city_list",
        waitFor = "select_city",
    },
    {
        title = "② 内政经营",
        desc = "征兵、升级、搜索人才",
        hint = "👆 点击右侧【内政】按钮试试",
        highlight = "affairs_btn",
        waitFor = "enter_affairs",
    },
    {
        title = "③ 出征攻城",
        desc = "从己方城出发攻打敌城",
        hint = "👆 返回后点击【出征】开战！",
        highlight = "attack_btn",
        waitFor = "enter_attack",
    },
    {
        title = "④ 结束回合",
        desc = "获得金粮收入，推进时间",
        hint = "👆 点击左下角【结束回合】推进",
        highlight = "end_turn_btn",
        waitFor = "end_turn",
    },
    {
        title = "⑤ 统一天下！",
        desc = "占领全部18城即可获胜\n善用内政、外交和计略！",
        hint = nil,
        highlight = "none",
        waitFor = nil,
    },
}

function M.StartGuide()
    wmGuide.active = true
    wmGuide.step = 1
    wmGuide.timer = 0
    wmGuide.waitAction = true
    print("=== 世界地图引导: 开始(交互式) ===")
end

function M.IsGuideActive()
    return wmGuide.active
end

-- 引导条件检查：玩家操作完成后自动推进到下一步
function M.CheckGuideProgress()
    if not wmGuide.active then return end
    local st = worldMapState
    local stepData = WM_GUIDE_STEPS[wmGuide.step]
    if not stepData or not stepData.waitFor then return end

    local done = false
    if stepData.waitFor == "select_city" then
        done = (st.selectedCity ~= nil and st.cityData[st.selectedCity] and st.cityData[st.selectedCity].owner == "player")
    elseif stepData.waitFor == "enter_affairs" then
        done = (st.phase == "AFFAIRS")
    elseif stepData.waitFor == "enter_attack" then
        done = (st.phase == "ATK_TARGET" or st.phase == "CONFIRM_ATTACK")
    elseif stepData.waitFor == "end_turn" then
        done = (st.phase == "TURN_REPORT")
    end

    if done then
        if wmGuide.step < #WM_GUIDE_STEPS then
            wmGuide.step = wmGuide.step + 1
            wmGuide.timer = 0
            wmGuide.waitAction = true
            if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
            print("=== 世界地图引导: 自动推进到步骤 " .. wmGuide.step .. " ===")
        else
            wmGuide.active = false
            wmGuide.step = 0
        end
    end
end

function M.UpdateGuide(dt)
    if not wmGuide.active then return end
    wmGuide.timer = wmGuide.timer + dt
    wmGuide.fingerY = math.sin(wmGuide.timer * 3) * 5
    M.CheckGuideProgress()
end

-- 绘制引导提示条（不再全屏遮罩，只画底部提示条+高亮）
function M.DrawGuide()
    if not wmGuide.active or wmGuide.step < 1 then return end
    local W, H = DESIGN_W, DESIGN_H
    local stepData = WM_GUIDE_STEPS[wmGuide.step]
    if not stepData then wmGuide.active = false; return end

    local st = worldMapState
    local L = Render.LAYOUT

    -- 高亮区域
    local hlRect = nil
    if stepData.highlight == "city_list" then
        -- 高亮左侧城池列表区域
        hlRect = { x = 0, y = L.TOP_BAR_H, w = L.LEFT_W, h = H - L.TOP_BAR_H - 42 }
    elseif stepData.highlight == "affairs_btn" and st.btn_affairs then
        hlRect = st.btn_affairs
    elseif stepData.highlight == "end_turn_btn" and st.btn_endTurn then
        hlRect = st.btn_endTurn
    elseif stepData.highlight == "attack_btn" and st.btn_attack then
        hlRect = st.btn_attack
    end

    -- 高亮闪烁边框（不遮罩其他区域）
    if hlRect then
        local pad = 6
        local rx, ry = hlRect.x - pad, hlRect.y - pad
        local rw, rh = hlRect.w + pad * 2, hlRect.h + pad * 2
        local pulse = 0.5 + 0.5 * math.sin(wmGuide.timer * 4)

        -- 外发光
        nvgBeginPath(vg); nvgRoundedRect(vg, rx - 3, ry - 3, rw + 6, rh + 6, 10)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(100 * pulse)))
        nvgStrokeWidth(vg, 4); nvgStroke(vg)
        -- 主边框
        nvgBeginPath(vg); nvgRoundedRect(vg, rx, ry, rw, rh, 8)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(220 * pulse)))
        nvgStrokeWidth(vg, 2.5); nvgStroke(vg)

        -- 手指动画
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 30)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(200 * pulse)))
        nvgText(vg, rx + rw / 2, ry - 20 + wmGuide.fingerY, "👆", nil)
    end

    -- 底部引导提示条
    local barH = 56
    local barY = H - barH
    -- 背景
    nvgBeginPath(vg); nvgRect(vg, 0, barY, W, barH)
    nvgFillColor(vg, nvgRGBA(30, 18, 8, 220)); nvgFill(vg)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, barY); nvgLineTo(vg, W, barY)
    nvgStrokeColor(vg, nvgRGBA(255, 210, 100, 150)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 步骤标题
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 230, 140, 255))
    nvgText(vg, 14, barY + barH / 2 - 12, stepData.title, nil)

    -- 描述/提示
    local hintText = stepData.hint or stepData.desc
    nvgFontSize(vg, 15)
    nvgFillColor(vg, nvgRGBA(220, 210, 180, 200))
    nvgText(vg, 14, barY + barH / 2 + 12, hintText, nil)

    -- 步骤指示器 (点点)
    local dotStartX = W - 90
    for i = 1, #WM_GUIDE_STEPS do
        local dotX = dotStartX + (i - 1) * 14
        nvgBeginPath(vg); nvgCircle(vg, dotX, barY + barH / 2 - 12, i == wmGuide.step and 5 or 3)
        nvgFillColor(vg, i <= wmGuide.step
            and nvgRGBA(255, 210, 80, 255)
            or nvgRGBA(120, 100, 70, 150))
        nvgFill(vg)
    end

    -- 最后一步：显示"开始游戏"按钮
    if not stepData.waitFor then
        local gbtnW, gbtnH = 110, 34
        local gbtnX = W - gbtnW - 14
        local gbtnY = barY + (barH - gbtnH) / 2
        wmGuide.btnRect = DrawBtn(gbtnX, gbtnY, gbtnW, gbtnH, "开始游戏！", 180, 130, 30)
    else
        wmGuide.btnRect = nil
    end

    -- 跳过按钮
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(160, 150, 130, 130))
    nvgText(vg, W - 8, barY - 4, "跳过引导", nil)
    wmGuide.skipRect = { x = W - 90, y = barY - 22, w = 90, h = 22 }
end

-- 引导点击处理 — 交互式：只拦截跳过/完成按钮，其他操作放行
function M.HandleGuideInput(dx, dy)
    if not wmGuide.active then return false end

    local function HitR(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    -- 跳过
    if wmGuide.skipRect and HitR(wmGuide.skipRect) then
        wmGuide.active = false
        wmGuide.step = 0
        if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
        print("=== 世界地图引导: 跳过 ===")
        return true
    end

    -- 最后一步的"开始游戏"按钮
    if wmGuide.btnRect and HitR(wmGuide.btnRect) then
        wmGuide.active = false
        wmGuide.step = 0
        if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
        print("=== 世界地图引导: 完成 ===")
        return true
    end

    -- 其他点击不拦截 — 让玩家正常操作！
    return false
end

-- ============================================================================
-- 辅助: 命中检测
-- ============================================================================
local function HitRect(r, dx, dy)
    return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
end

-- ============================================================================
-- 输入处理 (适配新 卡片列表 + 右侧面板 布局)
-- ============================================================================
function M.HandleInput(dx, dy)
    local st = worldMapState

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

    -- 招降阶段
    if st.phase == "SURRENDER" then
        local heroes = st.capturedHeroes or {}
        local results = st.surrenderResults or {}
        for i, hIdx in ipairs(heroes) do
            if results[hIdx] == nil then
                -- 招降按钮
                if st["btn_surrender_" .. i] and HitRect(st["btn_surrender_" .. i], dx, dy) then
                    local ok, msg = WorldMap.TrySurrender(hIdx, st.capturedCityId)
                    results[hIdx] = ok
                    if rawget(_G, "ShowToast") then ShowToast(msg) end
                    PlaySFX(AUDIO.sfx_click); return
                end
                -- 释放按钮
                if st["btn_release_" .. i] and HitRect(st["btn_release_" .. i], dx, dy) then
                    results[hIdx] = false
                    if rawget(_G, "ShowToast") then ShowToast(HERO_CARDS[hIdx] and HERO_CARDS[hIdx].name .. " 已释放" or "已释放") end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
        -- 完成按钮
        if st.btn_surrenderDone and HitRect(st.btn_surrenderDone, dx, dy) then
            local allDone = true
            for _, hIdx in ipairs(heroes) do
                if results[hIdx] == nil then allDone = false; break end
            end
            if allDone or #heroes == 0 then
                WorldMap.FinishSurrender()
                PlaySFX(AUDIO.sfx_click)
            end
        end
        return
    end

    -- 武将管理
    if st.phase == "HERO_MANAGE" then
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
        return
    end

    -- 拜师阶段
    if st.phase == "APPRENTICE" then
        local teacherCount = st._apprenticeTeacherCount or 0
        for i = 1, teacherCount do
            if st["btn_learn_" .. i] and HitRect(st["btn_learn_" .. i], dx, dy) then
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
        return
    end

    -- 回合报告
    if st.phase == "TURN_REPORT" then
        if st.btn_continue and HitRect(st.btn_continue, dx, dy) then
            st.phase = "MAP"; st.turnReport = nil
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- 内政
    if st.phase == "AFFAIRS" then
        if st.btn_recruit and HitRect(st.btn_recruit, dx, dy) then WorldMap.Recruit(st.affairsCity, 50); PlaySFX(AUDIO.sfx_click)
        elseif st.btn_reinforce and HitRect(st.btn_reinforce, dx, dy) then
            local ok, msg = WorldMap.Reinforce(st.affairsCity, 30)
            if rawget(_G, "ShowToast") then ShowToast(msg) end
            PlaySFX(AUDIO.sfx_click)
        elseif st.btn_upgrade and HitRect(st.btn_upgrade, dx, dy) then WorldMap.UpgradeCity(st.affairsCity); PlaySFX(AUDIO.sfx_click)
        elseif st.btn_search and HitRect(st.btn_search, dx, dy) then WorldMap.SearchTalent(st.affairsCity); PlaySFX(AUDIO.sfx_click)
        elseif st.btn_morale and HitRect(st.btn_morale, dx, dy) then WorldMap.BoostMorale(st.affairsCity); PlaySFX(AUDIO.sfx_click)
        elseif st.btn_affairsBack and HitRect(st.btn_affairsBack, dx, dy) then st.phase = "MAP"; st.searchResult = nil; PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- 外交
    if st.phase == "DIPLOMACY" then
        for _, fac in ipairs({"wei", "shu", "qun"}) do
            if st["btn_gift_" .. fac] and HitRect(st["btn_gift_" .. fac], dx, dy) then
                WorldMap.SendGift(fac); PlaySFX(AUDIO.sfx_click); return
            end
            if st["btn_treaty_" .. fac] and HitRect(st["btn_treaty_" .. fac], dx, dy) then
                WorldMap.SignTreaty(fac); PlaySFX(AUDIO.sfx_click); return
            end
        end
        if st.btn_diploBack and HitRect(st.btn_diploBack, dx, dy) then st.phase = "MAP"; PlaySFX(AUDIO.sfx_click) end
        return
    end

    -- 计略: 点击左侧城池卡片选敌城作目标 + 右侧计略按钮
    if st.phase == "STRATAGEM" then
        -- 右侧计略按钮
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
        -- 点击左侧城池卡片选敌城作为计略目标
        if st._cityCardRects then
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
        if st.btn_moveBack and HitRect(st.btn_moveBack, dx, dy) then
            st.phase = "MAP"; PlaySFX(AUDIO.sfx_click); return
        end
        -- 点击左侧城池卡片选目标
        if st._cityCardRects then
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
    if st.phase == "ATK_TARGET" then
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
        return
    end

    -- 战前部署
    if st.phase == "CONFIRM_ATTACK" then
        local fromData = st.cityData[st.selectedCity]
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
        if st.btn_confirmAtk and HitRect(st.btn_confirmAtk, dx, dy) then
            local foodCost = math.floor(st.deployTroops * 0.5)
            if st.deployTroops >= 20 and st.food >= foodCost then
                if #st.deployHeroes == 0 and fromData then
                    for _, h in ipairs(fromData.heroes) do table.insert(st.deployHeroes, h) end
                end
                WorldMap.StartAttack(st.selectedCity, st.targetCity)
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        if st.btn_cancelAtk and HitRect(st.btn_cancelAtk, dx, dy) then
            st.phase = "MAP"; st.targetCity = nil; st.deployHeroes = {}; st.deployTroops = 0
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- 默认 MAP 阶段
    if st.phase == "MAP" then
        -- 右侧面板按钮 (选中我方城池时)
        if st.selectedCity then
            local cd = st.cityData[st.selectedCity]
            if cd and cd.owner == "player" then
                if st.btn_affairs and HitRect(st.btn_affairs, dx, dy) then
                    st.affairsCity = st.selectedCity; st.phase = "AFFAIRS"; st.searchResult = nil
                    PlaySFX(AUDIO.sfx_click); return
                end
                if st.btn_diplomacy and HitRect(st.btn_diplomacy, dx, dy) then
                    st.phase = "DIPLOMACY"; PlaySFX(AUDIO.sfx_click); return
                end
                if st.btn_heroes and HitRect(st.btn_heroes, dx, dy) then
                    st.heroManageCity = st.selectedCity; st.heroManageScroll = 0
                    st.phase = "HERO_MANAGE"
                    PlaySFX(AUDIO.sfx_click); return
                end
                if st.btn_stratagem and HitRect(st.btn_stratagem, dx, dy) then
                    st.phase = "STRATAGEM"; st.stratagemTarget = nil
                    PlaySFX(AUDIO.sfx_click); return
                end
                if st.btn_move and HitRect(st.btn_move, dx, dy) then
                    st.phase = "MOVE_SELECT"; PlaySFX(AUDIO.sfx_click); return
                end
                if st.btn_attack and HitRect(st.btn_attack, dx, dy) then
                    local fromCity = WORLD_CITIES[st.selectedCity]
                    local enemies = {}
                    for _, connId in ipairs(fromCity.conn) do
                        if st.cityData[connId].owner ~= "player" then table.insert(enemies, connId) end
                    end
                    if #enemies > 0 then
                        if #enemies == 1 then
                            st.targetCity = enemies[1]; st.deployHeroes = {}; st.deployTroops = 0
                            st.phase = "CONFIRM_ATTACK"
                        else
                            st.phase = "ATK_TARGET"
                        end
                    else
                        if rawget(_G, "ShowToast") then ShowToast("周围无可攻击城池") end
                    end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end

        -- 结束回合 + 返回 (左侧底部按钮)
        if st.btn_endTurn and HitRect(st.btn_endTurn, dx, dy) then
            WorldMap.EndTurn(); PlaySFX(AUDIO.sfx_click); return
        end
        if st.btn_back and HitRect(st.btn_back, dx, dy) then
            PopPhase("MENU"); PlaySFX(AUDIO.sfx_click); return
        end

        -- 点击右侧面板武将小图 → 弹出武将详情
        if st._mapPanelHeroRects then
            for hIdx, rect in pairs(st._mapPanelHeroRects) do
                if HitRect(rect, dx, dy) then
                    st.heroPopup = hIdx
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end

        -- 点击左侧列表中的武将名字 → 弹出武将详情
        if st._heroNameRects then
            for hIdx, rect in pairs(st._heroNameRects) do
                if HitRect(rect, dx, dy) then
                    st.heroPopup = hIdx
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end

        -- 点击左侧城池卡片 (选择/取消选择 + 自动定位地图)
        if st._cityCardRects then
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

    -- 回合报告滚动
    if st.phase == "TURN_REPORT" and st.turnReport then
        st.reportScroll = math.max(0, math.min(#st.turnReport - 5, (st.reportScroll or 0) + delta))
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

    -- 右侧面板武将区域滚动
    if st.phase == "MAP" and st._mapPanelHeroScrollArea then
        local sa = st._mapPanelHeroScrollArea
        if dmx >= sa.x and dmx <= sa.x + sa.w and dmy >= sa.y and dmy <= sa.y + sa.h then
            local totalH = st._mapPanelHeroTotalH or 0
            if totalH > sa.h then
                local scroll = st.mapPanelHeroScroll or 0
                scroll = scroll + delta * 30
                scroll = math.max(0, math.min(totalH - sa.h, scroll))
                st.mapPanelHeroScroll = scroll
            end
            return
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
