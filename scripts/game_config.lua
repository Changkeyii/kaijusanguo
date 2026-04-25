-- ============================================================================
-- 游戏配置文件 (所有可调数值集中在此)
-- 直接修改下方数值即可调整游戏平衡，无需改动其他代码
-- ============================================================================

local Config = {}

-- ============================================================================
-- 命座系统 (C0 ~ C6)
-- 合成规则: 2张同角色同命座 → 1张下一命座
-- 达到C6理论需要 2^6 = 64 张基础卡
-- ============================================================================
Config.MAX_CONSTELLATION = 6

Config.CONSTELLATION_BONUS = {
    [0] = { atkMult = 1.00, defMult = 1.00, hpMult = 1.00, breakDmgAdd = 0, spawnRateMult = 1.00 },
    [1] = { atkMult = 1.08, defMult = 1.06, hpMult = 1.08, breakDmgAdd = 0, spawnRateMult = 1.00 },
    [2] = { atkMult = 1.18, defMult = 1.14, hpMult = 1.18, breakDmgAdd = 0, spawnRateMult = 1.02 },
    [3] = { atkMult = 1.30, defMult = 1.22, hpMult = 1.30, breakDmgAdd = 1, spawnRateMult = 1.05 },
    [4] = { atkMult = 1.44, defMult = 1.32, hpMult = 1.44, breakDmgAdd = 1, spawnRateMult = 1.08 },
    [5] = { atkMult = 1.60, defMult = 1.44, hpMult = 1.60, breakDmgAdd = 1, spawnRateMult = 1.12 },
    [6] = { atkMult = 1.60, defMult = 1.45, hpMult = 1.55, breakDmgAdd = 1.5, spawnRateMult = 1.10 },
}

Config.CONSTELLATION_COLORS = {
    [0] = { 180, 175, 165 },
    [1] = { 120, 220, 160 },
    [2] = { 80,  170, 240 },
    [3] = { 180, 120, 255 },
    [4] = { 255, 160, 60  },
    [5] = { 255, 80,  80  },
    [6] = { 255, 220, 80  },
}

-- ============================================================================
-- 抽卡系统
-- ============================================================================

-- 单卡品质抽取概率 (百分比, 总和必须为100)
Config.DRAW_QUALITY_WEIGHTS = {
    [1] = 55,   -- N (COMMON)   55%
    [2] = 28,   -- R (RARE)     28%
    [3] = 14,   -- SR (EPIC)    14%
    [4] = 3,    -- SSR (LEGENDARY) 3%
}

-- 重复满命座角色转化玉壁
Config.DUPLICATE_JADE_REWARD = {
    [1] = 3,    -- N  → 3 玉壁
    [2] = 10,   -- R  → 10 玉壁
    [3] = 25,   -- SR → 25 玉壁
    [4] = 100,  -- SSR → 100 玉壁
}

-- 保底机制
Config.PITY_SSR_COUNT = 70   -- 70次保底SSR

-- 抽卡费用 (玉壁)
Config.GACHA_COST_SINGLE = 25     -- 单抽费用
Config.GACHA_COST_TEN    = 220    -- 十连费用
Config.INITIAL_JADE      = 100000 -- 初始玉壁
Config.JADE_PER_WIN_MIN  = 45     -- 胜利玉壁最小值 (×10)
Config.JADE_PER_WIN_MAX  = 75     -- 胜利玉壁最大值 (×10)
Config.JADE_PER_LOSE     = 4      -- 失败获得玉壁

-- ============================================================================
-- 广告激励配置
-- ============================================================================
Config.AD_JADE_MIN       = 12     -- 广告奖励玉壁最小值
Config.AD_JADE_MAX       = 45     -- 广告奖励玉壁最大值
Config.AD_FREE_REFRESH   = true   -- 广告免费刷新商店
Config.AD_REVIVE_BONUS_JADE = 20  -- 失败后看广告额外玉壁


