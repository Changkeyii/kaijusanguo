-- ui/battle_hud_shop.lua - 三国武灵录 (从 battle_hud.lua 拆分)
-- ============================================================================
-- 信息面板 (左上角, 屏幕逻辑坐标)
-- ============================================================================

function DrawInfoPanel()
    if fontId < 0 then return end
    if longPressState.active or dragState.active or infoPopupState.show then return end  -- 操作中隐藏

    local panelW = 110
    local panelH = 88
    local ipOfsX = (gameSettings.infoPanelOffsetX or 0) * scale
    local ipOfsY = (gameSettings.infoPanelOffsetY or 0) * scale
    local px = 4 + ipOfsX
    local py = 26 * scale + offsetY + ipOfsY  -- HUD下方

    nvgSave(vg)

    -- 半透明古卷背景
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, panelW, panelH, 4)
    nvgFillColor(vg, nvgRGBA(10, 8, 5, 140)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 130, 70, 40))
    nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())
    local ly = py + 10

    -- 阵容加成
    local filledCount = 0
    local totalAtk = 0
    local totalDef = 0
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            filledCount = filledCount + 1
            local lm = 1 + ((slot.card.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
            totalAtk = totalAtk + math.floor(slot.card.atk * lm)
            totalDef = totalDef + math.floor(slot.card.def * lm)
        end
    end

    nvgFontSize(vg, 13.5)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    DrawWhiteInkText(px + 6, ly, "阵容 " .. filledCount .. "/" .. #PLAYER_SLOTS)
    ly = ly + 13

    DrawWhiteInkText(px + 6, ly, "总攻: " .. totalAtk)
    ly = ly + 12

    DrawWhiteInkText(px + 6, ly, "总防: " .. totalDef)
    ly = ly + 16

    -- 操作提示
    nvgFontSize(vg, 11.2)
    DrawWhiteInkText(px + 6, ly, "点击查看 - 拖拽换位")
    ly = ly + 10
    DrawWhiteInkText(px + 6, ly, "拖拽卡牌至石台放置")

    nvgRestore(vg)
end


-- ============================================================================
-- 底部商店 (暗黑水墨风)
-- ============================================================================

function DrawShop()
    local sl = shopLayout
    if sl.h <= 0 then return end

    if fontId < 0 then return end
    nvgFontFaceId(vg, GetMainFont())

    local isSHOP = (gameState.battlePhase == "SHOP")

    -- ========== 底栏: 只放卡牌 ==========
    local shopGrad = nvgLinearGradient(vg, 0, sl.y, 0, sl.y + sl.h,
        nvgRGBA(42, 35, 22, 240), nvgRGBA(28, 22, 14, 248))
    nvgBeginPath(vg); nvgRect(vg, 0, sl.y, screenW, sl.h)
    nvgFillPaint(vg, shopGrad); nvgFill(vg)

    -- 顶部金线
    local topLine1 = nvgLinearGradient(vg, 0, sl.y, screenW, sl.y,
        nvgRGBA(180, 150, 80, 0), nvgRGBA(180, 150, 80, 100))
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, sl.y + 0.5); nvgLineTo(vg, screenW, sl.y + 0.5)
    nvgStrokePaint(vg, topLine1)
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    -- 卡牌布局 (底栏居中)
    local cardCount = GameConfig.SHOP_SIZE
    local cardH = sl.h - 22
    local cardW = cardH * CARD_RATIO
    local gap = 8
    local totalCardsW = cardCount * cardW + (cardCount - 1) * gap
    local startX = (screenW - totalCardsW) / 2
    local cardY = sl.y + 8

    -- 提示文字
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    if gameState.isDummy and dummyState.prepPhase then
        DrawWhiteInkText(screenW / 2, sl.y + sl.h / 2, "武灵已就位，点击「开始挑战」出战")
    else
        DrawWhiteInkText(screenW / 2, sl.y + sl.h - 2, "点击查看 - 拖拽放置")
        -- 新手提示: 前3场战斗提示可点击查看详情
        if gameSettings.battleCount < 3 then
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 220, 120, math.floor(160 + 60 * math.sin((gameState.gameTime or 0) * 3))))
            nvgText(vg, screenW / 2, sl.y + 2, "提示: 点击卡牌可查看武灵详情", nil)
        end
    end

    -- 商店卡牌 (打桩准备阶段不显示)
    if not (gameState.isDummy and dummyState.prepPhase) then
    for i = 1, cardCount do
        local cx = startX + (i - 1) * (cardW + gap)
        local shopItem = shopCards[i]
        if shopItem and not shopItem.sold then
            local card = HERO_CARDS[shopItem.cardIdx]
            if card then
                DrawInventoryCard(cx, cardY, cardW, cardH, card, shopItem.constellation or 0, false)
                -- 费用标签
                local costStr = tostring(shopItem.cost)
                local canAfford = gameState.gold >= shopItem.cost
                local costBgColor = canAfford and nvgRGBA(30, 60, 40, 200) or nvgRGBA(60, 30, 30, 200)
                local costTxtColor = canAfford and nvgRGBA(100, 255, 180, 240) or nvgRGBA(255, 120, 100, 200)
                local costW = 28
                local costH = 13
                local costX = cx + cardW / 2 - costW / 2
                local costY = cardY + cardH + 1
                nvgBeginPath(vg); nvgRoundedRect(vg, costX, costY, costW, costH, 2)
                nvgFillColor(vg, costBgColor); nvgFill(vg)
                nvgFontSize(vg, 13.5)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, costTxtColor)
                nvgText(vg, costX + costW / 2, costY + costH / 2, costStr, nil)
            end
        elseif shopItem and shopItem.sold then
            -- 已购槽位：暗底 + "已购"文字，不显示"空"
            nvgBeginPath(vg); nvgRoundedRect(vg, cx, cardY, cardW, cardH, 3)
            nvgFillColor(vg, nvgRGBA(20, 16, 10, 100)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 65, 40, 40))
            nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
            nvgFontSize(vg, 13.5)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(120, 110, 90, 160))
            nvgText(vg, cx + cardW / 2, cardY + cardH / 2, "已购", nil)
        else
            DrawEmptyInvSlot(cx, cardY, cardW, cardH)
        end
        if not shopItem then shopItem = {} end
        shopItem._rect = { x = cx, y = cardY, w = cardW, h = cardH }
        if i <= #shopCards then shopCards[i]._rect = shopItem._rect end
    end
    end -- if not dummy prep
