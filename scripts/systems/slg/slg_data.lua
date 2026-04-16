-- ============================================================================
-- slg/slg_data.lua - 三国武灵传：SLG静态数据
-- 城池、地形、阵营颜色、计略定义
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

-- ============================================================================
-- 城池定义 (18城, 坐标基于 1024×571 横屏设计分辨率)
-- ============================================================================
WORLD_CITIES = {
    {id=1,  name="邺城", x=560, y=55,  faction="wei", prod=60, def=3, conn={2,3,10},   region="中原", terrain="plain"},
    {id=2,  name="北平", x=790, y=38,  faction="wei", prod=40, def=2, conn={1,3},       region="河北", terrain="mountain"},
    {id=3,  name="许昌", x=530, y=115, faction="wei", prod=80, def=4, conn={1,4,5,10},  region="中原", terrain="plain"},
    {id=4,  name="洛阳", x=340, y=100, faction="wei", prod=70, def=4, conn={3,5,9},     region="中原", terrain="plain"},
    {id=5,  name="宛城", x=420, y=170, faction="qun", prod=45, def=2, conn={3,4,6,7},   region="荆北", terrain="hill"},
    {id=6,  name="汝南", x=650, y=170, faction="qun", prod=40, def=2, conn={5,7,14},    region="中原", terrain="plain"},
    {id=7,  name="襄阳", x=475, y=230, faction="qun", prod=55, def=3, conn={5,6,8,12},  region="荆北", terrain="river"},
    {id=8,  name="荆州", x=370, y=290, faction="qun", prod=65, def=3, conn={7,9,11,12}, region="荆南", terrain="river"},
    {id=9,  name="汉中", x=195, y=190, faction="shu", prod=50, def=3, conn={4,8,10,11}, region="蜀地", terrain="mountain"},
    {id=10, name="西凉", x=130, y=90,  faction="qun", prod=35, def=2, conn={1,3,4,9},   region="西北", terrain="desert"},
    {id=11, name="成都", x=160, y=280, faction="shu", prod=80, def=4, conn={8,9,17},    region="蜀地", terrain="basin"},
    {id=12, name="长沙", x=560, y=310, faction="qun", prod=45, def=2, conn={7,8,13,14}, region="荆南", terrain="hill"},
    {id=13, name="柴桑", x=700, y=260, faction="wu",  prod=50, def=3, conn={12,14,15},  region="江东", terrain="river"},
    {id=14, name="寿春", x=750, y=200, faction="qun", prod=45, def=2, conn={6,12,13,15},region="中原", terrain="plain"},
    {id=15, name="建业", x=820, y=270, faction="wu",  prod=80, def=4, conn={13,14,16},  region="江东", terrain="river"},
    {id=16, name="吴郡", x=860, y=340, faction="wu",  prod=55, def=3, conn={15,18},     region="江东", terrain="plain"},
    {id=17, name="南蛮", x=230, y=360, faction="qun", prod=30, def=1, conn={11,18},     region="南方", terrain="forest"},
    {id=18, name="江州", x=530, y=380, faction="qun", prod=40, def=2, conn={16,17,12},  region="南方", terrain="forest"},
}

-- 山脉数据 (固定地形装饰)
M.MOUNTAINS = {
    {x=220, y=180, peaks={{0,0,18},{-12,5,12},{14,3,14},{-6,-8,10}}},
    {x=120, y=290, peaks={{0,0,16},{-10,4,11},{12,6,13}}},
    {x=620, y=100, peaks={{0,0,14},{-8,3,10},{10,5,12}}},
    {x=70,  y=200, peaks={{0,0,12},{8,4,9}}},
    {x=480, y=310, peaks={{0,0,13},{-9,3,10},{7,5,9}}},
}

-- 森林数据
M.FORESTS = {
    {x=300, y=280, count=5}, {x=200, y=260, count=4},
    {x=450, y=300, count=3}, {x=700, y=270, count=4},
    {x=550, y=250, count=3}, {x=320, y=230, count=3},
}

-- 阵营颜色体系 (main/light/dark/glow)
M.FC = {
    shu    = { main={200, 55, 55},   light={255,120,100}, dark={130,25,25},  glow={255,80,60}   },
    wei    = { main={50, 90, 200},   light={100,145,255}, dark={25,50,140},  glow={70,120,255}  },
    wu     = { main={45, 160, 55},   light={90,210,100},  dark={20,100,25},  glow={60,200,70}   },
    qun    = { main={160,140, 55},   light={210,195,100}, dark={100,85,25},  glow={200,180,70}  },
    player = { main={230,180, 50},   light={255,220,100}, dark={160,120,20}, glow={255,210,60}  },
}

-- 计略定义
M.STRATAGEMS = {
    {id="fire",   name="火计",   desc="烧毁敌城粮仓 驻军-20",    cost=120, icon="🔥", successRate=0.5},
    {id="spy",    name="离间",   desc="降低敌城士气-25",          cost=150, icon="📜", successRate=0.6},
    {id="defect", name="招降",   desc="尝试策反敌将归我",         cost=300, icon="🏳", successRate=0.2},
    {id="scout",  name="刺探",   desc="查看敌城详细兵力武将",     cost=50,  icon="👁", successRate=0.9},
}

return M
