-- ui/input_end_press.lua - 三国武灵录 (从 input.lua 拆分)
function HandleFragShopEndPress(sx, sy)
    fragShopScroll.isDragging = false
    local dx, dy = ScreenToDesign(sx, sy)
    local dragDist = math.abs(dy - (fragShopScroll.dragStartY or dy))
    if dragDist < 10 then
        -- 短距离视为点击 >> 检测合成按钮
        for cardIdx, rect in pairs(heroFragShopComposeBtnRects) do
            if dx >= rect.x and dx <= rect.x + rect.w and dy >= rect.y and dy <= rect.y + rect.h then
                TryComposeHeroFrag(cardIdx)
                break
            end
        end
        for skillIdx, rect in pairs(fragShopComposeBtnRects) do
            if dx >= rect.x and dx <= rect.x + rect.w and dy >= rect.y and dy <= rect.y + rect.h then
                TryComposeSkillFrag(skillIdx)
                break
            end
        end
        -- 一键合成按钮
        if fragShopOneKeyBtnRect then
            local r = fragShopOneKeyBtnRect
            if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
                OneKeyCompose()
            end
        end
        fragShopScroll.vel = 0
    end
    fragShopScroll.dragStartY = nil
    fragShopScroll.dragLastY = nil
end


--- 剧情章节列表松手处理

--- 武技滚动松手处理
function HandleSkillCodexEndPress(sx, sy)
    skillCodexState.isDragging = false
    local dx, dy = ScreenToDesign(sx, sy)
    local dragDist = math.abs(dy - (skillCodexState.dragStartY or dy))
    if dragDist < 10 then
        if phaseChangeCooldown <= 0 then
            for idx, rect in pairs(skillCodexCardRects) do
                if dx >= rect.x and dx <= rect.x + rect.w and
                   dy >= rect.y and dy <= rect.y + rect.h and
                   dy >= 66 and dy <= DESIGN_H - 10 then
                    skillCodexState.selectedIdx = idx
                    PushPhase("SKILL_DETAIL")
                    phaseChangeCooldown = 0.3
                    print("=== 查看武技详情: " .. SKILL_TECHNIQUES[idx].name .. " ===")
                    break
                end
            end
        end
        skillCodexState.scrollVel = 0
    end
    skillCodexState.dragStartY = nil
    skillCodexState.dragLastY = nil
end


--- 装备图鉴滚动松手处理
function HandleEquipCodexEndPress(sx, sy)
    equipCodexState.isDragging = false
    local dx, dy = ScreenToDesign(sx, sy)
    local dragDist = math.abs(dy - (equipCodexState.dragStartY or dy))
    if dragDist < 10 then
        equipCodexState.scrollVel = 0
    end
    equipCodexState.dragStartY = nil
    equipCodexState.dragLastY = nil
end


--- 武灵录滚动松手处理
function HandleCodexEndPress(sx, sy)
    codexScroll.isDragging = false
    local dx, dy = ScreenToDesign(sx, sy)
    local dragDist = math.abs(dy - (codexScroll.dragStartY or dy))
    if dragDist < 10 then
        if phaseChangeCooldown <= 0 then
            for idx, rect in pairs(codexCardRects) do
                if dx >= rect.x and dx <= rect.x + rect.w and
                   dy >= rect.y and dy <= rect.y + rect.h and
                   dy >= 66 and dy <= DESIGN_H - 30 then
                    local hero = playerHeroes[idx]
                    if hero and hero.owned then
                        heroDetailState.cardIdx = idx
                        heroDetailScroll.y = 0; heroDetailScroll.vel = 0
                        PushPhase("HERO_DETAIL")
                        print("=== 查看武灵详情: " .. HERO_CARDS[idx].name .. " ===")
                    end
                    break
                end
            end
        end
        codexScroll.vel = 0
    end
    codexScroll.dragStartY = nil
    codexScroll.dragLastY = nil
end


