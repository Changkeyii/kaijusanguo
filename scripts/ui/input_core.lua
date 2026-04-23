-- ui/input_core.lua - 三国武灵录 (从 input.lua 拆分)
-- ui/input.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 输入: 碰撞检测
-- ============================================================================

function HitSlotCard(dx, dy)
    local halfW = SLOT_CARD_W / 2 + 4
    local halfH = SLOT_CARD_H / 2 + 4
    for i, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            if dx >= slot.cx - halfW and dx <= slot.cx + halfW and
               dy >= slot.cy - halfH and dy <= slot.cy + halfH then
                return slot.card, i, false
            end
        end
    end
    for i, slot in ipairs(ENEMY_SLOTS) do
        if slot.filled and slot.card then
            if dx >= slot.cx - halfW and dx <= slot.cx + halfW and
               dy >= slot.cy - halfH and dy <= slot.cy + halfH then
                return slot.card, i, true
            end
        end
    end
    return nil, 0, false
end


function HitInventoryCard(lx, ly)
    local sl = shopLayout
    if ly < sl.y or ly > sl.y + sl.h then return nil, 0 end
    local visCount = GameConfig.INVENTORY_VISIBLE
    for vi = 1, visCount do
        local invIdx = invScrollOffset + vi
        if invIdx <= #inventory and inventory[invIdx] then
            local cx = sl.startX + (vi - 1) * (sl.cardW + sl.gap)
            local cy = sl.y + 20
            if lx >= cx and lx <= cx + sl.cardW and ly >= cy and ly <= cy + sl.cardH then
                return inventory[invIdx], invIdx
            end
        end
    end
    return nil, 0
end


function HitArrowLeft(lx, ly)
    local sl = shopLayout
    if ly < sl.y or ly > sl.y + sl.h then return false end
    return lx >= sl.arrowLeftX and lx <= sl.arrowLeftX + sl.arrowLeftW
end


function HitArrowRight(lx, ly)
    local sl = shopLayout
    if ly < sl.y or ly > sl.y + sl.h then return false end
    return lx >= sl.arrowRightX and lx <= sl.arrowRightX + sl.arrowRightW
end


function HitDrawButton(lx, ly)
    local sl = shopLayout
    return lx >= sl.drawBtnX and lx <= sl.drawBtnX + sl.drawBtnW and
           ly >= sl.drawBtnY and ly <= sl.drawBtnY + sl.drawBtnH
end


--- 检测点击商店卡牌 (逻辑坐标)
function HitShopCard(lx, ly)
    for i, item in ipairs(shopCards) do
        if item._rect and not item.sold then
            local r = item._rect
            if lx >= r.x and lx <= r.x + r.w and ly >= r.y and ly <= r.y + r.h then
                return i, item
            end
        end
    end
    return 0, nil
end


--- 检测点击开战按钮 (设计坐标)
function HitFightButton(dx, dy)
    if not shopFightBtnRect then return false end
    local r = shopFightBtnRect
    return dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
end


-- ============================================================================
-- 输入事件
-- ============================================================================

function HandleMouseDown(eventType, eventData)
    if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
    BeginPress(eventData["X"]:GetInt(), eventData["Y"]:GetInt(), -1)
end


function HandleMouseMove(eventType, eventData)
    HandleMoveLogic(eventData["X"]:GetInt(), eventData["Y"]:GetInt(), -1)
end


function HandleMouseUp(eventType, eventData)
    if eventData["Button"]:GetInt() ~= MOUSEB_LEFT then return end
    EndPress(eventData["X"]:GetInt(), eventData["Y"]:GetInt(), -1)
end


function HandleTouchBegin(eventType, eventData)
    local tx, ty = eventData["X"]:GetInt(), eventData["Y"]:GetInt()
    DetectTouchCoordSystem(tx, ty)
    -- 前3次触摸打印诊断日志
    if _touchDetectSamples <= 3 then
        print(string.format("[TouchDiag] raw=(%d,%d) logScreen=(%.0f,%.0f) physScreen=(%d,%d) dpr=%.2f touchDPR=%s",
            tx, ty, screenW, screenH,
            GetGraphics():GetWidth(), GetGraphics():GetHeight(),
            GetGraphics():GetDPR(),
            touchCoordDPR and string.format("%.2f", touchCoordDPR) or "detecting"))
    end
    BeginPress(tx, ty, eventData["TouchID"]:GetInt())
