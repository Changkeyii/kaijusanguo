-- ============================================================================
-- slg/slg_logic.lua - 三国武灵传：SLG核心逻辑
-- 初始化、回合处理、玩家行动、AI行动、计略
-- ============================================================================

---@diagnostic disable: undefined-global

local Data = require("systems.slg.slg_data")
local State = require("systems.slg.slg_state")

local STRATAGEMS = Data.STRATAGEMS
local AI_PERSONALITY = Data.AI_PERSONALITY
local RANDOM_EVENTS = Data.RANDOM_EVENTS
local BUILDINGS = Data.BUILDINGS
local BONDS = Data.BONDS
local HERO_EVENTS = Data.HERO_EVENTS
local CLASS_CHANGES = Data.CLASS_CHANGES
local QUESTS = Data.QUESTS

local M = {}

-- ============================================================================
-- 初始化
-- ============================================================================
function M.Init()
    local st = worldMapState
    if st.inited then
        State.ResetView()
        return
    end

    st.turn = 1
    st.gold = 500
    st.food = 300
    st.troops = 200
    st.phase = "MAP"
    st.selectedCity = nil
    st.turnReport = nil
    st.scrollY = 0
    st.cityData = {}
    st.searchResult = nil
    st.scoutResult = nil
    st.cloudOffset = 0

    st.diplomacy = {
        shu = { relation = 30, treaty = nil },
        wei = { relation = 20, treaty = nil },
        qun = { relation = 40, treaty = nil },
    }

    for _, city in ipairs(WORLD_CITIES) do
        local owner = city.faction
        if owner == st.playerFaction then owner = "player" end
        st.cityData[city.id] = {
            owner = owner,
            garrison = (owner == "player") and 80 or (40 + city.def * 15),
            level = city.def,
            heroes = {},
            morale = 80,
            buildings = {},  -- {[buildingId] = level} e.g. {farm=1, market=2}
        }
    end

    local playerCities = {}
    for _, city in ipairs(WORLD_CITIES) do
        if st.cityData[city.id].owner == "player" then
            table.insert(playerCities, city.id)
        end
    end
    -- 分配玩家已拥有的所有武将到我方城池 (武将录中的武将 = 可部署武将)
    local heroIdx2 = 0
    if rawget(_G, "HERO_CARDS") then
        for idx = 1, #HERO_CARDS do
            if playerHeroes[idx] and playerHeroes[idx].owned and #playerCities > 0 then
                heroIdx2 = heroIdx2 + 1
                local cityId = playerCities[((heroIdx2 - 1) % #playerCities) + 1]
                table.insert(st.cityData[cityId].heroes, idx)
            end
        end
    end

    local aiFactions = {"wei", "shu", "qun"}
    for _, fac in ipairs(aiFactions) do
        local aiHeroes = {}
        for idx, card in ipairs(HERO_CARDS) do
            if card.faction == fac and not playerHeroes[idx] then
                table.insert(aiHeroes, idx)
            end
        end
        local aiCities = {}
        for _, city in ipairs(WORLD_CITIES) do
            if st.cityData[city.id].owner == fac then
                table.insert(aiCities, city.id)
            end
        end
        if #aiCities > 0 then
            for i, hIdx in ipairs(aiHeroes) do
                local cid = aiCities[((i - 1) % #aiCities) + 1]
                table.insert(st.cityData[cid].heroes, hIdx)
            end
        end
    end

    st.inited = true
    print("[WorldMap] Initialized with " .. #playerCities .. " player cities")
end

-- ============================================================================
-- 建筑系统
-- ============================================================================

--- 查找建筑定义
local function FindBuilding(buildingId)
    for _, b in ipairs(BUILDINGS) do
        if b.id == buildingId then return b end
    end
    return nil
end

--- 升级建筑 (玩家操作)
function M.UpgradeBuilding(cityId, buildingId)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd or cd.owner ~= "player" then return false, "非我方城池" end

    local bDef = FindBuilding(buildingId)
    if not bDef then return false, "未知建筑" end

    local curLv = cd.buildings[buildingId] or 0
    if curLv >= 5 then
        if rawget(_G, "ShowToast") then ShowToast(bDef.name .. " 已满级") end
        return false, "已满级"
    end

    local cost = bDef.cost[curLv + 1]
    if st.gold < cost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需" .. cost .. ")") end
        return false, "金币不足"
    end

    st.gold = st.gold - cost
    cd.buildings[buildingId] = curLv + 1
    if rawget(_G, "ShowToast") then
        ShowToast(bDef.name .. " 升至 Lv." .. (curLv + 1))
    end
    return true, bDef.name .. " Lv." .. (curLv + 1)
end

--- 获取某城某建筑的加成值 (0 = 未建造)
function M.GetBuildingBonus(cityId, buildingId)
    local cd = worldMapState.cityData[cityId]
    if not cd then return 0 end
    local lv = cd.buildings[buildingId] or 0
    if lv == 0 then return 0 end
    local bDef = FindBuilding(buildingId)
    if not bDef then return 0 end
    return bDef.bonus[lv] or 0
end

--- 获取玩家所有城池某建筑的总加成
function M.GetTotalBuildingBonus(buildingId)
    local total = 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd = worldMapState.cityData[city.id]
        if cd and cd.owner == "player" then
            total = total + M.GetBuildingBonus(city.id, buildingId)
        end
    end
    return total
end

-- ============================================================================
-- 武将羁绊系统
-- ============================================================================

--- 获取指定城池中激活的羁绊列表
function M.GetActiveBonds(cityId)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd then return {} end
    local heroSet = {}
    if cd.heroes then
        for _, h in ipairs(cd.heroes) do heroSet[h] = true end
    end

    local active = {}
    for _, bond in ipairs(BONDS) do
        local need = bond.minCount or #bond.heroes
        local count = 0
        for _, hId in ipairs(bond.heroes) do
            if heroSet[hId] then count = count + 1 end
        end
        if count >= need then
            table.insert(active, bond)
        end
    end
    return active
end

--- 获取某城的全部羁绊加成汇总
function M.GetBondBonus(cityId)
    local bonds = M.GetActiveBonds(cityId)
    local bonus = {atkMult=0, defMult=0, hpMult=0, stratBonus=0, critBonus=0}
    for _, b in ipairs(bonds) do
        for k, v in pairs(b.bonus) do
            bonus[k] = (bonus[k] or 0) + v
        end
    end
    return bonus
end

-- ============================================================================
-- 武将事件系统
-- ============================================================================

--- 检查并触发武将事件 (每回合调用)
function M.CheckHeroEvents(report)
    local st = worldMapState
    st.triggeredEvents = st.triggeredEvents or {}
    st.heroStats = st.heroStats or {}

    for _, evt in ipairs(HERO_EVENTS) do
        if not st.triggeredEvents[evt.id] then
            -- 检查玩家是否拥有该武将
            local owned = false
            for _, city in ipairs(WORLD_CITIES) do
                local cd = st.cityData[city.id]
                if cd and cd.owner == "player" then
                    for _, h in ipairs(cd.heroes) do
                        if h == evt.heroId then owned = true; break end
                    end
                end
                if owned then break end
            end
            if owned and evt.condition(st) then
                st.triggeredEvents[evt.id] = true
                local rewardMsg = evt.reward(st)
                table.insert(report, evt.icon .. " 【" .. evt.name .. "】" .. evt.desc)
                if rewardMsg then
                    table.insert(report, "   → " .. rewardMsg)
                end
            end
        end
    end
end

--- 记录武将战斗统计
function M.RecordHeroBattle(heroIdx, isWin)
    local st = worldMapState
    st.heroStats = st.heroStats or {}
    if not st.heroStats[heroIdx] then
        st.heroStats[heroIdx] = {wins=0, battles=0}
    end
    st.heroStats[heroIdx].battles = st.heroStats[heroIdx].battles + 1
    if isWin then
        st.heroStats[heroIdx].wins = st.heroStats[heroIdx].wins + 1
    end
end

-- ============================================================================
-- 转职系统
-- ============================================================================

--- 检查武将是否可以转职
function M.CanClassChange(heroIdx)
    local st = worldMapState
    if st.classChanged and st.classChanged[heroIdx] then return false, "已转职" end
    for _, cc in ipairs(CLASS_CHANGES) do
        if cc.heroId == heroIdx then
            local stats = st.heroStats and st.heroStats[heroIdx]
            local wins = stats and stats.wins or 0
            if wins >= cc.reqWins then
                return true, cc
            else
                return false, "需要" .. cc.reqWins .. "场胜利(当前" .. wins .. ")"
            end
        end
    end
    return false, "无转职路线"
end

--- 执行转职
function M.DoClassChange(heroIdx)
    local st = worldMapState
    local canDo, ccData = M.CanClassChange(heroIdx)
    if not canDo then return false, type(ccData) == "string" and ccData or "无法转职" end

    st.classChanged = st.classChanged or {}
    st.classChanged[heroIdx] = true

    -- 应用永久属性加成
    st.heroBonusAtk = st.heroBonusAtk or {}
    st.heroBonusDef = st.heroBonusDef or {}
    st.heroBonusAtk[heroIdx] = (st.heroBonusAtk[heroIdx] or 0) + (ccData.bonus.atk or 0)
    st.heroBonusDef[heroIdx] = (st.heroBonusDef[heroIdx] or 0) + (ccData.bonus.def or 0)

    return true, ccData.desc
end

-- ============================================================================
-- 任务系统
-- ============================================================================

--- 检查并自动完成任务 (每回合调用)
function M.CheckQuests(report)
    local st = worldMapState
    st.questCompleted = st.questCompleted or {}
    st.questCounters = st.questCounters or {}

    for _, quest in ipairs(QUESTS) do
        if not st.questCompleted[quest.id] then
            if quest.check(st) then
                st.questCompleted[quest.id] = true
                -- 发放奖励
                if quest.reward.gold then st.gold = st.gold + quest.reward.gold end
                if quest.reward.food then st.food = st.food + quest.reward.food end
                local rewardStr = ""
                if quest.reward.gold then rewardStr = rewardStr .. "金" .. quest.reward.gold .. " " end
                if quest.reward.food then rewardStr = rewardStr .. "粮" .. quest.reward.food end
                table.insert(report, quest.icon .. " 任务完成【" .. quest.name .. "】" .. rewardStr)
            end
        end
    end
end

-- ============================================================================
-- 回合处理
-- ============================================================================
function M.EndTurn()
    local report = {}
    local st = worldMapState

    -- 1) 收入 (含建筑加成 + 断粮效果)
    local income, foodIncome, playerCityCount = 0, 0, 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" then
            local prod = city.prod + (cd.level - 1) * 10
            local goldBonus = M.GetBuildingBonus(city.id, "market")
            local foodBonus = M.GetBuildingBonus(city.id, "farm")
            local cityGold = prod + goldBonus
            local cityFood = math.floor(prod * 0.5) + foodBonus
            -- 断粮效果: 产出减半
            if st.cutoffCities[city.id] then
                cityGold = math.floor(cityGold * 0.5)
                cityFood = math.floor(cityFood * 0.5)
            end
            income = income + cityGold
            foodIncome = foodIncome + cityFood
            playerCityCount = playerCityCount + 1
            cd.morale = math.min(100, cd.morale + 3)
        end
    end
    st.gold = st.gold + income
    st.food = st.food + foodIncome
    table.insert(report, {type="income", text="税收 +" .. income .. "金  粮草 +" .. foodIncome})

    -- 2) 自动补兵 (含兵营加成)
    local recruitFood = playerCityCount * 10
    if st.food >= recruitFood then
        st.food = st.food - recruitFood
        for _, city in ipairs(WORLD_CITIES) do
            local cd = st.cityData[city.id]
            if cd.owner == "player" then
                local barracksBonus = M.GetBuildingBonus(city.id, "barracks")
                cd.garrison = cd.garrison + 5 + barracksBonus
            end
        end
        table.insert(report, {type="recruit", text="征兵: 各城 +5(+兵营) (粮 -" .. recruitFood .. ")"})
    else
        table.insert(report, {type="warning", text="粮草不足! 无法自动征兵"})
        for _, city in ipairs(WORLD_CITIES) do
            local cd = st.cityData[city.id]
            if cd.owner == "player" then cd.morale = math.max(30, cd.morale - 5) end
        end
    end

    -- 3) AI 行动 (性格化)
    local aiFactions = {"wei", "shu", "qun"}
    for _, fac in ipairs(aiFactions) do
        local diplo = st.diplomacy[fac]
        -- 已投降势力跳过AI行动
        if diplo and diplo.treaty == "surrendered" then goto continue_ai end
        local personality = AI_PERSONALITY[fac] or AI_PERSONALITY.qun
        local facCities = {}
        for _, city in ipairs(WORLD_CITIES) do
            if st.cityData[city.id].owner == fac then
                table.insert(facCities, city)
                -- 每城补兵量由性格决定
                st.cityData[city.id].garrison = st.cityData[city.id].garrison + personality.recruitRate
            end
        end
        -- 攻击概率由性格参数决定
        local aggression = personality.aggressionBase + (#facCities / #WORLD_CITIES) * personality.aggressionScale
        -- 条约抑制攻击: peace=10%, trade/alliance=不攻击玩家
        if diplo and (diplo.treaty == "trade" or diplo.treaty == "alliance") then
            aggression = aggression * 0.02  -- 几乎不会攻击
        elseif diplo and diplo.treaty == "peace" then
            aggression = aggression * 0.1
        end
        local facName = FACTIONS[fac] and FACTIONS[fac].name or fac

        -- AI 计略 (性格化: 诡诈型更爱用计)
        if #facCities > 0 and math.random() < personality.stratagemChance then
            -- AI 选一座玩家城池施放计略
            local stratagemTargets = {}
            for _, city in ipairs(WORLD_CITIES) do
                local cd = st.cityData[city.id]
                if cd.owner == "player" then
                    table.insert(stratagemTargets, city.id)
                end
            end
            if #stratagemTargets > 0 and not (diplo and (diplo.treaty == "peace" or diplo.treaty == "trade" or diplo.treaty == "alliance")) then
                local stId = stratagemTargets[math.random(#stratagemTargets)]
                local stCity = WORLD_CITIES[stId]
                -- AI 只用火计和离间
                local aiStrats = {"fire", "spy"}
                local picked = aiStrats[math.random(#aiStrats)]
                local strat = nil
                for _, s in ipairs(STRATAGEMS) do
                    if s.id == picked then strat = s; break end
                end
                if strat and math.random() < strat.successRate then
                    local td = st.cityData[stId]
                    if picked == "fire" then
                        td.garrison = math.max(5, td.garrison - 20)
                        table.insert(report, {type="stratagem", text=facName .. " 对 " .. stCity.name .. " 施火计! 驻军-20"})
                    elseif picked == "spy" then
                        td.morale = math.max(20, (td.morale or 80) - 25)
                        table.insert(report, {type="stratagem", text=facName .. " 对 " .. stCity.name .. " 施离间! 士气-25"})
                    end
                else
                    table.insert(report, {type="stratagem", text=facName .. " 的计略被识破!"})
                end
            end
        end

        -- AI 军事行动
        if #facCities > 0 and math.random() < aggression then
            -- 选择出击城池: 优先兵力最多的
            table.sort(facCities, function(a, b)
                return st.cityData[a.id].garrison > st.cityData[b.id].garrison
            end)
            local srcCity = facCities[1]
            local srcData = st.cityData[srcCity.id]
            if srcData.garrison >= personality.defenseThreshold then
                local targets = {}
                for _, connId in ipairs(srcCity.conn) do
                    local tgtOwner = st.cityData[connId].owner
                    if tgtOwner ~= fac then
                        if not (tgtOwner == "player" and diplo and (diplo.treaty == "peace" or diplo.treaty == "trade" or diplo.treaty == "alliance")) then
                            table.insert(targets, {id = connId, garrison = st.cityData[connId].garrison})
                        end
                    end
                end
                if #targets > 0 then
                    -- 目标选择由性格决定
                    local tgtId
                    if personality.preferTarget == "weak" then
                        table.sort(targets, function(a, b) return a.garrison < b.garrison end)
                        tgtId = targets[1].id
                    elseif personality.preferTarget == "strong" then
                        table.sort(targets, function(a, b) return a.garrison > b.garrison end)
                        tgtId = targets[1].id
                    else
                        tgtId = targets[math.random(#targets)].id
                    end
                    local tgtData = st.cityData[tgtId]
                    local tgtCity = WORLD_CITIES[tgtId]
                    local atkPower = srcData.garrison * 0.6 + #srcData.heroes * 15
                    local defPower = tgtData.garrison + tgtData.level * 10 + #tgtData.heroes * 10

                    if atkPower > defPower then
                        local oldOwner = tgtData.owner
                        tgtData.owner = fac
                        tgtData.garrison = math.floor(atkPower - defPower * 0.5)
                        srcData.garrison = math.floor(srcData.garrison * 0.4)
                        local movedHeroes = {}
                        for i = #srcData.heroes, 1, -1 do
                            if #movedHeroes < 2 then
                                table.insert(movedHeroes, srcData.heroes[i])
                                table.remove(srcData.heroes, i)
                            end
                        end
                        for _, h in ipairs(movedHeroes) do table.insert(tgtData.heroes, h) end
                        if oldOwner == "player" then
                            table.insert(report, {type="lost", text="失守! " .. facName .. "(" .. personality.name .. ") 攻占 " .. tgtCity.name})
                        else
                            local oldFacName = FACTIONS[oldOwner] and FACTIONS[oldOwner].name or oldOwner
                            table.insert(report, {type="battle", text=facName .. " 攻占 " .. oldFacName .. "·" .. tgtCity.name})
                        end
                    else
                        srcData.garrison = math.floor(srcData.garrison * 0.7)
                        tgtData.garrison = math.max(5, tgtData.garrison - math.floor(atkPower * 0.3))
                        table.insert(report, {type="battle", text=facName .. " 攻 " .. tgtCity.name .. " 败退"})
                    end
                end
            end
        end
        ::continue_ai::
    end

    -- 4) 外交衰减 + 贸易收入 (由性格决定衰减速度)
    for fac, d in pairs(st.diplomacy) do
        if d.treaty == "surrendered" then goto continue_diplo end  -- 已投降势力跳过
        local personality = AI_PERSONALITY[fac] or AI_PERSONALITY.qun
        local decay = personality.diploDecay or 2
        -- 有条约时衰减减半
        if d.treaty then decay = math.max(1, math.floor(decay * 0.5)) end
        d.relation = math.max(0, d.relation - decay)
        local facName = FACTIONS[fac] and FACTIONS[fac].name or fac

        -- 贸易收入
        if d.treaty == "trade" or d.treaty == "alliance" then
            local bonus = TREATY_DEFS.trade.incomeBonus or 50
            st.gold = st.gold + bonus
            table.insert(report, {type="diplomacy", text=facName .. " 贸易收入 +" .. bonus .. "金"})
        end

        -- 同盟援军预备 (战斗时会用到, 这里只记录)
        -- 条约降级检查: 关系过低时逐级降级
        local treatyIdx = 0
        for ti, tk in ipairs(TREATY_UPGRADE_PATH) do
            if d.treaty == tk then treatyIdx = ti; break end
        end
        if treatyIdx > 0 then
            local td = TREATY_DEFS[d.treaty]
            local breakThreshold = (td and td.reqRelation or 60) * 0.25
            if d.relation < breakThreshold then
                -- 降级到前一级条约
                if treatyIdx > 1 then
                    d.treaty = TREATY_UPGRADE_PATH[treatyIdx - 1]
                    local newName = TREATY_DEFS[d.treaty] and TREATY_DEFS[d.treaty].name or d.treaty
                    table.insert(report, {type="diplomacy", text=facName .. " 关系恶化, 降级为" .. newName})
                else
                    d.treaty = nil
                    table.insert(report, {type="diplomacy", text=facName .. " 撕毁和约!"})
                end
            end
        end
        ::continue_diplo::
    end

    -- 5) 随机事件
    M.ProcessRandomEvents(st, report)

    -- 6) 清除断粮效果 (只持续1回合)
    if next(st.cutoffCities) then
        for cid in pairs(st.cutoffCities) do
            local cName = WORLD_CITIES[cid] and WORLD_CITIES[cid].name or "?"
            table.insert(report, {type="info", text=cName .. " 断粮效果解除"})
        end
        st.cutoffCities = {}
    end

    -- 7) 武将事件检查
    M.CheckHeroEvents(report)

    -- 8) 任务检查
    M.CheckQuests(report)

    st.turn = st.turn + 1
    st.totalTurns = st.totalTurns + 1
    st.turnReport = report
    st.reportScroll = 0
    st.phase = "TURN_REPORT"

    local pCities = 0
    for _, city in ipairs(WORLD_CITIES) do
        if st.cityData[city.id].owner == "player" then pCities = pCities + 1 end
    end
    if pCities == 0 then
        table.insert(st.turnReport, {type="gameover", text="所有城池失守, 大业未成..."})
    elseif pCities >= #WORLD_CITIES then
        table.insert(st.turnReport, {type="victory", text="天下一统! 恭喜称帝!"})
    end
    print("[WorldMap] Turn " .. st.turn .. " ended. Player cities: " .. pCities)
end

-- ============================================================================
-- 随机事件处理
-- ============================================================================
function M.ProcessRandomEvents(st, report)
    if not RANDOM_EVENTS then return end

    -- 每回合最多触发1个事件
    local triggered = false
    -- 打乱顺序避免固定优先级
    local indices = {}
    for i = 1, #RANDOM_EVENTS do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    for _, idx in ipairs(indices) do
        if triggered then break end
        local event = RANDOM_EVENTS[idx]
        -- 检查是否上回合刚触发过同一事件 (防连续)
        local recentlyTriggered = false
        for _, hist in ipairs(st.eventHistory or {}) do
            if hist.id == event.id and (st.turn - hist.turn) <= 2 then
                recentlyTriggered = true
                break
            end
        end
        if not recentlyTriggered and math.random() < event.chance then
            local msg = event.effect(st)
            if msg then
                table.insert(report, {type="event", text=event.icon .. " " .. msg})
                -- 记录历史
                table.insert(st.eventHistory, {id = event.id, turn = st.turn})
                -- 只保留最近10条
                while #st.eventHistory > 10 do
                    table.remove(st.eventHistory, 1)
                end
                triggered = true
            end
        end
    end
end

-- ============================================================================
-- 玩家行军
-- ============================================================================
function M.MoveArmy(fromId, toId, troops, heroes)
    local st = worldMapState
    local fromData, toData = st.cityData[fromId], st.cityData[toId]
    if not fromData or not toData then return false, "无效城池" end
    if fromData.owner ~= "player" then return false, "非我方城池" end
    if toData.owner ~= "player" then return false, "目标非我方城池" end
    if fromData.garrison < troops then return false, "兵力不足" end
    local connected = false
    for _, connId in ipairs(WORLD_CITIES[fromId].conn) do
        if connId == toId then connected = true; break end
    end
    if not connected then return false, "城池不相邻" end
    fromData.garrison = fromData.garrison - troops
    toData.garrison = toData.garrison + troops
    if heroes then
        for _, hIdx in ipairs(heroes) do
            for i, h in ipairs(fromData.heroes) do
                if h == hIdx then
                    table.remove(fromData.heroes, i)
                    table.insert(toData.heroes, hIdx)
                    break
                end
            end
        end
    end
    return true, "调兵完成"
end

-- ============================================================================
-- 武将管理: 兵种切换
-- ============================================================================
function M.SetHeroTroop(heroIdx, troopType)
    local st = worldMapState
    local card = HERO_CARDS[heroIdx]
    if not card then return false, "未知武将" end
    -- 验证兵种是否在该武将的可选列表中
    local opts = card.troopOptions or { card.troopType }
    local valid = false
    for _, t in ipairs(opts) do
        if t == troopType then valid = true; break end
    end
    if not valid then return false, "该武将无法使用此兵种" end
    st.heroTroopChoice[heroIdx] = troopType
    return true, TROOP_TYPES[troopType].name
end

--- 获取武将当前使用的兵种 (优先玩家选择, 否则默认)
function M.GetHeroActiveTroop(heroIdx)
    local st = worldMapState
    if st.heroTroopChoice[heroIdx] then
        return st.heroTroopChoice[heroIdx]
    end
    local card = HERO_CARDS[heroIdx]
    if card then return card.troopType end
    return "infantry"
end

-- ============================================================================
-- 武将管理: 拜师学技
-- ============================================================================
function M.LearnSkill(studentIdx, teacherIdx)
    local st = worldMapState
    local student = HERO_CARDS[studentIdx]
    local teacher = HERO_CARDS[teacherIdx]
    if not student or not teacher then return false, "未知武将" end
    if studentIdx == teacherIdx then return false, "不能自学" end

    -- 两人必须在同一城池
    local sameCityId = nil
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd and cd.owner == "player" then
            local hasStudent, hasTeacher = false, false
            for _, h in ipairs(cd.heroes) do
                if h == studentIdx then hasStudent = true end
                if h == teacherIdx then hasTeacher = true end
            end
            if hasStudent and hasTeacher then sameCityId = city.id; break end
        end
    end
    if not sameCityId then return false, "两人不在同一城池" end

    -- 费用: 200金
    if st.gold < 200 then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需200)") end
        return false, "金币不足"
    end

    -- 师父必须有初始武技
    local teacherTech = teacher.initTechnique
    if not teacherTech then return false, "师父无武技可教" end

    -- 学生不能学自己已有的初始武技
    if student.initTechnique == teacherTech then
        return false, "已掌握此武技"
    end

    -- 检查是否已学过同一武技
    local learned = st.heroLearnedSkills[studentIdx]
    if learned and learned.techIdx == teacherTech then
        return false, "已学过此武技"
    end

    st.gold = st.gold - 200

    -- 成功率: 50% + 学生智力 * 0.5%
    local studentStats = student.stats5 or { int = 50 }
    local successRate = 0.50 + studentStats.int * 0.005
    successRate = math.min(0.95, successRate)

    if math.random() < successRate then
        -- 学成: 替换之前学的武技
        st.heroLearnedSkills[studentIdx] = {
            techIdx = teacherTech,
            teacherIdx = teacherIdx,
        }
        local techName = SKILL_TECHNIQUES[teacherTech] and SKILL_TECHNIQUES[teacherTech].name or "武技"
        return true, student.name .. " 拜师 " .. teacher.name .. " 学会 " .. techName .. "!"
    else
        return false, "学艺失败...（成功率" .. math.floor(successRate * 100) .. "%）"
    end
end

-- ============================================================================
-- 出征攻城
-- ============================================================================
function M.StartAttack(fromId, toId)
    local st = worldMapState
    local fromData, toData = st.cityData[fromId], st.cityData[toId]
    if not fromData or not toData then return false end
    if fromData.owner ~= "player" then return false end
    if toData.owner == "player" then return false end
    local deployTroops = st.deployTroops
    if deployTroops < 20 then
        if rawget(_G, "ShowToast") then ShowToast("至少需要20兵力出征") end
        return false
    end
    local connected = false
    for _, connId in ipairs(WORLD_CITIES[fromId].conn) do
        if connId == toId then connected = true; break end
    end
    if not connected then
        if rawget(_G, "ShowToast") then ShowToast("城池不相邻") end
        return false
    end
    local foodCost = math.floor(deployTroops * 0.5)
    if st.food < foodCost then
        if rawget(_G, "ShowToast") then ShowToast("粮草不足(需" .. foodCost .. ")") end
        return false
    end
    st.food = st.food - foodCost
    st.attackContext = {
        fromId = fromId, toId = toId,
        attackTroops = deployTroops,
        defenderFaction = toData.owner,
        deployHeroes = st.deployHeroes or {},
    }
    fromData.garrison = fromData.garrison - deployTroops
    local wallBonus = M.GetBuildingBonus(toId, "wall")
    local defStrength = toData.garrison + toData.level * 20 + #toData.heroes * 15 + wallBonus
    local scale = 0.3 + defStrength / 200
    if rawget(_G, "stageState") then stageState.enemyScale = math.min(2.5, scale) end
    if rawget(_G, "PLAYER_SLOTS") and rawget(_G, "HERO_CARDS") then
        for _, slot in ipairs(PLAYER_SLOTS) do slot.filled = false; slot.card = nil end
        local heroList = st.deployHeroes
        if #heroList == 0 then heroList = fromData.heroes end
        for i, hIdx in ipairs(heroList) do
            if i > #PLAYER_SLOTS then break end
            local card = HERO_CARDS[hIdx]
            if card then
                local slot = PLAYER_SLOTS[i]
                local hero = playerHeroes[hIdx]
                -- 羁绊加成
                local bondBonus = M.GetBondBonus(fromId)
                -- 永久属性加成
                local bAtk = (st.heroBonusAtk and st.heroBonusAtk[hIdx] or 0)
                local bDef = (st.heroBonusDef and st.heroBonusDef[hIdx] or 0)
                local baseAtk = card.atk + bAtk
                local baseDef = card.def + bDef
                local baseHp  = card.hp
                -- 应用羁绊百分比
                local finalAtk = math.floor(baseAtk * (1 + bondBonus.atkMult))
                local finalDef = math.floor(baseDef * (1 + bondBonus.defMult))
                local finalHp  = math.floor(baseHp * (1 + (bondBonus.hpMult or 0)))
                slot.filled = true
                slot.card = {
                    idx = hIdx, name = card.name, quality = card.quality,
                    unitClass = card.unitClass, atk = finalAtk, def = finalDef, hp = finalHp,
                    techIdx = card.techIdx, singleImg = card.singleImg,
                    row = card.row, col = card.col, type = card.type,
                    faction = card.faction, troopType = M.GetHeroActiveTroop(hIdx),
                    level = hero and hero.level or 1,
                    constellation = hero and hero.constellation or 0,
                }
                slot.spawnCount = 0; slot.deployCD = 0
            end
        end
    end
    print("[WorldMap] Attack: " .. WORLD_CITIES[fromId].name .. " -> " .. WORLD_CITIES[toId].name)
    WorldMap.StartMarchAnim(fromId, toId, deployTroops, function()
        if rawget(_G, "InitBattle") then InitBattle() end
        if rawget(_G, "PushPhase") then PushPhase("BATTLE") end
        if rawget(_G, "gameState") then
            gameState.battlePhase = "SHOP"
            gameState.worldMapBattle = true
        end
    end)
    return true
end

-- ============================================================================
-- 战斗结算
-- ============================================================================
function M.OnBattleResult(victory)
    local st = worldMapState
    local ctx = st.attackContext
    if not ctx then return end
    local fromData, toData = st.cityData[ctx.fromId], st.cityData[ctx.toId]
    local tgtCity = WORLD_CITIES[ctx.toId]
    -- 记录参战武将战绩
    local deployed = ctx.deployHeroes or {}
    for _, hIdx in ipairs(deployed) do
        M.RecordHeroBattle(hIdx, victory)
    end
    -- 任务计数: 胜利次数
    if victory then
        st.questCounters = st.questCounters or {}
        st.questCounters.battleWins = (st.questCounters.battleWins or 0) + 1
    end

    if victory then
        -- 记录被俘敌将 (攻城前城中的敌将)
        local capturedHeroes = {}
        for _, hIdx in ipairs(toData.heroes) do
            table.insert(capturedHeroes, hIdx)
        end

        -- 攻击盟友? 撕毁条约并大幅降低好感
        local defFac = ctx.defenderFaction
        if defFac and st.diplomacy[defFac] then
            local dd = st.diplomacy[defFac]
            if dd.treaty and dd.treaty ~= "surrendered" then
                local oldTreaty = TREATY_DEFS[dd.treaty] and TREATY_DEFS[dd.treaty].name or dd.treaty
                dd.treaty = nil
                dd.relation = math.max(0, dd.relation - 30)
                if rawget(_G, "ShowToast") then
                    ShowToast("背盟攻" .. (FACTIONS[defFac] and FACTIONS[defFac].name or defFac)
                        .. "! " .. oldTreaty .. "废除, 好感-30")
                end
            else
                dd.relation = math.max(0, dd.relation - 10)
            end
        end

        toData.owner = "player"
        toData.garrison = math.floor(ctx.attackTroops * 0.5)
        toData.level = math.max(1, toData.level - 1)
        toData.morale = 60
        local moved = ctx.deployHeroes or {}
        for _, hIdx in ipairs(moved) do
            for i, h in ipairs(fromData.heroes) do
                if h == hIdx then table.remove(fromData.heroes, i); break end
            end
        end
        toData.heroes = moved
        if rawget(_G, "AddFloatText") then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "攻占 " .. tgtCity.name .. "!", 2.5, {255, 220, 50}, 24)
        end

        -- 如果有被俘敌将，进入招降阶段
        if #capturedHeroes > 0 then
            st.capturedHeroes = capturedHeroes
            st.capturedCityId = ctx.toId
            st.surrenderResults = {}  -- 每个武将的招降结果
            st.phase = "SURRENDER"
            st.attackContext = nil
            st.deployHeroes = {}
            st.deployTroops = 0
            -- 注意: 不在此处清除 gameState.worldMapBattle
            -- 让 WIN/LOSE 点击处理或 FinishSurrender 来清除
            return
        end
    else
        if rawget(_G, "AddFloatText") then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "攻城失败...", 2.0, {200, 60, 60}, 22)
        end
    end
    st.attackContext = nil
    st.deployHeroes = {}
    st.deployTroops = 0
    -- 注意: 不在此处清除 gameState.worldMapBattle
    -- 让 WIN/LOSE 点击处理来路由回 WORLD_MAP 并清除
