-- ============================================================================
-- cloud_api.lua - client-side cloud bridge via the multiplayer server
-- ============================================================================

---@diagnostic disable: undefined-global

local ClientNet = require("network.Client")

local CloudAPI = CloudAPI or {
    enabled = false,
    userId = 0,
}

local retrySubscribed_ = false
local retryAccumulator_ = 0
local unpackFn = table.unpack or unpack

local function isNetworkRuntime()
    return rawget(_G, "IsNetworkMode") and IsNetworkMode()
end

local function normalizeSelf(maybeSelf, ...)
    if maybeSelf == CloudAPI then
        return ...
    end
    return maybeSelf, ...
end

local function tryStartClient()
    if not isNetworkRuntime() then
        return false
    end
    CloudAPI.enabled = true
    return ClientNet.Start() == true
end

local function ensureRetryLoop()
    if retrySubscribed_ then
        return
    end
    retrySubscribed_ = true
    SubscribeToEvent("Update", "HandleCloudApiRetry")
end

function HandleCloudApiRetry(eventType, eventData)
    if ClientNet.IsReady() then
        return
    end

    retryAccumulator_ = retryAccumulator_ + eventData["TimeStep"]:GetFloat()
    if retryAccumulator_ < 1.0 then
        return
    end
    retryAccumulator_ = 0
    tryStartClient()
end

function CloudAPI.Init()
    if not isNetworkRuntime() then
        CloudAPI.enabled = false
        return false
    end

    CloudAPI.enabled = true
    if not tryStartClient() then
        ensureRetryLoop()
    end
    return true
end

function CloudAPI.IsAvailable()
    return CloudAPI.enabled
end

function CloudAPI.IsReady()
    return CloudAPI.enabled and ClientNet.IsReady()
end

function CloudAPI.GetUserId()
    return tonumber(CloudAPI.userId) or 0
end

function CloudAPI._OnServerReady(netState)
    CloudAPI.enabled = true
    CloudAPI.userId = netState and netState.userId or 0
end

function CloudAPI.Set(maybeSelf, key, value, callbacks)
    key, value, callbacks = normalizeSelf(maybeSelf, key, value, callbacks)
    return ClientNet.CallCloud("set", {
        key = key,
        value = value,
    }, {
        ok = function()
            if callbacks and callbacks.ok then callbacks.ok() end
        end,
        error = function(reason)
            if callbacks and callbacks.error then callbacks.error(reason) end
        end,
    })
end

function CloudAPI.SetInt(maybeSelf, key, value, callbacks)
    key, value, callbacks = normalizeSelf(maybeSelf, key, value, callbacks)
    return ClientNet.CallCloud("set_int", {
        key = key,
        value = math.floor(tonumber(value) or 0),
    }, {
        ok = function()
            if callbacks and callbacks.ok then callbacks.ok() end
        end,
        error = function(reason)
            if callbacks and callbacks.error then callbacks.error(reason) end
        end,
    })
end

function CloudAPI.Add(maybeSelf, key, delta, callbacks)
    key, delta, callbacks = normalizeSelf(maybeSelf, key, delta, callbacks)
    return ClientNet.CallCloud("add_int", {
        key = key,
        delta = math.floor(tonumber(delta) or 0),
    }, {
        ok = function(payload)
            if callbacks and callbacks.ok then callbacks.ok(payload and payload.value) end
        end,
        error = function(reason)
            if callbacks and callbacks.error then callbacks.error(reason) end
        end,
    })
end

-- 服务端原子交易购买：由服务端验证并扣除虎珀，返回扣除后余额
-- callbacks.ok(jade)  -- 成功，jade 为扣除后余额
-- callbacks.error(reason)
function CloudAPI.TradeBuy(maybeSelf, coreKey, price, callbacks)
    coreKey, price, callbacks = normalizeSelf(maybeSelf, coreKey, price, callbacks)
    return ClientNet.CallCloud("trade_buy", {
        coreKey = tostring(coreKey),
        price   = math.floor(tonumber(price) or 0),
    }, {
        ok = function(payload)
            if callbacks and callbacks.ok then
                callbacks.ok(payload and payload.jade)
            end
        end,
        error = function(reason)
            if callbacks and callbacks.error then callbacks.error(reason) end
        end,
    })
