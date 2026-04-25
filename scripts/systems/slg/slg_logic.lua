-- ============================================================================
-- slg/slg_logic.lua - 三国武灵传：SLG核心逻辑
-- 初始化、回合处理、玩家行动、AI行动、计略
-- ============================================================================

---@diagnostic disable: undefined-global

local Data = require("systems.slg.slg_data")
local State = require("systems.slg.slg_state")
local Campaigns = require("systems.slg.slg_campaigns")

local STRATAGEMS = Data.STRATAGEMS

local M = {}

-- ============================================================================
-- 阵营名称查找 (避免战报出现英文 key)
-- ============================================================================
-- 非标准阵营的中文名映射 (战役中出现但不在全局 FACTIONS 中的)
local FACTION_NAME_FALLBACK = {
    yellow_turban  = "黄巾军",
    dong_zhuo_army = "董卓军",
    dong_zhuo      = "董卓",
    coalition      = "联军",
    xiliang        = "西凉军",
    cao_cao        = "曹操",
    yuan_shao      = "袁绍",
    liu_bei        = "刘备",
    sun_ce         = "孙策",
    sun_quan       = "孙权",
    sun_liu        = "孙刘联军",
    yi_zhou        = "益州",
    south          = "南方",
    others         = "群雄",
    neutral        = "中立",
    player         = "我方",
}

--- 安全获取阵营中文名, 绝不返回英文 key (全局可用)
---@param fac string|nil
---@return string
function GetFacName(fac)
    if not fac then return "未知" end
    if fac == "player" then return "我方" end
    if FACTIONS and FACTIONS[fac] then return FACTIONS[fac].name end
    if FACTION_NAME_FALLBACK[fac] then return FACTION_NAME_FALLBACK[fac] end
    -- 最后尝试从当前战役的 factions 列表中查找
    local st = rawget(_G, "worldMapState")
    if st and st._campaignFactions then
        for _, f in ipairs(st._campaignFactions) do
            if f.id == fac then return f.name end
        end
    end
    return "势力"
end

-- ============================================================================
-- 行动点系统
-- ============================================================================
-- 各操作消耗的行动点
local AP_COST = {
    recruit   = 1,  -- 征兵
    reinforce = 1,  -- 补兵
    upgrade   = 1,  -- 升级城防
    search    = 1,  -- 搜索人才
    morale    = 1,  -- 犒赏三军
    diplomacy = 1,  -- 外交(赠礼/缔约)
    stratagem = 1,  -- 计略
    move      = 1,  -- 调兵
    attack    = 2,  -- 出征(消耗2点)
}

--- 检查行动点是否足够
function M.CanAct(actionKey)
    local cost = AP_COST[actionKey] or 1
    return (worldMapState.actionPoints or 0) >= cost
end

--- 消耗行动点, 返回是否成功
function M.SpendAP(actionKey)
    local cost = AP_COST[actionKey] or 1
    local st = worldMapState
    if (st.actionPoints or 0) < cost then
        if rawget(_G, "ShowToast") then ShowToast("行动点不足! (需" .. cost .. "点)") end
        return false
    end
    st.actionPoints = st.actionPoints - cost
    return true
end

--- 获取操作所需行动点
function M.GetAPCost(actionKey)
    return AP_COST[actionKey] or 1
end

-- ============================================================================
-- 武将战力计算
-- ============================================================================

--- 兵种克制表: attacker -> defender -> 倍率
local TROOP_ADVANTAGE = {
    cavalry  = { archer = 1.2,  spear = 0.85 },
    archer   = { spear = 1.2,   cavalry = 0.85 },
    spear    = { cavalry = 1.2, archer = 0.85 },
    infantry = {},  -- 步兵中性
}

--- 计算单个武将的战力值 (基于 stats5)
--- @param heroIdx number 武将索引
--- @return number power 战力值 (0-100)
function M.CalcHeroPower(heroIdx)
    local card = HERO_CARDS and HERO_CARDS[heroIdx]
    if not card then return 0 end
    local s5 = card.stats5 or { str = 50, int = 50, vit = 50, tec = 50, spd = 50 }
    return s5.str * 0.40 + s5.int * 0.15 + s5.vit * 0.20 + s5.tec * 0.15 + s5.spd * 0.10
end

--- 计算一组武将的总战力
--- @param heroList table 武将索引列表
--- @return number totalPower
function M.CalcSquadPower(heroList)
    local total = 0
    for _, hIdx in ipairs(heroList) do
        total = total + M.CalcHeroPower(hIdx)
    end
    return total
end

-- ============================================================================
-- 战力指数 (出征界面用, 基于武将战斗属性+品阶+城池等级)
-- ============================================================================
-- 品阶战力系数 (品质越高, 战力越高)
local QUALITY_POWER_MULT = {
    [1] = 1.0,    -- N
    [2] = 1.2,    -- R
    [3] = 1.5,    -- SR
    [4] = 2.0,    -- SSR
    [5] = 2.2,    -- 限定SSR
}

--- 计算单个武将的战力指数 (基于 atk/def/hp + 品阶 + 命座)
--- @param heroIdx number 武将索引
--- @return number powerIndex
function M.CalcHeroCombatPower(heroIdx)
    local card = HERO_CARDS and HERO_CARDS[heroIdx]
    if not card then return 0 end
    -- 基础战力: atk权重最高, hp次之, def最低
    local basePower = (card.atk or 0) * 1.0 + (card.hp or 0) * 0.05 + (card.def or 0) * 0.5
    -- 品阶加成
    local qMult = QUALITY_POWER_MULT[card.quality or 1] or 1.0
    -- 命座加成
    local consMult = 1.0
    local hero = rawget(_G, "playerHeroes") and playerHeroes[heroIdx]
    if hero and hero.constellation and hero.constellation > 0 then
        consMult = 1.0 + hero.constellation * 0.08  -- 每命座+8%
    end
    return math.floor(basePower * qMult * consMult)
end

--- 计算一方的战力指数 (武将组 + 城池等级)
--- @param heroList table 武将索引列表
--- @param cityLevel number 城池等级 (1-5)
--- @return number powerIndex
function M.CalcSideCombatPower(heroList, cityLevel)
    local total = 0
    for _, hIdx in ipairs(heroList) do
        total = total + M.CalcHeroCombatPower(hIdx)
    end
    -- 城池等级加成: 每级+3%
    local lvMult = 1.0 + ((cityLevel or 1) - 1) * 0.03
    return math.floor(total * lvMult)
