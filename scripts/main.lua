-- ============================================================================
-- 涓夊浗姝︾伒浼狅細鎴樹簤鐗?v1.0.0
-- 澶у湴鍥惧洖鍚堢瓥鐣?+ 鎴樺満鍗虫椂鎴樻枟 + 姝﹀皢鎶€鑳界⒕鍘?
-- ============================================================================

-- ============================================================================
-- 鏈嶅姟绔ā寮忥細浠呭姞杞?Server.lua锛屼笉鍔犺浇瀹㈡埛绔ā鍧?
-- ============================================================================
if rawget(_G, "IsServerMode") and IsServerMode() then
    local ServerModule = require("network.Server")
    function Start()
        ServerModule.Start()
    end
    function Stop()
        ServerModule.Stop()
    end
    return  -- 鏈嶅姟绔笉鎵ц鍚庣画瀹㈡埛绔唬鐮?
end

require "LuaScripts/Utilities/Sample"

-- 绠＄悊鍛樻瀯寤烘爣蹇楋細鍙戝竷鏃秄alse锛岀鐞嗗憳璋冭瘯鏃惰涓簍rue
IS_ADMIN_BUILD = false

-- 绠＄悊鍛樻ā鍧楁潯浠跺姞杞斤紙浠呭綋 IS_ADMIN_BUILD=true 涓?admin/ 宸插鍒跺埌 scripts/ 鏃剁敓鏁堬級
if IS_ADMIN_BUILD then
    local ok1, m1 = pcall(require, "admin.admin_mail_ui")
    if ok1 then _AdminMailUI = m1 end
    local ok2, m2 = pcall(require, "admin.admin_mail_input")
    if ok2 then _AdminMailInput = m2 end
    local ok3, m3 = pcall(require, "admin.admin_mail_keyboard")
    if ok3 then _AdminMailKeyboard = m3 end
end

-- cjson: 寮曟搸鍐呯疆鍏ㄥ眬鍙橀噺, 鍦ㄤ娇鐢ㄥ灏辫繎澹版槑 (閬垮厤200 upvalue闄愬埗)
GameConfig = require "game_config"
require "EquipUI"
CloudAPI = require "cloud_api"
CloudManager = require "cloud_manager"
TradeManager = require "trade_manager"

-- ============================================================================
-- 妯″潡鍔犺浇
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
-- require "systems.gacha"  -- 宸茬Щ闄ゆ娊鍗＄郴缁?
require "systems.stage_bridge"  -- 浠庡凡鍒犳ā鍧椾腑鎻愬彇鐨勫叡鐢ㄥ嚱鏁?甯冨眬/鎺掍綅/婊″懡妫€娴?娈嬬墖鎺夎惤)
require "systems.hero"
require "systems.misc"
require "systems.phase"
require "systems.rank"
require "systems.rewards"
require "systems.save_system"
require "systems.seal"
require "systems.skill"
-- require "systems.stage"  -- 宸茬Щ闄ゅ叧鍗＄郴缁?
require "systems.tasks"
require "systems.tutorial"
require "systems.slg.slg_main"

-- UI
require "ui.battle_hud"
require "ui.codex"
require "ui.draw_helpers"
-- require "ui.gacha_screen"  -- 宸茬Щ闄ゆ娊鍗I
require "ui.input"
require "ui.menu"
require "ui.screens"
require "ui.seal_screen"
require "ui.settings"
require "ui.social"



-- ============================================================================
-- 妯″潡鍖栬祫婧愪笅杞?(闃诲瀹屾垚鍚庡苟琛屽惎鍔?4 涓ā鍧?
-- ============================================================================

--- 鎬诲叆鍙ｏ細鍚姩鍏ㄩ儴 4 涓ā鍧楃殑鍚庡彴涓嬭浇
function InitModuleDownloads()
    if downloadUI.modulesInited then return end
    downloadUI.modulesInited = true
    print("[DWP] 鍚姩 5 涓ā鍧楀悗鍙颁笅杞?..")
    InitModuleEquipment()
    InitModuleHeroes()
    InitModuleSkills()
    InitModuleBattle()
end


--- 妯″潡1: 鍏电敳璧勬簮
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
            print("[DWP] 鍏电敳妯″潡涓嬭浇瀹屾垚, success=" .. tostring(success))
        end,
        function(completed, total)
            ms.completedCount = completed; ms.totalCount = total
            ms.progress = total > 0 and (completed / total) or 0
        end
    )