-- ============================================================================
-- 初始拥有的武灵 (开局自带)
-- ============================================================================
-- 战争版: 初始8武将 (各阵营均衡2人)
Config.INITIAL_HEROES = {
    4,   -- 廖化  (蜀/步兵/N)
    6,   -- 糜竺  (蜀/弓兵-治/N)
    1,   -- 程普  (吴/枪兵/N)
    3,   -- 韩当  (吴/弓兵/N)
    7,   -- 曹洪  (魏/步兵-盾/N)
    8,   -- 李典  (魏/步兵/N)
    9,   -- 张任  (群/弓兵/N)
    10,  -- 纪灵  (群/枪兵/N)
}

-- ============================================================================
-- 战斗参数
-- ============================================================================
Config.BASE_HP_MAX     = 100   -- 双方营寨最大血量
Config.LEVEL_GROWTH_RATE = 0.05  -- 每级属性成长率 (降低防溢出, lv4=1.15x)

-- 士兵属性公式: 最终 = 保底值 + 武将属性 * 加成系数
-- 设计目标: 武将基础属性最高100, 士兵属性由武将属性加成
-- v3: ATK 基础值已融入旧 GLOBAL_DAMAGE_MULT(0.35), HP/DEF 不变以保持耐久
Config.SOLDIER_BASE_HP  = 20      -- 士兵保底血量
Config.SOLDIER_BASE_ATK = 5       -- 士兵保底攻击 (旧15 × 0.35 ≈ 5)
Config.SOLDIER_BASE_DEF = 18      -- 士兵保底防御
Config.SOLDIER_HP_SCALE  = 1.3    -- 武将HP→士兵HP
Config.SOLDIER_ATK_SCALE = 0.35   -- 武将ATK→士兵ATK (旧1.0 × 0.35)
Config.SOLDIER_DEF_SCALE = 1.1    -- 武将DEF→士兵DEF

Config.SHOP_SIZE    = 4        -- 商店展示卡牌数

-- 战斗时限 (秒)
Config.BATTLE_TIME_LIMIT = 120

-- ============================================================================
-- 背包/UI 参数
-- ============================================================================
Config.INVENTORY_VISIBLE = 4

-- ============================================================================
-- 玩家信息
-- ============================================================================
Config.PLAYER_REALMS = { "黄巾", "校尉", "偏将", "都督", "大将军" }
Config.REALM_LAYERS  = 10
Config.CHINESE_NUMS  = { "一", "二", "三", "四", "五", "六", "七", "八", "九", "十" }

-- 50级累计经验阈值 (rankIdx 1~50)
Config.RANK_EXP_TABLE = {
    -- 黄巾 一~十层
    0,    30,   70,   120,  180,  250,  330,  420,  520,  630,
    -- 校尉 一~十层
    760,  900,  1060, 1240, 1440, 1660, 1900, 2160, 2440, 2740,
    -- 偏将 一~十层
    3060, 3400, 3770, 4170, 4600, 5060, 5550, 6070, 6620, 7200,
    -- 都督 一~十层
    7820, 8480, 9180, 9920, 10700, 11520, 12380, 13280, 14220, 15200,
    -- 大将军 一~十层
    16230, 17310, 18440, 19620, 20850, 22130, 23460, 24840, 26270, 27750,
}
Config.EXP_PER_WIN = 28
Config.EXP_PER_LOSE = 9

-- ============================================================================
-- 搜打撤 探索系统
-- ============================================================================

-- 每个征战关卡对应的格子大小 (30关)
Config.STAGE_GRID_SIZES = {
    -- 第1页: 黄巾之乱 (4-5)
    4, 4, 4, 4, 4, 5, 5, 5, 5, 5,
    -- 第2页: 三分天下 (5-6)
    5, 5, 5, 6, 6, 6, 6, 6, 7, 7,
    -- 第3页: 天下归一 (7-8)
    7, 7, 7, 7, 8, 8, 8, 8, 8, 8,
}

-- 每个征战关卡的基础爆率 (30关)
Config.STAGE_DROP_RATES = {
    -- 第1页
    0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19,
    -- 第2页
    0.19, 0.20, 0.21, 0.22, 0.23, 0.24, 0.25, 0.26, 0.27, 0.28,
    -- 第3页
    0.28, 0.29, 0.29, 0.30, 0.30, 0.31, 0.31, 0.32, 0.32, 0.32,
}

