-- ============================================================================
-- systems/rank.lua - 涓夊浗姝︾伒褰?"
-- ============================================================================


--- 涓婃姤涓€娆℃湁鏁堝箍鍛婅鐪嬪埌浜戞帓琛屾
--- 鏈湴鍏堣鏇存柊璐＄尞姒滄暟鎹紙淇濊瘉鐪嬪畬骞垮憡鍚庣珛鍗虫湁鏁版嵁鍙湅锛?"
local function _getRankItemUserId(item)
    if rawget(_G, "ResolveRankListUserId") then
        return ResolveRankListUserId(item)
    end
    return tonumber(item and (item.userId or item.player or item.uid)) or 0
end

function UpdateContribRankLocally()
    if not welfareState.contribRank then
        welfareState.contribRank = {}
    end
    local myName = playerInfo.name or "鎴?"
    local myCount = welfareState.localAdCount or 1
    local found = false
    for _, entry in ipairs(welfareState.contribRank) do
        if entry.name == myName then
            entry.count = myCount
            found = true
            break
        end
    end
    if not found then
        table.insert(welfareState.contribRank, { name = myName, count = myCount })
    end
    table.sort(welfareState.contribRank, function(a, b) return a.count > b.count end)
    welfareState.contribLoaded = true
end


---- 涓婃姤鎴樺姏鍒颁簯鎺掕姒滐紙浣跨敤 SetInt 璁剧疆缁濆鍊硷級
function ReportPowerScore()
    local power = CalcPlayerTotalPower()
    if power <= 0 then return end

    -- 缁熻鎶€鑳芥暟鍜屾鐏垫暟锛岄檮甯︿笂鎶?"
    local skillCount = 0
    for i, sk in pairs(SKILL_DEFS) do
        if sk.unlocked then skillCount = skillCount + 1 end
    end
    local heroCount = #GetAllOwnedHeroes()

    if CloudAPI.IsAvailable() then
        CloudAPI:SetInt(PROJECT_PREFIX .. "combat_power", power, {
            ok = function()
                print("[鎴樺姏] 涓婃姤鎴愬姛: " .. tostring(power))
                -- 闄勫甫涓婃姤鎶€鑳芥暟鍜屾鐏垫暟
                CloudAPI:SetInt(PROJECT_PREFIX .. "skill_count", skillCount, {})
                CloudAPI:SetInt(PROJECT_PREFIX .. "hero_count", heroCount, {})
                -- 涓婃姤鎴愬姛鍚庡埛鏂版垬鍔涙帓琛屾
                welfareState.powerLoaded = false
                welfareState.powerLoading = false
                LoadPowerRank()
            end,
            error = function(err)
                print("[鎴樺姏] 涓婃姤澶辫触: " .. tostring(err))
            end,
        })
    else
        print("[鎴樺姏] CloudAPI 涓嶅彲鐢紝浠呮湰鍦版ā鎷?")
        -- 寮€鍙戞ā寮忎笅鏈湴妯℃嫙
        if not welfareState.powerRank then
            welfareState.powerRank = {}
        end
        local myName = playerInfo.name or "鎴?"
        local found = false
        for _, entry in ipairs(welfareState.powerRank) do
            if entry.name == myName then
                entry.power = power
                found = true
                break
            end
        end
        if not found then
            table.insert(welfareState.powerRank, 1, { name = myName, power = power, userId = 0 })
        end
        table.sort(welfareState.powerRank, function(a, b) return a.power > b.power end)
        welfareState.powerLoaded = true
    end
end


---- 鍔犺浇鎴樺姏鎺掕姒滄暟鎹?"
function LoadPowerRank()
    if not CloudAPI.IsAvailable() then return end
    if welfareState.powerLoading then return end
    welfareState.powerLoading = true
    CloudAPI:GetRankList(PROJECT_PREFIX .. "combat_power", 0, 100, {
        ok = function(rankList)
            -- 杩囨护灏佺鐜╁骞舵埅鍙栧墠50
            local filtered = {}
            for _, item in ipairs(rankList) do
                local uid = _getRankItemUserId(item)
                if uid > 0 and not CloudManager.IsPlayerRankHidden(uid) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, _getRankItemUserId(item))
            end
            if #userIds == 0 then
                welfareState.powerRank = {}
                welfareState.powerLoading = false
                welfareState.powerLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local sc = item.iscore or {}
                        local power = sc[PROJECT_PREFIX .. "combat_power"] or 0
                        local name = nameMap[uid] or ("Player " .. tostring(uid))
                        table.insert(result, {
                            name = name, power = power, userId = uid,
                            skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                            heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                            realmIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1,
                        })
                    end
                    welfareState.powerRank = result
                    welfareState.powerLoading = false
                    welfareState.powerLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local sc = item.iscore or {}
                        local power = sc[PROJECT_PREFIX .. "combat_power"] or 0
                        table.insert(result, {
                            name = "Player " .. tostring(uid), power = power, userId = uid,
                            skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                            heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                            realmIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1,
                        })
                    end
                    welfareState.powerRank = result
                    welfareState.powerLoading = false
                    welfareState.powerLoaded = true
                end,
            })
        end,
        error = function()
            welfareState.powerLoading = false
            welfareState.powerLoaded = true
            welfareState.powerRank = {}
        end,
    })
