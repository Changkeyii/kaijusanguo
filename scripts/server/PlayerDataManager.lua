-- ============================================================================
-- PlayerDataManager.lua - 服务端权威玩家数据管理器
-- 职责：加载/缓存/保存所有玩家数据（替代旧 DataManager 的排位 Elo 职能）
-- 特性：内存缓存 + 定时 flush + 分域加载 + 数据版本迁移
-- ============================================================================

local cjson = cjson ---@diagnostic disable-line: undefined-global
local Protocol = require("network.Protocol")
local CK = Protocol.CLOUD_KEYS
local DK = Protocol.DOMAIN_KEYS

local PlayerDataManager = {}

-- ============================================================================
-- 内存缓存
-- ============================================================================

-- playerCache_[userId] = {
--     loaded = false,           -- 基础域是否加载完成
--     lazyLoaded = {},          -- { [domain] = true } 已懒加载的域
--     domains = {},             -- { [domain] = table } 各域数据
--     money = {},               -- { jade=0, lingshi=0, hufu=0 } 货币缓存
--     dirty = {},               -- { [domain] = true } 脏标记
--     lastFlush = 0,            -- 上次 flush 时间
--     seq = 0,                  -- 客户端最新 seq（防重放）
--     processedOps = {},        -- 已处理的幂等 key { [opKey] = timestamp }
--     version = 0,              -- 数据版本号
-- }
local playerCache_ = {}

-- 配置
local FLUSH_INTERVAL = 30          -- 定时 flush 间隔（秒）
local OP_HISTORY_MAX = 200         -- 幂等记录最大保留数
local OP_HISTORY_EXPIRE = 3600     -- 幂等记录过期时间（秒）

-- ============================================================================
-- 初始化 / 获取
-- ============================================================================

--- 获取玩家缓存（可能未加载完成）
function PlayerDataManager.GetCache(userId)
    return playerCache_[userId]
end

--- 确保缓存结构存在
function PlayerDataManager.EnsureCache(userId)
    if not playerCache_[userId] then
        playerCache_[userId] = {
            loaded = false,
            lazyLoaded = {},
            domains = {},
            money = { jade = 0, lingshi = 0, hufu = 0 },
            dirty = {},
            lastFlush = 0,
            seq = 0,
            processedOps = {},
            version = 0,
        }
    end
    return playerCache_[userId]
end

--- 获取某个域的数据
function PlayerDataManager.GetDomain(userId, domain)
    local cache = playerCache_[userId]
    if not cache then return nil end
    return cache.domains[domain]
end

--- 设置某个域的数据并标脏
function PlayerDataManager.SetDomain(userId, domain, data)
    local cache = PlayerDataManager.EnsureCache(userId)
    cache.domains[domain] = data
    cache.dirty[domain] = true
end

--- 获取货币
function PlayerDataManager.GetMoney(userId)
    local cache = playerCache_[userId]
    if not cache then return { jade = 0, lingshi = 0, hufu = 0 } end
    return cache.money
end

-- ============================================================================
-- seq 管理（防重放）
-- ============================================================================

--- 检查并更新 seq，返回是否合法
function PlayerDataManager.CheckSeq(userId, seq)
    local cache = PlayerDataManager.EnsureCache(userId)
    if seq <= cache.seq then
        return false  -- seq 过期或重复
    end
    cache.seq = seq
    return true
end

--- 获取当前 seq
function PlayerDataManager.GetSeq(userId)
    local cache = playerCache_[userId]
    return cache and cache.seq or 0
end

-- ============================================================================
-- 幂等性管理
-- ============================================================================

--- 检查操作是否已处理过（幂等）
function PlayerDataManager.IsProcessed(userId, opKey)
    local cache = playerCache_[userId]
    if not cache then return false end
    return cache.processedOps[opKey] ~= nil
end

--- 标记操作已处理
function PlayerDataManager.MarkProcessed(userId, opKey)
    local cache = PlayerDataManager.EnsureCache(userId)
    cache.processedOps[opKey] = os.time()
    -- 清理过期记录
    PlayerDataManager._cleanupOps(userId)
end

function PlayerDataManager._cleanupOps(userId)
    local cache = playerCache_[userId]
    if not cache then return end
    local now = os.time()
    local count = 0
    for k, t in pairs(cache.processedOps) do
        count = count + 1
        if now - t > OP_HISTORY_EXPIRE then
            cache.processedOps[k] = nil
            count = count - 1
        end
    end
    -- 超过上限时强制清理最旧的
    if count > OP_HISTORY_MAX then
        local oldest_k, oldest_t = nil, math.huge
        for k, t in pairs(cache.processedOps) do
            if t < oldest_t then oldest_k, oldest_t = k, t end
        end
        if oldest_k then cache.processedOps[oldest_k] = nil end
    end
end

-- ============================================================================
-- 加载玩家数据（登录时调用）
-- ============================================================================

