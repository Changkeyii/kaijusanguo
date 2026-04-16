-- ============================================================================
-- systems/seal.lua - 三国武灵录
-- ============================================================================


--- 获取英雄已开的兵符孔数
function GetSealSlotCount(cardIdx)
    local sd = sealData[cardIdx]
    if not sd or not sd.slots then return 0 end
    local count = 0
    for i = 1, SEAL_MAX_SLOTS do
        if sd.slots[i] then count = count + 1 end
    end
    return count
end


--- 获取兵符总属性加成
function GetSealTotalBonus(cardIdx)
    local bonus = {
        atkPct = 0, defPct = 0, hpPct = 0,   -- 基础三维
        extraTroops = 0,                       -- 贪欲: 额外出兵
        critRate = 0,                          -- 嗔欲: 暴击率%
        dmgReduction = 0,                      -- 痴欲: 受伤减免%
        speedPct = 0,                          -- 慢欲: 移速%
        atkSpeedPct = 0,                       -- 慢欲: 攻速%
        counterRate = 0,                       -- 疑欲: 反击概率%
        breakDmgPct = 0,                       -- 邪欲: 突破伤害%
        deathExplosionPct = 0,                 -- 邪欲: 死亡爆炸ATK%
    }
    local sd = sealData[cardIdx]
    if not sd or not sd.slots then return bonus end
    for i = 1, SEAL_MAX_SLOTS do
        local slot = sd.slots[i]
        if slot then
            local effect = SEAL_SLOT_EFFECTS[i]
            if effect then
                local tierData = effect[slot.sealQ] or effect[1]
                local lv = slot.level or 1
                -- 主属性
                if effect.mainKey and tierData.main then
                    bonus[effect.mainKey] = (bonus[effect.mainKey] or 0) + tierData.main * lv
                end
                -- 副属性
                if effect.subKey and tierData.sub then
                    bonus[effect.subKey] = (bonus[effect.subKey] or 0) + tierData.sub * lv
                end
            end
        end
    end
    return bonus
end


--- 获取单个兵符孔位的加成 (用于UI显示)
function GetSealSlotBonus(slotIdx, sealQ, level)
    local effect = SEAL_SLOT_EFFECTS[slotIdx]
    if not effect then return nil end
    local tierData = effect[sealQ] or effect[1]
    local lv = level or 1
    local mainVal = (tierData.main or 0) * lv
    local subVal = (tierData.sub or 0) * lv
    return {
        mainKey = effect.mainKey, mainName = effect.mainName, mainVal = mainVal,
        subKey = effect.subKey, subName = effect.subName, subVal = subVal,
        theme = effect.theme, desc = effect.desc,
    }
end


--- 兵符等阶概率 (与装备相同, 基于1000)
--- 凡品52.5%, 良品25%, 优品15%, 将品5%, 王品2%, 帝品0.5%
function RollSealTier()
    local roll = math.random(1, 1000)
    if roll <= 5 then
        return 6       -- 帝品 0.5%
    elseif roll <= 25 then
        return 5  -- 王品 2%
    elseif roll <= 75 then
        return 4  -- 将品 5%
    elseif roll <= 225 then
        return 3 -- 优品 15%
    elseif roll <= 475 then
        return 2 -- 良品 25%
    else
        return 1                    -- 凡品 52.5%
    end
end


