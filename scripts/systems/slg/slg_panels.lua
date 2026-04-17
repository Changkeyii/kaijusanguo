-- ============================================================================
-- slg/slg_panels.lua - 三国武灵传：SLG右侧操作面板 (完全重做)
-- 所有面板在右侧区域绘制 (rpX, rpY, rpW, rpH)
-- ============================================================================

---@diagnostic disable: undefined-global

local Data   = require("systems.slg.slg_data")
local Render = require("systems.slg.slg_render")

local FC         = Data.FC
local STRATAGEMS = Data.STRATAGEMS
local QUESTS     = Data.QUESTS
local BONDS      = Data.BONDS
local CLASS_CHANGES = Data.CLASS_CHANGES

local GetFC            = Render.GetFC
local GetFactionStats  = Render.GetFactionStats
local DrawBtn          = Render.DrawBtn
local DrawIcon         = Render.DrawIcon
local DrawIconText     = Render.DrawIconText
local DrawTriangle     = Render.DrawTriangle
local DrawStar         = Render.DrawStar
local DrawDiamond      = Render.DrawDiamond
local DrawCircleOutline = Render.DrawCircleOutline
local DrawUpDownArrows = Render.DrawUpDownArrows

local M = {}

-- ============================================================================
-- 默认面板: 选中城池信息 + 操作按钮
-- ============================================================================
function M.DrawMapPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10

    if st.selectedCity then
        local city = WORLD_CITIES[st.selectedCity]
        local cd = st.cityData[st.selectedCity]
        if not city or not cd then st.selectedCity = nil; return end
        local isPlayer = (cd.owner == "player")
        local fc = GetFC(cd.owner)
        local facName = isPlayer and "我方" or (FACTIONS[cd.owner] and FACTIONS[cd.owner].name or cd.owner)

        -- 城池标题
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
        nvgText(vg, rpX + pad, rpY + 8, city.name, nil)

        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(fc.light[1], fc.light[2], fc.light[3], 200))
        nvgText(vg, rpX + pad + 70, rpY + 11, facName .. " · " .. city.region, nil)

        -- 分隔线
        local sepY = rpY + 30
        nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 城池详情 (竖排)
        -- 非我方城池: 驻军/城防/士气需刺探后才显示
        local scouted = isPlayer or (st.scoutResult and st.scoutResult.cityId == st.selectedCity)
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(220, 210, 190, 220))
        local infoY = sepY + 8
        local lineH = 20
        if scouted then
            nvgText(vg, rpX + pad, infoY, "驻军: " .. cd.garrison, nil)
            nvgText(vg, rpX + pad + rpW / 2 - 10, infoY, "城防: Lv" .. cd.level, nil)
        else
            nvgText(vg, rpX + pad, infoY, "驻军: ???", nil)
            nvgText(vg, rpX + pad + rpW / 2 - 10, infoY, "城防: ???", nil)
        end
        infoY = infoY + lineH
        nvgText(vg, rpX + pad, infoY, "产出: " .. city.prod, nil)
        if isPlayer then
            nvgText(vg, rpX + pad + rpW / 2 - 10, infoY, "士气: " .. cd.morale, nil)
        elseif scouted then
            nvgText(vg, rpX + pad + rpW / 2 - 10, infoY, "士气: " .. cd.morale, nil)
        end

        -- 武将小图列表 (固定区域 + 滚动)
        infoY = infoY + lineH
        -- 计算底部按钮区域高度 (我方7按钮4行, 敌方2行文字)
        local btnAreaH = isPlayer and (28 * 4 + 4 * 3 + 16) or 50
        local heroAreaTop = infoY
        local heroAreaBot = rpY + rpH - btnAreaH
        local heroAreaH = heroAreaBot - heroAreaTop

        -- 刺探情报 (若有，占据武将区上方一小段)
        local scoutH = 0
        if st.scoutResult and st.scoutResult.cityId == st.selectedCity and not isPlayer then
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 180, 60, 230))
            local sr = st.scoutResult
            nvgText(vg, rpX + pad, infoY, "【情报】兵:" .. sr.garrison .. " 防:Lv" .. sr.level .. " 气:" .. sr.morale, nil)
            scoutH = 16
            if #sr.heroes > 0 then
                nvgTextBox(vg, rpX + pad, infoY + 16, rpW - pad * 2, "将:" .. table.concat(sr.heroes, " "), nil)
                scoutH = 32
            end
        end
        heroAreaTop = heroAreaTop + scoutH
        heroAreaH = heroAreaH - scoutH

        -- 非我方未刺探城池: 隐藏武将信息
        local showHeroes = isPlayer or scouted
        if showHeroes and #cd.heroes > 0 then
            -- 标题行
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(160, 200, 255, 200))
            nvgText(vg, rpX + pad, heroAreaTop, "驻城武将 (" .. #cd.heroes .. ")", nil)
            heroAreaTop = heroAreaTop + 18
            heroAreaH = heroAreaH - 18

            -- 武将卡片网格参数
            local cardW = 58
            local cardH = 72
            local cardGap = 4
            local cols = math.max(1, math.floor((rpW - pad * 2 + cardGap) / (cardW + cardGap)))
            local rows = math.ceil(#cd.heroes / cols)
            local totalContentH = rows * (cardH + cardGap) - cardGap

            -- 滚动状态
            st.mapPanelHeroScroll = st.mapPanelHeroScroll or 0
            local maxScroll = math.max(0, totalContentH - heroAreaH)
            st.mapPanelHeroScroll = math.max(0, math.min(maxScroll, st.mapPanelHeroScroll))
            local scrollOff = st.mapPanelHeroScroll

            -- 裁切绘制区
            nvgSave(vg)
            nvgScissor(vg, rpX, heroAreaTop, rpW, heroAreaH)

            -- 清除旧的面板武将点击区域
            st._mapPanelHeroRects = st._mapPanelHeroRects or {}
            for k in pairs(st._mapPanelHeroRects) do st._mapPanelHeroRects[k] = nil end

            for i, hIdx in ipairs(cd.heroes) do
                local card = HERO_CARDS[hIdx]
                if not card then goto continue_map_hero end
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cx = rpX + pad + col * (cardW + cardGap)
                local cy = heroAreaTop + row * (cardH + cardGap) - scrollOff

                -- 只绘制可见区域
                if cy + cardH >= heroAreaTop and cy < heroAreaTop + heroAreaH then
                    local hero = playerHeroes and playerHeroes[hIdx]
                    local cons = hero and hero.constellation or 0
                    DrawInventoryCard(cx, cy, cardW, cardH, card, cons, false, true)

                    -- 底部名条区域: 显示武将名 (裁切防超框)
                    nvgSave(vg)
                    nvgIntersectScissor(vg, cx, cy + cardH - 16, cardW, 16)
                    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 11)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(240, 230, 200, 240))
                    nvgText(vg, cx + cardW / 2, cy + cardH - 8, card.name, nil)
                    nvgRestore(vg)

                    -- 兵种图标 (左下角)
                    local activeTrp = (st.heroTroopChoice[hIdx] or card.troopType)
                    local tt = activeTrp and TROOP_TYPES[activeTrp]
                    if tt then
                        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 11)
                        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy + cardH - 28, 15, 14, 2)
                        nvgFillColor(vg, nvgRGBA(30, 20, 10, 200)); nvgFill(vg)
                        nvgFillColor(vg, nvgRGBA(tt.color[1], tt.color[2], tt.color[3], 240))
                        nvgText(vg, cx + 7.5, cy + cardH - 21, tt.icon, nil)
                    end

                    -- 存储点击区域 (供 input 模块弹出武将详情)
                    st._mapPanelHeroRects[hIdx] = { x = cx, y = cy, w = cardW, h = cardH }
                end
                ::continue_map_hero::
            end

            nvgRestore(vg)

            -- 滚动条 (内容超出时显示)
            if totalContentH > heroAreaH then
                local barH = math.max(12, heroAreaH * (heroAreaH / totalContentH))
                local barY = heroAreaTop + (scrollOff / maxScroll) * (heroAreaH - barH)
                nvgBeginPath(vg); nvgRoundedRect(vg, rpX + rpW - pad, barY, 3, barH, 1.5)
                nvgFillColor(vg, nvgRGBA(200, 170, 100, 100)); nvgFill(vg)
            end

            -- 记录滚动区域信息供 input 模块使用
            st._mapPanelHeroScrollArea = { x = rpX, y = heroAreaTop, w = rpW, h = heroAreaH }
            st._mapPanelHeroTotalH = totalContentH
        elseif not showHeroes then
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(180, 150, 100, 150))
            nvgText(vg, rpX + pad, heroAreaTop, "情报未知 (需刺探)", nil)
        else
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(160, 140, 120, 150))
            nvgText(vg, rpX + pad, heroAreaTop, "无武将驻守", nil)
        end

        -- 操作按钮 (我方城池)
        if isPlayer then
            local btnW = (rpW - pad * 2 - 4) / 2
            local btnH = 28
            local btnGap = 4
            local btns = {
                {label="内政", key="affairs",    c={60,120,75}},
                {label="外交", key="diplomacy",  c={80,90,150}},
                {label="武将", key="heroes",     c={120,90,40}},
                {label="计略", key="stratagem",  c={140,80,60}},
                {label="建设", key="buildings",  c={100,120,50}},
                {label="任务", key="quests",     c={130,100,140}},
                {label="调兵", key="move",       c={70,110,160}},
                {label="出征", key="attack",     c={170,55,40}},
            }
            local rows = math.ceil(#btns / 2)
            local btnStartY = rpY + rpH - (btnH * rows + btnGap * (rows - 1)) - 8
            for i, btn in ipairs(btns) do
                local col = (i - 1) % 2
                local row = math.floor((i - 1) / 2)
                local bx = rpX + pad + col * (btnW + 4)
                local by = btnStartY + row * (btnH + btnGap)
                st["btn_" .. btn.key] = DrawBtn(bx, by, btnW, btnH, btn.label, btn.c[1], btn.c[2], btn.c[3])
            end
        else
            -- 敌方城池提示
            nvgFontSize(vg, 13)
            nvgFillColor(vg, nvgRGBA(200, 160, 100, 180))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(vg, rpX + rpW / 2, rpY + rpH - 40, "敌方城池", nil)
            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(180, 150, 110, 150))
            nvgText(vg, rpX + rpW / 2, rpY + rpH - 22, "从相邻我方城池出征攻取", nil)
        end
    else
        -- 未选中城池
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 150, 160))
        nvgText(vg, rpX + rpW / 2, rpY + rpH / 2 - 10, "← 点击左侧城池", nil)
        nvgFontSize(vg, 13)
        nvgText(vg, rpX + rpW / 2, rpY + rpH / 2 + 12, "查看详情与操作", nil)
    end
