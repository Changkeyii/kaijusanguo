-- ============================================================================
-- G_systems.lua - 三国武灵录 (从 G.lua 拆分)
-- ============================================================================

-- ============================================================================
-- 每日副本系统 (全局)
-- ============================================================================
DAILY_DUNGEON_NAMES = { "铸魂炼器", "定向猎装", "混沌试炼" }
DAILY_DUNGEON_DESCS = {
    "必出指定部位装备 (部位每日随机)",
    "必出指定套装装备 (可选择套装)",
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

-- 图鉴界面状态
codexBackBtnRect = nil    -- 图鉴界面返回按钮

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
    [1] = { cols = 4, rows = 4, imgW = 714, imgH = 1280 },  -- hero_cards.jpg (4×4)
    [2] = { cols = 3, rows = 3, imgW = 714, imgH = 1280 },  -- hero_cards_nobg.jpg (3×3)
    [4] = { cols = 4, rows = 4, imgW = 714, imgH = 1280 },  -- hero_cards_extra.jpg (4×4)
}
-- 计算每个精灵图的单格宽高比
for _, cfg in pairs(SHEET_CONFIG) do
    cfg.cellRatio = (cfg.imgW / cfg.cols) / (cfg.imgH / cfg.rows)
end
-- 无背景版精灵图的网格配置 (edited nobg 版本尺寸不同)
NOBG_SHEET_CONFIG = {
    [1] = { cols = 4, rows = 4, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_s1_nobg (4×4)
    [2] = { cols = 3, rows = 3, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_nobg (3×3, 含清泠法姬等)
    [4] = { cols = 4, rows = 4, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_extra_nobg (4×4)
}
for _, cfg in pairs(NOBG_SHEET_CONFIG) do
    cfg.cellRatio = (cfg.imgW / cfg.cols) / (cfg.imgH / cfg.rows)  -- ≈0.806
end
-- 装备精灵图参数 (7列=7套, 7行=7部位)
EQUIP_SHEET_COLS = 7
EQUIP_SHEET_ROWS = 7

-- 仓库格子容量
BASE_EQUIP_SLOTS = 20     -- 初始上限
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

-- 底部商店预留高度 (逻辑像素)
SHOP_RESERVED_H = 115

-- 相位切换防穿透冷却 (秒)
phaseChangeCooldown = 0

-- 透明版精灵图每格比例
NOBG_CELL_RATIO = (1237 / SHEET_COLS) / (1536 / SHEET_ROWS) -- 敌方 ≈0.806
-- 广告按钮区域
adRects = { jade = nil, refresh = nil, revive = nil, battleGold = nil }
autoMarchBtnRect = nil    -- 自动行军按钮
skillBtnRects = {}        -- 武技技能按钮 [slot] >> rect

-- 自动行军策略轮盘
strategyWheelState = {
    show = false,       -- 是否显示轮盘
    pressing = false,   -- 是否正在长按自动行军按钮
    startTime = 0,      -- 按下时间
    touchId = -1,       -- 触控ID
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
        title = "武灵录说明",
        color = { 80, 120, 160 },  -- 蓝色
        rules = {
            { "图鉴收集", "记录所有已发现的武灵，点击卡牌可查看详细属性。" },
            { "品质分类", "按品质筛选查看：白→绿→蓝→紫→金，便于快速定位。" },
            { "属性说明", "攻击力决定输出，防御力减少受伤，生命值决定存活时间。" },
            { "收集奖励", "收集一定数量武灵可解锁全局属性加成。" },
        },
    },
    STAGE_SELECT = {
        title = "乱世征途规则",
        color = { 160, 120, 60 },  -- 金色
        rules = {
            { "关卡挑战", "选择关卡进入战斗，击败敌方大本营即为通关。" },
            { "难度递增", "每一章节敌人属性逐步提升，需要合理搭配阵容。" },
            { "星级评价", "根据通关表现获得1-3星评价，星级越高奖励越丰厚。" },
            { "首通奖励", "首次通关每个关卡可获得额外英魂石和军资奖励。" },
            { "扫荡功能", "已满星通关的关卡可直接扫荡，快速获取奖励。" },
        },
    },
    ABYSS_SELECT = {
        title = "讨伐战令规则",
        color = { 160, 50, 50 },  -- 红色
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
        color = { 140, 100, 50 },  -- 棕金
        rules = {
            { "每日开放", "每天开放不同类型的试炼副本，挑战次数有限。" },
            { "副本类型", "军资试炼：大量军资奖励。经验试炼：大量经验奖励。材料试炼：稀有材料掉落。" },
            { "挑战次数", "每种副本每日可挑战有限次数，次日重置。" },
            { "难度选择", "可选择不同难度，难度越高奖励越丰厚。" },
        },
    },
    RANKED_SELECT = {
        title = "巅峰对决规则",
        color = { 200, 160, 50 },  -- 金色
        rules = {
            { "排位赛制", "与其他玩家的阵容进行对战，根据胜负调整排名。" },
            { "匹配机制", "系统根据战力和段位匹配相近实力的对手。" },
            { "赛季制度", "每赛季结束根据最终排名发放丰厚奖励。" },
            { "段位系统", "从青铜到王者，连胜可获得额外积分加成。" },
            { "每日次数", "每日挑战次数有限，合理安排出战时机。" },
        },
    },
    WELFARE = {
        title = "天命赐福说明",
        color = { 120, 60, 140 },  -- 深紫
        rules = {
            { "签到奖励", "每日登录签到可领取丰厚奖励，连续签到奖励更多。" },
            { "成长基金", "一次性购买可在达到指定等级时领取大量英魂石。" },
            { "限时活动", "定期开放限时活动，参与可获得专属奖励。" },
            { "在线奖励", "累计在线时间可领取额外奖励。" },
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

-- ============================================================================
-- 武技系统 (技能)
-- ============================================================================
SKILL_SHEET_COLS = 8       -- 序列帧列数
SKILL_SHEET_ROWS = 2       -- 序列帧行数
SKILL_FRAME_COUNT = 16     -- 总帧数
SKILL_IMG_W = 2048         -- 序列帧原始宽度
SKILL_IMG_H = 869          -- 序列帧原始高度

-- 武技序列帧 FX 系统
-- 每个条目: imgHandle(运行时填), cols, rows, totalFrames, fps, file
SKILL_FX_SHEETS = {
    -- iconIdx >> FX 配置 (每张图网格布局不同,已逐图像素分析)
    -- crop: 单元格内实际内容的联合边界 (PIL alpha getbbox 分析, 已按压缩后尺寸更新)
    [1]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_1_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 蚀骨针 (1536×1030, 8×2, cell=192×515)
    [2]  = { handle = -1, cols = 4, rows = 2, frames = 8, fps = 12,
             file = "image/skill_fx_yinghuoluoren.png",
             crop = { x=18, y=1, w=345, h=303 } },           -- 萤火落刃 (1500×636, 4×2, cell=375×318, 未缩放)
    [26] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_fx_thunder.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=308 } },            -- 九霄雷穿 (1536×651, 8×2, cell=192×326, ×0.75)
    [19] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_19_sheet_20260409160423.png", origW = 1537,
             crop = { x=0, y=0, w=192, h=326 } },            -- 烽火燎原 (1537×652, 8×2, cell=192×326) 重制版
    [20] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_20_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=326 } },            -- 赤壁焚域 (1536×652, 8×2, cell=192×326)
    [3]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_fx_ghostclaw.png", origW = 1536,
             crop = { x=0, y=52, w=192, h=466 } },           -- 幽爪探地 (1536×651, 8×1, cell=192×651, ×0.75)
    [4]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 12,
             file = "image/skill_4_sheet.png", origW = 2048,
             crop = { x=15, y=0, w=231, h=428 } },            -- 凝冰一线 (2048×869, 8×2, cell=256×434, 去白底+文字)
    [5]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_lightning_sheet.png",
             crop = { x=3, y=61, w=179, h=588 } },            -- 引雷丝 (1536×651, 8×1, cell=192×651, ×0.75)
    [6]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_wind_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 腐风斩 (1536×1030, 8×2, cell=192×515)
    [7]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_7_sheet.png",
             crop = { x=20, y=67, w=157, h=468 } },           -- 玄极穿云剑诀 (1500×636, 8×1, cell=187×636, 未缩放)
    [34] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_34_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=258 } },             -- 箭雨漫天 (1536×1030, 4×4, cell=384×258)
    [13] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_13_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 万箭坠阵 (1536×1536, 4×4, cell=384×384)
    [16] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_16_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 灵泉回春 (1536×1536, 4×4, cell=384×384)
    [21] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_21_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 冰狱封阵 (1536×1536, 4×4, cell=384×384)
    [15] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_15_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 天雷罚域 (1536×1536, 4×4, cell=384×384)
    [11] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_11_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=293 } },             -- 地刺连探 (1536×586, 8×2, cell=192×293, ×0.75)
    [31] = { handle = -1, cols = 9, rows = 4, frames = 36, fps = 18,
             file = "image/skill_31_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=170, h=163 } },             -- 九天化龙万域 (1536×652, 9×4, cell=170×163)
    [10] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_10_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 奔雷穿垣 (1536×1030, 8×2, cell=192×515)
    [17] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_fx_17.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 玄蚀径 (1536×1030, 8×2, cell=192×515)
    [8]  = { handle = -1, cols = 4, rows = 2, frames = 8, fps = 12,
             file = "image/skill_fx_8.png", origW = 1500,
             crop = { x=21, y=5, w=347, h=273 } },            -- 荆棘缠地 (1500×636, 4×2, cell=375×318)
    [9]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_9_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 寒棱贯骨 (1536×1030, 8×2, cell=192×515)
    [12] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_12_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 飞刃连梭 (1536×1030, 8×2, cell=192×515)
    [14] = { handle = -1, cols = 6, rows = 4, frames = 23, fps = 12,
             file = "image/skill_14_sheet.png", origW = 1536,
             crop = { x=0, y=4, w=254, h=249 } },             -- 寒渊冰封 (1536×1030, 6×4, cell=256×257, ×0.75)
    [23] = { handle = -1, cols = 6, rows = 4, frames = 24, fps = 12,
             file = "image/skill_23_sheet.png", origW = 1536,
             crop = { x=6, y=12, w=244, h=237 } },            -- 破军噬魂印 (1536×1030, 6×4, cell=256×257, ×0.75)
    [22] = { handle = -1, cols = 6, rows = 4, frames = 24, fps = 12,
             file = "image/skill_22_sheet.png", origW = 2048,
             crop = { x=3, y=6, w=336, h=334 } },             -- 22号武技 (2048×1374, 6×4, cell=341×343, 直接使用)
    [24] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_24_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 镇军碑压 (1536×1536, 4×4, cell=384×384)
    -- ▼ 以下为 AI 生成的武技序列帧 ▼
    -- 线性技能 (8×2, 1536×1030, cell=192×515)
    [18] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_18_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 碎岩冲击 (1536×1030, 8×2, cell=192×515)
    [25] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_25_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 龙吟贯索 (1536×1030, 8×2, cell=192×515)
    [27] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_27_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 极寒冰封贯空 (1536×1030, 8×2, cell=192×515)
    [28] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_28_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 武灵剑贯三界 (1536×1030, 8×2, cell=192×515)
    -- 大型AOE技能 (4×4, 1536×1536, cell=384×384)
    [29] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_29_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 远古龙魂踏地 (1536×1536, 4×4, cell=384×384)
    [30] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_30_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 万灵归墟衍域 (1536×1536, 4×4, cell=384×384)
    [32] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_32_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 天命雷音 (1536×1536, 4×4, cell=384×384)
    [33] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_33_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 千军冻绝冰域 (1536×1536, 4×4, cell=384×384)
    [35] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_35_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 不灭天域 (1536×1536, 4×4, cell=384×384)
    [36] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_36_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 天命灭世诀 (1536×1536, 4×4, cell=384×384)
}
-- skillFxTimer 存储在 menuAnimTimer 中复用，无需独立变量

-- 武技定义
-- 武技战斗数据 (按 SKILL_TECHNIQUES 索引, 在 SKILL_TECHNIQUES 定义后生成)
SKILL_DEFS = {}  -- [techniqueIdx] >> battle data

-- 武技运行时状态
skillTargeting = {
    active = false,              -- 是否正在瞄准(拖拽中)
    skillIdx = 0,                -- 正在瞄准的技能索引
    sx = 0, sy = 0,              -- 屏幕原始坐标
    dx = 0, dy = 0,              -- 目标设计坐标
    touchId = -1,
}

-- 场上活跃的技能特效
activeSkillEffects = {}    -- { x, y, skillIdx, timer, frameIdx, damaged, isEnemySkill? }
-- AI对手武技技能系统 (排位/讨伐模式)
aiSkillState = {
    enabled = false,           -- 是否启用AI技能
    availableSkills = {},      -- 可用技能列表 (SKILL_DEFS索引)
    cooldowns = {},            -- 各技能独立冷却 { [skillIdx] = remainingCD }
    castTimer = 0,             -- AI释放间隔计时器
    castInterval = 6.0,        -- AI每次释放技能的间隔(秒)
    nextCastTime = 4.0,        -- 下次释放时间(首次延迟)
}
-- 奖励弹窗确认按钮
rewardPopupConfirmRect = nil
rewardAdDoubleRect = nil  -- 看广告翻倍按钮
exploreAdDoubleJade = false  -- 探索撤离广告翻倍虎符标记

