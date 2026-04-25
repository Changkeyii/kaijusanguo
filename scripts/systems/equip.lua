-- ============================================================================
-- systems/equip.lua - 三国武灵录
-- ============================================================================


--- 根据品阶生成随机装备等级 (1-30)
function RollEquipLevel(tier)
    local t = tier or 1
    -- 阶级越高，初始等级范围越高
    local minLv = math.min(1 + (t - 1) * 2, EQUIP_LEVEL_MAX)
    local maxLv = math.min(minLv + 5, EQUIP_LEVEL_MAX)
    return math.random(minLv, maxLv)
end


--- 获取装备等级带来的基础属性加成
function GetLevelBonus(level)
    return ((level or 1) - 1) * EQUIP_LEVEL_BONUS
end


--- 创建一件新兵甲并加入owned，返回该兵甲对象
function CreateEquipItem(setIdx, slotIdx, tier, quality, level)
    local q = quality or math.random(0, 100)
    local lv = level or RollEquipLevel(tier)
    local item = {
        uid = playerEquipment.nextUid,
        setIdx = setIdx,
        slotIdx = slotIdx,
        tier = tier,
        quality = q,
        enhanceLv = 0,
        level = lv,  -- 装备自身等级 (1-30), 独立于强化
        heroIdx = nil, -- nil=仓库中, 数字=已装备给某武将
    }
    playerEquipment.nextUid = playerEquipment.nextUid + 1
    table.insert(playerEquipment.owned, item)
    return item
end


--- 根据uid查找兵甲对象，返回 (item, index)
function FindOwnedByUid(uid)
    for i, item in ipairs(playerEquipment.owned) do
        if item.uid == uid then return item, i end
    end
    return nil, nil
end


--- 根据uid移除兵甲
function RemoveOwnedByUid(uid)
    for i, item in ipairs(playerEquipment.owned) do
        if item.uid == uid then
            table.remove(playerEquipment.owned, i)
            return item
        end
    end
    return nil
end


--- 获取仓库中可用于某槽位的兵甲列表（未装备给任何武将 + 已装备给指定武将的）
--- heroIdx: 可选, 传入时也包含该武将已装备的装备
function GetOwnedForSlot(slotIdx, heroIdx)
    local list = {}
    for _, item in ipairs(playerEquipment.owned) do
        if item.slotIdx == slotIdx then
            -- 仓库中 (未装备) 或 已装备给当前查看的武将
            if not item.heroIdx or item.heroIdx == heroIdx then
                table.insert(list, item)
            end
        end
    end
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then return a.tier > b.tier end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.uid < b.uid
    end)
    return list
end


--- 获取某武将某槽位已装备的兵甲对象
--- heroIdx: 武将索引 (必须)
function GetEquippedItem(slotIdx, heroIdx)
    if not heroIdx then return nil end
    local heroEquip = playerEquipment.equipped[heroIdx]
    if not heroEquip then return nil end
    local uid = heroEquip[slotIdx]
    if not uid then return nil end
    return FindOwnedByUid(uid)
end


--- 给武将装备一件兵甲 (从仓库或从其他武将卸下)
function EquipItemToHero(heroIdx, slotIdx, uid)
    if not heroIdx or not uid then
        print("[Equip] FAIL: heroIdx=" .. tostring(heroIdx) .. " uid=" .. tostring(uid))
        return false
    end
    local item = FindOwnedByUid(uid)
    if not item then
        print("[Equip] FAIL: item not found uid=" .. tostring(uid))
        return false
    end

    -- 如果该装备已装在别的武将身上，先卸下
    if item.heroIdx and item.heroIdx ~= heroIdx then
        local oldHeroEquip = playerEquipment.equipped[item.heroIdx]
        if oldHeroEquip then
            for si, eu in pairs(oldHeroEquip) do
                if eu == uid then oldHeroEquip[si] = nil; break end
            end
        end
    end

    -- 卸下该武将该槽位的旧装备
    if not playerEquipment.equipped[heroIdx] then
        playerEquipment.equipped[heroIdx] = {}
    end
    local oldUid = playerEquipment.equipped[heroIdx][slotIdx]
    if oldUid then
        local oldItem = FindOwnedByUid(oldUid)
        if oldItem then oldItem.heroIdx = nil end
    end

    -- 装备新装备
    playerEquipment.equipped[heroIdx][slotIdx] = uid
    item.heroIdx = heroIdx
    return true
end


--- 从武将身上卸下某槽位的装备 (放回仓库)
function UnequipFromHero(heroIdx, slotIdx)
    if not heroIdx then return end
    local heroEquip = playerEquipment.equipped[heroIdx]
    if not heroEquip then return end
    local uid = heroEquip[slotIdx]
    if uid then
        local item = FindOwnedByUid(uid)
        if item then item.heroIdx = nil end
        heroEquip[slotIdx] = nil
    end
end


--- 品质加成: quality(0~100) → 0% ~ 1% 额外基础加成
function GetQualityBonus(quality)
    return (quality or 0) / 100 * 1.0  -- 最高+1%
