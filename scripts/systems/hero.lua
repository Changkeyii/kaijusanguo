-- ============================================================================
-- systems/hero.lua - 三国武灵录
-- ============================================================================


--- 获取某页总星数
function GetPageStars(page)
    local startIdx = (page - 1) * STAGE_PAGE_SIZE + 1
    local endIdx = math.min(page * STAGE_PAGE_SIZE, #STAGES)
    local total = 0
    for i = startIdx, endIdx do
        total = total + (stageStars[tostring(i)] or 0)
    end
    return total
end

--- 全局函数：获取武技名称（供 exploration.lua 等模块调用）
function GetSkillTechniqueName(idx)
    local tech = SKILL_TECHNIQUES[idx]
    return tech and tech.name or ("武技#" .. idx)
end


-- ============================================================================
-- 石台槽位
-- ============================================================================
function MakeSlot(bgX, bgY)
    return { cx = bgX * BG2D_X, cy = bgY * BG2D_Y, filled = false, card = nil }
end


--- 获取已部署武灵槽位数 (全局, 供教程等远距离代码调用)
function GetPlayerFilledSlotCount()
    local count = 0
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then count = count + 1 end
    end
    return count
end


-- 武技评分: 基于阶级战斗伤害值 × 层数加成 (每层+20%)
function GetSkillScore(skillIdx)
    local tech = SKILL_TECHNIQUES[skillIdx]
    if not tech then return 0 end
    local baseDmg = TIER_BATTLE_STATS[tech.tier].damage
    local layer = skillLayers[skillIdx] or 1
    return math.floor(baseDmg * (1 + (layer - 1) * 0.2))
end


-- 玩家总评分 (已装备兵甲 + 已装备武技)
function GetPlayerTotalScore()
    local score = 0
    for slotIdx = 1, 7 do
        score = score + GetEquippedSlotScore(slotIdx)
    end
    for _, skillIdx in ipairs(playerEquippedSkills) do
        score = score + GetSkillScore(skillIdx)
    end
    return score
end

-- 战力评分系统 (纯局外统一公式)
-- ============================================================================
-- 战力 = 装备评分 + 最高4武灵评分 + 武技分
-- 所有分数只看局外持久化数据，不涉及战斗状态

--- 武灵评分: 基础属性综合 × 命格 × 等级成长
--- 公式: (atk*2 + def + hp*0.1) × levelMult
function CalcHeroPowerScore(card)
    local lm = 1 + ((card.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
    local cStats = ApplyConstellationStats(card)
    local atk, def, hp = cStats.atk, cStats.def, cStats.hp
    -- 兵符加成
    if card.cardIdx then
        local sb = GetSealTotalBonus(card.cardIdx)
        atk = math.floor(atk * (1 + sb.atkPct / 100))
        def = math.floor(def * (1 + sb.defPct / 100))
        hp  = math.floor(hp  * (1 + sb.hpPct  / 100))
    end
    local power = (atk * 2 + def + hp * 0.1) * lm
    return math.floor(power)
end


--- 境界显示名: "新生三级" 格式
function GetRankDisplayName(rankIdx)
    rankIdx = rankIdx or playerInfo.rankIdx or 1
    local layers = GameConfig.REALM_LAYERS or 10
    local realmIdx = math.ceil(rankIdx / layers)
    local layerIdx = ((rankIdx - 1) % layers) + 1
    local realmName = GameConfig.PLAYER_REALMS[realmIdx] or "大将军"
    local layerName = GameConfig.CHINESE_NUMS[layerIdx] or tostring(layerIdx)
    return realmName .. layerName .. "级"
end


function CalcRankPowerScore()
    local idx = playerInfo.rankIdx or 1
    return RANK_POWER_TABLE[idx] or 0
end


--- 武技战力: 复用 GetSkillScore
function CalcSkillPowerScore()
    local power = 0
    for _, skillIdx in ipairs(playerEquippedSkills) do
        power = power + GetSkillScore(skillIdx)
    end
    return power
end


--- 装备总评分: 7个槽位已装备评分之和
function CalcEquipPowerScore()
    local power = 0
    for slotIdx = 1, 7 do
        power = power + GetEquippedSlotScore(slotIdx)
    end
    return power
end


--- 敌方单卡评分 (与玩家同口径, 无等级/命格/装备, 加 enemyScale)
function CalcEnemyPowerScore(card, enemyScale)
    enemyScale = enemyScale or 1.0
    local power = (card.atk * 2 + card.def + card.hp * 0.1) * enemyScale
    return math.floor(power)
end


--- 估算某个 enemyScale 下的推荐总战力 (纯敌方武灵战力, 不含玩家自身分)
function CalcStageRequiredPower(enemyScale)
    -- 敌方武灵战力 (实际战斗中部署 3-4 个敌人, 用平均值 * 3.5 估算)
    local totalAtk, totalDef, totalHp = 0, 0, 0
    for _, ec in ipairs(ENEMY_CARDS) do
        totalAtk = totalAtk + ec.atk
        totalDef = totalDef + ec.def
        totalHp  = totalHp  + ec.hp
    end
    local n = #ENEMY_CARDS
    local unitPow = (totalAtk / n * 2 + totalDef / n + totalHp / n * 0.1) * enemyScale
    local enemyHeroPower = unitPow * 3.5
    local totalPower = enemyHeroPower
    local minRequired = math.floor(totalPower * 0.7)
    local recommended = math.floor(totalPower * 1.0)
    return math.floor(totalPower), minRequired, recommended
end


--- 计算敌方阵容总战力 (纯武灵战力)
function CalcEnemyTotalPower(slots, enemyScale)
    local heroPower = 0
    for _, slot in ipairs(slots) do
        if slot.filled and slot.card then
            heroPower = heroPower + CalcEnemyPowerScore(slot.card, enemyScale)
        end
    end
    return heroPower
end


--- 计算战力比 (玩家/敌方, 同口径)
function CalcPowerRatio(playerSlots, enemySlots, enemyScale)
    local pp = CalcPlayerTotalPower()
    local ep = CalcEnemyTotalPower(enemySlots, enemyScale)
    if ep == 0 then return 99.0 end
    return pp / ep
end


--- 获取战力等级评价
function GetPowerGrade(ratio)
    if ratio >= 2.0 then
        return "碾压", {80, 255, 80}
    elseif ratio >= 1.5 then
        return "优势", {120, 220, 160}
    elseif ratio >= 1.1 then
        return "均势", {220, 220, 120}
    elseif ratio >= 0.8 then
        return "劣势", {255, 180, 80}
    else
        return "危险", {255, 80, 80}
    end
end


--- 获取玩家拥有的所有英雄 (纯局外, 只读持久化数据)
function GetAllOwnedHeroes()
    local heroes = {}
    for cardIdx, hero in pairs(playerHeroes) do
        if hero.owned then
            local baseCard = HERO_CARDS[cardIdx]
            if baseCard then
                table.insert(heroes, {
                    atk = baseCard.atk,
                    def = baseCard.def,
                    hp = baseCard.hp,
                    level = hero.level or 1,
                    constellation = hero.constellation or 0,
                    name = baseCard.name,
                    cardIdx = cardIdx,
                })
            end
        end
    end
    return heroes
end


--- 计算玩家总战力 (纯局外统一公式)
--- 战力 = 装备评分 + 最高4武灵评分 + 武技分
--- 注: 境界分不影响实际战斗,已从战力公式中移除
function CalcPlayerTotalPower()
    -- 1. 装备评分
    local equipPower = CalcEquipPowerScore()
    -- 2. 最高4武灵评分
    local allHeroes = GetAllOwnedHeroes()
    local heroPowers = {}
    for _, card in ipairs(allHeroes) do
        table.insert(heroPowers, CalcHeroPowerScore(card))
    end
    table.sort(heroPowers, function(a, b) return a > b end)
    local heroPower = 0
    local count = math.min(4, #heroPowers)
    for i = 1, count do
        heroPower = heroPower + heroPowers[i]
    end
    -- 3. 武技分
    local skillPower = CalcSkillPowerScore()
    local basePower = equipPower + heroPower + skillPower
    -- 4. 阵营等级加成 + 职位额外加成
    local factionBuff = 0
    if rawget(_G, "CloudManager") and CloudManager.GetFactionLevelInfo then
        local lvInfo = CloudManager.GetFactionLevelInfo()
        if lvInfo and lvInfo.totalBuffPercent and lvInfo.totalBuffPercent > 0 then
            factionBuff = math.floor(basePower * lvInfo.totalBuffPercent / 100)
        end
    end
    return basePower + factionBuff
end


--- 编队一键自动填充: 按品质优先选前 targetCount 个武灵
--- 获取已拥有武灵总数
--- @return number
function GetOwnedHeroCount()
    local count = 0
    for _, info in pairs(playerHeroes) do
        if info.owned then count = count + 1 end
    end
    return count
end


--- 一键编队: 按品质优先选前 FORMATION_MAX 个武灵
--- @return number ownedCount 已拥有总数
function AutoFillFormation()
    local FORMATION_MAX = 10
    local ownedCount = 0
    local owned = {}
    for idx = 1, #HERO_CARDS do
        local hero = playerHeroes[idx]
        if hero and hero.owned then
            ownedCount = ownedCount + 1
            table.insert(owned, { cardIdx = idx, quality = HERO_CARDS[idx].quality })
        end
    end
    local targetCount = math.min(FORMATION_MAX, ownedCount)
    -- 按品质降序排列
    table.sort(owned, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.cardIdx < b.cardIdx
    end)
    gameSettings.formation = {}
    for i = 1, targetCount do
        table.insert(gameSettings.formation, owned[i].cardIdx)
    end
    SaveSettings()
    return ownedCount
end