-- 武灵详情页状态
heroDetailState = {
    cardIdx = 0,       -- 当前查看的英雄索引
}
heroDetailBackBtnRect = nil
heroDetailScroll = { y = 0, vel = 0, isDragging = false, dragStartY = 0, dragLastY = 0 }
playerDetailScroll = { y = 0, vel = 0, isDragging = false, dragStartY = 0, dragLastY = 0 }

-- 玩家详情页状态
playerDetailBtnRect = nil  -- 首页点击头像进入
playerDetailBackBtnRect = nil

-- 图鉴卡牌区域 (用于点击检测)
codexCardRects = {}
codexScroll = {
    y = 0,              -- 武灵录滚动偏移
    vel = 0,            -- 滚动惯性速度
    dragStartY = nil,   -- 触摸拖动起始Y
    dragLastY = nil,    -- 上一帧触摸Y
    isDragging = false, -- 是否正在拖动
}
codexTab = 0  -- 图鉴标签页: 0=全部, 1=N, 2=R, 3=SR, 4=SSR
codexTabRects = {}  -- 标签页按钮点击区域

-- ============================================================================
-- 武技系统 (展示用)
-- ============================================================================
SKILL_ICON_COLS = 6        -- 图标列数
SKILL_ICON_ROWS = 6        -- 图标行数

-- 每个图标在精灵图中的实际内容边界 (基于像素分析)
-- bx,by = 内容左上角在250×250单元格内的偏移, bw,bh = 内容宽高
SKILL_ICON_BBOX = {}
for i = 1, 36 do
    SKILL_ICON_BBOX[i] = {bx=0, by=0, bw=250, bh=250}  -- 新图标带背景框，填满整个单元格
end

-- 武技阶级定义 (7阶: 凡→良→优→将→侯→王→帝)
SKILL_TIERS = {
    { name = "凡品", color = { 180, 175, 165 }, glowColor = { 140, 140, 140 }, count = 6 },
    { name = "良品", color = { 100, 210, 120 }, glowColor = { 60, 200, 60 },   count = 6 },
    { name = "优品", color = { 80, 160, 255 },  glowColor = { 60, 120, 255 },   count = 6 },
    { name = "将品", color = { 180, 100, 255 }, glowColor = { 170, 80, 255 }, count = 6 },
    { name = "侯品", color = { 255, 140, 0 },   glowColor = { 255, 120, 0 },  count = 6 },
    { name = "王品", color = { 255, 180, 50 },  glowColor = { 255, 150, 30 }, count = 5 },
    { name = "帝品", color = { 255, 80, 80 },   glowColor = { 255, 60, 60 },  count = 1 },
}

-- 36个武技完整数据
SKILL_TECHNIQUES = {
    -- 凡品 (1-6)
    { name = "破锋针", tier = 1, iconIdx = 1,
      desc = "凝聚锋锐之力化作利针，刺向单个敌人，伤害精准但覆盖极小。" },
    { name = "烽火附身", tier = 1, iconIdx = 2,
      desc = "引燃战火附于兵刃之上，短距离直线挥出，灼烧敌军。" },
    { name = "地裂探阵", tier = 1, iconIdx = 3,
      desc = "催发地脉之力从地底探出，抓击脚下小片区域的敌人。" },
    { name = "霜锋一线", tier = 1, iconIdx = 4,
      desc = "将寒气凝聚于一线，沿直线冻结短距离内的敌人。" },
    { name = "缚敌丝", tier = 1, iconIdx = 5,
      desc = "引出一缕缚敌细丝，击中前方最近的一个敌人。" },
    { name = "旋风斩", tier = 1, iconIdx = 6,
      desc = "以凌厉风刃横扫，短距离内切割前方敌人。" },

    -- 良品 (7-12)
    { name = "穿心箭", tier = 2, iconIdx = 7,
      desc = "利矢穿心而出，沿中等直线贯穿多个敌人。" },
    { name = "荆棘缠地", tier = 2, iconIdx = 8,
      desc = "召唤荆棘蔓延地面，形成小型地面域，持续伤害踩入其中的敌人。" },
    { name = "寒棱贯骨", tier = 2, iconIdx = 9,
      desc = "以冰棱沿直线射出，贯穿中等距离内所有敌人。" },
    { name = "奔雷穿垣", tier = 2, iconIdx = 10,
      desc = "天雷化作穿透射线，忽略障碍直线贯穿敌群。" },
    { name = "地刺连探", tier = 2, iconIdx = 11,
      desc = "连续催发地刺探出地面，沿短距直线造成多段伤害。" },
    { name = "飞刃连梭", tier = 2, iconIdx = 12,
      desc = "多道飞刃梭形连发，沿中距直线切割一切。" },

    -- 优品 (13-18)
    { name = "万箭坠阵", tier = 3, iconIdx = 13,
      desc = "万千箭矢从天而降，覆盖标准圆形区域，密集打击范围内敌人。" },
    { name = "寒渊冰封", tier = 3, iconIdx = 14,
      desc = "寒渊之力冰封一方，在中等地面域中冻结并伤害敌人。" },
    { name = "天雷罚域", tier = 3, iconIdx = 15,
      desc = "五道天雷汇聚，化为雷电领域覆盖标准范围，电击域内所有敌人。" },
    { name = "灵泉回春", tier = 3, iconIdx = 16,
      desc = "灵泉之力化为回春之阵，区域内己方武灵持续回复生命。" },
    { name = "玄蚀径", tier = 3, iconIdx = 17,
      desc = "玄力侵蚀路径，在标准直线范围内吞噬一切生灵。" },
    { name = "碎岩冲击", tier = 3, iconIdx = 18,
      desc = "岩力爆发冲击前方，标准距离贯穿敌人并击飞。" },

    -- 将品 (19-24)
    { name = "烽火燎原", tier = 4, iconIdx = 19,
      desc = "烽火漫燃形成火域，大型地面域持续焚烧域内一切敌军。" },
    { name = "赤壁焚域", tier = 4, iconIdx = 20,
      desc = "赤壁烈焰蔓延大型区域，天火焚烧域内一切敌人。" },
    { name = "冰狱封阵", tier = 4, iconIdx = 21,
      desc = "极寒之力封锁大片疆域，冰封域内所有敌人。" },
    { name = "雷狱囚阵", tier = 4, iconIdx = 22,
      desc = "天雷织成囚笼，大型区域内敌人无处可逃，持续受雷击。" },
    { name = "破军噬魂印", tier = 4, iconIdx = 23,
      desc = "破军印记标记大范围敌人，增强贯穿力穿透任何防御。" },
    { name = "镇军碑压", tier = 4, iconIdx = 24,
      desc = "镇军之力镇压大地，大型区域内敌人被重力碾压。" },

    -- 侯品 (25-30) — 复用王品图标
    { name = "龙吟贯索", tier = 5, iconIdx = 25,
      desc = "龙吟之力化为贯索，超长距离直线贯穿，穿透一切阻挡。" },
    { name = "九天雷穿", tier = 5, iconIdx = 26,
      desc = "九天神雷聚为一束，超长直线穿透，雷威浩荡无可匹敌。" },
    { name = "极寒冰封贯空", tier = 5, iconIdx = 27,
      desc = "绝对零度凝成寒光贯穿天地，超长直线冻碎一切。" },
    { name = "武灵剑贯三界", tier = 5, iconIdx = 28,
      desc = "绝世剑意化为武灵之剑，贯穿三界的超长直线攻击。" },
    { name = "远古龙魂踏地", tier = 5, iconIdx = 29,
      desc = "远古龙魂之影踏碎大地，全区域地面被震碎压制。" },
    { name = "万灵归墟衍域", tier = 5, iconIdx = 30,
      desc = "万灵归于虚墟，衍生出覆盖全区域的毁灭领域。" },

    -- 王品 (31-35)
    { name = "九天化龙万域", tier = 6, iconIdx = 31,
      desc = "九天之力化身龙域，全地图笼罩于无尽天威之中。" },
    { name = "天命雷音", tier = 6, iconIdx = 32,
      desc = "天命之雷贯彻天地，涤荡苍生的神雷覆盖全图。" },
    { name = "千军冻绝冰域", tier = 6, iconIdx = 33,
      desc = "千军尽冻的绝对冰域，全地图被永恒寒冰封印。" },
    { name = "箭雨漫天", tier = 6, iconIdx = 34,
      desc = "万箭归一后漫天箭雨，全地图无差别箭矢洗礼。" },
    { name = "不灭天域", tier = 6, iconIdx = 35,
      desc = "不灭之力化为天域，全地图敌人被天命之力反噬。" },

    -- 帝品 (36) — 唯一终极武技
    { name = "天命灭世诀", tier = 7, iconIdx = 36,
      desc = "天命本源化为终焉之火，焚尽天地万物的终极武技。" },
}

-- 根据阶级生成武技战斗属性 (7阶: 凡→良→优→将→侯→王→帝)
TIER_BATTLE_STATS = {
    { damage = 300,  radius = 70,  maxCooldown = 8,  renderSize = 120 }, -- 凡品 (小型)
    { damage = 550,  radius = 85,  maxCooldown = 9,  renderSize = 120 }, -- 良品 (小型)
    { damage = 900,  radius = 100, maxCooldown = 10, renderSize = 200 }, -- 优品 (中型)
    { damage = 1400, radius = 115, maxCooldown = 11, renderSize = 200 }, -- 将品 (中型)
    { damage = 1800, radius = 130, maxCooldown = 12, renderSize = 250 }, -- 侯品 (中大型)
    { damage = 2500, radius = 150, maxCooldown = 13, renderSize = 350 }, -- 王品 (大型)
    { damage = 3800, radius = 175, maxCooldown = 15, renderSize = 400 }, -- 帝品 (全屏)
}

