-- ============================================================================
-- G_systems.lua - 三国武灵录 (从 G.lua 拆分)
-- ============================================================================

-- ============================================================================
-- 每日副本系统 (全局)
-- ============================================================================
DAILY_DUNGEON_NAMES = { "淬魂炼器", "定向猎装", "混沌试炼" }
DAILY_DUNGEON_DESCS = {
    "必出指定部位装备 (部位每日随机)",
    "必出指定部位装备 (部位每日随机)",
    "将品及以上爆率×10 纯随机",
}
DAILY_DUNGEON_COLORS = {
    { 80, 200, 160 },   -- 绿
    { 100, 160, 255 },  -- 蓝
    { 220, 120, 255 },  -- 紫
}
DAILY_DUNGEON_ICONS = { "锻", "猎", "混" }

dailyDungeonState = {
    lastResetDay = "",
    completed = { false, false, false }, -- 今日是否已完成
    todaySlot = 1,         -- 副本1: 今日随机部位 (1-7)
    selectedSet = 1,       -- 副本2: 玩家选择的套装 (1-7)
    selectedDungeon = nil, -- 当前选中的副本 (1-3)
    showConfirm = false,   -- 是否显示确认弹窗
}
dailyDungeonCardRects = {} -- 三个副本卡片点击区域
dailyDungeonBackRect = nil
dailyDungeonConfirmBtnRect = nil
dailyDungeonCloseRect = nil
dailyDungeonSetBtnRects = {} -- 副本2: 7个套装选择按钮

-- 探索资源副本状态
resourceDungeonState = {
    lastResetDay = "",
    completed = { false, false, false },  -- 三种副本今日是否通关
    selectedType = nil,     -- 当前选中的副本类型 (1-3)
    showConfirm = false,    -- 显示确认弹窗
    showSelect = false,     -- 显示选择界面
}
resourceDungeonCardRects = {}
resourceDungeonBackRect = nil
resourceDungeonConfirmRect = nil

-- ============================================================================
-- 战令通行证状态
-- ============================================================================
battlePassState = {
    seasonStartDay = "",        -- 赛季开始日期 (YYYY-MM-DD)
    level = 0,                  -- 当前等级 (0=未解锁第1级)
    exp = 0,                    -- 当前等级内经验
    -- 任务进度 (每日/每周/赛季分开追踪)
    dailyProgress = {},         -- { bp_battle3 = 2, ... }
    weeklyProgress = {},
    seasonProgress = {},
    -- 任务领取标记
    dailyClaimed = {},          -- { bp_battle3 = true }
    weeklyClaimed = {},
    seasonClaimed = {},
    -- 奖励领取标记
    freeRewardClaimed = {},     -- { [1] = true, [2] = true, ... }
    premiumRewardClaimed = {},  -- { [1] = true, ... } (看广告领取)
    -- 重置标记
    lastDailyReset = "",
    lastWeeklyReset = "",
}
battlePassUIState = {
    tab = 1,                    -- 1=奖励总览 2=每日任务 3=周任务 4=赛季任务
    scrollY = 0,
    isDragging = false,
    dragStartY = 0,
    dragStartScroll = 0,
    rewardScrollX = 0,          -- 奖励横向滚动
    isDraggingReward = false,
    dragStartX = 0,
    dragStartScrollX = 0,
}
battlePassBackRect = nil
battlePassTabRects = {}
battlePassTaskBtnRects = {}
battlePassRewardRects = {}
battlePassClaimFreeRects = {}
battlePassClaimPremiumRects = {}

-- 武将图鉴界面状态
codexBackBtnRect = nil    -- 武将图鉴界面返回按钮

-- 战斗返回按钮
battleBackBtnRect = nil

-- 精灵图参数 (英雄4x4, 敌人4x4)
SHEET_COLS = 4
SHEET_ROWS = 4
-- 头像精灵图参数 (2列x3行)
AVATAR_COLS = 2
AVATAR_ROWS = 3
-- 各英雄精灵图的网格配置
SHEET_CONFIG = {
    [1] = { cols = 4, rows = 4, imgW = 714, imgH = 1280 },  -- hero_cards.jpg (4脳4)
    [2] = { cols = 3, rows = 3, imgW = 714, imgH = 1280 },  -- hero_cards_nobg.jpg (3脳3)
    [4] = { cols = 4, rows = 4, imgW = 714, imgH = 1280 },  -- hero_cards_extra.jpg (4脳4)
}
-- 计算每个精灵图的单格宽高比
for _, cfg in pairs(SHEET_CONFIG) do
    cfg.cellRatio = (cfg.imgW / cfg.cols) / (cfg.imgH / cfg.rows)
