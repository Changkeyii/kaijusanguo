-- ui/codex_heroes.lua - 三国武灵录 (从 codex.lua 拆分)
-- ============================================================================
-- ui/codex.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 武将图鉴界面 - 设计坐标
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
    -- 3. 英雄网格 (自适应列数, 可滚动) — 一屏显示2.5行
    -- ===========================
    local minGap = 15  -- 卡牌之间最小间距
    local startY = 110  -- 为标签页留空间
    local bottomPad = 10  -- 底部留白
    local visibleH = H - startY - bottomPad
    -- 反推卡片高度: 2.5行 × (cardH + gap) = visibleH
    local cardH = math.floor((visibleH - 2.5 * minGap) / 2.5)
    local cardW = math.floor(cardH * CARD_RATIO)
    -- 根据可用宽度自适应列数 (保证间距 >= minGap)
    local gridPadX = 15  -- 网格左右边距
    local availW = W - gridPadX * 2
    local cols = math.max(1, math.floor((availW + minGap) / (cardW + minGap)))
    local gap = (cols > 1) and math.floor((availW - cols * cardW) / (cols - 1)) or 0
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
    DrawWhiteInkText(cx, topBarY + backH / 2, "武将图鉴")

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
    nvgText(vg, cx - 1, H - 20, "集齐武将, 天道可期", nil)
    nvgText(vg, cx + 1, H - 20, "集齐武将, 天道可期", nil)
    nvgText(vg, cx, H - 21, "集齐武将, 天道可期", nil)
    nvgText(vg, cx, H - 19, "集齐武将, 天道可期", nil)
    nvgFillColor(vg, nvgRGBA(30, 25, 20, tipInkAlpha))
    nvgText(vg, cx, H - 20, "集齐武将, 天道可期", nil)

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
-- 武将详情养成页 - 设计坐标
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
    DrawWhiteInkText(cx, topBarY + backH / 2, "武将详情")

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
    DrawWhiteInkText(leftCX, infoY + 26, qName .. " | " .. (uc and uc.name or "未知") .. " | " .. posTag)

    -- 兵种描述
    if uc then
        nvgFontSize(vg, 24)
        DrawWhiteInkText(leftCX, infoY + 52, uc.desc)
    end

    -- 命格星标 (左侧卡牌下方)
    do
        local starY = infoY + 78
        local starSize = 20
        local starGap = 4
        local totalStars = GameConfig.MAX_CONSTELLATION + 1  -- C0~C6 = 7颗
        local totalStarW = totalStars * starSize + (totalStars - 1) * starGap
        local starStartX = leftCX - totalStarW / 2

        for c = 0, GameConfig.MAX_CONSTELLATION do
            local sx = starStartX + c * (starSize + starGap) + starSize / 2
            local sy = starY
            local isActive = c <= cons
            local isCurrent = c == cons

            -- 当前命格发光
            if isCurrent then
                local pulse = 0.6 + 0.4 * math.sin(t * 3)
                local glowR = starSize * 0.8
                local glow = nvgRadialGradient(vg, sx, sy, 2, glowR,
                    nvgRGBA(255, 215, 80, math.floor(50 * pulse)),
                    nvgRGBA(255, 215, 80, 0))
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, glowR)
                nvgFillPaint(vg, glow); nvgFill(vg)
            end

            nvgFontSize(vg, starSize)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if isActive then
                nvgFillColor(vg, nvgRGBA(255, 215, 80, 240))
                nvgText(vg, sx, sy, "★", nil)
            else
                nvgFillColor(vg, nvgRGBA(120, 110, 90, 100))
                nvgText(vg, sx, sy, "☆", nil)
            end
        end

        -- 命格等级文字
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local bonusC = GameConfig.CONSTELLATION_BONUS[cons]
        local bonusStr = ""
        if bonusC then
            local atkPct = math.floor((bonusC.atkMult - 1) * 100)
            bonusStr = atkPct > 0 and ("  全属性+" .. atkPct .. "%") or ""
        end
        nvgFillColor(vg, nvgRGBA(240, 220, 160, 230))
        nvgText(vg, leftCX, starY + 18, "命格 C" .. cons .. bonusStr, nil)
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

        -- 先计算面板总高度: 标题(18) + 特性行(30+26*n) + 数值行(+24) + 底边距(12)
        local contentBottom = 30 + #traits * 26 + 24
        local traitPanelH = contentBottom + 12

        -- 绘制背景
        nvgBeginPath(vg); nvgRoundedRect(vg, traitPanelX, traitY, traitPanelW, traitPanelH, 6)
        nvgFillColor(vg, nvgRGBA(20, 30, 45, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 120, 180, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 180, 255, 230))
        nvgText(vg, traitPanelX + 10, traitY + 16, "战斗特性", nil)

        -- 绘制特性
        nvgFontSize(vg, 24)
        for i, tr in ipairs(traits) do
            local ty = traitY + 30 + (i - 1) * 26
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(tr.color[1], tr.color[2], tr.color[3], 240))
            nvgText(vg, traitPanelX + 22, ty, "[" .. tr.icon .. "]", nil)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(235, 235, 240, 230))
            nvgText(vg, traitPanelX + 42, ty, tr.text, nil)
        end
        -- 数值行
        local numY = traitY + 30 + #traits * 26
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(190, 200, 220, 220))
        nvgText(vg, rightCX, numY, statsLine, nil)



        traitY = traitY + traitPanelH + 4
    end

    local panelW = RIGHT_W - 8
    local panelX = RIGHT_X + 4
    local extraY = traitY + 6

    -- 5.2 基础属性面板 (武力/智力/体力/技法/速度 + 暴击)
    do
        local s5 = card.stats5 or { str = 50, int = 50, vit = 50, tec = 50, spd = 50 }
        local sealBonus0 = GetSealTotalBonus(idx)
        local critVal = (sealBonus0 and sealBonus0.critRate or 0) + (s5.tec or 50) * 0.1
        local s5PanelX = panelX
        local s5PanelW = panelW
        local s5PanelY = extraY
        local s5LineH = 24
        local s5PanelH = 30 + 6 * s5LineH + 8  -- 标题 + 6行 + 底边距

        nvgBeginPath(vg); nvgRoundedRect(vg, s5PanelX, s5PanelY, s5PanelW, s5PanelH, 6)
        nvgFillColor(vg, nvgRGBA(20, 25, 40, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 140, 200, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 180, 255, 220))
        nvgText(vg, s5PanelX + 10, s5PanelY + 15, "基础属性", nil)

        -- 布局: [标签] 10px [进度条] 10px [数值(预留100%宽度)]
        -- 预测量最宽数值文本 "100%" 的宽度用于预留
        nvgFontSize(vg, 18)
        local valReserveW = nvgTextBounds(vg, 0, 0, "100%", nil) or 40
        local labelW = 36                          -- 两个汉字约36px @18pt
        local gap = 10
        local barLeft = s5PanelX + 10 + labelW + gap
        local barRight = s5PanelX + s5PanelW - 10 - valReserveW - gap
        local s5BarW = math.max(barRight - barLeft, 20)
        local s5BarH = 8

        local stats5Defs = {
            { label = "武力", val = s5.str, clr = {255, 140, 100} },
            { label = "智力", val = s5.int, clr = {120, 180, 255} },
            { label = "体力", val = s5.vit, clr = {100, 220, 130} },
            { label = "技法", val = s5.tec, clr = {255, 210, 80} },
            { label = "速度", val = s5.spd, clr = {100, 220, 200} },
            { label = "暴击", val = critVal, clr = {255, 100, 120}, isCrit = true },
        }
        for ai, attr in ipairs(stats5Defs) do
            local ay = s5PanelY + 30 + (ai - 1) * s5LineH + s5LineH / 2  -- 行垂直居中
            -- 标签(左)
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 220, 235, 240))
            nvgText(vg, s5PanelX + 10, ay, attr.label, nil)
            -- 进度条(中)
            local barY = ay
            nvgBeginPath(vg); nvgRoundedRect(vg, barLeft, barY - s5BarH / 2, s5BarW, s5BarH, 4)
            nvgFillColor(vg, nvgRGBA(40, 35, 25, 150)); nvgFill(vg)
            local fillW = math.floor(s5BarW * math.min(attr.val, 100) / 100)
            if fillW > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, barLeft, barY - s5BarH / 2, fillW, s5BarH, 4)
                nvgFillColor(vg, nvgRGBA(attr.clr[1], attr.clr[2], attr.clr[3], 200)); nvgFill(vg)
            end
            -- 数值(右, 左对齐到进度条右侧+10px)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(245, 245, 255, 240))
            if attr.isCrit then
                nvgText(vg, barRight + gap, ay, string.format("%.1f%%", attr.val), nil)
            else
                nvgText(vg, barRight + gap, ay, tostring(attr.val), nil)
            end
        end

        extraY = s5PanelY + s5PanelH + 6
    end

    -- 5.5 六德兵符总加成面板 (五维 + 暴击)
    local sealBonus = GetSealTotalBonus(idx)
    local hasSealAny = sealBonus and (
        sealBonus.strAdd > 0 or sealBonus.intAdd > 0 or sealBonus.vitAdd > 0 or
        sealBonus.tecAdd > 0 or sealBonus.spdAdd > 0 or sealBonus.critRate > 0)
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
                        local mainUnit = (effect.mainKey == "critRate") and "%" or ""
                        sealEntries[#sealEntries + 1] = {
                            slotIdx = i, theme = effect.theme, level = lv,
                            mainName = effect.mainName, mainVal = mainVal,
                            mainUnit = mainUnit,
                        }
                    end
                end
            end
        end

        -- 汇总行：五维+暴击
        local summaryParts = {}
        local summaryDefs = {
            { key = "strAdd", label = "武力", unit = "" },
            { key = "intAdd", label = "智力", unit = "" },
            { key = "vitAdd", label = "体力", unit = "" },
            { key = "tecAdd", label = "技法", unit = "" },
            { key = "spdAdd", label = "速度", unit = "" },
            { key = "critRate", label = "暴击", unit = "%" },
        }
        for _, sd in ipairs(summaryDefs) do
            local v = sealBonus[sd.key] or 0
            if v > 0 then
                if sd.unit == "%" then
                    summaryParts[#summaryParts + 1] = sd.label .. "+" .. string.format("%.1f", v) .. "%"
                else
                    summaryParts[#summaryParts + 1] = sd.label .. "+" .. string.format("%.0f", v)
                end
            end
        end

        -- 面板高度: 标题(28) + 汇总行(24) + 详情行(每行24) + 底边距(8)
        local sealPanelH = 28 + 24 + #sealEntries * 24 + 8

        nvgBeginPath(vg); nvgRoundedRect(vg, sealPanelX, extraY, sealPanelW, sealPanelH, 6)
        nvgFillColor(vg, nvgRGBA(25, 20, 15, 190)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 170, 80, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 215, 80, 230))
        nvgText(vg, sealPanelX + 10, extraY + 14, "六德兵符加成", nil)

        -- 汇总行
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 255, 130, 220))
        nvgText(vg, rightCX, extraY + 38, table.concat(summaryParts, "  "), nil)

        -- 详情行
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        for ei, se in ipairs(sealEntries) do
            local ey = extraY + 52 + (ei - 1) * 24
            local tc2 = SEAL_SLOT_THEME_COLORS[se.slotIdx] or { 200, 200, 200 }
            nvgFillColor(vg, nvgRGBA(tc2[1], tc2[2], tc2[3], 210))
            local txt = SEAL_SLOT_NAMES[se.slotIdx] .. " " .. se.theme
                .. "  " .. se.mainName .. "+" .. string.format("%.1f", se.mainVal) .. se.mainUnit
                .. "  Lv" .. se.level
            nvgText(vg, sealPanelX + 10, ey, txt, nil)
        end

        extraY = extraY + sealPanelH + 6
    end

    -- 5.8 装备管理 / 武技管理 按钮
    do
        local btnW, btnH = 120, 30
        local btnGap = 16
        local totalW = btnW * 2 + btnGap
        local btnStartX = RIGHT_X + (RIGHT_W - totalW) / 2
        local btnY = extraY

        -- 装备管理按钮
        nvgBeginPath(vg); nvgRoundedRect(vg, btnStartX, btnY, btnW, btnH, 5)
        nvgFillColor(vg, nvgRGBA(60, 110, 180, 190)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 160, 230, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, btnStartX + btnW / 2, btnY + btnH / 2, "装备管理", nil)
        heroDetailManageEquipRect = { x = btnStartX, y = btnY, w = btnW, h = btnH }

        -- 武技管理按钮
        local btn2X = btnStartX + btnW + btnGap
        nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, btnY, btnW, btnH, 5)
        nvgFillColor(vg, nvgRGBA(140, 80, 180, 190)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 120, 230, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, btn2X + btnW / 2, btnY + btnH / 2, "武技管理", nil)
        heroDetailManageSkillRect = { x = btn2X, y = btnY, w = btnW, h = btnH }

        extraY = btnY + btnH + 8
    end

    -- 6.5 招揽台词
    if card.recruitQuote then
        local quoteY = extraY
        local quotePanelW = RIGHT_W - 8
        local quotePanelX = RIGHT_X + 4
        -- 预计算台词文本高度
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 18)
        local quoteTextW = quotePanelW - 24
        local qBounds = nvgTextBoxBounds(vg, quotePanelX + 12, 0, quoteTextW, card.recruitQuote, nil)
        local quoteTextH = 18
        if qBounds and qBounds[4] and qBounds[2] then
            quoteTextH = math.max(18, qBounds[4] - qBounds[2])
        end
        local quotePanelH = 10 + quoteTextH + 10

        nvgBeginPath(vg); nvgRoundedRect(vg, quotePanelX, quoteY, quotePanelW, quotePanelH, 6)
        nvgFillColor(vg, nvgRGBA(25, 20, 15, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 170, 80, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 台词文本（无标题，直接显示）
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(245, 235, 210, 240))
        nvgTextBox(vg, quotePanelX + 12, quoteY + 10, quoteTextW, card.recruitQuote)

        extraY = quoteY + quotePanelH + 8
    end

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
        local bounds = nvgTextBoxBounds(vg, bioPanelX + 12, 0, textW, bioText, nil)
        local textH = 18
        if bounds and bounds[4] and bounds[2] then
            textH = math.max(18, bounds[4] - bounds[2])
        end
        local bioPanelH = 14 + 20 + 8 + textH + 12  -- 顶边距+标题行+间距+文本+底边距

        -- 面板背景
        nvgBeginPath(vg); nvgRoundedRect(vg, bioPanelX, bioY, bioPanelW, bioPanelH, 6)
        nvgFillColor(vg, nvgRGBA(20, 30, 45, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 155, 100, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 195, 130, 240))
        nvgText(vg, bioPanelX + 10, bioY + 14, "人物生平", nil)

        -- 装饰短线
        nvgBeginPath(vg)
        nvgMoveTo(vg, bioPanelX + 10, bioY + 26)
        nvgLineTo(vg, bioPanelX + bioPanelW - 10, bioY + 26)
        nvgStrokeColor(vg, nvgRGBA(180, 155, 100, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

        -- 生平文本（自动换行）
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(230, 230, 240, 240))
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

    -- === 左右切换武将箭头 ===
    -- 收集已拥有武将索引列表
    local ownedList = {}
    for i = 1, #HERO_CARDS do
        if playerHeroes[i] and playerHeroes[i].owned then
            ownedList[#ownedList + 1] = i
        end
    end
    -- 找到当前武将在已拥有列表中的位置
    local curPos = 0
    for i, v in ipairs(ownedList) do
        if v == idx then curPos = i; break end
    end
    local hasPrev = curPos > 1
    local hasNext = curPos < #ownedList

    -- 箭头参数
    local arrowW, arrowH = 28, 60
    local arrowCY = H / 2 + 20  -- 略偏下避开顶栏
    local breathOff = math.sin(t * 2.5) * 3  -- 呼吸动画水平偏移

    heroDetailNavPrevRect = nil
    heroDetailNavNextRect = nil

    -- 左箭头（上一个武将）
    if hasPrev then
        local ax = 2 + breathOff
        local ay = arrowCY - arrowH / 2
        -- 半透明背景胶囊
        nvgBeginPath(vg); nvgRoundedRect(vg, ax, ay, arrowW, arrowH, 6)
        nvgFillColor(vg, nvgRGBA(15, 20, 35, 140)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 155, 100, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        -- 箭头符号 <
        local acx, acy = ax + arrowW / 2, ay + arrowH / 2
        nvgBeginPath(vg)
        nvgMoveTo(vg, acx + 5, acy - 12)
        nvgLineTo(vg, acx - 6, acy)
        nvgLineTo(vg, acx + 5, acy + 12)
        nvgStrokeColor(vg, nvgRGBA(240, 220, 160, 220)); nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
        heroDetailNavPrevRect = { x = ax - 4, y = ay - 8, w = arrowW + 8, h = arrowH + 16 }
    end

    -- 右箭头（下一个武将）
    if hasNext then
        local ax = W - arrowW - 2 - breathOff
        local ay = arrowCY - arrowH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, ax, ay, arrowW, arrowH, 6)
        nvgFillColor(vg, nvgRGBA(15, 20, 35, 140)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 155, 100, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        -- 箭头符号 >
        local acx, acy = ax + arrowW / 2, ay + arrowH / 2
        nvgBeginPath(vg)
        nvgMoveTo(vg, acx - 5, acy - 12)
        nvgLineTo(vg, acx + 6, acy)
        nvgLineTo(vg, acx - 5, acy + 12)
        nvgStrokeColor(vg, nvgRGBA(240, 220, 160, 220)); nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
        heroDetailNavNextRect = { x = ax - 4, y = ay - 8, w = arrowW + 8, h = arrowH + 16 }
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

    -- 4.3 已装备兵甲栏 (7个装备槽)
    local equipSectionY = statsY + panelH + 8
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(rightCX, equipSectionY, "已装备兵甲")

    -- "管理装备" 快捷按钮
    local meBtnW, meBtnH = 68, 24
    local meBtnX = RIGHT_X + RIGHT_W - meBtnW - 8
    local meBtnY = equipSectionY - meBtnH / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, meBtnX, meBtnY, meBtnW, meBtnH, 4)
    nvgFillColor(vg, nvgRGBA(60, 110, 180, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 160, 230, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgText(vg, meBtnX + meBtnW / 2, meBtnY + meBtnH / 2, "管理装备", nil)
    heroDetailManageEquipRect = { x = meBtnX, y = meBtnY, w = meBtnW, h = meBtnH }

    local eqIconSize = 40
    local eqSlotW = 50
    local eqSlotGap = 4
    local eqRowW = 7 * eqSlotW + 6 * eqSlotGap
    local eqStartX = rightCX - eqRowW / 2
    local eqStartY = equipSectionY + 18
    local heroCardIdx = heroDetailState.cardIdx

    local hasAnyEquip = false
    for si = 1, 7 do
        local sx = eqStartX + (si - 1) * (eqSlotW + eqSlotGap)
        local sy = eqStartY

        -- 底板
        local eqItem = GetEquippedItem(si, heroCardIdx)
        if eqItem then
            hasAnyEquip = true
            local tc = EQUIP_TIERS[eqItem.tier or 1].color
            -- 品阶背景
            DrawEquipTierBg(sx, sy, eqIconSize, eqIconSize, eqItem.tier or 1, 5)
            -- 装备图标
            if IMG.equipmentSheet and IMG.equipmentSheet > 0 then
                DrawCardImage(sx + 2, sy + 2, eqIconSize - 4, eqIconSize - 4,
                    IMG.equipmentSheet, si - 1, eqItem.setIdx - 1,
                    EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
            end
            -- 边框
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, eqIconSize, eqIconSize, 5)
            nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        else
            -- 空槽
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, eqIconSize, eqIconSize, 5)
            nvgFillColor(vg, nvgRGBA(15, 18, 30, 160)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 70, 55, 80)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            -- 槽名
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(160, 150, 130, 120))
            nvgText(vg, sx + eqIconSize / 2, sy + eqIconSize / 2, EQUIP_SLOT_NAMES[si], nil)
        end
    end

    -- 套装效果提示
    local equipSectionH = eqIconSize + 4
    if hasAnyEquip then
        -- 统计套装件数
        local setCounts = {}
        for si = 1, 7 do
            local eqItem = GetEquippedItem(si, heroCardIdx)
            if eqItem and eqItem.setIdx then
                setCounts[eqItem.setIdx] = (setCounts[eqItem.setIdx] or 0) + 1
            end
        end
        -- 显示激活的套装
        local setTipY = eqStartY + eqIconSize + 4
        local hasBonusTip = false
        for setIdx, cnt in pairs(setCounts) do
            local setDef = EQUIPMENT_SETS[setIdx]
            if setDef then
                local bonusDesc = nil
                if cnt >= 7 then bonusDesc = setDef.setBonusDesc
                elseif cnt >= 4 then bonusDesc = setDef.setBonus4Desc
                elseif cnt >= 3 then bonusDesc = setDef.setBonus3Desc end
                if bonusDesc then
                    nvgFontSize(vg, 18)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    local sc = setDef.color
                    nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 200))
                    nvgText(vg, rightCX, setTipY, setDef.name .. "(" .. cnt .. "): " .. bonusDesc, nil)
                    setTipY = setTipY + 18
                    hasBonusTip = true
                end
            end
        end
        if hasBonusTip then
            equipSectionH = equipSectionH + (setTipY - (eqStartY + eqIconSize + 4))
        end
    end

    -- 4.5 已装备武技栏
    local skillSectionY = equipSectionY + equipSectionH + 8
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(rightCX, skillSectionY, "已装备武技")

    -- "管理武技" 快捷按钮
    local msBtnW, msBtnH = 68, 24
    local msBtnX = RIGHT_X + RIGHT_W - msBtnW - 8
    local msBtnY = skillSectionY - msBtnH / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, msBtnX, msBtnY, msBtnW, msBtnH, 4)
    nvgFillColor(vg, nvgRGBA(140, 80, 180, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 120, 230, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
    nvgText(vg, msBtnX + msBtnW / 2, msBtnY + msBtnH / 2, "管理武技", nil)
    heroDetailManageSkillRect = { x = msBtnX, y = msBtnY, w = msBtnW, h = msBtnH }

    local skIconSize = 46
    local skSlotW = 68
    local heroSkillList = GetHeroSkills(heroDetailState.cardIdx)
    local skCount = #heroSkillList
    local skRowW = math.max(skCount, 1) * skSlotW
    local skStartX = rightCX - skRowW / 2
    local skStartY = skillSectionY + 20
    playerDetailSkillRects = playerDetailSkillRects or {}
    for k in pairs(playerDetailSkillRects) do playerDetailSkillRects[k] = nil end

    if skCount == 0 then
        nvgFontSize(vg, 22)
        DrawWhiteInkText(rightCX, skStartY + skIconSize / 2, "暂无装备武技")
    else
        for si, skIdx in ipairs(heroSkillList) do
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