end

-- ============================================================================
-- 领兵上限系统
-- ============================================================================
-- 基础领兵上限按品质分级 (每位武将可独立带兵)
local TROOP_CAP_BASE = {
    [1] = 1500,   -- N  人武灵
    [2] = 2500,   -- R  地武灵
    [3] = 4000,   -- SR 天武灵
    [4] = 6000,   -- SSR 神武灵
    [5] = 8000,   -- 限定SSR
}

--- 计算单个武将的领兵上限
--- @param heroIdx number 武将索引
--- @return number cap 领兵上限
function M.CalcTroopCap(heroIdx)
    local card = HERO_CARDS and HERO_CARDS[heroIdx]
    if not card then return 5000 end
    local base = TROOP_CAP_BASE[card.quality or 1] or 5000
    -- 等级加成: 每级+200
    local hero = rawget(_G, "playerHeroes") and playerHeroes[heroIdx]
    local level = (hero and hero.level) or 1
    -- 统率(vit)加成: 每点统率+15
    local s5 = card.stats5 or { vit = 50 }
    return math.floor(base + (level - 1) * 200 + s5.vit * 15)
end

--- 计算城池所有武将的总领兵上限
--- @param cityId number 城池ID
--- @return number totalCap 总领兵上限
function M.CalcCityTroopCap(cityId)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd then return 0 end
    local heroes = cd.heroes or {}
    if #heroes == 0 then return 0 end
    local total = 0
    for _, hIdx in ipairs(heroes) do
        total = total + M.CalcTroopCap(hIdx)
    end
    return total
end

--- 计算城池人口驻军上限 (一成青壮可从军)
--- @param cityId number 城池ID
--- @return number popCap 人口驻军上限
function M.CalcCityPopCap(cityId)
    local city = WORLD_CITIES[cityId]
    if not city then return 0 end
    return math.floor((city.pop or 5000) * 2)
end

--- 计算兵种克制修正 (进攻方武将 vs 防守方武将)
--- @param atkHeroes table 进攻方武将列表
--- @param defHeroes table 防守方武将列表
--- @return number modifier 克制修正 (1.0 = 无克制)
function M.CalcTroopAdvantage(atkHeroes, defHeroes)
    if #atkHeroes == 0 or #defHeroes == 0 then return 1.0 end
    local st = worldMapState
    local totalMod = 0
    local count = 0
    for _, aIdx in ipairs(atkHeroes) do
        local aTroop = M.GetHeroActiveTroop(aIdx)
        for _, dIdx in ipairs(defHeroes) do
            local dTroop = M.GetHeroActiveTroop(dIdx)
            local advTable = TROOP_ADVANTAGE[aTroop]
            local mod = advTable and advTable[dTroop] or 1.0
            totalMod = totalMod + mod
            count = count + 1
        end
    end
    return count > 0 and (totalMod / count) or 1.0
end

--- 计算士气攻击修正 (使用MORALE_MULTIPLIER_TABLE分段表)
--- @param morale number 士气值 (0-100)
--- @return number modifier (0.70 ~ 1.25)
function M.CalcMoraleMod(morale)
    morale = morale or 50
    if rawget(_G, "MORALE_MULTIPLIER_TABLE") then
        for _, row in ipairs(MORALE_MULTIPLIER_TABLE) do
            if morale >= row.min and morale <= row.max then
                return row.atkMult
            end
        end
    end
    return 1.0
end

--- 计算士气防御修正
--- @param morale number 士气值 (0-100)
--- @return number modifier (0.80 ~ 1.20)
function M.CalcMoraleDefMod(morale)
    morale = morale or 50
    if rawget(_G, "MORALE_MULTIPLIER_TABLE") then
        for _, row in ipairs(MORALE_MULTIPLIER_TABLE) do
            if morale >= row.min and morale <= row.max then
                return row.defMult
            end
        end
    end
    return 1.0
end

--- 计算城防等级防御加成 (守城方额外乘数)
--- Lv1=x1.0, Lv2=x1.10, Lv3=x1.20, Lv4=x1.30, Lv5=x1.40
--- @param level number 城防等级 (1-5)
--- @return number modifier
function M.CalcDefLevelMod(level)
    return 1.0 + ((level or 1) - 1) * 0.10
end

--- 计算城池综合战力 (驻军 + 武将 + 城防 + 士气)
--- @param cityId number
--- @return number power
function M.CalcCityPower(cityId)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd then return 0 end
    local garrison = cd.garrison or 0
    local heroPower = M.CalcSquadPower(cd.heroes or {})
    local levelBonus = (cd.level or 1) * 20
    local moraleMod = M.CalcMoraleMod(cd.morale)
    return (garrison * 0.5 + heroPower + levelBonus) * moraleMod
end

-- ============================================================================
-- 初始化
-- ============================================================================
function M.Init()
    local st = worldMapState
    if st.inited then
        State.ResetView()
        return
    end
    -- 进入剧本选择界面
    M.EnterCampaignSelect()
end

--- 重新开始一局（进入剧本选择）
function M.NewGame()
    local st = worldMapState
    st.inited = false
    st.conquestRewardGiven = nil
    M.EnterCampaignSelect()
end

--- 进入剧本选择阶段
function M.EnterCampaignSelect()
    local st = worldMapState
    st.phase = "CAMPAIGN_SELECT"
    st.inited = true  -- 标记已初始化，避免重复进入
    st.campaignList = Campaigns.GetCampaignList()
    st.campaignScroll = 0
    st.selectedCampaignId = nil
    st.selectedCampaignFaction = nil
    -- 已完成的剧本 (从 clientCloud 加载或本地状态)
    if not st.completedCampaigns then
        st.completedCampaigns = {}
    end
end

--- 选择剧本后进入阵营选择
function M.SelectCampaign(campaignId)
    local st = worldMapState
    if not Campaigns.IsCampaignUnlocked(campaignId, st.completedCampaigns or {}) then
        if rawget(_G, "ShowToast") then ShowToast("需要先通关前置剧本") end
        return
    end
    st.selectedCampaignId = campaignId
    st.phase = "FACTION_SELECT"
    st.factionList = Campaigns.GetPlayableFactions(campaignId)
    st.selectedCampaignFaction = nil
end