end


-- ============================================================================
-- 澧冪晫鎺掕姒?(涓婃姤 & 鍔犺浇)
-- ============================================================================
function ReportRealmScore()
    local idx = playerInfo.rankIdx or 1
    if idx <= 0 then return end

    if CloudAPI.IsAvailable() then
        CloudAPI:SetInt(PROJECT_PREFIX .. "realm_level", idx, {
            ok = function()
                print("[澧冪晫] 涓婃姤鎴愬姛: " .. tostring(idx) .. " (" .. GetRankDisplayName(idx) .. ")")
                welfareState.realmLoaded = false
                welfareState.realmLoading = false
                LoadRealmRank()
            end,
            error = function(err)
                print("[澧冪晫] 涓婃姤澶辫触: " .. tostring(err))
            end,
        })
    end
end


function LoadRealmRank()
    if not CloudAPI.IsAvailable() then return end
    if welfareState.realmLoading then return end
    welfareState.realmLoading = true
    CloudAPI:GetRankList(PROJECT_PREFIX .. "realm_level", 0, 100, {
        ok = function(rankList)
            -- 杩囨护灏佺鐜╁骞舵埅鍙栧墠50
            local filtered = {}
            for _, item in ipairs(rankList) do
                local uid = _getRankItemUserId(item)
                if uid > 0 and not CloudManager.IsPlayerRankHidden(uid) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, _getRankItemUserId(item))
            end
            if #userIds == 0 then
                welfareState.realmRank = {}
                welfareState.realmLoading = false
                welfareState.realmLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local sc = item.iscore or {}
                        local rIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1
                        local name = nameMap[uid] or ("Player " .. tostring(uid))
                        table.insert(result, {
                            name = name, rankIdx = rIdx, userId = uid,
                            power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                            skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                            heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                        })
                    end
                    welfareState.realmRank = result
                    welfareState.realmLoading = false
                    welfareState.realmLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local sc = item.iscore or {}
                        local rIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1
                        table.insert(result, {
                            name = "Player " .. tostring(uid), rankIdx = rIdx, userId = uid,
                            power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                            skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                            heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                        })
                    end
                    welfareState.realmRank = result
                    welfareState.realmLoading = false
                    welfareState.realmLoaded = true
                end,
            })
        end,
        error = function()
            welfareState.realmLoading = false
            welfareState.realmLoaded = true
            welfareState.realmRank = {}
        end,
    })
end


-- ============================================================================
-- 妗╅€肩帇鎺掕姒?(鎵撴々浼ゅ鎺掕 - 涓婃姤 & 鍔犺浇)
-- ============================================================================
function ReportDummyScore(damage)
    if damage <= 0 then return end
    local intDmg = math.floor(damage)
    if CloudAPI.IsAvailable() then
        CloudAPI:SetInt(PROJECT_PREFIX .. "dummy_damage", intDmg, {
            ok = function()
                print("[妗╅€肩帇] 涓婃姤鎴愬姛: " .. tostring(intDmg))
                welfareState.dummyLoaded = false
                welfareState.dummyLoading = false
            end,
            error = function(err)
                print("[妗╅€肩帇] 涓婃姤澶辫触: " .. tostring(err))
            end,
        })
    end
end


function LoadDummyRank()
    if not CloudAPI.IsAvailable() then return end
    if welfareState.dummyLoading then return end
    welfareState.dummyLoading = true
    CloudAPI:GetRankList(PROJECT_PREFIX .. "dummy_damage", 0, 100, {
        ok = function(rankList)
            -- 杩囨护灏佺鐜╁骞舵埅鍙栧墠50
            local filtered = {}
            for _, item in ipairs(rankList) do
                local uid = _getRankItemUserId(item)
                if uid > 0 and not CloudManager.IsPlayerRankHidden(uid) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, _getRankItemUserId(item))
            end
            if #userIds == 0 then
                welfareState.dummyRank = {}
                welfareState.dummyLoading = false
                welfareState.dummyLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local sc = item.iscore or {}
                        local dmg = sc[PROJECT_PREFIX .. "dummy_damage"] or 0
                        local name = nameMap[uid] or ("Player " .. tostring(uid))
                        table.insert(result, {
                            name = name, damage = dmg, userId = uid,
                            power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                        })
                    end
                    welfareState.dummyRank = result
                    welfareState.dummyLoading = false
                    welfareState.dummyLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local sc = item.iscore or {}
                        local dmg = sc[PROJECT_PREFIX .. "dummy_damage"] or 0
                        table.insert(result, {
                            name = "Player " .. tostring(uid), damage = dmg, userId = uid,
                            power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                        })
                    end
                    welfareState.dummyRank = result
                    welfareState.dummyLoading = false
                    welfareState.dummyLoaded = true
                end,
            })
        end,
        error = function()
            welfareState.dummyLoading = false
            welfareState.dummyLoaded = true
            welfareState.dummyRank = {}
        end,
    })
