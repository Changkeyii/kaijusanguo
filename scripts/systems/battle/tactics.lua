-- ============================================================================
-- systems/battle/tactics.lua - 战旗回合制核心模块 (v2: 多占网格+精灵群)
-- ============================================================================
-- 职责: 网格管理、兵团创建、回合状态机、BFS移动、伤害计算、AI、播报
-- 依赖: G_systems.lua (TACTIC_COLS/ROWS, BATTLE_ZONE, TROOP_TACTICS, tacticState)
--       G_data_battle.lua (TROOP_TYPES, TROOP_COUNTER, GetTroopCounterMult)
-- ============================================================================
---@diagnostic disable: undefined-global

local Tactics = {}

-- ============================================================================
-- 坐标转换: 网格 ↔ 屏幕 (设计坐标)
-- ============================================================================

--- 网格(row,col) → 屏幕中心点 (设计坐标)
---@param row number 行 (1-based)
---@param col number 列 (1-based)
---@return number x, number y
function Tactics.GridToScreen(row, col)
    local x = BATTLE_ZONE.left + (col - 0.5) * TACTIC_CELL_W
    local y = BATTLE_ZONE.top  + (row - 0.5) * TACTIC_CELL_H
    return x, y
end

--- 屏幕(设计坐标) → 网格(row,col), 超出范围返回 nil
---@param dx number 设计坐标X
---@param dy number 设计坐标Y
---@return number|nil row, number|nil col
function Tactics.ScreenToGrid(dx, dy)
    if dx < BATTLE_ZONE.left or dx > BATTLE_ZONE.right then return nil, nil end
    if dy < BATTLE_ZONE.top  or dy > BATTLE_ZONE.bottom then return nil, nil end
    local col = math.floor((dx - BATTLE_ZONE.left) / TACTIC_CELL_W) + 1
    local row = math.floor((dy - BATTLE_ZONE.top)  / TACTIC_CELL_H) + 1
    col = math.max(1, math.min(TACTIC_COLS, col))
    row = math.max(1, math.min(TACTIC_ROWS, row))
    return row, col
end

-- ============================================================================
-- 网格占据查询 (v2: 多占模型, grid[row][col] = {id1, id2, ...})
-- id > 0: 玩家兵团索引, id < 0: 敌方兵团索引
-- ============================================================================

