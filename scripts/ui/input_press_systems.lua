-- ============================================================================
-- ui/input_press_systems.lua - 系统功能点击处理
-- 用途: BeginPress 子处理器 - SKILL_CODEX, SKILL_DETAIL, WELFARE, PROGRESS, DEV_EDITOR
-- 依赖: 全局变量 (gameState, ScreenToDesign, DrawBtn 等)
-- 导出: M.handle(sx, sy, touchId) -> boolean (是否已处理)
-- [TECH_DEBT] 全局变量模式: 延续 input 模块的全局状态设计
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

--- 处理点击事件 (仅处理本模块负责的 phase)
---@param sx number 屏幕坐标X
---@param sy number 屏幕坐标Y
---@param touchId number 触摸ID
---@return boolean handled 是否已处理
function M.handle(sx, sy, touchId)
    if gameState.phase == "SKILL_CODEX" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 弹窗打开时优先处理弹窗交互
        if skillPopup.show then
            if HitRect(skillPopup.closeBtnRect) then
                skillPopup.show = false
                print("=== 关闭武技弹窗 ===")
                return
            end
            -- 合成按钮
            if skillPopup.composeBtnRect and HitRect(skillPopup.composeBtnRect) then
                local curIdx = skillPopup.skillIdx
                if curIdx and TryComposeSkillFrag then
                    local result = TryComposeSkillFrag(curIdx)
                    if result then
                        local skName = SKILL_TECHNIQUES[curIdx] and SKILL_TECHNIQUES[curIdx].name or "?"
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, skName .. " 合成成功!", 1.2, { 255, 220, 100 }, 20)
                        SaveGameProgress()
                    else
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "残片不足", 1.0, { 160, 150, 130 }, 18)
                    end
                end
                return
            end
            -- 装备/卸下按钮
            if skillPopup.equipBtnRect and HitRect(skillPopup.equipBtnRect) then
                local curIdx = skillPopup.skillIdx
                local heroIdx = skillPopup.equipBtnRect.heroIdx
                if SKILL_DEFS[curIdx] and SKILL_DEFS[curIdx].notAvailable then
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "此武技暂未开放", 1.0, { 160, 150, 130 }, 18)
                elseif not heroIdx then
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.35, "请先选择武将", 1.0, { 160, 150, 130 }, 18)
                elseif skillPopup.equipBtnRect.action == "unequip" then
                    local s = skillPopup.equipBtnRect.slot
                    local heroSkills = GetHeroSkills(heroIdx)
                    table.remove(heroSkills, s)
                    print("=== 卸下武技: " .. SKILL_TECHNIQUES[curIdx].name .. " (武将#" .. heroIdx .. " 槽位" .. s .. ") ===")
                    SaveGameProgress()
                else
                    local heroSkills = GetHeroSkills(heroIdx)
                    heroSkills[#heroSkills + 1] = curIdx
                    print("=== 装备武技: " .. SKILL_TECHNIQUES[curIdx].name .. " (武将#" .. heroIdx .. " 槽位" .. #heroSkills .. ") ===")
                    SaveGameProgress()
                end
                return
            end
            -- 替换槽位按钮
            if skillPopup.equipSlotBtns then
                for s, btn in ipairs(skillPopup.equipSlotBtns) do
                    if HitRect(btn) then
                        local curIdx = skillPopup.skillIdx
                        local heroIdx = btn.heroIdx
                        if curIdx and heroIdx then
                            local heroSkills = GetHeroSkills(heroIdx)
                            local old = heroSkills[btn.slot]
                            heroSkills[btn.slot] = curIdx
                            local oldName = old and SKILL_TECHNIQUES[old] and SKILL_TECHNIQUES[old].name or "?"
                            print("=== 装备武技: " .. SKILL_TECHNIQUES[curIdx].name .. " >> 武将#" .. heroIdx .. " 槽位" .. btn.slot .. " (替换" .. oldName .. ") ===")
                            SaveGameProgress()
                        end
                        return
                    end
                end
            end
            -- 点击面板外部关闭弹窗
            if not HitRect(skillPopup.panelRect) then
                skillPopup.show = false
                print("=== 关闭武技弹窗 (点击外部) ===")
                return
            end
            return  -- 弹窗内其他区域吃掉点击
        end

        if HitRect(skillCodexBackBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
            return
        end
        -- 品质标签栏点击
        if skillCodexTierBtnRects then
            for ti, tr in ipairs(skillCodexTierBtnRects) do
                if HitRect(tr) and ti ~= skillCodexState.selectedTier then
                    skillCodexState.selectedTier = ti
                    skillCodexState.scrollX = 0
                    skillCodexState.scrollVelX = 0
                    return
                end
            end
        end
        -- 记录拖拽起始位置（用于横向滚动，点击延迟到EndPress判断）
        skillCodexState.dragStartX = dx
        skillCodexState.dragStartY = dy
        skillCodexState.dragLastX = dx
        skillCodexState.dragLastY = dy
        skillCodexState.isDragging = true
        skillCodexState.scrollVelX = 0
        skillCodexState.scrollVel = 0
        return
    end

    -- === 天命赐福输入 ===
    if gameState.phase == "WELFARE" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        if HitRect(welfareState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            print("=== 返回上一页 ===")
            return
        end
        -- 三日签到按钮 (第1天=武技18, 第2天=武技19, 第3天=20000玉壁)
        local SIGN_SKILL_REWARDS = { 18, 19, nil }  -- 前两天送武技(49残片直接可兑换)
        local SIGN_JADE_REWARD = 20000  -- 第3天送玉壁
        for i = 1, 3 do
            if HitRect(welfareState.signInBtnRects[i]) then
                -- 已领取则跳过
                if welfareState.signInClaimed[i] then break end
                -- 前一天必须已领取
                if i > 1 and not welfareState.signInClaimed[i - 1] then break end
                -- 24小时间隔检查: 前一天领取后需等待24小时
                if i > 1 then
                    local prevTs = welfareState.signInTimestamps[i - 1] or 0
                    if prevTs > 0 and (os.time() - prevTs) < 86400 then
                        local remain = 86400 - (os.time() - prevTs)
                        local hrs = math.floor(remain / 3600)
                        local mins = math.floor((remain % 3600) / 60)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "距下次签到还需 " .. hrs .. "时" .. mins .. "分", 1.5, { 255, 180, 80 }, 18)
                        break
                    end
                end
                local dayIdx = i
                local claimFunc = function()
                    welfareState.signInClaimed[dayIdx] = true
                    welfareState.signInTimestamps[dayIdx] = os.time()
                    if SIGN_SKILL_REWARDS[dayIdx] then
                        -- 送武技残片 (49个, 可直接兑换)
                        local skIdx = SIGN_SKILL_REWARDS[dayIdx]
                        skillFragments[skIdx] = (skillFragments[skIdx] or 0) + SKILL_FRAG_EXCHANGE
                        local sk = SKILL_TECHNIQUES[skIdx]
                        local skName = sk and sk.name or ("武技#" .. skIdx)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "获得 " .. skName .. " ×" .. SKILL_FRAG_EXCHANGE .. " 残片", 1.5, { 200, 160, 255 }, 18)
                        print("=== 签到第" .. dayIdx .. "天: 获得武技" .. skIdx .. " 残片×" .. SKILL_FRAG_EXCHANGE .. " ===")
                    else
                        -- 第3天送20000玉壁
                        playerInfo.jade = playerInfo.jade + SIGN_JADE_REWARD
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            "获得 玉壁 ×" .. SIGN_JADE_REWARD, 1.5, { 255, 220, 100 }, 18)
                        print("=== 签到第" .. dayIdx .. "天: +" .. SIGN_JADE_REWARD .. " 玉壁 ===")
                    end
                end
                if playerInfo.ad_free then
                    claimFunc()
                    SaveGameProgress()
                elseif sdk then
                    ShowAdSafe(SafeAdCallback(function(result)
                        if result.success then
                            claimFunc()
                            ReportAdWatchWelfare()
                            SaveGameProgress()
                        end
                    end))
                else
                    if not IsMobilePlatform() then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25, "仅移动端可观看广告", 1.5, { 200, 150, 100 }, 18)
                        return
                    end
                    claimFunc()
                    ReportAdWatchWelfare()
                end
                return
            end
        end
        -- 十日签到按钮（每日广告领5000玉壁）
        for i = 1, 10 do
            if HitRect(welfareState.dailySignInBtnRects[i]) then
                -- 必须按顺序领取
                if i > 1 and not welfareState.dailySignInClaimed[i - 1] then break end
                if welfareState.dailySignInClaimed[i] then break end
                -- 24小时间隔检查: 前一天领取后需等待24小时
                if i > 1 then
                    local prevTs = welfareState.dailySignInTimestamps[i - 1] or 0
                    if prevTs > 0 and (os.time() - prevTs) < 86400 then
                        local remain = 86400 - (os.time() - prevTs)
                        local rh = math.floor(remain / 3600)
                        local rm = math.floor((remain % 3600) / 60)
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                            string.format("距下次签到还需 %d时%d分", rh, rm),
                            1.5, { 200, 200, 200 }, 16)
                        break
                    end
                end
                local dayIdx = i
                local claimFunc = function()
                    welfareState.dailySignInClaimed[dayIdx] = true
                    welfareState.dailySignInTimestamps[dayIdx] = os.time()
                    playerInfo.jade = playerInfo.jade + 5000
                    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25,
                        "第" .. dayIdx .. "日签到 +5000 玉壁", 1.5, { 255, 220, 100 }, 18)
                    print("=== 十日签到第" .. dayIdx .. "天: +5000 玉壁 ===")
                end
                if playerInfo.ad_free then
                    claimFunc()
                    SaveGameProgress()
                elseif sdk then
                    ShowAdSafe(SafeAdCallback(function(result)
                        if result.success then
                            claimFunc()
                            ReportAdWatchWelfare()
                            SaveGameProgress()
                        end
                    end))
                else
                    if not IsMobilePlatform() then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.25, "仅移动端可观看广告", 1.5, { 200, 150, 100 }, 18)
                        return
                    end
                    claimFunc()
                    ReportAdWatchWelfare()
                end
                return
            end
        end
        -- 在线时长奖励按钮
        local OL_JADE = { 300, 500, 800, 1000 }
        for i = 1, 4 do
            if HitRect(welfareState.onlineBtnRects[i]) then
                welfareState.onlineRewards[i] = true
                playerInfo.jade = playerInfo.jade + OL_JADE[i]
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.4,
                    "在线奖励 +" .. OL_JADE[i] .. " 玉壁", 1.5, { 130, 200, 255 }, 18)
                print("=== 在线时长奖励第" .. i .. "档: +" .. OL_JADE[i] .. " 玉壁 ===")
                return
            end
        end

        -- (大转盘和每日翻牌点击处理已移除)

        -- 贡献榜"查看详情"按钮 → 跳转到贡献榜详情页
        if welfareState.contribDetailBtnRect and HitRect(welfareState.contribDetailBtnRect) then
            welfareState.contribDetailScroll.offset = 0  -- 重置滚动
            PushPhase("CONTRIB_RANK")
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 没有命中任何按钮，开始滚动拖拽
        -- 判断是在贡献榜区域还是下方内容区域
        local contribBot = 72 + (welfareState.contribFixedH or 0)
        if dy >= 72 and dy < contribBot then
            local cs = welfareState.contribScroll
            cs.isDragging = true
            cs.dragStartY = dy
            cs.dragLastY = dy
            cs.vel = 0
        else
            local ws = welfareState.scroll
            ws.isDragging = true
            ws.dragStartY = dy
            ws.dragLastY = dy
            ws.vel = 0
        end
        return
    end

    -- === 每日任务 / 成就 界面输入 ===
    if gameState.phase == "PROGRESS" then
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 返回按钮
        if HitRect(progressUIState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            return
        end
        -- Tab切换
        for i, r in ipairs(progressTabRects) do
            if HitRect(r) then
                progressUIState.tab = i
                progressUIState.scrollY = 0
                return
            end
        end
        -- 每日任务领取按钮
        if progressUIState.tab == 1 then
            for i, r in ipairs(dailyTaskBtnRects) do
                if HitRect(r) then
                    if ClaimDailyReward(i) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "任务奖励已领取!", 1.5, { 100, 255, 100 }, 18)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            -- 全勤奖励按钮
            if HitRect(dailyTaskAllBtnRect) then
                if ClaimDailyAllBonus() then
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 周任务领取按钮
        if progressUIState.tab == 2 then
            for i, r in ipairs(weeklyTaskBtnRects) do
                if HitRect(r) then
                    if ClaimWeeklyReward(i) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "周任务奖励已领取!", 1.5, { 100, 230, 255 }, 18)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
            -- 周全勤奖励按钮
            if HitRect(weeklyTaskAllBtnRect) then
                if ClaimWeeklyAllBonus() then
                    PlaySFX(AUDIO.sfx_click)
                end
                return
            end
        end
        -- 成就领取按钮
        if progressUIState.tab == 3 then
            for i, r in ipairs(progressUIState.achBtnRects or {}) do
                if HitRect(r) then
                    local origIdx = (progressUIState.achOrigIdx and progressUIState.achOrigIdx[i]) or i
                    if ClaimAchievement(origIdx) then
                        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "成就奖励已领取!", 1.5, { 255, 220, 80 }, 18)
                        PlaySFX(AUDIO.sfx_click)
                    end
                    return
                end
            end
        end
        -- 滚动拖拽
        progressUIState.isDragging = true
        progressUIState.dragStartY = dy
        progressUIState.dragLastY = dy
        progressUIState.scrollVel = 0
        return
    end

    -- === 个人资料界面输入 ===
    if gameState.phase == "DEV_EDITOR" then
        if phaseChangeCooldown > 0 then return end
        local dx, dy = ScreenToDesign(sx, sy)
        local function HitRect(r)
            return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
        end
        -- 返回按钮
        if HitRect(editorState.backBtnRect) then
            PopPhase("MENU")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- Tab切换
        for i, r in ipairs(editorState.tabRects) do
            if HitRect(r) then
                editorState.tab = i
                editorState.scrollY = 0
                editorState.scrollVel = 0
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- Tab 1: 关卡编辑
        if editorState.tab == 1 then
            -- 难度减少
            for si = 1, #STAGES do
                if HitRect(editorState.btnRects["stage_minus_" .. si]) then
                    local sOver = editorState.stageOverrides[si] or { enemyScale = STAGES[si].enemyScale }
                    sOver.enemyScale = math.max(0.1, (sOver.enemyScale or STAGES[si].enemyScale) - 0.1)
                    editorState.stageOverrides[si] = sOver
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                if HitRect(editorState.btnRects["stage_plus_" .. si]) then
                    local sOver = editorState.stageOverrides[si] or { enemyScale = STAGES[si].enemyScale }
                    sOver.enemyScale = math.min(10.0, (sOver.enemyScale or STAGES[si].enemyScale) + 0.1)
                    editorState.stageOverrides[si] = sOver
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                -- 点击关卡卡片选中
                if HitRect(editorState.btnRects["stage_" .. si]) then
                    editorState.selectedStage = si
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 重置全部难度
            if HitRect(editorState.btnRects["reset_stages"]) then
                editorState.stageOverrides = {}
                PlaySFX(AUDIO.sfx_click)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "已重置全部难度", 1.5, { 255, 200, 100 }, 18)
                return
            end
        end
        -- Tab 2: 战斗参数
        if editorState.tab == 2 then
            local params = {
                { key = "baseHpMax",        default = GameConfig.BASE_HP_MAX,       step = 50,   min = 100,  max = 5000 },
                { key = "initialGold",      default = GameConfig.INITIAL_GOLD,      step = 5,    min = 0,    max = 200 },
                { key = "battleTimeLimit",  default = GameConfig.BATTLE_TIME_LIMIT or 180, step = 15, min = 30, max = 600 },
            }
            for pi, p in ipairs(params) do
                if HitRect(editorState.btnRects["param_minus_" .. pi]) then
                    local curVal = editorState.overrides[p.key] or p.default
                    curVal = math.max(p.min, curVal - p.step)
                    editorState.overrides[p.key] = curVal
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
                if HitRect(editorState.btnRects["param_plus_" .. pi]) then
                    local curVal = editorState.overrides[p.key] or p.default
                    curVal = math.min(p.max, curVal + p.step)
                    editorState.overrides[p.key] = curVal
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 重置全部参数
            if HitRect(editorState.btnRects["reset_params"]) then
                editorState.overrides = {
                    baseHpMax = nil, initialGold = nil, enemySpawnCd = nil,
                    playerSpawnCd = nil, battleTimeLimit = nil, soldierStatScale = nil, deployCd = nil,
                }
                PlaySFX(AUDIO.sfx_click)
                AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, "已重置全部参数", 1.5, { 255, 200, 100 }, 18)
                return
            end
        end
        -- Tab 3: 快速测试
        if editorState.tab == 3 then
            -- 选择测试关卡
            for si = 1, #STAGES do
                if HitRect(editorState.btnRects["test_stage_" .. si]) then
                    editorState.testStage = si
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 开始测试战斗
            if HitRect(editorState.btnRects["start_test"]) then
                ApplyEditorOverrides()
                stageState.currentStage = editorState.testStage
                InitBattle()
                PushPhase("BATTLE")
                phaseChangeCooldown = 0.3
                PlaySFX(AUDIO.sfx_click)
                print("=== 编辑器: 开始测试关卡 " .. editorState.testStage .. " ===")
                return
            end
        end
        -- Tab 4: 石台编辑
        if editorState.tab == 4 then
            -- 导出复制按钮
            if HitRect(editorState.btnRects["slot_save"]) then
                ExportBattleLayouts()
                editorState.saveFlashT = os.clock()
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 撤销按钮
            if HitRect(editorState.btnRects["slot_undo"]) then
                if UndoSlotEdit() then
                    print("[布局编辑器] 撤销成功, 剩余 " .. #slotUndoStack .. " 步")
                end
                PlaySFX(AUDIO.sfx_click)
                return
            end
            -- 快捷选择按钮: 选我方 / 选敌方 / 清除选择
            if HitRect(editorState.btnRects["sel_player"]) then
                local lo = BATTLE_LAYOUTS[editorState.editLayoutIdx or 1]
                if lo then for pi = 1, #lo.playerSlots do editorState.selectedSlots["player_" .. pi] = true end end
                PlaySFX(AUDIO.sfx_click); return
            end
            if HitRect(editorState.btnRects["sel_enemy"]) then
                local lo = BATTLE_LAYOUTS[editorState.editLayoutIdx or 1]
                if lo then for ei = 1, #lo.enemySlots do editorState.selectedSlots["enemy_" .. ei] = true end end
                PlaySFX(AUDIO.sfx_click); return
            end
            if HitRect(editorState.btnRects["sel_clear"]) then
                editorState.selectedSlots = {}
                PlaySFX(AUDIO.sfx_click); return
            end
            -- 甯冨眬閫夋嫨
            for li = 1, #BATTLE_LAYOUTS do
                if HitRect(editorState.btnRects["layout_" .. li]) then
                    editorState.editLayoutIdx = li
                    editorState.slotDragging = false
                    editorState.selectedSlots = {}
                    PlaySFX(AUDIO.sfx_click)
                    return
                end
            end
            -- 石台圆圈按下 → 记录按下信息 (HandleMoveLogic 中判断是否拖拽)
            local lidx = editorState.editLayoutIdx or 1
            local layout = BATTLE_LAYOUTS[lidx]
            local sdx, sdy = ScreenToDesign(sx, sy)
            if layout then
                for ei = 1, #layout.enemySlots do
                    if HitRect(editorState.btnRects["eslot_" .. ei]) then
                        local key = "enemy_" .. ei
                        local wasSelected = editorState.selectedSlots[key] == true
                        editorState.selectedSlots[key] = true
                        editorState.slotPressKey = key
                        editorState.slotWasSelected = wasSelected
                        editorState.slotPressStartX = sdx
                        editorState.slotPressStartY = sdy
                        editorState.slotDragging = false
                        return
                    end
                end
                for pi = 1, #layout.playerSlots do
                    if HitRect(editorState.btnRects["pslot_" .. pi]) then
                        local key = "player_" .. pi
                        local wasSelected = editorState.selectedSlots[key] == true
                        editorState.selectedSlots[key] = true
                        editorState.slotPressKey = key
                        editorState.slotWasSelected = wasSelected
                        editorState.slotPressStartX = sdx
                        editorState.slotPressStartY = sdy
                        editorState.slotDragging = false
                        return
                    end
                end
            end
            -- 点击空白区域: 清除选择
            editorState.selectedSlots = {}
            return
        end
        -- 滚动拖拽
        editorState.isDragging = true
        editorState.dragStartY = dy
        editorState.dragLastY = dy
        editorState.scrollVel = 0
        return
    end

    return false  -- 未匹配任何 phase
end

return M