--- 执行兵符抽卡 (无保底)
--- 产出: 60% 兵符(匹配某个满命英雄, 等阶独立roll), 40% 经验道具
--- 每个兵符独特绑定到特定武灵
--- @param count number 抽卡次数 (1 或 10)
function ExecuteSealGachaPull(count)
    local cost
    if count >= 10 then
        cost = math.floor(SEAL_GACHA_COST * count * 0.9)  -- 10连及以上享9折
    else
        cost = SEAL_GACHA_COST * count
    end
    if playerInfo.jade < cost then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "虎符不足!", 1.2, { 255, 100, 100 }, 14)
        return false
    end
    if not HasMaxConstellationHero() then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "需要拥有至少1个满命武灵!", 1.5, { 255, 100, 100 }, 14)
        return false
    end
    playerInfo.jade = playerInfo.jade - cost
    sealGachaState.results = {}
    -- 无保底机制

    local maxHeroes = GetMaxConstellationHeroes()
    if #maxHeroes == 0 then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "需要拥有至少1个满命武灵!", 1.5, { 255, 100, 100 }, 14)
        playerInfo.jade = playerInfo.jade + cost
        return false
    end
    local totalJadeRefund = 0

    for _ = 1, count do
        local roll = math.random(1, 100)
        if roll <= 60 then
            -- 60%: 产出兵符 (匹配一个随机满命英雄)
            local target = maxHeroes[math.random(1, #maxHeroes)]
            local cardIdx = target.cardIdx
            -- 随机孔位类型 1-6
            local slotType = math.random(1, SEAL_MAX_SLOTS)
            -- 等阶: 独立roll, 与装备概率相同
            local sealQ = RollSealTier()
            -- 检查是否与该英雄同孔位同品质完全重复 → 返还虎符
            if not sealData[cardIdx] then sealData[cardIdx] = { slots = {} } end
            local sd = sealData[cardIdx]
            local equipped = sd.slots[slotType]
            if equipped and equipped.sealQ == sealQ then
                -- 同武灵 + 同孔位 + 同品质 → 重复, 返还虎符
                totalJadeRefund = totalJadeRefund + SEAL_DUPE_REFUND
                table.insert(sealGachaState.results, {
                    type = "seal_dupe", cardIdx = cardIdx, heroName = target.name,
                    slotType = slotType, slotName = SEAL_SLOT_NAMES[slotType],
                    sealQ = sealQ, refund = SEAL_DUPE_REFUND,
                })
            else
                -- 存入仓库
                local newSeal = {
                    id = sealInventoryNextId,
                    slotType = slotType, sealQ = sealQ,
                    level = 1, exp = 0, fromHero = cardIdx,
                }
                sealInventoryNextId = sealInventoryNextId + 1
                table.insert(sealInventory, newSeal)
                table.insert(sealGachaState.results, {
                    type = "seal", cardIdx = cardIdx, heroName = target.name,
                    slotType = slotType, slotName = SEAL_SLOT_NAMES[slotType],
                    sealQ = sealQ, isNew = true, toInventory = true,
                })
            end
        else
            -- 40%: 产出经验道具
            local totalWeight = 0
            for _, item in ipairs(SEAL_EXP_ITEMS) do totalWeight = totalWeight + item.weight end
            local r = math.random(1, totalWeight)
            local accum = 0
            local itemIdx = 1
            for idx, item in ipairs(SEAL_EXP_ITEMS) do
                accum = accum + item.weight
                if r <= accum then itemIdx = idx; break end
            end
            sealExpItems[itemIdx] = (sealExpItems[itemIdx] or 0) + 1
            table.insert(sealGachaState.results, {
                type = "exp_item", itemIdx = itemIdx,
                itemName = SEAL_EXP_ITEMS[itemIdx].name,
                itemExp = SEAL_EXP_ITEMS[itemIdx].exp,
            })
        end
    end

    if totalJadeRefund > 0 then
        playerInfo.jade = playerInfo.jade + totalJadeRefund
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.55, "重复兵符返还 +" .. totalJadeRefund .. " 虎符", 1.5, { 255, 200, 80 }, 16)
    end

    playerInfo.totalGachas = (playerInfo.totalGachas or 0) + count
    TrackDailyTask("gacha5", count)
    TrackWeeklyTask("wgacha20", count)
    TrackBattlePassTask("bp_gacha1", count)
    TrackBattlePassTask("bp_wgacha5", count)
    TrackBattlePassTask("bp_sgacha30", count)

    -- 播放抽卡动画
    sealGachaState.showResults = false
    sealGachaState.pulling = true
    sealGachaState.pullTimer = 0
    sealGachaState.pullCount = count
    SaveGameProgress()
    return true
end


--- 使用兵符经验道具给指定孔位升级
--- @param cardIdx number 英雄索引
--- @param slotIdx number 孔位索引 1-6
--- @param expItemIdx number 经验道具索引
--- @return boolean 是否成功
function UseSealExpItem(cardIdx, slotIdx, expItemIdx)
    local sd = sealData[cardIdx]
    if not sd or not sd.slots or not sd.slots[slotIdx] then return false end
    local slot = sd.slots[slotIdx]
    if slot.level >= SEAL_MAX_LEVEL then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "已达最高等级!", 1.2, { 255, 180, 80 }, 14)
        return false
    end
    local itemCount = sealExpItems[expItemIdx] or 0
    if itemCount <= 0 then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "道具不足!", 1.2, { 255, 100, 100 }, 14)
        return false
    end
    sealExpItems[expItemIdx] = itemCount - 1
    if sealExpItems[expItemIdx] <= 0 then sealExpItems[expItemIdx] = nil end
    local expGain = SEAL_EXP_ITEMS[expItemIdx].exp
    slot.exp = (slot.exp or 0) + expGain
    -- 检查升级
    local leveled = false
    while slot.level < SEAL_MAX_LEVEL do
        local need = SEAL_EXP_TABLE[slot.level] or 9999
        if slot.exp >= need then
            slot.exp = slot.exp - need
            slot.level = slot.level + 1
            leveled = true
        else
            break
        end
    end
    if slot.level >= SEAL_MAX_LEVEL then
        slot.exp = 0
    end
    if leveled then
        local qName = SEAL_QUALITY_NAMES[slot.sealQ] or "兵符"
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, SEAL_SLOT_NAMES[slotIdx] .. "兵符升级! Lv." .. slot.level, 1.5, { 255, 220, 80 }, 18)
        PlaySFX(AUDIO.sfx_click)
    else
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4, "+" .. expGain .. " 兵符经验", 1.0, { 200, 180, 255 }, 14)
    end
    SaveGameProgress()
    return true
