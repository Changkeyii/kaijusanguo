-- ============================================================================
-- Client.lua - 常驻服务器客户端网络层
-- 启动时直接连接常驻服务器，由服务端统一处理云存档、排行和排位匹配
-- ============================================================================
-- ============================================================================

---@diagnostic disable: undefined-global

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Client = {}
local Shared = require("network.Shared")
local Protocol = require("network.Protocol")

local EVENTS = Protocol.EVENTS

-- ============================================================================
-- 状态"
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
local eventsSubscribed_ = false
local nextCloudRequestId_ = 1
local pendingCloudRequests_ = {}
local delayedCloudQueue_ = {}

local function decodeCloudPayload(payloadStr)
    if not payloadStr or payloadStr == "" then
        return nil
    end
    local ok, decoded = pcall(cjson.decode, payloadStr)
    if ok and type(decoded) == "table" then
        return decoded
    end
    return nil
end

local function ensureServerConnection()
    if serverConnection_ then
        return true
    end
    return Client.Start()
end

local function flushDelayedCloudQueue()
    if not (netState.connected and netState.serverReady and serverConnection_) then
        return
    end
    if #delayedCloudQueue_ == 0 then
        return
    end
    for _, queued in ipairs(delayedCloudQueue_) do
        local data = VariantMap()
        data["RequestId"] = Variant(queued.requestId)
        data["Action"] = Variant(queued.action)
        data["Params"] = Variant(cjson.encode(queued.params or {}))
        serverConnection_:SendRemoteEvent(EVENTS.CLOUD_REQUEST, true, data)
    end
    delayedCloudQueue_ = {}
end

-- ============================================================================
-- 入口（排位匹配成功后调用）
-- ============================================================================

function Client.Start()
    if serverConnection_ then
        netState.connected = true
        return true
    end

    Shared.RegisterEvents()

    -- 创建空场景（网络必需）
    if not scene_ then
        scene_ = Scene()
        scene_:CreateComponent("Octree", LOCAL)
    end

    -- 获取服务端连接
    serverConnection_ = network:GetServerConnection()
    if not serverConnection_ then
        print("[Client] ERROR: No server connection")
        return false
    end

    -- 设置场景
    serverConnection_.scene = scene_

    -- 订阅服务端事件
    if not eventsSubscribed_ then
        SubscribeToEvent(EVENTS.WELCOME, "HandleWelcome")
        SubscribeToEvent(EVENTS.ERROR, "HandleServerError")
        SubscribeToEvent(EVENTS.CLOUD_RESPONSE, "HandleCloudResponse")
        SubscribeToEvent(EVENTS.RANKED_MATCHED, "HandleRankedMatched")
        SubscribeToEvent(EVENTS.RANKED_START, "HandleRankedStart")
        SubscribeToEvent(EVENTS.RANKED_UPDATE, "HandleRankedUpdate")
        SubscribeToEvent(EVENTS.RANKED_END, "HandleRankedEnd")
        eventsSubscribed_ = true
    end

    -- 发送就绪
    if not netState.connected then
        serverConnection_:SendRemoteEvent(EVENTS.CLIENT_READY, true)
    end
    netState.connected = true
    print("[Client] 已连接常驻服务器，发送 ClientReady")
    return true
end

function Client.Stop()
    netState.connected = false
    netState.serverReady = false
    serverConnection_ = nil
    scene_ = nil
    print("[Client] 断开常驻服务器连接")
end

-- ============================================================================
-- 浜嬩欢澶勭悊
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

    if rawget(_G, "CloudAPI") and CloudAPI._OnServerReady then
        CloudAPI._OnServerReady(netState)
    end

    flushDelayedCloudQueue()
end

function HandleServerError(eventType, eventData)
    local msg = eventData["Message"]:GetString()
    netState.lastError = msg
    print("[Client] Server Error: " .. msg)
end

function HandleCloudResponse(eventType, eventData)
    local requestId = eventData["RequestId"]:GetInt()
    local success = eventData["Success"]:GetBool()
    local payloadStr = eventData["Payload"]:GetString()
    local errMsg = eventData["Error"]:GetString()

    local request = pendingCloudRequests_[requestId]
    pendingCloudRequests_[requestId] = nil
    if not request then
        return
    end

    local payload = decodeCloudPayload(payloadStr)

    if success then
        if request.ok then request.ok(payload or {}) end
    else
        if request.error then request.error(errMsg or "cloud response error") end
    end
end

-- ============================================================================
-- 排位事件处理
-- ============================================================================

