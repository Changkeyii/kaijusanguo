-- ============================================================================
-- EquipUI: 宝物仓库系统 (纯 NanoVG 渲染，设计坐标 1024×571)
-- 独立模块，避免 main.lua 200 upvalue 限制
-- 三国古风亮色风格 + 背景图  (横屏左右分栏布局)
-- ============================================================================
---@diagnostic disable-next-line: undefined-global
local sdk = sdk ---@type any

EquipUI = {
    isVisible = false,
    _vg = nil,
    _equipSheet = nil,
    _sheetCols = 7,
    _sheetRows = 7,
    _bgImage = nil,       -- 背景图句柄
}

-- ============================================================================
-- 常量
-- ============================================================================
local W, H = 1024, 571

-- ===================== 横屏左右分栏布局常量 =====================
local TOP_BAR_H     = 44        -- 顶栏高度（压缩）
-- 左栏: 装备槽位 + 增幅 + 套装概览
local LEFT_W        = 330       -- 左栏宽度
local LEFT_PAD      = 10        -- 左栏内边距
-- 右栏: 操作栏 + 物品网格
local RIGHT_X       = LEFT_W + 4 -- 右栏起始x
local RIGHT_W       = W - RIGHT_X -- 右栏宽度(~690)

-- 装备槽位 (单行7个，在左栏内)
local SLOT_Y        = TOP_BAR_H + 6 -- 槽位起始y
local SLOT_W_C      = 42        -- 槽位宽（缩小适应单行）
local SLOT_H_C      = 42        -- 槽位高
local SLOT_GAP      = 4

-- 增幅区 (左栏内)
local STAT_Y        = SLOT_Y + SLOT_H_C + 8  -- ~100
local STAT_H        = 60        -- 增幅区高度
local STAT_PAD_X    = LEFT_PAD  -- 增幅区左右内边距
local STAT_ROW1_H   = 22        -- 标题行高度
local STAT_ROW2_H   = 32        -- 属性格子行高度

-- 套装概览 (左栏内，增幅区下方)
local SET_BAR_Y     = STAT_Y + STAT_H + 6  -- ~166
local SET_BAR_H     = H - SET_BAR_Y - 6   -- 填满左栏剩余高度(~399)

-- 操作栏 (右栏内)
local ACTION_SEP_Y  = TOP_BAR_H + 2
local ACTION_BAR_Y  = TOP_BAR_H + 6

-- 网格 (右栏内，操作栏下方)
local GRID_TOP_Y    = ACTION_BAR_Y + 34    -- ~84
local GRID_BOT_Y    = H - 6               -- ~565
local GRID_H        = GRID_BOT_Y - GRID_TOP_Y  -- ~481

-- 网格布局 (右栏内6列)
local GRID_COLS   = 6
local CELL_SIZE   = 80
local CELL_GAP    = 4
local GRID_W      = GRID_COLS * CELL_SIZE + (GRID_COLS - 1) * CELL_GAP
local GRID_X      = RIGHT_X + math.floor((RIGHT_W - GRID_W) / 2)

-- 仓库容量
local BASE_SLOTS      = 20
local UNLOCK_PER_AD   = 5

-- 长按检测
local LONG_PRESS_TIME = 0.4
local DRAG_THRESHOLD  = 12

-- ============================================================================
-- 哥特亮色配色 (Gothic Bright Palette)
-- ============================================================================
local COL_PANEL_BG    = {55, 48, 65}
local COL_PANEL_EDGE  = {145, 120, 85}
local COL_GOLD        = {235, 200, 110}
local COL_GOLD_DIM    = {190, 165, 105}
local COL_COPPER      = {180, 140, 95}
local COL_TEXT_MAIN   = {248, 242, 232}
local COL_TEXT_SUB    = {200, 190, 175}
local COL_ACCENT_BLUE = {110, 175, 245}
local COL_ACCENT_GREEN= {90, 210, 140}
local COL_ACCENT_RED  = {225, 85, 70}
local COL_LOCKED_BG   = {38, 34, 48}
local COL_CELL_BG     = {50, 44, 60}
local COL_SLOT_TOP    = {62, 55, 75}
local COL_SLOT_BOT    = {48, 42, 60}
local COL_SLOT_SEL_T  = {78, 68, 98}
local COL_SLOT_SEL_B  = {62, 55, 82}
local COL_SEPARATOR   = {160, 135, 95}

-- ============================================================================
-- 内部状态
-- ============================================================================
local state = {
    filterSlot    = 0,
    scrollY       = 0,
    scrollVel     = 0,
    isDragging    = false,
    dragStartX    = 0,
    dragStartY    = 0,
    dragLastY     = 0,
    dragMoved     = false,
    touchDown     = false,
    touchX        = 0,
    touchY        = 0,
    longPressTimer = 0,
    tooltipUid    = nil,
    decompConfirm = nil,
    enhanceConfirm = nil,
    batchDecompConfirm = nil,
    slotRects     = {},
    gridRects     = {},
    backBtnRect   = nil,
    batchBtnRect  = nil,
    selectBtnRect = nil,
    unlockBtnRect = nil,
    filterResetRect = nil,
    selectMode    = false,
    selectedUids  = {},
    selectBarConfirmRect = nil,
    selectBarCancelRect  = nil,
    selectBarAllRect     = nil,
    selectDecompConfirm  = nil,
    sdConfirmRect = nil,
    sdCancelRect  = nil,
    filterDecomp  = nil,   -- { tiers={true,true,false,...}, maxLv=5 }
    fdTierRects   = {},    -- tier checkbox rects [1..6]
    fdLvMinusRect = nil,
    fdLvPlusRect  = nil,
    fdConfirmRect = nil,
    fdCancelRect  = nil,
    tipEquipRect  = nil,
    tipDecompRect = nil,
    tipEnhanceRect= nil,
    dConfirmRect  = nil,
    dCancelRect   = nil,
    eConfirmRect  = nil,
    eCancelRect   = nil,
    bConfirmRect  = nil,
    bCancelRect   = nil,

    animTimer     = 0,
}

-- ============================================================================
-- 工具函数
-- ============================================================================
local function hitRect(r, x, y)
    if not r then return false end
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function getUnlockedSlots()
    return BASE_SLOTS + (playerEquipment.unlockedSlots or 0)
end

local function autoExpandLegacy()
    local total = #playerEquipment.owned
    local current = getUnlockedSlots()
    if total > current then
        local needed = total - BASE_SLOTS
        local newUnlocked = math.ceil(needed / UNLOCK_PER_AD) * UNLOCK_PER_AD
        if newUnlocked > (playerEquipment.unlockedSlots or 0) then
            playerEquipment.unlockedSlots = newUnlocked
            SaveGameProgress()
            print("[EquipUI] 老玩家自动扩展格子到 " .. getUnlockedSlots())
        end
    end
end

local function getFilteredItems()
    local filter = state.filterSlot
    local items = {}
    for _, item in ipairs(playerEquipment.owned) do
        local isMatch = (filter == 0) or (item.slotIdx == filter)
        items[#items + 1] = { item = item, highlighted = isMatch }
    end
    table.sort(items, function(a, b)
        if a.highlighted ~= b.highlighted then return a.highlighted end
        if a.item.tier ~= b.item.tier then return a.item.tier > b.item.tier end
        if a.item.quality ~= b.item.quality then return a.item.quality > b.item.quality end
        return a.item.uid < b.item.uid
    end)
    return items
end

local function getBatchDecompInfo()
    local count, gain = 0, 0
    for _, itm in ipairs(playerEquipment.owned) do
        if playerEquipment.equipped[itm.slotIdx] ~= itm.uid then
            count = count + 1
            gain = gain + CalcDecomposeGain(itm.tier, itm.enhanceLv)
        end
    end
    return count, gain
end

local function isItemEquipped(item)
    return playerEquipment.equipped[item.slotIdx] == item.uid
end

-- ============================================================================
-- 绘制工具
-- ============================================================================

local function drawButton(g, x, y, w, h, r, topColor, botColor, borderColor, text, textColor, fontSize)
    nvgBeginPath(g); nvgRoundedRect(g, x, y, w, h, r)
    local grad = nvgLinearGradient(g, x, y, x, y + h,
        nvgRGBA(topColor[1], topColor[2], topColor[3], topColor[4] or 240),
        nvgRGBA(botColor[1], botColor[2], botColor[3], botColor[4] or 240))
    nvgFillPaint(g, grad); nvgFill(g)
    if borderColor then
        nvgStrokeColor(g, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 130))
        nvgStrokeWidth(g, 1.2); nvgStroke(g)
    end
    if text then
        nvgFontSize(g, fontSize or 22)
        nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local tc = textColor or COL_TEXT_MAIN
        nvgFillColor(g, nvgRGBA(tc[1], tc[2], tc[3], tc[4] or 240))
        nvgText(g, x + w / 2, y + h / 2, text, nil)
    end
end

local function drawGothicSeparator(g, y, leftPad, rightPad, alpha)
    alpha = alpha or 60
    local lx = leftPad or 20
    local rx = W - (rightPad or 20)
    local mid = W / 2
    local gradL = nvgLinearGradient(g, lx, y, mid, y,
        nvgRGBA(COL_SEPARATOR[1], COL_SEPARATOR[2], COL_SEPARATOR[3], 0),
        nvgRGBA(COL_SEPARATOR[1], COL_SEPARATOR[2], COL_SEPARATOR[3], alpha))
    nvgBeginPath(g); nvgMoveTo(g, lx, y); nvgLineTo(g, mid - 6, y)
    nvgStrokePaint(g, gradL); nvgStrokeWidth(g, 1); nvgStroke(g)
    local gradR = nvgLinearGradient(g, mid, y, rx, y,
        nvgRGBA(COL_SEPARATOR[1], COL_SEPARATOR[2], COL_SEPARATOR[3], alpha),
        nvgRGBA(COL_SEPARATOR[1], COL_SEPARATOR[2], COL_SEPARATOR[3], 0))
    nvgBeginPath(g); nvgMoveTo(g, mid + 6, y); nvgLineTo(g, rx, y)
    nvgStrokePaint(g, gradR); nvgStrokeWidth(g, 1); nvgStroke(g)
    local ds = 4
    nvgBeginPath(g)
    nvgMoveTo(g, mid, y - ds); nvgLineTo(g, mid + ds, y)
    nvgLineTo(g, mid, y + ds); nvgLineTo(g, mid - ds, y)
    nvgClosePath(g)
    nvgFillColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], alpha + 20))
    nvgFill(g)
end

local function drawLockIcon(g, cx, cy, size, alpha)
    alpha = alpha or 160
    local s = size / 24
    local bw, bh = 14 * s, 10 * s
    local bx, by = cx - bw / 2, cy - bh / 2 + 2 * s
    nvgBeginPath(g); nvgRoundedRect(g, bx, by, bw, bh, 2 * s)
    nvgFillColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], alpha))
    nvgFill(g)
    nvgBeginPath(g)
    nvgArc(g, cx, by, 5.5 * s, math.rad(-180), math.rad(0), 1)
    nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], alpha))
    nvgStrokeWidth(g, 2.5 * s); nvgStroke(g)
    nvgBeginPath(g); nvgCircle(g, cx, by + bh * 0.38, 2 * s)
    nvgFillColor(g, nvgRGBA(35, 30, 40, alpha)); nvgFill(g)
    nvgBeginPath(g); nvgRect(g, cx - 1 * s, by + bh * 0.45, 2 * s, bh * 0.35)
    nvgFillColor(g, nvgRGBA(35, 30, 40, alpha)); nvgFill(g)