--- 向格子添加兵团
function Tactics.AddToGrid(row, col, groupId)
    if not tacticState then return end
    if not tacticState.grid[row] then tacticState.grid[row] = {} end
    if not tacticState.grid[row][col] then tacticState.grid[row][col] = {} end
    local cell = tacticState.grid[row][col]
    -- 避免重复添加
    for _, id in ipairs(cell) do
        if id == groupId then return end
    end
    cell[#cell + 1] = groupId
end

--- 从格子移除指定兵团
function Tactics.RemoveFromGrid(row, col, groupId)
    if not tacticState then return end
    local cell = tacticState.grid[row] and tacticState.grid[row][col]
    if not cell then return end
    for i = #cell, 1, -1 do
        if cell[i] == groupId then
            table.remove(cell, i)
            break
        end
    end
end

--- 获取格子上的所有兵团列表
---@return table groups 兵团对象列表
function Tactics.GetGroupsAt(row, col)
    local result = {}
    if not tacticState then return result end
    local cell = tacticState.grid[row] and tacticState.grid[row][col]
    if not cell then return result end
    for _, id in ipairs(cell) do
        local g
        if id > 0 then
            g = tacticState.playerGroups[id]
        else
            g = tacticState.enemyGroups[-id]
        end
        if g and g.alive then
            result[#result + 1] = g
        end
    end
    return result
end

--- 获取格子上指定阵营的兵团
function Tactics.GetFriendlyAt(row, col, isPlayer)
    local groups = Tactics.GetGroupsAt(row, col)
    for _, g in ipairs(groups) do
        if g.isPlayer == isPlayer then return g end
    end
    return nil
end

--- 获取格子上敌方兵团
function Tactics.GetEnemyAt(row, col, isPlayer)
    local groups = Tactics.GetGroupsAt(row, col)
    local enemies = {}
    for _, g in ipairs(groups) do
        if g.isPlayer ~= isPlayer then
            enemies[#enemies + 1] = g
        end
    end
    return enemies
end

--- 检查格子是否可通行(BFS用): 没有敌方阻挡 或 格子为目的地
function Tactics.IsCellPassable(row, col, isPlayer)
    if row < 1 or row > TACTIC_ROWS or col < 1 or col > TACTIC_COLS then return false end
    local cell = tacticState.grid[row] and tacticState.grid[row][col]
    if not cell or #cell == 0 then return true end
    -- 有友方可通过，有敌方可进入(但不穿越)
    for _, id in ipairs(cell) do
        local g
        if id > 0 then g = tacticState.playerGroups[id]
        else g = tacticState.enemyGroups[-id] end
        if g and g.alive and g.isPlayer == isPlayer then
            -- 友方占据 - 可通过
        elseif g and g.alive and g.isPlayer ~= isPlayer then
            -- 敌方占据 - 可进入但标记为终点
            return true, true  -- passable=true, hasEnemy=true
        end
    end
    return true, false
end

--- 检查格子是否完全空
function Tactics.IsCellEmpty(row, col)
    if row < 1 or row > TACTIC_ROWS or col < 1 or col > TACTIC_COLS then return false end
    local cell = tacticState.grid[row] and tacticState.grid[row][col]
    return not cell or #cell == 0
end

-- ============================================================================
-- BFS 移动范围计算 (v2: 支持进入敌方格但不穿越)
-- ============================================================================

--- 计算兵团可移动的所有格子
---@param startRow number
---@param startCol number
---@param moveRange number
---@param isPlayer boolean
---@return table targets {row,col} 列表 (不含起点)
function Tactics.CalcMoveRange(startRow, startCol, moveRange, isPlayer, troopType)
    local targets = {}
    local visited = {}
    local key = function(r, c) return r * 100 + c end
    local queue = { { row = startRow, col = startCol, dist = 0 } }
    visited[key(startRow, startCol)] = true

    -- 枪兵8方向(含对角线), 其他兵种4方向
    local dirs
    if troopType == "spear" then
        dirs = { {-1,0},{1,0},{0,-1},{0,1},{-1,-1},{-1,1},{1,-1},{1,1} }
    else
        dirs = { {-1,0},{1,0},{0,-1},{0,1} }
    end
    local head = 1
    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        if cur.dist > 0 then
            targets[#targets + 1] = { row = cur.row, col = cur.col }
        end
        if cur.dist < moveRange then
            for _, d in ipairs(dirs) do
                local nr, nc = cur.row + d[1], cur.col + d[2]
                if nr >= 1 and nr <= TACTIC_ROWS and nc >= 1 and nc <= TACTIC_COLS then
                    if not visited[key(nr, nc)] then
                        local passable, hasEnemy = Tactics.IsCellPassable(nr, nc, isPlayer)
                        if passable then
                            visited[key(nr, nc)] = true
                            queue[#queue + 1] = { row = nr, col = nc, dist = cur.dist + 1 }
                            -- 如果有敌方,可进入但不可再继续移动(设dist=moveRange)
                            if hasEnemy then
                                queue[#queue].dist = moveRange
                            end
                        end
                    end
                end
            end
        end
    end
    return targets
end

--- 计算兵团可攻击的目标
---@param centerRow number
---@param centerCol number
---@param atkRange number 0=本格, 1=相邻格
---@param isPlayer boolean 攻击方是否玩家
---@return table targets {row,col,group} 列表
function Tactics.CalcAttackRange(centerRow, centerCol, atkRange, isPlayer)
    local targets = {}
    if atkRange == 0 then
        -- 近战: 只查本格的敌方
        local enemies = Tactics.GetEnemyAt(centerRow, centerCol, isPlayer)
        for _, g in ipairs(enemies) do
            if g.hp > 0 then
                targets[#targets + 1] = { row = centerRow, col = centerCol, group = g }
            end
        end
    else
        -- 远程(弓兵): 查相邻格(曼哈顿距离 <= atkRange)的敌方
        for dr = -atkRange, atkRange do
            for dc = -atkRange, atkRange do
                local dist = math.abs(dr) + math.abs(dc)
                if dist >= 1 and dist <= atkRange then
                    local nr, nc = centerRow + dr, centerCol + dc
                    if nr >= 1 and nr <= TACTIC_ROWS and nc >= 1 and nc <= TACTIC_COLS then
                        local enemies = Tactics.GetEnemyAt(nr, nc, isPlayer)
                        for _, g in ipairs(enemies) do
                            if g.hp > 0 then
                                targets[#targets + 1] = { row = nr, col = nc, group = g }
                            end
                        end
                    end
                end
            end
        end
    end
    return targets
end

-- ============================================================================
-- 伤害计算
-- ============================================================================

--- 计算战旗伤害
function Tactics.CalcDamage(attacker, defender)
    local counterMult = GetTroopCounterMult(attacker.troopType, defender.troopType)
    local atk = attacker.atk * attacker.unitCount
    local def = defender.def
    local rawDmg = atk * counterMult * (1 - def / (def + 100))
    rawDmg = rawDmg * (0.9 + math.random() * 0.2)
    return math.max(1, math.floor(rawDmg))
end

-- ============================================================================
-- 播报系统
-- ============================================================================

--- 添加战场播报
function Tactics.AddBattleLog(text, color)
    if not tacticState then return end
    local log = tacticState.battleLog
    log[#log + 1] = {
        text = text,
        color = color or { 220, 200, 160 },
        timer = 5.0,  -- 5秒后淡出
    }
    -- 最多保留 20 条
    while #log > 20 do
        table.remove(log, 1)
    end
end

-- ============================================================================
-- 兵团创建
-- ============================================================================

--- 从武将槽位创建战旗兵团
function Tactics.CreateGroup(slot, isPlayer, groupIdx, row, col)
    local card = slot.card
    local troopType = card.baseTroop or "infantry"
    local tt = TROOP_TACTICS[troopType] or TROOP_TACTICS.infantry
    local tc = TROOP_TYPES[troopType] or TROOP_TYPES.infantry

    local lvlMult = 1 + (card.level or 1) * 0.08
    local baseAtk = math.floor(tt.baseAtk * lvlMult + (card.atk or 0) * 0.5)
    local baseDef = math.floor(tt.baseDef * lvlMult + (card.def or 0) * 0.3)
    local baseHP  = math.floor(tt.baseHP  * lvlMult + (card.hp  or 0) * 0.5)

    -- 兵力: 千人级真实兵力
    local level = card.level or 1
    local quality = card.quality or 1
    local unitCount = 500 + quality * 300 + level * 80

    -- 根据兵种选择精灵图名
    local spriteMap = {
        infantry = "sword",
        archer   = "archer",
        cavalry  = "cavalry",
        spear    = "lancer",
    }

    local group = {
        idx       = groupIdx,
        isPlayer  = isPlayer,
        troopType = troopType,
        troopName = tc.name,
        troopColor = tc.color,
        icon      = tt.icon,
        spriteName = spriteMap[troopType] or "sword",
        row       = row,
        col       = col,
        atk       = baseAtk,
        def       = baseDef,
        hp        = baseHP,
        maxHP     = baseHP,
        unitCount = unitCount,
        maxUnits  = unitCount,
        moveRange = tt.moveRange,
        atkRange  = tt.atkRange,
        acted     = false,
        heroName  = card.name or ("武将" .. groupIdx),
        heroIcon  = card.icon,
        slot      = slot,
        -- 动画
        screenX   = 0,
        screenY   = 0,
        animOfsX  = 0,
        animOfsY  = 0,
        flashTimer = 0,
        alive     = true,
    }

    group.screenX, group.screenY = Tactics.GridToScreen(row, col)
    return group
end

-- ============================================================================
-- 初始化
-- ============================================================================

function Tactics.Init()
    tacticState = {
        turnPhase    = "PLAYER_SELECT",
        turnNumber   = 1,
        isPlayerTurn = true,
        selectedGroup = nil,
        moveTargets   = {},
        attackTargets = {},
        animTimer     = 0,
        animType      = nil,
        animData      = nil,
        grid          = {},
        playerGroups  = {},
        enemyGroups   = {},
        bannerTimer   = 2.0,
        bannerText    = "第1回合 - 我方行动",
        pendingDamageTexts = {},
        battleLog     = {},       -- 播报记录
        projectiles   = {},       -- 弹道特效
    }

    -- 初始化空网格
    for r = 1, TACTIC_ROWS do
        tacticState.grid[r] = {}
        for c = 1, TACTIC_COLS do
            tacticState.grid[r][c] = {}
        end
    end

    -- === 玩家兵团: 放在左侧 1-3 列 ===
    local pIdx = 0
    for _, slot in ipairs(PLAYER_SLOTS) do
        if slot.filled and slot.card then
            pIdx = pIdx + 1
            local row = ((pIdx - 1) % TACTIC_ROWS) + 1
            local col = math.min(3, math.ceil(pIdx / TACTIC_ROWS))
            local group = Tactics.CreateGroup(slot, true, pIdx, row, col)
            tacticState.playerGroups[pIdx] = group
            Tactics.AddToGrid(row, col, pIdx)
        end
    end

    -- === 敌方兵团: 放在右侧 10-12 列 ===
    local eIdx = 0
    for _, slot in ipairs(ENEMY_SLOTS) do
        if slot.filled and slot.card then
            eIdx = eIdx + 1
            local row = ((eIdx - 1) % TACTIC_ROWS) + 1
            local col = TACTIC_COLS - math.min(2, math.ceil(eIdx / TACTIC_ROWS)) + 1
            local group = Tactics.CreateGroup(slot, false, eIdx, row, col)
            tacticState.enemyGroups[eIdx] = group
            Tactics.AddToGrid(row, col, -eIdx)
        end
    end

    Tactics.AddBattleLog("战斗开始！", { 255, 220, 80 })
    print(string.format("=== 战旗初始化 | 玩家兵团:%d 敌方兵团:%d | 网格:%dx%d ===",
        pIdx, eIdx, TACTIC_COLS, TACTIC_ROWS))
end

-- ============================================================================
-- 回合状态机更新
-- ============================================================================

function Tactics.Update(dt)
    if not tacticState then return end
    local ts = tacticState

    -- 横幅倒计时
    if ts.bannerTimer > 0 then
        ts.bannerTimer = ts.bannerTimer - dt
        return
    end

    -- 延迟伤害飘字
    for i = #ts.pendingDamageTexts, 1, -1 do
        local p = ts.pendingDamageTexts[i]
        p.delay = p.delay - dt
        if p.delay <= 0 then
            AddFloatText(p.x, p.y, p.text, p.dur, p.color, p.size)
            table.remove(ts.pendingDamageTexts, i)
        end
    end

    -- 播报计时衰减
    for i = #ts.battleLog, 1, -1 do
        ts.battleLog[i].timer = ts.battleLog[i].timer - dt
        if ts.battleLog[i].timer <= -1.0 then
            table.remove(ts.battleLog, i)
        end
    end

    -- 弹道特效更新
    for i = #ts.projectiles, 1, -1 do
        local p = ts.projectiles[i]
        p.timer = p.timer - dt
        if p.timer <= 0 then
            table.remove(ts.projectiles, i)
        end
    end

    local phase = ts.turnPhase

    if phase == "PLAYER_SELECT" then
        if Tactics.AllGroupsActed(true) then
            Tactics.EndPlayerTurn()
        end

    elseif phase == "PLAYER_MOVE" or phase == "PLAYER_ATTACK" then
        -- 等待玩家选择目标

    elseif phase == "PLAYER_ANIM" then
        Tactics.UpdateAnim(dt)

    elseif phase == "ENEMY_THINK" then
        Tactics.DoEnemyTurn(dt)

    elseif phase == "ENEMY_ANIM" then
        Tactics.UpdateAnim(dt)

    elseif phase == "TURN_ADVANCE" then
        ts.turnNumber = ts.turnNumber + 1
        for _, g in ipairs(ts.playerGroups) do
            if g.alive then g.acted = false end
        end
        ts.isPlayerTurn = true
        ts.turnPhase = "PLAYER_SELECT"
        ts.selectedGroup = nil
        ts.moveTargets = {}
        ts.attackTargets = {}
        ts.bannerTimer = 1.5
        ts.bannerText = "第" .. ts.turnNumber .. "回合 - 我方行动"
        Tactics.AddBattleLog("== 第" .. ts.turnNumber .. "回合 ==", { 255, 220, 80 })

    elseif phase == "BATTLE_END" then
        -- 已交给 OnBattleVictory / OnBattleEnd
    end

    -- 更新兵团屏幕位置 (含动画插值)
    for _, g in ipairs(ts.playerGroups) do
        if g.alive then
            local tx, ty = Tactics.GridToScreen(g.row, g.col)
            g.screenX = tx + g.animOfsX
            g.screenY = ty + g.animOfsY
        end
    end
    for _, g in ipairs(ts.enemyGroups) do
        if g.alive then
            local tx, ty = Tactics.GridToScreen(g.row, g.col)
            g.screenX = tx + g.animOfsX
            g.screenY = ty + g.animOfsY
        end
    end

    -- 受击闪烁衰减
    for _, g in ipairs(ts.playerGroups) do
        if g.flashTimer > 0 then g.flashTimer = g.flashTimer - dt end
    end
    for _, g in ipairs(ts.enemyGroups) do
        if g.flashTimer > 0 then g.flashTimer = g.flashTimer - dt end
    end

    Tactics.CheckBattleEnd()
end

-- ============================================================================
-- 动画更新 (移动/攻击/弹道)
-- ============================================================================

function Tactics.UpdateAnim(dt)
    local ts = tacticState
    ts.animTimer = ts.animTimer - dt

    if ts.animType == "move" and ts.animData then
        local ad = ts.animData
        local g = ad.group
        local progress = 1 - math.max(0, ts.animTimer / ad.totalTime)
        local sx, sy = Tactics.GridToScreen(ad.fromRow, ad.fromCol)
        local ex, ey = Tactics.GridToScreen(ad.toRow, ad.toCol)
        g.screenX = sx + (ex - sx) * progress
        g.screenY = sy + (ey - sy) * progress

        if ts.animTimer <= 0 then
            g.screenX, g.screenY = ex, ey
            g.animOfsX, g.animOfsY = 0, 0
            ts.animType = nil
            ts.animData = nil
            if g.isPlayer then
                -- 移动后检查是否可攻击
                local atkTargets = Tactics.CalcAttackRange(g.row, g.col, g.atkRange, true)
                if #atkTargets > 0 then
                    ts.attackTargets = atkTargets
                    ts.turnPhase = "PLAYER_ATTACK"
                else
                    g.acted = true
                    ts.selectedGroup = nil
                    ts.moveTargets = {}
                    ts.attackTargets = {}
                    ts.turnPhase = "PLAYER_SELECT"
                end
            else
                ts.turnPhase = "ENEMY_THINK"
            end
        end

    elseif ts.animType == "attack" and ts.animData then
        local ad = ts.animData
        local attacker = ad.attacker
        local defender = ad.defender
        local progress = 1 - math.max(0, ts.animTimer / ad.totalTime)

        if attacker.atkRange == 0 then
            -- 近战动画: 冲刺+回弹
            local defX, defY = Tactics.GridToScreen(defender.row, defender.col)
            local atkX, atkY = Tactics.GridToScreen(attacker.row, attacker.col)
            local dx = (defX - atkX) * 0.3
            local dy = (defY - atkY) * 0.3
            if progress < 0.4 then
                local p = progress / 0.4
                attacker.animOfsX = dx * p
                attacker.animOfsY = dy * p
            else
                local p = (progress - 0.4) / 0.6
                attacker.animOfsX = dx * (1 - p)
                attacker.animOfsY = dy * (1 - p)
            end
        else
            -- 弓兵远程: 不移动身体, 播放弹道
            attacker.animOfsX = 0
            attacker.animOfsY = 0
        end

        -- 中间帧应用伤害
        if not ad.damageApplied and progress >= 0.4 then
            ad.damageApplied = true
            local dmg = Tactics.CalcDamage(attacker, defender)
            defender.hp = defender.hp - dmg
            defender.flashTimer = 0.5

            local tx, ty = Tactics.GridToScreen(defender.row, defender.col)
            AddFloatText(tx, ty - 20, "-" .. dmg, 1.2, { 255, 80, 60 }, 20)

            -- 播报
            local atkName = attacker.heroName .. "(" .. attacker.troopName .. ")"
            local defName = defender.heroName .. "(" .. defender.troopName .. ")"
            Tactics.AddBattleLog(atkName .. " 攻击 " .. defName .. " 造成 " .. dmg .. " 伤害",
                attacker.isPlayer and { 120, 200, 255 } or { 255, 160, 140 })

            -- 克制提示
            local cm = GetTroopCounterMult(attacker.troopType, defender.troopType)
            if cm > 1.0 then
                ts.pendingDamageTexts[#ts.pendingDamageTexts + 1] = {
                    x = tx, y = ty - 45, text = "克制!", dur = 1.0,
                    color = { 255, 220, 80 }, size = 16, delay = 0.2
                }
                Tactics.AddBattleLog("  ★ 兵种克制! 伤害+25%", { 255, 220, 80 })
            elseif cm < 1.0 then
                ts.pendingDamageTexts[#ts.pendingDamageTexts + 1] = {
                    x = tx, y = ty - 45, text = "被克", dur = 1.0,
                    color = { 150, 150, 150 }, size = 14, delay = 0.2
                }
            end

            -- 兵力折算
            if defender.hp <= 0 then
                defender.hp = 0
                defender.alive = false
                defender.unitCount = 0
                Tactics.RemoveFromGrid(defender.row, defender.col,
                    defender.isPlayer and defender.idx or -defender.idx)
                ts.pendingDamageTexts[#ts.pendingDamageTexts + 1] = {
                    x = tx, y = ty - 65, text = "全灭!", dur = 1.5,
                    color = { 255, 50, 50 }, size = 22, delay = 0.3
                }
                Tactics.AddBattleLog("  " .. defName .. " 被消灭!", { 255, 80, 60 })
                if rawget(_G, "PlaySFX") and AUDIO then PlaySFX(AUDIO.sfx_click) end
            else
                defender.unitCount = math.max(1, math.ceil(defender.maxUnits * defender.hp / defender.maxHP))
            end
        end

        if ts.animTimer <= 0 then
            attacker.animOfsX, attacker.animOfsY = 0, 0
            ts.animType = nil
            ts.animData = nil
            attacker.acted = true

            if attacker.isPlayer then
                ts.selectedGroup = nil
                ts.moveTargets = {}
                ts.attackTargets = {}
                ts.turnPhase = "PLAYER_SELECT"
            else
                ts.turnPhase = "ENEMY_THINK"
            end
        end
    else
        if ts.animTimer <= 0 then
            ts.animType = nil
            ts.animData = nil
            if ts.isPlayerTurn then
                ts.turnPhase = "PLAYER_SELECT"
            else
                ts.turnPhase = "ENEMY_THINK"
            end
        end
    end
end

-- ============================================================================
-- 玩家操作接口
-- ============================================================================

--- 玩家点击网格
function Tactics.HandleTap(row, col)
    if not tacticState then return end
    local ts = tacticState
    if not ts.isPlayerTurn then return end

    if ts.turnPhase == "PLAYER_SELECT" then
        -- 尝试选择己方兵团
        local myGroup = Tactics.GetFriendlyAt(row, col, true)
        if myGroup and myGroup.alive and not myGroup.acted then
            ts.selectedGroup = myGroup.idx
            ts.moveTargets = Tactics.CalcMoveRange(row, col, myGroup.moveRange, true, myGroup.troopType)
            ts.attackTargets = Tactics.CalcAttackRange(row, col, myGroup.atkRange, true)
            if rawget(_G, "PlaySFX") and AUDIO then PlaySFX(AUDIO.sfx_click) end
        elseif myGroup and myGroup.acted then
            AddFloatText(myGroup.screenX, myGroup.screenY - 30, "已行动", 0.8, { 180, 180, 180 }, 16)
        end

    elseif ts.turnPhase == "PLAYER_MOVE" then
        local valid = false
        for _, t in ipairs(ts.moveTargets) do
            if t.row == row and t.col == col then valid = true; break end
        end
        if valid then
            Tactics.ExecuteMove(ts.selectedGroup, true, row, col)
        else
            ts.turnPhase = "PLAYER_SELECT"
            local g = ts.playerGroups[ts.selectedGroup]
            if g and g.alive then
                ts.moveTargets = Tactics.CalcMoveRange(g.row, g.col, g.moveRange, true, g.troopType)
                ts.attackTargets = Tactics.CalcAttackRange(g.row, g.col, g.atkRange, true)
            end
        end

    elseif ts.turnPhase == "PLAYER_ATTACK" then
        local target = nil
        for _, t in ipairs(ts.attackTargets) do
            if t.row == row and t.col == col then target = t; break end
        end
        if target then
            Tactics.ExecuteAttack(ts.selectedGroup, true, target.group)
        else
            local g = ts.playerGroups[ts.selectedGroup]
            if g then g.acted = true end
            ts.selectedGroup = nil
            ts.moveTargets = {}
            ts.attackTargets = {}
            ts.turnPhase = "PLAYER_SELECT"
        end
    end
end

--- 玩家点击"移动"按钮
function Tactics.HandleMoveBtn()
    if not tacticState then return end
    local ts = tacticState
    if ts.selectedGroup and ts.turnPhase == "PLAYER_SELECT" then
        local g = ts.playerGroups[ts.selectedGroup]
        if g and g.alive and not g.acted then
            ts.moveTargets = Tactics.CalcMoveRange(g.row, g.col, g.moveRange, true, g.troopType)
            if #ts.moveTargets > 0 then
                ts.turnPhase = "PLAYER_MOVE"
            else
                AddFloatText(g.screenX, g.screenY - 30, "无法移动", 0.8, { 255, 180, 80 }, 16)
            end
        end
    end
end

--- 玩家点击"攻击"按钮
function Tactics.HandleAttackBtn()
    if not tacticState then return end
    local ts = tacticState
    if ts.selectedGroup and (ts.turnPhase == "PLAYER_SELECT" or ts.turnPhase == "PLAYER_ATTACK") then
        local g = ts.playerGroups[ts.selectedGroup]
        if g and g.alive and not g.acted then
            local atkTargets = Tactics.CalcAttackRange(g.row, g.col, g.atkRange, true)
            if #atkTargets > 0 then
                ts.attackTargets = atkTargets
                ts.turnPhase = "PLAYER_ATTACK"
            else
                if g.atkRange == 0 then
                    AddFloatText(g.screenX, g.screenY - 30, "需移入敌方格子", 1.0, { 255, 180, 80 }, 14)
                else
                    AddFloatText(g.screenX, g.screenY - 30, "无敌人在范围内", 1.0, { 255, 180, 80 }, 14)
                end
            end
        end
    end
end

--- 玩家点击"待机"按钮
function Tactics.HandleWait()
    if not tacticState then return end
    local ts = tacticState
    if ts.selectedGroup then
        local g = ts.playerGroups[ts.selectedGroup]
        if g and g.alive then
            g.acted = true
            AddFloatText(g.screenX, g.screenY - 30, "待机", 0.8, { 200, 200, 200 }, 16)
            Tactics.AddBattleLog(g.heroName .. " 待机", { 180, 180, 180 })
        end
        ts.selectedGroup = nil
        ts.moveTargets = {}
        ts.attackTargets = {}
        ts.turnPhase = "PLAYER_SELECT"
    end
end

--- 玩家点击"结束回合"按钮
function Tactics.HandleEndTurn()
    if not tacticState then return end
    if tacticState.isPlayerTurn then
        Tactics.EndPlayerTurn()
    end
end

-- ============================================================================
-- 执行移动/攻击
-- ============================================================================

function Tactics.ExecuteMove(groupIdx, isPlayer, toRow, toCol)
    local ts = tacticState
    local groups = isPlayer and ts.playerGroups or ts.enemyGroups
    local g = groups[groupIdx]
    if not g or not g.alive then return end

    local fromRow, fromCol = g.row, g.col
    local gridId = isPlayer and groupIdx or -groupIdx

    -- 更新网格(多占模型)
    Tactics.RemoveFromGrid(fromRow, fromCol, gridId)
    g.row, g.col = toRow, toCol
    Tactics.AddToGrid(toRow, toCol, gridId)

    -- 播报
    Tactics.AddBattleLog(g.heroName .. "(" .. g.troopName .. ") 移动到 (" .. toRow .. "," .. toCol .. ")",
        isPlayer and { 120, 200, 255 } or { 255, 160, 140 })

    -- 启动移动动画
    ts.animType = "move"
    ts.animTimer = 0.35
    ts.animData = {
        group = g,
        fromRow = fromRow, fromCol = fromCol,
        toRow = toRow, toCol = toCol,
        totalTime = 0.35,
    }
    ts.turnPhase = isPlayer and "PLAYER_ANIM" or "ENEMY_ANIM"
    ts.moveTargets = {}
end

function Tactics.ExecuteAttack(groupIdx, isPlayer, defender)
    local ts = tacticState
    local groups = isPlayer and ts.playerGroups or ts.enemyGroups
    local attacker = groups[groupIdx]
    if not attacker or not attacker.alive then return end

    -- 弓兵弹道特效
    if attacker.atkRange > 0 then
        local sx, sy = Tactics.GridToScreen(attacker.row, attacker.col)
        local ex, ey = Tactics.GridToScreen(defender.row, defender.col)
        ts.projectiles[#ts.projectiles + 1] = {
            sx = sx, sy = sy, ex = ex, ey = ey,
            timer = 0.6, totalTime = 0.6,
            color = attacker.isPlayer and { 100, 200, 255 } or { 255, 120, 80 },
        }
    end

    ts.animType = "attack"
    ts.animTimer = 0.6
    ts.animData = {
        attacker = attacker,
        defender = defender,
        totalTime = 0.6,
        damageApplied = false,
    }
    ts.turnPhase = isPlayer and "PLAYER_ANIM" or "ENEMY_ANIM"
    ts.attackTargets = {}
end

-- ============================================================================
-- 回合切换
-- ============================================================================

function Tactics.AllGroupsActed(isPlayer)
    local groups = isPlayer and tacticState.playerGroups or tacticState.enemyGroups
    for _, g in ipairs(groups) do
        if g.alive and not g.acted then return false end
    end
    return true
end

function Tactics.EndPlayerTurn()
    local ts = tacticState
    for _, g in ipairs(ts.playerGroups) do
        if g.alive then g.acted = true end
    end
    ts.selectedGroup = nil
    ts.moveTargets = {}
    ts.attackTargets = {}
    ts.isPlayerTurn = false
    for _, g in ipairs(ts.enemyGroups) do
        if g.alive then g.acted = false end
    end
    ts.turnPhase = "ENEMY_THINK"
    ts.bannerTimer = 1.2
    ts.bannerText = "敌方行动"
    ts._enemyActionIdx = 0
    ts._enemyThinkDelay = 0.5
    Tactics.AddBattleLog("敌方回合开始", { 255, 140, 100 })
end

-- ============================================================================
-- 敌方 AI (评分制)
-- ============================================================================

function Tactics.DoEnemyTurn(dt)
    local ts = tacticState
    if not ts._enemyThinkDelay then ts._enemyThinkDelay = 0.5 end
    ts._enemyThinkDelay = ts._enemyThinkDelay - dt
    if ts._enemyThinkDelay > 0 then return end

    if not ts._enemyActionIdx then ts._enemyActionIdx = 0 end
    ts._enemyActionIdx = ts._enemyActionIdx + 1

    local g = nil
    while ts._enemyActionIdx <= #ts.enemyGroups do
        local candidate = ts.enemyGroups[ts._enemyActionIdx]
        if candidate.alive and not candidate.acted then
            g = candidate
            break
        end
        ts._enemyActionIdx = ts._enemyActionIdx + 1
    end

    if not g then
        ts.turnPhase = "TURN_ADVANCE"
        return
    end

    local bestScore = -999
    local bestAction = nil

    -- 1) 直接攻击 (不移动)
    local directTargets = Tactics.CalcAttackRange(g.row, g.col, g.atkRange, false)
    for _, t in ipairs(directTargets) do
        local dmg = Tactics.CalcDamage(g, t.group)
        local score = dmg * 2
        local cm = GetTroopCounterMult(g.troopType, t.group.troopType)
        if cm > 1.0 then score = score + 30 end
        if t.group.hp - dmg <= 0 then score = score + 80 end
        score = score + (1 - t.group.hp / t.group.maxHP) * 20
        if score > bestScore then
            bestScore = score
            bestAction = { type = "attack", target = t.group }
        end
    end

    -- 2) 移动 + 攻击
    local moveCells = Tactics.CalcMoveRange(g.row, g.col, g.moveRange, false, g.troopType)
    for _, mc in ipairs(moveCells) do
        local atkFromCell = Tactics.CalcAttackRange(mc.row, mc.col, g.atkRange, false)
        for _, t in ipairs(atkFromCell) do
            local dmg = Tactics.CalcDamage(g, t.group)
            local score = dmg * 1.5
            local cm = GetTroopCounterMult(g.troopType, t.group.troopType)
            if cm > 1.0 then score = score + 25 end
            if t.group.hp - dmg <= 0 then score = score + 70 end
            score = score + (1 - t.group.hp / t.group.maxHP) * 15
            if score > bestScore then
                bestScore = score
                bestAction = { type = "move_attack", moveRow = mc.row, moveCol = mc.col, target = t.group }
            end
        end
    end

    -- 3) 纯移动 (向最近玩家兵团靠近)
    if not bestAction or bestScore < 20 then
        local closestDist = 999
        local closestPG = nil
        for _, pg in ipairs(ts.playerGroups) do
            if pg.alive then
                local dist = math.abs(pg.row - g.row) + math.abs(pg.col - g.col)
                if dist < closestDist then
                    closestDist = dist
                    closestPG = pg
                end
            end
        end
        if closestPG and #moveCells > 0 then
            local bestMoveDist = 999
            local bestMoveCell = nil
            for _, mc in ipairs(moveCells) do
                local d = math.abs(mc.row - closestPG.row) + math.abs(mc.col - closestPG.col)
                if d < bestMoveDist then
                    bestMoveDist = d
                    bestMoveCell = mc
                end
            end
            if bestMoveCell and bestMoveDist < closestDist then
                local moveScore = 10 + (closestDist - bestMoveDist) * 5
                if not bestAction or moveScore > bestScore then
                    bestScore = moveScore
                    bestAction = { type = "move", moveRow = bestMoveCell.row, moveCol = bestMoveCell.col }
                end
            end
        end
    end

    -- 执行最佳行动
    if bestAction then
        if bestAction.type == "attack" then
            ts.selectedGroup = g.idx
            Tactics.ExecuteAttack(g.idx, false, bestAction.target)
            ts._enemyThinkDelay = 0.5
            return
        elseif bestAction.type == "move_attack" then
            g._pendingAttackTarget = bestAction.target
            ts.selectedGroup = g.idx
            Tactics.ExecuteMove(g.idx, false, bestAction.moveRow, bestAction.moveCol)
            ts._enemyThinkDelay = 0.5
            return
        elseif bestAction.type == "move" then
            ts.selectedGroup = g.idx
            Tactics.ExecuteMove(g.idx, false, bestAction.moveRow, bestAction.moveCol)
            ts._enemyThinkDelay = 0.5
            g._markActedAfterMove = true
            return
        end
    end

    -- 无可行动作: 待机
    g.acted = true
    ts._enemyThinkDelay = 0.3
end

-- 敌方移动完成后的后续逻辑
local _origUpdateAnim = Tactics.UpdateAnim
function Tactics.UpdateAnim(dt)
    local ts = tacticState
    local prevPhase = ts.turnPhase

    _origUpdateAnim(dt)

    if prevPhase == "ENEMY_ANIM" and ts.turnPhase == "ENEMY_THINK" then
        if ts.selectedGroup then
            local g = ts.enemyGroups[ts.selectedGroup]
            if g and g.alive and not g.acted then
                if g._pendingAttackTarget then
                    local target = g._pendingAttackTarget
                    g._pendingAttackTarget = nil
                    if target.alive then
                        -- 近战: 检查同格; 远程: 检查相邻格
                        local dist = math.abs(g.row - target.row) + math.abs(g.col - target.col)
                        if (g.atkRange == 0 and dist == 0) or (g.atkRange > 0 and dist <= g.atkRange) then
                            Tactics.ExecuteAttack(g.idx, false, target)
                            return
                        end
                    end
                    g.acted = true
                elseif g._markActedAfterMove then
                    g._markActedAfterMove = nil
                    g.acted = true
                end
            end
        end
    end
end

-- ============================================================================
-- 胜负判定
-- ============================================================================

function Tactics.CheckBattleEnd()
    if not tacticState then return end
    local ts = tacticState
    if ts.turnPhase == "BATTLE_END" then return end

    local playerAlive = 0
    for _, g in ipairs(ts.playerGroups) do
        if g.alive and g.hp > 0 then playerAlive = playerAlive + 1 end
    end
    local enemyAlive = 0
    for _, g in ipairs(ts.enemyGroups) do
        if g.alive and g.hp > 0 then enemyAlive = enemyAlive + 1 end
    end

    if enemyAlive == 0 then
        ts.turnPhase = "BATTLE_END"
        gameState.phase = "WIN"
        gameState.resultTimer = 0
        Tactics.AddBattleLog("★ 我方胜利! ★", { 255, 220, 80 })
        OnBattleVictory()
    elseif playerAlive == 0 then
        ts.turnPhase = "BATTLE_END"
        gameState.phase = "LOSE"
        gameState.resultTimer = 0
        Tactics.AddBattleLog("败北...", { 200, 80, 60 })
        OnBattleEnd()
    end
end

-- ============================================================================
-- 辅助
-- ============================================================================

function Tactics.GetAliveGroups(isPlayer)
    local result = {}
    local groups = isPlayer and tacticState.playerGroups or tacticState.enemyGroups
    for _, g in ipairs(groups) do
        if g.alive and g.hp > 0 then result[#result + 1] = g end
    end
    return result
end

return Tactics
