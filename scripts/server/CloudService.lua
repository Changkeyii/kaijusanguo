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

--- 深拷贝: 将可能含 userdata 的引擎对象递归转为纯 Lua table (cjson 安全)
local function deepCopyForJson(v)
    local t = type(v)
    if t == "table" then
        local copy = {}
        for k, val in pairs(v) do
            copy[k] = deepCopyForJson(val)
        end
        return copy
    elseif t == "string" then
        -- Set 值可能被引擎存为 JSON 字符串, 尝试解码
        local ok2, decoded = pcall(cjson.decode, v)
        if ok2 and type(decoded) == "table" then
            return decoded
        end
        return v
    elseif t == "number" or t == "boolean" then
        return v
    elseif t == "userdata" then
        -- 尝试 pairs 迭代 (VariantMap 等支持)
        local ok, result = pcall(function()
            local tbl = {}
            for k2, v2 in pairs(v) do
                tbl[k2] = deepCopyForJson(v2)
            end
            return tbl
        end)
        if ok and next(result) then return result end
        -- 尝试 tostring 兜底
        return tostring(v)
    end
    return nil
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
                values  = values  and deepCopyForJson(values)  or {},
                iscores = iscores and deepCopyForJson(iscores) or {},
                sscores = sscores and deepCopyForJson(sscores) or {},
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
            -- ★ 深拷贝 rankList，确保 score/iscore 中的 userdata 能被 cjson 序列化
            local safeList = {}
            for i, entry in ipairs(rankList or {}) do
                local rawScore = entry.score and deepCopyForJson(entry.score) or {}
                -- Set 值可能被引擎序列化为 JSON 字符串, 需要解码回 table
                for k, v in pairs(rawScore) do
                    if type(v) == "string" then
                        local ok2, decoded = pcall(cjson.decode, v)
                        if ok2 and type(decoded) == "table" then
                            rawScore[k] = decoded
                        end
                    end
                end
                safeList[i] = {
                    userId = entry.userId or entry.player,
                    player = entry.player or entry.userId,
                    iscore = entry.iscore and deepCopyForJson(entry.iscore) or {},
                    score  = rawScore,
                }
            end
            sendResponse(connection, requestId, true, {
                rankList = safeList,
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

-- ============================================================================
-- 管理员操作（服务端权威，UID 校验）
-- 所有管理员操作必须经过此入口，服务端硬编码校验 UID
-- ============================================================================

-- 管理员 UID 白名单（服务端硬编码，客户端无法伪造）
local ADMIN_UIDS = { [162525390] = true, [1630857738] = true }

-- 管理员封禁数据的 serverCloud 键名（独立于 clientCloud）
local ADMIN_BAN_KEY    = "slg_admin_ban_data"
local ADMIN_BAN_TS_KEY = "slg_admin_ban_ts"

-- 管理员专属的公告/广播邮件键名
local ADMIN_MAIL_KEY    = "slg_admin_broadcast"
local ADMIN_MAIL_TS_KEY = "slg_admin_broadcast_ts"

--- 服务端校验管理员身份
local function isAdminUser(userId)
    return ADMIN_UIDS[userId] == true
end

--- 暴露给 Server.lua 使用（Welcome 时下发 isAdmin 标记）
function CloudService.IsAdmin(userId)
    return isAdminUser(userId)
end

--- 管理员专用响应（复用 ADMIN_RESPONSE 事件）
local function sendAdminResponse(connection, requestId, success, payload, errMsg)
    local data = VariantMap()
    data["RequestId"] = Variant(tonumber(requestId) or 0)
    data["Success"] = Variant(success == true)
    data["Payload"] = Variant(payload and cjson.encode(payload) or "")
    data["Error"] = Variant(errMsg or "")
    connection:SendRemoteEvent(EVENTS.ADMIN_RESPONSE, true, data)
end

local function adminFail(connection, requestId, reason)
    sendAdminResponse(connection, requestId, false, nil, tostring(reason or "unknown error"))
end

-- ---- 封禁管理 ----

--- 获取封禁名单（从 serverCloud 管理员专属 key 读取）
local function adminGetBanList(userId, connection, requestId)
    if not serverCloud then
        adminFail(connection, requestId, "serverCloud unavailable")
        return
    end
    -- 用管理员自己的 userId 作为存储主体（只有管理员能写）
    serverCloud:BatchGet(userId)
        :Key(ADMIN_BAN_KEY)
        :Fetch({
            ok = function(values)
                local data = values and values[ADMIN_BAN_KEY]
                local bans = {}
                if type(data) == "table" and type(data.bans) == "table" then
                    bans = data.bans
                end
                sendAdminResponse(connection, requestId, true, { bans = bans })
            end,
            error = function(code, reason)
                adminFail(connection, requestId, reason or code)
            end,
        })
end

--- 发布封禁名单（覆盖式写入 serverCloud）
local function adminPublishBanList(userId, bans, connection, requestId)
    if not serverCloud then
        adminFail(connection, requestId, "serverCloud unavailable")
        return
    end
    local ts = os.time()
    local batch = serverCloud:BatchSet(userId)
    batch:SetInt(ADMIN_BAN_TS_KEY, ts)
    batch:Set(ADMIN_BAN_KEY, { bans = bans, updated = ts })
    batch:Save("admin_ban_publish", {
        ok = function()
            print("[Server/Admin] 封禁名单已发布 by uid=" .. tostring(userId))
            sendAdminResponse(connection, requestId, true, { ok = true })
        end,
        error = function(code, reason)
            adminFail(connection, requestId, reason or code)
        end,
    })
end

--- 永久封禁
local function adminPermanentBan(userId, targetUid, connection, requestId)
    -- 先读取现有封禁名单，再追加
    serverCloud:BatchGet(userId)
        :Key(ADMIN_BAN_KEY)
        :Fetch({
            ok = function(values)
                local data = values and values[ADMIN_BAN_KEY]
                local bans = (type(data) == "table" and type(data.bans) == "table") and data.bans or {}
                local uidStr = tostring(targetUid)
                bans[uidStr] = bans[uidStr] or {}
                bans[uidStr].level = 3
                bans[uidStr].reason = "永久封禁(服务端权威)"
                bans[uidStr]["until"] = 0
                bans[uidStr].rankHidden = true
                bans[uidStr].permanent = true
                adminPublishBanList(userId, bans, connection, requestId)
            end,
            error = function(code, reason)
                adminFail(connection, requestId, reason or code)
            end,
        })
end

--- 完全解封
local function adminFullUnban(userId, targetUid, connection, requestId)
    serverCloud:BatchGet(userId)
        :Key(ADMIN_BAN_KEY)
        :Fetch({
            ok = function(values)
                local data = values and values[ADMIN_BAN_KEY]
                local bans = (type(data) == "table" and type(data.bans) == "table") and data.bans or {}
                bans[tostring(targetUid)] = nil
                adminPublishBanList(userId, bans, connection, requestId)
            end,
            error = function(code, reason)
                adminFail(connection, requestId, reason or code)
            end,
        })
end

--- 隐藏玩家排行榜
local function adminHideRank(userId, targetUid, connection, requestId)
    serverCloud:BatchGet(userId)
        :Key(ADMIN_BAN_KEY)
        :Fetch({
            ok = function(values)
                local data = values and values[ADMIN_BAN_KEY]
                local bans = (type(data) == "table" and type(data.bans) == "table") and data.bans or {}
                local uidStr = tostring(targetUid)
                if not bans[uidStr] then
                    bans[uidStr] = { level = 0, reason = "排行榜隐藏", ["until"] = 0 }
                end
                bans[uidStr].rankHidden = true
                adminPublishBanList(userId, bans, connection, requestId)
            end,
            error = function(code, reason)
                adminFail(connection, requestId, reason or code)
            end,
        })
end

--- 恢复排行榜显示
local function adminUnhideRank(userId, targetUid, connection, requestId)
    serverCloud:BatchGet(userId)
        :Key(ADMIN_BAN_KEY)
        :Fetch({
            ok = function(values)
                local data = values and values[ADMIN_BAN_KEY]
                local bans = (type(data) == "table" and type(data.bans) == "table") and data.bans or {}
                local uidStr = tostring(targetUid)
                if bans[uidStr] then
                    bans[uidStr].rankHidden = nil
                    if (bans[uidStr].level or 0) == 0 then
                        bans[uidStr] = nil
                    end
                end
                adminPublishBanList(userId, bans, connection, requestId)
            end,
            error = function(code, reason)
                adminFail(connection, requestId, reason or code)
            end,
        })
end

-- ---- 管理员邮件/广播 ----

--- 发送广播邮件（管理员专属）
local function adminBroadcastMail(userId, params, connection, requestId)
    if not serverCloud then
        adminFail(connection, requestId, "serverCloud unavailable")
        return
    end
    local ts = os.time()
    local mailId = tostring(userId) .. "_" .. tostring(ts) .. "_" .. tostring(math.random(1000, 9999))
    local mailItem = {
        id = mailId,
        to = 0,  -- 0=广播
        from = userId,
        fromName = "管理员",
        subject = params.subject or "",
        body = params.body or "",
        rewards = params.rewards or {},
        time = ts,
    }

    -- 读取现有广播列表，追加
    serverCloud:BatchGet(userId)
        :Key(ADMIN_MAIL_KEY)
        :Fetch({
            ok = function(values)
                local existing = values and values[ADMIN_MAIL_KEY]
                local mailList = (type(existing) == "table") and existing or {}
                table.insert(mailList, 1, mailItem)
                -- 保留最近 50 封
                while #mailList > 50 do table.remove(mailList) end

                local batch = serverCloud:BatchSet(userId)
                batch:SetInt(ADMIN_MAIL_TS_KEY, ts)
                batch:Set(ADMIN_MAIL_KEY, mailList)
                batch:Save("admin_broadcast_mail", {
                    ok = function()
                        print("[Server/Admin] 广播邮件已发布: " .. (params.subject or ""))
                        sendAdminResponse(connection, requestId, true, { ok = true, mailId = mailId })
                    end,
                    error = function(code, reason)
                        adminFail(connection, requestId, reason or code)
                    end,
                })
            end,
            error = function(code, reason)
                adminFail(connection, requestId, reason or code)
            end,
        })
end

--- 发送私信邮件（管理员可发带奖励）
local function adminSendMail(userId, params, connection, requestId)
    if not serverCloud then
        adminFail(connection, requestId, "serverCloud unavailable")
        return
    end
    local targetUid = tonumber(params.targetUid)
    if not targetUid or targetUid <= 0 then
        adminFail(connection, requestId, "invalid targetUid")
        return
    end

    local ts = os.time()
    local mailId = tostring(userId) .. "_" .. tostring(ts) .. "_" .. tostring(math.random(1000, 9999))
    local mailItem = {
        id = mailId,
        to = targetUid,
        from = userId,
        fromName = "管理员",
        subject = params.subject or "",
        body = params.body or "",
        rewards = params.rewards or {},
        time = ts,
    }

    -- 管理员邮件也写入广播列表（私信 to != 0，客户端按 to 过滤）
    serverCloud:BatchGet(userId)
        :Key(ADMIN_MAIL_KEY)
        :Fetch({
            ok = function(values)
                local existing = values and values[ADMIN_MAIL_KEY]
                local mailList = (type(existing) == "table") and existing or {}
                table.insert(mailList, 1, mailItem)
                while #mailList > 50 do table.remove(mailList) end

                local batch = serverCloud:BatchSet(userId)
                batch:SetInt(ADMIN_MAIL_TS_KEY, ts)
                batch:Set(ADMIN_MAIL_KEY, mailList)
                batch:Save("admin_send_mail", {
                    ok = function()
                        print("[Server/Admin] 私信已发送 → uid=" .. tostring(targetUid))
                        sendAdminResponse(connection, requestId, true, { ok = true, mailId = mailId })
                    end,
                    error = function(code, reason)
                        adminFail(connection, requestId, reason or code)
                    end,
                })
            end,
            error = function(code, reason)
                adminFail(connection, requestId, reason or code)
            end,
        })
end

-- ============================================================================
-- 管理员请求统一入口（服务端 UID 校验）
-- ============================================================================

function CloudService.HandleAdminRequest(userId, connection, requestId, action, params)
    -- ★ 服务端硬校验：非管理员 UID 直接拒绝，不执行任何操作
    if not isAdminUser(userId) then
        print("[Server/Admin] REJECTED: userId=" .. tostring(userId) .. " action=" .. action)
        adminFail(connection, requestId, "权限不足: 非管理员")
        return
    end

    print("[Server/Admin] userId=" .. tostring(userId) .. " action=" .. action)

    if action == "get_ban_list" then
        adminGetBanList(userId, connection, requestId)
    elseif action == "publish_ban_list" then
        adminPublishBanList(userId, params.bans or {}, connection, requestId)
    elseif action == "permanent_ban" then
        adminPermanentBan(userId, params.targetUid, connection, requestId)
    elseif action == "full_unban" then
        adminFullUnban(userId, params.targetUid, connection, requestId)
    elseif action == "hide_rank" then
        adminHideRank(userId, params.targetUid, connection, requestId)
    elseif action == "unhide_rank" then
        adminUnhideRank(userId, params.targetUid, connection, requestId)
    elseif action == "broadcast_mail" then
        adminBroadcastMail(userId, params, connection, requestId)
    elseif action == "send_mail" then
        adminSendMail(userId, params, connection, requestId)
    else
        adminFail(connection, requestId, "unknown admin action: " .. tostring(action))
    end
end

return CloudService