end

local function drawPanel(g, px, py, pw, ph, borderColor)
    nvgBeginPath(g); nvgRoundedRect(g, px - 5, py - 5, pw + 10, ph + 10, 16)
    nvgFillColor(g, nvgRGBA(15, 12, 22, 60)); nvgFill(g)
    nvgBeginPath(g); nvgRoundedRect(g, px, py, pw, ph, 12)
    local bg = nvgLinearGradient(g, px, py, px, py + ph,
        nvgRGBA(68, 60, 82, 250), nvgRGBA(48, 42, 62, 250))
    nvgFillPaint(g, bg); nvgFill(g)
    local bc = borderColor or COL_PANEL_EDGE
    nvgBeginPath(g); nvgRoundedRect(g, px, py, pw, ph, 12)
    nvgStrokeColor(g, nvgRGBA(bc[1], bc[2], bc[3], 120))
    nvgStrokeWidth(g, 1.5); nvgStroke(g)
    nvgBeginPath(g); nvgRoundedRect(g, px + 2, py + 2, pw - 4, ph - 4, 10)
    nvgStrokeColor(g, nvgRGBA(bc[1], bc[2], bc[3], 35))
    nvgStrokeWidth(g, 0.8); nvgStroke(g)
    nvgBeginPath(g)
    nvgMoveTo(g, px + 24, py + 1.5); nvgLineTo(g, px + pw - 24, py + 1.5)
    nvgStrokeColor(g, nvgRGBA(255, 240, 200, 40))
    nvgStrokeWidth(g, 1); nvgStroke(g)
    local ds = 3
    local corners = {
        {px + 12, py + 12}, {px + pw - 12, py + 12},
        {px + 12, py + ph - 12}, {px + pw - 12, py + ph - 12},
    }
    for _, c in ipairs(corners) do
        nvgBeginPath(g)
        nvgMoveTo(g, c[1], c[2] - ds); nvgLineTo(g, c[1] + ds, c[2])
        nvgLineTo(g, c[1], c[2] + ds); nvgLineTo(g, c[1] - ds, c[2])
        nvgClosePath(g)
        nvgFillColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 60))
        nvgFill(g)
    end
end

local function drawOverlay(g)
    nvgBeginPath(g); nvgRect(g, 0, 0, W, H)
    nvgFillColor(g, nvgRGBA(18, 15, 25, 150)); nvgFill(g)
end

-- ============================================================================
-- 绘制: 背景图
-- ============================================================================
local function drawBackground(g)
    -- 优先绘制背景图片
    if EquipUI._bgImage and EquipUI._bgImage > 0 then
        local imgW, imgH = nvgImageSize(g, EquipUI._bgImage)
        if imgW > 4 and imgH > 4 then
            local pat = nvgImagePattern(g, 0, 0, W, H, 0, EquipUI._bgImage, 1.0)
            nvgBeginPath(g); nvgRect(g, 0, 0, W, H)
            nvgFillPaint(g, pat); nvgFill(g)
            -- 轻微暗化叠层让上面的UI更易读
            nvgBeginPath(g); nvgRect(g, 0, 0, W, H)
            nvgFillColor(g, nvgRGBA(15, 12, 22, 80)); nvgFill(g)
            return
        end
    end
    -- 降级：纯色渐变
    nvgBeginPath(g); nvgRect(g, 0, 0, W, H)
    local bgGrad = nvgLinearGradient(g, 0, 0, 0, H,
        nvgRGBA(62, 52, 72, 220), nvgRGBA(45, 38, 55, 230))
    nvgFillPaint(g, bgGrad); nvgFill(g)
end

-- ============================================================================
-- 绘制: 顶部栏
-- ============================================================================
local function drawTopBar(g)
    -- 半透明底条（横屏全宽）
    nvgBeginPath(g); nvgRect(g, 0, 0, W, TOP_BAR_H)
    nvgFillColor(g, nvgRGBA(20, 18, 28, 120)); nvgFill(g)

    -- 返回按钮（紧凑）
    local bx, by, bw, bh = 6, 6, 80, 32
    state.backBtnRect = { x = bx, y = by, w = bw, h = bh }
    drawButton(g, bx, by, bw, bh, 7,
        {75, 65, 88}, {55, 48, 68}, COL_PANEL_EDGE,
        nil, nil)
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 20)
    nvgFillColor(g, nvgRGBA(COL_TEXT_MAIN[1], COL_TEXT_MAIN[2], COL_TEXT_MAIN[3], 225))
    nvgText(g, bx + bw / 2, by + bh / 2, "< 返回", nil)

    -- 标题（左栏居中）
    nvgFontSize(g, 32)
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(LEFT_W / 2, TOP_BAR_H / 2, "宝物仓库")
    DrawHelpBtn(LEFT_W - 10, TOP_BAR_H / 2 - 12, 24)

    -- 军资（右栏右上角）
    nvgTextAlign(g, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 20)
    nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 220))
    nvgText(g, W - 10, TOP_BAR_H / 2, "军资 " .. (playerInfo.lingshi or 0), nil)

    -- 底部分隔线
    drawGothicSeparator(g, TOP_BAR_H, 10, 10, 55)
end

-- ============================================================================
-- 绘制: 装备槽位 (4+3)
-- ============================================================================
local function drawEquipSlots(g)
    state.slotRects = {}
    local selFilter = state.filterSlot
    local t = state.animTimer

    -- 横屏: 单行7个，居中在左栏内
    local totalSlotsW = 7 * SLOT_W_C + 6 * SLOT_GAP
    local slotsStartX = LEFT_PAD + math.floor((LEFT_W - LEFT_PAD * 2 - totalSlotsW) / 2)

    for si = 1, 7 do
        local rx = slotsStartX + (si - 1) * (SLOT_W_C + SLOT_GAP)
        local ry = SLOT_Y

        state.slotRects[si] = { x = rx, y = ry, w = SLOT_W_C, h = SLOT_H_C }
        local isSel = (si == selFilter)
        local eqInfo = GetEquippedItem(si)

        -- 底板
        nvgBeginPath(g); nvgRoundedRect(g, rx, ry, SLOT_W_C, SLOT_H_C, 6)
        if isSel then
            local pulse = 0.7 + 0.3 * math.sin(t * 3.0)
            local ga = math.floor(40 * pulse)
            local grad = nvgLinearGradient(g, rx, ry, rx, ry + SLOT_H_C,
                nvgRGBA(COL_SLOT_SEL_T[1], COL_SLOT_SEL_T[2], COL_SLOT_SEL_T[3], 245),
                nvgRGBA(COL_SLOT_SEL_B[1], COL_SLOT_SEL_B[2], COL_SLOT_SEL_B[3], 245))
            nvgFillPaint(g, grad); nvgFill(g)
            nvgBeginPath(g); nvgRoundedRect(g, rx - 2, ry - 2, SLOT_W_C + 4, SLOT_H_C + 4, 8)
            nvgStrokeColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 55 + ga))
            nvgStrokeWidth(g, 2); nvgStroke(g)
        else
            local grad = nvgLinearGradient(g, rx, ry, rx, ry + SLOT_H_C,
                nvgRGBA(COL_SLOT_TOP[1], COL_SLOT_TOP[2], COL_SLOT_TOP[3], 225),
                nvgRGBA(COL_SLOT_BOT[1], COL_SLOT_BOT[2], COL_SLOT_BOT[3], 225))
            nvgFillPaint(g, grad); nvgFill(g)
        end

        -- 内边框
        nvgBeginPath(g); nvgRoundedRect(g, rx + 1, ry + 1, SLOT_W_C - 2, SLOT_H_C - 2, 5)
        if isSel then
            nvgStrokeColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 190))
            nvgStrokeWidth(g, 1.5)
        elseif eqInfo then
            local tc = EQUIP_TIERS[eqInfo.tier or 1].color
            nvgStrokeColor(g, nvgRGBA(tc[1], tc[2], tc[3], 100))
            nvgStrokeWidth(g, 1)
        else
            nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 50))
            nvgStrokeWidth(g, 0.8)
        end
        nvgStroke(g)

        -- 槽位名称（底层，居中，alpha 0.7，可被图标遮挡）
        nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(g, 13)
        nvgFillColor(g, nvgRGBA(255, 255, 255, 178))
        nvgText(g, rx + SLOT_W_C / 2, ry + SLOT_H_C / 2, EQUIP_SLOT_NAMES[si], nil)

        -- 装备图标（上层，遮挡名称）
        local iconPad = 4
        local iconSize = SLOT_W_C - iconPad * 2
        local iconY = ry + iconPad
        if eqInfo and eqInfo.setIdx and EquipUI._equipSheet and EquipUI._equipSheet > 0 then
            local imgW, imgH = nvgImageSize(g, EquipUI._equipSheet)
            if imgW > 4 and imgH > 4 then
                DrawEquipTierBg(rx + iconPad - 2, iconY - 2, iconSize + 4, iconSize + 4, eqInfo.tier or 1, 5)
                DrawCardImage(rx + iconPad, iconY, iconSize, iconSize,
                    EquipUI._equipSheet, si - 1, eqInfo.setIdx - 1,
                    EquipUI._sheetCols, EquipUI._sheetRows)
            end
        else
            nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 55))
            nvgStrokeWidth(g, 1.5)
            local ccx, ccy = rx + SLOT_W_C / 2, ry + SLOT_H_C / 2
            local arm = 8
            nvgBeginPath(g); nvgMoveTo(g, ccx - arm, ccy); nvgLineTo(g, ccx + arm, ccy); nvgStroke(g)
            nvgBeginPath(g); nvgMoveTo(g, ccx, ccy - arm); nvgLineTo(g, ccx, ccy + arm); nvgStroke(g)
        end

        -- 红点
        if HasEquipSlotRedDot(si) then
            local rdx, rdy, rdr = rx + SLOT_W_C - 4, ry + 4, 3.5
            nvgBeginPath(g); nvgCircle(g, rdx, rdy, rdr + 1.5)
            nvgFillColor(g, nvgRGBA(200, 40, 30, 60)); nvgFill(g)
            nvgBeginPath(g); nvgCircle(g, rdx, rdy, rdr)
            nvgFillColor(g, nvgRGBA(240, 55, 45, 230)); nvgFill(g)
            nvgBeginPath(g); nvgCircle(g, rdx - 1.2, rdy - 1.2, 1.5)
            nvgFillColor(g, nvgRGBA(255, 180, 180, 180)); nvgFill(g)
        end
    end
end

