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

    -- 使用 BatchCommit:ScoreAddInt 实现原子性增量，避免 read-modify-write 竞争
    local c = serverCloud:BatchCommit("cloud_add_int")
    c:ScoreAddInt(userId, key, math.floor(tonumber(delta) or 0))
    c:Commit({
        ok = function()
            sendResponse(connection, requestId, true, { ok = true })
        end,
        error = function(code, reasonText)
            fail(connection, requestId, reasonText or code)
        end,
    })
end

-- 服务端原子交易购买：读取买家核心数据 → 验证虎珀余额 → 扣除 → 写回
local function handleTradeBuy(userId, params, connection, requestId)
    if not serverCloud then
        fail(connection, requestId, "serverCloud unavailable")
        return
    end

    local coreKey       = tostring(params.coreKey or "")
    local expectedPrice = math.floor(tonumber(params.price) or 0)

    if coreKey == "" then
        fail(connection, requestId, "trade_buy: missing coreKey")
        return
    end
    if expectedPrice <= 0 then
        fail(connection, requestId, "trade_buy: invalid price " .. expectedPrice)
        return
    end

    -- 1. 读取买家核心存档
    serverCloud:BatchGet(userId)
        :Key(coreKey)
        :Fetch({
            ok = function(scores)
                local coreData = scores and scores[coreKey]
                if type(coreData) ~= "table" then
                    fail(connection, requestId, "trade_buy: coreData not found")
                    return
                end

                local pi   = coreData.playerInfo
                local jade = tonumber(pi and pi.jade) or 0

                -- 2. 服务端验证余额
                if jade < expectedPrice then
                    fail(connection, requestId,
                        "trade_buy: jade insufficient (" .. jade .. " < " .. expectedPrice .. ")")
                    return
                end

                -- 3. 原子扣除：更新 blob 后通过 BatchCommit 写回
                pi.jade = jade - expectedPrice

                local c = serverCloud:BatchCommit("trade_buy")
                c:ScoreSet(userId, coreKey, coreData)
                c:Commit({
                    ok = function()
                        sendResponse(connection, requestId, true, {
                            jade = pi.jade,  -- 返回扣除后余额供客户端同步
                        })
                    end,
                    error = function(code, reasonText)
                        fail(connection, requestId, reasonText or code)
                    end,
                })
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
    elseif action == "trade_buy" then
        handleTradeBuy(userId, params, connection, requestId)
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
