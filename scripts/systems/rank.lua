-- ============================================================================
-- systems/rank.lua - 三国武灵录
-- ============================================================================
local CWP = require("network.CloudWriteProxy")


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

    -- 服务端权威模式：走 RPC
    if rawget(_G, "cl_state") then
        local ClientNet = require("network.Client")
        ClientNet.Request("report_score", {
            scoreType = "combat_power", value = power,
            skillCount = skillCount, heroCount = heroCount,
        }, function(resp)
            if resp.ok then
                print("[战力] 服务端上报成功: " .. tostring(power))
                welfareState.powerLoaded = false
                welfareState.powerLoading = false
                LoadPowerRank()
            else
                print("[战力] 服务端上报失败: " .. tostring(resp.msg))
            end
        end)
        return
    end

    if CWP.IsAvailable() then
        -- 批量上报: 战力 + 技能数 + 武灵数（1次RPC代替3次）
        CWP.Write({
            { key = PROJECT_PREFIX .. "combat_power", value = power, int = true },
            { key = PROJECT_PREFIX .. "skill_count", value = skillCount, int = true },
            { key = PROJECT_PREFIX .. "hero_count", value = heroCount, int = true },
        }, "战力上报", {
            ok = function()
                print("[战力] 上报成功: " .. tostring(power))
                welfareState.powerLoaded = false
                welfareState.powerLoading = false
                LoadPowerRank()
            end,
            error = function(code, reason)
                print("[战力] 上报失败: " .. tostring(reason))
            end,
        })
    else
        print("[战力] 写入通道不可用，仅本地模拟")
        -- 开发模式下本地模拟
        if not welfareState.powerRank then
            welfareState.powerRank = {}
        end
        local myName = playerInfo.name or "我"
        local found = false
        for _, entry in ipairs(welfareState.powerRank) do
            if entry.name == myName then
                entry.power = power
                found = true
                break
            end
        end
        if not found then
            table.insert(welfareState.powerRank, 1, { name = myName, power = power, userId = 0 })
        end
        table.sort(welfareState.powerRank, function(a, b) return a.power > b.power end)
        welfareState.powerLoaded = true
    end
end


---- 加载战力排行榜数据
function LoadPowerRank()
    if not rawget(_G, "clientCloud") then return end
    if welfareState.powerLoading then return end
    welfareState.powerLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "combat_power", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
            local filtered = {}
            for _, item in ipairs(rankList) do
                if not CloudManager.IsPlayerRankHidden(item.player) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, item.player)
            end
            if #userIds == 0 then
                welfareState.powerRank = {}
                welfareState.powerLoading = false
                welfareState.powerLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local sc = item.iscore or {}
                        local power = sc[PROJECT_PREFIX .. "combat_power"] or 0
                        local name = nameMap[item.player] or ("玩家" .. tostring(item.player))
                        table.insert(result, {
                            name = name, power = power, userId = item.player,
                            skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                            heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                            realmIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1,
                        })
                    end
                    welfareState.powerRank = result
                    welfareState.powerLoading = false
                    welfareState.powerLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local sc = item.iscore or {}
                        local power = sc[PROJECT_PREFIX .. "combat_power"] or 0
                        table.insert(result, {
                            name = "玩家" .. tostring(item.player), power = power, userId = item.player,
                            skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                            heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                            realmIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1,
                        })
                    end
                    welfareState.powerRank = result
                    welfareState.powerLoading = false
                    welfareState.powerLoaded = true
                end,
            })
        end,
        error = function()
            welfareState.powerLoading = false
            welfareState.powerLoaded = true
            welfareState.powerRank = {}
        end,
    })
end


-- ============================================================================
-- 境界排行榜 (上报 & 加载)
-- ============================================================================
function ReportRealmScore()
    local idx = playerInfo.rankIdx or 1
    if idx <= 0 then return end

    -- 服务端权威模式
    if rawget(_G, "cl_state") then
        local ClientNet = require("network.Client")
        ClientNet.Request("report_score", {
            scoreType = "realm_level", value = idx,
        }, function(resp)
            if resp.ok then
                print("[境界] 服务端上报成功: " .. tostring(idx))
                welfareState.realmLoaded = false
                welfareState.realmLoading = false
                LoadRealmRank()
            else
                print("[境界] 服务端上报失败: " .. tostring(resp.msg))
            end
        end)
        return
    end

    CWP.SetInt(PROJECT_PREFIX .. "realm_level", idx, "境界上报", {
        ok = function()
            print("[境界] 上报成功: " .. tostring(idx) .. " (" .. GetRankDisplayName(idx) .. ")")
            welfareState.realmLoaded = false
            welfareState.realmLoading = false
            LoadRealmRank()
        end,
        error = function(code, reason)
            print("[境界] 上报失败: " .. tostring(reason))
        end,
    })
end


