-- ============================================================================
-- systems/battle_pass.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 战令通行证: 重置 & 经验 & 领奖
-- ============================================================================

--- 初始化或检查赛季（如果赛季过期则重置）
function CheckBattlePassSeason()
    local today = GetTodayString()
    local bpCfg = GameConfig.BATTLE_PASS
    -- 首次进入：设置赛季起始日
    if battlePassState.seasonStartDay == "" then
        battlePassState.seasonStartDay = today
        print("[战令] 赛季开始: " .. today)
        return
    end
    -- 判断赛季是否过期
    local startY, startM, startD = battlePassState.seasonStartDay:match("(%d+)-(%d+)-(%d+)")
    if not startY then
        battlePassState.seasonStartDay = today
        return
    end
    local startTime = os.time({ year = tonumber(startY), month = tonumber(startM), day = tonumber(startD) })
    local nowY, nowM, nowD = today:match("(%d+)-(%d+)-(%d+)")
    local nowTime = os.time({ year = tonumber(nowY), month = tonumber(nowM), day = tonumber(nowD) })
    local daysPassed = math.floor((nowTime - startTime) / 86400)
    if daysPassed >= bpCfg.seasonDays then
        -- 赛季重置
        battlePassState.seasonStartDay = today
        battlePassState.level = 0
        battlePassState.exp = 0
        battlePassState.dailyProgress = {}
        battlePassState.weeklyProgress = {}
        battlePassState.seasonProgress = {}
        battlePassState.dailyClaimed = {}
        battlePassState.weeklyClaimed = {}
        battlePassState.seasonClaimed = {}
        battlePassState.freeRewardClaimed = {}
        battlePassState.premiumRewardClaimed = {}
        battlePassState.lastDailyReset = ""
        battlePassState.lastWeeklyReset = ""
        print("[战令] 赛季重置! 新赛季开始: " .. today)
    end
end


--- 获取赛季剩余天数
function GetBattlePassRemainingDays()
    local today = GetTodayString()
    local bpCfg = GameConfig.BATTLE_PASS
    if battlePassState.seasonStartDay == "" then return bpCfg.seasonDays end
    local startY, startM, startD = battlePassState.seasonStartDay:match("(%d+)-(%d+)-(%d+)")
    if not startY then return bpCfg.seasonDays end
    local startTime = os.time({ year = tonumber(startY), month = tonumber(startM), day = tonumber(startD) })
    local nowY, nowM, nowD = today:match("(%d+)-(%d+)-(%d+)")
    local nowTime = os.time({ year = tonumber(nowY), month = tonumber(nowM), day = tonumber(nowD) })
    local daysPassed = math.floor((nowTime - startTime) / 86400)
    return math.max(0, bpCfg.seasonDays - daysPassed)
end


--- 战令每日任务重置
function CheckBattlePassDailyReset()
    local today = GetTodayString()
    if battlePassState.lastDailyReset ~= today then
        battlePassState.lastDailyReset = today
        battlePassState.dailyProgress = {}
        battlePassState.dailyClaimed = {}
        print("[战令] 每日任务已重置: " .. today)
    end
end


--- 战令每周任务重置
function CheckBattlePassWeeklyReset()
    local week = GetWeekString()
    if battlePassState.lastWeeklyReset ~= week then
        battlePassState.lastWeeklyReset = week
        battlePassState.weeklyProgress = {}
        battlePassState.weeklyClaimed = {}
        print("[战令] 每周任务已重置: " .. week)
    end
end


--- 追踪战令任务进度 (同时追踪每日、每周、赛季中匹配的任务)
function TrackBattlePassTask(taskId, amount)
    CheckBattlePassSeason()
    CheckBattlePassDailyReset()
    CheckBattlePassWeeklyReset()
    amount = amount or 1
    -- 每日
    for _, t in ipairs(GameConfig.BATTLE_PASS.dailyTasks) do
        if t.id == taskId then
            battlePassState.dailyProgress[taskId] = (battlePassState.dailyProgress[taskId] or 0) + amount
        end
    end
    -- 每周
    for _, t in ipairs(GameConfig.BATTLE_PASS.weeklyTasks) do
        if t.id == taskId then
            battlePassState.weeklyProgress[taskId] = (battlePassState.weeklyProgress[taskId] or 0) + amount
        end
    end
    -- 赛季
    for _, t in ipairs(GameConfig.BATTLE_PASS.seasonTasks) do
        if t.id == taskId then
            battlePassState.seasonProgress[taskId] = (battlePassState.seasonProgress[taskId] or 0) + amount
        end
    end
end


--- 给战令增加经验 (自动升级)
function AddBattlePassExp(amount)
    if amount <= 0 then return end
    local bpCfg = GameConfig.BATTLE_PASS
    battlePassState.exp = battlePassState.exp + amount
    -- 循环升级
    while battlePassState.level < bpCfg.maxLevel do
        local needed = bpCfg.expPerLevel[battlePassState.level + 1] or 9999
        if battlePassState.exp >= needed then
            battlePassState.exp = battlePassState.exp - needed
            battlePassState.level = battlePassState.level + 1
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                "战令升级! Lv." .. battlePassState.level, 2.0, { 255, 220, 80 }, 18)
            print("[战令] 升级到 Lv." .. battlePassState.level)
        else
            break
        end
    end
    -- 满级溢出处理
    if battlePassState.level >= bpCfg.maxLevel then
        battlePassState.exp = 0
    end