--- 选择阵营后开始剧本游戏
function M.StartCampaign(campaignId, factionId)
    local ok, err = Campaigns.ApplyCampaign(campaignId, factionId)
    if not ok then
        if rawget(_G, "ShowToast") then ShowToast(err or "初始化失败") end
        return
    end
    if rawget(_G, "ShowToast") then
        local c = Campaigns.GetCampaign(campaignId)
        ShowToast(c and (c.name .. " 开始!") or "新的征程开始!")
    end
    -- 新游戏自动触发新手引导
    local Input = require("systems.slg.slg_input")
    Input.StartGuide()
end

--- 回到经典随机模式（保留向后兼容）
function M.StartClassicMode()
    M.SetupNewGame()
    if rawget(_G, "ShowToast") then ShowToast("经典模式 开始!") end
    -- 新游戏自动触发新手引导
    local Input = require("systems.slg.slg_input")
    Input.StartGuide()
end

--- 核心初始化逻辑（随机选择一座城作为玩家起点）
function M.SetupNewGame()
    local st = worldMapState

    st.turn = 1
    st.gold = 50000
    st.food = 30000
    st.troops = 20000
    st.actionPoints = 6
    st.maxActionPoints = 6
    st.phase = "MAP"
    st.selectedCity = nil
    st.targetCity = nil
    st.turnReport = nil
    st.scrollY = 0
    st.cityData = {}
    st.searchResult = nil
    st.scoutResult = nil
    st.cloudOffset = 0
    st.deployHeroes = {}
    st.deployTroops = 0
    st.heroTroopChoice = {}
    st.heroLearnedSkills = {}
    st.capturedHeroes = nil
    st.surrenderResults = nil
    st.surrenderCurrentIdx = nil
    st.attackContext = nil
    -- 出征前选择
    st.selectedFormation = "fish_scale"
    st.selectedTactic    = nil
    st.formationBtns     = {}
    st.tacticBtns        = {}
    st.lastBattleReward  = nil

    -- 随机选一座城作为玩家起点
    local startIdx = math.random(1, #WORLD_CITIES)
    local startCity = WORLD_CITIES[startIdx]
    st.startCityId = startCity.id
    -- 玩家阵营设为起点城市的原阵营（用于阵营色等）
    st.playerFaction = startCity.faction

    -- 外交: 排除玩家自身阵营，其余阵营都参与
    st.diplomacy = {}
    local allFacs = {"shu", "wei", "wu", "qun"}
    local defaultRelation = { shu = 30, wei = 20, wu = 25, qun = 40 }
    for _, fac in ipairs(allFacs) do
        if fac ~= startCity.faction then
            st.diplomacy[fac] = { relation = defaultRelation[fac] or 25, treaty = nil }
        end
    end

    for _, city in ipairs(WORLD_CITIES) do
        local owner = city.faction
        if city.id == startCity.id then
            owner = "player"
        end
        st.cityData[city.id] = {
            owner = owner,
            garrison = (owner == "player") and 3000 or (1500 + city.def * 500),
            level = (owner == "player") and math.max(city.def, 2) or city.def,
            heroes = {},
            morale = (owner == "player") and 90 or 80,
        }
    end

    local playerCities = { startCity.id }

    -- 分配玩家已拥有的所有武将到起始城
    local heroIdx2 = 0
    if rawget(_G, "HERO_CARDS") then
        for idx = 1, #HERO_CARDS do
            if playerHeroes[idx] and playerHeroes[idx].owned then
                heroIdx2 = heroIdx2 + 1
                table.insert(st.cityData[startCity.id].heroes, idx)
            end
        end
    end

    -- AI 阵营分配武将
    local aiFactions = {"wei", "shu", "wu", "qun"}
    for _, fac in ipairs(aiFactions) do
        local aiHeroes = {}
        for idx, card in ipairs(HERO_CARDS) do
            if card.faction == fac and not (playerHeroes[idx] and playerHeroes[idx].owned) then
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
    print("[WorldMap] New game! Start city: " .. startCity.name .. " (" .. startCity.faction .. ")")
end

-- ============================================================================
-- 回合处理
-- ============================================================================
function M.EndTurn()
    local report = {}
    local battleAnims = {}
    local st = worldMapState

    -- 回合播报
    st.turn = (st.turn or 0) + 1
    local AnimTA = require("ui.anim")
    local turnSubs = {"群雄逐鹿", "天下纷争", "烽烟四起", "诸侯割据", "风云变幻"}
    local subIdx = ((st.turn - 1) % #turnSubs) + 1
    AnimTA.StartTurnAnnounce("第" .. st.turn .. "回合", turnSubs[subIdx], gameState.gameTime or 0)

    -- 1) 收入 (基于人口 + 城防等级加成)
    local income, foodIncome, playerCityCount = 0, 0, 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" then
            local popIncome = (city.pop or 5000) + (cd.level - 1) * 1000
            income = income + popIncome
            foodIncome = foodIncome + math.floor(popIncome * 0.5)
            playerCityCount = playerCityCount + 1
            cd.morale = math.min(100, cd.morale + 3)
        end
    end
    st.gold = st.gold + income
    st.food = st.food + foodIncome
    table.insert(report, {type="income", text="税收 +" .. income .. "金  粮草 +" .. foodIncome .. "  (城x" .. playerCityCount .. ")"})
    -- 资源飘字
    local AnimRes = require("ui.anim")
    local nowT = gameState.gameTime or 0
    AnimRes.AddFloatNumber("+" .. income .. " 金", 120, 30, 255, 220, 80, nowT)
    AnimRes.AddFloatNumber("+" .. foodIncome .. " 粮", 240, 30, 160, 230, 140, nowT + 0.15)

    -- 2) 自动补兵 (每城补兵量受人口限制: pop/15, 每兵消耗2粮, 不超过人口驻军上限)
    local totalAutoRecruit, totalAutoFood = 0, 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" then
            local popCap = M.CalcCityPopCap(city.id)
            local curGarrison = cd.garrison or 0
            local roomLeft = math.max(0, popCap - curGarrison)
            local maxAuto = math.max(1, math.floor((city.pop or 5000) / 5))
            maxAuto = math.min(maxAuto, roomLeft)
            if maxAuto > 0 then
                local foodNeeded = maxAuto * 2
                if st.food >= foodNeeded then
                    cd.garrison = cd.garrison + maxAuto
                    st.food = st.food - foodNeeded
                    totalAutoRecruit = totalAutoRecruit + maxAuto
                    totalAutoFood = totalAutoFood + foodNeeded
                end
            end
        end
    end
    if totalAutoRecruit > 0 then
        table.insert(report, {type="recruit", text="自动补兵: 共+" .. FormatTroops(totalAutoRecruit) .. " (粮-" .. totalAutoFood .. ")"})
    else
        table.insert(report, {type="warning", text="粮草不足! 无法自动补兵"})
        for _, city in ipairs(WORLD_CITIES) do
            local cd = st.cityData[city.id]
            if cd.owner == "player" then cd.morale = math.max(30, cd.morale - 5) end
        end
    end

    -- 2.5) 低士气惩罚: 士气<30的城池有兵力逃散
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" and (cd.morale or 50) < 30 then
            local desert = math.floor((cd.garrison or 0) * 0.05)
            if desert > 0 then
                cd.garrison = math.max(0, cd.garrison - desert)
                table.insert(report, {type="warning", text=city.name .. " 士气过低! " .. FormatTroops(desert) .. "人逃散"})
            end
        end
    end

    -- 3) AI 行动 (动态收集所有非玩家阵营)
    local aiFactionSet = {}
    for _, city in ipairs(WORLD_CITIES) do
        local o = st.cityData[city.id] and st.cityData[city.id].owner
        if o and o ~= "player" and o ~= "neutral" then
            aiFactionSet[o] = true
        end
    end
    local aiFactions = {}
    for fac in pairs(aiFactionSet) do table.insert(aiFactions, fac) end
    for _, fac in ipairs(aiFactions) do
        local facCities = {}
        for _, city in ipairs(WORLD_CITIES) do
            if st.cityData[city.id].owner == fac then
                table.insert(facCities, city)
                st.cityData[city.id].garrison = st.cityData[city.id].garrison + 500
            end
        end
        local aggression = 0.2 + (#facCities / #WORLD_CITIES) * 0.3
        local diplo = st.diplomacy[fac]
        if diplo and diplo.treaty == "peace" then aggression = aggression * 0.1 end

        if #facCities > 0 and math.random() < aggression then
            -- 智能选择出击城池：优先选兵力最多的城池作为进攻方
            local bestSrc, bestGarrison = nil, 0
            for _, city in ipairs(facCities) do
                local g = st.cityData[city.id].garrison
                if g >= 3000 and g > bestGarrison then
                    bestGarrison = g
                    bestSrc = city
                end
            end
            local srcCity = bestSrc
            if srcCity then
                local srcData = st.cityData[srcCity.id]
                -- 智能目标排序：玩家城池优先，再按守军最少排序
                local targets = {}
                for _, connId in ipairs(srcCity.conn) do
                    local tgtOwner = st.cityData[connId].owner
                    if tgtOwner ~= fac then
                        if not (tgtOwner == "player" and diplo and diplo.treaty == "peace") then
                            table.insert(targets, {
                                id       = connId,
                                isPlayer = (tgtOwner == "player"),
                                garrison = st.cityData[connId].garrison,
                            })
                        end
                    end
                end
                -- 排序：玩家城优先(isPlayer=true)，同类按守军升序(薄弱优先)
                table.sort(targets, function(a, b)
                    if a.isPlayer ~= b.isPlayer then return a.isPlayer end
                    return a.garrison < b.garrison
                end)

                if #targets > 0 then
                    -- 主目标优先选最薄弱的，偶尔随机(30%概率)增加不可预测性
                    local pick = (math.random() < 0.7) and 1 or math.random(#targets)
                    local tgtId   = targets[pick].id
                    local tgtData = st.cityData[tgtId]
                    local tgtCity = WORLD_CITIES[tgtId]
                    local atkHeroPower = M.CalcSquadPower(srcData.heroes)
                    local atkMorale = M.CalcMoraleMod(srcData.morale)
                    local atkPower = (srcData.garrison * 0.5 + atkHeroPower) * atkMorale
                    local defHeroPower = M.CalcSquadPower(tgtData.heroes)
                    local defMorale = M.CalcMoraleDefMod(tgtData.morale)
                    local troopAdv = M.CalcTroopAdvantage(srcData.heroes, tgtData.heroes)
                    local defLvMod = M.CalcDefLevelMod(tgtData.level)
                    local defPower = (tgtData.garrison * 0.5 + defHeroPower + tgtData.level * 2000) * defMorale * defLvMod
                    atkPower = atkPower * troopAdv
                    local facName = GetFacName(fac)

                    -- 智能日志：解释进攻理由
                    local reason = ""
                    if targets[pick].isPlayer then
                        if targets[pick].garrison < 4000 then
                            reason = " [守军薄弱(" .. FormatTroops(tgtData.garrison) .. ")]"
                        else
                            reason = " [进攻我方]"
                        end
                    end
                    -- 兵种克制提示
                    local advHint = ""
                    if troopAdv > 1.05 then advHint = " [克制]"
                    elseif troopAdv < 0.95 then advHint = " [被克]" end

                    if atkPower > defPower then
                        local oldOwner = tgtData.owner
                        tgtData.owner = fac
                        tgtData.garrison = math.floor(atkPower - defPower * 0.5)
                        srcData.garrison = math.floor(srcData.garrison * 0.4)
                        -- 士气影响: 胜方士气+5, 败方相邻城士气-3
                        srcData.morale = math.min(100, (srcData.morale or 50) + 5)
                        local movedHeroes = {}
                        for i = #srcData.heroes, 1, -1 do
                            if #movedHeroes < 2 then
                                table.insert(movedHeroes, srcData.heroes[i])
                                table.remove(srcData.heroes, i)
                            end
                        end
                        for _, h in ipairs(movedHeroes) do table.insert(tgtData.heroes, h) end
                        local involvesPlayer = (oldOwner == "player")
                        local pwrStr = " (战力 " .. math.floor(atkPower) .. " vs " .. math.floor(defPower) .. ")"
                        if involvesPlayer then
                            table.insert(report, {type="lost", text="失守! " .. facName .. " 攻占 " .. tgtCity.name .. reason .. advHint .. pwrStr})
                        else
                            table.insert(report, {type="battle", text=facName .. " 攻占 " .. tgtCity.name .. advHint})
                        end
                        -- 所有攻城战都生成动画
                        table.insert(battleAnims, {
                            type = "conquest",
                            fromId = srcCity.id,
                            toId = tgtId,
                            fac = fac,
                            oldOwner = oldOwner,
                            facName = facName,
                            cityName = tgtCity.name,
                            troops = math.floor(srcData.garrison),
                            notify = facName .. " 攻破 " .. tgtCity.name .. "!",
                            isAIBattle = not involvesPlayer,
                        })
                        -- 败方相邻城士气-3 (仅影响玩家)
                        if involvesPlayer then
                            for _, connId in ipairs(WORLD_CITIES[tgtId].conn) do
                                local connData = st.cityData[connId]
                                if connData and connData.owner == "player" then
                                    connData.morale = math.max(0, (connData.morale or 50) - 3)
                                end
                            end
                        end
                    else
                        srcData.garrison = math.floor(srcData.garrison * 0.7)
                        tgtData.garrison = math.max(500, tgtData.garrison - math.floor(atkPower * 0.3))
                        local involvesPlayer = targets[pick].isPlayer
                        if involvesPlayer then
                            local pwrStr = " (战力 " .. math.floor(atkPower) .. " vs " .. math.floor(defPower) .. ")"
                            table.insert(report, {type="battle", text=facName .. " 攻 " .. tgtCity.name .. reason .. advHint .. " 败退" .. pwrStr})
                        else
                            table.insert(report, {type="battle", text=facName .. " 攻 " .. tgtCity.name .. advHint .. " 败退"})
                        end
                        -- 所有败退战都生成动画
                        table.insert(battleAnims, {
                            type = "repelled",
                            fromId = srcCity.id,
                            toId = tgtId,
                            fac = fac,
                            facName = facName,
                            cityName = tgtCity.name,
                            notify = facName .. " 进攻 " .. tgtCity.name .. " 被击退!",
                            isAIBattle = not involvesPlayer,
                        })
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
            table.insert(report, {type="diplomacy", text=GetFacName(fac) .. " 撕毁和约!"})
            -- 外交通知震屏
            local AnimDiplo = require("ui.anim")
            AnimDiplo.StartShake(5, 0.3, gameState.gameTime or 0)
            AnimDiplo.StartFlash(200, 50, 50, 0.25, gameState.gameTime or 0)
        end
    end

    -- 5) 士气警告 + 兵种提示
    local lowMoraleCities = {}
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" and (cd.morale or 50) < 40 then
            table.insert(lowMoraleCities, city.name .. "(" .. math.floor(cd.morale) .. ")")
        end
    end
    if #lowMoraleCities > 0 then
        table.insert(report, {type="warning", text="士气低落: " .. table.concat(lowMoraleCities, ", ") .. " (可犒赏提升)"})
    end

    st.turn = st.turn + 1
    st.totalTurns = st.totalTurns + 1
    -- 行动力由粮草决定: 基础3 + 每100粮+1, 上限6
    st.maxActionPoints = math.min(6, 3 + math.floor((st.food or 0) / 10000))
    st.actionPoints = st.maxActionPoints  -- 回合开始重置行动点
    st.turnReport = report
    st.reportScroll = 0

    -- 如果有战斗动画, 先播放动画再显示战报
    if #battleAnims > 0 then
        st.battleAnims = battleAnims
        st.battleAnimIdx = 1
        st.battleAnimPhase = "march"
        st.battleAnimT = 0
        st.battleAnimData = battleAnims[1]
        st.phase = "BATTLE_ANIM"
        -- 自动聚焦到第一个战斗的出发城
        local first = battleAnims[1]
        if first and first.fromId then
            local fromCity = WORLD_CITIES[first.fromId]
            if fromCity then
                st.mapTargetX = fromCity.x
                st.mapTargetY = fromCity.y
                st.mapTargetZoom = 2.0
            end
        end
    else
        st.phase = "TURN_REPORT"
    end

    local pCities = 0
    for _, city in ipairs(WORLD_CITIES) do
        if st.cityData[city.id].owner == "player" then pCities = pCities + 1 end
    end
    if pCities == 0 then
        table.insert(st.turnReport, {type="gameover", text="所有城池失守, 大业未成..."})
    elseif pCities >= #WORLD_CITIES then
        table.insert(st.turnReport, {type="victory", text="天下一统! 恭喜称帝!"})
        -- 一次性发放大量玉壁 (仅首次触发)
        if not st.conquestRewardGiven then
            st.conquestRewardGiven = true
            local conquestJade = 50000
            if rawget(_G, "playerInfo") and playerInfo then
                playerInfo.jade = (playerInfo.jade or 0) + conquestJade
                table.insert(st.turnReport, {type="reward", text="一统天下奖励: +" .. conquestJade .. " 玉壁!"})
            end
        end
    end
    print("[WorldMap] Turn " .. st.turn .. " ended. Player cities: " .. pCities)
end

-- ============================================================================
-- 玩家行军
-- ============================================================================
function M.MoveArmy(fromId, toId, troops, heroes)
    local st = worldMapState
    if not M.CanAct("move") then return false, "行动点不足" end
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
    M.SpendAP("move")
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

    -- 费用: 20000金
    if st.gold < 20000 then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需2万)") end
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

    st.gold = st.gold - 20000

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
        -- 自动装备: 如果该武技已解锁且该武将武技槽有空位, 自动装备给学生武将
        if SKILL_DEFS[teacherTech] and SKILL_DEFS[teacherTech].unlocked then
            local equippedSet = rawget(_G, "GetAllEquippedSkillSet") and GetAllEquippedSkillSet() or {}
            if not equippedSet[teacherTech] then
                local heroSkills = rawget(_G, "GetHeroSkills") and GetHeroSkills(studentIdx) or {}
                if #heroSkills < 2 then
                    heroSkills[#heroSkills + 1] = teacherTech
                    if rawget(_G, "SaveGameProgress") then SaveGameProgress() end
                    print("=== 自动装备武技: " .. techName .. " → 武将#" .. tostring(studentIdx) .. " (槽位" .. #heroSkills .. ") ===")
                end
            end
        end
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
    if not M.CanAct("attack") then return false end
    local fromData, toData = st.cityData[fromId], st.cityData[toId]
    if not fromData or not toData then return false end
    if fromData.owner ~= "player" then return false end
    if toData.owner == "player" then return false end
    local deployTroops = st.deployTroops
    if deployTroops < 2000 then
        if rawget(_G, "ShowToast") then ShowToast("至少需要2000兵力出征") end
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
    M.SpendAP("attack")
    st.food = st.food - foodCost
    st.attackContext = {
        fromId = fromId, toId = toId,
        attackTroops = deployTroops,
        defenderFaction = toData.owner,
        deployHeroes = st.deployHeroes or {},
        formationId = st.selectedFormation,
        tacticId    = st.selectedTactic,
    }
    fromData.garrison = fromData.garrison - deployTroops
    -- 敌方使用基础数值, 不做额外缩放; 城池等级通过 card.level → CalcSoldierStats 自然影响
    if rawget(_G, "stageState") then stageState.enemyScale = 1.0 end
    if rawget(_G, "PLAYER_SLOTS") and rawget(_G, "HERO_CARDS") then
        -- === 设置玩家 PLAYER_SLOTS ===
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
        -- === 设置敌方 ENEMY_SLOTS (用防守城池的守将HERO_CARDS) ===
        if rawget(_G, "ENEMY_SLOTS") then
            for _, slot in ipairs(ENEMY_SLOTS) do slot.filled = false; slot.card = nil end
            local defHeroes = toData.heroes or {}
            for i, hIdx in ipairs(defHeroes) do
                if i > #ENEMY_SLOTS then break end
                local card = HERO_CARDS[hIdx]
                if card then
                    local slot = ENEMY_SLOTS[i]
                    slot.filled = true
                    slot.card = {
                        idx = hIdx, name = card.name, quality = card.quality,
                        unitClass = card.unitClass,
                        atk = card.atk,
                        def = card.def,
                        hp  = card.hp,
                        skill = card.skill, skillData = card.skillData, singleImg = card.singleImg,
                        row = card.row, col = card.col, type = card.type,
                        faction = card.faction,
                        level = math.max(1, toData.level or 1),
                        constellation = 0,
                    }
                    slot.spawnCount = 0; slot.deployCD = 0
                end
            end
            -- 守将不足时补充泛用兵卒(使用ENEMY_CARDS)
            local filled = #defHeroes
            if filled < 2 and rawget(_G, "ENEMY_CARDS") then
                local usedE = {}
                for fi = filled + 1, math.min(3, #ENEMY_SLOTS) do
                    local idx
                    repeat idx = math.random(1, #ENEMY_CARDS) until not usedE[idx]
                    usedE[idx] = true
                    local ec = ENEMY_CARDS[idx]
                    if ec and not ec.isBoss then
                        local slot = ENEMY_SLOTS[fi]
                        local card = {}
                        for k, v in pairs(ec) do card[k] = v end
                        -- 泛用兵卒直接使用 ENEMY_CARDS 基础数值
                        card.level = math.max(1, (toData.level or 1))
                        card.constellation = 0
                        slot.filled = true; slot.card = card
                        slot.spawnCount = 0; slot.deployCD = 0
                    end
                end
            end
            -- 标记SLG敌方已预设, init.lua跳过随机填充
            st.attackContext.enemySlotsPreset = true
        end
    end
    print("[WorldMap] Attack: " .. WORLD_CITIES[fromId].name .. " -> " .. WORLD_CITIES[toId].name)
    WorldMap.StartMarchAnim(fromId, toId, deployTroops, function()
        -- SLG 战斗使用旧模式(自动战斗), 不再使用战旗回合制
        if rawget(_G, "gameState") then gameState.useTacticsMode = false end
        if rawget(_G, "InitBattle") then InitBattle() end
        -- InitBattle 会重置 battleGarrisonCap=0, 这里再覆盖为实际驻军数
        if rawget(_G, "battleGarrisonCap") ~= nil then
            battleGarrisonCap = deployTroops  -- 本场战斗玩家最多派出这么多兵
            battlePlayerTotalSpawned = 0
        end
        if rawget(_G, "PushPhase") then PushPhase("BATTLE") end
        if rawget(_G, "gameState") then
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
    local gs = rawget(_G, "gameState") or {}
    local isEnemyRetreated = gs.enemyRetreatedSuccess

    if victory then
        if isEnemyRetreated then
            -- === 敌方撤退 → 视为胜利但不占城 ===
            local pUnits = rawget(_G, "playerUnits") or {}
            local initP = gs.initialPlayerUnits or 1
            local aliveP = #pUnits
            local survivalRatio = (initP > 0) and (aliveP / initP) or 0
            local returnTroops = math.floor(ctx.attackTroops * survivalRatio)
            fromData.garrison = fromData.garrison + returnTroops
            local goldLoot = (tgtCity.def or 1) * 2000 + 3000
            local foodLoot = (tgtCity.def or 1) * 1000 + 2000
            st.gold = st.gold + goldLoot
            st.food = st.food + foodLoot
            local oldMorale = fromData.morale or 60
            fromData.morale = math.min(100, oldMorale + 10)
            st.lastBattleReward = {
                victory=true, gold=goldLoot, food=foodLoot,
                garrison=returnTroops, moraleDelta=10,
                enemyRetreated=true,
                survivalPct = math.floor(survivalRatio * 100),
            }
            if rawget(_G, "AddFloatText") then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
                    "敌军撤退! " .. FormatTroops(returnTroops) .. "兵归城", 2.5, {255, 220, 80}, 22)
            end
            st.pendingPlayerAnim = {
                type = "repelled",
                fromId = ctx.fromId, toId = ctx.toId,
                fac = "player",
                msg = "敌军撤退! 我军获胜!",
            }
            st.attackContext = nil
            st.deployHeroes = {}
            st.deployTroops = 0
            return
        end

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

        -- === 胜利奖励: 金粮掠夺 + 兵力回返 + 士气上升 ===
        local goldLoot    = (tgtCity.def or 1) * 4000 + 6000   -- 按城防等级给金
        local foodLoot    = (tgtCity.def or 1) * 2500 + 4000
        local returnTroop = math.floor(ctx.attackTroops * 0.30)
        st.gold = st.gold + goldLoot
        st.food = st.food + foodLoot
        fromData.garrison = fromData.garrison + returnTroop
        local oldMorale = fromData.morale or 60
        fromData.morale = math.min(100, oldMorale + 15)
        st.lastBattleReward = {
            victory=true, gold=goldLoot, food=foodLoot,
            garrison=returnTroop, moraleDelta=15,
        }
        -- 攻占弹窗公告延迟到 BATTLE_ANIM 播完后再显示
        -- (此时还在战斗结算界面, 立即调用 StartActionCard 会在回到世界地图前过期)
        local lootDesc = "缴获金币" .. goldLoot .. " 粮草" .. foodLoot .. "\n回收兵力" .. returnTroop .. " 士气+15"
        st.pendingPlayerAnim = {
            type = "conquest",
            fromId = ctx.fromId, toId = ctx.toId,
            fac = "player",
            msg = "我军攻占 " .. tgtCity.name .. "!",
            -- ActionCard 数据, 在 BATTLE_ANIM 结束后启动
            actionCard = {
                icon = "conquest",
                title = "攻占 " .. tgtCity.name,
                desc = lootDesc,
                color = {255, 220, 50},
            },
        }

        -- 如果有被俘敌将，进入招降阶段
        if #capturedHeroes > 0 then
            st.capturedHeroes = capturedHeroes
            st.capturedCityId = ctx.toId
            st.surrenderResults = {}  -- 每个武将的招降结果
            st.phase = "SURRENDER"
            st.attackContext = nil
            st.deployHeroes = {}
            st.deployTroops = 0
            -- worldMapBattle 标志由 input_begin_press.lua 的 WIN 确认按钮清除
            return  -- 不在此处清理，等招降阶段结束
        end
    else
        -- === 战败惩罚: 粮食损耗 + 士气下降 ===
        local foodPenalty = math.floor(ctx.attackTroops * 0.20)
        st.food = math.max(0, st.food - foodPenalty)
        local oldMorale = fromData.morale or 60
        fromData.morale = math.max(0, oldMorale - 20)

        -- gs 已在函数顶部定义
        local isRetreat = gs and gs.retreated

        if isRetreat then
            -- === 撤退成功: 武将安全回城, 存活兵力按比例回城 ===
            local pUnits = rawget(_G, "playerUnits") or {}
            local initP = gs.initialPlayerUnits or 1
            local aliveP = #pUnits
            local survivalRatio = (initP > 0) and (aliveP / initP) or 0
            local returnTroops = math.floor(ctx.attackTroops * survivalRatio)
            fromData.garrison = fromData.garrison + returnTroops
            st.lastBattleReward = {
                victory=false, gold=0, food=-foodPenalty,
                garrison=returnTroops, moraleDelta=-20, retreat=true,
                survivalPct = math.floor(survivalRatio * 100),
            }
            if rawget(_G, "AddFloatText") then
                local pct = math.floor(survivalRatio * 100)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
                    "鸣金收兵! 存活" .. pct .. "%, " .. returnTroops .. "兵归城",
                    2.5, {255, 200, 100}, 22)
            end
            st.pendingPlayerAnim = {
                type = "retreat",
                fromId = ctx.fromId, toId = ctx.toId,
                fac = "player",
                msg = "我军鸣金收兵, 安全撤退",
            }
        else
            -- === 全军覆没: AI决定俘获武将命运 ===
            local heroFates = {}
            local deployed = ctx.deployHeroes or {}
            -- tgtCity 已在函数顶部定义
            for _, hIdx in ipairs(deployed) do
                local card = HERO_CARDS[hIdx]
                if card then
                    -- 从出发城移除武将
                    if fromData and fromData.heroes then
                        for i, h in ipairs(fromData.heroes) do
                            if h == hIdx then table.remove(fromData.heroes, i); break end
                        end
                    end
                    -- AI决定: 60%招降 40%处死
                    local fate
                    if math.random() < 0.60 then
                        fate = "recruit"
                        -- 武将归入敌城
                        if toData and toData.heroes then
                            table.insert(toData.heroes, hIdx)
                        end
                    else
                        fate = "execute"
                    end
                    -- 玩家失去该武将
                    if playerHeroes[hIdx] then
                        playerHeroes[hIdx].owned = false
                    end
                    table.insert(heroFates, {
                        idx = hIdx, name = card.name,
                        fate = fate, quality = card.quality or 1,
                    })
                end
            end
            st.defeatHeroReport = heroFates
            st.lastBattleReward = {
                victory=false, gold=0, food=-foodPenalty,
                garrison=0, moraleDelta=-20, heroFates=heroFates,
            }
            if rawget(_G, "AddFloatText") then
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
                    "全军覆没!", 2.0, {200, 60, 60}, 22)
            end
            -- 进入战败通报阶段
            st.phase = "DEFEAT_REPORT"
            st.attackContext = nil
            st.deployHeroes = {}
            st.deployTroops = 0
            return
        end
    end
    st.attackContext = nil
    st.deployHeroes = {}
    st.deployTroops = 0
    -- worldMapBattle 标志由 input_begin_press.lua 的 WIN/LOSE 确认按钮清除
end

-- ============================================================================
-- 激活暂存的玩家战斗动画 (从结算界面返回地图时调用)
-- ============================================================================
function M.ActivatePendingPlayerAnim()
    local st = worldMapState
    local anim = st.pendingPlayerAnim
    if not anim then return false end
    st.pendingPlayerAnim = nil

    -- 保存 ActionCard 数据, 在 BATTLE_ANIM 播完回到 MAP 时启动
    if anim.actionCard then
        st._pendingActionCard = anim.actionCard
    end

    -- 确定起始阶段 (跳过march, 玩家出征前已看过行军动画)
    local startPhase
    if anim.type == "conquest" then
        startPhase = "siege"
    elseif anim.type == "repelled" then
        startPhase = "siege"
    else  -- retreat
        startPhase = "notify"
    end

    -- 复用现有 battleAnim 基础设施
    st.battleAnims = { anim }
    st.battleAnimIdx = 1
    st.battleAnimData = anim
    st.battleAnimPhase = startPhase
    st.battleAnimT = 0
    st.battleAnimIsPlayer = true  -- 结束后回MAP而非TURN_REPORT
    st.phase = "BATTLE_ANIM"

    -- 聚焦目标城
    local toCity = WORLD_CITIES[anim.toId]
    if toCity then
        st.mapTargetX = toCity.x
        st.mapTargetY = toCity.y
        st.mapTargetZoom = 2.0
    end
    return true
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
    st.surrenderCurrentIdx = nil
    st.surrenderDialogue = nil
    st._surrenderOpenTime = nil
    st.phase = "MAP"
end

-- ============================================================================
-- 补兵 (补充兵力到武将领兵上限)
-- ============================================================================
function M.Reinforce(cityId, amount)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd or cd.owner ~= "player" then return false, "非我方城池" end
    if not M.CanAct("reinforce") then return false, "行动点不足" end
    -- 领兵上限检查
    local troopCap = M.CalcCityTroopCap(cityId)
    if troopCap <= 0 then return false, "无武将驻守，无法补兵" end
    -- 人口驻军上限: 取领兵上限和人口上限中的较小值
    local popCap = M.CalcCityPopCap(cityId)
    local effectiveCap = math.min(troopCap, popCap)
    local maxAdd = math.max(0, effectiveCap - (cd.garrison or 0))
    if maxAdd <= 0 then return false, "兵力已达上限(" .. FormatTroops(effectiveCap) .. ")" end
    -- 实际补兵量不超过上限
    amount = math.min(amount, maxAdd)
    -- 补兵费用: 5金/人 + 1粮/人
    local goldCost = amount * 5
    local foodCost = amount
    if st.gold < goldCost then return false, "金币不足(需" .. goldCost .. ")" end
    if st.food < foodCost then return false, "粮草不足(需" .. foodCost .. ")" end
    M.SpendAP("reinforce")
    st.gold = st.gold - goldCost
    st.food = st.food - foodCost
    cd.garrison = cd.garrison + amount
    return true, amount
end

-- ============================================================================
-- 内政
-- ============================================================================
function M.Recruit(cityId, amount)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd or cd.owner ~= "player" then return false end
    if not M.CanAct("recruit") then return false end
    -- 人口驻军上限: 城市人口的一成可从军
    local popCap = M.CalcCityPopCap(cityId)
    local curGarrison = cd.garrison or 0
    local maxAdd = math.max(0, popCap - curGarrison)
    if maxAdd <= 0 then
        if rawget(_G, "ShowToast") then ShowToast("驻军已达人口上限(" .. FormatTroops(popCap) .. ")") end
        return false
    end
    -- 单次征兵量不超过剩余空间
    if amount > maxAdd then amount = maxAdd end
    local goldCost, foodCost = amount * 3, amount * 1
    if st.gold < goldCost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需" .. goldCost .. ")") end
        return false
    end
    if st.food < foodCost then
        if rawget(_G, "ShowToast") then ShowToast("粮草不足") end
        return false
    end
    M.SpendAP("recruit")
    st.gold = st.gold - goldCost
    st.food = st.food - foodCost
    cd.garrison = cd.garrison + amount
    return true, amount
end

function M.UpgradeCity(cityId)
    local st = worldMapState
    local cd = st.cityData[cityId]
    if not cd or cd.owner ~= "player" then return false end
    if not M.CanAct("upgrade") then return false end
    if cd.level >= 5 then
        if rawget(_G, "ShowToast") then ShowToast("城防已满级") end
        return false
    end
    local cost = cd.level * 20000
    if st.gold < cost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需" .. cost .. ")") end
        return false
    end
    M.SpendAP("upgrade")
    st.gold = st.gold - cost
    cd.level = cd.level + 1
    return true
