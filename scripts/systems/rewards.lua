-- ============================================================================
-- systems/rewards.lua - 三国武灵录
-- ============================================================================

-- 福利转盘奖励池（原在 gacha 模块中定义，已移至此处）
if not rawget(_G, "WHEEL_REWARDS") then
    WHEEL_REWARDS = {
        { label = "玉壁x50",   jade = 50 },
        { label = "玉壁x100",  jade = 100 },
        { label = "玉壁x200",  jade = 200 },
        { label = "武技残片x5", frag = 5 },
        { label = "武技残片x10", frag = 10 },
        { label = "召唤券x1",  ticket = 1 },
        { label = "召唤券x3",  ticket = 3 },
        { label = "玉壁x500",  jade = 500 },
    }
end

-- 福利翻牌奖励池（原在 gacha 模块中定义，已移至此处）
if not rawget(_G, "CARD_POOL") then
    CARD_POOL = {
        { label = "玉壁x30",   jade = 30 },
        { label = "玉壁x80",   jade = 80 },
        { label = "玉壁x150",  jade = 150 },
        { label = "武技残片x3", frag = 3 },
        { label = "武技残片x8", frag = 8 },
        { label = "召唤券x1",  ticket = 1 },
    }
end

-- 赠送随机装备（个体化: 每件兵甲独立，有品质）
function GrantRandomEquipment(maxTier)
    maxTier = maxTier or 1
    -- 根据概率决定阶级: 高阶概率极低
    local tier = 1
    local roll = math.random(1, 1000)
    local isTower = gameState and gameState.towerFloor
    if maxTier >= 6 and roll <= 5 then
        tier = 6                        -- 0.5%
    elseif maxTier >= 5 and roll <= (isTower and 5 or 25) then
        tier = 5 -- 爬塔0.5% / 普通2%
    elseif maxTier >= 4 and roll <= 75 then
        tier = 4                   -- 5%
    elseif maxTier >= 3 and roll <= 225 then
        tier = 3                  -- 15%
    elseif maxTier >= 2 and roll <= 475 then
        tier = 2                  -- 25%
    else
        tier = 1                                                       -- 52.5%
    end
    -- 随机选一个套装和部位
    local si = math.random(1, #EQUIPMENT_SETS)
    local pi = math.random(1, 7)
    local item = CreateEquipItem(si, pi, tier) -- 品质随机生成
    playerInfo.totalEquips = playerInfo.totalEquips + 1
    return { setIdx = si, slotIdx = pi, tier = tier, uid = item.uid, quality = item.quality }
end


-- 通用奖励发放
function GrantRewardTable(reward)
    if not reward then return end
    if reward.jade and reward.jade > 0 then
        playerInfo.jade = playerInfo.jade + reward.jade
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "+" .. reward.jade .. " 玉壁", 1.5, { 210, 180, 255 }, 18)
    end
    if reward.frag and reward.frag > 0 then
        -- 随机分配残片
        for _ = 1, reward.frag do
            local idx = math.random(1, #SKILL_TECHNIQUES)
            skillFragments[idx] = (skillFragments[idx] or 0) + 1
        end
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.40, "+" .. reward.frag .. " 武技残片", 1.5, { 180, 160, 255 }, 18)
    end
    if reward.ticket and reward.ticket > 0 then
        -- 讨伐票已废弃，转换为玉壁 (1票=10玉壁)
        local bonusJade = reward.ticket * 10
        playerInfo.jade = playerInfo.jade + bonusJade
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45, "+" .. bonusJade .. " 玉壁", 1.5, { 200, 140, 255 }, 18)
    end
    -- 装备掉落 (讨伐主要产出路径)
    if reward.equipDrop and reward.equipDrop > 0 then
        for _ = 1, reward.equipDrop do
            local si = math.random(1, #EQUIPMENT_SETS)
            local pi = math.random(1, 7)
            -- 讨伐掉落阶级偏高: 50% T2, 30% T3, 15% T4, 5% T5
            local roll = math.random(1, 100)
            local tier
            if roll <= 5 then
                tier = 5
            elseif roll <= 20 then
                tier = 4
            elseif roll <= 50 then
                tier = 3
            elseif roll <= 100 then
                tier = 2
            end
            CreateEquipItem(si, pi, tier, math.random(30, 90))
            playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
        end
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.50, "+" .. reward.equipDrop .. " 件装备!", 1.5, { 255, 200, 100 }, 18)
    end
end


-- ============================================================================
-- 英雄升级
-- ============================================================================
function GetHeroExpForLevel(level)
    if level < 1 then return 0 end
    if level > HERO_MAX_LEVEL then return HERO_LEVEL_EXP[HERO_MAX_LEVEL] + (level - HERO_MAX_LEVEL) * 500 end
    return HERO_LEVEL_EXP[level] or 0
