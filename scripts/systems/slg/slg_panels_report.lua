-- ============================================================================
-- slg/slg_panels_report.lua - 回合报告 & 战败通报面板集合
-- 用途: 回合战报弹窗、招降俘虏弹窗、全军覆没通报弹窗
-- 依赖: slg_panels.lua (通过 init 注入 UI常量/辅助函数/Render引用)
-- 导出: M.DrawTurnReportPanel, DrawSurrenderPanel, DrawDefeatReportPanel
-- ============================================================================

---@diagnostic disable: undefined-global

local Render = require("systems.slg.slg_render")

local DrawBtn          = Render.DrawBtn
local DrawTextOutlined = Render.DrawTextOutlined

local M = {}

-- 由父模块 slg_panels.lua 通过 init() 注入的依赖
local UI              ---@type table
local DrawThinSep     ---@type function
local DrawProgressBar ---@type function

--- 初始化依赖注入 (由 slg_panels.lua 调用)
---@param deps table 包含 UI, DrawThinSep, DrawProgressBar 等
function M.init(deps)
    UI              = deps.UI
    DrawThinSep     = deps.DrawThinSep
    DrawProgressBar = deps.DrawProgressBar
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
    DrawInventoryCard(heroCardX, heroCardY, heroCardW, heroCardH, card, cons, false, true, true)

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

return M
