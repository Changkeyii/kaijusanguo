-- ui/screens_result.lua - 三国武灵录 (从 screens.lua 拆分)
function DrawGameResultOverlay()
    if gameState.phase ~= "WIN" and gameState.phase ~= "LOSE" then return end
    if fontId < 0 then return end

    -- 渐入遮罩
    local fadeAlpha = math.min(1, gameState.resultTimer / 0.8)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(140 * fadeAlpha)))
    nvgFill(vg)

    local centerX = DESIGN_W / 2
    local centerY = BATTLE_ZONE.centerY

    nvgFontFaceId(vg, GetMainFont())
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if gameState.phase == "WIN" then
        -- 胜利: 金色光晕
        local pulse = 0.8 + 0.2 * math.sin(gameState.gameTime * 4)
        local glowR = 80 * fadeAlpha * pulse
        local glow = nvgRadialGradient(vg, centerX, centerY - 10, 10, glowR,
            nvgRGBA(255, 220, 80, math.floor(60 * fadeAlpha)),
            nvgRGBA(255, 200, 50, 0))
        nvgBeginPath(vg); nvgCircle(vg, centerX, centerY - 10, glowR)
        nvgFillPaint(vg, glow); nvgFill(vg)

        -- 大字
        nvgFontSize(vg, 63)
        nvgFillColor(vg, nvgRGBA(255, 230, 80, math.floor(255 * fadeAlpha)))
        nvgText(vg, centerX, centerY - 15, "大捷!", nil)

        -- 副文
        nvgFontSize(vg, 30)
        nvgFillColor(vg, nvgRGBA(255, 240, 180, math.floor(200 * fadeAlpha)))
        nvgText(vg, centerX, centerY + 20, "敌方阵地已被击破", nil)
    else
        -- 失败: 暗红光晕
        local pulse = 0.8 + 0.2 * math.sin(gameState.gameTime * 3)
        local glowR = 70 * fadeAlpha * pulse
        local glow = nvgRadialGradient(vg, centerX, centerY - 10, 10, glowR,
            nvgRGBA(255, 50, 30, math.floor(40 * fadeAlpha)),
            nvgRGBA(200, 30, 20, 0))
        nvgBeginPath(vg); nvgCircle(vg, centerX, centerY - 10, glowR)
        nvgFillPaint(vg, glow); nvgFill(vg)

        -- 大字
        nvgFontSize(vg, 63)
        nvgFillColor(vg, nvgRGBA(255, 80, 60, math.floor(255 * fadeAlpha)))
        nvgText(vg, centerX, centerY - 15, "败北...", nil)

        -- 副文
        nvgFontSize(vg, 30)
        nvgFillColor(vg, nvgRGBA(255, 160, 140, math.floor(200 * fadeAlpha)))
        nvgText(vg, centerX, centerY + 20, "我方阵地已被攻破", nil)
    end

    -- 战绩统计
    if fadeAlpha > 0.5 then
        local statAlpha = math.min(1, (fadeAlpha - 0.5) * 2)
        local statY = centerY + 50
        nvgFontSize(vg, 27)
        nvgFillColor(vg, nvgRGBA(220, 200, 130, math.floor(220 * statAlpha)))
        nvgText(vg, centerX, statY, "斩杀: " .. gameState.totalKills .. "   军资: " .. gameState.gold, nil)

        -- ★ 胜利奖励: 1秒后弹出大弹窗
        if gameState.phase == "WIN" then
            local rt = gameState.resultTimer or 0
            if rt > 1.0 and not gameState.showRewardPopup then
                gameState.showRewardPopup = true
                gameState.rewardPopupTimer = 0
                gameState.rewardScrollY = 0
                gameState.adDoubledReward = false  -- 重置广告翻倍状态
                -- 免广告卡自动翻倍奖励
                if IsBattleAdFree() then
                    WatchAdForDoubleReward()
                end
            end
        end

        -- LOSE时: 排位积分变化 或 广告获取虎符按钮
        if gameState.phase == "LOSE" and gameState.isRanked then
            -- 排位失败: 显示积分变化
            local rDelta = gameState.rankedDelta or 0
            local rTier = GetRankedTier(rankedState.score)
            local rColor = rTier.color
            local rdY = statY + 28
            nvgFontSize(vg, 40)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local deltaStr = rDelta .. " 分"
            nvgFillColor(vg, nvgRGBA(255, 120, 100, math.floor(240 * statAlpha)))
            nvgText(vg, centerX, rdY, deltaStr, nil)
            nvgFontSize(vg, 24)
            nvgFillColor(vg, nvgRGBA(rColor[1], rColor[2], rColor[3], math.floor(200 * statAlpha)))
            nvgText(vg, centerX, rdY + 30, rTier.name .. "  " .. rankedState.score .. "分", nil)
            -- 提示点击返回
            nvgFontSize(vg, 27)
            local retAlpha2 = math.floor(120 * statAlpha)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(retAlpha2 * 0.54)))
            nvgText(vg, centerX - 1, rdY + 70, "点击空白处返回", nil)
            nvgText(vg, centerX + 1, rdY + 70, "点击空白处返回", nil)
            nvgText(vg, centerX, rdY + 69, "点击空白处返回", nil)
            nvgText(vg, centerX, rdY + 71, "点击空白处返回", nil)
            nvgFillColor(vg, nvgRGBA(30, 25, 20, retAlpha2))
            nvgText(vg, centerX, rdY + 70, "点击空白处返回", nil)
        elseif gameState.phase == "LOSE" then
            local adBtnW = 140
            local adBtnH = 32
            local adBtnX = centerX - adBtnW / 2
            local adBtnY = statY + 22
            local adPulse = 0.7 + 0.3 * math.sin(gameState.gameTime * 4.0)
            nvgBeginPath(vg); nvgRoundedRect(vg, adBtnX, adBtnY, adBtnW, adBtnH, 6)
            nvgFillColor(vg, nvgRGBA(25, 50, 30, math.floor(200 * statAlpha * adPulse))); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, adBtnX, adBtnY, adBtnW, adBtnH, 6)
            nvgStrokeWidth(vg, 1)
            nvgStrokeColor(vg, nvgRGBA(80, 200, 100, math.floor(180 * statAlpha * adPulse))); nvgStroke(vg)
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(120, 255, 140, math.floor(240 * statAlpha * adPulse)))
            nvgText(vg, centerX, adBtnY + adBtnH / 2, "看广告 +" .. GameConfig.AD_REVIVE_BONUS_JADE .. "虎符", nil)
            adRects.revive = { x = adBtnX, y = adBtnY, w = adBtnW, h = adBtnH }

            -- 提示点击返回
            nvgFontSize(vg, 27)
            local retAlpha = math.floor(120 * statAlpha)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(retAlpha * 0.54)))
            nvgText(vg, centerX - 1, statY + 80, "点击空白处返回", nil)
            nvgText(vg, centerX + 1, statY + 80, "点击空白处返回", nil)
            nvgText(vg, centerX, statY + 79, "点击空白处返回", nil)
            nvgText(vg, centerX, statY + 81, "点击空白处返回", nil)
            nvgFillColor(vg, nvgRGBA(30, 25, 20, retAlpha))
            nvgText(vg, centerX, statY + 80, "点击空白处返回", nil)
        end
    end