end
-- 无背景版精灵图的网格配置 (edited nobg 版本尺寸不同)
NOBG_SHEET_CONFIG = {
    [1] = { cols = 4, rows = 4, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_s1_nobg (4脳4)
    [2] = { cols = 3, rows = 3, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_nobg (3×3, 含清泠法姬等)
    [4] = { cols = 4, rows = 4, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_extra_nobg (4脳4)
}
for _, cfg in pairs(NOBG_SHEET_CONFIG) do
    cfg.cellRatio = (cfg.imgW / cfg.cols) / (cfg.imgH / cfg.rows)  -- ≈0.806
end
-- 装备精灵图参数 (7列=7套, 7行=7部位)
EQUIP_SHEET_COLS = 7
EQUIP_SHEET_ROWS = 7

-- 仓库格子容量
BASE_EQUIP_SLOTS = 25     -- 初始上限
UNLOCK_PER_AD_SLOTS = 5   -- 每次广告解锁

-- 背景图原始尺寸
BG_W = 714
BG_H = 1280

-- 设计分辨率 (横屏, SHOW_ALL)
DESIGN_W = 1024
DESIGN_H = 571

BG2D_X = DESIGN_W / BG_W
BG2D_Y = DESIGN_H / BG_H

-- 卡牌显示比例 (匹配武将图片 515x768)
CARD_RATIO = 515 / 768

-- 石台上的卡牌尺寸
SLOT_CARD_W = 42
SLOT_CARD_H = 42 / CARD_RATIO

-- 屏幕实际尺寸 & SHOW_ALL 变换
screenW = 0
screenH = 0
scale = 1.0
offsetX = 0
offsetY = 0

-- 战斗地图缩放/平移 (SLG 俯视角)
battleZoom = 1.0       -- 战斗场景缩放倍数 (1.0~4.0, 默认1.0=俯视全景)
battlePanX = 0         -- 战斗场景平移X (设计坐标, 正值=看右侧)
battlePanY = 0         -- 战斗场景平移Y (设计坐标, 正值=看下方)
_battlePanning = false  -- 是否正在拖拽平移战场
_battlePanLastDX = 0    -- 拖拽上一帧设计坐标X
_battlePanLastDY = 0    -- 拖拽上一帧设计坐标Y
_battlePanTouchId = nil -- 平移拖拽的触摸ID

-- 刘海屏安全区 (设计坐标单位, 每帧更新)
safeInsets = { top = 0, bottom = 0, left = 0, right = 0 }

-- ============================================================================
-- 触摸坐标系自动检测 (华为/HarmonyOS 兼容)
-- 某些设备的触摸事件返回逻辑像素而非物理像素，需要自动检测并适配
-- ============================================================================
touchCoordDPR = nil        -- 实际用于触摸坐标转换的 DPR（nil=尚未检测）
_touchDetectSamples = 0    -- 已采集的样本数
_touchDetectMax = 8        -- 最多采集 N 个样本后锁定
_touchExceedsLogical = false -- 是否有触摸坐标超出逻辑范围
_deviceInfoLogged = false  -- 设备信息是否已打印

-- 每日副本系统 (全局)
SHOP_RESERVED_H = 115

-- 相位切换防穿透冷却 (秒)
phaseChangeCooldown = 0

-- 透明版精灵图每格比例
NOBG_CELL_RATIO = (1237 / SHEET_COLS) / (1536 / SHEET_ROWS) -- 敌方 ≈0.806
-- 广告按钮区域
adRects = { jade = nil, refresh = nil, revive = nil, battleGold = nil }
autoMarchBtnRect = nil    -- 自动行军按钮
skillBtnRects = {}        -- 武技技能按钮 [slot] >> rect

-- 武技自动释放弹窗队列
skillCastPopups = {}  -- { { text, timer, duration, color } }

--- 添加武技释放弹窗
function AddSkillCastPopup(text, color)
    table.insert(skillCastPopups, {
        text = text,
        timer = 0,
        duration = 2.5,
        color = color or { 255, 220, 120 },
    })
    -- 最多同时显示4条
    while #skillCastPopups > 4 do
        table.remove(skillCastPopups, 1)
    end
end

-- 自动行军策略轮盘
strategyWheelState = {
    show = false,       -- 是否显示轮盘
    pressing = false,   -- 是否正在长按自动行军按钮
    startTime = 0,      -- 按下时间
    touchId = -1,       -- 瑙︽帶ID
    sx = 0, sy = 0,     -- 按下的屏幕坐标
    selected = 0,       -- 当前选中的策略索引 (1/2/3, 0=无)
}
STRATEGY_LONG_PRESS = 0.15  -- 长按阈值(秒)
-- 策略列表
MARCH_STRATEGIES = {
    { id = "all_lanes",   name = "五路并进", desc = "随机分配全部车道", color = { 120, 220, 160 } },
    { id = "mid_focus",   name = "全歼中路", desc = "集中兵力攻击中路", color = { 255, 200, 80  } },
    { id = "side_spread", name = "分散侧翼", desc = "侧翼包抄分散进攻", color = { 100, 180, 255 } },
}

-- 自动释放技能计时
autoSkillState = {
    timer = 0,
    interval = 5.0,     -- 每5秒自动释放一次
    nextTime = 3.0,     -- 首次延迟3秒
}

-- 战斗规则弹窗
battleRulesState = {
    show = false,
    scrollY = 0,        -- 滚动偏移
    contentH = 0,       -- 内容总高度
    viewH = 0,          -- 可视区域高度
    isDragging = false,
    lastTouchY = 0,
    vel = 0,            -- 滚动惯性速度
}
battleRuleBtnRect = nil

-- 统一规则弹窗状态 (所有界面通用)
phaseRulePopup = {
    show = false,
    phase = "",         -- 当前显示的界面phase
    scrollY = 0,
    contentH = 0,
    viewH = 0,
    isDragging = false,
    lastTouchY = 0,
    vel = 0,
    closeBtnRect = nil,
    panelRect = nil,
}
-- phaseHelpBtnRect 合并到 phaseRulePopup.helpBtnRect 以节省 upvalue

-- 各界面规则内容定义
PHASE_RULES = {
    MENU = {
        title = "游戏指南",
        color = { 160, 80, 100 },  -- 紫红
        rules = {
            { "核心玩法", "购买武灵卡牌→放到石台上阵→开战后拖拽武灵到车道派兵→击破敌方大本营获胜。" },
            { "商店与军资", "每局开始有军资可购买武灵，战斗中军资会随时间增长。点击「刷新」可更换商店卡牌。" },
            { "手动派兵", "战斗中将已上阵武灵拖拽到指定车道即可精准出击，选择合适的车道至关重要。" },
            { "自动行军", "右下角行军按钮可一键开启自动派兵。长按按钮可切换策略：五路并进、全歼中路、分散侧翼。" },
            { "武灵升级", "出卡阶段将同名武灵拖放到已上阵武灵身上可升级，属性大幅提升。" },
            { "武技技能", "装备武技后，战斗中短按技能图标后拖拽释放。长按可查看技能详情。" },
            { "兵甲系统", "收集套装兵甲可获得全局属性加成，集齐整套获得额外套装效果。套装效力按最低等阶装备折算，全帝品方可满效力。" },
            { "战力计算", "总战力 = 武灵战力(前4强) + 兵甲分 + 武技分。" },
            { "探索模式", "乱世征途中进入搜打撤探索，击败敌人开启宝箱。" },
            { "突破机制", "己方兵冲过敌方临界线直接攻击大本营。伤害=ATK+兵种突破值×15+ATK×剩余血量比×0.5，再乘以(1+突破%)。" },
            { "天崩(死亡爆炸)", "兵阵亡时以ATK×天崩%为伤害，对半径60范围内敌人造成AOE伤害。" },
            { "暴击", "基础暴击率10%，兵符/装备暴击率叠加。暴击伤害×2.0。" },
            { "减伤", "受到伤害时，实际伤害=原始伤害×(1-减伤%/100)。" },
            { "反击", "被攻击时有概率反弹50%自身ATK的伤害给攻击者。" },
            { "攻速", "降低攻击冷却时间，公式=原CD/(1+攻速%/100)。" },
            { "额外兵力", "增加出兵上限(基础40)，所有上阵武灵的额外兵力取整后叠加。" },
        },
    },
    GACHA = {
        title = "英灵征召规则",
        color = { 120, 80, 160 },  -- 紫色
        rules = {
            { "基本规则", "消耗英魂石召唤武灵，单抽消耗1颗，十连消耗10颗。" },
            { "品质概率", "普通(白)60% → 精良(绿)25% → 稀有(蓝)10% → 史诗(紫)4% → 传说(金)1%。" },
            { "保底机制", "每50次召唤必出一个史诗或更高品质武灵。每100次必出传说品质。" },
            { "十连优惠", "十连召唤必定至少包含一个稀有(蓝)或更高品质武灵。" },
            { "重复处理", "获得已拥有的武灵时，自动转化为对应品质的灵魂碎片。" },
        },
    },
    CODEX = {
        title = "武将录说明",
        color = { 80, 120, 160 },  -- 蓝色
        rules = {
            { "武将图鉴", "记录所有已发现的武灵，点击卡牌可查看详细属性。" },
            { "品质分类", "按品质筛选查看：白→绿→蓝→紫→金，便于快速定位。" },
            { "属性说明", "攻击力决定输出，防御力减少受伤，生命值决定存活时间。" },
            { "品质分类", "按品质筛选查看：白→绿→蓝→紫→金，便于快速定位。" },
        },
    },
    STAGE_SELECT = {
        title = "乱世征途规则",
        color = { 160, 120, 60 },  -- 閲戣壊
        rules = {
            { "关卡挑战", "选择关卡进入战斗，击败敌方大本营即为通关。" },
            { "难度递增", "每一章节敌人属性逐步提升，需要合理搭配阵容。" },
            { "星级评价", "根据通关表现获得1-3星评价，星级越高奖励越丰厚。" },
            { "首通奖励", "首次通关每个关卡可获得额外英魂石和军资奖励。" },
            { "首通奖励", "首次通关每个关卡可获得额外英魂石和军资奖励。" },
        },
    },
    ABYSS_SELECT = {
        title = "讨伐战令规则",
        color = { 160, 50, 50 },  -- 绾㈣壊
        rules = {
            { "讨伐机制", "逐层挑战不断强化的敌人，层数越高奖励越丰厚。" },
            { "难度递增", "每层敌人属性按比例提升，高层需要强力阵容。" },
            { "层数奖励", "每通过一层获得军资和经验奖励，里程碑层有额外大奖。" },
            { "每日重置", "讨伐进度每日重置，每天都可以重新挑战。" },
            { "排行竞争", "挑战的最高层数会记录在排行榜上与其他玩家比拼。" },
        },
    },
    TOWER_SELECT = {
        title = "无尽之塔规则",
        color = { 60, 140, 120 },  -- 青色
        rules = {
            { "爬塔机制", "逐层攀登(最高999层)，每层敌方强度×1.15递增，每100层额外×1.1，500层后每100层×2。装备最高王品(0.5%)。" },
            { "赛季上限", "本赛季最高可攀登至999层，到达后需等待下赛季开放。" },
            { "永久记录", "塔的进度不会重置，历史最高层数永久保存。" },
            { "层数奖励", "通关奖励随层数递增，高层奖励更丰厚。" },
            { "云端排行", "历史最高层数上报云端，与其他玩家一较高下。" },
        },
    },
    DAILY_DUNGEON = {
        title = "日常试炼规则",
        color = { 140, 100, 50 },  -- 妫曢噾
        rules = {
            { "每日开放", "每天开放不同类型的试炼副本，挑战次数有限。" },
            { "副本类型", "军资试炼：大量军资奖励。经验试炼：大量经验奖励。材料试炼：稀有材料掉落。" },
            { "挑战次数", "每种副本每日可挑战有限次数，次日重置。" },
            { "难度选择", "可选择不同难度，难度越高奖励越丰厚。" },
        },
    },
    RANKED_SELECT = {
        title = "巅峰对决规则",
        color = { 200, 160, 50 },  -- 閲戣壊
        rules = {
            { "排位赛制", "与其他玩家的阵容进行对战，根据胜负调整排名。" },
            { "匹配机制", "系统根据战力和段位匹配相近实力的对手。" },
            { "匹配机制", "系统根据战力和段位匹配相近实力的对手。" },
            { "赛季制度", "每赛季结束根据最终排名发放丰厚奖励。" },
            { "段位系统", "从青铜到王者，连胜可获得额外积分加成。" },
        },
    },
    WELFARE = {
        title = "天命赐福说明",
        color = { 120, 60, 140 },  -- 娣辩传
        rules = {
            { "签到奖励", "每日登录签到可领取丰厚奖励，连续签到奖励更多。" },
            { "成长基金", "一次性购买可在达到指定等级时领取大量英魂石。" },
            { "限时活动", "定期开放限时活动，参与可获得专属奖励。" },
            { "在线奖励", "累计在线时间可领取额外奖励。" },
        },
    },
    SUMMON = {
        title = "召唤系统说明",
        color = { 120, 80, 180 },  -- 紫
        rules = {
            { "兵符召唤", "消耗玉壁召唤兵符，兵符可强化武灵属性。需拥有满命武灵才可铭刻。" },
            { "武将召唤", "消耗玉壁召唤新武将或提升已有武将命格。" },
            { "十连优惠", "十连及以上召唤享9折优惠。" },
        },
    },
    SEAL_MGR = {
        title = "兵符管理说明",
        color = { 100, 80, 140 },  -- 暗紫
        rules = {
            { "兵符系统", "兵符是强化武灵的特殊装备，可提供额外属性加成。" },
            { "兵符品质", "兵符分为不同品质，品质越高提供的属性越强。" },
            { "装备规则", "每个武灵可装备有限数量的兵符，合理搭配提升战力。" },
            { "强化升级", "使用材料强化兵符可提升属性，高级兵符需要稀有材料。" },
            { "套装效果", "装备同类型兵符达到一定数量可激活套装效果。" },
        },
    },
    EQUIP = {
        title = "兵甲系统说明",
        color = { 100, 130, 80 },  -- 暗绿
        rules = {
            { "装备获取", "通过战斗掉落、商店购买或活动获取装备。" },
            { "兵甲等阶", "兵甲分为凡品、良品、优品、将品、王品、帝品六个等阶，等阶越高属性越强。" },
            { "强化等级", "兵甲可强化至+20，每次强化消耗军资并提升属性。" },
            { "穿戴规则", "点击兵甲可穿戴到对应部位，替换同部位已装备兵甲。" },
            { "筛选分解", "按等阶和强化等级筛选批量分解不需要的兵甲，回收军资。" },
            { "选中分解", "手动勾选要分解的兵甲，精确控制分解内容。" },
            { "套装效果", "收集同套装兵甲可激活套装效果，提供额外加成。" },
        },
    },
}

-- 新手指引弹窗状态 (首页用)
newbieGuidePopup = {
    show = false,
    scrollY = 0,
    contentH = 0,
    viewH = 0,
    isDragging = false,
    lastTouchY = 0,
    vel = 0,
    closeBtnRect = nil,
    panelRect = nil,
}

-- 武技技能长按查看详情状态
skillLongPressState = {
    pressing = false,
    startTime = 0,
    slot = 0,           -- 按下的技能槽位 (1/2)
    touchId = -1,
    showPopup = false,   -- 是否显示技能详情弹窗
    popupSkillIdx = 0,   -- 显示的技能索引
    popupRect = nil,     -- 弹窗区域 (防穿透)
}

-- 战力说明弹窗
powerExplainPopup = {
    show = false,
    closeBtnRect = nil,
    panelRect = nil,
}

-- 玩家详情编辑模式
playerDetailEditMode = false
playerDetailEditState = {
    selectedAvatar = 1,
    selectedName = 1,
    customName = "",
    avatarRects = {},
    nameRects = {},
    confirmBtnRect = nil,
    cancelBtnRect = nil,
    customInputRect = nil,
}

require "G_data_skills"

-- 玩家已装备的武技 (按武将分配, 每武将最多2个, SKILL_TECHNIQUES 索引)
-- 格式: playerEquippedSkills[heroIdx] = { skillIdx1, skillIdx2 }
playerEquippedSkills = {}  -- 默认无装备武技(全部未解锁)

--- 获取指定武将的已装备武技列表 (安全访问)
function GetHeroSkills(heroIdx)
    if not heroIdx then return {} end
    if not playerEquippedSkills[heroIdx] then
        playerEquippedSkills[heroIdx] = {}
    end
    return playerEquippedSkills[heroIdx]
end

--- 获取所有武将已装备武技的合集 (去重, 用于战斗)
function GetAllEquippedSkills()
    local all = {}
    local seen = {}
    for heroIdx, skills in pairs(playerEquippedSkills) do
        if type(skills) == "table" then
            for _, si in ipairs(skills) do
                if not seen[si] then
                    seen[si] = true
                    all[#all + 1] = si
                end
            end
        end
    end
    return all
end

--- 获取所有已装备武技的集合 (用于判断是否已被任意武将装备)
function GetAllEquippedSkillSet()
    local set = {}
    for heroIdx, skills in pairs(playerEquippedSkills) do
        if type(skills) == "table" then
            for _, si in ipairs(skills) do
                set[si] = heroIdx  -- 记录装备在哪个武将身上
            end
        end
    end
    return set
end

-- 武技界面状态"
skillCodexState = {
    scrollY = 0,
    scrollVel = 0,
    scrollX = 0,          -- 横向滚动偏移
    scrollVelX = 0,       -- 横向滚动惯性
    dragStartY = nil,
    dragStartX = nil,
    dragLastY = nil,
    dragLastX = nil,
    isDragging = false,
    selectedIdx = 0,      -- 当前查看的武技索引
    selectedTier = 1,     -- 当前选中品质标签 (1~7)
}
skillCodexBackBtnRect = nil
skillCodexCardRects = {}
-- 武技弹窗面板状态 (替代已删除的详情页)
skillPopup = {
    show = false,
    skillIdx = nil,
    panelRect = nil,
    equipBtnRect = nil,
    equipSlotBtns = {},
    composeBtnRect = nil,
    closeBtnRect = nil,
}
-- menuSkillCodexBtnRect / menuWelfareBtnRect 已合并到 menuBtnRects
welfareState = {
    backBtnRect = nil,        -- 福利页返回按钮
    -- 三日签到
    signInClaimed = {false, false, false},  -- 每天是否已领取
    signInTimestamps = {0, 0, 0},             -- 每天领取时的 os.time() 时间戳
    signInBtnRects = {},      -- 签到按钮区域
    -- 十日签到（每日广告领5000玉壁）
    dailySignInClaimed = {false, false, false, false, false, false, false, false, false, false},
    dailySignInTimestamps = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0},  -- 每天领取时的 os.time() 时间戳
    dailySignInBtnRects = {},
    -- 在线时长奖励
    onlineTime = 0,           -- 累计在线秒数
    onlineRewards = {false, false, false, false}, -- 各档奖励是否已领
    onlineBtnRects = {},      -- 在线奖励按钮区域
    -- 贡献榜
    contribRank = nil,        -- 排行榜数据缓存 (数组 {name, count})
    contribLoading = false,   -- 是否正在加载
    contribLoaded = false,    -- 是否已加载完成
    -- 页面滚动（下方内容区）
    scroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 贡献榜独立滚动（顶部固定区域）
    contribScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    contribFixedH = 0,  -- 贡献榜固定区域总高度（动态计算）
    contribShowAll = false, -- 贡献榜是否展开显示全部（默认只显示前3）

    -- 大转盘
    spinWheel = {
        lastDate = "",        -- 上次转盘日期
        freeUsed = false,     -- 今日免费转是否已用
        adSpins = 0,          -- 今日广告转次数
        spinning = false,     -- 是否正在旋转
        angle = 0,            -- 当前角度(弧度)
        targetAngle = 0,      -- 目标角度
        spinStart = 0,        -- 开始旋转时间
        resultIdx = 0,        -- 结果索引
        resultGranted = false,-- 结果已发放
    },
    spinWheelBtnRect = nil,
    -- 每日翻牌
    cardFlip = {
        lastDate = "",        -- 上次翻牌日期
        cards = {},           -- 6张牌的奖励索引
        flipped = {},         -- 哪些牌已翻开 {false,false,...}
        freeUsed = false,     -- 今日免费转是否已用
        adFlips = 0,          -- 今日广告翻牌次数
    },
    cardFlipBtnRects = {},
    contribDetailBtnRect = nil,  -- 查看详情按钮区域
    -- 贡献榜详情页独立滚动
    contribDetailScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 战力排行榜
    powerRank = nil,          -- 排行榜数据缓存 (数组 {name, power})
    powerLoading = false,     -- 是否正在加载
    powerLoaded = false,      -- 是否已加载完成
    powerScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    powerFixedH = 0,          -- 战力排行榜固定区域总高度
    -- 排行榜页签: "power" 或 "realm"
    rankTab = "power",
    -- 境界排行榜
    realmRank = nil,          -- 境界排行榜数据缓存 (数组 {name, rankIdx})
    realmLoading = false,
    realmLoaded = false,
    realmScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 阵营等级排行榜
    factionRank = nil,         -- 排行榜数据缓存 (数组 {name, level, exp, userId, leaderName})
    factionRankLoading = false,
    factionRankLoaded = false,
    factionRankScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 查看玩家弹窗
    rankViewPopup = nil,  -- { entry={name,power,skillCount,heroCount,realmIdx,rank}, closeBtnRect={} }
    rankViewBtnRects = {},  -- [i] = {x,y,w,h}
}

-- ============================================================================
-- 邮件系统
-- ============================================================================
-- welfareState.mailDefs 和 welfareState.mail 合并到 welfareState 避免 local 上限
welfareState.mailDefs = {
    {
        id = "welcome_gift",
        title = "感谢相遇",
        sender = "武灵王座",
        content = "武灵大人，感谢你踏入这片乱世！初次相遇，赠你3000玉壁（约100抽），愿助你召集天下英杰、征战四方！此礼终身仅可领取一次，祝旗开得胜！",
        rewards = {
            { type = "jade", amount = 3000, label = "玉壁 ×3000" },
        },
    },
    {
        id = "self_recommend",
        title = "自荐信",
        sender = "制作人",
        content = "这是一个非常费心血的小游戏，感恩相遇，也希望大家能多多好评，可以加群一起交流优化方向，如果您的朋友也喜欢这个题材，请一定帮我推荐给他！！！感恩！",
        rewards = {
            { type = "jade", amount = 2000, label = "玉壁 ×2000" },
        },
    },
}
welfareState.mail = {
    claimed = {},         -- { [mailId] = true } 已领取的邮件
    btnRects = {},        -- 领取按钮区域
    confirmPopup = nil,   -- 领取确认弹窗 { mailIdx = N, closeBtnRect, confirmBtnRect, bgRect }
    tab = "system",       -- "system" / "cloud" 邮件标签
    cloudBtnRects = {},   -- 云邮件领取/查看按钮区域
    composing = false,    -- 是否正在写信
    composeData = nil,    -- 写信数据 { targetUid="", subject="", body="", rewards={}, inputFocus="" }
    adminPanel = false,   -- 管理员奖励面板
}

-- ============================================================================
-- 每周排行榜奖励结算 (客户端触发式)
-- ============================================================================
-- 奖励配置: 各排行榜 top N 奖励
WEEKLY_RANK_REWARDS = {
    {
        name = "战力榜", key = PROJECT_PREFIX .. "combat_power",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 500, label = "玉壁 ×500" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 300, label = "玉壁 ×300" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 150, label = "玉壁 ×150" } } },
            { maxRank = 20, rewards = { { type = "jade", amount = 80,  label = "玉壁 ×80" } } },
        },
    },
    {
        name = "境界榜", key = PROJECT_PREFIX .. "realm_level",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 500, label = "玉壁 ×500" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 300, label = "玉壁 ×300" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 150, label = "玉壁 ×150" } } },
            { maxRank = 20, rewards = { { type = "jade", amount = 80,  label = "玉壁 ×80" } } },
        },
    },
    -- 爬塔榜、排位榜已移除
}