--- 左侧栏按钮点击处理（提取为独立函数，供 BeginPress 和 EndPress 共用）
--- @param dx number 设计坐标 X
--- @param dy number 设计坐标 Y
--- @return boolean handled
function HandleSidebarButtonClick(dx, dy)
    local function HitR(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    if HitR(menuBtnRects.codex) then
        if not moduleState.heroes.ready then
            ShowToast("武灵资源下载中(" .. math.floor(moduleState.heroes.progress * 100) .. "%)，请稍候")
            PlaySFX(AUDIO.sfx_click); return true
        end
        PushPhase("CODEX"); codexScroll.y = 0; codexScroll.vel = 0
        phaseChangeCooldown = 0.3; return true
    elseif HitR(menuBtnRects.equip) then
        if not moduleState.equipment.ready then
            ShowToast("兵甲资源下载中(" .. math.floor(moduleState.equipment.progress * 100) .. "%)，请稍候")
            PlaySFX(AUDIO.sfx_click); return true
        end
        PushPhase("EQUIP")
        local autoSlot = 1
        for si = 1, 7 do
            if HasEquipSlotRedDot(si) then autoSlot = si; break end
        end
        equipScreenState.selectedSlot = autoSlot; equipScreenState.scrollY = 0
        EquipUI._vg = vg; EquipUI._equipSheet = IMG.equipmentSheet
        EquipUI._sheetCols = EQUIP_SHEET_COLS; EquipUI._sheetRows = EQUIP_SHEET_ROWS
        EquipUI.Show(); return true
    elseif HitR(menuBtnRects.equipCodex) then
        if not moduleState.equipment.ready then
            ShowToast("兵甲资源下载中(" .. math.floor(moduleState.equipment.progress * 100) .. "%)，请稍候")
            PlaySFX(AUDIO.sfx_click); return true
        end
        PushPhase("EQUIP_CODEX"); return true
    elseif HitR(menuBtnRects.skillCodex) then
        if not moduleState.skills.ready then
            ShowToast("武技资源下载中(" .. math.floor(moduleState.skills.progress * 100) .. "%)，请稍候")
            PlaySFX(AUDIO.sfx_click); return true
        end
        PushPhase("SKILL_CODEX"); skillCodexState.scrollY = 0; skillCodexState.scrollVel = 0
        phaseChangeCooldown = 0.3; DismissSkillRedDots(); return true
    elseif HitR(menuBtnRects.welfare) then
        PushPhase("WELFARE"); phaseChangeCooldown = 0.3
        welfareState.contribLoaded = false; welfareState.contribLoading = false
        welfareState.powerLoaded = false; welfareState.powerLoading = false
        welfareState.contribScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
        welfareState.powerScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
        welfareState.scroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
        LoadContribRank(); ReportPowerScore(); LoadPowerRank(); return true
    elseif menuBtnRects.progress and HitR(menuBtnRects.progress) then
        CheckDailyReset(); CheckWeeklyReset()
        progressUIState.tab = 1; progressUIState.scrollY = 0
        PushPhase("PROGRESS"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return true
    elseif menuBtnRects.mailBox and HitR(menuBtnRects.mailBox) then
        PushPhase("MAIL_BOX"); phaseChangeCooldown = 0.3
        welfareState.mail.scroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
        welfareState.mail.btnRects = {}; welfareState.mail.cloudBtnRects = {}
        welfareState.mail.confirmPopup = nil
        welfareState.mail.composing = false; welfareState.mail.composeData = nil
        welfareState.mail.adminPanel = false
        CloudManager.PollInbox()
        PlaySFX(AUDIO.sfx_click); return true
    elseif menuBtnRects.faction and HitR(menuBtnRects.faction) then
        -- 重置阵营UI状态
        local info = CloudManager.GetFactionInfo()
        local hasFaction = info and info.id and info.id > 0
        factionUI.tab = hasFaction and "info" or "list"
        factionUI.loaded = false; factionUI.loading = false
        factionUI.applyLoaded = false; factionUI.applyLoading = false
        factionUI.leaderNickLoaded = false; factionUI.leaderNickname = nil
        factionUI.memberValidated = false  -- 重新验证成员
        factionUI.chatPolled = false  -- 下次进聊天tab重新拉取
        factionUI.members = {}; factionUI.applications = {}; factionUI.factions = {}
        factionUI.scroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil }
        factionUI.inputTarget = nil; factionUI.confirmPopup = nil
        factionUI.createName = ""; factionUI.createDesc = ""
        PushPhase("FACTION"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return true
    elseif menuBtnRects.friends and HitR(menuBtnRects.friends) then
        -- 重置好友UI状态
        friendsUI.tab = "list"
        friendsUI.loaded = false; friendsUI.loading = false
        friendsUI.reqLoaded = false; friendsUI.reqLoading = false
        friendsUI.recLoaded = false; friendsUI.recLoading = false
        friendsUI.friends = {}; friendsUI.requests = {}; friendsUI.recommended = {}
        friendsUI.scroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil }
        friendsUI.confirmPopup = nil; friendsUI.inputActive = false
        friendsUI.searchId = ""; friendsUI.searchResult = nil; friendsUI.searchNotFound = false
        PushPhase("FRIENDS"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return true
    elseif menuBtnRects.formation and HitR(menuBtnRects.formation) then
        -- 编队: 进入时先自动编队
        ValidateFormation()
        local ownedCount = AutoFillFormation()
        formationUI = formationUI or {}
        formationUI.scrollY = 0; formationUI.scrollVel = 0
        formationUI.isDragging = false; formationUI.dragStartY = nil; formationUI.dragLastY = nil
        formationUI.tab = 0  -- 0=全部
        formationUI.cardRects = {}; formationUI.slotRects = {}
        formationUI.confirmPopup = nil
        formationUI.ownedCount = ownedCount
        if ownedCount < 10 then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "武灵不足10人, 已全部自动上阵", 2.0, { 255, 220, 100 }, 14)
        else
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "已自动编队, 可手动调整上阵武灵", 2.0, { 120, 220, 100 }, 14)
        end
        PushPhase("FORMATION"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return true
    elseif menuBtnRects.trade and HitR(menuBtnRects.trade) then
        -- 交易行
        PushPhase("TRADE"); phaseChangeCooldown = 0.3
        tradeState.tab = "market"
        tradeState.scroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil }
        tradeState.selectedItem = nil; tradeState.confirmPopup = nil; tradeState.btnRects = {}
        TradeManager.Init(); TradeManager.ResetCheckSalesCD(); TradeManager.RefreshMarket()
        PlaySFX(AUDIO.sfx_click); return true
    end
    return false