end


--- 计算从当前等级升到目标等级所需的总经验
--- @param curLevel number 当前等级
--- @param curExp number 当前经验
--- @param targetLevel number 目标等级
--- @return number 所需额外经验
function CalcSealExpNeeded(curLevel, curExp, targetLevel)
    if targetLevel <= curLevel then return 0 end
    if targetLevel > SEAL_MAX_LEVEL then targetLevel = SEAL_MAX_LEVEL end
    local total = 0
    for lv = curLevel, targetLevel - 1 do
        total = total + (SEAL_EXP_TABLE[lv] or 9999)
    end
    return math.max(0, total - (curExp or 0))
end


--- 计算用现有材料自动升级的消耗方案
--- @param expNeeded number 所需经验
--- @return table|nil plan 消耗方案 {[itemIdx]=count,...}, totalExp, 如果材料不足返回nil
function CalcSealAutoEnhancePlan(expNeeded)
    if expNeeded <= 0 then return {}, 0 end
    -- 优先使用低级材料（性价比高、消耗数量多但不浪费）
    local plan = {}
    local remaining = expNeeded
    -- 从低到高消耗
    for idx = 1, #SEAL_EXP_ITEMS do
        local item = SEAL_EXP_ITEMS[idx]
        local cnt = sealExpItems[idx] or 0
        if cnt > 0 and remaining > 0 then
            local need = math.ceil(remaining / item.exp)
            local use = math.min(need, cnt)
            plan[idx] = use
            remaining = remaining - use * item.exp
        end
    end
    if remaining > 0 then return nil end -- 材料不足
    local totalExp = 0
    for idx, use in pairs(plan) do
        totalExp = totalExp + use * SEAL_EXP_ITEMS[idx].exp
    end
    return plan, totalExp
end


