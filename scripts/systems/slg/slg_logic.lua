-- ============================================================================
-- slg/slg_logic.lua - 三国武灵传：SLG核心逻辑
-- 初始化、回合处理、玩家行动、AI行动、计略
-- ============================================================================

---@diagnostic disable: undefined-global

local Data = require("systems.slg.slg_data")
local State = require("systems.slg.slg_state")

local STRATAGEMS = Data.STRATAGEMS

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
-- 回合处理
-- ============================================================================
function M.EndTurn()
    local report = {}
    local st = worldMapState

    -- 1) 收入
    local income, foodIncome, playerCityCount = 0, 0, 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" then
            local prod = city.prod + (cd.level - 1) * 10
            income = income + prod
            foodIncome = foodIncome + math.floor(prod * 0.5)
            playerCityCount = playerCityCount + 1
            cd.morale = math.min(100, cd.morale + 3)
        end
    end
    st.gold = st.gold + income
    st.food = st.food + foodIncome
    table.insert(report, {type="income", text="税收 +" .. income .. "金  粮草 +" .. foodIncome})

    -- 2) 自动补兵
    local recruitFood = playerCityCount * 10
    if st.food >= recruitFood then
        st.food = st.food - recruitFood
        for _, city in ipairs(WORLD_CITIES) do
            local cd = st.cityData[city.id]
            if cd.owner == "player" then cd.garrison = cd.garrison + 5 end
        end
        table.insert(report, {type="recruit", text="征兵: 各城 +5 (粮 -" .. recruitFood .. ")"})
    else
        table.insert(report, {type="warning", text="粮草不足! 无法自动征兵"})
        for _, city in ipairs(WORLD_CITIES) do
            local cd = st.cityData[city.id]
            if cd.owner == "player" then cd.morale = math.max(30, cd.morale - 5) end
        end
    end

    -- 3) AI 行动
    local aiFactions = {"wei", "shu", "qun"}
    for _, fac in ipairs(aiFactions) do
        local facCities = {}
        for _, city in ipairs(WORLD_CITIES) do
            if st.cityData[city.id].owner == fac then
                table.insert(facCities, city)
                st.cityData[city.id].garrison = st.cityData[city.id].garrison + 3
            end
        end
        local aggression = 0.2 + (#facCities / #WORLD_CITIES) * 0.3
        local diplo = st.diplomacy[fac]
        if diplo and diplo.treaty == "peace" then aggression = aggression * 0.1 end

        if #facCities > 0 and math.random() < aggression then
            local srcCity = facCities[math.random(#facCities)]
            local srcData = st.cityData[srcCity.id]
            if srcData.garrison >= 30 then
                local targets = {}
                for _, connId in ipairs(srcCity.conn) do
                    local tgtOwner = st.cityData[connId].owner
                    if tgtOwner ~= fac then
                        if not (tgtOwner == "player" and diplo and diplo.treaty == "peace") then
                            table.insert(targets, connId)
                        end
                    end
                end
                if #targets > 0 then
                    local tgtId = targets[math.random(#targets)]
                    local tgtData = st.cityData[tgtId]
                    local tgtCity = WORLD_CITIES[tgtId]
                    local atkPower = srcData.garrison * 0.6 + #srcData.heroes * 15
                    local defPower = tgtData.garrison + tgtData.level * 10 + #tgtData.heroes * 10
                    local facName = FACTIONS[fac] and FACTIONS[fac].name or fac

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
                            table.insert(report, {type="lost", text="失守! " .. facName .. " 攻占 " .. tgtCity.name})
                        else
                            table.insert(report, {type="battle", text=facName .. " 攻占 " .. tgtCity.name})
                        end
                    else
                        srcData.garrison = math.floor(srcData.garrison * 0.7)
                        tgtData.garrison = math.max(5, tgtData.garrison - math.floor(atkPower * 0.3))
                        table.insert(report, {type="battle", text=facName .. " 攻 " .. tgtCity.name .. " 败退"})
                    end
                end
            end
        end
    end

    -- 4) 外交衰减
    for fac, d in pairs(st.diplomacy) do
        d.relation = math.max(0, d.relation - 2)
        if d.treaty == "peace" and d.relation < 15 then
            d.treaty = nil
            table.insert(report, {type="diplomacy", text=FACTIONS[fac].name .. " 撕毁和约!"})
        end
    end

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
    local defStrength = toData.garrison + toData.level * 20 + #toData.heroes * 15
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
                slot.filled = true
                slot.card = {
                    idx = hIdx, name = card.name, quality = card.quality,
                    unitClass = card.unitClass, atk = card.atk, def = card.def, hp = card.hp,
                    skill = card.skill, skillData = card.skillData, singleImg = card.singleImg,
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
    if victory then
        -- 记录被俘敌将 (攻城前城中的敌将)
        local capturedHeroes = {}
        for _, hIdx in ipairs(toData.heroes) do
            table.insert(capturedHeroes, hIdx)
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
            if rawget(_G, "gameState") then gameState.worldMapBattle = nil end
            return  -- 不在此处清理，等招降阶段结束
        end
    else
        if rawget(_G, "AddFloatText") then
            AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "攻城失败...", 2.0, {200, 60, 60}, 22)
        end
    end
    st.attackContext = nil
    st.deployHeroes = {}
    st.deployTroops = 0
    if rawget(_G, "gameState") then gameState.worldMapBattle = nil end
end

-- ============================================================================
-- 招降敌将
-- ============================================================================
function M.TrySurrender(heroIdx, cityId)
    local st = worldMapState
    -- 招降成功率: 基础50% + 外交加成 + 武将品质影响
    local card = HERO_CARDS[heroIdx]
    if not card then return false, "未知武将" end

    local baseRate = 0.50
    -- 低品质更容易招降
    local qualityMod = ({[1]=0.15, [2]=0.10, [3]=0.0, [4]=-0.10, [5]=-0.20})
    local qMod = qualityMod[card.quality] or 0
    -- 外交关系加成
    local diploBonus = 0
    if card.faction and st.diplomacy[card.faction] then
        diploBonus = st.diplomacy[card.faction].relation * 0.002  -- 最多+0.2
    end
    local finalRate = math.min(0.90, baseRate + qMod + diploBonus)

    if math.random() < finalRate then
        -- 招降成功: 加入玩家武将录
        if not playerHeroes[heroIdx] or not playerHeroes[heroIdx].owned then
            playerHeroes[heroIdx] = { owned = true, constellation = 0, level = 1 }
        end
        local cd = st.cityData[cityId]
        if cd then table.insert(cd.heroes, heroIdx) end
        return true, card.name .. " 归降!"
    else
        return false, card.name .. " 宁死不降!"
    end
end

function M.FinishSurrender()
    local st = worldMapState
    st.capturedHeroes = nil
    st.capturedCityId = nil
    st.surrenderResults = nil
    st.phase = "MAP"
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
    if math.random() < 0.2 and rawget(_G, "HERO_CARDS") then
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
    local st = worldMapState
    local d = st.diplomacy[faction]
    if not d then return false end
    if d.relation < 60 then
        if rawget(_G, "ShowToast") then ShowToast("好感度不足60, 无法缔约") end
        return false
    end
    if st.gold < 500 then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需500)") end
        return false
    end
    st.gold = st.gold - 500
    d.treaty = "peace"
    if rawget(_G, "ShowToast") then ShowToast("与" .. FACTIONS[faction].name .. "缔结和约!") end
    return true
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

    local bonusRate = 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" then bonusRate = bonusRate + #cd.heroes * 0.02 end
    end
    local finalRate = math.min(0.95, strat.successRate + bonusRate)

    if math.random() < finalRate then
        if stratagemId == "fire" then
            td.garrison = math.max(5, td.garrison - 20)
            if rawget(_G, "ShowToast") then ShowToast("火计成功! 敌军 -20") end
        elseif stratagemId == "spy" then
            td.morale = math.max(20, (td.morale or 80) - 25)
            if rawget(_G, "ShowToast") then ShowToast("离间成功! 士气 -25") end
        elseif stratagemId == "defect" then
            if #td.heroes > 0 then
                local hi = td.heroes[math.random(#td.heroes)]
                local bestPCity = nil
                for _, c2 in ipairs(WORLD_CITIES) do
                    if st.cityData[c2.id].owner == "player" then bestPCity = c2.id; break end
                end
                if bestPCity then
                    for i, h in ipairs(td.heroes) do
                        if h == hi then table.remove(td.heroes, i); break end
                    end
                    table.insert(st.cityData[bestPCity].heroes, hi)
                    if not playerHeroes[hi] or not playerHeroes[hi].owned then
                        playerHeroes[hi] = { owned = true, constellation = 0, level = 1 }
                    end
                    local hName = HERO_CARDS[hi] and HERO_CARDS[hi].name or "武将"
                    if rawget(_G, "ShowToast") then ShowToast("招降成功! " .. hName .. " 归降") end
                end
            else
                if rawget(_G, "ShowToast") then ShowToast("招降成功但无将可降") end
            end
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
        end
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

    -- 序列化城池数据
    local cityDataSave = {}
    for cid, cd in pairs(st.cityData) do
        cityDataSave[tostring(cid)] = {
            owner = cd.owner,
            garrison = cd.garrison,
            level = cd.level,
            heroes = cd.heroes,
            morale = cd.morale,
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

    local saveData = {
        version = 2,
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

    -- 恢复城池数据 (key 从 string 转回 number)
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
