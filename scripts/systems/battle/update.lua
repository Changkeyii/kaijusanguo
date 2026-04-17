-- ============================================================================
-- systems/battle/update.lua - 涓夊浗姝︾伒褰?
-- ============================================================================


-- ============================================================================
-- 鎴樻枟缁撶畻: 鑳滃埄/缁撴潫 缁熶竴鍏ュ彛
-- ============================================================================

--- 鎴樻枟鑳滃埄鏃惰皟鐢?(缁熻銆侀閫氥€佽浼愰€氬叧銆佽В閿佷笅涓€鍏?
function OnBattleVictory()
    -- 0) 鎺㈢储妯″紡宸茬Щ闄?
    -- if gameState.explorationMode then ... end

    -- 1) 缁熻
    playerInfo.totalWins = playerInfo.totalWins + 1
    playerInfo.totalBattles = playerInfo.totalBattles + 1
    TrackDailyTask("battle3", 1)
    TrackDailyTask("win2", 1)
    TrackWeeklyTask("wbattle15", 1)
    TrackWeeklyTask("wwin10", 1)
    TrackBattlePassTask("bp_battle3", 1)
    TrackBattlePassTask("bp_win2", 1)
    TrackBattlePassTask("bp_wbattle20", 1)
    TrackBattlePassTask("bp_wwin12", 1)
    TrackBattlePassTask("bp_sbattle100", 1)
    TrackBattlePassTask("bp_swin50", 1)

    -- 2) 鍏冲崱鏄熺骇濂栧姳 (闈炶浼?鐖)
    if not gameState.abyssFloor and not gameState.towerFloor and not gameState.isRanked then
        local stageIdx = stageState.currentStage
        local key = tostring(stageIdx)
        -- 璁＄畻鏄熺骇: 鍩轰簬鍩哄湴鍓╀綑HP鐧惧垎姣?
        local hpPct = (gameState.playerBaseHP or 0) / (BASE_HP_MAX or 1)
        local earnedStars = 1
        if hpPct > 0.8 then
            earnedStars = 3
        elseif hpPct > 0.5 then earnedStars = 2 end
        -- 鏇存柊鏈€楂樻槦绾?
        local prevStars = stageStars[key] or 0
        if earnedStars > prevStars then
            stageStars[key] = earnedStars
            -- 鍙戞斁鏂拌揪鍒版槦绾х殑铏庣濂栧姳
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
                gameState.firstClearReward = { jade = totalJadeReward }
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "鈽? .. earnedStars .. " 鏄熺骇濂栧姳: +" .. totalJadeReward .. " 铏庣", 2.0, {255, 220, 80}, 20)
            end
        end
        gameState.lastEarnedStars = earnedStars  -- 淇濆瓨鐢ㄤ簬缁撶畻灞曠ず
        -- 鑷姩瑙ｉ攣涓嬩竴鍏?
        if stageIdx >= stageState.maxUnlocked and stageIdx < #STAGES then
            stageState.maxUnlocked = stageIdx + 1
        end
    end

    -- 3) 璁ㄤ紣閫氬叧濂栧姳
    if gameState.abyssFloor then
        local floorIdx = gameState.abyssFloor
        local floorKey = tostring(floorIdx)
        TrackDailyTask("abyss1", 1)
        TrackWeeklyTask("wabyss3", 1)
        TrackBattlePassTask("bp_wabyss3", 1)
        TrackBattlePassTask("bp_sabyss10", 1)
        if not abyssCleared[floorKey] then
            abyssCleared[floorKey] = true
        end
        local abReward = ABYSS_REWARDS[floorIdx]
        if abReward then
            GrantRewardTable(abReward)
            gameState.abyssReward = abReward  -- 淇濆瓨鐢ㄤ簬寮圭獥灞曠ず
        end
    end

    -- 3.5) 鐖閫氬叧濂栧姳
    if gameState.towerFloor then
        local fl = gameState.towerFloor
        -- 閫掑濂栧姳 (閫傚害闄嶄綆)
        local towerJade = 20 + fl * 7
        local towerFrag = math.min(12, math.floor(fl / 4) + 1)
        local towerReward = { jade = towerJade, frag = towerFrag }
        GrantRewardTable(towerReward)
        gameState.towerReward = towerReward  -- 淇濆瓨鐢ㄤ簬寮圭獥灞曠ず
        -- 鎺ㄨ繘灞傛暟 (涓婇檺999灞?
        towerState.currentFloor = math.min(fl + 1, 1000)  -- 1000琛ㄧず宸查€氬叧999灞傦紝涓嶅彲鍐嶆寫鎴?
        if fl > towerState.highestFloor then
            towerState.highestFloor = fl
            ReportTowerFloor()  -- 涓婃姤浜戠鎺掕姒?
        end
    end

    -- 3.8) 鎺掍綅鑳滃埄
    if gameState.isRanked then
        if IsServerAuthoritativeRankedMode and IsServerAuthoritativeRankedMode() then
            local pendingStreak = rankedState.streak or 0
            if pendingStreak < 0 then pendingStreak = 0 end
            pendingStreak = pendingStreak + 1
            local delta = CalcRankedScoreChange(true, pendingStreak)
            gameState.awaitingRankedResult = true
            gameState.rankedDelta = nil
            local Client = require("network.Client")
            local ok = Client.ReportRankedBattleResult(true, rankedState.score, delta, pendingStreak)
            if not ok then
                gameState.awaitingRankedResult = false
                if rawget(_G, "ShowToast") then ShowToast("閹烘帊缍呯紒鎾剁暬娑撳﹥濮ゆ径杈Е", 2.0) end
            end
        else
        playerInfo.totalRankedBattles = (playerInfo.totalRankedBattles or 0) + 1
        playerInfo.totalRankedWins = (playerInfo.totalRankedWins or 0) + 1
        rankedState.wins = rankedState.wins + 1
        if rankedState.streak < 0 then rankedState.streak = 0 end
        rankedState.streak = rankedState.streak + 1
        local delta = CalcRankedScoreChange(true, rankedState.streak)
        rankedState.score = math.max(0, rankedState.score + delta)
        if rankedState.score > rankedState.highestScore then
            rankedState.highestScore = rankedState.score
        end
        gameState.rankedDelta = delta  -- 淇濆瓨鐢ㄤ簬寮圭獥灞曠ず
        ReportRankedScore()
        -- 缃戠粶妯″紡: 涓婃姤鏈嶅姟绔繘琛屾潈濞?Elo 缁撶畻
        end
    end

    -- 3.9) 鎴樺満鎷涙徑 (鎴樹簤鐗? 鎴樻枟鑳滃埄鍚庢湁姒傜巼鎷涙徑涓€鍚嶆湭鎷ユ湁姝﹀皢)
    do
        local recruitResult = nil
        -- 鏀堕泦鎵€鏈夋湭鎷ユ湁鐨勬灏?(鍝佽川瓒婁綆瓒婂鏄撴嫑鎻?
        local candidates = {}
        for idx = 1, #HERO_CARDS do
            local hero = playerHeroes[idx]
            if not hero or not hero.owned then
                table.insert(candidates, idx)
            end
        end
        if #candidates > 0 then
            -- 鎷涙徑姒傜巼: 鍩虹20%, 闅忓叧鍗?璁ㄤ紣杩涘害鎻愬崌
            local recruitChance = 0.20
            if gameState.abyssFloor then
                recruitChance = 0.30 + gameState.abyssFloor * 0.05
            elseif gameState.towerFloor then
                recruitChance = 0.15 + math.min(0.25, gameState.towerFloor * 0.005)
            end
            recruitChance = math.min(0.60, recruitChance)

            if math.random() < recruitChance then
                -- 鎸夊搧璐ㄦ潈閲嶉€夋嫨 (N=40, R=30, SR=15, SSR=10, 闄愬畾=5)
                local RECRUIT_WEIGHTS = { [1] = 40, [2] = 30, [3] = 15, [4] = 10, [5] = 5 }
                local weighted = {}
                for _, idx in ipairs(candidates) do
                    local q = HERO_CARDS[idx].quality or 1
                    local w = RECRUIT_WEIGHTS[q] or 20
                    table.insert(weighted, { idx = idx, weight = w })
                end
                -- 鍔犳潈闅忔満閫夋嫨
                local totalW = 0
                for _, e in ipairs(weighted) do totalW = totalW + e.weight end
                local roll = math.random() * totalW
                local acc = 0
                local chosenIdx = weighted[1].idx
                for _, e in ipairs(weighted) do
                    acc = acc + e.weight
                    if roll <= acc then chosenIdx = e.idx; break end
                end
                -- 鎷涙徑鎴愬姛
                playerHeroes[chosenIdx] = { owned = true, constellation = 0, level = 1 }
                recruitResult = {
                    cardIdx = chosenIdx,
                    name = HERO_CARDS[chosenIdx].name,
                    quality = HERO_CARDS[chosenIdx].quality,
                    faction = HERO_CARDS[chosenIdx].faction,
                }
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                    "鎷涙徑鎴愬姛: " .. HERO_CARDS[chosenIdx].name .. "!",
                    2.5, QUALITY_COLORS[HERO_CARDS[chosenIdx].quality] or {255, 255, 255}, 22)
            end
        end
        gameState.recruitResult = recruitResult  -- 淇濆瓨鐢ㄤ簬缁撶畻鐣岄潰灞曠ず
    end

    -- 3.10) 澶у湴鍥炬垬鏂楄儨鍒╁洖璋?
    if gameState.worldMapBattle and rawget(_G, "WorldMap") then
        WorldMap.OnBattleResult(true)
    end

    -- 4) 淇濆瓨
    SaveGameProgress()