end


--- 妯″潡2: 姝︾伒璧勬簮
function InitModuleHeroes()
    local ms = moduleState.heroes
    -- 涓夊浗姝︾伒鐙珛鍥?(hero1-hero40)
    for i = 1, 40 do
        local key = "hero" .. i
        IMG[key] = nvgCreateImage(vg, "image/hero_" .. i .. ".png", 0)
    end
    -- 鏁屾柟鐙珛绔嬬粯 (enemy1-enemy16)
    for i = 1, 16 do
        local key = "enemy" .. i
        IMG[key] = nvgCreateImage(vg, "image/enemy_" .. i .. ".png", 0)
    end

    local resList = {}
    for i = 1, 40 do
        resList[i] = "image/hero_" .. i .. ".png"
    end
    for i = 1, 16 do
        resList[40 + i] = "image/enemy_" .. i .. ".png"
    end
    ms.totalCount = #resList
    ms.downloading = true
    cache:DownloadResources(resList,
        function(success, failedCount)
            ms.ready = true; ms.downloading = false; ms.progress = 1.0
            print("[DWP] 姝︾伒妯″潡涓嬭浇瀹屾垚, success=" .. tostring(success))
        end,
        function(completed, total)
            ms.completedCount = completed; ms.totalCount = total
            ms.progress = total > 0 and (completed / total) or 0
        end
    )
end


--- 妯″潡3: 姝︽妧璧勬簮
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
            print("[DWP] 姝︽妧妯″潡涓嬭浇瀹屾垚, success=" .. tostring(success))
        end,
        function(completed, total)
            ms.completedCount = completed; ms.totalCount = total
            ms.progress = total > 0 and (completed / total) or 0
        end
    )
end


