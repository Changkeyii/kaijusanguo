-- ============================================================================
-- slg/slg_panels.lua - 三国武灵传：SLG右侧操作面板 (自适应布局重构)
-- 所有面板在右侧区域绘制 (rpX, rpY, rpW, rpH)
-- 设计目标: 信息展示清晰、无文字重叠、自适应面板尺寸、商游UI品质
-- ============================================================================

---@diagnostic disable: undefined-global

local Data   = require("systems.slg.slg_data")
local Render = require("systems.slg.slg_render")

local FC         = Data.FC
local STRATAGEMS = Data.STRATAGEMS

local GetFC            = Render.GetFC
local GetFactionStats  = Render.GetFactionStats
local DrawBtn          = Render.DrawBtn
local DrawTextOutlined = Render.DrawTextOutlined

local M = {}

-- ============================================================================
-- UI 常量 (统一管理, 方便全局调整)
-- ============================================================================
local UI = {
    PAD       = 10,     -- 面板内边距
    TITLE_H   = 32,     -- 标题区高度
    SEP_GAP   = 6,      -- 分隔线上下间距
    LINE_SM   = 24,     -- 小行高 (18pt最低, 需24px)
    LINE_MD   = 26,     -- 中行高 (18-20pt)
    LINE_LG   = 30,     -- 大行高 (20-22pt)
    BTN_H     = 36,     -- 标准按钮高度
    BTN_GAP   = 6,      -- 按钮间距
    CARD_W    = 78,     -- 武将卡片宽
    CARD_H    = 96,     -- 武将卡片高
    CARD_GAP  = 4,      -- 卡片间距
    BACK_BTN_H = 36,    -- 返回按钮高度
    BACK_BTN_W = 96,    -- 返回按钮宽度
    FOOTER    = 48,     -- 底部按钮区域高度
}

-- ============================================================================
-- 兵种克制序列常量 (模块级, 避免每帧创建)
-- ============================================================================
local COUNTER_SEQ = {
    { icon = "步", key = "infantry" },
    { icon = "弓", key = "archer" },
    { icon = "骑", key = "cavalry" },
    { icon = "枪", key = "spear" },
}

--- 绘制兵种克制关系提示 (紧凑一行: 步>弓>骑>枪>步)
local function DrawTroopCounterHint(x, y)
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local cx = x
    -- 标签
    nvgFillColor(vg, nvgRGBA(180, 170, 140, 180))
    nvgText(vg, cx, y, "克制:", nil)
    cx = cx + 42
    -- 循环: 步>弓>骑>枪>步
    for i, s in ipairs(COUNTER_SEQ) do
        local c = TROOP_TYPES[s.key].color
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 240))
        nvgText(vg, cx, y, s.icon, nil)
        cx = cx + 16
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 160))
        nvgText(vg, cx, y, ">", nil)
        cx = cx + 12
    end
    -- 循环回步兵
    local c1 = TROOP_TYPES.infantry.color
    nvgFillColor(vg, nvgRGBA(c1[1], c1[2], c1[3], 240))
    nvgText(vg, cx, y, "步", nil)
    cx = cx + 18
    -- 倍率
    nvgFillColor(vg, nvgRGBA(160, 150, 120, 150))
    nvgText(vg, cx, y, "(x1.3)", nil)
end

-- ============================================================================
-- 绘制辅助函数
-- ============================================================================

--- 绘制面板标题 (金色大字 + 分隔线), 返回下一个内容Y坐标
local function DrawPanelTitle(rpX, rpY, rpW, title, subtitle)
    local pad = UI.PAD
    -- 白字黑描边标题
    DrawTextOutlined(rpX + pad, rpY + 8 + 11, title, 22, 255, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    if subtitle then
        DrawTextOutlined(rpX + pad, rpY + 30 + 9, subtitle, 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    end

    -- 分隔线
    local sepY = subtitle and (rpY + 50) or (rpY + 34)
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY)
    nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(180, 180, 180, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    return sepY + UI.SEP_GAP
end

--- 绘制返回按钮 (居中底部), 返回按钮Rect
-- 判断当前 phase 是否会叠加"结束回合"按钮 (非弹窗、非全屏)
local POPUP_PHASES  = { TURN_REPORT=true, SURRENDER=true, DEFEAT_REPORT=true, RULES=true }
local FULL_PHASES   = { CAMPAIGN_SELECT=true, FACTION_SELECT=true, TURN_REPORT=true }
local function HasEndTurnBtn(phase)
    return not POPUP_PHASES[phase] and not FULL_PHASES[phase]
end

local function DrawBackBtn(st, rpX, rpY, rpW, rpH, key, label)
    label = label or "返回"
    key = key or "btn_back"
    local bw = UI.BACK_BTN_W
    local bh = UI.BACK_BTN_H
    -- 如果底部还有"结束回合"按钮, 返回按钮上移让出空间
    local extraBottom = HasEndTurnBtn(st.phase) and (UI.BTN_H + 6) or 0
    st[key] = DrawBtn(rpX + (rpW - bw) / 2, rpY + rpH - bh - 8 - extraBottom, bw, bh, label, 55, 50, 48)
end

--- 绘制信息行: 标签 + 值 (自动测量宽度, 不重叠)
local function DrawInfoRow(x, y, w, label, value, labelColor, valueColor, fontSize)
    fontSize = fontSize or 18
    -- 标签: 白字描边, 半透明
    local midY = y + fontSize * 0.55  -- TOP→MIDDLE 近似转换
    DrawTextOutlined(x, midY, label, fontSize, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, fontSize)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local lw = nvgTextBounds(vg, 0, 0, label, nil)
    -- 值: 白字描边, 不透明
    nvgSave(vg)
    nvgIntersectScissor(vg, x + lw + 2, y, w - lw - 2, fontSize + 6)
    DrawTextOutlined(x + lw + 2, midY, value, fontSize, 240, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgRestore(vg)
end

--- 绘制一组资源图标行 (金/粮/兵/气)
local function DrawResourceBar(x, y, w, items)
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local cx = x
    local gap = 6
    for _, item in ipairs(items) do
        nvgFillColor(vg, item.color or nvgRGBA(200, 190, 170, 220))
        local str = item.icon .. item.value
        nvgText(vg, cx, y, str, nil)
        cx = cx + nvgTextBounds(vg, 0, 0, str, nil) + gap
        if cx > x + w - 20 then break end  -- 防溢出
    end
end

--- 绘制小节标题 (带左侧色条)
local function DrawSectionHeader(x, y, w, text, color)
    color = color or {160, 200, 255}
    -- 左侧小色条
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y + 1, 3, 20, 1.5)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], 200)); nvgFill(vg)
    -- 白字黑描边标题
    DrawTextOutlined(x + 8, y + 10, text, 18, 230, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
end

--- 绘制进度条
local function DrawProgressBar(x, y, w, h, ratio, fgColor, bgColor)
    bgColor = bgColor or nvgRGBA(40, 35, 25, 100)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, h / 2)
    nvgFillColor(vg, bgColor); nvgFill(vg)
    local fillW = math.floor(w * math.min(1, math.max(0, ratio)))
    if fillW > 0 then
        nvgBeginPath(vg); nvgRoundedRect(vg, x, y, fillW, h, h / 2)
        nvgFillColor(vg, fgColor); nvgFill(vg)
    end
