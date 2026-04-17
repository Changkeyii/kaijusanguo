-- ============================================================================
-- systems/ad.lua - 涓夊浗姝︾伒褰?
-- ============================================================================
---@diagnostic disable: undefined-global


-- 骞垮憡闄愬埗宸茬Щ闄わ紝浠呯伒鐭冲箍鍛婁繚鐣欐瘡鏃?0娆¤鏁?

--- 瀹夊叏鐨勫箍鍛婂洖璋冨寘瑁呭櫒锛氶槻姝㈠洖璋冨唴寮傚父瀵艰嚧娓告垙宕╂簝
--- @param callback function 鍘熷鍥炶皟
--- @return function 瀹夊叏鍖呰鍚庣殑鍥炶皟
function SafeAdCallback(callback)
    return function(result)
        local ok, err = pcall(function()
            ResumeAfterAd()
            -- 鐪熷疄骞垮憡鎴愬姛: 閫掑姣忔棩骞垮憡鎬昏鏁?
            if result and result.success then
                IncrementDailyAdTotal()
            end
            if callback then callback(result) end
        end)
        if not ok then
            print("[骞垮憡] 鍥炶皟寮傚父(宸插畨鍏ㄥ鐞?: " .. tostring(err))
            -- 纭繚鍗充娇鍥炶皟宕╂簝锛屾父鎴忎粛鐒朵繚瀛樿繘搴?
            pcall(SaveGameProgress)
        end
    end
end


--- 妫€鏌ュ箍鍛婃槸鍚﹀彲浠ユ挱鏀撅紙鏃犻檺鍒讹紝濮嬬粓鍙湅锛?
--- @return boolean canWatch 濮嬬粓杩斿洖true
function CanWatchAd()
    -- 鍏嶅箍鍛婄壒鏉? 鐩存帴杩斿洖 false, 璋冪敤澶勮蛋 else(DEV) 鍒嗘敮鐩存帴缁欏鍔?
    if playerInfo.ad_free then return false end
    return true
end


