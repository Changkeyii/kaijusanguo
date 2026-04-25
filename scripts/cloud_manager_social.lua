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

local function _getRankItemUserId(item)
    if rawget(_G, "ResolveRankListUserId") then
        return ResolveRankListUserId(item)
    end
    return tonumber(item and (item.userId or item.player or item.uid)) or 0
end

-- ============================================================================
-- 公开档案
-- ============================================================================

--- 发布公开档案 (自动从全局变量提取, 有频率限制)
function CloudManager._publishProfile(allData)
    if not CloudAPI.IsAvailable() then return end
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

    -- 装备武技 (聚合所有武将的武技)
    if rawget(_G, "GetAllEquippedSkills") then
        for _, skillIdx in ipairs(GetAllEquippedSkills()) do
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
    CloudAPI:BatchSet()
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
    if not CloudAPI.IsAvailable() then
        if callback then callback({}) end
        return
    end

    CloudAPI:GetRankList(KEYS.combat_power, start, count, {
        ok = function(rankList)
            local profiles = {}
            local userIds = {}

            for i, item in ipairs(rankList) do
                local profile = item.score[KEYS.pub_profile] or {}
                local uid = _getRankItemUserId(item)
                local entry = {
                    rank = start + i,
                    userId = uid,
                    combatPower = (item.iscore and item.iscore[KEYS.combat_power]) or 0,
                    realmLevel = (item.iscore and item.iscore[KEYS.realm_level]) or 1,
                    profile = profile,
                    nickname = "",
                    isMe = uid == CloudAPI.GetUserId(),
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
-- 子模块加载
-- ============================================================================
require "cloud_manager_friends"
require "cloud_manager_faction"
