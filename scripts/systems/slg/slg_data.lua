-- ============================================================================
-- slg/slg_data.lua - 三国武灵传：SLG静态数据
-- 城池、地形、阵营颜色、计略定义
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 城池定义 (18城, 坐标基于 1024×571 横屏设计分辨率)
-- ============================================================================
-- 坐标根据水墨地图上标注的地理要素（太行山、黄河、秦岭、大巴山、汉水、长江、湘江）精确定位
-- 与三国时期真实华夏大地城池位置对应
WORLD_CITIES = {
    -- ── 魏 ──────────────────────────────────────────
    {id=1,  name="邺城", x=600, y=92,  faction="wei", prod=60, def=3, conn={2,3,10},   region="中原", terrain="plain"},
    -- 邺城(今河北临漳): 太行山南麓东侧, 黄河北岸平原
    {id=2,  name="北平", x=710, y=30,  faction="wei", prod=40, def=2, conn={1,14},      region="河北", terrain="mountain"},
    -- 北平(今北京): 太行山东北端, 燕山脚下
    {id=3,  name="许昌", x=570, y=175, faction="wei", prod=80, def=4, conn={1,4,5,6},   region="中原", terrain="plain"},
    -- 许昌(今河南许昌): 黄河以南, 中原平原腹地
    {id=4,  name="洛阳", x=460, y=155, faction="wei", prod=70, def=4, conn={3,5,9,10},  region="中原", terrain="plain"},
    -- 洛阳(今河南洛阳): 黄河南岸, 秦岭东北方, 关中通道
    -- ── 群 (中部争夺区) ──────────────────────────────
    {id=5,  name="宛城", x=475, y=240, faction="qun", prod=45, def=2, conn={3,4,6,7},   region="荆北", terrain="hill"},
    -- 宛城(今河南南阳): 秦岭东端以南, 汉水上游北侧盆地
    {id=6,  name="汝南", x=610, y=220, faction="qun", prod=40, def=2, conn={3,5,7,14},  region="中原", terrain="plain"},
    -- 汝南(今河南驻马店): 许昌东南方, 淮河上游平原
    {id=7,  name="襄阳", x=470, y=310, faction="qun", prod=55, def=3, conn={5,6,8,12},  region="荆北", terrain="river"},
    -- 襄阳(今湖北襄阳): 汉水中游, 地图"汉水"标注偏左
    {id=8,  name="荆州", x=445, y=375, faction="qun", prod=65, def=3, conn={7,9,11,12}, region="荆南", terrain="river"},
    -- 荆州(今湖北荆州): 长江中游北岸, 地图"长水"标注附近
    -- ── 蜀 ──────────────────────────────────────────
    {id=9,  name="汉中", x=310, y=255, faction="shu", prod=50, def=3, conn={4,8,10,11}, region="蜀地", terrain="mountain"},
    -- 汉中(今陕西汉中): 秦岭以南、大巴山以北的汉中盆地
    {id=10, name="西凉", x=110, y=85,  faction="qun", prod=35, def=2, conn={1,4,9},     region="西北", terrain="desert"},
    -- 西凉(今甘肃武威): 地图最左上, 河西走廊
    {id=11, name="成都", x=240, y=355, faction="shu", prod=80, def=4, conn={8,9,17},    region="蜀地", terrain="basin"},
    -- 成都(今四川成都): 大巴山西南方, 四川盆地中心
    -- ── 群 (南部) ───────────────────────────────────
    {id=12, name="长沙", x=520, y=430, faction="qun", prod=45, def=2, conn={7,8,13,18}, region="荆南", terrain="hill"},
    -- 长沙(今湖南长沙): 湘江标注附近, 洞庭湖以南
    -- ── 吴 ──────────────────────────────────────────
    {id=13, name="柴桑", x=630, y=335, faction="wu",  prod=50, def=3, conn={12,14,15},  region="江东", terrain="river"},
    -- 柴桑(今江西九江): 长江南岸, 鄱阳湖西侧
    {id=14, name="寿春", x=685, y=200, faction="qun", prod=45, def=2, conn={2,6,13,15}, region="中原", terrain="plain"},
    -- 寿春(今安徽寿县): 淮河流域, 合肥以西
    {id=15, name="建业", x=745, y=280, faction="wu",  prod=80, def=4, conn={13,14,16},  region="江东", terrain="river"},
    -- 建业(今江苏南京): 长江下游南岸, "江"标注附近
    {id=16, name="吴郡", x=815, y=315, faction="wu",  prod=55, def=3, conn={15,18},     region="江东", terrain="plain"},
    -- 吴郡(今江苏苏州): 建业东南, 太湖流域
    {id=17, name="南蛮", x=195, y=470, faction="qun", prod=30, def=1, conn={11,18},     region="南方", terrain="forest"},
    -- 南蛮(云贵高原): 地图左下方, 成都西南深山
    {id=18, name="江州", x=355, y=395, faction="qun", prod=40, def=2, conn={16,17,12},  region="南方", terrain="forest"},
    -- 江州(今重庆): 长江上游与嘉陵江交汇, 成都与荆州之间
}

