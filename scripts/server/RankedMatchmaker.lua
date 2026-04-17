-- ============================================================================
-- RankedMatchmaker.lua - server-side ranked queue, pairing and settlement
-- ============================================================================

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Protocol = require("network.Protocol")
local DataManager = require("server.DataManager")

local RankedMatchmaker = {}

local waitingQueue_ = {}
local waitingEntries_ = {}
local activeSession_ = {}
local nextMatchId_ = 1

local function removeFromQueue(userId)
    waitingEntries_[userId] = nil
    for idx = #waitingQueue_, 1, -1 do
        if waitingQueue_[idx] == userId then
            table.remove(waitingQueue_, idx)
        end
    end
end

local function clampNumber(value, minValue, maxValue)
    value = tonumber(value) or 0
    if minValue ~= nil and value < minValue then value = minValue end
    if maxValue ~= nil and value > maxValue then value = maxValue end
    return value
end

local function sanitizeCard(card)
    if type(card) ~= "table" then
        return nil
    end

    local atk = clampNumber(card.atk, 1, 999999)
    local def = clampNumber(card.def, 0, 999999)
    local hp = clampNumber(card.hp, 1, 99999999)
    local cardIdx = clampNumber(card.cardIdx, 1, 99999)

    return {
        cardIdx = cardIdx,
        name = tostring(card.name or ("Hero" .. tostring(cardIdx))),
        atk = atk,
        def = def,
        hp = hp,
        quality = clampNumber(card.quality, 1, 9),
        faction = tostring(card.faction or ""),
        level = 1,
        constellation = 0,
    }
end

