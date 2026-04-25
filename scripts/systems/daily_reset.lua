-- ============================================================================
-- systems/daily_reset.lua - 三国武灵录
-- ============================================================================


function CheckDailyReset()
    local today = GetTodayString()
    if dailyTaskState.lastResetDay ~= today then
        dailyTaskState.lastResetDay = today
        dailyTaskState.progress = {}
        dailyTaskState.claimed = {}
        dailyTaskState.allClaimedBonus = false
        print("[每日] 任务已重置: " .. today)
    end
end


function CheckDailyDungeonReset()
    local today = GetTodayString()
    if dailyDungeonState.lastResetDay ~= today then
        dailyDungeonState.lastResetDay = today
        dailyDungeonState.completed = { false, false, false }
        -- 基于日期种子生成今日部位 (同一天所有人相同)
        local dayNum = tonumber(os.date("%j")) or 1
        dailyDungeonState.todaySlot = ((dayNum - 1) % 7) + 1
        print("[每日副本] 已重置: " .. today .. " 今日部位: " .. EQUIP_SLOT_NAMES[dailyDungeonState.todaySlot])
    end
end


function CheckResourceDungeonReset()
    local today = GetTodayString()
    if resourceDungeonState.lastResetDay ~= today then
        resourceDungeonState.lastResetDay = today
        resourceDungeonState.completed = { false, false, false }
        print("[探索副本] 已重置: " .. today)
    end
end


function CheckSpinWheelReset()
    local today = GetTodayDateStr()
    if welfareState.spinWheel.lastDate ~= today then
        welfareState.spinWheel.lastDate = today
        welfareState.spinWheel.freeUsed = false
        welfareState.spinWheel.adSpins = 0
        welfareState.spinWheel.spinning = false
        welfareState.spinWheel.resultIdx = 0
        welfareState.spinWheel.resultGranted = false
        welfareState.spinWheel.angle = 0
    end
end


function CheckCardFlipReset()
    local today = GetTodayDateStr()
    if welfareState.cardFlip.lastDate ~= today then
        welfareState.cardFlip.lastDate = today
        welfareState.cardFlip.freeUsed = false
        welfareState.cardFlip.adFlips = 0
        welfareState.cardFlip.flipped = {false,false,false,false,false,false}
        -- 随机生成6张牌
        welfareState.cardFlip.cards = {}
        for i = 1, 6 do
            welfareState.cardFlip.cards[i] = math.random(1, #CARD_POOL)
        end
    end
end