end


--- 各页面滚动/拖拽释放逻辑（从 EndPress 中提取以避免 200 upvalue 限制）
--- @return boolean handled 是否已处理（调用方应 return）
function HandleEndPressDragRelease(sx, sy, touchId)
    -- 世界地图回合报告拖拽释放
    if worldMapState.reportDragging then
        worldMapState.reportDragging = false
        worldMapState.reportDragLastY = nil
    end

    -- 世界地图城池列表拖拽释放
    if worldMapState.cityListDragging then
        worldMapState.cityListDragging = false
        worldMapState.cityListDragLastY = nil
    end

    -- 左侧栏拖拽释放
    if leftSidebarScroll.isDragging then
        leftSidebarScroll.isDragging = false
        local _, dy = ScreenToDesign(sx, sy)
        local dragDist = math.abs(dy - (leftSidebarScroll.dragStartY or dy))
        if dragDist >= 10 then
            -- 拖拽距离足够 → 是滚动操作，不触发按钮点击
            leftSidebarScroll.dragStartY = nil
            leftSidebarScroll.dragLastY = nil
            return true
        end
        -- 拖拽距离不足 → 当作点击
        leftSidebarScroll.vel = 0
        leftSidebarScroll.dragStartY = nil
        leftSidebarScroll.dragLastY = nil
        local dx2, dy2 = ScreenToDesign(sx, sy)
        HandleSidebarButtonClick(dx2, dy2)
        return true
    end

    -- 英雄选择弹窗滚动释放
    if sealMgrState.showHeroPicker and heroPickerScroll.isDragging then
        heroPickerScroll.isDragging = false
        local dx, dy = ScreenToDesign(sx, sy)
        local dragDist = math.abs(dy - (heroPickerScroll.dragStartY or dy))
        if dragDist < 10 then
            heroPickerScroll.vel = 0
            -- 短按 = 点击，选中英雄卡牌
            for cardIdx, rect in pairs(sealMgrHeroRects) do
                if dx >= rect.x and dx <= rect.x + rect.w and dy >= rect.y and dy <= rect.y + rect.h then
                    sealMgrState.selectedHero = cardIdx
                    sealMgrState.selectedSlot = nil
                    sealMgrState.showLevelUp = false
                    sealMgrState.showHeroPicker = false
                    heroPickerScroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false, contentH = 0, viewH = 0 }
                    PlaySFX(AUDIO.sfx_click)
                    break
                end
            end
        end
        return true
    end

    -- 兵符替换弹窗滚动释放
    if sealReplaceState.show and sealReplaceState.scroll.isDragging then
        sealReplaceState.scroll.isDragging = false
        return true
    end

    -- 统一规则弹窗滚动释放
    if phaseRulePopup.isDragging then
        phaseRulePopup.isDragging = false
        return true
    end

    -- 战斗规则弹窗滚动释放
    if battleRulesState.isDragging then
        battleRulesState.isDragging = false
        return true
    end

    -- ======== 按钮位置调整模式拖拽释放 ========
    if settingsPage.btnAdjustMode then
        settingsPage.adjDragging = false
        settingsPage.adjDraggingScale = false
        return true
    end

    -- ======== 设置界面拖拽释放 ========
    if settingsPage.isOpen and gameState.phase == "MENU" then
        settingsPage.draggingMusic = false
        settingsPage.draggingSfx = false
        return true
    end

    -- 策略选项条释放
    if strategyWheelState.pressing and touchId == strategyWheelState.touchId then
        strategyWheelState.pressing = false
        if strategyWheelState.show then
            if strategyWheelState.selected > 0 and strategyWheelState.selected <= #MARCH_STRATEGIES then
                -- 拖拽选中了，直接应用
                local st = MARCH_STRATEGIES[strategyWheelState.selected]
                gameState.autoMarchStrategy = st.id
                gameState.autoMarch = true
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "策略: " .. st.name, 1.2, st.color, 16)
                PlaySFX(AUDIO.sfx_march)
                strategyWheelState.show = false
                strategyWheelState.selected = 0
            end
            -- 未选中则保持面板显示，等待点击选择
            return true
        else
            -- 短按: toggle自动行军
            gameState.autoMarch = not gameState.autoMarch
            if gameState.autoMarch then PlaySFX(AUDIO.sfx_march) end
            local txt = gameState.autoMarch and "自动行军 开启" or "自动行军 关闭"
            local clr = gameState.autoMarch and { 120, 255, 160 } or { 200, 180, 160 }
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, txt, 1.0, clr, 16)
            return true
        end
    end

    -- (已移除武技长按释放逻辑, 按下即拖拽瞄准)

    -- 武技技能瞄准释放
    if skillTargeting.active and touchId == skillTargeting.touchId then
        skillTargeting.active = false
        local tdx, tdy = ScreenToDesign(sx, sy)
        tdx = math.max(BATTLE_ZONE.left, math.min(BATTLE_ZONE.right, tdx))
        tdy = math.max(BATTLE_ZONE.top, math.min(BATTLE_ZONE.bottom, tdy))
        if tdy >= BATTLE_ZONE.top - 10 and tdy <= BATTLE_ZONE.bottom + 10
           and tdx >= BATTLE_ZONE.left - 10 and tdx <= BATTLE_ZONE.right + 10 then
            CastSkill(skillTargeting.skillIdx, tdx, tdy)
        else
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "释放取消", 0.8, { 180, 180, 180 }, 12)
        end
        return true
    end

    -- 武技滚动结束
    if gameState.phase == "SKILL_CODEX" and skillCodexState.isDragging then
        HandleSkillCodexEndPress(sx, sy)
        return true
    end

    -- 打桩选将滚动结束
    if gameState.phase == "DUMMY_SELECT" and dummyState.isDragging then
        dummyState.isDragging = false
        local dx, dy = ScreenToDesign(sx, sy)
        local dragDist = math.abs(dy - (dummyState.dragStartY or dy))
        if dragDist < 10 then
            -- 视为点击，检查卡牌选择
            for ci, rect in pairs(dummyState.cardRects) do
                if dx >= rect.x and dx <= rect.x + rect.w and
                   dy >= rect.y and dy <= rect.y + rect.h then
                    local foundIdx = nil
                    for si, sel in ipairs(dummyState.selected) do
                        if sel == ci then foundIdx = si; break end
                    end
                    if foundIdx then
                        table.remove(dummyState.selected, foundIdx)
                        PlaySFX(AUDIO.sfx_click)
                    else
                        if #dummyState.selected < 4 then
                            table.insert(dummyState.selected, ci)
                            PlaySFX(AUDIO.sfx_click)
                        else
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "最多选择4名武灵", 1.0, { 255, 200, 80 }, 16)
                        end
                    end
                    break
                end
            end
        end
        dummyState.dragStartY = nil
        dummyState.dragLastY = nil
        return true
    end

    -- 天命赐福贡献榜滚动释放
    if gameState.phase == "WELFARE" and welfareState.contribScroll.isDragging then
        welfareState.contribScroll.isDragging = false
        welfareState.contribScroll.dragStartY = nil
        welfareState.contribScroll.dragLastY = nil
        return true
    end

    -- 战令通行证横向拖拽释放
    if gameState.phase == "BATTLE_PASS" and battlePassUIState.isDraggingReward then
        battlePassUIState.isDraggingReward = false
        return true
    end

    -- 战令通行证纵向拖拽释放
    if gameState.phase == "BATTLE_PASS" and battlePassUIState.isDragging then
        battlePassUIState.isDragging = false
        battlePassUIState.dragStartY = nil
        battlePassUIState.dragLastY = nil
        return true
    end

    -- 编队界面滚动释放 + 卡牌点击
    if gameState.phase == "FORMATION" and formationUI and formationUI.isDragging then
        formationUI.isDragging = false
        local _, dy = ScreenToDesign(sx, sy)
        local dragDist = math.abs(dy - (formationUI.dragStartY or dy))
        formationUI.dragStartY = nil; formationUI.dragLastY = nil
        if dragDist < 10 then
            -- 拖拽距离不足 → 当作点击 (添加/移除卡牌)
            formationUI.scrollVel = 0
            local dx2, dy2 = ScreenToDesign(sx, sy)
            local FORMATION_MAX = 10
            local ownedCount = formationUI.ownedCount or GetOwnedHeroCount()
            local canManualEdit = ownedCount >= 10
            local targetCount = math.min(FORMATION_MAX, ownedCount)
            if formationUI.cardRects then
                for _, cr in ipairs(formationUI.cardRects) do
                    if cr and dx2 >= cr.x and dx2 <= cr.x + cr.w and dy2 >= cr.y and dy2 <= cr.y + cr.h then
                        -- 不满10人时禁止手动调整
                        if not canManualEdit then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "武灵不足10人, 无法调整编队", 1.5, { 255, 180, 80 }, 14)
                            PlaySFX(AUDIO.sfx_click)
                            break
                        end
                        local cardIdx = cr.cardIdx
                        -- 检查是否已在编队
                        local alreadyIn = false
                        for _, idx in ipairs(gameSettings.formation) do
                            if idx == cardIdx then alreadyIn = true; break end
                        end
                        if alreadyIn then
                            -- 已在编队 → 移除
                            for fi = #gameSettings.formation, 1, -1 do
                                if gameSettings.formation[fi] == cardIdx then
                                    table.remove(gameSettings.formation, fi); break
                                end
                            end
                            SaveSettings()
                            PlaySFX(AUDIO.sfx_click)
                        elseif #gameSettings.formation < targetCount then
                            -- 未满 → 添加
                            table.insert(gameSettings.formation, cardIdx)
                            SaveSettings()
                            PlaySFX(AUDIO.sfx_click)
                        else
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "编队已满(" .. targetCount .. "人)", 1.5, { 220, 160, 80 }, 14)
                        end
                        break
                    end
                end
            end
        end
        return true
    end

    -- 阵营成员列表滚动释放
    if gameState.phase == "FACTION" and factionUI.scroll.isDragging then
        factionUI.scroll.isDragging = false
        factionUI.scroll.dragStartY = nil
        factionUI.scroll.dragLastY = nil
        return true
    end

    -- 交易行滚动释放
    if gameState.phase == "TRADE" and tradeState.scroll.isDragging then
        tradeState.scroll.isDragging = false
        tradeState.scroll.dragStartY = nil
        tradeState.scroll.dragLastY = nil
        return true
    end

    -- 邮件列表滚动释放
    if gameState.phase == "MAIL_BOX" and welfareState.mail.scroll and welfareState.mail.scroll.isDragging then
        welfareState.mail.scroll.isDragging = false
        welfareState.mail.scroll.dragStartY = nil
        welfareState.mail.scroll.dragLastY = nil
        return true
    end

    -- 天命赐福下方内容滚动释放
    if gameState.phase == "WELFARE" and welfareState.scroll.isDragging then
        welfareState.scroll.isDragging = false
        welfareState.scroll.dragStartY = nil
        welfareState.scroll.dragLastY = nil
        return true
    end

    -- 每日任务/成就滚动释放
    if gameState.phase == "PROGRESS" and progressUIState.isDragging then
        progressUIState.isDragging = false
        progressUIState.dragStartY = nil
        progressUIState.dragLastY = nil
        return true
    end

    -- 编辑器石台释放
    if gameState.phase == "DEV_EDITOR" and editorState.slotPressKey then
        local key = editorState.slotPressKey
        if not editorState.slotDragging then
            if editorState.slotWasSelected then
                editorState.selectedSlots[key] = nil
            end
        end
        editorState.slotDragging = false
        editorState.slotPressKey = nil
        editorState.slotWasSelected = false
        editorState.slotPressStartX = nil
        editorState.slotPressStartY = nil
        editorState.dragStartBgX = nil
        editorState.dragStartBgY = nil
        editorState.dragOrigPositions = nil
        return true
    end

    -- 编辑器滚动释放
    if gameState.phase == "DEV_EDITOR" and editorState.isDragging then
        editorState.isDragging = false
        editorState.dragStartY = nil
        editorState.dragLastY = nil
        return true
    end

    -- 残片仓库松手
    if gameState.phase == "GACHA" and gachaState.showFragShop and fragShopScroll.isDragging then
        HandleFragShopEndPress(sx, sy)
        return true
    end

    -- 战力排行榜滚动释放
    if gameState.phase == "POWER_RANK" then
        local curScroll
        if welfareState.rankTab == "realm" then
            curScroll = welfareState.realmScroll
        elseif welfareState.rankTab == "dummy" then
            curScroll = welfareState.dummyScroll
        else curScroll = welfareState.powerScroll end
        if curScroll.isDragging then
            curScroll.isDragging = false
            curScroll.dragStartY = nil
            curScroll.dragLastY = nil
            return true
        end
    end

    -- 贡献榜详情页滚动释放
    if gameState.phase == "CONTRIB_RANK" and welfareState.contribDetailScroll.isDragging then
        welfareState.contribDetailScroll.isDragging = false
        welfareState.contribDetailScroll.dragStartY = nil
        welfareState.contribDetailScroll.dragLastY = nil
        return true
    end

    -- 新版EquipUI触摸结束委托
    if gameState.phase == "EQUIP" and EquipUI.isVisible then
        local dx, dy = ScreenToDesign(sx, sy)
        EquipUI.HandleTouchEnd(dx, dy)
        return true
    end

    -- 兵甲列表滚动释放（旧版，只响应按钮点击，不响应整行）
    if gameState.phase == "EQUIP" and equipScreenState.isDragging then
        equipScreenState.isDragging = false
        local dx, dy = ScreenToDesign(sx, sy)
        local dragDist = math.abs(dy - (equipScreenState.dragStartY or dy))
        if dragDist < 10 then
            equipScreenState.scrollVel = 0
            -- 短距离松手 = 点击，只检测按钮区域
            local function HitBtn(r)
                return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
            end
            local slotIdx = equipScreenState.selectedSlot
            -- 选中模式: 点击列表项切换勾选
            if equipScreenState.selectMode then
                for _, rect in pairs(equipPieceRects) do
                    local info = rect.info
                    if not info then goto skipSel end
                    if HitBtn(rect) then
                        -- 已装备的不可选
                        local equippedUid = playerEquipment.equipped[info.slotIdx]
                        if equippedUid ~= info.uid then
                            if equipScreenState.selectedUids[info.uid] then
                                equipScreenState.selectedUids[info.uid] = nil
                            else
                                equipScreenState.selectedUids[info.uid] = true
                            end
                            PlaySFX(AUDIO.sfx_click)
                        end
                        break
                    end
                    ::skipSel::
                end
            else
            for _, rect in pairs(equipPieceRects) do
                local info = rect.info
                if not info then goto skipRect end
                -- 分解按钮
                if HitBtn(rect.decompRect) then
                    local itemObj = FindOwnedByUid(info.uid)
                    if itemObj then
                        local gain, enhRefund = CalcDecomposeGain(itemObj.tier, itemObj.enhanceLv)
                        equipScreenState.decompConfirm = {
                            uid = itemObj.uid,
                            setIdx = itemObj.setIdx, slotIdx = itemObj.slotIdx,
                            tier = itemObj.tier, gain = gain, enhRefund = enhRefund, enhLv = itemObj.enhanceLv,
                        }
                    end
                    PlaySFX(AUDIO.sfx_click)
                    break
                end
                -- 装备按钮
                if HitBtn(rect.equipBtnRect) then
                    local itemObj = FindOwnedByUid(info.uid)
                    if itemObj then
                        playerEquipment.equipped[slotIdx] = itemObj.uid
                        local pieceName = EQUIPMENT_SETS[itemObj.setIdx].pieces[slotIdx].name
                        local tierName = EQUIP_TIERS[itemObj.tier or 1].name
                        local qLabel = GetQualityLabel(itemObj.quality)
                        print("=== 装备: 槽位" .. slotIdx .. " " .. tierName .. " " .. pieceName .. " " .. qLabel .. " ===")
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.5, "装备 " .. tierName .. " " .. pieceName, 1.0, { 100, 255, 180 }, 18)
                        playerInfo.totalEquips = playerInfo.totalEquips + 1
                        TrackDailyTask("equip1", 1)
                        SaveGameProgress()
                    end
                    break
                end
                -- 卸下按钮
                if HitBtn(rect.unequipRect) then
                    playerEquipment.equipped[slotIdx] = nil
                    print("=== 卸下装备: 槽位" .. slotIdx .. " ===")
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.5, "已卸下装备", 1.0, { 200, 200, 200 }, 18)
                    SaveGameProgress()
                    break
                end
                ::skipRect::
            end
            end -- end selectMode else
        end
        equipScreenState.dragStartY = nil
        equipScreenState.dragLastY = nil
        return true
    end

    -- 装备图鉴滚动释放
    if gameState.phase == "EQUIP_CODEX" and equipCodexState.isDragging then
        HandleEquipCodexEndPress(sx, sy)
        return true
    end

    -- 兵符管理滚动释放（选中分解列表）
    if gameState.phase == "SEAL_MGR" and sealMgrScroll.isDragging then
        sealMgrScroll.isDragging = false
        local dx, dy = ScreenToDesign(sx, sy)
        local dragDist = math.abs(dy - (sealMgrScroll.dragStartY or dy))
        if dragDist < 10 then
            sealMgrScroll.vel = 0
            -- 短按 = 点击，切换列表项选中
            if sealInvFilterState.selectMode and sealInvFilterBtnRects.selectItems then
                for _, rect in pairs(sealInvFilterBtnRects.selectItems) do
                    if dx >= rect.x and dx <= rect.x + rect.w and dy >= rect.y and dy <= rect.y + rect.h then
                        if sealInvFilterState.selectedIds[rect.invIndex] then
                            sealInvFilterState.selectedIds[rect.invIndex] = nil
                        else
                            sealInvFilterState.selectedIds[rect.invIndex] = true
                        end
                        PlaySFX(AUDIO.sfx_click)
                        break
                    end
                end
            end
        end
        return true
    end

    -- 武灵详情页滚动释放
    if gameState.phase == "HERO_DETAIL" and heroDetailScroll.isDragging then
        heroDetailScroll.isDragging = false
        return true
    end

    -- 玩家详情页滚动释放
    if gameState.phase == "PLAYER_DETAIL" and playerDetailScroll.isDragging then
        playerDetailScroll.isDragging = false
        return true
    end

    -- 武灵录滚动释放
    if gameState.phase == "CODEX" and codexScroll.isDragging then
        HandleCodexEndPress(sx, sy)
        return true
    end

    return false