end

--- 绘制薄分隔线
local function DrawThinSep(x, y, w)
    nvgBeginPath(vg); nvgMoveTo(vg, x, y); nvgLineTo(vg, x + w, y)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 40)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
end

-- ============================================================================
-- 默认面板: 选中城池信息 + 操作按钮
-- ============================================================================
function M.DrawMapPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2

    if st.selectedCity then
        local city = WORLD_CITIES[st.selectedCity]
        local cd = st.cityData[st.selectedCity]
        if not city or not cd then st.selectedCity = nil; return end
        local isPlayer = (cd.owner == "player")
        local fc = GetFC(cd.owner)
        local facName = isPlayer and "我方" or GetFacName(cd.owner)

        -- === 计算底部按钮区域高度 (固定不滚动) ===
        local etReserveH = UI.BTN_H + 6  -- "结束回合"按钮预留
        local btnAreaH = isPlayer and (UI.BTN_H * 2 + UI.BTN_GAP + 8 + etReserveH) or (UI.BTN_H * 2 + UI.BTN_GAP + 28 + etReserveH)

        -- === 可滚动区域范围 ===
        local scrollTop = rpY          -- 可滚动区域顶部
        local scrollBot = rpY + rpH - btnAreaH  -- 可滚动区域底部
        local scrollVisH = scrollBot - scrollTop

        -- === 先计算内容总高度 (不绘制, 只计量) ===
        local contentH = 0
        -- 标题区
        contentH = contentH + 38  -- 城名行 + 分隔线 + 间距
        -- 属性区
        local attrH = isPlayer and 62 or 46
        contentH = contentH + attrH + 6
        -- 刺探情报
        local hasScout = st.scoutResult and st.scoutResult.cityId == st.selectedCity and not isPlayer
        if hasScout then contentH = contentH + 56 end
        -- 武将区域
        local cardW = UI.CARD_W
        local cardH = UI.CARD_H
        local cardGap = UI.CARD_GAP
        local cols = math.max(1, math.floor((innerW + cardGap) / (cardW + cardGap)))
        if #cd.heroes > 0 then
            local rows = math.ceil(#cd.heroes / cols)
            contentH = contentH + 24 + rows * (cardH + cardGap) - cardGap  -- header + cards
        else
            contentH = contentH + 40  -- "无武将驻守" 提示
        end

        -- === 滚动状态 ===
        st.mapPanelHeroScroll = st.mapPanelHeroScroll or 0
        local maxScroll = math.max(0, contentH - scrollVisH)
        st.mapPanelHeroScroll = math.max(0, math.min(maxScroll, st.mapPanelHeroScroll))
        local scrollOff = st.mapPanelHeroScroll

        -- === 裁切可滚动区域并绘制内容 ===
        nvgSave(vg)
        nvgScissor(vg, rpX, scrollTop, rpW, scrollVisH)

        local curY = scrollTop - scrollOff  -- 带偏移的起始Y

        -- 标题区: 城名 + 阵营标签 (白字黑描边)
        DrawTextOutlined(rpX + pad, curY + 8 + 11, city.name, 22, 255, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local nameW = nvgTextBounds(vg, 0, 0, city.name, nil)

        -- 阵营标签 (胶囊型)
        local tagX = rpX + pad + nameW + 8
        local tagText = facName .. " · " .. city.region
        nvgFontSize(vg, 18)
        local tagW = nvgTextBounds(vg, 0, 0, tagText, nil) + 12
        nvgBeginPath(vg); nvgRoundedRect(vg, tagX, curY + 8, tagW, 22, 11)
        nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 80)); nvgFill(vg)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(fc.light[1], fc.light[2], fc.light[3], 220))
        nvgText(vg, tagX + tagW / 2, curY + 19, tagText, nil)

        -- 分隔线
        local sepY = curY + 32
        DrawThinSep(rpX + pad, sepY, innerW)
        curY = sepY + 6

        -- === 城池属性区 (卡片式) ===
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, curY, innerW, attrH, 5)
        nvgFillColor(vg, nvgRGBA(50, 35, 18, 60)); nvgFill(vg)

        local col1X = rpX + pad + 8
        local col2X = rpX + pad + innerW / 2
        local rowMid1 = curY + 6 + 9
        DrawTextOutlined(col1X, rowMid1, "驻军", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawTextOutlined(col1X + 38, rowMid1, FormatTroops(cd.garrison), 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawTextOutlined(col2X, rowMid1, "城防", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawTextOutlined(col2X + 38, rowMid1, cd.level .. "级", 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

        if isPlayer then
            local rowMid2 = curY + 32 + 9
            DrawTextOutlined(col1X, rowMid2, "人口", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            DrawTextOutlined(col1X + 38, rowMid2, tostring(city.pop), 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            DrawTextOutlined(col2X, rowMid2, "士气", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            local moraleClr = cd.morale >= 70 and nvgRGBA(120, 230, 100, 255) or
                              cd.morale >= 40 and nvgRGBA(220, 200, 80, 255) or nvgRGBA(230, 100, 70, 255)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, moraleClr)
            nvgText(vg, col2X + 38, rowMid2, tostring(cd.morale), nil)
        else
            DrawTextOutlined(rpX + rpW - pad - 8, rowMid1, "民" .. (city.pop or 50), 18, 180, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        end

        curY = curY + attrH + 6

        -- === 刺探情报 (若有) ===
        if hasScout then
            local sr = st.scoutResult
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, curY, innerW, 50, 4)
            nvgFillColor(vg, nvgRGBA(100, 70, 20, 60)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, curY, 3, 50, 1.5)
            nvgFillColor(vg, nvgRGBA(255, 180, 60, 200)); nvgFill(vg)

            DrawTextOutlined(rpX + pad + 10, curY + 4 + 9, "【情报】", 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            local intelStr = "兵:" .. FormatTroops(sr.garrison) ..
                "  防:" .. sr.level .. "级  气:" .. sr.morale
            DrawTextOutlined(rpX + pad + 10, curY + 26 + 9, intelStr, 18, 220, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if #sr.heroes > 0 then
                local heroStr = "将:" .. table.concat(sr.heroes, " ")
                nvgSave(vg)
                nvgIntersectScissor(vg, rpX + pad + 10 + 100, curY + 26, innerW - 118, 22)
                DrawTextOutlined(rpX + pad + 110, curY + 26 + 9, heroStr, 18, 220, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgRestore(vg)
            end
            curY = curY + 56
        end

        -- === 武将区域 ===
        st._heroAreaRect = { x = rpX, y = math.max(scrollTop, curY), w = rpW, h = math.max(0, scrollBot - math.max(scrollTop, curY)) }

        st._mapPanelHeroRects = st._mapPanelHeroRects or {}
        for k in pairs(st._mapPanelHeroRects) do st._mapPanelHeroRects[k] = nil end

        if #cd.heroes > 0 then
            DrawSectionHeader(rpX + pad, curY, innerW,
                "驻城武将 (" .. #cd.heroes .. ")", {160, 200, 255})
            curY = curY + 24

            local rows = math.ceil(#cd.heroes / cols)

            for i, hIdx in ipairs(cd.heroes) do
                local card = HERO_CARDS[hIdx]
                if not card then goto continue_map_hero end
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cx = rpX + pad + col * (cardW + cardGap)
                local cy = curY + row * (cardH + cardGap)

                if cy + cardH >= scrollTop and cy < scrollBot then
                    local hero = playerHeroes and playerHeroes[hIdx]
                    local cons = hero and hero.constellation or 0
                    DrawInventoryCard(cx, cy, cardW, cardH, card, cons, false, true, true)

                    -- 名条
                    local nameBarH = 24
                    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(240, 230, 200, 240))
                    nvgText(vg, cx + cardW / 2, cy + cardH - nameBarH / 2, TruncateText(card.name, cardW - 4), nil)

                    -- 兵种图标 (左下角)
                    local activeTrp = (st.heroTroopChoice[hIdx] or card.troopType)
                    local tt = activeTrp and TROOP_TYPES[activeTrp]
                    if tt then
                        local iconSz = 24
                        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
                        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy + cardH - nameBarH - iconSz + 2, iconSz, iconSz, 3)
                        nvgFillColor(vg, nvgRGBA(30, 20, 10, 200)); nvgFill(vg)
                        nvgFillColor(vg, nvgRGBA(tt.color[1], tt.color[2], tt.color[3], 240))
                        nvgText(vg, cx + iconSz / 2, cy + cardH - nameBarH - iconSz / 2 + 2, tt.icon, nil)
                    end

                    st._mapPanelHeroRects[hIdx] = { x = cx, y = cy, w = cardW, h = cardH }
                end
                ::continue_map_hero::
            end
        else
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawTextOutlined(rpX + rpW / 2, curY + 20, "无武将驻守", 18, 140)
        end

        nvgRestore(vg)  -- 结束滚动裁切

        -- 滚动条 (在裁切外绘制)
        if maxScroll > 0 then
            local barH = math.max(12, scrollVisH * (scrollVisH / contentH))
            local barY = scrollTop + (scrollOff / maxScroll) * (scrollVisH - barH)
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + rpW - pad, barY, 3, barH, 1.5)
            nvgFillColor(vg, nvgRGBA(200, 170, 100, 100)); nvgFill(vg)
        end

        -- 存储滚动区域 (整个可滚动区域而非仅武将区域)
        st._mapPanelHeroScrollArea = { x = rpX, y = scrollTop, w = rpW, h = scrollVisH }
        st._mapPanelHeroTotalH = contentH

        -- === 操作按钮 (固定在底部, 不随滚动移动) ===
        local etReserve = UI.BTN_H + 6
        if isPlayer then
            st.btn_diplomacy = nil; st.btn_stratagem = nil; st.btn_attack = nil
            st.btn_heroes = nil
            local btnH = UI.BTN_H
            local btnGap = UI.BTN_GAP
            local btns = {
                {label="内政",     key="affairs",   c={100,80,45}},
                {label="补兵",     key="reinforce", c={100,80,45}},
                {label="调兵遣将", key="transfer",  c={100,80,45}},
            }
            local btnW = (innerW - 4) / 2
            local btnStartY = rpY + rpH - (btnH * 2 + btnGap) - 8 - etReserve
            for i, btn in ipairs(btns) do
                local bx, by
                if i <= 2 then
                    local col0 = (i - 1) % 2
                    bx = rpX + pad + col0 * (btnW + 4)
                    by = btnStartY
                else
                    bx = rpX + pad + (innerW - btnW) / 2
                    by = btnStartY + btnH + btnGap
                end
                st["btn_" .. btn.key] = DrawBtn(bx, by, btnW, btnH, btn.label, btn.c[1], btn.c[2], btn.c[3])
            end

            -- 驻军上限信息
            local troopCap = WorldMap.CalcCityTroopCap(st.selectedCity)
            local popCap = WorldMap.CalcCityPopCap(st.selectedCity)
            local effectiveCap = (troopCap > 0) and math.min(troopCap, popCap) or popCap
            if effectiveCap > 0 then
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                local ratio = math.min(1, (cd.garrison or 0) / effectiveCap)
                local cr = math.floor(100 + 155 * (1 - ratio))
                local cg2 = math.floor(180 * ratio)
                nvgFillColor(vg, nvgRGBA(cr, cg2, 80, 180))
                nvgText(vg, rpX + rpW - pad, btnStartY - 18,
                    "兵力 " .. FormatTroops(cd.garrison) .. "/" .. FormatTroops(effectiveCap), nil)
            end
        else
            st.btn_affairs = nil; st.btn_heroes = nil; st.btn_reinforce = nil; st.btn_transfer = nil
            local btnW = (innerW - 4) / 2
            local btnH = UI.BTN_H
            local btnGap = UI.BTN_GAP
            local enemyBtns = {
                {label="外交", key="diplomacy", c={100,80,45}},
                {label="计略", key="stratagem", c={100,80,45}},
                {label="出征", key="attack",    c={100,80,45}},
            }
            local btnStartY = rpY + rpH - (btnH * 2 + btnGap) - 28 - etReserve
            DrawTroopCounterHint(rpX + pad, btnStartY - 18)
            for i, btn in ipairs(enemyBtns) do
                local bx, by
                if i <= 2 then
                    local col0 = (i - 1) % 2
                    bx = rpX + pad + col0 * (btnW + 4)
                    by = btnStartY
                else
                    bx = rpX + pad + (innerW - btnW) / 2
                    by = btnStartY + btnH + btnGap
                end
                st["btn_" .. btn.key] = DrawBtn(bx, by, btnW, btnH, btn.label, btn.c[1], btn.c[2], btn.c[3])
            end
        end
    else
        -- 未选中
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawTextOutlined(rpX + rpW / 2, rpY + rpH / 2 - 10, "< 点击左侧城池", 20, 160)
        DrawTextOutlined(rpX + rpW / 2, rpY + rpH / 2 + 14, "查看详情与操作", 18, 130)
    end
end

-- ============================================================================
-- 内政面板
-- ============================================================================
function M.DrawAffairsPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local cityId = st.affairsCity
    if not cityId then st.phase = "MAP"; return end
    local city, cd = WORLD_CITIES[cityId], st.cityData[cityId]
    if not city or not cd then st.phase = "MAP"; return end

    -- 标题 + 资源行
    local curY = DrawPanelTitle(rpX, rpY, rpW, city.name .. " · 内政")

    -- 资源卡片
    nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, curY, innerW, 28, 4)
    nvgFillColor(vg, nvgRGBA(50, 35, 18, 50)); nvgFill(vg)
    DrawResourceBar(rpX + pad + 6, curY + 5, innerW - 12, {
        {icon="💰", value=tostring(st.gold), color=nvgRGBA(255, 230, 100, 255)},
        {icon="🌾", value=tostring(st.food), color=nvgRGBA(180, 240, 130, 255)},
        {icon="⚔",  value=FormatTroops(cd.garrison), color=nvgRGBA(200, 190, 170, 220)},
        {icon="🔥", value=tostring(cd.morale), color=nvgRGBA(255, 180, 100, 220)},
    })
    curY = curY + 34

    -- 操作列表 (征兵和补兵受人口驻军上限约束)
    local Logic = require("systems.slg.slg_logic")
    local popCap = Logic.CalcCityPopCap(st.affairsCity)
    local troopCap = Logic.CalcCityTroopCap(st.affairsCity)
    local curGarrison = cd.garrison or 0
    local recruitRoom = math.max(0, popCap - curGarrison)
    local recruitAmt = math.min(5000, recruitRoom)
    local recruitGold = recruitAmt * 3
    local recruitFood = recruitAmt
    local effectiveCap = (troopCap > 0) and math.min(troopCap, popCap) or popCap
    local reinforceRoom = math.max(0, effectiveCap - curGarrison)
    local reinforceAmt = math.min(3000, reinforceRoom)
    local reinforceGold = reinforceAmt * 5
    local reinforceFood = reinforceAmt
    local ops = {
        {label="征兵+" .. FormatTroops(recruitAmt), desc=FormatTroops(recruitGold).."金+"..FormatTroops(recruitFood).."粮 上限"..FormatTroops(popCap), key="recruit",
         enabled=recruitAmt>0 and st.gold>=recruitGold and st.food>=recruitFood, color={100,80,45}},
        {label="补兵+" .. FormatTroops(reinforceAmt), desc=FormatTroops(reinforceGold).."金+"..FormatTroops(reinforceFood).."粮", key="reinforce",
         enabled=reinforceAmt>0 and troopCap>0 and st.gold>=reinforceGold and st.food>=reinforceFood, color={100,80,45}},
        {label="升级城防", desc=cd.level.."级→"..math.min(5,cd.level+1).."级 "..FormatTroops(cd.level*20000) .."金",
         key="upgrade", enabled=cd.level<5 and st.gold>=cd.level*20000, color={100,80,45}},
        {label="搜索人才", desc=FormatTroops(10000).."金(20%发现)", key="search",
         enabled=st.gold>=10000, color={100,80,45}},
        {label="犒赏三军", desc=FormatTroops(8000).."金 士气+15", key="morale",
         enabled=st.gold>=8000 and cd.morale<95, color={100,80,45}},
    }

    local btnW = 86
    local btnH = 34
    local rowH = 46

    for i, op in ipairs(ops) do
        local oy = curY + (i - 1) * rowH

        -- 交替行背景
        if i % 2 == 0 then
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, oy, innerW, rowH - 2, 3)
            nvgFillColor(vg, nvgRGBA(50, 35, 18, 30)); nvgFill(vg)
        end

        -- 描述 (左侧, 有宽度限制防溢出)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgSave(vg)
        nvgIntersectScissor(vg, rpX + pad, oy, innerW - btnW - 8, rowH)
        local descAlpha = op.enabled and 230 or 130
        nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(descAlpha * 0.7)))
        nvgText(vg, rpX + pad + 3, oy + rowH / 2, op.desc, nil)
        nvgText(vg, rpX + pad + 5, oy + rowH / 2, op.desc, nil)
        nvgText(vg, rpX + pad + 4, oy + rowH / 2 - 1, op.desc, nil)
        nvgText(vg, rpX + pad + 4, oy + rowH / 2 + 1, op.desc, nil)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, descAlpha))
        nvgText(vg, rpX + pad + 4, oy + rowH / 2, op.desc, nil)
        nvgRestore(vg)

        -- 按钮 (右侧)
        local bx = rpX + rpW - pad - btnW
        local by = oy + (rowH - btnH) / 2
        if op.enabled then
            st["btn_" .. op.key] = DrawBtn(bx, by, btnW, btnH, op.label, op.color[1], op.color[2], op.color[3])
        else
            st["btn_" .. op.key] = DrawBtn(bx, by, btnW, btnH, op.label, 60, 60, 60, 120)
        end
    end

    -- 搜索结果: 飞卡动画 (由 anim.lua FlyingCard 绘制, 这里只需触发)
    if st.searchResult and not st._talentFlyStarted then
        local Anim = require("ui.anim")
        Anim.StartFlyingCard(st.searchResult.heroIdx, t)
        st._talentFlyStarted = true
    end

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_affairsBack")
end

-- ============================================================================
-- 外交面板
-- ============================================================================
function M.DrawDiplomacyPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2

    local curY = DrawPanelTitle(rpX, rpY, rpW, "外交", "💰" .. st.gold)

    local factions = {"wei", "shu", "qun"}
    local fs = GetFactionStats()
    local rowH = 106  -- 每个势力卡片高度 (18pt按钮需更大空间)

    for i, fac in ipairs(factions) do
        local d = st.diplomacy[fac] or {relation=0, treaty=nil}
        local fy = curY + (i - 1) * (rowH + 4)
        local facInfo = FACTIONS[fac] or {name = GetFacName(fac)}
        local fc = GetFC(fac)

        -- 卡片背景
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, fy, innerW, rowH, 5)
        nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 25)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 60))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 左侧色条
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, fy + 4, 3, rowH - 8, 1.5)
        nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 200)); nvgFill(vg)

        -- 第一行: 阵营名 + 城数
        DrawTextOutlined(rpX + pad + 10, fy + 6, facInfo.name, 20, 240, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        DrawTextOutlined(rpX + rpW - pad - 6, fy + 8, "城:" .. (fs[fac] and fs[fac].cities or 0), 18, 170, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

        -- 第二行: 关系条 + 数值 + 和约
        local barX = rpX + pad + 10
        local barY2 = fy + 30
        local barW2 = innerW - 60
        DrawProgressBar(barX, barY2, barW2, 6, d.relation / 100,
            d.relation > 50 and nvgRGBA(60, 180, 80, 200) or
            d.relation > 25 and nvgRGBA(200, 180, 40, 200) or nvgRGBA(200, 60, 40, 200))

        local relStr = tostring(d.relation)
        if d.treaty then relStr = relStr .. " 和约" end
        DrawTextOutlined(rpX + rpW - pad - 6, barY2 - 2, relStr, 18, d.treaty and 230 or 200, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

        -- 第三行: 操作按钮
        local btnW2, btnH2 = 102, 34
        local btnY2 = fy + 44
        -- 确保按钮不超出卡片
        if btnY2 + btnH2 > fy + rowH - 4 then
            btnY2 = fy + rowH - btnH2 - 4
        end
        st["btn_gift_" .. fac] = DrawBtn(rpX + pad + 6, btnY2, btnW2, btnH2, "送礼" .. FormatTroops(20000) .. "金",
            100, 80, 45, st.gold >= 20000 and 200 or 100)
        if not d.treaty then
            st["btn_treaty_" .. fac] = DrawBtn(rpX + pad + btnW2 + 12, btnY2, btnW2, btnH2, "缔约" .. FormatTroops(50000) .. "金",
                50, 80, 110, (d.relation >= 60 and st.gold >= 50000) and 200 or 100)
        else
            st["btn_treaty_" .. fac] = nil
        end
    end

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_diploBack")
end

-- ============================================================================
-- 计略面板
-- ============================================================================
function M.DrawStratagemPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2

    -- 目标
    local tgtId = st.stratagemTarget
    local tgtName = tgtId and WORLD_CITIES[tgtId] and WORLD_CITIES[tgtId].name or "未选择"
    local curY = DrawPanelTitle(rpX, rpY, rpW, "计略",
        "💰" .. st.gold .. "  目标:" .. tgtName)

    -- 提示
    DrawTextOutlined(rpX + pad, curY, "< 点击左侧敌方城池选目标", 18, 160, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 24

    -- 计略卡片列表
    local cardH = 56
    local gap = 6

    for i, strat in ipairs(STRATAGEMS) do
        local by = curY + (i - 1) * (cardH + gap)
        local canUse = (tgtId ~= nil and st.gold >= strat.cost)

        -- 卡片背景
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, by, innerW, cardH, 5)
        nvgFillColor(vg, nvgRGBA(60, 40, 20, canUse and 70 or 30)); nvgFill(vg)
        if canUse then
            nvgStrokeColor(vg, nvgRGBA(200, 170, 90, 80))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end

        -- 第一行: 图标 + 名称
        DrawTextOutlined(rpX + pad + 6, by + 4, strat.icon .. " " .. strat.name, 20, canUse and 240 or 120, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 费用 + 成功率 (右侧)
        DrawTextOutlined(rpX + rpW - pad - 6, by + 6, strat.cost .. "金 " .. math.floor(strat.successRate * 100) .. "%", 18, canUse and 200 or 100, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

        -- 第二行: 描述
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(180, 170, 150, canUse and 170 or 90))
        nvgSave(vg)
        nvgIntersectScissor(vg, rpX + pad + 6, by + 30, innerW - 12, 24)
        nvgText(vg, rpX + pad + 6, by + 30, strat.desc, nil)
        nvgRestore(vg)

        -- 点击区域
        if canUse then
            st["btn_strat_" .. strat.id] = { x = rpX + pad, y = by, w = innerW, h = cardH }
        else
            st["btn_strat_" .. strat.id] = nil
        end
    end

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_stratBack")
end

-- ============================================================================
-- 子模块加载: 军事面板 & 报告面板 (依赖注入 + 函数转发)
-- ============================================================================
local Battle = require("systems.slg.slg_panels_battle")
local Report = require("systems.slg.slg_panels_report")

Battle.init({
    UI                   = UI,
    DrawPanelTitle       = DrawPanelTitle,
    DrawBackBtn          = DrawBackBtn,
    DrawSectionHeader    = DrawSectionHeader,
    DrawThinSep          = DrawThinSep,
    DrawTroopCounterHint = DrawTroopCounterHint,
    DrawProgressBar      = DrawProgressBar,
    HasEndTurnBtn        = HasEndTurnBtn,
})
Report.init({
    UI              = UI,
    DrawThinSep     = DrawThinSep,
    DrawProgressBar = DrawProgressBar,
})

-- 转发: 军事面板 (6)
M.DrawMoveSelectPanel       = Battle.DrawMoveSelectPanel
M.DrawAtkTargetPanel        = Battle.DrawAtkTargetPanel
M.DrawDeployPanel           = Battle.DrawDeployPanel
M.DrawAtkSourceSelectPanel  = Battle.DrawAtkSourceSelectPanel
M.DrawTransferPanel         = Battle.DrawTransferPanel
M.DrawTransferHeroSelectPanel = Battle.DrawTransferHeroSelectPanel

-- 转发: 报告面板 (3)
M.DrawTurnReportPanel       = Report.DrawTurnReportPanel
M.DrawSurrenderPanel        = Report.DrawSurrenderPanel
M.DrawDefeatReportPanel     = Report.DrawDefeatReportPanel

-- ============================================================================
-- 武将管理面板
-- ============================================================================
function M.DrawHeroManagePanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local cityId = st.heroManageCity
    if not cityId then st.phase = "MAP"; return end
    local city, cd = WORLD_CITIES[cityId], st.cityData[cityId]
    if not city or not cd or cd.owner ~= "player" then st.phase = "MAP"; return end

    local curY = DrawPanelTitle(rpX, rpY, rpW, city.name .. " · 武将",
        "💰" .. st.gold .. "  驻将:" .. #cd.heroes)

    -- 武将列表 (带滚动)
    local rowH = 78
    local contentH = rpH - (curY - rpY) - UI.FOOTER
    local scrollOff = st.heroManageScroll or 0

    nvgSave(vg)
    nvgScissor(vg, rpX, curY, rpW, contentH)

    local heroCount = #cd.heroes
    if heroCount == 0 then
        DrawTextOutlined(rpX + rpW / 2, curY + contentH / 2, "该城无武将驻守", 20, 160)
    else
        for i, hIdx in ipairs(cd.heroes) do
            local card = HERO_CARDS[hIdx]
            if not card then goto continue_hero end
            local oy = curY + (i - 1) * rowH - scrollOff
            if oy + rowH < curY or oy > curY + contentH then goto continue_hero end

            -- 卡片
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, oy, innerW, rowH - 4, 5)
            nvgFillColor(vg, nvgRGBA(50, 35, 18, 60)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 50))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            local qColors = {
                [1] = {180,180,180}, [2] = {100,200,100}, [3] = {80,140,255},
                [4] = {200,100,255}, [5] = {255,200,50},
            }
            local qc = qColors[card.quality] or {200,200,200}
            local heroNameMaxW = innerW * 0.45
            local heroNameTrunc = TruncateText(card.name, heroNameMaxW)
            -- 武将名保留品质色
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
            nvgText(vg, rpX + pad + 6, oy + 4, heroNameTrunc, nil)

            -- 当前兵种
            local activeTroop = st.heroTroopChoice[hIdx] or card.troopType
            local tt = TROOP_TYPES[activeTroop]
            nvgFontSize(vg, 18)
            local nameW = nvgTextBounds(vg, 0, 0, heroNameTrunc, nil)
            DrawTextOutlined(rpX + pad + 6 + nameW + 6, oy + 6, tt and tt.name or "步兵", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            -- 兵种选择按钮
            local opts = card.troopOptions or { card.troopType }
            local tbtnW = 42
            local tbtnH = 26
            local tbtnY = oy + 26
            for j, ttype in ipairs(opts) do
                local tti = TROOP_TYPES[ttype]
                local bx = rpX + pad + 4 + (j - 1) * (tbtnW + 3)
                local isActive = (ttype == activeTroop)
                nvgBeginPath(vg); nvgRoundedRect(vg, bx, tbtnY, tbtnW, tbtnH, 3)
                nvgFillColor(vg, isActive and nvgRGBA(180, 140, 40, 100) or nvgRGBA(50, 45, 30, 60)); nvgFill(vg)
                if isActive then
                    nvgStrokeColor(vg, nvgRGBA(255, 200, 60, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                end
                DrawTextOutlined(bx + tbtnW / 2, tbtnY + tbtnH / 2, tti and tti.name or "步兵", 18, isActive and 255 or 160)
                st["btn_troop_" .. hIdx .. "_" .. j] = { x = bx, y = tbtnY, w = tbtnW, h = tbtnH }
            end

            -- 武技
            local techText = ""
            if card.initTechnique and SKILL_TECHNIQUES[card.initTechnique] then
                techText = "技:" .. SKILL_TECHNIQUES[card.initTechnique].name
            end
            local learned = st.heroLearnedSkills[hIdx]
            if learned and learned.techIdx and SKILL_TECHNIQUES[learned.techIdx] then
                techText = techText .. " 习:" .. SKILL_TECHNIQUES[learned.techIdx].name
            end
            if techText ~= "" then
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgSave(vg)
                nvgIntersectScissor(vg, rpX + pad + 6, oy + 54, innerW - 60, 22)
                nvgText(vg, rpX + pad + 6, oy + 54, techText, nil)
                nvgRestore(vg)
            end

            -- 拜师按钮
            local apBtnW, apBtnH = 48, 28
            local apBtnX = rpX + rpW - pad - apBtnW - 2
            local apBtnY = oy + 4
            st["btn_apprentice_" .. i] = DrawBtn(apBtnX, apBtnY, apBtnW, apBtnH, "拜师", 100, 80, 45)

            st["_heroManage_idx_" .. i] = hIdx
            ::continue_hero::
        end
    end

    nvgRestore(vg)

    st._heroManageCount = heroCount
    st._heroManageTotalH = heroCount * rowH
    st._heroManageVisibleH = contentH
    st._heroManageScrollArea = { x = rpX, y = curY, w = rpW, h = contentH }

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_heroManageBack")
end

-- ============================================================================
-- 拜师面板
-- ============================================================================
function M.DrawApprenticePanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local studentIdx = st.apprenticeStudent
    if not studentIdx then st.phase = "HERO_MANAGE"; return end
    local student = HERO_CARDS[studentIdx]
    if not student then st.phase = "HERO_MANAGE"; return end
    local cityId = st.heroManageCity
    if not cityId then st.phase = "MAP"; return end
    local cd = st.cityData[cityId]
    if not cd then st.phase = "MAP"; return end

    local curY = DrawPanelTitle(rpX, rpY, rpW, student.name .. " · 拜师",
        "费用200金 (现有:" .. st.gold .. ")")

    -- 成功率
    local studentStats = student.stats5 or { int = 50 }
    local rate = math.min(95, 50 + studentStats.int * 0.5)
    local rateStr = "成功率:" .. math.floor(rate) .. "%"
    DrawTextOutlined(rpX + pad, curY, rateStr, 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    -- 学生武技
    local ownTech = ""
    if student.initTechnique and SKILL_TECHNIQUES[student.initTechnique] then
        ownTech = "自有:" .. SKILL_TECHNIQUES[student.initTechnique].name
    end
    local learned = st.heroLearnedSkills[studentIdx]
    if learned and learned.techIdx and SKILL_TECHNIQUES[learned.techIdx] then
        ownTech = ownTech .. " 已习:" .. SKILL_TECHNIQUES[learned.techIdx].name
    end
    if ownTech ~= "" then
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
        local rateW = nvgTextBounds(vg, 0, 0, rateStr, nil)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgSave(vg)
        nvgIntersectScissor(vg, rpX + pad + rateW + 10, curY, innerW - rateW - 10, 22)
        nvgText(vg, rpX + pad + rateW + 10, curY, ownTech, nil)
        nvgRestore(vg)
    end

    curY = curY + 24
    DrawThinSep(rpX + pad, curY, innerW)
    curY = curY + 6

    -- 师父列表
    DrawSectionHeader(rpX + pad, curY, innerW, "选择师父", {200, 180, 100})
    curY = curY + 26

    local rowH = 58
    local teacherCount = 0

    for i, hIdx in ipairs(cd.heroes) do
        if hIdx == studentIdx then goto continue_teacher end
        local card = HERO_CARDS[hIdx]
        if not card then goto continue_teacher end
        if not card.initTechnique then goto continue_teacher end
        if card.initTechnique == student.initTechnique then goto continue_teacher end

        teacherCount = teacherCount + 1
        local oy = curY + (teacherCount - 1) * rowH

        -- 背景
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, oy, innerW, rowH - 4, 4)
        nvgFillColor(vg, nvgRGBA(50, 35, 18, 50)); nvgFill(vg)

        local qColors = {
            [1] = {180,180,180}, [2] = {100,200,100}, [3] = {80,140,255},
            [4] = {200,100,255}, [5] = {255,200,50},
        }
        local qc = qColors[card.quality] or {200,200,200}
        -- 师父名保留品质色
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
        nvgText(vg, rpX + pad + 6, oy + 4, TruncateText(card.name, innerW * 0.45), nil)

        local tech = SKILL_TECHNIQUES[card.initTechnique]
        if tech then
            DrawTextOutlined(rpX + pad + 6, oy + 28, "教:" .. tech.name .. " (" .. tech.tier .. "品)", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        end

        -- 学习按钮
        local lbtnW, lbtnH = 52, 30
        local lbtnX = rpX + rpW - pad - lbtnW - 2
        local lbtnY = oy + 12
        local canLearn = (st.gold >= 200)
        if canLearn then
            st["btn_learn_" .. teacherCount] = DrawBtn(lbtnX, lbtnY, lbtnW, lbtnH, "学习", 100, 80, 45)
        else
            st["btn_learn_" .. teacherCount] = DrawBtn(lbtnX, lbtnY, lbtnW, lbtnH, "学习", 60, 60, 60, 120)
        end
        st["_apprentice_teacher_" .. teacherCount] = hIdx

        ::continue_teacher::
    end

    st._apprenticeTeacherCount = teacherCount

    if teacherCount == 0 then
        DrawTextOutlined(rpX + rpW / 2, curY + 24, "无可拜师武将", 18, 160)
        DrawTextOutlined(rpX + rpW / 2, curY + 44, "(需同城且有不同武技)", 18, 140)
    end

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_apprenticeBack")
end

-- ============================================================================
-- 面板分发
-- ============================================================================
-- ============================================================================
-- 剧本选择面板 (全屏覆盖)
-- ============================================================================
function M.DrawCampaignSelectPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local W, H = DESIGN_W, DESIGN_H

    -- 全屏半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(10, 8, 5, 200))
    nvgFill(vg)

    -- 主面板
    local panW = math.min(W - 60, 720)
    local panH = math.min(H - 40, 560)
    local panX = (W - panW) / 2
    local panY = (H - panH) / 2

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 12)
    nvgFillColor(vg, nvgRGBA(30, 25, 20, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 标题
    local pad = 16
    DrawTextOutlined(panX + panW / 2, panY + pad + 8, "乱世征途 · 剧本选择", 26, 255)

    -- 分隔线
    local sepY = panY + pad + 34
    nvgBeginPath(vg)
    nvgMoveTo(vg, panX + pad, sepY)
    nvgLineTo(vg, panX + panW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 剧本列表
    local campaigns = st.campaignList or {}
    local completed = st.completedCampaigns or {}
    local cardH = 72
    local cardGap = 8
    local listY = sepY + 10
    local listH = panH - (listY - panY) - 60  -- 留底部按钮空间
    local scroll = st.campaignScroll or 0

    nvgSave(vg)
    nvgScissor(vg, panX + pad, listY, panW - pad * 2, listH)

    local diffStars = {"★", "★★", "★★★", "★★★★", "★★★★★"}
    st._campaignBtns = {}

    for i, c in ipairs(campaigns) do
        local cy = listY - scroll + (i - 1) * (cardH + cardGap)
        if cy + cardH > listY - 10 and cy < listY + listH + 10 then
            local unlocked = (c.unlockAfter == nil) or (completed[c.unlockAfter] == true)
            local isDone = completed[c.id] == true
            local alpha = unlocked and 255 or 100

            -- 卡片背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, panX + pad, cy, panW - pad * 2, cardH, 8)
            if unlocked then
                nvgFillColor(vg, nvgRGBA(50, 42, 30, 220))
            else
                nvgFillColor(vg, nvgRGBA(35, 30, 25, 180))
            end
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(140, 120, 60, alpha))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            local tx = panX + pad + 14
            local innerW = panW - pad * 2 - 28

            -- 第一行: 年份 + 名称
            local yearStr = c.year .. "年"
            DrawTextOutlined(tx, cy + 8, yearStr, 20, alpha, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
            local adv = nvgTextBounds(vg, 0, 0, yearStr)
            DrawTextOutlined(tx + adv + 12, cy + 8, c.name, 20, alpha, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            -- 完成/锁定标记
            if isDone then
                DrawTextOutlined(panX + panW - pad - 14, cy + 8, "已通关", 18, 200, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            elseif not unlocked then
                DrawTextOutlined(panX + panW - pad - 14, cy + 8, "未解锁", 18, 100, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            end

            -- 第二行: 副标题
            DrawTextOutlined(tx, cy + 30, c.subtitle or "", 18, alpha, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            -- 第三行: 难度
            local diff = diffStars[c.difficulty or 1] or "*"
            DrawTextOutlined(tx, cy + 50, "难度: " .. diff, 18, alpha, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            -- 点击区域
            if unlocked then
                table.insert(st._campaignBtns, {
                    x = panX + pad, y = cy, w = panW - pad * 2, h = cardH,
                    campaignId = c.id,
                })
            end
        end
    end

    nvgRestore(vg)

    -- 底部: 经典模式按钮
    local btnW = 160
    local btnH = 36
    local btnX = panX + (panW - btnW) / 2
    local btnY = panY + panH - 50
    DrawBtn(btnX, btnY, btnW, btnH, "经典随机模式", 100, 80, 45)
    st._classicModeBtn = {x = btnX, y = btnY, w = btnW, h = btnH}
end

-- ============================================================================
-- 阵营选择面板 (全屏覆盖)
-- ============================================================================
function M.DrawFactionSelectPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local W, H = DESIGN_W, DESIGN_H

    -- 获取剧本信息
    local Campaigns = require("systems.slg.slg_campaigns")
    local campaign = Campaigns.GetCampaign(st.selectedCampaignId)
    if not campaign then return end

    -- 全屏半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(10, 8, 5, 210))
    nvgFill(vg)

    -- 主面板
    local panW = math.min(W - 60, 680)
    local panH = math.min(H - 40, 520)
    local panX = (W - panW) / 2
    local panY = (H - panH) / 2

    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 12)
    nvgFillColor(vg, nvgRGBA(30, 25, 20, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    local pad = 16

    -- 标题
    DrawTextOutlined(panX + panW / 2, panY + pad + 8, campaign.name .. " · 选择阵营", 24, 255)

    -- 剧本描述
    local descY = panY + pad + 32
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgTextBox(vg, panX + pad, descY, panW - pad * 2, campaign.desc or "")

    -- 分隔线
    local sepY = descY + 52
    nvgBeginPath(vg)
    nvgMoveTo(vg, panX + pad, sepY)
    nvgLineTo(vg, panX + panW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 阵营卡片
    local factions = st.factionList or {}
    local cardH = 68
    local cardGap = 8
    local listY = sepY + 10
    st._factionBtns = {}

    for i, fac in ipairs(factions) do
        local cy = listY + (i - 1) * (cardH + cardGap)
        if cy + cardH > panY + panH - 60 then break end  -- 不超出面板

        local fc = FC[fac.displayFaction] or FC["qun"]

        -- 卡片背景 (带阵营色边框)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, panX + pad, cy, panW - pad * 2, cardH, 8)
        nvgFillColor(vg, nvgRGBA(45, 38, 28, 220))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 200))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)

        -- 阵营色条
        nvgBeginPath(vg)
        nvgRoundedRect(vg, panX + pad, cy, 6, cardH, 3)
        nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 255))
        nvgFill(vg)

        local tx = panX + pad + 18

        -- 阵营名称
        DrawTextOutlined(tx, cy + 8, fac.name, 22, 255, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 描述
        DrawTextOutlined(tx, cy + 32, fac.desc or "", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 右侧信息: 城池数 / 武将数
        DrawTextOutlined(panX + panW - pad - 14, cy + 10, "城x" .. fac.cityCount, 18, 200, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        DrawTextOutlined(panX + panW - pad - 14, cy + 32, "将x" .. fac.heroCount, 18, 200, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

        -- 点击区域
        table.insert(st._factionBtns, {
            x = panX + pad, y = cy, w = panW - pad * 2, h = cardH,
            factionId = fac.id,
        })
    end

    -- 底部: 返回按钮
    local btnW = 120
    local btnH = 36
    local btnX = panX + (panW - btnW) / 2
    local btnY = panY + panH - 50
    DrawBtn(btnX, btnY, btnW, btnH, "返回", 55, 50, 48)
    st._factionBackBtn = {x = btnX, y = btnY, w = btnW, h = btnH}
end

-- ============================================================================
-- 规则说明面板
-- ============================================================================
function M.DrawRulesPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2

    local contentTop = DrawPanelTitle(rpX, rpY, rpW, "规则说明")

    -- 关闭按钮
    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_rules_close", "关闭")

    -- 可用内容区域（扣除底部按钮）
    local contentH = rpY + rpH - UI.BACK_BTN_H - 16 - contentTop
    local scrollOff = st.rulesScroll or 0

    -- 规则内容 (结构化数据)
    local sections = {
        {
            title = "【人口】",
            color = {180, 220, 140},
            lines = {
                "每座城池拥有固定人口值(35~80)",
                "回合收入: 金 = 人口 + (城防等级-1)*10",
                "回合收入: 粮 = 金收入 * 50%",
                "征兵上限: 每次最多征人口数的兵",
                "自动补兵: 每城每回合 人口/15 人",
                "  (每人消耗2粮, 粮不足则不补)",
            },
        },
        {
            title = "【行动力】",
            color = {80, 200, 240},
            lines = {
                "每回合行动力 = 3 + 粮草/100",
                "最高6点, 粮草不足则行动力减少",
                "出征/计略/外交等操作消耗行动力",
                "保持充足粮草储备至关重要!",
            },
        },
        {
            title = "【士气】",
            color = {220, 200, 80},
            lines = {
                "士气影响攻防战力乘数:",
                "  0~20 溃散: 攻x0.70 防x0.80",
                "  21~40 低落: 攻x0.85 防x0.90",
                "  41~60 平稳: 攻x1.00 防x1.00",
                "  61~80 高昂: 攻x1.10 防x1.10",
                "  81~100 如虹: 攻x1.25 防x1.20",
                "士气<30时每回合逃散5%驻军",
                "我方城池每回合士气恢复3点",
            },
        },
        {
            title = "【城防】",
            color = {100, 180, 255},
            lines = {
                "城防等级1~5级, 升级消耗: 等级*200金",
                "等级加成: 防御战力 +等级*20",
                "等级乘数: 1级x1.0 ~ 5级x1.40",
                "  (每升1级防御力增加10%)",
            },
        },
        {
            title = "【战斗】",
            color = {230, 120, 100},
            lines = {
                "攻方战力 = 兵力 + 武将战力",
                "  * 士气攻击乘数",
                "防方战力 = 兵力*0.5 + 武将战力",
                "  + 城防等级*20",
                "  * 士气防御乘数 * 城防等级乘数",
                "战损比例由双方战力差决定",
            },
        },
    }

    -- 预计算总高度
    local lineH = 22
    local sectionGap = 10
    local titleLineH = 26
    local totalH = 0
    for _, sec in ipairs(sections) do
        totalH = totalH + titleLineH + #sec.lines * lineH + sectionGap
    end
    totalH = totalH + 8  -- 底部边距

    local maxScroll = math.max(0, totalH - contentH)
    scrollOff = math.max(0, math.min(maxScroll, scrollOff))
    st.rulesScroll = scrollOff
    st._rulesMaxScroll = maxScroll

    -- 绘制内容区
    nvgSave(vg)
    nvgScissor(vg, rpX, contentTop, rpW, contentH)

    local curY = contentTop - scrollOff
    for _, sec in ipairs(sections) do
        -- 段标题
        DrawTextOutlined(rpX + pad, curY, sec.title, 20, 255, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        curY = curY + titleLineH

        -- 段内容
        for _, line in ipairs(sec.lines) do
            DrawTextOutlined(rpX + pad + 4, curY, line, 18, 220, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            curY = curY + lineH
        end
        curY = curY + sectionGap
    end

    nvgRestore(vg)

    -- 滚动条
    if maxScroll > 0 then
        local barH = math.max(12, contentH * (contentH / totalH))
        local barY = contentTop + (contentH - barH) * (scrollOff / maxScroll)
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + rpW - pad, barY, 3, barH, 1.5)
        nvgFillColor(vg, nvgRGBA(200, 170, 100, 100)); nvgFill(vg)
    end
end

function M.DrawPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    -- 面板滑入动画 (仅对右侧面板生效, 弹窗类面板排除)
    local Anim = require("ui.anim")
    local isPopupPhase = (st.phase == "TURN_REPORT" or st.phase == "SURRENDER"
        or st.phase == "DEFEAT_REPORT" or st.phase == "RULES")
    local slideOff = 0
    if not isPopupPhase then
        slideOff = Anim.GetPanelSlideOffset(st.phase, t, rpW)
    end
    if slideOff > 1 then
        nvgSave(vg)
        nvgTranslate(vg, slideOff, 0)
    end

    if st.phase == "CAMPAIGN_SELECT" then
        M.DrawCampaignSelectPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "FACTION_SELECT" then
        M.DrawFactionSelectPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "HERO_MANAGE" then
        M.DrawHeroManagePanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "APPRENTICE" then
        M.DrawApprenticePanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "AFFAIRS" then
        M.DrawAffairsPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "DIPLOMACY" then
        M.DrawDiplomacyPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "STRATAGEM" then
        M.DrawStratagemPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "MOVE_SELECT" then
        M.DrawMoveSelectPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "ATK_TARGET" then
        M.DrawAtkTargetPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "CONFIRM_ATTACK" then
        M.DrawDeployPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "ATK_SOURCE_SELECT" then
        M.DrawAtkSourceSelectPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "TRANSFER_SELECT" then
        M.DrawTransferPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "TRANSFER_HERO_SELECT" then
        M.DrawTransferHeroSelectPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "TURN_REPORT" then
        M.DrawTurnReportPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "SURRENDER" then
        M.DrawSurrenderPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "RULES" then
        M.DrawRulesPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "DEFEAT_REPORT" then
        M.DrawDefeatReportPanel(rpX, rpY, rpW, rpH, t)
    else
        M.DrawMapPanel(rpX, rpY, rpW, rpH, t)
    end

    -- 非弹窗/非全屏面板: 底部绘制"结束回合"按钮
    local isFullscreen = (st.phase == "CAMPAIGN_SELECT" or st.phase == "FACTION_SELECT"
        or st.phase == "TURN_REPORT")
    if not isPopupPhase and not isFullscreen then
        local etBtnW = rpW - UI.PAD * 2
        local etBtnH = UI.BTN_H
        local etBtnX = rpX + UI.PAD
        local etBtnY = rpY + rpH - etBtnH - 6
        local pulse = 0.8 + 0.2 * math.sin(t * 3)
        st.btn_endTurn = DrawBtn(etBtnX, etBtnY, etBtnW, etBtnH, "结束回合",
            math.floor(100 * pulse), math.floor(80 * pulse), math.floor(45 * pulse))
    end

    if slideOff > 1 then
        nvgRestore(vg)
    end
end

return M
