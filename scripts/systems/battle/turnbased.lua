-- ============================================================================
-- systems/battle/turnbased.lua - 回合制战斗核心模块
-- 5行×7列网格, 列4=中间分隔, 每回合6行动点, 每军团每回合行动1次
-- ============================================================================
local M = {}

-- ============================================================================
-- 网格坐标 ↔ 屏幕坐标
-- ============================================================================
function M.GridToScreen(row, col)
    local cx = TB_GRID_LEFT + (col - 0.5) * TB_CELL_W
    local cy = TB_GRID_TOP  + (row - 0.5) * TB_CELL_H
    return cx, cy
end

function M.ScreenToGrid(sx, sy)
    local col = math.floor((sx - TB_GRID_LEFT) / TB_CELL_W) + 1
    local row = math.floor((sy - TB_GRID_TOP)  / TB_CELL_H) + 1
    if col < 1 then col = 1 end; if col > TB_COLS then col = TB_COLS end
    if row < 1 then row = 1 end; if row > TB_ROWS then row = TB_ROWS end
    return row, col
end

-- ============================================================================
-- 初始化回合制状态
-- ============================================================================
function M.Init()
    ---@class TBState
    tbState = {
        -- 军团列表
        playerRegiments = {},   -- {regiment1, regiment2, ...}
        enemyRegiments  = {},
        -- 回合状态
        turnNumber   = 1,
        isPlayerTurn = true,
        ap           = TB_MAX_AP,         -- 当前剩余行动点
        usedTroops   = {},                -- 本回合已行动的兵种 (兼容保留)
        usedRegiments = {},               -- 本回合已行动的军团 { [regId]=true }
        usedHeroes   = {},                -- 本回合已使用武技的武将 { [slotIdx]=true }
        -- 选中状态
        selectedIdx  = nil,               -- 当前选中的军团索引 (playerRegiments 中的)
        -- 高亮格子
        moveTargets  = {},                -- 可移动格 { {row, col}, ... }
        attackTargets = {},               -- 可攻击格 { {row, col}, ... }
        -- 动画
        animState    = "idle",            -- idle / moving / attacking / opp_attack / ai_think
        animTimer    = 0,
        animData     = nil,
        -- 横幅
        bannerText   = nil,
        bannerTimer  = 0,
        -- 战斗日志
        battleLog    = {},                -- 最近N条战报
        -- 自动攻击记录 (每个军团每回合只触发一次)
        oppAttackUsed = {},               -- { [regId] = true }
        -- 胜负
        battleOver   = false,
        winner       = nil,               -- "player" / "enemy"
    }

    -- 从 PLAYER_SLOTS / ENEMY_SLOTS 创建军团
    M.CreateRegiments(PLAYER_SLOTS, true)
    M.CreateRegiments(ENEMY_SLOTS, false)

    -- 显示横幅
    tbState.bannerText = "第 1 回合 - 我方行动"
    tbState.bannerTimer = 1.5

    print(string.format("[TB] 初始化完成 | 玩家军团:%d 敌方军团:%d",
        #tbState.playerRegiments, #tbState.enemyRegiments))
end

-- ============================================================================
-- 从槽位创建军团
-- ============================================================================
function M.CreateRegiments(slots, isPlayer)
    local regList = isPlayer and tbState.playerRegiments or tbState.enemyRegiments
    local startCol = isPlayer and TB_PLAYER_START_COL or TB_ENEMY_START_COL
    local regCount = 0

    for slotIdx, slot in ipairs(slots) do
        if slot.filled and slot.card then
            regCount = regCount + 1
            local card = slot.card
            local level = card.level or 1
            local troopType = card.troopType or "infantry"
            local unitClass = card.unitClass or UNIT_CLASS.SWORD_MILITIA
            local heroHp  = card.hp  or 50
            local heroAtk = card.atk or 30
            local heroDef = card.def or 20

            -- 应用装备属性加成 (玩家方武将)
            if isPlayer and rawget(_G, "GetEquipmentBonus") and card.cardIdx then
                local eqB = GetEquipmentBonus(card.cardIdx)
                if eqB.vitAdd > 0 then heroHp  = heroHp  * (1 + eqB.vitAdd / 100) end
                if eqB.strAdd > 0 then heroAtk = heroAtk * (1 + eqB.strAdd / 100) end
                if eqB.intAdd > 0 then heroDef = heroDef * (1 + eqB.intAdd / 100) end
            end

            -- 兵力计算: 基于武将品质和等级 (千人级真实兵力)
            local quality = card.quality or 1
            local soldierCount = 500 + quality * 300 + level * 80

            -- 军团聚合属性 (回合制平衡)
            local levelMult = 1 + (level - 1) * GameConfig.LEVEL_GROWTH_RATE
            local hpMult  = unitClass.hpMult  or 1.0
            local atkMult = unitClass.atkMult or 1.0
            local defMult = unitClass.defMult or 1.0

            -- 命座加成
            local cBonus = GameConfig.CONSTELLATION_BONUS[card.constellation or 0]
                or GameConfig.CONSTELLATION_BONUS[0]

            local regHP  = soldierCount * (3 + level) * hpMult * (cBonus.hpMult or 1)
            local regATK = (heroAtk * TB_DMG_ATK_BASE + 10) * levelMult * atkMult * (cBonus.atkMult or 1)
            local regDEF = (heroDef * TB_DMG_DEF_MULT + 5) * levelMult * defMult * (cBonus.defMult or 1)

            -- 分配行: 每个军团占一行
            local row = ((regCount - 1) % TB_ROWS) + 1

            local screenX, screenY = M.GridToScreen(row, startCol)
            local troopColor = TROOP_TYPES[troopType] and TROOP_TYPES[troopType].color or {180,180,180}
            local troopIcon  = TROOP_TYPES[troopType] and TROOP_TYPES[troopType].icon  or "兵"

            local reg = {
                id        = (isPlayer and "p" or "e") .. slotIdx,
                isPlayer  = isPlayer,
                slotIdx   = slotIdx,
                row       = row,
                col       = startCol,
                screenX   = screenX,
                screenY   = screenY,
                -- 属性
                hp        = regHP,
                maxHP     = regHP,
                atk       = regATK,
                def       = regDEF,
                -- 兵种
                troopType = troopType,
                troopColor = troopColor,
                icon      = troopIcon,
                spriteName = unitClass.sprite or "sword",
                unitCount  = soldierCount,
                maxUnits   = soldierCount,
                -- 武将信息
                heroName  = card.name or "无名",
                heroIdx   = card.cardIdx,
                card      = card,
                -- 状态
                alive     = true,
                acted     = false,
                flashTimer = 0,
                -- 移动/攻击范围
                moveRange = TB_MOVE_RANGE[troopType] or 1,
                atkRange  = TB_ATK_RANGE[troopType]  or 1,
            }

            table.insert(regList, reg)
        end
    end
end

-- ============================================================================
-- 回合制主更新 (每帧调用)
-- ============================================================================
function M.Update(dt)
    if not tbState then return end
    if tbState.battleOver then return end

    -- 横幅倒计时
    if tbState.bannerTimer > 0 then
        tbState.bannerTimer = tbState.bannerTimer - dt
    end

    -- 战报日志淡入计时
    for _, entry in ipairs(tbState.battleLog) do
        if entry.timer < 2.0 then entry.timer = entry.timer + dt end
    end

    -- 受击闪烁衰减
    for _, r in ipairs(tbState.playerRegiments) do
        if r.flashTimer and r.flashTimer > 0 then r.flashTimer = r.flashTimer - dt end
    end
    for _, r in ipairs(tbState.enemyRegiments) do
        if r.flashTimer and r.flashTimer > 0 then r.flashTimer = r.flashTimer - dt end
    end

    -- 动画状态机
    if tbState.animState == "moving" then
        M.UpdateMoveAnim(dt)
        return
    elseif tbState.animState == "attacking" then
        M.UpdateAttackAnim(dt)
        return
    elseif tbState.animState == "opp_attack" then
        M.UpdateOppAttackAnim(dt)
        return
    elseif tbState.animState == "skill_trigger" then
        M.UpdateSkillTriggerAnim(dt)
        return
    elseif tbState.animState == "ai_think" then
        tbState.animTimer = tbState.animTimer - dt
        if tbState.animTimer <= 0 then
            M.ExecuteAITurn()
        end
        return
    elseif tbState.animState == "auto_player" then
        tbState.animTimer = tbState.animTimer - dt
        if tbState.animTimer <= 0 then
            M.ExecutePlayerAutoBattle()
        end
        return
    end

    -- 自动战斗: 玩家回合 idle 时自动执行
    if tbState.isPlayerTurn and tbState.animState == "idle" and gameSettings.tbAutoBattle then
        tbState.animState = "auto_player"
        tbState.animTimer = 0.4
        return
    end

    -- AI 回合
    if not tbState.isPlayerTurn and tbState.animState == "idle" then
        tbState.animState = "ai_think"
        tbState.animTimer = 0.4  -- AI 思考延迟
    end
end

-- ============================================================================
-- 移动动画
-- ============================================================================
function M.UpdateMoveAnim(dt)
    local d = tbState.animData
    if not d then tbState.animState = "idle"; return end
    d.timer = d.timer + dt
    local prog = math.min(1, d.timer / d.duration)
    -- 线性插值
    d.reg.screenX = d.fromX + (d.toX - d.fromX) * prog
    d.reg.screenY = d.fromY + (d.toY - d.fromY) * prog
    if prog >= 1 then
        d.reg.row = d.toRow
        d.reg.col = d.toCol
        d.reg.screenX, d.reg.screenY = M.GridToScreen(d.toRow, d.toCol)
        tbState.animState = "idle"
        tbState.animData = nil
        -- 移动完成后检查自动攻击
        M.CheckOpportunityAttacks(d.reg)
    end
end

-- ============================================================================
-- 攻击动画
-- ============================================================================
function M.UpdateAttackAnim(dt)
    local d = tbState.animData
    if not d then tbState.animState = "idle"; return end
    d.timer = d.timer + dt
    local prog = math.min(1, d.timer / d.duration)
    if prog < 0.5 then
        -- 前冲
        local t = prog / 0.5
        d.reg.screenX = d.fromX + (d.toX - d.fromX) * t * 0.4
    else
        -- 回退
        local t = (prog - 0.5) / 0.5
        d.reg.screenX = d.fromX + (d.toX - d.fromX) * 0.4 * (1 - t)
    end
    -- 在中点施加伤害
    if not d.damaged and prog >= 0.45 then
        d.damaged = true
        PlaySFX(AUDIO.sfx_kill)  -- 普通攻击播放"杀！"配音
        M.ApplyAttackDamage(d.reg, d.targets, false)
    end
    if prog >= 1 then
        d.reg.screenX, d.reg.screenY = M.GridToScreen(d.reg.row, d.reg.col)
        tbState.animData = nil
        -- 30% 概率触发武技
        if d.reg.isPlayer and M.TryAutoSkillTrigger(d.reg) then
            -- 进入武技播报状态, 不回到 idle
        else
            tbState.animState = "idle"
            M.CheckBattleEnd()
        end
    end
end

-- ============================================================================
-- 自动攻击动画 (移动后触发)
-- ============================================================================
function M.UpdateOppAttackAnim(dt)
    local d = tbState.animData
    if not d then tbState.animState = "idle"; return end
    d.timer = d.timer + dt
    local prog = math.min(1, d.timer / d.duration)
    if not d.damaged and prog >= 0.3 then
        d.damaged = true
        M.ApplyAttackDamage(d.attacker, d.targets, true)
    end
    if prog >= 1 then
        tbState.animState = "idle"
        tbState.animData = nil
        M.CheckBattleEnd()
    end
end

-- ============================================================================
-- 自动攻击检查: 移动后, 移动者对攻击范围内的敌人发动一次免费攻击
-- ============================================================================
function M.CheckOpportunityAttacks(movedReg)
    if tbState.oppAttackUsed[movedReg.id] then return end  -- 本回合已触发过

    -- 收集移动者攻击范围内同行的敌人
    local enemies = movedReg.isPlayer and tbState.enemyRegiments or tbState.playerRegiments
    local targets = {}
    for _, enemy in ipairs(enemies) do
        if enemy.alive and enemy.row == movedReg.row then
            local colDist = math.abs(movedReg.col - enemy.col)
            if colDist <= movedReg.atkRange and colDist > 0 then
                table.insert(targets, enemy)
            end
        end
    end

    if #targets == 0 then return end

    -- 标记已使用, 每回合每个军团只触发一次
    tbState.oppAttackUsed[movedReg.id] = true

    -- 播放自动攻击动画 (移动者主动攻击)
    tbState.animState = "opp_attack"
    tbState.animData = {
        attacker = movedReg,
        targets  = targets,
        timer    = 0,
        duration = 0.4,
        damaged  = false,
    }
    movedReg.flashTimer = 0.3
    M.AddLog(movedReg.heroName .. " 前进后自动攻击!")
end

-- ============================================================================
-- 伤害计算与施加
-- ============================================================================
function M.ApplyAttackDamage(attacker, targets, isOppAttack)
    local atkVal = attacker.atk
    local troopType = attacker.troopType

    for _, target in ipairs(targets) do
        if target.alive then
            -- 克制倍率
            local counterMult = GetTroopCounterMult(troopType, target.troopType)
            -- 伤害 = max(MIN, ATK * counterMult - DEF * defMult)
            local rawDmg = atkVal * counterMult - target.def * TB_DMG_DEF_MULT
            local dmg = math.max(TB_DMG_MIN, math.floor(rawDmg))
            -- 自动攻击只造成60%伤害
            if isOppAttack then
                dmg = math.max(TB_DMG_MIN, math.floor(dmg * TB_OPP_ATK_MULT))
            end

            target.hp = target.hp - dmg
            target.flashTimer = 0.5

            -- 兵力随HP同步减少
            local hpRatio = math.max(0, target.hp / target.maxHP)
            target.unitCount = math.max(1, math.ceil(target.maxUnits * hpRatio))

            -- 浮动伤害文字
            local sx, sy = target.screenX, target.screenY
            local dmgColor = isOppAttack and {255, 180, 60} or {255, 80, 60}
            AddFloatText(sx, sy - 15, "-" .. dmg, 1.0, dmgColor, 16)

            -- 克制标记
            if counterMult > 1.0 then
                AddFloatText(sx + 20, sy - 25, "克制!", 0.8, {255, 220, 80}, 12)
            elseif counterMult < 1.0 then
                AddFloatText(sx + 20, sy - 25, "被克", 0.8, {120, 120, 120}, 11)
            end

            -- 死亡判定
            if target.hp <= 0 then
                target.hp = 0
                target.alive = false
                target.unitCount = 0
                M.AddLog(target.heroName .. " 军团覆灭!")
                -- 死亡粒子
                for _ = 1, 8 do
                    table.insert(particles, {
                        x = sx, y = sy,
                        vx = math.random(-60, 60), vy = math.random(-80, -20),
                        timer = 0, life = 0.8,
                    })
                end
            end

            local oppTag = isOppAttack and "(自动)" or ""
            M.AddLog(string.format("%s 攻击 %s %s 造成 %d 伤害",
                attacker.heroName, target.heroName, oppTag, dmg))
        end
    end
end

-- ============================================================================
-- 玩家操作: 选中军团
-- ============================================================================
function M.SelectRegiment(regIdx)
    if tbState.animState ~= "idle" then return end
    if not tbState.isPlayerTurn then return end
    local reg = tbState.playerRegiments[regIdx]
    if not reg or not reg.alive then return end
    -- 检查该军团是否已行动
    if tbState.usedRegiments[reg.id] then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, reg.heroName .. " 已行动", 0.8, {255, 180, 60}, 14)
        return
    end
    tbState.selectedIdx = regIdx
    -- 计算可移动/可攻击格
    M.CalcMoveTargets(reg)
    M.CalcAttackTargets(reg)
end

-- ============================================================================
-- 计算可移动格子
-- ============================================================================
function M.CalcMoveTargets(reg)
    tbState.moveTargets = {}
    local moveR = reg.moveRange
    -- 枪兵8方向(含对角线), 其他兵种4方向(上下左右)
    local dirs
    if reg.troopType == "spear" then
        dirs = { {0,1},{0,-1},{1,0},{-1,0},{1,1},{1,-1},{-1,1},{-1,-1} }
    else
        dirs = { {0,1},{0,-1},{1,0},{-1,0} }
    end
    -- BFS 扩展可达格子
    local visited = {}
    local key = function(r, c) return r * 100 + c end
    local queue = { { row = reg.row, col = reg.col, dist = 0 } }
    visited[key(reg.row, reg.col)] = true
    -- 检查友军和敌军双方占据，每个格子只能有一个单位
    local friendly = reg.isPlayer and tbState.playerRegiments or tbState.enemyRegiments
    local enemies  = reg.isPlayer and tbState.enemyRegiments  or tbState.playerRegiments
    local head = 1
    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        if cur.dist > 0 then
            table.insert(tbState.moveTargets, { row = cur.row, col = cur.col })
        end
        if cur.dist < moveR then
            for _, d in ipairs(dirs) do
                local nr, nc = cur.row + d[1], cur.col + d[2]
                if nr >= 1 and nr <= TB_ROWS and nc >= 1 and nc <= TB_COLS and not visited[key(nr, nc)] then
                    -- 检查是否有任何单位（友军或敌军）占据该格子
                    local blocked = false
                    for _, fr in ipairs(friendly) do
                        if fr.alive and fr.id ~= reg.id and fr.row == nr and fr.col == nc then
                            blocked = true; break
                        end
                    end
                    if not blocked then
                        for _, en in ipairs(enemies) do
                            if en.alive and en.row == nr and en.col == nc then
                                blocked = true; break
                            end
                        end
                    end
                    if not blocked then
                        visited[key(nr, nc)] = true
                        queue[#queue + 1] = { row = nr, col = nc, dist = cur.dist + 1 }
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 计算可攻击格子
-- ============================================================================
function M.CalcAttackTargets(reg)
    tbState.attackTargets = {}
    local atkR = reg.atkRange
    local enemies = reg.isPlayer and tbState.enemyRegiments or tbState.playerRegiments
    -- 攻击方向: 玩家向右(+col), 敌方向左(-col)
    local dir = reg.isPlayer and 1 or -1
    for dc = 1, atkR do
        local tc = reg.col + dc * dir
        if tc >= 1 and tc <= TB_COLS then
            -- 检查前方列内同行的敌人 (仅同行可攻击)
            for _, en in ipairs(enemies) do
                if en.alive and en.col == tc and en.row == reg.row then
                    table.insert(tbState.attackTargets, { row = en.row, col = en.col })
                end
            end
        end
    end
end

-- ============================================================================
-- 玩家操作: 移动到目标格
-- ============================================================================
function M.MoveRegiment(targetRow, targetCol)
    if tbState.animState ~= "idle" then return false end
    if not tbState.isPlayerTurn then return false end
    local idx = tbState.selectedIdx
    if not idx then return false end
    local reg = tbState.playerRegiments[idx]
    if not reg or not reg.alive then return false end
    -- 验证目标在可移动列表中
    local valid = false
    for _, mt in ipairs(tbState.moveTargets) do
        if mt.row == targetRow and mt.col == targetCol then valid = true; break end
    end
    if not valid then return false end

    -- 消耗行动点
    tbState.ap = tbState.ap - 1
    tbState.usedRegiments[reg.id] = true
    reg.acted = true

    -- 启动移动动画
    local fromX, fromY = reg.screenX, reg.screenY
    local toX, toY = M.GridToScreen(targetRow, targetCol)
    tbState.animState = "moving"
    tbState.animData = {
        reg = reg,
        fromX = fromX, fromY = fromY,
        toX = toX, toY = toY,
        toRow = targetRow, toCol = targetCol,
        timer = 0, duration = 0.3,
    }

    -- 清除选中
    tbState.selectedIdx = nil
    tbState.moveTargets = {}
    tbState.attackTargets = {}

    M.AddLog(reg.heroName .. " 移动到 (" .. targetRow .. "," .. targetCol .. ")")
    return true
end

-- ============================================================================
-- 玩家操作: 攻击目标格
-- ============================================================================
function M.AttackTarget(targetRow, targetCol)
    if tbState.animState ~= "idle" then return false end
    if not tbState.isPlayerTurn then return false end
    local idx = tbState.selectedIdx
    if not idx then return false end
    local reg = tbState.playerRegiments[idx]
    if not reg or not reg.alive then return false end
    -- 验证目标在可攻击列表中
    local valid = false
    for _, at in ipairs(tbState.attackTargets) do
        if at.row == targetRow and at.col == targetCol then valid = true; break end
    end
    if not valid then return false end

    -- 消耗行动点
    tbState.ap = tbState.ap - 1
    tbState.usedRegiments[reg.id] = true
    reg.acted = true

    -- 收集目标列同行所有敌方军团
    local targets = {}
    for _, en in ipairs(tbState.enemyRegiments) do
        if en.alive and en.row == targetRow and en.col == targetCol then
            table.insert(targets, en)
        end
    end

    -- 启动攻击动画
    local fromX, fromY = reg.screenX, reg.screenY
    local toX, toY = M.GridToScreen(targetRow, targetCol)
    tbState.animState = "attacking"
    tbState.animData = {
        reg = reg,
        targets = targets,
        fromX = fromX, fromY = fromY,
        toX = toX, toY = toY,
        timer = 0, duration = 0.5,
        damaged = false,
    }

    tbState.selectedIdx = nil
    tbState.moveTargets = {}
    tbState.attackTargets = {}

    M.AddLog(reg.heroName .. " 发起攻击!")
    return true
end

-- ============================================================================
-- 玩家操作: 使用武技 (消耗1行动点)
-- ============================================================================
function M.UseHeroSkill(regIdx)
    if tbState.animState ~= "idle" then return false end
    if not tbState.isPlayerTurn then return false end
    if tbState.ap <= 0 then return false end
    local reg = tbState.playerRegiments[regIdx]
    if not reg or not reg.alive then return false end
    -- 检查武将是否已使用武技
    if tbState.usedHeroes[reg.slotIdx] then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "武技已使用", 0.8, {255, 180, 60}, 14)
        return false
    end

    local slot = PLAYER_SLOTS[reg.slotIdx]
    if not slot or not slot.card then return false end
    local techIdx = slot.card.equippedTechnique
    if not techIdx then
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "未装备武技", 0.8, {255, 180, 60}, 14)
        return false
    end
    local tech = SKILL_TECHNIQUES and SKILL_TECHNIQUES[techIdx]
    if not tech then return false end

    -- 消耗行动点
    tbState.ap = tbState.ap - 1
    tbState.usedHeroes[reg.slotIdx] = true

    -- 武技效果: 对同行所有敌方造成伤害 (基于武技等级)
    -- 从全局 skillLayers 读取实际武技养成等级（UI升级写入 skillLayers[idx]）
    local techLevel = (rawget(_G, "skillLayers") and skillLayers[techIdx]) or 1
    local skillDmg = reg.atk * (1.5 + techLevel * 0.3)
    local enemies = tbState.enemyRegiments
    local hitCount = 0
    for _, en in ipairs(enemies) do
        if en.alive and en.row == reg.row then
            local dmg = math.max(TB_DMG_MIN, math.floor(skillDmg - en.def * TB_DMG_DEF_MULT * 0.5))
            en.hp = en.hp - dmg
            en.flashTimer = 0.5
            local hpRatio = math.max(0, en.hp / en.maxHP)
            en.unitCount = math.max(1, math.ceil(en.maxUnits * hpRatio))
            AddFloatText(en.screenX, en.screenY - 15, "-" .. dmg, 1.0, {255, 160, 255}, 16)
            if en.hp <= 0 then
                en.hp = 0; en.alive = false; en.unitCount = 0
                M.AddLog(en.heroName .. " 被武技击溃!")
            end
            hitCount = hitCount + 1
        end
    end

    AddFloatText(reg.screenX, reg.screenY - 30, tech.name, 1.2, {255, 200, 255}, 14)
    M.AddLog(string.format("%s 发动武技 [%s] 命中%d个目标", reg.heroName, tech.name, hitCount))
    PlaySFX(AUDIO.sfx_skill)
    M.CheckBattleEnd()
    return true
