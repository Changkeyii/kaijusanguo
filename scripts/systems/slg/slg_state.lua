-- ============================================================================
-- slg/slg_state.lua - 三国武灵传：SLG运行时状态管理
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 运行时状态（全局，供所有模块访问）
-- ============================================================================
worldMapState = worldMapState or {
    inited = false,
    turn = 1,
    playerFaction = "wu",
    selectedCity = nil,
    targetCity = nil,
    phase = "MAP",
    turnReport = nil,
    animTimer = 0,
    scrollY = 0,

    cityData = {},
    troops = 200,
    gold = 500,
    food = 300,
    totalTurns = 0,
    affairsCity = nil,

    diplomacy = {},
    searchResult = nil,
    deployHeroes = {},
    deployTroops = 0,

    -- 计略
    stratagemTarget = nil,

    -- 武将管理 / 拜师
    heroManageCity = nil,       -- 当前管理武将的城池ID
    heroTroopChoice = {},       -- [heroIdx] = "cavalry" 玩家选择的兵种
    heroLearnedSkills = {},     -- [heroIdx] = {techIdx=N, teacherIdx=M} 拜师学到的武技
    apprenticeStudent = nil,    -- 当前拜师的学生heroIdx
    apprenticeTeacher = nil,    -- 当前拜师的老师heroIdx
    heroManageScroll = 0,       -- 武将管理面板滚动

    -- UI 动画 / 滚动
    mapPulse = 0,
    reportScroll = 0,
    cloudOffset = 0,
    reportDragging = false,
    reportDragLastY = nil,

    -- 地图平移/缩放
    mapCenterX = 512,       -- 地图视口中心 (地图坐标系 1024×571)
    mapCenterY = 285,
    mapZoom = 1.0,          -- 缩放倍率 (1.0 = 适配整个地图)
    mapDragging = false,    -- 是否正在拖拽
    mapDragMoved = false,   -- 拖拽中是否发生了移动(区分点击和拖拽)
    mapDragLastPX = 0,      -- 上一帧鼠标物理坐标
    mapDragLastPY = 0,
    mapTargetX = nil,       -- 自动平移目标 (nil=无目标)
    mapTargetY = nil,
    mapTargetZoom = nil,    -- 自动缩放目标 (nil=不改变)
    mapAnimTimer = 0,       -- 缩放动画计时器

    -- 武将弹窗
    heroPopup = nil,        -- 弹窗显示的武将索引 (nil=不显示)

    -- 刺探结果
    scoutResult = nil,
}

--- 获取状态引用
function M.Get()
    return worldMapState
end

--- 重置到地图默认视图（不清数据）
function M.ResetView()
    local st = worldMapState
    st.phase = "MAP"
    st.selectedCity = nil
    st.turnReport = nil
    st.scrollY = 0
    st.searchResult = nil
    st.scoutResult = nil
    st.heroManageCity = nil
    st.apprenticeStudent = nil
    st.apprenticeTeacher = nil
    st.heroManageScroll = 0
    st.heroPopup = nil
    st.mapPanelHeroScroll = 0
end

--- 完整重置（新游戏）
function M.FullReset()
    local st = worldMapState
    st.inited = false
    st.turn = 1
    st.gold = 500
    st.food = 300
    st.troops = 200
    st.phase = "MAP"
    st.selectedCity = nil
    st.turnReport = nil
    st.scrollY = 0
    st.cityData = {}
    st.totalTurns = 0
    st.affairsCity = nil
    st.diplomacy = {}
    st.searchResult = nil
    st.deployHeroes = {}
    st.deployTroops = 0
    st.stratagemTarget = nil
    st.heroManageCity = nil
    st.heroTroopChoice = {}
    st.heroLearnedSkills = {}
    st.apprenticeStudent = nil
    st.apprenticeTeacher = nil
    st.heroManageScroll = 0
    st.mapPulse = 0
    st.reportScroll = 0
    st.cloudOffset = 0
    st.mapCenterX = 512
    st.mapCenterY = 285
    st.mapZoom = 1.0
    st.mapDragging = false
    st.mapDragMoved = false
    st.mapTargetX = nil
    st.mapTargetY = nil
    st.mapTargetZoom = nil
    st.heroPopup = nil
    st.scoutResult = nil
    st.mapPanelHeroScroll = 0
end

return M