end


--- 领取战令任务奖励 (返回经验并标记已领取)
function ClaimBattlePassTaskReward(taskType, taskId)
    local bpCfg = GameConfig.BATTLE_PASS
    local tasks, progress, claimed
    if taskType == "daily" then
        tasks = bpCfg.dailyTasks
        progress = battlePassState.dailyProgress
        claimed = battlePassState.dailyClaimed
    elseif taskType == "weekly" then
        tasks = bpCfg.weeklyTasks
        progress = battlePassState.weeklyProgress
        claimed = battlePassState.weeklyClaimed
    elseif taskType == "season" then
        tasks = bpCfg.seasonTasks
        progress = battlePassState.seasonProgress
        claimed = battlePassState.seasonClaimed
    else
        return false
    end
    -- 找到任务
    local task = nil
    for _, t in ipairs(tasks) do
        if t.id == taskId then task = t; break end
    end
    if not task then return false end
    local prog = progress[taskId] or 0
    if prog < task.target then return false end
    if claimed[taskId] then return false end
    claimed[taskId] = true
    AddBattlePassExp(task.exp)
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.30,
        task.name .. " +" .. task.exp .. " 战令经验", 1.8, { 200, 180, 255 }, 15)
    SaveGameProgress()
    return true
end


--- 领取战令等级的免费奖励
function ClaimBattlePassFreeReward(level)
    local bpCfg = GameConfig.BATTLE_PASS
    if level < 1 or level > bpCfg.maxLevel then return false end
    if battlePassState.level < level then return false end
    if battlePassState.freeRewardClaimed[level] then return false end
    battlePassState.freeRewardClaimed[level] = true
    local reward = bpCfg.freeRewards[level]
    if reward then
        GrantBattlePassReward(reward)
    end
    SaveGameProgress()
    return true
end


--- 领取战令等级的高级奖励 (看广告)
function ClaimBattlePassPremiumReward(level)
    local bpCfg = GameConfig.BATTLE_PASS
    if level < 1 or level > bpCfg.maxLevel then return false end
    if battlePassState.level < level then return false end
    if battlePassState.premiumRewardClaimed[level] then return false end
    battlePassState.premiumRewardClaimed[level] = true
    local reward = bpCfg.premiumRewards[level]
    if reward then
        GrantBattlePassReward(reward)
    end
    SaveGameProgress()
    return true
end


--- 发放战令奖励 (通用)
function GrantBattlePassReward(reward)
    if reward.jade and reward.jade > 0 then
        playerInfo.jade = playerInfo.jade + reward.jade
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35,
            "+" .. reward.jade .. " 虎符", 1.5, { 255, 220, 100 }, 16)
    end
    if reward.frag and reward.frag > 0 then
        for _ = 1, reward.frag do
            local idx = math.random(1, #SKILL_TECHNIQUES)
            skillFragments[idx] = (skillFragments[idx] or 0) + 1
        end
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.40,
            "+" .. reward.frag .. " 武技残片", 1.5, { 180, 160, 255 }, 14)
    end
    if reward.equipDrop and reward.equipDrop > 0 then
        local tier = reward.equipTier or 3
        for _ = 1, reward.equipDrop do
            local si = math.random(1, #EQUIPMENT_SETS)
            local pi = math.random(1, 7)
            local eq = CreateEquipItem(si, pi, tier, math.random(30, 100))
            if eq then
                playerInfo.totalEquips = (playerInfo.totalEquips or 0) + 1
                local tierName = EQUIP_TIERS[tier] and EQUIP_TIERS[tier].name or "兵甲"
                local tc = EQUIP_TIERS[tier] and EQUIP_TIERS[tier].color or { 200, 200, 200 }
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.45,
                    "获得 " .. tierName .. " 装备!", 1.5, tc, 14)
            end
        end
    end
end


--- 战令红点检测: 是否有可领取的任务经验或奖励
function HasBattlePassRedDot()
    local bpCfg = GameConfig.BATTLE_PASS
    CheckBattlePassSeason()
    CheckBattlePassDailyReset()
    CheckBattlePassWeeklyReset()
    -- 检查每日任务
    for _, t in ipairs(bpCfg.dailyTasks) do
        local prog = battlePassState.dailyProgress[t.id] or 0
        if prog >= t.target and not battlePassState.dailyClaimed[t.id] then return true end
    end
    -- 检查每周任务
    for _, t in ipairs(bpCfg.weeklyTasks) do
        local prog = battlePassState.weeklyProgress[t.id] or 0
        if prog >= t.target and not battlePassState.weeklyClaimed[t.id] then return true end
    end
    -- 检查赛季任务
    for _, t in ipairs(bpCfg.seasonTasks) do
        local prog = battlePassState.seasonProgress[t.id] or 0
        if prog >= t.target and not battlePassState.seasonClaimed[t.id] then return true end
    end
    -- 检查可领取的等级奖励
    for lv = 1, math.min(battlePassState.level, bpCfg.maxLevel) do
        if not battlePassState.freeRewardClaimed[lv] then return true end
    end
    return false
end
