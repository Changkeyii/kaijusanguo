-- ============================================================================
-- G_data.lua - 三国武灵录 (从 G.lua 拆分)
-- ============================================================================

-- GameConfig 由 main.lua 全局加载，此处无需重复 require

---@type any
local sdk = rawget(_G, "sdk")  -- 广告SDK (运行时由引擎注入, 开发模式下为nil)

-- ============================================================================
-- 全局文字黑描边 (包装 nvgText，所有文字自动带描边)
-- ============================================================================
_nvgTextOrig = nvgText  -- 保存原始函数

-- ============================================================================
-- 项目隔离前缀（防止多应用间存档/云数据冲突）
-- ============================================================================
PROJECT_PREFIX = "p_49dd_"  -- 用于云变量 key 前缀 (三国武灵录)
FILE_SAVEGAME  = "p_49dd_savegame.json"
FILE_SETTINGS  = "p_49dd_settings.json"
FILE_LAYOUTS   = "p_49dd_battle_layouts.json"

-- ============================================================================
-- 设计常量
-- ============================================================================
vg = nil
fontId = -1
fontArt = -1  -- 艺术字体
fontGame = -1 -- 游戏字体
fontKai = -1  -- 楷体
fontFZ = -1   -- 方正文楷

-- 图片句柄 (合并为单表节省 local 名额)
IMG = {
    bg = -1,
    heroSheet = -1,
    heroSheetNoBg = -1,
    heroSheet2NoBg = -1,    -- sheet2 编辑后的透明版 (3×3)
    heroSheetExtra = -1,
    heroSheetExtraNoBg = -1,
    -- 三国武灵独立图 (hero1-hero40)
    hero1 = -1, hero2 = -1, hero3 = -1, hero4 = -1, hero5 = -1,
    hero6 = -1, hero7 = -1, hero8 = -1, hero9 = -1, hero10 = -1,
    hero11 = -1, hero12 = -1, hero13 = -1, hero14 = -1, hero15 = -1,
    hero16 = -1, hero17 = -1, hero18 = -1, hero19 = -1, hero20 = -1,
    hero21 = -1, hero22 = -1, hero23 = -1, hero24 = -1, hero25 = -1,
    hero26 = -1, hero27 = -1, hero28 = -1, hero29 = -1, hero30 = -1,
    hero31 = -1, hero32 = -1, hero33 = -1, hero34 = -1, hero35 = -1,
    hero36 = -1, hero37 = -1, hero38 = -1, hero39 = -1, hero40 = -1,
    avatarSheet = -1,
    equipmentSheet = -1,
    unitSprites = {},
    cloudA = -1,
    cloudB = -1,
    menuBg = -1,
    skillSheet = -1,        -- 技能序列帧图片句柄
    skillIconSheet = -1,    -- 武技图标精灵图句柄 (6×6)
    mapBg = -1,
    -- UI 装饰图片
    titleScroll = -1,       -- 标题卷轴横幅
    playerPanel = -1,       -- 玩家面板框
    dragonPortal = -1,      -- 龙形讨伐入口图标
    treasureChest = -1,     -- 宝箱图标(召唤武灵)
    btnCodex = -1,          -- 统一按钮框架
    rankedSelectBg = -1,    -- 排位选择背景
    towerSelectBg = -1,     -- 爬塔选择背景
    comic1 = -1,            -- 新手引导漫画1 (保留兼容)
    comic2 = -1,            -- 新手引导漫画2 (保留兼容)
    -- 战令专用图标 (替代 emoji)
    bpIconJade = -1,        -- 玉壁图标 (替代💰)
    bpIconFrag = -1,        -- 残片图标 (替代🔮)
    bpIconEquip = -1,       -- 装备图标 (替代⚔)
    bpIconExp = -1,         -- 经验图标 (替代⭐)
    bpIconCheck = -1,       -- 已领取勾选 (替代✓)
    bpIconLock = -1,        -- 未解锁锁 (替代🔒)
    bpIconMilestone = -1,   -- 里程碑旗帜 (替代★)
    bpBanner = -1,          -- 战令横幅背景
    -- 战令国风装饰素材
    bpFrameCorner = -1,     -- 面板四角云纹角饰
    bpCardGold = -1,        -- 高级卡片金色边框纹饰
    bpCardBlue = -1,        -- 免费卡片蓝色边框纹饰
    bpBadgeVip = -1,        -- 高级轨道徽章底纹
    bpBadgeFree = -1,       -- 普通轨道徽章底纹
    bpDivider = -1,         -- 国风分割线装饰
    -- 世界地图专用
    wmBg = -1,              -- 世界地图背景
    wmCityNormal = -1,      -- 普通城池图标
    wmCityCapital = -1,     -- 都城图标
    wmPanel = -1,           -- 面板卷轴背景
    wmBtnAction = -1,       -- 操作按钮底框
    wmFlagRed = -1,         -- 红旗(蜀)
    wmFlagBlue = -1,        -- 蓝旗(魏)
    wmFlagGreen = -1,       -- 绿旗(吴)
}
-- (DWP 边玩边下已启用，nvgCreateImage 不阻塞，引擎自动占位热替换)

-- (introVideo 已移除，新手引导不再使用开场视频)

-- 模块下载状态 (4 个后台模块)
moduleState = {
    equipment = { ready = false, downloading = false, progress = 0, completedCount = 0, totalCount = 0 },
    heroes    = { ready = false, downloading = false, progress = 0, completedCount = 0, totalCount = 0 },
    skills    = { ready = false, downloading = false, progress = 0, completedCount = 0, totalCount = 0 },
    battle    = { ready = false, downloading = false, progress = 0, completedCount = 0, totalCount = 0 },
}

-- 阻塞加载状态 (首页必需资源)
blockingLoadState = {
    ready = false,
    progress = 0,
    completedCount = 0,
    totalCount = 0,
}

-- 云存档加载完成标志 (与 blockingLoadState.ready 同时满足才跳出 LOADING)
saveLoadComplete = false



-- 下载面板 UI 状态 & 模块初始化标记
downloadUI = {
    panelOpen = false,
    btnRect = nil,       -- 下载按钮点击区域
    panelRect = nil,     -- 面板区域（防穿透）
    modulesInited = false,
}

-- Toast 提示
toastState = {
    text = "",
    timer = 0,       -- 剩余显示时间
    duration = 2.0,  -- 总持续时间
    category = "info", -- 分类: info/success/warning/error/reward
    startTime = 0,     -- 出现时的 gameTime
}



menuAnimTimer = 0
-- 首页菜单按钮区域 (设计坐标)
menuBtnRects = {
    battle = nil,     -- 出征作战
    gacha = nil,      -- 召唤武灵
    codex = nil,      -- 武灵录
    equip = nil,      -- 兵甲
    equipCodex = nil, -- 兵甲图录
    skillCodex = nil, -- 武技
    welfare = nil,    -- 天命赐福
    powerRank = nil,  -- 战力排行榜
    mailBox = nil,    -- 邮件按钮
    trade = nil,      -- 交易行
    formation = nil,  -- 编队
}

-- ============================================================================
-- 音频系统
-- ============================================================================
audioState = {
    scene = nil,       -- 音频专用场景
    bgmNode = nil,     -- BGM 播放节点
    bgmSource = nil,   -- BGM SoundSource
    sfxNode = nil,     -- 音效播放节点
    currentBGM = "",   -- 当前 BGM 路径 (防止重复播放)
}