end

-- ============================================================================
-- 结束回合
-- ============================================================================
function M.EndTurn()
    if tbState.animState ~= "idle" then return end
    if tbState.battleOver then return end

    if tbState.isPlayerTurn then
        -- 玩家回合结束 → 敌方回合
        tbState.isPlayerTurn = false
        tbState.ap = TB_MAX_AP
        tbState.usedTroops = {}
        tbState.usedRegiments = {}
        tbState.usedHeroes = {}
        tbState.oppAttackUsed = {}
        -- 重置敌方已行动标记
        for _, r in ipairs(tbState.enemyRegiments) do r.acted = false end
        tbState.bannerText = "第 " .. tbState.turnNumber .. " 回合 - 敌方行动"
        tbState.bannerTimer = 1.0
        tbState.selectedIdx = nil
        tbState.moveTargets = {}
        tbState.attackTargets = {}
    else
        -- 敌方回合结束 → 下一回合玩家
        tbState.turnNumber = tbState.turnNumber + 1
        tbState.isPlayerTurn = true
        tbState.ap = TB_MAX_AP
        tbState.usedTroops = {}
        tbState.usedRegiments = {}
        tbState.usedHeroes = {}
        tbState.oppAttackUsed = {}
        -- 重置玩家已行动标记
        for _, r in ipairs(tbState.playerRegiments) do r.acted = false end
        tbState.bannerText = "第 " .. tbState.turnNumber .. " 回合 - 我方行动"
        tbState.bannerTimer = 1.5
    end