end

function CloudAPI.Get(maybeSelf, key, callbacks)
    key, callbacks = normalizeSelf(maybeSelf, key, callbacks)
    return ClientNet.CallCloud("get", {
        key = key,
    }, {
        ok = function(payload)
            local values = payload and payload.values or {}
            if callbacks and callbacks.ok then callbacks.ok(values) end
        end,
        error = function(reason)
            if callbacks and callbacks.error then callbacks.error(nil, reason) end
        end,
    })
end

function CloudAPI.GetRankList(maybeSelf, key, start, count, callbacks, ...)
    key, start, count, callbacks = normalizeSelf(maybeSelf, key, start, count, callbacks)
    local fields = { ... }
    return ClientNet.CallCloud("get_rank_list", {
        key = key,
        start = tonumber(start) or 0,
        count = tonumber(count) or 20,
        fields = fields,
    }, {
        ok = function(payload)
            if callbacks and callbacks.ok then callbacks.ok((payload and payload.rankList) or {}) end
        end,
        error = function(reason)
            if callbacks and callbacks.error then callbacks.error(reason) end
        end,
    })
end

function CloudAPI.GetRankTotal(maybeSelf, key, callbacks)
    key, callbacks = normalizeSelf(maybeSelf, key, callbacks)
    return ClientNet.CallCloud("get_rank_total", {
        key = key,
    }, {
        ok = function(payload)
            if callbacks and callbacks.ok then callbacks.ok((payload and payload.total) or 0) end
        end,
        error = function(reason)
            if callbacks and callbacks.error then callbacks.error(reason) end
        end,
    })
end

function CloudAPI.GetUserRank(maybeSelf, targetUserId, key, callbacks)
    targetUserId, key, callbacks = normalizeSelf(maybeSelf, targetUserId, key, callbacks)
    return ClientNet.CallCloud("get_user_rank", {
        userId = tonumber(targetUserId) or 0,
        key = key,
    }, {
        ok = function(payload)
            if callbacks and callbacks.ok then
                callbacks.ok(payload and payload.rank, payload and payload.scoreValue)
            end
        end,
        error = function(reason)
            if callbacks and callbacks.error then callbacks.error(reason) end
        end,
    })
end

function CloudAPI.BatchSet()
    local ops = {}
    local builder = {}

    function builder:Set(key, value)
        ops[#ops + 1] = { kind = "value", key = key, value = value }
        return builder
    end

    function builder:SetInt(key, value)
        ops[#ops + 1] = { kind = "int", key = key, value = math.floor(tonumber(value) or 0) }
        return builder
    end

    function builder:Save(reason, callbacks)
        return ClientNet.CallCloud("batch_set", {
            ops = ops,
            reason = reason,
        }, {
            ok = function(payload)
                if callbacks and callbacks.ok then callbacks.ok(payload) end
            end,
            error = function(err)
                if callbacks and callbacks.error then callbacks.error(nil, err) end
            end,
        })
    end

    return builder
end

function CloudAPI.BatchGet()
    local keys = {}
    local builder = {}

    function builder:Key(key)
        keys[#keys + 1] = key
        return builder
    end

    function builder:Fetch(callbacks)
        return ClientNet.CallCloud("batch_get", {
            keys = keys,
        }, {
            ok = function(payload)
                if callbacks and callbacks.ok then
                    callbacks.ok(
                        (payload and payload.values) or {},
                        (payload and payload.iscores) or {},
                        (payload and payload.sscores) or {}
                    )
                end
            end,
            error = function(err)
                if callbacks and callbacks.error then callbacks.error(nil, err) end
            end,
        })
    end

    return builder
end

function CloudAPI.CallRankList(key, start, count, callbacks, fields)
    fields = fields or {}
    return CloudAPI.GetRankList(key, start, count, callbacks, unpackFn(fields))
end

return CloudAPI
