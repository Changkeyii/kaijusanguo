-- ui/codex_skills.lua - 三国武灵录 (从 codex.lua 拆分)
-- 横屏布局: 左侧品质标签栏 + 右侧水平滚动武技卡牌
function DrawSkillCodexScreen()
    if gameState.phase ~= "SKILL_CODEX" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local t = menuAnimTimer

    -- 1. 统一菜单背景
    DrawCodexBg(W, H)

    nvgFontFaceId(vg, GetMainFont())

    -- 返回按钮 (左上角)
    local backW, backH = 90, 36
    local backX, backY = 8, 6
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(40, 20, 15, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 70, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    skillCodexBackBtnRect = { x = backX, y = backY, w = backW, h = backH }

    -- 标题 (顶部居中)
    nvgFontSize(vg, 32)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(W / 2, 24, "武技")

    -- ===================== 横屏两栏布局 =====================
    local topBarH = 48
    local TAB_W = 90      -- 左侧标签栏宽度
    local TAB_Y = topBarH
    local TAB_H = H - TAB_Y
    local RIGHT_X = TAB_W
    local RIGHT_Y = topBarH
    local RIGHT_W = W - TAB_W
    local RIGHT_H = H - topBarH

    local selTier = skillCodexState.selectedTier or 1

    -- 2. 左侧品质标签栏
    -- 标签栏背景
    nvgBeginPath(vg); nvgRect(vg, 0, TAB_Y, TAB_W, TAB_H)
    nvgFillColor(vg, nvgRGBA(12, 15, 25, 200)); nvgFill(vg)

    skillCodexTierBtnRects = {}
    local tabBtnH = math.floor(TAB_H / #SKILL_TIERS)
    for ti, tier in ipairs(SKILL_TIERS) do
        local tc = tier.color
        local btnY = TAB_Y + (ti - 1) * tabBtnH
        local isActive = (ti == selTier)

        -- 标签背景
        nvgBeginPath(vg); nvgRect(vg, 0, btnY, TAB_W, tabBtnH)
        if isActive then
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 40)); nvgFill(vg)
            -- 左侧高亮竖条
            nvgBeginPath(vg); nvgRect(vg, 0, btnY + 4, 3, tabBtnH - 8)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220)); nvgFill(vg)
            -- 右侧连接线 (表示当前选中)
            nvgBeginPath(vg); nvgRect(vg, TAB_W - 2, btnY + 8, 2, tabBtnH - 16)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180)); nvgFill(vg)
        end

        -- 底部分割线
        if ti < #SKILL_TIERS then
            nvgBeginPath(vg)
            nvgMoveTo(vg, 8, btnY + tabBtnH)
            nvgLineTo(vg, TAB_W - 8, btnY + tabBtnH)
            nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        end

        -- 品质名称
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
        else
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 130))
        end
        nvgText(vg, TAB_W / 2, btnY + tabBtnH / 2 - 8, tier.name, nil)
        -- 数量
        nvgFontSize(vg, 16)
        nvgFillColor(vg, nvgRGBA(180, 170, 160, isActive and 180 or 100))
        nvgText(vg, TAB_W / 2, btnY + tabBtnH / 2 + 12, tier.count .. "式", nil)

        skillCodexTierBtnRects[ti] = { x = 0, y = btnY, w = TAB_W, h = tabBtnH }

        -- 品质页签红点: 该品质下有可合成/有空槽可装备的武技
        local tierStart = 0
        for k = 1, ti - 1 do tierStart = tierStart + SKILL_TIERS[k].count end
        local needFrag = SKILL_FRAG_EXCHANGE or 20
        local hasTierDot = false
        for si = 1, tier.count do
            local sIdx = tierStart + si
            local skD = SKILL_DEFS[sIdx]
            if skD and not skD.notAvailable then
                local frags = skillFragments[sIdx] or 0
                if frags >= needFrag and (not skD.unlocked or (skillLayers[sIdx] or 1) < SKILL_MAX_LAYER) then
                    hasTierDot = true; break
                end
            end
        end
        if hasTierDot then
            DrawRedDot(TAB_W - 8, btnY + 8, 5)
        end
    end

    -- 3. 右侧武技卡牌区域 (水平滚动)
    local tier = SKILL_TIERS[selTier]
    local tc = tier.color

    -- 计算当前阶级起始索引
    local tierStartIdx = 0
    for i = 1, selTier - 1 do tierStartIdx = tierStartIdx + SKILL_TIERS[i].count end

    -- 裁剪右侧区域
    nvgSave(vg)
    nvgScissor(vg, RIGHT_X, RIGHT_Y, RIGHT_W, RIGHT_H)

    -- 右侧背景渐变
    local rGrad = nvgLinearGradient(vg, RIGHT_X, RIGHT_Y, RIGHT_X + 200, RIGHT_Y,
        nvgRGBA(tc[1], tc[2], tc[3], 15), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, RIGHT_X, RIGHT_Y, RIGHT_W, RIGHT_H)
    nvgFillPaint(vg, rGrad); nvgFill(vg)

    -- 品质标题 (右侧内顶部)
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200))
    nvgText(vg, RIGHT_X + 16, RIGHT_Y + 20, tier.name .. " · 武技", nil)

    -- 卡牌参数
    local cardW = 120
    local cardH = RIGHT_H - 70
    local cardGap = 16
    local scrollX = skillCodexState.scrollX or 0
    local cardsStartX = RIGHT_X + 12 - scrollX
    local cardsStartY = RIGHT_Y + 42

    skillCodexCardRects = {}
    local allEquipSet = GetAllEquippedSkillSet and GetAllEquippedSkillSet() or {}

    for si = 1, tier.count do
        local skillIdx = tierStartIdx + si
        local skill = SKILL_TECHNIQUES[skillIdx]
        if not skill then break end

        local sx = cardsStartX + (si - 1) * (cardW + cardGap)
        local sy = cardsStartY

        -- 跳过完全不可见的卡牌 (优化)
        if sx + cardW < RIGHT_X - 10 or sx > RIGHT_X + RIGHT_W + 10 then
            skillCodexCardRects[skillIdx] = { x = sx, y = sy, w = cardW, h = cardH }
            goto continue_card
        end

        -- 卡牌底板
        nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, cardW, cardH, 8)
        nvgFillColor(vg, nvgRGBA(20, 25, 40, 220)); nvgFill(vg)

        -- 阶级色边框
        nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, cardW, cardH, 8)
        nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 120)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

        -- 图标 (大图标)
        do
            local iconDrawSize = cardW - 20
            local iconX = sx + 10
            local iconY = sy + 10
            drawSkillIcon(skill.iconIdx, iconX, iconY, iconDrawSize, 6)
        end

        -- 武技名
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local maxNameW = cardW - 8
        local nameDisplay = skill.name
        local nameW = nvgTextBounds(vg, 0, 0, nameDisplay, nil)
        if nameW > maxNameW then
            local ellipsis = ".."
            local charCount = utf8.len(nameDisplay) or #nameDisplay
            for cj = charCount - 1, 1, -1 do
                local byteOff = utf8.offset(nameDisplay, cj + 1)
                local sub = string.sub(nameDisplay, 1, (byteOff or 1) - 1) .. ellipsis
                if nvgTextBounds(vg, 0, 0, sub, nil) <= maxNameW then
                    nameDisplay = sub
                    break
                end
            end
        end
        DrawWhiteInkText(sx + cardW / 2, sy + cardW - 4, nameDisplay)

        -- 序列帧动画 (卡牌下半部分)
        local fxAreaY = sy + cardW + 8
        local fxAreaH = cardH - cardW - 12
        local fxData = SKILL_FX_SHEETS[skill.iconIdx]

        if fxData and fxData.handle > 0 and fxAreaH > 40 then
            -- 计算当前动画帧
            local frameIdx = math.floor(t * fxData.fps) % fxData.frames
            local fcol = frameIdx % fxData.cols
            local frow = math.floor(frameIdx / fxData.cols)

            -- 获取精灵图尺寸
            local imgW, imgH = nvgImageSize(vg, fxData.handle)
            local cellW = imgW / fxData.cols
            local cellH = imgH / fxData.rows

            -- crop-aware 渲染
            local crop = fxData.crop
            local cropScale = fxData.origW and (imgW / fxData.origW) or 1
            local srcX = fcol * cellW + crop.x * cropScale
            local srcY = frow * cellH + crop.y * cropScale
            local srcW = crop.w * cropScale
            local srcH = crop.h * cropScale

            -- 等比缩放 fit 进卡牌区域
            local fitW = cardW - 8
            local fitH = fxAreaH
            local contentScale = math.min(fitW / srcW, fitH / srcH)
            local scaledW = srcW * contentScale
            local scaledH = srcH * contentScale
            local centeredX = sx + 4 + (fitW - scaledW) / 2
            local centeredY = fxAreaY + (fxAreaH - scaledH) / 2

            local patX = centeredX - srcX * contentScale
            local patY = centeredY - srcY * contentScale
            local pat = nvgImagePattern(vg, patX, patY,
                imgW * contentScale, imgH * contentScale, 0, fxData.handle, 0.9)
            nvgBeginPath(vg)
            nvgRect(vg, centeredX, centeredY, scaledW, scaledH)
            nvgFillPaint(vg, pat)
            nvgFill(vg)
        elseif fxAreaH > 40 then
            -- 无序列帧: 显示脉动 "?"
            nvgFontSize(vg, 36)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local qAlpha = math.floor(60 + 30 * math.sin(t * 1.5))
            nvgFillColor(vg, nvgRGBA(140, 120, 90, qAlpha))
            nvgText(vg, sx + cardW / 2, fxAreaY + fxAreaH / 2, "?", nil)
        end

        -- 已解锁武技: 右上角层数标签
        local skDef = SKILL_DEFS[skillIdx]
        if skDef and skDef.unlocked and skillLayers[skillIdx] then
            local layer = skillLayers[skillIdx]
            local lbW, lbH = 28, 16
            local lbX = sx + cardW - lbW - 3
            local lbY = sy + 3
            nvgBeginPath(vg); nvgRoundedRect(vg, lbX, lbY, lbW, lbH, 3)
            if layer >= SKILL_MAX_LAYER then
                nvgFillColor(vg, nvgRGBA(200, 160, 40, 220))
            else
                nvgFillColor(vg, nvgRGBA(60, 140, 200, 200))
            end
            nvgFill(vg)
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
            nvgText(vg, lbX + lbW / 2, lbY + lbH / 2, layer >= SKILL_MAX_LAYER and "满" or (layer .. "层"), nil)
        end

        -- 已装备武将名标签 (左下角)
        if skDef and skDef.unlocked and allEquipSet[skillIdx] then
            local eqHeroIdx = allEquipSet[skillIdx]
            local eqHeroName = "?"
            if HERO_CARDS and HERO_CARDS[eqHeroIdx] then
                local fullN = HERO_CARDS[eqHeroIdx].name or ""
                -- 取前两个UTF-8字符
                local cnt2, pos2 = 0, 1
                while cnt2 < 2 and pos2 <= #fullN do
                    local b2 = fullN:byte(pos2)
                    if b2 < 0x80 then pos2 = pos2 + 1
                    elseif b2 < 0xE0 then pos2 = pos2 + 2
                    elseif b2 < 0xF0 then pos2 = pos2 + 3
                    else pos2 = pos2 + 4 end
                    cnt2 = cnt2 + 1
                end
                eqHeroName = fullN:sub(1, pos2 - 1)
            end
            local eTagW, eTagH = 30, 14
            local eTagX, eTagY = sx + 3, sy + cardH - eTagH - 3
            nvgBeginPath(vg); nvgRoundedRect(vg, eTagX, eTagY, eTagW, eTagH, 3)
            nvgFillColor(vg, nvgRGBA(55, 140, 180, 210)); nvgFill(vg)
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 235))
            nvgText(vg, eTagX + eTagW / 2, eTagY + eTagH / 2, eqHeroName, nil)
        end

        -- 暂未开放 / 未解锁遮罩
        if skDef and skDef.notAvailable then
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, cardW, cardH, 8)
            nvgFillColor(vg, nvgRGBA(5, 5, 12, 120)); nvgFill(vg)
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(sx + cardW / 2, sy + cardH / 2, "暂未开放")
        elseif skDef and not skDef.unlocked then
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, cardW, cardH, 8)
            nvgFillColor(vg, nvgRGBA(5, 5, 12, 95)); nvgFill(vg)
            -- NanoVG 古风封印图标
            local sealSize = 36
            local sealCX = sx + cardW / 2
            local sealCY = sy + cardH / 2 - 4
            local sealR = sealSize / 2
            -- 外圈 (双环)
            nvgBeginPath(vg); nvgCircle(vg, sealCX, sealCY, sealR)
            nvgStrokeColor(vg, nvgRGBA(180, 120, 80, 180))
            nvgStrokeWidth(vg, 2.0); nvgStroke(vg)
            nvgBeginPath(vg); nvgCircle(vg, sealCX, sealCY, sealR - 3.5)
            nvgStrokeColor(vg, nvgRGBA(180, 120, 80, 140))
            nvgStrokeWidth(vg, 1.0); nvgStroke(vg)
            -- 内部半透明填充
            nvgBeginPath(vg); nvgCircle(vg, sealCX, sealCY, sealR - 4)
            nvgFillColor(vg, nvgRGBA(60, 30, 20, 80)); nvgFill(vg)
            -- 中心"封"字
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 140, 90, 210))
            nvgText(vg, sealCX, sealCY, "封", nil)
            -- 四角装饰点
            local dotR = 2
            local dotOff = sealR - 6
            for _, ang in ipairs({ 0.785, 2.356, 3.927, 5.498 }) do
                local dx = sealCX + math.cos(ang) * dotOff
                local dy = sealCY + math.sin(ang) * dotOff
                nvgBeginPath(vg); nvgCircle(vg, dx, dy, dotR)
                nvgFillColor(vg, nvgRGBA(180, 120, 80, 150)); nvgFill(vg)
            end
        end

        -- 存储点击区域
        skillCodexCardRects[skillIdx] = { x = sx, y = sy, w = cardW, h = cardH }

        ::continue_card::
    end

    -- 记录内容总宽度 (用于横向滚动限制)
    skillCodexState.contentW = tier.count * (cardW + cardGap) - cardGap + 24

    nvgRestore(vg)  -- 恢复裁剪

    -- 左右竖分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, TAB_W, TAB_Y); nvgLineTo(vg, TAB_W, H)
    nvgStrokeColor(vg, nvgRGBA(80, 60, 40, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
end


-- ============================================================================
-- 武技弹窗面板 - 覆盖在 SKILL_CODEX 上层 (替代已删除的详情页)
-- ============================================================================
function DrawSkillPopup()
    if not skillPopup.show then return end
    local skillIdx = skillPopup.skillIdx
    if not skillIdx then skillPopup.show = false; return end
    local skill = SKILL_TECHNIQUES[skillIdx]
    if not skill then skillPopup.show = false; return end

    local W = DESIGN_W
    local H = DESIGN_H
    local t = menuAnimTimer
    local tier = SKILL_TIERS[skill.tier]
    local tc = tier.color
    local skDef = SKILL_DEFS[skillIdx]

    nvgFontFaceId(vg, GetMainFont())

    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150)); nvgFill(vg)

    -- 弹窗面板
    local panelW = 460
    local panelH = 450
    local panelX = (W - panelW) / 2
    local panelY = (H - panelH) / 2
    skillPopup.panelRect = { x = panelX, y = panelY, w = panelW, h = panelH }

    -- 面板背景
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 12)
    nvgFillColor(vg, nvgRGBA(18, 22, 38, 245)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 顶部渐变
    nvgSave(vg)
    nvgScissor(vg, panelX, panelY, panelW, panelH)
    local topGrad = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + 80,
        nvgRGBA(tc[1], tc[2], tc[3], 30), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, panelX, panelY, panelW, 80)
    nvgFillPaint(vg, topGrad); nvgFill(vg)

    local cx = panelX + panelW / 2

    -- 关闭按钮 (右上角)
    local closeSize = 30
    local closeX = panelX + panelW - closeSize - 8
    local closeY = panelY + 8
    nvgBeginPath(vg); nvgRoundedRect(vg, closeX, closeY, closeSize, closeSize, 4)
    nvgFillColor(vg, nvgRGBA(60, 30, 30, 200)); nvgFill(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 150, 150, 220))
    nvgText(vg, closeX + closeSize / 2, closeY + closeSize / 2, "X", nil)
    skillPopup.closeBtnRect = { x = closeX, y = closeY, w = closeSize, h = closeSize }

    -- ===== 第1行: 图标 + 名称 + 品质标签 + 层数 =====
    local contentY = panelY + 14
    local iconSize = 60
    local iconX = panelX + 16
    local iconY = contentY + 2

    -- 图标外发光
    local gc = tier.glowColor
    local glow = nvgBoxGradient(vg, iconX - 4, iconY - 4, iconSize + 8, iconSize + 8, 10, 12,
        nvgRGBA(gc[1], gc[2], gc[3], math.floor(25 + 10 * math.sin(t * 2.0))),
        nvgRGBA(gc[1], gc[2], gc[3], 0))
    nvgBeginPath(vg); nvgRoundedRect(vg, iconX - 8, iconY - 8, iconSize + 16, iconSize + 16, 12)
    nvgFillPaint(vg, glow); nvgFill(vg)

    drawSkillIcon(skill.iconIdx, iconX, iconY, iconSize, 6)
    nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 6)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 140)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    -- 名称
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
    nvgText(vg, iconX + iconSize + 14, iconY + 18, skill.name, nil)

    -- 品质标签
    local tagW = 60
    local tagH = 22
    local tagX = iconX + iconSize + 14
    local tagY = iconY + 38
    nvgBeginPath(vg); nvgRoundedRect(vg, tagX, tagY, tagW, tagH, 11)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 35)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 100)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200))
    nvgText(vg, tagX + tagW / 2, tagY + tagH / 2, tier.name, nil)

    -- 层数标签
    if skDef and skDef.unlocked and skillLayers[skillIdx] then
        local layer = skillLayers[skillIdx]
        local lbW = 60
        local lbH = 22
        local lbX = tagX + tagW + 8
        local lbY = tagY
        nvgBeginPath(vg); nvgRoundedRect(vg, lbX, lbY, lbW, lbH, 11)
        if layer >= SKILL_MAX_LAYER then
            nvgFillColor(vg, nvgRGBA(200, 160, 40, 50)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 160, 40, 150))
        else
            nvgFillColor(vg, nvgRGBA(60, 140, 200, 40)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(60, 140, 200, 120))
        end
        nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
        local layerStr = layer >= SKILL_MAX_LAYER and "满层" or (layer .. "/" .. SKILL_MAX_LAYER .. "层")
        nvgText(vg, lbX + lbW / 2, lbY + lbH / 2, layerStr, nil)
    end

    -- 编号 (右侧)
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 130, 110, 120))
    nvgText(vg, panelX + panelW - 16, iconY + iconSize / 2, "No." .. string.format("%03d", skillIdx), nil)

    -- ===== 第2行: 序列帧动画预览 =====
    local fxY = contentY + iconSize + 16
    local fxH = 160
    local fxW = panelW - 32
    local fxX = panelX + 16

    nvgBeginPath(vg); nvgRoundedRect(vg, fxX, fxY, fxW, fxH, 8)
    nvgFillColor(vg, nvgRGBA(8, 10, 20, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 40)); nvgStrokeWidth(vg, 0.6); nvgStroke(vg)

    local fxData = SKILL_FX_SHEETS[skill.iconIdx]
    if fxData and fxData.handle > 0 then
        local frameIdx = math.floor(t * fxData.fps) % fxData.frames
        local fcol = frameIdx % fxData.cols
        local frow = math.floor(frameIdx / fxData.cols)
        local imgW, imgH = nvgImageSize(vg, fxData.handle)
        local cellW = imgW / fxData.cols
        local cellH = imgH / fxData.rows
        local crop = fxData.crop
        local cropScale = fxData.origW and (imgW / fxData.origW) or 1
        local srcX = fcol * cellW + crop.x * cropScale
        local srcY = frow * cellH + crop.y * cropScale
        local srcW = crop.w * cropScale
        local srcH = crop.h * cropScale
        local contentScale = math.min(fxW / srcW, fxH / srcH)
        local scaledW = srcW * contentScale
        local scaledH = srcH * contentScale
        local centeredX = fxX + (fxW - scaledW) / 2
        local centeredY = fxY + (fxH - scaledH) / 2
        local patX = centeredX - srcX * contentScale
        local patY = centeredY - srcY * contentScale
        local pat = nvgImagePattern(vg, patX, patY,
            imgW * contentScale, imgH * contentScale, 0, fxData.handle, 1.0)
        nvgBeginPath(vg)
        nvgRect(vg, centeredX, centeredY, scaledW, scaledH)
        nvgFillPaint(vg, pat)
        nvgFill(vg)
    else
        nvgFontSize(vg, 40)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local qAlpha = math.floor(60 + 30 * math.sin(t * 1.5))
        nvgFillColor(vg, nvgRGBA(140, 120, 90, qAlpha))
        nvgText(vg, fxX + fxW / 2, fxY + fxH / 2, "?", nil)
    end

    -- ===== 第3行: 武技描述 =====
    local descY = fxY + fxH + 10
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 160))
    nvgText(vg, panelX + 16, descY, "武技描述", nil)
    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 16, descY + 20)
    nvgLineTo(vg, panelX + panelW - 16, descY + 20)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 35)); nvgStrokeWidth(vg, 0.6); nvgStroke(vg)
    nvgFontSize(vg, 17)
    nvgFillColor(vg, nvgRGBA(200, 195, 175, 210))
    nvgTextLineHeight(vg, 1.4)
    nvgTextBox(vg, panelX + 16, descY + 26, panelW - 32, skill.desc, nil)

    -- ===== 第4行: 残片 + 合成按钮 =====
    local actionY = descY + 74
    skillPopup.composeBtnRect = nil

    if skDef and not skDef.notAvailable then
        local frags = skillFragments[skillIdx] or 0
        if not skDef.unlocked or (skillLayers[skillIdx] or 1) < SKILL_MAX_LAYER then
            -- 残片进度
            local fragText = "残片: " .. frags .. "/" .. SKILL_FRAG_EXCHANGE
            nvgFontSize(vg, 17)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 170, 140, 200))
            nvgText(vg, panelX + 16, actionY + 14, fragText, nil)

            -- 进度条
            local barX = panelX + 120
            local barW = 150
            local barH = 8
            local barY = actionY + 10
            local ratio = math.min(frags / SKILL_FRAG_EXCHANGE, 1.0)
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 4)
            nvgFillColor(vg, nvgRGBA(30, 30, 40, 200)); nvgFill(vg)
            if ratio > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW * ratio, barH, 4)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180)); nvgFill(vg)
            end

            -- 合成按钮
            local compBtnW = 100
            local compBtnH = 28
            local compBtnX = panelX + panelW - compBtnW - 16
            local compBtnY = actionY
            local canCompose = frags >= SKILL_FRAG_EXCHANGE
            nvgBeginPath(vg); nvgRoundedRect(vg, compBtnX, compBtnY, compBtnW, compBtnH, 6)
            if canCompose then
                nvgFillColor(vg, nvgRGBA(tc[1] * 0.3, tc[2] * 0.3, tc[3] * 0.3, 220)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 160))
            else
                nvgFillColor(vg, nvgRGBA(30, 30, 30, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 80, 80, 100))
            end
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 17)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if canCompose then
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 230))
            else
                nvgFillColor(vg, nvgRGBA(120, 120, 120, 160))
            end
            local compLabel = skDef.unlocked and "升层" or "合成解锁"
            nvgText(vg, compBtnX + compBtnW / 2, compBtnY + compBtnH / 2, compLabel, nil)
            skillPopup.composeBtnRect = { x = compBtnX, y = compBtnY, w = compBtnW, h = compBtnH }
            actionY = actionY + compBtnH + 8
        else
            actionY = actionY + 4
        end
    end

    -- ===== 第5行: 装备/卸下按钮 =====
    skillPopup.equipBtnRect = nil
    skillPopup.equipSlotBtns = {}

    if skDef and skDef.notAvailable then
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 110, 100, 160))
        nvgText(vg, cx, actionY + 16, "此武技暂未开放", nil)
    elseif skDef and not skDef.unlocked then
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 110, 100, 160))
        nvgText(vg, cx, actionY + 16, "解锁后可装备", nil)
    elseif skDef and skDef.unlocked then
        local curHero = equipScreenState.selectedHero
        local heroSkills = curHero and GetHeroSkills(curHero) or {}
        local heroName = curHero and HERO_CARDS[curHero] and HERO_CARDS[curHero].name or "未选择"
        local equippedSlot = nil
        for slot, techIdx in ipairs(heroSkills) do
            if techIdx == skillIdx then equippedSlot = slot; break end
        end
        local equippedByOther = nil
        local allSet = GetAllEquippedSkillSet()
        if allSet[skillIdx] and allSet[skillIdx] ~= curHero then
            equippedByOther = allSet[skillIdx]
        end
        local isEquipped = (equippedSlot ~= nil)
        local slotsFull = (#heroSkills >= 2)

        -- 当前武将
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 150, 120, 180))
        nvgText(vg, cx, actionY + 8, "当前武将: " .. heroName, nil)

        local btnW = 200
        local btnH = 32
        local btnX = cx - btnW / 2
        local btnY = actionY + 22

        if not curHero then
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 6)
            nvgFillColor(vg, nvgRGBA(40, 35, 30, 200)); nvgFill(vg)
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, btnY + btnH / 2, "请先选择武将")
        elseif equippedByOther then
            local otherName = HERO_CARDS[equippedByOther] and HERO_CARDS[equippedByOther].name or ("武将#" .. equippedByOther)
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 6)
            nvgFillColor(vg, nvgRGBA(40, 35, 30, 200)); nvgFill(vg)
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 160, 120, 180))
            nvgText(vg, cx, btnY + btnH / 2, "已被 " .. otherName .. " 装备", nil)
        elseif isEquipped then
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 6)
            nvgFillColor(vg, nvgRGBA(60, 20, 20, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 60, 60, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(230, 120, 100, 230))
            nvgText(vg, cx, btnY + btnH / 2, "卸下 (槽位" .. equippedSlot .. ")", nil)
            skillPopup.equipBtnRect = { x = btnX, y = btnY, w = btnW, h = btnH, action = "unequip", slot = equippedSlot, heroIdx = curHero }
        elseif slotsFull then
            for s = 1, 2 do
                local sBtnY = btnY + (s - 1) * (btnH + 6)
                local oldName = SKILL_TECHNIQUES[heroSkills[s]] and SKILL_TECHNIQUES[heroSkills[s]].name or "?"
                nvgBeginPath(vg); nvgRoundedRect(vg, btnX, sBtnY, btnW, btnH, 6)
                nvgFillColor(vg, nvgRGBA(tc[1] * 0.25, tc[2] * 0.25, tc[3] * 0.25, 220)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 130)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220))
                nvgText(vg, cx, sBtnY + btnH / 2, "替换槽位" .. s .. ": " .. oldName, nil)
                skillPopup.equipSlotBtns[s] = { x = btnX, y = sBtnY, w = btnW, h = btnH, slot = s, heroIdx = curHero }
            end
        else
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 6)
            nvgFillColor(vg, nvgRGBA(tc[1] * 0.3, tc[2] * 0.3, tc[3] * 0.3, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 230))
            nvgText(vg, cx, btnY + btnH / 2, "装备", nil)
            skillPopup.equipBtnRect = { x = btnX, y = btnY, w = btnW, h = btnH, action = "equip", heroIdx = curHero }
        end

        -- 已装备槽位提示
        if #heroSkills > 0 and not slotsFull then
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(218, 195, 125, 200))
            local slotNames = {}
            for s, ti in ipairs(heroSkills) do
                slotNames[s] = s .. ":" .. (SKILL_TECHNIQUES[ti] and SKILL_TECHNIQUES[ti].name or "?")
            end
            nvgText(vg, cx, btnY + btnH + 4, heroName .. " [" .. table.concat(slotNames, " | ") .. "]", nil)
        end
    end

    nvgRestore(vg)  -- 恢复裁剪
end


-- EquipUI 实现代码已移至 EquipUI.lua 模块

-- ============================================================================
-- 兵甲界面 - 设计坐标 (NanoVG旧版, EquipUI启用时跳过)
-- ============================================================================
