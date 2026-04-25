-- ============================================================================
-- ui/gm_panel.lua - GM面板 (统一管理入口)
-- 功能: tab切换 "路线编辑器" 和 "管理工具"
-- 管理工具: 玩家封禁/解禁、邮件派发/广播、排行榜隐藏/恢复
-- 触发: 任意位置逆时针画2圈手势 (gm_gesture.lua)
-- ============================================================================
---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 状态
-- ============================================================================
local panelState = {
    active    = false,
    tab       = "editor",   -- "editor" | "admin"
    prevPhase = "MENU",     -- 打开前的 phase, 关闭时恢复
}

-- Tab 定义
local TABS = {
    { id = "editor", label = "路线编辑器" },
    { id = "admin",  label = "管理工具"   },
}

-- ============================================================================
-- 管理面板状态
-- ============================================================================
local adminState = {
    subTab    = "ban",      -- "ban" | "mail" | "rank"
    -- 输入字段
    uidInput  = "",         -- UID 输入框
    inputFocused = "",      -- 当前聚焦的输入框 ID: "uid" | "subject" | "body" | ""
    -- 邮件
    mailSubject = "",
    mailBody    = "",
    mailType    = "single", -- "single" | "broadcast"
    -- 封禁列表 (从服务端获取)
    banList     = nil,      -- { tempBans={}, permBans={} }
    banLoading  = false,
    -- 反馈提示
    toast       = nil,      -- { text="...", expire=time, color={r,g,b} }
    -- 按钮矩形缓存
    btnRects    = {},
}

-- 子 Tab 定义
local SUB_TABS = {
    { id = "ban",  label = "封禁管理" },
    { id = "mail", label = "邮件派发" },
    { id = "rank", label = "排行榜"   },
}

-- ============================================================================
-- 工具函数
-- ============================================================================

local function showToast(text, color, duration)
    adminState.toast = {
        text = text,
        expire = os.time() + (duration or 3),
        color = color or { 200, 220, 255 },
    }
end

local function drawButton(x, y, w, h, label, opts)
    opts = opts or {}
    local bgColor = opts.bg or { 50, 60, 80, 220 }
    local borderColor = opts.border or { 80, 120, 180, 180 }
    local textColor = opts.text or { 220, 230, 255, 255 }
    local fontSize = opts.fontSize or 13
    local radius = opts.radius or 6

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, radius)
    nvgFillColor(vg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 220))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, radius)
    nvgStrokeColor(vg, nvgRGBA(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 180))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, fontSize)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4] or 255))
    nvgText(vg, x + w / 2, y + h / 2, label)

    return { x = x, y = y, w = w, h = h }
end

local function drawInputBox(x, y, w, h, value, placeholder, focusId)
    local isFocused = (adminState.inputFocused == focusId)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 4)
    nvgFillColor(vg, nvgRGBA(15, 15, 25, 240))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 4)
    if isFocused then
        nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 220))
        nvgStrokeWidth(vg, 1.5)
    else
        nvgStrokeColor(vg, nvgRGBA(60, 70, 90, 180))
        nvgStrokeWidth(vg, 1)
    end
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    local displayText = value
    if (not displayText or displayText == "") and not isFocused then
        nvgFillColor(vg, nvgRGBA(100, 100, 120, 140))
        displayText = placeholder or ""
    else
        nvgFillColor(vg, nvgRGBA(220, 230, 255, 240))
        -- 显示光标
        if isFocused then
            displayText = (displayText or "") .. "|"
        end
    end
    nvgText(vg, x + 6, y + h / 2, displayText)

    return { x = x, y = y, w = w, h = h, focusId = focusId }
end

local function hitTest(rect, px, py)
    if not rect then return false end
    return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

-- ============================================================================
-- 生命周期
-- ============================================================================