end

-- ============================================================================
-- AI 回合执行
-- ============================================================================
function M.ExecuteAITurn()
    if tbState.battleOver then return end
    if tbState.isPlayerTurn then return end

    -- 必须先将 animState 设为 idle，否则 EndTurn() 会因状态检查直接返回
    tbState.animState = "idle"

    if tbState.ap <= 0 then
        M.EndTurn()
        return
    end

    -- 找一个未行动的存活敌方军团
    local chosen = nil
    local chosenIdx = nil
    for i, r in ipairs(tbState.enemyRegiments) do
        if r.alive and not tbState.usedRegiments[r.id] then
            chosen = r; chosenIdx = i; break
        end
    end

    if not chosen then
        -- 所有军团已行动 或 无存活军团
        M.EndTurn()
        return
    end

    -- AI 策略: 优先攻击 > 移动靠近
    -- 1) 检查是否能攻击 (前方列, 同行及相邻行)
    local atkR = chosen.atkRange
    local bestTarget = nil
    local bestTargetCol = nil
    for dc = 1, atkR do
        local tc = chosen.col - dc  -- 敌方向左攻击
        if tc >= 1 and tc <= TB_COLS then
            for _, pl in ipairs(tbState.playerRegiments) do
                if pl.alive and pl.col == tc and pl.row == chosen.row then
                    bestTarget = pl
                    bestTargetCol = tc
                    break
                end
            end
        end
        if bestTarget then break end
    end

    if bestTarget then
        -- 攻击
        tbState.ap = tbState.ap - 1
        tbState.usedRegiments[chosen.id] = true
        chosen.acted = true
        local targets = { bestTarget }
        local fromX, fromY = chosen.screenX, chosen.screenY
        local toX, toY = M.GridToScreen(bestTarget.row, bestTargetCol)
        tbState.animState = "attacking"
        tbState.animData = {
            reg = chosen, targets = targets,
            fromX = fromX, fromY = fromY, toX = toX, toY = toY,
            timer = 0, duration = 0.5, damaged = false,
        }
        M.AddLog(chosen.heroName .. " 发起攻击!")
        return
    end

    -- 2) 移动靠近最近的玩家单位 (多方向BFS)
    M.CalcMoveTargets(chosen)
    local bestMove = nil
    local bestDist = 999
    for _, mt in ipairs(tbState.moveTargets) do
        for _, pl in ipairs(tbState.playerRegiments) do
            if pl.alive then
                local dist = math.abs(mt.col - pl.col) + math.abs(mt.row - pl.row)
                if dist < bestDist then
                    bestDist = dist
                    bestMove = mt
                end
            end
        end
    end

    if bestMove then
        tbState.ap = tbState.ap - 1
        tbState.usedRegiments[chosen.id] = true
        chosen.acted = true
        local fromX, fromY = chosen.screenX, chosen.screenY
        local toX, toY = M.GridToScreen(bestMove.row, bestMove.col)
        tbState.animState = "moving"
        tbState.animData = {
            reg = chosen,
            fromX = fromX, fromY = fromY,
            toX = toX, toY = toY,
            toRow = bestMove.row, toCol = bestMove.col,
            timer = 0, duration = 0.3,
        }
        M.AddLog(chosen.heroName .. " 移动到 (" .. bestMove.row .. "," .. bestMove.col .. ")")
        return
    end

    -- 无法行动, 标记行动过
    tbState.usedRegiments[chosen.id] = true
    chosen.acted = true
    tbState.ap = tbState.ap - 1
    -- 继续下一个AI回合
    tbState.animState = "ai_think"
    tbState.animTimer = 0.2
