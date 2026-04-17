-- ============================================================================
-- Client.lua - 鎺掍綅瀵规垬瀹㈡埛绔綉缁滃眰
-- 浠呭湪鎺掍綅鍖归厤鎴愬姛鍚庯紙ServerReady 浜嬩欢锛夋墠鍒濆鍖栬繛鎺?
-- 鎴块棿鐢熷懡鍛ㄦ湡锛歋erverReady 鈫?Start 鈫?鎴樻枟 鈫?缁撶畻 鈫?Disconnect
-- ============================================================================

---@diagnostic disable: undefined-global

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Client = {}
local Shared = require("network.Shared")
local Protocol = require("network.Protocol")

local EVENTS = Protocol.EVENTS

-- ============================================================================
-- 鐘舵€?
-- ============================================================================

-- 缃戠粶鐘舵€侊紙鍏ㄥ眬锛屼緵鍏朵粬妯″潡璁块棶锛?
netState = netState or {
    connected = false,         -- 鏄惁宸茶繛鎺ユ埧闂存湇鍔＄
    userId = 0,                -- 鑷繁鐨?userId
    serverReady = false,       -- 鏄惁鏀跺埌 Welcome
    elo = 1000,
    wins = 0,
    losses = 0,
    lastError = nil,           -- 鏈€杩戠殑閿欒娑堟伅
}

---@type Scene
local scene_ = nil
local serverConnection_ = nil
local eventsSubscribed_ = false

local function ensureServerConnection()
    if serverConnection_ then
        return true
    end
    return Client.Start()
end

-- ============================================================================
-- 鍏ュ彛锛堟帓浣嶅尮閰嶆垚鍔熷悗璋冪敤锛?
-- ============================================================================

function Client.Start()
    if serverConnection_ then
        netState.connected = true
        return true
    end

    Shared.RegisterEvents()

    -- 鍒涘缓绌哄満鏅紙缃戠粶蹇呴渶锛?
    if not scene_ then
        scene_ = Scene()
        scene_:CreateComponent("Octree", LOCAL)
    end

    -- 鑾峰彇鏈嶅姟绔繛鎺?
    serverConnection_ = network:GetServerConnection()
    if not serverConnection_ then
        print("[Client] ERROR: No server connection")
        return false
    end

    -- 璁剧疆鍦烘櫙
    serverConnection_.scene = scene_

    -- 璁㈤槄鏈嶅姟绔簨浠?
    if not eventsSubscribed_ then
        SubscribeToEvent(EVENTS.WELCOME, "HandleWelcome")
        SubscribeToEvent(EVENTS.ERROR, "HandleServerError")
        SubscribeToEvent(EVENTS.RANKED_MATCHED, "HandleRankedMatched")
        SubscribeToEvent(EVENTS.RANKED_START, "HandleRankedStart")
        SubscribeToEvent(EVENTS.RANKED_UPDATE, "HandleRankedUpdate")
        SubscribeToEvent(EVENTS.RANKED_END, "HandleRankedEnd")
        eventsSubscribed_ = true
    end

    -- 鍙戦€佸氨缁?
    if not netState.connected then
        serverConnection_:SendRemoteEvent(EVENTS.CLIENT_READY, true)
    end
    netState.connected = true
    print("[Client] 宸茶繛鎺ユ帓浣嶆埧闂存湇鍔＄锛屽彂閫?ClientReady")
    return true
end

function Client.Stop()
    netState.connected = false
    netState.serverReady = false
    serverConnection_ = nil
    scene_ = nil
    print("[Client] 鏂紑鎺掍綅鎴块棿杩炴帴")
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

    -- 閫氱煡娓告垙绯荤粺鎴块棿灏辩华
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
-- 鎺掍綅浜嬩欢澶勭悊
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
    -- 鍙栨秷鍖归厤鍝嶅簲
    local cancelledVar = eventData["Cancelled"]
    if cancelledVar and cancelledVar:GetBool() then
        print("[Client] RankedEnd: cancelled")
        return
    end

    -- 鎴樻枟缁撶畻缁撴灉锛堟湇鍔＄鏉冨▉锛?
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

    -- 閫氱煡娓告垙绯荤粺鏈嶅姟绔‘璁ょ殑鎺掍綅缁撴灉
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
-- 鍙戦€佽姹傜殑鍏叡鎺ュ彛锛堜粎鎺掍綅鐩稿叧锛?
-- ============================================================================

--- 璇锋眰鍔犲叆鎺掍綅
function Client.JoinRanked()
    if not ensureServerConnection() then
        print("[Client] JoinRanked aborted: no server connection")
        return false
    end
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_JOIN, true)
    print("[Client] Sent RankedJoin")
    return true
end

--- 鍙栨秷鎺掍綅鍖归厤
function Client.CancelRanked()
    if not ensureServerConnection() then
        print("[Client] CancelRanked aborted: no server connection")
        return false
    end
    serverConnection_:SendRemoteEvent(EVENTS.RANKED_CANCEL, true)
    print("[Client] Sent RankedCancel")
    return true
end

--- 鍙戦€佹帓浣嶆搷浣滐紙鎴樻枟缁撴灉绛夛級
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

--- 鎻愪氦鎺掍綅鎴樻枟缁撴灉鍒版湇鍔＄
function Client.ReportRankedBattleResult(isWin, score, delta, streak)
    return Client.SendRankedAction({
        subAction = "battle_result",
        isWin = isWin,
        score = score,
        delta = delta,
        streak = streak,
    })
end

--- 鎺掍綅鎶曢檷/閫€鍑?
function Client.ForfeitRanked()
    return Client.SendRankedAction({
        subAction = "forfeit",
    })
end

--- 妫€鏌ユ槸鍚﹀凡杩炴帴骞跺氨缁?
function Client.IsReady()
    return netState.connected and netState.serverReady
end

return Client