-- 音频资源路径
AUDIO = {
    bgm_menu   = "audio/music_1776829948921.ogg",
    bgm_battle = "audio/music_1776829948921.ogg",
    sfx_click  = "audio/sfx/sfx_button_click.ogg",
    sfx_cast   = "audio/sfx/sfx_skill_cast.ogg",
    sfx_slash  = "audio/sfx/sfx_sword_slash.ogg",
    sfx_hit    = "audio/sfx/sfx_hit_impact.ogg",
    sfx_win    = "audio/sfx/sfx_victory.ogg",
    sfx_lose   = "audio/sfx/sfx_defeat.ogg",
    sfx_coin   = "audio/sfx/sfx_coin_collect.ogg",
    sfx_march  = "audio/sfx/sfx_march.ogg",
}

-- ============================================================================
-- CDK 兑换码系统
-- ============================================================================
cdkState = {
    codes = {
        -- 玉壁奖励兑换码 (每人终身限兑一次, 共50码)
        -- ▸ 50 玉壁 (15码)
        ["RK7N-4QXB"] = { jade = 50, desc = "50玉壁" },
        ["VF3W-8DTP"] = { jade = 50, desc = "50玉壁" },
        ["H6YJ-M2BR"] = { jade = 50, desc = "50玉壁" },
        ["W9QZ-5KNG"] = { jade = 50, desc = "50玉壁" },
        ["TX4D-7FLV"] = { jade = 50, desc = "50玉壁" },
        ["BN2P-8HKR"] = { jade = 50, desc = "50玉壁" },
        ["J5VT-3YGW"] = { jade = 50, desc = "50玉壁" },
        ["Q8BK-6XFD"] = { jade = 50, desc = "50玉壁" },
        ["NH3R-9MZJ"] = { jade = 50, desc = "50玉壁" },
        ["G7WF-4TPX"] = { jade = 50, desc = "50玉壁" },
        ["P6DK-2BVN"] = { jade = 50, desc = "50玉壁" },
        ["L9TJ-5HRQ"] = { jade = 50, desc = "50玉壁" },
        ["ZN4W-7KBG"] = { jade = 50, desc = "50玉壁" },
        ["D8FX-3VYH"] = { jade = 50, desc = "50玉壁" },
        ["K5MP-6JTR"] = { jade = 50, desc = "50玉壁" },
        -- ▸ 150 玉壁 (12码)
        ["MRK4-9JNX"] = { jade = 150, desc = "150玉壁" },
        ["FWQ8-T2DZ"] = { jade = 150, desc = "150玉壁" },
        ["Y6HP-B3KR"] = { jade = 150, desc = "150玉壁" },
        ["XNG5-W9FJ"] = { jade = 150, desc = "150玉壁" },
        ["Q7ZL-D8MK"] = { jade = 150, desc = "150玉壁" },
        ["BTV3-Y6HX"] = { jade = 150, desc = "150玉壁" },
        ["KJW9-P4FD"] = { jade = 150, desc = "150玉壁" },
        ["NRX2-H7BQ"] = { jade = 150, desc = "150玉壁" },
        ["VDT5-L3YK"] = { jade = 150, desc = "150玉壁" },
        ["WGF8-Z2NP"] = { jade = 150, desc = "150玉壁" },
        ["HXK6-R9TJ"] = { jade = 150, desc = "150玉壁" },
        ["PLM4-V7WG"] = { jade = 150, desc = "150玉壁" },
        -- ▸ 300 玉壁 (10码)
        ["7KRN-3XFP"] = { jade = 300, desc = "300玉壁" },
        ["4BTV-YH9M"] = { jade = 300, desc = "300玉壁" },
        ["2WDJ-QZ6K"] = { jade = 300, desc = "300玉壁" },
        ["9FXB-PT4V"] = { jade = 300, desc = "300玉壁" },
        ["5NKW-DR8T"] = { jade = 300, desc = "300玉壁" },
        ["8HQL-BX5F"] = { jade = 300, desc = "300玉壁" },
        ["3TZR-NW7G"] = { jade = 300, desc = "300玉壁" },
        ["6MBX-JD2K"] = { jade = 300, desc = "300玉壁" },
        ["VFN9-HTXR"] = { jade = 300, desc = "300玉壁" },
        ["4YJQ-KG3D"] = { jade = 300, desc = "300玉壁" },
        -- ▸ 600 玉壁 (7码)
        ["WK7R-3NXB"] = { jade = 600, desc = "600玉壁" },
        ["HV4J-8MTZ"] = { jade = 600, desc = "600玉壁" },
        ["QX5D-9FRW"] = { jade = 600, desc = "600玉壁" },
        ["BN8K-2TYG"] = { jade = 600, desc = "600玉壁" },
        ["TG3V-7KBR"] = { jade = 600, desc = "600玉壁" },
        ["FJ6X-4DHN"] = { jade = 600, desc = "600玉壁" },
        ["YM2P-5VFK"] = { jade = 600, desc = "600玉壁" },
        -- ▸ 1200 玉壁 (4码)
        ["9XBK-3VRN"] = { jade = 1200, desc = "1200玉壁" },
        ["4TWG-NJ8X"] = { jade = 1200, desc = "1200玉壁" },
        ["7FDR-Q5BV"] = { jade = 1200, desc = "1200玉壁" },
        ["2KNX-YT6R"] = { jade = 1200, desc = "1200玉壁" },
        -- ▸ 2500 玉壁 (2码)
        ["M7XK-3BVR"] = { jade = 2500, desc = "2500玉壁" },
        ["P4NT-6KWD"] = { jade = 2500, desc = "2500玉壁" },
        -- ▸ 1000 玉壁 (10码)
        ["KW7N2P"] = { jade = 1000, desc = "1000玉壁" },
        ["TX4B9R"] = { jade = 1000, desc = "1000玉壁" },
        ["MJ6F3D"] = { jade = 1000, desc = "1000玉壁" },
        ["VH8K5G"] = { jade = 1000, desc = "1000玉壁" },
        ["QR2W7N"] = { jade = 1000, desc = "1000玉壁" },
        ["BF9T4X"] = { jade = 1000, desc = "1000玉壁" },
        ["DK3P6J"] = { jade = 1000, desc = "1000玉壁" },
        ["YN5V8H"] = { jade = 1000, desc = "1000玉壁" },
        ["GT7M2L"] = { jade = 1000, desc = "1000玉壁" },
        ["XJ4R9W"] = { jade = 1000, desc = "1000玉壁" },
        -- ▸ 2000 玉壁 (10码)
        ["NP3K8V"] = { jade = 2000, desc = "2000玉壁" },
        ["WR6T2F"] = { jade = 2000, desc = "2000玉壁" },
        ["HX9D5B"] = { jade = 2000, desc = "2000玉壁" },
        ["JM4G7N"] = { jade = 2000, desc = "2000玉壁" },
        ["FK8W3R"] = { jade = 2000, desc = "2000玉壁" },
        ["TV2X6P"] = { jade = 2000, desc = "2000玉壁" },
        ["BG5N9J"] = { jade = 2000, desc = "2000玉壁" },
        ["QD7H4K"] = { jade = 2000, desc = "2000玉壁" },
        ["YW3F8T"] = { jade = 2000, desc = "2000玉壁" },
        ["RN6V2M"] = { jade = 2000, desc = "2000玉壁" },
        -- ▸ 5000 玉壁 (10码)
        ["VT8R3K"] = { jade = 5000, desc = "5000玉壁" },
        ["DW5N7J"] = { jade = 5000, desc = "5000玉壁" },
        ["BK6P4T"] = { jade = 5000, desc = "5000玉壁" },
        ["NJ9W2V"] = { jade = 5000, desc = "5000玉壁" },
        ["XR3M8F"] = { jade = 5000, desc = "5000玉壁" },
        ["GD7K5H"] = { jade = 5000, desc = "5000玉壁" },
        ["TN4V6B"] = { jade = 5000, desc = "5000玉壁" },
        ["WP8J3R"] = { jade = 5000, desc = "5000玉壁" },
        ["FM5X9D"] = { jade = 5000, desc = "5000玉壁" },
        ["RH2G6Y"] = { jade = 5000, desc = "5000玉壁" },
    },
    redeemed = {},         -- 已兑换的CDK码 { ["CODE"] = true }
    inputOpen = false,     -- CDK输入弹窗是否打开
    inputText = "",        -- 当前输入的文本
    resultText = "",       -- 兑换结果提示
    resultTimer = 0,       -- 结果提示显示计时
    resultOk = false,      -- 结果是否成功(控制颜色)
    redeemBtnRect = nil,
    closeBtnRect = nil,
    clearBtnRect = nil,
    inputBoxRect = nil,
    pasteBtnRect = nil,        -- 粘贴按钮区域
}