-- 宝箱掉落表 (按格子大小) — 玉壁略降15%
Config.EXPLORATION_DROP_RATES = {
    [4] = { equipment = 0.08, jade_min = 7,   jade_max = 14,  frag = 1 },
    [5] = { equipment = 0.13, jade_min = 9,   jade_max = 15,  frag = 2 },
    [6] = { equipment = 0.20, jade_min = 11,  jade_max = 17,  frag = 3 },
    [7] = { equipment = 0.25, jade_min = 12,  jade_max = 19,  frag = 3 },
    [8] = { equipment = 0.30, jade_min = 14,  jade_max = 20,  frag = 4 },
}

-- 撤离战利品保留比例
Config.LOOT_RETAIN_RETREAT = 1.0   -- 到达撤离点: 100%
Config.LOOT_RETAIN_ABANDON = 0.0   -- 提前退出: 0% (必须撤离才有收益)

-- 事件格权重 (10种随机事件)
Config.EXPLORATION_EVENTS = {
    { type = "heal",      weight = 20, desc = "发现灵泉妙药",     effect = "hp_bonus" },
    { type = "buff",      weight = 14, desc = "获得军师祝福",     effect = "atk_bonus" },
    { type = "trap",      weight = 18, desc = "触发埋伏!",        effect = "lose_loot" },
    { type = "debuff",    weight = 10, desc = "遭遇敌军诡计",     effect = "enemy_buff" },
    { type = "shop",      weight = 10, desc = "遇到行商旅人",     effect = "shop" },
    { type = "blacksmith",weight = 8,  desc = "路遇铁匠铺",       effect = "enhance" },
    { type = "gamble",    weight = 6,  desc = "赌坊试手气",       effect = "gamble" },
    { type = "ambush",    weight = 5,  desc = "精锐伏兵!",        effect = "elite_fight" },
    { type = "relic",     weight = 5,  desc = "发现古战场遗迹",   effect = "relic" },
    { type = "supply",    weight = 4,  desc = "截获军粮辎重",     effect = "supply" },
    { type = "adventure",weight = 8,  desc = "奇遇·仙人指路",   effect = "adventure" },
    { type = "gift",     weight = 6,  desc = "路遇贵人相助",     effect = "gift" },
    { type = "scam",     weight = 7,  desc = "遭遇江湖骗子!",    effect = "scam" },
    { type = "mystery",  weight = 5,  desc = "神秘宝匣",         effect = "mystery" },
}
-- 商人价格
Config.EXPLORE_SHOP_COST = 40

-- 格子密度参数
Config.ENEMY_DENSITY  = { [4] = 0.19, [5] = 0.20, [6] = 0.19, [7] = 0.18, [8] = 0.17 }
Config.BLOCKED_RATIO  = 0.08
Config.EVENT_RATIO    = 0.10
Config.MAX_CHESTS     = 5
Config.CHEST_GUARD_CHANCE = 0.6

-- 战斗胜利掉落 (探索内战斗额外掉落) — 略降
Config.EXPLORE_BATTLE_JADE_MIN = 1
Config.EXPLORE_BATTLE_JADE_MAX = 5
Config.EXPLORE_BATTLE_FRAG_CHANCE = 0.25

-- 武技总数
Config.TOTAL_SKILL_COUNT = 36

