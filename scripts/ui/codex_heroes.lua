-- ui/codex_heroes.lua - 三国武灵录 (从 codex.lua 拆分)
-- ============================================================================
-- ui/codex.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 武灵录 (图鉴界面) - 设计坐标
-- ============================================================================
function DrawCodexScreen()
    if gameState.phase ~= "CODEX" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer

    -- 1. 统一菜单背景
    DrawCodexBg(W, H)

    nvgFontFaceId(vg, GetMainFont())

    -- 顶部栏参数 (按钮绘制移到卡牌之后, 确保在卡牌上层)
    local topBarY = 12
    local backW, backH = 110, 48
    local backX = 10

    -- ===========================
    -- 2. 品质标签页过滤
    -- ===========================
    local TAB_DEFS = {
        { label = "全部", quality = nil },
        { label = "N",    quality = QUALITY.COMMON },
        { label = "R",    quality = QUALITY.RARE },
        { label = "SR",   quality = QUALITY.EPIC },
        { label = "SSR",  quality = QUALITY.LEGENDARY },
        { label = "限定",  quality = QUALITY.LIMITED },
    }
    -- 构建过滤后的卡牌列表 { origIdx, card }
    local filteredCards = {}
    for i = 1, #HERO_CARDS do
        local card = HERO_CARDS[i]
        local match = false
        if codexTab == 0 then
            match = true
        elseif TAB_DEFS[codexTab + 1].quality == QUALITY.LEGENDARY then
            -- SSR标签页同时显示SSR和限定SSR
            match = (card.quality == QUALITY.LEGENDARY or card.quality == QUALITY.LIMITED)
        else
            match = (card.quality == TAB_DEFS[codexTab + 1].quality)
        end
        if match then
            filteredCards[#filteredCards + 1] = { origIdx = i, card = card }
        end
    end

    -- ===========================
    -- 3. 英雄网格 (3列卡牌, 可滚动) — 一屏显示6张完整 + 下排露半
    -- ===========================
    local cols = 3
    local gap = 10
    local startY = 110  -- 为标签页留空间
    local bottomPad = 10  -- 底部留白
    local visibleH = H - startY - bottomPad
    -- 反推卡片高度: 2.5行 × (cardH + gap) = visibleH
    local cardH = math.floor((visibleH - 2.5 * gap) / 2.5)
    local cardW = math.floor(cardH * CARD_RATIO)
    local gridW = cols * cardW + (cols - 1) * gap
    local startX = cx - gridW / 2

    -- 计算内容总高度和滚动边界
    local totalRows = math.ceil(#filteredCards / cols)
    local contentH = totalRows * (cardH + gap + 4) - (gap + 4)
    local maxScrollY = 0
    local minScrollY = math.min(0, -(contentH - visibleH))

    -- 钳制滚动范围
    codexScroll.y = math.max(minScrollY, math.min(maxScrollY, codexScroll.y))

    -- 滚动区域裁剪 (严格限制在 startY 以下, 防止卡片遮挡顶部按钮)
    nvgSave(vg)
    nvgScissor(vg, 0, startY, W, visibleH)

    codexCardRects = {}
    for fi = 1, #filteredCards do
        local entry = filteredCards[fi]
        local idx = entry.origIdx
        local card = entry.card
        local col = ((fi - 1) % cols)
        local row = math.floor((fi - 1) / cols)
        local x = startX + col * (cardW + gap)
        local y = startY + row * (cardH + gap + 4) + codexScroll.y
        local hero = playerHeroes[idx]

        -- 存储点击区域 (用原始索引作为key, 兼容EndPress点击检测)
        codexCardRects[idx] = { x = x, y = y, w = cardW, h = cardH }

        -- 跳过完全不可见的卡牌
        if y + cardH >= startY and y <= startY + visibleH then
            if hero and hero.owned then
                -- 已拥有: 正常绘制
                DrawInventoryCard(x, y, cardW, cardH, card, hero.constellation, false)
            else
                -- 未拥有: 灰暗效果
                -- 暗底板
                nvgBeginPath(vg); nvgRoundedRect(vg, x, y, cardW, cardH, 4)
                nvgFillColor(vg, nvgRGBA(28, 25, 20, 240)); nvgFill(vg)

                -- 角色图 (暗淡)
                local _shC, _scC, _srC = GetHeroSheetInfo(card)
                if _shC > 0 then
                    nvgGlobalAlpha(vg, 0.2)
                    DrawCardImage(x + 3, y + 3, cardW - 6, cardH - 20, _shC, card.row, card.col, _scC, _srC)
                    nvgGlobalAlpha(vg, 1.0)
                end

                -- 暗色遮罩
                nvgBeginPath(vg); nvgRoundedRect(vg, x, y, cardW, cardH, 4)
                nvgFillColor(vg, nvgRGBA(10, 10, 15, 140)); nvgFill(vg)

                -- 边框
                nvgBeginPath(vg); nvgRoundedRect(vg, x, y, cardW, cardH, 4)
                nvgStrokeColor(vg, nvgRGBA(60, 55, 45, 120))
                nvgStrokeWidth(vg, 1); nvgStroke(vg)

                -- "?" 标记
                nvgFontSize(vg, 57)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(x + cardW / 2, y + (cardH - 24) / 2, "?")

                -- 品质边框色 (未解锁也显示品质色)
                local uqc = QUALITY_COLORS[card.quality]
                nvgBeginPath(vg); nvgRoundedRect(vg, x, y, cardW, cardH, 4)
                nvgStrokeColor(vg, nvgRGBA(uqc[1], uqc[2], uqc[3], 80))
                nvgStrokeWidth(vg, 1); nvgStroke(vg)

                -- 左上角品质标签 (未解锁也显示 N/R/SR/SSR)
                local uqTag = QUALITY_TAGS[card.quality] or "N"
                local uTagW = #uqTag > 2 and 26 or (#uqTag > 1 and 20 or 14)
                local uTagH = 13
                nvgBeginPath(vg); nvgRoundedRect(vg, x + 2, y + 2, uTagW, uTagH, 2)
                nvgFillColor(vg, nvgRGBA(uqc[1], uqc[2], uqc[3], 140)); nvgFill(vg)
                nvgFontSize(vg, 24)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(x + 2 + uTagW / 2, y + 2 + uTagH / 2, uqTag)

                -- 底部名条 (暗色)
                local nameBarH = 24
                local nameBarY = y + cardH - nameBarH
                nvgBeginPath(vg)
                nvgRoundedRect(vg, x + 1, nameBarY, cardW - 2, nameBarH, 0)
                nvgFillColor(vg, nvgRGBA(28, 24, 16, 210)); nvgFill(vg)
                nvgFontSize(vg, 25)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(x + cardW / 2, nameBarY + nameBarH / 2, "???")
            end
        end
    end

    nvgRestore(vg)

    -- ===========================
    -- 3. 顶部栏: 返回 + 标题 + 统计 (在卡牌之后绘制，确保在最上层)
    -- ===========================
    -- 先绘制不透明背景条遮住卡牌
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, startY)
    nvgFillColor(vg, nvgRGBA(15, 20, 38, 230)); nvgFill(vg)

    -- 返回按钮
    nvgBeginPath(vg)
    nvgRoundedRect(vg, backX, topBarY, backW, backH, 8)
    nvgFillColor(vg, nvgRGBA(32, 38, 58, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(162, 128, 78, 170)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, topBarY + backH / 2, "< 返回")
    codexBackBtnRect = { x = backX, y = topBarY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 45)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, topBarY + backH / 2, "武灵录")

    -- 收集统计
    local ownedCount = 0
    for _, h in pairs(playerHeroes) do
        if h.owned then ownedCount = ownedCount + 1 end
    end
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(W - 14, topBarY + backH / 2, ownedCount .. "/" .. #HERO_CARDS)

    -- ===========================
    -- 4. 品质标签页按钮
    -- ===========================
    local tabY = topBarY + backH + 8
    local tabH = 36
    local tabTotalW = W - 20
    local tabCount = #TAB_DEFS
    local tabGap = 6
    local tabW = math.floor((tabTotalW - (tabCount - 1) * tabGap) / tabCount)
    local tabStartX = 10
    codexTabRects = {}
    local TAB_QUALITY_COLORS = {
        [0] = {160, 160, 160},                     -- 全部: 灰白
        [1] = {160, 180, 160},                     -- N: 灰绿
        [2] = {80, 180, 255},                      -- R: 蓝
        [3] = {200, 130, 255},                     -- SR: 紫
        [4] = {255, 200, 60},                      -- SSR: 金
        [5] = {255, 80, 120},                      -- 限定: 红粉
    }
    for ti = 1, tabCount do
        local tabIdx = ti - 1
        local tx = tabStartX + (ti - 1) * (tabW + tabGap)
        local isActive = (codexTab == tabIdx)
        local tc = TAB_QUALITY_COLORS[tabIdx]
        -- 按钮背景
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 6)
        if isActive then
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 50)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        else
            nvgFillColor(vg, nvgRGBA(30, 35, 50, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 75, 65, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end
        -- 标签文字
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 255))
        else
            nvgFillColor(vg, nvgRGBA(180, 175, 165, 160))
        end
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, TAB_DEFS[ti].label, nil)
        -- 数量角标
        local tabQCount = 0
        for hIdx, h in pairs(playerHeroes) do
            if h.owned then
                local c = HERO_CARDS[hIdx]
                if c then
                    local tabMatch = false
                    if tabIdx == 0 then
                        tabMatch = true
                    elseif TAB_DEFS[ti].quality == QUALITY.LEGENDARY then
                        tabMatch = (c.quality == QUALITY.LEGENDARY or c.quality == QUALITY.LIMITED)
                    else
                        tabMatch = (c.quality == TAB_DEFS[ti].quality)
                    end
                    if tabMatch then tabQCount = tabQCount + 1 end
                end
            end
        end
        if tabQCount > 0 and not isActive then
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 140))
            nvgText(vg, tx + tabW - 2, tabY + 1, tostring(tabQCount), nil)
        end
        -- 存储点击区域
        codexTabRects[ti] = { x = tx, y = tabY, w = tabW, h = tabH, tabIdx = tabIdx }
    end

    -- 滚动条指示器 (内容超出可见区域时显示)
    if contentH > visibleH then
        local scrollBarH = math.max(30, visibleH * (visibleH / contentH))
        local scrollRange = visibleH - scrollBarH
        local scrollRatio = codexScroll.y / minScrollY  -- 0~1
        local scrollBarY = startY + scrollRange * scrollRatio
        nvgBeginPath(vg)
        nvgRoundedRect(vg, W - 6, scrollBarY, 3, scrollBarH, 1.5)
        nvgFillColor(vg, nvgRGBA(180, 160, 120, math.floor(60 + 40 * scrollRatio)))
        nvgFill(vg)
    end

    -- 底部装饰文字
    nvgFontSize(vg, 19)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local tipPulse = 0.4 + 0.6 * math.abs(math.sin(t * 1.2))
    local tipInkAlpha = math.floor(100 * tipPulse)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(tipInkAlpha * 0.54)))
    nvgText(vg, cx - 1, H - 20, "集齐武灵, 天道可期", nil)
    nvgText(vg, cx + 1, H - 20, "集齐武灵, 天道可期", nil)
    nvgText(vg, cx, H - 21, "集齐武灵, 天道可期", nil)
    nvgText(vg, cx, H - 19, "集齐武灵, 天道可期", nil)
    nvgFillColor(vg, nvgRGBA(30, 25, 20, tipInkAlpha))
    nvgText(vg, cx, H - 20, "集齐武灵, 天道可期", nil)

    -- 漂浮粒子
    for i = 1, 5 do
        local px = W * (0.1 + 0.8 * ((i * 97 + math.floor(t * 15)) % 100) / 100)
        local py = H * (0.05 + 0.12 * math.sin(t * 0.5 + i * 1.8))
        local pr = 1 + math.sin(t * 1.8 + i) * 0.5
        local pa = math.floor(25 + 18 * math.sin(t * 1.3 + i * 0.9))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(200, 210, 240, pa)); nvgFill(vg)
    end