end



-- ============================================================================
-- 胜利奖励大弹窗 (大捷1秒后弹出, 大面板可滑动)
-- ============================================================================
function DrawRewardPopup()
    if gameState.phase ~= "WIN" or not gameState.showRewardPopup then
        rewardPopupConfirmRect = nil
        rewardAdDoubleRect = nil
        return
    end

    local W = DESIGN_W
    local H = DESIGN_H
    local centerX = W / 2
    local t = gameState.gameTime

    -- 弹窗出现计时
    gameState.rewardPopupTimer = (gameState.rewardPopupTimer or 0)
    local popT = gameState.rewardPopupTimer
    local popAlpha = math.min(1, popT / 0.4)
    if popAlpha <= 0 then return end

    nvgFontFaceId(vg, GetMainFont())

    -- 半透明遮罩 (加深)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(120 * popAlpha)))
    nvgFill(vg)

    -- 弹窗面板 (大尺寸, 居中)
    local panelW = W - 60
    local panelH = H * 0.55
    local panelX = centerX - panelW / 2
    local panelY = H * 0.22
    -- 缩放动画
    local popScale = popT < 0.3 and (0.85 + 0.15 * (popT / 0.3)) or 1.0
    nvgSave(vg)
    nvgTranslate(vg, centerX, panelY + panelH / 2)
    nvgScale(vg, popScale, popScale)
    nvgTranslate(vg, -centerX, -(panelY + panelH / 2))

    -- 面板背景
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 14)
    nvgFillColor(vg, nvgRGBA(18, 22, 38, math.floor(245 * popAlpha))); nvgFill(vg)
    -- 金色边框
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 14)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 80, math.floor(200 * popAlpha)))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)
    -- 顶部高光
    local topGlow = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + 50,
        nvgRGBA(255, 220, 100, math.floor(30 * popAlpha)),
        nvgRGBA(255, 220, 100, 0))
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, 50, 14)
    nvgFillPaint(vg, topGlow); nvgFill(vg)

    -- 标题
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 45)
    nvgFillColor(vg, nvgRGBA(255, 225, 100, math.floor(255 * popAlpha)))
    nvgText(vg, centerX, panelY + 30, gameState.isRanked and "排位结算" or "战斗奖励", nil)
    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panelX + 20, panelY + 52)
    nvgLineTo(vg, panelX + panelW - 20, panelY + 52)
    nvgStrokeColor(vg, nvgRGBA(200, 170, 80, math.floor(80 * popAlpha)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- ★ 排位模式: 显示积分变化和段位信息
    if gameState.isRanked then
        local rDelta = gameState.rankedDelta or 0
        local rTier = GetRankedTier(rankedState.score)
        local rColor = rTier.color
        local contentY = panelY + 72

        -- 段位图标大圆
        local iconCx = centerX
        local iconCy = contentY + 40
        local iconR = 30
        nvgBeginPath(vg); nvgCircle(vg, iconCx, iconCy, iconR)
        nvgFillColor(vg, nvgRGBA(rColor[1], rColor[2], rColor[3], math.floor(60 * popAlpha))); nvgFill(vg)
        nvgBeginPath(vg); nvgCircle(vg, iconCx, iconCy, iconR)
        nvgStrokeColor(vg, nvgRGBA(rColor[1], rColor[2], rColor[3], math.floor(200 * popAlpha)))
        nvgStrokeWidth(vg, 2); nvgStroke(vg)
        nvgFontSize(vg, 32); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(rColor[1], rColor[2], rColor[3], math.floor(255 * popAlpha)))
        nvgText(vg, iconCx, iconCy, rTier.icon, nil)

        -- 段位名称
        nvgFontSize(vg, 34)
        nvgFillColor(vg, nvgRGBA(rColor[1], rColor[2], rColor[3], math.floor(240 * popAlpha)))
        nvgText(vg, centerX, iconCy + iconR + 22, rTier.name, nil)

        -- 积分变化（大号）
        local deltaY = iconCy + iconR + 60
        local deltaStr, deltaColor
        if rDelta > 0 then
            deltaStr = "+" .. rDelta .. " 分"
            deltaColor = { 100, 255, 140 }
        elseif rDelta < 0 then
            deltaStr = rDelta .. " 分"
            deltaColor = { 255, 120, 100 }
        else
            deltaStr = "+0 分"
            deltaColor = { 200, 200, 200 }
        end
        nvgFontSize(vg, 52)
        local deltaPulse = 0.85 + 0.15 * math.sin(t * 3)
        nvgFillColor(vg, nvgRGBA(deltaColor[1], deltaColor[2], deltaColor[3], math.floor(255 * popAlpha * deltaPulse)))
        nvgText(vg, centerX, deltaY, deltaStr, nil)

        -- 当前积分
        nvgFontSize(vg, 28)
        nvgFillColor(vg, nvgRGBA(200, 190, 160, math.floor(200 * popAlpha)))
        nvgText(vg, centerX, deltaY + 36, "当前积分: " .. rankedState.score, nil)

        -- 下一段位进度
        local nextTier = nil
        for i, ti in ipairs(RANKED_TIERS) do
            if ti.minScore > rankedState.score then
                nextTier = ti
                break
            end
        end
        if nextTier then
            local prevMin = rTier.minScore
            local progress = (rankedState.score - prevMin) / (nextTier.minScore - prevMin)
            progress = math.max(0, math.min(1, progress))
            local barW2 = panelW * 0.6
            local barH2 = 10
            local barX2 = centerX - barW2 / 2
            local barY2 = deltaY + 62
            nvgBeginPath(vg); nvgRoundedRect(vg, barX2, barY2, barW2, barH2, 5)
            nvgFillColor(vg, nvgRGBA(40, 40, 50, math.floor(200 * popAlpha))); nvgFill(vg)
            if progress > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, barX2, barY2, barW2 * progress, barH2, 5)
                nvgFillColor(vg, nvgRGBA(rColor[1], rColor[2], rColor[3], math.floor(220 * popAlpha))); nvgFill(vg)
            end
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(180, 170, 140, math.floor(180 * popAlpha)))
            nvgText(vg, centerX, barY2 + barH2 + 16, "距 " .. nextTier.name .. " 还需 " .. (nextTier.minScore - rankedState.score) .. " 分", nil)
        else
            nvgFontSize(vg, 26)
            nvgFillColor(vg, nvgRGBA(255, 200, 80, math.floor(200 * popAlpha)))
            nvgText(vg, centerX, deltaY + 62, "已达最高段位!", nil)
        end

        -- 战绩
        nvgFontSize(vg, 24)
        nvgFillColor(vg, nvgRGBA(160, 155, 140, math.floor(180 * popAlpha)))
        nvgText(vg, centerX, panelY + panelH - 90,
            "胜 " .. rankedState.wins .. "  负 " .. rankedState.losses .. "  连胜 " .. math.max(0, rankedState.streak), nil)

    else -- 非排位: 显示常规奖励列表

    -- 奖励列表区域 (可滚动)
    local listX = panelX + 16
    local listY = panelY + 62
    local listW = panelW - 32
    local listH = panelH - 130  -- 底部留给按钮
    local itemH = 80
    local itemGap = 10

    -- 收集所有奖励项
    local rewards = {}
    -- 虎符
    local jadeAmt = gameState.winJade or 0
    if jadeAmt > 0 then
        table.insert(rewards, { type = "jade", amount = jadeAmt })
    end
    -- 经验
    local expAmt = gameState.winExp or 0
    if expAmt > 0 then
        table.insert(rewards, { type = "exp", amount = expAmt })
    end
    -- 装备
    local eq = gameState.winEquip
    if eq then
        table.insert(rewards, { type = "equip", data = eq })
    end
    -- 武技残片
    local frags = gameState.winFragDrops
    if frags then
        for _, fd in ipairs(frags) do
            table.insert(rewards, { type = "frag", data = fd })
        end
    end

    local contentH = #rewards * (itemH + itemGap) - itemGap
    local scrollY = gameState.rewardScrollY or 0
    local maxScroll = 0
    local minScroll = math.min(0, -(contentH - listH))
    scrollY = math.max(minScroll, math.min(maxScroll, scrollY))
    gameState.rewardScrollY = scrollY

    -- 裁剪列表区域
    nvgSave(vg)
    nvgScissor(vg, listX, listY, listW, listH)

    for ri, rw in ipairs(rewards) do
        local iy = listY + (ri - 1) * (itemH + itemGap) + scrollY
        -- 延迟出现动画
        local itemDelay = (ri - 1) * 0.2
        local itemAlpha = math.min(1, math.max(0, (popT - 0.2 - itemDelay) / 0.3))
        if itemAlpha <= 0 then goto continue_reward end
        local ia = math.floor(240 * itemAlpha * popAlpha)

        -- 跳过不可见
        if iy + itemH < listY or iy > listY + listH then goto continue_reward end

        if rw.type == "jade" then
            -- 虎符奖励条
            nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 8)
            nvgFillColor(vg, nvgRGBA(35, 25, 55, ia)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 8)
            nvgStrokeColor(vg, nvgRGBA(180, 130, 255, math.floor(ia * 0.7)))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            -- 菱形图标
            nvgSave(vg)
            nvgTranslate(vg, listX + 36, iy + itemH / 2)
            nvgRotate(vg, math.rad(45))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, -14, -14, 28, 28, 4)
            nvgFillColor(vg, nvgRGBA(160, 100, 255, ia)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(210, 170, 255, ia)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            nvgRestore(vg)
            -- 文字 (标题左侧, 数量右侧, 水平排列)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 37)
            nvgFillColor(vg, nvgRGBA(210, 180, 255, ia))
            nvgText(vg, listX + 66, iy + itemH / 2, "虎符", nil)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 43)
            nvgFillColor(vg, nvgRGBA(230, 200, 255, ia))
            nvgText(vg, listX + listW - 16, iy + itemH / 2, "+" .. rw.amount, nil)

        elseif rw.type == "exp" then
            -- 经验奖励条
            nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 8)
            nvgFillColor(vg, nvgRGBA(45, 38, 18, ia)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 8)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 80, math.floor(ia * 0.7)))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            -- 星形图标
            nvgBeginPath(vg); nvgCircle(vg, listX + 36, iy + itemH / 2, 16)
            nvgFillColor(vg, nvgRGBA(255, 200, 50, ia)); nvgFill(vg)
            nvgBeginPath(vg); nvgCircle(vg, listX + 36, iy + itemH / 2, 10)
            nvgFillColor(vg, nvgRGBA(255, 240, 150, ia)); nvgFill(vg)
            -- 文字 (标题左侧, 数量右侧, 水平排列)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 37)
            nvgFillColor(vg, nvgRGBA(255, 230, 140, ia))
            nvgText(vg, listX + 66, iy + itemH / 2, "修为", nil)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 43)
            nvgFillColor(vg, nvgRGBA(255, 240, 180, ia))
            nvgText(vg, listX + listW - 16, iy + itemH / 2, "+" .. rw.amount, nil)

        elseif rw.type == "equip" then
            local eqData = rw.data
            local eqSet = EQUIPMENT_SETS[eqData.setIdx]
            local eqPiece = eqSet and eqSet.pieces[eqData.slotIdx]
            local eqTier = EQUIP_TIERS[eqData.tier or 1]
            if eqSet and eqPiece then
                local tc = eqTier.color
                local sc = eqSet.color
                local tierMul = eqTier.multiplier
                -- 装备奖励条
                nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 8)
                nvgFillColor(vg, nvgRGBA(25, 20, 15, ia)); nvgFill(vg)
                nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 8)
                nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], math.floor(ia * 0.8)))
                nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                -- 品质光晕
                local eqPulse = 0.7 + 0.3 * math.sin(t * 4)
                local eqGlow = nvgBoxGradient(vg, listX, iy, listW, itemH, 8, 12,
                    nvgRGBA(tc[1], tc[2], tc[3], math.floor(25 * eqPulse * itemAlpha)),
                    nvgRGBA(tc[1], tc[2], tc[3], 0))
                nvgBeginPath(vg); nvgRoundedRect(vg, listX - 2, iy - 2, listW + 4, itemH + 4, 10)
                nvgFillPaint(vg, eqGlow); nvgFill(vg)
                -- 装备图标
                if IMG.equipmentSheet and IMG.equipmentSheet > 0 then
                    local iconS = 48
                    DrawCardImage(listX + 12, iy + (itemH - iconS) / 2, iconS, iconS,
                        IMG.equipmentSheet, eqData.slotIdx - 1, eqData.setIdx - 1, EQUIP_SHEET_COLS, EQUIP_SHEET_ROWS)
                end
                -- 阶级标签
                nvgBeginPath(vg); nvgRoundedRect(vg, listX + 12, iy + 6, 36, 18, 4)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], ia)); nvgFill(vg)
                nvgFontSize(vg, 27); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, ia))
                nvgText(vg, listX + 30, iy + 15, eqTier.name, nil)
                -- 装备名称
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFontSize(vg, 35)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], ia))
                nvgText(vg, listX + 68, iy + 24, eqPiece.name, nil)
                -- 套装名
                nvgFontSize(vg, 29)
                nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], math.floor(ia * 0.7)))
                nvgText(vg, listX + 68, iy + 50, eqSet.name, nil)
                -- 属性
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFontSize(vg, 27)
                nvgFillColor(vg, nvgRGBA(160, 220, 160, math.floor(ia * 0.8)))
                nvgText(vg, listX + listW - 12, iy + itemH / 2,
                    string.format("ATK+%d%% DEF+%d%% HP+%d%%",
                        math.ceil((eqPiece.atkPct or 0) * tierMul),
                        math.ceil((eqPiece.defPct or 0) * tierMul),
                        math.ceil((eqPiece.hpPct or 0) * tierMul)), nil)
            end

        elseif rw.type == "frag" then
            local fd = rw.data
            local tc = fd.tierColor or { 180, 160, 255 }
            -- 残片奖励条
            nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 8)
            nvgFillColor(vg, nvgRGBA(20, 15, 35, ia)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 8)
            nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], math.floor(ia * 0.7)))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            -- 残片图标（六边形）
            local cx, cy = listX + 36, iy + itemH / 2
            nvgBeginPath(vg)
            for k = 0, 5 do
                local ang = math.rad(60 * k - 90)
                local px = cx + 15 * math.cos(ang)
                local py = cy + 15 * math.sin(ang)
                if k == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
            end
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], ia)); nvgFill(vg)
            -- 内部小六边形
            nvgBeginPath(vg)
            for k = 0, 5 do
                local ang = math.rad(60 * k - 90)
                local px = cx + 8 * math.cos(ang)
                local py = cy + 8 * math.sin(ang)
                if k == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
            end
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(ia * 0.6))); nvgFill(vg)
            -- 阶级标签
            nvgBeginPath(vg); nvgRoundedRect(vg, listX + 12, iy + 6, 36, 18, 4)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], ia)); nvgFill(vg)
            nvgFontSize(vg, 25); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, ia))
            nvgText(vg, listX + 30, iy + 15, fd.tierName or "", nil)
            -- 武技名称
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 33)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], ia))
            nvgText(vg, listX + 66, iy + itemH / 2, fd.skillName or "武技", nil)
            -- +1 残片
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 37)
            nvgFillColor(vg, nvgRGBA(200, 180, 255, ia))
            nvgText(vg, listX + listW - 16, iy + itemH / 2, "+1 残片", nil)
        end
        ::continue_reward::
    end

    nvgRestore(vg)  -- 列表裁剪

    -- 列表滚动条
    if contentH > listH then
        local barH = math.max(20, listH * (listH / contentH))
        local barRange = listH - barH
        local barRatio = scrollY / math.min(minScroll, -1)
        local barY = listY + barRange * barRatio
        nvgBeginPath(vg); nvgRoundedRect(vg, listX + listW - 4, barY, 3, barH, 1.5)
        nvgFillColor(vg, nvgRGBA(200, 180, 120, math.floor(80 * popAlpha))); nvgFill(vg)
    end

    end -- if gameState.isRanked / else

    -- 底部按钮区域
    local btnH = 50
    local btnY = panelY + panelH - 65
    local btnPulse = 0.85 + 0.15 * math.sin(t * 3)
    local adAvailable = not gameState.adDoubledReward and (gameState.winJade or 0) > 0 and not IsBattleAdFree()

    if adAvailable then
        -- 双按钮布局: 确认(左) + 看广告翻倍(右)
        local gap = 12
        local btnW = (panelW - 40 - gap) / 2
        local btnX1 = panelX + 20
        local btnX2 = btnX1 + btnW + gap

        -- 确认按钮 (左, 次要样式)
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX1, btnY, btnW, btnH, 10)
        nvgFillColor(vg, nvgRGBA(60, 50, 40, math.floor(220 * popAlpha))); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX1, btnY, btnW, btnH, 10)
        nvgStrokeColor(vg, nvgRGBA(180, 160, 100, math.floor(150 * popAlpha)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 33)
        nvgFillColor(vg, nvgRGBA(200, 190, 160, math.floor(220 * popAlpha)))
        nvgText(vg, btnX1 + btnW / 2, btnY + btnH / 2, "确 认", nil)
        rewardPopupConfirmRect = { x = btnX1, y = btnY, w = btnW, h = btnH }

        -- 看广告翻倍按钮 (右, 高亮样式, 呼吸动画)
        local adGrad = nvgLinearGradient(vg, btnX2, btnY, btnX2, btnY + btnH,
            nvgRGBA(80, 200, 120, math.floor(240 * popAlpha * btnPulse)),
            nvgRGBA(50, 160, 80, math.floor(240 * popAlpha * btnPulse)))
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY, btnW, btnH, 10)
        nvgFillPaint(vg, adGrad); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY, btnW, btnH, 10)
        nvgStrokeColor(vg, nvgRGBA(150, 255, 180, math.floor(200 * popAlpha)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        -- 光晕效果
        local adGlow = nvgBoxGradient(vg, btnX2, btnY, btnW, btnH, 10, 8,
            nvgRGBA(100, 255, 150, math.floor(30 * btnPulse * popAlpha)),
            nvgRGBA(100, 255, 150, 0))
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX2 - 3, btnY - 3, btnW + 6, btnH + 6, 12)
        nvgFillPaint(vg, adGlow); nvgFill(vg)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 30)
        nvgFillColor(vg, nvgRGBA(255, 255, 240, math.floor(255 * popAlpha)))
        nvgText(vg, btnX2 + btnW / 2, btnY + btnH / 2, "广告x2", nil)
        rewardAdDoubleRect = { x = btnX2, y = btnY, w = btnW, h = btnH }
    else
        -- 单按钮: 确认 (广告已用或已翻倍)
        local btnW = 200
        local btnX = centerX - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 10)
        local btnGrad = nvgLinearGradient(vg, btnX, btnY, btnX, btnY + btnH,
            nvgRGBA(180, 140, 50, math.floor(240 * popAlpha * btnPulse)),
            nvgRGBA(140, 100, 30, math.floor(240 * popAlpha * btnPulse)))
        nvgFillPaint(vg, btnGrad); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 10)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 120, math.floor(180 * popAlpha)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 37)
        nvgFillColor(vg, nvgRGBA(255, 250, 230, math.floor(255 * popAlpha)))
        nvgText(vg, centerX, btnY + btnH / 2, "确 认", nil)
        rewardPopupConfirmRect = { x = btnX, y = btnY, w = btnW, h = btnH }
        rewardAdDoubleRect = nil
    end

    nvgRestore(vg)  -- 缩放动画
