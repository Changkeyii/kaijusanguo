-- ============================================================================
-- slg/slg_render.lua - 三国武灵传：SLG界面渲染 (完全重做)
-- 纯背景 + 左侧城池列表 + 右侧操作面板 + 顶部状态栏
-- ============================================================================

---@diagnostic disable: undefined-global

local Data  = require("systems.slg.slg_data")
local Logic = require("systems.slg.slg_logic")
local FC    = Data.FC

local M = {}

-- ============================================================================
-- 布局常量
-- ============================================================================
M.LAYOUT = {
    TOP_BAR_H   = 56,       -- 顶部状态栏高度(适配18pt最低字号)
    LEFT_W      = 280,      -- 左侧城池列表宽度(适配18pt)
    LEFT_PAD    = 8,        -- 左侧列表内边距
    CARD_H      = 130,      -- 城池卡片高度(适配18pt 4行)
    CARD_GAP    = 5,        -- 卡片间距
    RIGHT_W     = 300,      -- 右侧操作面板宽度
    RIGHT_PAD   = 8,        -- 右侧面板内边距
}

-- ============================================================================
-- 辅助: 获取阵营颜色
-- ============================================================================
function M.GetFC(owner)
    return FC[owner] or FC.qun
end

-- ============================================================================
-- 辅助: 获取各势力统计
-- ============================================================================
function M.GetFactionStats()
    local stats = {}
    for _, city in ipairs(WORLD_CITIES) do
        local cd = worldMapState.cityData[city.id]
        if cd and cd.owner and cd.owner ~= "neutral" then
            local key = cd.owner
            if not stats[key] then
                stats[key] = {cities=0, troops=0, heroes=0}
            end
            stats[key].cities = stats[key].cities + 1
            stats[key].troops = stats[key].troops + (cd.garrison or 0)
            stats[key].heroes = stats[key].heroes + #(cd.heroes or {})
        end
    end
    -- 确保 player 始终存在
    if not stats.player then stats.player = {cities=0, troops=0, heroes=0} end
    return stats
end

-- ============================================================================
-- 辅助: 描边文字 (白字黑描边, SLG 全局统一风格)
-- ============================================================================
function M.DrawTextOutlined(x, y, text, fontSize, alpha, align)
    alpha = alpha or 240
    align = align or (NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, fontSize)
    nvgTextAlign(vg, align)
    -- 黑色描边 (4方向偏移)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(alpha * 0.7)))
    nvgText(vg, x - 1, y, text, nil)
    nvgText(vg, x + 1, y, text, nil)
    nvgText(vg, x, y - 1, text, nil)
    nvgText(vg, x, y + 1, text, nil)
    -- 白色主体
    nvgFillColor(vg, nvgRGBA(255, 255, 255, alpha))
    nvgText(vg, x, y, text, nil)
end

-- 统一按钮色板
M.BTN_PRIMARY  = { 100, 80, 45 }   -- 主要操作 (暗金)
M.BTN_SECONDARY = { 55, 50, 48 }   -- 次要操作 (灰褐)
M.BTN_DANGER   = { 130, 40, 35 }   -- 危险操作 (暗红)
M.BTN_ACCENT   = { 50, 80, 110 }   -- 强调操作 (暗蓝)

-- ============================================================================
-- 辅助: 按钮(统一深底白字描边风)
-- ============================================================================
function M.DrawBtn(x, y, w, h, label, r, g, b, alpha)
    alpha = alpha or 200
    local disabled = (alpha <= 150)
    -- 字号自适应按钮高度: h<=28→14pt, h<=34→16pt, h<=40→18pt, else 20pt
    local fontSize = h <= 34 and 18 or h <= 44 and 20 or 22
    -- 自动缩小字号防止文字超框 (最小12pt)
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, fontSize)
    local textW = nvgTextBounds(vg, 0, 0, label, nil) or 0
    local padInner = 6
    while textW > (w - padInner) and fontSize > 12 do
        fontSize = fontSize - 1
        nvgFontSize(vg, fontSize)
        textW = nvgTextBounds(vg, 0, 0, label, nil) or 0
    end
    local radius = math.max(3, math.min(6, h * 0.12))
    -- 按压缩放反馈
    local Anim = require("ui.anim")
    local now = gameState.gameTime or 0
    local sc = Anim.GetBtnScaleFor(now, x, y, w, h)
    if sc < 0.999 then
        local cx, cy = x + w * 0.5, y + h * 0.5
        nvgSave(vg)
        nvgTranslate(vg, cx, cy); nvgScale(vg, sc, sc); nvgTranslate(vg, -cx, -cy)
    end
    -- 阴影
    nvgBeginPath(vg); nvgRoundedRect(vg, x + 1, y + 1, w, h, radius)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 40)); nvgFill(vg)
    -- 渐变填充
    local grad = nvgLinearGradient(vg, x, y, x, y + h,
        nvgRGBA(math.min(255, r + 40), math.min(255, g + 30), math.min(255, b + 20), alpha),
        nvgRGBA(r, g, b, alpha))
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, radius)
    nvgFillPaint(vg, grad); nvgFill(vg)
    nvgStrokeColor(vg, disabled and nvgRGBA(120, 100, 70, 60) or nvgRGBA(200, 170, 90, 140))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    local tx, ty = x + w / 2, y + h / 2
    if disabled then
        M.DrawTextOutlined(tx, ty, label, fontSize, 120)
    else
        M.DrawTextOutlined(tx, ty, label, fontSize, 240)
    end
    if sc < 0.999 then nvgRestore(vg) end
    return { x = x, y = y, w = w, h = h }
end

