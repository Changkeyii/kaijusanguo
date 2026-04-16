-- ui/social_trade.lua - 三国武灵录 (从 social.lua 拆分)
function DrawTradeScreen()
    local W, H = DESIGN_W, DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer or 0
    DrawSocialBg(W, H)
    nvgFontFaceId(vg, GetMainFont())
    tradeState.btnRects = {}

    -- 返回按钮
    local backW, backH = 100, 44
    local backX, backY = 10, 10
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, backY, backW, backH, 6)
    nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 29); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, backY + backH / 2, "< 返回")
    tradeState.btnRects.back = { x = backX, y = backY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 30); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, 32, "交易行")

    -- 虎符显示
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    nvgText(vg, W - 14, 32, "虎符: " .. tostring(playerInfo.jade or 0), nil)

    -- Tab 栏
    local pad = 14
    local tabY = 58
    local tabH = 36
    local tabs = { { id = "market", label = "市场" }, { id = "mine", label = "我的上架" } }
    local tabW = (W - pad * 2) / #tabs
    for i, tb in ipairs(tabs) do
        local tx = pad + (i - 1) * tabW
        local sel = (tradeState.tab == tb.id)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx + 2, tabY, tabW - 4, tabH, 6)
        nvgFillColor(vg, sel and nvgRGBA(90, 60, 30, 220) or nvgRGBA(30, 30, 40, 180)); nvgFill(vg)
        if sel then nvgStrokeColor(vg, nvgRGBA(255, 180, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg) end
        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, sel and nvgRGBA(255, 220, 100, 255) or nvgRGBA(180, 180, 180, 200))
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, tb.label, nil)
        tradeState.btnRects["tab" .. (tb.id:sub(1, 1):upper()) .. tb.id:sub(2)] = { x = tx + 2, y = tabY, w = tabW - 4, h = tabH }
    end

    local bodyTop = tabY + tabH + 10
    local bodyH = H - bodyTop - 10

    -- ======== 市场 Tab ========
    if tradeState.tab == "market" then
        -- 刷新按钮
        local rfW, rfH = 80, 32
        local rfX = W - pad - rfW
        local rfY = bodyTop
        nvgBeginPath(vg); nvgRoundedRect(vg, rfX, rfY, rfW, rfH, 6)
        local isLoading = TradeManager.state.marketLoading
        nvgFillColor(vg, isLoading and nvgRGBA(40, 40, 50, 180) or nvgRGBA(50, 80, 120, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 140, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 220, 255, isLoading and 120 or 255))
        nvgText(vg, rfX + rfW / 2, rfY + rfH / 2, isLoading and "加载中" or "刷新", nil)
        tradeState.btnRects.refresh = { x = rfX, y = rfY, w = rfW, h = rfH }

        -- 规则提示
        nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 200))
        nvgText(vg, pad, rfY + rfH / 2, "交易规则: 将品及以上可交易 · 手续费5% · 上架3天", nil)

        local listTop = rfY + rfH + 8
        local listH = H - listTop - 10

        -- 裁剪
        nvgSave(vg)
        nvgScissor(vg, 0, listTop, W, listH)

        -- 过滤已购买的物品
        local allItems = TradeManager.state.marketItems or {}
        local myPurchases = TradeManager.state.myPurchases or {}
        local items = {}
        for _, it in ipairs(allItems) do
            if not myPurchases[it.listingKey] then
                items[#items + 1] = it
            end
        end
        tradeState._filteredMarketItems = items  -- 供点击使用

        if #items == 0 then
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(140, 140, 140, 200))
            local emptyText = TradeManager.state.marketLoaded and "暂无在售装备" or "点击刷新加载市场"
            nvgText(vg, cx, listTop + listH / 2, emptyText, nil)
        else
            -- 方格布局 (与上架列表一致)
            local gridW = W - pad * 2
            local mCellGap = 6
            local mGridCols = 5
            local mCellSize = math.floor((gridW - mCellGap * (mGridCols - 1)) / mGridCols)
            local gridX = pad
            local scrollOff = tradeState.scroll.offset or 0
            local totalRows = math.ceil(#items / mGridCols)
            local infoH = 42  -- 底部信息区：装备名+价格+卖家
            local fullCellH = mCellSize + infoH

            for i, item in ipairs(items) do
                local row = math.floor((i - 1) / mGridCols)
                local col = (i - 1) % mGridCols
                local cellX = gridX + col * (mCellSize + mCellGap)
                local cellY = listTop + row * (fullCellH + mCellGap) - scrollOff

                if cellY + fullCellH > listTop - 10 and cellY < listTop + listH + 10 then
                    local eq = item.equip
                    local tierData = EQUIP_TIERS[eq.tier] or EQUIP_TIERS[1]
                    local tc = tierData.color

                    -- 格子底板 + 品阶渐变
                    nvgBeginPath(vg); nvgRoundedRect(vg, cellX, cellY, mCellSize, mCellSize, 6)
                    local grad = nvgLinearGradient(vg, cellX, cellY, cellX, cellY + mCellSize,
                        nvgRGBA(tc[1], tc[2], tc[3], 22), nvgRGBA(25, 22, 18, 235))
                    nvgFillPaint(vg, grad); nvgFill(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, cellX, cellY, mCellSize, mCellSize, 6)
                    nvgFillColor(vg, nvgRGBA(30, 28, 22, 140)); nvgFill(vg)

                    -- 边框
                    nvgBeginPath(vg); nvgRoundedRect(vg, cellX + 0.5, cellY + 0.5, mCellSize - 1, mCellSize - 1, 5.5)
                    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

                    -- 装备图标
                    local iconPad = 6
                    local iconSize = mCellSize - iconPad * 2
                    if IMG.equipmentSheet and IMG.equipmentSheet > 0 then
                        local imgW, imgH = nvgImageSize(vg, IMG.equipmentSheet)
                        if imgW > 4 and imgH > 4 then
                            DrawEquipTierBg(cellX + iconPad - 2, cellY + iconPad - 2, iconSize + 4, iconSize + 4, eq.tier or 1, 4)
                            DrawCardImage(cellX + iconPad, cellY + iconPad, iconSize, iconSize,
                                IMG.equipmentSheet, eq.slotIdx - 1, eq.setIdx - 1,
                                EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
                        end
                    end

                    -- 品阶角标
                    local tierName = EQUIP_TIER_NAMES[eq.tier] or "?"
                    local badgeW, badgeH = 28, 14
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, cellX + mCellSize - badgeW - 2, cellY + 2, badgeW, badgeH, 3)
                    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180)); nvgFill(vg)
                    nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
                    nvgText(vg, cellX + mCellSize - badgeW / 2 - 2, cellY + 2 + badgeH / 2, tierName, nil)

                    -- 等级+强化角标 (右上角, 与装备仓库一致: Lv.X+Y)
                    local lvStr = "Lv." .. (eq.level or 1)
                    if (eq.enhanceLv or 0) > 0 then lvStr = lvStr .. "+" .. eq.enhanceLv end
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFontSize(vg, 11)
                    nvgFillColor(vg, nvgRGBA(255, 225, 130, 220))
                    nvgText(vg, cellX + 3, cellY + 3, lvStr, nil)

                    -- 底部信息区: 装备名+价格
                    local infoY = cellY + mCellSize
                    local setData = EQUIPMENT_SETS[eq.setIdx]
                    local pieceName = setData and setData.pieces[eq.slotIdx] and setData.pieces[eq.slotIdx].name or "?"
                    -- 装备名（品阶色）
                    nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
                    local shortPiece = pieceName
                    if utf8.len(shortPiece) > 4 then shortPiece = string.sub(shortPiece, 1, utf8.offset(shortPiece, 5) - 1) .. ".." end
                    nvgText(vg, cellX + mCellSize / 2, infoY + 8, shortPiece, nil)
                    -- 价格
                    nvgFontSize(vg, 11); nvgFillColor(vg, nvgRGBA(255, 220, 100, 240))
                    nvgText(vg, cellX + mCellSize / 2, infoY + 20, tostring(item.price) .. "符", nil)
                    -- 卖家名
                    nvgFontSize(vg, 9); nvgFillColor(vg, nvgRGBA(140, 180, 200, 160))
                    local sName = item.sellerName or ""
                    if utf8.len(sName) > 5 then sName = string.sub(sName, 1, utf8.offset(sName, 6) - 1) .. ".." end
                    nvgText(vg, cellX + mCellSize / 2, infoY + 34, sName, nil)
                end
                -- 点击区域
                tradeState.btnRects["market_" .. i] = { x = cellX, y = listTop + math.floor((i - 1) / mGridCols) * (fullCellH + mCellGap) - scrollOff, w = mCellSize, h = fullCellH }
            end
            -- 更新最大滚动
            local contentH = totalRows * (fullCellH + mCellGap)
            if scrollOff > math.max(0, contentH - listH) then
                tradeState.scroll.offset = math.max(0, contentH - listH)
            end
        end

        nvgRestore(vg)

    -- ======== 我的上架 Tab ========
    elseif tradeState.tab == "mine" then
        local scrollOff = tradeState.scroll.offset or 0
        local curY = bodyTop - scrollOff

        -- 待领取虎符
        local pendingJade = TradeManager.state.myData.pendingJade or 0
        local soldCount = TradeManager.state.myData.soldCount or 0
        nvgBeginPath(vg); nvgRoundedRect(vg, pad, curY, W - pad * 2, 50, 8)
        nvgFillColor(vg, nvgRGBA(40, 35, 25, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 140, 50, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
        nvgText(vg, pad + 10, curY + 16, "待领取: " .. pendingJade .. " 虎符", nil)
        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(160, 160, 160, 180))
        nvgText(vg, pad + 10, curY + 36, "累计售出: " .. soldCount .. "件", nil)

        if pendingJade > 0 then
            local cjW, cjH = 70, 32
            local cjX = W - pad - cjW - 8
            local cjY = curY + 9
            nvgBeginPath(vg); nvgRoundedRect(vg, cjX, cjY, cjW, cjH, 6)
            nvgFillColor(vg, nvgRGBA(180, 120, 30, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, cjX + cjW / 2, cjY + cjH / 2, "领取", nil)
            tradeState.btnRects.claimJade = { x = cjX, y = cjY, w = cjW, h = cjH }
        end

        curY = curY + 58

        -- 在售装备
        local active = TradeManager.GetActiveListings()
        if #active > 0 then
            nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 200))
            nvgText(vg, pad, curY + 10, "在售 (" .. #active .. "/" .. GameConfig.TRADE.MAX_LISTINGS .. ")", nil)
            curY = curY + 28
            local cardH = 92
            local cardGap = 6
            for i, al in ipairs(active) do
                local cy = curY + (i - 1) * (cardH + cardGap)
                if cy + cardH > bodyTop - 10 and cy < bodyTop + bodyH + 10 then
                    DrawTradeCard(pad, cy, W - pad * 2, cardH, {
                        equip = al.listing.equip,
                        price = al.listing.price,
                        sellerName = "我",
                        remainSec = al.remainSec,
                    }, i, true)
                end
                local btnW = 52
                tradeState.btnRects["unlist_" .. i] = { x = W - pad - btnW - 6, y = cy + 6, w = btnW, h = cardH - 12 }
            end
            curY = curY + #active * (cardH + cardGap)
        else
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(140, 140, 140, 180))
            nvgText(vg, pad, curY + 10, "暂无在售装备", nil)
            curY = curY + 30
        end

        -- 过期装备
        local expired = TradeManager.GetExpiredListings()
        if #expired > 0 then
            curY = curY + 6
            nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 120, 80, 200))
            nvgText(vg, pad, curY + 10, "已过期 (" .. #expired .. "件, 点击领回)", nil)
            curY = curY + 28
            local cardH = 60
            local cardGap = 4
            for i, ek in ipairs(expired) do
                local listing = TradeManager.state.myData.listings[ek]
                if listing then
                    local cy = curY + (i - 1) * (cardH + cardGap)
                    if cy + cardH > bodyTop - 10 and cy < bodyTop + bodyH + 10 then
                        local eq = listing.equip
                        local tierData = EQUIP_TIERS[eq.tier] or EQUIP_TIERS[1]
                        local tc = tierData.color
                        local setData = EQUIPMENT_SETS[eq.setIdx]
                        local pieceName = setData and setData.pieces[eq.slotIdx] and setData.pieces[eq.slotIdx].name or "未知"

                        nvgBeginPath(vg); nvgRoundedRect(vg, pad, cy, W - pad * 2, cardH, 8)
                        nvgFillColor(vg, nvgRGBA(50, 30, 30, 200)); nvgFill(vg)
                        nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

                        nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 255))
                        nvgText(vg, pad + 10, cy + 18, EQUIP_TIER_NAMES[eq.tier] .. " " .. pieceName, nil)
                        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(180, 180, 180, 180))
                        nvgText(vg, pad + 10, cy + 40, "原价 " .. listing.price .. " 虎符 · 已过期", nil)

                        -- 领回按钮
                        local btnW = 52
                        local btnX = W - pad - btnW - 6
                        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, cy + 10, btnW, cardH - 20, 6)
                        nvgFillColor(vg, nvgRGBA(120, 70, 30, 220)); nvgFill(vg)
                        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(255, 220, 150, 255))
                        nvgText(vg, btnX + btnW / 2, cy + cardH / 2, "领回", nil)
                    end
                    tradeState.btnRects["claim_" .. i] = { x = W - pad - 52 - 6, y = curY + (i - 1) * (cardH + cardGap) + 10, w = 52, h = cardH - 20 }
                end
            end
        end

        -- ======== 分割线 + 可交易物品 (方格展示) ========
        curY = curY + 16
        nvgBeginPath(vg)
        nvgMoveTo(vg, pad, curY)
        nvgLineTo(vg, W - pad, curY)
        nvgStrokeColor(vg, nvgRGBA(120, 100, 60, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        curY = curY + 10

        -- 小标题
        nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 220))
        nvgText(vg, pad, curY + 10, "可交易装备 (将品及以上)", nil)
        curY = curY + 30

        -- 收集可交易装备: tier >= 4 且未装备
        local tradeableItems = {}
        for _, item in ipairs(playerEquipment.owned) do
            if (item.tier or 0) >= 4 then
                local isEquipped = false
                for _, eqUid in pairs(playerEquipment.equipped) do
                    if eqUid == item.uid then isEquipped = true; break end
                end
                if not isEquipped then
                    tradeableItems[#tradeableItems + 1] = item
                end
            end
        end

        if #tradeableItems == 0 then
            nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(120, 120, 120, 160))
            nvgText(vg, pad, curY + 10, "暂无可交易装备", nil)
            curY = curY + 30
        else
            -- 方格布局
            local gridW = W - pad * 2
            local tCellGap = 6
            local tGridCols = 5
            local tCellSize = math.floor((gridW - tCellGap * (tGridCols - 1)) / tGridCols)
            local gridX = pad

            local tInfoH = 26  -- 底部信息区高度(装备名+等级)
            local tFullCellH = tCellSize + tInfoH

            for i, item in ipairs(tradeableItems) do
                local row = math.floor((i - 1) / tGridCols)
                local col = (i - 1) % tGridCols
                local cx2 = gridX + col * (tCellSize + tCellGap)
                local cy2 = curY + row * (tFullCellH + tCellGap)

                local tierData = EQUIP_TIERS[item.tier] or EQUIP_TIERS[1]
                local tc = tierData.color

                -- 格子底板 + 品阶渐变
                nvgBeginPath(vg); nvgRoundedRect(vg, cx2, cy2, tCellSize, tCellSize, 6)
                local grad = nvgLinearGradient(vg, cx2, cy2, cx2, cy2 + tCellSize,
                    nvgRGBA(tc[1], tc[2], tc[3], 22), nvgRGBA(25, 22, 18, 235))
                nvgFillPaint(vg, grad); nvgFill(vg)
                nvgBeginPath(vg); nvgRoundedRect(vg, cx2, cy2, tCellSize, tCellSize, 6)
                nvgFillColor(vg, nvgRGBA(30, 28, 22, 140)); nvgFill(vg)

                -- 边框
                nvgBeginPath(vg); nvgRoundedRect(vg, cx2 + 0.5, cy2 + 0.5, tCellSize - 1, tCellSize - 1, 5.5)
                nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

                -- 装备图标
                local iconPad = 6
                local iconSize = tCellSize - iconPad * 2
                if IMG.equipmentSheet and IMG.equipmentSheet > 0 then
                    local imgW, imgH = nvgImageSize(vg, IMG.equipmentSheet)
                    if imgW > 4 and imgH > 4 then
                        DrawEquipTierBg(cx2 + iconPad - 2, cy2 + iconPad - 2, iconSize + 4, iconSize + 4, item.tier or 1, 4)
                        DrawCardImage(cx2 + iconPad, cy2 + iconPad, iconSize, iconSize,
                            IMG.equipmentSheet, item.slotIdx - 1, item.setIdx - 1,
                            EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
                    end
                end

                -- 品阶角标
                local tierName = EQUIP_TIER_NAMES[item.tier] or "?"
                local badgeW, badgeH = 28, 14
                nvgBeginPath(vg)
                nvgRoundedRect(vg, cx2 + tCellSize - badgeW - 2, cy2 + 2, badgeW, badgeH, 3)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180)); nvgFill(vg)
                nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
                nvgText(vg, cx2 + tCellSize - badgeW / 2 - 2, cy2 + 2 + badgeH / 2, tierName, nil)

                -- 强化角标
                if (item.enhanceLv or 0) > 0 then
                    nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, nvgRGBA(255, 220, 100, 220))
                    nvgText(vg, cx2 + 3, cy2 + 3, "+" .. item.enhanceLv, nil)
                end

                -- 底部信息区: 装备名+等级
                local infoY2 = cy2 + tCellSize
                local setData2 = EQUIPMENT_SETS[item.setIdx]
                local pieceName2 = setData2 and setData2.pieces[item.slotIdx] and setData2.pieces[item.slotIdx].name or "?"
                nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
                local shortP2 = pieceName2
                if utf8.len(shortP2) > 4 then shortP2 = string.sub(shortP2, 1, utf8.offset(shortP2, 5) - 1) .. ".." end
                nvgText(vg, cx2 + tCellSize / 2, infoY2 + 7, shortP2, nil)
                -- 强化+等级
                local lvP2 = {}
                if (item.enhanceLv or 0) > 0 then lvP2[#lvP2 + 1] = "强+" .. item.enhanceLv end
                lvP2[#lvP2 + 1] = "Lv" .. (item.level or 1)
                nvgFontSize(vg, 9); nvgFillColor(vg, nvgRGBA(120, 220, 255, 210))
                nvgText(vg, cx2 + tCellSize / 2, infoY2 + 18, table.concat(lvP2, " "), nil)

                -- 保存格子rect用于点击
                tradeState.btnRects["list_" .. i] = { x = cx2, y = cy2, w = tCellSize, h = tFullCellH }
            end
            local totalRows = math.ceil(#tradeableItems / tGridCols)
            curY = curY + totalRows * (tFullCellH + tCellGap)
        end

        -- 保存可交易物品引用供点击使用
        tradeState.tradeableItems = tradeableItems
    end

    -- ======== 确认弹窗 ========
    if tradeState.confirmPopup then
        local pop = tradeState.confirmPopup
        -- 半透明遮罩
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)

        if pop.type == "list_item" then
            -- ======== 上架定价弹窗 (含价格 +/-) ========
            local d = pop.data
            local pw2, ph2 = 380, 300
            local px2 = (W - pw2) / 2
            local py2 = (H - ph2) / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, px2, py2, pw2, ph2, 14)
            nvgFillColor(vg, nvgRGBA(25, 22, 18, 245)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 160, 60, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
            tradeState.btnRects.popupBg = { x = px2, y = py2, w = pw2, h = ph2 }

            -- 标题
            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
            nvgText(vg, cx, py2 + 28, "上架交易行", nil)

            -- 装备名称
            local tierData2 = EQUIP_TIERS[d.tier] or EQUIP_TIERS[1]
            local tc2 = tierData2.color
            local setData2 = EQUIPMENT_SETS[d.setIdx]
            local pieceName2 = setData2 and setData2.pieces[d.slotIdx] and setData2.pieces[d.slotIdx].name or "装备"
            local tierName2 = EQUIP_TIER_NAMES[d.tier] or "?"
            nvgFontSize(vg, 20); nvgFillColor(vg, nvgRGBA(tc2[1], tc2[2], tc2[3], 255))
            nvgText(vg, cx, py2 + 58, tierName2 .. " " .. pieceName2, nil)

            -- 品质信息
            nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(180, 180, 180, 180))
            local info2 = "品质" .. (d.quality or 0) .. " · Lv" .. (d.level or 1)
            if (d.enhanceLv or 0) > 0 then info2 = info2 .. " · 强化+" .. d.enhanceLv end
            nvgText(vg, cx, py2 + 80, info2, nil)

            -- 手续费提示
            nvgFontSize(vg, 13); nvgFillColor(vg, nvgRGBA(200, 180, 120, 160))
            local commPct = math.floor(GameConfig.TRADE.COMMISSION * 100)
            nvgText(vg, cx, py2 + 100, "交易行抽成" .. commPct .. "% · 上架3天", nil)

            -- 价格区域
            local priceY = py2 + 125
            nvgFontSize(vg, 15); nvgFillColor(vg, nvgRGBA(180, 180, 180, 200))
            nvgText(vg, cx, priceY, "价格范围: " .. d.minPrice .. " ~ " .. d.maxPrice, nil)

            -- [-] 价格 [+]
            local priceRowY = priceY + 24
            local adjBtnW, adjBtnH = 44, 36
            local minusX2 = cx - 100
            local plusX2 = cx + 100 - adjBtnW
            -- 减
            nvgBeginPath(vg); nvgRoundedRect(vg, minusX2, priceRowY, adjBtnW, adjBtnH, 6)
            nvgFillColor(vg, nvgRGBA(80, 50, 30, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(160, 120, 60, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, minusX2 + adjBtnW / 2, priceRowY + adjBtnH / 2, "-", nil)
            tradeState.btnRects.priceMinus = { x = minusX2, y = priceRowY, w = adjBtnW, h = adjBtnH }
            -- 加
            nvgBeginPath(vg); nvgRoundedRect(vg, plusX2, priceRowY, adjBtnW, adjBtnH, 6)
            nvgFillColor(vg, nvgRGBA(80, 50, 30, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(160, 120, 60, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, plusX2 + adjBtnW / 2, priceRowY + adjBtnH / 2, "+", nil)
            tradeState.btnRects.pricePlus = { x = plusX2, y = priceRowY, w = adjBtnW, h = adjBtnH }
            -- 当前价格
            nvgFontSize(vg, 26); nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
            nvgText(vg, cx, priceRowY + adjBtnH / 2, tostring(d.price), nil)

            -- 到手收入
            local netIncome = TradeManager.CalcNetIncome(d.price)
            nvgFontSize(vg, 15); nvgFillColor(vg, nvgRGBA(120, 200, 120, 200))
            nvgText(vg, cx, priceRowY + adjBtnH + 16, "到手: " .. netIncome .. " 虎符", nil)

            -- 确认/取消
            local lbW, lbH = 120, 38
            local lbY = py2 + ph2 - lbH - 16; local lbGap = 20
            local lyX = cx - lbW - lbGap / 2
            local lnX = cx + lbGap / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, lyX, lbY, lbW, lbH, 8)
            nvgFillColor(vg, nvgRGBA(180, 100, 30, 230)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 180, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFontSize(vg, 18); nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, lyX + lbW / 2, lbY + lbH / 2, "确认上架", nil)
            tradeState.btnRects.popupYes = { x = lyX, y = lbY, w = lbW, h = lbH }
            nvgBeginPath(vg); nvgRoundedRect(vg, lnX, lbY, lbW, lbH, 8)
            nvgFillColor(vg, nvgRGBA(50, 50, 60, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 100, 120, 150)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 230))
            nvgText(vg, lnX + lbW / 2, lbY + lbH / 2, "取消", nil)
            tradeState.btnRects.popupNo = { x = lnX, y = lbY, w = lbW, h = lbH }
        else
            -- ======== 通用确认弹窗 (购买/下架/领回) ========
            local pw, ph = 320, 230
            local px = (W - pw) / 2
            local py = (H - ph) / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
            nvgFillColor(vg, nvgRGBA(30, 28, 35, 240)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 50, 160)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
            tradeState.btnRects.popupBg = { x = px, y = py, w = pw, h = ph }

            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))

            local popTitle = ""
            local popDesc = ""
            if pop.type == "buy" then
                local d = pop.data
                local eq = d.equip
                local tierName = EQUIP_TIER_NAMES[eq.tier] or "?"
                local setData = EQUIPMENT_SETS[eq.setIdx]
                local pieceName = setData and setData.pieces[eq.slotIdx] and setData.pieces[eq.slotIdx].name or "装备"
                popTitle = "确认购买"
                popDesc = tierName .. " " .. pieceName
                -- 计算属性加成
                local piece = setData and setData.pieces[eq.slotIdx]
                if piece then
                    local td = EQUIP_TIERS[eq.tier] or EQUIP_TIERS[1]
                    local tierMul = td.multiplier or 1.0
                    local enhMul = 1.0 + (eq.enhanceLv or 0) * ENHANCE_PERCENT_PER_LEVEL / 100
                    local qBonus = GetQualityBonus(eq.quality)
                    local lvBonus = GetLevelBonus(eq.level)
                    local atkVal = (piece.atkPct + qBonus + lvBonus) * tierMul * enhMul
                    local defVal = (piece.defPct + qBonus + lvBonus) * tierMul * enhMul
                    local hpVal  = (piece.hpPct + qBonus + lvBonus) * tierMul * enhMul
                    popDesc = popDesc .. "\n" .. string.format("攻+%.1f%%  防+%.1f%%  血+%.1f%%", atkVal, defVal, hpVal)
                end
                popDesc = popDesc .. "\n售价: " .. d.price .. " 虎符\n卖家: " .. (d.sellerName or "?")
            elseif pop.type == "unlist" then
                popTitle = "确认下架"
                local listing = pop.data.listing
                if listing then
                    local eq = listing.equip
                    local tierName = EQUIP_TIER_NAMES[eq.tier] or "?"
                    local setData = EQUIPMENT_SETS[eq.setIdx]
                    local pieceName = setData and setData.pieces[eq.slotIdx] and setData.pieces[eq.slotIdx].name or "装备"
                    popDesc = tierName .. " " .. pieceName .. "\n装备将返回仓库"
                end
            elseif pop.type == "claim_expired" then
                popTitle = "领回过期装备"
                popDesc = "装备将返回仓库"
            end

            nvgText(vg, cx, py + 30, popTitle, nil)

            -- 多行描述
            nvgFontSize(vg, 17); nvgFillColor(vg, nvgRGBA(210, 210, 210, 230))
            local descLines = {}
            for line in popDesc:gmatch("[^\n]+") do table.insert(descLines, line) end
            for li, line in ipairs(descLines) do
                nvgText(vg, cx, py + 60 + (li - 1) * 22, line, nil)
            end

            -- 确认/取消按钮
            local btnW2 = 110
            local btnH2 = 38
            local btnY2 = py + ph - btnH2 - 18
            local btnGap = 20
            local yesX = cx - btnW2 - btnGap / 2
            local noX = cx + btnGap / 2
            nvgBeginPath(vg); nvgRoundedRect(vg, yesX, btnY2, btnW2, btnH2, 8)
            nvgFillColor(vg, nvgRGBA(180, 100, 30, 230)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 180, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFontSize(vg, 19); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, yesX + btnW2 / 2, btnY2 + btnH2 / 2, "确认", nil)
            tradeState.btnRects.popupYes = { x = yesX, y = btnY2, w = btnW2, h = btnH2 }
            nvgBeginPath(vg); nvgRoundedRect(vg, noX, btnY2, btnW2, btnH2, 8)
            nvgFillColor(vg, nvgRGBA(50, 50, 60, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 100, 120, 150)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 230))
            nvgText(vg, noX + btnW2 / 2, btnY2 + btnH2 / 2, "取消", nil)
            tradeState.btnRects.popupNo = { x = noX, y = btnY2, w = btnW2, h = btnH2 }
        end
    end
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param item table {equip, price, sellerName, remainSec?, sellerId?}
---@param idx number
---@param isMine boolean
function DrawTradeCard(x, y, w, h, item, idx, isMine)
    local eq = item.equip
    local tierData = EQUIP_TIERS[eq.tier] or EQUIP_TIERS[1]
    local tc = tierData.color
    local setData = EQUIPMENT_SETS[eq.setIdx]
    local pieceName = setData and setData.pieces[eq.slotIdx] and setData.pieces[eq.slotIdx].name or "未知"
    local tierName = EQUIP_TIER_NAMES[eq.tier] or "?"
    local slotName = EQUIP_SLOT_NAMES[eq.slotIdx] or ""

    -- 卡片背景 (品阶色调)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 8)
    nvgFillColor(vg, nvgRGBA(math.floor(tc[1] * 0.15 + 20), math.floor(tc[2] * 0.15 + 18), math.floor(tc[3] * 0.15 + 22), 220))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 品阶标签
    local tagW = 42
    nvgBeginPath(vg); nvgRoundedRect(vg, x + 6, y + 6, tagW, 20, 4)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 60)); nvgFill(vg)
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 255))
    nvgText(vg, x + 6 + tagW / 2, y + 16, tierName, nil)

    -- 装备名称
    nvgFontSize(vg, 19); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 255))
    nvgText(vg, x + 6 + tagW + 8, y + 16, pieceName, nil)

    -- 槽位 + 套装名
    nvgFontSize(vg, 13); nvgFillColor(vg, nvgRGBA(160, 160, 160, 200))
    local setName = setData and setData.name or ""
    nvgText(vg, x + 10, y + 36, slotName .. " · " .. setName, nil)

    -- 强化等级 + 装备等级 (同一行)
    local infoLineX = x + 10
    if eq.enhanceLv and eq.enhanceLv > 0 then
        nvgFontSize(vg, 13); nvgFillColor(vg, nvgRGBA(120, 220, 255, 220))
        nvgText(vg, infoLineX, y + 52, "强化+" .. eq.enhanceLv, nil)
        infoLineX = infoLineX + 70
    end
    if eq.level and eq.level > 1 then
        nvgFontSize(vg, 13); nvgFillColor(vg, nvgRGBA(180, 220, 160, 200))
        nvgText(vg, infoLineX, y + 52, "Lv." .. eq.level, nil)
    end

    -- 属性加成显示
    local piece = setData and setData.pieces[eq.slotIdx]
    if piece then
        local tierMul = tierData.multiplier or 1.0
        local enhMul = 1.0 + (eq.enhanceLv or 0) * ENHANCE_PERCENT_PER_LEVEL / 100
        local qBonus = GetQualityBonus(eq.quality)
        local lvBonus = GetLevelBonus(eq.level)
        local atkVal = (piece.atkPct + qBonus + lvBonus) * tierMul * enhMul
        local defVal = (piece.defPct + qBonus + lvBonus) * tierMul * enhMul
        local hpVal  = (piece.hpPct + qBonus + lvBonus) * tierMul * enhMul
        nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 160, 80, 220))
        local attrStr = string.format("攻+%.1f%%  防+%.1f%%  血+%.1f%%", atkVal, defVal, hpVal)
        nvgText(vg, x + 10, y + 68, attrStr, nil)
    end

    -- 价格
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    local priceX = isMine and (x + w - 70) or (x + w - 80)
    nvgText(vg, priceX, y + 18, tostring(item.price), nil)
    nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(200, 180, 120, 180))
    nvgText(vg, priceX, y + 34, "虎符", nil)

    -- 剩余时间
    if item.remainSec then
        local hrs = math.floor(item.remainSec / 3600)
        local mins = math.floor((item.remainSec % 3600) / 60)
        local timeStr = hrs > 0 and (hrs .. "h" .. mins .. "m") or (mins .. "m")
        nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, hrs < 6 and nvgRGBA(255, 120, 80, 200) or nvgRGBA(140, 140, 140, 180))
        nvgText(vg, priceX, y + 50, "剩" .. timeStr, nil)
    end

    -- 卖家名 (市场模式) / 操作按钮 (我的上架)
    if isMine then
        -- 下架按钮
        local btnW = 52
        local btnX = x + w - btnW - 6
        local btnY2 = y + 6
        local btnH2 = h - 12
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY2, btnW, btnH2, 6)
        nvgFillColor(vg, nvgRGBA(80, 40, 40, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 80, 80, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 15); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 180, 160, 255))
        nvgText(vg, btnX + btnW / 2, y + h / 2, "下架", nil)
    else
        -- 卖家名
        nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 180, 200, 180))
        nvgText(vg, x + 10, y + h - 12, item.sellerName or "", nil)
        -- 购买按钮
        local buyW = 64
        local buyX = x + w - buyW - 6
        nvgBeginPath(vg); nvgRoundedRect(vg, buyX, y + 6, buyW, h - 12, 6)
        local pulse = 0.85 + 0.15 * math.sin((menuAnimTimer or 0) * 2.5 + idx)
        nvgFillColor(vg, nvgRGBA(math.floor(160 * pulse), math.floor(100 * pulse), 20, 230)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 60, math.floor(150 * pulse))); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, buyX + buyW / 2, y + h / 2, "购买", nil)
    end
end


