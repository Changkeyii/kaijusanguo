-- ============================================================================
-- G_systems.lua - 涓夊浗姝︾伒褰?(浠?G.lua 鎷嗗垎)
-- ============================================================================

-- ============================================================================
-- 姣忔棩鍓湰绯荤粺 (鍏ㄥ眬)
-- ============================================================================
DAILY_DUNGEON_NAMES = { "閾搁瓊鐐煎櫒", "瀹氬悜鐚庤", "娣锋矊璇曠偧" }
DAILY_DUNGEON_DESCS = {
    "蹇呭嚭鎸囧畾閮ㄤ綅瑁呭 (閮ㄤ綅姣忔棩闅忔満)",
    "蹇呭嚭鎸囧畾濂楄瑁呭 (鍙€夋嫨濂楄)",
    "灏嗗搧鍙婁互涓婄垎鐜嚸?0 绾殢鏈?,
}
DAILY_DUNGEON_COLORS = {
    { 80, 200, 160 },   -- 缁?
    { 100, 160, 255 },  -- 钃?
    { 220, 120, 255 },  -- 绱?
}
DAILY_DUNGEON_ICONS = { "閿?, "鐚?, "娣? }

dailyDungeonState = {
    lastResetDay = "",
    completed = { false, false, false }, -- 浠婃棩鏄惁宸插畬鎴?
    todaySlot = 1,         -- 鍓湰1: 浠婃棩闅忔満閮ㄤ綅 (1-7)
    selectedSet = 1,       -- 鍓湰2: 鐜╁閫夋嫨鐨勫瑁?(1-7)
    selectedDungeon = nil, -- 褰撳墠閫変腑鐨勫壇鏈?(1-3)
    showConfirm = false,   -- 鏄惁鏄剧ず纭寮圭獥
}
dailyDungeonCardRects = {} -- 涓変釜鍓湰鍗＄墖鐐瑰嚮鍖哄煙
dailyDungeonBackRect = nil
dailyDungeonConfirmBtnRect = nil
dailyDungeonCloseRect = nil
dailyDungeonSetBtnRects = {} -- 鍓湰2: 7涓瑁呴€夋嫨鎸夐挳

-- 鎺㈢储璧勬簮鍓湰鐘舵€?
resourceDungeonState = {
    lastResetDay = "",
    completed = { false, false, false },  -- 涓夌鍓湰浠婃棩鏄惁閫氬叧
    selectedType = nil,     -- 褰撳墠閫変腑鐨勫壇鏈被鍨?(1-3)
    showConfirm = false,    -- 鏄剧ず纭寮圭獥
    showSelect = false,     -- 鏄剧ず閫夋嫨鐣岄潰
}
resourceDungeonCardRects = {}
resourceDungeonBackRect = nil
resourceDungeonConfirmRect = nil

-- ============================================================================
-- 鎴樹护閫氳璇佺姸鎬?
-- ============================================================================
battlePassState = {
    seasonStartDay = "",        -- 璧涘寮€濮嬫棩鏈?(YYYY-MM-DD)
    level = 0,                  -- 褰撳墠绛夌骇 (0=鏈В閿佺1绾?
    exp = 0,                    -- 褰撳墠绛夌骇鍐呯粡楠?
    -- 浠诲姟杩涘害 (姣忔棩/姣忓懆/璧涘鍒嗗紑杩借釜)
    dailyProgress = {},         -- { bp_battle3 = 2, ... }
    weeklyProgress = {},
    seasonProgress = {},
    -- 浠诲姟棰嗗彇鏍囪
    dailyClaimed = {},          -- { bp_battle3 = true }
    weeklyClaimed = {},
    seasonClaimed = {},
    -- 濂栧姳棰嗗彇鏍囪
    freeRewardClaimed = {},     -- { [1] = true, [2] = true, ... }
    premiumRewardClaimed = {},  -- { [1] = true, ... } (鐪嬪箍鍛婇鍙?
    -- 閲嶇疆鏍囪
    lastDailyReset = "",
    lastWeeklyReset = "",
}
battlePassUIState = {
    tab = 1,                    -- 1=濂栧姳鎬昏 2=姣忔棩浠诲姟 3=鍛ㄤ换鍔?4=璧涘浠诲姟
    scrollY = 0,
    isDragging = false,
    dragStartY = 0,
    dragStartScroll = 0,
    rewardScrollX = 0,          -- 濂栧姳妯悜婊氬姩
    isDraggingReward = false,
    dragStartX = 0,
    dragStartScrollX = 0,
}
battlePassBackRect = nil
battlePassTabRects = {}
battlePassTaskBtnRects = {}
battlePassRewardRects = {}
battlePassClaimFreeRects = {}
battlePassClaimPremiumRects = {}

-- 鍥鹃壌鐣岄潰鐘舵€?
codexBackBtnRect = nil    -- 鍥鹃壌鐣岄潰杩斿洖鎸夐挳

-- 鎴樻枟杩斿洖鎸夐挳
battleBackBtnRect = nil

-- 绮剧伒鍥惧弬鏁?(鑻遍泟4x4, 鏁屼汉4x4)
SHEET_COLS = 4
SHEET_ROWS = 4
-- 澶村儚绮剧伒鍥惧弬鏁?(2鍒梮3琛?
AVATAR_COLS = 2
AVATAR_ROWS = 3
-- 鍚勮嫳闆勭簿鐏靛浘鐨勭綉鏍奸厤缃?
SHEET_CONFIG = {
    [1] = { cols = 4, rows = 4, imgW = 714, imgH = 1280 },  -- hero_cards.jpg (4脳4)
    [2] = { cols = 3, rows = 3, imgW = 714, imgH = 1280 },  -- hero_cards_nobg.jpg (3脳3)
    [4] = { cols = 4, rows = 4, imgW = 714, imgH = 1280 },  -- hero_cards_extra.jpg (4脳4)
}
-- 璁＄畻姣忎釜绮剧伒鍥剧殑鍗曟牸瀹介珮姣?
for _, cfg in pairs(SHEET_CONFIG) do
    cfg.cellRatio = (cfg.imgW / cfg.cols) / (cfg.imgH / cfg.rows)
end
-- 鏃犺儗鏅増绮剧伒鍥剧殑缃戞牸閰嶇疆 (edited nobg 鐗堟湰灏哄涓嶅悓)
NOBG_SHEET_CONFIG = {
    [1] = { cols = 4, rows = 4, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_s1_nobg (4脳4)
    [2] = { cols = 3, rows = 3, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_nobg (3脳3, 鍚竻娉犳硶濮瓑)
    [4] = { cols = 4, rows = 4, imgW = 1237, imgH = 1536 },  -- edited_hero_cards_extra_nobg (4脳4)
}
for _, cfg in pairs(NOBG_SHEET_CONFIG) do
    cfg.cellRatio = (cfg.imgW / cfg.cols) / (cfg.imgH / cfg.rows)  -- 鈮?.806
end
-- 瑁呭绮剧伒鍥惧弬鏁?(7鍒?7濂? 7琛?7閮ㄤ綅)
EQUIP_SHEET_COLS = 7
EQUIP_SHEET_ROWS = 7

-- 浠撳簱鏍煎瓙瀹归噺
BASE_EQUIP_SLOTS = 20     -- 鍒濆涓婇檺
UNLOCK_PER_AD_SLOTS = 5   -- 姣忔骞垮憡瑙ｉ攣

-- 鑳屾櫙鍥惧師濮嬪昂瀵?
BG_W = 714
BG_H = 1280

-- 璁捐鍒嗚鲸鐜?(妯睆, SHOW_ALL)
DESIGN_W = 1024
DESIGN_H = 571

BG2D_X = DESIGN_W / BG_W
BG2D_Y = DESIGN_H / BG_H

-- 鍗＄墝鏄剧ず姣斾緥 (鍖归厤姝﹀皢鍥剧墖 515x768)
CARD_RATIO = 515 / 768

-- 鐭冲彴涓婄殑鍗＄墝灏哄
SLOT_CARD_W = 42
SLOT_CARD_H = 42 / CARD_RATIO

-- 灞忓箷瀹為檯灏哄 & SHOW_ALL 鍙樻崲
screenW = 0
screenH = 0
scale = 1.0
offsetX = 0
offsetY = 0

-- 鍒樻捣灞忓畨鍏ㄥ尯 (璁捐鍧愭爣鍗曚綅, 姣忓抚鏇存柊)
safeInsets = { top = 0, bottom = 0, left = 0, right = 0 }

-- ============================================================================
-- 瑙︽懜鍧愭爣绯昏嚜鍔ㄦ娴?(鍗庝负/HarmonyOS 鍏煎)
-- 鏌愪簺璁惧鐨勮Е鎽镐簨浠惰繑鍥為€昏緫鍍忕礌鑰岄潪鐗╃悊鍍忕礌锛岄渶瑕佽嚜鍔ㄦ娴嬪苟閫傞厤
-- ============================================================================
touchCoordDPR = nil        -- 瀹為檯鐢ㄤ簬瑙︽懜鍧愭爣杞崲鐨?DPR锛坣il=灏氭湭妫€娴嬶級
_touchDetectSamples = 0    -- 宸查噰闆嗙殑鏍锋湰鏁?
_touchDetectMax = 8        -- 鏈€澶氶噰闆?N 涓牱鏈悗閿佸畾
_touchExceedsLogical = false -- 鏄惁鏈夎Е鎽稿潗鏍囪秴鍑洪€昏緫鑼冨洿
_deviceInfoLogged = false  -- 璁惧淇℃伅鏄惁宸叉墦鍗?

-- 搴曢儴鍟嗗簵棰勭暀楂樺害 (閫昏緫鍍忕礌)
SHOP_RESERVED_H = 115

-- 鐩镐綅鍒囨崲闃茬┛閫忓喎鍗?(绉?
phaseChangeCooldown = 0

-- 閫忔槑鐗堢簿鐏靛浘姣忔牸姣斾緥
NOBG_CELL_RATIO = (1237 / SHEET_COLS) / (1536 / SHEET_ROWS) -- 鏁屾柟 鈮?.806
-- 骞垮憡鎸夐挳鍖哄煙
adRects = { jade = nil, refresh = nil, revive = nil, battleGold = nil }
autoMarchBtnRect = nil    -- 鑷姩琛屽啗鎸夐挳
skillBtnRects = {}        -- 姝︽妧鎶€鑳芥寜閽?[slot] >> rect

-- 鑷姩琛屽啗绛栫暐杞洏
strategyWheelState = {
    show = false,       -- 鏄惁鏄剧ず杞洏
    pressing = false,   -- 鏄惁姝ｅ湪闀挎寜鑷姩琛屽啗鎸夐挳
    startTime = 0,      -- 鎸変笅鏃堕棿
    touchId = -1,       -- 瑙︽帶ID
    sx = 0, sy = 0,     -- 鎸変笅鐨勫睆骞曞潗鏍?
    selected = 0,       -- 褰撳墠閫変腑鐨勭瓥鐣ョ储寮?(1/2/3, 0=鏃?
}
STRATEGY_LONG_PRESS = 0.15  -- 闀挎寜闃堝€?绉?
-- 绛栫暐鍒楄〃
MARCH_STRATEGIES = {
    { id = "all_lanes",   name = "浜旇矾骞惰繘", desc = "闅忔満鍒嗛厤鍏ㄩ儴杞﹂亾", color = { 120, 220, 160 } },
    { id = "mid_focus",   name = "鍏ㄦ涓矾", desc = "闆嗕腑鍏靛姏鏀诲嚮涓矾", color = { 255, 200, 80  } },
    { id = "side_spread", name = "鍒嗘暎渚х考", desc = "渚х考鍖呮妱鍒嗘暎杩涙敾", color = { 100, 180, 255 } },
}

-- 鑷姩閲婃斁鎶€鑳借鏃?
autoSkillState = {
    timer = 0,
    interval = 5.0,     -- 姣?绉掕嚜鍔ㄩ噴鏀句竴娆?
    nextTime = 3.0,     -- 棣栨寤惰繜3绉?
}

-- 鎴樻枟瑙勫垯寮圭獥
battleRulesState = {
    show = false,
    scrollY = 0,        -- 婊氬姩鍋忕Щ
    contentH = 0,       -- 鍐呭鎬婚珮搴?
    viewH = 0,          -- 鍙鍖哄煙楂樺害
    isDragging = false,
    lastTouchY = 0,
    vel = 0,            -- 婊氬姩鎯€ч€熷害
}
battleRuleBtnRect = nil

-- 缁熶竴瑙勫垯寮圭獥鐘舵€?(鎵€鏈夌晫闈㈤€氱敤)
phaseRulePopup = {
    show = false,
    phase = "",         -- 褰撳墠鏄剧ず鐨勭晫闈hase
    scrollY = 0,
    contentH = 0,
    viewH = 0,
    isDragging = false,
    lastTouchY = 0,
    vel = 0,
    closeBtnRect = nil,
    panelRect = nil,
}
-- phaseHelpBtnRect 鍚堝苟鍒?phaseRulePopup.helpBtnRect 浠ヨ妭鐪?upvalue

-- 鍚勭晫闈㈣鍒欏唴瀹瑰畾涔?
PHASE_RULES = {
    MENU = {
        title = "娓告垙鎸囧崡",
        color = { 160, 80, 100 },  -- 绱孩
        rules = {
            { "鏍稿績鐜╂硶", "璐拱姝︾伒鍗＄墝鈫掓斁鍒扮煶鍙颁笂闃碘啋寮€鎴樺悗鎷栨嫿姝︾伒鍒拌溅閬撴淳鍏碘啋鍑荤牬鏁屾柟澶ф湰钀ヨ幏鑳溿€? },
            { "鍟嗗簵涓庡啗璧?, "姣忓眬寮€濮嬫湁鍐涜祫鍙喘涔版鐏碉紝鎴樻枟涓啗璧勪細闅忔椂闂村闀裤€傜偣鍑汇€屽埛鏂般€嶅彲鏇存崲鍟嗗簵鍗＄墝銆? },
            { "鎵嬪姩娲惧叺", "鎴樻枟涓皢宸蹭笂闃垫鐏垫嫋鎷藉埌鎸囧畾杞﹂亾鍗冲彲绮惧噯鍑哄嚮锛岄€夋嫨鍚堥€傜殑杞﹂亾鑷冲叧閲嶈銆? },
            { "鑷姩琛屽啗", "鍙充笅瑙掕鍐涙寜閽彲涓€閿紑鍚嚜鍔ㄦ淳鍏点€傞暱鎸夋寜閽彲鍒囨崲绛栫暐锛氫簲璺苟杩涖€佸叏姝间腑璺€佸垎鏁ｄ晶缈笺€? },
            { "姝︾伒鍗囩骇", "鍑哄崱闃舵灏嗗悓鍚嶆鐏垫嫋鏀惧埌宸蹭笂闃垫鐏佃韩涓婂彲鍗囩骇锛屽睘鎬уぇ骞呮彁鍗囥€? },
            { "姝︽妧鎶€鑳?, "瑁呭姝︽妧鍚庯紝鎴樻枟涓煭鎸夋妧鑳藉浘鏍囧悗鎷栨嫿閲婃斁銆傞暱鎸夊彲鏌ョ湅鎶€鑳借鎯呫€? },
            { "鍏电敳绯荤粺", "鏀堕泦濂楄鍏电敳鍙幏寰楀叏灞€灞炴€у姞鎴愶紝闆嗛綈鏁村鑾峰緱棰濆濂楄鏁堟灉銆傚瑁呮晥鍔涙寜鏈€浣庣瓑闃惰澶囨姌绠楋紝鍏ㄥ笣鍝佹柟鍙弧鏁堝姏銆? },
            { "鎴樺姏璁＄畻", "鎬绘垬鍔?= 姝︾伒鎴樺姏(鍓?寮? + 鍏电敳鍒?+ 姝︽妧鍒嗐€? },
            { "鎺㈢储妯″紡", "涔变笘寰侀€斾腑杩涘叆鎼滄墦鎾ゆ帰绱紝鍑昏触鏁屼汉寮€鍚疂绠便€? },
            { "绐佺牬鏈哄埗", "宸辨柟鍏靛啿杩囨晫鏂逛复鐣岀嚎鐩存帴鏀诲嚮澶ф湰钀ャ€備激瀹?ATK+鍏电绐佺牬鍊济?5+ATK脳鍓╀綑琛€閲忔瘮脳0.5锛屽啀涔樹互(1+绐佺牬%)銆? },
            { "澶╁穿(姝讳骸鐖嗙偢)", "鍏甸樀浜℃椂浠TK脳澶╁穿%涓轰激瀹筹紝瀵瑰崐寰?0鑼冨洿鍐呮晫浜洪€犳垚AOE浼ゅ銆? },
            { "鏆村嚮", "鍩虹鏆村嚮鐜?0%锛屽叺绗?瑁呭鏆村嚮鐜囧彔鍔犮€傛毚鍑讳激瀹趁?.0銆? },
            { "鍑忎激", "鍙楀埌浼ゅ鏃讹紝瀹為檯浼ゅ=鍘熷浼ゅ脳(1-鍑忎激%/100)銆? },
            { "鍙嶅嚮", "琚敾鍑绘椂鏈夋鐜囧弽寮?0%鑷韩ATK鐨勪激瀹崇粰鏀诲嚮鑰呫€? },
            { "鏀婚€?, "闄嶄綆鏀诲嚮鍐峰嵈鏃堕棿锛屽叕寮?鍘烠D/(1+鏀婚€?/100)銆? },
            { "棰濆鍏靛姏", "澧炲姞鍑哄叺涓婇檺(鍩虹40)锛屾墍鏈変笂闃垫鐏电殑棰濆鍏靛姏鍙栨暣鍚庡彔鍔犮€? },
        },
    },
    GACHA = {
        title = "鑻辩伒寰佸彫瑙勫垯",
        color = { 120, 80, 160 },  -- 绱壊
        rules = {
            { "鍩烘湰瑙勫垯", "娑堣€楄嫳榄傜煶鍙敜姝︾伒锛屽崟鎶芥秷鑰?棰楋紝鍗佽繛娑堣€?0棰椼€? },
            { "鍝佽川姒傜巼", "鏅€?鐧?60% 鈫?绮捐壇(缁?25% 鈫?绋€鏈?钃?10% 鈫?鍙茶瘲(绱?4% 鈫?浼犺(閲?1%銆? },
            { "淇濆簳鏈哄埗", "姣?0娆″彫鍞ゅ繀鍑轰竴涓彶璇楁垨鏇撮珮鍝佽川姝︾伒銆傛瘡100娆″繀鍑轰紶璇村搧璐ㄣ€? },
            { "鍗佽繛浼樻儬", "鍗佽繛鍙敜蹇呭畾鑷冲皯鍖呭惈涓€涓█鏈?钃?鎴栨洿楂樺搧璐ㄦ鐏点€? },
            { "閲嶅澶勭悊", "鑾峰緱宸叉嫢鏈夌殑姝︾伒鏃讹紝鑷姩杞寲涓哄搴斿搧璐ㄧ殑鐏甸瓊纰庣墖銆? },
        },
    },
    CODEX = {
        title = "姝︾伒褰曡鏄?,
        color = { 80, 120, 160 },  -- 钃濊壊
        rules = {
            { "鍥鹃壌鏀堕泦", "璁板綍鎵€鏈夊凡鍙戠幇鐨勬鐏碉紝鐐瑰嚮鍗＄墝鍙煡鐪嬭缁嗗睘鎬с€? },
            { "鍝佽川鍒嗙被", "鎸夊搧璐ㄧ瓫閫夋煡鐪嬶細鐧解啋缁库啋钃濃啋绱啋閲戯紝渚夸簬蹇€熷畾浣嶃€? },
            { "灞炴€ц鏄?, "鏀诲嚮鍔涘喅瀹氳緭鍑猴紝闃插尽鍔涘噺灏戝彈浼わ紝鐢熷懡鍊煎喅瀹氬瓨娲绘椂闂淬€? },
            { "鏀堕泦濂栧姳", "鏀堕泦涓€瀹氭暟閲忔鐏靛彲瑙ｉ攣鍏ㄥ眬灞炴€у姞鎴愩€? },
        },
    },
    STAGE_SELECT = {
        title = "涔变笘寰侀€旇鍒?,
        color = { 160, 120, 60 },  -- 閲戣壊
        rules = {
            { "鍏冲崱鎸戞垬", "閫夋嫨鍏冲崱杩涘叆鎴樻枟锛屽嚮璐ユ晫鏂瑰ぇ鏈惀鍗充负閫氬叧銆? },
            { "闅惧害閫掑", "姣忎竴绔犺妭鏁屼汉灞炴€ч€愭鎻愬崌锛岄渶瑕佸悎鐞嗘惌閰嶉樀瀹广€? },
            { "鏄熺骇璇勪环", "鏍规嵁閫氬叧琛ㄧ幇鑾峰緱1-3鏄熻瘎浠凤紝鏄熺骇瓒婇珮濂栧姳瓒婁赴鍘氥€? },
            { "棣栭€氬鍔?, "棣栨閫氬叧姣忎釜鍏冲崱鍙幏寰楅澶栬嫳榄傜煶鍜屽啗璧勫鍔便€? },
            { "鎵崱鍔熻兘", "宸叉弧鏄熼€氬叧鐨勫叧鍗″彲鐩存帴鎵崱锛屽揩閫熻幏鍙栧鍔便€? },
        },
    },
    ABYSS_SELECT = {
        title = "璁ㄤ紣鎴樹护瑙勫垯",
        color = { 160, 50, 50 },  -- 绾㈣壊
        rules = {
            { "璁ㄤ紣鏈哄埗", "閫愬眰鎸戞垬涓嶆柇寮哄寲鐨勬晫浜猴紝灞傛暟瓒婇珮濂栧姳瓒婁赴鍘氥€? },
            { "闅惧害閫掑", "姣忓眰鏁屼汉灞炴€ф寜姣斾緥鎻愬崌锛岄珮灞傞渶瑕佸己鍔涢樀瀹广€? },
            { "灞傛暟濂栧姳", "姣忛€氳繃涓€灞傝幏寰楀啗璧勫拰缁忛獙濂栧姳锛岄噷绋嬬灞傛湁棰濆澶у銆? },
            { "姣忔棩閲嶇疆", "璁ㄤ紣杩涘害姣忔棩閲嶇疆锛屾瘡澶╅兘鍙互閲嶆柊鎸戞垬銆? },
            { "鎺掕绔炰簤", "鎸戞垬鐨勬渶楂樺眰鏁颁細璁板綍鍦ㄦ帓琛屾涓婁笌鍏朵粬鐜╁姣旀嫾銆? },
        },
    },
    TOWER_SELECT = {
        title = "鏃犲敖涔嬪瑙勫垯",
        color = { 60, 140, 120 },  -- 闈掕壊
        rules = {
            { "鐖鏈哄埗", "閫愬眰鏀€鐧?鏈€楂?99灞?锛屾瘡灞傛晫鏂瑰己搴γ?.15閫掑锛屾瘡100灞傞澶柮?.1锛?00灞傚悗姣?00灞偯?銆傝澶囨渶楂樼帇鍝?0.5%)銆? },
            { "璧涘涓婇檺", "鏈禌瀛ｆ渶楂樺彲鏀€鐧昏嚦999灞傦紝鍒拌揪鍚庨渶绛夊緟涓嬭禌瀛ｅ紑鏀俱€? },
            { "姘镐箙璁板綍", "濉旂殑杩涘害涓嶄細閲嶇疆锛屽巻鍙叉渶楂樺眰鏁版案涔呬繚瀛樸€? },
            { "灞傛暟濂栧姳", "閫氬叧濂栧姳闅忓眰鏁伴€掑锛岄珮灞傚鍔辨洿涓板帤銆? },
            { "浜戠鎺掕", "鍘嗗彶鏈€楂樺眰鏁颁笂鎶ヤ簯绔紝涓庡叾浠栫帺瀹朵竴杈冮珮涓嬨€? },
        },
    },
    DAILY_DUNGEON = {
        title = "鏃ュ父璇曠偧瑙勫垯",
        color = { 140, 100, 50 },  -- 妫曢噾
        rules = {
            { "姣忔棩寮€鏀?, "姣忓ぉ寮€鏀句笉鍚岀被鍨嬬殑璇曠偧鍓湰锛屾寫鎴樻鏁版湁闄愩€? },
            { "鍓湰绫诲瀷", "鍐涜祫璇曠偧锛氬ぇ閲忓啗璧勫鍔便€傜粡楠岃瘯鐐硷細澶ч噺缁忛獙濂栧姳銆傛潗鏂欒瘯鐐硷細绋€鏈夋潗鏂欐帀钀姐€? },
            { "鎸戞垬娆℃暟", "姣忕鍓湰姣忔棩鍙寫鎴樻湁闄愭鏁帮紝娆℃棩閲嶇疆銆? },
            { "闅惧害閫夋嫨", "鍙€夋嫨涓嶅悓闅惧害锛岄毦搴﹁秺楂樺鍔辫秺涓板帤銆? },
        },
    },
    RANKED_SELECT = {
        title = "宸呭嘲瀵瑰喅瑙勫垯",
        color = { 200, 160, 50 },  -- 閲戣壊
        rules = {
            { "鎺掍綅璧涘埗", "涓庡叾浠栫帺瀹剁殑闃靛杩涜瀵规垬锛屾牴鎹儨璐熻皟鏁存帓鍚嶃€? },
            { "鍖归厤鏈哄埗", "绯荤粺鏍规嵁鎴樺姏鍜屾浣嶅尮閰嶇浉杩戝疄鍔涚殑瀵规墜銆? },
            { "璧涘鍒跺害", "姣忚禌瀛ｇ粨鏉熸牴鎹渶缁堟帓鍚嶅彂鏀句赴鍘氬鍔便€? },
            { "娈典綅绯荤粺", "浠庨潚閾滃埌鐜嬭€咃紝杩炶儨鍙幏寰楅澶栫Н鍒嗗姞鎴愩€? },
            { "姣忔棩娆℃暟", "姣忔棩鎸戞垬娆℃暟鏈夐檺锛屽悎鐞嗗畨鎺掑嚭鎴樻椂鏈恒€? },
        },
    },
    WELFARE = {
        title = "澶╁懡璧愮璇存槑",
        color = { 120, 60, 140 },  -- 娣辩传
        rules = {
            { "绛惧埌濂栧姳", "姣忔棩鐧诲綍绛惧埌鍙鍙栦赴鍘氬鍔憋紝杩炵画绛惧埌濂栧姳鏇村銆? },
            { "鎴愰暱鍩洪噾", "涓€娆℃€ц喘涔板彲鍦ㄨ揪鍒版寚瀹氱瓑绾ф椂棰嗗彇澶ч噺鑻遍瓊鐭炽€? },
            { "闄愭椂娲诲姩", "瀹氭湡寮€鏀鹃檺鏃舵椿鍔紝鍙備笌鍙幏寰椾笓灞炲鍔便€? },
            { "鍦ㄧ嚎濂栧姳", "绱鍦ㄧ嚎鏃堕棿鍙鍙栭澶栧鍔便€? },
        },
    },
    SEAL_MGR = {
        title = "鍏电绠＄悊璇存槑",
        color = { 100, 80, 140 },  -- 鏆楃传
        rules = {
            { "鍏电绯荤粺", "鍏电鏄己鍖栨鐏电殑鐗规畩瑁呭锛屽彲鎻愪緵棰濆灞炴€у姞鎴愩€? },
            { "鍏电鍝佽川", "鍏电鍒嗕负涓嶅悓鍝佽川锛屽搧璐ㄨ秺楂樻彁渚涚殑灞炴€ц秺寮恒€? },
            { "瑁呭瑙勫垯", "姣忎釜姝︾伒鍙澶囨湁闄愭暟閲忕殑鍏电锛屽悎鐞嗘惌閰嶆彁鍗囨垬鍔涖€? },
            { "寮哄寲鍗囩骇", "浣跨敤鏉愭枡寮哄寲鍏电鍙彁鍗囧睘鎬э紝楂樼骇鍏电闇€瑕佺█鏈夋潗鏂欍€? },
            { "濂楄鏁堟灉", "瑁呭鍚岀被鍨嬪叺绗﹁揪鍒颁竴瀹氭暟閲忓彲婵€娲诲瑁呮晥鏋溿€? },
        },
    },
    EQUIP = {
        title = "鍏电敳绯荤粺璇存槑",
        color = { 100, 130, 80 },  -- 鏆楃豢
        rules = {
            { "瑁呭鑾峰彇", "閫氳繃鎴樻枟鎺夎惤銆佸晢搴楄喘涔版垨娲诲姩鑾峰彇瑁呭銆? },
            { "鍏电敳绛夐樁", "鍏电敳鍒嗕负鍑″搧銆佽壇鍝併€佷紭鍝併€佸皢鍝併€佺帇鍝併€佸笣鍝佸叚涓瓑闃讹紝绛夐樁瓒婇珮灞炴€ц秺寮恒€? },
            { "寮哄寲绛夌骇", "鍏电敳鍙己鍖栬嚦+20锛屾瘡娆″己鍖栨秷鑰楀啗璧勫苟鎻愬崌灞炴€с€? },
            { "绌挎埓瑙勫垯", "鐐瑰嚮鍏电敳鍙┛鎴村埌瀵瑰簲閮ㄤ綅锛屾浛鎹㈠悓閮ㄤ綅宸茶澶囧叺鐢层€? },
            { "绛涢€夊垎瑙?, "鎸夌瓑闃跺拰寮哄寲绛夌骇绛涢€夋壒閲忓垎瑙ｄ笉闇€瑕佺殑鍏电敳锛屽洖鏀跺啗璧勩€? },
            { "閫変腑鍒嗚В", "鎵嬪姩鍕鹃€夎鍒嗚В鐨勫叺鐢诧紝绮剧‘鎺у埗鍒嗚В鍐呭銆? },
            { "濂楄鏁堟灉", "鏀堕泦鍚屽瑁呭叺鐢插彲婵€娲诲瑁呮晥鏋滐紝鎻愪緵棰濆鍔犳垚銆? },
        },
    },
}

-- 鏂版墜鎸囧紩寮圭獥鐘舵€?(棣栭〉鐢?
newbieGuidePopup = {
    show = false,
    scrollY = 0,
    contentH = 0,
    viewH = 0,
    isDragging = false,
    lastTouchY = 0,
    vel = 0,
    closeBtnRect = nil,
    panelRect = nil,
}

-- 姝︽妧鎶€鑳介暱鎸夋煡鐪嬭鎯呯姸鎬?
skillLongPressState = {
    pressing = false,
    startTime = 0,
    slot = 0,           -- 鎸変笅鐨勬妧鑳芥Ы浣?(1/2)
    touchId = -1,
    showPopup = false,   -- 鏄惁鏄剧ず鎶€鑳借鎯呭脊绐?
    popupSkillIdx = 0,   -- 鏄剧ず鐨勬妧鑳界储寮?
    popupRect = nil,     -- 寮圭獥鍖哄煙 (闃茬┛閫?
}

-- 鎴樺姏璇存槑寮圭獥
powerExplainPopup = {
    show = false,
    closeBtnRect = nil,
    panelRect = nil,
}

-- 鐜╁璇︽儏缂栬緫妯″紡
playerDetailEditMode = false
playerDetailEditState = {
    selectedAvatar = 1,
    selectedName = 1,
    customName = "",
    avatarRects = {},
    nameRects = {},
    confirmBtnRect = nil,
    cancelBtnRect = nil,
    customInputRect = nil,
}

-- ============================================================================
-- 姝︽妧绯荤粺 (鎶€鑳?
-- ============================================================================
SKILL_SHEET_COLS = 8       -- 搴忓垪甯у垪鏁?
SKILL_SHEET_ROWS = 2       -- 搴忓垪甯ц鏁?
SKILL_FRAME_COUNT = 16     -- 鎬诲抚鏁?
SKILL_IMG_W = 2048         -- 搴忓垪甯у師濮嬪搴?
SKILL_IMG_H = 869          -- 搴忓垪甯у師濮嬮珮搴?

-- 姝︽妧搴忓垪甯?FX 绯荤粺
-- 姣忎釜鏉＄洰: imgHandle(杩愯鏃跺～), cols, rows, totalFrames, fps, file
SKILL_FX_SHEETS = {
    -- iconIdx >> FX 閰嶇疆 (姣忓紶鍥剧綉鏍煎竷灞€涓嶅悓,宸查€愬浘鍍忕礌鍒嗘瀽)
    -- crop: 鍗曞厓鏍煎唴瀹為檯鍐呭鐨勮仈鍚堣竟鐣?(PIL alpha getbbox 鍒嗘瀽, 宸叉寜鍘嬬缉鍚庡昂瀵告洿鏂?
    [1]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_1_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 铓€楠ㄩ拡 (1536脳1030, 8脳2, cell=192脳515)
    [2]  = { handle = -1, cols = 4, rows = 2, frames = 8, fps = 12,
             file = "image/skill_fx_yinghuoluoren.png",
             crop = { x=18, y=1, w=345, h=303 } },           -- 钀ょ伀钀藉垉 (1500脳636, 4脳2, cell=375脳318, 鏈缉鏀?
    [26] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_fx_thunder.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=308 } },            -- 涔濋渼闆风┛ (1536脳651, 8脳2, cell=192脳326, 脳0.75)
    [19] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_19_sheet_20260409160423.png", origW = 1537,
             crop = { x=0, y=0, w=192, h=326 } },            -- 鐑界伀鐕庡師 (1537脳652, 8脳2, cell=192脳326) 閲嶅埗鐗?
    [20] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_20_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=326 } },            -- 璧ゅ鐒氬煙 (1536脳652, 8脳2, cell=192脳326)
    [3]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_fx_ghostclaw.png", origW = 1536,
             crop = { x=0, y=52, w=192, h=466 } },           -- 骞界埅鎺㈠湴 (1536脳651, 8脳1, cell=192脳651, 脳0.75)
    [4]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 12,
             file = "image/skill_4_sheet.png", origW = 2048,
             crop = { x=15, y=0, w=231, h=428 } },            -- 鍑濆啺涓€绾?(2048脳869, 8脳2, cell=256脳434, 鍘荤櫧搴?鏂囧瓧)
    [5]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_lightning_sheet.png",
             crop = { x=3, y=61, w=179, h=588 } },            -- 寮曢浄涓?(1536脳651, 8脳1, cell=192脳651, 脳0.75)
    [6]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_wind_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 鑵愰鏂?(1536脳1030, 8脳2, cell=192脳515)
    [7]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_7_sheet.png",
             crop = { x=20, y=67, w=157, h=468 } },           -- 鐜勬瀬绌夸簯鍓戣瘈 (1500脳636, 8脳1, cell=187脳636, 鏈缉鏀?
    [34] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_34_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=258 } },             -- 绠洦婕ぉ (1536脳1030, 4脳4, cell=384脳258)
    [13] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_13_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 涓囩鍧犻樀 (1536脳1536, 4脳4, cell=384脳384)
    [16] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_16_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 鐏垫硥鍥炴槬 (1536脳1536, 4脳4, cell=384脳384)
    [21] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_21_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 鍐扮嫳灏侀樀 (1536脳1536, 4脳4, cell=384脳384)
    [15] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_15_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 澶╅浄缃氬煙 (1536脳1536, 4脳4, cell=384脳384)
    [11] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_11_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=293 } },             -- 鍦板埡杩炴帰 (1536脳586, 8脳2, cell=192脳293, 脳0.75)
    [31] = { handle = -1, cols = 9, rows = 4, frames = 36, fps = 18,
             file = "image/skill_31_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=170, h=163 } },             -- 涔濆ぉ鍖栭緳涓囧煙 (1536脳652, 9脳4, cell=170脳163)
    [10] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_10_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 濂旈浄绌垮灒 (1536脳1030, 8脳2, cell=192脳515)
    [17] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_fx_17.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 鐜勮殌寰?(1536脳1030, 8脳2, cell=192脳515)
    [8]  = { handle = -1, cols = 4, rows = 2, frames = 8, fps = 12,
             file = "image/skill_fx_8.png", origW = 1500,
             crop = { x=21, y=5, w=347, h=273 } },            -- 鑽嗘缂犲湴 (1500脳636, 4脳2, cell=375脳318)
    [9]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_9_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 瀵掓１璐 (1536脳1030, 8脳2, cell=192脳515)
    [12] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_12_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 椋炲垉杩炴 (1536脳1030, 8脳2, cell=192脳515)
    [14] = { handle = -1, cols = 6, rows = 4, frames = 23, fps = 12,
             file = "image/skill_14_sheet.png", origW = 1536,
             crop = { x=0, y=4, w=254, h=249 } },             -- 瀵掓笂鍐板皝 (1536脳1030, 6脳4, cell=256脳257, 脳0.75)
    [23] = { handle = -1, cols = 6, rows = 4, frames = 24, fps = 12,
             file = "image/skill_23_sheet.png", origW = 1536,
             crop = { x=6, y=12, w=244, h=237 } },            -- 鐮村啗鍣瓊鍗?(1536脳1030, 6脳4, cell=256脳257, 脳0.75)
    [22] = { handle = -1, cols = 6, rows = 4, frames = 24, fps = 12,
             file = "image/skill_22_sheet.png", origW = 2048,
             crop = { x=3, y=6, w=336, h=334 } },             -- 22鍙锋鎶€ (2048脳1374, 6脳4, cell=341脳343, 鐩存帴浣跨敤)
    [24] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_24_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 闀囧啗纰戝帇 (1536脳1536, 4脳4, cell=384脳384)
    -- 鈻?浠ヤ笅涓?AI 鐢熸垚鐨勬鎶€搴忓垪甯?鈻?
    -- 绾挎€ф妧鑳?(8脳2, 1536脳1030, cell=192脳515)
    [18] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_18_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 纰庡博鍐插嚮 (1536脳1030, 8脳2, cell=192脳515)
    [25] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_25_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 榫欏悷璐储 (1536脳1030, 8脳2, cell=192脳515)
    [27] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_27_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 鏋佸瘨鍐板皝璐┖ (1536脳1030, 8脳2, cell=192脳515)
    [28] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_28_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 姝︾伒鍓戣疮涓夌晫 (1536脳1030, 8脳2, cell=192脳515)
    -- 澶у瀷AOE鎶€鑳?(4脳4, 1536脳1536, cell=384脳384)
    [29] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_29_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 杩滃彜榫欓瓊韪忓湴 (1536脳1536, 4脳4, cell=384脳384)
    [30] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_30_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 涓囩伒褰掑琛嶅煙 (1536脳1536, 4脳4, cell=384脳384)
    [32] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_32_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 澶╁懡闆烽煶 (1536脳1536, 4脳4, cell=384脳384)
    [33] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_33_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 鍗冨啗鍐荤粷鍐板煙 (1536脳1536, 4脳4, cell=384脳384)
    [35] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_35_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 涓嶇伃澶╁煙 (1536脳1536, 4脳4, cell=384脳384)
    [36] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_36_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 澶╁懡鐏笘璇€ (1536脳1536, 4脳4, cell=384脳384)
}
-- skillFxTimer 瀛樺偍鍦?menuAnimTimer 涓鐢紝鏃犻渶鐙珛鍙橀噺

-- 姝︽妧瀹氫箟
-- 姝︽妧鎴樻枟鏁版嵁 (鎸?SKILL_TECHNIQUES 绱㈠紩, 鍦?SKILL_TECHNIQUES 瀹氫箟鍚庣敓鎴?
SKILL_DEFS = {}  -- [techniqueIdx] >> battle data

-- 姝︽妧杩愯鏃剁姸鎬?
skillTargeting = {
    active = false,              -- 鏄惁姝ｅ湪鐬勫噯(鎷栨嫿涓?
    skillIdx = 0,                -- 姝ｅ湪鐬勫噯鐨勬妧鑳界储寮?
    sx = 0, sy = 0,              -- 灞忓箷鍘熷鍧愭爣
    dx = 0, dy = 0,              -- 鐩爣璁捐鍧愭爣
    touchId = -1,
}

-- 鍦轰笂娲昏穬鐨勬妧鑳界壒鏁?
activeSkillEffects = {}    -- { x, y, skillIdx, timer, frameIdx, damaged, isEnemySkill? }
-- AI瀵规墜姝︽妧鎶€鑳界郴缁?(鎺掍綅/璁ㄤ紣妯″紡)
aiSkillState = {
    enabled = false,           -- 鏄惁鍚敤AI鎶€鑳?
    availableSkills = {},      -- 鍙敤鎶€鑳藉垪琛?(SKILL_DEFS绱㈠紩)
    cooldowns = {},            -- 鍚勬妧鑳界嫭绔嬪喎鍗?{ [skillIdx] = remainingCD }
    castTimer = 0,             -- AI閲婃斁闂撮殧璁℃椂鍣?
    castInterval = 6.0,        -- AI姣忔閲婃斁鎶€鑳界殑闂撮殧(绉?
    nextCastTime = 4.0,        -- 涓嬫閲婃斁鏃堕棿(棣栨寤惰繜)
}
-- 濂栧姳寮圭獥纭鎸夐挳
rewardPopupConfirmRect = nil
rewardAdDoubleRect = nil  -- 鐪嬪箍鍛婄炕鍊嶆寜閽?
exploreAdDoubleJade = false  -- 鎺㈢储鎾ょ骞垮憡缈诲€嶈檸绗︽爣璁?

-- 姝︾伒璇︽儏椤电姸鎬?
heroDetailState = {
    cardIdx = 0,       -- 褰撳墠鏌ョ湅鐨勮嫳闆勭储寮?
}
heroDetailBackBtnRect = nil
heroDetailScroll = { y = 0, vel = 0, isDragging = false, dragStartY = 0, dragLastY = 0 }
playerDetailScroll = { y = 0, vel = 0, isDragging = false, dragStartY = 0, dragLastY = 0 }

-- 鐜╁璇︽儏椤电姸鎬?
playerDetailBtnRect = nil  -- 棣栭〉鐐瑰嚮澶村儚杩涘叆
playerDetailBackBtnRect = nil

-- 鍥鹃壌鍗＄墝鍖哄煙 (鐢ㄤ簬鐐瑰嚮妫€娴?
codexCardRects = {}
codexScroll = {
    y = 0,              -- 姝︾伒褰曟粴鍔ㄥ亸绉?
    vel = 0,            -- 婊氬姩鎯€ч€熷害
    dragStartY = nil,   -- 瑙︽懜鎷栧姩璧峰Y
    dragLastY = nil,    -- 涓婁竴甯цЕ鎽竃
    isDragging = false, -- 鏄惁姝ｅ湪鎷栧姩
}
codexTab = 0  -- 鍥鹃壌鏍囩椤? 0=鍏ㄩ儴, 1=N, 2=R, 3=SR, 4=SSR
codexTabRects = {}  -- 鏍囩椤垫寜閽偣鍑诲尯鍩?

-- ============================================================================
-- 姝︽妧绯荤粺 (灞曠ず鐢?
-- ============================================================================
SKILL_ICON_COLS = 6        -- 鍥炬爣鍒楁暟
SKILL_ICON_ROWS = 6        -- 鍥炬爣琛屾暟

-- 姣忎釜鍥炬爣鍦ㄧ簿鐏靛浘涓殑瀹為檯鍐呭杈圭晫 (鍩轰簬鍍忕礌鍒嗘瀽)
-- bx,by = 鍐呭宸︿笂瑙掑湪250脳250鍗曞厓鏍煎唴鐨勫亸绉? bw,bh = 鍐呭瀹介珮
SKILL_ICON_BBOX = {}
for i = 1, 36 do
    SKILL_ICON_BBOX[i] = {bx=0, by=0, bw=250, bh=250}  -- 鏂板浘鏍囧甫鑳屾櫙妗嗭紝濉弧鏁翠釜鍗曞厓鏍?
end

-- 姝︽妧闃剁骇瀹氫箟 (7闃? 鍑♀啋鑹啋浼樷啋灏嗏啋渚啋鐜嬧啋甯?
SKILL_TIERS = {
    { name = "鍑″搧", color = { 180, 175, 165 }, glowColor = { 140, 140, 140 }, count = 6 },
    { name = "鑹搧", color = { 100, 210, 120 }, glowColor = { 60, 200, 60 },   count = 6 },
    { name = "浼樺搧", color = { 80, 160, 255 },  glowColor = { 60, 120, 255 },   count = 6 },
    { name = "灏嗗搧", color = { 180, 100, 255 }, glowColor = { 170, 80, 255 }, count = 6 },
    { name = "渚搧", color = { 255, 140, 0 },   glowColor = { 255, 120, 0 },  count = 6 },
    { name = "鐜嬪搧", color = { 255, 180, 50 },  glowColor = { 255, 150, 30 }, count = 5 },
    { name = "甯濆搧", color = { 255, 80, 80 },   glowColor = { 255, 60, 60 },  count = 1 },
}

-- 36涓鎶€瀹屾暣鏁版嵁
SKILL_TECHNIQUES = {
    -- 鍑″搧 (1-6)
    { name = "鐮撮攱閽?, tier = 1, iconIdx = 1,
      desc = "鍑濊仛閿嬮攼涔嬪姏鍖栦綔鍒╅拡锛屽埡鍚戝崟涓晫浜猴紝浼ゅ绮惧噯浣嗚鐩栨瀬灏忋€? },
    { name = "鐑界伀闄勮韩", tier = 1, iconIdx = 2,
      desc = "寮曠噧鎴樼伀闄勪簬鍏靛垉涔嬩笂锛岀煭璺濈鐩寸嚎鎸ュ嚭锛岀伡鐑ф晫鍐涖€? },
    { name = "鍦拌鎺㈤樀", tier = 1, iconIdx = 3,
      desc = "鍌彂鍦拌剦涔嬪姏浠庡湴搴曟帰鍑猴紝鎶撳嚮鑴氫笅灏忕墖鍖哄煙鐨勬晫浜恒€? },
    { name = "闇滈攱涓€绾?, tier = 1, iconIdx = 4,
      desc = "灏嗗瘨姘斿嚌鑱氫簬涓€绾匡紝娌跨洿绾垮喕缁撶煭璺濈鍐呯殑鏁屼汉銆? },
    { name = "缂氭晫涓?, tier = 1, iconIdx = 5,
      desc = "寮曞嚭涓€缂曠細鏁岀粏涓濓紝鍑讳腑鍓嶆柟鏈€杩戠殑涓€涓晫浜恒€? },
    { name = "鏃嬮鏂?, tier = 1, iconIdx = 6,
      desc = "浠ュ噷鍘夐鍒冩í鎵紝鐭窛绂诲唴鍒囧壊鍓嶆柟鏁屼汉銆? },

    -- 鑹搧 (7-12)
    { name = "绌垮績绠?, tier = 2, iconIdx = 7,
      desc = "鍒╃煝绌垮績鑰屽嚭锛屾部涓瓑鐩寸嚎璐┛澶氫釜鏁屼汉銆? },
    { name = "鑽嗘缂犲湴", tier = 2, iconIdx = 8,
      desc = "鍙敜鑽嗘钄撳欢鍦伴潰锛屽舰鎴愬皬鍨嬪湴闈㈠煙锛屾寔缁激瀹宠俯鍏ュ叾涓殑鏁屼汉銆? },
    { name = "瀵掓１璐", tier = 2, iconIdx = 9,
      desc = "浠ュ啺妫辨部鐩寸嚎灏勫嚭锛岃疮绌夸腑绛夎窛绂诲唴鎵€鏈夋晫浜恒€? },
    { name = "濂旈浄绌垮灒", tier = 2, iconIdx = 10,
      desc = "澶╅浄鍖栦綔绌块€忓皠绾匡紝蹇界暐闅滅鐩寸嚎璐┛鏁岀兢銆? },
    { name = "鍦板埡杩炴帰", tier = 2, iconIdx = 11,
      desc = "杩炵画鍌彂鍦板埡鎺㈠嚭鍦伴潰锛屾部鐭窛鐩寸嚎閫犳垚澶氭浼ゅ銆? },
    { name = "椋炲垉杩炴", tier = 2, iconIdx = 12,
      desc = "澶氶亾椋炲垉姊舰杩炲彂锛屾部涓窛鐩寸嚎鍒囧壊涓€鍒囥€? },

    -- 浼樺搧 (13-18)
    { name = "涓囩鍧犻樀", tier = 3, iconIdx = 13,
      desc = "涓囧崈绠煝浠庡ぉ鑰岄檷锛岃鐩栨爣鍑嗗渾褰㈠尯鍩燂紝瀵嗛泦鎵撳嚮鑼冨洿鍐呮晫浜恒€? },
    { name = "瀵掓笂鍐板皝", tier = 3, iconIdx = 14,
      desc = "瀵掓笂涔嬪姏鍐板皝涓€鏂癸紝鍦ㄤ腑绛夊湴闈㈠煙涓喕缁撳苟浼ゅ鏁屼汉銆? },
    { name = "澶╅浄缃氬煙", tier = 3, iconIdx = 15,
      desc = "浜旈亾澶╅浄姹囪仛锛屽寲涓洪浄鐢甸鍩熻鐩栨爣鍑嗚寖鍥达紝鐢靛嚮鍩熷唴鎵€鏈夋晫浜恒€? },
    { name = "鐏垫硥鍥炴槬", tier = 3, iconIdx = 16,
      desc = "鐏垫硥涔嬪姏鍖栦负鍥炴槬涔嬮樀锛屽尯鍩熷唴宸辨柟姝︾伒鎸佺画鍥炲鐢熷懡銆? },
    { name = "鐜勮殌寰?, tier = 3, iconIdx = 17,
      desc = "鐜勫姏渚佃殌璺緞锛屽湪鏍囧噯鐩寸嚎鑼冨洿鍐呭悶鍣竴鍒囩敓鐏点€? },
    { name = "纰庡博鍐插嚮", tier = 3, iconIdx = 18,
      desc = "宀╁姏鐖嗗彂鍐插嚮鍓嶆柟锛屾爣鍑嗚窛绂昏疮绌挎晫浜哄苟鍑婚銆? },

    -- 灏嗗搧 (19-24)
    { name = "鐑界伀鐕庡師", tier = 4, iconIdx = 19,
      desc = "鐑界伀婕噧褰㈡垚鐏煙锛屽ぇ鍨嬪湴闈㈠煙鎸佺画鐒氱儳鍩熷唴涓€鍒囨晫鍐涖€? },
    { name = "璧ゅ鐒氬煙", tier = 4, iconIdx = 20,
      desc = "璧ゅ鐑堢劙钄撳欢澶у瀷鍖哄煙锛屽ぉ鐏剼鐑у煙鍐呬竴鍒囨晫浜恒€? },
    { name = "鍐扮嫳灏侀樀", tier = 4, iconIdx = 21,
      desc = "鏋佸瘨涔嬪姏灏侀攣澶х墖鐤嗗煙锛屽啺灏佸煙鍐呮墍鏈夋晫浜恒€? },
    { name = "闆风嫳鍥氶樀", tier = 4, iconIdx = 22,
      desc = "澶╅浄缁囨垚鍥氱锛屽ぇ鍨嬪尯鍩熷唴鏁屼汉鏃犲鍙€冿紝鎸佺画鍙楅浄鍑汇€? },
    { name = "鐮村啗鍣瓊鍗?, tier = 4, iconIdx = 23,
      desc = "鐮村啗鍗拌鏍囪澶ц寖鍥存晫浜猴紝澧炲己璐┛鍔涚┛閫忎换浣曢槻寰°€? },
    { name = "闀囧啗纰戝帇", tier = 4, iconIdx = 24,
      desc = "闀囧啗涔嬪姏闀囧帇澶у湴锛屽ぇ鍨嬪尯鍩熷唴鏁屼汉琚噸鍔涚⒕鍘嬨€? },

    -- 渚搧 (25-30) 鈥?澶嶇敤鐜嬪搧鍥炬爣
    { name = "榫欏悷璐储", tier = 5, iconIdx = 25,
      desc = "榫欏悷涔嬪姏鍖栦负璐储锛岃秴闀胯窛绂荤洿绾胯疮绌匡紝绌块€忎竴鍒囬樆鎸°€? },
    { name = "涔濆ぉ闆风┛", tier = 5, iconIdx = 26,
      desc = "涔濆ぉ绁為浄鑱氫负涓€鏉燂紝瓒呴暱鐩寸嚎绌块€忥紝闆峰▉娴╄崱鏃犲彲鍖规晫銆? },
    { name = "鏋佸瘨鍐板皝璐┖", tier = 5, iconIdx = 27,
      desc = "缁濆闆跺害鍑濇垚瀵掑厜璐┛澶╁湴锛岃秴闀跨洿绾垮喕纰庝竴鍒囥€? },
    { name = "姝︾伒鍓戣疮涓夌晫", tier = 5, iconIdx = 28,
      desc = "缁濅笘鍓戞剰鍖栦负姝︾伒涔嬪墤锛岃疮绌夸笁鐣岀殑瓒呴暱鐩寸嚎鏀诲嚮銆? },
    { name = "杩滃彜榫欓瓊韪忓湴", tier = 5, iconIdx = 29,
      desc = "杩滃彜榫欓瓊涔嬪奖韪忕澶у湴锛屽叏鍖哄煙鍦伴潰琚渿纰庡帇鍒躲€? },
    { name = "涓囩伒褰掑琛嶅煙", tier = 5, iconIdx = 30,
      desc = "涓囩伒褰掍簬铏氬锛岃鐢熷嚭瑕嗙洊鍏ㄥ尯鍩熺殑姣佺伃棰嗗煙銆? },

    -- 鐜嬪搧 (31-35)
    { name = "涔濆ぉ鍖栭緳涓囧煙", tier = 6, iconIdx = 31,
      desc = "涔濆ぉ涔嬪姏鍖栬韩榫欏煙锛屽叏鍦板浘绗肩僵浜庢棤灏藉ぉ濞佷箣涓€? },
    { name = "澶╁懡闆烽煶", tier = 6, iconIdx = 32,
      desc = "澶╁懡涔嬮浄璐交澶╁湴锛屾钉鑽¤媿鐢熺殑绁為浄瑕嗙洊鍏ㄥ浘銆? },
    { name = "鍗冨啗鍐荤粷鍐板煙", tier = 6, iconIdx = 33,
      desc = "鍗冨啗灏藉喕鐨勭粷瀵瑰啺鍩燂紝鍏ㄥ湴鍥捐姘告亽瀵掑啺灏佸嵃銆? },
    { name = "绠洦婕ぉ", tier = 6, iconIdx = 34,
      desc = "涓囩褰掍竴鍚庢极澶╃闆紝鍏ㄥ湴鍥炬棤宸埆绠煝娲楃ぜ銆? },
    { name = "涓嶇伃澶╁煙", tier = 6, iconIdx = 35,
      desc = "涓嶇伃涔嬪姏鍖栦负澶╁煙锛屽叏鍦板浘鏁屼汉琚ぉ鍛戒箣鍔涘弽鍣€? },

    -- 甯濆搧 (36) 鈥?鍞竴缁堟瀬姝︽妧
    { name = "澶╁懡鐏笘璇€", tier = 7, iconIdx = 36,
      desc = "澶╁懡鏈簮鍖栦负缁堢剦涔嬬伀锛岀剼灏藉ぉ鍦颁竾鐗╃殑缁堟瀬姝︽妧銆? },
}

-- 鏍规嵁闃剁骇鐢熸垚姝︽妧鎴樻枟灞炴€?(7闃? 鍑♀啋鑹啋浼樷啋灏嗏啋渚啋鐜嬧啋甯?
TIER_BATTLE_STATS = {
    { damage = 300,  radius = 70,  maxCooldown = 8,  renderSize = 120 }, -- 鍑″搧 (灏忓瀷)
    { damage = 550,  radius = 85,  maxCooldown = 9,  renderSize = 120 }, -- 鑹搧 (灏忓瀷)
    { damage = 900,  radius = 100, maxCooldown = 10, renderSize = 200 }, -- 浼樺搧 (涓瀷)
    { damage = 1400, radius = 115, maxCooldown = 11, renderSize = 200 }, -- 灏嗗搧 (涓瀷)
    { damage = 1800, radius = 130, maxCooldown = 12, renderSize = 250 }, -- 渚搧 (涓ぇ鍨?
    { damage = 2500, radius = 150, maxCooldown = 13, renderSize = 350 }, -- 鐜嬪搧 (澶у瀷)
    { damage = 3800, radius = 175, maxCooldown = 15, renderSize = 400 }, -- 甯濆搧 (鍏ㄥ睆)
}

-- 绾垮瀷鎶€鑳界殑 iconIdx 闆嗗悎 (铓€楠ㄩ拡绛夋部琛屽啗璺嚎椋炶鐨勬妧鑳?
LINE_SKILL_ICONS = { [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [18] = true, [25] = true, [27] = true, [28] = true }  -- iconIdx=1 >> 鐮撮攱閽? 4 >> 闇滈攱涓€绾? 5 >> 缂氭晫涓? 6 >> 鏃嬮鏂? 7 >> 绌垮績绠? 18 >> 纰庡博鍐插嚮, 25 >> 榫欏悷璐储, 27 >> 鏋佸瘨鍐板皝璐┖, 28 >> 姝︾伒鍓戣疮涓夌晫

-- 鐭╁舰鎶€鑳界殑 iconIdx >> 鐭╁舰灏哄 (瀹矫楅珮, 璁捐鍧愭爣)
RECT_SKILL_ICONS = {
    [34] = { w = 560, h = 272 },  -- 绠洦婕ぉ: 澶у瀷鐭╁舰绠洦
    [17] = { w = 400, h = 400 },  -- 鐜勮殌寰? 鐭╁舰妯法涓ゆ潯琛屽啗璺嚎,鎸佺画浼ゅ
}
-- 瓒呭ぇ鍦嗗舰AOE (瑕嗙洊鍏ㄥ満)
BIG_AOE_ICONS = {
    [31] = { radius = 280, renderSize = 560 },  -- 涔濆ぉ鍖栭緳涓囧煙: 瓒呭ぇ鍦嗗舰瑕嗙洊浜旀潯琛屽啗璺嚎
    [29] = { radius = 250, renderSize = 500 },  -- 杩滃彜榫欓瓊韪忓湴: 澶у瀷鍐插嚮娉?
    [30] = { radius = 280, renderSize = 560 },  -- 涓囩伒褰掑琛嶅煙: 鑻遍瓊椋庢毚瑕嗙洊鍏ㄥ煙
    [32] = { radius = 300, renderSize = 600 },  -- 澶╁懡闆烽煶: 闆锋毚瑕嗙洊鍏ㄥ煙
    [33] = { radius = 300, renderSize = 600 },  -- 鍗冨啗鍐荤粷鍐板煙: 鍐板皝鍏ㄥ煙
    [35] = { radius = 320, renderSize = 640 },  -- 涓嶇伃澶╁煙: 澶╁煙缁撶晫
    [36] = { radius = 350, renderSize = 700 },  -- 澶╁懡鐏笘璇€: 缁堟瀬姝︽妧鏈€澶ц寖鍥?
}

-- 娌荤枟鎶€鑳界殑 iconIdx 闆嗗悎 (搴曞眰娓叉煋, 涓棿甯у欢闀? 娌荤枟宸辨柟)
HEAL_SKILL_ICONS = { [16] = true }  -- iconIdx=16 >> 鐏垫硥鍥炴槬

-- 鍖哄煙鎶€鑳?(搴曞眰娓叉煋, 鎸佺画浼ゅ+鍑忛€? 绫讳技娌荤枟浣嗗鏁屾柟)
ZONE_SKILL_ICONS = {
    [21] = { slowFactor = 0.4, dmgPerTick = 10, tickInterval = 0.5 },  -- 鍐扮嫳灏侀樀: 鍑忛€?0%+鎸佺画浼ゅ
    [8]  = { slowFactor = 0.5, dmgPerTick = 5,  tickInterval = 0.5 },  -- 鑽嗘缂犲湴: 鍑忛€?0%+杞诲井鎸佺画浼ゅ
}

-- 鏋勫缓鍏ㄩ儴36涓鎶€鐨勬垬鏂楁暟鎹?(寮€鎸? 鍏ㄩ儴瑙ｉ攣)
for i, tech in ipairs(SKILL_TECHNIQUES) do
    local ts = TIER_BATTLE_STATS[tech.tier]
    local tc = SKILL_TIERS[tech.tier].color
    local isLine = LINE_SKILL_ICONS[tech.iconIdx]
    local isRect = RECT_SKILL_ICONS[tech.iconIdx]
    local isHeal = HEAL_SKILL_ICONS[tech.iconIdx]
    local isZone = ZONE_SKILL_ICONS[tech.iconIdx]
    local isBigAoe = BIG_AOE_ICONS[tech.iconIdx]
    -- AOE/rect 鍔ㄧ敾鏃堕暱: 鐢ㄥ簭鍒楀抚鐨?frames/fps, 鏃犲簭鍒楀抚鍥為€€ 1.0s
    local fxData = SKILL_FX_SHEETS[tech.iconIdx]
    local baseDur = (fxData and fxData.frames and fxData.fps) and (fxData.frames / fxData.fps) or 1.0
    -- 娌荤枟/鍖哄煙鎶€鑳? 涓棿甯у欢闀? 鎬绘椂闀?= 鍩虹鏃堕暱 + 棰濆鍋滅暀鏃堕棿
    local hasTickDmg = isRect and isRect.w and SKILL_FX_SHEETS[tech.iconIdx] and SKILL_FX_SHEETS[tech.iconIdx].crop
    local aoeDur = (isHeal or isZone or hasTickDmg) and (baseDur + 3.0) or baseDur
    local skillType = "aoe"
    if isHeal then
        skillType = "heal"
    elseif isZone then
        skillType = "zone"
    elseif isRect then
        skillType = "rect"
    elseif isLine then skillType = "line" end
    SKILL_DEFS[i] = {
        name = tech.name,
        desc = tech.desc,
        unlocked = false,        -- 榛樿鏈В閿? 闇€閫氳繃骞垮憡/濂栧姳鑾峰彇
        notAvailable = (SKILL_FX_SHEETS[tech.iconIdx] == nil),  -- 鏃犵壒鏁堢殑姝︽妧鏍囪涓烘殏鏈紑鏀?
        cooldown = 0,
        maxCooldown = ts.maxCooldown,
        damage = ts.damage,
        radius = isLine and 40 or ts.radius,         -- 绾垮瀷鎶€鑳芥í鍚戝懡涓搴﹁緝绐?
        renderSize = isLine and 40 or ts.renderSize,  -- 绾垮瀷鎶€鑳界簿鐏垫覆鏌撳昂瀵?
        animDuration = aoeDur,                        -- 鍔ㄧ敾鎭板ソ鎾畬涓€杞簭鍒楀抚
        damageFrame = 5,
        color = { tc[1], tc[2], tc[3] },
        iconIdx = tech.iconIdx,
        skillType = skillType,
        lineWidth = isLine and 50 or nil,             -- 绾垮瀷鎶€鑳藉懡涓搴?
        renderBehind = not isLine,                     -- 闄ょ嚎鎬ф妧鑳藉锛屽叏閮ㄥ湪鍗曚綅涓嬫柟娓叉煋
    }
    -- 鐭╁舰鎶€鑳借鐩?
    if isRect then
        SKILL_DEFS[i].rectW = isRect.w
        SKILL_DEFS[i].rectH = isRect.h
        SKILL_DEFS[i].damage = 3500   -- 鐭╁舰澶ц寖鍥存妧鑳藉浼?
    end
    -- 澶滃奖铓€寰? 鐭╁舰+鎸佺画浼ゅ (妯法涓ゆ潯琛屽啗璺嚎)
    if tech.iconIdx == 17 then
        SKILL_DEFS[i].dmgPerTick = 20        -- 姣弔ick鎸佺画浼ゅ
        SKILL_DEFS[i].tickInterval = 0.5     -- tick闂撮殧
        SKILL_DEFS[i].renderBehind = true    -- 搴曞眰娓叉煋
    end
    -- 瓒呭ぇ鍦嗗舰AOE瑕嗙洊 (31涔濆菇鍖栭瓟: 瑕嗙洊鍏ㄥ満, 搴曞眰娓叉煋)
    if isBigAoe then
        SKILL_DEFS[i].radius = isBigAoe.radius
        SKILL_DEFS[i].renderSize = isBigAoe.renderSize
        SKILL_DEFS[i].renderBehind = true
        SKILL_DEFS[i].damage = 3500
    end
    -- 娌荤枟鎶€鑳借鐩?
    if isHeal then
        SKILL_DEFS[i].radius = 65        -- 涓瀷鎶€鑳界缉灏忚寖鍥?
        SKILL_DEFS[i].renderSize = 130
        SKILL_DEFS[i].healPerTick = 15   -- 姣忔娌荤枟閲?
        SKILL_DEFS[i].healInterval = 0.5 -- 姣?.5绉掓不鐤椾竴娆?
    end
    -- 鍖哄煙鎶€鑳借鐩?(鍐扮嫳灏佺枂: 鎸佺画浼ゅ+鍑忛€?
    if isZone then
        SKILL_DEFS[i].slowFactor = isZone.slowFactor      -- 鍑忛€熸瘮渚?(0.4 = 鍑忛€?0%)
        SKILL_DEFS[i].dmgPerTick = isZone.dmgPerTick      -- 姣弔ick浼ゅ
        SKILL_DEFS[i].tickInterval = isZone.tickInterval   -- tick闂撮殧
    end
    -- 涔濆菇闆风┛: 鐙遍樁鎵╁ぇ1.25鍊?
    if tech.iconIdx == 26 then
        SKILL_DEFS[i].radius = math.floor(ts.radius * 1.25)
        SKILL_DEFS[i].renderSize = math.floor(ts.renderSize * 1.25)
    end
end

-- 鐜╁宸茶澶囩殑姝︽妧 (鏈€澶?涓? SKILL_TECHNIQUES 绱㈠紩)
playerEquippedSkills = {}  -- 榛樿鏃犺澶囨鎶€(鍏ㄩ儴鏈В閿?

-- 姝︽妧鐣岄潰鐘舵€?
skillCodexState = {
    scrollY = 0,
    scrollVel = 0,
    dragStartY = nil,
    dragLastY = nil,
    isDragging = false,
    selectedIdx = 0,      -- 褰撳墠鏌ョ湅鐨勬鎶€绱㈠紩
}
skillCodexBackBtnRect = nil
skillCodexCardRects = {}
skillDetailBackBtnRect = nil
skillDetailMiniRects = {}    -- 璇︽儏椤靛簳閮ㄥ悓闃堕瑙堢偣鍑诲尯鍩?
skillDetailEquipBtnRect = nil      -- 璇︽儏椤佃澶?鍗镐笅鎸夐挳
skillDetailEquipSlotBtns = {}     -- 璇︽儏椤垫浛鎹㈡Ы浣嶆寜閽?(婊?妲芥椂鏄剧ず)
skillDetailUpgradeBtnRect = nil   -- 璇︽儏椤靛崌灞傛寜閽?
-- menuSkillCodexBtnRect / menuWelfareBtnRect 宸插悎骞跺埌 menuBtnRects
welfareState = {
    backBtnRect = nil,        -- 绂忓埄椤佃繑鍥炴寜閽?
    -- 涓夋棩绛惧埌
    signInClaimed = {false, false, false},  -- 姣忓ぉ鏄惁宸查鍙?
    signInTimestamps = {0, 0, 0},             -- 姣忓ぉ棰嗗彇鏃剁殑 os.time() 鏃堕棿鎴?
    signInBtnRects = {},      -- 绛惧埌鎸夐挳鍖哄煙
    -- 鍗佹棩绛惧埌锛堟瘡鏃ュ箍鍛婇5000铏庣锛?
    dailySignInClaimed = {false, false, false, false, false, false, false, false, false, false},
    dailySignInTimestamps = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0},  -- 姣忓ぉ棰嗗彇鏃剁殑 os.time() 鏃堕棿鎴?
    dailySignInBtnRects = {},
    -- 鍦ㄧ嚎鏃堕暱濂栧姳
    onlineTime = 0,           -- 绱鍦ㄧ嚎绉掓暟
    onlineRewards = {false, false, false, false}, -- 鍚勬。濂栧姳鏄惁宸查
    onlineBtnRects = {},      -- 鍦ㄧ嚎濂栧姳鎸夐挳鍖哄煙
    -- 璐＄尞姒?
    contribRank = nil,        -- 鎺掕姒滄暟鎹紦瀛?(鏁扮粍 {name, count})
    contribLoading = false,   -- 鏄惁姝ｅ湪鍔犺浇
    contribLoaded = false,    -- 鏄惁宸插姞杞藉畬鎴?
    -- 椤甸潰婊氬姩锛堜笅鏂瑰唴瀹瑰尯锛?
    scroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 璐＄尞姒滅嫭绔嬫粴鍔紙椤堕儴鍥哄畾鍖哄煙锛?
    contribScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    contribFixedH = 0,  -- 璐＄尞姒滃浐瀹氬尯鍩熸€婚珮搴︼紙鍔ㄦ€佽绠楋級
    contribShowAll = false, -- 璐＄尞姒滄槸鍚﹀睍寮€鏄剧ず鍏ㄩ儴锛堥粯璁ゅ彧鏄剧ず鍓?锛?

    -- 澶ц浆鐩?
    spinWheel = {
        lastDate = "",        -- 涓婃杞洏鏃ユ湡
        freeUsed = false,     -- 浠婃棩鍏嶈垂杞槸鍚﹀凡鐢?
        adSpins = 0,          -- 浠婃棩骞垮憡杞鏁?
        spinning = false,     -- 鏄惁姝ｅ湪鏃嬭浆
        angle = 0,            -- 褰撳墠瑙掑害(寮у害)
        targetAngle = 0,      -- 鐩爣瑙掑害
        spinStart = 0,        -- 寮€濮嬫棆杞椂闂?
        resultIdx = 0,        -- 缁撴灉绱㈠紩
        resultGranted = false,-- 缁撴灉宸插彂鏀?
    },
    spinWheelBtnRect = nil,
    -- 姣忔棩缈荤墝
    cardFlip = {
        lastDate = "",        -- 涓婃缈荤墝鏃ユ湡
        cards = {},           -- 6寮犵墝鐨勫鍔辩储寮?
        flipped = {},         -- 鍝簺鐗屽凡缈诲紑 {false,false,...}
        freeUsed = false,     -- 鍏嶈垂缈荤墝鏄惁宸茬敤
        adFlips = 0,          -- 浠婃棩骞垮憡缈荤墝娆℃暟
    },
    cardFlipBtnRects = {},
    contribDetailBtnRect = nil,  -- 鏌ョ湅璇︽儏鎸夐挳鍖哄煙
    -- 璐＄尞姒滆鎯呴〉鐙珛婊氬姩
    contribDetailScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 鎴樺姏鎺掕姒?
    powerRank = nil,          -- 鎺掕姒滄暟鎹紦瀛?(鏁扮粍 {name, power})
    powerLoading = false,     -- 鏄惁姝ｅ湪鍔犺浇
    powerLoaded = false,      -- 鏄惁宸插姞杞藉畬鎴?
    powerScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    powerFixedH = 0,          -- 鎴樺姏鎺掕姒滃浐瀹氬尯鍩熸€婚珮搴?
    -- 鎺掕姒滈〉绛? "power" 鎴?"realm"
    rankTab = "power",
    -- 澧冪晫鎺掕姒?
    realmRank = nil,          -- 澧冪晫鎺掕姒滄暟鎹紦瀛?(鏁扮粍 {name, rankIdx})
    realmLoading = false,
    realmLoaded = false,
    realmScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 妗╅€肩帇鎺掕姒?(鎵撴々浼ゅ鎺掕)
    dummyRank = nil,           -- 鎺掕姒滄暟鎹紦瀛?(鏁扮粍 {name, damage, userId})
    dummyLoading = false,
    dummyLoaded = false,
    dummyScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 闃佃惀绛夌骇鎺掕姒?
    factionRank = nil,         -- 鎺掕姒滄暟鎹紦瀛?(鏁扮粍 {name, level, exp, userId, leaderName})
    factionRankLoading = false,
    factionRankLoaded = false,
    factionRankScroll = { offset = 0, vel = 0, dragStartY = nil, dragLastY = nil, isDragging = false },
    -- 鏌ョ湅鐜╁寮圭獥
    rankViewPopup = nil,  -- { entry={name,power,skillCount,heroCount,realmIdx,rank}, closeBtnRect={} }
    rankViewBtnRects = {},  -- [i] = {x,y,w,h}
}

-- ============================================================================
-- 閭欢绯荤粺
-- ============================================================================
-- welfareState.mailDefs 鍜?welfareState.mail 鍚堝苟鍒?welfareState 閬垮厤 local 涓婇檺
welfareState.mailDefs = {
    {
        id = "welcome_gift",
        title = "鎰熻阿鐩搁亣",
        sender = "姝︾伒鐜嬪骇",
        content = "姝︾伒澶т汉锛屾劅璋綘韪忓叆杩欑墖涔变笘锛佸垵娆＄浉閬囷紝璧犱綘3000铏庣锛堢害100鎶斤級锛屾効鍔╀綘鍙泦澶╀笅鑻辨澃銆佸緛鎴樺洓鏂癸紒姝ょぜ缁堣韩浠呭彲棰嗗彇涓€娆★紝绁濇棗寮€寰楄儨锛?,
        rewards = {
            { type = "jade", amount = 3000, label = "铏庣 脳3000" },
        },
    },
    {
        id = "self_recommend",
        title = "鑷崘淇?,
        sender = "鍒朵綔浜?,
        content = "杩欐槸涓€涓潪甯歌垂蹇冭鐨勫皬娓告垙锛屾劅鎭╃浉閬囷紝涔熷笇鏈涘ぇ瀹惰兘澶氬濂借瘎锛屽彲浠ュ姞缇や竴璧蜂氦娴佷紭鍖栨柟鍚戯紝濡傛灉鎮ㄧ殑鏈嬪弸涔熷枩娆㈣繖涓鏉愶紝璇蜂竴瀹氬府鎴戞帹鑽愮粰浠栵紒锛侊紒鎰熸仼锛?,
        rewards = {
            { type = "jade", amount = 2000, label = "铏庣 脳2000" },
        },
    },
}
welfareState.mail = {
    claimed = {},         -- { [mailId] = true } 宸查鍙栫殑閭欢
    btnRects = {},        -- 棰嗗彇鎸夐挳鍖哄煙
    confirmPopup = nil,   -- 棰嗗彇纭寮圭獥 { mailIdx = N, closeBtnRect, confirmBtnRect, bgRect }
    tab = "system",       -- "system" / "cloud" 閭欢鏍囩
    cloudBtnRects = {},   -- 浜戦偖浠堕鍙?鏌ョ湅鎸夐挳鍖哄煙
    composing = false,    -- 鏄惁姝ｅ湪鍐欎俊
    composeData = nil,    -- 鍐欎俊鏁版嵁 { targetUid="", subject="", body="", rewards={}, inputFocus="" }
    adminPanel = false,   -- 绠＄悊鍛樺鍔遍潰鏉?
}

-- ============================================================================
-- 姣忓懆鎺掕姒滃鍔辩粨绠?(瀹㈡埛绔Е鍙戝紡)
-- ============================================================================
-- 濂栧姳閰嶇疆: 鍚勬帓琛屾 top N 濂栧姳
WEEKLY_RANK_REWARDS = {
    {
        name = "鎴樺姏姒?, key = PROJECT_PREFIX .. "combat_power",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 500, label = "铏庣 脳500" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 300, label = "铏庣 脳300" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 150, label = "铏庣 脳150" } } },
            { maxRank = 20, rewards = { { type = "jade", amount = 80,  label = "铏庣 脳80" } } },
        },
    },
    {
        name = "澧冪晫姒?, key = PROJECT_PREFIX .. "realm_level",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 500, label = "铏庣 脳500" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 300, label = "铏庣 脳300" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 150, label = "铏庣 脳150" } } },
            { maxRank = 20, rewards = { { type = "jade", amount = 80,  label = "铏庣 脳80" } } },
        },
    },
    {
        name = "鐖姒?, key = PROJECT_PREFIX .. "tower_floor",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 400, label = "铏庣 脳400" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 200, label = "铏庣 脳200" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 100, label = "铏庣 脳100" } } },
        },
    },
    {
        name = "鎺掍綅姒?, key = PROJECT_PREFIX .. "ranked_score",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 400, label = "铏庣 脳400" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 200, label = "铏庣 脳200" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 100, label = "铏庣 脳100" } } },
        },
    },
    {
        name = "妗╅€肩帇", key = PROJECT_PREFIX .. "dummy_damage",
        tiers = {
            { maxRank = 1,  rewards = { { type = "jade", amount = 400, label = "铏庣 脳400" } } },
            { maxRank = 3,  rewards = { { type = "jade", amount = 200, label = "铏庣 脳200" } } },
            { maxRank = 10, rewards = { { type = "jade", amount = 100, label = "铏庣 脳100" } } },
        },
    },
}

-- ============================================================================
-- 鍏电绯荤粺
-- ============================================================================
UNIT_CLASS = {
    SWORD   = { id = 1, name = "铏庤床鍒€鍏?, sprite = "sword",   isRanged = false, atkRange = 40, speed = 30, atkCd = 0.9,
                breakDmg = 1, desc = "鍒€閿嬪铏庯紝鏀婚€熷噷鍘夋潃鏁屾棤鏁? },
    ARCHER  = { id = 2, name = "杩炲缉灏勬墜", sprite = "archer",  isRanged = true,  atkRange = 120, speed = 24, atkCd = 1.2,
                breakDmg = 1, desc = "鍔插缉榻愬彂锛岀櫨姝ョ┛鏉ㄥ皠鏉€鏁屽皢" },
    SHIELD  = { id = 3, name = "閾佺浘閲嶅崼", sprite = "shield",  isRanged = false, atkRange = 35, speed = 20, atkCd = 0.7,
                breakDmg = 2, desc = "閾佺浘褰撳叧锛岄┗瀹堥樀鍓嶆嫤鎴潵鏁? },
    MAGE    = { id = 4, name = "鐏敾鏈＋", sprite = "mage",    isRanged = true,  atkRange = 110, speed = 22, atkCd = 1.4,
                breakDmg = 2, desc = "鐏敾涔嬭锛岀剼鐑т竴鍒囨晫鍐涜惀瀵? },
    HEALER  = { id = 5, name = "鍐涘尰閬撳＋", sprite = "healer",  isRanged = true,  atkRange = 130, speed = 18, atkCd = 1.8,
                breakDmg = 1, desc = "濡欐墜鍥炴槬锛屾不鎰堟垜鍐涗激鍏垫畫鍗? },
    -- 澶у瀷/鐗规畩鍗曚綅
    CAVALRY  = { id = 9, name = "閾侀獞鍏堥攱", sprite = "cavalry",  isRanged = false, atkRange = 45, speed = 42, atkCd = 1.0,
                breakDmg = 4, spawnMax = 2, unitScale = 1.3, desc = "绛栭┈濂旇吘锛屾瀬閫熷啿閿嬫挒纰庢晫闃? },
    BEAST    = { id = 10, name = "鎴樿薄宸ㄥ吔", sprite = "beast",   isRanged = false, atkRange = 50, speed = 14, atkCd = 1.5,
                breakDmg = 6, spawnMax = 1, unitScale = 1.8, desc = "鍗楄洰鎴樿薄锛屼綋榄勯泟澹娍涓嶅彲鎸?, hpMult = 2.5, atkMult = 1.5 },
    ASSASSIN = { id = 11, name = "澶滆鍒哄", sprite = "assassin", isRanged = false, atkRange = 40, speed = 35, atkCd = 0.7,
                breakDmg = 3, spawnMax = 2, unitScale = 1.0, desc = "鏆楀娼滆锛岀粫鍚庡寘鎶勬挄瑁傚悗鎺? },
    LANCER   = { id = 12, name = "闀挎灙鍏?, sprite = "lancer",  isRanged = false, atkRange = 55, speed = 26, atkCd = 1.1,
                breakDmg = 2, spawnMax = 3, unitScale = 1.15, desc = "闀挎灙濡傞緳锛屼竴鍑诲彲璐┛鍓嶅悗浜屾晫" },
    -- 鐗规畩鍏电
    TALISMAN = { id = 13, name = "鐏墰绐佽", sprite = "talisman", isRanged = false, atkRange = 30, speed = 38, atkCd = 99,
                breakDmg = 10, spawnMax = 3, unitScale = 0.9, desc = "鐏墰鍐查樀锛屽啿鍚戞晫浜哄紩鐖嗙儓鐒?,
                isSuicider = true, explosionRadius = 60, explosionMult = 2.5 },
    PUPPETEER = { id = 14, name = "椹吔浣?, sprite = "puppeteer", isRanged = true, atkRange = 100, speed = 16, atkCd = 1.6,
                breakDmg = 1, spawnMax = 1, unitScale = 1.2, desc = "椹变娇鐚涘吔鍔╂垬锛屼笉鏂彫鍞よ蛋鍏藉弬鎴?,
                summonCd = 4.0, summonMax = 4 },
    ICE_MAGE = { id = 15, name = "瀵掑啺鏈＋", sprite = "ice_mage", isRanged = true, atkRange = 105, speed = 20, atkCd = 1.5,
                breakDmg = 1, spawnMax = 2, unitScale = 1.0, desc = "瀵掑啺渚佃殌锛屽喕缁撴晫浜鸿鍔ㄤ笌鏀婚€?,
                slowFactor = 0.4, slowDuration = 2.0 },
    SWARM    = { id = 16, name = "铚傚发铦楃兢", sprite = "swarm", isRanged = false, atkRange = 30, speed = 32, atkCd = 0.3,
                breakDmg = 1, spawnMax = 1, unitScale = 0.7, desc = "铦楃兢铚傛嫢鑰岃嚦锛屼互鏁伴噺娣规病鏁屼汉",
                swarmCount = 6, hpMult = 0.15, atkMult = 0.4 },
    -- 鏁屾柟鍏电
    DEMON_WARRIOR = { id = 6, name = "榛勫肪鍔涘＋", sprite = "demon_warrior", isRanged = false, atkRange = 40, speed = 27, atkCd = 0.9,
                breakDmg = 1, desc = "铔姏鎯婁汉鐨勯粍宸捐醇鍏碉紝鍑剁寷绐佽" },
    DEMON_ARCHER  = { id = 7, name = "灞辫醇寮撴墜", sprite = "demon_archer",  isRanged = true,  atkRange = 110, speed = 23, atkCd = 1.1,
                breakDmg = 1, desc = "鍗犲北涓虹帇鐨勫紦鎵嬶紝娣瘨杩滃皠" },
    DEMON_TANK    = { id = 8, name = "閾佺敳鎮嶅皢", sprite = "demon_tank",    isRanged = false, atkRange = 35, speed = 18, atkCd = 0.8,
                breakDmg = 3, desc = "韬姭閲嶉摖鐨勬倣灏嗭紝鍧氫笉鍙懅" },
}

local function MakeSlot(bgX, bgY)
    return { cx = bgX * BG2D_X, cy = bgY * BG2D_Y, filled = false, card = nil }
end

ENEMY_SLOTS = {
    MakeSlot(316, 77), MakeSlot(397, 77),
    MakeSlot(273, 199), MakeSlot(357, 199), MakeSlot(442, 199),
}

PLAYER_SLOTS = {
    MakeSlot(272, 1087), MakeSlot(357, 1087), MakeSlot(442, 1087),
    MakeSlot(186, 1205), MakeSlot(272, 1205), MakeSlot(358, 1205),
    MakeSlot(444, 1205), MakeSlot(528, 1205),
}

-- ============================================================================
-- 鍗＄墝鏁版嵁
-- ============================================================================
QUALITY = { COMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4, LIMITED = 5 }
QUALITY_NAMES = { "浜?, "鍦?, "澶?, "绁?, "闄? }
QUALITY_TAGS  = { "N", "R", "SR", "SSR", "闄愬畾SSR" }
QUALITY_COLORS = {
    [1] = { 200, 195, 180 },
    [2] = { 90, 210, 140 },
    [3] = { 170, 110, 255 },
    [4] = { 255, 190, 50 },
    [5] = { 255, 80, 120 },
}
QUALITY_GLOW = {
    [1] = { 200, 195, 180, 0 },
    [2] = { 90, 210, 140, 55 },
    [3] = { 170, 110, 255, 75 },
    [4] = { 255, 190, 50, 95 },
    [5] = { 255, 80, 120, 110 },
}

-- (CARD_COST 宸茬Щ闄? 瑙掕壊閫氳繃骞垮憡鎶藉崱鑾峰緱)

CARD_TYPE = { ATK = 1, DEF = 2, HEAL = 3, BUFF = 4 }
TYPE_NAMES = { "鏀?, "寰?, "鐤?, "杈? }
TYPE_COLORS = {
    [1] = { 220, 70, 60 },
    [2] = { 70, 130, 230 },
    [3] = { 70, 210, 120 },
    [4] = { 230, 190, 50 },
}

HERO_CARDS = {
    -- =====================================================================
    -- 浜烘鐏?(COMMON / N) 鈥?1~10
    -- =====================================================================
    -- 1. 绋嬫櫘 鈥?鍚村浗鑰佸皢锛岄搧鑴婄煕
    { name = "绋嬫櫘", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero1",
      atk = 720, def = 350, hp = 6500, unitClass = "LANCER", skill = "閾佽剨绌垮埡",
      skillData = { cd = 9, kind = "line", mult = 2.0, desc = "閾佽剨鐭涚洿鍒哄墠鏂癸紝鐩寸嚎绌垮埡閫犳垚200%浼ゅ" } },
    -- 2. 榛勭洊 鈥?鑻﹁倝璁＄伀鏀?
    { name = "榛勭洊", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero2",
      atk = 750, def = 280, hp = 5500, unitClass = "TALISMAN", skill = "鑻﹁倝鐏敾",
      skillData = { cd = 8, kind = "aoe", mult = 2.5, radius = 70, desc = "浠ヨ嫤鑲変箣璁″紩鐕冪儓鐏紝瀵硅寖鍥存晫浜洪€犳垚250%浼ゅ" } },
    -- 3. 闊╁綋 鈥?寮撻獞灏嗛
    { name = "闊╁綋", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero3",
      atk = 680, def = 300, hp = 6000, unitClass = "ARCHER", skill = "杩炵彔鍔插皠",
      skillData = { cd = 7, kind = "targeted", mult = 1.5, hits = 4, desc = "杩炲皠4鏀姴绠紝姣忕閫犳垚150%浼ゅ" } },
    -- 4. 寤栧寲 鈥?铚€姹夊厛閿?
    { name = "寤栧寲", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero4",
      atk = 700, def = 350, hp = 6500, unitClass = "SWORD", skill = "鍏堥攱绐佸嚮",
      skillData = { cd = 7, kind = "targeted", mult = 1.8, hits = 3, desc = "鍏堥攱涓夎繛鏂╋紝姣忓嚮閫犳垚180%浼ゅ" } },
    -- 5. 鍛ㄤ粨 鈥?鎵涘垁鎶ゅ崼
    { name = "鍛ㄤ粨", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero5",
      atk = 500, def = 650, hp = 8500, unitClass = "SHIELD", skill = "鎵涘垁瀹堟姢",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.20, duration = 6, desc = "浠ラ潚榫欏垁鎶ゅ崼鍏ㄥ啗锛屾柦鍔?0%鏈€澶х敓鍛芥姢鐩撅紝鎸佺画6绉? } },
    -- 6. 绯滅 鈥?绮崏瀹樿緟鍔?
    { name = "绯滅", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.COMMON, singleImg = "hero6",
      atk = 450, def = 380, hp = 7000, unitClass = "HEALER", skill = "绮崏琛ョ粰",
      skillData = { cd = 10, kind = "heal", healMult = 0.15, goldBonus = 2, desc = "杩愰€佺伯鑽夎ˉ缁欏叏鍐涳紝鎭㈠15%鏈€澶х敓鍛斤紝棰濆鑾峰緱2鍐涜祫" } },
    -- 7. 鏇规椽 鈥?鎶ゅ崼灏嗛
    { name = "鏇规椽", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero7",
      atk = 520, def = 600, hp = 8000, unitClass = "SHIELD", skill = "鑸嶈韩鎶や富",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.18, duration = 6, desc = "鑸嶈韩鎸″垁锛屽叏浣撳弸鍐涙柦鍔?8%鏈€澶х敓鍛芥姢鐩撅紝鎸佺画6绉? } },
    -- 8. 鏉庡吀 鈥?娌夌ǔ姝ュ皢
    { name = "鏉庡吀", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero8",
      atk = 680, def = 380, hp = 6800, unitClass = "SWORD", skill = "娌夊垁鏂?,
      skillData = { cd = 8, kind = "targeted", mult = 2.0, desc = "娌夌ǔ涓€鍒€鏂╀笅锛屽鍗曚綋閫犳垚200%浼ゅ" } },
    -- 9. 寮犱换 鈥?浼忓紦瀹堝皢
    { name = "寮犱换", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero9",
      atk = 700, def = 320, hp = 6200, unitClass = "ARCHER", skill = "浼忓嚮绠洦",
      skillData = { cd = 9, kind = "aoe", mult = 1.8, radius = 75, desc = "璁句紡鍙戠锛岃寖鍥寸闆ㄩ€犳垚180%浼ゅ" } },
    -- 10. 绾伒 鈥?涓夊皷鍒€姝﹀皢
    { name = "绾伒", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero10",
      atk = 730, def = 340, hp = 6600, unitClass = "LANCER", skill = "涓夊皷鍒烘潃",
      skillData = { cd = 8, kind = "targeted", mult = 2.2, desc = "涓夊皷涓ゅ垉鍒€鐚涘埡锛屽鍗曚綋閫犳垚220%浼ゅ" } },

    -- =====================================================================
    -- 鍦版鐏?(RARE / R) 鈥?11~22
    -- =====================================================================
    -- 11. 澶彶鎱?鈥?涓滃惔绁炲皠
    { name = "澶彶鎱?, row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero11",
      atk = 950, def = 360, hp = 6800, unitClass = "ARCHER", skill = "绁炲皠绌挎潹",
      skillData = { cd = 8, kind = "targeted", mult = 2.8, desc = "鐧炬绌挎潹鐨勭灏勪箣鎶€锛屽鍗曚綋閫犳垚280%浼ゅ" } },
    -- 12. 鐢樺畞 鈥?閿﹀竼鍒哄
    { name = "鐢樺畞", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero12",
      atk = 980, def = 330, hp = 6500, unitClass = "ASSASSIN", skill = "閿﹀竼绐佽",
      skillData = { cd = 7, kind = "targeted", mult = 2.0, hits = 3, desc = "閿﹀竼椋炲垁杩炲彂锛屾敾鍑?涓晫浜哄悇閫犳垚200%浼ゅ" } },
    -- 13. 寰愭檭 鈥?澶ф枾灏嗗啗
    { name = "寰愭檭", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero13",
      atk = 880, def = 450, hp = 7500, unitClass = "SWORD", skill = "澶ф枾妯壂",
      skillData = { cd = 9, kind = "aoe", mult = 2.2, radius = 90, desc = "宸ㄦ枾妯妶锛屽鑼冨洿鏁屼汉閫犳垚220%浼ゅ" } },
    -- 14. 寮犻儍 鈥?鏋硶绮惧
    { name = "寮犻儍", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero14",
      atk = 900, def = 550, hp = 8000, unitClass = "LANCER", skill = "濡欐灙杩炲埡",
      skillData = { cd = 9, kind = "line", mult = 2.5, desc = "鏋硶绮惧锛岀洿绾跨┛鍒洪€犳垚250%浼ゅ" } },
    -- 15. 榄忓欢 鈥?鍙嶉鐚涘皢
    { name = "榄忓欢", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero15",
      atk = 1050, def = 380, hp = 7800, unitClass = "SWORD", skill = "鍙嶉鐙傛柀",
      skillData = { cd = 10, kind = "aoe", mult = 2.5, radius = 85, desc = "鐙傛€уぇ鍙戞尌鍒€涔辨柀锛屽鑼冨洿鏁屼汉閫犳垚250%浼ゅ" } },
    -- 16. 鍏冲钩 鈥?闈掑勾缁ф壙鑰?
    { name = "鍏冲钩", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero16",
      atk = 920, def = 400, hp = 7200, unitClass = "SWORD", skill = "鎵跨埗鍒€娉?,
      skillData = { cd = 8, kind = "targeted", mult = 2.6, desc = "浼犳壙鍏冲叕鍒€娉曪紝瀵瑰崟浣撻€犳垚260%浼ゅ" } },
    -- 17. 楂橀『 鈥?闄烽樀涔嬪織
    { name = "楂橀『", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero17",
      atk = 480, def = 950, hp = 12500, unitClass = "SHIELD", skill = "闄烽樀澹佸瀿",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.22, duration = 6, desc = "闄烽樀钀ュ垪闃碉紝鍏ㄤ綋鍙嬪啗鏂藉姞22%鏈€澶х敓鍛芥姢鐩撅紝鎸佺画6绉? } },
    -- 18. 鏂囦笐 鈥?楠戝皢鐚涘啿
    { name = "鏂囦笐", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero18",
      atk = 1000, def = 420, hp = 7600, unitClass = "CAVALRY", skill = "鐚涢獞鍐查樀",
      skillData = { cd = 10, kind = "line", mult = 2.5, desc = "绛栭┈鍐查攱锛岀洿绾胯矾寰勪笂閫犳垚250%浼ゅ" } },
    -- 19. 棰滆壇 鈥?鍕囨鐚涘皢
    { name = "棰滆壇", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero19",
      atk = 980, def = 400, hp = 7400, unitClass = "SWORD", skill = "铏庡▉鍔堟柀",
      skillData = { cd = 9, kind = "targeted", mult = 2.8, desc = "铏庡▉鍔堟柀涓€鍑昏嚧鍛斤紝瀵瑰崟浣撻€犳垚280%浼ゅ" } },
    -- 20. 閭撹壘 鈥?鍋锋浮濂囪
    { name = "閭撹壘", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero20",
      atk = 950, def = 350, hp = 6800, unitClass = "ASSASSIN", skill = "鍋锋浮濂囪",
      skillData = { cd = 8, kind = "targeted", mult = 3.0, desc = "鍋锋浮闃村钩鐩村彇鍚庢柟锛屽鍗曚綋閫犳垚300%浼ゅ" } },
    -- 21. 閽熶細 鈥?璋嬬暐鍐涘笀
    { name = "閽熶細", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero21",
      atk = 800, def = 600, hp = 8500, unitClass = "MAGE", skill = "杩炵幆濡欒",
      skillData = { cd = 12, kind = "debuff", atkReduce = 0.25, duration = 7, desc = "鏂藉睍杩炵幆璁★紝鍏ㄤ綋鏁屼汉鏀诲嚮闄嶄綆25%锛屾寔缁?绉? } },
    -- 22. 闄嗘姉 鈥?闃插尽鍚嶅皢
    { name = "闄嗘姉", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero22",
      atk = 500, def = 1050, hp = 13000, unitClass = "SHIELD", skill = "瑗块櫟澹佸瀿",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.25, duration = 6, desc = "绛戝缓瑗块櫟闃茬嚎锛屽叏浣撳弸鍐涙柦鍔?5%鏈€澶х敓鍛芥姢鐩撅紝鎸佺画6绉? } },

    -- =====================================================================
    -- 澶╂鐏?(EPIC / SR) 鈥?23~30
    -- =====================================================================
    -- 23. 鍏搁煢 鈥?鍙屾垷鐚涘皢
    { name = "鍏搁煢", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero23",
      atk = 1350, def = 600, hp = 10200, unitClass = "SWORD", skill = "鍙屾垷缁濇潃",
      skillData = { cd = 12, kind = "aoe", mult = 2.8, radius = 100, desc = "鍙岄搧鎴熸棆椋庢í鎵紝瀵硅寖鍥存晫浜洪€犳垚280%浼ゅ" } },
    -- 24. 璁歌 鈥?铏庣棿鎶ゅ崼
    { name = "璁歌", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.EPIC, singleImg = "hero24",
      atk = 800, def = 1100, hp = 15000, unitClass = "SHIELD", skill = "铏庣棿鎬掑惣",
      skillData = { cd = 16, kind = "buff", shieldMult = 0.30, defBuff = 0.25, duration = 8, desc = "铏庣棿鎬掑惣闇囨厬鏁屽啗锛屽叏浣?30%鎶ょ浘+25%闃插尽锛屾寔缁?绉? } },
    -- 25. 瀛欑瓥 鈥?灏忛湼鐜嬪啿閿?
    { name = "瀛欑瓥", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero25",
      atk = 1200, def = 500, hp = 9500, unitClass = "CAVALRY", skill = "闇哥帇鍐查攱",
      skillData = { cd = 13, kind = "line", mult = 3.0, desc = "灏忛湼鐜嬬瓥椹啿閿嬶紝鐩寸嚎璺緞閫犳垚300%浼ゅ" } },
    -- 26. 澶忎警鎯?鈥?鎷旂煝鐚涘皢
    { name = "澶忎警鎯?, row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero26",
      atk = 1100, def = 700, hp = 11000, unitClass = "SWORD", skill = "鎷旂煝鍟栫潧",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.20, duration = 8, desc = "鎷旂煝涔嬪媷婵€鍔卞叏鍐涳紝鍏ㄤ綋鍙嬪啗鏀诲嚮鎻愬崌20%锛屾寔缁?绉? } },
    -- 27. 澶忎警娓?鈥?鎬ヨ灏嗗啗
    { name = "澶忎警娓?, row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero27",
      atk = 1200, def = 400, hp = 8500, unitClass = "ASSASSIN", skill = "鎬ヨ鍗冮噷",
      skillData = { cd = 8, kind = "targeted", mult = 3.5, desc = "鍗冮噷鎬ヨ鐩村彇鏁屽皢棣栫骇锛屽鍗曚綋閫犳垚350%浼ゅ" } },
    -- 28. 椹秴 鈥?鏋獞鏃犲弻
    { name = "椹秴", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero28",
      atk = 1300, def = 480, hp = 9000, unitClass = "CAVALRY", skill = "鏋獞澶╀笅",
      skillData = { cd = 13, kind = "line", mult = 3.2, desc = "瑗垮噳鏋獞甯嵎鎴樺満锛岀洿绾块€犳垚320%浼ゅ" } },
    -- 29. 榛勫繝 鈥?绁炵鑰佸皢
    { name = "榛勫繝", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero29",
      atk = 1250, def = 420, hp = 8200, unitClass = "ARCHER", skill = "鐧炬绌跨敳",
      skillData = { cd = 10, kind = "targeted", mult = 4.0, desc = "鑰佸皢鐧炬绌跨敳绠紝瀵瑰崟浣撻€犳垚400%浼ゅ" } },
    -- 30. 寮犺窘 鈥?濞侀渿閫嶉仴
    { name = "寮犺窘", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero30",
      atk = 1150, def = 650, hp = 10500, unitClass = "CAVALRY", skill = "濞侀渿閫嶉仴娲?,
      skillData = { cd = 14, kind = "aoe", mult = 2.6, radius = 95, desc = "鍏櫨楠戠獊琚崄涓囧啗锛屽鑼冨洿鏁屼汉閫犳垚260%浼ゅ" } },

    -- =====================================================================
    -- 绁炴鐏?(LEGENDARY / SSR) 鈥?31~36
    -- =====================================================================
    -- 31. 璧典簯 鈥?甯稿北榫欒儐
    { name = "璧典簯", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero31",
      atk = 1450, def = 650, hp = 11000, unitClass = "LANCER", skill = "涓冭繘涓冨嚭",
      skillData = { cd = 14, kind = "aoe", mult = 3.5, radius = 120, desc = "甯稿北璧靛瓙榫欎竷杩涗竷鍑猴紝瀵硅寖鍥存晫浜洪€犳垚350%浼ゅ" } },
    -- 32. 寮犻 鈥?涓囦汉鑾晫
    { name = "寮犻", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero32",
      atk = 1400, def = 550, hp = 9500, unitClass = "SWORD", skill = "涓囦汉鏁屽惣",
      skillData = { cd = 14, kind = "targeted", mult = 5.0, desc = "鐕曚汉寮犵考寰蜂竴澹版€掑惣锛屽鍗曚綋閫犳垚500%浼ゅ" } },
    -- 33. 鍏崇窘 鈥?姝﹀湥闄嶄复
    { name = "鍏崇窘", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero33",
      atk = 1500, def = 600, hp = 10500, unitClass = "SWORD", skill = "闈掗緳鏂╂湀",
      skillData = { cd = 15, kind = "aoe", mult = 3.8, radius = 110, desc = "闈掗緳鍋冩湀鍒€妯壂鍗冨啗锛屽鑼冨洿鏁屼汉閫犳垚380%浼ゅ" } },
    -- 34. 鍛ㄧ憸 鈥?鐏儳璧ゅ
    { name = "鍛ㄧ憸", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero34",
      atk = 1300, def = 500, hp = 8800, unitClass = "MAGE", skill = "鐏儳璧ゅ",
      skillData = { cd = 15, kind = "debuff", defReduce = 0.35, duration = 8, desc = "璧ゅ鐑堢劙鐒氬ぉ锛屽叏浣撴晫浜洪槻寰￠檷浣?5%锛屾寔缁?绉? } },
    -- 35. 鍚曞竷 鈥?澶╀笅鏃犲弻
    { name = "鍚曞竷", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero35",
      atk = 1550, def = 580, hp = 10000, unitClass = "CAVALRY", skill = "澶╀笅鏃犲弻",
      skillData = { cd = 14, kind = "aoe", mult = 3.8, radius = 110, desc = "鏂瑰ぉ鐢绘垷妯壂澶╀笅锛屽鑼冨洿鏁屼汉閫犳垚380%浼ゅ" } },
    -- 36. 璇歌憶浜?鈥?鍗ч緳涔嬫櫤
    { name = "璇歌憶浜?, row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero36",
      atk = 1200, def = 700, hp = 9800, unitClass = "MAGE", skill = "鍏樀鍥?,
      skillData = { cd = 16, kind = "buff", atkBuff = 0.25, defBuff = 0.20, duration = 10, desc = "甯冧笅鍏樀鍥撅紝鍏ㄥ啗鏀诲嚮+25%闃插尽+20%锛屾寔缁?0绉? } },

    -- =====================================================================
    -- 闄愬畾绁炴鐏?(LIMITED / 闄愬畾SSR) 鈥?37~40
    -- =====================================================================
    -- 37. 鍏崇窘路姝﹀湥褰掑ぉ
    { name = "鍏崇窘路姝﹀湥褰掑ぉ", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LIMITED, singleImg = "hero37",
      atk = 1950, def = 850, hp = 14500, unitClass = "SWORD", skill = "姝﹀湥澶╃綒",
      skillData = { cd = 15, kind = "aoe", mult = 5.0, radius = 140, desc = "姝﹀湥鎬掓剰璐€氬ぉ鍦帮紝瀵硅寖鍥存晫浜洪€犳垚500%浼ゅ" } },
    -- 38. 鍚曞竷路椋炲皢鏃犲弻
    { name = "鍚曞竷路椋炲皢鏃犲弻", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LIMITED, singleImg = "hero38",
      atk = 2000, def = 780, hp = 13800, unitClass = "CAVALRY", skill = "椋炲皢鐏笘",
      skillData = { cd = 14, kind = "aoe", mult = 5.5, radius = 150, desc = "椋炲皢涔嬪▉闄嶄复鎴樺満锛屽鑼冨洿鏁屼汉閫犳垚550%浼ゅ" } },
    -- 39. 璇歌憶浜峰崸榫欏嚭灞?
    { name = "璇歌憶浜峰崸榫欏嚭灞?, row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LIMITED, singleImg = "hero39",
      atk = 1650, def = 950, hp = 13200, unitClass = "MAGE", skill = "鍗ч緳澶╃伀",
      skillData = { cd = 15, kind = "aoe", mult = 4.2, radius = 135, dot = 0.5, dotDur = 6, desc = "鍗ч緳绁ぉ鐏鐩栧叏鍦猴紝鑼冨洿420%浼ゅ+鐏肩儳(50%鏀诲嚮/绉?鎸佺画6绉? } },
    -- 40. 鏇规搷路榄忔鎸ラ灜
    { name = "鏇规搷路榄忔鎸ラ灜", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LIMITED, singleImg = "hero40",
      atk = 1750, def = 900, hp = 14200, unitClass = "MAGE", skill = "榄忔鍙蜂护",
      skillData = { cd = 14, kind = "buff", atkBuff = 0.40, defBuff = 0.20, duration = 12, desc = "榄忔鎸ラ灜鍙蜂护澶╀笅锛屽叏鍐涙敾鍑?40%闃插尽+20%锛屾寔缁?2绉? } },
}

-- ============================================================================
-- 鎴樹簤鐗堝寮? 闃佃惀 / 鍏电鍏嬪埗 / 浜旂淮灞炴€?
-- ============================================================================

--- 闃佃惀瀹氫箟
FACTIONS = {
    shu = { name = "铚€", color = {220, 60, 60},  icon = "铚€" },
    wei = { name = "榄?, color = {60, 100, 220}, icon = "榄? },
    wu  = { name = "鍚?, color = {60, 180, 60},  icon = "鍚? },
    qun = { name = "缇?, color = {180, 160, 60}, icon = "缇? },
}

--- 鍏电鍏嬪埗绫诲瀷 (涓夊浗缇よ嫳浼犻鏍煎洓鍏电寰幆鍏嬪埗)
--- 姝ュ叺 > 寮撳叺 > 楠戝叺 > 鏋叺 > 姝ュ叺
TROOP_TYPES = {
    infantry = { name = "姝ュ叺", icon = "姝?, color = {200, 80, 60} },
    archer   = { name = "寮撳叺", icon = "寮?, color = {60, 180, 60} },
    cavalry  = { name = "楠戝叺", icon = "楠?, color = {60, 100, 220} },
    spear    = { name = "鏋叺", icon = "鏋?, color = {220, 160, 60} },
    special  = { name = "鐗规畩", icon = "鐗?, color = {180, 100, 255} },
}

--- 鍏嬪埗鍏崇郴: TROOP_COUNTER[鎴戞柟][鏁屾柟] = 浼ゅ鍊嶇巼
--- 鍏嬪埗 = 1.3x, 琚厠 = 0.7x, 鏃犲叧 = 1.0x
TROOP_COUNTER = {
    infantry = { infantry = 1.0, archer = 1.3, cavalry = 0.7, spear = 1.0, special = 1.0 },
    archer   = { infantry = 0.7, archer = 1.0, cavalry = 1.3, spear = 1.0, special = 1.0 },
    cavalry  = { infantry = 1.0, archer = 0.7, cavalry = 1.0, spear = 1.3, special = 1.0 },
    spear    = { infantry = 1.0, archer = 1.0, cavalry = 0.7, spear = 1.0, special = 1.0 },
    special  = { infantry = 1.0, archer = 1.0, cavalry = 1.0, spear = 1.0, special = 1.0 },
}

--- unitClass 鈫?troopType 榛樿鏄犲皠
local UNIT_TROOP_MAP = {
    SWORD = "infantry", SHIELD = "infantry",
    LANCER = "spear",
    CAVALRY = "cavalry", ASSASSIN = "cavalry",
    ARCHER = "archer", MAGE = "archer", HEALER = "archer",
    TALISMAN = "special", PUPPETEER = "special", ICE_MAGE = "special",
    SWARM = "special", BEAST = "special",
    -- 鏁屾柟鍏电
    DEMON_WARRIOR = "infantry", DEMON_ARCHER = "archer", DEMON_TANK = "infantry",
}

--- 鑾峰彇鍏电鍏嬪埗浼ゅ鍊嶇巼
function GetTroopCounterMult(attackerTroop, defenderTroop)
    local row = TROOP_COUNTER[attackerTroop]
    if not row then return 1.0 end
    return row[defenderTroop] or 1.0
end

--- 姣忎釜鑻遍泟鐨勯樀钀?(鎸夌储寮? 1~40)
local HERO_FACTIONS = {
    -- 浜烘鐏?1~10
    [1]  = "wu",   -- 绋嬫櫘
    [2]  = "wu",   -- 榛勭洊
    [3]  = "wu",   -- 闊╁綋
    [4]  = "shu",  -- 寤栧寲
    [5]  = "shu",  -- 鍛ㄤ粨
    [6]  = "shu",  -- 绯滅
    [7]  = "wei",  -- 鏇规椽
    [8]  = "wei",  -- 鏉庡吀
    [9]  = "qun",  -- 寮犱换
    [10] = "qun",  -- 绾伒
    -- 鍦版鐏?11~22
    [11] = "wu",   -- 澶彶鎱?
    [12] = "wu",   -- 鐢樺畞
    [13] = "wei",  -- 寰愭檭
    [14] = "wei",  -- 寮犻儍
    [15] = "shu",  -- 榄忓欢
    [16] = "shu",  -- 鍏冲钩
    [17] = "qun",  -- 楂橀『
    [18] = "qun",  -- 鏂囦笐
    [19] = "qun",  -- 棰滆壇
    [20] = "wei",  -- 閭撹壘
    [21] = "wei",  -- 閽熶細
    [22] = "wu",   -- 闄嗘姉
    -- 澶╂鐏?23~30
    [23] = "wei",  -- 鍏搁煢
    [24] = "wei",  -- 璁歌
    [25] = "wu",   -- 瀛欑瓥
    [26] = "wei",  -- 澶忎警鎯?
    [27] = "wei",  -- 澶忎警娓?
    [28] = "qun",  -- 椹秴 (瑗垮噳)
    [29] = "shu",  -- 榛勫繝
    [30] = "wei",  -- 寮犺窘
    -- 绁炴鐏?31~36
    [31] = "shu",  -- 璧典簯
    [32] = "shu",  -- 寮犻
    [33] = "shu",  -- 鍏崇窘
    [34] = "wu",   -- 鍛ㄧ憸
    [35] = "qun",  -- 鍚曞竷
    [36] = "shu",  -- 璇歌憶浜?
    -- 闄愬畾姝︾伒 37~40
    [37] = "shu",  -- 鍏崇窘路姝﹀湥褰掑ぉ
    [38] = "qun",  -- 鍚曞竷路椋炲皢鏃犲弻
    [39] = "shu",  -- 璇歌憶浜峰崸榫欏嚭灞?
    [40] = "wei",  -- 鏇规搷路榄忔鎸ラ灜
}

--- 浜旂淮灞炴€?(姝﹀姏/鏅哄姏/浣撳姏/鎶€鍔?閫熷害) 鎸夎嫳闆勭储寮?
--- 鏁板€艰寖鍥?1~100, 褰卞搷鍐呮斂鎸囦护鏁堢巼鍜屾垬鍦鸿〃鐜?
local HERO_STATS5 = {
    -- 浜烘鐏?1~10 (鍩虹灞炴€ц緝浣?
    [1]  = { str = 55, int = 30, vit = 50, tec = 40, spd = 45 },  -- 绋嬫櫘
    [2]  = { str = 60, int = 35, vit = 40, tec = 50, spd = 40 },  -- 榛勭洊
    [3]  = { str = 50, int = 30, vit = 45, tec = 55, spd = 50 },  -- 闊╁綋
    [4]  = { str = 55, int = 25, vit = 50, tec = 35, spd = 50 },  -- 寤栧寲
    [5]  = { str = 45, int = 20, vit = 65, tec = 25, spd = 35 },  -- 鍛ㄤ粨
    [6]  = { str = 25, int = 55, vit = 45, tec = 60, spd = 30 },  -- 绯滅
    [7]  = { str = 50, int = 25, vit = 60, tec = 30, spd = 40 },  -- 鏇规椽
    [8]  = { str = 50, int = 40, vit = 50, tec = 40, spd = 40 },  -- 鏉庡吀
    [9]  = { str = 55, int = 35, vit = 48, tec = 50, spd = 42 },  -- 寮犱换
    [10] = { str = 58, int = 25, vit = 50, tec = 38, spd = 45 },  -- 绾伒
    -- 鍦版鐏?11~22 (涓瓑灞炴€?
    [11] = { str = 72, int = 35, vit = 52, tec = 65, spd = 58 },  -- 澶彶鎱?
    [12] = { str = 75, int = 40, vit = 48, tec = 60, spd = 70 },  -- 鐢樺畞
    [13] = { str = 68, int = 35, vit = 58, tec = 45, spd = 50 },  -- 寰愭檭
    [14] = { str = 70, int = 50, vit = 60, tec = 55, spd = 48 },  -- 寮犻儍
    [15] = { str = 78, int = 30, vit = 60, tec = 40, spd = 55 },  -- 榄忓欢
    [16] = { str = 70, int = 35, vit = 55, tec = 50, spd = 52 },  -- 鍏冲钩
    [17] = { str = 45, int = 30, vit = 80, tec = 35, spd = 38 },  -- 楂橀『
    [18] = { str = 78, int = 25, vit = 58, tec = 35, spd = 62 },  -- 鏂囦笐
    [19] = { str = 75, int = 28, vit = 56, tec = 38, spd = 55 },  -- 棰滆壇
    [20] = { str = 72, int = 65, vit = 50, tec = 70, spd = 60 },  -- 閭撹壘
    [21] = { str = 55, int = 80, vit = 50, tec = 72, spd = 45 },  -- 閽熶細
    [22] = { str = 45, int = 60, vit = 75, tec = 55, spd = 40 },  -- 闄嗘姉
    -- 澶╂鐏?23~30 (楂樺睘鎬?
    [23] = { str = 90, int = 20, vit = 70, tec = 35, spd = 65 },  -- 鍏搁煢
    [24] = { str = 70, int = 25, vit = 92, tec = 30, spd = 50 },  -- 璁歌
    [25] = { str = 85, int = 55, vit = 62, tec = 60, spd = 75 },  -- 瀛欑瓥
    [26] = { str = 82, int = 35, vit = 75, tec = 45, spd = 55 },  -- 澶忎警鎯?
    [27] = { str = 80, int = 40, vit = 55, tec = 60, spd = 82 },  -- 澶忎警娓?
    [28] = { str = 88, int = 30, vit = 60, tec = 50, spd = 85 },  -- 椹秴
    [29] = { str = 85, int = 38, vit = 58, tec = 75, spd = 42 },  -- 榛勫繝
    [30] = { str = 82, int = 55, vit = 68, tec = 50, spd = 72 },  -- 寮犺窘
    -- 绁炴鐏?31~36 (鏋侀珮灞炴€?
    [31] = { str = 92, int = 45, vit = 72, tec = 65, spd = 88 },  -- 璧典簯
    [32] = { str = 95, int = 25, vit = 68, tec = 40, spd = 70 },  -- 寮犻
    [33] = { str = 97, int = 40, vit = 70, tec = 55, spd = 65 },  -- 鍏崇窘
    [34] = { str = 55, int = 98, vit = 50, tec = 90, spd = 60 },  -- 鍛ㄧ憸
    [35] = { str = 99, int = 30, vit = 65, tec = 50, spd = 90 },  -- 鍚曞竷
    [36] = { str = 40, int = 99, vit = 55, tec = 95, spd = 50 },  -- 璇歌憶浜?
    -- 闄愬畾姝︾伒 37~40 (椤剁骇灞炴€?
    [37] = { str = 98, int = 45, vit = 78, tec = 60, spd = 72 },  -- 鍏崇窘路姝﹀湥褰掑ぉ
    [38] = { str = 99, int = 35, vit = 72, tec = 55, spd = 92 },  -- 鍚曞竷路椋炲皢鏃犲弻
    [39] = { str = 50, int = 99, vit = 62, tec = 98, spd = 55 },  -- 璇歌憶浜峰崸榫欏嚭灞?
    [40] = { str = 80, int = 95, vit = 75, tec = 88, spd = 60 },  -- 鏇规搷路榄忔鎸ラ灜
}

--- 姣忎釜姝﹀皢鍙€夊叺绉?(鎸?unitClass 榛樿 + 鍚嶅皢鐗规畩瑕嗙洊)
--- 绗竴椤逛负榛樿鍏电, 鐜╁鍙湪姝﹀皢绠＄悊闈㈡澘涓垏鎹?
local TROOP_OPTIONS_BY_CLASS = {
    SWORD    = { "infantry", "spear" },
    SHIELD   = { "infantry", "spear" },
    LANCER   = { "spear", "cavalry" },
    CAVALRY  = { "cavalry", "infantry" },
    ASSASSIN = { "cavalry", "infantry" },
    ARCHER   = { "archer", "infantry" },
    MAGE     = { "archer", "special" },
    HEALER   = { "archer", "infantry" },
    TALISMAN = { "special", "archer", "infantry" },
}
--- 鍚嶅皢涓撳睘鍏电瑕嗙洊 (3绉嶅叺绉? 浣撶幇鍚嶅皢鐨勫闈㈡€?
local HERO_TROOP_OVERRIDES = {
    [25] = { "cavalry", "spear", "infantry" },    -- 瀛欑瓥: 灏忛湼鐜嬮獞鍐?鏋樀/姝ュ叺
    [28] = { "cavalry", "spear" },                 -- 椹秴: 瑗垮噳閾侀獞/鏋獞
    [30] = { "cavalry", "archer", "infantry" },    -- 寮犺窘: 楠戝叺/寮撻獞/姝ュ叺
    [31] = { "spear", "cavalry", "infantry" },     -- 璧典簯: 榫欒儐鏋?楠戝叺/姝ュ叺
    [33] = { "infantry", "cavalry", "spear" },     -- 鍏崇窘: 姝ュ叺/楠戝叺/鏋叺
    [34] = { "archer", "special" },                 -- 鍛ㄧ憸: 寮撳叺/鐗规畩
    [35] = { "cavalry", "spear", "infantry" },     -- 鍚曞竷: 楠戝叺/鏋叺/姝ュ叺
    [36] = { "archer", "special", "infantry" },    -- 璇歌憶浜? 寮撳叺/鐗规畩/姝ュ叺
    [37] = { "infantry", "cavalry", "spear" },     -- 鍏崇窘路姝﹀湥: 姝?楠?鏋?
    [38] = { "cavalry", "spear", "infantry" },     -- 鍚曞竷路椋炲皢: 楠?鏋?姝?
    [39] = { "archer", "special", "infantry" },    -- 璇歌憶浜峰崸榫? 寮?鐗?姝?
    [40] = { "archer", "special", "cavalry" },     -- 鏇规搷路榄忔: 寮?鐗?楠?
}

--- 鑾峰彇姝﹀皢鍙€夊叺绉嶅垪琛?
function GetHeroTroopOptions(heroIdx)
    if HERO_TROOP_OVERRIDES[heroIdx] then
        return HERO_TROOP_OVERRIDES[heroIdx]
    end
    local card = HERO_CARDS[heroIdx]
    if card then
        return TROOP_OPTIONS_BY_CLASS[card.unitClass] or { "infantry" }
    end
    return { "infantry" }
end

--- 姣忎釜姝﹀皢鐨勫垵濮嬫鎶€ (浠?6涓猄KILL_TECHNIQUES涓寜姝﹀皢鐗圭偣鍒嗛厤)
--- 鍊间负 SKILL_TECHNIQUES 鐨勭储寮? 姣忎釜姝﹀皢1涓垵濮嬫鎶€
HERO_INIT_TECHNIQUES = {
    -- 浜烘鐏?1~10 (鍑″搧/鑹搧姝︽妧)
    [1]  = 1,   -- 绋嬫櫘: 鐮撮攱閽?(鍑″搧)
    [2]  = 2,   -- 榛勭洊: 鐑界伀闄勮韩 (鍑″搧)
    [3]  = 7,   -- 闊╁綋: 绌垮績绠?(鑹搧)
    [4]  = 6,   -- 寤栧寲: 鏃嬮鏂?(鍑″搧)
    [5]  = 3,   -- 鍛ㄤ粨: 鍦拌鎺㈤樀 (鍑″搧)
    [6]  = 16,  -- 绯滅: 鐏垫硥鍥炴槬 (浼樺搧, 娌荤枟鍨嬬鍚堝叾杈呭姪瀹氫綅)
    [7]  = 5,   -- 鏇规椽: 缂氭晫涓?(鍑″搧)
    [8]  = 4,   -- 鏉庡吀: 闇滈攱涓€绾?(鍑″搧)
    [9]  = 8,   -- 寮犱换: 鑽嗘缂犲湴 (鑹搧)
    [10] = 11,  -- 绾伒: 鍦板埡杩炴帰 (鑹搧)
    -- 鍦版鐏?11~22 (鑹搧/浼樺搧姝︽妧)
    [11] = 12,  -- 澶彶鎱? 椋炲垉杩炴 (鑹搧)
    [12] = 9,   -- 鐢樺畞: 瀵掓１璐 (鑹搧)
    [13] = 18,  -- 寰愭檭: 纰庡博鍐插嚮 (浼樺搧)
    [14] = 17,  -- 寮犻儍: 鐜勮殌寰?(浼樺搧)
    [15] = 13,  -- 榄忓欢: 涓囩鍧犻樀 (浼樺搧)
    [16] = 10,  -- 鍏冲钩: 濂旈浄绌垮灒 (鑹搧)
    [17] = 14,  -- 楂橀『: 瀵掓笂鍐板皝 (浼樺搧)
    [18] = 15,  -- 鏂囦笐: 澶╅浄缃氬煙 (浼樺搧)
    [19] = 18,  -- 棰滆壇: 纰庡博鍐插嚮 (浼樺搧)
    [20] = 17,  -- 閭撹壘: 鐜勮殌寰?(浼樺搧)
    [21] = 15,  -- 閽熶細: 澶╅浄缃氬煙 (浼樺搧)
    [22] = 14,  -- 闄嗘姉: 瀵掓笂鍐板皝 (浼樺搧)
    -- 澶╂鐏?23~30 (灏嗗搧姝︽妧)
    [23] = 19,  -- 鍏搁煢: 鐑界伀鐕庡師 (灏嗗搧)
    [24] = 21,  -- 璁歌: 鍐扮嫳灏侀樀 (灏嗗搧)
    [25] = 23,  -- 瀛欑瓥: 鐮村啗鍣瓊鍗?(灏嗗搧)
    [26] = 24,  -- 澶忎警鎯? 闀囧啗纰戝帇 (灏嗗搧)
    [27] = 22,  -- 澶忎警娓? 闆风嫳鍥氶樀 (灏嗗搧)
    [28] = 19,  -- 椹秴: 鐑界伀鐕庡師 (灏嗗搧)
    [29] = 20,  -- 榛勫繝: 璧ゅ鐒氬煙 (灏嗗搧)
    [30] = 23,  -- 寮犺窘: 鐮村啗鍣瓊鍗?(灏嗗搧)
    -- 绁炴鐏?31~36 (渚搧/鐜嬪搧姝︽妧)
    [31] = 25,  -- 璧典簯: 榫欏悷璐储 (渚搧)
    [32] = 29,  -- 寮犻: 杩滃彜榫欓瓊韪忓湴 (渚搧)
    [33] = 28,  -- 鍏崇窘: 姝︾伒鍓戣疮涓夌晫 (渚搧)
    [34] = 26,  -- 鍛ㄧ憸: 涔濆ぉ闆风┛ (渚搧)
    [35] = 30,  -- 鍚曞竷: 涓囩伒褰掑琛嶅煙 (渚搧)
    [36] = 27,  -- 璇歌憶浜? 鏋佸瘨鍐板皝璐┖ (渚搧)
    -- 闄愬畾姝︾伒 37~40 (鐜嬪搧/甯濆搧姝︽妧)
    [37] = 31,  -- 鍏崇窘路姝﹀湥: 涔濆ぉ鍖栭緳涓囧煙 (鐜嬪搧)
    [38] = 35,  -- 鍚曞竷路椋炲皢: 涓嶇伃澶╁煙 (鐜嬪搧)
    [39] = 33,  -- 璇歌憶浜峰崸榫? 鍗冨啗鍐荤粷鍐板煙 (鐜嬪搧)
    [40] = 32,  -- 鏇规搷路榄忔: 澶╁懡闆烽煶 (鐜嬪搧)
}

--- 鎵归噺娉ㄥ叆: 涓烘墍鏈?HERO_CARDS 娣诲姞 faction / troopType / stats5 / troopOptions / initTechnique
for i, card in ipairs(HERO_CARDS) do
    card.faction = HERO_FACTIONS[i] or "qun"
    card.troopType = UNIT_TROOP_MAP[card.unitClass] or "infantry"
    card.stats5 = HERO_STATS5[i] or { str = 50, int = 50, vit = 50, tec = 50, spd = 50 }
    card.troopOptions = GetHeroTroopOptions(i)
    card.initTechnique = HERO_INIT_TECHNIQUES[i]
end

--- 涔熶负 ENEMY_CARDS 娉ㄥ叆 troopType (鏁屾柟鏃犻樀钀?
-- (鍦?ENEMY_CARDS 瀹氫箟涔嬪悗鎵ц, 瑙佷笅鏂?

ENEMY_CARDS = {
    -- 1. 榛勫肪鍔涘＋ (璐煎叺鍏堥攱)
    { name = "榛勫肪鍔涘＋", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE,
      atk = 1000, def = 480, hp = 8400, unitClass = "DEMON_WARRIOR", skill = "妯壂鍗冨啗",
      singleImg = "enemy1" },
    -- 2. 灞辫醇澶撮 (璐煎叺鍏堥攱)
    { name = "灞辫醇澶撮", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC,
      atk = 1400, def = 360, hp = 6600, unitClass = "DEMON_WARRIOR", skill = "澶滆绐佽繘",
      singleImg = "enemy2" },
    -- 3. 璐煎啗寮撴墜 (璐煎叺寮撴墜)
    { name = "璐煎啗寮撴墜", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE,
      atk = 840, def = 600, hp = 7800, unitClass = "DEMON_ARCHER", skill = "杩炵彔绠洦",
      singleImg = "enemy3" },
    -- 4. 鐑界伀鏆村緬 (璐煎叺鍏堥攱)
    { name = "鐑界伀鏆村緬", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 780, def = 380, hp = 7000, unitClass = "DEMON_WARRIOR", skill = "鐑堢伀鏂?,
      singleImg = "enemy4" },
    -- 5. 鍙涘啗鐫ｅ竻 (璐煎叺閲嶇敳) BOSS
    { name = "鍙涘啗鐫ｅ竻", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.LEGENDARY,
      atk = 1100, def = 1200, hp = 18000, unitClass = "DEMON_TANK", skill = "鐫ｅ竻涔嬬浘",
      isBoss = true, bossScale = 1.5, singleImg = "enemy5" },
    -- 6. 閾侀攣鐙卞崚 (璐煎叺閲嶇敳)
    { name = "閾侀攣鐙卞崚", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON,
      atk = 600, def = 950, hp = 12000, unitClass = "DEMON_TANK", skill = "閾侀攣缂犵粫",
      singleImg = "enemy6" },
    -- 7. 璐煎啗绁笀 (璐煎叺寮撴墜)
    { name = "璐煎啗绁笀", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.RARE,
      atk = 540, def = 660, hp = 9600, unitClass = "DEMON_ARCHER", skill = "鍥炴槬涔嬫湳",
      singleImg = "enemy7" },
    -- 8. 鐦存皵宸コ (璐煎叺寮撴墜)
    { name = "鐦存皵宸コ", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 720, def = 340, hp = 6200, unitClass = "DEMON_ARCHER", skill = "鐦存皵寮ユ极",
      singleImg = "enemy8" },
    -- 9. 璐煎啗寮╁叺 (璐煎叺寮撴墜)
    { name = "璐煎啗寮╁叺", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 740, def = 300, hp = 5800, unitClass = "DEMON_ARCHER", skill = "绌跨敳杩炲皠",
      singleImg = "enemy9" },
    -- 10. 閾佺敳楠戝＋ (璐煎叺閲嶇敳)
    { name = "閾佺敳楠戝＋", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE,
      atk = 720, def = 900, hp = 11400, unitClass = "DEMON_TANK", skill = "閾佸澹佸瀿",
      singleImg = "enemy10" },
    -- 11. 鎮嶅尓灞犲か (璐煎叺鍏堥攱)
    { name = "鎮嶅尓灞犲か", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 900, def = 420, hp = 7400, unitClass = "DEMON_WARRIOR", skill = "鐙傛毚灞犳埉",
      singleImg = "enemy11" },
    -- 12. 姣掕棨鏈＋ (璐煎叺寮撴墜)
    { name = "姣掕棨鏈＋", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.EPIC,
      atk = 660, def = 600, hp = 9000, unitClass = "DEMON_ARCHER", skill = "钘よ敁鍥炵敓",
      singleImg = "enemy12" },
    -- 13. 铔崚鐙傛垬 (璐煎叺鍏堥攱)
    { name = "铔崚鐙傛垬", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 840, def = 360, hp = 6600, unitClass = "DEMON_WARRIOR", skill = "鐙傛€掓€掑惣",
      singleImg = "enemy13" },
    -- 14. 鏆楀崼濂冲皢 (璐煎叺閲嶇敳)
    { name = "鏆楀崼濂冲皢", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE,
      atk = 580, def = 840, hp = 10200, unitClass = "DEMON_TANK", skill = "閾佸鎶ょ浘",
      singleImg = "enemy14" },
    -- 15. 閾佺敳姝﹀＋ (璐煎叺鍏堥攱)
    { name = "閾佺敳姝﹀＋", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON,
      atk = 820, def = 450, hp = 7000, unitClass = "DEMON_WARRIOR", skill = "閾佺敳鍐查攱",
      singleImg = "enemy15" },
    -- 16. 娌兼辰鏈＋ (璐煎叺寮撴墜)
    { name = "娌兼辰鏈＋", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE,
      atk = 720, def = 540, hp = 8400, unitClass = "DEMON_ARCHER", skill = "娌兼辰缂犵粫",
      singleImg = "enemy16" },
}

--- 涓?ENEMY_CARDS 娉ㄥ叆 troopType
for _, ecard in ipairs(ENEMY_CARDS) do
    ecard.troopType = UNIT_TROOP_MAP[ecard.unitClass] or "infantry"
end

-- ============================================================================
-- 瑁呭绯荤粺 (鍏电敳)
-- ============================================================================
EQUIP_SLOT_NAMES = { "姝﹀櫒", "澶寸洈", "鑳哥敳", "鎶よ吙", "鎴橀澊", "浣╅グ", "鍏典功" }

-- 瑁呭闃剁骇 (6闃?
EQUIP_TIERS = {
    { name = "鍑″搧", color = { 180, 175, 165 }, glow = { 180, 175, 165, 0 }, multiplier = 1.0 },
    { name = "鑹搧", color = { 100, 210, 120 }, glow = { 100, 210, 120, 40 }, multiplier = 1.3 },
    { name = "浼樺搧", color = { 80, 160, 255 },  glow = { 80, 160, 255, 60 }, multiplier = 1.6 },
    { name = "灏嗗搧", color = { 180, 100, 255 }, glow = { 180, 100, 255, 80 }, multiplier = 2.0 },
    { name = "鐜嬪搧", color = { 255, 180, 50 },  glow = { 255, 180, 50, 100 }, multiplier = 2.5 },
    { name = "甯濆搧", color = { 255, 80, 80 },   glow = { 255, 80, 80, 120 }, multiplier = 3.2 },
}
EQUIP_TIER_NAMES = { "鍑″搧", "鑹搧", "浼樺搧", "灏嗗搧", "鐜嬪搧", "甯濆搧" }

EQUIPMENT_SETS = {
    { -- Set 1 (col 0): 铏庣墷鍏冲 鈥?闃插尽鍨?| 棰濆璇嶆潯: 鍑忎激
        name = "铏庣墷鍏冲", theme = "鍥哄畧", color = { 120, 180, 255 },
        extraKey = "dmgReduction", extraName = "鍑忎激",
        setBonus3 = { atkPct = 0, defPct = 3, hpPct = 5, dmgReduction = 3 },
        setBonus3Desc = "闃插尽+3% 鐢熷懡+5% 鍑忎激+3%",
        setBonus4 = { atkPct = 0, defPct = 5, hpPct = 8, dmgReduction = 6 },
        setBonus4Desc = "闃插尽+5% 鐢熷懡+8% 鍑忎激+6%",
        setBonus = { atkPct = 0, defPct = 8, hpPct = 12, dmgReduction = 10 },
        setBonusDesc = "鍏ㄥ憳闃插尽+8% 鐢熷懡+12% 鍑忎激+10%",
        pieces = {
            { name = "闀囧叧闀挎灙", atkPct = 1, defPct = 4, hpPct = 3 },
            { name = "铏庣墷閾佺洈", atkPct = 0, defPct = 5, hpPct = 3 },
            { name = "鐜勯搧閲嶇敳", atkPct = 1, defPct = 4, hpPct = 3 },
            { name = "鍏抽殬鑵块摖", atkPct = 1, defPct = 3, hpPct = 2 },
            { name = "纾愮煶鎴橀澊", atkPct = 0, defPct = 3, hpPct = 2 },
            { name = "瀹堝叧浣?,   atkPct = 1, defPct = 2, hpPct = 2 },
            { name = "涓嶇伃鍏典功", atkPct = 1, defPct = 2, hpPct = 2 },
        },
    },
    { -- Set 2 (col 1): 鍗ч緳鍐涘笀濂?鈥?娉曟湳鍨?| 棰濆璇嶆潯: 鏀婚€?
        name = "鍗ч緳鍐涘笀濂?, theme = "娉曟湳", color = { 180, 140, 255 },
        extraKey = "atkSpeedPct", extraName = "鏀婚€?,
        setBonus3 = { atkPct = 3, defPct = 0, hpPct = 2, atkSpeedPct = 5 },
        setBonus3Desc = "鏀诲嚮+3% 鐢熷懡+2% 鏀婚€?5%",
        setBonus4 = { atkPct = 5, defPct = 1, hpPct = 4, atkSpeedPct = 10 },
        setBonus4Desc = "鏀诲嚮+5% 闃插尽+1% 鐢熷懡+4% 鏀婚€?10%",
        setBonus = { atkPct = 8, defPct = 2, hpPct = 6, atkSpeedPct = 18 },
        setBonusDesc = "鍏ㄥ憳鏀诲嚮+8% 鐢熷懡+6% 鏀婚€?18%",
        pieces = {
            { name = "缇芥墖绾跺肪",   atkPct = 4, defPct = 1, hpPct = 1 },
            { name = "鍐涘笀鍐?,     atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "閿︾汗闀胯", atkPct = 3, defPct = 1, hpPct = 2 },
            { name = "鍎掗泤鑵胯３", atkPct = 2, defPct = 1, hpPct = 1 },
            { name = "浜戞灞?,   atkPct = 2, defPct = 1, hpPct = 1 },
            { name = "鐜変僵鍧?,   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "鍗ч緳鍏典功",   atkPct = 2, defPct = 1, hpPct = 1 },
        },
    },
    { -- Set 3 (col 2): 鐚涘皢鍏堥攱濂?鈥?鐗╃悊鐖嗗彂 | 棰濆璇嶆潯: 鏆村嚮
        name = "鐚涘皢鍏堥攱濂?, theme = "鐖嗗彂", color = { 255, 160, 80 },
        extraKey = "critRate", extraName = "鏆村嚮",
        setBonus3 = { atkPct = 5, defPct = 0, hpPct = 2, critRate = 5 },
        setBonus3Desc = "鏀诲嚮+5% 鐢熷懡+2% 鏆村嚮+5%",
        setBonus4 = { atkPct = 8, defPct = 0, hpPct = 3, critRate = 10 },
        setBonus4Desc = "鏀诲嚮+8% 鐢熷懡+3% 鏆村嚮+10%",
        setBonus = { atkPct = 12, defPct = 0, hpPct = 4, critRate = 18 },
        setBonusDesc = "鍏ㄥ憳鏀诲嚮+12% 鐢熷懡+4% 鏆村嚮+18%",
        pieces = {
            { name = "鐮撮樀澶у垁", atkPct = 5, defPct = 0, hpPct = 1 },
            { name = "铏庡ご宸?,   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "瑁傜敳鎴樿", atkPct = 4, defPct = 1, hpPct = 1 },
            { name = "鐤鹃鑵跨敳", atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "韪忛樀闈?,   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "鐮村啗鐜?,   atkPct = 4, defPct = 0, hpPct = 1 },
            { name = "鐚涘皢鍏典功", atkPct = 2, defPct = 1, hpPct = 1 },
        },
    },
    { -- Set 4 (col 3): 榫欒儐鍓戝＋濂?鈥?鍓戠郴鐗瑰寲 | 棰濆璇嶆潯: 鍙嶅嚮
        name = "榫欒儐鍓戝＋濂?, theme = "鍓戦亾", color = { 100, 220, 255 },
        extraKey = "counterRate", extraName = "鍙嶅嚮",
        setBonus3 = { atkPct = 4, defPct = 1, hpPct = 2, counterRate = 4 },
        setBonus3Desc = "鏀诲嚮+4% 闃插尽+1% 鐢熷懡+2% 鍙嶅嚮+4%",
        setBonus4 = { atkPct = 7, defPct = 2, hpPct = 3, counterRate = 8 },
        setBonus4Desc = "鏀诲嚮+7% 闃插尽+2% 鐢熷懡+3% 鍙嶅嚮+8%",
        setBonus = { atkPct = 10, defPct = 3, hpPct = 5, counterRate = 15 },
        setBonusDesc = "鍏ㄥ憳鏀诲嚮+10% 闃插尽+3% 鍙嶅嚮+15%",
        pieces = {
            { name = "榫欒儐浜摱鏋?, atkPct = 4, defPct = 1, hpPct = 1 },
            { name = "閾跺啝",   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "娴佸厜鍓戣", atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "寰￠鑵跨敳", atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "鍑岃櫄闈?,   atkPct = 2, defPct = 1, hpPct = 1 },
            { name = "榫欒儐浣?,   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "榫欒儐鍏典功", atkPct = 2, defPct = 1, hpPct = 1 },
        },
    },
    { -- Set 5 (col 4): 澶滃奖鍒哄濂?鈥?鍒哄/鏆楁潃 | 棰濆璇嶆潯: 绐佺牬浼ゅ
        name = "澶滃奖鍒哄濂?, theme = "鏆楁潃", color = { 200, 100, 255 },
        extraKey = "breakDmgPct", extraName = "绐佺牬",
        setBonus3 = { atkPct = 6, defPct = 0, hpPct = 0, breakDmgPct = 6 },
        setBonus3Desc = "鏀诲嚮+6% 绐佺牬+6%",
        setBonus4 = { atkPct = 10, defPct = 0, hpPct = 0, breakDmgPct = 12 },
        setBonus4Desc = "鏀诲嚮+10% 绐佺牬+12%",
        setBonus = { atkPct = 15, defPct = 0, hpPct = 0, breakDmgPct = 20 },
        setBonusDesc = "鍏ㄥ憳鏀诲嚮+15% 绐佺牬+20%",
        pieces = {
            { name = "铦惰釜鍖?,   atkPct = 6, defPct = 0, hpPct = 1 },
            { name = "澶滃奖闈㈠叿", atkPct = 4, defPct = 1, hpPct = 1 },
            { name = "澶滆琛?,   atkPct = 4, defPct = 0, hpPct = 1 },
            { name = "杞荤敳鑵跨粦", atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "鏃犲０灞?,   atkPct = 3, defPct = 1, hpPct = 1 },
            { name = "铦跺奖閾?,   atkPct = 4, defPct = 0, hpPct = 1 },
            { name = "鍒哄鍏典功", atkPct = 2, defPct = 1, hpPct = 1 },
        },
    },
    { -- Set 6 (col 5): 闇哥帇绁炲▉濂?鈥?閲嶆敾鍑?| 棰濆璇嶆潯: 姝讳骸鐖嗙偢
        name = "闇哥帇绁炲▉濂?, theme = "绁炲▉", color = { 255, 200, 60 },
        extraKey = "deathExplosionPct", extraName = "澶╁穿",
        setBonus3 = { atkPct = 2, defPct = 2, hpPct = 3, deathExplosionPct = 15 },
        setBonus3Desc = "鏀婚槻+2% 鐢熷懡+3% 澶╁穿+15%",
        setBonus4 = { atkPct = 4, defPct = 4, hpPct = 5, deathExplosionPct = 30 },
        setBonus4Desc = "鏀婚槻+4% 鐢熷懡+5% 澶╁穿+30%",
        setBonus = { atkPct = 6, defPct = 6, hpPct = 8, deathExplosionPct = 50 },
        setBonusDesc = "鍏ㄥ憳鏀婚槻+6% 鐢熷懡+8% 澶╁穿+50%",
        pieces = {
            { name = "闇哥帇鎴?,     atkPct = 3, defPct = 2, hpPct = 2 },
            { name = "闇哥帇鐩?,     atkPct = 2, defPct = 3, hpPct = 2 },
            { name = "榫欓碁閾?,   atkPct = 3, defPct = 2, hpPct = 2 },
            { name = "閾佸鑵跨敳", atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "閲嶉敜闈?,   atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "铏庣浠?,     atkPct = 3, defPct = 1, hpPct = 2 },
            { name = "闇哥帇鍏典功", atkPct = 2, defPct = 1, hpPct = 2 },
        },
    },
    { -- Set 7 (col 6): 琛屼紞鏂板叺濂?鈥?鍧囪　/鏂版墜 | 棰濆璇嶆潯: 绉婚€?
        name = "琛屼紞鏂板叺濂?, theme = "鍧囪　", color = { 160, 220, 160 },
        extraKey = "speedPct", extraName = "绉婚€?,
        setBonus3 = { atkPct = 2, defPct = 2, hpPct = 2, speedPct = 5 },
        setBonus3Desc = "鏀婚槻+2% 鐢熷懡+2% 绉婚€?5%",
        setBonus4 = { atkPct = 3, defPct = 3, hpPct = 4, speedPct = 10 },
        setBonus4Desc = "鏀婚槻+3% 鐢熷懡+4% 绉婚€?10%",
        setBonus = { atkPct = 4, defPct = 4, hpPct = 6, speedPct = 15 },
        setBonusDesc = "鍏ㄥ憳鏀婚槻+4% 鐢熷懡+6% 绉婚€?15%",
        pieces = {
            { name = "鏂板叺鏈ㄥ墤", atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "绮楀竷鏂楃瑺", atkPct = 1, defPct = 2, hpPct = 2 },
            { name = "绮楀竷鐭", atkPct = 2, defPct = 2, hpPct = 2 },
            { name = "绮楀竷鑵胯９", atkPct = 1, defPct = 2, hpPct = 2 },
            { name = "鑽夌紪鎴橀澊", atkPct = 2, defPct = 1, hpPct = 2 },
            { name = "閾滈搩",     atkPct = 2, defPct = 1, hpPct = 2 },
            { name = "鍏ラ棬鍏典功", atkPct = 1, defPct = 1, hpPct = 2 },
        },
    },
}

-- 鐜╁瑁呭鐘舵€?(涓綋鍖栧瓨鍌? 姣忎欢鍏电敳鏄敮涓€鐗╁搧锛屾嫢鏈夎嚜宸辩殑uid/鍝佽川/寮哄寲)
playerEquipment = {
    owned = {},          -- 鎷ユ湁鐨勮澶囨暟缁? { {uid=1, setIdx=n, slotIdx=s, tier=t, quality=0~100, enhanceLv=0}, ... }
    equipped = {},       -- 宸茶澶? equipped[slotIdx] = uid (寮曠敤owned涓殑uid)
    nextUid = 1,         -- 涓嬩竴涓敮涓€ID
    unlockedSlots = 0, -- 棰濆瑙ｉ攣鐨勬牸瀛愭暟锛堟€绘牸瀛?BASE_EQUIP_SLOTS+姝ゅ€硷紝姣忔骞垮憡+5锛?
}

-- 鍒濆璧犻€佷竴濂楁父榄傚墤绔?set 7)鐨勬鍣?(鍑″搧, 鍝佽川50)
-- 鍐呰仈鍒涘缓锛岄伩鍏嶅墠鍚戝紩鐢?CreateEquipItem (瀹氫箟鍦?systems/equip.lua锛屽姞杞芥櫄浜?G.lua)
initItem = {
    uid = playerEquipment.nextUid,
    setIdx = 7,
    slotIdx = 1,
    tier = 1,
    quality = 50,
    enhanceLv = 0,
    level = 1,
}
playerEquipment.nextUid = playerEquipment.nextUid + 1
table.insert(playerEquipment.owned, initItem)
playerEquipment.equipped[1] = initItem.uid
-- 瑁呭UI鐘舵€?
equipScreenState = {
    selectedSlot = 1,   -- 褰撳墠閫変腑鐨勮澶囨Ы (1-7)
    decompConfirm = nil, -- 鍒嗚В纭寮圭獥 { setIdx, slotIdx, tier, gain }
    decompConfirmBtn = nil,  -- 纭鎸夐挳rect
    decompCancelBtn = nil,   -- 鍙栨秷鎸夐挳rect
    enhanceConfirm = nil,    -- 寮哄寲纭寮圭獥 { slotIdx, enhLv, cost }
    enhanceConfirmBtn = nil, -- 寮哄寲纭鎸夐挳rect
    enhanceCancelBtn = nil,  -- 寮哄寲鍙栨秷鎸夐挳rect
    scrollY = 0,             -- 瑁呭鍒楄〃婊氬姩鍋忕Щ
    scrollVel = 0,           -- 婊氬姩鎯€ч€熷害
    isDragging = false,      -- 鏄惁姝ｅ湪鎷栧姩
    dragStartY = nil,        -- 瑙︽懜鎷栧姩璧峰Y
    dragLastY = nil,         -- 涓婁竴甯цЕ鎽竃
    batchFilterMaxTier = 6,  -- 涓€閿垎瑙ｇ瓫閫? 鍝佽川涓婇檺 (1-6, 6=鍏ㄩ儴)
    batchFilterLeftBtn = nil,
    batchFilterRightBtn = nil,
    selectMode = false,         -- 閫変腑鍒嗚В妯″紡
    selectedUids = {},          -- 閫変腑鐨勮澶噓id闆嗗悎
    selectDecompBtn = nil,      -- 閫変腑鍒嗚В鎸夐挳rect
    selectConfirmBtn = nil,     -- 閫変腑鍒嗚В纭rect
    selectCancelBtn = nil,      -- 鍙栨秷閫変腑妯″紡rect
    selectAllBtn = nil,         -- 鍏ㄩ€夋寜閽畆ect
    selectDecompConfirm = nil,  -- 閫変腑鍒嗚В纭寮圭獥 { count, gain }
}
equipSlotRects = {}
equipPieceRects = {}
equipBackBtnRect = nil

-- ============================================================================

--- 澧冪晫璇勫垎: 姣忕骇閫掑, 楂樺鐣屽骞呮洿澶?(50绾?
RANK_POWER_TABLE = {
    -- 鏂扮敓 涓€~鍗佸眰
    0,   5,  12,  20,  30,  42,  56,  72,  90, 115,
    -- 渚嶅儳 涓€~鍗佸眰
    140, 170, 200, 235, 275, 320, 370, 425, 485, 550,
    -- 鍋忓皢 涓€~鍗佸眰
    620, 700, 785, 875, 970, 1070, 1175, 1285, 1400, 1520,
    -- 棰嗕富 涓€~鍗佸眰
    1650, 1790, 1940, 2100, 2270, 2450, 2640, 2840, 3050, 3270,
    -- 澶у皢鍐?涓€~鍗佸眰
    3500, 3740, 3990, 4250, 4520, 4800, 5090, 5390, 5700, 6020,
}

-- ============================================================================
-- 绾㈢偣绯荤粺 - 宸茶鎸囩汗 + 鏍戠姸绌块€?
-- ============================================================================
-- 鍘熺悊: 鐢ㄨ瘎鍒嗘寚绾硅窡韪?涓婃纭鏃剁殑鐘舵€?銆?
--   褰撹幏寰楁柊瑁呭/姝︽妧瀵艰嚧 bestOwned 鍗囬珮, 鎸囩汗涓嶅啀鍖归厤 >> 绾㈢偣浜捣銆?
--   鐐瑰嚮杩涘叆瀵瑰簲椤甸潰 >> 璋冪敤 Dismiss >> 鎸囩汗鏇存柊 >> 绾㈢偣鍏抽棴銆?
--   鏍戠姸绌块€? 鐖惰妭鐐圭孩鐐?= OR(鎵€鏈夊瓙鑺傜偣绾㈢偣)銆?

redDotState = {
    equipAck = {},      -- equipAck[slotIdx] = 宸茬‘璁ょ殑璇ユЫ浣嶆渶浣虫嫢鏈夎瘎鍒?
    skillAckBest = 0,   -- 宸茬‘璁ょ殑鏈€浣虫湭瑁呭姝︽妧璇勫垎
    skillAckSlots = 2,  -- 宸茬‘璁ゆ椂鐨勫凡瑁呭妲戒綅鏁?
}


-- ============================================================================
-- 鍏冲崱绯荤粺
-- ============================================================================
STAGE_PAGE_SIZE = 10
STAGES = {
    -- === 绗?椤? 榛勫肪涔嬩贡 ===
    { name = "榛勫肪钀ュ", desc = "鍒濆叆涔变笘涔嬪湴",     enemyScale = 0.25, maxTier = 1, dropSets = {7, 1},    color = {80, 255, 120},  layoutIdx = 1 },
    { name = "姹濆崡灏忓緞", desc = "涔￠噹闂寸殑浼忓嚮",     enemyScale = 0.35, maxTier = 1, dropSets = {1, 7},    color = {100, 220, 140}, layoutIdx = 1 },
    { name = "骞垮畻鍩庡", desc = "榛勫肪鍐涗富鍔涢┗鎵?,   enemyScale = 0.45, maxTier = 1, dropSets = {7, 2},    color = {120, 200, 100}, layoutIdx = 1 },
    { name = "钁ｅ崜鍓嶅摠", desc = "瑗垮噳閾侀獞鐨勫墠绾?,   enemyScale = 0.55, maxTier = 2, dropSets = {1, 2},    color = {200, 160, 80},  layoutIdx = 1 },
    { name = "铏庣墷鍏冲", desc = "涓夎嫳鎴樺悤甯冧箣鍦?,   enemyScale = 0.65, maxTier = 2, dropSets = {2, 3},    color = {220, 180, 60},  layoutIdx = 1 },
    { name = "娲涢槼搴熷", desc = "澶х伀鐒氱儳鍚庣殑娈嬪灒", enemyScale = 0.75, maxTier = 2, dropSets = {3, 7},    color = {180, 100, 60},  layoutIdx = 1 },
    { name = "闀垮畨鍙ら亾", desc = "閫氬線鏃ч兘鐨勯櫓璺?,   enemyScale = 0.85, maxTier = 2, dropSets = {1, 3},    color = {160, 140, 100}, layoutIdx = 1 },
    { name = "瀹涘煄澶滄垬", desc = "鏆楀涓殑绐佽",     enemyScale = 0.95, maxTier = 3, dropSets = {2, 4},    color = {100, 120, 200}, layoutIdx = 1 },
    { name = "瀹樻浮鍓嶇嚎", desc = "鍖楁柟闇告潈鐨勫喅鎴?,   enemyScale = 1.05, maxTier = 3, dropSets = {3, 5},    color = {140, 100, 180}, layoutIdx = 1 },
    { name = "鐧介┈娓″彛", desc = "娌崇晹鐨勬畩姝绘悘鏂?,   enemyScale = 1.15, maxTier = 3, dropSets = {4, 6},    color = {100, 180, 220}, layoutIdx = 1 },
    -- === 绗?椤? 涓夊垎澶╀笅 ===
    { name = "鏂伴噹鐑界伀", desc = "鍒樺鍏村叺涔嬪",     enemyScale = 1.25, maxTier = 3, dropSets = {5, 7},    color = {200, 120, 80},  layoutIdx = 1 },
    { name = "鍗氭湜鍧?,   desc = "瀛旀槑鍒濈敤鍏?,       enemyScale = 1.35, maxTier = 3, dropSets = {1, 6},    color = {220, 160, 60},  layoutIdx = 1 },
    { name = "褰撻槼闀垮潅", desc = "璧靛瓙榫欎竷杩涗竷鍑?,   enemyScale = 1.45, maxTier = 4, dropSets = {2, 5},    color = {255, 100, 40},  layoutIdx = 1 },
    { name = "璧ゅ婊╁ご", desc = "鐑界伀杩炲ぉ澶у喅鎴?,   enemyScale = 1.55, maxTier = 4, dropSets = {3, 6, 7}, color = {255, 80, 30},   layoutIdx = 1 },
    { name = "鍗楅儭浜夊ず", desc = "鑽嗗窞瑕佸湴鐨勬敾闃?,   enemyScale = 1.65, maxTier = 4, dropSets = {4, 1},    color = {160, 200, 100}, layoutIdx = 1 },
    { name = "鑽嗗窞鍩庢睜", desc = "鍏靛蹇呬簤涔嬪湴",     enemyScale = 1.75, maxTier = 4, dropSets = {5, 2},    color = {120, 200, 160}, layoutIdx = 1 },
    { name = "鐩婂窞鍏抽殬", desc = "鍏ヨ渶鐨勯噸閲嶅叧鍗?,   enemyScale = 1.85, maxTier = 5, dropSets = {6, 3},    color = {100, 160, 220}, layoutIdx = 1 },
    { name = "钀藉嚖鍧?,   desc = "鑻辨墠闄ㄨ惤涔嬪湴",     enemyScale = 1.95, maxTier = 5, dropSets = {7, 4},    color = {180, 80, 180},  layoutIdx = 1 },
    { name = "钁悓鍏?,   desc = "鎵煎畧铚€閬撶殑鍜藉枆",   enemyScale = 2.05, maxTier = 5, dropSets = {1, 5, 6}, color = {140, 180, 80},  layoutIdx = 1 },
    { name = "鎴愰兘涔嬫垬", desc = "鍏ヤ富鐩婂窞鐨勫喅鎴?,   enemyScale = 2.15, maxTier = 5, dropSets = {2, 6, 7}, color = {220, 200, 60},  layoutIdx = 1 },
    -- === 绗?椤? 澶╀笅褰掍竴 ===
    { name = "姹変腑浜夐攱", desc = "瀹氬啗鏂╁渚?,       enemyScale = 2.25, maxTier = 5, dropSets = {3, 5, 7}, color = {180, 220, 100}, layoutIdx = 1 },
    { name = "瀹氬啗灞?,   desc = "榛勫繝濞侀渿涓夊啗",     enemyScale = 2.35, maxTier = 5, dropSets = {4, 6, 1}, color = {200, 180, 60},  layoutIdx = 1 },
    { name = "妯婂煄姘存饭", desc = "鍏冲叕姘存饭涓冨啗",     enemyScale = 2.45, maxTier = 5, dropSets = {5, 7, 2}, color = {80, 160, 255},  layoutIdx = 1 },
    { name = "楹﹀煄缁濆", desc = "鑻遍泟鏈矾鐨勬偛澹?,   enemyScale = 2.55, maxTier = 6, dropSets = {6, 1, 3}, color = {200, 60, 60},   layoutIdx = 1 },
    { name = "澶烽櫟鐑堢劙", desc = "杩炶惀涓冪櫨閲岀伀娴?,   enemyScale = 2.65, maxTier = 6, dropSets = {7, 2, 4}, color = {255, 120, 40},  layoutIdx = 1 },
    { name = "琛椾涵澶卞畧", desc = "鎸ユ唱鏂╅┈璋?,       enemyScale = 2.75, maxTier = 6, dropSets = {1, 3, 5}, color = {160, 120, 200}, layoutIdx = 1 },
    { name = "浜斾笀鍘?,   desc = "鏄熻惤绉嬮鐨勭粷鍞?,   enemyScale = 2.85, maxTier = 6, dropSets = {2, 4, 6}, color = {140, 100, 220}, layoutIdx = 1 },
    { name = "閾佺灞?,   desc = "鍥板吔鐘规枟鐨勬鎴?,   enemyScale = 2.95, maxTier = 6, dropSets = {3, 5, 7}, color = {220, 80, 80},   layoutIdx = 1 },
    { name = "娈佃胺閺栨垬", desc = "澶у皢鍐涚殑鏈€鍚庝竴鎼?, enemyScale = 3.05, maxTier = 6, dropSets = {4, 6, 1}, color = {255, 60, 60},   layoutIdx = 1 },
    { name = "澶╂按褰掗€?, desc = "涔变笘缁堢粨鐨勬洐鍏?,   enemyScale = 3.15, maxTier = 6, dropSets = {5, 6, 7, 1, 2, 3}, color = {255, 220, 80}, layoutIdx = 1 },
}
STAGE_TOTAL_PAGES = math.ceil(#STAGES / STAGE_PAGE_SIZE)

-- ============================================================================
-- 鎴樻枟甯冨眬 (鑳屾櫙鍥?鈫?鐭冲彴鍧愭爣鍏宠仈)
-- ============================================================================
-- 鍧愭爣涓鸿儗鏅浘鍘熷鍍忕礌绌洪棿 (BG_W=714, BG_H=1280), 杩愯鏃朵箻浠?BG2D_X/Y 杞负璁捐鍧愭爣
--- 鎴樺満甯冨眬琛? 绱㈠紩0=榛樿, 1~7=璁ㄤ紣灞?(鐢ㄦ暟缁勭储寮?~8瀛樺偍)
--- layoutId 鍚箟: 0=榛樿, 1=璁ㄤ紣1, ..., 7=璁ㄤ紣7
--- 鏁扮粍绱㈠紩 = layoutId + 1
-- 鎵€鏈夋垬鍦虹粺涓€浣跨敤榛樿妲戒綅 (妯睆: 鐜╁宸︿晶, 鏁屼汉鍙充晶, 鍧愭爣涓築G鍍忕礌绌洪棿)
local _defaultPlayerSlots = {{100,400},{100,550},{100,700},{100,850},{200,400},{200,550},{200,700},{200,850}}
local _defaultEnemySlots  = {{550,400},{550,550},{550,700},{650,400},{650,550}}

BATTLE_LAYOUTS = {
    [1] = { layoutId = 0, name = "榛樿鎴樺満",  bg = "image/battle_bg_1.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [2] = { layoutId = 1, name = "璁ㄤ紣绗?灞?, bg = "image/battle_bg_2.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [3] = { layoutId = 2, name = "璁ㄤ紣绗?灞?, bg = "image/battle_bg_3.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [4] = { layoutId = 3, name = "璁ㄤ紣绗?灞?, bg = "image/battle_bg_4.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [5] = { layoutId = 4, name = "璁ㄤ紣绗?灞?, bg = "image/battle_bg_5.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [6] = { layoutId = 5, name = "璁ㄤ紣绗?灞?, bg = "image/battle_bg_6.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [7] = { layoutId = 6, name = "璁ㄤ紣绗?灞?, bg = "image/battle_bg_7.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
    [8] = { layoutId = 7, name = "璁ㄤ紣绗?灞?, bg = "image/battle_bg_8.png", bgHandle = nil,
        playerSlots = _defaultPlayerSlots, enemySlots = _defaultEnemySlots,
    },
}
currentLayoutIdx = 1

--- 鐭冲彴缂栬緫鍣ㄦ挙閿€鏍?(姣忔鎷栨嫿鍓嶈褰曞揩鐓?
slotUndoStack = {}  -- { {layoutIdx, slotType, slotIdx, oldX, oldY}, ... }  MAX=50

stageState = {
    currentStage = 1,       -- 褰撳墠閫変腑鍏冲崱
    maxUnlocked = 1,        -- 鏈€澶у凡瑙ｉ攣鍏冲崱
    currentPage = 1,        -- 褰撳墠椤电爜 (1-3)
    showPreview = false,    -- 鏄剧ず鍏冲崱棰勮
    showDropPopup = false,  -- 鏄剧ず鐖嗚寮圭獥
    lastDropReward = nil,   -- 涓婃鐖嗚缁撴灉
}
stageMaxTier = 1  -- 褰撳墠鍏冲崱鏈€楂樻帀钀介樁绾?
stageNodeRects = {}
stagePreviewBtnRect = nil
stagePagePrevRect = nil
stagePageNextRect = nil
stageChestRects = {}  -- 瀹濈鐐瑰嚮鍖哄煙
stageBackBtnRect = nil
stageStartBtnRect = nil
stagePreviewCloseRect = nil
stageDropCloseRect = nil

-- ============================================================================
-- 璁ㄤ紣鎴?閰嶇疆涓庣姸鎬?
-- ============================================================================
abyssState = {
    floors = {
        { name = "榛勫肪鍏?, desc = "榛勫肪浣欓儴鐩樿笧涔嬪湴",   unlockStage = 1, color = {60, 140, 220},  enemyScale = 2.3 },
        { name = "姹滄按鍏?, desc = "鍏抽殬闄╁郴鏄撳畧闅炬敾",   unlockStage = 2, color = {220, 190, 100}, enemyScale = 3.3 },
        { name = "鑽嗗窞鍩?, desc = "鍏靛蹇呬簤鐨勬垬鐣ヨ鍦?, unlockStage = 3, color = {80, 200, 120},  enemyScale = 4.4 },
        { name = "璧ゅ婊?, desc = "鐑堢伀鐒氭睙鐨勫彜鎴樺満",   unlockStage = 3, color = {120, 200, 255}, enemyScale = 5.8 },
        { name = "浜斾笀鍘?, desc = "鏄熻惤绉嬮鐨勬偛澹箣鍦?, unlockStage = 4, color = {180, 120, 255}, enemyScale = 7.5 },
        { name = "闀垮潅鍧?, desc = "涓囧啗涓涗腑濡傚叆鏃犱汉涔嬪", unlockStage = 5, color = {100, 200, 80},  enemyScale = 8.3 },
        { name = "铏庣墷鍏?, desc = "澶╀笅绗竴闆勫叧缁濆湴",   unlockStage = 6, color = {255, 160, 180}, enemyScale = 9.5 },
    },
    selectedFloor = 1,
    showPreview = false,
    scrollY = 0,
    scrollVel = 0,
    btnRect = nil,              -- 棣栭〉璁ㄤ紣鎸夐挳
    backBtnRect = nil,          -- 璁ㄤ紣椤佃繑鍥炴寜閽?
    floorRects = {},            -- 璁ㄤ紣鍏冲崱鎸夐挳鍖哄煙
    startBtnRect = nil,         -- 璁ㄤ紣鍑烘垬鎸夐挳
    previewCloseRect = nil,     -- 棰勮鍏抽棴鎸夐挳
}

-- ============================================================================
-- 鏃犲敖鐖 閰嶇疆涓庣姸鎬?
-- ============================================================================
towerState = {
    currentFloor = 1,           -- 褰撳墠鎸戞垬灞傛暟
    highestFloor = 1,           -- 鍘嗗彶鏈€楂樺眰鏁?
    showPreview = false,
    btnRect = nil,              -- 棣栭〉鐖鎸夐挳
    backBtnRect = nil,          -- 鐖椤佃繑鍥炴寜閽?
    startBtnRect = nil,         -- 鐖鍑烘垬鎸夐挳
    -- 鎺掕姒?
    rankList = {},              -- 鎺掕姒滄暟鎹?
    rankLoaded = false,
    rankLoading = false,
    showLeaderboard = false,    -- 鏄惁鏄剧ず鎺掕姒?
    leaderboardBtnRect = nil,   -- 鎺掕姒滄寜閽?
    leaderboardBackRect = nil,  -- 鎺掕姒滃叧闂寜閽?
}

-- ============================================================================
-- 鎺掍綅绔炴妧 閰嶇疆涓庣姸鎬?
-- ============================================================================
RANKED_TIERS = {
    { name = "榛勫肪", icon = "B", color = {180, 120, 60},  minScore = 0 },
    { name = "鏍″皦", icon = "S", color = {180, 190, 210}, minScore = 100 },
    { name = "鍋忓皢", icon = "G", color = {255, 200, 60},  minScore = 250 },
    { name = "閮界潱", icon = "P", color = {100, 220, 220}, minScore = 450 },
    { name = "澶у皢", icon = "D", color = {140, 180, 255}, minScore = 700 },
    { name = "澶╁懡", icon = "M", color = {255, 80, 80},   minScore = 1000 },
}

rankedState = {
    score = 0,
    wins = 0,
    losses = 0,
    streak = 0,
    highestScore = 0,
    -- UI
    btnRect = nil,
    backBtnRect = nil,
    startBtnRect = nil,
    rankBtnRect = nil,
    showPreview = false,
    matchAnim = 0,
    isMatching = false,
    matchReady = false,
    -- 瀵规墜淇℃伅
    opponentName = "",
    opponentPower = 0,
    opponentCards = {},
    -- 鎺掕姒?
    rankLoading = false,
    rankLoaded = false,
    rankList = {},
    rankScroll = { offset = 0, vel = 0, isDragging = false, lastY = nil },
    showLeaderboard = false,
}

-- 鍏电敳鍥惧綍鐘舵€?
equipCodexState = {
    scrollOffset = 0,
    selectedSet = 1,
    scrollY = 0,           -- 婊氬姩鍋忕Щ
    scrollVel = 0,          -- 婊氬姩鎯€ч€熷害
    dragStartY = nil,       -- 瑙︽懜鎷栧姩璧峰Y
    dragLastY = nil,        -- 涓婁竴甯цЕ鎽竃
    isDragging = false,     -- 鏄惁姝ｅ湪鎷栧姩
}
equipCodexBackBtnRect = nil
equipCodexSetRects = {}
-- powerRankBackBtnRect 瀛樺偍鍦?menuBtnRects.powerRankBack 涓紝閬垮厤灞€閮ㄥ彉閲忎笂闄?

-- ============================================================================
-- 娓告垙鐘舵€?
-- ============================================================================
BASE_HP_MAX = GameConfig.BASE_HP_MAX
SOLDIER_STAT_SCALE = GameConfig.SOLDIER_STAT_SCALE

gameState = {
    gold = 0,
    totalKills = 0,
    gameTime = 0,
    phase = "LOADING",      -- LOADING / PROFILE / MENU / GACHA / CODEX / EQUIP / EQUIP_CODEX / STAGE_SELECT / ABYSS_SELECT / EXPLORATION / TOWER_SELECT / RANKED_SELECT / BATTLE / WIN / LOSE / WELFARE / PROGRESS / PLAYER_DETAIL / SKILL_CODEX / SKILL_DETAIL / DUMMY_SELECT / DUMMY_RESULT / DEV_EDITOR
    battlePhase = "SHOP",   -- SHOP(甯冮樀璐崱) / FIGHT(鎴樻枟涓?
    resultTimer = 0,
    playerBaseHP = BASE_HP_MAX,
    playerBaseMax = BASE_HP_MAX,
    enemyBaseHP = BASE_HP_MAX,
    drawCount = 0,
    goldTimer = 0,          -- 鍐涜祫鑷姩澧為暱璁℃椂鍣?
    battleTime = 0,         -- 鎴樻枟鎸佺画鏃堕棿
    autoMarch = false,      -- 鑷姩琛屽啗妯″紡
    battleSpeed = 1,        -- 鎴樻枟鍊嶉€?(1/2/3)
    autoBattle = false,     -- 鍏ㄨ嚜鍔ㄦ垬鏂?(鑷姩鍒峰皢/娲惧叺/寮€鎴?
    noFullAuto = false,     -- 鍓湰妯″紡绂佹鍏ㄨ嚜鍔?(鍙厑璁歌嚜鍔ㄦ淳鍏?
    abyssFloor = nil,       -- 璁ㄤ紣妯″紡灞傛暟 (nil=鏅€氬叧鍗?
    towerFloor = nil,       -- 鐖妯″紡灞傛暟 (nil=闈炵埇濉?
    isRanked = false,       -- 鎺掍綅妯″紡鏍囪
    isDummy = false,        -- 30s鎵撴々妯″紡鏍囪
    explorationMode = false, -- 鎼滄墦鎾ゆ帰绱㈡ā寮忔爣璁?(浠庢帰绱㈠彂璧风殑鎴樻枟)
    exploreExitConfirm = nil, -- 鎺㈢储鎴樻枟寮圭獥 { type = "exit"|"death" }
}

-- 30s鎵撴々绯荤粺鐘舵€?(鍏ㄥ眬锛屼笉澧炲姞top-level local)
dummyState = {
    selected = {},          -- 宸查€夋鐏电储寮曞垪琛?(鏈€澶?涓?
    cardRects = {},         -- 姝︾伒閫夋嫨鍗＄墖鐨勭偣鍑诲尯鍩?
    startBtnRect = nil,     -- 寮€濮嬫寜閽尯鍩?
    backBtnRect = nil,      -- 杩斿洖鎸夐挳鍖哄煙
    btnRect = nil,          -- 涓昏彍鍗曞叆鍙ｆ寜閽尯鍩?
    totalDamage = 0,        -- 绱鎬讳激瀹?
    timer = 30,             -- 鍊掕鏃?
    resultBackRect = nil,   -- 缁撴灉椤佃繑鍥炴寜閽?
    scrollY = 0,            -- 閫夊皢缃戞牸婊氬姩鍋忕Щ
    scrollVel = 0,          -- 婊氬姩鎯€ч€熷害
    isDragging = false,     -- 鏄惁姝ｅ湪鎷栨嫿
    dragStartY = nil,       -- 鎷栨嫿璧峰Y
    dragLastY = nil,        -- 涓婁竴甯
    contentH = 0,           -- 缃戞牸鍐呭鎬婚珮搴?
    gridH = 0,              -- 鍙鍖哄煙楂樺害
}

-- 寮€鍙戣€呮垬鍦虹紪杈戝櫒鐘舵€?(鍏ㄥ眬)
editorState = {
    tab = 1,             -- 1=鍏冲崱缂栬緫, 2=鎴樻枟鍙傛暟, 3=蹇€熸祴璇? 4=鐭冲彴缂栬緫
    selectedStage = 1,   -- 褰撳墠缂栬緫鐨勫叧鍗?
    scrollY = 0,
    scrollVel = 0,
    isDragging = false,
    dragLastY = nil,
    contentHeight = 0,
    backBtnRect = nil,
    btnRects = {},       -- 鍚勭鎸夐挳鍖哄煙
    tabRects = {},
    -- 涓存椂缂栬緫鍙傛暟 (瑕嗙洊 GameConfig)
    overrides = {
        baseHpMax = nil,
        initialGold = nil,
        enemySpawnCd = nil,
        playerSpawnCd = nil,
        battleTimeLimit = nil,
        soldierStatScale = nil,
        deployCd = nil,
    },
    -- 缂栬緫杩囩殑鍏冲崱鏁版嵁
    stageOverrides = {},  -- [stageIdx] = { enemyScale, name, desc }
    testStage = 1,        -- 蹇€熸祴璇曠殑鍏冲崱
    -- 鐭冲彴缂栬緫 (tab 4)
    editLayoutIdx = 1,      -- 褰撳墠缂栬緫鐨勫竷灞€绱㈠紩
    slotDragging = false,   -- 鏄惁姝ｅ湪鎷栨嫿鐭冲彴
    previewRect = nil,      -- 鑳屾櫙棰勮鍖哄煙 {x,y,w,h}
    -- 澶氶€?+ 鎷栨嫿
    selectedSlots = {},     -- { ["player_1"]=true, ["enemy_3"]=true, ... }
    slotPressKey = nil,     -- 鎸変笅鐨勬Ы浣?key (鐢ㄤ簬鍖哄垎鐐瑰嚮/鎷栨嫿)
    slotWasSelected = false, -- 鎸変笅鏃惰妲戒綅鏄惁宸叉槸閫変腑鐘舵€?
    slotPressStartX = nil,  -- 鎸変笅鏃剁殑璁捐鍧愭爣 X
    slotPressStartY = nil,  -- 鎸変笅鏃剁殑璁捐鍧愭爣 Y
    dragStartBgX = nil,     -- 鎷栨嫿璧峰鐨勮儗鏅儚绱?X
    dragStartBgY = nil,     -- 鎷栨嫿璧峰鐨勮儗鏅儚绱?Y
    dragOrigPositions = nil, -- 鎷栨嫿寮€濮嬫椂鎵€鏈夐€変腑妲戒綅鐨勫師濮嬩綅缃?
}

-- 鍟嗗簵鍗＄墝 (浠庡凡鎷ユ湁姝︾伒鍒锋柊)
shopCards = {}        -- { cardIdx, quality, cost, sold }
shopFightBtnRect = nil -- 寮€鎴樻寜閽尯鍩?(璁捐鍧愭爣)
battleSpeedBtnRect = nil       -- 鍊嶉€熸寜閽尯鍩?(璁捐鍧愭爣, global閬垮厤local-limit)
autoBattleBtnRect = nil        -- 鑷姩鎴樻枟鎸夐挳鍖哄煙 (璁捐鍧愭爣, global閬垮厤local-limit)
autoBattleTimer = 0            -- 鑷姩鎴樻枟鎿嶄綔鑺傛祦璁℃椂鍣?(global閬垮厤local-limit)
shopRefreshBtnRect = nil       -- 鍒锋柊鎸夐挳鍖哄煙 (璁捐鍧愭爣, global閬垮厤local-limit)

-- 鎴樻枟鍖哄煙 (璁捐鍧愭爣, 妯睆宸﹀彸瀵规垬)
BATTLE_ZONE = {
    top = 60, bottom = 500,
    centerY = 280,
    left = 20, right = 1004,
    centerX = 512,
    -- 涓寸晫绾? 鍏佃繃姝ょ嚎鎵ｅ鏂瑰熀鍦拌 (妯悜)
    enemyLine = 960,    -- 鐜╁鍏靛悜鍙宠杩? 鍒拌揪姝ょ嚎 >> 鎵ｆ晫鏂硅
    playerLine = 64,    -- 鏁屾柟鍏靛悜宸﹁杩? 鍒拌揪姝ょ嚎 >> 鎵ｇ帺瀹惰
    -- 閮ㄧ讲鍖哄煙
    playerDeployLeft = 20,
    playerDeployRight = 300,
    enemyDeployLeft = 724,
    enemyDeployRight = 1004,
}

-- ============================================================================
-- 杞﹂亾绯荤粺 (5鏉℃按骞崇瓑鍒嗚溅閬? 妯睆鎸塝杞村垎)
-- ============================================================================
NUM_LANES = 5
LANE_WIDTH = (BATTLE_ZONE.bottom - BATTLE_ZONE.top) / NUM_LANES  -- ~88px each
INTERCEPT_RANGE = 60  -- 澹叺鎷︽埅鏁屼汉鐨勮窛绂婚槇鍊?

playerUnits = {}
enemyUnits = {}
floatTexts = {}

playerSpawnTimer = 0
enemySpawnTimer = 0
PLAYER_SPAWN_CD = GameConfig.PLAYER_SPAWN_CD
ENEMY_SPAWN_CD  = GameConfig.ENEMY_SPAWN_CD
BATTLE_TIME_LIMIT = GameConfig.BATTLE_TIME_LIMIT or 180
DEPLOY_BATCH_SIZE = GameConfig.DEPLOY_BATCH_SIZE or { [1] = 4, [2] = 5, [3] = 6, [4] = 8 }
DEPLOY_CD = GameConfig.DEPLOY_CD or 3.5
MAX_PLAYER_UNITS = 40
MAX_ENEMY_UNITS = 40



-- ============================================================================
-- 鐗规晥绯荤粺
-- ============================================================================
particles = {}
projectiles = {}  -- 杩滅▼寮归亾鐗规晥鍒楄〃

-- ============================================================================
-- 鑳屽寘绯荤粺 (鏇夸唬鏃у晢搴?
-- ============================================================================
-- inventory[i] = { cardIdx=N, constellation=0 }  (鏈儴缃茬殑鍗?
inventory = {}
invScrollOffset = 0  -- 鑳屽寘缈婚〉鍋忕Щ

shopLayout = {
    y = 0, h = 0, cardW = 0, cardH = 0,
    startX = 0, gap = 0,
    drawBtnX = 0, drawBtnY = 0, drawBtnW = 0, drawBtnH = 0,
}

-- 鎷栨嫿 (鈽?鎷栨嫿鍧愭爣缁熶竴浣跨敤灞忓箷閫昏緫鍧愭爣)
dragState = {
    active = false,
    card = nil,
    invIdx = 0,       -- 鑳屽寘绱㈠紩 (鏇夸唬 shopIdx)
    lx = 0, ly = 0,
    touchId = -1,
    fromInventory = true,
    fromShop = false,     -- 鏄惁浠庡晢搴楁嫋鎷?
    shopIdx = 0,          -- 鍟嗗簵鍗＄墝绱㈠紩
}

-- 闀挎寜鎻愮ず
longPressState = {
    active = false,
    pressing = false,
    startTime = 0,
    card = nil,
    isSlot = false,
    slotIdx = 0,
    isEnemy = false,
}
LONG_PRESS_THRESHOLD = 0.45

-- 淇℃伅寮圭獥 (鍗曞嚮瑙﹀彂, 鏇夸唬鏃х殑闀挎寜寮圭獥)
infoPopupState = {
    show = false,
    card = nil,
    slotIdx = 0,
    isSlot = false,
    isEnemy = false,
}
-- (laneButtonRects 宸插簾寮? 杞﹂亾閫夋嫨鏀逛负鎷栨嫿閮ㄧ讲)
laneButtonRects = {}
pressStartSX = 0
pressStartSY = 0

-- ============================================================================
-- 鍒濆鍖?
-- ============================================================================