-- ============================================================================
-- 顶部状态栏
-- ============================================================================
local function DrawTopBar(W, H)
    local st = worldMapState
    local L = M.LAYOUT
    local barH = L.TOP_BAR_H

    -- 半透明深色条 (磨砂质感)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, barH)
    local barGrad = nvgLinearGradient(vg, 0, 0, 0, barH,
        nvgRGBA(35, 20, 8, 220), nvgRGBA(50, 28, 12, 230))
    nvgFillPaint(vg, barGrad); nvgFill(vg)
    -- 底部金色线条
    nvgBeginPath(vg); nvgMoveTo(vg, 0, barH - 1); nvgLineTo(vg, W, barH - 1)
    nvgStrokeColor(vg, nvgRGBA(255, 200, 80, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 玩家阵营标签 (左上角胶囊)
    local pfac = st.playerFaction
    local pfName = GetFacName(pfac)
    local pfc = M.GetFC("player")
    nvgFontSize(vg, 18)
    local pfNameW = nvgTextBounds(vg, 0, 0, pfName, nil)
    local tagW = pfNameW + 14
    nvgBeginPath(vg); nvgRoundedRect(vg, 8, 4, tagW, 22, 11)
    nvgFillColor(vg, nvgRGBA(pfc.main[1], pfc.main[2], pfc.main[3], 100)); nvgFill(vg)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    M.DrawTextOutlined(8 + tagW / 2, 15, pfName, 18, 240)

    -- 回合数 (紧跟阵营)
    local turnStr = "第" .. st.turn .. "回合"
    M.DrawTextOutlined(8 + tagW + 8, 15, turnStr, 18, 200, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- 资源行 (第二行)
    nvgFontSize(vg, 18); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local resY = barH - 16
    local resX = 10
    local resGap = 6

    local resAlign = NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE
    local goldStr = "金" .. st.gold
    M.DrawTextOutlined(resX, resY, goldStr, 18, 240, resAlign)
    resX = resX + nvgTextBounds(vg, 0, 0, goldStr, nil) + resGap

    local foodStr = "粮" .. st.food
    M.DrawTextOutlined(resX, resY, foodStr, 18, 240, resAlign)
    resX = resX + nvgTextBounds(vg, 0, 0, foodStr, nil) + resGap

    local pc = WorldMap.GetPlayerCityCount()
    local cityStr = "城" .. pc .. "/" .. #WORLD_CITIES
    M.DrawTextOutlined(resX, resY, cityStr, 18, 240, resAlign)
    resX = resX + nvgTextBounds(vg, 0, 0, cityStr, nil) + resGap

    local ap = st.actionPoints or 0
    local apMax = st.maxActionPoints or 6
    local apStr = "令" .. ap .. "/" .. apMax
    M.DrawTextOutlined(resX, resY, apStr, 18, ap > 0 and 240 or 255, resAlign)

    -- 存档/读档按钮 (右上角)
    local saveBtnW, saveBtnH = 56, 32
    local saveBtnY = 4
    local saveBtnX = W - 8 - saveBtnW
    local loadBtnX = saveBtnX - saveBtnW - 4

    st.btn_save = M.DrawBtn(saveBtnX, saveBtnY, saveBtnW, saveBtnH, "存档", 100, 80, 45)
    local hasSave = rawget(_G, "WorldMap") and WorldMap.HasSave and WorldMap.HasSave()
    if hasSave then
        st.btn_load = M.DrawBtn(loadBtnX, saveBtnY, saveBtnW, saveBtnH, "读档", 100, 80, 45)
    else
        st.btn_load = nil
    end
    -- 规则按钮 (存档左侧)
    local rulesBtnX = (hasSave and loadBtnX or saveBtnX) - saveBtnW - 4
    st.btn_rules = M.DrawBtn(rulesBtnX, saveBtnY, saveBtnW, saveBtnH, "规则", 55, 50, 48)
    -- 返回大厅按钮 (规则左侧)
    local backBtnX = rulesBtnX - saveBtnW - 4
    st.btn_back = M.DrawBtn(backBtnX, saveBtnY, saveBtnW, saveBtnH, "返回", 55, 50, 48)

    -- 势力实力条 (底部)
    local facStats = M.GetFactionStats()
    local totalCities = #WORLD_CITIES
    local powerY = barH - 4
    local powerBarW = W - 16
    local powerBarH = 3
    nvgBeginPath(vg); nvgRoundedRect(vg, 8, powerY, powerBarW, powerBarH, 1.5)
    nvgFillColor(vg, nvgRGBA(60, 30, 10, 80)); nvgFill(vg)
    local facOrder = {"player", "wei", "shu", "wu", "qun"}
    local px2 = 8
    for _, fk in ipairs(facOrder) do
        local fs = facStats[fk]
        if fs and fs.cities > 0 then
            local segW = powerBarW * (fs.cities / totalCities)
            local fc = M.GetFC(fk)
            nvgBeginPath(vg); nvgRoundedRect(vg, px2, powerY, segW, powerBarH, 1.5)
            nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 200)); nvgFill(vg)
            px2 = px2 + segW
        end
    end
end

-- ============================================================================
-- 地图常量
-- ============================================================================
local MAP_W = 1024   -- 地图坐标系宽度
local MAP_H = 571    -- 地图坐标系高度
local MAP_ZOOM_MIN = 1.0
local MAP_ZOOM_MAX = 3.0
local CITY_ICON_SIZE = 48     -- 城池图标尺寸(地图坐标) 放大便于辨识
local FLAG_SIZE = 32          -- 旗帜尺寸(地图坐标)

-- 导出地图常量供 input 模块使用
M.MAP_W = MAP_W
M.MAP_H = MAP_H
M.MAP_ZOOM_MIN = MAP_ZOOM_MIN
M.MAP_ZOOM_MAX = MAP_ZOOM_MAX

-- ============================================================================
-- 辅助: 获取城池图标
-- ============================================================================
local function GetCityImage(owner)
    if owner == "player" then return IMG.cityFriendly end
    if owner == "qun" then return IMG.cityNeutral end
    return IMG.cityEnemy
end

-- ============================================================================
-- 辅助: 获取阵营旗帜图标
-- ============================================================================
local function GetFlagImage(owner)
    local pfac = worldMapState.playerFaction or "wu"
    local fac = owner
    if owner == "player" then fac = pfac end
    if fac == "wu"  then return IMG.flagWu end
    if fac == "wei" then return IMG.flagWei end
    if fac == "shu" then return IMG.flagShu end
    return IMG.flagQun
end

-- ============================================================================
-- 辅助: 绘制 NanoVG 图标 (居中绘制)
-- ============================================================================
local function DrawIcon(img, cx, cy, size, alpha)
    alpha = alpha or 1.0
    if not IsImageReady(img) then return end
    local half = size / 2
    local pat = nvgImagePattern(vg, cx - half, cy - half, size, size, 0, img, alpha)
    nvgBeginPath(vg); nvgRect(vg, cx - half, cy - half, size, size)
    nvgFillPaint(vg, pat); nvgFill(vg)
end

-- ============================================================================
-- 城池图标+连线+旗帜 (绘制在地图坐标系中，外部负责变换)
-- ============================================================================
local function DrawCityIcons(t)
    local st = worldMapState

    -- 先画连线 (道路)
    nvgSave(vg)
    nvgStrokeWidth(vg, 2.0)
    local drawnConns = {}
    for _, city in ipairs(WORLD_CITIES) do
        for _, connId in ipairs(city.conn) do
            local key = math.min(city.id, connId) .. "_" .. math.max(city.id, connId)
            if not drawnConns[key] then
                drawnConns[key] = true
                local c2 = WORLD_CITIES[connId]
                if c2 then
                    -- 渐变道路线
                    nvgBeginPath(vg)
                    nvgMoveTo(vg, city.x, city.y)
                    nvgLineTo(vg, c2.x, c2.y)
                    nvgStrokeColor(vg, nvgRGBA(180, 160, 100, 50))
                    nvgStroke(vg)
                    -- 虚线点装饰
                    local dx = c2.x - city.x
                    local dy = c2.y - city.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    local dots = math.floor(dist / 20)
                    for d = 1, dots - 1 do
                        local frac = d / dots
                        local px = city.x + dx * frac
                        local py = city.y + dy * frac
                        nvgBeginPath(vg); nvgCircle(vg, px, py, 1.2)
                        nvgFillColor(vg, nvgRGBA(200, 180, 120, 40)); nvgFill(vg)
                    end
                end
            end
        end
    end
    nvgRestore(vg)

    -- 存储城池在地图坐标中的点击区域 (input模块需要)
    st._mapCityRects = st._mapCityRects or {}
    for k in pairs(st._mapCityRects) do st._mapCityRects[k] = nil end

    -- 再画城池图标 + 旗帜
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if not cd then goto cont_icon end
        local cx, cy = city.x, city.y
        local fc = M.GetFC(cd.owner)
        local isPlayer = (cd.owner == "player")
        local isSelected = (st.selectedCity == city.id)
        local iconSz = isPlayer and (CITY_ICON_SIZE + 4) or CITY_ICON_SIZE

        -- 选中时脉冲光环
        if isSelected then
            local pulse = 0.5 + 0.5 * math.sin(t * 4)
            -- 外圈光环
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, iconSz * 0.6 + 8)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(180 * pulse)))
            nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
            -- 内圈发光
            local glow = nvgRadialGradient(vg, cx, cy, iconSz * 0.25, iconSz * 0.65,
                nvgRGBA(255, 230, 100, math.floor(70 * pulse)), nvgRGBA(255, 200, 50, 0))
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, iconSz * 0.65)
            nvgFillPaint(vg, glow); nvgFill(vg)
        end

        -- 城池底座阴影
        nvgBeginPath(vg); nvgEllipse(vg, cx, cy + iconSz * 0.35, iconSz * 0.4, iconSz * 0.12)
        nvgFillColor(vg, nvgRGBA(20, 10, 5, 60)); nvgFill(vg)

        -- 城池图标
        local cityImg = GetCityImage(cd.owner)
        if IsImageReady(cityImg) then
            DrawIcon(cityImg, cx, cy, iconSz, isSelected and 1.0 or 0.9)
        else
            -- 图标未就绪时 fallback 圆形
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, iconSz * 0.3)
            nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 200)); nvgFill(vg)
        end

        -- 阵营旗帜 (偏右上)
        local flagImg = GetFlagImage(cd.owner)
        if IsImageReady(flagImg) then
            local flagX = cx + iconSz * 0.32
            local flagY = cy - iconSz * 0.38
            DrawIcon(flagImg, flagX, flagY, FLAG_SIZE, 0.9)
        end

        -- 城池名称 (带阴影)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local nameY = cy + iconSz * 0.45
        -- 名称背景条 (高度匹配18pt字体)
        local tw = nvgTextBounds(vg, 0, 0, city.name, nil)
        local nameBgH = 24
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - tw / 2 - 6, nameY, tw + 12, nameBgH, 4)
        nvgFillColor(vg, nvgRGBA(30, 15, 5, 170)); nvgFill(vg)
        -- 名称文字 (居中对齐)
        M.DrawTextOutlined(cx, nameY + nameBgH / 2, city.name, 18, isPlayer and 255 or 200)

        -- 驻军数显示
        if cd.garrison > 0 then
            M.DrawTextOutlined(cx, nameY + nameBgH + 2, "兵" .. FormatTroops(cd.garrison), 18, 200, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        end

        -- 存储点击区域(地图坐标)
        local hitR = iconSz * 0.5 + 4
        st._mapCityRects[city.id] = { x = cx - hitR, y = cy - hitR, w = hitR * 2, h = hitR * 2 }

        ::cont_icon::
    end
end

-- ============================================================================
-- 战斗动画: 地图坐标绘制 (行军路线/攻城/换旗/欢呼)
-- 在 DrawCityIcons 之后、nvgRestore 之前调用 (地图变换内)
-- ============================================================================
local function DrawBattleAnimMap(t)
    local st = worldMapState
    if st.phase ~= "BATTLE_ANIM" then return end
    local data = st.battleAnimData
    if not data then return end
    local phase = st.battleAnimPhase
    local at = st.battleAnimT or 0

    local fromCity = WORLD_CITIES[data.fromId]
    local toCity   = WORLD_CITIES[data.toId]
    if not fromCity or not toCity then return end

    local fx, fy = fromCity.x, fromCity.y
    local tx, ty = toCity.x,   toCity.y
    local fc_atk = FC[data.fac] or FC.qun
    local cr, cg, cb = fc_atk.main[1], fc_atk.main[2], fc_atk.main[3]

    -- ---- march: 行军路线 + 部队图标 ----
    if phase == "march" then
        local dur = 1.5
        local p = math.min(1, at / dur)
        -- 虚线路径
        nvgSave(vg)
        nvgStrokeWidth(vg, 3)
        nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 160))
        nvgLineCap(vg, NVG_ROUND)
        local segLen = 10
        local dx, dy = tx - fx, ty - fy
        local dist = math.sqrt(dx * dx + dy * dy)
        local segs = math.max(1, math.floor(dist / segLen))
        for i = 0, math.floor(segs * p) - 1 do
            local s0 = i / segs
            local s1 = math.min(p, (i + 0.5) / segs)
            nvgBeginPath(vg)
            nvgMoveTo(vg, fx + dx * s0, fy + dy * s0)
            nvgLineTo(vg, fx + dx * s1, fy + dy * s1)
            nvgStroke(vg)
        end
        nvgRestore(vg)

        -- 部队圆点 (带兵力数)
        local px = fx + dx * p
        local py = fy + dy * p
        -- 光晕
        nvgBeginPath(vg); nvgCircle(vg, px, py, 18)
        nvgFillColor(vg, nvgRGBA(cr, cg, cb, 60)); nvgFill(vg)
        -- 实心
        nvgBeginPath(vg); nvgCircle(vg, px, py, 10)
        nvgFillColor(vg, nvgRGBA(cr, cg, cb, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 240, 200, 200))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        -- 兵力文字 (地图坐标18pt, 变换后自动缩放)
        if data.troops then
            M.DrawTextOutlined(px, py - 14, FormatTroops(data.troops), 18, 230, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        end

    -- ---- siege: 攻城冲击波 ----
    elseif phase == "siege" then
        local dur = 0.6
        local p = math.min(1, at / dur)
        -- 三圈扩散冲击波
        for ring = 1, 3 do
            local rp = math.max(0, p - (ring - 1) * 0.15)
            if rp > 0 then
                local radius = 12 + 40 * rp
                local alpha = math.floor(200 * (1 - rp))
                nvgBeginPath(vg); nvgCircle(vg, tx, ty, radius)
                nvgStrokeColor(vg, nvgRGBA(255, 160, 60, alpha))
                nvgStrokeWidth(vg, 3 - rp * 2); nvgStroke(vg)
            end
        end
        -- 中心闪光
        local flashA = math.floor(180 * (1 - p))
        nvgBeginPath(vg); nvgCircle(vg, tx, ty, 8 + 6 * p)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, flashA)); nvgFill(vg)

    -- ---- capture: 城池变色 + 旗帜升起 ----
    elseif phase == "capture" then
        local dur = 0.8
        local p = math.min(1, at / dur)
        -- 脉冲光环 (阵营色)
        local pulse = 0.5 + 0.5 * math.sin(p * math.pi * 3)
        local glowR = 20 + 30 * p
        nvgBeginPath(vg); nvgCircle(vg, tx, ty, glowR)
        nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, math.floor(220 * pulse)))
        nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
        -- 内部发光
        local grad = nvgRadialGradient(vg, tx, ty, 4, glowR,
            nvgRGBA(cr, cg, cb, math.floor(120 * pulse)), nvgRGBA(cr, cg, cb, 0))
        nvgBeginPath(vg); nvgCircle(vg, tx, ty, glowR)
        nvgFillPaint(vg, grad); nvgFill(vg)
        -- 旗帜升起效果: 小三角旗从城池上方升起
        local flagY = ty - CITY_ICON_SIZE * 0.38 - (1 - p) * 20
        local flagAlpha = math.floor(255 * p)
        nvgBeginPath(vg)
        local flagX = tx + CITY_ICON_SIZE * 0.32
        nvgMoveTo(vg, flagX, flagY - 8)
        nvgLineTo(vg, flagX + 12, flagY - 4)
        nvgLineTo(vg, flagX, flagY)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(cr, cg, cb, flagAlpha)); nvgFill(vg)

    -- ---- cheer: 欢呼庆祝粒子 ----
    elseif phase == "cheer" then
        local dur = 0.8
        local p = math.min(1, at / dur)
        -- 8个粒子围绕城池旋转扩散
        local count = 8
        for i = 1, count do
            local angle = (i / count) * math.pi * 2 + p * math.pi
            local dist2 = 20 + 30 * p
            local px = tx + math.cos(angle) * dist2
            local py = ty + math.sin(angle) * dist2 - 10 * p  -- 上漂
            local pAlpha = math.floor(220 * (1 - p * 0.6))
            local pSize = 3 + 2 * (1 - p)
            nvgBeginPath(vg); nvgCircle(vg, px, py, pSize)
            -- 交替金色/阵营色
            if i % 2 == 0 then
                nvgFillColor(vg, nvgRGBA(255, 220, 80, pAlpha))
            else
                nvgFillColor(vg, nvgRGBA(cr, cg, cb, pAlpha))
            end
            nvgFill(vg)
        end
        -- 中心星爆
        local starA = math.floor(160 * (1 - p))
        local sGrad = nvgRadialGradient(vg, tx, ty, 2, 15 + 10 * p,
            nvgRGBA(255, 240, 180, starA), nvgRGBA(255, 200, 80, 0))
        nvgBeginPath(vg); nvgCircle(vg, tx, ty, 15 + 10 * p)
        nvgFillPaint(vg, sGrad); nvgFill(vg)
    end
    -- notify 阶段不在地图坐标内绘制 (由 overlay 负责)
