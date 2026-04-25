-- ============================================================================
-- slg/slg_data.lua - 三国武灵传：SLG静态数据
-- 城池、地形、阵营颜色、计略定义
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 城池定义 (16城, 坐标基于水墨风中国地图 1024×571 设计分辨率重新校准)
-- 背景图：world_map_bg_8k_20260418151435.png
-- 地理参考：三国时期真实地理位置，按地图上的地形特征对齐
--   地图布局: 左上=西北高原 左下=四川盆地(蜀) 中上=黄河中原(魏)
--             右上=华北/山东 中下=长江流域 右下=江东(吴)
-- ============================================================================
WORLD_CITIES = {
    -- 魏 (蓝旗，北方/中原)
    {id=1,  name="邺城", x=680, y=68,  faction="wei", pop=8000, def=4, conn={2,3,5},    region="河北", terrain="plain"},
    {id=2,  name="兖州", x=740, y=138, faction="wei", pop=4500, def=2, conn={1,4,5},    region="中原", terrain="plain"},
    {id=3,  name="洛阳", x=570, y=155, faction="wei", pop=7000, def=4, conn={1,4,10},   region="中原", terrain="plain"},
    {id=4,  name="许昌", x=650, y=200, faction="wei", pop=7500, def=3, conn={2,3,5,6,14},region="中原",terrain="plain"},
    {id=5,  name="寿春", x=770, y=235, faction="qun", pop=4500, def=2, conn={1,2,4,6},  region="淮南", terrain="plain"},
    -- 吴 (绿旗，东南/江东)
    {id=6,  name="合肥", x=760, y=275, faction="qun", pop=5000, def=3, conn={4,5,7},    region="江淮", terrain="plain"},
    {id=7,  name="建业", x=810, y=320, faction="wu",  pop=8000, def=4, conn={6,8},      region="江东", terrain="river"},
    {id=8,  name="吴郡", x=870, y=345, faction="wu",  pop=5500, def=3, conn={7,9},      region="江东", terrain="plain"},
    {id=9,  name="会稽", x=890, y=420, faction="wu",  pop=4000, def=2, conn={8,16},     region="江东", terrain="plain"},
    -- 蜀 (红旗，西南/蜀地)
    {id=10, name="汉中", x=370, y=245, faction="shu", pop=5000, def=3, conn={3,11,12,14},region="蜀地",terrain="mountain"},
    {id=11, name="成都", x=290, y=340, faction="shu", pop=8000, def=4, conn={10,12,13}, region="蜀地", terrain="basin"},
    {id=12, name="白帝城",x=420, y=330, faction="shu", pop=4000, def=3, conn={10,11,15}, region="蜀地", terrain="mountain"},
    {id=13, name="益州", x=260, y=440, faction="shu", pop=3500, def=2, conn={11,16},    region="南方", terrain="forest"},
    -- 群 (中立/荆州争夺区)
    {id=14, name="襄阳", x=540, y=290, faction="qun", pop=5500, def=3, conn={4,10,15},  region="荆北", terrain="river"},
    {id=15, name="荆州", x=560, y=350, faction="qun", pop=6500, def=3, conn={12,14,16}, region="荆南", terrain="river"},
    {id=16, name="长沙", x=620, y=400, faction="qun", pop=4500, def=2, conn={9,13,15},  region="荆南", terrain="hill"},
}

-- 山脉数据 (固定地形装饰, 匹配水墨地图地形)
M.MOUNTAINS = {
    {x=320, y=200, peaks={{0,0,18},{-12,5,12},{14,3,14},{-6,-8,10}}},  -- 秦岭
    {x=250, y=310, peaks={{0,0,16},{-10,4,11},{12,6,13}}},             -- 蜀道
    {x=600, y=105, peaks={{0,0,14},{-8,3,10},{10,5,12}}},              -- 太行山
    {x=180, y=260, peaks={{0,0,12},{8,4,9}}},                          -- 巴山
    {x=500, y=320, peaks={{0,0,13},{-9,3,10},{7,5,9}}},                -- 荆山
}

-- 森林数据
M.FORESTS = {
    {x=310, y=360, count=5}, {x=250, y=380, count=4},   -- 蜀地森林
    {x=530, y=340, count=3}, {x=720, y=340, count=4},   -- 长江沿线
    {x=580, y=260, count=3}, {x=400, y=270, count=3},   -- 中原/汉中间
}

-- 阵营颜色体系 (main/light/dark/glow)
M.FC = {
    shu    = { main={200, 55, 55},   light={255,120,100}, dark={130,25,25},  glow={255,80,60}   },
    wei    = { main={50, 90, 200},   light={100,145,255}, dark={25,50,140},  glow={70,120,255}  },
    wu     = { main={45, 160, 55},   light={90,210,100},  dark={20,100,25},  glow={60,200,70}   },
    qun    = { main={160,140, 55},   light={210,195,100}, dark={100,85,25},  glow={200,180,70}  },
    han    = { main={180, 50, 50},   light={220,100,90},  dark={120,25,25},  glow={210,70,60}   },
    player = { main={230,180, 50},   light={255,220,100}, dark={160,120,20}, glow={255,210,60}  },
}

-- 计略定义
M.STRATAGEMS = {
    {id="fire",   name="火计",   desc="烧毁敌城粮仓 驻军-2000",   cost=12000, icon="🔥", successRate=0.5},
    {id="spy",    name="离间",   desc="降低敌城士气-25",          cost=15000, icon="📜", successRate=0.6},
    {id="defect", name="招降",   desc="尝试策反敌将归我",         cost=30000, icon="🏳", successRate=0.2},
    {id="scout",  name="刺探",   desc="查看敌城详细兵力武将",     cost=5000,  icon="👁", successRate=0.9},
}

return M
