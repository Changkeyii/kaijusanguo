-- ui/codex_equip.lua - 三国武灵录 (从 codex.lua 拆分)
function DrawEquipScreen()
    if gameState.phase ~= "EQUIP" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    -- 统一菜单背景
    DrawCodexBg(W, H)

    -- 新版NanoVG网格仓库
    if EquipUI.isVisible then
        EquipUI.Draw()
        return
    end

    nvgFontFaceId(vg, GetMainFont())

    -- 返回按钮
    local backW, backH = 110, 48
    equipBackBtnRect = { x = 10, y = 10, w = backW, h = backH }
    nvgBeginPath(vg); nvgRoundedRect(vg, 10, 10, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 28)
    DrawWhiteInkText(10 + backW / 2, 10 + backH / 2, "< 返回")

    -- 标题
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 46)
    DrawWhiteInkText(cx, 50, "兵甲系统")

    -- 当前装备总加成 + 军资显示
    local eqBonus = GetEquipmentBonus(equipScreenState.selectedHero)
    nvgFontSize(vg, 22)
    -- 用 EQUIP_STAT_DEFS 动态拼接五维+暴击
    local bonusParts = {}
    for _, sd in ipairs(EQUIP_STAT_DEFS) do
        local val = eqBonus[sd.key] or 0
        if val > 0 then
            local fmt = sd.isCrit and "%s+%.1f%%" or "%s+%.0f%%"
            table.insert(bonusParts, string.format(fmt, sd.label, val))
        end
    end
    local bonusStr = "全域增幅: " .. (bonusParts[1] and table.concat(bonusParts, "  ") or "无")
    DrawWhiteInkText(cx, 76, bonusStr)

    -- 额外词条加成显示 (来自套装效果, critRate已在五维中显示)
    local extraParts = {}
    local extraNames = {
        { key = "dmgReduction",      name = "减伤", color = {120, 200, 255} },
        { key = "atkSpeedPct",       name = "攻速", color = {200, 160, 255} },
        { key = "counterRate",       name = "反击", color = {180, 220, 120} },
        { key = "breakDmgPct",       name = "突破", color = {255, 160, 100} },
        { key = "deathExplosionPct", name = "邪爆", color = {255, 100, 180} },
        { key = "speedPct",          name = "移速", color = {160, 255, 200} },
    }
    for _, info in ipairs(extraNames) do
        local val = eqBonus[info.key] or 0
        if val > 0 then
            table.insert(extraParts, { text = info.name .. "+" .. val .. "%", color = info.color })
        end
    end
    if #extraParts > 0 then
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local extraX = cx - (#extraParts - 1) * 45
        for ei, ep in ipairs(extraParts) do
            nvgFillColor(vg, nvgRGBA(ep.color[1], ep.color[2], ep.color[3], 220))
            nvgText(vg, extraX + (ei - 1) * 90, 93, ep.text, nil)
        end
    end

    -- 套装效果概览
    local setCounts = {}
    for si = 1, 7 do
        local eqI = GetEquippedItem(si, equipScreenState.selectedHero)
        if eqI and eqI.setIdx then
            setCounts[eqI.setIdx] = (setCounts[eqI.setIdx] or 0) + 1
        end
    end
    local setInfoParts = {}
    for setIdx, cnt in pairs(setCounts) do
        local setD = EQUIPMENT_SETS[setIdx]
        if setD then
            local suffix = ""
            if cnt >= 7 then
                suffix = " ★7件"
            elseif cnt >= 4 then
                suffix = " ★4件"
            elseif cnt >= 3 then
                suffix = " ★3件"
            end
            table.insert(setInfoParts, setD.name .. " " .. cnt .. "/7" .. suffix)
        end
    end
    if #setInfoParts > 0 then
        nvgFontSize(vg, 21)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 120, 180))
        nvgText(vg, cx, #extraParts > 0 and 110 or 93, table.concat(setInfoParts, "  "), nil)
    end

    -- 军资货币显示（右上角）
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(180, 220, 255, 220))
    nvgText(vg, W - 18, 36, "军资: " .. (playerInfo.lingshi or 0), nil)

    -- 分解按钮区域（右上角军资下方: 筛选分解 + 选中分解）
    local batchBtnW, batchBtnH = 100, 36
    local batchBtnGap = 8
    local batchBtnY = 52
    -- 统计可分解数量
    local batchCount = 0
    local batchGain = 0
    for _, itm in ipairs(playerEquipment.owned) do
        if not itm.heroIdx then
            batchCount = batchCount + 1
            batchGain = batchGain + CalcDecomposeGain(itm.tier, itm.enhanceLv)
        end
    end
    equipScreenState.batchDecompBtn = nil
    equipScreenState.selectDecompBtn = nil
    if batchCount > 0 and not equipScreenState.selectMode then
        -- 筛选分解按钮
        local btn1X = W - 18 - batchBtnW
        nvgBeginPath(vg); nvgRoundedRect(vg, btn1X, batchBtnY, batchBtnW, batchBtnH, 5)
        nvgFillColor(vg, nvgRGBA(120, 50, 50, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(220, 100, 80, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 20)
        DrawWhiteInkText(btn1X + batchBtnW / 2, batchBtnY + batchBtnH / 2, "筛选分解")
        equipScreenState.batchDecompBtn = { x = btn1X, y = batchBtnY, w = batchBtnW, h = batchBtnH, count = batchCount, gain = batchGain }
        -- 选中分解按钮
        local btn2X = btn1X - batchBtnW - batchBtnGap
        nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, batchBtnY, batchBtnW, batchBtnH, 5)
        nvgFillColor(vg, nvgRGBA(50, 80, 120, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 160, 220, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 20)
        DrawWhiteInkText(btn2X + batchBtnW / 2, batchBtnY + batchBtnH / 2, "选中分解")
        equipScreenState.selectDecompBtn = { x = btn2X, y = batchBtnY, w = batchBtnW, h = batchBtnH }
    end

    -- ===========================
    -- 7个装备槽 (上方区域)
    -- ===========================
    local slotStartY = 100
    local slotW = 120
    local slotH = 120
    local slotGap = 12
    local slotsPerRow = 4
    local totalRowW = slotsPerRow * slotW + (slotsPerRow - 1) * slotGap
    local slotStartX = (W - totalRowW) / 2

    equipSlotRects = {}
    local selSlot = equipScreenState.selectedSlot

    for si = 1, 7 do
        local rowIdx = math.floor((si - 1) / slotsPerRow)
        local colIdx = (si - 1) % slotsPerRow
        -- 第二行居中
        local rowStartX = slotStartX
        if rowIdx == 1 then
            local rowCount = 7 - slotsPerRow
            local rowW = rowCount * slotW + (rowCount - 1) * slotGap
            rowStartX = (W - rowW) / 2
        end
        local sx = rowStartX + colIdx * (slotW + slotGap)
        local sy = slotStartY + rowIdx * (slotH + slotGap)

        equipSlotRects[si] = { x = sx, y = sy, w = slotW, h = slotH }

        local isSelected = (si == selSlot)
        local eqInfo = GetEquippedItem(si, equipScreenState.selectedHero)
        local eqSetIdx = eqInfo and eqInfo.setIdx or nil

        -- 槽位底板
        nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, slotW, slotH, 5)
        if isSelected then
            nvgFillColor(vg, nvgRGBA(40, 50, 70, 230))
        else
            nvgFillColor(vg, nvgRGBA(22, 28, 40, 220))
        end
        nvgFill(vg)

        -- 边框
        nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, slotW, slotH, 5)
        if isSelected then
            nvgStrokeColor(vg, nvgRGBA(200, 170, 90, 220))
            nvgStrokeWidth(vg, 2)
        else
            nvgStrokeColor(vg, nvgRGBA(80, 70, 55, 150))
            nvgStrokeWidth(vg, 1)
        end
        nvgStroke(vg)

        -- 槽位名称 (底层，可被图标遮挡)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 29)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 178))
        nvgText(vg, sx + slotW / 2, sy + slotH / 2, EQUIP_SLOT_NAMES[si], nil)

        -- 装备图标 (上层，遮挡名称)
        if eqSetIdx and IMG.equipmentSheet and IMG.equipmentSheet > 0 then
            local eqRow = si - 1    -- row = slot type (0-6)
            local eqCol = eqSetIdx - 1  -- col = set (0-6)
            DrawEquipTierBg(sx + 4, sy + 4, slotW - 8, slotH - 8, eqInfo and eqInfo.tier or 1, 5)
            DrawCardImage(sx + 4, sy + 4, slotW - 8, slotH - 8, IMG.equipmentSheet, eqRow, eqCol, EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
        else
            -- 空槽位图标
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 55)
            DrawWhiteInkText(sx + slotW / 2, sy + slotH / 2 - 12, "+")
        end

        -- 槽位红点（有更好装备时显示）
        if HasEquipSlotRedDot(si) then
            DrawRedDot(sx + slotW - 6, sy + 6, 5)
        end
    end

    -- ===========================
    -- 已选槽位详情
    -- ===========================
    local detailY = slotStartY + 2 * (slotH + slotGap) + 16
    local detailH = 100  -- 加高以容纳强化按钮
    local eqInfoDetail = GetEquippedItem(selSlot, equipScreenState.selectedHero)
    local eqSetIdx = eqInfoDetail and eqInfoDetail.setIdx or nil
    local eqTier = eqInfoDetail and eqInfoDetail.tier or 1

    nvgBeginPath(vg); nvgRoundedRect(vg, 16, detailY, W - 32, detailH, 5)
    nvgFillColor(vg, nvgRGBA(20, 25, 38, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 85, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    equipEnhanceBtnRect = nil  -- 重置强化按钮

    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    if eqSetIdx then
        local setData = EQUIPMENT_SETS[eqSetIdx]
        local piece = setData.pieces[selSlot]
        local tierData = EQUIP_TIERS[eqTier] or EQUIP_TIERS[1]
        local tc = tierData.color
        local tierMul = tierData.multiplier
        local eqEnhLv = eqInfoDetail.enhanceLv or 0
        local enhMul = 1.0 + eqEnhLv * ENHANCE_PERCENT_PER_LEVEL / 100
        local qBonus = GetQualityBonus(eqInfoDetail.quality)
        local qLabel, qColor = GetQualityLabel(eqInfoDetail.quality)
        -- 名称行: 装备名 [品质] 套装名 +强化等级
        nvgFontSize(vg, 33)
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
        local nameStr = piece.name .. " [" .. tierData.name .. "] " .. setData.name
        nvgText(vg, 26, detailY + 24, nameStr, nil)
        -- 等级+强化分离显示
        local detailLv = eqInfoDetail.level or 1
        nvgFontSize(vg, 23)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        -- 先画强化（蓝色）
        local enhTagX = W - 26
        if eqEnhLv > 0 then
            nvgFillColor(vg, nvgRGBA(120, 200, 255, 230))
            local enhText = "+" .. eqEnhLv
            nvgText(vg, enhTagX, detailY + 14, enhText, nil)
            enhTagX = enhTagX - nvgTextBounds(vg, 0, 0, enhText, nil) - 6
        end
        -- 再画等级（金色）
        nvgFillColor(vg, nvgRGBA(255, 220, 120, 230))
        nvgText(vg, enhTagX, detailY + 14, "Lv." .. detailLv, nil)
        nvgFontSize(vg, 25)
        nvgFillColor(vg, nvgRGBA(qColor[1], qColor[2], qColor[3], 220))
        nvgText(vg, W - 26, detailY + 36, qLabel .. " " .. eqInfoDetail.quality .. "%", nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        -- 属性行: 五维属性 × 品阶倍率 × 强化加成
        local detailLvBonus = GetLevelBonus(detailLv)
        nvgFontSize(vg, 26)
        local detailAttrParts = {}
        for _, sd in ipairs(EQUIP_STAT_DEFS) do
            local base = piece[sd.key] or 0
            if base > 0 then
                local val
                if sd.isCrit then
                    val = base * tierMul * enhMul
                else
                    val = (base + qBonus + detailLvBonus) * tierMul * enhMul
                end
                table.insert(detailAttrParts, string.format("%s+%.1f%%", sd.label, val))
            end
        end
        DrawWhiteInkText(26, detailY + 52, table.concat(detailAttrParts, "  "))

        -- 强化按钮（未满级时显示，只显示"强化"）
        if eqEnhLv < ENHANCE_MAX_LEVEL then
            local enhCost = ENHANCE_COST[eqEnhLv + 1] or 999
            local canEnhance = (playerInfo.lingshi >= enhCost)
            local btnW2 = 90
            local btnH2 = 34
            local btnX2 = W - 32 - btnW2 + 8
            local btnY2 = detailY + detailH - btnH2 - 8
            equipEnhanceBtnRect = { x = btnX2, y = btnY2, w = btnW2, h = btnH2 }
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, btnW2, btnH2, 5)
            if canEnhance then
                nvgFillColor(vg, nvgRGBA(60, 140, 220, 230))
            else
                nvgFillColor(vg, nvgRGBA(60, 60, 70, 200))
            end
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 27)
            if canEnhance then
                DrawWhiteInkText(btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "强化")
            else
                nvgFillColor(vg, nvgRGBA(150, 150, 150, 180))
                nvgText(vg, btnX2 + btnW2 / 2, btnY2 + btnH2 / 2, "强化", nil)
            end
        else
            -- 已满级提示
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 27)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
            nvgText(vg, W - 26, detailY + detailH - 22, "强化已满 +20", nil)
        end
    else
        nvgFontSize(vg, 31)
        DrawWhiteInkText(26, detailY + detailH / 2, EQUIP_SLOT_NAMES[selSlot] .. " - 未装备")
    end

    -- ===========================
    -- 套装效果信息 (当前装备所属套装)
    -- ===========================
    if eqSetIdx then
        local setData = EQUIPMENT_SETS[eqSetIdx]
        local setCount = setCounts[eqSetIdx] or 0
        local setInfoY = detailY + detailH + 4
        -- 多阶套装效果: 3行(3件/4件/7件)
        local tierLines = {}
        if setData.setBonus3 then
            table.insert(tierLines, { need = 3, desc = setData.setBonus3Desc or "", bonus = setData.setBonus3 })
        end
        if setData.setBonus4 then
            table.insert(tierLines, { need = 4, desc = setData.setBonus4Desc or "", bonus = setData.setBonus4 })
        end
        if setData.setBonus then
            table.insert(tierLines, { need = 7, desc = setData.setBonusDesc or "", bonus = setData.setBonus })
        end
        local lineH = 20
        local setInfoH = 22 + #tierLines * lineH + 4
        nvgBeginPath(vg); nvgRoundedRect(vg, 16, setInfoY, W - 32, setInfoH, 4)
        nvgFillColor(vg, nvgRGBA(18, 14, 28, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(140, 100, 60, 80)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

        -- 套装标题行
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 22)
        local setTitleClr = setCount >= 7 and nvgRGBA(255, 200, 80, 255) or nvgRGBA(180, 160, 120, 200)
        nvgFillColor(vg, setTitleClr)
        nvgText(vg, 26, setInfoY + 12, setData.name .. " 套装 (" .. setCount .. "/7)", nil)

        -- 多阶效果逐行显示
        for li, tl in ipairs(tierLines) do
            local ly = setInfoY + 22 + (li - 1) * lineH
            local active = setCount >= tl.need
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            -- 阶段标签
            local tagStr = string.format("(%d件)", tl.need)
            if active then
                nvgFillColor(vg, nvgRGBA(255, 220, 80, 240))
                nvgText(vg, 30, ly + lineH / 2, "★ " .. tagStr .. " " .. tl.desc, nil)
            else
                nvgFillColor(vg, nvgRGBA(130, 120, 110, 160))
                nvgText(vg, 30, ly + lineH / 2, "○ " .. tagStr .. " " .. tl.desc, nil)
            end
            -- 右侧状态 (含等阶效力百分比)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 24)
            if active then
                -- 计算套装效力百分比 (按最差等阶)
                local maxTMul = EQUIP_TIERS[#EQUIP_TIERS].multiplier
                local minMul = maxTMul
                for si2 = 1, 7 do
                    local eq2 = GetEquippedItem(si2, equipScreenState.selectedHero)
                    if eq2 and eq2.setIdx == eqSetIdx then
                        local tm2 = EQUIP_TIERS[eq2.tier or 1].multiplier
                        if tm2 < minMul then minMul = tm2 end
                    end
                end
                local pctVal = math.floor(minMul / maxTMul * 100 + 0.5)
                if pctVal >= 100 then
                    nvgFillColor(vg, nvgRGBA(255, 220, 80, 240))
                    nvgText(vg, W - 26, ly + lineH / 2, "满效力", nil)
                else
                    nvgFillColor(vg, nvgRGBA(100, 255, 130, 200))
                    nvgText(vg, W - 26, ly + lineH / 2, "效力" .. pctVal .. "%", nil)
                end
            else
                nvgFillColor(vg, nvgRGBA(100, 95, 85, 140))
                nvgText(vg, W - 26, ly + lineH / 2, "差" .. (tl.need - setCount) .. "件", nil)
            end
        end
        detailH = detailH + setInfoH + 4
    end

    -- ===========================
    -- 可选装备列表 (该槽位拥有的所有装备)
    -- ===========================
    local listY = detailY + detailH + 14
    local itemH = 92
    local listX = 16
    local listW = W - 32

    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(listX, listY - 2, "可选 " .. EQUIP_SLOT_NAMES[selSlot] .. ":")
    listY = listY + 24
    local listH = H - listY - 16  -- 列表区域延伸到底部

    equipPieceRects = {}
    local pieceCount = 0
    -- 收集该槽位所有拥有的装备 (已按阶级降序、品质降序排列)
    local ownedPieces = GetOwnedForSlot(selSlot)

    -- 滚动范围限制
    local totalContentH = #ownedPieces * (itemH + 8) - 8
    local maxScrollY = 0
    local minScrollY = math.min(0, listH - totalContentH)
    equipScreenState.scrollY = math.max(minScrollY, math.min(maxScrollY, equipScreenState.scrollY))
    local scrollY = equipScreenState.scrollY

    -- 裁剪装备列表区域防止超框
    nvgSave(vg)
    nvgScissor(vg, listX, listY, listW, listH)

    for _, op in ipairs(ownedPieces) do
        pieceCount = pieceCount + 1
        local iy = listY + (pieceCount - 1) * (itemH + 8) + scrollY
        -- 跳过不可见的项（但不中断循环）
        if iy + itemH < listY or iy > listY + listH then goto continue end

        local si = op.setIdx
        local ti = op.tier
        local setData = EQUIPMENT_SETS[si]
        local piece = setData.pieces[selSlot]
        local isEquipped = (op.heroIdx == equipScreenState.selectedHero and op.heroIdx ~= nil)
        local tierData = EQUIP_TIERS[ti] or EQUIP_TIERS[1]
        local tc = tierData.color
        local tierMul = tierData.multiplier

        local rect = { x = listX, y = iy, w = listW, h = itemH, info = { uid = op.uid, setIdx = si, slotIdx = selSlot, tier = ti } }
        equipPieceRects[pieceCount] = rect

        -- 选中状态
        local isSelected = equipScreenState.selectMode and equipScreenState.selectedUids[op.uid]

        -- 底板
        nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 4)
        if isSelected then
            nvgFillColor(vg, nvgRGBA(40, 50, 80, 240))
        elseif isEquipped then
            nvgFillColor(vg, nvgRGBA(35, 50, 40, 230))
        else
            nvgFillColor(vg, nvgRGBA(22, 26, 38, 220))
        end
        nvgFill(vg)

        -- 阶级色边框
        nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 4)
        if isSelected then
            nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 200))
        elseif isEquipped then
            nvgStrokeColor(vg, nvgRGBA(100, 220, 130, 180))
        else
            nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 130))
        end
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 装备小图标
        if IMG.equipmentSheet and IMG.equipmentSheet > 0 then
            local eqRow = selSlot - 1
            local eqCol = si - 1
            DrawEquipTierBg(listX + 4, iy + 4, itemH - 8, itemH - 8, ti, 4)
            DrawCardImage(listX + 4, iy + 4, itemH - 8, itemH - 8, IMG.equipmentSheet, eqRow, eqCol, EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
        end

        -- 阶级标签（自适应icon大小）
        local iconSize = itemH - 8
        local badgeW = math.floor(iconSize * 0.35)
        local badgeH = math.floor(iconSize * 0.22)
        local badgeFs = math.floor(iconSize * 0.20)
        local tierBadgeX = listX + 4
        local tierBadgeY = iy + 4
        nvgBeginPath(vg); nvgRoundedRect(vg, tierBadgeX, tierBadgeY, badgeW, badgeH, 2)
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200)); nvgFill(vg)
        nvgFontSize(vg, badgeFs); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(tierBadgeX + badgeW / 2, tierBadgeY + badgeH / 2, tierData.name)

        -- 装备名称和套装名
        local textX = listX + itemH + 10
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 31)
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
        local itemName = piece.name
        nvgText(vg, textX, iy + 22, itemName, nil)

        -- 等级+强化分离标签 (右上角)
        local itemLv = op.level or 1
        local itemEnhLv = op.enhanceLv or 0
        nvgFontSize(vg, 21)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        local tagRightX = listX + listW - 10
        -- 强化（蓝色）
        if itemEnhLv > 0 then
            nvgFillColor(vg, nvgRGBA(120, 200, 255, 220))
            local enhStr = "+" .. itemEnhLv
            nvgText(vg, tagRightX, iy + 12, enhStr, nil)
            tagRightX = tagRightX - nvgTextBounds(vg, 0, 0, enhStr, nil) - 4
        end
        -- 等级（金色）
        nvgFillColor(vg, nvgRGBA(255, 220, 120, 220))
        nvgText(vg, tagRightX, iy + 12, "Lv." .. itemLv, nil)

        -- 品质标签 (右侧名称行)
        local qLabel, qColor = GetQualityLabel(op.quality)
        nvgFontSize(vg, 23)
        nvgFillColor(vg, nvgRGBA(qColor[1], qColor[2], qColor[3], 200))
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, listX + listW - 82, iy + 22, qLabel .. op.quality .. "%", nil)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

        nvgFontSize(vg, 27)
        nvgFillColor(vg, nvgRGBA(setData.color[1], setData.color[2], setData.color[3], 140))
        nvgText(vg, textX, iy + 46, setData.name .. " - " .. tierData.name, nil)

        -- 属性 (含阶级加成+品质加成+等级加成, 百分比)
        local qBonus = GetQualityBonus(op.quality)
        local itemLvBonus = GetLevelBonus(itemLv)
        local enhMulItem = 1.0 + itemEnhLv * ENHANCE_PERCENT_PER_LEVEL / 100
        nvgFontSize(vg, 24)
        local itemAttrParts = {}
        for _, sd in ipairs(EQUIP_STAT_DEFS) do
            local base = piece[sd.key] or 0
            if base > 0 then
                local val
                if sd.isCrit then
                    val = base * tierMul * enhMulItem
                else
                    val = (base + qBonus + itemLvBonus) * tierMul * enhMulItem
                end
                table.insert(itemAttrParts, string.format("%s+%.1f%%", sd.label, val))
            end
        end
        DrawWhiteInkText(textX, iy + 70, table.concat(itemAttrParts, "  "))

        -- 右侧操作区
        if equipScreenState.selectMode then
            -- 选中模式: 显示复选框（已装备不可选）
            local cbSize = 28
            local cbX = listX + listW - cbSize - 12
            local cbY = iy + (itemH - cbSize) / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, cbX, cbY, cbSize, cbSize, 4)
            if isEquipped then
                nvgFillColor(vg, nvgRGBA(40, 40, 40, 150)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 80, 80, 100))
            elseif isSelected then
                nvgFillColor(vg, nvgRGBA(60, 120, 200, 220)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 200))
            else
                nvgFillColor(vg, nvgRGBA(30, 30, 40, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(120, 120, 140, 150))
            end
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            if isSelected then
                -- 勾号
                nvgBeginPath(vg)
                nvgMoveTo(vg, cbX + 6, cbY + cbSize * 0.5)
                nvgLineTo(vg, cbX + cbSize * 0.4, cbY + cbSize - 7)
                nvgLineTo(vg, cbX + cbSize - 5, cbY + 6)
                nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 240))
                nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
            elseif isEquipped then
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFontSize(vg, 24)
                nvgFillColor(vg, nvgRGBA(100, 100, 100, 150))
                nvgText(vg, cbX + cbSize / 2, cbY + cbSize / 2, "装备中", nil)
            end
            rect.checkboxRect = not isEquipped and { x = cbX, y = cbY, w = cbSize, h = cbSize } or nil
        elseif isEquipped then
            -- 已装备 → 显示"卸下"按钮
            local unequipBtnW = 68
            local unequipBtnH = 36
            local unequipBtnX = listX + listW - unequipBtnW - 8
            local unequipBtnY = iy + (itemH - unequipBtnH) / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, unequipBtnX, unequipBtnY, unequipBtnW, unequipBtnH, 4)
            nvgFillColor(vg, nvgRGBA(80, 70, 50, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 180, 100, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 26)
            DrawWhiteInkText(unequipBtnX + unequipBtnW / 2, unequipBtnY + unequipBtnH / 2, "卸下")
            rect.unequipRect = { x = unequipBtnX, y = unequipBtnY, w = unequipBtnW, h = unequipBtnH }
        else
            -- "装备" 按钮
            local equipBtnW = 68
            local equipBtnH = 36
            local equipBtnX = listX + listW - equipBtnW - 8
            local equipBtnY = iy + 10
            nvgBeginPath(vg); nvgRoundedRect(vg, equipBtnX, equipBtnY, equipBtnW, equipBtnH, 4)
            nvgFillColor(vg, nvgRGBA(50, 120, 80, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 200, 140, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 26)
            DrawWhiteInkText(equipBtnX + equipBtnW / 2, equipBtnY + equipBtnH / 2, "装备")
            rect.equipBtnRect = { x = equipBtnX, y = equipBtnY, w = equipBtnW, h = equipBtnH }

            -- "分解" 按钮
            local decBtnW = 68
            local decBtnH = 36
            local decBtnX = listX + listW - decBtnW - 8
            local decBtnY = iy + itemH - decBtnH - 10
            local dEnhLv2 = op.enhanceLv or 0
            local decompGain = CalcDecomposeGain(ti, dEnhLv2)
            nvgBeginPath(vg); nvgRoundedRect(vg, decBtnX, decBtnY, decBtnW, decBtnH, 4)
            nvgFillColor(vg, nvgRGBA(140, 60, 60, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(220, 100, 100, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 26)
            DrawWhiteInkText(decBtnX + decBtnW / 2, decBtnY + decBtnH / 2, "分解")
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(180, 200, 220, 160))
            local decompLabel = "+" .. decompGain .. "军资"
            if dEnhLv2 > 0 then decompLabel = decompLabel .. "(+强化)" end
            nvgText(vg, decBtnX - 6, decBtnY + decBtnH / 2, decompLabel, nil)
            rect.decompRect = { x = decBtnX, y = decBtnY, w = decBtnW, h = decBtnH }
        end
        ::continue::
    end

    -- 滚动条指示器（加粗、高可见度）
    if totalContentH > listH and #ownedPieces > 0 then
        -- 滚动轨道背景
        local barW = 6
        local barX = listX + listW - barW - 4
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, listY, barW, listH, 3)
        nvgFillColor(vg, nvgRGBA(60, 70, 90, 100)); nvgFill(vg)
        -- 滚动滑块
        local scrollRatio = minScrollY ~= 0 and (math.abs(scrollY) / math.abs(minScrollY)) or 0
        local barH = math.max(30, listH * (listH / totalContentH))
        local barY = listY + scrollRatio * (listH - barH)
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 3)
        nvgFillColor(vg, nvgRGBA(180, 200, 220, 160)); nvgFill(vg)
        -- 滑块高亮边
        nvgStrokeColor(vg, nvgRGBA(220, 230, 240, 80)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    end

    if pieceCount == 0 then
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 33)
        DrawWhiteInkText(cx, listY + 35, "暂无该类型兵甲")
        nvgFontSize(vg, 29)
        DrawWhiteInkText(cx, listY + 60, "通过战斗胜利可获得兵甲")
    end

    nvgRestore(vg)  -- 结束装备列表裁剪区域

    -- ========== 选中分解模式底部操作栏 ==========
    equipScreenState.selectConfirmBtn = nil
    equipScreenState.selectCancelBtn = nil
    equipScreenState.selectAllBtn = nil
    if equipScreenState.selectMode then
        local barH2 = 48
        local barY2 = H - barH2
        -- 底栏背景
        nvgBeginPath(vg); nvgRect(vg, 0, barY2, W, barH2)
        nvgFillColor(vg, nvgRGBA(20, 25, 40, 240)); nvgFill(vg)
        nvgBeginPath(vg); nvgMoveTo(vg, 0, barY2); nvgLineTo(vg, W, barY2)
        nvgStrokeColor(vg, nvgRGBA(80, 140, 220, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 统计选中数量
        local selCount, selGain = CalcSelectDecomposeStats(equipScreenState.selectedUids)

        -- 左侧: 选中信息
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(180, 210, 255, 220))
        nvgText(vg, 16, barY2 + barH2 / 2, "已选 " .. selCount .. " 件  +" .. selGain .. " 军资", nil)

        -- 右侧按钮: 全选 | 确认分解 | 取消
        local sbW, sbH = 72, 34
        local sbGap = 8
        local sbY = barY2 + (barH2 - sbH) / 2
        -- 取消按钮
        local cancelX = W - 16 - sbW
        nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, sbY, sbW, sbH, 5)
        nvgFillColor(vg, nvgRGBA(80, 70, 50, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 160, 100, 130)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 19)
        DrawWhiteInkText(cancelX + sbW / 2, sbY + sbH / 2, "取消")
        equipScreenState.selectCancelBtn = { x = cancelX, y = sbY, w = sbW, h = sbH }

        -- 确认分解按钮
        local confirmX = cancelX - sbW - sbGap
        nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, sbY, sbW, sbH, 5)
        if selCount > 0 then
            nvgFillColor(vg, nvgRGBA(160, 50, 40, 230)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(240, 100, 80, 160))
        else
            nvgFillColor(vg, nvgRGBA(60, 40, 40, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 80, 80, 100))
        end
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 19)
        nvgFillColor(vg, selCount > 0 and nvgRGBA(255, 230, 210, 255) or nvgRGBA(120, 100, 100, 150))
        nvgText(vg, confirmX + sbW / 2, sbY + sbH / 2, "分解", nil)
        equipScreenState.selectConfirmBtn = selCount > 0 and { x = confirmX, y = sbY, w = sbW, h = sbH } or nil

        -- 全选按钮
        local allX = confirmX - sbW - sbGap
        nvgBeginPath(vg); nvgRoundedRect(vg, allX, sbY, sbW, sbH, 5)
        nvgFillColor(vg, nvgRGBA(50, 80, 120, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 160, 220, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 19)
        DrawWhiteInkText(allX + sbW / 2, sbY + sbH / 2, "全选")
        equipScreenState.selectAllBtn = { x = allX, y = sbY, w = sbW, h = sbH }
    end

    -- ========== 选中分解确认弹窗 ==========
    if equipScreenState.selectDecompConfirm then
        local sdc = equipScreenState.selectDecompConfirm
        local dW, dH = DESIGN_W, DESIGN_H
        nvgBeginPath(vg); nvgRect(vg, 0, 0, dW, dH)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 150)); nvgFill(vg)

        local pw, ph = 360, 200
        local px, py = (dW - pw) / 2, (dH - ph) / 2 - 20
        nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
        local sbg = nvgLinearGradient(vg, px, py, px, py + ph,
            nvgRGBA(40, 30, 60, 245), nvgRGBA(25, 20, 40, 245))
        nvgFillPaint(vg, sbg); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 150, 220, 130)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 28)
        DrawWhiteInkText(dW / 2, py + 36, "确认分解选中兵甲？")

        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 210, 150, 220))
        nvgText(vg, dW / 2, py + 75, "将分解 " .. sdc.count .. " 件兵甲", nil)
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 220))
        nvgText(vg, dW / 2, py + 102, "预计获得 " .. sdc.gain .. " 军资", nil)
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(255, 130, 100, 180))
        nvgText(vg, dW / 2, py + 126, "此操作不可撤销!", nil)

        local btnW2, btnH2 = 120, 42
        local gap2 = 24
        local btnY2 = py + ph - 55
        local cfmX = dW / 2 - btnW2 - gap2 / 2
        local cnlX = dW / 2 + gap2 / 2

        nvgBeginPath(vg); nvgRoundedRect(vg, cfmX, btnY2, btnW2, btnH2, 8)
        local cbg3 = nvgLinearGradient(vg, cfmX, btnY2, cfmX, btnY2 + btnH2,
            nvgRGBA(180, 60, 40, 230), nvgRGBA(140, 40, 25, 230))
        nvgFillPaint(vg, cbg3); nvgFill(vg)
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(255, 230, 210, 255))
        nvgText(vg, cfmX + btnW2 / 2, btnY2 + btnH2 / 2, "确认分解", nil)
        equipScreenState.selectDecompConfirmBtn = { x = cfmX, y = btnY2, w = btnW2, h = btnH2 }

        nvgBeginPath(vg); nvgRoundedRect(vg, cnlX, btnY2, btnW2, btnH2, 8)
        local kbg3 = nvgLinearGradient(vg, cnlX, btnY2, cnlX, btnY2 + btnH2,
            nvgRGBA(255, 200, 80, 230), nvgRGBA(220, 160, 40, 230))
        nvgFillPaint(vg, kbg3); nvgFill(vg)
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(50, 30, 10, 255))
        nvgText(vg, cnlX + btnW2 / 2, btnY2 + btnH2 / 2, "取消", nil)
        equipScreenState.selectDecompCancelBtn = { x = cnlX, y = btnY2, w = btnW2, h = btnH2 }
    end

    -- ========== 分解确认弹窗 ==========
    if equipScreenState.decompConfirm then
        local dc = equipScreenState.decompConfirm
        local dW, dH = DESIGN_W, DESIGN_H

        -- 半透明遮罩
        nvgBeginPath(vg); nvgRect(vg, 0, 0, dW, dH)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 130)); nvgFill(vg)

        -- 弹窗面板
        local pw, ph = 360, 210
        local px, py = (dW - pw) / 2, (dH - ph) / 2 - 20
        nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
        local bg = nvgLinearGradient(vg, px, py, px, py + ph,
            nvgRGBA(45, 25, 30, 245), nvgRGBA(28, 15, 18, 245))
        nvgFillPaint(vg, bg); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(220, 100, 100, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- 标题
        nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 30)
        DrawWhiteInkText(dW / 2, py + 42, "确认分解？")

        -- 装备名称 + 获得军资
        local tierName = EQUIP_TIERS[dc.tier] and EQUIP_TIERS[dc.tier].name or ""
        local setData = EQUIPMENT_SETS[dc.setIdx]
        local pieceName = setData and setData.pieces[dc.slotIdx] and setData.pieces[dc.slotIdx].name or ""
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 210, 150, 220))
        nvgText(vg, dW / 2, py + 85, tierName .. " " .. pieceName, nil)

        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(180, 210, 240, 200))
        if dc.enhLv and dc.enhLv > 0 then
            nvgText(vg, dW / 2, py + 112, string.format("强化+%d  分解可获得 %d 军资", dc.enhLv, dc.gain), nil)
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, 180))
            nvgText(vg, dW / 2, py + 134, "(含强化返还" .. (dc.enhRefund or 0) .. "军资)", nil)
        else
            nvgText(vg, dW / 2, py + 118, "分解可获得 " .. dc.gain .. " 军资", nil)
        end

        -- 按钮
        local btnW2, btnH2 = 120, 42
        local gap = 24
        local btnY = py + ph - 60
        local confirmX = dW / 2 - btnW2 - gap / 2
        local cancelX = dW / 2 + gap / 2

        -- 确认分解按钮 (红色调)
        nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, btnY, btnW2, btnH2, 8)
        local cbg = nvgLinearGradient(vg, confirmX, btnY, confirmX, btnY + btnH2,
            nvgRGBA(180, 60, 40, 220), nvgRGBA(140, 40, 25, 220))
        nvgFillPaint(vg, cbg); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 120, 100, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 230, 210, 255))
        nvgText(vg, confirmX + btnW2 / 2, btnY + btnH2 / 2, "确认分解", nil)
        equipScreenState.decompConfirmBtn = { x = confirmX, y = btnY, w = btnW2, h = btnH2 }

        -- 取消按钮 (金色调，更醒目)
        nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, btnY, btnW2, btnH2, 8)
        local kbg = nvgLinearGradient(vg, cancelX, btnY, cancelX, btnY + btnH2,
            nvgRGBA(255, 200, 80, 230), nvgRGBA(220, 160, 40, 230))
        nvgFillPaint(vg, kbg); nvgFill(vg)
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(50, 30, 10, 255))
        nvgText(vg, cancelX + btnW2 / 2, btnY + btnH2 / 2, "取消", nil)
        equipScreenState.decompCancelBtn = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
    end

    -- ========== 强化确认弹窗 ==========
    if equipScreenState.enhanceConfirm then
        local ec = equipScreenState.enhanceConfirm
        local dW, dH = DESIGN_W, DESIGN_H

        -- 半透明遮罩
        nvgBeginPath(vg); nvgRect(vg, 0, 0, dW, dH)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 130)); nvgFill(vg)

        -- 弹窗面板
        local pw, ph = 340, 180
        local px, py = (dW - pw) / 2, (dH - ph) / 2 - 20
        nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
        local ebg = nvgLinearGradient(vg, px, py, px, py + ph,
            nvgRGBA(30, 40, 65, 245), nvgRGBA(20, 25, 40, 245))
        nvgFillPaint(vg, ebg); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- 标题
        nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 30)
        DrawWhiteInkText(dW / 2, py + 38, "确认强化？")

        -- 信息
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(180, 210, 240, 220))
        nvgText(vg, dW / 2, py + 78, string.format("强化等级: +%d → +%d", ec.enhLv, ec.enhLv + 1), nil)
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(255, 210, 150, 200))
        nvgText(vg, dW / 2, py + 105, string.format("消耗 %d 军资", ec.cost), nil)

        -- 按钮
        local btnW2, btnH2 = 120, 42
        local gap = 24
        local btnY = py + ph - 56
        local confirmX = dW / 2 - btnW2 - gap / 2
        local cancelX = dW / 2 + gap / 2

        -- 确认强化按钮 (蓝色调)
        nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, btnY, btnW2, btnH2, 8)
        local ecbg = nvgLinearGradient(vg, confirmX, btnY, confirmX, btnY + btnH2,
            nvgRGBA(50, 120, 210, 230), nvgRGBA(35, 90, 170, 230))
        nvgFillPaint(vg, ecbg); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, confirmX + btnW2 / 2, btnY + btnH2 / 2, "确认强化", nil)
        equipScreenState.enhanceConfirmBtn = { x = confirmX, y = btnY, w = btnW2, h = btnH2 }

        -- 取消按钮 (金色调)
        nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, btnY, btnW2, btnH2, 8)
        local ekbg = nvgLinearGradient(vg, cancelX, btnY, cancelX, btnY + btnH2,
            nvgRGBA(255, 200, 80, 230), nvgRGBA(220, 160, 40, 230))
        nvgFillPaint(vg, ekbg); nvgFill(vg)
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(50, 30, 10, 255))
        nvgText(vg, cancelX + btnW2 / 2, btnY + btnH2 / 2, "取消", nil)
        equipScreenState.enhanceCancelBtn = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
    end

    -- ========== 批量分解确认弹窗 (含品质筛选) ==========
    if equipScreenState.batchDecompConfirm then
        local bdc = equipScreenState.batchDecompConfirm
        local dW, dH = DESIGN_W, DESIGN_H

        nvgBeginPath(vg); nvgRect(vg, 0, 0, dW, dH)
        nvgFillColor(vg, nvgRGBA(5, 5, 12, 150)); nvgFill(vg)

        local pw, ph = 400, 270
        local px, py = (dW - pw) / 2, (dH - ph) / 2 - 20
        nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
        local bbg = nvgLinearGradient(vg, px, py, px, py + ph,
            nvgRGBA(50, 25, 25, 245), nvgRGBA(30, 15, 15, 245))
        nvgFillPaint(vg, bbg); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(220, 100, 80, 130)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 30)
        DrawWhiteInkText(dW / 2, py + 36, "筛选分解")

        -- 品质筛选行
        local ft = equipScreenState.batchFilterMaxTier or 6
        local filterY = py + 75
        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 200))
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, dW / 2 - 80, filterY, "分解品质上限:", nil)

        -- 左箭头
        local arrowW, arrowH = 30, 28
        local arrowLX = dW / 2 - 72
        nvgBeginPath(vg); nvgRoundedRect(vg, arrowLX, filterY - arrowH / 2, arrowW, arrowH, 4)
        nvgFillColor(vg, ft > 1 and nvgRGBA(80, 60, 60, 200) or nvgRGBA(40, 30, 30, 100)); nvgFill(vg)
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, ft > 1 and nvgRGBA(255, 220, 180, 230) or nvgRGBA(100, 80, 80, 100))
        nvgText(vg, arrowLX + arrowW / 2, filterY, "<", nil)
        equipScreenState.batchFilterLeftBtn = { x = arrowLX, y = filterY - arrowH / 2, w = arrowW, h = arrowH }

        -- 当前品质名称
        local tierFilterNames = { "凡品", "良品", "优品", "将品", "王品", "全部" }
        local tierName = tierFilterNames[ft] or "全部"
        local tc = ft <= #EQUIP_TIERS and EQUIP_TIERS[ft].color or { 255, 255, 255 }
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 255))
        local tierLabel = ft < 6 and (tierName .. "及以下") or "全部品质"
        nvgText(vg, dW / 2 + 10, filterY, tierLabel, nil)

        -- 右箭头
        local arrowRX = dW / 2 + 80
        nvgBeginPath(vg); nvgRoundedRect(vg, arrowRX, filterY - arrowH / 2, arrowW, arrowH, 4)
        nvgFillColor(vg, ft < 6 and nvgRGBA(80, 60, 60, 200) or nvgRGBA(40, 30, 30, 100)); nvgFill(vg)
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, ft < 6 and nvgRGBA(255, 220, 180, 230) or nvgRGBA(100, 80, 80, 100))
        nvgText(vg, arrowRX + arrowW / 2, filterY, ">", nil)
        equipScreenState.batchFilterRightBtn = { x = arrowRX, y = filterY - arrowH / 2, w = arrowW, h = arrowH }

        -- 分割线
        nvgBeginPath(vg)
        nvgMoveTo(vg, px + 20, filterY + 22)
        nvgLineTo(vg, px + pw - 20, filterY + 22)
        nvgStrokeColor(vg, nvgRGBA(120, 80, 60, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 统计信息
        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 210, 150, 220))
        nvgText(vg, dW / 2, filterY + 48, "将分解 " .. bdc.count .. " 件未装备兵甲", nil)
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 220))
        nvgText(vg, dW / 2, filterY + 75, "预计获得 " .. bdc.gain .. " 军资", nil)
        if bdc.count == 0 then
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(255, 180, 100, 180))
            nvgText(vg, dW / 2, filterY + 98, "当前筛选无可分解物品", nil)
        else
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(255, 130, 100, 180))
            nvgText(vg, dW / 2, filterY + 98, "此操作不可撤销!", nil)
        end

        local btnW2, btnH2 = 120, 42
        local gap = 24
        local btnY = py + ph - 58
        local confirmX = dW / 2 - btnW2 - gap / 2
        local cancelX = dW / 2 + gap / 2

        -- 确认按钮(无可分解时置灰)
        nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, btnY, btnW2, btnH2, 8)
        if bdc.count > 0 then
            local cbg2 = nvgLinearGradient(vg, confirmX, btnY, confirmX, btnY + btnH2,
                nvgRGBA(180, 60, 40, 230), nvgRGBA(140, 40, 25, 230))
            nvgFillPaint(vg, cbg2); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(60, 40, 40, 180)); nvgFill(vg)
        end
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, bdc.count > 0 and nvgRGBA(255, 230, 210, 255) or nvgRGBA(120, 100, 100, 150))
        nvgText(vg, confirmX + btnW2 / 2, btnY + btnH2 / 2, "确认分解", nil)
        equipScreenState.batchDecompConfirmBtn = bdc.count > 0
            and { x = confirmX, y = btnY, w = btnW2, h = btnH2 } or nil

        nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, btnY, btnW2, btnH2, 8)
        local kbg2 = nvgLinearGradient(vg, cancelX, btnY, cancelX, btnY + btnH2,
            nvgRGBA(255, 200, 80, 230), nvgRGBA(220, 160, 40, 230))
        nvgFillPaint(vg, kbg2); nvgFill(vg)
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(50, 30, 10, 255))
        nvgText(vg, cancelX + btnW2 / 2, btnY + btnH2 / 2, "取消", nil)
        equipScreenState.batchDecompCancelBtn = { x = cancelX, y = btnY, w = btnW2, h = btnH2 }
    end