end

-- ============================================================================
-- 招降敌将 (攻城后: 招降/杀/放走)
-- ============================================================================

--- 获取武将忠诚度 (默认100)
function M.GetHeroLoyalty(heroIdx)
    local st = worldMapState
    return st.heroLoyalty[heroIdx] or 100
end

--- 尝试招降
function M.TrySurrender(heroIdx, cityId)
    local st = worldMapState
    local card = HERO_CARDS[heroIdx]
    if not card then return false, "未知武将" end

    local loyalty = M.GetHeroLoyalty(heroIdx)
    -- 基础30% + 忠诚度影响(忠诚度越低成功率越高) + 品质修正 + 外交加成
    local baseRate = 0.30
    local loyaltyBonus = (100 - loyalty) * 0.006   -- 忠诚度0时+60%, 忠诚度100时+0%
    local qualityMod = ({[1]=0.15, [2]=0.10, [3]=0.0, [4]=-0.10, [5]=-0.15})
    local qMod = qualityMod[card.quality] or 0
    local diploBonus = 0
    if card.faction and st.diplomacy[card.faction] then
        diploBonus = st.diplomacy[card.faction].relation * 0.002
    end
    local finalRate = math.max(0.05, math.min(0.95, baseRate + loyaltyBonus + qMod + diploBonus))

    if math.random() < finalRate then
        -- 招降成功: 加入玩家武将录 + 驻守攻占城
        if not playerHeroes[heroIdx] or not playerHeroes[heroIdx].owned then
            playerHeroes[heroIdx] = { owned = true, constellation = 0, level = 1 }
        end
        local cd = st.cityData[cityId]
        if cd then table.insert(cd.heroes, heroIdx) end
        st.heroLoyalty[heroIdx] = 100  -- 归降后忠诚度重置
        return true, card.name .. " 归降!"
    else
        -- 招降失败: 标记为失败，等待玩家选择杀或放走
        return false, card.name .. " 拒绝投降! (忠诚:" .. loyalty .. ")"
    end
