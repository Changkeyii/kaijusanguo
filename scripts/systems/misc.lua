-- ============================================================================
-- systems/misc.lua - 三国武灵录
-- ============================================================================

function FilterBannedWords(text)
    if not text or #text == 0 then return text end
    local result = text
    for _, word in ipairs(CHAT_BANNED_WORDS) do
        local stars = string.rep("*", utf8.len(word) or #word)
        result = string.gsub(result, word, stars)
    end
    return result
end


--- 获取当前周标识 (年份+第几周)
function GetWeekKey()
    return os.date("%Y") .. "_W" .. os.date("%W")
end


local function _isWebPlatform()
    local p = GetPlatform and GetPlatform() or "unknown"
    return p == "Web" or p == "web" or p == "Emscripten"
end


-- ===========================
-- 阵营子视图: 升级/捐献/公告
-- ===========================
-- 加载阵营等级排行榜
--- 从 camp_leader_ts 排行榜加载阵营排行（按等级降序）
---@param target string "factionUI" 或 "welfareState"
function LoadFactionRankFrom(target)
    if not CloudAPI.IsAvailable() then
        if target == "factionUI" then
            factionUI.rankList = {}; factionUI.rankLoaded = true; factionUI.rankLoading = false
        else
            welfareState.factionRank = {}; welfareState.factionRankLoaded = true; welfareState.factionRankLoading = false
        end
        return
    end

    -- 直接复用 CloudManager.ListFactions（已验证可正常工作）
    CloudManager.ListFactions(function(factions)
        local result = {}
        for _, f in ipairs(factions) do
            table.insert(result, {
                campId = f.campId,
                name = f.name or "未命名",
                level = f.level or 1,
                exp = f.exp or 0,
                memberCount = f.memberCount or 0,
            })
        end
        -- 按等级降序、经验降序排序
        table.sort(result, function(a, b)
            if a.level ~= b.level then return a.level > b.level end
            return a.exp > b.exp
        end)

        if target == "factionUI" then
            factionUI.rankList = result; factionUI.rankLoaded = true; factionUI.rankLoading = false
        else
            welfareState.factionRank = result; welfareState.factionRankLoaded = true; welfareState.factionRankLoading = false
        end
    end)
end