--- 加载必需域（core + heroes + equip）+ 货币
function PlayerDataManager.LoadPlayer(userId, callback)
    local cache = PlayerDataManager.EnsureCache(userId)

    if not serverCloud then
        print("[PDM] WARNING: serverCloud not available, using defaults")
        cache.loaded = true
        if callback then callback(true, cache) end
        return
    end

    -- 批量加载必需域 + 排位数据 + 迁移标记
    local batch = serverCloud:BatchGet(userId)
    for _, domain in ipairs(Protocol.EAGER_DOMAINS) do
        batch:Key(DK[domain])
    end
    batch:Key(CK.RANKED_ELO)
    batch:Key(CK.RANKED_WINS)
    batch:Key(CK.RANKED_LOSSES)
    batch:Key(CK.MIGRATED)

    batch:Fetch({
        ok = function(scores, iscores)
            -- 加载域数据
            for _, domain in ipairs(Protocol.EAGER_DOMAINS) do
                cache.domains[domain] = scores[DK[domain]] or {}
                cache.lazyLoaded[domain] = true
            end

            -- 检测数据版本
            local coreData = cache.domains.core or {}
            cache.version = coreData.dataVersion or 0

            -- 排位数据兼容（保留旧字段）
            cache.elo = iscores[CK.RANKED_ELO] or 1000
            cache.wins = iscores[CK.RANKED_WINS] or 0
            cache.losses = iscores[CK.RANKED_LOSSES] or 0

            -- 检查是否需要从 clientCloud 迁移
            cache.migrated = (iscores[CK.MIGRATED] or 0) >= 1

            cache.loaded = true
            cache.lastFlush = os.time()

            print("[PDM] Player " .. tostring(userId) .. " loaded, migrated=" .. tostring(cache.migrated)
                .. ", version=" .. cache.version)

            -- 加载货币
            PlayerDataManager._loadMoney(userId, function()
                if callback then callback(true, cache) end
            end)
        end,
        error = function(code, reason)
            print("[PDM] Load error: " .. tostring(code) .. " " .. tostring(reason))
            cache.loaded = true  -- 使用默认值继续
            if callback then callback(false, cache) end
        end,
    })
end

--- 加载货币
function PlayerDataManager._loadMoney(userId, callback)
    local cache = playerCache_[userId]
    if not cache then
        if callback then callback() end
        return
    end

    if not serverCloud then
        if callback then callback() end
        return
    end

    serverCloud.money:Get(userId, {
        ok = function(moneys)
            cache.money.jade = moneys[CK.MONEY_JADE] or 0
            cache.money.lingshi = moneys[CK.MONEY_LINGSHI] or 0
            cache.money.hufu = moneys[CK.MONEY_HUFU] or 0
            print("[PDM] Money loaded: jade=" .. cache.money.jade
                .. " lingshi=" .. cache.money.lingshi .. " hufu=" .. cache.money.hufu)
            if callback then callback() end
        end,
        error = function(code, reason)
            print("[PDM] Money load error: " .. tostring(reason))
            if callback then callback() end
        end,
    })
end

-- ============================================================================
-- 懒加载（按需加载域）
-- ============================================================================

--- 懒加载指定域
function PlayerDataManager.LazyLoad(userId, domain, callback)
    local cache = playerCache_[userId]
    if not cache or not cache.loaded then
        if callback then callback(false, "player not loaded") end
        return
    end

    -- 已加载则直接返回
    if cache.lazyLoaded[domain] then
        if callback then callback(true, cache.domains[domain]) end
        return
    end

    local key = DK[domain]
    if not key then
        if callback then callback(false, "unknown domain: " .. tostring(domain)) end
        return
    end

    if not serverCloud then
        cache.domains[domain] = {}
        cache.lazyLoaded[domain] = true
        if callback then callback(true, {}) end
        return
    end

    serverCloud:Get(userId, key, {
        ok = function(scores)
            cache.domains[domain] = scores[key] or {}
            cache.lazyLoaded[domain] = true
            print("[PDM] LazyLoad " .. domain .. " for " .. tostring(userId))
            if callback then callback(true, cache.domains[domain]) end
        end,
        error = function(code, reason)
            cache.domains[domain] = {}
            cache.lazyLoaded[domain] = true
            print("[PDM] LazyLoad error " .. domain .. ": " .. tostring(reason))
            if callback then callback(false, reason) end
        end,
    })
end

-- ============================================================================
-- 保存（flush 脏数据到 serverCloud）
-- ============================================================================