-- ============================================================================
-- 兵种系统
-- ============================================================================
UNIT_CLASS = {
    -- =====================================================================
    -- 步兵系 (infantry) — 近战肉搏，攻守均衡 | 移速大幅提升
    -- =====================================================================
    INFANTRY_LIGHT = { id = 21, name = "轻装刀兵", sprite = "sword",   isRanged = false,
        atkRange = 40, speed = 48, atkCd = 0.9, breakDmg = 1,
        baseTroop = "infantry", tier = 1, desc = "轻装步卒，灵活迅捷" },
    INFANTRY_HEAVY = { id = 22, name = "重甲刀盾", sprite = "shield",  isRanged = false,
        atkRange = 38, speed = 42, atkCd = 0.8, breakDmg = 2,
        baseTroop = "infantry", tier = 2, desc = "重甲持盾，坚如磐石" },
    INFANTRY_ELITE = { id = 23, name = "虎贲精锐", sprite = "sword",   isRanged = false,
        atkRange = 42, speed = 45, atkCd = 0.7, breakDmg = 3,
        baseTroop = "infantry", tier = 3, hpMult = 1.2, atkMult = 1.15, desc = "虎贲之师，攻守兼备" },

    -- =====================================================================
    -- 弓兵系 (archer) — 远程输出，射程极远，攻速极慢
    -- =====================================================================
    ARCHER_LIGHT  = { id = 24, name = "轻弩散兵", sprite = "archer",  isRanged = true,
        atkRange = 280, speed = 24, atkCd = 5.0, breakDmg = 1,
        baseTroop = "archer", tier = 1, hpMult = 0.6, defMult = 0.5, desc = "轻弩射手，压制前排" },
    ARCHER_HEAVY  = { id = 25, name = "连弩射手", sprite = "archer",  isRanged = true,
        atkRange = 300, speed = 22, atkCd = 4.5, breakDmg = 1,
        baseTroop = "archer", tier = 2, hpMult = 0.55, defMult = 0.45, desc = "连弩齐发，火力密集" },
    ARCHER_ELITE  = { id = 26, name = "神射营", sprite = "mage",    isRanged = true,
        atkRange = 320, speed = 20, atkCd = 4.0, breakDmg = 2,
        baseTroop = "archer", tier = 3, atkMult = 1.2, hpMult = 0.5, defMult = 0.4, desc = "百步穿杨，弹无虚发" },

    -- =====================================================================
    -- 骑兵系 (cavalry) — 高速突击，侧翼包抄 | 移速大幅提升
    -- =====================================================================
    CAVALRY_LIGHT = { id = 27, name = "轻骑斥候", sprite = "cavalry", isRanged = false,
        atkRange = 42, speed = 58, atkCd = 0.9, breakDmg = 2,
        baseTroop = "cavalry", tier = 1, desc = "轻骑探路，迅如疾风" },
    CAVALRY_HEAVY = { id = 28, name = "铁骑先锋", sprite = "cavalry", isRanged = false,
        atkRange = 45, speed = 62, atkCd = 0.85, breakDmg = 3,
        baseTroop = "cavalry", tier = 2, desc = "铁甲骑兵，冲锋陷阵" },
    CAVALRY_ELITE = { id = 29, name = "虎豹精骑", sprite = "cavalry", isRanged = false,
        atkRange = 48, speed = 66, atkCd = 0.8, breakDmg = 4,
        baseTroop = "cavalry", tier = 3, hpMult = 1.15, atkMult = 1.2, desc = "虎豹骑精锐，势不可挡" },

    -- =====================================================================
    -- 枪兵系 (spear) — 长兵器克骑，稳守阵线 | 移速提升
    -- =====================================================================
    SPEAR_LIGHT   = { id = 30, name = "长矛步卒", sprite = "lancer",  isRanged = false,
        atkRange = 52, speed = 42, atkCd = 1.1, breakDmg = 1,
        baseTroop = "spear", tier = 1, desc = "长矛列阵，拒马克骑" },
    SPEAR_HEAVY   = { id = 31, name = "重装枪阵", sprite = "lancer",  isRanged = false,
        atkRange = 55, speed = 40, atkCd = 1.0, breakDmg = 2,
        baseTroop = "spear", tier = 2, desc = "枪阵如林，稳守如山" },
    SPEAR_ELITE   = { id = 32, name = "龙胆枪卫", sprite = "lancer",  isRanged = false,
        atkRange = 58, speed = 44, atkCd = 0.9, breakDmg = 3,
        baseTroop = "spear", tier = 3, hpMult = 1.15, atkMult = 1.15, desc = "龙胆亮银枪，一枪定乾坤" },

    -- =====================================================================
    -- 敌方兵种 (不参与玩家克制循环) | 移速/射程与玩家对应兵种统一
    -- =====================================================================
    DEMON_WARRIOR = { id = 41, name = "黄巾力士", sprite = "demon_warrior", isRanged = false,
        atkRange = 40, speed = 45, atkCd = 0.9, breakDmg = 1,
        baseTroop = "infantry", desc = "黄巾贼兵，悍不畏死" },
    DEMON_ARCHER  = { id = 42, name = "贼军弓手", sprite = "demon_archer",  isRanged = true,
        atkRange = 280, speed = 22, atkCd = 3.0, breakDmg = 1,
        baseTroop = "archer", hpMult = 0.6, defMult = 0.5, desc = "贼军弓手，暗箭难防" },
    DEMON_TANK    = { id = 43, name = "铁甲悍将", sprite = "demon_tank",    isRanged = false,
        atkRange = 35, speed = 32, atkCd = 0.8, breakDmg = 3,
        baseTroop = "infantry", desc = "身披重铠的悍将，坚不可摧" },
}

