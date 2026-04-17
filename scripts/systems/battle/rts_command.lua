-- ============================================================================
-- systems/battle/rts_command.lua - RTS 指令系统
-- 三国武灵录 - 红警式兵种操控
-- ============================================================================

-- ============================================================================
-- 全局状态
-- ============================================================================

---@class RTSState
rtsState = rtsState or {
    --- 当前选中的兵种 classId (nil=未选择)
    selectedClassId = nil,
    --- 当前激活的指令类型: "move"|"attack"|"defend"|nil
    activeCmd = nil,
    --- 指令目标点 (设计坐标)
    cmdTargetX = nil,
    cmdTargetY = nil,
    --- 是否显示指令目标标记
    showCmdMarker = false,
    cmdMarkerTimer = 0,
    --- 底部兵种栏数据 (动态生成)
    classBar = {},
    --- 指令按钮定义
    cmdButtons = {},
    --- 拖拽/点击状态
    isCmdDrag = false,
    cmdDragStartX = nil,
    cmdDragStartY = nil,
}

-- ============================================================================
-- 指令类型定义
-- ============================================================================

--- 指令颜色映射
RTS_CMD_COLORS = {
    advance = { 255, 255, 255 },   -- 白色(默认前进)
    move    = { 80, 220, 120 },    -- 绿色
    attack  = { 255, 80, 60 },     -- 红色
    defend  = { 80, 140, 255 },    -- 蓝色
}

--- 指令中文名
RTS_CMD_NAMES = {
    advance = "前进",
    move    = "移动",
    attack  = "进攻",
    defend  = "防守",
}

--- 指令图标 IMG 键名
RTS_CMD_ICONS = {
    move    = "slgIconSword",   -- 移动 (用剑图标)
    attack  = "slgIconSword",   -- 进攻
    defend  = "slgIconShield",  -- 防守
}

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化 RTS 指令系统 (战斗开始时调用)
function InitRTS()
    rtsState.selectedClassId = nil
    rtsState.activeCmd = nil
    rtsState.cmdTargetX = nil
    rtsState.cmdTargetY = nil
    rtsState.showCmdMarker = false
    rtsState.cmdMarkerTimer = 0
    rtsState.isCmdDrag = false

    -- 构建兵种快捷栏: 统计玩家场上有哪些兵种
    RebuildClassBar()

    print("[RTS] 指令系统初始化完成")
end

--- 重新构建底部兵种栏 (当部队变化时调用)
function RebuildClassBar()
    local classCounts = {}
    local classOrder = {}

    for _, u in ipairs(playerUnits) do
        if u.alive and u.unitClass then
            local cid = u.unitClass.id
            if not classCounts[cid] then
                classCounts[cid] = 0
                table.insert(classOrder, cid)
            end
            classCounts[cid] = classCounts[cid] + 1
        end
    end

    rtsState.classBar = {}
    for _, cid in ipairs(classOrder) do
        local uc = nil
        -- 查找 UNIT_CLASS 表中对应的定义
        for _, def in pairs(UNIT_CLASS) do
            if def.id == cid then uc = def; break end
        end
        if uc then
            table.insert(rtsState.classBar, {
                classId = cid,
                name = uc.name,
                sprite = uc.sprite,
                count = classCounts[cid],
                unitClass = uc,
            })
        end
    end
end

-- ============================================================================
-- 指令下达
-- ============================================================================

--- 选择/取消选择兵种
function ToggleClassSelection(classId)
    if rtsState.selectedClassId == classId then
        -- 再次点击取消选择
        rtsState.selectedClassId = nil
        rtsState.activeCmd = nil
        print("[RTS] 取消选择兵种")
    else
        rtsState.selectedClassId = classId
        -- 默认不激活任何指令，等玩家点指令按钮
        rtsState.activeCmd = nil
        local uc = nil
        for _, def in pairs(UNIT_CLASS) do
            if def.id == classId then uc = def; break end
        end
        print("[RTS] 选中兵种: " .. (uc and uc.name or "?") .. " (id=" .. classId .. ")")
    end
end

--- 激活指令模式
function ActivateCommand(cmdType)
    if not rtsState.selectedClassId then
        -- 没有选中兵种时，对全体发令
        print("[RTS] 全体指令: " .. cmdType)
    end
    rtsState.activeCmd = cmdType
    print("[RTS] 激活指令: " .. (RTS_CMD_NAMES[cmdType] or cmdType))
end

