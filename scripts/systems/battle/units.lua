-- ============================================================================
-- systems/battle/units.lua - 三国武灵录
-- ============================================================================


--- 获取战场随机Y坐标 (RTS模式: 车道已移除, 返回战场范围内随机Y)
--- 保留函数签名兼容旧引用
function GetLaneCenterY(laneIdx)
    local bz = BATTLE_ZONE
    return bz.top + 20 + math.random() * (bz.bottom - bz.top - 40)
end

--- 兼容旧代码
function GetLaneCenterX(laneIdx)
    return GetLaneCenterY(laneIdx)
end


--- 计算玩家单位动态上限 (基础40 + 全部槽位贪欲额外兵力)
function GetPlayerUnitCap()
    local extra = 0
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            local sb = slot.cachedSealBonus
            if sb and sb.extraTroops > 0 then
                extra = extra + math.floor(sb.extraTroops)
            end
        end
    end
    return MAX_PLAYER_UNITS + extra
end


--- 添加弹道特效 (从攻击者到目标的线性飞行)
function AddProjectile(sx, sy, tx, ty, color, isPlayer)
    table.insert(projectiles, {
        sx = sx, sy = sy,     -- 起点
        tx = tx, ty = ty,     -- 终点
        timer = 0,
        maxTime = 0.25,       -- 飞行时长
        color = color or (isPlayer and {200, 230, 255} or {255, 100, 80}),
        isPlayer = isPlayer,
    })
end


function AddParticle(x, y, opts)
    if #particles >= 300 then return end
    opts = opts or {}
    table.insert(particles, {
        x = x, y = y,
        vx = opts.vx or (math.random() - 0.5) * 60,
        vy = opts.vy or -(math.random() * 40 + 20),
        life = opts.life or (0.6 + math.random() * 0.6),
        timer = 0,
        size = opts.size or (2 + math.random() * 3),
        color = opts.color or { 255, 220, 100 },
        isDesign = opts.isDesign ~= false,  -- 默认设计坐标
    })
end


function SpawnPlaceEffect(cx, cy, quality)
    local qc = QUALITY_COLORS[quality] or { 200, 200, 200 }
    for _ = 1, 12 do
        AddParticle(cx, cy, {
            vx = (math.random() - 0.5) * 100,
            vy = -(math.random() * 60 + 10),
            life = 0.5 + math.random() * 0.5,
            size = 1.5 + math.random() * 3,
            color = { qc[1], qc[2], qc[3] },
        })
    end
end


-- ============================================================================
-- 战斗单位
-- ============================================================================

function GetUnitClassForCard(card, isPlayer)
    if isPlayer then
        return UNIT_CLASS[card.unitClass] or UNIT_CLASS.SWORD
    elseif gameState.isRanked then
        return UNIT_CLASS[card.unitClass] or UNIT_CLASS.SWORD
    else return UNIT_CLASS[card.unitClass] or UNIT_CLASS.DEMON_WARRIOR end
end


