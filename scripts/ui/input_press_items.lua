-- ============================================================================
-- ui/input_press_items.lua - 物品/交易点击处理
-- 用途: BeginPress 子处理器 - GACHA, CODEX, HERO_DETAIL, PLAYER_DETAIL, EQUIP, MAIL_BOX, TRADE
-- 依赖: 全局变量 (gameState, ScreenToDesign, DrawBtn 等)
-- 导出: M.handle(sx, sy, touchId) -> boolean (是否已处理)
-- [TECH_DEBT] 全局变量模式: 延续 input 模块的全局状态设计
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

--- 处理点击事件 (仅处理本模块负责的 phase)
---@param sx number 屏幕坐标X
---@param sy number 屏幕坐标Y
---@param touchId number 触摸ID
---@return boolean handled 是否已处理
function M.handle(sx, sy, touchId)
    -- === 抽卡界面输入 === (已移除抽卡系统)
    --[=[ GACHA phase removed
    if gameState.phase == "GACHA" then
        return
    end
    --]=]

    -- === 个人资料界面输入 ===
    if gameState.phase == "CODEX" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(codexBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
            return
        end
        -- 品质标签页点击检测
        for _, tr in ipairs(codexTabRects) do
            if HitRect(tr) then
                if codexTab ~= tr.tabIdx then
                    codexTab = tr.tabIdx
                    codexScroll.y = 0  -- 切换标签页时重置滚动位置
                    codexScroll.vel = 0
                end
                return
            end
        end
        -- 记录拖拽起始位置（用于滚动，点击延迟到EndPress判断）
        codexScroll.dragStartY = dy
        codexScroll.dragLastY = dy
        codexScroll.isDragging = true
        codexScroll.vel = 0
        return
    end

    -- === 武灵详情页输入 ===
    if gameState.phase == "HERO_DETAIL" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 左右切换武将箭头
        if HitRect(heroDetailNavPrevRect) or HitRect(heroDetailNavNextRect) then
            local isPrev = HitRect(heroDetailNavPrevRect)
            -- 收集已拥有武将索引
            local ownedList = {}
            for i = 1, #HERO_CARDS do
                if playerHeroes[i] and playerHeroes[i].owned then
                    ownedList[#ownedList + 1] = i
                end
            end
            local curPos = 0
            for i, v in ipairs(ownedList) do
                if v == heroDetailState.cardIdx then curPos = i; break end
            end
            local targetPos = isPrev and (curPos - 1) or (curPos + 1)
            if targetPos >= 1 and targetPos <= #ownedList then
                heroDetailState.cardIdx = ownedList[targetPos]
                heroDetailScroll.y = 0; heroDetailScroll.vel = 0
                PlaySFX(AUDIO.sfx_click)
                print("=== 切换武将: " .. HERO_CARDS[ownedList[targetPos]].name .. " ===")
            end
            return
        end
        if HitRect(heroDetailBackBtnRect) then
            PopPhase("CODEX")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
            return
        end
        -- "管理装备" 快捷跳转（预选当前武将）
        if HitRect(heroDetailManageEquipRect) then
            local targetHero = heroDetailState.cardIdx
            equipScreenState.selectedHero = targetHero
            equipScreenState.selectedSlot = 1
            equipScreenState.scrollY = 0
            PushPhase("EQUIP")
            EquipUI._vg = vg
            EquipUI._equipSheet = IMG.equipmentSheet
            EquipUI._sheetCols = EQUIP_SHEET_COLS
            EquipUI._sheetRows = EQUIP_SHEET_ROWS
            EquipUI.Show()  -- buildOwnedHeroList 会自动定位到 selectedHero
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 武将详情→管理装备 武将#" .. tostring(targetHero) .. " ===")
            return
        end
        -- "管理武技" 快捷跳转
        if HitRect(heroDetailManageSkillRect) then
            local targetHero = heroDetailState.cardIdx
            equipScreenState.selectedHero = targetHero
            skillCodexState.selectedIdx = nil
            PushPhase("SKILL_CODEX")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 武将详情→管理武技 武将#" .. tostring(targetHero) .. " ===")
            return
        end
        -- 开始拖拽滚动
        heroDetailScroll.dragStartY = dy
        heroDetailScroll.dragLastY = dy
        heroDetailScroll.isDragging = true
        heroDetailScroll.vel = 0
        return
    end

    -- === 玩家详情页输入 ===
    if gameState.phase == "PLAYER_DETAIL" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(playerDetailBackBtnRect) then
            powerExplainPopup.show = false
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
            return
        end
        -- 点击已装备武技 → 跳转武技图鉴并打开弹窗
        if playerDetailSkillRects then
            for _, sr in pairs(playerDetailSkillRects) do
                if HitRect(sr) and sr.skIdx then
                    local sk = SKILL_TECHNIQUES[sr.skIdx]
                    if sk then
                        skillCodexState.selectedTier = sk.tier
                        skillCodexState.scrollX = 0
                    end
                    PushPhase("SKILL_CODEX")
                    skillPopup.show = true
                    skillPopup.skillIdx = sr.skIdx
                    skillPopup.equipBtnRect = nil
                    skillPopup.equipSlotBtns = {}
                    skillPopup.composeBtnRect = nil
                    skillPopup.closeBtnRect = nil
                    phaseChangeCooldown = 0.3
                    print("=== 查看武技弹窗: " .. (sk and sk.name or "") .. " ===")
                    return
                end
            end
        end
        -- 点击武灵卡牌 → 跳转武灵详情
        if playerDetailHeroRects then
            for _, hr in pairs(playerDetailHeroRects) do
                if HitRect(hr) and hr.heroIdx then
                    local hero = playerHeroes[hr.heroIdx]
                    if hero and hero.owned then
                        heroDetailState.cardIdx = hr.heroIdx
                        heroDetailScroll.y = 0; heroDetailScroll.vel = 0
                        PushPhase("HERO_DETAIL")
                        phaseChangeCooldown = 0.3
                        print("=== 查看武灵详情: " .. HERO_CARDS[hr.heroIdx].name .. " ===")
                        return
                    end
                end
            end
        end
        -- 战力说明弹窗交互（使用统一的 powerExplainPopup）
        if powerExplainPopup.show then
            local cr = powerExplainPopup.closeBtnRect
            if cr and HitRect(cr) then
                powerExplainPopup.show = false
                PlaySFX(AUDIO.sfx_click)
            end
            -- 点击弹窗外关闭
            local pr = powerExplainPopup.panelRect
            if not (pr and HitRect(pr)) then
                powerExplainPopup.show = false
            end
            return  -- 弹窗打开时拦截所有其他点击
        end
        -- "?" 按钮点击 → 显示战力说明
        if playerDetailPowerHelpRect and playerDetailPowerHelpRect.isCircle then
            local pdx, pdy = dx - playerDetailPowerHelpRect.cx, dy - playerDetailPowerHelpRect.cy
            if pdx * pdx + pdy * pdy <= playerDetailPowerHelpRect.r * playerDetailPowerHelpRect.r then
                powerExplainPopup.show = true
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 编辑资料按钮
        if HitRect(playerDetailEditBtnRect) then
            -- 预填充当前头像和名字
            for i, avOpt in ipairs(AVATAR_OPTIONS) do
                if avOpt == playerInfo.avatarIdx then
                    profileState.selectedAvatar = i
                    break
                end
            end
            profileState.customName = playerInfo.name
            profileState.selectedName = CUSTOM_NAME_IDX
            profileState.isInputActive = false
            profileState.editMode = true  -- 标记为编辑模式
            PushPhase("PROFILE")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 缂栬緫璧勬枡 ===")
            return
        end
        -- 开始拖拽滚动
        playerDetailScroll.dragStartY = dy
        playerDetailScroll.dragLastY = dy
        playerDetailScroll.isDragging = true
        playerDetailScroll.vel = 0
        return
    end

    -- === 个人资料界面输入 ===
    if gameState.phase == "EQUIP" then
        -- 新版NanoVG网格仓库：委托触摸事件
        if EquipUI.isVisible then
            local dx, dy = ScreenToDesign(sx, sy)
            EquipUI.HandleTouchBegin(dx, dy)
            return
        end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 强化确认弹窗：拦截所有点击
        if equipScreenState.enhanceConfirm then
            if HitRect(equipScreenState.enhanceConfirmBtn) then
                local ec = equipScreenState.enhanceConfirm
                local ok = EnhanceEquipment(ec.slotIdx)
                if ok then
                    print("=== 强化成功: 槽位" .. ec.slotIdx .. " ===")
                end
                equipScreenState.enhanceConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            elseif HitRect(equipScreenState.enhanceCancelBtn) then
                equipScreenState.enhanceConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            end
            -- 弹窗期间吞掉所有点击
            return
        end
        -- 分解确认弹窗：拦截所有点击
        if equipScreenState.decompConfirm then
            if HitRect(equipScreenState.decompConfirmBtn) then
                local dc = equipScreenState.decompConfirm
                local ok = DecomposeEquipment(dc.uid)
                if ok then
                    print("=== 分解装备: uid=" .. dc.uid .. " 套装" .. dc.setIdx .. " 阶级" .. dc.tier .. " ===")
                end
                equipScreenState.decompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            elseif HitRect(equipScreenState.decompCancelBtn) then
                equipScreenState.decompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            end
            -- 弹窗期间吞掉所有点击
            return
        end
        -- 批量分解确认弹窗：拦截所有点击
        if equipScreenState.batchDecompConfirm then
            if equipScreenState.batchDecompConfirmBtn and HitRect(equipScreenState.batchDecompConfirmBtn) then
                local ft = equipScreenState.batchFilterMaxTier or 6
                BatchDecomposeAll(ft)
                equipScreenState.batchDecompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
                print("=== 批量分解完成 (筛选品质<=" .. ft .. ") ===")
            elseif equipScreenState.batchDecompCancelBtn and HitRect(equipScreenState.batchDecompCancelBtn) then
                equipScreenState.batchDecompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            elseif equipScreenState.batchFilterLeftBtn and HitRect(equipScreenState.batchFilterLeftBtn) then
                local ft = equipScreenState.batchFilterMaxTier or 6
                ft = math.max(1, ft - 1)
                equipScreenState.batchFilterMaxTier = ft
                local c, g = CalcBatchDecomposeStats(ft)
                equipScreenState.batchDecompConfirm.count = c
                equipScreenState.batchDecompConfirm.gain = g
                PlaySFX(AUDIO.sfx_click)
            elseif equipScreenState.batchFilterRightBtn and HitRect(equipScreenState.batchFilterRightBtn) then
                local ft = equipScreenState.batchFilterMaxTier or 6
                ft = math.min(6, ft + 1)
                equipScreenState.batchFilterMaxTier = ft
                local c, g = CalcBatchDecomposeStats(ft)
                equipScreenState.batchDecompConfirm.count = c
                equipScreenState.batchDecompConfirm.gain = g
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        -- 选中分解确认弹窗：拦截所有点击
        if equipScreenState.selectDecompConfirm then
            if equipScreenState.selectDecompConfirmBtn and HitRect(equipScreenState.selectDecompConfirmBtn) then
                SelectDecomposeAll(equipScreenState.selectedUids)
                equipScreenState.selectDecompConfirm = nil
                equipScreenState.selectMode = false
                equipScreenState.selectedUids = {}
                PlaySFX(AUDIO.sfx_click)
            print("=== 进入玩家详情 ===")
            elseif equipScreenState.selectDecompCancelBtn and HitRect(equipScreenState.selectDecompCancelBtn) then
                equipScreenState.selectDecompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        -- 选中模式底部操作栏按钮
        if equipScreenState.selectMode then
            -- 取消按钮
            if equipScreenState.selectCancelBtn and HitRect(equipScreenState.selectCancelBtn) then
                equipScreenState.selectMode = false
                equipScreenState.selectedUids = {}
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 确认分解按钮 → 弹出确认弹窗
            if equipScreenState.selectConfirmBtn and HitRect(equipScreenState.selectConfirmBtn) then
                local sc, sg = CalcSelectDecomposeStats(equipScreenState.selectedUids)
                equipScreenState.selectDecompConfirm = { count = sc, gain = sg }
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 全选按钮
            if equipScreenState.selectAllBtn and HitRect(equipScreenState.selectAllBtn) then
                -- 全选当前所有未装备兵甲
                for _, itm in ipairs(playerEquipment.owned) do
                    if not itm.heroIdx then
                        equipScreenState.selectedUids[itm.uid] = true
                    end
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 返回按钮
        if HitRect(equipBackBtnRect) then
            if equipScreenState.selectMode then
                equipScreenState.selectMode = false
                equipScreenState.selectedUids = {}
            else
                PopPhase("MENU")
                phaseChangeCooldown = 0.3
                print("=== 返回上一页 ===")
            end
            return
        end
        -- 点击选中分解按钮 → 进入选中模式
        if equipScreenState.selectDecompBtn and HitRect(equipScreenState.selectDecompBtn) then
            equipScreenState.selectMode = true
            equipScreenState.selectedUids = {}
            PlaySFX(AUDIO.sfx_click)
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "选中要分解的兵甲", 1.0, { 100, 180, 255 }, 18)
            return
        end
                        -- 空孔位 → 直接打开替换弹窗(装备)
        if equipScreenState.batchDecompBtn and HitRect(equipScreenState.batchDecompBtn) then
            local ft = equipScreenState.batchFilterMaxTier or 6
            local fc, fg = CalcBatchDecomposeStats(ft)
            equipScreenState.batchDecompConfirm = {
                count = fc,
                gain = fg,
            }
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 点击强化按钮 → 弹出确认弹窗
        if equipEnhanceBtnRect and HitRect(equipEnhanceBtnRect) then
            local slotIdx = equipScreenState.selectedSlot
            local eqItem = GetEquippedItem(slotIdx, equipScreenState.selectedHero)
            if eqItem then
                local eqEnhLv = eqItem.enhanceLv or 0
                local enhCost = ENHANCE_COST[eqEnhLv + 1] or 999
                equipScreenState.enhanceConfirm = {
                    slotIdx = slotIdx,
                    enhLv = eqEnhLv,
                    cost = enhCost,
                }
            end
            return
        end
        -- 点击装备槽位切换选中
        for si, rect in pairs(equipSlotRects) do
            if HitRect(rect) then
                equipScreenState.selectedSlot = si
                equipScreenState.scrollY = 0
                equipScreenState.scrollVel = 0
                -- 消除该槽位的红点（确认已查看）
                redDotState.equipAck[si] = GetBestUnequippedScoreForSlot(si)
                return
            end
        end
        -- 装备列表区域：纯滚动拖拽（装备/卸下通过槽位操作）
        equipScreenState.isDragging = true
        equipScreenState.dragStartY = dy
        equipScreenState.dragLastY = dy
        equipScreenState.scrollVel = 0
        return
    end

    if longPressState.active then
        longPressState.active = false
        longPressState.pressing = false
        longPressState.card = nil
        return
    end

    -- 信息弹窗打开时: 点击任意区域关闭
    if infoPopupState.show then
        infoPopupState.show = false
        infoPopupState.card = nil
        return
    end

    pressStartSX = sx
    pressStartSY = sy

    local lx, ly = ScreenToLogical(sx, sy)
    local dx, dy = ScreenToDesign(sx, sy)

    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    -- 邮件系统
    if gameState.phase == "MAIL_BOX" then
        -- 返回按钮
        if menuBtnRects.mailBack and HitRect(menuBtnRects.mailBack) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            welfareState.mail.confirmPopup = nil
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- ======== 写信弹窗交互（管理员专用，代码在 admin/ 目录） ========
        if IS_ADMIN_BUILD and _AdminMailInput and welfareState.mail.composing and welfareState.mail.composeData then
            if _AdminMailInput.HandleComposeClick() then return end
        end

        -- ======== 确认弹窗交互（次高优先级） ========
        if welfareState.mail.confirmPopup then
            local popup = welfareState.mail.confirmPopup
            if popup.confirmBtnRect and HitRect(popup.confirmBtnRect) then
                if popup.cloudMail then
                    -- 云邮件领取
                    local cm = popup.cloudMail
                    if not CloudManager.IsMailClaimed(cm.id) then
                        CloudManager.ClaimMail(cm.id)
                        -- 安全验证：只有管理员发送的邮件才能发放奖励
                        local senderIsAdmin = CloudManager.IsAdmin and CloudManager.IsAdmin(cm.from) or false
                        local safeRewards = senderIsAdmin and (cm.rewards or {}) or {}
                        if not senderIsAdmin and cm.rewards and #cm.rewards > 0 then
                            print("[安全] 非管理员邮件含奖励，已忽略: from=" .. tostring(cm.from))
                        end
                        for _, rw in ipairs(safeRewards) do
                            if rw.type == "jade" then
                                playerInfo.jade = playerInfo.jade + rw.amount
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                                    "+" .. rw.amount .. " 玉壁", 1.5, { 255, 220, 100 }, 18)
                            elseif rw.type == "ad_free" then
                                playerInfo.ad_free = true
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                    "获得免广告特权!", 1.5, { 100, 255, 150 }, 18)
                            elseif rw.type == "full_skill" then
                                local skIdx = rw.skillIdx
                                if skIdx then
                                    skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                                    local skName = SKILL_TECHNIQUES[skIdx] and SKILL_TECHNIQUES[skIdx].name or ("武技#" .. skIdx)
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                        "获得武技「" .. skName .. "」", 1.5, { 200, 160, 255 }, 18)
                                end
                            elseif rw.type == "seal" then
                                local heroIdx = rw.fromHero
                                local slotType = rw.slotType
                                local sealQ = rw.sealQ or 1
                                if heroIdx and slotType then
                                    -- 直接装备到武灵孔位上（覆盖旧的）
                                    if not sealData[heroIdx] then sealData[heroIdx] = { slots = {} } end
                                    sealData[heroIdx].slots[slotType] = { sealQ = sealQ, level = rw.level or 1, exp = 0 }
                                    local heroName = HERO_CARDS[heroIdx] and HERO_CARDS[heroIdx].name or ("武灵#" .. heroIdx)
                                    local tierName = SEAL_TIER_NAMES[sealQ] or "未知"
                                    local slotName = SEAL_SLOT_NAMES[slotType] or ("孔" .. slotType)
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                        heroName .. " 鑾峰緱" .. tierName .. slotName, 1.5, { 180, 140, 255 }, 18)
                                end
                            end
                        end
                        SaveGameProgress()
                        print("=== 云邮件领取: " .. (cm.subject or cm.id) .. " ===")
                    end
                else
                    -- 系统邮件领取
                    local mail = welfareState.mailDefs[popup.mailIdx]
                    if mail and not welfareState.mail.claimed[mail.id] then
                        welfareState.mail.claimed[mail.id] = true
                        for _, rw in ipairs(mail.rewards) do
                            if rw.type == "jade" then
                                playerInfo.jade = playerInfo.jade + rw.amount
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                                    "+" .. rw.amount .. " 玉壁", 1.5, { 255, 220, 100 }, 18)
                            elseif rw.type == "full_skill" then
                                local skIdx = rw.skillIdx
                                skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                                local skName = SKILL_TECHNIQUES[skIdx] and SKILL_TECHNIQUES[skIdx].name or ("武技#" .. skIdx)
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                    "获得武技「" .. skName .. "」", 1.5, { 200, 160, 255 }, 18)
                            end
                        end
                        SaveGameProgress()
                        print("=== 邮件领取: " .. mail.title .. " ===")
                    end
                end
                welfareState.mail.confirmPopup = nil
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if popup.closeBtnRect and HitRect(popup.closeBtnRect) then
                welfareState.mail.confirmPopup = nil
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if popup.bgRect and not HitRect(popup.bgRect) then
                welfareState.mail.confirmPopup = nil
                return
            end
            return  -- 弹窗打开时拦截
        end

        -- ======== Tab 切换 ========
        if menuBtnRects["mailTab_system"] and HitRect(menuBtnRects["mailTab_system"]) then
            if welfareState.mail.tab ~= "system" then
                welfareState.mail.tab = "system"
                if welfareState.mail.scroll then welfareState.mail.scroll.offset = 0; welfareState.mail.scroll.vel = 0 end
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        if menuBtnRects["mailTab_cloud"] and HitRect(menuBtnRects["mailTab_cloud"]) then
            if welfareState.mail.tab ~= "cloud" then
                welfareState.mail.tab = "cloud"
                if welfareState.mail.scroll then welfareState.mail.scroll.offset = 0; welfareState.mail.scroll.vel = 0 end
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end

        -- ======== 云邮件 Tab 按钮 ========
        if welfareState.mail.tab == "cloud" then
            -- 管理员按钮（写信/发奖励/玩家管理，代码在 admin/ 目录）
            if IS_ADMIN_BUILD and _AdminMailInput then
                if _AdminMailInput.HandleAdminButtonClick() then return end
            end
            -- 刷新按钮
            if menuBtnRects.mailRefresh and HitRect(menuBtnRects.mailRefresh) then
                CloudManager.ForceRefreshInbox(function()
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "邮件已刷新", 1.2, {140,220,180}, 18)
                end)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 云邮件领取按钮
            for i, btnRect in pairs(welfareState.mail.cloudBtnRects or {}) do
                if btnRect and HitRect(btnRect) then
                    local inbox = CloudManager._mailInbox or {}
                    local cm = inbox[i]
                    if cm and not CloudManager.IsMailClaimed(cm.id) then
                        welfareState.mail.confirmPopup = { cloudMail = cm }
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
        end

        -- ======== 云邮件 Tab 按钮 ========
        if welfareState.mail.tab == "system" then
            for i, btnRect in pairs(welfareState.mail.btnRects) do
                if btnRect and HitRect(btnRect) then
                    local mail = welfareState.mailDefs[i]
                    if mail and not welfareState.mail.claimed[mail.id] then
                        welfareState.mail.confirmPopup = { mailIdx = i }
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            -- 非管理员: 系统邮件Tab中的云邮件领取按钮
            if not CloudManager.IsAdmin() then
                for i, btnRect in pairs(welfareState.mail.cloudBtnRects or {}) do
                    if btnRect and HitRect(btnRect) then
                        local cloudInbox = CloudManager._mailInbox or {}
                        local cm = cloudInbox[i]
                        if cm and not CloudManager.IsMailClaimed(cm.id) then
                            welfareState.mail.confirmPopup = { cloudMail = cm }
                            PlaySFX(AUDIO.sfx_click)
                        end
                        return
                    end
                end
            end
        end

        -- 没有命中按钮，开始滚动拖拽
        local _, dy2 = ScreenToDesign(sx, sy)
        if welfareState.mail.scroll then
            welfareState.mail.scroll.isDragging = true
            welfareState.mail.scroll.dragStartY = dy2
            welfareState.mail.scroll.dragLastY = dy2
            welfareState.mail.scroll.vel = 0
        end
        return
    end

    -- ======== 交易行界面点击处理 ========
    if gameState.phase == "TRADE" then
        -- 确认弹窗优先
        if tradeState.confirmPopup then
            local pop = tradeState.confirmPopup
            -- 上架定价弹窗: 价格 +/-
            if pop.type == "list_item" then
                if tradeState.btnRects.priceMinus and HitRect(tradeState.btnRects.priceMinus) then
                    local d = pop.data
                    local step = d.price <= 50 and 5 or (d.price <= 500 and 10 or (d.price <= 5000 and 50 or 500))
                    d.price = math.max(d.minPrice, d.price - step)
                    PlaySFX(AUDIO.sfx_click); return
                end
                if tradeState.btnRects.pricePlus and HitRect(tradeState.btnRects.pricePlus) then
                    local d = pop.data
                    local step = d.price < 50 and 5 or (d.price < 500 and 10 or (d.price < 5000 and 50 or 500))
                    d.price = math.min(d.maxPrice, d.price + step)
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
            if tradeState.btnRects.popupYes and HitRect(tradeState.btnRects.popupYes) then
                tradeState.confirmPopup = nil
                PlaySFX(AUDIO.sfx_click)
                if pop.type == "buy" then
                    local d = pop.data
                    TradeManager.BuyItem(d.listingKey, d.sellerId, d.price, function(ok, msg)
                        ShowToast(msg)
                        if ok then TradeManager.RefreshMarket() end
                    end)
                elseif pop.type == "unlist" then
                    TradeManager.UnlistItem(pop.data.listingKey, function(ok, msg)
                        ShowToast(msg)
                    end)
                elseif pop.type == "claim_expired" then
                    TradeManager.ClaimExpired(pop.data.listingKey, function(ok, msg)
                        ShowToast(msg)
                    end)
                elseif pop.type == "list_item" then
                    local d = pop.data
                    TradeManager.ListItem(d.uid, d.price, function(ok, msg)
                        ShowToast(msg)
                        if ok then TradeManager.RefreshMarket() end
                    end)
                end
                return
            end
            if tradeState.btnRects.popupNo and HitRect(tradeState.btnRects.popupNo) then
                tradeState.confirmPopup = nil; PlaySFX(AUDIO.sfx_click); return
            end
            if tradeState.btnRects.popupBg and not HitRect(tradeState.btnRects.popupBg) then
                tradeState.confirmPopup = nil; return
            end
            return
        end
        -- 杩斿洖
        if tradeState.btnRects.back and HitRect(tradeState.btnRects.back) then
            PopPhase(); PlaySFX(AUDIO.sfx_click); return
        end
        -- Tab切换
        if tradeState.btnRects.tabMarket and HitRect(tradeState.btnRects.tabMarket) then
            tradeState.tab = "market"; tradeState.scroll.offset = 0; tradeState.scroll.vel = 0
            tradeState.selectedItem = nil; PlaySFX(AUDIO.sfx_click); return
        end
        if tradeState.btnRects.tabMine and HitRect(tradeState.btnRects.tabMine) then
            tradeState.tab = "mine"; tradeState.scroll.offset = 0; tradeState.scroll.vel = 0
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 刷新按钮
        if tradeState.btnRects.refresh and HitRect(tradeState.btnRects.refresh) then
            TradeManager.RefreshMarket(function()
                ShowToast("市场已刷新")
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 分页: 上一页
        if tradeState.btnRects.prevPage and HitRect(tradeState.btnRects.prevPage) then
            local curPage = TradeManager.state.marketPage or 1
            if curPage > 1 then
                TradeManager.state.lastRefreshTime = 0  -- 清除冷却
                tradeState.scroll.offset = 0; tradeState.scroll.vel = 0
                TradeManager.RefreshMarket(curPage - 1, function()
                    ShowToast("第 " .. (curPage - 1) .. " 页")
                end)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 分页: 下一页
        if tradeState.btnRects.nextPage and HitRect(tradeState.btnRects.nextPage) then
            if TradeManager.state.marketHasNextPage then
                local curPage = TradeManager.state.marketPage or 1
                TradeManager.state.lastRefreshTime = 0  -- 清除冷却
                tradeState.scroll.offset = 0; tradeState.scroll.vel = 0
                TradeManager.RefreshMarket(curPage + 1, function()
                    ShowToast("第 " .. (curPage + 1) .. " 页")
                end)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 领取玉壁按钮
        if tradeState.btnRects.claimJade and HitRect(tradeState.btnRects.claimJade) then
            TradeManager.ClaimJade(function(amount)
                if amount > 0 then
                    ShowToast("领取 " .. amount .. " 玉壁")
                else
                    ShowToast("暂无可领取玉壁")
                end
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 名字选择 (含自定义选项)
        if tradeState.tab == "market" then
            local items = tradeState._filteredMarketItems or TradeManager.state.marketItems or {}
            for i, _ in ipairs(items) do
                local rect = tradeState.btnRects["market_" .. i]
                if rect and HitRect(rect) then
                    local item = items[i]
                    if item.isMine then
                        ShowToast("不能购买自己上架的装备")
                        PlaySFX(AUDIO.sfx_click); return
                    end
                    tradeState.confirmPopup = {
                        type = "buy",
                        data = { listingKey = item.listingKey, sellerId = item.sellerId, price = item.price, equip = item.equip, sellerName = item.sellerName },
                    }
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
        -- 我的上架列表点击 (下架/领取)
        if tradeState.tab == "mine" then
            -- 在售items
            local active = TradeManager.GetActiveListings()
            for i, al in ipairs(active) do
                local rect = tradeState.btnRects["unlist_" .. i]
                if rect and HitRect(rect) then
                    tradeState.confirmPopup = { type = "unlist", data = { listingKey = al.key, listing = al.listing } }
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
            -- 杩囨湡items
            local expired = TradeManager.GetExpiredListings()
            for i, ek in ipairs(expired) do
                local rect = tradeState.btnRects["claim_" .. i]
                if rect and HitRect(rect) then
                    tradeState.confirmPopup = { type = "claim_expired", data = { listingKey = ek } }
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
            -- 可交易物品上架按钮
            local tItems = tradeState.tradeableItems or {}
            for i, item in ipairs(tItems) do
                local rect = tradeState.btnRects["list_" .. i]
                if rect and HitRect(rect) then
                    -- 检查上架数量限制
                    if TradeManager.GetListingCount() >= GameConfig.TRADE.MAX_LISTINGS then
                        ShowToast("上架数量已达上限(" .. GameConfig.TRADE.MAX_LISTINGS .. "件)")
                        PlaySFX(AUDIO.sfx_click); return
                    end
                    -- 打开定价弹窗
                    local pMin, pMax = TradeManager.GetPriceRange(item.tier)
                    local midPrice = math.floor((pMin + pMax) / 2)
                    if item.tier >= 6 then midPrice = pMin end
                    tradeState.confirmPopup = {
                        type = "list_item",
                        data = {
                            uid = item.uid, setIdx = item.setIdx, slotIdx = item.slotIdx,
                            tier = item.tier, quality = item.quality, level = item.level,
                            enhanceLv = item.enhanceLv,
                            price = midPrice, minPrice = pMin, maxPrice = pMax,
                        },
                    }
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
        -- 没有命中按钮，开始滚动拖拽
        tradeState.scroll.isDragging = true
        tradeState.scroll.dragStartY = dy
        tradeState.scroll.dragLastY = dy
        tradeState.scroll.vel = 0
        return
    end

    -- 战力排行榜独立界面

    return false  -- 未匹配任何 phase
end

return M
