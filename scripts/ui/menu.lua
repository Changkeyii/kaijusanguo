-- menu.lua
-- ============================================================================
-- ui/menu.lua - 婵炴垶鎸搁ˇ顖毭瑰Δ鈧～銏ゆ晜閸欍儳瑙﹂悷?"
-- ============================================================================


-- ============================================================================
-- 婵☆偓绲鹃悧鐘诲Υ婢舵劖鍤曟繝濠傚暙缁€?(闂佸搫妫欓〃濠囧箺閹槆noVG婵＄偛顑呯€涒晠鎮?+ 濠碘槅鍨埀顒冩珪閸嬨儱鈽夐幘鎰佸創婵?闁荤姳闄嶉崝瀣?
-- ============================================================================

function DrawMenuScreen()
    if gameState.phase ~= "MENU" then return end

    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer

    -- 1. 缂傚倷鑳堕崰宥囩博閹绢喗鍤曟繝濠傚暙缁€瀣煠閸愬弶婀版繛?
    DrawMenuBg(W, H)

    nvgFontFaceId(vg, GetMainFont())

    -- ===========================
    -- 闂備緡鍋呭銊╁极? 婵炴挻鐨滈崟顓炵効闂佸湱顭堥ˇ鐢稿箰瀹曞洨纾兼俊顖氭惈閻撴垿鏌涢幋锝呅撻柡?
    -- ===========================
    local function DrawSideBtn(bx, by, bw, bh, label, colors, bPulse, showGlow, iconImg)
        -- 缂備胶铏庨崹鏉棵瑰鈧?闂佸搫鍊稿ú銈夋偤瑜旈弫宥囦沪閻愵剨楠忔繛瀵稿Ь椤斿﹦绱炲澶嬪殑閻忕偟鍋撻悵?
        if iconImg and IsImageReady(iconImg) then
            local iconSize = math.floor(math.min(bw * 0.60, bh * 0.52))
            local iconX = bx + (bw - iconSize) / 2
            local iconY = by + 3
            local pat = nvgImagePattern(vg, iconX, iconY, iconSize, iconSize, 0, iconImg, 1.0)
            nvgBeginPath(vg); nvgRect(vg, iconX, iconY, iconSize, iconSize)
            nvgFillPaint(vg, pat); nvgFill(vg)
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            DrawWhiteInkText(bx + bw / 2, by + bh - 1, label)
        else
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + bw / 2, by + bh / 2, label)
        end
    end

    -- ===========================
    -- 2. 婵炴垶鎼╅崢濂稿Φ鎼达絾鍠嗛柟鐑樻礀椤ュ繘鎮橀悙瀛樼闁靛洦宀稿畷?(濠碘槅鍨兼禍婊堟儓? 婵＄偑鍊曢悥濂稿磿閹绢喖绀嗛柡澶庢硶娣囨椽鏌″鍛缂佺媴缍佸?"
    -- ===========================
    local centerAreaTop = 4
    local bottomBarH = 80
    local bottomBarY = H - bottomBarH - 4
    local centerAreaBottom = bottomBarY - 6



    -- ===========================
    -- 4. 閻庡綊娼荤紓姘跺疾閸洖鍐€?(缂備焦姊归悧妤冩暜閹捐绀夐柣鏃囶嚙閸樻挳鏌熺粙娆炬█闁? 濠碘槅鍨兼禍婊堟儓閸℃稒鐒婚柛宀€鍋涚敮? 闂佽　鍋撴い鏍ㄧ☉閻︻喗绻濇繝鍐濠?
    -- ===========================
    local sideBtnW = 88
    local sideBtnH = 68
    local sideGap = 5
    local sideX = 4
    local leftEndY = bottomBarY - 4       -- 闁圭厧鐡ㄥú鐔煎磿閹绢喗鍋╂繛鍡楃箰濮ｅ姊婚崒婊庢缂?
    local leftStartY = 110
    local leftViewH = leftEndY - leftStartY

    -- 閻庡綊娼荤紓姘跺疾閸洖绠板鑸靛姈鐏忥箓姊洪弶璺ㄐら柣?(闁汇埄鍨界粻鎴澝瑰鈧?"
    local leftButtons = {
        { label = "势力",      key = "faction",    colors = {70, 55, 30},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[8] },
        { label = "好友",      key = "friends",    colors = {40, 65, 70},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[9] },
        { label = "交易",        key = "trade",      colors = {75, 55, 35},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[14] },
        { label = "邮件",         key = "mailBox",    colors = {45, 45, 70},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[10] },
        { label = "图鉴",        key = "codex",      colors = {60, 45, 80},  mod = moduleState.heroes,    icon = IMG.menuIcons and IMG.menuIcons[1] },
        { label = "装备",        key = "equip",      colors = {50, 60, 80},  mod = moduleState.equipment, icon = IMG.menuIcons and IMG.menuIcons[2] },
        { label = "装备图鉴",  key = "equipCodex", colors = {45, 55, 75},  mod = moduleState.equipment, icon = IMG.menuIcons and IMG.menuIcons[3] },
        { label = "武技图鉴",  key = "skillCodex", colors = {55, 40, 75},  mod = moduleState.skills,    icon = IMG.menuIcons and IMG.menuIcons[4] },
        { label = "福利",      key = "welfare",    colors = {80, 50, 40},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[5] },
        { label = "进度",     key = "progress",   colors = {50, 65, 50},  mod = nil,                   icon = IMG.menuIcons and IMG.menuIcons[6] },
    }

    -- 闁荤姳绶ょ槐鏇㈡偩婵犳艾绀冮柛娑卞弾閸熷洭鏌熼鈧…鐑芥偟椤旇姤鍎?"
    local leftContentH = #leftButtons * sideBtnH + (#leftButtons - 1) * sideGap
    local leftMaxScroll = math.max(0, leftContentH - leftViewH)

    -- 闂佸搫娲ら悺銊╁蓟婵犲偆鐓ユ慨姗嗗墮琚熼梺缁橆焾閸╂牠鍩€椤戣儻鍏屾繛鍫熷灴瀹曟宕樿缁诲棝鏌?(婵炴挻纰嶇粙鎺斺偓姘儔楠炲繘骞嬮幒鎾虫敪婵炲瓨绮嶇敮濠冪箾閸ヮ剚鍋?"
    leftSidebarScroll.contentH = leftContentH
    leftSidebarScroll.viewH = leftViewH
    leftSidebarScroll.areaRect = { x = 0, y = leftStartY, w = sideBtnW + sideX * 2, h = leftViewH }

    -- 闂傚倸瀚崝鏇㈠春濡も偓椤劌顫濋鈧闂佽偐鍘ч崯顐⒚?
    leftSidebarScroll.y = math.max(0, math.min(leftSidebarScroll.y, leftMaxScroll))
    local scrollOff = leftSidebarScroll.y

    -- 閻庢鍠掗崑鎾绘煕濮樼厧鐏ユい銉ユ瀹曟粓顢旈崟顐︽闂?"
    nvgSave(vg)
    nvgScissor(vg, 0, leftStartY, sideBtnW + sideX * 2 + 4, leftViewH)

    local leftRects = {}
    for i, lb in ipairs(leftButtons) do
        local by = leftStartY + (i - 1) * (sideBtnH + sideGap) - scrollOff
        -- 婵炲濮撮幊蹇曟啺閸℃稑钃熼柟鎯у暱鐠佹煡鎮峰▎搴㈢グ閻庡灚鐗犲畷鍫曞级閹存繃鏆ラ梺姹囧妼鐎氼厾鈧灚绮撻弻?"
        if by + sideBtnH > leftStartY - 10 and by < leftEndY + 10 then
            local bPulse = 0.85 + 0.15 * math.sin(t * 2.0 + i)
            DrawSideBtn(sideX, by, sideBtnW, sideBtnH, lb.label, lb.colors, bPulse, false, lb.icon)

            -- 濠碘槅鍨埀顒冩珪閸嬨儵鏌￠崼顐＄盎婵ǜ鍔庣槐鎺楊敂閸粎纾跨紓?"
            if lb.mod and not lb.mod.ready then
                nvgBeginPath(vg); nvgRoundedRect(vg, sideX, by, sideBtnW, sideBtnH, 8)
                nvgFillColor(vg, nvgRGBA(10, 12, 20, 140)); nvgFill(vg)
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(sideX + sideBtnW / 2, by + sideBtnH / 2, math.floor(lb.mod.progress * 100) .. "%")
            end
        end
        leftRects[i] = { x = sideX, y = by, w = sideBtnW, h = sideBtnH }
        menuBtnRects[lb.key] = leftRects[i]
    end

    -- 閻庡綊娼荤紓姘跺疾閸撲胶妫柕蹇嬪灩娴?(闂?key 闂佸搫琚崕鍙夌珶濮椻偓閺佸秶浠﹂懞銉ㄥ惈闁荤喍妞掔粈浣圭珶閳ь剟鏌涢弽褎鎯堥柣鎾寸懇瀹曟﹢宕ㄩ婊冪闂?"
    local function DrawKeyRedDot(key)
        local r = menuBtnRects[key]
        if r then DrawRedDot(r.x + r.w - 6, r.y + 6, 6) end
    end
    if HasEquipRedDot() then DrawKeyRedDot("equip") end
    if HasSkillRedDot() then DrawKeyRedDot("skillCodex") end
    if HasProgressRedDot() then DrawKeyRedDot("progress") end
    -- 闂備緡鍙庨崰鏇炩枎閵忋垻妫柕蹇嬪灩娴?
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
    -- 婵犻潧鍊藉Λ鍕嚕閸濄儲瀚氶梺鍨儑濠€瀵哥磼娣囧崬鐏柛?(闁诲氦顫夌喊宥咁渻閸屾稒濮滄い鏃€顑欓崵? 婵☆偓绲鹃悧妤咁敃?缂備礁顦扮敮鎺楀箖濡も偓铻為柍褜鍓熷? 婵炴垶鏌ㄩ鍛村箖濡も偓琚?0缂?"
    local now = os.time()
    local friendCheckInterval = friendsUI.pendingReqChecked and 30 or 5  -- 婵☆偓绲鹃悧妤咁敃?缂? 婵炴垶鏌ㄩ鍛村箖?0缂?"
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
    -- 闂傚倸鍟╃徊濠氬箚閳ь剟鏌ｉ姀鐘垫瀮妞ゆ洦鍓涢惀顏堝閵忕姳鍖?(婵炲濮撮幊鎰哄Ο鑽も枖?闂佸憡鎼╅崹鍐裁哄Ο鑽も枖? 闁诲氦顫夌喊宥咁渻閸屾稒濮滄い鏃€顑欓崵? 婵☆偓绲鹃悧妤咁敃?缂備礁顦扮敮鎺楀箖濡も偓铻為柍褜鍓熷?"
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

    -- 缂傚倷鐒﹂幐璇差焽椤愩倖鍟戝ù锝囶焾椤?
    nvgRestore(vg)

    -- 濠电姴锕ラ懝鐐叏閳哄啰涓嶆い鎾跺亼娴犲牓鏌熺紒妯哄闁?(閻熸粎澧楅幐鎼佸船鐎电硶鍋撻崷顓ф敯缂佸鎸冲畷娆撳传閸曨偉顔夐柣鐔哥懁缁€浣轰焊椤栫偛鏄ラ柣鏂挎啞椤ρ囨煥濞戞瀚版繝鈧鍛懝鐟滃酣鎮ラ钘夌窞闁哄稄闄勫▍鐘绘煛閸曨偄鈷旈柕鍥ㄥ哺瀹曟繈濡搁敂鐟颁壕濞达絼璀﹂崬鎻掝熆?"
    if leftMaxScroll > 0 then
        local arrowX = sideX + sideBtnW / 2
        local arrowBob = math.sin(t * 3.0) * 4  -- 婵炴垶鎸搁敃锝囩箔閸涱劶褰掝敊閻撳巩妤呮煕閺傝濡块柡?
        -- 婵炴垶鎸搁敃锕傤敊閸曨剙绶?(闂佸憡鐟崹浼村箖濠婂嫮鈻斿┑鐘插暟濞夊﹪鏌涢弬璇插婵＄偛鍊垮浼村礈瑜嬫禒?
        if scrollOff > 2 then
            local upY = leftStartY - 14 + arrowBob
            local arrowA = math.min(200, math.floor(scrollOff / leftMaxScroll * 200 + 60))
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, arrowA))
            nvgText(vg, arrowX, upY, "▲", nil)
        end
        -- 婵炴垶鎸搁鍥敊閸曨剙绶?(闂佸憡鐟崹浼村箖濠婂嫮鈻旈悗锝庡亞濞夊﹪鏌涢弬璇插婵＄偛鍊垮浼村礈瑜嬫禒?
        if scrollOff < leftMaxScroll - 2 then
            local downY = leftEndY + 4 - arrowBob
            local arrowA = math.min(200, math.floor((1 - scrollOff / leftMaxScroll) * 200 + 60))
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, arrowA))
            nvgText(vg, arrowX, downY, "▼", nil)
        end
    end

    -- ===========================
    -- 5.5 闂佸憡鐟ラ崢鏍疾閸洖纭€闁汇値鍨堕崣锟犳⒒閸稑鐏繝?(闂佹悶鍎辨晶鑺ユ櫠閺嶎偅顫曢柣妯挎珪缂?+ 闂佸湱顭堥ˇ鐢稿箰閹惰棄鐭楅柣妯诲絻椤?
    -- ===========================
    do
        -- 闂傚倸鐗勯崹鍝勵熆濡棿鐒婇柛婵嗗閸ょ喖鏌涘鍐殭缂傚秴鎳愮槐?(缂備浇浜慨闈涱焽濡ゅ懎鍌ㄩ柣鏂款殠濞兼鎱ㄩ敐鍡樼叄缂?429:768 闂?9:16)
        local rpH = H * 0.88            -- 闂傚倸鐗勯崹鍝勵熆濡椿娈楁俊顖氭惈椤斿﹪鏌涘Δ鍐ㄐ㈤柣顐㈡閻?8%
        local rpW = rpH * (600 / 804)   -- 闂佸憡姊绘慨鎾敊閺冨牆瑙﹂幖杈剧悼椤﹂亶鏌℃径瀣闁伙富鍠楃粭?600:804
        local rpX = W - rpW - 12        -- 闂佸憡鐟ラ崢鏍疾閸洘鍋╂繛鍡樺笧閻濆爼鎮?"
        local rpY = (H - rpH) / 2       -- 闂佹悶鍔岄崐璇裁虹捄銊ゆ勃闁告侗鍓濋崢?

        -- 缂傚倷鐒﹂敋闁糕晜顨婂畷锟犳偪椤栫偛褰欓梻鍌氱墑閸ㄥ搫顭垮鈧畷鍫曞礈瑜嶉。?
        if IMG.scrollPanel and IsImageReady(IMG.scrollPanel) then
            local pat = nvgImagePattern(vg, rpX, rpY, rpW, rpH, 0, IMG.scrollPanel, 1.0)
            nvgBeginPath(vg); nvgRect(vg, rpX, rpY, rpW, rpH)
            nvgFillPaint(vg, pat); nvgFill(vg)
        end

        -- 闂傚倸鐗勯崹鍝勵熆濮椻偓瀹曟﹢宕ㄩ鑲╂▎闂備胶鐡旈崳锝夊储閵堝洨纾?"
        local rpBtns = {
            { label = "天下征途",   key = "rpBattle",   primary = true },
            { label = "设置",       key = "rpSettings", primary = false },
        }

        -- 闂佸湱顭堥ˇ鐢稿箰瀹曞洦鏆滈柛鎰╁妿濠€?(闂侀潻璐熼崝灞界暤鎼淬垺濮滈柡澶嬪灥閺佸爼姊洪鍝勫閻忓浚鍨跺畷娲偄妞嬪孩鐙楁繛鎴炴惄閸樼晫鏁幘璇茬?"
        local innerX = rpX + rpW * 0.12   -- 闂佸憡顨堥弻澶愭煀闁秴绀冮柛娑欏閻濆爼鎮?"
        local innerW = rpW * 0.76         -- 闂佸湱顭堥ˇ鐢稿箰閹惰棄鐭楁い鏍ㄧ矋閺嗗繘鎮楃涵鍛棄閻?
        local rpBtnW = innerW
        local rpBtnH = rpBtnW * (217 / 512)  -- 按钮图片原始比例 512x217
        -- 两按钮居中于卷轴框内, 设置缩小60%, 间距4px
        local exitScale = 0.60
        local exitBtnW = rpBtnW * exitScale
        local exitBtnH = rpBtnH * exitScale
        local btnGap = -2
        local totalGroupH = rpBtnH + btnGap + exitBtnH
        local primaryY = rpY + (rpH - totalGroupH) / 2
        local exitY = primaryY + rpBtnH + btnGap
        local rpBtnX = innerX

        for i, rb in ipairs(rpBtns) do
            local isPrimary = rb.primary
            local bw = isPrimary and rpBtnW or exitBtnW
            local bh = isPrimary and rpBtnH or exitBtnH
            local bx = isPrimary and rpBtnX or (rpBtnX + (rpBtnW - exitBtnW) / 2)
            local by = isPrimary and primaryY or exitY
            local bPulse = isPrimary and (0.7 + 0.3 * math.sin(t * 2.5)) or 1.0

            -- 闂佸湱顭堥ˇ鐢稿箰閹惰棄鐐婇柛鎾楀喚鏆紓浣戒含婵潧顭囧Δ鍛殑閻忕偟鍋撻悵?
            local btnImg = isPrimary and IMG.btnMenuPrimary or IMG.btnMenuNormal
            if btnImg and IsImageReady(btnImg) then
                local btnAlpha = isPrimary and bPulse or 1.0
                local btnPat = nvgImagePattern(vg, bx, by, bw, bh, 0, btnImg, btnAlpha)
                nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 6)
                nvgFillPaint(vg, btnPat); nvgFill(vg)
            else
                -- 缂備浇浜慨闈涱焽濡ゅ懎瀚夋い蹇撳閻ㄦ垹绱撴笟鍥︾凹婵＄偛鍊垮畷鍫曟倷鐞涒€充壕闁逞屽墰閻ヮ亪顢涘┑鍡╂
                nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, bw, bh, 6)
                nvgFillColor(vg, isPrimary and nvgRGBA(160, 40, 20, 200) or nvgRGBA(120, 95, 60, 200))
                nvgFill(vg)
            end

            -- 婵炴垶鎸剧划顖溾偓鍨矒閺岋箓顢欑喊杈ㄢ枎闂佸憡鐟﹂崹鐢稿储?
            if isPrimary then
                local glow = nvgRadialGradient(vg,
                    bx + bw / 2, by + bh / 2,
                    bw * 0.2, bw * 0.55,
                    nvgRGBA(255, 180, 60, math.floor(30 * bPulse)), nvgRGBA(255, 180, 60, 0))
                nvgBeginPath(vg)
                nvgRoundedRect(vg, bx - 10, by - 6, bw + 20, bh + 12, 10)
                nvgFillPaint(vg, glow); nvgFill(vg)
            end

            -- 闂佸湱顭堥ˇ鐢稿箰閹惰棄妫橀柛銉戝懏鎲?
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, isPrimary and 26 or 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            -- 闂佸搫鍊稿ú銈夋偤瑜斿濂稿级閹存繍娈?
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 60))
            nvgText(vg, bx + bw / 2 + 1, by + bh / 2 + 1, rb.label, nil)
            -- 闂佸搫鍊稿ú銈夋偤瑜嶉～銏ゆ晲閸曨厾歇
            if isPrimary then
                DrawWhiteInkText(bx + bw / 2, by + bh / 2, rb.label)
            else
                nvgFillColor(vg, nvgRGBA(240, 225, 190, 240))
                nvgText(vg, bx + bw / 2, by + bh / 2, rb.label, nil)
            end

            -- 闁诲孩绋掗敋闁稿绉归獮鎰緞閹邦厼鍞夐梺缁樺姉閹虫捇宕甸鈧畷鐘诲传閸曨厼骞?
            menuBtnRects[rb.key] = { x = bx, y = by, w = bw, h = bh }
        end
    end

    -- ===========================
    -- 6. 闁圭厧鐡ㄥú鐔煎磿閹绢喖绠肩€广儱瀚粙濠囨煛?(濠碘槅鍨兼禍婵堟暜?闂佸湱顭堥ˇ鐢稿箰? 婵炲濮撮悘婵嗩嚕椤掑嫭鍤€闁告劑鍔嶇粋?
    -- ===========================
    -- 闁圭厧鐡ㄥú姗€鎮ラ鈧幊妤冧沪閻愵剛褰?(闂佹悶鍎扮划娆撍夐幘璇叉辈闁哄稁鍓欓ˉ蹇斾繆椤栵絼绨兼繛?
    local barBgGrad = nvgLinearGradient(vg, 0, bottomBarY - 8, 0, bottomBarY + bottomBarH,
        nvgRGBA(120, 80, 40, 0), nvgRGBA(90, 55, 25, 180))
    nvgBeginPath(vg); nvgRect(vg, 0, bottomBarY - 8, W, bottomBarH + 16)
    nvgFillPaint(vg, barBgGrad); nvgFill(vg)
    -- 婵＄偑鍊曢悥濂稿磿閹绢喗鐓傞柟杈剧到椤ュ繘鏌涢幒鎴烆棦婵炲爜鍛／?"
    local sepGradL = nvgLinearGradient(vg, 0, bottomBarY - 2, W, bottomBarY - 2,
        nvgRGBA(255, 200, 80, 0), nvgRGBA(255, 200, 80, 150))
    nvgBeginPath(vg); nvgMoveTo(vg, 0, bottomBarY - 2); nvgLineTo(vg, cx, bottomBarY - 2)
    nvgStrokeWidth(vg, 1.5); nvgStrokePaint(vg, sepGradL); nvgStroke(vg)
    local sepGradR = nvgLinearGradient(vg, cx, bottomBarY - 2, W, bottomBarY - 2,
        nvgRGBA(255, 200, 80, 150), nvgRGBA(255, 200, 80, 0))
    nvgBeginPath(vg); nvgMoveTo(vg, cx, bottomBarY - 2); nvgLineTo(vg, W, bottomBarY - 2)
    nvgStrokeWidth(vg, 1.5); nvgStrokePaint(vg, sepGradR); nvgStroke(vg)

    -- 闁圭厧鐡ㄥú姗€鎮ラ鈧獮鎰緞閹邦厼鍞夐梻浣规緲缁夊爼鎮?(6婵? 闁汇埄鍨界粻鎴澝瑰鈧? 濠碘槅鍨兼禍婊堟儓閸℃稒鐒婚柛宀€鍋涚敮?
    local bottomButtons = {
        { label = "设置",    key = "settings",   colors = {40, 35, 55},  primary = false, mod = nil,                icon = IMG.menuIcons and IMG.menuIcons[13] },
        { label = "战令", key = "battlepass", colors = {120, 70, 30}, primary = false, mod = nil,                icon = IMG.dragonPortal },
        { label = "排行",    key = "powerRank",  colors = {35, 40, 65},  primary = false, mod = nil,                icon = IMG.menuIcons and IMG.menuIcons[12] },
        { label = "兵符召唤",  key = "gachaSeal",  colors = {80, 50, 130}, primary = false, mod = nil,                icon = IMG.sealItem1 },
        { label = "排位",      key = "ranked",     colors = {180, 45, 25}, primary = true,  mod = nil,                icon = IMG.abyssTicket },
    }
    local botBtnCount = #bottomButtons
    local botPad = 80  -- 閻庡綊娼荤紓姘跺疾閸洘鍋╂繛鍡楃箰濮ｅ銆掑鈧崟顓炵効缂備礁鏈钘壩?
    local botTotalW = W - botPad - 10
    local botBtnW = (botTotalW - (botBtnCount - 1) * 6) / botBtnCount
    local botBtnH = 72
    local botBtnY = bottomBarY + (bottomBarH - botBtnH) / 2

    local pulse = 0.7 + 0.3 * math.sin(t * 2.5)
    for i, bb in ipairs(bottomButtons) do
        local bx = botPad + (i - 1) * (botBtnW + 6)
        local by = botBtnY
        local isPrimary = bb.primary
        local bPulse = isPrimary and pulse or (0.85 + 0.15 * math.sin(t * 2.0 + i))

        -- 缂備胶铏庨崹鏉棵瑰鈧?闂佸搫鍊稿ú銈夋偤瑜旈弫宥囦沪閻愵剨楠忔繛瀵稿Ь椤斿﹦绱炲澶嬪殑閻忕偟鍋撻悵?(濠碘槅鍨兼禍婊堟儓閸℃稒鐒婚柛宀€鍋涚敮?
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
            -- 闂佸搫鍊稿ú銈夋偤?
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            DrawWhiteInkText(bx + botBtnW / 2, by + botBtnH - 1, bb.label)
        else
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + botBtnW / 2, by + botBtnH / 2, bb.label)
        end

        -- 闁诲孩绋掗敋闁稿绉归幃娆撴偡閺夋寧鐦栭梺鍛婄墪閹碱偊鎮?
        local rect = { x = bx, y = by, w = botBtnW, h = botBtnH }
        -- 濠碘槅鍨埀顒冩珪閸嬨儵鏌￠崼顐＄盎婵ǜ鍔庣槐鎺楊敂閸粎纾跨紓?(闂備緡鍋呭銊╁极?
        if bb.mod and not bb.mod.ready then
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, botBtnW, botBtnH, 8)
            nvgFillColor(vg, nvgRGBA(10, 12, 20, 140)); nvgFill(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(bx + botBtnW/2, by + botBtnH/2, math.floor(bb.mod.progress * 100) .. "%")
        end
        if bb.key == "battle" then
            menuBtnRects.battle = rect
        elseif bb.key == "gachaSeal" then
            menuBtnRects.gachaSeal = rect
        elseif bb.key == "battlepass" then
            menuBtnRects.battlepass = rect
            -- 闂佺懓鐡ㄧ湁闁硅翰鍊楅惀顏堝閵忕姳鍖?
            if HasBattlePassRedDot() then DrawRedDot(bx + botBtnW - 6, by + 6, 6) end
        elseif bb.key == "powerRank" then
            menuBtnRects.powerRank = rect
        elseif bb.key == "settings" then
            settingsPage.btnRect = rect
        end
    end

    menuBtnRects.editor = nil

    -- ===========================
    -- 6.5 婵炴垶鎸婚悧婊堝疾椤愶附鍤傚┑鐘插€舵禍?(闁圭厧鐡ㄥú姗€鎮ラ鐣屸枖濠电姴鍟悡? 濠殿喗绻愮徊濂告嚈?
    -- ===========================
    do
        local msgs = CloudManager.GetWorldChatMessages()
        worldChatUI.miniAnim = (worldChatUI.miniAnim or 0) + (1.0 / 60.0)

        if not worldChatUI.expanded then
            -- 闂佸啿鍘滈崑鎾绘煃閸忓浜?闁诲繐绻愮换鎺楁偘閵夈儙鐔煎灳瀹曞洨顢? 闂佸搫瀚晶浠嬪Φ濮樿泛瀚夐柍褜鍓熷顒侊紣娴ｄ警浼囬梺鍝勵槴閸撴繄绮旈悜钘夌畳?闂佸啿鍘滈崑鎾绘煃閸忓浜?
            local miniW = math.min(W * 0.6, 340)
            local miniH = 32
            local miniX = (W - miniW) / 2
            local miniY = bottomBarY - miniH - 6
            -- 闂佸憡顨呴敃顏堝焵椤掆偓缁绘垵危閹达附鍤勯悘鐐靛亾閻?(闂佸搫妫欓悧鐐寸珶?
            nvgBeginPath(vg); nvgRoundedRect(vg, miniX, miniY, miniW, miniH, 6)
            nvgFillColor(vg, nvgRGBA(220, 200, 160, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 120)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            -- 婵☆偆澧楅崹鎸庣妤ｅ啫鍐€闁搞儮鏅╅崝?
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(160, 80, 20, 220))
            nvgText(vg, miniX + 8, miniY + miniH / 2, "【世界】", nil)
            -- 闂佸搫鐗冮崑鎾绘煛閸屾粌顣肩紒澶屽厴楠炰線顢涘顒佹殽闁?"
            if #msgs > 0 then
                local last = msgs[#msgs]
                local displayText = (last.name or "?") .. ": " .. (last.text or "")
                if utf8.len(displayText) > 20 then
                    displayText = string.sub(displayText, 1, utf8.offset(displayText, 21) - 1) .. "..."
                end
                nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(60, 40, 20, 200))
                nvgText(vg, miniX + 58, miniY + miniH / 2, displayText, nil)
            else
                nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(120, 90, 50, 150))
                nvgText(vg, miniX + 58, miniY + miniH / 2, "点击打开世界聊天...", nil)
            end
            menuBtnRects.worldChatMini = { x = miniX, y = miniY, w = miniW, h = miniH }
        else
            -- 闂佸啿鍘滈崑鎾绘煃閸忓浜?闁诲繒鍋炲ú鏍閹存惊鐔煎灳瀹曞洨顢? 婵犮垹鐖㈤崱鏇炴瀳婵犮垹鐏堥弲婵嬫偘閵夆晛鐭?闂佸啿鍘滈崑鎾绘煃閸忓浜?
            local chatW = math.min(W * 0.88, 460)
            local chatH = math.min(H * 0.55, 420)
            local chatX = (W - chatW) / 2
            local chatY = (H - chatH) / 2

            -- 闂備緡鍓﹂崰姘跺磽?
            nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 120)); nvgFill(vg)

            -- 缂備焦鍔栭〃鍛般亹濞戙垺鍤勯悘鐐靛亾閻?(闂佸搫妫欓悧鐐寸珶婵犲洤纭€闁汇値鍨堕崣?
            nvgBeginPath(vg); nvgRoundedRect(vg, chatX, chatY, chatW, chatH, 12)
            nvgFillColor(vg, nvgRGBA(235, 215, 175, 240)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

            -- 闂佸搫绉村ú顓€傛禒瀣唨?(闂佸搫妫欓悧鐐寸珶婵犲伋搴㈡綇椤垶顥?
            local titleH2 = 36
            nvgBeginPath(vg); nvgRoundedRect(vg, chatX, chatY, chatW, titleH2, 12)
            nvgFillColor(vg, nvgRGBA(140, 90, 40, 220)); nvgFill(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
            nvgText(vg, chatX + chatW / 2, chatY + titleH2 / 2, "Chat", nil)
            -- 闂佺绻戞繛濠偽涢幘顔肩濠㈣埖鍔栫亸?
            local closeBtnS = 28
            local closeBtnX = chatX + chatW - closeBtnS - 4
            local closeBtnY2 = chatY + (titleH2 - closeBtnS) / 2
            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 180, 200))
            nvgText(vg, closeBtnX + closeBtnS / 2, closeBtnY2 + closeBtnS / 2, "X", nil)
            menuBtnRects.worldChatClose = { x = closeBtnX, y = closeBtnY2, w = closeBtnS, h = closeBtnS }

            -- 濠电偞鍨甸悧濠冨閸涙潙绀岄柛婵嗗閸?
            local msgAreaY = chatY + titleH2 + 4
            local inputH = 40
            local msgAreaH = chatH - titleH2 - inputH - 12
            nvgSave(vg)
            nvgScissor(vg, chatX + 4, msgAreaY, chatW - 8, msgAreaH)

            local avS = 24  -- 婵犮垼鍩栧娆撳磿濮樺彉鐒婇柛婵嗗閸?
            local lineH = avS + 6  -- 濠殿噯绲界换鎴濐焽椤栨埃妲堥柛顐ゅ枍缁辨牠鎮跺☉妯肩劯闁?
            local maxVisible = math.floor(msgAreaH / lineH)
            -- 闂佺厧顨庢禍婊勬叏閳轰緡鐓ユ慨姗嗗墮閻撳倿骞?"
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
                -- 婵犮垼鍩栧娆撳磿?(闂佸憡鐟崹鎶藉磻閿濆绀?"
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
                    -- 婵犮垼鍩栧娆撳磿濮橆厽鍎熼柡鍥╁櫏閺€?
                    nvgBeginPath(vg); nvgRoundedRect(vg, avX - 1, avY - 1, avS + 2, avS + 2, 4)
                    nvgFillColor(vg, nvgRGBA(180, 150, 100, 150)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(160, 120, 60, 150)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    local pat2 = nvgImagePattern(vg, avX - sx2 * (avS / cellW2),
                        avY - sy2 * (avS / cellH2),
                        imgW2 * (avS / cellW2), imgH2 * (avS / cellH2), 0, IMG.avatarSheet, 1.0)
                    nvgBeginPath(vg); nvgRoundedRect(vg, avX, avY, avS, avS, 3)
                    nvgFillPaint(vg, pat2); nvgFill(vg)
                else
                    -- 闂佸搫鍟版慨鎾Φ閺冨牆纾介煫鍥ㄦ尰缁傚牓鏌￠崘銊ヮ暢闁轰胶鍋撻—鈧俊顖涱儥閸氬洭鏌ょ憴鍕祷婵?
                    nvgBeginPath(vg); nvgRoundedRect(vg, avX, avY, avS, avS, 3)
                    nvgFillColor(vg, nvgRGBA(180, 150, 100, 200)); nvgFill(vg)
                end
                -- 闁荤姳鐒﹀妯肩礊瀹ュ棗绶為柡澶嬪灥閸撳ジ鏌ｉ幇顔藉殌闁搞値鍣ｅ畷鐘诲传閸曨厼骞?
                if m.uid and m.uid > 0 then
                    worldChatUI._avatarRects[#worldChatUI._avatarRects + 1] = {
                        x = avX, y = avY, w = avS, h = avS,
                        uid = m.uid, name = m.name or "???", av = avIdx,
                    }
                end
                -- 闂佸憡鑹剧粔鎾偤?
                local textX = avX + avS + 6
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(140, 70, 20, 220))
                local nameOnlyStr = m.name or "???"
                nvgText(vg, textX, my2, nameOnlyStr, nil)
                -- 闂佸憡鍔曢幊搴敊?(缂備焦顨忛崗娑氳姳閳哄啯鍋?"
                nvgFontSize(vg, 24)
                nvgFillColor(vg, nvgRGBA(60, 40, 20, 220))
                nvgText(vg, textX, my2 + 14, m.text or "", nil)
            end
            nvgRestore(vg)

            -- 闂佺粯澹曢弲娑㈩敊瀹ュ棛鈹嶉柍鈺佸暕缁辨牜鈧鍠栧﹢閬嶆偘閵夆晜鏅柛顐犲灩娴狀垶鏌涢幋锝庡殭闁靛洦妫冨畷鎾圭疀閹剧懓澧鹃梺鍛婂灩鐏忋劎妲愰悧鍫濈窞闁哄鍨甸崜?+ 闂佸憡鑹剧粔鎾偤?+ 濠电儑缍€椤曆勬叏閻愬闄勯柦妯侯槸閸戠娀鏌熺粙娆炬█闁瑰憡濞婇弫?"
            if worldChatUI.namePopup then
                local pp = worldChatUI.namePopup
                local ppW, ppH = 160, 60
                local ppX = math.min(pp.x + avS + 4, chatX + chatW - ppW - 8)
                local ppY = pp.y - 4
                if ppY + ppH > chatY + chatH - 50 then ppY = pp.y - ppH - 4 end
                if ppY < chatY + titleH2 then ppY = chatY + titleH2 + 4 end
                -- 閻庢鍠栧﹢閬嶆偘閵夆晜鍤勯悘鐐靛亾閻?(闂佸搫妫欓悧鐐寸珶?
                nvgBeginPath(vg); nvgRoundedRect(vg, ppX, ppY, ppW, ppH, 8)
                nvgFillColor(vg, nvgRGBA(240, 225, 190, 245)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 200)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
                -- 閻庢鍠栧﹢閬嶆偘閵夆晛绀冮柛娑卞幑娴犲牓鏌?"
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
                -- 闂佸憡鑹剧粔鎾偤?
                local ppTxtX = ppAvX + ppAvS + 8
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(80, 40, 10, 240))
                nvgText(vg, ppTxtX, ppY + ppH / 2 - 8, pp.name or "???", nil)
                -- 濠电儑缍€椤曆勬叏閻愬闄勯柦妯侯槸閸戠娀鏌熺粙娆炬█闁?
                local addBtnW, addBtnH = 70, 22
                local addBtnX = ppTxtX
                local addBtnY = ppY + ppH / 2 + 6
                local isFriend = CloudManager.IsFriend(pp.uid)
                local isMe = (CloudAPI.IsAvailable() and pp.uid == CloudAPI.GetUserId())
                if isMe then
                    nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(120, 90, 50, 180))
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgText(vg, addBtnX, addBtnY + addBtnH / 2, "You", nil)
                elseif isFriend then
                    nvgFontSize(vg, 24); nvgFillColor(vg, nvgRGBA(40, 130, 60, 200))
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgText(vg, addBtnX, addBtnY + addBtnH / 2, "Friend", nil)
                else
                    nvgBeginPath(vg); nvgRoundedRect(vg, addBtnX, addBtnY, addBtnW, addBtnH, 4)
                    nvgFillColor(vg, nvgRGBA(40, 100, 60, 220)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100, 220, 140, 180)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(100, 240, 140, 255))
                    nvgText(vg, addBtnX + addBtnW / 2, addBtnY + addBtnH / 2, "+ 加好友", nil)
                    menuBtnRects.worldChatAddFriend = { x = addBtnX, y = addBtnY, w = addBtnW, h = addBtnH, uid = pp.uid, name = pp.name }
                end
                -- 闂佽桨鑳剁换婵嬫煂濠婂喚鍤曢柛锔诲幘瀹曞爼鏌涢弽褎鎯堥柣鎾寸懇閺佸秹宕奸姀鐘卞寲闂佸憡鍨奸褔藝婵犳碍鐒鹃柕濞垮劚瑜扮娀姊婚崒銈呭箻闁轰降鍊濋弫?"
                menuBtnRects.worldChatPopupArea = { x = ppX, y = ppY, w = ppW, h = ppH }
                if not menuBtnRects.worldChatAddFriend or isMe or isFriend then
                    menuBtnRects.worldChatAddFriend = nil
                end
            else
                menuBtnRects.worldChatAddFriend = nil
                menuBtnRects.worldChatPopupArea = nil
            end

            -- 闁哄鐗婇幐鎼佸矗閸℃稑绀岄柛婵嗗閸?
            local inputY = chatY + chatH - inputH - 4
            local sendBtnW = 56
            local inputW = chatW - sendBtnW - 20
            -- 闁哄鐗婇幐鎼佸矗閸℃娴栭柛鈩冭壘閸撳綊鏌?(闂佸搫妫欓悧鐐寸珶?
            nvgBeginPath(vg); nvgRoundedRect(vg, chatX + 8, inputY, inputW, inputH - 4, 6)
            nvgFillColor(vg, nvgRGBA(255, 245, 225, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 120)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            -- 闁哄鐗婇幐鎼佸矗閸℃娴栭柛鈩兩戦悗顕€鎮?"
            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            if worldChatUI.chatInput and #worldChatUI.chatInput > 0 then
                nvgFillColor(vg, nvgRGBA(50, 30, 10, 230))
                nvgText(vg, chatX + 14, inputY + (inputH - 4) / 2, worldChatUI.chatInput, nil)
            else
                nvgFillColor(vg, nvgRGBA(150, 120, 80, 150))
                nvgText(vg, chatX + 14, inputY + (inputH - 4) / 2, "输入消息...", nil)
            end
            menuBtnRects.worldChatInput = { x = chatX + 8, y = inputY, w = inputW, h = inputH - 4 }
            -- 闂佸憡鐟﹂崹鍧楀焵椤戣法鍔嶉悗鍨矒閺?"
            local sendX = chatX + chatW - sendBtnW - 8
            nvgBeginPath(vg); nvgRoundedRect(vg, sendX, inputY, sendBtnW, inputH - 4, 6)
            nvgFillColor(vg, nvgRGBA(160, 90, 30, 220)); nvgFill(vg)
            nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 245, 220, 240))
            nvgText(vg, sendX + sendBtnW / 2, inputY + (inputH - 4) / 2, "发送", nil)
            menuBtnRects.worldChatSend = { x = sendX, y = inputY, w = sendBtnW, h = inputH - 4 }
        end
    end

    -- ===========================
    -- 7. 閻庡綊娼荤紓姘辩箔閸屾粍鍠嗛柟鐑樻煥鐠愮喖鎮楅悷鎵煟婵為棿鍗冲?(濠碘槅鍨兼禍婊堟儓閸℃稒鐒婚柛宀€鍋涚敮?
    -- ===========================
    local panelW = 230
    local panelH = 84
    local panelX = 6
    local panelY = 4

    -- 闂傚倸鐗勯崹鍝勵熆濮椻偓閹虫浠﹂悙顒傚讲 (闂佹悶鍎扮划娆撍夐幘璇叉辈闁哄稁鍓欓ˉ蹇涙煕濡ゅ啯鐒块梺?
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX + 3, panelY + 3, panelW, panelH, 8)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 50)); nvgFill(vg)
    local panelGrad = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + panelH,
        nvgRGBA(235, 215, 175, 220), nvgRGBA(215, 195, 155, 230))
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 8)
    nvgFillPaint(vg, panelGrad); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 180)); nvgStrokeWidth(vg, 2.5); nvgStroke(vg)

    -- 婵犮垼鍩栧娆撳磿?(濠碘槅鍨兼禍婊堟儓閸℃瑧纾介柍杞拌兌濮?
    local avatarSize = 50
    local avatarX = panelX + 8
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

    -- 闂佸搫鍊稿ú銈夋偤瑜庣粚閬嶅焺閸愌呯 (婵炴垶鎸搁ˇ鎶姐€侀幋鐘愁潟鐟滃秹宕? 闂佸憡鑹剧粔鎾偤?/ 闁诲氦顫夐…鍫熺?/ 闂佺懓鐡ㄩ敋濠?
    local infoX = avatarX + avatarSize + 6
    local infoTopY = panelY + 8
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local maxTextW = panelX + panelW - infoX - 6
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
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
    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(180, 60, 50, 220))
    nvgText(vg, infoX, infoTopY + 26, rankName, nil)

    -- 闂佺懓鐡ㄩ敋濠?(缂備焦顨忛崗娑氱箔娴ｇ儤鍋? 闂侀潻璐熼崝宀勫箖閺囩姭鍋?闁诲氦顫夐…鍫熺鐎涙鈻旈悗锝庡亝閻?
    local totalPwr = CalcPlayerTotalPower()
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local statX = infoX
    local statY = infoTopY + 52
    nvgFillColor(vg, nvgRGBA(255, 240, 210, 120))
    nvgText(vg, statX + 0.5, statY + 0.5, "战力 " .. FormatPower(totalPwr), nil)
    nvgFillColor(vg, nvgRGBA(80, 50, 20, 230))
    nvgText(vg, statX, statY, "战力 " .. FormatPower(totalPwr), nil)

    -- 闂佺懓鐡ㄩ敋濠?"?" 闂佸湱顭堥ˇ鐢稿箰?
    local pwrTextW = nvgTextBounds(vg, 0, 0, "战力 " .. FormatPower(totalPwr), nil)
    local qBtnX = statX + pwrTextW + 4
    local qBtnY = statY - 1
    local qBtnS = 14
    nvgBeginPath(vg); nvgCircle(vg, qBtnX + qBtnS/2, qBtnY + qBtnS/2, qBtnS/2)
    nvgFillColor(vg, nvgRGBA(160, 120, 50, 160)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 80, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(60, 30, 10, 230))
    nvgText(vg, qBtnX + qBtnS/2, qBtnY + qBtnS/2, "?", nil)
    menuBtnRects.powerHelp = { x = qBtnX, y = qBtnY, w = qBtnS, h = qBtnS }

    playerDetailBtnRect = { x = panelX, y = panelY, w = panelW, h = panelH }

    -- ===========================
    -- 8. 闂佸憡鐟ラ崢鏍箔閸屾粍鍠嗛柟鐑樻礃椤庢绱掑Δ瀣婵☆垰顦辩划?+ 濡ょ姷鍋涢悘婵嬪箟?
    -- ===========================
    local jadeBoxW = 180
    local jadeBoxH = 34
    local jadeBoxX = W - jadeBoxW - 10
    local jadeBoxY = 4

    nvgBeginPath(vg); nvgRoundedRect(vg, jadeBoxX + 2, jadeBoxY + 2, jadeBoxW, jadeBoxH, 6)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 40)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, jadeBoxX, jadeBoxY, jadeBoxW, jadeBoxH, 6)
    nvgFillColor(vg, nvgRGBA(230, 210, 170, 210)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, 180)); nvgStrokeWidth(vg, 2.0); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(jadeBoxX + 6, jadeBoxY + jadeBoxH / 2, "玉壁")
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(jadeBoxX + jadeBoxW - 32, jadeBoxY + jadeBoxH / 2, FormatJade(playerInfo.jade))

    -- 濡ょ姷鍋涢悘婵嬪箟?(+)
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
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(adBtnX + adBtnW/2, adBtnY + adBtnH/2, "+")
    local adPad = 6
    adRects.jade = { x = adBtnX - adPad, y = adBtnY - adPad, w = adBtnW + adPad*2, h = adBtnH + adPad*2 }
    -- 濡ょ姷鍋涢悘婵嬪箟閿熺姴绠甸柟閭﹀枔娴?
    nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(180, 50, 30, math.floor(160 * adPulse)))
    nvgText(vg, jadeBoxX + jadeBoxW / 2, jadeBoxY + jadeBoxH + 1, "+2000玉壁", nil)

    -- ===========================
    -- 9. 婵炴垶鎸搁鍫澝归崶顒€绠板鑸靛姈鐏?+ 婵炴垶鎸搁鍫澝归崶顒侇棃闁靛繆鍓濈欢?
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
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(dlBtnX + dlBtnW/2, dlBtnY + (dlBtnH - miniBarH)/2, "Sync " .. totalPct .. "%")
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
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            DrawWhiteInkText(panX + panW/2, panY + 6, "Module Sync")
            local modules = {
                { name = "Equip", mod = moduleState.equipment },
                { name = "Heroes", mod = moduleState.heroes },
                { name = "Skills", mod = moduleState.skills },
                { name = "Battle", mod = moduleState.battle },
            }
            local rowH = 22; local rowStartY2 = panY + 24
            local barX2 = panX + 46; local barW2 = panW - 58; local barH2 = 7
            for mi, m in ipairs(modules) do
                local ry = rowStartY2 + (mi - 1) * rowH
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, m.mod.ready and nvgRGBA(40,130,60,220) or nvgRGBA(80,60,40,200))
                nvgText(vg, barX2 - 4, ry + barH2/2, m.name, nil)
                nvgBeginPath(vg); nvgRoundedRect(vg, barX2, ry, barW2, barH2, 3)
                nvgFillColor(vg, nvgRGBA(180, 160, 120, 150)); nvgFill(vg)
                local modFillW = barW2 * m.mod.progress
                if modFillW > 1 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, barX2, ry, modFillW, barH2, 3)
                    nvgFillColor(vg, m.mod.ready and nvgRGBA(60,160,80,220) or nvgRGBA(180,120,40,200)); nvgFill(vg)
                end
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
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
    -- 10. 濠电姵娲栭崐鍦嫚閻愰潧鍨濋柟鐑樺灩閹?(闂備礁寮堕崹鍏肩珶婵犲洦鈷掓い蹇撴噺琚?
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
-- 闂佸湱顭堥ˇ鐢稿箰閾忣偅濯寸€广儱娲ㄩ弸鍌炴偣鐎ｎ亜鏆為柡鍡到铻ｉ柍銉ョ－绾偓 (闂佺懓鐡ㄨ摫闁哄鍠栧畷鐑芥倻濡崵褰查柣搴℃贡閸嬬偛顪冮崒娑崇矗闁告洦鍣? 闁荤姳鐒﹀畷姗€顢橀幖浣搁敜闁归偊鍘鹃崹?
-- ============================================================================
function DrawBtnAdjustMode()
    local W = DESIGN_W
    local H = DESIGN_H
    local t = menuAnimTimer

    -- 1. 缂傚倷鐒﹂敋闁糕晜顨婇獮瀣熺紒妯间憾闂佺厧鍟块張顒€鈻?
    if IsImageReady(IMG.bg) then
        local p = nvgImagePattern(vg, 0, 0, W, H, 0, IMG.bg, 1.0)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillPaint(vg, p); nvgFill(vg)
    else
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(25, 22, 16, 255)); nvgFill(vg)
        DrawSpinner(W / 2, H / 2, 20)
    end

    -- 闂佸憡顨呴敃顏堝焵椤掆偓缁绘垵危閹达附鐒兼い鏃€鍎抽崗濠囨偣娴ｅ弶娅嗛悗鍨矒閺岋箓顢欓懞銉у嚱濠电偞鎸搁幊蹇撯枍?
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 50)); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 2. 缂傚倷鐒﹂敋闁糕晜顨婇獮瀣熺紒妯间憾闂佸憡鐗曢幖顐︽偂濞嗘挸鐭楅柛灞剧妇閸嬫捇宕橀鍕枃
    nvgBeginPath(vg)
    nvgRect(vg, BATTLE_ZONE.left, BATTLE_ZONE.top,
        BATTLE_ZONE.right - BATTLE_ZONE.left, BATTLE_ZONE.bottom - BATTLE_ZONE.top)
    nvgStrokeColor(vg, nvgRGBA(100, 90, 60, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 3. 缂傚倷鐒﹂敋闁糕晜顨堥埀顒€婀遍崑銈咁瀶椤栨稑绶炵憸宥夋儍椤掑嫭鍎嶉柛鏇ㄤ簽閻熷繘鏌涢敃鈧悧濠勨偓鍨矒閺岋箓顢氶崱娆戭槱婵炶揪缍€濞夋洟寮妶鍡欌枖?DrawBottomActionBar 闁诲海鎳撻懟顖炲矗韫囨稒鍎庣紒瀣閸婇亶鏌ｉ妸銉ヮ仼缂佹棃顥撴禒锕傚焵椤掑嫭鐒婚柡鍕箳鐢棝鏌?"
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

    -- 缂傚倷鐒﹂敋闁糕晜顨嗙粙澶嬪緞婢舵劕娈濋梺鐟扮仢缁夊磭绱為弮鍫濇嵍?"
    local circles = {
        { cx = topCX, cy = topCY, label = "自动", sub = "行军" },
        { cx = leftCX, cy = bottomCY, label = "武技", sub = "1" },
        { cx = rightCX, cy = bottomCY, label = "武技", sub = "2" },
    }
    for _, c in ipairs(circles) do
        -- 婵犮垼鍩栭悧鏇°亹閸岀偛绀?"
        local glowGrad = nvgRadialGradient(vg, c.cx, c.cy, R * 0.8, R * 1.6,
            nvgRGBA(120, 50, 55, 40), nvgRGBA(120, 50, 55, 0))
        nvgBeginPath(vg); nvgCircle(vg, c.cx, c.cy, R * 1.6)
        nvgFillPaint(vg, glowGrad); nvgFill(vg)
        -- 闂佸湱顭堥ˇ鐢稿箰閹惰棄瀚夋い鎴ｆ硶缁?
        nvgBeginPath(vg); nvgCircle(vg, c.cx, c.cy, R)
        nvgFillColor(vg, nvgRGBA(30, 35, 50, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(120, 50, 55, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        -- 闂佸搫鍊稿ú銈夋偤?
        nvgFontSize(vg, math.max(24, math.floor(11 * btnSc)))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(c.cx, c.cy - 5 * btnSc, c.label)
        nvgFontSize(vg, math.max(24, math.floor(9 * btnSc)))
        DrawWhiteInkText(c.cx, c.cy + 7 * btnSc, c.sub)
    end

    -- 闂佸綊鏀遍悧妤冣偓姘缁嬪顢橀悩宕囨殸闁荤喐鐟ュΛ婊堬綖鎼淬劌绠甸柟閭﹀枔娴?(婵炲濮撮幊搴ｇ礊鐎ｎ喖绀堢€广儱顦崑鎾村緞婢跺骸骞€缂傚倷绀佺€氫即鎮甸鐣岊洸?"
    local activeGrp = settingsPage.adjActiveGroup or "skill"
    if settingsPage.adjDragging and activeGrp == "skill" then
        for _, c in ipairs(circles) do
            nvgBeginPath(vg); nvgCircle(vg, c.cx, c.cy, R + 3)
            nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 120)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        end
    end
    -- 闂備緡鍋勯ˇ顕€鎳欓幋鐑嗘畻婵☆垳鎳撻惁銊︿繆?(闂佺懓鐏堥崑鎾绘煠瀹曞洦娅曠紒?
    if activeGrp == "skill" then
        for _, c in ipairs(circles) do
            nvgBeginPath(vg); nvgCircle(vg, c.cx, c.cy, R + 2)
            nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        end
    end

    -- 3b. 缂傚倷鐒﹂敋闁糕晜顨婂畷锝夊礂閸涱垳鎲柣鐔哥懄鐢鈧灚绮撻弻锕傤敊閸撗呯厑婵☆偅婢樼€氼垶锝?
    local rbOfsX = settingsPage.adjRightBtnOffsetX
    local rbOfsY = settingsPage.adjRightBtnOffsetY
    local rbBtnW = 84
    local rbBtnH = 36
    local rbGap = 6
    local rbRightMargin = 4
    local rbStartY = 28 + rbOfsY
    local rbX = W - rbBtnW - rbRightMargin + rbOfsX
    local rbLabels = {"撤退", "自动", "倍速"}
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
        nvgFontSize(vg, 24)
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

    -- 3c. 缂傚倷鐒﹂敋闁糕晜顨嗛妵鍕醇閺囩偛濮UD婵☆偅婢樼€氼垶锝?
    local hudOfsX = settingsPage.adjHudOffsetX
    local hudOfsY = settingsPage.adjHudOffsetY
    local hudH2 = 28
    nvgBeginPath(vg); nvgRoundedRect(vg, 4 + hudOfsX, 2 + hudOfsY, W - 8, hudH2, 4)
    nvgFillColor(vg, nvgRGBA(30, 25, 16, 190)); nvgFill(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(16 + hudOfsX, 13 + hudOfsY, "军资")
    nvgFontSize(vg, 24)
    DrawWhiteInkText(50 + hudOfsX, 13 + hudOfsY, "99")
    nvgFontSize(vg, 24)
    DrawWhiteInkText(120 + hudOfsX, 13 + hudOfsY, "斩")
    nvgFontSize(vg, 24)
    DrawWhiteInkText(140 + hudOfsX, 13 + hudOfsY, "0")
    -- 闂佺锕ョ敮鐔碱敇閹间礁绫嶉柛顐ｆ处閺嗘洟鎮?"
    local tmrW2 = 72
    local tmrH2 = 20
    local tmrX2 = W / 2 - tmrW2 / 2 + hudOfsX
    local tmrY2 = hudH2 + 4 + hudOfsY
    nvgBeginPath(vg); nvgRoundedRect(vg, tmrX2, tmrY2, tmrW2, tmrH2, 10)
    nvgFillColor(vg, nvgRGBA(12, 10, 6, 180)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 80)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(W / 2 + hudOfsX, tmrY2 + tmrH2 / 2, "1:30")
    if activeGrp == "hud" then
        nvgBeginPath(vg); nvgRoundedRect(vg, 1 + hudOfsX, -1 + hudOfsY, W - 2, hudH2 + tmrH2 + 10, 5)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- 3d. 缂傚倷鐒﹂敋闁糕晜顨呴蹇涙晜鐠恒劎鎲柣鐔哥懄鐢﹥绌辨繝鍥х畳妞ゆ牜鍋炲銊╂煛婢跺﹥鍋ユい锝傛櫇閹?"
    local ipOfsX = settingsPage.adjInfoPanelOffsetX
    local ipOfsY = settingsPage.adjInfoPanelOffsetY
    local ipW = 110
    local ipH = 88
    local ipX = 4 + ipOfsX
    local ipY = 28 + ipOfsY
    nvgBeginPath(vg); nvgRoundedRect(vg, ipX, ipY, ipW, ipH, 4)
    nvgFillColor(vg, nvgRGBA(10, 8, 5, 140)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 130, 70, 40)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    DrawWhiteInkText(ipX + 6, ipY + 8, "Units: 3/6")
    DrawWhiteInkText(ipX + 6, ipY + 28, "ATK: 100")
    DrawWhiteInkText(ipX + 6, ipY + 48, "DEF: 80")
    nvgFontSize(vg, 24)
    DrawWhiteInkText(ipX + 6, ipY + 68, "拖拽移动面板")
    if activeGrp == "infoPanel" then
        nvgBeginPath(vg); nvgRoundedRect(vg, ipX - 3, ipY - 3, ipW + 6, ipH + 6, 5)
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    end

    -- 4. 婵＄偑鍊曢悥濂稿磿閹绢喖绠甸柟閭﹀枔娴犳盯鏌?"
    local tipBarH = 36
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, tipBarH)
    nvgFillColor(vg, nvgRGBA(10, 15, 30, 200)); nvgFill(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(W / 2, tipBarH / 2, "拖拽屏幕移动选中组位置")

    -- 5. 闁圭厧鐡ㄥú鐔煎磿閺夋埈鍟呴柕澶堝劚瀵版棃鏌?(婵犫拃鍛槐闁绘繍鍠楃粋鎺楀Ψ閵夘喖鏅ｇ紓浣瑰劤绾绢厾鍒掑澶婄闁搞儯鍔屾惔濠囨煛瀹ュ懏宸濇い?
    local barH = 90
    local barY = H - barH
    nvgBeginPath(vg); nvgRect(vg, 0, barY, W, barH)
    nvgFillColor(vg, nvgRGBA(10, 15, 30, 220)); nvgFill(vg)
    -- 婵＄偑鍊曢悥濂稿磿閹绢喖绀嗛柛鈩冪⊕椤撳墽绱?"
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, barY); nvgLineTo(vg, W, barY)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 5a. 缂傚倷绀佺€氼剟宕硅箛娑樼闁靛骏绱曢崹鑲╃磼濞戞艾浜鹃柣?
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
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(tabCurX + tw / 2, tabY + tabH / 2, g.label)
        settingsPage.adjGroupBtnRects[gi] = { x = tabCurX, y = tabY, w = tw, h = tabH, key = g.key }
        tabCurX = tabCurX + tw + tabGap
    end

    -- 5b. 缂傚倸鍊甸弲婊堝棘娴ｅ壊鐓ラ柟瀵稿仦閽?(婵炲濮撮幊蹇斾繆瑜旈幊妤呮嚍閵夈儳妯嗛梻浣虹摂閸犳氨鍒掑澶婂強闁告挆浣风驳)
    local row2Y = tabY + tabH + 8
    if activeGrp == "skill" then
        local sliderLabel = "Scale"
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

    -- 5c. 闂佸湱顭堥ˇ鐢稿箰閹惰棄绀岄柛婵嗗閸?(闁圭厧鐡ㄥú鐔煎磿閹绢喖鐭楅柛蹇撴噺濞?
    local btnAreaX = W - 190
    local btnY = row2Y
    local btnW2 = 54
    local btnH2 = 32

    -- 闂備焦褰冪粔鍫曟偪閸℃稑绠板鑸靛姈鐏?
    nvgBeginPath(vg); nvgRoundedRect(vg, btnAreaX, btnY, btnW2, btnH2, 5)
    nvgFillColor(vg, nvgRGBA(60, 55, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(btnAreaX + btnW2 / 2, btnY + btnH2 / 2, "Reset")
    settingsPage.adjResetBtnRect = { x = btnAreaX, y = btnY, w = btnW2, h = btnH2 }

    -- 婵烇絽娲︾换鍌炴偤閵娾晛绠板鑸靛姈鐏?
    local saveBtnX = btnAreaX + btnW2 + 8
    nvgBeginPath(vg); nvgRoundedRect(vg, saveBtnX, btnY, btnW2, btnH2, 5)
    local saveGrad = nvgLinearGradient(vg, saveBtnX, btnY, saveBtnX, btnY + btnH2,
        nvgRGBA(90, 45, 55, 230), nvgRGBA(60, 25, 35, 230))
    nvgFillPaint(vg, saveGrad); nvgFill(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(saveBtnX + btnW2 / 2, btnY + btnH2 / 2, "Save")
    settingsPage.adjSaveBtnRect = { x = saveBtnX, y = btnY, w = btnW2, h = btnH2 }

    -- 闁哄鏅滈弻銊ッ洪弽顓炵濠㈣埖鍔栫亸?
    local backBtnX = saveBtnX + btnW2 + 8
    nvgBeginPath(vg); nvgRoundedRect(vg, backBtnX, btnY, btnW2, btnH2, 5)
    nvgFillColor(vg, nvgRGBA(50, 35, 35, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 100, 80, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backBtnX + btnW2 / 2, btnY + btnH2 / 2, "Back")
    settingsPage.adjBackBtnRect = { x = backBtnX, y = btnY, w = btnW2, h = btnH2 }
end