--- 执行一键升级（批量消耗材料）
--- @param cardIdx number 英雄索引
--- @param slotIdx number 孔位索引 1-6
--- @param targetLevel number 目标等级
--- @return boolean success
--- @return string msg
function DoSealBatchEnhance(cardIdx, slotIdx, targetLevel)
    local sd = sealData[cardIdx]
    if not sd or not sd.slots or not sd.slots[slotIdx] then return false, "无效孔位" end
    local slot = sd.slots[slotIdx]
    if slot.level >= SEAL_MAX_LEVEL then return false, "已达最高等级" end
    if targetLevel <= slot.level then return false, "目标等级无效" end
    if targetLevel > SEAL_MAX_LEVEL then targetLevel = SEAL_MAX_LEVEL end

    local expNeeded = CalcSealExpNeeded(slot.level, slot.exp, targetLevel)
    local plan, totalExp = CalcSealAutoEnhancePlan(expNeeded)
    if not plan then return false, "材料不足" end

    -- 扣除材料
    for idx, use in pairs(plan) do
        sealExpItems[idx] = (sealExpItems[idx] or 0) - use
        if sealExpItems[idx] <= 0 then sealExpItems[idx] = nil end
    end

    -- 加经验 + 升级
    slot.exp = (slot.exp or 0) + totalExp
    local oldLevel = slot.level
    while slot.level < SEAL_MAX_LEVEL do
        local need = SEAL_EXP_TABLE[slot.level] or 9999
        if slot.exp >= need then
            slot.exp = slot.exp - need
            slot.level = slot.level + 1
        else
            break
        end
    end
    if slot.level >= SEAL_MAX_LEVEL then slot.exp = 0 end

    local levelGained = slot.level - oldLevel
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
        SEAL_SLOT_NAMES[slotIdx] .. "兵符升至 Lv." .. slot.level .. " (+" .. levelGained .. "级)",
        1.5, { 255, 220, 80 }, 18)
    PlaySFX(AUDIO.sfx_click)
    SaveGameProgress()
    return true, "升级成功"
end


--- 获取仓库中匹配指定孔位类型的兵符列表
--- @param slotType number 孔位类型 1-6
--- @param heroIdx number|nil 武灵cardIdx (只返回绑定该武灵的兵符)
--- @return table 匹配的仓库兵符列表 (带原始索引)
function GetInventorySealsForSlot(slotType, heroIdx)
    local result = {}
    for i, seal in ipairs(sealInventory) do
        if seal.slotType == slotType then
            -- 兵符必须与目标武灵绑定才能装备
            if not heroIdx or seal.fromHero == heroIdx then
                table.insert(result, { index = i, seal = seal })
            end
        end
    end
    -- 按品质降序排列
    table.sort(result, function(a, b)
        if a.seal.sealQ ~= b.seal.sealQ then return a.seal.sealQ > b.seal.sealQ end
        return a.seal.level > b.seal.level
    end)
    return result
end


--- 获取仓库中所有兵符列表 (按品质降序)
--- @return table 所有仓库兵符列表 (带原始索引)
function GetAllInventorySeals()
    local result = {}
    for i, seal in ipairs(sealInventory) do
        table.insert(result, { index = i, seal = seal })
    end
    table.sort(result, function(a, b)
        if a.seal.sealQ ~= b.seal.sealQ then return a.seal.sealQ > b.seal.sealQ end
        if a.seal.slotType ~= b.seal.slotType then return a.seal.slotType < b.seal.slotType end
        return a.seal.level > b.seal.level
    end)
    return result
end