end


function LoadFactionLevelRank()
    if factionUI.rankLoading then return end
    factionUI.rankLoading = true
    LoadFactionRankFrom("factionUI")
end


--- 鍔犺浇闃佃惀鎺掕姒滃埌涓绘帓琛屾Tab锛堝啓鍏?welfareState锛?"
function LoadFactionLevelRankForTab()
    if welfareState.factionRankLoading then return end
    welfareState.factionRankLoading = true
    LoadFactionRankFrom("welfareState")
end


-- ============================================================================
-- 鎺掍綅璧?- 浜戠鎺掕姒?"
-- ============================================================================
-- ============================================================================
-- 鐖 - 浜戠鎺掕姒?"
-- ============================================================================
function ReportTowerFloor()
    local floor = towerState.highestFloor
    if CloudAPI.IsAvailable() then
        CloudAPI:SetInt(PROJECT_PREFIX .. "tower_floor", floor, {
            ok = function()
                print("[鐖] 涓婃姤鎴愬姛: " .. tostring(floor))
                towerState.rankLoaded = false
                towerState.rankLoading = false
            end,
            error = function(err)
                print("[鐖] 涓婃姤澶辫触: " .. tostring(err))
            end,
        })
    end
end


function LoadTowerLeaderboard()
    if not CloudAPI.IsAvailable() then
        towerState.rankLoaded = true
        towerState.rankLoading = false
        return
    end
    if towerState.rankLoading then return end
    towerState.rankLoading = true
    CloudAPI:GetRankList(PROJECT_PREFIX .. "tower_floor", 0, 100, {
        ok = function(rankList)
            -- 杩囨护灏佺鐜╁骞舵埅鍙栧墠50
            local filtered = {}
            for _, item in ipairs(rankList) do
                local uid = _getRankItemUserId(item)
                if uid > 0 and not CloudManager.IsPlayerRankHidden(uid) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, _getRankItemUserId(item))
            end
            if #userIds == 0 then
                towerState.rankList = {}
                towerState.rankLoading = false
                towerState.rankLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local fl = item.iscore and item.iscore[PROJECT_PREFIX .. "tower_floor"] or 0
                        local name = nameMap[uid] or ("Player " .. tostring(uid))
                        table.insert(result, { name = name, floor = fl, userId = uid })
                    end
                    towerState.rankList = result
                    towerState.rankLoading = false
                    towerState.rankLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local fl = item.iscore and item.iscore[PROJECT_PREFIX .. "tower_floor"] or 0
                        table.insert(result, { name = "Player " .. tostring(uid), floor = fl, userId = uid })
                    end
                    towerState.rankList = result
                    towerState.rankLoading = false
                    towerState.rankLoaded = true
                end,
            })
        end,
        error = function()
            towerState.rankLoading = false
            towerState.rankLoaded = true
            towerState.rankList = {}
        end,
    })
end


function ReportRankedScore()
    local score = rankedState.score
    if IsServerAuthoritativeRankedMode and IsServerAuthoritativeRankedMode() then
        print("[閹烘帊缍匽 Skipping CloudAPI ranked upload in server-authoritative mode")
        return
    end
    if CloudAPI.IsAvailable() then
        CloudAPI:SetInt(PROJECT_PREFIX .. "ranked_score", score, {
            ok = function()
                print("[鎺掍綅] 涓婃姤鎴愬姛: " .. tostring(score))
                rankedState.rankLoaded = false
                rankedState.rankLoading = false
            end,
            error = function(err)
                print("[鎺掍綅] 涓婃姤澶辫触: " .. tostring(err))
            end,
        })
    end
end


function OnRankedMatched(matchType, elo, payload)
    payload = payload or {}
    local opponent = payload.opponent or {}
    rankedState.score = elo or rankedState.score
    rankedState.opponentName = opponent.name or "Unknown"
    rankedState.opponentPower = opponent.totalPower or 0
    rankedState.opponentCards = opponent.cards or {}
    rankedState.matchReady = true
    print("[排位] matched type=" .. tostring(matchType)
        .. " opponent=" .. tostring(rankedState.opponentName)
        .. " power=" .. tostring(rankedState.opponentPower))
