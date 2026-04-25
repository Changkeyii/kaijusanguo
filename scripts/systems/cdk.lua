-- ============================================================================
-- systems/cdk.lua - 三国武灵录
-- ============================================================================


--- CDK 兑换逻辑
function TryRedeemCDK()
    -- 清理输入：去除空格和不可见字符，统一大写
    local code = cdkState.inputText:gsub("%s+", ""):gsub("[^A-Za-z0-9%-]", ""):upper()
    cdkState.inputText = code  -- 回写清理后的文本
    if #code == 0 then
        cdkState.resultText = "请输入兑换码"
        cdkState.resultOk = false
        cdkState.resultTimer = 2.5
        return
    end
    -- 检查码是否存在
    local reward = cdkState.codes[code]
    if not reward then
        cdkState.resultText = "无效的兑换码"
        cdkState.resultOk = false
        cdkState.resultTimer = 2.5
        return
    end
    -- 检查是否已兑换（infinite 码可无限兑换）
    if cdkState.redeemed[code] and not reward.infinite then
        cdkState.resultText = "该兑换码已使用"
        cdkState.resultOk = false
        cdkState.resultTimer = 2.5
        return
    end
    -- 发放奖励
    if reward.jade then playerInfo.jade = playerInfo.jade + reward.jade end
    if reward.frag then
        for hid, hero in pairs(playerHeroes) do
            if hero.owned then
                skillFragments[hid] = (skillFragments[hid] or 0) + reward.frag
            end
        end
    end
    if reward.unlockAllHeroes then
        for i = 1, 40 do
            if not playerHeroes[i] then
                playerHeroes[i] = { owned = true, constellation = 0 }
            end
        end
    end
    if reward.unlockAllSkills then
        for i = 1, 40 do
            if not skillLayers[i] then skillLayers[i] = 1 end
        end
    end
    if reward.unlockAllTierWeapons then
        -- 每个品阶各给一把武器(slotIdx=1)，随机套装，品质100
        for tier = 1, #EQUIP_TIERS do
            local si = math.random(1, #EQUIPMENT_SETS)
            CreateEquipItem(si, 1, tier, 100, tier * 5)
        end
    end
    if reward.unlockAllTopGear then
        -- 7套 x 7件，全部帝品(tier6)、品质100、满级30
        for setIdx = 1, #EQUIPMENT_SETS do
            for slotIdx = 1, 7 do
                CreateEquipItem(setIdx, slotIdx, 6, 100, 30)
            end
        end
    end
    if reward.clearAll then
        -- 清除全部装备
        playerEquipment.owned = {}
        playerEquipment.equipped = {}
        playerEquipment.nextUid = 1
        -- 清除交易行上架记录
        if TradeManager and TradeManager.ClearAllListings then
            TradeManager.ClearAllListings()
        elseif playerInfo and playerInfo.tradeData then
            playerInfo.tradeData.listings = {}
        end
        -- 清除全部武灵（保留初始武灵结构但重置为未拥有）
        for hid, _ in pairs(playerHeroes) do
            playerHeroes[hid] = nil
        end
        -- 恢复初始武灵
        for _, idx in ipairs(GameConfig.INITIAL_HEROES) do
            playerHeroes[idx] = { owned = true, constellation = 0 }
        end
        -- 清除武技
        for k in pairs(skillLayers) do skillLayers[k] = nil end
        -- 清除武技残片
        for k in pairs(skillFragments) do skillFragments[k] = nil end
        -- 清除武灵残片
        for k in pairs(heroFragments) do heroFragments[k] = nil end
        -- 重置出战武灵槽位
        for _, slot in ipairs(PLAYER_SLOTS) do
            slot.filled = false
            slot.card = nil
        end
        print("[CDK] 已清除全部装备和武灵")
    end
    -- 标记已兑换（infinite 码不标记）
    if not reward.infinite then cdkState.redeemed[code] = true end
    cdkState.resultText = "兑换成功! 获得 " .. reward.desc
    cdkState.resultOk = true
    cdkState.resultTimer = 3.0
    cdkState.inputText = ""
    -- 立即保存防丢档
    SaveGameProgress()
    SaveSettings()
    PlaySFX(AUDIO.sfx_coin)
    print("[CDK] 兑换成功: " .. code .. " → " .. reward.desc)
end
