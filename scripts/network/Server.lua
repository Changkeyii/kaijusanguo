-- ============================================================================
-- Server.lua - 服务端权威架构主入口
-- 职责：连接管理、GAME_REQUEST 分发、STATE_SYNC 推送、排位对战
-- ============================================================================

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Server = {}

-- ============================================================================
-- Headless 模式兼容（必须在 require Sample 之前，否则 Sample 访问 graphics 崩溃）
-- ============================================================================
if GetGraphics() == nil then
    local mockGraphics = {
        SetWindowIcon = function() end,
        SetWindowTitleAndIcon = function() end,
        GetWidth = function() return 1920 end,
        GetHeight = function() return 1080 end,
        GetDPR = function() return 1.0 end,
    }
    function GetGraphics() return mockGraphics end
    graphics = mockGraphics
    console = { background = {} }
    function GetConsole() return console end
    debugHud = {}
    function GetDebugHud() return debugHud end
end

local Shared = require("network.Shared")
local Protocol = require("network.Protocol")
local PlayerDataManager = require("server.PlayerDataManager")
local GameActions = require("server.GameActions")
local RankedMatchmaker = require("server.RankedMatchmaker")

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 变量
-- ============================================================================
local EVENTS = Protocol.EVENTS
local CODE = Protocol.CODE

-- 连接管理
local serverConnections_ = {}  -- connKey -> connection
local connectionUserIds_ = {}  -- connKey -> userId
local userIdToConnKey_ = {}    -- userId -> connKey（反向映射）

-- 场景（网络必需，即使无3D渲染）
---@type Scene
local scene_ = nil

-- ============================================================================
-- 注册所有 action handler（按需 require）
-- ============================================================================
local function registerActions()
    -- 阶段 2: 存档操作
    local ok1, err1 = pcall(function()
        require("server.actions.SaveActions")
    end)
    if not ok1 then print("[Server] SaveActions load: " .. tostring(err1)) end

    -- 阶段 3: 货币/装备/英雄
    local ok2, err2 = pcall(function() require("server.actions.CurrencyActions") end)
    if not ok2 then print("[Server] CurrencyActions load: " .. tostring(err2)) end
    local ok3, err3 = pcall(function() require("server.actions.EquipActions") end)
    if not ok3 then print("[Server] EquipActions load: " .. tostring(err3)) end
    local ok4, err4 = pcall(function() require("server.actions.HeroActions") end)
    if not ok4 then print("[Server] HeroActions load: " .. tostring(err4)) end

    -- 阶段 4: 战斗/排行榜
    local ok5, err5 = pcall(function() require("server.actions.BattleActions") end)
    if not ok5 then print("[Server] BattleActions load: " .. tostring(err5)) end

    -- 阶段 5: 福利
    local ok6, err6 = pcall(function() require("server.actions.WelfareActions") end)
    if not ok6 then print("[Server] WelfareActions load: " .. tostring(err6)) end

    -- 阶段 6: 社交
    local ok7, err7 = pcall(function() require("server.actions.SocialActions") end)
    if not ok7 then print("[Server] SocialActions load: " .. tostring(err7)) end

    -- 阶段 7: 交易
    local ok8, err8 = pcall(function() require("server.actions.TradeActions") end)
    if not ok8 then print("[Server] TradeActions load: " .. tostring(err8)) end

    -- 阶段 8: 共享数据写入代理 (clientCloud → serverCloud)
    local ok9, err9 = pcall(function() require("server.actions.SharedDataActions") end)
    if not ok9 then print("[Server] SharedDataActions load: " .. tostring(err9)) end

    print("[Server] Registered actions: " .. table.concat(GameActions.ListActions(), ", "))
end

-- ============================================================================
-- 入口
-- ============================================================================