end


-- ============================================================================
-- 个人资料设置 (首次进入) - 设计坐标
-- ============================================================================
function DrawProfileScreen()
    if gameState.phase ~= "PROFILE" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer

    -- 1. 统一菜单背景
    DrawCodexBg(W, H)

    -- 字体未就绪时显示进度条（防止文字不显示）
    if fontId < 0 then
        -- 限制重试频率：最多每秒尝试一次（避免每帧文件I/O卡住渲染线程）
        local now = time:GetElapsedTime()
        if not _fontRetryTime or (now - _fontRetryTime) >= 1.0 then
            _fontRetryTime = now
            fontId = nvgCreateFont(vg, "sans", "Fonts/LXGWWenKai-Regular.ttf")
            if fontId >= 0 then
                nvgCreateFont(vg, "emoji", "Fonts/LXGWWenKai-Regular.ttf")
                if fontArt < 0 then
                    fontArt = nvgCreateFont(vg, "art", "Fonts/ZhiMangXing-Regular.ttf")
                    if fontArt >= 0 then nvgAddFallbackFontId(vg, fontArt, fontId) end
                end
                if fontGame < 0 then
                    fontGame = nvgCreateFont(vg, "game", "Fonts/ZCOOLKuaiLe-Regular.ttf")
                    if fontGame >= 0 then nvgAddFallbackFontId(vg, fontGame, fontId) end
                end
                if fontKai < 0 then
                    fontKai = nvgCreateFont(vg, "kai", "Fonts/ZCOOLKuaiLe-Regular.ttf")
                    if fontKai >= 0 then nvgAddFallbackFontId(vg, fontKai, fontId) end
                end
                if fontFZ < 0 then
                    fontFZ = nvgCreateFont(vg, "fangzheng", "Fonts/LXGWWenKai-Regular.ttf")
                    if fontFZ >= 0 then nvgAddFallbackFontId(vg, fontFZ, fontId) end
                end
            end
        end
        if fontId < 0 then
            -- 字体仍未就绪，显示加载进度条
            local pct = blockingLoadState.progress or 0
            local barW = W * 0.5
            local barH = 6
            local barX = cx - barW / 2
            local barY = H / 2 + 10

            -- 进度条背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW, barH, 3)
            nvgFillColor(vg, nvgRGBA(40, 40, 55, 200)); nvgFill(vg)

            -- 进度填充
            local fillW = barW * pct
            if fillW > 1 then
                local grad = nvgLinearGradient(vg, barX, barY, barX + fillW, barY,
                    nvgRGBA(180, 150, 90, 220), nvgRGBA(220, 190, 120, 220))
                nvgBeginPath(vg)
                nvgRoundedRect(vg, barX, barY, fillW, barH, 3)
                nvgFillPaint(vg, grad); nvgFill(vg)
            end

            -- 提示文字（用默认字体）
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local tipAlpha = math.floor(140 + 60 * math.sin(t * 2.0))
            nvgFillColor(vg, nvgRGBA(200, 190, 160, tipAlpha))
            nvgText(vg, cx, barY + barH + 20, "正在加载资源...", nil)
            return
        end
    end

    nvgFontFaceId(vg, GetMainFont())

    -- ===========================
    -- 横屏左右分栏布局 (1024×571)
    -- 左栏: 标题 + 头像选择
    -- 右栏: 道号选择 + 确认按钮
    -- ===========================
    local leftW = W * 0.45          -- 左栏占 45%
    local rightW = W * 0.45         -- 右栏占 45%
    local gap = W * 0.04            -- 中间间隔 4%
    local leftX = (W - leftW - gap - rightW) / 2  -- 居中
    local rightX = leftX + leftW + gap
    local topY = 30                 -- 顶部留白

    -- === 标题 (居中) ===
    nvgFontSize(vg, 38)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local profileTitle = profileState.editMode and "编辑资料" or "讨伐初始"
    DrawWhiteInkText(cx, topY + 18, profileTitle)

    nvgFontSize(vg, 18)
    local profileSubtitle = profileState.editMode and "修改你的代号与头像" or "选择你的代号与头像"
    DrawWhiteInkText(cx, topY + 44, profileSubtitle)

    local contentY = topY + 68  -- 内容区起始Y

    -- ===========================
    -- 左栏: 头像选择 (3列×2行)
    -- ===========================
    local leftCx = leftX + leftW / 2
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawWhiteInkText(leftCx, contentY, "选择头像")

    local avCols = 3
    local avSize = 80
    local avGap = 14
    local avGridW = avCols * avSize + (avCols - 1) * avGap
    local avStartX = leftCx - avGridW / 2
    local avStartY = contentY + 30
    profileAvatarRects = {}

    for i, cardIdx in ipairs(AVATAR_OPTIONS) do
        local col = ((i - 1) % avCols)
        local row = math.floor((i - 1) / avCols)
        local ax = avStartX + col * (avSize + avGap)
        local ay = avStartY + row * (avSize + avGap)
        local selected = (profileState.selectedAvatar == i)

        -- 选中光圈
        if selected then
            local glowPulse = 0.6 + 0.4 * math.sin(t * 3)
            nvgBeginPath(vg); nvgRoundedRect(vg, ax - 4, ay - 4, avSize + 8, avSize + 8, 6)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 100, math.floor(200 * glowPulse)))
            nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
        end

        -- 头像底板
        nvgBeginPath(vg); nvgRoundedRect(vg, ax - 1, ay - 1, avSize + 2, avSize + 2, 5)
        nvgFillColor(vg, selected and nvgRGBA(90, 45, 55, 200) or nvgRGBA(60, 50, 35, 180))
        nvgFill(vg)

        -- 头像图 (用IMG.avatarSheet)
        if IMG.avatarSheet >= 0 then
            local avData = AVATAR_DATA[cardIdx]
            if avData then
                local imgW, imgH = 512, 768
                local cellW = imgW / AVATAR_COLS
                local cellH = imgH / AVATAR_ROWS
                local sx = avData.col * cellW
                local sy = avData.row * cellH
                local patImg = nvgImagePattern(vg,
                    ax - sx * (avSize / cellW), ay - sy * (avSize / cellH),
                    imgW * (avSize / cellW), imgH * (avSize / cellH),
                    0, IMG.avatarSheet, 1.0)
                nvgBeginPath(vg); nvgRoundedRect(vg, ax, ay, avSize, avSize, 4)
                nvgFillPaint(vg, patImg); nvgFill(vg)
            end
        end

        -- 边框
        nvgBeginPath(vg); nvgRoundedRect(vg, ax, ay, avSize, avSize, 4)
        nvgStrokeColor(vg, selected and nvgRGBA(255, 220, 100, 200) or nvgRGBA(100, 85, 55, 140))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        profileAvatarRects[i] = { x = ax, y = ay, w = avSize, h = avSize }
    end

    -- 左栏底部提示
    local avEndY = avStartY + 2 * (avSize + avGap)
    nvgFontFaceId(vg, fontId)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(180, 165, 130, 140))
    nvgText(vg, leftCx, avEndY + 6, "点击头像选择你的形象", nil)

    -- === 左右分隔线 ===
    local divX = leftX + leftW + gap / 2
    nvgBeginPath(vg)
    nvgMoveTo(vg, divX, contentY)
    nvgLineTo(vg, divX, H - 40)
    nvgStrokeColor(vg, nvgRGBA(120, 100, 60, 60))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- ===========================
    -- 右栏: 道号选择 + 确认按钮
    -- ===========================
    local rightCx = rightX + rightW / 2
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    DrawWhiteInkText(rightCx, contentY, "选择道号")

    local nameStartY = contentY + 30
    local nameCols = 2
    local nameW = rightW * 0.46
    local nameH = 36
    local nameGap = 10
    local nameGridW = nameCols * nameW + (nameCols - 1) * nameGap
    local nameStartX = rightCx - nameGridW / 2
    profileNameRects = {}

    for i, name in ipairs(PRESET_NAMES) do
        local col = ((i - 1) % nameCols)
        local row = math.floor((i - 1) / nameCols)
        local nx = nameStartX + col * (nameW + nameGap)
        local ny = nameStartY + row * (nameH + nameGap)
        local selected = (profileState.selectedName == i)

        -- 按钮背景
        nvgBeginPath(vg); nvgRoundedRect(vg, nx, ny, nameW, nameH, 5)
        if selected then
            local selGrad = nvgLinearGradient(vg, nx, ny, nx, ny + nameH,
                nvgRGBA(60, 50, 25, 200), nvgRGBA(40, 35, 15, 200))
            nvgFillPaint(vg, selGrad); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(35, 40, 55, 150)); nvgFill(vg)
        end

        -- 边框
        nvgBeginPath(vg); nvgRoundedRect(vg, nx, ny, nameW, nameH, 5)
        nvgStrokeColor(vg, selected and nvgRGBA(255, 220, 100, 180) or nvgRGBA(100, 85, 55, 120))
        nvgStrokeWidth(vg, selected and 1.5 or 0.8); nvgStroke(vg)

        -- 名字文字
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(nx + nameW / 2, ny + nameH / 2, name)

        profileNameRects[i] = { x = nx, y = ny, w = nameW, h = nameH }
    end

    -- 第7个选项: "自定义名字"（跨两列宽度）
    do
        local customRow = 3  -- 第4行(0-based=3)
        local cnx = nameStartX
        local cny = nameStartY + customRow * (nameH + nameGap)
        local cnw = nameGridW  -- 跨满两列
        local selected = (profileState.selectedName == CUSTOM_NAME_IDX)

        nvgBeginPath(vg); nvgRoundedRect(vg, cnx, cny, cnw, nameH, 5)
        if selected then
            local selGrad = nvgLinearGradient(vg, cnx, cny, cnx, cny + nameH,
                nvgRGBA(60, 50, 25, 200), nvgRGBA(40, 35, 15, 200))
            nvgFillPaint(vg, selGrad); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(35, 40, 55, 150)); nvgFill(vg)
        end

        nvgBeginPath(vg); nvgRoundedRect(vg, cnx, cny, cnw, nameH, 5)
        nvgStrokeColor(vg, selected and nvgRGBA(255, 220, 100, 180) or nvgRGBA(100, 85, 55, 120))
        nvgStrokeWidth(vg, selected and 1.5 or 0.8); nvgStroke(vg)

        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if selected and #profileState.customName > 0 then
            local cursor = (math.floor(t * 2) % 2 == 0) and "|" or ""
            DrawWhiteInkText(cnx + cnw / 2, cny + nameH / 2, profileState.customName .. cursor)
        elseif selected and profileState.isInputActive then
            local cursor = (math.floor(t * 2) % 2 == 0) and "|" or ""
            DrawWhiteInkText(cnx + cnw / 2, cny + nameH / 2, "请输入名字" .. cursor)
        else
            DrawWhiteInkText(cnx + cnw / 2, cny + nameH / 2, "自定义名字")
        end

        profileNameRects[CUSTOM_NAME_IDX] = { x = cnx, y = cny, w = cnw, h = nameH }
    end

    -- ===========================
    -- 确认按钮 (右栏底部)
    -- ===========================
    local confirmW = rightW * 0.65
    local confirmH = 44
    local confirmX = rightCx - confirmW / 2
    local confirmY = nameStartY + 4 * (nameH + nameGap) + 24
    -- 安全限制：确保不超出设计高度
    if confirmY + confirmH > H - 20 then
        confirmY = H - 20 - confirmH
    end
    local bPulse = 0.7 + 0.3 * math.sin(t * 2.5)

    -- 外发光
    local confirmGlow = nvgRadialGradient(vg,
        confirmX + confirmW / 2, confirmY + confirmH / 2,
        confirmW * 0.2, confirmW * 0.6,
        nvgRGBA(200, 170, 80, math.floor(40 * bPulse)), nvgRGBA(200, 170, 80, 0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, confirmX - 15, confirmY - 8, confirmW + 30, confirmH + 16, 20)
    nvgFillPaint(vg, confirmGlow); nvgFill(vg)

    -- 铜色边框
    nvgBeginPath(vg)
    nvgRoundedRect(vg, confirmX - 1.5, confirmY - 1.5, confirmW + 3, confirmH + 3, 7)
    nvgFillColor(vg, nvgRGBA(90, 45, 55, math.floor(190 * bPulse))); nvgFill(vg)

    -- 深色底
    local btnGrad = nvgLinearGradient(vg, confirmX, confirmY, confirmX, confirmY + confirmH,
        nvgRGBA(25, 32, 50, 180), nvgRGBA(15, 18, 30, 180))
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, confirmY, confirmW, confirmH, 5)
    nvgFillPaint(vg, btnGrad); nvgFill(vg)

    -- 内描边
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX + 1, confirmY + 1, confirmW - 2, confirmH - 2, 4)
    nvgStrokeWidth(vg, 0.8)
    nvgStrokeColor(vg, nvgRGBA(180, 148, 88, math.floor(80 * bPulse))); nvgStroke(vg)

    -- 确认文字
    nvgFontSize(vg, 32)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 80))
    nvgText(vg, confirmX + confirmW / 2 + 1, confirmY + confirmH / 2 + 1, "踏入讨伐", nil)
    nvgFillColor(vg, nvgRGBA(200, 180, 190, math.floor(200 + 55 * bPulse)))
    nvgText(vg, confirmX + confirmW / 2, confirmY + confirmH / 2, "踏入讨伐", nil)

    profileConfirmBtnRect = { x = confirmX, y = confirmY, w = confirmW, h = confirmH }

    -- 底部提示 (居中)
    nvgFontFaceId(vg, fontId)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(180, 165, 130, 160))
    nvgText(vg, cx, H - 32, "首次加载较慢，请耐心等待资源刷新", nil)
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(255, 200, 80, 140))
    nvgText(vg, cx, H - 16, "华为个别机型可能存在兼容性问题，敬请谅解", nil)

    -- ===========================
    -- 7. 漂浮粒子
    -- ===========================
    for i = 1, 6 do
        local px = W * (0.1 + 0.8 * ((i * 127 + math.floor(t * 18)) % 100) / 100)
        local py = H * (0.04 + 0.12 * math.sin(t * 0.5 + i * 1.5))
        local pr = 1.2 + math.sin(t * 1.8 + i) * 0.6
        local pa = math.floor(30 + 22 * math.sin(t * 1.3 + i * 0.8))
        nvgBeginPath(vg); nvgCircle(vg, px, py, pr)
        nvgFillColor(vg, nvgRGBA(200, 215, 245, pa)); nvgFill(vg)
    end
