-- ============================================================================
-- systems/td/td_logic.lua - 塔防模式核心逻辑 (纯塔防重构版)
-- 用途: 敌人移动、武将直接攻击、能量/技能系统、波次管理、胜负判定
-- 适配: 像素坐标固定路径 + 固定塔位系统
-- ============================================================================
---@diagnostic disable: undefined-global

local TDData = require("systems.td.td_data")

local M = {}

-- ============================================================================
-- TD 专属音效路径
-- ============================================================================
local TD_SFX = {
    deploy       = "audio/sfx/td_deploy.ogg",
    wave         = "audio/sfx/td_enemy_wave.ogg",
    arrow        = "audio/sfx/td_arrow_shot.ogg",
    swordClash   = "audio/sfx/td_sword_clash.ogg",
    skillActivate= "audio/sfx/td_skill_activate.ogg",
    enemyDeath   = "audio/sfx/td_enemy_death.ogg",
    levelClear   = "audio/sfx/td_level_clear.ogg",
    baseHit      = "audio/sfx/td_base_hit.ogg",
    heroRanged   = "audio/sfx/td_hero_ranged.ogg",
    heroMelee    = "audio/sfx/td_hero_melee.ogg",
    heroDeath    = "audio/sfx/td_hero_death.ogg",
    heroRevive   = "audio/sfx/td_hero_revive.ogg",
    upgrade      = "audio/sfx/td_upgrade.ogg",
    skillFire    = "audio/sfx/td_skill_fire.ogg",
    skillFrost   = "audio/sfx/td_skill_frost.ogg",
    skillHeal    = "audio/sfx/td_skill_heal.ogg",
    skillThunder = "audio/sfx/td_skill_thunder.ogg",
}
M.TD_SFX = TD_SFX  -- 暴露给其他模块使用

-- ============================================================================
-- 工具函数
-- ============================================================================