local function MakeSlot(bgX, bgY)
    return { cx = bgX * BG2D_X, cy = bgY * BG2D_Y, filled = false, card = nil }
end

-- 直接使用设计坐标定义英雄格位 (全屏左右纵列布局)
local function MakeHeroSlot(cx, cy)
    return { cx = cx, cy = cy, filled = false, card = nil }
end

-- 每侧最多6个武将槽位 — 新布局: 玩家在左侧纵列(x=60), 敌方在右侧纵列(x=964)
PLAYER_SLOTS = {
    MakeHeroSlot(60, 80),
    MakeHeroSlot(60, 164),
    MakeHeroSlot(60, 248),
    MakeHeroSlot(60, 332),
    MakeHeroSlot(60, 416),
    MakeHeroSlot(60, 500),
}

ENEMY_SLOTS = {
    MakeHeroSlot(964, 80),
    MakeHeroSlot(964, 164),
    MakeHeroSlot(964, 248),
    MakeHeroSlot(964, 332),
    MakeHeroSlot(964, 416),
    MakeHeroSlot(964, 500),
}

require "G_data_heroes"

require "G_data_battle"
currentLayoutIdx = 1

--- 石台编辑器撤销栈 (每次拖拽前记录快照)
slotUndoStack = {}  -- { {layoutIdx, slotType, slotIdx, oldX, oldY}, ... }  MAX=50

