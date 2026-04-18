-- ============================================================================
-- systems/misc.lua - 涓夊浗姝︾伒褰?"
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


--- 鑾峰彇褰撳墠鍛ㄦ爣璇?(骞翠唤+绗嚑鍛?"
function GetWeekKey()
    return os.date("%Y") .. "_W" .. os.date("%W")
end


local function _isWebPlatform()
    local p = GetPlatform and GetPlatform() or "unknown"
    return p == "Web" or p == "web" or p == "Emscripten"
end


-- ===========================
-- 闃佃惀瀛愯鍥? 鍗囩骇/鎹愮尞/鍏憡
-- ===========================
-- 鍔犺浇闃佃惀绛夌骇鎺掕姒?"
--- 浠?camp_leader_ts 鎺掕姒滃姞杞介樀钀ユ帓琛岋紙鎸夌瓑绾ч檷搴忥級
---@param target string "factionUI" 鎴?"welfareState"
function LoadFactionRankFrom(target)
    if not CloudAPI.IsAvailable() then
        if target == "factionUI" then
            factionUI.rankList = {}; factionUI.rankLoaded = true; factionUI.rankLoading = false
        else
            welfareState.factionRank = {}; welfareState.factionRankLoaded = true; welfareState.factionRankLoading = false
        end
        return
    end

    -- 鐩存帴澶嶇敤 CloudManager.ListFactions锛堝凡楠岃瘉鍙甯稿伐浣滐級
    CloudManager.ListFactions(function(factions)
        local result = {}
        for _, f in ipairs(factions) do
            table.insert(result, {
                campId = f.campId,
                name = f.name or "鏈懡鍚?",
                level = f.level or 1,
                exp = f.exp or 0,
                memberCount = f.memberCount or 0,
            })
        end
        -- 鎸夌瓑绾ч檷搴忋€佺粡楠岄檷搴忔帓搴?"
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