-- 线型技能的 iconIdx 集合 (蚀骨针等沿行军路线飞行的技能)
LINE_SKILL_ICONS = { [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [18] = true, [25] = true, [27] = true, [28] = true }  -- iconIdx=1 >> 破锋针, 4 >> 霜锋一线, 5 >> 缚敌丝, 6 >> 旋风斩, 7 >> 穿心箭, 18 >> 碎岩冲击, 25 >> 龙吟贯索, 27 >> 极寒冰封贯空, 28 >> 武灵剑贯三界

-- 矩形技能的 iconIdx >> 矩形尺寸 (宽×高, 设计坐标)
RECT_SKILL_ICONS = {
    [34] = { w = 560, h = 272 },  -- 箭雨漫天: 大型矩形箭雨
    [17] = { w = 400, h = 400 },  -- 玄蚀径: 矩形横跨两条行军路线,持续伤害
}
-- 超大圆形AOE (覆盖全场)
BIG_AOE_ICONS = {
    [31] = { radius = 280, renderSize = 560 },  -- 九天化龙万域: 超大圆形覆盖五条行军路线
    [29] = { radius = 250, renderSize = 500 },  -- 远古龙魂踏地: 大型冲击波
    [30] = { radius = 280, renderSize = 560 },  -- 万灵归墟衍域: 英魂风暴覆盖全域
    [32] = { radius = 300, renderSize = 600 },  -- 天命雷音: 雷暴覆盖全域
    [33] = { radius = 300, renderSize = 600 },  -- 千军冻绝冰域: 冰封全域
    [35] = { radius = 320, renderSize = 640 },  -- 不灭天域: 天域结界
    [36] = { radius = 350, renderSize = 700 },  -- 天命灭世诀: 终极武技最大范围
}

-- 治疗技能的 iconIdx 集合 (底层渲染, 中间帧延长, 治疗己方)
HEAL_SKILL_ICONS = { [16] = true }  -- iconIdx=16 >> 灵泉回春

-- 区域技能 (底层渲染, 持续伤害+减速, 类似治疗但对敌方)
ZONE_SKILL_ICONS = {
    [21] = { slowFactor = 0.4, dmgPerTick = 10, tickInterval = 0.5 },  -- 冰狱封阵: 减速40%+持续伤害
    [8]  = { slowFactor = 0.5, dmgPerTick = 5,  tickInterval = 0.5 },  -- 荆棘缠地: 减速50%+轻微持续伤害
}

-- 构建全部36个武技的战斗数据 (开挂: 全部解锁)
for i, tech in ipairs(SKILL_TECHNIQUES) do
    local ts = TIER_BATTLE_STATS[tech.tier]
    local tc = SKILL_TIERS[tech.tier].color
    local isLine = LINE_SKILL_ICONS[tech.iconIdx]
    local isRect = RECT_SKILL_ICONS[tech.iconIdx]
    local isHeal = HEAL_SKILL_ICONS[tech.iconIdx]
    local isZone = ZONE_SKILL_ICONS[tech.iconIdx]
    local isBigAoe = BIG_AOE_ICONS[tech.iconIdx]
    -- AOE/rect 动画时长: 用序列帧的 frames/fps, 无序列帧回退 1.0s
    local fxData = SKILL_FX_SHEETS[tech.iconIdx]
    local baseDur = (fxData and fxData.frames and fxData.fps) and (fxData.frames / fxData.fps) or 1.0
    -- 治疗/区域技能: 中间帧延长, 总时长 = 基础时长 + 额外停留时间
    local hasTickDmg = isRect and isRect.w and SKILL_FX_SHEETS[tech.iconIdx] and SKILL_FX_SHEETS[tech.iconIdx].crop
    local aoeDur = (isHeal or isZone or hasTickDmg) and (baseDur + 3.0) or baseDur
    local skillType = "aoe"
    if isHeal then
        skillType = "heal"
    elseif isZone then
        skillType = "zone"
    elseif isRect then
        skillType = "rect"
    elseif isLine then skillType = "line" end
    SKILL_DEFS[i] = {
        name = tech.name,
        desc = tech.desc,
        unlocked = false,        -- 默认未解锁, 需通过广告/奖励获取
        notAvailable = (SKILL_FX_SHEETS[tech.iconIdx] == nil),  -- 无特效的武技标记为暂未开放
        cooldown = 0,
        maxCooldown = ts.maxCooldown,
        damage = ts.damage,
        radius = isLine and 40 or ts.radius,         -- 线型技能横向命中宽度较窄
        renderSize = isLine and 40 or ts.renderSize,  -- 线型技能精灵渲染尺寸
        animDuration = aoeDur,                        -- 动画恰好播完一轮序列帧
        damageFrame = 5,
        color = { tc[1], tc[2], tc[3] },
        iconIdx = tech.iconIdx,
        skillType = skillType,
        lineWidth = isLine and 50 or nil,             -- 线型技能命中宽度
        renderBehind = not isLine,                     -- 除线性技能外，全部在单位下方渲染
    }
    -- 矩形技能覆盖
    if isRect then
        SKILL_DEFS[i].rectW = isRect.w
        SKILL_DEFS[i].rectH = isRect.h
        SKILL_DEFS[i].damage = 3500   -- 矩形大范围技能增伤
    end
    -- 夜影蚀径: 矩形+持续伤害 (横跨两条行军路线)
    if tech.iconIdx == 17 then
        SKILL_DEFS[i].dmgPerTick = 20        -- 每tick持续伤害
        SKILL_DEFS[i].tickInterval = 0.5     -- tick间隔
        SKILL_DEFS[i].renderBehind = true    -- 底层渲染
    end
    -- 超大圆形AOE覆盖 (31九幽化魔: 覆盖全场, 底层渲染)
    if isBigAoe then
        SKILL_DEFS[i].radius = isBigAoe.radius
        SKILL_DEFS[i].renderSize = isBigAoe.renderSize
        SKILL_DEFS[i].renderBehind = true
        SKILL_DEFS[i].damage = 3500
    end
    -- 治疗技能覆盖
    if isHeal then
        SKILL_DEFS[i].radius = 65        -- 中型技能缩小范围
        SKILL_DEFS[i].renderSize = 130
        SKILL_DEFS[i].healPerTick = 15   -- 每次治疗量
        SKILL_DEFS[i].healInterval = 0.5 -- 每0.5秒治疗一次
    end
    -- 区域技能覆盖 (冰狱封疆: 持续伤害+减速)
    if isZone then
        SKILL_DEFS[i].slowFactor = isZone.slowFactor      -- 减速比例 (0.4 = 减速40%)
        SKILL_DEFS[i].dmgPerTick = isZone.dmgPerTick      -- 每tick伤害
        SKILL_DEFS[i].tickInterval = isZone.tickInterval   -- tick间隔
    end
    -- 九幽雷穿: 狱阶扩大1.25倍
    if tech.iconIdx == 26 then
        SKILL_DEFS[i].radius = math.floor(ts.radius * 1.25)
        SKILL_DEFS[i].renderSize = math.floor(ts.renderSize * 1.25)
    end
end

-- 玩家已装备的武技 (最多2个, SKILL_TECHNIQUES 索引)
playerEquippedSkills = {}  -- 默认无装备武技(全部未解锁)

-- 武技界面状态
skillCodexState = {
    scrollY = 0,
    scrollVel = 0,
    dragStartY = nil,
    dragLastY = nil,
    isDragging = false,
    selectedIdx = 0,      -- 当前查看的武技索引
}
skillCodexBackBtnRect = nil
skillCodexCardRects = {}
skillDetailBackBtnRect = nil
skillDetailMiniRects = {}    -- 详情页底部同阶预览点击区域
skillDetailEquipBtnRect = nil      -- 详情页装备/卸下按钮
skillDetailEquipSlotBtns = {}     -- 详情页替换槽位按钮 (满2槽时显示)
skillDetailUpgradeBtnRect = nil   -- 详情页升层按钮
-- menuSkillCodexBtnRect / menuWelfareBtnRect 已合并到 menuBtnRects
welfareState = {
    backBtnRect = nil,        -- 福利页返回按钮
    -- 三日签到
    signInClaimed = {false, false, false},  -- 每天是否已领取
    signInTimestamps = {0, 0, 0},             -- 每天领取时的 os.time() 时间戳
    signInBtnRects = {},      -- 签到按钮区域
    -- 十日签到（每日广告领5000虎符）
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
        freeUsed = false,     -- 免费翻牌是否已用
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
    -- 桩逼王排行榜 (打桩伤害排行)
    dummyRank = nil,           -- 排行榜数据缓存 (数组 {name, damage, userId})
    dummyLoading = false,
    dummyLoaded = false,
    dummyScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
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
        content = "武灵大人，感谢你踏入这片乱世！初次相遇，赠你3000虎符（约100抽），愿助你召集天下英杰、征战四方！此礼终身仅可领取一次，祝旗开得胜！",
        rewards = {
            { type = "jade", amount = 3000, label = "虎符 ×3000" },
        },
    },
    {
        id = "self_recommend",
        title = "自荐信",
        sender = "制作人",
        content = "这是一个非常费心血的小游戏，感恩相遇，也希望大家能多多好评，可以加群一起交流优化方向，如果您的朋友也喜欢这个题材，请一定帮我推荐给他！！！感恩！",
        rewards = {
            { type = "jade", amount = 2000, label = "虎符 ×2000" },
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
            { maxRank = 1,  rewards = { { type = "jade", amount = 500, label = "虎符 ×500" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 300, label = "虎符 ×300" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 150, label = "虎符 ×150" } } },
            { maxRank = 20, rewards = { { type = "jade", amount = 80,  label = "虎符 ×80" } } },
        },
    },
    {
        name = "境界榜", key = PROJECT_PREFIX .. "realm_level",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 500, label = "虎符 ×500" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 300, label = "虎符 ×300" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 150, label = "虎符 ×150" } } },
            { maxRank = 20, rewards = { { type = "jade", amount = 80,  label = "虎符 ×80" } } },
        },
    },
    {
        name = "爬塔榜", key = PROJECT_PREFIX .. "tower_floor",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 400, label = "虎符 ×400" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 200, label = "虎符 ×200" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 100, label = "虎符 ×100" } } },
        },
    },
    {
        name = "排位榜", key = PROJECT_PREFIX .. "ranked_score",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 400, label = "虎符 ×400" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 200, label = "虎符 ×200" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 100, label = "虎符 ×100" } } },
        },
    },
    {
        name = "桩逼王", key = PROJECT_PREFIX .. "dummy_damage",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 400, label = "虎符 ×400" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 200, label = "虎符 ×200" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 100, label = "虎符 ×100" } } },
        },
    },
}

-- ============================================================================
-- 兵种系统
-- ============================================================================
UNIT_CLASS = {
    SWORD   = { id = 1, name = "虎贲刀兵", sprite = "sword",   isRanged = false, atkRange = 40, speed = 30, atkCd = 0.9,
                breakDmg = 1, desc = "刀锋如虎，攻速凌厉杀敌无数" },
    ARCHER  = { id = 2, name = "连弩射手", sprite = "archer",  isRanged = true,  atkRange = 120, speed = 24, atkCd = 1.2,
                breakDmg = 1, desc = "劲弩齐发，百步穿杨射杀敌将" },
    SHIELD  = { id = 3, name = "铁盾重卫", sprite = "shield",  isRanged = false, atkRange = 35, speed = 20, atkCd = 0.7,
                breakDmg = 2, desc = "铁盾当关，驻守阵前拦截来敌" },
    MAGE    = { id = 4, name = "火攻术士", sprite = "mage",    isRanged = true,  atkRange = 110, speed = 22, atkCd = 1.4,
                breakDmg = 2, desc = "火攻之计，焚烧一切敌军营寨" },
    HEALER  = { id = 5, name = "军医道士", sprite = "healer",  isRanged = true,  atkRange = 130, speed = 18, atkCd = 1.8,
                breakDmg = 1, desc = "妙手回春，治愈我军伤兵残卒" },
    -- 大型/特殊单位
    CAVALRY  = { id = 9, name = "铁骑先锋", sprite = "cavalry",  isRanged = false, atkRange = 45, speed = 42, atkCd = 1.0,
                breakDmg = 4, spawnMax = 2, unitScale = 1.3, desc = "策马奔腾，极速冲锋撞碎敌阵" },
    BEAST    = { id = 10, name = "战象巨兽", sprite = "beast",   isRanged = false, atkRange = 50, speed = 14, atkCd = 1.5,
                breakDmg = 6, spawnMax = 1, unitScale = 1.8, desc = "南蛮战象，体魄雄壮势不可挡", hpMult = 2.5, atkMult = 1.5 },
    ASSASSIN = { id = 11, name = "夜行刺客", sprite = "assassin", isRanged = false, atkRange = 40, speed = 35, atkCd = 0.7,
                breakDmg = 3, spawnMax = 2, unitScale = 1.0, desc = "暗夜潜行，绕后包抄撕裂后排" },
    LANCER   = { id = 12, name = "长枪兵", sprite = "lancer",  isRanged = false, atkRange = 55, speed = 26, atkCd = 1.1,
                breakDmg = 2, spawnMax = 3, unitScale = 1.15, desc = "长枪如龙，一击可贯穿前后二敌" },
    -- 特殊兵种
    TALISMAN = { id = 13, name = "火牛突袭", sprite = "talisman", isRanged = false, atkRange = 30, speed = 38, atkCd = 99,
                breakDmg = 10, spawnMax = 3, unitScale = 0.9, desc = "火牛冲阵，冲向敌人引爆烈焰",
                isSuicider = true, explosionRadius = 60, explosionMult = 2.5 },
    PUPPETEER = { id = 14, name = "驯兽使", sprite = "puppeteer", isRanged = true, atkRange = 100, speed = 16, atkCd = 1.6,
                breakDmg = 1, spawnMax = 1, unitScale = 1.2, desc = "驱使猛兽助战，不断召唤走兽参战",
                summonCd = 4.0, summonMax = 4 },
    ICE_MAGE = { id = 15, name = "寒冰术士", sprite = "ice_mage", isRanged = true, atkRange = 105, speed = 20, atkCd = 1.5,
                breakDmg = 1, spawnMax = 2, unitScale = 1.0, desc = "寒冰侵蚀，冻结敌人行动与攻速",
                slowFactor = 0.4, slowDuration = 2.0 },
    SWARM    = { id = 16, name = "蜂巢蝗群", sprite = "swarm", isRanged = false, atkRange = 30, speed = 32, atkCd = 0.3,
                breakDmg = 1, spawnMax = 1, unitScale = 0.7, desc = "蝗群蜂拥而至，以数量淹没敌人",
                swarmCount = 6, hpMult = 0.15, atkMult = 0.4 },
    -- 敌方兵种
    DEMON_WARRIOR = { id = 6, name = "黄巾力士", sprite = "demon_warrior", isRanged = false, atkRange = 40, speed = 27, atkCd = 0.9,
                breakDmg = 1, desc = "蛮力惊人的黄巾贼兵，凶猛突袭" },
    DEMON_ARCHER  = { id = 7, name = "山贼弓手", sprite = "demon_archer",  isRanged = true,  atkRange = 110, speed = 23, atkCd = 1.1,
                breakDmg = 1, desc = "占山为王的弓手，淬毒远射" },
    DEMON_TANK    = { id = 8, name = "铁甲悍将", sprite = "demon_tank",    isRanged = false, atkRange = 35, speed = 18, atkCd = 0.8,
                breakDmg = 3, desc = "身披重铠的悍将，坚不可摧" },
}

local function MakeSlot(bgX, bgY)
    return { cx = bgX * BG2D_X, cy = bgY * BG2D_Y, filled = false, card = nil }
end

ENEMY_SLOTS = {
    MakeSlot(316, 77), MakeSlot(397, 77),
    MakeSlot(273, 199), MakeSlot(357, 199), MakeSlot(442, 199),
}

PLAYER_SLOTS = {
    MakeSlot(272, 1087), MakeSlot(357, 1087), MakeSlot(442, 1087),
    MakeSlot(186, 1205), MakeSlot(272, 1205), MakeSlot(358, 1205),
    MakeSlot(444, 1205), MakeSlot(528, 1205),
}

-- ============================================================================
-- 卡牌数据
-- ============================================================================
QUALITY = { COMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4, LIMITED = 5 }
QUALITY_NAMES = { "人", "地", "天", "神", "限" }
QUALITY_TAGS  = { "N", "R", "SR", "SSR", "限定SSR" }
QUALITY_COLORS = {
    [1] = { 200, 195, 180 },
    [2] = { 90, 210, 140 },
    [3] = { 170, 110, 255 },
    [4] = { 255, 190, 50 },
    [5] = { 255, 80, 120 },
}
QUALITY_GLOW = {
    [1] = { 200, 195, 180, 0 },
    [2] = { 90, 210, 140, 55 },
    [3] = { 170, 110, 255, 75 },
    [4] = { 255, 190, 50, 95 },
    [5] = { 255, 80, 120, 110 },
}