end

-- ============================================================================
-- 胜负检查
-- ============================================================================
function M.CheckBattleEnd()
    if tbState.battleOver then return end
    local playerAlive = 0
    for _, r in ipairs(tbState.playerRegiments) do
        if r.alive then playerAlive = playerAlive + 1 end
    end
    local enemyAlive = 0
    for _, r in ipairs(tbState.enemyRegiments) do
        if r.alive then enemyAlive = enemyAlive + 1 end
    end

    if enemyAlive == 0 then
        tbState.battleOver = true
        tbState.winner = "player"
        tbState.bannerText = "胜利!"
        tbState.bannerTimer = 3.0
        -- 延迟切换到 WIN 阶段
        gameState.resultTimer = 0
        gameState.phase = "WIN"
        print("[TB] 战斗胜利!")
        -- 同步战斗结果到SLG大地图（奖励、城池占领、武将招降等）
        if rawget(_G, "OnBattleVictory") then
            OnBattleVictory()
        end
    elseif playerAlive == 0 then
        tbState.battleOver = true
        tbState.winner = "enemy"
        tbState.bannerText = "败北..."
        tbState.bannerTimer = 3.0
        gameState.resultTimer = 0
        gameState.phase = "LOSE"
        print("[TB] 战斗失败!")
        -- 同步战斗结果到SLG大地图（武将死亡/招降、兵力返回等）
        if rawget(_G, "OnBattleEnd") then
            OnBattleEnd()
        end
    end
