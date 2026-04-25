-- ============================================================================
-- systems/td/td_data.lua - 塔防模式数据定义
-- 用途: 常量、波次配置、固定路径点 & 固定塔位(贴合2.5D背景图)
-- ============================================================================
---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 设计分辨率 (与 NanoVG BeginFrame 一致)
-- ============================================================================
M.DESIGN_W = 1024
M.DESIGN_H = 571

-- ============================================================================
-- 地图可用区域 (上方留HUD 36px, 下方留武将栏 78px)
-- ============================================================================
M.MAP_AREA_TOP    = 36
M.MAP_AREA_BOTTOM = 493
M.MAP_AREA_LEFT   = 0
M.MAP_AREA_RIGHT  = 1024

-- ============================================================================
-- 固定路径锚点 (设计坐标, 贴合背景图道路走势)
-- 道路: 从左中进入 → 向右下弯 → 折回向右上 → S形到右上城堡
-- 这些是道路中心线的关键锚点, 敌人沿此路线行军
-- ============================================================================
-- 原始导出锚点 (用户在编辑器中绘制)
-- 引擎会在 GenerateSmoothPath() 中做 Catmull-Rom 插值
-- 为使拐弯更圆滑，在大角度拐弯处插入了辅助控制点

-- 锚点和塔位数据已内嵌在源码中 (通过编辑器导出后固化)

M.PATH_ANCHORS = {
    { x = 102, y = 274 },   -- 入口
    { x = 203, y = 274 },
    { x = 276, y = 249 },
    { x = 336, y = 218 },
    { x = 389, y = 191 },
    { x = 433, y = 187 },
    -- 弯道: 从右上折向右下 (插入辅助点使弯道更圆滑)
    { x = 465, y = 200 },
    { x = 487, y = 225 },
    { x = 496, y = 262 },
    -- 弯道: 折向左下 (插入辅助点)
    { x = 468, y = 284 },
    { x = 436, y = 301 },
    { x = 413, y = 332 },
    { x = 413, y = 350 },
    -- 弯道: 折向右下 (插入辅助点)
    { x = 424, y = 368 },
    { x = 434, y = 376 },
    { x = 453, y = 381 },
    { x = 482, y = 398 },
    { x = 532, y = 419 },
    { x = 566, y = 414 },
    { x = 598, y = 408 },
    { x = 633, y = 398 },
    -- 弯道: 从右下折向右上 (插入辅助点)
    { x = 658, y = 383 },
    { x = 676, y = 369 },
    { x = 678, y = 349 },
    { x = 674, y = 329 },
    { x = 670, y = 294 },
    -- 终段: 向右到城堡
    { x = 695, y = 270 },
    { x = 732, y = 249 },   -- 终点: 城堡入口
}

-- ============================================================================
-- 固定塔位 (放置武将的位置, 在道路两侧, 贴合背景图草地区域)
-- 每个塔位有唯一 key, 便于逻辑引用
-- ============================================================================
M.TOWER_SLOTS = {
    -- 道路左段两侧
    { key = "A1", x = 130, y = 160 },
    { key = "A2", x = 295, y = 269 },
    { key = "A3", x = 313, y = 181 },
    { key = "A4", x = 350, y = 324 },
    -- 道路中段两侧
    { key = "B1", x = 410, y = 161 },
    { key = "B2", x = 570, y = 458 },
    { key = "B3", x = 645, y = 259 },
    { key = "B4", x = 402, y = 274 },
    -- 道路右段两侧
    { key = "C1", x = 528, y = 209 },
    { key = "C2", x = 650, y = 150 },
    { key = "C3", x = 726, y = 319 },
    { key = "C4", x = 770, y = 175 },
}

-- ============================================================================
-- 路径工具: 生成平滑路径 (在锚点间插值, 生成密集路点供敌人行军)
-- ============================================================================