end

-- ============================================================================
-- 战斗动画: 屏幕坐标覆盖层 (通知横幅 + 跳过提示)
-- 在 DrawHeroPopup 之后、浮动飘字之前调用
-- ============================================================================
local function DrawBattleAnimOverlay(W, H)
    local st = worldMapState
    if st.phase ~= "BATTLE_ANIM" then return end
    local data = st.battleAnimData
    if not data then return end
    local phase = st.battleAnimPhase
    local at = st.battleAnimT or 0

    -- ---- AI战斗标签 + 跳过提示 ----
    if data.isAIBattle then
        -- 左上角"AI交战"标签
        M.DrawTextOutlined(12, 50, "[AI交战] " .. (data.facName or "") .. " x3", 20, 180, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        -- 底部跳过提示
        local blink = math.floor(180 + 60 * math.sin((at or 0) * 4))
        M.DrawTextOutlined(W / 2, H - 16, "[ 点击跳过全部AI战斗 ]", 18, blink, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    end

    -- ---- notify: 战报通知横幅 ----
    if phase == "notify" then
        local dur = 2.0
        -- 淡入淡出
        local fadeIn = math.min(1, at / 0.3)
        local fadeOut = math.max(0, 1 - math.max(0, at - (dur - 0.4)) / 0.4)
        local alpha = math.floor(255 * fadeIn * fadeOut)
        local bgAlpha = math.floor(200 * fadeIn * fadeOut)

        -- 横幅背景 (居中, 宽度自适应)
        local bannerH = 60
        local bannerY = H * 0.35 - bannerH / 2
        nvgBeginPath(vg); nvgRect(vg, 0, bannerY, W, bannerH)
        nvgFillColor(vg, nvgRGBA(20, 10, 5, bgAlpha)); nvgFill(vg)
        -- 上下金边
        nvgBeginPath(vg); nvgMoveTo(vg, 0, bannerY); nvgLineTo(vg, W, bannerY)
        nvgStrokeColor(vg, nvgRGBA(220, 180, 80, math.floor(alpha * 0.7)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgBeginPath(vg); nvgMoveTo(vg, 0, bannerY + bannerH); nvgLineTo(vg, W, bannerY + bannerH)
        nvgStrokeColor(vg, nvgRGBA(220, 180, 80, math.floor(alpha * 0.7)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- 通知文本
        local msg = data.notify or ""
        M.DrawTextOutlined(W / 2, bannerY + bannerH / 2, msg, 24, alpha)
    end

    -- ---- 底部跳过提示 (所有阶段) ----
    local hintAlpha = math.floor(120 + 60 * math.sin((gameState.gameTime or 0) * 2.5))
    M.DrawTextOutlined(W / 2, H - 12, "[ 点击屏幕跳过 ]", 18, hintAlpha, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
end

-- ============================================================================
-- 左侧城池列表
-- ============================================================================
local function DrawCityList(W, H, t)
    local st = worldMapState
    local L = M.LAYOUT
    local listX = 0
    local listY = L.TOP_BAR_H
    local listW = L.LEFT_W
    local listH = H - L.TOP_BAR_H

    -- 半透明面板背景
    nvgBeginPath(vg); nvgRect(vg, listX, listY, listW, listH)
    nvgFillColor(vg, nvgRGBA(28, 16, 6, 180)); nvgFill(vg)
    -- 右侧分隔线
    nvgBeginPath(vg); nvgMoveTo(vg, listW, listY); nvgLineTo(vg, listW, H)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 列表标题 (紧凑)
    M.DrawTextOutlined(listW / 2, listY + 12, "-- 城 池 --", 18, 200)

    -- 裁切区域
    local contentY = listY + 26
    local contentH = listH - 26 - 40  -- 留底部按钮空间
    nvgSave(vg)
    nvgScissor(vg, listX, contentY, listW, contentH)

    -- 城池卡片列表 (分组: 我方 > 敌方)
    local pad = L.LEFT_PAD
    local cardW = listW - pad * 2
    local cardH = L.CARD_H
    local gap = L.CARD_GAP
    local scrollY = st.cityListScroll or 0

    -- 分组排序: 玩家城池在前
    local sortedCities = {}
    for _, city in ipairs(WORLD_CITIES) do
        local cd = st.cityData[city.id]
        if cd then
            table.insert(sortedCities, {city = city, cd = cd, isPlayer = (cd.owner == "player")})
        end
    end
    table.sort(sortedCities, function(a, b)
        if a.isPlayer ~= b.isPlayer then return a.isPlayer end
        return a.city.id < b.city.id
    end)

    local drawY = contentY - scrollY
    local drawnPlayerHeader = false
    local drawnEnemyHeader = false

    -- 清除旧的城池点击区域
    st._cityCardRects = st._cityCardRects or {}
    for k in pairs(st._cityCardRects) do st._cityCardRects[k] = nil end

    for _, entry in ipairs(sortedCities) do
        local city = entry.city
        local cd = entry.cd
        local isPlayer = entry.isPlayer

        -- 分组标题
        local groupH = 26
        if isPlayer and not drawnPlayerHeader then
            drawnPlayerHeader = true
            if drawY + groupH > contentY - groupH and drawY < contentY + contentH then
                M.DrawTextOutlined(pad + 4, drawY + groupH / 2, "> 我方城池", 18, 220, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            end
            drawY = drawY + groupH
        elseif not isPlayer and not drawnEnemyHeader then
            drawnEnemyHeader = true
            if drawY + groupH > contentY - groupH and drawY < contentY + contentH then
                M.DrawTextOutlined(pad + 4, drawY + groupH / 2, "> 其他势力", 18, 180, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            end
            drawY = drawY + groupH
        end

        -- 只绘制可见卡片
        if drawY + cardH > contentY and drawY < contentY + contentH then
            local cx = pad
            local cy = drawY
            local fc = M.GetFC(cd.owner)
            local isSelected = (st.selectedCity == city.id)

            -- 卡片背景
            if isSelected then
                local pulse = 0.7 + 0.3 * math.sin(t * 3)
                nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 5)
                nvgFillColor(vg, nvgRGBA(110, 80, 25, math.floor(170 * pulse))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(255, 210, 80, math.floor(200 * pulse)))
                nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            else
                nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 5)
                nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], isPlayer and 50 or 28))
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], isPlayer and 80 or 40))
                nvgStrokeWidth(vg, 1); nvgStroke(vg)
            end

            -- 阵营色条 (左侧竖条, 更窄)
            nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy + 3, 3, cardH - 6, 1.5)
            nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 200)); nvgFill(vg)

            -- 第一行: 城池名称 + 阵营 (cy+4)
            local ltAlign = NVG_ALIGN_LEFT + NVG_ALIGN_TOP
            M.DrawTextOutlined(cx + 10, cy + 4, city.name, 20, isSelected and 255 or 230, ltAlign)

            -- 阵营+区域 (名称右侧, 裁切防溢出)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            local facName = isPlayer and "我方" or GetFacName(cd.owner)
            nvgFontSize(vg, 20)
            local nameW = nvgTextBounds(vg, 0, 0, city.name, nil)
            local facRegStr = facName .. " " .. city.region
            nvgSave(vg)
            nvgIntersectScissor(vg, cx + 12 + nameW, cy + 4, cardW - 14 - nameW, 24)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, ltAlign)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 112))
            nvgText(vg, cx + 12 + nameW - 1, cy + 6, facRegStr, nil)
            nvgText(vg, cx + 12 + nameW + 1, cy + 6, facRegStr, nil)
            nvgText(vg, cx + 12 + nameW, cy + 5, facRegStr, nil)
            nvgText(vg, cx + 12 + nameW, cy + 7, facRegStr, nil)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 160))
            nvgText(vg, cx + 12 + nameW, cy + 6, facRegStr, nil)
            nvgRestore(vg)

            -- 第二行: 兵力/城防/产出 (cy+30)
            local infoY2 = cy + 30
            local g = cd.garrison
            local garStr = "兵" .. FormatTroops(g)
            M.DrawTextOutlined(cx + 10, infoY2, garStr, 18, 220, ltAlign)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            local garW = nvgTextBounds(vg, 0, 0, garStr, nil)
            local defStr = "防" .. cd.level
            M.DrawTextOutlined(cx + 12 + garW + 4, infoY2, defStr, 18, 200, ltAlign)
            local defW = nvgTextBounds(vg, 0, 0, defStr, nil)
            M.DrawTextOutlined(cx + 16 + garW + defW + 8, infoY2, "民" .. (city.pop or 50), 18, 200, ltAlign)

            -- 薄弱角标
            if not isPlayer and g < 40 then
                local badgeX = cx + cardW - 36
                local badgeY = cy + 2
                nvgBeginPath(vg); nvgRoundedRect(vg, badgeX, badgeY, 34, 22, 4)
                nvgFillColor(vg, nvgRGBA(180, 40, 20, 190)); nvgFill(vg)
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 220, 200, 255))
                nvgText(vg, badgeX + 17, badgeY + 11, "弱", nil)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            end

            -- 第三行: 士气/武将 (cy+56)
            local row3Y = cy + 56
            if isPlayer then
                local moraleVal = cd.morale or 50
                M.DrawTextOutlined(cx + 10, row3Y, "气" .. moraleVal, 18, 200, ltAlign)
            end
            if #cd.heroes > 0 then
                local heroX = isPlayer and (cx + 52) or (cx + 10)
                M.DrawTextOutlined(heroX, row3Y, "将:", 18, 180, ltAlign)
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
                local nameStartX = heroX + nvgTextBounds(vg, 0, 0, "将:", nil) + 4
                -- 裁切武将名防溢出
                nvgSave(vg)
                nvgIntersectScissor(vg, nameStartX, row3Y, cx + cardW - nameStartX - 4, 22)
                nvgTextAlign(vg, ltAlign)
                for hi, hIdx in ipairs(cd.heroes) do
                    local card = HERO_CARDS[hIdx]
                    if card then
                        nvgFillColor(vg, nvgRGBA(0, 0, 0, 154))
                        nvgText(vg, nameStartX - 1, row3Y, card.name, nil)
                        nvgText(vg, nameStartX + 1, row3Y, card.name, nil)
                        nvgText(vg, nameStartX, row3Y - 1, card.name, nil)
                        nvgText(vg, nameStartX, row3Y + 1, card.name, nil)
                        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
                        nvgText(vg, nameStartX, row3Y, card.name, nil)
                        nameStartX = nameStartX + nvgTextBounds(vg, 0, 0, card.name, nil) + 5
                    end
                end
                nvgRestore(vg)
            end

            -- 第四行: 武将综合战力指示条 (cy+82)
            if #cd.heroes > 0 then
                local barY4 = cy + 84
                local barMaxW = cardW - 20
                local totalPower = Logic.CalcSquadPower(cd.heroes)
                local maxPower = #cd.heroes * 80
                local ratio = math.min(1, totalPower / math.max(1, maxPower))
                -- 战力条背景
                nvgBeginPath(vg); nvgRoundedRect(vg, cx + 10, barY4, barMaxW, 6, 3)
                nvgFillColor(vg, nvgRGBA(40, 35, 25, 80)); nvgFill(vg)
                -- 战力条前景
                local fillW4 = math.floor(barMaxW * ratio)
                if fillW4 > 0 then
                    local r4 = ratio < 0.5 and 200 or math.floor(100 + 120 * (1 - ratio))
                    local g4 = ratio < 0.5 and math.floor(140 + 120 * ratio) or 200
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx + 10, barY4, fillW4, 6, 3)
                    nvgFillColor(vg, nvgRGBA(r4, g4, 80, 170)); nvgFill(vg)
                end
                -- 战力数值 (条右侧)
                M.DrawTextOutlined(cx + 12 + fillW4 + 3, barY4 - 3, string.format("%.0f", totalPower), 18, 160, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            end

            -- 存储卡片点击区域
            st._cityCardRects[city.id] = { x = cx, y = cy, w = cardW, h = cardH }
        end

        drawY = drawY + cardH + gap
    end

    -- 记录总内容高度用于滚动
    st._cityListTotalH = drawY - contentY + scrollY
    st._cityListVisibleH = contentH

    nvgRestore(vg)

    -- (结束回合已移至右侧面板底部, 返回已移至顶栏)

    -- 滚动条
    if st._cityListTotalH > contentH then
        local scrollBarH = math.max(16, contentH * (contentH / st._cityListTotalH))
        local scrollBarY = contentY + (scrollY / (st._cityListTotalH - contentH)) * (contentH - scrollBarH)
        nvgBeginPath(vg); nvgRoundedRect(vg, listW - 4, scrollBarY, 3, scrollBarH, 1.5)
        nvgFillColor(vg, nvgRGBA(200, 170, 100, 80)); nvgFill(vg)
    end
end

-- ============================================================================
-- 武将弹窗 (卡牌+详情)
-- ============================================================================
local function DrawHeroPopup(W, H, t)
    local st = worldMapState
    if not st.heroPopup then return end
    local hIdx = st.heroPopup
    local card = HERO_CARDS[hIdx]
    if not card then st.heroPopup = nil; return end

    -- 判断是否我方武将
    local isPlayerHero = false
    local heroCityId = nil
    for cid, cd in pairs(st.cityData) do
        if cd.owner == "player" then
            for _, h in ipairs(cd.heroes) do
                if h == hIdx then isPlayerHero = true; heroCityId = cid; break end
            end
        end
        if isPlayerHero then break end
    end

    -- 全屏半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)

    -- 弹窗尺寸 (适配18pt最低字号)
    local popW = 420
    local popH = isPlayerHero and 540 or 480
    local popX = (W - popW) / 2
    local popY = (H - popH) / 2

    -- 保存弹窗矩形用于输入命中检测
    st._heroPopupRect = { x = popX, y = popY, w = popW, h = popH }

    -- 弹窗背景
    local bgGrad = nvgLinearGradient(vg, popX, popY, popX, popY + popH,
        nvgRGBA(60, 35, 15, 240), nvgRGBA(40, 22, 10, 250))
    nvgBeginPath(vg); nvgRoundedRect(vg, popX, popY, popW, popH, 10)
    nvgFillPaint(vg, bgGrad); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 180, 80, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 顶部装饰条
    nvgBeginPath(vg); nvgRoundedRect(vg, popX + 2, popY + 2, popW - 4, 30, 8)
    local titleGrad = nvgLinearGradient(vg, popX, popY, popX + popW, popY + 30,
        nvgRGBA(180, 130, 40, 200), nvgRGBA(140, 90, 20, 200))
    nvgFillPaint(vg, titleGrad); nvgFill(vg)

    -- 武将名 + 品质
    M.DrawTextOutlined(popX + popW / 2, popY + 17, card.name, 18, 255)

    -- === 左侧: 卡牌立绘 ===
    local cardAreaX = popX + 14
    local cardAreaY = popY + 38
    local cardW2, cardH2 = 110, 144

    -- 使用 DrawInventoryCard 渲染完整卡牌
    local hero = playerHeroes and playerHeroes[hIdx]
    local cons = hero and hero.constellation or 0
    DrawInventoryCard(cardAreaX, cardAreaY, cardW2, cardH2, card, cons, false, false)

    -- === 右侧: 属性面板 ===
    local infoX = cardAreaX + cardW2 + 10
    local infoW = popW - (cardW2 + 10) - 24
    local lineH = 24  -- 18pt字体用24px行高(紧凑)
    local ltAlign = NVG_ALIGN_LEFT + NVG_ALIGN_TOP

    local attrY = cardAreaY + 2

    -- 势力
    local facName = card.faction and GetFacName(card.faction) or "群雄"
    M.DrawTextOutlined(infoX, attrY, "势力", 18, 180, ltAlign)
    M.DrawTextOutlined(infoX + 38, attrY, facName, 18, 240, ltAlign)

    -- 兵种
    attrY = attrY + lineH
    local troopKey = st.heroTroopChoice[hIdx] or card.troopType or "infantry"
    local ttInfo = TROOP_TYPES[troopKey]
    local troopDisp = ttInfo and ttInfo.name or "步兵"
    M.DrawTextOutlined(infoX, attrY, "兵种", 18, 180, ltAlign)
    M.DrawTextOutlined(infoX + 38, attrY, troopDisp, 18, 240, ltAlign)

    -- === 五维属性 (stats5) ===
    local s5 = card.stats5 or { str = 50, int = 50, vit = 50, tec = 50, spd = 50 }
    local barW = infoW - 62  -- 进度条宽度
    local barH = 6            -- 进度条高度(更细)
    local stats5List = {
        { label = "武力", val = s5.str, clr = {255, 140, 100} },
        { label = "智力", val = s5.int, clr = {120, 180, 255} },
        { label = "体力", val = s5.vit, clr = {100, 220, 130} },
        { label = "技法", val = s5.tec, clr = {255, 210, 80} },
        { label = "速度", val = s5.spd, clr = {100, 220, 200} },
    }
    for _, attr in ipairs(stats5List) do
        attrY = attrY + lineH
        -- 标签
        M.DrawTextOutlined(infoX, attrY, attr.label, 18, 180, ltAlign)
        -- 数值
        M.DrawTextOutlined(infoX + 38, attrY, tostring(attr.val), 18, 240, ltAlign)
        -- 进度条背景
        local bx = infoX + 62
        local by = attrY + 7
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, barW, barH, 3)
        nvgFillColor(vg, nvgRGBA(40, 35, 25, 150)); nvgFill(vg)
        -- 进度条前景
        local fillW = math.floor(barW * math.min(attr.val, 100) / 100)
        if fillW > 0 then
            nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, fillW, barH, 3)
            nvgFillColor(vg, nvgRGBA(attr.clr[1], attr.clr[2], attr.clr[3], 200)); nvgFill(vg)
        end
    end

    -- === 下方: 武技/习得 ===
    local bottomY = cardAreaY + cardH2 + 10
    local detailLineH = 26  -- 18pt字体用26px行高
    local detailX = popX + 14

    -- 横线分隔
    nvgBeginPath(vg); nvgMoveTo(vg, popX + 12, bottomY - 4); nvgLineTo(vg, popX + popW - 12, bottomY - 4)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 武技
    if card.techs and #card.techs > 0 then
        M.DrawTextOutlined(detailX, bottomY, "武技:", 18, 180, ltAlign)
        local techNames = {}
        for _, tech in ipairs(card.techs) do table.insert(techNames, tech.name or "?") end
        local techStr = table.concat(techNames, " / ")
        nvgSave(vg)
        nvgIntersectScissor(vg, detailX + 46, bottomY, popW - 74, detailLineH)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
        nvgTextAlign(vg, ltAlign)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 168))
        nvgText(vg, detailX + 45, bottomY, techStr, nil)
        nvgText(vg, detailX + 47, bottomY, techStr, nil)
        nvgText(vg, detailX + 46, bottomY - 1, techStr, nil)
        nvgText(vg, detailX + 46, bottomY + 1, techStr, nil)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
        nvgText(vg, detailX + 46, bottomY, techStr, nil)
        nvgRestore(vg)
        bottomY = bottomY + detailLineH
    end

    -- 拜师学到的技能
    if st.heroLearnedSkills[hIdx] then
        local ls = st.heroLearnedSkills[hIdx]
        M.DrawTextOutlined(detailX, bottomY, "习得:", 18, 180, ltAlign)
        local teacherCard = HERO_CARDS[ls.teacherIdx]
        local teacherTech = teacherCard and teacherCard.techs and teacherCard.techs[ls.techIdx]
        if teacherTech then
            local learnStr = teacherTech.name .. " (师从" .. (teacherCard.name or "") .. ")"
            nvgSave(vg)
            nvgIntersectScissor(vg, detailX + 46, bottomY, popW - 74, detailLineH)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 18)
            nvgTextAlign(vg, ltAlign)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 168))
            nvgText(vg, detailX + 45, bottomY, learnStr, nil)
            nvgText(vg, detailX + 47, bottomY, learnStr, nil)
            nvgText(vg, detailX + 46, bottomY - 1, learnStr, nil)
            nvgText(vg, detailX + 46, bottomY + 1, learnStr, nil)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
            nvgText(vg, detailX + 46, bottomY, learnStr, nil)
            nvgRestore(vg)
        end
        bottomY = bottomY + detailLineH
    end

    -- 驻城信息
    if heroCityId then
        local cityInfo = WORLD_CITIES[heroCityId]
        if cityInfo then
            M.DrawTextOutlined(detailX, bottomY, "驻城:", 18, 180, ltAlign)
            M.DrawTextOutlined(detailX + 46, bottomY, cityInfo.name, 18, 240, ltAlign)
            bottomY = bottomY + detailLineH
        end
    end

    -- === 我方武将操作按钮 ===
    if isPlayerHero then
        bottomY = bottomY + 6
        -- 横线分隔
        nvgBeginPath(vg); nvgMoveTo(vg, popX + 12, bottomY - 2); nvgLineTo(vg, popX + popW - 12, bottomY - 2)
        nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        local btnW3 = 96
        local btnH3 = 34
        local btnGap = 6
        local totalBtnW = btnW3 * 3 + btnGap * 2
        local btnStartX = popX + (popW - totalBtnW) / 2

        -- 武将管理按钮
        st.btn_heroPopupManage = M.DrawBtn(btnStartX, bottomY + 2, btnW3, btnH3, "武将管理", 100, 80, 45)

        -- 兵种切换按钮
        local troopOpts = card.troopOptions or { card.troopType }
        if #troopOpts > 1 then
            st.btn_heroPopupTroop = M.DrawBtn(btnStartX + btnW3 + btnGap, bottomY + 2, btnW3, btnH3, "切换兵种", 100, 80, 45)
        end

        -- 拜师按钮
        if not st.heroLearnedSkills[hIdx] then
            st.btn_heroPopupApprentice = M.DrawBtn(btnStartX + (btnW3 + btnGap) * 2, bottomY + 2, btnW3, btnH3, "拜师学技", 100, 80, 45)
        end

        bottomY = bottomY + btnH3 + 8
    end

    -- 关闭按钮
    local closeBtnW, closeBtnH = 88, 34
    local closeBtnX = popX + (popW - closeBtnW) / 2
    local closeBtnY = popY + popH - 40
    st.btn_heroPopupClose = M.DrawBtn(closeBtnX, closeBtnY, closeBtnW, closeBtnH, "关闭", 55, 50, 48)
