-- ============================================================================
-- systems/td/td_editor.lua - TD 路线 & 塔位可视化编辑器
-- 用途: 在2.5D背景图上手绘路径锚点 / 放置塔位, 导出坐标到控制台
-- 进入方式: 在 TD_BATTLE 或 MENU 阶段按 KEY_F5 进入
-- ============================================================================
---@diagnostic disable: undefined-global

local TDData = require("systems.td.td_data")

local M = {}

-- ============================================================================
-- 编辑器状态
-- ============================================================================

---@class TDEditorState
---@field mode string "PATH"|"SLOT"
---@field anchors table[] 路径锚点 {x,y}
---@field slots table[] 塔位 {key,x,y}
---@field dragIdx number 当前拖拽的点索引 (0=无)
---@field dragType string "anchor"|"slot"
---@field isDragging boolean
---@field smoothPath table[] 预览用平滑路径
---@field nextSlotLetter number 下一个塔位字母 (A=1, B=2...)
---@field nextSlotNum table 每个字母的下一个编号
---@field showHelp boolean 显示快捷键帮助
---@field hoverIdx number 鼠标悬停的点索引
---@field hoverType string "anchor"|"slot"
---@field btnRects table
---@field lastClickTime number 上次点击时间 (双击删除)
---@field lastClickIdx number 上次点击的点索引
---@field lastClickType string 上次点击的类型
local editorState = nil

local POINT_RADIUS   = 8
local POINT_HIT_R    = 16     -- 点击命中半径
local SLOT_RADIUS    = 12
local SNAP_DIST      = 6      -- 拖拽吸附距离
local DOUBLE_CLICK_T = 0.35   -- 双击时间窗口

-- 云端同步状态
local cloudSyncStatus = ""    -- "" | "syncing" | "synced" | "failed"
local cloudSyncTimer  = 0     -- 同步状态显示计时器

-- ============================================================================
-- Cover-fit 图片绘制
-- ============================================================================
local function DrawImageCover(imgHandle, dx, dy, dw, dh, alpha)
    if not imgHandle or imgHandle <= 0 then return end
    alpha = alpha or 1.0
    local iw, ih = nvgImageSize(vg, imgHandle)
    if not iw or iw <= 0 then return end
    local scaleX = dw / iw
    local scaleY = dh / ih
    local sc = math.max(scaleX, scaleY)
    local pw = iw * sc
    local ph = ih * sc
    local px = dx + (dw - pw) / 2
    local py = dy + (dh - ph) / 2
    local pat = nvgImagePattern(vg, px, py, pw, ph, 0, imgHandle, alpha)
    nvgBeginPath(vg)
    nvgRect(vg, dx, dy, dw, dh)
    nvgFillPaint(vg, pat)
    nvgFill(vg)
end

