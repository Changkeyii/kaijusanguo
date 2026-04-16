-- ============================================================================
-- DataManager.lua - 排位房间服务端数据管理器
-- 仅管理排位 Elo 数据（征途为纯单机，不经服务端）
-- ============================================================================

local Protocol = require("network.Protocol")
local CK = Protocol.CLOUD_KEYS

local DataManager = {}

-- 玩家数据缓存: playerData_[userId] = { loaded, elo, wins, losses }
local playerData_ = {}

-- ============================================================================
-- 初始化/获取玩家数据
-- ============================================================================

--- 获取玩家缓存数据（可能未加载完成）
function DataManager.GetPlayerData(userId)
    return playerData_[userId]
end

--- 确保玩家数据结构存在
function DataManager.EnsurePlayer(userId)
    if not playerData_[userId] then
        playerData_[userId] = {
            loaded = false,
            elo = 1000,
            wins = 0,
            losses = 0,
        }
    end
    return playerData_[userId]
end

--- 从 serverCloud 加载玩家排位数据
function DataManager.LoadPlayer(userId, callback)
    local pd = DataManager.EnsurePlayer(userId)

    if not serverCloud then
        print("[DataManager] WARNING: serverCloud not available, using defaults")
        pd.loaded = true
        if callback then callback(true, pd) end
        return
    end

    -- 加载排位数据
    serverCloud:BatchGet(userId)
        :Key(CK.RANKED_ELO)
        :Key(CK.RANKED_WINS)
        :Key(CK.RANKED_LOSSES)
        :Fetch({
            ok = function(scores, iscores, sscores)
                if iscores then
                    pd.elo = iscores[CK.RANKED_ELO] or 1000
                    pd.wins = iscores[CK.RANKED_WINS] or 0
                    pd.losses = iscores[CK.RANKED_LOSSES] or 0
                end
                pd.loaded = true
                print("[DataManager] Player " .. tostring(userId) .. " loaded: elo=" .. pd.elo)
                if callback then callback(true, pd) end
            end,
            error = function(code, reason)
                print("[DataManager] Load error: " .. tostring(code) .. " " .. tostring(reason))
                pd.loaded = true  -- 使用默认值继续
                if callback then callback(true, pd) end
            end,
        })
end

-- ============================================================================
-- 排位 Elo 操作
-- ============================================================================

--- 更新 Elo 分数
function DataManager.UpdateElo(userId, newElo, isWin, callback)
    local pd = DataManager.EnsurePlayer(userId)
    pd.elo = newElo

    if not serverCloud then
        if isWin then pd.wins = pd.wins + 1 else pd.losses = pd.losses + 1 end
        if callback then callback(true) end
        return
    end

    local c = serverCloud:BatchCommit("elo_update")
    c:ScoreSetInt(userId, CK.RANKED_ELO, newElo)
    if isWin then
        c:ScoreAddInt(userId, CK.RANKED_WINS, 1)
    else
        c:ScoreAddInt(userId, CK.RANKED_LOSSES, 1)
    end
    c:Commit({
        ok = function()
            if isWin then pd.wins = pd.wins + 1 else pd.losses = pd.losses + 1 end
            if callback then callback(true) end
        end,
        error = function(code, reason)
            if callback then callback(false, reason) end
        end,
    })
end

-- ============================================================================
-- 清理
-- ============================================================================

--- 玩家断开时清理缓存
function DataManager.RemovePlayer(userId)
    playerData_[userId] = nil
end

return DataManager