function LoadRealmRank()
    if not rawget(_G, "clientCloud") then return end
    if welfareState.realmLoading then return end
    welfareState.realmLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "realm_level", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
            local filtered = {}
            for _, item in ipairs(rankList) do
                if not CloudManager.IsPlayerRankHidden(item.player) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, item.player)
            end
            if #userIds == 0 then
                welfareState.realmRank = {}
                welfareState.realmLoading = false
                welfareState.realmLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local sc = item.iscore or {}
                        local rIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1
                        local name = nameMap[item.player] or ("玩家" .. tostring(item.player))
                        table.insert(result, {
                            name = name, rankIdx = rIdx, userId = item.player,
                            power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                            skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                            heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                        })
                    end
                    welfareState.realmRank = result
                    welfareState.realmLoading = false
                    welfareState.realmLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local sc = item.iscore or {}
                        local rIdx = sc[PROJECT_PREFIX .. "realm_level"] or 1
                        table.insert(result, {
                            name = "玩家" .. tostring(item.player), rankIdx = rIdx, userId = item.player,
                            power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                            skillCount = sc[PROJECT_PREFIX .. "skill_count"] or 0,
                            heroCount = sc[PROJECT_PREFIX .. "hero_count"] or 0,
                        })
                    end
                    welfareState.realmRank = result
                    welfareState.realmLoading = false
                    welfareState.realmLoaded = true
                end,
            })
        end,
        error = function()
            welfareState.realmLoading = false
            welfareState.realmLoaded = true
            welfareState.realmRank = {}
        end,
    })
end


-- ============================================================================
-- 桩逼王排行榜 (打桩伤害排行 - 上报 & 加载)
-- ============================================================================
function ReportDummyScore(damage)
    if damage <= 0 then return end
    local intDmg = math.floor(damage)

    -- 服务端权威模式
    if rawget(_G, "cl_state") then
        local ClientNet = require("network.Client")
        ClientNet.Request("report_score", {
            scoreType = "dummy_damage", value = intDmg,
        }, function(resp)
            if resp.ok then
                print("[桩逼王] 服务端上报成功: " .. tostring(intDmg))
                welfareState.dummyLoaded = false
                welfareState.dummyLoading = false
            else
                print("[桩逼王] 服务端上报失败: " .. tostring(resp.msg))
            end
        end)
        return
    end

    CWP.SetInt(PROJECT_PREFIX .. "dummy_damage", intDmg, "桩逼王上报", {
        ok = function()
            print("[桩逼王] 上报成功: " .. tostring(intDmg))
            welfareState.dummyLoaded = false
            welfareState.dummyLoading = false
        end,
        error = function(code, reason)
            print("[桩逼王] 上报失败: " .. tostring(reason))
        end,
    })
end


function LoadDummyRank()
    if not rawget(_G, "clientCloud") then return end
    if welfareState.dummyLoading then return end
    welfareState.dummyLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "dummy_damage", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
            local filtered = {}
            for _, item in ipairs(rankList) do
                if not CloudManager.IsPlayerRankHidden(item.player) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, item.player)
            end
            if #userIds == 0 then
                welfareState.dummyRank = {}
                welfareState.dummyLoading = false
                welfareState.dummyLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local sc = item.iscore or {}
                        local dmg = sc[PROJECT_PREFIX .. "dummy_damage"] or 0
                        local name = nameMap[item.player] or ("玩家" .. tostring(item.player))
                        table.insert(result, {
                            name = name, damage = dmg, userId = item.player,
                            power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                        })
                    end
                    welfareState.dummyRank = result
                    welfareState.dummyLoading = false
                    welfareState.dummyLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local sc = item.iscore or {}
                        local dmg = sc[PROJECT_PREFIX .. "dummy_damage"] or 0
                        table.insert(result, {
                            name = "玩家" .. tostring(item.player), damage = dmg, userId = item.player,
                            power = sc[PROJECT_PREFIX .. "combat_power"] or 0,
                        })
                    end
                    welfareState.dummyRank = result
                    welfareState.dummyLoading = false
                    welfareState.dummyLoaded = true
                end,
            })
        end,
        error = function()
            welfareState.dummyLoading = false
            welfareState.dummyLoaded = true
            welfareState.dummyRank = {}
        end,
    })
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
-- 排位赛 - 云端排行榜
-- ============================================================================
-- ============================================================================
-- 爬塔 - 云端排行榜
-- ============================================================================
function ReportTowerFloor()
    local floor = towerState.highestFloor

    -- 服务端权威模式
    if rawget(_G, "cl_state") then
        local ClientNet = require("network.Client")
        ClientNet.Request("report_score", {
            scoreType = "tower_floor", value = floor,
        }, function(resp)
            if resp.ok then
                print("[爬塔] 服务端上报成功: " .. tostring(floor))
                towerState.rankLoaded = false
                towerState.rankLoading = false
            else
                print("[爬塔] 服务端上报失败: " .. tostring(resp.msg))
            end
        end)
        return
    end

    CWP.SetInt(PROJECT_PREFIX .. "tower_floor", floor, "爬塔上报", {
        ok = function()
            print("[爬塔] 上报成功: " .. tostring(floor))
            towerState.rankLoaded = false
            towerState.rankLoading = false
        end,
        error = function(code, reason)
            print("[爬塔] 上报失败: " .. tostring(reason))
        end,
    })