end


function HandleTouchMove(eventType, eventData)
    local tx, ty = eventData["X"]:GetInt(), eventData["Y"]:GetInt()
    DetectTouchCoordSystem(tx, ty)
    HandleMoveLogic(tx, ty, eventData["TouchID"]:GetInt())
end


function HandleTouchEnd(eventType, eventData)
    EndPress(eventData["X"]:GetInt(), eventData["Y"]:GetInt(), eventData["TouchID"]:GetInt())
end


-- === 鼠标滚轮缩放 ===
---@param eventType string
---@param eventData MouseWheelEventData
function HandleMouseWheel(eventType, eventData)
    local delta = eventData["Wheel"]:GetInt()
    if delta == 0 then return end
    if gameState.phase == "WORLD_MAP" and rawget(_G, "WorldMap") and WorldMap.HandleScroll then
        WorldMap.HandleScroll(delta)
    end
end


-- === 双指捏合缩放 (MultiGesture) ===
---@param eventType string
---@param eventData MultiGestureEventData
function HandleMultiGesture(eventType, eventData)
    local numFingers = eventData["NumFingers"]:GetInt()
    if numFingers < 2 then return end
    local dDist = eventData["DDist"]:GetFloat()  -- 双指距离变化量 (正=张开, 负=捏合)
    if math.abs(dDist) < 0.0001 then return end

    -- 将 DDist 转换为等效滚轮 delta (张开=放大=负delta, 捏合=缩小=正delta)
    -- DDist 通常在 -0.05 ~ 0.05 范围，乘以缩放系数转换
    local scrollDelta = -dDist * 15.0

    if gameState.phase == "WORLD_MAP" and rawget(_G, "WorldMap") and WorldMap.HandleScroll then
        WorldMap.HandleScroll(scrollDelta)
    end
end


-- === 文本输入事件（自定义名字） ===
function HandleTextInput(eventType, eventData)
    local ch = eventData:GetString("Text")
    if not ch or #ch == 0 then return end

    -- CDK 输入拦截 (优先)
    if cdkState.inputOpen then
        local upper = string.upper(ch)
        -- 接受 A-Z, 0-9, - (CDK码字符)
        if upper:match("^[A-Z0-9%-]$") then
            if #cdkState.inputText < 20 then
                cdkState.inputText = cdkState.inputText .. upper
            end
        end
        return
    end

    -- 阵营创建输入
    if gameState.phase == "FACTION" and factionUI.inputTarget then
        if factionUI.inputTarget == "name" then
            local nameLen = utf8.len(factionUI.createName) or 0
            if nameLen < 8 then factionUI.createName = factionUI.createName .. ch end
        elseif factionUI.inputTarget == "desc" then
            local descLen = utf8.len(factionUI.createDesc) or 0
            if descLen < 30 then factionUI.createDesc = factionUI.createDesc .. ch end
        elseif factionUI.inputTarget == "chat" then
            if not factionUI.chatInput then factionUI.chatInput = "" end
            local chatLen = utf8.len(factionUI.chatInput) or 0
            if chatLen < 50 then factionUI.chatInput = factionUI.chatInput .. ch end
        elseif factionUI.inputTarget == "rename" then
            if not factionUI.renameInput then factionUI.renameInput = "" end
            local renameLen = utf8.len(factionUI.renameInput) or 0
            if renameLen < 8 then factionUI.renameInput = factionUI.renameInput .. ch end
        elseif factionUI.inputTarget == "announce" then
            if not factionUI.announceInput then factionUI.announceInput = "" end
            local annLen = utf8.len(factionUI.announceInput) or 0
            if annLen < 200 then factionUI.announceInput = factionUI.announceInput .. ch end
        end
        return
    end

    -- 好友搜索输入
    if gameState.phase == "FRIENDS" and friendsUI.inputActive then
        -- 只接受数字
        if ch:match("^[0-9]$") then
            if #friendsUI.searchId < 15 then
                friendsUI.searchId = friendsUI.searchId .. ch
            end
        end
        return
    end

    -- 世界聊天输入
    if worldChatUI.expanded and worldChatUI.inputActive then
        if not worldChatUI.chatInput then worldChatUI.chatInput = "" end
        local chatLen = utf8.len(worldChatUI.chatInput) or 0
        if chatLen < 60 then worldChatUI.chatInput = worldChatUI.chatInput .. ch end
        return
    end

    -- 邮件写信输入（管理员专用，代码在 admin/ 目录）
    if IS_ADMIN_BUILD and _AdminMailKeyboard and gameState.phase == "MAIL_BOX" and welfareState.mail.composing and welfareState.mail.composeData then
        _AdminMailKeyboard.HandleTextInput(ch)
        return
    end

    -- 个人资料名字输入
    if not profileState.isInputActive then return end
    if gameState.phase ~= "PROFILE" then return end
    -- 限制最大5个UTF-8字符
    local nameLen = utf8.len(profileState.customName) or 0
    if nameLen < 5 then
        profileState.customName = profileState.customName .. ch
    end