end

--- 处决俘虏
function M.KillCaptured(heroIdx)
    local card = HERO_CARDS[heroIdx]
    local name = card and card.name or "武将"
    -- 从游戏中移除该武将 (不加入任何城池)
    return true, name .. " 已被处决"
end

--- 放走俘虏 (带20%原兵力去往其他敌城, 忠诚度-20)
function M.ReleaseCaptured(heroIdx, capturedCityId)
    local st = worldMapState
    local card = HERO_CARDS[heroIdx]
    local name = card and card.name or "武将"

    -- 忠诚度下降20
    local oldLoyalty = st.heroLoyalty[heroIdx] or 100
    st.heroLoyalty[heroIdx] = math.max(0, oldLoyalty - 20)

    -- 带走原城20%兵力
    local cd = st.cityData[capturedCityId]
    local troopsToTake = 0
    if cd then
        troopsToTake = math.floor(cd.garrison * 0.2)
        cd.garrison = cd.garrison - troopsToTake
    end

    -- 找一座非玩家城池安置 (优先相连城池)
    local targetCityId = nil
    local city = WORLD_CITIES[capturedCityId]
    if city then
        -- 优先相连的敌城
        for _, connId in ipairs(city.conn or {}) do
            if st.cityData[connId] and st.cityData[connId].owner ~= "player" then
                targetCityId = connId; break
            end
        end
    end
    -- 若相连城池全是玩家的，随机找一座敌城
    if not targetCityId then
        for _, c in ipairs(WORLD_CITIES) do
            if st.cityData[c.id] and st.cityData[c.id].owner ~= "player" then
                targetCityId = c.id; break
            end
        end
    end

    if targetCityId then
        local tcd = st.cityData[targetCityId]
        table.insert(tcd.heroes, heroIdx)
        tcd.garrison = tcd.garrison + troopsToTake
        local tName = WORLD_CITIES[targetCityId] and WORLD_CITIES[targetCityId].name or "?"
        return true, name .. " 带" .. troopsToTake .. "兵去往" .. tName .. " (忠诚:" .. st.heroLoyalty[heroIdx] .. ")"
    else
        -- 全地图都是玩家的城，武将无处可去
        return true, name .. " 已释放 (无城可去)"
    end