end

function M.SearchTalent(cityId)
    local st = worldMapState
    if not M.CanAct("search") then return false end
    local cost = 10000
    if st.gold < cost then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需1万)") end
        return false
    end
    M.SpendAP("search")
    st.gold = st.gold - cost
    -- 引导中第一次搜索必出人才
    local Input = require("systems.slg.slg_input")
    local guideForce = Input.IsGuideActive()
    if (guideForce or math.random() < 0.2) and rawget(_G, "HERO_CARDS") then
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
    if not M.CanAct("morale") then return false end
    if st.gold < 8000 then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需8千)") end
        return false
    end
    M.SpendAP("morale")
    st.gold = st.gold - 8000
    cd.morale = math.min(100, cd.morale + 15)
    return true
end

-- ============================================================================
-- 外交
-- ============================================================================
function M.SendGift(faction)
    local st = worldMapState
    if not M.CanAct("diplomacy") then return false end
    if st.gold < 20000 then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需2万)") end
        return false
    end
    M.SpendAP("diplomacy")
    st.gold = st.gold - 20000
    local d = st.diplomacy[faction]
    if d then
        d.relation = math.min(100, d.relation + 15)
        if rawget(_G, "ShowToast") then ShowToast(GetFacName(faction) .. " 好感 +15") end
    end
    return true