stageState = {
    currentStage = 1,       -- 当前选中关卡
    maxUnlocked = 1,        -- 最大已解锁关卡
    currentPage = 1,        -- 当前椤电爜 (1-3)
    showPreview = false,    -- 显示关卡预览
    showDropPopup = false,  -- 显示爆装弹窗
    lastDropReward = nil,   -- 上次爆装结果
}
stageMaxTier = 1  -- 当前关卡最高掉落阶级
stageNodeRects = {}
stagePreviewBtnRect = nil
stagePagePrevRect = nil
stagePageNextRect = nil
stageChestRects = {}  -- 宝箱点击区域
stageBackBtnRect = nil
stageStartBtnRect = nil
stagePreviewCloseRect = nil
stageDropCloseRect = nil

-- ============================================================================
-- 讨伐战 配置与状态
-- ============================================================================
abyssState = {
    floors = {
        { name = "黄巾关", desc = "黄巾余部盘踞之地",   unlockStage = 1, color = {60, 140, 220},  enemyScale = 2.3 },
        { name = "汜水关", desc = "关隘险峻易守难攻",   unlockStage = 2, color = {220, 190, 100}, enemyScale = 3.3 },
        { name = "荆州城", desc = "兵家必争的战略要地", unlockStage = 3, color = {80, 200, 120},  enemyScale = 4.4 },
        { name = "赤壁滩", desc = "烈火焚江的古战场",   unlockStage = 3, color = {120, 200, 255}, enemyScale = 5.8 },
        { name = "五丈原", desc = "星落秋风的悲壮之地", unlockStage = 4, color = {180, 120, 255}, enemyScale = 7.5 },
        { name = "长坂坡", desc = "万军丛中如入无人之境", unlockStage = 5, color = {100, 200, 80},  enemyScale = 8.3 },
        { name = "虎牢关", desc = "天下第一雄关绝地",   unlockStage = 6, color = {255, 160, 180}, enemyScale = 9.5 },
    },
    selectedFloor = 1,
    showPreview = false,
    scrollY = 0,
    scrollVel = 0,
    btnRect = nil,              -- 首页讨伐按钮
    backBtnRect = nil,        -- 福利页返回按钮
    floorRects = {},            -- 讨伐关卡按钮区域
    startBtnRect = nil,         -- 讨伐出战按钮
    previewCloseRect = nil,     -- 预览关闭按钮
}