end


function DrawInventoryArrow(sl, isLeft)
    local ax = isLeft and sl.arrowLeftX or sl.arrowRightX
    local aw = isLeft and sl.arrowLeftW or sl.arrowRightW
    local ay = sl.y + 20
    local ah = sl.cardH
    local t = gameState.gameTime

    -- 是否可点击
    local canClick
    if isLeft then
        canClick = invScrollOffset > 0
    else
        canClick = invScrollOffset < math.max(0, #inventory - GameConfig.INVENTORY_VISIBLE)
    end

    local alpha = canClick and 180 or 50
    local pulse = canClick and (0.7 + 0.3 * math.sin(t * 3)) or 1.0

    -- 背景
    nvgBeginPath(vg); nvgRoundedRect(vg, ax, ay, aw, ah, 3)
    nvgFillColor(vg, nvgRGBA(25, 20, 12, math.floor(120 * pulse))); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 130, 70, math.floor(alpha * pulse * 0.4)))
    nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

    -- 箭头符号
    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 23)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 130, math.floor(alpha * pulse)))
        nvgText(vg, ax + aw / 2, ay + ah / 2, isLeft and "<" or ">", nil)
    end
end


function DrawEmptyInvSlot(x, y, w, h)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 3)
    nvgFillColor(vg, nvgRGBA(20, 16, 10, 100)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 65, 40, 40))
    nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(x + w / 2, y + h / 2, "空")
    end
end


