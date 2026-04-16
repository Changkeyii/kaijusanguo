-- ============================================================================
-- GameActions.lua - 服务端 RPC 请求分发器（含统一中间件）
-- 职责：注册 action handler、分发请求、统一前置校验
-- 中间件链：在线检查 → seq 校验 → 频率限制 → 参数校验 → 业务逻辑
-- ============================================================================

local cjson = cjson ---@diagnostic disable-line: undefined-global
local Protocol = require("network.Protocol")
local CODE = Protocol.CODE
local PlayerDataManager = require("server.PlayerDataManager")

local GameActions = {}

-- action 注册表: handlers_[actionName] = { handler, rateLimit, needDomains }
local handlers_ = {}

-- 频率限制记录: rateLimits_[userId] = { [action] = { count, windowStart } }
local rateLimits_ = {}

-- 默认频率限制: 每秒最多 5 次同类请求
local DEFAULT_RATE_LIMIT = { maxCount = 5, windowSec = 1 }

-- ============================================================================
-- Action 注册
-- ============================================================================

--- 注册 action handler
---@param actionName string
---@param opts table { handler: function, rateLimit?: {maxCount,windowSec}, needDomains?: string[] }
function GameActions.Register(actionName, opts)
    handlers_[actionName] = {
        handler = opts.handler,
        rateLimit = opts.rateLimit or DEFAULT_RATE_LIMIT,
        needDomains = opts.needDomains or {},
    }
end

-- ============================================================================
-- 中间件 - 统一前置检查
-- ============================================================================

--- 检查频率限制
local function checkRateLimit(userId, action, limit)
    if not limit then return true end

    if not rateLimits_[userId] then
        rateLimits_[userId] = {}
    end
    local userLimits = rateLimits_[userId]

    local now = os.time()
    local rec = userLimits[action]
    if not rec or (now - rec.windowStart) >= limit.windowSec then
        userLimits[action] = { count = 1, windowStart = now }
        return true
    end

    rec.count = rec.count + 1
    if rec.count > limit.maxCount then
        return false
    end
    return true
end

--- 确保懒加载域已加载（同步检查，异步加载）
local function ensureDomains(userId, domains, callback)
    if not domains or #domains == 0 then
        callback(true)
        return
    end

    local cache = PlayerDataManager.GetCache(userId)
    if not cache then
        callback(false)
        return
    end

    -- 找出未加载的域
    local toLoad = {}
    for _, domain in ipairs(domains) do
        if not cache.lazyLoaded[domain] then
            toLoad[#toLoad + 1] = domain
        end
    end

    if #toLoad == 0 then
        callback(true)
        return
    end

    -- 逐个加载（串行，保证顺序）
    local idx = 0
    local function loadNext()
        idx = idx + 1
        if idx > #toLoad then
            callback(true)
            return
        end
        PlayerDataManager.LazyLoad(userId, toLoad[idx], function(ok)
            if not ok then
                callback(false)
                return
            end
            loadNext()
        end)
    end
    loadNext()
end

-- ============================================================================
-- 请求分发
-- ============================================================================

--- 分发 GAME_REQUEST
---@param userId number 玩家 ID
---@param action string 操作名
---@param seq number 请求序号
---@param params table 请求参数
---@param replyFn fun(code: number, data?: table, msg?: string) 回复函数
function GameActions.Dispatch(userId, action, seq, params, replyFn)
    -- 1. action 是否存在
    local entry = handlers_[action]
    if not entry then
        replyFn(CODE.ERR_PARAMS, nil, "unknown action: " .. tostring(action))
        return
    end

    -- 2. 玩家是否已加载
    local cache = PlayerDataManager.GetCache(userId)
    if not cache or not cache.loaded then
        replyFn(CODE.ERR_SERVER, nil, "player data not loaded")
        return
    end

    -- 3. seq 校验（防重放）—— 特殊 action 可跳过（如 migrate_legacy）
    if action ~= "migrate_legacy" and action ~= "load_domain" then
        if not PlayerDataManager.CheckSeq(userId, seq) then
            replyFn(CODE.ERR_SEQ, nil, "seq expired or duplicate")
            return
        end
    end

    -- 4. 频率限制
    if not checkRateLimit(userId, action, entry.rateLimit) then
        replyFn(CODE.ERR_RATE_LIMIT, nil, "rate limit exceeded")
        return
    end

    -- 5. 幂等检查（如果 params 中带 opKey）
    local opKey = params and params.opKey
    if opKey then
        if PlayerDataManager.IsProcessed(userId, opKey) then
            replyFn(CODE.ERR_DUPLICATE, nil, "duplicate operation")
            return
        end
    end

    -- 6. 确保所需域已加载
    ensureDomains(userId, entry.needDomains, function(ok)
        if not ok then
            replyFn(CODE.ERR_SERVER, nil, "failed to load required domains")
            return
        end

        -- 7. 执行业务逻辑
        local success, err = pcall(entry.handler, userId, params, function(code, data, msg)
            -- 标记幂等
            if opKey and code == CODE.OK then
                PlayerDataManager.MarkProcessed(userId, opKey)
            end
            replyFn(code, data, msg)
        end)

        if not success then
            print("[GameActions] ERROR in " .. action .. ": " .. tostring(err))
            replyFn(CODE.ERR_SERVER, nil, "internal error")
        end
    end)
end

-- ============================================================================
-- 清理
-- ============================================================================

--- 清理玩家频率限制记录
function GameActions.RemovePlayer(userId)
    rateLimits_[userId] = nil
end

--- 获取已注册的 action 列表（调试用）
function GameActions.ListActions()
    local list = {}
    for name in pairs(handlers_) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

return GameActions