--- 妫€鏌ヤ粖鏃ユ垬鏂楀箍鍛婃槸鍚﹀凡鍏嶉櫎 (姣忔棩鍏嶅箍鍛婂崱: 鐪嬫弧5娆″箍鍛婂悗鎴樻枟涓箍鍛婅嚜鍔ㄨ烦杩?
--- @return boolean isFree 鎴樻枟骞垮憡鏄惁鍏嶉櫎
function IsBattleAdFree()
    -- 姘镐箙鍏嶅箍鍛婄壒鏉冧紭鍏?
    if playerInfo.ad_free then return true end
    -- 璺ㄦ棩閲嶇疆
    local today = os.date("%Y-%m-%d")
    if gameSettings.dailyAdDate ~= today then
        gameSettings.dailyAdCount = 0
        gameSettings.dailyAdDate = today
    end
    return gameSettings.dailyAdCount >= 3
end


--- 妫€鏌ヤ粖鏃ュ箍鍛婃€绘鏁版槸鍚﹀凡杈句笂闄?(姣忔棩鏈€澶?0娆?
--- 璺ㄦ棩鑷姩閲嶇疆; 棣栨瀹夎 dailyTotalAdDate="" 浼氳Е鍙戦噸缃负0, 涓嶄細璇皝
--- @return boolean limitReached 鏄惁杈惧埌涓婇檺
function IsDailyAdLimitReached()
    local today = os.date("%Y-%m-%d")
    if gameSettings.dailyTotalAdDate ~= today then
        gameSettings.dailyTotalAdCount = 0
        gameSettings.dailyTotalAdDate = today
        SaveSettings()  -- 璺ㄦ棩閲嶇疆鍚庢寔涔呭寲
    end
    return gameSettings.dailyTotalAdCount >= 20
end


--- 璁板綍涓€娆℃垚鍔熺殑骞垮憡瑙傜湅锛堟瘡鏃ヤ笂闄愯鏁?1, 鑷姩淇濆瓨锛?
--- 鍙湪鐪熷疄骞垮憡鎴愬姛鍥炶皟涓皟鐢? DEV妯″紡涓嶈鏁?
function IncrementDailyAdTotal()
    local today = os.date("%Y-%m-%d")
    if gameSettings.dailyTotalAdDate ~= today then
        gameSettings.dailyTotalAdCount = 0
        gameSettings.dailyTotalAdDate = today
    end
    gameSettings.dailyTotalAdCount = gameSettings.dailyTotalAdCount + 1
    print("[骞垮憡] 浠婃棩骞垮憡瑙傜湅: " .. gameSettings.dailyTotalAdCount .. "/20")
    SaveSettings()
end


--- 甯︽瘡鏃ヤ笂闄愭鏌ョ殑骞垮憡鏄剧ず (鏇夸唬鐩存帴璋冪敤 sdk:ShowRewardVideoAd)
--- @param wrappedCallback function SafeAdCallback 鍖呰鍚庣殑鍥炶皟
function ShowAdSafe(wrappedCallback)
    if IsDailyAdLimitReached() then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "浠婃棩骞垮憡宸茶揪涓婇檺(20娆?", 1.5, {255, 180, 80}, 14)
        return
    end
    -- 閫氳繃绱㈠紩璋冪敤閬垮厤琚?replace_all 鏇挎崲
    sdk["ShowRewardVideoAd"](sdk, wrappedCallback)
end


function ReportAdWatch()
    -- 鏈湴璁℃暟锛堟棤璁轰簯鏄惁鍙敤閮芥洿鏂帮級
    welfareState.localAdCount = (welfareState.localAdCount or 0) + 1
    print("[骞垮憡] 鏈湴骞垮憡璁℃暟: " .. tostring(welfareState.localAdCount))

    -- 鏈湴鍏堣鏇存柊璐＄尞姒滐紙绔嬪嵆鍙锛?
    UpdateContribRankLocally()

    if CloudAPI.IsAvailable() then
        print("[骞垮憡] CloudAPI 鍙敤锛屼笂鎶?ad_watch_count +1")
        CloudAPI:Add(PROJECT_PREFIX .. "ad_watch_count", 1, {
            ok = function()
                print("[骞垮憡] 涓婃姤鎴愬姛锛屽悗鍙板埛鏂版帓琛屾")
                -- 涓婃姤鎴愬姛鍚庡湪鍚庡彴鍒锋柊鎺掕姒滐紙鑾峰彇鍏朵粬鐜╁鐨勬渶鏂版暟鎹級
                welfareState.contribLoading = false
                LoadContribRank()
            end,
            error = function(err)
                print("[骞垮憡] 涓婃姤澶辫触: " .. tostring(err))
                -- 涓婃姤澶辫触涔熸棤濡紝鏈湴鏁版嵁宸插厛琛屾洿鏂?
            end,
        })
    else
        print("[骞垮憡] CloudAPI 涓嶅彲鐢紝浠呮湰鍦拌鏁?)
    end
end


--- 绂忓埄涓績涓撶敤骞垮憡涓婃姤锛堜粎涓婃姤璐＄尞姒滐級
function ReportAdWatchWelfare()
    welfareState.localAdCount = (welfareState.localAdCount or 0) + 1
    print("[骞垮憡-绂忓埄] 绂忓埄绛惧埌骞垮憡 | 绱: " .. tostring(welfareState.localAdCount))
    UpdateContribRankLocally()
    if CloudAPI.IsAvailable() then
        CloudAPI:Add(PROJECT_PREFIX .. "ad_watch_count", 1, {
            ok = function()
                welfareState.contribLoading = false
                LoadContribRank()
            end,
            error = function(err)
                print("[骞垮憡-绂忓埄] 涓婃姤澶辫触: " .. tostring(err))
            end,
        })
    end
end


--- 鐪嬪箍鍛婅幏鍙栬檸绗?
function WatchAdForJade()
    local reward = 2000
    if sdk then
        ShowAdSafe(SafeAdCallback(function(result)
            if result.success then
                playerInfo.jade = playerInfo.jade + reward
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "+" .. reward .. " 铏庣", 1.5, { 120, 255, 180 }, 16)
                print("=== 骞垮憡濂栧姳: +" .. reward .. " 铏庣 ===")
                ReportAdWatch()
                SaveGameProgress()
            end
        end))
    else
        if not IsMobilePlatform() then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "浠呯Щ鍔ㄧ鍙鐪嬪箍鍛?, 1.5, { 200, 150, 100 }, 14)
            return
        end
        playerInfo.jade = playerInfo.jade + reward
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "+" .. reward .. " 铏庣", 1.5, { 120, 255, 180 }, 16)
        print("=== [DEV] 骞垮憡濂栧姳: +" .. reward .. " 铏庣 ===")
        ReportAdWatch()
    end
