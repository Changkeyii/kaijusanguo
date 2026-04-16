-- ui/codex_skills.lua - 三国武灵录 (从 codex.lua 拆分)
function DrawSkillCodexScreen()
    if gameState.phase ~= "SKILL_CODEX" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer

    -- 1. 统一菜单背景
    DrawCodexBg(W, H)

    nvgFontFaceId(vg, GetMainFont())

    -- 返回按钮
    local backW, backH = 120, 50
    local backX, backY = 10, 8
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(40, 20, 15, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 70, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    skillCodexBackBtnRect = { x = backX, y = backY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 39)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 33, "武技")

    -- 2. 可滚动内容区域
    local contentY = 68
    local contentH = H - contentY
    local scrollY = skillCodexState.scrollY

    -- 裁剪区域
    nvgSave(vg)
    nvgScissor(vg, 0, contentY, W, contentH)

    skillCodexCardRects = {}
    local cardW = 88
    local cardH = 110
    local cardGap = 20
    local cols = 4
    local gridW = cols * cardW + (cols - 1) * cardGap
    local gridStartX = (W - gridW) / 2
    local curY = contentY + 10 - scrollY
    local tierStartIdx = 1

    for ti, tier in ipairs(SKILL_TIERS) do
        local tc = tier.color

        -- 阶级标题栏
        local titleBarH = 30
        -- 渐变背景条
        local tGrad = nvgLinearGradient(vg, gridStartX, curY, gridStartX + gridW, curY,
            nvgRGBA(tc[1], tc[2], tc[3], 50), nvgRGBA(tc[1], tc[2], tc[3], 10))
        nvgBeginPath(vg); nvgRoundedRect(vg, gridStartX, curY, gridW, titleBarH, 4)
        nvgFillPaint(vg, tGrad); nvgFill(vg)
        -- 左侧竖条
        nvgBeginPath(vg); nvgRect(vg, gridStartX, curY + 4, 3, titleBarH - 8)
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200)); nvgFill(vg)
        -- 阶级名
        nvgFontSize(vg, 27)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(gridStartX + 12, curY + titleBarH / 2, tier.name)
        -- 数量
        nvgFontSize(vg, 27)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(gridStartX + gridW - 8, curY + titleBarH / 2, tier.count .. "式")

        curY = curY + titleBarH + 20

        -- 武技卡牌网格
        for si = 1, tier.count do
            local skillIdx = tierStartIdx + si - 1
            local skill = SKILL_TECHNIQUES[skillIdx]
            if not skill then break end

            local col = (si - 1) % cols
            local row = math.floor((si - 1) / cols)
            local sx = gridStartX + col * (cardW + cardGap)
            local sy = curY + row * (cardH + cardGap)

            -- 卡牌底板
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, cardW, cardH, 6)
            nvgFillColor(vg, nvgRGBA(20, 25, 40, 220)); nvgFill(vg)

            -- 阶级色边框
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, cardW, cardH, 6)
            nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 120)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

            -- 图标 (按实际像素裁切居中)
            do
                local iconDrawSize = cardW - 16
                local iconX = sx + 8
                local iconY = sy + 6
                drawSkillIcon(skill.iconIdx, iconX, iconY, iconDrawSize, 4)
            end

            -- 武技名 (超长截断加省略号)
            nvgFontSize(vg, 27)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local maxNameW = cardW - 6
            local nameDisplay = skill.name
            local nameW = nvgTextBounds(vg, 0, 0, nameDisplay, nil)
            if nameW > maxNameW then
                -- 逐字截断直到适配 (UTF-8安全)
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
            DrawWhiteInkText(sx + cardW / 2, sy + cardH - 12, nameDisplay)

            -- 已解锁武技: 右上角显示层数标签
            local skDef = SKILL_DEFS[skillIdx]
            if skDef and skDef.unlocked and skillLayers[skillIdx] then
                local layer = skillLayers[skillIdx]
                local lbW, lbH = 28, 16
                local lbX = sx + cardW - lbW - 2
                local lbY = sy + 2
                nvgBeginPath(vg); nvgRoundedRect(vg, lbX, lbY, lbW, lbH, 3)
                if layer >= SKILL_MAX_LAYER then
                    nvgFillColor(vg, nvgRGBA(200, 160, 40, 220))
                else
                    nvgFillColor(vg, nvgRGBA(60, 140, 200, 200))
                end
                nvgFill(vg)
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
                nvgText(vg, lbX + lbW / 2, lbY + lbH / 2, layer >= SKILL_MAX_LAYER and "满" or (layer .. "层"), nil)
            end

            -- 暂未开放 / 未解锁遮罩
            if skDef and skDef.notAvailable then
                nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, cardW, cardH, 6)
                nvgFillColor(vg, nvgRGBA(5, 5, 12, 120)); nvgFill(vg)
                nvgFontSize(vg, 27)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(sx + cardW / 2, sy + cardH / 2, "暂未开放")
            elseif skDef and not skDef.unlocked then
                nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, cardW, cardH, 6)
                nvgFillColor(vg, nvgRGBA(5, 5, 12, 95)); nvgFill(vg)
                -- 锁图标（使用生成的暗黑风格锁图标）
                if IsImageReady(IMG.lockIcon) then
                    local lockSize = 36
                    local lockX = sx + (cardW - lockSize) / 2
                    local lockY = sy + (cardH - lockSize) / 2 - 4
                    local lockPat = nvgImagePattern(vg, lockX, lockY, lockSize, lockSize, 0, IMG.lockIcon, 0.85)
                    nvgBeginPath(vg); nvgRoundedRect(vg, lockX, lockY, lockSize, lockSize, 4)
                    nvgFillPaint(vg, lockPat); nvgFill(vg)
                else
                    nvgFontSize(vg, 30)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(200, 180, 140, 200))
                    nvgText(vg, sx + cardW / 2, sy + cardH / 2, "锁", nil)
                end
            end

            -- 存储点击区域
            skillCodexCardRects[skillIdx] = { x = sx, y = sy, w = cardW, h = cardH }
        end

        local rowCount = math.ceil(tier.count / cols)
        curY = curY + rowCount * (cardH + cardGap) + 10
        tierStartIdx = tierStartIdx + tier.count
    end

    -- 记录内容总高度 (用于滚动限制)
    skillCodexState.contentH = curY + scrollY - contentY + 20

    nvgRestore(vg)  -- 恢复裁剪

    -- 漂浮粒子装饰
    for i = 1, 4 do
        local px = W * (0.1 + 0.8 * ((i * 173 + math.floor(t * 11)) % 100) / 100)
        local py = 50 + 40 * math.sin(t * 0.5 + i * 2.1)
        local pr = 1.2 + math.sin(t * 1.8 + i) * 0.4
        local pa = math.floor(20 + 14 * math.sin(t * 1.0 + i * 1.3))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(200, 180, 240, pa)); nvgFill(vg)
    end