end

-- ============================================================================
-- 内政面板
-- ============================================================================
function M.DrawAffairsPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    local cityId = st.affairsCity
    if not cityId then st.phase = "MAP"; return end
    local city, cd = WORLD_CITIES[cityId], st.cityData[cityId]
    if not city or not cd then st.phase = "MAP"; return end

    -- 标题
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, rpX + pad, rpY + 8, city.name .. " · 内政", nil)

    -- 资源一行
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
    nvgText(vg, rpX + pad, rpY + 28, "金:" .. st.gold .. " 粮:" .. st.food .. " 兵:" .. cd.garrison .. " 气:" .. cd.morale, nil)

    -- 分隔线
    local sepY = rpY + 44
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 操作列表 (每项: 描述 + 按钮)
    local reinforceAmt = 30
    local reinforceGold = reinforceAmt * 5
    local reinforceFood = reinforceAmt
    local ops = {
        {label="征兵+50", desc="150金+50粮", key="recruit",
         enabled=st.gold>=150 and st.food>=50, color={60,130,75}},
        {label="补兵+"..reinforceAmt, desc=reinforceGold.."金+"..reinforceFood.."粮 (快速)", key="reinforce",
         enabled=st.gold>=reinforceGold and st.food>=reinforceFood, color={80,140,80}},
        {label="升级城防", desc="Lv"..cd.level.."→"..math.min(5,cd.level+1).." "..(cd.level*200).."金",
         key="upgrade", enabled=cd.level<5 and st.gold>=cd.level*200, color={70,100,160}},
        {label="搜索人才", desc="100金 (20%发现)", key="search",
         enabled=st.gold>=100, color={140,100,60}},
        {label="犒赏三军", desc="80金 士气+15", key="morale",
         enabled=st.gold>=80 and cd.morale<95, color={160,120,40}},
    }

    local rowH = 38
    local btnW = 80
    local btnH = 26
    local startY = sepY + 6

    for i, op in ipairs(ops) do
        local oy = startY + (i - 1) * rowH
        -- 描述
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 190, 170, op.enabled and 220 or 120))
        nvgText(vg, rpX + pad, oy + rowH / 2, op.desc, nil)
        -- 按钮
        local bx = rpX + rpW - pad - btnW
        local by = oy + (rowH - btnH) / 2
        if op.enabled then
            st["btn_" .. op.key] = DrawBtn(bx, by, btnW, btnH, op.label, op.color[1], op.color[2], op.color[3])
        else
            st["btn_" .. op.key] = DrawBtn(bx, by, btnW, btnH, op.label, 60, 60, 60, 120)
        end
    end

    -- 搜索结果
    if st.searchResult then
        local card = HERO_CARDS[st.searchResult.heroIdx]
        if card then
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 60, 255))
            nvgText(vg, rpX + rpW / 2, startY + 4 * rowH + 8, "发现人才: " .. card.name .. "!", nil)
        end
    end

    -- 返回按钮
    st.btn_affairsBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "返回", 60, 55, 50)
end