end


function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")

    -- 云数据加载中拦截键盘操作
    if CloudManager.IsCloudLoading() then return end

    -- CDK 输入拦截 (优先)
    if cdkState.inputOpen then
        if key == KEY_BACKSPACE then
            local s = cdkState.inputText
            if #s > 0 then cdkState.inputText = s:sub(1, -2) end
        elseif key == KEY_RETURN or key == KEY_KP_ENTER then
            TryRedeemCDK()
        elseif key == KEY_ESCAPE then
            cdkState.inputOpen = false
            cdkState.inputText = ""
            input:SetScreenKeyboardVisible(false)
        end
        return
    end

    -- 阵营创建输入 KeyDown
    if gameState.phase == "FACTION" and factionUI.inputTarget then
        if key == KEY_BACKSPACE then
            if factionUI.inputTarget == "name" then
                local s = factionUI.createName
                if #s > 0 then
                    local bytes = { string.byte(s, 1, #s) }
                    local i = #bytes
                    while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do i = i - 1 end
                    if i > 0 then i = i - 1 end
                    factionUI.createName = string.sub(s, 1, i)
                end
            elseif factionUI.inputTarget == "desc" then
                local s = factionUI.createDesc
                if #s > 0 then
                    local bytes = { string.byte(s, 1, #s) }
                    local i = #bytes
                    while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do i = i - 1 end
                    if i > 0 then i = i - 1 end
                    factionUI.createDesc = string.sub(s, 1, i)
                end
            elseif factionUI.inputTarget == "chat" then
                local s = factionUI.chatInput or ""
                if #s > 0 then
                    local bytes = { string.byte(s, 1, #s) }
                    local i = #bytes
                    while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do i = i - 1 end
                    if i > 0 then i = i - 1 end
                    factionUI.chatInput = string.sub(s, 1, i)
                end
            elseif factionUI.inputTarget == "rename" then
                local s = factionUI.renameInput or ""
                if #s > 0 then
                    local bytes = { string.byte(s, 1, #s) }
                    local i = #bytes
                    while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do i = i - 1 end
                    if i > 0 then i = i - 1 end
                    factionUI.renameInput = string.sub(s, 1, i)
                end
            elseif factionUI.inputTarget == "announce" then
                local s = factionUI.announceInput or ""
                if #s > 0 then
                    local bytes = { string.byte(s, 1, #s) }
                    local i = #bytes
                    while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do i = i - 1 end
                    if i > 0 then i = i - 1 end
                    factionUI.announceInput = string.sub(s, 1, i)
                end
            end
        elseif key == KEY_RETURN or key == KEY_KP_ENTER then
            -- 改名输入回车直接提交
            if factionUI.inputTarget == "rename" and factionUI.renamePopup then
                local newName = factionUI.renameInput or ""
                if #newName > 0 then
                    if (playerInfo.jade or 0) < 1000 then
                        ShowToast("玉壁不足，改名需要1000玉壁")
                    else
                        playerInfo.jade = playerInfo.jade - 1000
                        CloudManager.RenameFaction(newName, function(ok, reason)
                            if ok then
                                ShowToast("阵营已更名为「" .. newName .. "」(-1000玉壁)")
                                factionUI.loaded = false; factionUI.loading = false
                                if SaveGameProgress then SaveGameProgress() end
                            else
                                playerInfo.jade = playerInfo.jade + 1000
                                ShowToast("改名失败: " .. tostring(reason))
                            end
                        end)
                    end
                end
                factionUI.renamePopup = false; factionUI.renameInput = ""
                factionUI.inputTarget = nil; input:SetScreenKeyboardVisible(false)
                return
            end
            -- 聊天输入回车直接发送 (云端同步)
            if factionUI.inputTarget == "chat" and factionUI.chatInput and #factionUI.chatInput > 0 then
                local filteredText = FilterBannedWords(factionUI.chatInput)
                local senderName = CloudManager._myTapNickname or factionUI.myNickname or playerInfo.name or "我"
                CloudManager.SendFactionChat(filteredText, senderName)
                playerInfo.totalFactionChat = (playerInfo.totalFactionChat or 0) + 1
                factionUI.chatInput = ""
            end
            factionUI.inputTarget = nil; input:SetScreenKeyboardVisible(false)
        elseif key == KEY_ESCAPE then
            if factionUI.renamePopup then
                factionUI.renamePopup = false; factionUI.renameInput = ""
            end
            factionUI.inputTarget = nil; input:SetScreenKeyboardVisible(false)
        end
        return
    end

    -- 好友搜索输入 KeyDown
    if gameState.phase == "FRIENDS" and friendsUI.inputActive then
        if key == KEY_BACKSPACE then
            local s = friendsUI.searchId
            if #s > 0 then friendsUI.searchId = s:sub(1, -2) end
        elseif key == KEY_RETURN or key == KEY_KP_ENTER then
            friendsUI.inputActive = false; input:SetScreenKeyboardVisible(false)
            -- 自动触发搜索
            if #friendsUI.searchId > 0 then
                friendsUI.searchResult = nil; friendsUI.searchNotFound = false
                local searchUid = tonumber(friendsUI.searchId)
                if searchUid then
                    CloudManager.SearchPlayer(searchUid, function(player)
                        if player then
                            friendsUI.searchResult = player; friendsUI.searchNotFound = false
                        else friendsUI.searchNotFound = true end
                    end)
                end
            end
        elseif key == KEY_ESCAPE then
            friendsUI.inputActive = false; input:SetScreenKeyboardVisible(false)
        end
        return
    end

    -- 世界聊天 KeyDown
    if worldChatUI.expanded and worldChatUI.inputActive then
        if key == KEY_BACKSPACE then
            local s = worldChatUI.chatInput or ""
            if #s > 0 then
                local bytes = { string.byte(s, 1, #s) }
                local i = #bytes
                while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do i = i - 1 end
                if i > 0 then i = i - 1 end
                worldChatUI.chatInput = string.sub(s, 1, i)
            end
        elseif key == KEY_RETURN or key == KEY_KP_ENTER then
            if worldChatUI.chatInput and #worldChatUI.chatInput > 0 then
                local filteredText = FilterBannedWords(worldChatUI.chatInput)
                local senderName = CloudManager._myTapNickname or factionUI.myNickname or playerInfo.name or "无名"
                CloudManager.SendWorldChat(filteredText, senderName)
                worldChatUI.chatInput = ""
            end
            worldChatUI.inputActive = false; input:SetScreenKeyboardVisible(false)
        elseif key == KEY_ESCAPE then
            worldChatUI.expanded = false; worldChatUI.inputActive = false
            worldChatUI.chatInput = ""; input:SetScreenKeyboardVisible(false)
        end
        return
    end

    -- 邮件写信 KeyDown（管理员专用，代码在 admin/ 目录）
    if IS_ADMIN_BUILD and _AdminMailKeyboard and gameState.phase == "MAIL_BOX" and welfareState.mail.composing and welfareState.mail.composeData then
        _AdminMailKeyboard.HandleKeyDown(key)
        return
    end

    if not profileState.isInputActive then return end
    if gameState.phase ~= "PROFILE" then return end
    if key == KEY_BACKSPACE then
        local s = profileState.customName
        if #s > 0 then
            -- 删除最后一个UTF-8字符
            local bytes = { string.byte(s, 1, #s) }
            local i = #bytes
            while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do
                i = i - 1
            end
            if i > 0 then i = i - 1 end
            profileState.customName = string.sub(s, 1, i)
        end
    elseif key == KEY_RETURN or key == KEY_KP_ENTER then
        profileState.isInputActive = false
        input:SetScreenKeyboardVisible(false)
    end
end

