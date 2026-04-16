-- ============================================================================
-- EquipActions.lua - 服务端装备验证 Actions
-- 职责：装备强化、分解等关键操作的服务端验证
-- 操作：enhance_equip, decompose_equip, batch_decompose
-- ============================================================================

local Protocol = require("network.Protocol")
local CODE = Protocol.CODE
local GameActions = require("server.GameActions")
local PlayerDataManager = require("server.PlayerDataManager")

-- ============================================================================
-- 装备强化（消耗军资，修改装备数据）
-- ============================================================================
GameActions.Register("enhance_equip", {
    rateLimit = { maxCount = 10, windowSec = 1 },
    needDomains = { "core", "equip" },
    handler = function(userId, params, replyFn)
        local uid = tonumber(params.uid) -- 装备唯一ID
        local cost = tonumber(params.cost)

        if not uid or not cost or cost <= 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "参数缺失")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 验证军资余额
        local currentLingshi = cache.money.lingshi or 0
        if currentLingshi < cost then
            replyFn(false, CODE.ERR_INSUFFICIENT, nil,
                "军资不足: 需要" .. cost .. " 当前" .. currentLingshi)
            return
        end

        -- 验证装备存在
        local equipDomain = cache.domains.equip
        if not equipDomain or not equipDomain.playerEquipment then
            replyFn(false, CODE.ERR_PARAMS, nil, "装备数据不存在")
            return
        end

        local owned = equipDomain.playerEquipment.owned
        if not owned then
            replyFn(false, CODE.ERR_PARAMS, nil, "背包数据不存在")
            return
        end

        -- 查找装备
        local targetEquip = nil
        for _, eq in pairs(owned) do
            if eq.uid == uid then
                targetEquip = eq
                break
            end
        end

        if not targetEquip then
            replyFn(false, CODE.ERR_PARAMS, nil, "装备不存在: uid=" .. uid)
            return
        end

        -- 强化等级上限验证
        local maxLevel = 20
        local currentLv = targetEquip.enhanceLv or 0
        if currentLv >= maxLevel then
            replyFn(false, CODE.ERR_PARAMS, nil, "装备已达最大强化等级")
            return
        end

        -- 扣款 + 强化
        cache.money.lingshi = currentLingshi - cost
        targetEquip.enhanceLv = currentLv + 1

        -- 同步到 playerInfo
        if cache.domains.core and cache.domains.core.playerInfo then
            cache.domains.core.playerInfo.lingshi = cache.money.lingshi
            cache.domains.core.playerInfo.totalEnhance =
                (cache.domains.core.playerInfo.totalEnhance or 0) + 1
        end

        cache.dirty.core = true
        cache.dirty.equip = true

        PlayerDataManager.LogOp(userId, "enhance_equip",
            { uid = uid, cost = cost, newLv = currentLv + 1 })

        replyFn(true, nil, {
            lingshi = cache.money.lingshi,
            uid = uid,
            enhanceLv = currentLv + 1,
        })
    end,
})

-- ============================================================================
-- 分解装备（获得军资，移除装备）
-- ============================================================================
GameActions.Register("decompose_equip", {
    rateLimit = { maxCount = 10, windowSec = 1 },
    needDomains = { "core", "equip" },
    handler = function(userId, params, replyFn)
        local uid = tonumber(params.uid)
        local expectedGain = tonumber(params.gain) or 0

        if not uid then
            replyFn(false, CODE.ERR_PARAMS, nil, "缺少装备uid")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        local equipDomain = cache.domains.equip
        if not equipDomain or not equipDomain.playerEquipment
            or not equipDomain.playerEquipment.owned then
            replyFn(false, CODE.ERR_PARAMS, nil, "装备数据不存在")
            return
        end

        local owned = equipDomain.playerEquipment.owned

        -- 查找并移除装备
        local removed = false
        local gain = 0
        for i, eq in pairs(owned) do
            if eq.uid == uid then
                -- 计算分解产出（服务端按自己的规则计算，不信任客户端）
                local tierGain = { 10, 30, 80, 200, 500 }
                local tier = eq.tier or 1
                gain = tierGain[tier] or 10
                -- 强化等级额外返还
                gain = gain + (eq.enhanceLv or 0) * 5

                owned[i] = nil
                removed = true
                break
            end
        end

        if not removed then
            replyFn(false, CODE.ERR_PARAMS, nil, "装备不存在: uid=" .. uid)
            return
        end

        -- 发放军资
        cache.money.lingshi = (cache.money.lingshi or 0) + gain
        if cache.domains.core and cache.domains.core.playerInfo then
            cache.domains.core.playerInfo.lingshi = cache.money.lingshi
            cache.domains.core.playerInfo.totalDecompose =
                (cache.domains.core.playerInfo.totalDecompose or 0) + 1
        end

        cache.dirty.core = true
        cache.dirty.equip = true

        PlayerDataManager.LogOp(userId, "decompose_equip",
            { uid = uid, gain = gain })

        replyFn(true, nil, {
            lingshi = cache.money.lingshi,
            removedUid = uid,
            gain = gain,
        })
    end,
})

-- ============================================================================
-- 批量分解装备
-- ============================================================================
GameActions.Register("batch_decompose", {
    rateLimit = { maxCount = 2, windowSec = 5 },
    needDomains = { "core", "equip" },
    handler = function(userId, params, replyFn)
        local uids = params.uids -- 数组: { uid1, uid2, ... }

        if not uids or type(uids) ~= "table" or #uids == 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "缺少装备列表")
            return
        end

        if #uids > 100 then
            replyFn(false, CODE.ERR_PARAMS, nil, "一次最多分解100件")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        local equipDomain = cache.domains.equip
        if not equipDomain or not equipDomain.playerEquipment
            or not equipDomain.playerEquipment.owned then
            replyFn(false, CODE.ERR_PARAMS, nil, "装备数据不存在")
            return
        end

        local owned = equipDomain.playerEquipment.owned
        local totalGain = 0
        local removedCount = 0
        local uidSet = {}
        for _, u in ipairs(uids) do uidSet[tonumber(u)] = true end

        -- 遍历并移除匹配的装备
        local tierGain = { 10, 30, 80, 200, 500 }
        for i, eq in pairs(owned) do
            if uidSet[eq.uid] then
                local tier = eq.tier or 1
                local gain = tierGain[tier] or 10
                gain = gain + (eq.enhanceLv or 0) * 5
                totalGain = totalGain + gain
                owned[i] = nil
                removedCount = removedCount + 1
            end
        end

        if removedCount == 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "未找到可分解的装备")
            return
        end

        cache.money.lingshi = (cache.money.lingshi or 0) + totalGain
        if cache.domains.core and cache.domains.core.playerInfo then
            cache.domains.core.playerInfo.lingshi = cache.money.lingshi
            cache.domains.core.playerInfo.totalDecompose =
                (cache.domains.core.playerInfo.totalDecompose or 0) + removedCount
        end

        cache.dirty.core = true
        cache.dirty.equip = true

        PlayerDataManager.LogOp(userId, "batch_decompose",
            { count = removedCount, totalGain = totalGain })

        replyFn(true, nil, {
            lingshi = cache.money.lingshi,
            removedCount = removedCount,
            totalGain = totalGain,
        })
    end,
})

print("[EquipActions] 已注册: enhance_equip, decompose_equip, batch_decompose")
