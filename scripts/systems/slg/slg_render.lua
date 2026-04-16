-- ============================================================================
-- slg/slg_render.lua - 三国武灵传：SLG界面渲染 (完全重做)
-- 纯背景 + 左侧城池列表 + 右侧操作面板 + 顶部状态栏
-- ============================================================================

---@diagnostic disable: undefined-global

local Data = require("systems.slg.slg_data")
local FC   = Data.FC

local M = {}

-- ============================================================================
-- 布局常量
-- ============================================================================
M.LAYOUT = {
    TOP_BAR_H   = 44,       -- 顶部状态栏高度
    LEFT_W      = 230,      -- 左侧城池列表宽度
    LEFT_PAD    = 8,        -- 左侧列表内边距
    CARD_H      = 56,       -- 城池卡片高度
    CARD_GAP    = 4,        -- 卡片间距
    RIGHT_W     = 280,      -- 右侧操作面板宽度
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
    local stats = { player={cities=0,troops=0,heroes=0}, wei={cities=0,troops=0,heroes=0},
                    shu={cities=0,troops=0,heroes=0}, wu={cities=0,troops=0,heroes=0},
                    qun={cities=0,troops=0,heroes=0} }
    for _, city in ipairs(WORLD_CITIES) do
        local cd = worldMapState.cityData[city.id]
        if cd then
            local key = cd.owner
            if stats[key] then
                stats[key].cities = stats[key].cities + 1
                stats[key].troops = stats[key].troops + cd.garrison
                stats[key].heroes = stats[key].heroes + #cd.heroes
            end
        end
    end
    return stats
end

-- ============================================================================
-- 辅助: 按钮(国风暖色卷轴风)
-- ============================================================================
function M.DrawBtn(x, y, w, h, label, r, g, b, alpha)
    alpha = alpha or 200
    local disabled = (alpha <= 150)
    -- 纯色渐变按钮 (不使用背景图)
    nvgBeginPath(vg); nvgRoundedRect(vg, x + 1, y + 1, w, h, 4)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 40)); nvgFill(vg)
    local grad = nvgLinearGradient(vg, x, y, x, y + h,
        nvgRGBA(math.min(255, r + 40), math.min(255, g + 30), math.min(255, b + 20), alpha),
        nvgRGBA(r, g, b, alpha))
    nvgBeginPath(vg); nvgRoundedRect(vg, x, y, w, h, 4)
    nvgFillPaint(vg, grad); nvgFill(vg)
    nvgStrokeColor(vg, disabled and nvgRGBA(120, 100, 70, 60) or nvgRGBA(200, 170, 90, 140))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if disabled then
        nvgFillColor(vg, nvgRGBA(120, 100, 80, 120))
    else
        nvgFillColor(vg, nvgRGBA(60, 30, 10, 160))
        nvgText(vg, x + w / 2 + 1, y + h / 2 + 1, label, nil)
        nvgFillColor(vg, nvgRGBA(255, 240, 200, 240))
    end
    nvgText(vg, x + w / 2, y + h / 2, label, nil)
    return { x = x, y = y, w = w, h = h }
end

