-- ============================================================================
-- Protocol.lua - 常驻服务器网络协议常量
-- 用于客户端与常驻服务端之间的云数据、排行和排位对战通信
-- ============================================================================

local Protocol = {}

-- ============================================================================
-- 事件名称（所有 RemoteEvent 必须在此定义）
-- ============================================================================
Protocol.EVENTS = {
    -- 通用
    CLIENT_READY       = "ClientReady",         -- C→S: 客户端就绪
    WELCOME            = "Welcome",             -- S→C: 欢迎 + 初始数据
    ERROR              = "ServerError",          -- S→C: 错误通知
    CLOUD_REQUEST      = "CloudRequest",        -- C→S: 通用云数据请求
    CLOUD_RESPONSE     = "CloudResponse",       -- S→C: 通用云数据响应

    -- 管理员操作（服务端权威，UID校验）
    ADMIN_REQUEST      = "AdminRequest",        -- C→S: 管理员请求
    ADMIN_RESPONSE     = "AdminResponse",       -- S→C: 管理员响应

    -- 排位模式（由常驻服务器撮合与结算）
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
-- serverCloud 数据键名（排位 Elo 相关）
-- ============================================================================
Protocol.CLOUD_KEYS = {
    -- iScore 域（整数，用于排行榜）
    RANKED_ELO         = "slg_ranked_elo",
    RANKED_WINS        = "slg_ranked_wins",
    RANKED_LOSSES      = "slg_ranked_losses",
}

return Protocol