end

function M.FinishSurrender()
    local st = worldMapState
    st.capturedHeroes = nil
    st.capturedCityId = nil
    st.surrenderResults = nil
    st.surrenderFailPending = nil  -- 清理失败待决状态
    st.phase = "MAP"
    -- 招降阶段结束后清除战斗标记 (此时已在地图，不再需要)
    if rawget(_G, "gameState") then gameState.worldMapBattle = nil end
end

-- ============================================================================
-- 补兵 (快速补充兵力，比征兵更高效但更贵)
-- ============================================================================
function M.Reinforce(cityId, amount)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd or cd.owner ~= "player" then return false, "非我方城池" end
    -- 补兵费用: 5金/人 + 1粮/人 (比征兵的 3金+1粮/人 更贵，但可自由选数量)
    local goldCost = amount * 5
    local foodCost = amount
    if st.gold < goldCost then return false, "金币不足(需" .. goldCost .. ")" end
    if st.food < foodCost then return false, "粮草不足(需" .. foodCost .. ")" end
    st.gold = st.gold - goldCost
    st.food = st.food - foodCost
    cd.garrison = cd.garrison + amount
    return true, "补兵" .. amount .. "人"
end

-- ============================================================================
-- 内政
-- ============================================================================
function M.Recruit(cityId, amount)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd or cd.owner ~= "player" then return false end
    local goldCost, foodCost = amount * 3, amount * 1
    if st.gold < goldCost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需" .. goldCost .. ")") end
        return false
    end
    if st.food < foodCost then
        if rawget(_G, "ShowToast") then ShowToast("粮草不足") end
        return false
    end
    st.gold = st.gold - goldCost
    st.food = st.food - foodCost
    cd.garrison = cd.garrison + amount
    return true