--- 从仓库装备兵符到指定英雄孔位
--- @param invIndex number 仓库索引
--- @param heroIdx number 英雄cardIdx
--- @param slotIdx number 目标孔位 1-6
--- @return boolean 是否成功
function EquipSealFromInventory(invIndex, heroIdx, slotIdx)
    local invSeal = sealInventory[invIndex]
    if not invSeal then return false end
    if invSeal.slotType ~= slotIdx then return false end
    -- 兵符只能装备到绑定的武灵身上
    if invSeal.fromHero ~= heroIdx then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4,
            "该兵符绑定了其他武灵!", 1.2, { 255, 100, 100 }, 16)
        return false
    end
    if not sealData[heroIdx] then sealData[heroIdx] = { slots = {} } end
    local sd = sealData[heroIdx]
    -- 旧兵符退回仓库
    local oldSlot = sd.slots[slotIdx]
    if oldSlot then
        local oldSeal = {
            id = sealInventoryNextId,
            slotType = slotIdx, sealQ = oldSlot.sealQ,
            level = oldSlot.level or 1, exp = oldSlot.exp or 0,
            fromHero = heroIdx,
        }
        sealInventoryNextId = sealInventoryNextId + 1
        table.insert(sealInventory, oldSeal)
    end
    -- 新兵符装入
    sd.slots[slotIdx] = { sealQ = invSeal.sealQ, level = invSeal.level or 1, exp = invSeal.exp or 0 }
    -- 从仓库移除
    table.remove(sealInventory, invIndex)
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4,
        SEAL_SLOT_NAMES[slotIdx] .. " 已装备!", 1.2, { 100, 255, 160 }, 16)
    SaveGameProgress()
    return true
end


--- 分解兵符 (仓库中的)
--- @param invIndex number 仓库索引
--- @return boolean 是否成功
function DecomposeSealFromInventory(invIndex)
    local invSeal = sealInventory[invIndex]
    if not invSeal then return false end
    local returns = SEAL_DECOMPOSE_RETURNS[invSeal.sealQ] or SEAL_DECOMPOSE_RETURNS[1]
    -- 额外经验: 已升级的兵符返还部分经验道具
    local extraExpTotal = 0
    if invSeal.level and invSeal.level > 1 then
        for lv = 1, invSeal.level - 1 do
            extraExpTotal = extraExpTotal + (SEAL_EXP_TABLE[lv] or 0)
        end
        extraExpTotal = extraExpTotal + (invSeal.exp or 0)
    end
    -- 发放返还道具
    local returnTexts = {}
    for _, ret in ipairs(returns) do
        sealExpItems[ret.idx] = (sealExpItems[ret.idx] or 0) + ret.count
        table.insert(returnTexts, SEAL_EXP_ITEMS[ret.idx].name .. "x" .. ret.count)
    end
    -- 额外经验转换为最小经验道具
    if extraExpTotal > 0 then
        local extraCount = math.floor(extraExpTotal / SEAL_EXP_ITEMS[1].exp)
        if extraCount > 0 then
            sealExpItems[1] = (sealExpItems[1] or 0) + extraCount
            table.insert(returnTexts, SEAL_EXP_ITEMS[1].name .. "x" .. extraCount .. "(经验返还)")
        end
    end
    table.remove(sealInventory, invIndex)
    local qName = SEAL_QUALITY_NAMES[invSeal.sealQ] or "兵符"
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
        qName .. SEAL_SLOT_NAMES[invSeal.slotType] .. " 分解成功!", 1.5, { 255, 200, 80 }, 16)
    if #returnTexts > 0 then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.42,
            "获得: " .. table.concat(returnTexts, ", "), 2.0, { 200, 180, 255 }, 13)
    end
    SaveGameProgress()
    return true
end