local function sanitizeSnapshot(snapshot, fallbackUserId)
    if type(snapshot) ~= "table" then
        return nil
    end

    local result = {
        name = tostring(snapshot.name or ("Player" .. tostring(fallbackUserId or 0))),
        totalPower = 0,
        cards = {},
    }

    for _, card in ipairs(snapshot.cards or {}) do
        local sanitized = sanitizeCard(card)
        if sanitized then
            result.cards[#result.cards + 1] = sanitized
            result.totalPower = result.totalPower + math.floor((sanitized.atk * 2) + sanitized.def + sanitized.hp * 0.1)
            if #result.cards >= 5 then
                break
            end
        end
    end

    if #result.cards == 0 then
        return nil
    end

    local declaredPower = clampNumber(snapshot.totalPower, 0, 999999999)
    if declaredPower > result.totalPower then
        result.totalPower = declaredPower
    end

    return result
end

local function decodePayload(payloadStr)
    if not payloadStr or payloadStr == "" then
        return nil
    end
    local ok, decoded = pcall(cjson.decode, payloadStr)
    if ok and type(decoded) == "table" then
        return decoded
    end
    return nil
end

local function encodePayload(payload)
    local ok, encoded = pcall(cjson.encode, payload or {})
    if ok then
        return encoded
    end
    return ""
end

local function sendRankedMatched(connection, pd, payload)
    local data = VariantMap()
    data["Success"] = Variant(true)
    data["MatchType"] = Variant("player")
    data["Elo"] = Variant(pd and pd.elo or 1000)
    data["Payload"] = Variant(encodePayload(payload))
    connection:SendRemoteEvent(Protocol.EVENTS.RANKED_MATCHED, true, data)
end

local function sendRankedUpdate(connection, payload)
    local data = VariantMap()
    data["Payload"] = Variant(encodePayload(payload))
    connection:SendRemoteEvent(Protocol.EVENTS.RANKED_UPDATE, true, data)
end

local function sendRankedResult(connection, result)
    local data = VariantMap()
    data["Action"] = Variant("ranked_result")
    data["Success"] = Variant(true)
    data["IsWin"] = Variant(result.isWin == true)
    data["ServerDelta"] = Variant(clampNumber(result.serverDelta))
    data["NewElo"] = Variant(clampNumber(result.newElo))
    data["Wins"] = Variant(clampNumber(result.wins))
    data["Losses"] = Variant(clampNumber(result.losses))
    data["Payload"] = Variant(encodePayload(result.payload))
    connection:SendRemoteEvent(Protocol.EVENTS.RANKED_END, true, data)
end

local function makeSummary(params, forfeit)
    local summary = {}
    summary.forfeit = forfeit == true or params.forfeit == true
    summary.playerBaseHp = clampNumber(params.playerBaseHp, 0, 999999999)
    summary.enemyBaseHp = clampNumber(params.enemyBaseHp, 0, 999999999)
    summary.battleTime = clampNumber(params.battleTime, 0, 86400)
    summary.totalKills = clampNumber(params.totalKills, 0, 999999)
    summary.isWin = params.isWin == true
    if summary.forfeit then
        summary.isWin = false
    end
    return summary
end

local function compareSummary(left, right, leftUserId, rightUserId)
    if left.forfeit ~= right.forfeit then
        return right.forfeit
    end
    if left.isWin ~= right.isWin then
        return left.isWin
    end
    if left.enemyBaseHp ~= right.enemyBaseHp then
        return left.enemyBaseHp < right.enemyBaseHp
    end
    if left.playerBaseHp ~= right.playerBaseHp then
        return left.playerBaseHp > right.playerBaseHp
    end
    if left.battleTime ~= right.battleTime then
        return left.battleTime < right.battleTime
    end
    if left.totalKills ~= right.totalKills then
        return left.totalKills > right.totalKills
    end
    return tonumber(leftUserId) < tonumber(rightUserId)
end

local function calcScoreChange(isWin)
    if isWin then
        return 20
    end
    return -15
end

local function clearSessionPair(userId, opponentId)
    activeSession_[userId] = nil
    activeSession_[opponentId] = nil
end

local function commitResultPair(winnerId, loserId, callback)
    local winnerPd = DataManager.GetPlayerData(winnerId)
    local loserPd = DataManager.GetPlayerData(loserId)
    if not winnerPd or not loserPd then
        if callback then callback(false, "player data missing") end
        return
    end

    local winnerDelta = calcScoreChange(true)
    local loserDelta = calcScoreChange(false)
    local winnerNewElo = math.max(0, (winnerPd.elo or 1000) + winnerDelta)
    local loserNewElo = math.max(0, (loserPd.elo or 1000) + loserDelta)

    if not serverCloud then
        winnerPd.elo = winnerNewElo
        loserPd.elo = loserNewElo
        winnerPd.wins = (winnerPd.wins or 0) + 1
        loserPd.losses = (loserPd.losses or 0) + 1
        if callback then
            callback(true, {
                [winnerId] = {
                    isWin = true,
                    serverDelta = winnerDelta,
                    newElo = winnerNewElo,
                    wins = winnerPd.wins,
                    losses = winnerPd.losses,
                },
                [loserId] = {
                    isWin = false,
                    serverDelta = loserDelta,
                    newElo = loserNewElo,
                    wins = loserPd.wins,
                    losses = loserPd.losses,
                },
            })
        end
        return
    end

    local CK = Protocol.CLOUD_KEYS
    local commit = serverCloud:BatchCommit("ranked_match_result")
    commit:ScoreSetInt(winnerId, CK.RANKED_ELO, winnerNewElo)
    commit:ScoreAddInt(winnerId, CK.RANKED_WINS, 1)
    commit:ScoreSetInt(loserId, CK.RANKED_ELO, loserNewElo)
    commit:ScoreAddInt(loserId, CK.RANKED_LOSSES, 1)
    commit:Commit({
        ok = function()
            winnerPd.elo = winnerNewElo
            loserPd.elo = loserNewElo
            winnerPd.wins = (winnerPd.wins or 0) + 1
            loserPd.losses = (loserPd.losses or 0) + 1
            if callback then
                callback(true, {
                    [winnerId] = {
                        isWin = true,
                        serverDelta = winnerDelta,
                        newElo = winnerNewElo,
                        wins = winnerPd.wins,
                        losses = winnerPd.losses,
                    },
                    [loserId] = {
                        isWin = false,
                        serverDelta = loserDelta,
                        newElo = loserNewElo,
                        wins = loserPd.wins,
                        losses = loserPd.losses,
                    },
                })
            end
        end,
        error = function(code, reason)
            if callback then callback(false, reason or code) end
        end,
    })
end

local function resolvePair(userId)
    local session = activeSession_[userId]
    if not session or session.resolved then
        return
    end

    local opponent = activeSession_[session.opponentId]
    if not opponent then
        return
    end

    if session.result == nil and opponent.result == nil then
        return
    end

    if session.result == nil then
        session.result = makeSummary({ isWin = false }, true)
    end
    if opponent.result == nil then
        opponent.result = makeSummary({ isWin = false }, true)
    end

    session.resolved = true
    opponent.resolved = true

    local sessionWins = compareSummary(session.result, opponent.result, session.userId, opponent.userId)
    local winner = sessionWins and session or opponent
    local loser = sessionWins and opponent or session

    commitResultPair(winner.userId, loser.userId, function(success, resultsOrErr)
        if not success then
            if winner.connection then
                RankedMatchmaker.SendError(winner.connection, "结算失败: " .. tostring(resultsOrErr))
            end
            if loser.connection then
                RankedMatchmaker.SendError(loser.connection, "结算失败: " .. tostring(resultsOrErr))
            end
            session.resolved = false
            opponent.resolved = false
            return
        end

        local winnerResult = resultsOrErr[winner.userId]
        local loserResult = resultsOrErr[loser.userId]
        winnerResult.payload = {
            opponentUserId = loser.userId,
            opponentName = loser.snapshot and loser.snapshot.name or "",
            matchType = "player",
        }
        loserResult.payload = {
            opponentUserId = winner.userId,
            opponentName = winner.snapshot and winner.snapshot.name or "",
            matchType = "player",
        }

        if winner.connection then
            sendRankedResult(winner.connection, winnerResult)
        end
        if loser.connection then
            sendRankedResult(loser.connection, loserResult)
        end

        print("[RankedMatchmaker] match=" .. tostring(session.matchId)
            .. " winner=" .. tostring(winner.userId)
            .. " loser=" .. tostring(loser.userId))

        clearSessionPair(session.userId, opponent.userId)
    end)
end

local function pairPlayers(leftEntry, rightEntry)
    local leftPd = DataManager.GetPlayerData(leftEntry.userId)
    local rightPd = DataManager.GetPlayerData(rightEntry.userId)
    if not leftPd or not rightPd or not leftPd.loaded or not rightPd.loaded then
        return false
    end

    local matchId = nextMatchId_
    nextMatchId_ = nextMatchId_ + 1

    activeSession_[leftEntry.userId] = {
        matchId = matchId,
        userId = leftEntry.userId,
        connection = leftEntry.connection,
        snapshot = leftEntry.snapshot,
        opponentId = rightEntry.userId,
        startTime = os.time(),
        result = nil,
        resolved = false,
    }
    activeSession_[rightEntry.userId] = {
        matchId = matchId,
        userId = rightEntry.userId,
        connection = rightEntry.connection,
        snapshot = rightEntry.snapshot,
        opponentId = leftEntry.userId,
        startTime = os.time(),
        result = nil,
        resolved = false,
    }

    removeFromQueue(leftEntry.userId)
    removeFromQueue(rightEntry.userId)

    sendRankedMatched(leftEntry.connection, leftPd, {
        matchId = matchId,
        opponent = rightEntry.snapshot,
    })
    sendRankedMatched(rightEntry.connection, rightPd, {
        matchId = matchId,
        opponent = leftEntry.snapshot,
    })

    print("[RankedMatchmaker] paired " .. tostring(leftEntry.userId)
        .. " vs " .. tostring(rightEntry.userId)
        .. " match=" .. tostring(matchId))
    return true
end

function RankedMatchmaker.HandleJoin(userId, connection, params)
    local pd = DataManager.GetPlayerData(userId)
    if not pd or not pd.loaded then
        RankedMatchmaker.SendError(connection, "数据尚未加载完成")
        return
    end

    if activeSession_[userId] or waitingEntries_[userId] then
        RankedMatchmaker.SendError(connection, "你已在排位队列中")
        return
    end

    local snapshot = sanitizeSnapshot(params and params.snapshot, userId)
    if not snapshot then
        RankedMatchmaker.SendError(connection, "排位阵容无效，请重新进入排位")
        return
    end

    local entry = {
        userId = userId,
        connection = connection,
        snapshot = snapshot,
        joinedAt = os.time(),
    }

    for _, queuedUserId in ipairs(waitingQueue_) do
        if queuedUserId ~= userId then
            local queuedEntry = waitingEntries_[queuedUserId]
            if queuedEntry and pairPlayers(queuedEntry, entry) then
                return
            end
        end
    end

    waitingEntries_[userId] = entry
    waitingQueue_[#waitingQueue_ + 1] = userId
    sendRankedUpdate(connection, {
        status = "queued",
        queuedAt = entry.joinedAt,
    })
    print("[RankedMatchmaker] queued userId=" .. tostring(userId))
end

function RankedMatchmaker.HandleCancel(userId, connection)
    if waitingEntries_[userId] then
        removeFromQueue(userId)
        local data = VariantMap()
        data["Cancelled"] = Variant(true)
        connection:SendRemoteEvent(Protocol.EVENTS.RANKED_END, true, data)
        print("[RankedMatchmaker] cancelled queue userId=" .. tostring(userId))
        return
    end

    local session = activeSession_[userId]
    if session and not session.resolved then
        RankedMatchmaker.HandleForfeit(userId, connection)
    end
end

function RankedMatchmaker.HandleAction(userId, connection, params)
    local subAction = params.subAction
    if subAction == "battle_result" then
        RankedMatchmaker.HandleBattleResult(userId, connection, params)
    elseif subAction == "forfeit" then
        RankedMatchmaker.HandleForfeit(userId, connection)
    else
        print("[RankedMatchmaker] unknown subAction: " .. tostring(subAction))
    end
end

function RankedMatchmaker.HandleBattleResult(userId, connection, params)
    local session = activeSession_[userId]
    if not session then
        RankedMatchmaker.SendError(connection, "当前没有可结算的排位对局")
        return
    end
    if session.resolved or session.result ~= nil then
        RankedMatchmaker.SendError(connection, "本局结果已经提交")
        return
    end

    local elapsed = os.time() - session.startTime
    if elapsed < 5 then
        print("[RankedMatchmaker] warning: battle finished quickly userId=" .. tostring(userId) .. " elapsed=" .. tostring(elapsed))
    end

    session.result = makeSummary(params, false)
    sendRankedUpdate(connection, {
        status = "awaiting_opponent_result",
        matchId = session.matchId,
    })
    resolvePair(userId)
end

function RankedMatchmaker.HandleForfeit(userId, connection)
    if waitingEntries_[userId] then
        removeFromQueue(userId)
        local data = VariantMap()
        data["Cancelled"] = Variant(true)
        connection:SendRemoteEvent(Protocol.EVENTS.RANKED_END, true, data)
        return
    end

    local session = activeSession_[userId]
    if not session or session.resolved then
        return
    end

    session.result = makeSummary({ isWin = false }, true)
    resolvePair(userId)
end

function RankedMatchmaker.RemovePlayer(userId)
    if waitingEntries_[userId] then
        removeFromQueue(userId)
        return
    end

    local session = activeSession_[userId]
    if not session or session.resolved then
        activeSession_[userId] = nil
        return
    end

    session.connection = nil
    session.result = makeSummary({ isWin = false }, true)
    resolvePair(userId)
end

function RankedMatchmaker.SendError(connection, message)
    local data = VariantMap()
    data["Message"] = Variant("[排位] " .. tostring(message))
    connection:SendRemoteEvent(Protocol.EVENTS.ERROR, true, data)
end

return RankedMatchmaker