-- ============================================================================
-- 绘制: 全域增幅 + 套装概览
-- ============================================================================
local function drawStatSummary(g)
    local eqBonus = GetEquipmentBonus()

    local panelX = STAT_PAD_X
    local panelW = LEFT_W - STAT_PAD_X * 2
    -- 外框背景
    nvgBeginPath(g); nvgRoundedRect(g, panelX, STAT_Y, panelW, STAT_H, 6)
    nvgFillColor(g, nvgRGBA(COL_PANEL_BG[1], COL_PANEL_BG[2], COL_PANEL_BG[3], 170))
    nvgFill(g)
    nvgBeginPath(g); nvgRoundedRect(g, panelX, STAT_Y, panelW, STAT_H, 6)
    nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 55))
    nvgStrokeWidth(g, 0.8); nvgStroke(g)

    nvgFontFaceId(g, GetMainFont())

    -- === 第1行: 标题 "全域增幅" 居中(左栏内) ===
    local row1CY = STAT_Y + STAT_ROW1_H / 2 + 2
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 15)
    nvgFillColor(g, nvgRGBA(COL_GOLD_DIM[1], COL_GOLD_DIM[2], COL_GOLD_DIM[3], 200))
    nvgText(g, LEFT_W / 2, row1CY, "全域增幅", nil)

    -- === 第2行: 三个属性 grid 均分 ===
    local row2Y   = STAT_Y + STAT_ROW1_H
    local innerPad = 4        -- 格子区域左右内边距
    local cellGap  = 4        -- 格子之间间距
    local gridX    = panelX + innerPad
    local gridW    = panelW - innerPad * 2
    local cellW    = math.floor((gridW - cellGap * 2) / 3)
    local cellH    = STAT_ROW2_H - 4  -- 上下各留2px

    local stats = {
        { label = "ATK", val = eqBonus.atkPct, color = {255, 145, 125}, bgCol = {80, 40, 35} },
        { label = "DEF", val = eqBonus.defPct, color = {130, 190, 255}, bgCol = {35, 50, 80} },
        { label = "HP",  val = eqBonus.hpPct,  color = {130, 235, 170}, bgCol = {35, 70, 50} },
    }

    for i, st in ipairs(stats) do
        local cx = gridX + (i - 1) * (cellW + cellGap)
        local cy = row2Y + 2
        -- 格子背景
        nvgBeginPath(g); nvgRoundedRect(g, cx, cy, cellW, cellH, 4)
        nvgFillColor(g, nvgRGBA(st.bgCol[1], st.bgCol[2], st.bgCol[3], 130))
        nvgFill(g)
        -- 属性文字居中
        nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(g, 15)
        nvgFillColor(g, nvgRGBA(st.color[1], st.color[2], st.color[3], 240))
        local txt = string.format("%s+%.0f%%", st.label, st.val)
        nvgText(g, cx + cellW / 2, cy + cellH / 2, txt, nil)
    end

end

-- ============================================================================
-- 绘制: 操作栏
-- ============================================================================
local function drawActionBar(g)
    local totalOwned = #playerEquipment.owned
    local maxSlots = getUnlockedSlots()

    -- 右栏内的分隔线
    drawGothicSeparator(g, ACTION_SEP_Y, RIGHT_X + 8, W - RIGHT_X - RIGHT_W + 8, 45)

    -- 左侧: 容量
    nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 18)
    local full = totalOwned >= maxSlots
    if full then
        nvgFillColor(g, nvgRGBA(COL_ACCENT_RED[1], COL_ACCENT_RED[2], COL_ACCENT_RED[3], 230))
    else
        nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 200))
    end
    nvgText(g, RIGHT_X + 8, ACTION_BAR_Y + 12, totalOwned .. "/" .. maxSlots, nil)

    -- 筛选重置
    state.filterResetRect = nil
    if state.filterSlot > 0 then
        local resetX = RIGHT_X + 62
        local resetW, resetH = 64, 26
        local resetY = ACTION_BAR_Y
        drawButton(g, resetX, resetY, resetW, resetH, 5,
            {82, 72, 98}, {65, 58, 80}, {COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 80},
            nil, nil)
        nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(g, 15)
        nvgFillColor(g, nvgRGBA(COL_TEXT_MAIN[1], COL_TEXT_MAIN[2], COL_TEXT_MAIN[3], 210))
        nvgText(g, resetX + resetW / 2, resetY + resetH / 2, "显示全部", nil)
        state.filterResetRect = { x = resetX, y = resetY, w = resetW, h = resetH }
    end

    -- 右侧按钮（右栏内右端）
    local barRightX = W - 10
    local btnH = 26

    -- 解锁格子
    local ulW = 80
    local ulX = barRightX - ulW
    local ulY = ACTION_BAR_Y
    drawButton(g, ulX, ulY, ulW, btnH, 5,
        {55, 105, 65}, {40, 82, 50}, {100, 200, 135, 110},
        nil, nil)
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 16)
    nvgFillColor(g, nvgRGBA(190, 255, 210, 240))
    nvgText(g, ulX + ulW / 2, ulY + btnH / 2, "解锁 +5", nil)
    state.unlockBtnRect = { x = ulX, y = ulY, w = ulW, h = btnH }

    -- 筛选分解 + 选中分解
    local batchCount, _ = getBatchDecompInfo()
    state.batchBtnRect = nil
    state.selectBtnRect = nil
    if batchCount > 0 and not state.selectMode then
        local btW = 76
        local gap = 4
        -- 筛选分解
        local bt1X = ulX - btW - gap
        drawButton(g, bt1X, ulY, btW, btnH, 5,
            {125, 55, 50}, {98, 38, 35}, {220, 100, 85, 110},
            nil, nil)
        nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(g, 15)
        nvgFillColor(g, nvgRGBA(255, 220, 200, 240))
        nvgText(g, bt1X + btW / 2, ulY + btnH / 2, "筛选分解", nil)
        state.batchBtnRect = { x = bt1X, y = ulY, w = btW, h = btnH }
        -- 选中分解
        local bt2X = bt1X - btW - gap
        drawButton(g, bt2X, ulY, btW, btnH, 5,
            {90, 60, 120}, {70, 45, 95}, {160, 120, 200, 110},
            nil, nil)
        nvgFontSize(g, 15)
        nvgFillColor(g, nvgRGBA(220, 200, 255, 240))
        nvgText(g, bt2X + btW / 2, ulY + btnH / 2, "选中分解", nil)
        state.selectBtnRect = { x = bt2X, y = ulY, w = btW, h = btnH }
    end
end

-- ============================================================================
-- 绘制: 网格仓库
-- ============================================================================
local function drawGrid(g)
    local items = getFilteredItems()
    local unlocked = getUnlockedSlots()
    local displayCount = math.max(unlocked + UNLOCK_PER_AD, #items)
    displayCount = math.ceil(displayCount / GRID_COLS) * GRID_COLS

    local totalRows = math.ceil(displayCount / GRID_COLS)
    local totalContentH = totalRows * (CELL_SIZE + CELL_GAP) - CELL_GAP
    local maxScrollY = 0
    local minScrollY = math.min(0, GRID_H - totalContentH)
    state.scrollY = clamp(state.scrollY, minScrollY, maxScrollY)

    nvgSave(g)
    nvgScissor(g, RIGHT_X, GRID_TOP_Y, RIGHT_W, GRID_H)

    state.gridRects = {}

    for idx = 1, displayCount do
        local row = math.floor((idx - 1) / GRID_COLS)
        local col = (idx - 1) % GRID_COLS
        local cx = GRID_X + col * (CELL_SIZE + CELL_GAP)
        local cy = GRID_TOP_Y + row * (CELL_SIZE + CELL_GAP) + state.scrollY

        if cy + CELL_SIZE < GRID_TOP_Y - 10 or cy > GRID_BOT_Y + 10 then
            goto nextCell
        end

        local entry = items[idx]
        local isLocked = (idx > unlocked)
        local item = entry and entry.item or nil
        local highlighted = entry and entry.highlighted or false

        state.gridRects[idx] = { x = cx, y = cy, w = CELL_SIZE, h = CELL_SIZE,
                                 item = item, locked = isLocked }

        -- 格子底板
        nvgBeginPath(g); nvgRoundedRect(g, cx, cy, CELL_SIZE, CELL_SIZE, 6)
        if isLocked then
            nvgFillColor(g, nvgRGBA(COL_LOCKED_BG[1], COL_LOCKED_BG[2], COL_LOCKED_BG[3], 200))
        elseif item then
            local tc = EQUIP_TIERS[item.tier or 1].color
            local grad = nvgLinearGradient(g, cx, cy, cx, cy + CELL_SIZE,
                nvgRGBA(tc[1], tc[2], tc[3], 22), nvgRGBA(COL_PANEL_BG[1], COL_PANEL_BG[2], COL_PANEL_BG[3], 235))
            nvgFillPaint(g, grad); nvgFill(g)
            nvgBeginPath(g); nvgRoundedRect(g, cx, cy, CELL_SIZE, CELL_SIZE, 6)
            nvgFillColor(g, nvgRGBA(COL_CELL_BG[1], COL_CELL_BG[2], COL_CELL_BG[3], 140))
            nvgFill(g)
        else
            nvgFillColor(g, nvgRGBA(COL_CELL_BG[1], COL_CELL_BG[2], COL_CELL_BG[3], 170))
        end
        if not item or isLocked then nvgFill(g) end

        -- 边框
        nvgBeginPath(g); nvgRoundedRect(g, cx + 0.5, cy + 0.5, CELL_SIZE - 1, CELL_SIZE - 1, 5.5)
        if item and not isLocked then
            local tc = EQUIP_TIERS[item.tier or 1].color
            local alpha = highlighted and 170 or 60
            nvgStrokeColor(g, nvgRGBA(tc[1], tc[2], tc[3], alpha))
            nvgStrokeWidth(g, highlighted and 1.8 or 0.8)
        elseif isLocked then
            nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 30))
            nvgStrokeWidth(g, 0.6)
        else
            nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 40))
            nvgStrokeWidth(g, 0.6)
        end
        nvgStroke(g)

        if item then
            local iconPad = 6
            local iconSize = CELL_SIZE - iconPad * 2
            if EquipUI._equipSheet and EquipUI._equipSheet > 0 then
                local imgW, imgH = nvgImageSize(g, EquipUI._equipSheet)
                if imgW > 4 and imgH > 4 then
                    DrawEquipTierBg(cx + iconPad - 2, cy + iconPad - 2, iconSize + 4, iconSize + 4, item.tier or 1, 4)
                    DrawCardImage(cx + iconPad, cy + iconPad, iconSize, iconSize,
                        EquipUI._equipSheet, item.slotIdx - 1, item.setIdx - 1,
                        EquipUI._sheetCols, EquipUI._sheetRows)
                end
            end

            -- 品阶角标
            local tierData = EQUIP_TIERS[item.tier or 1]
            local tc = tierData.color
            local badgeW, badgeH = 28, 14
            nvgBeginPath(g)
            nvgMoveTo(g, cx, cy + 6); nvgLineTo(g, cx, cy)
            nvgLineTo(g, cx + badgeW, cy); nvgLineTo(g, cx + badgeW - 4, cy + badgeH)
            nvgLineTo(g, cx, cy + badgeH); nvgClosePath(g)
            nvgFillColor(g, nvgRGBA(tc[1], tc[2], tc[3], 210)); nvgFill(g)
            nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(g, 13)
            nvgFillColor(g, nvgRGBA(255, 255, 255, 245))
            nvgText(g, cx + badgeW / 2 - 1, cy + badgeH / 2, tierData.name, nil)

            -- 等级
            local lvStr = "Lv." .. (item.level or 1)
            if (item.enhanceLv or 0) > 0 then
                lvStr = lvStr .. "+" .. item.enhanceLv
            end
            nvgTextAlign(g, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(g, 14)
            nvgFillColor(g, nvgRGBA(255, 225, 130, 210))
            nvgText(g, cx + CELL_SIZE - 4, cy + 10, lvStr, nil)

            -- 已装备标记
            if isItemEquipped(item) then
                local tagW, tagH = 28, 14
                local tagX, tagY = cx + CELL_SIZE - tagW - 2, cy + CELL_SIZE - tagH - 2
                nvgBeginPath(g); nvgRoundedRect(g, tagX, tagY, tagW, tagH, 3)
                local eGrad = nvgLinearGradient(g, tagX, tagY, tagX, tagY + tagH,
                    nvgRGBA(55, 180, 100, 225), nvgRGBA(40, 140, 78, 225))
                nvgFillPaint(g, eGrad); nvgFill(g)
                nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFontSize(g, 12)
                nvgFillColor(g, nvgRGBA(255, 255, 255, 240))
                nvgText(g, tagX + tagW / 2, tagY + tagH / 2, "装备", nil)
            end

            -- 非高亮遮罩
            if state.filterSlot > 0 and not highlighted then
                nvgBeginPath(g); nvgRoundedRect(g, cx, cy, CELL_SIZE, CELL_SIZE, 6)
                nvgFillColor(g, nvgRGBA(25, 22, 35, 145)); nvgFill(g)
            end

            -- 锁定覆盖
            if isLocked then
                nvgBeginPath(g); nvgRoundedRect(g, cx, cy, CELL_SIZE, CELL_SIZE, 6)
                nvgFillColor(g, nvgRGBA(28, 25, 38, 140)); nvgFill(g)
                drawLockIcon(g, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2, 28, 170)
            end

            -- 选中分解模式勾选框
            if state.selectMode and not isLocked then
                local isEquipped = isItemEquipped(item)
                local isSelected = state.selectedUids[item.uid] == true
                local cbSize = 20
                local cbX, cbY = cx + CELL_SIZE - cbSize - 2, cy + 2
                if isEquipped then
                    -- 已装备：灰色锁定标记
                    nvgBeginPath(g); nvgRoundedRect(g, cx, cy, CELL_SIZE, CELL_SIZE, 6)
                    nvgFillColor(g, nvgRGBA(25, 22, 35, 120)); nvgFill(g)
                elseif isSelected then
                    -- 已选中：蓝色高亮边框 + 勾选
                    nvgBeginPath(g); nvgRoundedRect(g, cx, cy, CELL_SIZE, CELL_SIZE, 6)
                    nvgFillColor(g, nvgRGBA(80, 120, 200, 50)); nvgFill(g)
                    nvgBeginPath(g); nvgRoundedRect(g, cx + 0.5, cy + 0.5, CELL_SIZE - 1, CELL_SIZE - 1, 5.5)
                    nvgStrokeColor(g, nvgRGBA(100, 160, 255, 200)); nvgStrokeWidth(g, 2); nvgStroke(g)
                    -- 勾选框
                    nvgBeginPath(g); nvgRoundedRect(g, cbX, cbY, cbSize, cbSize, 4)
                    nvgFillColor(g, nvgRGBA(80, 140, 255, 230)); nvgFill(g)
                    -- 勾号
                    nvgBeginPath(g)
                    nvgMoveTo(g, cbX + 4, cbY + cbSize * 0.5)
                    nvgLineTo(g, cbX + cbSize * 0.38, cbY + cbSize - 5)
                    nvgLineTo(g, cbX + cbSize - 4, cbY + 5)
                    nvgStrokeColor(g, nvgRGBA(255, 255, 255, 245)); nvgStrokeWidth(g, 2.5); nvgStroke(g)
                else
                    -- 未选中：空勾选框
                    nvgBeginPath(g); nvgRoundedRect(g, cbX, cbY, cbSize, cbSize, 4)
                    nvgStrokeColor(g, nvgRGBA(180, 170, 200, 150)); nvgStrokeWidth(g, 1.5); nvgStroke(g)
                    nvgFillColor(g, nvgRGBA(40, 35, 50, 160)); nvgFill(g)
                end
            end
        elseif isLocked then
            drawLockIcon(g, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2, 22, 80)
        end

        ::nextCell::
    end

    -- 滚动条（右栏右边缘）
    if totalContentH > GRID_H then
        local barW = 3
        local barX = W - 6
        local scrollRange = math.abs(minScrollY)
        local scrollRatio = scrollRange > 0 and (math.abs(state.scrollY) / scrollRange) or 0
        local barH = math.max(30, GRID_H * (GRID_H / totalContentH))
        local barY = GRID_TOP_Y + scrollRatio * (GRID_H - barH)
        nvgBeginPath(g); nvgRoundedRect(g, barX, barY, barW, barH, 1.5)
        nvgFillColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 70))
        nvgFill(g)
    end

    nvgRestore(g)

    -- 底部渐隐（右栏范围）
    nvgBeginPath(g); nvgRect(g, RIGHT_X, GRID_BOT_Y - 18, RIGHT_W, 20)
    local fadeGrad = nvgLinearGradient(g, RIGHT_X, GRID_BOT_Y - 18, RIGHT_X, GRID_BOT_Y,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(30, 25, 38, 200))
    nvgFillPaint(g, fadeGrad); nvgFill(g)