end


-- ============================================================================
-- 武技详情界面 - 设计坐标
-- ============================================================================
function DrawSkillDetailScreen()
    if gameState.phase ~= "SKILL_DETAIL" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer
    local skillIdx = skillCodexState.selectedIdx
    local skill = SKILL_TECHNIQUES[skillIdx]
    if not skill then return end
    local tier = SKILL_TIERS[skill.tier]
    local tc = tier.color

    -- 1. 统一菜单背景
    DrawCodexBg(W, H)

    -- 顶部阶级色渐变
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, 200,
        nvgRGBA(tc[1], tc[2], tc[3], 40), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, 200)
    nvgFillPaint(vg, topGrad); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 返回按钮
    local backW, backH = 120, 50
    local backX, backY = 10, 8
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(40, 20, 15, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 70, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    skillDetailBackBtnRect = { x = backX, y = backY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 35)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 33, "武技详情")

    -- 2. 大图标
    local iconSize = 140
    local iconX = cx - iconSize / 2
    local iconY = 80
    -- 图标外发光
    local gc = tier.glowColor
    local glow = nvgBoxGradient(vg, iconX - 15, iconY - 15, iconSize + 30, iconSize + 30, 20, 25,
        nvgRGBA(gc[1], gc[2], gc[3], math.floor(30 + 15 * math.sin(t * 2.0))),
        nvgRGBA(gc[1], gc[2], gc[3], 0))
    nvgBeginPath(vg); nvgRoundedRect(vg, iconX - 20, iconY - 20, iconSize + 40, iconSize + 40, 24)
    nvgFillPaint(vg, glow); nvgFill(vg)

    -- 图标底板
    nvgBeginPath(vg); nvgRoundedRect(vg, iconX - 3, iconY - 3, iconSize + 6, iconSize + 6, 10)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 80)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 8)
    nvgFillColor(vg, nvgRGBA(20, 25, 40, 240)); nvgFill(vg)

    -- 绘制图标 (按实际像素裁切居中)
    drawSkillIcon(skill.iconIdx, iconX, iconY, iconSize, 8)

    -- 图标边框
    nvgBeginPath(vg); nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 8)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 160)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 3. 武技名称
    local nameY = iconY + iconSize + 26
    nvgFontSize(vg, 43)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 阴影
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95))
    nvgText(vg, cx + 1, nameY + 1, skill.name, nil)
    -- 阶级色文字
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 250))
    nvgText(vg, cx, nameY, skill.name, nil)

    -- 4. 阶级标签
    local tagY = nameY + 30
    local tagW = 80
    local tagH = 28
    nvgBeginPath(vg); nvgRoundedRect(vg, cx - tagW / 2, tagY, tagW, tagH, 14)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 40)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 27)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220))
    nvgText(vg, cx, tagY + tagH / 2, tier.name, nil)

    -- 5. 编号 + 层数
    nvgFontSize(vg, 27)
    local skDefDetail = SKILL_DEFS[skillIdx]
    if skDefDetail and skDefDetail.unlocked and skillLayers[skillIdx] then
        local layer = skillLayers[skillIdx]
        local layerStr = layer >= SKILL_MAX_LAYER and "满层" or (layer .. "/" .. SKILL_MAX_LAYER .. "层")
        DrawWhiteInkText(cx, tagY + tagH + 20, "No." .. string.format("%03d", skillIdx) .. "  |  " .. layerStr)
    else
        DrawWhiteInkText(cx, tagY + tagH + 20, "No." .. string.format("%03d", skillIdx))
    end

    -- 6. 描述面板
    local descPanelY = tagY + tagH + 44
    local descPanelW = W - 40
    local descPanelH = 120
    local descPanelX = 20

    nvgBeginPath(vg); nvgRoundedRect(vg, descPanelX, descPanelY, descPanelW, descPanelH, 8)
    nvgFillColor(vg, nvgRGBA(15, 18, 30, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 描述标题
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180))
    nvgText(vg, descPanelX + 14, descPanelY + 12, "武技描述", nil)

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, descPanelX + 14, descPanelY + 32)
    nvgLineTo(vg, descPanelX + descPanelW - 14, descPanelY + 32)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 40)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

    -- 描述文字 (自动换行)
    nvgFontSize(vg, 27)
    nvgFillColor(vg, nvgRGBA(200, 195, 175, 220))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgTextLineHeight(vg, 1.5)
    nvgTextBox(vg, descPanelX + 14, descPanelY + 40, descPanelW - 28, skill.desc, nil)

    -- 7. 同阶武技横排预览
    local previewY = descPanelY + descPanelH + 24
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, previewY, "- " .. tier.name .. " - 全部武技 -")

    local miniSize = 50
    local miniGap = 20
    local tierStart = 0
    for i = 1, skill.tier - 1 do tierStart = tierStart + SKILL_TIERS[i].count end
    local miniStartY = previewY + 18
    local miniCount = tier.count
    local miniRowW = miniCount * miniSize + (miniCount - 1) * miniGap
    local miniStartX = cx - miniRowW / 2

    skillDetailMiniRects = {}
    for mi = 1, miniCount do
        local idx = tierStart + mi
        local sk = SKILL_TECHNIQUES[idx]
        if not sk then break end
        local mx = miniStartX + (mi - 1) * (miniSize + miniGap)
        local my = miniStartY
        local isCurrent = (idx == skillIdx)

        -- 存储点击区域
        skillDetailMiniRects[mi] = { x = mx, y = my, w = miniSize, h = miniSize, idx = idx }

        -- 小图标底板
        nvgBeginPath(vg); nvgRoundedRect(vg, mx, my, miniSize, miniSize, 5)
        if isCurrent then
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 50))
        else
            nvgFillColor(vg, nvgRGBA(20, 25, 40, 200))
        end
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, mx, my, miniSize, miniSize, 5)
        nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], isCurrent and 200 or 60))
        nvgStrokeWidth(vg, isCurrent and 2 or 0.8); nvgStroke(vg)

        -- 小图标 (按实际像素裁切居中)
        drawSkillIcon(sk.iconIdx, mx + 3, my + 3, miniSize - 6, 3)
    end

    -- ==========================================
    -- 8. 序列帧动画预览
    -- ==========================================
    local fxSectionY = miniStartY + miniSize + 30
    local fxData = SKILL_FX_SHEETS[skill.iconIdx]

    -- 标题
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, fxSectionY, "- 武技特效 -")

    local fxPreviewY = fxSectionY + 30

    if fxData and fxData.handle > 0 then
        -- 有序列帧: 播放动画
        local fxSize = 180  -- 预览区域尺寸
        local fxX = cx - fxSize / 2
        local fxY = fxPreviewY

        -- 半透明背景圆角框
        nvgBeginPath(vg); nvgRoundedRect(vg, fxX - 10, fxY - 10, fxSize + 20, fxSize + 20, 10)
        nvgFillColor(vg, nvgRGBA(8, 10, 20, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 50)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

        -- 计算当前帧
        local frameIdx = math.floor(t * fxData.fps) % fxData.frames
        local fcol = frameIdx % fxData.cols
        local frow = math.floor(frameIdx / fxData.cols)

        -- 按实际像素裁切渲染 (与 drawSkillIcon 同理)
        local crop = fxData.crop
        local imgW, imgH = nvgImageSize(vg, fxData.handle)
        local cellW = imgW / fxData.cols
        local cellH = imgH / fxData.rows

        -- crop 值基于原始图片尺寸, 需按实际尺寸缩放
        local cropScale = fxData.origW and (imgW / fxData.origW) or 1
        -- 内容在整张精灵图中的绝对像素位置
        local srcX = fcol * cellW + crop.x * cropScale
        local srcY = frow * cellH + crop.y * cropScale
        local srcW = crop.w * cropScale
        local srcH = crop.h * cropScale

        -- 等比缩放让内容 fit 进 fxSize，并居中
        local contentScale = math.min(fxSize / srcW, fxSize / srcH)
        local scaledW = srcW * contentScale
        local scaledH = srcH * contentScale
        local centeredX = fxX + (fxSize - scaledW) / 2
        local centeredY = fxY + (fxSize - scaledH) / 2

        -- nvgImagePattern 需要整张精灵图的缩放和偏移
        local patX = centeredX - srcX * contentScale
        local patY = centeredY - srcY * contentScale

        local pat = nvgImagePattern(vg, patX, patY, imgW * contentScale, imgH * contentScale, 0, fxData.handle, 1.0)
        nvgBeginPath(vg)
        nvgRect(vg, centeredX, centeredY, scaledW, scaledH)
        nvgFillPaint(vg, pat)
        nvgFill(vg)


    else
        -- 无序列帧: 显示 "?"
        local fxSize = 140
        local fxX = cx - fxSize / 2
        local fxY = fxPreviewY

        -- 虚线框
        nvgBeginPath(vg); nvgRoundedRect(vg, fxX, fxY, fxSize, fxSize, 10)
        nvgFillColor(vg, nvgRGBA(8, 10, 20, 120)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 90, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 问号
        nvgFontSize(vg, 57)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local qAlpha = math.floor(80 + 40 * math.sin(t * 1.5))
        nvgFillColor(vg, nvgRGBA(160, 140, 100, qAlpha))
        nvgText(vg, cx, fxY + fxSize / 2, "?", nil)

        -- 提示文字
        nvgFontSize(vg, 27)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawWhiteInkText(cx, fxY + fxSize + 8, "特效待解锁")
    end

    -- 9. 装备/卸下按钮
    local equipBtnW = 220
    local equipBtnH = 40
    local equipBtnGap = 20

    -- 暂未开放 / 未解锁 / 正常装备按钮
    local skDef = SKILL_DEFS[skillIdx]
    if skDef and skDef.notAvailable then
        skillDetailEquipBtnRect = nil
        skillDetailEquipSlotBtns = {}
        skillDetailUpgradeBtnRect = nil
        local tipBtnX = cx - equipBtnW / 2
        local tipBtnY = H - 70
        nvgBeginPath(vg); nvgRoundedRect(vg, tipBtnX, tipBtnY, equipBtnW, equipBtnH, 8)
        nvgFillColor(vg, nvgRGBA(40, 40, 40, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 100, 100, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 27)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, tipBtnY + equipBtnH / 2, "暂未开放")
        -- 底部说明
        nvgFontSize(vg, 27)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        DrawWhiteInkText(cx, tipBtnY + equipBtnH + 10, "此武技特效正在制作中，敬请期待")
    elseif skDef and not skDef.unlocked then
        -- 未解锁武技: 仅显示未解锁提示，无操作按钮
        skillDetailEquipBtnRect = nil
        skillDetailEquipSlotBtns = {}
        skillDetailUpgradeBtnRect = nil
        local tipBtnX = cx - equipBtnW / 2
        local tipBtnY = H - 70
        nvgBeginPath(vg); nvgRoundedRect(vg, tipBtnX, tipBtnY, equipBtnW, equipBtnH, 8)
        nvgFillColor(vg, nvgRGBA(40, 40, 40, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 100, 100, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 27)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, tipBtnY + equipBtnH / 2, "未解锁")
        -- 底部说明
        nvgFontSize(vg, 27)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(180, 160, 120, 160))
        nvgText(vg, cx, tipBtnY + equipBtnH + 10, "通过残片合成解锁此武技", nil)
    elseif skDef and skDef.unlocked then
        -- 已解锁: 装备/卸下按钮 (不再提供广告升层)
        skillDetailUpgradeBtnRect = nil
        -- 判断当前武技是否已装备
        local equippedSlot = nil
        for slot, techIdx in ipairs(playerEquippedSkills) do
            if techIdx == skillIdx then equippedSlot = slot; break end
        end
        local isEquipped = (equippedSlot ~= nil)
        local slotsFull = (#playerEquippedSkills >= 2)

        skillDetailEquipBtnRect = nil
        skillDetailEquipSlotBtns = {}

        if isEquipped then
            -- 已装备 >> 单个卸下按钮
            local equipBtnX = cx - equipBtnW / 2
            local equipBtnY = H - 70
            nvgBeginPath(vg); nvgRoundedRect(vg, equipBtnX, equipBtnY, equipBtnW, equipBtnH, 8)
            nvgFillColor(vg, nvgRGBA(60, 20, 20, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 60, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFontSize(vg, 27)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(230, 120, 100, 240))
            nvgText(vg, cx, equipBtnY + equipBtnH / 2, "卸下 (槽位" .. equippedSlot .. ")", nil)
            skillDetailEquipBtnRect = { x = equipBtnX, y = equipBtnY, w = equipBtnW, h = equipBtnH, action = "unequip", slot = equippedSlot }
        elseif slotsFull then
            -- 两个槽位都满 >> 显示两个替换按钮
            local totalH = equipBtnH * 2 + equipBtnGap
            local startY = H - 20 - totalH
            local equipBtnX = cx - equipBtnW / 2
            for s = 1, 2 do
                local btnY = startY + (s - 1) * (equipBtnH + equipBtnGap)
                local oldName = SKILL_TECHNIQUES[playerEquippedSkills[s]].name
                nvgBeginPath(vg); nvgRoundedRect(vg, equipBtnX, btnY, equipBtnW, equipBtnH, 8)
                nvgFillColor(vg, nvgRGBA(tc[1] * 0.25, tc[2] * 0.25, tc[3] * 0.25, 220)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
                nvgFontSize(vg, 27)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 230))
                nvgText(vg, cx, btnY + equipBtnH / 2, "替换槽位" .. s .. ": " .. oldName, nil)
                skillDetailEquipSlotBtns[s] = { x = equipBtnX, y = btnY, w = equipBtnW, h = equipBtnH, slot = s }
            end
        else
            -- 有空位 >> 单个装备按钮
            local equipBtnX = cx - equipBtnW / 2
            local equipBtnY = H - 70
            nvgBeginPath(vg); nvgRoundedRect(vg, equipBtnX, equipBtnY, equipBtnW, equipBtnH, 8)
            nvgFillColor(vg, nvgRGBA(tc[1] * 0.3, tc[2] * 0.3, tc[3] * 0.3, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFontSize(vg, 27)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
            nvgText(vg, cx, equipBtnY + equipBtnH / 2, "装备", nil)
            skillDetailEquipBtnRect = { x = equipBtnX, y = equipBtnY, w = equipBtnW, h = equipBtnH, action = "equip" }
        end

        -- 已装备槽位提示
        if #playerEquippedSkills > 0 and not slotsFull then
            local tipY = isEquipped and (H - 70 + equipBtnH + 6) or (H - 70 + equipBtnH + 6)
            nvgFontSize(vg, 27)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(218, 195, 125, 230))
            local slotNames = {}
            for s, ti in ipairs(playerEquippedSkills) do
                slotNames[s] = s .. ":" .. SKILL_TECHNIQUES[ti].name
            end
            nvgText(vg, cx, tipY, "当前装备 [" .. table.concat(slotNames, " | ") .. "]", nil)
        end
    end

    -- 装饰粒子
    for i = 1, 6 do
        local px = W * (0.05 + 0.9 * ((i * 191 + math.floor(t * 9)) % 100) / 100)
        local py = H * (0.6 + 0.35 * math.sin(t * 0.3 + i * 1.5))
        local pr = 1.0 + math.sin(t * 1.5 + i * 0.9) * 0.5
        local pa = math.floor(15 + 12 * math.sin(t * 0.8 + i * 1.1))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], pa)); nvgFill(vg)
    end
end