end

function M.SignTreaty(faction)
    local st = worldMapState
    if not M.CanAct("diplomacy") then return false end
    local d = st.diplomacy[faction]
    if not d then return false end
    if d.relation < 60 then
        if rawget(_G, "ShowToast") then ShowToast("好感度不足60, 无法缔约") end
        return false
    end
    if st.gold < 50000 then
        if rawget(_G, "ShowToast") then ShowToast("金币不足(需5万)") end
        return false
    end
    M.SpendAP("diplomacy")
    st.gold = st.gold - 50000
    d.treaty = "peace"
    if rawget(_G, "ShowToast") then ShowToast("与" .. GetFacName(faction) .. "缔结和约!") end
    return true
end

-- ============================================================================
-- 计略
-- ============================================================================
function M.ExecuteStratagem(stratagemId, targetCityId)
    local st = worldMapState
    if not M.CanAct("stratagem") then return false end
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
    M.SpendAP("stratagem")
    st.gold = st.gold - strat.cost

    local bonusRate = 0
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd.owner == "player" then bonusRate = bonusRate + #cd.heroes * 0.02 end
    end
    local finalRate = math.min(0.95, strat.successRate + bonusRate)

    if math.random() < finalRate then
        if stratagemId == "fire" then
            td.garrison = math.max(500, td.garrison - 2000)
            if rawget(_G, "ShowToast") then ShowToast("火计成功! 敌军 -2000") end
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
        actionPoints = st.actionPoints,
        maxActionPoints = st.maxActionPoints,
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
    st.gold = data.gold or 50000
    st.food = data.food or 30000
    st.troops = data.troops or 20000
    st.actionPoints = data.actionPoints or 6
    st.maxActionPoints = data.maxActionPoints or 6
    st.playerFaction = data.playerFaction or "wu"

    -- 恢复城池数据 (key 从 string 转回 number)
    st.cityData = {}
    for cidStr, cd in pairs(data.cityData) do
        local cid = tonumber(cidStr)
        if cid then
            st.cityData[cid] = {
                owner = cd.owner or "qun",
                garrison = cd.garrison or 3000,
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