-- 背包卡牌 (水墨风 + 命格标记)
function DrawInventoryCard(x, y, w, h, card, constellation, mergeable, hideName)
    local qc = QUALITY_COLORS[card.quality]
    local qg = QUALITY_GLOW[card.quality]
    local t = gameState.gameTime

    -- 外层品质光晕
    if qg and qg[4] > 0 then
        local pulse = 0.55 + 0.45 * math.sin(t * 2.2)
        local glowR = math.max(w, h) * 0.75
        local grad = nvgRadialGradient(vg, x + w / 2, y + h * 0.42, 2, glowR,
            nvgRGBA(qg[1], qg[2], qg[3], math.floor(qg[4] * pulse * 0.35)),
            nvgRGBA(qg[1], qg[2], qg[3], 0))
        nvgBeginPath(vg); nvgRoundedRect(vg, x - 4, y - 4, w + 8, h + 8, 6)
        nvgFillPaint(vg, grad); nvgFill(vg)
    end

    -- 可合成闪烁边框
    if mergeable then
        local mPulse = 0.5 + 0.5 * math.sin(t * 4)
        nvgBeginPath(vg); nvgRoundedRect(vg, x - 2, y - 2, w + 4, h + 4, 5)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 255, math.floor(100 + 120 * mPulse)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- 底板
    local paperGrad = nvgLinearGradient(vg, x, y, x, y + h,
        nvgRGBA(48, 40, 26, 248), nvgRGBA(32, 26, 14, 252))
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 4)
    nvgFillPaint(vg, paperGrad); nvgFill(vg)

    -- 四角装饰
    local cs = 2
    for _, cp in ipairs({
        { x + 3, y + 3 }, { x + w - 3 - cs, y + 3 },
        { x + 3, y + h - 3 - cs }, { x + w - 3 - cs, y + h - 3 - cs },
    }) do
        nvgBeginPath(vg); nvgRect(vg, cp[1], cp[2], cs, cs)
        nvgFillColor(vg, nvgRGBA(200, 165, 90, 60)); nvgFill(vg)
    end

    -- 角色图
    local imgY = y + 3
    local imgH = h - 20
    if GetHeroSheet(card) > 0 then
        local _sh, _sc, _sr = GetHeroSheetInfo(card)
        DrawCardImage(x + 3, imgY, w - 6, imgH, _sh, card.row, card.col, _sc, _sr)
        local fadeGrad = nvgLinearGradient(vg, x, imgY + imgH - 10, x, imgY + imgH,
            nvgRGBA(32, 26, 14, 0), nvgRGBA(32, 26, 14, 200))
        nvgBeginPath(vg); nvgRect(vg, x + 3, imgY + imgH - 10, w - 6, 10)
        nvgFillPaint(vg, fadeGrad); nvgFill(vg)
    end

    -- 外边框 (品质描金)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 4)
    nvgStrokeColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 170))
    nvgStrokeWidth(vg, 1.3); nvgStroke(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, x + 2, y + 2, w - 4, h - 4, 3)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 100, 25))
    nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

    if fontId < 0 then return end
    nvgFontFaceId(vg, GetMainFont())

    -- 左上类型印章
    local tc = TYPE_COLORS[card.type]
    nvgBeginPath(vg); nvgRoundedRect(vg, x + 3, y + 3, 13, 13, 1.5)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, x + 3, y + 3, 13, 13, 1.5)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 30))
    nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    nvgFontSize(vg, 12.8)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(x + 9.5, y + 9.5, TYPE_NAMES[card.type])

    -- 右上命格标记 (替代费用)
    local cc = GameConfig.CONSTELLATION_COLORS[constellation] or { 180, 175, 165 }
    local constX = x + w - 9
    local constY = y + 9
    nvgBeginPath(vg); nvgCircle(vg, constX, constY, 7.5)
    nvgFillColor(vg, nvgRGBA(38, 32, 16, 230)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 200))
    nvgStrokeWidth(vg, 1.3); nvgStroke(vg)
    -- 星标
    nvgFontSize(vg, 10.5); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 255))
    nvgText(vg, constX, constY, "C" .. constellation, nil)

    if not hideName then
        -- 底部名条
        local nameBarH = 17
        local nameBarY = y + h - nameBarH
        local nameGrad = nvgLinearGradient(vg, x, nameBarY, x, y + h,
            nvgRGBA(30, 25, 14, 225), nvgRGBA(22, 18, 10, 240))
        nvgBeginPath(vg); nvgRoundedRect(vg, x + 1, nameBarY, w - 2, nameBarH, 0)
        nvgFillPaint(vg, nameGrad); nvgFill(vg)
        nvgBeginPath(vg)
        nvgMoveTo(vg, x + 5, nameBarY + 0.5); nvgLineTo(vg, x + w - 5, nameBarY + 0.5)
        nvgStrokeColor(vg, nvgRGBA(190, 160, 90, 55))
        nvgStrokeWidth(vg, 0.5); nvgStroke(vg)

        -- 品质菱形
        local qnx = x + w / 2
        local qny = nameBarY + 0.5
        nvgBeginPath(vg)
        nvgMoveTo(vg, qnx, qny - 2); nvgLineTo(vg, qnx + 3, qny)
        nvgLineTo(vg, qnx, qny + 2); nvgLineTo(vg, qnx - 3, qny)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 180)); nvgFill(vg)

        -- 等阶标签 (N/R/SR/SSR/限定SSR, 左对齐向右延展)
        local qTag = QUALITY_TAGS[card.quality] or "N"
        local tagH2 = 12
        local tagX2 = x + 2
        local tagY2 = nameBarY - tagH2 - 1
        -- 测量文字实际宽度，自适应标签宽
        nvgFontSize(vg, 13)
        nvgFontFaceId(vg, GetMainFont())
        local measuredW = nvgTextBounds(vg, 0, 0, qTag, nil)
        local tagW2 = math.max(14, measuredW + 8)
        nvgBeginPath(vg); nvgRoundedRect(vg, tagX2, tagY2, tagW2, tagH2, 2)
        nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 190)); nvgFill(vg)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(tagX2 + tagW2 / 2, tagY2 + tagH2 / 2, qTag)

        -- 名称 (左对齐，裁剪防超框)
        nvgSave(vg)
        nvgIntersectScissor(vg, x, nameBarY, w, nameBarH)
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(x + 3, nameBarY + nameBarH / 2 + 1, card.name)
        nvgRestore(vg)
    end