-- ============================================================================
-- 设置系统 (持久化)
-- ============================================================================
gameSettings = {
    musicVolume = 0.6,      -- 音乐音量 0~1
    sfxVolume = 0.8,        -- 音效音量 0~1
    defaultAutoMarch = false,  -- 默认自动行军
    -- 三圈按钮自定义位置 (nil=使用默认位置)
    btnOffsetX = 0,         -- 右下角基准的 X 偏移
    btnOffsetY = 0,         -- 右下角基准的 Y 偏移
    btnScale = 1.0,         -- 按钮缩放 0.5~2.0
    -- 战斗UI位置偏移 (右上角按钮组/左上角信息面板/顶部HUD+倒计时)
    rightBtnOffsetX = 0,    -- 右上角按钮组 X 偏移
    rightBtnOffsetY = 0,    -- 右侧按钮组 Y 偏移 (基准已内置136，此为额外偏移)
    infoPanelOffsetX = 0,   -- 左上角信息面板 X 偏移
    infoPanelOffsetY = 0,   -- 左上角信息面板 Y 偏移
    hudOffsetX = 0,         -- 顶部HUD+倒计时 X 偏移
    hudOffsetY = 0,         -- 顶部HUD+倒计时 Y 偏移
    fontStyle = "misans",  -- 字体风格: "misans"(默认) / "kuaile"(快乐体) / "wenkai"(文楷) / "xingshu"(行书)
    defaultBattlefield = 1, -- 默认战场 (1-8, BATTLE_LAYOUTS索引, 1=默认)
    guideCompleted = false, -- 世界地图引导是否已完成/跳过

    battleCount = 0,            -- 累计战斗次数 (用于新手提示)
    shownMarchHint = false,     -- 是否已显示过出兵策略提示
    -- 每日免广告卡 (看满3次广告, 今日战斗中广告自动跳过)
    dailyAdCount = 0,           -- 今日已看广告次数 (免广告卡专用)
    dailyAdDate = "",           -- 今日日期 (用于跨日重置)
    dailyTotalAdCount = 0,      -- 今日广告总观看次数 (每日上限20)
    dailyTotalAdDate = "",      -- 今日广告总次数日期 (用于跨日重置)
    -- 预编队 (最多10个cardIdx, 战斗商店只从编队中随机)
    formation = {},             -- e.g. {1, 5, 12, 33, ...}
}
settingsPage = {
    btnRect = nil,             -- 首页设置按钮区域
    isOpen = false,            -- 设置界面是否打开
    draggingMusic = false,     -- 是否正在拖拽音乐滑条
    draggingSfx = false,       -- 是否正在拖拽音效滑条
    musicSliderRect = nil,
    sfxSliderRect = nil,
    autoMarchToggleRect = nil,
    -- 字体按钮 rect 通过 settingsPage["font_xxx_rect"] 动态存储
    saveBtnRect = nil,
    closeBtnRect = nil,
    adjustPosBtnRect = nil,    -- "调整位置"按钮区域
    slotEditorBtnRect = nil,   -- "编辑石台"按钮区域
    -- 战斗场景按钮调整模式
    btnAdjustMode = false,     -- 是否处于按钮位置调整模式
    adjDragging = false,       -- 调整模式中是否正在拖拽按钮组
    adjDragStartX = 0,
    adjDragStartY = 0,
    adjOffsetX = 0,            -- 调整中的临时偏移
    adjOffsetY = 0,
    adjScale = 1.0,            -- 调整中的临时缩放
    adjSaveBtnRect = nil,      -- 调整模式保存按钮
    adjResetBtnRect = nil,     -- 调整模式重置按钮
    adjBackBtnRect = nil,      -- 调整模式返回按钮
    adjScaleSliderRect = nil,  -- 调整模式缩放滑条
    adjDraggingScale = false,  -- 是否在拖拽调整模式缩放滑条
    -- 多组UI调整
    adjActiveGroup = "skill",  -- 当前调整的组: "skill"(右下技能), "rightBtn"(右上按钮), "infoPanel"(左上信息), "hud"(顶部HUD)
    adjRightBtnOffsetX = 0, adjRightBtnOffsetY = 0,
    adjInfoPanelOffsetX = 0, adjInfoPanelOffsetY = 0,
    adjHudOffsetX = 0, adjHudOffsetY = 0,
    adjGroupBtnRects = {},    -- 组切换按钮区域
    battlefieldBtnRect = nil,  -- 默认战场切换按钮区域
}

-- ============================================================================
-- 玩家持久信息
-- ============================================================================
playerInfo = {
    name = "无名武灵",
    level = 1,
    exp = 0,
    rankIdx = 1,
    jade = GameConfig.INITIAL_JADE,  -- 玉壁 (抽卡货币)
    avatarIdx = 1,                   -- 头像英雄索引 (HERO_CARDS 索引)
    profileSet = false,              -- 是否已设置过个人资料
    abyssTickets = 3,               -- 讨伐票 (初始赠送3张)
    lingshi = 0,                    -- 军资 (装备分解/强化货币)
    totalBattles = 0,               -- 累计战斗次数
    totalWins = 0,                  -- 累计胜利次数
    totalGachas = 0,                -- 累计抽卡次数
    totalEquips = 0,                -- 累计装备获得数
    totalDecompose = 0,             -- 累计分解次数
    totalEnhance = 0,              -- 累计强化次数
    totalFriends = 0,              -- 好友数量
    totalFriendReqs = 0,           -- 累计发送好友请求
    totalFactionChat = 0,          -- 累计阵营聊天消息
    factionJoined = 0,             -- 是否加入阵营 (0/1)
    totalFactionCreated = 0,       -- 累计创建阵营次数
    totalRankedBattles = 0,        -- 累计排位赛场次
    totalRankedWins = 0,           -- 累计排位赛胜场
    totalExplores = 0,             -- 累计探索完成次数
    universalFrags = 0,            -- [已废弃] 保留兼容旧存档
    ad_free = false,               -- 免广告特权 (管理员邮件派发)
    jadeUnlockedBigPull = false,   -- 玉壁≥20万解锁连抽增强(10/50/100连抽)，一次解锁永久生效
}