function M.Open()
    panelState.prevPhase = gameState.phase or "MENU"
    panelState.active = true
    panelState.tab = "editor"

    -- 初始化路线编辑器
    local TDEditor = require("systems.td.td_editor")
    TDEditor.Init()

    print("[GM Panel] 已打开 (手势触发, 来自: " .. panelState.prevPhase .. ")")
end

function M.Close()
    -- 如果当前是编辑器tab, 应用编辑结果并重置
    if panelState.tab == "editor" then
        local TDEditor = require("systems.td.td_editor")
        if TDEditor.IsActive() then
            TDEditor.ApplyToGame()
            TDEditor.ExportToConsole()
            TDEditor.Reset()
        end
    end

    -- 清除输入焦点
    adminState.inputFocused = ""

    panelState.active = false

    -- 恢复之前的 phase
    gameState.phase = panelState.prevPhase or "MENU"
    print("[GM Panel] 已关闭, 恢复到: " .. gameState.phase)
end

function M.IsActive()
    return panelState.active
end

function M.GetTab()
    return panelState.tab
end

-- ============================================================================
-- 绘制
-- ============================================================================

-- GM 面板 tab 栏高度 (编辑器工具栏需要在此之下)
M.TAB_BAR_HEIGHT = 38

function M.Draw()
    if not panelState.active then return end

    local DW = DESIGN_W or 1024
    local DH = DESIGN_H or 571

    -- ① 先绘制内容区 (编辑器或管理工具)
    if panelState.tab == "editor" then
        local TDEditor = require("systems.td.td_editor")
        if not TDEditor.IsActive() then TDEditor.Init() end
        TDEditor.Draw()
    elseif panelState.tab == "admin" then
        M.DrawAdminTab()
    end

    -- ② 再绘制 tab 栏 (最上层, 不会被编辑器背景覆盖)
    local tabH = 34
    local tabW = 120
    local tabY = 2
    local tabStartX = DW / 2 - (#TABS * tabW) / 2

    -- tab 栏底色条
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, DW, M.TAB_BAR_HEIGHT)
    nvgFillColor(vg, nvgRGBA(15, 15, 20, 220))
    nvgFill(vg)

    for i, tab in ipairs(TABS) do
        local tx = tabStartX + (i - 1) * tabW
        local isActive = (panelState.tab == tab.id)

        -- Tab 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, tabW - 4, tabH, 6)
        if isActive then
            nvgFillColor(vg, nvgRGBA(60, 120, 200, 230))
        else
            nvgFillColor(vg, nvgRGBA(40, 40, 50, 180))
        end
        nvgFill(vg)

        -- Tab 边框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, tabW - 4, tabH, 6)
        nvgStrokeColor(vg, nvgRGBA(100, 140, 200, isActive and 255 or 100))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        -- Tab 文字
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, isActive and 255 or 160))
        nvgText(vg, tx + (tabW - 4) / 2, tabY + tabH / 2, tab.label)
    end

    -- 关闭按钮 (右上角)
    local closeX = DW - 30
    local closeY = tabY + tabH / 2
    local closeR = 14
    nvgBeginPath(vg)
    nvgCircle(vg, closeX, closeY, closeR)
    nvgFillColor(vg, nvgRGBA(200, 60, 60, 200))
    nvgFill(vg)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeX, closeY, "X")
end

-- ============================================================================
-- 管理工具 Tab (完整重写: 封禁/邮件/排行榜)
-- ============================================================================

