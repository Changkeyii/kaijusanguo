-- ============================================================================
-- systems/stage_bridge.lua - 浠庡凡鍒犻櫎鐨?stage.lua / gacha.lua 涓彁鍙栫殑鍏辩敤鍑芥暟
-- 杩欎簺鍑芥暟琚垬鏂楃郴缁熴€佹帓浣嶇郴缁熴€佸叺绗︾郴缁熺瓑骞挎硾寮曠敤锛屽繀椤讳繚鐣?
-- ============================================================================

--- 搴旂敤鎴樻枟甯冨眬: 閲嶈鐭冲彴浣嶇疆 + 鍒囨崲鑳屾櫙
function ApplyBattleLayout(layoutIdx)
    layoutIdx = layoutIdx or 1
    local layout = BATTLE_LAYOUTS[layoutIdx] or BATTLE_LAYOUTS[1]
    currentLayoutIdx = layoutIdx
    for i, pos in ipairs(layout.playerSlots) do
        if PLAYER_SLOTS[i] then
            PLAYER_SLOTS[i].cx = pos[1] * BG2D_X
            PLAYER_SLOTS[i].cy = pos[2] * BG2D_Y
        end
    end
    for i, pos in ipairs(layout.enemySlots) do
        if ENEMY_SLOTS[i] then
            ENEMY_SLOTS[i].cx = pos[1] * BG2D_X
            ENEMY_SLOTS[i].cy = pos[2] * BG2D_Y
        end
    end
end