end


function LoadTowerLeaderboard()
    if not rawget(_G, "clientCloud") then
        towerState.rankLoaded = true
        towerState.rankLoading = false
        return
    end
    if towerState.rankLoading then return end
    towerState.rankLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "tower_floor", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
            local filtered = {}
            for _, item in ipairs(rankList) do
                if not CloudManager.IsPlayerRankHidden(item.player) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, item.player)
            end
            if #userIds == 0 then
                towerState.rankList = {}
                towerState.rankLoading = false
                towerState.rankLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local fl = item.iscore and item.iscore[PROJECT_PREFIX .. "tower_floor"] or 0
                        local name = nameMap[item.player] or ("玩家" .. tostring(item.player))
                        table.insert(result, { name = name, floor = fl, userId = item.player })
                    end
                    towerState.rankList = result
                    towerState.rankLoading = false
                    towerState.rankLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local fl = item.iscore and item.iscore[PROJECT_PREFIX .. "tower_floor"] or 0
                        table.insert(result, { name = "玩家" .. tostring(item.player), floor = fl, userId = item.player })
                    end
                    towerState.rankList = result
                    towerState.rankLoading = false
                    towerState.rankLoaded = true
                end,
            })
        end,
        error = function()
            towerState.rankLoading = false
            towerState.rankLoaded = true
            towerState.rankList = {}
        end,
    })
end


function ReportRankedScore()
    local score = rankedState.score

    -- 服务端权威模式
    if rawget(_G, "cl_state") then
        local ClientNet = require("network.Client")
        ClientNet.Request("report_score", {
            scoreType = "ranked_score", value = score,
        }, function(resp)
            if resp.ok then
                print("[排位] 服务端上报成功: " .. tostring(score))
                rankedState.rankLoaded = false
                rankedState.rankLoading = false
            else
                print("[排位] 服务端上报失败: " .. tostring(resp.msg))
            end
        end)
        return
    end

    CWP.SetInt(PROJECT_PREFIX .. "ranked_score", score, "排位上报", {
        ok = function()
            print("[排位] 上报成功: " .. tostring(score))
            rankedState.rankLoaded = false
            rankedState.rankLoading = false
        end,
        error = function(code, reason)
            print("[排位] 上报失败: " .. tostring(reason))
        end,
    })
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
    if not rawget(_G, "clientCloud") then
        rankedState.rankLoaded = true
        rankedState.rankLoading = false
        return
    end
    if rankedState.rankLoading then return end
    rankedState.rankLoading = true
    clientCloud:GetRankList(PROJECT_PREFIX .. "ranked_score", 0, 100, {
        ok = function(rankList)
            -- 过滤封禁玩家并截取前50
            local filtered = {}
            for _, item in ipairs(rankList) do
                if not CloudManager.IsPlayerRankHidden(item.player) then
                    filtered[#filtered + 1] = item
                    if #filtered >= 50 then break end
                end
            end
            rankList = filtered
            local userIds = {}
            for _, item in ipairs(rankList) do
                table.insert(userIds, item.player)
            end
            if #userIds == 0 then
                rankedState.rankList = {}
                rankedState.rankLoading = false
                rankedState.rankLoaded = true
                return
            end
            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local nameMap = {}
                    for _, info in ipairs(nicknames) do
                        nameMap[info.userId] = info.nickname
                    end
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local sc = item.iscore and item.iscore[PROJECT_PREFIX .. "ranked_score"] or 0
                        local name = nameMap[item.player] or ("玩家" .. tostring(item.player))
                        table.insert(result, { name = name, score = sc, userId = item.player })
                    end
                    rankedState.rankList = result
                    rankedState.rankLoading = false
                    rankedState.rankLoaded = true
                end,
                onError = function()
                    local result = {}
                    for _, item in ipairs(rankList) do
                        local sc = item.iscore and item.iscore[PROJECT_PREFIX .. "ranked_score"] or 0
                        table.insert(result, { name = "玩家" .. tostring(item.player), score = sc, userId = item.player })
                    end
                    rankedState.rankList = result
                    rankedState.rankLoading = false
                    rankedState.rankLoaded = true
                end,
            })
        end,
        error = function()
            rankedState.rankLoading = false
            rankedState.rankLoaded = true
            rankedState.rankList = {}
        end,
    })
end
