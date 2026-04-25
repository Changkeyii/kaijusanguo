-- ============================================================================
-- cloud_manager_friends.lua - 好友系统模块
-- 用途: 好友申请/同意/拒绝/删除、收发信箱管理、随机推荐/搜索玩家
-- 依赖: CloudManager(全局), CloudAPI(全局), CloudManager._C/_S(常量/状态)
-- 导出: CloudManager.SendFriendRequest, AcceptFriendRequest, RejectFriendRequest,
--       CheckIncomingRequests, CheckMyRequestResponses, GetRandomPlayers,
--       SearchPlayer, RemoveFriend, GetFriendIds, GetFriendProfiles, IsFriend
-- [TECH_DEBT] 使用全局 CloudManager 表扩展模式(遗留架构),
--             所有函数直接挂载到 CloudManager 全局表, 无独立 return
-- ============================================================================
---@diagnostic disable: undefined-global

-- 从 core 模块导入常量和共享状态
local C = CloudManager._C
local S = CloudManager._S
local KEYS = C.KEYS
local DOMAINS = C.DOMAINS
local MAX_FRIENDS = C.MAX_FRIENDS
local REQUEST_EXPIRE_SECONDS = C.REQUEST_EXPIRE_SECONDS
local MAX_OUTBOX = C.MAX_OUTBOX
local MAX_CAMP_MEMBERS = C.MAX_CAMP_MEMBERS
local CAMP_CREATE_COST = C.CAMP_CREATE_COST
local FACTION_ROLES = C.FACTION_ROLES
local ROLE_SUCCESSION = C.ROLE_SUCCESSION
local BAN_LEVEL_SOCIAL = C.BAN_LEVEL_SOCIAL
local BAN_LEVEL_CORE = C.BAN_LEVEL_CORE
local COOLDOWN_FRIEND_REQUEST = C.COOLDOWN_FRIEND_REQUEST
local COOLDOWN_PROFILE_PUBLISH = C.COOLDOWN_PROFILE_PUBLISH
local COOLDOWN_REJECTED_RETRY = C.COOLDOWN_REJECTED_RETRY
local _getRoleLevel = C._getRoleLevel
local _getRoleName = C._getRoleName
local _hasAuthorityOver = C._hasAuthorityOver
local _countRole = C._countRole

local function _getRankItemUserId(item)
    if rawget(_G, "ResolveRankListUserId") then
        return ResolveRankListUserId(item)
    end
    return tonumber(item and (item.userId or item.player or item.uid)) or 0
end

-- ============================================================================
-- 好友系统 (公共申请池模型 — 安全版)
-- 核心: 排行榜做公共信箱, 每人只写自己数据, 永不写别人存档
-- ============================================================================

CloudManager._friendIds = {}           -- 已确认好友 { userId1, userId2, ... }
CloudManager._outgoingRequests = {}    -- 本地缓存: 我发出的申请 { [toUid]={time=ts}, ... }
CloudManager._outgoingResponses = {}   -- 本地缓存: 我的回复 { [toUid]={accepted=bool, time=ts}, ... }

-- ── 工具: 过期清理 ──

local function _purgeExpired(tbl)
    local now = os.time()
    local removed = 0
    for uid, entry in pairs(tbl) do
        if entry.time and (now - entry.time) > REQUEST_EXPIRE_SECONDS then
            tbl[uid] = nil
            removed = removed + 1
        end
    end
    return removed
end

local function _tableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- ── 初始化时从云端拉取自己的出站信箱 ──

