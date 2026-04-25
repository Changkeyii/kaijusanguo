-- ============================================================================
-- slg/slg_panels_battle.lua - 军事行动面板集合
-- 用途: 调兵、出征目标选择、战前部署、出发城选择、调兵遣将、武将调配
-- 依赖: slg_panels.lua (通过 init 注入 UI常量/辅助函数/Render引用)
-- 导出: M.DrawMoveSelectPanel, DrawAtkTargetPanel, DrawDeployPanel,
--       DrawAtkSourceSelectPanel, DrawTransferPanel, DrawTransferHeroSelectPanel
-- ============================================================================

---@diagnostic disable: undefined-global

local Data   = require("systems.slg.slg_data")
local Render = require("systems.slg.slg_render")

local GetFC            = Render.GetFC
local DrawBtn          = Render.DrawBtn
local DrawTextOutlined = Render.DrawTextOutlined

local M = {}

-- 由父模块 slg_panels.lua 通过 init() 注入的依赖
local UI                  ---@type table
local DrawPanelTitle      ---@type function
local DrawBackBtn         ---@type function
local DrawSectionHeader   ---@type function
local DrawThinSep         ---@type function
local DrawTroopCounterHint ---@type function
local DrawProgressBar     ---@type function
local HasEndTurnBtn       ---@type function

--- 初始化依赖注入 (由 slg_panels.lua 调用)
---@param deps table 包含 UI, DrawPanelTitle, DrawBackBtn 等
function M.init(deps)
    UI                   = deps.UI
    DrawPanelTitle       = deps.DrawPanelTitle
    DrawBackBtn          = deps.DrawBackBtn
    DrawSectionHeader    = deps.DrawSectionHeader
    DrawThinSep          = deps.DrawThinSep
    DrawTroopCounterHint = deps.DrawTroopCounterHint
    DrawProgressBar      = deps.DrawProgressBar
    HasEndTurnBtn        = deps.HasEndTurnBtn
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
    -- 战力直接按出征武将计算, 不再按兵力比例缩放 (保持与实际战斗一致)
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

    -- (阵型和战术选择已移除)
    st.formationBtns = {}
    st.tacticBtns = {}

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

    -- === 武将 (可滚动网格) ===
    DrawThinSep(rpX + pad, curY, innerW)
    curY = curY + 4
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    if #fromData.heroes > 0 then
        local heroCount = #fromData.heroes
        DrawTextOutlined(rpX + pad, curY, "武将(点击出战) " .. heroCount .. "人:", 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        curY = curY + 22
        local cardW2, cardH2 = 48, 64
        local cardGap2 = 4
        local cols = math.min(4, math.floor((innerW + cardGap2) / (cardW2 + cardGap2)))
        local rows = math.ceil(heroCount / cols)
        local heroTotalH = rows * (cardH2 + cardGap2)
        -- 动态计算可用高度：底部留出兵种克制提示+按钮区域（约 90px）
        local etOffset2 = HasEndTurnBtn(st.phase) and (UI.BTN_H + 6) or 0
        local bottomReserve = 90 + etOffset2
        local availH = math.max((cardH2 + cardGap2) * 2, rpY + rpH - curY - bottomReserve)
        local heroVisH = math.min(heroTotalH, availH)
        -- 注册滚动区域
        st._deployHeroScrollArea = { x = rpX + pad, y = curY, w = innerW, h = heroVisH }
        st._deployHeroTotalH = heroTotalH
        local heroScroll = st.deployHeroScroll or 0
        local maxScroll = math.max(0, heroTotalH - heroVisH)
        heroScroll = math.max(0, math.min(maxScroll, heroScroll))
        st.deployHeroScroll = heroScroll
        -- 裁剪区域
        nvgSave(vg)
        nvgScissor(vg, rpX + pad, curY, innerW, heroVisH)
        -- 清除旧的 hero 按钮
        for k, _ in pairs(st) do
            if type(k) == "string" and k:sub(1, 9) == "btn_hero_" then st[k] = nil end
        end
        for i = 1, heroCount do
            local hIdx = fromData.heroes[i]
            local card = HERO_CARDS[hIdx]
            if card then
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cx = rpX + pad + col * (cardW2 + cardGap2)
                local cy = curY + row * (cardH2 + cardGap2) - heroScroll
                -- 裁剪判断: 只绘制可见区域内的卡片
                if cy + cardH2 > curY - 5 and cy < curY + heroVisH + 5 then
                    local hero = playerHeroes[hIdx]
                    local cons = hero and hero.constellation or 0
                    local deployed = false
                    for _, dh in ipairs(st.deployHeroes) do if dh == hIdx then deployed = true; break end end
                    DrawInventoryCard(cx, cy, cardW2, cardH2, card, cons, false, false, true)
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
        end
        nvgRestore(vg) -- 恢复裁剪
        -- 滚动指示器 (超过2行时显示)
        if rows > 2 then
            local scrollPct = maxScroll > 0 and (heroScroll / maxScroll) or 0
            local scrollBarH = math.max(12, heroVisH * (heroVisH / heroTotalH))
            local barY = curY + scrollPct * (heroVisH - scrollBarH)
            nvgBeginPath(vg); nvgRoundedRect(vg, rpX + rpW - pad - 4, barY, 3, scrollBarH, 1.5)
            nvgFillColor(vg, nvgRGBA(200, 180, 120, 120)); nvgFill(vg)
        end
        curY = curY + heroVisH + 4
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

return M
