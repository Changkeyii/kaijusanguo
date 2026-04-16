-- ============================================================================
-- systems/stage_bridge.lua - 从已删除的 stage.lua / gacha.lua 中提取的共用函数
-- 这些函数被战斗系统、排位系统、兵符系统等广泛引用，必须保留
-- ============================================================================

--- 应用战斗布局: 重设石台位置 + 切换背景
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
function GenerateRankedOpponent()
    local playerPower = CalcPlayerTotalPower()
    local nonHeroPower = CalcRankPowerScore() + CalcEquipPowerScore() + CalcSkillPowerScore()
    local playerHeroPower = math.max(1, playerPower - nonHeroPower)
    local targetMin = playerHeroPower * 0.95
    local targetMax = playerHeroPower * 1.05

    local cardCount = math.random(3, 5)
    local usedIdx = {}
    local picked = {}
    for i = 1, cardCount do
        local idx
        repeat idx = math.random(1, #HERO_CARDS) until not usedIdx[idx]
        usedIdx[idx] = true
        local card = DeepCopy(HERO_CARDS[idx])
        card.cardIdx = idx
        card.level = 1
        card.constellation = 0
        table.insert(picked, card)
    end

    local function calcLinePower(cards)
        local total = 0
        for _, c in ipairs(cards) do
            local lm = 1 + ((c.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
            local cStats = ApplyConstellationStats(c)
            total = total + (cStats.atk * 2 + cStats.def + cStats.hp * 0.1) * lm
        end
        return math.floor(total)
    end

    for _ = 1, 200 do
        local cur = calcLinePower(picked)
        if cur >= targetMin and cur <= targetMax then break end
        if cur >= targetMax then break end
        local ci = math.random(1, #picked)
        local c = picked[ci]
        if c.level < 10 and (c.constellation >= GameConfig.MAX_CONSTELLATION or math.random() < 0.7) then
            c.level = c.level + 1
        elseif c.constellation < GameConfig.MAX_CONSTELLATION then
            c.constellation = c.constellation + 1
        elseif c.level < 10 then
            c.level = c.level + 1
        end
    end

    for _ = 1, 50 do
        local cur = calcLinePower(picked)
        if cur <= targetMax then break end
        local ci = math.random(1, #picked)
        local c = picked[ci]
        if c.level > 1 then
            c.level = c.level - 1
        elseif c.constellation > 0 then c.constellation = c.constellation - 1 end
    end

    for _, c in ipairs(picked) do
        local lm = 1 + ((c.level or 1) - 1) * GameConfig.LEVEL_GROWTH_RATE
        local cStats = ApplyConstellationStats(c)
        c.atk = math.floor(cStats.atk * lm)
        c.def = math.floor(cStats.def * lm)
        c.hp  = math.floor(cStats.hp  * lm)
        c.level = 1
        c.constellation = 0
    end

    local surnames = {"烽火","铁骑","虎牢","武灵","破军","赤壁","青龙","白虎","玄武","朱雀","龙吟","凤鸣","天策","麒麟"}
    local titles   = {"猎手","先锋","守将","行者","游侠","壮士","校尉","军师","术士","勇士","义士","斥候","大将","护卫"}
    local opName = surnames[math.random(1,#surnames)] .. titles[math.random(1,#titles)]

    return {
        cards = picked,
        totalPower = calcLinePower(picked),
        name = opName,
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
        [3] = 35,   -- 优品
        [4] = 18,   -- 将品
        [5] = 8,    -- 侯品
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