end

function M.UpgradeCity(cityId)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd or cd.owner ~= "player" then return false end
    if cd.level >= 5 then
        if rawget(_G, "ShowToast") then ShowToast("城防已满级") end
        return false
    end
    local cost = cd.level * 200
    if st.gold < cost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需" .. cost .. ")") end
        return false
    end
    st.gold = st.gold - cost
    cd.level = cd.level + 1
    return true
end

function M.SearchTalent(cityId)
    local st = worldMapState
    local cost = 100
    if st.gold < cost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需100)") end
        return false
    end
    st.gold = st.gold - cost
    local academyBonus = M.GetBuildingBonus(cityId, "academy")  -- 学府加成(百分比)
    if math.random() < (0.2 + academyBonus) and rawget(_G, "HERO_CARDS") then
        local unowned = {}
        for idx, _ in ipairs(HERO_CARDS) do
            if not playerHeroes[idx] then table.insert(unowned, idx) end
        end
        if #unowned > 0 then
            local found = unowned[math.random(#unowned)]
            if not playerHeroes[found] or not playerHeroes[found].owned then
                playerHeroes[found] = { owned = true, constellation = 0, level = 1 }
            end
            table.insert(st.cityData[cityId].heroes, found)
            st.searchResult = { heroIdx = found, cityId = cityId }
            return true
        end
    end
    st.searchResult = nil
    if rawget(_G, "ShowToast") then ShowToast("未发现人才") end
    return false
end

function M.BoostMorale(cityId)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd or cd.owner ~= "player" then return false end
    if st.gold < 80 then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需80)") end
        return false
    end
    st.gold = st.gold - 80
    cd.morale = math.min(100, cd.morale + 15)
    return true
end

-- ============================================================================
-- 外交
-- ============================================================================
function M.SendGift(faction)
    local st = worldMapState
    if st.gold < 200 then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需200)") end
        return false
    end
    st.gold = st.gold - 200
    local d = st.diplomacy[faction]
    if d then
        d.relation = math.min(100, d.relation + 15)
        if rawget(_G, "ShowToast") then ShowToast(FACTIONS[faction].name .. " 好感 +15") end
    end
    return true