-- ============================================================================
-- 探索资源副本 (遭遇战模式)
-- ============================================================================
Config.RESOURCE_DUNGEON = {
    gridSize = 7,           -- 7×7=49格
    entryCost = 270,        -- 门票270玉壁
    encounterRate = 0.30,   -- 空格遭遇战触发率30%
    eventRatio = 0.18,      -- 事件格比例提高到18% (更多机遇)
    chestCount = 8,         -- 宝箱增加到8个
    blockedRatio = 0.06,    -- 阻挡格减少 (更多探索空间)
    enemyDensity = 0.10,    -- 固定敌人减少 (改为遭遇战)
    chestGuardChance = 0.4, -- 宝箱看守概率降低

    -- 三种副本类型
    types = {
        {
            id = "equip",
            name = "兵甲探索",
            desc = "搜寻稀有兵甲装备",
            icon = "equip",  -- 图标标识
            color = { 220, 160, 60 },
            -- 产出控制: 装备为主, 碎片减少
            dropRateBonus = 0.15,       -- 装备爆率+15%
            fragMultiplier = 0.5,       -- 碎片产出减半
            jadeMultiplier = 0.8,       -- 玉壁产出略降
            maxTier = 6,                -- 最高帝品
            highTierMultiplier = 1,     -- 高品级概率正常 (0.5% 帝品)
        },
        {
            id = "seal",
            name = "咒印探索",
            desc = "探寻强力咒印符文",
            icon = "seal",
            color = { 160, 100, 255 },
            -- 产出控制: 咒印/符文为主 (用碎片代表)
            dropRateBonus = 0.05,
            fragMultiplier = 2.0,       -- 碎片产出翻倍
            jadeMultiplier = 0.7,
            maxTier = 5,                -- 最高王品
            highTierMultiplier = 1,
        },
        {
            id = "skill",
            name = "残片探索",
            desc = "收集武技残片精华",
            icon = "skill",
            color = { 80, 200, 160 },
            -- 产出控制: 武技碎片为主
            dropRateBonus = 0.0,
            fragMultiplier = 3.0,       -- 碎片产出三倍
            jadeMultiplier = 0.6,
            maxTier = 4,                -- 最高将品
            highTierMultiplier = 1,
        },
    },

    -- 遭遇战掉落 (比普通战斗掉落略好)
    encounterBattleJadeMin = 3,
    encounterBattleJadeMax = 8,
    encounterBattleFragChance = 0.35,

    -- 遭遇战专属事件 (踩到空格触发)
    encounterEvents = {
        { type = "battle",    weight = 50, desc = "遭遇敌军巡逻队!" },
        { type = "ambush",    weight = 15, desc = "遭遇精锐伏兵!" },
        { type = "treasure",  weight = 20, desc = "发现隐藏宝物!" },
        { type = "nothing",   weight = 15, desc = "虚惊一场..." },
    },
}