function Server.Start()
    -- SampleStart 在 headless 模式下可能部分失败，pcall 保护
    local ok, err = pcall(SampleStart)
    if not ok then
        print("[Server] SampleStart (headless): " .. tostring(err))
    end
    Shared.RegisterEvents()

    -- 创建空场景（网络同步必需）
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)

    -- 注册所有 action handler
    registerActions()

    -- 订阅连接事件
    SubscribeToEvent("ClientIdentity", "HandleClientIdentity")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")

    -- 订阅自定义远程事件
    SubscribeToEvent(EVENTS.CLIENT_READY, "HandleClientReady")
    SubscribeToEvent(EVENTS.GAME_REQUEST, "HandleGameRequest")

    -- 排位事件
    SubscribeToEvent(EVENTS.RANKED_JOIN, "HandleRankedJoin")
    SubscribeToEvent(EVENTS.RANKED_CANCEL, "HandleRankedCancel")
    SubscribeToEvent(EVENTS.RANKED_READY, "HandleRankedReady")
    SubscribeToEvent(EVENTS.RANKED_ACTION, "HandleRankedAction")

    -- 定时 flush
    SubscribeToEvent("Update", "HandleServerUpdate")

    print("[Server] 服务端权威架构启动")
    print("[Server] serverCloud available: " .. tostring(serverCloud ~= nil))
end

function Server.Stop()
    -- 断开前 flush 所有玩家数据
    for userId in pairs(userIdToConnKey_) do
        PlayerDataManager.Flush(userId)
    end
    print("[Server] 服务端停止，已 flush 所有玩家数据")
end

-- ============================================================================
-- 定时更新
-- ============================================================================