-- ============================================================================
-- 顶部状态栏
-- ============================================================================
local function DrawTopBar(W, H)
    local st = worldMapState
    local L = M.LAYOUT
    local barH = L.TOP_BAR_H

    -- 半透明深色条
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, barH)
    local barGrad = nvgLinearGradient(vg, 0, 0, 0, barH,
        nvgRGBA(40, 22, 10, 210), nvgRGBA(60, 32, 15, 220))
    nvgFillPaint(vg, barGrad); nvgFill(vg)
    -- 底部金色线条
    nvgBeginPath(vg); nvgMoveTo(vg, 0, barH - 1); nvgLineTo(vg, W, barH - 1)
    nvgStrokeColor(vg, nvgRGBA(255, 210, 100, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 235, 170, 255))
    nvgText(vg, 12, barH / 2 - 6, "天下大势", nil)

    -- 资源信息
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local resY = barH / 2 - 6
    nvgFillColor(vg, nvgRGBA(255, 240, 210, 220))
    nvgText(vg, 108, resY, "第" .. st.turn .. "回合", nil)
    nvgFillColor(vg, nvgRGBA(255, 230, 100, 255))
    nvgText(vg, 200, resY, "💰" .. st.gold, nil)
    nvgFillColor(vg, nvgRGBA(180, 240, 130, 255))
    nvgText(vg, 285, resY, "🌾" .. st.food, nil)
    local pc = WorldMap.GetPlayerCityCount()
    nvgFillColor(vg, nvgRGBA(220, 210, 255, 240))
    nvgText(vg, 370, resY, "🏯" .. pc .. "/" .. #WORLD_CITIES, nil)

    -- 存档/读档按钮 (右上角区域)
    local saveBtnW, saveBtnH = 44, 22
    local saveBtnY = 4
    local saveBtnX = W - 10 - saveBtnW
    local loadBtnX = saveBtnX - saveBtnW - 4

    st.btn_save = M.DrawBtn(saveBtnX, saveBtnY, saveBtnW, saveBtnH, "存档", 80, 100, 60)
    -- 仅在有存档时显示读档按钮
    local hasSave = rawget(_G, "WorldMap") and WorldMap.HasSave and WorldMap.HasSave()
    if hasSave then
        st.btn_load = M.DrawBtn(loadBtnX, saveBtnY, saveBtnW, saveBtnH, "读档", 60, 80, 120)
    else
        st.btn_load = nil
    end

    -- 玩家阵营
    local pfac = st.playerFaction
    local pfName = FACTIONS[pfac] and FACTIONS[pfac].name or pfac
    nvgFillColor(vg, nvgRGBA(255, 240, 200, 255))
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(vg, loadBtnX - 6, resY, pfName, nil)

    -- 势力实力条
    local facStats = M.GetFactionStats()
    local totalCities = #WORLD_CITIES
    local powerY = barH / 2 + 10
    local powerBarW = W - 24
    local powerBarH = 5
    nvgBeginPath(vg); nvgRoundedRect(vg, 12, powerY, powerBarW, powerBarH, 2)
    nvgFillColor(vg, nvgRGBA(60, 30, 10, 100)); nvgFill(vg)
    local facOrder = {"player", "wei", "shu", "wu", "qun"}
    local px2 = 12
    for _, fk in ipairs(facOrder) do
        local fs = facStats[fk]
        if fs and fs.cities > 0 then
            local segW = powerBarW * (fs.cities / totalCities)
            local fc = M.GetFC(fk)
            nvgBeginPath(vg); nvgRoundedRect(vg, px2, powerY, segW, powerBarH, 2)
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
local CITY_ICON_SIZE = 36     -- 城池图标尺寸(地图坐标)
local FLAG_SIZE = 24          -- 旗帜尺寸(地图坐标)

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
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, iconSz * 0.7 + 6)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(180 * pulse)))
            nvgStrokeWidth(vg, 3); nvgStroke(vg)
            -- 内圈发光
            local glow = nvgRadialGradient(vg, cx, cy, iconSz * 0.3, iconSz * 0.8,
                nvgRGBA(255, 230, 100, math.floor(80 * pulse)), nvgRGBA(255, 200, 50, 0))
            nvgBeginPath(vg); nvgCircle(vg, cx, cy, iconSz * 0.8)
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
            local flagX = cx + iconSz * 0.3
            local flagY = cy - iconSz * 0.35
            DrawIcon(flagImg, flagX, flagY, FLAG_SIZE, 0.9)
        end

        -- 城池名称 (带阴影)
        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        local nameY = cy + iconSz * 0.42
        -- 名称背景条
        local tw = nvgTextBounds(vg, 0, 0, city.name, nil)
        nvgBeginPath(vg); nvgRoundedRect(vg, cx - tw / 2 - 4, nameY - 1, tw + 8, 16, 3)
        nvgFillColor(vg, nvgRGBA(30, 15, 5, 140)); nvgFill(vg)
        -- 名称文字
        nvgFillColor(vg, nvgRGBA(255, 245, 210, isPlayer and 255 or 200))
        nvgText(vg, cx, nameY, city.name, nil)

        -- 驻军数显示 (小字)
        if cd.garrison > 0 then
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(220, 200, 160, 180))
            nvgText(vg, cx, nameY + 15, "兵" .. cd.garrison, nil)
        end

        -- 存储点击区域(地图坐标)
        local hitR = iconSz * 0.5 + 4
        st._mapCityRects[city.id] = { x = cx - hitR, y = cy - hitR, w = hitR * 2, h = hitR * 2 }

        ::cont_icon::
    end
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
    nvgFillColor(vg, nvgRGBA(30, 18, 8, 170)); nvgFill(vg)
    -- 右侧分隔线
    nvgBeginPath(vg); nvgMoveTo(vg, listW, listY); nvgLineTo(vg, listW, H)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 列表标题
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 230, 160, 220))
    nvgText(vg, listW / 2, listY + 14, "— 城 池 —", nil)

    -- 裁切区域
    local contentY = listY + 28
    local contentH = listH - 28 - 42  -- 留底部按钮空间
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
        table.insert(sortedCities, {city = city, cd = cd, isPlayer = (cd.owner == "player")})
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

    -- 清除旧的武将名字点击区域
    st._heroNameRects = st._heroNameRects or {}
    for k in pairs(st._heroNameRects) do st._heroNameRects[k] = nil end

    for _, entry in ipairs(sortedCities) do
        local city = entry.city
        local cd = entry.cd
        local isPlayer = entry.isPlayer

        -- 分组标题
        if isPlayer and not drawnPlayerHeader then
            drawnPlayerHeader = true
            if drawY + 20 > contentY - 20 and drawY < contentY + contentH then
                nvgFontSize(vg, 12)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 210, 80, 200))
                nvgText(vg, pad + 4, drawY + 10, "▸ 我方城池", nil)
            end
            drawY = drawY + 20
        elseif not isPlayer and not drawnEnemyHeader then
            drawnEnemyHeader = true
            if drawY + 20 > contentY - 20 and drawY < contentY + contentH then
                nvgFontSize(vg, 12)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(180, 160, 130, 180))
                nvgText(vg, pad + 4, drawY + 10, "▸ 其他势力", nil)
            end
            drawY = drawY + 20
        end

        -- 只绘制可见卡片
        if drawY + cardH > contentY and drawY < contentY + contentH then
            local cx = pad
            local cy = drawY
            local fc = M.GetFC(cd.owner)
            local isSelected = (st.selectedCity == city.id)

            -- 卡片背景
            if isSelected then
                -- 选中态: 金色高亮
                local pulse = 0.7 + 0.3 * math.sin(t * 3)
                nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 6)
                nvgFillColor(vg, nvgRGBA(120, 90, 30, math.floor(180 * pulse))); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(255, 210, 80, math.floor(220 * pulse)))
                nvgStrokeWidth(vg, 2); nvgStroke(vg)
            else
                -- 普通态
                nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, cardW, cardH, 6)
                nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], isPlayer and 60 or 35))
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], isPlayer and 100 or 50))
                nvgStrokeWidth(vg, 1); nvgStroke(vg)
            end

            -- 阵营色条 (左侧竖条)
            nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy + 4, 4, cardH - 8, 2)
            nvgFillColor(vg, nvgRGBA(fc.main[1], fc.main[2], fc.main[3], 220)); nvgFill(vg)

            -- 城池名称
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 16)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, isSelected and nvgRGBA(255, 240, 180, 255) or nvgRGBA(240, 225, 190, 230))
            nvgText(vg, cx + 12, cy + 6, city.name, nil)

            -- 区域+阵营
            nvgFontSize(vg, 11)
            local facName = isPlayer and "我方" or (FACTIONS[cd.owner] and FACTIONS[cd.owner].name or cd.owner)
            nvgFillColor(vg, nvgRGBA(fc.light[1], fc.light[2], fc.light[3], 180))
            nvgText(vg, cx + 60, cy + 8, facName .. " · " .. city.region, nil)

            -- 第二行: 兵力/城防/产出
            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(200, 190, 170, 200))
            local infoY2 = cy + 26
            nvgText(vg, cx + 12, infoY2, "兵:" .. cd.garrison, nil)
            nvgText(vg, cx + 68, infoY2, "防:Lv" .. cd.level, nil)
            nvgText(vg, cx + 125, infoY2, "产:" .. city.prod, nil)

            -- 第三行: 士气(我方)/武将
            nvgFontSize(vg, 11)
            local row3Y = cy + 40
            if isPlayer then
                nvgFillColor(vg, nvgRGBA(180, 220, 120, 200))
                nvgText(vg, cx + 12, row3Y, "气:" .. cd.morale, nil)
            end
            if #cd.heroes > 0 then
                local heroX = isPlayer and (cx + 50) or (cx + 12)
                nvgFillColor(vg, nvgRGBA(140, 170, 220, 180))
                nvgText(vg, heroX, row3Y, "将:", nil)
                local nameStartX = heroX + 22
                for hi, hIdx in ipairs(cd.heroes) do
                    local card = HERO_CARDS[hIdx]
                    if card then
                        -- 武将名可点击 (带下划线风格)
                        nvgFillColor(vg, nvgRGBA(180, 220, 255, 230))
                        local tw = nvgTextBounds(vg, 0, 0, card.name, nil)
                        nvgText(vg, nameStartX, row3Y, card.name, nil)
                        -- 下划线
                        nvgBeginPath(vg); nvgMoveTo(vg, nameStartX, row3Y + 12)
                        nvgLineTo(vg, nameStartX + tw, row3Y + 12)
                        nvgStrokeColor(vg, nvgRGBA(160, 200, 255, 80)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                        -- 存储点击区域
                        st._heroNameRects[hIdx] = { x = nameStartX, y = row3Y - 2, w = tw, h = 14 }
                        nameStartX = nameStartX + tw + 6
                    end
                end
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

    -- 底部按钮区域
    local btnAreaY = H - 40
    local btnW2 = 90
    local endBtnX = listW / 2 - btnW2 / 2

    local pulse = 0.8 + 0.2 * math.sin(t * 3)
    st.btn_endTurn = M.DrawBtn(pad, btnAreaY, btnW2, 30, "结束回合",
        math.floor(160 * pulse), math.floor(130 * pulse), 30)

    st.btn_back = M.DrawBtn(pad + btnW2 + 6, btnAreaY, 60, 30, "返回", 60, 55, 50)

    -- 滚动条
    if st._cityListTotalH > contentH then
        local scrollBarH = math.max(20, contentH * (contentH / st._cityListTotalH))
        local scrollBarY = contentY + (scrollY / (st._cityListTotalH - contentH)) * (contentH - scrollBarH)
        nvgBeginPath(vg); nvgRoundedRect(vg, listW - 4, scrollBarY, 3, scrollBarH, 1.5)
        nvgFillColor(vg, nvgRGBA(200, 170, 100, 100)); nvgFill(vg)
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

    -- 弹窗尺寸 (我方武将更大以容纳操作按钮)
    local popW = 360
    local popH = isPlayerHero and 440 or 400
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
    nvgBeginPath(vg); nvgRoundedRect(vg, popX + 2, popY + 2, popW - 4, 36, 8)
    local titleGrad = nvgLinearGradient(vg, popX, popY, popX + popW, popY + 36,
        nvgRGBA(180, 130, 40, 200), nvgRGBA(140, 90, 20, 200))
    nvgFillPaint(vg, titleGrad); nvgFill(vg)

    -- 武将名 + 品质
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 245, 200, 255))
    nvgText(vg, popX + popW / 2, popY + 20, card.name, nil)

    -- === 左侧: 卡牌立绘 ===
    local cardAreaX = popX + 14
    local cardAreaY = popY + 44
    local cardW2, cardH2 = 100, 130

    -- 使用 DrawInventoryCard 渲染完整卡牌
    local hero = playerHeroes and playerHeroes[hIdx]
    local cons = hero and hero.constellation or 0
    DrawInventoryCard(cardAreaX, cardAreaY, cardW2, cardH2, card, cons, false, false)

    -- === 右侧: 属性面板 ===
    local infoX = cardAreaX + cardW2 + 14
    local infoW = popW - (cardW2 + 14) - 28
    local lineH = 20
    nvgFontSize(vg, 14); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

    local attrY = cardAreaY + 2

    -- 势力
    local facName = card.faction and FACTIONS[card.faction] and FACTIONS[card.faction].name or "群雄"
    nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, infoX, attrY, "势力", nil)
    nvgFillColor(vg, nvgRGBA(255, 230, 150, 255)); nvgText(vg, infoX + 42, attrY, facName, nil)

    -- 兵种
    attrY = attrY + lineH
    local troopKey = st.heroTroopChoice[hIdx] or card.troopType or "infantry"
    local ttInfo = TROOP_TYPES[troopKey]
    local troopDisp = ttInfo and (ttInfo.icon .. ttInfo.name) or troopKey
    nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, infoX, attrY, "兵种", nil)
    nvgFillColor(vg, nvgRGBA(255, 230, 150, 255)); nvgText(vg, infoX + 42, attrY, troopDisp, nil)

    -- 武力
    attrY = attrY + lineH
    nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, infoX, attrY, "武力", nil)
    nvgFillColor(vg, nvgRGBA(255, 140, 100, 255)); nvgText(vg, infoX + 42, attrY, tostring(card.atk or 0), nil)

    -- 智力
    attrY = attrY + lineH
    nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, infoX, attrY, "智力", nil)
    nvgFillColor(vg, nvgRGBA(120, 180, 255, 255)); nvgText(vg, infoX + 42, attrY, tostring(card.intel or 0), nil)

    -- 统帅
    attrY = attrY + lineH
    nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, infoX, attrY, "统帅", nil)
    nvgFillColor(vg, nvgRGBA(255, 210, 80, 255)); nvgText(vg, infoX + 42, attrY, tostring(card.cmd or 0), nil)

    -- 速度
    attrY = attrY + lineH
    nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, infoX, attrY, "速度", nil)
    nvgFillColor(vg, nvgRGBA(100, 220, 150, 255)); nvgText(vg, infoX + 42, attrY, tostring(card.spd or 0), nil)

    -- === 下方: 武技/习得 ===
    local bottomY = cardAreaY + cardH2 + 10
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local detailX = popX + 18

    -- 横线分隔
    nvgBeginPath(vg); nvgMoveTo(vg, popX + 14, bottomY - 4); nvgLineTo(vg, popX + popW - 14, bottomY - 4)
    nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 武技
    if card.techs and #card.techs > 0 then
        nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, detailX, bottomY, "武技:", nil)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 240))
        local techNames = {}
        for _, tech in ipairs(card.techs) do table.insert(techNames, tech.name or "?") end
        nvgSave(vg)
        nvgIntersectScissor(vg, detailX + 42, bottomY, popW - 74, lineH)
        nvgText(vg, detailX + 42, bottomY, table.concat(techNames, " · "), nil)
        nvgRestore(vg)
        bottomY = bottomY + lineH
    end

    -- 拜师学到的技能
    if st.heroLearnedSkills[hIdx] then
        local ls = st.heroLearnedSkills[hIdx]
        nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, detailX, bottomY, "习得:", nil)
        local teacherCard = HERO_CARDS[ls.teacherIdx]
        local teacherTech = teacherCard and teacherCard.techs and teacherCard.techs[ls.techIdx]
        if teacherTech then
            nvgFillColor(vg, nvgRGBA(255, 200, 120, 255))
            nvgText(vg, detailX + 42, bottomY, teacherTech.name .. " (师从" .. (teacherCard.name or "") .. ")", nil)
        end
        bottomY = bottomY + lineH
    end

    -- 驻城信息
    if heroCityId then
        local cityInfo = WORLD_CITIES[heroCityId]
        if cityInfo then
            nvgFillColor(vg, nvgRGBA(180, 170, 140, 200)); nvgText(vg, detailX, bottomY, "驻城:", nil)
            nvgFillColor(vg, nvgRGBA(200, 220, 160, 255)); nvgText(vg, detailX + 42, bottomY, cityInfo.name, nil)
            bottomY = bottomY + lineH
        end
    end

    -- === 我方武将操作按钮 ===
    if isPlayerHero then
        bottomY = bottomY + 6
        -- 横线分隔
        nvgBeginPath(vg); nvgMoveTo(vg, popX + 14, bottomY - 2); nvgLineTo(vg, popX + popW - 14, bottomY - 2)
        nvgStrokeColor(vg, nvgRGBA(180, 150, 80, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        local btnW3 = 90
        local btnH3 = 28
        local btnGap = 8
        local totalBtnW = btnW3 * 3 + btnGap * 2
        local btnStartX = popX + (popW - totalBtnW) / 2

        -- 武将管理按钮
        st.btn_heroPopupManage = M.DrawBtn(btnStartX, bottomY + 2, btnW3, btnH3, "武将管理", 100, 80, 40)

        -- 兵种切换按钮
        local troopOpts = card.troopOptions or { card.troopType }
        if #troopOpts > 1 then
            st.btn_heroPopupTroop = M.DrawBtn(btnStartX + btnW3 + btnGap, bottomY + 2, btnW3, btnH3, "切换兵种", 80, 100, 60)
        end

        -- 拜师按钮
        if not st.heroLearnedSkills[hIdx] then
            st.btn_heroPopupApprentice = M.DrawBtn(btnStartX + (btnW3 + btnGap) * 2, bottomY + 2, btnW3, btnH3, "拜师学技", 60, 80, 120)
        end

        bottomY = bottomY + btnH3 + 8
    end

    -- 关闭按钮
    local closeBtnW, closeBtnH = 80, 30
    local closeBtnX = popX + (popW - closeBtnW) / 2
    local closeBtnY = popY + popH - 38
    st.btn_heroPopupClose = M.DrawBtn(closeBtnX, closeBtnY, closeBtnW, closeBtnH, "关闭", 120, 80, 40)
end

-- ============================================================================
-- 主绘制入口 (背景+地图变换+顶部栏+左侧列表+右侧面板+武将弹窗)
-- ============================================================================
function M.DrawWorldMapScreen(drawPanelFn)
    local st = worldMapState
    local W, H = DESIGN_W, DESIGN_H
    local t = gameState.gameTime or 0
    st.mapPulse = t

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

    -- === 地图视口区域 (左侧列表和右侧面板之间) ===
    local mapViewX = L.LEFT_W
    local mapViewY = L.TOP_BAR_H
    local hasPanel = (st.selectedCity ~= nil) or (st.phase ~= "MAP")
    local mapViewW = hasPanel and (W - L.LEFT_W - L.RIGHT_W) or (W - L.LEFT_W)
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
    DrawCityList(W, H, t)

    -- === 3. 右侧操作面板 ===
    local rpX = W - L.RIGHT_W
    local rpY = L.TOP_BAR_H
    local rpW = L.RIGHT_W
    local rpH = H - L.TOP_BAR_H

    if hasPanel then
        nvgBeginPath(vg); nvgRect(vg, rpX, rpY, rpW, rpH)
        nvgFillColor(vg, nvgRGBA(30, 18, 8, 170)); nvgFill(vg)
        nvgBeginPath(vg); nvgMoveTo(vg, rpX, rpY); nvgLineTo(vg, rpX, H)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 70, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end

    if drawPanelFn then
        drawPanelFn(rpX, rpY, rpW, rpH, t)
    end

    -- === 4. 顶部状态栏 (最后绘制，覆盖在最上层) ===
    DrawTopBar(W, H)

    -- === 5. 武将弹窗 (最顶层) ===
    DrawHeroPopup(W, H, t)
end

return M
