-- ============================================================================
-- Server.lua - 常驻服务器服务端
-- 负责统一处理客户端连接、云数据代理与排位匹配结算
-- ============================================================================

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Server = {}
local Shared = require("network.Shared")
local Protocol = require("network.Protocol")
local DataManager = require("server.DataManager")
local RankedMatchmaker = require("server.RankedMatchmaker")
local CloudService = require("server.CloudService")

-- ============================================================================
-- 变量
-- ============================================================================
local EVENTS = Protocol.EVENTS

-- 连接管理
local serverConnections_ = {}  -- connKey -> connection
local connectionUserIds_ = {}  -- connKey -> userId
local userIdToConnKey_ = {}    -- userId -> connKey（反向映射）

-- 场景（网络必需，即使无3D渲染）
---@type Scene
local scene_ = nil

-- ============================================================================
-- 入口
-- ============================================================================

function Server.Start()
    Shared.RegisterEvents()

    -- 创建空场景（网络同步必需）
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)

    -- 订阅连接事件
    SubscribeToEvent("ClientIdentity", "HandleClientIdentity")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")

    -- 订阅自定义远程事件
    SubscribeToEvent(EVENTS.CLIENT_READY, "HandleClientReady")
    SubscribeToEvent(EVENTS.CLOUD_REQUEST, "HandleCloudRequest")

    -- 排位事件
    SubscribeToEvent(EVENTS.RANKED_JOIN, "HandleRankedJoin")
    SubscribeToEvent(EVENTS.RANKED_CANCEL, "HandleRankedCancel")
    SubscribeToEvent(EVENTS.RANKED_READY, "HandleRankedReady")
    SubscribeToEvent(EVENTS.RANKED_ACTION, "HandleRankedAction")

    print("[Server] 常驻服务器启动")
    print("[Server] serverCloud available: " .. tostring(serverCloud ~= nil))
end

function Server.Stop()
    print("[Server] 常驻服务器停止")
end

-- ============================================================================
-- 连接管理
-- ============================================================================

function HandleClientIdentity(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)

    -- 提取 userId
    local userId = 10001  -- dev fallback
    local identityUid = connection.identity["user_id"]
    if identityUid then
        userId = identityUid:GetInt64()
    end

    serverConnections_[connKey] = connection
    connectionUserIds_[connKey] = userId
    userIdToConnKey_[userId] = connKey

    print("[Server] ClientIdentity userId=" .. tostring(userId))

    -- 预加载玩家排位数据
    DataManager.LoadPlayer(userId, function(success, pd)
        print("[Server] Player data loaded: userId=" .. tostring(userId) .. " success=" .. tostring(success))
    end)
end

function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]

    if not userId then
        print("[Server] WARNING: ClientReady but no userId for " .. connKey)
        return
    end

    -- 分配场景
    connection.scene = scene_

    -- 等待数据加载完成后发送 Welcome
    local function trySendWelcome()
        local pd = DataManager.GetPlayerData(userId)
        if pd and pd.loaded then
            SendWelcome(connection, userId, pd)
        else
            SubscribeToEvent("Update", function()
                local pd2 = DataManager.GetPlayerData(userId)
                if pd2 and pd2.loaded then
                    UnsubscribeFromEvent("Update")
                    SendWelcome(connection, userId, pd2)
                end
            end)
        end
    end

    trySendWelcome()
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData:GetPtr("Connection", "Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]

    serverConnections_[connKey] = nil
    connectionUserIds_[connKey] = nil
    if userId then
        userIdToConnKey_[userId] = nil
        RankedMatchmaker.RemovePlayer(userId)
        DataManager.RemovePlayer(userId)
        print("[Server] Client disconnected userId=" .. tostring(userId))
    end
end

-- ============================================================================
-- Welcome 消息（仅排位数据）
-- ============================================================================

function SendWelcome(connection, userId, pd)
    local data = VariantMap()
    data["UserId"] = Variant(userId)
    data["Elo"] = Variant(pd.elo)
    data["Wins"] = Variant(pd.wins)
    data["Losses"] = Variant(pd.losses)

    connection:SendRemoteEvent(EVENTS.WELCOME, true, data)
    print("[Server] Sent Welcome to userId=" .. tostring(userId) .. " elo=" .. pd.elo)
end

function SendError(connection, message)
    local data = VariantMap()
    data["Message"] = Variant(message)
    connection:SendRemoteEvent(EVENTS.ERROR, true, data)
end

-- ============================================================================
-- 排位对战
-- ============================================================================

function HandleRankedJoin(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]
    if not userId then return end

    local params = {}
    local paramsVar = eventData["Params"]
    if paramsVar then
        local paramsStr = paramsVar:GetString()
        if paramsStr and paramsStr ~= "" then
            local ok, decoded = pcall(cjson.decode, paramsStr)
            if ok and type(decoded) == "table" then
                params = decoded
            end
        end
    end

    RankedMatchmaker.HandleJoin(userId, connection, params)
end

function HandleRankedCancel(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]
    if not userId then return end
    RankedMatchmaker.HandleCancel(userId, connection)
end

function HandleRankedReady(eventType, eventData)
    print("[Server] RankedReady received")
end

function HandleRankedAction(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]
    if not userId then return end

    local paramsStr = eventData["Params"]:GetString()
    local params = {}
    if paramsStr and paramsStr ~= "" then
        local ok, decoded = pcall(cjson.decode, paramsStr)
        if ok then params = decoded end
    end

    RankedMatchmaker.HandleAction(userId, connection, params)
end

function HandleCloudRequest(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]
    if not userId then return end

    local requestId = eventData["RequestId"]:GetInt()
    local action = eventData["Action"]:GetString()
    local paramsStr = eventData["Params"]:GetString()

    local params = {}
    if paramsStr and paramsStr ~= "" then
        local ok, decoded = pcall(cjson.decode, paramsStr)
        if ok and type(decoded) == "table" then
            params = decoded
        end
    end

    CloudService.HandleRequest(userId, connection, requestId, action, params)
end

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 向指定 userId 发送事件
function Server.SendToUser(userId, eventName, data)
    local connKey = userIdToConnKey_[userId]
    if connKey and serverConnections_[connKey] then
        serverConnections_[connKey]:SendRemoteEvent(eventName, true, data)
    end
end

--- 广播给所有连接的客户端
function Server.Broadcast(eventName, data)
    for _, conn in pairs(serverConnections_) do
        conn:SendRemoteEvent(eventName, true, data)
    end
end

-- ============================================================================
-- 全局入口：引擎以 Server.lua 为服务端入口时需要全局 Start()
-- ============================================================================
function Start()
    Server.Start()
end

return Server
