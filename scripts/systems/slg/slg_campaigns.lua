-- ============================================================================
-- slg/slg_campaigns.lua - 三国武灵传：历史剧本数据
-- 6个历史剧本，每个定义阵营/城池归属/武将分配/胜利条件
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 剧本列表
-- ============================================================================
-- 武将索引参考 (G_systems.lua HERO_CARDS):
--   原始40: 1~10 人, 11~22 地, 23~30 天, 31~36 神, 37~40 限定
--   扩展68: 41~56 人, 57~76 地, 77~100 天, 101~108 神
--
-- 城池 ID (slg_data.lua WORLD_CITIES):
--   1=邺城 2=兖州 3=洛阳 4=许昌 5=寿春 6=合肥
--   7=建业 8=吴郡 9=会稽 10=汉中 11=成都 12=白帝城
--   13=益州 14=襄阳 15=荆州 16=长沙
-- ============================================================================

M.CAMPAIGNS = {
    -- ================================================================
    -- 第一章: 黄巾之乱 (184年)
    -- ================================================================
    {
        id = "yellow_turban",
        name = "黄巾之乱",
        subtitle = "苍天已死 黄天当立",
        year = 184,
        desc = "汉灵帝中平元年，太平道张角率众起义，黄巾军席卷八州。朝廷急遣皇甫嵩、朱儁、卢植三路平叛，各地豪杰纷纷自募义兵。天下大乱的序幕由此拉开。",
        difficulty = 1,  -- 1~5
        unlockAfter = nil,  -- 初始解锁

        -- 参与阵营
        factions = {
            {
                id = "han",
                name = "汉室",
                desc = "大汉朝廷，遣将平叛",
                isPlayer = true,  -- 可选阵营
                cities = {3, 4, 1, 2},  -- 洛阳/许昌/邺城/兖州
                heroes = {
                    [3]  = {44, 43, 45},     -- 洛阳: 皇甫嵩/朱儁/卢植
                    [4]  = {47, 46},          -- 许昌: 何进/丁原
                    [1]  = {7, 8},            -- 邺城: 曹洪/李典
                    [2]  = {48, 49},          -- 兖州: 陶谦/孔融
                },
                gold = 60000, food = 40000,
                garrison = {[3]=12000, [4]=10000, [1]=8000, [2]=6000},
            },
            {
                id = "yellow_turban",
                name = "黄巾军",
                displayFaction = "qun",  -- 用群色显示
                desc = "太平道起义军",
                isPlayer = true,
                cities = {5, 6, 14, 15, 16},  -- 寿春/合肥/襄阳/荆州/长沙
                heroes = {
                    [5]  = {81, 82},          -- 寿春: 张角/张宝
                    [6]  = {83, 41},          -- 合肥: 张梁/管亥
                    [14] = {42},              -- 襄阳: 严白虎
                    [15] = {},
                    [16] = {},
                },
                gold = 25000, food = 18000,
                garrison = {[5]=6000, [6]=5000, [14]=4000, [15]=3000, [16]=2500},
            },
            {
                id = "xiliang",
                name = "西凉军",
                displayFaction = "qun",
                desc = "凉州军阀，伺机而动",
                isPlayer = false,
                cities = {10, 11},  -- 汉中/成都
                heroes = {
                    [10] = {88, 89},          -- 汉中: 马腾/韩遂
                    [11] = {91},              -- 成都: 刘璋
                },
                gold = 20000, food = 15000,
                garrison = {[10]=5000, [11]=4000},
            },
        },

        -- 未分配城池 (中立)
        neutralCities = {
            [7]  = {garrison=2500, heroes={}},    -- 建业
            [8]  = {garrison=2000, heroes={}},    -- 吴郡
            [9]  = {garrison=1500, heroes={}},    -- 会稽
            [12] = {garrison=2000, heroes={}},    -- 白帝城
            [13] = {garrison=1500, heroes={}},    -- 益州
        },

        -- 胜利条件
        victory = {
            type = "eliminate",  -- 消灭特定势力
            target = "yellow_turban",
            desc = "消灭黄巾军全部城池",
            altType = "cities",  -- 或占领N城
            altCount = 10,
        },

        -- AI 外交默认
        diplomacy = {
            yellow_turban = {relation = 10},
            xiliang = {relation = 40},
        },
    },

    -- ================================================================
    -- 第二章: 讨伐董卓 (190年)
    -- ================================================================
    {
        id = "dong_zhuo",
        name = "讨伐董卓",
        subtitle = "十八路诸侯会盟",
        year = 190,
        desc = "董卓废帝擅权，迁都长安，天怒人怨。曹操矫诏号召天下诸侯组成关东联军，盟主袁绍统领十八路大军西进讨贼。虎牢关前，三英战吕布。",
        difficulty = 2,
        unlockAfter = "yellow_turban",

        factions = {
            {
                id = "coalition",
                name = "关东联军",
                displayFaction = "wei",
                desc = "十八路诸侯讨董联盟",
                isPlayer = true,
                cities = {1, 2, 5, 6, 7},  -- 邺城/兖州/寿春/合肥/建业
                heroes = {
                    [1]  = {84, 86, 18, 19}, -- 邺城: 袁绍/淳于琼/文丑/颜良
                    [2]  = {101, 57, 59},    -- 兖州: 曹操/荀彧/程昱
                    [5]  = {85, 9},           -- 寿春: 袁术/张任
                    [6]  = {87, 10},          -- 合肥: 公孙瓒/纪灵
                    [7]  = {104, 1, 2},       -- 建业: 孙坚/程普/黄盖
                },
                gold = 70000, food = 50000,
                garrison = {[1]=10000, [2]=9000, [5]=7000, [6]=7000, [7]=8000},
            },
            {
                id = "dong_zhuo_army",
                name = "董卓军",
                displayFaction = "qun",
                desc = "挟天子以令天下",
                isPlayer = true,
                cities = {3, 4, 10, 14},  -- 洛阳/许昌/汉中/襄阳
                heroes = {
                    [3]  = {77, 78, 35},     -- 洛阳: 董卓/华雄/吕布
                    [4]  = {79, 80},          -- 许昌: 李傕/郭汜
                    [10] = {60},              -- 汉中: 贾诩
                    [14] = {55},              -- 襄阳: 蔡瑁
                },
                gold = 80000, food = 60000,
                garrison = {[3]=15000, [4]=10000, [10]=6000, [14]=6000},
            },
            {
                id = "south",
                name = "荆益势力",
                displayFaction = "qun",
                desc = "南方诸侯割据一方",
                isPlayer = false,
                cities = {15, 16, 11, 12, 13},
                heroes = {
                    [15] = {90, 56},          -- 荆州: 刘表/文聘
                    [16] = {},
                    [11] = {91},              -- 成都: 刘璋
                    [12] = {92},              -- 白帝城: 张鲁
                    [13] = {},
                },
                gold = 40000, food = 30000,
                garrison = {[15]=7000, [16]=4000, [11]=6000, [12]=5000, [13]=3000},
            },
        },

        neutralCities = {
            [8]  = {garrison=3000, heroes={}},
            [9]  = {garrison=2000, heroes={}},
        },

        victory = {
            type = "eliminate",
            target = "dong_zhuo_army",
            desc = "攻破洛阳 铲除董卓",
            altType = "cities",
            altCount = 10,
        },

        diplomacy = {
            dong_zhuo_army = {relation = 5},
            south = {relation = 35},
        },
    },

    -- ================================================================
    -- 第三章: 群雄割据 (196年)
    -- ================================================================
    {
        id = "warlords",
        name = "群雄割据",
        subtitle = "逐鹿中原 谁主沉浮",
        year = 196,
        desc = "董卓已灭，但天下更乱。曹操奉天子都许昌，挟天子以令诸侯。袁绍雄踞河北四州，天下最强。刘备寄人篱下，孙策横扫江东。群雄并起，大争之世。",
        difficulty = 3,
        unlockAfter = "dong_zhuo",

        factions = {
            {
                id = "cao_cao",
                name = "曹操",
                displayFaction = "wei",
                desc = "奉天子以令不臣",
                isPlayer = true,
                cities = {4, 2, 3},  -- 许昌/兖州/洛阳
                heroes = {
                    [4]  = {101, 57, 58},    -- 许昌: 曹操/荀彧/荀攸
                    [2]  = {59, 61, 62},     -- 兖州: 程昱/于禁/乐进
                    [3]  = {63, 64, 23},     -- 洛阳: 曹仁/满宠/典韦
                },
                gold = 60000, food = 40000,
                garrison = {[4]=10000, [2]=8000, [3]=9000},
            },
            {
                id = "yuan_shao",
                name = "袁绍",
                displayFaction = "qun",
                desc = "四世三公 雄踞河北",
                isPlayer = true,
                cities = {1, 5},  -- 邺城/寿春
                heroes = {
                    [1]  = {84, 86, 18, 19}, -- 邺城: 袁绍/淳于琼/文丑/颜良
                    [5]  = {17},              -- 寿春: 高顺
                },
                gold = 70000, food = 50000,
                garrison = {[1]=12000, [5]=7000},
            },
            {
                id = "liu_bei",
                name = "刘备",
                displayFaction = "shu",
                desc = "汉室宗亲 仁义之师",
                isPlayer = true,
                cities = {14},  -- 襄阳
                heroes = {
                    [14] = {102, 32, 33, 4}, -- 襄阳: 刘备/张飞/关羽/廖化
                },
                gold = 30000, food = 20000,
                garrison = {[14]=8000},
            },
            {
                id = "sun_ce",
                name = "孙策",
                displayFaction = "wu",
                desc = "小霸王横扫江东",
                isPlayer = true,
                cities = {7, 8},  -- 建业/吴郡
                heroes = {
                    [7]  = {25, 34, 1},      -- 建业: 孙策/周瑜/程普
                    [8]  = {2, 3, 73},        -- 吴郡: 黄盖/韩当/鲁肃
                },
                gold = 50000, food = 35000,
                garrison = {[7]=9000, [8]=7000},
            },
            {
                id = "others",
                name = "诸侯",
                displayFaction = "qun",
                desc = "各方割据势力",
                isPlayer = false,
                cities = {6, 9, 10, 11, 12, 13, 15, 16},
                heroes = {
                    [6]  = {85},              -- 合肥: 袁术
                    [9]  = {},                -- 会稽
                    [10] = {92},              -- 汉中: 张鲁
                    [11] = {91},              -- 成都: 刘璋
                    [12] = {},                -- 白帝城
                    [13] = {},                -- 益州
                    [15] = {90, 55, 56},      -- 荆州: 刘表/蔡瑁/文聘
                    [16] = {},                -- 长沙
                },
                gold = 50000, food = 40000,
                garrison = {[6]=6000, [9]=3000, [10]=5000, [11]=6000, [12]=4000, [13]=3000, [15]=7000, [16]=4000},
            },
        },

        neutralCities = {},

        victory = {
            type = "cities",
            count = 12,
            desc = "占领12座城池 称霸中原",
        },

        diplomacy = {},
    },

    -- ================================================================
    -- 第四章: 官渡之战 (200年)
    -- ================================================================
    {
        id = "guandu",
        name = "官渡之战",
        subtitle = "以少胜多 奠定北方",
        year = 200,
        desc = "建安五年，袁绍率精兵十万南下，曹操以两万兵力据守官渡。许攸献计火烧乌巢，袁军粮草尽毁，曹操一举破敌。此战奠定了曹魏的霸业基础。",
        difficulty = 3,
        unlockAfter = "warlords",

        factions = {
            {
                id = "cao_cao",
                name = "曹操",
                displayFaction = "wei",
                desc = "背水一战 以少胜多",
                isPlayer = true,
                cities = {4, 2, 3, 6},  -- 许昌/兖州/洛阳/合肥
                heroes = {
                    [4]  = {101, 57, 58, 60}, -- 许昌: 曹操/荀彧/荀攸/贾诩
                    [2]  = {59, 61, 62, 30},  -- 兖州: 程昱/于禁/乐进/张辽
                    [3]  = {63, 64, 13, 14},  -- 洛阳: 曹仁/满宠/徐晃/张郃
                    [6]  = {23, 24},           -- 合肥: 典韦/许褚
                },
                gold = 50000, food = 30000,  -- 曹操粮草吃紧
                garrison = {[4]=8000, [2]=7000, [3]=8000, [6]=6000},
            },
            {
                id = "yuan_shao",
                name = "袁绍",
                displayFaction = "qun",
                desc = "兵多将广 势如破竹",
                isPlayer = true,
                cities = {1, 5},  -- 邺城/寿春
                heroes = {
                    [1]  = {84, 86, 18, 19, 17}, -- 邺城: 袁绍/淳于琼/文丑/颜良/高顺
                    [5]  = {85},                   -- 寿春: 袁术
                },
                gold = 90000, food = 70000,  -- 袁绍粮草充足
                garrison = {[1]=16000, [5]=8000},
            },
            {
                id = "liu_bei",
                name = "刘备",
                displayFaction = "shu",
                desc = "新得荆州 图谋巴蜀",
                isPlayer = true,
                cities = {14, 15},  -- 襄阳/荆州
                heroes = {
                    [14] = {102, 32, 33, 108}, -- 襄阳: 刘备/张飞/关羽/徐庶
                    [15] = {4, 5, 6},           -- 荆州: 廖化/周仓/糜竺
                },
                gold = 40000, food = 30000,
                garrison = {[14]=8000, [15]=6000},
            },
            {
                id = "sun_quan",
                name = "孙权",
                displayFaction = "wu",
                desc = "承父兄基业 坐断东南",
                isPlayer = true,
                cities = {7, 8, 9},  -- 建业/吴郡/会稽
                heroes = {
                    [7]  = {103, 34, 73},     -- 建业: 孙权/周瑜/鲁肃
                    [8]  = {74, 11, 12},       -- 吴郡: 吕蒙/太史慈/甘宁
                    [9]  = {1, 2, 3},          -- 会稽: 程普/黄盖/韩当
                },
                gold = 55000, food = 40000,
                garrison = {[7]=9000, [8]=8000, [9]=6000},
            },
            {
                id = "others",
                name = "诸侯",
                displayFaction = "qun",
                desc = "各方割据",
                isPlayer = false,
                cities = {10, 11, 12, 13, 16},
                heroes = {
                    [10] = {92, 88},           -- 汉中: 张鲁/马腾
                    [11] = {91},               -- 成都: 刘璋
                    [12] = {},                 -- 白帝城
                    [13] = {},                 -- 益州
                    [16] = {90},               -- 长沙: 刘表
                },
                gold = 40000, food = 30000,
                garrison = {[10]=6000, [11]=6000, [12]=4000, [13]=3000, [16]=5000},
            },
        },

        neutralCities = {},

        victory = {
            type = "eliminate",
            target = "yuan_shao",
            desc = "击败袁绍 统一北方",
            altType = "cities",
            altCount = 10,
        },

        diplomacy = {
            yuan_shao = {relation = 5},
            others = {relation = 30},
        },
    },

    -- ================================================================
    -- 第五章: 赤壁之战 (208年)
    -- ================================================================
    {
        id = "chibi",
        name = "赤壁之战",
        subtitle = "火烧连环 天下三分",
        year = 208,
        desc = "曹操统一北方后率八十万大军南征。孙刘联军在赤壁以火攻大破曹军。诸葛亮借东风，周瑜施连环，一把大火烧尽曹操统一天下的美梦。从此三足鼎立。",
        difficulty = 4,
        unlockAfter = "guandu",

        factions = {
            {
                id = "cao_cao",
                name = "曹操",
                displayFaction = "wei",
                desc = "八十万大军 南征荆州",
                isPlayer = true,
                cities = {1, 2, 3, 4, 5, 6, 14},  -- 北方七城
                heroes = {
                    [1]  = {20, 21},              -- 邺城: 邓艾/钟会
                    [2]  = {59, 61, 62},           -- 兖州: 程昱/于禁/乐进
                    [3]  = {63, 64, 13},           -- 洛阳: 曹仁/满宠/徐晃
                    [4]  = {101, 57, 58, 105},     -- 许昌: 曹操/荀彧/荀攸/司马懿
                    [5]  = {14, 30},               -- 寿春: 张郃/张辽
                    [6]  = {23, 24, 7, 8},         -- 合肥: 典韦/许褚/曹洪/李典
                    [14] = {55, 56, 60},           -- 襄阳: 蔡瑁/文聘/贾诩
                },
                gold = 100000, food = 80000,
                garrison = {[1]=8000, [2]=8000, [3]=9000, [4]=10000, [5]=8000, [6]=10000, [14]=9000},
            },
            {
                id = "sun_liu",
                name = "孙刘联军",
                displayFaction = "wu",
                desc = "联手抗曹 保全江东",
                isPlayer = true,
                cities = {7, 8, 9, 15, 16},  -- 江东+荆南
                heroes = {
                    [7]  = {103, 34, 73},         -- 建业: 孙权/周瑜/鲁肃
                    [8]  = {74, 11, 75, 76},       -- 吴郡: 吕蒙/太史慈/丁奉/徐盛
                    [9]  = {94, 95, 22},           -- 会稽: 凌统/蒋钦/陆抗
                    [15] = {102, 36, 32, 33},      -- 荆州: 刘备/诸葛亮/张飞/关羽
                    [16] = {31, 4, 5},             -- 长沙: 赵云/廖化/周仓
                },
                gold = 60000, food = 45000,
                garrison = {[7]=9000, [8]=8000, [9]=6000, [15]=8000, [16]=7000},
            },
            {
                id = "yi_zhou",
                name = "益州",
                displayFaction = "qun",
                desc = "刘璋暗弱 益州富庶",
                isPlayer = false,
                cities = {10, 11, 12, 13},
                heroes = {
                    [10] = {92},                   -- 汉中: 张鲁
                    [11] = {91, 68, 53},           -- 成都: 刘璋/严颜/吴懿
                    [12] = {},                     -- 白帝城
                    [13] = {93},                   -- 益州: 孟获
                },
                gold = 50000, food = 40000,
                garrison = {[10]=6000, [11]=7000, [12]=4000, [13]=3000},
            },
        },

        neutralCities = {},

        victory = {
            type = "cities",
            count = 12,
            desc = "占领12座城池 奠定霸业",
        },

        diplomacy = {
            yi_zhou = {relation = 35},
        },
    },

    -- ================================================================
    -- 第六章: 三国鼎立 (220年)
    -- ================================================================
    {
        id = "three_kingdoms",
        name = "三国鼎立",
        subtitle = "一统天下 终结乱世",
        year = 220,
        desc = "曹丕篡汉称帝，刘备据蜀称帝，孙权据吴称帝，天下三分。三国各怀统一大志，最终鹿死谁手？这是三国故事的终章，也是英雄们最后的舞台。",
        difficulty = 5,
        unlockAfter = "chibi",

        factions = {
            {
                id = "wei",
                name = "魏国",
                displayFaction = "wei",
                desc = "国力最强 占据中原",
                isPlayer = true,
                cities = {1, 2, 3, 4, 5, 6},  -- 北方六城
                heroes = {
                    [1]  = {105, 20, 21},         -- 邺城: 司马懿/邓艾/钟会
                    [2]  = {59, 61, 62},           -- 兖州: 程昱/于禁/乐进
                    [3]  = {63, 64, 13, 14},       -- 洛阳: 曹仁/满宠/徐晃/张郃
                    [4]  = {101, 57, 58, 60},      -- 许昌: 曹操/荀彧/荀攸/贾诩
                    [5]  = {30, 23},               -- 寿春: 张辽/典韦
                    [6]  = {24, 7, 8},             -- 合肥: 许褚/曹洪/李典
                },
                gold = 80000, food = 60000,
                garrison = {[1]=10000, [2]=8000, [3]=9000, [4]=10000, [5]=8000, [6]=9000},
            },
            {
                id = "shu",
                name = "蜀国",
                displayFaction = "shu",
                desc = "兴复汉室 还于旧都",
                isPlayer = true,
                cities = {10, 11, 12, 13, 14},  -- 蜀地+襄阳
                heroes = {
                    [10] = {29, 106, 72},          -- 汉中: 黄忠/黄忠·定军山/王平
                    [11] = {102, 36, 65, 66},      -- 成都: 刘备/诸葛亮/庞统/法正
                    [12] = {32, 70, 71},           -- 白帝城: 张飞/张苞/刘封
                    [13] = {50, 51, 52},           -- 益州: 刘巴/费祎/蒋琬
                    [14] = {33, 15, 4, 69},        -- 襄阳: 关羽/魏延/廖化/马良
                },
                gold = 60000, food = 45000,
                garrison = {[10]=8000, [11]=9000, [12]=7000, [13]=6000, [14]=8000},
            },
            {
                id = "wu",
                name = "吴国",
                displayFaction = "wu",
                desc = "坐断东南 水师天下",
                isPlayer = true,
                cities = {7, 8, 9, 15, 16},  -- 江东+荆南
                heroes = {
                    [7]  = {103, 73, 74},          -- 建业: 孙权/鲁肃/吕蒙
                    [8]  = {11, 75, 76},           -- 吴郡: 太史慈/丁奉/徐盛
                    [9]  = {94, 95, 22},           -- 会稽: 凌统/蒋钦/陆抗
                    [15] = {34, 96, 97},           -- 荆州: 周瑜/朱然/潘璋
                    [16] = {107, 98, 12},          -- 长沙: 甘宁·百骑/步骘/甘宁
                },
                gold = 65000, food = 50000,
                garrison = {[7]=9000, [8]=8000, [9]=6000, [15]=8000, [16]=7000},
            },
        },

        neutralCities = {},

        victory = {
            type = "cities",
            count = 14,
            desc = "占领14座城池 一统天下",
        },

        diplomacy = {},
    },
}

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 获取剧本列表 (用于UI显示)
--- @return table[] campaigns {id, name, subtitle, year, difficulty, unlockAfter, desc}
function M.GetCampaignList()
    local list = {}
    for _, c in ipairs(M.CAMPAIGNS) do
        table.insert(list, {
            id = c.id,
            name = c.name,
            subtitle = c.subtitle,
            year = c.year,
            difficulty = c.difficulty,
            unlockAfter = c.unlockAfter,
            desc = c.desc,
        })
    end
    return list