end


--- 澶辫触鍚庣湅骞垮憡鑾峰彇棰濆铏庣
function WatchAdForRevive()
    if IsBattleAdFree() then
        local bonus = GameConfig.AD_REVIVE_BONUS_JADE
        playerInfo.jade = playerInfo.jade + bonus
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍏嶅箍鍛婂崱宸茶嚜鍔ㄩ鍙?+" .. bonus .. " 铏庣", 1.5, { 120, 255, 180 }, 16)
        print("=== [鍏嶅箍鍛婂崱] 鑷姩棰嗗彇澶辫触濂栧姳: +" .. bonus .. " 铏庣 ===")
        SaveGameProgress()
        return
    end
    if sdk then
        ShowAdSafe(SafeAdCallback(function(result)
            if result.success then
                local bonus = GameConfig.AD_REVIVE_BONUS_JADE
                playerInfo.jade = playerInfo.jade + bonus
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "+" .. bonus .. " 铏庣", 1.5, { 255, 220, 100 }, 16)
                ReportAdWatch()
                SaveGameProgress()
            end
        end))
    else
        if not IsMobilePlatform() then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "浠呯Щ鍔ㄧ鍙鐪嬪箍鍛?, 1.5, { 200, 150, 100 }, 14)
            return
        end
        local bonus = GameConfig.AD_REVIVE_BONUS_JADE
        playerInfo.jade = playerInfo.jade + bonus
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "+" .. bonus .. " 铏庣", 1.5, { 255, 220, 100 }, 16)
        print("=== [DEV] 澶辫触骞垮憡濂栧姳: +" .. bonus .. " 铏庣 ===")
        ReportAdWatch()
    end
end


--- 鎴樻枟鑳滃埄鍚庣湅骞垮憡缈诲€嶅鍔?
function WatchAdForDoubleReward()
    if gameState.adDoubledReward then return end  -- 宸查杩?
    local bonusJade = gameState.winJade or 0
    if bonusJade <= 0 then return end
    if IsBattleAdFree() then
        gameState.adDoubledReward = true
        playerInfo.jade = playerInfo.jade + bonusJade
        gameState.winJade = bonusJade * 2
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "鍏嶅箍鍛婂崱宸茶嚜鍔ㄧ炕鍊?+" .. bonusJade .. " 铏庣", 1.5, { 120, 255, 180 }, 18)
        print("=== [鍏嶅箍鍛婂崱] 鑷姩缈诲€嶅鍔? +" .. bonusJade .. " 铏庣 ===")
        SaveGameProgress()
        return
    end
    if sdk then
        ShowAdSafe(SafeAdCallback(function(result)
            if result.success then
                gameState.adDoubledReward = true
                playerInfo.jade = playerInfo.jade + bonusJade
                gameState.winJade = bonusJade * 2  -- 鏇存柊鏄剧ず涓虹炕鍊嶅悗鐨勫€?
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "缈诲€? +" .. bonusJade .. " 铏庣", 1.5, { 120, 255, 180 }, 18)
                print("=== 骞垮憡缈诲€嶅鍔? +" .. bonusJade .. " 铏庣 ===")
                ReportAdWatch()
                SaveGameProgress()
            end
        end))
    else
        if not IsMobilePlatform() then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "浠呯Щ鍔ㄧ鍙鐪嬪箍鍛?, 1.5, { 200, 150, 100 }, 14)
            return
        end
        gameState.adDoubledReward = true
        playerInfo.jade = playerInfo.jade + bonusJade
        gameState.winJade = bonusJade * 2
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "缈诲€? +" .. bonusJade .. " 铏庣", 1.5, { 120, 255, 180 }, 18)
        print("=== [DEV] 骞垮憡缈诲€嶅鍔? +" .. bonusJade .. " 铏庣 ===")
        ReportAdWatch()
    end
end