-- (CARD_COST 已移除, 角色通过广告抽卡获得)

CARD_TYPE = { ATK = 1, DEF = 2, HEAL = 3, BUFF = 4 }
TYPE_NAMES = { "攻", "御", "疗", "辅" }
TYPE_COLORS = {
    [1] = { 220, 70, 60 },
    [2] = { 70, 130, 230 },
    [3] = { 70, 210, 120 },
    [4] = { 230, 190, 50 },
}

HERO_CARDS = {
    -- =====================================================================
    -- 人武灵 (COMMON / N) — 1~10
    -- =====================================================================
    -- 1. 程普 — 吴国老将，铁脊矛
    { name = "程普", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero1",
      atk = 720, def = 350, hp = 6500, unitClass = "LANCER", skill = "铁脊穿刺",
      skillData = { cd = 9, kind = "line", mult = 2.0, desc = "铁脊矛直刺前方，直线穿刺造成200%伤害" } },
    -- 2. 黄盖 — 苦肉计火攻
    { name = "黄盖", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero2",
      atk = 750, def = 280, hp = 5500, unitClass = "TALISMAN", skill = "苦肉火攻",
      skillData = { cd = 8, kind = "aoe", mult = 2.5, radius = 70, desc = "以苦肉之计引燃烈火，对范围敌人造成250%伤害" } },
    -- 3. 韩当 — 弓骑将领
    { name = "韩当", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero3",
      atk = 680, def = 300, hp = 6000, unitClass = "ARCHER", skill = "连珠劲射",
      skillData = { cd = 7, kind = "targeted", mult = 1.5, hits = 4, desc = "连射4支劲箭，每箭造成150%伤害" } },
    -- 4. 廖化 — 蜀汉先锋
    { name = "廖化", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero4",
      atk = 700, def = 350, hp = 6500, unitClass = "SWORD", skill = "先锋突击",
      skillData = { cd = 7, kind = "targeted", mult = 1.8, hits = 3, desc = "先锋三连斩，每击造成180%伤害" } },
    -- 5. 周仓 — 扛刀护卫
    { name = "周仓", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero5",
      atk = 500, def = 650, hp = 8500, unitClass = "SHIELD", skill = "扛刀守护",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.20, duration = 6, desc = "以青龙刀护卫全军，施加20%最大生命护盾，持续6秒" } },
    -- 6. 糜竺 — 粮草官辅助
    { name = "糜竺", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.COMMON, singleImg = "hero6",
      atk = 450, def = 380, hp = 7000, unitClass = "HEALER", skill = "粮草补给",
      skillData = { cd = 10, kind = "heal", healMult = 0.15, goldBonus = 2, desc = "运送粮草补给全军，恢复15%最大生命，额外获得2军资" } },
    -- 7. 曹洪 — 护卫将领
    { name = "曹洪", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero7",
      atk = 520, def = 600, hp = 8000, unitClass = "SHIELD", skill = "舍身护主",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.18, duration = 6, desc = "舍身挡刀，全体友军施加18%最大生命护盾，持续6秒" } },
    -- 8. 李典 — 沉稳步将
    { name = "李典", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero8",
      atk = 680, def = 380, hp = 6800, unitClass = "SWORD", skill = "沉刀斩",
      skillData = { cd = 8, kind = "targeted", mult = 2.0, desc = "沉稳一刀斩下，对单体造成200%伤害" } },
    -- 9. 张任 — 伏弓守将
    { name = "张任", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero9",
      atk = 700, def = 320, hp = 6200, unitClass = "ARCHER", skill = "伏击箭雨",
      skillData = { cd = 9, kind = "aoe", mult = 1.8, radius = 75, desc = "设伏发箭，范围箭雨造成180%伤害" } },
    -- 10. 纪灵 — 三尖刀武将
    { name = "纪灵", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero10",
      atk = 730, def = 340, hp = 6600, unitClass = "LANCER", skill = "三尖刺杀",
      skillData = { cd = 8, kind = "targeted", mult = 2.2, desc = "三尖两刃刀猛刺，对单体造成220%伤害" } },

    -- =====================================================================
    -- 地武灵 (RARE / R) — 11~22
    -- =====================================================================
    -- 11. 太史慈 — 东吴神射
    { name = "太史慈", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero11",
      atk = 950, def = 360, hp = 6800, unitClass = "ARCHER", skill = "神射穿杨",
      skillData = { cd = 8, kind = "targeted", mult = 2.8, desc = "百步穿杨的神射之技，对单体造成280%伤害" } },
    -- 12. 甘宁 — 锦帆刺客
    { name = "甘宁", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero12",
      atk = 980, def = 330, hp = 6500, unitClass = "ASSASSIN", skill = "锦帆突袭",
      skillData = { cd = 7, kind = "targeted", mult = 2.0, hits = 3, desc = "锦帆飞刀连发，攻击3个敌人各造成200%伤害" } },
    -- 13. 徐晃 — 大斧将军
    { name = "徐晃", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero13",
      atk = 880, def = 450, hp = 7500, unitClass = "SWORD", skill = "大斧横扫",
      skillData = { cd = 9, kind = "aoe", mult = 2.2, radius = 90, desc = "巨斧横劈，对范围敌人造成220%伤害" } },
    -- 14. 张郃 — 枪法精妙
    { name = "张郃", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero14",
      atk = 900, def = 550, hp = 8000, unitClass = "LANCER", skill = "妙枪连刺",
      skillData = { cd = 9, kind = "line", mult = 2.5, desc = "枪法精妙，直线穿刺造成250%伤害" } },
    -- 15. 魏延 — 反骨猛将
    { name = "魏延", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero15",
      atk = 1050, def = 380, hp = 7800, unitClass = "SWORD", skill = "反骨狂斩",
      skillData = { cd = 10, kind = "aoe", mult = 2.5, radius = 85, desc = "狂性大发挥刀乱斩，对范围敌人造成250%伤害" } },
    -- 16. 关平 — 青年继承者
    { name = "关平", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero16",
      atk = 920, def = 400, hp = 7200, unitClass = "SWORD", skill = "承父刀法",
      skillData = { cd = 8, kind = "targeted", mult = 2.6, desc = "传承关公刀法，对单体造成260%伤害" } },
    -- 17. 高顺 — 陷阵之志
    { name = "高顺", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero17",
      atk = 480, def = 950, hp = 12500, unitClass = "SHIELD", skill = "陷阵壁垒",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.22, duration = 6, desc = "陷阵营列阵，全体友军施加22%最大生命护盾，持续6秒" } },
    -- 18. 文丑 — 骑将猛冲
    { name = "文丑", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero18",
      atk = 1000, def = 420, hp = 7600, unitClass = "CAVALRY", skill = "猛骑冲阵",
      skillData = { cd = 10, kind = "line", mult = 2.5, desc = "策马冲锋，直线路径上造成250%伤害" } },
    -- 19. 颜良 — 勇武猛将
    { name = "颜良", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero19",
      atk = 980, def = 400, hp = 7400, unitClass = "SWORD", skill = "虎威劈斩",
      skillData = { cd = 9, kind = "targeted", mult = 2.8, desc = "虎威劈斩一击致命，对单体造成280%伤害" } },
    -- 20. 邓艾 — 偷渡奇袭
    { name = "邓艾", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero20",
      atk = 950, def = 350, hp = 6800, unitClass = "ASSASSIN", skill = "偷渡奇袭",
      skillData = { cd = 8, kind = "targeted", mult = 3.0, desc = "偷渡阴平直取后方，对单体造成300%伤害" } },
    -- 21. 钟会 — 谋略军师
    { name = "钟会", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero21",
      atk = 800, def = 600, hp = 8500, unitClass = "MAGE", skill = "连环妙计",
      skillData = { cd = 12, kind = "debuff", atkReduce = 0.25, duration = 7, desc = "施展连环计，全体敌人攻击降低25%，持续7秒" } },
    -- 22. 陆抗 — 防御名将
    { name = "陆抗", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero22",
      atk = 500, def = 1050, hp = 13000, unitClass = "SHIELD", skill = "西陵壁垒",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.25, duration = 6, desc = "筑建西陵防线，全体友军施加25%最大生命护盾，持续6秒" } },

    -- =====================================================================
    -- 天武灵 (EPIC / SR) — 23~30
    -- =====================================================================
    -- 23. 典韦 — 双戟猛将
    { name = "典韦", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero23",
      atk = 1350, def = 600, hp = 10200, unitClass = "SWORD", skill = "双戟绝杀",
      skillData = { cd = 12, kind = "aoe", mult = 2.8, radius = 100, desc = "双铁戟旋风横扫，对范围敌人造成280%伤害" } },
    -- 24. 许褚 — 虎痴护卫
    { name = "许褚", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.EPIC, singleImg = "hero24",
      atk = 800, def = 1100, hp = 15000, unitClass = "SHIELD", skill = "虎痴怒吼",
      skillData = { cd = 16, kind = "buff", shieldMult = 0.30, defBuff = 0.25, duration = 8, desc = "虎痴怒吼震慑敌军，全体+30%护盾+25%防御，持续8秒" } },
    -- 25. 孙策 — 小霸王冲锋
    { name = "孙策", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero25",
      atk = 1200, def = 500, hp = 9500, unitClass = "CAVALRY", skill = "霸王冲锋",
      skillData = { cd = 13, kind = "line", mult = 3.0, desc = "小霸王策马冲锋，直线路径造成300%伤害" } },
    -- 26. 夏侯惇 — 拔矢猛将
    { name = "夏侯惇", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero26",
      atk = 1100, def = 700, hp = 11000, unitClass = "SWORD", skill = "拔矢啖睛",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.20, duration = 8, desc = "拔矢之勇激励全军，全体友军攻击提升20%，持续8秒" } },
    -- 27. 夏侯渊 — 急袭将军
    { name = "夏侯渊", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero27",
      atk = 1200, def = 400, hp = 8500, unitClass = "ASSASSIN", skill = "急袭千里",
      skillData = { cd = 8, kind = "targeted", mult = 3.5, desc = "千里急袭直取敌将首级，对单体造成350%伤害" } },
    -- 28. 马超 — 枪骑无双
    { name = "马超", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero28",
      atk = 1300, def = 480, hp = 9000, unitClass = "CAVALRY", skill = "枪骑天下",
      skillData = { cd = 13, kind = "line", mult = 3.2, desc = "西凉枪骑席卷战场，直线造成320%伤害" } },
    -- 29. 黄忠 — 神箭老将
    { name = "黄忠", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero29",
      atk = 1250, def = 420, hp = 8200, unitClass = "ARCHER", skill = "百步穿甲",
      skillData = { cd = 10, kind = "targeted", mult = 4.0, desc = "老将百步穿甲箭，对单体造成400%伤害" } },
    -- 30. 张辽 — 威震逍遥
    { name = "张辽", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero30",
      atk = 1150, def = 650, hp = 10500, unitClass = "CAVALRY", skill = "威震逍遥津",
      skillData = { cd = 14, kind = "aoe", mult = 2.6, radius = 95, desc = "八百骑突袭十万军，对范围敌人造成260%伤害" } },

    -- =====================================================================
    -- 神武灵 (LEGENDARY / SSR) — 31~36
    -- =====================================================================
    -- 31. 赵云 — 常山龙胆
    { name = "赵云", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero31",
      atk = 1450, def = 650, hp = 11000, unitClass = "LANCER", skill = "七进七出",
      skillData = { cd = 14, kind = "aoe", mult = 3.5, radius = 120, desc = "常山赵子龙七进七出，对范围敌人造成350%伤害" } },
    -- 32. 张飞 — 万人莫敌
    { name = "张飞", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero32",
      atk = 1400, def = 550, hp = 9500, unitClass = "SWORD", skill = "万人敌吼",
      skillData = { cd = 14, kind = "targeted", mult = 5.0, desc = "燕人张翼德一声怒吼，对单体造成500%伤害" } },
    -- 33. 关羽 — 武圣降临
    { name = "关羽", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero33",
      atk = 1500, def = 600, hp = 10500, unitClass = "SWORD", skill = "青龙斩月",
      skillData = { cd = 15, kind = "aoe", mult = 3.8, radius = 110, desc = "青龙偃月刀横扫千军，对范围敌人造成380%伤害" } },
    -- 34. 周瑜 — 火烧赤壁
    { name = "周瑜", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero34",
      atk = 1300, def = 500, hp = 8800, unitClass = "MAGE", skill = "火烧赤壁",
      skillData = { cd = 15, kind = "debuff", defReduce = 0.35, duration = 8, desc = "赤壁烈焰焚天，全体敌人防御降低35%，持续8秒" } },
    -- 35. 吕布 — 天下无双
    { name = "吕布", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero35",
      atk = 1550, def = 580, hp = 10000, unitClass = "CAVALRY", skill = "天下无双",
      skillData = { cd = 14, kind = "aoe", mult = 3.8, radius = 110, desc = "方天画戟横扫天下，对范围敌人造成380%伤害" } },
    -- 36. 诸葛亮 — 卧龙之智
    { name = "诸葛亮", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero36",
      atk = 1200, def = 700, hp = 9800, unitClass = "MAGE", skill = "八阵图",
      skillData = { cd = 16, kind = "buff", atkBuff = 0.25, defBuff = 0.20, duration = 10, desc = "布下八阵图，全军攻击+25%防御+20%，持续10秒" } },

    -- =====================================================================
    -- 限定神武灵 (LIMITED / 限定SSR) — 37~40
    -- =====================================================================
    -- 37. 关羽·武圣归天
    { name = "关羽·武圣归天", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LIMITED, singleImg = "hero37",
      atk = 1950, def = 850, hp = 14500, unitClass = "SWORD", skill = "武圣天罚",
      skillData = { cd = 15, kind = "aoe", mult = 5.0, radius = 140, desc = "武圣怒意贯通天地，对范围敌人造成500%伤害" } },
    -- 38. 吕布·飞将无双
    { name = "吕布·飞将无双", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LIMITED, singleImg = "hero38",
      atk = 2000, def = 780, hp = 13800, unitClass = "CAVALRY", skill = "飞将灭世",
      skillData = { cd = 14, kind = "aoe", mult = 5.5, radius = 150, desc = "飞将之威降临战场，对范围敌人造成550%伤害" } },
    -- 39. 诸葛亮·卧龙出山
    { name = "诸葛亮·卧龙出山", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LIMITED, singleImg = "hero39",
      atk = 1650, def = 950, hp = 13200, unitClass = "MAGE", skill = "卧龙天火",
      skillData = { cd = 15, kind = "aoe", mult = 4.2, radius = 135, dot = 0.5, dotDur = 6, desc = "卧龙祭天火覆盖全场，范围420%伤害+灼烧(50%攻击/秒)持续6秒" } },
    -- 40. 曹操·魏武挥鞭
    { name = "曹操·魏武挥鞭", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LIMITED, singleImg = "hero40",
      atk = 1750, def = 900, hp = 14200, unitClass = "MAGE", skill = "魏武号令",
      skillData = { cd = 14, kind = "buff", atkBuff = 0.40, defBuff = 0.20, duration = 12, desc = "魏武挥鞭号令天下，全军攻击+40%防御+20%，持续12秒" } },
}