end

-- ============================================================================
-- 绘制: 底部套装概览 + 激活加成
-- ============================================================================
local function drawSetInfoBar(g)
    local setCounts = {}
    for si = 1, 7 do
        local eqI = GetEquippedItem(si)
        if eqI and eqI.setIdx then
            setCounts[eqI.setIdx] = (setCounts[eqI.setIdx] or 0) + 1
        end
    end
    -- 收集已装备套装信息 (按件数降序)
    local setItems = {}
    for setIdx, cnt in pairs(setCounts) do
        local setD = EQUIPMENT_SETS[setIdx]
        if setD then
            local activated = 0
            if cnt >= 7 then activated = 3
            elseif cnt >= 4 then activated = 2
            elseif cnt >= 3 then activated = 1
            end
            setItems[#setItems + 1] = { idx = setIdx, name = setD.name, cnt = cnt, activated = activated, data = setD }
        end
    end
    if #setItems == 0 then return end
    table.sort(setItems, function(a, b) return a.cnt > b.cnt end)

    local padX = LEFT_PAD
    local barW = LEFT_W - padX * 2

    -- 背景面板（左栏内）
    nvgBeginPath(g); nvgRoundedRect(g, padX, SET_BAR_Y, barW, SET_BAR_H, 8)
    local panelGrad = nvgLinearGradient(g, padX, SET_BAR_Y, padX, SET_BAR_Y + SET_BAR_H,
        nvgRGBA(48, 42, 58, 230), nvgRGBA(35, 30, 45, 230))
    nvgFillPaint(g, panelGrad); nvgFill(g)
    nvgBeginPath(g); nvgRoundedRect(g, padX, SET_BAR_Y, barW, SET_BAR_H, 8)
    nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 55))
    nvgStrokeWidth(g, 1.0); nvgStroke(g)

    nvgFontFaceId(g, GetMainFont())

    -- 标题（左栏居中）
    local titleY = SET_BAR_Y + 12
    local leftCenter = LEFT_W / 2
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 14)
    nvgFillColor(g, nvgRGBA(COL_GOLD_DIM[1], COL_GOLD_DIM[2], COL_GOLD_DIM[3], 200))
    nvgText(g, leftCenter, titleY, "套装加成", nil)
    -- 标题下分隔线
    local sepLX, sepRX = padX + 12, padX + barW - 12
    local sepMid = leftCenter
    local sepLineY = titleY + 9
    local gradL = nvgLinearGradient(g, sepLX, sepLineY, sepMid, sepLineY,
        nvgRGBA(COL_SEPARATOR[1], COL_SEPARATOR[2], COL_SEPARATOR[3], 0),
        nvgRGBA(COL_SEPARATOR[1], COL_SEPARATOR[2], COL_SEPARATOR[3], 50))
    nvgBeginPath(g); nvgMoveTo(g, sepLX, sepLineY); nvgLineTo(g, sepMid, sepLineY)
    nvgStrokePaint(g, gradL); nvgStrokeWidth(g, 0.8); nvgStroke(g)
    local gradR = nvgLinearGradient(g, sepMid, sepLineY, sepRX, sepLineY,
        nvgRGBA(COL_SEPARATOR[1], COL_SEPARATOR[2], COL_SEPARATOR[3], 50),
        nvgRGBA(COL_SEPARATOR[1], COL_SEPARATOR[2], COL_SEPARATOR[3], 0))
    nvgBeginPath(g); nvgMoveTo(g, sepMid, sepLineY); nvgLineTo(g, sepRX, sepLineY)
    nvgStrokePaint(g, gradR); nvgStrokeWidth(g, 0.8); nvgStroke(g)

    -- 限制绘制区域（防溢出）
    nvgSave(g)
    nvgScissor(g, padX, SET_BAR_Y, barW, SET_BAR_H)

    -- 逐套装显示
    local curY = SET_BAR_Y + 26
    local innerX = padX + 8
    local innerW = barW - 16
    local maxSets = 4  -- 横屏左栏空间大，最多显示4套

    for i = 1, math.min(#setItems, maxSets) do
        local si = setItems[i]
        local sd = si.data
        local sc = sd.color

        -- 套装名 + 进度条
        nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(g, 14)
        if si.activated > 0 then
            nvgFillColor(g, nvgRGBA(sc[1], sc[2], sc[3], 240))
        else
            nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 180))
        end
        nvgText(g, innerX, curY, si.name, nil)

        -- 件数指示 (右侧)
        nvgTextAlign(g, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFontSize(g, 12)
        nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 160))
        nvgText(g, padX + barW - 8, curY, si.cnt .. "/7", nil)

        -- 进度点 (7个小圆点)
        local dotsX = innerX + 72
        local dotGap = 12
        for d = 1, 7 do
            local dx = dotsX + (d - 1) * dotGap
            nvgBeginPath(g); nvgCircle(g, dx, curY, 2.5)
            if d <= si.cnt then
                nvgFillColor(g, nvgRGBA(sc[1], sc[2], sc[3], 220))
            else
                nvgFillColor(g, nvgRGBA(60, 55, 70, 180))
            end
            nvgFill(g)
        end

        curY = curY + 16

        -- 显示各阶加成 (3件/4件/7件)
        local bonusTiers = {}
        if sd.setBonus3 then bonusTiers[#bonusTiers + 1] = { n = 3, desc = sd.setBonus3Desc or "" } end
        if sd.setBonus4 then bonusTiers[#bonusTiers + 1] = { n = 4, desc = sd.setBonus4Desc or "" } end
        if sd.setBonus  then bonusTiers[#bonusTiers + 1] = { n = 7, desc = sd.setBonusDesc or "" } end

        for _, bt in ipairs(bonusTiers) do
            local isActive = si.cnt >= bt.n
            -- 阶数标签
            nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(g, 13)
            if isActive then
                -- 激活: 金色标签 + 亮色描述
                nvgFillColor(g, nvgRGBA(255, 210, 80, 230))
                nvgText(g, innerX + 4, curY, "(" .. bt.n .. ")", nil)
                nvgFillColor(g, nvgRGBA(245, 235, 200, 210))
            else
                -- 未激活: 灰色
                nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 90))
                nvgText(g, innerX + 4, curY, "(" .. bt.n .. ")", nil)
                nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 80))
            end
            nvgText(g, innerX + 26, curY, bt.desc, nil)

            -- 激活状态标记
            if isActive then
                nvgTextAlign(g, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFontSize(g, 11)
                nvgFillColor(g, nvgRGBA(COL_ACCENT_GREEN[1], COL_ACCENT_GREEN[2], COL_ACCENT_GREEN[3], 200))
                nvgText(g, padX + barW - 8, curY, "生效中", nil)
            end
            curY = curY + 14
        end
        curY = curY + 3  -- 套装间距
    end

    nvgRestore(g) -- 关闭 scissor
end

-- ============================================================================
-- 绘制: 长按 Tooltip（行间距加大）
-- ============================================================================
local function drawTooltip(g)
    if not state.tooltipUid then return end
    local item = FindOwnedByUid(state.tooltipUid)
    if not item then state.tooltipUid = nil; return end

    local setData = EQUIPMENT_SETS[item.setIdx]
    local piece = setData.pieces[item.slotIdx]
    local tierData = EQUIP_TIERS[item.tier or 1]
    local tc = tierData.color
    local eqEnhLv = item.enhanceLv or 0
    local eqLevel = item.level or 1
    local enhMul = 1.0 + eqEnhLv * ENHANCE_PERCENT_PER_LEVEL / 100
    local qBonus = GetQualityBonus(item.quality)
    local lvBonus = GetLevelBonus(eqLevel)
    local qLabel, qColor = GetQualityLabel(item.quality)
    local equipped = isItemEquipped(item)

    drawOverlay(g)

    local pw, ph = 420, 360
    local px = math.floor((W - pw) / 2)
    local py = math.floor((H - ph) / 2) - 10
    drawPanel(g, px, py, pw, ph, tc)

    local tx = px + 16
    local ty = py + 14

    -- 图标
    local tipIconSize = 58
    if EquipUI._equipSheet and EquipUI._equipSheet > 0 then
        DrawEquipTierBg(tx - 2, ty - 2, tipIconSize + 4, tipIconSize + 4, item.tier or 1, 6)
        DrawCardImage(tx, ty, tipIconSize, tipIconSize,
            EquipUI._equipSheet, item.slotIdx - 1, item.setIdx - 1,
            EquipUI._sheetCols, EquipUI._sheetRows)
    end
    nvgBeginPath(g); nvgRoundedRect(g, tx, ty, tipIconSize, tipIconSize, 5)
    nvgStrokeColor(g, nvgRGBA(tc[1], tc[2], tc[3], 170)); nvgStrokeWidth(g, 1.5); nvgStroke(g)

    -- 名称（图标右侧）
    local nameX = tx + tipIconSize + 12
    nvgFontFaceId(g, GetMainFont())
    nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 24)
    nvgFillColor(g, nvgRGBA(tc[1], tc[2], tc[3], 245))
    nvgText(g, nameX, ty + 14, piece.name, nil)

    -- 套装 + 品阶
    nvgFontSize(g, 18)
    nvgFillColor(g, nvgRGBA(setData.color[1], setData.color[2], setData.color[3], 190))
    nvgText(g, nameX, ty + 34, setData.name .. " - " .. tierData.name, nil)

    -- 等级 + 强化
    nvgFontSize(g, 17)
    nvgFillColor(g, nvgRGBA(255, 225, 130, 225))
    local lvText = "Lv." .. eqLevel
    if eqEnhLv > 0 then
        nvgText(g, nameX, ty + 52, lvText, nil)
        local lvW = nvgTextBounds(g, 0, 0, lvText .. "  ", nil)
        nvgFillColor(g, nvgRGBA(COL_ACCENT_BLUE[1], COL_ACCENT_BLUE[2], COL_ACCENT_BLUE[3], 230))
        nvgText(g, nameX + lvW, ty + 52, "+" .. eqEnhLv, nil)
    else
        nvgText(g, nameX, ty + 52, lvText, nil)
    end

    -- 品质 (右上)
    nvgTextAlign(g, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 17)
    nvgFillColor(g, nvgRGBA(qColor[1], qColor[2], qColor[3], 215))
    nvgText(g, px + pw - 16, ty + 14, qLabel .. " " .. item.quality .. "%", nil)
    nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 170))
    nvgText(g, px + pw - 16, ty + 34, EQUIP_SLOT_NAMES[item.slotIdx], nil)

    -- ──── 分隔线 ────
    local sepY = ty + tipIconSize + 8
    drawGothicSeparator(g, sepY, px + 14, W - px - pw + 14, 55)

    -- ──── 属性行 ────
    local attrY = sepY + 18
    nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 19)
    local atkVal = (piece.atkPct + qBonus + lvBonus) * tierData.multiplier * enhMul
    local defVal = (piece.defPct + qBonus + lvBonus) * tierData.multiplier * enhMul
    local hpVal  = (piece.hpPct + qBonus + lvBonus) * tierData.multiplier * enhMul
    nvgFillColor(g, nvgRGBA(255, 145, 125, 235))
    nvgText(g, tx, attrY, string.format("ATK +%.1f%%", atkVal), nil)
    nvgFillColor(g, nvgRGBA(130, 190, 255, 235))
    nvgText(g, tx + 130, attrY, string.format("DEF +%.1f%%", defVal), nil)
    nvgFillColor(g, nvgRGBA(130, 235, 170, 235))
    nvgText(g, tx + 260, attrY, string.format("HP +%.1f%%", hpVal), nil)

    -- ──── 套装效果 ────
    local setY = attrY + 28
    local setCounts = {}
    for si = 1, 7 do
        local eqI = GetEquippedItem(si)
        if eqI and eqI.setIdx == item.setIdx then
            setCounts[item.setIdx] = (setCounts[item.setIdx] or 0) + 1
        end
    end
    local setCount = setCounts[item.setIdx] or 0
    nvgFontSize(g, 16)
    nvgFillColor(g, nvgRGBA(COL_GOLD_DIM[1], COL_GOLD_DIM[2], COL_GOLD_DIM[3], 200))
    nvgText(g, tx, setY, setData.name .. " 套装 (" .. setCount .. "/7)", nil)

    local tierLines = {}
    if setData.setBonus3 then tierLines[#tierLines + 1] = { need = 3, desc = setData.setBonus3Desc or "" } end
    if setData.setBonus4 then tierLines[#tierLines + 1] = { need = 4, desc = setData.setBonus4Desc or "" } end
    if setData.setBonus then tierLines[#tierLines + 1] = { need = 7, desc = setData.setBonusDesc or "" } end

    for li, tl in ipairs(tierLines) do
        local ly = setY + 22 * li
        nvgFontSize(g, 15)
        nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        if setCount >= tl.need then
            nvgFillColor(g, nvgRGBA(255, 215, 90, 225))
        else
            nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 120))
        end
        nvgText(g, tx + 8, ly, "(" .. tl.need .. "件) " .. tl.desc, nil)

        nvgTextAlign(g, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        if setCount >= tl.need then
            nvgFillColor(g, nvgRGBA(COL_ACCENT_GREEN[1], COL_ACCENT_GREEN[2], COL_ACCENT_GREEN[3], 215))
            nvgText(g, px + pw - 16, ly, "已激活", nil)
        else
            nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 110))
            nvgText(g, px + pw - 16, ly, "差" .. (tl.need - setCount) .. "件", nil)
        end
    end

    -- ──── 操作按钮 ────
    local btnY = py + ph - 52
    local btnH = 38

    state.tipEquipRect = nil
    state.tipDecompRect = nil
    state.tipEnhanceRect = nil

    if equipped then
        local btn1W, btn2W = 100, 145
        local btnGap = 12
        local totalBtnW = btn1W + btn2W + btnGap
        local btnStartX = math.floor((pw - totalBtnW) / 2) + px

        drawButton(g, btnStartX, btnY, btn1W, btnH, 7,
            {90, 78, 58}, {68, 58, 42}, {COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 110},
            "卸下", COL_TEXT_MAIN, 20)
        state.tipEquipRect = { x = btnStartX, y = btnY, w = btn1W, h = btnH, action = "unequip" }

        local enhX = btnStartX + btn1W + btnGap
        if eqEnhLv < ENHANCE_MAX_LEVEL then
            local enhCost = ENHANCE_COST[eqEnhLv + 1] or 999
            local canEnh = (playerInfo.lingshi >= enhCost)
            if canEnh then
                drawButton(g, enhX, btnY, btn2W, btnH, 7,
                    {60, 125, 215}, {42, 98, 178}, {100, 180, 255, 110},
                    "强化(" .. enhCost .. "军资)", {255, 255, 255, 245}, 19)
            else
                drawButton(g, enhX, btnY, btn2W, btnH, 7,
                    {55, 50, 62}, {42, 38, 50}, {85, 78, 90, 60},
                    nil, nil, 19)
                nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFontSize(g, 19)
                nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 130))
                nvgText(g, enhX + btn2W / 2, btnY + btnH / 2, "强化(" .. enhCost .. "军资)", nil)
            end
            state.tipEnhanceRect = { x = enhX, y = btnY, w = btn2W, h = btnH }
        else
            nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(g, 19)
            nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 200))
            nvgText(g, enhX + btn2W / 2, btnY + btnH / 2, "已满 +20", nil)
        end
    else
        -- 双按钮布局：装备 | 分解
        local btn1W, btn2W = 100, 155
        local btnGap = 12
        local totalBtnW = btn1W + btn2W + btnGap
        local btnStartX = math.floor((pw - totalBtnW) / 2) + px

        drawButton(g, btnStartX, btnY, btn1W, btnH, 7,
            {55, 150, 95}, {42, 120, 72}, {100, 210, 140, 110},
            "装备", {255, 255, 255, 245}, 20)
        state.tipEquipRect = { x = btnStartX, y = btnY, w = btn1W, h = btnH, action = "equip" }

        local decompGain = CalcDecomposeGain(item.tier, eqEnhLv)
        local decX = btnStartX + btn1W + btnGap
        drawButton(g, decX, btnY, btn2W, btnH, 7,
            {160, 62, 55}, {130, 42, 38}, {230, 110, 95, 110},
            "分解 +" .. decompGain .. " 军资", {255, 228, 210, 245}, 19)
        state.tipDecompRect = { x = decX, y = btnY, w = btn2W, h = btnH }
    end
