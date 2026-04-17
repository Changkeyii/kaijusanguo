-- ============================================================================
-- Protocol.lua - 网络协议常量（服务端权威架构）
-- 包含：通用事件、排位事件、游戏 RPC 事件、错误码、云端键名
-- ============================================================================

local Protocol = {}

-- ============================================================================
-- 事件名称（所有 RemoteEvent 必须在此定义）
-- ============================================================================
Protocol.EVENTS = {
    -- 通用
    CLIENT_READY       = "ClientReady",         -- C→S: 客户端就绪
    WELCOME            = "Welcome",             -- S→C: 欢迎 + 初始数据
    ERROR              = "ServerError",         -- S→C: 错误通知

    -- 游戏 RPC（服务端权威核心通道）
    GAME_REQUEST       = "GameRequest",         -- C→S: 客户端请求操作
    GAME_RESPONSE      = "GameResponse",        -- S→C: 服务端回复操作结果
    STATE_SYNC         = "StateSync",           -- S→C: 服务端推送状态同步

    -- 排位模式（房间制 1v1）
    RANKED_JOIN        = "RankedJoin",          -- C→S: 加入排位匹配
    RANKED_CANCEL      = "RankedCancel",        -- C→S: 取消匹配
    RANKED_READY       = "RankedReady",         -- C→S: 确认准备
    RANKED_ACTION      = "RankedAction",        -- C→S: 对战操作
    RANKED_MATCHED     = "RankedMatched",       -- S→C: 匹配成功
    RANKED_START       = "RankedStart",         -- S→C: 对战开始
    RANKED_UPDATE      = "RankedUpdate",        -- S→C: 对战状态更新
    RANKED_END         = "RankedEnd",           -- S→C: 对战结束
}

-- ============================================================================
-- 错误码体系（统一 code + msg）
-- ============================================================================
Protocol.CODE = {
    OK                 = 1000,   -- 成功
    ERR_PARAMS         = 1001,   -- 参数错误
    ERR_COOLDOWN       = 1002,   -- 冷却中
    ERR_INSUFFICIENT   = 1003,   -- 资源不足
    ERR_NOT_FOUND      = 1004,   -- 目标不存在
    ERR_DUPLICATE      = 1005,   -- 重复操作（幂等拦截）
    ERR_FORBIDDEN      = 1006,   -- 权限不足 / 封禁
    ERR_SEQ            = 1007,   -- seq 非法（过期/重复）
    ERR_RATE_LIMIT     = 1008,   -- 频率超限
    ERR_SERVER         = 1009,   -- 服务端内部错误
    ERR_OFFLINE        = 1010,   -- 玩家不在线
    ERR_VALIDATE       = 1011,   -- 战斗校验失败
    ERR_VERSION        = 1012,   -- 数据版本不兼容
    ERR_BANNED         = 1013,   -- 账号被封禁
    ERR_MIGRATING      = 1014,   -- 数据迁移中
}

-- 错误码 → 默认消息映射
Protocol.CODE_MSG = {
    [1000] = "成功",
    [1001] = "参数错误",
    [1002] = "操作过于频繁，请稍后再试",
    [1003] = "资源不足",
    [1004] = "目标不存在",
    [1005] = "重复操作",
    [1006] = "权限不足",
    [1007] = "请求已过期",
    [1008] = "操作过于频繁",
    [1009] = "服务器内部错误",
    [1010] = "玩家不在线",
    [1011] = "战斗数据校验失败",
    [1012] = "数据版本不兼容，请更新游戏",
    [1013] = "账号已被封禁",
    [1014] = "数据迁移中，请稍后",
}

-- ============================================================================
-- serverCloud 数据键名
-- ============================================================================
Protocol.CLOUD_KEYS = {
    -- 存档 domain（Score 域，存 JSON table）
    SV_CORE            = "p_49dd_sv_core",
    SV_HEROES          = "p_49dd_sv_heroes",
    SV_EQUIP           = "p_49dd_sv_equip",
    SV_SKILLS          = "p_49dd_sv_skills",
    SV_PROGRESS        = "p_49dd_sv_progress",
    SV_WELFARE         = "p_49dd_sv_welfare",
    SV_SOCIAL          = "p_49dd_sv_social",
    SV_EXPLORE         = "p_49dd_sv_explore",
    SV_WORLDMAP        = "p_49dd_sv_worldmap",

    -- 货币（money 子对象）
    MONEY_JADE         = "p_49dd_jade",
    MONEY_LINGSHI      = "p_49dd_lingshi",
    MONEY_HUFU         = "p_49dd_hufu",

    -- 排行榜（iScore 域，整数）
    RANKED_ELO         = "p_49dd_ranked_score",
    RANKED_WINS        = "p_49dd_ranked_wins",
    RANKED_LOSSES      = "p_49dd_ranked_losses",
    COMBAT_POWER       = "p_49dd_combat_power",
    REALM_LEVEL        = "p_49dd_realm_level",
    TOWER_FLOOR        = "p_49dd_tower_floor",
    DUMMY_DAMAGE       = "p_49dd_dummy_damage",
    SKILL_COUNT        = "p_49dd_skill_count",
    HERO_COUNT         = "p_49dd_hero_count",

    -- 配额（quota 子对象）
    AD_WATCH           = "p_49dd_ad_watch",
    DAILY_SIGNIN       = "p_49dd_daily_signin",

    -- 迁移标记
    MIGRATED           = "p_49dd_migrated",

    -- 操作日志（用于审计）
    OP_LOG             = "p_49dd_op_log",
}

-- domain 名 → cloud key 映射
Protocol.DOMAIN_KEYS = {
    core      = "p_49dd_sv_core",
    heroes    = "p_49dd_sv_heroes",
    equip     = "p_49dd_sv_equip",
    skills    = "p_49dd_sv_skills",
    progress  = "p_49dd_sv_progress",
    welfare   = "p_49dd_sv_welfare",
    social    = "p_49dd_sv_social",
    explore   = "p_49dd_sv_explore",
    worldmap  = "p_49dd_sv_worldmap",
}

-- 必须在登录时同步的 domain（懒加载优化：其他 domain 按需加载）
Protocol.EAGER_DOMAINS = { "core", "heroes", "equip" }
-- 可延迟加载的 domain
Protocol.LAZY_DOMAINS = { "skills", "progress", "welfare", "social", "explore", "worldmap" }

-- ============================================================================
-- 数据版本号（用于存档结构升级）
-- ============================================================================
Protocol.DATA_VERSION = 3  -- v2=旧clientCloud, v3=新serverCloud权威

return Protocol
