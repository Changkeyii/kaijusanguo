-- ============================================================================
-- Client.lua - 排位对战客户端网络层
-- 仅在排位匹配成功后（ServerReady 事件）才初始化连接
-- 房间生命周期：ServerReady → Start → 战斗 → 结算 → Disconnect
-- ============================================================================

---@diagnostic disable: undefined-global

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Client = {}
local Shared = require("network.Shared")
local Protocol = require("network.Protocol")

local EVENTS = Protocol.EVENTS

-- ============================================================================
-- 状态
-- ============================================================================

-- 网络状态（全局，供其他模块访问）
netState = netState or {
    connected = false,         -- 是否已连接房间服务端
    userId = 0,                -- 自己的 userId
    serverReady = false,       -- 是否收到 Welcome
    elo = 1000,
    wins = 0,
    losses = 0,
    lastError = nil,           -- 最近的错误消息
}

---@type Scene
local scene_ = nil
local serverConnection_ = nil

-- ============================================================================
-- 入口（排位匹配成功后调用）
-- ============================================================================

function Client.Start()
    Shared.RegisterEvents()

    -- 创建空场景（网络必需）
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)

    -- 获取服务端连接
    serverConnection_ = network:GetServerConnection()
    if not serverConnection_ then
        print("[Client] ERROR: No server connection")
        return
    end

    -- 设置场景
    serverConnection_.scene = scene_

    -- 订阅服务端事件
    SubscribeToEvent(EVENTS.WELCOME, "HandleWelcome")
    SubscribeToEvent(EVENTS.ERROR, "HandleServerError")
    SubscribeToEvent(EVENTS.RANKED_MATCHED, "HandleRankedMatched")
    SubscribeToEvent(EVENTS.RANKED_START, "HandleRankedStart")
    SubscribeToEvent(EVENTS.RANKED_UPDATE, "HandleRankedUpdate")
    SubscribeToEvent(EVENTS.RANKED_END, "HandleRankedEnd")

    -- 发送就绪
    serverConnection_:SendRemoteEvent(EVENTS.CLIENT_READY, true)
    netState.connected = true
    print("[Client] 已连接排位房间服务端，发送 ClientReady")
end

function Client.Stop()
    netState.connected = false
    netState.serverReady = false
    serverConnection_ = nil
    scene_ = nil
    print("[Client] 断开排位房间连接")
end

-- ============================================================================
-- 事件处理
-- ============================================================================

function HandleWelcome(eventType, eventData)
    netState.userId = eventData["UserId"]:GetInt()
    netState.elo = eventData["Elo"]:GetInt()
    netState.wins = eventData["Wins"]:GetInt()
    netState.losses = eventData["Losses"]:GetInt()
    netState.serverReady = true

    print("[Client] Welcome: userId=" .. tostring(netState.userId)
        .. " elo=" .. netState.elo)

    -- 通知游戏系统房间就绪
    if rawget(_G, "OnServerReady") then
        OnServerReady(netState)
    end
end

function HandleServerError(eventType, eventData)
    local msg = eventData["Message"]:GetString()
    netState.lastError = msg
    print("[Client] Server Error: " .. msg)
end

-- ============================================================================
-- 排位事件处理
-- ============================================================================

function HandleRankedMatched(eventType, eventData)
    local success = eventData["Success"]:GetBool()
    local matchType = eventData["MatchType"]:GetString()
    local elo = eventData["Elo"]:GetInt()

    netState.elo = elo
    print("[Client] RankedMatched: type=" .. matchType .. " elo=" .. elo)

    if rawget(_G, "OnRankedMatched") then
        OnRankedMatched(matchType, elo)
    end
end

function HandleRankedStart(eventType, eventData)
    print("[Client] RankedStart received")
end

function HandleRankedUpdate(eventType, eventData)
    print("[Client] RankedUpdate received")
end

function HandleRankedEnd(eventType, eventData)
    -- 取消匹配响应
    local cancelledVar = eventData["Cancelled"]
    if cancelledVar and cancelledVar:GetBool() then
        print("[Client] RankedEnd: cancelled")
        return
    end

    -- 战斗结算结果（服务端权威）
    local isWin = eventData["IsWin"]:GetBool()
    local serverDelta = eventData["ServerDelta"]:GetInt()
    local newElo = eventData["NewElo"]:GetInt()
    local wins = eventData["Wins"]:GetInt()
    local losses = eventData["Losses"]:GetInt()

    netState.elo = newElo
    netState.wins = wins
    netState.losses = losses

    print("[Client] RankedEnd: " .. (isWin and "WIN" or "LOSE")
        .. " serverDelta=" .. serverDelta .. " newElo=" .. newElo)

    -- 通知游戏系统服务端确认的排位结果
    if rawget(_G, "OnRankedResult") then
        OnRankedResult({
            isWin = isWin,
            serverDelta = serverDelta,
            newElo = newElo,
            wins = wins,
            losses = losses,
        })
    end
end

-- ============================================================================
-- 发送请求的公共接口（仅排位相关）
-- ============================================================================

--- 请求加入排位
function Client.JoinRanked()
    if not serverConnection_ then return end
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_JOIN, true)
    print("[Client] Sent RankedJoin")
end

--- 取消排位匹配
function Client.CancelRanked()
    if not serverConnection_ then return end
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_CANCEL, true)
    print("[Client] Sent RankedCancel")
end

--- 发送排位操作（战斗结果等）
function Client.SendRankedAction(params)
    if not serverConnection_ then return end
    local data = VariantMap()
    data["Params"] = Variant(cjson.encode(params))
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_ACTION, true, data)
    print("[Client] Sent RankedAction: " .. tostring(params.subAction))
end

--- 提交排位战斗结果到服务端
function Client.ReportRankedBattleResult(isWin, score, delta, streak)
    Client.SendRankedAction({
        subAction = "battle_result",
        isWin = isWin,
        score = score,
        delta = delta,
        streak = streak,
    })
end

--- 排位投降/退出
function Client.ForfeitRanked()
    Client.SendRankedAction({
        subAction = "forfeit",
    })
end

--- 检查是否已连接并就绪
function Client.IsReady()
    return netState.connected and netState.serverReady
end

return Client