end


--- 品质评级文字
function GetQualityLabel(quality)
    if quality >= 95 then
        return "极品", {255, 215, 0}
    elseif quality >= 80 then
        return "上品", {180, 130, 255}
    elseif quality >= 60 then
        return "良品", {100, 200, 255}
    elseif quality >= 40 then
        return "中品", {140, 220, 140}
    elseif quality >= 20 then
        return "下品", {200, 200, 200}
    else
        return "劣品", {150, 150, 150}
    end
end


-- ============================================================================
-- 兵甲界面 - 正式UI系统 (EquipUI)
-- ============================================================================
-- EquipUI 表在 EquipUI.lua 模块中定义

-- 五维属性键名列表 (与 EQUIP_STAT_DEFS 对应)
local STAT_KEYS = { "strAdd", "intAdd", "vitAdd", "tecAdd", "spdAdd", "critRate" }
-- 额外词条key列表 (来自套装效果，非五维核心)
local EXTRA_KEYS = { "dmgReduction", "speedPct", "atkSpeedPct", "counterRate", "breakDmgPct", "deathExplosionPct" }

-- 计算某武将的装备总加成 (五维属性 + 向后兼容百分比)
-- heroIdx: 武将索引, nil时返回零加成
function GetEquipmentBonus(heroIdx)
    local bonus = {
        -- 五维属性 (累加值，直接作为战斗属性加成百分比)
        strAdd = 0, intAdd = 0, vitAdd = 0, tecAdd = 0, spdAdd = 0,
        -- 暴击 + 额外词条 (来自套装效果)
        critRate = 0, dmgReduction = 0, speedPct = 0,
        atkSpeedPct = 0, counterRate = 0, breakDmgPct = 0,
        deathExplosionPct = 0,
    }
    if not heroIdx then return bonus end
    local setCounts = {}
    for slotIdx = 1, 7 do
        local eq = GetEquippedItem(slotIdx, heroIdx)
        if eq then
            local piece = EQUIPMENT_SETS[eq.setIdx].pieces[slotIdx]
            local tierMul = EQUIP_TIERS[eq.tier or 1].multiplier
            -- 强化等级加成: 每级+5%
            local enhMul = 1.0 + (eq.enhanceLv or 0) * ENHANCE_PERCENT_PER_LEVEL / 100
            -- 品质加成: quality(0~100) → 0%~1% 额外加到各基础属性上
            local qBonus = GetQualityBonus(eq.quality)
            -- 装备等级加成: 每级+0.3%基础属性
            local lvBonus = GetLevelBonus(eq.level)
            -- 累加五维 + 暴击 (piece中只有coreKeys对应的3个属性有值)
            for _, sk in ipairs(STAT_KEYS) do
                local baseVal = piece[sk] or 0
                if baseVal > 0 then
                    -- 非暴击属性额外加品质+等级奖励; 暴击不加品质和等级
                    if sk == "critRate" then
                        bonus[sk] = bonus[sk] + baseVal * tierMul * enhMul
                    else
                        bonus[sk] = bonus[sk] + (baseVal + qBonus + lvBonus) * tierMul * enhMul
                    end
                end
            end
            setCounts[eq.setIdx] = (setCounts[eq.setIdx] or 0) + 1
        end
    end
    -- 多阶套装奖励 (3件/4件/7件 逐级叠加最高档)
    local maxTierMul = EQUIP_TIERS[#EQUIP_TIERS].multiplier
    for setIdx, count in pairs(setCounts) do
        local setData = EQUIPMENT_SETS[setIdx]
        local sb = nil
        if count >= 7 and setData.setBonus then
            sb = setData.setBonus
        elseif count >= 4 and setData.setBonus4 then
            sb = setData.setBonus4
        elseif count >= 3 and setData.setBonus3 then
            sb = setData.setBonus3
        end
        if sb then
            local minMul = maxTierMul
            for slotIdx2 = 1, 7 do
                local eq2 = GetEquippedItem(slotIdx2, heroIdx)
                if eq2 and eq2.setIdx == setIdx then
                    local tierMul2 = EQUIP_TIERS[eq2.tier or 1].multiplier
                    if tierMul2 < minMul then minMul = tierMul2 end
                end
            end
            local setRatio = minMul / maxTierMul
            -- 累加五维属性和暴击
            for _, sk in ipairs(STAT_KEYS) do
                if sb[sk] then
                    bonus[sk] = bonus[sk] + sb[sk] * setRatio
                end
            end
            -- 累加额外词条
            for _, ek in ipairs(EXTRA_KEYS) do
                if sb[ek] then
                    bonus[ek] = bonus[ek] + sb[ek] * setRatio
                end
            end
        end
    end
    return bonus
end


-- ============================================================================
-- 评分系统 + 红点检测
-- ============================================================================

-- 装备评分: 基础属性和 × 品阶倍率 (含品质加成)
function GetEquipScore(setIdx, slotIdx, tier, enhanceLv, quality)
    local piece = EQUIPMENT_SETS[setIdx].pieces[slotIdx]
    local mul = EQUIP_TIERS[tier].multiplier
    local enhMul = 1.0 + (enhanceLv or 0) * ENHANCE_PERCENT_PER_LEVEL / 100
    local qBonus = GetQualityBonus(quality)
    -- 累加该装备所有五维属性基值
    local total = 0
    local coreCount = 0
    for _, sk in ipairs(STAT_KEYS) do
        local v = piece[sk] or 0
        if v > 0 then
            if sk == "critRate" then
                total = total + v  -- 暴击无品质/等级加成
            else
                total = total + v + qBonus
                coreCount = coreCount + 1
            end
        end
    end
    return math.ceil(total * mul * enhMul)
end


-- 获取某武将某装备槽当前已装备的评分
function GetEquippedSlotScore(slotIdx, heroIdx)
    local eq = GetEquippedItem(slotIdx, heroIdx)
    if not eq then return 0 end
    return GetEquipScore(eq.setIdx, slotIdx, eq.tier, eq.enhanceLv, eq.quality)
end


-- 获取仓库中未装备的最佳装备评分 (用于红点检测)
function GetBestUnequippedScoreForSlot(slotIdx)
    local best = 0
    for _, item in ipairs(playerEquipment.owned) do
        if item.slotIdx == slotIdx and not item.heroIdx then
            local score = GetEquipScore(item.setIdx, slotIdx, item.tier, item.enhanceLv, item.quality)
            if score > best then best = score end
        end
    end
    return best
end


-- 获取当前最佳未装备武技评分 (未被任何武将装备的武技)
function GetBestUnequippedSkillScore()
    local equippedSet = GetAllEquippedSkillSet()
    local best = 0
    for i = 1, #SKILL_TECHNIQUES do
        if not equippedSet[i] and SKILL_DEFS[i] and SKILL_DEFS[i].unlocked then
            local sc = GetSkillScore(i)
            if sc > best then best = sc end
        end
    end
    return best
end


-- 红点: 仓库中有未装备的装备 且 评分大于确认阈值
function HasEquipSlotRedDot(slotIdx)
    local bestUnequipped = GetBestUnequippedScoreForSlot(slotIdx)
    if bestUnequipped <= 0 then return false end
    return bestUnequipped > (redDotState.equipAck[slotIdx] or 0)
end


-- 兵甲按钮红点 (任一槽位有未装备装备)
function HasEquipRedDot()
    for slotIdx = 1, 7 do
        if HasEquipSlotRedDot(slotIdx) then return true end
    end
    return false
end


-- 武技按钮红点 (按武将检查)
function HasSkillRedDot()
    -- 情况0: 有碎片足够合成但未解锁/未满层的武技 → 红点
    local needFrag = SKILL_FRAG_EXCHANGE or 20
    for i = 1, #SKILL_TECHNIQUES do
        local skDef = SKILL_DEFS[i]
        if skDef and not skDef.notAvailable then
            local frags = skillFragments[i] or 0
            if frags >= needFrag then
                if not skDef.unlocked or (skillLayers[i] or 1) < SKILL_MAX_LAYER then
                    return true  -- 可合成/升层 → 红点
                end
            end
        end
    end
    local equippedSet = GetAllEquippedSkillSet()
    -- 情况1: 任一拥有的武将有空闲槽位 且 有已解锁的武技可装备 → 红点
    for heroIdx, hero in pairs(playerHeroes) do
        if hero.owned then
            local heroSkills = GetHeroSkills(heroIdx)
            if #heroSkills < 2 then
                for i = 1, #SKILL_TECHNIQUES do
                    if not equippedSet[i] and SKILL_DEFS[i] and SKILL_DEFS[i].unlocked then
                        return true  -- 有空槽 + 有可装备的武技 → 红点
                    end
                end
            end
        end
    end
    -- 情况2: 有更好的未装备武技, 且该优势未被确认
    local allSkills = GetAllEquippedSkills()
    local minEquipped = math.huge
    for _, si in ipairs(allSkills) do
        local sc = GetSkillScore(si)
        if sc < minEquipped then minEquipped = sc end
    end
    if #allSkills == 0 then minEquipped = 0 end
    local bestUnequipped = GetBestUnequippedSkillScore()
    if bestUnequipped <= minEquipped then return false end
    return bestUnequipped > (redDotState.skillAckBest or 0)
end


-- 确认兵甲红点 (进入兵甲页面时调用)
function DismissEquipRedDots()
    for slotIdx = 1, 7 do
        redDotState.equipAck[slotIdx] = GetBestUnequippedScoreForSlot(slotIdx)
    end
end


-- 确认武技红点 (进入武技页面时调用)
function DismissSkillRedDots()
    redDotState.skillAckBest = GetBestUnequippedSkillScore()
    redDotState.skillAckSlots = #GetAllEquippedSkills()
end