-- ============================================================================
-- 每日任务系统
-- ============================================================================
DAILY_TASKS = {
    { id = "battle3",   name = "征伐三场",   desc = "完成3场战斗",       target = 3, reward = { jade = 500 } },
    { id = "win2",      name = "连胜两场",   desc = "赢得2场战斗",       target = 2, reward = { jade = 400 } },
    { id = "gacha1",    name = "召唤武灵",   desc = "进行1次召唤",       target = 1, reward = { jade = 300 } },
    { id = "equip1",    name = "装备兵甲",   desc = "装备1件兵甲",       target = 1, reward = { frag = 2 } },
    { id = "enhance1",  name = "强化兵甲",   desc = "强化1次装备",       target = 1, reward = { jade = 400 } },
    { id = "abyss1",    name = "讨伐挑战",   desc = "完成1次讨伐",       target = 1, reward = { jade = 600 } },
}
dailyTaskState = {
    lastResetDay = "",
    progress = {},
    claimed = {},
    allClaimedBonus = false,
}
dailyTaskBtnRects = {}
dailyTaskAllBtnRect = nil

-- ============================================================================
-- 周任务系统
-- ============================================================================
WEEKLY_TASKS = {
    { id = "wbattle15",  name = "周伐十五",   desc = "本周完成15场战斗",    target = 15, reward = { jade = 2250 } },
    { id = "wwin10",     name = "十战十捷",   desc = "本周赢得10场",        target = 10, reward = { jade = 1800 } },
    { id = "wgacha5",    name = "五连灵召",   desc = "本周召唤5次",         target = 5,  reward = { jade = 1500 } },
    { id = "wabyss3",    name = "讨伐周行",   desc = "本周完成3次讨伐",     target = 3,  reward = { jade = 2250 } },
    { id = "wenhance3",  name = "匠心三炼",   desc = "本周强化装备3次",     target = 3,  reward = { jade = 1500, frag = 3 } },
}
weeklyTaskState = {
    lastResetWeek = "",
    progress = {},
    claimed = {},
    allClaimedBonus = false,
}
weeklyTaskBtnRects = {}
weeklyTaskAllBtnRect = nil

-- ============================================================================
-- 英雄升级系统
-- ============================================================================
HERO_LEVEL_EXP = { 0, 30, 80, 150, 250, 400, 600, 850, 1200, 1600 }
HERO_MAX_LEVEL = #HERO_LEVEL_EXP

-- ============================================================================
-- 装备强化/分解系统
-- ============================================================================
DECOMPOSE_LINGSHI = { 5, 10, 20, 40, 80, 160 }
-- 强化系统: +1~+20级, 每级+5%加成
ENHANCE_MAX_LEVEL = 20
ENHANCE_PERCENT_PER_LEVEL = 5  -- 每级+5%
-- 装备自身等级系统 (独立于强化)
EQUIP_LEVEL_MAX = 30           -- 装备最高等级
EQUIP_LEVEL_BONUS = 0.3        -- 每级+0.3%基础属性 (Lv.30→+8.7%)
-- 强化费用表 (20级)：前期便宜，后期递增
ENHANCE_COST = {
    5,  8,  12, 16, 20,     -- +1 ~ +5
    25, 30, 38, 46, 55,     -- +6 ~ +10
    65, 78, 92, 108, 126,   -- +11 ~ +15
    148, 172, 200, 235, 280 -- +16 ~ +20
}

-- ============================================================================
-- 关卡星级与宝箱奖励系统
-- ============================================================================
stageStars = {}             -- ["1"] = 3  (每关0-3星)
stageStarClaimed = {}       -- ["1_1"] = true  (关卡idx_星级 已领取)
stageChestClaimed = {}      -- ["1_10"] = true  (页码_星数阈值 已领取)

-- 首次达到1/2/3星的玉壁奖励
STAGE_STAR_JADE = { 60, 100, 160 }

-- 每页宝箱: 10/20/30星阈值
STAGE_CHEST_THRESHOLDS = { 10, 20, 30 }
STAGE_CHEST_REWARDS = {
    { jade = 400, frag = 8 },    -- 10星宝箱
    { jade = 800, frag = 15 },   -- 20星宝箱
    { jade = 1500, frag = 30 },  -- 30星宝箱
}

-- 页面标题
STAGE_PAGE_NAMES = { "黄巾之乱", "三分天下", "天下归一" }

-- ============================================================================
-- 讨伐完成记录
-- ============================================================================
abyssCleared = {}
ABYSS_REWARDS = {
    { jade = 0,  frag = 5,  ticket = 0, equipDrop = 2 },
    { jade = 0,  frag = 8,  ticket = 0, equipDrop = 3 },
    { jade = 0,  frag = 10, ticket = 1, equipDrop = 4 },
    { jade = 0,  frag = 14, ticket = 1, equipDrop = 5 },
    { jade = 0,  frag = 18, ticket = 1, equipDrop = 6 },
    { jade = 0,  frag = 22, ticket = 1, equipDrop = 8 },
    { jade = 0,  frag = 30, ticket = 2, equipDrop = 12 },
}