function M.DrawAdminTab()
    local DW = DESIGN_W or 1024
    local DH = DESIGN_H or 571
    local topY = M.TAB_BAR_HEIGHT
    local contentH = DH - topY

    -- 管理工具区域背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, topY, DW, contentH)
    nvgFillColor(vg, nvgRGBA(20, 20, 30, 230))
    nvgFill(vg)

    -- 清空按钮矩形缓存
    adminState.btnRects = {}

    -- ============ 子 Tab 栏 ============
    local subTabH = 28
    local subTabW = 90
    local subTabY = topY + 4
    local subTabStartX = 10

    for i, st in ipairs(SUB_TABS) do
        local sx = subTabStartX + (i - 1) * (subTabW + 4)
        local isActive = (adminState.subTab == st.id)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, sx, subTabY, subTabW, subTabH, 5)
        if isActive then
            nvgFillColor(vg, nvgRGBA(50, 100, 170, 220))
        else
            nvgFillColor(vg, nvgRGBA(35, 35, 45, 200))
        end
        nvgFill(vg)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, sx, subTabY, subTabW, subTabH, 5)
        nvgStrokeColor(vg, nvgRGBA(80, 120, 180, isActive and 200 or 80))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 230, 255, isActive and 255 or 140))
        nvgText(vg, sx + subTabW / 2, subTabY + subTabH / 2, st.label)

        adminState.btnRects["subtab_" .. st.id] = { x = sx, y = subTabY, w = subTabW, h = subTabH }
    end

    -- 内容区起始 Y
    local bodyY = subTabY + subTabH + 8

    -- ============ 绘制子 Tab 内容 ============
    if adminState.subTab == "ban" then
        M.DrawBanTab(DW, DH, bodyY)
    elseif adminState.subTab == "mail" then
        M.DrawMailTab(DW, DH, bodyY)
    elseif adminState.subTab == "rank" then
        M.DrawRankTab(DW, DH, bodyY)
    end

    -- ============ Toast 提示 ============
    if adminState.toast and os.time() <= adminState.toast.expire then
        local t = adminState.toast
        local tw = 300
        local th = 32
        local tx = DW / 2 - tw / 2
        local ty = DH - 50

        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, ty, tw, th, 8)
        nvgFillColor(vg, nvgRGBA(t.color[1], t.color[2], t.color[3], 220))
        nvgFill(vg)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
        nvgText(vg, tx + tw / 2, ty + th / 2, t.text)
    elseif adminState.toast then
        adminState.toast = nil
    end
end

-- ============================================================================
-- 封禁管理子 Tab
-- ============================================================================

