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


--- DEPLOY阶段确定性排列: 按兵种类型分区部署,同一阵型永远产生相同布局
--- infantry(步兵)前排, spear(枪兵)中前, cavalry(骑兵)中后, archer(弓兵)后排
function ArrangeUnitsInFormation(units, isPlayer)
    local bz = BATTLE_ZONE
    local deployLeft  = isPlayer and bz.playerDeployLeft or bz.enemyDeployLeft
    local deployRight = isPlayer and bz.playerDeployRight or bz.enemyDeployRight
    local deployW = deployRight - deployLeft
    local margin = 12

    -- 获取当前阵型的兵种区域配置
    local formId = isPlayer and deploySelectedFormation or (gameState.enemyFormationId or "fish_scale")
    local form = nil
    for _, f in ipairs(FORMATIONS) do if f.id == formId then form = f; break end end
    local zones = (form and form.troopZones) or DEFAULT_TROOP_ZONES

    -- 按 baseTroop 分组
    local troopGroups = {}  -- baseTroop → {unit1, unit2, ...}
    for _, u in ipairs(units) do
        local bt = (u.unitClass and u.unitClass.baseTroop) or "infantry"
        if not troopGroups[bt] then troopGroups[bt] = {} end
        table.insert(troopGroups[bt], u)
    end

    -- 全部 5 车道
    local allLanes = {1, 2, 3, 4, 5}

    -- 对每组兵种，在其指定的 X 区域 + 车道内确定性排列
    for bt, group in pairs(troopGroups) do
        local zone = zones[bt] or zones.infantry or DEFAULT_TROOP_ZONES.infantry
        local xR = zone.xRange or {0.0, 1.0}
        local usableW = deployW - margin * 2
        local xMin = deployLeft + margin + xR[1] * usableW
        local xMax = deployLeft + margin + xR[2] * usableW

        -- 可用车道
        local lanes = zone.lanePrefer or allLanes
        local count = #group
        local numLanes = #lanes

        for i, u in ipairs(group) do
            -- 车道: 循环分配到可用车道
            local laneSlotIdx = ((i - 1) % numLanes) + 1
            local li = lanes[laneSlotIdx]
            u.laneIdx = li

            -- X 位置: 同一车道内的单位在 xMin-xMax 区间均匀分布
            local rowIdx = math.floor((i - 1) / numLanes)        -- 第几排
            local totalRows = math.ceil(count / numLanes)         -- 总排数
            local tx = totalRows > 1 and (rowIdx / (totalRows - 1)) or 0.5

            if isPlayer then
                -- 玩家: xMin(最前) → xMax(最后)
                u.x = xMin + tx * (xMax - xMin)
            else
                -- 敌方: 镜像排列 (前排在右侧)
                u.x = deployRight - margin - xR[1] * usableW - tx * (xMax - xMin)
            end

            -- Y 位置: 在车道中心附近按同车道内的序号微调
            local laneCY = GetLaneCenterY(li)
            -- 同一车道同一兵种有多少人
            local sameCount = math.ceil(count / numLanes)
            local posInLane = rowIdx
            local yOff = sameCount > 1 and ((posInLane / (sameCount - 1) - 0.5) * LANE_WIDTH * 0.35) or 0
            u.y = laneCY + yOff

            -- 记录阵型原始位置，供 AI 返回阵位使用
            u.homeX = u.x
            u.homeY = u.y
        end
    end
end