--- 妯″潡4: 鎴樻枟璧勬簮
function InitModuleBattle()
    local ms = moduleState.battle

    -- 甯冨眬宸插唴缃负榛樿鍊硷紝涓嶅啀浠庢枃浠跺姞杞?
    -- LoadBattleLayouts()

    IMG.bg = nvgCreateImage(vg, "image/battle_bg_1.png", 0)
    IMG.skillSheet = nvgCreateImage(vg, "image/skill_fentianjue.png", 0)

    -- 涓栫晫鍦板浘绱犳潗
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

    -- Q钀屽浗椋庢柊鑳屾櫙
    IMG.codexBg = nvgCreateImage(vg, "image/codex_bg_20260415173024.png", 0)
    IMG.settingsBg = nvgCreateImage(vg, "image/settings_bg_20260415173050.png", 0)
    IMG.deployBg = nvgCreateImage(vg, "image/deploy_bg_20260415172852.png", 0)
    IMG.homeBg = nvgCreateImage(vg, "image/home_bg_20260415173103.png", 0)
    IMG.panelBg = nvgCreateImage(vg, "image/panel_bg_new_20260416000416.png", 0)
    IMG.battleBgNew = nvgCreateImage(vg, "image/battle_bg_20260415172845.png", 0)
    -- 鏂板煄姹犲浘鏍囦笌鏃楀笢
    IMG.cityFriendly = nvgCreateImage(vg, "image/city_icon_friendly_20260415173137.png", 0)
    IMG.cityEnemy = nvgCreateImage(vg, "image/city_icon_enemy_20260415173221.png", 0)
    IMG.cityNeutral = nvgCreateImage(vg, "image/city_icon_neutral_20260415173305.png", 0)
    IMG.btnDeploy = nvgCreateImage(vg, "image/btn_deploy_20260415173149.png", 0)
    IMG.flagShu = nvgCreateImage(vg, "image/faction_flag_shu_20260415173130.png", 0)
    IMG.flagWei = nvgCreateImage(vg, "image/faction_flag_wei_20260415173135.png", 0)
    IMG.flagWu = nvgCreateImage(vg, "image/faction_flag_wu_20260416015845.png", 0)
    IMG.flagQun = nvgCreateImage(vg, "image/faction_flag_qun_20260416015756.png", 0)
    IMG.btnPause = nvgCreateImage(vg, "image/btn_pause_20260416015754.png", 0)
    IMG.wmBgClean = nvgCreateImage(vg, "image/world_map_bg_clean_20260416015728.png", 0)

    -- 鍏电缁忛獙閬撳叿鍥剧墖
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

    for idx, fx in pairs(SKILL_FX_SHEETS) do
        fx.handle = nvgCreateImage(vg, fx.file, 0)
    end

    IMG.abyssBg = {}
    IMG.abyssBg[1] = nvgCreateImage(vg, "image/battle_bg_2.png", 0)
    IMG.abyssBg[2] = nvgCreateImage(vg, "image/battle_bg_3.png", 0)
    IMG.abyssBg[3] = nvgCreateImage(vg, "image/battle_bg_4.png", 0)
    IMG.abyssBg[4] = nvgCreateImage(vg, "image/battle_bg_5.png", 0)
    IMG.abyssBg[5] = nvgCreateImage(vg, "image/battle_bg_6.png", 0)
    IMG.abyssBg[6] = nvgCreateImage(vg, "image/battle_bg_7.png", 0)
    IMG.abyssBg[7] = nvgCreateImage(vg, "image/battle_bg_8.png", 0)
    -- 鍒濆鍖栨垬鏂楀竷灞€鑳屾櫙鍙ユ焺: 榛樿鎴樺満鏃犺儗鏅?nil), 璁ㄤ紣澶嶇敤 IMG.abyssBg
    BATTLE_LAYOUTS[1].bgHandle = IMG.bg  -- 榛樿鎴樺満浣跨敤鏂拌儗鏅浘
    for i = 1, 7 do
        BATTLE_LAYOUTS[i + 1].bgHandle = IMG.abyssBg[i]
    end

    -- 鐭冲彴搴曞骇鍥剧墖 (閫忔槑鑳屾櫙, 鐙珛浜庢垬鏂楄儗鏅?
    IMG.platform = {}
    IMG.platform.default = nvgCreateImage(vg, "image/platform_default_20260408122937.png", 0)
    IMG.platform.shu     = nvgCreateImage(vg, "image/platform_shu_20260408122914.png", 0)
    IMG.platform.wu      = nvgCreateImage(vg, "image/platform_wu_20260408122920.png", 0)
    IMG.platform.wei     = nvgCreateImage(vg, "image/platform_wei_20260408122920.png", 0)
    -- 姣忎釜甯冨眬缁戝畾瀵瑰簲鐭冲彴鏍峰紡: 榛樿+1-2灞?铚€, 3-4灞?鍚? 5-7灞?榄?
    BATTLE_LAYOUTS[1].platformImg = IMG.platform.shu      -- 榛樿鎴樺満
    BATTLE_LAYOUTS[2].platformImg = IMG.platform.shu      -- 璁ㄤ紣1灞?
    BATTLE_LAYOUTS[3].platformImg = IMG.platform.shu      -- 璁ㄤ紣2灞?
    BATTLE_LAYOUTS[4].platformImg = IMG.platform.wu       -- 璁ㄤ紣3灞?
    BATTLE_LAYOUTS[5].platformImg = IMG.platform.wu       -- 璁ㄤ紣4灞?
    BATTLE_LAYOUTS[6].platformImg = IMG.platform.wei      -- 璁ㄤ紣5灞?
    BATTLE_LAYOUTS[7].platformImg = IMG.platform.wei      -- 璁ㄤ紣6灞?
    BATTLE_LAYOUTS[8].platformImg = IMG.platform.wei      -- 璁ㄤ紣7灞?
    -- 绋嬪簭鍖栫煶鍙伴樀钀ヨ壊 (鏇夸唬鍥剧墖鐭冲彴)
    BATTLE_LAYOUTS[1].platformFaction = "shu"
    BATTLE_LAYOUTS[2].platformFaction = "shu"
    BATTLE_LAYOUTS[3].platformFaction = "shu"
    BATTLE_LAYOUTS[4].platformFaction = "wu"
    BATTLE_LAYOUTS[5].platformFaction = "wu"
    BATTLE_LAYOUTS[6].platformFaction = "wei"
    BATTLE_LAYOUTS[7].platformFaction = "wei"
    BATTLE_LAYOUTS[8].platformFaction = "wei"

    IMG.abyssIcon = {}
    IMG.abyssIcon[1] = nvgCreateImage(vg, "image/abyss_icon_1_sanguo_bright_20260408083110.png", 0)
    IMG.abyssIcon[2] = nvgCreateImage(vg, "image/abyss_icon_2_sanguo_bright_20260408083150.png", 0)
    IMG.abyssIcon[3] = nvgCreateImage(vg, "image/abyss_icon_3_sanguo_bright_20260408083102.png", 0)
    IMG.abyssIcon[4] = nvgCreateImage(vg, "image/abyss_icon_4_sanguo_bright_20260408083119.png", 0)
    IMG.abyssIcon[5] = nvgCreateImage(vg, "image/abyss_icon_5_sanguo_bright_20260408083103.png", 0)
    IMG.abyssIcon[6] = nvgCreateImage(vg, "image/abyss_icon_6_sanguo_bright_20260408083117.png", 0)
    IMG.abyssIcon[7] = nvgCreateImage(vg, "image/abyss_icon_7_sanguo_bright_20260408083114.png", 0)

    local battleRes = {
        "image/battle_bg_1.png",
        "image/skill_fentianjue.png",
        "image/battle_bg_topdown_stage6.png",
        "image/abyss_select_sanguo_bright_20260408082708.png",
    }
    -- 鎴樺満鑳屾櫙 2-8
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
    -- Q钀屽浗椋庢柊鑳屾櫙涓嶶I鍏冪礌
    battleRes[#battleRes + 1] = "image/codex_bg_20260415173024.png"
    battleRes[#battleRes + 1] = "image/settings_bg_20260415173050.png"
    battleRes[#battleRes + 1] = "image/deploy_bg_20260415172852.png"
    battleRes[#battleRes + 1] = "image/home_bg_20260415173103.png"
    battleRes[#battleRes + 1] = "image/panel_bg_20260415173049.png"
    battleRes[#battleRes + 1] = "image/battle_bg_20260415172845.png"
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
            print("[DWP] 鎴樻枟妯″潡涓嬭浇瀹屾垚, success=" .. tostring(success) .. " failed=" .. tostring(failedCount))
        end,
        function(completed, total, downloadedBytes, totalBytes)
            ms.completedCount = completed; ms.totalCount = total
            ms.progress = total > 0 and (completed / total) or 0
        end
    )
end


-- ============================================================================
-- 鎺掍綅鍖归厤鐢熷懡鍛ㄦ湡锛堝悗鍙板尮閰嶆ā寮忥級
-- ============================================================================

--- Legacy room-match callback kept as a no-op while the project uses persistent servers.
function HandleServerReady(eventType, eventData)
    print("[Main] Ignoring legacy ServerReady event; persistent server flow is active")
end

-- ============================================================================
-- 鍒濆鍖?
-- ============================================================================

function Start()
    SampleStart()

    CloudAPI.Init()

    vg = nvgCreate(1)
    if not vg then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    -- 瀛椾綋鍒濆鍖? 榛樿浣跨敤椤圭洰鍐呭彲鐢ㄧ殑鏂囨シ瀛椾綋
    fontId = nvgCreateFont(vg, "sans", "Fonts/LXGWWenKai-Regular.ttf")

    -- ========== 闃诲闃舵: 棣栭〉蹇呴渶璧勬簮鍏ㄩ儴涓嬭浇瀹屾墠杩涘叆 ==========
    -- 鍒涘缓 NanoVG 鍙ユ焺锛圖WP 鍗犱綅锛?
    IMG.menuBg = nvgCreateImage(vg, "image/edited_menu_bg_no_panel_20260416004055.png", 0)
    IMG.scrollPanel = nvgCreateImage(vg, "image/edited_scroll_panel_wide_20260416015015.png", 0)
    IMG.btnMenuPrimary = nvgCreateImage(vg, "image/btn_menu_primary_20260416015609.png", 0)
    IMG.btnMenuNormal = nvgCreateImage(vg, "image/btn_menu_normal_20260416015645.png", 0)
    IMG.avatarSheet = nvgCreateImage(vg, "image/avatars_q_cute.png", 0)
    IMG.cloudA = nvgCreateImage(vg, "image/cloud_a_sanguo_bright_20260408082912.png", 0)
    IMG.cloudB = nvgCreateImage(vg, "image/cloud_b_sanguo_bright_20260408082858.png", 0)
    IMG.playerPanel = nvgCreateImage(vg, "image/player_panel_sanguo_bright_20260408082842.png", 0)
    IMG.dragonPortal = nvgCreateImage(vg, "image/icon_zhanling_v3_20260409100724.png", 0)   -- 鎴樹护
    IMG.taofaIcon = nvgCreateImage(vg, "image/icon_taofa_v3_20260409100723.png", 0)       -- 璁ㄤ紣
    IMG.treasureChest = nvgCreateImage(vg, "image/treasure_chest_new_20260408104225.png", 0)
    IMG.btnCodex = nvgCreateImage(vg, "image/btn_frame_sanguo_20260408091405.png", 0)
    -- comic1/comic2 + introVideo 宸茬Щ闄わ紙鏂版墜寮曞涓嶅啀浣跨敤寮€鍦鸿棰?婕敾锛?
    IMG.abyssTicket = nvgCreateImage(vg, "image/icon_pata_v4_20260409100707.png", 0)  -- 涔变笘寰侀€?鐖

    -- 鎴樹护涓撶敤鍥炬爣 (鏇夸唬 emoji)
    IMG.bpIconJade = nvgCreateImage(vg, "image/bp_icon_jade_20260409103401.png", 0)
    IMG.bpIconFrag = nvgCreateImage(vg, "image/bp_icon_frag_20260409103349.png", 0)
    IMG.bpIconEquip = nvgCreateImage(vg, "image/bp_icon_equip_20260409103351.png", 0)
    IMG.bpIconExp = nvgCreateImage(vg, "image/bp_icon_exp_20260409103404.png", 0)
    IMG.bpIconCheck = nvgCreateImage(vg, "image/bp_icon_check_20260409103343.png", 0)
    IMG.bpIconLock = nvgCreateImage(vg, "image/bp_icon_lock_20260409103359.png", 0)
    IMG.bpIconMilestone = nvgCreateImage(vg, "image/bp_icon_milestone_20260409103351.png", 0)
    IMG.bpBanner = nvgCreateImage(vg, "image/bp_banner_20260409103340.png", 0)

    -- 鎴樹护鍥介瑁呴グ绱犳潗
    IMG.bpFrameCorner = nvgCreateImage(vg, "image/bp_frame_corner_20260409104818.png", 0)
    IMG.bpCardGold = nvgCreateImage(vg, "image/bp_card_overlay_gold_20260409104823.png", 0)
    IMG.bpCardBlue = nvgCreateImage(vg, "image/bp_card_overlay_blue_20260409104825.png", 0)
    IMG.bpBadgeVip = nvgCreateImage(vg, "image/bp_track_badge_vip_20260409104820.png", 0)
    IMG.bpBadgeFree = nvgCreateImage(vg, "image/bp_track_badge_free_20260409104824.png", 0)
    IMG.bpDivider = nvgCreateImage(vg, "image/bp_divider_deco_20260409104810.png", 0)

    -- 鑿滃崟鍏ュ彛鍥炬爣 (鍥介浜屾鍏冮鏍硷紝杞荤泩鏄庝寒)
    IMG.menuIcons = {}
    IMG.menuIcons[1]  = nvgCreateImage(vg, "image/icon_wulinglu_v2_20260409092052.png", 0)    -- 姝︾伒褰?
    IMG.menuIcons[2]  = nvgCreateImage(vg, "image/icon_bingji_v3_20260409095902.png", 0)      -- 鍏电敳
    IMG.menuIcons[3]  = nvgCreateImage(vg, "image/icon_tulu_v2_20260409092109.png", 0)        -- 鍏电敳鍥惧綍
    IMG.menuIcons[4]  = nvgCreateImage(vg, "image/icon_wuji_v2_20260409092118.png", 0)        -- 姝︽妧
    IMG.menuIcons[5]  = nvgCreateImage(vg, "image/icon_cifu_v3_20260409095904.png", 0)        -- 澶╁懡璧愮
    IMG.menuIcons[6]  = nvgCreateImage(vg, "image/icon_renwu_v3_20260409095925.png", 0)       -- 姣忔棩浠诲姟
    IMG.menuIcons[7]  = nvgCreateImage(vg, "image/icon_paiwei_v3_20260409100755.png", 0)      -- 鎺掍綅
    IMG.menuIcons[8]  = nvgCreateImage(vg, "image/icon_zhenying_v3_20260409095857.png", 0)    -- 闃佃惀
    IMG.menuIcons[9]  = nvgCreateImage(vg, "image/icon_haoyou_v2_20260409092321.png", 0)      -- 濂藉弸
    IMG.menuIcons[10] = nvgCreateImage(vg, "image/icon_youjian_v3_20260409095937.png", 0)     -- 閭欢
    IMG.menuIcons[11] = nvgCreateImage(vg, "image/icon_zhaohuan_v2_20260409093140.png", 0)    -- 鍙敜姝︾伒
    IMG.menuIcons[12] = nvgCreateImage(vg, "image/icon_zhanlibang_v2_20260409093144.png", 0)  -- 鎴樺姏姒?
    IMG.menuIcons[13] = nvgCreateImage(vg, "image/icon_shezhi_v3_20260409095935.png", 0)      -- 璁剧疆
    IMG.menuIcons[14] = nvgCreateImage(vg, "image/icon_trade_20260411014554.png", 0)        -- 浜ゆ槗琛?
    IMG.menuIcons[15] = nvgCreateImage(vg, "image/icon_biandui_v2_20260411051928.png", 0)    -- 缂栭槦
    IMG.sealItem1 = nvgCreateImage(vg, "image/icon_tansuo_v4_20260409100758.png", 0)   -- 鎺㈢储
    IMG.sealItem2 = nvgCreateImage(vg, "image/icon_pata_v4_20260409100707.png", 0)   -- 鐖(涔变笘寰侀€斿瓙椤?
    IMG.sealItem3 = nvgCreateImage(vg, "image/icon_fuben_v3_20260409100805.png", 0)  -- 鍓湰

    -- 闃诲涓嬭浇锛氬瓧浣撲紭鍏?+ 棣栧睆蹇呴渶璧勬簮锛堝噺灏戝姞杞芥椂闂达級
    local blockingRes = {
        "Fonts/LXGWWenKai-Regular.ttf",

        "image/avatars_sanguo_v2_20260408082207.png",
        "image/home_bg_sanguo_bright_20260408082713.png",
    }
    -- 鏂版墜寮曞鏍稿績璧勬簮锛氫粎寮€鍦烘极鐢伙紙tutorial step 1 蹇呴渶锛屽叾浣欏悗鍙颁笅杞斤級
    local tutorialRes = {
    }
    -- 鑿滃崟瑁呴グ + 鎸夐挳鍥剧墖锛坱utorial step 2-5 闇€瑕侊紝鍚庡彴涓嬭浇涓嶉樆濉烇級
    local menuDecoRes = {
        "image/cloud_a_sanguo_bright_20260408082912.png",
        "image/cloud_b_sanguo_bright_20260408082858.png",
        "image/title_scroll_sanguo_bright_20260408082855.png",
        "image/player_panel_sanguo_bright_20260408082842.png",
        "image/portal_sanguo_bright_20260408082840.png",
        "image/treasure_chest_sanguo_bright_20260408082844.png",
        "image/btn_frame_sanguo_bright_20260408082840.png",
        -- 鑿滃崟鍏ュ彛鍥炬爣
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
            print("[DWP] 闃诲璧勬簮涓嬭浇瀹屾垚, success=" .. tostring(success) .. " failed=" .. tostring(failedCount))
            -- 瀛椾綋閲嶅缓寤惰繜鍒颁富绾跨▼鎵ц锛岄伩鍏嶅悗鍙扮嚎绋嬭皟鐢?cache:GetResource 鎶ラ敊
            fontRebuildNeeded = true
            blockingLoadState.ready = true
            blockingLoadState.progress = 1.0
            -- 涓嬭浇鏂版墜寮曞鏍稿績璧勬簮锛圥ROFILE 椤靛睍绀鸿繘搴︽潯锛屼粎婕敾2涓枃浠讹級
            tutorialLoadState.totalCount = #tutorialRes
            cache:DownloadResources(tutorialRes,
                function(s, f)
                    tutorialLoadState.ready = true
                    tutorialLoadState.progress = 1.0
                    print("[DWP] 鏂版墜寮曞鏍稿績璧勬簮涓嬭浇瀹屾垚, success=" .. tostring(s))
                end,
                function(completed, total, downloadedBytes, totalBytes)
                    tutorialLoadState.completedCount = completed
                    tutorialLoadState.totalCount = total
                    tutorialLoadState.progress = total > 0 and (completed / total) or 0
                end
            )
            -- 鑿滃崟瑁呴グ鍚庡彴涓嬭浇锛堜笉闃诲锛屽埌 MENU 椤垫椂鑷劧鏄剧ず锛?
            cache:DownloadResources(menuDecoRes,
                function(s, f)
                    print("[DWP] 鑿滃崟瑁呴グ璧勬簮涓嬭浇瀹屾垚, success=" .. tostring(s))
                end, nil
            )
            -- 鍚屾椂鍚姩鍚庡彴妯″潡涓嬭浇锛堝叺鐢?姝︾伒/姝︽妧/鎴樻枟/鍓ф儏锛?
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

    -- 闊抽绯荤粺鍒濆鍖?
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

    -- 鍔犺浇璁剧疆
    LoadSettings()

    -- 鍒濆鍖栦簯瀛樻。绠＄悊鍣?
    CloudManager.Init({
        onBanned = function(level, reason)
            gameState.isBanned = true
            gameState.banReason = reason or ""
        end,
    })

    -- 璁剧疆绠＄悊鍛?UID 鍒楄〃 (寮€鍙戣€呯殑娓告垙鍐呬簯 UID)
    -- 娉ㄦ剰: 棣栨杩愯鏃跺湪鎺у埗鍙版煡鐪嬫墦鍗扮殑 UID, 鐒跺悗濉叆姝ゅ垪琛?
    CloudManager.ADMIN_UIDS = { 162525390 }
    if CloudAPI.IsAvailable() then
        local myUid = CloudAPI.GetUserId()
        print("============================================")
        print("[绯荤粺] 褰撳墠鐜╁ UID: " .. tostring(myUid))
        print("============================================")
    end

    -- 鍔犺浇瀛樻。 & 姣忔棩/鍛ㄩ噸缃?
    LoadGameProgress(function()
        CheckDailyReset()
        CheckWeeklyReset()
        CheckWeeklyRankRewards()

    -- 涓婃姤鎴樺姏鍜屽鐣屽埌鎺掕姒滐紙鍚姩鏃朵竴娆★級
        ReportPowerScore()
        ReportRealmScore()
    -- 鍔犺浇鎴樺姏鎺掕姒滄暟鎹紙棣栭〉灞曠ず鐢級
        LoadPowerRank()
    end)

    -- 鎾斁鑿滃崟 BGM
    PlayBGM(AUDIO.bgm_menu)

    -- 鍒濆鍖栫孩鐐瑰凡璇荤姸鎬?(閬垮厤寮€灞€灏变寒绾㈢偣)
    DismissEquipRedDots()
    DismissSkillRedDots()

    -- 甯搁┗鏈嶅姟鍣ㄦā寮忥細CloudAPI.Init 浼氬湪鍚姩鏃剁珛鍗冲垵濮嬪寲鑱旀満灞?    if rawget(_G, "IsNetworkMode") and IsNetworkMode() then
        print("[Main] 甯搁┗鏈嶅姟鍣ㄦā寮忥細鍚姩鏃剁珛鍗宠繛鎺ユ湇鍔＄")
    end

    print("=== 涓夊浗姝︾伒褰?v5.0 ===")
end