-- ============================================================================
-- 成就系统
-- ============================================================================
ACHIEVEMENTS = {
    -- 胜利成就 (1→3→10→30→100→300)
    { id = "win1",     name = "初入乱世",   desc = "赢得1场战斗",       target = 1,    stat = "totalWins",     reward = { jade = 250 } },
    { id = "win3",     name = "小试锋芒",   desc = "累计赢得3场",       target = 3,    stat = "totalWins",     reward = { jade = 400 } },
    { id = "win10",    name = "百战武灵",   desc = "累计赢得10场",      target = 10,   stat = "totalWins",     reward = { jade = 600 } },
    { id = "win30",    name = "血战宿将",   desc = "累计赢得30场",      target = 30,   stat = "totalWins",     reward = { jade = 900 } },
    { id = "win100",   name = "天命所归",   desc = "累计赢得100场",     target = 100,  stat = "totalWins",     reward = { jade = 1250, ticket = 3 } },
    { id = "win300",   name = "万古不灭",   desc = "累计赢得300场",     target = 300,  stat = "totalWins",     reward = { jade = 1750, ticket = 5 } },
    -- 参战成就 (3→10→30→100→300)
    { id = "battle3",  name = "征伐三场",   desc = "累计参战3场",       target = 3,    stat = "totalBattles",  reward = { jade = 250 } },
    { id = "battle10", name = "久经血战",   desc = "累计参战10场",      target = 10,   stat = "totalBattles",  reward = { jade = 400 } },
    { id = "battle30", name = "血战老将",   desc = "累计参战30场",      target = 30,   stat = "totalBattles",  reward = { jade = 600 } },
    { id = "battle100",name = "百战破骨",   desc = "累计参战100场",     target = 100,  stat = "totalBattles",  reward = { jade = 900 } },
    { id = "battle300",name = "不灭战意",   desc = "累计参战300场",     target = 300,  stat = "totalBattles",  reward = { jade = 1250 } },
    -- 召唤成就 (1→5→15→50→150)
    { id = "gacha1",   name = "首次血契",   desc = "完成首次召唤",      target = 1,    stat = "totalGachas",   reward = { jade = 250 } },
    { id = "gacha5",   name = "深入血契",   desc = "累计召唤5次",       target = 5,    stat = "totalGachas",   reward = { jade = 400 } },
    { id = "gacha15",  name = "血契常客",   desc = "累计召唤15次",      target = 15,   stat = "totalGachas",   reward = { jade = 600 } },
    { id = "gacha50",  name = "万魂齐聚",   desc = "累计召唤50次",      target = 50,   stat = "totalGachas",   reward = { jade = 900 } },
    { id = "gacha150", name = "英魂主宰",   desc = "累计召唤150次",     target = 150,  stat = "totalGachas",   reward = { jade = 1250 } },
    -- 装备成就 (1→5→15→50)
    { id = "equip1",   name = "初得兵甲",   desc = "获得首件装备",      target = 1,    stat = "totalEquips",   reward = { jade = 250 } },
    { id = "equip5",   name = "兵甲入门",   desc = "累计获得5件装备",   target = 5,    stat = "totalEquips",   reward = { jade = 400 } },
    { id = "equip15",  name = "兵甲行家",   desc = "累计获得15件装备",  target = 15,   stat = "totalEquips",   reward = { jade = 600 } },
    { id = "equip50",  name = "兵甲收藏家", desc = "累计获得50件装备",  target = 50,   stat = "totalEquips",   reward = { jade = 900 } },
    -- 分解成就 (1→5→15→50)
    { id = "decomp1",  name = "初试熔炼",   desc = "分解首件装备",      target = 1,    stat = "totalDecompose", reward = { jade = 250 } },
    { id = "decomp5",  name = "熔炼入门",   desc = "累计分解5次",       target = 5,    stat = "totalDecompose", reward = { jade = 400 } },
    { id = "decomp15", name = "熔炼老手",   desc = "累计分解15次",      target = 15,   stat = "totalDecompose", reward = { jade = 600 } },
    { id = "decomp50", name = "熔炼宗师",   desc = "累计分解50次",      target = 50,   stat = "totalDecompose", reward = { jade = 900 } },
    -- 强化成就 (1→5→15→50)
    { id = "enh1",     name = "锻造初成",   desc = "完成首次强化",      target = 1,    stat = "totalEnhance",  reward = { jade = 250 } },
    { id = "enh5",     name = "锻造五成",   desc = "累计强化5次",       target = 5,    stat = "totalEnhance",  reward = { jade = 400 } },
    { id = "enh15",    name = "锻造大师",   desc = "累计强化15次",      target = 15,   stat = "totalEnhance",  reward = { jade = 600 } },
    { id = "enh50",    name = "锻造宗师",   desc = "累计强化50次",      target = 50,   stat = "totalEnhance",  reward = { jade = 900 } },
    -- 关卡通关成就 (1→3→5→7)
    { id = "stage1",   name = "初闯暗关",   desc = "通关首个关卡",      target = 1,    stat = "stagesCleared", reward = { jade = 400 } },
    { id = "stage3",   name = "三界通行",   desc = "通关3个不同关卡",   target = 3,    stat = "stagesCleared", reward = { jade = 750, ticket = 3 } },
    { id = "stage5",   name = "五关斩将",   desc = "通关5个不同关卡",   target = 5,    stat = "stagesCleared", reward = { jade = 1000, ticket = 5 } },
    { id = "stage7",   name = "六道轮回",   desc = "通关全部7个关卡",   target = 7,    stat = "stagesCleared", reward = { jade = 1500, ticket = 10 } },
    -- 讨伐成就 (1→3→5→7)
    { id = "abyss1",   name = "讨伐初探",   desc = "通关讨伐第1层",     target = 1,    stat = "abyssCleared",  reward = { jade = 500 } },
    { id = "abyss3",   name = "讨伐行者",   desc = "通关讨伐3层",       target = 3,    stat = "abyssCleared",  reward = { jade = 900, ticket = 3 } },
    { id = "abyss5",   name = "讨伐征服",   desc = "通关讨伐5层",       target = 5,    stat = "abyssCleared",  reward = { jade = 1250, ticket = 5 } },
    { id = "abyss7",   name = "渊底之主",   desc = "通关全部7层讨伐",   target = 7,    stat = "abyssCleared",  reward = { jade = 1750, ticket = 10 } },
    -- ========== 社交成就 ==========
    -- 好友成就 (1→3→5→10→20)
    { id = "friend1",  name = "初识知己",   desc = "添加首位好友",      target = 1,    stat = "totalFriends",  reward = { jade = 300 } },
    { id = "friend3",  name = "三人行",     desc = "拥有3位好友",       target = 3,    stat = "totalFriends",  reward = { jade = 500 } },
    { id = "friend5",  name = "五虎将",     desc = "拥有5位好友",       target = 5,    stat = "totalFriends",  reward = { jade = 750, ticket = 2 } },
    { id = "friend10", name = "桃园广聚",   desc = "拥有10位好友",      target = 10,   stat = "totalFriends",  reward = { jade = 1000, ticket = 3 } },
    { id = "friend20", name = "天下英杰",   desc = "拥有20位好友",      target = 20,   stat = "totalFriends",  reward = { jade = 1500, ticket = 5 } },
    -- 阵营成就 (加入→贡献→聊天)
    { id = "faction1", name = "投身阵营",   desc = "加入一个阵营",      target = 1,    stat = "factionJoined", reward = { jade = 500 } },
    { id = "fchat5",   name = "阵营交流",   desc = "发送5条阵营消息",   target = 5,    stat = "totalFactionChat", reward = { jade = 400 } },
    { id = "fchat20",  name = "阵营话事人", desc = "发送20条阵营消息",  target = 20,   stat = "totalFactionChat", reward = { jade = 750 } },
    { id = "fchat50",  name = "阵营之声",   desc = "发送50条阵营消息",  target = 50,   stat = "totalFactionChat", reward = { jade = 1000, ticket = 3 } },
    -- 好友请求成就
    { id = "freq1",    name = "广结善缘",   desc = "发送首个好友请求",  target = 1,    stat = "totalFriendReqs", reward = { jade = 250 } },
    { id = "freq10",   name = "求贤若渴",   desc = "累计发送10个好友请求", target = 10, stat = "totalFriendReqs", reward = { jade = 600 } },
    -- 排位成就
    { id = "ranked1",  name = "初入武场",   desc = "完成首场排位赛",    target = 1,    stat = "totalRankedBattles", reward = { jade = 400 } },
    { id = "ranked10", name = "竞技常客",   desc = "完成10场排位赛",    target = 10,   stat = "totalRankedBattles", reward = { jade = 750 } },
    { id = "ranked30", name = "武场悍将",   desc = "完成30场排位赛",    target = 30,   stat = "totalRankedBattles", reward = { jade = 1250, ticket = 3 } },
    { id = "rwin5",    name = "排位五连胜", desc = "排位赢得5场",       target = 5,    stat = "totalRankedWins", reward = { jade = 600 } },
    { id = "rwin20",   name = "排位高手",   desc = "排位赢得20场",      target = 20,   stat = "totalRankedWins", reward = { jade = 1000, ticket = 3 } },
    -- 探索成就
    { id = "explore1", name = "初探秘境",   desc = "完成首次探索",      target = 1,    stat = "totalExplores", reward = { jade = 300 } },
    { id = "explore5", name = "秘境行者",   desc = "完成5次探索",       target = 5,    stat = "totalExplores", reward = { jade = 600 } },
    { id = "explore20",name = "秘境征服者", desc = "完成20次探索",      target = 20,   stat = "totalExplores", reward = { jade = 1000, ticket = 3 } },
    -- 创建阵营成就
    { id = "fcreate1", name = "立旗称雄",   desc = "创建一个阵营",      target = 1,    stat = "totalFactionCreated", reward = { jade = 750, ticket = 2 } },
}
achievementClaimed = {}

progressUIState = {
    tab = 1,
    scrollY = 0,
    scrollVel = 0,
    dragStartY = nil,
    dragLastY = nil,
    isDragging = false,
    backBtnRect = nil,
}
progressTabRects = {}