end


--- 鎴樻枟缁撴潫鏃惰皟鐢?(澶辫触/骞冲眬)
function OnBattleEnd()
    -- 鎺㈢储妯″紡宸茬Щ闄?
    -- if gameState.explorationMode then ... end

    playerInfo.totalBattles = playerInfo.totalBattles + 1
    TrackDailyTask("battle3", 1)
    TrackWeeklyTask("wbattle15", 1)
    TrackBattlePassTask("bp_battle3", 1)
    TrackBattlePassTask("bp_wbattle20", 1)
    TrackBattlePassTask("bp_sbattle100", 1)
    -- 璁ㄤ紣澶辫触涔熻鍏ヨ浼愪换鍔?
    if gameState.abyssFloor then
        TrackDailyTask("abyss1", 1)
        TrackWeeklyTask("wabyss3", 1)
        TrackBattlePassTask("bp_wabyss3", 1)
        TrackBattlePassTask("bp_sabyss10", 1)
    end
    -- 鎺掍綅澶辫触
    if gameState.isRanked then
        if IsServerAuthoritativeRankedMode and IsServerAuthoritativeRankedMode() then
            local pendingStreak = rankedState.streak or 0
            if pendingStreak > 0 then pendingStreak = 0 end
            pendingStreak = pendingStreak - 1
            local delta = CalcRankedScoreChange(false, pendingStreak)
            gameState.awaitingRankedResult = true
            gameState.rankedDelta = nil
            local Client = require("network.Client")
            local ok = Client.ReportRankedBattleResult(false, rankedState.score, delta, pendingStreak)
            if not ok then
                gameState.awaitingRankedResult = false
                if rawget(_G, "ShowToast") then ShowToast("閹烘帊缍呯紒鎾剁暬娑撳﹥濮ゆ径杈Е", 2.0) end
            end
        else
        playerInfo.totalRankedBattles = (playerInfo.totalRankedBattles or 0) + 1
        rankedState.losses = rankedState.losses + 1
        if rankedState.streak > 0 then rankedState.streak = 0 end
        rankedState.streak = rankedState.streak - 1
        local delta = CalcRankedScoreChange(false, rankedState.streak)
        rankedState.score = math.max(0, rankedState.score + delta)
        gameState.rankedDelta = delta  -- 淇濆瓨鐢ㄤ簬寮圭獥灞曠ず
        ReportRankedScore()
        -- 缃戠粶妯″紡: 涓婃姤鏈嶅姟绔繘琛屾潈濞?Elo 缁撶畻
        end
    end
    -- 澶у湴鍥炬垬鏂楀け璐ュ洖璋?
    if gameState.worldMapBattle and rawget(_G, "WorldMap") then
        WorldMap.OnBattleResult(false)
    end
    SaveGameProgress()
end