-- ============================================================================
-- 战令通行证 (Battle Pass)
-- 30级, 普通+高级双轨奖励, 任务驱动升级
-- ============================================================================
Config.BATTLE_PASS = {
    maxLevel = 50,
    -- 每级所需经验 (累进递增)
    expPerLevel = {
        100,  120,  140,  160,  180,  200,  220,  250,  280,  320,   -- Lv1-10
        360,  400,  440,  480,  520,  560,  600,  650,  700,  760,   -- Lv11-20
        820,  880,  940, 1000, 1060, 1120, 1200, 1300, 1400, 1500,   -- Lv21-30
        1600, 1700, 1800, 1900, 2000, 2100, 2200, 2350, 2500, 2700, -- Lv31-40
        2900, 3100, 3300, 3500, 3700, 3900, 4100, 4400, 4700, 5000, -- Lv41-50
    },

    -- 普通奖励 (免费轨道) — 玉壁×3，每5级一个可观奖品，其余小奖
    freeRewards = {
        { jade = 60 },                                           -- Lv1  小奖 (20×3)
        { frag = 1 },                                            -- Lv2  小奖
        { jade = 90 },                                           -- Lv3  小奖 (30×3)
        { frag = 1 },                                            -- Lv4  小奖
        { jade = 900, equipDrop = 1, equipTier = 2 },            -- Lv5  ★可观: 900玉壁+良品装备
        { jade = 60 },                                           -- Lv6  小奖
        { frag = 2 },                                            -- Lv7  小奖
        { jade = 90 },                                           -- Lv8  小奖
        { equipDrop = 1, equipTier = 1 },                        -- Lv9  小奖: 凡品装备
        { jade = 900, frag = 3 },                                -- Lv10 ★可观: 900玉壁+3残片
        { jade = 75 },                                           -- Lv11 小奖 (25×3)
        { frag = 1 },                                            -- Lv12 小奖
        { jade = 90 },                                           -- Lv13 小奖
        { frag = 2 },                                            -- Lv14 小奖
        { jade = 900, equipDrop = 1, equipTier = 3 },            -- Lv15 ★可观: 900玉壁+优品装备
        { jade = 90 },                                           -- Lv16 小奖
        { frag = 2 },                                            -- Lv17 小奖
        { jade = 120 },                                          -- Lv18 小奖 (40×3)
        { frag = 2 },                                            -- Lv19 小奖
        { jade = 1050, equipDrop = 1, equipTier = 3, frag = 3 },-- Lv20 ★可观: 1050玉壁+优品装备+3残片
        { jade = 90 },                                           -- Lv21 小奖
        { frag = 2 },                                            -- Lv22 小奖
        { jade = 120 },                                          -- Lv23 小奖
        { equipDrop = 1, equipTier = 1 },                        -- Lv24 小奖: 凡品装备
        { jade = 1200, equipDrop = 1, equipTier = 4, frag = 5 },-- Lv25 ★可观: 1200玉壁+将品装备+5残片
        { jade = 120 },                                          -- Lv26 小奖
        { frag = 3 },                                            -- Lv27 小奖
        { jade = 150 },                                          -- Lv28 小奖 (50×3)
        { frag = 3 },                                            -- Lv29 小奖
        { jade = 1500, equipDrop = 1, equipTier = 5, frag = 8 },-- Lv30 ★终极: 1500玉壁+王品装备+8残片
        -- Lv31-40 扩充
        { jade = 150 },                                          -- Lv31 小奖
        { frag = 3 },                                            -- Lv32 小奖
        { jade = 180 },                                          -- Lv33 小奖
        { frag = 3 },                                            -- Lv34 小奖
        { jade = 1500, equipDrop = 1, equipTier = 4, frag = 6 },-- Lv35 ★可观: 1500玉壁+将品装备+6残片
        { jade = 180 },                                          -- Lv36 小奖
        { frag = 4 },                                            -- Lv37 小奖
        { jade = 210 },                                          -- Lv38 小奖
        { frag = 4 },                                            -- Lv39 小奖
        { jade = 1800, equipDrop = 1, equipTier = 5, frag = 10},-- Lv40 ★里程碑: 1800玉壁+王品装备+10残片
        -- Lv41-50 扩充
        { jade = 210 },                                          -- Lv41 小奖
        { frag = 4 },                                            -- Lv42 小奖
        { jade = 240 },                                          -- Lv43 小奖
        { frag = 5 },                                            -- Lv44 小奖
        { jade = 2100, equipDrop = 1, equipTier = 5, frag = 8 },-- Lv45 ★可观: 2100玉壁+王品装备+8残片
        { jade = 240 },                                          -- Lv46 小奖
        { frag = 5 },                                            -- Lv47 小奖
        { jade = 300 },                                          -- Lv48 小奖
        { frag = 6 },                                            -- Lv49 小奖
        { jade = 3000, equipDrop = 2, equipTier = 6, frag = 15},-- Lv50 ★★终极: 3000玉壁+2帝品装备+15残片
    },

    -- 高级奖励 (看广告解锁) — 玉壁×3，每级都好
    premiumRewards = {
        { jade = 1500 },                                          -- Lv1  1500玉壁
        { jade = 1500, frag = 3 },                                -- Lv2  1500玉壁+3残片
        { jade = 1500, equipDrop = 1, equipTier = 2 },            -- Lv3  1500玉壁+良品装备
        { jade = 1500, frag = 3 },                                -- Lv4  1500玉壁+3残片
        { jade = 1800, equipDrop = 1, equipTier = 3, frag = 5 },  -- Lv5  ★1800玉壁+优品装备+5残片
        { jade = 1500, frag = 3 },                                -- Lv6  1500玉壁+3残片
        { jade = 1500, equipDrop = 1, equipTier = 2 },            -- Lv7  1500玉壁+良品装备
        { jade = 1500, frag = 4 },                                -- Lv8  1500玉壁+4残片
        { jade = 1500, equipDrop = 1, equipTier = 3 },            -- Lv9  1500玉壁+优品装备
        { jade = 2400, equipDrop = 1, equipTier = 4, frag = 6 },  -- Lv10 ★里程碑: 2400玉壁+将品装备+6残片
        { jade = 1500, frag = 4 },                                -- Lv11 1500玉壁+4残片
        { jade = 1500, equipDrop = 1, equipTier = 3 },            -- Lv12 1500玉壁+优品装备
        { jade = 1500, frag = 5 },                                -- Lv13 1500玉壁+5残片
        { jade = 1500, equipDrop = 1, equipTier = 3 },            -- Lv14 1500玉壁+优品装备
        { jade = 2100, equipDrop = 1, equipTier = 4, frag = 6 },  -- Lv15 ★2100玉壁+将品装备+6残片
        { jade = 1500, frag = 5 },                                -- Lv16 1500玉壁+5残片
        { jade = 1500, equipDrop = 1, equipTier = 3 },            -- Lv17 1500玉壁+优品装备
        { jade = 1800, frag = 6 },                                -- Lv18 1800玉壁+6残片
        { jade = 1500, equipDrop = 1, equipTier = 4 },            -- Lv19 1500玉壁+将品装备
        { jade = 3000, equipDrop = 2, equipTier = 5, frag = 8 },  -- Lv20 ★大里程碑: 3000玉壁+2王品装备+8残片
        { jade = 1500, frag = 6 },                                -- Lv21 1500玉壁+6残片
        { jade = 1800, equipDrop = 1, equipTier = 4 },            -- Lv22 1800玉壁+将品装备
        { jade = 1500, frag = 6 },                                -- Lv23 1500玉壁+6残片
        { jade = 1800, equipDrop = 1, equipTier = 4 },            -- Lv24 1800玉壁+将品装备
        { jade = 2400, equipDrop = 1, equipTier = 5, frag = 8 },  -- Lv25 ★2400玉壁+王品装备+8残片
        { jade = 1800, frag = 8 },                                -- Lv26 1800玉壁+8残片
        { jade = 1800, equipDrop = 1, equipTier = 5 },            -- Lv27 1800玉壁+王品装备
        { jade = 2100, frag = 8 },                                -- Lv28 2100玉壁+8残片
        { jade = 2400, equipDrop = 2, equipTier = 5, frag = 10 }, -- Lv29 ★2400玉壁+2王品装备+10残片
        { jade = 4500, equipDrop = 2, equipTier = 6, frag = 15},  -- Lv30 ★★终极: 4500玉壁+2帝品装备+15残片
        -- Lv31-40 扩充
        { jade = 1800, frag = 8 },                                -- Lv31 1800玉壁+8残片
        { jade = 2100, equipDrop = 1, equipTier = 4 },            -- Lv32 2100玉壁+将品装备
        { jade = 1800, frag = 8 },                                -- Lv33 1800玉壁+8残片
        { jade = 2100, equipDrop = 1, equipTier = 5 },            -- Lv34 2100玉壁+王品装备
        { jade = 3000, equipDrop = 1, equipTier = 5, frag = 10 }, -- Lv35 ★3000玉壁+王品装备+10残片
        { jade = 2100, frag = 10 },                               -- Lv36 2100玉壁+10残片
        { jade = 2100, equipDrop = 1, equipTier = 5 },            -- Lv37 2100玉壁+王品装备
        { jade = 2400, frag = 10 },                               -- Lv38 2400玉壁+10残片
        { jade = 2400, equipDrop = 2, equipTier = 5 },            -- Lv39 2400玉壁+2王品装备
        { jade = 4500, equipDrop = 2, equipTier = 6, frag = 15 }, -- Lv40 ★★里程碑: 4500玉壁+2帝品装备+15残片
        -- Lv41-50 扩充
        { jade = 2400, frag = 10 },                               -- Lv41 2400玉壁+10残片
        { jade = 2700, equipDrop = 1, equipTier = 5 },            -- Lv42 2700玉壁+王品装备
        { jade = 2400, frag = 12 },                               -- Lv43 2400玉壁+12残片
        { jade = 2700, equipDrop = 2, equipTier = 5 },            -- Lv44 2700玉壁+2王品装备
        { jade = 3600, equipDrop = 2, equipTier = 6, frag = 12 }, -- Lv45 ★3600玉壁+2帝品装备+12残片
        { jade = 2700, frag = 12 },                               -- Lv46 2700玉壁+12残片
        { jade = 3000, equipDrop = 2, equipTier = 5 },            -- Lv47 3000玉壁+2王品装备
        { jade = 3000, frag = 15 },                               -- Lv48 3000玉壁+15残片
        { jade = 3600, equipDrop = 2, equipTier = 6, frag = 15 }, -- Lv49 ★3600玉壁+2帝品装备+15残片
        { jade = 6000, equipDrop = 3, equipTier = 6, frag = 20 }, -- Lv50 ★★★满级终极: 6000玉壁+3帝品装备+20残片
    },

    -- 战令任务定义
    dailyTasks = {
        { id = "bp_battle3",   name = "日行三战",   desc = "完成3场战斗",     target = 3,  exp = 80 },
        { id = "bp_win2",      name = "日胜两场",   desc = "赢得2场战斗",     target = 2,  exp = 60 },
        { id = "bp_explore1",  name = "日探一次",   desc = "完成1次探索",     target = 1,  exp = 100 },
        { id = "bp_gacha1",    name = "日召一次",   desc = "进行1次召唤",     target = 1,  exp = 50 },
        { id = "bp_enhance1",  name = "日炼一次",   desc = "强化1次装备",     target = 1,  exp = 50 },
    },
    weeklyTasks = {
        { id = "bp_wbattle20", name = "周伐二十",   desc = "本周完成20场战斗", target = 20, exp = 300 },
        { id = "bp_wwin12",    name = "周胜十二",   desc = "本周赢得12场",     target = 12, exp = 250 },
        { id = "bp_wexplore5", name = "周探五次",   desc = "本周完成5次探索",  target = 5,  exp = 350 },
        { id = "bp_wabyss3",   name = "周伐三讨",   desc = "本周完成3次讨伐",  target = 3,  exp = 300 },
        { id = "bp_wgacha5",   name = "周召五次",   desc = "本周召唤5次",      target = 5,  exp = 200 },
    },
    seasonTasks = {
        { id = "bp_swin50",     name = "赛季五十胜", desc = "赛季累计赢50场",   target = 50,  exp = 800 },
        { id = "bp_sbattle100", name = "百战沙场",   desc = "赛季累计100场战斗", target = 100, exp = 1000 },
        { id = "bp_sgacha30",   name = "灵召三十",   desc = "赛季累计召唤30次", target = 30,  exp = 600 },
        { id = "bp_sabyss10",   name = "讨伐十战",   desc = "赛季累计10次讨伐", target = 10,  exp = 700 },
        { id = "bp_sexplore15", name = "探索十五",   desc = "赛季累计15次探索", target = 15,  exp = 800 },
        { id = "bp_senhance20", name = "二十连炼",   desc = "赛季累计强化20次", target = 20,  exp = 500 },
    },

    -- 赛季持续天数 (到期后重置)
    seasonDays = 30,
}

-- ============================================================================
-- 交易行系统
-- ============================================================================
Config.TRADE = {
    COMMISSION = 0.05,           -- 手续费 5%
    EXPIRE_SECONDS = 3 * 86400,  -- 上架有效期 3天
    MAX_LISTINGS = 5,            -- 每人最多同时上架5件
    REFRESH_CD = 10,             -- 刷新冷却 10秒
    CHECK_SALES_CD = 60,         -- 扫描收款间隔 60秒
    PRICE_RANGE = {
        [4] = { min = 100,   max = 3000    },  -- 将品(装备tier4, ×10)
        [5] = { min = 1000,  max = 20000   },  -- 王品(装备tier5, ×10)
        [6] = { min = 20000, max = 9999990 },  -- 帝品(装备tier6, 2w起)
    },
}

return Config