end

--- 根据ID获取剧本数据
--- @param campaignId string
--- @return table|nil campaign
function M.GetCampaign(campaignId)
    for _, c in ipairs(M.CAMPAIGNS) do
        if c.id == campaignId then return c end
    end
    return nil
end

--- 获取剧本中玩家可选的阵营列表
--- @param campaignId string
--- @return table[] factions {id, name, desc, cities}
function M.GetPlayableFactions(campaignId)
    local campaign = M.GetCampaign(campaignId)
    if not campaign then return {} end
    local result = {}
    for _, fac in ipairs(campaign.factions) do
        if fac.isPlayer then
            table.insert(result, {
                id = fac.id,
                name = fac.name,
                desc = fac.desc,
                cityCount = #fac.cities,
                heroCount = 0,  -- 懒计算
                displayFaction = fac.displayFaction or fac.id,
            })
            -- 计算武将数
            local count = 0
            for _, heroes in pairs(fac.heroes) do
                count = count + #heroes
            end
            result[#result].heroCount = count
        end
    end
    return result
end

--- 检查剧本是否解锁
--- @param campaignId string
--- @param completedCampaigns table 已完成的剧本ID集合 {["yellow_turban"]=true, ...}
--- @return boolean
function M.IsCampaignUnlocked(campaignId, completedCampaigns)
    local campaign = M.GetCampaign(campaignId)
    if not campaign then return false end
    if not campaign.unlockAfter then return true end  -- 无前置条件
    return completedCampaigns[campaign.unlockAfter] == true
end

--- 根据剧本和阵营选择初始化游戏状态
--- @param campaignId string 剧本ID
--- @param factionId string 玩家选择的阵营ID
--- @return boolean success
--- @return string? error
function M.ApplyCampaign(campaignId, factionId)
    local campaign = M.GetCampaign(campaignId)
    if not campaign then return false, "剧本不存在" end

    local st = worldMapState

    -- 找到玩家阵营数据
    local playerFac = nil
    for _, fac in ipairs(campaign.factions) do
        if fac.id == factionId then
            playerFac = fac
            break
        end
    end
    if not playerFac then return false, "阵营不存在" end

    -- 重置状态
    st.turn = 1
    st.gold = playerFac.gold or 50000
    st.food = playerFac.food or 30000
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
    st.selectedFormation = "fish_scale"
    st.selectedTactic = nil
    st.formationBtns = {}
    st.tacticBtns = {}
    st.lastBattleReward = nil
    st.conquestRewardGiven = false
    st.heroPopup = nil
    st.mapPanelHeroScroll = 0
    st.leftPanelCollapsed = false
    st.rightPanelCollapsed = true
    st.mapCenterX = 512
    st.mapCenterY = 285
    st.mapZoom = 1.0

    -- 记录当前剧本信息
    st.campaignId = campaignId
    st.campaignFaction = factionId
    st.playerFaction = playerFac.displayFaction or factionId

    -- 外交
    st.diplomacy = {}
    for _, fac in ipairs(campaign.factions) do
        if fac.id ~= factionId then
            local rel = 25
            if campaign.diplomacy and campaign.diplomacy[fac.id] then
                rel = campaign.diplomacy[fac.id].relation or 25
            end
            st.diplomacy[fac.id] = { relation = rel, treaty = nil }
        end
    end

    -- 初始化所有城池 (先设中立)
    for _, city in ipairs(WORLD_CITIES) do
        st.cityData[city.id] = {
            owner = "neutral",
            garrison = 3000,
            level = math.max(1, city.def - 1),
            heroes = {},
            morale = 60,
        }
    end

    -- 中立城池覆盖
    if campaign.neutralCities then
        for cityId, data in pairs(campaign.neutralCities) do
            local cd = st.cityData[cityId]
            if cd then
                cd.owner = "neutral"
                cd.garrison = data.garrison or 3000
                cd.heroes = data.heroes or {}
            end
        end
    end

    -- 为自定义阵营注册FC颜色 (使用 displayFaction 映射)
    local Data = require("systems.slg.slg_data")
    for _, fac in ipairs(campaign.factions) do
        if fac.id ~= factionId and not Data.FC[fac.id] then
            local base = fac.displayFaction or "qun"
            if Data.FC[base] then
                Data.FC[fac.id] = Data.FC[base]
            end
        end
    end

    -- 各阵营城池分配
    for _, fac in ipairs(campaign.factions) do
        local ownerTag = (fac.id == factionId) and "player" or fac.id
        for _, cityId in ipairs(fac.cities) do
            local cd = st.cityData[cityId]
            if cd then
                cd.owner = ownerTag
                cd.garrison = (fac.garrison and fac.garrison[cityId]) or (6000 + (WORLD_CITIES[cityId] and WORLD_CITIES[cityId].def or 2) * 2000)
                cd.level = WORLD_CITIES[cityId] and math.max(2, WORLD_CITIES[cityId].def) or 2
                cd.morale = (ownerTag == "player") and 90 or 80
                cd.heroes = (fac.heroes and fac.heroes[cityId]) or {}
            end
        end
    end

    -- 记录起始城 (玩家第一座城)
    if playerFac.cities and #playerFac.cities > 0 then
        st.startCityId = playerFac.cities[1]
    end

    -- 胜利条件
    st.victoryCondition = campaign.victory

    st.inited = true
    print("[Campaign] Started: " .. campaign.name .. " as " .. playerFac.name)

    return true
end

--- 检查胜利条件
--- @return boolean won
--- @return string? message
function M.CheckVictory()
    local st = worldMapState
    local vc = st.victoryCondition
    if not vc then return false end

    if vc.type == "cities" then
        local count = 0
        for _, city in ipairs(WORLD_CITIES) do
            if st.cityData[city.id] and st.cityData[city.id].owner == "player" then
                count = count + 1
            end
        end
        if count >= (vc.count or 16) then
            return true, vc.desc or "胜利!"
        end
    elseif vc.type == "eliminate" then
        local target = vc.target
        local targetAlive = false
        for _, city in ipairs(WORLD_CITIES) do
            if st.cityData[city.id] and st.cityData[city.id].owner == target then
                targetAlive = true
                break
            end
        end
        if not targetAlive then
            return true, vc.desc or "胜利!"
        end
        -- 检查备选条件
        if vc.altType == "cities" then
            local count = 0
            for _, city in ipairs(WORLD_CITIES) do
                if st.cityData[city.id] and st.cityData[city.id].owner == "player" then
                    count = count + 1
                end
            end
            if count >= (vc.altCount or 16) then
                return true, vc.desc or "胜利!"
            end
        end
    end

    return false
end

return M