-- ============================================================================
-- Catmull-Rom 插值 (与 td_data.lua 一致)
-- ============================================================================
local function CatmullRomSmooth(anchors)
    if #anchors < 2 then return anchors end
    local points = {}
    local segs = 8
    for i = 1, #anchors - 1 do
        local p0 = anchors[math.max(1, i - 1)]
        local p1 = anchors[i]
        local p2 = anchors[math.min(#anchors, i + 1)]
        local p3 = anchors[math.min(#anchors, i + 2)]
        for s = 0, segs - 1 do
            local t = s / segs
            local t2 = t * t
            local t3 = t2 * t
            local px = 0.5 * ((2 * p1.x) +
                (-p0.x + p2.x) * t +
                (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
            local py = 0.5 * ((2 * p1.y) +
                (-p0.y + p2.y) * t +
                (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
            points[#points + 1] = { x = px, y = py }
        end
    end
    local last = anchors[#anchors]
    points[#points + 1] = { x = last.x, y = last.y }
    return points
end

-- ============================================================================
-- 初始化 / 退出
-- ============================================================================

--- 内部: 用当前 TDData 的数据创建编辑器状态
local function BuildEditorState()
    local anchors = {}
    for i, a in ipairs(TDData.PATH_ANCHORS) do
        anchors[i] = { x = a.x, y = a.y }
    end

    local slots = {}
    for i, s in ipairs(TDData.TOWER_SLOTS) do
        slots[i] = { key = s.key, x = s.x, y = s.y }
    end

    editorState = {
        mode = "PATH",
        anchors = anchors,
        slots = slots,
        dragIdx = 0,
        dragType = "",
        isDragging = false,
        smoothPath = CatmullRomSmooth(anchors),
        nextSlotLetter = 4,  -- D (A/B/C 已有)
        nextSlotNum = { A = 5, B = 5, C = 5, D = 1, E = 1, F = 1 },
        showHelp = false,      -- 默认关闭帮助 (移动端屏幕小)
        hoverIdx = 0,
        hoverType = "",
        selectedIdx = 0,       -- 当前选中的点索引 (触摸选中, 用于删除)
        selectedType = "",     -- "anchor"|"slot"
        btnRects = {},
        lastClickTime = 0,
        lastClickIdx = 0,
        lastClickType = "",
    }

    -- 计算已有 slot 最大编号
    for _, s in ipairs(slots) do
        local letter = s.key:sub(1, 1)
        local num = tonumber(s.key:sub(2)) or 0
        if editorState.nextSlotNum[letter] then
            editorState.nextSlotNum[letter] = math.max(editorState.nextSlotNum[letter], num + 1)
        end
    end

    print("[TD Editor] 编辑器已启动 - 路径锚点: " .. #anchors .. ", 塔位: " .. #slots)
end

function M.Init()
    -- 先尝试从云端加载最新配置
    cloudSyncStatus = "syncing"
    cloudSyncTimer = 3.0
    TDData.LoadFromCloud(function(ok, source)
        if ok then
            cloudSyncStatus = "synced"
            cloudSyncTimer = 2.0
            print("[TD Editor] 从云端加载配置成功, 刷新编辑器")
            -- 用云端数据重建编辑器状态
            BuildEditorState()
        else
            cloudSyncStatus = ""
            print("[TD Editor] 使用本地默认配置 (来源: " .. tostring(source) .. ")")
        end
    end)

    -- 立即用当前 TDData 创建编辑器 (云端回调可能覆盖)
    BuildEditorState()
end

function M.Reset()
    editorState = nil
end

function M.IsActive()
    return editorState ~= nil
end

-- ============================================================================
-- 生成新塔位 key
-- ============================================================================
local function GenerateSlotKey()
    local st = editorState
    local letters = "ABCDEFGHIJKLMNOP"
    for li = 1, #letters do
        local letter = letters:sub(li, li)
        if not st.nextSlotNum[letter] then st.nextSlotNum[letter] = 1 end
        local num = st.nextSlotNum[letter]
        if num <= 9 then
            st.nextSlotNum[letter] = num + 1
            return letter .. tostring(num)
        end
    end
    return "Z" .. tostring(math.random(1, 99))
end

-- ============================================================================
-- 重建平滑路径
-- ============================================================================
local function RebuildSmooth()
    local st = editorState
    if not st then return end
    st.smoothPath = CatmullRomSmooth(st.anchors)
end

-- ============================================================================
-- 导出坐标到控制台 (可直接粘贴到 td_data.lua)
-- ============================================================================
-- ============================================================================
-- 将编辑结果应用回 TDData (运行时生效)
-- ============================================================================
function M.ApplyToGame()
    local st = editorState
    if not st then return end

    -- 写回 PATH_ANCHORS
    TDData.PATH_ANCHORS = {}
    for i, a in ipairs(st.anchors) do
        TDData.PATH_ANCHORS[i] = { x = math.floor(a.x + 0.5), y = math.floor(a.y + 0.5) }
    end

    -- 写回 TOWER_SLOTS
    TDData.TOWER_SLOTS = {}
    for i, s in ipairs(st.slots) do
        TDData.TOWER_SLOTS[i] = { key = s.key, x = math.floor(s.x + 0.5), y = math.floor(s.y + 0.5) }
    end

    -- 如果当前有 tdState, 刷新路径和塔位
    if tdState then
        local TDLogic = require("systems.td.td_logic")
        TDLogic.InitPathData()
        print("[TD Editor] 路径和塔位已应用到游戏运行时")
    end

    -- ========== 持久化保存到 JSON 文件 (本地备份) ==========
    local cjson_m = rawget(_G, "cjson")
    if cjson_m then
        local saveObj = {
            anchors = TDData.PATH_ANCHORS,
            slots = TDData.TOWER_SLOTS,
        }
        local ok, jsonStr = pcall(cjson_m.encode, saveObj)
        if ok and jsonStr then
            local file = File("td_editor_export.json", FILE_WRITE)
            if file then
                file:WriteString(jsonStr)
                file:Close()
                print("[TD Editor] 本地备份已保存到 td_editor_export.json")
            end
        end
    end

    -- ========== 自动同步到云端 ==========
    cloudSyncStatus = "syncing"
    cloudSyncTimer = 5.0
    TDData.SaveToCloud(function(ok, reason)
        if ok then
            cloudSyncStatus = "synced"
            cloudSyncTimer = 3.0
            st.exportToast = { text = "已保存并同步到云端! 锚点:" .. #st.anchors .. " 塔位:" .. #st.slots, totalTime = 2.5, timer = 2.5 }
        else
            cloudSyncStatus = "failed"
            cloudSyncTimer = 5.0
            st.exportToast = { text = "本地已保存, 云端同步失败:" .. tostring(reason), totalTime = 3.0, timer = 3.0 }
        end
    end)

    -- 屏幕提示 (先显示保存中, 云端回调后会覆盖)
    st.exportToast = { text = "保存中, 正在同步云端...", totalTime = 3.0, timer = 3.0 }
end

function M.ExportToConsole()
    local st = editorState
    if not st then return end

    print("========== TD EDITOR: 导出坐标 ==========")
    print("")

    -- 路径锚点
    print("M.PATH_ANCHORS = {")
    for i, a in ipairs(st.anchors) do
        local comment = ""
        if i == 1 then comment = "   -- 入口"
        elseif i == #st.anchors then comment = "   -- 终点: 城堡入口"
        end
        print(string.format("    { x = %3d, y = %3d },%s",
            math.floor(a.x + 0.5), math.floor(a.y + 0.5), comment))
    end
    print("}")
    print("")

    -- 塔位
    print("M.TOWER_SLOTS = {")
    -- 按 key 排序
    local sortedSlots = {}
    for _, s in ipairs(st.slots) do sortedSlots[#sortedSlots + 1] = s end
    table.sort(sortedSlots, function(a, b) return a.key < b.key end)
    for _, s in ipairs(sortedSlots) do
        print(string.format('    { key = "%s", x = %3d, y = %3d },',
            s.key, math.floor(s.x + 0.5), math.floor(s.y + 0.5)))
    end
    print("}")

    print("")
    print("========== 导出完毕 (共 " .. #st.anchors .. " 锚点, " .. #st.slots .. " 塔位) ==========")
end

-- ============================================================================
-- 查找最近的点
-- ============================================================================
local function FindNearestPoint(px, py, maxDist)
    local st = editorState
    local bestIdx = 0
    local bestType = ""
    local bestDist = maxDist or POINT_HIT_R

    -- 根据当前模式优先搜索对应类型
    local function SearchAnchors()
        for i, a in ipairs(st.anchors) do
            local dx = px - a.x
            local dy = py - a.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < bestDist then
                bestDist = d; bestIdx = i; bestType = "anchor"
            end
        end
    end

    local function SearchSlots()
        for i, s in ipairs(st.slots) do
            local dx = px - s.x
            local dy = py - s.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < bestDist then
                bestDist = d; bestIdx = i; bestType = "slot"
            end
        end
    end

    if st.mode == "PATH" then
        SearchAnchors()
        SearchSlots()  -- 也能选中塔位
    else
        SearchSlots()
        SearchAnchors()  -- 也能选中锚点
    end

    return bestIdx, bestType, bestDist
end

-- ============================================================================
-- 渲染
-- ============================================================================

function M.Draw()
    local st = editorState
    if not st then return end

    local DW = TDData.DESIGN_W
    local DH = TDData.DESIGN_H

    -- 云端同步状态计时器衰减 (使用帧间隔近似)
    if cloudSyncTimer > 0 then
        cloudSyncTimer = cloudSyncTimer - 0.016  -- ~60fps 近似
        if cloudSyncTimer <= 0 then
            cloudSyncTimer = 0
            if cloudSyncStatus == "synced" then
                cloudSyncStatus = ""  -- 淡出"已同步"状态
            end
        end
    end

    -- ① 背景图
    local bgImg = IMG and IMG.tdMapBg
    if bgImg and bgImg > 0 then
        DrawImageCover(bgImg, 0, 0, DW, DH, 1.0)
    else
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, DW, DH)
        nvgFillColor(vg, nvgRGBA(40, 50, 45, 255))
        nvgFill(vg)
    end

    -- ② 平滑路径预览线 (半透明黄色)
    if st.smoothPath and #st.smoothPath >= 2 then
        nvgBeginPath(vg)
        nvgMoveTo(vg, st.smoothPath[1].x, st.smoothPath[1].y)
        for i = 2, #st.smoothPath do
            nvgLineTo(vg, st.smoothPath[i].x, st.smoothPath[i].y)
        end
        nvgStrokeColor(vg, nvgRGBA(255, 220, 80, 120))
        nvgStrokeWidth(vg, 3)
        nvgStroke(vg)
    end

    -- ③ 锚点之间的直线连接 (虚线效果: 细淡线)
    if #st.anchors >= 2 then
        nvgBeginPath(vg)
        nvgMoveTo(vg, st.anchors[1].x, st.anchors[1].y)
        for i = 2, #st.anchors do
            nvgLineTo(vg, st.anchors[i].x, st.anchors[i].y)
        end
        nvgStrokeColor(vg, nvgRGBA(255, 100, 80, 80))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
    end

    -- ④ 路径锚点 (红色圆点, 选中高亮)
    for i, a in ipairs(st.anchors) do
        local isHover = (st.hoverIdx == i and st.hoverType == "anchor")
        local isDrag = (st.dragIdx == i and st.dragType == "anchor")
        local isSelected = (st.selectedIdx == i and st.selectedType == "anchor")
        local r = (isHover or isDrag or isSelected) and (POINT_RADIUS + 3) or POINT_RADIUS

        -- 选中光晕
        if isSelected then
            nvgBeginPath(vg)
            nvgCircle(vg, a.x, a.y, r + 6)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 100, 180))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        end

        -- 外圈
        nvgBeginPath(vg)
        nvgCircle(vg, a.x, a.y, r)
        nvgFillColor(vg, nvgRGBA(255, 60, 40, (isDrag or isSelected) and 220 or 160))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgCircle(vg, a.x, a.y, r)
        nvgStrokeColor(vg, isSelected and nvgRGBA(255, 255, 100, 255) or nvgRGBA(255, 255, 255, 200))
        nvgStrokeWidth(vg, isSelected and 2 or 1.5)
        nvgStroke(vg)

        -- 序号
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
        nvgText(vg, a.x, a.y, tostring(i))
    end

    -- ⑤ 塔位 (绿色菱形, 选中高亮)
    for i, s in ipairs(st.slots) do
        local isHover = (st.hoverIdx == i and st.hoverType == "slot")
        local isDrag = (st.dragIdx == i and st.dragType == "slot")
        local isSelected = (st.selectedIdx == i and st.selectedType == "slot")
        local r = (isHover or isDrag or isSelected) and (SLOT_RADIUS + 3) or SLOT_RADIUS

        -- 选中光晕
        if isSelected then
            nvgBeginPath(vg)
            nvgCircle(vg, s.x, s.y, r + 6)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 100, 180))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        end

        -- 菱形
        nvgBeginPath(vg)
        nvgMoveTo(vg, s.x, s.y - r)
        nvgLineTo(vg, s.x + r, s.y)
        nvgLineTo(vg, s.x, s.y + r)
        nvgLineTo(vg, s.x - r, s.y)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(40, 200, 80, (isDrag or isSelected) and 220 or 160))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgMoveTo(vg, s.x, s.y - r)
        nvgLineTo(vg, s.x + r, s.y)
        nvgLineTo(vg, s.x, s.y + r)
        nvgLineTo(vg, s.x - r, s.y)
        nvgClosePath(vg)
        nvgStrokeColor(vg, isSelected and nvgRGBA(255, 255, 100, 255) or nvgRGBA(255, 255, 255, 200))
        nvgStrokeWidth(vg, isSelected and 2 or 1.5)
        nvgStroke(vg)

        -- key 标签
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
        nvgText(vg, s.x, s.y, s.key)
    end

    -- ⑥ 鼠标坐标显示
    if st.mouseX then
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
        nvgText(vg, st.mouseX + 16, st.mouseY - 10,
            string.format("(%d, %d)", math.floor(st.mouseX + 0.5), math.floor(st.mouseY + 0.5)))
    end

    -- ⑦ 顶部工具栏
    M.DrawToolbar()

    -- ⑧ 帮助面板
    if st.showHelp then
        M.DrawHelp()
    end

    -- ⑨ 导出成功提示 (Toast) - 用 os.clock 计算时间
    if st.exportToast then
        local now = os.clock()
        if not st.exportToast.startTime then
            st.exportToast.startTime = now
        end
        st.exportToast.timer = st.exportToast.totalTime - (now - st.exportToast.startTime)
        if st.exportToast.timer <= 0 then
            st.exportToast = nil
        end
    end
    if st.exportToast and st.exportToast.timer > 0 then
        local toast = st.exportToast
        local alpha = math.min(1, toast.timer / 0.3) * 255
        local tw = 300
        local th = 40
        local tx = DW / 2 - tw / 2
        local ty = DH / 2 - th / 2

        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, ty, tw, th, 8)
        nvgFillColor(vg, nvgRGBA(40, 140, 60, math.floor(220 * alpha / 255)))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, ty, tw, th, 8)
        nvgStrokeColor(vg, nvgRGBA(120, 255, 120, math.floor(180 * alpha / 255)))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 16)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(alpha)))
            nvgText(vg, DW / 2, DH / 2, toast.text, nil)
        end
    end
end

-- ============================================================================
-- 工具栏
-- ============================================================================
-- 工具栏起始 Y (在 GM 面板 tab 栏下方)
local TOOLBAR_Y = 38
local TOOLBAR_H = 32

function M.DrawToolbar()
    local st = editorState
    local DW = TDData.DESIGN_W

    -- 半透明背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, TOOLBAR_Y, DW, TOOLBAR_H)
    nvgFillColor(vg, nvgRGBA(20, 18, 15, 200))
    nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())
    st.btnRects = {}

    local by = TOOLBAR_Y + 4
    local bh = 24

    -- 模式切换: PATH / SLOT
    local modes = { "PATH", "SLOT" }
    local modeLabels = { "路径锚点", "塔位编辑" }
    local mx = 8
    for mi, modeStr in ipairs(modes) do
        local bw = 80
        local isActive = st.mode == modeStr

        nvgBeginPath(vg)
        nvgRoundedRect(vg, mx, by, bw, bh, 4)
        nvgFillColor(vg, isActive and nvgRGBA(200, 160, 60, 200) or nvgRGBA(60, 55, 45, 180))
        nvgFill(vg)

        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(255, 255, 255, 255) or nvgRGBA(180, 170, 150, 200))
        nvgText(vg, mx + bw / 2, by + bh / 2, modeLabels[mi])

        st.btnRects["mode_" .. modeStr] = { x = mx, y = by, w = bw, h = bh }
        mx = mx + bw + 6
    end

    -- 分隔
    mx = mx + 8

    -- 撤销按钮 (移动端替代 Z 键)
    local undoW = 50
    nvgBeginPath(vg)
    nvgRoundedRect(vg, mx, by, undoW, bh, 4)
    nvgFillColor(vg, nvgRGBA(100, 90, 50, 200))
    nvgFill(vg)
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, mx + undoW / 2, by + bh / 2, "撤销")
    st.btnRects.undo = { x = mx, y = by, w = undoW, h = bh }
    mx = mx + undoW + 6

    -- 删除选中按钮 (移动端替代双击删除)
    local delW = 50
    local hasSelection = (st.selectedIdx > 0)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, mx, by, delW, bh, 4)
    nvgFillColor(vg, hasSelection and nvgRGBA(200, 60, 40, 200) or nvgRGBA(80, 40, 35, 120))
    nvgFill(vg)
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, hasSelection and 255 or 100))
    nvgText(vg, mx + delW / 2, by + bh / 2, "删除")
    st.btnRects.delete = { x = mx, y = by, w = delW, h = bh }
    mx = mx + delW + 6

    -- 保存按钮 (保存到运行时 + 云端同步)
    local expW = 60
    local saveBgR, saveBgG, saveBgB = 60, 120, 180
    if cloudSyncStatus == "syncing" then
        saveBgR, saveBgG, saveBgB = 180, 160, 40
    elseif cloudSyncStatus == "synced" then
        saveBgR, saveBgG, saveBgB = 40, 160, 80
    elseif cloudSyncStatus == "failed" then
        saveBgR, saveBgG, saveBgB = 180, 60, 40
    end
    nvgBeginPath(vg)
    nvgRoundedRect(vg, mx, by, expW, bh, 4)
    nvgFillColor(vg, nvgRGBA(saveBgR, saveBgG, saveBgB, 200))
    nvgFill(vg)
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    local saveLabel = "保存"
    if cloudSyncStatus == "syncing" then saveLabel = "同步中"
    elseif cloudSyncStatus == "synced" then saveLabel = "已同步"
    elseif cloudSyncStatus == "failed" then saveLabel = "重试"
    end
    nvgText(vg, mx + expW / 2, by + bh / 2, saveLabel)
    st.btnRects.export = { x = mx, y = by, w = expW, h = bh }
    mx = mx + expW + 6

    -- 清空按钮
    local clrW = 50
    nvgBeginPath(vg)
    nvgRoundedRect(vg, mx, by, clrW, bh, 4)
    nvgFillColor(vg, nvgRGBA(180, 60, 50, 200))
    nvgFill(vg)
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, mx + clrW / 2, by + bh / 2, "清空")
    st.btnRects.clear = { x = mx, y = by, w = clrW, h = bh }
    mx = mx + clrW + 6

    -- 帮助切换
    local helpW = 30
    nvgBeginPath(vg)
    nvgRoundedRect(vg, mx, by, helpW, bh, 4)
    nvgFillColor(vg, nvgRGBA(80, 80, 80, 180))
    nvgFill(vg)
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgText(vg, mx + helpW / 2, by + bh / 2, "?")
    st.btnRects.help = { x = mx, y = by, w = helpW, h = bh }
    mx = mx + helpW + 6

    -- 返回按钮 (右侧)
    local backW = 50
    local backX = DW - backW - 8
    nvgBeginPath(vg)
    nvgRoundedRect(vg, backX, by, backW, bh, 4)
    nvgFillColor(vg, nvgRGBA(120, 50, 50, 200))
    nvgFill(vg)
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, backX + backW / 2, by + bh / 2, "返回")
    st.btnRects.back = { x = backX, y = by, w = backW, h = bh }

    -- 状态信息
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 180, 160, 180))
    nvgText(vg, backX - 12, by + bh / 2,
        "锚点:" .. #st.anchors .. "  塔位:" .. #st.slots)
end

-- ============================================================================
-- 帮助面板
-- ============================================================================
function M.DrawHelp()
    local st = editorState
    local DW = TDData.DESIGN_W
    local DH = TDData.DESIGN_H

    local pw = 260
    local ph = 190
    local px = DW - pw - 12
    local py = TOOLBAR_Y + TOOLBAR_H + 6

    -- 半透明背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 6)
    nvgFillColor(vg, nvgRGBA(15, 12, 10, 220))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 6)
    nvgStrokeColor(vg, nvgRGBA(120, 110, 90, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())
    local lx = px + 12
    local ly = py + 14
    local lineH = 19

    local function HelpLine(text, col)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, col or nvgRGBA(220, 210, 190, 230))
        nvgText(vg, lx, ly, text)
        ly = ly + lineH
    end

    HelpLine("触摸操作指南:", nvgRGBA(255, 220, 100, 255))
    ly = ly + 2
    HelpLine("点击空白    添加锚点/塔位")
    HelpLine("点击已有点  选中 (黄色高亮)")
    HelpLine("拖拽点      移动位置")
    HelpLine("[撤销]按钮  撤销最后添加的点")
    HelpLine("[删除]按钮  删除选中的点")
    HelpLine("[保存]按钮  应用到游戏+同步云端")
    ly = ly + 4
    HelpLine("红色圆点 = 路径锚点 (敌人行军路线)")
    HelpLine("绿色菱形 = 塔位 (放置武将)")
    HelpLine("编辑自动云端同步, 重启后生效", nvgRGBA(100, 200, 255, 200))
