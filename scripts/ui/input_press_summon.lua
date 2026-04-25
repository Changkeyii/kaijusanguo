-- ============================================================================
-- ui/input_press_summon.lua - 召唤系统点击处理
-- 用途: BeginPress 子处理器 - SUMMON phase
-- 依赖: 全局变量 (gameState, ScreenToDesign, summonTab, heroGachaState, sealGachaState 等)
-- 导出: M.handle(sx, sy, touchId) -> boolean
-- [TECH_DEBT] 全局变量模式: 延续 input 模块的全局状态设计
-- ============================================================================

---@diagnostic disable: undefined-global

local M = {}

--- 处理 SUMMON phase 的点击事件
---@param sx number 屏幕坐标X
---@param sy number 屏幕坐标Y
---@param touchId number 触摸ID
function M.handle(sx, sy, touchId)
    if gameState.phase ~= "SUMMON" then return end
    if phaseChangeCooldown > 0 then return end

    local dx, dy = ScreenToDesign(sx, sy)
    local function HitRect(r)
        return r and dx >= r.x and dx <= r.x + r.w and dy >= r.y and dy <= r.y + r.h
    end

    -- ========== 优先: 弹窗层输入 (规则弹窗、结果确认) ==========

    -- 兵符召唤 - 规则弹窗关闭
    if summonTab == 1 and sealGachaState.showRules then
        if HitRect(gachaRulesCloseBtnRect) then
            sealGachaState.showRules = false
            PlaySFX(AUDIO.sfx_click)
        end
        return  -- 弹窗模态, 吞掉所有点击
    end

    -- 武将召唤 - 规则弹窗关闭
    if summonTab == 2 and heroGachaState.showRules then
        if HitRect(heroGachaRulesCloseBtnRect) then
            heroGachaState.showRules = false
            PlaySFX(AUDIO.sfx_click)
        end
        return  -- 弹窗模态, 吞掉所有点击
    end

    -- 武技召唤 - 规则弹窗关闭
    if summonTab == 3 and skillGachaState.showRules then
        if HitRect(skillGachaRulesCloseBtnRect) then
            skillGachaState.showRules = false
            PlaySFX(AUDIO.sfx_click)
        end
        return  -- 弹窗模态, 吞掉所有点击
    end

    -- 兵符召唤 - 结果确认
    if summonTab == 1 and sealGachaState.showResults then
        if HitRect(gachaConfirmBtnRect) then
            sealGachaState.showResults = false
            sealGachaState.results = {}
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- 武将召唤 - 结果确认
    if summonTab == 2 and heroGachaState.showResults then
        if HitRect(heroGachaConfirmBtnRect) then
            heroGachaState.showResults = false
            heroGachaState.results = {}
            heroGachaState._resultsSorted = false
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- 武技召唤 - 结果确认
    if summonTab == 3 and skillGachaState.showResults then
        if HitRect(skillGachaConfirmBtnRect) then
            skillGachaState.showResults = false
            skillGachaState.results = {}
            skillGachaState._resultsSorted = false
            PlaySFX(AUDIO.sfx_click)
        end
        return
    end

    -- 兵符召唤 - 抽卡动画跳过
    if summonTab == 1 and sealGachaState.pulling then
        sealGachaState.pulling = false
        sealGachaState.showResults = true
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 武将召唤 - 抽卡动画跳过
    if summonTab == 2 and heroGachaState.pulling then
        heroGachaState.pulling = false
        heroGachaState.showResults = true
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- 武技召唤 - 抽卡动画跳过
    if summonTab == 3 and skillGachaState.pulling then
        skillGachaState.pulling = false
        skillGachaState.showResults = true
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- ========== 帮助按钮 ==========
    if HitRect(helpBtnRect) then
        ShowHelp("SUMMON")
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- ========== 返回按钮 ==========
    if HitRect(summonBackBtnRect) then
        PopPhase("MENU")
        phaseChangeCooldown = 0.3
        PlaySFX(AUDIO.sfx_click)
        return
    end

    -- ========== 页签切换 ==========
    for i, tr in ipairs(summonTabRects) do
        if HitRect(tr) then
            if summonTab ~= i then
                summonTab = i
                PlaySFX(AUDIO.sfx_click)
            end
            return
        end
    end

    -- ========== 页签内容区域按钮 ==========
    if summonTab == 1 then
        -- 兵符召唤按钮
        local bigPull = playerInfo.jadeUnlockedBigPull
        if bigPull then
            -- 增强模式: gachaSingleBtnRect=10连, gachaTenBtnRect=50连, gachaHundredBtnRect=100连
            if HitRect(gachaSingleBtnRect) then
                ExecuteSealGachaPull(10)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(gachaTenBtnRect) then
                ExecuteSealGachaPull(50)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(gachaHundredBtnRect) then
                ExecuteSealGachaPull(100)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        else
            -- 标准模式: 单抽/十连
            if HitRect(gachaSingleBtnRect) then
                ExecuteSealGachaPull(1)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(gachaTenBtnRect) then
                ExecuteSealGachaPull(10)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 兵符管理入口
        if HitRect(sealMgrBtnRect) then
            PushPhase("SEAL_MGR")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 规则按钮
        if HitRect(gachaRulesBtnRect) then
            sealGachaState.showRules = true
            PlaySFX(AUDIO.sfx_click)
            return
        end

    elseif summonTab == 2 then
        -- 武将召唤按钮
        local bigPull = playerInfo.jadeUnlockedBigPull
        if bigPull then
            -- 增强模式: heroGachaSingleBtnRect=10连, heroGachaTenBtnRect=50连, heroGachaHundredBtnRect=100连
            if HitRect(heroGachaSingleBtnRect) then
                ExecuteHeroGachaPull(10)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(heroGachaTenBtnRect) then
                ExecuteHeroGachaPull(50)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(heroGachaHundredBtnRect) then
                ExecuteHeroGachaPull(100)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        else
            -- 标准模式: 单抽/十连
            if HitRect(heroGachaSingleBtnRect) then
                ExecuteHeroGachaPull(1)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(heroGachaTenBtnRect) then
                ExecuteHeroGachaPull(10)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 武将录入口
        if HitRect(heroGachaCodexBtnRect) then
            PushPhase("CODEX")
            phaseChangeCooldown = 0.3
            PlaySFX(AUDIO.sfx_click)
            return
        end
        -- 规则按钮
        if HitRect(heroGachaRulesBtnRect) then
            heroGachaState.showRules = true
            PlaySFX(AUDIO.sfx_click)
            return
        end

    elseif summonTab == 3 then
        -- 武技召唤按钮
        local bigPull = playerInfo.jadeUnlockedBigPull
        if bigPull then
            -- 增强模式: skillGachaSingleBtnRect=10连, skillGachaTenBtnRect=50连, skillGachaHundredBtnRect=100连
            if HitRect(skillGachaSingleBtnRect) then
                ExecuteSkillGachaPull(10)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(skillGachaTenBtnRect) then
                ExecuteSkillGachaPull(50)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(skillGachaHundredBtnRect) then
                ExecuteSkillGachaPull(100)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        else
            -- 标准模式: 单抽/十连
            if HitRect(skillGachaSingleBtnRect) then
                ExecuteSkillGachaPull(1)
                PlaySFX(AUDIO.sfx_click)
                return
            end
            if HitRect(skillGachaTenBtnRect) then
                ExecuteSkillGachaPull(10)
                PlaySFX(AUDIO.sfx_click)
                return
            end
        end
        -- 规则按钮
        if HitRect(skillGachaRulesBtnRect) then
            skillGachaState.showRules = true
            PlaySFX(AUDIO.sfx_click)
            return
        end
    end
end

return M