-- 左侧栏滚动状态
leftSidebarScroll = {
    y = 0,
    vel = 0,
    isDragging = false,
    dragStartY = nil,
    dragLastY = nil,
    areaRect = nil,      -- 左侧栏可滚动区域 (渲染时赋值)
    contentH = 0,        -- 内容总高度
    viewH = 0,           -- 可见区域高度
}

-- 阵营界面状态
factionUI = {
    tab = "info",          -- "info" | "members" | "apply" | "list" | "create"
    loaded = false,
    loading = false,
    factions = {},         -- 阵营列表
    members = {},          -- 当前阵营成员
    applications = {},     -- 入队申请
    scroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil },
    createName = "",
    createDesc = "",
    inputTarget = nil,     -- "name" | "desc" | nil
    confirmPopup = nil,    -- { type, targetId, targetName }
    applyStatus = nil,     -- "pending" | "approved" | "rejected" | nil
    pendingAppCount = 0,   -- 首页红点: 未处理的入队申请数
    lastAppCheckTime = 0,  -- 上次检查时间戳
    -- 养成功能
    subView = nil,         -- "upgrade" | "donate" | "announce" | nil (nil=主信息页)
    donateAmount = 500,    -- 当前选择的捐献数量
    announceInput = "",    -- 公告编辑内容
    donating = false,      -- 捐献中(防重复点击)
    -- 阵营排行榜
    showRank = false,      -- 是否显示排行榜面板
    rankList = {},         -- 排行榜数据
    rankLoaded = false,
    rankLoading = false,
    -- 成员贡献排行
    contribList = {},      -- 贡献排行数据 { uid, amount, name }
    contribLoaded = false,
    contribLoading = false,
    contribScroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil },
    -- 签到状态
    signingIn = false,     -- 防重复点击
}

-- 世界聊天UI状态
worldChatUI = {
    expanded = false,      -- 是否展开大窗口
    chatInput = "",        -- 输入框内容
    inputActive = false,   -- 输入框激活
    scrollOffset = 0,      -- 消息滚动偏移
    lastMsgCount = 0,      -- 上次消息数量 (用于自动滚到底)
    miniAnim = 0,          -- 小窗动画计时器
    namePopup = nil,       -- {uid, name, x, y} 点击名字弹出的快捷操作
}

-- 聊天屏蔽词过滤
CHAT_BANNED_WORDS = {
    "傻逼", "操你", "妈的", "他妈", "草泥马", "狗日", "王八蛋",
    "滚蛋", "去死", "废物", "垃圾", "白痴", "弱智", "脑残",
    "智障", "猪头", "蠢货", "混蛋", "畜生", "贱人", "婊子",
    "尼玛", "卧槽", "艹", "TMD", "tmd", "NMSL", "nmsl",
    "CNM", "cnm", "SB", "sb", "MB", "mb",
}

-- 好友界面状态
friendsUI = {
    tab = "list",          -- "list" | "add" | "requests"
    loaded = false,
    loading = false,
    friends = {},          -- 好友资料列表
    requests = {},         -- 收到的好友请求
    recommended = {},      -- 推荐玩家
    scroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil },
    confirmPopup = nil,    -- { type, targetId, targetName }
    searchId = "",
    searchResult = nil,
    pendingReqCount = 0,   -- 首页红点: 未处理请求数
    lastReqCheckTime = 0,  -- 上次检查时间戳
}

-- 交易行界面状态
tradeState = {
    tab = "market",        -- "market" | "mine"
    scroll = { offset = 0, vel = 0, isDragging = false, dragStartY = nil, dragLastY = nil },
    selectedItem = nil,    -- 选中的市场物品 (index in marketItems)
    confirmPopup = nil,    -- { type="buy"|"unlist"|"claim_expired"|"list", data={...} }
    listPrice = "",        -- 上架定价输入
    priceInput = false,    -- 是否在输入价格
    toastMsg = nil,        -- 操作提示
    toastTimer = 0,
    btnRects = {},         -- 按钮矩形区域
}

-- 个人资料界面状态
profileState = {
    selectedAvatar = 1,   -- 当前选中的头像索引
    selectedName = 1,     -- 当前选中的预设名字索引
    customName = "",      -- 自定义名字输入
    isInputActive = false, -- 是否在自定义输入模式
}
PRESET_NAMES = { "无名武灵", "虎牢将军", "卧龙谋士", "铁骑先锋", "烽火猎手", "乱世豪杰" }
CUSTOM_NAME_IDX = #PRESET_NAMES + 1  -- "自定义名字"选项索引
AVATAR_OPTIONS = { 1, 2, 3, 4, 5, 6 }  -- 可选头像 (AVATAR_DATA 索引)
AVATAR_DATA = {
    { name = "铁骑将军", row = 0, col = 0 },
    { name = "灵狐军师", row = 0, col = 1 },
    { name = "寒冰武将", row = 1, col = 0 },
    { name = "烈焰武灵", row = 1, col = 1 },
    { name = "蛛丝女将", row = 2, col = 0 },
    { name = "白甲勇士", row = 2, col = 1 },
}
profileAvatarRects = {}  -- 头像选择按钮区域
profileNameRects = {}    -- 名字选择按钮区域
profileConfirmBtnRect = nil  -- 确认按钮区域

-- 前向声明 (定义在后面，但需要在此处声明使早期函数可访问)
HERO_CARDS = nil

-- 玩家拥有的武灵集合: playerHeroes[cardIdx] = { owned=true, constellation=0 }
playerHeroes = {}
-- 初始武灵
for _, idx in ipairs(GameConfig.INITIAL_HEROES) do
    playerHeroes[idx] = { owned = true, constellation = 0 }
end


-- 抽卡/图鉴返回按钮区域 (设计坐标)
backBtnRect = nil

-- 抽卡界面状态
gachaState = {
    results = {},        -- 本次抽卡结果 { {cardIdx, constellation, isNew, oldConst} ... }
    showResults = false, -- 是否显示抽卡结果
    animTimer = 0,       -- 动画计时器
    pulling = false,     -- 正在播放召唤动画
    pullTimer = 0,       -- 召唤动画计时
    pullCount = 0,       -- 本次抽卡数量
    pityCounter = 0,     -- 保底计数器 (距离上次SSR的抽数)
    showRules = false,   -- 是否显示概率规则弹窗
    currentTab = 1,      -- 1=召唤武灵, 2=武技召唤, 3=兵符, 4=限定
    skillResults = {},   -- 武技抽取结果 { {skillIdx, fragCount} ... }
    showFragShop = false, -- 是否显示残片仓库
    skillPityCounter = 0, -- (已废弃, 保留兼容存档)
    limitedPityCounter = 0, -- 限定池碎片保底计数器
    limitedResults = {},    -- 限定池抽取结果
}
gachaSingleBtnRect = nil  -- 单抽/十连按钮区域 (增强模式下为10连)
gachaTenBtnRect = nil     -- 十连/五十连按钮区域 (增强模式下为50连)
gachaHundredBtnRect = nil -- 百连按钮区域 (仅增强模式)
gachaBackBtnRect = nil    -- 抽卡界面返回按钮
gachaConfirmBtnRect = nil -- 结果确认按钮
gachaRulesBtnRect = nil   -- 概率规则?按钮
gachaRulesCloseBtnRect = nil -- 规则弹窗关闭按钮
gachaFragShopBtnRect = nil   -- 残片仓库按钮
gachaTabRects = {}           -- tab切换按钮区域

-- 武技残片系统 (全局, 避免200 local限制)
skillFragments = {}  -- skillFragments[skillIdx] = 残片数量
SKILL_MAX_LAYER = 5  -- 武技最高层数
SKILL_MAX_REFUND_JADE = 30  -- 满层武技再合成返还玉壁
skillLayers = {}     -- skillLayers[skillIdx] = 层数 (1~5), nil表示未解锁

