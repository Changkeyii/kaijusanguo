-- ============================================================================
-- systems/td/td_reward.lua - 塔防通关掉落 & CSGO转盘动画
-- 用途: 每关通关后展示CSGO风格横向滚动抽奖动画
-- ============================================================================
---@diagnostic disable: undefined-global

local TDData = require("systems.td.td_data")

local M = {}

-- ============================================================================
-- 常量
-- ============================================================================
local REEL_ITEM_COUNT   = 40    -- 转盘总格子数
local REEL_ITEM_W       = 80    -- 单个格子宽度
local REEL_ITEM_H       = 90    -- 单个格子高度
local REEL_GAP          = 4     -- 格子间距
local REEL_VISIBLE_W    = 640   -- 可视区域宽度
local REEL_Y            = 200   -- 转盘Y位置(设计坐标)
local SPIN_DURATION     = 3.5   -- 主转动时间
local SLOW_DURATION     = 1.5   -- 减速时间
local TOTAL_DURATION    = SPIN_DURATION + SLOW_DURATION

local MAX_EXTRA_SPINS   = 2     -- 广告最多额外抽2次
local AD_COOLDOWN       = 0.5   -- 防止连击

-- 掉落品阶概率 (按TD关卡等级缩放)
local TIER_WEIGHTS_BASE = {
    { tier = 1, weight = 500 },  -- 凡品
    { tier = 2, weight = 300 },  -- 良品
    { tier = 3, weight = 130 },  -- 优品
    { tier = 4, weight = 50 },   -- 将品
    { tier = 5, weight = 15 },   -- 王品
    { tier = 6, weight = 5 },    -- 帝品
}

-- ============================================================================
-- 状态
-- ============================================================================

---@class TDRewardState
---@field active boolean 是否正在展示
---@field reelItems table[] 转盘物品列表
---@field targetIdx number 最终停留索引
---@field scrollX number 当前滚动偏移
---@field targetScrollX number 目标滚动偏移
---@field timer number 动画计时
---@field phase string "SPINNING"|"STOPPED"|"DONE"
---@field spinCount number 已完成的抽奖次数(含额外)
---@field maxSpins number 本关最大抽奖次数 (1 + 广告获得)
---@field results table[] 已获得的奖品
---@field adWatched boolean 本关是否已看广告
---@field level number 当前关卡
---@field btnRects table
---@field adCooldown number 广告按钮冷却
tdRewardState = nil

-- ============================================================================
-- 掉落生成
-- ============================================================================

