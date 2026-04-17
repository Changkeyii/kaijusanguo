-- ui/input_begin_press.lua - 涓夊浗姝︾伒褰?(浠?input.lua 鎷嗗垎)
---@diagnostic disable: undefined-global
function BeginPress(sx, sy, touchId)
    local curFrame = time:GetFrameNumber()
    if curFrame == _lastPressFrame then return end
    _lastPressFrame = curFrame

    -- === LOADING 闃舵鐐瑰嚮鎻愮ず ===
    if gameState.phase == "LOADING" then
        loadingClickTipTimer = 2.5
        return
    end

    -- === 涓汉璧勬枡鐣岄潰杈撳叆 ===
    if gameState.phase == "PROFILE" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 澶村儚閫夋嫨
        for i, rect in ipairs(profileAvatarRects) do
            if HitRect(rect) then
                profileState.selectedAvatar = i
                return
            end
        end
        -- 鍚嶅瓧閫夋嫨 (鍚嚜瀹氫箟閫夐」)
        for i, rect in ipairs(profileNameRects) do
            if HitRect(rect) then
                profileState.selectedName = i
                if i == CUSTOM_NAME_IDX then
                    -- 鐐瑰嚮鑷畾涔? 鍚姩鏂囨湰杈撳叆
                    profileState.isInputActive = true
                    input:SetScreenKeyboardVisible(true)
                else
                    profileState.isInputActive = false
                    input:SetScreenKeyboardVisible(false)
                end
                return
            end
        end
        -- 纭鎸夐挳
        if HitRect(profileConfirmBtnRect) then
            -- (鏁欑▼璧勬簮妫€鏌ュ凡绉婚櫎锛屾棤闇€绛夊緟涓嬭浇)
            playerInfo.avatarIdx = AVATAR_OPTIONS[profileState.selectedAvatar] or 1
            if profileState.selectedName == CUSTOM_NAME_IDX and #profileState.customName > 0 then
                playerInfo.name = profileState.customName
            else
                playerInfo.name = PRESET_NAMES[profileState.selectedName] or "鏃犲悕姝︾伒"
            end
            playerInfo.profileSet = true
            profileState.isInputActive = false
            input:SetScreenKeyboardVisible(false)
            -- 绔嬪嵆淇濆瓨锛岀‘淇?profileSet 鐘舵€佹寔涔呭寲
            SaveGameProgress()
            -- 妯″潡涓嬭浇宸插湪闃诲鍔犺浇瀹屾垚鍚庤嚜鍔ㄥ惎鍔紙InitModuleDownloads锛?
            if profileState.editMode then
                -- 缂栬緫妯″紡锛氱洿鎺ヨ繑鍥烇紝涓嶈Е鍙戞柊鎵嬪紩瀵?
                profileState.editMode = false
                PopPhase()
                print("=== 璧勬枡缂栬緫瀹屾垚: " .. playerInfo.name .. " ===")
            else
                gameState.phase = "MENU"
                print("=== 璧勬枡璁剧疆瀹屾垚: " .. playerInfo.name .. " ===")
            end
        end
        return
    end

    -- ======== 缁熶竴瑙勫垯寮圭獥浜や簰 (鍏ㄥ眬鏈€楂樹紭鍏堢骇) ========
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

    -- ======== 缁熶竴 "?" 鎸夐挳鐐瑰嚮妫€娴?(鍏ㄥ眬) ========
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

    -- 棣栭〉鎸夐挳鐐瑰嚮妫€娴?
    if gameState.phase == "MENU" then
        -- 闃茬┛閫忥細鍒氫粠鍏朵粬鐣岄潰杩斿洖鏃跺拷鐣ョ偣鍑?
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        -- 杈呭姪: 妫€娴嬬偣鏄惁鍦ㄧ煩褰㈠唴
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- ======== 鎸夐挳浣嶇疆璋冩暣妯″紡浜や簰 (鏈€楂樹紭鍏堢骇锛屽繀椤诲湪鎵€鏈夊叾浠栨娴嬩箣鍓? ========
        if settingsPage.btnAdjustMode then
            -- 缁勫垏鎹㈡爣绛剧偣鍑?
            if settingsPage.adjGroupBtnRects then
                for _, gr in ipairs(settingsPage.adjGroupBtnRects) do
                    if HitRect(gr) then
                        settingsPage.adjActiveGroup = gr.key
                        PlaySFX(AUDIO.sfx_click)
                        return
                    end
                end
            end
            -- 淇濆瓨鎸夐挳 (淇濆瓨鎵€鏈夌粍)
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
            -- 閲嶇疆鎸夐挳 (閲嶇疆褰撳墠閫変腑缁?
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
            -- 杩斿洖鎸夐挳
            if HitRect(settingsPage.adjBackBtnRect) then
                settingsPage.btnAdjustMode = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 缂╂斁婊戞潯鎷栨嫿寮€濮?(浠呮妧鑳界粍)
            if settingsPage.adjScaleSliderRect and HitRect(settingsPage.adjScaleSliderRect) then
                settingsPage.adjDraggingScale = true
                local r = settingsPage.adjScaleSliderRect
                local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
                settingsPage.adjScale = 0.5 + ratio * 1.5  -- 0.5~2.0
                return
            end
            -- 鎷栨嫿褰撳墠閫変腑缁勶紙鐐瑰嚮鎴樻枟鍖哄煙鍐呬换鎰忎綅缃紑濮嬫嫋鎷斤級
            settingsPage.adjDragging = true
            settingsPage.adjDragStartX = dx
            settingsPage.adjDragStartY = dy
            return
        end

        -- 鐜╁闈㈡澘鐐瑰嚮 >> 杩涘叆鐜╁璇︽儏
        if HitRect(playerDetailBtnRect) then
            playerDetailScroll.y = 0; playerDetailScroll.vel = 0
            PushPhase("PLAYER_DETAIL")
            print("=== 杩涘叆鐜╁璇︽儏 ===")
            return
        end
        -- 骞垮憡鑾峰彇铏庣
        if HitRect(adRects.jade) then
            WatchAdForJade()
            return
        end

        -- ======== CDK 寮圭獥浜や簰 (鏈€楂樹紭鍏堢骇) ========
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
            -- 绮樿创鎸夐挳
            if cdkState.pasteBtnRect and HitRect(cdkState.pasteBtnRect) then
                local clipText = SafeGetClipboard()
                print("=== CDK绮樿创: clipText=[" .. tostring(clipText) .. "] ===")
                if clipText and #clipText > 0 then
                    local cleaned = clipText:upper():gsub("[^A-Z0-9%-]", "")
                    if #cleaned > 20 then cleaned = cleaned:sub(1, 20) end
                    cdkState.inputText = cleaned
                    print("=== 绮樿创鍏戞崲鐮? " .. cleaned .. " ===")
                else
                    input:SetScreenKeyboardVisible(true)
                    cdkState.resultText = "璇峰湪閿洏涓暱鎸夎緭鍏ユ绮樿创"
                    cdkState.resultTimer = 3.0
                    cdkState.resultOk = false
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鐐瑰嚮寮圭獥鍖哄煙鍐呮秷璐逛簨浠?鍘熺敓閿洏澶勭悊杈撳叆)
            return
        end

        -- ======== 鎴樺姏璇存槑寮圭獥浜や簰 ========
        if powerExplainPopup.show then
            local cr = powerExplainPopup.closeBtnRect
            if cr and HitRect(cr) then
                powerExplainPopup.show = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鐐瑰嚮寮圭獥澶栧叧闂?
            local pr = powerExplainPopup.panelRect
            if not (pr and HitRect(pr)) then
                powerExplainPopup.show = false
            end
            return
        end

        -- ======== 璁剧疆鐣岄潰浜や簰 (浼樺厛鎷︽埅) ========
        if settingsPage.isOpen then
            -- 淇濆瓨鎸夐挳
            if HitRect(settingsPage.saveBtnRect) then
                SaveSettings()
                settingsPage.isOpen = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鍏抽棴鎸夐挳
            if HitRect(settingsPage.closeBtnRect) then
                settingsPage.isOpen = false
                settingsPage.draggingMusic = false
                settingsPage.draggingSfx = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鑷姩琛屽啗寮€鍏?
            if HitRect(settingsPage.autoMarchToggleRect) then
                gameSettings.defaultAutoMarch = not gameSettings.defaultAutoMarch
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 瀛椾綋鍒囨崲: 4绉嶅瓧浣?
            for _, fkey in ipairs({"misans", "kuaile", "wenkai", "xingshu"}) do
                local rect = settingsPage["font_" .. fkey .. "_rect"]
                if rect and HitRect(rect) then
                    gameSettings.fontStyle = fkey
                    SaveGameProgress()
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 榛樿鎴樺満鍒囨崲
            if settingsPage.battlefieldBtnRect and HitRect(settingsPage.battlefieldBtnRect) then
                local cur = gameSettings.defaultBattlefield or 1
                gameSettings.defaultBattlefield = (cur % 8) + 1
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 璋冩暣浣嶇疆鎸夐挳 >> 杩涘叆鎴樻枟鍦烘櫙璋冩暣妯″紡
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

            -- UID 澶嶅埗鎸夐挳
            if settingsPage.uidCopyBtnRect and HitRect(settingsPage.uidCopyBtnRect) then
                local uidStr = settingsPage.uidValue or ""
                if uidStr ~= "" and uidStr ~= "---" then
                    local sysOk = SafeSetClipboard(uidStr)
                    settingsPage.uidCopyTimer = 2.5
                    if sysOk then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "UID宸插鍒? " .. uidStr, 1.5, { 100, 220, 160 }, 16)
                    else
                        -- 绯荤粺鍓创鏉夸笉鍙敤锛屽凡瀛樺叆娓告垙鍐呭壀璐存澘锛屽悓鏃舵彁绀烘埅鍥?
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.30, "UID宸插鍒?娓告垙鍐?", 2.5, { 100, 220, 160 }, 16)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.36, uidStr, 3.0, { 255, 220, 80 }, 22)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.42, "鍙戦偖浠跺彲鐩存帴绮樿创 / 鎴浘淇濆瓨", 2.5, { 180, 180, 180 }, 14)
                    end
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end

            -- 鍏嶅箍鍛婂崱 - 鐪嬪箍鍛婃寜閽?
            if settingsPage.adCardBtnRect and HitRect(settingsPage.adCardBtnRect) then
                PlaySFX(AUDIO.sfx_click)
                if not IsMobilePlatform() then
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "浠呯Щ鍔ㄧ鍙鐪嬪箍鍛?, 1.5, { 200, 150, 100 }, 14)
                    return
                end
                -- 鐪嬪箍鍛婂苟璁″叆鍏嶅箍鍛婂崱
                local function onAdCardSuccess()
                    local today = os.date("%Y-%m-%d")
                    if gameSettings.dailyAdDate ~= today then
                        gameSettings.dailyAdCount = 0
                        gameSettings.dailyAdDate = today
                    end
                    gameSettings.dailyAdCount = gameSettings.dailyAdCount + 1
                    print("[鍏嶅箍鍛婂崱] 鐪嬪箍鍛婅鍏? " .. gameSettings.dailyAdCount .. "/3")
                    if gameSettings.dailyAdCount >= 3 then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "浠婃棩鍏嶅箍鍛婂崱宸叉縺娲?", 2.0, { 100, 255, 200 }, 18)
                    else
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                            "骞垮憡瑙傜湅鎴愬姛 (" .. gameSettings.dailyAdCount .. "/3)", 1.5, { 200, 200, 100 }, 14)
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

            -- CDK 鍏戞崲鎸夐挳
            if HitRect(settingsPage.cdkBtnRect) then
                cdkState.inputOpen = true
                cdkState.inputText = ""
                cdkState.resultTimer = 0
                input:SetScreenKeyboardVisible(true)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 闊充箰婊戞潯鎷栨嫿寮€濮?
            if HitRect(settingsPage.musicSliderRect) then
                settingsPage.draggingMusic = true
                local r = settingsPage.musicSliderRect
                local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
                gameSettings.musicVolume = ratio
                if audioState.bgmSource then audioState.bgmSource.gain = ratio end
                return
            end
            -- 闊虫晥婊戞潯鎷栨嫿寮€濮?
            if HitRect(settingsPage.sfxSliderRect) then
                settingsPage.draggingSfx = true
                local r = settingsPage.sfxSliderRect
                local ratio = math.max(0, math.min(1, (dx - r.x) / r.w))
                gameSettings.sfxVolume = ratio
                return
            end
            -- 鐐瑰嚮閬僵鍖哄煙 >> 娑堣垂浜嬩欢涓嶇┛閫?
            return
        end

        if HitRect(settingsPage.btnRect) then
            settingsPage.isOpen = true
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 鍙充晶鍗疯酱闈㈡澘鎸夐挳
        if menuBtnRects.rpBattle and HitRect(menuBtnRects.rpBattle) then
            -- 涔变笘寰侀€?(澶嶇敤 battle 閫昏緫)
            if not moduleState.battle.ready then
                local pct = math.floor(moduleState.battle.progress * 100)
                ShowToast("鎴樻枟璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PlaySFX(AUDIO.sfx_click)
            WorldMap.Init()
            PushPhase("WORLD_MAP")
            print("=== 鍙充晶闈㈡澘: 杩涘叆涔变笘寰侀€?===")
            return
        end
        if menuBtnRects.rpCodex and HitRect(menuBtnRects.rpCodex) then
            -- 瑙掕壊鍏绘垚 (姝︾伒褰?
            if not moduleState.heroes.ready then
                local pct = math.floor(moduleState.heroes.progress * 100)
                ShowToast("姝︾伒璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("CODEX")
            codexScroll.y = 0
            codexScroll.vel = 0
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 鍙充晶闈㈡澘: 杩涘叆瑙掕壊鍏绘垚(姝︾伒褰? ===")
            return
        end
        if menuBtnRects.rpSettings and HitRect(menuBtnRects.rpSettings) then
            -- 璁剧疆
            settingsPage.isOpen = true
            PlaySFX(AUDIO.sfx_click)
            return
        end
        if menuBtnRects.rpExit and HitRect(menuBtnRects.rpExit) then
            -- 閫€鍑烘父鎴?
            PlaySFX(AUDIO.sfx_click)
            engine:Exit()
            return
        end
        -- 鎴樺姏璇存槑"?"鎸夐挳 (鍦ㄧ帺瀹堕潰鏉跨偣鍑讳箣鍓嶆嫤鎴?
        if menuBtnRects.powerHelp and HitRect(menuBtnRects.powerHelp) then
            powerExplainPopup.show = true
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 涓嬭浇闈㈡澘浜や簰
        if downloadUI.panelOpen and downloadUI.panelRect and HitRect(downloadUI.panelRect) then
            -- 鐐瑰嚮闈㈡澘鍐呴儴 >> 娑堣垂浜嬩欢涓嶇┛閫?
            return
        end
        if downloadUI.btnRect and HitRect(downloadUI.btnRect) then
            downloadUI.panelOpen = not downloadUI.panelOpen
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 鐐瑰嚮鍏朵粬鍖哄煙鏃舵敹璧烽潰鏉?
        if downloadUI.panelOpen then
            downloadUI.panelOpen = false
        end

        -- ======== 宸︿晶鏍忔嫋鎷?鐐瑰嚮澶勭悊 ========
        if leftSidebarScroll.areaRect then
            local ar = leftSidebarScroll.areaRect
            if dx >= ar.x and dx <= ar.x + ar.w and dy >= ar.y and dy <= ar.y + ar.h then
                local maxScroll = math.max(0, leftSidebarScroll.contentH - leftSidebarScroll.viewH)
                if maxScroll > 0 then
                    -- 鏈夋粴鍔ㄩ渶姹?鈫?璁板綍鎷栨嫿璧风偣锛孍ndPress 鍒ゆ柇鏄偣鍑昏繕鏄嫋鎷?
                    leftSidebarScroll.isDragging = true
                    leftSidebarScroll.dragStartY = dy
                    leftSidebarScroll.dragLastY = dy
                    leftSidebarScroll.vel = 0
                    return  -- 闃绘绌块€忓埌涓嬫柟鎸夐挳鐐瑰嚮
                else
                    -- 鏃犳粴鍔?鈫?鐩存帴澶勭悊鎸夐挳鐐瑰嚮
                    HandleSidebarButtonClick(dx, dy)
                    return
                end
            end
        end

        -- ======== 涓栫晫鑱婂ぉ鐐瑰嚮澶勭悊 ========
        if worldChatUI.expanded then
            -- 灞曞紑妯″紡: 浼樺厛鎷︽埅鎵€鏈夌偣鍑?
            if menuBtnRects.worldChatClose and HitRect(menuBtnRects.worldChatClose) then
                worldChatUI.expanded = false
                worldChatUI.inputActive = false
                worldChatUI.chatInput = ""
                input:SetScreenKeyboardVisible(false)
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 娣诲姞濂藉弸寮瑰嚭鎸夐挳
            if menuBtnRects.worldChatAddFriend and HitRect(menuBtnRects.worldChatAddFriend) then
                local targetUid = menuBtnRects.worldChatAddFriend.uid
                local targetName = menuBtnRects.worldChatAddFriend.name or "?"
                local myUid = CloudAPI.GetUserId()
                if targetUid == myUid then
                    ShowToast("涓嶈兘娣诲姞鑷繁涓哄ソ鍙?)
                else
                    CloudManager.SendFriendRequest(targetUid, "")
                    playerInfo.totalFriendReqs = (playerInfo.totalFriendReqs or 0) + 1
                    ShowToast("宸插悜銆? .. targetName .. "銆嶅彂閫佸ソ鍙嬭姹?)
                end
                worldChatUI.namePopup = nil
                PlaySFX(AUDIO.sfx_click); return
            end
            if menuBtnRects.worldChatSend and HitRect(menuBtnRects.worldChatSend) then
                if worldChatUI.chatInput and #worldChatUI.chatInput > 0 then
                    local filteredText = FilterBannedWords(worldChatUI.chatInput)
                    local senderName = CloudManager._myTapNickname or factionUI.myNickname or playerInfo.name or "鏃犲悕"
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
            -- 鐐瑰嚮寮圭獥鍖哄煙鍐呬笉鍏抽棴
            if menuBtnRects.worldChatPopupArea and HitRect(menuBtnRects.worldChatPopupArea) then
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 鐐瑰嚮澶村儚寮瑰嚭鐜╁淇℃伅
            if worldChatUI._avatarRects then
                for _, nr in ipairs(worldChatUI._avatarRects) do
                    if HitRect(nr) then
                        if worldChatUI.namePopup and worldChatUI.namePopup.uid == nr.uid then
                            worldChatUI.namePopup = nil  -- 鍐嶆鐐瑰嚮鍚屼竴澶村儚鍏抽棴
                        else
                            worldChatUI.namePopup = { uid = nr.uid, name = nr.name, x = nr.x, y = nr.y, av = nr.av }
                        end
                        PlaySFX(AUDIO.sfx_click); return
                    end
                end
            end
            -- 鐐瑰嚮绐楀彛澶栭儴鍏抽棴
            worldChatUI.expanded = false
            worldChatUI.inputActive = false
            worldChatUI.chatInput = ""
            worldChatUI.namePopup = nil
            input:SetScreenKeyboardVisible(false)
            PlaySFX(AUDIO.sfx_click); return
        end
        if menuBtnRects.worldChatMini and HitRect(menuBtnRects.worldChatMini) then
            worldChatUI.expanded = true
            worldChatUI.lastMsgCount = 0  -- 瑙﹀彂鑷姩婊氬埌搴?
            CloudManager.PollWorldChat()  -- 绔嬪嵆鎷夊彇
            PlaySFX(AUDIO.sfx_click); return
        end

        if HitRect(menuBtnRects.battle) then
            -- 涔变笘寰侀€?>> 澶у湴鍥撅紙闇€瑕佹垬鏂楁ā鍧楋級
            if not moduleState.battle.ready then
                local pct = math.floor(moduleState.battle.progress * 100)
                ShowToast("鎴樻枟璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PlaySFX(AUDIO.sfx_click)
            WorldMap.Init()
            PushPhase("WORLD_MAP")
            print("=== 杩涘叆澶у湴鍥?===")
        elseif HitRect(menuBtnRects.gachaSeal) then
            -- 鍏电鍙敜锛堢洿鎺ヨ繘鍏ュ叺绗︾鐞嗭級
            PushPhase("SEAL_MGR")
            PlaySFX(AUDIO.sfx_click)
            print("=== 杩涘叆鍏电鍙敜 ===")
        elseif HitRect(menuBtnRects.gachaSkill) then
            -- 姝︽妧鍙敜锛堣繘鍏ユ鎶€鍥惧綍锛?
            if not moduleState.skills.ready then
                local pct = math.floor(moduleState.skills.progress * 100)
                ShowToast("姝︽妧璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("SKILL_CODEX")
            PlaySFX(AUDIO.sfx_click)
            print("=== 杩涘叆姝︽妧鍙敜 ===")
        elseif HitRect(menuBtnRects.codex) then
            -- 姝︾伒褰曪紙闇€瑕佹鐏垫ā鍧楋級
            if not moduleState.heroes.ready then
                local pct = math.floor(moduleState.heroes.progress * 100)
                ShowToast("姝︾伒璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("CODEX")
            codexScroll.y = 0
            codexScroll.vel = 0
            phaseChangeCooldown = 0.3
            print("=== 杩涘叆姝︾伒褰?===")
        elseif HitRect(menuBtnRects.equip) then
            -- 鍏电敳锛堥渶瑕佸叺鐢叉ā鍧楋級
            if not moduleState.equipment.ready then
                local pct = math.floor(moduleState.equipment.progress * 100)
                ShowToast("鍏电敳璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("EQUIP")
            -- 鑷姩閫変腑鏈夌孩鐐圭殑妲戒綅锛堝府鍔╃帺瀹舵壘鍒版柊瑁呭锛?
            local autoSlot = 1
            for si = 1, 7 do
                if HasEquipSlotRedDot(si) then autoSlot = si; break end
            end
            equipScreenState.selectedSlot = autoSlot
            equipScreenState.scrollY = 0
            -- 浼犻€?NanoVG 涓婁笅鏂囧拰绮剧伒鍥惧彞鏌勭粰瑕嗙洊灞?
            EquipUI._vg = vg
            EquipUI._equipSheet = IMG.equipmentSheet
            EquipUI._sheetCols = EQUIP_SHEET_COLS
            EquipUI._sheetRows = EQUIP_SHEET_ROWS
            -- 鏄剧ずNanoVG缃戞牸浠撳簱
            EquipUI.Show()
            -- 涓嶅啀绔嬪嵆娑堥櫎鎵€鏈夌孩鐐癸紝鏀逛负鐐瑰嚮妲戒綅鏃堕€愪釜娑堥櫎
            print("=== 杩涘叆鍏电敳 ===")
        elseif HitRect(menuBtnRects.equipCodex) then
            -- 鍏电敳鍥惧綍锛堥渶瑕佸叺鐢叉ā鍧楋級
            if not moduleState.equipment.ready then
                local pct = math.floor(moduleState.equipment.progress * 100)
                ShowToast("鍏电敳璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("EQUIP_CODEX")
            print("=== 杩涘叆鍏电敳鍥惧綍 ===")
        elseif HitRect(menuBtnRects.skillCodex) then
            -- 姝︽妧锛堥渶瑕佹鎶€妯″潡锛?
            if not moduleState.skills.ready then
                local pct = math.floor(moduleState.skills.progress * 100)
                ShowToast("姝︽妧璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            PushPhase("SKILL_CODEX")
            skillCodexState.scrollY = 0
            skillCodexState.scrollVel = 0
            phaseChangeCooldown = 0.3
            DismissSkillRedDots()
            print("=== 杩涘叆姝︽妧 ===")
        elseif HitRect(menuBtnRects.welfare) then
            -- 澶╁懡璧愮
            PushPhase("WELFARE")
            phaseChangeCooldown = 0.3
            welfareState.contribLoaded = false  -- 姣忔杩涘叆鍒锋柊璐＄尞姒?
            welfareState.contribLoading = false -- 閲嶇疆鍔犺浇閿侊紝闃叉鍗′綇
            welfareState.powerLoaded = false    -- 姣忔杩涘叆鍒锋柊鎴樺姏姒?
            welfareState.powerLoading = false   -- 閲嶇疆鍔犺浇閿?
            welfareState.contribScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            welfareState.powerScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            welfareState.scroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            LoadContribRank()
            ReportPowerScore()
            LoadPowerRank()
            print("=== 杩涘叆澶╁懡璧愮 ===")
        elseif menuBtnRects.trade and HitRect(menuBtnRects.trade) then
            -- 浜ゆ槗琛?
            PushPhase("TRADE")
            phaseChangeCooldown = 0.3
            tradeState.tab = "market"
            tradeState.scroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil }
            tradeState.selectedItem = nil
            tradeState.confirmPopup = nil
            tradeState.btnRects = {}
            TradeManager.Init()
            TradeManager.ResetCheckSalesCD()  -- 杩涘叆浜ゆ槗琛屾椂绔嬪嵆妫€鏌ユ敹娆?
            TradeManager.RefreshMarket()
            PlaySFX(AUDIO.sfx_click)
            print("=== 杩涘叆浜ゆ槗琛?===")
        elseif menuBtnRects.mailBox and HitRect(menuBtnRects.mailBox) then
            -- 閭欢绯荤粺
            PushPhase("MAIL_BOX")
            phaseChangeCooldown = 0.3
            welfareState.mail.scroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
            welfareState.mail.btnRects = {}
            welfareState.mail.cloudBtnRects = {}
            welfareState.mail.confirmPopup = nil
            welfareState.mail.composing = false
            welfareState.mail.composeData = nil
            welfareState.mail.adminPanel = false
            -- 棣栨杩涘叆鏃惰疆璇簯閭欢
            CloudManager.PollInbox()
            PlaySFX(AUDIO.sfx_click)
            print("=== 杩涘叆閭欢 ===")
        elseif menuBtnRects.faction and HitRect(menuBtnRects.faction) then
            -- 闃佃惀绯荤粺
            PushPhase("FACTION")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 杩涘叆闃佃惀 ===")
        elseif menuBtnRects.friends and HitRect(menuBtnRects.friends) then
            -- 濂藉弸绯荤粺
            PushPhase("FRIENDS")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 杩涘叆濂藉弸 ===")
        elseif menuBtnRects.powerRank and HitRect(menuBtnRects.powerRank) then
            -- 鎴樺姏鎺掕姒滅嫭绔嬬晫闈?
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
            print("=== 杩涘叆鎴樺姏鎺掕姒?===")
        elseif menuBtnRects.progress and HitRect(menuBtnRects.progress) then
            -- 姣忔棩浠诲姟 / 鍛ㄤ换鍔?/ 鎴愬氨
            CheckDailyReset()
            CheckWeeklyReset()
            progressUIState.tab = 1
            progressUIState.scrollY = 0
            PushPhase("PROGRESS")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 杩涘叆姣忔棩浠诲姟 ===")
        elseif menuBtnRects.battlepass and HitRect(menuBtnRects.battlepass) then
            -- 鎴樹护閫氳璇?
            CheckBattlePassSeason()
            CheckBattlePassDailyReset()
            CheckBattlePassWeeklyReset()
            battlePassUIState.tab = 1
            battlePassUIState.scrollY = 0
            battlePassUIState.rewardScrollX = 0
            PushPhase("BATTLE_PASS")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 杩涘叆鎴樹护閫氳璇?===")
        --[=[ 宸茬Щ闄? 璁ㄤ紣/鍓湰/鎺㈢储 鍏ュ彛
        elseif abyssState.btnRect and HitRect(abyssState.btnRect) then
            PushPhase("ABYSS_SELECT")
        elseif dailyDungeonState.btnRect and HitRect(dailyDungeonState.btnRect) then
            PushPhase("DAILY_DUNGEON")
        elseif resourceDungeonState.btnRect and HitRect(resourceDungeonState.btnRect) then
            PushPhase("RESOURCE_DUNGEON")
        --]=]
        elseif dummyState.btnRect and HitRect(dummyState.btnRect) then
            -- 30s鎵撴々妯″紡锛堥渶瑕佹垬鏂楁ā鍧楋級
            if not moduleState.battle.ready then
                local pct = math.floor(moduleState.battle.progress * 100)
                ShowToast("鎴樻枟璧勬簮涓嬭浇涓?" .. pct .. "%)锛岃绋嶅€?)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 妫€鏌ユ槸鍚︽湁瓒冲鐨勬鐏?
            local ownedCount = 0
            for _, h in pairs(playerHeroes) do
                if h.owned then ownedCount = ownedCount + 1 end
            end
            if ownedCount < 1 then
                ShowToast("鑷冲皯鎷ユ湁1鍚嶆鐏垫墠鑳芥寫鎴?)
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
            print("=== 杩涘叆30s鎵撴々閫夊皢 ===")
        --[=[ 宸茬Щ闄? 鐖/鎺掍綅 鍏ュ彛
        elseif towerState.btnRect and HitRect(towerState.btnRect) then
            PushPhase("TOWER_SELECT")
        elseif rankedState.btnRect and HitRect(rankedState.btnRect) then
            PushPhase("RANKED_SELECT")
        --]=]
        end
        return
    end

    -- === 30s鎵撴々閫夊皢鐣岄潰杈撳叆 ===
    if gameState.phase == "DUMMY_SELECT" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 杩斿洖鎸夐挳
        if HitRect(dummyState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 鎵撴々閫夊皢杩斿洖涓婁竴椤?===")
            return
        end
        -- 寮€濮嬫寫鎴樻寜閽?
        if HitRect(dummyState.startBtnRect) and #dummyState.selected > 0 then
            -- 鍒濆鍖栨墦妗╂垬鏂楋紙杩涘叆鍑嗗闃舵锛岀瓑鐜╁鎵嬪姩寮€濮嬶級
            InitBattle()
            gameState.isDummy = true
            dummyState.totalDamage = 0
            dummyState.timer = 30
            dummyState.prepPhase = true  -- 鍑嗗闃舵鏍囪

            -- 娓呯┖榛樿鏁屾柟閮ㄧ讲锛堢煶鍙颁笂涓嶆斁姝︾伒锛?
            for _, slot in ipairs(ENEMY_SLOTS) do
                slot.filled = false; slot.card = nil
            end

            -- 闅忔満璁ㄤ紣鑳屾櫙
            if not gameState.abyssFloor then
                gameState.abyssFloor = math.random(1, 7)
            end

            -- 灏嗛€夊畾姝︾伒鑷姩鏀惧叆鐜╁鐭冲彴
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

            -- 璁剧疆瓒呴珮鏁屾柟鍩哄湴HP
            gameState.enemyBaseHP = 999999
            gameState.enemyBaseMax = 999999

            -- 杩涘叆SHOP闃舵锛堝噯澶囬樁娈碉級锛岃鐜╁璋冩暣甯冮樀
            gameState.battlePhase = "SHOP"
            gameState.phase = "BATTLE"
            phaseChangeCooldown = 0.3
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "鎽嗘斁姝︾伒锛屽噯澶囧紑濮?", 1.5, { 255, 220, 80 }, 18)
            print("=== 30s鎵撴々 鍑嗗闃舵 ===")
            return
        end
        -- 璁板綍鎷栨嫿璧峰浣嶇疆锛堝崱鐗岀偣鍑诲欢杩熷埌TouchEnd鍒ゆ柇锛?
        dummyState.dragStartY = dy
        dummyState.dragLastY = dy
        dummyState.isDragging = true
        dummyState.scrollVel = 0
        return
    end

    -- === 30s鎵撴々缁撴灉鐣岄潰杈撳叆 ===
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
            print("=== 鎵撴々缁撴灉杩斿洖涓婁竴椤?===")
        end
        return
    end

    -- === 姝︽妧鐣岄潰杈撳叆 ===
    if gameState.phase == "SKILL_CODEX" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(skillCodexBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 杩斿洖涓婁竴椤?===")
            return
        end
        -- 璁板綍鎷栨嫿璧峰浣嶇疆锛堢敤浜庢粴鍔紝鐐瑰嚮寤惰繜鍒癊ndPress鍒ゆ柇锛?
        skillCodexState.dragStartY = dy
        skillCodexState.dragLastY = dy
        skillCodexState.isDragging = true
        skillCodexState.scrollVel = 0
        return
    end

    -- === 姝︽妧璇︽儏椤佃緭鍏?===
    if gameState.phase == "SKILL_DETAIL" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(skillDetailBackBtnRect) then
            PopPhase("SKILL_CODEX")
            phaseChangeCooldown = 0.3
            print("=== 杩斿洖涓婁竴椤?===")
        elseif skillDetailEquipBtnRect and HitRect(skillDetailEquipBtnRect) then
            -- 瑁呭/鍗镐笅鎸夐挳 (鍗曟寜閽ā寮?
            local curIdx = skillCodexState.selectedIdx
            if SKILL_DEFS[curIdx] and SKILL_DEFS[curIdx].notAvailable then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "姝ゆ鎶€鏆傛湭寮€鏀?, 1.0, { 160, 150, 130 }, 14)
            elseif skillDetailEquipBtnRect.action == "unequip" then
                local s = skillDetailEquipBtnRect.slot
                table.remove(playerEquippedSkills, s)
                print("=== 鍗镐笅姝︽妧: " .. SKILL_TECHNIQUES[curIdx].name .. " (妲戒綅" .. s .. ") ===")
                SaveGameProgress()
            else
                playerEquippedSkills[#playerEquippedSkills + 1] = curIdx
                print("=== 瑁呭姝︽妧: " .. SKILL_TECHNIQUES[curIdx].name .. " (妲戒綅" .. #playerEquippedSkills .. ") ===")
                SaveGameProgress()
            end
        elseif skillDetailEquipSlotBtns and #skillDetailEquipSlotBtns > 0 then
            -- 涓や釜鏇挎崲鎸夐挳妯″紡 (涓や釜妲戒綅閮芥弧)
            local curIdx = skillCodexState.selectedIdx
            if SKILL_DEFS[curIdx] and SKILL_DEFS[curIdx].notAvailable then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "姝ゆ鎶€鏆傛湭寮€鏀?, 1.0, { 160, 150, 130 }, 14)
            end
            local handled = false
            for s, btn in ipairs(skillDetailEquipSlotBtns) do
                if HitRect(btn) then
                    local old = playerEquippedSkills[btn.slot]
                    playerEquippedSkills[btn.slot] = curIdx
                    print("=== 瑁呭姝︽妧: " .. SKILL_TECHNIQUES[curIdx].name .. " >> 妲戒綅" .. btn.slot .. " (鏇挎崲" .. SKILL_TECHNIQUES[old].name .. ") ===")
                    SaveGameProgress()
                    handled = true
                    break
                end
            end
            if not handled then
                -- 娌＄偣涓浛鎹㈡寜閽紝妫€鏌ュ簳閮ㄥ悓闃堕瑙堟潯
                for _, mr in ipairs(skillDetailMiniRects) do
                    if HitRect(mr) and mr.idx ~= skillCodexState.selectedIdx then
                        skillCodexState.selectedIdx = mr.idx
                        print("=== 鍒囨崲姝︽妧: " .. SKILL_TECHNIQUES[mr.idx].name .. " ===")
                        break
                    end
                end
            end
        else
            -- 搴曢儴鍚岄樁棰勮鏉＄偣鍑诲垏鎹?
            for _, mr in ipairs(skillDetailMiniRects) do
                if HitRect(mr) and mr.idx ~= skillCodexState.selectedIdx then
                    skillCodexState.selectedIdx = mr.idx
                    print("=== 鍒囨崲姝︽妧: " .. SKILL_TECHNIQUES[mr.idx].name .. " ===")
                    break
                end
            end
        end
        return
    end

    -- === 澶╁懡璧愮杈撳叆 ===
    if gameState.phase == "WELFARE" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(welfareState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 杩斿洖涓婁竴椤?===")
            return
        end
        -- 涓夋棩绛惧埌鎸夐挳 (绗?澶?姝︽妧18, 绗?澶?姝︽妧19, 绗?澶?20000铏庣)
        local SIGN_SKILL_REWARDS = { 18, 19, nil }  -- 鍓嶄袱澶╅€佹鎶€(49娈嬬墖鐩存帴鍙厬鎹?
        local SIGN_JADE_REWARD = 20000  -- 绗?澶╅€佽檸绗?
        for i = 1, 3 do
            if HitRect(welfareState.signInBtnRects[i]) then
                -- 宸查鍙栧垯璺宠繃
                if welfareState.signInClaimed[i] then break end
                -- 鍓嶄竴澶╁繀椤诲凡棰嗗彇
                if i > 1 and not welfareState.signInClaimed[i - 1] then break end
                -- 24灏忔椂闂撮殧妫€鏌? 鍓嶄竴澶╅鍙栧悗闇€绛夊緟24灏忔椂
                if i > 1 then
                    local prevTs = welfareState.signInTimestamps[i - 1] or 0
                    if prevTs > 0 and (os.time() - prevTs) < 86400 then
                        local remain = 86400 - (os.time() - prevTs)
                        local hrs = math.floor(remain / 3600)
                        local mins = math.floor((remain % 3600) / 60)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "璺濅笅娆＄鍒拌繕闇€ " .. hrs .. "鏃? .. mins .. "鍒?, 1.5, { 255, 180, 80 }, 18)
                        break
                    end
                end
                local dayIdx = i
                local claimFunc = function()
                    welfareState.signInClaimed[dayIdx] = true
                    welfareState.signInTimestamps[dayIdx] = os.time()
                    if SIGN_SKILL_REWARDS[dayIdx] then
                        -- 閫佹鎶€娈嬬墖 (49涓? 鍙洿鎺ュ厬鎹?
                        local skIdx = SIGN_SKILL_REWARDS[dayIdx]
                        skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                        local sk = SKILL_TECHNIQUES[skIdx]
                        local skName = sk and sk.name or ("姝︽妧#" .. skIdx)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "鑾峰緱 " .. skName .. " 脳" .. SKILL_FRAG_EXCHANGE .. " 娈嬬墖", 1.5, { 200, 160, 255 }, 18)
                        print("=== 绛惧埌绗? .. dayIdx .. "澶? 鑾峰緱姝︽妧" .. skIdx .. " 娈嬬墖脳" .. SKILL_FRAG_EXCHANGE .. " ===")
                    else
                        -- 绗?澶╅€?0000铏庣
                        playerInfo.jade = playerInfo.jade + SIGN_JADE_REWARD
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "鑾峰緱 铏庣 脳" .. SIGN_JADE_REWARD, 1.5, { 255, 220, 100 }, 18)
                        print("=== 绛惧埌绗? .. dayIdx .. "澶? +" .. SIGN_JADE_REWARD .. " 铏庣 ===")
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
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25, "浠呯Щ鍔ㄧ鍙鐪嬪箍鍛?, 1.5, { 200, 150, 100 }, 14)
                        return
                    end
                    claimFunc()
                    ReportAdWatchWelfare()
                end
                return
            end
        end
        -- 鍗佹棩绛惧埌鎸夐挳锛堟瘡鏃ュ箍鍛婇5000铏庣锛?
        for i = 1, 10 do
            if HitRect(welfareState.dailySignInBtnRects[i]) then
                -- 蹇呴』鎸夐『搴忛鍙?
                if i > 1 and not welfareState.dailySignInClaimed[i - 1] then break end
                if welfareState.dailySignInClaimed[i] then break end
                -- 24灏忔椂闂撮殧妫€鏌? 鍓嶄竴澶╅鍙栧悗闇€绛夊緟24灏忔椂
                if i > 1 then
                    local prevTs = welfareState.dailySignInTimestamps[i - 1] or 0
                    if prevTs > 0 and (os.time() - prevTs) < 86400 then
                        local remain = 86400 - (os.time() - prevTs)
                        local rh = math.floor(remain / 3600)
                        local rm = math.floor((remain % 3600) / 60)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            string.format("璺濅笅娆＄鍒拌繕闇€ %d鏃?d鍒?, rh, rm),
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
                        "绗? .. dayIdx .. "鏃ョ鍒?+5000 铏庣", 1.5, { 255, 220, 100 }, 18)
                    print("=== 鍗佹棩绛惧埌绗? .. dayIdx .. "澶? +5000 铏庣 ===")
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
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25, "浠呯Щ鍔ㄧ鍙鐪嬪箍鍛?, 1.5, { 200, 150, 100 }, 14)
                        return
                    end
                    claimFunc()
                    ReportAdWatchWelfare()
                end
                return
            end
        end
        -- 鍦ㄧ嚎鏃堕暱濂栧姳鎸夐挳
        local OL_JADE = { 300, 500, 800, 1000 }
        for i = 1, 4 do
            if HitRect(welfareState.onlineBtnRects[i]) then
                welfareState.onlineRewards[i] = true
                playerInfo.jade = playerInfo.jade + OL_JADE[i]
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4,
                    "鍦ㄧ嚎濂栧姳 +" .. OL_JADE[i] .. " 铏庣", 1.5, { 130, 200, 255 }, 16)
                print("=== 鍦ㄧ嚎鏃堕暱濂栧姳绗? .. i .. "妗? +" .. OL_JADE[i] .. " 铏庣 ===")
                return
            end
        end

        -- (澶ц浆鐩樺拰姣忔棩缈荤墝鐐瑰嚮澶勭悊宸茬Щ闄?

        -- 璐＄尞姒?鏌ョ湅璇︽儏"鎸夐挳 鈫?璺宠浆鍒拌础鐚璇︽儏椤?
        if welfareState.contribDetailBtnRect and HitRect(welfareState.contribDetailBtnRect) then
            welfareState.contribDetailScroll.offset = 0  -- 閲嶇疆婊氬姩
            PushPhase("CONTRIB_RANK")
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 娌℃湁鍛戒腑浠讳綍鎸夐挳锛屽紑濮嬫粴鍔ㄦ嫋鎷?
        -- 鍒ゆ柇鏄湪璐＄尞姒滃尯鍩熻繕鏄笅鏂瑰唴瀹瑰尯鍩?
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

    -- === 姣忔棩浠诲姟 / 鎴愬氨 鐣岄潰杈撳叆 ===
    if gameState.phase == "PROGRESS" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 杩斿洖鎸夐挳
        if HitRect(progressUIState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            return
        end
        -- Tab鍒囨崲
        for i, r in ipairs(progressTabRects) do
            if HitRect(r) then
                progressUIState.tab = i
                progressUIState.scrollY = 0
                return
            end
        end
        -- 姣忔棩浠诲姟棰嗗彇鎸夐挳
        if progressUIState.tab == 1 then
            for i, r in ipairs(dailyTaskBtnRects) do
                if HitRect(r) then
                    if ClaimDailyReward(i) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "浠诲姟濂栧姳宸查鍙?", 1.5, { 100, 255, 100 }, 16)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            -- 鍏ㄥ嫟濂栧姳鎸夐挳
            if HitRect(dailyTaskAllBtnRect) then
                if ClaimDailyAllBonus() then
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 鍛ㄤ换鍔￠鍙栨寜閽?
        if progressUIState.tab == 2 then
            for i, r in ipairs(weeklyTaskBtnRects) do
                if HitRect(r) then
                    if ClaimWeeklyReward(i) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍛ㄤ换鍔″鍔卞凡棰嗗彇!", 1.5, { 100, 230, 255 }, 16)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            -- 鍛ㄥ叏鍕ゅ鍔辨寜閽?
            if HitRect(weeklyTaskAllBtnRect) then
                if ClaimWeeklyAllBonus() then
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 鎴愬氨棰嗗彇鎸夐挳
        if progressUIState.tab == 3 then
            for i, r in ipairs(progressUIState.achBtnRects or {}) do
                if HitRect(r) then
                    local origIdx = (progressUIState.achOrigIdx and progressUIState.achOrigIdx[i]) or i
                    if ClaimAchievement(origIdx) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鎴愬氨濂栧姳宸查鍙?", 1.5, { 255, 220, 80 }, 16)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
        end
        -- 婊氬姩鎷栨嫿
        progressUIState.isDragging = true
        progressUIState.dragStartY = dy
        progressUIState.dragLastY = dy
        progressUIState.scrollVel = 0
        return
    end

    -- === 寮€鍙戣€呮垬鍦虹紪杈戝櫒杈撳叆 ===
    if gameState.phase == "DEV_EDITOR" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 杩斿洖鎸夐挳
        if HitRect(editorState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- Tab鍒囨崲
        for i, r in ipairs(editorState.tabRects) do
            if HitRect(r) then
                editorState.tab = i
                editorState.scrollY = 0
                editorState.scrollVel = 0
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- Tab 1: 鍏冲崱缂栬緫
        if editorState.tab == 1 then
            -- 闅惧害鍑忓皯
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
                -- 鐐瑰嚮鍏冲崱鍗＄墖閫変腑
                if HitRect(editorState.btnRects["stage_" .. si]) then
                    editorState.selectedStage = si
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 閲嶇疆鍏ㄩ儴闅惧害
            if HitRect(editorState.btnRects["reset_stages"]) then
                editorState.stageOverrides = {}
                PlaySFX(AUDIO.sfx_click)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "宸查噸缃叏閮ㄩ毦搴?, 1.5, { 255, 200, 100 }, 16)
                return
            end
        end
        -- Tab 2: 鎴樻枟鍙傛暟
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
            -- 閲嶇疆鍏ㄩ儴鍙傛暟
            if HitRect(editorState.btnRects["reset_params"]) then
                editorState.overrides = {
                    baseHpMax = nil, initialGold = nil, enemySpawnCd = nil,
                    playerSpawnCd = nil, battleTimeLimit = nil, soldierStatScale = nil, deployCd = nil,
                }
                PlaySFX(AUDIO.sfx_click)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "宸查噸缃叏閮ㄥ弬鏁?, 1.5, { 255, 200, 100 }, 16)
                return
            end
        end
        -- Tab 3: 蹇€熸祴璇?
        if editorState.tab == 3 then
            -- 閫夋嫨娴嬭瘯鍏冲崱
            for si = 1, #STAGES do
                if HitRect(editorState.btnRects["test_stage_" .. si]) then
                    editorState.testStage = si
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 寮€濮嬫祴璇曟垬鏂?
            if HitRect(editorState.btnRects["start_test"]) then
                ApplyEditorOverrides()
                stageState.currentStage = editorState.testStage
                gameState.isDummy = false
                InitBattle()
                PushPhase("BATTLE")
                phaseChangeCooldown = 0.3
                PlaySFX(AUDIO.sfx_click)
                print("=== 缂栬緫鍣? 寮€濮嬫祴璇曞叧鍗?" .. editorState.testStage .. " ===")
                return
            end
        end
        -- Tab 4: 鐭冲彴缂栬緫
        if editorState.tab == 4 then
            -- 瀵煎嚭澶嶅埗鎸夐挳
            if HitRect(editorState.btnRects["slot_save"]) then
                ExportBattleLayouts()
                editorState.saveFlashT = os.clock()
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鎾ら攢鎸夐挳
            if HitRect(editorState.btnRects["slot_undo"]) then
                if UndoSlotEdit() then
                    print("[甯冨眬缂栬緫鍣╙ 鎾ら攢鎴愬姛, 鍓╀綑 " .. #slotUndoStack .. " 姝?)
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 蹇嵎閫夋嫨鎸夐挳: 閫夋垜鏂?/ 閫夋晫鏂?/ 娓呴櫎閫夋嫨
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
            -- 甯冨眬閫夋嫨
            for li = 1, #BATTLE_LAYOUTS do
                if HitRect(editorState.btnRects["layout_" .. li]) then
                    editorState.editLayoutIdx = li
                    editorState.slotDragging = false
                    editorState.selectedSlots = {}
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 鐭冲彴鍦嗗湀鎸変笅 鈫?璁板綍鎸変笅淇℃伅 (HandleMoveLogic 涓垽鏂槸鍚︽嫋鎷?
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
            -- 鐐瑰嚮绌虹櫧鍖哄煙: 娓呴櫎閫夋嫨
            editorState.selectedSlots = {}
            return
        end
        -- 婊氬姩鎷栨嫿
        editorState.isDragging = true
        editorState.dragStartY = dy
        editorState.dragLastY = dy
        editorState.scrollVel = 0
        return
    end

    -- === 鎶藉崱鐣岄潰杈撳叆 === (宸茬Щ闄ゆ娊鍗＄郴缁?
    --[=[ GACHA phase removed
    if gameState.phase == "GACHA" then
        return
    end
    --]=]

    -- === 鍥鹃壌鐣岄潰杈撳叆 ===
    if gameState.phase == "CODEX" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(codexBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 杩斿洖涓婁竴椤?===")
            return
        end
        -- 鍝佽川鏍囩椤电偣鍑绘娴?
        for _, tr in ipairs(codexTabRects) do
            if HitRect(tr) then
                if codexTab ~= tr.tabIdx then
                    codexTab = tr.tabIdx
                    codexScroll.y = 0  -- 鍒囨崲鏍囩椤垫椂閲嶇疆婊氬姩浣嶇疆
                    codexScroll.vel = 0
                end
                return
            end
        end
        -- 璁板綍鎷栨嫿璧峰浣嶇疆锛堢敤浜庢粴鍔紝鐐瑰嚮寤惰繜鍒癊ndPress鍒ゆ柇锛?
        codexScroll.dragStartY = dy
        codexScroll.dragLastY = dy
        codexScroll.isDragging = true
        codexScroll.vel = 0
        return
    end

    -- === 姝︾伒璇︽儏椤佃緭鍏?===
    if gameState.phase == "HERO_DETAIL" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(heroDetailBackBtnRect) then
            PopPhase("CODEX")
            phaseChangeCooldown = 0.3
            print("=== 杩斿洖涓婁竴椤?===")
            return
        end
        -- 寮€濮嬫嫋鎷芥粴鍔?
        heroDetailScroll.dragStartY = dy
        heroDetailScroll.dragLastY = dy
        heroDetailScroll.isDragging = true
        heroDetailScroll.vel = 0
        return
    end

    -- === 鐜╁璇︽儏椤佃緭鍏?===
    if gameState.phase == "PLAYER_DETAIL" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(playerDetailBackBtnRect) then
            powerExplainPopup.show = false
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 杩斿洖涓婁竴椤?===")
            return
        end
        -- 鐐瑰嚮宸茶澶囨鎶€ 鈫?璺宠浆姝︽妧璇︽儏
        if playerDetailSkillRects then
            for _, sr in pairs(playerDetailSkillRects) do
                if HitRect(sr) and sr.skIdx then
                    skillCodexState.selectedIdx = sr.skIdx
                    PushPhase("SKILL_DETAIL")
                    phaseChangeCooldown = 0.3
                    print("=== 鏌ョ湅姝︽妧璇︽儏: " .. (SKILL_TECHNIQUES[sr.skIdx] and SKILL_TECHNIQUES[sr.skIdx].name or "") .. " ===")
                    return
                end
            end
        end
        -- 鐐瑰嚮姝︾伒鍗＄墝 鈫?璺宠浆姝︾伒璇︽儏
        if playerDetailHeroRects then
            for _, hr in pairs(playerDetailHeroRects) do
                if HitRect(hr) and hr.heroIdx then
                    local hero = playerHeroes[hr.heroIdx]
                    if hero and hero.owned then
                        heroDetailState.cardIdx = hr.heroIdx
                        heroDetailScroll.y = 0; heroDetailScroll.vel = 0
                        PushPhase("HERO_DETAIL")
                        phaseChangeCooldown = 0.3
                        print("=== 鏌ョ湅姝︾伒璇︽儏: " .. HERO_CARDS[hr.heroIdx].name .. " ===")
                        return
                    end
                end
            end
        end
        -- 鎴樺姏璇存槑寮圭獥浜や簰锛堜娇鐢ㄧ粺涓€鐨?powerExplainPopup锛?
        if powerExplainPopup.show then
            local cr = powerExplainPopup.closeBtnRect
            if cr and HitRect(cr) then
                powerExplainPopup.show = false
                PlaySFX(AUDIO.sfx_click)
            end
            -- 鐐瑰嚮寮圭獥澶栧叧闂?
            local pr = powerExplainPopup.panelRect
            if not (pr and HitRect(pr)) then
                powerExplainPopup.show = false
            end
            return  -- 寮圭獥鎵撳紑鏃舵嫤鎴墍鏈夊叾浠栫偣鍑?
        end
        -- "?" 鎸夐挳鐐瑰嚮 鈫?鏄剧ず鎴樺姏璇存槑
        if playerDetailPowerHelpRect and playerDetailPowerHelpRect.isCircle then
            local pdx, pdy = dx - playerDetailPowerHelpRect.cx, dy - playerDetailPowerHelpRect.cy
            if pdx * pdx + pdy * pdy <= playerDetailPowerHelpRect.r * playerDetailPowerHelpRect.r then
                powerExplainPopup.show = true
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 缂栬緫璧勬枡鎸夐挳
        if HitRect(playerDetailEditBtnRect) then
            -- 棰勫～鍏呭綋鍓嶅ご鍍忓拰鍚嶅瓧
            for i, avOpt in ipairs(AVATAR_OPTIONS) do
                if avOpt == playerInfo.avatarIdx then
                    profileState.selectedAvatar = i
                    break
                end
            end
            profileState.customName = playerInfo.name
            profileState.selectedName = CUSTOM_NAME_IDX
            profileState.isInputActive = false
            profileState.editMode = true  -- 鏍囪涓虹紪杈戞ā寮?
            PushPhase("PROFILE")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            print("=== 缂栬緫璧勬枡 ===")
            return
        end
        -- 寮€濮嬫嫋鎷芥粴鍔?
        playerDetailScroll.dragStartY = dy
        playerDetailScroll.dragLastY = dy
        playerDetailScroll.isDragging = true
        playerDetailScroll.vel = 0
        return
    end

    -- === 鍏电敳鐣岄潰杈撳叆 ===
    if gameState.phase == "EQUIP" then
        -- 鏂扮増NanoVG缃戞牸浠撳簱锛氬鎵樿Е鎽镐簨浠?
        if EquipUI.isVisible then
            local dx, dy = ScreenToDesign(sx, sy)
            EquipUI.HandleTouchBegin(dx, dy)
            return
        end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 寮哄寲纭寮圭獥锛氭嫤鎴墍鏈夌偣鍑?
        if equipScreenState.enhanceConfirm then
            if HitRect(equipScreenState.enhanceConfirmBtn) then
                local ec = equipScreenState.enhanceConfirm
                local ok = EnhanceEquipment(ec.slotIdx)
                if ok then
                    print("=== 寮哄寲鎴愬姛: 妲戒綅" .. ec.slotIdx .. " ===")
                end
                equipScreenState.enhanceConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            elseif HitRect(equipScreenState.enhanceCancelBtn) then
                equipScreenState.enhanceConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            end
            -- 寮圭獥鏈熼棿鍚炴帀鎵€鏈夌偣鍑?
            return
        end
        -- 鍒嗚В纭寮圭獥锛氭嫤鎴墍鏈夌偣鍑?
        if equipScreenState.decompConfirm then
            if HitRect(equipScreenState.decompConfirmBtn) then
                local dc = equipScreenState.decompConfirm
                local ok = DecomposeEquipment(dc.uid)
                if ok then
                    print("=== 鍒嗚В瑁呭: uid=" .. dc.uid .. " 濂楄" .. dc.setIdx .. " 闃剁骇" .. dc.tier .. " ===")
                end
                equipScreenState.decompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            elseif HitRect(equipScreenState.decompCancelBtn) then
                equipScreenState.decompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            end
            -- 寮圭獥鏈熼棿鍚炴帀鎵€鏈夌偣鍑?
            return
        end
        -- 鎵归噺鍒嗚В纭寮圭獥锛氭嫤鎴墍鏈夌偣鍑?
        if equipScreenState.batchDecompConfirm then
            if equipScreenState.batchDecompConfirmBtn and HitRect(equipScreenState.batchDecompConfirmBtn) then
                local ft = equipScreenState.batchFilterMaxTier or 6
                BatchDecomposeAll(ft)
                equipScreenState.batchDecompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
                print("=== 鎵归噺鍒嗚В瀹屾垚 (绛涢€夊搧璐?=" .. ft .. ") ===")
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
        -- 閫変腑鍒嗚В纭寮圭獥锛氭嫤鎴墍鏈夌偣鍑?
        if equipScreenState.selectDecompConfirm then
            if equipScreenState.selectDecompConfirmBtn and HitRect(equipScreenState.selectDecompConfirmBtn) then
                SelectDecomposeAll(equipScreenState.selectedUids)
                equipScreenState.selectDecompConfirm = nil
                equipScreenState.selectMode = false
                equipScreenState.selectedUids = {}
                PlaySFX(AUDIO.sfx_click)
                print("=== 閫変腑鍒嗚В瀹屾垚 ===")
            elseif equipScreenState.selectDecompCancelBtn and HitRect(equipScreenState.selectDecompCancelBtn) then
                equipScreenState.selectDecompConfirm = nil
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
        -- 閫変腑妯″紡搴曢儴鎿嶄綔鏍忔寜閽?
        if equipScreenState.selectMode then
            -- 鍙栨秷鎸夐挳
            if equipScreenState.selectCancelBtn and HitRect(equipScreenState.selectCancelBtn) then
                equipScreenState.selectMode = false
                equipScreenState.selectedUids = {}
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 纭鍒嗚В鎸夐挳 鈫?寮瑰嚭纭寮圭獥
            if equipScreenState.selectConfirmBtn and HitRect(equipScreenState.selectConfirmBtn) then
                local sc, sg = CalcSelectDecomposeStats(equipScreenState.selectedUids)
                equipScreenState.selectDecompConfirm = { count = sc, gain = sg }
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鍏ㄩ€夋寜閽?
            if equipScreenState.selectAllBtn and HitRect(equipScreenState.selectAllBtn) then
                -- 鍏ㄩ€夊綋鍓嶆墍鏈夋湭瑁呭鍏电敳
                for _, itm in ipairs(playerEquipment.owned) do
                    if playerEquipment.equipped[itm.slotIdx] ~= itm.uid then
                        equipScreenState.selectedUids[itm.uid] = true
                    end
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 杩斿洖鎸夐挳
        if HitRect(equipBackBtnRect) then
            if equipScreenState.selectMode then
                equipScreenState.selectMode = false
                equipScreenState.selectedUids = {}
            else
                PopPhase("MENU")
                phaseChangeCooldown = 0.3
                print("=== 杩斿洖涓婁竴椤?===")
            end
            return
        end
        -- 鐐瑰嚮閫変腑鍒嗚В鎸夐挳 鈫?杩涘叆閫変腑妯″紡
        if equipScreenState.selectDecompBtn and HitRect(equipScreenState.selectDecompBtn) then
            equipScreenState.selectMode = true
            equipScreenState.selectedUids = {}
            PlaySFX(AUDIO.sfx_click)
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "閫変腑瑕佸垎瑙ｇ殑鍏电敳", 1.0, { 100, 180, 255 }, 16)
            return
        end
        -- 鐐瑰嚮绛涢€夊垎瑙ｆ寜閽?鈫?寮瑰嚭纭寮圭獥(浣跨敤褰撳墠绛涢€?
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
        -- 鐐瑰嚮寮哄寲鎸夐挳 鈫?寮瑰嚭纭寮圭獥
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
        -- 鐐瑰嚮瑁呭妲戒綅鍒囨崲閫変腑
        for si, rect in pairs(equipSlotRects) do
            if HitRect(rect) then
                equipScreenState.selectedSlot = si
                equipScreenState.scrollY = 0
                equipScreenState.scrollVel = 0
                -- 娑堥櫎璇ユЫ浣嶇殑绾㈢偣锛堢‘璁ゅ凡鏌ョ湅锛?
                redDotState.equipAck[si] = GetBestOwnedScoreForSlot(si)
                return
            end
        end
        -- 瑁呭鍒楄〃鍖哄煙锛氱函婊氬姩鎷栨嫿锛堣澶?鍗镐笅閫氳繃妲戒綅鎿嶄綔锛?
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

    -- 淇℃伅寮圭獥鎵撳紑鏃? 鐐瑰嚮浠绘剰鍖哄煙鍏抽棴
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

    -- 閭欢绯荤粺
    if gameState.phase == "MAIL_BOX" then
        -- 杩斿洖鎸夐挳
        if menuBtnRects.mailBack and HitRect(menuBtnRects.mailBack) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            welfareState.mail.confirmPopup = nil
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- ======== 鍐欎俊寮圭獥浜や簰锛堢鐞嗗憳涓撶敤锛屼唬鐮佸湪 admin/ 鐩綍锛?========
        if IS_ADMIN_BUILD and _AdminMailInput and welfareState.mail.composing and welfareState.mail.composeData then
            if _AdminMailInput.HandleComposeClick() then return end
        end

        -- ======== 纭寮圭獥浜や簰锛堟楂樹紭鍏堢骇锛?========
        if welfareState.mail.confirmPopup then
            local popup = welfareState.mail.confirmPopup
            if popup.confirmBtnRect and HitRect(popup.confirmBtnRect) then
                if popup.cloudMail then
                    -- 浜戦偖浠堕鍙?
                    local cm = popup.cloudMail
                    if not CloudManager.IsMailClaimed(cm.id) then
                        CloudManager.ClaimMail(cm.id)
                        -- 瀹夊叏楠岃瘉锛氬彧鏈夌鐞嗗憳鍙戦€佺殑閭欢鎵嶈兘鍙戞斁濂栧姳
                        local senderIsAdmin = CloudManager.IsAdmin and CloudManager.IsAdmin(cm.from) or false
                        local safeRewards = senderIsAdmin and (cm.rewards or {}) or {}
                        if not senderIsAdmin and cm.rewards and #cm.rewards > 0 then
                            print("[瀹夊叏] 闈炵鐞嗗憳閭欢鍚鍔憋紝宸插拷鐣? from=" .. tostring(cm.from))
                        end
                        for _, rw in ipairs(safeRewards) do
                            if rw.type == "jade" then
                                playerInfo.jade = playerInfo.jade + rw.amount
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                                    "+" .. rw.amount .. " 铏庣", 1.5, { 255, 220, 100 }, 18)
                            elseif rw.type == "ad_free" then
                                playerInfo.ad_free = true
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                    "鑾峰緱鍏嶅箍鍛婄壒鏉?", 1.5, { 100, 255, 150 }, 16)
                            elseif rw.type == "full_skill" then
                                local skIdx = rw.skillIdx
                                if skIdx then
                                    skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                                    local skName = SKILL_TECHNIQUES[skIdx] and SKILL_TECHNIQUES[skIdx].name or ("姝︽妧#" .. skIdx)
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                        "鑾峰緱姝︽妧銆? .. skName .. "銆?, 1.5, { 200, 160, 255 }, 16)
                                end
                            elseif rw.type == "seal" then
                                local heroIdx = rw.fromHero
                                local slotType = rw.slotType
                                local sealQ = rw.sealQ or 1
                                if heroIdx and slotType then
                                    -- 鐩存帴瑁呭鍒版鐏靛瓟浣嶄笂锛堣鐩栨棫鐨勶級
                                    if not sealData[heroIdx] then sealData[heroIdx] = { slots = {} } end
                                    sealData[heroIdx].slots[slotType] = { sealQ = sealQ, level = rw.level or 1, exp = 0 }
                                    local heroName = HERO_CARDS[heroIdx] and HERO_CARDS[heroIdx].name or ("姝︾伒#" .. heroIdx)
                                    local tierName = SEAL_TIER_NAMES[sealQ] or "鏈煡"
                                    local slotName = SEAL_SLOT_NAMES[slotType] or ("瀛? .. slotType)
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                        heroName .. " 鑾峰緱" .. tierName .. slotName, 1.5, { 180, 140, 255 }, 16)
                                end
                            end
                        end
                        SaveGameProgress()
                        print("=== 浜戦偖浠堕鍙? " .. (cm.subject or cm.id) .. " ===")
                    end
                else
                    -- 绯荤粺閭欢棰嗗彇
                    local mail = welfareState.mailDefs[popup.mailIdx]
                    if mail and not welfareState.mail.claimed[mail.id] then
                        welfareState.mail.claimed[mail.id] = true
                        for _, rw in ipairs(mail.rewards) do
                            if rw.type == "jade" then
                                playerInfo.jade = playerInfo.jade + rw.amount
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                                    "+" .. rw.amount .. " 铏庣", 1.5, { 255, 220, 100 }, 18)
                            elseif rw.type == "full_skill" then
                                local skIdx = rw.skillIdx
                                skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                                local skName = SKILL_TECHNIQUES[skIdx] and SKILL_TECHNIQUES[skIdx].name or ("姝︽妧#" .. skIdx)
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                                    "鑾峰緱姝︽妧銆? .. skName .. "銆?, 1.5, { 200, 160, 255 }, 16)
                            end
                        end
                        SaveGameProgress()
                        print("=== 閭欢棰嗗彇: " .. mail.title .. " ===")
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
            return  -- 寮圭獥鎵撳紑鏃舵嫤鎴?
        end

        -- ======== Tab 鍒囨崲 ========
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

        -- ======== 浜戦偖浠?Tab 鎸夐挳 ========
        if welfareState.mail.tab == "cloud" then
            -- 绠＄悊鍛樻寜閽紙鍐欎俊/鍙戝鍔?鐜╁绠＄悊锛屼唬鐮佸湪 admin/ 鐩綍锛?
            if IS_ADMIN_BUILD and _AdminMailInput then
                if _AdminMailInput.HandleAdminButtonClick() then return end
            end
            -- 鍒锋柊鎸夐挳
            if menuBtnRects.mailRefresh and HitRect(menuBtnRects.mailRefresh) then
                CloudManager.ForceRefreshInbox(function()
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "閭欢宸插埛鏂?, 1.2, {140,220,180}, 14)
                end)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 浜戦偖浠堕鍙栨寜閽?
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

        -- ======== 绯荤粺閭欢 Tab 棰嗗彇鎸夐挳 ========
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
            -- 闈炵鐞嗗憳: 绯荤粺閭欢Tab涓殑浜戦偖浠堕鍙栨寜閽?
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

        -- 娌℃湁鍛戒腑鎸夐挳锛屽紑濮嬫粴鍔ㄦ嫋鎷?
        local _, dy2 = ScreenToDesign(sx, sy)
        if welfareState.mail.scroll then
            welfareState.mail.scroll.isDragging = true
            welfareState.mail.scroll.dragStartY = dy2
            welfareState.mail.scroll.dragLastY = dy2
            welfareState.mail.scroll.vel = 0
        end
        return
    end

    -- ======== 浜ゆ槗琛岀晫闈㈢偣鍑诲鐞?========
    if gameState.phase == "TRADE" then
        -- 纭寮圭獥浼樺厛
        if tradeState.confirmPopup then
            local pop = tradeState.confirmPopup
            -- 涓婃灦瀹氫环寮圭獥: 浠锋牸 +/-
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
        -- Tab 鍒囨崲
        if tradeState.btnRects.tabMarket and HitRect(tradeState.btnRects.tabMarket) then
            tradeState.tab = "market"; tradeState.scroll.offset = 0; tradeState.scroll.vel = 0
            tradeState.selectedItem = nil; PlaySFX(AUDIO.sfx_click); return
        end
        if tradeState.btnRects.tabMine and HitRect(tradeState.btnRects.tabMine) then
            tradeState.tab = "mine"; tradeState.scroll.offset = 0; tradeState.scroll.vel = 0
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鍒锋柊鎸夐挳
        if tradeState.btnRects.refresh and HitRect(tradeState.btnRects.refresh) then
            TradeManager.RefreshMarket(function()
                ShowToast("甯傚満宸插埛鏂?)
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 棰嗗彇铏庣鎸夐挳
        if tradeState.btnRects.claimJade and HitRect(tradeState.btnRects.claimJade) then
            TradeManager.ClaimJade(function(amount)
                if amount > 0 then
                    ShowToast("棰嗗彇 " .. amount .. " 铏庣")
                else
                    ShowToast("鏆傛棤鍙鍙栬檸绗?)
                end
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 甯傚満鍒楄〃鐐瑰嚮 (浣跨敤杩囨护鍚庣殑鐗╁搧鍒楄〃)
        if tradeState.tab == "market" then
            local items = tradeState._filteredMarketItems or TradeManager.state.marketItems or {}
            for i, _ in ipairs(items) do
                local rect = tradeState.btnRects["market_" .. i]
                if rect and HitRect(rect) then
                    local item = items[i]
                    if item.isMine then
                        ShowToast("杩欐槸浣犺嚜宸变笂鏋剁殑瑁呭")
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
        -- 鎴戠殑涓婃灦鍒楄〃鐐瑰嚮 (涓嬫灦/棰嗗彇)
        if tradeState.tab == "mine" then
            -- 鍦ㄥ敭items
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
            -- 鍙氦鏄撶墿鍝佷笂鏋舵寜閽?
            local tItems = tradeState.tradeableItems or {}
            for i, item in ipairs(tItems) do
                local rect = tradeState.btnRects["list_" .. i]
                if rect and HitRect(rect) then
                    -- 妫€鏌ヤ笂鏋舵暟閲忛檺鍒?
                    if TradeManager.GetListingCount() >= GameConfig.TRADE.MAX_LISTINGS then
                        ShowToast("涓婃灦鏁伴噺宸茶揪涓婇檺(" .. GameConfig.TRADE.MAX_LISTINGS .. "浠?")
                        PlaySFX(AUDIO.sfx_click); return
                    end
                    -- 鎵撳紑瀹氫环寮圭獥
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
        -- 娌℃湁鍛戒腑鎸夐挳锛屽紑濮嬫粴鍔ㄦ嫋鎷?
        tradeState.scroll.isDragging = true
        tradeState.scroll.dragStartY = dy
        tradeState.scroll.dragLastY = dy
        tradeState.scroll.vel = 0
        return
    end

    -- 鎴樺姏鎺掕姒滅嫭绔嬬晫闈?
    -- ======== 闃佃惀鐣岄潰鐐瑰嚮澶勭悊 ========
    if gameState.phase == "FACTION" then
        -- 鏀瑰悕寮圭獥浼樺厛
        if factionUI.renamePopup then
            if menuBtnRects.factionRenameYes and HitRect(menuBtnRects.factionRenameYes) then
                local newName = factionUI.renameInput or ""
                if #newName == 0 then
                    ShowToast("鍚嶇О涓嶈兘涓虹┖")
                elseif (playerInfo.jade or 0) < 1000 then
                    ShowToast("铏庣涓嶈冻锛屾敼鍚嶉渶瑕?000铏庣")
                else
                    playerInfo.jade = playerInfo.jade - 1000
                    CloudManager.RenameFaction(newName, function(ok, reason)
                        if ok then
                            ShowToast("闃佃惀宸叉洿鍚嶄负銆? .. newName .. "銆?-1000铏庣)")
                            factionUI.loaded = false; factionUI.loading = false
                            if SaveGameProgress then SaveGameProgress() end
                        else
                            -- 鏀瑰悕澶辫触锛岄€€杩樿檸绗?
                            playerInfo.jade = playerInfo.jade + 1000
                            ShowToast("鏀瑰悕澶辫触: " .. tostring(reason))
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
            -- 鐐硅緭鍏ユ婵€娲婚敭鐩?
            if menuBtnRects.factionRenameInput and HitRect(menuBtnRects.factionRenameInput) then
                factionUI.inputTarget = "rename"
                input:SetScreenKeyboardVisible(true)
                PlaySFX(AUDIO.sfx_click); return
            end
            return  -- 寮圭獥鎵撳紑鏃舵嫤鎴?
        end
        -- 纭寮圭獥浼樺厛
        if factionUI.confirmPopup then
            if menuBtnRects.factionPopupYes and HitRect(menuBtnRects.factionPopupYes) then
                local pop = factionUI.confirmPopup
                factionUI.confirmPopup = nil
                PlaySFX(AUDIO.sfx_click)
                if pop.type == "leave" then
                    CloudManager.LeaveFaction(function(ok)
                        if ok then
                            ShowToast("宸查€€鍑洪樀钀?)
                            factionUI.tab = "list"
                            factionUI.loaded = false
                            factionUI.loading = false
                            factionUI.applyStatus = nil
                            factionUI.members = {}
                            factionUI.applications = {}
                            factionUI.chatPolled = false
                            playerInfo.factionJoined = 0
                            SaveGameProgress()
                        else ShowToast("鎿嶄綔澶辫触") end
                    end)
                elseif pop.type == "apply" then
                    CloudManager.ApplyToFaction(pop.targetId, pop.targetName, function(ok)
                        if ok then
                            factionUI.applyStatus = "pending"
                            playerInfo.factionJoined = 1
                            ShowToast("鐢宠宸插彂閫?)
                        else ShowToast("鐢宠澶辫触") end
                    end)
                elseif pop.type == "create" then
                    -- 铏庣妫€鏌ュ拰鎵ｈ垂鐢?CloudManager.CreateFaction 缁熶竴澶勭悊
                    CloudManager.CreateFaction(factionUI.createName, factionUI.createDesc, function(ok, reason)
                        if ok then
                            playerInfo.totalFactionCreated = (playerInfo.totalFactionCreated or 0) + 1
                            playerInfo.factionJoined = 1
                            ShowToast("闃佃惀鍒涘缓鎴愬姛锛?)
                            factionUI.tab = "info"
                            factionUI.loaded = false
                            factionUI.loading = false
                            factionUI.createName = ""; factionUI.createDesc = ""
                            SaveGameProgress()
                        else
                            ShowToast(reason or "鍒涘缓澶辫触")
                        end
                    end)
                elseif pop.type == "kick" then
                    CloudManager.KickMember(pop.targetUserId, function(ok, reason)
                        if ok then
                            ShowToast("宸茶涪鍑烘垚鍛?)
                            factionUI.loaded = false; factionUI.loading = false
                        else
                            ShowToast("韪㈠嚭澶辫触: " .. tostring(reason))
                        end
                    end)
                end
                return
            end
            if menuBtnRects.factionPopupNo and HitRect(menuBtnRects.factionPopupNo) then
                factionUI.confirmPopup = nil; PlaySFX(AUDIO.sfx_click); return
            end
            return  -- 寮圭獥鎵撳紑鏃舵嫤鎴?
        end
        -- 杩斿洖
        if menuBtnRects.factionBack and HitRect(menuBtnRects.factionBack) then
            factionUI.inputTarget = nil; input:SetScreenKeyboardVisible(false)
            PopPhase("MENU"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return
        end
        -- Tab 鍒囨崲
        for _, tid in ipairs({"info", "members", "chat", "apply", "list", "create"}) do
            local r = menuBtnRects["factionTab_" .. tid]
            if r and HitRect(r) then
                if factionUI.tab ~= tid then
                    factionUI.tab = tid; factionUI.inputTarget = nil
                    factionUI.subView = nil
                    factionUI.scroll.offset = 0; factionUI.scroll.vel = 0
                    -- 鍒囨崲 tab 鏃堕噸鏂板姞杞藉搴旀暟鎹?
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
        -- 鑱屼綅閫夋嫨寮圭獥鎵撳紑鏃讹紝鎷︽埅鎵€鏈夊叾浠栫偣鍑?
        if factionUI.rolePopup then
            for i = 1, 6 do
                local optR = menuBtnRects["factionRoleOption_" .. i]
                if optR and HitRect(optR) then
                    local rp = factionUI.rolePopup
                    local newRole = optR.roleKey
                    if newRole ~= rp.currentRole then
                        CloudManager.SetMemberRole(rp.userId, newRole, function(ok, reason)
                            if ok then
                                ShowToast("宸插皢銆? .. (rp.nickname or "?") .. "銆嶈涓? .. (reason or newRole))
                                factionUI.loaded = false; factionUI.loading = false
                            else
                                ShowToast("璁剧疆澶辫触: " .. tostring(reason))
                            end
                        end)
                    end
                    factionUI.rolePopup = nil
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
            -- 鐐瑰脊绐楀鍏抽棴
            factionUI.rolePopup = nil
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鎺掕姒滈潰鏉匡紙鏈€楂樹紭鍏堢骇锛岃鐩栧叾浠栨搷浣滐級
        if factionUI.showRank then
            if menuBtnRects.factionRankClose and HitRect(menuBtnRects.factionRankClose) then
                factionUI.showRank = false
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 鎺掕姒滈伄缃╃偣鍑讳篃鍏抽棴
            if menuBtnRects.factionRankOverlay and HitRect(menuBtnRects.factionRankOverlay) then
                factionUI.showRank = false
                PlaySFX(AUDIO.sfx_click); return
            end
            return  -- 鎺掕姒滄墦寮€鏃舵嫤鎴墍鏈夊叾浠栫偣鍑?
        end
        -- 鎺掕姒滄墦寮€鎸夐挳
        if menuBtnRects.factionRankBtn and HitRect(menuBtnRects.factionRankBtn) then
            factionUI.showRank = true
            factionUI.rankLoaded = false; factionUI.rankLoading = false
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 瀛愯鍥捐繑鍥炴寜閽?
        if menuBtnRects.factionSubBack and HitRect(menuBtnRects.factionSubBack) then
            factionUI.subView = nil; factionUI.showRank = false
            factionUI.inputTarget = nil
            input:SetScreenKeyboardVisible(false)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鎹愮尞閲戦閫夋嫨
        for ai = 1, 4 do
            local amtR = menuBtnRects["factionDonateAmt_" .. ai]
            if amtR and HitRect(amtR) then
                factionUI.donateAmount = amtR.amount
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 鎹愮尞鎸夐挳
        if menuBtnRects.factionDonate and HitRect(menuBtnRects.factionDonate) then
            if not factionUI.donating then
                factionUI.donating = true
                CloudManager.DonateFaction(factionUI.donateAmount, function(ok, reason)
                    factionUI.donating = false
                    if ok then
                        if reason then
                            ShowToast(reason)  -- 鍗囩骇鎻愮ず
                        else
                            ShowToast("鎹愮尞鎴愬姛! +" .. factionUI.donateAmount .. " 铏庣")
                        end
                    else
                        ShowToast("鎹愮尞澶辫触: " .. tostring(reason))
                    end
                end)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鍏憡杈撳叆妗?
        if menuBtnRects.factionAnnounceInput and HitRect(menuBtnRects.factionAnnounceInput) then
            factionUI.inputTarget = "announce"
            input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鍏憡淇濆瓨鎸夐挳
        if menuBtnRects.factionAnnounceSave and HitRect(menuBtnRects.factionAnnounceSave) then
            CloudManager.SetFactionAnnouncement(factionUI.announceInput, function(ok, reason)
                if ok then
                    ShowToast("鍏憡宸叉洿鏂?)
                    factionUI.announceInput = ""
                    factionUI.inputTarget = nil
                    input:SetScreenKeyboardVisible(false)
                else
                    ShowToast("鏇存柊澶辫触: " .. tostring(reason))
                end
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 闃佃惀鍔熻兘鍏ュ彛锛氭垚鍛樼鐞?鈫?members tab锛岃亰澶?鈫?chat tab
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
        -- 姣忔棩绛惧埌
        if menuBtnRects["factionFeat_signIn"] and HitRect(menuBtnRects["factionFeat_signIn"]) then
            if CloudManager.HasSignedInToday() then
                ShowToast("浠婃棩宸茬鍒?)
            elseif not factionUI.signingIn then
                factionUI.signingIn = true
                CloudManager.FactionSignIn(function(ok, reason)
                    factionUI.signingIn = false
                    if ok then
                        if reason then
                            ShowToast(reason)  -- 鍗囩骇鎻愮ず
                        else
                            ShowToast("绛惧埌鎴愬姛! 闃佃惀缁忛獙+500")
                        end
                    else
                        ShowToast("绛惧埌澶辫触: " .. tostring(reason))
                    end
                end)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 闃佃惀鎺掕鍏ュ彛 鈫?鎵撳紑鎺掕姒滃脊鍑洪潰鏉?
        if menuBtnRects["factionFeat_rank"] and HitRect(menuBtnRects["factionFeat_rank"]) then
            factionUI.showRank = true
            factionUI.rankLoaded = false; factionUI.rankLoading = false
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鎴愬憳璐＄尞 鈫?鎵撳紑璐＄尞瀛愯鍥?
        if menuBtnRects["factionFeat_contrib"] and HitRect(menuBtnRects["factionFeat_contrib"]) then
            factionUI.subView = "contrib"
            factionUI.contribLoaded = false; factionUI.contribLoading = false
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 闃佃惀鑱婂ぉ: 娣诲姞濂藉弸鎸夐挳
        if menuBtnRects.factionChatAddFriend and HitRect(menuBtnRects.factionChatAddFriend) then
            local targetUid = menuBtnRects.factionChatAddFriend.uid
            local targetName = menuBtnRects.factionChatAddFriend.name or "?"
            local myUid = CloudAPI.GetUserId()
            if targetUid == myUid then
                ShowToast("涓嶈兘娣诲姞鑷繁涓哄ソ鍙?)
            else
                CloudManager.SendFriendRequest(targetUid, "")
                playerInfo.totalFriendReqs = (playerInfo.totalFriendReqs or 0) + 1
                ShowToast("宸插悜銆? .. targetName .. "銆嶅彂閫佸ソ鍙嬭姹?)
            end
            factionUI.chatNamePopup = nil
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 闃佃惀鑱婂ぉ: 寮圭獥鍖哄煙鍐呯偣鍑讳笉绌块€?
        if menuBtnRects.factionChatPopupArea and HitRect(menuBtnRects.factionChatPopupArea) then
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 闃佃惀鑱婂ぉ: 鐐瑰嚮澶村儚寮瑰嚭鐜╁淇℃伅
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
        -- 鑱婂ぉ杈撳叆妗?
        if menuBtnRects.factionChatInput and HitRect(menuBtnRects.factionChatInput) then
            factionUI.inputTarget = "chat"
            factionUI.chatNamePopup = nil
            if not factionUI.chatInput then factionUI.chatInput = "" end
            input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鑱婂ぉ鍙戦€佹寜閽?(浜戠鍚屾)
        if menuBtnRects.factionChatSend and HitRect(menuBtnRects.factionChatSend) then
            if factionUI.chatInput and #factionUI.chatInput > 0 then
                local filteredText = FilterBannedWords(factionUI.chatInput)
                local senderName = CloudManager._myTapNickname or factionUI.myNickname or playerInfo.name or "鎴?
                CloudManager.SendFactionChat(filteredText, senderName)
                playerInfo.totalFactionChat = (playerInfo.totalFactionChat or 0) + 1
                factionUI.chatInput = ""
                factionUI.inputTarget = nil
                input:SetScreenKeyboardVisible(false)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 闃佃惀鍏绘垚鍔熻兘鍏ュ彛 (鎵撳紑瀛愯鍥?
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
        -- 鍏朵綑寰呭紑鍙戝姛鑳?
        local devFeatIds = {"shop","war","task"}
        local devFeatNames = {shop="闃佃惀鍟嗗簵",war="闃佃惀鎴樹簤",task="闃佃惀浠诲姟"}
        for _, fid in ipairs(devFeatIds) do
            local fr = menuBtnRects["factionFeat_" .. fid]
            if fr and HitRect(fr) then
                ShowToast("銆? .. (devFeatNames[fid] or fid) .. "銆嶅姛鑳藉緟寮€鍙戯紝鏁鏈熷緟锛?)
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 鏀瑰悕鎸夐挳 (鐩熶富)
        if menuBtnRects.factionRename and HitRect(menuBtnRects.factionRename) then
            factionUI.renamePopup = true
            factionUI.renameInput = ""
            factionUI.inputTarget = "rename"
            input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 閫€鍑?瑙ｆ暎闃佃惀
        if menuBtnRects.factionLeave and HitRect(menuBtnRects.factionLeave) then
            local info = CloudManager.GetFactionInfo()
            local msg = (info and info.role == "leader") and "纭畾瑙ｆ暎闃佃惀锛? or "纭畾閫€鍑洪樀钀ワ紵"
            factionUI.confirmPopup = { type = "leave", msg = msg }
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鍏ラ槦鐢宠: 鍚屾剰/鎷掔粷
        for i = 1, 50 do
            local accR = menuBtnRects["factionAccept_" .. i]
            if accR and HitRect(accR) then
                local uid = accR.userId
                CloudManager.ApproveFactionApplication(uid, function(ok)
                    if ok then ShowToast("宸插悓鎰忕敵璇?) else ShowToast("鎿嶄綔澶辫触") end
                    factionUI.applyLoaded = false; factionUI.applyLoading = false
                    factionUI.loaded = false; factionUI.loading = false  -- 鍒锋柊鎴愬憳鍒楄〃
                    factionUI.pendingAppCount = math.max(0, factionUI.pendingAppCount - 1)
                    factionUI.lastAppCheckTime = 0  -- 瑙﹀彂绔嬪嵆閲嶆柊妫€鏌?
                end)
                PlaySFX(AUDIO.sfx_click); return
            end
            local rejR = menuBtnRects["factionReject_" .. i]
            if rejR and HitRect(rejR) then
                local uid = rejR.userId
                CloudManager.RejectFactionApplication(uid)
                ShowToast("宸叉嫆缁?); PlaySFX(AUDIO.sfx_click)
                factionUI.applyLoaded = false; factionUI.applyLoading = false
                factionUI.pendingAppCount = math.max(0, factionUI.pendingAppCount - 1)
                factionUI.lastAppCheckTime = 0
                return
            end
        end
        -- 鎴愬憳鍒楄〃: 璁剧疆鑱屼綅鎸夐挳
        for i = 1, 30 do
            local srR = menuBtnRects["factionSetRole_" .. i]
            if srR and HitRect(srR) then
                factionUI.rolePopup = { userId = srR.userId, currentRole = srR.currentRole, nickname = srR.nickname }
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 鎴愬憳鍒楄〃: 韪㈠嚭鎸夐挳
        for i = 1, 30 do
            local kR = menuBtnRects["factionKick_" .. i]
            if kR and HitRect(kR) then
                factionUI.confirmPopup = {
                    type = "kick", targetUserId = kR.userId,
                    msg = "纭畾灏嗐€? .. (kR.nickname or "?") .. "銆嶈涪鍑洪樀钀ワ紵"
                }
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 闃佃惀鍒楄〃: 鐢宠鍔犲叆
        for i = 1, 50 do
            local apR = menuBtnRects["factionApply_" .. i]
            if apR and HitRect(apR) then
                factionUI.confirmPopup = {
                    type = "apply", targetId = apR.campId, targetName = apR.campName,
                    msg = "鐢宠鍔犲叆銆? .. (apR.campName or "?") .. "銆嶏紵"
                }
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 鍒锋柊鐢宠鐘舵€?
        if menuBtnRects.factionRefreshApply and HitRect(menuBtnRects.factionRefreshApply) then
            CloudManager.CheckMyFactionApplication(function(status)
                if status == "approved" then
                    factionUI.applyStatus = nil; ShowToast("鐢宠宸查€氳繃锛?)
                    factionUI.loaded = false; factionUI.loading = false
                elseif status == "rejected" then
                    factionUI.applyStatus = nil; ShowToast("鐢宠琚嫆缁?)
                elseif status == "pending" then
                    ShowToast("浠嶅湪瀹℃壒涓?..")
                else
                    factionUI.applyStatus = nil; ShowToast("鐘舵€佸凡鏇存柊")
                end
            end)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 杈撳叆妗嗘縺娲?
        if menuBtnRects.factionNameInput and HitRect(menuBtnRects.factionNameInput) then
            factionUI.inputTarget = "name"; input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        if menuBtnRects.factionDescInput and HitRect(menuBtnRects.factionDescInput) then
            factionUI.inputTarget = "desc"; input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鍒涘缓闃佃惀
        if menuBtnRects.factionCreate and HitRect(menuBtnRects.factionCreate) then
            if #factionUI.createName < 2 then
                ShowToast("闃佃惀鍚嶇О鑷冲皯2涓瓧"); return
            end
            factionUI.confirmPopup = {
                type = "create",
                msg = "鑺辫垂5000铏庣鍒涘缓闃佃惀锛?
            }
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鎴愬憳鍒楄〃锛氭病鏈夊懡涓寜閽紝寮€濮嬫粴鍔ㄦ嫋鎷?
        if factionUI.tab == "members" and #factionUI.members > 0 then
            factionUI.scroll.isDragging = true
            factionUI.scroll.dragStartY = dy
            factionUI.scroll.dragLastY = dy
            factionUI.scroll.vel = 0
        end
        return
    end

    -- ======== 濂藉弸鐣岄潰鐐瑰嚮澶勭悊 ========
    if gameState.phase == "FRIENDS" then
        -- 纭寮圭獥浼樺厛
        if friendsUI.confirmPopup then
            if menuBtnRects.friendPopupYes and HitRect(menuBtnRects.friendPopupYes) then
                local pop = friendsUI.confirmPopup
                friendsUI.confirmPopup = nil
                PlaySFX(AUDIO.sfx_click)
                if pop.type == "delete" then
                    CloudManager.RemoveFriend(pop.targetId)
                    ShowToast("宸插垹闄ゅソ鍙?)
                    friendsUI.loaded = false; friendsUI.loading = false
                end
                return
            end
            if menuBtnRects.friendPopupNo and HitRect(menuBtnRects.friendPopupNo) then
                friendsUI.confirmPopup = nil; PlaySFX(AUDIO.sfx_click); return
            end
            return  -- 寮圭獥鎵撳紑鏃舵嫤鎴?
        end
        -- 杩斿洖
        if menuBtnRects.friendsBack and HitRect(menuBtnRects.friendsBack) then
            friendsUI.inputActive = false; input:SetScreenKeyboardVisible(false)
            PopPhase("MENU"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return
        end
        -- Tab 鍒囨崲
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
        -- 濂藉弸鍒楄〃: 鍒犻櫎
        for i = 1, 50 do
            local delR = menuBtnRects["friendDel_" .. i]
            if delR and HitRect(delR) then
                local fr = friendsUI.friends[i]
                local name = fr and (fr.nickname or ("鐜╁" .. tostring(fr.userId))) or "?"
                friendsUI.confirmPopup = {
                    type = "delete", targetId = delR.userId,
                    msg = "纭畾鍒犻櫎濂藉弸銆? .. name .. "銆嶏紵"
                }
                PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 鎼滅储杈撳叆妗嗘縺娲?
        if menuBtnRects.friendSearchInput and HitRect(menuBtnRects.friendSearchInput) then
            friendsUI.inputActive = true; input:SetScreenKeyboardVisible(true)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鎼滅储鎸夐挳
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
                    ShowToast("璇疯緭鍏ユ暟瀛桰D")
                end
            else
                ShowToast("璇疯緭鍏ョ帺瀹禝D")
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鎼滅储缁撴灉: 娣诲姞濂藉弸
        if menuBtnRects.friendSearchAdd and HitRect(menuBtnRects.friendSearchAdd) then
            local uid = menuBtnRects.friendSearchAdd.userId
            CloudManager.SendFriendRequest(uid, "")
            playerInfo.totalFriendReqs = (playerInfo.totalFriendReqs or 0) + 1
            ShowToast("濂藉弸璇锋眰宸插彂閫?); PlaySFX(AUDIO.sfx_click); return
        end
        -- 鎺ㄨ崘鐜╁: 娣诲姞
        for i = 1, 20 do
            local recR = menuBtnRects["friendRecAdd_" .. i]
            if recR and HitRect(recR) then
                CloudManager.SendFriendRequest(recR.userId, "")
                playerInfo.totalFriendReqs = (playerInfo.totalFriendReqs or 0) + 1
                ShowToast("濂藉弸璇锋眰宸插彂閫?); PlaySFX(AUDIO.sfx_click); return
            end
        end
        -- 濂藉弸璇锋眰: 鍚屾剰/鎷掔粷
        for i = 1, 50 do
            local accR = menuBtnRects["friendAccept_" .. i]
            if accR and HitRect(accR) then
                CloudManager.AcceptFriendRequest(accR.fromUid)
                playerInfo.totalFriends = (playerInfo.totalFriends or 0) + 1
                ShowToast("宸叉坊鍔犲ソ鍙?)
                friendsUI.reqLoaded = false; friendsUI.reqLoading = false
                friendsUI.loaded = false; friendsUI.loading = false
                friendsUI.pendingReqCount = math.max(0, friendsUI.pendingReqCount - 1)
                friendsUI.lastReqCheckTime = 0
                PlaySFX(AUDIO.sfx_click); return
            end
            local rejR = menuBtnRects["friendReject_" .. i]
            if rejR and HitRect(rejR) then
                CloudManager.RejectFriendRequest(rejR.fromUid)
                ShowToast("宸叉嫆缁?); PlaySFX(AUDIO.sfx_click)
                friendsUI.reqLoaded = false; friendsUI.reqLoading = false
                friendsUI.pendingReqCount = math.max(0, friendsUI.pendingReqCount - 1)
                friendsUI.lastReqCheckTime = 0
                return
            end
        end
        return
    end

    -- ======== 缂栭槦鐣岄潰鐐瑰嚮澶勭悊 ========
    if gameState.phase == "FORMATION" then
        if phaseChangeCooldown > 0 then return end
        local ownedCount = formationUI.ownedCount or GetOwnedHeroCount()
        local canManualEdit = ownedCount >= 10  -- 涓嶆弧10浜虹姝㈡墜鍔ㄨ皟鏁?
        -- 杩斿洖鎸夐挳
        if formationBackBtnRect and HitRect(formationBackBtnRect) then
            PopPhase("MENU"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return
        end
        -- 涓€閿紪闃?
        if formationUI.autoBtnRect and HitRect(formationUI.autoBtnRect) then
            formationUI.ownedCount = AutoFillFormation()
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "宸茶嚜鍔ㄧ紪闃?, 1.5, { 120, 220, 100 }, 16)
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 娓呯┖鎸夐挳 (涓嶆弧10浜烘椂绂佺敤)
        if formationUI.clearBtnRect and HitRect(formationUI.clearBtnRect) then
            if not canManualEdit then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "姝︾伒涓嶈冻10浜? 鏃犳硶璋冩暣缂栭槦", 1.5, { 255, 180, 80 }, 14)
            else
                gameSettings.formation = {}; SaveSettings()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "宸叉竻绌虹紪闃?, 1.5, { 220, 120, 80 }, 16)
            end
            PlaySFX(AUDIO.sfx_click); return
        end
        -- 鍝佽川绛涢€夋爣绛?
        if formationUI.tabRects then
            for _, tr in ipairs(formationUI.tabRects) do
                if HitRect(tr) then
                    formationUI.tab = tr.quality
                    formationUI.scrollY = 0; formationUI.scrollVel = 0
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
        -- 缂栭槦妲界偣鍑?(绉婚櫎姝︾伒, 涓嶆弧10浜烘椂鎻愮ず)
        if formationUI.slotRects then
            for i, sr in ipairs(formationUI.slotRects) do
                if HitRect(sr) and gameSettings.formation[i] then
                    if not canManualEdit then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "姝︾伒涓嶈冻10浜? 鏃犳硶璋冩暣缂栭槦", 1.5, { 255, 180, 80 }, 14)
                    else
                        table.remove(gameSettings.formation, i)
                        SaveSettings()
                    end
                    PlaySFX(AUDIO.sfx_click); return
                end
            end
        end
        -- 鍗＄墝鍒楄〃鍖哄煙: 寮€濮嬫嫋鎷?(鐐瑰嚮鍦?EndPress 澶勭悊)
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
        -- 椤电鍒囨崲 (缁熶竴澶勭悊4涓猅ab)
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
        -- 寮圭獥浜や簰锛堜紭鍏堝鐞嗭級
        if welfareState.rankViewPopup then
            local popup = welfareState.rankViewPopup
            -- 鍏抽棴鎸夐挳
            if popup.closeBtnRect and HitRect(popup.closeBtnRect) then
                welfareState.rankViewPopup = nil
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 澶嶅埗UID鎸夐挳
            if popup.copyBtnRect and HitRect(popup.copyBtnRect) then
                local uidStr = tostring(popup.entry and popup.entry.userId or 0)
                SafeSetClipboard(uidStr)
                popup.copyFlash = 1.5
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "UID宸插鍒? " .. uidStr, 1.2, { 140, 220, 180 }, 14)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鐐瑰嚮寮圭獥澶栭儴鍏抽棴
            if popup.bgRect and not HitRect(popup.bgRect) then
                welfareState.rankViewPopup = nil
                return
            end
            return  -- 寮圭獥鎵撳紑鏃舵嫤鎴墍鏈夌偣鍑?
        end
        -- 鏌ョ湅鎸夐挳鐐瑰嚮锛堥€氳繃 userId 鏌ユ壘锛岄伩鍏嶈繃婊ゅ悗绱㈠紩閿欎綅锛?
        local rankData
        if welfareState.rankTab == "realm" then
            rankData = welfareState.realmRank
        elseif welfareState.rankTab == "dummy" then
            rankData = welfareState.dummyRank
        else rankData = welfareState.powerRank end
        if rankData and welfareState.rankViewBtnRects then
            for i, btnRect in pairs(welfareState.rankViewBtnRects) do
                if btnRect and HitRect(btnRect) and btnRect.userId then
                    -- 閫氳繃 userId 浠庡師濮嬫暟鎹腑绮剧‘鏌ユ壘瀵瑰簲鏉＄洰
                    local entry = nil
                    for _, e in ipairs(rankData) do
                        if e.userId == btnRect.userId then entry = e; break end
                    end
                    if entry then
                        local realmIdx = entry.realmIdx or entry.rankIdx or 1
                        welfareState.rankViewPopup = {
                            entry = {
                                name = entry.name or "鏈煡",
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
        -- 寮€濮嬫嫋鎷芥粴鍔紙鏍规嵁褰撳墠椤电锛?
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

    -- 璐＄尞姒滆鎯呯嫭绔嬬晫闈?
    if gameState.phase == "CONTRIB_RANK" then
        if menuBtnRects.contribRankBack and HitRect(menuBtnRects.contribRankBack) then
            PopPhase("WELFARE")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 寮€濮嬫嫋鎷芥粴鍔?
        welfareState.contribDetailScroll.isDragging = true
        welfareState.contribDetailScroll.dragStartY = dy
        welfareState.contribDetailScroll.dragLastY = dy
        welfareState.contribDetailScroll.vel = 0
        return
    end

    -- 鑳滆礋鐣岄潰鐐瑰嚮杩斿洖棣栭〉
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
        -- 璁板綍鎷栨嫿璧峰浣嶇疆锛堢敤浜庢粴鍔級
        equipCodexState.dragStartY = dy
        equipCodexState.dragLastY = dy
        equipCodexState.isDragging = true
        equipCodexState.scrollVel = 0
        return
    end

    -- === 鍏电绠＄悊鐣岄潰杈撳叆 ===
    if gameState.phase == "SEAL_MGR" then
        -- ====== 浼樺厛绾?1: 鍒嗚В纭寮圭獥 (鏈€楂? ======
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
            return  -- 鍒嗚В纭寮圭獥鎵撳紑鏃跺睆钄藉叾浠栫偣鍑?
        end

        -- ====== 浼樺厛绾?1.5: 鍏电绛涢€夊垎瑙ｇ‘璁ゅ脊绐?======
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
            -- 鍝佽川涓婇檺璋冩暣 鈫?鈫?
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
            -- 瀛斾綅绛涢€夎皟鏁?鈫?鈫?
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
            return  -- 绛涢€夊垎瑙ｅ脊绐楁墦寮€鏃跺睆钄藉叾浠栫偣鍑?
        end

        -- ====== 浼樺厛绾?1.6: 鍏电閫変腑鍒嗚В纭寮圭獥 ======
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
            return  -- 閫変腑鍒嗚В纭寮圭獥灞忚斀鍏朵粬鐐瑰嚮
        end

        -- ====== 浼樺厛绾?2: 鏇挎崲寮圭獥 ======
        if sealReplaceState.show then
            -- 鍏抽棴鎸夐挳
            if sealReplaceBtnRects.close and HitRect(sealReplaceBtnRects.close) then
                sealReplaceState.show = false
                sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鍒楄〃椤规寜閽?
            for _, rects in pairs(sealReplaceListRects) do
                if rects.equip and HitRect(rects.equip) then
                    local invIdx = rects.equip.invIndex
                    local ok = EquipSealFromInventory(invIdx, sealReplaceState.heroIdx, sealReplaceState.slotIdx)
                    if ok then
                        PlaySFX(AUDIO.sfx_click)
                        -- 瑁呭鍚庡叧闂脊绐?
                        sealReplaceState.show = false
                        sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                    end
                    return
                end
                if rects.decompose and HitRect(rects.decompose) then
                    -- 鎵撳紑鍒嗚В纭寮圭獥
                    sealDecomposeState.show = true
                    sealDecomposeState.source = "inventory"
                    sealDecomposeState.invIndex = rects.decompose.invIndex
                    sealDecomposeState.heroIdx = nil
                    sealDecomposeState.slotIdx = nil
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 鏇挎崲寮圭獥鍐呮嫋鎷藉紑濮嬶紙鐢ㄤ簬婊氬姩锛?
            sealReplaceState.scroll.dragStartY = dy
            sealReplaceState.scroll.dragLastY = dy
            sealReplaceState.scroll.isDragging = true
            sealReplaceState.scroll.vel = 0
            return  -- 鏇挎崲寮圭獥鎵撳紑鏃跺睆钄藉叾浠栫偣鍑?
        end

        -- ====== 浼樺厛绾?3: 鍗囩骇闈㈡澘 ======
        if sealMgrState.showLevelUp then
            if sealMgrBtnRects.closeLevelUp and HitRect(sealMgrBtnRects.closeLevelUp) then
                sealMgrState.showLevelUp = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鏇挎崲鎸夐挳 (鍦ㄥ崌绾ч潰鏉夸腑)
            if sealMgrBtnRects.replaceBtn and HitRect(sealMgrBtnRects.replaceBtn) then
                sealReplaceState.show = true
                sealReplaceState.heroIdx = sealMgrState.selectedHero
                sealReplaceState.slotIdx = sealMgrState.selectedSlot
                sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鍒嗚В鎸夐挳 (鍦ㄥ崌绾ч潰鏉夸腑)
            if sealMgrBtnRects.decomposeBtn and HitRect(sealMgrBtnRects.decomposeBtn) then
                sealDecomposeState.show = true
                sealDecomposeState.source = "equipped"
                sealDecomposeState.invIndex = nil
                sealDecomposeState.heroIdx = sealMgrState.selectedHero
                sealDecomposeState.slotIdx = sealMgrState.selectedSlot
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 缁忛獙閬撳叿浣跨敤鎸夐挳
            for idx, rect in pairs(sealMgrExpItemRects) do
                if HitRect(rect) then
                    local ok = UseSealExpItem(sealMgrState.selectedHero, sealMgrState.selectedSlot, idx)
                    if ok then
                        PlaySFX(AUDIO.sfx_click)
                        SaveGameProgress()
                    else
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "鏃犳硶浣跨敤!", 1.0, { 255, 100, 100 }, 14)
                    end
                    return
                end
            end
            -- 涓€閿绾у己鍖栨寜閽?
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
                        sealBatchTarget = nil  -- 閲嶇疆
                    else
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, msg or "鍗囩骇澶辫触", 1.0, { 255, 100, 100 }, 14)
                    end
                end
                return
            end
            return  -- 鍗囩骇闈㈡澘鎵撳紑鏃跺睆钄藉叾浠栫偣鍑?
        end

        -- ====== 杩斿洖鎸夐挳 ======
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

        -- ====== 閫変腑鍒嗚В妯″紡涓嬬殑浜や簰 ======
        if sealInvFilterState.selectMode then
            -- 鍏ㄩ€夋寜閽?
            if sealInvFilterBtnRects.selectAll and HitRect(sealInvFilterBtnRects.selectAll) then
                for i = 1, #sealInventory do
                    sealInvFilterState.selectedIds[i] = true
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 纭鍒嗚В鎸夐挳
            if sealInvFilterBtnRects.selectDoDecomp and HitRect(sealInvFilterBtnRects.selectDoDecomp) then
                local selCount = 0
                for _ in pairs(sealInvFilterState.selectedIds) do selCount = selCount + 1 end
                if selCount > 0 then
                    sealInvFilterState.selectConfirmShow = true
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鍙栨秷鎸夐挳
            if sealInvFilterBtnRects.selectCancelMode and HitRect(sealInvFilterBtnRects.selectCancelMode) then
                sealInvFilterState.selectMode = false
                sealInvFilterState.selectedIds = {}
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鍒楄〃鍖哄煙锛氬惎鍔ㄦ嫋鎷斤紙鐭寜鍒囨崲閫変腑鍦?EndPress 鍒ゅ畾锛?
            sealMgrScroll.dragStartY = dy
            sealMgrScroll.dragLastY = dy
            sealMgrScroll.isDragging = true
            sealMgrScroll.vel = 0
            return  -- 閫変腑妯″紡灞忚斀鍏朵粬鐐瑰嚮
        end

        -- ====== 绛涢€夊垎瑙ｆ寜閽?======
        if sealInvFilterBtnRects.batchDecompBtn and HitRect(sealInvFilterBtnRects.batchDecompBtn) then
            sealInvFilterState.batchConfirmShow = true
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- ====== 閫変腑鍒嗚В鎸夐挳 ======
        if sealInvFilterBtnRects.selectDecompBtn and HitRect(sealInvFilterBtnRects.selectDecompBtn) then
            sealInvFilterState.selectMode = true
            sealInvFilterState.selectedIds = {}
            sealMgrScroll.y = 0
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "鐐瑰嚮閫変腑瑕佸垎瑙ｇ殑鍏电", 1.0, { 100, 180, 255 }, 16)
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- ====== 浠撳簱鍏ュ彛鎸夐挳 ======
        if sealMgrBtnRects.inventoryBtn and HitRect(sealMgrBtnRects.inventoryBtn) then
            -- 鎵撳紑浠撳簱寮圭獥 (鏄剧ず褰撳墠閫変腑鑻遍泟鐨勭涓€涓彲鐢ㄥ瓟浣? 鎴栧叏閮?
            local heroIdx = sealMgrState.selectedHero
            if heroIdx then
                sealReplaceState.show = true
                sealReplaceState.heroIdx = heroIdx
                -- 濡傛灉鏈夐€変腑瀛斾綅灏辩敤閫変腑鐨勶紝鍚﹀垯鐢ㄧ涓€涓瓟浣?
                sealReplaceState.slotIdx = sealMgrState.selectedSlot or 1
                sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end

        -- ====== 鑻遍泟閫夋嫨寮圭獥 ======
        if sealMgrState.showHeroPicker then
            if sealMgrBtnRects.closeHeroPicker and HitRect(sealMgrBtnRects.closeHeroPicker) then
                sealMgrState.showHeroPicker = false
                heroPickerScroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false, contentH = 0, viewH = 0 }
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 寮圭獥鍐呮嫋鎷藉紑濮嬶紙鐭寜閫変腑鑻遍泟鍦?EndPress 鍒ゅ畾锛?
            heroPickerScroll.dragStartY = dy
            heroPickerScroll.dragLastY = dy
            heroPickerScroll.isDragging = true
            heroPickerScroll.vel = 0
            return  -- 鑻遍泟閫夋嫨寮圭獥鎵撳紑鏃跺睆钄藉叾浠栫偣鍑?
        end

        -- ====== 涓績鍗＄墝鐐瑰嚮 鈫?鑻遍泟閫夋嫨 ======
        if sealMgrBtnRects.centerCard and HitRect(sealMgrBtnRects.centerCard) then
            local maxHeroes = GetMaxConstellationHeroes()
            if #maxHeroes > 1 then
                sealMgrState.showHeroPicker = true
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end

        -- ====== 瀛斾綅鐐瑰嚮 鈫?鎵撳紑鍗囩骇闈㈡澘 ======
        for slotIdx, rect in pairs(sealMgrSlotRects) do
            if HitRect(rect) then
                local cardIdx = sealMgrState.selectedHero
                if cardIdx then
                    sealMgrState.selectedSlot = slotIdx
                    if sealData[cardIdx] and sealData[cardIdx].slots and sealData[cardIdx].slots[slotIdx] then
                        -- 宸叉湁鍏电 鈫?鎵撳紑鍗囩骇闈㈡澘
                        sealMgrState.showLevelUp = true
                    else
                        -- 绌哄瓟浣?鈫?鐩存帴鎵撳紑鏇挎崲寮圭獥(瑁呭)
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

    -- === 鎼滄墦鎾ゆ帰绱㈢晫闈㈣緭鍏?=== [EXPLORATION REMOVED]
    -- if gameState.phase == "EXPLORATION" then
    --     Exploration.HandlePress(dx, dy)
    --     return
    -- end

    if gameState.phase == "WORLD_MAP" then
        -- 琛屽啗鍔ㄧ敾鏈熼棿灞忚斀杈撳叆
        if rawget(_G, "WorldMap") and WorldMap.IsMarchActive and WorldMap.IsMarchActive() then
            return
        end
        -- 鏂版墜寮曞浼樺厛鎷︽埅杈撳叆
        if WorldMap.HandleGuideInput(dx, dy) then
            return
        end
        -- 鍥炲悎鎶ュ憡鎷栨嫿婊氬姩: 璁板綍璧峰Y
        if worldMapState.phase == "TURN_REPORT" then
            worldMapState.reportDragging = true
            worldMapState.reportDragLastY = dy
        end
        -- 鍩庢睜鍒楄〃鎷栨嫿婊氬姩: 璁板綍璧峰Y (宸︿晶230px鍖哄煙)
        if dx < 230 then
            worldMapState.cityListDragging = true
            worldMapState.cityListDragStartY = dy
            worldMapState.cityListDragLastY = dy
        end
        WorldMap.HandleInput(dx, dy)
        return
    end

    if gameState.phase == "STAGE_SELECT" then
        -- 鐖嗚寮圭獥鍏抽棴
        if stageState.showDropPopup then
            if stageDropCloseRect and HitRect(stageDropCloseRect) then
                stageState.showDropPopup = false
                stageState.lastDropReward = nil
                return
            end
            return  -- 寮圭獥鎵撳紑鏃跺睆钄藉叾浠栫偣鍑?
        end
        -- 棰勮寮圭獥
        if stageState.showPreview then
            if stagePreviewCloseRect and HitRect(stagePreviewCloseRect) then
                stageState.showPreview = false
                return
            end
            if stageStartBtnRect and HitRect(stageStartBtnRect) then
                -- 寮€濮嬫帰绱?(鎼滄墦鎾ゆā寮?
                local stageIdx = stageState.currentStage
                local stage = STAGES[stageIdx]
                stageMaxTier = stage.maxTier or 1
                stageState.showPreview = false
                -- [EXPLORATION REMOVED] 鎺㈢储妯″潡宸茬Щ闄?
                PlaySFX(AUDIO.sfx_click)
                return
                --[=[ EXPLORATION REMOVED: 浠ヤ笅鎺㈢储浠ｇ爜宸叉敞閲?

                -- 鍒濆鍖栨帰绱㈡ā鍧?(棣栨)
                if not Exploration.IsActive() then
                    Exploration.Init(vg, fontId, IMG)
                end

                SyncPlayerDataToExploration()

                -- 閰嶇疆鎺㈢储鍦板浘
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

                -- 璁剧疆鍥炶皟
                Exploration.onStartBattle = function(enemyScale, maxTier, dropSets)
                    -- 浠庢帰绱㈣繘鍏ユ垬鏂?
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
                    -- 搴旂敤鎺㈢储澧炵泭
                    local buff = Exploration.GetBuff()
                    gameState.exploreBuff = buff  -- 瀛樺偍渚?AggregateBaseStats 浣跨敤
                    if buff then
                        if buff.type == "hp_bonus" then
                            gameState.playerBaseHP = BASE_HP_MAX + buff.value
                            gameState.playerBaseMax = BASE_HP_MAX + buff.value
                        end
                    end
                    -- 鏁屾柟閮ㄧ讲 (鎸夋晫浜鸿妯¤皟鏁?
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
                    print("=== 鎺㈢储鎴樻枟寮€濮?(鍏冲崱: " .. stage.name .. ") ===")
                end

                Exploration.onComplete = function(result)
                    -- 鎺㈢储瀹屾垚鍥炶皟: 鍙戞斁濂栧姳
                    if result then
                        if result.success then
                            playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                        end
                        local jadeReward = result.totalJade or 0
                        if exploreAdDoubleJade then
                            jadeReward = jadeReward * 2
                            exploreAdDoubleJade = false
                        end
                        result.totalJade = jadeReward  -- 鏇存柊鐢ㄤ簬鍚庣画鏄剧ず
                        playerInfo.jade = playerInfo.jade + jadeReward
                        -- 鎸夋鎶€鍒嗛厤娈嬬墖
                        if result.fragList then
                            for _, fi in ipairs(result.fragList) do
                                skillFragments[fi.skillIdx] = (skillFragments[fi.skillIdx] or 0) + fi.count
                            end
                        elseif (result.totalFrag or 0) > 0 then
                            -- 鍏煎鏃ф暟鎹? 闅忔満鍒嗛厤
                            for _ = 1, result.totalFrag do
                                local idx = math.random(1, #SKILL_TECHNIQUES)
                                skillFragments[idx] = (skillFragments[idx] or 0) + 1
                            end
                        end
                        -- 瑁呭鎺夎惤锛氱洿鎺ヤ娇鐢ㄦ帰绱腑宸茬‘瀹氱殑鍝佺骇/濂楄/閮ㄤ綅锛堜繚璇佹樉绀轰笌瀹為檯涓€鑷达級
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
                        -- 鏄剧ず瑁呭鎺夎惤閫氱煡锛堟瘡浠跺崟鐙彁绀猴紝鍛婄煡鍝侀樁銆佹Ы浣嶅拰鍝佽川锛?
                        for i, eqDrop in ipairs(equipDrops) do
                            local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "鏈煡"
                            local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "鏈煡"
                            local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                            local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255, 255, 255}
                            local qLabel = GetQualityLabel(eqDrop.quality or 0)
                            local eLv = eqDrop.level or 1
                            local dropMsg = "鑾峰緱鍏电敳: " .. tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i - 1) * 30, dropMsg, 3.0, tc, 20)
                        end
                        -- 鍘嗗姭妯″紡: 鏄熺骇濂栧姳 + 鍏冲崱瑙ｉ攣
                        if result.mode == "stage" and result.success then
                            local si = result.stageIdx
                            local key = tostring(si)
                            -- 璁＄畻鏄熺骇 (鍩轰簬鍩哄湴HP)
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
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "鈽? .. earnedStars .. " 鏄熺骇濂栧姳: +" .. totalJadeReward .. " 铏庣", 2.0, {255, 220, 80}, 20)
                                end
                            end
                            if si >= stageState.maxUnlocked and si < #STAGES then
                                stageState.maxUnlocked = si + 1
                            end
                        end
                        -- 璁ㄤ紣妯″紡: 璁板綍閫氬叧
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
                            local rewardStr = "鎺㈢储缁撴潫: +" .. (result.totalJade or 0) .. " 铏庣"
                            if result.fragList and #result.fragList > 0 then
                                local totalF = 0
                                for _, fi in ipairs(result.fragList) do totalF = totalF + fi.count end
                                rewardStr = rewardStr .. " +" .. totalF .. "姝︽妧娈嬬墖"
                            end
                            if #equipDrops > 0 then
                                rewardStr = rewardStr .. " +" .. #equipDrops .. "浠跺叺鐢?
                            end
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, rewardStr, 2.0, {255, 220, 80}, 22)
                        else
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鎺㈢储鏀惧純, 鏈幏寰楀鍔?, 2.0, {180, 180, 180}, 18)
                        end
                        -- 鎴樹护: 鎺㈢储瀹屾垚 (浠呮垚鍔?鎾ょ鏃惰拷韪? 鏀惧純涓嶇畻)
                        if result.success then
                            TrackBattlePassTask("bp_explore1", 1)
                            TrackBattlePassTask("bp_wexplore5", 1)
                            TrackBattlePassTask("bp_sexplore15", 1)
                        end
                    end
                    gameState.explorationMode = false
                    gameState.noFullAuto = false  -- 绂诲紑鎺㈢储, 鎭㈠鍏ㄨ嚜鍔ㄥ彲鐢?
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
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣宸茬炕鍊?", 1.5, { 120, 255, 180 }, 18)
                                if callback then callback(true) end
                            else
                                if callback then callback(false) end
                            end
                        end))
                    else
                        ReportAdWatch()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣宸茬炕鍊?", 1.5, { 120, 255, 180 }, 18)
                        if callback then callback(true) end
                    end
                end

                PushPhase("EXPLORATION")
                PlaySFX(AUDIO.sfx_click)
                print("=== 寮€濮嬫帰绱? " .. stage.name .. " (" .. gs .. "脳" .. gs .. ") ===")
                return
                --]=] -- END EXPLORATION REMOVED (STAGE_SELECT)
            end
            return
        end
        -- 杩斿洖鎸夐挳
        if stageBackBtnRect and HitRect(stageBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            return
        end
        -- 缈婚〉鎸夐挳
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
        -- 瀹濈鐐瑰嚮
        for ci, cRect in ipairs(stageChestRects) do
            if cRect and HitRect(cRect) then
                local chestKey = tostring(cRect.page) .. "_" .. tostring(cRect.threshold)
                local pageStars = GetPageStars(cRect.page)
                if pageStars >= cRect.threshold and not stageChestClaimed[chestKey] then
                    stageChestClaimed[chestKey] = true
                    local reward = STAGE_CHEST_REWARDS[ci]
                    if reward then
                        GrantRewardTable(reward)
                        local msg = "瀹濈濂栧姳: +" .. reward.jade .. " 铏庣"
                        if reward.frag and reward.frag > 0 then
                            msg = msg .. " +" .. reward.frag .. " 姝︽妧娈嬬墖"
                        end
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, msg, 2.0, {255, 220, 80}, 20)
                    end
                    PlaySFX(AUDIO.sfx_click)
                    SaveGameProgress()
                else
                    if stageChestClaimed[chestKey] then
                        ShowToast("宸查鍙?)
                    else
                        ShowToast("闇€瑕?" .. cRect.threshold .. " 鏄熸墠鑳介鍙?)
                    end
                end
                return
            end
        end
        -- 鍏冲崱鑺傜偣鐐瑰嚮 (stageNodeRects 鐜板湪鎼哄甫 stageIdx)
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

    -- === 姣忔棩鍓湰鐣岄潰杈撳叆 ===
    if gameState.phase == "DAILY_DUNGEON" then
        if phaseChangeCooldown > 0 then return end

        -- 纭寮圭獥
        if dailyDungeonState.showConfirm then
            -- 鍏抽棴
            if dailyDungeonCloseRect and HitRect(dailyDungeonCloseRect) then
                dailyDungeonState.showConfirm = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 鍓湰2: 濂楄閫夋嫨鎸夐挳
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
            -- 娑堣€楄檸绗﹁繘鍏ユ寜閽?
            if dailyDungeonConfirmBtnRect and HitRect(dailyDungeonConfirmBtnRect) then
                if not di or dailyDungeonState.completed[di] then return end
                PlaySFX(AUDIO.sfx_click)

                local function EnterDailyDungeon()
                    -- [EXPLORATION REMOVED] 鎺㈢储妯″潡宸茬Щ闄?
                    dailyDungeonState.showConfirm = false
                    ShowToast("鎺㈢储鍔熻兘鏆傛湭寮€鏀?)
                    return
                    --[=[ EXPLORATION REMOVED: 浠ヤ笅鎺㈢储浠ｇ爜宸叉敞閲?
                    SaveGameProgress()

                    -- 鍒濆鍖栨帰绱㈡ā鍧?
                    if not Exploration.IsActive() then
                        Exploration.Init(vg, fontId, IMG)
                    end
                    SyncPlayerDataToExploration()

                    -- 鍓湰閰嶇疆
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

                    -- 鎴樻枟鍥炶皟
                    Exploration.onStartBattle = function(enemyScale, maxTier, dropSets)
                        gameState.explorationMode = true
                        gameState.noFullAuto = true   -- 姣忔棩鍓湰绂佹鍏ㄨ嚜鍔?
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
                        -- 鏁屾柟鎴樺姏鍖归厤鐜╁褰撳墠鎴樺姏
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
                        print("=== 姣忔棩鍓湰鎴樻枟 (绫诲瀷" .. di .. ") ===")
                    end

                    Exploration.onComplete = function(result)
                        if result then
                            if result.success then
                                dailyDungeonState.completed[di] = true  -- 鍙湁璧版挙绂婚€氶亾鎵嶆爣璁伴€氬叧
                                playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                            end
                            local jadeReward = result.totalJade or 0
                            if exploreAdDoubleJade then
                                jadeReward = jadeReward * 2
                                exploreAdDoubleJade = false
                            end
                            result.totalJade = jadeReward  -- 鏇存柊鐢ㄤ簬鍚庣画鏄剧ず
                            playerInfo.jade = playerInfo.jade + jadeReward
                            if result.fragList then
                                for _, fItem in ipairs(result.fragList) do
                                    skillFragments[fItem.skillIdx] = (skillFragments[fItem.skillIdx] or 0) + fItem.count
                                end
                            end
                            -- 姣忔棩鍓湰涓撳睘鎺夎惤閫昏緫
                            local ddEquipDrops = {}
                            if result.equipCount and result.equipCount > 0 then
                                for _, loot in ipairs(result.loot) do
                                    if loot.hasEquipment then
                                        local tier = loot.equipTier or 2
                                        local si = loot.equipSet or math.random(1, #EQUIPMENT_SETS)
                                        local pi = loot.equipSlotIdx or math.random(1, 7)
                                        -- 鍓湰1: 寮哄埗鎸囧畾閮ㄤ綅
                                        if di == 1 then
                                            pi = dailyDungeonState.todaySlot
                                        end
                                        -- 鍓湰2: 寮哄埗鎸囧畾濂楄
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
                            -- 淇濆簳: 姣忎釜鍓湰鑷冲皯鎺?浠惰澶?(浠呮垚鍔?鎾ょ鏃惰Е鍙? 鏀惧純涓嶄繚搴?
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
                                    local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "鏈煡"
                                    local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "鏈煡"
                                    local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                                    local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255,255,255}
                                    local qLabel = GetQualityLabel(eqDrop.quality or 0)
                                    local eLv = eqDrop.level or 1
                                    local dropMsg = tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i - 1) * 30, dropMsg, 3.0, tc, 20)
                                end
                                local ddStr = "鍓湰瀹屾垚: +" .. #ddEquipDrops .. "浠跺叺鐢?
                                if jadeReward > 0 then ddStr = ddStr .. " +" .. jadeReward .. " 铏庣" end
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, ddStr, 2.5, {80, 220, 160}, 22)
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍓湰鏀惧純, 鏈幏寰楀鍔?, 2.0, {180, 180, 180}, 18)
                            end
                        end
                        gameState.explorationMode = false
                        gameState.noFullAuto = false  -- 绂诲紑鍓湰, 鎭㈠鍏ㄨ嚜鍔ㄥ彲鐢?
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
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣宸茬炕鍊?", 1.5, {120,255,180}, 18)
                                    if callback then callback(true) end
                                else
                                    if callback then callback(false) end
                                end
                            end))
                        else
                            ReportAdWatch()
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣宸茬炕鍊?", 1.5, {120,255,180}, 18)
                            if callback then callback(true) end
                        end
                    end

                    PushPhase("EXPLORATION")
                    PlaySFX(AUDIO.sfx_click)
                    print("=== 寮€濮嬫瘡鏃ュ壇鏈? .. di .. ": " .. DAILY_DUNGEON_NAMES[di] .. " (5脳5) ===")
                    --]=] -- END EXPLORATION REMOVED (DAILY_DUNGEON)
                end

                -- 鎵ｉ櫎300铏庣鍏ュ満
                local DUNGEON_ENTRY_COST = 300
                if playerInfo.jade >= DUNGEON_ENTRY_COST then
                    playerInfo.jade = playerInfo.jade - DUNGEON_ENTRY_COST
                    EnterDailyDungeon()
                else
                    ShowToast("铏庣涓嶈冻锛岄渶瑕?" .. DUNGEON_ENTRY_COST .. " 铏庣", 2.0)
                end
                return
            end
            return
        end

        -- 杩斿洖鎸夐挳
        if dailyDungeonBackRect and HitRect(dailyDungeonBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 鍓湰鍗＄墖鐐瑰嚮
        for di = 1, 3 do
            if dailyDungeonCardRects[di] and HitRect(dailyDungeonCardRects[di]) then
                if dailyDungeonState.completed[di] then
                    ShowToast("浠婃棩宸插畬鎴愭鍓湰")
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

    -- === 鎺㈢储璧勬簮鍓湰鐣岄潰杈撳叆 ===
    if gameState.phase == "RESOURCE_DUNGEON" then
        if phaseChangeCooldown > 0 then return end

        -- 纭寮圭獥
        if resourceDungeonState.showConfirm then
            -- 鍏抽棴鎸夐挳
            if resourceDungeonConfirmRect and resourceDungeonConfirmRect.close and HitRect(resourceDungeonConfirmRect.close) then
                resourceDungeonState.showConfirm = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 纭杩涘叆鎸夐挳
            if resourceDungeonConfirmRect and resourceDungeonConfirmRect.enter and HitRect(resourceDungeonConfirmRect.enter) then
                local ti = resourceDungeonState.selectedType
                if not ti or resourceDungeonState.completed[ti] then return end
                local rdCfg = GameConfig.RESOURCE_DUNGEON
                local typeInfo = rdCfg.types[ti]
                if not typeInfo then return end
                -- 妫€鏌ヨ檸绗?
                if playerInfo.jade < rdCfg.entryCost then
                    ShowToast("铏庣涓嶈冻! 闇€瑕?" .. rdCfg.entryCost .. " 铏庣")
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                PlaySFX(AUDIO.sfx_click)

                local function EnterResourceDungeon()
                    -- [EXPLORATION REMOVED] 鎺㈢储妯″潡宸茬Щ闄?
                    resourceDungeonState.showConfirm = false
                    ShowToast("鎺㈢储鍔熻兘鏆傛湭寮€鏀?)
                    return
                    --[=[ EXPLORATION REMOVED: 浠ヤ笅鎺㈢储浠ｇ爜宸叉敞閲?
                    -- 鎵ｉ櫎闂ㄧエ
                    playerInfo.jade = playerInfo.jade - rdCfg.entryCost
                    resourceDungeonState.showConfirm = false
                    -- 涓嶇珛鍗虫爣璁板畬鎴? 閫氬叧鎵嶇畻
                    SaveGameProgress()

                    -- 鍒濆鍖栨帰绱㈡ā鍧?
                    if not Exploration.IsActive() then
                        Exploration.Init(vg, fontId, IMG)
                    end
                    SyncPlayerDataToExploration()

                    -- 鍓湰閰嶇疆: 閬亣鎴樻ā寮?
                    local eScale = 1.0 + (playerInfo.rankIdx or 1) * 0.15
                    local ppTotal = CalcPlayerTotalPower()
                    -- 鐣ラ珮浜庣帺瀹舵垬鍔?
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
                        -- 閬亣鎴樻ā寮忓弬鏁?
                        encounterMode = true,
                        encounterRate = rdCfg.encounterRate,
                        enemyDensityOverride = rdCfg.enemyDensity,
                        chestCountOverride = rdCfg.chestCount,
                        blockedRatioOverride = rdCfg.blockedRatio,
                        eventRatioOverride = rdCfg.eventRatio,
                        chestGuardOverride = rdCfg.chestGuardChance,
                    })

                    -- 鎴樻枟鍥炶皟
                    Exploration.onStartBattle = function(enemyScale2, maxTier2, dropSets2)
                        gameState.explorationMode = true
                        gameState.noFullAuto = true   -- 鎺㈢储鍓湰绂佹鍏ㄨ嚜鍔?
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
                        -- 鏁屾柟鍗曚綅
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
                        -- 鏁屾柟鎴樺姏鍖归厤鐜╁褰撳墠鎴樺姏 (鐣ラ珮)
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
                        print("=== 鎺㈢储鍓湰鎴樻枟 (" .. typeInfo.name .. ") ===")
                    end

                    Exploration.onComplete = function(result)
                        if result then
                            -- 鍙湁鎾ょ鎴愬姛鎵嶆爣璁伴€氬叧 (閫€鍑?0鏀剁泭涓嶇畻瀹屾垚)
                            if result.success then
                                resourceDungeonState.completed[ti] = true
                                playerInfo.totalExplores = (playerInfo.totalExplores or 0) + 1
                            end
                            local jadeReward = result.totalJade or 0
                            if exploreAdDoubleJade then
                                jadeReward = jadeReward * 2
                                exploreAdDoubleJade = false
                            end
                            result.totalJade = jadeReward  -- 鏇存柊鐢ㄤ簬鍚庣画鏄剧ず
                            playerInfo.jade = playerInfo.jade + jadeReward
                            if result.fragList then
                                for _, fItem in ipairs(result.fragList) do
                                    skillFragments[fItem.skillIdx] = (skillFragments[fItem.skillIdx] or 0) + fItem.count
                                end
                            end
                            -- 鎺㈢储鍓湰涓撳睘鎺夎惤
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
                            -- 淇濆簳: 鑷冲皯鎺?浠惰澶?(浠呮垚鍔?鎾ょ鏃惰Е鍙? 鏀惧純涓嶄繚搴?
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
                                    local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "鏈煡"
                                    local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "鏈煡"
                                    local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                                    local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255,255,255}
                                    local qLabel = GetQualityLabel(eqDrop.quality or 0)
                                    local eLv = eqDrop.level or 1
                                    local dropMsg = tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4 + (i2 - 1) * 30, dropMsg, 3.0, tc, 20)
                                end
                                local rdStr = typeInfo.name .. "瀹屾垚: +" .. #rdEquipDrops .. "浠跺叺鐢?
                                if jadeReward > 0 then rdStr = rdStr .. " +" .. jadeReward .. " 铏庣" end
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, rdStr, 2.5, {typeInfo.color[1], typeInfo.color[2], typeInfo.color[3]}, 22)
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鎺㈢储鏀惧純, 鏈幏寰楀鍔?, 2.0, {180, 180, 180}, 18)
                            end
                        end
                        -- 鎴樹护: 鎺㈢储瀹屾垚 (浠呮垚鍔?鎾ょ鏃惰拷韪? 鏀惧純涓嶇畻)
                        if result and result.success then
                            TrackBattlePassTask("bp_explore1", 1)
                            TrackBattlePassTask("bp_wexplore5", 1)
                            TrackBattlePassTask("bp_sexplore15", 1)
                        end
                        gameState.explorationMode = false
                        gameState.noFullAuto = false  -- 绂诲紑鎺㈢储, 鎭㈠鍏ㄨ嚜鍔ㄥ彲鐢?
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
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣宸茬炕鍊?", 1.5, {120,255,180}, 18)
                                    if callback then callback(true) end
                                else
                                    if callback then callback(false) end
                                end
                            end))
                        else
                            ReportAdWatch()
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣宸茬炕鍊?", 1.5, {120,255,180}, 18)
                            if callback then callback(true) end
                        end
                    end

                    PushPhase("EXPLORATION")
                    PlaySFX(AUDIO.sfx_click)
                    print("=== 寮€濮嬫帰绱㈠壇鏈? " .. typeInfo.name .. " (7脳7 閬亣鎴? ===")
                    --]=] -- END EXPLORATION REMOVED (RESOURCE_DUNGEON)
                end

                -- 鐩存帴杩涘叆 (闂ㄧエ鍒? 闈炲箍鍛婂埗)
                EnterResourceDungeon()
                return
            end
            return
        end

        -- 杩斿洖鎸夐挳
        if resourceDungeonBackRect and HitRect(resourceDungeonBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 鍓湰绫诲瀷鍗＄墖鐐瑰嚮
        for di = 1, 3 do
            if resourceDungeonCardRects[di] and HitRect(resourceDungeonCardRects[di]) then
                if resourceDungeonState.completed[di] then
                    ShowToast("浠婃棩宸插畬鎴愭鎺㈢储")
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

    -- === 鎴樹护閫氳璇佺晫闈㈣緭鍏?===
    if gameState.phase == "BATTLE_PASS" then
        if phaseChangeCooldown > 0 then return end

        -- 杩斿洖鎸夐挳
        if battlePassBackRect and HitRect(battlePassBackRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- Tab 鍒囨崲
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

        -- Tab 1: 濂栧姳鎬昏 - 棰嗗彇鎸夐挳
        if battlePassUIState.tab == 1 then
            -- 楂樼骇濂栧姳棰嗗彇锛堢湅骞垮憡 / 鍏嶅箍鍛婄壒鏉冪洿鎺ラ鍙栵級
            for lv, rect in pairs(battlePassClaimPremiumRects) do
                if HitRect(rect) then
                    if playerInfo.ad_free then
                        -- 鍏嶅箍鍛婄壒鏉? 鐩存帴棰嗗彇
                        if ClaimBattlePassPremiumReward(lv) then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍏嶅箍鍛婄洿鎺ラ鍙?", 1.5, { 100, 255, 200 }, 18)
                        end
                    elseif sdk then
                        local capturedLv = lv
                        ShowAdSafe(SafeAdCallback(function(result)
                            if result.success then
                                ReportAdWatch()
                                if ClaimBattlePassPremiumReward(capturedLv) then
                                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "楂樼骇濂栧姳宸查鍙?", 1.5, { 255, 220, 100 }, 18)
                                end
                            else
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "骞垮憡鎾斁澶辫触", 1.5, { 255, 120, 80 }, 16)
                            end
                        end))
                    else
                        ReportAdWatch()
                        if ClaimBattlePassPremiumReward(lv) then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "楂樼骇濂栧姳宸查鍙?", 1.5, { 255, 220, 100 }, 18)
                        end
                    end
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 鏅€氬鍔遍鍙栵紙鍏嶈垂锛?
            for lv, rect in pairs(battlePassClaimFreeRects) do
                if HitRect(rect) then
                    if ClaimBattlePassFreeReward(lv) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "濂栧姳宸查鍙?", 1.5, { 120, 255, 180 }, 18)
                    end
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 妯悜鎷栨嫿婊氬姩锛堝鍔辫建閬擄級
            battlePassUIState.isDraggingReward = true
            battlePassUIState.dragStartX = dx
            battlePassUIState.dragStartScrollX = battlePassUIState.rewardScrollX
            return
        end

        -- Tab 2/3/4: 浠诲姟鍒楄〃 - 棰嗗彇鎸夐挳
        for _, btnInfo in ipairs(battlePassTaskBtnRects) do
            if HitRect(btnInfo) then
                ClaimBattlePassTaskReward(btnInfo.taskType, btnInfo.taskId)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 绾靛悜鎷栨嫿婊氬姩锛堜换鍔″垪琛級
        battlePassUIState.isDragging = true
        battlePassUIState.dragStartY = dy
        battlePassUIState.dragLastY = dy
        battlePassUIState.scrollVel = 0
        return
    end

    -- === 璁ㄤ紣鎴樼晫闈㈣緭鍏?===
    if gameState.phase == "ABYSS_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 棰勮寮圭獥
        if abyssState.showPreview then
            if abyssState.previewCloseRect and HitRect(abyssState.previewCloseRect) then
                abyssState.showPreview = false
                return
            end
            if abyssState.startBtnRect and HitRect(abyssState.startBtnRect) then
                -- 璁ㄤ紣鍏ュ満璐癸細100铏庣
                local ABYSS_COST = 100
                if playerInfo.jade < ABYSS_COST then
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "铏庣涓嶈冻! 闇€瑕? .. ABYSS_COST .. " 铏庣", 1.5, { 255, 80, 80 }, 18)
                    return
                end
                -- 鎵ｉ櫎铏庣
                playerInfo.jade = playerInfo.jade - ABYSS_COST
                SaveGameProgress()

                -- 璁ㄤ紣鎺㈢储妯″紡 (鎼滄墦鎾?
                local fi = abyssState.selectedFloor
                abyssState.showPreview = false

                -- 闅忔満鍦板浘澶у皬 (4~8)
                local abyssGridSizes = {4, 5, 5, 6, 6, 7, 8}
                local gs = abyssGridSizes[fi] or math.random(4, 8)

                -- 灏嗗搧鍙婁互涓婃鐜囦负鏅€氭帰绱㈢殑3鍊?
                local highTierMul = 3

                -- [EXPLORATION REMOVED] 鎺㈢储妯″潡宸茬Щ闄?
                ShowToast("鎺㈢储鍔熻兘鏆傛湭寮€鏀?)
                return
                --[=[ EXPLORATION REMOVED: 浠ヤ笅鎺㈢储浠ｇ爜宸叉敞閲?

                -- 鍒濆鍖栨帰绱㈡ā鍧?
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

                -- 璁剧疆鍥炶皟 (涓庡巻鍔叡鐢?onComplete, 浣嗘爣璁颁负 abyss)
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
                    -- 搴旂敤鎺㈢储澧炵泭
                    local buff = Exploration.GetBuff()
                    gameState.exploreBuff = buff
                    if buff then
                        if buff.type == "hp_bonus" then
                            gameState.playerBaseHP = BASE_HP_MAX + buff.value
                            gameState.playerBaseMax = BASE_HP_MAX + buff.value
                        end
                    end
                    -- 鏁屾柟閮ㄧ讲
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
                    InitAISkills()  -- 璁ㄤ紣妯″紡鍚敤AI鎶€鑳?
                    print("=== 璁ㄤ紣鎺㈢储鎴樻枟 绗? .. fi .. "灞?===")
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
                        -- 鎸夋鎶€鍒嗛厤娈嬬墖
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
                        -- 鏄剧ず瑁呭鎺夎惤閫氱煡锛堝惈鍝佽川+瑁呯瓑锛?
                        for i, eqDrop in ipairs(abEquipDrops) do
                            local tierName = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].name or "鏈煡"
                            local slotName = EQUIP_SLOT_NAMES[eqDrop.slotIdx] or "鏈煡"
                            local setName = EQUIPMENT_SETS[eqDrop.setIdx] and EQUIPMENT_SETS[eqDrop.setIdx].name or ""
                            local tc = EQUIP_TIERS[eqDrop.tier] and EQUIP_TIERS[eqDrop.tier].color or {255, 255, 255}
                            local qLabel = GetQualityLabel(eqDrop.quality or 0)
                            local eLv = eqDrop.level or 1
                            local dropMsg = "鑾峰緱鍏电敳: " .. tierName .. " " .. setName .. " [" .. slotName .. "] Lv." .. eLv .. " " .. qLabel .. eqDrop.quality .. "%"
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
                        local abRewardStr = "璁ㄤ紣鎺㈢储: +" .. (result.totalJade or 0) .. " 铏庣"
                        if result.fragList and #result.fragList > 0 then
                            local totalF = 0
                            for _, fItem in ipairs(result.fragList) do totalF = totalF + fItem.count end
                            abRewardStr = abRewardStr .. " +" .. totalF .. "姝︽妧娈嬬墖"
                        end
                        if #abEquipDrops > 0 then
                            abRewardStr = abRewardStr .. " +" .. #abEquipDrops .. "浠跺叺鐢?
                        end
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, abRewardStr, 2.5, {180, 120, 255}, 22)
                    end
                    -- 鎴樹护: 鎺㈢储瀹屾垚
                    TrackBattlePassTask("bp_explore1", 1)
                    TrackBattlePassTask("bp_wexplore5", 1)
                    TrackBattlePassTask("bp_sexplore15", 1)
                    gameState.explorationMode = false
                    gameState.noFullAuto = false  -- 绂诲紑鎺㈢储, 鎭㈠鍏ㄨ嚜鍔ㄥ彲鐢?
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
                                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣宸茬炕鍊?", 1.5, { 120, 255, 180 }, 18)
                                if callback then callback(true) end
                            else
                                if callback then callback(false) end
                            end
                        end))
                    else
                        ReportAdWatch()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣宸茬炕鍊?", 1.5, { 120, 255, 180 }, 18)
                        if callback then callback(true) end
                    end
                end

                -- 鏄剧ず鐖嗙巼淇℃伅
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
                    "璁ㄤ紣鎺㈢储 " .. gs .. "脳" .. gs .. " 灏嗗搧鈫戞鐜嚸? .. highTierMul,
                    3.0, {180, 120, 255}, 20)

                PushPhase("EXPLORATION")
                PlaySFX(AUDIO.sfx_click)
                print("=== 璁ㄤ紣鎺㈢储 绗? .. fi .. "灞?" .. gs .. "脳" .. gs .. " 灏嗗搧鈫戞鐜嚸? .. highTierMul .. " ===")
                return
                --]=] -- END EXPLORATION REMOVED (ABYSS_SELECT)
            end
            return
        end

        -- 杩斿洖鎸夐挳
        if abyssState.backBtnRect and HitRect(abyssState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 鍏冲崱鍒楄〃鐐瑰嚮
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

    -- === 鏃犲敖鐖鐣岄潰杈撳叆 ===
    if gameState.phase == "TOWER_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 鎺掕姒滈潰鏉挎墦寮€鏃讹紝浼樺厛澶勭悊鎺掕姒滀氦浜?
        if towerState.showLeaderboard then
            if towerState.leaderboardBackRect and HitRect(towerState.leaderboardBackRect) then
                towerState.showLeaderboard = false
                PlaySFX(AUDIO.sfx_click)
            end
            return  -- 鎺掕姒滄墦寮€鏃跺悶鍣墍鏈夌偣鍑?
        end

        -- 棰勮寮圭獥锛堟寫鎴樼‘璁わ級
        if towerState.showPreview then
            if towerState.startBtnRect and HitRect(towerState.startBtnRect) then
                -- 999灞備笂闄愭鏌?
                if towerState.currentFloor > 999 then
                    ShowToast("宸茶揪鏈禌瀛ｆ渶楂樺眰(999灞?锛岃绛夊緟涓嬩釜璧涘")
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                -- 鐖鎴樻枟寮€濮嬶紙鏃犻渶闂ㄧエ锛?
                towerState.showPreview = false
                local fl = towerState.currentFloor
                gameState.towerFloor = fl  -- 鏍囪鐖妯″紡
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
                -- 闃剁骇闅忓眰鏁伴€掑 (姣?0灞?1闃? 鐖鏈€楂樼帇鍝?闃?
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
                print("=== 杩涘叆鐖鎴樻枟 绗? .. fl .. "灞?===")
                return
            end
            -- 鍏抽棴棰勮
            towerState.showPreview = false
            return
        end

        -- 杩斿洖鎸夐挳
        if towerState.backBtnRect and HitRect(towerState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 鎺掕姒滄寜閽?
        if towerState.leaderboardBtnRect and HitRect(towerState.leaderboardBtnRect) then
            towerState.showLeaderboard = true
            if not towerState.rankLoaded then
                LoadTowerLeaderboard()
            end
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 鐐瑰嚮涓诲尯鍩熸墦寮€棰勮
        towerState.showPreview = true
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- === 鎺掍綅璧涚晫闈㈣緭鍏?===
    if gameState.phase == "RANKED_SELECT" then
        if phaseChangeCooldown > 0 then return end

        -- 鍖归厤涓笉鍏佽鍏朵粬鎿嶄綔
        if rankedState.isMatching then return end

        -- 鎺掕姒滃脊绐?
        if rankedState.showLeaderboard then
            -- 鍏抽棴鎺掕姒?
            if rankedState.backBtnRect and HitRect(rankedState.backBtnRect) then
                rankedState.showLeaderboard = false
                PlaySFX(AUDIO.sfx_click)
                return
            end
            return
        end

        -- 寮€濮嬪尮閰嶆寜閽?
        if rankedState.startBtnRect and HitRect(rankedState.startBtnRect) then
            rankedState.isMatching = true
            rankedState.matchAnim = 0
            rankedState.matchReady = false
            rankedState.opponentName = ""
            rankedState.opponentPower = 0
            rankedState.opponentCards = {}
            if rawget(_G, "IsNetworkMode") and IsNetworkMode() then
                local Client = require("network.Client")
                local ok = Client.JoinRanked()
                if not ok then
                    rankedState.isMatching = false
                    if rawget(_G, "ShowToast") then ShowToast("排位服务器连接失败", 2.0) end
                    return
                end
            else
                rankedState.isMatching = false
                if rawget(_G, "ShowToast") then ShowToast("排位模式仅支持联机匹配", 2.0) end
                return
            end
            PlaySFX(AUDIO.sfx_click)
            print("=== 鎺掍綅鍖归厤寮€濮?===")
            return
        end

        -- 鎺掕姒滄寜閽?
        if rankedState.rankBtnRect and HitRect(rankedState.rankBtnRect) then
            rankedState.showLeaderboard = true
            if not rankedState.rankLoaded then
                LoadRankedLeaderboard()
            end
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- 杩斿洖鎸夐挳
        if rankedState.backBtnRect and HitRect(rankedState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        return
    end

    -- 鎺㈢储鎴樻枟纭寮圭獥: 鎷︽埅鎵€鏈夌偣鍑?(閫€鍑?姝讳骸)
    if gameState.exploreExitConfirm then
        local ddx, ddy = ScreenToDesign(sx, sy)
        local function HitECR(r)
            return r and ddx >= r.x and ddx <= r.x + r.w and ddy >= r.y and ddy <= r.y + r.h
        end

        -- 骞垮憡缈诲€嶈檸绗︽寜閽?
        if HitECR(exploreConfirmBtnRects.adDouble) then
            PlaySFX(AUDIO.sfx_click)
            if not exploreAdDoubleJade then
                if playerInfo.ad_free then
                    exploreAdDoubleJade = true
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍏嶅箍鍛婄炕鍊?", 1.5, { 100, 255, 200 }, 18)
                    print("[鎺㈢储] [鍏嶅箍鍛奭 缈诲€嶈檸绗﹀凡婵€娲?)
                elseif sdk then
                    ShowAdSafe(SafeAdCallback(function(result)
                        if result.success then
                            exploreAdDoubleJade = true
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "铏庣灏嗙炕鍊?", 1.5, { 120, 255, 180 }, 18)
                            ReportAdWatch()
                            print("[鎺㈢储] 骞垮憡缈诲€嶈檸绗﹀凡婵€娲?)
                        end
                    end))
                else
                    exploreAdDoubleJade = true
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "[DEV] 铏庣灏嗙炕鍊?", 1.5, { 120, 255, 180 }, 18)
                    ReportAdWatch()
                    print("[鎺㈢储] [DEV] 骞垮憡缈诲€嶈檸绗﹀凡婵€娲?)
                end
            end
            return
        end

        -- 纭鎸夐挳
        if HitECR(exploreConfirmBtnRects.confirm) then
            PlaySFX(AUDIO.sfx_click)
            if gameState.exploreExitConfirm.type == "abyss_exit" then
                -- 璁ㄤ紣鎴橀€€鍑? 淇濈暀30%鏀惰幏, 杩斿洖璁ㄤ紣鎴橀〉闈?
                gameState.exploreExitConfirm = nil
                -- Exploration.ForceAbandonWithRetain(0.3)  -- 30%淇濈暀 [EXPLORATION REMOVED]
                gameState.explorationMode = false
                gameState.noFullAuto = false
                gameState.abyssFloor = nil
                PopPhase("ABYSS_SELECT")
                abyssState.showPreview = false
                phaseChangeCooldown = 0.3
                SaveGameProgress()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "璁ㄤ紣鎾ら€€ (淇濈暀30%鏀惰幏)", 2.0, { 255, 200, 100 }, 16)
                print("[璁ㄤ紣] 涓€旈€€鍑? 淇濈暀30%鏀惰幏, 杩斿洖璁ㄤ紣鎴橀〉闈?)
            else
                -- 鎺㈢储鎴樻枟閫€鍑? 鍥炲埌鎺㈢储鍦板浘 (涓㈠け10%-30%宸叉湁鎴樺埄鍝? [EXPLORATION REMOVED]
                gameState.exploreExitConfirm = nil
                -- Exploration.OnBattleReturn(false)  -- [EXPLORATION REMOVED]
                -- local lostCount = Exploration.GetState().lastBattleLostCount or 0
                -- if lostCount > 0 then
                --     AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "涓㈠け浜?" .. lostCount .. " 浠舵垬鍒╁搧", 2.0, { 255, 120, 80 }, 16)
                -- end
                gameState.explorationMode = false
                gameState.phase = "MENU"  -- 鎺㈢储宸茬Щ闄? 鐩存帴鍥炰富鑿滃崟
                phaseChangeCooldown = 0.3
                print("[鎺㈢储] 鎺㈢储妯″潡宸茬Щ闄? 杩斿洖涓昏彍鍗?)
            end
            return
        end

        -- 鐪嬪箍鍛婂娲绘寜閽?(浠呮浜℃椂)
        if gameState.exploreExitConfirm.type == "death"
           and HitECR(exploreConfirmBtnRects.revive) then
            PlaySFX(AUDIO.sfx_click)
            -- 澶嶆椿鎴愬姛鐨勯€氱敤澶勭悊
            local function doRevive()
                -- Exploration.OnBattleReturn(false)  -- [EXPLORATION REMOVED]
                gameState.explorationMode = false
                gameState.exploreExitConfirm = nil
                gameState.phase = "MENU"  -- 鎺㈢储宸茬Щ闄? 鐩存帴鍥炰富鑿滃崟
                phaseChangeCooldown = 0.3
            end
            if playerInfo.ad_free then
                doRevive()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍏嶅箍鍛婂娲绘垚鍔?", 1.5, { 100, 255, 200 }, 16)
                print("[鎺㈢储] [鍏嶅箍鍛奭 澶嶆椿, 杩斿洖鎺㈢储鍦板浘")
            elseif sdk then
                ShowAdSafe(SafeAdCallback(function(result)
                    if result.success then
                        doRevive()
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "澶嶆椿鎴愬姛! 缁х画鎺㈢储", 1.5, { 120, 255, 180 }, 16)
                        ReportAdWatch()
                        print("[鎺㈢储] 骞垮憡澶嶆椿, 杩斿洖鎺㈢储鍦板浘")
                    end
                end))
            else
                -- DEV妯″紡: 妯℃嫙骞垮憡鎴愬姛
                doRevive()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "[DEV] 澶嶆椿鎴愬姛!", 1.5, { 120, 255, 180 }, 16)
                ReportAdWatch()
                print("[鎺㈢储] [DEV] 骞垮憡澶嶆椿, 杩斿洖鎺㈢储鍦板浘")
            end
            return
        end

        return  -- 寮圭獥鏄剧ず鏃舵嫤鎴墍鏈夊叾浠栫偣鍑?
    end

        if gameState.phase == "WIN" or gameState.phase == "LOSE" then
        if gameState.phase == "WIN" then
            -- WIN: 濂栧姳寮圭獥娴佺▼
            if gameState.showRewardPopup then
                -- 寮圭獥宸叉樉绀? 鍝嶅簲纭鎸夐挳鍜屽箍鍛婄炕鍊嶆寜閽?
                local ddx, ddy = ScreenToDesign(sx, sy)
                -- 骞垮憡缈诲€嶆寜閽?
                if rewardAdDoubleRect then
                    local r = rewardAdDoubleRect
                    if ddx >= r.x and ddx <= r.x + r.w and ddy >= r.y and ddy <= r.y + r.h then
                        WatchAdForDoubleReward()
                        return
                    end
                end
                -- 纭鎸夐挳
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
                        print("=== 濂栧姳纭, 杩斿洖 ===")
                    end
                end
            end
            -- 寮圭獥鏈脊鍑烘椂涓嶅搷搴旂偣鍑?
            return
        end
        -- LOSE: 鍘熸湁閫昏緫
        if gameState.resultTimer > 1.5 then
            -- 鎺㈢储妯″紡: 寮瑰嚭姝讳骸纭寮圭獥 (纭鏀惧純 / 鐪嬪箍鍛婂娲? [EXPLORATION REMOVED]
            -- explorationMode is always false since exploration module was removed
            -- if gameState.explorationMode then
            --     if not gameState.exploreExitConfirm then
            --         gameState.exploreExitConfirm = { type = gameState.abyssFloor and "abyss_exit" or "death" }
            --     end
            --     -- 寮圭獥鎸夐挳鐐瑰嚮鍦ㄤ笅鏂圭粺涓€澶勭悊
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
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "鍐嶆帴鍐嶅帀!", 2.0, { 200, 160, 100 }, 20)
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
            print("=== 杩斿洖 ===")
        end
        return
    end

    -- (宸茬Щ闄ゆ鎶€璇︽儏寮圭獥)

    -- 鎴樻枟瑙勫垯寮圭獥: 鎷︽埅鎵€鏈夌偣鍑伙紝鏀寔婊氬姩
    if battleRulesState.show then
        local cr = battleRulesState.closeBtnRect
        if cr and dx >= cr.x and dx <= cr.x + cr.w and dy >= cr.y and dy <= cr.y + cr.h then
            battleRulesState.show = false
            battleRulesState.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 闈㈡澘鍖哄煙鍐呭紑濮嬫嫋鎷芥粴鍔?
        local pr = battleRulesState.panelRect
        if pr and dx >= pr.x and dx <= pr.x + pr.w and dy >= pr.y and dy <= pr.y + pr.h then
            battleRulesState.isDragging = true
            battleRulesState.lastTouchY = dy
            battleRulesState.vel = 0
        else
            -- 鐐瑰嚮寮圭獥澶栧叧闂?
            battleRulesState.show = false
            battleRulesState.isDragging = false
        end
        return
    end

    -- 鎴樻枟杩斿洖鎸夐挳 (璁捐鍧愭爣)
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
            -- 鎺掍綅涓€旈€€鍑?= 鍒よ礋鎵ｅ垎
            local shouldLeaveRankedBattle = true
            if IsServerAuthoritativeRankedMode and IsServerAuthoritativeRankedMode() then
                gameState.awaitingRankedResult = true
                gameState.rankedDelta = nil
                local Client = require("network.Client")
                local ok = Client.ForfeitRanked()
                if not ok then
                    gameState.awaitingRankedResult = false
                    shouldLeaveRankedBattle = false
                    if rawget(_G, "ShowToast") then ShowToast("閹烘帊缍呴幎鏇㈡閹绘劒姘︽径杈Е", 2.0) end
                else
                    SaveGameProgress()
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "閹舵洟妾风紒鎾剁暬瀹稿弶褰佹禍?", 2.0, { 255, 180, 120 }, 18)
                end
            elseif rankedState.score > 0 then
                rankedState.losses = rankedState.losses + 1
                if rankedState.streak > 0 then rankedState.streak = 0 end
                rankedState.streak = rankedState.streak - 1
                local delta = CalcRankedScoreChange(false, rankedState.streak)
                rankedState.score = math.max(0, rankedState.score + delta)
                ReportRankedScore()
                -- 缃戠粶妯″紡: 閫氱煡鏈嶅姟绔純鏉?
                SaveGameProgress()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "閫€鍑哄垽璐?" .. delta .. "鍒?, 2.0, { 255, 100, 80 }, 18)
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
            -- 鏅€氬緛閫旈€€鍑? 淇濈暀30%鑳滃埄濂栧姳
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
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "鎾ら€€ +" .. retreatJade .. " 铏庣 (30%)", 2.0, { 255, 200, 100 }, 16)
            PopPhase("MENU")
        end
        phaseChangeCooldown = 0.3
        -- 娓呯悊鎴樻枟鐘舵€?
        for _, slot in ipairs(PLAYER_SLOTS) do
            slot.filled = false; slot.card = nil
        end
        playerUnits = {}
        enemyUnits = {}
        print("=== 鎴樻枟涓繑鍥為椤?===")
        return
    end

    -- 鎹㈡垬鍦烘寜閽?(鎵撴々鍑嗗闃舵, 璁捐鍧愭爣)
    if gameState.isDummy and dummyState.prepPhase and dummyState.changeBgBtnRect then
        local r = dummyState.changeBgBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            gameState.abyssFloor = (gameState.abyssFloor % 7) + 1
            ApplyBattleLayout(gameState.abyssFloor + 1)  -- 璁ㄤ紣灞侼 鈫?甯冨眬绱㈠紩N+1
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "鎴樺満 " .. gameState.abyssFloor .. "/7", 1.0, { 180, 220, 255 }, 14)
            PlaySFX(AUDIO.sfx_click)
            print("=== 鍒囨崲鎴樺満鑳屾櫙: " .. gameState.abyssFloor .. " ===")
            return
        end
    end

    -- 鎹㈡垬鍦烘寜閽?(鏅€氭垬鏂? 闈炶浼?鐖, 璁捐鍧愭爣)
    if not gameState.abyssFloor and not gameState.towerFloor and not gameState.isRanked and not gameState.isDummy and battleChangeBgBtnRect then
        local r = battleChangeBgBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            local newIdx = (currentLayoutIdx % 8) + 1
            ApplyBattleLayout(newIdx)
            local layoutName = BATTLE_LAYOUTS[newIdx] and BATTLE_LAYOUTS[newIdx].name or "榛樿"
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, layoutName, 1.0, { 180, 220, 255 }, 14)
            PlaySFX(AUDIO.sfx_click)
            print("=== 鍒囨崲鎴樺満鑳屾櫙: " .. newIdx .. " " .. layoutName .. " ===")
            return
        end
    end

    -- 寮€鎴樻寜閽?(浠匰HOP闃舵鍙敤, 璁捐鍧愭爣)
    if HitFightButton(dx, dy) then
        if gameState.battlePhase == "SHOP" then
            -- 鎵撴々妯″紡锛氱敓鎴愯€佽檸骞跺紑濮?0绉掕鏃?
            if gameState.isDummy and dummyState.prepPhase then
                dummyState.prepPhase = false
                dummyState.totalDamage = 0
                dummyState.timer = 30

                -- 姹囪仛灞炴€?
                AggregateBaseStats()
                -- 閲嶈鏁屾柟HP锛圓ggregateBaseStats浼氳鐩栵級
                gameState.enemyBaseHP = 999999
                gameState.enemyBaseMax = 999999

                -- 鐢熸垚100鍙法鍏借€佽檸锛堟瘡鏉¤溅閬?0鍙級
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
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "30s鎵撴々寮€濮?", 1.5, { 255, 220, 80 }, 18)
                print("=== 30s鎵撴々鎴樻枟寮€濮?(100鍙法鍏借€佽檸) ===")
            else
                gameState.battlePhase = "FIGHT"
                AggregateBaseStats()  -- 姹囪仛姝︾伒灞炴€у埌澶ф湰钀?
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "寮€鎴?", 1.5, { 255, 220, 80 }, 18)
                PlaySFX(AUDIO.sfx_march)
                -- 搴旂敤榛樿鑷姩琛屽啗璁剧疆
                gameState.autoMarch = gameSettings.defaultAutoMarch
                -- 鏂版墜鍑哄叺绛栫暐鎻愮ず (浠呴娆?
                if not gameSettings.shownMarchHint then
                    gameSettings.shownMarchHint = true
                    gameSettings.battleCount = (gameSettings.battleCount or 0) + 1
                    SaveSettings()
                    ShowToast("鎻愮ず: 鐐瑰嚮鍙充笅琛屽啗鎸夐挳寮€鍚嚜鍔ㄥ嚭鍏碉紝闀挎寜鍙垏鎹㈠嚭鍏电瓥鐣?, 4.0)
                else
                    gameSettings.battleCount = (gameSettings.battleCount or 0) + 1
                    SaveSettings()
                end
                print("=== 寮€鎴? ===")
            end
        end
        return
    end

    -- 鍒锋柊鎸夐挳 (SHOP鍜孎IGHT闃舵閮藉彲鐢? 璁捐鍧愭爣)
    if shopRefreshBtnRect then
        local r = shopRefreshBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            if gameState.gold >= GameConfig.REFRESH_COST then
                gameState.gold = gameState.gold - GameConfig.REFRESH_COST
                RefreshShop()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "-" .. GameConfig.REFRESH_COST .. " 鍒锋柊", 1.0, { 180, 200, 255 }, 12)
            else
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.6, "鍐涜祫涓嶈冻!", 1.2, { 255, 100, 100 }, 14)
            end
            return
        end
    end
    -- 鍊嶉€熸寜閽偣鍑?
    if battleSpeedBtnRect then
        local r = battleSpeedBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            -- 寰幆鍒囨崲: 1 鈫?2 鈫?3 鈫?1
            local spd = gameState.battleSpeed or 1
            if spd == 1 then
                gameState.battleSpeed = 2
            elseif spd == 2 then
                gameState.battleSpeed = 3
            else
                gameState.battleSpeed = 1
            end
            local spdLabel = "脳" .. tostring(gameState.battleSpeed)
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "鍊嶉€?" .. spdLabel, 1.0, { 255, 220, 80 }, 16)
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- 鑷姩鎴樻枟鎸夐挳鐐瑰嚮
    if autoBattleBtnRect then
        local r = autoBattleBtnRect
        if dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h then
            if gameState.noFullAuto then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "鍓湰妯″紡绂佺敤鍏ㄨ嚜鍔?, 1.5, { 255, 140, 100 }, 16)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            gameState.autoBattle = not gameState.autoBattle
            autoBattleTimer = 0
            local txt = gameState.autoBattle and "鑷姩鎴樻枟 寮€鍚? or "鑷姩鎴樻枟 鍏抽棴"
            local clr = gameState.autoBattle and { 120, 255, 160 } or { 200, 180, 160 }
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, txt, 1.2, clr, 16)
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
    -- 瑙勫垯鎸夐挳鐐瑰嚮 (FIGHT闃舵)
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
    -- 绛栫暐閫夐」鏉＄偣鍑?(show=true鏃朵紭鍏堟娴?
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
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "绛栫暐: " .. st.name, 1.2, st.color, 16)
            PlaySFX(AUDIO.sfx_march)
        end
        strategyWheelState.show = false
        strategyWheelState.selected = 0
        return
    end
    -- 鑷姩琛屽啗鎸夐挳 (FIGHT闃舵, 鍦嗗舰纰版挒妫€娴? 鏀寔闀挎寜寮瑰嚭绛栫暐閫夐」)
    if autoMarchBtnRect and autoMarchBtnRect.isCircle then
        local ab = autoMarchBtnRect
        local ddx, ddy = dx - ab.cx, dy - ab.cy
        if ddx * ddx + ddy * ddy <= ab.r * ab.r then
            -- 璁板綍鎸変笅锛岀瓑release鏃跺垽鏂槸鐭寜toggle杩樻槸闀挎寜閫夌瓥鐣?
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

    -- 姝︽妧鎶€鑳芥寜閽?(FIGHT闃舵, 鍦嗗舰纰版挒妫€娴? 鏈€澶?涓?
    -- 姝︽妧鎶€鑳? 鎸変笅鍗冲紑濮嬫嫋鎷界瀯鍑嗭紙宸茬Щ闄ら暱鎸夊脊绐楋級
    if gameState.battlePhase == "FIGHT" then
        for slot, sb in pairs(skillBtnRects) do
            if sb and sb.isCircle then
                local sdx, sdy = dx - sb.cx, dy - sb.cy
                if sdx * sdx + sdy * sdy <= sb.r * sb.r then
                    local techIdx = sb.techIdx
                    local skill = SKILL_DEFS[techIdx]
                    if skill then
                        if not skill.unlocked then
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "姝︽妧鏈В閿?, 0.8, { 200, 160, 100 }, 12)
                        elseif skill.cooldown > 0 then
                            local cdLeft = math.ceil(skill.cooldown)
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "鍐峰嵈涓?" .. cdLeft .. "s", 0.8, { 200, 160, 100 }, 12)
                        else
                            -- 鐩存帴寮€濮嬫嫋鎷界瀯鍑?
                            skillTargeting.active = true
                            skillTargeting.skillIdx = techIdx
                            skillTargeting.touchId = touchId
                            skillTargeting.sx = sx
                            skillTargeting.sy = sy
                            skillTargeting.dx = math.max(BATTLE_ZONE.left, math.min(BATTLE_ZONE.right, dx))
                            skillTargeting.dy = math.max(BATTLE_ZONE.top, math.min(BATTLE_ZONE.bottom, dy))
                            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, skill.name .. " - 鎷栨嫿鐬勫噯", 0.8, skill.color, 12)
                        end
                    end
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
        end
    end

    -- 鍟嗗簵鍗＄墝 >> 鎷栨嫿鏀剧疆 (SHOP鍜孎IGHT闃舵鍧囧彲)
    if gameState.battlePhase == "SHOP" or gameState.battlePhase == "FIGHT" then
        local shopIdx, shopItem = HitShopCard(lx, ly)
        if shopIdx > 0 and shopItem then
            -- 妫€鏌ュ啗璧勫涓嶅
            if gameState.gold < shopItem.cost then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.6, "鍐涜祫涓嶈冻!", 1.2, { 255, 100, 100 }, 14)
                return
            end
            -- 鎵ｉ櫎鍐涜祫, 鏍囪宸插敭, 寮€濮嬫嫋鎷?
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
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "-" .. shopItem.cost .. " 鍐涜祫 - 鎷栬嚦鐭冲彴鏀剧疆", 1.2, { 255, 180, 80 }, 12)
            return
        end
    end

    longPressState.pressing = true
    longPressState.active = false
    longPressState.startTime = gameState.gameTime

    -- 鐭冲彴鍗＄墝 (鐐瑰嚮鏌ョ湅璇︽儏, 鎷栨嫿鎹綅)
    local slotCard, slotIdx, isEnemy = HitSlotCard(dx, dy)
    if slotCard then
        longPressState.card = slotCard
        longPressState.isSlot = true
        longPressState.slotIdx = slotIdx
        longPressState.isEnemy = isEnemy
        dragState.touchId = touchId
        return
    end

    -- 鑳屽寘鍗＄墝 (鎷栨嫿涓婇樀, SHOP鍜孎IGHT闃舵鍧囧彲)
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



