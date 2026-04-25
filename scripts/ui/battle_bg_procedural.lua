-- ============================================================================
-- battle_bg_procedural.lua - Perlin 噪声程序化 2.5D 战斗地图
-- ============================================================================
-- 用 NanoVG 实时绘制程序化地形替代静态背景图
-- 地形类型: 草地、泥土、沙地、丘陵、河流、道路
-- ============================================================================

local Perlin = require("utils.perlin")

local ProceduralBG = {}

-- ============================================================================
-- 地形配置
-- ============================================================================

-- 地形种子 (每场战斗随机)
local _seed = 0
local _terrainCache = nil   -- 缓存的地形格子数组
local _cachedSeed = -1      -- 上次缓存时的种子

-- 地形网格分辨率 (格子越大越快, 越小越细腻)
local CELL_W = 16           -- 每格宽 16px (1024/16 = 64 列)
local CELL_H = 16           -- 每格高 16px (571/16 ≈ 36 行)
local COLS, ROWS            -- 在 init 时计算

-- 地形色板 (水墨古风色调)
local PALETTE = {
    -- 草地 (深浅两档)
    grassDark  = { 48, 72, 38 },
    grassLight = { 68, 95, 52 },
    -- 泥土/黄土
    dirtDark   = { 92, 72, 48 },
    dirtLight  = { 115, 92, 62 },
    -- 沙地
    sandDark   = { 140, 120, 80 },
    sandLight  = { 165, 145, 98 },
    -- 水/河流
    waterDeep  = { 30, 55, 80 },
    waterShallow = { 50, 80, 110 },
    -- 岩石/山丘
    rockDark   = { 60, 58, 55 },
    rockLight  = { 85, 82, 78 },
    -- 道路 (兵道)
    road       = { 100, 88, 68 },
    roadEdge   = { 80, 70, 55 },
}

-- 地形类型常量
local T_GRASS   = 1
local T_DIRT    = 2
local T_SAND    = 3
local T_WATER   = 4
local T_ROCK    = 5
local T_ROAD    = 6

-- ============================================================================
-- 初始化
-- ============================================================================

--- 设置新种子 (每场战斗调用一次)
---@param seed number|nil
function ProceduralBG.SetSeed(seed)
    _seed = seed or math.floor(math.random() * 100000)
    _terrainCache = nil
    _cachedSeed = -1
end

--- 获取当前种子
function ProceduralBG.GetSeed()
    return _seed
end

-- ============================================================================
-- 地形生成
-- ============================================================================

--- 生成地形网格 (只在种子改变时重新计算)
---@param w number 设计宽度
---@param h number 设计高度
local function GenerateTerrain(w, h)
    if _cachedSeed == _seed and _terrainCache then
        return _terrainCache
    end

    COLS = math.ceil(w / CELL_W)
    ROWS = math.ceil(h / CELL_H)

    local grid = {}
    local sx = _seed * 0.137   -- 种子偏移, 避免每场都一样
    local sy = _seed * 0.291

    for row = 1, ROWS do
        grid[row] = {}
        for col = 1, COLS do
            local nx = (col - 1) / COLS
            local ny = (row - 1) / ROWS

            -- 多层噪声
            local elevation  = Perlin.fbm(nx + sx, ny + sy, 4, 0.5, 2.0, 0.25)    -- 海拔
            local moisture   = Perlin.fbm(nx + sx + 50, ny + sy + 50, 3, 0.5, 2.0, 0.3) -- 湿度
            local detail     = Perlin.fbm(nx + sx + 100, ny + sy + 100, 2, 0.4, 2.5, 0.15) -- 细节

            -- 确定地形类型
            local terrainType = T_GRASS
            local shade = 0.5 + detail * 0.3   -- 明暗变化

            -- 高海拔 → 岩石/山丘
            if elevation > 0.45 then
                terrainType = T_ROCK
                shade = 0.4 + (elevation - 0.45) * 1.5
            -- 低海拔 + 高湿度 → 水域
            elseif elevation < -0.35 and moisture > 0.1 then
                terrainType = T_WATER
                shade = 0.5 + moisture * 0.3
            -- 干燥区 → 沙地
            elseif moisture < -0.3 then
                terrainType = T_SAND
                shade = 0.5 + detail * 0.25
            -- 中等湿度偏低 → 泥土
            elseif moisture < -0.05 and elevation < 0.15 then
                terrainType = T_DIRT
                shade = 0.5 + detail * 0.2
            else
                -- 草地
                terrainType = T_GRASS
                shade = 0.5 + detail * 0.25
            end

            -- 中间行军道路 (战场中部横向道路带)
            local centerY = ROWS / 2
            local roadDist = math.abs(row - centerY) / ROWS
            if roadDist < 0.06 and terrainType ~= T_WATER then
                terrainType = T_ROAD
                shade = 0.5 + detail * 0.15
            end

            -- 边界渐暗 (边缘区域略暗, 视觉引导)
            local edgeFadeX = math.min(col - 1, COLS - col) / (COLS * 0.15)
            local edgeFadeY = math.min(row - 1, ROWS - row) / (ROWS * 0.15)
            local edgeFade = math.min(1, math.min(edgeFadeX, edgeFadeY))
            shade = shade * (0.6 + 0.4 * edgeFade)

            shade = math.max(0, math.min(1, shade))

            grid[row][col] = {
                t = terrainType,
                s = shade,
                e = elevation,       -- 用于 2.5D 阴影
                m = moisture,
            }
        end
    end

    _terrainCache = grid
    _cachedSeed = _seed
    return grid
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 根据地形类型和明暗获取颜色
---@param terrainType integer
---@param shade number 0~1
---@return integer r, integer g, integer b
local function GetTerrainColor(terrainType, shade)
    local dark, light
    if terrainType == T_GRASS then
        dark = PALETTE.grassDark; light = PALETTE.grassLight
    elseif terrainType == T_DIRT then
        dark = PALETTE.dirtDark; light = PALETTE.dirtLight
    elseif terrainType == T_SAND then
        dark = PALETTE.sandDark; light = PALETTE.sandLight
    elseif terrainType == T_WATER then
        dark = PALETTE.waterDeep; light = PALETTE.waterShallow
    elseif terrainType == T_ROCK then
        dark = PALETTE.rockDark; light = PALETTE.rockLight
    elseif terrainType == T_ROAD then
        dark = PALETTE.roadEdge; light = PALETTE.road
    else
        dark = PALETTE.grassDark; light = PALETTE.grassLight
    end
    local r = math.floor(dark[1] + (light[1] - dark[1]) * shade)
    local g = math.floor(dark[2] + (light[2] - dark[2]) * shade)
    local b = math.floor(dark[3] + (light[3] - dark[3]) * shade)
    return r, g, b