function HandleServerUpdate(eventType, eventData)
    -- 定时 flush 脏数据
    PlayerDataManager.TickFlush()

    -- 处理待发送的 Welcome（数据加载延迟时的队列）
    if pendingWelcomes_ and #pendingWelcomes_ > 0 then
        local remaining = {}
        for _, pw in ipairs(pendingWelcomes_) do
            local cache = PlayerDataManager.GetCache(pw.userId)
            if cache and cache.loaded then
                -- 确认连接仍有效
                if serverConnections_[pw.connKey] then
                    SendWelcome(pw.connection, pw.userId, cache)
                    SendFullStateSync(pw.connection, pw.userId, cache)
                    print("[Server] Deferred welcome sent to userId=" .. tostring(pw.userId))
                end
            else
                remaining[#remaining + 1] = pw
            end
        end
        pendingWelcomes_ = remaining
    end
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

    -- 异地登录踢人：如果已有旧连接则踢掉
    local oldConnKey = userIdToConnKey_[userId]
    if oldConnKey and oldConnKey ~= connKey and serverConnections_[oldConnKey] then
        local kickData = VariantMap()
        kickData["Message"] = Variant("异地登录，当前设备已下线")
        kickData["Kick"] = Variant(true)
        serverConnections_[oldConnKey]:SendRemoteEvent(EVENTS.ERROR, true, kickData)
        -- 清理旧连接
        serverConnections_[oldConnKey] = nil
        connectionUserIds_[oldConnKey] = nil
        print("[Server] Kicked old connection for userId=" .. tostring(userId))
    end

    serverConnections_[connKey] = connection
    connectionUserIds_[connKey] = userId
    userIdToConnKey_[userId] = connKey

    print("[Server] ClientIdentity userId=" .. tostring(userId))

    -- 预加载玩家数据
    PlayerDataManager.LoadPlayer(userId, function(success, cache)
        print("[Server] Player data loaded: userId=" .. tostring(userId)
            .. " success=" .. tostring(success)
            .. " migrated=" .. tostring(cache and cache.migrated))
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

    -- 等待数据加载完成后发送 Welcome + STATE_SYNC
    local cache = PlayerDataManager.GetCache(userId)
    if cache and cache.loaded then
        SendWelcome(connection, userId, cache)
        SendFullStateSync(connection, userId, cache)
    else
        -- 数据未就绪，加入待发送队列（在 HandleServerUpdate 中轮询）
        -- 注意：不能用 SubscribeToEvent("Update") 否则会覆盖 HandleServerUpdate
        pendingWelcomes_ = pendingWelcomes_ or {}
        pendingWelcomes_[#pendingWelcomes_ + 1] = {
            connKey = connKey,
            userId = userId,
            connection = connection,
        }
        print("[Server] Player data not ready, queued welcome for userId=" .. tostring(userId))
    end
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
        GameActions.RemovePlayer(userId)
        PlayerDataManager.RemovePlayer(userId)
        print("[Server] Client disconnected userId=" .. tostring(userId))
    end
end

-- ============================================================================
-- Welcome + STATE_SYNC
-- ============================================================================

function SendWelcome(connection, userId, cache)
    local data = VariantMap()
    data["UserId"] = Variant(userId)
    data["Elo"] = Variant(cache.elo or 1000)
    data["Wins"] = Variant(cache.wins or 0)
    data["Losses"] = Variant(cache.losses or 0)
    data["Migrated"] = Variant(cache.migrated or false)

    connection:SendRemoteEvent(EVENTS.WELCOME, true, data)
    print("[Server] Sent Welcome to userId=" .. tostring(userId))
end

--- 发送完整状态同步（登录时）
function SendFullStateSync(connection, userId, cache)
    -- 构建同步数据：必需域 + 货币
    local syncData = {
        domains = {},
        money = cache.money,
        version = cache.version,
        migrated = cache.migrated,
    }

    -- 只同步已加载的域（懒加载域在客户端按需请求）
    for _, domain in ipairs(Protocol.EAGER_DOMAINS) do
        syncData.domains[domain] = cache.domains[domain] or {}
    end

    local data = VariantMap()
    data["Type"] = Variant("full_state")
    data["Data"] = Variant(cjson.encode(syncData))

    connection:SendRemoteEvent(EVENTS.STATE_SYNC, true, data)
    print("[Server] Sent full STATE_SYNC to userId=" .. tostring(userId))
end

--- 发送增量状态同步（Field 级）
function Server.SendDomainSync(userId, domain, domainData)
    local connKey = userIdToConnKey_[userId]
    if not connKey or not serverConnections_[connKey] then return end

    local syncData = {
        domains = { [domain] = domainData },
    }

    local data = VariantMap()
    data["Type"] = Variant("domain_update")
    data["Data"] = Variant(cjson.encode(syncData))

    serverConnections_[connKey]:SendRemoteEvent(EVENTS.STATE_SYNC, true, data)
end

--- 发送货币同步
function Server.SendMoneySync(userId, money)
    local connKey = userIdToConnKey_[userId]
    if not connKey or not serverConnections_[connKey] then return end

    local syncData = { money = money }
    local data = VariantMap()
    data["Type"] = Variant("money_update")
    data["Data"] = Variant(cjson.encode(syncData))

    serverConnections_[connKey]:SendRemoteEvent(EVENTS.STATE_SYNC, true, data)
end

-- ============================================================================
-- GAME_REQUEST 处理（核心分发）
-- ============================================================================

function HandleGameRequest(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]

    if not userId then
        print("[Server] WARNING: GameRequest but no userId")
        return
    end

    -- 解析请求
    local action = eventData["Action"]:GetString()
    local seq = eventData["Seq"]:GetInt()
    local paramsStr = eventData["Params"]:GetString()

    local params = {}
    if paramsStr and paramsStr ~= "" then
        local ok, decoded = pcall(cjson.decode, paramsStr)
        if ok then params = decoded end
    end

    -- 构建回复函数
    local function replyFn(code, respData, msg)
        local reply = VariantMap()
        reply["Action"] = Variant(action)
        reply["Seq"] = Variant(seq)
        reply["Ok"] = Variant(code == CODE.OK)
        reply["Code"] = Variant(code)
        reply["Data"] = Variant(cjson.encode(respData or {}))
        reply["Msg"] = Variant(msg or Protocol.CODE_MSG[code] or "")

        if serverConnections_[connKey] then
            serverConnections_[connKey]:SendRemoteEvent(EVENTS.GAME_RESPONSE, true, reply)
        end
    end

    -- 分发到 GameActions
    GameActions.Dispatch(userId, action, seq, params, replyFn)
end

-- ============================================================================
-- 排位对战（保留原有逻辑）
-- ============================================================================

function HandleRankedJoin(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = tostring(connection)
    local userId = connectionUserIds_[connKey]
    if not userId then return end
    RankedMatchmaker.HandleJoin(userId, connection)
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

--- 获取在线用户列表（调试用）
function Server.GetOnlineUsers()
    local users = {}
    for _, userId in pairs(connectionUserIds_) do
        users[#users + 1] = userId
    end
    return users
end

-- ============================================================================
-- 全局入口（引擎启动时自动调用）
-- entry_server 指向本文件，引擎会调用全局 Start() / Stop()
-- ============================================================================

function Start()
    Server.Start()
end

function Stop()
    Server.Stop()
end

return Server
