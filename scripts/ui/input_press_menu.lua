-- ============================================================================
-- ui/input_press_menu.lua - 主菜单点击处理
-- 用途: BeginPress 子处理器 - MENU
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
    if gameState.phase == "MENU" then
        -- 防穿透：刚从其他界面返回时忽略点击
        if phaseChangeCooldown > 0 then return end

        local dx, dy = ScreenToDesign(sx, sy)
        -- 辅助: 检测点是否在矩形内
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
    -- ======== 战役模式选择弹窗 (最高优先级拦截) ========
        if gameState.campaignModePopup then
            if menuBtnRects.campaignTD and HitRect(menuBtnRects.campaignTD) then
                gameState.campaignModePopup = false
                PushPhase("TD_SELECT")
                phaseChangeCooldown = 0.3
                PlaySFX(AUDIO.sfx_click)
                print("=== 进入放置守城 ===")
                return
            end
            if menuBtnRects.campaignBattle and HitRect(menuBtnRects.campaignBattle) then
                if rawget(_G, "ShowToast") then ShowToast("暂未开放") end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if menuBtnRects.campaignClose and HitRect(menuBtnRects.campaignClose) then
                gameState.campaignModePopup = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 弹窗打开时吞掉所有点击
            return
        end

    -- ======== 统一规则弹窗交互 (全局最高优先级) ========
        if settingsPage.btnAdjustMode then
            -- 组切换标签点击
            if settingsPage.adjGroupBtnRects then
                for _, gr in ipairs(settingsPage.adjGroupBtnRects) do
                    if HitRect(gr) then
                        settingsPage.adjActiveGroup = gr.key
                        PlaySFX(AUDIO.sfx_click)
                        return
                    end
                end
            end
        -- 名字选择 (含自定义选项)
            if HitRect(settingsPage.adjSaveBtnRect) then
                gameSettings.btnOffsetX = settingsPage.adjOffsetX
                gameSettings.btnOffsetY = settingsPage.adjOffsetY
                gameSettings.btnScale = settingsPage.adjScale
                gameSettings.rightBtnOffsetX = settingsPage.adjRightBtnOffsetX
                gameSettings.rightBtnOffsetY = settingsPage.adjRightBtnOffsetY
                gameSettings.infoPanelOffsetX = settingsPage.adjInfoPanelOffsetX
                gameSettings.infoPanelOffsetY = settingsPage.adjInfoPanelOffsetY
                gameSettings.hudOffsetX = settingsPage.adjHudOffsetX
                gameSettings.hudOffsetY = settingsPage.adjHudOffsetY
                SaveSettings()
                settingsPage.btnAdjustMode = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
        -- 名字选择 (含自定义选项)
            if HitRect(settingsPage.adjResetBtnRect) then
                local ag = settingsPage.adjActiveGroup or "skill"
                if ag == "skill" then
                    settingsPage.adjOffsetX = 0
                    settingsPage.adjOffsetY = 0
                    settingsPage.adjScale = 1.0
                elseif ag == "rightBtn" then
                    settingsPage.adjRightBtnOffsetX = 0
                    settingsPage.adjRightBtnOffsetY = 0
                elseif ag == "infoPanel" then
                    settingsPage.adjInfoPanelOffsetX = 0
                    settingsPage.adjInfoPanelOffsetY = 0
                elseif ag == "hud" then
                    settingsPage.adjHudOffsetX = 0
                    settingsPage.adjHudOffsetY = 0
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 返回按钮
            if HitRect(settingsPage.adjBackBtnRect) then
                settingsPage.btnAdjustMode = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 缩放滑条拖拽开始 (仅技能组)
            if settingsPage.adjScaleSliderRect and HitRect(settingsPage.adjScaleSliderRect) then
                settingsPage.adjDraggingScale = true
                local r = settingsPage.adjScaleSliderRect
                local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
                settingsPage.adjScale = 0.5 + ratio * 1.5  -- 0.5~2.0
                return
            end
            -- 拖拽当前选中组（点击战斗区域内任意位置开始拖拽）
            settingsPage.adjDragging = true
            settingsPage.adjDragStartX = dx
            settingsPage.adjDragStartY = dy
            return
        end

        -- 玩家面板点击 >> 进入玩家详情
        if HitRect(playerDetailBtnRect) then
            playerDetailScroll.y = 0; playerDetailScroll.vel = 0
            PushPhase("PLAYER_DETAIL")
            print("=== 进入玩家详情 ===")
            return
        end
        -- 广告获取玉壁
        if HitRect(adRects.jade) then
            WatchAdForJade()
            return
        end

        -- ======== CDK 弹窗交互 (最高优先级) ========
        if cdkState.inputOpen then
            if HitRect(cdkState.redeemBtnRect) then
                TryRedeemCDK()
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(cdkState.clearBtnRect) then
                cdkState.inputText = ""
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(cdkState.closeBtnRect) then
                cdkState.inputOpen = false
                cdkState.inputText = ""
                input:SetScreenKeyboardVisible(false)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 粘贴按钮
            if cdkState.pasteBtnRect and HitRect(cdkState.pasteBtnRect) then
                local clipText = SafeGetClipboard()
                print("=== CDK粘贴: clipText=[" .. tostring(clipText) .. "] ===")
                if clipText and #clipText > 0 then
                    local cleaned = clipText:upper():gsub("[^A-Z0-9%-]", "")
                    if #cleaned > 20 then cleaned = cleaned:sub(1, 20) end
                    cdkState.inputText = cleaned
                    print("=== 粘贴兑换码: " .. cleaned .. " ===")
                else
                    input:SetScreenKeyboardVisible(true)
                    cdkState.resultText = "请在键盘中长按输入框粘贴"
                    cdkState.resultTimer = 3.0
                    cdkState.resultOk = false
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 点击弹窗区域内消费事件(原生键盘处理输入)
            return
        end

        -- ======== 战力说明弹窗交互 ========
        if powerExplainPopup.show then
            local cr = powerExplainPopup.closeBtnRect
            if cr and HitRect(cr) then
                powerExplainPopup.show = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 点击弹窗外关闭
            local pr = powerExplainPopup.panelRect
            if not (pr and HitRect(pr)) then
                powerExplainPopup.show = false
            end
            return
        end

        -- ======== 设置界面交互 (优先拦截) ========
        if settingsPage.isOpen then
            -- 关闭按钮
            if HitRect(settingsPage.closeBtnRect) then
                settingsPage.isOpen = false
                settingsPage.draggingMusic = false
                settingsPage.draggingSfx = false
                PlaySFX(AUDIO.sfx_click)
                return
            end



            -- UID 复制按钮
            if settingsPage.uidCopyBtnRect and HitRect(settingsPage.uidCopyBtnRect) then
                local uidStr = settingsPage.uidValue or ""
                if uidStr ~= "" and uidStr ~= "---" then
                    local sysOk = SafeSetClipboard(uidStr)
                    settingsPage.uidCopyTimer = 2.5
                    if sysOk then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "UID已复制: " .. uidStr, 1.5, { 100, 220, 160 }, 18)
                    else
                        -- 系统剪贴板不可用，已存入游戏内剪贴板，同时提示截图
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.30, "UID已复制(游戏内)", 2.5, { 100, 220, 160 }, 18)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.36, uidStr, 3.0, { 255, 220, 80 }, 22)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.42, "发邮件可直接粘贴 / 截图保存", 2.5, { 180, 180, 180 }, 18)
                    end
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end



            -- CDK 兑换按钮
            if HitRect(settingsPage.cdkBtnRect) then
                cdkState.inputOpen = true
                cdkState.inputText = ""
                cdkState.resultTimer = 0
                input:SetScreenKeyboardVisible(true)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 音乐滑条拖拽开始
            if HitRect(settingsPage.musicSliderRect) then
                settingsPage.draggingMusic = true
                local r = settingsPage.musicSliderRect
                local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
                gameSettings.musicVolume = ratio
                if audioState.bgmSource then audioState.bgmSource.gain = ratio end
                return
            end
            -- 音效滑条拖拽开始
            if HitRect(settingsPage.sfxSliderRect) then
                settingsPage.draggingSfx = true
                local r = settingsPage.sfxSliderRect
                local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
                gameSettings.sfxVolume = ratio
                return
            end
            -- 精灵上限滑条拖拽开始
            if HitRect(settingsPage.spriteLimitSliderRect) then
                settingsPage.draggingSpriteLimit = true
                local r = settingsPage.spriteLimitSliderRect
                local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
                gameSettings.spriteLimit = math.floor(500 + ratio * 4500 + 0.5)
                -- 对齐到50的整数倍
                gameSettings.spriteLimit = math.floor(gameSettings.spriteLimit / 50 + 0.5) * 50
                gameSettings.spriteLimit = math.max(500, math.min(5000, gameSettings.spriteLimit))
                return
            end
            -- 点击遮罩区域 >> 消费事件不穿透
            return
        end

        if HitRect(settingsPage.btnRect) then
            settingsPage.isOpen = true
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 右侧卷轴面板按钮
        if menuBtnRects.rpBattle and HitRect(menuBtnRects.rpBattle) then
            -- 天下征途 → 进入SLG世界地图
            PlaySFX(AUDIO.sfx_click)
            WorldMap.Init()
            PushPhase("WORLD_MAP")
            phaseChangeCooldown = 0.3
            print("=== 进入天下征途 ===")
            return
        end
        if menuBtnRects.rpSettings and HitRect(menuBtnRects.rpSettings) then
            -- 打开设置页
            PlaySFX(AUDIO.sfx_click)
            settingsPage.isOpen = true
            return
        end
        -- 战力说明"?"按钮 (在玩家面板点击之前拦截)
        if menuBtnRects.powerHelp and HitRect(menuBtnRects.powerHelp) then
            powerExplainPopup.show = true
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 下载面板交互
        if downloadUI.panelOpen and downloadUI.panelRect and HitRect(downloadUI.panelRect) then
            -- 点击面板内部 >> 消费事件不穿透
            return
        end
        if downloadUI.btnRect and HitRect(downloadUI.btnRect) then
            downloadUI.panelOpen = not downloadUI.panelOpen
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 点击其他区域时收起面板
        if downloadUI.panelOpen then
            downloadUI.panelOpen = false
        end

        -- ======== 左侧栏拖拽/点击处理 ========
        if leftSidebarScroll.areaRect then
            local ar = leftSidebarScroll.areaRect
            if dx >= ar.x and dx <= ar.x + ar.w and dy >= ar.y and dy <= ar.y + ar.h then
                local maxScroll = math.max(0, leftSidebarScroll.contentH - leftSidebarScroll.viewH)
                if maxScroll > 0 then
                    -- 有滚动需求 → 记录拖拽起点，EndPress 判断是点击还是拖拽
                    leftSidebarScroll.isDragging = true
                    leftSidebarScroll.dragStartY = dy
                    leftSidebarScroll.dragLastY = dy
                    leftSidebarScroll.vel = 0
            return  -- 弹窗打开时拦截所有其他点击
                else
                    -- 无滚动 → 直接处理按钮点击
                    HandleSidebarButtonClick(dx, dy)
                    return
                end
            end
        end

        -- ======== 世界聊天点击处理 ========
        if worldChatUI.expanded then
            -- 展开模式: 优先拦截所有点击
            if menuBtnRects.worldChatClose and HitRect(menuBtnRects.worldChatClose) then
                worldChatUI.expanded = false
                worldChatUI.inputActive = false
                worldChatUI.chatInput = ""
                input:SetScreenKeyboardVisible(false)
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 添加好友弹出按钮
            if menuBtnRects.worldChatAddFriend and HitRect(menuBtnRects.worldChatAddFriend) then
                local targetUid = menuBtnRects.worldChatAddFriend.uid
                local targetName = menuBtnRects.worldChatAddFriend.name or "?"
                local myUid = CloudAPI.GetUserId()
                if targetUid == myUid then
                    ShowToast("不能添加自己为好友")
                else
                    CloudManager.SendFriendRequest(targetUid, "")
                    playerInfo.totalFriendReqs = (playerInfo.totalFriendReqs or 0) + 1
                    ShowToast("已向「" .. targetName .. "」发送好友请求")
                end
                worldChatUI.namePopup = nil
                PlaySFX(AUDIO.sfx_click); return
            end
            if menuBtnRects.worldChatSend and HitRect(menuBtnRects.worldChatSend) then
                if worldChatUI.chatInput and #worldChatUI.chatInput > 0 then
                    local filteredText = FilterBannedWords(worldChatUI.chatInput)
                    local senderName = CloudManager._myTapNickname or factionUI.myNickname or playerInfo.name or "无名"
                    CloudManager.SendWorldChat(filteredText, senderName)
                    worldChatUI.chatInput = ""
                    worldChatUI.inputActive = false
                    input:SetScreenKeyboardVisible(false)
                end
                worldChatUI.namePopup = nil
                PlaySFX(AUDIO.sfx_click); return
            end
            if menuBtnRects.worldChatInput and HitRect(menuBtnRects.worldChatInput) then
                worldChatUI.inputActive = true
                worldChatUI.namePopup = nil
                input:SetScreenKeyboardVisible(true)
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 点击弹窗区域内不关闭
            if menuBtnRects.worldChatPopupArea and HitRect(menuBtnRects.worldChatPopupArea) then
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 点击头像弹出玩家信息
            if worldChatUI._avatarRects then
                for _, nr in ipairs(worldChatUI._avatarRects) do
                    if HitRect(nr) then
                        if worldChatUI.namePopup and worldChatUI.namePopup.uid == nr.uid then
                            worldChatUI.namePopup = nil  -- 再次点击同一头像关闭
                        else
                            worldChatUI.namePopup = { uid = nr.uid, name = nr.name, x = nr.x, y = nr.y, av = nr.av }
                        end
                        PlaySFX(AUDIO.sfx_click); return
                    end
                end
            end
            -- 点击窗口外部关闭
            worldChatUI.expanded = false
            worldChatUI.inputActive = false
            worldChatUI.chatInput = ""
            worldChatUI.namePopup = nil
            input:SetScreenKeyboardVisible(false)
            PlaySFX(AUDIO.sfx_click); return
        end
        if menuBtnRects.worldChatMini and HitRect(menuBtnRects.worldChatMini) then
            worldChatUI.expanded = true
            worldChatUI.lastMsgCount = 0  -- 触发自动滚到底
            CloudManager.PollWorldChat()  -- 立即拉取
            PlaySFX(AUDIO.sfx_click); return
        end

        if menuBtnRects.gachaSeal and HitRect(menuBtnRects.gachaSeal) then
            -- 召唤入口（页签: 兵符召唤 / 武将召唤）
            summonTab = summonTab or 1  -- 1=兵符召唤, 2=武将召唤
            PushPhase("SUMMON")
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入召唤 ===")
        elseif HitRect(menuBtnRects.codex) then
            -- 武将录
            if not moduleState.heroes.ready then
                local pct = math.floor(moduleState.heroes.progress * 100)
                ShowToast("武灵资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("CODEX")
            codexScroll.y = 0
            codexScroll.vel = 0
            phaseChangeCooldown = 0.3
            print("=== 进入武将录 ===")
        elseif HitRect(menuBtnRects.equip) then
            -- 兵甲（需要兵甲模块）
            if not moduleState.equipment.ready then
                local pct = math.floor(moduleState.equipment.progress * 100)
                ShowToast("兵甲资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("EQUIP")
            -- 自动选中有红点的槽位（帮助玩家找到新装备）
            local autoSlot = 1
            for si = 1, 7 do
                if HasEquipSlotRedDot(si) then autoSlot = si; break end
            end
            equipScreenState.selectedSlot = autoSlot
            equipScreenState.scrollY = 0
            -- 传递 NanoVG 上下文和精灵图句柄给覆盖层
            EquipUI._vg = vg
            EquipUI._equipSheet = IMG.equipmentSheet
            EquipUI._sheetCols = EQUIP_SHEET_COLS
            EquipUI._sheetRows = EQUIP_SHEET_ROWS
            -- 显示NanoVG网格仓库
            EquipUI.Show()
            -- 不再立即消除所有红点，改为点击槽位时逐个消除
            print("=== 进入玩家详情 ===")
        elseif HitRect(menuBtnRects.equipCodex) then
            -- 兵甲图录（需要兵甲模块）
            if not moduleState.equipment.ready then
                local pct = math.floor(moduleState.equipment.progress * 100)
                ShowToast("兵甲资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("EQUIP_CODEX")
            print("=== 进入玩家详情 ===")
        elseif HitRect(menuBtnRects.skillCodex) then
            -- 武技（需要武技模块）
            if not moduleState.skills.ready then
                local pct = math.floor(moduleState.skills.progress * 100)
                ShowToast("武技资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("SKILL_CODEX")
            skillCodexState.scrollY = 0
            skillCodexState.scrollVel = 0
            phaseChangeCooldown = 0.3
            DismissSkillRedDots()
            print("=== 进入玩家详情 ===")
        elseif HitRect(menuBtnRects.welfare) then
            -- 天命赐福
            PushPhase("WELFARE")
            phaseChangeCooldown = 0.3
            welfareState.contribLoaded = false  -- 每次进入刷新贡献榜
            welfareState.contribLoading = false -- 重置加载锁，防止卡住
            welfareState.powerLoaded = false    -- 每次进入刷新战力榜
            welfareState.powerLoading = false   -- 重置加载锁
            welfareState.contribScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            welfareState.powerScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            welfareState.scroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            LoadContribRank()
            ReportPowerScore()
            LoadPowerRank()
            print("=== 进入玩家详情 ===")
        elseif menuBtnRects.trade and HitRect(menuBtnRects.trade) then
            -- 交易行
            PushPhase("TRADE")
            phaseChangeCooldown = 0.3
            tradeState.tab = "market"
            tradeState.scroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil }
            tradeState.selectedItem = nil
            tradeState.confirmPopup = nil
            tradeState.btnRects = {}
            TradeManager.Init()
            TradeManager.ResetCheckSalesCD()  -- 进入交易行时立即检查收款
            TradeManager.RefreshMarket()
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入交易行 ===")
        elseif menuBtnRects.mailBox and HitRect(menuBtnRects.mailBox) then
            -- 邮件系统
            PushPhase("MAIL_BOX")
            phaseChangeCooldown = 0.3
            welfareState.mail.scroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            welfareState.mail.btnRects = {}
            welfareState.mail.cloudBtnRects = {}
            welfareState.mail.confirmPopup = nil
            welfareState.mail.composing = false
            welfareState.mail.composeData = nil
            welfareState.mail.adminPanel = false
            -- 首次进入时轮询云邮件
            CloudManager.PollInbox()
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入玩家详情 ===")
        elseif menuBtnRects.faction and HitRect(menuBtnRects.faction) then
            -- 阵营系统
            PushPhase("FACTION")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入玩家详情 ===")
        elseif menuBtnRects.friends and HitRect(menuBtnRects.friends) then
            -- 好友系统
            PushPhase("FRIENDS")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入玩家详情 ===")
        elseif menuBtnRects.powerRank and HitRect(menuBtnRects.powerRank) then
            -- 战力排行榜独立界面
            PushPhase("POWER_RANK")
            phaseChangeCooldown = 0.3
            welfareState.powerLoaded = false
            welfareState.powerLoading = false
            welfareState.powerScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            welfareState.realmLoaded = false
            welfareState.realmLoading = false
            welfareState.realmScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            welfareState.rankTab = "power"
            ReportPowerScore()
            ReportRealmScore()
            LoadPowerRank()
            LoadRealmRank()
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入战力排行榜 ===")
        elseif menuBtnRects.progress and HitRect(menuBtnRects.progress) then
            -- 每日任务 / 周任务 / 成就
            CheckDailyReset()
            CheckWeeklyReset()
            progressUIState.tab = 1
            progressUIState.scrollY = 0
            PushPhase("PROGRESS")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入玩家详情 ===")
        elseif menuBtnRects.battlepass and HitRect(menuBtnRects.battlepass) then
            -- 战令通行证
            CheckBattlePassSeason()
            CheckBattlePassDailyReset()
            CheckBattlePassWeeklyReset()
            battlePassUIState.tab = 1
            battlePassUIState.scrollY = 0
            battlePassUIState.rewardScrollX = 0
            PushPhase("BATTLE_PASS")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入战令通行证 ===")
        elseif menuBtnRects.campaign and HitRect(menuBtnRects.campaign) then
            -- 战役模式入口 —— 弹出选择弹窗
            gameState.campaignModePopup = true
            PlaySFX(AUDIO.sfx_click)
            print("=== 打开战役选择 ===")
        --[=[ 已移除: 讨伐/副本/探索 入口
        elseif abyssState.btnRect and HitRect(abyssState.btnRect) then
            PushPhase("ABYSS_SELECT")
        elseif dailyDungeonState.btnRect and HitRect(dailyDungeonState.btnRect) then
            PushPhase("DAILY_DUNGEON")
        elseif resourceDungeonState.btnRect and HitRect(resourceDungeonState.btnRect) then
            PushPhase("RESOURCE_DUNGEON")
        --]=]
        --[=[ 已移除: 爬塔/排位 入口
        elseif towerState.btnRect and HitRect(towerState.btnRect) then
            PushPhase("TOWER_SELECT")
        elseif rankedState.btnRect and HitRect(rankedState.btnRect) then
            PushPhase("RANKED_SELECT")
        --]=]
        end
        return
    end




    return false  -- 未匹配任何 phase
end

return M