-- ============================================================================
-- 战争版增强: 阵营 / 兵种克制 / 五维属性
-- ============================================================================

--- 阵营定义
FACTIONS = {
    shu = { name = "蜀", color = {220, 60, 60},  icon = "蜀" },
    wei = { name = "魏", color = {60, 100, 220}, icon = "魏" },
    wu  = { name = "吴", color = {60, 180, 60},  icon = "吴" },
    qun = { name = "群", color = {180, 160, 60}, icon = "群" },
}

--- 兵种克制类型 (三国群英传风格四兵种循环克制)
--- 步兵 > 弓兵 > 骑兵 > 枪兵 > 步兵
TROOP_TYPES = {
    infantry = { name = "步兵", icon = "步", color = {200, 80, 60} },
    archer   = { name = "弓兵", icon = "弓", color = {60, 180, 60} },
    cavalry  = { name = "骑兵", icon = "骑", color = {60, 100, 220} },
    spear    = { name = "枪兵", icon = "枪", color = {220, 160, 60} },
    special  = { name = "特殊", icon = "特", color = {180, 100, 255} },
}

--- 克制关系: TROOP_COUNTER[我方][敌方] = 伤害倍率
--- 克制 = 1.3x, 被克 = 0.7x, 无关 = 1.0x
TROOP_COUNTER = {
    infantry = { infantry = 1.0, archer = 1.3, cavalry = 0.7, spear = 1.0, special = 1.0 },
    archer   = { infantry = 0.7, archer = 1.0, cavalry = 1.3, spear = 1.0, special = 1.0 },
    cavalry  = { infantry = 1.0, archer = 0.7, cavalry = 1.0, spear = 1.3, special = 1.0 },
    spear    = { infantry = 1.0, archer = 1.0, cavalry = 0.7, spear = 1.0, special = 1.0 },
    special  = { infantry = 1.0, archer = 1.0, cavalry = 1.0, spear = 1.0, special = 1.0 },
}

--- unitClass → troopType 默认映射
local UNIT_TROOP_MAP = {
    SWORD = "infantry", SHIELD = "infantry",
    LANCER = "spear",
    CAVALRY = "cavalry", ASSASSIN = "cavalry",
    ARCHER = "archer", MAGE = "archer", HEALER = "archer",
    TALISMAN = "special", PUPPETEER = "special", ICE_MAGE = "special",
    SWARM = "special", BEAST = "special",
    -- 敌方兵种
    DEMON_WARRIOR = "infantry", DEMON_ARCHER = "archer", DEMON_TANK = "infantry",
}

--- 获取兵种克制伤害倍率
function GetTroopCounterMult(attackerTroop, defenderTroop)
    local row = TROOP_COUNTER[attackerTroop]
    if not row then return 1.0 end
    return row[defenderTroop] or 1.0
end

--- 每个英雄的阵营 (按索引, 1~40)
local HERO_FACTIONS = {
    -- 人武灵 1~10
    [1]  = "wu",   -- 程普
    [2]  = "wu",   -- 黄盖
    [3]  = "wu",   -- 韩当
    [4]  = "shu",  -- 廖化
    [5]  = "shu",  -- 周仓
    [6]  = "shu",  -- 糜竺
    [7]  = "wei",  -- 曹洪
    [8]  = "wei",  -- 李典
    [9]  = "qun",  -- 张任
    [10] = "qun",  -- 纪灵
    -- 地武灵 11~22
    [11] = "wu",   -- 太史慈
    [12] = "wu",   -- 甘宁
    [13] = "wei",  -- 徐晃
    [14] = "wei",  -- 张郃
    [15] = "shu",  -- 魏延
    [16] = "shu",  -- 关平
    [17] = "qun",  -- 高顺
    [18] = "qun",  -- 文丑
    [19] = "qun",  -- 颜良
    [20] = "wei",  -- 邓艾
    [21] = "wei",  -- 钟会
    [22] = "wu",   -- 陆抗
    -- 天武灵 23~30
    [23] = "wei",  -- 典韦
    [24] = "wei",  -- 许褚
    [25] = "wu",   -- 孙策
    [26] = "wei",  -- 夏侯惇
    [27] = "wei",  -- 夏侯渊
    [28] = "qun",  -- 马超 (西凉)
    [29] = "shu",  -- 黄忠
    [30] = "wei",  -- 张辽
    -- 神武灵 31~36
    [31] = "shu",  -- 赵云
    [32] = "shu",  -- 张飞
    [33] = "shu",  -- 关羽
    [34] = "wu",   -- 周瑜
    [35] = "qun",  -- 吕布
    [36] = "shu",  -- 诸葛亮
    -- 限定武灵 37~40
    [37] = "shu",  -- 关羽·武圣归天
    [38] = "qun",  -- 吕布·飞将无双
    [39] = "shu",  -- 诸葛亮·卧龙出山
    [40] = "wei",  -- 曹操·魏武挥鞭
}

--- 五维属性 (武力/智力/体力/技力/速度) 按英雄索引
--- 数值范围 1~100, 影响内政指令效率和战场表现
local HERO_STATS5 = {
    -- 人武灵 1~10 (基础属性较低)
    [1]  = { str = 55, int = 30, vit = 50, tec = 40, spd = 45 },  -- 程普
    [2]  = { str = 60, int = 35, vit = 40, tec = 50, spd = 40 },  -- 黄盖
    [3]  = { str = 50, int = 30, vit = 45, tec = 55, spd = 50 },  -- 韩当
    [4]  = { str = 55, int = 25, vit = 50, tec = 35, spd = 50 },  -- 廖化
    [5]  = { str = 45, int = 20, vit = 65, tec = 25, spd = 35 },  -- 周仓
    [6]  = { str = 25, int = 55, vit = 45, tec = 60, spd = 30 },  -- 糜竺
    [7]  = { str = 50, int = 25, vit = 60, tec = 30, spd = 40 },  -- 曹洪
    [8]  = { str = 50, int = 40, vit = 50, tec = 40, spd = 40 },  -- 李典
    [9]  = { str = 55, int = 35, vit = 48, tec = 50, spd = 42 },  -- 张任
    [10] = { str = 58, int = 25, vit = 50, tec = 38, spd = 45 },  -- 纪灵
    -- 地武灵 11~22 (中等属性)
    [11] = { str = 72, int = 35, vit = 52, tec = 65, spd = 58 },  -- 太史慈
    [12] = { str = 75, int = 40, vit = 48, tec = 60, spd = 70 },  -- 甘宁
    [13] = { str = 68, int = 35, vit = 58, tec = 45, spd = 50 },  -- 徐晃
    [14] = { str = 70, int = 50, vit = 60, tec = 55, spd = 48 },  -- 张郃
    [15] = { str = 78, int = 30, vit = 60, tec = 40, spd = 55 },  -- 魏延
    [16] = { str = 70, int = 35, vit = 55, tec = 50, spd = 52 },  -- 关平
    [17] = { str = 45, int = 30, vit = 80, tec = 35, spd = 38 },  -- 高顺
    [18] = { str = 78, int = 25, vit = 58, tec = 35, spd = 62 },  -- 文丑
    [19] = { str = 75, int = 28, vit = 56, tec = 38, spd = 55 },  -- 颜良
    [20] = { str = 72, int = 65, vit = 50, tec = 70, spd = 60 },  -- 邓艾
    [21] = { str = 55, int = 80, vit = 50, tec = 72, spd = 45 },  -- 钟会
    [22] = { str = 45, int = 60, vit = 75, tec = 55, spd = 40 },  -- 陆抗
    -- 天武灵 23~30 (高属性)
    [23] = { str = 90, int = 20, vit = 70, tec = 35, spd = 65 },  -- 典韦
    [24] = { str = 70, int = 25, vit = 92, tec = 30, spd = 50 },  -- 许褚
    [25] = { str = 85, int = 55, vit = 62, tec = 60, spd = 75 },  -- 孙策
    [26] = { str = 82, int = 35, vit = 75, tec = 45, spd = 55 },  -- 夏侯惇
    [27] = { str = 80, int = 40, vit = 55, tec = 60, spd = 82 },  -- 夏侯渊
    [28] = { str = 88, int = 30, vit = 60, tec = 50, spd = 85 },  -- 马超
    [29] = { str = 85, int = 38, vit = 58, tec = 75, spd = 42 },  -- 黄忠
    [30] = { str = 82, int = 55, vit = 68, tec = 50, spd = 72 },  -- 张辽
    -- 神武灵 31~36 (极高属性)
    [31] = { str = 92, int = 45, vit = 72, tec = 65, spd = 88 },  -- 赵云
    [32] = { str = 95, int = 25, vit = 68, tec = 40, spd = 70 },  -- 张飞
    [33] = { str = 97, int = 40, vit = 70, tec = 55, spd = 65 },  -- 关羽
    [34] = { str = 55, int = 98, vit = 50, tec = 90, spd = 60 },  -- 周瑜
    [35] = { str = 99, int = 30, vit = 65, tec = 50, spd = 90 },  -- 吕布
    [36] = { str = 40, int = 99, vit = 55, tec = 95, spd = 50 },  -- 诸葛亮
    -- 限定武灵 37~40 (顶级属性)
    [37] = { str = 98, int = 45, vit = 78, tec = 60, spd = 72 },  -- 关羽·武圣归天
    [38] = { str = 99, int = 35, vit = 72, tec = 55, spd = 92 },  -- 吕布·飞将无双
    [39] = { str = 50, int = 99, vit = 62, tec = 98, spd = 55 },  -- 诸葛亮·卧龙出山
    [40] = { str = 80, int = 95, vit = 75, tec = 88, spd = 60 },  -- 曹操·魏武挥鞭
}

--- 每个武将可选兵种 (按 unitClass 默认 + 名将特殊覆盖)
--- 第一项为默认兵种, 玩家可在武将管理面板中切换
local TROOP_OPTIONS_BY_CLASS = {
    SWORD    = { "infantry", "spear" },
    SHIELD   = { "infantry", "spear" },
    LANCER   = { "spear", "cavalry" },
    CAVALRY  = { "cavalry", "infantry" },
    ASSASSIN = { "cavalry", "infantry" },
    ARCHER   = { "archer", "infantry" },
    MAGE     = { "archer", "special" },
    HEALER   = { "archer", "infantry" },
    TALISMAN = { "special", "archer", "infantry" },
}
--- 名将专属兵种覆盖 (3种兵种, 体现名将的多面性)
local HERO_TROOP_OVERRIDES = {
    [25] = { "cavalry", "spear", "infantry" },    -- 孙策: 小霸王骑冲/枪阵/步兵
    [28] = { "cavalry", "spear" },                 -- 马超: 西凉铁骑/枪骑
    [30] = { "cavalry", "archer", "infantry" },    -- 张辽: 骑兵/弓骑/步兵
    [31] = { "spear", "cavalry", "infantry" },     -- 赵云: 龙胆枪/骑兵/步兵
    [33] = { "infantry", "cavalry", "spear" },     -- 关羽: 步兵/骑兵/枪兵
    [34] = { "archer", "special" },                 -- 周瑜: 弓兵/特殊
    [35] = { "cavalry", "spear", "infantry" },     -- 吕布: 骑兵/枪兵/步兵
    [36] = { "archer", "special", "infantry" },    -- 诸葛亮: 弓兵/特殊/步兵
    [37] = { "infantry", "cavalry", "spear" },     -- 关羽·武圣: 步/骑/枪
    [38] = { "cavalry", "spear", "infantry" },     -- 吕布·飞将: 骑/枪/步
    [39] = { "archer", "special", "infantry" },    -- 诸葛亮·卧龙: 弓/特/步
    [40] = { "archer", "special", "cavalry" },     -- 曹操·魏武: 弓/特/骑
}

