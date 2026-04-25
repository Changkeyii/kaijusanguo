-- ============================================================================
-- G_data_skills.lua - 武技系统数据定义
-- 用途: 武技序列帧配置、武技定义表、阶级属性、运行时状态初始化
-- 职责: 纯数据初始化, 不含业务逻辑
-- 依赖: G_systems.lua 中的 UNIT_CLASS(兵种定义, 需先加载)
-- [TECH_DEBT] 使用全局表模式(遗留架构), 50+文件直接引用这些全局变量
--             转换为 local M = {} + return M 需要全量修改引用方, 风险过高
-- ============================================================================
---@diagnostic disable: undefined-global

-- ============================================================================
-- 武技序列帧常量
-- ============================================================================
SKILL_SHEET_COLS = 8       -- 序列帧列数
SKILL_SHEET_ROWS = 2       -- 序列帧行数
SKILL_FRAME_COUNT = 16     -- 总帧数
SKILL_IMG_W = 2048         -- 序列帧原始宽度
SKILL_IMG_H = 869          -- 序列帧原始高度

-- 武技序列帧 FX 系统
-- 每个条目: imgHandle(运行时填), cols, rows, totalFrames, fps, file
SKILL_FX_SHEETS = {
    -- iconIdx >> FX 配置 (每张图网格布局不同,已逐图像素分析)
    -- crop: 单元格内实际内容的联合边界 (PIL alpha getbbox 分析, 已按压缩后尺寸更新)
    [1]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_1_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 腐风斩 (1536×1030, 8×2, cell=192×515)
    [2]  = { handle = -1, cols = 4, rows = 2, frames = 8, fps = 12,
             file = "image/skill_fx_yinghuoluoren.png",
             crop = { x=18, y=1, w=345, h=303 } },           -- 萤火落刃 (1500×636, 4×2, cell=375×318, 未缩放)
    [26] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_fx_thunder.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=308 } },            -- 九霄雷穿 (1536×651, 8×2, cell=192×326, ×0.75)
    [19] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_19_sheet_20260409160423.png", origW = 1537,
             crop = { x=0, y=0, w=192, h=326 } },            -- 烽火燎原 (1537×652, 8×2, cell=192×326) 重制版
    [20] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_20_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=326 } },            -- 赤壁焚域 (1536×652, 8×2, cell=192×326)
    [3]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_fx_ghostclaw.png", origW = 1536,
             crop = { x=0, y=52, w=192, h=466 } },           -- 幽爪探地 (1536×651, 8×1, cell=192×651, ×0.75)
    [4]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 12,
             file = "image/skill_4_sheet.png", origW = 2048,
             crop = { x=15, y=0, w=231, h=428 } },            -- 凝冰一线 (2048×869, 8×2, cell=256×434, 去白底+文字)
    [5]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_lightning_sheet.png",
             crop = { x=3, y=61, w=179, h=588 } },            -- 引雷丝 (1536×651, 8×1, cell=192×651, ×0.75)
    [6]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_wind_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 腐风斩 (1536×1030, 8×2, cell=192×515)
    [7]  = { handle = -1, cols = 8, rows = 1, frames = 8, fps = 12,
             file = "image/skill_7_sheet.png",
             crop = { x=20, y=67, w=157, h=468 } },           -- 玄极穿云剑诀 (1500×636, 8×1, cell=187×636, 未缩放)
    [34] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_34_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=258 } },             -- 箭雨漫天 (1536×1030, 4×4, cell=384×258)
    [13] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_13_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 万箭坠阵 (1536×1536, 4×4, cell=384×384)
    [16] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_16_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 万箭坠阵 (1536×1536, 4×4, cell=384×384)
    [21] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_21_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 万箭坠阵 (1536×1536, 4×4, cell=384×384)
    [15] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_15_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 天雷罚域 (1536×1536, 4×4, cell=384×384)
    [11] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 16,
             file = "image/skill_11_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=293 } },             -- 地刺连探 (1536×586, 8×2, cell=192×293, ×0.75)
    [31] = { handle = -1, cols = 9, rows = 4, frames = 36, fps = 18,
             file = "image/skill_31_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=170, h=163 } },             -- 九天化龙万域 (1536×652, 9×4, cell=170×163)
    [10] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_10_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 奔雷穿云 (1536×1030, 8×2, cell=192×515)
    [17] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_fx_17.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 玄蚀径 (1536×1030, 8×2, cell=192×515)
    [8]  = { handle = -1, cols = 4, rows = 2, frames = 8, fps = 12,
             file = "image/skill_fx_8.png", origW = 1500,
             crop = { x=21, y=5, w=347, h=273 } },            -- 荆棘缠地 (1500脳636, 4脳2, cell=375脳318)
    [9]  = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_9_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 寒冰贯 (1536脳1030, 8脳2, cell=192脳515)
    [12] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_12_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 飞刃连梭 (1536脳1030, 8脳2, cell=192脳515)
    [14] = { handle = -1, cols = 6, rows = 4, frames = 23, fps = 12,
             file = "image/skill_14_sheet.png", origW = 1536,
             crop = { x=0, y=4, w=254, h=249 } },             -- 寒渊冰封 (1536×1030, 6×4, cell=256×257, ×0.75)
    [23] = { handle = -1, cols = 6, rows = 4, frames = 24, fps = 12,
             file = "image/skill_23_sheet.png", origW = 1536,
             crop = { x=6, y=12, w=244, h=237 } },            -- 破军噬魂印 (1536×1030, 6×4, cell=256×257, ×0.75)
    [22] = { handle = -1, cols = 6, rows = 4, frames = 24, fps = 12,
             file = "image/skill_22_sheet.png", origW = 2048,
             crop = { x=3, y=6, w=336, h=334 } },             -- 22号武技 (2048×1374, 6×4, cell=341×343, 直接使用)
    [24] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_24_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 镇军碑压 (1536×1536, 4×4, cell=384×384)
    -- ▼ 以下为 AI 生成的武技序列帧 ▼
    -- 线性技能 (8×2, 1536×1030, cell=192×515)
    [18] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_18_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 腐风斩 (1536×1030, 8×2, cell=192×515)
    [25] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_25_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 龙吟贯索 (1536脳1030, 8脳2, cell=192脳515)
    [27] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_27_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 腐风斩 (1536×1030, 8×2, cell=192×515)
    [28] = { handle = -1, cols = 8, rows = 2, frames = 16, fps = 14,
             file = "image/skill_28_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=192, h=515 } },             -- 腐风斩 (1536×1030, 8×2, cell=192×515)
    -- 大型AOE技能 (4×4, 1536×1536, cell=384×384)
    [29] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_29_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 远古龙魂踏地 (1536×1536, 4×4, cell=384×384)
    [30] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_30_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 万箭坠阵 (1536×1536, 4×4, cell=384×384)
    [32] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_32_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 天命雷石 (1536脳1536, 4脳4, cell=384脳384)
    [33] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_33_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 万箭坠阵 (1536×1536, 4×4, cell=384×384)
    [35] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_35_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 万箭坠阵 (1536×1536, 4×4, cell=384×384)
    [36] = { handle = -1, cols = 4, rows = 4, frames = 16, fps = 12,
             file = "image/skill_36_sheet.png", origW = 1536,
             crop = { x=0, y=0, w=384, h=384 } },             -- 天命灭世诀 (1536脳1536, 4脳4, cell=384脳384)
}
-- skillFxTimer 存储在 menuAnimTimer 中复用，无需独立变量

-- 武技定义
-- 武技战斗数据 (按 SKILL_TECHNIQUES 索引, 在 SKILL_TECHNIQUES 定义后生成)
SKILL_DEFS = {}  -- [techniqueIdx] >> battle data

---@class SkillTargetingState
---@field active boolean 是否正在瞄准(拖拽中)
---@field skillIdx number 正在瞄准的技能索引
---@field sx number 屏幕原始X坐标
---@field sy number 屏幕原始Y坐标
---@field dx number 目标设计X坐标
---@field dy number 目标设计Y坐标
---@field touchId number 触摸ID

---@type SkillTargetingState
skillTargeting = {
    active = false,
    skillIdx = 0,
    sx = 0, sy = 0,
    dx = 0, dy = 0,
    touchId = -1,
}

-- 场上活跃的技能特效
activeSkillEffects = {}    -- { x, y, skillIdx, timer, frameIdx, damaged, isEnemySkill?" }
-- AI对手武技技能系统 (排位/讨伐模式)
aiSkillState = {
    enabled = false,           -- 是否启用AI技能
    availableSkills = {},      -- 可用技能列表 (SKILL_DEFS索引)
    cooldowns = {},            -- 各技能独立冷却 { [skillIdx] = remainingCD }
    castTimer = 0,             -- AI释放间隔计时器
    castInterval = 6.0,        -- AI每次释放技能的间隔(秒)
    nextCastTime = 4.0,        -- 下次释放时间(首次延迟)
}
-- 奖励弹窗确认按钮
rewardPopupConfirmRect = nil
rewardAdDoubleRect = nil  -- 看广告翻倍按钮
exploreAdDoubleJade = false  -- 探索撤离广告翻倍玉壁标记

-- 武灵详情页状态
heroDetailState = {
    cardIdx = 0,       -- 当前查看的英雄索引
}
heroDetailBackBtnRect = nil
heroDetailNavPrevRect = nil  -- 上一个武将箭头
heroDetailNavNextRect = nil  -- 下一个武将箭头
heroDetailScroll = { y = 0, vel = 0, isDragging = false, dragStartY = 0, dragLastY = 0 }
playerDetailScroll = { y = 0, vel = 0, isDragging = false, dragStartY = 0, dragLastY = 0 }

-- 玩家详情页状态
playerDetailBtnRect = nil  -- 首页点击头像进入
playerDetailBackBtnRect = nil

-- 图鉴卡牌区域 (用于点击检测)
codexCardRects = {}
codexScroll = {
    y = 0,              -- 武将录滚动偏移
    vel = 0,            -- 滚动惯性速度
    dragStartY = nil,   -- 触摸拖动起始Y
    dragLastY = nil,    -- 上一帧触摸Y
    isDragging = false, -- 是否正在拖动
}
codexTab = 0  -- 图鉴标签页: 0=全部, 1=N, 2=R, 3=SR, 4=SSR
codexTabRects = {}  -- 标签页按钮点击区域

-- ============================================================================
-- 武技系统 (展示用)
-- ============================================================================
SKILL_ICON_COLS = 6        -- 图标列数
SKILL_ICON_ROWS = 6        -- 图标行数

-- 每日副本系统 (全局)
-- bx,by = 内容左上角在250×250单元格内的偏移, bw,bh = 内容宽高
SKILL_ICON_BBOX = {}
for i = 1, 36 do
    SKILL_ICON_BBOX[i] = {bx=0, by=0, bw=250, bh=250}  -- 新图标带背景框，填满整个单元格
end

-- 武技阶级定义 (7阶: 凡→良→优→将→侯→王→帝)
SKILL_TIERS = {
    { name = "凡品", color = { 180, 175, 165 }, glowColor = { 140, 140, 140 }, count = 6 },
    { name = "良品", color = { 100, 210, 120 }, glowColor = { 60, 200, 60 },   count = 6 },
    { name = "优品", color = { 80, 160, 255 },  glowColor = { 60, 120, 255 },   count = 6 },
    { name = "将品", color = { 180, 100, 255 }, glowColor = { 170, 80, 255 }, count = 6 },
    { name = "侍品", color = { 255, 140, 0 },   glowColor = { 255, 120, 0 },  count = 6 },
    { name = "王品", color = { 255, 180, 50 },  glowColor = { 255, 150, 30 }, count = 5 },
    { name = "帝品", color = { 255, 80, 80 },   glowColor = { 255, 60, 60 },  count = 1 },
}

-- 36个武技完整数据
SKILL_TECHNIQUES = {
    -- 凡品 (1-6)
    { name = "破锋针", tier = 1, iconIdx = 1,
      desc = "引燃战火附于兵刃之上，短距离直线挥出，灼烧敌军。" },
    { name = "烈火附身", tier = 1, iconIdx = 2,
      desc = "引燃战火附于兵刃之上，短距离直线挥出，灼烧敌军。" },
    { name = "地裂探阵", tier = 1, iconIdx = 3,
      desc = "催发地脉之力从地底探出，抓击脚下小片区域的敌人。" },
    { name = "霜锋一线", tier = 1, iconIdx = 4,
      desc = "将寒气凝聚于一线，沿直线冻结短距离内的敌人。" },
    { name = "缚敌丝", tier = 1, iconIdx = 5,
      desc = "引出一缕缚敌细丝，击中前方最近的一个敌人。" },
    { name = "旋风斩", tier = 1, iconIdx = 6,
      desc = "以凌厉风刃横扫，短距离内切割前方敌人。" },

    -- 良品 (7-12)
    { name = "穿心箭", tier = 2, iconIdx = 7,
      desc = "利矢穿心而出，沿中等直线贯穿多个敌人。" },
    { name = "荆棘缠地", tier = 2, iconIdx = 8,
      desc = "召唤荆棘蔓延地面，形成小型地面域，持续伤害踩入其中的敌人。" },
    { name = "寒冰贯", tier = 2, iconIdx = 9,
      desc = "以冰棱沿直线射出，贯穿中等距离内所有敌人。" },
    { name = "奔雷穿云", tier = 2, iconIdx = 10,
      desc = "天雷化作穿透射线，忽略障碍直线贯穿敌群。" },
    { name = "地刺连探", tier = 2, iconIdx = 11,
      desc = "连续催发地刺探出地面，沿短距直线造成多段伤害。" },
    { name = "飞刃连梭", tier = 2, iconIdx = 12,
      desc = "多道飞刃梭形连发，沿中距直线切割一切。" },

    -- 优品 (13-18)
    { name = "万箭坠阵", tier = 3, iconIdx = 13,
      desc = "万千箭矢从天而降，覆盖标准圆形区域，密集打击范围内敌人。" },
    { name = "寒渊冰封", tier = 3, iconIdx = 14,
      desc = "寒渊之力冰封一方，在中等地面域中冻结并伤害敌人。" },
    { name = "天雷罚域", tier = 3, iconIdx = 15,
      desc = "五道天雷汇聚，化为雷电领域覆盖标准范围，电击域内所有敌人。" },
    { name = "灵泉回春", tier = 3, iconIdx = 16,
      desc = "灵泉之力化为回春之阵，区域内己方武灵持续回复生命。" },
    { name = "玄蚀径", tier = 3, iconIdx = 17,
      desc = "玄力侵蚀路径，在标准直线范围内吞噬一切生灵。" },
    { name = "碎岩冲击", tier = 3, iconIdx = 18,
      desc = "岩力爆发冲击前方，标准距离贯穿敌人并击飞。" },

    -- 将品 (19-24)
    { name = "烈火燎原", tier = 4, iconIdx = 19,
      desc = "烽火漫燃形成火域，大型地面域持续焚烧域内一切敌军。" },
    { name = "赤壁焚域", tier = 4, iconIdx = 20,
      desc = "赤壁烈焰蔓延大型区域，天火焚烧域内一切敌人。" },
    { name = "冰狱封阵", tier = 4, iconIdx = 21,
      desc = "极寒之力封锁大片疆域，冰封域内所有敌人。" },
    { name = "雷狱囚阵", tier = 4, iconIdx = 22,
      desc = "天雷织成囚笼，大型区域内敌人无处可逃，持续受雷击。" },
    { name = "破军噬魂印", tier = 4, iconIdx = 23,
      desc = "破军印记标记大范围敌人，增强贯穿力穿透任何防御。" },
    { name = "镇军碑压", tier = 4, iconIdx = 24,
      desc = "镇军之力镇压大地，大型区域内敌人被重力碾压。" },

    -- 侯品 (25-30) — 复用王品图标
    { name = "龙吟贯索", tier = 5, iconIdx = 25,
      desc = "龙吟之力化为贯索，超长距离直线贯穿，穿透一切阻挡。" },
    { name = "九天雷穿", tier = 5, iconIdx = 26,
      desc = "引燃战火附于兵刃之上，短距离直线挥出，灼烧敌军。" },
    { name = "极寒冰封贯空", tier = 5, iconIdx = 27,
      desc = "绝对零度凝成寒光贯穿天地，超长直线冻碎一切。" },
    { name = "武灵剑贯三界", tier = 5, iconIdx = 28,
      desc = "绝世剑意化为武灵之剑，贯穿三界的超长直线攻击。" },
    { name = "远古龙魂踏地", tier = 5, iconIdx = 29,
      desc = "远古龙魂之影踏碎大地，全区域地面被震碎压制。" },
    { name = "万灵归墟衍域", tier = 5, iconIdx = 30,
      desc = "万灵归于虚墟，衍生出覆盖全区域的毁灭领域。" },

    -- 王品 (31-35)
    { name = "九天化龙万域", tier = 6, iconIdx = 31,
      desc = "引燃战火附于兵刃之上，短距离直线挥出，灼烧敌军。" },
    { name = "天命雷石", tier = 6, iconIdx = 32,
      desc = "天命之雷贯彻天地，涤荡苍生的神雷覆盖全图。" },
    { name = "千军冻绝冰域", tier = 6, iconIdx = 33,
      desc = "千军尽冻的绝对冰域，全地图被永恒寒冰封印。" },
    { name = "箭雨漫天", tier = 6, iconIdx = 34,
      desc = "万箭归一后漫天箭雨，全地图无差别箭矢洗礼。" },
    { name = "不灭天域", tier = 6, iconIdx = 35,
      desc = "不灭之力化为天域，全地图敌人被天命之力反噬。" },

    -- 帝品 (36) — 唯一终极武技
    { name = "天命灭世诀", tier = 7, iconIdx = 36,
      desc = "天命本源化为终焉之火，焚尽天地万物的终极武技。" },
}

-- 根据阶级生成武技战斗属性 (7阶: 凡→良→优→将→侯→王→帝)
TIER_BATTLE_STATS = {
    { damage = 80,   radius = 60,  maxCooldown = 7,  renderSize = 120 }, -- 凡品 (小型)
    { damage = 140,  radius = 70,  maxCooldown = 8,  renderSize = 120 }, -- 良品 (小型)
    { damage = 180,  radius = 85,  maxCooldown = 9,  renderSize = 200 }, -- 优品 (中型)
    { damage = 220,  radius = 100, maxCooldown = 10, renderSize = 200 }, -- 将品 (中型)
    { damage = 260,  radius = 115, maxCooldown = 11, renderSize = 250 }, -- 侯品 (中大型)
    { damage = 300,  radius = 130, maxCooldown = 12, renderSize = 350 }, -- 王品 (大型)
    { damage = 320,  radius = 150, maxCooldown = 14, renderSize = 400 }, -- 帝品 (全屏)
}

-- 线型技能的 iconIdx 集合 (蚀骨针等沿行军路线飞行的技能)
LINE_SKILL_ICONS = { [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [18] = true, [25] = true, [27] = true, [28] = true }  -- iconIdx=1 >> 破锋针, 4 >> 霜锋一线, 5 >> 缚敌丝, 6 >> 旋风斩, 7 >> 穿心箭, 18 >> 碎岩冲击, 25 >> 龙吟贯索, 27 >> 极寒冰封贯空, 28 >> 武灵剑贯三界

-- 矩形技能的 iconIdx >> 矩形尺寸 (宽×高, 设计坐标)
RECT_SKILL_ICONS = {
    [34] = { w = 560, h = 272 },  -- 箭雨漫天: 大型矩形箭雨
    [17] = { w = 400, h = 400 },  -- 玄蚀径: 矩形横跨两条行军路线,持续伤害
}
-- 超大圆形AOE (覆盖全场)
BIG_AOE_ICONS = {
    [31] = { radius = 280, renderSize = 560 },  -- 九天化龙万域: 超大圆形覆盖五条行军路线
    [29] = { radius = 250, renderSize = 500 },  -- 远古龙魂踏地: 大型冲击波
    [30] = { radius = 280, renderSize = 560 },  -- 万灵归墟衍域: 英魂风暴覆盖全域
    [32] = { radius = 300, renderSize = 600 },  -- 天命雷音: 雷暴覆盖全域
    [33] = { radius = 300, renderSize = 600 },  -- 千军冻绝冰域: 冰封全域
    [35] = { radius = 320, renderSize = 640 },  -- 不灭天域: 天域结界
    [36] = { radius = 350, renderSize = 700 },  -- 天命灭世诀: 终极武技最大范围
}

-- 治疗技能的 iconIdx 集合 (底层渲染, 中间帧延长, 治疗己方)
HEAL_SKILL_ICONS = { [16] = true }  -- iconIdx=16 >> 灵泉回春

-- 区域技能 (底层渲染, 持续伤害+减速, 类似治疗但对敌方)
ZONE_SKILL_ICONS = {
    [21] = { slowFactor = 0.4, dmgPerTick = 10, tickInterval = 0.5 },  -- 冰狱封阵: 减速40%+持续伤害
    [8]  = { slowFactor = 0.5, dmgPerTick = 5,  tickInterval = 0.5 },  -- 荆棘缠地: 减速50%+轻微持续伤害
}

-- 构建全部36个武技的战斗数据 (开挂: 全部解锁)
for i, tech in ipairs(SKILL_TECHNIQUES) do
    local ts = TIER_BATTLE_STATS[tech.tier]
    local tc = SKILL_TIERS[tech.tier].color
    local isLine = LINE_SKILL_ICONS[tech.iconIdx]
    local isRect = RECT_SKILL_ICONS[tech.iconIdx]
    local isHeal = HEAL_SKILL_ICONS[tech.iconIdx]
    local isZone = ZONE_SKILL_ICONS[tech.iconIdx]
    local isBigAoe = BIG_AOE_ICONS[tech.iconIdx]
    -- AOE/rect 动画时长: 用序列帧的 frames/fps, 无序列帧回退 1.0s
    local fxData = SKILL_FX_SHEETS[tech.iconIdx]
    local baseDur = (fxData and fxData.frames and fxData.fps) and (fxData.frames / fxData.fps) or 1.0
    -- 治疗/区域技能: 中间帧延长, 总时长 = 基础时长 + 额外停留时间
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
        unlocked = false,        -- 默认未解锁, 需通过广告/奖励获取
        notAvailable = (SKILL_FX_SHEETS[tech.iconIdx] == nil),  -- 无特效的武技标记为暂未开放
        cooldown = 0,
        maxCooldown = ts.maxCooldown,
        damage = ts.damage,
        radius = isLine and 40 or ts.radius,         -- 线型技能横向命中宽度较窄
        renderSize = isLine and 40 or ts.renderSize,  -- 线型技能精灵渲染尺寸
        animDuration = aoeDur,                        -- 动画恰好播完一轮序列帧
        damageFrame = 5,
        color = { tc[1], tc[2], tc[3] },
        iconIdx = tech.iconIdx,
        skillType = skillType,
        lineWidth = isLine and 50 or nil,             -- 线型技能命中宽度
        renderBehind = not isLine,                     -- 除线性技能外，全部在单位下方渲染
    }
    -- 矩形技能覆盖
    if isRect then
        SKILL_DEFS[i].rectW = isRect.w
        SKILL_DEFS[i].rectH = isRect.h
        SKILL_DEFS[i].damage = 3500   -- 矩形大范围技能增伤
    end
    -- 夜影蚀径: 矩形+持续伤害 (横跨两条行军路线)
    if tech.iconIdx == 17 then
        SKILL_DEFS[i].dmgPerTick = 20        -- 每tick持续伤害
        SKILL_DEFS[i].tickInterval = 0.5     -- tick闂撮殧
        SKILL_DEFS[i].renderBehind = true    -- 搴曞眰娓叉煋
    end
    -- 超大圆形AOE覆盖 (31九幽化魔: 覆盖全场, 底层渲染)
    if isBigAoe then
        SKILL_DEFS[i].radius = isBigAoe.radius
        SKILL_DEFS[i].renderSize = isBigAoe.renderSize
        SKILL_DEFS[i].renderBehind = true
        SKILL_DEFS[i].damage = 3500
    end
    -- 治疗技能覆盖
    if isHeal then
        SKILL_DEFS[i].radius = 65        -- 中型技能缩小范围
        SKILL_DEFS[i].renderSize = 130
        SKILL_DEFS[i].healPerTick = 15   -- 每次治疗量
        SKILL_DEFS[i].healInterval = 0.5 -- 每0.5秒治疗一次
    end
    -- 区域技能覆盖 (冰狱封疆: 持续伤害+减速)
    if isZone then
        SKILL_DEFS[i].slowFactor = isZone.slowFactor      -- 减速比例 (0.4 = 减速40%)
        SKILL_DEFS[i].dmgPerTick = isZone.dmgPerTick      -- 每tick伤害
        SKILL_DEFS[i].tickInterval = isZone.tickInterval   -- tick闂撮殧
    end
    -- 九幽雷穿: 狱阶扩大1.25倍
    if tech.iconIdx == 26 then
        SKILL_DEFS[i].radius = math.floor(ts.radius * 1.25)
        SKILL_DEFS[i].renderSize = math.floor(ts.renderSize * 1.25)
    end
end