-- ============================================================================
-- 外交面板
-- ============================================================================
function M.DrawDiplomacyPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    diploBtnRects = {}  -- 重置按钮rects

    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, rpX + pad, rpY + 8, "外交", nil)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
    nvgText(vg, rpX + pad + 50, rpY + 10, "金:" .. st.gold, nil)

    local sepY = rpY + 30
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local startY = sepY + 6
    local rowH = 82  -- 增加行高容纳更多按钮
    local factions = {"wei", "shu", "qun"}
    local fs = GetFactionStats()

    for i, fac in ipairs(factions) do
        local d = st.diplomacy[fac] or {relation=0, treaty=nil}
        local fy = startY + (i - 1) * rowH
        local facInfo = FACTIONS[fac]
        local fc = GetFC(fac)
        local facCities = fs[fac] and fs[fac].cities or 0

        -- 已投降势力特殊显示
        if d.treaty == "surrendered" then
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(fc.light[1], fc.light[2], fc.light[3], 120))
            nvgText(vg, rpX + pad, fy, facInfo.name, nil)
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(80, 200, 100, 180))
            nvgText(vg, rpX + pad + 35, fy + 2, "[已归顺]", nil)
            -- 分隔线
            local sepFy = fy + rowH - 4
            nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepFy); nvgLineTo(vg, rpX + rpW - pad, sepFy)
            nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 30)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
            goto continue_draw
        end

        -- 阵营名
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(fc.light[1], fc.light[2], fc.light[3], 240))
        nvgText(vg, rpX + pad, fy, facInfo.name, nil)

        -- 关系条
        local barX = rpX + pad + 30
        local barW2, barH2 = 70, 5
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, fy + 5, barW2, barH2, 2)
        nvgFillColor(vg, nvgRGBA(80, 60, 40, 100)); nvgFill(vg)
        local rel = d.relation / 100
        local relColor = rel > 0.7 and {60, 180, 80} or (rel > 0.4 and {200, 180, 40} or {200, 60, 40})
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, fy + 5, barW2 * rel, barH2, 2)
        nvgFillColor(vg, nvgRGBA(relColor[1], relColor[2], relColor[3], 200)); nvgFill(vg)

        -- 好感数值
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
        nvgText(vg, barX + barW2 + 3, fy + 1, tostring(d.relation), nil)

        -- 当前条约状态标签
        if d.treaty then
            local td = TREATY_DEFS[d.treaty]
            if td then
                nvgFillColor(vg, nvgRGBA(td.color[1], td.color[2], td.color[3], 230))
                nvgText(vg, barX + barW2 + 20, fy + 1, "[" .. td.name .. "]", nil)
            end
        end

        -- 城数
        nvgFillColor(vg, nvgRGBA(180, 170, 150, 170))
        nvgText(vg, rpX + rpW - pad - 28, fy + 1, "城:" .. facCities, nil)

        -- 按钮行1: 送礼
        local btnW2, btnH2 = 70, 20
        local btnY1 = fy + 16
        st["btn_gift_" .. fac] = DrawBtn(rpX + pad, btnY1, btnW2, btnH2, "送礼200金",
            80, 100, 60, st.gold >= 200 and 200 or 100)

        -- 按钮行1: 升级条约 (动态显示下一级)
        local nextTreaty = WorldMap.GetNextTreaty(fac)
        if nextTreaty then
            local ntd = TREATY_DEFS[nextTreaty]
            if ntd then
                local canUpgrade = d.relation >= ntd.reqRelation and st.gold >= ntd.cost
                local preOk = not ntd.reqTreaty or d.treaty == ntd.reqTreaty
                local btnLabel = ntd.name .. ntd.cost .. "金"
                local btnAlpha = (canUpgrade and preOk) and 200 or 100
                local btnRect = DrawBtn(rpX + pad + btnW2 + 4, btnY1, btnW2 + 10, btnH2, btnLabel,
                    math.floor(ntd.color[1] * 0.4), math.floor(ntd.color[2] * 0.4), math.floor(ntd.color[3] * 0.4), btnAlpha)
                diploBtnRects["upgrade_" .. fac] = btnRect
                diploBtnRects["upgrade_" .. fac .. "_treaty"] = nextTreaty
            end
        else
            diploBtnRects["upgrade_" .. fac] = nil
        end

        -- 按钮行2: 劝降 (条件: 城≤2, 好感≥70)
        local btnY2 = btnY1 + btnH2 + 3
        local sd = SURRENDER_DEFS
        if facCities > 0 and facCities <= sd.reqMaxCities and d.relation >= sd.reqRelation then
            local chance = sd.successBase + d.relation * sd.relationBonus - facCities * sd.cityPenalty
            chance = math.max(0.10, math.min(0.95, chance))
            local pctText = math.floor(chance * 100) .. "%"
            local surrLabel = "劝降(" .. pctText .. ") " .. sd.costGold .. "金"
            local canSurr = st.gold >= sd.costGold
            local surrRect = DrawBtn(rpX + pad, btnY2, rpW - pad * 2, btnH2, surrLabel,
                160, 60, 40, canSurr and 220 or 100)
            diploBtnRects["surrender_" .. fac] = surrRect
        else
            diploBtnRects["surrender_" .. fac] = nil
            -- 显示劝降条件提示
            if facCities > 0 then
                nvgFontSize(vg, 9)
                nvgFillColor(vg, nvgRGBA(150, 140, 120, 120))
                local hint = ""
                if facCities > sd.reqMaxCities then
                    hint = "劝降需城≤" .. sd.reqMaxCities .. "(当前" .. facCities .. ")"
                elseif d.relation < sd.reqRelation then
                    hint = "劝降需好感≥" .. sd.reqRelation .. "(当前" .. d.relation .. ")"
                end
                if hint ~= "" then
                    nvgSave(vg)
                    nvgScissor(vg, rpX + pad, btnY2, rpW - pad * 2, 16)
                    nvgText(vg, rpX + pad, btnY2 + 3, hint, nil)
                    nvgRestore(vg)
                end
            end
        end

        -- 分隔线
        local sepFy = fy + rowH - 4
        nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepFy); nvgLineTo(vg, rpX + rpW - pad, sepFy)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 30)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

        ::continue_draw::
    end

    st.btn_diploBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "返回", 60, 55, 50)
end

-- ============================================================================
-- 计略面板
-- ============================================================================
function M.DrawStratagemPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10

    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, rpX + pad, rpY + 8, "计略", nil)

    -- 目标
    local tgtId = st.stratagemTarget
    local tgtName = "未选择"
    if tgtId then
        local tc = WORLD_CITIES[tgtId]
        if tc then tgtName = tc.name end
    end
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
    nvgText(vg, rpX + pad + 50, rpY + 10, "金:" .. st.gold .. "  目标:" .. tgtName, nil)

    local sepY = rpY + 30
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 提示: 从左侧列表选择敌方城池
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(255, 200, 100, 180))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgText(vg, rpX + pad, sepY + 4, "← 点击左侧敌方城池选目标", nil)

    -- 计略列表
    local startY = sepY + 22
    local btnW3, btnH3 = rpW - pad * 2, 32
    local gap = 5

    for i, strat in ipairs(STRATAGEMS) do
        local by = startY + (i - 1) * (btnH3 + gap)
        local canUse = (tgtId ~= nil and st.gold >= strat.cost)

        -- 背景卡片
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, by, btnW3, btnH3, 4)
        nvgFillColor(vg, nvgRGBA(60, 40, 20, canUse and 80 or 40)); nvgFill(vg)

        -- 计略名 + 图标
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, canUse and nvgRGBA(255, 230, 170, 240) or nvgRGBA(150, 130, 100, 130))
        nvgText(vg, rpX + pad + 6, by + btnH3 / 2, strat.icon .. " " .. strat.name, nil)

        -- 描述
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(180, 170, 150, canUse and 180 or 100))
        nvgTextBox(vg, rpX + pad + 70, by + btnH3 / 2 - 6, rpW - pad - 70 - pad, strat.desc, nil)
        nvgText(vg, rpX + pad + 70, by + btnH3 / 2 + 6, strat.cost .. "金 成功率" .. math.floor(strat.successRate * 100) .. "%", nil)

        -- 点击区域
        if canUse then
            st["btn_strat_" .. strat.id] = { x = rpX + pad, y = by, w = btnW3, h = btnH3 }
        else
            st["btn_strat_" .. strat.id] = nil
        end
    end

    st.btn_stratBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "返回", 60, 55, 50)
end

-- ============================================================================
-- 调兵面板
-- ============================================================================
function M.DrawMoveSelectPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    local fromCity = WORLD_CITIES[st.selectedCity]
    if not fromCity then st.phase = "MAP"; return end

    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, rpX + pad, rpY + 8, fromCity.name .. " · 调兵", nil)

    local sepY = rpY + 30
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 可选目标列表 (相邻我方城池)
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
    nvgText(vg, rpX + pad, sepY + 6, "← 点击左侧相邻我方城池调兵", nil)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(180, 170, 150, 160))
    nvgText(vg, rpX + pad, sepY + 24, "(调50%兵力+全部武将)", nil)

    -- 列出可选目标
    local startY = sepY + 46
    local targets = {}
    for _, connId in ipairs(fromCity.conn) do
        local cd = st.cityData[connId]
        if cd.owner == "player" and connId ~= st.selectedCity then
            table.insert(targets, {id = connId, city = WORLD_CITIES[connId], cd = cd})
        end
    end

    if #targets > 0 then
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(160, 200, 255, 200))
        nvgText(vg, rpX + pad, startY, "可调往:", nil)
        for i, tgt in ipairs(targets) do
            nvgFillColor(vg, nvgRGBA(220, 210, 190, 200))
            nvgText(vg, rpX + pad + 10, startY + i * 18, "· " .. tgt.city.name .. " (兵:" .. tgt.cd.garrison .. ")", nil)
        end
    else
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(200, 100, 60, 200))
        nvgText(vg, rpX + pad, startY, "无相邻我方城池可调兵", nil)
    end

    st.btn_moveBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "取消", 60, 55, 50)
end

