-- ============================================================================
-- perlin.lua - 纯 Lua Perlin 噪声 (2D)
-- 用于程序化战斗地图生成
-- ============================================================================

local Perlin = {}

-- 预置排列表 (经典 Ken Perlin 排列)
local p = {
    151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,
    140,36,103,30,69,142,8,99,37,240,21,10,23,190,6,148,
    247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,
    57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,
    74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,
    60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,54,
    65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,
    200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,
    52,217,226,250,124,123,5,202,38,147,118,126,255,82,85,212,
    207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,
    119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,
    129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,
    218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,241,
    81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,
    254,157,184,127,157,243,157,176,157,157,157,157,157,157,157,157,
    204,157,157,157,115,157,157,157,157,66,157,157,157,157,157,157,
}

-- 扩展到 512 以支持环绕
local perm = {}
for i = 0, 255 do
    perm[i]       = p[i + 1]
    perm[i + 256] = p[i + 1]
end

-- 渐变向量 (简化为 4 方向, 足够生成自然地形)
local grad2 = {
    {1,1}, {-1,1}, {1,-1}, {-1,-1},
    {1,0}, {-1,0}, {0,1},  {0,-1},
}

local function dot2(g, x, y)
    return g[1] * x + g[2] * y
end

-- 5次 Hermite 平滑曲线 (f(t) = 6t^5 - 15t^4 + 10t^3)
local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local floor = math.floor

--- 2D Perlin 噪声, 返回值约在 [-1, 1]
---@param x number
---@param y number
---@return number
function Perlin.noise2d(x, y)
    -- 单元格坐标
    local xi = floor(x) & 255
    local yi = floor(y) & 255

    -- 单元格内小数部分
    local xf = x - floor(x)
    local yf = y - floor(y)

    -- 平滑插值因子
    local u = fade(xf)
    local v = fade(yf)

    -- 哈希 4 个角
    local aa = perm[perm[xi] + yi]
    local ab = perm[perm[xi] + yi + 1]
    local ba = perm[perm[xi + 1] + yi]
    local bb = perm[perm[xi + 1] + yi + 1]

    -- 梯度选择 (8 方向)
    local ga = grad2[(aa & 7) + 1]
    local gb = grad2[(ab & 7) + 1]
    local gc = grad2[(ba & 7) + 1]
    local gd = grad2[(bb & 7) + 1]

    -- 梯度点积
    local n00 = dot2(ga, xf,     yf)
    local n01 = dot2(gb, xf,     yf - 1)
    local n10 = dot2(gc, xf - 1, yf)
    local n11 = dot2(gd, xf - 1, yf - 1)

    -- 双线性插值
    local nx0 = lerp(n00, n10, u)
    local nx1 = lerp(n01, n11, u)
    return lerp(nx0, nx1, v)
end

--- 分形布朗运动 (多层叠加, 产生自然地形)
---@param x number
---@param y number
---@param octaves integer 叠加层数 (越多越细腻, 越慢)
---@param persistence number 每层振幅衰减 (0.5 较自然)
---@param lacunarity number 每层频率倍增 (2.0 标准)
---@param scale number 基础缩放 (越大地形块越大)
---@return number 返回值约在 [-1, 1]
function Perlin.fbm(x, y, octaves, persistence, lacunarity, scale)
    octaves = octaves or 4
    persistence = persistence or 0.5
    lacunarity = lacunarity or 2.0
    scale = scale or 1.0

    local total = 0
    local amplitude = 1
    local frequency = 1 / scale
    local maxVal = 0

    for _ = 1, octaves do
        total = total + Perlin.noise2d(x * frequency, y * frequency) * amplitude
        maxVal = maxVal + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end

    return total / maxVal  -- 归一化到 [-1, 1]
end

return Perlin
