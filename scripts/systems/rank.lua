-- ============================================================================
-- systems/rank.lua - 三国武灵录
-- 所有排行榜读写统一走服务端 RPC（多人联网游戏，clientCloud 不可用）
-- ============================================================================


--- 上报一次有效广告观看到云排行榜
--- 本地先行更新贡献榜数据（保证看完广告后立即有数据可看）
function UpdateContribRankLocally()
    if not welfareState.contribRank then
        welfareState.contribRank = {}
    end
    local myName = playerInfo.name or "我"
    local myCount = welfareState.localAdCount or 1
    local found = false
    for _, entry in ipairs(welfareState.contribRank) do
        if entry.name == myName then
            entry.count = myCount
            found = true
            break
        end
    end
    if not found then
        table.insert(welfareState.contribRank, { name = myName, count = myCount })
    end
    table.sort(welfareState.contribRank, function(a, b) return a.count > b.count end)
    welfareState.contribLoaded = true
end


-- ============================================================================
-- 战力排行榜 (上报 & 加载)
-- ============================================================================

---- 上报战力到云排行榜（使用 SetInt 设置绝对值）
function ReportPowerScore()
    local power = CalcPlayerTotalPower()
    if power <= 0 then return end

    -- 统计技能数和武灵数，附带上报
    local skillCount = 0
    for i, sk in pairs(SKILL_DEFS) do
        if sk.unlocked then skillCount = skillCount + 1 end
    end
    local heroCount = #GetAllOwnedHeroes()

    if not rawget(_G, "cl_state") then
        print("[战力] 服务端未连接，跳过上报")
        return
    end

    local ClientNet = require("network.Client")
    ClientNet.Request("report_score", {
        scoreType = "combat_power", value = power,
        skillCount = skillCount, heroCount = heroCount,
    }, function(ok, code, data, msg)
        if ok then
            print("[战力] 服务端上报成功: " .. tostring(power))
            welfareState.powerLoaded = false
            welfareState.powerLoading = false
            LoadPowerRank()
        else
            print("[战力] 服务端上报失败: " .. tostring(msg))
        end
    end)
end


---- 将服务端返回的排行榜原始数据转换为客户端展示格式（战力榜）
local function _parsePowerRankEntries(entries)
    local result = {}
    for _, item in ipairs(entries) do
        local uid = item.userId
        if not CloudManager.IsPlayerRankHidden(uid) then
            local sc = item.iscore or {}
            local power = sc[PROJECT_PREFIX .. "combat_power"] or 0
            local name = (item.name and item.name ~= "") and item.name or ("玩家" .. tostring(uid))
            result[#result + 1] = {
                name = name, power = power, userId = uid,
                skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                heroCount  = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                realmIdx   = sc[PROJECT_PREFIX .. "realm_level"] or 1,
            }
            if #result >= 50 then break end
        end
    end
    return result
end