end

-- ============================================================================
-- 绘制: 分解确认弹窗
-- ============================================================================
local function drawDecompDialog(g)
    local dc = state.decompConfirm
    if not dc then return end
    drawOverlay(g)

    local pw, ph = 370, 230
    local px, py = math.floor((W - pw) / 2), math.floor((H - ph) / 2) - 10
    drawPanel(g, px, py, pw, ph, COL_ACCENT_RED)

    nvgFontFaceId(g, GetMainFont())
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 24)
    DrawWhiteInkText(W / 2, py + 32, "确认分解")

    drawGothicSeparator(g, py + 54, px + 20, W - px - pw + 20, 50)

    local tierName = EQUIP_TIERS[dc.tier] and EQUIP_TIERS[dc.tier].name or ""
    local setData = EQUIPMENT_SETS[dc.setIdx]
    local pieceName = setData and setData.pieces[dc.slotIdx] and setData.pieces[dc.slotIdx].name or ""

    nvgFontSize(g, 22)
    nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 230))
    nvgText(g, W / 2, py + 80, tierName .. " " .. pieceName, nil)

    nvgFontSize(g, 19)
    nvgFillColor(g, nvgRGBA(COL_TEXT_MAIN[1], COL_TEXT_MAIN[2], COL_TEXT_MAIN[3], 215))
    if dc.enhLv and dc.enhLv > 0 then
        nvgText(g, W / 2, py + 108, string.format("强化+%d  获得 %d 军资", dc.enhLv, dc.gain), nil)
        nvgFontSize(g, 16)
        nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 180))
        nvgText(g, W / 2, py + 132, "(含强化返还" .. (dc.enhRefund or 0) .. "军资)", nil)
    else
        nvgText(g, W / 2, py + 114, "分解可获得 " .. dc.gain .. " 军资", nil)
    end

    local btnW2, btnH2 = 120, 38
    local gap = 16
    local btnY = py + ph - 54
    local confirmX = math.floor(W / 2 - btnW2 - gap / 2)
    local cancelX = math.floor(W / 2 + gap / 2)

    drawButton(g, confirmX, btnY, btnW2, btnH2, 7,
        {200, 65, 50}, {160, 45, 35}, {245, 110, 95, 110},
        "确认分解", {255, 240, 228, 255}, 19)
    state.dConfirmRect = { x = confirmX, y = btnY, w = btnW2, h = btnH2 }

    drawButton(g, cancelX, btnY, btnW2, btnH2, 7,
        {78, 70, 65}, {58, 52, 48}, {COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 80},
        "取消", COL_TEXT_MAIN, 19)
    state.dCancelRect = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
