-- ============================================================================
-- systems/tasks.lua - 涓夊浗姝︾伒褰?
-- ============================================================================


--- 妫€鏌ュ苟鎵ц姣忓懆鎺掕姒滃鍔辩粨绠?
--- 鍦ㄦ父鎴忓惎鍔?瀛樻。鍔犺浇鍚庤皟鐢ㄤ竴娆?
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
        print("[鍛ㄥ鍔盷 鏈懆宸茬粨绠? " .. weekKey)
        return
    end

    local myUid = CloudAPI.GetUserId()
    local pendingChecks = #WEEKLY_RANK_REWARDS
    local generatedMails = {}

    for _, cfg in ipairs(WEEKLY_RANK_REWARDS) do
        CloudAPI:GetRankList(cfg.key, 0, 20, {
            ok = function(rankList)
                -- 鎵惧埌鑷繁鐨勬帓鍚?
                local myRank = 0
                for ri, item in ipairs(rankList) do
                    if _getRankItemUserId(item) == myUid then
                        myRank = ri
                        break
                    end
                end

                if myRank > 0 then
                    -- 鏍规嵁鎺掑悕纭畾濂栧姳
                    for _, tier in ipairs(cfg.tiers) do
                        if myRank <= tier.maxRank then
                            local mailId = "weekly_" .. weekKey .. "_" .. cfg.key
                            local rankDesc = (myRank == 1) and "绗?鍚? or ("绗? .. myRank .. "鍚?)
                            table.insert(generatedMails, {
                                id = mailId,
                                title = cfg.name .. "鍛ㄦ濂栧姳",
                                sender = "鎺掕姒滅粨绠?,
                                content = "鎭枩姝︾伒澶т汉鍦ㄦ湰鍛? .. cfg.name .. "涓崳鑾? .. rankDesc .. "锛佺壒姝ゅ彂鏀惧鍔憋紝璇锋煡鏀躲€傛帓鍚嶈秺楂樺鍔辫秺涓板帤锛屼笅鍛ㄧ户缁姞娌癸紒",
                                rewards = tier.rewards,
                            })
                            break  -- 鍙彇鏈€楂樻。濂栧姳
                        end
                    end
                end

                pendingChecks = pendingChecks - 1
                if pendingChecks <= 0 then
                    -- 鎵€鏈夋帓琛屾妫€鏌ュ畬鎴?
                    if #generatedMails > 0 then
                        for _, mail in ipairs(generatedMails) do
                            table.insert(welfareState.mailDefs, mail)
                        end
                        print("[鍛ㄥ鍔盷 鐢熸垚 " .. #generatedMails .. " 灏佸鍔遍偖浠?)
                        if rawget(_G, "ShowToast") then ShowToast("鏈懆鎺掕姒滃鍔卞凡鍙戞斁锛岃鏌ョ湅閭欢锛?) end
                    else
                        print("[鍛ㄥ鍔盷 鏈懆鏈笂姒? 鏃犲鍔?)
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


-- 姣忔棩浠诲姟绾㈢偣: 鏈夊彲棰嗗彇浣嗘湭棰嗗彇鐨勪换鍔?
function HasDailyTaskRedDot()
    for _, task in ipairs(DAILY_TASKS) do
        if not dailyTaskState.claimed[task.id] then
            local prog = dailyTaskState.progress[task.id] or 0
            if prog >= task.target then return true end
        end
    end
    return false
end


-- 鍛ㄤ换鍔＄孩鐐? 鏈夊彲棰嗗彇浣嗘湭棰嗗彇鐨勫懆浠诲姟
function HasWeeklyTaskRedDot()
    for _, task in ipairs(WEEKLY_TASKS) do
        if not weeklyTaskState.claimed[task.id] then
            local prog = weeklyTaskState.progress[task.id] or 0
            if prog >= task.target then return true end
        end
    end
    return false
end


-- 鎴愬氨绾㈢偣: 鏈夊彲棰嗗彇浣嗘湭棰嗗彇鐨勬垚灏?
function HasAchievementRedDot()
    for _, ach in ipairs(ACHIEVEMENTS) do
        if not achievementClaimed[ach.id] then
            local val = GetAchievementStatValue(ach.stat)
            if val >= ach.target then return true end
        end
    end
    return false
end


-- 淇鏃ュ綍鎸夐挳绾㈢偣 (鏍戠姸: 浠讳竴瀛愰〉绛句寒 >> 鐖惰妭鐐逛寒)
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
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍏ㄥ嫟濂栧姳 +500铏庣", 2.0, { 255, 220, 80 }, 16)
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
        print("[鍛ㄤ换鍔 宸查噸缃? " .. week)
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
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍛ㄥ叏鍕ゅ鍔?+1300铏庣", 2.0, { 255, 200, 60 }, 17)
    SaveGameProgress()
    return true
end


-- ============================================================================
-- 鎴愬氨缁熻鑾峰彇
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