-- 山脉数据 (固定地形装饰, 与地图实际山脉位置对应)
M.MOUNTAINS = {
    {x=630, y=75,  peaks={{0,0,18},{-12,5,12},{14,3,14},{-6,-8,10}}},  -- 太行山
    {x=385, y=235, peaks={{0,0,16},{-10,4,11},{12,6,13},{18,2,10}}},   -- 秦岭
    {x=345, y=285, peaks={{0,0,14},{-8,3,10},{10,5,12}}},              -- 大巴山
    {x=150, y=200, peaks={{0,0,12},{8,4,9},{-10,6,10}}},               -- 陇山/六盘山
    {x=200, y=400, peaks={{0,0,13},{-9,3,10},{7,5,9}}},                -- 云贵高原山地
}

-- 森林数据 (对应地图上的植被区域)
M.FORESTS = {
    {x=270, y=330, count=5}, -- 蜀地丛林(成都北)
    {x=210, y=450, count=4}, -- 南蛮密林
    {x=480, y=350, count=3}, -- 荆南丛林(荆州南)
    {x=660, y=310, count=4}, -- 江东丛林(柴桑周围)
    {x=390, y=410, count=3}, -- 巴东丛林(江州附近)
    {x=540, y=455, count=3}, -- 湘南丛林(长沙南)
}

-- 阵营颜色体系 (main/light/dark/glow)
M.FC = {
    shu    = { main={200, 55, 55},   light={255,120,100}, dark={130,25,25},  glow={255,80,60}   },
    wei    = { main={50, 90, 200},   light={100,145,255}, dark={25,50,140},  glow={70,120,255}  },
    wu     = { main={45, 160, 55},   light={90,210,100},  dark={20,100,25},  glow={60,200,70}   },
    qun    = { main={160,140, 55},   light={210,195,100}, dark={100,85,25},  glow={200,180,70}  },
    player = { main={230,180, 50},   light={255,220,100}, dark={160,120,20}, glow={255,210,60}  },
}

