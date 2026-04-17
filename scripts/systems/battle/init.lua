-- ============================================================================
-- systems/battle/init.lua - 三国武灵录
-- ============================================================================


--- 获取商店中未售出的卡牌数量 (全局, 供教程等远距离代码调用)
function GetUnsoldShopCardCount()
    local count = 0
    for _, card in ipairs(shopCards) do
        if not card.sold then count = count + 1 end
    end
    return count
end


--- 检查玩家是否还能购买商店中任意一张卡牌 (全局, 供教程调用)
function CanAffordAnyShopCard()
    for _, card in ipairs(shopCards) do
        if not card.sold and gameState.gold >= card.cost then
            return true
        end
    end
    return false
end


--- 检查是否有卡牌正在拖拽中 (全局, 供教程调用)
function IsDraggingCard()
    return dragState.active
end

-- ============================================================================

-- ============================================================================
-- 商店系统 (每回合刷新随机卡牌)
-- ============================================================================

--- 校验编队: 移除已不拥有的卡牌
function ValidateFormation()
    local cleaned = {}
    for _, idx in ipairs(gameSettings.formation) do
        if playerHeroes[idx] and playerHeroes[idx].owned and idx <= #HERO_CARDS then
            table.insert(cleaned, idx)
        end
    end
    gameSettings.formation = cleaned
end


