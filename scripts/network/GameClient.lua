-- ============================================================================
-- GameClient.lua - 客户端 RPC 封装（服务端权威架构）
-- 职责：发送 GAME_REQUEST、管理 seq、处理 GAME_RESPONSE/STATE_SYNC
-- 特性：自增 seq、Ack 超时重发、离线队列、回调管理
-- ============================================================================

---@diagnostic disable: undefined-global

local cjson = cjson ---@diagnostic disable-line: undefined-global
local Protocol = require("network.Protocol")
local EVENTS = Protocol.EVENTS
local CODE = Protocol.CODE

local GameClient = {}

-- ============================================================================
-- 状态
-- ============================================================================

local seq_ = 0                      -- 自增请求序号
local pendingRequests_ = {}         -- seq → { action, params, callback, sentTime, retries }
local offlineQueue_ = {}            -- 离线时积攒的请求 { action, params, callback, opKey }
local serverConnection_ = nil       -- 服务端连接引用
local connected_ = false            -- 是否已连接
local stateCallbacks_ = {}          -- STATE_SYNC 回调列表
local responseCallbacks_ = {}       -- 按 action 注册的全局回调（非 seq 绑定）

-- 配置
local ACK_TIMEOUT = 8              -- Ack 超时时间（秒）
local MAX_RETRIES = 2              -- 最大重发次数
local CLEANUP_INTERVAL = 5         -- 超时检查间隔（秒）
local lastCleanupTime_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化（Client.Start 中调用）
function GameClient.Init(connection)
    serverConnection_ = connection
    connected_ = true
    seq_ = 0
    pendingRequests_ = {}

    -- 订阅事件
    SubscribeToEvent(EVENTS.GAME_RESPONSE, "HandleGameResponse")
    SubscribeToEvent(EVENTS.STATE_SYNC, "HandleStateSync")

    -- 发送离线队列中的请求
    GameClient._flushOfflineQueue()

    print("[GameClient] Initialized")
end

--- 断开连接
function GameClient.Shutdown()
    connected_ = false
    serverConnection_ = nil
    -- 不清理 pendingRequests_，重连后可能重发
    print("[GameClient] Shutdown")
end

-- ============================================================================
-- 发送请求
-- ============================================================================

--- 发送游戏请求（核心 API）
---@param action string 操作名（如 "save_domain", "equip_enhance"）
---@param params? table 请求参数
---@param callback? fun(ok: boolean, code: number, data: table, msg: string)
---@param opts? { opKey?: string } 可选配置（opKey 用于幂等）
function GameClient.Request(action, params, callback, opts)
    params = params or {}
    opts = opts or {}

    -- 注入幂等 key
    if opts.opKey then
        params.opKey = opts.opKey
    end

    -- 离线时存入队列
    if not connected_ or not serverConnection_ then
        offlineQueue_[#offlineQueue_ + 1] = {
            action = action,
            params = params,
            callback = callback,
        }
        print("[GameClient] Queued offline request: " .. action)
        return
    end

    -- 自增 seq
    seq_ = seq_ + 1
    local currentSeq = seq_

    -- 构建 VariantMap
    local data = VariantMap()
    data["Action"] = Variant(action)
    data["Seq"] = Variant(currentSeq)
    data["Params"] = Variant(cjson.encode(params))

    -- 记录 pending
    pendingRequests_[currentSeq] = {
        action = action,
        params = params,
        callback = callback,
        sentTime = os.time(),
        retries = 0,
    }

    -- 发送
    serverConnection_:SendRemoteEvent(EVENTS.GAME_REQUEST, true, data)
end

-- ============================================================================
-- 事件处理
-- ============================================================================

