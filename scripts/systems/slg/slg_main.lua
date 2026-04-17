-- ============================================================================
-- slg/slg_main.lua - 涓夊浗姝︾伒浼狅細SLG鍏ュ彛妯″潡
-- 灏嗘墍鏈夊瓙妯″潡鎸傝浇鍒板叏灞€ WorldMap 琛紝淇濇寔瀵瑰鎺ュ彛鍏煎
-- ============================================================================

---@diagnostic disable: undefined-global

-- 鍔犺浇瀛愭ā鍧楋紙椤哄簭閲嶈锛欴ata/State 鍏堜簬 Logic锛孡ogic 鍏堜簬 Input锛?
local Data   = require("systems.slg.slg_data")
local State  = require("systems.slg.slg_state")
local Logic  = require("systems.slg.slg_logic")
local Render = require("systems.slg.slg_render")
local Panels = require("systems.slg.slg_panels")
local Input  = require("systems.slg.slg_input")

-- ============================================================================
-- 鍏ㄥ眬 WorldMap 琛?(淇濇寔鍚戝悗鍏煎)
-- ============================================================================
WorldMap = WorldMap or {}

-- Logic 妯″潡
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

-- B4: 姝﹀皢绠＄悊/鎷涢檷/琛ュ叺/瀛樻。
WorldMap.SetHeroTroop      = Logic.SetHeroTroop
WorldMap.LearnSkill        = Logic.LearnSkill
WorldMap.TrySurrender      = Logic.TrySurrender
WorldMap.FinishSurrender   = Logic.FinishSurrender
WorldMap.Reinforce         = Logic.Reinforce
WorldMap.SaveSLG           = Logic.SaveSLG
WorldMap.LoadSLG           = Logic.LoadSLG
WorldMap.HasSave           = Logic.HasSave
WorldMap.DeleteSave        = Logic.DeleteSave

-- Input 妯″潡 (琛屽啗鍔ㄧ敾 + 寮曞 + 杈撳叆)
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

-- Render 妯″潡 (鍦板浘缁樺埗)
WorldMap.GetFC             = Render.GetFC
WorldMap.GetFactionStats   = Render.GetFactionStats
WorldMap.DrawBtn           = Render.DrawBtn

-- 涓荤粯鍒跺叆鍙ｏ細灏?Panels.DrawPanel 浣滀负鍥炶皟浼犲叆 Render
function WorldMap.DrawWorldMapScreen()
    Render.DrawWorldMapScreen(Panels.DrawPanel)
end

-- 寰侀€旀ā寮忥細绾崟鏈?+ CloudAPI 瀛樻。锛屼笉渚濊禆鏈嶅姟绔?

-- 鍚戝悗鍏煎锛歜attle_hud_core 绛夊閮ㄦ枃浠朵互瑁稿叏灞€鍑芥暟璋冪敤
DrawWorldMapScreen = WorldMap.DrawWorldMapScreen

return WorldMap