end

function M.SignTreaty(faction)
    -- 向下兼容: 直接升级到 peace
    return M.UpgradeTreaty(faction, "peace")
end

--- 升级条约 (peace → trade → alliance)
function M.UpgradeTreaty(faction, targetTreaty)
    local st = worldMapState
    local d = st.diplomacy[faction]
    if not d then return false end
    local td = TREATY_DEFS[targetTreaty]
    if not td then return false end
    local facName = FACTIONS[faction] and FACTIONS[faction].name or faction

    -- 检查前置条约
    if td.reqTreaty and d.treaty ~= td.reqTreaty then
        local preName = TREATY_DEFS[td.reqTreaty] and TREATY_DEFS[td.reqTreaty].name or td.reqTreaty
        if rawget(_G, "ShowToast") then ShowToast("需要先缔结" .. preName) end
        return false
    end
    -- 不能重复缔结同级
    if d.treaty == targetTreaty then
        if rawget(_G, "ShowToast") then ShowToast("已有此协定") end
        return false
    end
    -- 检查好感
    if d.relation < td.reqRelation then
        if rawget(_G, "ShowToast") then ShowToast("好感度不足" .. td.reqRelation) end
        return false
    end
    -- 检查金币
    if st.gold < td.cost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需" .. td.cost .. ")") end
        return false
    end

    st.gold = st.gold - td.cost
    d.treaty = targetTreaty
    if rawget(_G, "ShowToast") then ShowToast("与" .. facName .. "缔结" .. td.name .. "!") end
    return true
end

--- 获取下一可升级的条约类型
function M.GetNextTreaty(faction)
    local st = worldMapState
    local d = st.diplomacy[faction]
    if not d then return nil end
    local current = d.treaty
    for i, key in ipairs(TREATY_UPGRADE_PATH) do
        if current == nil and i == 1 then return key end
        if current == key and i < #TREATY_UPGRADE_PATH then return TREATY_UPGRADE_PATH[i + 1] end
    end
    return nil -- 已达最高
end