function InitBattle()
    playerUnits = {}
    enemyUnits = {}
    floatTexts = {}
    particles = {}
    -- 重置派兵计数 (世界地图战斗由 slg_logic 在此之前设置 battleGarrisonCap)
    -- 关卡/讨伐/爬塔战斗不受驻军上限约束，故默认重置为0(无限制)
    -- slg_logic 会在 InitBattle 之前将 battleGarrisonCap 设为实际驻军数
    battleGarrisonCap = 0
    battlePlayerTotalSpawned = 0
    battleTroopScale = 1
    TROOP_DISPLAY_SCALE = 1
    inventory = {}
    invScrollOffset = 0
    shopCards = {}

    -- SLG 世界地图战斗: slg_logic.StartAttack 已预设 PLAYER_SLOTS, 跳过自动填充
    local wmsCtx = rawget(_G, "worldMapState")
    local isSLGBattle = wmsCtx and wmsCtx.attackContext

    -- 清空石台
    if not isSLGBattle then
        for _, slot in ipairs(PLAYER_SLOTS) do
            slot.filled = false; slot.card = nil
        end
    end
    -- SLG 战斗: slg_logic.StartAttack 已预设 ENEMY_SLOTS, 不清空
    local slgEnemyPreset = isSLGBattle and wmsCtx.attackContext and wmsCtx.attackContext.enemySlotsPreset
    if not slgEnemyPreset then
        for _, slot in ipairs(ENEMY_SLOTS) do
            slot.filled = false; slot.card = nil
        end
    end

    -- 自动填充玩家英雄槽 (从编队/已拥有武灵中按优先级选取)
    -- SLG 战斗跳过: 武将已在 StartAttack 中按 deployHeroes 设置
    if isSLGBattle then goto skip_player_fill end
    do
        local filled = 0
        local usedIdx = {}
        -- 优先按编队顺序
        local formation = (gameSettings and gameSettings.formation) or {}
        for _, cardIdx in ipairs(formation) do
            if filled >= #PLAYER_SLOTS then break end
            local info = playerHeroes and playerHeroes[cardIdx]
            if info and info.owned and HERO_CARDS[cardIdx] and not usedIdx[cardIdx] then
                usedIdx[cardIdx] = true
                filled = filled + 1
                local baseCard = HERO_CARDS[cardIdx]
                local card = DeepCopy(baseCard)
                card.cardIdx   = cardIdx
                card.level     = info.level or 1
                card.constellation = info.constellation or 0
                SetupSlotHero(PLAYER_SLOTS[filled], card)
            end
        end
        -- 若编队不足，从全部已拥有中补充 (按品质降序)
        if filled < #PLAYER_SLOTS then
            local candidates = {}
            for cardIdx, info in pairs(playerHeroes or {}) do
                if info.owned and HERO_CARDS[cardIdx] and not usedIdx[cardIdx] then
                    candidates[#candidates + 1] = { cardIdx = cardIdx, quality = HERO_CARDS[cardIdx].quality or 1 }
                end
            end
            table.sort(candidates, function(a, b) return a.quality > b.quality end)
            for _, c in ipairs(candidates) do
                if filled >= #PLAYER_SLOTS then break end
                local info = playerHeroes[c.cardIdx]
                local baseCard = HERO_CARDS[c.cardIdx]
                local card = DeepCopy(baseCard)
                card.cardIdx   = c.cardIdx
                card.level     = info.level or 1
                card.constellation = info.constellation or 0
                filled = filled + 1
                SetupSlotHero(PLAYER_SLOTS[filled], card)
            end
        end
        print(string.format("[InitBattle] 玩家英雄上阵: %d 位", filled))

        -- ===== 计算上阵武将平均智力加成 (用于全局技能伤害/冷却) =====
        local totalInt = 0
        local intCount = 0
        for _, slot in ipairs(PLAYER_SLOTS) do
            if slot.filled and slot.card and slot.card.stats5 then
                totalInt = totalInt + (slot.card.stats5.int or 0)
                intCount = intCount + 1
            end
        end
        local avgInt = intCount > 0 and (totalInt / intCount) or 0
        -- 技能伤害加成: 每点INT +0.3%, 冷却缩减: 每点INT +0.15% (上限30%)
        battleIntSkillMult = 1 + avgInt * 0.003
        battleIntCdReduction = math.min(0.30, avgInt * 0.0015)
        print(string.format("[InitBattle] 五维INT加成: 平均INT=%.0f, 技能伤害×%.2f, 冷却-%.1f%%",
            avgInt, battleIntSkillMult, battleIntCdReduction * 100))
    end
    ::skip_player_fill::

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

    -- 重置战斗状态
    gameState.gold = 0              -- 军资不再使用，归零
    gameState.totalKills = 0
    gameState.playerBaseHP = BASE_HP_MAX
    gameState.playerBaseMax = BASE_HP_MAX
    gameState.enemyBaseHP = BASE_HP_MAX
    gameState.battlePhase = "DEPLOY" -- 进入备战阶段，等玩家点击"出征"
    gameState.goldTimer = 0
    gameState.battleTime = 0
    gameState.autoMarch = false     -- 默认不自动行军，玩家手动控制
    gameState.autoMarchStrategy = "all_lanes"  -- 默认五路并进
    gameState.behaviorMode = "free" -- 默认自由指令
    gameState.battleSpeed = 1       -- 重置倍速
    gameState.exploreBuff = nil     -- 清空探索增益 (探索模式会重新设置)
    -- autoBattle 不重置, 保持玩家上次的选择
    autoBattleTimer = 0
    autoSkillState.timer = 0
    autoSkillState.nextTime = 12.0  -- 开战后12秒再释放首次武技，给玩家观察时间
    gameState.deployCountdown = nil -- 出征倒计时 (点击出征后3秒倒计)
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
        -- SLG 世界地图战斗: slg_logic 在 InitBattle 前设置了 stageState.enemyScale
        -- 普通关卡战斗: 使用 STAGES 表中的 enemyScale
        if stageState.enemyScale and stageState.enemyScale > 0 then
            eScale = stageState.enemyScale
            stageState.enemyScale = nil  -- 使用后清除，避免影响后续普通关卡
        else
            local stageInfo = STAGES[stageState.currentStage] or STAGES[1]
            eScale = stageInfo.enemyScale or 1.0
        end
    end
    -- 计算敌方动态等级 (SLG: 基于城池等级和武将; 爬塔: 基于层数; 关卡: 基于关卡序号)
    local enemyLevel = 1
    -- wmsCtx 已在上方定义, 此处复用
    if wmsCtx and wmsCtx.attackContext then
        -- SLG 战斗: 敌方等级 = 城池等级, 最低1级 (与slg_logic预设一致)
        local toData = wmsCtx.cityData and wmsCtx.cityData[wmsCtx.attackContext.toId]
        if toData then
            enemyLevel = math.max(1, toData.level or 1)
        end
    elseif gameState.towerFloor then
        enemyLevel = math.max(1, math.floor(gameState.towerFloor / 3) + 1)
    elseif stageState.currentStage then
        enemyLevel = math.max(1, math.floor(stageState.currentStage / 3) + 1)
    end

    -- SLG 战斗: ENEMY_SLOTS 已由 slg_logic.StartAttack 预设, 跳过随机填充
    local enemyCount = 0
    if slgEnemyPreset then
        -- 统计已预设的敌方武将数
        for _, slot in ipairs(ENEMY_SLOTS) do
            if slot.filled then enemyCount = enemyCount + 1 end
        end
    else
        enemyCount = math.min(#ENEMY_SLOTS, 3 + math.random(0, 1))
        local used = {}
        for i = 1, enemyCount do
            local idx
            repeat idx = math.random(1, #ENEMY_CARDS) until not used[idx]
            used[idx] = true
            if i <= #ENEMY_SLOTS then
                local card = DeepCopy(ENEMY_CARDS[idx])
                card.level = enemyLevel
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
    end

    -- 汇聚属性 (DEPLOY阶段仅计算属性，不出兵)
    AggregateBaseStats()

    -- ======= 阵型/战术/士气效果 (仅 SLG 世界地图战斗有 attackContext) =======
    local wms = rawget(_G, "worldMapState")
    if wms and wms.attackContext then
        ApplyFormationEffects(wms.selectedFormation)
        ApplyTacticEffects(wms.selectedTactic)
        ApplyMoraleEffects(wms.attackContext.fromId)
    else
        -- 非 SLG 战斗：使用默认阵型 (玩家可在 DEPLOY 阶段切换)
        battleTacticId = nil; battleTacticUnitAtkMult = 1.0
        battleTacticUnitDefMult = 1.0; battleTacticUnitCounterRate = 1.0
        battleTacticCounterReflectBonus = 0; battleMoraleLabel = ""
        deploySelectedFormation = DEFAULT_FORMATION_ID
        ApplyFormationEffects(DEFAULT_FORMATION_ID)
        -- 随机给敌方一个阵型 (供克制计算)
        local enemyForms = {"fish_scale","crane_wing","arrowhead","square","wild_goose"}
        gameState.enemyFormationId = enemyForms[math.random(1, #enemyForms)]
    end

    -- DEPLOY阶段: 预生成所有单位(冻结不动), 等玩家点击"出征"后才开始厮杀
    -- 初始化每个武将的预选车道
    for i, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            slot.deployLane = slot.deployLane or ((i - 1) % NUM_LANES + 1) -- 默认分散到5路
            slot.deployCD = 0
            slot.spawnCount = 0
            slot.behaviorMode = slot.behaviorMode or "free" -- 每英雄独立行为模式: free/hold/attack
        end
    end

    -- === 计算SLG战斗动态缩放 & 精灵数量 ===
    local MAX_SPRITES_PER_SIDE = 200
    local slgPlayerTroops = 0  -- SLG战斗: 玩家出征兵力(内部值)
    local slgEnemyTroops = 0   -- SLG战斗: 敌方驻军(内部值)
    battleTroopScale = 1       -- 重置动态缩放

    if isSLGBattle and wmsCtx and wmsCtx.attackContext then
        slgPlayerTroops = wmsCtx.attackContext.attackTroops or 0
        local toData = wmsCtx.cityData and wmsCtx.cityData[wmsCtx.attackContext.toId]
        slgEnemyTroops = toData and toData.garrison or 0
        -- 动态缩放: 任一方兵力超过200时, 每个精灵代表更多人
        local maxSide = math.max(slgPlayerTroops, slgEnemyTroops)
        if maxSide > MAX_SPRITES_PER_SIDE then
            battleTroopScale = math.ceil(maxSide / MAX_SPRITES_PER_SIDE)
            TROOP_DISPLAY_SCALE = battleTroopScale
        else
            TROOP_DISPLAY_SCALE = 1
        end
    end

    -- === 预生成玩家单位 (按阵型排列, 冻结在己方区域) ===
    local totalPlayerSpawned = 0
    if isSLGBattle and slgPlayerTroops > 0 then
        -- SLG战斗: 精灵数 = 兵力 / battleTroopScale, 按武将均分
        local targetSprites = math.min(MAX_SPRITES_PER_SIDE, math.max(1, math.floor(slgPlayerTroops / battleTroopScale)))
        local filledSlots = {}
        for _, slot in ipairs(PLAYER_SLOTS) do
            if slot.filled and slot.card then
                filledSlots[#filledSlots + 1] = slot
            end
        end
        if #filledSlots > 0 then
            local perSlot = math.floor(targetSprites / #filledSlots)
            local remainder = targetSprites - perSlot * #filledSlots
            for si, slot in ipairs(filledSlots) do
                local count = perSlot + (si <= remainder and 1 or 0)
                for _ = 1, count do
                    local laneIdx = slot.deployLane or PickFormationLane()
                    SpawnUnitFromSlot(slot, true, laneIdx)
                    totalPlayerSpawned = totalPlayerSpawned + 1
                end
                slot.deployCD = 0
                slot.spawnCount = (slot.spawnCount or 0) + count
            end
        end
    else
        -- 非SLG战斗: 保持原有batch逻辑
        for _, slot in ipairs(PLAYER_SLOTS) do
            if slot.filled and slot.card then
                local batchSize = GetBatchSizeForSlot(slot)
                local unitCap = GetPlayerUnitCap()
                for _ = 1, batchSize do
                    if #playerUnits < unitCap then
                        local laneIdx = slot.deployLane or PickFormationLane()
                        SpawnUnitFromSlot(slot, true, laneIdx)
                        totalPlayerSpawned = totalPlayerSpawned + 1
                    end
                end
                slot.deployCD = 0
                slot.spawnCount = (slot.spawnCount or 0) + batchSize
            end
        end
    end

    -- === 预生成敌方单位 (随机分布在敌方区域, 冻结) ===
    local totalEnemySpawned = 0
    if isSLGBattle and slgEnemyTroops > 0 then
        -- SLG战斗: 敌方精灵数 = 敌方驻军 / battleTroopScale
        local targetSprites = math.min(MAX_SPRITES_PER_SIDE, math.max(1, math.floor(slgEnemyTroops / battleTroopScale)))
        local filledESlots = {}
        for _, slot in ipairs(ENEMY_SLOTS) do
            if slot.filled and slot.card then
                filledESlots[#filledESlots + 1] = slot
            end
        end
        if #filledESlots > 0 then
            local perSlot = math.floor(targetSprites / #filledESlots)
            local remainder = targetSprites - perSlot * #filledESlots
            for si, slot in ipairs(filledESlots) do
                local count = perSlot + (si <= remainder and 1 or 0)
                for _ = 1, count do
                    local laneIdx = math.random(1, NUM_LANES)
                    SpawnUnitFromSlot(slot, false, laneIdx)
                    totalEnemySpawned = totalEnemySpawned + 1
                end
                slot.deployCD = 0
            end
        end
    else
        -- 非SLG战斗: 保持原有batch逻辑
        for _, slot in ipairs(ENEMY_SLOTS) do
            if slot.filled and slot.card then
                local batchSize = GetBatchSizeForSlot(slot)
                for _ = 1, batchSize do
                    if #enemyUnits < MAX_ENEMY_UNITS then
                        local laneIdx = math.random(1, NUM_LANES)
                        SpawnUnitFromSlot(slot, false, laneIdx)
                        totalEnemySpawned = totalEnemySpawned + 1
                    end
                end
                slot.deployCD = 0
            end
        end
    end

    -- 确定性排列: 同阵型永远同布局
    ArrangeUnitsInFormation(playerUnits, true)
    ArrangeUnitsInFormation(enemyUnits, false)

    print(string.format("=== 进入备战阶段(DEPLOY) | 玩家出兵:%d 敌方出兵:%d | 武将:%d vs %d | 阵型:%s 战术:%s | 缩放:%d ===",
        totalPlayerSpawned, totalEnemySpawned,
        #PLAYER_SLOTS, enemyCount,
        battleFormationId or "无", battleTacticId or "无",
        battleTroopScale))
end


--- 从DEPLOY阶段正式开战: 解冻所有预生成单位, 进入FIGHT
function StartBattleFromDeploy()
    gameState.battlePhase = "FIGHT"
    gameState.autoMarch = false  -- 兵力固定，不再自动行军
    gameState.battleTime = 0

    -- 记录初始兵力 (用于胜负判定和星级计算)
    gameState.initialPlayerUnits = #playerUnits
    gameState.initialEnemyUnits = #enemyUnits

    -- 重置所有槽位部署CD (一次性预部署，无需冷却)
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled then slot.deployCD = 0 end
    end
    for _, slot in ipairs(ENEMY_SLOTS) do
        if slot.filled then slot.deployCD = 0 end
    end

    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "出征!", 1.5, { 255, 220, 80 }, 24)
    PlaySFX(AUDIO.sfx_march)

    print(string.format("=== 出征! 解冻全部兵力 | 玩家兵:%d 敌方兵:%d | 阵型:%s 战术:%s ===",
        #playerUnits, #enemyUnits,
        battleFormationId or "无", battleTacticId or "无"))
end


--- DEPLOY 阶段切换阵型: 重算属性 + 重新生成玩家单位
function SwitchDeployFormation(formId)
    if not gameState or gameState.battlePhase ~= "DEPLOY" then return end
    if formId == deploySelectedFormation then return end

    local form = nil
    for _, f in ipairs(FORMATIONS) do if f.id == formId then form = f; break end end
    if not form then return end

    deploySelectedFormation = formId

    -- 重置基础属性再应用新阵型 (避免累乘)
    AggregateBaseStats()
    ApplyFormationEffects(formId)
    if battleTacticId then ApplyTacticEffects(battleTacticId) end

    -- 直接重新排列已有单位位置（不清空、不重生）
    ArrangeUnitsInFormation(playerUnits, true)

    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, form.name, 1.0, { 255, 220, 100 }, 18)
    PlaySFX(AUDIO.sfx_click)

    print(string.format("[SwitchDeployFormation] → %s | 玩家兵:%d | ATK:%d DEF:%d",
        form.name, #playerUnits,
        gameState.playerBaseATK or 0, gameState.playerBaseDEF or 0))
end

-- ============================================================================
-- 阵型效果应用 (在 AggregateBaseStats 之后调用)
-- ============================================================================
function ApplyFormationEffects(formId)
    -- 重置
    battleFormationId = nil; battleFormationLaneWeights = nil
    battleFormationArcherAtkBonus = 0; battleFormationCounterReflect = 0
    local baseCd = DEPLOY_CD
    if not formId or not rawget(_G, "FORMATIONS") then
        battleDeployCd = baseCd; return
    end
    local f = nil
    for _, v in ipairs(FORMATIONS) do if v.id == formId then f = v; break end end
    if not f then battleDeployCd = baseCd; return end

    battleFormationId           = f.id
    battleFormationLaneWeights  = f.laneWeights
    battleFormationArcherAtkBonus = f.archerAtkBonus or 0
    battleFormationCounterReflect = f.counterDmgReflect or 0
    -- 阵型 CD 乘数 (战术乘数在 ApplyTacticEffects 中再叠乘)
    battleDeployCd = math.max(1.2, baseCd * (f.spawnCdMult or 1.0))
    -- 将攻防乘数叠加到已汇聚的基础属性
    local atkM = f.playerAtkMult or 1.0
    local defM = f.playerDefMult or 1.0
    if rawget(_G, "gameState") then
        gameState.playerBaseATK = math.floor((gameState.playerBaseATK or 0) * atkM)
        gameState.playerBaseDEF = math.floor((gameState.playerBaseDEF or 0) * defM)
    end
    print(string.format("[Formation] %s | CD=%.2f ATK×%.2f DEF×%.2f",
        f.name, battleDeployCd, atkM, defM))
end

-- ============================================================================
-- 战术效果应用 (在 ApplyFormationEffects 之后调用，进一步叠乘 CD)
-- ============================================================================
function ApplyTacticEffects(tacticId)
    battleTacticId = nil
    battleTacticUnitAtkMult = 1.0; battleTacticUnitDefMult = 1.0
    battleTacticUnitCounterRate = 1.0; battleTacticCounterReflectBonus = 0
    if not tacticId or not rawget(_G, "TACTIC_DEFS") then return end
    local td = nil
    for _, v in ipairs(TACTIC_DEFS) do if v.id == tacticId then td = v; break end end
    if not td then return end

    battleTacticId = td.id
    battleTacticUnitAtkMult     = td.unitAtkMult or 1.0
    battleTacticUnitDefMult     = td.unitDefMult or 1.0
    battleTacticUnitCounterRate = td.counterRateMult or 1.0
    battleTacticCounterReflectBonus = td.counterReflectBonus or 0
    -- 战术 CD 乘数叠加 (阵型已先设好 battleDeployCd)
    battleDeployCd = math.max(1.2, battleDeployCd * (td.spawnCdMult or 1.0))
    print(string.format("[Tactic] %s | CD=%.2f ATK×%.2f DEF×%.2f CounterRate×%.2f",
        td.name, battleDeployCd, battleTacticUnitAtkMult,
        battleTacticUnitDefMult, battleTacticUnitCounterRate))
end

-- ============================================================================
-- 士气效果应用 (在 AggregateBaseStats + ApplyFormationEffects 之后调用)
-- ============================================================================
function ApplyMoraleEffects(fromCityId)
    battleMoraleLabel = ""
    if not fromCityId or not rawget(_G, "worldMapState") then return end
    if not rawget(_G, "MORALE_MULTIPLIER_TABLE") then return end
    local cityData = worldMapState.cityData
    if not cityData or not cityData[fromCityId] then return end
    local morale = cityData[fromCityId].morale or 60
    local tier = nil
    for _, row in ipairs(MORALE_MULTIPLIER_TABLE) do
        if morale >= row.min and morale <= row.max then tier = row; break end
    end
    if not tier then return end
    battleMoraleLabel = tier.label
    if rawget(_G, "gameState") then
        gameState.playerBaseATK = math.floor((gameState.playerBaseATK or 0) * tier.atkMult)
        gameState.playerBaseDEF = math.floor((gameState.playerBaseDEF or 0) * tier.defMult)
    end
    print(string.format("[Morale] %d → %s ATK×%.2f DEF×%.2f",
        morale, tier.label, tier.atkMult, tier.defMult))
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