-- ============================================================================
-- 无尽爬塔 配置与状态
-- ============================================================================
towerState = {
    currentFloor = 1,           -- 当前挑战层数
    highestFloor = 1,           -- 历史最高层数
    showPreview = false,
    btnRect = nil,              -- 首页讨伐按钮
    backBtnRect = nil,        -- 福利页返回按钮
    startBtnRect = nil,         -- 讨伐出战按钮
    -- 排行榜
    rankList = {},              -- 排行榜数据
    rankLoaded = false,
    rankLoading = false,
    showLeaderboard = false,    -- 是否显示排行榜
    leaderboardBtnRect = nil,   -- 排行榜按钮
    leaderboardBackRect = nil,  -- 排行榜关闭按钮
}

-- ============================================================================
-- 排位竞技 配置与状态
-- ============================================================================
RANKED_TIERS = {
    { name = "黄铜", icon = "B", color = {180, 120, 60},  minScore = 0 },
    { name = "校尉", icon = "S", color = {180, 190, 210}, minScore = 120 },
    { name = "偏将", icon = "G", color = {255, 200, 60},  minScore = 280 },
    { name = "都督", icon = "P", color = {100, 220, 220}, minScore = 480 },
    { name = "大将", icon = "D", color = {140, 180, 255}, minScore = 750 },
    { name = "天命", icon = "M", color = {255, 80, 80},   minScore = 1050 },
}

rankedState = {
    score = 0,
    wins = 0,
    losses = 0,
    streak = 0,
    highestScore = 0,
    -- UI
    btnRect = nil,
    backBtnRect = nil,
    startBtnRect = nil,
    rankBtnRect = nil,
    showPreview = false,
    matchAnim = 0,
    isMatching = false,
    matchReady = false,
    -- 瀵规墜信息
    opponentName = "",
    opponentPower = 0,
    opponentCards = {},
    -- 排行榜
    rankLoading = false,
    rankLoaded = false,
    rankList = {},
    rankScroll = { offset = 0, vel = 0, isDragging = false, lastY = nil },
    showLeaderboard = false,
}

