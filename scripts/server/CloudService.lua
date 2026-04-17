-- ============================================================================
-- CloudService.lua - 通用服务端云数据代理
-- 使用 serverCloud 为客户端提供统一的存储 / 排行榜访问能力
-- ============================================================================

local cjson = cjson ---@diagnostic disable-line: undefined-global

local Protocol = require("network.Protocol")
local unpackFn = table.unpack or unpack

local CloudService = {}
local EVENTS = Protocol.EVENTS

local function sendResponse(connection, requestId, success, payload, errMsg)
    local data = VariantMap()
    data["RequestId"] = Variant(tonumber(requestId) or 0)
    data["Success"] = Variant(success == true)
    data["Payload"] = Variant(payload and cjson.encode(payload) or "")
    data["Error"] = Variant(errMsg or "")
    connection:SendRemoteEvent(EVENTS.CLOUD_RESPONSE, true, data)
end

local function fail(connection, requestId, reason)
    sendResponse(connection, requestId, false, nil, tostring(reason or "unknown error"))
end

local function saveBatch(userId, ops, reason, connection, requestId)
    if not serverCloud then
        fail(connection, requestId, "serverCloud unavailable")
        return
    end

    local batch = serverCloud:BatchSet(userId)
    for _, op in ipairs(ops or {}) do
        if op.kind == "int" then
            batch:SetInt(op.key, math.floor(tonumber(op.value) or 0))
        else
            batch:Set(op.key, op.value)
        end
    end

    batch:Save(reason or "cloud_batch_set", {
        ok = function()
            sendResponse(connection, requestId, true, { ok = true })
        end,
        error = function(code, reasonText)
            fail(connection, requestId, reasonText or code)
        end,
    })
end

local function fetchBatch(userId, keys, connection, requestId)
    if not serverCloud then
        fail(connection, requestId, "serverCloud unavailable")
        return
    end

    local batch = serverCloud:BatchGet(userId)
    for _, key in ipairs(keys or {}) do
        batch:Key(key)
    end

    batch:Fetch({
        ok = function(values, iscores, sscores)
            sendResponse(connection, requestId, true, {
                values = values or {},
                iscores = iscores or {},
                sscores = sscores or {},
            })
        end,
        error = function(code, reasonText)
            fail(connection, requestId, reasonText or code)
        end,
    })
end

local function handleAddInt(userId, key, delta, connection, requestId)
    if not serverCloud then
        fail(connection, requestId, "serverCloud unavailable")
        return
    end

    serverCloud:BatchGet(userId)
        :Key(key)
        :Fetch({
            ok = function(values, iscores)
                local current = 0
                if iscores and iscores[key] ~= nil then
                    current = tonumber(iscores[key]) or 0
                elseif values and values[key] ~= nil then
                    current = tonumber(values[key]) or 0
                end
                local nextValue = math.floor(current + (tonumber(delta) or 0))
                saveBatch(userId, {
                    { kind = "int", key = key, value = nextValue },
                }, "cloud_add_int", connection, requestId)
            end,
            error = function(code, reasonText)
                fail(connection, requestId, reasonText or code)
            end,
        })
end

local function handleGetRankList(key, start, count, fields, connection, requestId)
    if not serverCloud then
        fail(connection, requestId, "serverCloud unavailable")
        return
    end

    local requestArgs = {
        key,
        tonumber(start) or 0,
        tonumber(count) or 20,
        {
        ok = function(rankList)
            sendResponse(connection, requestId, true, {
                rankList = rankList or {},
            })
        end,
        error = function(code, reasonText)
            fail(connection, requestId, reasonText or code)
        end,
        }
    }

    for _, field in ipairs(fields or {}) do
        requestArgs[#requestArgs + 1] = field
    end

    serverCloud:GetRankList(unpackFn(requestArgs))
end

local function handleGetRankTotal(key, connection, requestId)
    if not serverCloud then
        fail(connection, requestId, "serverCloud unavailable")
        return
    end

    serverCloud:GetRankTotal(key, {
        ok = function(total)
            sendResponse(connection, requestId, true, {
                total = tonumber(total) or 0,
            })
        end,
        error = function(code, reasonText)
            fail(connection, requestId, reasonText or code)
        end,
    })
end

local function handleGetUserRank(targetUserId, key, connection, requestId)
    if not serverCloud then
        fail(connection, requestId, "serverCloud unavailable")
        return
    end

    serverCloud:GetUserRank(tonumber(targetUserId) or 0, key, {
        ok = function(rank, scoreValue)
            sendResponse(connection, requestId, true, {
                rank = rank,
                scoreValue = scoreValue,
            })
        end,
        error = function(code, reasonText)
            fail(connection, requestId, reasonText or code)
        end,
    })
end

function CloudService.HandleRequest(userId, connection, requestId, action, params)
    params = params or {}

    if action == "batch_set" then
        saveBatch(userId, params.ops, params.reason, connection, requestId)
    elseif action == "set" then
        saveBatch(userId, {
            { kind = "value", key = params.key, value = params.value },
        }, params.reason or "cloud_set", connection, requestId)
    elseif action == "set_int" then
        saveBatch(userId, {
            { kind = "int", key = params.key, value = params.value },
        }, params.reason or "cloud_set_int", connection, requestId)
    elseif action == "batch_get" then
        fetchBatch(userId, params.keys, connection, requestId)
    elseif action == "get" then
        fetchBatch(userId, { params.key }, connection, requestId)
    elseif action == "add_int" then
        handleAddInt(userId, params.key, params.delta, connection, requestId)
    elseif action == "get_rank_list" then
        handleGetRankList(params.key, params.start, params.count, params.fields, connection, requestId)
    elseif action == "get_rank_total" then
        handleGetRankTotal(params.key, connection, requestId)
    elseif action == "get_user_rank" then
        handleGetUserRank(params.userId, params.key, connection, requestId)
    else
        fail(connection, requestId, "unknown cloud action: " .. tostring(action))
    end
end

return CloudService