-- ============================================================================
-- 攻击目标选择面板
-- ============================================================================
function M.DrawAtkTargetPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    local fromCity = WORLD_CITIES[st.selectedCity]
    if not fromCity then st.phase = "MAP"; return end

    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 160, 80, 255))
    nvgText(vg, rpX + pad, rpY + 8, fromCity.name .. " · 出征", nil)

    local sepY = rpY + 30
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(255, 200, 100, 200))
    nvgText(vg, rpX + pad, sepY + 6, "选择攻击目标:", nil)

    -- 列出可攻击敌城
    local enemies = {}
    for _, connId in ipairs(fromCity.conn) do
        local cd = st.cityData[connId]
        if cd.owner ~= "player" then table.insert(enemies, connId) end
    end

    local startY = sepY + 28
    local cardH2 = 44
    local gap = 4
    st._atkTargetRects = st._atkTargetRects or {}
    for k in pairs(st._atkTargetRects) do st._atkTargetRects[k] = nil end

    for i, eid in ipairs(enemies) do
        local ec = WORLD_CITIES[eid]
        local ed = st.cityData[eid]
        local efc = GetFC(ed.owner)
        local cy = startY + (i - 1) * (cardH2 + gap)

        -- 卡片背景
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, cy, rpW - pad * 2, cardH2, 5)
        nvgFillColor(vg, nvgRGBA(efc.main[1], efc.main[2], efc.main[3], 50)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(efc.main[1], efc.main[2], efc.main[3], 100))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 阵营色条
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, cy + 4, 4, cardH2 - 8, 2)
        nvgFillColor(vg, nvgRGBA(efc.main[1], efc.main[2], efc.main[3], 220)); nvgFill(vg)

        -- 城池名
        nvgFontSize(vg, 15)
        nvgFillColor(vg, nvgRGBA(240, 225, 190, 230))
        nvgText(vg, rpX + pad + 12, cy + 6, ec.name, nil)
        -- 阵营
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(efc.light[1], efc.light[2], efc.light[3], 180))
        local eFacName = FACTIONS[ed.owner] and FACTIONS[ed.owner].name or ed.owner
        nvgText(vg, rpX + pad + 60, cy + 8, eFacName, nil)
        -- 兵力
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
        nvgText(vg, rpX + pad + 12, cy + 26, "兵:" .. ed.garrison .. " 防:Lv" .. ed.level, nil)

        st._atkTargetRects[eid] = { x = rpX + pad, y = cy, w = rpW - pad * 2, h = cardH2 }
    end

    st.btn_atkTargetBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "取消", 60, 55, 50)
end

-- ============================================================================
-- 战前部署面板
-- ============================================================================
function M.DrawDeployPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    if not st.selectedCity or not st.targetCity then st.phase = "MAP"; return end
    local fromCity, toCity = WORLD_CITIES[st.selectedCity], WORLD_CITIES[st.targetCity]
    local fromData, toData = st.cityData[st.selectedCity], st.cityData[st.targetCity]
    if not fromCity or not toCity then st.phase = "MAP"; return end

    local defFac = toData.owner
    local defFacName = FACTIONS[defFac] and FACTIONS[defFac].name or defFac
    local dfc = GetFC(defFac)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 160, 80, 255))
    nvgText(vg, rpX + pad, rpY + 8, "战前部署", nil)

    -- 对阵信息
    local sepY = rpY + 28
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(180, 220, 120, 240))
    nvgText(vg, rpX + pad, sepY, fromCity.name, nil)
    nvgFillColor(vg, nvgRGBA(200, 180, 150, 200))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawIcon(IMG.slgIconSword, rpX + rpW / 2, sepY + 7, 16)
    -- nvgText placeholder removed (was ⚔)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(dfc.light[1], dfc.light[2], dfc.light[3], 240))
    nvgText(vg, rpX + rpW - pad, sepY, toCity.name .. "(" .. defFacName .. ")", nil)

    -- 兵力条
    local barY3 = sepY + 18
    local barW = rpW - pad * 2
    local barH3 = 8
    local totalForce = fromData.garrison + toData.garrison + 1
    local atkRatio = fromData.garrison / totalForce
    nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, barY3, barW * atkRatio, barH3, 3)
    nvgFillColor(vg, nvgRGBA(FC.player.main[1], FC.player.main[2], FC.player.main[3], 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad + barW * atkRatio, barY3, barW * (1 - atkRatio), barH3, 3)
    nvgFillColor(vg, nvgRGBA(dfc.main[1], dfc.main[2], dfc.main[3], 200)); nvgFill(vg)
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgText(vg, rpX + pad + 3, barY3 + barH3 / 2, tostring(fromData.garrison), nil)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg, rpX + rpW - pad - 3, barY3 + barH3 / 2, tostring(toData.garrison), nil)

    -- 兵力选择
    local ratioY = barY3 + barH3 + 10
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
    nvgText(vg, rpX + pad, ratioY, "出征兵力:", nil)

    local ratios = {{label="30%",ratio=0.3},{label="50%",ratio=0.5},{label="70%",ratio=0.7}}
    local rbtnW = (rpW - pad * 2 - 8) / 3
    local rbtnH = 24
    local rbtnY = ratioY + 18
    if st.deployTroops == 0 then st.deployTroops = math.floor(fromData.garrison * 0.5) end
    for i, r in ipairs(ratios) do
        local troops = math.floor(fromData.garrison * r.ratio)
        local isActive = (st.deployTroops == troops)
        local bx2 = rpX + pad + (i - 1) * (rbtnW + 4)
        if isActive then
            st["btn_ratio" .. i] = DrawBtn(bx2, rbtnY, rbtnW, rbtnH, r.label.."("..troops..")", 180, 140, 40)
        else
            st["btn_ratio" .. i] = DrawBtn(bx2, rbtnY, rbtnW, rbtnH, r.label.."("..troops..")", 60, 55, 50)
        end
    end

    -- 粮草
    local foodCost = math.floor(st.deployTroops * 0.5)
    local foodY = rbtnY + rbtnH + 8
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, st.food >= foodCost and nvgRGBA(140, 220, 100, 200) or nvgRGBA(255, 80, 60, 220))
    nvgText(vg, rpX + pad, foodY, "粮草:" .. foodCost .. " (现有:" .. st.food .. ")", nil)

    -- 阵型选择
    local formY = foodY + 18
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(255, 220, 140, 220))
    nvgText(vg, rpX + pad, formY, "阵型:", nil)

    local fbtnW = (rpW - pad * 2 - 6) / 2
    local fbtnH = 22
    local fbtnY = formY + 16
    formationBtnRects = {}
    for fi, fkey in ipairs(FORMATION_LIST) do
        local fd = FORMATION_DEFS[fkey]
        local col = (fi - 1) % 2
        local row = math.floor((fi - 1) / 2)
        local bx = rpX + pad + col * (fbtnW + 6)
        local by = fbtnY + row * (fbtnH + 3)
        local isActive = (playerFormation == fkey)

        -- 按钮背景
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, fbtnW, fbtnH, 4)
        if isActive then
            nvgFillColor(vg, nvgRGBA(fd.color[1], fd.color[2], fd.color[3], 100)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(fd.color[1], fd.color[2], fd.color[3], 220))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        else
            nvgFillColor(vg, nvgRGBA(50, 40, 25, 80)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(120, 100, 60, 80))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end

        -- 图标 + 名称
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive
            and nvgRGBA(fd.color[1], fd.color[2], fd.color[3], 255)
            or nvgRGBA(180, 170, 140, 180))
        nvgText(vg, bx + fbtnW / 2, by + fbtnH / 2, fd.icon .. fd.name, nil)

        formationBtnRects[fi] = { x = bx, y = by, w = fbtnW, h = fbtnH, key = fkey }
    end

    -- 阵型加成提示
    local curForm = FORMATION_DEFS[playerFormation]
    if curForm then
        local formInfoY = fbtnY + 2 * (fbtnH + 3) + 2
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(curForm.color[1], curForm.color[2], curForm.color[3], 180))
        nvgText(vg, rpX + pad, formInfoY, curForm.desc, nil)
    end

    -- 武将 (简化列表)
    local heroY = fbtnY + 2 * (fbtnH + 3) + 16
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    if #fromData.heroes > 0 then
        nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
        nvgText(vg, rpX + pad, heroY, "武将(点击出战):", nil)
        local cardW2, cardH2 = 52, 70
        local cardGap2 = 4
        local cardStartY2 = heroY + 18
        local maxCards = math.min(#fromData.heroes, 4)
        for i = 1, maxCards do
            local hIdx = fromData.heroes[i]
            local card = HERO_CARDS[hIdx]
            if card then
                local cx = rpX + pad + (i - 1) * (cardW2 + cardGap2)
                local cy = cardStartY2
                local hero = playerHeroes[hIdx]
                local cons = hero and hero.constellation or 0
                local deployed = false
                for _, dh in ipairs(st.deployHeroes) do if dh == hIdx then deployed = true; break end end

                DrawInventoryCard(cx, cy, cardW2, cardH2, card, cons, false, false)

                if deployed then
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx - 1, cy - 1, cardW2 + 2, cardH2 + 2, 4)
                    nvgStrokeColor(vg, nvgRGBA(255, 200, 50, 220))
                    nvgStrokeWidth(vg, 2); nvgStroke(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx + cardW2 - 20, cy + 1, 18, 12, 2)
                    nvgFillColor(vg, nvgRGBA(220, 160, 30, 220)); nvgFill(vg)
                    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 8)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(60, 30, 0, 255))
                    nvgText(vg, cx + cardW2 - 11, cy + 7, "出战", nil)
                else
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW2, cardH2, 4)
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 100)); nvgFill(vg)
                end

                st["btn_hero_" .. i] = { x = cx, y = cy, w = cardW2, h = cardH2 }
            end
        end
        nvgFontFaceId(vg, GetMainFont())
    else
        nvgFillColor(vg, nvgRGBA(200, 80, 30, 200))
        nvgText(vg, rpX + pad, heroY, "无武将(战力大减)", nil)
    end

    -- 按钮
    local canAtk = st.deployTroops >= 20 and st.food >= foodCost
    local btnW3, btnH3 = (rpW - pad * 2 - 6) / 2, 28
    local btnY3 = rpY + rpH - btnH3 - 8
    st.btn_cancelAtk = DrawBtn(rpX + pad, btnY3, btnW3, btnH3, "取消", 60, 55, 50)
    if canAtk then
        st.btn_confirmAtk = DrawBtn(rpX + pad + btnW3 + 6, btnY3, btnW3, btnH3, "出征!", 170, 55, 40)
    else
        st.btn_confirmAtk = DrawBtn(rpX + pad + btnW3 + 6, btnY3, btnW3, btnH3, "出征!", 60, 60, 60, 120)
    end
