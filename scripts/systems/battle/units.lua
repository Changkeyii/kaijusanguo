-- ============================================================================
-- systems/battle/units.lua - 三国武灵录
-- ============================================================================

--- 士兵属性计算 (基础值 + 武将属性*加成系数)
--- @param heroHp number 武将最终HP
--- @param heroAtk number 武将最终ATK
--- @param heroDef number 武将最终DEF
--- @param levelMult number 等级成长倍率 (1 + (lv-1)*0.15)
--- @param hpMult number|nil 兵种HP倍率
--- @param atkMult number|nil 兵种ATK倍率
--- @param defMult number|nil 兵种DEF倍率
--- @return number hp
--- @return number atk
--- @return number def
function CalcSoldierStats(heroHp, heroAtk, heroDef, levelMult, hpMult, atkMult, defMult)
    local lm = levelMult or 1.0
    local hpM = hpMult or 1.0
    local atkM = atkMult or 1.0
    local defM = defMult or 1.0
    local hp  = (SOLDIER_BASE_HP  + heroHp  * SOLDIER_HP_SCALE)  * lm * hpM
    local atk = (SOLDIER_BASE_ATK + heroAtk * SOLDIER_ATK_SCALE) * lm * atkM
    local def = (SOLDIER_BASE_DEF + heroDef * SOLDIER_DEF_SCALE) * lm * defM
    return hp, atk, def
end


--- 获取车道中心Y坐标 (横屏: 车道沿Y轴分布, laneIdx: 1~5)
function GetLaneCenterY(laneIdx)
    return BATTLE_ZONE.top + (laneIdx - 0.5) * LANE_WIDTH
end

--- 获取单位行为模式 (从 ownerSlotIdx 查找对应英雄槽位的 behaviorMode)
--- 敌方单位始终 "attack"，玩家单位查槽位设定，兜底 gameState.behaviorMode
function GetUnitBehaviorMode(u)
    if not u.isPlayer then return "attack" end
    -- 优先检查兵种指令: 有移动/进攻指令时覆盖行为模式
    local order = GetTroopOrder(u)
    if order then
        return order.type == "attack" and "attack" or "move"
    end
    if u.ownerSlotIdx then
        local slot = PLAYER_SLOTS[u.ownerSlotIdx]
        if slot and slot.behaviorMode then
            return slot.behaviorMode
        end
    end
    return gameState.behaviorMode or "free"
end


--- 获取兵种指令 (玩家通过底部兵种按钮下达的移动/进攻指令)
--- @param u table 单位对象
--- @return table|nil 指令 {type="move"|"attack", x, y, time} 或 nil
function GetTroopOrder(u)
    if not u.isPlayer then return nil end
    if not u.troopType then return nil end
    local orders = gameState.troopOrders
    if not orders then return nil end
    return orders[u.troopType]
end


--- 将单位朝兵种指令目标移动 (move或attack指令通用)
--- @return boolean 是否已到达目标附近
function MoveTowardTroopOrder(u, dt, order)
    local dx = order.x - u.x
    local dy = order.y - u.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 20 then return true end  -- 已到达
    local spd = u.speed
    u.x = u.x + (dx / dist) * spd * dt
    u.y = u.y + (dy / dist) * spd * 0.6 * dt
    return false
end


--- 兼容旧代码: GetLaneCenterX 现在返回车道中心Y坐标
--- (横屏改造: 车道由X轴划分改为Y轴划分)
function GetLaneCenterX(laneIdx)
    return GetLaneCenterY(laneIdx)
end


--- 计算玩家单位动态上限 (基础40)
function GetPlayerUnitCap()
    return MAX_PLAYER_UNITS
end


--- 添加弹道特效 (从攻击者到目标的线性飞行)
function AddProjectile(sx, sy, tx, ty, color, isPlayer)
    if #projectiles >= 80 then return end  -- ★ 弹道上限，防止远程单位过多时积累
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
    if #particles >= 150 then return end  -- 粒子上限 (新特效需要稍多配额)
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
        isImpact = opts.isImpact or false,  -- 冲击环特效
        isSpark  = opts.isSpark  or false,  -- 火花拖尾特效
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
        return UNIT_CLASS[card.unitClass] or UNIT_CLASS.INFANTRY_LIGHT
    elseif gameState.isRanked then
        return UNIT_CLASS[card.unitClass] or UNIT_CLASS.INFANTRY_LIGHT
    else return UNIT_CLASS[card.unitClass] or UNIT_CLASS.DEMON_WARRIOR end
end