end

-- ============================================================================
-- 点击处理 (从 input_core 调用)
-- ============================================================================
function M.HandleClick(dx, dy)
    if not tbState or tbState.battleOver then return false end
    if tbState.animState ~= "idle" then return false end
    if not tbState.isPlayerTurn then return false end

    -- 坐标是否在网格内
    if dx < TB_GRID_LEFT or dx > TB_GRID_RIGHT or dy < TB_GRID_TOP or dy > TB_GRID_BOTTOM then
        return false
    end

    local row, col = M.ScreenToGrid(dx, dy)

    -- 1) 检查是否点击了攻击目标格
    for _, at in ipairs(tbState.attackTargets) do
        if at.row == row and at.col == col then
            return M.AttackTarget(row, col)
        end
    end

    -- 2) 检查是否点击了移动目标格
    for _, mt in ipairs(tbState.moveTargets) do
        if mt.row == row and mt.col == col then
            return M.MoveRegiment(row, col)
        end
    end

    -- 3) 检查是否点击了自己的军团 (选中/取消)
    for i, r in ipairs(tbState.playerRegiments) do
        if r.alive and r.row == row and r.col == col then
            if tbState.selectedIdx == i then
                -- 取消选中
                tbState.selectedIdx = nil
                tbState.moveTargets = {}
                tbState.attackTargets = {}
            else
                M.SelectRegiment(i)
            end
            return true
        end
    end

    -- 4) 点击空白格: 取消选中
    tbState.selectedIdx = nil
    tbState.moveTargets = {}
    tbState.attackTargets = {}
    return true