end

-- ============================================================================
-- 回合报告面板
-- ============================================================================
function M.DrawTurnReportPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10

    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, rpX + pad, rpY + 8, "第 " .. (st.turn - 1) .. " 回合 · 战报", nil)

    local sepY = rpY + 28
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    if st.turnReport then
        local lineH = 18
        local contentTop = sepY + 4
        local contentBot = rpY + rpH - 40
        local maxVisible = math.floor((contentBot - contentTop) / lineH)
        local scrollOff = st.reportScroll or 0

        nvgSave(vg)
        nvgScissor(vg, rpX, contentTop, rpW, contentBot - contentTop)

        for i, item in ipairs(st.turnReport) do
            local lineY = contentTop + (i - 1 - scrollOff) * lineH
            if lineY >= contentTop - lineH and lineY < contentBot then
                local text = type(item) == "table" and item.text or tostring(item)
                local itype = type(item) == "table" and item.type or "info"
                local iconKey = nil
                if itype == "income" then iconKey = "slgIconGold"
                elseif itype == "recruit" then iconKey = "slgIconSword"
                elseif itype == "battle" then iconKey = "slgIconBattleflag"
                elseif itype == "lost" then iconKey = "slgIconFire"
                elseif itype == "warning" then iconKey = "slgIconWarning"
                elseif itype == "diplomacy" then iconKey = "slgIconScroll"
                elseif itype == "victory" then iconKey = "slgIconCrown"
                elseif itype == "gameover" then iconKey = "slgIconDeath"
                elseif itype == "event" then iconKey = "slgIconDice"
                elseif itype == "stratagem" then iconKey = "slgIconPuzzle"
                end
                nvgFontSize(vg, 12)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                if itype == "lost" or itype == "gameover" then
                    nvgFillColor(vg, nvgRGBA(190, 40, 40, 240))
                elseif itype == "victory" then
                    nvgFillColor(vg, nvgRGBA(160, 100, 10, 255))
                elseif itype == "warning" then
                    nvgFillColor(vg, nvgRGBA(180, 100, 20, 230))
                elseif itype == "income" or itype == "recruit" then
                    nvgFillColor(vg, nvgRGBA(80, 200, 100, 220))
                elseif itype == "diplomacy" then
                    nvgFillColor(vg, nvgRGBA(100, 120, 220, 220))
                elseif itype == "event" then
                    nvgFillColor(vg, nvgRGBA(180, 120, 220, 230))
                elseif itype == "stratagem" then
                    nvgFillColor(vg, nvgRGBA(220, 160, 80, 230))
                else
                    nvgFillColor(vg, nvgRGBA(200, 190, 170, 210))
                end
                if iconKey then
                    DrawIconText(iconKey, text, rpX + pad, lineY, 12, 3)
                else
                    nvgText(vg, rpX + pad, lineY, "· " .. text, nil)
                end
            end
        end

        nvgRestore(vg)

        if #st.turnReport > maxVisible then
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(150, 130, 100, 140))
            DrawUpDownArrows(rpX + rpW - pad - 30, contentBot - 5, 5, 150, 130, 100, 140)
            nvgText(vg, rpX + rpW - pad - 22, contentBot - 5, "滑动", nil)
        end
    end

    st.btn_continue = DrawBtn(rpX + rpW / 2 - 45, rpY + rpH - 36, 90, 28, "继 续", 160, 130, 40)
end

-- ============================================================================
-- 招降面板 (战后俘获敌将: 招降/杀/放走)
-- ============================================================================
function M.DrawSurrenderPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10

    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
    nvgText(vg, rpX + pad, rpY + 8, "俘获敌将", nil)

    local cityName = ""
    if st.capturedCityId then
        local c = WORLD_CITIES[st.capturedCityId]
        if c then cityName = c.name end
    end
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
    nvgText(vg, rpX + pad + 80, rpY + 10, "攻占 " .. cityName, nil)

    local sepY = rpY + 30
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local heroes = st.capturedHeroes or {}
    local results = st.surrenderResults or {}
    local failPending = st.surrenderFailPending or {}  -- [heroIdx]=true 表示招降失败待决
    local startY = sepY + 6
    local rowH = 72
    local btnW2, btnH2 = 50, 22

    if #heroes == 0 then
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(200, 180, 150, 180))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, rpX + rpW / 2, rpY + rpH / 2, "无俘获武将", nil)
    else
        for i, hIdx in ipairs(heroes) do
            local card = HERO_CARDS[hIdx]
            if not card then goto continue_surrender end
            local oy = startY + (i - 1) * rowH
            if oy + rowH > rpY + rpH - 42 then break end

            local result = results[hIdx]
            local alreadyDone = (result ~= nil)
            local isFailed = failPending[hIdx]  -- 招降失败，等待杀/放走

            -- 卡片背景
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, oy, rpW - pad * 2, rowH - 4, 5)
            if isFailed then
                nvgFillColor(vg, nvgRGBA(80, 30, 20, 80)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(220, 80, 60, 100))
            elseif alreadyDone then
                nvgFillColor(vg, nvgRGBA(60, 40, 20, 40)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(200, 170, 100, 40))
            else
                nvgFillColor(vg, nvgRGBA(60, 40, 20, 70)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(200, 170, 100, 80))
            end
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 武将名 + 品质
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            local qColors = {
                [1] = {180,180,180}, [2] = {100,200,100}, [3] = {80,140,255},
                [4] = {200,100,255}, [5] = {255,200,50},
            }
            local qc = qColors[card.quality] or {200,200,200}
            nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], alreadyDone and 150 or 255))
            nvgText(vg, rpX + pad + 8, oy + 5, card.name, nil)

            -- 忠诚度显示
            local loyalty = (worldMapState.heroLoyalty[hIdx] or 100)
            nvgFontSize(vg, 10)
            local loyColor = loyalty <= 40 and {255,100,80} or loyalty <= 70 and {255,200,80} or {150,200,150}
            nvgFillColor(vg, nvgRGBA(loyColor[1], loyColor[2], loyColor[3], alreadyDone and 120 or 220))
            nvgText(vg, rpX + pad + 8 + 60, oy + 7, "忠诚:" .. loyalty, nil)

            -- 阵营+兵种
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(180, 170, 150, alreadyDone and 120 or 200))
            local facName = card.faction and (FACTIONS[card.faction] and FACTIONS[card.faction].name or card.faction) or ""
            local troopName = card.troopType and TROOP_TYPES[card.troopType] and TROOP_TYPES[card.troopType].name or ""
            nvgText(vg, rpX + pad + 8, oy + 22, facName .. " " .. troopName, nil)

            -- 属性
            nvgText(vg, rpX + pad + 8, oy + 35, "攻:" .. card.atk .. " 防:" .. card.def .. " 血:" .. card.hp, nil)

            -- 操作按钮 / 结果
            if alreadyDone then
                nvgFontSize(vg, 13)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                if result == "recruited" then
                    nvgFillColor(vg, nvgRGBA(80, 220, 80, 220))
                    nvgText(vg, rpX + rpW - pad - 6, oy + rowH / 2 - 2, "已归降", nil)
                elseif result == "killed" then
                    nvgFillColor(vg, nvgRGBA(200, 60, 60, 220))
                    nvgText(vg, rpX + rpW - pad - 6, oy + rowH / 2 - 2, "已处决", nil)
                elseif result == "released" then
                    nvgFillColor(vg, nvgRGBA(180, 180, 100, 200))
                    nvgText(vg, rpX + rpW - pad - 6, oy + rowH / 2 - 2, "已放走", nil)
                end
            elseif isFailed then
                -- 招降失败后: 只显示 杀/放走
                nvgFontSize(vg, 11)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 120, 80, 220))
                nvgText(vg, rpX + rpW - pad - 6, oy + 4, "招降失败!", nil)

                local bx = rpX + rpW - pad - btnW2
                st["btn_kill_" .. i]    = DrawBtn(bx, oy + 22, btnW2, btnH2, "处决", 160, 40, 40)
                st["btn_release_" .. i] = DrawBtn(bx, oy + 22 + btnH2 + 3, btnW2, btnH2, "放走", 80, 70, 60)
            else
                -- 初始状态: 招降/杀/放走 三个按钮
                local bx = rpX + rpW - pad - btnW2
                st["btn_surrender_" .. i] = DrawBtn(bx, oy + 4, btnW2, btnH2, "招降", 140, 100, 40)
                st["btn_kill_" .. i]      = DrawBtn(bx, oy + 4 + btnH2 + 3, btnW2, btnH2, "处决", 160, 40, 40)
                st["btn_release_" .. i]   = DrawBtn(bx, oy + 4 + (btnH2 + 3) * 2, btnW2, btnH2, "放走", 80, 70, 60)
            end
            ::continue_surrender::
        end
    end

    -- 完成按钮 (所有武将已处理后可用)
    local allDone = true
    for _, hIdx in ipairs(heroes) do
        if results[hIdx] == nil then allDone = false; break end
    end
    -- 还有失败待决的也不算完成
    for _, hIdx in ipairs(heroes) do
        if failPending[hIdx] then allDone = false; break end
    end
    if allDone or #heroes == 0 then
        st.btn_surrenderDone = DrawBtn(rpX + rpW / 2 - 50, rpY + rpH - 36, 100, 28, "继 续", 160, 130, 40)
    else
        st.btn_surrenderDone = DrawBtn(rpX + rpW / 2 - 50, rpY + rpH - 36, 100, 28, "继 续", 60, 60, 60, 120)
    end
