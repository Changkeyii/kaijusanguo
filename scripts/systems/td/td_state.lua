-- ============================================================================
-- systems/td/td_state.lua - 塔防模式状态管理
-- 用途: 初始化/重置塔防游戏状态
-- ============================================================================
---@diagnostic disable: undefined-global

local TDData = require("systems.td.td_data")
local TDLogic -- 延迟加载, 避免循环引用

local M = {}

--- 全局塔防状态
---@class TDState
---@field level number 当前关卡
---@field gold number 军资
---@field baseHP number 基地生命
---@field baseMaxHP number 基地最大生命
---@field path table[] 路径格子列表
---@field placeable table<string,boolean> 可放置格子
---@field heroes table[] 已放置的武将
---@field enemies table[] 场上敌人
---@field projectiles table[] 弹道
---@field waves table[] 当前关卡波次
---@field currentWave number 当前波次
---@field waveTimer number 波次计时
---@field spawnQueue table[] 当前波待生成敌人
---@field spawnTimer number 生成计时
---@field gameTime number 游戏时间
---@field paused boolean 暂停
---@field autoBattle boolean 自动战斗
---@field speed number 倍速
---@field phase string 阶段: "PREPARE"/"PLAYING"/"WAVE_CLEAR"/"LEVEL_CLEAR"/"GAME_OVER"
---@field selectedHeroIdx number 选中的预选武将索引 (用于放置)
---@field floatTexts table[] 飘字
---@field particles table[] 粒子
---@field goldTimer number 被动军资计时
---@field roster table[] 预选的8个武将 (cardIdx列表)
---@field rosterCards HeroCardDef[] 预选武将的卡牌数据
---@field placedHeroMap table<string,number> 格子key→heroIdx映射
---@field totalKills number 总击杀
---@field waveEnemiesAlive number 当前波存活敌人
---@field btnRects table UI按钮区域
tdState = nil

--- 初始化塔防状态
---@param roster number[] 预选的8个武将cardIdx
---@param level number 起始关卡
function M.Init(roster, level)
    level = level or 1

    -- 构建花名册卡牌数据
    local rosterCards = {}
    for i, cardIdx in ipairs(roster) do
        if HERO_CARDS[cardIdx] then
            rosterCards[i] = HERO_CARDS[cardIdx]
        end
    end

    tdState = {
        level = level,
        gold = TDData.INITIAL_GOLD,
        baseHP = 20,
        baseMaxHP = 20,
        path = {},            -- 由 InitPathData 填充 (像素坐标)
        placeable = {},       -- 由 InitPathData 填充 (slotKey → true)
        heroes = {},          -- { cardIdx, slotKey, x, y, tdStats, atkTimer, currentHP, maxHP, level, dead, respawnTimer }
        enemies = {},         -- { troop, hp, maxHP, atk, def, speed, travelDist, x, y, elite, dead, atkTimer, slowTimer, stunTimer }
        projectiles = {},
        waves = TDData.GenerateWaves(level),
        currentWave = 0,
        waveTimer = 0,
        spawnQueue = {},
        spawnTimer = 0,
        gameTime = 0,
        paused = false,
        autoBattle = false,
        speed = 1,
        phase = "PREPARE",    -- 开局准备阶段(可放武将)
        selectedHeroIdx = 0,  -- 花名册中选中的武将(1-8)
        floatTexts = {},
        particles = {},
        goldTimer = 0,
        roster = roster,
        rosterCards = rosterCards,
        placedHeroMap = {},   -- slotKey → heroes数组索引
        totalKills = 0,
        waveEnemiesAlive = 0,

        -- UI 按钮区域
        btnRects = {
            back = nil,
            pause = nil,
            speed = nil,
            autoBattle = nil,
            startWave = nil,
            heroSlots = {},   -- 底部8个武将按钮
        },

        -- 技能特效列表
        skillFXList = {},

        -- ========== 能量 & 技能系统 ==========
        totalEnergy = 0,        -- 全局能量池
        skills = {},            -- 5个技能的CD计时器(在Init后填充)
        focusedHeroIdx = 0,     -- 当前聚焦的武将索引(用于升级/重定位)
        repositionMode = false, -- 重定位模式
        targetingSkill = 0,     -- 需要目标的技能索引(>0时点击地图释放技能)

        -- ========== 飞行剑系统 ==========
        -- 全局飞行剑 CD & 状态
        swordCdBase = 8.0,     -- 基础CD (秒)
        swordCdTimer = 4.0,    -- 当前CD计时 (初始50%预热)
        swordDmgBase = 50,     -- 基础伤害
        swordSpeed = 220,      -- 飞行速度 (像素/秒)
        swordRadius = 30,      -- 碰撞半径 (像素)
        flyingSwords = {},     -- 当前飞行中的剑实体列表
        -- 每把剑: { travelDist, dmg, hitSet={}, color, trail={}, active }

        -- 滚动 (底部武将栏)
        heroBarScrollX = 0,

        -- 准备阶段倒计时
        prepareTimer = 0,

        -- smoothPath / pathLength 由 InitPathData 填充
        smoothPath = nil,
        pathLength = 0,
    }

    -- 初始化5个技能CD计时器
    for i = 1, #TDData.SKILL_DEFS do
        tdState.skills[i] = { cdTimer = 0 }
    end

    -- 延迟加载 TDLogic 并初始化路径数据
    if not TDLogic then
        TDLogic = require("systems.td.td_logic")
    end
    TDLogic.InitPathData()

    -- 尝试从云端加载最新路径/塔位配置 (异步, 加载成功后刷新路径)
    TDData.LoadFromCloud(function(ok, source)
        if ok and tdState then
            print("[TDState] 云端配置已加载, 刷新路径数据")
            TDLogic.InitPathData()
        end
    end)
