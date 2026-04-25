-- ============================================================================
-- systems/td/td_select.lua - 塔防武将选择界面
-- 用途: 进入塔防前选择8名武将出战
-- ============================================================================
---@diagnostic disable: undefined-global

local TDState = require("systems.td.td_state")
local TDData  = require("systems.td.td_data")

local M = {}

-- Cover-fit 图片绘制 (保持宽高比, 裁剪居中)
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
-- 选择界面状态 (phase == "TD_SELECT" 时有效)
-- ============================================================================
---@class TDSelectState
---@field selected table<number, boolean> cardIdx → true
---@field selectedOrder number[] 按选择顺序排列的 cardIdx
---@field scrollY number 滚动偏移
---@field isDragging boolean 滚动拖拽中
---@field dragLastY number 上次拖拽Y
---@field dragStartY number 拖拽起始Y
---@field vel number 滚动惯性速度
---@field cardRects table[] 当前帧卡牌点击区域
---@field confirmRect table 确认按钮区域
---@field backRect table 返回按钮区域
---@field clearRect table 清空选择按钮区域
tdSelectState = nil

local MAX_SELECT = 8

function M.Init()
    -- 收集已拥有的武将列表
    tdSelectState = {
        selected = {},
        selectedOrder = {},
        scrollY = 0,
        isDragging = false,
        dragLastY = 0,
        dragStartY = 0,
        vel = 0,
        cardRects = {},
        confirmRect = nil,
        backRect = nil,
        clearRect = nil,
    }
end

function M.Reset()
    tdSelectState = nil
end

