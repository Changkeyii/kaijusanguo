-- ============================================================================
-- systems/rank.lua - 三国武灵录
-- ============================================================================


--- 上报一次有效广告观看到云排行榜
--- 本地先行更新贡献榜数据（保证看完广告后立即有数据可看）
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
    local myName = playerInfo.name or "我"
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


---- 上报战力到云排行榜（使用 SetInt 设置绝对值）
function ReportPowerScore()
    local power = CalcPlayerTotalPower()
    if power <= 0 then return end

    -- 统计技能数和武灵数，附带上报
    local skillCount = 0
    for i, sk in pairs(SKILL_DEFS) do
        if sk.unlocked then skillCount = skillCount + 1 end
    end
    local heroCount = #GetAllOwnedHeroes()

    if rawget(_G, "clientCloud") then
        clientCloud:SetInt(PROJECT_PREFIX .. "combat_power", power, {
            ok = function()
                print("[战力] 上报成功: " .. tostring(power))
                -- 附带上报技能数和武灵数
                clientCloud:SetInt(PROJECT_PREFIX .. "skill_count", skillCount, {})
                clientCloud:SetInt(PROJECT_PREFIX .. "hero_count", heroCount, {})
                -- 上报成功后刷新战力排行榜
                welfareState.powerLoaded = false
                welfareState.powerLoading = false
                LoadPowerRank()
            end,
            error = function(err)
                print("[战力] 上报失败: " .. tostring(err))
            end,
        })
    else
        print("[战力] clientCloud 不可用，仅本地模拟")
        -- 开发模式下本地模拟
        if not welfareState.powerRank then
            welfareState.powerRank = {}
        end
        local myName = playerInfo.name or "我"
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


---- 加载战力排行榜数据
function LoadPowerRank()
    if not rawget(_G, "clientCloud") then return end
    if welfareState.powerLoading then return end
    welfareState.powerLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "combat_power", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
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
-- 境界排行榜 (上报 & 加载)
-- ============================================================================
function ReportRealmScore()
    local idx = playerInfo.rankIdx or 1
    if idx <= 0 then return end

    if rawget(_G, "clientCloud") then
        clientCloud:SetInt(PROJECT_PREFIX .. "realm_level", idx, {
            ok = function()
                print("[境界] 上报成功: " .. tostring(idx) .. " (" .. GetRankDisplayName(idx) .. ")")
                welfareState.realmLoaded = false
                welfareState.realmLoading = false
                LoadRealmRank()
            end,
            error = function(err)
                print("[境界] 上报失败: " .. tostring(err))
            end,
        })
    end
end


function LoadRealmRank()
    if not rawget(_G, "clientCloud") then return end
    if welfareState.realmLoading then return end
    welfareState.realmLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "realm_level", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
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
-- 桩逼王排行榜 (打桩伤害排行 - 上报 & 加载)
-- ============================================================================
function ReportDummyScore(damage)
    if damage <= 0 then return end
    local intDmg = math.floor(damage)
    if rawget(_G, "clientCloud") then
        clientCloud:SetInt(PROJECT_PREFIX .. "dummy_damage", intDmg, {
            ok = function()
                print("[桩逼王] 上报成功: " .. tostring(intDmg))
                welfareState.dummyLoaded = false
                welfareState.dummyLoading = false
            end,
            error = function(err)
                print("[桩逼王] 上报失败: " .. tostring(err))
            end,
        })
    end
end


function LoadDummyRank()
    if not rawget(_G, "clientCloud") then return end
    if welfareState.dummyLoading then return end
    welfareState.dummyLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "dummy_damage", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
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


--- 加载阵营排行榜到主排行榜Tab（写入 welfareState）
function LoadFactionLevelRankForTab()
    if welfareState.factionRankLoading then return end
    welfareState.factionRankLoading = true
    LoadFactionRankFrom("welfareState")
end


-- ============================================================================
-- 排位赛 - 云端排行榜
-- ============================================================================
-- ============================================================================
-- 爬塔 - 云端排行榜
-- ============================================================================
function ReportTowerFloor()
    local floor = towerState.highestFloor
    if rawget(_G, "clientCloud") then
        clientCloud:SetInt(PROJECT_PREFIX .. "tower_floor", floor, {
            ok = function()
                print("[爬塔] 上报成功: " .. tostring(floor))
                towerState.rankLoaded = false
                towerState.rankLoading = false
            end,
            error = function(err)
                print("[爬塔] 上报失败: " .. tostring(err))
            end,
        })
    end
end


function LoadTowerLeaderboard()
    if not rawget(_G, "clientCloud") then
        towerState.rankLoaded = true
        towerState.rankLoading = false
        return
    end
    if towerState.rankLoading then return end
    towerState.rankLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "tower_floor", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
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
        print("[鎺掍綅] Skipping clientCloud ranked upload in server-authoritative mode")
        return
    end
    if rawget(_G, "clientCloud") then
        clientCloud:SetInt(PROJECT_PREFIX .. "ranked_score", score, {
            ok = function()
                print("[排位] 上报成功: " .. tostring(score))
                rankedState.rankLoaded = false
                rankedState.rankLoading = false
            end,
            error = function(err)
                print("[排位] 上报失败: " .. tostring(err))
            end,
        })
    end
end


--- 服务端权威 Elo 结算回调
--- 当服务端返回排位结果时，用权威数据覆盖本地 rankedState
---@param result table {isWin, serverDelta, newElo, wins, losses}
function OnRankedResult(result)
    if not result then return end
    local awaitingResult = gameState and gameState.awaitingRankedResult == true
    print("[排位] 服务端权威结算: Elo=" .. tostring(result.newElo)
        .. " delta=" .. tostring(result.serverDelta)
        .. " wins=" .. tostring(result.wins)
        .. " losses=" .. tostring(result.losses))
    -- 用服务端权威值覆盖本地
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
    -- 更新展示用的 delta（覆盖本地计算值）
    if result.serverDelta then
        gameState.rankedDelta = result.serverDelta
    end
    if gameState then
        gameState.awaitingRankedResult = false
    end
    -- 刷新排行榜
    rankedState.rankLoaded = false
    rankedState.rankLoading = false
    SaveGameProgress()
end


function LoadRankedLeaderboard()
    if IsServerAuthoritativeRankedMode and IsServerAuthoritativeRankedMode() then
        local myUid = 0
        if rawget(_G, "netState") and netState.userId then
            myUid = netState.userId
        elseif rawget(_G, "clientCloud") then
            myUid = clientCloud.userId or 0
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
    if not rawget(_G, "clientCloud") then
        rankedState.rankLoaded = true
        rankedState.rankLoading = false
        return
    end
    if rankedState.rankLoading then return end
    rankedState.rankLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "ranked_score", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
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