--- 根据锚点生成平滑路径点 (Catmull-Rom 插值)
--- 返回 { {x=, y=}, ... } 密集点列表
function M.GenerateSmoothPath()
    local anchors = M.PATH_ANCHORS
    if #anchors < 2 then return anchors end

    local points = {}
    local segmentsPerAnchor = 12  -- 每段锚点间插 12 个点 (锚点更密后提高插值精度)

    for i = 1, #anchors - 1 do
        local p0 = anchors[math.max(1, i - 1)]
        local p1 = anchors[i]
        local p2 = anchors[math.min(#anchors, i + 1)]
        local p3 = anchors[math.min(#anchors, i + 2)]

        for s = 0, segmentsPerAnchor - 1 do
            local t = s / segmentsPerAnchor
            local t2 = t * t
            local t3 = t2 * t

            -- Catmull-Rom
            local x = 0.5 * (
                (2 * p1.x) +
                (-p0.x + p2.x) * t +
                (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3
            )
            local y = 0.5 * (
                (2 * p1.y) +
                (-p0.y + p2.y) * t +
                (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3
            )

            points[#points + 1] = { x = x, y = y }
        end
    end
    -- 加最后一个锚点
    local last = anchors[#anchors]
    points[#points + 1] = { x = last.x, y = last.y }

    return points
end

--- 计算路径总长度 (像素)
function M.GetPathLength(pathPoints)
    local len = 0
    for i = 2, #pathPoints do
        local dx = pathPoints[i].x - pathPoints[i-1].x
        local dy = pathPoints[i].y - pathPoints[i-1].y
        len = len + math.sqrt(dx * dx + dy * dy)
    end
    return len
end

--- 根据行进距离获取路径上的位置
--- @param pathPoints table[] 密集路径点
--- @param dist number 已行进距离 (像素)
--- @return number x, number y, boolean arrived
function M.GetPositionOnPath(pathPoints, dist)
    if dist <= 0 then
        return pathPoints[1].x, pathPoints[1].y, false
    end

    local accum = 0
    for i = 2, #pathPoints do
        local dx = pathPoints[i].x - pathPoints[i-1].x
        local dy = pathPoints[i].y - pathPoints[i-1].y
        local segLen = math.sqrt(dx * dx + dy * dy)

        if accum + segLen >= dist then
            local t = (dist - accum) / segLen
            local px = pathPoints[i-1].x + dx * t
            local py = pathPoints[i-1].y + dy * t
            return px, py, false
        end

        accum = accum + segLen
    end

    -- 到达终点
    local last = pathPoints[#pathPoints]
    return last.x, last.y, true
end

-- ============================================================================
-- 兼容旧接口: GridToScreen / ScreenToGrid (转为像素坐标近似)
-- ============================================================================
M.GRID_COLS = 14        -- 保留兼容
M.GRID_ROWS = 7
M.ISO_TILE_W = 64       -- 用于攻击范围计算 (1格≈64px)
M.ISO_TILE_H = 32
M.CELL_W = 64
M.CELL_H = 32

--- 兼容接口: 格子->屏幕 (不再真正使用, 仅兼容旧逻辑引用)
function M.GridToScreen(col, row)
    -- 近似: 把 14x7 格子均匀铺在地图区域
    local cellW = (M.MAP_AREA_RIGHT - M.MAP_AREA_LEFT) / M.GRID_COLS
    local cellH = (M.MAP_AREA_BOTTOM - M.MAP_AREA_TOP) / M.GRID_ROWS
    local sx = M.MAP_AREA_LEFT + (col - 0.5) * cellW
    local sy = M.MAP_AREA_TOP + (row - 0.5) * cellH
    return sx, sy
end

--- 兼容接口: 屏幕->格子
function M.ScreenToGrid(dx, dy)
    local cellW = (M.MAP_AREA_RIGHT - M.MAP_AREA_LEFT) / M.GRID_COLS
    local cellH = (M.MAP_AREA_BOTTOM - M.MAP_AREA_TOP) / M.GRID_ROWS
    local col = math.floor((dx - M.MAP_AREA_LEFT) / cellW) + 1
    local row = math.floor((dy - M.MAP_AREA_TOP) / cellH) + 1
    col = math.max(1, math.min(M.GRID_COLS, col))
    row = math.max(1, math.min(M.GRID_ROWS, row))
    return col, row
end

-- ============================================================================
-- 军资 & 经济
-- ============================================================================
M.INITIAL_GOLD       = 300
M.KILL_GOLD_BASE     = 2       -- 降低单只金币(10倍量)
M.KILL_GOLD_ELITE    = 15
M.WAVE_BONUS_GOLD    = 50
M.PASSIVE_GOLD_RATE  = 3
M.PASSIVE_GOLD_INTERVAL = 2

M.HERO_COST = {
    [1] = 80,
    [2] = 140,
    [3] = 220,
    [4] = 350,
    [5] = 450,
}

-- ============================================================================
-- 武将升级
-- ============================================================================
M.UPGRADE_COST = { 80, 160, 300, 500 }  -- Lv1→2, Lv2→3, Lv3→4, Lv4→5
M.UPGRADE_MULT = {
    [1] = 1.0,
    [2] = 1.3,
    [3] = 1.7,
    [4] = 2.2,
    [5] = 2.8,
}

-- ============================================================================
-- 能量系统
-- ============================================================================
M.ENERGY_MAX      = 100
M.ENERGY_PER_HIT  = 1     -- 每次命中+1
M.ENERGY_PER_KILL = 5     -- 每次击杀+5
M.ENERGY_PASSIVE  = 0.5   -- 每秒被动+0.5

-- ============================================================================
-- 兵种差异化 (乘数, 基于 ENEMY_BASE_* 计算最终值)
-- ============================================================================
M.ENEMY_TYPE_STATS = {
    infantry = { hpMul = 1.5, atkMul = 1.0, defMul = 1.0, spdMul = 0.75, canRangeAtk = false, label = "步兵" },
    archer   = { hpMul = 0.6, atkMul = 1.2, defMul = 0.6, spdMul = 1.0,  canRangeAtk = true, atkRange = 100, atkCd = 2.0, label = "弓兵" },
    cavalry  = { hpMul = 1.0, atkMul = 1.0, defMul = 0.8, spdMul = 1.6,  canRangeAtk = false, label = "骑兵" },
    spear    = { hpMul = 1.2, atkMul = 0.8, defMul = 1.5, spdMul = 0.9,  canRangeAtk = false, label = "枪兵" },
}

-- ============================================================================
-- 技能定义
-- ============================================================================
M.SKILL_DEFS = {
    [1] = { id = "sword",   name = "飞剑",  energyCost = 25, cd = 3,  needTarget = false, desc = "沿路径反向飞行AOE" },
    [2] = { id = "fire",    name = "天火",  energyCost = 40, cd = 8,  needTarget = true,  radius = 80, damage = 120, desc = "大范围火伤" },
    [3] = { id = "frost",   name = "冰霜",  energyCost = 30, cd = 10, needTarget = false, slowMul = 0.4, duration = 3.0, desc = "全场减速3s" },
    [4] = { id = "heal",    name = "春风",  energyCost = 35, cd = 12, needTarget = false, healPct = 0.3, desc = "回复全体武将30%HP" },
    [5] = { id = "thunder", name = "雷霆",  energyCost = 50, cd = 15, needTarget = true,  radius = 60, damage = 200, stunDur = 1.0, desc = "闪电+眩晕1s" },
}

-- ============================================================================
-- 波次配置
-- ============================================================================
M.WAVE_INTERVAL     = 18
M.FIRST_WAVE_DELAY  = 8
M.SPAWN_INTERVAL    = 0.08   -- 加快出兵间隔(原0.15)

M.ENEMY_BASE_HP  = 60     -- 降低单体血量(原350), 配合10倍数量
M.ENEMY_BASE_ATK = 8      -- 降低攻击(原25)
M.ENEMY_BASE_DEF = 3      -- 降低防御(原10)
M.ENEMY_BASE_SPEED = 55   -- 像素/秒 (路径更长, 速度适当提高)

M.LEVEL_SCALE_HP   = 1.35   -- 每关HP ×1.35 (难度递增更明显)
M.LEVEL_SCALE_ATK  = 1.20   -- 每关ATK ×1.20
M.LEVEL_SCALE_DEF  = 1.15   -- 每关DEF ×1.15
M.LEVEL_SCALE_SPD  = 1.05   -- 每关速度 ×1.05 (新增: 越来越快)
M.LEVEL_SCALE_COUNT = 25    -- 每级递增敌人数量

M.WAVES_PER_LEVEL = 8

--- 生成一关的波次数据 (10倍扩容, 兵种差异化)
function M.GenerateWaves(level)
    local waves = {}
    local hpScale  = M.LEVEL_SCALE_HP  ^ (level - 1)
    local atkScale = M.LEVEL_SCALE_ATK ^ (level - 1)
    local defScale = M.LEVEL_SCALE_DEF ^ (level - 1)
    local spdScale = M.LEVEL_SCALE_SPD ^ (level - 1)     -- 速度递增
    local baseCount = 80 + math.min(level - 1, 10) * M.LEVEL_SCALE_COUNT  -- 第1关80只

    local troopKeys = { "infantry", "archer", "cavalry", "spear" }

    for w = 1, M.WAVES_PER_LEVEL do
        local count = baseCount + math.floor(w / 3) * 5
        local isElite = (w == M.WAVES_PER_LEVEL)
        local waveEnemies = {}

        for i = 1, count do
            local troop = troopKeys[((i - 1) % #troopKeys) + 1]
            local elite = isElite and (i <= 3)
            local eliteHpMul = elite and 4.0 or 1.0
            local eliteAtkMul = elite and 2.5 or 1.0

            -- 应用兵种差异化
            local ts = M.ENEMY_TYPE_STATS[troop]
            waveEnemies[#waveEnemies + 1] = {
                troop = troop,
                hp    = math.floor(M.ENEMY_BASE_HP * hpScale * eliteHpMul * ts.hpMul * (0.9 + w * 0.05)),
                maxHp = math.floor(M.ENEMY_BASE_HP * hpScale * eliteHpMul * ts.hpMul * (0.9 + w * 0.05)),
                atk   = math.floor(M.ENEMY_BASE_ATK * atkScale * eliteAtkMul * ts.atkMul),
                def   = math.floor(M.ENEMY_BASE_DEF * defScale * ts.defMul),
                speed = M.ENEMY_BASE_SPEED * spdScale * ts.spdMul,
                elite = elite,
                -- 弓兵远程攻击武将的属性
                canRangeAtk = ts.canRangeAtk,
                atkRange = ts.atkRange,
                atkCd = ts.atkCd,
            }
        end

        waves[#waves + 1] = {
            enemies = waveEnemies,
            delay = (w == 1) and M.FIRST_WAVE_DELAY or M.WAVE_INTERVAL,
        }
    end

    return waves
end

-- ============================================================================
-- 旧路径生成 (保留兼容但不再使用, 用 GenerateSmoothPath 代替)
-- ============================================================================
function M.GeneratePath(cols, rows)
    -- 不再使用随机路径, 返回固定锚点的 col/row 近似
    -- 这个函数被 td_logic 调用, 需要返回 {col=, row=} 格式
    -- 但我们现在改用像素路径, 所以这里返回锚点转换后的近似值
    local path = {}
    for _, a in ipairs(M.PATH_ANCHORS) do
        local col, row = M.ScreenToGrid(a.x, a.y)
        -- 去重
        if #path == 0 or path[#path].col ~= col or path[#path].row ~= row then
            path[#path + 1] = { col = col, row = row }
        end
    end
    return path
end

--- 获取路径上某个位置的可放置点 (现在使用固定塔位)
function M.GetPlaceableSlots(path, cols, rows)
    local placeable = {}
    for _, slot in ipairs(M.TOWER_SLOTS) do
        placeable[slot.key] = true
    end
    return placeable
end

--- 通过 key 获取塔位坐标
function M.GetSlotPosition(key)
    for _, slot in ipairs(M.TOWER_SLOTS) do
        if slot.key == key then
            return slot.x, slot.y
        end
    end
    return nil, nil
end

--- 根据屏幕坐标找最近的空塔位 (点击放置用)
function M.FindNearestSlot(px, py, maxDist)
    maxDist = maxDist or 50
    local bestKey = nil
    local bestDist = maxDist

    for _, slot in ipairs(M.TOWER_SLOTS) do
        local dx = px - slot.x
        local dy = py - slot.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < bestDist then
            bestDist = dist
            bestKey = slot.key
        end
    end

    return bestKey, bestDist
end

-- ============================================================================
-- 云端存取: 路径锚点 & 塔位配置
-- 云端 key: "td_map_anchors" (JSON array of {x,y})
--           "td_map_slots"   (JSON array of {key,x,y})
-- ============================================================================

local cjson_mod = rawget(_G, "cjson") or nil

--- 内部: 确保 cjson 可用
local function getCjson()
    if not cjson_mod then cjson_mod = rawget(_G, "cjson") end
    return cjson_mod
end

--- 从云端加载锚点和塔位, 覆盖硬编码默认值
--- @param callback fun(ok: boolean, source: string)|nil  加载完成回调
function M.LoadFromCloud(callback)
    local CA = rawget(_G, "CloudAPI")
    if not CA or not CA.IsReady() then
        -- 云端不可用, 使用本地硬编码
        print("[TDData] 云端不可用, 使用本地默认数据")
        if callback then callback(false, "local") end
        return
    end

    CA.BatchGet()
        :Key("td_map_anchors")
        :Key("td_map_slots")
        :Fetch({
            ok = function(values)
                local cj = getCjson()
                if not cj then
                    print("[TDData] cjson不可用, 使用本地默认数据")
                    if callback then callback(false, "local") end
                    return
                end

                local loaded = false

                -- 解析锚点
                local anchorsStr = values and values["td_map_anchors"]
                if anchorsStr and type(anchorsStr) == "string" and #anchorsStr > 2 then
                    local ok, arr = pcall(cj.decode, anchorsStr)
                    if ok and type(arr) == "table" and #arr >= 2 then
                        M.PATH_ANCHORS = {}
                        for i, a in ipairs(arr) do
                            M.PATH_ANCHORS[i] = { x = tonumber(a.x) or 0, y = tonumber(a.y) or 0 }
                        end
                        loaded = true
                        print("[TDData] 云端加载锚点: " .. #M.PATH_ANCHORS .. " 个")
                    end
                end

                -- 解析塔位
                local slotsStr = values and values["td_map_slots"]
                if slotsStr and type(slotsStr) == "string" and #slotsStr > 2 then
                    local ok2, arr2 = pcall(cj.decode, slotsStr)
                    if ok2 and type(arr2) == "table" and #arr2 >= 1 then
                        M.TOWER_SLOTS = {}
                        for i, s in ipairs(arr2) do
                            M.TOWER_SLOTS[i] = { key = tostring(s.key or ("X"..i)), x = tonumber(s.x) or 0, y = tonumber(s.y) or 0 }
                        end
                        loaded = true
                        print("[TDData] 云端加载塔位: " .. #M.TOWER_SLOTS .. " 个")
                    end
                end

                if loaded then
                    if callback then callback(true, "cloud") end
                else
                    print("[TDData] 云端无有效数据, 使用本地默认数据")
                    if callback then callback(false, "local") end
                end
            end,
            error = function(_, reason)
                print("[TDData] 云端加载失败: " .. tostring(reason) .. ", 使用本地默认数据")
                if callback then callback(false, "local") end
            end,
        })
end

--- 将当前锚点和塔位保存到云端
--- @param callback fun(ok: boolean, reason: string|nil)|nil  保存完成回调
function M.SaveToCloud(callback)
    local CA = rawget(_G, "CloudAPI")
    if not CA or not CA.IsReady() then
        print("[TDData] 云端不可用, 跳过云端保存")
        if callback then callback(false, "not_ready") end
        return
    end

    local cj = getCjson()
    if not cj then
        print("[TDData] cjson不可用, 跳过云端保存")
        if callback then callback(false, "no_cjson") end
        return
    end

    -- 序列化锚点
    local anchorsData = {}
    for i, a in ipairs(M.PATH_ANCHORS) do
        anchorsData[i] = { x = math.floor(a.x + 0.5), y = math.floor(a.y + 0.5) }
    end
    local ok1, anchorsJson = pcall(cj.encode, anchorsData)
    if not ok1 then
        print("[TDData] 锚点序列化失败")
        if callback then callback(false, "encode_error") end
        return
    end

    -- 序列化塔位
    local slotsData = {}
    for i, s in ipairs(M.TOWER_SLOTS) do
        slotsData[i] = { key = s.key, x = math.floor(s.x + 0.5), y = math.floor(s.y + 0.5) }
    end
    local ok2, slotsJson = pcall(cj.encode, slotsData)
    if not ok2 then
        print("[TDData] 塔位序列化失败")
        if callback then callback(false, "encode_error") end
        return
    end

    CA.BatchSet()
        :Set("td_map_anchors", anchorsJson)
        :Set("td_map_slots", slotsJson)
        :Save("td_editor_save", {
            ok = function()
                print("[TDData] 云端保存成功 (锚点:" .. #anchorsData .. " 塔位:" .. #slotsData .. ")")
                if callback then callback(true) end
            end,
            error = function(_, reason)
                print("[TDData] 云端保存失败: " .. tostring(reason))
                if callback then callback(false, tostring(reason)) end
            end,
        })
end

-- ============================================================================
-- 武将塔防属性
-- ============================================================================

--- 根据武将卡计算塔防属性 (纯塔防: 武将直接攻击, 无派兵)
function M.GetHeroTDStats(card)
    local quality = card.quality or 1
    local isRanged = (card.unitClass and card.unitClass:find("ARCHER")) and true or false
    return {
        atk = card.atk,
        def = card.def,
        hp  = card.hp,
        maxHP = card.hp,
        atkCd = math.max(1.0, 3.5 - quality * 0.4),
        atkRange = isRanged and 180 or 60,   -- 远程180px, 近战60px
        isRanged = isRanged,
        energyGain = quality,   -- 品质越高每次攻击获得能量越多
        skillCd = (card.skillData and card.skillData.cd or 10) * 5,
    }
end

return M
