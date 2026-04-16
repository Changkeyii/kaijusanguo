-- ============================================================================
-- cloud_manager_social.lua - 三国武灵录 (从 cloud_manager.lua 拆分)
-- 社交系统: 公开资料、好友、公会(阵营)
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

-- ============================================================================
-- 公开档案
-- ============================================================================

--- 发布公开档案 (自动从全局变量提取, 有频率限制)
function CloudManager._publishProfile(allData)
    if not rawget(_G, "clientCloud") then return end
    -- 封禁检查
    if S.banLevel >= BAN_LEVEL_CORE then return end
    -- 频率限制
    if not CloudManager._checkCooldown("publish_profile", COOLDOWN_PROFILE_PUBLISH) then return end

    local coreData = allData and allData.core or CloudManager.CollectDomainData("core")
    local pi = coreData.playerInfo or {}

    -- 构建轻量公开资料
    local profile = {
        heroLineup = {},
        skillLineup = {},
        mainEquipTier = 0,
        level = pi.rankIdx or 1,
        totalWins = pi.totalWins or 0,
        totalBattles = pi.totalBattles or 0,
        avatarIdx = pi.avatarIdx or 1,
        factionId = CloudManager._factionId or 0,
        factionName = CloudManager._factionName or "",
        updatedAt = os.time(),
    }

    -- 上阵武灵
    if rawget(_G, "playerHeroes") then
        for idx, hero in pairs(playerHeroes) do
            if hero.owned then
                profile.heroLineup[#profile.heroLineup + 1] = tonumber(idx) or idx
            end
        end
        -- 只保留前6个
        while #profile.heroLineup > 6 do table.remove(profile.heroLineup) end
    end

    -- 装备武技
    if rawget(_G, "playerEquippedSkills") then
        for _, skillIdx in ipairs(playerEquippedSkills) do
            profile.skillLineup[#profile.skillLineup + 1] = skillIdx
        end
    end

    -- 最高装备品阶
    if rawget(_G, "playerEquipment") and playerEquipment.owned then
        for _, item in ipairs(playerEquipment.owned) do
            if item.tier and item.tier > profile.mainEquipTier then
                profile.mainEquipTier = item.tier
            end
        end
    end

    -- 计算战力 (与现有逻辑保持一致)
    local combatPower = 0
    if rawget(_G, "CalcPlayerTotalPower") then
        combatPower = CalcPlayerTotalPower() or 0
    else
        combatPower = (pi.rankIdx or 1) * 100 + (pi.totalWins or 0) * 10
    end

    -- BatchSet: 公开资料 + 战力排行
    clientCloud:BatchSet()
        :Set(KEYS.pub_profile, profile)
        :SetInt(KEYS.combat_power, combatPower)
        :SetInt(KEYS.realm_level, pi.rankIdx or 1)
        :Save("发布公开档案")
end

--- 手动发布公开档案
function CloudManager.PublishProfile()
    CloudManager._publishProfile(nil)
end

--- 获取其他玩家的公开档案 (通过战力排行榜)
---@param start number 起始位置 (0开始)
---@param count number 获取数量
---@param callback fun(profiles: table[])
function CloudManager.GetPublicProfiles(start, count, callback)
    if not rawget(_G, "clientCloud") then
        if callback then callback({}) end
        return
    end

    clientCloud:GetRankList(KEYS.combat_power, start, count, {
        ok = function(rankList)
            local profiles = {}
            local userIds = {}

            for i, item in ipairs(rankList) do
                local profile = item.score[KEYS.pub_profile] or {}
                local entry = {
                    rank = start + i,
                    userId = item.userId or item.player,
                    combatPower = (item.iscore and item.iscore[KEYS.combat_power]) or 0,
                    realmLevel = (item.iscore and item.iscore[KEYS.realm_level]) or 1,
                    profile = profile,
                    nickname = "",
                    isMe = (item.userId or item.player) == clientCloud.userId,
                }
                profiles[#profiles + 1] = entry
                userIds[#userIds + 1] = entry.userId
            end

            -- 批量查询昵称
            if #userIds > 0 and rawget(_G, "GetUserNickname") then
                GetUserNickname({
                    userIds = userIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do
                            map[info.userId] = info.nickname or ""
                        end
                        for _, entry in ipairs(profiles) do
                            entry.nickname = map[entry.userId] or "未知"
                        end
                        if callback then callback(profiles) end
                    end,
                    onError = function()
                        if callback then callback(profiles) end
                    end,
                })
            else
                if callback then callback(profiles) end
            end
        end,
        error = function(code, reason)
            print("[CloudManager] 获取排行榜失败: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.pub_profile, KEYS.realm_level)
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
    if not rawget(_G, "clientCloud") then
        if callback then callback() end
        return
    end
    clientCloud:BatchGet()
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
    if not rawget(_G, "clientCloud") then return end
    _purgeExpired(CloudManager._outgoingRequests)
    clientCloud:BatchSet()
        :SetInt(KEYS.freq_outbox_ts, os.time())
        :Set(KEYS.freq_outbox, CloudManager._outgoingRequests)
        :Save("发布好友申请出站")
end

function CloudManager._publishResponses()
    if not rawget(_G, "clientCloud") then return end
    _purgeExpired(CloudManager._outgoingResponses)
    clientCloud:BatchSet()
        :SetInt(KEYS.freq_resp_ts, os.time())
        :Set(KEYS.freq_resp, CloudManager._outgoingResponses)
        :Save("发布好友回复")
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
    local myUid = rawget(_G, "clientCloud") and clientCloud.userId or 0
    if targetUserId == myUid then
        return false, "不能添加自己"
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
    if not rawget(_G, "clientCloud") then
        if callback then callback({}) end
        return
    end
    local myUid = clientCloud.userId

    -- 扫描 freq_outbox_ts 排行榜 (按最近更新排序, 拉200人)
    clientCloud:GetRankList(KEYS.freq_outbox_ts, 0, 200, {
        ok = function(rankList)
            local incoming = {}
            local senderIds = {}
            local myUidStr = tostring(myUid)

            for _, item in ipairs(rankList) do
                local senderId = item.userId or item.player
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
    if not rawget(_G, "clientCloud") then
        if callback then callback({}) end
        return
    end
    local myUid = clientCloud.userId
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
    clientCloud:GetRankList(KEYS.freq_resp_ts, 0, 200, {
        ok = function(rankList)
            local results = {}
            local completedUids = {}

            for _, item in ipairs(rankList) do
                local responder = item.userId or item.player
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
            print("[好友] 扫描回复失败: " .. tostring(reason))
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
    if not rawget(_G, "clientCloud") then
        if callback then callback({}) end
        return
    end

    -- 先获取排行榜总人数
    clientCloud:GetRankTotal(KEYS.combat_power, {
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
                local myUid = clientCloud.userId
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
    if not rawget(_G, "clientCloud") or not targetUserId then
        if callback then callback(nil) end
        return
    end

    -- 通过 GetUserRank 查找
    clientCloud:GetUserRank(targetUserId, KEYS.combat_power, {
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

-- ============================================================================
-- 阵营养成系统 (升级 / 捐献 / 公告)
-- ============================================================================

-- 阵营等级经验表: 升到该等级所需的累计经验
-- 公式: Lv N → 成员上限 (10+10N), 每人捐 N×10000, 单级需 (10+10N)×N×10000
local FACTION_LEVEL_EXP = {
    [1]  = 0,          -- 起始
    [2]  = 200000,     -- 20人×1w = 20w
    [3]  = 800000,     -- +30人×2w = +60w
    [4]  = 2000000,    -- +40人×3w = +120w
    [5]  = 4000000,    -- +50人×4w = +200w
    [6]  = 7000000,    -- +60人×5w = +300w
    [7]  = 11200000,   -- +70人×6w = +420w
    [8]  = 16800000,   -- +80人×7w = +560w
    [9]  = 24000000,   -- +90人×8w = +720w
    [10] = 33000000,   -- +100人×9w = +900w
}
-- 阵营每级成员上限: Lv N → 10 + 10×N
local FACTION_LEVEL_MAX_MEMBERS = {
    [1]  = 20,  [2]  = 30,  [3]  = 40,  [4]  = 50,  [5]  = 60,
    [6]  = 70,  [7]  = 80,  [8]  = 90,  [9]  = 100, [10] = 100,
}
local FACTION_MAX_LEVEL = 10
local FACTION_DONATE_MIN = 100         -- 单次最少捐献

-- 职位额外加成系数 (每阵营等级额外+x%战力, 盟主最高, 成员无额外)
local ROLE_BUFF_PER_LEVEL = {
    leader      = 0.6,
    vice_leader = 0.5,
    strategist  = 0.4,
    vanguard    = 0.3,
    diplomat    = 0.2,
    elite       = 0.1,
    member      = 0,
}

--- 获取阵营等级信息
---@return table { level, exp, nextExp, maxLevel, buffPercent, roleBonusPercent, totalBuffPercent }
function CloudManager.GetFactionLevelInfo()
    local meta = CloudManager._factionMeta
    local lv = (meta and meta.level) or 1
    local exp = (meta and meta.exp) or 0
    if lv < 1 then lv = 1 end
    if lv > FACTION_MAX_LEVEL then lv = FACTION_MAX_LEVEL end
    local nextExp = FACTION_LEVEL_EXP[lv + 1] or FACTION_LEVEL_EXP[FACTION_MAX_LEVEL]
    local curNeed = FACTION_LEVEL_EXP[lv] or 0
    local baseBuff = lv * 2  -- 每级+2%战力加成(全员)
    local role = CloudManager._factionRole or "member"
    local roleCoeff = ROLE_BUFF_PER_LEVEL[role] or 0
    local roleBonus = lv * roleCoeff  -- 职位额外加成
    return {
        level = lv,
        exp = exp,
        curLevelExp = curNeed,
        nextLevelExp = nextExp,
        maxLevel = FACTION_MAX_LEVEL,
        buffPercent = baseBuff,          -- 全员基础加成%
        roleBonusPercent = roleBonus,    -- 职位额外加成%
        totalBuffPercent = baseBuff + roleBonus,  -- 总加成%
        maxMembers = FACTION_LEVEL_MAX_MEMBERS[lv] or 20,
    }
end

--- 获取当日个人已捐献额度 (本地追踪)
---@return number
function CloudManager.GetTodayDonation()
    local meta = CloudManager._factionMeta
    if not meta then return 0 end
    local myUid = rawget(_G, "clientCloud") and clientCloud.userId or 0
    local uidStr = tostring(myUid)
    local today = os.date("%Y%m%d")
    if not meta.donateDaily then return 0 end
    if not meta.donateDaily[uidStr] then return 0 end
    if meta.donateDaily[uidStr].day ~= today then return 0 end
    return meta.donateDaily[uidStr].amount or 0
end

--- 捐献虎符给阵营
---@param amount number 捐献数量
---@param callback? fun(success: boolean, reason: string)
function CloudManager.DonateFaction(amount, callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "阵营数据未加载") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end
    amount = math.floor(amount)
    if amount < FACTION_DONATE_MIN then
        if callback then callback(false, "最少捐献" .. FACTION_DONATE_MIN .. "虎符") end
        return
    end
    if not rawget(_G, "playerInfo") or (playerInfo.jade or 0) < amount then
        if callback then callback(false, "虎符不足") end
        return
    end

    local myUid = clientCloud.userId or 0
    local uidStr = tostring(myUid)
    local today = os.date("%Y%m%d")

    -- 检查每日限额
    if not meta.donateDaily then meta.donateDaily = {} end
    if not meta.donateDaily[uidStr] then meta.donateDaily[uidStr] = { day = today, amount = 0 } end
    if meta.donateDaily[uidStr].day ~= today then
        meta.donateDaily[uidStr] = { day = today, amount = 0 }
    end
    local todayDone = meta.donateDaily[uidStr].amount or 0

    -- 扣虎符
    playerInfo.jade = playerInfo.jade - amount

    -- 更新 meta
    meta.exp = (meta.exp or 0) + amount
    meta.funds = (meta.funds or 0) + amount
    meta.donateDaily[uidStr].amount = todayDone + amount

    -- 个人累计贡献
    if not meta.contributions then meta.contributions = {} end
    meta.contributions[uidStr] = (meta.contributions[uidStr] or 0) + amount

    -- 检查升级
    local oldLevel = meta.level or 1
    local newLevel = oldLevel
    for lv = oldLevel + 1, FACTION_MAX_LEVEL do
        if meta.exp >= (FACTION_LEVEL_EXP[lv] or 999999999) then
            newLevel = lv
        else
            break
        end
    end
    local leveled = newLevel > oldLevel
    meta.level = newLevel
    -- 升级后更新成员上限
    if leveled then
        meta.maxMembers = FACTION_LEVEL_MAX_MEMBERS[newLevel] or meta.maxMembers
    end

    clientCloud:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("阵营捐献", {
            ok = function()
                print("[阵营] 捐献成功: " .. amount .. "虎符, 经验=" .. meta.exp .. ", 等级=" .. meta.level)
                -- 上报阵营等级到排行榜 (等级*1000000+经验, 等级优先)
                local rankScore = meta.level * 1000000 + math.min(meta.exp, 999999)
                local rankKey = (rawget(_G, "PROJECT_PREFIX") or "p_49dd_") .. "faction_level"
                clientCloud:SetInt(rankKey, rankScore, {})
                if rawget(_G, "SaveGameProgress") then SaveGameProgress() end
                if callback then callback(true, leveled and ("阵营升级到Lv." .. newLevel .. "!") or nil) end
            end,
            error = function(_, reason)
                -- 回滚
                playerInfo.jade = playerInfo.jade + amount
                meta.exp = meta.exp - amount
                meta.funds = meta.funds - amount
                meta.donateDaily[uidStr].amount = todayDone
                meta.contributions[uidStr] = (meta.contributions[uidStr] or 0) - amount
                meta.level = oldLevel
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 检查今日是否已签到
---@return boolean
function CloudManager.HasSignedInToday()
    local meta = CloudManager._factionMeta
    if not meta then return false end
    local myUid = rawget(_G, "clientCloud") and clientCloud.userId or 0
    local uidStr = tostring(myUid)
    local today = os.date("%Y%m%d")
    if not meta.donateDaily then return false end
    if not meta.donateDaily[uidStr] then return false end
    return meta.donateDaily[uidStr].day == today and meta.donateDaily[uidStr].signedIn == true
end

--- 阵营签到 (每日免费捐献500经验，不消耗虎符)
---@param callback? fun(success: boolean, reason: string)
function CloudManager.FactionSignIn(callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "阵营数据未加载") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end

    local myUid = clientCloud.userId or 0
    local uidStr = tostring(myUid)
    local today = os.date("%Y%m%d")
    local signInAmount = 500

    -- 初始化每日记录
    if not meta.donateDaily then meta.donateDaily = {} end
    if not meta.donateDaily[uidStr] then meta.donateDaily[uidStr] = { day = today, amount = 0 } end
    if meta.donateDaily[uidStr].day ~= today then
        meta.donateDaily[uidStr] = { day = today, amount = 0 }
    end

    -- 检查是否已签到
    if meta.donateDaily[uidStr].signedIn then
        if callback then callback(false, "今日已签到") end
        return
    end

    -- 更新 meta (不扣虎符)
    meta.exp = (meta.exp or 0) + signInAmount
    meta.funds = (meta.funds or 0) + signInAmount
    meta.donateDaily[uidStr].signedIn = true
    meta.donateDaily[uidStr].amount = (meta.donateDaily[uidStr].amount or 0) + signInAmount

    -- 个人累计贡献
    if not meta.contributions then meta.contributions = {} end
    meta.contributions[uidStr] = (meta.contributions[uidStr] or 0) + signInAmount

    -- 检查升级
    local oldLevel = meta.level or 1
    local newLevel = oldLevel
    for lv = oldLevel + 1, FACTION_MAX_LEVEL do
        if meta.exp >= (FACTION_LEVEL_EXP[lv] or 999999999) then
            newLevel = lv
        else
            break
        end
    end
    local leveled = newLevel > oldLevel
    meta.level = newLevel
    if leveled then
        meta.maxMembers = FACTION_LEVEL_MAX_MEMBERS[newLevel] or meta.maxMembers
    end

    clientCloud:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("阵营签到", {
            ok = function()
                print("[阵营] 签到成功: +" .. signInAmount .. " 经验")
                local rankScore = meta.level * 1000000 + math.min(meta.exp, 999999)
                local rankKey = (rawget(_G, "PROJECT_PREFIX") or "p_49dd_") .. "faction_level"
                clientCloud:SetInt(rankKey, rankScore, {})
                if rawget(_G, "SaveGameProgress") then SaveGameProgress() end
                if callback then callback(true, leveled and ("阵营升级到Lv." .. newLevel .. "!") or nil) end
            end,
            error = function(_, reason)
                -- 回滚
                meta.exp = meta.exp - signInAmount
                meta.funds = meta.funds - signInAmount
                meta.donateDaily[uidStr].signedIn = false
                meta.donateDaily[uidStr].amount = meta.donateDaily[uidStr].amount - signInAmount
                meta.contributions[uidStr] = (meta.contributions[uidStr] or 0) - signInAmount
                meta.level = oldLevel
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 获取阵营成员贡献排行 (从meta.contributions排序)
---@return table[] { uid, amount, name }
function CloudManager.GetContributionRank()
    local meta = CloudManager._factionMeta
    if not meta or not meta.contributions then return {} end
    local list = {}
    for uid, amt in pairs(meta.contributions) do
        table.insert(list, { uid = tonumber(uid) or 0, amount = amt })
    end
    table.sort(list, function(a, b) return a.amount > b.amount end)
    return list
end

--- 设置阵营公告 (盟主/副盟主)
---@param text string 公告内容
---@param callback? fun(success: boolean, reason: string)
function CloudManager.SetFactionAnnouncement(text, callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "阵营数据未加载") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end
    local myRole = CloudManager._factionRole
    if _getRoleLevel(myRole) < _getRoleLevel("vice_leader") then
        if callback then callback(false, "副盟主及以上才能设置公告") end
        return
    end
    if text and #text > 200 then
        if callback then callback(false, "公告最多200字") end
        return
    end

    local oldAnn = meta.announcement
    meta.announcement = text or ""

    clientCloud:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("设置公告", {
            ok = function()
                print("[阵营] 公告已更新")
                if callback then callback(true, nil) end
            end,
            error = function(_, reason)
                meta.announcement = oldAnn
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 获取个人累计贡献
---@return number
function CloudManager.GetMyContribution()
    local meta = CloudManager._factionMeta
    if not meta or not meta.contributions then return 0 end
    local myUid = rawget(_G, "clientCloud") and clientCloud.userId or 0
    return meta.contributions[tostring(myUid)] or 0
end

--- 获取阵营公告
---@return string
function CloudManager.GetFactionAnnouncement()
    local meta = CloudManager._factionMeta
    if not meta then return "" end
    return meta.announcement or ""
end

--- 获取阵营资金总额
---@return number
function CloudManager.GetFactionFunds()
    local meta = CloudManager._factionMeta
    if not meta then return 0 end
    return meta.funds or 0
end

--- 获取捐献配置常量
---@return table { minAmount: number }
function CloudManager.GetDonateConfig()
    return { minAmount = FACTION_DONATE_MIN }
end

--- 获取好友档案列表 (通过排行榜匹配)
---@param callback fun(friends: table[])
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

--- 同步社交域到云端 (好友列表 + 阵营归属)
function CloudManager._syncSocialDomain()
    if not rawget(_G, "clientCloud") then return end
    local data = CloudManager.CollectDomainData("social")
    clientCloud:Set(DOMAINS.social, data, {
        ok = function()
            print("[社交] social域已同步")
        end,
    })
end

-- ============================================================================
-- 阵营系统 (公共申请池模型 — 安全版)
-- 核心: 盟主通过排行榜发布阵营, 申请者通过排行榜提交, 盟主审批后更新成员表
-- 角色体系: leader(盟主) > vice_leader(副盟主) > member(成员)
-- 继承链: 盟主退出 → 副盟主继位 → 最早成员继位 → 最后一人退出=解散
-- ============================================================================

CloudManager._factionId = 0
CloudManager._factionName = ""
CloudManager._factionRole = "none"  -- "leader" / "vice_leader" / "member" / "none"
CloudManager._factionMeta = nil     -- 阵营元数据 (盟主维护, 含 roles 字段)
CloudManager._campOutApply = nil    -- 本地缓存: 我的入营申请
CloudManager._campOutResp = {}      -- 本地缓存: 盟主的审批回复

-- ── 创建阵营 ──

--- 创建阵营 (消耗虎符, 先扣再建)
---@param name string
---@param desc string
---@param callback? fun(success: boolean, reason: string)
function CloudManager.CreateFaction(name, desc, callback)
    -- 封禁检查
    if S.banLevel >= BAN_LEVEL_SOCIAL then
        if callback then callback(false, "社交功能已被限制") end
        return
    end
    if CloudManager._factionId ~= 0 then
        if callback then callback(false, "已有阵营, 请先离开") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end
    -- 检查虎符
    if not rawget(_G, "playerInfo") or (playerInfo.jade or 0) < CAMP_CREATE_COST then
        if callback then callback(false, "虎符不足(需要" .. CAMP_CREATE_COST .. ")") end
        return
    end

    local uid = clientCloud.userId or 0
    local ts = os.time()
    -- 生成唯一阵营ID: 时间戳后6位 * 10000 + uid后4位
    local campId = (ts % 1000000) * 10000 + (uid % 10000)

    -- 1. 先扣虎符 (写入自己存档)
    playerInfo.jade = playerInfo.jade - CAMP_CREATE_COST

    local uidStr = tostring(uid)
    local meta = {
        id = campId,
        name = name,
        desc = desc or "",
        leaderId = uid,
        createdAt = ts,
        maxMembers = MAX_CAMP_MEMBERS,
        members = { uid },  -- 盟主自己是首个成员
        memberCount = 1,
        roles = { [uidStr] = "leader" },  -- 角色映射: uid→角色
    }

    CloudManager._factionId = campId
    CloudManager._factionName = name
    CloudManager._factionRole = "leader"
    CloudManager._factionMeta = meta

    -- 2. 发布到排行榜 (camp_leader_ts + camp_meta)
    clientCloud:BatchSet()
        :SetInt(KEYS.camp_leader_ts, ts)
        :Set(KEYS.camp_meta, meta)
        :Save("创建阵营", {
            ok = function()
                print("[阵营] 创建成功: " .. name .. " (ID=" .. campId .. "), 盟主, 消耗" .. CAMP_CREATE_COST .. "虎符")
                CloudManager._syncSocialDomain()
                CloudManager.PublishProfile()
                if callback then callback(true, "创建成功") end
            end,
            error = function(_, reason)
                -- 回滚虎符
                playerInfo.jade = playerInfo.jade + CAMP_CREATE_COST
                CloudManager._factionId = 0
                CloudManager._factionName = ""
                CloudManager._factionRole = "none"
                CloudManager._factionMeta = nil
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- ── 列出所有阵营 ──

--- 列出阵营列表 (从 camp_leader_ts 排行榜, 按campId去重保留最新)
---@param callback fun(factions: table[])
function CloudManager.ListFactions(callback)
    if not rawget(_G, "clientCloud") then
        if callback then callback({}) end
        return
    end

    clientCloud:GetRankList(KEYS.camp_leader_ts, 0, 100, {
        ok = function(rankList)
            -- 按 campId 去重: 盟主转让后可能存在新旧两条, 保留排行靠前(时间戳更大)的
            local campMap = {}  -- campId → faction entry
            local campOrder = {} -- 保持顺序

            for _, item in ipairs(rankList) do
                local meta = item.score[KEYS.camp_meta]
                if type(meta) == "table" and meta.id then
                    local cid = meta.id
                    local ts = (item.iscore and item.iscore[KEYS.camp_leader_ts]) or 0
                    if not campMap[cid] or ts > (campMap[cid]._ts or 0) then
                        if not campMap[cid] then
                            table.insert(campOrder, cid)
                        end
                        campMap[cid] = {
                            _ts = ts,
                            campId = cid,
                            name = meta.name or "未命名",
                            desc = meta.desc or "",
                            leaderId = meta.leaderId or (item.userId or item.player),
                            leaderNickname = "",
                            createdAt = meta.createdAt or 0,
                            maxMembers = meta.maxMembers or MAX_CAMP_MEMBERS,
                            memberCount = meta.memberCount or 0,
                            members = meta.members or {},
                            roles = meta.roles or {},
                            level = meta.level or 1,
                            exp = meta.exp or 0,
                        }
                    end
                end
            end

            -- 转为有序列表
            local factions = {}
            local leaderIds = {}
            for _, cid in ipairs(campOrder) do
                local f = campMap[cid]
                f._ts = nil  -- 清除内部字段
                table.insert(factions, f)
                table.insert(leaderIds, f.leaderId)
            end

            -- 批量查昵称
            if #leaderIds > 0 and rawget(_G, "GetUserNickname") then
                GetUserNickname({
                    userIds = leaderIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do map[info.userId] = info.nickname or "" end
                        for _, f in ipairs(factions) do f.leaderNickname = map[f.leaderId] or "未知" end
                        if callback then callback(factions) end
                    end,
                    onError = function() if callback then callback(factions) end end,
                })
            else
                if callback then callback(factions) end
            end
        end,
        error = function(_, reason)
            print("[阵营] 列出阵营失败: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.camp_meta)
end

-- ── 申请加入阵营 ──

--- 申请加入指定阵营
---@param campId number
---@param campName string
---@param callback? fun(success: boolean, reason: string)
function CloudManager.ApplyToFaction(campId, campName, callback)
    -- 封禁检查
    if S.banLevel >= BAN_LEVEL_SOCIAL then
        if callback then callback(false, "社交功能已被限制") end
        return
    end
    if CloudManager._factionId ~= 0 then
        if callback then callback(false, "已有阵营, 请先离开") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end

    local apply = {
        campId = campId,
        campName = campName or "",
        time = os.time(),
    }
    CloudManager._campOutApply = apply

    clientCloud:BatchSet()
        :SetInt(KEYS.camp_apply_ts, os.time())
        :Set(KEYS.camp_apply, apply)
        :Save("申请加入阵营", {
            ok = function()
                print("[阵营] 已提交申请: " .. (campName or "") .. " (ID=" .. campId .. ")")
                if callback then callback(true, "申请已提交") end
            end,
            error = function(_, reason)
                CloudManager._campOutApply = nil
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- ── 盟主审批 ──

--- 盟主/副盟主查看阵营申请 (扫描 camp_apply_ts 排行榜)
---@param callback fun(applications: table[])
function CloudManager.CheckFactionApplications(callback)
    -- 副盟主及以上可审批 (level >= 5)
    if _getRoleLevel(CloudManager._factionRole) < _getRoleLevel("vice_leader")
       or CloudManager._factionId == 0 then
        if callback then callback({}) end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback({}) end
        return
    end
    local myCampId = CloudManager._factionId

    clientCloud:GetRankList(KEYS.camp_apply_ts, 0, 200, {
        ok = function(rankList)
            local applications = {}
            local applicantIds = {}

            for _, item in ipairs(rankList) do
                local applyData = item.score[KEYS.camp_apply]
                if type(applyData) == "table" and applyData.campId == myCampId then
                    local applicantId = item.userId or item.player
                    -- 排除过期 & 已在成员列表中
                    if applyData.time and (os.time() - applyData.time) <= REQUEST_EXPIRE_SECONDS then
                        local alreadyMember = false
                        if CloudManager._factionMeta and CloudManager._factionMeta.members then
                            for _, mid in ipairs(CloudManager._factionMeta.members) do
                                if mid == applicantId then alreadyMember = true; break end
                            end
                        end
                        -- 排除已回复拒绝/同意的
                        local alreadyResp = CloudManager._campOutResp[tostring(applicantId)]
                        if not alreadyMember and not alreadyResp then
                            table.insert(applications, {
                                userId = applicantId,
                                time = applyData.time,
                                nickname = "",
                            })
                            table.insert(applicantIds, applicantId)
                        end
                    end
                end
            end

            if #applicantIds > 0 and rawget(_G, "GetUserNickname") then
                GetUserNickname({
                    userIds = applicantIds,
                    onSuccess = function(nicknames)
                        local map = {}
                        for _, info in ipairs(nicknames) do map[info.userId] = info.nickname or "" end
                        for _, a in ipairs(applications) do a.nickname = map[a.userId] or "未知" end
                        if callback then callback(applications) end
                    end,
                    onError = function() if callback then callback(applications) end end,
                })
            else
                if callback then callback(applications) end
            end
        end,
        error = function(_, reason)
            print("[阵营] 扫描申请失败: " .. tostring(reason))
            if callback then callback({}) end
        end,
    }, KEYS.camp_apply)
end

--- 盟主/副盟主同意申请
---@param applicantUserId number
---@param callback? fun(success: boolean)
function CloudManager.ApproveFactionApplication(applicantUserId, callback)
    -- 副盟主及以上可审批
    if _getRoleLevel(CloudManager._factionRole) < _getRoleLevel("vice_leader")
       or not CloudManager._factionMeta then
        if callback then callback(false) end
        return
    end

    local meta = CloudManager._factionMeta
    -- 人数上限
    if (meta.memberCount or 0) >= (meta.maxMembers or MAX_CAMP_MEMBERS) then
        print("[阵营] 成员已满")
        if callback then callback(false) end
        return
    end

    -- 追加成员
    if not meta.members then meta.members = {} end
    -- 检查重复
    for _, mid in ipairs(meta.members) do
        if mid == applicantUserId then
            if callback then callback(true) end -- 已在列表
            return
        end
    end
    table.insert(meta.members, applicantUserId)
    meta.memberCount = #meta.members
    -- 新成员默认角色
    if not meta.roles then meta.roles = {} end
    meta.roles[tostring(applicantUserId)] = "member"

    -- 记录审批回复
    CloudManager._campOutResp[tostring(applicantUserId)] = {
        approved = true,
        campId = meta.id,
        campName = meta.name,
        time = os.time(),
    }

    -- 先读再合并: 更新 camp_meta + 发布审批回复
    clientCloud:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :SetInt(KEYS.camp_resp_ts, os.time())
        :Set(KEYS.camp_resp, CloudManager._campOutResp)
        :Save("同意入营", {
            ok = function()
                print("[阵营] 已同意 " .. tostring(applicantUserId) .. " 加入, 当前" .. meta.memberCount .. "人")
                if callback then callback(true) end
            end,
            error = function()
                -- 回滚
                for i, mid in ipairs(meta.members) do
                    if mid == applicantUserId then table.remove(meta.members, i); break end
                end
                meta.memberCount = #meta.members
                CloudManager._campOutResp[tostring(applicantUserId)] = nil
                if callback then callback(false) end
            end,
        })
end

--- 盟主拒绝申请
---@param applicantUserId number
function CloudManager.RejectFactionApplication(applicantUserId)
    CloudManager._campOutResp[tostring(applicantUserId)] = {
        approved = false,
        campId = CloudManager._factionId,
        time = os.time(),
    }
    if rawget(_G, "clientCloud") then
        clientCloud:BatchSet()
            :SetInt(KEYS.camp_resp_ts, os.time())
            :Set(KEYS.camp_resp, CloudManager._campOutResp)
            :Save("拒绝入营")
    end
end

-- ── 申请者检查审批结果 ──

--- 检查我的入营申请是否被批准 (自动完成入营)
---@param callback? fun(result: string) "approved" | "rejected" | "pending" | "none"
function CloudManager.CheckMyFactionApplication(callback)
    if not CloudManager._campOutApply then
        if callback then callback("none") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback("pending") end
        return
    end

    local myUid = clientCloud.userId
    local myUidStr = tostring(myUid)
    local targetCampId = CloudManager._campOutApply.campId

    -- 扫描盟主的审批回复
    clientCloud:GetRankList(KEYS.camp_resp_ts, 0, 100, {
        ok = function(rankList)
            for _, item in ipairs(rankList) do
                local respData = item.score[KEYS.camp_resp]
                if type(respData) == "table" and respData[myUidStr] then
                    local resp = respData[myUidStr]
                    if resp.campId == targetCampId then
                        if resp.approved then
                            -- 入营成功!
                            CloudManager._factionId = targetCampId
                            CloudManager._factionName = CloudManager._campOutApply.campName or ""
                            CloudManager._factionRole = "member"
                            CloudManager._campOutApply = nil
                            -- 清理申请排行
                            clientCloud:BatchSet()
                                :SetInt(KEYS.camp_apply_ts, 0)
                                :Set(KEYS.camp_apply, {})
                                :Save("清理入营申请")
                            CloudManager._syncSocialDomain()
                            CloudManager.PublishProfile()
                            -- 拉取阵营meta(盟主名/人数等), 供UI显示
                            CloudManager._refreshFactionStatus()
                            print("[阵营] 入营审批通过!")
                            if callback then callback("approved") end
                        else
                            CloudManager._campOutApply = nil
                            print("[阵营] 入营申请被拒绝")
                            if callback then callback("rejected") end
                        end
                        return
                    end
                end
            end
            if callback then callback("pending") end
        end,
        error = function()
            if callback then callback("pending") end
        end,
    }, KEYS.camp_resp)
end

-- ── 离开阵营 ──

--- 从成员列表中找到继任者 (按率土职位继承链: 副盟主→军师→先锋官→外交官→精英→成员)
--- 同级别内按加入顺序(members数组顺序)优先
---@param meta table 阵营元数据
---@param excludeUid number 要排除的uid(即将离开的人)
---@return number|nil successorUid
local function _findSuccessor(meta, excludeUid)
    if not meta or not meta.members then return nil end
    local roles = meta.roles or {}
    -- 按继承链顺序逐级查找
    for _, roleName in ipairs(ROLE_SUCCESSION) do
        for _, mid in ipairs(meta.members) do
            if mid ~= excludeUid and (roles[tostring(mid)] or "member") == roleName then
                return mid
            end
        end
    end
    return nil  -- 没有其他人了
end

--- 离开当前阵营
--- 盟主退出: 有其他成员→转让盟主(副盟主优先), 无其他成员→解散
--- 非盟主退出: 直接离开, 本地清除
---@param callback? fun(success: boolean, info: string)
function CloudManager.LeaveFaction(callback)
    if CloudManager._factionId == 0 then
        if callback then callback(true, "未加入阵营") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end

    local myUid = clientCloud.userId
    local oldName = CloudManager._factionName
    local wasLeader = CloudManager._factionRole == "leader"
    local meta = CloudManager._factionMeta

    if wasLeader and meta then
        -- ── 盟主离开 ──
        local successor = _findSuccessor(meta, myUid)

        if successor then
            -- 有继任者: 转让盟主, 阵营存续
            -- 从成员列表移除自己
            local newMembers = {}
            for _, mid in ipairs(meta.members) do
                if mid ~= myUid then
                    table.insert(newMembers, mid)
                end
            end
            meta.members = newMembers
            meta.memberCount = #newMembers
            meta.leaderId = successor
            -- 更新角色: 继任者→leader, 移除旧盟主
            if not meta.roles then meta.roles = {} end
            meta.roles[tostring(myUid)] = nil
            meta.roles[tostring(successor)] = "leader"

            -- 清除本地状态
            CloudManager._factionId = 0
            CloudManager._factionName = ""
            CloudManager._factionRole = "none"

            -- 发布更新后的meta (旧盟主最后一次写入, 保留排行条目供阵营继续可见)
            clientCloud:BatchSet()
                :Set(KEYS.camp_meta, meta)
                :SetInt(KEYS.camp_resp_ts, 0)
                :Set(KEYS.camp_resp, {})
                :Save("盟主退位, 转让给" .. tostring(successor), {
                    ok = function()
                        print("[阵营] 盟主退出: " .. oldName
                            .. ", 转让给 " .. tostring(successor)
                            .. ", 剩余" .. meta.memberCount .. "人")
                        CloudManager._factionMeta = nil
                        CloudManager._campOutResp = {}
                        CloudManager._syncSocialDomain()
                        CloudManager.PublishProfile()
                        if callback then callback(true, "已退出, 盟主已转让") end
                    end,
                    error = function()
                        -- 回滚
                        CloudManager._factionId = meta.id
                        CloudManager._factionName = oldName
                        CloudManager._factionRole = "leader"
                        if callback then callback(false, "退出失败") end
                    end,
                })
        else
            -- 无继任者: 最后一人, 解散阵营
            CloudManager._factionId = 0
            CloudManager._factionName = ""
            CloudManager._factionRole = "none"

            clientCloud:BatchSet()
                :SetInt(KEYS.camp_leader_ts, 0)
                :Set(KEYS.camp_meta, {})
                :SetInt(KEYS.camp_resp_ts, 0)
                :Set(KEYS.camp_resp, {})
                :Save("解散阵营(最后一人)", {
                    ok = function()
                        print("[阵营] 最后一人离开, 阵营已解散: " .. oldName)
                        CloudManager._factionMeta = nil
                        CloudManager._campOutResp = {}
                        CloudManager._syncSocialDomain()
                        CloudManager.PublishProfile()
                        if callback then callback(true, "阵营已解散") end
                    end,
                    error = function()
                        if callback then callback(false, "解散失败") end
                    end,
                })
        end
    else
        -- ── 非盟主离开 ──
        -- 非盟主无法直接修改camp_meta(存在盟主的排行条目下)
        -- 只能清除本地状态; 盟主侧会通过成员活跃度检测到离开
        CloudManager._factionId = 0
        CloudManager._factionName = ""
        CloudManager._factionRole = "none"
        CloudManager._campOutApply = nil

        -- 清理自己的申请排行条目
        clientCloud:BatchSet()
            :SetInt(KEYS.camp_apply_ts, 0)
            :Set(KEYS.camp_apply, {})
            :Save("成员退出阵营", {
                ok = function()
                    print("[阵营] 已退出: " .. oldName)
                    CloudManager._syncSocialDomain()
                    CloudManager.PublishProfile()
                    if callback then callback(true, "已退出阵营") end
                end,
                error = function()
                    if callback then callback(false, "退出失败") end
                end,
            })
    end
end

-- ── 获取阵营成员列表 ──

--- 获取当前阵营成员档案
---@param callback fun(members: table[])
function CloudManager.GetFactionMembers(callback)
    if CloudManager._factionId == 0 then
        if callback then callback({}) end
        return
    end

    -- 如果是盟主, 直接用本地 meta
    if CloudManager._factionRole == "leader" and CloudManager._factionMeta then
        local memberIds = CloudManager._factionMeta.members or {}
        if #memberIds == 0 then
            if callback then callback({}) end
            return
        end

        --- 内部: 拿到全量 profiles 后, 过滤 + 校验离开 + 补查缺失成员
        local function _processMembers(profiles)
            local memberSet = {}
            for _, mid in ipairs(memberIds) do memberSet[mid] = true end
            local result = {}
            local profileMap = {}
            for _, p in ipairs(profiles) do
                profileMap[p.userId] = p
                if memberSet[p.userId] then table.insert(result, p) end
            end

            -- 找出排行榜中未出现的成员, 用 SearchPlayer 补查
            local missing = {}
            for _, mid in ipairs(memberIds) do
                if not profileMap[mid] then missing[#missing + 1] = mid end
            end

            -- 补查完成后执行验证清理
            local function _afterFetchMissing()
                -- 验证: 只清理 factionId>0 且 != myFid 的（明确加入了其他阵营）
                local myFid = CloudManager._factionId
                local myUid = clientCloud.userId
                local removed = {}
                for _, mid in ipairs(memberIds) do
                    if mid ~= myUid then
                        local mp = profileMap[mid]
                        if mp and mp.profile then
                            local theirFid = mp.profile.factionId
                            if theirFid and theirFid ~= 0 and theirFid ~= myFid then
                                removed[#removed + 1] = mid
                                print("[阵营] 检测到成员 " .. tostring(mid) .. " 已加入其他阵营(factionId=" .. tostring(theirFid) .. ")")
                            end
                        end
                        -- 注意: 找不到的成员(mp==nil)不清理, 可能是新成员还没发布profile
                    end
                end
                if #removed > 0 then
                    local meta = CloudManager._factionMeta
                    local removedSet = {}
                    for _, rid in ipairs(removed) do removedSet[rid] = true end
                    local newMembers = {}
                    for _, mid in ipairs(meta.members or {}) do
                        if not removedSet[mid] then newMembers[#newMembers + 1] = mid end
                    end
                    meta.members = newMembers
                    meta.memberCount = #newMembers
                    local cleanResult = {}
                    for _, r in ipairs(result) do
                        if not removedSet[r.userId] then cleanResult[#cleanResult + 1] = r end
                    end
                    result = cleanResult
                    clientCloud:BatchSet()
                        :Set(KEYS.camp_meta, meta)
                        :Save("盟主自动清理已离开成员", {
                            ok = function()
                                print("[阵营] 已自动清理 " .. #removed .. " 名离开成员, 剩余" .. meta.memberCount .. "人")
                            end,
                        })
                end
                if callback then callback(result) end
            end

            if #missing == 0 then
                _afterFetchMissing()
            else
                -- 逐个补查缺失成员
                local pending = #missing
                for _, mid in ipairs(missing) do
                    CloudManager.SearchPlayer(mid, function(found)
                        if found then
                            profileMap[found.userId] = found
                            table.insert(result, found)
                        end
                        pending = pending - 1
                        if pending <= 0 then _afterFetchMissing() end
                    end)
                end
            end
        end

        -- 先拉取 top-200 profiles, 覆盖大多数成员
        CloudManager.GetPublicProfiles(0, 200, function(profiles)
            _processMembers(profiles)
        end)
        return
    end

    -- 普通成员: 从盟主的 camp_meta 获取成员列表
    clientCloud:GetRankList(KEYS.camp_leader_ts, 0, 50, {
        ok = function(rankList)
            local memberIds = {}
            for _, item in ipairs(rankList) do
                local meta = item.score[KEYS.camp_meta]
                if type(meta) == "table" and meta.id == CloudManager._factionId then
                    memberIds = meta.members or {}
                    break
                end
            end
            if #memberIds == 0 then
                if callback then callback({}) end
                return
            end
            CloudManager.GetPublicProfiles(0, 100, function(profiles)
                local memberSet = {}
                for _, mid in ipairs(memberIds) do memberSet[mid] = true end
                local result = {}
                for _, p in ipairs(profiles) do
                    if memberSet[p.userId] then table.insert(result, p) end
                end
                if callback then callback(result) end
            end)
        end,
        error = function()
            if callback then callback({}) end
        end,
    }, KEYS.camp_meta)
end

--- 获取当前阵营信息
---@return table
function CloudManager.GetFactionInfo()
    return {
        id = CloudManager._factionId,
        name = CloudManager._factionName,
        role = CloudManager._factionRole,
        meta = CloudManager._factionMeta,
    }
end

-- ── 设置成员职位 (仿率土之滨) ──

--- 设置成员职位 (需要操作者权限高于目标当前职位和目标职位)
--- 有效职位: "vice_leader"(副盟主), "strategist"(军师), "vanguard"(先锋官),
---           "diplomat"(外交官), "elite"(精英), "member"(成员)
---@param targetUserId number 目标成员uid
---@param newRole string 新职位名称
---@param callback? fun(success: boolean, reason: string)
function CloudManager.SetMemberRole(targetUserId, newRole, callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "阵营数据未加载") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end

    local myUid = clientCloud.userId
    local myRole = CloudManager._factionRole
    if targetUserId == myUid then
        if callback then callback(false, "不能对自己操作") end
        return
    end

    -- 验证目标职位合法性
    if newRole == "leader" then
        if callback then callback(false, "盟主只能通过转让设置") end
        return
    end
    if not FACTION_ROLES[newRole] then
        if callback then callback(false, "无效的职位: " .. tostring(newRole)) end
        return
    end

    -- 检查目标是否在阵营中
    local isMember = false
    for _, mid in ipairs(meta.members or {}) do
        if mid == targetUserId then isMember = true; break end
    end
    if not isMember then
        if callback then callback(false, "对方不在阵营中") end
        return
    end

    if not meta.roles then meta.roles = {} end
    local targetUidStr = tostring(targetUserId)
    local oldRole = meta.roles[targetUidStr] or "member"

    -- 权限检查: 操作者必须比目标当前职位高, 也必须比目标新职位高
    if not _hasAuthorityOver(myRole, oldRole) then
        if callback then callback(false, "你的职位不够, 无法操作" .. _getRoleName(oldRole)) end
        return
    end
    if not _hasAuthorityOver(myRole, newRole) then
        if callback then callback(false, "你的职位不够, 无法授予" .. _getRoleName(newRole)) end
        return
    end

    -- 人数上限检查 (有限职位)
    local roleDef = FACTION_ROLES[newRole]
    if roleDef.max > 0 then
        local current = _countRole(meta.roles, newRole)
        -- 如果目标已经是这个职位, 不占额外名额
        if oldRole ~= newRole and current >= roleDef.max then
            if callback then callback(false, _getRoleName(newRole) .. "名额已满(上限" .. roleDef.max .. "人)") end
            return
        end
    end

    if oldRole == newRole then
        if callback then callback(true, "已经是" .. _getRoleName(newRole)) end
        return
    end

    meta.roles[targetUidStr] = newRole

    -- 发布更新
    clientCloud:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("设置职位", {
            ok = function()
                print("[阵营] " .. tostring(targetUserId) .. " "
                    .. _getRoleName(oldRole) .. "→" .. _getRoleName(newRole))
                if callback then callback(true, "已设为" .. _getRoleName(newRole)) end
            end,
            error = function(_, reason)
                -- 回滚
                meta.roles[targetUidStr] = oldRole
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

--- 兼容旧接口: 设置/取消副盟主
---@param targetUserId number
---@param setAsVice boolean
---@param callback? fun(success: boolean, reason: string)
function CloudManager.SetViceLeader(targetUserId, setAsVice, callback)
    CloudManager.SetMemberRole(targetUserId, setAsVice and "vice_leader" or "member", callback)
end

-- ── 阵营改名 (仅盟主) ──

---@param newName string
---@param callback? fun(success: boolean, reason: string)
function CloudManager.RenameFaction(newName, callback)
    if CloudManager._factionRole ~= "leader" then
        if callback then callback(false, "只有盟主才能改名") end
        return
    end
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "阵营数据未加载") end
        return
    end
    if not newName or #newName == 0 then
        if callback then callback(false, "名称不能为空") end
        return
    end
    if #newName > 24 then
        if callback then callback(false, "名称过长(最多8个汉字)") end
        return
    end
    local oldName = meta.name
    meta.name = newName
    CloudManager._factionName = newName

    clientCloud:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("阵营改名", {
            ok = function()
                print("[阵营] 改名成功: " .. tostring(oldName) .. " → " .. newName)
                if callback then callback(true, nil) end
            end,
            error = function(_, reason)
                meta.name = oldName
                CloudManager._factionName = oldName
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- ── 踢出成员 (副盟主及以上, 只能踢低于自己职位的) ──

--- 踢出指定成员
---@param targetUserId number
---@param callback? fun(success: boolean, reason: string)
function CloudManager.KickMember(targetUserId, callback)
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "阵营数据未加载") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end

    local myUid = clientCloud.userId
    local myRole = CloudManager._factionRole
    if targetUserId == myUid then
        if callback then callback(false, "不能踢自己, 请使用退出") end
        return
    end

    -- 操作权限: 副盟主及以上
    if _getRoleLevel(myRole) < _getRoleLevel("vice_leader") then
        if callback then callback(false, "副盟主及以上才能踢人") end
        return
    end

    -- 检查目标是否在阵营中
    local targetIdx = nil
    for i, mid in ipairs(meta.members or {}) do
        if mid == targetUserId then targetIdx = i; break end
    end
    if not targetIdx then
        if callback then callback(false, "对方不在阵营中") end
        return
    end

    if not meta.roles then meta.roles = {} end
    local targetUidStr = tostring(targetUserId)
    local targetRole = meta.roles[targetUidStr] or "member"

    -- 只能踢低于自己职位的
    if not _hasAuthorityOver(myRole, targetRole) then
        if callback then callback(false, "无法踢出" .. _getRoleName(targetRole) .. ", 职位不低于你") end
        return
    end

    -- 从成员列表移除
    local removedUid = table.remove(meta.members, targetIdx)
    meta.memberCount = #meta.members
    meta.roles[targetUidStr] = nil

    -- 发布更新
    clientCloud:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("踢出成员", {
            ok = function()
                print("[阵营] 踢出 " .. tostring(targetUserId) .. " (" .. _getRoleName(targetRole) .. ")"
                    .. ", 剩余" .. meta.memberCount .. "人")
                if callback then callback(true, "已踢出") end
            end,
            error = function(_, reason)
                -- 回滚
                table.insert(meta.members, targetIdx, removedUid)
                meta.memberCount = #meta.members
                meta.roles[targetUidStr] = targetRole
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- ── 转让盟主 ──

--- 盟主主动转让给指定成员
---@param targetUserId number
---@param callback? fun(success: boolean, reason: string)
function CloudManager.TransferLeadership(targetUserId, callback)
    if CloudManager._factionRole ~= "leader" then
        if callback then callback(false, "只有盟主才能转让") end
        return
    end
    local meta = CloudManager._factionMeta
    if not meta then
        if callback then callback(false, "阵营数据未加载") end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false, "云端不可用") end
        return
    end

    local myUid = clientCloud.userId
    if targetUserId == myUid then
        if callback then callback(false, "不能转让给自己") end
        return
    end

    -- 检查目标是否在阵营中
    local isMember = false
    for _, mid in ipairs(meta.members or {}) do
        if mid == targetUserId then isMember = true; break end
    end
    if not isMember then
        if callback then callback(false, "对方不在阵营中") end
        return
    end

    if not meta.roles then meta.roles = {} end
    local myUidStr = tostring(myUid)
    local targetUidStr = tostring(targetUserId)

    -- 转让: 自己降为成员, 目标升为盟主
    meta.leaderId = targetUserId
    meta.roles[myUidStr] = "member"
    meta.roles[targetUidStr] = "leader"

    CloudManager._factionRole = "member"

    clientCloud:BatchSet()
        :Set(KEYS.camp_meta, meta)
        :Save("转让盟主", {
            ok = function()
                print("[阵营] 盟主已转让给 " .. tostring(targetUserId))
                CloudManager._factionMeta = nil  -- 不再是盟主, 不持有meta
                CloudManager._syncSocialDomain()
                if callback then callback(true, "盟主已转让") end
            end,
            error = function(_, reason)
                -- 回滚
                meta.leaderId = myUid
                meta.roles[myUidStr] = "leader"
                meta.roles[targetUidStr] = meta.roles[targetUidStr]  -- 保持
                CloudManager._factionRole = "leader"
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- ── 继位检测: 新盟主上线后接管 ──

--- 刷新阵营状态 (登录时自动调用)
--- 检测当前玩家是否因盟主退出而被提升为新盟主, 如果是则重新发布 camp_meta
---@param callback? fun(transferred: boolean)
function CloudManager._refreshFactionStatus(callback)
    if CloudManager._factionId == 0 then
        if callback then callback(false) end
        return
    end
    if not rawget(_G, "clientCloud") then
        if callback then callback(false) end
        return
    end

    local myUid = clientCloud.userId
    local myCampId = CloudManager._factionId

    -- 从排行榜获取当前阵营的 meta
    clientCloud:GetRankList(KEYS.camp_leader_ts, 0, 100, {
        ok = function(rankList)
            local latestMeta = nil
            local latestTs = 0

            -- 找到自己阵营的最新meta (按campId去重, 保留最新时间戳)
            for _, item in ipairs(rankList) do
                local meta = item.score[KEYS.camp_meta]
                if type(meta) == "table" and meta.id == myCampId then
                    local ts = (item.iscore and item.iscore[KEYS.camp_leader_ts]) or 0
                    if ts > latestTs then
                        latestTs = ts
                        latestMeta = meta
                    end
                end
            end

            if not latestMeta then
                -- 阵营已不存在 (可能已解散)
                print("[阵营] 阵营已不存在, 清除本地状态")
                CloudManager._factionId = 0
                CloudManager._factionName = ""
                CloudManager._factionRole = "none"
                CloudManager._factionMeta = nil
                CloudManager._syncSocialDomain()
                if callback then callback(false) end
                return
            end

            -- 检查自己是否在成员列表中
            local inMembers = false
            for _, mid in ipairs(latestMeta.members or {}) do
                if mid == myUid then inMembers = true; break end
            end

            if not inMembers then
                -- 我已不在阵营中 (可能被踢)
                print("[阵营] 我已不在阵营成员中, 清除本地状态")
                CloudManager._factionId = 0
                CloudManager._factionName = ""
                CloudManager._factionRole = "none"
                CloudManager._factionMeta = nil
                CloudManager._syncSocialDomain()
                if callback then callback(false) end
                return
            end

            -- 同步阵营名称和meta
            CloudManager._factionName = latestMeta.name or CloudManager._factionName

            -- 关键: 检查 leaderId 是否是自己
            if latestMeta.leaderId == myUid then
                if CloudManager._factionRole ~= "leader" then
                    -- 我被提升为新盟主! 重新发布 camp_meta 到自己的排行条目
                    print("[阵营] 检测到盟主继位! 重新发布 camp_meta")
                    CloudManager._factionRole = "leader"
                    CloudManager._factionMeta = latestMeta

                    clientCloud:BatchSet()
                        :SetInt(KEYS.camp_leader_ts, os.time())
                        :Set(KEYS.camp_meta, latestMeta)
                        :Save("新盟主接管阵营", {
                            ok = function()
                                print("[阵营] 新盟主接管完成: " .. (latestMeta.name or ""))
                                CloudManager._syncSocialDomain()
                                CloudManager.PublishProfile()
                                if callback then callback(true) end
                            end,
                            error = function()
                                print("[阵营] 接管发布失败, 下次登录重试")
                                if callback then callback(false) end
                            end,
                        })
                    return
                else
                    -- 已经是盟主, 更新meta缓存
                    CloudManager._factionMeta = latestMeta
                end
            else
                -- 非盟主: 更新角色, 保留meta供UI显示(盟主名/人数等)
                local roles = latestMeta.roles or {}
                local myRole = roles[tostring(myUid)] or "member"
                CloudManager._factionRole = myRole
                CloudManager._factionMeta = latestMeta
            end

            if callback then callback(false) end
        end,
        error = function(_, reason)
            print("[阵营] 刷新阵营状态失败: " .. tostring(reason))
            if callback then callback(false) end
        end,
    }, KEYS.camp_meta)
end