end

-- ============================================================================
-- 输入: 鼠标/触摸按下
-- ============================================================================
function M.handlePress(sx, sy)
    local st = editorState
    if not st then return end

    local dx, dy = ScreenToDesign(sx, sy)
    local now = os.clock()

    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    -- 工具栏按钮
    if HitRect(st.btnRects.mode_PATH) then
        st.mode = "PATH"; return
    end
    if HitRect(st.btnRects.mode_SLOT) then
        st.mode = "SLOT"; return
    end
    if HitRect(st.btnRects.export) then
        M.ApplyToGame()
        M.ExportToConsole()
        return
    end
    if HitRect(st.btnRects.undo) then
        -- 撤销最后一个点 (移动端替代 Z 键)
        if st.mode == "PATH" and #st.anchors > 0 then
            table.remove(st.anchors)
            RebuildSmooth()
            st.selectedIdx = 0; st.selectedType = ""
            print("[TD Editor] 撤销最后一个锚点")
        elseif st.mode == "SLOT" and #st.slots > 0 then
            table.remove(st.slots)
            st.selectedIdx = 0; st.selectedType = ""
            print("[TD Editor] 撤销最后一个塔位")
        end
        return
    end
    if HitRect(st.btnRects.delete) then
        -- 删除选中的点 (移动端替代双击删除)
        if st.selectedIdx > 0 then
            if st.selectedType == "anchor" and st.selectedIdx <= #st.anchors then
                print("[TD Editor] 删除锚点 #" .. st.selectedIdx)
                table.remove(st.anchors, st.selectedIdx)
                RebuildSmooth()
            elseif st.selectedType == "slot" and st.selectedIdx <= #st.slots then
                print("[TD Editor] 删除塔位 " .. st.slots[st.selectedIdx].key)
                table.remove(st.slots, st.selectedIdx)
            end
            st.selectedIdx = 0; st.selectedType = ""
        end
        return
    end
    if HitRect(st.btnRects.clear) then
        if st.mode == "PATH" then
            st.anchors = {}
            RebuildSmooth()
            print("[TD Editor] 路径锚点已清空")
        else
            st.slots = {}
            print("[TD Editor] 塔位已清空")
        end
        st.selectedIdx = 0; st.selectedType = ""
        return
    end
    if HitRect(st.btnRects.help) then
        st.showHelp = not st.showHelp; return
    end
    if HitRect(st.btnRects.back) then
        -- 通过GM面板统一关闭 (Apply + Reset + 恢复phase)
        local GMPanel = require("ui.gm_panel")
        if GMPanel.IsActive() then
            GMPanel.Close()
        else
            -- 兼容: 直接打开编辑器的旧路径
            M.ApplyToGame()
            M.ExportToConsole()
            M.Reset()
            gameState.phase = tdState and "TD_BATTLE" or "MENU"
        end
        return
    end

    -- 忽略工具栏区域 (tab栏 + 编辑器工具栏)
    if dy < TOOLBAR_Y + TOOLBAR_H then return end

    -- 查找最近的点
    local idx, ptype, dist = FindNearestPoint(dx, dy, POINT_HIT_R)

    if idx > 0 then
        -- 触摸选中: 点击已有点 → 选中(或取消) + 开始拖拽
        if st.selectedIdx == idx and st.selectedType == ptype then
            -- 再次点击同一个已选中的点 → 取消选中
            st.selectedIdx = 0
            st.selectedType = ""
        else
            -- 选中该点
            st.selectedIdx = idx
            st.selectedType = ptype
        end

        -- 同时开始拖拽 (移动该点)
        st.dragIdx = idx
        st.dragType = ptype
        st.isDragging = true
        st.lastClickTime = now
        st.lastClickIdx = idx
        st.lastClickType = ptype
    else
        -- 点击空白: 添加新点
        st.lastClickTime = 0
        if st.mode == "PATH" then
            -- 插入锚点 (在最近的两点之间, 或追加到末尾)
            local insertAt = #st.anchors + 1

            -- 如果点击位置靠近某两个相邻锚点之间的线段, 插入到中间
            if #st.anchors >= 2 then
                local bestSegDist = 30  -- 线段吸附距离
                for i = 1, #st.anchors - 1 do
                    local a = st.anchors[i]
                    local b = st.anchors[i + 1]
                    -- 点到线段的距离
                    local abx = b.x - a.x
                    local aby = b.y - a.y
                    local abLen2 = abx * abx + aby * aby
                    if abLen2 > 0 then
                        local t = math.max(0, math.min(1,
                            ((dx - a.x) * abx + (dy - a.y) * aby) / abLen2))
                        local projX = a.x + t * abx
                        local projY = a.y + t * aby
                        local segDist = math.sqrt((dx - projX)^2 + (dy - projY)^2)
                        if segDist < bestSegDist then
                            bestSegDist = segDist
                            insertAt = i + 1
                        end
                    end
                end
            end

            table.insert(st.anchors, insertAt, { x = dx, y = dy })
            RebuildSmooth()
            print(string.format("[TD Editor] 添加锚点 #%d at (%d, %d)",
                insertAt, math.floor(dx), math.floor(dy)))
        else
            -- 添加塔位
            local key = GenerateSlotKey()
            st.slots[#st.slots + 1] = { key = key, x = dx, y = dy }
            print(string.format('[TD Editor] 添加塔位 "%s" at (%d, %d)',
                key, math.floor(dx), math.floor(dy)))
        end
    end
end

-- ============================================================================
-- 输入: 鼠标/触摸移动
-- ============================================================================
function M.handleMove(sx, sy)
    local st = editorState
    if not st then return end

    local dx, dy = ScreenToDesign(sx, sy)
    st.mouseX = dx
    st.mouseY = dy

    if st.isDragging and st.dragIdx > 0 then
        -- clamp 到地图区域 (工具栏下方)
        dx = math.max(0, math.min(TDData.DESIGN_W, dx))
        dy = math.max(TOOLBAR_Y + TOOLBAR_H, math.min(TDData.DESIGN_H, dy))

        if st.dragType == "anchor" then
            st.anchors[st.dragIdx].x = dx
            st.anchors[st.dragIdx].y = dy
            RebuildSmooth()
        elseif st.dragType == "slot" then
            st.slots[st.dragIdx].x = dx
            st.slots[st.dragIdx].y = dy
        end
    else
        -- 悬停检测
        local idx, ptype = FindNearestPoint(dx, dy, POINT_HIT_R)
        st.hoverIdx = idx
        st.hoverType = ptype
    end
end

-- ============================================================================
-- 输入: 鼠标/触摸松开
-- ============================================================================
function M.handleEndPress(sx, sy)
    local st = editorState
    if not st then return end

    if st.isDragging then
        st.isDragging = false
        st.dragIdx = 0
        st.dragType = ""
        RebuildSmooth()
    end
end

-- ============================================================================
-- 键盘快捷键
-- ============================================================================
function M.handleKeyDown(key)
    local st = editorState
    if not st then return false end

    if key == KEY_ESCAPE then
        -- 通过GM面板统一关闭
        local GMPanel = require("ui.gm_panel")
        if GMPanel.IsActive() then
            GMPanel.Close()
        else
            M.ApplyToGame()
            M.ExportToConsole()
            M.Reset()
            gameState.phase = tdState and "TD_BATTLE" or "MENU"
        end
        return true
    end

    if key == KEY_TAB then
        st.mode = (st.mode == "PATH") and "SLOT" or "PATH"
        print("[TD Editor] 切换到 " .. st.mode .. " 模式")
        return true
    end

    if key == KEY_F5 then
        M.ExportToConsole()
        return true
    end

    -- Ctrl+Z 撤销最后一个点 (简易版)
    if key == KEY_Z then
        if st.mode == "PATH" and #st.anchors > 0 then
            table.remove(st.anchors)
            RebuildSmooth()
            print("[TD Editor] 撤销最后一个锚点")
        elseif st.mode == "SLOT" and #st.slots > 0 then
            table.remove(st.slots)
            print("[TD Editor] 撤销最后一个塔位")
        end
        return true
    end

    return false
end

return M