end


function DrawDrawButton(sl)
    local bx, by = sl.drawBtnX, sl.drawBtnY
    local bw, bh = sl.drawBtnW, sl.drawBtnH
    local t = gameState.gameTime

    -- 按钮背景 (带脉冲光)
    local pulse = 0.7 + 0.3 * math.sin(t * 2.5)
    local btnGrad = nvgLinearGradient(vg, bx, by, bx, by + bh,
        nvgRGBA(40, 25, 55, 230), nvgRGBA(25, 15, 35, 245))
    nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
    nvgFillPaint(vg, btnGrad); nvgFill(vg)

    -- 外发光
    local glowR = 8 * pulse
    local glow = nvgBoxGradient(vg, bx - glowR / 2, by - glowR / 2,
        bw + glowR, bh + glowR, 8, glowR,
        nvgRGBA(180, 120, 255, math.floor(25 * pulse)),
        nvgRGBA(180, 120, 255, 0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx - glowR, by - glowR, bw + glowR * 2, bh + glowR * 2, 10)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 边框
    local borderAlpha = math.floor(100 + 60 * math.sin(t * 3))
    nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 5)
    nvgStrokeColor(vg, nvgRGBA(180, 130, 255, borderAlpha))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        -- 主文字
        nvgFontSize(vg, 16.5)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(210, 180, 255, math.floor(220 + 35 * pulse)))
        nvgText(vg, bx + bw / 2, by + bh / 2 - 3, "武灵召唤", nil)
        -- 副文字
        nvgFontSize(vg, 10.5)
        DrawWhiteInkText(bx + bw / 2, by + bh / 2 + 10, "看广告抽卡")
    end
end


-- ============================================================================
-- 拖拽卡牌渲染 (★ 屏幕逻辑坐标, 不在游戏区域变换中)
-- ============================================================================

