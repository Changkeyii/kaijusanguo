-- ============================================================================
-- 从三国开始争霸天下 v1.0.0
-- 大地图回合策略 + 战场即时战斗 + 武将技能碾压
-- ============================================================================

-- ============================================================================
-- 服务端模式：仅加载 Server.lua，不加载客户端模块
-- ============================================================================
if rawget(_G, "IsServerMode") and IsServerMode() then
    local ServerModule = require("network.Server")
    function Start()
        ServerModule.Start()
    end
    function Stop()
        ServerModule.Stop()
    end
    return  -- 服务端不执行后续客户端代码
end

require "LuaScripts/Utilities/Sample"

-- 管理员构建标志：发布时false，管理员调试时设为true
IS_ADMIN_BUILD = false

-- 管理员模块条件加载（仅当 IS_ADMIN_BUILD=true 且 admin/ 已复制到 scripts/ 时生效）
if IS_ADMIN_BUILD then
    local ok1, m1 = pcall(require, "admin.admin_mail_ui")
    if ok1 then _AdminMailUI = m1 end
    local ok2, m2 = pcall(require, "admin.admin_mail_input")
    if ok2 then _AdminMailInput = m2 end
    local ok3, m3 = pcall(require, "admin.admin_mail_keyboard")
    if ok3 then _AdminMailKeyboard = m3 end
end

-- cjson: 引擎内置全局变量, 在使用处就近声明 (避免200 upvalue限制)
GameConfig = require "game_config"
require "EquipUI"
CloudAPI = require "cloud_api"
CloudManager = require "cloud_manager"
TradeManager = require "trade_manager"

-- ============================================================================
-- 模块加载
-- ============================================================================
require "G"
require "utils"

-- Systems
require "systems.ad"
require "systems.audio"
require "systems.battle.init"
require "systems.battle.units"
require "systems.battle.update"
require "systems.battle_pass"
require "systems.cdk"
require "systems.daily_reset"
require "systems.equip"
-- require "systems.gacha"  -- 已移除抽卡系统
require "systems.stage_bridge"  -- 从已删模块中提取的共用函数(布局/排位/满命检测/残片掉落)
require "systems.hero"
require "systems.misc"
require "systems.phase"
require "systems.rank"
require "systems.rewards"
require "systems.save_system"
require "systems.seal"
require "systems.skill"
-- require "systems.stage"  -- 已移除关卡系统
require "systems.tasks"
-- require "systems.tutorial"  -- 已移除引导系统
require "systems.slg.slg_main"

-- UI
require "ui.battle_hud"
require "ui.codex"
require "ui.draw_helpers"
-- require "ui.gacha_screen"  -- 已移除抽卡UI
require "ui.input"
require "ui.menu"
require "ui.screens"
require "ui.seal_screen"
require "ui.summon_screen"
require "ui.settings"
require "ui.social"



-- ============================================================================
-- 模块化资源下载 (阻塞完成后并行启动 4 个模块)
-- ============================================================================

--- 总入口：启动全部 4 个模块的后台下载
function InitModuleDownloads()
    if downloadUI.modulesInited then return end
    downloadUI.modulesInited = true
    print("[DWP] 启动 5 个模块后台下载...")
    InitModuleEquipment()
    InitModuleHeroes()
    InitModuleSkills()
    InitModuleBattle()
end


--- 模块1: 兵甲资源
function InitModuleEquipment()
    local ms = moduleState.equipment
    IMG.equipmentSheet = nvgCreateImage(vg, "image/equipment_sheet_dark_new.png", 0)
    IMG.tierFrames = nvgCreateImage(vg, "image/tier_frames_sanguo_new.png", 0)

    local resList = { "image/equipment_sheet_dark_new.png", "image/tier_frames_sanguo_new.png" }
    ms.totalCount = #resList
    ms.downloading = true
    cache:DownloadResources(resList,
        function(success, failedCount)
            ms.ready = true; ms.downloading = false; ms.progress = 1.0
            print("[DWP] 兵甲模块下载完成, success=" .. tostring(success))
        end,
        function(completed, total)
            ms.completedCount = completed; ms.totalCount = total
            ms.progress = total > 0 and (completed / total) or 0
        end
    )
end