function SpawnPlayerUnit()
    if #playerUnits >= GetPlayerUnitCap() then return end
    -- 驻军派兵上限: 本场战斗派出的总兵力不超过出征驻军数
    if battleGarrisonCap > 0 and battlePlayerTotalSpawned >= battleGarrisonCap then return end
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
            local ucDef = UNIT_CLASS[entry.slot.card.unitClass or "INFANTRY_LIGHT"]
            local w = 1.0  -- 默认权重
            if ucDef and ucDef.isRanged then
                w = isFront and 0.8 or 1.5   -- 远程放后排概率+50%，放前排概率-20%
            else
                w = isFront and 1.5 or 0.8   -- 近战放前排概率+50%，放后排概率-20%
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
        -- 应用装备五维增幅
        local eqB = GetEquipmentBonus(card.cardIdx)
        cachedEqBonus = eqB  -- 缓存供单位属性注入
        local eHp  = cStats.hp  * (1 + eqB.vitAdd / 100)
        local eAtk = cStats.atk * (1 + eqB.strAdd / 100)
        local eDef = cStats.def * (1 + eqB.intAdd / 100)
        hp, atk, def = CalcSoldierStats(eHp, eAtk, eDef, lm, uc.hpMult, uc.atkMult, uc.defMult)
        breakDmgAdd = cStats.breakDmgAdd or 0
    else
        uc = UNIT_CLASS.INFANTRY_LIGHT; atk = 56; def = 14; hp = 180
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
        isHealer = (uc.isHealer == true),
        cloudSeed = math.random() * 100,
        breakDmgAdd = breakDmgAdd,
    }
    unit.homeX = unit.x
    unit.homeY = unit.y
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
    battlePlayerTotalSpawned = battlePlayerTotalSpawned + 1
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
        hp, atk, def = CalcSoldierStats(card.hp, card.atk, card.def, 1.0, uc.hpMult, uc.atkMult, uc.defMult)
    else
        uc = UNIT_CLASS.DEMON_WARRIOR
        atk = 52; def = 12; hp = 160
    end

    local bz = BATTLE_ZONE
    local eu = {
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
    }
    eu.homeX = eu.x
    eu.homeY = eu.y
    table.insert(enemyUnits, eu)
end


--- 每次部署的出兵数量（按品质: 人/地/天/神）
local BATCH_SIZE_BY_QUALITY = { [1] = 4, [2] = 5, [3] = 6, [4] = 8 }

--- 获取兵种实际出兵数 (大型兵种数量更少)
--- 返回 baseBatch, sealExtra (兵符额外兵力不受spawnMax限制)
function GetBatchSizeForSlot(slot)
    local quality = slot.card and slot.card.quality or 1
    local baseBatch = BATCH_SIZE_BY_QUALITY[quality] or 4
    local uc = GetUnitClassForCard(slot.card, true)
    if uc.spawnMax then
        baseBatch = math.min(baseBatch, uc.spawnMax)
    end
    return baseBatch
end


