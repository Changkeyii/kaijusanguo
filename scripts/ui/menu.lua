-- ============================================================================
-- ui/menu.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 首页菜单 (暗铜NanoVG风格 + 模块下载/讨伐)
-- ============================================================================

function DrawMenuScreen()
    if gameState.phase ~= "MENU" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer

    -- 1. 统一菜单背景
    DrawMenuBg(W, H)

    nvgFontFaceId(vg, GetMainFont())

    -- ===========================
    -- 通用: 侧栏按钮绘制函数
    -- ===========================
    local function DrawSideBtn(bx, by, bw, bh, label, colors, bPulse, showGlow, iconImg)
        -- 纯图标+文字，无任何背景
        if iconImg and IsImageReady(iconImg) then
            local iconSize = math.floor(math.min(bw * 0.65, bh * 0.55))
            local iconX = bx + (bw - iconSize) / 2
            local iconY = by + 2
            local pat = nvgImagePattern(vg, iconX, iconY, iconSize, iconSize, 0, iconImg, 1.0)
            nvgBeginPath(vg); nvgRect(vg, iconX, iconY, iconSize, iconSize)
            nvgFillPaint(vg, pat); nvgFill(vg)
            -- 文字
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            DrawWhiteInkText(bx + bw / 2, by + bh - 1, label)
        else
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + bw / 2, by + bh / 2, label)
        end
    end

    -- ===========================
    -- 2. 中央角色展示区 (横屏: 顶部到底栏之间)
    -- ===========================
    local centerAreaTop = 4
    local bottomBarH = 72
    local bottomBarY = H - bottomBarH - 4
    local centerAreaBottom = bottomBarY - 6



    -- ===========================
    -- 4. 左侧栏 (竖排功能按钮, 横屏适配, 支持滚动)
    -- ===========================
    local sideBtnW = 72
    local sideBtnH = 58
    local sideGap = 4
    local sideX = 4
    local leftEndY = bottomBarY - 4       -- 底部留出间距
    local leftStartY = centerAreaTop + 4
    local leftViewH = leftEndY - leftStartY

    -- 左侧按钮配置 (带图标)
    local leftButtons = {
        { label = "阵营",   key = "faction",  colors = {70, 55, 30},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[8] },
        { label = "好友",   key = "friends",  colors = {40, 65, 70},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[9] },
        { label = "交易行", key = "trade",    colors = {75, 55, 35},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[14] },
        { label = "编队",   key = "formation", colors = {65, 50, 55},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[15] },
        { label = "邮件",   key = "mailBox",  colors = {45, 45, 70},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[10] },
        { label = "武灵录", key = "codex",     colors = {60, 45, 80},  mod = moduleState.heroes,    icon = IMG.menuIcons and IMG.menuIcons[1] },
        { label = "兵甲",   key = "equip",     colors = {50, 60, 80},  mod = moduleState.equipment, icon = IMG.menuIcons and IMG.menuIcons[2] },
        { label = "兵甲图录", key = "equipCodex", colors = {45, 55, 75}, mod = moduleState.equipment, icon = IMG.menuIcons and IMG.menuIcons[3] },
        { label = "武技",   key = "skillCodex", colors = {55, 40, 75},  mod = moduleState.skills,    icon = IMG.menuIcons and IMG.menuIcons[4] },
        { label = "天命赐福", key = "welfare",  colors = {80, 50, 40},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[5] },
        { label = "每日任务", key = "progress", colors = {50, 65, 50},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[6] },
    }

    -- 计算内容总高度
    local leftContentH = #leftButtons * sideBtnH + (#leftButtons - 1) * sideGap
    local leftMaxScroll = math.max(0, leftContentH - leftViewH)

    -- 更新滚动状态的元信息 (供拖拽交互使用)
    leftSidebarScroll.contentH = leftContentH
    leftSidebarScroll.viewH = leftViewH
    leftSidebarScroll.areaRect = { x = 0, y = leftStartY, w = sideBtnW + sideX * 2, h = leftViewH }

    -- 限制滚动范围
    leftSidebarScroll.y = math.max(0, math.min(leftSidebarScroll.y, leftMaxScroll))
    local scrollOff = leftSidebarScroll.y

    -- 开启裁剪区域
    nvgSave(vg)
    nvgScissor(vg, 0, leftStartY, sideBtnW + sideX * 2 + 4, leftViewH)

    local leftRects = {}
    for i, lb in ipairs(leftButtons) do
        local by = leftStartY + (i - 1) * (sideBtnH + sideGap) - scrollOff
        -- 仅渲染可见范围内的按钮
        if by + sideBtnH > leftStartY - 10 and by < leftEndY + 10 then
            local bPulse = 0.85 + 0.15 * math.sin(t * 2.0 + i)
            DrawSideBtn(sideX, by, sideBtnW, sideBtnH, lb.label, lb.colors, bPulse, false, lb.icon)

            -- 模块未就绪遮罩
            if lb.mod and not lb.mod.ready then
                nvgBeginPath(vg); nvgRoundedRect(vg, sideX, by, sideBtnW, sideBtnH, 8)
                nvgFillColor(vg, nvgRGBA(10, 12, 20, 140)); nvgFill(vg)
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 19)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(sideX + sideBtnW / 2, by + sideBtnH / 2, math.floor(lb.mod.progress * 100) .. "%")
            end
        end
        leftRects[i] = { x = sideX, y = by, w = sideBtnW, h = sideBtnH }
        menuBtnRects[lb.key] = leftRects[i]
    end

    -- 左侧红点 (按 key 查找，在裁剪区域内绘制)
    local function DrawKeyRedDot(key)
        local r = menuBtnRects[key]
        if r then DrawRedDot(r.x + r.w - 6, r.y + 6, 6) end
    end
    if HasEquipRedDot() then DrawKeyRedDot("equip") end
    if HasSkillRedDot() then DrawKeyRedDot("skillCodex") end
    if HasProgressRedDot() then DrawKeyRedDot("progress") end
    -- 邮件红点
    local hasUnreadMail = false
    for _, md in ipairs(welfareState.mailDefs) do
        if not welfareState.mail.claimed[md.id] then hasUnreadMail = true; break end
    end
    if not hasUnreadMail then
        for _, cm in ipairs(CloudManager._mailInbox or {}) do
            if not CloudManager.IsMailClaimed(cm.id) and #(cm.rewards or {}) > 0 then
                hasUnreadMail = true; break
            end
        end
    end
    if hasUnreadMail then DrawKeyRedDot("mailBox") end
    -- 好友请求红点 (定时轮询, 首次5秒后检查, 之后每30秒)
    local now = os.time()
    local friendCheckInterval = friendsUI.pendingReqChecked and 30 or 5  -- 首次5秒, 之后30秒
    if now - friendsUI.lastReqCheckTime >= friendCheckInterval
       and rawget(_G, "CloudManager")
       and CloudManager.CheckIncomingRequests then
        friendsUI.lastReqCheckTime = now
        CloudManager.CheckIncomingRequests(function(reqs)
            friendsUI.pendingReqCount = reqs and #reqs or 0
            friendsUI.pendingReqChecked = true
        end)
    end
    if friendsUI.pendingReqCount > 0 then DrawKeyRedDot("friends") end
    -- 阵营申请红点 (仅盟主/副盟主, 定时轮询, 首次5秒后检查)
    do
        local fInfo = rawget(_G, "CloudManager") and CloudManager.GetFactionInfo and CloudManager.GetFactionInfo()
        if fInfo and (fInfo.role == "leader" or fInfo.role == "vice_leader") then
            local now2 = os.time()
            local factionCheckInterval = factionUI.pendingAppChecked and 30 or 5
            if now2 - factionUI.lastAppCheckTime >= factionCheckInterval
               and CloudManager.CheckFactionApplications then
                factionUI.lastAppCheckTime = now2
                CloudManager.CheckFactionApplications(function(apps)
                    factionUI.pendingAppCount = apps and #apps or 0
                    factionUI.pendingAppChecked = true
                end)
            end
            if factionUI.pendingAppCount > 0 then DrawKeyRedDot("faction") end
        end
    end

    -- 结束裁剪
    nvgRestore(vg)

    -- 滚动箭头提示 (当内容超出可见区域时，在侧栏外侧显示动态箭头)
    if leftMaxScroll > 0 then
        local arrowX = sideX + sideBtnW / 2
        local arrowBob = math.sin(t * 3.0) * 4  -- 上下浮动动画
        -- 上箭头 (可向上滚动时显示)
        if scrollOff > 2 then
            local upY = leftStartY - 14 + arrowBob
            local arrowA = math.min(200, math.floor(scrollOff / leftMaxScroll * 200 + 60))
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, arrowA))
            nvgText(vg, arrowX, upY, "▲", nil)
        end
        -- 下箭头 (可向下滚动时显示)
        if scrollOff < leftMaxScroll - 2 then
            local downY = leftEndY + 4 - arrowBob
            local arrowA = math.min(200, math.floor((1 - scrollOff / leftMaxScroll) * 200 + 60))
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, arrowA))
            nvgText(vg, arrowX, downY, "▼", nil)
        end
    end

    --[=[ 已移除右侧栏 (排位/爬塔/讨伐/副本/探索)
    -- 右侧挑战模式已全部删除, 30s打桩也已移除
    --]=]

    -- 30s 打桩按钮 (右上角小按钮)
    do
        local dummyBtnW = 70
        local dummyBtnH = 36
        local dummyBtnX = W - dummyBtnW - 10
        local dummyBtnY = centerAreaTop + 12
        local dummyPulse = 0.85 + 0.15 * math.sin(t * 3.5)
        nvgBeginPath(vg); nvgRoundedRect(vg, dummyBtnX + 2, dummyBtnY + 2, dummyBtnW, dummyBtnH, 6)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 50)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, dummyBtnX, dummyBtnY, dummyBtnW, dummyBtnH, 6)
        local dummyGrad = nvgLinearGradient(vg, dummyBtnX, dummyBtnY, dummyBtnX, dummyBtnY + dummyBtnH,
            nvgRGBA(180, 55, 30, math.floor(220 * dummyPulse)),
            nvgRGBA(140, 30, 15, math.floor(235 * dummyPulse)))
        nvgFillPaint(vg, dummyGrad); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(20, 15, 10, math.floor(200 * dummyPulse))); nvgStrokeWidth(vg, 2.0); nvgStroke(vg)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(dummyBtnX + dummyBtnW / 2, dummyBtnY + dummyBtnH / 2, "30s")
        dummyState.btnRect = { x = dummyBtnX, y = dummyBtnY, w = dummyBtnW, h = dummyBtnH }
        -- 30s打桩 战斗模块未就绪遮罩
        if not moduleState.battle.ready then
            nvgBeginPath(vg); nvgRoundedRect(vg, dummyBtnX, dummyBtnY, dummyBtnW, dummyBtnH, 6)
            nvgFillColor(vg, nvgRGBA(80, 60, 30, 160)); nvgFill(vg)
        end
    end

    -- ===========================
    -- 5.5 右侧卷轴面板 (图片素材 + 按钮叠加)
    -- ===========================
    do
        -- 面板尺寸和位置 (素材原始比例 429:768 ≈ 9:16)
        local rpH = H * 0.88            -- 面板高度占屏幕88%
        local rpW = rpH * (600 / 804)   -- 加宽后素材比例 600:804
        local rpX = W - rpW - 12        -- 右侧留边距
        local rpY = (H - rpH) / 2       -- 垂直居中

        -- 绘制卷轴面板图片
        if IMG.scrollPanel and IsImageReady(IMG.scrollPanel) then
            local pat = nvgImagePattern(vg, rpX, rpY, rpW, rpH, 0, IMG.scrollPanel, 1.0)
            nvgBeginPath(vg); nvgRect(vg, rpX, rpY, rpW, rpH)
            nvgFillPaint(vg, pat); nvgFill(vg)
        end

        -- 面板内按钮配置
        local rpBtns = {
            { label = "乱世征途", key = "rpBattle",    primary = true },
            { label = "角色养成", key = "rpCodex",     primary = false },
            { label = "设置",     key = "rpSettings",  primary = false },
            { label = "退出",     key = "rpExit",      primary = false },
        }

        -- 按钮布局 (在卷轴内部区域居中排列)
        local innerX = rpX + rpW * 0.12   -- 卷轴内边距
        local innerW = rpW * 0.76         -- 按钮可用宽度
        local rpBtnW = innerW
        local rpBtnH = rpH * 0.09         -- 按钮高度
        local rpBtnGap = rpH * 0.04       -- 按钮间距
        local totalBtnH = #rpBtns * rpBtnH + (#rpBtns - 1) * rpBtnGap
        local rpBtnStartY = rpY + (rpH - totalBtnH) / 2  -- 在面板内垂直居中
        local rpBtnX = innerX

        for i, rb in ipairs(rpBtns) do
            local by = rpBtnStartY + (i - 1) * (rpBtnH + rpBtnGap)
            local isPrimary = rb.primary
            local bPulse = isPrimary and (0.7 + 0.3 * math.sin(t * 2.5)) or 1.0

            -- 按钮图片素材背景
            local btnImg = isPrimary and IMG.btnMenuPrimary or IMG.btnMenuNormal
            if btnImg and IsImageReady(btnImg) then
                local btnAlpha = isPrimary and bPulse or 1.0
                local btnPat = nvgImagePattern(vg, rpBtnX, by, rpBtnW, rpBtnH, 0, btnImg, btnAlpha)
                nvgBeginPath(vg); nvgRoundedRect(vg, rpBtnX, by, rpBtnW, rpBtnH, 6)
                nvgFillPaint(vg, btnPat); nvgFill(vg)
            else
                -- 素材未就绪时回退纯色
                nvgBeginPath(vg); nvgRoundedRect(vg, rpBtnX, by, rpBtnW, rpBtnH, 6)
                nvgFillColor(vg, isPrimary and nvgRGBA(160, 40, 20, 200) or nvgRGBA(120, 95, 60, 200))
                nvgFill(vg)
            end

            -- 主按钮外发光
            if isPrimary then
                local glow = nvgRadialGradient(vg,
                    rpBtnX + rpBtnW / 2, by + rpBtnH / 2,
                    rpBtnW * 0.2, rpBtnW * 0.55,
                    nvgRGBA(255, 180, 60, math.floor(30 * bPulse)), nvgRGBA(255, 180, 60, 0))
                nvgBeginPath(vg)
                nvgRoundedRect(vg, rpBtnX - 10, by - 6, rpBtnW + 20, rpBtnH + 12, 10)
                nvgFillPaint(vg, glow); nvgFill(vg)
            end

            -- 按钮文字
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, isPrimary and 22 or 19)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            -- 文字阴影
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 60))
            nvgText(vg, rpBtnX + rpBtnW / 2 + 1, by + rpBtnH / 2 + 1, rb.label, nil)
            -- 文字正体
            if isPrimary then
                DrawWhiteInkText(rpBtnX + rpBtnW / 2, by + rpBtnH / 2, rb.label)
            else
                nvgFillColor(vg, nvgRGBA(240, 225, 190, 240))
                nvgText(vg, rpBtnX + rpBtnW / 2, by + rpBtnH / 2, rb.label, nil)
            end

            -- 存储按钮点击区域
            menuBtnRects[rb.key] = { x = rpBtnX, y = by, w = rpBtnW, h = rpBtnH }
        end
    end

    -- ===========================
    -- 6. 底部操作栏 (横排5按钮, 仿参考图)
    -- ===========================
    -- 底栏背景 (国风暖色横条)
    local barBgGrad = nvgLinearGradient(vg, 0, bottomBarY - 8, 0, bottomBarY + bottomBarH,
        nvgRGBA(120, 80, 40, 0), nvgRGBA(90, 55, 25, 180))
    nvgBeginPath(vg); nvgRect(vg, 0, bottomBarY - 8, W, bottomBarH + 16)
    nvgFillPaint(vg, barBgGrad); nvgFill(vg)
    -- 顶部金色分隔线
    local sepGradL = nvgLinearGradient(vg, 0, bottomBarY - 2, W, bottomBarY - 2,
        nvgRGBA(255, 200, 80, 0), nvgRGBA(255, 200, 80, 150))
    nvgBeginPath(vg); nvgMoveTo(vg, 0, bottomBarY - 2); nvgLineTo(vg, cx, bottomBarY - 2)
    nvgStrokeWidth(vg, 1.5); nvgStrokePaint(vg, sepGradL); nvgStroke(vg)
    local sepGradR = nvgLinearGradient(vg, cx, bottomBarY - 2, W, bottomBarY - 2,
        nvgRGBA(255, 200, 80, 150), nvgRGBA(255, 200, 80, 0))
    nvgBeginPath(vg); nvgMoveTo(vg, cx, bottomBarY - 2); nvgLineTo(vg, W, bottomBarY - 2)
    nvgStrokeWidth(vg, 1.5); nvgStrokePaint(vg, sepGradR); nvgStroke(vg)

    -- 底栏按钮配置 (6个, 带图标, 横屏适配)
    local botBtnCount = 6
    local botPad = 80  -- 左侧留出侧栏空间
    local botTotalW = W - botPad - 10
    local botBtnW = (botTotalW - (botBtnCount - 1) * 6) / botBtnCount
    local botBtnH = 62
    local botBtnY = bottomBarY + (bottomBarH - botBtnH) / 2

    local bottomButtons = {
        { label = "设置",     key = "settings",  colors = {40, 35, 55},  primary = false, mod = nil, icon = IMG.menuIcons and IMG.menuIcons[13] },
        { label = "战令",     key = "battlepass", colors = {120, 70, 30}, primary = false, mod = nil, icon = IMG.dragonPortal },
        { label = "战力榜",   key = "powerRank",  colors = {35, 40, 65},  primary = false, mod = nil, icon = IMG.menuIcons and IMG.menuIcons[12] },
        { label = "兵符召唤", key = "gachaSeal",  colors = {80, 50, 130}, primary = false, mod = nil, icon = IMG.sealItem1 },
        { label = "武技召唤", key = "gachaSkill", colors = {50, 100, 80}, primary = false, mod = moduleState.skills, icon = IMG.menuIcons and IMG.menuIcons[4] },
        { label = "乱世征途", key = "battle",     colors = {180, 45, 25}, primary = true,  mod = moduleState.battle, icon = IMG.abyssTicket },
    }

    local pulse = 0.7 + 0.3 * math.sin(t * 2.5)
    for i, bb in ipairs(bottomButtons) do
        local bx = botPad + (i - 1) * (botBtnW + 6)
        local by = botBtnY
        local isPrimary = bb.primary
        local bPulse = isPrimary and pulse or (0.85 + 0.15 * math.sin(t * 2.0 + i))

        -- 纯图标+文字，无任何背景 (横屏适配)
        local hasIcon = bb.icon and IsImageReady(bb.icon)
        if hasIcon then
            local iconSize
            if isPrimary then
                iconSize = math.floor(math.min(botBtnW * 0.70, botBtnH * 0.70))
            else
                iconSize = math.floor(math.min(botBtnW * 0.55, botBtnH * 0.55))
            end
            local iconX = bx + (botBtnW - iconSize) / 2
            local iconY = isPrimary and (by - 2) or (by + 2)
            local pat = nvgImagePattern(vg, iconX, iconY, iconSize, iconSize, 0, bb.icon, 1.0)
            nvgBeginPath(vg); nvgRect(vg, iconX, iconY, iconSize, iconSize)
            nvgFillPaint(vg, pat); nvgFill(vg)
            -- 文字
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, isPrimary and 16 or 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            DrawWhiteInkText(bx + botBtnW / 2, by + botBtnH - 1, bb.label)
        else
            nvgFontFaceId(vg, GetMainFont())
            local fontSize = isPrimary and 22 or 20
            nvgFontSize(vg, fontSize)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + botBtnW / 2, by + botBtnH / 2, bb.label)
        end

        -- 存储点击区域
        local rect = { x = bx, y = by, w = botBtnW, h = botBtnH }
        -- 模块未就绪遮罩 (通用)
        if bb.mod and not bb.mod.ready then
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, botBtnW, botBtnH, 8)
            nvgFillColor(vg, nvgRGBA(10, 12, 20, 140)); nvgFill(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 19)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + botBtnW/2, by + botBtnH/2, math.floor(bb.mod.progress * 100) .. "%")
        end
        if bb.key == "battle" then
            menuBtnRects.battle = rect
        elseif bb.key == "gachaSeal" then
            menuBtnRects.gachaSeal = rect
        elseif bb.key == "gachaSkill" then
            menuBtnRects.gachaSkill = rect
            -- 武技碎片红点
            local hasComposable = false
            for _, cnt in pairs(skillFragments) do
                if cnt >= SKILL_FRAG_EXCHANGE then hasComposable = true; break end
            end
            if hasComposable then DrawRedDot(bx + botBtnW - 6, by + 6, 6) end
        elseif bb.key == "battlepass" then
            menuBtnRects.battlepass = rect
            -- 战令红点
            if HasBattlePassRedDot() then DrawRedDot(bx + botBtnW - 6, by + 6, 6) end
        elseif bb.key == "powerRank" then
            menuBtnRects.powerRank = rect
        elseif bb.key == "settings" then
            settingsPage.btnRect = rect
        end
    end

    menuBtnRects.editor = nil

    -- ===========================
    -- 6.5 世界聊天 (底栏上方, 正中)
    -- ===========================
    do
        local msgs = CloudManager.GetWorldChatMessages()
        worldChatUI.miniAnim = (worldChatUI.miniAnim or 0) + (1.0 / 60.0)

        if not worldChatUI.expanded then
            -- ── 小窗模式: 显示最新一条消息 ──
            local miniW = math.min(W * 0.6, 340)
            local miniH = 32
            local miniX = (W - miniW) / 2
            local miniY = bottomBarY - miniH - 6
            -- 半透明背景 (暖色)
            nvgBeginPath(vg); nvgRoundedRect(vg, miniX, miniY, miniW, miniH, 6)
            nvgFillColor(vg, nvgRGBA(220, 200, 160, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 120)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            -- 频道标签
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(160, 80, 20, 220))
            nvgText(vg, miniX + 8, miniY + miniH / 2, "【世界】", nil)
            -- 最新消息内容
            if #msgs > 0 then
                local last = msgs[#msgs]
                local displayText = (last.name or "?") .. ": " .. (last.text or "")
                if utf8.len(displayText) > 20 then
                    displayText = string.sub(displayText, 1, utf8.offset(displayText, 21) - 1) .. "..."
                end
                nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(60, 40, 20, 200))
                nvgText(vg, miniX + 58, miniY + miniH / 2, displayText, nil)
            else
                nvgFontSize(vg, 13); nvgFillColor(vg, nvgRGBA(120, 90, 50, 150))
                nvgText(vg, miniX + 58, miniY + miniH / 2, "点击打开世界聊天...", nil)
            end
            menuBtnRects.worldChatMini = { x = miniX, y = miniY, w = miniW, h = miniH }
        else
            -- ── 展开模式: 大聊天窗口 ──
            local chatW = math.min(W * 0.88, 460)
            local chatH = math.min(H * 0.55, 420)
            local chatX = (W - chatW) / 2
            local chatY = (H - chatH) / 2

            -- 遮罩
            nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 120)); nvgFill(vg)

            -- 窗口背景 (暖色卷轴)
            nvgBeginPath(vg); nvgRoundedRect(vg, chatX, chatY, chatW, chatH, 12)
            nvgFillColor(vg, nvgRGBA(235, 215, 175, 240)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

            -- 标题栏 (暖色深棕)
            local titleH2 = 36
            nvgBeginPath(vg); nvgRoundedRect(vg, chatX, chatY, chatW, titleH2, 12)
            nvgFillColor(vg, nvgRGBA(140, 90, 40, 220)); nvgFill(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
            nvgText(vg, chatX + chatW / 2, chatY + titleH2 / 2, "世界聊天", nil)
            -- 关闭按钮
            local closeBtnS = 28
            local closeBtnX = chatX + chatW - closeBtnS - 4
            local closeBtnY2 = chatY + (titleH2 - closeBtnS) / 2
            nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 180, 200))
            nvgText(vg, closeBtnX + closeBtnS / 2, closeBtnY2 + closeBtnS / 2, "X", nil)
            menuBtnRects.worldChatClose = { x = closeBtnX, y = closeBtnY2, w = closeBtnS, h = closeBtnS }

            -- 消息区域
            local msgAreaY = chatY + titleH2 + 4
            local inputH = 40
            local msgAreaH = chatH - titleH2 - inputH - 12
            nvgSave(vg)
            nvgScissor(vg, chatX + 4, msgAreaY, chatW - 8, msgAreaH)

            local avS = 24  -- 头像尺寸
            local lineH = avS + 6  -- 每条消息行高
            local maxVisible = math.floor(msgAreaH / lineH)
            -- 自动滚到底
            if #msgs ~= worldChatUI.lastMsgCount then
                worldChatUI.lastMsgCount = #msgs
                worldChatUI.scrollOffset = math.max(0, #msgs - maxVisible)
            end
            local startIdx = math.max(1, #msgs - maxVisible - worldChatUI.scrollOffset + 1)
            local endIdx = math.min(#msgs, startIdx + maxVisible - 1)

            worldChatUI._avatarRects = {}
            for i = startIdx, endIdx do
                local m = msgs[i]
                local row = i - startIdx
                local my2 = msgAreaY + row * lineH + 3
                -- 头像 (可点击)
                local avX = chatX + 8
                local avY = my2
                local avIdx = m.av or 1
                if IMG.avatarSheet >= 0 then
                    local avData = AVATAR_DATA[avIdx] or AVATAR_DATA[1]
                    local imgW2, imgH2 = 512, 768
                    local cellW2 = imgW2 / AVATAR_COLS
                    local cellH2 = imgH2 / AVATAR_ROWS
                    local sx2 = avData.col * cellW2
                    local sy2 = avData.row * cellH2
                    -- 头像底框
                    nvgBeginPath(vg); nvgRoundedRect(vg, avX - 1, avY - 1, avS + 2, avS + 2, 4)
                    nvgFillColor(vg, nvgRGBA(180, 150, 100, 150)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(160, 120, 60, 150)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    local pat2 = nvgImagePattern(vg, avX - sx2 * (avS / cellW2),
                        avY - sy2 * (avS / cellH2),
                        imgW2 * (avS / cellW2), imgH2 * (avS / cellH2), 0, IMG.avatarSheet, 1.0)
                    nvgBeginPath(vg); nvgRoundedRect(vg, avX, avY, avS, avS, 3)
                    nvgFillPaint(vg, pat2); nvgFill(vg)
                else
                    -- 无头像图时画默认色块
                    nvgBeginPath(vg); nvgRoundedRect(vg, avX, avY, avS, avS, 3)
                    nvgFillColor(vg, nvgRGBA(180, 150, 100, 200)); nvgFill(vg)
                end
                -- 记录头像点击区域
                if m.uid and m.uid > 0 then
                    worldChatUI._avatarRects[#worldChatUI._avatarRects + 1] = {
                        x = avX, y = avY, w = avS, h = avS,
                        uid = m.uid, name = m.name or "???", av = avIdx,
                    }
                end
                -- 名字
                local textX = avX + avS + 6
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(140, 70, 20, 220))
                local nameOnlyStr = m.name or "???"
                nvgText(vg, textX, my2, nameOnlyStr, nil)
                -- 内容 (第二行)
                nvgFontSize(vg, 14)
                nvgFillColor(vg, nvgRGBA(60, 40, 20, 220))
                nvgText(vg, textX, my2 + 14, m.text or "", nil)
            end
            nvgRestore(vg)

            -- 玩家信息弹窗（点击头像弹出：头像 + 名字 + 添加好友按钮）
            if worldChatUI.namePopup then
                local pp = worldChatUI.namePopup
                local ppW, ppH = 160, 60
                local ppX = math.min(pp.x + avS + 4, chatX + chatW - ppW - 8)
                local ppY = pp.y - 4
                if ppY + ppH > chatY + chatH - 50 then ppY = pp.y - ppH - 4 end
                if ppY < chatY + titleH2 then ppY = chatY + titleH2 + 4 end
                -- 弹窗背景 (暖色)
                nvgBeginPath(vg); nvgRoundedRect(vg, ppX, ppY, ppW, ppH, 8)
                nvgFillColor(vg, nvgRGBA(240, 225, 190, 245)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 200)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
                -- 弹窗内头像
                local ppAvS = 32
                local ppAvX = ppX + 8
                local ppAvY = ppY + (ppH - ppAvS) / 2
                local ppAvIdx = pp.av or 1
                if IMG.avatarSheet >= 0 then
                    local avData = AVATAR_DATA[ppAvIdx] or AVATAR_DATA[1]
                    local imgW2, imgH2 = 512, 768
                    local cellW2 = imgW2 / AVATAR_COLS
                    local cellH2 = imgH2 / AVATAR_ROWS
                    local sx2 = avData.col * cellW2
                    local sy2 = avData.row * cellH2
                    nvgBeginPath(vg); nvgRoundedRect(vg, ppAvX - 1, ppAvY - 1, ppAvS + 2, ppAvS + 2, 4)
                    nvgFillColor(vg, nvgRGBA(180, 150, 100, 150)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(160, 120, 60, 160)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    local pat3 = nvgImagePattern(vg, ppAvX - sx2 * (ppAvS / cellW2),
                        ppAvY - sy2 * (ppAvS / cellH2),
                        imgW2 * (ppAvS / cellW2), imgH2 * (ppAvS / cellH2), 0, IMG.avatarSheet, 1.0)
                    nvgBeginPath(vg); nvgRoundedRect(vg, ppAvX, ppAvY, ppAvS, ppAvS, 3)
                    nvgFillPaint(vg, pat3); nvgFill(vg)
                end
                -- 名字
                local ppTxtX = ppAvX + ppAvS + 8
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 15)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(80, 40, 10, 240))
                nvgText(vg, ppTxtX, ppY + ppH / 2 - 8, pp.name or "???", nil)
                -- 添加好友按钮
                local addBtnW, addBtnH = 70, 22
                local addBtnX = ppTxtX
                local addBtnY = ppY + ppH / 2 + 6
                local isFriend = CloudManager.IsFriend(pp.uid)
                local isMe = (rawget(_G, "clientCloud") and pp.uid == clientCloud.userId)
                if isMe then
                    nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(120, 90, 50, 180))
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgText(vg, addBtnX, addBtnY + addBtnH / 2, "（自己）", nil)
                elseif isFriend then
                    nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(40, 130, 60, 200))
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgText(vg, addBtnX, addBtnY + addBtnH / 2, "已是好友", nil)
                else
                    nvgBeginPath(vg); nvgRoundedRect(vg, addBtnX, addBtnY, addBtnW, addBtnH, 4)
                    nvgFillColor(vg, nvgRGBA(40, 100, 60, 220)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100, 220, 140, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(100, 240, 140, 255))
                    nvgText(vg, addBtnX + addBtnW / 2, addBtnY + addBtnH / 2, "+ 加好友", nil)
                    menuBtnRects.worldChatAddFriend = { x = addBtnX, y = addBtnY, w = addBtnW, h = addBtnH, uid = pp.uid, name = pp.name }
                end
                -- 整个弹窗区域（点击外部关闭用）
                menuBtnRects.worldChatPopupArea = { x = ppX, y = ppY, w = ppW, h = ppH }
                if not menuBtnRects.worldChatAddFriend or isMe or isFriend then
                    menuBtnRects.worldChatAddFriend = nil
                end
            else
                menuBtnRects.worldChatAddFriend = nil
                menuBtnRects.worldChatPopupArea = nil
            end

            -- 输入区域
            local inputY = chatY + chatH - inputH - 4
            local sendBtnW = 56
            local inputW = chatW - sendBtnW - 20
            -- 输入框背景 (暖色)
            nvgBeginPath(vg); nvgRoundedRect(vg, chatX + 8, inputY, inputW, inputH - 4, 6)
            nvgFillColor(vg, nvgRGBA(255, 245, 225, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 120)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            -- 输入框文字
            nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if worldChatUI.chatInput and #worldChatUI.chatInput > 0 then
                nvgFillColor(vg, nvgRGBA(50, 30, 10, 230))
                nvgText(vg, chatX + 14, inputY + (inputH - 4) / 2, worldChatUI.chatInput, nil)
            else
                nvgFillColor(vg, nvgRGBA(150, 120, 80, 150))
                nvgText(vg, chatX + 14, inputY + (inputH - 4) / 2, "输入消息...", nil)
            end
            menuBtnRects.worldChatInput = { x = chatX + 8, y = inputY, w = inputW, h = inputH - 4 }
            -- 发送按钮
            local sendX = chatX + chatW - sendBtnW - 8
            nvgBeginPath(vg); nvgRoundedRect(vg, sendX, inputY, sendBtnW, inputH - 4, 6)
            nvgFillColor(vg, nvgRGBA(160, 90, 30, 220)); nvgFill(vg)
            nvgFontSize(vg, 17); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 245, 220, 240))
            nvgText(vg, sendX + sendBtnW / 2, inputY + (inputH - 4) / 2, "发送", nil)
            menuBtnRects.worldChatSend = { x = sendX, y = inputY, w = sendBtnW, h = inputH - 4 }
        end
    end

    -- ===========================
    -- 7. 左上角玩家面板 (横屏适配)
    -- ===========================
    local panelW = 200
    local panelH = 70
    local panelX = 6
    local panelY = 4

    -- 面板背景 (国风暖色卷轴)
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX + 3, panelY + 3, panelW, panelH, 8)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 50)); nvgFill(vg)
    local panelGrad = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + panelH,
        nvgRGBA(235, 215, 175, 220), nvgRGBA(215, 195, 155, 230))
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 8)
    nvgFillPaint(vg, panelGrad); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 180)); nvgStrokeWidth(vg, 2.5); nvgStroke(vg)

    -- 头像 (横屏缩小)
    local avatarSize = 40
    local avatarX = panelX + 6
    local avatarY = panelY + (panelH - avatarSize) / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, avatarX - 2, avatarY - 2, avatarSize + 4, avatarSize + 4, 4)
    nvgFillColor(vg, nvgRGBA(160, 120, 60, 120)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    if IMG.avatarSheet >= 0 then
        local avData = AVATAR_DATA[playerInfo.avatarIdx] or AVATAR_DATA[1]
        local imgW, imgH = 512, 768
        local cellW = imgW / AVATAR_COLS
        local cellH = imgH / AVATAR_ROWS
        local sx = avData.col * cellW
        local sy = avData.row * cellH
        local pat = nvgImagePattern(vg, avatarX - sx * (avatarSize / cellW),
            avatarY - sy * (avatarSize / cellH),
            imgW * (avatarSize / cellW), imgH * (avatarSize / cellH), 0, IMG.avatarSheet, 1.0)
        nvgBeginPath(vg); nvgRoundedRect(vg, avatarX, avatarY, avatarSize, avatarSize, 3)
        nvgFillPaint(vg, pat); nvgFill(vg)
    end

    -- 文字信息 (三行紧凑: 名字 / 官职 / 战力)
    local infoX = avatarX + avatarSize + 6
    local infoTopY = panelY + 8
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local maxTextW = panelX + panelW - infoX - 6
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 16)
    local displayName = playerInfo.name
    local nameW = nvgTextBounds(vg, 0, 0, displayName, nil)
    if nameW > maxTextW then
        while #displayName > 2 do
            displayName = string.sub(displayName, 1, #displayName - 3)
            local w = nvgTextBounds(vg, 0, 0, displayName .. "..", nil)
            if w <= maxTextW then displayName = displayName .. ".."; break end
        end
    end
    nvgFillColor(vg, nvgRGBA(255, 245, 220, 160))
    for _, off in ipairs({{-0.5,0},{0.5,0},{0,-0.5},{0,0.5}}) do
        _nvgTextOrig(vg, infoX + off[1], infoTopY + off[2], displayName, nil)
    end
    nvgFillColor(vg, nvgRGBA(60, 30, 10, 240))
    _nvgTextOrig(vg, infoX, infoTopY, displayName, nil)

    local rankName = GetRankDisplayName()
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(180, 60, 50, 220))
    nvgText(vg, infoX, infoTopY + 18, rankName, nil)

    -- 战力 (第三行, 在名字/官职下方)
    local totalPwr = CalcPlayerTotalPower()
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local statX = infoX
    local statY = infoTopY + 34
    nvgFillColor(vg, nvgRGBA(255, 240, 210, 120))
    nvgText(vg, statX + 0.5, statY + 0.5, "战力 " .. FormatPower(totalPwr), nil)
    nvgFillColor(vg, nvgRGBA(80, 50, 20, 230))
    nvgText(vg, statX, statY, "战力 " .. FormatPower(totalPwr), nil)

    -- 战力 "?" 按钮
    local pwrTextW = nvgTextBounds(vg, 0, 0, "战力 " .. FormatPower(totalPwr), nil)
    local qBtnX = statX + pwrTextW + 4
    local qBtnY = statY - 1
    local qBtnS = 14
    nvgBeginPath(vg); nvgCircle(vg, qBtnX + qBtnS/2, qBtnY + qBtnS/2, qBtnS/2)
    nvgFillColor(vg, nvgRGBA(160, 120, 50, 160)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 80, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(60, 30, 10, 230))
    nvgText(vg, qBtnX + qBtnS/2, qBtnY + qBtnS/2, "?", nil)
    menuBtnRects.powerHelp = { x = qBtnX, y = qBtnY, w = qBtnS, h = qBtnS }

    playerDetailBtnRect = { x = panelX, y = panelY, w = panelW, h = panelH }

    -- ===========================
    -- 8. 右上角虎符显示 + 广告
    -- ===========================
    local jadeBoxW = 160
    local jadeBoxH = 28
    local jadeBoxX = W - jadeBoxW - 10
    local jadeBoxY = 4

    nvgBeginPath(vg); nvgRoundedRect(vg, jadeBoxX + 2, jadeBoxY + 2, jadeBoxW, jadeBoxH, 6)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 40)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, jadeBoxX, jadeBoxY, jadeBoxW, jadeBoxH, 6)
    nvgFillColor(vg, nvgRGBA(230, 210, 170, 210)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 180)); nvgStrokeWidth(vg, 2.0); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(jadeBoxX + 5, jadeBoxY + jadeBoxH / 2, "虎符")
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(jadeBoxX + jadeBoxW - 32, jadeBoxY + jadeBoxH / 2, FormatJade(playerInfo.jade))

    -- 广告 (+)
    local adBtnW = 30
    local adBtnH = 22
    local adBtnX = jadeBoxX + jadeBoxW - adBtnW - 3
    local adBtnY = jadeBoxY + (jadeBoxH - adBtnH) / 2
    local adPulse = 0.7 + 0.3 * math.sin(t * 3)
    nvgBeginPath(vg); nvgRoundedRect(vg, adBtnX + 1, adBtnY + 1, adBtnW, adBtnH, 4)
    nvgFillColor(vg, nvgRGBA(60, 30, 10, 40)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, adBtnX, adBtnY, adBtnW, adBtnH, 4)
    nvgFillColor(vg, nvgRGBA(200, 60, 40, math.floor(210 * adPulse))); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 170)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(adBtnX + adBtnW/2, adBtnY + adBtnH/2, "+")
    local adPad = 6
    adRects.jade = { x = adBtnX - adPad, y = adBtnY - adPad, w = adBtnW + adPad*2, h = adBtnH + adPad*2 }
    -- 广告提示
    nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(180, 50, 30, math.floor(160 * adPulse)))
    nvgText(vg, jadeBoxX + jadeBoxW / 2, jadeBoxY + jadeBoxH + 1, "+2000虎符", nil)

    -- ===========================
    -- 9. 下载按钮 + 下载面板
    -- ===========================
    local allModulesReady = moduleState.equipment.ready and moduleState.heroes.ready
        and moduleState.skills.ready and moduleState.battle.ready
    if not allModulesReady then
        local dlBtnW = 72
        local dlBtnH = 24
        local dlBtnX = W - dlBtnW - 10
        local dlBtnY = jadeBoxY + jadeBoxH + 18
        local totalProg = (moduleState.equipment.progress + moduleState.heroes.progress
            + moduleState.skills.progress + moduleState.battle.progress) / 4
        local totalPct = math.floor(totalProg * 100)
        local dlBtnPulse = 0.7 + 0.3 * math.sin(t * 3)
        nvgBeginPath(vg); nvgRoundedRect(vg, dlBtnX, dlBtnY, dlBtnW, dlBtnH, 4)
        nvgFillColor(vg, nvgRGBA(220, 200, 160, 200)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 140, 60, math.floor(160 * dlBtnPulse))); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        local miniBarH = 2
        local miniBarY2 = dlBtnY + dlBtnH - miniBarH - 2
        local miniBarX = dlBtnX + 4
        local miniBarW = dlBtnW - 8
        nvgBeginPath(vg); nvgRoundedRect(vg, miniBarX, miniBarY2, miniBarW, miniBarH, 1)
        nvgFillColor(vg, nvgRGBA(160, 130, 80, 120)); nvgFill(vg)
        local miniFillW = miniBarW * totalProg
        if miniFillW > 1 then
            nvgBeginPath(vg); nvgRoundedRect(vg, miniBarX, miniBarY2, miniFillW, miniBarH, 1)
            nvgFillColor(vg, nvgRGBA(160, 100, 30, 200)); nvgFill(vg)
        end
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(dlBtnX + dlBtnW/2, dlBtnY + (dlBtnH - miniBarH)/2, "下载" .. totalPct .. "%")
        downloadUI.btnRect = { x = dlBtnX, y = dlBtnY, w = dlBtnW, h = dlBtnH }

        if downloadUI.panelOpen then
            local panW = 180
            local panH = 130
            local panX = dlBtnX + dlBtnW - panW
            local panY = dlBtnY + dlBtnH + 4
            nvgBeginPath(vg); nvgRoundedRect(vg, panX, panY, panW, panH, 6)
            nvgFillColor(vg, nvgRGBA(235, 215, 175, 235)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            downloadUI.panelRect = { x = panX, y = panY, w = panW, h = panH }
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            DrawWhiteInkText(panX + panW/2, panY + 6, "资源下载进度")
            local modules = {
                { name = "兵甲", mod = moduleState.equipment },
                { name = "武灵", mod = moduleState.heroes },
                { name = "武技", mod = moduleState.skills },
                { name = "战斗", mod = moduleState.battle },
            }
            local rowH = 22; local rowStartY2 = panY + 24
            local barX2 = panX + 46; local barW2 = panW - 58; local barH2 = 7
            for mi, m in ipairs(modules) do
                local ry = rowStartY2 + (mi - 1) * rowH
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, m.mod.ready and nvgRGBA(40,130,60,220) or nvgRGBA(80,60,40,200))
                nvgText(vg, barX2 - 4, ry + barH2/2, m.name, nil)
                nvgBeginPath(vg); nvgRoundedRect(vg, barX2, ry, barW2, barH2, 3)
                nvgFillColor(vg, nvgRGBA(180, 160, 120, 150)); nvgFill(vg)
                local modFillW = barW2 * m.mod.progress
                if modFillW > 1 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, barX2, ry, modFillW, barH2, 3)
                    nvgFillColor(vg, m.mod.ready and nvgRGBA(60,160,80,220) or nvgRGBA(180,120,40,200)); nvgFill(vg)
                end
                nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if m.mod.ready then
                    DrawWhiteInkText(barX2 + barW2 + 4, ry + barH2/2, "OK")
                else
                    DrawWhiteInkText(barX2 + barW2 + 4, ry + barH2/2, math.floor(m.mod.progress * 100) .. "%")
                end
            end
        end
    else
        downloadUI.btnRect = nil; downloadUI.panelRect = nil; downloadUI.panelOpen = false
    end

    -- ===========================
    -- 10. 漂浮粒子 (金色闪星)
    -- ===========================
    for i = 1, 6 do
        local px = W * (0.15 + 0.7 * ((i * 137 + math.floor(t * 18)) % 100) / 100)
        local py = H * (0.12 + 0.55 * math.sin(t * 0.4 + i * 1.3))
        local sr = 2.2 + math.sin(t * 2 + i) * 1.0
        local pa = math.floor(45 + 35 * math.sin(t * 1.5 + i * 0.7))
        nvgBeginPath(vg)
        nvgMoveTo(vg, px, py - sr); nvgLineTo(vg, px + sr * 0.3, py - sr * 0.3)
        nvgLineTo(vg, px + sr, py); nvgLineTo(vg, px + sr * 0.3, py + sr * 0.3)
        nvgLineTo(vg, px, py + sr); nvgLineTo(vg, px - sr * 0.3, py + sr * 0.3)
        nvgLineTo(vg, px - sr, py); nvgLineTo(vg, px - sr * 0.3, py - sr * 0.3)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(255, 230, 160, pa)); nvgFill(vg)
    end
