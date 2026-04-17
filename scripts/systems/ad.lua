-- ============================================================================
-- systems/ad.lua - 三国武灵录
-- ============================================================================
---@diagnostic disable: undefined-global


-- 广告限制已移除，仅灵石广告保留每日20次计数

--- 安全的广告回调包装器：防止回调内异常导致游戏崩溃
--- @param callback function 原始回调
--- @return function 安全包装后的回调
function SafeAdCallback(callback)
    return function(result)
        local ok, err = pcall(function()
            ResumeAfterAd()
            -- 真实广告成功: 递增每日广告总计数
            if result and result.success then
                IncrementDailyAdTotal()
            end
            if callback then callback(result) end
        end)
        if not ok then
            print("[广告] 回调异常(已安全处理): " .. tostring(err))
            -- 确保即使回调崩溃，游戏仍然保存进度
            pcall(SaveGameProgress)
        end
    end
end


--- 检查广告是否可以播放（无限制，始终可看）
--- @return boolean canWatch 始终返回true
function CanWatchAd()
    -- 免广告特权: 直接返回 false, 调用处走 else(DEV) 分支直接给奖励
    if playerInfo.ad_free then return false end
    return true
end


--- 检查今日战斗广告是否已免除 (每日免广告卡: 看满5次广告后战斗中广告自动跳过)
--- @return boolean isFree 战斗广告是否免除
function IsBattleAdFree()
    -- 永久免广告特权优先
    if playerInfo.ad_free then return true end
    -- 跨日重置
    local today = os.date("%Y-%m-%d")
    if gameSettings.dailyAdDate ~= today then
        gameSettings.dailyAdCount = 0
        gameSettings.dailyAdDate = today
    end
    return gameSettings.dailyAdCount >= 3
end


--- 检查今日广告总次数是否已达上限 (每日最多20次)
--- 跨日自动重置; 首次安装 dailyTotalAdDate="" 会触发重置为0, 不会误封
--- @return boolean limitReached 是否达到上限
function IsDailyAdLimitReached()
    local today = os.date("%Y-%m-%d")
    if gameSettings.dailyTotalAdDate ~= today then
        gameSettings.dailyTotalAdCount = 0
        gameSettings.dailyTotalAdDate = today
        SaveSettings()  -- 跨日重置后持久化
    end
    return gameSettings.dailyTotalAdCount >= 20
end


--- 记录一次成功的广告观看（每日上限计数+1, 自动保存）
--- 只在真实广告成功回调中调用, DEV模式不计数
function IncrementDailyAdTotal()
    local today = os.date("%Y-%m-%d")
    if gameSettings.dailyTotalAdDate ~= today then
        gameSettings.dailyTotalAdCount = 0
        gameSettings.dailyTotalAdDate = today
    end
    gameSettings.dailyTotalAdCount = gameSettings.dailyTotalAdCount + 1
    print("[广告] 今日广告观看: " .. gameSettings.dailyTotalAdCount .. "/20")
    SaveSettings()
end


--- 带每日上限检查的广告显示 (替代直接调用 sdk:ShowRewardVideoAd)
--- @param wrappedCallback function SafeAdCallback 包装后的回调
function ShowAdSafe(wrappedCallback)
    if IsDailyAdLimitReached() then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "今日广告已达上限(20次)", 1.5, {255, 180, 80}, 14)
        return
    end
    -- 通过索引调用避免被 replace_all 替换
    sdk["ShowRewardVideoAd"](sdk, wrappedCallback)
end


function ReportAdWatch()
    -- 本地计数（无论云是否可用都更新）
    welfareState.localAdCount = (welfareState.localAdCount or 0) + 1
    print("[广告] 本地广告计数: " .. tostring(welfareState.localAdCount))

    -- 本地先行更新贡献榜（立即可见）
    UpdateContribRankLocally()

    -- 服务端权威模式
    if rawget(_G, "cl_state") then
        local ClientNet = require("network.Client")
        ClientNet.Request("report_ad_watch", {
            adType = "general",
        }, function(ok, code, data, msg)
            if ok then
                print("[广告] 服务端上报成功")
                welfareState.contribLoading = false
                LoadContribRank()
            else
                print("[广告] 服务端上报失败: " .. tostring(msg))
            end
        end)
        return
    end

    print("[广告] 服务端未连接，仅本地计数")
end


