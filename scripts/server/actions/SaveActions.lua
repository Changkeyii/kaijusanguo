-- ============================================================================
-- SaveActions.lua - 服务端存档操作（保存/加载/迁移）
-- action: save_domain, save_all, load_domain, migrate_legacy
-- ============================================================================

local GameActions = require("server.GameActions")
local PlayerDataManager = require("server.PlayerDataManager")
local Protocol = require("network.Protocol")
local CODE = Protocol.CODE
local DK = Protocol.DOMAIN_KEYS

-- 所有合法域名
local VALID_DOMAINS = {}
for domain in pairs(DK) do
    VALID_DOMAINS[domain] = true
end

-- 域数据大小上限 (序列化后字节数)
local DOMAIN_MAX_SIZE = {
    core      = 131072,   -- 128 KB
    heroes    = 262144,   -- 256 KB
    equip     = 262144,   -- 256 KB
    skills    = 131072,   -- 128 KB
    progress  = 131072,   -- 128 KB
    welfare   = 65536,    -- 64 KB
    social    = 65536,    -- 64 KB
    explore   = 131072,   -- 128 KB
    worldmap  = 131072,   -- 128 KB
}
local DEFAULT_MAX_SIZE = 131072 -- 默认 128 KB

--- 校验域数据大小，返回 nil 或错误信息
local function _validateDomainSize(domain, data)
    local cjson = require("cjson")
    local ok, encoded = pcall(cjson.encode, data)
    if not ok then
        return "data encode failed: " .. tostring(encoded)
    end
    local maxSize = DOMAIN_MAX_SIZE[domain] or DEFAULT_MAX_SIZE
    if #encoded > maxSize then
        return "domain " .. domain .. " data too large ("
            .. #encoded .. " > " .. maxSize .. " bytes)"
    end
    return nil
end

--- 校验 core 域关键资源 (非负 + 合理范围)
local function _validateCoreResources(data)
    if type(data) ~= "table" then return nil end
    local pi = data.playerInfo
    if type(pi) ~= "table" then return nil end

    -- 资源类字段不允许为负
    local resourceFields = { "jade", "lingshi", "hufu", "gold", "diamond" }
    for _, field in ipairs(resourceFields) do
        local v = pi[field]
        if v ~= nil and type(v) == "number" and v < 0 then
            return "core.playerInfo." .. field .. " cannot be negative (" .. tostring(v) .. ")"
        end
    end

    -- 等级合理范围
    if pi.level and (type(pi.level) ~= "number" or pi.level < 1 or pi.level > 9999) then
        return "core.playerInfo.level out of range: " .. tostring(pi.level)
    end

    return nil
end

-- ============================================================================
-- save_domain: 保存单个域
-- params: { domain: string, data: table }
-- ============================================================================
GameActions.Register("save_domain", {
    rateLimit = { maxCount = 10, windowSec = 1 },
    handler = function(userId, params, reply)
        local domain = params.domain
        local data = params.data

        if not domain or not VALID_DOMAINS[domain] then
            reply(CODE.ERR_PARAMS, nil, "invalid domain: " .. tostring(domain))
            return
        end
        if type(data) ~= "table" then
            reply(CODE.ERR_PARAMS, nil, "data must be table")
            return
        end

        -- 数据大小校验
        local sizeErr = _validateDomainSize(domain, data)
        if sizeErr then
            reply(CODE.ERR_VALIDATE, nil, sizeErr)
            return
        end

        -- core 域资源合法性校验
        if domain == "core" then
            local resErr = _validateCoreResources(data)
            if resErr then
                reply(CODE.ERR_VALIDATE, nil, resErr)
                PlayerDataManager.LogOp(userId, "save_domain_rejected", {
                    domain = domain, reason = resErr,
                })
                return
            end
        end

        -- 注入服务端时间戳
        data.savedAt = os.time()
        data.savedBy = "server"

        PlayerDataManager.SetDomain(userId, domain, data)

        reply(CODE.OK, { domain = domain })

        -- 日志（仅关键域）
        if domain == "core" then
            PlayerDataManager.LogOp(userId, "save_domain", { domain = domain })
        end
    end,
})