function SpawnPlayerUnit()
    if #playerUnits >= GetPlayerUnitCap() then return end
    local filledSlots = {}
    for si, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then table.insert(filledSlots, { slot = slot, idx = si }) end
    end

    local uc, atk, def, hp, breakDmgAdd
    breakDmgAdd = 0
    if #filledSlots > 0 then
        -- ★ 站位加成：放对位置的武灵出兵概率更高（加权随机）
        -- 前排(1-3)适合近战，后排(4-8)适合远程/治疗，夜影刺客任意
        local weights = {}
        local totalW = 0
        for i, entry in ipairs(filledSlots) do
            local isFront = (entry.idx <= 3)
            local ucN = (entry.slot.card.unitClass or "SWORD")
            local w = 1.0  -- 默认权重
            if ucN == "SHIELD" or ucN == "CAVALRY" or ucN == "LANCER" or ucN == "BEAST" or ucN == "SWORD" then
                w = isFront and 1.5 or 0.8   -- 近战放前排概率+50%，放后排概率-20%
            elseif ucN == "ARCHER" or ucN == "MAGE" or ucN == "ICE_MAGE" then
                w = isFront and 0.8 or 1.5   -- 远程放后排概率+50%，放前排概率-20%
            elseif ucN == "HEALER" or ucN == "PUPPETEER" then
                w = isFront and 0.7 or 1.6   -- 军医道士/驯兽使放后排概率+60%
            elseif ucN == "ASSASSIN" then
                w = 1.2                       -- 夜影刺客任意位置略高
            elseif ucN == "TALISMAN" or ucN == "SWARM" then
                w = isFront and 1.4 or 0.9   -- 火牛突袭/蜂巢蝗群偏前排（冲锋/近战虫群）
            end
            weights[i] = w
            totalW = totalW + w
        end
        -- 加权随机选择
        local roll = math.random() * totalW
        local pickIdx = 1
        local acc = 0
        for i, w in ipairs(weights) do
            acc = acc + w
            if roll <= acc then pickIdx = i; break end
        end

        local pick = filledSlots[pickIdx]
        local slot = pick.slot
        local card = slot.card
        local lm = 1 + ((card.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
        uc = GetUnitClassForCard(card, true)
        -- 应用命格加成
        local cStats = ApplyConstellationStats(card)
        -- 应用装备百分比增幅
        local eqB = GetEquipmentBonus()
        cachedEqBonus = eqB  -- 缓存供单位属性注入
        local ss = SOLDIER_STAT_SCALE
        atk = cStats.atk * (1 + eqB.atkPct / 100) * lm * ss
        def = cStats.def * (1 + eqB.defPct / 100) * lm * ss * 0.5
        hp  = cStats.hp  * (1 + eqB.hpPct / 100)  * lm * ss * 0.6
        breakDmgAdd = cStats.breakDmgAdd or 0
    else
        uc = UNIT_CLASS.SWORD; atk = 56; def = 14; hp = 180
    end

    local bz = BATTLE_ZONE
    local unit = {
        x = bz.playerDeployLeft + 10 + math.random() * (bz.playerDeployRight - bz.playerDeployLeft - 20),
        y = bz.top + 20 + math.random() * (bz.bottom - bz.top - 40),
        hp = hp, maxHp = hp, atk = atk, def = def,
        speed = uc.speed + math.random() * 6,
        atkTimer = math.random() * 0.5, atkCooldown = uc.atkCd,
        atkRange = uc.atkRange,
        alive = true, isPlayer = true,
        isRanged = uc.isRanged, unitClass = uc,
        animTimer = math.random() * 6.28, flashTimer = 0,
        isHealer = (uc == UNIT_CLASS.HEALER),
        cloudSeed = math.random() * 100,
        breakDmgAdd = breakDmgAdd,
    }
    -- 装备套装额外词条注入 (与兵符属性同名, 战斗中叠加生效)
    if cachedEqBonus then
        local eb = cachedEqBonus
        if eb.speedPct > 0 then
            unit.speed = unit.speed * (1 + eb.speedPct / 100)
        end
        if eb.atkSpeedPct > 0 then
            unit.atkCooldown = unit.atkCooldown / (1 + eb.atkSpeedPct / 100)
        end
        unit.equipCritRate = eb.critRate or 0
        unit.equipDmgReduction = eb.dmgReduction or 0
        unit.equipCounterRate = eb.counterRate or 0
        unit.equipBreakDmgPct = eb.breakDmgPct or 0
        unit.equipDeathExplosionPct = eb.deathExplosionPct or 0
    end
    table.insert(playerUnits, unit)
end


function SpawnEnemyUnit()
    if #enemyUnits >= MAX_ENEMY_UNITS then return end
    local filledSlots = {}
    for _, slot in ipairs(ENEMY_SLOTS) do
        if slot.filled and slot.card then table.insert(filledSlots, slot) end
    end

    local uc, atk, def, hp
    if #filledSlots > 0 then
        local slot = filledSlots[math.random(1, #filledSlots)]
        local card = slot.card
        uc = GetUnitClassForCard(card, false)
        local ss = SOLDIER_STAT_SCALE
        atk = card.atk * ss; def = card.def * ss * 0.5; hp = card.hp * ss * 0.6
    else
        uc = UNIT_CLASS.DEMON_WARRIOR
        atk = 52; def = 12; hp = 160
    end

    local bz = BATTLE_ZONE
    table.insert(enemyUnits, {
        x = bz.enemyDeployLeft + 10 + math.random() * (bz.enemyDeployRight - bz.enemyDeployLeft - 20),
        y = bz.top + 20 + math.random() * (bz.bottom - bz.top - 40),
        hp = hp, maxHp = hp, atk = atk, def = def,
        speed = uc.speed + math.random() * 5,
        atkTimer = math.random() * 0.5, atkCooldown = uc.atkCd,
        atkRange = uc.atkRange,
        alive = true, isPlayer = false,
        isRanged = uc.isRanged, unitClass = uc,
        animTimer = math.random() * 6.28, flashTimer = 0,
        isHealer = false,
        cloudSeed = math.random() * 100,
    })
end


--- 获取兵种实际出兵数 (大型兵种数量更少)
--- 返回 baseBatch, sealExtra (兵符额外兵力不受spawnMax限制)
function GetBatchSizeForSlot(slot)
    local quality = slot.card and slot.card.quality or 1
    local baseBatch = DEPLOY_BATCH_SIZE[quality] or 4
    -- 贪欲兵符: 额外出兵数 (无视spawnMax, 作为独立增援)
    local sealExtra = 0
    local sb = slot.cachedSealBonus
    if sb and sb.extraTroops > 0 then
        sealExtra = math.floor(sb.extraTroops)
    end
    local uc = GetUnitClassForCard(slot.card, true)
    if uc.spawnMax then
        baseBatch = math.min(baseBatch, uc.spawnMax)
    end
    return baseBatch + sealExtra
end


--- 从指定槽位生成一个战斗单位 (RTS模式: 自由2D部署)
function SpawnUnitFromSlot(slot, isPlayer, overrideLaneIdx, slotIdx)
    local card = slot.card
    local uc = GetUnitClassForCard(card, isPlayer)
    local lm = 1 + ((card.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
    local cStats = ApplyConstellationStats(card)
    local bz = BATTLE_ZONE

    -- RTS模式: 自由Y坐标分布 (不再分配车道)
    local spawnY = bz.top + 20 + math.random() * (bz.bottom - bz.top - 40)

    local ss = SOLDIER_STAT_SCALE
    -- 大型兵种属性加成（数量少但单体更强）
    local hpM = uc.hpMult or 1.0
    local atkM = uc.atkMult or 1.0
    local unitHp = cStats.hp * lm * ss * 0.6 * hpM
    local unit = {
        x = isPlayer and (bz.playerDeployLeft + 10 + math.random() * 20) or (bz.enemyDeployLeft + 10 + math.random() * 20),
        y = spawnY,
        hp = unitHp, maxHp = unitHp,
        atk = cStats.atk * lm * ss * atkM, def = cStats.def * lm * ss * 0.5,
        speed = uc.speed + math.random() * 5,
        atkTimer = math.random() * 0.5, atkCooldown = uc.atkCd,
        atkRange = uc.atkRange,
        alive = true, isPlayer = isPlayer,
        isRanged = uc.isRanged, unitClass = uc,
        animTimer = math.random() * 6.28, flashTimer = 0,
        isHealer = (uc == UNIT_CLASS.HEALER),
        cloudSeed = math.random() * 100,
        breakDmgAdd = cStats.breakDmgAdd or 0,
        cmdType = "advance",  -- RTS指令: "advance"|"move"|"attack"|"defend"
        cmdTarget = nil,      -- RTS指令目标 {x,y}
        cmdDone = false,      -- 是否已到达指令目标
        summonTimer = 0,    -- 傀儡操师召唤计时
        summonCount = 0,    -- 傀儡操师已召唤数
        troopType = card.troopType or "infantry", -- 兵种克制类型 (已在G_systems.lua中批量注入)
        slotIdx = slotIdx,   -- 武将技能系统: 关联PLAYER_SLOTS索引
    }

    -- 六欲兵符战斗属性注入
    local sb = isPlayer and slot.cachedSealBonus or nil
    if sb then
        -- 慢欲: 移速加成
        if sb.speedPct > 0 then
            unit.speed = unit.speed * (1 + sb.speedPct / 100)
        end
        -- 慢欲: 攻速加成 (降低攻击冷却)
        if sb.atkSpeedPct > 0 then
            unit.atkCooldown = unit.atkCooldown / (1 + sb.atkSpeedPct / 100)
        end
        -- 嗔欲: 暴击率
        unit.sealCritRate = sb.critRate or 0
        -- 痴欲: 减伤
        unit.sealDmgReduction = sb.dmgReduction or 0
        -- 疑欲: 反击率
        unit.sealCounterRate = sb.counterRate or 0
        -- 邪欲: 突破伤害加成%
        unit.sealBreakDmgPct = sb.breakDmgPct or 0
        -- 邪欲: 死亡爆炸ATK%
        unit.sealDeathExplosionPct = sb.deathExplosionPct or 0
    end

    -- 装备基础属性百分比加成 (玩家方: atkPct/defPct/hpPct)
    if isPlayer then
        local eqB = GetEquipmentBonus()
        if eqB.atkPct > 0 then unit.atk = unit.atk * (1 + eqB.atkPct / 100) end
        if eqB.defPct > 0 then unit.def = unit.def * (1 + eqB.defPct / 100) end
        if eqB.hpPct > 0 then
            unit.hp = unit.hp * (1 + eqB.hpPct / 100)
            unit.maxHp = unit.hp
        end
    end

    -- 装备套装额外词条注入 (玩家方, 与兵符叠加)
    if isPlayer then
        local eb = GetEquipmentBonus()
        if eb.speedPct > 0 then
            unit.speed = unit.speed * (1 + eb.speedPct / 100)
        end
        if eb.atkSpeedPct > 0 then
            unit.atkCooldown = unit.atkCooldown / (1 + eb.atkSpeedPct / 100)
        end
        unit.equipCritRate = eb.critRate or 0
        unit.equipDmgReduction = eb.dmgReduction or 0
        unit.equipCounterRate = eb.counterRate or 0
        unit.equipBreakDmgPct = eb.breakDmgPct or 0
        unit.equipDeathExplosionPct = eb.deathExplosionPct or 0
    end

    -- 腐蝇虫群: 一次生成多个小单位
    if uc.swarmCount and uc.swarmCount > 1 then
        for si = 1, uc.swarmCount do
            local swarmUnit = {}
            for k, v in pairs(unit) do swarmUnit[k] = v end
            swarmUnit.x = unit.x + (si - 3.5) * 8
            swarmUnit.y = unit.y + (math.random() - 0.5) * 12
            swarmUnit.cloudSeed = math.random() * 100
            swarmUnit.animTimer = math.random() * 6.28
            swarmUnit.isSwarmling = true
            if isPlayer then
                table.insert(playerUnits, swarmUnit)
            else table.insert(enemyUnits, swarmUnit) end
        end
        return  -- 虫群不再插入主单位
    end

    if isPlayer then
        table.insert(playerUnits, unit)
    else
        table.insert(enemyUnits, unit)
    end
end


--- 傀儡操师召唤小傀儡 (战斗中调用)
function SpawnPuppet(master, units, isPlayerSide)
    local bz = BATTLE_ZONE
    local puppet = {
        x = master.x + (math.random() - 0.5) * 20,
        y = master.y + (isPlayerSide and -20 or 20),
        hp = master.maxHp * 0.2, maxHp = master.maxHp * 0.2,
        atk = master.atk * 0.5, def = master.def * 0.3,
        speed = 28 + math.random() * 5,
        atkTimer = math.random() * 0.5, atkCooldown = 0.8,
        atkRange = 35,
        alive = true, isPlayer = isPlayerSide,
        isRanged = false, unitClass = UNIT_CLASS.PUPPETEER,
        animTimer = math.random() * 6.28, flashTimer = 0,
        cloudSeed = math.random() * 100,
        breakDmgAdd = 0,
        cmdType = "advance",
        cmdTarget = nil,
        cmdDone = false,
        isPuppet = true,  -- 标记为傀儡小兵
        summonTimer = 0, summonCount = 0,
    }
    table.insert(units, puppet)
end


--- 敌方AI: 返回随机车道索引 (RTS模式: 车道已废弃, 兼容旧接口)
function EnemyPickLane()
    return math.random(1, NUM_LANES)
end


function UpdateUnits(dt, units, targets, isPlayerSide)
    for _, u in ipairs(units) do
        if u.alive then
            -- 区域减速: 临时降低速度, 帧末恢复
            local origSpeed = u.speed
            local origAtk = u.atk
            local origDef = u.def
            if u.zoneSlowUntil and gameState.gameTime < u.zoneSlowUntil then
                u.speed = u.speed * (1.0 - (u.zoneSlowFactor or 0))
                u.isZoneSlowed = true
            else
                u.isZoneSlowed = false
                u.zoneSlowUntil = nil
                u.zoneSlowFactor = nil
            end

            -- 战斗地形效果: 检查单位所在地形区块
            u.currentTerrain = nil
            if battleTerrainZones then
                for _, tz in ipairs(battleTerrainZones) do
                    if u.x >= tz.x and u.x <= tz.x + tz.w and u.y >= tz.y and u.y <= tz.y + tz.h then
                        local td = TERRAIN_DEFS[tz.terrain]
                        if td then
                            u.currentTerrain = tz.terrain
                            if td.spdMod ~= 0 then u.speed = u.speed * (1 + td.spdMod) end
                            if td.atkMod ~= 0 then u.atk = u.atk * (1 + td.atkMod) end
                            if td.defMod ~= 0 then u.def = u.def * (1 + td.defMod) end
                        end
                        break
                    end
                end
            end

            u.animTimer = u.animTimer + dt * 3
            if u.flashTimer > 0 then u.flashTimer = u.flashTimer - dt end
            if u.atkAnimTimer and u.atkAnimTimer > 0 then u.atkAnimTimer = u.atkAnimTimer - dt end

            local ucId = u.unitClass and u.unitClass.id or 1

            -- ★ RTS指令优先: 如果单位有非默认指令，由指令系统接管行为
            if ExecuteUnitCommand and ExecuteUnitCommand(u, dt, targets, isPlayerSide) then
                -- 指令已接管移动和攻击，跳过默认兵种AI
                -- 但仍需处理死亡爆炸等被动效果
                if ucId == 6 and u.hp <= 0 and not u.deathExploded then
                    u.deathExploded = true
                    local explR = 45
                    local explDmg = u.atk * 1.2
                    for _, t in ipairs(targets) do
                        if t.alive then
                            local edx, edy = t.x - u.x, t.y - u.y
                            local ed = math.sqrt(edx * edx + edy * edy)
                            if ed <= explR then
                                t.hp = t.hp - explDmg
                                t.flashTimer = 0.2
                            end
                        end
                    end
                end
                if ucId == 8 then u.damageReduction = 0.15 end
            elseif u.isHealer then
                -- 腐灵祭司: 跟随部队前进 + 沿途治疗 + 攻速光环
                u.atkTimer = u.atkTimer + dt
                if u.atkTimer >= u.atkCooldown then
                    local ally = FindLowestHPAlly(u, units)
                    if ally and ally.hp < ally.maxHp then
                        u.atkTimer = 0; u.atkAnimTimer = 0.4
                        local heal = u.atk * 0.8
                        ally.hp = math.min(ally.maxHp, ally.hp + heal)
                        AddFloatText(ally.x, ally.y - 15, "+" .. math.floor(heal), 0.7, { 80, 255, 120 }, 20)
                    end
                end
                -- ★ 腐灵祭司攻速光环: 周围80px内友军攻速提升20%
                local auraRange = 80
                for _, ally in ipairs(units) do
                    if ally.alive and ally ~= u and not ally.isHealer then
                        local adx, ady = ally.x - u.x, ally.y - u.y
                        local ad = math.sqrt(adx * adx + ady * ady)
                        if ad <= auraRange then
                            ally.healerAura = true
                            ally.atkCooldown = (ally.unitClass and ally.unitClass.atkCd or 1.0) * 0.8
                        end
                    end
                end
                -- 跟随前线友军推进(横屏: 保持在友军X轴后方)
                local frontAlly = FindFrontAlly(u, units, isPlayerSide)
                if frontAlly then
                    local followX = isPlayerSide and (frontAlly.x - 40) or (frontAlly.x + 40)
                    local ddx = followX - u.x
                    if math.abs(ddx) > 5 then
                        u.x = u.x + (ddx > 0 and 1 or -1) * u.speed * dt
                    end
                    local ddy = frontAlly.y - u.y
                    if math.abs(ddy) > 10 then
                        u.y = u.y + (ddy > 0 and 1 or -1) * u.speed * 0.4 * dt
                    end
                else
                    -- 没有友军时缓慢前进
                    MoveTowardEnemyBase(u, dt, isPlayerSide)
                end

            elseif ucId == 9 then
                -- 噩梦骑兵: 快速冲锋(横屏: 沿X轴), 沿途撞击伤害
                local targetX = isPlayerSide and BATTLE_ZONE.enemyLine or BATTLE_ZONE.playerLine
                local ddx = targetX - u.x
                if math.abs(ddx) > 1 then
                    local dirX = ddx > 0 and 1 or -1
                    u.x = u.x + dirX * u.speed * dt
                    -- 冲锋沿途撞击：对路径上的敌人造成伤害
                    for _, t in ipairs(targets) do
                        if t.alive then
                            local tdx, tdy = t.x - u.x, t.y - u.y
                            local td = math.sqrt(tdx * tdx + tdy * tdy)
                            if td < 30 then
                                u.atkTimer = u.atkTimer + dt
                                if u.atkTimer >= u.atkCooldown then
                                    u.atkTimer = 0; u.atkAnimTimer = 0.4
                                    local raw = u.atk * 1.2
                                    t.hp = t.hp - raw
                                    t.flashTimer = 0.15
                                    AddFloatText(t.x, t.y - 10, math.floor(raw), 0.5, { 255, 200, 80 }, 14)
                                end
                            end
                        end
                    end
                    -- 轻微Y轴漂移防止扎堆
                    local yDrift = (math.random() - 0.5) * u.speed * 0.08 * dt
                    u.y = math.max(BATTLE_ZONE.top + 10, math.min(BATTLE_ZONE.bottom - 10, u.y + yDrift))
                end

            elseif ucId == 10 then
                -- 讨伐巨兽: 行进优先+范围攻击，边走边打挡路敌人
                local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                if blockT then
                    -- 挡路敌人在攻击范围内 → 范围攻击，但不停下来
                    u.atkTimer = u.atkTimer + dt
                    if u.atkTimer >= u.atkCooldown then
                        u.atkTimer = 0; u.atkAnimTimer = 0.4
                        local hitCount = 0
                        for _, t in ipairs(targets) do
                            if t.alive then
                                local tdx, tdy = t.x - u.x, t.y - u.y
                                local td = math.sqrt(tdx * tdx + tdy * tdy)
                                if td <= u.atkRange then
                                    local raw = u.atk * 0.8
                                    t.hp = t.hp - raw
                                    t.flashTimer = 0.15
                                    hitCount = hitCount + 1
                                end
                            end
                        end
                        if hitCount > 0 then
                            AddFloatText(u.x, u.y - 15, "震" .. hitCount .. "人", 0.6, { 255, 160, 50 }, 16)
                        end
                    end
                end
                -- 始终向基地推进
                MoveTowardEnemyBase(u, dt, isPlayerSide)

            elseif ucId == 13 then
                -- 自爆亡魂: 全速冲向基地，碰到敌人也引爆
                local exploded = false
                -- 检查是否碰到敌人
                for _, t in ipairs(targets) do
                    if t.alive then
                        local tdx, tdy = t.x - u.x, t.y - u.y
                        local td = math.sqrt(tdx * tdx + tdy * tdy)
                        if td <= 25 then
                            exploded = true; break
                        end
                    end
                end
                if exploded then
                    -- 自爆! 范围伤害
                    local eRadius = u.unitClass.explosionRadius or 60
                    local eMult = u.unitClass.explosionMult or 2.5
                    local hitCount = 0
                    for _, t in ipairs(targets) do
                        if t.alive then
                            local tdx, tdy = t.x - u.x, t.y - u.y
                            local td = math.sqrt(tdx * tdx + tdy * tdy)
                            if td <= eRadius then
                                local raw = u.atk * eMult
                                t.hp = t.hp - raw
                                t.flashTimer = 0.2
                                hitCount = hitCount + 1
                                if t.hp <= 0 then t.alive = false end
                            end
                        end
                    end
                    AddFloatText(u.x, u.y - 15, "符爆!" .. hitCount .. "人", 0.8, { 255, 200, 50 }, 18)
                    -- 爆炸粒子特效
                    for _ = 1, 8 do
                        AddParticle(u.x, u.y, {
                            vx = (math.random() - 0.5) * 80,
                            vy = (math.random() - 0.5) * 80,
                            life = 0.5 + math.random() * 0.3,
                            size = 3 + math.random() * 4,
                            color = { 255, 180, 50 },
                        })
                    end
                    u.alive = false  -- 自毁
                else
                    -- 全速冲向基地
                    MoveTowardEnemyBase(u, dt, isPlayerSide)
                end

            elseif ucId == 14 and not u.isPuppet then
                -- 傀儡操师(召唤): 缓慢前进，定期召唤小傀儡
                u.summonTimer = (u.summonTimer or 0) + dt
                local sCd = u.unitClass.summonCd or 4.0
                local sMax = u.unitClass.summonMax or 4
                if u.summonTimer >= sCd and (u.summonCount or 0) < sMax then
                    u.summonTimer = 0
                    u.summonCount = (u.summonCount or 0) + 1
                    SpawnPuppet(u, isPlayerSide and playerUnits or enemyUnits, isPlayerSide)
                    AddFloatText(u.x, u.y - 15, "召唤傀儡", 0.6, { 180, 100, 255 }, 14)
                end
                -- 远程攻击范围内敌人
                local bestT, bestD = nil, u.atkRange + 1
                for _, t in ipairs(targets) do
                    if t.alive then
                        local tdx, tdy = t.x - u.x, t.y - u.y
                        local td = math.sqrt(tdx * tdx + tdy * tdy)
                        if td < bestD then bestD = td; bestT = t end
                    end
                end
                if bestT and bestD <= u.atkRange then
                    AttackTarget(u, bestT, dt, isPlayerSide)
                end
                MoveTowardEnemyBase(u, dt, isPlayerSide)

            elseif ucId == 15 then
                -- 霜骨冰巫(减速): 远程攻击附带减速效果，有目标时停下射击
                local bestT, bestD = nil, u.atkRange + 1
                for _, t in ipairs(targets) do
                    if t.alive then
                        local tdx, tdy = t.x - u.x, t.y - u.y
                        local td = math.sqrt(tdx * tdx + tdy * tdy)
                        if td < bestD then bestD = td; bestT = t end
                    end
                end
                if bestT and bestD <= u.atkRange then
                    -- 有目标：停下来射击
                    u.rangedTarget = bestT
                    u.atkTimer = u.atkTimer + dt
                    if u.atkTimer >= u.atkCooldown then
                        u.atkTimer = 0; u.atkAnimTimer = 0.4
                        local atkDefMod = u.atk / (u.atk + bestT.def)
                        local raw = math.max(1, u.atk * atkDefMod * 0.7)  -- 伤害略低
                        bestT.hp = bestT.hp - raw
                        bestT.flashTimer = 0.15
                        -- 施加减速
                        local sf = u.unitClass.slowFactor or 0.4
                        local sd = u.unitClass.slowDuration or 2.0
                        bestT.zoneSlowUntil = gameState.gameTime + sd
                        bestT.zoneSlowFactor = sf
                        AddFloatText(bestT.x, bestT.y - 10, math.floor(raw) .. " 冻", 0.5, { 100, 200, 255 }, 13)
                        if bestT.hp <= 0 then bestT.alive = false end
                        -- 冰蓝弹道特效
                        AddProjectile(u.x, u.y, bestT.x, bestT.y, {100, 200, 255}, isPlayerSide)
                        -- 冰晶粒子
                        for _ = 1, 3 do
                            AddParticle(bestT.x, bestT.y, {
                                vx = (math.random() - 0.5) * 30,
                                vy = -(math.random() * 20),
                                life = 0.4, size = 2 + math.random() * 2,
                                color = { 120, 210, 255 },
                            })
                        end
                    end
                else
                    -- 无目标才推进
                    u.rangedTarget = nil
                    MoveTowardEnemyBase(u, dt, isPlayerSide)
                end

            elseif ucId == 16 or u.isSwarmling then
                -- 腐蝇虫群: 极快攻速，近距离群攻，血薄
                local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                if not blockT then
                    -- 虫群也搜索附近任意敌人（小范围）
                    for _, t in ipairs(targets) do
                        if t.alive then
                            local tdx, tdy = t.x - u.x, t.y - u.y
                            local td = math.sqrt(tdx * tdx + tdy * tdy)
                            if td <= u.atkRange + 15 then
                                blockT = t; blockD = td; break
                            end
                        end
                    end
                end
                if blockT then
                    u.atkTimer = u.atkTimer + dt
                    if u.atkTimer >= u.atkCooldown then
                        u.atkTimer = 0; u.atkAnimTimer = 0.4
                        local raw = math.max(1, u.atk * 0.8)
                        blockT.hp = blockT.hp - raw
                        blockT.flashTimer = 0.1
                        if blockT.hp <= 0 then blockT.alive = false end
                    end
                end
                MoveTowardEnemyBase(u, dt, isPlayerSide)

            elseif ucId == 3 then
                -- 墓碑守卫: 防御型AI，不主动进攻，在自家半场站岗防御
                if not u.guardPostY then
                    -- 分配站岗位置: 在自家半场均匀分布
                    local shieldCount = 0
                    local shieldIdx = 0
                    for _, su in ipairs(units) do
                        if su.alive and su.unitClass and su.unitClass.id == 3 then
                            shieldCount = shieldCount + 1
                            if su == u then shieldIdx = shieldCount end
                        end
                    end
                    if isPlayerSide then
                        -- 玩家半场: centerY(430) ~ playerLine(665) 之间站岗
                        local zoneTop = BATTLE_ZONE.centerY - 20
                        local zoneBot = BATTLE_ZONE.playerLine - 30
                        u.guardPostY = zoneTop + (zoneBot - zoneTop) * shieldIdx / (shieldCount + 1)
                    else
                        -- 敌方半场: enemyLine(195) ~ centerY(430) 之间站岗
                        local zoneTop = BATTLE_ZONE.enemyLine + 30
                        local zoneBot = BATTLE_ZONE.centerY + 20
                        u.guardPostY = zoneTop + (zoneBot - zoneTop) * shieldIdx / (shieldCount + 1)
                    end
                end
                -- 移动到站岗位置 (X轴保持当前位置，只调整Y轴)
                local gdx = 0
                local gdy = u.guardPostY - u.y
                if math.abs(gdy) > 3 then
                    u.y = u.y + (gdy > 0 and 1 or -1) * u.speed * dt
                end
                if math.abs(gdx) > 5 then
                    u.x = u.x + (gdx > 0 and 1 or -1) * u.speed * 0.3 * dt
                end
                -- 攻击范围内的敌人（站岗时也攻击）
                local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                if not blockT then
                    -- 也查找从后方经过的敌人（防御不只看前方）
                    for _, t in ipairs(targets) do
                        if t.alive then
                            local tdx, tdy = t.x - u.x, t.y - u.y
                            local td = math.sqrt(tdx * tdx + tdy * tdy)
                            if td <= u.atkRange then
                                blockT = t; blockD = td
                                break
                            end
                        end
                    end
                end
                if blockT then
                    AttackTarget(u, blockT, dt, isPlayerSide)
                    -- 墓碑守卫嘲讽: 被攻击的敌人会优先攻击墓碑守卫（标记嘲讽源）
                    blockT.tauntedBy = u
                    blockT.tauntTimer = 3.0  -- 嘲讽持续3秒
                end

            elseif ucId == 2 or ucId == 4 or ucId == 7 then
                -- 亡魂弩手/冥火术士/邪骨射手: 远程攻击AI，有目标时停下射击+弹道特效
                local bestT, bestD = nil, u.atkRange + 1
                for _, t in ipairs(targets) do
                    if t.alive then
                        local tdx, tdy = t.x - u.x, t.y - u.y
                        local td = math.sqrt(tdx * tdx + tdy * tdy)
                        if td < bestD then bestD = td; bestT = t end
                    end
                end
                if bestT and bestD <= u.atkRange then
                    -- 有目标：停下来射击
                    local prevTimer = u.atkTimer
                    AttackTarget(u, bestT, dt, isPlayerSide)
                    if u.atkTimer < prevTimer then
                        -- 攻击命中瞬间生成弹道特效
                        local projColor
                        if ucId == 4 then
                            projColor = {180, 130, 255}      -- 冥火术士: 紫色
                        elseif ucId == 7 then
                            projColor = {255, 80, 60}    -- 邪骨射手: 暗红
                        else projColor = {200, 230, 255} end               -- 亡魂弩手: 淡蓝
                        AddProjectile(u.x, u.y, bestT.x, bestT.y, projColor, isPlayerSide)
                    end
                    u.rangedTarget = bestT
                else
                    -- 无目标才向基地推进
                    u.rangedTarget = nil
                    MoveTowardEnemyBase(u, dt, isPlayerSide)
                end

            elseif ucId == 11 then
                -- 夜影刺客: 跨越路线绕后暗杀，对后排目标造成高伤害
                local prioTarget = FindBacklineEnemy(u, targets)
                if prioTarget then
                    local ddx, ddy = prioTarget.x - u.x, prioTarget.y - u.y
                    local dist = math.sqrt(ddx * ddx + ddy * ddy)
                    if dist <= u.atkRange then
                        -- 后排目标在范围内 → 暗杀攻击（绕后加成1.5x）
                        u.stealthing = false
                        u.atkTimer = u.atkTimer + dt
                        if u.atkTimer >= u.atkCooldown then
                            u.atkTimer = 0; u.atkAnimTimer = 0.4
                            local atkDefMod = u.atk / (u.atk + prioTarget.def)
                            local raw = math.max(1, u.atk * atkDefMod)
                            -- 绕后加成: 夜影刺客从后方攻击伤害x1.5
                            local behindBonus = 1.0
                            local isBehind = (isPlayerSide and u.y > prioTarget.y) or (not isPlayerSide and u.y < prioTarget.y)
                            if isBehind then behindBonus = 1.5 end
                            raw = raw * behindBonus
                            local isCrit = math.random() < 0.15  -- 夜影刺客暴击率更高
                            if isCrit then raw = raw * 2.0 end
                            prioTarget.hp = prioTarget.hp - raw
                            prioTarget.flashTimer = 0.15
                            local dmgColor = isBehind and { 255, 80, 200 } or { 255, 200, 80 }
                            local dmgText = isCrit and "暴击!" .. math.floor(raw) or math.floor(raw)
                            AddFloatText(prioTarget.x, prioTarget.y - 10, dmgText, 0.6, dmgColor, isCrit and 18 or 14)
                            if prioTarget.hp <= 0 then prioTarget.alive = false end
                        end
                    else
                        u.stealthing = true
                    end
                    -- 夜影刺客绕后路线: 先横向迂回到目标侧翼，再纵向包抄
                    local targetY = isPlayerSide and BATTLE_ZONE.enemyLine or BATTLE_ZONE.playerLine
                    local baseDir = targetY - u.y
                    if math.abs(baseDir) > 1 then
                        local dirY = baseDir > 0 and 1 or -1
                        u.y = u.y + dirY * u.speed * dt
                    end
                    -- 横向跨越车道靠近后排目标
                    local ldx = prioTarget.x - u.x
                    if math.abs(ldx) > 5 then
                        u.x = u.x + (ldx > 0 and 1 or -1) * u.speed * 0.6 * dt
                    end
                else
                    u.stealthing = false
                    -- 没有后排目标 → 边打挡路敌人边向基地推进
                    local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                    if blockT then
                        AttackTarget(u, blockT, dt, isPlayerSide)
                    end
                    MoveTowardEnemyBase(u, dt, isPlayerSide)
                end

            elseif ucId == 12 then
                -- 骨矛枪兵: 行进优先+贯穿攻击，边走边打挡路敌人
                local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                if blockT then
                    u.atkTimer = u.atkTimer + dt
                    if u.atkTimer >= u.atkCooldown then
                        u.atkTimer = 0; u.atkAnimTimer = 0.4
                        -- 找最近的2个敌人同时攻击
                        local sorted = {}
                        for _, t in ipairs(targets) do
                            if t.alive then
                                local tdx, tdy = t.x - u.x, t.y - u.y
                                local td = math.sqrt(tdx * tdx + tdy * tdy)
                                if td <= u.atkRange + 15 then
                                    table.insert(sorted, { target = t, dist = td })
                                end
                            end
                        end
                        table.sort(sorted, function(a, b) return a.dist < b.dist end)
                        for i = 1, math.min(2, #sorted) do
                            local t = sorted[i].target
                            local atkDefMod = u.atk / (u.atk + t.def)
                            local raw = math.max(1, u.atk * atkDefMod)
                            t.hp = t.hp - raw
                            t.flashTimer = 0.15
                            AddFloatText(t.x, t.y - 10, math.floor(raw), 0.5, { 200, 220, 255 }, 13)
                        end
                    end
                end
                -- 始终向基地推进
                MoveTowardEnemyBase(u, dt, isPlayerSide)

            else
                -- 骷髅剑兵/炼狱战鬼/铁棺重卫: 近战行进优先AI
                -- 嘲讽响应: 如果被墓碑守卫嘲讽，优先攻击墓碑守卫
                if u.tauntedBy and u.tauntedBy.alive and u.tauntTimer and u.tauntTimer > 0 then
                    u.tauntTimer = u.tauntTimer - dt
                    local tdx, tdy = u.tauntedBy.x - u.x, u.tauntedBy.y - u.y
                    local td = math.sqrt(tdx * tdx + tdy * tdy)
                    if td <= u.atkRange + 20 then
                        AttackTarget(u, u.tauntedBy, dt, isPlayerSide)
                    else
                        -- 向嘲讽源移动
                        u.x = u.x + (tdx > 0 and 1 or -1) * u.speed * 0.5 * dt
                        u.y = u.y + (tdy > 0 and 1 or -1) * u.speed * 0.5 * dt
                    end
                else
                    u.tauntedBy = nil
                    -- 只攻击挡路的敌人（同车道+前方+攻击范围内），不追击不偏离路线
                    local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                    if blockT then
                        AttackTarget(u, blockT, dt, isPlayerSide)
                    end
                    -- 始终向基地推进（即使在攻击也继续行进）
                    MoveTowardEnemyBase(u, dt, isPlayerSide)
                end

                -- ★ 敌军差异化 (仅限炼狱战鬼ucId==6)
                if ucId == 6 then
                    -- 炼狱战鬼死亡爆炸: 在 hp<=0 时触发范围伤害
                    if u.hp <= 0 and not u.deathExploded then
                        u.deathExploded = true
                        local explR = 45
                        local explDmg = u.atk * 1.2
                        for _, t in ipairs(targets) do
                            if t.alive then
                                local edx, edy = t.x - u.x, t.y - u.y
                                local ed = math.sqrt(edx * edx + edy * edy)
                                if ed <= explR then
                                    t.hp = t.hp - explDmg
                                    t.flashTimer = 0.2
                                    AddFloatText(t.x, t.y - 10, math.floor(explDmg), 0.5, { 200, 50, 50 }, 14)
                                end
                            end
                        end
                        -- 爆炸粒子
                        for a = 1, 8 do
                            local angle = (a / 8) * math.pi * 2
                            table.insert(particles, {
                                x = u.x, y = u.y,
                                vx = math.cos(angle) * 40, vy = math.sin(angle) * 40,
                                size = 4, life = 0.5, timer = 0,
                                color = { 180, 50, 50 }, isDesign = true,
                            })
                        end
                    end
                end

                -- ★ 铁棺重卫差异化 (ucId==8): 护盾抗性，受到伤害降低15%
                if ucId == 8 then
                    -- 通过在受伤时降低伤害实现（在此标记，AttackTarget检测）
                    u.damageReduction = 0.15
                end
            end

            -- 恢复原始属性 (区域减速+地形修正只在本帧生效)
            u.speed = origSpeed
            u.atk = origAtk
            u.def = origDef
        end
    end
end


--- 向敌方基地推进 (RTS模式: 沿X轴前进, 轻微Y漂移防扎堆)
function MoveTowardEnemyBase(u, dt, isPlayerSide)
    local targetX = isPlayerSide and BATTLE_ZONE.enemyLine or BATTLE_ZONE.playerLine
    local ddx = targetX - u.x
    if math.abs(ddx) > 1 then
        local dirX = ddx > 0 and 1 or -1
        u.x = u.x + dirX * u.speed * dt
        -- 轻微Y轴随机漂移 (防止单位扎堆成一条线)
        local bz = BATTLE_ZONE
        local yDrift = (math.random() - 0.5) * u.speed * 0.05 * dt
        u.y = math.max(bz.top + 10, math.min(bz.bottom - 10, u.y + yDrift))
    end
end

--- 向任意目标点移动 (RTS指令用)
--- 返回 true 表示已到达目标
function MoveToTarget(u, dt, tx, ty)
    local ddx = tx - u.x
    local ddy = ty - u.y
    local dist = math.sqrt(ddx * ddx + ddy * ddy)
    if dist < 15 then return true end  -- 到达阈值
    local nx, ny = ddx / dist, ddy / dist
    u.x = u.x + nx * u.speed * dt
    u.y = u.y + ny * u.speed * dt
    -- 限制在战场范围内
    local bz = BATTLE_ZONE
    u.y = math.max(bz.top + 10, math.min(bz.bottom - 10, u.y))
    return false
end


--- 查找前线友军 (横屏: 玩家向右推进X越大越前, 敌方向左X越小越前)
function FindFrontAlly(healer, units, isPlayerSide)
    local best, bestX = nil, nil
    for _, u in ipairs(units) do
        if u.alive and u ~= healer and not u.isHealer then
            if bestX == nil then
                best = u; bestX = u.x
            else
                if isPlayerSide then
                    if u.x > bestX then best = u; bestX = u.x end  -- 玩家方: X越大越前(向右)
                else
                    if u.x < bestX then best = u; bestX = u.x end  -- 敌方: X越小越前(向左)
                end
            end
        end
    end
    return best
end


--- 查找后排高优先目标 (夜影刺客专用: 远程/腐灵祭司优先)
function FindBacklineEnemy(assassin, targets)
    local best, bestD = nil, 99999
    for _, t in ipairs(targets) do
        if t.alive and (t.isRanged or t.isHealer) then
            local ddx, ddy = t.x - assassin.x, t.y - assassin.y
            local d = math.sqrt(ddx * ddx + ddy * ddy)
            if d < bestD then bestD = d; best = t end
        end
    end
    return best
end


--- 查找附近敌人 (只在interceptRange范围内)
function FindNearbyEnemy(unit, targets, interceptRange)
    local best, bestD = nil, interceptRange + 1
    for _, t in ipairs(targets) do
        if t.alive then
            local ddx, ddy = t.x - unit.x, t.y - unit.y
            local d = math.sqrt(ddx * ddx + ddy * ddy)
            if d < bestD then bestD = d; best = t end
        end
    end
    if best and bestD <= interceptRange then
        return best, bestD
    end
    return nil, 99999
end


--- 查找挡路敌人 (行进优先模式: 找前方+攻击范围内最近敌人)
--- 已去除车道限制，改为纯距离+前方判断
function FindBlockingEnemy(unit, targets, atkRange, isPlayerSide)
    local best, bestD = nil, atkRange + 1
    for _, t in ipairs(targets) do
        if t.alive then
            local ddx = t.x - unit.x
            local ddy = t.y - unit.y
            -- 检查: 必须在前方 (横屏: 玩家向右推进 = X 增大方向)
            local isAhead = (isPlayerSide and ddx > 0) or (not isPlayerSide and ddx < 0)
            if isAhead then
                local d = math.sqrt(ddx * ddx + ddy * ddy)
                if d < bestD then bestD = d; best = t end
            end
        end
    end
    if best and bestD <= atkRange then
        return best, bestD
    end
    return nil, 99999
end


--- 攻击目标 (从原UpdateUnits提取)
function AttackTarget(u, t, dt, isPlayerSide)
    u.atkTimer = u.atkTimer + dt
    if u.atkTimer >= u.atkCooldown then
        u.atkTimer = 0; u.atkAnimTimer = 0.4
        local atkDefMod = u.atk / (u.atk + t.def)
        local raw = math.max(1, u.atk * atkDefMod)
        -- 兵种克制倍率 (战争版)
        if u.troopType and t.troopType and rawget(_G, "GetTroopCounterMult") then
            raw = raw * GetTroopCounterMult(u.troopType, t.troopType)
        end
        -- 暴击率: 基础10% + 兵符加成 + 装备词条加成
        local critChance = 0.1 + (u.sealCritRate or 0) / 100 + (u.equipCritRate or 0) / 100
        local isCrit = math.random() < critChance
        if isCrit then raw = raw * 2.0 end
        -- 铁棺重卫护盾抗性: 减少受到的伤害
        if t.damageReduction and t.damageReduction > 0 then
            raw = raw * (1 - t.damageReduction)
        end
        -- 减伤: 兵符 + 装备词条
        local totalDmgReduction = (t.sealDmgReduction or 0) + (t.equipDmgReduction or 0)
        if totalDmgReduction > 0 then
            raw = raw * (1 - totalDmgReduction / 100)
        end
        -- 武将技能护盾吸收 (在扣血前检查)
        if t.shield and t.shield > 0 then
            if raw <= t.shield then
                t.shield = t.shield - raw
                raw = 0
            else
                raw = raw - t.shield
                t.shield = 0
            end
        end
        t.hp = t.hp - raw
        -- 反击: 兵符 + 装备词条 (受击方概率反弹50%自身ATK伤害)
        local totalCounterRate = (t.sealCounterRate or 0) + (t.equipCounterRate or 0)
        if totalCounterRate > 0 and t.alive and math.random() * 100 < totalCounterRate then
            local counterDmg = math.max(1, t.atk * 0.5)
            u.hp = u.hp - counterDmg
            u.flashTimer = 0.1
            -- 反击特效 (紫色闪光)
            AddParticle(u.x, u.y, {
                vx = (math.random() - 0.5) * 40,
                vy = -(math.random() * 20 + 5),
                life = 0.25, size = 2,
                color = { 180, 160, 220 },
            })
            if u.hp <= 0 then u.alive = false end
        end
        t.flashTimer = 0.15
        for _ = 1, 3 do
            AddParticle(t.x, t.y, {
                vx = (math.random() - 0.5) * 50,
                vy = -(math.random() * 30 + 5),
                life = 0.3 + math.random() * 0.3,
                size = 1 + math.random() * 2,
                color = isPlayerSide and { 200, 230, 255 } or { 255, 100, 80 },
            })
        end
        if t.hp <= 0 then
            t.alive = false
            if isPlayerSide then
                gameState.totalKills = gameState.totalKills + 1
            end
            -- 死亡爆炸: 兵符 + 装备词条 (被击杀单位如果有死亡爆炸属性，对周围敌人造成AOE伤害)
            local totalDeathExplPct = (t.sealDeathExplosionPct or 0) + (t.equipDeathExplosionPct or 0)
            if totalDeathExplPct > 0 then
                local explDmg = t.atk * totalDeathExplPct / 100
                local explRadius = 60
                local enemies = isPlayerSide and playerUnits or enemyUnits  -- 被杀方的敌人
                for _, e in ipairs(enemies) do
                    if e.alive and e ~= u then
                        local edx = e.x - t.x
                        local edy = e.y - t.y
                        local ed = math.sqrt(edx * edx + edy * edy)
                        if ed <= explRadius then
                            e.hp = e.hp - explDmg
                            e.flashTimer = 0.15
                            if e.hp <= 0 then e.alive = false end
                        end
                    end
                end
                -- 死亡爆炸特效 (紫红色扩散)
                for _ = 1, 12 do
                    AddParticle(t.x, t.y, {
                        vx = (math.random() - 0.5) * 150,
                        vy = (math.random() - 0.5) * 150,
                        life = 0.4 + math.random() * 0.3,
                        size = 3 + math.random() * 3,
                        color = { 200, 50, 200 },
                    })
                end
                AddFloatText(t.x, t.y - 20, "邪爆!", 0.6, { 200, 50, 200 }, 18)
            end
            for _ = 1, 8 do
                AddParticle(t.x, t.y, {
                    vx = (math.random() - 0.5) * 120,
                    vy = -(math.random() * 60 + 10),
                    life = 0.5 + math.random() * 0.4,
                    size = 2 + math.random() * 2.5,
                    color = isPlayerSide and { 255, 160, 60 } or { 120, 200, 255 },
                })
            end
        end
        AddFloatText(t.x, t.y - 15, math.floor(raw) .. (isCrit and "!" or ""),
            0.7, isCrit and { 255, 220, 50 } or (isPlayerSide and { 255, 255, 255 } or { 255, 100, 100 }),
            isCrit and 26 or 20)
    end
end


function FindNearest(unit, targets)
    local best, bestD = nil, 99999
    for _, t in ipairs(targets) do
        if t.alive then
            local ddx, ddy = t.x - unit.x, t.y - unit.y
            local d = math.sqrt(ddx * ddx + ddy * ddy)
            if d < bestD then bestD = d; best = t end
        end
    end
    return best, bestD
end


function FindLowestHPAlly(unit, allies)
    local best, bestRatio = nil, 1.0
    for _, a in ipairs(allies) do
        if a.alive and a ~= unit then
            local r = a.hp / a.maxHp
            if r < bestRatio then bestRatio = r; best = a end
        end
    end
    return best
end


function AddFloatText(x, y, text, duration, color, fontSize)
    if #floatTexts >= 50 then return end
    table.insert(floatTexts, {
        x = x, y = y, text = text,
        timer = 0, duration = duration or 1.0,
        color = color or { 255, 255, 255 },
        fontSize = fontSize or 12,
    })
end