end

function EndPress(sx, sy, touchId)
    if gameState.isBanned then return end  -- 封禁玩家拦截一切操作
    if CloudManager.IsCloudLoading() then return end  -- 云数据加载中拦截操作
    local curFrame = time:GetFrameNumber()
    if curFrame == _lastEndFrame then return end
    _lastEndFrame = curFrame

    if HandleEndPressDragRelease(sx, sy, touchId) then return end

    -- RTS 指令拖拽释放: 松手下达指令
    if rtsState and rtsState.isCmdDrag and (touchId == rtsState.cmdDragTouchId) then
        rtsState.isCmdDrag = false
        local rdx, rdy = ScreenToDesign(sx, sy)
        local bz = BATTLE_ZONE
        rdx = math.max(bz.playerLine, math.min(bz.enemyLine, rdx))
        rdy = math.max(bz.top + 10, math.min(bz.bottom - 10, rdy))
        local cmdType = rtsState._lastCmd or rtsState.activeCmd or "move"
        IssueCommand(cmdType, rdx, rdy)
        rtsState._lastCmd = cmdType
        rtsState.cmdMarkerTimer = 1.5  -- 恢复正常倒计时
        PlaySFX(AUDIO.sfx_march)
        return
    end

    if longPressState.active then
        longPressState.active = false
        longPressState.pressing = false
        longPressState.card = nil
        return
    end

    if longPressState.pressing then
        if longPressState.card then
            infoPopupState.show = true
            infoPopupState.card = longPressState.card
            infoPopupState.slotIdx = longPressState.slotIdx
            infoPopupState.isSlot = longPressState.isSlot
            infoPopupState.isEnemy = longPressState.isEnemy
        end
        longPressState.pressing = false
        longPressState.card = nil
    end

    if dragState.active and (touchId == dragState.touchId) then
        dragState.lx, dragState.ly = ScreenToLogical(sx, sy)
        TryDrop()
    end