-- ============================================================================
-- 建筑定义 (6种建筑, 每城可各建一个, 最高5级)
-- ============================================================================
M.BUILDINGS = {
    {id="farm",     name="农田", icon="slgIconFood", desc="增加粮草产出",
     cost={80,150,250,400,600},   -- 各级升级费用(金)
     effect="food",               -- food=粮草加成, gold=金币加成, recruit=征兵加成, defense=城防加成, craft=计略加成, research=搜才加成
     bonus={10,25,45,70,100},     -- 各级加成数值(粮草/回合)
    },
    {id="market",   name="市集", icon="slgIconMarket", desc="增加金币产出",
     cost={100,180,300,480,700},
     effect="gold",
     bonus={15,35,60,90,130},
    },
    {id="barracks", name="兵营", icon="slgIconBow", desc="增加自动征兵量",
     cost={120,200,320,500,750},
     effect="recruit",
     bonus={3,6,10,15,22},        -- 各级额外征兵/回合
    },
    {id="wall",     name="城墙", icon="slgIconCastle", desc="增加城防战力",
     cost={150,250,400,600,900},
     effect="defense",
     bonus={10,25,45,70,100},     -- 各级额外防御力
    },
    {id="workshop", name="工坊", icon="slgIconHammer", desc="提高计略成功率",
     cost={100,180,300,480,700},
     effect="craft",
     bonus={0.03,0.06,0.10,0.15,0.20},  -- 各级计略成功率加成
    },
    {id="academy",  name="学府", icon="slgIconBook", desc="提高搜才成功率",
     cost={80,150,250,400,600},
     effect="research",
     bonus={0.03,0.06,0.10,0.15,0.22},  -- 各级搜才加成
    },
}

-- 计略定义
M.STRATAGEMS = {
    {id="fire",      name="火计",   desc="烧毁敌城粮仓 驻军-20",    cost=120, icon="slgIconFire", successRate=0.5},
    {id="spy",       name="离间",   desc="降低敌城士气-25",          cost=150, icon="slgIconScroll", successRate=0.6},
    {id="scout",     name="刺探",   desc="查看敌城详细兵力武将",     cost=50,  icon="slgIconEye", successRate=0.9},
    {id="counterspy",name="反间",   desc="破坏敌城外交 关系-15",     cost=180, icon="slgIconSpy", successRate=0.55},
    {id="ambush",    name="埋伏",   desc="伏击敌军 驻军-30",         cost=200, icon="slgIconSword",  successRate=0.4},
    {id="cutoff",    name="断粮",   desc="烧毁敌城粮仓 产出-50%一回合", cost=160, icon="slgIconBan", successRate=0.45},
    {id="recruit_t", name="招贤",   desc="策反敌将 忠诚-30",         cost=250, icon="slgIconMask", successRate=0.35},
}

-- ============================================================================
-- AI 性格定义 (每个势力不同的行为倾向)
-- ============================================================================
M.AI_PERSONALITY = {
    wei = {
        name = "雄略", desc = "积极扩张,善用计略",
        aggressionBase = 0.35,   -- 基础攻击概率(比默认0.2更高)
        aggressionScale = 0.35,  -- 城池数量加成系数
        recruitRate = 5,         -- 每城每回合补兵
        stratagemChance = 0.25,  -- 使用计略概率
        preferTarget = "weak",   -- 目标偏好: weak=弱城优先, strong=挑战强城, random=随机
        diploDecay = 3,          -- 外交衰减速度(越高关系降越快)
        defenseThreshold = 25,   -- 低于此兵力不出击
    },
    shu = {
        name = "仁义", desc = "注重防守,外交优先",
        aggressionBase = 0.15,
        aggressionScale = 0.20,
        recruitRate = 4,
        stratagemChance = 0.10,
        preferTarget = "random",
        diploDecay = 1,           -- 外交衰减慢(重信义)
        defenseThreshold = 40,    -- 更保守,兵力充足才出击
    },
    qun = {
        name = "诡诈", desc = "伺机而动,善用计略",
        aggressionBase = 0.25,
        aggressionScale = 0.40,
        recruitRate = 3,
        stratagemChance = 0.35,   -- 最爱用计略
        preferTarget = "weak",
        diploDecay = 4,           -- 外交关系不稳
        defenseThreshold = 20,
    },
}