end


-- ============================================================================
-- 武灵详情养成页 - 设计坐标
-- ============================================================================
function DrawHeroDetailScreen()
    if gameState.phase ~= "HERO_DETAIL" then return end

    local idx = heroDetailState.cardIdx
    if idx < 1 or idx > #HERO_CARDS then return end

    local card = HERO_CARDS[idx]
    local hero = playerHeroes[idx]
    if not hero or not hero.owned then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer
    local cons = hero.constellation

    -- 1. 统一菜单背景
    DrawCodexBg(W, H)

    nvgFontFaceId(vg, GetMainFont())

    -- === 横屏布局: 左侧卡牌(280px) + 右侧信息(可滚动) ===
    local LEFT_COL_W = 280
    local TOP_H = 44  -- 顶栏高度
    local RIGHT_X = LEFT_COL_W + 8
    local RIGHT_W = W - RIGHT_X - 8

    -- 2. 顶部栏: 返回 + 标题
    local topBarY = 6
    local backW, backH = 90, 36
    local backX = 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, topBarY, backW, backH, 4)
    nvgFillColor(vg, nvgRGBA(20, 25, 40, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, topBarY + backH / 2, "< 返回")
    heroDetailBackBtnRect = { x = backX, y = topBarY, w = backW, h = backH }

    nvgFontSize(vg, 32)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, topBarY + backH / 2, "武灵详情")

    -- === 左侧面板: 卡牌 + 名称 + 品质 ===
    local leftCX = LEFT_COL_W / 2
    local bigCardW = 140
    local bigCardH = bigCardW / CARD_RATIO
    local bigCardX = leftCX - bigCardW / 2
    local bigCardY = TOP_H + 8
    DrawInventoryCard(bigCardX, bigCardY, bigCardW, bigCardH, card, cons, false)

    -- 名称
    local qName = QUALITY_NAMES[card.quality]
    local uc = UNIT_CLASS[card.unitClass]
    local infoY = bigCardY + bigCardH + 10

    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftCX, infoY, card.name)

    -- 品质 | 兵种 | 站位
    local posTag = "前排"
    if uc and uc.isRanged then
        posTag = "后排"
    end
    nvgFontSize(vg, 18)
    DrawWhiteInkText(leftCX, infoY + 22, qName .. " | " .. (uc and uc.name or "未知") .. " | " .. posTag)

    -- 兵种描述
    if uc then
        nvgFontSize(vg, 24)
        DrawWhiteInkText(leftCX, infoY + 42, uc.desc)
    end

    -- === 右侧面板: 可滚动内容 ===
    local contentTop = TOP_H + 4
    local contentH = H - contentTop - 4
    -- 使用虚拟 cursorY 追踪内容累计高度
    local scrollOff = heroDetailScroll.y
    local cursorY = contentTop + scrollOff  -- 起始绘制Y（受滚动偏移）

    -- 开启右侧裁剪区域
    nvgSave(vg)
    nvgScissor(vg, RIGHT_X - 2, contentTop, RIGHT_W + 4, contentH)

    local rightCX = RIGHT_X + RIGHT_W / 2

    -- 4.5 兵种战斗特性面板
    local traitY = cursorY
    if uc then
        local traitPanelW = RIGHT_W - 8
        local traitPanelX = RIGHT_X + 4

        -- 预计算特性数据
        local traits = {}
        local bt = uc.baseTroop or "infantry"
        local tierName = ({ "轻装", "重装", "精锐" })[uc.tier or 1] or "轻装"
        if bt == "infantry" then
            traits[#traits + 1] = { icon = "剑", color = {255,220,180}, text = tierName .. "步兵: 攻守均衡，边推进边斩杀挡路敌人" }
        elseif bt == "archer" then
            traits[#traits + 1] = { icon = "箭", color = {200,255,150}, text = tierName .. "弓兵: 远距离锁定目标，驻足瞄准射击" }
        elseif bt == "cavalry" then
            traits[#traits + 1] = { icon = "速", color = {255,200,80}, text = tierName .. "骑兵: 高速冲锋突进，机动性强" }
        elseif bt == "spear" then
            traits[#traits + 1] = { icon = "枪", color = {200,220,255}, text = tierName .. "枪兵: 长兵器攻击，克制骑兵" }
        else
            traits[#traits + 1] = { icon = "剑", color = {255,220,180}, text = "近战输出: 攻速快伤害均衡，边推进边斩杀挡路敌人" }
        end

        local statsLine = string.format("范围:%d  速度:%d  攻速:%.1fs  突破:%d",
            uc.atkRange, uc.speed, uc.atkCd, uc.breakDmg)
        if uc.spawnMax then
            statsLine = statsLine .. "  上限:" .. uc.spawnMax .. "只"
        end

        -- 先计算面板总高度: 标题(14) + 特性行(28+20*n) + 数值行(+20) + 规则行(+18) + 底边距(12)
        local contentBottom = 28 + #traits * 20 + 20 + 18
        local traitPanelH = contentBottom + 12

        -- 绘制背景
        nvgBeginPath(vg); nvgRoundedRect(vg, traitPanelX, traitY, traitPanelW, traitPanelH, 6)
        nvgFillColor(vg, nvgRGBA(20, 30, 45, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 180, 255, 220))
        nvgText(vg, traitPanelX + 10, traitY + 14, "战斗特性", nil)

        -- 绘制特性
        nvgFontSize(vg, 24)
        for i, tr in ipairs(traits) do
            local ty = traitY + 28 + (i - 1) * 20
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(tr.color[1], tr.color[2], tr.color[3], 240))
            nvgText(vg, traitPanelX + 22, ty, "[" .. tr.icon .. "]", nil)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 220, 230, 200))
            nvgText(vg, traitPanelX + 42, ty, tr.text, nil)
        end
        -- 数值行
        local numY = traitY + 28 + #traits * 20
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 170, 190, 160))
        nvgText(vg, rightCX, numY, statsLine, nil)



        traitY = traitY + traitPanelH + 4
    end

    -- 5. 属性面板 (含命格加成)
    local bonus = GetConstellationBonus(cons)
    local statsY = traitY + 6
    local panelW = RIGHT_W - 8
    local panelX = RIGHT_X + 4
    local panelH = 60

    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, statsY, panelW, panelH, 6)
    nvgFillColor(vg, nvgRGBA(15, 18, 30, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local statItems = {
        { label = "攻击", base = card.atk, mult = bonus.atkMult },
        { label = "防御", base = card.def, mult = bonus.defMult },
        { label = "生命", base = card.hp,  mult = bonus.hpMult },
    }
    local sCol = panelW / 3
    for si, st in ipairs(statItems) do
        local sx = panelX + (si - 0.5) * sCol
        local sy = statsY + 22
        -- 标签
        nvgFontSize(vg, 24)
        DrawWhiteInkText(sx, sy, st.label)
        -- 数值
        local finalVal = math.floor(st.base * st.mult)
        local valStr = tostring(finalVal)
        if st.mult > 1.0 then
            valStr = valStr .. string.format(" (+%d%%)", math.floor((st.mult - 1) * 100))
        end
        nvgFontSize(vg, 22)
        DrawWhiteInkText(sx, sy + 22, valStr)
    end

    -- 额外加成（突破伤害/出兵速率）
    local extraParts = {}
    if bonus.breakDmgAdd > 0 then
        extraParts[#extraParts + 1] = "突破伤害+" .. bonus.breakDmgAdd
    end
    if bonus.spawnRateMult > 1.0 then
        extraParts[#extraParts + 1] = string.format("出兵速率+%d%%", math.floor((bonus.spawnRateMult - 1) * 100))
    end
    local extraY = statsY + panelH + 6
    if #extraParts > 0 then
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(rightCX, extraY, table.concat(extraParts, "  |  "))
        extraY = extraY + 18
    end

    -- 5.5 兵符总加成面板
    local sealBonus = GetSealTotalBonus(idx)
    local hasSealAny = sealBonus and (
        sealBonus.atkPct > 0 or sealBonus.defPct > 0 or sealBonus.hpPct > 0 or
        sealBonus.extraTroops > 0 or sealBonus.critRate > 0 or sealBonus.dmgReduction > 0 or
        sealBonus.speedPct > 0 or sealBonus.atkSpeedPct > 0 or sealBonus.counterRate > 0 or
        sealBonus.breakDmgPct > 0 or sealBonus.deathExplosionPct > 0)
    if hasSealAny then
        local sealPanelX = panelX
        local sealPanelW = panelW

        -- 收集非零加成行
        local sealEntries = {}
        local sealSlotData = sealData[idx]
        if sealSlotData and sealSlotData.slots then
            for i = 1, SEAL_MAX_SLOTS do
                local sealSlot = sealSlotData.slots[i]
                if sealSlot then
                    local effect = SEAL_SLOT_EFFECTS[i]
                    if effect then
                        local tierData = effect[sealSlot.sealQ] or effect[1]
                        local lv = sealSlot.level or 1
                        local mainVal = (tierData.main or 0) * lv
                        local subVal = (tierData.sub or 0) * lv
                        sealEntries[#sealEntries + 1] = {
                            slotIdx = i, theme = effect.theme, level = lv,
                            mainName = effect.mainName, mainVal = mainVal,
                            mainUnit = (effect.mainKey == "extraTroops") and "" or "%",
                            subName = effect.subName, subVal = subVal,
                        }
                    end
                end
            end
        end

        -- 汇总行：攻+X% 防+X% 血+X%
        local summaryParts = {}
        if sealBonus.atkPct > 0 then summaryParts[#summaryParts + 1] = "攻+" .. string.format("%.0f", sealBonus.atkPct) .. "%" end
        if sealBonus.defPct > 0 then summaryParts[#summaryParts + 1] = "防+" .. string.format("%.0f", sealBonus.defPct) .. "%" end
        if sealBonus.hpPct > 0 then summaryParts[#summaryParts + 1] = "血+" .. string.format("%.0f", sealBonus.hpPct) .. "%" end
        -- 特殊效果汇总
        if sealBonus.extraTroops > 0 then summaryParts[#summaryParts + 1] = "兵力+" .. string.format("%.1f", sealBonus.extraTroops) end
        if sealBonus.critRate > 0 then summaryParts[#summaryParts + 1] = "暴击+" .. string.format("%.0f", sealBonus.critRate) .. "%" end
        if sealBonus.dmgReduction > 0 then summaryParts[#summaryParts + 1] = "减伤+" .. string.format("%.0f", sealBonus.dmgReduction) .. "%" end
        if sealBonus.speedPct > 0 then summaryParts[#summaryParts + 1] = "移速+" .. string.format("%.0f", sealBonus.speedPct) .. "%" end
        if sealBonus.atkSpeedPct > 0 then summaryParts[#summaryParts + 1] = "攻速+" .. string.format("%.0f", sealBonus.atkSpeedPct) .. "%" end
        if sealBonus.counterRate > 0 then summaryParts[#summaryParts + 1] = "反击+" .. string.format("%.0f", sealBonus.counterRate) .. "%" end
        if sealBonus.breakDmgPct > 0 then summaryParts[#summaryParts + 1] = "突破+" .. string.format("%.0f", sealBonus.breakDmgPct) .. "%" end
        if sealBonus.deathExplosionPct > 0 then summaryParts[#summaryParts + 1] = "爆炸+" .. string.format("%.0f", sealBonus.deathExplosionPct) .. "%" end

        -- 面板高度: 标题(28) + 汇总行(20) + 详情行(每行18) + 底边距(8)
        local sealPanelH = 28 + 22 + #sealEntries * 18 + 8

        nvgBeginPath(vg); nvgRoundedRect(vg, sealPanelX, extraY, sealPanelW, sealPanelH, 6)
        nvgFillColor(vg, nvgRGBA(25, 20, 15, 190)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 170, 80, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 215, 80, 230))
        nvgText(vg, sealPanelX + 10, extraY + 14, "兵符总加成", nil)

        -- 汇总行
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 255, 130, 220))
        nvgText(vg, rightCX, extraY + 38, table.concat(summaryParts, "  "), nil)

        -- 详情行
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        for ei, se in ipairs(sealEntries) do
            local ey = extraY + 50 + (ei - 1) * 18
            local tc2 = SEAL_SLOT_THEME_COLORS[se.slotIdx] or { 200, 200, 200 }
            nvgFillColor(vg, nvgRGBA(tc2[1], tc2[2], tc2[3], 210))
            local txt = SEAL_SLOT_NAMES[se.slotIdx] .. " " .. se.theme
            if se.mainName then
                txt = txt .. "  " .. se.mainName .. "+" .. string.format("%.1f", se.mainVal) .. se.mainUnit
            end
            if se.subName and se.subVal > 0 then
                txt = txt .. "  " .. se.subName .. "+" .. string.format("%.1f", se.subVal) .. "%"
            end
            txt = txt .. "  Lv" .. se.level
            nvgText(vg, sealPanelX + 10, ey, txt, nil)
        end

        extraY = extraY + sealPanelH + 6
    end

    -- 6. 命格进度 (C0~C6 横排) — 右栏内
    local constY = extraY + 10
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(rightCX, constY, "命格进度")

    local constStartY = constY + 20
    local nodeR = 14
    local constMargin = 16
    local nodeGap = (RIGHT_W - constMargin * 2) / 7
    local nodeStartX = RIGHT_X + constMargin + nodeGap / 2

    for c = 0, GameConfig.MAX_CONSTELLATION do
        local nx = nodeStartX + c * nodeGap
        local ny = constStartY + nodeR
        local isActive = c <= cons
        local isCurrent = c == cons

        -- 连接线
        if c < GameConfig.MAX_CONSTELLATION then
            local nextActive = (c + 1) <= cons
            nvgBeginPath(vg)
            nvgMoveTo(vg, nx + nodeR, ny)
            nvgLineTo(vg, nx + nodeGap - nodeR, ny)
            nvgStrokeWidth(vg, 2)
            nvgStrokeColor(vg, nvgRGBA(180, 155, 100, nextActive and 180 or 40))
            nvgStroke(vg)
        end

        -- 节点圆
        if isCurrent then
            local pulse = 0.6 + 0.4 * math.sin(t * 3)
            local glowR = nodeR + 6 * pulse
            local glow = nvgRadialGradient(vg, nx, ny, nodeR - 2, glowR,
                nvgRGBA(220, 190, 120, math.floor(60 * pulse)),
                nvgRGBA(220, 190, 120, 0))
            nvgBeginPath(vg); nvgCircle(vg, nx, ny, glowR)
            nvgFillPaint(vg, glow); nvgFill(vg)
        end

        nvgBeginPath(vg); nvgCircle(vg, nx, ny, nodeR)
        if isActive then
            nvgFillColor(vg, nvgRGBA(200, 170, 100, 220))
        else
            nvgFillColor(vg, nvgRGBA(40, 38, 35, 200))
        end
        nvgFill(vg)
        nvgStrokeWidth(vg, isCurrent and 2 or 1)
        nvgStrokeColor(vg, nvgRGBA(200, 170, 100, isActive and 220 or 50))
        nvgStroke(vg)

        -- 节点文字
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            DrawWhiteInkText(nx, ny, "C" .. c)
        else
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 60))
            nvgText(vg, nx, ny, "C" .. c, nil)
        end

        -- 下方加成标注
        local bonusC = GameConfig.CONSTELLATION_BONUS[c]
        if bonusC then
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            local atkPct = math.floor((bonusC.atkMult - 1) * 100)
            local label = atkPct > 0 and ("+" .. atkPct .. "%") or "基础"
            if isActive then
                DrawWhiteInkText(nx, ny + nodeR + 3, label)
            else
                nvgFillColor(vg, nvgRGBA(200, 190, 160, 50))
                nvgText(vg, nx, ny + nodeR + 3, label, nil)
            end
        end
    end

    -- 更新 extraY 为命格区域底部
    extraY = constStartY + nodeR * 2 + 24

    -- 7. 人物生平面板 — 右栏内
    if card.bio then
        local bioY = extraY + 6
        local bioPanelW = RIGHT_W - 8
        local bioPanelX = RIGHT_X + 4
        local bioText = card.bio
        -- 预计算文本高度
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 18)
        local textW = bioPanelW - 24
        local bounds = {}
        nvgTextBoxBounds(vg, bioPanelX + 12, 0, textW, bioText, bounds)
        local textH = bounds[4] - bounds[2]
        local bioPanelH = 14 + 20 + 8 + textH + 12  -- 顶边距+标题行+间距+文本+底边距

        -- 面板背景
        nvgBeginPath(vg); nvgRoundedRect(vg, bioPanelX, bioY, bioPanelW, bioPanelH, 6)
        nvgFillColor(vg, nvgRGBA(20, 30, 45, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 155, 100, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 175, 120, 220))
        nvgText(vg, bioPanelX + 10, bioY + 14, "人物生平", nil)

        -- 装饰短线
        nvgBeginPath(vg)
        nvgMoveTo(vg, bioPanelX + 10, bioY + 26)
        nvgLineTo(vg, bioPanelX + bioPanelW - 10, bioY + 26)
        nvgStrokeColor(vg, nvgRGBA(180, 155, 100, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

        -- 生平文本（自动换行）
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(210, 210, 220, 200))
        nvgTextBox(vg, bioPanelX + 12, bioY + 34, textW, bioText)

        -- 记录总内容高度(从 bio 面板底部)
        extraY = bioY + bioPanelH + 10
    end

    -- 滚动范围限制: 内容总高度 = extraY - contentTop (去掉滚动偏移)
    local totalContentH = (extraY - scrollOff) - contentTop
    local maxScroll = 0
    local minScroll = -(math.max(0, totalContentH - contentH))
    heroDetailScroll.y = math.max(minScroll, math.min(maxScroll, heroDetailScroll.y))

    -- 关闭右侧裁剪区域
    nvgRestore(vg)

    -- 漂浮粒子（全屏范围，不受裁剪）
    for i = 1, 4 do
        local px = W * (0.1 + 0.8 * ((i * 113 + math.floor(t * 16)) % 100) / 100)
        local py = H * (0.05 + 0.12 * math.sin(t * 0.5 + i * 1.6))
        local pr = 1 + math.sin(t * 1.8 + i) * 0.5
        local pa = math.floor(20 + 16 * math.sin(t * 1.3 + i * 0.9))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(200, 210, 240, pa)); nvgFill(vg)
    end
end


-- ============================================================================
-- 玩家详情页 - 设计坐标
-- ============================================================================
function DrawPlayerDetailScreen()
    if gameState.phase ~= "PLAYER_DETAIL" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer

    -- 1. 统一菜单背景
    DrawCodexBg(W, H)

    nvgFontFaceId(vg, GetMainFont())

    -- === 横屏布局: 左侧头像区(260px) + 右侧信息(可滚动) ===
    local LEFT_COL_W = 260
    local TOP_H = 40
    local RIGHT_X = LEFT_COL_W + 8
    local RIGHT_W = W - RIGHT_X - 8
    local rightCX = RIGHT_X + RIGHT_W / 2

    -- 2. 顶部栏: 返回 + 标题
    local backW, backH = 90, 36
    local backX = 10
    local backY = 4
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 4)
    nvgFillColor(vg, nvgRGBA(40, 20, 15, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 70, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    playerDetailBackBtnRect = { x = backX, y = backY, w = backW, h = backH }

    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, backY + backH / 2, "冒险者详情")

    -- === 左侧面板: 头像 + 名字 + 阵营 + 经验 + 编辑按钮 ===
    local leftCX = LEFT_COL_W / 2

    -- 3. 头像区
    local avatarSize = 72
    local avatarX = leftCX - avatarSize / 2
    local avatarY = TOP_H + 8
    -- 头像边框
    nvgBeginPath(vg); nvgRoundedRect(vg, avatarX - 3, avatarY - 3, avatarSize + 6, avatarSize + 6, 8)
    nvgFillColor(vg, nvgRGBA(90, 45, 55, 200)); nvgFill(vg)
    -- 头像图 (用IMG.avatarSheet)
    if IMG.avatarSheet >= 0 then
        local avData = AVATAR_DATA[playerInfo.avatarIdx] or AVATAR_DATA[1]
        local imgW, imgH = 512, 768
        local cellW = imgW / AVATAR_COLS
        local cellH = imgH / AVATAR_ROWS
        local sx = avData.col * cellW
        local sy = avData.row * cellH
        local pat = nvgImagePattern(vg, avatarX - sx * (avatarSize / cellW),
            avatarY - sy * (avatarSize / cellH),
            imgW * (avatarSize / cellW), imgH * (avatarSize / cellH),
            0, IMG.avatarSheet, 1.0)
        nvgBeginPath(vg); nvgRoundedRect(vg, avatarX, avatarY, avatarSize, avatarSize, 5)
        nvgFillPaint(vg, pat); nvgFill(vg)
    end

    -- 编辑资料按钮 (头像右侧)
    local editBtnW, editBtnH = 70, 32
    local editBtnX = avatarX + avatarSize + 8
    local editBtnY = avatarY + avatarSize / 2 - editBtnH / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, editBtnX, editBtnY, editBtnW, editBtnH, 5)
    nvgFillColor(vg, nvgRGBA(50, 40, 60, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 160, 120, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 210, 180, 220))
    nvgText(vg, editBtnX + editBtnW / 2, editBtnY + editBtnH / 2, "编辑资料", nil)
    playerDetailEditBtnRect = { x = editBtnX, y = editBtnY, w = editBtnW, h = editBtnH }

    -- 名字
    local nameY = avatarY + avatarSize + 16
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftCX, nameY, playerInfo.name)

    -- 阵营
    local factionInfoProfile = CloudManager.GetFactionInfo()
    local profileRoleText = ""
    if factionInfoProfile and factionInfoProfile.name and #factionInfoProfile.name > 0 then
        profileRoleText = factionInfoProfile.name .. " · " .. (CloudManager.GetRoleName(factionInfoProfile.role) or "成员")
    else
        profileRoleText = "无阵营"
    end
    nvgFontSize(vg, 20)
    DrawWhiteInkText(leftCX, nameY + 24, profileRoleText)

    -- 经验条
    local expBarW = LEFT_COL_W - 40
    local expBarH = 10
    local expBarX = leftCX - expBarW / 2
    local expBarY = nameY + 48
    nvgBeginPath(vg); nvgRoundedRect(vg, expBarX, expBarY, expBarW, expBarH, 4)
    nvgFillColor(vg, nvgRGBA(30, 30, 40, 200)); nvgFill(vg)
    local maxRank = #GameConfig.RANK_EXP_TABLE
    local isMaxLevel = playerInfo.rankIdx >= maxRank
    local curRankExp = GameConfig.RANK_EXP_TABLE[playerInfo.rankIdx] or 0
    local nextRankExp = GameConfig.RANK_EXP_TABLE[playerInfo.rankIdx + 1]
    local expRatio = 1.0
    if not isMaxLevel and nextRankExp then
        expRatio = math.min(1, (playerInfo.exp - curRankExp) / math.max(1, nextRankExp - curRankExp))
    end
    local fillW = expBarW * expRatio
    if fillW > 1 then
        local expGrad = nvgLinearGradient(vg, expBarX, expBarY, expBarX + fillW, expBarY,
            nvgRGBA(100, 200, 255, 220), nvgRGBA(80, 160, 220, 220))
        nvgBeginPath(vg); nvgRoundedRect(vg, expBarX, expBarY, fillW, expBarH, 4)
        nvgFillPaint(vg, expGrad); nvgFill(vg)
    end
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if isMaxLevel then
        DrawWhiteInkText(leftCX, expBarY + expBarH + 14, "已满级")
    else
        DrawWhiteInkText(leftCX, expBarY + expBarH + 14,
            string.format("经验: %d / %d", playerInfo.exp - curRankExp, nextRankExp - curRankExp))
    end

    -- 战力评分 (左侧居中)
    local powerY = expBarY + expBarH + 38
    local myTotalPower = CalcPlayerTotalPower()
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local powerText = "总战力 " .. FormatPower(myTotalPower)
    DrawWhiteInkText(leftCX, powerY, powerText)

    -- "?" 按钮 (战力说明)
    local powerTextW = nvgTextBounds(vg, 0, 0, powerText, nil)
    local qBtnX = leftCX + powerTextW / 2 + 8
    local qBtnR = 10
    nvgBeginPath(vg); nvgCircle(vg, qBtnX, powerY, qBtnR)
    nvgFillColor(vg, nvgRGBA(80, 70, 55, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 180, 120, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 230))
    nvgText(vg, qBtnX, powerY, "?", nil)
    playerDetailPowerHelpRect = { cx = qBtnX, cy = powerY, r = qBtnR + 4, isCircle = true }

    -- 战力说明弹窗（已移至 DrawPowerExplainPopup，在 DrawPlayerDetailScreen 之后渲染，避免层级问题）

    -- === 右侧面板: 可滚动内容 ===
    local contentTop = TOP_H + 2
    local contentH = H - contentTop - 4
    local scrollOff = playerDetailScroll.y
    local cursorY = contentTop + scrollOff

    -- 开启右侧裁剪区域
    nvgSave(vg)
    nvgScissor(vg, RIGHT_X - 2, contentTop, RIGHT_W + 4, contentH)

    -- 4. 统计面板
    local statsY = cursorY
    local panelW = RIGHT_W - 8
    local panelX = RIGHT_X + 4
    local panelH = 80

    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, statsY, panelW, panelH, 6)
    nvgFillColor(vg, nvgRGBA(15, 18, 30, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 统计数据
    local ownedCount = 0
    local totalConst = 0
    for _, h in pairs(playerHeroes) do
        if h.owned then
            ownedCount = ownedCount + 1
            totalConst = totalConst + h.constellation
        end
    end

    local stats = {
        { label = "玉壁", value = FormatJade(playerInfo.jade) },
        { label = "武灵收集", value = ownedCount .. "/" .. #HERO_CARDS },
        { label = "总命格", value = tostring(totalConst) },
    }
    local sColW = panelW / #stats
    for si, st in ipairs(stats) do
        local sx = panelX + (si - 1) * sColW + sColW / 2
        local sy = statsY + 20
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(sx, sy, st.label)
        nvgFontSize(vg, 28)
        DrawWhiteInkText(sx, sy + 28, st.value)
    end

    -- 4.5 已装备武技栏
    local skillSectionY = statsY + panelH + 8
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(rightCX, skillSectionY, "已装备武技")

    local skIconSize = 46
    local skSlotW = 68
    local skCount = #playerEquippedSkills
    local skRowW = skCount * skSlotW
    local skStartX = rightCX - skRowW / 2
    local skStartY = skillSectionY + 20
    playerDetailSkillRects = playerDetailSkillRects or {}
    for k in pairs(playerDetailSkillRects) do playerDetailSkillRects[k] = nil end

    if skCount == 0 then
        nvgFontSize(vg, 22)
        DrawWhiteInkText(rightCX, skStartY + skIconSize / 2, "暂无装备武技")
    else
        for si, skIdx in ipairs(playerEquippedSkills) do
            local sk = SKILL_TECHNIQUES[skIdx]
            if sk then
                local skTier = SKILL_TIERS[sk.tier]
                local stc = skTier.color
                local slotCX = skStartX + (si - 1) * skSlotW + skSlotW / 2
                local mx = slotCX - skIconSize / 2
                local my = skStartY

                -- 底板
                nvgBeginPath(vg); nvgRoundedRect(vg, mx - 2, my - 2, skIconSize + 4, skIconSize + 4, 6)
                nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], 60)); nvgFill(vg)
                nvgBeginPath(vg); nvgRoundedRect(vg, mx, my, skIconSize, skIconSize, 5)
                nvgFillColor(vg, nvgRGBA(15, 18, 30, 220)); nvgFill(vg)

                -- 图标
                drawSkillIcon(sk.iconIdx, mx + 3, my + 3, skIconSize - 6, 3)

                -- 边框
                nvgBeginPath(vg); nvgRoundedRect(vg, mx, my, skIconSize, skIconSize, 5)
                nvgStrokeColor(vg, nvgRGBA(stc[1], stc[2], stc[3], 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

                -- 武技名 (限制宽度, 截断显示)
                nvgFontSize(vg, 24)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                local maxTextW = skSlotW - 4
                local displayName = sk.name
                if nvgTextBounds(vg, 0, 0, displayName, nil) > maxTextW then
                    -- 截断到合适长度
                    for ci = #displayName - 1, 2, -1 do
                        local sub = string.sub(displayName, 1, ci) .. ".."
                        if nvgTextBounds(vg, 0, 0, sub, nil) <= maxTextW then
                            displayName = sub; break
                        end
                    end
                end
                DrawWhiteInkText(slotCX, my + skIconSize + 6, displayName)

                -- 存储点击区域
                playerDetailSkillRects[si] = { x = mx - 4, y = my - 4, w = skIconSize + 8, h = skIconSize + 28, skIdx = skIdx }
            end
        end
    end

    local skillSectionH = skIconSize + 30

    -- 5. 拥有武灵预览 (小卡牌横排, 在右栏裁剪内)
    local previewY = skillSectionY + skillSectionH + 10
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(rightCX, previewY, "我的武灵")

    local miniCardW = 54
    local miniCardH = miniCardW / CARD_RATIO
    local miniGap = 12
    local ownedList = {}
    for i = 1, #HERO_CARDS do
        if playerHeroes[i] and playerHeroes[i].owned then
            table.insert(ownedList, i)
        end
    end
    local rowCols = math.floor((RIGHT_W - 8) / (miniCardW + miniGap))
    if rowCols < 3 then rowCols = 3 end
    local miniStartY = previewY + 18
    playerDetailHeroRects = playerDetailHeroRects or {}
    for k in pairs(playerDetailHeroRects) do playerDetailHeroRects[k] = nil end
    local gridW = rowCols * miniCardW + (rowCols - 1) * miniGap
    local gridStartX = rightCX - gridW / 2
    local bottomY = miniStartY  -- 追踪最底部
    for oi, heroIdx in ipairs(ownedList) do
        local c = ((oi - 1) % rowCols)
        local r = math.floor((oi - 1) / rowCols)
        local mx = gridStartX + c * (miniCardW + miniGap)
        local my = miniStartY + r * (miniCardH + miniGap + 4)
        local hCard = HERO_CARDS[heroIdx]
        local hCons = playerHeroes[heroIdx].constellation
        DrawInventoryCard(mx, my, miniCardW, miniCardH, hCard, hCons, false)
        playerDetailHeroRects[oi] = { x = mx, y = my, w = miniCardW, h = miniCardH, heroIdx = heroIdx }
        if my + miniCardH > bottomY then bottomY = my + miniCardH end
    end

    -- 滚动范围限制
    local totalContentH = (bottomY + 10 - scrollOff) - contentTop
    local maxScroll = 0
    local minScroll = -(math.max(0, totalContentH - contentH))
    playerDetailScroll.y = math.max(minScroll, math.min(maxScroll, playerDetailScroll.y))

    -- 关闭右侧裁剪区域
    nvgRestore(vg)

    -- 漂浮粒子（全屏范围，不受裁剪）
    for i = 1, 5 do
        local px = W * (0.1 + 0.8 * ((i * 127 + math.floor(t * 14)) % 100) / 100)
        local py = H * (0.05 + 0.1 * math.sin(t * 0.45 + i * 1.7))
        local pr = 1 + math.sin(t * 1.6 + i) * 0.5
        local pa = math.floor(22 + 16 * math.sin(t * 1.2 + i * 1.0))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(200, 210, 240, pa)); nvgFill(vg)
    end
end


-- ============================================================================
-- 武技界面 - 设计坐标
-- ============================================================================