--- 模块2: 武灵资源
function InitModuleHeroes()
    local ms = moduleState.heroes
    -- 三国武灵独立图 (hero1-hero108)
    for i = 1, 108 do
        local key = "hero" .. i
        IMG[key] = nvgCreateImage(vg, "image/hero_" .. i .. ".png", 0)
    end
    -- 敌方独立立绘 (enemy1-enemy16)
    for i = 1, 16 do
        local key = "enemy" .. i
        IMG[key] = nvgCreateImage(vg, "image/enemy_" .. i .. ".png", 0)
    end

    local resList = {}
    for i = 1, 108 do
        resList[i] = "image/hero_" .. i .. ".png"
    end
    for i = 1, 16 do
        resList[108 + i] = "image/enemy_" .. i .. ".png"
    end
    ms.totalCount = #resList
    ms.downloading = true
    cache:DownloadResources(resList,
        function(success, failedCount)
            ms.ready = true; ms.downloading = false; ms.progress = 1.0
            print("[DWP] 兵甲模块下载完成, success=" .. tostring(success))
        end,
        function(completed, total)
            ms.completedCount = completed; ms.totalCount = total
            ms.progress = total > 0 and (completed / total) or 0
        end
    )
end


--- 模块3: 武技资源
function InitModuleSkills()
    local ms = moduleState.skills
    IMG.skillIconSheet = nvgCreateImage(vg, "image/skill_icons_sheet_dark_new.png", 0)
    IMG.lockIcon = nvgCreateImage(vg, "image/lock_icon_dark_20260405040224.png", 0)

    local resList = { "image/skill_icons_sheet_dark_new.png" }
    ms.totalCount = #resList
    ms.downloading = true
    cache:DownloadResources(resList,
        function(success, failedCount)
            ms.ready = true; ms.downloading = false; ms.progress = 1.0
            print("[DWP] 兵甲模块下载完成, success=" .. tostring(success))
        end,
        function(completed, total)
            ms.completedCount = completed; ms.totalCount = total
            ms.progress = total > 0 and (completed / total) or 0
        end
    )
end