--- 分解已装备的兵符
--- @param heroIdx number 英雄cardIdx
--- @param slotIdx number 孔位 1-6
--- @return boolean 是否成功
function DecomposeEquippedSeal(heroIdx, slotIdx)
    local sd = sealData[heroIdx]
    if not sd or not sd.slots or not sd.slots[slotIdx] then return false end
    local slot = sd.slots[slotIdx]
    local returns = SEAL_DECOMPOSE_RETURNS[slot.sealQ] or SEAL_DECOMPOSE_RETURNS[1]
    -- 额外经验返还
    local extraExpTotal = 0
    if slot.level and slot.level > 1 then
        for lv = 1, slot.level - 1 do
            extraExpTotal = extraExpTotal + (SEAL_EXP_TABLE[lv] or 0)
        end
        extraExpTotal = extraExpTotal + (slot.exp or 0)
    end
    local returnTexts = {}
    for _, ret in ipairs(returns) do
        sealExpItems[ret.idx] = (sealExpItems[ret.idx] or 0) + ret.count
        table.insert(returnTexts, SEAL_EXP_ITEMS[ret.idx].name .. "x" .. ret.count)
    end
    if extraExpTotal > 0 then
        local extraCount = math.floor(extraExpTotal / SEAL_EXP_ITEMS[1].exp)
        if extraCount > 0 then
            sealExpItems[1] = (sealExpItems[1] or 0) + extraCount
            table.insert(returnTexts, SEAL_EXP_ITEMS[1].name .. "x" .. extraCount .. "(经验返还)")
        end
    end
    local qName = SEAL_QUALITY_NAMES[slot.sealQ] or "兵符"
    sd.slots[slotIdx] = nil
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
        qName .. SEAL_SLOT_NAMES[slotIdx] .. " 分解成功!", 1.5, { 255, 200, 80 }, 16)
    if #returnTexts > 0 then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.42,
            "获得: " .. table.concat(returnTexts, ", "), 2.0, { 200, 180, 255 }, 13)
    end
    SaveGameProgress()
    return true
end


--- 计算兵符筛选分解统计 (不执行分解)
--- @param maxTier number 品质上限 (1-7)
--- @param slotFilter number 孔位筛选 (0=全部, 1-6=指定)
--- @return number count, table returns 分解数量, 返还道具汇总
function CalcSealBatchDecomp(maxTier, slotFilter)
    local count = 0
    local totalReturns = {} -- { [itemIdx] = count }
    for _, seal in ipairs(sealInventory) do
        local tierOk = seal.sealQ <= maxTier
        local slotOk = (slotFilter == 0) or (seal.slotType == slotFilter)
        if tierOk and slotOk then
            count = count + 1
            local returns = SEAL_DECOMPOSE_RETURNS[seal.sealQ] or SEAL_DECOMPOSE_RETURNS[1]
            for _, ret in ipairs(returns) do
                totalReturns[ret.idx] = (totalReturns[ret.idx] or 0) + ret.count
            end
            -- 经验返还
            if seal.level and seal.level > 1 then
                local extraExp = 0
                for lv = 1, seal.level - 1 do extraExp = extraExp + (SEAL_EXP_TABLE[lv] or 0) end
                extraExp = extraExp + (seal.exp or 0)
                local extraCount = math.floor(extraExp / SEAL_EXP_ITEMS[1].exp)
                if extraCount > 0 then
                    totalReturns[1] = (totalReturns[1] or 0) + extraCount
                end
            end
        end
    end
    return count, totalReturns
end


--- 执行兵符筛选分解
--- @param maxTier number 品质上限
--- @param slotFilter number 孔位筛选 (0=全部)
--- @return number count 分解数量
function ExecuteSealBatchDecomp(maxTier, slotFilter)
    local count = 0
    local totalReturns = {}
    local i = #sealInventory
    while i >= 1 do
        local seal = sealInventory[i]
        local tierOk = seal.sealQ <= maxTier
        local slotOk = (slotFilter == 0) or (seal.slotType == slotFilter)
        if tierOk and slotOk then
            count = count + 1
            local returns = SEAL_DECOMPOSE_RETURNS[seal.sealQ] or SEAL_DECOMPOSE_RETURNS[1]
            for _, ret in ipairs(returns) do
                sealExpItems[ret.idx] = (sealExpItems[ret.idx] or 0) + ret.count
                totalReturns[ret.idx] = (totalReturns[ret.idx] or 0) + ret.count
            end
            if seal.level and seal.level > 1 then
                local extraExp = 0
                for lv = 1, seal.level - 1 do extraExp = extraExp + (SEAL_EXP_TABLE[lv] or 0) end
                extraExp = extraExp + (seal.exp or 0)
                local extraCount = math.floor(extraExp / SEAL_EXP_ITEMS[1].exp)
                if extraCount > 0 then
                    sealExpItems[1] = (sealExpItems[1] or 0) + extraCount
                end
            end
            table.remove(sealInventory, i)
        end
        i = i - 1
    end
    if count > 0 then
        local parts = {}
        for idx = 1, #SEAL_EXP_ITEMS do
            if totalReturns[idx] and totalReturns[idx] > 0 then
                table.insert(parts, SEAL_EXP_ITEMS[idx].name .. "x" .. totalReturns[idx])
            end
        end
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
            "筛选分解 " .. count .. " 件兵符!", 2.0, { 255, 200, 80 }, 16)
        if #parts > 0 then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.42,
                "获得: " .. table.concat(parts, ", "), 2.5, { 200, 180, 255 }, 13)
        end
        SaveGameProgress()
    end
    return count
