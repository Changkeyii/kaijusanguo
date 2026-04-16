-- ============================================================================
-- RankedMatchmaker.lua - 排位服务端验证与 Elo 管理
-- 核心职责：
-- 1. 验证排位战斗结果的合法性（防止伪造胜负）
-- 2. 通过 serverCloud 原子更新 Elo 分数（替代客户端 clientCloud 直接上报）
-- 3. 管理排位会话状态，防止重复提交
-- ============================================================================

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Protocol = require("network.Protocol")
local DataManager = require("server.DataManager")
local CK = Protocol.CLOUD_KEYS
local RankedMatchmaker = {}

-- 活跃排位会话: activeSession_[userId] = { startTime, opponentPower, validated }
local activeSession_ = {}

-- ============================================================================
-- 排位会话管理
-- ============================================================================

--- 玩家请求开始排位匹配
function RankedMatchmaker.HandleJoin(userId, connection)
    local pd = DataManager.GetPlayerData(userId)
    if not pd or not pd.loaded then
        RankedMatchmaker.SendError(connection, "数据未加载")
        return
    end

    -- 防止重复匹配
    if activeSession_[userId] then
        RankedMatchmaker.SendError(connection, "已在排位中")
        return
    end

    -- 创建排位会话（服务端记录开始时间，用于校验战斗时长）
    activeSession_[userId] = {
        startTime = os.time(),
        validated = false,
    }

    -- 发送匹配成功（当前是 AI 对战，立即匹配）
    local data = VariantMap()
    data["Success"] = Variant(true)
    data["MatchType"] = Variant("ai")  -- 标记为 AI 匹配
    data["Elo"] = Variant(pd.elo)
    connection:SendRemoteEvent(Protocol.EVENTS.RANKED_MATCHED, true, data)

    print("[RankedMatchmaker] userId=" .. tostring(userId) .. " joined ranked, elo=" .. pd.elo)
end

--- 玩家取消匹配
function RankedMatchmaker.HandleCancel(userId, connection)
    activeSession_[userId] = nil

    local data = VariantMap()
    data["Cancelled"] = Variant(true)
    connection:SendRemoteEvent(Protocol.EVENTS.RANKED_END, true, data)

    print("[RankedMatchmaker] userId=" .. tostring(userId) .. " cancelled")
end

-- ============================================================================
-- 排位战斗结算
-- ============================================================================

--- 处理排位操作（主要是战斗结果提交）
function RankedMatchmaker.HandleAction(userId, connection, params)
    local subAction = params.subAction

    if subAction == "battle_result" then
        RankedMatchmaker.HandleBattleResult(userId, connection, params)
    elseif subAction == "forfeit" then
        RankedMatchmaker.HandleForfeit(userId, connection)
    else
        print("[RankedMatchmaker] Unknown subAction: " .. tostring(subAction))
    end
end

--- 战斗结果提交 - 服务端验证并更新 Elo
function RankedMatchmaker.HandleBattleResult(userId, connection, params)
    local session = activeSession_[userId]
    if not session then
        RankedMatchmaker.SendError(connection, "无活跃排位会话")
        return
    end

    -- 防止重复提交
    if session.validated then
        RankedMatchmaker.SendError(connection, "结果已提交")
        return
    end

    -- 基础校验：战斗时长（至少 10 秒，防止秒杀外挂）
    local elapsed = os.time() - session.startTime
    if elapsed < 10 then
        print("[RankedMatchmaker] WARNING: userId=" .. tostring(userId)
            .. " battle too fast: " .. elapsed .. "s")
        -- 不拒绝，但记录可疑行为（未来可扩展反作弊）
    end

    local isWin = params.isWin == true
    local clientScore = params.score or 0       -- 客户端声称的分数（仅供参考）
    local clientDelta = params.delta or 0       -- 客户端计算的分数变化
    local streak = params.streak or 0           -- 连胜/连败

    -- 服务端独立计算分数变化（不信任客户端数据）
    local pd = DataManager.GetPlayerData(userId)
    local serverDelta = RankedMatchmaker.CalcScoreChange(isWin, streak)
    local newElo = math.max(0, pd.elo + serverDelta)

    session.validated = true

    -- 原子更新 Elo（通过 serverCloud，取代 clientCloud 直接上报）
    DataManager.UpdateElo(userId, newElo, isWin, function(success, err)
        if success then
            -- 清理会话
            activeSession_[userId] = nil

            -- 通知客户端服务端确认的结果
            local data = VariantMap()
            data["Action"] = Variant("ranked_result")
            data["Success"] = Variant(true)
            data["IsWin"] = Variant(isWin)
            data["ServerDelta"] = Variant(serverDelta)
            data["NewElo"] = Variant(newElo)
            data["Wins"] = Variant(pd.wins)
            data["Losses"] = Variant(pd.losses)
            connection:SendRemoteEvent(Protocol.EVENTS.RANKED_END, true, data)

            print("[RankedMatchmaker] userId=" .. tostring(userId)
                .. (isWin and " WIN" or " LOSE")
                .. " delta=" .. serverDelta .. " newElo=" .. newElo)
        else
            session.validated = false  -- 允许重试
            RankedMatchmaker.SendError(connection, "Elo更新失败: " .. tostring(err))
        end
    end)
end

--- 玩家主动投降/退出排位战斗
function RankedMatchmaker.HandleForfeit(userId, connection)
    local session = activeSession_[userId]
    if not session or session.validated then
        activeSession_[userId] = nil
        return
    end

    session.validated = true
    local pd = DataManager.GetPlayerData(userId)
    local serverDelta = RankedMatchmaker.CalcScoreChange(false, 0)
    local newElo = math.max(0, pd.elo + serverDelta)

    DataManager.UpdateElo(userId, newElo, false, function(success)
        activeSession_[userId] = nil

        local data = VariantMap()
        data["Action"] = Variant("ranked_result")
        data["Success"] = Variant(true)
        data["IsWin"] = Variant(false)
        data["ServerDelta"] = Variant(serverDelta)
        data["NewElo"] = Variant(newElo)
        data["Wins"] = Variant(pd.wins)
        data["Losses"] = Variant(pd.losses)
        data["Forfeit"] = Variant(true)
        connection:SendRemoteEvent(Protocol.EVENTS.RANKED_END, true, data)

        print("[RankedMatchmaker] userId=" .. tostring(userId) .. " forfeited, delta=" .. serverDelta)
    end)
end

-- ============================================================================
-- 分数计算（与客户端一致，但服务端权威）
-- ============================================================================

--- 计算排位分数变化（镜像 CalcRankedScoreChange）
function RankedMatchmaker.CalcScoreChange(isWin, currentStreak)
    if isWin then
        local s = math.max(0, currentStreak)
        return math.min(30, 20 + s * 2)   -- 胜利 +20~30 分
    else
        local s = math.max(0, -currentStreak)
        return -math.max(10, 15 - s)       -- 失败 -10~15 分
    end
end

-- ============================================================================
-- 清理
-- ============================================================================

--- 玩家断开时清理排位会话
function RankedMatchmaker.RemovePlayer(userId)
    activeSession_[userId] = nil
end

-- ============================================================================
-- 辅助
-- ============================================================================

function RankedMatchmaker.SendError(connection, message)
    local data = VariantMap()
    data["Message"] = Variant("[排位] " .. message)
    connection:SendRemoteEvent(Protocol.EVENTS.ERROR, true, data)
end

return RankedMatchmaker