end

--- 绘制程序化地形背景 (在 NanoVG frame 内调用)
---@param vgCtx any NanoVG context
---@param w number 设计宽度 (DESIGN_W)
---@param h number 设计高度 (DESIGN_H)
---@param gameTime number 游戏时间 (用于水面动画)
function ProceduralBG.Draw(vgCtx, w, h, gameTime)
    local grid = GenerateTerrain(w, h)
    gameTime = gameTime or 0

    -- ========== 第 1 层: 地形基色 ==========
    for row = 1, ROWS do
        for col = 1, COLS do
            local cell = grid[row][col]
            local x = (col - 1) * CELL_W
            local y = (row - 1) * CELL_H

            local shade = cell.s

            -- 水面动画: 波光闪烁
            if cell.t == T_WATER then
                local wave = math.sin(gameTime * 2.0 + col * 0.5 + row * 0.3) * 0.1
                shade = math.max(0, math.min(1, shade + wave))
            end

            local r, g, b = GetTerrainColor(cell.t, shade)
            nvgBeginPath(vgCtx); nvgRect(vgCtx, x, y, CELL_W + 1, CELL_H + 1)
            nvgFillColor(vgCtx, nvgRGBA(r, g, b, 255)); nvgFill(vgCtx)
        end
    end

    -- ========== 第 2 层: 2.5D 丘陵阴影 (高海拔区域底部加暗影) ==========
    for row = 2, ROWS do
        for col = 1, COLS do
            local cell = grid[row][col]
            local above = grid[row - 1] and grid[row - 1][col]
            if above and above.e > 0.2 and cell.e <= 0.2 then
                -- 高处到低处的过渡 → 底部阴影
                local shadowAlpha = math.floor(math.min(80, (above.e - 0.2) * 200))
                local x = (col - 1) * CELL_W
                local y = (row - 1) * CELL_H
                local shadowGrad = nvgLinearGradient(vgCtx, x, y, x, y + CELL_H,
                    nvgRGBA(0, 0, 0, shadowAlpha), nvgRGBA(0, 0, 0, 0))
                nvgBeginPath(vgCtx); nvgRect(vgCtx, x, y, CELL_W + 1, CELL_H * 0.7)
                nvgFillPaint(vgCtx, shadowGrad); nvgFill(vgCtx)
            end
        end
    end

    -- ========== 第 3 层: 丘陵高光 (高海拔区域顶部加亮光) ==========
    for row = 1, ROWS - 1 do
        for col = 1, COLS do
            local cell = grid[row][col]
            local below = grid[row + 1] and grid[row + 1][col]
            if cell.e > 0.25 and below and below.e <= 0.25 then
                -- 高处顶部 → 日照高光
                local hlAlpha = math.floor(math.min(50, (cell.e - 0.25) * 150))
                local x = (col - 1) * CELL_W
                local y = (row - 1) * CELL_H
                nvgBeginPath(vgCtx); nvgRect(vgCtx, x, y + CELL_H * 0.3, CELL_W + 1, CELL_H * 0.5)
                nvgFillColor(vgCtx, nvgRGBA(255, 240, 200, hlAlpha)); nvgFill(vgCtx)
            end
        end
    end

    -- ========== 第 4 层: 草地纹理点 (低密度随机噪点模拟草叶) ==========
    for row = 1, ROWS, 2 do
        for col = 1, COLS, 2 do
            local cell = grid[row][col]
            if cell.t == T_GRASS and cell.e > -0.1 then
                local gx = (col - 1) * CELL_W + Perlin.noise2d(col * 3.7 + _seed, row * 3.7) * CELL_W * 0.6
                local gy = (row - 1) * CELL_H + Perlin.noise2d(col * 4.1, row * 4.1 + _seed) * CELL_H * 0.6
                local gAlpha = math.floor(30 + cell.s * 30)
                nvgBeginPath(vgCtx); nvgCircle(vgCtx, gx, gy, 1.0 + cell.s * 0.5)
                nvgFillColor(vgCtx, nvgRGBA(40, 80, 30, gAlpha)); nvgFill(vgCtx)
            end
        end
    end

    -- ========== 第 5 层: 水面波纹 ==========
    for row = 1, ROWS do
        for col = 1, COLS, 3 do
            local cell = grid[row][col]
            if cell.t == T_WATER then
                local wx = (col - 1) * CELL_W + CELL_W * 0.5
                local wy = (row - 1) * CELL_H + CELL_H * 0.5
                local wavePhase = gameTime * 1.5 + col * 0.8 + row * 0.6
                local waveR = 3 + math.sin(wavePhase) * 2
                local waveA = math.floor(20 + math.sin(wavePhase + 1) * 12)
                nvgBeginPath(vgCtx); nvgCircle(vgCtx, wx, wy, waveR)
                nvgStrokeColor(vgCtx, nvgRGBA(120, 160, 200, waveA))
                nvgStrokeWidth(vgCtx, 0.5); nvgStroke(vgCtx)
            end
        end
    end

    -- ========== 第 6 层: 道路车辙纹 ==========
    local roadCenterRow = math.floor(ROWS / 2)
    for col = 1, COLS - 1, 2 do
        local cell = grid[roadCenterRow][col]
        if cell.t == T_ROAD then
            local rx1 = (col - 1) * CELL_W
            local rx2 = (col + 1) * CELL_W
            local ry = (roadCenterRow - 1) * CELL_H + CELL_H * 0.5
            local wobble = Perlin.noise2d(col * 2 + _seed * 0.1, roadCenterRow) * 3
            nvgBeginPath(vgCtx)
            nvgMoveTo(vgCtx, rx1, ry + wobble - 2)
            nvgLineTo(vgCtx, rx2, ry + Perlin.noise2d((col + 2) * 2 + _seed * 0.1, roadCenterRow) * 3 - 2)
            nvgStrokeColor(vgCtx, nvgRGBA(70, 60, 45, 40))
            nvgStrokeWidth(vgCtx, 0.8); nvgStroke(vgCtx)
            -- 第二条车辙
            nvgBeginPath(vgCtx)
            nvgMoveTo(vgCtx, rx1, ry + wobble + 2)
            nvgLineTo(vgCtx, rx2, ry + Perlin.noise2d((col + 2) * 2 + _seed * 0.1, roadCenterRow + 5) * 3 + 2)
            nvgStrokeColor(vgCtx, nvgRGBA(70, 60, 45, 35))
            nvgStrokeWidth(vgCtx, 0.6); nvgStroke(vgCtx)
        end
    end

    -- ========== 第 7 层: 水墨风雾气叠加 (整体氛围) ==========
    local fogAlpha = math.floor(12 + math.sin(gameTime * 0.3) * 5)
    local fogGrad = nvgLinearGradient(vgCtx, 0, 0, 0, h,
        nvgRGBA(180, 190, 170, fogAlpha),
        nvgRGBA(120, 130, 110, math.floor(fogAlpha * 0.5)))
    nvgBeginPath(vgCtx); nvgRect(vgCtx, 0, 0, w, h)
    nvgFillPaint(vgCtx, fogGrad); nvgFill(vgCtx)
end

return ProceduralBG