end

-- ============================================================================
-- 战斗日志
-- ============================================================================
function M.AddLog(text, color)
    table.insert(tbState.battleLog, {
        text  = text,
        timer = 0,
        color = color or { 220, 220, 200 },
    })
    if #tbState.battleLog > 8 then
        table.remove(tbState.battleLog, 1)
    end
end

-- ============================================================================
-- 取消选中 (供外部调用)
-- ============================================================================
function M.Deselect()
    if tbState then
        tbState.selectedIdx = nil
        tbState.moveTargets = {}
        tbState.attackTargets = {}
    end
end

-- ============================================================================
-- 武技自动触发 (30% 概率, 普通攻击结束后)
-- ============================================================================
function M.TryAutoSkillTrigger(reg)
    if tbState.battleOver then return false end
    if math.random() > 0.50 then return false end  -- 50%不触发

    -- 检查武将是否有装备武技
    local slot = PLAYER_SLOTS[reg.slotIdx]
    if not slot or not slot.card then return false end
    local techIdx = nil
    local heroIdx = slot.card.cardIdx
    if heroIdx and rawget(_G, "playerEquippedSkills") then
        local skills = playerEquippedSkills[heroIdx]
        if skills and skills[1] then techIdx = skills[1] end
    end
    if not techIdx then
        techIdx = slot.card.equippedTechnique
    end
    -- 若未装备武技，根据英雄品质自动分配一个默认武技
    if not techIdx then
        local q = slot.card.quality or 1
        -- 品质→武技索引范围: COMMON(1-6), RARE(7-12), EPIC(13-24), LEGENDARY(25-35), LIMITED(36)
        local tierRanges = {
            { 1,  6 },   -- COMMON  → 凡品
            { 7, 12 },   -- RARE    → 良品
            { 13, 24 },  -- EPIC    → 优/将品
            { 25, 35 },  -- LEGENDARY → 侯/王品
            { 36, 36 },  -- LIMITED → 帝品
        }
        local range = tierRanges[q] or tierRanges[1]
        techIdx = math.random(range[1], range[2])
    end
    if not techIdx then return false end
    local tech = SKILL_TECHNIQUES and SKILL_TECHNIQUES[techIdx]
    if not tech then return false end
    local skillDef = SKILL_DEFS and SKILL_DEFS[techIdx]

    -- 根据技能类型选择目标
    local enemies = tbState.enemyRegiments
    -- 从全局 skillLayers 读取实际武技养成等级（UI升级写入 skillLayers[idx]）
    local techLevel = (rawget(_G, "skillLayers") and skillLayers[techIdx]) or 1
    local skillDmg = reg.atk * (1.5 + techLevel * 0.3)
    local sType = skillDef and skillDef.skillType or "aoe"
    local isBigAoe = skillDef and BIG_AOE_ICONS[skillDef.iconIdx]

    -- 收集将被命中的目标列表 hitTargets = { {enemy, row, col}, ... }
    local hitTargets = {}

    if sType == "heal" then
        -- 治疗技能: 选择己方受伤的友军回复兵力
        local allies = reg.isPlayer and tbState.playerRegiments or tbState.enemyRegiments
        for _, al in ipairs(allies) do
            if al.alive and al.hp < al.maxHP then
                table.insert(hitTargets, al)
            end
        end
        if #hitTargets == 0 then return false end  -- 全员满血则不触发
    elseif isBigAoe then
        -- 全屏技能: 命中所有存活敌人
        for _, en in ipairs(enemies) do
            if en.alive then table.insert(hitTargets, en) end
        end
    elseif sType == "line" then
        -- 线性技能: 贯穿一列, 选敌人最多的列
        local bestCol, bestCount = nil, 0
        for col = 1, TB_COLS do
            local cnt = 0
            for _, en in ipairs(enemies) do
                if en.alive and en.col == col then cnt = cnt + 1 end
            end
            if cnt > bestCount then bestCount = cnt; bestCol = col end
        end
        if bestCol then
            for _, en in ipairs(enemies) do
                if en.alive and en.col == bestCol then
                    table.insert(hitTargets, en)
                end
            end
        end
    else
        -- aoe/rect/zone: 以敌人最密集的位置为中心, 根据阶级扩大范围
        -- tier 1-2: 命中1行, tier 3-4: 2行, tier 5-6: 3行, tier 7: 全部
        local tier = tech.tier or 1
        local rowSpread = 0  -- 中心行上下各扩展多少行
        if tier <= 2 then rowSpread = 0
        elseif tier <= 4 then rowSpread = 1
        elseif tier <= 6 then rowSpread = 2
        else rowSpread = TB_ROWS end  -- 帝品覆盖全部

        -- 选最优中心行: 该行及扩展范围内敌人最多
        local bestRow, bestCount = nil, 0
        for centerRow = 1, TB_ROWS do
            local cnt = 0
            for _, en in ipairs(enemies) do
                if en.alive and math.abs(en.row - centerRow) <= rowSpread then
                    cnt = cnt + 1
                end
            end
            if cnt > bestCount then bestCount = cnt; bestRow = centerRow end
        end
        if bestRow then
            for _, en in ipairs(enemies) do
                if en.alive and math.abs(en.row - bestRow) <= rowSpread then
                    table.insert(hitTargets, en)
                end
            end
        end
    end

    if #hitTargets == 0 then return false end

    -- 计算特效显示的中心位置
    local avgFxX, avgFxY, fxCount = 0, 0, 0
    for _, en in ipairs(hitTargets) do
        avgFxX = avgFxX + en.screenX
        avgFxY = avgFxY + en.screenY
        fxCount = fxCount + 1
    end
    local fxX = fxCount > 0 and (avgFxX / fxCount) or 0
    local fxY = fxCount > 0 and (avgFxY / fxCount) or 0

    -- 进入武技播报状态
    tbState.animState = "skill_trigger"
    tbState.animData = {
        reg      = reg,
        techIdx  = techIdx,
        tech     = tech,
        techLevel = techLevel,
        skillDmg = skillDmg,
        hitTargets = hitTargets,
        isHeal   = (sType == "heal"),
        timer    = 0,
        duration = 1.8,     -- 播报 1.8 秒: 0~0.8 弹窗, 0.8~1.8 伤害+特效
        damaged  = false,
    }

    -- 播报横幅: 武技名
    tbState.bannerText = reg.heroName .. " 发动武技【" .. tech.name .. "】!"
    tbState.bannerTimer = 1.5

    -- 播放武技音效
    PlaySFX(AUDIO.sfx_skill)

    -- 添加技能特效到 activeSkillEffects
    if skillDef then
        local fxData = SKILL_FX_SHEETS[skillDef.iconIdx]
        local animDur = (fxData and fxData.frames and fxData.fps)
            and (fxData.frames / fxData.fps) or 1.0
        local eff = {
            x = fxX,
            y = fxY,
            skillIdx = techIdx,
            timer = 0,
            duration = animDur,
            frameIdx = 0,
            damaged = false,
            isEnemySkill = not reg.isPlayer,
            isLine = (sType == "line"),
            _tbSkillEffect = true,
        }
        table.insert(activeSkillEffects, eff)
    end

    M.AddLog(string.format("%s 触发武技 [%s]!", reg.heroName, tech.name), {255, 200, 255})
    return true