end

function OnRankedUpdate(payload)
    payload = payload or {}
    if payload.status == "awaiting_opponent_result" then
        if gameState then
            gameState.awaitingRankedResult = true
        end
    end
end

--- 鏈嶅姟绔潈濞?Elo 缁撶畻鍥炶皟
--- 褰撴湇鍔＄杩斿洖鎺掍綅缁撴灉鏃讹紝鐢ㄦ潈濞佹暟鎹鐩栨湰鍦?rankedState
---@param result table {isWin, serverDelta, newElo, wins, losses}
function OnRankedResult(result)
    if not result then return end
    local awaitingResult = gameState and gameState.awaitingRankedResult == true
    print("[鎺掍綅] 鏈嶅姟绔潈濞佺粨绠? Elo=" .. tostring(result.newElo)
        .. " delta=" .. tostring(result.serverDelta)
        .. " wins=" .. tostring(result.wins)
        .. " losses=" .. tostring(result.losses))
    -- 鐢ㄦ湇鍔＄鏉冨▉鍊艰鐩栨湰鍦?"
    rankedState.score = result.newElo or rankedState.score
    rankedState.wins = result.wins or rankedState.wins
    rankedState.losses = result.losses or rankedState.losses
    if awaitingResult then
        playerInfo.totalRankedBattles = (playerInfo.totalRankedBattles or 0) + 1
        if result.isWin then
            playerInfo.totalRankedWins = (playerInfo.totalRankedWins or 0) + 1
            if rankedState.streak < 0 then rankedState.streak = 0 end
            rankedState.streak = rankedState.streak + 1
        else
            if rankedState.streak > 0 then rankedState.streak = 0 end
            rankedState.streak = rankedState.streak - 1
        end
    end
    if rankedState.score > rankedState.highestScore then
        rankedState.highestScore = rankedState.score
    end
    -- 鏇存柊灞曠ず鐢ㄧ殑 delta锛堣鐩栨湰鍦拌绠楀€硷級
    if result.serverDelta then
        gameState.rankedDelta = result.serverDelta
    end
    if gameState then
        gameState.awaitingRankedResult = false
    end
    -- 鍒锋柊鎺掕姒?"
    rankedState.rankLoaded = false
    rankedState.rankLoading = false
    SaveGameProgress()
end


function LoadRankedLeaderboard()
    if IsServerAuthoritativeRankedMode and IsServerAuthoritativeRankedMode() then
        local myUid = 0
        if rawget(_G, "netState") and netState.userId then
            myUid = netState.userId
        elseif CloudAPI.IsAvailable() then
            myUid = CloudAPI.GetUserId()
        end
        rankedState.rankList = {
            {
                name = playerInfo.name or "Player",
                score = rankedState.score or 0,
                userId = myUid,
            }
        }
        rankedState.rankLoaded = true
        rankedState.rankLoading = false
        return
    end
    if not CloudAPI.IsAvailable() then
        rankedState.rankLoaded = true
        rankedState.rankLoading = false
        return
    end
    if rankedState.rankLoading then return end
    rankedState.rankLoading = true
    CloudAPI:GetRankList(PROJECT_PREFIX .. "ranked_score", 0, 100, {
        ok = function(rankList)
            -- 杩囨护灏佺鐜╁骞舵埅鍙栧墠50
            local filtered = {}
            for _, item in ipairs(rankList) do
                local uid = _getRankItemUserId(item)
                if uid > 0 and not CloudManager.IsPlayerRankHidden(uid) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, _getRankItemUserId(item))
            end
            if #userIds == 0 then
                rankedState.rankList = {}
                rankedState.rankLoading = false
                rankedState.rankLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local sc = item.iscore and item.iscore[PROJECT_PREFIX .. "ranked_score"] or 0
                        local name = nameMap[uid] or ("Player " .. tostring(uid))
                        table.insert(result, { name = name, score = sc, userId = uid })
                    end
                    rankedState.rankList = result
                    rankedState.rankLoading = false
                    rankedState.rankLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local uid = _getRankItemUserId(item)
                        local sc = item.iscore and item.iscore[PROJECT_PREFIX .. "ranked_score"] or 0
                        table.insert(result, { name = "Player " .. tostring(uid), score = sc, userId = uid })
                    end
                    rankedState.rankList = result
                    rankedState.rankLoading = false
                    rankedState.rankLoaded = true
                end,
            })
        end,
        error = function()
            rankedState.rankLoading = false
            rankedState.rankLoaded = true
            rankedState.rankList = {}
        end,
    })
end