local function dist2D(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local MAX_FLOAT_TEXTS = 20

local function addFloat(text, x, y, color)
    if not tdState then return end
    if #tdState.floatTexts >= MAX_FLOAT_TEXTS then return end
    tdState.floatTexts[#tdState.floatTexts + 1] = {
        text = text, x = x, y = y, timer = 0, duration = 1.2,
        color = color or {255, 255, 255},
    }
end

--- 添加技能特效
local function addSkillFX(kind, cx, cy, radius, color, techIdx)
    if not tdState then return end
    tdState.skillFXList = tdState.skillFXList or {}

    local iconIdx = nil
    local fxData = nil
    if techIdx and SKILL_TECHNIQUES and SKILL_TECHNIQUES[techIdx] then
        iconIdx = SKILL_TECHNIQUES[techIdx].iconIdx
        if iconIdx and SKILL_FX_SHEETS then
            fxData = SKILL_FX_SHEETS[iconIdx]
        end
    end

    local duration = 0.8
    local fps = 14
    local totalFrames = 16
    if fxData and fxData.frames and fxData.fps then
        totalFrames = fxData.frames
        fps = fxData.fps
        duration = totalFrames / fps
    end

    tdState.skillFXList[#tdState.skillFXList + 1] = {
        kind = kind,
        cx = cx, cy = cy,
        radius = radius or 60,
        color = color or {255, 180, 80},
        timer = 0,
        duration = duration,
        techIdx = techIdx,
        iconIdx = iconIdx,
        frameIdx = 0,
        fps = fps,
        totalFrames = totalFrames,
        angle = (kind == "melee") and (math.random() * math.pi * 2) or 0,
    }
end

-- ============================================================================
-- 空间哈希 (性能优化: 100+敌人时快速查找)
-- ============================================================================
local HASH_CELL = 80
local spatialHash = {}

local function hashKey(x, y)
    local cx = math.floor(x / HASH_CELL)
    local cy = math.floor(y / HASH_CELL)
    return cx * 10000 + cy
end

local function rebuildSpatialHash()
    spatialHash = {}
    if not tdState then return end
    for i, enemy in ipairs(tdState.enemies) do
        if not enemy.dead then
            local k = hashKey(enemy.x, enemy.y)
            if not spatialHash[k] then spatialHash[k] = {} end
            spatialHash[k][#spatialHash[k] + 1] = i
        end
    end
end

--- 在空间哈希中查找范围内的敌人索引
local function queryNearby(x, y, range)
    local results = {}
    local cellRange = math.ceil(range / HASH_CELL)
    local cx0 = math.floor(x / HASH_CELL)
    local cy0 = math.floor(y / HASH_CELL)
    for dx = -cellRange, cellRange do
        for dy = -cellRange, cellRange do
            local k = (cx0 + dx) * 10000 + (cy0 + dy)
            local bucket = spatialHash[k]
            if bucket then
                for _, idx in ipairs(bucket) do
                    results[#results + 1] = idx
                end
            end
        end
    end
    return results
end

-- ============================================================================
-- 初始化 TD 状态 (新路径系统)
-- ============================================================================

function M.InitPathData()
    local st = tdState
    if not st then return end

    st.smoothPath = TDData.GenerateSmoothPath()
    st.pathLength = TDData.GetPathLength(st.smoothPath)

    st.path = {}
    for _, a in ipairs(TDData.PATH_ANCHORS) do
        st.path[#st.path + 1] = { x = a.x, y = a.y }
    end

    st.placeable = {}
    st.placedHeroMap = {}
    for _, slot in ipairs(TDData.TOWER_SLOTS) do
        st.placeable[slot.key] = true
    end
end

-- ============================================================================
-- 放置武将 (使用固定塔位 key)
-- ============================================================================

function M.PlaceHero(rosterIdx, slotKey)
    local st = tdState
    if not st then return false end

    local cardIdx = st.roster[rosterIdx]
    if not cardIdx then return false end
    local card = HERO_CARDS[cardIdx]
    if not card then return false end

    local cost = TDData.HERO_COST[card.quality] or 200
    if st.gold < cost then
        addFloat("军资不足!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, {255, 80, 80})
        return false
    end

    if not st.placeable[slotKey] then return false end
    if st.placedHeroMap[slotKey] then
        addFloat("已有武将!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, {255, 200, 80})
        return false
    end

    local sx, sy = TDData.GetSlotPosition(slotKey)
    if not sx then return false end

    st.gold = st.gold - cost

    local tdStats = TDData.GetHeroTDStats(card)

    local hero = {
        cardIdx = cardIdx,
        rosterIdx = rosterIdx,
        card = card,
        slotKey = slotKey,
        x = sx,
        y = sy,
        tdStats = tdStats,
        atkTimer = 0,
        -- 纯塔防: 新增字段
        currentHP = tdStats.maxHP,
        maxHP = tdStats.maxHP,
        level = 1,
        dead = false,
        respawnTimer = 0,
    }

    st.heroes[#st.heroes + 1] = hero
    st.placedHeroMap[slotKey] = #st.heroes

    addFloat("-" .. cost .. "军资", sx, sy - 20, {255, 220, 100})

    if PlaySFX then PlaySFX(TD_SFX.deploy) end

    return true
end

-- ============================================================================
-- 武将重定位
-- ============================================================================

function M.RelocateHero(heroIdx, newSlotKey)
    local st = tdState
    if not st then return false end
    local hero = st.heroes[heroIdx]
    if not hero then return false end
    if not st.placeable[newSlotKey] then return false end
    if st.placedHeroMap[newSlotKey] then return false end

    -- 释放旧位置
    st.placedHeroMap[hero.slotKey] = nil
    -- 新位置
    local sx, sy = TDData.GetSlotPosition(newSlotKey)
    if not sx then return false end

    hero.slotKey = newSlotKey
    hero.x = sx
    hero.y = sy
    st.placedHeroMap[newSlotKey] = heroIdx

    addFloat("移动!", sx, sy - 20, {200, 220, 255})
    return true
end

-- ============================================================================
-- 武将升级
-- ============================================================================

function M.UpgradeHero(heroIdx)
    local st = tdState
    if not st then return false end
    local hero = st.heroes[heroIdx]
    if not hero then return false end

    local curLv = hero.level
    if curLv >= 5 then
        addFloat("已满级!", hero.x, hero.y - 20, {255, 200, 80})
        return false
    end

    local cost = TDData.UPGRADE_COST[curLv]
    if not cost then return false end
    if st.gold < cost then
        addFloat("军资不足!", hero.x, hero.y - 20, {255, 80, 80})
        return false
    end

    st.gold = st.gold - cost
    hero.level = curLv + 1

    -- 重新计算属性 (基础属性 × 升级倍率)
    local baseTD = TDData.GetHeroTDStats(hero.card)
    local mult = TDData.UPGRADE_MULT[hero.level]
    hero.tdStats.atk = math.floor(baseTD.atk * mult)
    hero.tdStats.def = math.floor(baseTD.def * mult)
    hero.tdStats.hp  = math.floor(baseTD.hp  * mult)
    hero.tdStats.maxHP = hero.tdStats.hp
    hero.maxHP = hero.tdStats.maxHP
    hero.currentHP = hero.maxHP  -- 升级回满血

    addFloat("升级 Lv" .. hero.level .. "!", hero.x, hero.y - 25, {255, 220, 80})
    addSkillFX("buff", hero.x, hero.y, 40, {255, 220, 80}, nil)
    if PlaySFX then PlaySFX(TD_SFX.upgrade) end

    return true
end

-- ============================================================================
-- 开始波次
-- ============================================================================

function M.StartNextWave()
    local st = tdState
    if not st then return end

    st.currentWave = st.currentWave + 1
    if st.currentWave > #st.waves then
        st.phase = "LEVEL_CLEAR"
        return
    end

    local wave = st.waves[st.currentWave]
    st.spawnQueue = {}
    for i, e in ipairs(wave.enemies) do
        st.spawnQueue[i] = {
            troop = e.troop,
            hp = e.hp,
            maxHP = e.maxHp or e.hp,
            atk = e.atk,
            def = e.def,
            speed = e.speed,
            elite = e.elite,
            canRangeAtk = e.canRangeAtk,
            atkRange = e.atkRange,
            atkCd = e.atkCd,
        }
    end
    st.waveEnemiesAlive = #st.spawnQueue
    st.spawnTimer = 0
    st.phase = "PLAYING"

    addFloat("第 " .. st.currentWave .. " 波!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2 - 30, {255, 200, 80})
    if PlaySFX then PlaySFX(TD_SFX.wave) end
end

-- ============================================================================
-- 主更新循环
-- ============================================================================

function M.Update(dt)
    local st = tdState
    if not st or st.paused then return end

    local spd = st.speed or 1
    dt = dt * spd
    st.gameTime = st.gameTime + dt

    M.UpdateFloatTexts(dt)
    M.UpdateSkillFX(dt)

    if st.phase == "PREPARE" then
        st.prepareTimer = st.prepareTimer + dt
        if st.autoBattle and st.prepareTimer > 2 then
            M.AutoPlaceHeroes()
            M.StartNextWave()
        end
        return
    end

    if st.phase == "LEVEL_CLEAR" then
        st.prepareTimer = (st.prepareTimer or 0) + dt
        if st.prepareTimer > 1.5 then
            local TDReward = require("systems.td.td_reward")
            if not TDReward.IsActive() then
                TDReward.Start(st.level)
            end
            TDReward.Update(dt)
        end
        return
    end

    if st.phase == "GAME_OVER" then return end
    if st.phase ~= "PLAYING" and st.phase ~= "WAVE_CLEAR" then return end

    -- 被动军资
    st.goldTimer = st.goldTimer + dt
    if st.goldTimer >= TDData.PASSIVE_GOLD_INTERVAL then
        st.goldTimer = st.goldTimer - TDData.PASSIVE_GOLD_INTERVAL
        st.gold = st.gold + TDData.PASSIVE_GOLD_RATE
    end

    -- 被动能量
    st.totalEnergy = math.min(TDData.ENERGY_MAX, st.totalEnergy + TDData.ENERGY_PASSIVE * dt)

    -- 技能CD递减
    for i = 1, #st.skills do
        if st.skills[i].cdTimer > 0 then
            st.skills[i].cdTimer = st.skills[i].cdTimer - dt
            if st.skills[i].cdTimer < 0 then st.skills[i].cdTimer = 0 end
        end
    end

    -- 重建空间哈希
    rebuildSpatialHash()

    M.UpdateSpawning(dt)
    M.UpdateEnemies(dt)
    M.UpdateHeroes(dt)
    M.UpdateEnemyAttackHeroes(dt)
    M.UpdateHeroDeath(dt)
    -- 旧的 UpdateSwordCD 已移除，飞剑改为通过技能栏释放
    M.UpdateFlyingSwords(dt)
    M.UpdateProjectiles(dt)
    M.CleanupDead()

    -- 检查波次完成
    if st.phase == "PLAYING" and #st.spawnQueue == 0 and st.waveEnemiesAlive <= 0 then
        if st.currentWave >= #st.waves then
            st.phase = "LEVEL_CLEAR"
            st.prepareTimer = 0
            addFloat("关卡通过!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, {255, 220, 80})
            local jadeReward = 50 + st.level * 20
            if playerInfo then
                playerInfo.jade = (playerInfo.jade or 0) + jadeReward
            end
            addFloat("+" .. jadeReward .. " 玉璧", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2 + 30, {120, 220, 255})
            if PlaySFX then PlaySFX(TD_SFX.levelClear) end
        else
            st.phase = "WAVE_CLEAR"
            st.waveTimer = 0
            st.gold = st.gold + TDData.WAVE_BONUS_GOLD
            addFloat("+" .. TDData.WAVE_BONUS_GOLD .. "军资", TDData.DESIGN_W / 2, 100, {255, 220, 100})
        end
    end

    -- 波次无缝衔接
    if st.phase == "WAVE_CLEAR" then
        M.StartNextWave()
    end

    if st.autoBattle then
        M.AutoBattleTick(dt)
    end
end

-- ============================================================================
-- 敌人生成
-- ============================================================================

function M.UpdateSpawning(dt)
    local st = tdState
    if #st.spawnQueue == 0 then return end

    st.spawnTimer = st.spawnTimer + dt
    if st.spawnTimer >= TDData.SPAWN_INTERVAL then
        st.spawnTimer = st.spawnTimer - TDData.SPAWN_INTERVAL

        local template = table.remove(st.spawnQueue, 1)
        if template then
            local startPt = st.smoothPath[1]
            local enemy = {
                troop = template.troop,
                hp = template.hp,
                maxHP = template.maxHP,
                atk = template.atk,
                def = template.def,
                speed = template.speed,
                elite = template.elite,
                travelDist = 0,
                x = startPt.x,
                y = startPt.y,
                dead = false,
                slowTimer = 0,
                slowFactor = 1.0,
                stunTimer = 0,
                swayPhase = math.random() * math.pi * 2,
                swayAmp = 2.5 + math.random() * 1.5,
                -- 弓兵攻击属性
                canRangeAtk = template.canRangeAtk,
                atkRange = template.atkRange,
                atkCd = template.atkCd,
                atkTimer = 0,
            }
            st.enemies[#st.enemies + 1] = enemy
        end
    end
end

-- ============================================================================
-- 敌人移动
-- ============================================================================

function M.UpdateEnemies(dt)
    local st = tdState
    for _, enemy in ipairs(st.enemies) do
        if not enemy.dead then
            -- 眩晕: 不移动不攻击
            if enemy.stunTimer and enemy.stunTimer > 0 then
                enemy.stunTimer = enemy.stunTimer - dt
                if enemy.stunTimer < 0 then enemy.stunTimer = 0 end
                -- 眩晕中跳过移动
            else
                -- 减速效果衰减
                if enemy.slowTimer > 0 then
                    enemy.slowTimer = enemy.slowTimer - dt
                    if enemy.slowTimer <= 0 then
                        enemy.slowFactor = 1.0
                    end
                end

                local speed = enemy.speed * enemy.slowFactor
                enemy.travelDist = enemy.travelDist + speed * dt

                local px, py, arrived = TDData.GetPositionOnPath(st.smoothPath, enemy.travelDist)
                enemy.x = px
                enemy.y = py

                if arrived then
                    local dmg = 1 + (enemy.elite and 2 or 0)
                    st.baseHP = st.baseHP - dmg
                    enemy.dead = true
                    st.waveEnemiesAlive = st.waveEnemiesAlive - 1
                    if PlaySFX then PlaySFX(TD_SFX.baseHit) end

                    if st.baseHP <= 0 then
                        st.baseHP = 0
                        st.phase = "GAME_OVER"
                        addFloat("基地陷落!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, {255, 60, 60})
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 武将直接攻击 (纯塔防: 远程弹道 / 近战斩击)
-- ============================================================================

function M.UpdateHeroes(dt)
    local st = tdState
    for _, hero in ipairs(st.heroes) do
        if hero.dead then goto continue end

        local stats = hero.tdStats
        hero.atkTimer = hero.atkTimer + dt

        if hero.atkTimer >= stats.atkCd then
            -- 使用空间哈希查找范围内敌人
            local nearbyIdxs = queryNearby(hero.x, hero.y, stats.atkRange)
            local bestEnemy = nil
            local bestDist = stats.atkRange + 1

            for _, idx in ipairs(nearbyIdxs) do
                local enemy = st.enemies[idx]
                if enemy and not enemy.dead then
                    local d = dist2D(hero.x, hero.y, enemy.x, enemy.y)
                    if d <= stats.atkRange and d < bestDist then
                        bestEnemy = enemy
                        bestDist = d
                    end
                end
            end

            if bestEnemy then
                hero.atkTimer = 0

                if stats.isRanged then
                    -- 远程: 生成箭矢弹道
                    st.projectiles[#st.projectiles + 1] = {
                        sx = hero.x, sy = hero.y,
                        tx = bestEnemy.x, ty = bestEnemy.y,
                        timer = 0, duration = 0.3,
                        kind = "arrow",
                        dmg = stats.atk,
                        targetRef = bestEnemy,
                        heroRef = hero,
                    }
                    if PlaySFX then PlaySFX(TD_SFX.heroRanged) end
                else
                    -- 近战: 即时伤害 + 扇形斩击特效
                    M.DealDamage(bestEnemy, stats.atk, hero)
                    addSkillFX("melee", hero.x, hero.y, stats.atkRange, {255, 255, 240}, nil)
                    if PlaySFX then PlaySFX(TD_SFX.heroMelee) end
                end
            end
        end

        ::continue::
    end
end

-- ============================================================================
-- 敌人攻击武将
-- ============================================================================

function M.UpdateEnemyAttackHeroes(dt)
    local st = tdState
    for _, enemy in ipairs(st.enemies) do
        if enemy.dead then goto nextEnemy end
        if enemy.stunTimer and enemy.stunTimer > 0 then goto nextEnemy end

        -- 弓兵远程攻击武将
        if enemy.canRangeAtk and enemy.atkRange then
            enemy.atkTimer = (enemy.atkTimer or 0) + dt
            if enemy.atkTimer >= (enemy.atkCd or 2.0) then
                -- 找最近的活着的武将
                local bestHero, bestD = nil, (enemy.atkRange or 100) + 1
                for _, hero in ipairs(st.heroes) do
                    if not hero.dead then
                        local d = dist2D(enemy.x, enemy.y, hero.x, hero.y)
                        if d <= (enemy.atkRange or 100) and d < bestD then
                            bestHero = hero
                            bestD = d
                        end
                    end
                end
                if bestHero then
                    enemy.atkTimer = 0
                    local dmg = math.max(1, enemy.atk - bestHero.tdStats.def * 0.3)
                    bestHero.currentHP = bestHero.currentHP - dmg
                end
            end
        else
            -- 近战敌人: 接触伤害 (dist<35)
            for _, hero in ipairs(st.heroes) do
                if not hero.dead then
                    local d = dist2D(enemy.x, enemy.y, hero.x, hero.y)
                    if d < 35 then
                        local dmg = enemy.atk * 0.05 * dt
                        hero.currentHP = hero.currentHP - dmg
                    end
                end
            end
        end

        ::nextEnemy::
    end
end

-- ============================================================================
-- 武将死亡 & 复活
-- ============================================================================

function M.UpdateHeroDeath(dt)
    local st = tdState
    for _, hero in ipairs(st.heroes) do
        if hero.dead then
            -- 复活倒计时
            hero.respawnTimer = hero.respawnTimer - dt
            if hero.respawnTimer <= 0 then
                hero.dead = false
                hero.currentHP = hero.maxHP * 0.5  -- 复活50%HP
                hero.respawnTimer = 0
                addFloat("复活!", hero.x, hero.y - 20, {80, 255, 120})
                if PlaySFX then PlaySFX(TD_SFX.heroRevive) end
            end
        else
            -- 检查是否死亡
            if hero.currentHP <= 0 then
                hero.dead = true
                hero.currentHP = 0
                hero.respawnTimer = 10.0  -- 10秒复活
                addFloat("阵亡!", hero.x, hero.y - 20, {255, 60, 60})
                if PlaySFX then PlaySFX(TD_SFX.heroDeath) end
            end
        end
    end
end

-- ============================================================================
-- 飞行剑系统 (方向已修复: 从城堡→入口)
-- ============================================================================

local function SumHeroAtk()
    local st = tdState
    local total = 0
    for _, hero in ipairs(st.heroes) do
        if not hero.dead then
            total = total + (hero.tdStats.atk or 0)
        end
    end
    return total
end

local function CalcSwordBuffs(heroAtk)
    local dmgMult = 1.0
    local bonusDmg = heroAtk * 0.5
    return dmgMult, bonusDmg
end

local function SpawnFlyingSword()
    local st = tdState
    if not st.smoothPath or #st.smoothPath < 2 then return end

    local heroAtk = SumHeroAtk()
    local dmgMult, bonusDmg = CalcSwordBuffs(heroAtk)
    local finalDmg = math.floor((st.swordDmgBase + bonusDmg) * dmgMult)

    local color
    if finalDmg >= 500 then
        color = {255, 80, 80}
    elseif finalDmg >= 300 then
        color = {255, 180, 60}
    elseif finalDmg >= 150 then
        color = {80, 180, 255}
    else
        color = {200, 220, 255}
    end

    -- 修复: 从路径终点(城堡)出发, travelDist = pathLength
    st.flyingSwords[#st.flyingSwords + 1] = {
        travelDist = st.pathLength,
        dmg = finalDmg,
        hitSet = {},
        color = color,
        trail = {},
        active = true,
    }

    addFloat("剑气发射! 伤害:" .. finalDmg, TDData.DESIGN_W / 2, 55, color)
    if PlaySFX then PlaySFX(TD_SFX.skillActivate) end
end

function M.UpdateSwordCD(dt)
    local st = tdState
    if not st or st.phase ~= "PLAYING" then return end
    if #st.heroes == 0 then return end

    local effectiveCd = st.swordCdBase
    st.swordCdTimer = st.swordCdTimer + dt
    st.swordEffectiveCd = effectiveCd

    if st.swordCdTimer >= effectiveCd then
        if #st.enemies > 0 then
            st.swordCdTimer = 0
            SpawnFlyingSword()
        else
            st.swordCdTimer = effectiveCd
        end
    end
end

--- 更新飞行中的剑 (修复: 反向飞行, travelDist递减)
function M.UpdateFlyingSwords(dt)
    local st = tdState
    if not st or not st.flyingSwords then return end

    local i = 1
    while i <= #st.flyingSwords do
        local sword = st.flyingSwords[i]
        if not sword.active then
            -- swap-and-pop 清理
            st.flyingSwords[i] = st.flyingSwords[#st.flyingSwords]
            st.flyingSwords[#st.flyingSwords] = nil
        else
            -- 反向飞行: travelDist 递减
            sword.travelDist = sword.travelDist - st.swordSpeed * dt

            local sx, sy
            if sword.travelDist <= 0 then
                -- 到达路径起点(入口), 消失
                sword.active = false
                sx = st.smoothPath[1].x
                sy = st.smoothPath[1].y
            else
                local arrived
                sx, sy, arrived = TDData.GetPositionOnPath(st.smoothPath, sword.travelDist)
            end

            -- 记录拖尾轨迹
            if sx then
                sword.trail[#sword.trail + 1] = { x = sx, y = sy }
                if #sword.trail > 12 then
                    table.remove(sword.trail, 1)
                end

                -- 碰撞检测
                local nearbyIdxs = queryNearby(sx, sy, st.swordRadius)
                for _, idx in ipairs(nearbyIdxs) do
                    local enemy = st.enemies[idx]
                    if enemy and not enemy.dead then
                        local eid = tostring(enemy)
                        if not sword.hitSet[eid] then
                            local d = dist2D(sx, sy, enemy.x, enemy.y)
                            if d <= st.swordRadius then
                                sword.hitSet[eid] = true
                                M.DealDamage(enemy, sword.dmg, nil)
                                addSkillFX("targeted", enemy.x, enemy.y, 20, sword.color, nil)
                            end
                        end
                    end
                end
            end

            i = i + 1
        end
    end
end

-- ============================================================================
-- 寻找范围内最近敌人 (使用空间哈希)
-- ============================================================================

function M.FindNearestEnemy(x, y, range)
    local st = tdState
    local nearbyIdxs = queryNearby(x, y, range)
    local best, bestDist = nil, range + 1
    for _, idx in ipairs(nearbyIdxs) do
        local enemy = st.enemies[idx]
        if enemy and not enemy.dead then
            local d = dist2D(x, y, enemy.x, enemy.y)
            if d <= range and d < bestDist then
                best = enemy
                bestDist = d
            end
        end
    end
    return best
end

-- ============================================================================
-- 造成伤害 + 能量获取
-- ============================================================================

function M.DealDamage(enemy, damage, source)
    if enemy.dead then return end
    local actualDmg = math.max(1, damage - enemy.def * 0.3)

    if source and source.card then
        local srcTroop = "infantry"
        local uc = source.card.unitClass and UNIT_CLASS[source.card.unitClass]
        if uc then srcTroop = uc.baseTroop or "infantry" end
        local mult = GetTroopCounterMult(srcTroop, enemy.troop)
        actualDmg = actualDmg * mult
    end

    actualDmg = math.floor(actualDmg)
    enemy.hp = enemy.hp - actualDmg

    -- 能量: 命中 +1
    tdState.totalEnergy = math.min(TDData.ENERGY_MAX, tdState.totalEnergy + TDData.ENERGY_PER_HIT)

    if enemy.hp <= 0 then
        enemy.dead = true
        tdState.waveEnemiesAlive = tdState.waveEnemiesAlive - 1
        tdState.totalKills = tdState.totalKills + 1
        local goldReward = enemy.elite and TDData.KILL_GOLD_ELITE or TDData.KILL_GOLD_BASE
        tdState.gold = tdState.gold + goldReward
        addFloat("+" .. goldReward, enemy.x, enemy.y - 10, {255, 220, 100})

        -- 能量: 击杀 +5
        tdState.totalEnergy = math.min(TDData.ENERGY_MAX, tdState.totalEnergy + TDData.ENERGY_PER_KILL)

        if PlaySFX and tdState.totalKills % 5 == 0 then
            PlaySFX(TD_SFX.enemyDeath)
        end
    end
end

-- ============================================================================
-- 5技能释放
-- ============================================================================

function M.CastSkill(skillIdx, targetX, targetY)
    local st = tdState
    if not st then return false end

    local def = TDData.SKILL_DEFS[skillIdx]
    if not def then return false end

    -- 检查能量
    if st.totalEnergy < def.energyCost then
        addFloat("能量不足!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, {255, 80, 80})
        return false
    end

    -- 检查CD
    if st.skills[skillIdx].cdTimer > 0 then
        addFloat("冷却中!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, {255, 200, 80})
        return false
    end

    -- 扣能量, 启动CD
    st.totalEnergy = st.totalEnergy - def.energyCost
    st.skills[skillIdx].cdTimer = def.cd

    if def.id == "sword" then
        -- 飞剑: 直接生成一把(不等CD)
        SpawnFlyingSword()

    elseif def.id == "fire" then
        -- 天火: 大范围AOE伤害
        local radius = def.radius or 80
        local dmg = def.damage or 120
        for _, enemy in ipairs(st.enemies) do
            if not enemy.dead and dist2D(targetX, targetY, enemy.x, enemy.y) <= radius then
                M.DealDamage(enemy, dmg, nil)
            end
        end
        addFloat("天火!", targetX, targetY - 25, {255, 120, 40})
        addSkillFX("aoe", targetX, targetY, radius, {255, 120, 40}, nil)
        if PlaySFX then PlaySFX(TD_SFX.skillFire) end

    elseif def.id == "frost" then
        -- 冰霜: 全场减速
        local slowMul = def.slowMul or 0.4
        local dur = def.duration or 3.0
        for _, enemy in ipairs(st.enemies) do
            if not enemy.dead then
                enemy.slowTimer = dur
                enemy.slowFactor = slowMul
            end
        end
        addFloat("冰霜降临!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, {80, 180, 255})
        addSkillFX("aoe", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, 200, {80, 180, 255}, nil)
        if PlaySFX then PlaySFX(TD_SFX.skillFrost) end

    elseif def.id == "heal" then
        -- 春风: 全体武将回复30%HP
        local pct = def.healPct or 0.3
        for _, hero in ipairs(st.heroes) do
            if not hero.dead then
                local healAmt = math.floor(hero.maxHP * pct)
                hero.currentHP = math.min(hero.maxHP, hero.currentHP + healAmt)
                addFloat("+" .. healAmt, hero.x, hero.y - 15, {80, 255, 120})
            end
        end
        addFloat("春风化雨!", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, {80, 255, 120})
        addSkillFX("heal", TDData.DESIGN_W / 2, TDData.DESIGN_H / 2, 150, {80, 255, 120}, nil)
        if PlaySFX then PlaySFX(TD_SFX.skillHeal) end

    elseif def.id == "thunder" then
        -- 雷霆: 范围伤害+眩晕
        local radius = def.radius or 60
        local dmg = def.damage or 200
        local stunDur = def.stunDur or 1.0
        for _, enemy in ipairs(st.enemies) do
            if not enemy.dead and dist2D(targetX, targetY, enemy.x, enemy.y) <= radius then
                M.DealDamage(enemy, dmg, nil)
                enemy.stunTimer = stunDur
            end
        end
        addFloat("雷霆万钧!", targetX, targetY - 25, {180, 120, 255})
        addSkillFX("aoe", targetX, targetY, radius, {180, 120, 255}, nil)
        if PlaySFX then PlaySFX(TD_SFX.skillThunder) end
    end

    return true
end

-- ============================================================================
-- 旧技能系统保留 (武将个人技能, 现在很少触发)
-- ============================================================================

local function getSkillName(card)
    if card.initTechnique and SKILL_TECHNIQUES and SKILL_TECHNIQUES[card.initTechnique] then
        return SKILL_TECHNIQUES[card.initTechnique].name
    end
    return card.skill or "武技"
end

local TIER_COLORS = {
    {200, 200, 200},
    {120, 220, 120},
    {80, 160, 255},
    {200, 120, 255},
    {255, 180, 60},
    {255, 80, 80},
    {255, 220, 80},
}

local function getSkillTierColor(card)
    if card.initTechnique and SKILL_TECHNIQUES and SKILL_TECHNIQUES[card.initTechnique] then
        local tier = SKILL_TECHNIQUES[card.initTechnique].tier or 1
        return TIER_COLORS[tier] or TIER_COLORS[1]
    end
    return TIER_COLORS[1]
end

function M.UseSkill(hero, target)
    local card = hero.card
    local sd = card.skillData
    if not sd then return end

    local stats = hero.tdStats
    local baseDmg = stats.atk * (sd.mult or 1.5)
    local skillName = getSkillName(card)
    local tierClr = getSkillTierColor(card)

    if PlaySFX then PlaySFX(TD_SFX.skillActivate) end
    local techIdx = card.initTechnique

    if sd.kind == "aoe" then
        local radius = (sd.radius or 60)
        for _, enemy in ipairs(tdState.enemies) do
            if not enemy.dead and dist2D(target.x, target.y, enemy.x, enemy.y) <= radius then
                M.DealDamage(enemy, baseDmg, hero)
            end
        end
        addFloat(skillName, target.x, target.y - 25, tierClr)
        addSkillFX("aoe", target.x, target.y, radius, tierClr, techIdx)
    elseif sd.kind == "line" then
        local lineLen = 200
        for _, enemy in ipairs(tdState.enemies) do
            if not enemy.dead and math.abs(enemy.y - hero.y) < 30 then
                if dist2D(hero.x, hero.y, enemy.x, enemy.y) < lineLen then
                    M.DealDamage(enemy, baseDmg, hero)
                end
            end
        end
        addFloat(skillName, hero.x + 40, hero.y - 15, tierClr)
        addSkillFX("line", hero.x, hero.y, lineLen, tierClr, techIdx)
    elseif sd.kind == "heal" then
        local healAmt = math.floor(tdState.baseMaxHP * (sd.healMult or 0.1))
        tdState.baseHP = math.min(tdState.baseMaxHP, tdState.baseHP + healAmt)
        addFloat(skillName, hero.x, hero.y - 30, {80, 255, 120})
        addFloat("+" .. healAmt .. "HP", hero.x, hero.y - 15, {80, 255, 120})
        addSkillFX("heal", hero.x, hero.y, 50, {80, 255, 120}, techIdx)
    elseif sd.kind == "buff" then
        local buffRadius = 150
        for _, h in ipairs(tdState.heroes) do
            if dist2D(hero.x, hero.y, h.x, h.y) < buffRadius then
                h.tdStats.atk = h.tdStats.atk + math.floor(stats.atk * (sd.atkBuff or 0.2))
            end
        end
        addFloat(skillName, hero.x, hero.y - 25, {255, 255, 120})
        addSkillFX("buff", hero.x, hero.y, buffRadius, {255, 255, 120}, techIdx)
    else
        local hits = sd.hits or 1
        for h = 1, hits do
            M.DealDamage(target, baseDmg, hero)
        end
        addFloat(skillName, target.x, target.y - 25, tierClr)
        addSkillFX("targeted", target.x, target.y, 30, tierClr, techIdx)
    end
end

-- ============================================================================
-- 弹道更新 (箭矢命中时造成伤害)
-- ============================================================================

function M.UpdateProjectiles(dt)
    local st = tdState
    local i = 1
    while i <= #st.projectiles do
        local p = st.projectiles[i]
        p.timer = p.timer + dt
        if p.timer >= p.duration then
            -- 箭矢命中: 造成伤害
            if p.kind == "arrow" and p.targetRef and not p.targetRef.dead then
                M.DealDamage(p.targetRef, p.dmg, p.heroRef)
            end
            -- swap-and-pop
            st.projectiles[i] = st.projectiles[#st.projectiles]
            st.projectiles[#st.projectiles] = nil
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- 清理死亡敌人 (swap-and-pop 优化)
-- ============================================================================

function M.CleanupDead()
    local st = tdState
    local i = 1
    while i <= #st.enemies do
        if st.enemies[i].dead then
            st.enemies[i] = st.enemies[#st.enemies]
            st.enemies[#st.enemies] = nil
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- 飘字 & 技能特效更新
-- ============================================================================

function M.UpdateFloatTexts(dt)
    local st = tdState
    local i = 1
    while i <= #st.floatTexts do
        local ft = st.floatTexts[i]
        ft.timer = ft.timer + dt
        ft.y = ft.y - 30 * dt
        if ft.timer >= ft.duration then
            st.floatTexts[i] = st.floatTexts[#st.floatTexts]
            st.floatTexts[#st.floatTexts] = nil
        else
            i = i + 1
        end
    end
end

function M.UpdateSkillFX(dt)
    local st = tdState
    if not st or not st.skillFXList then return end
    local i = 1
    while i <= #st.skillFXList do
        local fx = st.skillFXList[i]
        fx.timer = fx.timer + dt
        if fx.fps and fx.totalFrames then
            fx.frameIdx = math.min(
                math.floor(fx.timer * fx.fps),
                fx.totalFrames - 1
            )
        end
        if fx.timer >= fx.duration then
            st.skillFXList[i] = st.skillFXList[#st.skillFXList]
            st.skillFXList[#st.skillFXList] = nil
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- 自动战斗
-- ============================================================================

function M.AutoBattleTick(dt)
    local st = tdState
    if st.phase ~= "PLAYING" and st.phase ~= "WAVE_CLEAR" then return end
    M.AutoPlaceHeroes()
    -- 自动释放全部5个技能（能量和CD允许时）
    if st.phase == "PLAYING" then
        M.AutoCastSkills()
    end
end

--- 自动施放所有可用技能
function M.AutoCastSkills()
    local st = tdState
    if not st then return end

    for i = 1, 5 do
        local def = TDData.SKILL_DEFS[i]
        if not def then goto continue end
        -- 检查能量和CD
        if st.totalEnergy < def.energyCost then goto continue end
        if st.skills[i] and st.skills[i].cdTimer > 0 then goto continue end
        -- 需要目标的技能: 选敌人最密集的区域
        if def.needTarget then
            local bestX, bestY, bestCount = nil, nil, 0
            local radius = def.radius or 80
            for _, enemy in ipairs(st.enemies) do
                if not enemy.dead then
                    local cnt = 0
                    for _, other in ipairs(st.enemies) do
                        if not other.dead and dist2D(enemy.x, enemy.y, other.x, other.y) <= radius then
                            cnt = cnt + 1
                        end
                    end
                    if cnt > bestCount then
                        bestCount = cnt
                        bestX = enemy.x
                        bestY = enemy.y
                    end
                end
            end
            if bestX and bestCount >= 1 then
                M.CastSkill(i, bestX, bestY)
            end
        else
            -- 无需目标的技能: 直接释放
            M.CastSkill(i, TDData.DESIGN_W / 2, TDData.DESIGN_H / 2)
        end
        ::continue::
    end
end

function M.AutoPlaceHeroes()
    local st = tdState
    if not st then return end

    local sortedRoster = {}
    for i, cardIdx in ipairs(st.roster) do
        if HERO_CARDS[cardIdx] then
            sortedRoster[#sortedRoster + 1] = { idx = i, quality = HERO_CARDS[cardIdx].quality, cardIdx = cardIdx }
        end
    end
    table.sort(sortedRoster, function(a, b) return a.quality > b.quality end)

    local availableSlots = {}
    for _, slot in ipairs(TDData.TOWER_SLOTS) do
        if not st.placedHeroMap[slot.key] then
            availableSlots[#availableSlots + 1] = slot.key
        end
    end

    if #availableSlots == 0 then return end

    for _, entry in ipairs(sortedRoster) do
        local cost = TDData.HERO_COST[HERO_CARDS[entry.cardIdx].quality] or 200
        if st.gold >= cost and #availableSlots > 0 then
            local alreadyPlaced = false
            for _, hero in ipairs(st.heroes) do
                if hero.rosterIdx == entry.idx then
                    alreadyPlaced = true
                    break
                end
            end
            if not alreadyPlaced then
                local key = table.remove(availableSlots, math.random(#availableSlots))
                M.PlaceHero(entry.idx, key)
            end
        end
    end
end

return M