--- 刷新商店: 优先从编队中随机选 SHOP_SIZE 张, 编队为空则从全部已拥有中选
function RefreshShop()
    shopCards = {}
    -- 校验编队有效性
    ValidateFormation()
    -- 构建卡池: 优先编队, 否则全部已拥有
    local pool = {}
    if #gameSettings.formation > 0 then
        -- 从编队中构建卡池
        for _, idx in ipairs(gameSettings.formation) do
            local info = playerHeroes[idx]
            if info and info.owned then
                table.insert(pool, { cardIdx = idx, quality = HERO_CARDS[idx].quality, constellation = info.constellation or 0 })
            end
        end
    end
    if #pool == 0 then
        -- 编队为空或无效, 回退到全部已拥有
        for idx, info in pairs(playerHeroes) do
            if info.owned and idx <= #HERO_CARDS then
                table.insert(pool, { cardIdx = idx, quality = HERO_CARDS[idx].quality, constellation = info.constellation or 0 })
            end
        end
    end
    if #pool == 0 then return end
    -- 随机选 SHOP_SIZE 张 (允许重复)
    for _ = 1, GameConfig.SHOP_SIZE do
        local pick = math.random(1, #pool)
        local item = pool[pick]
        local cost = GameConfig.CARD_COST[item.quality] or 5
        table.insert(shopCards, {
            cardIdx = item.cardIdx,
            quality = item.quality,
            cost = cost,
            constellation = item.constellation,
            sold = false,
        })
    end
end


function InitBattle()
    playerUnits = {}
    enemyUnits = {}
    floatTexts = {}
    particles = {}
    inventory = {}
    invScrollOffset = 0
    shopCards = {}

    -- 清空石台
    for _, slot in ipairs(PLAYER_SLOTS) do
        slot.filled = false; slot.card = nil
    end
    for _, slot in ipairs(ENEMY_SLOTS) do
        slot.filled = false; slot.card = nil
    end

    -- 应用战斗布局 (背景图 + 石台位置)
    -- layoutId: 0=默认, 1~7=讨伐层; 数组索引 = layoutId + 1
    if gameState.abyssFloor then
        ApplyBattleLayout(gameState.abyssFloor + 1)  -- 讨伐层1→索引2, 层7→索引8
    elseif gameState.towerFloor then
        -- 爬塔: 循环使用讨伐背景 (层数 mod 7 + 1 → 索引2~8)
        local bgIdx = ((gameState.towerFloor - 1) % 7) + 1
        ApplyBattleLayout(bgIdx + 1)
    else
        -- 应用玩家默认战场偏好 (非讨伐/非爬塔)
        local defBf = gameSettings.defaultBattlefield or 1
        if defBf >= 1 and defBf <= 8 then
            ApplyBattleLayout(defBf)
        else
            local stageInfo = STAGES[stageState.currentStage] or STAGES[1]
            ApplyBattleLayout(stageInfo.layoutIdx or 1)
        end
    end

    -- 重置战斗状态 (三国群英传模式: 直接进入FIGHT, 无SHOP阶段)
    gameState.gold = 0  -- 三国群英传模式无军资
    gameState.totalKills = 0
    gameState.playerBaseHP = BASE_HP_MAX
    gameState.playerBaseMax = BASE_HP_MAX
    gameState.enemyBaseHP = BASE_HP_MAX
    gameState.battlePhase = "FIGHT"  -- 直接进入战斗
    gameState.goldTimer = 0
    gameState.battleTime = 0
    gameState.autoMarch = true  -- 三国群英传模式: 始终自动行军
    gameState.autoMarchStrategy = "all_lanes"  -- 默认五路并进
    gameState.battleSpeed = 1       -- 重置倍速
    gameState.exploreBuff = nil     -- 清空探索增益 (探索模式会重新设置)
    gameState.autoBattle = false    -- 重置自动战斗, 允许玩家操控兵种
    autoBattleTimer = 0
    autoSkillState.timer = 0
    autoSkillState.nextTime = 3.0
    strategyWheelState.show = false
    strategyWheelState.pressing = false
    battleRulesState.show = false
    playerSpawnTimer = 0
    enemySpawnTimer = 0

    -- 敌方随机部署 (应用关卡难度缩放)
    local eScale = 1.0
    if gameState.abyssFloor then
        local abyssFloor = abyssState.floors[gameState.abyssFloor]
        eScale = abyssFloor and abyssFloor.enemyScale or 1.0
    elseif gameState.towerFloor then
        -- 爬塔: 1.15^层数 基础递增 + 每100层额外跳增(500层前×1.1, 500层后×2)
        local fl = gameState.towerFloor
        eScale = math.pow(1.15, fl)
        local tier100 = math.floor(fl / 100)
        if tier100 > 0 then
            if fl <= 500 then
                -- 500层及以下: 每100层×1.1
                eScale = eScale * math.pow(1.1, tier100)
            else
                -- 500层以上: 前5个100层用×1.1, 之后每100层×2
                local lowTiers = 5  -- 100~500层的5个阶段
                local highTiers = tier100 - lowTiers  -- 500层以上的阶段数
                eScale = eScale * math.pow(1.1, lowTiers) * math.pow(2.0, highTiers)
            end
        end
    else
        local stageInfo = STAGES[stageState.currentStage] or STAGES[1]
        eScale = stageInfo.enemyScale or 1.0
    end
    local enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 1))
    local used = {}
    for i = 1, enemyCount do
        local idx
        repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
        used[idx] = true
        if i <= #ENEMY_SLOTS then
            local card = DeepCopy(ENEMY_CARDS[idx])
            card.level = 1
            card.constellation = 0
            card.cardIdx = idx
            -- 应用关卡难度缩放到敌方属性
            card.hp = math.floor(card.hp * eScale)
            card.atk = math.floor(card.atk * eScale)
            card.def = math.floor(card.def * eScale)
            ENEMY_SLOTS[i].filled = true
            ENEMY_SLOTS[i].card = card
            ENEMY_SLOTS[i].spawnTimer = 0
            ENEMY_SLOTS[i].spawnCount = 0
            ENEMY_SLOTS[i].spawnFlash = 0
        end
    end

    -- === 三国群英传模式: 自动部署玩家编队武灵到石台 ===
    ValidateFormation()
    local formationPool = {}
    if #gameSettings.formation > 0 then
        for _, idx in ipairs(gameSettings.formation) do
            local info = playerHeroes[idx]
            if info and info.owned and idx <= #HERO_CARDS then
                table.insert(formationPool, { cardIdx = idx, quality = HERO_CARDS[idx].quality, constellation = info.constellation or 0 })
            end
        end
    end
    if #formationPool == 0 then
        -- 编队为空, 回退到全部已拥有
        for idx, info in pairs(playerHeroes) do
            if info.owned and idx <= #HERO_CARDS then
                table.insert(formationPool, { cardIdx = idx, quality = HERO_CARDS[idx].quality, constellation = info.constellation or 0 })
            end
        end
    end
    -- 部署到玩家石台 (最多填满所有PLAYER_SLOTS)
    for i = 1, math.min(#formationPool, #PLAYER_SLOTS) do
        local item = formationPool[i]
        local heroData = HERO_CARDS[item.cardIdx]
        if heroData then
            local card = DeepCopy(heroData)
            card.level = playerHeroes[item.cardIdx] and playerHeroes[item.cardIdx].level or 1
            card.constellation = item.constellation
            card.cardIdx = item.cardIdx
            SetupSlotHero(PLAYER_SLOTS[i], card)
        end
    end

    -- 汇聚武灵属性到大本营
    AggregateBaseStats()

    -- === 三国群英传模式: 开局一次性生成全部兵力 ===
    local function SpawnAllTroopsForSide(slots, isPlayer, unitList, maxUnits)
        for si, slot in ipairs(slots) do
            if slot.filled and slot.card then
                local batchSize = GetBatchSizeForSlot(slot)
                -- 每个武灵一次性派出全部兵力
                local spawnCount = math.min(batchSize * 2, maxUnits - #unitList)
                for _ = 1, spawnCount do
                    if #unitList < maxUnits then
                        local laneIdx = math.random(1, NUM_LANES)
                        SpawnUnitFromSlot(slot, isPlayer, laneIdx, isPlayer and si or nil)
                    end
                end
                slot.spawnCount = spawnCount
                slot.deployCD = 9999  -- 不再补兵
            end
        end
    end
    SpawnAllTroopsForSide(PLAYER_SLOTS, true, playerUnits, MAX_PLAYER_UNITS)
    SpawnAllTroopsForSide(ENEMY_SLOTS, false, enemyUnits, MAX_ENEMY_UNITS)

    -- ============================================================
    -- 同盟援军: 有军事同盟的势力派兵支援
    -- ============================================================
    if rawget(_G, "worldMapState") and worldMapState.diplomacy then
        local bz = BATTLE_ZONE
        local allyAidCount = 0
        for fac, d in pairs(worldMapState.diplomacy) do
            if d.treaty == "alliance" and TREATY_DEFS and TREATY_DEFS.alliance then
                local aidNum = TREATY_DEFS.alliance.aidTroops or 30
                local facName = FACTIONS[fac] and FACTIONS[fac].name or fac
                local facColor = FACTIONS[fac] and FACTIONS[fac].color or {180, 180, 180}
                -- 生成援军 (使用基础步兵属性, 根据同盟方城池数量缩放)
                local facCityCount = 0
                for _, city in ipairs(WORLD_CITIES) do
                    if worldMapState.cityData[city.id] and worldMapState.cityData[city.id].owner == fac then
                        facCityCount = facCityCount + 1
                    end
                end
                local aidScale = 0.8 + facCityCount * 0.1  -- 城多则援军更强
                for ai = 1, aidNum do
                    if #playerUnits >= MAX_PLAYER_UNITS then break end
                    local spawnY = bz.top + 20 + math.random() * (bz.bottom - bz.top - 40)
                    local baseHp = 800 * aidScale
                    local aidUnit = {
                        x = bz.playerDeployLeft + 5 + math.random() * 15,
                        y = spawnY,
                        hp = baseHp, maxHp = baseHp,
                        atk = 60 * aidScale, def = 30 * aidScale,
                        speed = 45 + math.random() * 10,
                        atkTimer = math.random() * 0.5, atkCooldown = 1.0,
                        atkRange = 35,
                        alive = true, isPlayer = true,
                        isRanged = false, unitClass = UNIT_CLASS.SWORD or UNIT_CLASS.INFANTRY,
                        animTimer = math.random() * 6.28, flashTimer = 0,
                        isHealer = false,
                        cloudSeed = math.random() * 100,
                        breakDmgAdd = 0,
                        cmdType = "advance", cmdTarget = nil, cmdDone = false,
                        summonTimer = 0, summonCount = 0,
                        troopType = "infantry",
                        isAllyAid = true,       -- 标记为援军
                        allyFaction = fac,       -- 来自哪个势力
                        allyColor = facColor,    -- 援军颜色
                    }
                    table.insert(playerUnits, aidUnit)
                    allyAidCount = allyAidCount + 1
                end
                print("[Alliance] " .. facName .. " 派出 " .. aidNum .. " 援军!")
            end
        end
        if allyAidCount > 0 and rawget(_G, "AddFloatText") then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25, "同盟援军到达! +" .. allyAidCount, 2.0, {120, 100, 255}, 18)
        end
    end

    -- 武将技能系统已移除: techIdx仅作拜师学武技数据, 战斗中不自动释放
    heroSkillSystem.slots = {}
    heroSkillSystem.effects = {}

    -- ============================================================
    -- 阵型系统: 根据玩家选择的阵型调整部署位置和属性
    -- ============================================================
    local formDef = FORMATION_DEFS[playerFormation]
    if formDef then
        local bz = BATTLE_ZONE
        for _, u in ipairs(playerUnits) do
            if u.alive then
                -- 属性修正
                u.atk = u.atk * (1 + (formDef.atkMod or 0))
                u.def = u.def * (1 + (formDef.defMod or 0))
                u.speed = u.speed * (1 + (formDef.spdMod or 0))
                if formDef.hpMod then
                    u.hp = u.hp * (1 + formDef.hpMod)
                    u.maxHp = u.maxHp * (1 + formDef.hpMod)
                end
                -- 部署位置调整
                local pat = formDef.deployPattern
                local midY = (bz.top + bz.bottom) / 2
                local rangeY = (bz.bottom - bz.top) * 0.4
                if pat == "wide" then
                    -- 鹤翼: Y轴分散到两翼
                    local offset = (u.y - midY) / rangeY
                    u.y = midY + offset * rangeY * 1.3
                    u.x = u.x + math.abs(offset) * 15 -- 两翼靠前
                elseif pat == "cone" then
                    -- 锥行: X轴前推, Y轴收拢
                    u.x = u.x + 20
                    u.y = midY + (u.y - midY) * 0.6
                elseif pat == "tight" then
                    -- 方圆: 紧凑聚拢
                    u.y = midY + (u.y - midY) * 0.5
                    u.x = u.x - 10
                elseif pat == "layered" then
                    -- 鱼鳞: 分层排列 (默认基本不动)
                end
            end
        end
    end

    -- ============================================================
    -- 战斗地形生成: 随机放置2-4个地形区块
    -- ============================================================
    battleTerrainZones = {}
    local bz = BATTLE_ZONE
    local zoneCount = math.random(2, 4)
    local terrainPool = { "forest", "swamp", "highland" }  -- 平原不用放, 默认就是
    for _ = 1, zoneCount do
        local tw = 60 + math.random() * 60   -- 60~120 宽
        local th = 50 + math.random() * 50   -- 50~100 高
        local tx = bz.left + 40 + math.random() * (bz.right - bz.left - tw - 80)
        local ty = bz.top + 20 + math.random() * (bz.bottom - bz.top - th - 40)
        local terrain = terrainPool[math.random(1, #terrainPool)]
        table.insert(battleTerrainZones, {
            x = tx, y = ty, w = tw, h = th,
            terrain = terrain,
        })
    end

    -- 初始化 RTS 指令系统
    if InitRTS then InitRTS() end

    print(string.format("=== 三国群英传模式 进入战斗 | 阵型:%s 地形区块:%d | 我军:%d 敌军:%d ===",
        formDef and formDef.name or "无", #battleTerrainZones, #playerUnits, #enemyUnits))
end


--- 将卡牌部署到石台时初始化武灵属性
function SetupSlotHero(slot, card)
    slot.filled = true
    slot.card = card
    -- 派兵系统
    slot.spawnTimer = 0
    slot.spawnCount = 0
    slot.spawnFlash = 0
    slot.deployCD = 0  -- 部署冷却 (0=可部署)
end


--- 汇聚武灵属性到大本营 (开战时调用)
--- 将所有上阵武灵的HP/ATK/DEF汇总, 加成到基地上
function AggregateBaseStats()
    local pHpBonus, pAtkBonus, pDefBonus = 0, 0, 0
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            local card = slot.card
            local lm = 1 + ((card.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
            local bonus = GetConstellationBonus(card.constellation or 0)
            local baseAtk = math.floor(card.atk * bonus.atkMult * lm)
            local baseDef = math.floor(card.def * bonus.defMult * lm)
            local baseHp  = math.floor(card.hp  * bonus.hpMult  * lm)
            -- 兵符加成 (六欲差异化)
            local cardIdx = card.cardIdx
            if cardIdx then
                local sb = GetSealTotalBonus(cardIdx)
                baseAtk = math.floor(baseAtk * (1 + sb.atkPct / 100))
                baseDef = math.floor(baseDef * (1 + sb.defPct / 100))
                baseHp  = math.floor(baseHp  * (1 + sb.hpPct  / 100))
                -- 缓存完整兵符加成供战斗使用
                slot.cachedSealBonus = sb
            else
                slot.cachedSealBonus = nil
            end
            pHpBonus  = pHpBonus  + baseHp
            pAtkBonus = pAtkBonus + baseAtk
            pDefBonus = pDefBonus + baseDef
        end
    end
    local eHpBonus, eAtkBonus, eDefBonus = 0, 0, 0
    for _, slot in ipairs(ENEMY_SLOTS) do
        if slot.filled and slot.card then
            local card = slot.card
            eHpBonus  = eHpBonus  + math.floor(card.hp)
            eAtkBonus = eAtkBonus + math.floor(card.atk)
            eDefBonus = eDefBonus + math.floor(card.def)
        end
    end
    -- 探索增益 (atk_bonus / def_bonus / enemy_buff)
    local eb = gameState.exploreBuff
    if eb and gameState.explorationMode then
        if eb.type == "atk_bonus" then
            pAtkBonus = math.floor(pAtkBonus * (1 + eb.value))
        elseif eb.type == "def_bonus" then
            pDefBonus = math.floor(pDefBonus * (1 + eb.value))
        elseif eb.type == "enemy_buff" then
            eAtkBonus = math.floor(eAtkBonus * (1 + eb.value))
            eDefBonus = math.floor(eDefBonus * (1 + eb.value))
            eHpBonus  = math.floor(eHpBonus  * (1 + eb.value))
        end
    end
    -- 汇聚到基地
    gameState.playerBaseHP  = BASE_HP_MAX + pHpBonus
    gameState.playerBaseMax = gameState.playerBaseHP
    gameState.playerBaseATK = pAtkBonus
    gameState.playerBaseDEF = pDefBonus
    gameState.enemyBaseHP   = BASE_HP_MAX + eHpBonus
    gameState.enemyBaseMax  = gameState.enemyBaseHP
    gameState.enemyBaseATK  = eAtkBonus
    gameState.enemyBaseDEF  = eDefBonus
    print(string.format("=== 属性汇聚 | 玩家HP:%d ATK:%d DEF:%d | 敌方HP:%d ATK:%d DEF:%d ===",
        gameState.playerBaseHP, gameState.playerBaseATK, gameState.playerBaseDEF,
        gameState.enemyBaseHP, gameState.enemyBaseATK, gameState.enemyBaseDEF))
end


--- 实时刷新玩家基地属性 (放置/交换/移除武灵时调用)
--- 按比例保留当前HP，不会满血重置
function RefreshBaseStats()
    local pHpBonus, pAtkBonus, pDefBonus = 0, 0, 0
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            local card = slot.card
            local lm = 1 + ((card.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
            local bonus = GetConstellationBonus(card.constellation or 0)
            local baseAtk = math.floor(card.atk * bonus.atkMult * lm)
            local baseDef = math.floor(card.def * bonus.defMult * lm)
            local baseHp  = math.floor(card.hp  * bonus.hpMult  * lm)
            -- 兵符加成 (六欲差异化)
            local cardIdx = card.cardIdx
            if cardIdx then
                local sb = GetSealTotalBonus(cardIdx)
                baseAtk = math.floor(baseAtk * (1 + sb.atkPct / 100))
                baseDef = math.floor(baseDef * (1 + sb.defPct / 100))
                baseHp  = math.floor(baseHp  * (1 + sb.hpPct  / 100))
                slot.cachedSealBonus = sb
            else
                slot.cachedSealBonus = nil
            end
            pHpBonus  = pHpBonus  + baseHp
            pAtkBonus = pAtkBonus + baseAtk
            pDefBonus = pDefBonus + baseDef
        end
    end
    -- 探索增益 (atk_bonus / def_bonus)
    local eb = gameState.exploreBuff
    if eb and gameState.explorationMode then
        if eb.type == "atk_bonus" then
            pAtkBonus = math.floor(pAtkBonus * (1 + eb.value))
        elseif eb.type == "def_bonus" then
            pDefBonus = math.floor(pDefBonus * (1 + eb.value))
        end
    end
    local newMax = BASE_HP_MAX + pHpBonus
    local oldMax = math.max(1, gameState.playerBaseMax)
    local hpRatio = gameState.playerBaseHP / oldMax
    gameState.playerBaseMax = newMax
    gameState.playerBaseHP  = math.max(1, math.floor(newMax * hpRatio))
    gameState.playerBaseATK = pAtkBonus
    gameState.playerBaseDEF = pDefBonus
end


-- ============================================================================
-- 命格属性计算
-- ============================================================================

--- 获取命格加成表
function GetConstellationBonus(constellation)
    local c = math.max(0, math.min(constellation or 0, GameConfig.MAX_CONSTELLATION))
    return GameConfig.CONSTELLATION_BONUS[c] or GameConfig.CONSTELLATION_BONUS[0]
end


--- 计算应用命格加成后的实际属性
function ApplyConstellationStats(card)
    local bonus = GetConstellationBonus(card.constellation)
    return {
        atk = math.floor(card.atk * bonus.atkMult),
        def = math.floor(card.def * bonus.defMult),
        hp  = math.floor(card.hp  * bonus.hpMult),
        breakDmgAdd   = bonus.breakDmgAdd,
        spawnRateMult = bonus.spawnRateMult,
    }
end


function CalcShopLayout()
    local sl = shopLayout
    sl.h = SHOP_RESERVED_H
    sl.y = screenH - sl.h

    sl.cardH = sl.h - 32
    sl.cardW = sl.cardH * CARD_RATIO
    sl.gap = 6

    -- 可见卡牌数
    local visCount = GameConfig.INVENTORY_VISIBLE
    -- 翻页箭头宽度
    local arrowW = 22
    -- 抽卡按钮宽度
    local drawBtnW = 60

    local totalCardsW = visCount * sl.cardW + (visCount - 1) * sl.gap
    local totalW = arrowW + 6 + totalCardsW + 6 + arrowW + 10 + drawBtnW
    sl.startX = (screenW - totalW) / 2 + arrowW + 6

    -- 左箭头区域
    sl.arrowLeftX = sl.startX - 6 - arrowW
    sl.arrowLeftW = arrowW
    -- 右箭头区域
    sl.arrowRightX = sl.startX + totalCardsW + 6
    sl.arrowRightW = arrowW

    -- 抽卡按钮
    sl.drawBtnW = drawBtnW
    sl.drawBtnH = 36
    sl.drawBtnX = sl.arrowRightX + arrowW + 10
    sl.drawBtnY = sl.y + sl.h / 2 - sl.drawBtnH / 2 - 2
end
