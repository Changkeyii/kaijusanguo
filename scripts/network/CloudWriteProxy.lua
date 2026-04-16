-- ============================================================================
-- CloudWriteProxy.lua - 客户端云端共享数据写入代理
-- 统一封装 clientCloud 共享数据写入，自动路由:
--   - 多人模式 (cl_state) → 服务端 RPC (cloud_write action)
--   - 单机模式 → clientCloud 直接写入
-- serverCloud 和 clientCloud 共享底层排行存储，
-- 因此服务端写入后客户端 GetRankList 仍可正常读取
-- ============================================================================

local CloudWriteProxy = {}

--- 检查是否有可用的写入通道（cl_state 或 clientCloud）
---@return boolean
function CloudWriteProxy.IsAvailable()
    return rawget(_G, "cl_state") ~= nil or rawget(_G, "clientCloud") ~= nil
end

--- 批量写入共享数据
--- 自动路由: cl_state → 服务端 RPC, 否则 → clientCloud 直接写入
---@param writes table[] 写入项数组 { {key=string, value=any, int=boolean?}, ... }
---@param label string 操作描述（日志/追踪用）
---@param opts? table 回调 { ok=function(), error=function(code_or_reason, reason?) }
function CloudWriteProxy.Write(writes, label, opts)
    opts = opts or {}

    if rawget(_G, "cl_state") then
        -- ── 服务端权威模式：走 RPC ──
        local ClientNet = require("network.Client")
        local rpcWrites = {}
        for _, w in ipairs(writes) do
            rpcWrites[#rpcWrites + 1] = { key = w.key, value = w.value, int = w.int or nil }
        end
        ClientNet.Request("cloud_write", {
            writes = rpcWrites,
            label = label,
        }, function(ok, code, data, msg)
            if ok then
                if opts.ok then opts.ok() end
            else
                print("[CWP] RPC失败 (" .. label .. "): " .. tostring(msg))
                if opts.error then opts.error(code, tostring(msg)) end
            end
        end)
    else
        -- ── 单机模式：clientCloud 直接写入 ──
        if not rawget(_G, "clientCloud") then
            if opts.error then opts.error(0, "clientCloud不可用") end
            return
        end
        local batch = clientCloud:BatchSet()
        for _, w in ipairs(writes) do
            if w.int then
                batch:SetInt(w.key, math.floor(tonumber(w.value) or 0))
            else
                batch:Set(w.key, w.value)
            end
        end
        batch:Save(label, opts)
    end
end

--- 单个 Set 写入（便捷方法）
---@param key string
---@param value any
---@param label string
---@param opts? table
function CloudWriteProxy.Set(key, value, label, opts)
    CloudWriteProxy.Write({ { key = key, value = value } }, label, opts)
end

--- 单个 SetInt 写入（便捷方法）
---@param key string
---@param value number
---@param label string
---@param opts? table
function CloudWriteProxy.SetInt(key, value, label, opts)
    CloudWriteProxy.Write({ { key = key, value = value, int = true } }, label, opts)
end

return CloudWriteProxy
