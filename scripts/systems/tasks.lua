-- ============================================================================
-- systems/tasks.lua - 三国武灵录
-- ============================================================================


--- 检查并执行每周排行榜奖励结算
--- 在游戏启动/存档加载后调用一次
local function _getRankItemUserId(item)
    if rawget(_G, "ResolveRankListUserId") then
        return ResolveRankListUserId(item)
    end
    return tonumber(item and (item.userId or item.player or item.uid)) or 0
end

function CheckWeeklyRankRewards()
    if not CloudAPI.IsAvailable() then return end

    local weekKey = GetWeekKey()
    -- 宸茬粨绠楀垯璺宠繃
    if welfareState.lastWeeklySettled == weekKey then
        print("[周奖励] 本周已结算: " .. weekKey)
        return
    end

    local myUid = CloudAPI.GetUserId()
    local pendingChecks = #WEEKLY_RANK_REWARDS
    local generatedMails = {}

    for _, cfg in ipairs(WEEKLY_RANK_REWARDS) do
        CloudAPI:GetRankList(cfg.key, 0, 20, {
            ok = function(rankList)
                -- 找到自己的排名
                local myRank = 0
                for ri, item in ipairs(rankList) do
                    if _getRankItemUserId(item) == myUid then
                        myRank = ri
                        break
                    end
                end

                if myRank > 0 then
                    -- 根据排名确定奖励
                    for _, tier in ipairs(cfg.tiers) do
                        if myRank <= tier.maxRank then
                            local mailId = "weekly_" .. weekKey .. "_" .. cfg.key
                            local rankDesc = (myRank == 1) and "第1名" or ("第" .. myRank .. "名")
                            table.insert(generatedMails, {
                                id = mailId,
                                title = cfg.name .. "周榜奖励",
                                sender = "排行榜结算",
                                content = "恭喜武灵大人在本周" .. cfg.name .. "中荣获" .. rankDesc .. "！特此发放奖励，请查收。排名越高奖励越丰厚，下周继续加油！",
                                rewards = tier.rewards,
                            })
                            break  -- 只取最高档奖励
                        end
                    end
                end

                pendingChecks = pendingChecks - 1
                if pendingChecks <= 0 then
                    -- 所有排行榜检查完成
                    if #generatedMails > 0 then
                        for _, mail in ipairs(generatedMails) do
                            table.insert(welfareState.mailDefs, mail)
                        end
                        print("[周奖励] 生成 " .. #generatedMails .. " 封奖励邮件")
                        if rawget(_G, "ShowToast") then ShowToast("本周排行榜奖励已发放，请查看邮件！") end
                    else
                        print("[周奖励] 本周未上榜, 无奖励")
                    end
                    welfareState.lastWeeklySettled = weekKey
                    SaveGameProgress()
                end
            end,
            error = function()
                pendingChecks = pendingChecks - 1
                if pendingChecks <= 0 then
                    welfareState.lastWeeklySettled = weekKey
                    SaveGameProgress()
                end
            end,
        })
    end
end


-- 每日任务红点: 有可领取但未领取的任务
function HasDailyTaskRedDot()
    for _, task in ipairs(DAILY_TASKS) do
        if not dailyTaskState.claimed[task.id] then
            local prog = dailyTaskState.progress[task.id] or 0
            if prog >= task.target then return true end
        end
    end
    return false
end


-- 周任务红点: 有可领取但未领取的周任务
function HasWeeklyTaskRedDot()
    for _, task in ipairs(WEEKLY_TASKS) do
        if not weeklyTaskState.claimed[task.id] then
            local prog = weeklyTaskState.progress[task.id] or 0
            if prog >= task.target then return true end
        end
    end
    return false
end


-- 成就红点: 有可领取但未领取的成就
function HasAchievementRedDot()
    for _, ach in ipairs(ACHIEVEMENTS) do
        if not achievementClaimed[ach.id] then
            local val = GetAchievementStatValue(ach.stat)
            if val >= ach.target then return true end
        end
    end
    return false
end


-- 修行日录按钮红点 (树状: 任一子页签亮 >> 父节点亮)
function HasProgressRedDot()
    return HasDailyTaskRedDot() or HasWeeklyTaskRedDot() or HasAchievementRedDot()
end


function TrackDailyTask(taskId, amount)
    CheckDailyReset()
    dailyTaskState.progress[taskId] = (dailyTaskState.progress[taskId] or 0) + (amount or 1)
end


function ClaimDailyReward(taskIdx)
    local task = DAILY_TASKS[taskIdx]
    if not task then return false end
    local prog = dailyTaskState.progress[task.id] or 0
    if prog < task.target then return false end
    if dailyTaskState.claimed[task.id] then return false end
    dailyTaskState.claimed[task.id] = true
    GrantRewardTable(task.reward)
    SaveGameProgress()
    return true
end


function ClaimDailyAllBonus()
    if dailyTaskState.allClaimedBonus then return false end
    for _, task in ipairs(DAILY_TASKS) do
        if not dailyTaskState.claimed[task.id] then return false end
    end
    dailyTaskState.allClaimedBonus = true
    playerInfo.jade = playerInfo.jade + 500
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "全勤奖励 +500玉壁", 2.0, { 255, 220, 80 }, 18)
    SaveGameProgress()
    return true