--- 处理 GAME_RESPONSE
function HandleGameResponse(eventType, eventData)
    local action = eventData["Action"]:GetString()
    local respSeq = eventData["Seq"]:GetInt()
    local ok = eventData["Ok"]:GetBool()
    local code = eventData["Code"]:GetInt()
    local dataStr = eventData["Data"]:GetString()
    local msg = eventData["Msg"]:GetString()

    -- 解析 data
    local respData = {}
    if dataStr and dataStr ~= "" then
        local success, decoded = pcall(cjson.decode, dataStr)
        if success then respData = decoded end
    end

    -- 查找 pending request
    local pending = pendingRequests_[respSeq]
    if pending then
        pendingRequests_[respSeq] = nil
        if pending.callback then
            pending.callback(ok, code, respData, msg)
        end
    end

    -- 触发全局 action 回调
    if responseCallbacks_[action] then
        responseCallbacks_[action](ok, code, respData, msg)
    end
end

--- 处理 STATE_SYNC
function HandleStateSync(eventType, eventData)
    local syncType = eventData["Type"]:GetString()
    local dataStr = eventData["Data"]:GetString()

    local syncData = {}
    if dataStr and dataStr ~= "" then
        local success, decoded = pcall(cjson.decode, dataStr)
        if success then syncData = decoded end
    end

    print("[GameClient] STATE_SYNC type=" .. syncType)

    -- 触发所有注册的回调
    for _, cb in ipairs(stateCallbacks_) do
        local ok, err = pcall(cb, syncType, syncData)
        if not ok then
            print("[GameClient] STATE_SYNC callback error: " .. tostring(err))
        end
    end
end

-- ============================================================================
-- 回调注册
-- ============================================================================

--- 注册 STATE_SYNC 回调
function GameClient.OnStateSync(callback)
    stateCallbacks_[#stateCallbacks_ + 1] = callback
end

--- 注册特定 action 的全局回调（不依赖 seq）
function GameClient.OnAction(action, callback)
    responseCallbacks_[action] = callback
end

-- ============================================================================
-- 超时重发 & 离线队列
-- ============================================================================

--- 在 Update 中调用，处理超时重发
function GameClient.Tick(dt)
    local now = os.time()
    if (now - lastCleanupTime_) < CLEANUP_INTERVAL then return end
    lastCleanupTime_ = now

    if not connected_ then return end

    for seq, req in pairs(pendingRequests_) do
        if (now - req.sentTime) >= ACK_TIMEOUT then
            if req.retries < MAX_RETRIES then
                -- 重发
                req.retries = req.retries + 1
                req.sentTime = now
                local data = VariantMap()
                data["Action"] = Variant(req.action)
                data["Seq"] = Variant(seq)
                data["Params"] = Variant(cjson.encode(req.params))
                serverConnection_:SendRemoteEvent(EVENTS.GAME_REQUEST, true, data)
                print("[GameClient] Retry #" .. req.retries .. " for " .. req.action .. " seq=" .. seq)
            else
                -- 超过重试次数，通知失败
                pendingRequests_[seq] = nil
                if req.callback then
                    req.callback(false, CODE.ERR_SERVER, {}, "request timed out")
                end
                print("[GameClient] Request timed out: " .. req.action .. " seq=" .. seq)
            end
        end
    end
end

--- 发送离线队列
function GameClient._flushOfflineQueue()
    if #offlineQueue_ == 0 then return end

    print("[GameClient] Flushing " .. #offlineQueue_ .. " offline requests")
    local queue = offlineQueue_
    offlineQueue_ = {}

    for _, req in ipairs(queue) do
        GameClient.Request(req.action, req.params, req.callback)
    end
end

-- ============================================================================
-- 工具
-- ============================================================================

--- 是否已连接
function GameClient.IsConnected()
    return connected_
end

--- 获取当前 seq（调试用）
function GameClient.GetSeq()
    return seq_
end

--- 获取 pending 请求数（调试用）
function GameClient.GetPendingCount()
    local count = 0
    for _ in pairs(pendingRequests_) do count = count + 1 end
    return count
end

--- 获取离线队列长度
function GameClient.GetOfflineQueueSize()
    return #offlineQueue_
end

return GameClient
