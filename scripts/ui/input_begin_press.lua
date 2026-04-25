-- ============================================================================
-- ui/input_begin_press.lua - 触摸/点击事件入口分发器
-- 用途: BeginPress 全局函数 - 帧去重、按钮反馈、全局弹窗、phase 分发
-- 子模块: input_press_menu, input_press_systems, input_press_items,
--         input_press_social, input_press_dungeon, input_press_endgame
-- [TECH_DEBT] 全局函数模式: 延续 input 模块设计, 50+ 文件引用不可变更
-- ============================================================================

---@diagnostic disable: undefined-global
function BeginPress(sx, sy, touchId)
    local curFrame = time:GetFrameNumber()
    if curFrame == _lastPressFrame then return end
    _lastPressFrame = curFrame

    -- GM手势检测 (仅主界面可触发)
    if gameState.phase == "MENU" or gameState.phase == "HOME" then
        local _gdx, _gdy = ScreenToDesign(sx, sy)
        local GMGesture = require("ui.gm_gesture")
        GMGesture.OnPress(_gdx, _gdy)
    end

    -- GM面板点击处理
    if gameState.phase == "GM_PANEL" then
        local _gdx, _gdy = ScreenToDesign(sx, sy)
        local GMPanel = require("ui.gm_panel")
        if GMPanel.IsActive() then
            local consumed = GMPanel.handlePress(_gdx, _gdy)
            if consumed then return end
            -- 未消费 = 编辑器tab, 转发给编辑器
            local TDEditor = require("systems.td.td_editor")
            if TDEditor.IsActive() then TDEditor.handlePress(sx, sy) end
        end
        return
    end

    -- 按钮按压反馈: 统一记录点击位置(设计坐标)
    do
        local _adx, _ady = ScreenToDesign(sx, sy)
        local _Anim = require("ui.anim")
        _Anim.OnBtnPress(_adx, _ady, gameState.gameTime or 0)
    end

    -- === LOADING 阶段点击提示 ===
    if gameState.phase == "LOADING" then
        loadingClickTipTimer = 2.5
        return
    end

    -- === 个人资料界面输入 ===
    if gameState.phase == "PROFILE" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 头像选择
        for i, rect in ipairs(profileAvatarRects) do
            if HitRect(rect) then
                profileState.selectedAvatar = i
                return
            end
        end
        -- 名字选择 (含自定义选项)
        for i, rect in ipairs(profileNameRects) do
            if HitRect(rect) then
                profileState.selectedName = i
                if i == CUSTOM_NAME_IDX then
                    -- 点击自定义: 启动文本输入
                    profileState.isInputActive = true
                    input:SetScreenKeyboardVisible(true)
                else
                    profileState.isInputActive = false
                    input:SetScreenKeyboardVisible(false)
                end
                return
            end
        end
        -- 确认按钮
        if HitRect(profileConfirmBtnRect) then
            -- (教程资源检查已移除，无需等待下载)
            playerInfo.avatarIdx = AVATAR_OPTIONS[profileState.selectedAvatar] or 1
            if profileState.selectedName == CUSTOM_NAME_IDX and #profileState.customName > 0 then
                playerInfo.name = profileState.customName
            else
                playerInfo.name = PRESET_NAMES[profileState.selectedName] or "无名武灵"
            end
            playerInfo.profileSet = true
            profileState.isInputActive = false
            input:SetScreenKeyboardVisible(false)
            -- 立即保存，确保 profileSet 状态持久化
            SaveGameProgress()
            -- 模块下载已在阻塞加载完成后自动启动（InitModuleDownloads）
            if profileState.editMode then
                -- 编辑模式：直接返回，不触发新手引导
                profileState.editMode = false
                PopPhase()
                print("=== 资料编辑完成: " .. playerInfo.name .. " ===")
            else
                gameState.phase = "MENU"
                print("=== 资料设置完成: " .. playerInfo.name .. " ===")
            end
        end
        return
    end

    -- ======== 统一规则弹窗交互 (全局最高优先级) ========
    if phaseRulePopup.show then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRectG(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        local cr = phaseRulePopup.closeBtnRect
        if cr and HitRectG(cr) then
            phaseRulePopup.show = false
            phaseRulePopup.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
        local pr = phaseRulePopup.panelRect
        if pr and HitRectG(pr) then
            phaseRulePopup.isDragging = true
            phaseRulePopup.lastTouchY = dy
            phaseRulePopup.vel = 0
        else
            phaseRulePopup.show = false
            phaseRulePopup.isDragging = false
        end
        return
    end

    -- ======== 统一 "?" 按钮点击检测 (全局) ========
    if phaseRulePopup.helpBtnRect and gameState.phase ~= "BATTLE" then
        local dx, dy = ScreenToDesign(sx, sy)
        local _hbr = phaseRulePopup.helpBtnRect
        if _hbr and dx >= _hbr.x and dx <= _hbr.x + _hbr.w
            and dy >= _hbr.y and dy <= _hbr.y + _hbr.h then
            phaseRulePopup.show = true
            phaseRulePopup.phase = gameState.phase
            phaseRulePopup.scrollY = 0
            phaseRulePopup.vel = 0
            phaseRulePopup.isDragging = false
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end


    -- ============================================================================
    -- Phase 分发: 按功能域委托到子模块
    -- ============================================================================
    local phase = gameState.phase

    -- Group 1: 主菜单
    if phase == "MENU" then
        local handler = require("ui.input_press_menu")
        handler.handle(sx, sy, touchId)
        return
    end

    -- Group 2: 武技/签到/任务/编辑器
    if phase == "SKILL_CODEX"
        or phase == "WELFARE" or phase == "PROGRESS"
        or phase == "DEV_EDITOR" then
        local handler = require("ui.input_press_systems")
        handler.handle(sx, sy, touchId)
        return
    end

    -- Group 2.5: 召唤系统
    if phase == "SUMMON" then
        local handler = require("ui.input_press_summon")
        handler.handle(sx, sy, touchId)
        return
    end

    -- Group 3: 图鉴/装备/邮件/交易
    if phase == "GACHA" or phase == "CODEX" or phase == "HERO_DETAIL"
        or phase == "PLAYER_DETAIL" or phase == "EQUIP"
        or phase == "MAIL_BOX" or phase == "TRADE" then
        local handler = require("ui.input_press_items")
        handler.handle(sx, sy, touchId)
        return
    end

    -- Group 4: 势力/好友/排行/封印
    if phase == "FACTION" or phase == "FRIENDS"
        or phase == "POWER_RANK" or phase == "CONTRIB_RANK"
        or phase == "EQUIP_CODEX" or phase == "SEAL_MGR" then
        local handler = require("ui.input_press_social")
        handler.handle(sx, sy, touchId)
        return
    end

    -- Group 5: 世界地图/关卡/副本
    if phase == "WORLD_MAP" or phase == "STAGE_SELECT"
        or phase == "DAILY_DUNGEON" or phase == "RESOURCE_DUNGEON" then
        local handler = require("ui.input_press_dungeon")
        handler.handle(sx, sy, touchId)
        return
    end

    -- Group 7: 塔防模式 (TD_EDITOR 已合并到 GM_PANEL, 在顶部处理)
    if phase == "TD_SELECT" then
        local TDSelect = require("systems.td.td_select")
        if not tdSelectState then TDSelect.Init() end
        TDSelect.handlePress(sx, sy, touchId)
        return
    end
    if phase == "TD_BATTLE" then
        -- CSGO转盘奖励动画优先拦截
        local TDReward = require("systems.td.td_reward")
        if TDReward.IsActive() then
            TDReward.handlePress(sx, sy, touchId)
            return
        end
        local TDInput = require("systems.td.td_input")
        TDInput.handlePress(sx, sy, touchId)
        return
    end

    -- Group 6: 战斗/战令/讨伐/爬塔/排位/胜负结算
    if phase == "BATTLE" or phase == "BATTLE_PASS" or phase == "ABYSS_SELECT"
        or phase == "TOWER_SELECT" or phase == "RANKED_SELECT"
        or phase == "WIN" or phase == "LOSE" then
        local handler = require("ui.input_press_endgame")
        handler.handle(sx, sy, touchId)
        return
    end

    -- Fallthrough: 未匹配的 phase
    longPressState.pressing = false
    longPressState.card = nil
end