-- 兵甲图录状态
equipCodexState = {
    scrollOffset = 0,
    selectedSet = 1,
    scrollY = 0,           -- 滚动偏移
    scrollVel = 0,          -- 滚动惯性速度
    dragStartY = nil,       -- 触摸拖动起始Y
    dragLastY = nil,    -- 上一帧触摸Y
    isDragging = false,     -- 是否正在拖动
}
equipCodexBackBtnRect = nil
equipCodexSetRects = {}
-- powerRankBackBtnRect 存储在 menuBtnRects.powerRankBack 中，避免局部变量上限

-- ============================================================================
-- 游戏状态"
-- ============================================================================
BASE_HP_MAX = GameConfig.BASE_HP_MAX
-- 新士兵属性公式常量
SOLDIER_BASE_HP   = GameConfig.SOLDIER_BASE_HP
SOLDIER_BASE_ATK  = GameConfig.SOLDIER_BASE_ATK
SOLDIER_BASE_DEF  = GameConfig.SOLDIER_BASE_DEF
SOLDIER_HP_SCALE  = GameConfig.SOLDIER_HP_SCALE
SOLDIER_ATK_SCALE = GameConfig.SOLDIER_ATK_SCALE
SOLDIER_DEF_SCALE = GameConfig.SOLDIER_DEF_SCALE
TROOP_DISPLAY_SCALE = 1     -- 数据已为实际值, 显示倍率=1
battleTroopScale = 1        -- 本场战斗动态缩放 (兵力>200时>1, 每精灵代表更多人)

gameState = {
    gold = 0,
    totalKills = 0,
    gameTime = 0,
    phase = "LOADING",      -- LOADING / PROFILE / MENU / SUMMON / GACHA / CODEX / EQUIP / EQUIP_CODEX / STAGE_SELECT / ABYSS_SELECT / EXPLORATION / TOWER_SELECT / RANKED_SELECT / BATTLE / WIN / LOSE / WELFARE / PROGRESS / PLAYER_DETAIL / SKILL_CODEX / DEV_EDITOR
    battlePhase = "DEPLOY", -- DEPLOY(布阵) / FIGHT(战斗中)
    resultTimer = 0,
    playerBaseHP = BASE_HP_MAX,
    playerBaseMax = BASE_HP_MAX,
    enemyBaseHP = BASE_HP_MAX,
    drawCount = 0,
    goldTimer = 0,          -- 军资自动增长计时器
    battleTime = 0,         -- 战斗持续时间
    autoMarch = false,      -- 自动行军模式
    behaviorMode = "free",  -- 全局行为指令: "hold"(驻守) / "attack"(进攻) / "free"(自由,默认)
    battleSpeed = 1,        -- 战斗倍速 (1/2/3/5/10)
    autoBattle = false,     -- 全自动战斗 (自动刷将/派兵/开战)
    noFullAuto = false,     -- 副本模式禁止全自动 (只允许自动派兵)
    abyssFloor = nil,       -- 讨伐模式层数 (nil=普通关卡)
    towerFloor = nil,       -- 爬塔模式层数 (nil=非爬塔)
    isRanked = false,       -- 排位模式标记
    explorationMode = false, -- 搜打撤探索模式标记 (从探索发起的战斗)
    exploreExitConfirm = nil, -- 探索战斗弹窗 { type = "exit"|"death" }
}

-- 开发者战场编辑器状态 (全局)
editorState = {
    tab = 1,             -- 1=关卡编辑, 2=战斗参数, 3=快速测试, 4=石台编辑
    selectedStage = 1,   -- 当前编辑的关卡
    scrollY = 0,
    scrollVel = 0,
    isDragging = false,
    dragLastY = nil,
    contentHeight = 0,
    backBtnRect = nil,
    btnRects = {},        -- 领取按钮区域
    tabRects = {},
    -- 临时编辑参数 (覆盖 GameConfig)
    overrides = {
        baseHpMax = nil,
        initialGold = nil,
        enemySpawnCd = nil,
        playerSpawnCd = nil,
        battleTimeLimit = nil,
        soldierStatScale = nil,
        deployCd = nil,
    },
    -- 编辑过的关卡数据
    stageOverrides = {},  -- [stageIdx] = { enemyScale, name, desc }
    testStage = 1,        -- 快速测试的关卡
    -- 石台编辑 (tab 4)
    editLayoutIdx = 1,      -- 当前编辑的布局索引
    slotDragging = false,   -- 是否正在拖拽石台
    previewRect = nil,      -- 背景预览区域 {x,y,w,h}
    -- 多选 + 拖拽
    selectedSlots = {},     -- { ["player_1"]=true, ["enemy_3"]=true, ... }
    slotPressKey = nil,     -- 按下的槽位 key (用于区分点击/拖拽)
    slotWasSelected = false, -- 按下时该槽位是否已是选中状态
    slotPressStartX = nil,  -- 按下时的设计坐标 X
    slotPressStartY = nil,  -- 按下时的设计坐标 Y
    dragStartBgX = nil,     -- 拖拽起始的背景像素 X
    dragStartBgY = nil,     -- 拖拽起始的背景像素 Y
    dragOrigPositions = nil, -- 拖拽开始时所有选中槽位的原始位置
}

-- 商店卡牌 (从已拥有武灵刷新)
shopCards = {}        -- { cardIdx, quality, cost, sold }
shopFightBtnRect = nil -- 开战按钮区域 (设计坐标)
-- 战前武将路线分配: [slotIdx] = laneNum (1-5), nil=全路线均分
heroLaneAssignment = {}
preBattleSelectingSlot = 0   -- 当前正在选路线的武将格位 (0=未选中)
battleSpeedBtnRect = nil       -- 倍速按钮区域 (设计坐标, global避免local-limit)
autoBattleBtnRect = nil        -- 自动战斗按钮区域 (设计坐标, global避免local-limit)
autoBattleTimer = 0            -- 自动战斗操作节流计时器 (global避免local-limit)
shopRefreshBtnRect = nil       -- 刷新按钮区域 (设计坐标, global避免local-limit)

-- 刘海屏安全区 (设计坐标单位, 每帧更新)
BATTLE_ZONE = {
    top = 200, bottom = 500,        -- ★ 中间地面区域 (设计坐标 768 高度)
    centerY = 350,                  -- ★ (200+500)/2
    left = 20, right = 1004,
    centerX = 512,
    -- 临界线: 在武将列正前方 (玩家武将列 x=60, 敌方武将列 x=964)
    playerLine = 102,   -- 敌方兵越过此线扣玩家基地血 (玩家武将 x=60 前方)
    enemyLine  = 922,   -- 玩家兵越过此线扣敌方基地血 (敌方武将 x=964 前方)
    -- 部署区域: 小兵在两侧死亡线之间出生，被武将列框住
    playerDeployLeft  = 115,
    playerDeployRight = 420,
    enemyDeployLeft   = 604,
    enemyDeployRight  = 909,
}