--- 劝降整个势力 (势力投降，城池全归玩家)
function M.AttemptSurrender(faction)
    local st = worldMapState
    local d = st.diplomacy[faction]
    if not d then return false end
    local facName = FACTIONS[faction] and FACTIONS[faction].name or faction
    local sd = SURRENDER_DEFS

    -- 检查好感
    if d.relation < sd.reqRelation then
        if rawget(_G, "ShowToast") then ShowToast("好感度不足" .. sd.reqRelation .. ",无法劝降") end
        return false
    end

    -- 统计势力城池数
    local facCityCount = 0
    local facCityIds = {}
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd and cd.owner == faction then
            facCityCount = facCityCount + 1
            table.insert(facCityIds, city.id)
        end
    end
    if facCityCount > sd.reqMaxCities then
        if rawget(_G, "ShowToast") then ShowToast(facName .. "尚有" .. facCityCount .. "城,无法劝降(需≤" .. sd.reqMaxCities .. ")") end
        return false
    end
    if facCityCount == 0 then
        if rawget(_G, "ShowToast") then ShowToast(facName .. "已无城池") end
        return false
    end

    -- 检查金币
    if st.gold < sd.costGold then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需" .. sd.costGold .. ")") end
        return false
    end

    st.gold = st.gold - sd.costGold

    -- 计算成功率
    local chance = sd.successBase + d.relation * sd.relationBonus - facCityCount * sd.cityPenalty
    chance = math.max(0.10, math.min(0.95, chance))

    if math.random() < chance then
        -- 劝降成功: 所有城池归玩家
        for _, cid in ipairs(facCityIds) do
            local cd = st.cityData[cid]
            cd.owner = "player"
            cd.morale = math.max(40, (cd.morale or 80) - 20)  -- 投降后士气降低
        end
        -- 消除外交关系 (已投降)
        d.treaty = "surrendered"
        d.relation = 100
        if rawget(_G, "ShowToast") then ShowToast(facName .. "归顺! 获得" .. facCityCount .. "座城池!") end
        return true
    else
        -- 劝降失败: 好感大幅下降
        d.relation = math.max(0, d.relation - 25)
        d.treaty = nil  -- 撕毁所有条约
        if rawget(_G, "ShowToast") then ShowToast("劝降失败! " .. facName .. "震怒, 好感-25, 条约废除!") end
        return false
    end
end

