-- ============================================================================
-- G_data_heroes.lua - 英雄卡牌数据定义
-- 用途: 卡牌品质/类型枚举、108名武将属性表(含武技数据)
-- 职责: 纯数据初始化, 不含业务逻辑
-- 依赖: 无(独立数据模块)
-- [TECH_DEBT] 使用全局表模式(遗留架构), 50+文件直接引用这些全局变量
--             转换为 local M = {} + return M 需要全量修改引用方, 风险过高
-- ============================================================================
---@diagnostic disable: undefined-global

---@class HeroSkillData
---@field cd number 技能冷却(秒)
---@field kind string 技能类型: "targeted"|"aoe"|"line"|"buff"|"heal"|"debuff"
---@field mult? number 伤害倍率
---@field hits? number 多段攻击次数
---@field radius? number AOE半径
---@field healMult? number 治疗倍率(基于最大生命)
---@field shieldMult? number 护盾倍率(基于最大生命)
---@field atkBuff? number 攻击加成百分比
---@field defBuff? number 防御加成百分比
---@field atkReduce? number 攻击削减百分比(debuff)
---@field atkDebuff? number 攻击削弱百分比(debuff)
---@field defReduce? number 防御削减百分比(debuff)
---@field defDebuff? number 防御削弱百分比(debuff)
---@field duration? number 持续时间(秒)
---@field dot? number 持续伤害倍率
---@field dotDur? number 持续伤害时间(秒)
---@field desc string 技能描述

---@class HeroCardDef
---@field name string 武将名称
---@field row number 卡牌图集行(预留)
---@field col number 卡牌图集列(预留)
---@field type number 类型: CARD_TYPE.ATK|DEF|HEAL|BUFF
---@field quality number 品质: QUALITY.COMMON~LIMITED
---@field singleImg string 立绘资源名
---@field atk number 基础攻击力
---@field def number 基础防御力
---@field hp number 基础生命值
---@field breakDmg number 破防伤害(ATK型武将按品质0/1/1/2/2, 其他类型为0)
---@field spawnRate number 出兵速率倍率(默认1.0)
---@field unitClass string 兵种标识(对应UNIT_CLASS)
---@field skill string 技能名称
---@field skillData HeroSkillData 技能详细数据

-- ============================================================================
-- 品质 / 类型枚举
-- ============================================================================
QUALITY = { COMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4, LIMITED = 5 }
QUALITY_NAMES = { "人", "地", "天", "神", "限" }
QUALITY_TAGS  = { "N", "R", "SR", "SSR", "限定SSR" }
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

-- (CARD_COST 已移除, 角色通过广告抽卡获得)

CARD_TYPE = { ATK = 1, DEF = 2, HEAL = 3, BUFF = 4 }
TYPE_NAMES = { "攻", "御", "疗", "辅" }
TYPE_COLORS = {
    [1] = { 220, 70, 60 },
    [2] = { 70, 130, 230 },
    [3] = { 70, 210, 120 },
    [4] = { 230, 190, 50 },
}

