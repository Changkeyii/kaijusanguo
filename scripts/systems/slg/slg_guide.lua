-- ============================================================================
-- slg/slg_guide.lua - SLG新手引导系统模块
-- 用途: 21步交互式新手引导, 引导玩家学习城池选择/武将管理/调兵/攻城等操作
-- 依赖: slg_render(DrawBtn/DrawTextOutlined), worldMapState(全局)
-- 导出: StartGuide, IsGuideActive, CheckGuideProgress,
--       UpdateGuide, DrawGuide, HandleGuideInput
-- ============================================================================
---@diagnostic disable: undefined-global

local Render = require("systems.slg.slg_render")
local DrawBtn          = Render.DrawBtn
local DrawTextOutlined = Render.DrawTextOutlined

local M = {}

-- ============================================================================
-- 新手引导系统（交互式）
-- ============================================================================

---@class GuideState
---@field active boolean 引导是否激活
---@field step number 当前步骤 0=未开始, 1~21=引导步骤
---@field timer number 步骤计时器
---@field fingerY number 手指动画Y偏移
---@field btnRect table|nil 当前按钮点击区域
---@field skipRect table|nil 跳过按钮点击区域
---@field waitAction boolean 是否等待玩家操作

---@type GuideState
wmGuide = {
    active = false,
    step = 0,
    timer = 0,
    fingerY = 0,
    btnRect = nil,
    skipRect = nil,
    waitAction = false,
}

-- 引导步骤：交互式，玩家按提示操作后自动推进
WM_GUIDE_STEPS = {
    {   -- 1 选择城池
        title = "1/21 选择城池",
        hint = "点击左侧列表中你的城池(金色)",
        highlight = "city_list",
        waitFor = "select_city",
    },
    {   -- 2 查看武将弹窗
        title = "2/21 查看武将",
        hint = "点击城池卡片中的武将头像\n查看武将详情",
        highlight = "hero_card_area",
        waitFor = "open_hero_popup",
    },
    {   -- 3 进入武将管理
        title = "3/21 武将管理",
        hint = "点击弹窗中的【武将管理】按钮",
        highlight = "heroPopupManage",
        waitFor = "enter_hero_manage",
    },
    {   -- 4 返回地图(从武将管理)
        title = "4/21 返回地图",
        hint = "点击【返回】回到世界地图",
        highlight = "heroManageBack",
        waitFor = "back_to_map",
    },
    {   -- 5 进入内政
        title = "5/21 内政经营",
        hint = "先选中你的城池\n再点击右侧【内政】按钮",
        highlight = "affairs_btn",
        waitFor = "enter_affairs",
    },
    {   -- 6 征兵
        title = "6/21 征兵",
        hint = "点击【征兵】补充兵力",
        highlight = "affairs_recruit",
        waitFor = "click_recruit",
    },
    {   -- 7 补兵
        title = "7/21 补兵",
        hint = "点击【补兵】恢复编制",
        highlight = "affairs_reinforce",
        waitFor = "click_reinforce",
    },
    {   -- 8 升级城防
        title = "8/21 升级城防",
        hint = "点击【升级城防】提升防御",
        highlight = "affairs_upgrade",
        waitFor = "click_upgrade",
    },
    {   -- 9 搜索人才
        title = "9/21 搜索人才",
        hint = "点击【搜索人才】招募武将",
        highlight = "affairs_search",
        waitFor = "click_search",
    },
    {   -- 10 确认人才
        title = "10/21 确认人才",
        hint = "新武将加入! 点击【确 认】",
        highlight = "talent_ok",
        waitFor = "confirm_talent",
    },
    {   -- 11 犒赏三军
        title = "11/21 犒赏三军",
        hint = "点击【犒赏三军】提升士气",
        highlight = "affairs_morale",
        waitFor = "click_morale",
    },
    {   -- 12 返回地图(从内政)
        title = "12/21 返回地图",
        hint = "点击底部【返回】按钮回到地图",
        highlight = "affairs_back_btn",
        waitFor = "back_to_map",
    },
    {   -- 13 滚动到敌方区域 (自动)
        title = "13/21 查看敌方势力",
        hint = "向下查看其他势力的城池...",
        highlight = "city_list",
        waitFor = "scroll_to_enemy",
    },
    {   -- 14 选择敌方城池
        title = "14/21 选择敌方城池",
        hint = "点击左侧列表中的敌方城池",
        highlight = "city_list",
        waitFor = "select_enemy_city",
    },
    {   -- 15 进入外交
        title = "15/21 外交系统",
        hint = "点击右侧【外交】按钮",
        highlight = "diplomacy_btn",
        waitFor = "enter_diplomacy",
    },
    {   -- 16 外交功能介绍(自动4秒)
        title = "16/21 外交详解",
        hint = "可向其他势力送礼或签约\n合纵连横是统一的关键",
        highlight = "none",
        waitFor = "auto_timer",
        autoDelay = 4.0,
    },
    {   -- 17 返回地图(从外交)
        title = "17/21 返回地图",
        hint = "点击底部【返回】回到地图",
        highlight = "diploBack",
        waitFor = "back_to_map",
    },
    {   -- 18 进入计略
        title = "18/21 计略系统",
        hint = "点击右侧【计略】按钮",
        highlight = "stratagem_btn",
        waitFor = "enter_stratagem",
    },
    {   -- 19 计略功能介绍(自动4秒)
        title = "19/21 计略详解",
        hint = "离间/反间/火攻/水攻...\n巧用计略可以不战而胜",
        highlight = "none",
        waitFor = "auto_timer",
        autoDelay = 4.0,
    },
    {   -- 20 返回地图(从计略)
        title = "20/21 返回地图",
        hint = "点击底部【返回】回到地图",
        highlight = "stratBack",
        waitFor = "back_to_map",
    },
    {   -- 21 引导完成
        title = "21/21 引导完成!",
        hint = "选择敌方城池点击【出征】发起进攻!\n占领全部城池即可获胜",
        highlight = "none",
        waitFor = nil,
    },
}

