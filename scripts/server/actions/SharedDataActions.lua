-- ============================================================================
-- server/actions/SharedDataActions.lua
-- 共享数据写入代理（服务端权威）
-- 将所有 clientCloud 共享数据写入（排行榜/公共信箱）改为服务端代理
-- serverCloud 和 clientCloud 共享底层排行存储，
-- 因此服务端写入后客户端 GetRankList 仍可正常读取
-- ============================================================================
local Protocol = require("network.Protocol")
local PlayerDataManager = require("server.PlayerDataManager")
local GameActions       = require("server.GameActions")

local CODE = Protocol.CODE

-- ============================================================================
-- 允许写入的 key 白名单
-- 只有在此白名单内的 key 才允许客户端通过 cloud_write 代理写入
-- ============================================================================
local PREFIX = "p_49dd_"

local ALLOWED_KEYS = {
    -- 公开档案
    [PREFIX .. "pub_profile"]    = { type = "set",    maxSize = 4096 },
    [PREFIX .. "combat_power"]   = { type = "setInt", maxVal = 999999999 },
    [PREFIX .. "realm_level"]    = { type = "setInt", maxVal = 9999 },
    -- 好友公共信箱
    [PREFIX .. "freq_outbox_ts"] = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "freq_outbox"]    = { type = "set",    maxSize = 8192 },
    [PREFIX .. "freq_resp_ts"]   = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "freq_resp"]      = { type = "set",    maxSize = 8192 },
    -- 阵营
    [PREFIX .. "camp_leader_ts"] = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "camp_meta"]      = { type = "set",    maxSize = 32768 },
    [PREFIX .. "camp_apply_ts"]  = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "camp_apply"]     = { type = "set",    maxSize = 2048 },
    [PREFIX .. "camp_resp_ts"]   = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "camp_resp"]      = { type = "set",    maxSize = 16384 },
    [PREFIX .. "faction_level"]  = { type = "setInt", maxVal = 999999999 },
    -- 阵营聊天
    [PREFIX .. "camp_chat_ts"]   = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "camp_chat"]      = { type = "set",    maxSize = 8192 },
    -- 世界聊天
    [PREFIX .. "world_chat_ts"]  = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "world_chat"]     = { type = "set",    maxSize = 4096 },
    -- 封禁
    [PREFIX .. "ban_ts"]         = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "ban_data"]       = { type = "set",    maxSize = 65536 },
    -- 邮件
    [PREFIX .. "mail_ts"]        = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "mail_outbox"]    = { type = "set",    maxSize = 32768 },
    -- 交易
    [PREFIX .. "trade_ts"]       = { type = "setInt", maxVal = 9999999999 },
    [PREFIX .. "trade_data"]     = { type = "set",    maxSize = 32768 },
    -- 存档域（社交域同步）
    [PREFIX .. "social"]         = { type = "set",    maxSize = 16384 },
    -- 排行榜数值（rank.lua 上报用，与 report_score 的 slg_* key 并行）
    [PREFIX .. "skill_count"]    = { type = "setInt", maxVal = 9999 },
    [PREFIX .. "hero_count"]     = { type = "setInt", maxVal = 9999 },
    [PREFIX .. "dummy_damage"]   = { type = "setInt", maxVal = 999999999 },
    [PREFIX .. "tower_floor"]    = { type = "setInt", maxVal = 9999 },
    [PREFIX .. "ranked_score"]   = { type = "setInt", maxVal = 999999999 },
}

-- ============================================================================
-- cloud_write: 通用共享数据写入代理
--
-- 客户端发送:
--   params = {
--     writes = {
--       { key = "p_49dd_camp_meta", value = {...} },
--       { key = "p_49dd_camp_leader_ts", value = 12345 },
--     },
--     label = "创建阵营",  -- 日志标签
--   }
--
-- 服务端验证:
--   1. 每个 key 必须在白名单内
--   2. setInt 类型校验数值范围
--   3. set 类型校验 value 存在性
--   4. 批量写入 serverCloud
-- ============================================================================
GameActions.Register("cloud_write", {
    rateLimit  = { interval = 1, burst = 10 },
    needDomains = {},
    handler = function(userId, params, replyFn)
        local writes = params.writes
        local label  = params.label or "cloud_write"

        if not writes or type(writes) ~= "table" or #writes == 0 then
            replyFn(CODE.ERR_PARAMS, nil, "writes 为空")
            return
        end

        if #writes > 20 then
            replyFn(CODE.ERR_PARAMS, nil, "单次写入 key 过多(上限20)")
            return
        end

        -- 验证每个 key
        for i, w in ipairs(writes) do
            local key = w.key
            local rule = ALLOWED_KEYS[key]
            if not rule then
                replyFn(CODE.ERR_FORBIDDEN, nil, "禁止写入 key: " .. tostring(key))
                return
            end

            if rule.type == "setInt" then
                local v = tonumber(w.value)
                if not v then
                    replyFn(CODE.ERR_PARAMS, nil, "key " .. key .. " 需要数值")
                    return
                end
                if v < 0 then
                    replyFn(CODE.ERR_VALIDATE, nil, "key " .. key .. " 不允许负数")
                    return
                end
                if rule.maxVal and v > rule.maxVal then
                    replyFn(CODE.ERR_VALIDATE, nil, "key " .. key .. " 数值超限")
                    return
                end
            else
                -- set 类型: 校验序列化后大小，防止超大数据攻击
                if rule.maxSize then
                    local ok, encoded = pcall(function()
                        local cjson = require("cjson")
                        return cjson.encode(w.value)
                    end)
                    if ok and encoded and #encoded > rule.maxSize then
                        replyFn(CODE.ERR_VALIDATE, nil, "key " .. key .. " 数据大小超限("
                            .. #encoded .. ">" .. rule.maxSize .. ")")
                        return
                    end
                end
            end
        end

        -- 执行批量写入 serverCloud
        if not rawget(_G, "serverCloud") then
            replyFn(CODE.ERR_SERVER, nil, "serverCloud 不可用")
            return
        end

        local batch = serverCloud:BatchSet(userId)
        for _, w in ipairs(writes) do
            local rule = ALLOWED_KEYS[w.key]
            if rule.type == "setInt" then
                batch:SetInt(w.key, math.floor(tonumber(w.value)))
            else
                batch:Set(w.key, w.value)
            end
        end

        batch:Save("SDA." .. label, {
            ok = function()
                -- 记录操作日志
                local keyList = {}
                for _, w in ipairs(writes) do
                    keyList[#keyList + 1] = w.key
                end
                PlayerDataManager.LogOp(userId, "cloud_write", {
                    label = label,
                    keys = keyList,
                })

                replyFn(CODE.OK, { ok = true })
            end,
            error = function(code, reason)
                print("[SharedDataActions] cloud_write error: " .. tostring(reason))
                replyFn(CODE.ERR_SERVER, nil, "写入失败: " .. tostring(reason))
            end,
        })
    end,
})

print("[SharedDataActions] 已注册: cloud_write")
return true