end

-- ============================================================================
-- 武技触发动画更新
-- ============================================================================
function M.UpdateSkillTriggerAnim(dt)
    local d = tbState.animData
    if not d then tbState.animState = "idle"; return end
    d.timer = d.timer + dt
    local prog = math.min(1, d.timer / d.duration)

    -- 同步更新 activeSkillEffects 中的回合制武技特效
    for _, eff in ipairs(activeSkillEffects) do
        if eff._tbSkillEffect then
            eff.timer = eff.timer + dt
            local fxData = SKILL_FX_SHEETS[SKILL_DEFS[eff.skillIdx] and SKILL_DEFS[eff.skillIdx].iconIdx or 0]
            if fxData and fxData.fps then
                eff.frameIdx = math.floor(eff.timer * fxData.fps)
            end
        end
    end

    -- 在0.5时施加伤害或治疗 (按 hitTargets 列表命中)
    if not d.damaged and prog >= 0.5 then
        d.damaged = true
        local hitCount = 0
        if d.isHeal then
            -- 治疗: 回复己方兵力
            local healAmt = math.floor(d.skillDmg * 0.8)
            for _, al in ipairs(d.hitTargets or {}) do
                if al.alive then
                    local before = al.hp
                    al.hp = math.min(al.maxHP, al.hp + healAmt)
                    local actual = al.hp - before
                    al.flashTimer = 0.5
                    local hpRatio = math.max(0, al.hp / al.maxHP)
                    al.unitCount = math.max(1, math.ceil(al.maxUnits * hpRatio))
                    AddFloatText(al.screenX, al.screenY - 15, "+" .. actual, 1.0, {120, 255, 160}, 16)
                    hitCount = hitCount + 1
                end
            end
            M.AddLog(string.format("[%s] 治疗%d个友军", d.tech.name, hitCount), {120, 255, 160})
        else
            -- 伤害: 对敌方造成伤害
            for _, en in ipairs(d.hitTargets or {}) do
                if en.alive then
                    local dmg = math.max(TB_DMG_MIN, math.floor(d.skillDmg - en.def * TB_DMG_DEF_MULT * 0.5))
                    en.hp = en.hp - dmg
                    en.flashTimer = 0.5
                    local hpRatio = math.max(0, en.hp / en.maxHP)
                    en.unitCount = math.max(1, math.ceil(en.maxUnits * hpRatio))
                    AddFloatText(en.screenX, en.screenY - 15, "-" .. dmg, 1.0, {255, 160, 255}, 16)
                    if en.hp <= 0 then
                        en.hp = 0; en.alive = false; en.unitCount = 0
                        M.AddLog(en.heroName .. " 被武技击溃!")
                    end
                    hitCount = hitCount + 1
                end
            end
            M.AddLog(string.format("[%s] 命中%d个目标", d.tech.name, hitCount))
        end
    end

    if prog >= 1 then
        -- 清理回合制武技特效
        for i = #activeSkillEffects, 1, -1 do
            if activeSkillEffects[i]._tbSkillEffect then
                table.remove(activeSkillEffects, i)
            end
        end
        tbState.animState = "idle"
        tbState.animData = nil
        M.CheckBattleEnd()
    end