--- 获取武将可选兵种列表
function GetHeroTroopOptions(heroIdx)
    if HERO_TROOP_OVERRIDES[heroIdx] then
        return HERO_TROOP_OVERRIDES[heroIdx]
    end
    local card = HERO_CARDS[heroIdx]
    if card then
        return TROOP_OPTIONS_BY_CLASS[card.unitClass] or { "infantry" }
    end
    return { "infantry" }
end

--- 每个武将的初始武技 (从36个SKILL_TECHNIQUES中按武将特点分配)
--- 值为 SKILL_TECHNIQUES 的索引, 每个武将1个初始武技
HERO_INIT_TECHNIQUES = {
    -- 人武灵 1~10 (凡品/良品武技)
    [1]  = 1,   -- 程普: 破锋针 (凡品)
    [2]  = 2,   -- 黄盖: 烽火附身 (凡品)
    [3]  = 7,   -- 韩当: 穿心箭 (良品)
    [4]  = 6,   -- 廖化: 旋风斩 (凡品)
    [5]  = 3,   -- 周仓: 地裂探阵 (凡品)
    [6]  = 16,  -- 糜竺: 灵泉回春 (优品, 治疗型符合其辅助定位)
    [7]  = 5,   -- 曹洪: 缚敌丝 (凡品)
    [8]  = 4,   -- 李典: 霜锋一线 (凡品)
    [9]  = 8,   -- 张任: 荆棘缠地 (良品)
    [10] = 11,  -- 纪灵: 地刺连探 (良品)
    -- 地武灵 11~22 (良品/优品武技)
    [11] = 12,  -- 太史慈: 飞刃连梭 (良品)
    [12] = 9,   -- 甘宁: 寒棱贯骨 (良品)
    [13] = 18,  -- 徐晃: 碎岩冲击 (优品)
    [14] = 17,  -- 张郃: 玄蚀径 (优品)
    [15] = 13,  -- 魏延: 万箭坠阵 (优品)
    [16] = 10,  -- 关平: 奔雷穿垣 (良品)
    [17] = 14,  -- 高顺: 寒渊冰封 (优品)
    [18] = 15,  -- 文丑: 天雷罚域 (优品)
    [19] = 18,  -- 颜良: 碎岩冲击 (优品)
    [20] = 17,  -- 邓艾: 玄蚀径 (优品)
    [21] = 15,  -- 钟会: 天雷罚域 (优品)
    [22] = 14,  -- 陆抗: 寒渊冰封 (优品)
    -- 天武灵 23~30 (将品武技)
    [23] = 19,  -- 典韦: 烽火燎原 (将品)
    [24] = 21,  -- 许褚: 冰狱封阵 (将品)
    [25] = 23,  -- 孙策: 破军噬魂印 (将品)
    [26] = 24,  -- 夏侯惇: 镇军碑压 (将品)
    [27] = 22,  -- 夏侯渊: 雷狱囚阵 (将品)
    [28] = 19,  -- 马超: 烽火燎原 (将品)
    [29] = 20,  -- 黄忠: 赤壁焚域 (将品)
    [30] = 23,  -- 张辽: 破军噬魂印 (将品)
    -- 神武灵 31~36 (侯品/王品武技)
    [31] = 25,  -- 赵云: 龙吟贯索 (侯品)
    [32] = 29,  -- 张飞: 远古龙魂踏地 (侯品)
    [33] = 28,  -- 关羽: 武灵剑贯三界 (侯品)
    [34] = 26,  -- 周瑜: 九天雷穿 (侯品)
    [35] = 30,  -- 吕布: 万灵归墟衍域 (侯品)
    [36] = 27,  -- 诸葛亮: 极寒冰封贯空 (侯品)
    -- 限定武灵 37~40 (王品/帝品武技)
    [37] = 31,  -- 关羽·武圣: 九天化龙万域 (王品)
    [38] = 35,  -- 吕布·飞将: 不灭天域 (王品)
    [39] = 33,  -- 诸葛亮·卧龙: 千军冻绝冰域 (王品)
    [40] = 32,  -- 曹操·魏武: 天命雷音 (王品)
}

--- 批量注入: 为所有 HERO_CARDS 添加 faction / troopType / stats5 / troopOptions / initTechnique
for i, card in ipairs(HERO_CARDS) do
    card.faction = HERO_FACTIONS[i] or "qun"
    card.troopType = UNIT_TROOP_MAP[card.unitClass] or "infantry"
    card.stats5 = HERO_STATS5[i] or { str = 50, int = 50, vit = 50, tec = 50, spd = 50 }
    card.troopOptions = GetHeroTroopOptions(i)
    card.initTechnique = HERO_INIT_TECHNIQUES[i]
end

--- 也为 ENEMY_CARDS 注入 troopType (敌方无阵营)
-- (在 ENEMY_CARDS 定义之后执行, 见下方)

ENEMY_CARDS = {
    -- 1. 黄巾力士 (贼兵先锋)
    { name = "黄巾力士", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE,
      atk = 1000, def = 480, hp = 8400, unitClass = "DEMON_WARRIOR", skill = "横扫千军",
      singleImg = "enemy1" },
    -- 2. 山贼头领 (贼兵先锋)
    { name = "山贼头领", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC,
      atk = 1400, def = 360, hp = 6600, unitClass = "DEMON_WARRIOR", skill = "夜袭突进",
      singleImg = "enemy2" },
    -- 3. 贼军弓手 (贼兵弓手)
    { name = "贼军弓手", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE,
      atk = 840, def = 600, hp = 7800, unitClass = "DEMON_ARCHER", skill = "连珠箭雨",
      singleImg = "enemy3" },
    -- 4. 烽火暴徒 (贼兵先锋)
    { name = "烽火暴徒", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 780, def = 380, hp = 7000, unitClass = "DEMON_WARRIOR", skill = "烈火斩",
      singleImg = "enemy4" },
    -- 5. 叛军督帅 (贼兵重甲) BOSS
    { name = "叛军督帅", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.LEGENDARY,
      atk = 1100, def = 1200, hp = 18000, unitClass = "DEMON_TANK", skill = "督帅之盾",
      isBoss = true, bossScale = 1.5, singleImg = "enemy5" },
    -- 6. 铁锁狱卒 (贼兵重甲)
    { name = "铁锁狱卒", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON,
      atk = 600, def = 950, hp = 12000, unitClass = "DEMON_TANK", skill = "铁锁缠绕",
      singleImg = "enemy6" },
    -- 7. 贼军祭师 (贼兵弓手)
    { name = "贼军祭师", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.RARE,
      atk = 540, def = 660, hp = 9600, unitClass = "DEMON_ARCHER", skill = "回春之术",
      singleImg = "enemy7" },
    -- 8. 瘴气巫女 (贼兵弓手)
    { name = "瘴气巫女", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 720, def = 340, hp = 6200, unitClass = "DEMON_ARCHER", skill = "瘴气弥漫",
      singleImg = "enemy8" },
    -- 9. 贼军弩兵 (贼兵弓手)
    { name = "贼军弩兵", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 740, def = 300, hp = 5800, unitClass = "DEMON_ARCHER", skill = "穿甲连射",
      singleImg = "enemy9" },
    -- 10. 铁甲骑士 (贼兵重甲)
    { name = "铁甲骑士", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE,
      atk = 720, def = 900, hp = 11400, unitClass = "DEMON_TANK", skill = "铁壁壁垒",
      singleImg = "enemy10" },
    -- 11. 悍匪屠夫 (贼兵先锋)
    { name = "悍匪屠夫", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 900, def = 420, hp = 7400, unitClass = "DEMON_WARRIOR", skill = "狂暴屠戮",
      singleImg = "enemy11" },
    -- 12. 毒藤术士 (贼兵弓手)
    { name = "毒藤术士", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.EPIC,
      atk = 660, def = 600, hp = 9000, unitClass = "DEMON_ARCHER", skill = "藤蔓回生",
      singleImg = "enemy12" },
    -- 13. 蛮荒狂战 (贼兵先锋)
    { name = "蛮荒狂战", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 840, def = 360, hp = 6600, unitClass = "DEMON_WARRIOR", skill = "狂怒怒吼",
      singleImg = "enemy13" },
    -- 14. 暗卫女将 (贼兵重甲)
    { name = "暗卫女将", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE,
      atk = 580, def = 840, hp = 10200, unitClass = "DEMON_TANK", skill = "铁壁护盾",
      singleImg = "enemy14" },
    -- 15. 铁甲武士 (贼兵先锋)
    { name = "铁甲武士", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 820, def = 450, hp = 7000, unitClass = "DEMON_WARRIOR", skill = "铁甲冲锋",
      singleImg = "enemy15" },
    -- 16. 沼泽术士 (贼兵弓手)
    { name = "沼泽术士", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE,
      atk = 720, def = 540, hp = 8400, unitClass = "DEMON_ARCHER", skill = "沼泽缠绕",
      singleImg = "enemy16" },
}

--- 为 ENEMY_CARDS 注入 troopType
for _, ecard in ipairs(ENEMY_CARDS) do
    ecard.troopType = UNIT_TROOP_MAP[ecard.unitClass] or "infantry"
end

-- ============================================================================
-- 装备系统 (兵甲)
-- ============================================================================
EQUIP_SLOT_NAMES = { "武器", "头盔", "胸甲", "护腿", "战靴", "佩饰", "兵书" }

-- 装备阶级 (6阶)
EQUIP_TIERS = {
    { name = "凡品", color = { 180, 175, 165 }, glow = { 180, 175, 165, 0 }, multiplier = 1.0 },
    { name = "良品", color = { 100, 210, 120 }, glow = { 100, 210, 120, 40 }, multiplier = 1.3 },
    { name = "优品", color = { 80, 160, 255 },  glow = { 80, 160, 255, 60 }, multiplier = 1.6 },
    { name = "将品", color = { 180, 100, 255 }, glow = { 180, 100, 255, 80 }, multiplier = 2.0 },
    { name = "王品", color = { 255, 180, 50 },  glow = { 255, 180, 50, 100 }, multiplier = 2.5 },
    { name = "帝品", color = { 255, 80, 80 },   glow = { 255, 80, 80, 120 }, multiplier = 3.2 },
}
EQUIP_TIER_NAMES = { "凡品", "良品", "优品", "将品", "王品", "帝品" }