function M.DrawBanTab(DW, DH, bodyY)
    local pad = 12
    local leftCol = DW * 0.45   -- 左列宽度 (操作区)
    local rightX = leftCol + 10 -- 右列起始

    -- ---- 左列: 操作区 ----
    local ly = bodyY

    -- UID 输入
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 170, 190, 200))
    nvgText(vg, pad, ly + 8, "目标玩家 UID:")
    ly = ly + 18
    adminState.btnRects["input_uid"] = drawInputBox(pad, ly, leftCol - pad * 2, 26, adminState.uidInput, "输入 UID...", "uid")
    ly = ly + 34

    -- 操作按钮
    local btnW = (leftCol - pad * 2 - 6) / 2
    local btnH = 30

    adminState.btnRects["btn_perm_ban"] = drawButton(pad, ly, btnW, btnH, "永久封禁", {
        bg = { 160, 40, 40, 220 }, border = { 200, 80, 80, 180 }, text = { 255, 200, 200, 255 }
    })
    adminState.btnRects["btn_full_unban"] = drawButton(pad + btnW + 6, ly, btnW, btnH, "完全解禁", {
        bg = { 40, 120, 60, 220 }, border = { 80, 180, 100, 180 }, text = { 200, 255, 210, 255 }
    })
    ly = ly + btnH + 6

    adminState.btnRects["btn_hide_rank"] = drawButton(pad, ly, btnW, btnH, "隐藏排行", {
        bg = { 120, 90, 30, 220 }, border = { 180, 140, 60, 180 }
    })
    adminState.btnRects["btn_unhide_rank"] = drawButton(pad + btnW + 6, ly, btnW, btnH, "恢复排行", {
        bg = { 40, 80, 120, 220 }, border = { 80, 130, 180, 180 }
    })
    ly = ly + btnH + 10

    -- 刷新封禁列表按钮
    adminState.btnRects["btn_refresh_bans"] = drawButton(pad, ly, leftCol - pad * 2, 28, adminState.banLoading and "加载中..." or "刷新封禁列表", {
        bg = { 40, 50, 70, 220 }, border = { 70, 100, 150, 180 }
    })

    -- ---- 右列: 封禁列表 ----
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 170, 190, 200))
    nvgText(vg, rightX, bodyY + 8, "当前封禁名单:")

    local listY = bodyY + 20
    local listH = DH - listY - 10
    local listW = DW - rightX - pad

    -- 列表背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, rightX, listY, listW, listH, 4)
    nvgFillColor(vg, nvgRGBA(12, 12, 20, 200))
    nvgFill(vg)

    nvgSave(vg)
    nvgScissor(vg, rightX, listY, listW, listH)

    if adminState.banList then
        local itemH = 22
        local iy = listY + 4
        local allBans = {}
        for _, b in ipairs(adminState.banList.permBans or {}) do
            allBans[#allBans + 1] = b
        end
        for _, b in ipairs(adminState.banList.tempBans or {}) do
            allBans[#allBans + 1] = b
        end

        if #allBans == 0 then
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(100, 100, 120, 140))
            nvgText(vg, rightX + listW / 2, listY + listH / 2, "暂无封禁记录")
        else
            for _, ban in ipairs(allBans) do
                local statusStr = ban.permanent and "[永封]" or ("[Lv" .. tostring(ban.level or 0) .. "]")
                local rankStr = ban.rankHidden and " [隐榜]" or ""
                local line = statusStr .. " UID:" .. tostring(ban.uid) .. rankStr
                if ban.reason and ban.reason ~= "" then
                    line = line .. " - " .. ban.reason
                end

                nvgFontFace(vg, "sans")
                nvgFontSize(vg, 11)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if ban.permanent then
                    nvgFillColor(vg, nvgRGBA(255, 120, 120, 220))
                else
                    nvgFillColor(vg, nvgRGBA(200, 200, 220, 200))
                end
                nvgText(vg, rightX + 6, iy + itemH / 2, line)
                iy = iy + itemH
                if iy > listY + listH then break end
            end
        end
    else
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 100, 120, 140))
        nvgText(vg, rightX + listW / 2, listY + listH / 2, "点击「刷新」加载封禁列表")
    end

    nvgRestore(vg)
end

-- ============================================================================
-- 邮件派发子 Tab
-- ============================================================================

function M.DrawMailTab(DW, DH, bodyY)
    local pad = 12
    local ly = bodyY

    -- 邮件类型切换
    local typeBtnW = 90
    local typeBtnH = 26

    adminState.btnRects["btn_mail_single"] = drawButton(pad, ly, typeBtnW, typeBtnH,
        "单人发送", {
            bg = adminState.mailType == "single" and { 50, 100, 170, 220 } or { 35, 35, 45, 200 },
            border = { 80, 130, 200, adminState.mailType == "single" and 200 or 80 },
        })
    adminState.btnRects["btn_mail_broadcast"] = drawButton(pad + typeBtnW + 6, ly, typeBtnW, typeBtnH,
        "全服广播", {
            bg = adminState.mailType == "broadcast" and { 50, 100, 170, 220 } or { 35, 35, 45, 200 },
            border = { 80, 130, 200, adminState.mailType == "broadcast" and 200 or 80 },
        })
    ly = ly + typeBtnH + 8

    -- UID 输入 (仅单人发送)
    if adminState.mailType == "single" then
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 170, 190, 200))
        nvgText(vg, pad, ly + 8, "收件人 UID:")
        ly = ly + 18
        adminState.btnRects["input_uid"] = drawInputBox(pad, ly, DW / 2 - pad, 26, adminState.uidInput, "输入目标 UID...", "uid")
        ly = ly + 34
    end

    -- 邮件标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 170, 190, 200))
    nvgText(vg, pad, ly + 8, "邮件标题:")
    ly = ly + 18
    adminState.btnRects["input_subject"] = drawInputBox(pad, ly, DW - pad * 2, 26, adminState.mailSubject, "输入标题...", "subject")
    ly = ly + 34

    -- 邮件正文
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 170, 190, 200))
    nvgText(vg, pad, ly + 8, "邮件正文:")
    ly = ly + 18

    -- 正文多行框 (使用较高的输入框)
    local bodyH = math.min(80, DH - ly - 50)
    adminState.btnRects["input_body"] = drawInputBox(pad, ly, DW - pad * 2, bodyH, adminState.mailBody, "输入正文内容...", "body")
    ly = ly + bodyH + 10

    -- 发送按钮
    local sendW = 140
    adminState.btnRects["btn_send_mail"] = drawButton(DW / 2 - sendW / 2, ly, sendW, 32, "发送邮件", {
        bg = { 50, 120, 80, 220 }, border = { 80, 180, 120, 200 },
        text = { 220, 255, 230, 255 }, fontSize = 14
    })