--- 瀵煎嚭甯冨眬閰嶇疆鍒版枃浠?(JSON 鏍煎紡)
function ExportBattleLayouts()
    local data = {}
    for li, layout in ipairs(BATTLE_LAYOUTS) do
        local entry = {
            name = layout.name,
            bg = layout.bg,
            playerSlots = {},
            enemySlots = {},
        }
        for _, pos in ipairs(layout.playerSlots) do
            entry.playerSlots[#entry.playerSlots + 1] = { pos[1], pos[2] }
        end
        for _, pos in ipairs(layout.enemySlots) do
            entry.enemySlots[#entry.enemySlots + 1] = { pos[1], pos[2] }
        end
        data[#data + 1] = entry
    end
    ---@diagnostic disable-next-line: undefined-global
    local cj = cjson
    local jsonStr = cj.encode(data)
    local file = File(FILE_LAYOUTS, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(jsonStr)
        file:Close()
        print("[甯冨眬缂栬緫鍣╙ 宸插鍑哄埌 battle_layouts.json")
    else
        print("[甯冨眬缂栬緫鍣╙ 瀵煎嚭澶辫触: 鏃犳硶鍐欏叆鏂囦欢")
    end
    print("[甯冨眬鏁版嵁] " .. jsonStr)
end


--- 鎾ら攢涓婁竴姝ョ煶鍙版嫋鎷?
function UndoSlotEdit()
    if #slotUndoStack == 0 then return false end
    local snap = slotUndoStack[#slotUndoStack]
    slotUndoStack[#slotUndoStack] = nil
    local entries = snap.batch or { snap }
    for _, s in ipairs(entries) do
        local layout = BATTLE_LAYOUTS[s.layoutIdx]
        if layout then
            local slots = s.slotType == "player" and layout.playerSlots or layout.enemySlots
            if slots[s.slotIdx] then
                slots[s.slotIdx][1] = s.oldX
                slots[s.slotIdx][2] = s.oldY
            end
        end
    end
    return true
end


-- ============================================================================
-- 鎺掍綅杈呭姪鍑芥暟
-- ============================================================================

function GetRankedTier(score)
    local tier = RANKED_TIERS[1]
    for i = #RANKED_TIERS, 1, -1 do
        if score >= RANKED_TIERS[i].minScore then
            tier = RANKED_TIERS[i]
            tier.index = i
            return tier
        end
    end
    tier.index = 1
    return tier
end


function CalcRankedScoreChange(isWin, currentStreak)
    if isWin then
        local s = math.max(0, currentStreak)
        return math.min(30, 20 + s * 2)
    else
        local s = math.max(0, -currentStreak)
        return -math.max(10, 15 - s)
    end
end


--- 鐢熸垚鎺掍綅AI瀵规墜
local function buildRankedCardFromHero(cardIdx, heroInfo)
    local baseCard = HERO_CARDS[cardIdx]
    if not baseCard or not heroInfo then
        return nil, 0
    end

    local tempCard = DeepCopy(baseCard)
    tempCard.cardIdx = cardIdx
    tempCard.level = heroInfo.level or 1
    tempCard.constellation = heroInfo.constellation or 0

    local stats = ApplyConstellationStats(tempCard)
    local levelMul = 1 + ((tempCard.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
    local sealBonus = GetSealTotalBonus(cardIdx)

    local finalAtk = math.floor(stats.atk * levelMul * (1 + (sealBonus.atkPct or 0) / 100))
    local finalDef = math.floor(stats.def * levelMul * (1 + (sealBonus.defPct or 0) / 100))
    local finalHp = math.floor(stats.hp * levelMul * (1 + (sealBonus.hpPct or 0) / 100))
    local power = math.floor(finalAtk * 2 + finalDef + finalHp * 0.1)

    return {
        cardIdx = cardIdx,
        name = baseCard.name,
        quality = baseCard.quality,
        faction = baseCard.faction,
        atk = finalAtk,
        def = finalDef,
        hp = finalHp,
        level = 1,
        constellation = 0,
    }, power
end

function BuildRankedPlayerSnapshot()
    local chosen = {}
    local chosenSet = {}
    local formation = (rawget(_G, 'gameSettings') and gameSettings.formation) or {}
    local totalPower = 0

    local function pushCard(cardIdx)
        if chosenSet[cardIdx] then
            return
        end
        local heroInfo = playerHeroes and playerHeroes[cardIdx]
        if not heroInfo or not heroInfo.owned then
            return
        end
        local card, power = buildRankedCardFromHero(cardIdx, heroInfo)
        if not card then
            return
        end
        chosen[#chosen + 1] = { card = card, power = power }
        chosenSet[cardIdx] = true
    end

    for _, cardIdx in ipairs(formation) do
        pushCard(cardIdx)
        if #chosen >= 5 then
            break
        end
    end

    if #chosen < 5 then
        local candidates = {}
        for cardIdx, heroInfo in pairs(playerHeroes or {}) do
            if heroInfo.owned and not chosenSet[cardIdx] then
                local _, power = buildRankedCardFromHero(cardIdx, heroInfo)
                candidates[#candidates + 1] = { cardIdx = cardIdx, power = power }
            end
        end
        table.sort(candidates, function(a, b) return a.power > b.power end)
        for _, candidate in ipairs(candidates) do
            pushCard(candidate.cardIdx)
            if #chosen >= 5 then
                break
            end
        end
    end

    local cards = {}
    table.sort(chosen, function(a, b) return a.power > b.power end)
    for _, entry in ipairs(chosen) do
        cards[#cards + 1] = entry.card
        totalPower = totalPower + entry.power
    end

    return {
        name = (playerInfo and playerInfo.name) or 'Player',
        totalPower = totalPower,
        cards = cards,
    }
end


-- ============================================================================
-- 婊″懡姝︾伒妫€娴?(鍏电绯荤粺渚濊禆)
-- ============================================================================

--- 妫€鏌ユ槸鍚︽湁鑷冲皯1涓弧鍛芥鐏?
function HasMaxConstellationHero()
    for idx, hero in pairs(playerHeroes) do
        if hero and (hero.constellation or 0) >= GameConfig.MAX_CONSTELLATION then
            return true
        end
    end
    return false
end


--- 鑾峰彇鎵€鏈夋弧鍛芥鐏靛垪琛?
function GetMaxConstellationHeroes()
    local list = {}
    if not HERO_CARDS then return list end
    for idx, hero in pairs(playerHeroes) do
        if hero and (hero.constellation or 0) >= GameConfig.MAX_CONSTELLATION then
            local card = HERO_CARDS[idx]
            if card then
                table.insert(list, { cardIdx = idx, name = card.name, quality = card.quality })
            end
        end
    end
    table.sort(list, function(a, b) return a.cardIdx < b.cardIdx end)
    return list
end


-- ============================================================================
-- 姝︽妧娈嬬墖鎺夎惤鏉冮噸锛堝師鍦ㄨ繍琛屾椂鍒濆鍖栵紝姝ゅ鎻愪緵榛樿鍊硷級
-- ============================================================================
if not rawget(_G, "SKILL_FRAG_WEIGHTS") then
    SKILL_FRAG_WEIGHTS = {
        [1] = 100,  -- 鍑″搧
        [2] = 60,   -- 鑹搧
        [3] = 35,   -- 浼樺搧
        [4] = 18,   -- 灏嗗搧
        [5] = 8,    -- 渚搧
        [6] = 3,    -- 鐜嬪搧
        [7] = 1,    -- 甯濆搧
    }
end

-- ============================================================================
-- 鎴樻枟姝︽妧娈嬬墖鎺夎惤
-- ============================================================================

--- 鎴樻枟鑳滃埄鎺夎惤姝︽妧娈嬬墖
--- @param maxTier number 鍏冲崱鏈€楂樻帀钀介樁绾?1-6)
--- @return table[] fragDrops 鎺夎惤鍒楄〃
function GenerateBattleSkillFragDrop(maxTier)
    local fragDrops = {}
    local dropCount = 1
    local roll = math.random(1, 100)
    if maxTier >= 4 then
        dropCount = roll <= 40 and 3 or (roll <= 75 and 2 or 1)
    elseif maxTier >= 2 then
        dropCount = roll <= 30 and 2 or 1
    end
    for _ = 1, dropCount do
        local pool = {}
        local totalW = 0
        for idx, tech in ipairs(SKILL_TECHNIQUES) do
            local baseW = SKILL_FRAG_WEIGHTS[tech.tier] or 10
            if tech.tier <= maxTier then
                baseW = baseW + math.floor(maxTier * 0.5)
            end
            totalW = totalW + baseW
            table.insert(pool, { idx = idx, weight = baseW, cumWeight = totalW })
        end
        local r = math.random() * totalW
        local chosen = pool[1].idx
        for _, p in ipairs(pool) do
            if r <= p.cumWeight then chosen = p.idx; break end
        end
        skillFragments[chosen] = (skillFragments[chosen] or 0) + 1
        local tech = SKILL_TECHNIQUES[chosen]
        local tier = SKILL_TIERS[tech.tier]
        table.insert(fragDrops, {
            skillIdx = chosen,
            skillName = tech.name,
            tierName = tier.name,
            tierColor = tier.color,
        })
    end
    return fragDrops
end