-- ============================================================================
-- 计略
-- ============================================================================
function M.ExecuteStratagem(stratagemId, targetCityId)
    local st = worldMapState
    local strat = nil
    for _, s in ipairs(STRATAGEMS) do
        if s.id == stratagemId then strat = s; break end
    end
    if not strat then return false end
    local td = st.cityData[targetCityId]
    if not td or td.owner == "player" then return false end
    if st.gold < strat.cost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需" .. strat.cost .. ")") end
        return false
    end
    st.gold = st.gold - strat.cost

    -- 武将数量加成 + 工坊(craft)加成
    local bonusRate = 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" then bonusRate = bonusRate + #cd.heroes * 0.02 end
    end
    local craftBonus = M.GetTotalBuildingBonus("workshop")  -- 工坊加成(百分比)
    -- 羁绊策略加成: 取玩家所有城池中最高stratBonus
    local stratBondBonus = 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd2 = st.cityData[city.id]
        if cd2 and cd2.owner == "player" then
            local bb = M.GetBondBonus(city.id)
            if bb.stratBonus and bb.stratBonus > stratBondBonus then
                stratBondBonus = bb.stratBonus
            end
        end
    end
    local finalRate = math.min(0.95, strat.successRate + bonusRate + craftBonus + stratBondBonus)

    if math.random() < finalRate then
        if stratagemId == "fire" then
            td.garrison = math.max(5, td.garrison - 20)
            if rawget(_G, "ShowToast") then ShowToast("火计成功! 敌军 -20") end
        elseif stratagemId == "spy" then
            td.morale = math.max(20, (td.morale or 80) - 25)
            if rawget(_G, "ShowToast") then ShowToast("离间成功! 士气 -25") end
        elseif stratagemId == "scout" then
            st.scoutResult = {
                cityId = targetCityId,
                garrison = td.garrison,
                level = td.level,
                morale = td.morale or 80,
                heroes = {},
            }
            for _, hi in ipairs(td.heroes) do
                local c = HERO_CARDS[hi]
                if c then table.insert(st.scoutResult.heroes, c.name) end
            end
            if rawget(_G, "ShowToast") then ShowToast("刺探成功! 已获取情报") end
        elseif stratagemId == "counterspy" then
            -- 反间: 破坏敌城所属势力外交关系-15
            local facOwner = td.owner
            if facOwner and st.diplomacy[facOwner] then
                st.diplomacy[facOwner].relation = math.max(0, st.diplomacy[facOwner].relation - 15)
            end
            if rawget(_G, "ShowToast") then ShowToast("反间成功! 外交关系 -15") end
        elseif stratagemId == "ambush" then
            -- 埋伏: 伏击敌军 驻军-30
            td.garrison = math.max(5, td.garrison - 30)
            if rawget(_G, "ShowToast") then ShowToast("埋伏成功! 敌军 -30") end
        elseif stratagemId == "cutoff" then
            -- 断粮: 敌城产出减半一回合 (对玩家城池无效,这里是对敌城)
            -- 但断粮逻辑主要影响收入阶段, 所以标记被断粮的城池
            st.cutoffCities[targetCityId] = true
            if rawget(_G, "ShowToast") then ShowToast("断粮成功! 产出减半一回合") end
        elseif stratagemId == "recruit_t" then
            -- 招贤(策反): 降低敌将忠诚度-30
            if #td.heroes > 0 then
                local targetHero = td.heroes[math.random(#td.heroes)]
                local oldLoy = st.heroLoyalty[targetHero] or 100
                st.heroLoyalty[targetHero] = math.max(0, oldLoy - 30)
                local hName = HERO_CARDS[targetHero] and HERO_CARDS[targetHero].name or "敌将"
                if rawget(_G, "ShowToast") then ShowToast("策反成功! " .. hName .. " 忠诚-30") end
            else
                if rawget(_G, "ShowToast") then ShowToast("策反成功! 但敌城无将可策反") end
            end
        end
        -- 任务计数: 计略成功次数
        st.questCounters = st.questCounters or {}
        st.questCounters.stratSuccess = (st.questCounters.stratSuccess or 0) + 1
        return true
    else
        if rawget(_G, "ShowToast") then ShowToast(strat.name .. " 失败!") end
        return false
    end
end

-- ============================================================================
-- 辅助查询
-- ============================================================================
function M.GetPlayerCityCount()
    local count = 0
    for _, city in ipairs(WORLD_CITIES) do
        if worldMapState.cityData[city.id] and worldMapState.cityData[city.id].owner == "player" then
            count = count + 1
        end
    end
    return count
end

function M.GetCityById(id) return WORLD_CITIES[id] end
function M.GetCityData(id) return worldMapState.cityData[id] end

function M.IsConnected(id1, id2)
    local city = WORLD_CITIES[id1]
    if not city then return false end
    for _, connId in ipairs(city.conn) do
        if connId == id2 then return true end
    end
    return false
end

-- ============================================================================
-- SLG 存档系统
-- ============================================================================
local SLG_SAVE_FILE = "p_49dd_slg_save.json"

function M.SaveSLG()
    local st = worldMapState
    if not st.inited then return false, "未初始化" end

    -- 序列化城池数据 (含建筑)
    local cityDataSave = {}
    for cid, cd in pairs(st.cityData) do
        cityDataSave[tostring(cid)] = {
            owner = cd.owner,
            garrison = cd.garrison,
            level = cd.level,
            heroes = cd.heroes,
            morale = cd.morale,
            buildings = cd.buildings or {},
        }
    end

    -- 序列化兵种选择 (key从number转string)
    local troopChoiceSave = {}
    for k, v in pairs(st.heroTroopChoice or {}) do
        troopChoiceSave[tostring(k)] = v
    end
    -- 序列化已学武技
    local learnedSave = {}
    for k, v in pairs(st.heroLearnedSkills or {}) do
        learnedSave[tostring(k)] = v
    end

    -- 序列化忠诚度 (key从number转string)
    local loyaltySave = {}
    for k, v in pairs(st.heroLoyalty or {}) do
        loyaltySave[tostring(k)] = v
    end

    -- 序列化断粮城池 (key从number转string)
    local cutoffSave = {}
    for cid in pairs(st.cutoffCities or {}) do
        cutoffSave[tostring(cid)] = true
    end

    -- 序列化武将战绩 (v5新增, key从number转string)
    local heroStatsSave = {}
    for k, v in pairs(st.heroStats or {}) do
        heroStatsSave[tostring(k)] = v
    end
    local heroBonusAtkSave = {}
    for k, v in pairs(st.heroBonusAtk or {}) do
        heroBonusAtkSave[tostring(k)] = v
    end
    local heroBonusDefSave = {}
    for k, v in pairs(st.heroBonusDef or {}) do
        heroBonusDefSave[tostring(k)] = v
    end
    -- triggeredEvents/classChanged key已是string, 直接复制
    local triggeredSave = {}
    for k, v in pairs(st.triggeredEvents or {}) do triggeredSave[k] = v end
    local classChangedSave = {}
    for k, v in pairs(st.classChanged or {}) do
        classChangedSave[tostring(k)] = v
    end
    local questCompletedSave = {}
    for k, v in pairs(st.questCompleted or {}) do questCompletedSave[k] = v end

    local saveData = {
        version = 5,
        savedAt = os.time(),
        turn = st.turn,
        totalTurns = st.totalTurns or st.turn,
        gold = st.gold,
        food = st.food,
        troops = st.troops,
        playerFaction = st.playerFaction,
        cityData = cityDataSave,
        diplomacy = st.diplomacy,
        heroTroopChoice = troopChoiceSave,
        heroLearnedSkills = learnedSave,
        heroLoyalty = loyaltySave,
        eventHistory = st.eventHistory or {},
        cutoffCities = cutoffSave,
        -- v5 新增
        heroStats = heroStatsSave,
        heroBonusAtk = heroBonusAtkSave,
        heroBonusDef = heroBonusDefSave,
        triggeredEvents = triggeredSave,
        classChanged = classChangedSave,
        questCompleted = questCompletedSave,
        questCounters = st.questCounters or {},
    }

    local cjson_m = rawget(_G, "cjson")
    if not cjson_m then return false, "cjson不可用" end

    local ok, json = pcall(cjson_m.encode, saveData)
    if not ok then return false, "编码失败" end

    local file = File(SLG_SAVE_FILE, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
        print("[SLG] 本地存档成功 回合:" .. st.turn)
    end

    -- 同步到云端（统一数据出口：本地缓存 + 云端结果同步）
    local CloudMgr = rawget(_G, "CloudManager")
    if CloudMgr and CloudMgr.SaveDomain then
        CloudMgr.SaveDomain("worldmap", function(success)
            if success then
                print("[SLG] 云端同步成功 回合:" .. st.turn)
            else
                print("[SLG] 云端同步失败, 仅本地保存")
            end
        end)
    end

    return true, "存档成功 (回合" .. st.turn .. ")"
end

function M.LoadSLG()
    local st = worldMapState

    -- 优先使用 CloudManager 已加载的云端数据
    -- (CloudManager.LoadAll 在游戏启动时已将 worldmap domain 恢复到 worldMapState)
    if st.inited and st.turn and st.turn > 0 and st.cityData then
        local hasCities = false
        for _ in pairs(st.cityData) do hasCities = true; break end
        if hasCities then
            print("[SLG] 使用云端已加载数据, 回合:" .. st.turn)
            return true, "读档成功 (回合" .. st.turn .. ", 云端)"
        end
    end

    -- 兜底: 从本地文件加载
    if not fileSystem:FileExists(SLG_SAVE_FILE) then
        return false, "无存档"
    end

    local file = File(SLG_SAVE_FILE, FILE_READ)
    if not file:IsOpen() then return false, "读取失败" end
    local content = file:ReadString()
    file:Close()

    local cjson_m = rawget(_G, "cjson")
    if not cjson_m then return false, "cjson不可用" end

    local ok, data = pcall(cjson_m.decode, content)
    if not ok or not data then return false, "解码失败" end
    if not data.cityData then return false, "存档数据不完整" end

    st.turn = data.turn or 1
    st.totalTurns = data.totalTurns or st.turn
    st.gold = data.gold or 500
    st.food = data.food or 300
    st.troops = data.troops or 200
    st.playerFaction = data.playerFaction or "wu"

    -- 恢复城池数据 (key 从 string 转回 number, 含建筑 v4)
    st.cityData = {}
    for cidStr, cd in pairs(data.cityData) do
        local cid = tonumber(cidStr)
        if cid then
            st.cityData[cid] = {
                owner = cd.owner or "qun",
                garrison = cd.garrison or 30,
                level = cd.level or 1,
                heroes = cd.heroes or {},
                morale = cd.morale or 80,
                buildings = cd.buildings or {},
            }
        end
    end

    -- 恢复外交
    st.diplomacy = data.diplomacy or {
        shu = { relation = 30, treaty = nil },
        wei = { relation = 20, treaty = nil },
        qun = { relation = 40, treaty = nil },
    }

    -- 恢复兵种选择 (key从string转回number)
    st.heroTroopChoice = {}
    if data.heroTroopChoice then
        for k, v in pairs(data.heroTroopChoice) do
            local idx = tonumber(k)
            if idx then st.heroTroopChoice[idx] = v end
        end
    end

    -- 恢复已学武技
    st.heroLearnedSkills = {}
    if data.heroLearnedSkills then
        for k, v in pairs(data.heroLearnedSkills) do
            local idx = tonumber(k)
            if idx then st.heroLearnedSkills[idx] = v end
        end
    end

    -- 恢复忠诚度 (v3新增)
    st.heroLoyalty = {}
    if data.heroLoyalty then
        for k, v in pairs(data.heroLoyalty) do
            local idx = tonumber(k)
            if idx then st.heroLoyalty[idx] = v end
        end
    end

    -- 恢复事件历史 (v3新增)
    st.eventHistory = data.eventHistory or {}

    -- 恢复断粮城池 (v4新增, key从string转回number)
    st.cutoffCities = {}
    if data.cutoffCities then
        for cidStr, v in pairs(data.cutoffCities) do
            local cid = tonumber(cidStr)
            if cid and v then st.cutoffCities[cid] = true end
        end
    end

    -- 恢复武将战绩 (v5新增, key从string转回number)
    st.heroStats = {}
    if data.heroStats then
        for k, v in pairs(data.heroStats) do
            local idx = tonumber(k)
            if idx then st.heroStats[idx] = v end
        end
    end
    st.heroBonusAtk = {}
    if data.heroBonusAtk then
        for k, v in pairs(data.heroBonusAtk) do
            local idx = tonumber(k)
            if idx then st.heroBonusAtk[idx] = v end
        end
    end
    st.heroBonusDef = {}
    if data.heroBonusDef then
        for k, v in pairs(data.heroBonusDef) do
            local idx = tonumber(k)
            if idx then st.heroBonusDef[idx] = v end
        end
    end
    st.triggeredEvents = data.triggeredEvents or {}
    st.classChanged = {}
    if data.classChanged then
        for k, v in pairs(data.classChanged) do
            local idx = tonumber(k)
            if idx then st.classChanged[idx] = v end
        end
    end
    st.questCompleted = data.questCompleted or {}
    st.questCounters = data.questCounters or {}

    st.phase = "MAP"
    st.selectedCity = nil
    st.turnReport = nil
    st.searchResult = nil
    st.scoutResult = nil
    st.inited = true

    print("[SLG] 本地读档成功 回合:" .. st.turn)
    return true, "读档成功 (回合" .. st.turn .. ", 本地)"
end

function M.HasSave()
    return fileSystem:FileExists(SLG_SAVE_FILE)
end

function M.DeleteSave()
    if fileSystem:FileExists(SLG_SAVE_FILE) then
        fileSystem:Delete(SLG_SAVE_FILE)
        return true
    end
    return false
end

return M