end


-- ============================================================================
-- 按钮位置调整模式 (战斗场景实时预览, 设计坐标)
-- ============================================================================
function DrawBtnAdjustMode()
    local W = DESIGN_W
    local H = DESIGN_H
    local t = menuAnimTimer

    -- 1. 绘制战斗背景
    if IsImageReady(IMG.bg) then
        local p = nvgImagePattern(vg, 0, 0, W, H, 0, IMG.bg, 1.0)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillPaint(vg, p); nvgFill(vg)
    else
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(25, 22, 16, 255)); nvgFill(vg)
        DrawSpinner(W / 2, H / 2, 20)
    end

    -- 半透明遮罩让按钮更清晰
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 50)); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 2. 绘制战斗区域参考线
    nvgBeginPath(vg)
    nvgRect(vg, BATTLE_ZONE.left, BATTLE_ZONE.top,
        BATTLE_ZONE.right - BATTLE_ZONE.left, BATTLE_ZONE.bottom - BATTLE_ZONE.top)
    nvgStrokeColor(vg, nvgRGBA(100, 90, 60, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 3. 绘制实际大小的三圈按钮（使用与 DrawBottomActionBar 完全相同的布局逻辑）
    local btnSc = settingsPage.adjScale
    local R = math.floor(26 * btnSc)
    local gap = math.floor(6 * btnSc)
    local marginR = 8 + safeInsets.right
    local marginB = 12 + safeInsets.bottom

    local btnOfsX = settingsPage.adjOffsetX
    local btnOfsY = settingsPage.adjOffsetY
    local bottomCY = BATTLE_ZONE.bottom - marginB - R + R * 2 + btnOfsY
    local rightCX = W - marginR - R + btnOfsX
    local leftCX  = rightCX - R * 2 - gap
    local topCX = (leftCX + rightCX) / 2
    local topCY = bottomCY - R * 2 - gap

    -- 绘制三个操作圈
    local circles = {
        { cx = topCX, cy = topCY, label = "自动", sub = "行军" },
        { cx = leftCX, cy = bottomCY, label = "武技", sub = "1" },
        { cx = rightCX, cy = bottomCY, label = "武技", sub = "2" },
    }
    for _, c in ipairs(circles) do
        -- 外发光
        local glowGrad = nvgRadialGradient(vg, c.cx, c.cy, R * 0.8, R * 1.6,
            nvgRGBA(120, 50, 55, 40), nvgRGBA(120, 50, 55, 0))
        nvgBeginPath(vg); nvgCircle(vg, c.cx, c.cy, R * 1.6)
        nvgFillPaint(vg, glowGrad); nvgFill(vg)
        -- 按钮本体
        nvgBeginPath(vg); nvgCircle(vg, c.cx, c.cy, R)
        nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(120, 50, 55, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        -- 文字
        nvgFontSize(vg, math.floor(11 * btnSc))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(c.cx, c.cy - 5 * btnSc, c.label)
        nvgFontSize(vg, math.floor(9 * btnSc))
        DrawWhiteInkText(c.cx, c.cy + 7 * btnSc, c.sub)
    end

    -- 拖拽中的视觉提示 (仅当前选中组高亮)
    local activeGrp = settingsPage.adjActiveGroup or "skill"
    if settingsPage.adjDragging and activeGrp == "skill" then
        for _, c in ipairs(circles) do
            nvgBeginPath(vg); nvgCircle(vg, c.cx, c.cy, R + 3)
            nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        end
    end
    -- 选中高亮框 (技能组)
    if activeGrp == "skill" then
        for _, c in ipairs(circles) do
            nvgBeginPath(vg); nvgCircle(vg, c.cx, c.cy, R + 2)
            nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        end
    end

    -- 3b. 绘制右上角按钮组预览
    local rbOfsX = settingsPage.adjRightBtnOffsetX
    local rbOfsY = settingsPage.adjRightBtnOffsetY
    local rbBtnW = 72
    local rbBtnH = 30
    local rbGap = 6
    local rbRightMargin = 4
    local rbStartY = 28 + rbOfsY
    local rbX = W - rbBtnW - rbRightMargin + rbOfsX
    local rbLabels = { "军资", "刷新", "退出" }
    local rbCurY = rbStartY
    for idx, lbl in ipairs(rbLabels) do
        nvgBeginPath(vg); nvgRoundedRect(vg, rbX, rbCurY, rbBtnW, rbBtnH, 3)
        if idx == #rbLabels then
            nvgFillColor(vg, nvgRGBA(60, 20, 20, 160)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 100, 80, 120))
        else
            nvgFillColor(vg, nvgRGBA(12, 10, 6, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 180, 220, 80))
        end
        nvgStrokeWidth(vg, 0.6); nvgStroke(vg)
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(rbX + rbBtnW / 2, rbCurY + rbBtnH / 2, lbl)
        rbCurY = rbCurY + rbBtnH + rbGap
    end
    if activeGrp == "rightBtn" then
        nvgBeginPath(vg); nvgRoundedRect(vg, rbX - 3, rbStartY - 3, rbBtnW + 6, rbCurY - rbStartY + 3, 4)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end
    if settingsPage.adjDragging and activeGrp == "rightBtn" then
        nvgBeginPath(vg); nvgRoundedRect(vg, rbX - 4, rbStartY - 4, rbBtnW + 8, rbCurY - rbStartY + 4, 5)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- 3c. 绘制顶部HUD预览
    local hudOfsX = settingsPage.adjHudOffsetX
    local hudOfsY = settingsPage.adjHudOffsetY
    local hudH2 = 22
    nvgBeginPath(vg); nvgRoundedRect(vg, 4 + hudOfsX, 2 + hudOfsY, W - 8, hudH2, 4)
    nvgFillColor(vg, nvgRGBA(30, 25, 16, 190)); nvgFill(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(16 + hudOfsX, 13 + hudOfsY, "军资")
    nvgFontSize(vg, 22)
    DrawWhiteInkText(50 + hudOfsX, 13 + hudOfsY, "99")
    nvgFontSize(vg, 20)
    DrawWhiteInkText(120 + hudOfsX, 13 + hudOfsY, "斩")
    nvgFontSize(vg, 22)
    DrawWhiteInkText(140 + hudOfsX, 13 + hudOfsY, "0")
    -- 倒计时预览
    local tmrW2 = 72
    local tmrH2 = 20
    local tmrX2 = W / 2 - tmrW2 / 2 + hudOfsX
    local tmrY2 = hudH2 + 4 + hudOfsY
    nvgBeginPath(vg); nvgRoundedRect(vg, tmrX2, tmrY2, tmrW2, tmrH2, 10)
    nvgFillColor(vg, nvgRGBA(12, 10, 6, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 80)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(W / 2 + hudOfsX, tmrY2 + tmrH2 / 2, "1:30")
    if activeGrp == "hud" then
        nvgBeginPath(vg); nvgRoundedRect(vg, 1 + hudOfsX, -1 + hudOfsY, W - 2, hudH2 + tmrH2 + 10, 5)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- 3d. 绘制左上角信息面板预览
    local ipOfsX = settingsPage.adjInfoPanelOffsetX
    local ipOfsY = settingsPage.adjInfoPanelOffsetY
    local ipW = 110
    local ipH = 88
    local ipX = 4 + ipOfsX
    local ipY = 28 + ipOfsY
    nvgBeginPath(vg); nvgRoundedRect(vg, ipX, ipY, ipW, ipH, 4)
    nvgFillColor(vg, nvgRGBA(10, 8, 5, 140)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 130, 70, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    nvgFontSize(vg, 13.5)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawWhiteInkText(ipX + 6, ipY + 10, "阵容 3/6")
    DrawWhiteInkText(ipX + 6, ipY + 23, "总攻: 100")
    DrawWhiteInkText(ipX + 6, ipY + 35, "总防: 80")
    nvgFontSize(vg, 11.2)
    DrawWhiteInkText(ipX + 6, ipY + 51, "点击查看 - 拖拽换位")
    DrawWhiteInkText(ipX + 6, ipY + 61, "拖拽卡牌至石台放置")
    if activeGrp == "infoPanel" then
        nvgBeginPath(vg); nvgRoundedRect(vg, ipX - 3, ipY - 3, ipW + 6, ipH + 6, 5)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- 4. 顶部提示条
    local tipBarH = 36
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, tipBarH)
    nvgFillColor(vg, nvgRGBA(10, 15, 30, 200)); nvgFill(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(W / 2, tipBarH / 2, "拖拽屏幕移动选中组位置")

    -- 5. 底部工具栏 (增高以容纳组切换标签)
    local barH = 90
    local barY = H - barH
    nvgBeginPath(vg); nvgRect(vg, 0, barY, W, barH)
    nvgFillColor(vg, nvgRGBA(10, 15, 30, 220)); nvgFill(vg)
    -- 顶部分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, barY); nvgLineTo(vg, W, barY)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 5a. 组切换标签栏
    local groups = {
        { key = "skill",     label = "技能按钮" },
        { key = "rightBtn",  label = "右侧按钮" },
        { key = "hud",       label = "顶部信息" },
        { key = "infoPanel", label = "左侧面板" },
    }
    local tabY = barY + 6
    local tabH = 26
    local tabGap = 6
    local totalTabW = 0
    local tabWidths = {}
    for _, g in ipairs(groups) do
        local tw = 70
        tabWidths[#tabWidths + 1] = tw
        totalTabW = totalTabW + tw + tabGap
    end
    totalTabW = totalTabW - tabGap
    local tabStartX = (W - totalTabW) / 2
    local tabCurX = tabStartX
    settingsPage.adjGroupBtnRects = {}
    for gi, g in ipairs(groups) do
        local tw = tabWidths[gi]
        local isActive = (activeGrp == g.key)
        nvgBeginPath(vg); nvgRoundedRect(vg, tabCurX, tabY, tw, tabH, 4)
        if isActive then
            nvgFillColor(vg, nvgRGBA(60, 100, 160, 230)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        else
            nvgFillColor(vg, nvgRGBA(40, 40, 55, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(100, 90, 70, 100)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        end
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(tabCurX + tw / 2, tabY + tabH / 2, g.label)
        settingsPage.adjGroupBtnRects[gi] = { x = tabCurX, y = tabY, w = tw, h = tabH, key = g.key }
        tabCurX = tabCurX + tw + tabGap
    end

    -- 5b. 缩放滑条 (仅技能按钮组显示)
    local row2Y = tabY + tabH + 8
    if activeGrp == "skill" then
        local sliderLabel = "大小"
        local sliderX = 60
        local sliderW = W - 260
        local sliderH = 8
        local sliderY = row2Y + 4
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(14, sliderY, sliderLabel)
        nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, sliderY - sliderH / 2, sliderW, sliderH, 4)
        nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
        local scaleRatio = (settingsPage.adjScale - 0.5) / 1.5
        local scaleFill = sliderW * scaleRatio
        nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, sliderY - sliderH / 2, scaleFill, sliderH, 4)
        nvgFillColor(vg, nvgRGBA(100, 180, 220, 200)); nvgFill(vg)
        local scaleKnobX = sliderX + scaleFill
        nvgBeginPath(vg); nvgCircle(vg, scaleKnobX, sliderY, 9)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 240)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 140, 200, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 24)
        DrawWhiteInkText(sliderX + sliderW + 6, sliderY, math.floor(settingsPage.adjScale * 100) .. "%")
        settingsPage.adjScaleSliderRect = { x = sliderX, y = sliderY - 14, w = sliderW, h = 28 }
    else
        settingsPage.adjScaleSliderRect = nil
    end

    -- 5c. 按钮区域 (底部右侧)
    local btnAreaX = W - 190
    local btnY = row2Y
    local btnW2 = 54
    local btnH2 = 32

    -- 重置按钮
    nvgBeginPath(vg); nvgRoundedRect(vg, btnAreaX, btnY, btnW2, btnH2, 5)
    nvgFillColor(vg, nvgRGBA(60, 55, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(btnAreaX + btnW2 / 2, btnY + btnH2 / 2, "重置")
    settingsPage.adjResetBtnRect = { x = btnAreaX, y = btnY, w = btnW2, h = btnH2 }

    -- 保存按钮
    local saveBtnX = btnAreaX + btnW2 + 8
    nvgBeginPath(vg); nvgRoundedRect(vg, saveBtnX, btnY, btnW2, btnH2, 5)
    local saveGrad = nvgLinearGradient(vg, saveBtnX, btnY, saveBtnX, btnY + btnH2,
        nvgRGBA(90, 45, 55, 230), nvgRGBA(60, 25, 35, 230))
    nvgFillPaint(vg, saveGrad); nvgFill(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(saveBtnX + btnW2 / 2, btnY + btnH2 / 2, "保存")
    settingsPage.adjSaveBtnRect = { x = saveBtnX, y = btnY, w = btnW2, h = btnH2 }

    -- 返回按钮
    local backBtnX = saveBtnX + btnW2 + 8
    nvgBeginPath(vg); nvgRoundedRect(vg, backBtnX, btnY, btnW2, btnH2, 5)
    nvgFillColor(vg, nvgRGBA(50, 35, 35, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 100, 80, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backBtnX + btnW2 / 2, btnY + btnH2 / 2, "返回")
    settingsPage.adjBackBtnRect = { x = backBtnX, y = btnY, w = btnW2, h = btnH2 }
end


function DrawFormationScreen()
    if gameState.phase ~= "FORMATION" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local t = menuAnimTimer or 0

    DrawMenuBg(W, H)
    nvgFontFaceId(vg, GetMainFont())

    -- ===========================
    -- 1. 顶部栏: 返回 + 标题
    -- ===========================
    local topBarY = 12
    local backW, backH = 110, 48
    local backX = 10

    -- ===========================
    -- 2. 编队槽区域 (上半部分, 最多10个槽)
    -- ===========================
    local FORMATION_MAX = 10
    local slotCols = 5
    local slotRows = 2
    local slotW = 62
    local slotH = 80
    local slotGap = 8
    local slotAreaW = slotCols * slotW + (slotCols - 1) * slotGap
    local slotStartX = (W - slotAreaW) / 2
    local slotStartY = topBarY + backH + 16

    -- 统计信息
    local formation = gameSettings.formation or {}
    local formCount = #formation
    local ownedCount = formationUI.ownedCount or GetOwnedHeroCount()
    local targetCount = math.min(FORMATION_MAX, ownedCount)
    local canManualEdit = ownedCount >= 10

    -- 标题栏
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local titleStr = "编队 (" .. formCount .. "/" .. targetCount .. ")"
    DrawWhiteInkText(W / 2, slotStartY - 8, titleStr)

    -- 编队说明 (根据状态不同显示)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if canManualEdit then
        nvgFillColor(vg, nvgRGBA(180, 170, 140, 180))
        nvgText(vg, W / 2, slotStartY + 4, "点击卡牌可调整编队阵容")
    else
        nvgFillColor(vg, nvgRGBA(255, 200, 100, math.floor(150 + 60 * math.sin(t * 2.5))))
        nvgText(vg, W / 2, slotStartY + 4, "武灵不足10人, 已全部自动上阵")
    end

    slotStartY = slotStartY + 14

    formationUI.slotRects = {}
    for i = 1, FORMATION_MAX do
        local col = ((i - 1) % slotCols)
        local row = math.floor((i - 1) / slotCols)
        local sx = slotStartX + col * (slotW + slotGap)
        local sy = slotStartY + row * (slotH + slotGap + 4)

        formationUI.slotRects[i] = { x = sx, y = sy, w = slotW, h = slotH }

        local cardIdx = formation[i]
        if cardIdx and HERO_CARDS[cardIdx] and playerHeroes[cardIdx] and playerHeroes[cardIdx].owned then
            -- 已放置武灵
            local card = HERO_CARDS[cardIdx]
            local hero = playerHeroes[cardIdx]
            DrawInventoryCard(sx, sy, slotW, slotH, card, hero.constellation or 0, false, false)
            -- 移除标记 (右上角x) — 仅满10人可手动编辑时显示
            if canManualEdit then
                nvgBeginPath(vg)
                nvgCircle(vg, sx + slotW - 6, sy + 6, 8)
                nvgFillColor(vg, nvgRGBA(180, 50, 50, 200)); nvgFill(vg)
                nvgFontSize(vg, 14)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
                nvgText(vg, sx + slotW - 6, sy + 6, "×")
            end
        else
            -- 空槽位
            local isEmpty = i > targetCount
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, slotW, slotH, 4)
            if isEmpty then
                nvgFillColor(vg, nvgRGBA(20, 18, 15, 150))
            else
                nvgFillColor(vg, nvgRGBA(35, 32, 25, 200))
            end
            nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, sx, sy, slotW, slotH, 4)
            if isEmpty then
                nvgStrokeColor(vg, nvgRGBA(60, 55, 40, 60))
            else
                local pulse = 0.5 + 0.5 * math.sin(t * 2.5 + i)
                nvgStrokeColor(vg, nvgRGBA(180, 150, 80, math.floor(80 + 60 * pulse)))
            end
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
            if not isEmpty then
                nvgFontSize(vg, 28)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(120, 110, 80, 100))
                nvgText(vg, sx + slotW / 2, sy + slotH / 2, "+")
            end
        end
    end

    -- ===========================
    -- 3. 功能按钮区 (一键编队 / 清空)
    -- ===========================
    local btnAreaY = slotStartY + slotRows * (slotH + slotGap + 4) + 8
    local btnW = 90
    local btnH = 32
    local btnGap = 16
    local totalBtnW = btnW * 2 + btnGap
    local btnStartX = (W - totalBtnW) / 2

    -- 一键编队按钮
    local autoBtnX = btnStartX
    nvgBeginPath(vg); nvgRoundedRect(vg, autoBtnX, btnAreaY, btnW, btnH, 6)
    local autoGrad = nvgLinearGradient(vg, autoBtnX, btnAreaY, autoBtnX, btnAreaY + btnH,
        nvgRGBA(80, 140, 60, 220), nvgRGBA(50, 100, 40, 240))
    nvgFillPaint(vg, autoGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, autoBtnX, btnAreaY, btnW, btnH, 6)
    nvgStrokeColor(vg, nvgRGBA(120, 200, 80, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(autoBtnX + btnW / 2, btnAreaY + btnH / 2, "一键编队")
    formationUI.autoBtnRect = { x = autoBtnX, y = btnAreaY, w = btnW, h = btnH }

    -- 清空按钮 (不满10人时显示灰色锁定)
    local clearBtnX = btnStartX + btnW + btnGap
    nvgBeginPath(vg); nvgRoundedRect(vg, clearBtnX, btnAreaY, btnW, btnH, 6)
    if canManualEdit then
        local clearGrad = nvgLinearGradient(vg, clearBtnX, btnAreaY, clearBtnX, btnAreaY + btnH,
            nvgRGBA(140, 60, 50, 220), nvgRGBA(100, 40, 35, 240))
        nvgFillPaint(vg, clearGrad); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, clearBtnX, btnAreaY, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(200, 80, 60, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    else
        nvgFillColor(vg, nvgRGBA(60, 55, 50, 180)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, clearBtnX, btnAreaY, btnW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(80, 70, 60, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if canManualEdit then
        DrawWhiteInkText(clearBtnX + btnW / 2, btnAreaY + btnH / 2, "清空")
    else
        nvgFillColor(vg, nvgRGBA(120, 110, 100, 120))
        nvgText(vg, clearBtnX + btnW / 2, btnAreaY + btnH / 2, "清空")
    end
    formationUI.clearBtnRect = { x = clearBtnX, y = btnAreaY, w = btnW, h = btnH }

    -- ===========================
    -- 4. 品质筛选标签页
    -- ===========================
    local tabY = btnAreaY + btnH + 12
    local tabH = 26
    local TAB_DEFS = {
        { label = "全部", quality = 0 },
        { label = "N",    quality = 1 },
        { label = "R",    quality = 2 },
        { label = "SR",   quality = 3 },
        { label = "SSR",  quality = 4 },
        { label = "限定", quality = 5 },
    }
    local tabW = math.floor((W - 20) / #TAB_DEFS) - 4
    local tabStartX = 12
    formationUI.tabRects = {}
    for ti, td in ipairs(TAB_DEFS) do
        local tx = tabStartX + (ti - 1) * (tabW + 4)
        local isActive = (formationUI.tab or 0) == td.quality
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 4)
        if isActive then
            local qc = td.quality > 0 and QUALITY_COLORS[td.quality] or { 200, 180, 140 }
            nvgFillColor(vg, nvgRGBA(qc[1], qc[2], qc[3], 180)); nvgFill(vg)
        else
            nvgFillColor(vg, nvgRGBA(40, 36, 28, 200)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 4)
            nvgStrokeColor(vg, nvgRGBA(80, 70, 50, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        end
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if isActive then
            nvgFillColor(vg, nvgRGBA(30, 25, 15, 255))
        else
            nvgFillColor(vg, nvgRGBA(180, 170, 140, 200))
        end
        nvgText(vg, tx + tabW / 2, tabY + tabH / 2, td.label)
        formationUI.tabRects[ti] = { x = tx, y = tabY, w = tabW, h = tabH, quality = td.quality }
    end

    -- ===========================
    -- 5. 已拥有武灵列表 (可滚动)
    -- ===========================
    local listStartY = tabY + tabH + 8
    local listEndY = H - 10
    local listViewH = listEndY - listStartY

    -- 筛选已拥有 + 品质过滤
    local filteredOwned = {}
    local inFormationSet = {}
    for _, idx in ipairs(formation) do inFormationSet[idx] = true end

    for idx = 1, #HERO_CARDS do
        local hero = playerHeroes[idx]
        if hero and hero.owned then
            local card = HERO_CARDS[idx]
            local matchQuality = (formationUI.tab or 0) == 0 or card.quality == formationUI.tab
            if matchQuality then
                table.insert(filteredOwned, { cardIdx = idx, card = card, hero = hero, inFormation = inFormationSet[idx] or false })
            end
        end
    end

    -- 排序: 已编队的排后面, 同组按品质降序
    table.sort(filteredOwned, function(a, b)
        if a.inFormation ~= b.inFormation then return not a.inFormation end
        if a.card.quality ~= b.card.quality then return a.card.quality > b.card.quality end
        return a.cardIdx < b.cardIdx
    end)

    local cardW = 62
    local cardH = 80
    local cardGap = 8
    local cols = math.floor((W - 20) / (cardW + cardGap))
    local cardStartX = math.floor((W - (cols * (cardW + cardGap) - cardGap)) / 2)
    local rows = math.ceil(#filteredOwned / cols)
    local contentH = rows * (cardH + cardGap + 4)

    -- 滚动范围限制
    local maxScroll = math.max(0, contentH - listViewH)
    formationUI.scrollY = math.max(0, math.min(formationUI.scrollY or 0, maxScroll))
    local scrollY = formationUI.scrollY

    -- 滚动裁剪
    nvgSave(vg)
    nvgScissor(vg, 0, listStartY, W, listViewH)

    formationUI.cardRects = {}
    for fi = 1, #filteredOwned do
        local entry = filteredOwned[fi]
        local col = ((fi - 1) % cols)
        local row = math.floor((fi - 1) / cols)
        local cx = cardStartX + col * (cardW + cardGap)
        local cy = listStartY + row * (cardH + cardGap + 4) - scrollY

        formationUI.cardRects[fi] = { x = cx, y = cy, w = cardW, h = cardH, cardIdx = entry.cardIdx }

        -- 跳过不可见
        if cy + cardH >= listStartY - 10 and cy <= listEndY + 10 then
            if entry.inFormation then
                -- 已编队: 暗化显示
                DrawInventoryCard(cx, cy, cardW, cardH, entry.card, entry.hero.constellation or 0, false, false)
                nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 4)
                nvgFillColor(vg, nvgRGBA(10, 10, 15, 150)); nvgFill(vg)
                -- "已编入" 标记
                nvgFontSize(vg, 13)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(120, 200, 100, 220))
                nvgText(vg, cx + cardW / 2, cy + cardH / 2, "已编入")
            else
                -- 未编队
                DrawInventoryCard(cx, cy, cardW, cardH, entry.card, entry.hero.constellation or 0, false, false)
                -- 不满10人锁定时，未编队卡牌也显示暗化锁定
                if not canManualEdit then
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 4)
                    nvgFillColor(vg, nvgRGBA(10, 10, 15, 100)); nvgFill(vg)
                    nvgFontSize(vg, 20)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(160, 140, 100, 120))
                    nvgText(vg, cx + cardW / 2, cy + cardH / 2, "🔒")
                end
            end
        end
    end

    nvgRestore(vg)

    -- 滚动条
    if contentH > listViewH then
        local barH = math.max(20, listViewH * listViewH / contentH)
        local barY = listStartY + (scrollY / maxScroll) * (listViewH - barH)
        nvgBeginPath(vg); nvgRoundedRect(vg, W - 5, barY, 3, barH, 1.5)
        nvgFillColor(vg, nvgRGBA(180, 160, 120, 70)); nvgFill(vg)
    end

    -- ===========================
    -- 6. 顶部栏 (覆盖在上层)
    -- ===========================
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, topBarY + backH + 4)
    nvgFillColor(vg, nvgRGBA(15, 20, 38, 230)); nvgFill(vg)

    -- 返回按钮
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, topBarY, backW, backH, 8)
    nvgFillColor(vg, nvgRGBA(32, 38, 58, 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, topBarY, backW, backH, 8)
    nvgStrokeColor(vg, nvgRGBA(100, 85, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, topBarY + backH / 2, "◁ 返回")
    formationBackBtnRect = { x = backX, y = topBarY, w = backW, h = backH }

    -- 标题
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(W / 2, topBarY + backH / 2, "出征编队")

    -- 右上角状态提示
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    if not canManualEdit then
        -- 不满10人: 锁定提示
        nvgFillColor(vg, nvgRGBA(255, 200, 100, math.floor(150 + 80 * math.sin(t * 3))))
        nvgText(vg, W - 14, topBarY + backH / 2, "自动编队中")
    elseif formCount < targetCount then
        -- 满10人但编队未满
        nvgFillColor(vg, nvgRGBA(255, 180, 80, math.floor(150 + 80 * math.sin(t * 3))))
        nvgText(vg, W - 14, topBarY + backH / 2, "需补齐" .. targetCount .. "人")
    else
        -- 编队已满
        nvgFillColor(vg, nvgRGBA(120, 220, 100, 180))
        nvgText(vg, W - 14, topBarY + backH / 2, "编队完成")
    end
end