EQUIPMENT_SETS = {
    { -- Set 1 (col 0): 虎牢关套 — 防御型 | 额外词条: 减伤
        name = "虎牢关套", theme = "固守", color = { 120, 180, 255 },
        extraKey = "dmgReduction", extraName = "减伤",
        setBonus3 = { atkPct = 0, defPct = 3, hpPct = 5, dmgReduction = 3 },
        setBonus3Desc = "防御+3% 生命+5% 减伤+3%",
        setBonus4 = { atkPct = 0, defPct = 5, hpPct = 8, dmgReduction = 6 },
        setBonus4Desc = "防御+5% 生命+8% 减伤+6%",
        setBonus = { atkPct = 0, defPct = 8, hpPct = 12, dmgReduction = 10 },
        setBonusDesc = "全员防御+8% 生命+12% 减伤+10%",
        pieces = {
            { name = "镇关长枪", atkPct = 1, defPct = 4, hpPct = 3 },
            { name = "虎牢铁盔", atkPct = 0, defPct = 5, hpPct = 3 },
            { name = "玄铁重甲", atkPct = 1, defPct = 4, hpPct = 3 },
            { name = "关隘腿铠", atkPct = 1, defPct = 3, hpPct = 2 },
            { name = "磐石战靴", atkPct = 0, defPct = 3, hpPct = 2 },
            { name = "守关佩",   atkPct = 1, defPct = 2, hpPct = 2 },
            { name = "不灭兵书", atkPct = 1, defPct = 2, hpPct = 2 },
        },
    },
    { -- Set 2 (col 1): 卧龙军师套 — 法术型 | 额外词条: 攻速
        name = "卧龙军师套", theme = "法术", color = { 180, 140, 255 },
        extraKey = "atkSpeedPct", extraName = "攻速",
        setBonus3 = { atkPct = 3, defPct = 0, hpPct = 2, atkSpeedPct = 5 },
        setBonus3Desc = "攻击+3% 生命+2% 攻速+5%",
        setBonus4 = { atkPct = 5, defPct = 1, hpPct = 4, atkSpeedPct = 10 },
        setBonus4Desc = "攻击+5% 防御+1% 生命+4% 攻速+10%",
        setBonus = { atkPct = 8, defPct = 2, hpPct = 6, atkSpeedPct = 18 },
        setBonusDesc = "全员攻击+8% 生命+6% 攻速+18%",
        pieces = {
            { name = "羽扇纶巾",   atkPct = 4, defPct = 1, hpPct = 1 },
            { name = "军师冠",     atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "锦纹长袍", atkPct = 3, defPct = 1, hpPct = 2 },
            { name = "儒雅腿裳", atkPct = 2, defPct = 1, hpPct = 1 },
            { name = "云步履",   atkPct = 2, defPct = 1, hpPct = 1 },
            { name = "玉佩坠",   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "卧龙兵书",   atkPct = 2, defPct = 1, hpPct = 1 },
        },
    },
    { -- Set 3 (col 2): 猛将先锋套 — 物理爆发 | 额外词条: 暴击
        name = "猛将先锋套", theme = "爆发", color = { 255, 160, 80 },
        extraKey = "critRate", extraName = "暴击",
        setBonus3 = { atkPct = 5, defPct = 0, hpPct = 2, critRate = 5 },
        setBonus3Desc = "攻击+5% 生命+2% 暴击+5%",
        setBonus4 = { atkPct = 8, defPct = 0, hpPct = 3, critRate = 10 },
        setBonus4Desc = "攻击+8% 生命+3% 暴击+10%",
        setBonus = { atkPct = 12, defPct = 0, hpPct = 4, critRate = 18 },
        setBonusDesc = "全员攻击+12% 生命+4% 暴击+18%",
        pieces = {
            { name = "破阵大刀", atkPct = 5, defPct = 0, hpPct = 1 },
            { name = "虎头巾",   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "裂甲战袍", atkPct = 4, defPct = 1, hpPct = 1 },
            { name = "疾风腿甲", atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "踏阵靴",   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "破军环",   atkPct = 4, defPct = 0, hpPct = 1 },
            { name = "猛将兵书", atkPct = 2, defPct = 1, hpPct = 1 },
        },
    },
    { -- Set 4 (col 3): 龙胆剑士套 — 剑系特化 | 额外词条: 反击
        name = "龙胆剑士套", theme = "剑道", color = { 100, 220, 255 },
        extraKey = "counterRate", extraName = "反击",
        setBonus3 = { atkPct = 4, defPct = 1, hpPct = 2, counterRate = 4 },
        setBonus3Desc = "攻击+4% 防御+1% 生命+2% 反击+4%",
        setBonus4 = { atkPct = 7, defPct = 2, hpPct = 3, counterRate = 8 },
        setBonus4Desc = "攻击+7% 防御+2% 生命+3% 反击+8%",
        setBonus = { atkPct = 10, defPct = 3, hpPct = 5, counterRate = 15 },
        setBonusDesc = "全员攻击+10% 防御+3% 反击+15%",
        pieces = {
            { name = "龙胆亮银枪", atkPct = 4, defPct = 1, hpPct = 1 },
            { name = "银冠",   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "流光剑袍", atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "御风腿甲", atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "凌虚靴",   atkPct = 2, defPct = 1, hpPct = 1 },
            { name = "龙胆佩",   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "龙胆兵书", atkPct = 2, defPct = 1, hpPct = 1 },
        },
    },
    { -- Set 5 (col 4): 夜影刺客套 — 刺客/暗杀 | 额外词条: 突破伤害
        name = "夜影刺客套", theme = "暗杀", color = { 200, 100, 255 },
        extraKey = "breakDmgPct", extraName = "突破",
        setBonus3 = { atkPct = 6, defPct = 0, hpPct = 0, breakDmgPct = 6 },
        setBonus3Desc = "攻击+6% 突破+6%",
        setBonus4 = { atkPct = 10, defPct = 0, hpPct = 0, breakDmgPct = 12 },
        setBonus4Desc = "攻击+10% 突破+12%",
        setBonus = { atkPct = 15, defPct = 0, hpPct = 0, breakDmgPct = 20 },
        setBonusDesc = "全员攻击+15% 突破+20%",
        pieces = {
            { name = "蝶踪匕",   atkPct = 6, defPct = 0, hpPct = 1 },
            { name = "夜影面具", atkPct = 4, defPct = 1, hpPct = 1 },
            { name = "夜行衣",   atkPct = 4, defPct = 0, hpPct = 1 },
            { name = "轻甲腿绑", atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "无声履",   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "蝶影铃",   atkPct = 4, defPct = 0, hpPct = 1 },
            { name = "刺客兵书", atkPct = 2, defPct = 1, hpPct = 1 },
        },
    },
    { -- Set 6 (col 5): 霸王神威套 — 重攻击 | 额外词条: 死亡爆炸
        name = "霸王神威套", theme = "神威", color = { 255, 200, 60 },
        extraKey = "deathExplosionPct", extraName = "天崩",
        setBonus3 = { atkPct = 2, defPct = 2, hpPct = 3, deathExplosionPct = 15 },
        setBonus3Desc = "攻防+2% 生命+3% 天崩+15%",
        setBonus4 = { atkPct = 4, defPct = 4, hpPct = 5, deathExplosionPct = 30 },
        setBonus4Desc = "攻防+4% 生命+5% 天崩+30%",
        setBonus = { atkPct = 6, defPct = 6, hpPct = 8, deathExplosionPct = 50 },
        setBonusDesc = "全员攻防+6% 生命+8% 天崩+50%",
        pieces = {
            { name = "霸王戟",     atkPct = 3, defPct = 2, hpPct = 2 },
            { name = "霸王盔",     atkPct = 2, defPct = 3, hpPct = 2 },
            { name = "龙鳞铠",   atkPct = 3, defPct = 2, hpPct = 2 },
            { name = "铁壁腿甲", atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "重锤靴",   atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "虎符令",     atkPct = 3, defPct = 1, hpPct = 2 },
            { name = "霸王兵书", atkPct = 2, defPct = 1, hpPct = 2 },
        },
    },
    { -- Set 7 (col 6): 行伍新兵套 — 均衡/新手 | 额外词条: 移速
        name = "行伍新兵套", theme = "均衡", color = { 160, 220, 160 },
        extraKey = "speedPct", extraName = "移速",
        setBonus3 = { atkPct = 2, defPct = 2, hpPct = 2, speedPct = 5 },
        setBonus3Desc = "攻防+2% 生命+2% 移速+5%",
        setBonus4 = { atkPct = 3, defPct = 3, hpPct = 4, speedPct = 10 },
        setBonus4Desc = "攻防+3% 生命+4% 移速+10%",
        setBonus = { atkPct = 4, defPct = 4, hpPct = 6, speedPct = 15 },
        setBonusDesc = "全员攻防+4% 生命+6% 移速+15%",
        pieces = {
            { name = "新兵木剑", atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "粗布斗笠", atkPct = 1, defPct = 2, hpPct = 2 },
            { name = "粗布短褐", atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "粗布腿裹", atkPct = 1, defPct = 2, hpPct = 2 },
            { name = "草编战靴", atkPct = 2, defPct = 1, hpPct = 2 },
            { name = "铜铃",     atkPct = 2, defPct = 1, hpPct = 2 },
            { name = "入门兵书", atkPct = 1, defPct = 1, hpPct = 2 },
        },
    },
}

-- 玩家装备状态 (个体化存储: 每件兵甲是唯一物品，拥有自己的uid/品质/强化)
playerEquipment = {
    owned = {},          -- 拥有的装备数组: { {uid=1, setIdx=n, slotIdx=s, tier=t, quality=0~100, enhanceLv=0}, ... }
    equipped = {},       -- 已装备: equipped[slotIdx] = uid (引用owned中的uid)
    nextUid = 1,         -- 下一个唯一ID
    unlockedSlots = 0, -- 额外解锁的格子数（总格子=BASE_EQUIP_SLOTS+此值，每次广告+5）
}

-- 初始赠送一套游魂剑童(set 7)的武器 (凡品, 品质50)
-- 内联创建，避免前向引用 CreateEquipItem (定义在 systems/equip.lua，加载晚于 G.lua)
initItem = {
    uid = playerEquipment.nextUid,
    setIdx = 7,
    slotIdx = 1,
    tier = 1,
    quality = 50,
    enhanceLv = 0,
    level = 1,
}
playerEquipment.nextUid = playerEquipment.nextUid + 1
table.insert(playerEquipment.owned, initItem)
playerEquipment.equipped[1] = initItem.uid
-- 装备UI状态
equipScreenState = {
    selectedSlot = 1,   -- 当前选中的装备槽 (1-7)
    decompConfirm = nil, -- 分解确认弹窗 { setIdx, slotIdx, tier, gain }
    decompConfirmBtn = nil,  -- 确认按钮rect
    decompCancelBtn = nil,   -- 取消按钮rect
    enhanceConfirm = nil,    -- 强化确认弹窗 { slotIdx, enhLv, cost }
    enhanceConfirmBtn = nil, -- 强化确认按钮rect
    enhanceCancelBtn = nil,  -- 强化取消按钮rect
    scrollY = 0,             -- 装备列表滚动偏移
    scrollVel = 0,           -- 滚动惯性速度
    isDragging = false,      -- 是否正在拖动
    dragStartY = nil,        -- 触摸拖动起始Y
    dragLastY = nil,         -- 上一帧触摸Y
    batchFilterMaxTier = 6,  -- 一键分解筛选: 品质上限 (1-6, 6=全部)
    batchFilterLeftBtn = nil,
    batchFilterRightBtn = nil,
    selectMode = false,         -- 选中分解模式
    selectedUids = {},          -- 选中的装备uid集合
    selectDecompBtn = nil,      -- 选中分解按钮rect
    selectConfirmBtn = nil,     -- 选中分解确认rect
    selectCancelBtn = nil,      -- 取消选中模式rect
    selectAllBtn = nil,         -- 全选按钮rect
    selectDecompConfirm = nil,  -- 选中分解确认弹窗 { count, gain }
}
equipSlotRects = {}
equipPieceRects = {}
equipBackBtnRect = nil

-- ============================================================================

--- 境界评分: 每级递增, 高境界增幅更大 (50级)
RANK_POWER_TABLE = {
    -- 新生 一~十层
    0,   5,  12,  20,  30,  42,  56,  72,  90, 115,
    -- 侍僧 一~十层
    140, 170, 200, 235, 275, 320, 370, 425, 485, 550,
    -- 偏将 一~十层
    620, 700, 785, 875, 970, 1070, 1175, 1285, 1400, 1520,
    -- 领主 一~十层
    1650, 1790, 1940, 2100, 2270, 2450, 2640, 2840, 3050, 3270,
    -- 大将军 一~十层
    3500, 3740, 3990, 4250, 4520, 4800, 5090, 5390, 5700, 6020,
}

-- ============================================================================
-- 红点系统 - 已读指纹 + 树状穿透
-- ============================================================================
-- 原理: 用评分指纹跟踪"上次确认时的状态"。
--   当获得新装备/武技导致 bestOwned 升高, 指纹不再匹配 >> 红点亮起。
--   点击进入对应页面 >> 调用 Dismiss >> 指纹更新 >> 红点关闭。
--   树状穿透: 父节点红点 = OR(所有子节点红点)。

redDotState = {
    equipAck = {},      -- equipAck[slotIdx] = 已确认的该槽位最佳拥有评分
    skillAckBest = 0,   -- 已确认的最佳未装备武技评分
    skillAckSlots = 2,  -- 已确认时的已装备槽位数
}