-- ============================================================================
-- 车道系统 (5条纵向等分车道, 横屏按Y轴分)
-- ============================================================================
NUM_LANES = 5
LANE_WIDTH = (BATTLE_ZONE.bottom - BATTLE_ZONE.top) / NUM_LANES  -- ~110px each
INTERCEPT_RANGE = 55  -- 士兵拦截敌人的距离阈值

playerUnits = {}
enemyUnits = {}
floatTexts = {}

playerSpawnTimer = 0
enemySpawnTimer = 0
BATTLE_TIME_LIMIT = GameConfig.BATTLE_TIME_LIMIT or 180
MAX_PLAYER_UNITS = 500
MAX_ENEMY_UNITS = 500
-- 本场战斗驻军派兵上限 (由SLG地图决定, 0=无限制)
battleGarrisonCap = 0
-- 本场战斗已派出的玩家兵力总数
battlePlayerTotalSpawned = 0

-- ============================================================================
-- 阵型/战术/士气 战斗全局变量 (每次 InitBattle 重置)
-- ============================================================================
battleFormationId            = nil   -- 当前阵型 id (string or nil)
battleFormationLaneWeights   = nil   -- 车道权重 table[1..5]，nil 时等权随机
battleFormationArcherAtkBonus = 0   -- 弓兵攻击加成系数 (如 0.20 = +20%)
battleFormationCounterReflect = 0   -- 克制伤害反弹系数
battleDeployCd               = 3.5  -- 本场实际部署CD(由阵型×战术决定, 下限1.2s)
battleTacticId               = nil   -- 当前战术 id
battleTacticUnitAtkMult      = 1.0  -- 战术单位攻击乘数
battleTacticUnitDefMult      = 1.0  -- 战术单位防御乘数
battleTacticUnitCounterRate  = 1.0  -- 战术克制触发率乘数
battleTacticCounterReflectBonus = 0  -- 战术克制反弹加成
battleMoraleLabel            = ""    -- 士气等级文字 (如"高昂")

-- DEPLOY 阶段阵型切换 UI 状态
deploySelectedFormation      = nil   -- 当前选中的阵型 id (DEPLOY阶段)
deployFormationBtnRects      = {}    -- 阵型按钮碰撞矩形 { [formId] = {x,y,w,h} }
deploySwapFirstTroop         = nil   -- 兵种位置交换: 第一个选中的兵种key (如 "infantry")
deployCustomZones            = nil   -- 玩家手动交换后的自定义兵种区域 (覆盖阵型默认)


-- ============================================================================
-- 战旗回合制 - 网格/状态全局变量
-- ============================================================================
TACTIC_COLS = 12    -- 12列 (横向, 更多格子配合缩放)
TACTIC_ROWS = 7     -- 7行 (纵向)

-- 网格像素尺寸 (基于 BATTLE_ZONE 自动计算)
TACTIC_CELL_W = (BATTLE_ZONE.right - BATTLE_ZONE.left) / TACTIC_COLS   -- ~82
TACTIC_CELL_H = (BATTLE_ZONE.bottom - BATTLE_ZONE.top) / TACTIC_ROWS  -- ~79

-- 兵种战旗参数: 移动范围/攻击范围/基础战力
-- atkRange=0: 只能攻击同格敌人(近战); atkRange=1: 攻击相邻格敌人(远程)
TROOP_TACTICS = {
    infantry = { moveRange = 1, atkRange = 1, baseAtk = 35, baseDef = 25, baseHP = 120, icon = "步" },
    archer   = { moveRange = 1, atkRange = 2, baseAtk = 40, baseDef = 12, baseHP = 70,  icon = "弓" },
    cavalry  = { moveRange = 2, atkRange = 1, baseAtk = 45, baseDef = 15, baseHP = 90,  icon = "骑" },
    spear    = { moveRange = 1, atkRange = 1, baseAtk = 30, baseDef = 30, baseHP = 100, icon = "枪" },
}

-- 战旗全局状态 (每次 InitBattle 重置)
---@class TacticState
---@field turnPhase string 当前回合阶段
---@field turnNumber number 回合数
---@field isPlayerTurn boolean 是否玩家回合
---@field selectedGroup number|nil 选中的兵团索引
---@field moveTargets table 可移动格子列表
---@field attackTargets table 可攻击格子列表
---@field animTimer number 动画计时器
---@field animType string|nil 动画类型
---@field animData table|nil 动画数据
---@field grid table 网格占据数据 grid[row][col]
---@field playerGroups table 玩家兵团列表
---@field enemyGroups table 敌方兵团列表
---@field bannerTimer number 回合横幅显示计时
---@field bannerText string|nil 横幅文字
---@field battleLog table 战场播报记录
---@field projectiles table 弹道特效列表
tacticState = nil  -- InitBattle 时初始化

-- 战旗按钮碰撞矩形 (全局, 设计坐标)
tacticBtnMove   = nil  -- 移动按钮
tacticBtnAttack = nil  -- 攻击按钮
tacticBtnWait   = nil  -- 待机按钮
tacticBtnEnd    = nil  -- 结束回合按钮

-- ============================================================================
-- 特效系统
-- ============================================================================
particles = {}
projectiles = {}  -- 远程弹道特效列表

-- ============================================================================
-- 背包系统 (替代旧商店)
-- ============================================================================
-- inventory[i] = { cardIdx=N, constellation=0 }  (未部署的卡)
inventory = {}
invScrollOffset = 0  -- 背包翻页偏移

shopLayout = {
    y = 0, h = 0, cardW = 0, cardH = 0,
    startX = 0, gap = 0,
    drawBtnX = 0, drawBtnY = 0, drawBtnW = 0, drawBtnH = 0,
}

-- 拖拽 (★ 拖拽坐标统一使用屏幕逻辑坐标)
dragState = {
    active = false,
    card = nil,
    invIdx = 0,       -- 背包索引 (替代 shopIdx)
    lx = 0, ly = 0,
    touchId = -1,
    fromInventory = true,
    fromShop = false,     -- 是否从商店拖拽
    shopIdx = 0,          -- 商店卡牌索引
}

-- 长按提示
longPressState = {
    active = false,
    pressing = false,
    startTime = 0,
    card = nil,
    isSlot = false,
    slotIdx = 0,
    isEnemy = false,
}
LONG_PRESS_THRESHOLD = 0.45

-- 刘海屏安全区 (设计坐标单位, 每帧更新)
infoPopupState = {
    show = false,
    card = nil,
    slotIdx = 0,
    isSlot = false,
    isEnemy = false,
}
-- (laneButtonRects 已废弃, 车道选择改为拖拽部署)
laneButtonRects = {}
pressStartSX = 0
pressStartSY = 0

-- ============================================================================
-- 初始化
-- ============================================================================

