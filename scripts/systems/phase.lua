-- ============================================================================
-- systems/phase.lua - 三国武灵录
-- ============================================================================

phaseHistory = phaseHistory or {}

function PushPhase(newPhase)
    if gameState.phase and gameState.phase ~= newPhase then
        table.insert(phaseHistory, gameState.phase)
        -- 保持历史栈不超过20层
        if #phaseHistory > 20 then table.remove(phaseHistory, 1) end
    end
    gameState.phase = newPhase
end

function PopPhase(fallback)
    local prevPhase = gameState.phase
    if #phaseHistory > 0 then
        gameState.phase = table.remove(phaseHistory)
    else
        gameState.phase = fallback or "MENU"
    end
    -- 离开兵甲界面时自动隐藏正式UI
    if prevPhase == "EQUIP" and gameState.phase ~= "EQUIP" then
        EquipUI.Hide()
    end
end

function UpdateBGM()
    local phase = gameState.phase
    if phase == prevPhaseForBGM then return end
    prevPhaseForBGM = phase
    if phase == "BATTLE" then
        PlayBGM(AUDIO.bgm_battle)
    else
        PlayBGM(AUDIO.bgm_menu)
    end
end
