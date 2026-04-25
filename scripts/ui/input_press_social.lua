-- ============================================================================
-- ui/input_press_social.lua - 社交系统点击处理
-- 用途: BeginPress 子处理器 - FACTION, FRIENDS, POWER_RANK, CONTRIB_RANK, EQUIP_CODEX, SEAL_MGR
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
    local dx, dy = ScreenToDesign(sx, sy)
    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    if gameState.phase == "FACTION" then
        -- 改名弹窗优先
        if factionUI.renamePopup then
            if menuBtnRects.factionRenameYes and HitRect(menuBtnRects.factionRenameYes) then
                local newName = factionUI.renameInput or ""
                if #newName == 0 then
                    ShowToast("不能添加自己为好友")
                elseif (playerInfo.jade or 0) < 1000 then
                    ShowToast("玉壁不足，改名需要1000玉壁")
                else
                    playerInfo.jade = playerInfo.jade - 1000
                    CloudManager.RenameFaction(newName, function(ok, reason)
                        if ok then
                            ShowToast("阵营已更名为「" .. newName .. "」(-1000玉壁)")
                            factionUI.loaded = false; factionUI.loading = false
                            if SaveGameProgress then SaveGameProgress() end
                        else
                            -- 改名失败，退还玉壁
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
                        else ShowToast("操作失败") end
                    end)
                elseif pop.type == "create" then
                    -- 玉壁检查和扣费由 CloudManager.CreateFaction 统一处理
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
        -- 杩斿洖
        if menuBtnRects.factionBack and HitRect(menuBtnRects.factionBack) then
            factionUI.inputTarget = nil; input:SetScreenKeyboardVisible(false)
            PopPhase("MENU"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return
        end
        -- Tab切换
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
                            ShowToast("捐献成功! +" .. factionUI.donateAmount .. " 玉壁")
                        end
                    else
                            ShowToast("改名失败: " .. tostring(reason))
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
                            ShowToast("改名失败: " .. tostring(reason))
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
            local myUid = CloudAPI.GetUserId()
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
        -- 名字选择 (含自定义选项)
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
        -- 名字选择 (含自定义选项)
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
                    factionUI.applyStatus = nil; ShowToast("申请已通过！")
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
                msg = "花费5000玉壁创建阵营？"
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

        -- ======== 战力说明弹窗交互 ========
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
        -- 杩斿洖
        if menuBtnRects.friendsBack and HitRect(menuBtnRects.friendsBack) then
            friendsUI.inputActive = false; input:SetScreenKeyboardVisible(false)
            PopPhase("MENU"); phaseChangeCooldown = 0.3; PlaySFX(AUDIO.sfx_click); return
        end
        -- Tab切换
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
        -- 入队申请: 同意/拒绝
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

    if gameState.phase == "POWER_RANK" then
        if menuBtnRects.powerRankBack and HitRect(menuBtnRects.powerRankBack) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 刷新按钮
        if menuBtnRects.rankRefresh and HitRect(menuBtnRects.rankRefresh) then
            if CloudAPI.IsAvailable() then
                welfareState.powerLoaded = false; welfareState.powerLoading = false
                welfareState.realmLoaded = false; welfareState.realmLoading = false
                welfareState.factionRankLoaded = false; welfareState.factionRankLoading = false
                ReportPowerScore(); LoadPowerRank()
                ReportRealmScore(); LoadRealmRank()
                local ct = welfareState.rankTab or "power"
                if ct == "faction" then LoadFactionLevelRankForTab() end
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "正在刷新排行榜...", 1.2, {140, 220, 180}, 18)
            else
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "服务器未连接，请稍后再试", 1.2, {255, 160, 100}, 18)
            end
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 页签切换 (统一处理3个Tab)
        for _, tabId in ipairs({"power", "realm", "faction"}) do
            local tabKey = "rankTab_" .. tabId
            if menuBtnRects[tabKey] and HitRect(menuBtnRects[tabKey]) then
                if welfareState.rankTab ~= tabId then
                    welfareState.rankTab = tabId
                    welfareState.rankViewBtnRects = {}
                    welfareState.rankViewPopup = nil
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
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "UID已复制: " .. uidStr, 1.2, { 140, 220, 180 }, 18)
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
                    -- 通过 userId 从原始数据中精确查找对应条目
        local rankData
        if welfareState.rankTab == "realm" then
            rankData = welfareState.realmRank
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

    -- === 个人资料界面输入 ===
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
            return  -- 弹窗打开时拦截所有其他点击
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
        -- 名字选择 (含自定义选项)
            if sealMgrBtnRects.replaceBtn and HitRect(sealMgrBtnRects.replaceBtn) then
                sealReplaceState.show = true
                sealReplaceState.heroIdx = sealMgrState.selectedHero
                sealReplaceState.slotIdx = sealMgrState.selectedSlot
                sealReplaceState.scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
                PlaySFX(AUDIO.sfx_click)
                return
            end
        -- 名字选择 (含自定义选项)
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
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "无法使用!", 1.0, { 255, 100, 100 }, 18)
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
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, msg or "升级失败", 1.0, { 255, 100, 100 }, 18)
                    end
                end
                return
            end
            return  -- 升级面板打开时屏蔽其他点击
        end

        -- ====== 选中分解模式下的交互 ======
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
            return  -- 弹窗打开时拦截所有其他点击
        end

        -- ====== 选中分解模式下的交互 ======
        if sealInvFilterBtnRects.batchDecompBtn and HitRect(sealInvFilterBtnRects.batchDecompBtn) then
            sealInvFilterState.batchConfirmShow = true
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- ====== 选中分解模式下的交互 ======
        if sealInvFilterBtnRects.selectDecompBtn and HitRect(sealInvFilterBtnRects.selectDecompBtn) then
            sealInvFilterState.selectMode = true
            sealInvFilterState.selectedIds = {}
            sealMgrScroll.y = 0
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "选中要分解的兵甲", 1.0, { 100, 180, 255 }, 18)
            PlaySFX(AUDIO.sfx_click)
            return
        end

        -- ====== 选中分解模式下的交互 ======
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


    return false  -- 未匹配任何 phase
end

return M