-- ============================================================================
-- 鏇存柊閫昏緫
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    gameState.gameTime = gameState.gameTime + dt

    -- DWP 鍥炶皟璁剧疆鐨勫瓧浣撻噸寤烘爣蹇楋細鍦ㄤ富绾跨▼鎵ц瀛椾綋閲嶅缓
    if fontRebuildNeeded then
        fontRebuildNeeded = false
        if fontId < 0 then
            fontId = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
            print("[MainThread] 閲嶅缓涓诲瓧浣?fontId=" .. tostring(fontId))
        end
    end

    -- 鑷姩瀛樻。锛堟瘡60绉掍繚瀛樹竴娆★紝闃叉鎰忓閫€鍑轰涪澶辫繘搴︼級
    -- 浠呭湪瀹屾垚璧勬枡璁剧疆涓旇繘鍏ヤ富鑿滃崟鍚庢墠鑷姩瀛樻。锛岄伩鍏嶅湪鍔犺浇/閫夎祫鏂欓樁娈佃鐩栨纭暟鎹?
    autoSaveTimer = (autoSaveTimer or 0) + dt
    if autoSaveTimer >= 60 then
        autoSaveTimer = 0
        if playerInfo.profileSet and gameState.phase ~= "LOADING" and gameState.phase ~= "PROFILE" then
            SaveGameProgress()
        end
    end

    -- 铏庣鈮?0涓囦竴娆℃€цВ閿佽繛鎶藉寮?(10/50/100杩炴娊)
    if not playerInfo.jadeUnlockedBigPull and playerInfo.jade >= 200000 then
        playerInfo.jadeUnlockedBigPull = true
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "杩炴娊澧炲己宸茶В閿? 10/50/100杩炴娊", 2.5, { 255, 220, 80 }, 20)
        print("[杩炴娊澧炲己] 铏庣鈮?0涓? 姘镐箙瑙ｉ攣10/50/100杩炴娊!")
    end

    -- 浜戝瓨妗ｉ噸璇?(濮旀墭缁?CloudManager)
    if rawget(_G, 'CloudManager') then CloudManager.Update(dt) end

    -- 浜ゆ槗琛屽畾鏃舵壂鎻?
    TradeManager.Tick(dt)

    -- 骞垮憡闄愬埗宸茬Щ闄?

    -- 鎴樻枟瑙勫垯寮圭獥婊氬姩鎯€?
    if battleRulesState.show and not battleRulesState.isDragging and math.abs(battleRulesState.vel) > 1 then
        battleRulesState.scrollY = battleRulesState.scrollY + battleRulesState.vel * dt
        battleRulesState.vel = battleRulesState.vel * 0.92
        local maxScroll = math.max(0, battleRulesState.contentH - battleRulesState.viewH)
        battleRulesState.scrollY = math.max(0, math.min(battleRulesState.scrollY, maxScroll))
    elseif battleRulesState.show and not battleRulesState.isDragging then
        battleRulesState.vel = 0
    end

    -- 鏂版墜鎸囧紩寮圭獥婊氬姩鎯€?
    if newbieGuidePopup.show and not newbieGuidePopup.isDragging and math.abs(newbieGuidePopup.vel or 0) > 1 then
        newbieGuidePopup.scrollY = (newbieGuidePopup.scrollY or 0) + (newbieGuidePopup.vel or 0) * dt
        newbieGuidePopup.vel = (newbieGuidePopup.vel or 0) * 0.92
        local maxScroll = math.max(0, (newbieGuidePopup.contentH or 0) - (newbieGuidePopup.viewH or 0))
        newbieGuidePopup.scrollY = math.max(0, math.min(newbieGuidePopup.scrollY, maxScroll))
    elseif newbieGuidePopup.show and not newbieGuidePopup.isDragging then
        newbieGuidePopup.vel = 0
    end

    -- 缁熶竴瑙勫垯寮圭獥婊氬姩鎯€?
    if phaseRulePopup.show and not phaseRulePopup.isDragging and math.abs(phaseRulePopup.vel or 0) > 1 then
        phaseRulePopup.scrollY = (phaseRulePopup.scrollY or 0) + (phaseRulePopup.vel or 0) * dt
        phaseRulePopup.vel = (phaseRulePopup.vel or 0) * 0.92
        local maxScroll = math.max(0, (phaseRulePopup.contentH or 0) - (phaseRulePopup.viewH or 0))
        phaseRulePopup.scrollY = math.max(0, math.min(phaseRulePopup.scrollY, maxScroll))
    elseif phaseRulePopup.show and not phaseRulePopup.isDragging then
        phaseRulePopup.vel = 0
    end

    -- 鍏电鏇挎崲寮圭獥婊氬姩鎯€?
    if sealReplaceState.show then
        local scrl = sealReplaceState.scroll
        if not scrl.isDragging and math.abs(scrl.vel or 0) > 1 then
            scrl.y = (scrl.y or 0) + (scrl.vel or 0) * dt
            scrl.vel = (scrl.vel or 0) * 0.92
            local maxScroll = math.max(0, (scrl.contentH or 0) - (scrl.viewH or 0))
            scrl.y = math.max(0, math.min(scrl.y, maxScroll))
        elseif not scrl.isDragging then
            scrl.vel = 0
        end
    end

    -- 绛栫暐閫夐」鏉? 姣忓抚妫€娴嬮暱鎸夛紙涓嶄緷璧栨墜鎸囩Щ鍔級
    if strategyWheelState.pressing and not strategyWheelState.show then
        local elapsed = gameState.gameTime - strategyWheelState.startTime
        if elapsed >= STRATEGY_LONG_PRESS then
            strategyWheelState.show = true
        end
    end

    -- (宸茬Щ闄ゆ鎶€闀挎寜寮圭獥, 鏀逛负鎸変笅鍗虫嫋鎷界瀯鍑?

    -- 鎺㈢储妯″紡甯ф洿鏂?(宸茬Щ闄ゆ帰绱㈢郴缁?
    -- if gameState.phase == "EXPLORATION" then
    --     Exploration.Update(dt)
    -- end

    -- 绱鍦ㄧ嚎鏃堕棿锛堝叏灞€锛屼笉浠呴檺浜庣鍒╅〉锛?
    welfareState.onlineTime = welfareState.onlineTime + dt

    -- BGM 鍦烘櫙鍒囨崲
    UpdateBGM()

    -- 澶╁懡璧愮婊氬姩鎯€?
    if gameState.phase == "WELFARE" then
        local ws = welfareState.scroll
        if not ws.isDragging and math.abs(ws.vel) > 0.5 then
            ws.offset = ws.offset + ws.vel * dt
            ws.vel = ws.vel * 0.92
        elseif not ws.isDragging then
            ws.vel = 0
        end
        -- 璐＄尞姒滅嫭绔嬫粴鍔ㄦ儻鎬?
        local cs = welfareState.contribScroll
        if not cs.isDragging and math.abs(cs.vel) > 0.5 then
            cs.offset = cs.offset + cs.vel * dt
            cs.vel = cs.vel * 0.92
        elseif not cs.isDragging then
            cs.vel = 0
        end
        -- 鎴樺姏鎺掕姒滅嫭绔嬫粴鍔ㄦ儻鎬?
        local ps2 = welfareState.powerScroll
        if not ps2.isDragging and math.abs(ps2.vel) > 0.5 then
            ps2.offset = ps2.offset + ps2.vel * dt
            ps2.vel = ps2.vel * 0.92
        elseif not ps2.isDragging then
            ps2.vel = 0
        end
        -- 妗╅€肩帇鎺掕姒滄粴鍔ㄦ儻鎬?
        local ds = welfareState.dummyScroll
        if not ds.isDragging and math.abs(ds.vel) > 0.5 then
            ds.offset = ds.offset + ds.vel * dt
            ds.vel = ds.vel * 0.92
        elseif not ds.isDragging then
            ds.vel = 0
        end
    end

    -- 闃佃惀鎴愬憳鍒楄〃婊氬姩鎯€?
    if gameState.phase == "FACTION" then
        local fs = factionUI.scroll
        if not fs.isDragging and math.abs(fs.vel) > 0.5 then
            fs.offset = fs.offset + fs.vel * dt
            fs.vel = fs.vel * 0.92
            if fs.offset < 0 then fs.offset = 0; fs.vel = 0 end
        elseif not fs.isDragging then
            fs.vel = 0
        end
    end

    -- 浜ゆ槗琛屾粴鍔ㄦ儻鎬?
    if gameState.phase == "TRADE" then
        local ts = tradeState.scroll
        if not ts.isDragging and math.abs(ts.vel) > 0.5 then
            ts.offset = ts.offset + ts.vel * dt
            ts.vel = ts.vel * 0.92
            if ts.offset < 0 then ts.offset = 0; ts.vel = 0 end
        elseif not ts.isDragging then
            ts.vel = 0
        end
        -- toast 璁℃椂
        if tradeState.toastTimer > 0 then
            tradeState.toastTimer = tradeState.toastTimer - dt
        end
    end

    -- 缂栭槦鐣岄潰婊氬姩鎯€?
    if gameState.phase == "FORMATION" and formationUI then
        menuAnimTimer = menuAnimTimer + dt
        if not formationUI.isDragging and math.abs(formationUI.scrollVel or 0) > 0.5 then
            formationUI.scrollY = (formationUI.scrollY or 0) + formationUI.scrollVel * dt
            formationUI.scrollVel = formationUI.scrollVel * 0.92
        elseif not formationUI.isDragging then
            formationUI.scrollVel = 0
        end
    end

    -- 閭欢鍒楄〃婊氬姩鎯€?
    if gameState.phase == "MAIL_BOX" then
        local ms = welfareState.mail.scroll
        if ms and not ms.isDragging and math.abs(ms.vel) > 0.5 then
            ms.offset = ms.offset + ms.vel * dt
            ms.vel = ms.vel * 0.92
            if ms.offset < 0 then ms.offset = 0; ms.vel = 0 end
        elseif ms and not ms.isDragging then
            ms.vel = 0
        end
    end

    -- 鎴樹护閫氳璇佷换鍔″垪琛ㄦ粴鍔ㄦ儻鎬?
    if gameState.phase == "BATTLE_PASS" and battlePassUIState.tab ~= 1 then
        local bs = battlePassUIState
        if not bs.isDragging then
            if math.abs(bs.scrollVel or 0) > 0.3 then
                bs.scrollY = bs.scrollY + bs.scrollVel * dt
                bs.scrollVel = bs.scrollVel * math.pow(0.12, dt)
            else
                bs.scrollVel = 0
            end
            -- 杈圭晫鍥炲脊
            local maxY = 0
            local minY = -math.max(0, (bs.contentHeight or 0))
            if bs.scrollY > maxY then
                bs.scrollY = bs.scrollY + (maxY - bs.scrollY) * math.min(1, 12 * dt)
                bs.scrollVel = (bs.scrollVel or 0) * 0.5
                if math.abs(bs.scrollY - maxY) < 0.5 then bs.scrollY = maxY end
            elseif bs.scrollY < minY then
                bs.scrollY = bs.scrollY + (minY - bs.scrollY) * math.min(1, 12 * dt)
                bs.scrollVel = (bs.scrollVel or 0) * 0.5
                if math.abs(bs.scrollY - minY) < 0.5 then bs.scrollY = minY end
            end
        end
    end

    -- 姣忔棩浠诲姟/鎴愬氨婊氬姩鎯€?(甯﹁竟鐣屽洖寮?
    if gameState.phase == "PROGRESS" then
        local ps = progressUIState
        if not ps.isDragging then
            -- 鎯€ц“鍑忥紙鏇村钩婊戠殑鎸囨暟琛板噺锛?
            if math.abs(ps.scrollVel) > 0.3 then
                ps.scrollY = ps.scrollY + ps.scrollVel * dt
                ps.scrollVel = ps.scrollVel * math.pow(0.12, dt) -- 鏃堕棿鏃犲叧琛板噺
            else
                ps.scrollVel = 0
            end
            -- 杈圭晫鍥炲脊
            local maxScroll = ps.contentHeight or 0
            local minY = -math.max(0, maxScroll)
            local maxY = 0
            if ps.scrollY > maxY then
                -- 椤堕儴瓒呭嚭锛屽脊鍥?
                ps.scrollY = ps.scrollY + (maxY - ps.scrollY) * math.min(1, 12 * dt)
                ps.scrollVel = ps.scrollVel * 0.5
                if math.abs(ps.scrollY - maxY) < 0.5 then ps.scrollY = maxY end
            elseif ps.scrollY < minY then
                -- 搴曢儴瓒呭嚭锛屽脊鍥?
                ps.scrollY = ps.scrollY + (minY - ps.scrollY) * math.min(1, 12 * dt)
                ps.scrollVel = ps.scrollVel * 0.5
                if math.abs(ps.scrollY - minY) < 0.5 then ps.scrollY = minY end
            end
        else
            -- 鎷栨嫿涓殑姗＄毊绛嬫晥鏋滐紙瓒呭嚭杈圭晫鏃堕樆鍔涘彉澶э級
            local maxScroll = ps.contentHeight or 0
            local minY = -math.max(0, maxScroll)
            if ps.scrollY > 0 then
                ps.scrollY = ps.scrollY * 0.6  -- 椤堕儴姗＄毊绛嬮樆鍔?
            elseif ps.scrollY < minY then
                local over = minY - ps.scrollY
                ps.scrollY = minY - over * 0.6  -- 搴曢儴姗＄毊绛嬮樆鍔?
            end
        end
    end

    -- 缂栬緫鍣ㄦ粴鍔ㄦ儻鎬?(甯﹁竟鐣屽洖寮?
    if gameState.phase == "DEV_EDITOR" then
        local es = editorState
        if not es.isDragging then
            if math.abs(es.scrollVel) > 0.3 then
                es.scrollY = es.scrollY + es.scrollVel * dt
                es.scrollVel = es.scrollVel * math.pow(0.12, dt)
            else
                es.scrollVel = 0
            end
            local maxScroll = es.contentHeight or 0
            local minY = -math.max(0, maxScroll)
            local maxY = 0
            if es.scrollY > maxY then
                es.scrollY = es.scrollY + (maxY - es.scrollY) * math.min(1, 12 * dt)
                es.scrollVel = es.scrollVel * 0.5
                if math.abs(es.scrollY - maxY) < 0.5 then es.scrollY = maxY end
            elseif es.scrollY < minY then
                es.scrollY = es.scrollY + (minY - es.scrollY) * math.min(1, 12 * dt)
                es.scrollVel = es.scrollVel * 0.5
                if math.abs(es.scrollY - minY) < 0.5 then es.scrollY = minY end
            end
        else
            local maxScroll = es.contentHeight or 0
            local minY = -math.max(0, maxScroll)
            if es.scrollY > 0 then
                es.scrollY = es.scrollY * 0.6
            elseif es.scrollY < minY then
                local over = minY - es.scrollY
                es.scrollY = minY - over * 0.6
            end
        end
    end

    -- 鐩镐綅鍒囨崲闃茬┛閫忓喎鍗撮€掑噺
    if phaseChangeCooldown > 0 then
        phaseChangeCooldown = phaseChangeCooldown - dt
    end

    -- CDK 缁撴灉鎻愮ず鍊掕鏃?
    if cdkState.resultTimer > 0 then
        cdkState.resultTimer = cdkState.resultTimer - dt
    end

    -- Toast 璁℃椂鍣ㄩ€掑噺
    if toastState.timer > 0 then
        toastState.timer = toastState.timer - dt
    end

    -- (闀挎寜涓嶅啀瑙﹀彂寮圭獥, 鏀逛负鍗曞嚮瑙﹀彂 infoPopupState)

    -- LOADING 闃舵锛氶樆濉炶祫婧愪笅杞藉畬鎴愬悗鑷姩璺宠浆
    if gameState.phase == "LOADING" then
        menuAnimTimer = menuAnimTimer + dt
        if blockingLoadState.ready then
            if playerInfo.profileSet then
                -- 宸茶缃繃璧勬枡锛岃烦杩囧ご鍍忛€夋嫨鐩存帴杩涘叆涓昏彍鍗?
                gameState.phase = "MENU"
                print("=== 闃诲鍔犺浇瀹屾垚锛宲rofileSet=true锛岀洿鎺ヨ繘鍏?MENU ===")
            else
                gameState.phase = "PROFILE"
                print("=== 闃诲鍔犺浇瀹屾垚锛岃繘鍏?PROFILE锛堥娆¤缃祫鏂欙級===")
            end
        end
        -- 鐐瑰嚮鎻愮ず鍊掕鏃?
        if loadingClickTipTimer and loadingClickTipTimer > 0 then
            loadingClickTipTimer = loadingClickTipTimer - dt
        end
        return
    end

    if gameState.phase == "PROFILE" then
        menuAnimTimer = menuAnimTimer + dt
    elseif gameState.phase == "MENU" then
        menuAnimTimer = menuAnimTimer + dt
        -- 宸︿晶鏍忔粴鍔ㄦ儻鎬?
        if not leftSidebarScroll.isDragging and math.abs(leftSidebarScroll.vel) > 0.5 then
            leftSidebarScroll.y = leftSidebarScroll.y + leftSidebarScroll.vel * dt
            leftSidebarScroll.vel = leftSidebarScroll.vel * 0.92
            local maxScroll = math.max(0, leftSidebarScroll.contentH - leftSidebarScroll.viewH)
            leftSidebarScroll.y = math.max(0, math.min(leftSidebarScroll.y, maxScroll))
        elseif not leftSidebarScroll.isDragging then
            leftSidebarScroll.vel = 0
        end
    elseif gameState.phase == "GACHA" then
        do
            gachaState.animTimer = gachaState.animTimer + dt
            if gachaState.pulling then
                gachaState.pullTimer = gachaState.pullTimer + dt
                if gachaState.pullTimer >= 1.2 then
                    gachaState.pulling = false
                    gachaState.showResults = true
                end
            end
            if sealGachaState.pulling then
                sealGachaState.pullTimer = sealGachaState.pullTimer + dt
                if sealGachaState.pullTimer >= 1.2 then
                    sealGachaState.pulling = false
                    sealGachaState.showResults = true
                end
            end
        end
        -- 娈嬬墖浠撳簱鎯€ф粴鍔?
        if gachaState.showFragShop and not fragShopScroll.isDragging and math.abs(fragShopScroll.vel) > 0.5 then
            fragShopScroll.offset = fragShopScroll.offset + fragShopScroll.vel * dt
            fragShopScroll.vel = fragShopScroll.vel * 0.92
        elseif gachaState.showFragShop then
            fragShopScroll.vel = 0
        end
    elseif gameState.phase == "CODEX" then
        menuAnimTimer = menuAnimTimer + dt
        -- 婊氬姩鎯€?
        if not codexScroll.isDragging and math.abs(codexScroll.vel) > 0.5 then
            codexScroll.y = codexScroll.y + codexScroll.vel * dt
            codexScroll.vel = codexScroll.vel * 0.92  -- 鎽╂摝鍔涜“鍑?
        else
            codexScroll.vel = 0
        end
    elseif gameState.phase == "HERO_DETAIL" then
        menuAnimTimer = menuAnimTimer + dt
        -- 婊氬姩鎯€?
        if not heroDetailScroll.isDragging and math.abs(heroDetailScroll.vel) > 0.5 then
            heroDetailScroll.y = heroDetailScroll.y + heroDetailScroll.vel * dt
            heroDetailScroll.vel = heroDetailScroll.vel * 0.92
        else
            heroDetailScroll.vel = 0
        end
    elseif gameState.phase == "PLAYER_DETAIL" then
        menuAnimTimer = menuAnimTimer + dt
        -- 婊氬姩鎯€?
        if not playerDetailScroll.isDragging and math.abs(playerDetailScroll.vel) > 0.5 then
            playerDetailScroll.y = playerDetailScroll.y + playerDetailScroll.vel * dt
            playerDetailScroll.vel = playerDetailScroll.vel * 0.92
        else
            playerDetailScroll.vel = 0
        end
    elseif gameState.phase == "SKILL_CODEX" then
        menuAnimTimer = menuAnimTimer + dt
        -- 婊氬姩鎯€?
        if not skillCodexState.isDragging and math.abs(skillCodexState.scrollVel) > 0.5 then
            skillCodexState.scrollY = skillCodexState.scrollY + skillCodexState.scrollVel * dt
            skillCodexState.scrollVel = skillCodexState.scrollVel * 0.92
        else
            skillCodexState.scrollVel = 0
        end
        -- 婊氬姩鑼冨洿闄愬埗
        local maxScroll = math.max(0, (skillCodexState.contentH or 0) - (DESIGN_H - 68))
        skillCodexState.scrollY = math.max(0, math.min(maxScroll, skillCodexState.scrollY))
    elseif gameState.phase == "EQUIP" then
        menuAnimTimer = menuAnimTimer + dt
        -- 鏂扮増EquipUI鏇存柊锛堟粴鍔ㄦ儻鎬с€侀暱鎸夎鏃剁瓑锛?
        if EquipUI.isVisible then
            EquipUI.Update(dt)
        else
            -- 鏃х増婊氬姩鎯€?
            if not equipScreenState.isDragging and math.abs(equipScreenState.scrollVel) > 0.5 then
                equipScreenState.scrollY = equipScreenState.scrollY + equipScreenState.scrollVel * dt
                equipScreenState.scrollVel = equipScreenState.scrollVel * 0.92
            elseif not equipScreenState.isDragging then
                equipScreenState.scrollVel = 0
            end
        end
    elseif gameState.phase == "EQUIP_CODEX" then
        menuAnimTimer = menuAnimTimer + dt
        -- 鍏电敳鍥惧綍婊氬姩鎯€?
        if not equipCodexState.isDragging and math.abs(equipCodexState.scrollVel) > 0.5 then
            equipCodexState.scrollY = equipCodexState.scrollY + equipCodexState.scrollVel * dt
            equipCodexState.scrollVel = equipCodexState.scrollVel * 0.92
        elseif not equipCodexState.isDragging then
            equipCodexState.scrollVel = 0
        end
    elseif gameState.phase == "SEAL_MGR" then
        menuAnimTimer = menuAnimTimer + dt
        -- 鍏电绠＄悊婊氬姩鎯€э紙閫変腑鍒嗚В鍒楄〃锛?
        if not sealMgrScroll.isDragging and math.abs(sealMgrScroll.vel) > 0.5 then
            sealMgrScroll.y = (sealMgrScroll.y or 0) + sealMgrScroll.vel * dt
            sealMgrScroll.vel = sealMgrScroll.vel * 0.92
            -- 杈圭晫闄愬埗
            local maxS = math.max(0, (sealMgrScroll.contentH or 0) - (sealMgrScroll.viewH or 0))
            sealMgrScroll.y = math.max(0, math.min(sealMgrScroll.y, maxS))
        elseif not sealMgrScroll.isDragging then
            sealMgrScroll.vel = 0
        end
        -- 鑻遍泟閫夋嫨寮圭獥婊氬姩鎯€?
        if sealMgrState.showHeroPicker and not heroPickerScroll.isDragging and math.abs(heroPickerScroll.vel) > 0.5 then
            heroPickerScroll.y = (heroPickerScroll.y or 0) + heroPickerScroll.vel * dt
            local maxScroll = math.max(0, (heroPickerScroll.contentH or 0) - (heroPickerScroll.viewH or 0))
            heroPickerScroll.y = math.max(0, math.min(heroPickerScroll.y, maxScroll))
            heroPickerScroll.vel = heroPickerScroll.vel * 0.92
        elseif sealMgrState.showHeroPicker and not heroPickerScroll.isDragging then
            heroPickerScroll.vel = 0
        end
    elseif gameState.phase == "WELFARE" then
        menuAnimTimer = menuAnimTimer + dt
    elseif gameState.phase == "MAIL_BOX" then
        menuAnimTimer = menuAnimTimer + dt
    elseif gameState.phase == "POWER_RANK" then
        menuAnimTimer = menuAnimTimer + dt
        -- 鎴樺姏/澧冪晫鎺掕姒滄粴鍔ㄦ儻鎬э紙鏍规嵁褰撳墠椤电锛?
        local ps2 = welfareState.powerScroll
        if not ps2.isDragging and math.abs(ps2.vel) > 0.5 then
            ps2.offset = ps2.offset + ps2.vel * dt
            ps2.vel = ps2.vel * 0.92
        elseif not ps2.isDragging then
            ps2.vel = 0
        end
        local rs2 = welfareState.realmScroll
        if not rs2.isDragging and math.abs(rs2.vel) > 0.5 then
            rs2.offset = rs2.offset + rs2.vel * dt
            rs2.vel = rs2.vel * 0.92
        elseif not rs2.isDragging then
            rs2.vel = 0
        end
    elseif gameState.phase == "CONTRIB_RANK" then
        menuAnimTimer = menuAnimTimer + dt
        -- 璐＄尞姒滆鎯呴〉婊氬姩鎯€?
        local cs2 = welfareState.contribDetailScroll
        if not cs2.isDragging and math.abs(cs2.vel) > 0.5 then
            cs2.offset = cs2.offset + cs2.vel * dt
            cs2.vel = cs2.vel * 0.92
        elseif not cs2.isDragging then
            cs2.vel = 0
        end
    elseif gameState.phase == "WORLD_MAP" then
        menuAnimTimer = menuAnimTimer + dt
        WorldMap.UpdateGuide(dt)
        WorldMap.UpdateMarch(dt)
        WorldMap.UpdateMapDrag(dt)
    elseif gameState.phase == "RANKED_SELECT" then
        menuAnimTimer = menuAnimTimer + dt
        -- 排位匹配动画: 服务端确认配对后再进入战斗
        if rankedState.isMatching then
            rankedState.matchAnim = rankedState.matchAnim + dt
            if rankedState.matchReady and rankedState.matchAnim >= 1.0 then
                rankedState.isMatching = false
                rankedState.matchReady = false
                rankedState.matchAnim = 0
                gameState.isRanked = true
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
                local tierIdx = GetRankedTier(rankedState.score).index
                stageMaxTier = math.min(6, math.max(1, tierIdx))
                for _, sk in ipairs(SKILL_DEFS) do sk.cooldown = 0 end
                activeSkillEffects = {}
                skillTargeting.active = false
                for _, s in ipairs(PLAYER_SLOTS) do s.filled = false; s.card = nil end
                for _, s in ipairs(ENEMY_SLOTS) do s.filled = false; s.card = nil end
                playerUnits = {}
                enemyUnits = {}
                inventory = {}
                RefreshShop()
                local oppCards = rankedState.opponentCards or {}
                for i = 1, math.min(#oppCards, #ENEMY_SLOTS) do
                    local card = DeepCopy(oppCards[i])
                    ENEMY_SLOTS[i].filled = true
                    ENEMY_SLOTS[i].card = card
                end
                local bgIdx = math.random(1, 8)
                ApplyBattleLayout(bgIdx)
                InitAISkills()
                PlaySFX(AUDIO.sfx_click)
                print("=== 排位匹配完成，进入战斗 vs " .. tostring(rankedState.opponentName or "Unknown") .. " ===")
            end
        end
            end
        end
        -- 鎺掕姒滄粴鍔ㄦ儻鎬?
        if rankedState.showLeaderboard and not rankedState.rankScroll.isDragging then
            if math.abs(rankedState.rankScroll.vel) > 0.5 then
                rankedState.rankScroll.offset = rankedState.rankScroll.offset + rankedState.rankScroll.vel * dt
                rankedState.rankScroll.vel = rankedState.rankScroll.vel * 0.92
            else
                rankedState.rankScroll.vel = 0
            end
            rankedState.rankScroll.offset = math.max(0, rankedState.rankScroll.offset)
        end
    elseif gameState.phase == "DUMMY_SELECT" then
        menuAnimTimer = menuAnimTimer + dt
        -- 鎵撴々閫夊皢婊氬姩鎯€?
        if not dummyState.isDragging and math.abs(dummyState.scrollVel) > 0.5 then
            dummyState.scrollY = dummyState.scrollY + dummyState.scrollVel * dt
            dummyState.scrollVel = dummyState.scrollVel * 0.92
        elseif not dummyState.isDragging then
            dummyState.scrollVel = 0
        end
        local maxScroll = math.max(0, dummyState.contentH - dummyState.gridH)
        dummyState.scrollY = math.max(0, math.min(maxScroll, dummyState.scrollY))
    elseif gameState.phase == "DUMMY_RESULT" then
        menuAnimTimer = menuAnimTimer + dt
    elseif gameState.phase == "SKILL_DETAIL" then
        menuAnimTimer = menuAnimTimer + dt
        -- skillFxTimer 澶嶇敤 menuAnimTimer
    elseif gameState.phase == "BATTLE" then
        -- 鎴樻枟鍊嶉€? 涔樹互鍊嶇巼
        local battleDt = dt * (gameState.battleSpeed or 1)
        UpdateAutoBattle(dt)  -- 鑷姩鎴樻枟鐢ㄥ師濮媎t鑺傛祦
        UpdateBattle(battleDt)
    elseif gameState.phase == "WIN" or gameState.phase == "LOSE" then
        gameState.resultTimer = gameState.resultTimer + dt
        if gameState.showRewardPopup then
            gameState.rewardPopupTimer = (gameState.rewardPopupTimer or 0) + dt
        end
    end

    -- 椋樺瓧
    for i = #floatTexts, 1, -1 do
        floatTexts[i].timer = floatTexts[i].timer + dt
        if floatTexts[i].timer >= floatTexts[i].duration then table.remove(floatTexts, i) end
    end

    -- 绮掑瓙
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.timer = p.timer + dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 50 * dt  -- 閲嶅姏
        if p.timer >= p.life then table.remove(particles, i) end
    end
end


--- 鏍规嵁鑷姩琛屽啗绛栫暐閫夋嫨杞﹂亾
function PickLaneByStrategy(strategy)
    if strategy == "mid_focus" then
        -- 鍏ㄦ涓矾: 鍏ㄩ儴鍏靛姏闆嗕腑绗?閬?
        return 3
    elseif strategy == "side_spread" then
        -- 鍒嗘暎渚х考: 鍏ㄩ儴鍏靛姏鍙蛋绗?鍜岀5閬?
        if math.random(2) == 1 then return 1 else return 5 end
    else
        -- 浜旇矾骞惰繘(榛樿): 闅忔満鍏ㄨ溅閬?
        return math.random(1, NUM_LANES)
    end
end


--- 鑷姩閲婃斁鐜╁鎶€鑳?(autoMarch寮€鍚椂, 鎵嬪姩鎿嶄綔浼樺厛)
function UpdateAutoSkills(dt)
    if not gameState.autoMarch then return end
    if skillTargeting.active then return end  -- 鐜╁姝ｅ湪鎵嬪姩鐬勫噯锛岃烦杩?
    if #playerEquippedSkills == 0 then return end
    if #playerUnits == 0 then return end  -- 娌℃湁宸辨柟鍗曚綅涓嶉噴鏀?

    autoSkillState.timer = autoSkillState.timer + dt
    if autoSkillState.timer < autoSkillState.nextTime then return end

    autoSkillState.timer = 0
    autoSkillState.nextTime = autoSkillState.interval + (math.random() - 0.5) * 2.0

    -- 绛涢€夊彲鐢?涓嶅湪CD)鐨勫凡瑁呭鎶€鑳?
    local readySkills = {}
    for _, techIdx in ipairs(playerEquippedSkills) do
        local skill = SKILL_DEFS[techIdx]
        if skill and skill.unlocked and skill.cooldown <= 0 then
            table.insert(readySkills, techIdx)
        end
    end
    if #readySkills == 0 then return end

    -- 闅忔満閫変竴涓妧鑳?
    local chosenIdx = readySkills[math.random(1, #readySkills)]
    local skill = SKILL_DEFS[chosenIdx]
    if not skill then return end

    -- 璁＄畻鐩爣: 浼樺厛鐬勫噯鏁屾柟鍗曚綅
    local targetX, targetY
    if skill.skillType == "line" then
        local laneIdx = PickLaneByStrategy(gameState.autoMarchStrategy)
        targetX = GetLaneCenterX(laneIdx)
        targetY = BATTLE_ZONE.centerY
    else
        if #enemyUnits > 0 then
            local target = enemyUnits[math.random(1, #enemyUnits)]
            if target and target.alive then
                targetX = target.x + (math.random() - 0.5) * 30
                targetY = target.y + (math.random() - 0.5) * 20
            end
        end
        if not targetX then
            targetX = BATTLE_ZONE.left + math.random() * (BATTLE_ZONE.right - BATTLE_ZONE.left)
            targetY = BATTLE_ZONE.centerY - math.random() * (BATTLE_ZONE.centerY - BATTLE_ZONE.enemyLine) * 0.5
        end
    end

    -- 閲婃斁鎶€鑳?(澶嶇敤 CastSkill)
    CastSkill(chosenIdx, targetX, targetY)
    AddFloatText(targetX, targetY - 50, "鑷姩: " .. skill.name, 1.0, { skill.color[1], skill.color[2], skill.color[3] }, 14)
end


-- ============================================================================
-- 鍏ㄨ嚜鍔ㄦ垬鏂?AI (绠€鍗曢€昏緫: 鑷姩涔板崱涓婇樀銆佸紑鎴樸€佽鍐涖€佸埛鏂?
-- ============================================================================

--- 鑷姩浠庡晢搴楄喘涔板崱鐗屽苟鏀惧叆绌烘Ы浣?
--- @return boolean 鏄惁鎴愬姛璐拱浜嗚嚦灏戜竴寮?
function AutoBuyAndPlace()
    local bought = false

    -- 浼樺厛绾х瓥鐣?
    -- 1. 浼樺厛璐拱鑳戒笌宸蹭笂闃垫鐏靛悎骞跺崌绾х殑鍗＄墝 (鍚屽悕)
    -- 2. 鍏舵鎸夎垂鐢ㄩ檷搴忚喘涔伴珮鍝佽川鍗＄墝
    -- 3. 鏈夌┖妲芥墠鏀炬柊鍗?

    -- 鏀堕泦宸蹭笂闃垫鐏靛悕绉?(鐢ㄤ簬鍚堝苟鍗囩骇鍒ゆ柇)
    local onBoardNames = {}
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            onBoardNames[slot.card.name] = true
        end
    end

    -- 鎸夎垂鐢ㄩ檷搴忔帓鍒楃储寮?
    local sortedIndices = {}
    for i = 1, #shopCards do sortedIndices[i] = i end

    -- 鎺掑簭: 鍙悎骞剁殑浼樺厛, 鍚屼紭鍏堢骇鎸夎垂鐢ㄩ檷搴?
    table.sort(sortedIndices, function(a, b)
        local sa, sb = shopCards[a], shopCards[b]
        local heroA = HERO_CARDS[sa.cardIdx]
        local heroB = HERO_CARDS[sb.cardIdx]
        local mergeA = (heroA and onBoardNames[heroA.name]) and 1 or 0
        local mergeB = (heroB and onBoardNames[heroB.name]) and 1 or 0
        if mergeA ~= mergeB then return mergeA > mergeB end
        return sa.cost > sb.cost
    end)

    for _, i in ipairs(sortedIndices) do
        local shopItem = shopCards[i]
        if not shopItem.sold and gameState.gold >= shopItem.cost then
            -- 鍏堟鏌ヨ兘鍚﹀悎骞跺埌宸叉湁鍚屽悕妲戒綅
            local heroData = HERO_CARDS[shopItem.cardIdx]
            local mergeSlot = nil
            if heroData then
                for _, slot in ipairs(PLAYER_SLOTS) do
                    if slot.filled and slot.card and slot.card.name == heroData.name then
                        mergeSlot = slot
                        break
                    end
                end
            end

            if mergeSlot then
                -- 鍚堝苟鍗囩骇: 璐拱鍚庡崌绾у凡鏈夊崱鐗?
                gameState.gold = gameState.gold - shopItem.cost
                shopItem.sold = true
                -- 鍗囩骇: 绛夌骇+1, 灞炴€ф彁鍗?
                local mc = mergeSlot.card
                mc.level = (mc.level or 1) + 1
                mc.constellation = (mc.constellation or 0) + (shopItem.constellation or 0)
                bought = true
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.5,
                    mc.name .. " 鍗囩骇 Lv" .. mc.level, 1.0, { 255, 220, 80 }, 14)
            else
                -- 鎵句竴涓┖妲戒綅鏀炬柊鍗?
                local emptySlot = nil
                for _, slot in ipairs(PLAYER_SLOTS) do
                    if not slot.filled then
                        emptySlot = slot
                        break
                    end
                end
                if not emptySlot then break end -- 娌℃湁绌烘Ы浣嶄簡
                -- 璐拱骞舵斁缃?
                gameState.gold = gameState.gold - shopItem.cost
                shopItem.sold = true
                local cardData = DeepCopy(HERO_CARDS[shopItem.cardIdx])
                cardData.cardIdx = shopItem.cardIdx
                cardData.constellation = shopItem.constellation or 0
                cardData.level = 1
                SetupSlotHero(emptySlot, cardData)
                bought = true
            end
        end
    end
    if bought then RefreshBaseStats() end
    return bought
end


--- 鑷姩鎴樻枟涓绘洿鏂?(鐢ㄥ師濮媎t鑺傛祦, 涓嶅彈鍊嶉€熷奖鍝?
function UpdateAutoBattle(dt)
    if not gameState.autoBattle then return end
    if gameState.noFullAuto then gameState.autoBattle = false; return end -- 鍓湰绂佺敤鍏ㄨ嚜鍔?

    autoBattleTimer = (autoBattleTimer or 0) + dt

    if gameState.battlePhase == "SHOP" then
        -- SHOP闃舵: 姣?.3s鎵ц涓€娆? 涔板崱涓婇樀鐒跺悗寮€鎴?
        if autoBattleTimer < 0.3 then return end
        autoBattleTimer = 0

        -- 鑷姩璐拱骞朵笂闃?
        local bought = AutoBuyAndPlace()

        -- 濡傛灉涔颁笉鍒版洿澶氬崱 (閽变笉澶熸垨妲戒綅婊?, 鑷姩寮€鎴?
        if not bought and GetPlayerFilledSlotCount() > 0 then
            gameState.battlePhase = "FIGHT"
            AggregateBaseStats()
            gameState.autoMarch = true
            gameState.battleTime = 0
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "鑷姩寮€鎴?", 1.5, { 120, 255, 180 }, 18)
            PlaySFX(AUDIO.sfx_march)
        end

    elseif gameState.battlePhase == "FIGHT" then
        -- FIGHT闃舵: 姣?s鎵ц涓€娆?
        if autoBattleTimer < 1.0 then return end
        autoBattleTimer = 0

        -- 纭繚鑷姩琛屽啗寮€鍚?
        if not gameState.autoMarch then
            gameState.autoMarch = true
        end

        -- 鍟嗗簵鍞絼涓旀湁鍐涜祫鏃惰嚜鍔ㄥ埛鏂?
        if GetUnsoldShopCardCount() == 0 and gameState.gold >= GameConfig.REFRESH_COST then
            gameState.gold = gameState.gold - GameConfig.REFRESH_COST
            RefreshShop()
        end

        -- 鑷姩璐拱鏂板崱骞舵斁鍏ョ┖妲戒綅
        AutoBuyAndPlace()
    end
end


function UpdateBattle(dt)
    -- ============================
    -- SHOP: 甯冮樀璐崱闃舵 - 涓嶅嚭鍏? 绛夌帺瀹剁偣鍑诲紑鎴?
    -- ============================
    if gameState.battlePhase == "SHOP" then
        return
    end

    -- ============================
    -- FIGHT: 杩炵画鍑哄叺+鎴樻枟 (鏃犲洖鍚? 鐩村埌涓€鏂瑰熀鍦拌閲忓綊闆?
    -- ============================

    -- === 鎵撴々妯″紡: 30s鍊掕鏃?+ 浼ゅ杩借釜 ===
    if gameState.isDummy then
        -- 鍑嗗闃舵涓嶈鏃?
        if dummyState.prepPhase then return end

        local prevHP = gameState.enemyBaseHP
        -- 缁х画姝ｅ父鎴樻枟鏇存柊锛堜笅鏂归€昏緫浼氬噺灏慹nemyBaseHP锛?
        -- 浣嗗厛澶勭悊璁℃椂
        dummyState.timer = dummyState.timer - dt
        if dummyState.timer <= 0 then
            -- 璁＄畻鏈抚鏈€鍚庝激瀹?
            local frameDmg = prevHP - gameState.enemyBaseHP
            if frameDmg > 0 then
                dummyState.totalDamage = dummyState.totalDamage + frameDmg
            end
            -- 鏃堕棿鍒帮紝杩涘叆缁撴灉椤?
            gameState.phase = "DUMMY_RESULT"
            gameState.isDummy = false
            gameState.abyssFloor = nil
            gameState.towerFloor = nil
            gameState.isRanked = false
            dummyState.prepPhase = false
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "鏃堕棿鍒?", 2.0, { 255, 200, 60 }, 36)
            PlaySFX(AUDIO.sfx_click)
            print(string.format("=== 30s鎵撴々缁撴潫 | 鎬讳激瀹? %d | DPS: %.0f ===",
                math.floor(dummyState.totalDamage), dummyState.totalDamage / 30))
            -- 璁板綍鏈€楂樻墦妗╀激瀹?& 涓婃姤鍒版々閫肩帇鎺掕姒?
            if dummyState.totalDamage > (playerInfo.bestDummyDamage or 0) then
                playerInfo.bestDummyDamage = dummyState.totalDamage
            end
            ReportDummyScore(dummyState.totalDamage)
            return
        end
    end

    gameState.battleTime = gameState.battleTime + dt

    -- 鍐涜祫鑷姩澧為暱 (姣?0s +1)
    gameState.goldTimer = gameState.goldTimer + dt
    if gameState.goldTimer >= GameConfig.GOLD_INTERVAL then
        gameState.goldTimer = gameState.goldTimer - GameConfig.GOLD_INTERVAL
        gameState.gold = gameState.gold + GameConfig.GOLD_PER_TICK
        AddFloatText(DESIGN_W * 0.15, DESIGN_H * 0.35, "+1 鍐涜祫", 1.2, { 100, 220, 255 }, 22)
    end

    -- === 鐜╁閮ㄧ讲鍐峰嵈鍊掕鏃?(鎵嬪姩鎷栨嫿閮ㄧ讲, 涓嶅啀鑷姩鍑哄叺) ===
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.deployCD and slot.deployCD > 0 then
            slot.deployCD = slot.deployCD - dt
            if slot.deployCD < 0 then slot.deployCD = 0 end
        end
    end

    -- === 鑷姩琛屽啗: 宸蹭笂闃典笖涓嶅湪CD鏈熺殑姝︾伒绔嬪嵆娲惧叺(鎸夌瓥鐣ラ€夎溅閬? ===
    if gameState.autoMarch then
        for _, slot in ipairs(PLAYER_SLOTS) do
            if slot.filled and slot.card then
                local cd = slot.deployCD or 0
                local unitCap = GetPlayerUnitCap()
                if cd <= 0 and #playerUnits < unitCap then
                    local laneIdx = PickLaneByStrategy(gameState.autoMarchStrategy)
                    local batchSize = GetBatchSizeForSlot(slot)
                    local spawned = 0
                    for _ = 1, batchSize do
                        if #playerUnits < unitCap then
                            SpawnUnitFromSlot(slot, true, laneIdx)
                            spawned = spawned + 1
                        end
                    end
                    slot.deployCD = DEPLOY_CD
                    slot.spawnFlash = 0.5
                    slot.spawnCount = (slot.spawnCount or 0) + spawned
                end
            end
        end
    end

    -- === 鏁屾柟鍑哄叺: 鍏变韩璁℃椂鍣?姣忔CD鍒伴殢鏈洪€変竴涓Ы浣嶆淳1鍏?===
    -- (鏃ф柟妗? 姣忔Ы鐙珛1.2sCD 鈫?3-4妲?0.3s涓€涓叺, 涓ラ噸杩囧揩)
    if not gameState.isDummy then
        enemySpawnTimer = enemySpawnTimer + dt
        if enemySpawnTimer >= ENEMY_SPAWN_CD and #enemyUnits < MAX_ENEMY_UNITS then
            enemySpawnTimer = enemySpawnTimer - ENEMY_SPAWN_CD
            local filledSlots = {}
            for _, slot in ipairs(ENEMY_SLOTS) do
                if slot.filled and slot.card then table.insert(filledSlots, slot) end
            end
            if #filledSlots > 0 then
                local slot = filledSlots[math.random(1, #filledSlots)]
                slot.spawnCount = (slot.spawnCount or 0) + 1
                SpawnUnitFromSlot(slot, false)
            end
        end
    end

    -- === 鍑哄叺闂厜琛板噺 (鍘熷湪 UpdateHeroSkills 涓? ===
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.spawnFlash and slot.spawnFlash > 0 then slot.spawnFlash = slot.spawnFlash - dt end
    end
    for _, slot in ipairs(ENEMY_SLOTS) do
        if slot.spawnFlash and slot.spawnFlash > 0 then slot.spawnFlash = slot.spawnFlash - dt end
    end

    -- 鏇存柊姝︽妧鎶€鑳界壒鏁?
    UpdateSkillEffects(dt)

    -- AI瀵规墜閲婃斁姝︽妧鎶€鑳?(鎺掍綅/璁ㄤ紣妯″紡)
    UpdateAISkills(dt)

    -- 鐜╁鑷姩閲婃斁鎶€鑳?(鑷姩琛屽啗寮€鍚椂, 鎵嬪姩浼樺厛)
    UpdateAutoSkills(dt)

    -- 鏇存柊鍏靛姏鎴樻枟
    UpdateUnits(dt, playerUnits, enemyUnits, true)
    UpdateUnits(dt, enemyUnits, playerUnits, false)

    -- === 鐜╁鍏电獊鐮存晫鏂逛复鐣岀嚎 >> 鐩存帴鏀诲嚮鏁屾柟澶ф湰钀?===
    -- 鐨囧鎴樹簤璁捐: 绐佺牬=澶т激瀹? 涓€涓叺杩囩嚎灏卞緢鐥?
    for i = #playerUnits, 1, -1 do
        local u = playerUnits[i]
        if u.alive and u.x >= BATTLE_ZONE.enemyLine - 8 then
            -- 绐佺牬浼ゅ = 鍏礎TK鍏ㄩ + 鍏电棰濆绐佺牬 + 鍓╀綑HP鍗犳瘮鍔犳垚
            local classBreak = (u.unitClass and u.unitClass.breakDmg or 1) * 15
            local hpRatio = u.hp / math.max(1, u.maxHp)
            local rawDmg = math.ceil(u.atk * 1.0 + classBreak + u.atk * hpRatio * 0.5)
            -- 绐佺牬浼ゅ鍔犳垚: 鍏电 + 瑁呭璇嶆潯
            local totalBreakPct = (u.sealBreakDmgPct or 0) + (u.equipBreakDmgPct or 0)
            if totalBreakPct > 0 then
                rawDmg = math.ceil(rawDmg * (1 + totalBreakPct / 100))
            end
            local breakDmg = math.max(5, rawDmg)
            gameState.enemyBaseHP = gameState.enemyBaseHP - breakDmg
            AddFloatText(BATTLE_ZONE.enemyLine - 5, u.y, "-" .. breakDmg, 1.0, { 100, 255, 150 }, 26)
            -- 绐佺牬鐖嗙偢鐗规晥 (鏇村ぇ鏇翠寒)
            for _ = 1, 8 do
                AddParticle(BATTLE_ZONE.enemyLine, u.y, {
                    vx = (math.random() * 50 + 15), vy = (math.random() - 0.5) * 100,
                    life = 0.6, size = 3, color = { 100, 255, 180 },
                })
            end
            u.alive = false
        end
        if not u.alive then table.remove(playerUnits, i) end
    end

    -- === 鏁屾柟鍏电獊鐮寸帺瀹朵复鐣岀嚎 >> 鐩存帴鏀诲嚮鐜╁澶ф湰钀?===
    for i = #enemyUnits, 1, -1 do
        local u = enemyUnits[i]
        -- 鎵撴々鑰佽檸涓嶇Щ鍔?speed=0)锛屼笉浼氱獊鐮翠复鐣岀嚎锛屼絾浠ラ槻涓囦竴涔熻烦杩?
        if u.alive and u.x <= BATTLE_ZONE.playerLine + 8 then
            if not u.isDummyTiger then
                local classBreak = (u.unitClass and u.unitClass.breakDmg or 1) * 15
                local hpRatio = u.hp / math.max(1, u.maxHp)
                local rawDmg = math.ceil(u.atk * 1.0 + classBreak + u.atk * hpRatio * 0.5)
                local breakDmg = math.max(5, rawDmg)
                gameState.playerBaseHP = gameState.playerBaseHP - breakDmg
                AddFloatText(BATTLE_ZONE.playerLine + 5, u.y, "-" .. breakDmg, 1.0, { 255, 100, 80 }, 26)
                for _ = 1, 8 do
                    AddParticle(BATTLE_ZONE.playerLine, u.y, {
                        vx = -(math.random() * 50 + 15), vy = (math.random() - 0.5) * 100,
                        life = 0.6, size = 3, color = { 255, 80, 60 },
                    })
                end
                u.alive = false
            end
        end
        -- 鎵撴々鑰佽檸姝讳骸鍚庝笉绉婚櫎锛岀暀缁欎笅闈㈢殑澶嶆椿閫昏緫澶勭悊
        if not u.alive and not u.isDummyTiger then table.remove(enemyUnits, i) end
    end

    -- === 鎵撴々妯″紡: 姣忓抚浼ゅ绱 + 鑰佽檸鏃犻檺杞洖 ===
    if gameState.isDummy then
        -- 璁板綍鏈抚閫犳垚鐨勪激瀹?(enemyBaseHP鍦ㄤ笂鏂硅鍑忓皯浜?
        local curHP = gameState.enemyBaseHP
        local expectedHP = 999999
        local frameDmg = expectedHP - curHP
        if frameDmg > 0 then
            dummyState.totalDamage = dummyState.totalDamage + frameDmg
            gameState.enemyBaseHP = expectedHP
        end
        -- 缁熻琚嚮鏉€鑰佽檸鐨勪激瀹冲苟澶嶆椿
        local bz = BATTLE_ZONE
        local tigerUC = UNIT_CLASS.DEMON_WARRIOR
        for i = #enemyUnits, 1, -1 do
            local u = enemyUnits[i]
            if u.isDummyTiger and not u.alive then
                -- 绱鍑绘潃浼ゅ
                dummyState.totalDamage = dummyState.totalDamage + (u.maxHp or 8000)
                -- 鍘熷湴澶嶆椿锛氬湪鍚屼竴杞﹂亾涓棿鍖哄煙闅忔満浣嶇疆閲嶇敓锛堟í灞忥細lane=Y杞达紝X鍦ㄦ晫鏂瑰尯鍩燂級
                local lane = u.laneIdx or math.random(1, NUM_LANES)
                local laneCY = GetLaneCenterY(lane)
                u.y = laneCY + (math.random() - 0.5) * LANE_WIDTH * 0.6
                u.x = bz.centerX + (math.random() - 0.5) * (bz.right - bz.left) * 0.3
                u.hp = u.maxHp
                u.alive = true
                u.flashTimer = 0
                u.animTimer = math.random() * 6.28
            end
        end
        -- 鎵撴々妯″紡涔熶笉璁╃帺瀹跺熀鍦拌鎵撴
        gameState.playerBaseHP = math.max(gameState.playerBaseHP, gameState.playerBaseMax)
        return  -- 鎵撴々妯″紡涓嶈蛋姝ｅ父瓒呮椂/鑳滆礋鍒ゅ畾
    end

    -- 瓒呮椂鍒ゅ畾 (3鍒嗛挓鏃堕檺锛屾寜鍓╀綑HP姣斾緥鍐冲畾鑳滆礋)
    if gameState.battleTime >= BATTLE_TIME_LIMIT then
        local pRatio = gameState.playerBaseHP / math.max(1, gameState.playerBaseMax)
        local eRatio = gameState.enemyBaseHP / math.max(1, gameState.enemyBaseMax)
        if pRatio > eRatio then
            -- 鐜╁HP姣斾緥鏇撮珮 >> 鑳滃埄
            gameState.enemyBaseHP = 0
            gameState.phase = "WIN"
            gameState.resultTimer = 0
            gameState.winJade = math.random(GameConfig.JADE_PER_WIN_MIN, GameConfig.JADE_PER_WIN_MAX)
            gameState.winExp = GameConfig.EXP_PER_WIN
            playerInfo.jade = playerInfo.jade + gameState.winJade
            playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_WIN
            CheckPlayerLevelUp()
            local reward = GrantRandomEquipment(stageMaxTier or 2)
            gameState.winEquip = reward
            gameState.winFragDrops = GenerateBattleSkillFragDrop(stageMaxTier or 2)
            OnBattleVictory()
            AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "鏃堕棿鍒?澶ф嵎!", 3.0, { 255, 230, 80 }, 48)
            PlaySFX(AUDIO.sfx_win)
        elseif eRatio > pRatio then
            -- 鏁屾柟HP姣斾緥鏇撮珮 >> 澶辫触
            gameState.playerBaseHP = 0
            gameState.phase = "LOSE"
            gameState.resultTimer = 0
            playerInfo.jade = playerInfo.jade + GameConfig.JADE_PER_LOSE
            playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_LOSE
            CheckPlayerLevelUp()
            OnBattleEnd()
            AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "鏃堕棿鍒?璐ュ寳...", 3.0, { 255, 80, 80 }, 48)
            PlaySFX(AUDIO.sfx_lose)
        else
            -- 瀹屽叏骞冲眬 >> 鍒ゅ畾涓哄け璐?
            gameState.playerBaseHP = 0
            gameState.phase = "LOSE"
            gameState.resultTimer = 0
            playerInfo.jade = playerInfo.jade + GameConfig.JADE_PER_LOSE
            playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_LOSE
            CheckPlayerLevelUp()
            OnBattleEnd()
            AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "鏃堕棿鍒?骞冲眬", 3.0, { 200, 180, 120 }, 48)
            PlaySFX(AUDIO.sfx_lose)
        end
        return
    end

    -- 鑳滆礋鍒ゅ畾
    if gameState.enemyBaseHP <= 0 then
        gameState.enemyBaseHP = 0
        gameState.phase = "WIN"
        gameState.resultTimer = 0
        -- 淇濆瓨濂栧姳淇℃伅鐢ㄤ簬缁撶畻鐣岄潰灞曠ず
        gameState.winJade = math.random(GameConfig.JADE_PER_WIN_MIN, GameConfig.JADE_PER_WIN_MAX)
        gameState.winExp = GameConfig.EXP_PER_WIN
        playerInfo.jade = playerInfo.jade + gameState.winJade
        playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_WIN
        CheckPlayerLevelUp()
        -- 鎴樻枟鑳滃埄濂栧姳闅忔満鍏电敳
        local reward = GrantRandomEquipment(stageMaxTier or 2)
        gameState.winEquip = reward  -- 淇濆瓨瑁呭鎺夎惤鐢ㄤ簬灞曠ず
        gameState.winFragDrops = GenerateBattleSkillFragDrop(stageMaxTier or 2)
        OnBattleVictory()
        AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "澶ф嵎!", 3.0, { 255, 230, 80 }, 48)
        PlaySFX(AUDIO.sfx_win)
        return
    elseif gameState.playerBaseHP <= 0 then
        gameState.playerBaseHP = 0
        gameState.phase = "LOSE"
        gameState.resultTimer = 0
        playerInfo.jade = playerInfo.jade + GameConfig.JADE_PER_LOSE
        playerInfo.exp = playerInfo.exp + GameConfig.EXP_PER_LOSE
        CheckPlayerLevelUp()
        OnBattleEnd()
        AddFloatText(DESIGN_W / 2, BATTLE_ZONE.centerY, "璐ュ寳...", 3.0, { 255, 80, 80 }, 48)
        PlaySFX(AUDIO.sfx_lose)
        return
    end
end