end

--- 切换到下一关 (固定路径 & 塔位不变, 保留已放置武将)
function M.NextLevel()
    if not tdState then return end
    local level = tdState.level + 1

    -- 保留已放置的武将, 重置计时器, 回满血
    local newHeroes = {}
    local newPlacedMap = {}
    for _, hero in ipairs(tdState.heroes) do
        if hero.slotKey and tdState.placeable[hero.slotKey] then
            hero.atkTimer = 0
            hero.currentHP = hero.maxHP     -- 回满血
            hero.dead = false
            hero.respawnTimer = 0
            newHeroes[#newHeroes + 1] = hero
            newPlacedMap[hero.slotKey] = #newHeroes
        end
    end

    tdState.level = level
    tdState.gold = tdState.gold + TDData.WAVE_BONUS_GOLD  -- 过关奖励
    tdState.baseHP = tdState.baseMaxHP  -- 回满血
    tdState.heroes = newHeroes
    tdState.placedHeroMap = newPlacedMap
    tdState.enemies = {}
    tdState.projectiles = {}
    tdState.waves = TDData.GenerateWaves(level)
    tdState.currentWave = 0
    tdState.waveTimer = 0
    tdState.spawnQueue = {}
    tdState.spawnTimer = 0
    tdState.phase = "PREPARE"
    tdState.floatTexts = {}
    tdState.particles = {}
    tdState.waveEnemiesAlive = 0
    tdState.prepareTimer = 0
    -- 能量保留, 技能CD重置
    for i = 1, #tdState.skills do
        tdState.skills[i].cdTimer = 0
    end
    tdState.focusedHeroIdx = 0
    tdState.repositionMode = false
    tdState.targetingSkill = 0
    -- 飞行剑重置
    tdState.swordCdTimer = tdState.swordCdBase * 0.5
    tdState.flyingSwords = {}
end

--- 重置塔防状态
function M.Reset()
    tdState = nil
end

return M