--- 下达指令到目标点 (核心函数)
--- @param cmdType string "move"|"attack"|"defend"
--- @param tx number 目标X(设计坐标)
--- @param ty number 目标Y(设计坐标)
function IssueCommand(cmdType, tx, ty)
    local classId = rtsState.selectedClassId
    local affected = 0

    -- 限制目标点在战区内
    local bz = BATTLE_ZONE
    tx = math.max(bz.playerLine, math.min(bz.enemyLine, tx))
    ty = math.max(bz.top + 10, math.min(bz.bottom - 10, ty))

    for _, u in ipairs(playerUnits) do
        if u.alive then
            local match = false
            if classId == nil then
                -- 未选择兵种 → 全体
                match = true
            elseif u.unitClass and u.unitClass.id == classId then
                match = true
            end

            if match then
                u.cmdType = cmdType
                -- 为每个单位添加微小偏移，防止扎堆
                local offsetX = (math.random() - 0.5) * 30
                local offsetY = (math.random() - 0.5) * 30
                u.cmdTarget = {
                    x = math.max(bz.playerLine, math.min(bz.enemyLine, tx + offsetX)),
                    y = math.max(bz.top + 10, math.min(bz.bottom - 10, ty + offsetY)),
                }
                u.cmdDone = false
                affected = affected + 1
            end
        end
    end

    -- 显示指令标记
    rtsState.cmdTargetX = tx
    rtsState.cmdTargetY = ty
    rtsState.showCmdMarker = true
    rtsState.cmdMarkerTimer = 1.5  -- 1.5秒后消失

    -- 记录最后下达的指令类型(用于标记颜色)
    rtsState._lastCmd = cmdType
    -- 指令下达后清除激活状态(一次性)
    rtsState.activeCmd = nil

    local cmdName = RTS_CMD_NAMES[cmdType] or cmdType
    local cmdColor = RTS_CMD_COLORS[cmdType] or { 255, 255, 255 }
    local className = "全体"
    if classId then
        for _, def in pairs(UNIT_CLASS) do
            if def.id == classId then className = def.name; break end
        end
    end

    AddFloatText(tx, ty - 20, className .. " " .. cmdName .. "!", 1.0, cmdColor, 16)
    print("[RTS] 下达指令: " .. className .. " " .. cmdName .. " → (" .. math.floor(tx) .. "," .. math.floor(ty) .. ") 影响" .. affected .. "个单位")
end

--- 取消当前兵种的指令，恢复默认前进
function CancelCommand()
    local classId = rtsState.selectedClassId
    local affected = 0

    for _, u in ipairs(playerUnits) do
        if u.alive then
            local match = (classId == nil) or (u.unitClass and u.unitClass.id == classId)
            if match then
                u.cmdType = "advance"
                u.cmdTarget = nil
                u.cmdDone = false
                affected = affected + 1
            end
        end
    end

    rtsState.activeCmd = nil
    rtsState.showCmdMarker = false

    print("[RTS] 取消指令，" .. affected .. "个单位恢复前进")
end

-- ============================================================================
-- 指令标记更新 (在 UpdateBattle 中调用)
-- ============================================================================

function UpdateRTSMarker(dt)
    if rtsState.showCmdMarker then
        rtsState.cmdMarkerTimer = rtsState.cmdMarkerTimer - dt
        if rtsState.cmdMarkerTimer <= 0 then
            rtsState.showCmdMarker = false
        end
    end

    -- 定期刷新兵种栏计数
    rtsState._refreshTimer = (rtsState._refreshTimer or 0) + dt
    if rtsState._refreshTimer > 1.0 then
        rtsState._refreshTimer = 0
        RebuildClassBar()
    end
end

-- ============================================================================
-- 单位指令响应 (在 UpdateUnits 中调用)
-- ============================================================================

--- 执行单位的RTS指令，返回 true 表示指令已接管移动/行为
--- @param u table 单位
--- @param dt number 帧时间
--- @param targets table 敌方单位列表
--- @param isPlayerSide boolean
--- @return boolean 是否接管了默认行为
function ExecuteUnitCommand(u, dt, targets, isPlayerSide)
    -- 只有玩家单位响应指令
    if not isPlayerSide then return false end

    local cmd = u.cmdType
    if not cmd or cmd == "advance" then
        -- 默认前进模式，不接管
        return false
    end

    if cmd == "move" then
        -- ======== 移动指令: 向目标点移动，到达后待命 ========
        if u.cmdTarget and not u.cmdDone then
            local arrived = MoveToTarget(u, dt, u.cmdTarget.x, u.cmdTarget.y)
            if arrived then
                u.cmdDone = true
            end
        end
        -- 到达后原地攻击附近敌人
        if u.cmdDone then
            local nearT, nearD = FindNearbyEnemy(u, targets, u.atkRange)
            if nearT then
                AttackTarget(u, nearT, dt, isPlayerSide)
            end
        end
        return true  -- 接管移动

    elseif cmd == "attack" then
        -- ======== 进攻指令: 向目标点推进，沿途主动攻击所有敌人 ========
        -- 先检查攻击范围内有没有敌人
        local nearT, nearD = FindNearbyEnemy(u, targets, u.atkRange)
        if nearT then
            AttackTarget(u, nearT, dt, isPlayerSide)
        end
        -- 持续向目标点推进
        if u.cmdTarget and not u.cmdDone then
            local arrived = MoveToTarget(u, dt, u.cmdTarget.x, u.cmdTarget.y)
            if arrived then
                u.cmdDone = true
            end
        end
        -- 到达后继续攻击附近敌人（不再移动）
        return true

    elseif cmd == "defend" then
        -- ======== 防守指令: 移动到目标点后驻守，不再前进 ========
        if u.cmdTarget and not u.cmdDone then
            local arrived = MoveToTarget(u, dt, u.cmdTarget.x, u.cmdTarget.y)
            if arrived then
                u.cmdDone = true
            end
        end
        -- 驻守: 攻击范围内的所有敌人（不分前后方）
        local nearT, nearD = FindNearbyEnemy(u, targets, u.atkRange)
        if nearT then
            AttackTarget(u, nearT, dt, isPlayerSide)
        end
        return true  -- 接管移动，不再前进
    end

    return false
end
