-- ============================================================================
-- ui/gm_gesture.lua - GM面板手势检测器
-- 检测: 在任意位置逆时针连续画2圈 → 弹出GM面板
-- ============================================================================
---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 配置
-- ============================================================================
local MIN_SAMPLES       = 12    -- 每圈最少采样点数
local ANGLE_THRESHOLD   = -5.8  -- 约 -330°, 接近一整圈 (弧度, 逆时针为负)
local CIRCLES_NEEDED    = 2     -- 需要画几圈
local TIMEOUT           = 5.0   -- 超时秒数(从第一个采样开始)
local MIN_RADIUS        = 15    -- 最小画圈半径(过滤抖动)

-- ============================================================================
-- 状态
-- ============================================================================
local state = {
    active    = false,   -- 手指在触发区域内按下
    points    = {},      -- 采样点列表 { {x,y}, ... }
    startTime = 0,       -- 开始时间
    circles   = 0,       -- 已完成圈数
    lastAngle = 0,       -- 上一段累积角度
    totalAngle = 0,      -- 当前圈累积角度
}

-- ============================================================================
-- 重置
-- ============================================================================
local function Reset()
    state.active = false
    state.points = {}
    state.startTime = 0
    state.circles = 0
    state.lastAngle = 0
    state.totalAngle = 0
end

-- ============================================================================
-- 计算两个向量的夹角 (带符号, 逆时针为负)
-- ============================================================================
local function SignedAngle(ax, ay, bx, by)
    local cross = ax * by - ay * bx
    local dot   = ax * bx + ay * by
    return math.atan(cross, dot)
end

-- ============================================================================
-- 判断采样点是否构成逆时针圆弧
-- ============================================================================
local function CheckCircle()
    local pts = state.points
    if #pts < MIN_SAMPLES then return false end

    -- 计算质心
    local cx, cy = 0, 0
    for _, p in ipairs(pts) do
        cx = cx + p.x
        cy = cy + p.y
    end
    cx = cx / #pts
    cy = cy / #pts

    -- 检查半径
    local maxR = 0
    for _, p in ipairs(pts) do
        local dx = p.x - cx
        local dy = p.y - cy
        local r = math.sqrt(dx * dx + dy * dy)
        if r > maxR then maxR = r end
    end
    if maxR < MIN_RADIUS then return false end

    -- 计算累积角度变化
    local totalAngle = 0
    for i = 2, #pts do
        local ax = pts[i - 1].x - cx
        local ay = pts[i - 1].y - cy
        local bx = pts[i].x - cx
        local by = pts[i].y - cy
        local lenA = math.sqrt(ax * ax + ay * ay)
        local lenB = math.sqrt(bx * bx + by * by)
        if lenA > 1 and lenB > 1 then
            totalAngle = totalAngle + SignedAngle(ax, ay, bx, by)
        end
    end

    state.totalAngle = totalAngle

    -- 逆时针一整圈约 -2π ≈ -6.28, 阈值设为 -5.8
    if totalAngle < ANGLE_THRESHOLD then
        return true
    end

    return false
end

-- ============================================================================
-- 输入接口
-- ============================================================================

--- 手指/鼠标按下时调用 (设计坐标)
---@param dx number 设计坐标 x
---@param dy number 设计坐标 y
---@return boolean consumed 是否消费了事件
function M.OnPress(dx, dy)
    Reset()
    state.active = true
    state.startTime = os.clock()
    state.points = { { x = dx, y = dy } }
    return false  -- 不消费, 让其他逻辑也能响应
end

--- 手指/鼠标移动时调用 (设计坐标)
---@param dx number 设计坐标 x
---@param dy number 设计坐标 y
---@return boolean triggered 是否触发了GM面板
function M.OnMove(dx, dy)
    if not state.active then return false end

    -- 超时检测
    if os.clock() - state.startTime > TIMEOUT then
        Reset()
        return false
    end

    -- 采样
    state.points[#state.points + 1] = { x = dx, y = dy }

    -- 检测是否完成了一圈
    if CheckCircle() then
        state.circles = state.circles + 1
        -- 重置采样但保留圈数计数
        state.points = { { x = dx, y = dy } }
        state.totalAngle = 0

        if state.circles >= CIRCLES_NEEDED then
            Reset()
            return true  -- 触发!
        end
    end

    return false
end

--- 手指/鼠标松开时调用
function M.OnRelease()
    -- 松开手指不重置, 允许多次触摸完成3圈
    -- 但如果超时则在 OnMove 中自动重置
end

--- 获取当前已完成圈数 (用于可视化反馈)
function M.GetCircleCount()
    if not state.active then return 0 end
    return state.circles
end

--- 是否正在手势中
function M.IsActive()
    return state.active
end

return M
