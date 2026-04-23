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

        -- 标题区: 城名 + 阵营标签 (白字黑描边)
        DrawTextOutlined(rpX + pad, rpY + 8 + 11, city.name, 22, 255, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local nameW = nvgTextBounds(vg, 0, 0, city.name, nil)

        -- 阵营标签 (胶囊型)
        local tagX = rpX + pad + nameW + 8
        local tagText = facName .. " · " .. city.region
        nvgFontSize(vg, 18)
        local tagW = nvgTextBounds(vg, 0, 0, tagText, nil) + 12
        nvgBeginPath(vg); nvgRoundedRect(vg, tagX, rpY + 8, tagW, 22, 11)
        nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 80)); nvgFill(vg)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(fc.light[1], fc.light[2], fc.light[3], 220))
        nvgText(vg, tagX + tagW / 2, rpY + 19, tagText, nil)

        -- 分隔线
        local sepY = rpY + 32
        DrawThinSep(rpX + pad, sepY, innerW)
        local curY = sepY + 6

        -- === 城池属性区 (卡片式) ===
        local attrH = isPlayer and 62 or 46
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, curY, innerW, attrH, 5)
        nvgFillColor(vg, nvgRGBA(50, 35, 18, 60)); nvgFill(vg)

        -- 第一行: 驻军 + 城防 (白字黑描边)
        local col1X = rpX + pad + 8
        local col2X = rpX + pad + innerW / 2
        local rowMid1 = curY + 6 + 9
        DrawTextOutlined(col1X, rowMid1, "驻军", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawTextOutlined(col1X + 38, rowMid1, FormatTroops(cd.garrison), 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawTextOutlined(col2X, rowMid1, "城防", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawTextOutlined(col2X + 38, rowMid1, cd.level .. "级", 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

        if isPlayer then
            -- 第二行: 人口 + 士气
            local rowMid2 = curY + 32 + 9
            DrawTextOutlined(col1X, rowMid2, "人口", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            DrawTextOutlined(col1X + 38, rowMid2, tostring(city.pop), 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            DrawTextOutlined(col2X, rowMid2, "士气", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            -- 士气保留语义色 (低士气红色警告)
            local moraleClr = cd.morale >= 70 and nvgRGBA(120, 230, 100, 255) or
                              cd.morale >= 40 and nvgRGBA(220, 200, 80, 255) or nvgRGBA(230, 100, 70, 255)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, moraleClr)
            nvgText(vg, col2X + 38, rowMid2, tostring(cd.morale), nil)
        else
            -- 人口放在第一行右侧空位
            DrawTextOutlined(rpX + rpW - pad - 8, rowMid1, "民" .. (city.pop or 50), 18, 180, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        end

        curY = curY + attrH + 6

        -- === 刺探情报 (若有) ===
        local scoutH = 0
        if st.scoutResult and st.scoutResult.cityId == st.selectedCity and not isPlayer then
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
            scoutH = 56
            curY = curY + scoutH
        end

        -- === 武将区域 ===
        local etReserveH = UI.BTN_H + 6  -- 底部"结束回合"按钮预留
        local btnAreaH = isPlayer and (UI.BTN_H * 3 + UI.BTN_GAP * 2 + 16 + etReserveH) or (50 + etReserveH)
        local heroAreaTop = curY
        local heroAreaBot = rpY + rpH - btnAreaH
        local heroAreaH = heroAreaBot - heroAreaTop

        -- 存储武将区域rect供引导系统高亮
        st._heroAreaRect = { x = rpX, y = heroAreaTop, w = rpW, h = heroAreaH }

        if #cd.heroes > 0 then
            DrawSectionHeader(rpX + pad, heroAreaTop, innerW,
                "驻城武将 (" .. #cd.heroes .. ")", {160, 200, 255})
            heroAreaTop = heroAreaTop + 24
            heroAreaH = heroAreaH - 24

            -- 武将卡片网格
            local cardW = UI.CARD_W
            local cardH = UI.CARD_H
            local cardGap = UI.CARD_GAP
            local cols = math.max(1, math.floor((innerW + cardGap) / (cardW + cardGap)))
            local rows = math.ceil(#cd.heroes / cols)
            local totalContentH = rows * (cardH + cardGap) - cardGap

            -- 滚动
            st.mapPanelHeroScroll = st.mapPanelHeroScroll or 0
            local maxScroll = math.max(0, totalContentH - heroAreaH)
            st.mapPanelHeroScroll = math.max(0, math.min(maxScroll, st.mapPanelHeroScroll))
            local scrollOff = st.mapPanelHeroScroll

            nvgSave(vg)
            nvgScissor(vg, rpX, heroAreaTop, rpW, heroAreaH)

            st._mapPanelHeroRects = st._mapPanelHeroRects or {}
            for k in pairs(st._mapPanelHeroRects) do st._mapPanelHeroRects[k] = nil end

            for i, hIdx in ipairs(cd.heroes) do
                local card = HERO_CARDS[hIdx]
                if not card then goto continue_map_hero end
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cx = rpX + pad + col * (cardW + cardGap)
                local cy = heroAreaTop + row * (cardH + cardGap) - scrollOff

                if cy + cardH >= heroAreaTop and cy < heroAreaTop + heroAreaH then
                    local hero = playerHeroes and playerHeroes[hIdx]
                    local cons = hero and hero.constellation or 0
                    DrawInventoryCard(cx, cy, cardW, cardH, card, cons, false, true)

                    -- 名条 (超框显示省略号)
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
            nvgRestore(vg)

            -- 滚动条
            if totalContentH > heroAreaH then
                local barH = math.max(12, heroAreaH * (heroAreaH / totalContentH))
                local barY = heroAreaTop + (scrollOff / maxScroll) * (heroAreaH - barH)
                nvgBeginPath(vg); nvgRoundedRect(vg, rpX + rpW - pad, barY, 3, barH, 1.5)
                nvgFillColor(vg, nvgRGBA(200, 170, 100, 100)); nvgFill(vg)
            end

            st._mapPanelHeroScrollArea = { x = rpX, y = heroAreaTop, w = rpW, h = heroAreaH }
            st._mapPanelHeroTotalH = totalContentH
        else
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawTextOutlined(rpX + rpW / 2, heroAreaTop + heroAreaH / 2, "无武将驻守", 18, 140)
        end

        -- === 操作按钮 ===
        local etReserve = UI.BTN_H + 6  -- 为底部"结束回合"按钮预留空间
        if isPlayer then
            -- 我方城池: 清除敌方按钮残留
            st.btn_diplomacy = nil; st.btn_stratagem = nil; st.btn_attack = nil
            st.btn_heroes = nil  -- 武将管理已移至武将详情弹窗
            local btnH = UI.BTN_H
            local btnGap = UI.BTN_GAP
            local btns = {
                {label="内政",     key="affairs",   c={100,80,45}},
                {label="补兵",     key="reinforce", c={100,80,45}},
                {label="调兵遣将", key="transfer",  c={100,80,45}},
            }
            -- 3按钮: 第一行2个, 第二行1个居中
            local btnW = (innerW - 4) / 2
            local btnStartY = rpY + rpH - (btnH * 2 + btnGap) - 8 - etReserve
            for i, btn in ipairs(btns) do
                local bx, by
                if i <= 2 then
                    local col = (i - 1) % 2
                    bx = rpX + pad + col * (btnW + 4)
                    by = btnStartY
                else
                    bx = rpX + pad + (innerW - btnW) / 2
                    by = btnStartY + btnH + btnGap
                end
                st["btn_" .. btn.key] = DrawBtn(bx, by, btnW, btnH, btn.label, btn.c[1], btn.c[2], btn.c[3])
            end

            -- 驻军上限信息 (取领兵上限和人口上限的较小值)
            local troopCap = WorldMap.CalcCityTroopCap(st.selectedCity)
            local popCap = WorldMap.CalcCityPopCap(st.selectedCity)
            local effectiveCap = (troopCap > 0) and math.min(troopCap, popCap) or popCap
            if effectiveCap > 0 then
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                local ratio = math.min(1, (cd.garrison or 0) / effectiveCap)
                local cr = math.floor(100 + 155 * (1 - ratio))
                local cg = math.floor(180 * ratio)
                nvgFillColor(vg, nvgRGBA(cr, cg, 80, 180))
                nvgText(vg, rpX + rpW - pad, btnStartY - 18,
                    "兵力 " .. FormatTroops(cd.garrison) .. "/" .. FormatTroops(effectiveCap), nil)
            end
        else
            -- 敌方城池: 外交/计略/出征, 清除我方按钮残留
            st.btn_affairs = nil; st.btn_heroes = nil; st.btn_reinforce = nil; st.btn_transfer = nil
            local btnW = (innerW - 4) / 2
            local btnH = UI.BTN_H
            local btnGap = UI.BTN_GAP
            local enemyBtns = {
                {label="外交", key="diplomacy", c={100,80,45}},
                {label="计略", key="stratagem", c={100,80,45}},
                {label="出征", key="attack",    c={100,80,45}},
            }
            -- 3个按钮: 第一行2个, 第二行1个居中
            local btnStartY = rpY + rpH - (btnH * 2 + btnGap) - 28 - etReserve
            -- 兵种克制提示 (按钮区上方)
            DrawTroopCounterHint(rpX + pad, btnStartY - 18)
            for i, btn in ipairs(enemyBtns) do
                local bx, by
                if i <= 2 then
                    local col = (i - 1) % 2
                    bx = rpX + pad + col * (btnW + 4)
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
-- 调兵面板
-- ============================================================================
function M.DrawMoveSelectPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local fromCity = WORLD_CITIES[st.selectedCity]
    if not fromCity then st.phase = "MAP"; return end

    local curY = DrawPanelTitle(rpX, rpY, rpW, fromCity.name .. " · 调兵")

    DrawTextOutlined(rpX + pad, curY, "< 点击相邻我方城池调兵", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawTextOutlined(rpX + pad, curY + 22, "(调50%兵力+全部武将)", 18, 150, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 48

    -- 可选目标
    local targets = {}
    for _, connId in ipairs(fromCity.conn) do
        local cd = st.cityData[connId]
        if cd.owner == "player" and connId ~= st.selectedCity then
            table.insert(targets, {id = connId, city = WORLD_CITIES[connId], cd = cd})
        end
    end

    if #targets > 0 then
        DrawSectionHeader(rpX + pad, curY, innerW, "可调往城池", {100, 200, 150})
        curY = curY + 26
        for i, tgt in ipairs(targets) do
            local cityLabel = "· " .. tgt.city.name
            DrawTextOutlined(rpX + pad + 6, curY, cityLabel, 18, 210, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            local nameW = nvgTextBounds(vg, 0, 0, cityLabel, nil)
            DrawTextOutlined(rpX + pad + 6 + nameW + 6, curY + 2, "兵:" .. FormatTroops(tgt.cd.garrison), 18, 170, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            curY = curY + 28
        end
    else
        DrawTextOutlined(rpX + rpW / 2, curY + 20, "无相邻我方城池可调兵", 18, 180)
    end

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_moveBack", "取消")
end

-- ============================================================================
-- 攻击目标选择面板
-- ============================================================================
function M.DrawAtkTargetPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local fromCity = WORLD_CITIES[st.selectedCity]
    if not fromCity then st.phase = "MAP"; return end

    local curY = DrawPanelTitle(rpX, rpY, rpW, fromCity.name .. " · 出征")

    DrawSectionHeader(rpX + pad, curY, innerW, "选择攻击目标", {255, 160, 80})
    curY = curY + 26

    -- 敌城列表
    local enemies = {}
    for _, connId in ipairs(fromCity.conn) do
        local cd = st.cityData[connId]
        if cd.owner ~= "player" then table.insert(enemies, connId) end
    end

    local cardH2 = 56
    local gap = 6
    st._atkTargetRects = st._atkTargetRects or {}
    for k in pairs(st._atkTargetRects) do st._atkTargetRects[k] = nil end

    for i, eid in ipairs(enemies) do
        local ec = WORLD_CITIES[eid]
        local ed = st.cityData[eid]
        local efc = GetFC(ed.owner)
        local cy = curY + (i - 1) * (cardH2 + gap)

        -- 卡片
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, cy, innerW, cardH2, 5)
        nvgFillColor(vg, nvgRGBA(efc.main[1], efc.main[2], efc.main[3], 40)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(efc.main[1], efc.main[2], efc.main[3], 80))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 左色条
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, cy + 4, 3, cardH2 - 8, 1.5)
        nvgFillColor(vg, nvgRGBA(efc.main[1], efc.main[2], efc.main[3], 200)); nvgFill(vg)

        -- 城名 + 阵营
        DrawTextOutlined(rpX + pad + 10, cy + 6, ec.name, 20, 240, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local eFacName = GetFacName(ed.owner)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
        local nW = nvgTextBounds(vg, 0, 0, ec.name, nil)
        DrawTextOutlined(rpX + pad + 12 + nW, cy + 10, eFacName, 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 兵力 + 城防
        DrawTextOutlined(rpX + pad + 10, cy + 30, "兵:" .. FormatTroops(ed.garrison) .. "  防:" .. ed.level .. "级", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        st._atkTargetRects[eid] = { x = rpX + pad, y = cy, w = innerW, h = cardH2 }
    end

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_atkTargetBack", "取消")
end

-- ============================================================================
-- 战前部署面板 (内容最密集的面板 — 使用紧凑自适应布局)
-- ============================================================================
function M.DrawDeployPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local fromId = st.attackFromCity or st.selectedCity
    if not fromId or not st.targetCity then st.phase = "MAP"; return end
    local fromCity, toCity = WORLD_CITIES[fromId], WORLD_CITIES[st.targetCity]
    local fromData, toData = st.cityData[fromId], st.cityData[st.targetCity]
    if not fromCity or not toCity then st.phase = "MAP"; return end

    local defFac = toData.owner
    local defFacName = GetFacName(defFac)
    local dfc = GetFC(defFac)

    nvgFontFaceId(vg, GetMainFont())

    -- === 标题 + 兵种克制提示 ===
    DrawTextOutlined(rpX + pad, rpY + 6, "战前部署", 20, 255, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawTroopCounterHint(rpX + pad, rpY + 6 + 20 + 9)

    -- === 对阵信息 (紧凑一行) ===
    local curY = rpY + 44
    DrawTextOutlined(rpX + pad, curY, fromCity.name, 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawTextOutlined(rpX + rpW / 2, curY, "vs", 18, 180, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawTextOutlined(rpX + rpW - pad, curY, toCity.name .. "(" .. defFacName .. ")", 18, 220, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    curY = curY + 22

    -- === 战力指数对比 (醒目区块) ===
    local Logic = require("systems.slg.slg_logic")
    local atkDeployHeroes0 = (#st.deployHeroes > 0) and st.deployHeroes or fromData.heroes
    local atkPower = Logic.CalcSideCombatPower(atkDeployHeroes0, fromData.level or 1)
    local defPower = Logic.CalcSideCombatPower(toData.heroes or {}, toData.level or 1)
    local totalPower = atkPower + defPower + 1
    local atkPRatio = atkPower / totalPower
    -- 战力数值 (大字号显示在对比条上方)
    local powerAdvantage = atkPower >= defPower
    nvgFontSize(vg, 22); nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgText(vg, rpX + pad, curY, tostring(atkPower), nil)
    nvgFontSize(vg, 16); nvgFillColor(vg, nvgRGBA(200, 200, 200, 180))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(vg, rpX + rpW / 2, curY + 2, powerAdvantage and "优势" or "劣势", nil)
    nvgFontSize(vg, 22); nvgFillColor(vg, nvgRGBA(dfc.main[1], dfc.main[2], dfc.main[3], 240))
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgText(vg, rpX + rpW - pad, curY, tostring(defPower), nil)
    curY = curY + 24
    -- 对比条 (加粗到12px)
    local barH = 12
    local atkPW = math.floor(innerW * atkPRatio)
    nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, curY, atkPW, barH, 4)
    nvgFillColor(vg, powerAdvantage and nvgRGBA(80, 200, 80, 220) or nvgRGBA(200, 160, 60, 220)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad + atkPW, curY, innerW - atkPW, barH, 4)
    nvgFillColor(vg, nvgRGBA(dfc.main[1], dfc.main[2], dfc.main[3], 200)); nvgFill(vg)
    curY = curY + barH + 6

    -- === 出征兵力选择 ===
    DrawTextOutlined(rpX + pad, curY, "出征兵力:", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 22

    local ratios = {{label="30%",ratio=0.3},{label="50%",ratio=0.5},{label="70%",ratio=0.7}}
    local rbtnW = (innerW - 8) / 3
    local rbtnH = 30
    if st.deployTroops == 0 then st.deployTroops = math.floor(fromData.garrison * 0.5) end
    for i, r in ipairs(ratios) do
        local troops = math.floor(fromData.garrison * r.ratio)
        local isActive = (st.deployTroops == troops)
        local bx = rpX + pad + (i - 1) * (rbtnW + 4)
        local lblStr = r.label .. "(" .. FormatTroops(troops) .. ")"
        if isActive then
            st["btn_ratio" .. i] = DrawBtn(bx, curY, rbtnW, rbtnH, lblStr, 100, 80, 45)
        else
            st["btn_ratio" .. i] = DrawBtn(bx, curY, rbtnW, rbtnH, lblStr, 55, 50, 48)
        end
    end
    curY = curY + rbtnH + 4

    -- === 粮草消耗 ===
    local foodCost = math.floor(st.deployTroops * 0.5)
    DrawTextOutlined(rpX + pad, curY, "粮草:" .. foodCost .. " (现有:" .. st.food .. ")", 18, st.food >= foodCost and 200 or 220, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 22

    DrawThinSep(rpX + pad, curY, innerW)
    curY = curY + 4

    -- === 阵型选择 ===
    DrawTextOutlined(rpX + pad, curY, "阵型:", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 22

    local fBtnW = math.floor((innerW - 4) / 5)
    local fBtnH = 28
    st.formationBtns = {}
    if rawget(_G, "FORMATIONS") then
        for i, f in ipairs(FORMATIONS) do
            local bx = rpX + pad + (i - 1) * (fBtnW + 1)
            local isActive = (st.selectedFormation == f.id)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, fBtnW, fBtnH, 3)
            nvgFillColor(vg, isActive and nvgRGBA(180, 120, 30, 200) or nvgRGBA(50, 45, 35, 160)); nvgFill(vg)
            if isActive then
                nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            end
            DrawTextOutlined(bx + fBtnW / 2, curY + fBtnH / 2, f.name, 18, isActive and 255 or 160)
            st.formationBtns[i] = { x=bx, y=curY, w=fBtnW, h=fBtnH, formId=f.id }
        end
    end
    curY = curY + fBtnH + 2

    -- 阵型说明 (一行, 截断防溢出)
    local curForm = nil
    if rawget(_G, "FORMATIONS") and st.selectedFormation then
        for _, f in ipairs(FORMATIONS) do if f.id == st.selectedFormation then curForm = f; break end end
    end
    if curForm then
        DrawTextOutlined(rpX + pad, curY, curForm.desc .. " 适合:" .. curForm.suitFor, 18, 160, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    end
    curY = curY + 22

    -- === 战术选择 ===
    DrawTextOutlined(rpX + pad, curY, "战术:", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 22

    local tBtnW = math.floor((innerW - 4) / 3)
    local tBtnH = 28
    st.tacticBtns = {}
    if rawget(_G, "TACTIC_DEFS") then
        for i, td in ipairs(TACTIC_DEFS) do
            local bx = rpX + pad + (i - 1) * (tBtnW + 2)
            local isActive = (st.selectedTactic == td.id)
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, curY, tBtnW, tBtnH, 3)
            nvgFillColor(vg, isActive and nvgRGBA(100, 50, 180, 200) or nvgRGBA(50, 45, 40, 160)); nvgFill(vg)
            if isActive then
                nvgStrokeColor(vg, nvgRGBA(180, 140, 255, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            end
            DrawTextOutlined(bx + tBtnW / 2, curY + tBtnH / 2, td.name, 18, isActive and 255 or 160)
            st.tacticBtns[i] = { x=bx, y=curY, w=tBtnW, h=tBtnH, tacticId=td.id }
        end
    end
    curY = curY + tBtnH + 4

    -- === 士气 ===
    local fromMorale = fromData.morale or 60
    local moraleTier = nil
    if rawget(_G, "MORALE_MULTIPLIER_TABLE") then
        for _, row in ipairs(MORALE_MULTIPLIER_TABLE) do
            if fromMorale >= row.min and fromMorale <= row.max then moraleTier = row; break end
        end
    end
    if moraleTier then
        local mc = moraleTier.color or {180,180,140}
        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(mc[1], mc[2], mc[3], 200))
        nvgText(vg, rpX + pad, curY,
            "士气:" .. fromMorale .. " [" .. moraleTier.label .. "] 攻×" ..
            string.format("%.1f", moraleTier.atkMult), nil)
    end
    curY = curY + 22

    -- === 上次战果 ===
    if st.lastBattleReward then
        local rew = st.lastBattleReward
        if rew.victory then
            DrawTextOutlined(rpX + pad, curY, "上次:胜 +" .. rew.gold .. "金 +" .. rew.food .. "粮", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        else
            DrawTextOutlined(rpX + pad, curY, "上次:败 " .. rew.food .. "粮", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        end
        curY = curY + 22
    end

    -- === 武将 (横排卡片) ===
    DrawThinSep(rpX + pad, curY, innerW)
    curY = curY + 4
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    if #fromData.heroes > 0 then
        DrawTextOutlined(rpX + pad, curY, "武将(点击出战):", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        curY = curY + 22
        local cardW2, cardH2 = 48, 64
        local cardGap2 = 4
        local maxCards = math.min(#fromData.heroes, 4)
        for i = 1, maxCards do
            local hIdx = fromData.heroes[i]
            local card = HERO_CARDS[hIdx]
            if card then
                local cx = rpX + pad + (i - 1) * (cardW2 + cardGap2)
                local cy = curY
                local hero = playerHeroes[hIdx]
                local cons = hero and hero.constellation or 0
                local deployed = false
                for _, dh in ipairs(st.deployHeroes) do if dh == hIdx then deployed = true; break end end

                DrawInventoryCard(cx, cy, cardW2, cardH2, card, cons, false, false)

                if deployed then
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx - 1, cy - 1, cardW2 + 2, cardH2 + 2, 4)
                    nvgStrokeColor(vg, nvgRGBA(255, 200, 50, 200))
                    nvgStrokeWidth(vg, 2); nvgStroke(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx + cardW2 - 40, cy + 1, 38, 22, 2)
                    nvgFillColor(vg, nvgRGBA(220, 160, 30, 220)); nvgFill(vg)
                    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(60, 30, 0, 255))
                    nvgText(vg, cx + cardW2 - 21, cy + 12, "出战", nil)
                else
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW2, cardH2, 4)
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 80)); nvgFill(vg)
                end
                st["btn_hero_" .. i] = { x = cx, y = cy, w = cardW2, h = cardH2 }
            end
        end
        curY = curY + cardH2 + 4
        nvgFontFaceId(vg, GetMainFont())
    else
        DrawTextOutlined(rpX + pad, curY, "无武将(战力大减)", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        curY = curY + 22
    end

    -- === 兵种克制 & 士气提示 (底部固定区) ===
    local etOffset = HasEndTurnBtn(st.phase) and (UI.BTN_H + 6) or 0
    local estY = rpY + rpH - 50 - etOffset
    DrawThinSep(rpX + pad, estY - 4, innerW)
    local atkDeployHeroes = (#st.deployHeroes > 0) and st.deployHeroes or fromData.heroes
    local troopAdv = Logic.CalcTroopAdvantage(atkDeployHeroes, toData.heroes or {})
    local advLabel = ""
    if troopAdv > 1.05 then advLabel = "兵种克制×" .. string.format("%.1f", troopAdv)
    elseif troopAdv < 0.95 then advLabel = "兵种被克×" .. string.format("%.1f", troopAdv)
    else advLabel = "兵种无克制" end
    local advColor = troopAdv > 1.05 and 180 or (troopAdv < 0.95 and 220 or 160)
    DrawTextOutlined(rpX + pad, estY, advLabel, 18, advColor, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    -- === 底部按钮 ===
    local canAtk = st.deployTroops >= 20 and st.food >= foodCost
    local btnW3, btnH3 = (innerW - 6) / 2, 32
    local etExtra = HasEndTurnBtn(st.phase) and (UI.BTN_H + 6) or 0
    local btnY3 = rpY + rpH - btnH3 - 6 - etExtra
    st.btn_cancelAtk = DrawBtn(rpX + pad, btnY3, btnW3, btnH3, "取消", 55, 50, 48)
    if canAtk then
        st.btn_confirmAtk = DrawBtn(rpX + pad + btnW3 + 6, btnY3, btnW3, btnH3, "出征!", 130, 40, 35)
    else
        st.btn_confirmAtk = DrawBtn(rpX + pad + btnW3 + 6, btnY3, btnW3, btnH3, "出征!", 60, 60, 60, 120)
    end
end

-- ============================================================================
-- 出征出发城池选择面板 (多个临近我方城池可出征时)
-- ============================================================================
function M.DrawAtkSourceSelectPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local targetCity = WORLD_CITIES[st.targetCity]
    if not targetCity or not st.attackSources then st.phase = "MAP"; return end

    local toData = st.cityData[st.targetCity]
    local dfc = GetFC(toData and toData.owner or "neutral")

    local curY = DrawPanelTitle(rpX, rpY, rpW, "出征 · " .. targetCity.name)

    -- 目标城池信息
    local defFacName = GetFacName(toData.owner)
    DrawTextOutlined(rpX + pad, curY, defFacName .. " 兵:" .. FormatTroops(toData.garrison), 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 26

    DrawSectionHeader(rpX + pad, curY, innerW, "选择出发城池", {255, 200, 100})
    curY = curY + 26

    -- 可用出发城池列表
    local cardH2 = 60
    local gap = 6
    st._atkSourceRects = st._atkSourceRects or {}
    for k in pairs(st._atkSourceRects) do st._atkSourceRects[k] = nil end

    for i, srcId in ipairs(st.attackSources) do
        local sc = WORLD_CITIES[srcId]
        local sd = st.cityData[srcId]
        if sc and sd then
            local cy = curY + (i - 1) * (cardH2 + gap)

            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, cy, innerW, cardH2, 5)
            nvgFillColor(vg, nvgRGBA(60, 100, 60, 60)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 180, 80, 100))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 左色条
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, cy + 4, 3, cardH2 - 8, 1.5)
            nvgFillColor(vg, nvgRGBA(80, 180, 60, 200)); nvgFill(vg)

            -- 城名
            DrawTextOutlined(rpX + pad + 10, cy + 6, sc.name, 20, 240, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            -- 兵力 + 武将数
            DrawTextOutlined(rpX + pad + 10, cy + 30, "兵:" .. FormatTroops(sd.garrison) .. "  将:" .. #(sd.heroes or {}), 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            st._atkSourceRects[srcId] = { x = rpX + pad, y = cy, w = innerW, h = cardH2 }
        end
    end

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_atkSourceBack", "取消")
end

-- ============================================================================
-- 调兵遣将面板 (从其他城池调武将到当前城池)
-- ============================================================================
function M.DrawTransferPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local toCity = WORLD_CITIES[st.selectedCity]
    if not toCity then st.phase = "MAP"; return end
    local toData = st.cityData[st.selectedCity]
    if not toData or toData.owner ~= "player" then st.phase = "MAP"; return end

    local curY = DrawPanelTitle(rpX, rpY, rpW, toCity.name .. " · 调兵遣将")

    DrawTextOutlined(rpX + pad, curY, "点击相邻我方城池调入武将", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawTextOutlined(rpX + pad, curY + 22, "(调50%兵力+全部武将到此城)", 18, 150, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 48

    -- 可选来源城池
    local sources = {}
    for _, connId in ipairs(toCity.conn) do
        local cd = st.cityData[connId]
        if cd and cd.owner == "player" and connId ~= st.selectedCity and #(cd.heroes or {}) > 0 then
            table.insert(sources, {id = connId, city = WORLD_CITIES[connId], cd = cd})
        end
    end

    if #sources > 0 then
        DrawSectionHeader(rpX + pad, curY, innerW, "可调兵城池", {100, 180, 220})
        curY = curY + 26
        st._transferSourceRects = st._transferSourceRects or {}
        for k in pairs(st._transferSourceRects) do st._transferSourceRects[k] = nil end

        local cardH2 = 56
        local gap = 6
        for i, src in ipairs(sources) do
            local cy = curY + (i - 1) * (cardH2 + gap)

            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, cy, innerW, cardH2, 5)
            nvgFillColor(vg, nvgRGBA(50, 70, 100, 60)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 130, 200, 100))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 左色条
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, cy + 4, 3, cardH2 - 8, 1.5)
            nvgFillColor(vg, nvgRGBA(60, 130, 200, 200)); nvgFill(vg)

            -- 城名
            DrawTextOutlined(rpX + pad + 10, cy + 6, src.city.name, 20, 240, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            -- 兵力 + 武将数
            DrawTextOutlined(rpX + pad + 10, cy + 30, "兵:" .. FormatTroops(src.cd.garrison) .. "  将:" .. #(src.cd.heroes or {}), 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

            st._transferSourceRects[src.id] = { x = rpX + pad, y = cy, w = innerW, h = cardH2 }
        end
    else
        DrawTextOutlined(rpX + rpW / 2, curY + 20, "无相邻城池可调兵(需有武将)", 18, 180)
    end

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_transferBack", "取消")
end

-- ============================================================================
-- 调兵武将选择面板 (选中来源城池后, 选择要调取的武将)
-- ============================================================================
function M.DrawTransferHeroSelectPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = UI.PAD
    local innerW = rpW - pad * 2
    local srcId = st.transferFromCity
    local dstId = st.selectedCity
    if not srcId or not dstId then st.phase = "TRANSFER_SELECT"; return end
    local srcCity = WORLD_CITIES[srcId]
    local srcData = st.cityData[srcId]
    local dstCity = WORLD_CITIES[dstId]
    if not srcCity or not srcData or not dstCity then st.phase = "TRANSFER_SELECT"; return end

    -- 初始化选择状态 (默认全选)
    if not st._transferHeroSelected then
        st._transferHeroSelected = {}
        for _, hIdx in ipairs(srcData.heroes) do
            st._transferHeroSelected[hIdx] = true
        end
    end

    local curY = DrawPanelTitle(rpX, rpY, rpW, srcCity.name .. " → " .. dstCity.name,
        "选择要调遣的武将")

    -- 兵力调配说明
    local selectedCount = 0
    for _, hIdx in ipairs(srcData.heroes) do
        if st._transferHeroSelected[hIdx] then selectedCount = selectedCount + 1 end
    end
    local troopRatio = selectedCount > 0 and math.floor(selectedCount / #srcData.heroes * 50) or 0
    local moveTroops = math.floor(srcData.garrison * troopRatio / 100)
    DrawTextOutlined(rpX + pad, curY, "随行兵力: " .. FormatTroops(moveTroops) .. " (" .. troopRatio .. "%)", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 24

    -- 武将列表
    DrawSectionHeader(rpX + pad, curY, innerW, "可调武将 (已选" .. selectedCount .. "/" .. #srcData.heroes .. ")", {100, 180, 220})
    curY = curY + 26

    -- 滚动区域
    local backBtnReserve = UI.BACK_BTN_H + 16 + (HasEndTurnBtn(st.phase) and (UI.BTN_H + 6) or 0)
    local confirmBtnH = UI.BTN_H + 8
    local listH = rpY + rpH - curY - backBtnReserve - confirmBtnH
    local rowH = 52
    local totalH = #srcData.heroes * rowH

    st._transferHeroScroll = st._transferHeroScroll or 0
    local maxScroll = math.max(0, totalH - listH)
    st._transferHeroScroll = math.max(0, math.min(maxScroll, st._transferHeroScroll))
    local scrollOff = st._transferHeroScroll

    nvgSave(vg)
    nvgScissor(vg, rpX, curY, rpW, listH)

    st._transferHeroCheckRects = st._transferHeroCheckRects or {}
    for k in pairs(st._transferHeroCheckRects) do st._transferHeroCheckRects[k] = nil end

    for i, hIdx in ipairs(srcData.heroes) do
        local card = HERO_CARDS[hIdx]
        if not card then goto continue_th end
        local oy = curY + (i - 1) * rowH - scrollOff
        if oy + rowH < curY or oy > curY + listH then goto continue_th end

        local selected = st._transferHeroSelected[hIdx] or false

        -- 行背景
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, oy + 2, innerW, rowH - 4, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 80, 50, 80) or nvgRGBA(50, 35, 18, 40)); nvgFill(vg)
        if selected then
            nvgStrokeColor(vg, nvgRGBA(120, 200, 80, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end

        -- 勾选框
        local cbSz = 22
        local cbX = rpX + pad + 6
        local cbY = oy + (rowH - cbSz) / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, cbX, cbY, cbSz, cbSz, 3)
        nvgFillColor(vg, selected and nvgRGBA(80, 180, 60, 200) or nvgRGBA(60, 50, 30, 120)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 160, 100, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        if selected then
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
            nvgText(vg, cbX + cbSz / 2, cbY + cbSz / 2, "✓", nil)
        end

        -- 武将名 (品质色)
        local qColors = {
            [1] = {180,180,180}, [2] = {100,200,100}, [3] = {80,140,255},
            [4] = {200,100,255}, [5] = {255,200,50},
        }
        local qc = qColors[card.quality] or {200,200,200}
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
        nvgText(vg, cbX + cbSz + 8, oy + rowH / 2 - 8, card.name, nil)

        -- 兵种
        local activeTroop = st.heroTroopChoice[hIdx] or card.troopType
        local tt = TROOP_TYPES[activeTroop]
        if tt then
            DrawTextOutlined(cbX + cbSz + 8, oy + rowH / 2 + 10, tt.name, 18, 160, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        end

        -- 整行点击区域 (用于切换勾选)
        st._transferHeroCheckRects[hIdx] = { x = rpX + pad, y = oy + 2, w = innerW, h = rowH - 4 }

        ::continue_th::
    end
    nvgRestore(vg)

    -- 滚动条
    if totalH > listH then
        local barH = math.max(12, listH * (listH / totalH))
        local barY = curY + (scrollOff / maxScroll) * (listH - barH)
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + rpW - pad, barY, 3, barH, 1.5)
        nvgFillColor(vg, nvgRGBA(200, 170, 100, 100)); nvgFill(vg)
    end

    -- 存储滚动区域供触摸拖拽使用
    st._transferHeroScrollArea = { x = rpX, y = curY, w = rpW, h = listH }
    st._transferHeroTotalH = totalH

    -- 确认调兵按钮
    local confirmY = curY + listH + 4
    local confirmEnabled = selectedCount > 0
    local cr, cg, cb = 60, 120, 50
    if not confirmEnabled then cr, cg, cb = 60, 50, 45 end
    st.btn_transferConfirm = DrawBtn(rpX + pad, confirmY, innerW, UI.BTN_H,
        "确认调兵 (" .. selectedCount .. "将)", cr, cg, cb)

    DrawBackBtn(st, rpX, rpY, rpW, rpH, "btn_transferHeroBack", "返回")
end

-- ============================================================================
-- 回合报告面板
-- ============================================================================
function M.DrawTurnReportPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local W, H = DESIGN_W, DESIGN_H
    local Anim = require("ui.anim")

    -- 记录面板打开时刻 (用于逐条揭示动画)
    if not st._reportOpenTime then st._reportOpenTime = t end

    -- 清空按钮状态
    st.btn_newgame = nil
    st.btn_continue = nil

    -- 弹窗进场动画
    local popAge = t - st._reportOpenTime
    local popScale, popAlphaScale = Anim.PopupScaleAlpha(popAge)

    -- === 全屏半透明遮罩 (淡入) ===
    local maskAlpha = math.min(200, math.floor(200 * math.min(1, popAge / 0.2)))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(10, 8, 5, maskAlpha)); nvgFill(vg)

    -- === 居中弹窗 ===
    local popW = math.min(580, W - 40)
    local popH = math.min(510, H - 40)
    local popX = (W - popW) / 2
    local popY = math.max(30, (H - popH) / 2)
    local pad = 16
    local innerW = popW - pad * 2

    -- 弹窗缩放动画
    nvgSave(vg)
    if popScale < 0.999 then
        local cx = popX + popW / 2
        local cy = popY + popH / 2
        nvgTranslate(vg, cx, cy)
        nvgScale(vg, popScale, popScale)
        nvgTranslate(vg, -cx, -cy)
    end

    -- 弹窗背景渐变 (深色卷轴风)
    local bgAlpha = math.floor(240 * popAlphaScale)
    local popGrad = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
        nvgRGBA(45, 28, 12, bgAlpha), nvgRGBA(35, 18, 8, math.floor(250 * popAlphaScale)))
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
    nvgFillPaint(vg, popGrad); nvgFill(vg)
    -- 金色边框
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 80, math.floor(140 * popAlphaScale))); nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- === 标题 ===
    DrawTextOutlined(popX + popW / 2, popY + 12, "第 " .. (st.turn - 1) .. " 回合 · 战报", 24, 255, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    DrawThinSep(popX + pad, popY + 42, innerW)

    -- === 分类整理报告条目 ===
    local CAT_DEF = {
        { key = "economy",   icon = "💰", title = "经济收入",  types = { income = true } },
        { key = "military",  icon = "⚔",  title = "军事动态",  types = { recruit = true, battle = true, lost = true } },
        { key = "diplomacy", icon = "📜", title = "外交纵横",  types = { diplomacy = true } },
        { key = "alert",     icon = "⚠",  title = "局势警报",  types = { warning = true } },
        { key = "reward",    icon = "🎁", title = "战果奖赏",  types = { reward = true } },
        { key = "fate",      icon = "👑", title = "天命所归",  types = { victory = true, gameover = true } },
    }

    local grouped = {}
    for _, cat in ipairs(CAT_DEF) do grouped[cat.key] = {} end
    local hasEnding = false

    if st.turnReport then
        for _, item in ipairs(st.turnReport) do
            local itype = type(item) == "table" and item.type or "info"
            if itype == "victory" or itype == "gameover" then hasEnding = true end
            local placed = false
            for _, cat in ipairs(CAT_DEF) do
                if cat.types[itype] then
                    table.insert(grouped[cat.key], item)
                    placed = true; break
                end
            end
            if not placed then table.insert(grouped["alert"], item) end
        end
    end

    -- 构建渲染行列表 (分类标题 + 条目)
    local rows = {}
    for _, cat in ipairs(CAT_DEF) do
        local items = grouped[cat.key]
        if #items > 0 then
            table.insert(rows, { kind = "header", icon = cat.icon, title = cat.title, count = #items })
            for _, item in ipairs(items) do
                table.insert(rows, { kind = "item", item = item })
            end
        end
    end

    -- === 可滚动内容区域 ===
    local contentTop = popY + 48
    local btnAreaH = 52
    local contentBot = popY + popH - btnAreaH
    local contentH = contentBot - contentTop
    local headerH = 32
    local itemH = 26

    -- 计算总内容高度
    local totalH = 0
    for _, row in ipairs(rows) do
        totalH = totalH + (row.kind == "header" and headerH or itemH)
    end

    -- 像素级滚动
    local scrollOff = st.reportScroll or 0
    local maxScroll = math.max(0, totalH - contentH)
    scrollOff = math.max(0, math.min(maxScroll, scrollOff))
    st.reportScroll = scrollOff
    st._reportMaxScroll = maxScroll

    nvgSave(vg)
    nvgScissor(vg, popX + pad, contentTop, innerW, contentH)

    if #rows == 0 then
        -- 空报告
        DrawTextOutlined(popX + popW / 2, contentTop + contentH / 2, "本回合风平浪静", 20, 160)
    else
        local curY = contentTop - scrollOff
        local rowIdx = 0
        local revealDelay = 0.12  -- 每行延迟
        local revealDur   = 0.25  -- 单行淡入时长
        local revealBase  = popAge - 0.25  -- 弹窗进场后 0.25s 开始揭示
        for _, row in ipairs(rows) do
            rowIdx = rowIdx + 1
            -- 逐条揭示: 根据行序号计算淡入 alpha
            local rowElapsed = revealBase - (rowIdx - 1) * revealDelay
            local rowAlpha = 1.0
            if rowElapsed < 0 then rowAlpha = 0
            elseif rowElapsed < revealDur then rowAlpha = Anim.easeOutQuad(rowElapsed / revealDur)
            end
            if row.kind == "header" then
                local rh = headerH
                if curY + rh > contentTop - rh and curY < contentBot and rowAlpha > 0 then
                    -- 分类标题底色
                    nvgBeginPath(vg); nvgRoundedRect(vg, popX + pad + 2, curY + 3, innerW - 4, rh - 6, 4)
                    nvgFillColor(vg, nvgRGBA(60, 42, 18, math.floor(180 * rowAlpha))); nvgFill(vg)
                    -- 左侧金色竖条
                    nvgBeginPath(vg); nvgRoundedRect(vg, popX + pad + 2, curY + 5, 4, rh - 10, 2)
                    nvgFillColor(vg, nvgRGBA(220, 180, 60, math.floor(200 * rowAlpha))); nvgFill(vg)

                    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 220, 120, math.floor(240 * rowAlpha)))
                    nvgText(vg, popX + pad + 14, curY + rh / 2, row.icon .. " " .. row.title, nil)

                    -- 计数徽章
                    nvgFontSize(vg, 18)
                    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(180, 160, 120, math.floor(160 * rowAlpha)))
                    nvgText(vg, popX + pad + innerW - 10, curY + rh / 2, "×" .. row.count, nil)
                end
                curY = curY + rh
            else
                -- 条目行
                local rh = itemH
                if curY + rh > contentTop - rh and curY < contentBot and rowAlpha > 0 then
                    local item = row.item
                    local text = type(item) == "table" and item.text or tostring(item)
                    local itype = type(item) == "table" and item.type or "info"

                    -- 类型图标
                    local icon = "·"
                    if itype == "income" then icon = "💰"
                    elseif itype == "recruit" then icon = "⚔"
                    elseif itype == "battle" then icon = "🏴"
                    elseif itype == "lost" then icon = "🔥"
                    elseif itype == "warning" then icon = "⚠"
                    elseif itype == "diplomacy" then icon = "📜"
                    elseif itype == "victory" then icon = "👑"
                    elseif itype == "gameover" then icon = "💀"
                    elseif itype == "reward" then icon = "🎁"
                    end

                    -- 类型颜色
                    local r, g, b, a = 200, 190, 170, 210
                    if itype == "lost" or itype == "gameover" then r, g, b, a = 220, 60, 50, 240
                    elseif itype == "victory" then r, g, b, a = 255, 210, 50, 255
                    elseif itype == "warning" then r, g, b, a = 220, 140, 30, 230
                    elseif itype == "income" or itype == "recruit" then r, g, b, a = 100, 210, 120, 220
                    elseif itype == "diplomacy" then r, g, b, a = 120, 150, 230, 220
                    elseif itype == "reward" then r, g, b, a = 240, 190, 70, 255
                    elseif itype == "battle" then r, g, b, a = 230, 180, 100, 230
                    end

                    -- 重要事件高亮底色
                    if itype == "victory" then
                        nvgBeginPath(vg); nvgRoundedRect(vg, popX + pad + 4, curY + 1, innerW - 8, rh - 2, 3)
                        nvgFillColor(vg, nvgRGBA(120, 100, 20, math.floor(50 * rowAlpha))); nvgFill(vg)
                    elseif itype == "gameover" then
                        nvgBeginPath(vg); nvgRoundedRect(vg, popX + pad + 4, curY + 1, innerW - 8, rh - 2, 3)
                        nvgFillColor(vg, nvgRGBA(120, 20, 10, math.floor(50 * rowAlpha))); nvgFill(vg)
                    end

                    -- 左侧分类色条
                    local barR, barG, barB = r, g, b
                    if itype == "income" then barR, barG, barB = 50, 180, 80
                    elseif itype == "recruit" then barR, barG, barB = 80, 160, 220
                    elseif itype == "battle" then barR, barG, barB = 220, 160, 50
                    elseif itype == "lost" then barR, barG, barB = 200, 40, 30
                    elseif itype == "warning" then barR, barG, barB = 220, 140, 30
                    elseif itype == "diplomacy" then barR, barG, barB = 100, 120, 210
                    elseif itype == "victory" then barR, barG, barB = 255, 210, 50
                    elseif itype == "gameover" then barR, barG, barB = 180, 30, 20
                    elseif itype == "reward" then barR, barG, barB = 230, 180, 50
                    end
                    nvgBeginPath(vg); nvgRoundedRect(vg, popX + pad + 4, curY + 3, 3, rh - 6, 1.5)
                    nvgFillColor(vg, nvgRGBA(barR, barG, barB, math.floor(220 * rowAlpha))); nvgFill(vg)

                    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(r, g, b, math.floor(a * rowAlpha)))
                    -- 裁切防溢出
                    nvgSave(vg)
                    nvgIntersectScissor(vg, popX + pad + 10, curY, innerW - 16, rh)
                    nvgText(vg, popX + pad + 14, curY + rh / 2, icon .. " " .. text, nil)
                    nvgRestore(vg)
                end
                curY = curY + rh
            end
        end
    end

    nvgRestore(vg) -- 恢复内容区裁切

    -- 滚动指示条
    if maxScroll > 0 then
        local barH = math.max(20, contentH * contentH / totalH)
        local barY = contentTop + (contentH - barH) * (scrollOff / maxScroll)
        nvgBeginPath(vg); nvgRoundedRect(vg, popX + popW - pad - 5, barY, 4, barH, 2)
        nvgFillColor(vg, nvgRGBA(180, 150, 80, 100)); nvgFill(vg)
    end

    -- === 底部按钮 ===
    if hasEnding then
        local btnW2 = 110
        local btnGap = 20
        local totalBtnW = btnW2 * 2 + btnGap
        local startX = popX + (popW - totalBtnW) / 2
        local btnY2 = popY + popH - 44
        st.btn_newgame  = DrawBtn(startX, btnY2, btnW2, 36, "重新开始", 100, 80, 45)
        st.btn_continue = DrawBtn(startX + btnW2 + btnGap, btnY2, btnW2, 36, "继 续", 100, 80, 45)
    else
        st.btn_continue = DrawBtn(popX + popW / 2 - 56, popY + popH - 44, 112, 36, "继 续", 100, 80, 45)
    end

    nvgRestore(vg) -- 闭合弹窗缩放变换
end

-- ============================================================================
-- 招降面板
-- ============================================================================
function M.DrawSurrenderPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local W, H = DESIGN_W, DESIGN_H

    if not st.surrenderCurrentIdx then st.surrenderCurrentIdx = 1 end

    local heroes = st.capturedHeroes or {}
    local results = st.surrenderResults or {}

    st.btn_surrender_action = nil
    st.btn_release_action = nil
    st.btn_execute_action = nil
    st.btn_surrender_next = nil
    st.btn_surrenderDone = nil

    -- === 全屏半透明遮罩 ===
    nvgSave(vg)
    nvgResetScissor(vg)

    -- 弹窗弹入动画
    local AnimS = require("ui.anim")
    if not st._surrenderOpenTime then st._surrenderOpenTime = t end
    local sPopAge = t - st._surrenderOpenTime
    local sPopScale, sPopAlphaScale = AnimS.PopupScaleAlpha(sPopAge)
    local sMaskAlpha = math.min(160, math.floor(160 * math.min(1, sPopAge / 0.2)))

    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, sMaskAlpha)); nvgFill(vg)

    -- === 居中弹窗 ===
    local popW = math.min(420, W - 40)
    local popH = math.min(490, H - 80)
    local popX = (W - popW) / 2
    local popY = math.max(62, (H - popH) / 2)
    local pad = 16
    local innerW = popW - pad * 2

    -- 弹窗缩放变换
    nvgSave(vg)
    if sPopScale < 0.999 then
        local sCx = popX + popW / 2; local sCy = popY + popH / 2
        nvgTranslate(vg, sCx, sCy); nvgScale(vg, sPopScale, sPopScale); nvgTranslate(vg, -sCx, -sCy)
    end

    -- 弹窗背景 (深色卷轴风)
    local popGrad = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
        nvgRGBA(45, 28, 12, math.floor(240 * sPopAlphaScale)),
        nvgRGBA(35, 18, 8, math.floor(250 * sPopAlphaScale)))
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
    nvgFillPaint(vg, popGrad); nvgFill(vg)
    -- 金色边框
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 80, math.floor(140 * sPopAlphaScale)))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- === 标题 ===
    DrawTextOutlined(popX + popW / 2, popY + 18, "俘获敌将", 22, 255)

    if #heroes > 0 then
        local dispIdx = math.min(st.surrenderCurrentIdx, #heroes)
        DrawTextOutlined(popX + popW / 2, popY + 42, dispIdx .. " / " .. #heroes, 18, 160)
    end

    DrawThinSep(popX + pad, popY + 56, innerW)

    -- === 空列表 / 处理完毕 ===
    if #heroes == 0 then
        DrawTextOutlined(popX + popW / 2, popY + popH / 2, "无俘获武将", 22, 160)
        st.btn_surrenderDone = DrawBtn(popX + popW / 2 - 52, popY + popH - 50, 104, 36, "继 续", 100, 80, 45)
        nvgRestore(vg)
        return
    end

    if st.surrenderCurrentIdx > #heroes then
        DrawTextOutlined(popX + popW / 2, popY + popH / 2 - 16, "所有武将已处理完毕", 22, 220)
        st.btn_surrenderDone = DrawBtn(popX + popW / 2 - 52, popY + popH - 50, 104, 36, "继 续", 100, 80, 45)
        nvgRestore(vg)
        return
    end

    local idx = st.surrenderCurrentIdx
    local hIdx = heroes[idx]
    local card = HERO_CARDS[hIdx]
    if not card then st.surrenderCurrentIdx = idx + 1; nvgRestore(vg); return end

    local result = results[hIdx]
    local qColors = {
        [1] = {180,180,180}, [2] = {100,200,100}, [3] = {80,140,255},
        [4] = {200,100,255}, [5] = {255,200,50},
    }
    local qNames = { [1] = "人武灵", [2] = "地武灵", [3] = "天武灵", [4] = "神武灵", [5] = "限定武灵" }
    local qc = qColors[card.quality] or {200,200,200}

    -- === 左侧: 武将正式卡牌 ===
    local heroCardW = 120
    local heroCardH = 160
    local heroCardX = popX + pad
    local heroCardY = popY + 68
    local hero = playerHeroes and playerHeroes[hIdx]
    local cons = hero and hero.constellation or 0
    DrawInventoryCard(heroCardX, heroCardY, heroCardW, heroCardH, card, cons, false, true)

    -- === 右侧: 名字 + 品质 + 阵营兵种 + 五维 ===
    local infoX = heroCardX + heroCardW + 14
    local infoW = popX + popW - pad - infoX
    local curY = heroCardY

    -- 武将名 (大字)
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
    nvgText(vg, infoX, curY, card.name, nil)
    curY = curY + 28

    -- 品质 + 阵营 + 兵种
    local facName = card.faction and GetFacName(card.faction) or ""
    local troopName = card.troopType and TROOP_TYPES[card.troopType] and TROOP_TYPES[card.troopType].name or ""
    DrawTextOutlined(infoX, curY, (qNames[card.quality] or "") .. " · " .. facName, 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 24
    DrawTextOutlined(infoX, curY, "兵种: " .. troopName, 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    curY = curY + 28

    -- 五维属性 (带进度条)
    local s5 = card.stats5 or { str = 50, int = 50, vit = 50, tec = 50, spd = 50 }
    local stats5Defs = {
        { label = "武", val = s5.str, clr = {255, 140, 100} },
        { label = "智", val = s5.int, clr = {120, 180, 255} },
        { label = "体", val = s5.vit, clr = {100, 220, 130} },
        { label = "技", val = s5.tec, clr = {255, 210, 80} },
        { label = "速", val = s5.spd, clr = {100, 220, 200} },
    }
    local barW = infoW - 50
    for _, attr in ipairs(stats5Defs) do
        DrawTextOutlined(infoX, curY, attr.label, 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        DrawTextOutlined(infoX + 18, curY, tostring(attr.val), 18, 240, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        DrawProgressBar(infoX + 42, curY + 5, barW, 5, attr.val / 100,
            nvgRGBA(attr.clr[1], attr.clr[2], attr.clr[3], 180))
        curY = curY + 20
    end

    -- === 武技 (卡牌下方，横跨全宽) ===
    local skillAreaY = heroCardY + heroCardH + 10
    if card.skill then
        DrawTextOutlined(popX + pad, skillAreaY, "武技: " .. card.skill, 18, 220, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        if card.skillData and card.skillData.desc then
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 160))
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgSave(vg)
            nvgIntersectScissor(vg, popX + pad, skillAreaY + 22, innerW, 40)
            nvgTextBox(vg, popX + pad, skillAreaY + 22, innerW, card.skillData.desc, nil)
            nvgRestore(vg)
        end
        skillAreaY = skillAreaY + 62
    else
        skillAreaY = skillAreaY + 4
    end

    DrawThinSep(popX + pad, skillAreaY, innerW)

    -- === 对话框 (如有) ===
    local btnAreaY = skillAreaY + 8
    if st.surrenderDialogue then
        local dlgY = btnAreaY
        local dlgW = innerW
        local dlgH = 70

        nvgBeginPath(vg); nvgRoundedRect(vg, popX + pad, dlgY, dlgW, dlgH, 5)
        nvgFillColor(vg, nvgRGBA(50, 35, 20, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 170, 100, 60))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        DrawTextOutlined(popX + pad + 8, dlgY + 6, card.name .. ":", 18, 220, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgSave(vg)
        nvgIntersectScissor(vg, popX + pad + 8, dlgY + 26, dlgW - 16, dlgH - 30)
        nvgTextBox(vg, popX + pad + 8, dlgY + 26, dlgW - 16, st.surrenderDialogue, nil)
        nvgRestore(vg)

        btnAreaY = dlgY + dlgH + 10
    end

    -- === 操作按钮 / 结果 ===
    if result == nil then
        local btnW = 100
        local btnH = 38
        local spacing = 12
        local totalBtnW = btnW * 3 + spacing * 2
        local startX = popX + (popW - totalBtnW) / 2
        st.btn_surrender_action = DrawBtn(startX, btnAreaY, btnW, btnH, "招 降", 100, 80, 45)
        st.btn_release_action   = DrawBtn(startX + btnW + spacing, btnAreaY, btnW, btnH, "释 放", 55, 50, 48)
        st.btn_execute_action   = DrawBtn(startX + 2 * (btnW + spacing), btnAreaY, btnW, btnH, "处 刑", 130, 40, 35)
    else
        -- 结果显示
        if result == true then
            DrawTextOutlined(popX + popW / 2, btnAreaY + 12, "已归降", 22, 230)
        elseif result == "executed" then
            DrawTextOutlined(popX + popW / 2, btnAreaY + 12, "已处刑", 22, 230)
        elseif result == "refused" then
            DrawTextOutlined(popX + popW / 2, btnAreaY + 12, "拒绝招降", 22, 230)
        else
            DrawTextOutlined(popX + popW / 2, btnAreaY + 12, "已释放", 22, 200)
        end

        if result == "refused" and not st.surrenderDialogue then
            -- 拒绝招降后，仍可选择释放或处刑
            local btnW = 100; local btnH = 38; local spacing = 20
            local totalW = btnW * 2 + spacing
            local startX = popX + (popW - totalW) / 2
            st.btn_release_action  = DrawBtn(startX, btnAreaY + 34, btnW, btnH, "释 放", 55, 50, 48)
            st.btn_execute_action  = DrawBtn(startX + btnW + spacing, btnAreaY + 34, btnW, btnH, "处 刑", 130, 40, 35)
        else
            -- 下一位/完成 按钮
            local isLast = (idx >= #heroes)
            local nextLabel = isLast and "完 成" or "下一位"
            if result == "refused" then nextLabel = "确 认" end
            st.btn_surrender_next = DrawBtn(popX + popW / 2 - 52, btnAreaY + 40, 104, 36, nextLabel, 100, 80, 45)
        end
    end

    nvgRestore(vg)  -- 弹窗缩放变换
    nvgRestore(vg)  -- nvgSave + nvgResetScissor
end

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

-- ============================================================================
-- 战败通报面板 (全军覆没后展示武将命运)
-- ============================================================================
function M.DrawDefeatReportPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local W, H = DESIGN_W, DESIGN_H
    local fates = st.defeatHeroReport or {}

    st.btn_defeatReportDone = nil

    -- 全屏遮罩
    nvgSave(vg)
    nvgResetScissor(vg)

    -- 弹窗弹入动画
    local AnimD = require("ui.anim")
    if not st._defeatRptOpenTime then st._defeatRptOpenTime = t end
    local dPopAge = t - st._defeatRptOpenTime
    local dPopScale, dPopAlphaScale = AnimD.PopupScaleAlpha(dPopAge)
    local dMaskAlpha = math.min(180, math.floor(180 * math.min(1, dPopAge / 0.2)))

    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, dMaskAlpha)); nvgFill(vg)

    -- 居中弹窗
    local popW = math.min(400, W - 40)
    local lineCount = math.max(1, #fates)
    local popH = math.min(120 + lineCount * 56, H - 80)
    local popX = (W - popW) / 2
    local popY = math.max(62, (H - popH) / 2)
    local pad = 16
    local innerW = popW - pad * 2

    -- 弹窗缩放变换
    nvgSave(vg)
    if dPopScale < 0.999 then
        local dCx = popX + popW / 2; local dCy = popY + popH / 2
        nvgTranslate(vg, dCx, dCy); nvgScale(vg, dPopScale, dPopScale); nvgTranslate(vg, -dCx, -dCy)
    end

    -- 背景
    local popGrad = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
        nvgRGBA(50, 15, 10, math.floor(245 * dPopAlphaScale)),
        nvgRGBA(35, 10, 8, math.floor(250 * dPopAlphaScale)))
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
    nvgFillPaint(vg, popGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
    nvgStrokeColor(vg, nvgRGBA(200, 80, 60, math.floor(160 * dPopAlphaScale)))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 标题
    DrawTextOutlined(popX + popW / 2, popY + 18, "全军覆没 - 武将通报", 24, 255)

    DrawThinSep(popX + pad, popY + 42, innerW)

    -- 武将命运列表
    local curY = popY + 52
    if #fates == 0 then
        DrawTextOutlined(popX + popW / 2, popY + popH / 2, "无出征武将", 22, 160)
    else
        for i, info in ipairs(fates) do
            local qc = QUALITY_COLORS[info.quality] or { 200, 195, 180 }
            local lineY = curY + (i - 1) * 56

            -- 武将名 (品质色保留)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
            nvgText(vg, popX + pad, lineY, info.name, nil)

            -- 命运结果
            local fateText
            if info.fate == "recruit" then
                fateText = "被敌军招降"
            else
                fateText = "被敌军处死"
            end
            DrawTextOutlined(popX + popW - pad, lineY, fateText, 22, 240, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)

            -- 分隔线
            if i < #fates then
                DrawThinSep(popX + pad, lineY + 34, innerW)
            end
        end
    end

    -- 确认按钮
    local btnY = popY + popH - 50
    st.btn_defeatReportDone = DrawBtn(popX + popW / 2 - 52, btnY, 104, 36,
        "确  认", 100, 80, 45)

    nvgRestore(vg)   -- 弹窗缩放变换
    nvgRestore(vg)   -- resetScissor
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