-- ============================================================================
-- 关卡系统
-- ============================================================================
STAGE_PAGE_SIZE = 10
STAGES = {
    -- === 第1页: 黄巾之乱 ===
    { name = "黄巾营寨", desc = "初入乱世之地",     enemyScale = 0.25, maxTier = 1, dropSets = {7, 1},    color = {80, 255, 120},  layoutIdx = 1 },
    { name = "汝南小径", desc = "乡野间的伏击",     enemyScale = 0.35, maxTier = 1, dropSets = {1, 7},    color = {100, 220, 140}, layoutIdx = 1 },
    { name = "广宗城外", desc = "黄巾军主力驻扎",   enemyScale = 0.45, maxTier = 1, dropSets = {7, 2},    color = {120, 200, 100}, layoutIdx = 1 },
    { name = "董卓前哨", desc = "西凉铁骑的前线",   enemyScale = 0.55, maxTier = 2, dropSets = {1, 2},    color = {200, 160, 80},  layoutIdx = 1 },
    { name = "虎牢关外", desc = "三英战吕布之地",   enemyScale = 0.65, maxTier = 2, dropSets = {2, 3},    color = {220, 180, 60},  layoutIdx = 1 },
    { name = "洛阳废墟", desc = "大火焚烧后的残垣", enemyScale = 0.75, maxTier = 2, dropSets = {3, 7},    color = {180, 100, 60},  layoutIdx = 1 },
    { name = "长安古道", desc = "通往旧都的险路",   enemyScale = 0.85, maxTier = 2, dropSets = {1, 3},    color = {160, 140, 100}, layoutIdx = 1 },
    { name = "宛城夜战", desc = "暗夜中的突袭",     enemyScale = 0.95, maxTier = 3, dropSets = {2, 4},    color = {100, 120, 200}, layoutIdx = 1 },
    { name = "官渡前线", desc = "北方霸权的决战",   enemyScale = 1.05, maxTier = 3, dropSets = {3, 5},    color = {140, 100, 180}, layoutIdx = 1 },
    { name = "白马渡口", desc = "河畔的殊死搏斗",   enemyScale = 1.15, maxTier = 3, dropSets = {4, 6},    color = {100, 180, 220}, layoutIdx = 1 },
    -- === 第2页: 三分天下 ===
    { name = "新野烽火", desc = "刘备兴兵之始",     enemyScale = 1.25, maxTier = 3, dropSets = {5, 7},    color = {200, 120, 80},  layoutIdx = 1 },
    { name = "博望坡",   desc = "孔明初用兵",       enemyScale = 1.35, maxTier = 3, dropSets = {1, 6},    color = {220, 160, 60},  layoutIdx = 1 },
    { name = "当阳长坂", desc = "赵子龙七进七出",   enemyScale = 1.45, maxTier = 4, dropSets = {2, 5},    color = {255, 100, 40},  layoutIdx = 1 },
    { name = "赤壁滩头", desc = "烽火连天大决战",   enemyScale = 1.55, maxTier = 4, dropSets = {3, 6, 7}, color = {255, 80, 30},   layoutIdx = 1 },
    { name = "南郡争夺", desc = "荆州要地的攻防",   enemyScale = 1.65, maxTier = 4, dropSets = {4, 1},    color = {160, 200, 100}, layoutIdx = 1 },
    { name = "荆州城池", desc = "兵家必争之地",     enemyScale = 1.75, maxTier = 4, dropSets = {5, 2},    color = {120, 200, 160}, layoutIdx = 1 },
    { name = "益州关隘", desc = "入蜀的重重关卡",   enemyScale = 1.85, maxTier = 5, dropSets = {6, 3},    color = {100, 160, 220}, layoutIdx = 1 },
    { name = "落凤坡",   desc = "英才陨落之地",     enemyScale = 1.95, maxTier = 5, dropSets = {7, 4},    color = {180, 80, 180},  layoutIdx = 1 },
    { name = "葭萌关",   desc = "扼守蜀道的咽喉",   enemyScale = 2.05, maxTier = 5, dropSets = {1, 5, 6}, color = {140, 180, 80},  layoutIdx = 1 },
    { name = "成都之战", desc = "入主益州的决战",   enemyScale = 2.15, maxTier = 5, dropSets = {2, 6, 7}, color = {220, 200, 60},  layoutIdx = 1 },
    -- === 第3页: 天下归一 ===
    { name = "汉中争锋", desc = "定军斩夏侯",       enemyScale = 2.25, maxTier = 5, dropSets = {3, 5, 7}, color = {180, 220, 100}, layoutIdx = 1 },
    { name = "定军山",   desc = "黄忠威震三军",     enemyScale = 2.35, maxTier = 5, dropSets = {4, 6, 1}, color = {200, 180, 60},  layoutIdx = 1 },
    { name = "樊城水淹", desc = "关公水淹七军",     enemyScale = 2.45, maxTier = 5, dropSets = {5, 7, 2}, color = {80, 160, 255},  layoutIdx = 1 },
    { name = "麦城绝境", desc = "英雄末路的悲壮",   enemyScale = 2.55, maxTier = 6, dropSets = {6, 1, 3}, color = {200, 60, 60},   layoutIdx = 1 },
    { name = "夷陵烈焰", desc = "连营七百里火海",   enemyScale = 2.65, maxTier = 6, dropSets = {7, 2, 4}, color = {255, 120, 40},  layoutIdx = 1 },
    { name = "街亭失守", desc = "挥泪斩马谡",       enemyScale = 2.75, maxTier = 6, dropSets = {1, 3, 5}, color = {160, 120, 200}, layoutIdx = 1 },
    { name = "五丈原",   desc = "星落秋风的绝唱",   enemyScale = 2.85, maxTier = 6, dropSets = {2, 4, 6}, color = {140, 100, 220}, layoutIdx = 1 },
    { name = "铁笼山",   desc = "困兽犹斗的死战",   enemyScale = 2.95, maxTier = 6, dropSets = {3, 5, 7}, color = {220, 80, 80},   layoutIdx = 1 },
    { name = "段谷鏖战", desc = "大将军的最后一搏", enemyScale = 3.05, maxTier = 6, dropSets = {4, 6, 1}, color = {255, 60, 60},   layoutIdx = 1 },
    { name = "天水归途", desc = "乱世终结的曙光",   enemyScale = 3.15, maxTier = 6, dropSets = {5, 6, 7, 1, 2, 3}, color = {255, 220, 80}, layoutIdx = 1 },
}
STAGE_TOTAL_PAGES = math.ceil(#STAGES / STAGE_PAGE_SIZE)

-- ============================================================================
-- 战斗布局 (背景图 ↔ 石台坐标关联)
-- ============================================================================
-- 坐标为背景图原始像素空间 (BG_W=714, BG_H=1280), 运行时乘以 BG2D_X/Y 转为设计坐标
--- 战场布局表: 索引0=默认, 1~7=讨伐层 (用数组索引1~8存储)
--- layoutId 含义: 0=默认, 1=讨伐1, ..., 7=讨伐7
--- 数组索引 = layoutId + 1
-- 所有战场统一使用默认槽位 (横屏: 玩家左侧, 敌人右侧, 坐标为BG像素空间)
local _defaultPlayerSlots = {{100,400},{100,550},{100,700},{100,850},{200,400},{200,550},{200,700},{200,850}}
local _defaultEnemySlots  = {{550,400},{550,550},{550,700},{650,400},{650,550}}

BATTLE_LAYOUTS = {
    [1] = { layoutId = 0, name = "默认战场",  bg = "image/battle_bg_1.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [2] = { layoutId = 1, name = "讨伐第1层", bg = "image/battle_bg_2.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [3] = { layoutId = 2, name = "讨伐第2层", bg = "image/battle_bg_3.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [4] = { layoutId = 3, name = "讨伐第3层", bg = "image/battle_bg_4.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [5] = { layoutId = 4, name = "讨伐第4层", bg = "image/battle_bg_5.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [6] = { layoutId = 5, name = "讨伐第5层", bg = "image/battle_bg_6.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [7] = { layoutId = 6, name = "讨伐第6层", bg = "image/battle_bg_7.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [8] = { layoutId = 7, name = "讨伐第7层", bg = "image/battle_bg_8.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
}
currentLayoutIdx = 1

--- 石台编辑器撤销栈 (每次拖拽前记录快照)
slotUndoStack = {}  -- { {layoutIdx, slotType, slotIdx, oldX, oldY}, ... }  MAX=50

stageState = {
    currentStage = 1,       -- 当前选中关卡
    maxUnlocked = 1,        -- 最大已解锁关卡
    currentPage = 1,        -- 当前页码 (1-3)
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
    backBtnRect = nil,          -- 讨伐页返回按钮
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
    btnRect = nil,              -- 首页爬塔按钮
    backBtnRect = nil,          -- 爬塔页返回按钮
    startBtnRect = nil,         -- 爬塔出战按钮
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
    { name = "黄巾", icon = "B", color = {180, 120, 60},  minScore = 0 },
    { name = "校尉", icon = "S", color = {180, 190, 210}, minScore = 100 },
    { name = "偏将", icon = "G", color = {255, 200, 60},  minScore = 250 },
    { name = "都督", icon = "P", color = {100, 220, 220}, minScore = 450 },
    { name = "大将", icon = "D", color = {140, 180, 255}, minScore = 700 },
    { name = "天命", icon = "M", color = {255, 80, 80},   minScore = 1000 },
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
    -- 对手信息
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
    dragLastY = nil,        -- 上一帧触摸Y
    isDragging = false,     -- 是否正在拖动
}
equipCodexBackBtnRect = nil
equipCodexSetRects = {}
-- powerRankBackBtnRect 存储在 menuBtnRects.powerRankBack 中，避免局部变量上限

-- ============================================================================
-- 游戏状态
-- ============================================================================
BASE_HP_MAX = GameConfig.BASE_HP_MAX
SOLDIER_STAT_SCALE = GameConfig.SOLDIER_STAT_SCALE

gameState = {
    gold = 0,
    totalKills = 0,
    gameTime = 0,
    phase = "LOADING",      -- LOADING / PROFILE / MENU / GACHA / CODEX / EQUIP / EQUIP_CODEX / STAGE_SELECT / ABYSS_SELECT / EXPLORATION / TOWER_SELECT / RANKED_SELECT / BATTLE / WIN / LOSE / WELFARE / PROGRESS / PLAYER_DETAIL / SKILL_CODEX / SKILL_DETAIL / DUMMY_SELECT / DUMMY_RESULT / DEV_EDITOR
    battlePhase = "SHOP",   -- SHOP(布阵购卡) / FIGHT(战斗中)
    resultTimer = 0,
    playerBaseHP = BASE_HP_MAX,
    playerBaseMax = BASE_HP_MAX,
    enemyBaseHP = BASE_HP_MAX,
    drawCount = 0,
    goldTimer = 0,          -- 军资自动增长计时器
    battleTime = 0,         -- 战斗持续时间
    autoMarch = false,      -- 自动行军模式
    battleSpeed = 1,        -- 战斗倍速 (1/2/3)
    autoBattle = false,     -- 全自动战斗 (自动刷将/派兵/开战)
    noFullAuto = false,     -- 副本模式禁止全自动 (只允许自动派兵)
    abyssFloor = nil,       -- 讨伐模式层数 (nil=普通关卡)
    towerFloor = nil,       -- 爬塔模式层数 (nil=非爬塔)
    isRanked = false,       -- 排位模式标记
    isDummy = false,        -- 30s打桩模式标记
    explorationMode = false, -- 搜打撤探索模式标记 (从探索发起的战斗)
    exploreExitConfirm = nil, -- 探索战斗弹窗 { type = "exit"|"death" }
}

-- 30s打桩系统状态 (全局，不增加top-level local)
dummyState = {
    selected = {},          -- 已选武灵索引列表 (最多4个)
    cardRects = {},         -- 武灵选择卡片的点击区域
    startBtnRect = nil,     -- 开始按钮区域
    backBtnRect = nil,      -- 返回按钮区域
    btnRect = nil,          -- 主菜单入口按钮区域
    totalDamage = 0,        -- 累计总伤害
    timer = 30,             -- 倒计时
    resultBackRect = nil,   -- 结果页返回按钮
    scrollY = 0,            -- 选将网格滚动偏移
    scrollVel = 0,          -- 滚动惯性速度
    isDragging = false,     -- 是否正在拖拽
    dragStartY = nil,       -- 拖拽起始Y
    dragLastY = nil,        -- 上一帧Y
    contentH = 0,           -- 网格内容总高度
    gridH = 0,              -- 可视区域高度
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
    btnRects = {},       -- 各种按钮区域
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
battleSpeedBtnRect = nil       -- 倍速按钮区域 (设计坐标, global避免local-limit)
autoBattleBtnRect = nil        -- 自动战斗按钮区域 (设计坐标, global避免local-limit)
autoBattleTimer = 0            -- 自动战斗操作节流计时器 (global避免local-limit)
shopRefreshBtnRect = nil       -- 刷新按钮区域 (设计坐标, global避免local-limit)

-- 战斗区域 (设计坐标, 横屏左右对战)
BATTLE_ZONE = {
    top = 60, bottom = 500,
    centerY = 280,
    left = 20, right = 1004,
    centerX = 512,
    -- 临界线: 兵过此线扣对方基地血 (横向)
    enemyLine = 960,    -- 玩家兵向右行进, 到达此线 >> 扣敌方血
    playerLine = 64,    -- 敌方兵向左行进, 到达此线 >> 扣玩家血
    -- 部署区域
    playerDeployLeft = 20,
    playerDeployRight = 300,
    enemyDeployLeft = 724,
    enemyDeployRight = 1004,
}

-- ============================================================================
-- 车道系统 (5条水平等分车道, 横屏按Y轴分)
-- ============================================================================
NUM_LANES = 5
LANE_WIDTH = (BATTLE_ZONE.bottom - BATTLE_ZONE.top) / NUM_LANES  -- ~88px each
INTERCEPT_RANGE = 60  -- 士兵拦截敌人的距离阈值

playerUnits = {}
enemyUnits = {}
floatTexts = {}

playerSpawnTimer = 0
enemySpawnTimer = 0
PLAYER_SPAWN_CD = GameConfig.PLAYER_SPAWN_CD
ENEMY_SPAWN_CD  = GameConfig.ENEMY_SPAWN_CD
BATTLE_TIME_LIMIT = GameConfig.BATTLE_TIME_LIMIT or 180
DEPLOY_BATCH_SIZE = GameConfig.DEPLOY_BATCH_SIZE or { [1] = 4, [2] = 5, [3] = 6, [4] = 8 }
DEPLOY_CD = GameConfig.DEPLOY_CD or 3.5
MAX_PLAYER_UNITS = 40
MAX_ENEMY_UNITS = 40



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

-- 信息弹窗 (单击触发, 替代旧的长按弹窗)
infoPopupState = {
    show = false,
    card = nil,
    slotIdx = 0,
    isSlot = false,
    isEnemy = false,
}
pressStartSX = 0
pressStartSY = 0

-- ============================================================================
-- 初始化
-- ============================================================================