end

-- ============================================================================
-- 武将管理面板
-- ============================================================================
function M.DrawHeroManagePanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    local cityId = st.heroManageCity
    if not cityId then st.phase = "MAP"; return end
    local city, cd = WORLD_CITIES[cityId], st.cityData[cityId]
    if not city or not cd or cd.owner ~= "player" then st.phase = "MAP"; return end

    -- 标题
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, rpX + pad, rpY + 8, city.name .. " · 武将", nil)

    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
    nvgText(vg, rpX + pad, rpY + 28, "金:" .. st.gold .. " 驻将:" .. #cd.heroes, nil)

    local sepY = rpY + 44
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 武将列表 (带滚动)
    local startY = sepY + 4
    local rowH = 64
    local contentH = rpH - (startY - rpY) - 40
    local scrollOff = st.heroManageScroll or 0

    nvgSave(vg)
    nvgScissor(vg, rpX, startY, rpW, contentH)

    local heroCount = #cd.heroes
    if heroCount == 0 then
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(180, 160, 130, 160))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, rpX + rpW / 2, startY + contentH / 2, "该城无武将驻守", nil)
    else
        for i, hIdx in ipairs(cd.heroes) do
            local card = HERO_CARDS[hIdx]
            if not card then goto continue_hero end
            local oy = startY + (i - 1) * rowH - scrollOff
            if oy + rowH < startY or oy > startY + contentH then goto continue_hero end

            -- 卡片背景
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, oy, rpW - pad * 2, rowH - 4, 5)
            nvgFillColor(vg, nvgRGBA(50, 35, 18, 80)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 60))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 武将名 + 品质色
            local qColors = {
                [1] = {180,180,180}, [2] = {100,200,100}, [3] = {80,140,255},
                [4] = {200,100,255}, [5] = {255,200,50},
            }
            local qc = qColors[card.quality] or {200,200,200}
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
            nvgText(vg, rpX + pad + 6, oy + 4, card.name, nil)

            -- 当前兵种
            local activeTroop = st.heroTroopChoice[hIdx] or card.troopType
            local tt = TROOP_TYPES[activeTroop]
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(200, 180, 120, 220))
            nvgText(vg, rpX + pad + 60, oy + 6, tt and (tt.icon .. tt.name) or activeTroop, nil)

            -- 可选兵种 (小按钮)
            local opts = card.troopOptions or { card.troopType }
            local tbtnW = 42
            local tbtnH = 18
            local tbtnY = oy + 24
            for j, ttype in ipairs(opts) do
                local tti = TROOP_TYPES[ttype]
                local bx = rpX + pad + 4 + (j - 1) * (tbtnW + 3)
                local isActive = (ttype == activeTroop)
                if isActive then
                    nvgBeginPath(vg); nvgRoundedRect(vg, bx, tbtnY, tbtnW, tbtnH, 3)
                    nvgFillColor(vg, nvgRGBA(180, 140, 40, 120)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(255, 200, 60, 200)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                else
                    nvgBeginPath(vg); nvgRoundedRect(vg, bx, tbtnY, tbtnW, tbtnH, 3)
                    nvgFillColor(vg, nvgRGBA(60, 50, 30, 80)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(140, 120, 80, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                end
                nvgFontSize(vg, 10)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, isActive and nvgRGBA(255, 230, 150, 255) or nvgRGBA(180, 170, 140, 180))
                nvgText(vg, bx + tbtnW / 2, tbtnY + tbtnH / 2, tti and (tti.icon .. tti.name) or ttype, nil)
                st["btn_troop_" .. hIdx .. "_" .. j] = { x = bx, y = tbtnY, w = tbtnW, h = tbtnH }
            end

            -- 武技信息
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            local techText = ""
            if card.initTechnique and SKILL_TECHNIQUES[card.initTechnique] then
                techText = "技:" .. SKILL_TECHNIQUES[card.initTechnique].name
            end
            local learned = st.heroLearnedSkills[hIdx]
            if learned and learned.techIdx and SKILL_TECHNIQUES[learned.techIdx] then
                techText = techText .. " 习:" .. SKILL_TECHNIQUES[learned.techIdx].name
            end
            if techText ~= "" then
                nvgFillColor(vg, nvgRGBA(140, 180, 220, 200))
                nvgText(vg, rpX + pad + 6, oy + 46, techText, nil)
            end

            -- 拜师按钮 (右侧)
            local apBtnW, apBtnH = 38, 20
            local apBtnX = rpX + rpW - pad - apBtnW - 2
            local apBtnY = oy + 4
            st["btn_apprentice_" .. i] = DrawBtn(apBtnX, apBtnY, apBtnW, apBtnH, "拜师", 100, 80, 50)

            -- 存储武将索引映射
            st["_heroManage_idx_" .. i] = hIdx
            ::continue_hero::
        end
    end

    nvgRestore(vg)

    st._heroManageCount = heroCount
    st._heroManageTotalH = heroCount * rowH
    st._heroManageVisibleH = contentH

    -- 返回按钮
    st.btn_heroManageBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "返回", 60, 55, 50)
end

-- ============================================================================
-- 拜师面板 (选择师父)
-- ============================================================================
function M.DrawApprenticePanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    local studentIdx = st.apprenticeStudent
    if not studentIdx then st.phase = "HERO_MANAGE"; return end
    local student = HERO_CARDS[studentIdx]
    if not student then st.phase = "HERO_MANAGE"; return end
    local cityId = st.heroManageCity
    if not cityId then st.phase = "MAP"; return end
    local cd = st.cityData[cityId]
    if not cd then st.phase = "MAP"; return end

    -- 标题
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, rpX + pad, rpY + 8, student.name .. " · 拜师", nil)

    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
    nvgText(vg, rpX + pad, rpY + 28, "费用200金 (现有:" .. st.gold .. ")", nil)

    -- 学生武技
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(140, 180, 220, 200))
    local ownTech = ""
    if student.initTechnique and SKILL_TECHNIQUES[student.initTechnique] then
        ownTech = "自有:" .. SKILL_TECHNIQUES[student.initTechnique].name
    end
    local learned = st.heroLearnedSkills[studentIdx]
    if learned and learned.techIdx and SKILL_TECHNIQUES[learned.techIdx] then
        ownTech = ownTech .. " 已习:" .. SKILL_TECHNIQUES[learned.techIdx].name
    end
    if ownTech ~= "" then
        nvgText(vg, rpX + pad, rpY + 42, ownTech, nil)
    end

    -- 成功率提示
    local studentStats = student.stats5 or { int = 50 }
    local rate = math.min(95, 50 + studentStats.int * 0.5)
    nvgFillColor(vg, nvgRGBA(220, 200, 130, 180))
    nvgText(vg, rpX + pad + 140, rpY + 28, "成功率:" .. math.floor(rate) .. "%", nil)

    local sepY = rpY + 56
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 同城可拜师的武将列表
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 220))
    nvgText(vg, rpX + pad, sepY + 4, "选择师父:", nil)

    local startY = sepY + 22
    local rowH = 48
    local teacherCount = 0

    for i, hIdx in ipairs(cd.heroes) do
        if hIdx == studentIdx then goto continue_teacher end
        local card = HERO_CARDS[hIdx]
        if not card then goto continue_teacher end
        if not card.initTechnique then goto continue_teacher end
        -- 不能学自己已有的武技
        if card.initTechnique == student.initTechnique then goto continue_teacher end

        teacherCount = teacherCount + 1
        local oy = startY + (teacherCount - 1) * rowH

        -- 背景
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, oy, rpW - pad * 2, rowH - 4, 5)
        nvgFillColor(vg, nvgRGBA(50, 35, 18, 70)); nvgFill(vg)

        -- 名字
        local qColors = {
            [1] = {180,180,180}, [2] = {100,200,100}, [3] = {80,140,255},
            [4] = {200,100,255}, [5] = {255,200,50},
        }
        local qc = qColors[card.quality] or {200,200,200}
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
        nvgText(vg, rpX + pad + 6, oy + 4, card.name, nil)

        -- 可教武技
        local tech = SKILL_TECHNIQUES[card.initTechnique]
        if tech then
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, 220))
            nvgText(vg, rpX + pad + 6, oy + 22, "教:" .. tech.name .. " (" .. tech.tier .. "品)", nil)
        end

        -- 学习按钮
        local lbtnW, lbtnH = 42, 22
        local lbtnX = rpX + rpW - pad - lbtnW - 2
        local lbtnY = oy + 10
        local canLearn = (st.gold >= 200)
        if canLearn then
            st["btn_learn_" .. teacherCount] = DrawBtn(lbtnX, lbtnY, lbtnW, lbtnH, "学习", 120, 100, 40)
        else
            st["btn_learn_" .. teacherCount] = DrawBtn(lbtnX, lbtnY, lbtnW, lbtnH, "学习", 60, 60, 60, 120)
        end
        st["_apprentice_teacher_" .. teacherCount] = hIdx

        ::continue_teacher::
    end

    st._apprenticeTeacherCount = teacherCount

    if teacherCount == 0 then
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(200, 160, 100, 160))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, rpX + rpW / 2, startY + 30, "无可拜师武将", nil)
        nvgFontSize(vg, 11)
        nvgText(vg, rpX + rpW / 2, startY + 50, "(需同城且有不同武技)", nil)
    end

    -- 返回按钮
    st.btn_apprenticeBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "返回", 60, 55, 50)