--- 福利中心专用广告上报（仅上报贡献榜）
function ReportAdWatchWelfare()
    welfareState.localAdCount = (welfareState.localAdCount or 0) + 1
    print("[广告-福利] 福利签到广告 | 累计: " .. tostring(welfareState.localAdCount))
    UpdateContribRankLocally()

    -- 服务端权威模式
    if rawget(_G, "cl_state") then
        local ClientNet = require("network.Client")
        ClientNet.Request("report_ad_watch", {
            adType = "welfare",
        }, function(ok, code, data, msg)
            if ok then
                welfareState.contribLoading = false
                LoadContribRank()
            else
                print("[广告-福利] 服务端上报失败: " .. tostring(msg))
            end
        end)
        return
    end
end


--- 看广告获取虎符
function WatchAdForJade()
    local reward = 2000
    if sdk then
        ShowAdSafe(SafeAdCallback(function(result)
            if result.success then
                playerInfo.jade = playerInfo.jade + reward
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "+" .. reward .. " 虎符", 1.5, { 120, 255, 180 }, 16)
                print("=== 广告奖励: +" .. reward .. " 虎符 ===")
                ReportAdWatch()
                SaveGameProgress()
            end
        end))
    else
        if not IsMobilePlatform() then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "仅移动端可观看广告", 1.5, { 200, 150, 100 }, 14)
            return
        end
        playerInfo.jade = playerInfo.jade + reward
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "+" .. reward .. " 虎符", 1.5, { 120, 255, 180 }, 16)
        print("=== [DEV] 广告奖励: +" .. reward .. " 虎符 ===")
        ReportAdWatch()
    end
end


--- 失败后看广告获取额外虎符
function WatchAdForRevive()
    if IsBattleAdFree() then
        local bonus = GameConfig.AD_REVIVE_BONUS_JADE
        playerInfo.jade = playerInfo.jade + bonus
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "免广告卡已自动领取 +" .. bonus .. " 虎符", 1.5, { 120, 255, 180 }, 16)
        print("=== [免广告卡] 自动领取失败奖励: +" .. bonus .. " 虎符 ===")
        SaveGameProgress()
        return
    end
    if sdk then
        ShowAdSafe(SafeAdCallback(function(result)
            if result.success then
                local bonus = GameConfig.AD_REVIVE_BONUS_JADE
                playerInfo.jade = playerInfo.jade + bonus
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "+" .. bonus .. " 虎符", 1.5, { 255, 220, 100 }, 16)
                ReportAdWatch()
                SaveGameProgress()
            end
        end))
    else
        if not IsMobilePlatform() then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "仅移动端可观看广告", 1.5, { 200, 150, 100 }, 14)
            return
        end
        local bonus = GameConfig.AD_REVIVE_BONUS_JADE
        playerInfo.jade = playerInfo.jade + bonus
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "+" .. bonus .. " 虎符", 1.5, { 255, 220, 100 }, 16)
        print("=== [DEV] 失败广告奖励: +" .. bonus .. " 虎符 ===")
        ReportAdWatch()
    end
end


--- 战斗胜利后看广告翻倍奖励
function WatchAdForDoubleReward()
    if gameState.adDoubledReward then return end  -- 已领过
    local bonusJade = gameState.winJade or 0
    if bonusJade <= 0 then return end
    if IsBattleAdFree() then
        gameState.adDoubledReward = true
        playerInfo.jade = playerInfo.jade + bonusJade
        gameState.winJade = bonusJade * 2
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "免广告卡已自动翻倍 +" .. bonusJade .. " 虎符", 1.5, { 120, 255, 180 }, 18)
        print("=== [免广告卡] 自动翻倍奖励: +" .. bonusJade .. " 虎符 ===")
        SaveGameProgress()
        return
    end
    if sdk then
        ShowAdSafe(SafeAdCallback(function(result)
            if result.success then
                gameState.adDoubledReward = true
                playerInfo.jade = playerInfo.jade + bonusJade
                gameState.winJade = bonusJade * 2  -- 更新显示为翻倍后的值
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "翻倍! +" .. bonusJade .. " 虎符", 1.5, { 120, 255, 180 }, 18)
                print("=== 广告翻倍奖励: +" .. bonusJade .. " 虎符 ===")
                ReportAdWatch()
                SaveGameProgress()
            end
        end))
    else
        if not IsMobilePlatform() then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "仅移动端可观看广告", 1.5, { 200, 150, 100 }, 14)
            return
        end
        gameState.adDoubledReward = true
        playerInfo.jade = playerInfo.jade + bonusJade
        gameState.winJade = bonusJade * 2
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "翻倍! +" .. bonusJade .. " 虎符", 1.5, { 120, 255, 180 }, 18)
        print("=== [DEV] 广告翻倍奖励: +" .. bonusJade .. " 虎符 ===")
        ReportAdWatch()
    end
end
