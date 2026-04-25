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

    if CloudAPI.IsAvailable() and CloudAPI.IsReady() then
        CloudAPI:SetInt(PROJECT_PREFIX .. "combat_power", power, {
            ok = function()
                print("[战力] 上报成功: " .. tostring(power))
                -- 附带上报技能数和武灵数
                CloudAPI:SetInt(PROJECT_PREFIX .. "skill_count", skillCount, {})
                CloudAPI:SetInt(PROJECT_PREFIX .. "hero_count", heroCount, {})
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
            table.insert(welfareState.powerRank, 1, { name = myName, power = power, userId = CloudAPI.GetUserId() })
        end
        table.sort(welfareState.powerRank, function(a, b) return a.power > b.power end)
        welfareState.powerLoaded = true
    end
end


---- 加载战力排行榜数据
function LoadPowerRank()
    if not CloudAPI.IsAvailable() then return end
    if not CloudAPI.IsReady() then return end  -- 连接未就绪时跳过，等 auto-retry
    if welfareState.powerLoading then return end
    welfareState.powerLoading = true
    CloudAPI:GetRankList(PROJECT_PREFIX .. "combat_power", 0, 100, {
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
                        local name = nameMap[uid] or ("玩家 " .. tostring(uid))
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
                            name = "玩家 " .. tostring(uid), power = power, userId = uid,
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
        error = function(err)
            print("[排行榜] 战力加载失败: " .. tostring(err))
            welfareState.powerLoading = false
            -- 不设 powerLoaded=true，允许 auto-retry 重试
        end,
    })
end


-- ============================================================================
-- 境界排行榜 (上报 & 加载)
-- ============================================================================
function ReportRealmScore()
    local idx = playerInfo.rankIdx or 1
    if idx <= 0 then return end

    if CloudAPI.IsAvailable() and CloudAPI.IsReady() then
        CloudAPI:SetInt(PROJECT_PREFIX .. "realm_level", idx, {
            ok = function()
                print("[境界] 上报成功: " .. tostring(idx) .. " (" .. GetRankDisplayName(idx) .. ")")
                welfareState.realmLoaded = false
                welfareState.realmLoading = false
                LoadRealmRank()
            end,
            error = function(err)
                print("[战力] 上报失败: " .. tostring(err))
            end,
        })
    end
end


function LoadRealmRank()
    if not CloudAPI.IsAvailable() then return end
    if not CloudAPI.IsReady() then return end  -- 连接未就绪时跳过，等 auto-retry
    if welfareState.realmLoading then return end
    welfareState.realmLoading = true
    CloudAPI:GetRankList(PROJECT_PREFIX .. "realm_level", 0, 100, {
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
                        local name = nameMap[uid] or ("玩家 " .. tostring(uid))
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
                            name = "玩家 " .. tostring(uid), rankIdx = rIdx, userId = uid,
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
        error = function(err)
            print("[排行榜] 境界加载失败: " .. tostring(err))
            welfareState.realmLoading = false
            -- 不设 realmLoaded=true，允许 auto-retry 重试
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
-- 爬塔/排位排行榜已移除（功能不存在）
-- 保留空函数避免调用方报错
-- ============================================================================
function ReportTowerFloor() end
function LoadTowerLeaderboard() end
function ReportRankedScore() end


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


function LoadRankedLeaderboard() end


