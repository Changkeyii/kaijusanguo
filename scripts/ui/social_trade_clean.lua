local function TradeBtn(x, y, w, h, label, active)
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 6)
    nvgFillColor(vg, active and nvgRGBA(90, 60, 30, 220) or nvgRGBA(32, 34, 44, 210)); nvgFill(vg)
    nvgStrokeColor(vg, active and nvgRGBA(255, 180, 60, 180) or nvgRGBA(110, 130, 165, 120)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE); DrawWhiteInkText(x + w / 2, y + h / 2, label)
end

function DrawTradeScreen()
    local W, H, cx, pad = DESIGN_W, DESIGN_H, DESIGN_W / 2, 14
    tradeState.btnRects = {}
    tradeState.tab = tradeState.tab or "market"
    DrawSocialBg(W, H); nvgFontFaceId(vg, GetMainFont())
    tradeState.btnRects.back = { x = 10, y = 10, w = 100, h = 44 }; TradeBtn(10, 10, 100, 44, "< 返回", false)
    DrawWhiteInkText(cx, 32, "交易")

    local tabW = (W - pad * 2) / 2
    tradeState.btnRects.tabMarket = { x = pad + 2, y = 56, w = tabW - 4, h = 36 }
    tradeState.btnRects.tabMine = { x = pad + tabW + 2, y = 56, w = tabW - 4, h = 36 }
    TradeBtn(pad + 2, 56, tabW - 4, 36, "集市", tradeState.tab == "market")
    TradeBtn(pad + tabW + 2, 56, tabW - 4, 36, "我的", tradeState.tab == "mine")
    local bodyTop = 102

    if tradeState.tab == "market" then
        tradeState.btnRects.refresh = { x = W - 94, y = bodyTop - 36, w = 80, h = 30 }
        TradeBtn(W - 94, bodyTop - 36, 80, 30, "刷新", false)
        local items = (TradeManager and TradeManager.state and TradeManager.state.marketItems) or {}
        tradeState._filteredMarketItems = items
        if TradeManager and TradeManager.state and TradeManager.state.marketLoading then DrawWhiteInkText(cx, bodyTop + 80, "加载集市中...")
        elseif #items == 0 then DrawWhiteInkText(cx, bodyTop + 80, "暂无商品")
        else
            for i, item in ipairs(items) do
                local y = bodyTop + (i - 1) * 76
                if y + 68 > H - 10 then break end
                nvgBeginPath(vg); nvgRoundedRect(vg, pad, y, W - pad * 2, 68, 8); nvgFillColor(vg, nvgRGBA(20, 25, 35, 210)); nvgFill(vg)
                nvgText(vg, pad + 12, y + 20, tostring(item.pieceName or item.name or item.listingKey or ("物品 " .. i)), nil)
                nvgText(vg, pad + 12, y + 44, "价格: " .. tostring(item.price or 0), nil)
                tradeState.btnRects["market_" .. i] = { x = pad, y = y, w = W - pad * 2, h = 68 }
            end
        end
    else
        local myData = (TradeManager and TradeManager.state and TradeManager.state.myData) or {}
        tradeState.btnRects.claimJade = { x = W - 136, y = bodyTop - 36, w = 122, h = 30 }
        TradeBtn(W - 136, bodyTop - 36, 122, 30, "提取玉璧", (myData.pendingJade or 0) > 0)
        nvgText(vg, pad, bodyTop - 20, "待提取: " .. tostring(myData.pendingJade or 0), nil)
        local active = TradeManager and TradeManager.GetActiveListings and TradeManager.GetActiveListings() or {}
        local expired = TradeManager and TradeManager.GetExpiredListings and TradeManager.GetExpiredListings() or {}
        tradeState.tradeableItems = {}
        local y = bodyTop
        for i, entry in ipairs(active) do
            if y + 60 > H - 10 then break end
            local key, listing = entry.key or ("listing_" .. i), entry.listing or entry
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, y, W - pad * 2, 56, 8); nvgFillColor(vg, nvgRGBA(20, 25, 35, 210)); nvgFill(vg)
            nvgText(vg, pad + 12, y + 20, tostring(listing.pieceName or key), nil)
            nvgText(vg, pad + 12, y + 40, "价格: " .. tostring(listing.price or 0), nil)
            tradeState.btnRects["unlist_" .. i] = { x = W - pad - 78, y = y + 13, w = 68, h = 30 }
            TradeBtn(W - pad - 78, y + 13, 68, 30, "下架", false)
            y = y + 62
        end
        for i, key in ipairs(expired) do
            if y + 60 > H - 10 then break end
            nvgBeginPath(vg); nvgRoundedRect(vg, pad, y, W - pad * 2, 56, 8); nvgFillColor(vg, nvgRGBA(30, 25, 20, 210)); nvgFill(vg)
            nvgText(vg, pad + 12, y + 30, "已过期: " .. tostring(key), nil)
            tradeState.btnRects["claim_" .. i] = { x = W - pad - 78, y = y + 13, w = 68, h = 30 }
            TradeBtn(W - pad - 78, y + 13, 68, 30, "取回", true)
            y = y + 62
        end
        if y == bodyTop then DrawWhiteInkText(cx, bodyTop + 80, "暂无上架商品") end
    end

    if not tradeState.confirmPopup then return end
    local pop = tradeState.confirmPopup
    local px, py, pw, ph = 40, H / 2 - 110, W - 80, 220
    tradeState.btnRects.popupBg = { x = px, y = py, w = pw, h = ph }
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H); nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 10); nvgFillColor(vg, nvgRGBA(28, 24, 34, 245)); nvgFill(vg)
    DrawWhiteInkText(cx, py + 28, "交易确认")
    local desc = pop.type or "操作"
    if pop.type == "list" and pop.data then desc = "上架价格: " .. tostring(pop.data.price or 0) end
    nvgText(vg, cx, py + 78, tostring(desc), nil)
    if pop.type == "list" and pop.data then
        tradeState.btnRects.priceMinus = { x = cx - 120, y = py + 112, w = 50, h = 34 }
        tradeState.btnRects.pricePlus = { x = cx + 70, y = py + 112, w = 50, h = 34 }
        TradeBtn(cx - 120, py + 112, 50, 34, "-", false)
        TradeBtn(cx + 70, py + 112, 50, 34, "+", false)
        nvgText(vg, cx, py + 129, tostring(pop.data.price or 0), nil)
    end
    tradeState.btnRects.popupYes = { x = cx - 120, y = py + ph - 52, w = 110, h = 38 }
    tradeState.btnRects.popupNo = { x = cx + 10, y = py + ph - 52, w = 110, h = 38 }
    TradeBtn(cx - 120, py + ph - 52, 110, 38, "确认", true)
    TradeBtn(cx + 10, py + ph - 52, 110, 38, "取消", false)
end