end

-- ============================================================================
-- 自动战斗: 玩家AI自动执行回合
-- ============================================================================
function M.ExecutePlayerAutoBattle()
    if tbState.battleOver then return end
    if not tbState.isPlayerTurn then return end

    -- 先将状态设为 idle 以通过检查
    tbState.animState = "idle"

    if tbState.ap <= 0 then
        M.EndTurn()
        return
    end

    -- 找一个未行动的存活我方军团
    local chosen = nil
    local chosenIdx = nil
    for i, r in ipairs(tbState.playerRegiments) do
        if r.alive and not tbState.usedRegiments[r.id] then
            chosen = r; chosenIdx = i; break
        end
    end

    if not chosen then
        M.EndTurn()
        return
    end

    -- AI 策略: 优先攻击 > 移动靠近
    -- 1) 检查能否攻击 (前方列, 同行)
    local atkR = chosen.atkRange
    local bestTarget = nil
    local bestTargetCol = nil
    for dc = 1, atkR do
        local tc = chosen.col + dc  -- 玩家向右攻击
        if tc >= 1 and tc <= TB_COLS then
            for _, en in ipairs(tbState.enemyRegiments) do
                if en.alive and en.col == tc and en.row == chosen.row then
                    bestTarget = en
                    bestTargetCol = tc
                    break
                end
            end
        end
        if bestTarget then break end
    end

    if bestTarget then
        -- 攻击
        tbState.ap = tbState.ap - 1
        tbState.usedRegiments[chosen.id] = true
        chosen.acted = true
        local targets = { bestTarget }
        local fromX, fromY = chosen.screenX, chosen.screenY
        local toX, toY = M.GridToScreen(bestTarget.row, bestTargetCol)
        tbState.animState = "attacking"
        tbState.animData = {
            reg = chosen, targets = targets,
            fromX = fromX, fromY = fromY, toX = toX, toY = toY,
            timer = 0, duration = 0.5, damaged = false,
        }
        tbState.selectedIdx = nil
        tbState.moveTargets = {}
        tbState.attackTargets = {}
        M.AddLog(chosen.heroName .. " (自动)发起攻击!")
        return
    end

    -- 2) 移动靠近最近的敌方单位
    M.CalcMoveTargets(chosen)
    local bestMove = nil
    local bestDist = 999
    for _, mt in ipairs(tbState.moveTargets) do
        for _, en in ipairs(tbState.enemyRegiments) do
            if en.alive then
                local dist = math.abs(mt.col - en.col) + math.abs(mt.row - en.row)
                if dist < bestDist then
                    bestDist = dist
                    bestMove = mt
                end
            end
        end
    end

    if bestMove then
        tbState.ap = tbState.ap - 1
        tbState.usedRegiments[chosen.id] = true
        chosen.acted = true
        local fromX, fromY = chosen.screenX, chosen.screenY
        local toX, toY = M.GridToScreen(bestMove.row, bestMove.col)
        tbState.animState = "moving"
        tbState.animData = {
            reg = chosen,
            fromX = fromX, fromY = fromY,
            toX = toX, toY = toY,
            toRow = bestMove.row, toCol = bestMove.col,
            timer = 0, duration = 0.3,
        }
        tbState.selectedIdx = nil
        tbState.moveTargets = {}
        tbState.attackTargets = {}
        M.AddLog(chosen.heroName .. " (自动)移动")
        return
    end

    -- 无法行动
    tbState.usedRegiments[chosen.id] = true
    chosen.acted = true
    tbState.ap = tbState.ap - 1
    tbState.animState = "auto_player"
    tbState.animTimer = 0.2
end

return M
