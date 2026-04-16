-- ============================================================================
-- HeroActions.lua - 服务端英雄验证 Actions
-- 职责：英雄升级、碎片合成等关键操作的服务端验证
-- 操作：level_up_hero, compose_hero
-- ============================================================================

local Protocol = require("network.Protocol")
local CODE = Protocol.CODE
local GameActions = require("server.GameActions")
local PlayerDataManager = require("server.PlayerDataManager")

-- ============================================================================
-- 英雄升级（消耗经验值）
-- ============================================================================
GameActions.Register("level_up_hero", {
    rateLimit = { maxCount = 10, windowSec = 1 },
    needDomains = { "core", "heroes" },
    handler = function(userId, params, replyFn)
        local cardIdx = tonumber(params.cardIdx)
        local expCost = tonumber(params.expCost) or 0

        if not cardIdx then
            replyFn(false, CODE.ERR_PARAMS, nil, "缺少英雄索引")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        -- 验证英雄存在
        local heroesDomain = cache.domains.heroes
        if not heroesDomain or not heroesDomain.playerHeroes then
            replyFn(false, CODE.ERR_PARAMS, nil, "英雄数据不存在")
            return
        end

        local hero = heroesDomain.playerHeroes[cardIdx]
            or heroesDomain.playerHeroes[tostring(cardIdx)]
        if not hero then
            replyFn(false, CODE.ERR_PARAMS, nil, "英雄不存在: " .. cardIdx)
            return
        end

        if not hero.owned then
            replyFn(false, CODE.ERR_PARAMS, nil, "英雄未拥有")
            return
        end

        -- 验证等级上限
        local maxLevel = 100
        local currentLevel = hero.level or 1
        if currentLevel >= maxLevel then
            replyFn(false, CODE.ERR_PARAMS, nil, "英雄已达最高等级")
            return
        end

        -- 验证经验值（从 core domain 的 playerInfo 获取）
        local coreDomain = cache.domains.core
        if not coreDomain or not coreDomain.playerInfo then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "核心数据未加载")
            return
        end

        local playerExp = coreDomain.playerInfo.exp or 0
        if expCost > 0 and playerExp < expCost then
            replyFn(false, CODE.ERR_INSUFFICIENT, nil,
                "经验不足: 需要" .. expCost .. " 当前" .. playerExp)
            return
        end

        -- 执行升级
        hero.level = currentLevel + 1
        if expCost > 0 then
            coreDomain.playerInfo.exp = playerExp - expCost
        end

        cache.dirty.heroes = true
        cache.dirty.core = true

        PlayerDataManager.LogOp(userId, "level_up_hero",
            { cardIdx = cardIdx, newLevel = hero.level, expCost = expCost })

        replyFn(true, nil, {
            cardIdx = cardIdx,
            newLevel = hero.level,
            exp = coreDomain.playerInfo.exp,
        })
    end,
})

-- ============================================================================
-- 碎片合成英雄
-- ============================================================================
GameActions.Register("compose_hero", {
    rateLimit = { maxCount = 5, windowSec = 1 },
    needDomains = { "core", "heroes" },
    handler = function(userId, params, replyFn)
        local cardIdx = tonumber(params.cardIdx)
        local fragCost = tonumber(params.fragCost) or 0

        if not cardIdx or fragCost <= 0 then
            replyFn(false, CODE.ERR_PARAMS, nil, "参数缺失")
            return
        end

        local cache = PlayerDataManager.GetCache(userId)
        if not cache then
            replyFn(false, CODE.ERR_NOT_FOUND, nil, "数据未加载")
            return
        end

        local heroesDomain = cache.domains.heroes
        if not heroesDomain or not heroesDomain.playerHeroes then
            replyFn(false, CODE.ERR_PARAMS, nil, "英雄数据不存在")
            return
        end

        -- 验证碎片
        local fragments = heroesDomain.heroFragments or {}
        local currentFrags = fragments[cardIdx]
            or fragments[tostring(cardIdx)] or 0
        if currentFrags < fragCost then
            replyFn(false, CODE.ERR_INSUFFICIENT, nil,
                "碎片不足: 需要" .. fragCost .. " 当前" .. currentFrags)
            return
        end

        -- 检查是否已拥有
        local hero = heroesDomain.playerHeroes[cardIdx]
            or heroesDomain.playerHeroes[tostring(cardIdx)]

        if hero and hero.owned then
            -- 已拥有 → 增加命座
            local maxConstellation = 6
            local currentConst = hero.constellation or 0
            if currentConst >= maxConstellation then
                replyFn(false, CODE.ERR_PARAMS, nil, "英雄命座已满")
                return
            end
            hero.constellation = currentConst + 1
        else
            -- 未拥有 → 解锁
            heroesDomain.playerHeroes[cardIdx] = {
                owned = true,
                level = 1,
                constellation = 0,
            }
        end

        -- 扣除碎片
        if heroesDomain.heroFragments then
            heroesDomain.heroFragments[cardIdx] = currentFrags - fragCost
        end

        cache.dirty.heroes = true

        PlayerDataManager.LogOp(userId, "compose_hero",
            { cardIdx = cardIdx, fragCost = fragCost })

        replyFn(true, nil, {
            cardIdx = cardIdx,
            owned = true,
        })
    end,
})

print("[HeroActions] 已注册: level_up_hero, compose_hero")