end


function CheckWeeklyReset()
    local week = GetWeekString()
    if weeklyTaskState.lastResetWeek ~= week then
        weeklyTaskState.lastResetWeek = week
        weeklyTaskState.progress = {}
        weeklyTaskState.claimed = {}
        weeklyTaskState.allClaimedBonus = false
        print("[周任务] 已重置: " .. week)
    end
end


function TrackWeeklyTask(taskId, amount)
    CheckWeeklyReset()
    weeklyTaskState.progress[taskId] = (weeklyTaskState.progress[taskId] or 0) + (amount or 1)
end


function ClaimWeeklyReward(taskIdx)
    local task = WEEKLY_TASKS[taskIdx]
    if not task then return false end
    local prog = weeklyTaskState.progress[task.id] or 0
    if prog < task.target then return false end
    if weeklyTaskState.claimed[task.id] then return false end
    weeklyTaskState.claimed[task.id] = true
    GrantRewardTable(task.reward)
    SaveGameProgress()
    return true
end


function ClaimWeeklyAllBonus()
    if weeklyTaskState.allClaimedBonus then return false end
    for _, task in ipairs(WEEKLY_TASKS) do
        if not weeklyTaskState.claimed[task.id] then return false end
    end
    weeklyTaskState.allClaimedBonus = true
    playerInfo.jade = playerInfo.jade + 1300
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "周全勤奖励 +1300玉壁", 2.0, { 255, 200, 60 }, 18)
    SaveGameProgress()
    return true
end


-- ============================================================================
-- 成就统计获取
-- ============================================================================
function GetAchievementStatValue(statName)
    if statName == "totalWins" then
        return playerInfo.totalWins
    elseif statName == "totalBattles" then
        return playerInfo.totalBattles
    elseif statName == "totalGachas" then
        return playerInfo.totalGachas
    elseif statName == "totalEquips" then
        return playerInfo.totalEquips
    elseif statName == "totalDecompose" then
        return playerInfo.totalDecompose
    elseif statName == "totalEnhance" then
        return playerInfo.totalEnhance
    elseif statName == "totalFriends" then
        return playerInfo.totalFriends or 0
    elseif statName == "totalFriendReqs" then
        return playerInfo.totalFriendReqs or 0
    elseif statName == "totalFactionChat" then
        return playerInfo.totalFactionChat or 0
    elseif statName == "factionJoined" then
        return playerInfo.factionJoined or 0
    elseif statName == "totalFactionCreated" then
        return playerInfo.totalFactionCreated or 0
    elseif statName == "totalRankedBattles" then
        return playerInfo.totalRankedBattles or 0
    elseif statName == "totalRankedWins" then
        return playerInfo.totalRankedWins or 0
    elseif statName == "totalExplores" then
        return playerInfo.totalExplores or 0
    elseif statName == "stagesCleared" then
        local c = 0
        for k, v in pairs(stageStars) do if v and v > 0 then c = c + 1 end end
        return c
    elseif statName == "abyssCleared" then
        local c = 0
        for k, v in pairs(abyssCleared) do if v then c = c + 1 end end
        return c
    end
    return 0
end


function ClaimAchievement(achIdx)
    local ach = ACHIEVEMENTS[achIdx]
    if not ach then return false end
    if achievementClaimed[ach.id] then return false end
    local val = GetAchievementStatValue(ach.stat)
    if val < ach.target then return false end
    achievementClaimed[ach.id] = true
    GrantRewardTable(ach.reward)
    SaveGameProgress()
    return true
end

