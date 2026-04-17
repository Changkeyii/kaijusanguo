-- ============================================================================
-- CloudWriteProxy.lua - 客户端云端共享数据写入代理
-- 统一封装云端共享数据写入，通过服务端 RPC (cloud_write action) 路由
-- serverCloud 写入后客户端 GetRankList 仍可正常读取
-- ============================================================================

local CloudWriteProxy = {}

--- 检查是否有可用的写入通道（服务端权威模式）
---@return boolean
function CloudWriteProxy.IsAvailable()
    return rawget(_G, "cl_state") ~= nil
end

--- 批量写入共享数据（通过服务端 RPC）
---@param writes table[] 写入项数组 { {key=string, value=any, int=boolean?}, ... }
---@param label string 操作描述（日志/追踪用）
---@param opts? table 回调 { ok=function(), error=function(code_or_reason, reason?) }
function CloudWriteProxy.Write(writes, label, opts)
    opts = opts or {}

    if not rawget(_G, "cl_state") then
        if opts.error then opts.error(0, "服务端未连接") end
        return
    end

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