function M.StartGuide()
    if gameSettings.guideCompleted then
        print("=== 世界地图引导: 已完成, 跳过 ===")
        return
    end
    wmGuide.active = true
    wmGuide.step = 1
    wmGuide.timer = 0
    wmGuide.waitAction = true
    print("=== 世界地图引导: 开始(交互式) ===")
end

function M.IsGuideActive()
    return wmGuide.active
end

-- 引导条件检查：玩家操作完成后自动推进到下一步
function M.CheckGuideProgress()
    if not wmGuide.active then return end
    local st = worldMapState
    local stepData = WM_GUIDE_STEPS[wmGuide.step]
    if not stepData or not stepData.waitFor then return end

    local done = false
    if stepData.waitFor == "select_city" then
        done = (st.selectedCity ~= nil and st.cityData[st.selectedCity] and st.cityData[st.selectedCity].owner == "player")
    elseif stepData.waitFor == "open_hero_popup" then
        done = (st.heroPopup ~= nil)
    elseif stepData.waitFor == "enter_hero_manage" then
        done = (st.phase == "HERO_MANAGE")
    elseif stepData.waitFor == "enter_affairs" then
        done = (st.phase == "AFFAIRS")
    elseif stepData.waitFor == "click_recruit" then
        done = (wmGuide._affairsDone == "recruit")
    elseif stepData.waitFor == "click_reinforce" then
        done = (wmGuide._affairsDone == "reinforce")
    elseif stepData.waitFor == "click_upgrade" then
        done = (wmGuide._affairsDone == "upgrade")
    elseif stepData.waitFor == "click_search" then
        done = (wmGuide._affairsDone == "search")
    elseif stepData.waitFor == "confirm_talent" then
        done = (wmGuide._affairsDone == "talent_confirmed")
    elseif stepData.waitFor == "click_morale" then
        done = (wmGuide._affairsDone == "morale")
    elseif stepData.waitFor == "auto_timer" then
        done = (wmGuide.timer >= (stepData.autoDelay or 3.0))
    elseif stepData.waitFor == "back_to_map" then
        done = (st.phase == "MAP" and st.heroPopup == nil)
    elseif stepData.waitFor == "enter_diplomacy" then
        done = (st.phase == "DIPLOMACY")
    elseif stepData.waitFor == "enter_stratagem" then
        done = (st.phase == "STRATAGEM")
    elseif stepData.waitFor == "scroll_to_enemy" then
        done = (wmGuide._scrollDone == true)
    elseif stepData.waitFor == "select_enemy_city" then
        done = (st.selectedCity ~= nil and st.cityData[st.selectedCity] and st.cityData[st.selectedCity].owner ~= "player")
    elseif stepData.waitFor == "enter_attack" then
        done = (st.phase == "ATK_TARGET" or st.phase == "CONFIRM_ATTACK")
    elseif stepData.waitFor == "end_turn" then
        done = (st.phase == "TURN_REPORT")
    end

    if done then
        if wmGuide.step < #WM_GUIDE_STEPS then
            wmGuide.step = wmGuide.step + 1
            wmGuide.timer = 0
            wmGuide.waitAction = true
            wmGuide._affairsDone = nil  -- 重置内政子步骤状态
            if rawget(_G, "PlaySFX") then PlaySFX(AUDIO.sfx_click) end
            print("=== 世界地图引导: 自动推进到步骤 " .. wmGuide.step .. " ===")

            -- 准备 scroll_to_enemy 步骤
            local nextData = WM_GUIDE_STEPS[wmGuide.step]
            if nextData and nextData.waitFor == "scroll_to_enemy" then
                wmGuide._scrollDone = false
                -- 计算敌方区域滚动目标: 玩家城池数 * 卡高 + header
                local numPlayer = 0
                for _, cd2 in pairs(st.cityData) do
                    if cd2.owner == "player" then numPlayer = numPlayer + 1 end
                end
                local L = Render.LAYOUT
                wmGuide._scrollTarget = math.max(0, 26 + numPlayer * (L.CARD_H + L.CARD_GAP) - 20)
            end
        else
            -- 世界地图引导全部完成
            wmGuide.active = false
            wmGuide.step = 0
            gameSettings.guideCompleted = true
            SaveSettings()
            print("=== 世界地图引导: 全部完成 ===")
        end
    end
