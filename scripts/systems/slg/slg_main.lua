-- ============================================================================
-- slg/slg_main.lua - 三国武灵传：SLG入口模块
-- 将所有子模块挂载到全局 WorldMap 表，保持对外接口兼容
-- ============================================================================

---@diagnostic disable: undefined-global

-- 加载子模块（顺序重要：Data/State 先于 Logic，Logic 先于 Input）
local Data   = require("systems.slg.slg_data")
local State  = require("systems.slg.slg_state")
local Logic  = require("systems.slg.slg_logic")
local Render = require("systems.slg.slg_render")
local Panels = require("systems.slg.slg_panels")
local Input  = require("systems.slg.slg_input")

-- ============================================================================
-- 全局 WorldMap 表 (保持向后兼容)
-- ============================================================================
WorldMap = WorldMap or {}

-- Logic 模块
WorldMap.Init              = Logic.Init
WorldMap.EndTurn           = Logic.EndTurn
WorldMap.MoveArmy          = Logic.MoveArmy
WorldMap.StartAttack       = Logic.StartAttack
WorldMap.OnBattleResult    = Logic.OnBattleResult
WorldMap.Recruit           = Logic.Recruit
WorldMap.UpgradeCity       = Logic.UpgradeCity
WorldMap.SearchTalent      = Logic.SearchTalent
WorldMap.BoostMorale       = Logic.BoostMorale
WorldMap.SendGift          = Logic.SendGift
WorldMap.SignTreaty         = Logic.SignTreaty
WorldMap.ExecuteStratagem  = Logic.ExecuteStratagem
WorldMap.GetPlayerCityCount = Logic.GetPlayerCityCount
WorldMap.GetCityById       = Logic.GetCityById
WorldMap.GetCityData       = Logic.GetCityData
WorldMap.IsConnected       = Logic.IsConnected

-- B4: 武将管理/招降/补兵/存档
WorldMap.SetHeroTroop      = Logic.SetHeroTroop
WorldMap.LearnSkill        = Logic.LearnSkill
WorldMap.TrySurrender      = Logic.TrySurrender
WorldMap.FinishSurrender   = Logic.FinishSurrender
WorldMap.Reinforce         = Logic.Reinforce
WorldMap.SaveSLG           = Logic.SaveSLG
WorldMap.LoadSLG           = Logic.LoadSLG
WorldMap.HasSave           = Logic.HasSave
WorldMap.DeleteSave        = Logic.DeleteSave

-- Input 模块 (行军动画 + 引导 + 输入)
WorldMap.HandleInput       = Input.HandleInput
WorldMap.HandleScroll      = Input.HandleScroll
WorldMap.StartMarchAnim    = Input.StartMarchAnim
WorldMap.IsMarchActive     = Input.IsMarchActive
WorldMap.UpdateMarch       = Input.UpdateMarch
WorldMap.DrawMarch         = Input.DrawMarch
WorldMap.StartGuide        = Input.StartGuide
WorldMap.IsGuideActive     = Input.IsGuideActive
WorldMap.UpdateGuide       = Input.UpdateGuide
WorldMap.DrawGuide         = Input.DrawGuide
WorldMap.HandleGuideInput  = Input.HandleGuideInput
WorldMap.UpdateMapDrag     = Input.UpdateMapDrag
WorldMap.CenterOnCity      = Input.CenterOnCity

-- Render 模块 (地图绘制)
WorldMap.GetFC             = Render.GetFC
WorldMap.GetFactionStats   = Render.GetFactionStats
WorldMap.DrawBtn           = Render.DrawBtn

-- 主绘制入口：将 Panels.DrawPanel 作为回调传入 Render
function WorldMap.DrawWorldMapScreen()
    Render.DrawWorldMapScreen(Panels.DrawPanel)
end

-- 征途模式：纯单机 + clientCloud 存档，不依赖服务端

-- 向后兼容：battle_hud_core 等外部文件以裸全局函数调用
DrawWorldMapScreen = WorldMap.DrawWorldMapScreen

return WorldMap
