-- ============================================================================
-- Client.lua - 客户端网络层（服务端权威架构）
-- 职责：连接管理、GameClient 驱动、STATE_SYNC 分发到游戏系统、排位对战
-- ============================================================================

---@diagnostic disable: undefined-global

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Client = {}
local Shared = require("network.Shared")
local Protocol = require("network.Protocol")
local GameClient = require("network.GameClient")

local EVENTS = Protocol.EVENTS
local CODE = Protocol.CODE

-- ============================================================================
-- 状态（全局，供其他模块访问）
-- ============================================================================

netState = netState or {
    connected = false,         -- 是否已连接服务端
    userId = 0,                -- 自己的 userId
    serverReady = false,       -- 是否收到 Welcome 并完成 STATE_SYNC
    migrated = false,          -- 数据是否已迁移到 serverCloud
    elo = 1000,
    wins = 0,
    losses = 0,
    lastError = nil,           -- 最近的错误消息
    kicked = false,            -- 是否被踢下线（异地登录）
}

---@type Scene
local scene_ = nil
local serverConnection_ = nil

-- ============================================================================
-- 入口
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

    -- 初始化 GameClient（RPC 封装层）
    GameClient.Init(serverConnection_)

    -- 注册 STATE_SYNC 回调（核心：将服务端推送分发到游戏系统）
    GameClient.OnStateSync(Client._handleStateSync)

    -- 订阅通用事件
    SubscribeToEvent(EVENTS.WELCOME, "HandleWelcome")
    SubscribeToEvent(EVENTS.ERROR, "HandleServerError")

    -- 订阅排位事件
    SubscribeToEvent(EVENTS.RANKED_MATCHED, "HandleRankedMatched")
    SubscribeToEvent(EVENTS.RANKED_START, "HandleRankedStart")
    SubscribeToEvent(EVENTS.RANKED_UPDATE, "HandleRankedUpdate")
    SubscribeToEvent(EVENTS.RANKED_END, "HandleRankedEnd")

    -- 注意：不再在此处 SubscribeToEvent("Update") —— 会覆盖全局 HandleUpdate
    -- 改由 HandleUpdate 中主动调用 HandleClientUpdate

    -- 发送就绪
    serverConnection_:SendRemoteEvent(EVENTS.CLIENT_READY, true)
    netState.connected = true
    print("[Client] Connected, sent ClientReady")
end

function Client.Stop()
    GameClient.Shutdown()
    netState.connected = false
    netState.serverReady = false
    serverConnection_ = nil
    scene_ = nil
    print("[Client] Disconnected")
end

-- ============================================================================
-- Update 驱动
-- ============================================================================

function HandleClientUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    GameClient.Tick(dt)
end

-- ============================================================================
-- Welcome 处理
-- ============================================================================

function HandleWelcome(eventType, eventData)
    netState.userId = eventData["UserId"]:GetInt()
    netState.elo = eventData["Elo"]:GetInt()
    netState.wins = eventData["Wins"]:GetInt()
    netState.losses = eventData["Losses"]:GetInt()

    local migratedVar = eventData["Migrated"]
    netState.migrated = migratedVar and migratedVar:GetBool() or false

    print("[Client] Welcome: userId=" .. tostring(netState.userId)
        .. " elo=" .. netState.elo
        .. " migrated=" .. tostring(netState.migrated))
end

-- ============================================================================
-- 错误处理
-- ============================================================================

function HandleServerError(eventType, eventData)
    local msg = eventData["Message"]:GetString()
    netState.lastError = msg

    -- 检查是否被踢（异地登录）
    local kickVar = eventData["Kick"]
    if kickVar and kickVar:GetBool() then
        netState.kicked = true
        print("[Client] Kicked: " .. msg)
        if rawget(_G, "OnKicked") then
            OnKicked(msg)
        end
        return
    end

    print("[Client] Server Error: " .. msg)

    -- 通知游戏系统
    if rawget(_G, "OnServerError") then
        OnServerError(msg)
    end
end

-- ============================================================================
-- STATE_SYNC 分发到游戏系统
-- ============================================================================

--- STATE_SYNC 核心回调
---@param syncType string "full_state" | "domain_update" | "money_update"
---@param syncData table 同步数据
function Client._handleStateSync(syncType, syncData)
    if syncType == "full_state" then
        Client._applyFullState(syncData)
    elseif syncType == "domain_update" then
        Client._applyDomainUpdate(syncData)
    elseif syncType == "money_update" then
        Client._applyMoneyUpdate(syncData)
    else
        print("[Client] Unknown STATE_SYNC type: " .. tostring(syncType))
    end
end

