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


--- 获取某槽位的所有兵甲列表（按阶级降序、品质降序排列）
function GetOwnedForSlot(slotIdx)
    local list = {}
    for _, item in ipairs(playerEquipment.owned) do
        if item.slotIdx == slotIdx then
            table.insert(list, item)
        end
    end
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then return a.tier > b.tier end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.uid < b.uid
    end)
    return list
end


--- 获取已装备某槽位的兵甲对象
function GetEquippedItem(slotIdx)
    local uid = playerEquipment.equipped[slotIdx]
    if not uid then return nil end
    return FindOwnedByUid(uid)
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

-- 计算装备总加成 (百分比, 含品质加成)
function GetEquipmentBonus()
    local bonus = {
        atkPct = 0, defPct = 0, hpPct = 0,
        -- 额外词条 (来自套装效果)
        critRate = 0, dmgReduction = 0, speedPct = 0,
        atkSpeedPct = 0, counterRate = 0, breakDmgPct = 0,
        deathExplosionPct = 0,
    }
    local setCounts = {}
    for slotIdx = 1, 7 do
        local eq = GetEquippedItem(slotIdx)
        if eq then
            local piece = EQUIPMENT_SETS[eq.setIdx].pieces[slotIdx]
            local tierMul = EQUIP_TIERS[eq.tier or 1].multiplier
            -- 强化等级加成: 每级+5%
            local enhMul = 1.0 + (eq.enhanceLv or 0) * ENHANCE_PERCENT_PER_LEVEL / 100
            -- 品质加成: quality(0~100) → 0%~1% 额外加到基础属性上
            local qBonus = GetQualityBonus(eq.quality)
            -- 装备等级加成: 每级+0.3%基础属性
            local lvBonus = GetLevelBonus(eq.level)
            bonus.atkPct = bonus.atkPct + (piece.atkPct + qBonus + lvBonus) * tierMul * enhMul
            bonus.defPct = bonus.defPct + (piece.defPct + qBonus + lvBonus) * tierMul * enhMul
            bonus.hpPct  = bonus.hpPct  + (piece.hpPct + qBonus + lvBonus) * tierMul * enhMul
            setCounts[eq.setIdx] = (setCounts[eq.setIdx] or 0) + 1
        end
    end
    -- 额外词条key列表
    local extraKeys = { "critRate", "dmgReduction", "speedPct", "atkSpeedPct", "counterRate", "breakDmgPct", "deathExplosionPct" }
    -- 多阶套装奖励 (3件/4件/7件 逐级叠加最高档)
    -- ★ 套装属性按参与件中最差等阶的 multiplier 来折算比例
    --   比例 = minTierMultiplier / maxTierMultiplier(帝品3.2)
    --   全帝品才给 100%, 混搭凡品则只给 1.0/3.2 ≈ 31%
    local maxTierMul = EQUIP_TIERS[#EQUIP_TIERS].multiplier  -- 帝品 3.2
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
            -- 找出该套装中所有已装备件的最差等阶
            local minMul = maxTierMul
            for slotIdx2 = 1, 7 do
                local eq2 = GetEquippedItem(slotIdx2)
                if eq2 and eq2.setIdx == setIdx then
                    local tierMul2 = EQUIP_TIERS[eq2.tier or 1].multiplier
                    if tierMul2 < minMul then minMul = tierMul2 end
                end
            end
            local setRatio = minMul / maxTierMul  -- 0.31 ~ 1.0
            bonus.atkPct = bonus.atkPct + sb.atkPct * setRatio
            bonus.defPct = bonus.defPct + sb.defPct * setRatio
            bonus.hpPct  = bonus.hpPct  + sb.hpPct * setRatio
            -- 累加额外词条 (同样按比例)
            for _, ek in ipairs(extraKeys) do
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
    return math.ceil((piece.atkPct + piece.defPct + piece.hpPct + qBonus * 3) * mul * enhMul)
end


-- 获取某装备槽当前已装备的评分（含强化等级和品质）
function GetEquippedSlotScore(slotIdx)
    local eq = GetEquippedItem(slotIdx)
    if not eq then return 0 end
    return GetEquipScore(eq.setIdx, slotIdx, eq.tier, eq.enhanceLv, eq.quality)
end


-- 获取某装备槽拥有的最佳评分
function GetBestOwnedScoreForSlot(slotIdx)
    local best = 0
    for _, item in ipairs(playerEquipment.owned) do
        if item.slotIdx == slotIdx then
            local score = GetEquipScore(item.setIdx, slotIdx, item.tier, item.enhanceLv, item.quality)
            if score > best then best = score end
        end
    end
    return best
end


-- 获取当前最佳未装备武技评分
function GetBestUnequippedSkillScore()
    local equippedSet = {}
    for _, si in ipairs(playerEquippedSkills) do equippedSet[si] = true end
    local best = 0
    for i = 1, #SKILL_TECHNIQUES do
        if not equippedSet[i] and SKILL_DEFS[i] and SKILL_DEFS[i].unlocked then
            local sc = GetSkillScore(i)
            if sc > best then best = sc end
        end
    end
    return best
end


-- 单槽位红点: 有更好的装备 且 该优势未被确认
function HasEquipSlotRedDot(slotIdx)
    local bestOwned = GetBestOwnedScoreForSlot(slotIdx)
    local equipped = GetEquippedSlotScore(slotIdx)
    if bestOwned <= equipped then return false end
    return bestOwned > (redDotState.equipAck[slotIdx] or 0)
end


-- 兵甲按钮红点 (树状: 任一子槽位亮 >> 父节点亮)
function HasEquipRedDot()
    for slotIdx = 1, 7 do
        if HasEquipSlotRedDot(slotIdx) then return true end
    end
    return false
end


-- 武技按钮红点
function HasSkillRedDot()
    -- 情况1: 有空闲槽位 且 有已解锁的武技可装备 → 持续红点提醒
    if #playerEquippedSkills < 2 then
        local equippedSet = {}
        for _, si in ipairs(playerEquippedSkills) do equippedSet[si] = true end
        for i = 1, #SKILL_TECHNIQUES do
            if not equippedSet[i] and SKILL_DEFS[i] and SKILL_DEFS[i].unlocked then
                return true  -- 有空槽 + 有可装备的武技 → 红点
            end
        end
    end
    -- 情况2: 有更好的未装备武技, 且该优势未被确认
    local minEquipped = math.huge
    for _, si in ipairs(playerEquippedSkills) do
        local sc = GetSkillScore(si)
        if sc < minEquipped then minEquipped = sc end
    end
    if #playerEquippedSkills == 0 then minEquipped = 0 end
    local bestUnequipped = GetBestUnequippedSkillScore()
    if bestUnequipped <= minEquipped then return false end
    return bestUnequipped > (redDotState.skillAckBest or 0)
end


-- 确认兵甲红点 (进入兵甲页面时调用)
function DismissEquipRedDots()
    for slotIdx = 1, 7 do
        redDotState.equipAck[slotIdx] = GetBestOwnedScoreForSlot(slotIdx)
    end
end


-- 确认武技红点 (进入武技页面时调用)
function DismissSkillRedDots()
    redDotState.skillAckBest = GetBestUnequippedSkillScore()
    redDotState.skillAckSlots = #playerEquippedSkills
end