-- 武灵残片系统 (全局)
heroFragments = {}   -- heroFragments[cardIdx] = 残片数量
SKILL_FRAG_EXCHANGE = 20  -- 武技残片兑换所需数量（原在 gacha 模块中定义）

HERO_FRAG_EXCHANGE = {  -- 按品质的残片兑换阶梯
    [1] = 10,   -- N  品质: 10残片兑换
    [2] = 20,   -- R  品质: 20残片兑换
    [3] = 40,   -- SR 品质: 40残片兑换
    [4] = 80,   -- SSR品质: 80残片兑换
    [5] = 120,  -- 限定SSR: 120残片兑换
}
HERO_FULL_CARD_RATE = 5   -- 整卡出率: 5% (极小概率)

-- 限定池配置
LIMITED_GACHA_COST = 300        -- 限定池单抽费用
LIMITED_GACHA_TEN_COST = 2700   -- 限定池十连费用 (9折)
LIMITED_PITY_FRAG_COUNT = 30    -- 限定池30抽碎片保底
LIMITED_FRAG_GUARANTEE_MIN = 6  -- 保底最少给6个限定碎片
LIMITED_FRAG_GUARANTEE_MAX = 8  -- 保底最多给8个限定碎片
LIMITED_DRAW_WEIGHTS = {        -- 限定池品质概率 (只出碎片, 无整卡)
    [1] = 0,    -- N  0%  (限定池不出N)
    [2] = 35,   -- R  35%
    [3] = 40,   -- SR 40%
    [4] = 15,   -- SSR 15%
    [5] = 10,   -- 限定SSR 10%
}

-- 召唤商店状态 (全局)
fragShopScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
fragShopComposeBtnRects = {}  -- fragShopComposeBtnRects[skillIdx] = rect
heroFragShopComposeBtnRects = {}  -- heroFragShopComposeBtnRects[cardIdx] = rect
fragShopOneKeyBtnRect = nil  -- 一键合成按钮区域

-- ============================================================================
-- 武灵兵符系统 (全局)
-- ============================================================================
--- 六欲孔位名称
SEAL_SLOT_NAMES = { "仁符", "义符", "礼符", "智符", "信符", "勇符" }
SEAL_MAX_SLOTS = 6        -- 每个武灵最多6孔
SEAL_MAX_LEVEL = 10       -- 每个兵符最高10级 (强化难度大提升大)
SEAL_GACHA_COST = 300     -- 兵符单抽费用 (×3)
SEAL_GACHA_TEN_COST = 2700 -- 兵符十连费用 (9折)
SEAL_DUPE_REFUND = 50     -- 重复兵符返还玉壁

--- 兵符经验需求表 (指数增长, 强化难度很大)
SEAL_EXP_TABLE = {}
for i = 1, SEAL_MAX_LEVEL do
    -- 1→2: 50, 2→3: 100, ... 9→10: ~6400 (强化难度大)
    SEAL_EXP_TABLE[i] = math.floor(50 * (2.0 ^ (i - 1)) + 0.5)
end

--- 兵符等阶 (7阶: 凡→良→优→将→侯→王→帝)
SEAL_TIER_NAMES = { [1] = "凡品", [2] = "良品", [3] = "优品", [4] = "将品", [5] = "侯品", [6] = "王品", [7] = "帝品" }
SEAL_QUALITY_NAMES = SEAL_TIER_NAMES  -- 兼容旧代码
SEAL_QUALITY_COLORS = {
    [1] = { 180, 175, 165 },  -- 凡品 灰
    [2] = { 100, 210, 120 },  -- 良品 绿
    [3] = { 80, 160, 255 },   -- 优品 蓝
    [4] = { 180, 100, 255 },  -- 将品 紫
    [5] = { 255, 140, 0 },    -- 侯品 橙
    [6] = { 255, 180, 50 },   -- 王品 金
    [7] = { 255, 80, 80 },    -- 帝品 红
}

--- 六欲兵符差异化效果系统
--- 每个孔位有独特的主副属性, 数值按 [等阶][每级] 递增
SEAL_SLOT_EFFECTS = {
    [1] = { -- 贪欲: 兵力增援
        theme = "兵力增援", desc = "增加出兵数量",
        mainKey = "extraTroops", mainName = "额外兵力",
        subKey = nil, subName = nil,
        [1] = { main = 0.1 },  -- 凡品
        [2] = { main = 0.15 }, -- 良品
        [3] = { main = 0.2 },  -- 优品
        [4] = { main = 0.3 },  -- 将品
        [5] = { main = 0.35 }, -- 侯品
        [6] = { main = 0.4 },  -- 王品
        [7] = { main = 0.5 },  -- 帝品
    },
    [2] = { -- 嗔欲: 嗜血狂攻
        theme = "嗜血狂攻", desc = "提升攻击力与暴击",
        mainKey = "atkPct", mainName = "攻击",
        subKey = "critRate", subName = "暴击率",
        [1] = { main = 1.5, sub = 0.5 },
        [2] = { main = 2.5, sub = 0.8 },
        [3] = { main = 4.0, sub = 1.2 },
        [4] = { main = 6.0, sub = 1.8 },
        [5] = { main = 7.0, sub = 2.0 },  -- 侯品
        [6] = { main = 8.0, sub = 2.5 },  -- 王品
        [7] = { main = 12.0, sub = 4.0 }, -- 帝品
    },
    [3] = { -- 痴欲: 不灭执念
        theme = "不灭执念", desc = "提升生命与减伤",
        mainKey = "hpPct", mainName = "生命",
        subKey = "dmgReduction", subName = "减伤",
        [1] = { main = 2.0, sub = 0.3 },
        [2] = { main = 3.0, sub = 0.5 },
        [3] = { main = 5.0, sub = 0.8 },
        [4] = { main = 7.0, sub = 1.2 },
        [5] = { main = 8.5, sub = 1.5 },  -- 侯品
        [6] = { main = 10.0, sub = 1.8 }, -- 王品
        [7] = { main = 15.0, sub = 2.5 }, -- 帝品
    },
    [4] = { -- 慢欲: 傲慢疾步
        theme = "傲慢疾步", desc = "提升移速与攻速",
        mainKey = "speedPct", mainName = "移速",
        subKey = "atkSpeedPct", subName = "攻速",
        [1] = { main = 1.0, sub = 0.8 },
        [2] = { main = 1.5, sub = 1.2 },
        [3] = { main = 2.5, sub = 2.0 },
        [4] = { main = 3.5, sub = 3.0 },
        [5] = { main = 4.0, sub = 3.5 },  -- 侯品
        [6] = { main = 5.0, sub = 4.0 },  -- 王品
        [7] = { main = 7.0, sub = 6.0 },  -- 帝品
    },
    [5] = { -- 疑欲: 疑心壁垒
        theme = "疑心壁垒", desc = "提升防御与反击",
        mainKey = "defPct", mainName = "防御",
        subKey = "counterRate", subName = "反击率",
        [1] = { main = 1.5, sub = 0.3 },
        [2] = { main = 2.5, sub = 0.5 },
        [3] = { main = 4.0, sub = 0.8 },
        [4] = { main = 6.0, sub = 1.2 },
        [5] = { main = 7.0, sub = 1.5 },  -- 侯品
        [6] = { main = 8.0, sub = 2.0 },  -- 王品
        [7] = { main = 12.0, sub = 3.0 }, -- 帝品
    },
    [6] = { -- 邪欲: 邪念破阵
        theme = "邪念破阵", desc = "提升突破与死亡爆炸",
        mainKey = "breakDmgPct", mainName = "突破伤害",
        subKey = "deathExplosionPct", subName = "死亡爆炸",
        [1] = { main = 2.0, sub = 0.5 },
        [2] = { main = 3.0, sub = 1.0 },
        [3] = { main = 5.0, sub = 1.5 },
        [4] = { main = 8.0, sub = 2.0 },
        [5] = { main = 10.0, sub = 2.5 }, -- 侯品
        [6] = { main = 12.0, sub = 3.0 }, -- 王品
        [7] = { main = 18.0, sub = 5.0 }, -- 帝品
    },
}
--- 六欲孔位主题色 (每个欲位的标志色, 在UI中区分)
SEAL_SLOT_THEME_COLORS = {
    [1] = { 255, 215, 80 },   -- 贪欲: 金色
    [2] = { 255, 60, 60 },    -- 嗔欲: 红色
    [3] = { 80, 220, 160 },   -- 痴欲: 青绿
    [4] = { 100, 180, 255 },  -- 慢欲: 天蓝
    [5] = { 180, 160, 220 },  -- 疑欲: 灰紫
    [6] = { 200, 50, 200 },   -- 邪欲: 紫红
}