--- 按权重随机选择品阶
local function RollTier(level)
    -- 关卡越高，高品阶权重增加
    local levelBonus = math.min(level - 1, 15) * 0.08  -- 每关+8%高品概率上限
    local weights = {}
    for _, tw in ipairs(TIER_WEIGHTS_BASE) do
        local w = tw.weight
        if tw.tier >= 3 then
            w = w * (1 + levelBonus)
        end
        if tw.tier <= 2 then
            w = w * math.max(0.5, 1 - levelBonus * 0.3)
        end
        weights[#weights + 1] = { tier = tw.tier, w = w }
    end
    -- 帝品(tier6)概率硬上限 1.5%
    local MAX_T6_PCT = 0.015
    local t6 = weights[#weights]  -- tier6 是最后一个
    local othersW = 0
    for i = 1, #weights - 1 do othersW = othersW + weights[i].w end
    local maxT6W = othersW * MAX_T6_PCT / (1 - MAX_T6_PCT)
    if t6.w > maxT6W then t6.w = maxT6W end
    -- 构建累积权重
    local totalW = 0
    local adjusted = {}
    for _, wt in ipairs(weights) do
        totalW = totalW + wt.w
        adjusted[#adjusted + 1] = { tier = wt.tier, cumW = totalW }
    end
    local roll = math.random() * totalW
    for _, a in ipairs(adjusted) do
        if roll <= a.cumW then return a.tier end
    end
    return 1
end

--- 生成单个掉落物品
local function GenerateDropItem(level)
    local tier = RollTier(level)
    local si = math.random(1, #EQUIPMENT_SETS)
    local pi = math.random(1, 7)
    return {
        setIdx = si,
        slotIdx = pi,
        tier = tier,
        setName = EQUIPMENT_SETS[si].name,
        pieceName = EQUIPMENT_SETS[si].pieces[pi].name,
        tierName = EQUIP_TIER_NAMES[tier],
        tierColor = EQUIP_TIERS[tier].color,
    }
end

--- 生成转盘物品列表 (N个随机物品，其中targetIdx是真正掉落的)
local function GenerateReel(level)
    local items = {}
    for i = 1, REEL_ITEM_COUNT do
        items[i] = GenerateDropItem(level)
    end
    -- 真正掉落物放在可视区中间偏后 (让动画有足够的滚动距离)
    local targetIdx = math.random(math.floor(REEL_ITEM_COUNT * 0.65), math.floor(REEL_ITEM_COUNT * 0.85))
    -- 真正掉落物品阶可能更好
    items[targetIdx] = GenerateDropItem(level)
    return items, targetIdx
end

-- ============================================================================
-- 初始化 / 控制
-- ============================================================================

--- 开始通关奖励展示
function M.Start(level)
    local items, targetIdx = GenerateReel(level)

    -- 计算目标滚动位置: 让targetIdx对齐到可视区中心
    local itemFullW = REEL_ITEM_W + REEL_GAP
    local centerOffset = REEL_VISIBLE_W / 2 - REEL_ITEM_W / 2
    local targetScroll = (targetIdx - 1) * itemFullW - centerOffset
    -- 多转一整圈 (所有格子的总宽度)，增强抽奖仪式感
    targetScroll = targetScroll + REEL_ITEM_COUNT * itemFullW
    -- 加一点随机偏移让定格不总在正中
    targetScroll = targetScroll + math.random(-15, 15)

    tdRewardState = {
        active = true,
        reelItems = items,
        targetIdx = targetIdx,
        scrollX = 0,
        targetScrollX = targetScroll,
        timer = 0,
        phase = "SPINNING",
        spinCount = 0,
        maxSpins = 1,  -- 基础1次
        results = {},
        adWatched = false,
        level = level,
        btnRects = {},
        adCooldown = 0,
    }
end

--- 完成当前转盘，发放奖品
local function FinishCurrentSpin()
    local st = tdRewardState
    if not st then return end

    local item = st.reelItems[st.targetIdx]
    -- 真正创建装备
    local eq = CreateEquipItem(item.setIdx, item.slotIdx, item.tier)
    item.uid = eq.uid
    item.quality = eq.quality

    st.results[#st.results + 1] = {
        setIdx = item.setIdx,
        slotIdx = item.slotIdx,
        tier = item.tier,
        setName = item.setName,
        pieceName = item.pieceName,
        tierName = item.tierName,
        tierColor = item.tierColor,
        uid = eq.uid,
        quality = eq.quality,
    }
    st.spinCount = st.spinCount + 1
    st.phase = "STOPPED"
end

--- 开始额外转盘 (看广告后)
local function StartExtraSpin()
    local st = tdRewardState
    if not st then return end

    local items, targetIdx = GenerateReel(st.level)
    local itemFullW = REEL_ITEM_W + REEL_GAP
    local centerOffset = REEL_VISIBLE_W / 2 - REEL_ITEM_W / 2
    local targetScroll = (targetIdx - 1) * itemFullW - centerOffset
        + REEL_ITEM_COUNT * itemFullW + math.random(-15, 15)

    st.reelItems = items
    st.targetIdx = targetIdx
    st.scrollX = 0
    st.targetScrollX = targetScroll
    st.timer = 0
    st.phase = "SPINNING"
end

--- 结束奖励展示，返回结果
function M.Finish()
    local st = tdRewardState
    local results = st and st.results or {}
    tdRewardState = nil
    return results
end

function M.IsActive()
    return tdRewardState ~= nil and tdRewardState.active
end

-- ============================================================================
-- Update
-- ============================================================================
function M.Update(dt)
    local st = tdRewardState
    if not st or not st.active then return end

    -- 广告冷却
    if st.adCooldown > 0 then st.adCooldown = st.adCooldown - dt end

    if st.phase ~= "SPINNING" then return end

    st.timer = st.timer + dt

    -- 缓动: 快速加速 → 匀速 → 减速停止
    local t = math.min(st.timer / TOTAL_DURATION, 1.0)
    -- easeOutQuint: 先快后慢
    local eased = 1 - (1 - t) ^ 4
    st.scrollX = eased * st.targetScrollX

    if st.timer >= TOTAL_DURATION then
        st.scrollX = st.targetScrollX
        FinishCurrentSpin()
        PlaySFX(AUDIO.sfx_click)
    end
end

-- ============================================================================
-- 渲染
-- ============================================================================
function M.Draw()
    local st = tdRewardState
    if not st or not st.active then return end

    local W, H = DESIGN_W, DESIGN_H

    -- 半透明背景遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(10, 8, 5, 220))
    nvgFill(vg)

    -- 标题
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    nvgText(vg, W / 2, 60, "第" .. st.level .. "关 通关奖励")

    -- 玉璧奖励 + 抽奖次数
    local jadeReward = 50 + st.level * 20
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(120, 220, 255, 230))
    nvgText(vg, W / 2, 85, "+" .. jadeReward .. " 玉璧")
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(200, 190, 160, 180))
    nvgText(vg, W / 2, 105, "抽奖 " .. st.spinCount .. "/" .. st.maxSpins)

    -- ======== 转盘区域 ========
    local reelLeft = (W - REEL_VISIBLE_W) / 2
    local reelTop = REEL_Y
    local itemFullW = REEL_ITEM_W + REEL_GAP

    -- 转盘背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, reelLeft - 4, reelTop - 4, REEL_VISIBLE_W + 8, REEL_ITEM_H + 8, 6)
    nvgFillColor(vg, nvgRGBA(30, 28, 22, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 160, 100, 120))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 裁剪绘制转盘物品
    nvgSave(vg)
    nvgScissor(vg, reelLeft, reelTop, REEL_VISIBLE_W, REEL_ITEM_H)

    -- 循环滚动：将scrollX映射到[0, totalReelW)区间，实现无缝衔接
    local totalReelW = REEL_ITEM_COUNT * itemFullW
    local scrollMod = st.scrollX % totalReelW
    local subOffset = -(scrollMod % itemFullW)
    local firstIdx0 = math.floor(scrollMod / itemFullW)
    local numVisible = math.ceil(REEL_VISIBLE_W / itemFullW) + 2

    for vi = 0, numVisible - 1 do
        local i = ((firstIdx0 + vi) % REEL_ITEM_COUNT) + 1  -- 1-based
        local item = st.reelItems[i]
        local x = reelLeft + subOffset + vi * itemFullW
        if item and x + REEL_ITEM_W >= reelLeft and x <= reelLeft + REEL_VISIBLE_W then
            local isTarget = (i == st.targetIdx and st.phase == "STOPPED")
            local tc = item.tierColor or { 150, 150, 150 }

            -- 物品背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, reelTop, REEL_ITEM_W, REEL_ITEM_H, 4)
            if isTarget then
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 80))
            else
                nvgFillColor(vg, nvgRGBA(45, 40, 35, 220))
            end
            nvgFill(vg)

            -- 边框
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, reelTop, REEL_ITEM_W, REEL_ITEM_H, 4)
            if isTarget then
                nvgStrokeColor(vg, nvgRGBA(255, 220, 80, 255))
                nvgStrokeWidth(vg, 2.5)
            else
                nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 100))
                nvgStrokeWidth(vg, 1)
            end
            nvgStroke(vg)

            -- 装备icon区域 (使用正式的 DrawEquipTierBg + DrawCardImage)
            local iconSize = math.min(REEL_ITEM_W - 12, REEL_ITEM_H - 26)
            local iconX = x + (REEL_ITEM_W - iconSize) / 2
            local iconY = reelTop + 4
            if DrawEquipTierBg and IMG and IMG.equipmentSheet and IMG.equipmentSheet > 0 then
                DrawEquipTierBg(iconX, iconY, iconSize, iconSize, item.tier, 5)
                DrawCardImage(iconX + 4, iconY + 4, iconSize - 8, iconSize - 8,
                    IMG.equipmentSheet, item.slotIdx - 1, item.setIdx - 1,
                    EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
            else
                -- 无图时 fallback 文字
                local setCfg = EQUIPMENT_SETS[item.setIdx]
                local setClr = setCfg and setCfg.color or { 120, 120, 120 }
                nvgBeginPath(vg)
                nvgRoundedRect(vg, iconX, iconY, iconSize, iconSize, 5)
                nvgFillColor(vg, nvgRGBA(setClr[1], setClr[2], setClr[3], 60))
                nvgFill(vg)
                local slotName = EQUIP_SLOT_NAMES[item.slotIdx] or "?"
                nvgFontFaceId(vg, GetMainFont())
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(240, 230, 210, 220))
                nvgText(vg, x + REEL_ITEM_W / 2, iconY + iconSize / 2, slotName)
            end

            -- 品阶 + 装备名(底部)
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
            local displayName = (item.tierName or "") .. " " .. (item.pieceName or "")
            if #displayName > 8 then displayName = displayName:sub(1, 24) end
            nvgText(vg, x + REEL_ITEM_W / 2, reelTop + REEL_ITEM_H - 3, displayName)
        end
    end

    nvgRestore(vg)

    -- ======== 中央指针 (倒三角) ========
    local pointerX = W / 2
    local pointerTopY = reelTop - 12
    nvgBeginPath(vg)
    nvgMoveTo(vg, pointerX - 8, pointerTopY)
    nvgLineTo(vg, pointerX + 8, pointerTopY)
    nvgLineTo(vg, pointerX, pointerTopY + 10)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
    nvgFill(vg)

    -- 底部指针
    local pointerBotY = reelTop + REEL_ITEM_H + 12
    nvgBeginPath(vg)
    nvgMoveTo(vg, pointerX - 8, pointerBotY)
    nvgLineTo(vg, pointerX + 8, pointerBotY)
    nvgLineTo(vg, pointerX, pointerBotY - 10)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
    nvgFill(vg)

    -- ======== 已获得奖品展示 (icon + 文字) ========
    if #st.results > 0 then
        local resultY = reelTop + REEL_ITEM_H + 28
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 190, 160, 200))
        nvgText(vg, W / 2, resultY, "已获得:")

        local rowH = 38
        local iconSz = 32
        local totalW2 = #st.results * (iconSz + 50 + 8)
        local startX2 = W / 2 - totalW2 / 2

        for ri, res in ipairs(st.results) do
            local rx = startX2 + (ri - 1) * (iconSz + 50 + 8)
            local ry = resultY + 22
            local rc = res.tierColor or { 180, 180, 180 }

            -- 小装备icon
            if DrawEquipTierBg and IMG and IMG.equipmentSheet and IMG.equipmentSheet > 0 then
                DrawEquipTierBg(rx, ry, iconSz, iconSz, res.tier, 4)
                DrawCardImage(rx + 3, ry + 3, iconSz - 6, iconSz - 6,
                    IMG.equipmentSheet, res.slotIdx - 1, res.setIdx - 1,
                    EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
            end

            -- 名字
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 255))
            nvgText(vg, rx + iconSz + 4, ry + iconSz / 2, res.pieceName or "")
        end
    end

    -- ======== 停止后的按钮区 ========
    if st.phase == "STOPPED" then
        local btnY = H - 65
        local btnH = 38
        st.btnRects = {}

        -- 看广告额外抽 (条件: 未看广告 且 还有额外次数可用)
        if not st.adWatched and st.spinCount < st.maxSpins + MAX_EXTRA_SPINS then
            local adBtnW = 180
            local adBtnX = W / 2 - adBtnW - 8
            nvgBeginPath(vg)
            nvgRoundedRect(vg, adBtnX, btnY, adBtnW, btnH, 6)
            nvgFillColor(vg, nvgRGBA(60, 120, 180, 220))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, adBtnX, btnY, adBtnW, btnH, 6)
            nvgStrokeColor(vg, nvgRGBA(100, 180, 255, 180))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 240, 255, 255))
            nvgText(vg, adBtnX + adBtnW / 2, btnY + btnH / 2, "看广告额外抽2次")
            st.btnRects.adBtn = { x = adBtnX, y = btnY, w = adBtnW, h = btnH }
        end

        -- 继续/下一关按钮
        local contW = 120
        local contX = W / 2 + 8
        if st.adWatched or st.spinCount >= st.maxSpins + MAX_EXTRA_SPINS then
            -- 广告已用完或已看，按钮居中
            contX = W / 2 - contW / 2
        end
        nvgBeginPath(vg)
        nvgRoundedRect(vg, contX, btnY, contW, btnH, 6)
        nvgFillColor(vg, nvgRGBA(180, 140, 50, 220))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, contX, btnY, contW, btnH, 6)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, 180))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 240, 200, 255))
        local contLabel = (st.spinCount < st.maxSpins) and "继续抽奖" or "下一关"
        nvgText(vg, contX + contW / 2, btnY + btnH / 2, contLabel)
        st.btnRects.continueBtn = { x = contX, y = btnY, w = contW, h = btnH }
    end

    -- 转动中提示
    if st.phase == "SPINNING" then
        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local flashA = math.floor(160 + 80 * math.sin(st.timer * 6))
        nvgFillColor(vg, nvgRGBA(255, 220, 100, flashA))
        nvgText(vg, W / 2, H - 40, "抽奖中...")
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================
function M.handlePress(sx, sy, touchId)
    local st = tdRewardState
    if not st or not st.active then return false end
    if st.phase ~= "STOPPED" then return true end  -- 转动中吃掉输入

    local dx, dy = ScreenToDesign(sx, sy)
    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    -- 看广告按钮
    if st.btnRects.adBtn and HitRect(st.btnRects.adBtn) then
        if st.adCooldown > 0 then return true end
        st.adCooldown = AD_COOLDOWN
        -- 调用广告
        ShowAdSafe(SafeAdCallback(function(result)
            if result and result.success and tdRewardState then
                tdRewardState.adWatched = true
                tdRewardState.maxSpins = tdRewardState.maxSpins + MAX_EXTRA_SPINS
                -- 立即开始下一次转
                StartExtraSpin()
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "+2次额外抽奖!", 1.5, { 100, 200, 255 }, 18)
            end
        end))
        PlaySFX(AUDIO.sfx_click)
        return true
    end

    -- 继续/下一关按钮
    if st.btnRects.continueBtn and HitRect(st.btnRects.continueBtn) then
        if st.spinCount < st.maxSpins then
            -- 还有抽奖次数，开始下一次转
            StartExtraSpin()
        else
            -- 抽完了，结束奖励展示 → 进入下一关
            M.Finish()
            -- 触发下一关
            if tdState then
                local TDState = require("systems.td.td_state")
                TDState.NextLevel()
            end
        end
        PlaySFX(AUDIO.sfx_click)
        return true
    end

    return true  -- 吃掉所有点击
end

return M