---@type HeroCardDef[]
HERO_CARDS = {
    -- =====================================================================
    -- 人武灵 (COMMON / N) — 1~10
    -- =====================================================================
    -- 1. 程普 — 吴国老将，铁脊矛
    { name = "程普", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero1",
      atk = 720, def = 350, hp = 6500, unitClass = "SPEAR_LIGHT", skill = "铁脊穿刺",
      skillData = { cd = 9, kind = "line", mult = 2.0, desc = "铁脊矛直刺前方，直线穿刺造成200%伤害" } },
    -- 2. 黄盖 — 苦肉计火攻
    { name = "黄盖", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero2",
      atk = 750, def = 280, hp = 5500, unitClass = "CAVALRY_LIGHT", skill = "苦肉火攻",
      skillData = { cd = 8, kind = "aoe", mult = 2.5, radius = 70, desc = "以苦肉之计引燃烈火，对范围敌人造成250%伤害" } },
    -- 3. 韩当 — 弓骑将领
    { name = "韩当", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero3",
      atk = 680, def = 300, hp = 6000, unitClass = "ARCHER_LIGHT", skill = "连珠劲射",
      skillData = { cd = 7, kind = "targeted", mult = 1.5, hits = 4, desc = "连射4支劲箭，每箭造成150%伤害" } },
    -- 4. 廖化 — 蜀汉先锋
    { name = "廖化", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero4",
      atk = 700, def = 350, hp = 6500, unitClass = "INFANTRY_LIGHT", skill = "先锋突击",
      skillData = { cd = 7, kind = "targeted", mult = 1.8, hits = 3, desc = "先锋三连斩，每击造成180%伤害" } },
    -- 5. 周仓 — 扛刀护卫
    { name = "周仓", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero5",
      atk = 500, def = 650, hp = 8500, unitClass = "INFANTRY_HEAVY", skill = "扛刀守护",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.20, duration = 6, desc = "以青龙刀护卫全军，施加20%最大生命护盾，持续6秒" } },
    -- 6. 糜竺 — 粮草官辅助
    { name = "糜竺", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.COMMON, singleImg = "hero6",
      atk = 450, def = 380, hp = 7000, unitClass = "ARCHER_HEAVY", skill = "粮草补给",
      skillData = { cd = 10, kind = "heal", healMult = 0.15, desc = "运送粮草补给全军，恢复15%最大生命" } },
    -- 7. 曹洪 — 护卫将领
    { name = "曹洪", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero7",
      atk = 520, def = 600, hp = 8000, unitClass = "INFANTRY_HEAVY", skill = "舍身护主",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.18, duration = 6, desc = "舍身挡刀，全体友军施加18%最大生命护盾，持续6秒" } },
    -- 8. 李典 — 沉稳步将
    { name = "李典", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero8",
      atk = 680, def = 380, hp = 6800, unitClass = "INFANTRY_LIGHT", skill = "沉刀斩",
      skillData = { cd = 8, kind = "targeted", mult = 2.0, desc = "沉稳一刀斩下，对单体造成200%伤害" } },
    -- 9. 张任 — 伏弓守将
    { name = "张任", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero9",
      atk = 700, def = 320, hp = 6200, unitClass = "ARCHER_LIGHT", skill = "伏击箭雨",
      skillData = { cd = 9, kind = "aoe", mult = 1.8, radius = 75, desc = "设伏发箭，范围箭雨造成180%伤害" } },
    -- 10. 纪灵 — 三尖刀武将
    { name = "纪灵", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero10",
      atk = 730, def = 340, hp = 6600, unitClass = "SPEAR_LIGHT", skill = "三尖刺杀",
      skillData = { cd = 8, kind = "targeted", mult = 2.2, desc = "三尖两刃刀猛刺，对单体造成220%伤害" } },

    -- =====================================================================
    -- 地武灵 (RARE / R) — 11~22
    -- =====================================================================
    -- 11. 太史慈 — 东吴神射
    { name = "太史慈", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero11",
      atk = 950, def = 360, hp = 6800, unitClass = "ARCHER_HEAVY", skill = "神射穿杨",
      skillData = { cd = 8, kind = "targeted", mult = 2.8, desc = "百步穿杨的神射之技，对单体造成280%伤害" } },
    -- 12. 甘宁 — 锦帆刺客
    { name = "甘宁", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero12",
      atk = 980, def = 330, hp = 6500, unitClass = "CAVALRY_LIGHT", skill = "锦帆突袭",
      skillData = { cd = 7, kind = "targeted", mult = 2.0, hits = 3, desc = "锦帆飞刀连发，攻击3个敌人各造成200%伤害" } },
    -- 13. 徐晃 — 大斧将军
    { name = "徐晃", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero13",
      atk = 880, def = 450, hp = 7500, unitClass = "INFANTRY_HEAVY", skill = "大斧横扫",
      skillData = { cd = 9, kind = "aoe", mult = 2.2, radius = 90, desc = "巨斧横劈，对范围敌人造成220%伤害" } },
    -- 14. 张郃 — 枪法精妙
    { name = "张郃", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero14",
      atk = 900, def = 550, hp = 8000, unitClass = "SPEAR_HEAVY", skill = "如枪连刺",
      skillData = { cd = 9, kind = "line", mult = 2.5, desc = "枪法精妙，直线穿刺造成250%伤害" } },
    -- 15. 魏延 — 反骨猛将
    { name = "魏延", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero15",
      atk = 1050, def = 380, hp = 7800, unitClass = "INFANTRY_HEAVY", skill = "反骨狂斩",
      skillData = { cd = 10, kind = "aoe", mult = 2.5, radius = 85, desc = "狂性大发挥刀乱斩，对范围敌人造成250%伤害" } },
    -- 16. 关平 — 青年继承者
    { name = "关平", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero16",
      atk = 920, def = 400, hp = 7200, unitClass = "INFANTRY_HEAVY", skill = "承父刀法",
      skillData = { cd = 8, kind = "targeted", mult = 2.6, desc = "传承关公刀法，对单体造成260%伤害" } },
    -- 17. 高顺 — 陷阵之志
    { name = "高顺", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero17",
      atk = 480, def = 950, hp = 12500, unitClass = "INFANTRY_ELITE", skill = "陷阵壁垒",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.22, duration = 6, desc = "陷阵营列阵，全体友军施加22%最大生命护盾，持续6秒" } },
    -- 18. 文丑 — 骑将猛冲
    { name = "文丑", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero18",
      atk = 1000, def = 420, hp = 7600, unitClass = "CAVALRY_HEAVY", skill = "猛骑冲阵",
      skillData = { cd = 10, kind = "line", mult = 2.5, desc = "策马冲锋，直线路径上造成250%伤害" } },
    -- 19. 颜良 — 勇武猛将
    { name = "颜良", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero19",
      atk = 980, def = 400, hp = 7400, unitClass = "INFANTRY_HEAVY", skill = "虎威劈斩",
      skillData = { cd = 9, kind = "targeted", mult = 2.8, desc = "虎威劈斩一击致命，对单体造成280%伤害" } },
    -- 20. 邓艾 — 偷渡奇袭
    { name = "邓艾", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero20",
      atk = 950, def = 350, hp = 6800, unitClass = "CAVALRY_LIGHT", skill = "偷渡奇袭",
      skillData = { cd = 8, kind = "targeted", mult = 3.0, desc = "偷渡阴平直取后方，对单体造成300%伤害" } },
    -- 21. 钟会 — 谋略军师
    { name = "钟会", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero21",
      atk = 800, def = 600, hp = 8500, unitClass = "ARCHER_HEAVY", skill = "连环如雷",
      skillData = { cd = 12, kind = "debuff", atkReduce = 0.25, duration = 7, desc = "施展连环计，全体敌人攻击降低25%，持续7秒" } },
    -- 22. 陆抗 — 防御名将
    { name = "陆抗", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero22",
      atk = 500, def = 1050, hp = 13000, unitClass = "INFANTRY_ELITE", skill = "西陵壁垒",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.25, duration = 6, desc = "筑建西陵防线，全体友军施加25%最大生命护盾，持续6秒" } },

    -- =====================================================================
    -- 天武灵 (EPIC / SR) — 23~30
    -- =====================================================================
    -- 23. 典韦 — 双戟猛将
    { name = "典韦", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero23",
      atk = 1350, def = 600, hp = 10200, unitClass = "INFANTRY_ELITE", skill = "双戟绝杀",
      skillData = { cd = 12, kind = "aoe", mult = 2.8, radius = 100, desc = "双铁戟旋风横扫，对范围敌人造成280%伤害" } },
    -- 24. 许褚 — 虎痴护卫
    { name = "许褚", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.EPIC, singleImg = "hero24",
      atk = 800, def = 1100, hp = 15000, unitClass = "INFANTRY_ELITE", skill = "虎痴怒吼",
      skillData = { cd = 16, kind = "buff", shieldMult = 0.30, defBuff = 0.25, duration = 8, desc = "虎痴怒吼震慑敌军，全体+30%护盾+25%防御，持续8秒" } },
    -- 25. 孙策 — 小霸王冲锋
    { name = "孙策", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero25",
      atk = 1200, def = 500, hp = 9500, unitClass = "CAVALRY_HEAVY", skill = "霸王冲锋",
      skillData = { cd = 13, kind = "line", mult = 3.0, desc = "小霸王策马冲锋，直线路径造成300%伤害" } },
    -- 26. 夏侯惇 — 拔矢猛将
    { name = "夏侯惇", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero26",
      atk = 1100, def = 700, hp = 11000, unitClass = "INFANTRY_ELITE", skill = "拔矢啖睛",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.20, duration = 8, desc = "拔矢之勇激励全军，全体友军攻击提升20%，持续8秒" } },
    -- 27. 夏侯渊 — 急袭将军
    { name = "夏侯渊", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero27",
      atk = 1200, def = 400, hp = 8500, unitClass = "CAVALRY_HEAVY", skill = "急袭千里",
      skillData = { cd = 8, kind = "targeted", mult = 3.5, desc = "千里急袭直取敌将首级，对单体造成350%伤害" } },
    -- 28. 马超 — 枪骑无双
    { name = "马超", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero28",
      atk = 1300, def = 480, hp = 9000, unitClass = "CAVALRY_ELITE", skill = "枪骑天下",
      skillData = { cd = 13, kind = "line", mult = 3.2, desc = "西凉枪骑席卷战场，直线造成320%伤害" } },
    -- 29. 黄忠 — 神箭老将
    { name = "黄忠", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero29",
      atk = 1250, def = 420, hp = 8200, unitClass = "ARCHER_ELITE", skill = "百步穿甲",
      skillData = { cd = 10, kind = "targeted", mult = 4.0, desc = "老将百步穿甲箭，对单体造成400%伤害" } },
    -- 30. 张辽 — 威震逍遥
    { name = "张辽", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero30",
      atk = 1150, def = 650, hp = 10500, unitClass = "CAVALRY_ELITE", skill = "威震逍遥津",
      skillData = { cd = 14, kind = "aoe", mult = 2.6, radius = 95, desc = "八百骑突袭十万军，对范围敌人造成260%伤害" } },

    -- =====================================================================
    -- 神武灵 (LEGENDARY / SSR) — 31~36
    -- =====================================================================
    -- 31. 赵云 — 常山龙胆
    { name = "赵云", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero31",
      atk = 1450, def = 650, hp = 11000, unitClass = "SPEAR_ELITE", skill = "七进七出",
      skillData = { cd = 14, kind = "aoe", mult = 3.5, radius = 120, desc = "常山赵子龙七进七出，对范围敌人造成350%伤害" } },
    -- 32. 张飞 — 万人莫敌
    { name = "张飞", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero32",
      atk = 1400, def = 550, hp = 9500, unitClass = "INFANTRY_ELITE", skill = "万人敌吼",
      skillData = { cd = 14, kind = "targeted", mult = 5.0, desc = "燕人张翼德一声怒吼，对单体造成500%伤害" } },
    -- 33. 关羽 — 武圣降临
    { name = "关羽", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero33",
      atk = 1500, def = 600, hp = 10500, unitClass = "INFANTRY_ELITE", skill = "青龙斩月",
      skillData = { cd = 15, kind = "aoe", mult = 3.8, radius = 110, desc = "青龙偃月刀横扫千军，对范围敌人造成380%伤害" } },
    -- 34. 周瑜 — 火烧赤壁
    { name = "周瑜", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero34",
      atk = 1300, def = 500, hp = 8800, unitClass = "ARCHER_ELITE", skill = "火烧赤壁",
      skillData = { cd = 15, kind = "debuff", defReduce = 0.35, duration = 8, desc = "赤壁烈焰焚天，全体敌人防御降低35%，持续8秒" } },
    -- 35. 吕布 — 天下无双
    { name = "吕布", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero35",
      atk = 1550, def = 580, hp = 10000, unitClass = "CAVALRY_ELITE", skill = "天下无双",
      skillData = { cd = 14, kind = "aoe", mult = 3.8, radius = 110, desc = "方天画戟横扫天下，对范围敌人造成380%伤害" } },
    -- 36. 诸葛亮 — 卧龙之智
    { name = "诸葛亮", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero36",
      atk = 1200, def = 700, hp = 9800, unitClass = "ARCHER_ELITE", skill = "八阵图",
      skillData = { cd = 16, kind = "buff", atkBuff = 0.25, defBuff = 0.20, duration = 10, desc = "布下八阵图，全军攻击+25%防御+20%，持续10秒" } },

    -- =====================================================================
    -- 限定神武灵 (LIMITED / 限定SSR) — 37~40
    -- =====================================================================
    -- 37. 关羽·武圣归天
    { name = "关羽·武圣归天", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LIMITED, singleImg = "hero37",
      atk = 1950, def = 850, hp = 14500, unitClass = "INFANTRY_ELITE", skill = "武圣天降",
      skillData = { cd = 15, kind = "aoe", mult = 5.0, radius = 140, desc = "武圣怒意贯通天地，对范围敌人造成500%伤害" } },
    -- 38. 吕布·飞将无双
    { name = "吕布·飞将无双", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LIMITED, singleImg = "hero38",
      atk = 2000, def = 780, hp = 13800, unitClass = "CAVALRY_ELITE", skill = "飞将临世",
      skillData = { cd = 14, kind = "aoe", mult = 5.5, radius = 150, desc = "飞将之威降临战场，对范围敌人造成550%伤害" } },
    -- 39. 诸葛亮·卧龙出山
    { name = "诸葛亮·卧龙出山", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LIMITED, singleImg = "hero39",
      atk = 1650, def = 950, hp = 13200, unitClass = "ARCHER_ELITE", skill = "卧龙天火",
      skillData = { cd = 15, kind = "aoe", mult = 4.2, radius = 135, dot = 0.5, dotDur = 6, desc = "卧龙祭天火覆盖全场，范围420%伤害+灼烧(50%攻击/秒)持续6秒" } },
    -- 40. 曹操·魏武挥鞭
    { name = "曹操·魏武挥鞭", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LIMITED, singleImg = "hero40",
      atk = 1750, def = 900, hp = 14200, unitClass = "ARCHER_ELITE", skill = "魏武号令",
      skillData = { cd = 14, kind = "buff", atkBuff = 0.40, defBuff = 0.20, duration = 12, desc = "魏武挥鞭号令天下，全军攻击+40%防御+20%，持续12秒" } },

    -- =====================================================================
    -- 剧本扩展武将 — 人武灵 (COMMON / N) — 41~56
    -- =====================================================================
    -- 41. 管亥 — 黄巾渠帅
    { name = "管亥", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero41",
      atk = 740, def = 320, hp = 6400, unitClass = "INFANTRY_LIGHT", skill = "黄巾怒斩",
      skillData = { cd = 8, kind = "targeted", mult = 2.0, desc = "黄巾怒斩敌将，对单体造成200%伤害" } },
    -- 42. 严白虎 — 江东豪强
    { name = "严白虎", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero42",
      atk = 700, def = 340, hp = 6600, unitClass = "INFANTRY_LIGHT", skill = "豪强压阵",
      skillData = { cd = 9, kind = "aoe", mult = 1.8, radius = 70, desc = "豪强之势压阵，范围造成180%伤害" } },
    -- 43. 朱儁 — 汉室将军
    { name = "朱儁", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero43",
      atk = 710, def = 380, hp = 6800, unitClass = "SPEAR_LIGHT", skill = "汉军突刺",
      skillData = { cd = 8, kind = "line", mult = 2.0, desc = "汉军列阵突刺，直线穿刺造成200%伤害" } },
    -- 44. 皇甫嵩 — 讨贼名将
    { name = "皇甫嵩", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero44",
      atk = 730, def = 390, hp = 7000, unitClass = "ARCHER_LIGHT", skill = "火攻连营",
      skillData = { cd = 9, kind = "aoe", mult = 2.0, radius = 75, desc = "火攻敌营，范围造成200%伤害" } },
    -- 45. 卢植 — 儒将之风
    { name = "卢植", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.COMMON, singleImg = "hero45",
      atk = 480, def = 420, hp = 7200, unitClass = "INFANTRY_HEAVY", skill = "儒将鼓舞",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.10, defBuff = 0.10, duration = 8, desc = "儒将之风鼓舞全军，攻防各+10%，持续8秒" } },
    -- 46. 丁原 — 并州刺史
    { name = "丁原", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero46",
      atk = 520, def = 580, hp = 7800, unitClass = "SPEAR_HEAVY", skill = "并州坚守",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.18, duration = 6, desc = "并州军坚守阵地，全体施加18%最大生命护盾" } },
    -- 47. 何进 — 大将军
    { name = "何进", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.COMMON, singleImg = "hero47",
      atk = 450, def = 400, hp = 7000, unitClass = "INFANTRY_LIGHT", skill = "大将号令",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.12, duration = 8, desc = "大将军号令三军，全军攻击+12%，持续8秒" } },
    -- 48. 陶谦 — 徐州牧
    { name = "陶谦", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.COMMON, singleImg = "hero48",
      atk = 420, def = 400, hp = 7200, unitClass = "ARCHER_HEAVY", skill = "仁政抚民",
      skillData = { cd = 10, kind = "heal", healMult = 0.15, desc = "仁政抚民，恢复全军15%最大生命" } },
    -- 49. 孔融 — 北海太守
    { name = "孔融", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.COMMON, singleImg = "hero49",
      atk = 400, def = 380, hp = 6800, unitClass = "ARCHER_LIGHT", skill = "学士箴言",
      skillData = { cd = 11, kind = "heal", healMult = 0.14, desc = "学士箴言慰藉全军，恢复14%最大生命" } },
    -- 50. 刘巴 — 蜀汉谋臣
    { name = "刘巴", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.COMMON, singleImg = "hero50",
      atk = 430, def = 390, hp = 6800, unitClass = "ARCHER_LIGHT", skill = "理财安国",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.08, defBuff = 0.08, duration = 8, desc = "理财安国，攻防各+8%持续8秒" } },
    -- 51. 费祎 — 蜀汉丞相
    { name = "费祎", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.COMMON, singleImg = "hero51",
      atk = 440, def = 410, hp = 7000, unitClass = "INFANTRY_LIGHT", skill = "安民抚恤",
      skillData = { cd = 10, kind = "heal", healMult = 0.16, desc = "丞相安民，恢复全军16%最大生命" } },
    -- 52. 蒋琬 — 蜀汉辅政
    { name = "蒋琬", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.COMMON, singleImg = "hero52",
      atk = 420, def = 420, hp = 7200, unitClass = "INFANTRY_LIGHT", skill = "辅政安邦",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.10, defBuff = 0.12, duration = 8, desc = "辅政安邦，全军攻击+10%防御+12%，持续8秒" } },
    -- 53. 吴懿 — 益州将领
    { name = "吴懿", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero53",
      atk = 690, def = 360, hp = 6600, unitClass = "CAVALRY_LIGHT", skill = "益州突骑",
      skillData = { cd = 8, kind = "targeted", mult = 1.9, desc = "益州铁骑突袭，对单体造成190%伤害" } },
    -- 54. 雷铜 — 蜀中勇将
    { name = "雷铜", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.COMMON, singleImg = "hero54",
      atk = 720, def = 330, hp = 6200, unitClass = "INFANTRY_LIGHT", skill = "雷刀劈斩",
      skillData = { cd = 7, kind = "targeted", mult = 2.0, desc = "雷刀劈下，对单体造成200%伤害" } },
    -- 55. 蔡瑁 — 荆州水军
    { name = "蔡瑁", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero55",
      atk = 500, def = 560, hp = 7600, unitClass = "ARCHER_HEAVY", skill = "水寨防线",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.16, duration = 6, desc = "水军布阵防守，全体施加16%最大生命护盾" } },
    -- 56. 文聘 — 荆州守将
    { name = "文聘", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.COMMON, singleImg = "hero56",
      atk = 530, def = 580, hp = 7800, unitClass = "INFANTRY_HEAVY", skill = "坚城守御",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.19, duration = 6, desc = "荆州坚城守御，全体施加19%最大生命护盾" } },

    -- =====================================================================
    -- 剧本扩展武将 — 地武灵 (RARE / R) — 57~76
    -- =====================================================================
    -- 57. 荀彧 — 王佐之才
    { name = "荀彧", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero57",
      atk = 520, def = 580, hp = 9000, unitClass = "ARCHER_HEAVY", skill = "王佐之谋",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.18, defBuff = 0.15, duration = 8, desc = "王佐之才运筹帷幄，全军攻+18%防+15%，持续8秒" } },
    -- 58. 荀攸 — 谋主奇计
    { name = "荀攸", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero58",
      atk = 550, def = 520, hp = 8200, unitClass = "ARCHER_HEAVY", skill = "十二奇策",
      skillData = { cd = 11, kind = "debuff", atkDebuff = 0.15, duration = 6, desc = "奇策妙计削弱敌军，敌军攻击-15%，持续6秒" } },
    -- 59. 程昱 — 毒士奇谋
    { name = "程昱", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero59",
      atk = 880, def = 420, hp = 7600, unitClass = "ARCHER_HEAVY", skill = "毒火连环",
      skillData = { cd = 10, kind = "aoe", mult = 2.2, radius = 80, desc = "毒火连环计，范围造成220%伤害" } },
    -- 60. 贾诩 — 毒士
    { name = "贾诩", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero60",
      atk = 600, def = 480, hp = 8000, unitClass = "ARCHER_HEAVY", skill = "离间毒计",
      skillData = { cd = 11, kind = "debuff", atkDebuff = 0.18, defDebuff = 0.10, duration = 6, desc = "毒士离间，敌军攻-18%防-10%，持续6秒" } },
    -- 61. 于禁 — 治军严整
    { name = "于禁", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero61",
      atk = 600, def = 820, hp = 10500, unitClass = "INFANTRY_HEAVY", skill = "铁壁军阵",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.22, duration = 7, desc = "治军严整列铁壁，全体施加22%最大生命护盾" } },
    -- 62. 乐进 — 先登勇士
    { name = "乐进", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero62",
      atk = 950, def = 380, hp = 7200, unitClass = "INFANTRY_LIGHT", skill = "先登陷阵",
      skillData = { cd = 8, kind = "targeted", mult = 2.6, desc = "先登城墙陷阵杀敌，对单体造成260%伤害" } },
    -- 63. 曹仁 — 铁壁将军
    { name = "曹仁", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero63",
      atk = 580, def = 880, hp = 11000, unitClass = "INFANTRY_ELITE", skill = "铁壁坚城",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.24, duration = 7, desc = "曹仁铁壁守城，全体施加24%最大生命护盾" } },
    -- 64. 满宠 — 守城名将
    { name = "满宠", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero64",
      atk = 540, def = 800, hp = 10200, unitClass = "ARCHER_HEAVY", skill = "守城箭雨",
      skillData = { cd = 10, kind = "aoe", mult = 2.0, radius = 85, desc = "守城弓弩齐射，范围造成200%伤害" } },
    -- 65. 庞统 — 凤雏
    { name = "庞统", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero65",
      atk = 580, def = 500, hp = 8500, unitClass = "ARCHER_HEAVY", skill = "连环妙计",
      skillData = { cd = 11, kind = "debuff", atkDebuff = 0.20, defDebuff = 0.12, duration = 6, desc = "连环计锁敌阵脚，敌军攻-20%防-12%，持续6秒" } },
    -- 66. 法正 — 奇谋士
    { name = "法正", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero66",
      atk = 560, def = 480, hp = 8000, unitClass = "ARCHER_HEAVY", skill = "奇谋反间",
      skillData = { cd = 11, kind = "debuff", atkDebuff = 0.16, duration = 7, desc = "奇谋反间削弱敌军，敌军攻-16%，持续7秒" } },
    -- 67. 姜维 — 天水麒麟
    { name = "姜维", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero67",
      atk = 1020, def = 480, hp = 8200, unitClass = "SPEAR_HEAVY", skill = "麒麟枪法",
      skillData = { cd = 9, kind = "line", mult = 2.6, desc = "天水麒麟枪穿阵，直线造成260%伤害" } },
    -- 68. 严颜 — 老当益壮
    { name = "严颜", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero68",
      atk = 900, def = 480, hp = 8500, unitClass = "INFANTRY_HEAVY", skill = "老将断喝",
      skillData = { cd = 9, kind = "aoe", mult = 2.2, radius = 80, desc = "老将一声断喝，范围造成220%伤害" } },
    -- 69. 马良 — 白眉智士
    { name = "马良", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.RARE, singleImg = "hero69",
      atk = 480, def = 500, hp = 8800, unitClass = "ARCHER_HEAVY", skill = "白眉献策",
      skillData = { cd = 10, kind = "heal", healMult = 0.20, desc = "白眉献策安军心，恢复全军20%最大生命" } },
    -- 70. 张苞 — 蜀汉虎将
    { name = "张苞", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero70",
      atk = 980, def = 400, hp = 7600, unitClass = "CAVALRY_HEAVY", skill = "虎威冲锋",
      skillData = { cd = 9, kind = "line", mult = 2.4, desc = "承父虎威冲锋陷阵，直线造成240%伤害" } },
    -- 71. 刘封 — 义子猛将
    { name = "刘封", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero71",
      atk = 920, def = 420, hp = 7800, unitClass = "INFANTRY_HEAVY", skill = "猛将劈斩",
      skillData = { cd = 8, kind = "targeted", mult = 2.5, desc = "义子猛将劈斩，对单体造成250%伤害" } },
    -- 72. 王平 — 无当飞军
    { name = "王平", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.RARE, singleImg = "hero72",
      atk = 620, def = 780, hp = 10000, unitClass = "SPEAR_HEAVY", skill = "无当死守",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.22, duration = 7, desc = "无当飞军死守阵地，全体施加22%最大生命护盾" } },
    -- 73. 鲁肃 — 东吴都督
    { name = "鲁肃", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.RARE, singleImg = "hero73",
      atk = 520, def = 560, hp = 9200, unitClass = "ARCHER_HEAVY", skill = "联盟之策",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.16, defBuff = 0.16, duration = 8, desc = "联盟之策鼓舞三军，攻防各+16%，持续8秒" } },
    -- 74. 吕蒙 — 白衣渡江
    { name = "吕蒙", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero74",
      atk = 960, def = 500, hp = 8500, unitClass = "INFANTRY_HEAVY", skill = "白衣奇袭",
      skillData = { cd = 9, kind = "aoe", mult = 2.4, radius = 85, desc = "白衣渡江奇袭，范围造成240%伤害" } },
    -- 75. 丁奉 — 雪夜奇袭
    { name = "丁奉", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero75",
      atk = 940, def = 380, hp = 7400, unitClass = "CAVALRY_LIGHT", skill = "雪夜突袭",
      skillData = { cd = 8, kind = "targeted", mult = 2.0, hits = 3, desc = "雪夜奇袭三连击，每击造成200%伤害" } },
    -- 76. 徐盛 — 东吴火将
    { name = "徐盛", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.RARE, singleImg = "hero76",
      atk = 920, def = 400, hp = 7600, unitClass = "ARCHER_HEAVY", skill = "火箭连射",
      skillData = { cd = 9, kind = "aoe", mult = 2.2, radius = 80, desc = "火箭齐射焚敌阵，范围造成220%伤害" } },

    -- =====================================================================
    -- 剧本扩展武将 — 天武灵 (EPIC / SR) — 77~90
    -- =====================================================================
    -- 77. 董卓 — 暴虐霸主
    { name = "董卓", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero77",
      atk = 1150, def = 600, hp = 10500, unitClass = "CAVALRY_HEAVY", skill = "暴君碾压",
      skillData = { cd = 12, kind = "aoe", mult = 3.0, radius = 100, desc = "暴君之威碾压全场，范围造成300%伤害" } },
    -- 78. 华雄 — 关前猛将
    { name = "华雄", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero78",
      atk = 1200, def = 500, hp = 9200, unitClass = "INFANTRY_ELITE", skill = "关前斩将",
      skillData = { cd = 10, kind = "targeted", mult = 3.2, desc = "关前连斩敌将，对单体造成320%伤害" } },
    -- 79. 李傕 — 西凉骑将
    { name = "李傕", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero79",
      atk = 1100, def = 480, hp = 8800, unitClass = "CAVALRY_HEAVY", skill = "西凉铁骑冲",
      skillData = { cd = 10, kind = "line", mult = 2.8, desc = "西凉铁骑直冲敌阵，直线造成280%伤害" } },
    -- 80. 郭汜 — 西凉副将
    { name = "郭汜", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero80",
      atk = 1080, def = 500, hp = 9000, unitClass = "CAVALRY_HEAVY", skill = "西凉劫掠",
      skillData = { cd = 10, kind = "aoe", mult = 2.6, radius = 85, desc = "西凉劫掠横扫，范围造成260%伤害" } },
    -- 81. 张角 — 太平道主
    { name = "张角", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.EPIC, singleImg = "hero81",
      atk = 900, def = 620, hp = 10800, unitClass = "ARCHER_ELITE", skill = "太平妖术",
      skillData = { cd = 13, kind = "buff", atkBuff = 0.22, defBuff = 0.15, duration = 10, desc = "太平妖术加持全军，攻+22%防+15%，持续10秒" } },
    -- 82. 张宝 — 地公将军
    { name = "张宝", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero82",
      atk = 1080, def = 520, hp = 9500, unitClass = "ARCHER_ELITE", skill = "妖风箭雨",
      skillData = { cd = 11, kind = "aoe", mult = 2.8, radius = 95, desc = "召唤妖风驱箭雨，范围造成280%伤害" } },
    -- 83. 张梁 — 人公将军
    { name = "张梁", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero83",
      atk = 1100, def = 500, hp = 9200, unitClass = "INFANTRY_ELITE", skill = "黄巾力劈",
      skillData = { cd = 10, kind = "targeted", mult = 3.0, desc = "黄巾力士力劈，对单体造成300%伤害" } },
    -- 84. 袁绍 — 四世三公
    { name = "袁绍", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.EPIC, singleImg = "hero84",
      atk = 850, def = 650, hp = 11000, unitClass = "ARCHER_ELITE", skill = "四世号令",
      skillData = { cd = 13, kind = "buff", atkBuff = 0.20, defBuff = 0.18, duration = 10, desc = "四世三公号令诸侯，全军攻+20%防+18%，持续10秒" } },
    -- 85. 袁术 — 仲家天子
    { name = "袁术", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.EPIC, singleImg = "hero85",
      atk = 800, def = 580, hp = 9800, unitClass = "ARCHER_HEAVY", skill = "僭越天威",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.18, duration = 8, desc = "自封天子激励全军，攻击+18%，持续8秒" } },
    -- 86. 淳于琼 — 袁绍粮将
    { name = "淳于琼", row = 0, col = 0, type = CARD_TYPE.DEF, quality = QUALITY.EPIC, singleImg = "hero86",
      atk = 680, def = 750, hp = 11500, unitClass = "INFANTRY_ELITE", skill = "乌巢守粮",
      skillData = { cd = 14, kind = "buff", shieldMult = 0.24, duration = 7, desc = "乌巢固守粮仓，全体施加24%最大生命护盾" } },
    -- 87. 公孙瓒 — 白马将军
    { name = "公孙瓒", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero87",
      atk = 1180, def = 520, hp = 9500, unitClass = "CAVALRY_ELITE", skill = "白马义从",
      skillData = { cd = 11, kind = "line", mult = 3.0, desc = "白马义从冲锋陷阵，直线造成300%伤害" } },
    -- 88. 马腾 — 西凉太守
    { name = "马腾", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero88",
      atk = 1120, def = 550, hp = 9800, unitClass = "CAVALRY_HEAVY", skill = "西凉铁骑",
      skillData = { cd = 11, kind = "aoe", mult = 2.8, radius = 90, desc = "西凉铁骑奔袭，范围造成280%伤害" } },
    -- 89. 韩遂 — 凉州叛军
    { name = "韩遂", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero89",
      atk = 1050, def = 520, hp = 9200, unitClass = "CAVALRY_HEAVY", skill = "凉州飞骑",
      skillData = { cd = 10, kind = "line", mult = 2.6, desc = "凉州飞骑突阵，直线造成260%伤害" } },
    -- 90. 刘表 — 荆州之主
    { name = "刘表", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.EPIC, singleImg = "hero90",
      atk = 750, def = 620, hp = 10500, unitClass = "ARCHER_ELITE", skill = "荆州安泰",
      skillData = { cd = 13, kind = "buff", atkBuff = 0.15, defBuff = 0.20, duration = 10, desc = "荆州安泰抚军心，攻+15%防+20%，持续10秒" } },

    -- =====================================================================
    -- 剧本扩展武将 — 天武灵 续 (EPIC / SR) — 91~100
    -- =====================================================================
    -- 91. 刘璋 — 益州牧
    { name = "刘璋", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.EPIC, singleImg = "hero91",
      atk = 700, def = 600, hp = 10000, unitClass = "ARCHER_ELITE", skill = "益州富庶",
      skillData = { cd = 12, kind = "heal", healMult = 0.22, desc = "益州富庶补给全军，恢复22%生命" } },
    -- 92. 张鲁 — 天师道主
    { name = "张鲁", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.EPIC, singleImg = "hero92",
      atk = 720, def = 580, hp = 9800, unitClass = "ARCHER_ELITE", skill = "五斗米法",
      skillData = { cd = 11, kind = "heal", healMult = 0.22, desc = "五斗米法术回春，恢复全军22%生命" } },
    -- 93. 孟获 — 南蛮王
    { name = "孟获", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero93",
      atk = 1180, def = 480, hp = 9800, unitClass = "INFANTRY_ELITE", skill = "蛮王猛击",
      skillData = { cd = 10, kind = "aoe", mult = 2.8, radius = 90, desc = "南蛮王猛击大地，范围造成280%伤害" } },
    -- 94. 凌统 — 少年将军
    { name = "凌统", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero94",
      atk = 1100, def = 480, hp = 8800, unitClass = "INFANTRY_ELITE", skill = "奋命斩",
      skillData = { cd = 9, kind = "targeted", mult = 3.0, desc = "奋命一刀斩敌将，对单体造成300%伤害" } },
    -- 95. 蒋钦 — 东吴猛将
    { name = "蒋钦", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero95",
      atk = 1060, def = 460, hp = 8600, unitClass = "ARCHER_ELITE", skill = "劲弩连射",
      skillData = { cd = 9, kind = "targeted", mult = 2.0, hits = 3, desc = "劲弩三连射，每箭造成200%伤害" } },
    -- 96. 朱然 — 赤壁火将
    { name = "朱然", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero96",
      atk = 1080, def = 500, hp = 9000, unitClass = "ARCHER_ELITE", skill = "火烧连营",
      skillData = { cd = 11, kind = "aoe", mult = 2.8, radius = 90, desc = "火烧连营三百里，范围造成280%伤害" } },
    -- 97. 潘璋 — 东吴悍将
    { name = "潘璋", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero97",
      atk = 1050, def = 450, hp = 8500, unitClass = "INFANTRY_ELITE", skill = "悍勇劈砍",
      skillData = { cd = 9, kind = "targeted", mult = 2.8, desc = "悍将劈砍猛攻，对单体造成280%伤害" } },
    -- 98. 步骘 — 东吴谋臣
    { name = "步骘", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.EPIC, singleImg = "hero98",
      atk = 600, def = 620, hp = 9800, unitClass = "ARCHER_ELITE", skill = "安邦定策",
      skillData = { cd = 12, kind = "buff", atkBuff = 0.16, defBuff = 0.18, duration = 9, desc = "安邦定策稳军心，攻+16%防+18%，持续9秒" } },
    -- 99. 庞德 — 抬棺勇将
    { name = "庞德", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero99",
      atk = 1200, def = 500, hp = 9200, unitClass = "CAVALRY_ELITE", skill = "抬棺死战",
      skillData = { cd = 11, kind = "targeted", mult = 3.2, desc = "抬棺决战誓不退，对单体造成320%伤害" } },
    -- 100. 许褚·裸衣 — 虎痴裸战
    { name = "许褚", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.EPIC, singleImg = "hero100",
      atk = 1180, def = 420, hp = 9500, unitClass = "INFANTRY_ELITE", skill = "裸衣斗马超",
      skillData = { cd = 10, kind = "aoe", mult = 2.8, radius = 90, desc = "裸衣上阵战意如虹，范围造成280%伤害" } },

    -- =====================================================================
    -- 剧本扩展武将 — 神武灵 (LEGENDARY / SSR) — 101~108
    -- =====================================================================
    -- 101. 曹操 — 治世能臣
    { name = "曹操", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero101",
      atk = 1300, def = 750, hp = 11500, unitClass = "ARCHER_ELITE", skill = "挟天子令",
      skillData = { cd = 14, kind = "buff", atkBuff = 0.30, defBuff = 0.20, duration = 10, desc = "挟天子以令诸侯，全军攻+30%防+20%，持续10秒" } },
    -- 102. 刘备 — 仁德之主
    { name = "刘备", row = 0, col = 0, type = CARD_TYPE.HEAL, quality = QUALITY.LEGENDARY, singleImg = "hero102",
      atk = 1100, def = 700, hp = 12000, unitClass = "INFANTRY_ELITE", skill = "仁德之师",
      skillData = { cd = 14, kind = "heal", healMult = 0.30, atkBuff = 0.15, duration = 8, desc = "仁德感召全军，恢复30%生命且攻+15%持续8秒" } },
    -- 103. 孙权 — 守业之主
    { name = "孙权", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero103",
      atk = 1150, def = 720, hp = 11800, unitClass = "ARCHER_ELITE", skill = "坐断东南",
      skillData = { cd = 14, kind = "buff", atkBuff = 0.25, defBuff = 0.25, duration = 10, desc = "坐断东南号令江东，攻防各+25%，持续10秒" } },
    -- 104. 孙坚 — 江东猛虎
    { name = "孙坚", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero104",
      atk = 1400, def = 620, hp = 10500, unitClass = "INFANTRY_ELITE", skill = "猛虎下山",
      skillData = { cd = 12, kind = "aoe", mult = 3.5, radius = 105, desc = "江东猛虎下山，范围造成350%伤害" } },
    -- 105. 司马懿 — 冢虎
    { name = "司马懿", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero105",
      atk = 1200, def = 780, hp = 11000, unitClass = "ARCHER_ELITE", skill = "鹰视狼顾",
      skillData = { cd = 15, kind = "debuff", atkDebuff = 0.25, defDebuff = 0.20, duration = 8, desc = "冢虎鹰视狼顾，敌军攻-25%防-20%，持续8秒" } },
    -- 106. 黄忠·定军山 — 老将封神
    { name = "黄忠", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero106",
      atk = 1450, def = 580, hp = 10200, unitClass = "ARCHER_ELITE", skill = "定军山斩",
      skillData = { cd = 13, kind = "targeted", mult = 4.0, desc = "定军山一箭封神，对单体造成400%伤害" } },
    -- 107. 甘宁·百骑 — 百骑劫营
    { name = "甘宁", row = 0, col = 0, type = CARD_TYPE.ATK, quality = QUALITY.LEGENDARY, singleImg = "hero107",
      atk = 1380, def = 550, hp = 10000, unitClass = "CAVALRY_ELITE", skill = "百骑劫营",
      skillData = { cd = 12, kind = "aoe", mult = 3.5, radius = 100, desc = "百骑劫营夜袭，范围造成350%伤害" } },
    -- 108. 徐庶 — 元直走马
    { name = "徐庶", row = 0, col = 0, type = CARD_TYPE.BUFF, quality = QUALITY.LEGENDARY, singleImg = "hero108",
      atk = 1150, def = 680, hp = 10500, unitClass = "ARCHER_ELITE", skill = "走马荐贤",
      skillData = { cd = 14, kind = "buff", atkBuff = 0.28, defBuff = 0.18, duration = 10, desc = "走马荐诸葛，全军攻+28%防+18%，持续10秒" } },
}