end

-- ============================================================================
-- 排行榜管理子 Tab
-- ============================================================================

function M.DrawRankTab(DW, DH, bodyY)
    local pad = 12
    local ly = bodyY

    -- UID 输入
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 170, 190, 200))
    nvgText(vg, pad, ly + 8, "目标玩家 UID:")
    ly = ly + 18
    adminState.btnRects["input_uid"] = drawInputBox(pad, ly, DW / 2 - pad, 26, adminState.uidInput, "输入 UID...", "uid")
    ly = ly + 36

    -- 操作按钮
    local btnW = 140
    local btnH = 32

    adminState.btnRects["btn_hide_rank"] = drawButton(pad, ly, btnW, btnH, "隐藏排行榜", {
        bg = { 120, 90, 30, 220 }, border = { 180, 140, 60, 180 },
        text = { 255, 230, 180, 255 }
    })
    adminState.btnRects["btn_unhide_rank"] = drawButton(pad + btnW + 10, ly, btnW, btnH, "恢复排行榜", {
        bg = { 40, 80, 120, 220 }, border = { 80, 130, 180, 180 },
        text = { 200, 230, 255, 255 }
    })
    ly = ly + btnH + 20

    -- 说明
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(120, 120, 140, 160))
    nvgText(vg, pad, ly, "说明: 隐藏后该玩家不会出现在排行榜中，")
    nvgText(vg, pad, ly + 16, "但其数据保留，可随时恢复显示。")
end

-- ============================================================================
-- 输入处理
-- ============================================================================