--- 兵符经验道具 (抽卡池产出)
SEAL_EXP_ITEMS = {
    { name = "残旧兵符墨",   exp = 10,  weight = 40, img = "image/seal_exp_item_1_sanguo_bright_20260408083102.png" },  -- 常见
    { name = "精炼兵符墨",   exp = 30,  weight = 30, img = "image/seal_exp_item_2_sanguo_bright_20260408083259.png" },  -- 较常见
    { name = "上古兵符墨",   exp = 80,  weight = 20, img = "image/seal_exp_item_3_sanguo_bright_20260408083108.png" },  -- 稀有
    { name = "天命兵符墨",   exp = 200, weight = 10, img = "image/seal_exp_item_4_sanguo_bright_20260408083400.png" },  -- 极稀有
}
--- 兵符经验道具 NanoVG 图片句柄 (在 Start 中初始化)
sealExpItemImages = {}

--- 玩家兵符数据
--- sealData[cardIdx] = { slots = { [1]={sealQ=quality, level=1, exp=0}, [2]=nil, ... } }
sealData = {}
--- 玩家兵符经验道具库存
--- sealExpItems[itemIdx] = count
sealExpItems = {}

--- 兵符抽卡状态
sealGachaState = {
    results = {},        -- 本次抽卡结果列表
    showResults = false,
    pulling = false,
    pullTimer = 0,
    pullCount = 0,
    -- 无保底机制
}
sealGachaSingleBtnRect = nil
sealGachaTenBtnRect = nil
sealGachaConfirmBtnRect = nil

--- 兵符管理界面状态 (全局)
sealMgrState = {
    selectedHero = nil,  -- 当前选中的英雄cardIdx
    selectedSlot = nil,  -- 当前选中的孔位 1-6
    showLevelUp = false, -- 是否显示升级面板
    showHeroPicker = false, -- 是否显示英雄选择弹窗
}
-- 英雄选择弹窗独立滚动状态
heroPickerScroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false, contentH = 0, viewH = 0 }
sealMgrScroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false }
sealMgrBtnRects = {}     -- 各种按钮区域
sealMgrHeroRects = {}    -- 英雄选择按钮
sealMgrSlotRects = {}    -- 孔位按钮
sealMgrExpItemRects = {} -- 经验道具使用按钮
sealMgrBackBtnRect = nil
sealBatchTarget = nil    -- 一键升级目标等级 (nil=未设置, 自动初始化为当前等级+1)

--- 兵符仓库 (存放未装备的兵符)
--- sealInventory = { {slotType=1-6, sealQ=quality, level=1, exp=0, fromHero=cardIdx}, ... }
sealInventory = {}
--- 自增ID计数器 (用于仓库兵符唯一标识)
sealInventoryNextId = 1

--- 兵符替换弹窗状态
sealReplaceState = {
    show = false,        -- 是否显示替换弹窗
    heroIdx = nil,       -- 当前操作的英雄cardIdx
    slotIdx = nil,       -- 当前操作的孔位 1-6
    scroll = { y = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
}
sealReplaceBtnRects = {}   -- 替换弹窗内各按钮区域
sealReplaceListRects = {}  -- 仓库列表项的按钮区域

--- 兵符分解确认弹窗状态
sealDecomposeState = {
    show = false,         -- 是否显示分解确认弹窗
    source = nil,         -- "inventory" 或 "equipped"
    invIndex = nil,       -- 仓库索引 (source=inventory时)
    heroIdx = nil,        -- 英雄cardIdx (source=equipped时)
    slotIdx = nil,        -- 孔位索引 (source=equipped时)
}
sealDecomposeBtnRects = {} -- 分解确认弹窗按钮

--- 兵符仓库筛选/批量分解状态
sealInvFilterState = {
    filterMaxTier = 7,          -- 筛选分解品质上限 (1-7, 7=全部)
    filterSlotType = 0,         -- 筛选孔位类型 (0=全部, 1-6=指定孔位)
    selectMode = false,         -- 选中分解模式
    selectedIds = {},           -- 选中的仓库索引集合 { [invIndex]=true }
    batchConfirmShow = false,   -- 筛选分解确认弹窗
    selectConfirmShow = false,  -- 选中分解确认弹窗
}
sealInvFilterBtnRects = {}      -- 筛选/选中分解按钮区域

--- 兵符分解返还经验道具表
--- 根据品质返还不同数量的经验道具
SEAL_DECOMPOSE_RETURNS = {
    [1] = { { idx = 1, count = 1 } },                              -- 凡品: 1个残旧
    [2] = { { idx = 1, count = 2 } },                              -- 良品: 2个残旧
    [3] = { { idx = 1, count = 2 }, { idx = 2, count = 1 } },      -- 优品: 2残旧+1精炼
    [4] = { { idx = 2, count = 2 }, { idx = 3, count = 1 } },      -- 将品: 2精炼+1上古
    [5] = { { idx = 2, count = 1 }, { idx = 3, count = 2 } },      -- 侯品: 1精炼+2上古
    [6] = { { idx = 3, count = 2 }, { idx = 4, count = 1 } },      -- 王品: 2上古+1天命
    [7] = { { idx = 3, count = 1 }, { idx = 4, count = 2 } },      -- 帝品: 1上古+2天命
}


-- ============================================================================
-- 运行时全局变量存根（由引擎/平台在运行时注入，此处仅消除 LSP 警告）
-- ============================================================================
---@diagnostic disable: undefined-global
if not rawget(_G, "sdk") then
    sdk = { showAd = function() end, hasAd = function() return false end }
end
if not rawget(_G, "_isWebPlatform") then
    _isWebPlatform = false
end
if not rawget(_G, "PLATFORM_COLORS") then
    PLATFORM_COLORS = {
        shu = { main = {220, 60, 60}, light = {255, 100, 100}, dark = {160, 30, 30} },
        wei = { main = {60, 100, 220}, light = {100, 140, 255}, dark = {30, 60, 160} },
        wu = { main = {60, 180, 60}, light = {100, 220, 100}, dark = {30, 120, 30} },
        qun = { main = {180, 160, 60}, light = {220, 200, 100}, dark = {120, 100, 30} },
    }
end
if not rawget(_G, "LoadContribRank") then
    function LoadContribRank() end
end
---@diagnostic enable: undefined-global