end

function M.UpdateGuide(dt)
    if not wmGuide.active then return end
    wmGuide.timer = wmGuide.timer + dt
    wmGuide.fingerY = math.sin(wmGuide.timer * 3) * 5
    -- 强引导提示冷却
    if wmGuide._blockToastCD and wmGuide._blockToastCD > 0 then
        wmGuide._blockToastCD = wmGuide._blockToastCD - dt
    end
    -- scroll_to_enemy 自动滚动动画
    local stepData = WM_GUIDE_STEPS[wmGuide.step]
    if stepData and stepData.waitFor == "scroll_to_enemy" and not wmGuide._scrollDone then
        local st = worldMapState
        local target = wmGuide._scrollTarget or 0
        local current = st.cityListScroll or 0
        local diff = target - current
        if math.abs(diff) < 2 then
            st.cityListScroll = target
            wmGuide._scrollDone = true
        else
            st.cityListScroll = current + diff * math.min(1, dt * 4)
        end
    end
    M.CheckGuideProgress()
end

-- 绘制引导提示（居中显示在左右面板之间，无不透明背景）
function M.DrawGuide()
    if not wmGuide.active or wmGuide.step < 1 then return end
    local W, H = DESIGN_W, DESIGN_H
    local stepData = WM_GUIDE_STEPS[wmGuide.step]
    if not stepData then wmGuide.active = false; return end

    local st = worldMapState
    local L = Render.LAYOUT

    -- 高亮区域
    local hlRect = nil
    if stepData.highlight == "city_list" then
        hlRect = { x = 0, y = L.TOP_BAR_H, w = L.LEFT_W, h = H - L.TOP_BAR_H - 42 }
    elseif stepData.highlight == "hero_card_area" and st._heroAreaRect then
        hlRect = st._heroAreaRect
    elseif stepData.highlight == "heroPopupManage" and st.btn_heroPopupManage then
        hlRect = st.btn_heroPopupManage
    elseif stepData.highlight == "heroManageBack" and st.btn_heroManageBack then
        hlRect = st.btn_heroManageBack
    elseif stepData.highlight == "affairs_btn" and st.btn_affairs then
        hlRect = st.btn_affairs
    elseif stepData.highlight == "affairs_recruit" and st.btn_recruit then
        hlRect = st.btn_recruit
    elseif stepData.highlight == "affairs_reinforce" and st.btn_reinforce then
        hlRect = st.btn_reinforce
    elseif stepData.highlight == "affairs_upgrade" and st.btn_upgrade then
        hlRect = st.btn_upgrade
    elseif stepData.highlight == "affairs_search" and st.btn_search then
        hlRect = st.btn_search
    elseif stepData.highlight == "affairs_morale" and st.btn_morale then
        hlRect = st.btn_morale
    elseif stepData.highlight == "talent_ok" and st.btn_talentOk then
        hlRect = st.btn_talentOk
    elseif stepData.highlight == "affairs_back_btn" and st.btn_affairsBack then
        hlRect = st.btn_affairsBack
    elseif stepData.highlight == "diplomacy_btn" and st.btn_diplomacy then
        hlRect = st.btn_diplomacy
    elseif stepData.highlight == "diploBack" and st.btn_diploBack then
        hlRect = st.btn_diploBack
    elseif stepData.highlight == "stratagem_btn" and st.btn_stratagem then
        hlRect = st.btn_stratagem
    elseif stepData.highlight == "stratBack" and st.btn_stratBack then
        hlRect = st.btn_stratBack
    elseif stepData.highlight == "attack_btn" and st.btn_attack then
        hlRect = st.btn_attack
    elseif stepData.highlight == "end_turn_btn" and st.btn_endTurn then
        hlRect = st.btn_endTurn
    end

    -- 高亮闪烁边框
    if hlRect then
        local pad = 6
        local rx, ry = hlRect.x - pad, hlRect.y - pad
        local rw, rh = hlRect.w + pad * 2, hlRect.h + pad * 2
        local pulse = 0.5 + 0.5 * math.sin(wmGuide.timer * 4)

        nvgBeginPath(vg); nvgRoundedRect(vg, rx - 3, ry - 3, rw + 6, rh + 6, 10)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(100 * pulse)))
        nvgStrokeWidth(vg, 4); nvgStroke(vg)

        nvgBeginPath(vg); nvgRoundedRect(vg, rx, ry, rw, rh, 8)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(220 * pulse)))
        nvgStrokeWidth(vg, 2.5); nvgStroke(vg)

        nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 26)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 230, 80, math.floor(220 * pulse)))
        nvgText(vg, rx + rw / 2, ry - 16 + wmGuide.fingerY, "v", nil)
    end

    -- === 顶部区域：文字显示在顶栏下方，避免遮挡弹窗 ===
    local centerX = W / 2
    local topY = L.TOP_BAR_H + 8

    local hintText = stepData.hint or ""
    local hasTimer = stepData.waitFor == "auto_timer"

    -- 步骤标题（金黄色 + 黑色描边）
    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    -- 描边
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 200))
    nvgText(vg, centerX - 1, topY, stepData.title, nil)
    nvgText(vg, centerX + 1, topY, stepData.title, nil)
    nvgText(vg, centerX, topY - 1, stepData.title, nil)
    nvgText(vg, centerX, topY + 1, stepData.title, nil)
    -- 金黄色主体
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 240))
    nvgText(vg, centerX, topY, stepData.title, nil)

    -- 提示文字（亮黄色 + 黑色描边，支持 \n 换行）
    local lineY = topY + 26
    nvgFontSize(vg, 20)
    for line in hintText:gmatch("[^\n]+") do
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
        nvgText(vg, centerX - 1, lineY, line, nil)
        nvgText(vg, centerX + 1, lineY, line, nil)
        nvgText(vg, centerX, lineY - 1, line, nil)
        nvgText(vg, centerX, lineY + 1, line, nil)
        nvgFillColor(vg, nvgRGBA(255, 235, 140, 220))
        nvgText(vg, centerX, lineY, line, nil)
        lineY = lineY + 22
    end

    -- auto_timer 倒计时显示
    if hasTimer then
        local remaining = math.max(0, (stepData.autoDelay or 3.0) - wmGuide.timer)
        local timerStr = string.format("%.0f秒后继续...", math.ceil(remaining))
        nvgFontSize(vg, 18)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
        nvgText(vg, centerX - 1, lineY + 4, timerStr, nil)
        nvgText(vg, centerX + 1, lineY + 4, timerStr, nil)
        nvgFillColor(vg, nvgRGBA(200, 200, 180, 180))
        nvgText(vg, centerX, lineY + 4, timerStr, nil)
    end

    -- 步骤指示器 (点点) — 文字下方
    local dotTotalW = (#WM_GUIDE_STEPS - 1) * 14
    local dotStartX = centerX - dotTotalW / 2
    local dotY = lineY + (hasTimer and 28 or 8)
    for i = 1, #WM_GUIDE_STEPS do
        local dotX = dotStartX + (i - 1) * 14
        nvgBeginPath(vg); nvgCircle(vg, dotX, dotY, i == wmGuide.step and 5 or 3)
        nvgFillColor(vg, i <= wmGuide.step
            and nvgRGBA(255, 210, 80, 255)
            or nvgRGBA(120, 100, 70, 150))
        nvgFill(vg)
    end

    -- 最后一步：显示"开始游戏"按钮（居中）
    if not stepData.waitFor then
        local gbtnW, gbtnH = 120, 36
        local gbtnX = centerX - gbtnW / 2
        local gbtnY = dotY + 16
        wmGuide.btnRect = DrawBtn(gbtnX, gbtnY, gbtnW, gbtnH, "开始征战!", 100, 80, 45)
    else
        wmGuide.btnRect = nil
    end

    -- 跳过按钮（居中区域右上角, 白字黑描边）
    local skipX = W - L.RIGHT_W - 10
    local skipY = L.TOP_BAR_H + 6
    DrawTextOutlined(skipX, skipY + 10, "跳过引导 >", 20, 160, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    wmGuide.skipRect = { x = skipX - 80, y = skipY - 2, w = 84, h = 20 }
end

-- 引导点击处理 — 强引导过滤已移至 HandleInput 顶部, 此处仅保留接口兼容
function M.HandleGuideInput(dx, dy)
    return false
end

return M