--- Flush 所有脏域到 serverCloud
function PlayerDataManager.Flush(userId, callback)
    local cache = playerCache_[userId]
    if not cache then
        if callback then callback(false, "no cache") end
        return
    end

    -- 收集脏域
    local dirtyDomains = {}
    for domain, isDirty in pairs(cache.dirty) do
        if isDirty and cache.domains[domain] then
            dirtyDomains[#dirtyDomains + 1] = domain
        end
    end

    if #dirtyDomains == 0 then
        if callback then callback(true, "nothing to flush") end
        return
    end

    if not serverCloud then
        -- 清除脏标记
        for _, domain in ipairs(dirtyDomains) do
            cache.dirty[domain] = nil
        end
        if callback then callback(true, "no serverCloud") end
        return
    end

    -- BatchSet 批量写入
    local batch = serverCloud:BatchSet(userId)
    for _, domain in ipairs(dirtyDomains) do
        batch:Set(DK[domain], cache.domains[domain])
    end

    batch:Save("PDM.Flush", {
        ok = function()
            for _, domain in ipairs(dirtyDomains) do
                cache.dirty[domain] = nil
            end
            cache.lastFlush = os.time()
            print("[PDM] Flush " .. #dirtyDomains .. " domains for " .. tostring(userId))
            if callback then callback(true) end
        end,
        error = function(code, reason)
            print("[PDM] Flush error: " .. tostring(reason))
            if callback then callback(false, reason) end
        end,
    })
end

--- 定时 Flush 检查（在 Server Update 中调用）
function PlayerDataManager.TickFlush()
    local now = os.time()
    for userId, cache in pairs(playerCache_) do
        if cache.loaded and (now - cache.lastFlush) >= FLUSH_INTERVAL then
            -- 有脏数据才 flush
            local hasDirty = false
            for _ in pairs(cache.dirty) do hasDirty = true; break end
            if hasDirty then
                PlayerDataManager.Flush(userId)
            else
                cache.lastFlush = now
            end
        end
    end
end

-- ============================================================================
-- 数据迁移（clientCloud → serverCloud）
-- ============================================================================

--- 接收客户端上传的旧存档并写入 serverCloud
function PlayerDataManager.MigrateLegacy(userId, allDomainData, callback)
    local cache = PlayerDataManager.EnsureCache(userId)

    if cache.migrated then
        print("[PDM] Already migrated for " .. tostring(userId))
        if callback then callback(true, "already migrated") end
        return
    end

    if not serverCloud then
        if callback then callback(false, "no serverCloud") end
        return
    end

    -- 写入所有域 + 标记迁移完成
    local batch = serverCloud:BatchSet(userId)
    for domain, key in pairs(DK) do
        local data = allDomainData[domain]
        if data then
            batch:Set(key, data)
            cache.domains[domain] = data
            cache.lazyLoaded[domain] = true
        end
    end
    batch:SetInt(CK.MIGRATED, 1)

    batch:Save("PDM.Migrate", {
        ok = function()
            cache.migrated = true
            cache.loaded = true

            -- 同步货币到 money 子对象
            local coreData = allDomainData.core
            if coreData and coreData.playerInfo then
                local pi = coreData.playerInfo
                local jade = pi.jade or 0
                local lingshi = pi.lingshi or 0
                local hufu = pi.hufu or 0
                if jade > 0 or lingshi > 0 or hufu > 0 then
                    local c = serverCloud:BatchCommit("migrate_money")
                    if jade > 0 then c:MoneyAdd(userId, CK.MONEY_JADE, jade) end
                    if lingshi > 0 then c:MoneyAdd(userId, CK.MONEY_LINGSHI, lingshi) end
                    if hufu > 0 then c:MoneyAdd(userId, CK.MONEY_HUFU, hufu) end
                    c:Commit({
                        ok = function()
                            cache.money.jade = jade
                            cache.money.lingshi = lingshi
                            cache.money.hufu = hufu
                            print("[PDM] Money migrated for " .. tostring(userId))
                        end,
                    })
                end
            end

            print("[PDM] Migration complete for " .. tostring(userId))
            if callback then callback(true) end
        end,
        error = function(code, reason)
            print("[PDM] Migration error: " .. tostring(reason))
            if callback then callback(false, reason) end
        end,
    })
end

-- ============================================================================
-- 清理
-- ============================================================================

--- 玩家断开时 flush 后清理缓存
function PlayerDataManager.RemovePlayer(userId)
    local cache = playerCache_[userId]
    if cache then
        -- 先 flush 脏数据
        local hasDirty = false
        for _ in pairs(cache.dirty) do hasDirty = true; break end
        if hasDirty then
            PlayerDataManager.Flush(userId, function()
                playerCache_[userId] = nil
                print("[PDM] Player " .. tostring(userId) .. " flushed and removed")
            end)
        else
            playerCache_[userId] = nil
            print("[PDM] Player " .. tostring(userId) .. " removed")
        end
    end
end

-- ============================================================================
-- 操作日志（关键操作落库）
-- ============================================================================

--- 记录操作日志
---@param userId number
---@param opType string 操作类型（如 "currency_add", "equip_enhance"）
---@param details table { old=x, new=y, reason="..." }
function PlayerDataManager.LogOp(userId, opType, details)
    if not serverCloud then return end

    local logEntry = {
        uid = userId,
        op = opType,
        ts = os.time(),
    }
    -- 合并 details
    if details then
        for k, v in pairs(details) do
            logEntry[k] = v
        end
    end

    -- 使用 list:Add 追加日志（异步，不阻塞）
    serverCloud.list:Add(userId, CK.OP_LOG, logEntry)
end

return PlayerDataManager
