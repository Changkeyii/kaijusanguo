-- ============================================================================
-- Shared.lua - 乱世征途 网络共享层
-- 注册所有 RemoteEvent，供 Server 和 Client 共同使用
-- ============================================================================

local Shared = {}
local Protocol = require("network.Protocol")

Shared.Protocol = Protocol
Shared.EVENTS = Protocol.EVENTS

-- ============================================================================
-- 注册所有远程事件（Server 和 Client 启动时各调用一次）
-- ============================================================================
function Shared.RegisterEvents()
    for _, eventName in pairs(Protocol.EVENTS) do
        network:RegisterRemoteEvent(eventName)
    end
    print("[Shared] Registered " .. Shared.CountEvents() .. " remote events")
end

function Shared.CountEvents()
    local n = 0
    for _ in pairs(Protocol.EVENTS) do n = n + 1 end
    return n
end

return Shared