end

-- ============================================================================
-- 主绘制入口 (背景+地图变换+顶部栏+左侧列表+右侧面板+武将弹窗)
-- ============================================================================
function M.DrawWorldMapScreen(drawPanelFn)
    local st = worldMapState
    local W, H = DESIGN_W, DESIGN_H
    local t = gameState.gameTime or 0
    st.mapPulse = t

    -- 屏幕震动
    local AnimShake = require("ui.anim")
    AnimShake.UpdateShake(t)
    nvgSave(vg)
    AnimShake.ApplyShake()

    local L = M.LAYOUT

    -- === 自动居中+缩放动画 (平滑lerp) ===
    local lerpDt = 1.0 / 60.0  -- 近似帧时间
    local lerpSpeed = 5.0
    if st.mapTargetX and st.mapTargetY then
        local dx = st.mapTargetX - st.mapCenterX
        local dy = st.mapTargetY - st.mapCenterY
        if math.abs(dx) < 1 and math.abs(dy) < 1 then
            st.mapCenterX = st.mapTargetX
            st.mapCenterY = st.mapTargetY
            st.mapTargetX = nil
            st.mapTargetY = nil
        else
            local f = 1 - math.exp(-lerpSpeed * lerpDt)
            st.mapCenterX = st.mapCenterX + dx * f
            st.mapCenterY = st.mapCenterY + dy * f
        end
    end
    -- 缩放动画
    if st.mapTargetZoom then
        local dz = st.mapTargetZoom - st.mapZoom
        if math.abs(dz) < 0.01 then
            st.mapZoom = st.mapTargetZoom
            st.mapTargetZoom = nil
        else
            local f = 1 - math.exp(-lerpSpeed * lerpDt)
            st.mapZoom = st.mapZoom + dz * f
        end
    end

    -- === 地图视口区域 (根据面板收缩状态动态计算) ===
    local leftCollapsed  = st.leftPanelCollapsed  or false
    local rightCollapsed = st.rightPanelCollapsed or false
    local hasPanel = (st.selectedCity ~= nil) or (st.phase ~= "MAP" and st.phase ~= "BATTLE_ANIM")
    local effectiveLeftW  = leftCollapsed and 0 or L.LEFT_W
    local effectiveRightW = (hasPanel and not rightCollapsed) and L.RIGHT_W or 0
    local mapViewX = effectiveLeftW
    local mapViewY = L.TOP_BAR_H
    local mapViewW = W - effectiveLeftW - effectiveRightW
    local mapViewH = H - L.TOP_BAR_H

    -- 计算适配缩放: 最小缩放时地图覆盖整个视口 (cover模式, 无留白)
    local fitScaleX = mapViewW / MAP_W
    local fitScaleY = mapViewH / MAP_H
    local fitScale = math.max(fitScaleX, fitScaleY)
    local renderScale = fitScale * st.mapZoom

    -- 存储地图变换参数供 input 模块使用
    st._mapViewX = mapViewX
    st._mapViewY = mapViewY
    st._mapViewW = mapViewW
    st._mapViewH = mapViewH
    st._mapRenderScale = renderScale
    st._mapFitScale = fitScale

    -- 约束地图中心点 (确保不露出空白)
    local visW = mapViewW / renderScale
    local visH = mapViewH / renderScale
    if visW < MAP_W then
        st.mapCenterX = math.max(visW / 2, math.min(MAP_W - visW / 2, st.mapCenterX))
    else
        st.mapCenterX = MAP_W / 2
    end
    if visH < MAP_H then
        st.mapCenterY = math.max(visH / 2, math.min(MAP_H - visH / 2, st.mapCenterY))
    else
        st.mapCenterY = MAP_H / 2
    end

    -- === 1. 绘制地图区域 (裁切+变换) ===
    nvgSave(vg)
    nvgScissor(vg, mapViewX, mapViewY, mapViewW, mapViewH)

    -- 视口中心 (设计坐标)
    local vpCx = mapViewX + mapViewW / 2
    local vpCy = mapViewY + mapViewH / 2

    -- 背景图 (在变换内绘制)
    nvgSave(vg)
    nvgTranslate(vg, vpCx, vpCy)
    nvgScale(vg, renderScale, renderScale)
    nvgTranslate(vg, -st.mapCenterX, -st.mapCenterY)

    local bgImg = IMG.wmBgClean or IMG.wmBg
    if IsImageReady(bgImg) then
        -- 绘制背景图覆盖地图坐标系区域
        local pat = nvgImagePattern(vg, 0, 0, MAP_W, MAP_H, 0, bgImg, 1.0)
        nvgBeginPath(vg); nvgRect(vg, -20, -20, MAP_W + 40, MAP_H + 40)
        nvgFillPaint(vg, pat); nvgFill(vg)
    else
        -- fallback 渐变色背景
        nvgBeginPath(vg); nvgRect(vg, 0, 0, MAP_W, MAP_H)
        local bgGrad = nvgLinearGradient(vg, 0, 0, 0, MAP_H,
            nvgRGBA(235, 220, 185, 255), nvgRGBA(215, 195, 160, 255))
        nvgFillPaint(vg, bgGrad); nvgFill(vg)
    end

    -- 城池图标+连线 (在地图坐标系中绘制)
    DrawCityIcons(t)

    -- 战斗动画: 行军/攻城/换旗/欢呼 (地图坐标)
    DrawBattleAnimMap(t)

    nvgRestore(vg) -- 结束地图变换

    -- 地图边缘渐隐 (遮罩)
    local fadeW = 20
    -- 左边缘
    local fadeL = nvgLinearGradient(vg, mapViewX, 0, mapViewX + fadeW, 0,
        nvgRGBA(30, 18, 8, 180), nvgRGBA(30, 18, 8, 0))
    nvgBeginPath(vg); nvgRect(vg, mapViewX, mapViewY, fadeW, mapViewH)
    nvgFillPaint(vg, fadeL); nvgFill(vg)
    -- 右边缘
    local rEdge = mapViewX + mapViewW
    local fadeR = nvgLinearGradient(vg, rEdge - fadeW, 0, rEdge, 0,
        nvgRGBA(30, 18, 8, 0), nvgRGBA(30, 18, 8, 180))
    nvgBeginPath(vg); nvgRect(vg, rEdge - fadeW, mapViewY, fadeW, mapViewH)
    nvgFillPaint(vg, fadeR); nvgFill(vg)

    nvgRestore(vg) -- 结束 scissor

    -- === 2. 左侧城池列表 ===
    if not leftCollapsed then
        DrawCityList(W, H, t)
    end

    -- === 3. 右侧操作面板 ===
    local rpX = W - L.RIGHT_W
    local rpY = L.TOP_BAR_H
    local rpW = L.RIGHT_W
    local rpH = H - L.TOP_BAR_H

    -- 全屏覆盖面板 (剧本/阵营选择，不依赖右侧面板区域)
    local isFullscreenPhase = (st.phase == "CAMPAIGN_SELECT" or st.phase == "FACTION_SELECT" or st.phase == "TURN_REPORT")
    if isFullscreenPhase then
        if drawPanelFn then
            drawPanelFn(0, 0, W, H, t)
        end
    elseif hasPanel and not rightCollapsed then
        nvgBeginPath(vg); nvgRect(vg, rpX, rpY, rpW, rpH)
        nvgFillColor(vg, nvgRGBA(30, 18, 8, 170)); nvgFill(vg)
        nvgBeginPath(vg); nvgMoveTo(vg, rpX, rpY); nvgLineTo(vg, rpX, H)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        if drawPanelFn then
            drawPanelFn(rpX, rpY, rpW, rpH, t)
        end
    else
        -- 右侧面板未绘制(收起或无面板): 清除所有面板相关点击区域, 防止残留rect穿透
        st._mapPanelHeroRects = nil
        st._mapPanelHeroScrollArea = nil
        st._mapPanelHeroTotalH = nil
        st._atkSourceRects = nil
        st._atkTargetRects = nil
        st._transferSourceRects = nil
        st.heroPopup = nil; st._heroPopupRect = nil
        -- 清除面板按钮rect
        st.btn_affairs = nil; st.btn_reinforce = nil; st.btn_transfer = nil
        st.btn_diplomacy = nil; st.btn_stratagem = nil; st.btn_attack = nil
        st.btn_cancelAtk = nil; st.btn_confirmAtk = nil
        st.btn_atkSourceBack = nil; st.btn_transferBack = nil
        st.btn_affairsBack = nil; st.btn_diploBack = nil; st.btn_stratBack = nil
        st.btn_moveBack = nil
    end

    -- === 4. 面板收缩 Tab 按钮 (全屏面板阶段不显示) ===
    if isFullscreenPhase then
        st.btn_toggleLeft = nil
        st.btn_toggleRight = nil
        return  -- 全屏面板不绘制Tab/顶部栏/武将弹窗
    end
    local tabW, tabH = 24, 72  -- 放大按钮，更易点击
    local tabY = L.TOP_BAR_H + (H - L.TOP_BAR_H) / 2 - tabH / 2
    local tabRadius = 6
    local tabPulse = 0.85 + 0.15 * math.sin(t * 2.2)
    local tabFill    = nvgRGBA(50, 34, 14, 220)
    local tabStroke  = nvgRGBA(220, 175, 80, math.floor(150 * tabPulse))
    local tabText    = nvgRGBA(240, 210, 150, 230)

    -- 左侧 Tab
    local leftTabX = leftCollapsed and 0 or (L.LEFT_W - tabW)
    local leftArrow = leftCollapsed and "▶" or "◀"
    nvgBeginPath(vg); nvgRoundedRect(vg, leftTabX, tabY, tabW, tabH, tabRadius)
    nvgFillColor(vg, tabFill); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, leftTabX, tabY, tabW, tabH, tabRadius)
    nvgStrokeColor(vg, tabStroke); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, tabText)
    nvgText(vg, leftTabX + tabW / 2, tabY + tabH / 2, leftArrow, nil)
    st.btn_toggleLeft = { x = leftTabX, y = tabY, w = tabW, h = tabH }

    -- 右侧 Tab (仅当 hasPanel 时显示)
    if hasPanel then
        local rightTabX = rightCollapsed and (W - tabW) or (W - L.RIGHT_W)
        local rightArrow = rightCollapsed and "◀" or "▶"
        nvgBeginPath(vg); nvgRoundedRect(vg, rightTabX, tabY, tabW, tabH, tabRadius)
        nvgFillColor(vg, tabFill); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, rightTabX, tabY, tabW, tabH, tabRadius)
        nvgStrokeColor(vg, tabStroke); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, tabText)
        nvgText(vg, rightTabX + tabW / 2, tabY + tabH / 2, rightArrow, nil)
        st.btn_toggleRight = { x = rightTabX, y = tabY, w = tabW, h = tabH }
    else
        st.btn_toggleRight = nil
    end

    -- === 5. 顶部状态栏 (最后绘制，覆盖在最上层) ===
    DrawTopBar(W, H)

    -- === 6. 武将弹窗 (最顶层) ===
    DrawHeroPopup(W, H, t)

    -- === 6.5 战斗动画覆盖层 (通知横幅 + 跳过提示) ===
    DrawBattleAnimOverlay(W, H)

    -- === 7. 浮动飘字 + 屏幕闪烁 ===
    local Anim = require("ui.anim")
    Anim.DrawFloatNumbers(t)
    Anim.DrawFlash(W, H, t)

    -- === 7.5 回合播报 ===
    Anim.DrawTurnAnnounce(W, H, t)

    -- === 7.6 飞卡动画 (搜索人才成功) ===
    Anim.UpdateFlyingCard(t)
    local fcBtn = Anim.DrawFlyingCard(W, H, t)
    worldMapState.btn_talentOk = fcBtn

    -- === 7.7 通用操作反馈弹窗 (征兵/升级城防/犒赏三军) ===
    Anim.UpdateActionCard(t)
    Anim.DrawActionCard(W, H, t)

    -- === 8. 屏幕转场遮罩 (绝对最顶层) ===
    Anim.DrawTransition(W, H)

    -- 恢复震动偏移
    nvgRestore(vg)
end

return M