end


function TryLevelUpHero(cardIdx)
    local hero = playerHeroes[cardIdx]
    if not hero or not hero.owned then return false end
    local curLv = hero.level or 1
    local needed = GetHeroExpForLevel(curLv + 1) - GetHeroExpForLevel(curLv)
    if needed <= 0 then needed = 50 end
    if playerInfo.exp < needed then return false end
    playerInfo.exp = playerInfo.exp - needed
    hero.level = curLv + 1
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
        HERO_CARDS[cardIdx].name .. " 升级! Lv" .. hero.level, 2.0, { 255, 230, 80 }, 18)
    SaveGameProgress()
    return true
end


-- ============================================================================
-- 玩家升级检查 (经验累积制: 达到阈值自动升级)
-- ============================================================================
function CheckPlayerLevelUp()
    local maxRank = #GameConfig.RANK_EXP_TABLE
    while playerInfo.rankIdx < maxRank do
        local nextExp = GameConfig.RANK_EXP_TABLE[playerInfo.rankIdx + 1]
        if not nextExp then break end
        if playerInfo.exp >= nextExp then
            playerInfo.rankIdx = playerInfo.rankIdx + 1
            playerInfo.level = playerInfo.rankIdx
            local rankName = GetRankDisplayName(playerInfo.rankIdx)
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                "突破! " .. rankName, 3.0, { 255, 230, 80 }, 22)
            PlaySFX(AUDIO.sfx_win)
            SaveGameProgress()
            ReportRealmScore()
        else
            break
        end
    end
end


-- ============================================================================
-- 装备分解 & 强化
-- ============================================================================
--- 计算分解可获得军资（含强化返还50%）
function CalcDecomposeGain(tier, enhanceLv)
    local base = DECOMPOSE_LINGSHI[tier] or 5
    local enhLv = enhanceLv or 0
    if enhLv <= 0 then return base, 0 end
    -- 强化投入总军资
    local totalEnhCost = 0
    for i = 1, enhLv do
        totalEnhCost = totalEnhCost + (ENHANCE_COST[i] or 0)
    end
    -- 返还强化投入的50%（向上取整）
    local enhRefund = math.ceil(totalEnhCost * 0.5)
    return base + enhRefund, enhRefund
end


function DecomposeEquipment(uid)
    local item, idx = FindOwnedByUid(uid)
    if not item then return false end
    -- 已装备的不能分解
    if item.heroIdx then return false end
    -- 分解获取军资（含强化返还）
    local gain, enhRefund = CalcDecomposeGain(item.tier, item.enhanceLv)
    RemoveOwnedByUid(uid)
    playerInfo.lingshi = playerInfo.lingshi + gain
    playerInfo.totalDecompose = playerInfo.totalDecompose + 1
    TrackDailyTask("enhance1", 0) -- 分解不算强化
    local msg = "分解 +" .. gain .. " 军资"
    if enhRefund > 0 then
        msg = msg .. " (含强化返还" .. enhRefund .. ")"
    end
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, msg, 1.5, { 180, 220, 255 }, 18)
    SaveGameProgress()
    return true
end


--- 计算筛选分解统计 (不执行分解)
function CalcBatchDecomposeStats(maxTier)
    maxTier = maxTier or 6
    local count = 0
    local gain = 0
    for _, item in ipairs(playerEquipment.owned) do
        if not item.heroIdx and item.tier <= maxTier then
            count = count + 1
            gain = gain + CalcDecomposeGain(item.tier, item.enhanceLv)
        end
    end
    return count, gain
end


--- 一键分解: 分解未装备兵甲(可筛选品质), 返回(总数, 总军资)
function BatchDecomposeAll(maxTier, filterTiers, maxEnhLv)
    maxTier = maxTier or 6
    local toRemove = {}
    local totalGain = 0
    local count = 0
    for _, item in ipairs(playerEquipment.owned) do
        if not item.heroIdx then
            local tierOk = false
            if filterTiers then
                tierOk = filterTiers[item.tier] == true
            else
                tierOk = item.tier <= maxTier
            end
            local lvOk = true
            if maxEnhLv then
                lvOk = (item.enhanceLv or 0) <= maxEnhLv
            end
            if tierOk and lvOk then
                local gain = CalcDecomposeGain(item.tier, item.enhanceLv)
                totalGain = totalGain + gain
                count = count + 1
                table.insert(toRemove, item.uid)
            end
        end
    end
    if count == 0 then return 0, 0 end
    -- 从后往前删除 (避免索引偏移)
    for i = #toRemove, 1, -1 do
        RemoveOwnedByUid(toRemove[i])
    end
    playerInfo.lingshi = playerInfo.lingshi + totalGain
    playerInfo.totalDecompose = playerInfo.totalDecompose + count
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
        "批量分解 " .. count .. " 件 +" .. totalGain .. " 军资", 2.5, { 255, 200, 100 }, 18)
    SaveGameProgress()
    return count, totalGain