function HandleRankedMatched(eventType, eventData)
    local success = eventData["Success"]:GetBool()
    local matchType = eventData["MatchType"]:GetString()
    local elo = eventData["Elo"]:GetInt()
    local payload = decodeCloudPayload(eventData["Payload"] and eventData["Payload"]:GetString())

    netState.elo = elo
    print("[Client] RankedMatched: type=" .. matchType .. " elo=" .. elo)

    if rawget(_G, "OnRankedMatched") then
        OnRankedMatched(matchType, elo, payload or {})
    end
end

function HandleRankedStart(eventType, eventData)
    local payload = decodeCloudPayload(eventData["Payload"] and eventData["Payload"]:GetString())
    print("[Client] RankedStart received")
    if rawget(_G, "OnRankedStart") then
        OnRankedStart(payload or {})
    end
end

function HandleRankedUpdate(eventType, eventData)
    local payload = decodeCloudPayload(eventData["Payload"] and eventData["Payload"]:GetString())
    print("[Client] RankedUpdate received")
    if rawget(_G, "OnRankedUpdate") then
        OnRankedUpdate(payload or {})
    end
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
    if not ensureServerConnection() then
        print("[Client] JoinRanked aborted: no server connection")
        return false
    end
    local data = VariantMap()
    local snapshot = rawget(_G, "BuildRankedPlayerSnapshot") and BuildRankedPlayerSnapshot() or nil
    data["Params"] = Variant(cjson.encode({
        snapshot = snapshot,
    }))
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_JOIN, true, data)
    print("[Client] Sent RankedJoin")
    return true
end

--- 取消排位匹配
function Client.CancelRanked()
    if not ensureServerConnection() then
        print("[Client] CancelRanked aborted: no server connection")
        return false
    end
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_CANCEL, true)
    print("[Client] Sent RankedCancel")
    return true
end

--- 发送排位操作（战斗结果等）
function Client.SendRankedAction(params)
    if not ensureServerConnection() then
        print("[Client] RankedAction aborted: no server connection")
        return false
    end
    local data = VariantMap()
    data["Params"] = Variant(cjson.encode(params))
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_ACTION, true, data)
    print("[Client] Sent RankedAction: " .. tostring(params.subAction))
    return true
end

function Client.CallCloud(action, params, callbacks)
    callbacks = callbacks or {}

    if not ensureServerConnection() then
        if callbacks.error then
            callbacks.error("no server connection")
        end
        return false
    end

    local requestId = nextCloudRequestId_
    nextCloudRequestId_ = nextCloudRequestId_ + 1
    pendingCloudRequests_[requestId] = callbacks

    if netState.connected and netState.serverReady then
        local data = VariantMap()
        data["RequestId"] = Variant(requestId)
        data["Action"] = Variant(action)
        data["Params"] = Variant(cjson.encode(params or {}))
        serverConnection_:SendRemoteEvent(EVENTS.CLOUD_REQUEST, true, data)
    else
        delayedCloudQueue_[#delayedCloudQueue_ + 1] = {
            requestId = requestId,
            action = action,
            params = params or {},
        }
    end

    return true
end

--- 提交排位战斗结果到服务端
function Client.ReportRankedBattleResult(isWin, score, delta, streak)
    return Client.SendRankedAction({
        subAction = "battle_result",
        isWin = isWin,
        score = score,
        delta = delta,
        streak = streak,
        playerBaseHp = gameState and gameState.playerBaseHP or 0,
        enemyBaseHp = gameState and gameState.enemyBaseHP or 0,
        battleTime = gameState and gameState.battleTime or 0,
        totalKills = gameState and gameState.totalKills or 0,
    })
end

--- 排位投降/退出
function Client.ForfeitRanked()
    return Client.SendRankedAction({
        subAction = "forfeit",
    })
end

--- 检查是否已连接并就绪
function Client.IsReady()
    return netState.connected and netState.serverReady
end

-- 暴露到全局，供 cloud_api 等模块访问（避免 require 循环依赖）
_G._ClientNet = Client

-- ============================================================================
-- 全局入口：引擎以 Client.lua 为入口时，需要全局 Start()
-- 延迟 require "main" 到 Start() 内部，确保 Client 模块已完成加载，
-- 避免 Client → main → cloud_api → Client 的循环依赖
-- ============================================================================
function Start()
    require "main"   -- main.lua 会重新定义全局 Start() 为游戏初始化逻辑
    Start()          -- 调用 main.lua 定义的新 Start()（非递归，全局已被覆盖）
end

return Client