end


function DrawExploreExitConfirmPopup()
    if not gameState.exploreExitConfirm then
        exploreConfirmBtnRects = {}
        return
    end

    local confirmType = gameState.exploreExitConfirm.type
    local W = DESIGN_W
    local H = DESIGN_H
    local centerX = W / 2

    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())

    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180)); nvgFill(vg)

    -- 弹窗面板
    local panelW = 340
    local panelH = confirmType == "death" and 250 or 170
    local panelX = centerX - panelW / 2
    local panelY = H * 0.35

    -- 面板背景
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 12)
    nvgFillColor(vg, nvgRGBA(22, 18, 28, 240)); nvgFill(vg)
    -- 边框
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, panelH, 12)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 80, 160))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    -- 顶部高光
    local topGlow = nvgLinearGradient(vg, panelX, panelY, panelX, panelY + 40,
        nvgRGBA(255, 200, 80, 25), nvgRGBA(255, 200, 80, 0))
    nvgBeginPath(vg); nvgRoundedRect(vg, panelX, panelY, panelW, 40, 12)
    nvgFillPaint(vg, topGlow); nvgFill(vg)

    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题
    local titleY = panelY + 32
    nvgFontSize(vg, 28)
    if confirmType == "death" then
        nvgFillColor(vg, nvgRGBA(255, 80, 60, 255))
        nvgText(vg, centerX, titleY, "战斗失败", nil)
    else
        nvgFillColor(vg, nvgRGBA(255, 200, 100, 255))
        nvgText(vg, centerX, titleY, "确认退出?", nil)
    end

    -- 说明文字
    nvgFontSize(vg, 17)
    nvgFillColor(vg, nvgRGBA(200, 180, 140, 220))
    if confirmType == "abyss_exit" then
        nvgText(vg, centerX, titleY + 38, "退出讨伐将保留30%收获", nil)
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(180, 160, 120, 180))
        nvgText(vg, centerX, titleY + 56, "返回讨伐战页面", nil)
    else
        nvgText(vg, centerX, titleY + 38, "将丢失10%~30%已获得的战利品", nil)
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(180, 160, 120, 180))
        nvgText(vg, centerX, titleY + 56, "并回到探索副本地图中", nil)
    end

    -- 广告翻倍虎符按钮 (仅撤离结算时显示, 退出确认弹窗不显示)
    exploreConfirmBtnRects.adDouble = nil

    -- 底部按钮区域
    local btnW = 130
    local btnH = 38
    local btnY = panelY + panelH - 55
    local adPulse = 0.7 + 0.3 * math.sin(gameState.gameTime * 4.0)

    if confirmType == "death" then
        -- 双按钮: 确认 (左) + 看广告复活 (右)
        local gap = 16
        local totalW = btnW * 2 + gap
        local btn1X = centerX - totalW / 2
        local btn2X = btn1X + btnW + gap

        -- 确认按钮 (暗红色)
        nvgBeginPath(vg); nvgRoundedRect(vg, btn1X, btnY, btnW, btnH, 8)
        nvgFillColor(vg, nvgRGBA(80, 30, 25, 220)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, btn1X, btnY, btnW, btnH, 8)
        nvgStrokeColor(vg, nvgRGBA(180, 80, 60, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 180, 160, 240))
        nvgText(vg, btn1X + btnW / 2, btnY + btnH / 2, "确 认", nil)

        -- 看广告复活按钮 (绿色脉冲)
        nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, btnY, btnW, btnH, 8)
        nvgFillColor(vg, nvgRGBA(25, 60, 35, math.floor(220 * adPulse))); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, btn2X, btnY, btnW, btnH, 8)
        nvgStrokeColor(vg, nvgRGBA(80, 220, 120, math.floor(200 * adPulse)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(120, 255, 150, math.floor(255 * adPulse)))
        nvgText(vg, btn2X + btnW / 2, btnY + btnH / 2, "看广告复活", nil)

        exploreConfirmBtnRects.confirm = { x = btn1X, y = btnY, w = btnW, h = btnH }
        exploreConfirmBtnRects.revive  = { x = btn2X, y = btnY, w = btnW, h = btnH }
    else
        -- 单按钮: 确认
        local btnX = centerX - btnW / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 8)
        nvgFillColor(vg, nvgRGBA(60, 45, 20, 220)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 8)
        nvgStrokeColor(vg, nvgRGBA(200, 170, 80, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(255, 230, 160, 240))
        nvgText(vg, centerX, btnY + btnH / 2, "确 认", nil)

        exploreConfirmBtnRects.confirm = { x = btnX, y = btnY, w = btnW, h = btnH }
    end

    nvgRestore(vg)
end


-- ============================================================================
-- 关卡选择界面
-- ============================================================================