--- 模块4: 战斗资源
function InitModuleBattle()
    local ms = moduleState.battle

    -- 布局已内置为默认值，不再从文件加载
    -- LoadBattleLayouts()

    IMG.bg = nvgCreateImage(vg, "image/battle_bg_1.png", 0)
    IMG.skillSheet = nvgCreateImage(vg, "image/skill_fentianjue.png", 0)

    -- 世界地图素材
    IMG.wmBg = nvgCreateImage(vg, "image/world_map_bg_20260415172845.png", 0)
    IMG.wmCityNormal = nvgCreateImage(vg, "image/city_icon_normal_20260415023214.png", 0)
    IMG.wmCityCapital = nvgCreateImage(vg, "image/city_icon_capital_20260415023249.png", 0)
    IMG.wmPanel = nvgCreateImage(vg, "image/panel_scroll_bg_20260415023215.png", 0)
    IMG.wmBtnAction = nvgCreateImage(vg, "image/btn_action_20260415023237.png", 0)
    IMG.wmFlagRed = nvgCreateImage(vg, "image/flag_red_20260415023234.png", 0)
    IMG.wmFlagBlue = nvgCreateImage(vg, "image/flag_blue_20260415023218.png", 0)
    IMG.wmFlagGreen = nvgCreateImage(vg, "image/flag_green_20260415023216.png", 0)
    IMG.mapBg = nvgCreateImage(vg, "image/battle_bg_topdown_stage6.png", 0)
    IMG.abyssSelectBg = nvgCreateImage(vg, "image/abyss_select_sanguo_bright_20260408082708.png", 0)
    IMG.rankedSelectBg = nvgCreateImage(vg, "image/ranked_select_sanguo_bright_20260408082704.png", 0)
    IMG.towerSelectBg = nvgCreateImage(vg, "image/tower_select_sanguo_bright_20260408082718.png", 0)
    IMG.dailyDungeonBg = nvgCreateImage(vg, "image/daily_dungeon_sanguo_bright_20260408082709.png", 0)

    -- Q萌国风新背景
    IMG.codexBg = nvgCreateImage(vg, "image/codex_bg_20260415173024.png", 0)
    IMG.settingsBg = nvgCreateImage(vg, "image/settings_bg_20260415173050.png", 0)
    IMG.deployBg = nvgCreateImage(vg, "image/deploy_bg_20260415172852.png", 0)
    IMG.homeBg = nvgCreateImage(vg, "image/home_bg_20260415173103.png", 0)
    IMG.panelBg = nvgCreateImage(vg, "image/panel_bg_new_20260416000416.png", 0)
    IMG.battleBgNew = nvgCreateImage(vg, "image/battle_bg_qcute_classic_20260420115155.png", 1) -- Q萌经典战役背景，NVG_IMAGE_GENERATE_MIPMAPS
    -- 新城池图标与旗帜
    IMG.cityFriendly = nvgCreateImage(vg, "image/city_icon_friendly_20260415173137.png", 0)
    IMG.cityEnemy = nvgCreateImage(vg, "image/city_icon_enemy_20260415173221.png", 0)
    IMG.cityNeutral = nvgCreateImage(vg, "image/city_icon_neutral_20260415173305.png", 0)
    IMG.btnDeploy = nvgCreateImage(vg, "image/btn_deploy_20260415173149.png", 0)
    IMG.flagShu = nvgCreateImage(vg, "image/faction_flag_shu_20260415173130.png", 0)
    IMG.flagWei = nvgCreateImage(vg, "image/faction_flag_wei_20260415173135.png", 0)
    IMG.flagWu = nvgCreateImage(vg, "image/faction_flag_wu_20260416015845.png", 0)
    IMG.flagQun = nvgCreateImage(vg, "image/faction_flag_qun_20260416015756.png", 0)
    IMG.btnPause = nvgCreateImage(vg, "image/btn_pause_20260416015754.png", 0)
    IMG.wmBgClean = nvgCreateImage(vg, "image/world_map_bg_8k_20260418151435.png", 0) -- 8K水墨风世界地图：无城池无文字，由代码动态叠加

    -- 兵符经验道具图片
    for idx, item in ipairs(SEAL_EXP_ITEMS) do
        sealExpItemImages[idx] = nvgCreateImage(vg, item.img, 0)
    end

    local unitFiles = {
        {"sword",          "image/unit_sword_20260408043132.png"},
        {"archer",         "image/unit_archer_20260408043131.png"},
        {"shield",         "image/unit_shield_20260408043146.png"},
        {"mage",           "image/unit_mage_20260408043126.png"},
        {"healer",         "image/unit_healer_20260408043156.png"},
        {"demon_warrior",  "image/unit_demon_warrior_20260408043242.png"},
        {"demon_archer",   "image/unit_demon_archer_20260408043348.png"},
        {"demon_tank",     "image/unit_demon_tank_20260408043300.png"},
        {"cavalry",        "image/unit_cavalry_20260408043245.png"},
        {"beast",          "image/unit_beast_20260408043249.png"},
        {"assassin",       "image/unit_assassin_20260408044538.png"},
        {"lancer",         "image/unit_lancer_20260408044610.png"},
        {"talisman",       "image/unit_talisman_20260408044643.png"},
        {"puppeteer",      "image/unit_puppeteer_20260408044742.png"},
        {"ice_mage",       "image/unit_ice_mage_20260408055719.png"},
        {"swarm",          "image/unit_swarm_20260408044906.png"},
    }
    for _, uf in ipairs(unitFiles) do
        IMG.unitSprites[uf[1]] = nvgCreateImage(vg, uf[2], 0)
    end

    -- TD 地图贴图 (2.5D Q版三国风格)
    IMG.tdMapBg  = nvgCreateImage(vg, "image/td_map_bg_hd_20260425081936.png", 0)
    IMG.tdGrass  = nvgCreateImage(vg, "image/td_grass_varied_20260425075602.png", NVG_IMAGE_REPEATX + NVG_IMAGE_REPEATY)
    IMG.tdRoad   = nvgCreateImage(vg, "image/td_road_seamless_20260425075559.png", NVG_IMAGE_REPEATX + NVG_IMAGE_REPEATY)
    IMG.tdCastle = nvgCreateImage(vg, "image/td_castle_q_20260425072900.png", 0)
    IMG.tdSlot   = nvgCreateImage(vg, "image/td_slot_q_20260425072914.png", 0)
    IMG.tdEntranceFlag = nvgCreateImage(vg, "image/td_entrance_flag_20260425072859.png", 0)
    IMG.tdGoldIcon     = nvgCreateImage(vg, "image/td_gold_icon_20260425072901.png", 0)
    IMG.tdSelectBg     = nvgCreateImage(vg, "image/td_select_bg_20260425120420.png", 0)
    IMG.tdFxSlash      = nvgCreateImage(vg, "image/fx_slash_v2_20260425123340.png", 0)
    IMG.tdFxArrow      = nvgCreateImage(vg, "image/fx_arrow_v2_20260425123327.png", 0)
    -- TD 技能图标
    IMG.tdSkillIcons = {
        nvgCreateImage(vg, "image/skill_icon_sword_20260425123348.png", 0),    -- 1: 飞剑
        nvgCreateImage(vg, "image/skill_icon_fire_20260425123326.png", 0),      -- 2: 天火
        nvgCreateImage(vg, "image/skill_icon_frost_20260425123332.png", 0),     -- 3: 冰霜
        nvgCreateImage(vg, "image/skill_icon_heal_20260425123328.png", 0),      -- 4: 春风
        nvgCreateImage(vg, "image/skill_icon_thunder_20260425123331.png", 0),   -- 5: 雷霆
    }
    -- 玩法入口图标
    IMG.iconGameplay   = nvgCreateImage(vg, "image/icon_gameplay_20260425123344.png", 0)

    for idx, fx in pairs(SKILL_FX_SHEETS) do
        fx.handle = nvgCreateImage(vg, fx.file, 0)
    end

    -- ★ 初始化战斗布局背景句柄: 遍历 BATTLE_LAYOUTS 自动加载 bg 字段的图片
    for i, layout in ipairs(BATTLE_LAYOUTS) do
        if layout.bg then
            layout.bgHandle = nvgCreateImage(vg, layout.bg, 1)  -- NVG_IMAGE_GENERATE_MIPMAPS
        end
    end

    -- 石台底座图片 (透明背景, 独立于战斗背景)
    IMG.platform = {}
    IMG.platform.default = nvgCreateImage(vg, "image/platform_default_20260408122937.png", 0)
    IMG.platform.shu     = nvgCreateImage(vg, "image/platform_shu_20260408122914.png", 0)
    IMG.platform.wu      = nvgCreateImage(vg, "image/platform_wu_20260408122920.png", 0)
    IMG.platform.wei     = nvgCreateImage(vg, "image/platform_wei_20260408122920.png", 0)
    -- 所有布局统一蜀风石台 + 阵营色
    for i, layout in ipairs(BATTLE_LAYOUTS) do
        layout.platformImg = IMG.platform.shu
        layout.platformFaction = "shu"
    end

    IMG.abyssIcon = {}
    IMG.abyssIcon[1] = nvgCreateImage(vg, "image/abyss_icon_1_sanguo_bright_20260408083110.png", 0)
    IMG.abyssIcon[2] = nvgCreateImage(vg, "image/abyss_icon_2_sanguo_bright_20260408083150.png", 0)
    IMG.abyssIcon[3] = nvgCreateImage(vg, "image/abyss_icon_3_sanguo_bright_20260408083102.png", 0)
    IMG.abyssIcon[4] = nvgCreateImage(vg, "image/abyss_icon_4_sanguo_bright_20260408083119.png", 0)
    IMG.abyssIcon[5] = nvgCreateImage(vg, "image/abyss_icon_5_sanguo_bright_20260408083103.png", 0)
    IMG.abyssIcon[6] = nvgCreateImage(vg, "image/abyss_icon_6_sanguo_bright_20260408083117.png", 0)
    IMG.abyssIcon[7] = nvgCreateImage(vg, "image/abyss_icon_7_sanguo_bright_20260408083114.png", 0)

    -- ========== 战旗回合制 UI 图片 ==========
    IMG.tactic = {}
    IMG.tactic.gridNormal    = nvgCreateImage(vg, "image/grid_tile_normal_20260424030041.png", 0)
    IMG.tactic.gridDark      = nvgCreateImage(vg, "image/grid_tile_dark_20260424030039.png", 0)
    IMG.tactic.hlMove        = nvgCreateImage(vg, "image/highlight_move_20260423162236.png", 0)
    IMG.tactic.hlAttack      = nvgCreateImage(vg, "image/highlight_attack_20260423162205.png", 0)
    IMG.tactic.hlSelected    = nvgCreateImage(vg, "image/highlight_selected_20260423162158.png", 0)
    IMG.tactic.panelBg       = nvgCreateImage(vg, "image/panel_bottom_bg_20260424030058.png", 0)
    IMG.tactic.btnMove       = nvgCreateImage(vg, "image/btn_move_20260424030037.png", 0)
    IMG.tactic.btnAttack     = nvgCreateImage(vg, "image/btn_attack_20260424030111.png", 0)
    IMG.tactic.btnWait       = nvgCreateImage(vg, "image/btn_wait_20260424030038.png", 0)
    IMG.tactic.btnEndTurn    = nvgCreateImage(vg, "image/btn_end_turn_20260424030040.png", 0)
    IMG.tactic.btnDisabled   = nvgCreateImage(vg, "image/btn_disabled_20260424030058.png", 0)
    IMG.tactic.troopFrameP   = nvgCreateImage(vg, "image/troop_frame_player_20260423162518.png", 0)
    IMG.tactic.troopFrameE   = nvgCreateImage(vg, "image/troop_frame_enemy_20260423162514.png", 0)
    IMG.tactic.btnInfantry   = nvgCreateImage(vg, "image/troop_btn_infantry_20260423162509.png", 0)
    IMG.tactic.btnArcher     = nvgCreateImage(vg, "image/troop_btn_archer_20260423162510.png", 0)
    IMG.tactic.btnCavalry    = nvgCreateImage(vg, "image/troop_btn_cavalry_20260423162509.png", 0)
    IMG.tactic.btnSpear      = nvgCreateImage(vg, "image/troop_btn_spear_20260423162509.png", 0)
    IMG.tactic.bannerPlayer  = nvgCreateImage(vg, "image/banner_player_turn_20260423162532.png", 0)
    IMG.tactic.bannerEnemy   = nvgCreateImage(vg, "image/banner_enemy_turn_20260423162515.png", 0)
    IMG.tactic.hpBarFrame    = nvgCreateImage(vg, "image/hp_bar_frame_20260423162505.png", 0)
    IMG.tactic.battleBg      = nvgCreateImage(vg, "image/tactic_battle_bg_20260424030038.png", 0)

    local battleRes = {
        "image/battle_bg_1.png",
        "image/skill_fentianjue.png",
        "image/battle_bg_topdown_stage6.png",
        "image/abyss_select_sanguo_bright_20260408082708.png",
    }
    -- 战场背景 2-8
    for i = 2, 8 do
        battleRes[#battleRes + 1] = "image/battle_bg_" .. i .. ".png"
    end
    for _, uf in ipairs(unitFiles) do
        battleRes[#battleRes + 1] = uf[2]
    end
    for idx, fx in pairs(SKILL_FX_SHEETS) do
        battleRes[#battleRes + 1] = fx.file
    end
    battleRes[#battleRes + 1] = "image/abyss_bg_sanguo_1_bright_20260408083455.png"
    battleRes[#battleRes + 1] = "image/abyss_bg_sanguo_2_bright_20260408083457.png"
    battleRes[#battleRes + 1] = "image/abyss_bg_sanguo_3_bright_20260408083425.png"
    battleRes[#battleRes + 1] = "image/abyss_bg_sanguo_4_bright_20260408083429.png"
    battleRes[#battleRes + 1] = "image/abyss_bg_sanguo_5_bright_20260408083431.png"
    battleRes[#battleRes + 1] = "image/abyss_bg_sanguo_6_bright_20260408083622.png"
    battleRes[#battleRes + 1] = "image/abyss_bg_sanguo_7_bright_20260408083435.png"
    battleRes[#battleRes + 1] = "image/abyss_icon_1_sanguo_bright_20260408083110.png"
    battleRes[#battleRes + 1] = "image/abyss_icon_2_sanguo_bright_20260408083150.png"
    battleRes[#battleRes + 1] = "image/abyss_icon_3_sanguo_bright_20260408083102.png"
    battleRes[#battleRes + 1] = "image/abyss_icon_4_sanguo_bright_20260408083119.png"
    battleRes[#battleRes + 1] = "image/abyss_icon_5_sanguo_bright_20260408083103.png"
    battleRes[#battleRes + 1] = "image/abyss_icon_6_sanguo_bright_20260408083117.png"
    battleRes[#battleRes + 1] = "image/abyss_icon_7_sanguo_bright_20260408083114.png"
    -- Q萌国风新背景与UI元素
    battleRes[#battleRes + 1] = "image/codex_bg_20260415173024.png"
    battleRes[#battleRes + 1] = "image/settings_bg_20260415173050.png"
    battleRes[#battleRes + 1] = "image/deploy_bg_20260415172852.png"
    battleRes[#battleRes + 1] = "image/home_bg_20260415173103.png"
    battleRes[#battleRes + 1] = "image/panel_bg_20260415173049.png"
    battleRes[#battleRes + 1] = "image/battle_bg_ink_wash_20260418083752.png"
    battleRes[#battleRes + 1] = "image/city_icon_friendly_20260415173137.png"
    battleRes[#battleRes + 1] = "image/city_icon_enemy_20260415173221.png"
    battleRes[#battleRes + 1] = "image/city_icon_neutral_20260415173305.png"
    battleRes[#battleRes + 1] = "image/btn_deploy_20260415173149.png"
    battleRes[#battleRes + 1] = "image/faction_flag_shu_20260415173130.png"
    battleRes[#battleRes + 1] = "image/faction_flag_wei_20260415173135.png"
    ms.totalCount = #battleRes
    ms.downloading = true
    cache:DownloadResources(battleRes,
        function(success, failedCount)
            ms.ready = true; ms.downloading = false; ms.progress = 1.0
            print("[DWP] 战斗模块下载完成, success=" .. tostring(success) .. " failed=" .. tostring(failedCount))
        end,
        function(completed, total, downloadedBytes, totalBytes)
            ms.completedCount = completed; ms.totalCount = total
            ms.progress = total > 0 and (completed / total) or 0
        end
    )
end


-- ============================================================================
-- 排位匹配生命周期（后台匹配模式）
-- ============================================================================

--- Legacy room-match callback kept as a no-op while the project uses persistent servers.
function HandleServerReady(eventType, eventData)
    print("[Main] Ignoring legacy ServerReady event; persistent server flow is active")
end

-- ============================================================================
-- 初始化
-- ============================================================================

function Start()
    SampleStart()

    CloudAPI.Init()

    vg = nvgCreate(1)
    if not vg then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- 字体初始化: 只加载 MiSans 默认字体
    fontId = nvgCreateFont(vg, "sans", "Fonts/LXGWWenKai-Regular.ttf")

    -- ========== 阻塞阶段: 首页必需资源全部下载完才进入 ==========
    -- 创建 NanoVG 句柄（DWP 占位）
    IMG.menuBg = nvgCreateImage(vg, "image/edited_menu_bg_no_panel_20260416004055.png", 0)
    IMG.scrollPanel = nvgCreateImage(vg, "image/scroll_panel_v2_20260421093014.png", 0)
    IMG.btnMenuPrimary = nvgCreateImage(vg, "image/btn_primary_v2_20260421092932.png", 0)
    IMG.btnMenuNormal = nvgCreateImage(vg, "image/btn_normal_v2_20260421092956.png", 0)
    IMG.btnMenuPrimarySelected = nvgCreateImage(vg, "image/btn_primary_selected_20260421095013.png", 0)
    IMG.btnMenuNormalSelected = nvgCreateImage(vg, "image/btn_normal_selected_20260421095041.png", 0)
    IMG.avatarSheet = nvgCreateImage(vg, "image/avatars_q_cute.png", 0)
    IMG.cloudA = nvgCreateImage(vg, "image/cloud_a_sanguo_bright_20260408082912.png", 0)
    IMG.cloudB = nvgCreateImage(vg, "image/cloud_b_sanguo_bright_20260408082858.png", 0)
    IMG.playerPanel = nvgCreateImage(vg, "image/player_panel_sanguo_bright_20260408082842.png", 0)
    IMG.dragonPortal = nvgCreateImage(vg, "image/icon_zhanling_v3_20260409100724.png", 0)   -- 战令
    IMG.taofaIcon = nvgCreateImage(vg, "image/icon_taofa_v3_20260409100723.png", 0)       -- 讨伐
    IMG.treasureChest = nvgCreateImage(vg, "image/treasure_chest_new_20260408104225.png", 0)
    IMG.btnCodex = nvgCreateImage(vg, "image/btn_frame_sanguo_20260408091405.png", 0)
    -- comic1/comic2 + introVideo 已移除（新手引导不再使用开场视频/漫画）
    IMG.abyssTicket = nvgCreateImage(vg, "image/icon_pata_v4_20260409100707.png", 0)  -- 涔变笘寰侀€?爪

    -- 战令专用图标 (替代 emoji)
    IMG.bpIconJade = nvgCreateImage(vg, "image/bp_icon_jade_20260409103401.png", 0)
    IMG.bpIconFrag = nvgCreateImage(vg, "image/bp_icon_frag_20260409103349.png", 0)
    IMG.bpIconEquip = nvgCreateImage(vg, "image/bp_icon_equip_20260409103351.png", 0)
    IMG.bpIconExp = nvgCreateImage(vg, "image/bp_icon_exp_20260409103404.png", 0)
    IMG.bpIconCheck = nvgCreateImage(vg, "image/bp_icon_check_20260409103343.png", 0)
    IMG.bpIconLock = nvgCreateImage(vg, "image/bp_icon_lock_20260409103359.png", 0)
    IMG.bpIconMilestone = nvgCreateImage(vg, "image/bp_icon_milestone_20260409103351.png", 0)
    IMG.bpBanner = nvgCreateImage(vg, "image/bp_banner_20260409103340.png", 0)

    -- 战令国风装饰素材
    IMG.bpFrameCorner = nvgCreateImage(vg, "image/bp_frame_corner_20260409104818.png", 0)
    IMG.bpCardGold = nvgCreateImage(vg, "image/bp_card_overlay_gold_20260409104823.png", 0)
    IMG.bpCardBlue = nvgCreateImage(vg, "image/bp_card_overlay_blue_20260409104825.png", 0)
    IMG.bpBadgeVip = nvgCreateImage(vg, "image/bp_track_badge_vip_20260409104820.png", 0)
    IMG.bpBadgeFree = nvgCreateImage(vg, "image/bp_track_badge_free_20260409104824.png", 0)
    IMG.bpDivider = nvgCreateImage(vg, "image/bp_divider_deco_20260409104810.png", 0)

    -- 菜单入口图标 (国风二次元风格，轻盈明亮)
    IMG.menuIcons = {}
    IMG.menuIcons[1]  = nvgCreateImage(vg, "image/icon_wulinglu_v2_20260409092052.png", 0)    -- 武将录
    IMG.menuIcons[2]  = nvgCreateImage(vg, "image/icon_bingji_v3_20260409095902.png", 0)      -- 兵甲
    IMG.menuIcons[3]  = nvgCreateImage(vg, "image/icon_tulu_v2_20260409092109.png", 0)        -- 兵甲图录
    IMG.menuIcons[4]  = nvgCreateImage(vg, "image/icon_wuji_v2_20260409092118.png", 0)        -- 武技
    IMG.menuIcons[5]  = nvgCreateImage(vg, "image/icon_cifu_v3_20260409095904.png", 0)        -- 天命赐福
    IMG.menuIcons[6]  = nvgCreateImage(vg, "image/icon_renwu_v3_20260409095925.png", 0)       -- 每日浠诲姟
    IMG.menuIcons[7]  = nvgCreateImage(vg, "image/icon_paiwei_v3_20260409100755.png", 0)      -- 排位
    IMG.menuIcons[8]  = nvgCreateImage(vg, "image/icon_zhenying_v3_20260409095857.png", 0)    -- 阵营
    IMG.menuIcons[9]  = nvgCreateImage(vg, "image/icon_haoyou_v2_20260409092321.png", 0)      -- 好友
    IMG.menuIcons[10] = nvgCreateImage(vg, "image/icon_youjian_v3_20260409095937.png", 0)     -- 邮件
    IMG.menuIcons[11] = nvgCreateImage(vg, "image/icon_zhaohuan_v2_20260409093140.png", 0)    -- 召唤武灵
    IMG.menuIcons[12] = nvgCreateImage(vg, "image/icon_zhanlibang_v2_20260409093144.png", 0)  -- 战力榜
    IMG.menuIcons[13] = nvgCreateImage(vg, "image/icon_shezhi_v3_20260409095935.png", 0)      -- 设置
    IMG.menuIcons[14] = nvgCreateImage(vg, "image/icon_trade_20260411014554.png", 0)        -- 交易行
    IMG.menuIcons[15] = nvgCreateImage(vg, "image/icon_biandui_v2_20260411051928.png", 0)    -- 缂栭槦
    IMG.sealItem1 = nvgCreateImage(vg, "image/icon_tansuo_v4_20260409100758.png", 0)   -- 探索
    IMG.sealItem2 = nvgCreateImage(vg, "image/icon_pata_v4_20260409100707.png", 0)   -- 爬塔(乱世征途子页)
    IMG.sealItem3 = nvgCreateImage(vg, "image/icon_fuben_v3_20260409100805.png", 0)  -- 副本

    -- 阻塞下载：字体优先 + 首屏必需资源（减少加载时间）
    local blockingRes = {
        "Fonts/LXGWWenKai-Regular.ttf",

        "image/avatars_sanguo_v2_20260408082207.png",
        "image/home_bg_sanguo_bright_20260408082713.png",
    }
    -- 菜单装饰 + 按钮图片（后台下载不阻塞）
    local menuDecoRes = {
        "image/cloud_a_sanguo_bright_20260408082912.png",
        "image/cloud_b_sanguo_bright_20260408082858.png",
        "image/title_scroll_sanguo_bright_20260408082855.png",
        "image/player_panel_sanguo_bright_20260408082842.png",
        "image/portal_sanguo_bright_20260408082840.png",
        "image/treasure_chest_sanguo_bright_20260408082844.png",
        "image/btn_frame_sanguo_bright_20260408082840.png",
        -- 菜单入口图标
        "image/abyss_icon_1_sanguo_bright_20260408083110.png",
        "image/abyss_icon_2_sanguo_bright_20260408083150.png",
        "image/abyss_icon_3_sanguo_bright_20260408083102.png",
        "image/abyss_icon_4_sanguo_bright_20260408083119.png",
        "image/abyss_icon_5_sanguo_bright_20260408083103.png",
        "image/abyss_icon_6_sanguo_bright_20260408083117.png",
        "image/abyss_icon_7_sanguo_bright_20260408083114.png",
        "image/seal_exp_item_2_sanguo_bright_20260408083259.png",
        "image/seal_exp_item_3_sanguo_bright_20260408083108.png",
    }
    blockingLoadState.totalCount = #blockingRes
    cache:DownloadResources(blockingRes,
        function(success, failedCount)
            print("[DWP] 战斗模块下载完成, success=" .. tostring(success) .. " failed=" .. tostring(failedCount))
            -- 字体重建延迟到主线程执行，避免后台线程调用 cache:GetResource 报错
            fontRebuildNeeded = true
            blockingLoadState.ready = true
            blockingLoadState.progress = 1.0
            -- 菜单装饰后台下载（不阻塞，到 MENU 页时自然显示）
            cache:DownloadResources(menuDecoRes,
                function(s, f)
                    print("[DWP] 菜单装饰资源下载完成, success=" .. tostring(s))
                end, nil
            )
            -- 同时启动后台模块下载（兵甲/武灵/武技/战斗/剧情）
            InitModuleDownloads()
        end,
        function(completed, total, downloadedBytes, totalBytes)
            blockingLoadState.completedCount = completed
            blockingLoadState.totalCount = total
            blockingLoadState.progress = total > 0 and (completed / total) or 0
        end
    )

    SubscribeToEvent(vg, "NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("MouseWheel", "HandleMouseWheel")
    SubscribeToEvent("MultiGesture", "HandleMultiGesture")
    SubscribeToEvent("TextInput", "HandleTextInput")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    SampleInitMouseMode(MM_FREE)

    -- 音频系统初始化
    audioState.scene = Scene()
    audioState.scene:CreateComponent("Octree")
    local listenerNode = audioState.scene:CreateChild("Listener")
    listenerNode:CreateComponent("SoundListener")
    audio:SetListener(listenerNode:GetComponent("SoundListener"))

    audioState.bgmNode = audioState.scene:CreateChild("BGM")
    audioState.bgmSource = audioState.bgmNode:CreateComponent("SoundSource")
    audioState.bgmSource.soundType = "Music"
    audioState.bgmSource.gain = gameSettings.musicVolume

    audioState.sfxNode = audioState.scene:CreateChild("SFX")

    -- 加载设置
    LoadSettings()

    -- 初始化云存档管理器
    CloudManager.Init({
        onBanned = function(level, reason)
            gameState.isBanned = true
            gameState.banReason = reason or ""
        end,
    })

    -- 管理员身份由服务端 Welcome 消息下发（netState.isAdmin），客户端不再保存 UID 列表
    if CloudAPI.IsAvailable() then
        local myUid = CloudAPI.GetUserId()
        print("[系统] 当前玩家 UID: " .. tostring(myUid))
    end

    -- 加载存档 & 每日/周重置
    -- 注意: LoadAll 是异步的，回调执行后才设 saveLoadComplete=true，
    -- update.lua 的 LOADING 阶段同时等待 blockingLoadState.ready + saveLoadComplete，
    -- 避免云存档未加载完就根据默认 profileSet=false 跳到 PROFILE 页
    LoadGameProgress(function()
        saveLoadComplete = true   -- 云存档已加载完毕，允许 LOADING 跳转
        CheckDailyReset()
        CheckWeeklyReset()
        CheckWeeklyRankRewards()

    -- 上报战力和境界到排行榜（启动时一次）
        ReportPowerScore()
        ReportRealmScore()
    -- 加载战力排行榜数据（首页展示用）
        LoadPowerRank()

        -- 补偿跳转: 如果云存档加载完后 profileSet=true，
        -- 但因为超时兜底已经跳到了 PROFILE 页，则立即修正为 MENU
        if playerInfo.profileSet and gameState.phase == "PROFILE" then
            gameState.phase = "MENU"
            print("=== 云存档恢复 profileSet=true，从 PROFILE 补跳到 MENU ===")
        end
    end)

    -- 播放菜单 BGM
    PlayBGM(AUDIO.bgm_menu)

    -- 初始化红点已读状态 (避免开局就亮红点)
    DismissEquipRedDots()
    DismissSkillRedDots()

    -- 排位匹配：后台匹配模式，匹配成功后 ServerReady 事件触发连接
    -- 启动时不连接服务器，仅在排位匹配成功后才初始化网络层
    if rawget(_G, "IsNetworkMode") and IsNetworkMode() then
        SubscribeToEvent("ServerReady", "HandleServerReady")
        print("[Main] 后台匹配模式：等待 ServerReady 事件")
    end

    print("=== 从三国开始争霸天下 v1.0.0 ===")
end