function DrawDragCardScreen()
    if not dragState.active or not dragState.card then return end
    local card = dragState.card
    local sl = shopLayout

    -- 卡牌尺寸 (与商店卡牌同大)
    local w = sl.cardW + 4
    local h = sl.cardH + 4
    local lx, ly = dragState.lx, dragState.ly
    local x, y = lx - w / 2, ly - h / 2

    nvgSave(vg)
    nvgGlobalAlpha(vg, 0.88)

    -- 底板
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 4)
    nvgFillColor(vg, nvgRGBA(30, 25, 15, 230)); nvgFill(vg)

    -- 卡牌图片
    if GetHeroSheet(card) > 0 then
        local _sh2, _sc2, _sr2 = GetHeroSheetInfo(card)
        DrawCardImage(x + 2, y + 2, w - 4, h - 16, _sh2, card.row, card.col, _sc2, _sr2)
    end

    -- 品质边框
    local qc = QUALITY_COLORS[card.quality]
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 4)
    nvgStrokeColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 255))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)

    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())

        -- 费用徽标 (左上角)
        local cardCost = GameConfig.CARD_COST[card.quality] or 5
        nvgBeginPath(vg); nvgRoundedRect(vg, x + 2, y + 2, 18, 13, 3)
        nvgFillColor(vg, nvgRGBA(20, 15, 8, 200)); nvgFill(vg)
        nvgFontSize(vg, 13.5); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 220, 255, 255))
        nvgText(vg, x + 11, y + 9, tostring(cardCost), nil)

        -- 命格徽标 (右上角)
        local cons = card.constellation or 0
        if cons > 0 then
            local cc = GameConfig.CONSTELLATION_COLORS[cons] or { 180, 175, 165 }
            local cBadgeX = x + w - 8
            local cBadgeY = y + 8
            nvgBeginPath(vg); nvgCircle(vg, cBadgeX, cBadgeY, 7)
            nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 120))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 13.5); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cBadgeX, cBadgeY, "C" .. cons)
        end

        -- 等阶标签 (N/R/SR/SSR, 左下角名条上方)
        local dqTag = QUALITY_TAGS[card.quality] or "N"
        local dqc = QUALITY_COLORS[card.quality] or { 200, 195, 180 }
        local dTagW = #dqTag > 2 and 22 or (#dqTag > 1 and 16 or 12)
        local dTagH = 11
        local dTagX = x + 2
        local dTagY = y + h - 14 - dTagH - 1
        nvgBeginPath(vg); nvgRoundedRect(vg, dTagX, dTagY, dTagW, dTagH, 2)
        nvgFillColor(vg, nvgRGBA(dqc[1], dqc[2], dqc[3], 190)); nvgFill(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(dTagX + dTagW / 2, dTagY + dTagH / 2, dqTag)

        -- 名条
        nvgBeginPath(vg); nvgRect(vg, x, y + h - 14, w, 14)
        nvgFillColor(vg, nvgRGBA(28, 24, 14, 200)); nvgFill(vg)
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(x + w / 2, y + h - 6, card.name)
    end

    nvgRestore(vg)
end


-- ============================================================================
-- 长按Tips浮层 (水墨卷轴)
-- ============================================================================

function DrawLongPressTip()
    -- 旧长按弹窗已废弃, 现在使用 DrawInfoPopup (单击触发)
end


function DrawInfoPopup()
    if not infoPopupState.show or not infoPopupState.card then return end
    if fontId < 0 then return end

    local card = infoPopupState.card
    local uc = UNIT_CLASS[card.unitClass]
    local qc = QUALITY_COLORS[card.quality]

    local tipW = math.min(240, screenW - 20)
    local pad = 12
    local lx = pad
    local innerW = tipW - pad * 2

    -- ===== 预计算内容高度 =====
    nvgFontFaceId(vg, GetMainFont())
    local contentH = 0
    contentH = contentH + 16 + 26 + 2   -- 顶部间距 + 名称
    contentH = contentH + 18 + 6         -- 标签行 + 分割线间距

    -- 属性面板 (3行: 属性值 + 兵符加成 + 等级/命格/费用)
    contentH = contentH + 18             -- 基础属性行
    -- 兵符加成
    local cardIdx = card.cardIdx
    local sb = cardIdx and GetSealTotalBonus(cardIdx) or nil
    local hasSealBonus = sb and (sb.atkPct > 0 or sb.defPct > 0 or sb.hpPct > 0)
    if hasSealBonus then
        contentH = contentH + 15         -- 基础值行(小字) + 已在18中含最终值
    end
    contentH = contentH + 19 + 6         -- 等级/命格/费用 + 分割线间距

    -- 技能描述高度
    local descH = 0
    if card.skill and card.skillData then
        contentH = contentH + 18         -- 技能标题
        nvgFontSize(vg, 13)
        local descText = card.skillData.desc or ""
        local bounds = nvgTextBoxBounds(vg, 0, 0, innerW, descText, nil)
        descH = bounds and (bounds[4] - bounds[2]) or 14
        contentH = contentH + descH + 6  -- 技能描述
    end

    -- 站位建议
    contentH = contentH + 6 + 16         -- 分割线 + 建议文字

    -- 兵符加成详情区块
    local sealLines = {}
    if cardIdx and sb then
        local sd = sealData[cardIdx]
        if sd and sd.slots then
            for i = 1, SEAL_MAX_SLOTS do
                local sealSlot = sd.slots[i]
                if sealSlot then
                    local effect = SEAL_SLOT_EFFECTS[i]
                    if effect then
                        local tierData = effect[sealSlot.sealQ] or effect[1]
                        local lv = sealSlot.level or 1
                        local mainVal = (tierData.main or 0) * lv
                        local subVal = (tierData.sub or 0) * lv
                        local line = {
                            slotIdx = i,
                            theme = effect.theme,
                            mainName = effect.mainName, mainVal = mainVal, mainUnit = (effect.mainKey == "extraTroops") and "" or "%",
                            subName = effect.subName, subVal = subVal,
                            level = lv,
                        }
                        sealLines[#sealLines + 1] = line
                    end
                end
            end
        end
    end
    local hasSealDetails = #sealLines > 0
    if hasSealDetails then
        contentH = contentH + 8 + 16     -- 分割线 + "兵符加成"标题
        contentH = contentH + #sealLines * 14 -- 每行兵符效果
    end

    contentH = contentH + 20             -- 底部"点击关闭"

    local tipH = contentH + 8
    if tipH > screenH - 16 then tipH = screenH - 16 end
    local tipX = (screenW - tipW) / 2
    local tipY = (screenH - tipH) / 2

    -- 遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 100)); nvgFill(vg)

    -- 卷轴底板
    nvgBeginPath(vg); nvgRoundedRect(vg, tipX, tipY, tipW, tipH, 8)
    local panelGrad = nvgLinearGradient(vg, tipX, tipY, tipX, tipY + tipH,
        nvgRGBA(42, 35, 22, 248), nvgRGBA(28, 22, 12, 252))
    nvgFillPaint(vg, panelGrad); nvgFill(vg)

    -- 品质色边框
    nvgBeginPath(vg); nvgRoundedRect(vg, tipX, tipY, tipW, tipH, 8)
    nvgStrokeColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 160))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 顶部品质装饰线
    nvgBeginPath(vg); nvgRoundedRect(vg, tipX + 10, tipY + 6, tipW - 20, 2.5, 1)
    local decoGrad = nvgLinearGradient(vg, tipX + 10, tipY + 6, tipX + tipW - 10, tipY + 6,
        nvgRGBA(qc[1], qc[2], qc[3], 0), nvgRGBA(qc[1], qc[2], qc[3], 120))
    nvgFillPaint(vg, decoGrad); nvgFill(vg)

    local axLx = tipX + pad
    local cxTip = tipX + tipW / 2
    local ly = tipY + 16

    -- ① 名称
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawWhiteInkText(cxTip, ly, card.name)
    ly = ly + 26

    -- ② 品质 | 类型 | 兵种
    local pqTag = QUALITY_TAGS[card.quality] or "N"
    local typeName = TYPE_NAMES[card.type or 1]
    local ucName = uc and uc.name or "未知"
    local rangeTag = uc and (uc.isRanged and "远程" or "近战") or ""
    local tagLine = pqTag .. "·" .. QUALITY_NAMES[card.quality] .. "品  " .. typeName .. "  " .. ucName .. "(" .. rangeTag .. ")"
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 200))
    nvgText(vg, cxTip, ly, tagLine, nil)
    ly = ly + 18

    -- 分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, axLx, ly); nvgLineTo(vg, tipX + tipW - pad, ly)
    nvgStrokeColor(vg, nvgRGBA(160, 130, 80, 60)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    ly = ly + 6

    -- ③ 属性面板 (基础 or 基础+兵符)
    local lm = 1 + ((card.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
    local cBonus = GetConstellationBonus(card.constellation or 0)
    local rawAtk = math.floor(card.atk * cBonus.atkMult * lm)
    local rawDef = math.floor(card.def * cBonus.defMult * lm)
    local rawHp  = math.floor(card.hp  * cBonus.hpMult  * lm)

    local col3 = innerW / 3  -- 三列等分宽度
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    if hasSealBonus then
        -- 基础值行 (小字灰色)
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(180, 170, 155, 170))
        nvgText(vg, axLx, ly, "攻:" .. rawAtk, nil)
        nvgText(vg, axLx + col3, ly, "防:" .. rawDef, nil)
        nvgText(vg, axLx + col3 * 2, ly, "血:" .. rawHp, nil)
        ly = ly + 15

        -- 加成后最终值行
        local fAtk = math.floor(rawAtk * (1 + sb.atkPct / 100))
        local fDef = math.floor(rawDef * (1 + sb.defPct / 100))
        local fHp  = math.floor(rawHp  * (1 + sb.hpPct  / 100))
        nvgFontSize(vg, 15)
        nvgFillColor(vg, nvgRGBA(255, 120, 100, 240))
        local atkStr = "攻:" .. fAtk
        if sb.atkPct > 0 then atkStr = atkStr .. "↑" end
        nvgText(vg, axLx, ly, atkStr, nil)
        nvgFillColor(vg, nvgRGBA(100, 150, 255, 240))
        local defStr = "防:" .. fDef
        if sb.defPct > 0 then defStr = defStr .. "↑" end
        nvgText(vg, axLx + col3, ly, defStr, nil)
        nvgFillColor(vg, nvgRGBA(100, 230, 130, 240))
        local hpStr = "血:" .. fHp
        if sb.hpPct > 0 then hpStr = hpStr .. "↑" end
        nvgText(vg, axLx + col3 * 2, ly, hpStr, nil)
    else
        -- 无兵符，直接显示属性值
        nvgFontSize(vg, 15)
        nvgFillColor(vg, nvgRGBA(255, 120, 100, 240))
        nvgText(vg, axLx, ly, "攻:" .. rawAtk, nil)
        nvgFillColor(vg, nvgRGBA(100, 150, 255, 240))
        nvgText(vg, axLx + col3, ly, "防:" .. rawDef, nil)
        nvgFillColor(vg, nvgRGBA(100, 230, 130, 240))
        nvgText(vg, axLx + col3 * 2, ly, "血:" .. rawHp, nil)
    end
    ly = ly + 18

    -- ④ 等级 / 命格 / 费用
    local cons = card.constellation or 0
    local cc = GameConfig.CONSTELLATION_COLORS[cons] or { 180, 175, 165 }
    local cardCost = GameConfig.CARD_COST[card.quality] or 5
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawWhiteInkText(axLx, ly, "Lv" .. (card.level or 1))
    nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 230))
    nvgText(vg, axLx + 45, ly, "C" .. cons, nil)
    nvgFillColor(vg, nvgRGBA(120, 220, 255, 230))
    nvgText(vg, axLx + 90, ly, "费用:" .. cardCost, nil)
    ly = ly + 19

    -- 分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, axLx, ly); nvgLineTo(vg, tipX + tipW - pad, ly)
    nvgStrokeColor(vg, nvgRGBA(160, 130, 80, 60)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    ly = ly + 6

    -- ⑤ 技能信息
    if card.skill and card.skillData then
        nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 200, 80, 240))
        nvgText(vg, axLx, ly, "技能: " .. card.skill, nil)
        nvgFillColor(vg, nvgRGBA(180, 170, 150, 180))
        nvgText(vg, tipX + tipW - pad - 50, ly, "CD:" .. (card.skillData.cd or "?") .. "s", nil)
        ly = ly + 18
        -- 技能描述 (自动换行)
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(200, 195, 180, 200))
        local descText2 = card.skillData.desc or ""
        nvgTextBox(vg, axLx, ly, innerW, descText2, nil)
        ly = ly + descH + 6
    end

    -- ⑥ 站位建议
    nvgBeginPath(vg)
    nvgMoveTo(vg, axLx, ly); nvgLineTo(vg, tipX + tipW - pad, ly)
    nvgStrokeColor(vg, nvgRGBA(160, 130, 80, 60)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    ly = ly + 6
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local posAdvice = ""
    local posColor = { 180, 220, 255 }
    if card.unitClass == "SHIELD" or card.unitClass == "CAVALRY" or card.unitClass == "LANCER" then
        posAdvice = "前排★ 出兵概率+50%"
        posColor = { 100, 180, 255 }
    elseif card.unitClass == "ARCHER" or card.unitClass == "MAGE" then
        posAdvice = "后排★ 出兵概率+50%"
        posColor = { 255, 180, 80 }
    elseif card.unitClass == "HEALER" then
        posAdvice = "后排★ 出兵概率+60%"
        posColor = { 100, 230, 130 }
    elseif card.unitClass == "ASSASSIN" then
        posAdvice = "任意★ 出兵概率+20%"
        posColor = { 220, 140, 255 }
    elseif card.unitClass == "BEAST" then
        posAdvice = "前排★ 出兵概率+50%"
        posColor = { 255, 140, 100 }
    else
        posAdvice = "前排★ 出兵概率+50%"
        posColor = { 240, 220, 180 }
    end
    nvgFillColor(vg, nvgRGBA(posColor[1], posColor[2], posColor[3], 220))
    nvgText(vg, axLx, ly, posAdvice, nil)
    ly = ly + 16

    -- ⑦ 兵符加成详情
    if hasSealDetails then
        -- 分割线
        nvgBeginPath(vg)
        nvgMoveTo(vg, axLx, ly); nvgLineTo(vg, tipX + tipW - pad, ly)
        nvgStrokeColor(vg, nvgRGBA(160, 130, 80, 60)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        ly = ly + 5
        -- 标题
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 215, 80, 230))
        nvgText(vg, axLx, ly, "兵符加成", nil)
        ly = ly + 16
        -- 每条兵符效果
        nvgFontSize(vg, 11)
        for _, sl in ipairs(sealLines) do
            local tc2 = SEAL_SLOT_THEME_COLORS[sl.slotIdx] or { 200, 200, 200 }
            nvgFillColor(vg, nvgRGBA(tc2[1], tc2[2], tc2[3], 210))
            local txt = SEAL_SLOT_NAMES[sl.slotIdx] .. " "
            if sl.mainName then
                txt = txt .. sl.mainName .. "+" .. string.format("%.0f", sl.mainVal) .. sl.mainUnit
            end
            if sl.subName and sl.subVal > 0 then
                txt = txt .. " " .. sl.subName .. "+" .. string.format("%.0f", sl.subVal) .. "%"
            end
            txt = txt .. " L" .. sl.level
            nvgText(vg, axLx, ly, txt, nil)
            ly = ly + 14
        end
    end

    -- 关闭提示
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(150, 140, 130, 120))
    nvgText(vg, cxTip, tipY + tipH - 4, "点击任意处关闭", nil)
end


-- ============================================================================
-- 飘字 & 波次过渡 (设计坐标)
-- ============================================================================

function DrawFloatTexts()
    if fontId < 0 then return end
    nvgFontFaceId(vg, GetMainFont())
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, ft in ipairs(floatTexts) do
        local p = ft.timer / ft.duration
        local a = math.floor(255 * (1 - p))
        local py = ft.y - p * 60
        nvgFontSize(vg, ft.fontSize)
        nvgFillColor(vg, nvgRGBA(ft.color[1], ft.color[2], ft.color[3], a))
        nvgText(vg, ft.x, py, ft.text, nil)
    end
end