end


-- ============================================================================
-- 兵甲图录界面 (重制版)
-- ============================================================================
function DrawEquipCodexScreen()
    if gameState.phase ~= "EQUIP_CODEX" then return end
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime

    -- 统一菜单背景
    DrawCodexBg(W, H)

    nvgFontFaceId(vg, GetMainFont())

    -- ========== 顶部栏（渐变底条 + 装饰线） ==========
    local topBarH = 52
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, topBarH)
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, topBarH,
        nvgRGBA(18, 15, 28, 200), nvgRGBA(25, 22, 35, 160))
    nvgFillPaint(vg, topGrad); nvgFill(vg)
    -- 底部金色渐变线
    nvgBeginPath(vg); nvgMoveTo(vg, 30, topBarH); nvgLineTo(vg, W - 30, topBarH)
    local lineGrad = nvgLinearGradient(vg, 30, topBarH, W - 30, topBarH,
        nvgRGBA(180, 150, 80, 0), nvgRGBA(220, 185, 100, 120))
    nvgStrokePaint(vg, lineGrad); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    local lineGradL = nvgLinearGradient(vg, 30, topBarH, W / 2, topBarH,
        nvgRGBA(220, 185, 100, 120), nvgRGBA(220, 185, 100, 0))
    nvgBeginPath(vg); nvgMoveTo(vg, 30, topBarH); nvgLineTo(vg, cx, topBarH)
    nvgStrokePaint(vg, lineGradL); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 返回按钮
    local backW, backH = 90, 36
    local backX, backY = 10, 8
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    local backGrad = nvgLinearGradient(vg, backX, backY, backX, backY + backH,
        nvgRGBA(65, 55, 80, 220), nvgRGBA(45, 38, 60, 220))
    nvgFillPaint(vg, backGrad); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(140, 115, 80, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    equipCodexBackBtnRect = { x = backX, y = backY, w = backW, h = backH }

    -- 标题（居中，金色描边）
    nvgFontSize(vg, 38); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local titleCY = topBarH / 2
    -- 金色描边
    local goldOffsets = {{-1,-1},{1,-1},{-1,1},{1,1},{0,-1},{0,1},{-1,0},{1,0}}
    nvgFillColor(vg, nvgRGBA(180, 150, 80, 120))
    for _, off in ipairs(goldOffsets) do
        _nvgTextOrig(vg, cx + off[1], titleCY + off[2], "兵甲图录", nil)
    end
    nvgFillColor(vg, nvgRGBA(255, 245, 225, 245))
    _nvgTextOrig(vg, cx, titleCY, "兵甲图录", nil)

    -- ========== 套装选择标签（横向滚动风格，每行4个） ==========
    local tabY = topBarH + 10
    local tabCols = 4
    local tabGap = 6
    local tabPad = 10
    local tabW = (W - tabPad * 2 - (tabCols - 1) * tabGap) / tabCols
    local tabH = 34
    equipCodexSetRects = {}

    -- 统计每个套装的收集进度
    local function countSetOwned(setIdx)
        local owned = 0
        local slots = {}
        for _, item in ipairs(playerEquipment.owned) do
            if item.setIdx == setIdx and not slots[item.slotIdx] then
                slots[item.slotIdx] = true
                owned = owned + 1
            end
        end
        return owned
    end

    for si = 1, #EQUIPMENT_SETS do
        local col = (si - 1) % tabCols
        local row = math.floor((si - 1) / tabCols)
        local tx = tabPad + col * (tabW + tabGap)
        local ty = tabY + row * (tabH + 6)
        local isSel = (equipCodexState.selectedSet == si)
        local sc = EQUIPMENT_SETS[si].color
        local ownedCount = countSetOwned(si)

        nvgBeginPath(vg); nvgRoundedRect(vg, tx, ty, tabW, tabH, 5)
        if isSel then
            -- 选中：套装主色渐变填充
            local selGrad = nvgLinearGradient(vg, tx, ty, tx, ty + tabH,
                nvgRGBA(sc[1], sc[2], sc[3], 80), nvgRGBA(sc[1], sc[2], sc[3], 40))
            nvgFillPaint(vg, selGrad); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 200))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        else
            nvgFillColor(vg, nvgRGBA(25, 22, 38, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(70, 65, 55, 80))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        end

        -- 套装名
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isSel then
            nvgFillColor(vg, nvgRGBA(255, 248, 230, 245))
        else
            nvgFillColor(vg, nvgRGBA(190, 185, 170, 180))
        end
        nvgText(vg, tx + tabW / 2, ty + tabH / 2 - 1, EQUIPMENT_SETS[si].name, nil)

        -- 收集进度小点（右上角）
        if ownedCount == 7 then
            -- 全收集：金色小勾
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(255, 210, 80, 230))
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgText(vg, tx + tabW - 3, ty + 2, "★", nil)
        elseif ownedCount > 0 then
            nvgFontSize(vg, 20)
            nvgFillColor(vg, nvgRGBA(200, 195, 180, 160))
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgText(vg, tx + tabW - 3, ty + 2, ownedCount .. "/7", nil)
        end

        equipCodexSetRects[si] = { x = tx, y = ty, w = tabW, h = tabH }
    end

    -- ========== 套装详情（可滚动区域） ==========
    local selSet = EQUIPMENT_SETS[equipCodexState.selectedSet]
    local tabRows = math.ceil(#EQUIPMENT_SETS / tabCols)
    local scrollStartY = tabY + tabRows * (tabH + 6) + 12

    local scrollVisibleH = H - scrollStartY - 8
    local itemW = W - 24
    local itemH2 = 92
    local itemGap = 8
    local headerH = 110
    local legendH = 90
    local contentTotalH = headerH + 7 * (itemH2 + itemGap) + legendH
    local maxScrollY = 0
    local minScrollY = math.min(0, -(contentTotalH - scrollVisibleH))

    equipCodexState.scrollY = math.max(minScrollY, math.min(maxScrollY, equipCodexState.scrollY))

    -- 裁剪
    nvgSave(vg)
    nvgScissor(vg, 0, scrollStartY, W, scrollVisibleH)

    local contentY = scrollStartY + 16 + equipCodexState.scrollY
    local sc = selSet.color

    -- 套装信息头部面板
    local hdrX, hdrW = 12, W - 24
    local hdrY = contentY
    local hdrH = headerH - 6
    nvgBeginPath(vg); nvgRoundedRect(vg, hdrX, hdrY, hdrW, hdrH, 8)
    local hdrGrad = nvgLinearGradient(vg, hdrX, hdrY, hdrX, hdrY + hdrH,
        nvgRGBA(sc[1], sc[2], sc[3], 25), nvgRGBA(20, 18, 30, 200))
    nvgFillPaint(vg, hdrGrad); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 套装名（大字，套装色）
    nvgFontSize(vg, 34); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 240))
    nvgText(vg, cx, hdrY + 22, selSet.name, nil)

    -- 主题标签
    nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local themeText = "「" .. selSet.theme .. "」"
    nvgFillColor(vg, nvgRGBA(200, 195, 180, 180))
    nvgText(vg, cx, hdrY + 46, themeText, nil)

    -- 套装效果描述
    nvgFontSize(vg, 19); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 200, 140, 200))
    nvgText(vg, cx, hdrY + 70, "套装效果: " .. selSet.setBonusDesc, nil)

    -- 收集进度条
    local ownedTotal = countSetOwned(equipCodexState.selectedSet)
    local barBgX = hdrX + 20
    local barBgW = hdrW - 40
    local barBgY = hdrY + hdrH - 18
    local barBgH = 6
    nvgBeginPath(vg); nvgRoundedRect(vg, barBgX, barBgY, barBgW, barBgH, 3)
    nvgFillColor(vg, nvgRGBA(40, 38, 50, 200)); nvgFill(vg)
    local fillW = barBgW * (ownedTotal / 7)
    if fillW > 0 then
        nvgBeginPath(vg); nvgRoundedRect(vg, barBgX, barBgY, fillW, barBgH, 3)
        local barGrad = nvgLinearGradient(vg, barBgX, barBgY, barBgX + fillW, barBgY,
            nvgRGBA(sc[1], sc[2], sc[3], 200), nvgRGBA(255, 220, 120, 200))
        nvgFillPaint(vg, barGrad); nvgFill(vg)
    end
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 195, 180, 180))
    nvgText(vg, hdrX + hdrW - 12, barBgY + barBgH / 2, ownedTotal .. "/7", nil)

    contentY = contentY + headerH

    -- ========== 7件装备卡片 ==========
    for pi = 1, 7 do
        local piece = selSet.pieces[pi]
        local ix = 12
        local iy = contentY + (pi - 1) * (itemH2 + itemGap)

        if iy + itemH2 >= scrollStartY and iy <= scrollStartY + scrollVisibleH then
            -- 检查拥有情况
            local bestTier = 0
            for _, ownedItem in ipairs(playerEquipment.owned) do
                if ownedItem.setIdx == equipCodexState.selectedSet and ownedItem.slotIdx == pi then
                    if ownedItem.tier > bestTier then bestTier = ownedItem.tier end
                end
            end

            local isOwned = bestTier > 0

            -- 卡片背景（拥有/未拥有区分）
            nvgBeginPath(vg); nvgRoundedRect(vg, ix, iy, itemW, itemH2, 8)
            if isOwned then
                local cardGrad = nvgLinearGradient(vg, ix, iy, ix, iy + itemH2,
                    nvgRGBA(35, 32, 48, 230), nvgRGBA(28, 25, 40, 240))
                nvgFillPaint(vg, cardGrad); nvgFill(vg)
                local btc = EQUIP_TIERS[bestTier].color
                -- 左侧彩色条带
                nvgBeginPath(vg); nvgRoundedRect(vg, ix, iy, 4, itemH2, 2)
                nvgFillColor(vg, nvgRGBA(btc[1], btc[2], btc[3], 200)); nvgFill(vg)
                -- 边框
                nvgBeginPath(vg); nvgRoundedRect(vg, ix, iy, itemW, itemH2, 8)
                nvgStrokeColor(vg, nvgRGBA(btc[1], btc[2], btc[3], 80))
                nvgStrokeWidth(vg, 1); nvgStroke(vg)
            else
                nvgFillColor(vg, nvgRGBA(22, 20, 32, 200)); nvgFill(vg)
                nvgBeginPath(vg); nvgRoundedRect(vg, ix, iy, itemW, itemH2, 8)
                nvgStrokeColor(vg, nvgRGBA(50, 48, 42, 80))
                nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            end

            -- 装备图标
            local iconSize = itemH2 - 16
            local iconX = ix + 10
            local iconY2 = iy + 8
            if IMG.equipmentSheet and IMG.equipmentSheet > 0 then
                nvgSave(vg)
                if not isOwned then nvgGlobalAlpha(vg, 0.25) end
                if isOwned then
                    DrawEquipTierBg(iconX - 2, iconY2 - 2, iconSize + 4, iconSize + 4, bestTier, 5)
                end
                DrawCardImage(iconX, iconY2, iconSize, iconSize,
                    IMG.equipmentSheet, pi - 1, equipCodexState.selectedSet - 1,
                    EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
                nvgRestore(vg)
            end

            -- 文本区域
            local textX = iconX + iconSize + 14
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

            -- 装备名（阶级颜色 or 灰色）
            nvgFontSize(vg, 26)
            if isOwned then
                local btc = EQUIP_TIERS[bestTier].color
                nvgFillColor(vg, nvgRGBA(btc[1], btc[2], btc[3], 245))
            else
                nvgFillColor(vg, nvgRGBA(130, 125, 115, 120))
            end
            nvgText(vg, textX, iy + 20, piece.name, nil)

            -- 槽位（套装色）
            nvgFontSize(vg, 20)
            nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], isOwned and 160 or 80))
            nvgText(vg, textX, iy + 42, EQUIP_SLOT_NAMES[pi], nil)

            -- 属性 (简洁格式)
            nvgFontSize(vg, 18)
            local attrAlpha = isOwned and 180 or 100
            nvgFillColor(vg, nvgRGBA(180, 175, 160, attrAlpha))
            local codexParts = {}
            for _, sd in ipairs(EQUIP_STAT_DEFS) do
                local base = piece[sd.key] or 0
                if base > 0 then
                    table.insert(codexParts, string.format("%s+%d%%", sd.label, base))
                end
            end
            local attrStr = table.concat(codexParts, "  ")
            nvgText(vg, textX, iy + 64, attrStr, nil)

            -- 右侧状态标签
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            if isOwned then
                local btc = EQUIP_TIERS[bestTier].color
                -- 阶级标签背景
                local tagText = EQUIP_TIERS[bestTier].name
                local tagW = 56
                local tagH2 = 24
                local tagX = ix + itemW - 10 - tagW
                local tagY = iy + itemH2 / 2 - tagH2 / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, tagX, tagY, tagW, tagH2, 4)
                nvgFillColor(vg, nvgRGBA(btc[1], btc[2], btc[3], 30)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(btc[1], btc[2], btc[3], 100))
                nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                nvgFontSize(vg, 20)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(btc[1], btc[2], btc[3], 240))
                nvgText(vg, tagX + tagW / 2, tagY + tagH2 / 2, tagText, nil)
            else
                nvgFontSize(vg, 20)
                nvgFillColor(vg, nvgRGBA(90, 85, 75, 120))
                nvgText(vg, ix + itemW - 12, iy + itemH2 / 2, "未获得", nil)
            end
        end
    end

    -- ========== 底部阶级说明 ==========
    local legendY = contentY + 7 * (itemH2 + itemGap) + 12
    if legendY + 60 >= scrollStartY and legendY <= scrollStartY + scrollVisibleH then
        -- 分隔线
        nvgBeginPath(vg); nvgMoveTo(vg, 40, legendY - 4); nvgLineTo(vg, W - 40, legendY - 4)
        local sepGrad = nvgLinearGradient(vg, 40, legendY, W - 40, legendY,
            nvgRGBA(140, 120, 80, 0), nvgRGBA(140, 120, 80, 60))
        nvgStrokePaint(vg, sepGrad); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        local sepGradR = nvgLinearGradient(vg, cx, legendY, W - 40, legendY,
            nvgRGBA(140, 120, 80, 60), nvgRGBA(140, 120, 80, 0))
        nvgBeginPath(vg); nvgMoveTo(vg, cx, legendY - 4); nvgLineTo(vg, W - 40, legendY - 4)
        nvgStrokePaint(vg, sepGradR); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 170, 150, 160))
        nvgText(vg, cx, legendY + 8, "- 阶级倍率 -", nil)
        legendY = legendY + 26
        local legendColW = W / 3
        for ti = 1, #EQUIP_TIERS do
            local col = (ti - 1) % 3
            local row = math.floor((ti - 1) / 3)
            local lx = col * legendColW + legendColW / 2
            local ly = legendY + row * 22
            local tc = EQUIP_TIERS[ti].color
            nvgFontSize(vg, 20)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 220))
            nvgText(vg, lx, ly, EQUIP_TIERS[ti].name .. " x" .. string.format("%.1f", EQUIP_TIERS[ti].multiplier), nil)
        end
    end

    nvgRestore(vg)

    -- ========== 滚动条 ==========
    if contentTotalH > scrollVisibleH then
        local barW = 4
        local barX = W - barW - 3
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, scrollStartY, barW, scrollVisibleH, 2)
        nvgFillColor(vg, nvgRGBA(50, 48, 60, 60)); nvgFill(vg)
        local scrollBarH = math.max(24, scrollVisibleH * scrollVisibleH / contentTotalH)
        local scrollRange = scrollVisibleH - scrollBarH
        local scrollRatio = minScrollY ~= 0 and (equipCodexState.scrollY / minScrollY) or 0
        local scrollBarY = scrollStartY + scrollRatio * scrollRange
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, scrollBarY, barW, scrollBarH, 2)
        local barGrad2 = nvgLinearGradient(vg, barX, scrollBarY, barX, scrollBarY + scrollBarH,
            nvgRGBA(180, 160, 120, 140), nvgRGBA(140, 125, 90, 100))
        nvgFillPaint(vg, barGrad2); nvgFill(vg)
    end
end