-- ============================================================================
-- 随机事件定义
-- ============================================================================
M.RANDOM_EVENTS = {
    -- 正面事件
    {
        id = "harvest",    name = "丰收",
        desc = "风调雨顺,粮草丰收",
        icon = "slgIconFood", chance = 0.12,
        target = "player",   -- player=只影响玩家, any=任意势力, ai=只影响AI
        effect = function(st)
            local bonus = 80 + math.random(120)
            st.food = st.food + bonus
            return "丰收! 粮草 +" .. bonus
        end,
    },
    {
        id = "trade",      name = "商队",
        desc = "丝路商队经过,获得金币",
        icon = "slgIconCaravan", chance = 0.10,
        target = "player",
        effect = function(st)
            local bonus = 60 + math.random(140)
            st.gold = st.gold + bonus
            return "商队路过! 金币 +" .. bonus
        end,
    },
    {
        id = "volunteer",  name = "义军来投",
        desc = "百姓慕名投军",
        icon = "slgIconBow", chance = 0.08,
        target = "player",
        effect = function(st)
            -- 随机一座我方城池获得驻军
            local pCities = {}
            for _, city in ipairs(WORLD_CITIES) do
                if st.cityData[city.id] and st.cityData[city.id].owner == "player" then
                    table.insert(pCities, city.id)
                end
            end
            if #pCities > 0 then
                local cid = pCities[math.random(#pCities)]
                local bonus = 15 + math.random(25)
                st.cityData[cid].garrison = st.cityData[cid].garrison + bonus
                local cName = WORLD_CITIES[cid] and WORLD_CITIES[cid].name or "?"
                return cName .. " 义军来投! 驻军 +" .. bonus
            end
            return nil  -- 无城池则不触发
        end,
    },
    {
        id = "morale_up",  name = "军心大振",
        desc = "将士士气高涨",
        icon = "slgIconHorn", chance = 0.08,
        target = "player",
        effect = function(st)
            for _, city in ipairs(WORLD_CITIES) do
                local cd = st.cityData[city.id]
                if cd and cd.owner == "player" then
                    cd.morale = math.min(100, cd.morale + 8)
                end
            end
            return "军心大振! 全城士气 +8"
        end,
    },
    -- 负面事件
    {
        id = "plague",     name = "瘟疫",
        desc = "疫病蔓延,驻军减少",
        icon = "slgIconPlague", chance = 0.06,
        target = "any",
        effect = function(st)
            -- 随机选一座我方城池
            local pCities = {}
            for _, city in ipairs(WORLD_CITIES) do
                if st.cityData[city.id] and st.cityData[city.id].owner == "player" then
                    table.insert(pCities, city.id)
                end
            end
            if #pCities > 0 then
                local cid = pCities[math.random(#pCities)]
                local cd = st.cityData[cid]
                local loss = math.floor(cd.garrison * 0.15)
                cd.garrison = math.max(5, cd.garrison - loss)
                cd.morale = math.max(30, cd.morale - 10)
                local cName = WORLD_CITIES[cid] and WORLD_CITIES[cid].name or "?"
                return cName .. " 爆发瘟疫! 驻军 -" .. loss .. " 士气 -10"
            end
            return nil
        end,
    },
    {
        id = "bandit",     name = "匪患",
        desc = "山贼劫掠,损失金粮",
        icon = "slgIconBlade", chance = 0.08,
        target = "player",
        effect = function(st)
            local goldLoss = 30 + math.random(70)
            local foodLoss = 20 + math.random(50)
            st.gold = math.max(0, st.gold - goldLoss)
            st.food = math.max(0, st.food - foodLoss)
            return "遭遇匪患! 金币 -" .. goldLoss .. " 粮草 -" .. foodLoss
        end,
    },
    {
        id = "flood",      name = "洪涝",
        desc = "河水泛滥,城防受损",
        icon = "slgIconFlood", chance = 0.05,
        target = "any",
        effect = function(st)
            -- 影响河流地形城池
            local riverCities = {}
            for _, city in ipairs(WORLD_CITIES) do
                if city.terrain == "river" and st.cityData[city.id] and st.cityData[city.id].owner == "player" then
                    table.insert(riverCities, city.id)
                end
            end
            if #riverCities > 0 then
                local cid = riverCities[math.random(#riverCities)]
                local cd = st.cityData[cid]
                cd.level = math.max(1, cd.level - 1)
                local cName = WORLD_CITIES[cid] and WORLD_CITIES[cid].name or "?"
                return cName .. " 洪涝灾害! 城防 -1"
            end
            return nil
        end,
    },
    {
        id = "defect",     name = "叛逃",
        desc = "敌方武将心生不满前来投奔",
        icon = "slgIconSurrender", chance = 0.04,
        target = "player",
        effect = function(st)
            -- 寻找一位非玩家武将
            if not rawget(_G, "HERO_CARDS") or not rawget(_G, "playerHeroes") then return nil end
            local candidates = {}
            for _, city in ipairs(WORLD_CITIES) do
                local cd = st.cityData[city.id]
                if cd and cd.owner ~= "player" then
                    for _, hIdx in ipairs(cd.heroes) do
                        local loyalty = st.heroLoyalty[hIdx] or 100
                        if loyalty <= 50 then
                            table.insert(candidates, {hIdx = hIdx, cityId = city.id})
                        end
                    end
                end
            end
            if #candidates > 0 then
                local pick = candidates[math.random(#candidates)]
                local card = HERO_CARDS[pick.hIdx]
                if not card then return nil end
                -- 从原城池移除
                local cd = st.cityData[pick.cityId]
                for i, h in ipairs(cd.heroes) do
                    if h == pick.hIdx then table.remove(cd.heroes, i); break end
                end
                -- 加入玩家
                if not playerHeroes[pick.hIdx] or not playerHeroes[pick.hIdx].owned then
                    playerHeroes[pick.hIdx] = { owned = true, constellation = 0, level = 1 }
                end
                -- 放到第一座玩家城池
                for _, city2 in ipairs(WORLD_CITIES) do
                    local cd2 = st.cityData[city2.id]
                    if cd2 and cd2.owner == "player" then
                        table.insert(cd2.heroes, pick.hIdx)
                        st.heroLoyalty[pick.hIdx] = 80
                        return card.name .. " 不满叛逃,前来归降!"
                    end
                end
            end
            return nil
        end,
    },
}

-- ============================================================================
-- 武将羁绊定义 (组合加成, 同阵中激活)
-- ============================================================================
M.BONDS = {
    {id="tiger_wei",    name="虎卫双雄",  heroes={23,24}, -- 典韦+许褚
     desc="攻+12% 防+10%",
     bonus={atkMult=0.12, defMult=0.10}},
    {id="five_tiger",   name="五虎上将",  heroes={31,32,33,28,29}, -- 赵云+张飞+关羽+马超+黄忠
     desc="攻+20% (任意3人激活)",
     minCount=3, bonus={atkMult=0.20}},
    {id="sworn_bro",    name="桃园结义",  heroes={33,32,4}, -- 关羽+张飞+廖化(代刘备)
     desc="全属性+8%",
     bonus={atkMult=0.08, defMult=0.08, hpMult=0.08}},
    {id="wu_duo",       name="东吴双壁",  heroes={25,34}, -- 孙策+周瑜
     desc="攻+15% 计略成功+10%",
     bonus={atkMult=0.15, stratBonus=0.10}},
    {id="yan_liang",    name="河北双雄",  heroes={18,19}, -- 文丑+颜良
     desc="攻+12% 暴击+8%",
     bonus={atkMult=0.12, critBonus=0.08}},
    {id="wei_cavalry",  name="魏之铁骑",  heroes={26,27,30}, -- 夏侯惇+夏侯渊+张辽
     desc="攻+10% 防+8% (任意2人激活)",
     minCount=2, bonus={atkMult=0.10, defMult=0.08}},
    {id="shu_strat",    name="卧龙凤雏",  heroes={36,21}, -- 诸葛亮+钟会(代庞统)
     desc="计略成功+15% 防+10%",
     bonus={stratBonus=0.15, defMult=0.10}},
    {id="god_war",      name="武神对决",  heroes={35,33}, -- 吕布+关羽
     desc="攻+18%",
     bonus={atkMult=0.18}},
}

-- ============================================================================
-- 武将历史事件 (特定条件触发的剧情+奖励)
-- ============================================================================
M.HERO_EVENTS = {
    {id="guan_yu_pass", name="过五关斩六将", heroId=33,
     condition = function(st)
         -- 关羽参与3场以上胜利
         return (st.heroStats[33] and st.heroStats[33].wins or 0) >= 3
     end,
     desc="关羽千里走单骑, 过五关斩六将!",
     icon="slgIconSword", reward = function(st)
         -- 关羽攻击永久+50
         st.heroBonusAtk = st.heroBonusAtk or {}
         st.heroBonusAtk[33] = (st.heroBonusAtk[33] or 0) + 50
         return "关羽武力永久+50!"
     end},
    {id="zhao_yun_rescue", name="长坂坡救主", heroId=31,
     condition = function(st)
         return (st.heroStats[31] and st.heroStats[31].wins or 0) >= 2
     end,
     desc="赵云于万军中七进七出, 救得幼主!",
     icon="slgIconHorse", reward = function(st)
         st.heroBonusAtk = st.heroBonusAtk or {}
         st.heroBonusAtk[31] = (st.heroBonusAtk[31] or 0) + 40
         st.heroBonusDef = st.heroBonusDef or {}
         st.heroBonusDef[31] = (st.heroBonusDef[31] or 0) + 30
         return "赵云攻+40 防+30!"
     end},
    {id="lv_bu_duel", name="三英战吕布", heroId=35,
     condition = function(st)
         return (st.heroStats[35] and st.heroStats[35].battles or 0) >= 5
     end,
     desc="虎牢关前, 三英战吕布!",
     icon="slgIconBow", reward = function(st)
         st.heroBonusAtk = st.heroBonusAtk or {}
         st.heroBonusAtk[35] = (st.heroBonusAtk[35] or 0) + 60
         return "吕布攻击永久+60!"
     end},
    {id="zhuge_fire", name="火烧博望坡", heroId=36,
     condition = function(st)
         return (st.heroStats[36] and st.heroStats[36].wins or 0) >= 2
     end,
     desc="卧龙初出茅庐, 火烧博望!",
     icon="slgIconFire", reward = function(st)
         st.gold = st.gold + 300
         st.food = st.food + 200
         return "获得金300 粮200!"
     end},
    {id="zhou_yu_fire", name="赤壁之战", heroId=34,
     condition = function(st)
         return (st.heroStats[34] and st.heroStats[34].wins or 0) >= 3
     end,
     desc="周公瑾借东风火烧赤壁!",
     icon="slgIconFlood", reward = function(st)
         st.heroBonusAtk = st.heroBonusAtk or {}
         st.heroBonusAtk[34] = (st.heroBonusAtk[34] or 0) + 45
         return "周瑜攻击永久+45!"
     end},
    {id="dianwei_gate", name="濮阳死战", heroId=23,
     condition = function(st)
         return (st.heroStats[23] and st.heroStats[23].battles or 0) >= 4
     end,
     desc="典韦独守营门, 力战群敌!",
     icon="slgIconShield", reward = function(st)
         st.heroBonusDef = st.heroBonusDef or {}
         st.heroBonusDef[23] = (st.heroBonusDef[23] or 0) + 50
         return "典韦防御永久+50!"
     end},
}

-- ============================================================================
-- 转职系统 (武将达成条件后可转职提升兵种和属性)
-- ============================================================================
M.CLASS_CHANGES = {
    -- heroId, 新兵种, 要求(等级/胜场), 属性加成
    {heroId=31, name="龙胆将军", newClass="CAVALRY", reqWins=5,
     bonus={atk=80, def=40, hp=500}, desc="赵云转职龙胆将军, 骑枪合一!"},
    {heroId=33, name="武圣", newClass="SWORD", reqWins=6,
     bonus={atk=100, def=50, hp=600}, desc="关羽晋升武圣, 青龙偃月无敌!"},
    {heroId=35, name="飞将", newClass="CAVALRY", reqWins=5,
     bonus={atk=120, def=30, hp=400}, desc="吕布转职飞将, 天下无双!"},
    {heroId=36, name="丞相", newClass="MAGE", reqWins=4,
     bonus={atk=60, def=60, hp=800}, desc="诸葛亮拜相, 运筹帷幄!"},
    {heroId=30, name="征东将军", newClass="CAVALRY", reqWins=4,
     bonus={atk=70, def=50, hp=500}, desc="张辽封征东将军, 威震四方!"},
    {heroId=25, name="霸王", newClass="CAVALRY", reqWins=4,
     bonus={atk=90, def=40, hp=400}, desc="孙策封霸王, 勇冠三军!"},
}

-- ============================================================================
-- 任务系统 (中期目标引导)
-- ============================================================================
M.QUESTS = {
    {id="q_conquer3",  name="三城太守", desc="占领3座城池",
     icon="slgIconFortress", reward={gold=200, food=150},
     check=function(st)
         local count = 0
         for _, city in ipairs(WORLD_CITIES) do
             if st.cityData[city.id] and st.cityData[city.id].owner == "player" then count = count + 1 end
         end
         return count >= 3
     end},
    {id="q_conquer6",  name="六城霸主", desc="占领6座城池",
     icon="slgIconFortress", reward={gold=500, food=300},
     check=function(st)
         local count = 0
         for _, city in ipairs(WORLD_CITIES) do
             if st.cityData[city.id] and st.cityData[city.id].owner == "player" then count = count + 1 end
         end
         return count >= 6
     end},
    {id="q_conquer12", name="半壁江山", desc="占领12座城池",
     icon="slgIconCrown", reward={gold=1000, food=600},
     check=function(st)
         local count = 0
         for _, city in ipairs(WORLD_CITIES) do
             if st.cityData[city.id] and st.cityData[city.id].owner == "player" then count = count + 1 end
         end
         return count >= 12
     end},
    {id="q_heroes5",   name="求贤若渴", desc="拥有5位武将",
     icon="slgIconSword", reward={gold=300},
     check=function(st)
         local count = 0
         for _, city in ipairs(WORLD_CITIES) do
             local cd = st.cityData[city.id]
             if cd and cd.owner == "player" then count = count + #cd.heroes end
         end
         return count >= 5
     end},
    {id="q_heroes10",  name="群英荟萃", desc="拥有10位武将",
     icon="slgIconSword", reward={gold=600, food=300},
     check=function(st)
         local count = 0
         for _, city in ipairs(WORLD_CITIES) do
             local cd = st.cityData[city.id]
             if cd and cd.owner == "player" then count = count + #cd.heroes end
         end
         return count >= 10
     end},
    {id="q_gold2000",  name="富可敌国", desc="累计拥有2000金币",
     icon="slgIconGold", reward={food=500},
     check=function(st) return st.gold >= 2000 end},
    {id="q_build3",    name="基建先锋", desc="建造3个建筑",
     icon="slgIconBuild", reward={gold=200},
     check=function(st)
         local count = 0
         for _, city in ipairs(WORLD_CITIES) do
             local cd = st.cityData[city.id]
             if cd and cd.owner == "player" and cd.buildings then
                 for _, lv in pairs(cd.buildings) do
                     if lv > 0 then count = count + 1 end
                 end
             end
         end
         return count >= 3
     end},
    {id="q_strat3",    name="足智多谋", desc="成功使用3次计略",
     icon="slgIconScroll", reward={gold=250},
     check=function(st) return (st.questCounters and st.questCounters.stratSuccess or 0) >= 3 end},
    {id="q_win5",      name="常胜将军", desc="赢得5场战斗",
     icon="slgIconTrophy", reward={gold=400, food=200},
     check=function(st) return (st.questCounters and st.questCounters.battleWins or 0) >= 5 end},
    {id="q_turn20",    name="持久战", desc="坚持到第20回合",
     icon="slgIconTimer", reward={gold=300, food=200},
     check=function(st) return st.turn >= 20 end},
}

return M