end


function TryDrop()
    if not dragState.active then return end
    dragState.active = false
    if not dragState.card then return end

    -- 把拖拽逻辑坐标转设计坐标检查放置
    local dx, dy = LogicalToDesign(dragState.lx, dragState.ly)

    local halfW = SLOT_CARD_W / 2 + 12
    local halfH = SLOT_CARD_H / 2 + 12
    local placed = false

    for si, slot in ipairs(PLAYER_SLOTS) do
        if dx >= slot.cx - halfW and dx <= slot.cx + halfW and
           dy >= slot.cy - halfH and dy <= slot.cy + halfH then

            -- === 从石台拖拽: 交换/移位 ===
            if dragState.fromSlot then
                local srcIdx = dragState.fromSlotIdx
                local srcSlot = PLAYER_SLOTS[srcIdx]
                if si == srcIdx then
                    -- 放回原位
                    srcSlot.filled = true
                    srcSlot.card = dragState.card
                    AddFloatText(slot.cx, slot.cy - 25, "放回", 0.8, { 180, 200, 255 }, 12)
                elseif slot.filled and slot.card then
                    -- 目标有卡牌 >> 交换
                    local targetCard = slot.card
                    -- 把拖拽卡牌放到目标位
                    SetupSlotHero(slot, dragState.card)
                    -- 把目标卡牌放到源位
                    SetupSlotHero(srcSlot, targetCard)
                    SpawnPlaceEffect(slot.cx, slot.cy, dragState.card.quality)
                    SpawnPlaceEffect(srcSlot.cx, srcSlot.cy, targetCard.quality)
                    AddFloatText(slot.cx, slot.cy - 25, "换位!", 1.0, { 255, 220, 120 }, 12)
                else
                    -- 目标为空 >> 直接移入
                    SetupSlotHero(slot, dragState.card)
                    SpawnPlaceEffect(slot.cx, slot.cy, dragState.card.quality)
                    AddFloatText(slot.cx, slot.cy - 25, dragState.card.name .. " 移位!", 1.0, { 200, 255, 200 }, 12)
                end
                dragState.card = nil
                placed = true
                RefreshBaseStats()
                return
            end

            -- === 从背包/商店来源 ===
            -- 从背包移除卡牌 (仅背包来源)
            if dragState.fromInventory and dragState.invIdx > 0 then
                if dragState.invIdx <= #inventory then
                    table.remove(inventory, dragState.invIdx)
                    local maxOff = math.max(0, #inventory - GameConfig.INVENTORY_VISIBLE)
                    if invScrollOffset > maxOff then invScrollOffset = maxOff end
                end
            end

            local oldCard = slot.card

            if dragState.fromShop then
                -- 商店卡牌: 使用 SetupSlotHero 初始化槽位
                SetupSlotHero(slot, dragState.card)
            else
                slot.filled = true
                slot.card = dragState.card
            end

            -- 放置特效
            SpawnPlaceEffect(slot.cx, slot.cy, dragState.card.quality)

            if oldCard and oldCard.name == dragState.card.name then
                slot.card.level = (oldCard.level or 1) + 1
                slot.card.atk = slot.card.atk * 1.15
                slot.card.def = slot.card.def * 1.1
                slot.card.hp = slot.card.hp * 1.2
                AddFloatText(slot.cx, slot.cy - 40, "合成! Lv" .. slot.card.level, 1.5, { 255, 220, 60 }, 14)
            elseif oldCard then
                -- 被替换的卡牌回到背包
                table.insert(inventory, {
                    cardIdx = oldCard.cardIdx or 1,
                    constellation = oldCard.constellation or 0,
                })
                AddFloatText(slot.cx, slot.cy - 25, "替换!", 1.0, { 255, 180, 80 }, 12)
            end
            AddFloatText(slot.cx, slot.cy - 25, slot.card.name .. " 上阵!", 1.2, { 200, 255, 200 }, 12)
            dragState.card = nil
            placed = true
            RefreshBaseStats()
            return
        end
    end

    -- === 未放到槽位上 ===
    if not placed then
        if dragState.fromSlot then
            if gameState.battlePhase == "SHOP" then
                -- SHOP阶段: 从石台拖出 >> 兑换军资
                local card = dragState.card
                local refund = GameConfig.CARD_COST[card.quality] or 3
                gameState.gold = gameState.gold + refund
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.5,
                    card.name .. " >> +" .. refund .. "军资", 1.2, { 255, 220, 80 }, 14)
                RefreshBaseStats()
            else
                -- FIGHT阶段: 检查是否拖到战场区域进行部署
                local ddx, ddy = LogicalToDesign(dragState.lx, dragState.ly)
                local srcIdx = dragState.fromSlotIdx
                local srcSlot = srcIdx and PLAYER_SLOTS[srcIdx]
                local bz = BATTLE_ZONE

                -- 判定区域比显示区域大(左右各扩60), 方便手机操作
                local hitMargin = 60
                if srcSlot and ddy >= bz.top and ddy <= bz.bottom
                   and ddx >= bz.playerLine - hitMargin and ddx <= bz.enemyLine + hitMargin then
                    -- 在战场区域: 检测车道并部署
                    if srcSlot.deployCD and srcSlot.deployCD > 0 then
                        -- 冷却中, 放回原位
                        srcSlot.filled = true
                        srcSlot.card = dragState.card
                        local cdLeft = string.format("%.1f", srcSlot.deployCD)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.5,
                            "冷却中(" .. cdLeft .. "s)", 0.8, { 255, 150, 100 }, 14)
                    else
                        -- 已去除车道系统，直接部署到手指Y位置
                        -- 先恢复卡牌 (拖拽中slot.card被清空, SpawnUnitFromSlot需要读slot.card)
                        srcSlot.filled = true
                        srcSlot.card = dragState.card

                        -- 批量部署士兵
                        local batchSize = GetBatchSizeForSlot(srcSlot)
                        local spawned = 0
                        local unitCap = GetPlayerUnitCap()
                        for _ = 1, batchSize do
                            if #playerUnits < unitCap then
                                SpawnUnitFromSlot(srcSlot, true)
                                spawned = spawned + 1
                            end
                        end

                        -- 设置冷却
                        srcSlot.deployCD = DEPLOY_CD
                        srcSlot.spawnFlash = 0.5
                        srcSlot.spawnCount = (srcSlot.spawnCount or 0) + spawned

                        AddFloatText(bz.playerDeployLeft + 60, ddy,
                            "部署 ×" .. spawned .. "!", 1.2, { 200, 255, 200 }, 16)
                    end
                else
                    -- 拖出战场区域: 检查是否拖到底部卡牌区/商店区
                    -- 只有拖到商店区域(屏幕底部)才下阵换军资, 其余放回原位
                    local shopTopY = screenH - SHOP_RESERVED_H
                    if srcSlot and dragState.ly >= shopTopY then
                        -- 拖到底部卡牌区: 下阵换军资
                        local card = dragState.card
                        local refund = GameConfig.CARD_COST[card.quality] or 3
                        gameState.gold = gameState.gold + refund
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.5,
                            card.name .. " 下阵 >> +" .. refund .. "军资", 1.2, { 255, 220, 80 }, 14)
                        RefreshBaseStats()
                    elseif srcSlot then
                        -- 其他区域: 放回原位 (取消操作)
                        srcSlot.filled = true
                        srcSlot.card = dragState.card
                    end
                end
            end
        elseif dragState.fromShop then
            local shopItem = shopCards[dragState.shopIdx]
            if shopItem then
                shopItem.sold = false
                gameState.gold = gameState.gold + shopItem.cost
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.6, "已退还军资", 1.0, { 180, 220, 255 }, 12)
            end
        end
    end
    dragState.card = nil
end