end

-- ============================================================================
-- 建设面板 (城池建筑升级)
-- ============================================================================
function M.DrawBuildingsPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    local cityId = st.buildingsCity
    if not cityId then st.phase = "MAP"; return end
    local city = WORLD_CITIES[cityId]
    local cd = st.cityData[cityId]
    if not city or not cd or cd.owner ~= "player" then st.phase = "MAP"; return end

    local BUILDINGS = Data.BUILDINGS

    -- 标题
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, rpX + pad, rpY + 8, city.name .. " · 建设", nil)

    -- 资源
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
    nvgText(vg, rpX + pad, rpY + 28, "金:" .. st.gold, nil)

    local sepY = rpY + 44
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 建筑列表 (带滚动)
    local startY = sepY + 4
    local rowH = 52
    local contentH = rpH - (startY - rpY) - 40
    local totalH = #BUILDINGS * rowH
    local scrollOff = st.buildingsScroll or 0
    local maxScroll = math.max(0, totalH - contentH)
    st.buildingsScroll = math.max(0, math.min(maxScroll, scrollOff))
    scrollOff = st.buildingsScroll

    nvgSave(vg)
    nvgScissor(vg, rpX, startY, rpW, contentH)

    for i, bDef in ipairs(BUILDINGS) do
        local oy = startY + (i - 1) * rowH - scrollOff
        if oy + rowH < startY or oy > startY + contentH then goto continue_building end

        local curLv = cd.buildings[bDef.id] or 0
        local isMax = (curLv >= 5)
        local nextCost = isMax and 0 or bDef.cost[curLv + 1]
        local canUpgrade = (not isMax) and (st.gold >= nextCost)

        -- 卡片背景
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + pad, oy, rpW - pad * 2, rowH - 4, 5)
        nvgFillColor(vg, nvgRGBA(50, 40, 20, 80)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 150, 80, curLv > 0 and 80 or 40))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 图标 + 名字
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 235, 170, curLv > 0 and 255 or 180))
        nvgText(vg, rpX + pad + 6, oy + 4, bDef.icon .. " " .. bDef.name, nil)

        -- 等级
        nvgFontSize(vg, 11)
        if curLv > 0 then
            nvgFillColor(vg, nvgRGBA(255, 200, 60, 220))
            nvgText(vg, rpX + pad + 70, oy + 6, "Lv." .. curLv, nil)
        else
            nvgFillColor(vg, nvgRGBA(150, 130, 100, 150))
            nvgText(vg, rpX + pad + 70, oy + 6, "未建", nil)
        end

        -- 描述 + 当前加成
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 170, 150, 180))
        nvgText(vg, rpX + pad + 6, oy + 22, bDef.desc, nil)

        if curLv > 0 then
            local bonus = bDef.bonus[curLv]
            local bonusStr
            if bDef.effect == "craft" or bDef.effect == "research" then
                bonusStr = "+" .. math.floor(bonus * 100) .. "%"
            else
                bonusStr = "+" .. bonus
            end
            nvgFillColor(vg, nvgRGBA(100, 200, 100, 200))
            nvgText(vg, rpX + pad + 6, oy + 34, "当前: " .. bonusStr, nil)
        end

        -- 升级按钮或满级标记
        local btnW2, btnH2 = 50, 22
        local bx = rpX + rpW - pad - btnW2 - 2
        local by = oy + (rowH - 4 - btnH2) / 2
        if isMax then
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 170, 80, 180))
            nvgText(vg, rpX + rpW - pad - 6, oy + rowH / 2 - 2, "MAX", nil)
            st["btn_build_" .. bDef.id] = nil
        elseif canUpgrade then
            st["btn_build_" .. bDef.id] = DrawBtn(bx, by, btnW2, btnH2, nextCost .. "金", 100, 120, 50)
        else
            st["btn_build_" .. bDef.id] = DrawBtn(bx, by, btnW2, btnH2, nextCost .. "金", 60, 60, 60, 120)
        end

        ::continue_building::
    end

    nvgRestore(vg)

    -- 滚动条
    if totalH > contentH then
        local barH = math.max(12, contentH * (contentH / totalH))
        local barY = startY + (scrollOff / maxScroll) * (contentH - barH)
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + rpW - pad, barY, 3, barH, 1.5)
        nvgFillColor(vg, nvgRGBA(200, 170, 100, 100)); nvgFill(vg)
    end

    -- 存储滚动区域信息
    st._buildingsScrollArea = { x = rpX, y = startY, w = rpW, h = contentH }
    st._buildingsTotalH = totalH

    -- 返回按钮
    st.btn_buildingsBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "返回", 60, 55, 50)
end