end

-- ============================================================================
-- 绘制: 强化确认弹窗
-- ============================================================================
local function drawEnhanceDialog(g)
    local ec = state.enhanceConfirm
    if not ec then return end
    drawOverlay(g)

    local pw, ph = 350, 210
    local px, py = math.floor((W - pw) / 2), math.floor((H - ph) / 2) - 10
    drawPanel(g, px, py, pw, ph, COL_ACCENT_BLUE)

    nvgFontFaceId(g, GetMainFont())
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 24)
    DrawWhiteInkText(W / 2, py + 32, "确认强化")

    drawGothicSeparator(g, py + 52, px + 20, W - px - pw + 20, 50)

    nvgFontSize(g, 22)
    nvgFillColor(g, nvgRGBA(COL_TEXT_MAIN[1], COL_TEXT_MAIN[2], COL_TEXT_MAIN[3], 230))
    nvgText(g, W / 2, py + 80, string.format("+%d  -->  +%d", ec.enhLv, ec.enhLv + 1), nil)
    nvgFontSize(g, 19)
    nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 215))
    nvgText(g, W / 2, py + 108, string.format("消耗 %d 军资", ec.cost), nil)

    local btnW2, btnH2 = 120, 38
    local gap = 16
    local btnY = py + ph - 52
    local confirmX = math.floor(W / 2 - btnW2 - gap / 2)
    local cancelX = math.floor(W / 2 + gap / 2)

    drawButton(g, confirmX, btnY, btnW2, btnH2, 7,
        {60, 135, 225}, {45, 105, 185}, {100, 180, 255, 110},
        "确认强化", {255, 255, 255, 250}, 19)
    state.eConfirmRect = { x = confirmX, y = btnY, w = btnW2, h = btnH2 }

    drawButton(g, cancelX, btnY, btnW2, btnH2, 7,
        {78, 70, 65}, {58, 52, 48}, {COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 80},
        "取消", COL_TEXT_MAIN, 19)
    state.eCancelRect = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
end

-- ============================================================================
-- 绘制: 批量分解弹窗
-- ============================================================================
local function drawBatchDecompDialog(g)
    local bdc = state.batchDecompConfirm
    if not bdc then return end
    drawOverlay(g)

    local pw, ph = 380, 240
    local px, py = math.floor((W - pw) / 2), math.floor((H - ph) / 2) - 10
    drawPanel(g, px, py, pw, ph, COL_ACCENT_RED)

    nvgFontFaceId(g, GetMainFont())
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 24)
    DrawWhiteInkText(W / 2, py + 32, "一键分解确认")

    drawGothicSeparator(g, py + 54, px + 20, W - px - pw + 20, 50)

    nvgFontSize(g, 20)
    nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 235))
    nvgText(g, W / 2, py + 80, "将分解 " .. bdc.count .. " 件未装备宝物", nil)

    nvgFontSize(g, 19)
    nvgFillColor(g, nvgRGBA(COL_TEXT_MAIN[1], COL_TEXT_MAIN[2], COL_TEXT_MAIN[3], 215))
    nvgText(g, W / 2, py + 106, "预计获得 " .. bdc.gain .. " 军资", nil)

    nvgFontSize(g, 16)
    nvgFillColor(g, nvgRGBA(COL_ACCENT_RED[1], COL_ACCENT_RED[2], COL_ACCENT_RED[3], 200))
    nvgText(g, W / 2, py + 130, "此操作不可撤销", nil)

    local btnW2, btnH2 = 120, 38
    local gap = 16
    local btnY = py + ph - 54
    local confirmX = math.floor(W / 2 - btnW2 - gap / 2)
    local cancelX = math.floor(W / 2 + gap / 2)

    drawButton(g, confirmX, btnY, btnW2, btnH2, 7,
        {200, 65, 50}, {160, 45, 35}, {245, 110, 95, 110},
        "全部分解", {255, 240, 228, 255}, 19)
    state.bConfirmRect = { x = confirmX, y = btnY, w = btnW2, h = btnH2 }

    drawButton(g, cancelX, btnY, btnW2, btnH2, 7,
        {78, 70, 65}, {58, 52, 48}, {COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 80},
        "取消", COL_TEXT_MAIN, 19)
    state.bCancelRect = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
end

-- ============================================================================
-- 绘制: 选中分解底部操作栏
-- ============================================================================
local function drawSelectBar(g)
    if not state.selectMode then return end

    -- 统计选中数量和收益
    local selCount, selGain = 0, 0
    for uid, _ in pairs(state.selectedUids) do
        local item = FindOwnedByUid(uid)
        if item and not isItemEquipped(item) then
            selCount = selCount + 1
            selGain = selGain + CalcDecomposeGain(item.tier, item.enhanceLv)
        end
    end

    local barH = 42
    local barY = H - barH
    -- 底栏背景（仅右栏区域）
    nvgBeginPath(g); nvgRect(g, RIGHT_X, barY, RIGHT_W, barH)
    nvgFillColor(g, nvgRGBA(35, 30, 45, 240)); nvgFill(g)
    -- 顶部分割线
    nvgBeginPath(g); nvgMoveTo(g, RIGHT_X, barY); nvgLineTo(g, W, barY)
    nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 80)); nvgStrokeWidth(g, 1); nvgStroke(g)

    nvgFontFaceId(g, GetMainFont())

    -- 左侧: 已选 N 件 +X 军资
    nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 16)
    nvgFillColor(g, nvgRGBA(COL_TEXT_MAIN[1], COL_TEXT_MAIN[2], COL_TEXT_MAIN[3], 215))
    nvgText(g, RIGHT_X + 10, barY + barH / 2, "已选 " .. selCount .. " 件  +" .. selGain .. " 军资", nil)

    -- 右侧按钮组: 全选 | 分解 | 取消
    local btnW, btnHi = 62, 30
    local gap = 6
    local rightX = W - 10

    -- 取消
    local btnPadY = math.floor((barH - btnHi) / 2)
    local cancelX = rightX - btnW
    drawButton(g, cancelX, barY + btnPadY, btnW, btnHi, 5,
        {78, 70, 65}, {58, 52, 48}, {COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 80},
        "取消", COL_TEXT_MAIN, 15)
    state.selectBarCancelRect = { x = cancelX, y = barY + btnPadY, w = btnW, h = btnHi }

    -- 分解
    local decompX = cancelX - btnW - gap
    local decompCol = selCount > 0 and {200, 65, 50} or {80, 60, 58}
    local decompColB = selCount > 0 and {160, 45, 35} or {60, 45, 42}
    local decompGlow = selCount > 0 and {245, 110, 95, 110} or {100, 70, 65, 60}
    drawButton(g, decompX, barY + btnPadY, btnW, btnHi, 5,
        decompCol, decompColB, decompGlow,
        "分解", {255, 240, 228, selCount > 0 and 255 or 120}, 15)
    state.selectBarConfirmRect = { x = decompX, y = barY + btnPadY, w = btnW, h = btnHi }

    -- 全选
    local allX = decompX - btnW - gap
    drawButton(g, allX, barY + btnPadY, btnW, btnHi, 5,
        {55, 85, 120}, {40, 65, 95}, {100, 160, 220, 110},
        "全选", {200, 230, 255, 240}, 15)
    state.selectBarAllRect = { x = allX, y = barY + btnPadY, w = btnW, h = btnHi }
end

-- ============================================================================
-- 绘制: 选中分解确认弹窗
-- ============================================================================
local function drawSelectDecompDialog(g)
    local sdc = state.selectDecompConfirm
    if not sdc then return end
    drawOverlay(g)

    local pw, ph = 380, 240
    local px, py = math.floor((W - pw) / 2), math.floor((H - ph) / 2) - 10
    drawPanel(g, px, py, pw, ph, {120, 80, 180})

    nvgFontFaceId(g, GetMainFont())
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 24)
    DrawWhiteInkText(W / 2, py + 32, "选中分解确认")

    drawGothicSeparator(g, py + 54, px + 20, W - px - pw + 20, 50)

    nvgFontSize(g, 20)
    nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 235))
    nvgText(g, W / 2, py + 80, "将分解 " .. sdc.count .. " 件选中宝物", nil)

    nvgFontSize(g, 19)
    nvgFillColor(g, nvgRGBA(COL_TEXT_MAIN[1], COL_TEXT_MAIN[2], COL_TEXT_MAIN[3], 215))
    nvgText(g, W / 2, py + 106, "预计获得 " .. sdc.gain .. " 军资", nil)

    nvgFontSize(g, 16)
    nvgFillColor(g, nvgRGBA(COL_ACCENT_RED[1], COL_ACCENT_RED[2], COL_ACCENT_RED[3], 200))
    nvgText(g, W / 2, py + 130, "此操作不可撤销", nil)

    local btnW2, btnH2 = 120, 38
    local gapX = 16
    local btnY = py + ph - 54
    local confirmX = math.floor(W / 2 - btnW2 - gapX / 2)
    local cancelX = math.floor(W / 2 + gapX / 2)

    drawButton(g, confirmX, btnY, btnW2, btnH2, 7,
        {140, 60, 160}, {110, 42, 130}, {200, 120, 220, 110},
        "确认分解", {255, 240, 255, 255}, 19)
    state.sdConfirmRect = { x = confirmX, y = btnY, w = btnW2, h = btnH2 }

    drawButton(g, cancelX, btnY, btnW2, btnH2, 7,
        {78, 70, 65}, {58, 52, 48}, {COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 80},
        "取消", COL_TEXT_MAIN, 19)
    state.sdCancelRect = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
end

-- ============================================================================
-- 筛选分解: 计算匹配数量
-- ============================================================================
local function calcFilterDecompStats(tiers, maxLv)
    local count, gain = 0, 0
    for _, item in ipairs(playerEquipment.owned) do
        if playerEquipment.equipped[item.slotIdx] ~= item.uid then
            if tiers[item.tier] and (item.enhanceLv or 0) <= maxLv then
                count = count + 1
                gain = gain + CalcDecomposeGain(item.tier, item.enhanceLv)
            end
        end
    end
    return count, gain