-- ============================================================================
-- save_all: 保存所有域（全量保存）
-- params: { domains: { core={...}, heroes={...}, ... } }
-- ============================================================================
GameActions.Register("save_all", {
    rateLimit = { maxCount = 2, windowSec = 10 },  -- 全量保存频率更低
    handler = function(userId, params, reply)
        local domains = params.domains
        if type(domains) ~= "table" then
            reply(CODE.ERR_PARAMS, nil, "domains must be table")
            return
        end

        local savedDomains = {}
        local skippedDomains = {}
        local now = os.time()

        for domain, data in pairs(domains) do
            if VALID_DOMAINS[domain] and type(data) == "table" then
                -- 数据大小校验
                local sizeErr = _validateDomainSize(domain, data)
                if sizeErr then
                    skippedDomains[#skippedDomains + 1] = domain
                    print("[SaveActions] save_all 跳过 " .. domain .. ": " .. sizeErr)
                else
                    -- core 域资源合法性校验
                    if domain == "core" then
                        local resErr = _validateCoreResources(data)
                        if resErr then
                            skippedDomains[#skippedDomains + 1] = domain
                            print("[SaveActions] save_all 拒绝 core: " .. resErr)
                            PlayerDataManager.LogOp(userId, "save_all_rejected", {
                                domain = domain, reason = resErr,
                            })
                        else
                            data.savedAt = now
                            data.savedBy = "server"
                            PlayerDataManager.SetDomain(userId, domain, data)
                            savedDomains[#savedDomains + 1] = domain
                        end
                    else
                        data.savedAt = now
                        data.savedBy = "server"
                        PlayerDataManager.SetDomain(userId, domain, data)
                        savedDomains[#savedDomains + 1] = domain
                    end
                end
            end
        end

        -- 立即 flush（全量保存比较重要）
        local replyData = { saved = savedDomains }
        if #skippedDomains > 0 then
            replyData.skipped = skippedDomains
        end
        PlayerDataManager.Flush(userId, function(ok, msg)
            if ok then
                reply(CODE.OK, replyData)
            else
                -- 数据已在内存，下次 TickFlush 会重试
                replyData.flushPending = true
                reply(CODE.OK, replyData)
            end
        end)

        PlayerDataManager.LogOp(userId, "save_all", {
            domains = savedDomains,
        })
    end,
})

-- ============================================================================
-- load_domain: 加载懒加载域
-- params: { domain: string }
-- ============================================================================
GameActions.Register("load_domain", {
    rateLimit = { maxCount = 10, windowSec = 1 },
    handler = function(userId, params, reply)
        local domain = params.domain
        if not domain or not VALID_DOMAINS[domain] then
            reply(CODE.ERR_PARAMS, nil, "invalid domain: " .. tostring(domain))
            return
        end

        PlayerDataManager.LazyLoad(userId, domain, function(ok, data)
            if ok then
                reply(CODE.OK, {
                    domains = { [domain] = data },
                })
            else
                reply(CODE.ERR_SERVER, nil, "failed to load domain: " .. tostring(data))
            end
        end)
    end,
})

-- ============================================================================
-- migrate_legacy: 从 clientCloud 迁移旧存档到 serverCloud
-- params: { domains: { core={...}, heroes={...}, ... }, money: { jade=N, ... } }
-- ============================================================================
GameActions.Register("migrate_legacy", {
    rateLimit = { maxCount = 1, windowSec = 60 },  -- 迁移操作严格限流
    handler = function(userId, params, reply)
        local domains = params.domains
        local money = params.money

        if type(domains) ~= "table" then
            reply(CODE.ERR_PARAMS, nil, "domains must be table")
            return
        end

        -- 检查是否已迁移
        local cache = PlayerDataManager.GetCache(userId)
        if cache and cache.migrated then
            reply(CODE.ERR_DUPLICATE, nil, "already migrated")
            return
        end

        -- 注入货币到 core.playerInfo（供 MigrateLegacy 提取）
        if money and domains.core then
            if not domains.core.playerInfo then
                domains.core.playerInfo = {}
            end
            local pi = domains.core.playerInfo
            pi.jade = money.jade or pi.jade or 0
            pi.lingshi = money.lingshi or pi.lingshi or 0
            pi.hufu = money.hufu or pi.hufu or 0
        end

        PlayerDataManager.MigrateLegacy(userId, domains, function(ok, msg)
            if ok then
                -- 重新加载以获取最新缓存
                local updatedCache = PlayerDataManager.GetCache(userId)
                reply(CODE.OK, {
                    migrated = true,
                    version = Protocol.DATA_VERSION,
                })

                PlayerDataManager.LogOp(userId, "migrate_legacy", {
                    domainCount = 0, -- 不暴露细节
                })
            else
                reply(CODE.ERR_SERVER, nil, "migration failed: " .. tostring(msg))
            end
        end)
    end,
})

print("[SaveActions] Registered: save_domain, save_all, load_domain, migrate_legacy")