--- 应用全量状态（登录时）
function Client._applyFullState(syncData)
    local domains = syncData.domains or {}
    local money = syncData.money or {}

    -- 将 domain 数据写入全局变量（供游戏系统读取）
    -- cl_state 是客户端的服务端权威数据缓存
    cl_state = cl_state or {}
    cl_state.domains = domains
    cl_state.money = money
    cl_state.version = syncData.version
    cl_state.migrated = syncData.migrated

    netState.migrated = syncData.migrated or false
    netState.serverReady = true

    print("[Client] Full state applied. domains="
        .. tostring(Client._countKeys(domains))
        .. " migrated=" .. tostring(syncData.migrated))

    -- 通知游戏系统
    if rawget(_G, "OnFullStateSync") then
        OnFullStateSync(cl_state)
    end

    -- 通知房间就绪（兼容旧接口）
    if rawget(_G, "OnServerReady") then
        OnServerReady(netState)
    end
end

--- 应用增量域更新
function Client._applyDomainUpdate(syncData)
    cl_state = cl_state or { domains = {} }
    local domains = syncData.domains or {}

    for domain, data in pairs(domains) do
        cl_state.domains[domain] = data
        print("[Client] Domain updated: " .. domain)
    end

    -- 通知游戏系统
    if rawget(_G, "OnDomainSync") then
        OnDomainSync(domains)
    end
end

--- 应用货币更新
function Client._applyMoneyUpdate(syncData)
    cl_state = cl_state or {}
    cl_state.money = syncData.money or cl_state.money

    print("[Client] Money updated")

    -- 通知游戏系统
    if rawget(_G, "OnMoneySync") then
        OnMoneySync(cl_state.money)
    end
end

-- ============================================================================
-- 公共 API：发送 RPC 请求（封装 GameClient）
-- ============================================================================

--- 发送游戏请求（核心 API，所有数据修改都走这个通道）
---@param action string 操作名
---@param params? table 请求参数
---@param callback? fun(ok: boolean, code: number, data: table, msg: string)
---@param opts? { opKey?: string }
function Client.Request(action, params, callback, opts)
    GameClient.Request(action, params, callback, opts)
end

--- 请求加载懒加载域
---@param domain string 域名（如 "skills", "welfare"）
---@param callback? fun(ok: boolean, code: number, data: table, msg: string)
function Client.LoadDomain(domain, callback)
    GameClient.Request("load_domain", { domain = domain }, function(ok, code, data, msg)
        if ok and data.domains then
            -- 服务端会通过 STATE_SYNC 推送，这里 data 也可能包含
            cl_state = cl_state or { domains = {} }
            for d, dData in pairs(data.domains) do
                cl_state.domains[d] = dData
            end
        end
        if callback then
            callback(ok, code, data, msg)
        end
    end)
end

--- 保存指定域到服务端
---@param domain string 域名
---@param domainData table 域数据
---@param callback? fun(ok: boolean, code: number, data: table, msg: string)
function Client.SaveDomain(domain, domainData, callback)
    GameClient.Request("save_domain", {
        domain = domain,
        data = domainData,
    }, callback)
end

--- 保存所有域到服务端（全量保存，慎用）
---@param allDomains table<string, table> { core = {...}, heroes = {...}, ... }
---@param callback? fun(ok: boolean, code: number, data: table, msg: string)
function Client.SaveAllDomains(allDomains, callback)
    GameClient.Request("save_all", {
        domains = allDomains,
    }, callback)
end

--- 迁移旧 clientCloud 数据到服务端
---@param allDomains table<string, table> 所有 domain 数据
---@param money table 货币数据 { jade=N, lingshi=N, hufu=N }
---@param callback? fun(ok: boolean, code: number, data: table, msg: string)
function Client.MigrateLegacy(allDomains, money, callback)
    GameClient.Request("migrate_legacy", {
        domains = allDomains,
        money = money,
    }, function(ok, code, data, msg)
        if ok then
            netState.migrated = true
            if cl_state then cl_state.migrated = true end
        end
        if callback then
            callback(ok, code, data, msg)
        end
    end)
end

-- ============================================================================
-- 排位对战（保留原有接口）
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
    local cancelledVar = eventData["Cancelled"]
    if cancelledVar and cancelledVar:GetBool() then
        print("[Client] RankedEnd: cancelled")
        return
    end

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

--- 发送排位操作
function Client.SendRankedAction(params)
    if not serverConnection_ then return end
    local data = VariantMap()
    data["Params"] = Variant(cjson.encode(params))
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_ACTION, true, data)
end

--- 提交排位战斗结果
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
    Client.SendRankedAction({ subAction = "forfeit" })
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 是否已连接并就绪（完成 STATE_SYNC）
function Client.IsReady()
    return netState.connected and netState.serverReady
end

--- 是否需要迁移数据
function Client.NeedsMigration()
    return netState.connected and not netState.migrated
end

--- 获取 GameClient 模块（高级用法）
function Client.GetGameClient()
    return GameClient
end

--- 获取当前网络状态
function Client.GetNetState()
    return netState
end

-- ============================================================================
-- 工具
-- ============================================================================

function Client._countKeys(t)
    local n = 0
    if t then for _ in pairs(t) do n = n + 1 end end
    return n
end

return Client