end

-- ============================================================================
-- 绘制: 筛选分解弹窗
-- ============================================================================
local function drawFilterDecompDialog(g)
    local fd = state.filterDecomp
    if not fd then return end
    drawOverlay(g)

    local pw, ph = 420, 340
    local px, py = math.floor((W - pw) / 2), math.floor((H - ph) / 2) - 10
    drawPanel(g, px, py, pw, ph, COL_ACCENT_RED)

    nvgFontFaceId(g, GetMainFont())
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 22)
    DrawWhiteInkText(W / 2, py + 28, "筛选分解")

    drawGothicSeparator(g, py + 46, px + 20, W - px - pw + 20, 50)

    -- === 等阶选择 ===
    nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 17)
    nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 220))
    nvgText(g, px + 20, py + 64, "选择等阶 (勾选要分解的):", nil)

    local cbSize = 24
    local cbGap = 4
    local cols = 3
    local cbStartX = px + 20
    local cbStartY = py + 80
    state.fdTierRects = {}
    for i = 1, 6 do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cbX = cbStartX + col * ((pw - 40) / cols)
        local cbY = cbStartY + row * (cbSize + cbGap + 4)
        local checked = fd.tiers[i] == true
        local tc = EQUIP_TIERS[i].color

        -- 勾选框
        nvgBeginPath(g); nvgRoundedRect(g, cbX, cbY, cbSize, cbSize, 4)
        if checked then
            nvgFillColor(g, nvgRGBA(tc[1], tc[2], tc[3], 180)); nvgFill(g)
        else
            nvgFillColor(g, nvgRGBA(35, 30, 45, 200)); nvgFill(g)
        end
        nvgStrokeColor(g, nvgRGBA(tc[1], tc[2], tc[3], checked and 220 or 100))
        nvgStrokeWidth(g, 1.2); nvgStroke(g)

        if checked then
            nvgFontSize(g, 16)
            nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(g, nvgRGBA(255, 255, 255, 240))
            nvgText(g, cbX + cbSize / 2, cbY + cbSize / 2, "✓", nil)
        end

        -- 等阶名
        nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(g, 15)
        nvgFillColor(g, nvgRGBA(tc[1], tc[2], tc[3], 235))
        nvgText(g, cbX + cbSize + 5, cbY + cbSize / 2, EQUIP_TIERS[i].name, nil)

        state.fdTierRects[i] = { x = cbX, y = cbY, w = cbSize + 55, h = cbSize }
    end

    -- === 强化等级上限 ===
    local lvRowY = cbStartY + 2 * (cbSize + cbGap + 3) + 12
    nvgTextAlign(g, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 17)
    nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 220))
    nvgText(g, px + 20, lvRowY, "强化等级 ≤", nil)

    local lvCtrlX = px + 140
    local lvBtnW, lvBtnH = 36, 28
    -- 减号按钮
    drawButton(g, lvCtrlX, lvRowY - lvBtnH / 2, lvBtnW, lvBtnH, 5,
        {80, 50, 50}, {60, 38, 38}, COL_ACCENT_RED,
        "-", {255, 220, 200, 240}, 20)
    state.fdLvMinusRect = { x = lvCtrlX, y = lvRowY - lvBtnH / 2, w = lvBtnW, h = lvBtnH }

    -- 等级数字
    local lvNumX = lvCtrlX + lvBtnW + 8
    local lvNumW = 50
    nvgBeginPath(g); nvgRoundedRect(g, lvNumX, lvRowY - lvBtnH / 2, lvNumW, lvBtnH, 4)
    nvgFillColor(g, nvgRGBA(25, 20, 35, 200)); nvgFill(g)
    nvgStrokeColor(g, nvgRGBA(COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 100))
    nvgStrokeWidth(g, 1); nvgStroke(g)
    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 19)
    nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 240))
    nvgText(g, lvNumX + lvNumW / 2, lvRowY, tostring(fd.maxLv), nil)

    -- 加号按钮
    local plusX = lvNumX + lvNumW + 8
    drawButton(g, plusX, lvRowY - lvBtnH / 2, lvBtnW, lvBtnH, 5,
        {50, 80, 50}, {38, 60, 38}, COL_ACCENT_GREEN,
        "+", {200, 255, 220, 240}, 20)
    state.fdLvPlusRect = { x = plusX, y = lvRowY - lvBtnH / 2, w = lvBtnW, h = lvBtnH }

    -- === 预览统计 ===
    local statsY = lvRowY + 32
    local matchCount, matchGain = calcFilterDecompStats(fd.tiers, fd.maxLv)

    drawGothicSeparator(g, statsY - 8, px + 20, W - px - pw + 20, 40)

    nvgTextAlign(g, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(g, 18)
    if matchCount > 0 then
        nvgFillColor(g, nvgRGBA(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 235))
        nvgText(g, W / 2, statsY + 10, "匹配 " .. matchCount .. " 件  |  获得 " .. matchGain .. " 军资", nil)
    else
        nvgFillColor(g, nvgRGBA(COL_TEXT_SUB[1], COL_TEXT_SUB[2], COL_TEXT_SUB[3], 180))
        nvgText(g, W / 2, statsY + 10, "没有匹配的宝物", nil)
    end

    -- === 按钮 ===
    local btnW2, btnH2 = 120, 38
    local gapX = 16
    local btnY = py + ph - 52
    local confirmX = math.floor(W / 2 - btnW2 - gapX / 2)
    local cancelX = math.floor(W / 2 + gapX / 2)

    if matchCount > 0 then
        drawButton(g, confirmX, btnY, btnW2, btnH2, 7,
            {200, 65, 50}, {160, 45, 35}, {245, 110, 95, 110},
            "分解 " .. matchCount .. " 件", {255, 240, 228, 255}, 17)
    else
        drawButton(g, confirmX, btnY, btnW2, btnH2, 7,
            {60, 55, 55}, {45, 40, 40}, {100, 90, 90, 80},
            "无可分解", {150, 140, 140, 180}, 17)
    end
    state.fdConfirmRect = { x = confirmX, y = btnY, w = btnW2, h = btnH2 }

    drawButton(g, cancelX, btnY, btnW2, btnH2, 7,
        {78, 70, 65}, {58, 52, 48}, {COL_COPPER[1], COL_COPPER[2], COL_COPPER[3], 80},
        "取消", COL_TEXT_MAIN, 19)
    state.fdCancelRect = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
end

-- ============================================================================
-- 主绘制
-- ============================================================================
function EquipUI.Draw()
    if not EquipUI.isVisible then return end
    local g = EquipUI._vg
    if not g then return end

    nvgFontFaceId(g, GetMainFont())

    drawBackground(g)
    drawTopBar(g)
    drawEquipSlots(g)
    drawStatSummary(g)
    drawActionBar(g)
    drawGrid(g)
    drawSetInfoBar(g)

    drawSelectBar(g)

    drawTooltip(g)
    drawDecompDialog(g)
    drawEnhanceDialog(g)
    drawBatchDecompDialog(g)
    drawSelectDecompDialog(g)
    drawFilterDecompDialog(g)
end

-- ============================================================================
-- 触摸处理: 开始
-- ============================================================================
function EquipUI.HandleTouchBegin(dx, dy)
    if not EquipUI.isVisible then return false end

    if state.selectDecompConfirm then
        if hitRect(state.sdConfirmRect, dx, dy) then
            -- 执行选中分解
            local totalCount, totalGain = 0, 0
            local uidsToRemove = {}
            for uid, _ in pairs(state.selectedUids) do
                local item = FindOwnedByUid(uid)
                if item and not isItemEquipped(item) then
                    uidsToRemove[#uidsToRemove + 1] = uid
                    totalCount = totalCount + 1
                    totalGain = totalGain + CalcDecomposeGain(item.tier, item.enhanceLv)
                end
            end
            for _, uid in ipairs(uidsToRemove) do
                for i = #playerEquipment.owned, 1, -1 do
                    if playerEquipment.owned[i].uid == uid then
                        table.remove(playerEquipment.owned, i); break
                    end
                end
            end
            playerInfo.lingshi = (playerInfo.lingshi or 0) + totalGain
            AddFloatText(W / 2, H * 0.3,
                "选中分解 " .. totalCount .. " 件 +" .. totalGain .. " 军资", 2.5, {255, 200, 100}, 18)
            state.selectDecompConfirm = nil
            state.selectedUids = {}
            state.selectMode = false
            SaveGameProgress()
            PlaySFX(AUDIO.sfx_click)
        elseif hitRect(state.sdCancelRect, dx, dy) then
            state.selectDecompConfirm = nil; PlaySFX(AUDIO.sfx_click)
        end
        return true
    end
    if state.filterDecomp then
        local fd = state.filterDecomp
        -- 等阶勾选
        for i = 1, 6 do
            if state.fdTierRects[i] and hitRect(state.fdTierRects[i], dx, dy) then
                fd.tiers[i] = not fd.tiers[i]
                PlaySFX(AUDIO.sfx_click); return true
            end
        end
        -- 等级 -/+
        if hitRect(state.fdLvMinusRect, dx, dy) then
            fd.maxLv = math.max(0, fd.maxLv - 1)
            PlaySFX(AUDIO.sfx_click); return true
        end
        if hitRect(state.fdLvPlusRect, dx, dy) then
            fd.maxLv = math.min(ENHANCE_MAX_LEVEL or 20, fd.maxLv + 1)
            PlaySFX(AUDIO.sfx_click); return true
        end
        -- 确认分解
        if hitRect(state.fdConfirmRect, dx, dy) then
            local cnt, _ = calcFilterDecompStats(fd.tiers, fd.maxLv)
            if cnt > 0 then
                BatchDecomposeAll(nil, fd.tiers, fd.maxLv)
                state.filterDecomp = nil
            end
            PlaySFX(AUDIO.sfx_click); return true
        end
        -- 取消
        if hitRect(state.fdCancelRect, dx, dy) then
            state.filterDecomp = nil; PlaySFX(AUDIO.sfx_click); return true
        end
        return true
    end
    if state.batchDecompConfirm then
        if hitRect(state.bConfirmRect, dx, dy) then
            BatchDecomposeAll(); state.batchDecompConfirm = nil; PlaySFX(AUDIO.sfx_click)
        elseif hitRect(state.bCancelRect, dx, dy) then
            state.batchDecompConfirm = nil; PlaySFX(AUDIO.sfx_click)
        end
        return true
    end
    if state.enhanceConfirm then
        if hitRect(state.eConfirmRect, dx, dy) then
            EnhanceEquipment(state.enhanceConfirm.slotIdx)
            state.enhanceConfirm = nil; state.tooltipUid = nil; PlaySFX(AUDIO.sfx_click)
        elseif hitRect(state.eCancelRect, dx, dy) then
            state.enhanceConfirm = nil; PlaySFX(AUDIO.sfx_click)
        end
        return true
    end

    if state.decompConfirm then
        if hitRect(state.dConfirmRect, dx, dy) then
            DecomposeEquipment(state.decompConfirm.uid)
            state.decompConfirm = nil; state.tooltipUid = nil; PlaySFX(AUDIO.sfx_click)
        elseif hitRect(state.dCancelRect, dx, dy) then
            state.decompConfirm = nil; PlaySFX(AUDIO.sfx_click)
        end
        return true
    end

    if state.tooltipUid then
        local item = FindOwnedByUid(state.tooltipUid)
        if item then
            if hitRect(state.tipEquipRect, dx, dy) then
                local act = state.tipEquipRect.action
                if act == "equip" then
                    playerEquipment.equipped[item.slotIdx] = item.uid
                    local pName = EQUIPMENT_SETS[item.setIdx].pieces[item.slotIdx].name
                    AddFloatText(W / 2, H * 0.4, "装备 " .. pName, 1.0, {100, 255, 180}, 18)
                    playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                    TrackDailyTask("equip1", 1)
                    SaveGameProgress()
                elseif act == "unequip" then
                    playerEquipment.equipped[item.slotIdx] = nil
                    AddFloatText(W / 2, H * 0.4, "已卸下装备", 1.0, {200, 200, 200}, 18)
                    SaveGameProgress()
                end
                state.tooltipUid = nil; PlaySFX(AUDIO.sfx_click); return true
            end
            if hitRect(state.tipDecompRect, dx, dy) then
                local gain, enhRefund = CalcDecomposeGain(item.tier, item.enhanceLv)
                state.decompConfirm = {
                    uid = item.uid, setIdx = item.setIdx, slotIdx = item.slotIdx,
                    tier = item.tier, gain = gain, enhRefund = enhRefund, enhLv = item.enhanceLv,
                }
                PlaySFX(AUDIO.sfx_click); return true
            end
            if hitRect(state.tipEnhanceRect, dx, dy) then
                local eqEnhLv = item.enhanceLv or 0
                local enhCost = ENHANCE_COST[eqEnhLv + 1] or 999
                if playerInfo.lingshi < enhCost then
                    AddFloatText(W / 2, H * 0.3, "军资不足", 1.0, {255, 100, 100}, 18)
                else
                    state.enhanceConfirm = { slotIdx = item.slotIdx, enhLv = eqEnhLv, cost = enhCost }
                end
                PlaySFX(AUDIO.sfx_click); return true
            end

        end
        state.tooltipUid = nil; PlaySFX(AUDIO.sfx_click); return true
    end

    if hitRect(state.backBtnRect, dx, dy) then
        if state.selectMode then
            state.selectMode = false; state.selectedUids = {}
        else
            EquipUI.Hide(); PopPhase("MENU"); phaseChangeCooldown = 0.3
        end
        PlaySFX(AUDIO.sfx_click); return true
    end

    if hitRect(state.filterResetRect, dx, dy) then
        state.filterSlot = 0; state.scrollY = 0
        PlaySFX(AUDIO.sfx_click); return true
    end

    if hitRect(state.batchBtnRect, dx, dy) then
        state.filterDecomp = {
            tiers = { true, true, false, false, false, false },
            maxLv = 5,
        }
        PlaySFX(AUDIO.sfx_click); return true
    end

    if hitRect(state.selectBtnRect, dx, dy) then
        state.selectMode = true; state.selectedUids = {}
        PlaySFX(AUDIO.sfx_click); return true
    end

    -- 选中模式底部操作栏
    if state.selectMode then
        if hitRect(state.selectBarCancelRect, dx, dy) then
            state.selectMode = false; state.selectedUids = {}
            PlaySFX(AUDIO.sfx_click); return true
        end
        if hitRect(state.selectBarConfirmRect, dx, dy) then
            local selCount, selGain = 0, 0
            for uid, _ in pairs(state.selectedUids) do
                local item = FindOwnedByUid(uid)
                if item and not isItemEquipped(item) then
                    selCount = selCount + 1
                    selGain = selGain + CalcDecomposeGain(item.tier, item.enhanceLv)
                end
            end
            if selCount > 0 then
                state.selectDecompConfirm = { count = selCount, gain = selGain }
            else
                AddFloatText(W / 2, H * 0.3, "请先选择要分解的宝物", 1.0, {255, 200, 100}, 18)
            end
            PlaySFX(AUDIO.sfx_click); return true
        end
        if hitRect(state.selectBarAllRect, dx, dy) then
            -- 全选所有未装备物品
            state.selectedUids = {}
            for _, itm in ipairs(playerEquipment.owned) do
                if not isItemEquipped(itm) then
                    state.selectedUids[itm.uid] = true
                end
            end
            PlaySFX(AUDIO.sfx_click); return true
        end
    end

    if hitRect(state.unlockBtnRect, dx, dy) then
        if sdk then
            sdk:ShowRewardVideoAd(SafeAdCallback(function(result)
                if result.success then
                    playerEquipment.unlockedSlots = (playerEquipment.unlockedSlots or 0) + UNLOCK_PER_AD
                    AddFloatText(W / 2, H * 0.3, "解锁+" .. UNLOCK_PER_AD .. "格子", 1.5, {120, 255, 180}, 18)
                    ReportAdWatch(); SaveGameProgress()
                end
            end))
        else
            playerEquipment.unlockedSlots = (playerEquipment.unlockedSlots or 0) + UNLOCK_PER_AD
            AddFloatText(W / 2, H * 0.3, "[DEV] 解锁+" .. UNLOCK_PER_AD .. "格子", 1.5, {120, 255, 180}, 18)
            ReportAdWatch(); SaveGameProgress()
        end
        PlaySFX(AUDIO.sfx_click); return true
    end

    for si = 1, 7 do
        if hitRect(state.slotRects[si], dx, dy) then
            if state.filterSlot == si then state.filterSlot = 0
            else state.filterSlot = si; redDotState.equipAck[si] = GetBestOwnedScoreForSlot(si)
            end
            state.scrollY = 0; PlaySFX(AUDIO.sfx_click); return true
        end
    end

    if dy >= GRID_TOP_Y and dy <= GRID_BOT_Y then
        state.isDragging = true; state.dragStartX = dx; state.dragStartY = dy
        state.dragLastY = dy; state.dragMoved = false
        state.touchDown = true; state.touchX = dx; state.touchY = dy
        state.longPressTimer = 0; return true
    end

    return false
end

-- ============================================================================
-- 触摸处理: 移动
-- ============================================================================
function EquipUI.HandleTouchMove(dx, dy)
    if not EquipUI.isVisible then return end
    if not state.isDragging then return end

    local delta = dy - state.dragLastY
    state.scrollY = state.scrollY + delta
    state.scrollVel = delta * 15
    state.dragLastY = dy

    local dist = math.abs(dy - state.dragStartY) + math.abs(dx - state.dragStartX)
    if dist > DRAG_THRESHOLD then
        state.dragMoved = true; state.touchDown = false; state.longPressTimer = 0
    end
end

-- ============================================================================
-- 触摸处理: 结束
-- ============================================================================
function EquipUI.HandleTouchEnd(dx, dy)
    if not EquipUI.isVisible then return false end
    if not state.isDragging then return false end

    state.isDragging = false; state.touchDown = false; state.longPressTimer = 0

    if not state.dragMoved then
        state.scrollVel = 0
        for _, rect in pairs(state.gridRects) do
            if rect.item and hitRect(rect, dx, dy) then
                local item = rect.item
                if rect.locked then
                    AddFloatText(W / 2, H * 0.3, "看广告解锁更多格子", 1.0, {255, 200, 100}, 18)
                elseif state.selectMode then
                    -- 选中模式：切换勾选（已装备的不可选）
                    if isItemEquipped(item) then
                        AddFloatText(W / 2, H * 0.3, "已装备，不可分解", 1.0, {255, 150, 100}, 18)
                    else
                        if state.selectedUids[item.uid] then
                            state.selectedUids[item.uid] = nil
                        else
                            state.selectedUids[item.uid] = true
                        end
                    end
                else
                    if isItemEquipped(item) then
                        state.tooltipUid = item.uid
                    else
                        playerEquipment.equipped[item.slotIdx] = item.uid
                        local pName = EQUIPMENT_SETS[item.setIdx].pieces[item.slotIdx].name
                        local tierName = EQUIP_TIERS[item.tier or 1].name
                        AddFloatText(W / 2, H * 0.4, "装备 " .. tierName .. " " .. pName, 1.0, {100, 255, 180}, 18)
                        playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                        TrackDailyTask("equip1", 1); SaveGameProgress()
                    end
                end
                PlaySFX(AUDIO.sfx_click); return true
            end
        end
    end

    state.dragStartX = 0; state.dragStartY = 0; state.dragLastY = 0; state.dragMoved = false
    return true
end

-- ============================================================================
-- 帧更新
-- ============================================================================
function EquipUI.Update(dt)
    if not EquipUI.isVisible then return end

    state.animTimer = state.animTimer + dt

    if not state.isDragging and math.abs(state.scrollVel) > 0.5 then
        state.scrollY = state.scrollY + state.scrollVel * dt
        state.scrollVel = state.scrollVel * 0.92
    else
        if not state.isDragging then state.scrollVel = 0 end
    end

    if state.touchDown then
        state.longPressTimer = state.longPressTimer + dt
        if state.longPressTimer >= LONG_PRESS_TIME then
            state.touchDown = false; state.longPressTimer = 0
            state.isDragging = false; state.dragMoved = true
            local tx, ty = state.touchX, state.touchY
            for _, rect in pairs(state.gridRects) do
                if rect.item and hitRect(rect, tx, ty) and not rect.locked then
                    state.tooltipUid = rect.item.uid; PlaySFX(AUDIO.sfx_click); break
                end
            end
            for si = 1, 7 do
                if hitRect(state.slotRects[si], tx, ty) then
                    local eqInfo = GetEquippedItem(si)
                    if eqInfo then state.tooltipUid = eqInfo.uid; PlaySFX(AUDIO.sfx_click) end
                    break
                end
            end
        end
    end
end

-- ============================================================================
-- 公开 API
-- ============================================================================
function EquipUI.Show()
    if EquipUI.isVisible then return end
    EquipUI.isVisible = true
    state.filterSlot = 0; state.scrollY = 0; state.scrollVel = 0
    state.tooltipUid = nil; state.decompConfirm = nil
    state.enhanceConfirm = nil; state.batchDecompConfirm = nil
    state.selectDecompConfirm = nil; state.filterDecomp = nil
    state.selectMode = false; state.selectedUids = {}
    state.isDragging = false; state.touchDown = false
    state.longPressTimer = 0; state.animTimer = 0

    -- 加载背景图（只加载一次）
    if not EquipUI._bgImage or EquipUI._bgImage <= 0 then
        local g = EquipUI._vg
        if g then
            EquipUI._bgImage = nvgCreateImage(g, "image/equip_bg_sanguo_20260408065550.png", 0)
        end
    end

    autoExpandLegacy()

    for si = 1, 7 do
        if HasEquipSlotRedDot(si) then
            state.filterSlot = si
            redDotState.equipAck[si] = GetBestOwnedScoreForSlot(si)
            break
        end
    end

    print("[EquipUI] Show (NanoVG grid, unlocked=" .. getUnlockedSlots() .. ")")
end

function EquipUI.Hide()
    if not EquipUI.isVisible then return end
    EquipUI.isVisible = false
    state.tooltipUid = nil; state.decompConfirm = nil
    state.enhanceConfirm = nil; state.batchDecompConfirm = nil
    state.selectDecompConfirm = nil; state.filterDecomp = nil
    state.selectMode = false; state.selectedUids = {}
    print("[EquipUI] Hide")
end

function EquipUI.MarkDirty() end

return EquipUI