--- 处理GM面板内的点击 (设计坐标)
---@param dx number 设计坐标 x
---@param dy number 设计坐标 y
---@return boolean consumed 是否消费了事件
function M.handlePress(dx, dy)
    if not panelState.active then return false end

    local DW = DESIGN_W or 1024

    -- 关闭按钮检测
    local closeX = DW - 30
    local closeY = 2 + 34 / 2  -- tabY + tabH/2
    local closeR = 14
    if (dx - closeX) ^ 2 + (dy - closeY) ^ 2 <= (closeR + 4) ^ 2 then
        M.Close()
        return true
    end

    -- Tab 切换检测
    local tabH = 36
    local tabW = 120
    local tabY = 2
    local tabStartX = DW / 2 - (#TABS * tabW) / 2

    for i, tab in ipairs(TABS) do
        local tx = tabStartX + (i - 1) * tabW
        if dx >= tx and dx <= tx + tabW - 4 and dy >= tabY and dy <= tabY + tabH then
            if panelState.tab ~= tab.id then
                -- 切换 tab 时先应用编辑器结果
                if panelState.tab == "editor" then
                    local TDEditor = require("systems.td.td_editor")
                    if TDEditor.IsActive() then
                        TDEditor.ApplyToGame()
                    end
                end
                panelState.tab = tab.id
                -- 切换到编辑器时重新初始化
                if tab.id == "editor" then
                    local TDEditor = require("systems.td.td_editor")
                    TDEditor.Init()
                end
                -- 切换到管理时清除焦点
                if tab.id == "admin" then
                    adminState.inputFocused = ""
                end
                print("[GM Panel] 切换到: " .. tab.label)
            end
            return true
        end
    end

    -- 管理 tab 内的交互
    if panelState.tab == "admin" then
        return M.handleAdminPress(dx, dy)
    end

    -- 编辑器 tab: 把事件传递给编辑器 (用屏幕坐标)
    if panelState.tab == "editor" then
        -- 不消费, 让编辑器处理
        return false
    end

    return true
end

--- 处理管理面板内的点击
function M.handleAdminPress(dx, dy)
    local rects = adminState.btnRects

    -- 子 Tab 切换
    for _, st in ipairs(SUB_TABS) do
        local key = "subtab_" .. st.id
        if hitTest(rects[key], dx, dy) then
            adminState.subTab = st.id
            adminState.inputFocused = ""
            return true
        end
    end

    -- 输入框聚焦
    for _, inputId in ipairs({ "input_uid", "input_subject", "input_body" }) do
        if hitTest(rects[inputId], dx, dy) then
            local fid = rects[inputId].focusId
            adminState.inputFocused = fid or ""
            -- 触发系统键盘 (移动端)
            if rawget(_G, "input") and input.OpenSoftKeyboard then
                pcall(function() input:OpenSoftKeyboard() end)
            end
            return true
        end
    end

    -- 取消焦点 (点击非输入区域)
    local clickedInput = false
    for _, inputId in ipairs({ "input_uid", "input_subject", "input_body" }) do
        if hitTest(rects[inputId], dx, dy) then
            clickedInput = true
            break
        end
    end
    if not clickedInput then
        adminState.inputFocused = ""
    end

    -- ============ 封禁管理按钮 ============
    if adminState.subTab == "ban" then
        if hitTest(rects["btn_perm_ban"], dx, dy) then
            M.ExecPermBan()
            return true
        end
        if hitTest(rects["btn_full_unban"], dx, dy) then
            M.ExecFullUnban()
            return true
        end
        if hitTest(rects["btn_hide_rank"], dx, dy) then
            M.ExecHideRank()
            return true
        end
        if hitTest(rects["btn_unhide_rank"], dx, dy) then
            M.ExecUnhideRank()
            return true
        end
        if hitTest(rects["btn_refresh_bans"], dx, dy) then
            M.ExecRefreshBans()
            return true
        end
    end

    -- ============ 邮件按钮 ============
    if adminState.subTab == "mail" then
        if hitTest(rects["btn_mail_single"], dx, dy) then
            adminState.mailType = "single"
            return true
        end
        if hitTest(rects["btn_mail_broadcast"], dx, dy) then
            adminState.mailType = "broadcast"
            return true
        end
        if hitTest(rects["btn_send_mail"], dx, dy) then
            M.ExecSendMail()
            return true
        end
    end

    -- ============ 排行榜按钮 ============
    if adminState.subTab == "rank" then
        if hitTest(rects["btn_hide_rank"], dx, dy) then
            M.ExecHideRank()
            return true
        end
        if hitTest(rects["btn_unhide_rank"], dx, dy) then
            M.ExecUnhideRank()
            return true
        end
    end

    return true  -- 管理tab消费所有点击
end

--- 处理GM面板内的移动 (屏幕坐标)
function M.handleMove(sx, sy)
    if not panelState.active then return false end
    if panelState.tab == "editor" then
        return false  -- 让编辑器处理
    end
    return true
end

--- 处理GM面板内的松手 (屏幕坐标)
function M.handleEndPress(sx, sy)
    if not panelState.active then return false end
    if panelState.tab == "editor" then
        return false  -- 让编辑器处理
    end
    return true
end

--- 处理GM面板内的键盘 (按键码)
function M.handleKeyDown(key)
    if not panelState.active then return false end

    -- ESC 关闭面板
    if key == KEY_ESCAPE then
        M.Close()
        return true
    end

    -- 管理 tab 文本输入处理
    if panelState.tab == "admin" and adminState.inputFocused ~= "" then
        M.handleAdminKeyInput(key)
        return true
    end

    -- 编辑器 tab: 传递键盘事件给编辑器
    if panelState.tab == "editor" then
        local TDEditor = require("systems.td.td_editor")
        if TDEditor.IsActive() then
            TDEditor.handleKeyDown(key)
        end
        return true
    end

    return true
end

--- 处理管理面板的文本输入事件
function M.handleTextInput(text)
    if not panelState.active then return false end
    if panelState.tab ~= "admin" then return false end
    if adminState.inputFocused == "" then return false end

    local focused = adminState.inputFocused
    if focused == "uid" then
        -- UID 只接受数字
        local digits = text:match("%d+")
        if digits then
            adminState.uidInput = adminState.uidInput .. digits
        end
    elseif focused == "subject" then
        adminState.mailSubject = adminState.mailSubject .. text
    elseif focused == "body" then
        adminState.mailBody = adminState.mailBody .. text
    end

    return true
end

--- 处理管理面板键盘按键 (退格等)
function M.handleAdminKeyInput(key)
    local focused = adminState.inputFocused
    if not focused or focused == "" then return end

    -- 退格键
    if key == KEY_BACKSPACE then
        if focused == "uid" and #adminState.uidInput > 0 then
            adminState.uidInput = adminState.uidInput:sub(1, -2)
        elseif focused == "subject" and #adminState.mailSubject > 0 then
            -- UTF-8 安全删除最后一个字符
            adminState.mailSubject = M._utf8RemoveLast(adminState.mailSubject)
        elseif focused == "body" and #adminState.mailBody > 0 then
            adminState.mailBody = M._utf8RemoveLast(adminState.mailBody)
        end
    elseif key == KEY_RETURN or key == KEY_KP_ENTER then
        -- 回车换行 (仅正文)
        if focused == "body" then
            adminState.mailBody = adminState.mailBody .. "\n"
        else
            -- 标题/UID 回车: 取消焦点
            adminState.inputFocused = ""
        end
    elseif key == KEY_TAB then
        -- Tab 切换焦点
        if focused == "uid" then
            adminState.inputFocused = "subject"
        elseif focused == "subject" then
            adminState.inputFocused = "body"
        elseif focused == "body" then
            adminState.inputFocused = ""
        end
    end
end

--- UTF-8 安全删除最后一个字符
function M._utf8RemoveLast(s)
    if not s or s == "" then return "" end
    local len = #s
    local i = len
    while i > 0 do
        local byte = s:byte(i)
        if byte < 128 or byte >= 192 then
            -- 找到字符起始字节
            return s:sub(1, i - 1)
        end
        i = i - 1
    end
    return ""
end

-- ============================================================================
-- 管理操作执行 (调用 CloudManager API)
-- ============================================================================

--- 获取 UID 输入值 (number)
local function getUidInput()
    local uid = tonumber(adminState.uidInput)
    if not uid or uid <= 0 then
        showToast("请输入有效的 UID", { 255, 120, 80 })
        return nil
    end
    return uid
end

--- 检查 CloudManager 是否可用
local function checkCloudManager()
    if not rawget(_G, "CloudManager") then
        showToast("CloudManager 未加载", { 255, 120, 80 })
        return false
    end
    return true
end

--- 永久封禁
function M.ExecPermBan()
    local uid = getUidInput()
    if not uid then return end
    if not checkCloudManager() then return end

    showToast("正在封禁 UID:" .. tostring(uid) .. "...", { 180, 180, 200 })
    CloudManager.AdminPermanentBan(uid, function(ok, msg)
        if ok then
            showToast("已永久封禁 UID:" .. tostring(uid), { 80, 200, 120 })
            M.ExecRefreshBans()
        else
            showToast("封禁失败: " .. tostring(msg), { 255, 120, 80 })
        end
    end)
end

--- 完全解禁
function M.ExecFullUnban()
    local uid = getUidInput()
    if not uid then return end
    if not checkCloudManager() then return end

    showToast("正在解禁 UID:" .. tostring(uid) .. "...", { 180, 180, 200 })
    CloudManager.AdminFullUnban(uid, function(ok, msg)
        if ok then
            showToast("已完全解禁 UID:" .. tostring(uid), { 80, 200, 120 })
            M.ExecRefreshBans()
        else
            showToast("解禁失败: " .. tostring(msg), { 255, 120, 80 })
        end
    end)
end

--- 隐藏排行榜
function M.ExecHideRank()
    local uid = getUidInput()
    if not uid then return end
    if not checkCloudManager() then return end

    showToast("正在隐藏排行 UID:" .. tostring(uid) .. "...", { 180, 180, 200 })
    CloudManager.AdminHidePlayerRank(uid, function(ok, msg)
        if ok then
            showToast("已隐藏 UID:" .. tostring(uid) .. " 的排行", { 80, 200, 120 })
        else
            showToast("操作失败: " .. tostring(msg), { 255, 120, 80 })
        end
    end)
end

--- 恢复排行榜
function M.ExecUnhideRank()
    local uid = getUidInput()
    if not uid then return end
    if not checkCloudManager() then return end

    showToast("正在恢复排行 UID:" .. tostring(uid) .. "...", { 180, 180, 200 })
    CloudManager.AdminUnhidePlayerRank(uid, function(ok, msg)
        if ok then
            showToast("已恢复 UID:" .. tostring(uid) .. " 的排行", { 80, 200, 120 })
        else
            showToast("操作失败: " .. tostring(msg), { 255, 120, 80 })
        end
    end)
end

--- 刷新封禁列表
function M.ExecRefreshBans()
    if not checkCloudManager() then return end
    if adminState.banLoading then return end

    adminState.banLoading = true
    CloudManager.AdminGetBanListSummary(function(tempBans, permBans, err)
        adminState.banLoading = false
        if err then
            showToast("加载封禁列表失败: " .. tostring(err), { 255, 120, 80 })
        else
            adminState.banList = { tempBans = tempBans, permBans = permBans }
            local total = #tempBans + #permBans
            showToast("已加载封禁列表 (" .. total .. " 条)", { 80, 200, 120 })
        end
    end)
end

--- 发送邮件
function M.ExecSendMail()
    if not checkCloudManager() then return end

    local subject = adminState.mailSubject
    local body = adminState.mailBody

    if not subject or subject == "" then
        showToast("请输入邮件标题", { 255, 120, 80 })
        return
    end
    if not body or body == "" then
        showToast("请输入邮件正文", { 255, 120, 80 })
        return
    end

    if adminState.mailType == "broadcast" then
        showToast("正在广播邮件...", { 180, 180, 200 })
        CloudManager.BroadcastMail(subject, body, {}, function(ok, msg)
            if ok then
                showToast("全服广播邮件已发送!", { 80, 200, 120 })
                adminState.mailSubject = ""
                adminState.mailBody = ""
            else
                showToast("广播失败: " .. tostring(msg), { 255, 120, 80 })
            end
        end)
    else
        local uid = getUidInput()
        if not uid then return end

        showToast("正在发送邮件...", { 180, 180, 200 })
        CloudManager.SendMail(uid, subject, body, nil, function(ok, msg)
            if ok then
                showToast("邮件已发送给 UID:" .. tostring(uid), { 80, 200, 120 })
                adminState.mailSubject = ""
                adminState.mailBody = ""
            else
                showToast("发送失败: " .. tostring(msg), { 255, 120, 80 })
            end
        end)
    end
end

return M