-- ============================================================================
-- 获取已拥有的武将列表 (按品质排序，高品质在前)
-- ============================================================================
local function GetOwnedHeroes()
    local list = {}
    for idx = 1, #HERO_CARDS do
        local info = playerHeroes[idx]
        if info and info.owned then
            list[#list + 1] = idx
        end
    end
    -- 按品质降序、索引升序排
    table.sort(list, function(a, b)
        local qa = HERO_CARDS[a].quality or 1
        local qb = HERO_CARDS[b].quality or 1
        if qa ~= qb then return qa > qb end
        return a < b
    end)
    return list
end

-- ============================================================================
-- 渲染
-- ============================================================================
function M.Draw()
    local st = tdSelectState
    if not st then return end

    local W, H = DESIGN_W, DESIGN_H  -- 1024, 571

    -- 背景 (优先使用背景图)
    local bgImg = IMG and IMG.tdSelectBg
    if bgImg and bgImg > 0 then
        DrawImageCover(bgImg, 0, 0, W, H, 1.0)
        -- 半透明遮罩使文字可读
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(15, 12, 8, 160))
        nvgFill(vg)
    else
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(25, 22, 18, 255))
        nvgFill(vg)
    end

    -- 标题
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 230, 180, 255))
    nvgText(vg, W / 2, 28, "选择出战武将 (最多" .. MAX_SELECT .. "名)")

    -- 已选数量
    local selCount = #st.selectedOrder
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(200, 190, 160, 200))
    nvgText(vg, W / 2, 50, "已选: " .. selCount .. "/" .. MAX_SELECT)

    -- ========== 左侧: 已选武将预览条 ==========
    local previewX = 16
    local previewY = 68
    local previewSlotW = 52
    local previewSlotH = 60
    local previewGap = 4

    for i = 1, MAX_SELECT do
        local sx = previewX
        local sy = previewY + (i - 1) * (previewSlotH + previewGap)
        local cardIdx = st.selectedOrder[i]

        -- 槽位背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, sx, sy, previewSlotW, previewSlotH, 4)
        if cardIdx then
            local card = HERO_CARDS[cardIdx]
            local qc = QUALITY_COLORS[card.quality] or { 120, 120, 120 }
            nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 50))
        else
            nvgFillColor(vg, nvgRGBA(60, 55, 45, 100))
        end
        nvgFill(vg)

        -- 边框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, sx, sy, previewSlotW, previewSlotH, 4)
        nvgStrokeColor(vg, nvgRGBA(100, 90, 70, 120))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        if cardIdx then
            local card = HERO_CARDS[cardIdx]
            -- 头像 (cover-fit 防变形)
            local imgH = GetHeroSheet(card)
            if imgH and imgH >= 0 then
                nvgSave(vg)
                nvgScissor(vg, sx + 2, sy + 2, previewSlotW - 4, previewSlotH - 10)
                DrawImageCover(imgH, sx + 2, sy + 2, previewSlotW - 4, previewSlotH - 10, 0.9, 3)
                nvgRestore(vg)
            end
            -- 序号
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
            nvgText(vg, sx + 3, sy + 2, tostring(i))
        else
            -- 空位标记
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(80, 75, 65, 120))
            nvgText(vg, sx + previewSlotW / 2, sy + previewSlotH / 2, "+")
        end
    end

    -- ========== 右侧: 武将网格(可滚动) ==========
    local gridLeft = previewX + previewSlotW + 16
    local gridTop = 68
    local gridW = W - gridLeft - 16
    local gridH = H - gridTop - 60  -- 底部留按钮区
    local cardW = 80
    local cardH = 100
    local gap = 8
    local cols = math.floor((gridW + gap) / (cardW + gap))
    if cols < 1 then cols = 1 end

    local ownedList = GetOwnedHeroes()
    local rows = math.ceil(#ownedList / cols)
    local contentH = rows * (cardH + gap)
    local maxScroll = math.max(0, contentH - gridH)

    -- clamp scroll
    st.scrollY = math.max(0, math.min(maxScroll, st.scrollY))

    -- 裁剪区域
    nvgSave(vg)
    nvgScissor(vg, gridLeft, gridTop, gridW, gridH)

    st.cardRects = {}

    for i, cardIdx in ipairs(ownedList) do
        local card = HERO_CARDS[cardIdx]
        local ci = ((i - 1) % cols)
        local ri = math.floor((i - 1) / cols)
        local cx = gridLeft + ci * (cardW + gap)
        local cy = gridTop + ri * (cardH + gap) - st.scrollY

        -- 可见性剔除
        if cy + cardH >= gridTop and cy <= gridTop + gridH then
            local isSelected = st.selected[cardIdx]

            -- 卡背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx, cy, cardW, cardH, 5)
            local qc = QUALITY_COLORS[card.quality] or { 100, 100, 100 }
            if isSelected then
                nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 80))
            else
                nvgFillColor(vg, nvgRGBA(40, 36, 30, 200))
            end
            nvgFill(vg)

            -- 边框(选中高亮)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx, cy, cardW, cardH, 5)
            if isSelected then
                nvgStrokeColor(vg, nvgRGBA(255, 220, 100, 220))
                nvgStrokeWidth(vg, 2.5)
            else
                nvgStrokeColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 100))
                nvgStrokeWidth(vg, 1)
            end
            nvgStroke(vg)

            -- 立绘 (cover-fit 防变形)
            local imgH = GetHeroSheet(card)
            if imgH and imgH >= 0 then
                local imgAreaH = cardH - 22
                nvgSave(vg)
                nvgScissor(vg, cx + 3, cy + 3, cardW - 6, imgAreaH)
                DrawImageCover(imgH, cx + 3, cy + 3, cardW - 6, imgAreaH, 0.85, 3)
                nvgRestore(vg)
            end

            -- 名字
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(240, 230, 210, 255))
            nvgText(vg, cx + cardW / 2, cy + cardH - 2, card.name)

            -- 品质标签
            local qt = QUALITY_TAGS[card.quality] or ""
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 220))
            nvgText(vg, cx + 4, cy + 4, qt)

            -- 选中勾号
            if isSelected then
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
                nvgText(vg, cx + cardW - 4, cy + 2, "✓")
            end

            -- 消耗军资提示
            local cost = TDData.HERO_COST[card.quality] or 100
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 180))
            nvgText(vg, cx + cardW - 4, cy + cardH - 14, "费" .. cost)

            -- 存储点击区域
            st.cardRects[#st.cardRects + 1] = {
                x = cx, y = cy, w = cardW, h = cardH,
                cardIdx = cardIdx,
            }
        end
    end

    nvgRestore(vg)

    -- ========== 底部按钮区 ==========
    local btnY = H - 48
    local btnH = 36
    local btnGap = 12

    -- 返回按钮
    local backW = 70
    local backX = gridLeft
    nvgBeginPath(vg)
    nvgRoundedRect(vg, backX, btnY, backW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(80, 70, 60, 200))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, backX, btnY, backW, btnH, 6)
    nvgStrokeColor(vg, nvgRGBA(140, 130, 110, 150))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 210, 190, 255))
    nvgText(vg, backX + backW / 2, btnY + btnH / 2, "返回")
    st.backRect = { x = backX, y = btnY, w = backW, h = btnH }

    -- 清空按钮
    local clearW = 70
    local clearX = backX + backW + btnGap
    nvgBeginPath(vg)
    nvgRoundedRect(vg, clearX, btnY, clearW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(120, 60, 50, 180))
    nvgFill(vg)
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 200, 180, 255))
    nvgText(vg, clearX + clearW / 2, btnY + btnH / 2, "清空")
    st.clearRect = { x = clearX, y = btnY, w = clearW, h = btnH }

    -- 确认出战按钮
    local confirmW = 120
    local confirmX = W - 16 - confirmW
    local canConfirm = selCount >= 1
    nvgBeginPath(vg)
    nvgRoundedRect(vg, confirmX, btnY, confirmW, btnH, 6)
    if canConfirm then
        nvgFillColor(vg, nvgRGBA(180, 140, 50, 220))
    else
        nvgFillColor(vg, nvgRGBA(60, 55, 45, 150))
    end
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, confirmX, btnY, confirmW, btnH, 6)
    nvgStrokeColor(vg, nvgRGBA(255, 220, 100, canConfirm and 180 or 60))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 200, canConfirm and 255 or 80))
    nvgText(vg, confirmX + confirmW / 2, btnY + btnH / 2, "确认出战 (" .. selCount .. ")")
    st.confirmRect = { x = confirmX, y = btnY, w = confirmW, h = btnH }

    -- 一键选满按钮
    if selCount < MAX_SELECT then
        local autoW = 80
        local autoX = confirmX - autoW - btnGap
        nvgBeginPath(vg)
        nvgRoundedRect(vg, autoX, btnY, autoW, btnH, 6)
        nvgFillColor(vg, nvgRGBA(60, 100, 80, 200))
        nvgFill(vg)
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 240, 200, 255))
        nvgText(vg, autoX + autoW / 2, btnY + btnH / 2, "一键选满")
        st.autoRect = { x = autoX, y = btnY, w = autoW, h = btnH }
    else
        st.autoRect = nil
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================
function M.handlePress(sx, sy, touchId)
    local st = tdSelectState
    if not st then return end

    local dx, dy = ScreenToDesign(sx, sy)

    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    -- 返回
    if HitRect(st.backRect) then
        M.Reset()
        PopPhase()
        phaseChangeCooldown = 0.3
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 清空
    if HitRect(st.clearRect) then
        st.selected = {}
        st.selectedOrder = {}
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 一键选满
    if st.autoRect and HitRect(st.autoRect) then
        local ownedList = GetOwnedHeroes()
        for _, cardIdx in ipairs(ownedList) do
            if #st.selectedOrder >= MAX_SELECT then break end
            if not st.selected[cardIdx] then
                st.selected[cardIdx] = true
                st.selectedOrder[#st.selectedOrder + 1] = cardIdx
            end
        end
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 确认出战
    if HitRect(st.confirmRect) and #st.selectedOrder >= 1 then
        local roster = {}
        for i, cardIdx in ipairs(st.selectedOrder) do
            roster[i] = cardIdx
        end
        -- 初始化塔防状态
        TDState.Init(roster, 1)
        M.Reset()
        -- 切换到塔防战斗阶段
        gameState.phase = "TD_BATTLE"
        phaseChangeCooldown = 0.3
        PlaySFX(AUDIO.sfx_click)
        print("=== 塔防开始! 出战武将: " .. #roster .. " 名 ===")
        return
    end

    -- 卡牌点击 (选中/取消)
    for _, rect in ipairs(st.cardRects) do
        if dx >= rect.x and dx <= rect.x + rect.w and dy >= rect.y and dy <= rect.y + rect.h then
            local cardIdx = rect.cardIdx
            if st.selected[cardIdx] then
                -- 取消选中
                st.selected[cardIdx] = nil
                for j = #st.selectedOrder, 1, -1 do
                    if st.selectedOrder[j] == cardIdx then
                        table.remove(st.selectedOrder, j)
                        break
                    end
                end
                PlaySFX(AUDIO.sfx_click)
            else
                -- 选中(限额检查)
                if #st.selectedOrder < MAX_SELECT then
                    st.selected[cardIdx] = true
                    st.selectedOrder[#st.selectedOrder + 1] = cardIdx
                    PlaySFX(AUDIO.sfx_click)
                end
            end
            return
        end
    end

    -- 开始拖拽滚动
    local gridLeft = 16 + 52 + 16
    local gridTop = 68
    local gridH = DESIGN_H - gridTop - 60
    if dx >= gridLeft and dx <= DESIGN_W - 16 and dy >= gridTop and dy <= gridTop + gridH then
        st.isDragging = true
        st.dragLastY = dy
        st.dragStartY = dy
        st.vel = 0
    end
end

function M.handleMove(sx, sy, touchId)
    local st = tdSelectState
    if not st or not st.isDragging then return end

    local _, dy = ScreenToDesign(sx, sy)
    local delta = st.dragLastY - dy  -- 向上拖=向下滚
    st.vel = delta / (1 / 60)
    st.scrollY = st.scrollY + delta
    st.dragLastY = dy
end

function M.handleEndPress(sx, sy, touchId)
    local st = tdSelectState
    if not st then return end
    st.isDragging = false
end

-- ============================================================================
-- Update (惯性滚动)
-- ============================================================================
function M.Update(dt)
    local st = tdSelectState
    if not st then return end

    if not st.isDragging and math.abs(st.vel) > 0.5 then
        st.scrollY = st.scrollY + st.vel * dt
        st.vel = st.vel * 0.92  -- 摩擦
    end
end

return M