end


--- 计算选中分解统计
--- @param selectedIds table { [invIndex]=true }
--- @return number count, table returns
function CalcSealSelectDecomp(selectedIds)
    local count = 0
    local totalReturns = {}
    for i, seal in ipairs(sealInventory) do
        if selectedIds[i] then
            count = count + 1
            local returns = SEAL_DECOMPOSE_RETURNS[seal.sealQ] or SEAL_DECOMPOSE_RETURNS[1]
            for _, ret in ipairs(returns) do
                totalReturns[ret.idx] = (totalReturns[ret.idx] or 0) + ret.count
            end
            if seal.level and seal.level > 1 then
                local extraExp = 0
                for lv = 1, seal.level - 1 do extraExp = extraExp + (SEAL_EXP_TABLE[lv] or 0) end
                extraExp = extraExp + (seal.exp or 0)
                local extraCount = math.floor(extraExp / SEAL_EXP_ITEMS[1].exp)
                if extraCount > 0 then
                    totalReturns[1] = (totalReturns[1] or 0) + extraCount
                end
            end
        end
    end
    return count, totalReturns
end


--- 执行选中分解
--- @param selectedIds table { [invIndex]=true }
--- @return number count
function ExecuteSealSelectDecomp(selectedIds)
    local count = 0
    local totalReturns = {}
    local i = #sealInventory
    while i >= 1 do
        if selectedIds[i] then
            local seal = sealInventory[i]
            count = count + 1
            local returns = SEAL_DECOMPOSE_RETURNS[seal.sealQ] or SEAL_DECOMPOSE_RETURNS[1]
            for _, ret in ipairs(returns) do
                sealExpItems[ret.idx] = (sealExpItems[ret.idx] or 0) + ret.count
                totalReturns[ret.idx] = (totalReturns[ret.idx] or 0) + ret.count
            end
            if seal.level and seal.level > 1 then
                local extraExp = 0
                for lv = 1, seal.level - 1 do extraExp = extraExp + (SEAL_EXP_TABLE[lv] or 0) end
                extraExp = extraExp + (seal.exp or 0)
                local extraCount = math.floor(extraExp / SEAL_EXP_ITEMS[1].exp)
                if extraCount > 0 then
                    sealExpItems[1] = (sealExpItems[1] or 0) + extraCount
                end
            end
            table.remove(sealInventory, i)
        end
        i = i - 1
    end
    if count > 0 then
        local parts = {}
        for idx = 1, #SEAL_EXP_ITEMS do
            if totalReturns[idx] and totalReturns[idx] > 0 then
                table.insert(parts, SEAL_EXP_ITEMS[idx].name .. "x" .. totalReturns[idx])
            end
        end
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
            "选中分解 " .. count .. " 件兵符!", 2.0, { 255, 200, 80 }, 16)
        if #parts > 0 then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.42,
                "获得: " .. table.concat(parts, ", "), 2.5, { 200, 180, 255 }, 13)
        end
        SaveGameProgress()
    end
    sealInvFilterState.selectedIds = {}
    sealInvFilterState.selectMode = false
    return count
end