---- 加载战力排行榜数据（服务端 RPC）
function LoadPowerRank()
    if welfareState.powerLoading then return end

    if not rawget(_G, "cl_state") then
        print("[战力] 服务端未连接，跳过加载排行榜")
        return
    end

    welfareState.powerLoading = true
    local ClientNet = require("network.Client")
    ClientNet.Request("get_rank_list", {
        key = PROJECT_PREFIX .. "combat_power",
        start = 0, count = 100,
    }, function(ok, code, data, msg)
        if ok and data and data.list then
            welfareState.powerRank = _parsePowerRankEntries(data.list)
            print("[战力] 服务端排行榜加载成功, 共 " .. #welfareState.powerRank .. " 条")
        else
            print("[战力] 服务端排行榜加载失败: " .. tostring(msg))
        end
        welfareState.powerLoading = false
        welfareState.powerLoaded = true
    end)
end


-- ============================================================================
-- 境界排行榜 (上报 & 加载)
-- ============================================================================
function ReportRealmScore()
    local idx = playerInfo.rankIdx or 1
    if idx <= 0 then return end

    if not rawget(_G, "cl_state") then
        print("[境界] 服务端未连接，跳过上报")
        return
    end

    local ClientNet = require("network.Client")
    ClientNet.Request("report_score", {
        scoreType = "realm_level", value = idx,
    }, function(ok, code, data, msg)
        if ok then
            print("[境界] 服务端上报成功: " .. tostring(idx))
            welfareState.realmLoaded = false
            welfareState.realmLoading = false
            LoadRealmRank()
        else
            print("[境界] 服务端上报失败: " .. tostring(msg))
        end
    end)
end


function LoadRealmRank()
    if welfareState.realmLoading then return end

    if not rawget(_G, "cl_state") then
        print("[境界] 服务端未连接，跳过加载排行榜")
        return
    end

    welfareState.realmLoading = true
    local ClientNet = require("network.Client")
    ClientNet.Request("get_rank_list", {
        key = PROJECT_PREFIX .. "realm_level",
        start = 0, count = 100,
    }, function(ok, code, data, msg)
        if ok and data and data.list then
            local result = {}
            for _, item in ipairs(data.list) do
                local uid = item.userId
                if not CloudManager.IsPlayerRankHidden(uid) then
                    local sc = item.iscore or {}
                    local name = (item.name and item.name ~= "") and item.name or ("玩家" .. tostring(uid))
                    result[#result + 1] = {
                        name = name, rankIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1, userId = uid,
                        power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                        skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                        heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                    }
                    if #result >= 50 then break end
                end
            end
            welfareState.realmRank = result
            print("[境界] 服务端排行榜加载成功, 共 " .. #result .. " 条")
        else
            print("[境界] 服务端排行榜加载失败: " .. tostring(msg))
        end
        welfareState.realmLoading = false
        welfareState.realmLoaded = true
    end)
end


-- ============================================================================
-- 桩逼王排行榜 (打桩伤害排行 - 上报 & 加载)
-- ============================================================================
function ReportDummyScore(damage)
    if damage <= 0 then return end
    local intDmg = math.floor(damage)

    if not rawget(_G, "cl_state") then
        print("[桩逼王] 服务端未连接，跳过上报")
        return
    end

    local ClientNet = require("network.Client")
    ClientNet.Request("report_score", {
        scoreType = "dummy_damage", value = intDmg,
    }, function(ok, code, data, msg)
        if ok then
            print("[桩逼王] 服务端上报成功: " .. tostring(intDmg))
            welfareState.dummyLoaded = false
            welfareState.dummyLoading = false
        else
            print("[桩逼王] 服务端上报失败: " .. tostring(msg))
        end
    end)
end


function LoadDummyRank()
    if welfareState.dummyLoading then return end

    if not rawget(_G, "cl_state") then
        print("[桩逼王] 服务端未连接，跳过加载排行榜")
        return
    end

    welfareState.dummyLoading = true
    local ClientNet = require("network.Client")
    ClientNet.Request("get_rank_list", {
        key = PROJECT_PREFIX .. "dummy_damage",
        start = 0, count = 100,
    }, function(ok, code, data, msg)
        if ok and data and data.list then
            local result = {}
            for _, item in ipairs(data.list) do
                local uid = item.userId
                if not CloudManager.IsPlayerRankHidden(uid) then
                    local sc = item.iscore or {}
                    local dmg = sc[PROJECT_PREFIX .. "dummy_damage"] or 0
                    local name = (item.name and item.name ~= "") and item.name or ("玩家" .. tostring(uid))
                    result[#result + 1] = {
                        name = name, damage = dmg, userId = uid,
                        power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                    }
                    if #result >= 50 then break end
                end
            end
            welfareState.dummyRank = result
            print("[桩逼王] 服务端排行榜加载成功, 共 " .. #result .. " 条")
        else
            print("[桩逼王] 服务端排行榜加载失败: " .. tostring(msg))
        end
        welfareState.dummyLoading = false
        welfareState.dummyLoaded = true
    end)
end


function LoadFactionLevelRank()
    if factionUI.rankLoading then return end
    factionUI.rankLoading = true
    LoadFactionRankFrom("factionUI")
end


--- 加载阵营排行榜到主排行榜Tab（写入 welfareState）
function LoadFactionLevelRankForTab()
    if welfareState.factionRankLoading then return end
    welfareState.factionRankLoading = true
    LoadFactionRankFrom("welfareState")
end


-- ============================================================================
-- 爬塔 - 云端排行榜
-- ============================================================================
function ReportTowerFloor()
    local floor = towerState.highestFloor

    if not rawget(_G, "cl_state") then
        print("[爬塔] 服务端未连接，跳过上报")
        return
    end

    local ClientNet = require("network.Client")
    ClientNet.Request("report_score", {
        scoreType = "tower_floor", value = floor,
    }, function(ok, code, data, msg)
        if ok then
            print("[爬塔] 服务端上报成功: " .. tostring(floor))
            towerState.rankLoaded = false
            towerState.rankLoading = false
        else
            print("[爬塔] 服务端上报失败: " .. tostring(msg))
        end
    end)
end


function LoadTowerLeaderboard()
    if towerState.rankLoading then return end

    if not rawget(_G, "cl_state") then
        print("[爬塔] 服务端未连接，跳过加载排行榜")
        towerState.rankLoaded = true
        towerState.rankLoading = false
        return
    end

    towerState.rankLoading = true
    local ClientNet = require("network.Client")
    ClientNet.Request("get_rank_list", {
        key = PROJECT_PREFIX .. "tower_floor",
        start = 0, count = 100,
    }, function(ok, code, data, msg)
        if ok and data and data.list then
            local result = {}
            for _, item in ipairs(data.list) do
                local uid = item.userId
                if not CloudManager.IsPlayerRankHidden(uid) then
                    local sc = item.iscore or {}
                    local fl = sc[PROJECT_PREFIX .. "tower_floor"] or 0
                    local name = (item.name and item.name ~= "") and item.name or ("玩家" .. tostring(uid))
                    result[#result + 1] = { name = name, floor = fl, userId = uid }
                    if #result >= 50 then break end
                end
            end
            towerState.rankList = result
            print("[爬塔] 服务端排行榜加载成功, 共 " .. #result .. " 条")
        else
            print("[爬塔] 服务端排行榜加载失败: " .. tostring(msg))
            towerState.rankList = {}
        end
        towerState.rankLoading = false
        towerState.rankLoaded = true
    end)
end


-- ============================================================================
-- 排位赛 - 云端排行榜
-- ============================================================================
function ReportRankedScore()
    local score = rankedState.score

    if not rawget(_G, "cl_state") then
        print("[排位] 服务端未连接，跳过上报")
        return
    end

    local ClientNet = require("network.Client")
    ClientNet.Request("report_score", {
        scoreType = "ranked_score", value = score,
    }, function(ok, code, data, msg)
        if ok then
            print("[排位] 服务端上报成功: " .. tostring(score))
            rankedState.rankLoaded = false
            rankedState.rankLoading = false
        else
            print("[排位] 服务端上报失败: " .. tostring(msg))
        end
    end)
end


--- 服务端权威 Elo 结算回调
--- 当服务端返回排位结果时，用权威数据覆盖本地 rankedState
---@param result table {isWin, serverDelta, newElo, wins, losses}
function OnRankedResult(result)
    if not result then return end
    print("[排位] 服务端权威结算: Elo=" .. tostring(result.newElo)
        .. " delta=" .. tostring(result.serverDelta)
        .. " wins=" .. tostring(result.wins)
        .. " losses=" .. tostring(result.losses))
    -- 用服务端权威值覆盖本地
    rankedState.score = result.newElo or rankedState.score
    rankedState.wins = result.wins or rankedState.wins
    rankedState.losses = result.losses or rankedState.losses
    if rankedState.score > rankedState.highestScore then
        rankedState.highestScore = rankedState.score
    end
    -- 更新展示用的 delta（覆盖本地计算值）
    if result.serverDelta then
        gameState.rankedDelta = result.serverDelta
    end
    -- 刷新排行榜
    rankedState.rankLoaded = false
    rankedState.rankLoading = false
end


function LoadRankedLeaderboard()
    if rankedState.rankLoading then return end

    if not rawget(_G, "cl_state") then
        print("[排位] 服务端未连接，跳过加载排行榜")
        rankedState.rankLoaded = true
        rankedState.rankLoading = false
        return
    end

    rankedState.rankLoading = true
    local ClientNet = require("network.Client")
    ClientNet.Request("get_rank_list", {
        key = PROJECT_PREFIX .. "ranked_score",
        start = 0, count = 100,
    }, function(ok, code, data, msg)
        if ok and data and data.list then
            local result = {}
            for _, item in ipairs(data.list) do
                local uid = item.userId
                if not CloudManager.IsPlayerRankHidden(uid) then
                    local sc = item.iscore or {}
                    local s = sc[PROJECT_PREFIX .. "ranked_score"] or 0
                    local name = (item.name and item.name ~= "") and item.name or ("玩家" .. tostring(uid))
                    result[#result + 1] = { name = name, score = s, userId = uid }
                    if #result >= 50 then break end
                end
            end
            rankedState.rankList = result
            print("[排位] 服务端排行榜加载成功, 共 " .. #result .. " 条")
        else
            print("[排位] 服务端排行榜加载失败: " .. tostring(msg))
            rankedState.rankList = {}
        end
        rankedState.rankLoading = false
        rankedState.rankLoaded = true
    end)
end
