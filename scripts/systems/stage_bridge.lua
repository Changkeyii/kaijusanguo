-- ============================================================================
-- systems/stage_bridge.lua - 从已删除的 stage.lua / gacha.lua 中提取的共用函数
-- 这些函数被战斗系统、排位系统、兵符系统等广泛引用，必须保留
-- ============================================================================

--- 应用战斗布局: 记录当前布局索引 (石台位置由 G_systems.lua 中全局 PLAYER_SLOTS/ENEMY_SLOTS 固定)
function ApplyBattleLayout(layoutIdx)
    layoutIdx = layoutIdx or 1
    currentLayoutIdx = layoutIdx
    -- 注意: 旧版本会用 BG 像素坐标覆盖 slot cx/cy，已移除。
    -- 英雄槽位坐标由 G_systems.lua 的 MakeHeroSlot() 统一定义，横屏固定布局。
end


--- 导出布局配置到文件 (JSON 格式)
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
        print("[布局编辑器] 已导出到 battle_layouts.json")
    else
        print("[布局编辑器] 导出失败: 无法写入文件")
    end
    print("[布局数据] " .. jsonStr)
end


--- 撤销上一步石台拖拽
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
-- 排位辅助函数
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


--- 生成排位AI对手
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
-- 满命武灵检测 (兵符系统依赖)
-- ============================================================================

--- 检查是否有至少1个满命武灵
function HasMaxConstellationHero()
    for idx, hero in pairs(playerHeroes) do
        if hero and (hero.constellation or 0) >= GameConfig.MAX_CONSTELLATION then
            return true
        end
    end
    return false
end


--- 获取所有满命武灵列表
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
-- 武技残片掉落权重（原在运行时初始化，此处提供默认值）
-- ============================================================================
if not rawget(_G, "SKILL_FRAG_WEIGHTS") then
    SKILL_FRAG_WEIGHTS = {
        [1] = 100,  -- 凡品
        [2] = 60,   -- 良品
        [3] = 35,   -- 浼樺搧
        [4] = 18,   -- 灏嗗搧
        [5] = 8,    -- 侍品
        [6] = 3,    -- 王品
        [7] = 1,    -- 帝品
    }
end

-- ============================================================================
-- 战斗武技残片掉落
-- ============================================================================

--- 战斗胜利掉落武技残片
--- @param maxTier number 关卡最高掉落阶级(1-6)
--- @return table[] fragDrops 掉落列表
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