-- ============================================================================
-- 任务面板 (羁绊 + 任务目标 + 转职)
-- ============================================================================
function M.DrawQuestsPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    local pad = 10
    local WorldMap = require("systems.slg.slg_logic")

    -- 标题
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(255, 230, 160, 255))
    nvgText(vg, rpX + pad, rpY + 8, "任务·羁绊·转职", nil)

    local sepY = rpY + 28
    nvgBeginPath(vg); nvgMoveTo(vg, rpX + pad, sepY); nvgLineTo(vg, rpX + rpW - pad, sepY)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 可滚动内容区
    local contentTop = sepY + 4
    local contentH = rpH - (contentTop - rpY) - 42  -- 底部留返回按钮
    st.questScroll = st.questScroll or 0

    nvgSave(vg)
    nvgScissor(vg, rpX, contentTop, rpW, contentH)

    local cy = contentTop - st.questScroll
    local itemH = 0  -- 跟踪总内容高度

    -- === 第一节: 任务目标 ===
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 240))
    DrawTriangle(rpX + pad + 4, cy + 6, 5, "right", 180, 220, 255, 240)
    nvgText(vg, rpX + pad + 14, cy, "任务目标", nil)
    cy = cy + 20

    for _, q in ipairs(QUESTS) do
        local done = st.questCompleted[q.id]
        local iconKey = done and "slgIconCheck" or (q.icon or "slgIconClipboard")
        local nameC = done and {120, 180, 120} or {230, 220, 200}
        local descC = done and {100, 140, 100} or {180, 170, 150}

        -- 图标 + 名称
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(nameC[1], nameC[2], nameC[3], done and 160 or 240))
        DrawIconText(iconKey, q.name, rpX + pad, cy, 13, 3)

        -- 奖励
        local rwdTxt = ""
        if q.reward.gold then rwdTxt = rwdTxt .. "金" .. q.reward.gold .. " " end
        if q.reward.food then rwdTxt = rwdTxt .. "粮" .. q.reward.food end
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(220, 190, 80, done and 120 or 200))
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgText(vg, rpX + rpW - pad, cy, rwdTxt, nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        cy = cy + 16

        -- 描述
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(descC[1], descC[2], descC[3], done and 120 or 180))
        nvgText(vg, rpX + pad + 18, cy, q.desc, nil)
        cy = cy + 18
    end

    -- === 第二节: 激活羁绊 ===
    cy = cy + 6
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 200, 150, 240))
    DrawTriangle(rpX + pad + 4, cy + 6, 5, "right", 255, 200, 150, 240)
    nvgText(vg, rpX + pad + 14, cy, "武将羁绊", nil)
    cy = cy + 20

    for _, bond in ipairs(BONDS) do
        -- 检查是否有任何玩家城池激活了该羁绊
        local activated = false
        for _, city in ipairs(Data.WORLD_CITIES) do
            local cd = st.cityData[city.id]
            if cd and cd.owner == "player" then
                local activeBonds = WorldMap.GetActiveBonds(city.id)
                for _, ab in ipairs(activeBonds) do
                    if ab.id == bond.id then activated = true; break end
                end
            end
            if activated then break end
        end

        local nameC = activated and {255, 230, 140} or {160, 150, 130}
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(nameC[1], nameC[2], nameC[3], activated and 255 or 150))
        if activated then
            DrawStar(rpX + pad + 6, cy + 6, 6, 3, 255, 230, 140, 255)
        else
            DrawCircleOutline(rpX + pad + 6, cy + 6, 4, nameC[1], nameC[2], nameC[3], 150, 1.5)
        end
        nvgText(vg, rpX + pad + 16, cy, bond.name, nil)

        -- 右侧显示加成
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 180, 120, activated and 220 or 100))
        nvgText(vg, rpX + rpW - pad, cy, bond.desc, nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        cy = cy + 16

        -- 武将列表（限制宽度防止超框）
        nvgFontSize(vg, 10)
        local heroParts = {}
        for _, hIdx in ipairs(bond.heroes) do
            local c = HERO_CARDS[hIdx]
            if c then
                local owned = playerHeroes[hIdx] and playerHeroes[hIdx].owned
                table.insert(heroParts, owned and c.name or ("?" .. c.name))
            end
        end
        nvgFillColor(vg, nvgRGBA(150, 140, 120, activated and 180 or 100))
        local heroTxt = table.concat(heroParts, " ")
        local maxTxtW = rpW - pad * 2 - 20
        nvgTextBox(vg, rpX + pad + 18, cy, maxTxtW, heroTxt, nil)
        cy = cy + 18
    end

    -- === 第三节: 转职 ===
    cy = cy + 6
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(150, 220, 255, 240))
    DrawTriangle(rpX + pad + 4, cy + 6, 5, "right", 150, 220, 255, 240)
    nvgText(vg, rpX + pad + 14, cy, "转职升阶", nil)
    cy = cy + 20

    for _, cc in ipairs(CLASS_CHANGES) do
        local card = HERO_CARDS[cc.heroId]
        if not card then goto continue_cc end
        local owned = playerHeroes[cc.heroId] and playerHeroes[cc.heroId].owned
        local changed = st.classChanged[cc.heroId]
        local canDo = false
        if owned and not changed then
            canDo = WorldMap.CanClassChange(cc.heroId)
        end

        local nameC = changed and {120, 200, 120} or (canDo and {255, 240, 160} or {150, 140, 120})
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(nameC[1], nameC[2], nameC[3], changed and 200 or (canDo and 255 or 130)))
        if changed then
            DrawStar(rpX + pad + 6, cy + 6, 6, 3, 120, 200, 120, 200)
        elseif canDo then
            DrawDiamond(rpX + pad + 6, cy + 6, 5, 255, 240, 160, 255)
        else
            DrawCircleOutline(rpX + pad + 6, cy + 6, 4, 150, 140, 120, 130, 1.5)
        end
        nvgText(vg, rpX + pad + 16, cy, card.name .. " → " .. cc.name, nil)
        cy = cy + 16

        -- 条件 / 状态
        nvgFontSize(vg, 11)
        if changed then
            nvgFillColor(vg, nvgRGBA(100, 180, 100, 180))
            nvgText(vg, rpX + pad + 18, cy, "已转职", nil)
        else
            local wins = (st.heroStats[cc.heroId] and st.heroStats[cc.heroId].wins or 0)
            local prog = wins .. "/" .. cc.reqWins .. "胜"
            nvgFillColor(vg, nvgRGBA(180, 170, 140, canDo and 220 or 120))
            nvgText(vg, rpX + pad + 18, cy, "需" .. cc.reqWins .. "胜 (" .. prog .. ")", nil)

            -- 转职按钮
            if canDo then
                local btnKey = "btn_cc_" .. cc.heroId
                st[btnKey] = DrawBtn(rpX + rpW - pad - 50, cy - 3, 48, 20, "转职", 80, 140, 200)
            end
        end
        cy = cy + 20
        ::continue_cc::
    end

    local totalH = cy + st.questScroll - contentTop
    nvgRestore(vg)

    -- 滚动条
    if totalH > contentH then
        local maxScroll = totalH - contentH
        st.questScroll = math.max(0, math.min(maxScroll, st.questScroll))
        local barH = math.max(12, contentH * (contentH / totalH))
        local barY = contentTop + (st.questScroll / maxScroll) * (contentH - barH)
        nvgBeginPath(vg); nvgRoundedRect(vg, rpX + rpW - pad, barY, 3, barH, 1.5)
        nvgFillColor(vg, nvgRGBA(200, 170, 100, 100)); nvgFill(vg)
    end

    st._questsScrollArea = { x = rpX, y = contentTop, w = rpW, h = contentH }
    st._questsTotalH = totalH

    -- 返回按钮
    st.btn_questsBack = DrawBtn(rpX + rpW / 2 - 40, rpY + rpH - 36, 80, 28, "返回", 60, 55, 50)
end

-- ============================================================================
-- 面板分发 (新签名: rpX, rpY, rpW, rpH, t)
-- ============================================================================
function M.DrawPanel(rpX, rpY, rpW, rpH, t)
    local st = worldMapState
    if st.phase == "HERO_MANAGE" then
        M.DrawHeroManagePanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "APPRENTICE" then
        M.DrawApprenticePanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "BUILDINGS" then
        M.DrawBuildingsPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "QUESTS" then
        M.DrawQuestsPanel(rpX, rpY, rpW, rpH, t)
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
    elseif st.phase == "TURN_REPORT" then
        M.DrawTurnReportPanel(rpX, rpY, rpW, rpH, t)
    elseif st.phase == "SURRENDER" then
        M.DrawSurrenderPanel(rpX, rpY, rpW, rpH, t)
    else
        M.DrawMapPanel(rpX, rpY, rpW, rpH, t)
    end
end

return M