function CloudManager._loadMyOutbox(callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback() end
        return
    end
    CloudAPI:BatchGet()
        :Key(KEYS.freq_outbox)
        :Key(KEYS.freq_resp)
        :Key(KEYS.camp_apply)
        :Key(KEYS.camp_resp)
        :Key(KEYS.camp_meta)
        :Fetch({
            ok = function(values, _)
                -- 好友出站
                if values[KEYS.freq_outbox] then
                    CloudManager._outgoingRequests = values[KEYS.freq_outbox] or {}
                    _purgeExpired(CloudManager._outgoingRequests)
                end
                if values[KEYS.freq_resp] then
                    CloudManager._outgoingResponses = values[KEYS.freq_resp] or {}
                    _purgeExpired(CloudManager._outgoingResponses)
                end
                -- 阵营出站
                if values[KEYS.camp_apply] and type(values[KEYS.camp_apply]) == "table"
                   and values[KEYS.camp_apply].campId then
                    CloudManager._campOutApply = values[KEYS.camp_apply]
                end
                if values[KEYS.camp_resp] and type(values[KEYS.camp_resp]) == "table" then
                    CloudManager._campOutResp = values[KEYS.camp_resp]
                end
                -- 盟主阵营元数据
                if values[KEYS.camp_meta] and type(values[KEYS.camp_meta]) == "table"
                   and values[KEYS.camp_meta].id then
                    CloudManager._factionMeta = values[KEYS.camp_meta]
                end
                print("[社交] 出站信箱已加载: 好友申请=" .. _tableCount(CloudManager._outgoingRequests)
                    .. " 好友回复=" .. _tableCount(CloudManager._outgoingResponses)
                    .. " 阵营申请=" .. (CloudManager._campOutApply and "有" or "无"))
                -- 阵营继位检测: 如果有阵营归属, 自动检查是否发生了盟主转让
                if CloudManager._factionId ~= 0 then
                    CloudManager._refreshFactionStatus()
                end
                if callback then callback() end
            end,
            error = function(_, reason)
                print("[社交] 加载出站信箱失败: " .. tostring(reason))
                if callback then callback() end
            end,
        })
end

-- ── 发布自己的出站信箱到排行榜 ──

function CloudManager._publishOutbox()
    if not CloudAPI.IsAvailable() then return end
    _purgeExpired(CloudManager._outgoingRequests)
    CloudAPI:BatchSet()
        :SetInt(KEYS.freq_outbox_ts, os.time())
        :Set(KEYS.freq_outbox, CloudManager._outgoingRequests)
        :Save("发布公开档案")
end

function CloudManager._publishResponses()
    if not CloudAPI.IsAvailable() then return end
    _purgeExpired(CloudManager._outgoingResponses)
    CloudAPI:BatchSet()
        :SetInt(KEYS.freq_resp_ts, os.time())
        :Set(KEYS.freq_resp, CloudManager._outgoingResponses)
        :Save("发布公开档案")
end

-- ── 发送好友申请 ──

--- 向目标玩家发送好友申请 (写入自己的出站信箱)
---@param targetUserId number
---@param message? string 申请留言
---@return boolean success
---@return string? reason
function CloudManager.SendFriendRequest(targetUserId, message)
    -- 封禁检查: 社交封禁及以上禁止
    if S.banLevel >= BAN_LEVEL_SOCIAL then
        return false, "社交功能已被限制"
    end
    if not targetUserId or targetUserId == 0 then
        return false, "无效的用户ID"
    end
    local myUid = CloudAPI.GetUserId()
    if targetUserId == myUid then
        return false, "社交功能已被限制"
    end
    -- 频率限制
    if not CloudManager._checkCooldown("friend_request", COOLDOWN_FRIEND_REQUEST) then
        return false, "操作过于频繁, 请" .. COOLDOWN_FRIEND_REQUEST .. "秒后再试"
    end
    -- 已是好友
    if CloudManager.IsFriend(targetUserId) then
        return false, "已是好友"
    end
    -- 已有待处理申请 (7天内防重复)
    local uidKey = tostring(targetUserId)
    if CloudManager._outgoingRequests[uidKey] then
        return false, "已发送过申请, 等待对方回应"
    end
    -- 被拒绝冷却: 24小时内不能重复申请同一人
    local rejectTime = S.rejectedByCache[uidKey]
    if rejectTime and (os.time() - rejectTime) < COOLDOWN_REJECTED_RETRY then
        local remaining = COOLDOWN_REJECTED_RETRY - (os.time() - rejectTime)
        local hours = math.ceil(remaining / 3600)
        return false, "对方曾拒绝你的申请, " .. hours .. "小时后可重试"
    end
    -- 出站上限
    if _tableCount(CloudManager._outgoingRequests) >= MAX_OUTBOX then
        _purgeExpired(CloudManager._outgoingRequests)
        if _tableCount(CloudManager._outgoingRequests) >= MAX_OUTBOX then
            return false, "待处理申请过多, 请等待回应或清理"
        end
    end

    CloudManager._outgoingRequests[uidKey] = {
        time = os.time(),
        msg = message or "",
    }
    CloudManager._publishOutbox()
    print("[好友] 已发送申请给 " .. uidKey)
    return true
end

-- ── 拉取发给我的好友申请 (扫描所有人的出站信箱) ──

--- 检查收到的好友申请
---@param callback fun(requests: table[]) {fromUid, time, msg, nickname}
function CloudManager.CheckIncomingRequests(callback)
    if S.banLevel >= BAN_LEVEL_SOCIAL then
        if callback then callback({}) end
        return
    end
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end
    local myUid = CloudAPI.GetUserId()

    -- 扫描 freq_outbox_ts 排行榜 (按最近更新排序, 拉200人)
    CloudAPI:GetRankList(KEYS.freq_outbox_ts, 0, 200, {
        ok = function(rankList)
            local incoming = {}
            local senderIds = {}
            local myUidStr = tostring(myUid)

            for _, item in ipairs(rankList) do
                local senderId = _getRankItemUserId(item)
                if senderId ~= myUid then
                    local outbox = item.score[KEYS.freq_outbox]
                    if type(outbox) == "table" and outbox[myUidStr] then
                        local req = outbox[myUidStr]
                        -- 检查过期
                        if req.time and (os.time() - req.time) <= REQUEST_EXPIRE_SECONDS then
                            -- 排除已是好友 & 已回复的
                            if not CloudManager.IsFriend(senderId)
                               and not CloudManager._outgoingResponses[tostring(senderId)] then
                                table.insert(incoming, {
                                    fromUid = senderId,
                                    time = req.time,
                                    msg = req.msg or "",
                                    nickname = "",
                                })
                                table.insert(senderIds, senderId)
                            end
                        end
                    end
                end
            end

            -- 批量查昵称
            if #senderIds > 0 and rawget(_G, "GetUserNickname") then
                GetUserNickname({
                    userIds = senderIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do
                            map[info.userId] = info.nickname or ""
                        end
                        for _, r in ipairs(incoming) do
                            r.nickname = map[r.fromUid] or "未知"
                        end
                        if callback then callback(incoming) end
                    end,
                    onError = function()
                        if callback then callback(incoming) end
                    end,
                })
            else
                if callback then callback(incoming) end
            end
        end,
        error = function(_, reason)
            print("[好友] 扫描入站申请失败: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.freq_outbox)
end

-- ── 同意好友申请 ──

--- 同意来自 fromUserId 的好友申请
---@param fromUserId number
---@return boolean
function CloudManager.AcceptFriendRequest(fromUserId)
    if S.banLevel >= BAN_LEVEL_SOCIAL then return false end
    if not fromUserId or fromUserId == 0 then return false end
    if CloudManager.IsFriend(fromUserId) then return false end
    if #CloudManager._friendIds >= MAX_FRIENDS then
        print("[好友] 好友数已满 " .. MAX_FRIENDS)
        return false
    end

    -- 1. 加入自己好友列表
    table.insert(CloudManager._friendIds, fromUserId)

    -- 2. 发布回复到自己的 resp 信箱 (对方下次登录会扫到)
    CloudManager._outgoingResponses[tostring(fromUserId)] = {
        accepted = true,
        time = os.time(),
    }
    CloudManager._publishResponses()
    CloudManager._syncSocialDomain()

    print("[好友] 已同意 " .. tostring(fromUserId) .. " 的申请, 当前好友 " .. #CloudManager._friendIds .. " 人")
    return true
end

--- 拒绝来自 fromUserId 的好友申请 (仅标记, 不加好友)
---@param fromUserId number
function CloudManager.RejectFriendRequest(fromUserId)
    if not fromUserId or fromUserId == 0 then return end
    CloudManager._outgoingResponses[tostring(fromUserId)] = {
        accepted = false,
        time = os.time(),
    }
    CloudManager._publishResponses()
    print("[好友] 已拒绝 " .. tostring(fromUserId) .. " 的申请")
end

-- ── 检查我发出的申请的回复 (自动完成双向加好友) ──

--- 检查我发出的申请是否被对方回复, 自动完成互加
---@param callback? fun(results: table[]) {toUid, accepted, nickname}
function CloudManager.CheckMyRequestResponses(callback)
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end
    local myUid = CloudAPI.GetUserId()
    local myUidStr = tostring(myUid)

    -- 我有哪些待处理的出站申请?
    local pendingUids = {}
    for uidStr, _ in pairs(CloudManager._outgoingRequests) do
        table.insert(pendingUids, tonumber(uidStr))
    end
    if #pendingUids == 0 then
        if callback then callback({}) end
        return
    end

    -- 扫描 freq_resp_ts 排行榜, 找对方的回复
    CloudAPI:GetRankList(KEYS.freq_resp_ts, 0, 200, {
        ok = function(rankList)
            local results = {}
            local completedUids = {}

            for _, item in ipairs(rankList) do
                local responder = _getRankItemUserId(item)
                local respData = item.score[KEYS.freq_resp]
                if type(respData) == "table" and respData[myUidStr] then
                    local resp = respData[myUidStr]
                    if resp.accepted then
                        -- 对方同意了! 加入我的好友列表
                        if not CloudManager.IsFriend(responder)
                           and #CloudManager._friendIds < MAX_FRIENDS then
                            table.insert(CloudManager._friendIds, responder)
                            table.insert(completedUids, responder)
                        end
                    else
                        -- 对方拒绝了, 记录到被拒缓存 (24h冷却)
                        S.rejectedByCache[tostring(responder)] = os.time()
                    end
                    table.insert(results, {
                        toUid = responder,
                        accepted = resp.accepted or false,
                    })
                    -- 从出站信箱移除已处理的
                    CloudManager._outgoingRequests[tostring(responder)] = nil
                end
            end

            -- 如果有新增好友, 同步
            if #completedUids > 0 then
                CloudManager._publishOutbox()  -- 更新出站 (移除已处理)
                CloudManager._syncSocialDomain()
                print("[好友] 自动互加完成: +" .. #completedUids .. " 人")
            end

            if callback then callback(results) end
        end,
        error = function(_, reason)
                print("[社交] 加载出站信箱失败: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.freq_resp)
end

-- ── 随机推荐玩家 ──

--- 从战力排行榜随机抽取 count 个玩家 (排除自己和已有好友)
---@param count number
---@param callback fun(players: table[])
function CloudManager.GetRandomPlayers(count, callback)
    count = count or 10
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end

    -- 先获取排行榜总人数
    CloudAPI:GetRankTotal(KEYS.combat_power, {
        ok = function(total)
            if total <= 0 then
                if callback then callback({}) end
                return
            end
            -- 随机偏移, 拉 count*3 条 (留余量过滤)
            local fetchCount = math.min(total, count * 3, 200)
            local maxStart = math.max(0, total - fetchCount)
            local startPos = math.random(0, maxStart)

            CloudManager.GetPublicProfiles(startPos, fetchCount, function(profiles)
                -- 过滤自己、好友、3天未在线
                local myUid = CloudAPI.GetUserId()
                local now = os.time()
                local friendSet = {}
                for _, fid in ipairs(CloudManager._friendIds) do friendSet[fid] = true end

                local candidates = {}
                for _, p in ipairs(profiles) do
                    if p.userId ~= myUid and not friendSet[p.userId] then
                        local updatedAt = (p.profile and p.profile.updatedAt) or 0
                        if updatedAt > 0 and (now - updatedAt) <= 3 * 86400 then
                            table.insert(candidates, p)
                        end
                    end
                end

                -- 随机打乱 & 截取
                for i = #candidates, 2, -1 do
                    local j = math.random(1, i)
                    candidates[i], candidates[j] = candidates[j], candidates[i]
                end
                local result = {}
                for i = 1, math.min(count, #candidates) do
                    result[i] = candidates[i]
                end
                if callback then callback(result) end
            end)
        end,
        error = function()
            if callback then callback({}) end
        end,
    })
end

--- 搜索玩家 (按userId精确匹配)
---@param targetUserId number
---@param callback fun(player: table|nil)
function CloudManager.SearchPlayer(targetUserId, callback)
    if not CloudAPI.IsAvailable() or not targetUserId then
        if callback then callback(nil) end
        return
    end

    -- 通过 GetUserRank 查找
    CloudAPI:GetUserRank(targetUserId, KEYS.combat_power, {
        ok = function(rank, scoreValue)
            if not rank then
                if callback then callback(nil) end
                return
            end
            -- 找到了, 拉取详细资料 (从排行榜偏移)
            local startPos = math.max(0, rank - 1)
            CloudManager.GetPublicProfiles(startPos, 1, function(profiles)
                local found = nil
                for _, p in ipairs(profiles) do
                    if p.userId == targetUserId then
                        found = p
                        break
                    end
                end
                if callback then callback(found) end
            end)
        end,
        error = function()
            if callback then callback(nil) end
        end,
    })
end

-- ── 好友管理 ──

--- 移除好友
---@param userId number
---@return boolean
function CloudManager.RemoveFriend(userId)
    for i, id in ipairs(CloudManager._friendIds) do
        if id == userId then
            table.remove(CloudManager._friendIds, i)
            CloudManager._syncSocialDomain()
            print("[好友] 移除好友: " .. tostring(userId))
            return true
        end
    end
    return false
end

--- 获取好友ID列表
---@return number[]
function CloudManager.GetFriendIds()
    return CloudManager._friendIds
end

function CloudManager.GetFriendProfiles(callback)
    if #CloudManager._friendIds == 0 then
        if callback then callback({}) end
        return
    end
    CloudManager.GetPublicProfiles(0, 100, function(profiles)
        local friendSet = {}
        for _, id in ipairs(CloudManager._friendIds) do friendSet[id] = true end
        local friends = {}
        for _, p in ipairs(profiles) do
            if friendSet[p.userId] then
                friends[#friends + 1] = p
            end
        end
        if callback then callback(friends) end
    end)
end

--- 是否是好友
---@param userId number
---@return boolean
function CloudManager.IsFriend(userId)
    for _, id in ipairs(CloudManager._friendIds) do
        if id == userId then return true end
    end
    return false
end
