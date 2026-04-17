-- ui/input_begin_press.lua - 三国武灵录 (从 input.lua 拆分)
---@diagnostic disable: undefined-global
function BeginPress(sx, sy, touchId)
    local curFrame = time:GetFrameNumber()
    if curFrame == _lastPressFrame then return end
    _lastPressFrame = curFrame

    -- === LOADING 阶段点击提示 ===
    if gameState.phase == "LOADING" then
        loadingClickTipTimer = 2.5
        return
    end

    -- === 个人资料界面输入 ===
    if gameState.phase == "PROFILE" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 头像选择
        for i, rect in ipairs(profileAvatarRects) do
            if HitRect(rect) then
                profileState.selectedAvatar = i
                return
            end
        end
        -- 名字选择 (含自定义选项)
        for i, rect in ipairs(profileNameRects) do
            if HitRect(rect) then
                profileState.selectedName = i
                if i == CUSTOM_NAME_IDX then
                    -- 点击自定义: 启动文本输入
                    profileState.isInputActive = true
                    input:SetScreenKeyboardVisible(true)
                else
                    profileState.isInputActive = false
                    input:SetScreenKeyboardVisible(false)
                end
                return
            end
        end
        -- 确认按钮
        if HitRect(profileConfirmBtnRect) then
            -- (教程资源检查已移除，无需等待下载)
            playerInfo.avatarIdx = AVATAR_OPTIONS[profileState.selectedAvatar] or 1
            if profileState.selectedName == CUSTOM_NAME_IDX and #profileState.customName > 0 then
                playerInfo.name = profileState.customName
            else
                playerInfo.name = PRESET_NAMES[profileState.selectedName] or "无名武灵"
            end
            playerInfo.profileSet = true
            profileState.isInputActive = false
            input:SetScreenKeyboardVisible(false)
            -- 立即保存，确保 profileSet 状态持久化
            SaveGameProgress()
            -- 模块下载已在阻塞加载完成后自动启动（InitModuleDownloads）
            if profileState.editMode then
                -- 编辑模式：直接返回，不触发新手引导
                profileState.editMode = false
                PopPhase()
                print("=== 资料编辑完成: " .. playerInfo.name .. " ===")
            else
                gameState.phase = "MENU"
                print("=== 资料设置完成: " .. playerInfo.name .. " ===")
            end
        end
        return
    end

    -- ======== 统一规则弹窗交互 (全局最高优先级) ========
    if phaseRulePopup.show then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRectG(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        local cr = phaseRulePopup.closeBtnRect
        if cr and HitRectG(cr) then
            phaseRulePopup.show = false
            phaseRulePopup.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
        local pr = phaseRulePopup.panelRect
        if pr and HitRectG(pr) then
            phaseRulePopup.isDragging = true
            phaseRulePopup.lastTouchY = dy
            phaseRulePopup.vel = 0
        else
            phaseRulePopup.show = false
            phaseRulePopup.isDragging = false
        end
        return
    end

    -- ======== 统一 "?" 按钮点击检测 (全局) ========
    if phaseRulePopup.helpBtnRect and gameState.phase ~= "BATTLE" then
        local dx, dy = ScreenToDesign(sx, sy)
        local _hbr = phaseRulePopup.helpBtnRect
        if _hbr and dx >= _hbr.x and dx <= _hbr.x + _hbr.w
            and dy >= _hbr.y and dy <= _hbr.y + _hbr.h then
            phaseRulePopup.show = true
            phaseRulePopup.phase = gameState.phase
            phaseRulePopup.scrollY = 0
            phaseRulePopup.vel = 0
            phaseRulePopup.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end

    -- 首页按钮点击检测
    if gameState.phase == "MENU" then
        -- 防穿透：刚从其他界面返回时忽略点击
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        -- 辅助: 检测点是否在矩形内
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- ======== 按钮位置调整模式交互 (最高优先级，必须在所有其他检测之前) ========
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
            -- 保存按钮 (保存所有组)
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
            -- 重置按钮 (重置当前选中组)
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
        -- 广告获取虎符
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
            -- 保存按钮
            if HitRect(settingsPage.saveBtnRect) then
                SaveSettings()
                settingsPage.isOpen = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 关闭按钮
            if HitRect(settingsPage.closeBtnRect) then
                settingsPage.isOpen = false
                settingsPage.draggingMusic = false
                settingsPage.draggingSfx = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 自动行军开关
            if HitRect(settingsPage.autoMarchToggleRect) then
                gameSettings.defaultAutoMarch = not gameSettings.defaultAutoMarch
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 字体切换: 4种字体
            for _, fkey in ipairs({"misans", "kuaile", "wenkai", "xingshu"}) do
                local rect = settingsPage["font_" .. fkey .. "_rect"]
                if rect and HitRect(rect) then
                    gameSettings.fontStyle = fkey
                    SaveGameProgress()
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 默认战场切换
            if settingsPage.battlefieldBtnRect and HitRect(settingsPage.battlefieldBtnRect) then
                local cur = gameSettings.defaultBattlefield or 1
                gameSettings.defaultBattlefield = (cur % 8) + 1
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 调整位置按钮 >> 进入战斗场景调整模式
            if HitRect(settingsPage.adjustPosBtnRect) then
                settingsPage.isOpen = false
                settingsPage.btnAdjustMode = true
                settingsPage.adjActiveGroup = "skill"
                settingsPage.adjOffsetX = gameSettings.btnOffsetX
                settingsPage.adjOffsetY = gameSettings.btnOffsetY
                settingsPage.adjScale = gameSettings.btnScale or 1.0
                settingsPage.adjRightBtnOffsetX = gameSettings.rightBtnOffsetX or 0
                settingsPage.adjRightBtnOffsetY = gameSettings.rightBtnOffsetY or 0
                settingsPage.adjInfoPanelOffsetX = gameSettings.infoPanelOffsetX or 0
                settingsPage.adjInfoPanelOffsetY = gameSettings.infoPanelOffsetY or 0
                settingsPage.adjHudOffsetX = gameSettings.hudOffsetX or 0
                settingsPage.adjHudOffsetY = gameSettings.hudOffsetY or 0
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
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "UID已复制: " .. uidStr, 1.5, { 100, 220, 160 }, 16)
                    else
                        -- 系统剪贴板不可用，已存入游戏内剪贴板，同时提示截图
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.30, "UID已复制(游戏内)", 2.5, { 100, 220, 160 }, 16)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.36, uidStr, 3.0, { 255, 220, 80 }, 22)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.42, "发邮件可直接粘贴 / 截图保存", 2.5, { 180, 180, 180 }, 14)
                    end
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end

            -- 免广告卡 - 看广告按钮
            if settingsPage.adCardBtnRect and HitRect(settingsPage.adCardBtnRect) then
                PlaySFX(AUDIO.sfx_click)
                if not IsMobilePlatform() then
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "仅移动端可观看广告", 1.5, { 200, 150, 100 }, 14)
                    return
                end
                -- 看广告并计入免广告卡
                local function onAdCardSuccess()
                    local today = os.date("%Y-%m-%d")
                    if gameSettings.dailyAdDate ~= today then
                        gameSettings.dailyAdCount = 0
                        gameSettings.dailyAdDate = today
                    end
                    gameSettings.dailyAdCount = gameSettings.dailyAdCount + 1
                    print("[免广告卡] 看广告计入: " .. gameSettings.dailyAdCount .. "/3")
                    if gameSettings.dailyAdCount >= 3 then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "今日免广告卡已激活!", 2.0, { 100, 255, 200 }, 18)
                    else
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                            "广告观看成功 (" .. gameSettings.dailyAdCount .. "/3)", 1.5, { 200, 200, 100 }, 14)
                    end
                    SaveSettings()
                end
                if sdk then
                    ShowAdSafe(SafeAdCallback(function(result)
                        if result.success then
                            onAdCardSuccess()
                        end
                    end))
                else
                    onAdCardSuccess()
                end
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
            -- 乱世征途 (复用 battle 逻辑)
            if not moduleState.battle.ready then
                local pct = math.floor(moduleState.battle.progress * 100)
                ShowToast("战斗资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PlaySFX(AUDIO.sfx_click)
            WorldMap.Init()
            PushPhase("WORLD_MAP")
            print("=== 右侧面板: 进入乱世征途 ===")
            return
        end
        if menuBtnRects.rpCodex and HitRect(menuBtnRects.rpCodex) then
            -- 角色养成 (武灵录)
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
            PlaySFX(AUDIO.sfx_click)
            print("=== 右侧面板: 进入角色养成(武灵录) ===")
            return
        end
        if menuBtnRects.rpSettings and HitRect(menuBtnRects.rpSettings) then
            -- 设置
            settingsPage.isOpen = true
            PlaySFX(AUDIO.sfx_click)
            return
        end
        if menuBtnRects.rpExit and HitRect(menuBtnRects.rpExit) then
            -- 退出游戏
            PlaySFX(AUDIO.sfx_click)
            engine:Exit()
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
                    return  -- 阻止穿透到下方按钮点击
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
                local myUid = rawget(_G, "clientCloud") and clientCloud.userId or 0
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

        if HitRect(menuBtnRects.battle) then
            -- 乱世征途 >> 大地图（需要战斗模块）
            if not moduleState.battle.ready then
                local pct = math.floor(moduleState.battle.progress * 100)
                ShowToast("战斗资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PlaySFX(AUDIO.sfx_click)
            WorldMap.Init()
            PushPhase("WORLD_MAP")
            print("=== 进入大地图 ===")
        elseif HitRect(menuBtnRects.gachaSeal) then
            -- 兵符召唤（直接进入兵符管理）
            PushPhase("SEAL_MGR")
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入兵符召唤 ===")
        elseif HitRect(menuBtnRects.gachaSkill) then
            -- 武技召唤（进入武技图录）
            if not moduleState.skills.ready then
                local pct = math.floor(moduleState.skills.progress * 100)
                ShowToast("武技资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("SKILL_CODEX")
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入武技召唤 ===")
        elseif HitRect(menuBtnRects.codex) then
            -- 武灵录（需要武灵模块）
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
            print("=== 进入武灵录 ===")
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
            print("=== 进入兵甲 ===")
        elseif HitRect(menuBtnRects.equipCodex) then
            -- 兵甲图录（需要兵甲模块）
            if not moduleState.equipment.ready then
                local pct = math.floor(moduleState.equipment.progress * 100)
                ShowToast("兵甲资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("EQUIP_CODEX")
            print("=== 进入兵甲图录 ===")
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
            print("=== 进入武技 ===")
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
            print("=== 进入天命赐福 ===")
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
            print("=== 进入邮件 ===")
        elseif menuBtnRects.faction and HitRect(menuBtnRects.faction) then
            -- 阵营系统
            PushPhase("FACTION")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入阵营 ===")
        elseif menuBtnRects.friends and HitRect(menuBtnRects.friends) then
            -- 好友系统
            PushPhase("FRIENDS")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入好友 ===")
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
            welfareState.dummyLoaded = false
            welfareState.dummyLoading = false
            welfareState.dummyScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            ReportPowerScore()
            ReportRealmScore()
            LoadPowerRank()
            LoadRealmRank()
            LoadDummyRank()
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
            print("=== 进入每日任务 ===")
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
        --[=[ 已移除: 讨伐/副本/探索 入口
        elseif abyssState.btnRect and HitRect(abyssState.btnRect) then
            PushPhase("ABYSS_SELECT")
        elseif dailyDungeonState.btnRect and HitRect(dailyDungeonState.btnRect) then
            PushPhase("DAILY_DUNGEON")
        elseif resourceDungeonState.btnRect and HitRect(resourceDungeonState.btnRect) then
            PushPhase("RESOURCE_DUNGEON")
        --]=]
        elseif dummyState.btnRect and HitRect(dummyState.btnRect) then
            -- 30s打桩模式（需要战斗模块）
            if not moduleState.battle.ready then
                local pct = math.floor(moduleState.battle.progress * 100)
                ShowToast("战斗资源下载中(" .. pct .. "%)，请稍候")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 检查是否有足够的武灵
            local ownedCount = 0
            for _, h in pairs(playerHeroes) do
                if h.owned then ownedCount = ownedCount + 1 end
            end
            if ownedCount < 1 then
                ShowToast("至少拥有1名武灵才能挑战")
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("DUMMY_SELECT")
            dummyState.selected = {}
            dummyState.cardRects = {}
            dummyState.scrollY = 0
            dummyState.scrollVel = 0
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 进入30s打桩选将 ===")
        --[=[ 已移除: 爬塔/排位 入口
        elseif towerState.btnRect and HitRect(towerState.btnRect) then
            PushPhase("TOWER_SELECT")
        elseif rankedState.btnRect and HitRect(rankedState.btnRect) then
            PushPhase("RANKED_SELECT")
        --]=]
        end
        return
    end

    -- === 30s打桩选将界面输入 ===
    if gameState.phase == "DUMMY_SELECT" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 返回按钮
        if HitRect(dummyState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 打桩选将返回上一页 ===")
            return
        end
        -- 开始挑战按钮
        if HitRect(dummyState.startBtnRect) and #dummyState.selected > 0 then
            -- 初始化打桩战斗（进入准备阶段，等玩家手动开始）
            InitBattle()
            gameState.isDummy = true
            dummyState.totalDamage = 0
            dummyState.timer = 30
            dummyState.prepPhase = true  -- 准备阶段标记

            -- 清空默认敌方部署（石台上不放武灵）
            for _, slot in ipairs(ENEMY_SLOTS) do
                slot.filled = false; slot.card = nil
            end

            -- 随机讨伐背景
            if not gameState.abyssFloor then
                gameState.abyssFloor = math.random(1, 7)
            end

            -- 将选定武灵自动放入玩家石台
            for i, ci in ipairs(dummyState.selected) do
                if i <= #PLAYER_SLOTS then
                    local heroData = HERO_CARDS[ci]
                    local card = DeepCopy(heroData)
                    card.level = playerHeroes[ci] and playerHeroes[ci].level or 1
                    card.constellation = playerHeroes[ci] and playerHeroes[ci].constellation or 0
                    card.cardIdx = ci
                    SetupSlotHero(PLAYER_SLOTS[i], card)
                end
            end

            -- 设置超高敌方基地HP
            gameState.enemyBaseHP = 999999
            gameState.enemyBaseMax = 999999

            -- 进入SHOP阶段（准备阶段），让玩家调整布阵
            gameState.battlePhase = "SHOP"
            gameState.phase = "BATTLE"
            phaseChangeCooldown = 0.3
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "摆放武灵，准备开始!", 1.5, { 255, 220, 80 }, 18)
            print("=== 30s打桩 准备阶段 ===")
            return
        end
        -- 记录拖拽起始位置（卡牌点击延迟到TouchEnd判断）
        dummyState.dragStartY = dy
        dummyState.dragLastY = dy
        dummyState.isDragging = true
        dummyState.scrollVel = 0
        return
    end

    -- === 30s打桩结果界面输入 ===
    if gameState.phase == "DUMMY_RESULT" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(dummyState.resultBackRect) then
            PopPhase("MENU")
            gameState.isDummy = false
            gameState.abyssFloor = nil
            gameState.towerFloor = nil
            gameState.isRanked = false
            dummyState.prepPhase = false
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 打桩结果返回上一页 ===")
        end
        return
    end

    -- === 武技界面输入 ===
    if gameState.phase == "SKILL_CODEX" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(skillCodexBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
            return
        end
        -- 记录拖拽起始位置（用于滚动，点击延迟到EndPress判断）
        skillCodexState.dragStartY = dy
        skillCodexState.dragLastY = dy
        skillCodexState.isDragging = true
        skillCodexState.scrollVel = 0
        return
    end

    -- === 武技详情页输入 ===
    if gameState.phase == "SKILL_DETAIL" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(skillDetailBackBtnRect) then
            PopPhase("SKILL_CODEX")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
        elseif skillDetailEquipBtnRect and HitRect(skillDetailEquipBtnRect) then
            -- 装备/卸下按钮 (单按钮模式)
            local curIdx = skillCodexState.selectedIdx
            if SKILL_DEFS[curIdx] and SKILL_DEFS[curIdx].notAvailable then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "此武技暂未开放", 1.0, { 160, 150, 130 }, 14)
            elseif skillDetailEquipBtnRect.action == "unequip" then
                local s = skillDetailEquipBtnRect.slot
                table.remove(playerEquippedSkills, s)
                print("=== 卸下武技: " .. SKILL_TECHNIQUES[curIdx].name .. " (槽位" .. s .. ") ===")
                SaveGameProgress()
            else
                playerEquippedSkills[#playerEquippedSkills + 1] = curIdx
                print("=== 装备武技: " .. SKILL_TECHNIQUES[curIdx].name .. " (槽位" .. #playerEquippedSkills .. ") ===")
                SaveGameProgress()
            end
        elseif skillDetailEquipSlotBtns and #skillDetailEquipSlotBtns > 0 then
            -- 两个替换按钮模式 (两个槽位都满)
            local curIdx = skillCodexState.selectedIdx
            if SKILL_DEFS[curIdx] and SKILL_DEFS[curIdx].notAvailable then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "此武技暂未开放", 1.0, { 160, 150, 130 }, 14)
            end
            local handled = false
            for s, btn in ipairs(skillDetailEquipSlotBtns) do
                if HitRect(btn) then
                    local old = playerEquippedSkills[btn.slot]
                    playerEquippedSkills[btn.slot] = curIdx
                    print("=== 装备武技: " .. SKILL_TECHNIQUES[curIdx].name .. " >> 槽位" .. btn.slot .. " (替换" .. SKILL_TECHNIQUES[old].name .. ") ===")
                    SaveGameProgress()
                    handled = true
                    break
                end
            end
            if not handled then
                -- 没点中替换按钮，检查底部同阶预览条
                for _, mr in ipairs(skillDetailMiniRects) do
                    if HitRect(mr) and mr.idx ~= skillCodexState.selectedIdx then
                        skillCodexState.selectedIdx = mr.idx
                        print("=== 切换武技: " .. SKILL_TECHNIQUES[mr.idx].name .. " ===")
                        break
                    end
                end
            end
        else
            -- 底部同阶预览条点击切换
            for _, mr in ipairs(skillDetailMiniRects) do
                if HitRect(mr) and mr.idx ~= skillCodexState.selectedIdx then
                    skillCodexState.selectedIdx = mr.idx
                    print("=== 切换武技: " .. SKILL_TECHNIQUES[mr.idx].name .. " ===")
                    break
                end
            end
        end
        return
    end

    -- === 天命赐福输入 ===
    if gameState.phase == "WELFARE" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(welfareState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
            return
        end
        -- 三日签到按钮 (第1天=武技18, 第2天=武技19, 第3天=20000虎符)
        local SIGN_SKILL_REWARDS = { 18, 19, nil }  -- 前两天送武技(49残片直接可兑换)
        local SIGN_JADE_REWARD = 20000  -- 第3天送虎符
        for i = 1, 3 do
            if HitRect(welfareState.signInBtnRects[i]) then
                -- 已领取则跳过
                if welfareState.signInClaimed[i] then break end
                -- 前一天必须已领取
                if i > 1 and not welfareState.signInClaimed[i - 1] then break end
                -- 24小时间隔检查: 前一天领取后需等待24小时
                if i > 1 then
                    local prevTs = welfareState.signInTimestamps[i - 1] or 0
                    if prevTs > 0 and (os.time() - prevTs) < 86400 then
                        local remain = 86400 - (os.time() - prevTs)
                        local hrs = math.floor(remain / 3600)
                        local mins = math.floor((remain % 3600) / 60)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "距下次签到还需 " .. hrs .. "时" .. mins .. "分", 1.5, { 255, 180, 80 }, 18)
                        break
                    end
                end
                local dayIdx = i
                local claimFunc = function()
                    welfareState.signInClaimed[dayIdx] = true
                    welfareState.signInTimestamps[dayIdx] = os.time()
                    if SIGN_SKILL_REWARDS[dayIdx] then
                        -- 送武技残片 (49个, 可直接兑换)
                        local skIdx = SIGN_SKILL_REWARDS[dayIdx]
                        skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                        local sk = SKILL_TECHNIQUES[skIdx]
                        local skName = sk and sk.name or ("武技#" .. skIdx)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "获得 " .. skName .. " ×" .. SKILL_FRAG_EXCHANGE .. " 残片", 1.5, { 200, 160, 255 }, 18)
                        print("=== 签到第" .. dayIdx .. "天: 获得武技" .. skIdx .. " 残片×" .. SKILL_FRAG_EXCHANGE .. " ===")
                    else
                        -- 第3天送20000虎符
                        playerInfo.jade = playerInfo.jade + SIGN_JADE_REWARD
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "获得 虎符 ×" .. SIGN_JADE_REWARD, 1.5, { 255, 220, 100 }, 18)
                        print("=== 签到第" .. dayIdx .. "天: +" .. SIGN_JADE_REWARD .. " 虎符 ===")
                    end
                end
                if playerInfo.ad_free then
                    claimFunc()
                    SaveGameProgress()
                elseif sdk then
                    ShowAdSafe(SafeAdCallback(function(result)
                        if result.success then
                            claimFunc()
                            ReportAdWatchWelfare()
                            SaveGameProgress()
                        end
                    end))
                else
                    if not IsMobilePlatform() then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25, "仅移动端可观看广告", 1.5, { 200, 150, 100 }, 14)
                        return
                    end
                    claimFunc()
                    ReportAdWatchWelfare()
                end
                return
            end
        end
        -- 十日签到按钮（每日广告领5000虎符）
        for i = 1, 10 do
            if HitRect(welfareState.dailySignInBtnRects[i]) then
                -- 必须按顺序领取
                if i > 1 and not welfareState.dailySignInClaimed[i - 1] then break end
                if welfareState.dailySignInClaimed[i] then break end
                -- 24小时间隔检查: 前一天领取后需等待24小时
                if i > 1 then
                    local prevTs = welfareState.dailySignInTimestamps[i - 1] or 0
                    if prevTs > 0 and (os.time() - prevTs) < 86400 then
                        local remain = 86400 - (os.time() - prevTs)
                        local rh = math.floor(remain / 3600)
                        local rm = math.floor((remain % 3600) / 60)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            string.format("距下次签到还需 %d时%d分", rh, rm),
                            1.5, { 200, 200, 200 }, 16)
                        break
                    end
                end
                local dayIdx = i
                local claimFunc = function()
                    welfareState.dailySignInClaimed[dayIdx] = true
                    welfareState.dailySignInTimestamps[dayIdx] = os.time()
                    playerInfo.jade = playerInfo.jade + 5000
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                        "第" .. dayIdx .. "日签到 +5000 虎符", 1.5, { 255, 220, 100 }, 18)
                    print("=== 十日签到第" .. dayIdx .. "天: +5000 虎符 ===")
                end
                if playerInfo.ad_free then
                    claimFunc()
                    SaveGameProgress()
                elseif sdk then
                    ShowAdSafe(SafeAdCallback(function(result)
                        if result.success then
                            claimFunc()
                            ReportAdWatchWelfare()
                            SaveGameProgress()
                        end
                    end))
                else
                    if not IsMobilePlatform() then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25, "仅移动端可观看广告", 1.5, { 200, 150, 100 }, 14)
                        return
                    end
                    claimFunc()
                    ReportAdWatchWelfare()
                end
                return
            end
        end
        -- 在线时长奖励按钮
        local OL_JADE = { 300, 500, 800, 1000 }
        for i = 1, 4 do
            if HitRect(welfareState.onlineBtnRects[i]) then
                welfareState.onlineRewards[i] = true
                playerInfo.jade = playerInfo.jade + OL_JADE[i]
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4,
                    "在线奖励 +" .. OL_JADE[i] .. " 虎符", 1.5, { 130, 200, 255 }, 16)
                print("=== 在线时长奖励第" .. i .. "档: +" .. OL_JADE[i] .. " 虎符 ===")
                return
            end
        end

        -- (大转盘和每日翻牌点击处理已移除)

        -- 贡献榜"查看详情"按钮 → 跳转到贡献榜详情页
        if welfareState.contribDetailBtnRect and HitRect(welfareState.contribDetailBtnRect) then
            welfareState.contribDetailScroll.offset = 0  -- 重置滚动
            PushPhase("CONTRIB_RANK")
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 没有命中任何按钮，开始滚动拖拽
        -- 判断是在贡献榜区域还是下方内容区域
        local contribBot = 72 + (welfareState.contribFixedH or 0)
        if dy >= 72 and dy < contribBot then
            local cs = welfareState.contribScroll
            cs.isDragging = true
            cs.dragStartY = dy
            cs.dragLastY = dy
            cs.vel = 0
        else
            local ws = welfareState.scroll
            ws.isDragging = true
            ws.dragStartY = dy
            ws.dragLastY = dy
            ws.vel = 0
        end
        return
    end

    -- === 每日任务 / 成就 界面输入 ===
    if gameState.phase == "PROGRESS" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 返回按钮
        if HitRect(progressUIState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            return
        end
        -- Tab切换
        for i, r in ipairs(progressTabRects) do
            if HitRect(r) then
                progressUIState.tab = i
                progressUIState.scrollY = 0
                return
            end
        end
        -- 每日任务领取按钮
        if progressUIState.tab == 1 then
            for i, r in ipairs(dailyTaskBtnRects) do
                if HitRect(r) then
                    if ClaimDailyReward(i) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "任务奖励已领取!", 1.5, { 100, 255, 100 }, 16)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            -- 全勤奖励按钮
            if HitRect(dailyTaskAllBtnRect) then
                if ClaimDailyAllBonus() then
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 周任务领取按钮
        if progressUIState.tab == 2 then
            for i, r in ipairs(weeklyTaskBtnRects) do
                if HitRect(r) then
                    if ClaimWeeklyReward(i) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "周任务奖励已领取!", 1.5, { 100, 230, 255 }, 16)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            -- 周全勤奖励按钮
            if HitRect(weeklyTaskAllBtnRect) then
                if ClaimWeeklyAllBonus() then
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 成就领取按钮
        if progressUIState.tab == 3 then
            for i, r in ipairs(progressUIState.achBtnRects or {}) do
                if HitRect(r) then
                    local origIdx = (progressUIState.achOrigIdx and progressUIState.achOrigIdx[i]) or i
                    if ClaimAchievement(origIdx) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "成就奖励已领取!", 1.5, { 255, 220, 80 }, 16)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
        end
        -- 滚动拖拽
        progressUIState.isDragging = true
        progressUIState.dragStartY = dy
        progressUIState.dragLastY = dy
        progressUIState.scrollVel = 0
        return
    end

    -- === 开发者战场编辑器输入 ===
    if gameState.phase == "DEV_EDITOR" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 返回按钮
        if HitRect(editorState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- Tab切换
        for i, r in ipairs(editorState.tabRects) do
            if HitRect(r) then
                editorState.tab = i
                editorState.scrollY = 0
                editorState.scrollVel = 0
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- Tab 1: 关卡编辑
        if editorState.tab == 1 then
            -- 难度减少
            for si = 1, #STAGES do
                if HitRect(editorState.btnRects["stage_minus_" .. si]) then
                    local sOver = editorState.stageOverrides[si] or { enemyScale = STAGES[si].enemyScale }
                    sOver.enemyScale = math.max(0.1, (sOver.enemyScale or STAGES[si].enemyScale) - 0.1)
                    editorState.stageOverrides[si] = sOver
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                if HitRect(editorState.btnRects["stage_plus_" .. si]) then
                    local sOver = editorState.stageOverrides[si] or { enemyScale = STAGES[si].enemyScale }
                    sOver.enemyScale = math.min(10.0, (sOver.enemyScale or STAGES[si].enemyScale) + 0.1)
                    editorState.stageOverrides[si] = sOver
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                -- 点击关卡卡片选中
                if HitRect(editorState.btnRects["stage_" .. si]) then
                    editorState.selectedStage = si
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 重置全部难度
            if HitRect(editorState.btnRects["reset_stages"]) then
                editorState.stageOverrides = {}
                PlaySFX(AUDIO.sfx_click)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "已重置全部难度", 1.5, { 255, 200, 100 }, 16)
                return
            end
        end
        -- Tab 2: 战斗参数
        if editorState.tab == 2 then
            local params = {
                { key = "baseHpMax",        default = GameConfig.BASE_HP_MAX,       step = 50,   min = 100,  max = 5000 },
                { key = "initialGold",      default = GameConfig.INITIAL_GOLD,      step = 5,    min = 0,    max = 200 },
                { key = "enemySpawnCd",     default = GameConfig.ENEMY_SPAWN_CD,    step = 0.1,  min = 0.3,  max = 10 },
                { key = "playerSpawnCd",    default = GameConfig.PLAYER_SPAWN_CD,   step = 0.1,  min = 0.3,  max = 10 },
                { key = "battleTimeLimit",  default = GameConfig.BATTLE_TIME_LIMIT or 180, step = 15, min = 30, max = 600 },
                { key = "soldierStatScale", default = GameConfig.SOLDIER_STAT_SCALE, step = 0.05, min = 0.05, max = 2.0 },
                { key = "deployCd",         default = GameConfig.DEPLOY_CD or 3.5,  step = 0.5,  min = 1,    max = 20 },
            }
            for pi, p in ipairs(params) do
                if HitRect(editorState.btnRects["param_minus_" .. pi]) then
                    local curVal = editorState.overrides[p.key] or p.default
                    curVal = math.max(p.min, curVal - p.step)
                    editorState.overrides[p.key] = curVal
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                if HitRect(editorState.btnRects["param_plus_" .. pi]) then
                    local curVal = editorState.overrides[p.key] or p.default
                    curVal = math.min(p.max, curVal + p.step)
                    editorState.overrides[p.key] = curVal
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 重置全部参数
            if HitRect(editorState.btnRects["reset_params"]) then
                editorState.overrides = {
                    baseHpMax = nil, initialGold = nil, enemySpawnCd = nil,
                    playerSpawnCd = nil, battleTimeLimit = nil, soldierStatScale = nil, deployCd = nil,
                }
                PlaySFX(AUDIO.sfx_click)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "已重置全部参数", 1.5, { 255, 200, 100 }, 16)
                return
            end
        end
        -- Tab 3: 快速测试
        if editorState.tab == 3 then
            -- 选择测试关卡
            for si = 1, #STAGES do
                if HitRect(editorState.btnRects["test_stage_" .. si]) then
                    editorState.testStage = si
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 开始测试战斗
            if HitRect(editorState.btnRects["start_test"]) then
                ApplyEditorOverrides()
                stageState.currentStage = editorState.testStage
                gameState.isDummy = false
                InitBattle()
                PushPhase("BATTLE")
                phaseChangeCooldown = 0.3
                PlaySFX(AUDIO.sfx_click)
                print("=== 编辑器: 开始测试关卡 " .. editorState.testStage .. " ===")
                return
            end
        end
        -- Tab 4: 石台编辑
        if editorState.tab == 4 then
            -- 导出复制按钮
            if HitRect(editorState.btnRects["slot_save"]) then
                ExportBattleLayouts()
                editorState.saveFlashT = os.clock()
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 撤销按钮
            if HitRect(editorState.btnRects["slot_undo"]) then
                if UndoSlotEdit() then
                    print("[布局编辑器] 撤销成功, 剩余 " .. #slotUndoStack .. " 步")
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 快捷选择按钮: 选我方 / 选敌方 / 清除选择
            if HitRect(editorState.btnRects["sel_player"]) then
                local lo = BATTLE_LAYOUTS[editorState.editLayoutIdx or 1]
                if lo then for pi = 1, #lo.playerSlots do editorState.selectedSlots["player_" .. pi] = true end end
                PlaySFX(AUDIO.sfx_click); return
            end
            if HitRect(editorState.btnRects["sel_enemy"]) then
                local lo = BATTLE_LAYOUTS[editorState.editLayoutIdx or 1]
                if lo then for ei = 1, #lo.enemySlots do editorState.selectedSlots["enemy_" .. ei] = true end end
                PlaySFX(AUDIO.sfx_click); return
            end
            if HitRect(editorState.btnRects["sel_clear"]) then
                editorState.selectedSlots = {}
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 布局选择
            for li = 1, #BATTLE_LAYOUTS do
                if HitRect(editorState.btnRects["layout_" .. li]) then
                    editorState.editLayoutIdx = li
                    editorState.slotDragging = false
                    editorState.selectedSlots = {}
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 石台圆圈按下 → 记录按下信息 (HandleMoveLogic 中判断是否拖拽)
            local lidx = editorState.editLayoutIdx or 1
            local layout = BATTLE_LAYOUTS[lidx]
            local sdx, sdy = ScreenToDesign(sx, sy)
            if layout then
                for ei = 1, #layout.enemySlots do
                    if HitRect(editorState.btnRects["eslot_" .. ei]) then
                        local key = "enemy_" .. ei
                        local wasSelected = editorState.selectedSlots[key] == true
                        editorState.selectedSlots[key] = true
                        editorState.slotPressKey = key
                        editorState.slotWasSelected = wasSelected
                        editorState.slotPressStartX = sdx
                        editorState.slotPressStartY = sdy
                        editorState.slotDragging = false
                        return
                    end
                end
                for pi = 1, #layout.playerSlots do
                    if HitRect(editorState.btnRects["pslot_" .. pi]) then
                        local key = "player_" .. pi
                        local wasSelected = editorState.selectedSlots[key] == true
                        editorState.selectedSlots[key] = true
                        editorState.slotPressKey = key
                        editorState.slotWasSelected = wasSelected
                        editorState.slotPressStartX = sdx
                        editorState.slotPressStartY = sdy
                        editorState.slotDragging = false
                        return
                    end
                end
            end
            -- 点击空白区域: 清除选择
            editorState.selectedSlots = {}
            return
        end
        -- 滚动拖拽
        editorState.isDragging = true
        editorState.dragStartY = dy
        editorState.dragLastY = dy
        editorState.scrollVel = 0
        return
    end

    -- === 抽卡界面输入 === (已移除抽卡系统)
    --[=[ GACHA phase removed
    if gameState.phase == "GACHA" then
        return
    end
    --]=]

    -- === 图鉴界面输入 ===
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
        if HitRect(heroDetailBackBtnRect) then
            PopPhase("CODEX")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
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
        -- 点击已装备武技 → 跳转武技详情
        if playerDetailSkillRects then
            for _, sr in pairs(playerDetailSkillRects) do
                if HitRect(sr) and sr.skIdx then
                    skillCodexState.selectedIdx = sr.skIdx
                    PushPhase("SKILL_DETAIL")
                    phaseChangeCooldown = 0.3
                    print("=== 查看武技详情: " .. (SKILL_TECHNIQUES[sr.skIdx] and SKILL_TECHNIQUES[sr.skIdx].name or "") .. " ===")
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
            print("=== 编辑资料 ===")
            return
        end
        -- 开始拖拽滚动
        playerDetailScroll.dragStartY = dy
        playerDetailScroll.dragLastY = dy
        playerDetailScroll.isDragging = true
        playerDetailScroll.vel = 0
        return
    end

    -- === 兵甲界面输入 ===
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
                print("=== 选中分解完成 ===")
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
                    if playerEquipment.equipped[itm.slotIdx] ~= itm.uid then
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
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "选中要分解的兵甲", 1.0, { 100, 180, 255 }, 16)
            return
        end
        -- 点击筛选分解按钮 → 弹出确认弹窗(使用当前筛选)
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
            local eqItem = GetEquippedItem(slotIdx)
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
                redDotState.equipAck[si] = GetBestOwnedScoreForSlot(si)
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
                                    "+" .. rw.amount .. " 虎符", 1.5, { 255, 220, 100 }, 18)
                            elseif rw.type == "ad_free" then
                                playerInfo.ad_free = true
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                    "获得免广告特权!", 1.5, { 100, 255, 150 }, 16)
                            elseif rw.type == "full_skill" then
                                local skIdx = rw.skillIdx
                                if skIdx then
                                    skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                                    local skName = SKILL_TECHNIQUES[skIdx] and SKILL_TECHNIQUES[skIdx].name or ("武技#" .. skIdx)
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                        "获得武技「" .. skName .. "」", 1.5, { 200, 160, 255 }, 16)
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
                                        heroName .. " 获得" .. tierName .. slotName, 1.5, { 180, 140, 255 }, 16)
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
                                    "+" .. rw.amount .. " 虎符", 1.5, { 255, 220, 100 }, 18)
                            elseif rw.type == "full_skill" then
                                local skIdx = rw.skillIdx
                                skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                                local skName = SKILL_TECHNIQUES[skIdx] and SKILL_TECHNIQUES[skIdx].name or ("武技#" .. skIdx)
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                    "获得武技「" .. skName .. "」", 1.5, { 200, 160, 255 }, 16)
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
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "邮件已刷新", 1.2, {140,220,180}, 14)
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

        -- ======== 系统邮件 Tab 领取按钮 ========
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
        -- 返回
        if tradeState.btnRects.back and HitRect(tradeState.btnRects.back) then
            PopPhase(); PlaySFX(AUDIO.sfx_click); return
        end
        -- Tab 切换
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
        -- 领取虎符按钮
        if tradeState.btnRects.claimJade and HitRect(tradeState.btnRects.claimJade) then
            TradeManager.ClaimJade(function(amount)
                if amount > 0 then
                    ShowToast("领取 " .. amount .. " 虎符")
                else
                    ShowToast("暂无可领取虎符")
                end
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 市场列表点击 (使用过滤后的物品列表)
        if tradeState.tab == "market" then
            local items = tradeState._filteredMarketItems or TradeManager.state.marketItems or {}
            for i, _ in ipairs(items) do
                local rect = tradeState.btnRects["market_" .. i]
                if rect and HitRect(rect) then
                    local item = items[i]
                    if item.isMine then
                        ShowToast("这是你自己上架的装备")
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
            -- 过期items
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
    -- ======== 阵营界面点击处理 ========
    if gameState.phase == "FACTION" then
        -- 改名弹窗优先
        if factionUI.renamePopup then
            if menuBtnRects.factionRenameYes and HitRect(menuBtnRects.factionRenameYes) then
                local newName = factionUI.renameInput or ""
                if #newName == 0 then
                    ShowToast("名称不能为空")
                elseif (playerInfo.jade or 0) < 1000 then
                    ShowToast("虎符不足，改名需要1000虎符")
                else
                    playerInfo.jade = playerInfo.jade - 1000
                    CloudManager.RenameFaction(newName, function(ok, reason)
                        if ok then
                            ShowToast("阵营已更名为「" .. newName .. "」(-1000虎符)")
                            factionUI.loaded = false; factionUI.loading = false
                            if SaveGameProgress then SaveGameProgress() end
                        else
                            -- 改名失败，退还虎符
                            playerInfo.jade = playerInfo.jade + 1000
                            ShowToast("改名失败: " .. tostring(reason))
                        end
                    end)
                    factionUI.renamePopup = false; factionUI.renameInput = ""
                    factionUI.inputTarget = nil; input:SetScreenKeyboardVisible(false)
                end
                PlaySFX(AUDIO.sfx_click); return
            end
            if menuBtnRects.factionRenameNo and HitRect(menuBtnRects.factionRenameNo) then
                factionUI.renamePopup = false; factionUI.renameInput = ""
                factionUI.inputTarget = nil; input:SetScreenKeyboardVisible(false)
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 点输入框激活键盘
            if menuBtnRects.factionRenameInput and HitRect(menuBtnRects.factionRenameInput) then
                factionUI.inputTarget = "rename"
                input:SetScreenKeyboardVisible(true)
                PlaySFX(AUDIO.sfx_click); return
            end
            return  -- 弹窗打开时拦截
        end
        -- 确认弹窗优先
        if factionUI.confirmPopup then
            if menuBtnRects.factionPopupYes and HitRect(menuBtnRects.factionPopupYes) then
                local pop = factionUI.confirmPopup
                factionUI.confirmPopup = nil
                PlaySFX(AUDIO.sfx_click)
                if pop.type == "leave" then
                    CloudManager.LeaveFaction(function(ok)
                        if ok then
                            ShowToast("已退出阵营")
                            factionUI.tab = "list"
                            factionUI.loaded = false
                            factionUI.loading = false
                            factionUI.applyStatus = nil
                            factionUI.members = {}
                            factionUI.applications = {}
                            factionUI.chatPolled = false
                            playerInfo.factionJoined = 0
                            SaveGameProgress()
                        else ShowToast("操作失败") end
                    end)
                elseif pop.type == "apply" then
                    CloudManager.ApplyToFaction(pop.targetId, pop.targetName, function(ok)
                        if ok then
                            factionUI.applyStatus = "pending"
                            playerInfo.factionJoined = 1
                            ShowToast("申请已发送")
                        else ShowToast("申请失败") end
                    end)
                elseif pop.type == "create" then
                    -- 虎符检查和扣费由 CloudManager.CreateFaction 统一处理
                    CloudManager.CreateFaction(factionUI.createName, factionUI.createDesc, function(ok, reason)
                        if ok then
                            playerInfo.totalFactionCreated = (playerInfo.totalFactionCreated or 0) + 1
                            playerInfo.factionJoined = 1
                            ShowToast("阵营创建成功！")
                            factionUI.tab = "info"
                            factionUI.loaded = false
                            factionUI.loading = false
                            factionUI.createName = ""; factionUI.createDesc = ""
                            SaveGameProgress()
                        else
                            ShowToast(reason or "创建失败")
                        end
                    end)
                elseif pop.type == "kick" then
                    CloudManager.KickMember(pop.targetUserId, function(ok, reason)
                        if ok then
                            ShowToast("已踢出成员")
                            factionUI.loaded = false; factionUI.loading = false
                        else
                            ShowToast("踢出失败: " .. tostring(reason))
                        end
                    end)
                end
                return
            end
            if menuBtnRects.factionPopupNo and HitRect(menuBtnRects.factionPopupNo) then
                factionUI.confirmPopup = nil; PlaySFX(AUDIO.sfx_click); return
            end
            return  -- 弹窗打开时拦截
        end
        -- 返回
        if menuBtnRects.factionBack and HitRect(menuBtnRects.factionBack) then
            factionUI.inputTarget = nil; input:SetScreenKeyboardVisible(false)
            PopPhase("MENU"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return
        end
        -- Tab 切换
        for _, tid in ipairs({"info", "members", "chat", "apply", "list", "create"}) do
            local r = menuBtnRects["factionTab_" .. tid]
            if r and HitRect(r) then
                if factionUI.tab ~= tid then
                    factionUI.tab = tid; factionUI.inputTarget = nil
                    factionUI.subView = nil
                    factionUI.scroll.offset = 0; factionUI.scroll.vel = 0
                    -- 切换 tab 时重新加载对应数据
                    if tid == "members" then
                        factionUI.loaded = false; factionUI.loading = false
                    elseif tid == "apply" then
                        factionUI.applyLoaded = false; factionUI.applyLoading = false
                    elseif tid == "list" then
                        factionUI.loaded = false; factionUI.loading = false
                    end
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 职位选择弹窗打开时，拦截所有其他点击
        if factionUI.rolePopup then
            for i = 1, 6 do
                local optR = menuBtnRects["factionRoleOption_" .. i]
                if optR and HitRect(optR) then
                    local rp = factionUI.rolePopup
                    local newRole = optR.roleKey
                    if newRole ~= rp.currentRole then
                        CloudManager.SetMemberRole(rp.userId, newRole, function(ok, reason)
                            if ok then
                                ShowToast("已将「" .. (rp.nickname or "?") .. "」设为" .. (reason or newRole))
                                factionUI.loaded = false; factionUI.loading = false
                            else
                                ShowToast("设置失败: " .. tostring(reason))
                            end
                        end)
                    end
                    factionUI.rolePopup = nil
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
            -- 点弹窗外关闭
            factionUI.rolePopup = nil
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 排行榜面板（最高优先级，覆盖其他操作）
        if factionUI.showRank then
            if menuBtnRects.factionRankClose and HitRect(menuBtnRects.factionRankClose) then
                factionUI.showRank = false
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 排行榜遮罩点击也关闭
            if menuBtnRects.factionRankOverlay and HitRect(menuBtnRects.factionRankOverlay) then
                factionUI.showRank = false
                PlaySFX(AUDIO.sfx_click); return
            end
            return  -- 排行榜打开时拦截所有其他点击
        end
        -- 排行榜打开按钮
        if menuBtnRects.factionRankBtn and HitRect(menuBtnRects.factionRankBtn) then
            factionUI.showRank = true
            factionUI.rankLoaded = false; factionUI.rankLoading = false
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 子视图返回按钮
        if menuBtnRects.factionSubBack and HitRect(menuBtnRects.factionSubBack) then
            factionUI.subView = nil; factionUI.showRank = false
            factionUI.inputTarget = nil
            input:SetScreenKeyboardVisible(false)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 捐献金额选择
        for ai = 1, 4 do
            local amtR = menuBtnRects["factionDonateAmt_" .. ai]
            if amtR and HitRect(amtR) then
                factionUI.donateAmount = amtR.amount
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 捐献按钮
        if menuBtnRects.factionDonate and HitRect(menuBtnRects.factionDonate) then
            if not factionUI.donating then
                factionUI.donating = true
                CloudManager.DonateFaction(factionUI.donateAmount, function(ok, reason)
                    factionUI.donating = false
                    if ok then
                        if reason then
                            ShowToast(reason)  -- 升级提示
                        else
                            ShowToast("捐献成功! +" .. factionUI.donateAmount .. " 虎符")
                        end
                    else
                        ShowToast("捐献失败: " .. tostring(reason))
                    end
                end)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 公告输入框
        if menuBtnRects.factionAnnounceInput and HitRect(menuBtnRects.factionAnnounceInput) then
            factionUI.inputTarget = "announce"
            input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 公告保存按钮
        if menuBtnRects.factionAnnounceSave and HitRect(menuBtnRects.factionAnnounceSave) then
            CloudManager.SetFactionAnnouncement(factionUI.announceInput, function(ok, reason)
                if ok then
                    ShowToast("公告已更新")
                    factionUI.announceInput = ""
                    factionUI.inputTarget = nil
                    input:SetScreenKeyboardVisible(false)
                else
                    ShowToast("更新失败: " .. tostring(reason))
                end
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 阵营功能入口：成员管理 → members tab，聊天 → chat tab
        if menuBtnRects["factionFeat_manage"] and HitRect(menuBtnRects["factionFeat_manage"]) then
            factionUI.tab = "members"; factionUI.loaded = false; factionUI.loading = false
            factionUI.subView = nil
            PlaySFX(AUDIO.sfx_click); return
        end
        if menuBtnRects["factionFeat_chat"] and HitRect(menuBtnRects["factionFeat_chat"]) then
            factionUI.tab = "chat"; factionUI.subView = nil
            if not factionUI.chatMessages then factionUI.chatMessages = {} end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 每日签到
        if menuBtnRects["factionFeat_signIn"] and HitRect(menuBtnRects["factionFeat_signIn"]) then
            if CloudManager.HasSignedInToday() then
                ShowToast("今日已签到")
            elseif not factionUI.signingIn then
                factionUI.signingIn = true
                CloudManager.FactionSignIn(function(ok, reason)
                    factionUI.signingIn = false
                    if ok then
                        if reason then
                            ShowToast(reason)  -- 升级提示
                        else
                            ShowToast("签到成功! 阵营经验+500")
                        end
                    else
                        ShowToast("签到失败: " .. tostring(reason))
                    end
                end)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 阵营排行入口 → 打开排行榜弹出面板
        if menuBtnRects["factionFeat_rank"] and HitRect(menuBtnRects["factionFeat_rank"]) then
            factionUI.showRank = true
            factionUI.rankLoaded = false; factionUI.rankLoading = false
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 成员贡献 → 打开贡献子视图
        if menuBtnRects["factionFeat_contrib"] and HitRect(menuBtnRects["factionFeat_contrib"]) then
            factionUI.subView = "contrib"
            factionUI.contribLoaded = false; factionUI.contribLoading = false
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 阵营聊天: 添加好友按钮
        if menuBtnRects.factionChatAddFriend and HitRect(menuBtnRects.factionChatAddFriend) then
            local targetUid = menuBtnRects.factionChatAddFriend.uid
            local targetName = menuBtnRects.factionChatAddFriend.name or "?"
            local myUid = rawget(_G, "clientCloud") and clientCloud.userId or 0
            if targetUid == myUid then
                ShowToast("不能添加自己为好友")
            else
                CloudManager.SendFriendRequest(targetUid, "")
                playerInfo.totalFriendReqs = (playerInfo.totalFriendReqs or 0) + 1
                ShowToast("已向「" .. targetName .. "」发送好友请求")
            end
            factionUI.chatNamePopup = nil
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 阵营聊天: 弹窗区域内点击不穿透
        if menuBtnRects.factionChatPopupArea and HitRect(menuBtnRects.factionChatPopupArea) then
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 阵营聊天: 点击头像弹出玩家信息
        if factionUI._chatAvatarRects then
            for _, nr in ipairs(factionUI._chatAvatarRects) do
                if HitRect(nr) then
                    if factionUI.chatNamePopup and factionUI.chatNamePopup.uid == nr.uid then
                        factionUI.chatNamePopup = nil
                    else
                        factionUI.chatNamePopup = { uid = nr.uid, name = nr.name, x = nr.x, y = nr.y, av = nr.av }
                    end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
        -- 聊天输入框
        if menuBtnRects.factionChatInput and HitRect(menuBtnRects.factionChatInput) then
            factionUI.inputTarget = "chat"
            factionUI.chatNamePopup = nil
            if not factionUI.chatInput then factionUI.chatInput = "" end
            input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 聊天发送按钮 (云端同步)
        if menuBtnRects.factionChatSend and HitRect(menuBtnRects.factionChatSend) then
            if factionUI.chatInput and #factionUI.chatInput > 0 then
                local filteredText = FilterBannedWords(factionUI.chatInput)
                local senderName = CloudManager._myTapNickname or factionUI.myNickname or playerInfo.name or "我"
                CloudManager.SendFactionChat(filteredText, senderName)
                playerInfo.totalFactionChat = (playerInfo.totalFactionChat or 0) + 1
                factionUI.chatInput = ""
                factionUI.inputTarget = nil
                input:SetScreenKeyboardVisible(false)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 阵营养成功能入口 (打开子视图)
        local cultivateFeats = {"upgrade", "donate", "announce"}
        for _, fid in ipairs(cultivateFeats) do
            local fr = menuBtnRects["factionFeat_" .. fid]
            if fr and HitRect(fr) then
                factionUI.subView = fid
                factionUI.inputTarget = nil
                if fid == "announce" then
                    factionUI.announceInput = ""
                end
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 其余待开发功能
        local devFeatIds = {"shop","war","task"}
        local devFeatNames = {shop="阵营商店",war="阵营战争",task="阵营任务"}
        for _, fid in ipairs(devFeatIds) do
            local fr = menuBtnRects["factionFeat_" .. fid]
            if fr and HitRect(fr) then
                ShowToast("「" .. (devFeatNames[fid] or fid) .. "」功能待开发，敬请期待！")
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 改名按钮 (盟主)
        if menuBtnRects.factionRename and HitRect(menuBtnRects.factionRename) then
            factionUI.renamePopup = true
            factionUI.renameInput = ""
            factionUI.inputTarget = "rename"
            input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 退出/解散阵营
        if menuBtnRects.factionLeave and HitRect(menuBtnRects.factionLeave) then
            local info = CloudManager.GetFactionInfo()
            local msg = (info and info.role == "leader") and "确定解散阵营？" or "确定退出阵营？"
            factionUI.confirmPopup = { type = "leave", msg = msg }
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 入队申请: 同意/拒绝
        for i = 1, 50 do
            local accR = menuBtnRects["factionAccept_" .. i]
            if accR and HitRect(accR) then
                local uid = accR.userId
                CloudManager.ApproveFactionApplication(uid, function(ok)
                    if ok then ShowToast("已同意申请") else ShowToast("操作失败") end
                    factionUI.applyLoaded = false; factionUI.applyLoading = false
                    factionUI.loaded = false; factionUI.loading = false  -- 刷新成员列表
                    factionUI.pendingAppCount = math.max(0, factionUI.pendingAppCount - 1)
                    factionUI.lastAppCheckTime = 0  -- 触发立即重新检查
                end)
                PlaySFX(AUDIO.sfx_click); return
            end
            local rejR = menuBtnRects["factionReject_" .. i]
            if rejR and HitRect(rejR) then
                local uid = rejR.userId
                CloudManager.RejectFactionApplication(uid)
                ShowToast("已拒绝"); PlaySFX(AUDIO.sfx_click)
                factionUI.applyLoaded = false; factionUI.applyLoading = false
                factionUI.pendingAppCount = math.max(0, factionUI.pendingAppCount - 1)
                factionUI.lastAppCheckTime = 0
                return
            end
        end
        -- 成员列表: 设置职位按钮
        for i = 1, 30 do
            local srR = menuBtnRects["factionSetRole_" .. i]
            if srR and HitRect(srR) then
                factionUI.rolePopup = { userId = srR.userId, currentRole = srR.currentRole, nickname = srR.nickname }
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 成员列表: 踢出按钮
        for i = 1, 30 do
            local kR = menuBtnRects["factionKick_" .. i]
            if kR and HitRect(kR) then
                factionUI.confirmPopup = {
                    type = "kick", targetUserId = kR.userId,
                    msg = "确定将「" .. (kR.nickname or "?") .. "」踢出阵营？"
                }
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 阵营列表: 申请加入
        for i = 1, 50 do
            local apR = menuBtnRects["factionApply_" .. i]
            if apR and HitRect(apR) then
                factionUI.confirmPopup = {
                    type = "apply", targetId = apR.campId, targetName = apR.campName,
                    msg = "申请加入「" .. (apR.campName or "?") .. "」？"
                }
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 刷新申请状态
        if menuBtnRects.factionRefreshApply and HitRect(menuBtnRects.factionRefreshApply) then
            CloudManager.CheckMyFactionApplication(function(status)
                if status == "approved" then
                    factionUI.applyStatus = nil; ShowToast("申请已通过！")
                    factionUI.loaded = false; factionUI.loading = false
                elseif status == "rejected" then
                    factionUI.applyStatus = nil; ShowToast("申请被拒绝")
                elseif status == "pending" then
                    ShowToast("仍在审批中...")
                else
                    factionUI.applyStatus = nil; ShowToast("状态已更新")
                end
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 输入框激活
        if menuBtnRects.factionNameInput and HitRect(menuBtnRects.factionNameInput) then
            factionUI.inputTarget = "name"; input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        if menuBtnRects.factionDescInput and HitRect(menuBtnRects.factionDescInput) then
            factionUI.inputTarget = "desc"; input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 创建阵营
        if menuBtnRects.factionCreate and HitRect(menuBtnRects.factionCreate) then
            if #factionUI.createName < 2 then
                ShowToast("阵营名称至少2个字"); return
            end
            factionUI.confirmPopup = {
                type = "create",
                msg = "花费5000虎符创建阵营？"
            }
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 成员列表：没有命中按钮，开始滚动拖拽
        if factionUI.tab == "members" and #factionUI.members > 0 then
            factionUI.scroll.isDragging = true
            factionUI.scroll.dragStartY = dy
            factionUI.scroll.dragLastY = dy
            factionUI.scroll.vel = 0
        end
        return
    end

    -- ======== 好友界面点击处理 ========
    if gameState.phase == "FRIENDS" then
        -- 确认弹窗优先
        if friendsUI.confirmPopup then
            if menuBtnRects.friendPopupYes and HitRect(menuBtnRects.friendPopupYes) then
                local pop = friendsUI.confirmPopup
                friendsUI.confirmPopup = nil
                PlaySFX(AUDIO.sfx_click)
                if pop.type == "delete" then
                    CloudManager.RemoveFriend(pop.targetId)
                    ShowToast("已删除好友")
                    friendsUI.loaded = false; friendsUI.loading = false
                end
                return
            end
            if menuBtnRects.friendPopupNo and HitRect(menuBtnRects.friendPopupNo) then
                friendsUI.confirmPopup = nil; PlaySFX(AUDIO.sfx_click); return
            end
            return  -- 弹窗打开时拦截
        end
        -- 返回
        if menuBtnRects.friendsBack and HitRect(menuBtnRects.friendsBack) then
            friendsUI.inputActive = false; input:SetScreenKeyboardVisible(false)
            PopPhase("MENU"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return
        end
        -- Tab 切换
        for _, tid in ipairs({"list", "add", "requests"}) do
            local r = menuBtnRects["friendsTab_" .. tid]
            if r and HitRect(r) then
                if friendsUI.tab ~= tid then
                    friendsUI.tab = tid; friendsUI.inputActive = false
                    if tid == "list" then
                        friendsUI.loaded = false; friendsUI.loading = false
                    elseif tid == "requests" then
                        friendsUI.reqLoaded = false; friendsUI.reqLoading = false
                    elseif tid == "add" then
                        friendsUI.recLoaded = false; friendsUI.recLoading = false; friendsUI.searchResult = nil; friendsUI.searchNotFound = false
                    end
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 好友列表: 删除
        for i = 1, 50 do
            local delR = menuBtnRects["friendDel_" .. i]
            if delR and HitRect(delR) then
                local fr = friendsUI.friends[i]
                local name = fr and (fr.nickname or ("玩家" .. tostring(fr.userId))) or "?"
                friendsUI.confirmPopup = {
                    type = "delete", targetId = delR.userId,
                    msg = "确定删除好友「" .. name .. "」？"
                }
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 搜索输入框激活
        if menuBtnRects.friendSearchInput and HitRect(menuBtnRects.friendSearchInput) then
            friendsUI.inputActive = true; input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 搜索按钮
        if menuBtnRects.friendSearchBtn and HitRect(menuBtnRects.friendSearchBtn) then
            if #friendsUI.searchId > 0 then
                friendsUI.searchResult = nil; friendsUI.searchNotFound = false
                local searchUid = tonumber(friendsUI.searchId)
                if searchUid then
                    CloudManager.SearchPlayer(searchUid, function(player)
                        if player then
                            friendsUI.searchResult = player; friendsUI.searchNotFound = false
                        else friendsUI.searchNotFound = true end
                    end)
                else
                    ShowToast("请输入数字ID")
                end
            else
                ShowToast("请输入玩家ID")
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 搜索结果: 添加好友
        if menuBtnRects.friendSearchAdd and HitRect(menuBtnRects.friendSearchAdd) then
            local uid = menuBtnRects.friendSearchAdd.userId
            CloudManager.SendFriendRequest(uid, "")
            playerInfo.totalFriendReqs = (playerInfo.totalFriendReqs or 0) + 1
            ShowToast("好友请求已发送"); PlaySFX(AUDIO.sfx_click); return
        end
        -- 推荐玩家: 添加
        for i = 1, 20 do
            local recR = menuBtnRects["friendRecAdd_" .. i]
            if recR and HitRect(recR) then
                CloudManager.SendFriendRequest(recR.userId, "")
                playerInfo.totalFriendReqs = (playerInfo.totalFriendReqs or 0) + 1
                ShowToast("好友请求已发送"); PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 好友请求: 同意/拒绝
        for i = 1, 50 do
            local accR = menuBtnRects["friendAccept_" .. i]
            if accR and HitRect(accR) then
                CloudManager.AcceptFriendRequest(accR.fromUid)
                playerInfo.totalFriends = (playerInfo.totalFriends or 0) + 1
                ShowToast("已添加好友")
                friendsUI.reqLoaded = false; friendsUI.reqLoading = false
                friendsUI.loaded = false; friendsUI.loading = false
                friendsUI.pendingReqCount = math.max(0, friendsUI.pendingReqCount - 1)
                friendsUI.lastReqCheckTime = 0
                PlaySFX(AUDIO.sfx_click); return
            end
            local rejR = menuBtnRects["friendReject_" .. i]
            if rejR and HitRect(rejR) then
                CloudManager.RejectFriendRequest(rejR.fromUid)
                ShowToast("已拒绝"); PlaySFX(AUDIO.sfx_click)
                friendsUI.reqLoaded = false; friendsUI.reqLoading = false
                friendsUI.pendingReqCount = math.max(0, friendsUI.pendingReqCount - 1)
                friendsUI.lastReqCheckTime = 0
                return
            end
        end
        return
    end

    -- ======== 编队界面点击处理 ========
    if gameState.phase == "FORMATION" then
        if phaseChangeCooldown > 0 then return end
        local ownedCount = formationUI.ownedCount or GetOwnedHeroCount()
        local canManualEdit = ownedCount >= 10  -- 不满10人禁止手动调整
        -- 返回按钮
        if formationBackBtnRect and HitRect(formationBackBtnRect) then
            PopPhase("MENU"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return
        end
        -- 一键编队
        if formationUI.autoBtnRect and HitRect(formationUI.autoBtnRect) then
            formationUI.ownedCount = AutoFillFormation()
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "已自动编队", 1.5, { 120, 220, 100 }, 16)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 清空按钮 (不满10人时禁用)
        if formationUI.clearBtnRect and HitRect(formationUI.clearBtnRect) then
            if not canManualEdit then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "武灵不足10人, 无法调整编队", 1.5, { 255, 180, 80 }, 14)
            else
                gameSettings.formation = {}; SaveSettings()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "已清空编队", 1.5, { 220, 120, 80 }, 16)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 品质筛选标签
        if formationUI.tabRects then
            for _, tr in ipairs(formationUI.tabRects) do
                if HitRect(tr) then
                    formationUI.tab = tr.quality
                    formationUI.scrollY = 0; formationUI.scrollVel = 0
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
        -- 编队槽点击 (移除武灵, 不满10人时提示)
        if formationUI.slotRects then
            for i, sr in ipairs(formationUI.slotRects) do
                if HitRect(sr) and gameSettings.formation[i] then
                    if not canManualEdit then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "武灵不足10人, 无法调整编队", 1.5, { 255, 180, 80 }, 14)
                    else
                        table.remove(gameSettings.formation, i)
                        SaveSettings()
                    end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
        -- 卡牌列表区域: 开始拖拽 (点击在 EndPress 处理)
        local _, dy2 = ScreenToDesign(sx, sy)
        formationUI.isDragging = true
        formationUI.dragStartY = dy2
        formationUI.dragLastY = dy2
        formationUI.scrollVel = 0
        return
    end

    if gameState.phase == "POWER_RANK" then
        if menuBtnRects.powerRankBack and HitRect(menuBtnRects.powerRankBack) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 页签切换 (统一处理4个Tab)
        for _, tabId in ipairs({"power", "realm", "dummy", "faction"}) do
            local tabKey = "rankTab_" .. tabId
            if menuBtnRects[tabKey] and HitRect(menuBtnRects[tabKey]) then
                if welfareState.rankTab ~= tabId then
                    welfareState.rankTab = tabId
                    welfareState.rankViewBtnRects = {}
                    welfareState.rankViewPopup = nil
                    if tabId == "dummy" and not welfareState.dummyLoaded then LoadDummyRank() end
                    if tabId == "faction" and not welfareState.factionRankLoaded then LoadFactionLevelRankForTab() end
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 弹窗交互（优先处理）
        if welfareState.rankViewPopup then
            local popup = welfareState.rankViewPopup
            -- 关闭按钮
            if popup.closeBtnRect and HitRect(popup.closeBtnRect) then
                welfareState.rankViewPopup = nil
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 复制UID按钮
            if popup.copyBtnRect and HitRect(popup.copyBtnRect) then
                local uidStr = tostring(popup.entry and popup.entry.userId or 0)
                SafeSetClipboard(uidStr)
                popup.copyFlash = 1.5
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "UID已复制: " .. uidStr, 1.2, { 140, 220, 180 }, 14)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 点击弹窗外部关闭
            if popup.bgRect and not HitRect(popup.bgRect) then
                welfareState.rankViewPopup = nil
                return
            end
            return  -- 弹窗打开时拦截所有点击
        end
        -- 查看按钮点击（通过 userId 查找，避免过滤后索引错位）
        local rankData
        if welfareState.rankTab == "realm" then
            rankData = welfareState.realmRank
        elseif welfareState.rankTab == "dummy" then
            rankData = welfareState.dummyRank
        else rankData = welfareState.powerRank end
        if rankData and welfareState.rankViewBtnRects then
            for i, btnRect in pairs(welfareState.rankViewBtnRects) do
                if btnRect and HitRect(btnRect) and btnRect.userId then
                    -- 通过 userId 从原始数据中精确查找对应条目
                    local entry = nil
                    for _, e in ipairs(rankData) do
                        if e.userId == btnRect.userId then entry = e; break end
                    end
                    if entry then
                        local realmIdx = entry.realmIdx or entry.rankIdx or 1
                        welfareState.rankViewPopup = {
                            entry = {
                                name = entry.name or "未知",
                                power = entry.power or entry.damage or 0,
                                skillCount = entry.skillCount or 0,
                                heroCount = entry.heroCount or 0,
                                realmIdx = realmIdx,
                                rank = btnRect.filteredIdx or i,
                                damage = entry.damage,
                                userId = entry.userId or 0,
                            }
                        }
                        PlaySFX(AUDIO.sfx_click)
                        return
                    end
                end
            end
        end
        -- 开始拖拽滚动（根据当前页签）
        local curScroll
        if welfareState.rankTab == "realm" then
            curScroll = welfareState.realmScroll
        elseif welfareState.rankTab == "dummy" then
            curScroll = welfareState.dummyScroll
        elseif welfareState.rankTab == "faction" then
            curScroll = welfareState.factionRankScroll
        else curScroll = welfareState.powerScroll end
        curScroll.isDragging = true
        curScroll.dragStartY = dy
        curScroll.dragLastY = dy
        curScroll.vel = 0
        return
    end

    -- 贡献榜详情独立界面
    if gameState.phase == "CONTRIB_RANK" then
        if menuBtnRects.contribRankBack and HitRect(menuBtnRects.contribRankBack) then
            PopPhase("WELFARE")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 开始拖拽滚动
        welfareState.contribDetailScroll.isDragging = true
        welfareState.contribDetailScroll.dragStartY = dy
        welfareState.contribDetailScroll.dragLastY = dy
        welfareState.contribDetailScroll.vel = 0
        return
    end

    -- 胜负界面点击返回首页
    if gameState.phase == "EQUIP_CODEX" then
        if equipCodexBackBtnRect and HitRect(equipCodexBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            return
        end
        for si, rect in ipairs(equipCodexSetRects) do
            if rect and HitRect(rect) then
                equipCodexState.selectedSet = si
                equipCodexState.scrollY = 0
                equipCodexState.scrollVel = 0
                return
            end
        end
        -- 记录拖拽起始位置（用于滚动）
        equipCodexState.dragStartY = dy
        equipCodexState.dragLastY = dy
        equipCodexState.isDragging = true
        equipCodexState.scrollVel = 0
        return
    end

    -- === 兵符管理界面输入 ===
    if gameState.phase == "SEAL_MGR" then
        -- ====== 优先级 1: 分解确认弹窗 (最高) ======
        if sealDecomposeState.show then
            if sealDecomposeBtnRects.confirm and HitRect(sealDecomposeBtnRects.confirm) then
                local ok = false
                if sealDecomposeState.source == "inventory" and sealDecomposeState.invIndex then
                    ok = DecomposeSealFromInventory(sealDecomposeState.invIndex)
                elseif sealDecomposeState.source == "equipped" and sealDecomposeState.heroIdx and sealDecomposeState.slotIdx then
                    ok = DecomposeEquippedSeal(sealDecomposeState.heroIdx, sealDecomposeState.slotIdx)
                end
                sealDecomposeState.show = false
                if ok then PlaySFX(AUDIO.sfx_click) end
                return
            end
            if sealDecomposeBtnRects.cancel and HitRect(sealDecomposeBtnRects.cancel) then
                sealDecomposeState.show = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            return  -- 分解确认弹窗打开时屏蔽其他点击
        end

        -- ====== 优先级 1.5: 兵符筛选分解确认弹窗 ======
        if sealInvFilterState.batchConfirmShow then
            if sealInvFilterBtnRects.batchConfirm and HitRect(sealInvFilterBtnRects.batchConfirm) then
                local cnt = ExecuteSealBatchDecomp(sealInvFilterState.filterMaxTier, sealInvFilterState.filterSlotType)
                sealInvFilterState.batchConfirmShow = false
                if cnt > 0 then PlaySFX(AUDIO.sfx_click) end
                return
            end
            if sealInvFilterBtnRects.batchCancel and HitRect(sealInvFilterBtnRects.batchCancel) then
                sealInvFilterState.batchConfirmShow = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 品质上限调整 ← →
            if sealInvFilterBtnRects.tierLeft and HitRect(sealInvFilterBtnRects.tierLeft) then
                sealInvFilterState.filterMaxTier = math.max(1, sealInvFilterState.filterMaxTier - 1)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if sealInvFilterBtnRects.tierRight and HitRect(sealInvFilterBtnRects.tierRight) then
                sealInvFilterState.filterMaxTier = math.min(7, sealInvFilterState.filterMaxTier + 1)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 孔位筛选调整 ← →
            if sealInvFilterBtnRects.slotLeft and HitRect(sealInvFilterBtnRects.slotLeft) then
                sealInvFilterState.filterSlotType = math.max(0, sealInvFilterState.filterSlotType - 1)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if sealInvFilterBtnRects.slotRight and HitRect(sealInvFilterBtnRects.slotRight) then
                sealInvFilterState.filterSlotType = math.min(6, sealInvFilterState.filterSlotType + 1)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            return  -- 筛选分解弹窗打开时屏蔽其他点击
        end

        -- ====== 优先级 1.6: 兵符选中分解确认弹窗 ======
        if sealInvFilterState.selectConfirmShow then
            if sealInvFilterBtnRects.selectConfirm and HitRect(sealInvFilterBtnRects.selectConfirm) then
                local cnt = ExecuteSealSelectDecomp(sealInvFilterState.selectedIds)
                sealInvFilterState.selectConfirmShow = false
                if cnt > 0 then PlaySFX(AUDIO.sfx_click) end
                return
            end
            if sealInvFilterBtnRects.selectCancel and HitRect(sealInvFilterBtnRects.selectCancel) then
                sealInvFilterState.selectConfirmShow = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            return  -- 选中分解确认弹窗屏蔽其他点击
        end

        -- ====== 优先级 2: 替换弹窗 ======
        if sealReplaceState.show then
            -- 关闭按钮
            if sealReplaceBtnRects.close and HitRect(sealReplaceBtnRects.close) then
                sealReplaceState.show = false
                sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 列表项按钮
            for _, rects in pairs(sealReplaceListRects) do
                if rects.equip and HitRect(rects.equip) then
                    local invIdx = rects.equip.invIndex
                    local ok = EquipSealFromInventory(invIdx, sealReplaceState.heroIdx, sealReplaceState.slotIdx)
                    if ok then
                        PlaySFX(AUDIO.sfx_click)
                        -- 装备后关闭弹窗
                        sealReplaceState.show = false
                        sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                    end
                    return
                end
                if rects.decompose and HitRect(rects.decompose) then
                    -- 打开分解确认弹窗
                    sealDecomposeState.show = true
                    sealDecomposeState.source = "inventory"
                    sealDecomposeState.invIndex = rects.decompose.invIndex
                    sealDecomposeState.heroIdx = nil
                    sealDecomposeState.slotIdx = nil
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 替换弹窗内拖拽开始（用于滚动）
            sealReplaceState.scroll.dragStartY = dy
            sealReplaceState.scroll.dragLastY = dy
            sealReplaceState.scroll.isDragging = true
            sealReplaceState.scroll.vel = 0
            return  -- 替换弹窗打开时屏蔽其他点击
        end

        -- ====== 优先级 3: 升级面板 ======
        if sealMgrState.showLevelUp then
            if sealMgrBtnRects.closeLevelUp and HitRect(sealMgrBtnRects.closeLevelUp) then
                sealMgrState.showLevelUp = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 替换按钮 (在升级面板中)
            if sealMgrBtnRects.replaceBtn and HitRect(sealMgrBtnRects.replaceBtn) then
                sealReplaceState.show = true
                sealReplaceState.heroIdx = sealMgrState.selectedHero
                sealReplaceState.slotIdx = sealMgrState.selectedSlot
                sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 分解按钮 (在升级面板中)
            if sealMgrBtnRects.decomposeBtn and HitRect(sealMgrBtnRects.decomposeBtn) then
                sealDecomposeState.show = true
                sealDecomposeState.source = "equipped"
                sealDecomposeState.invIndex = nil
                sealDecomposeState.heroIdx = sealMgrState.selectedHero
                sealDecomposeState.slotIdx = sealMgrState.selectedSlot
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 经验道具使用按钮
            for idx, rect in pairs(sealMgrExpItemRects) do
                if HitRect(rect) then
                    local ok = UseSealExpItem(sealMgrState.selectedHero, sealMgrState.selectedSlot, idx)
                    if ok then
                        PlaySFX(AUDIO.sfx_click)
                        SaveGameProgress()
                    else
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "无法使用!", 1.0, { 255, 100, 100 }, 14)
                    end
                    return
                end
            end
            -- 一键多级强化按钮
            if sealMgrBtnRects.batchMinus and HitRect(sealMgrBtnRects.batchMinus) then
                local sd = sealData[sealMgrState.selectedHero]
                local slot = sd and sd.slots and sd.slots[sealMgrState.selectedSlot]
                if slot then
                    local minTarget = slot.level + 1
                    sealBatchTarget = sealBatchTarget or (slot.level + 1)
                    sealBatchTarget = sealBatchTarget - 1
                    if sealBatchTarget < minTarget then sealBatchTarget = minTarget end
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if sealMgrBtnRects.batchPlus and HitRect(sealMgrBtnRects.batchPlus) then
                local sd = sealData[sealMgrState.selectedHero]
                local slot = sd and sd.slots and sd.slots[sealMgrState.selectedSlot]
                if slot then
                    sealBatchTarget = sealBatchTarget or (slot.level + 1)
                    sealBatchTarget = sealBatchTarget + 1
                    if sealBatchTarget > SEAL_MAX_LEVEL then sealBatchTarget = SEAL_MAX_LEVEL end
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if sealMgrBtnRects.batchGo and HitRect(sealMgrBtnRects.batchGo) then
                if sealBatchTarget then
                    local ok, msg = DoSealBatchEnhance(sealMgrState.selectedHero, sealMgrState.selectedSlot, sealBatchTarget)
                    if ok then
                        sealBatchTarget = nil  -- 重置
                    else
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, msg or "升级失败", 1.0, { 255, 100, 100 }, 14)
                    end
                end
                return
            end
            return  -- 升级面板打开时屏蔽其他点击
        end

        -- ====== 返回按钮 ======
        if sealMgrBtnRects.back and HitRect(sealMgrBtnRects.back) then
            PopPhase("GACHA")
            phaseChangeCooldown = 0.3
            sealMgrState.selectedHero = nil
            sealMgrState.selectedSlot = nil
            sealMgrState.showLevelUp = false
            sealMgrState.showHeroPicker = false
            sealInvFilterState.selectMode = false
            sealInvFilterState.selectedIds = {}
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- ====== 选中分解模式下的交互 ======
        if sealInvFilterState.selectMode then
            -- 全选按钮
            if sealInvFilterBtnRects.selectAll and HitRect(sealInvFilterBtnRects.selectAll) then
                for i = 1, #sealInventory do
                    sealInvFilterState.selectedIds[i] = true
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 确认分解按钮
            if sealInvFilterBtnRects.selectDoDecomp and HitRect(sealInvFilterBtnRects.selectDoDecomp) then
                local selCount = 0
                for _ in pairs(sealInvFilterState.selectedIds) do selCount = selCount + 1 end
                if selCount > 0 then
                    sealInvFilterState.selectConfirmShow = true
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 取消按钮
            if sealInvFilterBtnRects.selectCancelMode and HitRect(sealInvFilterBtnRects.selectCancelMode) then
                sealInvFilterState.selectMode = false
                sealInvFilterState.selectedIds = {}
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 列表区域：启动拖拽（短按切换选中在 EndPress 判定）
            sealMgrScroll.dragStartY = dy
            sealMgrScroll.dragLastY = dy
            sealMgrScroll.isDragging = true
            sealMgrScroll.vel = 0
            return  -- 选中模式屏蔽其他点击
        end

        -- ====== 筛选分解按钮 ======
        if sealInvFilterBtnRects.batchDecompBtn and HitRect(sealInvFilterBtnRects.batchDecompBtn) then
            sealInvFilterState.batchConfirmShow = true
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- ====== 选中分解按钮 ======
        if sealInvFilterBtnRects.selectDecompBtn and HitRect(sealInvFilterBtnRects.selectDecompBtn) then
            sealInvFilterState.selectMode = true
            sealInvFilterState.selectedIds = {}
            sealMgrScroll.y = 0
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "点击选中要分解的兵符", 1.0, { 100, 180, 255 }, 16)
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- ====== 仓库入口按钮 ======
        if sealMgrBtnRects.inventoryBtn and HitRect(sealMgrBtnRects.inventoryBtn) then
            -- 打开仓库弹窗 (显示当前选中英雄的第一个可用孔位, 或全部)
            local heroIdx = sealMgrState.selectedHero
            if heroIdx then
                sealReplaceState.show = true
                sealReplaceState.heroIdx = heroIdx
                -- 如果有选中孔位就用选中的，否则用第一个孔位
                sealReplaceState.slotIdx = sealMgrState.selectedSlot or 1
                sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end

        -- ====== 英雄选择弹窗 ======
        if sealMgrState.showHeroPicker then
            if sealMgrBtnRects.closeHeroPicker and HitRect(sealMgrBtnRects.closeHeroPicker) then
                sealMgrState.showHeroPicker = false
                heroPickerScroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false, contentH = 0, viewH = 0 }
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 弹窗内拖拽开始（短按选中英雄在 EndPress 判定）
            heroPickerScroll.dragStartY = dy
            heroPickerScroll.dragLastY = dy
            heroPickerScroll.isDragging = true
            heroPickerScroll.vel = 0
            return  -- 英雄选择弹窗打开时屏蔽其他点击
        end

        -- ====== 中心卡牌点击 → 英雄选择 ======
        if sealMgrBtnRects.centerCard and HitRect(sealMgrBtnRects.centerCard) then
            local maxHeroes = GetMaxConstellationHeroes()
            if #maxHeroes > 1 then
                sealMgrState.showHeroPicker = true
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end

        -- ====== 孔位点击 → 打开升级面板 ======
        for slotIdx, rect in pairs(sealMgrSlotRects) do
            if HitRect(rect) then
                local cardIdx = sealMgrState.selectedHero
                if cardIdx then
                    sealMgrState.selectedSlot = slotIdx
                    if sealData[cardIdx] and sealData[cardIdx].slots and sealData[cardIdx].slots[slotIdx] then
                        -- 已有兵符 → 打开升级面板
                        sealMgrState.showLevelUp = true
                    else
                        -- 空孔位 → 直接打开替换弹窗(装备)
                        sealReplaceState.show = true
                        sealReplaceState.heroIdx = cardIdx
                        sealReplaceState.slotIdx = slotIdx
                        sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                    end
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        return
    end

    -- === 搜打撤探索界面输入 === [EXPLORATION REMOVED]
    -- if gameState.phase == "EXPLORATION" then
    --     Exploration.HandlePress(dx, dy)
    --     return
    -- end

    if gameState.phase == "WORLD_MAP" then
        -- 行军动画期间屏蔽输入
        if rawget(_G, "WorldMap") and WorldMap.IsMarchActive and WorldMap.IsMarchActive() then
            return
        end
        -- 新手引导优先拦截输入
        if WorldMap.HandleGuideInput(dx, dy) then
            return
        end
        -- 回合报告拖拽滚动: 记录起始Y
        if worldMapState.phase == "TURN_REPORT" then
            worldMapState.reportDragging = true
            worldMapState.reportDragLastY = dy
        end
        -- 城池列表拖拽滚动: 记录起始Y (左侧230px区域)
        if dx < 230 then
            worldMapState.cityListDragging = true
            worldMapState.cityListDragStartY = dy
            worldMapState.cityListDragLastY = dy
        end
        WorldMap.HandleInput(dx, dy)
        return
    end

    if gameState.phase == "STAGE_SELECT" then
        -- 爆装弹窗关闭
        if stageState.showDropPopup then
            if stageDropCloseRect and HitRect(stageDropCloseRect) then
                stageState.showDropPopup = false
                stageState.lastDropReward = nil
                return
            end
            return  -- 弹窗打开时屏蔽其他点击
        end
        -- 预览弹窗
        if stageState.showPreview then
            if stagePreviewCloseRect and HitRect(stagePreviewCloseRect) then
                stageState.showPreview = false
                return
            end
            if stageStartBtnRect and HitRect(stageStartBtnRect) then
                -- 开始探索 (搜打撤模式)
                local stageIdx = stageState.currentStage
                local stage = STAGES[stageIdx]
                stageMaxTier = stage.maxTier or 1
                stageState.showPreview = false
                -- [EXPLORATION REMOVED] 探索模块已移除
                PlaySFX(AUDIO.sfx_click)
                return
                --[=[ EXPLORATION REMOVED: 以下探索代码已注释

                -- 初始化探索模块 (首次)
                if not Exploration.IsActive() then
                    Exploration.Init(vg, fontId, IMG)
                end

                SyncPlayerDataToExploration()

                -- 配置探索地图
                local gs = GameConfig.STAGE_GRID_SIZES[stageIdx] or 4
                Exploration.StartMap({
                    mode = "stage",
                    stageIdx = stageIdx,
                    stageName = stage.name,
                    gridSize = gs,
                    enemyScale = stage.enemyScale or 1.0,
                    maxTier = stage.maxTier or 1,
                    dropSets = stage.dropSets,
                    dropRateBonus = 0,
                })

                -- 设置回调
                Exploration.onStartBattle = function(enemyScale, maxTier, dropSets)
                    -- 从探索进入战斗
                    gameState.explorationMode = true
                    gameState.abyssFloor = nil
                    gameState.towerFloor = nil
                    gameState.isRanked = false
                    gameState.phase = "BATTLE"
                    gameState.battlePhase = "SHOP"
                    gameState.playerBaseHP = BASE_HP_MAX
                    gameState.enemyBaseHP = BASE_HP_MAX
                    gameState.gold = GameConfig.INITIAL_GOLD
                    gameState.totalKills = 0
                    gameState.battleTime = 0
                    gameState.drawCount = 0
                    gameState.goldTimer = 0
                    gameState.resultTimer = 0
                    gameState.autoMarch = false
                    stageMaxTier = maxTier or 1
                    for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                    activeSkillEffects = {}
                    skillTargeting.active = false
                    for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                    for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                    playerUnits = {}
                    enemyUnits = {}
                    inventory = {}
                    RefreshShop()
                    -- 应用探索增益
                    local buff = Exploration.GetBuff()
                    gameState.exploreBuff = buff  -- 存储供 AggregateBaseStats 使用
                    if buff then
                        if buff.type == "hp_bonus" then
                            gameState.playerBaseHP = BASE_HP_MAX + buff.value
                            gameState.playerBaseMax = BASE_HP_MAX + buff.value
                        end
                    end
                    -- 敌方部署 (按敌人规模调整)
                    local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 2))
                    local used = {}
                    for i = 1, enemyCount do
                        local idx
                        repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
                        used[idx] = true
                        if i <= #ENEMY_SLOTS then
                            local card = DeepCopy(ENEMY_CARDS[idx])
                            card.level = 1
                            card.constellation = 0
                            card.cardIdx = idx
                            ENEMY_SLOTS[i].filled = true
                            ENEMY_SLOTS[i].card = card
                        end
                    end
                    print("=== 探索战斗开始 (关卡: " .. stage.name .. ") ===")
                end

                Exploration.onComplete = function(result)
                    -- 探索完成回调: 发放奖励
                    if result then
                        if result.success then
                            playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                        end
                        local jadeReward = result.totalJade or 0
                        if exploreAdDoubleJade then
                            jadeReward = jadeReward * 2
                            exploreAdDoubleJade = false
                        end
                        result.totalJade = jadeReward  -- 更新用于后续显示
                        playerInfo.jade = playerInfo.jade + jadeReward
                        -- 按武技分配残片
                        if result.fragList then
                            for _, fi in ipairs(result.fragList) do
                                skillFragments[fi.skillIdx] = (skillFragments[fi.skillIdx] or 0) + fi.count
                            end
                        elseif (result.totalFrag or 0) > 0 then
                            -- 兼容旧数据: 随机分配
                            for _ = 1, result.totalFrag do
                                local idx = math.random(1, #SKILL_TECHNIQUES)
                                skillFragments[idx] = (skillFragments[idx] or 0) + 1
                            end
                        end
                        -- 装备掉落：直接使用探索中已确定的品级/套装/部位（保证显示与实际一致）
                        local equipDrops = {}
                        if result.equipCount and result.equipCount > 0 then
                            for _, loot in ipairs(result.loot) do
                                if loot.hasEquipment then
                                    local tier = loot.equipTier or 1
                                    local si = loot.equipSet or math.random(1, #EQUIPMENT_SETS)
                                    local pi = loot.equipSlotIdx or math.random(1, 7)
                                    local minQ = loot.equipMinQuality or 0
                                    local q = math.random(math.max(0, minQ), 100)
                                    local item = CreateEquipItem(si, pi, tier, q)
                                    playerInfo.totalEquips = playerInfo.totalEquips + 1
                                    table.insert(equipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                                end
                            end
                        end
                        -- 显示装备掉落通知（每件单独提示，告知品阶、槽位和品质）
                        for i, eqDrop in ipairs(equipDrops) do
                            local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "未知"
                            local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "未知"
                            local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                            local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255, 255, 255}
                            local qLabel = GetQualityLabel(eqDrop.quality or 0)
                            local eLv = eqDrop.level or 1
                            local dropMsg = "获得兵甲: " .. tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i - 1) * 30, dropMsg, 3.0, tc, 20)
                        end
                        -- 历劫模式: 星级奖励 + 关卡解锁
                        if result.mode == "stage" and result.success then
                            local si = result.stageIdx
                            local key = tostring(si)
                            -- 计算星级 (基于基地HP)
                            local hpPct = (gameState.playerBaseHP or 0) / (BASE_HP_MAX or 1)
                            local earnedStars = 1
                            if hpPct > 0.8 then
                                earnedStars = 3
                            elseif hpPct > 0.5 then earnedStars = 2 end
                            local prevStars = stageStars[key] or 0
                            if earnedStars > prevStars then
                                stageStars[key] = earnedStars
                                local totalJadeReward = 0
                                for s = prevStars + 1, earnedStars do
                                    local claimKey = key .. "_" .. s
                                    if not stageStarClaimed[claimKey] then
                                        stageStarClaimed[claimKey] = true
                                        totalJadeReward = totalJadeReward + (STAGE_STAR_JADE[s] or 0)
                                    end
                                end
                                if totalJadeReward > 0 then
                                    playerInfo.jade = playerInfo.jade + totalJadeReward
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "★" .. earnedStars .. " 星级奖励: +" .. totalJadeReward .. " 虎符", 2.0, {255, 220, 80}, 20)
                                end
                            end
                            if si >= stageState.maxUnlocked and si < #STAGES then
                                stageState.maxUnlocked = si + 1
                            end
                        end
                        -- 讨伐模式: 记录通关
                        if result.mode == "abyss" and result.success and result.abyssFloor then
                            local floorKey = tostring(result.abyssFloor)
                            if not abyssCleared[floorKey] then
                                abyssCleared[floorKey] = true
                            end
                            TrackDailyTask("abyss1", 1)
                            TrackWeeklyTask("wabyss3", 1)
                            TrackBattlePassTask("bp_wabyss3", 1)
                            TrackBattlePassTask("bp_sabyss10", 1)
                        end
                        if result.success or jadeReward > 0 or #equipDrops > 0 then
                            local rewardStr = "探索结束: +" .. (result.totalJade or 0) .. " 虎符"
                            if result.fragList and #result.fragList > 0 then
                                local totalF = 0
                                for _, fi in ipairs(result.fragList) do totalF = totalF + fi.count end
                                rewardStr = rewardStr .. " +" .. totalF .. "武技残片"
                            end
                            if #equipDrops > 0 then
                                rewardStr = rewardStr .. " +" .. #equipDrops .. "件兵甲"
                            end
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, rewardStr, 2.0, {255, 220, 80}, 22)
                        else
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "探索放弃, 未获得奖励", 2.0, {180, 180, 180}, 18)
                        end
                        -- 战令: 探索完成 (仅成功/撤离时追踪, 放弃不算)
                        if result.success then
                            TrackBattlePassTask("bp_explore1", 1)
                            TrackBattlePassTask("bp_wexplore5", 1)
                            TrackBattlePassTask("bp_sexplore15", 1)
                        end
                    end
                    gameState.explorationMode = false
                    gameState.noFullAuto = false  -- 离开探索, 恢复全自动可用
                    PopPhase("MENU")
                    SaveGameProgress()
                end

                Exploration.onShopPurchase = function(cost)
                    playerInfo.jade = math.max(0, playerInfo.jade - cost)
                end
                Exploration.onShowToast = function(msg)
                    ShowToast(msg, 2.0)
                end
                Exploration.canWatchAd = function()
                    if IsBattleAdFree() then return false end
                    return not IsDailyAdLimitReached()
                end
                Exploration.isBattleAdFree = function() return IsBattleAdFree() end
                Exploration.onWatchAdForDouble = function(callback)
                    if sdk then
                        ShowAdSafe(SafeAdCallback(function(result)
                            if result.success then
                                ReportAdWatch()
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符已翻倍!", 1.5, { 120, 255, 180 }, 18)
                                if callback then callback(true) end
                            else
                                if callback then callback(false) end
                            end
                        end))
                    else
                        ReportAdWatch()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符已翻倍!", 1.5, { 120, 255, 180 }, 18)
                        if callback then callback(true) end
                    end
                end

                PushPhase("EXPLORATION")
                PlaySFX(AUDIO.sfx_click)
                print("=== 开始探索: " .. stage.name .. " (" .. gs .. "×" .. gs .. ") ===")
                return
                --]=] -- END EXPLORATION REMOVED (STAGE_SELECT)
            end
            return
        end
        -- 返回按钮
        if stageBackBtnRect and HitRect(stageBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            return
        end
        -- 翻页按钮
        if stagePagePrevRect and HitRect(stagePagePrevRect) then
            if stageState.currentPage > 1 then
                stageState.currentPage = stageState.currentPage - 1
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        if stagePageNextRect and HitRect(stagePageNextRect) then
            if stageState.currentPage < STAGE_TOTAL_PAGES then
                stageState.currentPage = stageState.currentPage + 1
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        -- 宝箱点击
        for ci, cRect in ipairs(stageChestRects) do
            if cRect and HitRect(cRect) then
                local chestKey = tostring(cRect.page) .. "_" .. tostring(cRect.threshold)
                local pageStars = GetPageStars(cRect.page)
                if pageStars >= cRect.threshold and not stageChestClaimed[chestKey] then
                    stageChestClaimed[chestKey] = true
                    local reward = STAGE_CHEST_REWARDS[ci]
                    if reward then
                        GrantRewardTable(reward)
                        local msg = "宝箱奖励: +" .. reward.jade .. " 虎符"
                        if reward.frag and reward.frag > 0 then
                            msg = msg .. " +" .. reward.frag .. " 武技残片"
                        end
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, msg, 2.0, {255, 220, 80}, 20)
                    end
                    PlaySFX(AUDIO.sfx_click)
                    SaveGameProgress()
                else
                    if stageChestClaimed[chestKey] then
                        ShowToast("已领取")
                    else
                        ShowToast("需要 " .. cRect.threshold .. " 星才能领取")
                    end
                end
                return
            end
        end
        -- 关卡节点点击 (stageNodeRects 现在携带 stageIdx)
        for i, rect in ipairs(stageNodeRects) do
            if rect and HitRect(rect) then
                local stageIdx = rect.stageIdx
                if stageIdx and stageIdx <= stageState.maxUnlocked then
                    stageState.currentStage = stageIdx
                    stageState.showPreview = true
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        return
    end

    -- === 每日副本界面输入 ===
    if gameState.phase == "DAILY_DUNGEON" then
        if phaseChangeCooldown > 0 then return end

        -- 确认弹窗
        if dailyDungeonState.showConfirm then
            -- 关闭
            if dailyDungeonCloseRect and HitRect(dailyDungeonCloseRect) then
                dailyDungeonState.showConfirm = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 副本2: 套装选择按钮
            local di = dailyDungeonState.selectedDungeon
            if di == 2 then
                for si = 1, 7 do
                    if dailyDungeonSetBtnRects[si] and HitRect(dailyDungeonSetBtnRects[si]) then
                        dailyDungeonState.selectedSet = si
                        PlaySFX(AUDIO.sfx_click)
                        return
                    end
                end
            end
            -- 消耗虎符进入按钮
            if dailyDungeonConfirmBtnRect and HitRect(dailyDungeonConfirmBtnRect) then
                if not di or dailyDungeonState.completed[di] then return end
                PlaySFX(AUDIO.sfx_click)

                local function EnterDailyDungeon()
                    -- [EXPLORATION REMOVED] 探索模块已移除
                    dailyDungeonState.showConfirm = false
                    ShowToast("探索功能暂未开放")
                    return
                    --[=[ EXPLORATION REMOVED: 以下探索代码已注释
                    SaveGameProgress()

                    -- 初始化探索模块
                    if not Exploration.IsActive() then
                        Exploration.Init(vg, fontId, IMG)
                    end
                    SyncPlayerDataToExploration()

                    -- 副本配置
                    local eScale = 1.0 + (playerInfo.rankIdx or 1) * 0.15
                    local highTierMul = (di == 3) and 10 or 1
                    local dailyMode = "daily" .. di

                    Exploration.StartMap({
                        mode = dailyMode,
                        gridSize = 5,
                        enemyScale = eScale,
                        maxTier = 6,
                        dropSets = (di == 2) and { dailyDungeonState.selectedSet } or {1,2,3,4,5,6,7},
                        highTierMultiplier = highTierMul,
                        dropRateBonus = 0.3,
                    })

                    -- 战斗回调
                    Exploration.onStartBattle = function(enemyScale, maxTier, dropSets)
                        gameState.explorationMode = true
                        gameState.noFullAuto = true   -- 每日副本禁止全自动
                        gameState.autoBattle = false
                        gameState.abyssFloor = nil
                        gameState.towerFloor = nil
                        gameState.isRanked = false
                        gameState.phase = "BATTLE"
                        gameState.battlePhase = "SHOP"
                        gameState.playerBaseHP = BASE_HP_MAX
                        gameState.enemyBaseHP = BASE_HP_MAX
                        gameState.gold = GameConfig.INITIAL_GOLD
                        gameState.totalKills = 0
                        gameState.battleTime = 0
                        gameState.drawCount = 0
                        gameState.goldTimer = 0
                        gameState.resultTimer = 0
                        gameState.autoMarch = false
                        stageMaxTier = maxTier or 1
                        for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                        activeSkillEffects = {}
                        skillTargeting.active = false
                        for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                        for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                        playerUnits = {}
                        enemyUnits = {}
                        inventory = {}
                        RefreshShop()
                        local buff = Exploration.GetBuff()
                        gameState.exploreBuff = buff
                        if buff then
                            if buff.type == "hp_bonus" then
                                gameState.playerBaseHP = BASE_HP_MAX + buff.value
                                gameState.playerBaseMax = BASE_HP_MAX + buff.value
                            end
                        end
                        local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 2))
                        local used = {}
                        for i = 1, enemyCount do
                            local idx
                            repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
                            used[idx] = true
                            if i <= #ENEMY_SLOTS then
                                local card = DeepCopy(ENEMY_CARDS[idx])
                                card.level = 1
                                card.constellation = 0
                                card.cardIdx = idx
                                ENEMY_SLOTS[i].filled = true
                                ENEMY_SLOTS[i].card = card
                            end
                        end
                        -- 敌方战力匹配玩家当前战力
                        local ppTotal = CalcPlayerTotalPower()
                        local nonHP = CalcRankPowerScore() + CalcEquipPowerScore() + CalcSkillPowerScore()
                        local targetHP = math.max(1, ppTotal - nonHP)
                        local rawEP = 0
                        for _, s in ipairs(ENEMY_SLOTS) do
                            if s.filled and s.card then
                                rawEP = rawEP + (s.card.atk * 2 + s.card.def + s.card.hp * 0.1)
                            end
                        end
                        if rawEP > 0 then
                            local sc = targetHP / rawEP
                            for _, s in ipairs(ENEMY_SLOTS) do
                                if s.filled and s.card then
                                    s.card.atk = math.floor(s.card.atk * sc)
                                    s.card.def = math.floor(s.card.def * sc)
                                    s.card.hp  = math.floor(s.card.hp * sc)
                                end
                            end
                        end
                        ApplyBattleLayout(1)
                        InitAISkills()
                        print("=== 每日副本战斗 (类型" .. di .. ") ===")
                    end

                    Exploration.onComplete = function(result)
                        if result then
                            if result.success then
                                dailyDungeonState.completed[di] = true  -- 只有走撤离通道才标记通关
                                playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                            end
                            local jadeReward = result.totalJade or 0
                            if exploreAdDoubleJade then
                                jadeReward = jadeReward * 2
                                exploreAdDoubleJade = false
                            end
                            result.totalJade = jadeReward  -- 更新用于后续显示
                            playerInfo.jade = playerInfo.jade + jadeReward
                            if result.fragList then
                                for _, fItem in ipairs(result.fragList) do
                                    skillFragments[fItem.skillIdx] = (skillFragments[fItem.skillIdx] or 0) + fItem.count
                                end
                            end
                            -- 每日副本专属掉落逻辑
                            local ddEquipDrops = {}
                            if result.equipCount and result.equipCount > 0 then
                                for _, loot in ipairs(result.loot) do
                                    if loot.hasEquipment then
                                        local tier = loot.equipTier or 2
                                        local si = loot.equipSet or math.random(1, #EQUIPMENT_SETS)
                                        local pi = loot.equipSlotIdx or math.random(1, 7)
                                        -- 副本1: 强制指定部位
                                        if di == 1 then
                                            pi = dailyDungeonState.todaySlot
                                        end
                                        -- 副本2: 强制指定套装
                                        if di == 2 then
                                            si = dailyDungeonState.selectedSet
                                        end
                                        local minQ = loot.equipMinQuality or 0
                                        local q = math.random(math.max(0, minQ), 100)
                                        local item = CreateEquipItem(si, pi, tier, q)
                                        playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                                        table.insert(ddEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                                    end
                                end
                            end
                            -- 保底: 每个副本至少掉1件装备 (仅成功/撤离时触发, 放弃不保底)
                            if #ddEquipDrops == 0 and result.success then
                                local si = (di == 2) and dailyDungeonState.selectedSet or math.random(1, #EQUIPMENT_SETS)
                                local pi = (di == 1) and dailyDungeonState.todaySlot or math.random(1, 7)
                                local tier = (di == 3) and math.random(4, 6) or math.random(2, 4)
                                local item = CreateEquipItem(si, pi, tier, math.random(40, 100))
                                playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                                table.insert(ddEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                            end
                            if result.success or jadeReward > 0 or #ddEquipDrops > 0 then
                                for i, eqDrop in ipairs(ddEquipDrops) do
                                    local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "未知"
                                    local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "未知"
                                    local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                                    local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255,255,255}
                                    local qLabel = GetQualityLabel(eqDrop.quality or 0)
                                    local eLv = eqDrop.level or 1
                                    local dropMsg = tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i - 1) * 30, dropMsg, 3.0, tc, 20)
                                end
                                local ddStr = "副本完成: +" .. #ddEquipDrops .. "件兵甲"
                                if jadeReward > 0 then ddStr = ddStr .. " +" .. jadeReward .. " 虎符" end
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, ddStr, 2.5, {80, 220, 160}, 22)
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "副本放弃, 未获得奖励", 2.0, {180, 180, 180}, 18)
                            end
                        end
                        gameState.explorationMode = false
                        gameState.noFullAuto = false  -- 离开副本, 恢复全自动可用
                        PopPhase("MENU")
                        SaveGameProgress()
                    end

                    Exploration.onShopPurchase = function(cost)
                        playerInfo.jade = math.max(0, playerInfo.jade - cost)
                    end
                    Exploration.onShowToast = function(msg)
                        ShowToast(msg, 2.0)
                    end
                    Exploration.canWatchAd = function()
                        if IsBattleAdFree() then return false end
                        return not IsDailyAdLimitReached()
                    end
                    Exploration.isBattleAdFree = function() return IsBattleAdFree() end
                    Exploration.onWatchAdForDouble = function(callback)
                        if sdk then
                            ShowAdSafe(SafeAdCallback(function(res)
                                if res.success then
                                    ReportAdWatch()
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符已翻倍!", 1.5, {120,255,180}, 18)
                                    if callback then callback(true) end
                                else
                                    if callback then callback(false) end
                                end
                            end))
                        else
                            ReportAdWatch()
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符已翻倍!", 1.5, {120,255,180}, 18)
                            if callback then callback(true) end
                        end
                    end

                    PushPhase("EXPLORATION")
                    PlaySFX(AUDIO.sfx_click)
                    print("=== 开始每日副本" .. di .. ": " .. DAILY_DUNGEON_NAMES[di] .. " (5×5) ===")
                    --]=] -- END EXPLORATION REMOVED (DAILY_DUNGEON)
                end

                -- 扣除300虎符入场
                local DUNGEON_ENTRY_COST = 300
                if playerInfo.jade >= DUNGEON_ENTRY_COST then
                    playerInfo.jade = playerInfo.jade - DUNGEON_ENTRY_COST
                    EnterDailyDungeon()
                else
                    ShowToast("虎符不足，需要 " .. DUNGEON_ENTRY_COST .. " 虎符", 2.0)
                end
                return
            end
            return
        end

        -- 返回按钮
        if dailyDungeonBackRect and HitRect(dailyDungeonBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 副本卡片点击
        for di = 1, 3 do
            if dailyDungeonCardRects[di] and HitRect(dailyDungeonCardRects[di]) then
                if dailyDungeonState.completed[di] then
                    ShowToast("今日已完成此副本")
                else
                    dailyDungeonState.selectedDungeon = di
                    dailyDungeonState.showConfirm = true
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        return
    end

    -- === 探索资源副本界面输入 ===
    if gameState.phase == "RESOURCE_DUNGEON" then
        if phaseChangeCooldown > 0 then return end

        -- 确认弹窗
        if resourceDungeonState.showConfirm then
            -- 关闭按钮
            if resourceDungeonConfirmRect and resourceDungeonConfirmRect.close and HitRect(resourceDungeonConfirmRect.close) then
                resourceDungeonState.showConfirm = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 确认进入按钮
            if resourceDungeonConfirmRect and resourceDungeonConfirmRect.enter and HitRect(resourceDungeonConfirmRect.enter) then
                local ti = resourceDungeonState.selectedType
                if not ti or resourceDungeonState.completed[ti] then return end
                local rdCfg = GameConfig.RESOURCE_DUNGEON
                local typeInfo = rdCfg.types[ti]
                if not typeInfo then return end
                -- 检查虎符
                if playerInfo.jade < rdCfg.entryCost then
                    ShowToast("虎符不足! 需要 " .. rdCfg.entryCost .. " 虎符")
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                PlaySFX(AUDIO.sfx_click)

                local function EnterResourceDungeon()
                    -- [EXPLORATION REMOVED] 探索模块已移除
                    resourceDungeonState.showConfirm = false
                    ShowToast("探索功能暂未开放")
                    return
                    --[=[ EXPLORATION REMOVED: 以下探索代码已注释
                    -- 扣除门票
                    playerInfo.jade = playerInfo.jade - rdCfg.entryCost
                    resourceDungeonState.showConfirm = false
                    -- 不立即标记完成, 通关才算
                    SaveGameProgress()

                    -- 初始化探索模块
                    if not Exploration.IsActive() then
                        Exploration.Init(vg, fontId, IMG)
                    end
                    SyncPlayerDataToExploration()

                    -- 副本配置: 遭遇战模式
                    local eScale = 1.0 + (playerInfo.rankIdx or 1) * 0.15
                    local ppTotal = CalcPlayerTotalPower()
                    -- 略高于玩家战力
                    eScale = eScale * (1.0 + math.random() * 0.1)

                    Exploration.StartMap({
                        mode = "resource_" .. typeInfo.id,
                        gridSize = rdCfg.gridSize,
                        enemyScale = eScale,
                        maxTier = typeInfo.maxTier,
                        dropSets = {1, 2, 3, 4, 5, 6, 7},
                        highTierMultiplier = typeInfo.highTierMultiplier or 1,
                        dropRateBonus = typeInfo.dropRateBonus or 0,
                        fragMultiplier = typeInfo.fragMultiplier or 1.0,
                        jadeMultiplier = typeInfo.jadeMultiplier or 1.0,
                        -- 遭遇战模式参数
                        encounterMode = true,
                        encounterRate = rdCfg.encounterRate,
                        enemyDensityOverride = rdCfg.enemyDensity,
                        chestCountOverride = rdCfg.chestCount,
                        blockedRatioOverride = rdCfg.blockedRatio,
                        eventRatioOverride = rdCfg.eventRatio,
                        chestGuardOverride = rdCfg.chestGuardChance,
                    })

                    -- 战斗回调
                    Exploration.onStartBattle = function(enemyScale2, maxTier2, dropSets2)
                        gameState.explorationMode = true
                        gameState.noFullAuto = true   -- 探索副本禁止全自动
                        gameState.autoBattle = false
                        gameState.abyssFloor = nil
                        gameState.towerFloor = nil
                        gameState.isRanked = false
                        gameState.phase = "BATTLE"
                        gameState.battlePhase = "SHOP"
                        gameState.playerBaseHP = BASE_HP_MAX
                        gameState.enemyBaseHP = BASE_HP_MAX
                        gameState.gold = GameConfig.INITIAL_GOLD
                        gameState.totalKills = 0
                        gameState.battleTime = 0
                        gameState.drawCount = 0
                        gameState.goldTimer = 0
                        gameState.resultTimer = 0
                        gameState.autoMarch = false
                        stageMaxTier = maxTier2 or typeInfo.maxTier or 1
                        for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                        activeSkillEffects = {}
                        skillTargeting.active = false
                        for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                        for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                        playerUnits = {}
                        enemyUnits = {}
                        inventory = {}
                        RefreshShop()
                        local buff = Exploration.GetBuff()
                        gameState.exploreBuff = buff
                        if buff then
                            if buff.type == "hp_bonus" then
                                gameState.playerBaseHP = BASE_HP_MAX + buff.value
                                gameState.playerBaseMax = BASE_HP_MAX + buff.value
                            end
                        end
                        -- 敌方单位
                        local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 2))
                        local used = {}
                        for i = 1, enemyCount do
                            local idx
                            repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
                            used[idx] = true
                            if i <= #ENEMY_SLOTS then
                                local card = DeepCopy(ENEMY_CARDS[idx])
                                card.level = 1
                                card.constellation = 0
                                card.cardIdx = idx
                                ENEMY_SLOTS[i].filled = true
                                ENEMY_SLOTS[i].card = card
                            end
                        end
                        -- 敌方战力匹配玩家当前战力 (略高)
                        local nonHP = CalcRankPowerScore() + CalcEquipPowerScore() + CalcSkillPowerScore()
                        local targetHP = math.max(1, ppTotal - nonHP)
                        targetHP = math.floor(targetHP * (1.0 + math.random() * 0.15))
                        local rawEP = 0
                        for _, s in ipairs(ENEMY_SLOTS) do
                            if s.filled and s.card then
                                rawEP = rawEP + (s.card.atk * 2 + s.card.def + s.card.hp * 0.1)
                            end
                        end
                        if rawEP > 0 then
                            local sc = targetHP / rawEP
                            for _, s in ipairs(ENEMY_SLOTS) do
                                if s.filled and s.card then
                                    s.card.atk = math.floor(s.card.atk * sc)
                                    s.card.def = math.floor(s.card.def * sc)
                                    s.card.hp  = math.floor(s.card.hp * sc)
                                end
                            end
                        end
                        ApplyBattleLayout(1)
                        InitAISkills()
                        print("=== 探索副本战斗 (" .. typeInfo.name .. ") ===")
                    end

                    Exploration.onComplete = function(result)
                        if result then
                            -- 只有撤离成功才标记通关 (退出=0收益不算完成)
                            if result.success then
                                resourceDungeonState.completed[ti] = true
                                playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                            end
                            local jadeReward = result.totalJade or 0
                            if exploreAdDoubleJade then
                                jadeReward = jadeReward * 2
                                exploreAdDoubleJade = false
                            end
                            result.totalJade = jadeReward  -- 更新用于后续显示
                            playerInfo.jade = playerInfo.jade + jadeReward
                            if result.fragList then
                                for _, fItem in ipairs(result.fragList) do
                                    skillFragments[fItem.skillIdx] = (skillFragments[fItem.skillIdx] or 0) + fItem.count
                                end
                            end
                            -- 探索副本专属掉落
                            local rdEquipDrops = {}
                            if result.equipCount and result.equipCount > 0 then
                                for _, loot in ipairs(result.loot) do
                                    if loot.hasEquipment then
                                        local tier = loot.equipTier or 2
                                        local si = loot.equipSet or math.random(1, #EQUIPMENT_SETS)
                                        local pi = loot.equipSlotIdx or math.random(1, 7)
                                        local minQ = loot.equipMinQuality or 0
                                        local q = math.random(math.max(0, minQ), 100)
                                        local item = CreateEquipItem(si, pi, tier, q)
                                        playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                                        table.insert(rdEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                                    end
                                end
                            end
                            -- 保底: 至少掉1件装备 (仅成功/撤离时触发, 放弃不保底)
                            if #rdEquipDrops == 0 and result.success then
                                local si = math.random(1, #EQUIPMENT_SETS)
                                local pi = math.random(1, 7)
                                local tier = math.random(2, math.min(typeInfo.maxTier, 4))
                                local item = CreateEquipItem(si, pi, tier, math.random(30, 90))
                                playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                                table.insert(rdEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                            end
                            if result.success or jadeReward > 0 or #rdEquipDrops > 0 then
                                for i2, eqDrop in ipairs(rdEquipDrops) do
                                    local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "未知"
                                    local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "未知"
                                    local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                                    local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255,255,255}
                                    local qLabel = GetQualityLabel(eqDrop.quality or 0)
                                    local eLv = eqDrop.level or 1
                                    local dropMsg = tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i2 - 1) * 30, dropMsg, 3.0, tc, 20)
                                end
                                local rdStr = typeInfo.name .. "完成: +" .. #rdEquipDrops .. "件兵甲"
                                if jadeReward > 0 then rdStr = rdStr .. " +" .. jadeReward .. " 虎符" end
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, rdStr, 2.5, {typeInfo.color[1], typeInfo.color[2], typeInfo.color[3]}, 22)
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "探索放弃, 未获得奖励", 2.0, {180, 180, 180}, 18)
                            end
                        end
                        -- 战令: 探索完成 (仅成功/撤离时追踪, 放弃不算)
                        if result and result.success then
                            TrackBattlePassTask("bp_explore1", 1)
                            TrackBattlePassTask("bp_wexplore5", 1)
                            TrackBattlePassTask("bp_sexplore15", 1)
                        end
                        gameState.explorationMode = false
                        gameState.noFullAuto = false  -- 离开探索, 恢复全自动可用
                        PopPhase("MENU")
                        SaveGameProgress()
                    end

                    Exploration.onShopPurchase = function(cost)
                        playerInfo.jade = math.max(0, playerInfo.jade - cost)
                    end
                    Exploration.onShowToast = function(msg)
                        ShowToast(msg, 2.0)
                    end
                    Exploration.canWatchAd = function()
                        if IsBattleAdFree() then return false end
                        return not IsDailyAdLimitReached()
                    end
                    Exploration.isBattleAdFree = function() return IsBattleAdFree() end
                    Exploration.onWatchAdForDouble = function(callback)
                        if sdk then
                            ShowAdSafe(SafeAdCallback(function(res)
                                if res.success then
                                    ReportAdWatch()
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符已翻倍!", 1.5, {120,255,180}, 18)
                                    if callback then callback(true) end
                                else
                                    if callback then callback(false) end
                                end
                            end))
                        else
                            ReportAdWatch()
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符已翻倍!", 1.5, {120,255,180}, 18)
                            if callback then callback(true) end
                        end
                    end

                    PushPhase("EXPLORATION")
                    PlaySFX(AUDIO.sfx_click)
                    print("=== 开始探索副本: " .. typeInfo.name .. " (7×7 遭遇战) ===")
                    --]=] -- END EXPLORATION REMOVED (RESOURCE_DUNGEON)
                end

                -- 直接进入 (门票制, 非广告制)
                EnterResourceDungeon()
                return
            end
            return
        end

        -- 返回按钮
        if resourceDungeonBackRect and HitRect(resourceDungeonBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 副本类型卡片点击
        for di = 1, 3 do
            if resourceDungeonCardRects[di] and HitRect(resourceDungeonCardRects[di]) then
                if resourceDungeonState.completed[di] then
                    ShowToast("今日已完成此探索")
                else
                    resourceDungeonState.selectedType = di
                    resourceDungeonState.showConfirm = true
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        return
    end

    -- === 战令通行证界面输入 ===
    if gameState.phase == "BATTLE_PASS" then
        if phaseChangeCooldown > 0 then return end

        -- 返回按钮
        if battlePassBackRect and HitRect(battlePassBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- Tab 切换
        for ti = 1, 4 do
            if battlePassTabRects[ti] and HitRect(battlePassTabRects[ti]) then
                if battlePassUIState.tab ~= ti then
                    battlePassUIState.tab = ti
                    battlePassUIState.scrollY = 0
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end

        -- Tab 1: 奖励总览 - 领取按钮
        if battlePassUIState.tab == 1 then
            -- 高级奖励领取（看广告 / 免广告特权直接领取）
            for lv, rect in pairs(battlePassClaimPremiumRects) do
                if HitRect(rect) then
                    if playerInfo.ad_free then
                        -- 免广告特权: 直接领取
                        if ClaimBattlePassPremiumReward(lv) then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "免广告直接领取!", 1.5, { 100, 255, 200 }, 18)
                        end
                    elseif sdk then
                        local capturedLv = lv
                        ShowAdSafe(SafeAdCallback(function(result)
                            if result.success then
                                ReportAdWatch()
                                if ClaimBattlePassPremiumReward(capturedLv) then
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "高级奖励已领取!", 1.5, { 255, 220, 100 }, 18)
                                end
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "广告播放失败", 1.5, { 255, 120, 80 }, 16)
                            end
                        end))
                    else
                        ReportAdWatch()
                        if ClaimBattlePassPremiumReward(lv) then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "高级奖励已领取!", 1.5, { 255, 220, 100 }, 18)
                        end
                    end
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 普通奖励领取（免费）
            for lv, rect in pairs(battlePassClaimFreeRects) do
                if HitRect(rect) then
                    if ClaimBattlePassFreeReward(lv) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "奖励已领取!", 1.5, { 120, 255, 180 }, 18)
                    end
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 横向拖拽滚动（奖励轨道）
            battlePassUIState.isDraggingReward = true
            battlePassUIState.dragStartX = dx
            battlePassUIState.dragStartScrollX = battlePassUIState.rewardScrollX
            return
        end

        -- Tab 2/3/4: 任务列表 - 领取按钮
        for _, btnInfo in ipairs(battlePassTaskBtnRects) do
            if HitRect(btnInfo) then
                ClaimBattlePassTaskReward(btnInfo.taskType, btnInfo.taskId)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 纵向拖拽滚动（任务列表）
        battlePassUIState.isDragging = true
        battlePassUIState.dragStartY = dy
        battlePassUIState.dragLastY = dy
        battlePassUIState.scrollVel = 0
        return
    end

    -- === 讨伐战界面输入 ===
    if gameState.phase == "ABYSS_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 预览弹窗
        if abyssState.showPreview then
            if abyssState.previewCloseRect and HitRect(abyssState.previewCloseRect) then
                abyssState.showPreview = false
                return
            end
            if abyssState.startBtnRect and HitRect(abyssState.startBtnRect) then
                -- 讨伐入场费：100虎符
                local ABYSS_COST = 100
                if playerInfo.jade < ABYSS_COST then
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "虎符不足! 需要" .. ABYSS_COST .. " 虎符", 1.5, { 255, 80, 80 }, 18)
                    return
                end
                -- 扣除虎符
                playerInfo.jade = playerInfo.jade - ABYSS_COST
                SaveGameProgress()

                -- 讨伐探索模式 (搜打撤)
                local fi = abyssState.selectedFloor
                abyssState.showPreview = false

                -- 随机地图大小 (4~8)
                local abyssGridSizes = {4, 5, 5, 6, 6, 7, 8}
                local gs = abyssGridSizes[fi] or math.random(4, 8)

                -- 将品及以上概率为普通探索的3倍
                local highTierMul = 3

                -- [EXPLORATION REMOVED] 探索模块已移除
                ShowToast("探索功能暂未开放")
                return
                --[=[ EXPLORATION REMOVED: 以下探索代码已注释

                -- 初始化探索模块
                if not Exploration.IsActive() then
                    Exploration.Init(vg, fontId, IMG)
                end
                SyncPlayerDataToExploration()

                Exploration.StartMap({
                    mode = "abyss",
                    abyssFloor = fi,
                    gridSize = gs,
                    enemyScale = abyssState.floors[fi] and abyssState.floors[fi].enemyScale or (1.8 + fi * 0.5),
                    maxTier = math.min(6, math.max(1, fi)),
                    dropSets = {1,2,3,4,5,6,7},
                    highTierMultiplier = highTierMul,
                    dropRateBonus = 0,
                })

                -- 设置回调 (与历劫共用 onComplete, 但标记为 abyss)
                Exploration.onStartBattle = function(enemyScale, maxTier, dropSets)
                    gameState.explorationMode = true
                    gameState.abyssFloor = fi
                    gameState.towerFloor = nil
                    gameState.isRanked = false
                    gameState.phase = "BATTLE"
                    gameState.battlePhase = "SHOP"
                    gameState.playerBaseHP = BASE_HP_MAX
                    gameState.enemyBaseHP = BASE_HP_MAX
                    gameState.gold = GameConfig.INITIAL_GOLD
                    gameState.totalKills = 0
                    gameState.battleTime = 0
                    gameState.drawCount = 0
                    gameState.goldTimer = 0
                    gameState.resultTimer = 0
                    gameState.autoMarch = false
                    stageMaxTier = maxTier or 1
                    for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                    activeSkillEffects = {}
                    skillTargeting.active = false
                    for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                    for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                    playerUnits = {}
                    enemyUnits = {}
                    inventory = {}
                    RefreshShop()
                    -- 应用探索增益
                    local buff = Exploration.GetBuff()
                    gameState.exploreBuff = buff
                    if buff then
                        if buff.type == "hp_bonus" then
                            gameState.playerBaseHP = BASE_HP_MAX + buff.value
                            gameState.playerBaseMax = BASE_HP_MAX + buff.value
                        end
                    end
                    -- 敌方部署
                    local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 2))
                    local used = {}
                    for i = 1, enemyCount do
                        local idx
                        repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
                        used[idx] = true
                        if i <= #ENEMY_SLOTS then
                            local card = DeepCopy(ENEMY_CARDS[idx])
                            card.level = 1
                            card.constellation = 0
                            card.cardIdx = idx
                            ENEMY_SLOTS[i].filled = true
                            ENEMY_SLOTS[i].card = card
                        end
                    end
                    InitAISkills()  -- 讨伐模式启用AI技能
                    print("=== 讨伐探索战斗 第" .. fi .. "层 ===")
                end

                Exploration.onComplete = function(result)
                    if result then
                        if result.success then
                            playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                        end
                        local jadeReward = result.totalJade or 0
                        if exploreAdDoubleJade then
                            jadeReward = jadeReward * 2
                            exploreAdDoubleJade = false
                        end
                        result.totalJade = jadeReward
                        playerInfo.jade = playerInfo.jade + jadeReward
                        -- 按武技分配残片
                        if result.fragList then
                            for _, fItem in ipairs(result.fragList) do
                                skillFragments[fItem.skillIdx] = (skillFragments[fItem.skillIdx] or 0) + fItem.count
                            end
                        elseif (result.totalFrag or 0) > 0 then
                            for _ = 1, result.totalFrag do
                                local idx = math.random(1, #SKILL_TECHNIQUES)
                                skillFragments[idx] = (skillFragments[idx] or 0) + 1
                            end
                        end
                        local abEquipDrops = {}
                        if result.equipCount and result.equipCount > 0 then
                            for _, loot in ipairs(result.loot) do
                                if loot.hasEquipment then
                                    local tier = loot.equipTier or 1
                                    local si = loot.equipSet or math.random(1, #EQUIPMENT_SETS)
                                    local pi = loot.equipSlotIdx or math.random(1, 7)
                                    local minQ = loot.equipMinQuality or 0
                                    local q = math.random(math.max(0, minQ), 100)
                                    local item = CreateEquipItem(si, pi, tier, q)
                                    playerInfo.totalEquips = playerInfo.totalEquips + 1
                                    table.insert(abEquipDrops, { setIdx = si, slotIdx = pi, tier = tier, quality = item.quality, level = item.level })
                                end
                            end
                        end
                        -- 显示装备掉落通知（含品质+装等）
                        for i, eqDrop in ipairs(abEquipDrops) do
                            local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "未知"
                            local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "未知"
                            local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                            local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255, 255, 255}
                            local qLabel = GetQualityLabel(eqDrop.quality or 0)
                            local eLv = eqDrop.level or 1
                            local dropMsg = "获得兵甲: " .. tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45 + (i - 1) * 30, dropMsg, 3.0, tc, 20)
                        end
                        if result.mode == "abyss" and result.success and result.abyssFloor then
                            local floorKey = tostring(result.abyssFloor)
                            if not abyssCleared[floorKey] then
                                abyssCleared[floorKey] = true
                            end
                            TrackDailyTask("abyss1", 1)
                            TrackWeeklyTask("wabyss3", 1)
                            TrackBattlePassTask("bp_wabyss3", 1)
                            TrackBattlePassTask("bp_sabyss10", 1)
                        end
                        local abRewardStr = "讨伐探索: +" .. (result.totalJade or 0) .. " 虎符"
                        if result.fragList and #result.fragList > 0 then
                            local totalF = 0
                            for _, fItem in ipairs(result.fragList) do totalF = totalF + fItem.count end
                            abRewardStr = abRewardStr .. " +" .. totalF .. "武技残片"
                        end
                        if #abEquipDrops > 0 then
                            abRewardStr = abRewardStr .. " +" .. #abEquipDrops .. "件兵甲"
                        end
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, abRewardStr, 2.5, {180, 120, 255}, 22)
                    end
                    -- 战令: 探索完成
                    TrackBattlePassTask("bp_explore1", 1)
                    TrackBattlePassTask("bp_wexplore5", 1)
                    TrackBattlePassTask("bp_sexplore15", 1)
                    gameState.explorationMode = false
                    gameState.noFullAuto = false  -- 离开探索, 恢复全自动可用
                    PopPhase("MENU")
                    SaveGameProgress()
                end

                Exploration.onShopPurchase = function(cost)
                    playerInfo.jade = math.max(0, playerInfo.jade - cost)
                end
                Exploration.onShowToast = function(msg)
                    ShowToast(msg, 2.0)
                end
                Exploration.canWatchAd = function()
                    if IsBattleAdFree() then return false end
                    return not IsDailyAdLimitReached()
                end
                Exploration.isBattleAdFree = function() return IsBattleAdFree() end
                Exploration.onWatchAdForDouble = function(callback)
                    if sdk then
                        ShowAdSafe(SafeAdCallback(function(result)
                            if result.success then
                                ReportAdWatch()
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符已翻倍!", 1.5, { 120, 255, 180 }, 18)
                                if callback then callback(true) end
                            else
                                if callback then callback(false) end
                            end
                        end))
                    else
                        ReportAdWatch()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符已翻倍!", 1.5, { 120, 255, 180 }, 18)
                        if callback then callback(true) end
                    end
                end

                -- 显示爆率信息
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                    "讨伐探索 " .. gs .. "×" .. gs .. " 将品↑概率×" .. highTierMul,
                    3.0, {180, 120, 255}, 20)

                PushPhase("EXPLORATION")
                PlaySFX(AUDIO.sfx_click)
                print("=== 讨伐探索 第" .. fi .. "层 " .. gs .. "×" .. gs .. " 将品↑概率×" .. highTierMul .. " ===")
                return
                --]=] -- END EXPLORATION REMOVED (ABYSS_SELECT)
            end
            return
        end

        -- 返回按钮
        if abyssState.backBtnRect and HitRect(abyssState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 关卡列表点击
        for i, rect in ipairs(abyssState.floorRects) do
            if rect and HitRect(rect) then
                local floor = abyssState.floors[i]
                if stageState.maxUnlocked >= floor.unlockStage then
                    abyssState.selectedFloor = i
                    abyssState.showPreview = true
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        return
    end

    -- === 无尽爬塔界面输入 ===
    if gameState.phase == "TOWER_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 排行榜面板打开时，优先处理排行榜交互
        if towerState.showLeaderboard then
            if towerState.leaderboardBackRect and HitRect(towerState.leaderboardBackRect) then
                towerState.showLeaderboard = false
                PlaySFX(AUDIO.sfx_click)
            end
            return  -- 排行榜打开时吞噬所有点击
        end

        -- 预览弹窗（挑战确认）
        if towerState.showPreview then
            if towerState.startBtnRect and HitRect(towerState.startBtnRect) then
                -- 999层上限检查
                if towerState.currentFloor > 999 then
                    ShowToast("已达本赛季最高层(999层)，请等待下个赛季")
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                -- 爬塔战斗开始（无需门票）
                towerState.showPreview = false
                local fl = towerState.currentFloor
                gameState.towerFloor = fl  -- 标记爬塔模式
                gameState.phase = "BATTLE"
                gameState.battlePhase = "SHOP"
                gameState.playerBaseHP = BASE_HP_MAX
                gameState.enemyBaseHP = BASE_HP_MAX
                gameState.gold = GameConfig.INITIAL_GOLD
                gameState.totalKills = 0
                gameState.gameTime = 0
                gameState.battleTime = 0
                gameState.drawCount = 0
                gameState.goldTimer = 0
                gameState.resultTimer = 0
                gameState.autoMarch = false
                -- 阶级随层数递增 (每10层+1阶, 爬塔最高王品5阶)
                stageMaxTier = math.min(5, math.max(1, math.floor((fl - 1) / 10) + 1))
                for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                activeSkillEffects = {}
                skillTargeting.active = false
                for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                playerUnits = {}
                enemyUnits = {}
                inventory = {}
                RefreshShop()
                local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 2))
                local used = {}
                for i = 1, enemyCount do
                    local idx
                    repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
                    used[idx] = true
                    if i <= #ENEMY_SLOTS then
                        local card = DeepCopy(ENEMY_CARDS[idx])
                        card.level = 1
                        card.constellation = 0
                        card.cardIdx = idx
                        ENEMY_SLOTS[i].filled = true
                        ENEMY_SLOTS[i].card = card
                    end
                end
                PlaySFX(AUDIO.sfx_click)
                print("=== 进入爬塔战斗 第" .. fl .. "层 ===")
                return
            end
            -- 关闭预览
            towerState.showPreview = false
            return
        end

        -- 返回按钮
        if towerState.backBtnRect and HitRect(towerState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 排行榜按钮
        if towerState.leaderboardBtnRect and HitRect(towerState.leaderboardBtnRect) then
            towerState.showLeaderboard = true
            if not towerState.rankLoaded then
                LoadTowerLeaderboard()
            end
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 点击主区域打开预览
        towerState.showPreview = true
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- === 排位赛界面输入 ===
    if gameState.phase == "RANKED_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 匹配中不允许其他操作
        if rankedState.isMatching then return end

        -- 排行榜弹窗
        if rankedState.showLeaderboard then
            -- 关闭排行榜
            if rankedState.backBtnRect and HitRect(rankedState.backBtnRect) then
                rankedState.showLeaderboard = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            return
        end

        -- 开始匹配按钮
        if rankedState.startBtnRect and HitRect(rankedState.startBtnRect) then
            rankedState.isMatching = true
            rankedState.matchAnim = 0
            -- 预生成对手
            local opp = GenerateRankedOpponent()
            rankedState.opponentName = opp.name
            rankedState.opponentPower = opp.totalPower
            rankedState.opponentCards = opp.cards
            -- 网络模式: 通知服务端创建排位会话（战斗结算时需要）
            if rawget(_G, "IsNetworkMode") and IsNetworkMode() then
                local Client = require("network.Client")
                local ok = Client.JoinRanked()
                if not ok then
                    rankedState.isMatching = false
                    if rawget(_G, "ShowToast") then ShowToast("鎺掍綅杩炴帴澶辫触", 2.0) end
                    return
                end
            end
            PlaySFX(AUDIO.sfx_click)
            print("=== 排位匹配开始 ===")
            return
        end

        -- 排行榜按钮
        if rankedState.rankBtnRect and HitRect(rankedState.rankBtnRect) then
            rankedState.showLeaderboard = true
            if not rankedState.rankLoaded then
                LoadRankedLeaderboard()
            end
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 返回按钮
        if rankedState.backBtnRect and HitRect(rankedState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        return
    end

    -- 探索战斗确认弹窗: 拦截所有点击 (退出/死亡)
    if gameState.exploreExitConfirm then
        local ddx, ddy = ScreenToDesign(sx, sy)
        local function HitECR(r)
            return r and ddx >= r.x and ddx <= r.x + r.w and ddy >= r.y and ddy <= r.y + r.h
        end

        -- 广告翻倍虎符按钮
        if HitECR(exploreConfirmBtnRects.adDouble) then
            PlaySFX(AUDIO.sfx_click)
            if not exploreAdDoubleJade then
                if playerInfo.ad_free then
                    exploreAdDoubleJade = true
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "免广告翻倍!", 1.5, { 100, 255, 200 }, 18)
                    print("[探索] [免广告] 翻倍虎符已激活")
                elseif sdk then
                    ShowAdSafe(SafeAdCallback(function(result)
                        if result.success then
                            exploreAdDoubleJade = true
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "虎符将翻倍!", 1.5, { 120, 255, 180 }, 18)
                            ReportAdWatch()
                            print("[探索] 广告翻倍虎符已激活")
                        end
                    end))
                else
                    exploreAdDoubleJade = true
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "[DEV] 虎符将翻倍!", 1.5, { 120, 255, 180 }, 18)
                    ReportAdWatch()
                    print("[探索] [DEV] 广告翻倍虎符已激活")
                end
            end
            return
        end

        -- 确认按钮
        if HitECR(exploreConfirmBtnRects.confirm) then
            PlaySFX(AUDIO.sfx_click)
            if gameState.exploreExitConfirm.type == "abyss_exit" then
                -- 讨伐战退出: 保留30%收获, 返回讨伐战页面
                gameState.exploreExitConfirm = nil
                -- Exploration.ForceAbandonWithRetain(0.3)  -- 30%保留 [EXPLORATION REMOVED]
                gameState.explorationMode = false
                gameState.noFullAuto = false
                gameState.abyssFloor = nil
                PopPhase("ABYSS_SELECT")
                abyssState.showPreview = false
                phaseChangeCooldown = 0.3
                SaveGameProgress()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "讨伐撤退 (保留30%收获)", 2.0, { 255, 200, 100 }, 16)
                print("[讨伐] 中途退出, 保留30%收获, 返回讨伐战页面")
            else
                -- 探索战斗退出: 回到探索地图 (丢失10%-30%已有战利品) [EXPLORATION REMOVED]
                gameState.exploreExitConfirm = nil
                -- Exploration.OnBattleReturn(false)  -- [EXPLORATION REMOVED]
                -- local lostCount = Exploration.GetState().lastBattleLostCount or 0
                -- if lostCount > 0 then
                --     AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "丢失了 " .. lostCount .. " 件战利品", 2.0, { 255, 120, 80 }, 16)
                -- end
                gameState.explorationMode = false
                gameState.phase = "MENU"  -- 探索已移除, 直接回主菜单
                phaseChangeCooldown = 0.3
                print("[探索] 探索模块已移除, 返回主菜单")
            end
            return
        end

        -- 看广告复活按钮 (仅死亡时)
        if gameState.exploreExitConfirm.type == "death"
           and HitECR(exploreConfirmBtnRects.revive) then
            PlaySFX(AUDIO.sfx_click)
            -- 复活成功的通用处理
            local function doRevive()
                -- Exploration.OnBattleReturn(false)  -- [EXPLORATION REMOVED]
                gameState.explorationMode = false
                gameState.exploreExitConfirm = nil
                gameState.phase = "MENU"  -- 探索已移除, 直接回主菜单
                phaseChangeCooldown = 0.3
            end
            if playerInfo.ad_free then
                doRevive()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "免广告复活成功!", 1.5, { 100, 255, 200 }, 16)
                print("[探索] [免广告] 复活, 返回探索地图")
            elseif sdk then
                ShowAdSafe(SafeAdCallback(function(result)
                    if result.success then
                        doRevive()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "复活成功! 继续探索", 1.5, { 120, 255, 180 }, 16)
                        ReportAdWatch()
                        print("[探索] 广告复活, 返回探索地图")
                    end
                end))
            else
                -- DEV模式: 模拟广告成功
                doRevive()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "[DEV] 复活成功!", 1.5, { 120, 255, 180 }, 16)
                ReportAdWatch()
                print("[探索] [DEV] 广告复活, 返回探索地图")
            end
            return
        end

        return  -- 弹窗显示时拦截所有其他点击
    end

        if gameState.phase == "WIN" or gameState.phase == "LOSE" then
        if gameState.phase == "WIN" then
            -- WIN: 奖励弹窗流程
            if gameState.showRewardPopup then
                -- 弹窗已显示, 响应确认按钮和广告翻倍按钮
                local ddx, ddy = ScreenToDesign(sx, sy)
                -- 广告翻倍按钮
                if rewardAdDoubleRect then
                    local r = rewardAdDoubleRect
                    if ddx >= r.x and ddx <= r.x + r.w and ddy >= r.y and ddy <= r.y + r.h then
                        WatchAdForDoubleReward()
                        return
                    end
                end
                -- 确认按钮
                if rewardPopupConfirmRect then
                    local r = rewardPopupConfirmRect
                    if ddx >= r.x and ddx <= r.x + r.w and ddy >= r.y and ddy <= r.y + r.h then
                        gameState.showRewardPopup = false
                        rewardPopupConfirmRect = nil
                        rewardAdDoubleRect = nil
                        if gameState.isRanked then
                            gameState.phase = "RANKED_SELECT"
                            gameState.isRanked = false
                            gameState.rankedDelta = nil
                            rankedState.showPreview = false
                        elseif gameState.abyssFloor then
                            gameState.phase = "ABYSS_SELECT"
                            abyssState.showPreview = false
                            gameState.abyssFloor = nil
                        elseif gameState.towerFloor then
                            gameState.phase = "TOWER_SELECT"
                            towerState.showPreview = false
                            gameState.towerFloor = nil
                        elseif gameState.worldMapBattle then
                            gameState.phase = "WORLD_MAP"
                            gameState.worldMapBattle = nil
                        else
                            gameState.phase = "MENU"
                        end
                        phaseChangeCooldown = 0.3
                        print("=== 奖励确认, 返回 ===")
                    end
                end
            end
            -- 弹窗未弹出时不响应点击
            return
        end
        -- LOSE: 原有逻辑
        if gameState.resultTimer > 1.5 then
            -- 探索模式: 弹出死亡确认弹窗 (确认放弃 / 看广告复活) [EXPLORATION REMOVED]
            -- explorationMode is always false since exploration module was removed
            -- if gameState.explorationMode then
            --     if not gameState.exploreExitConfirm then
            --         gameState.exploreExitConfirm = { type = gameState.abyssFloor and "abyss_exit" or "death" }
            --     end
            --     -- 弹窗按钮点击在下方统一处理
            --     return
            -- end
            if adRects.revive then
                local ddx, ddy = ScreenToDesign(sx, sy)
                if ddx >= adRects.revive.x and ddx <= adRects.revive.x + adRects.revive.w
                   and ddy >= adRects.revive.y and ddy <= adRects.revive.y + adRects.revive.h then
                    WatchAdForRevive()
                    return
                end
            end
            adRects.revive = nil
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "再接再厉!", 2.0, { 200, 160, 100 }, 20)
            if gameState.isRanked then
                gameState.phase = "RANKED_SELECT"
                gameState.isRanked = false
                gameState.rankedDelta = nil
                rankedState.showPreview = false
            elseif gameState.abyssFloor then
                gameState.phase = "ABYSS_SELECT"
                abyssState.showPreview = false
                gameState.abyssFloor = nil
            elseif gameState.towerFloor then
                gameState.phase = "TOWER_SELECT"
                towerState.showPreview = false
                gameState.towerFloor = nil
            elseif gameState.worldMapBattle then
                gameState.phase = "WORLD_MAP"
                gameState.worldMapBattle = nil
            else
                gameState.phase = "MENU"
            end
            phaseChangeCooldown = 0.3
            print("=== 返回 ===")
        end
        return
    end

    -- (已移除武技详情弹窗)

    -- 战斗规则弹窗: 拦截所有点击，支持滚动
    if battleRulesState.show then
        local cr = battleRulesState.closeBtnRect
        if cr and dx >= cr.x and dx <= cr.x + cr.w and dy >= cr.y and dy <= cr.y + cr.h then
            battleRulesState.show = false
            battleRulesState.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 面板区域内开始拖拽滚动
        local pr = battleRulesState.panelRect
        if pr and dx >= pr.x and dx <= pr.x + pr.w and dy >= pr.y and dy <= pr.y + pr.h then
            battleRulesState.isDragging = true
            battleRulesState.lastTouchY = dy
            battleRulesState.vel = 0
        else
            -- 点击弹窗外关闭
            battleRulesState.show = false
            battleRulesState.isDragging = false
        end
        return
    end

    -- 战斗返回按钮 (设计坐标)
    local function HitDesignRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end
    if HitDesignRect(battleBackBtnRect) then
        -- [EXPLORATION REMOVED] explorationMode is always false, removed two branches
        -- if gameState.explorationMode and gameState.abyssFloor then
        --     gameState.exploreExitConfirm = { type = "abyss_exit" }
        --     PlaySFX(AUDIO.sfx_click)
        --     return
        -- elseif gameState.explorationMode then
        --     gameState.exploreExitConfirm = { type = "exit" }
        --     PlaySFX(AUDIO.sfx_click)
        --     return
        if gameState.isDummy then
            PopPhase("MENU")
            gameState.isDummy = false
            gameState.abyssFloor = nil
            gameState.towerFloor = nil
            gameState.isRanked = false
            dummyState.prepPhase = false
            PlaySFX(AUDIO.sfx_click)
            return
        elseif gameState.isRanked then
            -- 排位中途退出 = 判负扣分
            local shouldLeaveRankedBattle = true
            if IsServerAuthoritativeRankedMode and IsServerAuthoritativeRankedMode() then
                gameState.awaitingRankedResult = true
                gameState.rankedDelta = nil
                local Client = require("network.Client")
                local ok = Client.ForfeitRanked()
                if not ok then
                    gameState.awaitingRankedResult = false
                    shouldLeaveRankedBattle = false
                    if rawget(_G, "ShowToast") then ShowToast("鎺掍綅鎶曢檷鎻愪氦澶辫触", 2.0) end
                else
                    SaveGameProgress()
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鎶曢檷缁撶畻宸叉彁浜?", 2.0, { 255, 180, 120 }, 18)
                end
            elseif rankedState.score > 0 then
                rankedState.losses = rankedState.losses + 1
                if rankedState.streak > 0 then rankedState.streak = 0 end
                rankedState.streak = rankedState.streak - 1
                local delta = CalcRankedScoreChange(false, rankedState.streak)
                rankedState.score = math.max(0, rankedState.score + delta)
                ReportRankedScore()
                -- 网络模式: 通知服务端弃权
                SaveGameProgress()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "退出判负 " .. delta .. "分", 2.0, { 255, 100, 80 }, 18)
            end
            if shouldLeaveRankedBattle then
                PopPhase("RANKED_SELECT")
                gameState.isRanked = false
                gameState.rankedDelta = nil
                rankedState.showPreview = false
            end
        elseif gameState.abyssFloor then
            PopPhase("ABYSS_SELECT")
            abyssState.showPreview = false
            gameState.abyssFloor = nil
        elseif gameState.towerFloor then
            PopPhase("TOWER_SELECT")
            towerState.showPreview = false
            gameState.towerFloor = nil
        else
            -- 普通征途退出: 保留30%胜利奖励
            local baseJade = math.random(GameConfig.JADE_PER_WIN_MIN, GameConfig.JADE_PER_WIN_MAX)
            local retreatJade = math.max(1, math.floor(baseJade * 0.3))
            local retreatExp = math.max(1, math.floor(GameConfig.EXP_PER_WIN * 0.3))
            playerInfo.jade = playerInfo.jade + retreatJade
            playerInfo.exp = playerInfo.exp + retreatExp
            CheckPlayerLevelUp()
            playerInfo.totalBattles = (playerInfo.totalBattles or 0) + 1
            TrackDailyTask("battle3", 1)
            TrackWeeklyTask("wbattle15", 1)
            TrackBattlePassTask("bp_battle3", 1)
            TrackBattlePassTask("bp_wbattle20", 1)
            TrackBattlePassTask("bp_sbattle100", 1)
            SaveGameProgress()
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "撤退 +" .. retreatJade .. " 虎符 (30%)", 2.0, { 255, 200, 100 }, 16)
            PopPhase("MENU")
        end
        phaseChangeCooldown = 0.3
        -- 清理战斗状态
        for _, slot in ipairs(PLAYER_SLOTS) do
            slot.filled = false; slot.card = nil
        end
        playerUnits = {}
        enemyUnits = {}
        print("=== 战斗中返回首页 ===")
        return
    end

    -- 换战场按钮 (打桩准备阶段, 设计坐标)
    if gameState.isDummy and dummyState.prepPhase and dummyState.changeBgBtnRect then
        local r = dummyState.changeBgBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            gameState.abyssFloor = (gameState.abyssFloor % 7) + 1
            ApplyBattleLayout(gameState.abyssFloor + 1)  -- 讨伐层N → 布局索引N+1
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "战场 " .. gameState.abyssFloor .. "/7", 1.0, { 180, 220, 255 }, 14)
            PlaySFX(AUDIO.sfx_click)
            print("=== 切换战场背景: " .. gameState.abyssFloor .. " ===")
            return
        end
    end

    -- 换战场按钮 (普通战斗, 非讨伐/爬塔, 设计坐标)
    if not gameState.abyssFloor and not gameState.towerFloor and not gameState.isRanked and not gameState.isDummy and battleChangeBgBtnRect then
        local r = battleChangeBgBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            local newIdx = (currentLayoutIdx % 8) + 1
            ApplyBattleLayout(newIdx)
            local layoutName = BATTLE_LAYOUTS[newIdx] and BATTLE_LAYOUTS[newIdx].name or "默认"
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, layoutName, 1.0, { 180, 220, 255 }, 14)
            PlaySFX(AUDIO.sfx_click)
            print("=== 切换战场背景: " .. newIdx .. " " .. layoutName .. " ===")
            return
        end
    end

    -- 开战按钮 (仅SHOP阶段可用, 设计坐标)
    if HitFightButton(dx, dy) then
        if gameState.battlePhase == "SHOP" then
            -- 打桩模式：生成老虎并开始30秒计时
            if gameState.isDummy and dummyState.prepPhase then
                dummyState.prepPhase = false
                dummyState.totalDamage = 0
                dummyState.timer = 30

                -- 汇聚属性
                AggregateBaseStats()
                -- 重设敌方HP（AggregateBaseStats会覆盖）
                gameState.enemyBaseHP = 999999
                gameState.enemyBaseMax = 999999

                -- 生成100只巨兽老虎（每条车道20只）
                local bz = BATTLE_ZONE
                local tigerHP = 8000
                local tigerATK = 1
                local tigerDEF = 0
                local tigerUC = UNIT_CLASS.DEMON_WARRIOR
                for lane = 1, NUM_LANES do
                    local laneCX = GetLaneCenterX(lane)
                    for t = 1, 20 do
                        local spawnX = laneCX + (math.random() - 0.5) * LANE_WIDTH * 0.6
                        local spawnY = bz.centerY + (math.random() - 0.5) * (bz.bottom - bz.top) * 0.5
                        local unit = {
                            x = spawnX, y = spawnY,
                            hp = tigerHP, maxHp = tigerHP,
                            atk = tigerATK, def = tigerDEF,
                            speed = 0,
                            atkTimer = math.random() * 0.5, atkCooldown = tigerUC.atkCd,
                            atkRange = tigerUC.atkRange,
                            alive = true, isPlayer = false,
                            isRanged = false, unitClass = tigerUC,
                            animTimer = math.random() * 6.28, flashTimer = 0,
                            isHealer = false,
                            cloudSeed = math.random() * 100,
                            breakDmgAdd = 0,
                            laneIdx = lane,
                            isDummyTiger = true,
                        }
                        table.insert(enemyUnits, unit)
                    end
                end

                gameState.battlePhase = "FIGHT"
                gameState.autoMarch = true
                PlaySFX(AUDIO.sfx_march)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "30s打桩开始!", 1.5, { 255, 220, 80 }, 18)
                print("=== 30s打桩战斗开始 (100只巨兽老虎) ===")
            else
                gameState.battlePhase = "FIGHT"
                AggregateBaseStats()  -- 汇聚武灵属性到大本营
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "开战!", 1.5, { 255, 220, 80 }, 18)
                PlaySFX(AUDIO.sfx_march)
                -- 应用默认自动行军设置
                gameState.autoMarch = gameSettings.defaultAutoMarch
                -- 新手出兵策略提示 (仅首次)
                if not gameSettings.shownMarchHint then
                    gameSettings.shownMarchHint = true
                    gameSettings.battleCount = (gameSettings.battleCount or 0) + 1
                    SaveSettings()
                    ShowToast("提示: 点击右下行军按钮开启自动出兵，长按可切换出兵策略", 4.0)
                else
                    gameSettings.battleCount = (gameSettings.battleCount or 0) + 1
                    SaveSettings()
                end
                print("=== 开战! ===")
            end
        end
        return
    end

    -- 刷新按钮 (SHOP和FIGHT阶段都可用, 设计坐标)
    if shopRefreshBtnRect then
        local r = shopRefreshBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            if gameState.gold >= GameConfig.REFRESH_COST then
                gameState.gold = gameState.gold - GameConfig.REFRESH_COST
                RefreshShop()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "-" .. GameConfig.REFRESH_COST .. " 刷新", 1.0, { 180, 200, 255 }, 12)
            else
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.6, "军资不足!", 1.2, { 255, 100, 100 }, 14)
            end
            return
        end
    end
    -- 倍速按钮点击
    if battleSpeedBtnRect then
        local r = battleSpeedBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            -- 循环切换: 1 → 2 → 3 → 1
            local spd = gameState.battleSpeed or 1
            if spd == 1 then
                gameState.battleSpeed = 2
            elseif spd == 2 then
                gameState.battleSpeed = 3
            else
                gameState.battleSpeed = 1
            end
            local spdLabel = "×" .. tostring(gameState.battleSpeed)
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "倍速 " .. spdLabel, 1.0, { 255, 220, 80 }, 16)
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- 自动战斗按钮点击
    if autoBattleBtnRect then
        local r = autoBattleBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            if gameState.noFullAuto then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "副本模式禁用全自动", 1.5, { 255, 140, 100 }, 16)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            gameState.autoBattle = not gameState.autoBattle
            autoBattleTimer = 0
            local txt = gameState.autoBattle and "自动战斗 开启" or "自动战斗 关闭"
            local clr = gameState.autoBattle and { 120, 255, 160 } or { 200, 180, 160 }
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, txt, 1.2, clr, 16)
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- 规则按钮点击 (FIGHT阶段)
    if battleRuleBtnRect then
        local r = battleRuleBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            battleRulesState.show = true
            battleRulesState.scrollY = 0
            battleRulesState.vel = 0
            battleRulesState.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- 策略选项条点击 (show=true时优先检测)
    if strategyWheelState.show and autoMarchBtnRect then
        local ab = autoMarchBtnRect
        local cardW, cardH, gap2 = 115, 64, 8
        local sX = ab.cx - ab.r - 12
        local cCY = ab.cy - ab.r - cardH / 2 - 16
        local hitCard = 0
        for i = 1, #MARCH_STRATEGIES do
            local cRight = sX - (i - 1) * (cardW + gap2)
            local cLeft = cRight - cardW
            local cTop = cCY - cardH / 2
            local cBot = cCY + cardH / 2
            if dx >= cLeft and dx <= cRight and dy >= cTop and dy <= cBot then
                hitCard = i
                break
            end
        end
        if hitCard > 0 then
            local st = MARCH_STRATEGIES[hitCard]
            gameState.autoMarchStrategy = st.id
            gameState.autoMarch = true
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "策略: " .. st.name, 1.2, st.color, 16)
            PlaySFX(AUDIO.sfx_march)
        end
        strategyWheelState.show = false
        strategyWheelState.selected = 0
        return
    end
    -- 自动行军按钮 (FIGHT阶段, 圆形碰撞检测, 支持长按弹出策略选项)
    if autoMarchBtnRect and autoMarchBtnRect.isCircle then
        local ab = autoMarchBtnRect
        local ddx, ddy = dx - ab.cx, dy - ab.cy
        if ddx * ddx + ddy * ddy <= ab.r * ab.r then
            -- 记录按下，等release时判断是短按toggle还是长按选策略
            strategyWheelState.pressing = true
            strategyWheelState.startTime = gameState.gameTime
            strategyWheelState.touchId = touchId
            strategyWheelState.sx = sx
            strategyWheelState.sy = sy
            strategyWheelState.selected = 0
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end

    -- 武技技能按钮 (FIGHT阶段, 圆形碰撞检测, 最多2个)
    -- 武技技能: 按下即开始拖拽瞄准（已移除长按弹窗）
    if gameState.battlePhase == "FIGHT" then
        for slot, sb in pairs(skillBtnRects) do
            if sb and sb.isCircle then
                local sdx, sdy = dx - sb.cx, dy - sb.cy
                if sdx * sdx + sdy * sdy <= sb.r * sb.r then
                    local techIdx = sb.techIdx
                    local skill = SKILL_DEFS[techIdx]
                    if skill then
                        if not skill.unlocked then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "武技未解锁", 0.8, { 200, 160, 100 }, 12)
                        elseif skill.cooldown > 0 then
                            local cdLeft = math.ceil(skill.cooldown)
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "冷却中 " .. cdLeft .. "s", 0.8, { 200, 160, 100 }, 12)
                        else
                            -- 直接开始拖拽瞄准
                            skillTargeting.active = true
                            skillTargeting.skillIdx = techIdx
                            skillTargeting.touchId = touchId
                            skillTargeting.sx = sx
                            skillTargeting.sy = sy
                            skillTargeting.dx = math.max(BATTLE_ZONE.left, math.min(BATTLE_ZONE.right, dx))
                            skillTargeting.dy = math.max(BATTLE_ZONE.top, math.min(BATTLE_ZONE.bottom, dy))
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, skill.name .. " - 拖拽瞄准", 0.8, skill.color, 12)
                        end
                    end
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
        end
    end

    -- 商店卡牌 >> 拖拽放置 (SHOP和FIGHT阶段均可)
    if gameState.battlePhase == "SHOP" or gameState.battlePhase == "FIGHT" then
        local shopIdx, shopItem = HitShopCard(lx, ly)
        if shopIdx > 0 and shopItem then
            -- 检查军资够不够
            if gameState.gold < shopItem.cost then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.6, "军资不足!", 1.2, { 255, 100, 100 }, 14)
                return
            end
            -- 扣除军资, 标记已售, 开始拖拽
            gameState.gold = gameState.gold - shopItem.cost
            shopItem.sold = true
            local cardData = DeepCopy(HERO_CARDS[shopItem.cardIdx])
            cardData.cardIdx = shopItem.cardIdx
            cardData.constellation = shopItem.constellation or 0
            cardData.level = 1
            dragState.active = true
            dragState.card = cardData
            dragState.fromShop = true
            dragState.shopIdx = shopIdx
            dragState.fromInventory = false
            dragState.fromSlot = false
            dragState.lx = lx
            dragState.ly = ly
            dragState.touchId = touchId
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "-" .. shopItem.cost .. " 军资 - 拖至石台放置", 1.2, { 255, 180, 80 }, 12)
            return
        end
    end

    longPressState.pressing = true
    longPressState.active = false
    longPressState.startTime = gameState.gameTime

    -- 石台卡牌 (点击查看详情, 拖拽换位)
    local slotCard, slotIdx, isEnemy = HitSlotCard(dx, dy)
    if slotCard then
        longPressState.card = slotCard
        longPressState.isSlot = true
        longPressState.slotIdx = slotIdx
        longPressState.isEnemy = isEnemy
        dragState.touchId = touchId
        return
    end

    -- 背包卡牌 (拖拽上阵, SHOP和FIGHT阶段均可)
    if gameState.battlePhase == "SHOP" or gameState.battlePhase == "FIGHT" then
        local invCard, invIdx = HitInventoryCard(lx, ly)
        if invCard then
            local fullCard = DeepCopy(HERO_CARDS[invCard.cardIdx])
            fullCard.constellation = invCard.constellation
            fullCard.cardIdx = invCard.cardIdx
            fullCard.level = 1
            longPressState.card = fullCard
            longPressState.isSlot = false
            longPressState.slotIdx = invIdx
            longPressState.isEnemy = false
            dragState.touchId = touchId
            return
        end
    end

    longPressState.pressing = false
    longPressState.card = nil
end