--- 从指定槽位生成一个战斗单位 (overrideLaneIdx: 手动部署时指定车道)
function SpawnUnitFromSlot(slot, isPlayer, overrideLaneIdx)
    -- 驻军派兵上限: 玩家方总兵力不超过出征驻军数
    if isPlayer and battleGarrisonCap > 0 and battlePlayerTotalSpawned >= battleGarrisonCap then
        return
    end
    local card = slot.card
    local uc = GetUnitClassForCard(card, isPlayer)
    local lm = 1 + ((card.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
    local cStats = ApplyConstellationStats(card)
    local bz = BATTLE_ZONE

    -- 车道分配
    local laneIdx
    if overrideLaneIdx then
        laneIdx = overrideLaneIdx
    elseif not isPlayer then
        laneIdx = EnemyPickLane()
    else
        laneIdx = slot.laneIdx or math.random(1, NUM_LANES)
    end
    local laneCY = GetLaneCenterY(laneIdx)
    local spawnY = laneCY + (math.random() - 0.5) * LANE_WIDTH * 0.6

    local unitHp, unitAtk, unitDef = CalcSoldierStats(cStats.hp, cStats.atk, cStats.def, lm, uc.hpMult, uc.atkMult, uc.defMult)
    local unit = {
        -- 部队在英雄列前方出生，使用完整部署区间
        x = isPlayer and (bz.playerDeployLeft + math.random() * (bz.playerDeployRight - bz.playerDeployLeft))
            or (bz.enemyDeployLeft + math.random() * (bz.enemyDeployRight - bz.enemyDeployLeft)),
        y = spawnY,
        hp = unitHp, maxHp = unitHp,
        atk = unitAtk, def = unitDef,
        speed = uc.speed + math.random() * 5,
        atkTimer = math.random() * 0.5, atkCooldown = uc.atkCd,
        atkRange = uc.atkRange,
        alive = true, isPlayer = isPlayer,
        isRanged = uc.isRanged, unitClass = uc,
        animTimer = math.random() * 6.28, flashTimer = 0,
        isHealer = (uc.isHealer == true),
        cloudSeed = math.random() * 100,
        breakDmgAdd = cStats.breakDmgAdd or 0,
        laneIdx = laneIdx,  -- 所属车道
        summonTimer = 0,    -- 傀儡操师召唤计时
        summonCount = 0,    -- 傀儡操师已召唤数
        troopType = card.troopType or "infantry", -- 兵种克制类型 (已在G_systems.lua中批量注入)
    }
    -- 记录所属英雄槽位索引 (供独立行为模式查找)
    if isPlayer then
        for si = 1, #PLAYER_SLOTS do
            if PLAYER_SLOTS[si] == slot then unit.ownerSlotIdx = si; break end
        end
    end
    -- 记录出生位置作为阵型原点 (供弓兵返回阵位)
    unit.homeX = unit.x
    unit.homeY = unit.y

    -- ===== 五维属性差异化加成 (仅玩家方, 基于武将 stats5) =====
    if isPlayer and card.stats5 then
        local s5 = card.stats5
        -- str(武力): ATK加成, 每点+0.3%
        if s5.str > 0 then
            unit.atk = unit.atk * (1 + s5.str * 0.003)
        end
        -- vit(体力): HP加成, 每点+0.3%
        if s5.vit > 0 then
            unit.hp = unit.hp * (1 + s5.vit * 0.003)
            unit.maxHp = unit.hp
        end
        -- spd(速度): 移速+攻速加成, 每点+0.2%
        if s5.spd > 0 then
            local spdMul = 1 + s5.spd * 0.002
            unit.speed = unit.speed * spdMul
            unit.atkCooldown = unit.atkCooldown / spdMul
        end
        -- tec(技力): 暴击率加成, 每点+0.1% (存储到单位上, 供战斗伤害判定使用)
        unit.stats5CritRate = (s5.tec or 0) * 0.001
        -- int(智力): 技能伤害加成, 存储在单位上供技能系统读取
        unit.stats5IntBonus = (s5.int or 0) * 0.003
    end

    -- 六德兵符战斗属性注入 (五维已通过 stats5 生效, 这里只注入暴击率)
    local sb = isPlayer and slot.cachedSealBonus or nil
    if sb then
        -- 勇符: 暴击率 (直接加算)
        unit.sealCritRate = sb.critRate or 0
    end

    -- 装备五维属性加成 (玩家方: strAdd→ATK, intAdd→DEF, vitAdd→HP)
    if isPlayer then
        local eqB = GetEquipmentBonus(card.cardIdx)
        if eqB.strAdd > 0 then unit.atk = unit.atk * (1 + eqB.strAdd / 100) end
        if eqB.intAdd > 0 then unit.def = unit.def * (1 + eqB.intAdd / 100) end
        if eqB.vitAdd > 0 then
            unit.hp = unit.hp * (1 + eqB.vitAdd / 100)
            unit.maxHp = unit.hp
        end
    end

    -- 装备套装额外词条注入 (玩家方, 与兵符叠加)
    if isPlayer then
        local eb = GetEquipmentBonus(card.cardIdx)
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

    -- 阵型+战术属性注入 (仅玩家方SLG战斗)
    if isPlayer then
        -- 战术攻防乘数
        local tacAtkM = rawget(_G, "battleTacticUnitAtkMult") or 1.0
        local tacDefM = rawget(_G, "battleTacticUnitDefMult") or 1.0
        if tacAtkM ~= 1.0 then unit.atk = unit.atk * tacAtkM end
        if tacDefM ~= 1.0 then unit.def = unit.def * tacDefM end
        -- 阵型弓兵攻击加成 (isRanged 单位)
        local archerBonus = rawget(_G, "battleFormationArcherAtkBonus") or 0
        if archerBonus > 0 and unit.isRanged then
            unit.atk = unit.atk * (1 + archerBonus)
        end
        -- 战术克制触发率注入 (叠加到装备克制率)
        local counterRateMult = rawget(_G, "battleTacticUnitCounterRate") or 1.0
        if counterRateMult ~= 1.0 then
            unit.equipCounterRate = (unit.equipCounterRate or 0) * counterRateMult
        end
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
                battlePlayerTotalSpawned = battlePlayerTotalSpawned + 1
            else table.insert(enemyUnits, swarmUnit) end
        end
        return  -- 虫群不再插入主单位
    end

    if isPlayer then
        table.insert(playerUnits, unit)
        battlePlayerTotalSpawned = battlePlayerTotalSpawned + 1
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
        isRanged = false, unitClass = UNIT_CLASS.INFANTRY_LIGHT,
        animTimer = math.random() * 6.28, flashTimer = 0,
        cloudSeed = math.random() * 100,
        breakDmgAdd = 0,
        laneIdx = master.laneIdx,
        isPuppet = true,  -- 标记为傀儡小兵
        summonTimer = 0, summonCount = 0,
    }
    table.insert(units, puppet)
end


--- 敌方AI选择车道：优先选玩家兵最多的车道进行拦截
function EnemyPickLane()
    local laneCounts = { 0, 0, 0, 0, 0 }
    for _, u in ipairs(playerUnits) do
        if u.alive and u.laneIdx then
            laneCounts[u.laneIdx] = laneCounts[u.laneIdx] + 1
        end
    end
    -- 找最多的车道，加一点随机性
    local maxCount = 0
    local candidates = {}
    for i = 1, NUM_LANES do
        if laneCounts[i] > maxCount then
            maxCount = laneCounts[i]
            candidates = { i }
        elseif laneCounts[i] == maxCount then
            table.insert(candidates, i)
        end
    end
    if maxCount == 0 then
        return math.random(1, NUM_LANES)
    end
    return candidates[math.random(1, #candidates)]
end


-- ★ AI 节流: 每帧只有 1/3 单位执行完整 AI 搜索，其余做轻量更新
local _aiFrameCounter = 0

function UpdateUnits(dt, units, targets, isPlayerSide)
    _aiFrameCounter = _aiFrameCounter + 1
    local frameSlot = _aiFrameCounter % 3  -- 0, 1, 2 交替

    for i, u in ipairs(units) do
        if u.alive then
            -- 区域减速: 临时降低速度, 帧末恢复
            local origSpeed = u.speed
            if u.zoneSlowUntil and gameState.gameTime < u.zoneSlowUntil then
                u.speed = u.speed * (1.0 - (u.zoneSlowFactor or 0))
                u.isZoneSlowed = true
            else
                u.isZoneSlowed = false
                u.zoneSlowUntil = nil
                u.zoneSlowFactor = nil
            end

            u.animTimer = u.animTimer + dt * 3
            if u.flashTimer > 0 then u.flashTimer = u.flashTimer - dt end
            if u.atkAnimTimer and u.atkAnimTimer > 0 then u.atkAnimTimer = u.atkAnimTimer - dt end

            -- ★ 节流: 非本帧轮次的单位 → 轻量更新（继续当前行为，跳过搜索）
            local fullAI = (i % 3 == frameSlot)
            local ucId = u.unitClass and u.unitClass.id or 1
            if not fullAI then
                -- 轻量更新: 正在攻击的继续攻击，正在移动的继续移动
                if u._cachedTarget and u._cachedTarget.alive then
                    -- 继续攻击缓存目标
                    AttackTarget(u, u._cachedTarget, dt, isPlayerSide)
                else
                    u._cachedTarget = nil
                    -- 继续向前推进
                    MoveTowardEnemyBase(u, dt, isPlayerSide)
                end
                u.speed = origSpeed
                goto continueUnit
            end

            -- ★ GOAP 目标优先级:
            --   1. 攻击范围内有敌人 → 无条件攻击 (最高优先级)
            --   2. 兵种移动/进攻指令 → 向目标移动 (中优先级)
            --   3. 默认AI行为 → 推进/追击 (低优先级)
            -- 例外: 治疗师(isHealer)、自爆亡魂(ucId==13) 有独立逻辑
            do
                local troopOrder = GetTroopOrder(u)
                if troopOrder and u.isPlayer then
                    -- ★ GOAP: 先检查攻击范围内是否有敌人 (全方位, 不限车道)
                    if not u.isHealer and ucId ~= 13 then
                        local goapTarget, goapDist = FindNearestEnemy(u, targets, u.atkRange)
                        if goapTarget and goapDist <= u.atkRange then
                            -- 攻击范围内有敌人 → 停下来打 (GOAP: 攻击 > 一切移动指令)
                            AttackTarget(u, goapTarget, dt, isPlayerSide)
                            if u.isRanged then u.rangedTarget = goapTarget end
                            u.speed = origSpeed
                            goto continueUnit
                        end
                    end
                    -- 无敌人在攻击范围 → 执行兵种移动指令
                    local arrived = MoveTowardTroopOrder(u, dt, troopOrder)
                    if not arrived then
                        u.speed = origSpeed
                        goto continueUnit
                    end
                    -- 已到达目标位置
                    if troopOrder.type == "move" then
                        ReturnToFormationPosition(u, dt)
                        u.speed = origSpeed
                        goto continueUnit
                    end
                    -- attack指令到达后 → 落入正常AI在目标点战斗
                end
            end

            if u.isHealer then
                -- 腐灵祭司: 跟随部队前进 + 沿途治疗 + 攻速光环
                u.atkTimer = u.atkTimer + dt
                if u.atkTimer >= u.atkCooldown then
                    local ally = FindLowestHPAlly(u, units)
                    if ally and ally.hp < ally.maxHp then
                        u.atkTimer = 0; u.atkAnimTimer = 0.4
                        local heal = u.atk * 0.8
                        ally.hp = math.min(ally.maxHp, ally.hp + heal)
                        AddFloatText(ally.x, ally.y - 15, "+" .. math.floor(heal * TROOP_DISPLAY_SCALE), 0.7, { 80, 255, 120 }, 20)
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
                                    AddFloatText(t.x, t.y - 10, math.floor(raw * TROOP_DISPLAY_SCALE), 0.5, { 255, 200, 80 }, 18)
                                end
                            end
                        end
                    end
                    -- 车道修正(Y轴)
                    local laneCY = GetLaneCenterY(u.laneIdx or 3)
                    local ldy = laneCY - u.y
                    if math.abs(ldy) > 5 then
                        u.y = u.y + (ldy > 0 and 1 or -1) * u.speed * 0.3 * dt
                    end
                end

            elseif ucId == 10 then
                -- 讨伐巨兽: 杀敌优先+范围攻击
                local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                if blockT then
                    -- 攻击范围内有敌人 → 停下来范围攻击
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
                            AddFloatText(u.x, u.y - 15, "震" .. hitCount .. "人", 0.6, { 255, 160, 50 }, 18)
                        end
                    end
                else
                    -- 没有攻击范围内的敌人 → 搜索附近敌人追击
                    local nearT, nearD = FindNearestEnemy(u, targets, 200)
                    if nearT then
                        local tdx, tdy = nearT.x - u.x, nearT.y - u.y
                        local dirX = tdx > 0 and 1 or (tdx < 0 and -1 or 0)
                        local dirY = tdy > 0 and 1 or (tdy < 0 and -1 or 0)
                        u.x = u.x + dirX * u.speed * dt
                        if math.abs(tdy) > 5 then
                            u.y = u.y + dirY * u.speed * 0.5 * dt
                        end
                    else
                        -- 附近无敌人才向基地推进
                        MoveTowardEnemyBase(u, dt, isPlayerSide)
                    end
                end

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
                    AddFloatText(u.x, u.y - 15, "召唤傀儡", 0.6, { 180, 100, 255 }, 18)
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
                    -- 攻击范围内有敌人 → 停下来远程攻击
                    AttackTarget(u, bestT, dt, isPlayerSide)
                else
                    -- 没有攻击目标 → 搜索附近敌人追击
                    local nearT, nearD = FindNearestEnemy(u, targets, 200)
                    if nearT then
                        local tdx, tdy = nearT.x - u.x, nearT.y - u.y
                        local dirX = tdx > 0 and 1 or (tdx < 0 and -1 or 0)
                        local dirY = tdy > 0 and 1 or (tdy < 0 and -1 or 0)
                        u.x = u.x + dirX * u.speed * dt
                        if math.abs(tdy) > 5 then
                            u.y = u.y + dirY * u.speed * 0.5 * dt
                        end
                    else
                        -- 附近无敌人才向基地推进
                        MoveTowardEnemyBase(u, dt, isPlayerSide)
                    end
                end

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
                        AddFloatText(bestT.x, bestT.y - 10, math.floor(raw * TROOP_DISPLAY_SCALE) .. " 冻", 0.5, { 100, 200, 255 }, 18)
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
                -- 蜂巢蝗群: 杀敌优先，极快攻速近距离群攻
                local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                if not blockT then
                    -- 搜索附近任意敌人
                    local nearT, nearD = FindNearestEnemy(u, targets, 150)
                    if nearT then blockT = nearT; blockD = nearD end
                end
                if blockT then
                    if blockD <= u.atkRange + 15 then
                        -- 在攻击范围内 → 停下来打
                        u.atkTimer = u.atkTimer + dt
                        if u.atkTimer >= u.atkCooldown then
                            u.atkTimer = 0; u.atkAnimTimer = 0.4
                            local raw = math.max(1, u.atk * 0.8)
                            blockT.hp = blockT.hp - raw
                            blockT.flashTimer = 0.1
                            if blockT.hp <= 0 then blockT.alive = false end
                        end
                    else
                        -- 有敌人但不在攻击范围 → 追击
                        local tdx, tdy = blockT.x - u.x, blockT.y - u.y
                        local dirX = tdx > 0 and 1 or (tdx < 0 and -1 or 0)
                        local dirY = tdy > 0 and 1 or (tdy < 0 and -1 or 0)
                        u.x = u.x + dirX * u.speed * dt
                        if math.abs(tdy) > 5 then
                            u.y = u.y + dirY * u.speed * 0.5 * dt
                        end
                    end
                else
                    -- 附近无敌人才推进
                    MoveTowardEnemyBase(u, dt, isPlayerSide)
                end

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
                -- 移动到站岗位置
                local laneCX = GetLaneCenterX(u.laneIdx or 3)
                local gdx = laneCX - u.x
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
                -- 远程射手(连弩射手/火攻术士/山贼弓手): 杀敌优先，有目标停下射击+弹道特效
                local bestT, bestD = nil, u.atkRange + 1
                for _, t in ipairs(targets) do
                    if t.alive then
                        local tdx, tdy = t.x - u.x, t.y - u.y
                        local td = math.sqrt(tdx * tdx + tdy * tdy)
                        if td < bestD then bestD = td; bestT = t end
                    end
                end
                if bestT and bestD <= u.atkRange then
                    -- 攻击范围内有目标：停下来射击
                    local prevTimer = u.atkTimer
                    AttackTarget(u, bestT, dt, isPlayerSide)
                    if u.atkTimer < prevTimer then
                        -- 攻击命中瞬间生成弹道特效
                        local projColor
                        if ucId == 4 then
                            projColor = {180, 130, 255}      -- 火攻术士: 紫色
                        elseif ucId == 7 then
                            projColor = {255, 80, 60}    -- 山贼弓手: 暗红
                        else projColor = {200, 230, 255} end               -- 连弩射手: 淡蓝
                        AddProjectile(u.x, u.y, bestT.x, bestT.y, projColor, isPlayerSide)
                    end
                    u.rangedTarget = bestT
                else
                    -- 攻击范围内无目标 → 根据行为指令决定
                    u.rangedTarget = nil
                    local bMode = GetUnitBehaviorMode(u)
                    local troopOrder = GetTroopOrder(u)
                    local nearT, nearD = FindNearestEnemy(u, targets, 250)
                    if troopOrder then
                        -- 有兵种指令 → 朝指令目标移动
                        MoveTowardTroopOrder(u, dt, troopOrder)
                    elseif bMode == "hold" then
                        -- 驻守: 原地不动，返回阵位
                        ReturnToFormationPosition(u, dt)
                    elseif bMode == "attack" and nearT then
                        -- 进攻: 向敌人前推
                        local tdx, tdy = nearT.x - u.x, nearT.y - u.y
                        u.x = u.x + (tdx > 0 and 1 or -1) * u.speed * dt
                        if math.abs(tdy) > 5 then
                            u.y = u.y + (tdy > 0 and 1 or -1) * u.speed * 0.5 * dt
                        end
                    elseif nearT and nearD > u.atkRange then
                        -- 自由: 仅调整Y轴接近
                        local tdy = nearT.y - u.y
                        if math.abs(tdy) > 5 then
                            u.y = u.y + (tdy > 0 and 1 or -1) * u.speed * 0.5 * dt
                        end
                    else
                        ReturnToFormationPosition(u, dt)
                    end
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
                            local dmgText = isCrit and "暴击!" .. math.floor(raw * TROOP_DISPLAY_SCALE) or math.floor(raw * TROOP_DISPLAY_SCALE)
                            AddFloatText(prioTarget.x, prioTarget.y - 10, dmgText, 0.6, dmgColor, isCrit and 22 or 18)
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
                    -- 没有后排目标 → 杀敌优先，找最近的敌人打
                    local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                    if blockT then
                        -- 攻击范围内有敌人 → 停下来打
                        AttackTarget(u, blockT, dt, isPlayerSide)
                    else
                        -- 搜索更大范围
                        local nearT, nearD = FindNearestEnemy(u, targets, 200)
                        if nearT then
                            local tdx, tdy = nearT.x - u.x, nearT.y - u.y
                            local dirX = tdx > 0 and 1 or (tdx < 0 and -1 or 0)
                            local dirY = tdy > 0 and 1 or (tdy < 0 and -1 or 0)
                            u.x = u.x + dirX * u.speed * dt
                            if math.abs(tdy) > 5 then
                                u.y = u.y + dirY * u.speed * 0.5 * dt
                            end
                        else
                            MoveTowardEnemyBase(u, dt, isPlayerSide)
                        end
                    end
                end

            elseif ucId == 12 then
                -- 骨矛枪兵: 杀敌优先+贯穿攻击
                local blockT, blockD = FindBlockingEnemy(u, targets, u.atkRange, isPlayerSide)
                if blockT then
                    -- 攻击范围内有敌人 → 停下来贯穿攻击
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
                        for si = 1, math.min(2, #sorted) do
                            local t = sorted[si].target
                            local atkDefMod = u.atk / (u.atk + t.def)
                            local raw = math.max(1, u.atk * atkDefMod)
                            t.hp = t.hp - raw
                            t.flashTimer = 0.15
                            AddFloatText(t.x, t.y - 10, math.floor(raw * TROOP_DISPLAY_SCALE), 0.5, { 200, 220, 255 }, 18)
                        end
                    end
                else
                    -- 无挡路敌人 → 搜索附近敌人追击或推进
                    local nearT, nearD = FindNearestEnemy(u, targets, 200)
                    if nearT then
                        local tdx, tdy = nearT.x - u.x, nearT.y - u.y
                        u.x = u.x + (tdx > 0 and 1 or -1) * u.speed * dt
                        if math.abs(tdy) > 5 then
                            u.y = u.y + (tdy > 0 and 1 or -1) * u.speed * 0.5 * dt
                        end
                    else
                        MoveTowardEnemyBase(u, dt, isPlayerSide)
                    end
                end

            elseif u.isRanged then
                -- ★ 通用远程AI: 所有 isRanged=true 的新弓兵子兵种走此分支
                local bestT, bestD = nil, u.atkRange + 1
                for _, t in ipairs(targets) do
                    if t.alive then
                        local tdx, tdy = t.x - u.x, t.y - u.y
                        local td = math.sqrt(tdx * tdx + tdy * tdy)
                        if td < bestD then bestD = td; bestT = t end
                    end
                end
                if bestT and bestD <= u.atkRange then
                    local prevTimer = u.atkTimer
                    AttackTarget(u, bestT, dt, isPlayerSide)
                    if u.atkTimer < prevTimer then
                        AddProjectile(u.x, u.y, bestT.x, bestT.y, {200, 230, 255}, isPlayerSide)
                    end
                    u.rangedTarget = bestT
                else
                    -- 根据行为指令决定远程移动
                    u.rangedTarget = nil
                    local bMode = GetUnitBehaviorMode(u)
                    local troopOrder = GetTroopOrder(u)
                    local nearT, nearD = FindNearestEnemy(u, targets, 250)
                    if troopOrder then
                        MoveTowardTroopOrder(u, dt, troopOrder)
                    elseif bMode == "hold" then
                        ReturnToFormationPosition(u, dt)
                    elseif bMode == "attack" and nearT then
                        local tdx, tdy = nearT.x - u.x, nearT.y - u.y
                        u.x = u.x + (tdx > 0 and 1 or -1) * u.speed * dt
                        if math.abs(tdy) > 5 then
                            u.y = u.y + (tdy > 0 and 1 or -1) * u.speed * 0.5 * dt
                        end
                    elseif nearT and nearD > u.atkRange then
                        local tdy = nearT.y - u.y
                        if math.abs(tdy) > 5 then
                            u.y = u.y + (tdy > 0 and 1 or -1) * u.speed * 0.5 * dt
                        end
                    else
                        ReturnToFormationPosition(u, dt)
                    end
                end

            else
                -- 默认近战AI: 杀敌优先
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
                    local bMode = GetUnitBehaviorMode(u)
                    -- ★ GOAP: 杀敌优先 - 全方位搜索攻击范围内的敌人(不限车道和方向)
                    local nearAtkT, nearAtkD = FindNearestEnemy(u, targets, u.atkRange)
                    if nearAtkT and nearAtkD <= u.atkRange then
                        -- 攻击范围内有敌人 → 停下来打 (最高优先级)
                        AttackTarget(u, nearAtkT, dt, isPlayerSide)
                    elseif bMode == "hold" then
                        -- 驻守模式: 不追击不推进，返回阵位
                        ReturnToFormationPosition(u, dt)
                    else
                        -- 进攻/自由模式: 搜索更大范围最近的敌人
                        local nearT, nearD = FindNearestEnemy(u, targets, 200)
                        if nearT then
                            -- 有敌人在感知范围内 → 追击
                            local tdx, tdy = nearT.x - u.x, nearT.y - u.y
                            local dirX = tdx > 0 and 1 or (tdx < 0 and -1 or 0)
                            local dirY = tdy > 0 and 1 or (tdy < 0 and -1 or 0)
                            u.x = u.x + dirX * u.speed * dt
                            if math.abs(tdy) > 5 then
                                u.y = u.y + dirY * u.speed * 0.5 * dt
                            end
                        else
                            -- 感知范围内无敌人 → 向前推进
                            MoveTowardEnemyBase(u, dt, isPlayerSide)
                        end
                    end
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
                                    AddFloatText(t.x, t.y - 10, math.floor(explDmg * TROOP_DISPLAY_SCALE), 0.5, { 200, 50, 50 }, 18)
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

            ::continueUnit::
            -- 恢复原始速度 (区域减速只在本帧生效)
            u.speed = origSpeed
        end
    end
end


--- 向敌方基地推进 (横屏: 沿X轴前进, 车道修正沿Y轴)
--- 单位到达战场边界后被钳制，不再穿越临界线
function MoveTowardEnemyBase(u, dt, isPlayerSide)
    local targetX = isPlayerSide and BATTLE_ZONE.enemyLine or BATTLE_ZONE.playerLine
    local laneCY = GetLaneCenterY(u.laneIdx or 3)
    local ddy = laneCY - u.y
    local ddx = targetX - u.x
    if math.abs(ddx) > 1 then
        local dirX = ddx > 0 and 1 or -1
        local yCorrect = 0
        if math.abs(ddy) > 5 then
            yCorrect = (ddy > 0 and 1 or -1) * u.speed * 0.3 * dt
        end
        u.x = u.x + dirX * u.speed * dt
        u.y = u.y + yCorrect
    end
    -- 边界钳制: 不允许越过临界线
    if isPlayerSide then
        u.x = math.min(u.x, BATTLE_ZONE.enemyLine - 5)
    else
        u.x = math.max(u.x, BATTLE_ZONE.playerLine + 5)
    end
end


--- 远程单位返回阵型原始位置 (不前推，保持后排)
--- 到达 homeX/homeY 附近后停止移动
function ReturnToFormationPosition(u, dt)
    local hx = u.homeX or u.x
    local hy = u.homeY or u.y
    local dx = hx - u.x
    local dy = hy - u.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 5 then
        local spd = u.speed * 0.8
        u.x = u.x + (dx / dist) * spd * dt
        u.y = u.y + (dy / dist) * spd * dt
    end
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


--- 查找挡路敌人 (行进优先模式: 只找同车道+在前方的敌人)
--- 所有普通兵种使用此函数，确保行军到基地为首要目标
function FindBlockingEnemy(unit, targets, atkRange, isPlayerSide)
    local laneTolerance = LANE_WIDTH * 0.7  -- 同车道纵向容差(Y轴)
    local best, bestD = nil, atkRange + 1
    for _, t in ipairs(targets) do
        if t.alive then
            local ddx = t.x - unit.x
            local ddy = t.y - unit.y
            -- 检查: 必须在前方 (横屏: 玩家向右推进 = X 增大方向)
            local isAhead = (isPlayerSide and ddx > 0) or (not isPlayerSide and ddx < 0)
            -- 检查: 大致同车道 (纵向距离 < 容差)
            local sameishLane = math.abs(ddy) < laneTolerance
            if isAhead and sameishLane then
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


--- 寻找最近的存活敌人 (不限车道, 用于追击)
function FindNearestEnemy(unit, targets, searchRange)
    local range = (searchRange or 200) + 1
    local bestSq = range * range  -- ★ 用平方距离比较，避免每次 sqrt
    local best = nil
    local ux, uy = unit.x, unit.y  -- 缓存局部变量
    for _, t in ipairs(targets) do
        if t.alive then
            local ddx = t.x - ux
            local ddy = t.y - uy
            local dSq = ddx * ddx + ddy * ddy
            if dSq < bestSq then bestSq = dSq; best = t end
        end
    end
    if best then return best, math.sqrt(bestSq) end
    return nil, 99999
end


--- 攻击目标 (从原UpdateUnits提取)
--- ★ 伤害已通过降低 SOLDIER_BASE_ATK / SOLDIER_ATK_SCALE 基础值实现平衡
---   无需全局乘数（旧 GLOBAL_DAMAGE_MULT 已移除，等效系数融入 game_config）

function AttackTarget(u, t, dt, isPlayerSide)
    u._cachedTarget = t  -- ★ 缓存攻击目标，节流帧可复用
    u.atkTimer = u.atkTimer + dt
    if u.atkTimer >= u.atkCooldown then
        u.atkTimer = 0; u.atkAnimTimer = 0.4
        local atkDefMod = u.atk / (u.atk + t.def)
        local raw = math.max(1, u.atk * atkDefMod)
        -- 溃不成军: 战力下降50%
        if u.routDebuff then raw = raw * 0.5 end
        -- 兵种克制倍率 (战争版)
        if u.troopType and t.troopType and rawget(_G, "GetTroopCounterMult") then
            raw = raw * GetTroopCounterMult(u.troopType, t.troopType)
        end
        -- 暴击率: 基础10% + 五维tec加成 + 兵符加成 + 装备词条加成
        local critChance = 0.1 + (u.stats5CritRate or 0) + (u.sealCritRate or 0) / 100 + (u.equipCritRate or 0) / 100
        local isCrit = math.random() < critChance
        if isCrit then raw = raw * 2.0 end
        -- 铁棺重卫护盾抗性: 减少受到的伤害
        if t.damageReduction and t.damageReduction > 0 then
            raw = raw * (1 - t.damageReduction)
        end
        -- 减伤: 装备词条
        local totalDmgReduction = (t.equipDmgReduction or 0)
        if totalDmgReduction > 0 then
            raw = raw * (1 - totalDmgReduction / 100)
        end
        t.hp = t.hp - raw
        -- 反击: 装备词条 (受击方概率反弹50%自身ATK伤害)
        local totalCounterRate = (t.equipCounterRate or 0)
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
        -- ★ 攻击命中特效: 冲击环 + 火花
        local hitColor = isPlayerSide and { 200, 230, 255 } or { 255, 100, 80 }
        -- 冲击环
        AddParticle(t.x, t.y, {
            vx = 0, vy = 0, life = 0.2, size = 4,
            color = hitColor, isImpact = true,
        })
        -- 2个飞散火花
        for _ = 1, 2 do
            local angle = math.random() * math.pi * 2
            local spd = 30 + math.random() * 40
            AddParticle(t.x, t.y, {
                vx = math.cos(angle) * spd,
                vy = math.sin(angle) * spd - 15,
                life = 0.2 + math.random() * 0.2,
                size = 1 + math.random() * 1.5,
                color = isCrit and { 255, 220, 80 } or hitColor,
                isSpark = true,
            })
        end
        if t.hp <= 0 then
            t.alive = false
            if isPlayerSide then
                gameState.totalKills = gameState.totalKills + 1
            end
            -- ★ 死亡特效: 扩散冲击环 + 碎片火花
            AddParticle(t.x, t.y, {
                vx = 0, vy = 0, life = 0.35, size = 8,
                color = isPlayerSide and { 180, 220, 255 } or { 255, 120, 60 },
                isImpact = true,
            })
            for _ = 1, 3 do
                local angle = math.random() * math.pi * 2
                local spd = 40 + math.random() * 60
                AddParticle(t.x, t.y, {
                    vx = math.cos(angle) * spd,
                    vy = math.sin(angle) * spd - 20,
                    life = 0.3 + math.random() * 0.2,
                    size = 1.5 + math.random() * 2,
                    color = { 255, 200, 100 },
                    isSpark = true,
                })
            end
            -- 死亡爆炸: 装备词条 (被击杀单位如果有死亡爆炸属性，对周围敌人造成AOE伤害)
            local totalDeathExplPct = (t.equipDeathExplosionPct or 0)
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
                -- 死亡爆炸特效 (紫红色扩散) ★ 12→4
                for _ = 1, 4 do
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
            -- ★ 死亡粒子: 8→3
            for _ = 1, 3 do
                AddParticle(t.x, t.y, {
                    vx = (math.random() - 0.5) * 120,
                    vy = -(math.random() * 60 + 10),
                    life = 0.5 + math.random() * 0.4,
                    size = 2 + math.random() * 2.5,
                    color = isPlayerSide and { 255, 160, 60 } or { 120, 200, 255 },
                })
            end
        end
        AddFloatText(t.x, t.y - 15, math.floor(raw * TROOP_DISPLAY_SCALE) .. (isCrit and "!" or ""),
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


--- 同侧单位分离碰撞 (禁止重叠, 最小间距20px, 推力300px/s)
-- ★ 分离碰撞: 随机采样法，避免 O(n²) 全量比较
-- 每帧每个单位与随机 8 个邻居做碰撞检测，多帧后收敛到均匀分布
function SeparateUnits(dt)
    local MIN_DIST = 20
    local PUSH_SPEED = 300
    local MAX_CHECKS = 8  -- 每个单位最多检查 8 个随机邻居
    local function separate(units)
        local n = #units
        if n < 2 then return end
        for i = 1, n do
            local a = units[i]
            if a.alive then
                local checks = math.min(MAX_CHECKS, n - 1)
                for _ = 1, checks do
                    local j = math.random(1, n)
                    if j ~= i then
                        local b = units[j]
                        if b.alive then
                            local dx = b.x - a.x
                            local dy = b.y - a.y
                            local dist = dx * dx + dy * dy  -- 先用平方距离快速排除
                            if dist < MIN_DIST * MIN_DIST then
                                dist = math.sqrt(dist)
                                if dist > 0.1 then
                                    local overlap = (MIN_DIST - dist) * 0.5
                                    local nx, ny = dx / dist, dy / dist
                                    local push = math.min(overlap, PUSH_SPEED * dt)
                                    a.x = a.x - nx * push
                                    a.y = a.y - ny * push
                                    b.x = b.x + nx * push
                                    b.y = b.y + ny * push
                                else
                                    local angle = math.random() * 6.28
                                    local push = PUSH_SPEED * dt
                                    a.x = a.x - math.cos(angle) * push
                                    a.y = a.y - math.sin(angle) * push
                                    b.x = b.x + math.cos(angle) * push
                                    b.y = b.y + math.sin(angle) * push
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    separate(playerUnits)
    separate(enemyUnits)
end