end


--- 计算选中分解统计 (不执行分解)
function CalcSelectDecomposeStats(uids)
    local count = 0
    local gain = 0
    for uid, _ in pairs(uids) do
        local item = FindOwnedByUid(uid)
        if item and not item.heroIdx then
            count = count + 1
            gain = gain + CalcDecomposeGain(item.tier, item.enhanceLv)
        end
    end
    return count, gain
end


--- 选中分解: 分解指定uid列表, 返回(总数, 总军资)
function SelectDecomposeAll(uids)
    local toRemove = {}
    local totalGain = 0
    local count = 0
    for uid, _ in pairs(uids) do
        local item = FindOwnedByUid(uid)
        if item and not item.heroIdx then
            local gain = CalcDecomposeGain(item.tier, item.enhanceLv)
            totalGain = totalGain + gain
            count = count + 1
            table.insert(toRemove, uid)
        end
    end
    if count == 0 then return 0, 0 end
    for i = #toRemove, 1, -1 do
        RemoveOwnedByUid(toRemove[i])
    end
    playerInfo.lingshi = playerInfo.lingshi + totalGain
    playerInfo.totalDecompose = playerInfo.totalDecompose + count
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
        "选中分解 " .. count .. " 件 +" .. totalGain .. " 军资", 2.5, { 255, 200, 100 }, 18)
    SaveGameProgress()
    return count, totalGain
end


function EnhanceEquipment(slotIdx, heroIdx)
    local eq = GetEquippedItem(slotIdx, heroIdx)
    if not eq then return false end
    local curLv = eq.enhanceLv or 0
    if curLv >= ENHANCE_MAX_LEVEL then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "已达强化上限 +20!", 1.0, { 255, 200, 100 }, 18)
        return false
    end
    local cost = ENHANCE_COST[curLv + 1] or 999
    if playerInfo.lingshi < cost then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "军资不足 (需要" .. cost .. ")", 1.0, { 255, 100, 100 }, 18)
        return false
    end
    playerInfo.lingshi = playerInfo.lingshi - cost
    eq.enhanceLv = curLv + 1
    playerInfo.totalEnhance = playerInfo.totalEnhance + 1
    TrackDailyTask("enhance1", 1)
    TrackWeeklyTask("wenhance3", 1)
    TrackBattlePassTask("bp_enhance1", 1)
    TrackBattlePassTask("bp_senhance20", 1)
    local bonusPct = eq.enhanceLv * ENHANCE_PERCENT_PER_LEVEL
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
        "强化成功! +" .. eq.enhanceLv .. " (全属性+" .. bonusPct .. "%)", 2.0, { 255, 220, 80 }, 18)
    SaveGameProgress()
    return true
end


function GrantWheelReward(idx)
    local rw = WHEEL_REWARDS[idx]
    if not rw then return end
    if rw.jade then playerInfo.jade = playerInfo.jade + rw.jade end
    if rw.frag then playerInfo.skillFragments = (playerInfo.skillFragments or 0) + rw.frag end
    if rw.ticket then playerInfo.tickets = (playerInfo.tickets or 0) + rw.ticket end
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "转盘奖励: " .. rw.label, 2.0, { 255, 220, 80 }, 18)
end


function GrantCardReward(poolIdx)
    local rw = CARD_POOL[poolIdx]
    if not rw then return end
    if rw.jade then playerInfo.jade = playerInfo.jade + rw.jade end
    if rw.frag then playerInfo.skillFragments = (playerInfo.skillFragments or 0) + rw.frag end
    if rw.ticket then playerInfo.tickets = (playerInfo.tickets or 0) + rw.ticket end
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "翻牌奖励: " .. rw.label, 2.0, { 120, 220, 255 }, 18)
end


function StartWheelSpin(t)
    local resultIdx = math.random(1, #WHEEL_REWARDS)
    local segAngle = 2 * math.pi / #WHEEL_REWARDS
    -- 目标角度: 多转几圈 + 停在指定扇区
    local extraTurns = math.random(3, 5) * 2 * math.pi
    local targetA = extraTurns + (2 * math.pi - (resultIdx - 0.5) * segAngle)
    welfareState.spinWheel.spinning = true
    welfareState.spinWheel.spinStart = t
    welfareState.spinWheel.targetAngle = targetA
    welfareState.spinWheel.resultIdx = resultIdx
    welfareState.spinWheel.resultGranted = false
    welfareState.spinWheel.angle = 0
end
