-- ============================================================================
-- ui/seal_manager.lua - 三国武灵录 (兵符管理: 升级/替换/分解)
-- ============================================================================
-- ============================================================================
-- 兵符管理界面 - 查看/升级兵符 (正式版: 卡牌居中 + 六德环绕)
-- ============================================================================
function DrawSealMgrScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = menuAnimTimer

    -- 背景
    DrawSocialBg(W, H)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(12, 6, 24, 80)); nvgFill(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 清空点击区域
    sealMgrHeroRects = {}
    sealMgrSlotRects = {}
    sealMgrExpItemRects = {}

    -- ============ 顶部栏 ============
    local topBarY = 14
    local backW, backH = 100, 40
    local backX = 12
    nvgBeginPath(vg); nvgRoundedRect(vg, backX, topBarY, backW, backH, 4)
    nvgFillColor(vg, nvgRGBA(20, 15, 35, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 80, 220, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(backX + backW / 2, topBarY + backH / 2, "< 返回")
    sealMgrBtnRects.back = { x = backX, y = topBarY, w = backW, h = backH }

    nvgFontSize(vg, 36)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, topBarY + backH / 2, "兵符管理")
    DrawHelpBtn(DESIGN_W - 14 - 30, topBarY + (backH - 30) / 2, 30)

    -- 仓库入口按钮
    local invBtnW, invBtnH = 80, 40
    local invBtnX = DESIGN_W - 14 - 30 - 10 - invBtnW
    local invBtnY = topBarY + (backH - invBtnH) / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, invBtnX, invBtnY, invBtnW, invBtnH, 4)
    nvgFillColor(vg, nvgRGBA(30, 55, 85, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(70, 140, 210, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(invBtnX + invBtnW / 2, invBtnY + invBtnH / 2, "仓库")
    sealMgrBtnRects.inventoryBtn = { x = invBtnX, y = invBtnY, w = invBtnW, h = invBtnH }
    -- 仓库数量角标
    if #sealInventory > 0 then
        local badgeR = 10
        local badgeX = invBtnX + invBtnW - 4
        local badgeY = invBtnY
        nvgBeginPath(vg); nvgCircle(vg, badgeX, badgeY, badgeR)
        nvgFillColor(vg, nvgRGBA(200, 50, 50, 240)); nvgFill(vg)
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, badgeX, badgeY, tostring(#sealInventory), nil)
    end

    -- ============ 筛选分解 + 选中分解 按钮 (仓库按钮左侧) ============
    sealInvFilterBtnRects.batchDecompBtn = nil
    sealInvFilterBtnRects.selectDecompBtn = nil
    if #sealInventory > 0 and not sealInvFilterState.selectMode then
        local dbtnW, dbtnH = 88, 36
        local dbtnGap = 6
        local dbtn1X = invBtnX - dbtnGap - dbtnW
        local dbtnY = topBarY + (backH - dbtnH) / 2
        -- 筛选分解
        nvgBeginPath(vg); nvgRoundedRect(vg, dbtn1X, dbtnY, dbtnW, dbtnH, 4)
        nvgFillColor(vg, nvgRGBA(110, 40, 40, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 80, 80, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(dbtn1X + dbtnW / 2, dbtnY + dbtnH / 2, "筛选分解")
        sealInvFilterBtnRects.batchDecompBtn = { x = dbtn1X, y = dbtnY, w = dbtnW, h = dbtnH }
        -- 选中分解
        local dbtn2X = dbtn1X - dbtnGap - dbtnW
        nvgBeginPath(vg); nvgRoundedRect(vg, dbtn2X, dbtnY, dbtnW, dbtnH, 4)
        nvgFillColor(vg, nvgRGBA(40, 60, 100, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 140, 200, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 24)
        DrawWhiteInkText(dbtn2X + dbtnW / 2, dbtnY + dbtnH / 2, "选中分解")
        sealInvFilterBtnRects.selectDecompBtn = { x = dbtn2X, y = dbtnY, w = dbtnW, h = dbtnH }
    end

    -- ============ 获取满命武灵 ============
    local maxHeroes = GetMaxConstellationHeroes()

    -- 自动选择第一个英雄
    if not sealMgrState.selectedHero and #maxHeroes > 0 then
        sealMgrState.selectedHero = maxHeroes[1].cardIdx
    end

    -- ============ 选中分解模式: 全屏仓库列表 ============
    if sealInvFilterState.selectMode then
        DrawSealSelectModeList()

        -- 选中分解确认弹窗
        if sealInvFilterState.selectConfirmShow then
            DrawSealSelectDecompConfirm()
        end

        -- 筛选分解确认弹窗（理论上不会在选中模式出现，但保险）
        if sealInvFilterState.batchConfirmShow then
            DrawSealBatchDecompConfirm()
        end
        return
    end

    -- ============ 布局参数 ============
    local cardH = 165
    local cardW = math.floor(cardH * CARD_RATIO)
    local cardCX = cx                    -- 卡牌中心X
    local cardCY = topBarY + backH + 220 -- 卡牌中心Y
    local cardX = cardCX - cardW / 2
    local cardY = cardCY - cardH / 2
    local orbitR = 155                   -- 兵符环绕半径

    -- 六条连线的卡牌锚点 (卡牌边缘不同位置)
    -- 顺序: 贪欲(上), 嗔欲(右上), 痴欲(右下), 慢欲(下), 疑欲(左下), 邪欲(左上)
    local cardAnchors = {
        { x = cardCX,              y = cardY - 2 },              -- 1 贪欲: 顶部中央
        { x = cardX + cardW + 2,   y = cardY + cardH * 0.25 },   -- 2 嗔欲: 右侧偏上
        { x = cardX + cardW + 2,   y = cardY + cardH * 0.75 },   -- 3 痴欲: 右侧偏下
        { x = cardCX,              y = cardY + cardH + 2 },       -- 4 慢欲: 底部中央
        { x = cardX - 2,           y = cardY + cardH * 0.75 },    -- 5 疑欲: 左侧偏下
        { x = cardX - 2,           y = cardY + cardH * 0.25 },    -- 6 邪欲: 左侧偏上
    }

    if sealMgrState.selectedHero then
        local cardIdx = sealMgrState.selectedHero
        local card = HERO_CARDS[cardIdx]
        local sd = sealData[cardIdx]
        local heroQ = card and card.quality or 1
        local qc = QUALITY_COLORS[heroQ] or { 200, 200, 200 }
        local hero = playerHeroes[cardIdx]
        local constellation = hero and hero.constellation or 0
        local slotCount = GetSealSlotCount(cardIdx)

        -- ========== 1. 底层装饰: 轨道环 ==========
        -- 外环 (缓慢脉冲)
        local outerPulse = 0.3 + 0.15 * math.sin(t * 0.6)
        nvgBeginPath(vg)
        nvgCircle(vg, cardCX, cardCY, orbitR + 12)
        nvgStrokeColor(vg, nvgRGBA(100, 50, 180, math.floor(50 * outerPulse)))
        nvgStrokeWidth(vg, 1.0)
        nvgStroke(vg)

        -- 主轨道环 (呼吸)
        local mainPulse = 0.5 + 0.3 * math.sin(t * 0.9)
        nvgBeginPath(vg)
        nvgCircle(vg, cardCX, cardCY, orbitR)
        nvgStrokeColor(vg, nvgRGBA(140, 80, 220, math.floor(40 * mainPulse)))
        nvgStrokeWidth(vg, 0.7)
        nvgStroke(vg)

        -- 旋转刻度标记 (12个小点，缓慢旋转)
        local rotAngle = t * 0.15
        for i = 0, 11 do
            local da = (i / 12) * math.pi * 2 + rotAngle
            local dx = cardCX + math.cos(da) * (orbitR + 6)
            local dy = cardCY + math.sin(da) * (orbitR + 6)
            local dotAlpha = 30 + 20 * math.sin(t * 1.2 + i * 0.5)
            nvgBeginPath(vg)
            nvgCircle(vg, dx, dy, 1.5)
            nvgFillColor(vg, nvgRGBA(180, 120, 255, math.floor(dotAlpha)))
            nvgFill(vg)
        end

        -- ========== 2. 连接线 (各指向卡牌不同锚点) ==========
        for slotIdx = 1, SEAL_MAX_SLOTS do
            local angle = ((slotIdx - 1) / SEAL_MAX_SLOTS) * math.pi * 2 - math.pi / 2
            local sx = cardCX + math.cos(angle) * orbitR
            local sy = cardCY + math.sin(angle) * orbitR
            local anchor = cardAnchors[slotIdx]

            local slot = sd and sd.slots and sd.slots[slotIdx] or nil
            local stc = SEAL_SLOT_THEME_COLORS[slotIdx] or { 120, 80, 180 }

            -- 连线 (从兵符孔位→卡牌锚点)
            local lineActive = slot ~= nil
            local linePulse = 0.4 + 0.3 * math.sin(t * 1.8 + slotIdx * 1.05)
            local lineA = lineActive and math.floor(120 * linePulse) or math.floor(30 * linePulse)

            nvgBeginPath(vg)
            nvgMoveTo(vg, sx, sy)
            nvgLineTo(vg, anchor.x, anchor.y)
            nvgStrokeColor(vg, nvgRGBA(stc[1], stc[2], stc[3], lineA))
            nvgStrokeWidth(vg, lineActive and 1.5 or 0.8)
            nvgStroke(vg)

            -- 锚点端发光点
            if lineActive then
                local anchorGlow = 0.5 + 0.5 * math.sin(t * 2.5 + slotIdx * 0.9)
                nvgBeginPath(vg)
                nvgCircle(vg, anchor.x, anchor.y, 3)
                nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], math.floor(160 * anchorGlow)))
                nvgFill(vg)
            end

            -- 流动能量粒子 (沿连线从孔位流向卡牌)
            if lineActive then
                for pi = 0, 1 do
                    local pTime = (t * 0.5 + slotIdx * 0.4 + pi * 0.5) % 1.0
                    local px = sx + (anchor.x - sx) * pTime
                    local py = sy + (anchor.y - sy) * pTime
                    local pAlpha = math.sin(pTime * math.pi)
                    nvgBeginPath(vg)
                    nvgCircle(vg, px, py, 2.0)
                    nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], math.floor(140 * pAlpha)))
                    nvgFill(vg)
                end
            end
        end

        -- ========== 3. 中心卡牌 (复用武灵图录渲染) ==========
        if card then
            DrawInventoryCard(cardX, cardY, cardW, cardH, card, constellation, false)
        end

        -- 兵符孔数信息 (卡牌下方)
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cardCX, cardY + cardH + 16, "六德 " .. slotCount .. "/" .. SEAL_MAX_SLOTS)

        -- 切换提示
        if #maxHeroes > 1 then
            local hintPulse = 150 + 60 * math.sin(t * 2.0)
            nvgFontSize(vg, 20)
            nvgFillColor(vg, nvgRGBA(200, 170, 240, math.floor(hintPulse)))
            nvgText(vg, cardCX, cardY + cardH + 34, "- 点击卡牌切换 -", nil)
        end

        -- 中心卡牌点击区域
        sealMgrBtnRects.centerCard = { x = cardX - 8, y = cardY - 8, w = cardW + 16, h = cardH + 46 }

        -- ========== 4. 六个兵符孔 (环绕布局) ==========
        local slotR = 34
        for slotIdx = 1, SEAL_MAX_SLOTS do
            local angle = ((slotIdx - 1) / SEAL_MAX_SLOTS) * math.pi * 2 - math.pi / 2
            -- 浮动偏移
            local floatAmt = math.sin(t * 1.2 + slotIdx * 1.05) * 3
            local sx = cardCX + math.cos(angle) * (orbitR + floatAmt)
            local sy = cardCY + math.sin(angle) * (orbitR + floatAmt)

            local slot = sd and sd.slots and sd.slots[slotIdx] or nil
            local isSelected = (sealMgrState.selectedSlot == slotIdx)
            local stc = SEAL_SLOT_THEME_COLORS[slotIdx] or { 200, 200, 200 }

            if slot then
                -- ===== 已开孔 =====
                local sc = SEAL_QUALITY_COLORS[slot.sealQ] or { 180, 180, 180 }

                -- 底部光晕 (品质色)
                local glowPulse = 0.4 + 0.3 * math.sin(t * 1.5 + slotIdx * 0.7)
                local slotGlow = nvgRadialGradient(vg, sx, sy, 4, slotR + 16,
                    nvgRGBA(sc[1], sc[2], sc[3], math.floor(60 * glowPulse)),
                    nvgRGBA(sc[1], sc[2], sc[3], 0))
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, slotR + 16)
                nvgFillPaint(vg, slotGlow); nvgFill(vg)

                -- 选中时外层强光脉冲
                if isSelected then
                    local selPulse2 = 0.5 + 0.5 * math.sin(t * 4.0)
                    local selGlow2 = nvgRadialGradient(vg, sx, sy, slotR, slotR + 20,
                        nvgRGBA(255, 255, 255, math.floor(70 * selPulse2)),
                        nvgRGBA(255, 255, 255, 0))
                    nvgBeginPath(vg); nvgCircle(vg, sx, sy, slotR + 20)
                    nvgFillPaint(vg, selGlow2); nvgFill(vg)
                end

                -- 六角形主体
                DrawSealHexIcon(sx, sy, slotR, sc, slot.sealQ)

                -- 选中高亮描边 (六角形脉冲)
                if isSelected then
                    nvgBeginPath(vg)
                    for vi = 0, 5 do
                        local a = (vi / 6) * math.pi * 2 - math.pi / 2
                        local px = sx + math.cos(a) * (slotR + 4)
                        local py = sy + math.sin(a) * (slotR + 4)
                        if vi == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
                    end
                    nvgClosePath(vg)
                    local sPulse = 0.5 + 0.5 * math.sin(t * 3.0)
                    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, math.floor(200 * sPulse)))
                    nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
                end

                -- 等级 (六角形下半区)
                nvgFontSize(vg, 20)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(sx, sy + slotR * 0.25, "Lv." .. (slot.level or 1))

                -- 孔名 (下方白字描边)
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(sx, sy + slotR + 14, SEAL_SLOT_NAMES[slotIdx])

                -- 效果主题 (更下方，带主题色描边)
                local eff = SEAL_SLOT_EFFECTS[slotIdx]
                if eff then
                    nvgFontSize(vg, 18)
                    -- 先画描边
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 140))
                    nvgText(vg, sx - 1, sy + slotR + 29, eff.theme, nil)
                    nvgText(vg, sx + 1, sy + slotR + 29, eff.theme, nil)
                    nvgText(vg, sx, sy + slotR + 28, eff.theme, nil)
                    nvgText(vg, sx, sy + slotR + 30, eff.theme, nil)
                    -- 主题色主体
                    nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], 220))
                    nvgText(vg, sx, sy + slotR + 29, eff.theme, nil)
                end
            else
                -- ===== 未开孔 =====
                -- 暗淡光晕
                local dimGlow = nvgRadialGradient(vg, sx, sy, 4, slotR + 10,
                    nvgRGBA(60, 30, 90, 25), nvgRGBA(60, 30, 90, 0))
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, slotR + 10)
                nvgFillPaint(vg, dimGlow); nvgFill(vg)

                -- 暗淡六角形
                nvgBeginPath(vg)
                for vi = 0, 5 do
                    local a = (vi / 6) * math.pi * 2 - math.pi / 2
                    local px = sx + math.cos(a) * slotR
                    local py = sy + math.sin(a) * slotR
                    if vi == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
                end
                nvgClosePath(vg)
                nvgFillColor(vg, nvgRGBA(25, 15, 40, 180)); nvgFill(vg)
                -- 虚线边框效果 (分段描边)
                nvgStrokeColor(vg, nvgRGBA(80, 50, 120, 80))
                nvgStrokeWidth(vg, 1); nvgStroke(vg)

                -- 锁定图标 (呼吸)
                local lockAlpha = 80 + 40 * math.sin(t * 0.8 + slotIdx * 0.6)
                nvgFontSize(vg, 24)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(120, 80, 160, math.floor(lockAlpha)))
                nvgText(vg, sx, sy, "锁", nil)

                -- 孔名 (白字描边，暗淡)
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
                nvgText(vg, sx - 1, sy + slotR + 14, SEAL_SLOT_NAMES[slotIdx], nil)
                nvgText(vg, sx + 1, sy + slotR + 14, SEAL_SLOT_NAMES[slotIdx], nil)
                nvgFillColor(vg, nvgRGBA(160, 130, 200, 100))
                nvgText(vg, sx, sy + slotR + 14, SEAL_SLOT_NAMES[slotIdx], nil)

                -- 效果主题 (暗淡)
                local eff2 = SEAL_SLOT_EFFECTS[slotIdx]
                if eff2 then
                    nvgFontSize(vg, 18)
                    nvgFillColor(vg, nvgRGBA(100, 70, 150, 60))
                    nvgText(vg, sx, sy + slotR + 29, eff2.theme, nil)
                end
            end

            sealMgrSlotRects[slotIdx] = { x = sx - slotR - 6, y = sy - slotR - 6, w = (slotR + 6) * 2, h = (slotR + 6) * 2 + 36 }
        end

        -- ========== 5. 底部信息面板 ==========
        local bottomY = cardCY + orbitR + 68

        -- 兵符总加成
        local bonus = GetSealTotalBonus(cardIdx)
        local bonusLines = {}
        local bonusFieldDefs = {
            { key = "strAdd",   name = "武力",   fmt = "+%.0f",   slot = 1 },
            { key = "intAdd",   name = "智力",   fmt = "+%.0f",   slot = 2 },
            { key = "vitAdd",   name = "体力",   fmt = "+%.0f",   slot = 3 },
            { key = "tecAdd",   name = "技法",   fmt = "+%.0f",   slot = 4 },
            { key = "spdAdd",   name = "速度",   fmt = "+%.0f",   slot = 5 },
            { key = "critRate", name = "暴击率", fmt = "+%.1f%%", slot = 6 },
        }
        for _, fd in ipairs(bonusFieldDefs) do
            local v = bonus[fd.key] or 0
            if v > 0 then
                local tc = SEAL_SLOT_THEME_COLORS[fd.slot] or { 200, 160, 255 }
                table.insert(bonusLines, { text = fd.name .. string.format(fd.fmt, v), color = tc })
            end
        end

        if #bonusLines > 0 then
            local lineH2 = 18
            local bPanelW = W - 40
            local bPanelH = 34 + math.ceil(#bonusLines / 2) * lineH2
            local bPanelX = cx - bPanelW / 2

            -- 面板背景
            nvgBeginPath(vg); nvgRoundedRect(vg, bPanelX, bottomY, bPanelW, bPanelH, 8)
            nvgFillColor(vg, nvgRGBA(20, 10, 35, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(140, 80, 200, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 标题
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, bottomY + 16, "兵符总加成")

            -- 两列加成
            nvgFontSize(vg, 22)
            local colW = bPanelW / 2
            for li, bl in ipairs(bonusLines) do
                local col = (li - 1) % 2
                local row = math.floor((li - 1) / 2)
                local lx = bPanelX + colW * col + colW / 2
                local ly = bottomY + 32 + row * lineH2
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                -- 描边
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
                nvgText(vg, lx - 1, ly, bl.text, nil)
                nvgText(vg, lx + 1, ly, bl.text, nil)
                -- 主色
                nvgFillColor(vg, nvgRGBA(bl.color[1], bl.color[2], bl.color[3], 230))
                nvgText(vg, lx, ly, bl.text, nil)
            end
            bottomY = bottomY + bPanelH + 8
        end

        -- 咒墨道具概览
        nvgFontSize(vg, 19)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, bottomY + 6, "咒墨道具")

        local itemRowY = bottomY + 28
        local itemW = (W - 40) / 4
        local itemCardH = 72
        for idx, item in ipairs(SEAL_EXP_ITEMS) do
            local ix = 20 + (idx - 1) * itemW
            local cnt = sealExpItems[idx] or 0
            local cw = itemW - 6
            local ccx = ix + cw / 2

            -- 道具卡片背景
            nvgBeginPath(vg); nvgRoundedRect(vg, ix, itemRowY, cw, itemCardH, 5)
            nvgFillColor(vg, nvgRGBA(20, 12, 35, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(110, 70, 170, 80)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

            -- 道具图标
            local imgSize = 30
            local imgHandle = sealExpItemImages[idx]
            if imgHandle and imgHandle > 0 then
                local imgPat = nvgImagePattern(vg, ccx - imgSize / 2, itemRowY + 4, imgSize, imgSize, 0, imgHandle, 1.0)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, ccx - imgSize / 2, itemRowY + 4, imgSize, imgSize, 4)
                nvgFillPaint(vg, imgPat); nvgFill(vg)
            end

            -- 道具名 (白字描边)
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(ccx, itemRowY + imgSize + 10, item.name)

            -- 数量
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if cnt > 0 then
                DrawWhiteInkText(ccx, itemRowY + imgSize + 26, "x" .. cnt)
            else
                nvgFillColor(vg, nvgRGBA(80, 60, 110, 120))
                nvgText(vg, ccx, itemRowY + imgSize + 26, "x0", nil)
            end
        end
    else
        -- ============ 无满命英雄提示 ============
        -- 装饰环
        local emptyPulse = 0.3 + 0.2 * math.sin(t * 0.6)
        nvgBeginPath(vg)
        nvgCircle(vg, cardCX, cardCY, orbitR)
        nvgStrokeColor(vg, nvgRGBA(80, 40, 140, math.floor(50 * emptyPulse)))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 占位空卡
        nvgBeginPath(vg); nvgRoundedRect(vg, cardX, cardY, cardW, cardH, 6)
        nvgFillColor(vg, nvgRGBA(30, 20, 45, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 50, 120, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        nvgFontSize(vg, 40)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(80, 50, 120, 80))
        nvgText(vg, cardCX, cardCY - 10, "?", nil)

        nvgFontSize(vg, 18)
        DrawWhiteInkText(cardCX, cardY + cardH + 20, "暂无满命武灵")

        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(140, 110, 180, 120))
        nvgText(vg, cardCX, cardY + cardH + 42, "满命后解锁兵符系统", nil)
    end

    -- ============ 英雄选择弹窗 ============
    if sealMgrState.showHeroPicker and #maxHeroes > 1 then
        -- 半透明遮罩
        nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
        nvgFillColor(vg, nvgRGBA(5, 3, 15, 180)); nvgFill(vg)

        -- 布局计算
        local ppW = W * 0.92
        local colCount = 3
        local padX = 18
        local cellGap = 10
        local cellW = (ppW - padX * 2 - (colCount - 1) * cellGap) / colCount
        local cellH = cellW * 1.35
        local rows = math.ceil(#maxHeroes / colCount)
        local headerH = 56
        local gridContentH = rows * (cellH + cellGap) - cellGap
        local maxGridViewH = H * 0.62  -- 弹窗网格区最大可视高度
        local gridViewH = math.min(gridContentH, maxGridViewH)
        local needsScroll = (gridContentH > gridViewH)
        local footerH = needsScroll and 28 or 12
        local ppH = headerH + gridViewH + footerH
        local ppX = cx - ppW / 2
        local ppY = H / 2 - ppH / 2

        -- 记录滚动区域尺寸 (供拖拽逻辑使用)
        heroPickerScroll.contentH = gridContentH
        heroPickerScroll.viewH = gridViewH

        -- ====== 面板背景 (三国古风暗紫渐变) ======
        nvgSave(vg)
        local ppGrad = nvgLinearGradient(vg, ppX, ppY, ppX, ppY + ppH,
            nvgRGBA(42, 20, 65, 250), nvgRGBA(25, 12, 42, 252))
        nvgBeginPath(vg); nvgRoundedRect(vg, ppX, ppY, ppW, ppH, 14)
        nvgFillPaint(vg, ppGrad); nvgFill(vg)
        -- 外边框 (双层: 金色内框 + 暗紫外框)
        nvgBeginPath(vg); nvgRoundedRect(vg, ppX + 1, ppY + 1, ppW - 2, ppH - 2, 13)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 80, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, ppX, ppY, ppW, ppH, 14)
        nvgStrokeColor(vg, nvgRGBA(140, 70, 200, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

        -- ====== 标题栏 ======
        -- 标题背景装饰条
        local titleBarGrad = nvgLinearGradient(vg, ppX, ppY, ppX + ppW, ppY,
            nvgRGBA(120, 60, 180, 0), nvgRGBA(120, 60, 180, 60))
        nvgBeginPath(vg); nvgRoundedRect(vg, ppX + 4, ppY + 4, ppW - 8, headerH - 8, 10)
        nvgFillPaint(vg, titleBarGrad); nvgFill(vg)
        -- 底部分隔线
        local sepGrad = nvgLinearGradient(vg, ppX + 20, ppY + headerH, ppX + ppW - 20, ppY + headerH,
            nvgRGBA(200, 160, 80, 0), nvgRGBA(200, 160, 80, 120))
        nvgBeginPath(vg)
        nvgMoveTo(vg, ppX + 20, ppY + headerH - 1)
        nvgLineTo(vg, ppX + ppW - 20, ppY + headerH - 1)
        nvgStrokePaint(vg, sepGrad); nvgStrokeWidth(vg, 1); nvgStroke(vg)

        nvgFontFaceId(vg, GetMainFont())
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawWhiteInkText(cx, ppY + headerH / 2, "— 选择武灵 —")

        -- 武灵数量提示
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(180, 150, 220, 160))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, ppX + padX, ppY + headerH / 2 + 1, #maxHeroes .. "位满命", nil)

        -- ====== 关闭按钮 (圆形) ======
        local closeBtnR = 16
        local closeCX = ppX + ppW - 24
        local closeCY = ppY + headerH / 2
        nvgBeginPath(vg); nvgCircle(vg, closeCX, closeCY, closeBtnR)
        nvgFillColor(vg, nvgRGBA(60, 30, 85, 220)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(180, 120, 240, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        -- X 图标
        local xOff = 7
        nvgBeginPath(vg)
        nvgMoveTo(vg, closeCX - xOff, closeCY - xOff)
        nvgLineTo(vg, closeCX + xOff, closeCY + xOff)
        nvgMoveTo(vg, closeCX + xOff, closeCY - xOff)
        nvgLineTo(vg, closeCX - xOff, closeCY + xOff)
        nvgStrokeColor(vg, nvgRGBA(220, 200, 255, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
        sealMgrBtnRects.closeHeroPicker = { x = closeCX - closeBtnR, y = closeCY - closeBtnR, w = closeBtnR * 2, h = closeBtnR * 2 }

        -- ====== 英雄网格 (带裁剪滚动) ======
        local gridAreaX = ppX + padX
        local gridAreaY = ppY + headerH
        local gridAreaW = ppW - padX * 2
        local scrollY = heroPickerScroll.y or 0

        nvgSave(vg)
        nvgScissor(vg, gridAreaX - 2, gridAreaY, gridAreaW + 4, gridViewH)

        for i, heroInfo in ipairs(maxHeroes) do
            local col = ((i - 1) % colCount)
            local row = math.floor((i - 1) / colCount)
            local hx = gridAreaX + col * (cellW + cellGap)
            local hy = gridAreaY + row * (cellH + cellGap) - scrollY

            -- 跳过不可见的卡牌 (性能优化)
            if hy + cellH >= gridAreaY - 10 and hy <= gridAreaY + gridViewH + 10 then
                local hCard = HERO_CARDS[heroInfo.cardIdx]
                local hHero = playerHeroes[heroInfo.cardIdx]
                local hConst = hHero and hHero.constellation or 0
                local isSelected = (sealMgrState.selectedHero == heroInfo.cardIdx)

                -- 卡牌底色 (选中时金色光晕)
                if isSelected then
                    nvgBeginPath(vg); nvgRoundedRect(vg, hx - 4, hy - 4, cellW + 8, cellH + 8, 8)
                    nvgFillColor(vg, nvgRGBA(200, 160, 60, 40)); nvgFill(vg)
                end

                if hCard then
                    DrawInventoryCard(hx, hy, cellW, cellH, hCard, hConst, false)
                end

                -- 选中高亮边框 (金色双层)
                if isSelected then
                    nvgBeginPath(vg); nvgRoundedRect(vg, hx - 3, hy - 3, cellW + 6, cellH + 6, 7)
                    nvgStrokeColor(vg, nvgRGBA(255, 210, 80, 240))
                    nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, hx - 1, hy - 1, cellW + 2, cellH + 2, 5)
                    nvgStrokeColor(vg, nvgRGBA(255, 240, 160, 100))
                    nvgStrokeWidth(vg, 1); nvgStroke(vg)
                end

                -- 已开孔数标记 (右下角胶囊)
                local sc2 = GetSealSlotCount(heroInfo.cardIdx)
                local badgeW2, badgeH2 = 36, 16
                local badgeX = hx + cellW - badgeW2 - 3
                local badgeY = hy + cellH - badgeH2 - 3
                local badgeBg = nvgLinearGradient(vg, badgeX, badgeY, badgeX, badgeY + badgeH2,
                    nvgRGBA(30, 15, 50, 230), nvgRGBA(20, 8, 35, 240))
                nvgBeginPath(vg); nvgRoundedRect(vg, badgeX, badgeY, badgeW2, badgeH2, badgeH2 / 2)
                nvgFillPaint(vg, badgeBg); nvgFill(vg)
                nvgBeginPath(vg); nvgRoundedRect(vg, badgeX, badgeY, badgeW2, badgeH2, badgeH2 / 2)
                nvgStrokeColor(vg, nvgRGBA(160, 120, 220, 100)); nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                local slotColor = sc2 >= 6 and nvgRGBA(255, 220, 80, 255) or nvgRGBA(200, 180, 240, 220)
                nvgFillColor(vg, slotColor)
                nvgText(vg, badgeX + badgeW2 / 2, badgeY + badgeH2 / 2, sc2 .. "/" .. SEAL_MAX_SLOTS .. "孔", nil)

                -- 记录点击区域 (使用滚动后的实际位置)
                sealMgrHeroRects[heroInfo.cardIdx] = { x = hx, y = hy, w = cellW, h = cellH }
            end
        end

        nvgRestore(vg)  -- 恢复裁剪

        -- ====== 滚动条（粗，高可见度）======
        if needsScroll and gridContentH > 0 then
            local sbBarW = 8
            local scrollBarX = ppX + ppW - sbBarW - 4
            local scrollBarH = math.max(30, gridViewH * (gridViewH / gridContentH))
            local scrollBarMaxY = gridViewH - scrollBarH
            local scrollRatio = scrollY / math.max(1, gridContentH - gridViewH)
            local scrollBarY = gridAreaY + scrollRatio * scrollBarMaxY
            -- 轨道
            nvgBeginPath(vg); nvgRoundedRect(vg, scrollBarX, gridAreaY, sbBarW, gridViewH, sbBarW / 2)
            nvgFillColor(vg, nvgRGBA(40, 20, 60, 100)); nvgFill(vg)
            -- 滑块
            nvgBeginPath(vg); nvgRoundedRect(vg, scrollBarX, scrollBarY, sbBarW, scrollBarH, sbBarW / 2)
            nvgFillColor(vg, nvgRGBA(200, 160, 255, heroPickerScroll.isDragging and 220 or 150)); nvgFill(vg)
        end

        -- ====== 底部提示 (可滚动时显示) ======
        if needsScroll then
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(160, 140, 200, 100))
            nvgText(vg, cx, ppY + ppH - footerH / 2, "上下滑动查看更多", nil)
        end

        nvgRestore(vg)
    end

    -- ============ 升级面板 (弹窗) ============
    if sealMgrState.showLevelUp and sealMgrState.selectedHero and sealMgrState.selectedSlot then
        local cardIdx = sealMgrState.selectedHero
        local slotIdx = sealMgrState.selectedSlot
        local sd = sealData[cardIdx]
        local slot = sd and sd.slots and sd.slots[slotIdx]

        if slot then
            -- 遮罩
            nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
            nvgFillColor(vg, nvgRGBA(5, 3, 15, 160)); nvgFill(vg)

            -- 弹窗面板
            local pW = W * 0.88
            local pH = 560
            local pX = cx - pW / 2
            local pY = H / 2 - pH / 2

            local pGrad = nvgLinearGradient(vg, pX, pY, pX, pY + pH,
                nvgRGBA(40, 18, 55, 248), nvgRGBA(25, 12, 38, 252))
            nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
            nvgFillPaint(vg, pGrad); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
            nvgStrokeColor(vg, nvgRGBA(160, 80, 240, 140)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

            nvgFontFaceId(vg, GetMainFont())

            -- 标题 (白字描边)
            local sc = SEAL_QUALITY_COLORS[slot.sealQ] or { 180, 180, 180 }
            nvgFontSize(vg, 28)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, pY + 28, SEAL_SLOT_NAMES[slotIdx] .. " · " .. (SEAL_QUALITY_NAMES[slot.sealQ] or "?"))

            -- 关闭按钮
            local closeBtnSize = 36
            local closeX = pX + pW - closeBtnSize - 8
            local closeY = pY + 8
            nvgBeginPath(vg); nvgRoundedRect(vg, closeX, closeY, closeBtnSize, closeBtnSize, 6)
            nvgFillColor(vg, nvgRGBA(50, 25, 70, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(160, 100, 220, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(closeX + closeBtnSize / 2, closeY + closeBtnSize / 2, "X")
            sealMgrBtnRects.closeLevelUp = { x = closeX, y = closeY, w = closeBtnSize, h = closeBtnSize }

            -- 六角形图标 + 等级
            local iconY = pY + 90
            DrawSealHexIcon(cx, iconY, 38, sc, slot.sealQ)
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, iconY + 2, "Lv." .. slot.level)

            -- 属性加成
            local slotBonus = GetSealSlotBonus(slotIdx, slot.sealQ, slot.level)
            local attrY = iconY + 46
            local stc = SEAL_SLOT_THEME_COLORS[slotIdx] or { 200, 160, 255 }
            if slotBonus then
                -- 主题名 (主题色描边)
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
                nvgText(vg, cx - 1, attrY, "【" .. slotBonus.theme .. "】", nil)
                nvgText(vg, cx + 1, attrY, "【" .. slotBonus.theme .. "】", nil)
                nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], 230))
                nvgText(vg, cx, attrY, "【" .. slotBonus.theme .. "】", nil)
                attrY = attrY + 22

                -- 主属性 (白字描边)
                nvgFontSize(vg, 24)
                local mainText
                if slotBonus.mainKey == "critRate" then
                    mainText = slotBonus.mainName .. string.format("+%.1f%%", slotBonus.mainVal)
                else
                    mainText = slotBonus.mainName .. string.format("+%.0f", slotBonus.mainVal)
                end
                DrawWhiteInkText(cx, attrY, mainText)
            end

            -- 经验进度条
            local barY = attrY + 28
            local barW2 = pW - 60
            local barH2 = 16
            local barX = cx - barW2 / 2

            if slot.level < SEAL_MAX_LEVEL then
                local expNeeded = SEAL_EXP_TABLE[slot.level] or 999
                local expCur = slot.exp or 0
                local ratio = math.min(1.0, expCur / expNeeded)

                nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW2, barH2, 4)
                nvgFillColor(vg, nvgRGBA(15, 8, 28, 220)); nvgFill(vg)
                if ratio > 0 then
                    local barGrad = nvgLinearGradient(vg, barX, barY, barX + barW2 * ratio, barY,
                        nvgRGBA(sc[1], sc[2], sc[3], 200), nvgRGBA(sc[1], sc[2], sc[3], 140))
                    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW2 * ratio, barH2, 4)
                    nvgFillPaint(vg, barGrad); nvgFill(vg)
                end
                nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW2, barH2, 4)
                nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 100))
                nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

                nvgFontSize(vg, 20)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(cx, barY + barH2 / 2, expCur .. " / " .. expNeeded)
            else
                nvgFontSize(vg, 24)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
                nvgText(vg, cx - 1, barY + barH2 / 2, "已达最高等级!", nil)
                nvgText(vg, cx + 1, barY + barH2 / 2, "已达最高等级!", nil)
                nvgFillColor(vg, nvgRGBA(255, 220, 80, 240))
                nvgText(vg, cx, barY + barH2 / 2, "已达最高等级!", nil)
            end

            -- 使用咒墨道具
            local useItemY = barY + barH2 + 24
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, useItemY, "使用咒墨提升等级")

            local useBtnY = useItemY + 26
            local useBtnW = (pW - 50) / 4
            local useBtnH = 90
            local imgBtnSize = 28

            for idx, item in ipairs(SEAL_EXP_ITEMS) do
                local bx = pX + 20 + (idx - 1) * (useBtnW + 4)
                local by = useBtnY
                local cnt = sealExpItems[idx] or 0
                local canUse = cnt > 0 and slot.level < SEAL_MAX_LEVEL
                local bcx = bx + useBtnW / 2

                nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, useBtnW, useBtnH, 6)
                if canUse then
                    nvgFillColor(vg, nvgRGBA(35, 18, 55, 230)); nvgFill(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, useBtnW, useBtnH, 6)
                    nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 160))
                    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
                else
                    nvgFillColor(vg, nvgRGBA(20, 12, 30, 180)); nvgFill(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, useBtnW, useBtnH, 6)
                    nvgStrokeColor(vg, nvgRGBA(50, 35, 70, 80))
                    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                end

                -- 道具图标
                local imgHandle = sealExpItemImages[idx]
                if imgHandle and imgHandle > 0 then
                    local alpha = canUse and 1.0 or 0.4
                    local imgPat = nvgImagePattern(vg, bcx - imgBtnSize / 2, by + 6, imgBtnSize, imgBtnSize, 0, imgHandle, alpha)
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, bcx - imgBtnSize / 2, by + 6, imgBtnSize, imgBtnSize, 4)
                    nvgFillPaint(vg, imgPat); nvgFill(vg)
                end

                -- 道具名 (白字描边)
                nvgFontSize(vg, 20)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if canUse then
                    DrawWhiteInkText(bcx, by + imgBtnSize + 14, item.name)
                else
                    nvgFillColor(vg, nvgRGBA(80, 60, 100, 120))
                    nvgText(vg, bcx, by + imgBtnSize + 14, item.name, nil)
                end

                -- 经验值
                nvgFontSize(vg, 18)
                if canUse then
                    DrawWhiteInkText(bcx, by + imgBtnSize + 30, "+" .. item.exp .. "EXP")
                else
                    nvgFillColor(vg, nvgRGBA(80, 60, 100, 80))
                    nvgText(vg, bcx, by + imgBtnSize + 30, "+" .. item.exp .. "EXP", nil)
                end

                -- 数量
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if cnt > 0 then
                    DrawWhiteInkText(bcx, by + imgBtnSize + 48, "x" .. cnt)
                else
                    nvgFillColor(vg, nvgRGBA(80, 60, 100, 100))
                    nvgText(vg, bcx, by + imgBtnSize + 48, "x0", nil)
                end

                -- "使用" 按钮文字
                if canUse then
                    nvgFontSize(vg, 22)
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
                    nvgText(vg, bcx - 1, by + useBtnH - 8, "使用", nil)
                    nvgText(vg, bcx + 1, by + useBtnH - 8, "使用", nil)
                    nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 240))
                    nvgText(vg, bcx, by + useBtnH - 8, "使用", nil)
                end

                sealMgrExpItemRects[idx] = { x = bx, y = by, w = useBtnW, h = useBtnH }
            end

            -- ============ 一键升级区域 ============
            local batchY = useBtnY + useBtnH + 12
            if slot.level < SEAL_MAX_LEVEL then
                -- 初始化目标等级
                if not sealBatchTarget or sealBatchTarget <= slot.level then
                    sealBatchTarget = math.min(slot.level + 1, SEAL_MAX_LEVEL)
                end
                if sealBatchTarget > SEAL_MAX_LEVEL then sealBatchTarget = SEAL_MAX_LEVEL end

                local expNeeded = CalcSealExpNeeded(slot.level, slot.exp, sealBatchTarget)
                local plan = CalcSealAutoEnhancePlan(expNeeded)
                local canBatch = plan ~= nil and sealBatchTarget > slot.level

                -- 背景条
                nvgBeginPath(vg); nvgRoundedRect(vg, pX + 16, batchY, pW - 32, 52, 8)
                nvgFillColor(vg, nvgRGBA(20, 12, 35, 200)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(140, 80, 220, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

                -- "升至" 文字
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(pX + 26, batchY + 18, "升至")

                -- - 按钮
                local minusBtnX = pX + 66
                local minusBtnW, minusBtnH = 30, 28
                nvgBeginPath(vg); nvgRoundedRect(vg, minusBtnX, batchY + 4, minusBtnW, minusBtnH, 5)
                nvgFillColor(vg, sealBatchTarget > slot.level + 1 and nvgRGBA(60, 30, 90, 220) or nvgRGBA(30, 18, 45, 150))
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(140, 80, 220, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(minusBtnX + minusBtnW / 2, batchY + 4 + minusBtnH / 2, "-")
                sealMgrBtnRects.batchMinus = { x = minusBtnX, y = batchY + 4, w = minusBtnW, h = minusBtnH }

                -- 目标等级
                nvgFontSize(vg, 22); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 220, 80, 255))
                nvgText(vg, minusBtnX + minusBtnW + 30, batchY + 18, "Lv." .. sealBatchTarget, nil)

                -- + 按钮
                local plusBtnX = minusBtnX + minusBtnW + 58
                nvgBeginPath(vg); nvgRoundedRect(vg, plusBtnX, batchY + 4, minusBtnW, minusBtnH, 5)
                nvgFillColor(vg, sealBatchTarget < SEAL_MAX_LEVEL and nvgRGBA(60, 30, 90, 220) or nvgRGBA(30, 18, 45, 150))
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(140, 80, 220, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(plusBtnX + minusBtnW / 2, batchY + 4 + minusBtnH / 2, "+")
                sealMgrBtnRects.batchPlus = { x = plusBtnX, y = batchY + 4, w = minusBtnW, h = minusBtnH }

                -- 所需经验
                nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(180, 160, 220, 180))
                nvgText(vg, pX + 26, batchY + 40, "需" .. expNeeded .. "EXP", nil)

                -- 材料消耗预览
                if plan then
                    local previewX = pX + 100
                    nvgFontSize(vg, 18)
                    for idx = 1, #SEAL_EXP_ITEMS do
                        local use = plan[idx] or 0
                        if use > 0 then
                            nvgFillColor(vg, nvgRGBA(200, 180, 255, 200))
                            nvgText(vg, previewX, batchY + 40, SEAL_EXP_ITEMS[idx].name .. "x" .. use, nil)
                            local tw = nvgTextBounds(vg, 0, 0, SEAL_EXP_ITEMS[idx].name .. "x" .. use, nil)
                            previewX = previewX + tw + 8
                        end
                    end
                else
                    nvgFontSize(vg, 20)
                    nvgFillColor(vg, nvgRGBA(255, 100, 100, 200))
                    nvgText(vg, pX + 100, batchY + 40, "材料不足", nil)
                end

                -- 一键升级按钮
                local goBtnW = 80
                local goBtnH = 36
                local goBtnX = pX + pW - goBtnW - 24
                local goBtnY2 = batchY + 8
                nvgBeginPath(vg); nvgRoundedRect(vg, goBtnX, goBtnY2, goBtnW, goBtnH, 6)
                if canBatch then
                    local goGrad = nvgLinearGradient(vg, goBtnX, goBtnY2, goBtnX, goBtnY2 + goBtnH,
                        nvgRGBA(180, 80, 255, 230), nvgRGBA(120, 40, 200, 230))
                    nvgFillPaint(vg, goGrad); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(220, 160, 255, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                else
                    nvgFillColor(vg, nvgRGBA(40, 25, 55, 180)); nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(80, 50, 110, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                end
                nvgFontSize(vg, 24); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                if canBatch then
                    DrawWhiteInkText(goBtnX + goBtnW / 2, goBtnY2 + goBtnH / 2, "一键升级")
                else
                    nvgFillColor(vg, nvgRGBA(80, 60, 100, 120))
                    nvgText(vg, goBtnX + goBtnW / 2, goBtnY2 + goBtnH / 2, "一键升级", nil)
                end
                sealMgrBtnRects.batchGo = canBatch and { x = goBtnX, y = goBtnY2, w = goBtnW, h = goBtnH } or nil
            end

            local batchAreaH = (slot.level < SEAL_MAX_LEVEL) and 60 or 0

            -- ============ 替换 / 分解 操作按钮 ============
            local actionBtnY = useBtnY + useBtnH + 14 + batchAreaH
            local actionBtnW = (pW - 54) / 2
            local actionBtnH = 38

            -- 替换按钮
            local replaceBtnX = pX + 20
            nvgBeginPath(vg); nvgRoundedRect(vg, replaceBtnX, actionBtnY, actionBtnW, actionBtnH, 6)
            nvgFillColor(vg, nvgRGBA(35, 70, 110, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80, 150, 220, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(replaceBtnX + actionBtnW / 2, actionBtnY + actionBtnH / 2, "替换兵符")
            sealMgrBtnRects.replaceBtn = { x = replaceBtnX, y = actionBtnY, w = actionBtnW, h = actionBtnH }

            -- 分解按钮
            local decomposeBtnX = pX + 34 + actionBtnW
            nvgBeginPath(vg); nvgRoundedRect(vg, decomposeBtnX, actionBtnY, actionBtnW, actionBtnH, 6)
            nvgFillColor(vg, nvgRGBA(110, 35, 35, 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 80, 80, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(decomposeBtnX + actionBtnW / 2, actionBtnY + actionBtnH / 2, "分解兵符")
            sealMgrBtnRects.decomposeBtn = { x = decomposeBtnX, y = actionBtnY, w = actionBtnW, h = actionBtnH }
        end
    end

    -- ============ 替换弹窗 (最高优先级) ============
    if sealReplaceState.show then
        DrawSealReplacePopup()
    end

    -- ============ 分解确认弹窗 (次高优先级) ============
    if sealDecomposeState.show then
        DrawSealDecomposeConfirm()
    end

    -- ============ 筛选分解确认弹窗 ============
    if sealInvFilterState.batchConfirmShow then
        DrawSealBatchDecompConfirm()
    end
end


-- ============================================================================
-- 兵符替换弹窗绘制
-- ============================================================================
function DrawSealReplacePopup()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local heroIdx = sealReplaceState.heroIdx
    local slotIdx = sealReplaceState.slotIdx
    if not heroIdx or not slotIdx then return end

    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 3, 15, 190)); nvgFill(vg)

    -- 弹窗面板
    local pW = W * 0.92
    local pH = H * 0.72
    local pX = cx - pW / 2
    local pY = H / 2 - pH / 2

    local pGrad = nvgLinearGradient(vg, pX, pY, pX, pY + pH,
        nvgRGBA(38, 18, 58, 250), nvgRGBA(22, 10, 38, 252))
    nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
    nvgFillPaint(vg, pGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
    nvgStrokeColor(vg, nvgRGBA(160, 80, 240, 140)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    local stc = SEAL_SLOT_THEME_COLORS[slotIdx] or { 200, 160, 255 }
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, pY + 28, SEAL_SLOT_NAMES[slotIdx] .. " - 仓库")

    -- 当前装备信息
    local sd = sealData[heroIdx]
    local equipped = sd and sd.slots and sd.slots[slotIdx]
    local infoY = pY + 54
    if equipped then
        local sc = SEAL_QUALITY_COLORS[equipped.sealQ] or { 180, 180, 180 }
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 220))
        nvgText(vg, cx, infoY, "当前: " .. (SEAL_QUALITY_NAMES[equipped.sealQ] or "?") .. " Lv." .. (equipped.level or 1), nil)
    else
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 100, 160, 150))
        nvgText(vg, cx, infoY, "当前: 空", nil)
    end

    -- 关闭按钮
    local closeBtnSize = 36
    local closeX = pX + pW - closeBtnSize - 8
    local closeY = pY + 8
    nvgBeginPath(vg); nvgRoundedRect(vg, closeX, closeY, closeBtnSize, closeBtnSize, 6)
    nvgFillColor(vg, nvgRGBA(50, 25, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(160, 100, 220, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(closeX + closeBtnSize / 2, closeY + closeBtnSize / 2, "X")
    sealReplaceBtnRects.close = { x = closeX, y = closeY, w = closeBtnSize, h = closeBtnSize }

    -- 仓库列表区域
    local listX = pX + 12
    local listY = infoY + 22
    local listW = pW - 24 - 14  -- 右边留14px给滚动条
    local listH = pH - (listY - pY) - 16
    local itemH = 80
    local itemGap = 6

    -- 获取所有兵符（按品质降序），高亮匹配项，其余半遮罩
    local allSeals = GetAllInventorySeals()
    sealReplaceListRects = {}

    if #allSeals == 0 then
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 110, 180, 120))
        nvgText(vg, cx, listY + listH / 2, "仓库中没有兵符", nil)
        return
    end

    -- 对列表排序：匹配的排前面，不匹配的排后面，各自内部按品质降序
    table.sort(allSeals, function(a, b)
        local aMatch = (a.seal.slotType == slotIdx and a.seal.fromHero == heroIdx) and 1 or 0
        local bMatch = (b.seal.slotType == slotIdx and b.seal.fromHero == heroIdx) and 1 or 0
        if aMatch ~= bMatch then return aMatch > bMatch end
        if a.seal.sealQ ~= b.seal.sealQ then return a.seal.sealQ > b.seal.sealQ end
        if a.seal.slotType ~= b.seal.slotType then return a.seal.slotType < b.seal.slotType end
        return a.seal.level > b.seal.level
    end)

    -- 统计匹配数量
    local matchCount = 0
    for _, e in ipairs(allSeals) do
        if e.seal.slotType == slotIdx and e.seal.fromHero == heroIdx then matchCount = matchCount + 1 end
    end

    -- 匹配/全部计数
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 140, 240, 160))
    nvgText(vg, pX + pW - 18, listY - 8, "匹配 " .. matchCount .. " / 全部 " .. #allSeals, nil)

    -- 内容总高度
    local contentH = #allSeals * (itemH + itemGap) - itemGap
    local maxScroll = math.max(0, contentH - listH)
    local scrollY = sealReplaceState.scroll.y
    scrollY = math.max(0, math.min(scrollY, maxScroll))
    sealReplaceState.scroll.y = scrollY
    sealReplaceState.scroll.contentH = contentH
    sealReplaceState.scroll.viewH = listH

    -- 裁剪区域
    nvgSave(vg)
    nvgScissor(vg, listX, listY, listW + 14, listH)

    -- 绘制列表项
    for i, entry in ipairs(allSeals) do
        local seal = entry.seal
        local iy = listY + (i - 1) * (itemH + itemGap) - scrollY
        -- 可见性检测
        if iy + itemH >= listY and iy <= listY + listH then
            local isMatch = (seal.slotType == slotIdx and seal.fromHero == heroIdx)
            local dimAlpha = isMatch and 1.0 or 0.35  -- 不匹配的整体降低透明度
            local sc = SEAL_QUALITY_COLORS[seal.sealQ] or { 180, 180, 180 }

            -- 项目背景
            nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 6)
            nvgFillColor(vg, nvgRGBA(28, 14, 45, math.floor(220 * dimAlpha))); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 6)
            nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], math.floor(100 * dimAlpha))); nvgStrokeWidth(vg, 1); nvgStroke(vg)

            -- 左侧: 六角形小图标
            local hexX = listX + 32
            local hexY = iy + itemH / 2
            local hexR = 22
            if isMatch then
                DrawSealHexIcon(hexX, hexY, hexR, sc, seal.sealQ)
            else
                -- 暗淡版六角形
                local dsc = { math.floor(sc[1] * 0.4), math.floor(sc[2] * 0.4), math.floor(sc[3] * 0.4) }
                DrawSealHexIcon(hexX, hexY, hexR, dsc, seal.sealQ)
            end
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if isMatch then
                DrawWhiteInkText(hexX, hexY + 2, "Lv." .. (seal.level or 1))
            else
                nvgFillColor(vg, nvgRGBA(180, 180, 180, 80))
                nvgText(vg, hexX, hexY + 2, "Lv." .. (seal.level or 1), nil)
            end

            -- 中间: 信息
            local infoX = listX + 68
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], math.floor(230 * dimAlpha)))
            nvgText(vg, infoX, iy + 18, (SEAL_QUALITY_NAMES[seal.sealQ] or "?") .. " " .. SEAL_SLOT_NAMES[seal.slotType], nil)

            -- 效果描述
            local eff = SEAL_SLOT_EFFECTS[seal.slotType]
            if eff then
                nvgFontSize(vg, 20)
                local effTC = SEAL_SLOT_THEME_COLORS[seal.slotType] or stc
                nvgFillColor(vg, nvgRGBA(effTC[1], effTC[2], effTC[3], math.floor(180 * dimAlpha)))
                local tierData = eff[seal.sealQ] or eff[1]
                local mainVal = (tierData.main or 0) * (seal.level or 1)
                local desc = eff.mainName .. string.format("+%.1f", mainVal)
                if eff.subKey and tierData.sub then
                    local subVal = tierData.sub * (seal.level or 1)
                    desc = desc .. "  " .. eff.subName .. string.format("+%.1f", subVal)
                end
                nvgText(vg, infoX, iy + 38, desc, nil)
            end

            -- 来源英雄
            if seal.fromHero and HERO_CARDS[seal.fromHero] then
                nvgFontSize(vg, 18)
                nvgFillColor(vg, nvgRGBA(140, 120, 180, math.floor((isMatch and 120 or 60) * 1)))
                local heroTag = HERO_CARDS[seal.fromHero].name
                if not isMatch then heroTag = heroTag .. (seal.slotType ~= slotIdx and " [孔位不同]" or " [其他武灵]") end
                nvgText(vg, infoX, iy + 54, "来源: " .. heroTag, nil)
            end

            -- 右侧按钮: 装备 / 分解
            local btnW = 52
            local btnH2 = 28
            local btnGap2 = 6
            local btnX = listX + listW - btnW - 8

            sealReplaceListRects[i] = sealReplaceListRects[i] or {}

            if isMatch then
                -- 装备按钮（仅匹配的兵符可装备）
                local equipBtnY = iy + (itemH / 2 - btnH2 - btnGap2 / 2)
                nvgBeginPath(vg); nvgRoundedRect(vg, btnX, equipBtnY, btnW, btnH2, 4)
                nvgFillColor(vg, nvgRGBA(40, 120, 80, 220)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 200, 120, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(btnX + btnW / 2, equipBtnY + btnH2 / 2, "装备")
                sealReplaceListRects[i].equip = { x = btnX, y = equipBtnY, w = btnW, h = btnH2, invIndex = entry.index }
            else
                -- 不匹配: 显示灰色禁用的装备按钮
                local equipBtnY = iy + (itemH / 2 - btnH2 - btnGap2 / 2)
                nvgBeginPath(vg); nvgRoundedRect(vg, btnX, equipBtnY, btnW, btnH2, 4)
                nvgFillColor(vg, nvgRGBA(30, 30, 30, 120)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80, 80, 80, 60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(120, 120, 120, 80))
                nvgText(vg, btnX + btnW / 2, equipBtnY + btnH2 / 2, "装备", nil)
                -- 不设置 equip rect，禁止点击
            end

            -- 分解按钮（所有兵符都可分解）
            local decompBtnY = iy + (itemH / 2 + btnGap2 / 2)
            nvgBeginPath(vg); nvgRoundedRect(vg, btnX, decompBtnY, btnW, btnH2, 4)
            nvgFillColor(vg, nvgRGBA(120, 40, 40, math.floor(220 * (isMatch and 1.0 or 0.6)))); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(200, 80, 80, math.floor(160 * (isMatch and 1.0 or 0.6)))); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            if isMatch then
                DrawWhiteInkText(btnX + btnW / 2, decompBtnY + btnH2 / 2, "分解")
            else
                nvgFillColor(vg, nvgRGBA(200, 160, 160, 140))
                nvgText(vg, btnX + btnW / 2, decompBtnY + btnH2 / 2, "分解", nil)
            end
            sealReplaceListRects[i].decompose = { x = btnX, y = decompBtnY, w = btnW, h = btnH2, invIndex = entry.index }

            -- 不匹配的兵符加半透明深色遮罩
            if not isMatch then
                nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 6)
                nvgFillColor(vg, nvgRGBA(8, 4, 18, 120)); nvgFill(vg)
            end
        end
    end

    nvgRestore(vg)

    -- 滚动条（粗，高可见度）
    if contentH > listH then
        local sbBarW = 8
        local sbX = pX + pW - sbBarW - 4
        local sbTotalH = listH
        local sbThumbH = math.max(30, sbTotalH * (listH / contentH))
        local sbThumbY = listY + (scrollY / maxScroll) * (sbTotalH - sbThumbH)

        -- 轨道
        nvgBeginPath(vg); nvgRoundedRect(vg, sbX, listY, sbBarW, sbTotalH, sbBarW / 2)
        nvgFillColor(vg, nvgRGBA(40, 20, 60, 100)); nvgFill(vg)

        -- 滑块
        nvgBeginPath(vg); nvgRoundedRect(vg, sbX, sbThumbY, sbBarW, sbThumbH, sbBarW / 2)
        nvgFillColor(vg, nvgRGBA(180, 120, 240, sealReplaceState.scroll.isDragging and 220 or 160)); nvgFill(vg)
    end
end


-- ============================================================================
-- 兵符分解确认弹窗绘制
-- ============================================================================
function DrawSealDecomposeConfirm()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    -- 半透明遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 3, 15, 200)); nvgFill(vg)

    -- 获取兵符信息
    local sealQ, slotType, sealLevel
    if sealDecomposeState.source == "inventory" and sealDecomposeState.invIndex then
        local invSeal = sealInventory[sealDecomposeState.invIndex]
        if not invSeal then sealDecomposeState.show = false; return end
        sealQ = invSeal.sealQ
        slotType = invSeal.slotType
        sealLevel = invSeal.level or 1
    elseif sealDecomposeState.source == "equipped" and sealDecomposeState.heroIdx and sealDecomposeState.slotIdx then
        local sd = sealData[sealDecomposeState.heroIdx]
        local slot = sd and sd.slots and sd.slots[sealDecomposeState.slotIdx]
        if not slot then sealDecomposeState.show = false; return end
        sealQ = slot.sealQ
        slotType = sealDecomposeState.slotIdx
        sealLevel = slot.level or 1
    else
        sealDecomposeState.show = false; return
    end

    local sc = SEAL_QUALITY_COLORS[sealQ] or { 180, 180, 180 }
    local qName = SEAL_QUALITY_NAMES[sealQ] or "?"

    -- 弹窗面板
    local pW = W * 0.78
    local pH = 300
    local pX = cx - pW / 2
    local pY = H / 2 - pH / 2

    local pGrad = nvgLinearGradient(vg, pX, pY, pX, pY + pH,
        nvgRGBA(50, 20, 30, 250), nvgRGBA(30, 12, 22, 252))
    nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
    nvgFillPaint(vg, pGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
    nvgStrokeColor(vg, nvgRGBA(220, 80, 80, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 标题
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, pY + 30, "确认分解")

    -- 兵符信息
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 240))
    nvgText(vg, cx, pY + 70, qName .. " " .. SEAL_SLOT_NAMES[slotType] .. " Lv." .. sealLevel, nil)

    -- 返还道具预览
    local returns = SEAL_DECOMPOSE_RETURNS[sealQ] or SEAL_DECOMPOSE_RETURNS[1]
    local retY = pY + 105
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, retY, "分解将获得:")
    retY = retY + 24
    for _, ret in ipairs(returns) do
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(200, 180, 255, 220))
        nvgText(vg, cx, retY, SEAL_EXP_ITEMS[ret.idx].name .. " x" .. ret.count, nil)
        retY = retY + 20
    end
    -- 额外经验返还提示
    if sealLevel > 1 then
        local extraExp = 0
        for lv = 1, sealLevel - 1 do extraExp = extraExp + (SEAL_EXP_TABLE[lv] or 0) end
        local extraCount = math.floor(extraExp / SEAL_EXP_ITEMS[1].exp)
        if extraCount > 0 then
            nvgFontSize(vg, 20)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 180))
            nvgText(vg, cx, retY, "+" .. SEAL_EXP_ITEMS[1].name .. " x" .. extraCount .. " (经验返还)", nil)
            retY = retY + 20
        end
    end

    -- 按钮区域
    local btnW = 110
    local btnH2 = 42
    local btnY = pY + pH - btnH2 - 24
    local btnGap = 30

    -- 确认按钮
    local confirmX = cx - btnW - btnGap / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, btnY, btnW, btnH2, 6)
    nvgFillColor(vg, nvgRGBA(160, 40, 40, 230)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 80, 80, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(confirmX + btnW / 2, btnY + btnH2 / 2, "确认分解")
    sealDecomposeBtnRects.confirm = { x = confirmX, y = btnY, w = btnW, h = btnH2 }

    -- 取消按钮
    local cancelX = cx + btnGap / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, btnY, btnW, btnH2, 6)
    nvgFillColor(vg, nvgRGBA(50, 35, 70, 230)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 90, 170, 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cancelX + btnW / 2, btnY + btnH2 / 2, "取消")
    sealDecomposeBtnRects.cancel = { x = cancelX, y = btnY, w = btnW, h = btnH2 }
end


-- ============================================================================
-- 兵符筛选分解确认弹窗
-- ============================================================================
function DrawSealBatchDecompConfirm()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    -- 遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 3, 15, 200)); nvgFill(vg)

    -- 弹窗面板
    local pW = W * 0.82
    local pH = 340
    local pX = cx - pW / 2
    local pY = H / 2 - pH / 2

    local pGrad = nvgLinearGradient(vg, pX, pY, pX, pY + pH,
        nvgRGBA(50, 20, 30, 250), nvgRGBA(30, 12, 22, 252))
    nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
    nvgFillPaint(vg, pGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
    nvgStrokeColor(vg, nvgRGBA(220, 80, 80, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, pY + 32, "筛选分解兵符")

    -- 品质筛选行
    local filterY = pY + 75
    local arrowW, arrowH = 32, 28
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 180, 220, 220))
    nvgText(vg, cx - 70, filterY, "品质上限:", nil)

    -- 左箭头
    local arrowLX = cx + 10
    nvgBeginPath(vg); nvgRoundedRect(vg, arrowLX, filterY - arrowH / 2, arrowW, arrowH, 4)
    nvgFillColor(vg, nvgRGBA(60, 40, 80, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(140, 100, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgText(vg, arrowLX + arrowW / 2, filterY, "<", nil)
    sealInvFilterBtnRects.tierLeft = { x = arrowLX, y = filterY - arrowH / 2, w = arrowW, h = arrowH }

    -- 当前品质
    local ft = sealInvFilterState.filterMaxTier
    local tierLabel = ft <= 7 and (SEAL_TIER_NAMES[ft] or "全部") or "全部"
    local tc = SEAL_QUALITY_COLORS[ft] or { 200, 200, 200 }
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
    nvgFontSize(vg, 24)
    nvgText(vg, cx + 70, filterY, tierLabel, nil)

    -- 右箭头
    local arrowRX = cx + 105
    nvgBeginPath(vg); nvgRoundedRect(vg, arrowRX, filterY - arrowH / 2, arrowW, arrowH, 4)
    nvgFillColor(vg, nvgRGBA(60, 40, 80, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(140, 100, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgText(vg, arrowRX + arrowW / 2, filterY, ">", nil)
    sealInvFilterBtnRects.tierRight = { x = arrowRX, y = filterY - arrowH / 2, w = arrowW, h = arrowH }

    -- 孔位筛选行
    local slotFilterY = filterY + 40
    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(200, 180, 220, 220))
    nvgText(vg, cx - 70, slotFilterY, "孔位筛选:", nil)

    local slotArrowLX = cx + 10
    nvgBeginPath(vg); nvgRoundedRect(vg, slotArrowLX, slotFilterY - arrowH / 2, arrowW, arrowH, 4)
    nvgFillColor(vg, nvgRGBA(60, 40, 80, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(140, 100, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgText(vg, slotArrowLX + arrowW / 2, slotFilterY, "<", nil)
    sealInvFilterBtnRects.slotLeft = { x = slotArrowLX, y = slotFilterY - arrowH / 2, w = arrowW, h = arrowH }

    local sf = sealInvFilterState.filterSlotType
    local slotLabel = sf == 0 and "全部" or SEAL_SLOT_NAMES[sf]
    local slotC = sf > 0 and (SEAL_SLOT_THEME_COLORS[sf] or { 200, 160, 255 }) or { 200, 200, 200 }
    nvgFillColor(vg, nvgRGBA(slotC[1], slotC[2], slotC[3], 240))
    nvgFontSize(vg, 24)
    nvgText(vg, cx + 70, slotFilterY, slotLabel, nil)

    local slotArrowRX = cx + 105
    nvgBeginPath(vg); nvgRoundedRect(vg, slotArrowRX, slotFilterY - arrowH / 2, arrowW, arrowH, 4)
    nvgFillColor(vg, nvgRGBA(60, 40, 80, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(140, 100, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgText(vg, slotArrowRX + arrowW / 2, slotFilterY, ">", nil)
    sealInvFilterBtnRects.slotRight = { x = slotArrowRX, y = slotFilterY - arrowH / 2, w = arrowW, h = arrowH }

    -- 分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, pX + 20, slotFilterY + 22)
    nvgLineTo(vg, pX + pW - 20, slotFilterY + 22)
    nvgStrokeColor(vg, nvgRGBA(100, 60, 140, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 统计
    local bdc, bdReturns = CalcSealBatchDecomp(ft, sf)
    local statY = slotFilterY + 42
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 180, 220, 220))
    nvgText(vg, cx, statY, "将分解 " .. bdc .. " 件仓库兵符", nil)
    if bdc > 0 then
        local parts = {}
        for idx = 1, #SEAL_EXP_ITEMS do
            if bdReturns[idx] and bdReturns[idx] > 0 then
                table.insert(parts, SEAL_EXP_ITEMS[idx].name .. "x" .. bdReturns[idx])
            end
        end
        if #parts > 0 then
            nvgFontSize(vg, 22)
            nvgFillColor(vg, nvgRGBA(200, 180, 255, 180))
            nvgText(vg, cx, statY + 22, "返还: " .. table.concat(parts, " "), nil)
        end
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(255, 130, 80, 200))
        nvgText(vg, cx, statY + 46, "此操作不可撤销!", nil)
    else
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(140, 120, 180, 140))
        nvgText(vg, cx, statY + 22, "当前筛选无可分解兵符", nil)
    end

    -- 按钮
    local btnW = 110
    local btnH2 = 40
    local btnY = pY + pH - btnH2 - 20
    local btnGap = 30

    -- 确认按钮
    local confirmX = cx - btnW - btnGap / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, btnY, btnW, btnH2, 6)
    if bdc > 0 then
        nvgFillColor(vg, nvgRGBA(160, 40, 40, 230)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(220, 80, 80, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    else
        nvgFillColor(vg, nvgRGBA(60, 40, 50, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 70, 90, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(confirmX + btnW / 2, btnY + btnH2 / 2, "确认分解")
    sealInvFilterBtnRects.batchConfirm = bdc > 0 and { x = confirmX, y = btnY, w = btnW, h = btnH2 } or nil

    -- 取消按钮
    local cancelX = cx + btnGap / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, btnY, btnW, btnH2, 6)
    nvgFillColor(vg, nvgRGBA(50, 35, 70, 230)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 90, 170, 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 18)
    DrawWhiteInkText(cancelX + btnW / 2, btnY + btnH2 / 2, "取消")
    sealInvFilterBtnRects.batchCancel = { x = cancelX, y = btnY, w = btnW, h = btnH2 }
end


-- ============================================================================
-- 兵符选中分解模式 - 全屏仓库列表
-- ============================================================================
function DrawSealSelectModeList()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    nvgFontFaceId(vg, GetMainFont())

    -- 提示标题
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 200))
    nvgText(vg, cx, 82, "点击选中要分解的兵符", nil)

    -- 列表区域
    local listX = 14
    local listY = 100
    local listW = W - 28
    local listH = H - listY - 60  -- 底部留操作栏
    local itemH = 62
    local itemGap = 4

    local allSeals = GetAllInventorySeals()
    sealInvFilterBtnRects.selectItems = {}

    if #allSeals == 0 then
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 120, 180, 120))
        nvgText(vg, cx, listY + listH / 2, "仓库中没有兵符", nil)
    else
        -- 滚动
        local contentH = #allSeals * (itemH + itemGap) - itemGap
        local maxScroll = math.max(0, contentH - listH)
        local scrollY = math.max(0, math.min(sealMgrScroll.y or 0, maxScroll))
        sealMgrScroll.y = scrollY
        sealMgrScroll.contentH = contentH
        sealMgrScroll.viewH = listH

        nvgSave(vg)
        nvgScissor(vg, listX, listY, listW, listH)

        for fi, entry in ipairs(allSeals) do
            local seal = entry.seal
            local invIdx = entry.index
            local iy = listY + (fi - 1) * (itemH + itemGap) - scrollY

            if iy + itemH >= listY and iy <= listY + listH then
                local sc = SEAL_QUALITY_COLORS[seal.sealQ] or { 180, 180, 180 }
                local isSelected = sealInvFilterState.selectedIds[invIdx] == true

                -- 背景
                nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 6)
                if isSelected then
                    nvgFillColor(vg, nvgRGBA(60, 30, 30, 230)); nvgFill(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 6)
                    nvgStrokeColor(vg, nvgRGBA(220, 100, 80, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                else
                    nvgFillColor(vg, nvgRGBA(28, 14, 45, 220)); nvgFill(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, listX, iy, listW, itemH, 6)
                    nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 80)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
                end

                -- 勾选框
                local cbSize = 22
                local cbX = listX + 10
                local cbY = iy + itemH / 2 - cbSize / 2
                nvgBeginPath(vg); nvgRoundedRect(vg, cbX, cbY, cbSize, cbSize, 4)
                if isSelected then
                    nvgFillColor(vg, nvgRGBA(200, 60, 60, 230)); nvgFill(vg)
                    nvgFontSize(vg, 24)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
                    nvgText(vg, cbX + cbSize / 2, cbY + cbSize / 2, "✓", nil)
                else
                    nvgFillColor(vg, nvgRGBA(40, 25, 60, 200)); nvgFill(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, cbX, cbY, cbSize, cbSize, 4)
                    nvgStrokeColor(vg, nvgRGBA(120, 90, 170, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                end

                -- 六角图标
                local hexX = cbX + cbSize + 18
                local hexY = iy + itemH / 2
                DrawSealHexIcon(hexX, hexY, 18, sc, seal.sealQ)
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(hexX, hexY + 2, "Lv." .. (seal.level or 1))

                -- 信息
                local infoX = hexX + 28
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 230))
                nvgText(vg, infoX, iy + 18, (SEAL_QUALITY_NAMES[seal.sealQ] or "?") .. " " .. SEAL_SLOT_NAMES[seal.slotType], nil)

                -- 属性简述
                local stc = SEAL_SLOT_THEME_COLORS[seal.slotType] or { 200, 160, 255 }
                local eff = SEAL_SLOT_EFFECTS[seal.slotType]
                if eff then
                    nvgFontSize(vg, 18)
                    nvgFillColor(vg, nvgRGBA(stc[1], stc[2], stc[3], 180))
                    local tierData = eff[seal.sealQ] or eff[1]
                    local mainVal = (tierData.main or 0) * (seal.level or 1)
                    nvgText(vg, infoX, iy + 36, eff.mainName .. string.format("+%.1f", mainVal), nil)
                end

                -- 来源
                if seal.fromHero and HERO_CARDS[seal.fromHero] then
                    nvgFontSize(vg, 18)
                    nvgFillColor(vg, nvgRGBA(140, 120, 180, 100))
                    nvgText(vg, infoX, iy + 50, "来源: " .. HERO_CARDS[seal.fromHero].name, nil)
                end

                -- 返还预览 (右侧)
                local returns = SEAL_DECOMPOSE_RETURNS[seal.sealQ] or SEAL_DECOMPOSE_RETURNS[1]
                local retParts = {}
                for _, ret in ipairs(returns) do
                    table.insert(retParts, SEAL_EXP_ITEMS[ret.idx].name:sub(1, 6) .. "x" .. ret.count)
                end
                nvgFontSize(vg, 18)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(180, 160, 220, 140))
                nvgText(vg, listX + listW - 8, iy + itemH / 2, table.concat(retParts, " "), nil)

                -- 点击区域
                sealInvFilterBtnRects.selectItems[fi] = { x = listX, y = iy, w = listW, h = itemH, invIndex = invIdx }
            end
        end

        nvgRestore(vg)

        -- 滚动条（粗，高可见度）
        if contentH > listH then
            local sbBarW = 8
            local sbX = W - sbBarW - 4
            local sbThumbH = math.max(30, listH * (listH / contentH))
            local sbThumbY = listY + (scrollY / maxScroll) * (listH - sbThumbH)
            -- 轨道
            nvgBeginPath(vg); nvgRoundedRect(vg, sbX, listY, sbBarW, listH, sbBarW / 2)
            nvgFillColor(vg, nvgRGBA(40, 20, 60, 100)); nvgFill(vg)
            -- 滑块
            nvgBeginPath(vg); nvgRoundedRect(vg, sbX, sbThumbY, sbBarW, sbThumbH, sbBarW / 2)
            nvgFillColor(vg, nvgRGBA(180, 120, 240, sealMgrScroll.isDragging and 220 or 160)); nvgFill(vg)
        end
    end

    -- ========== 底部操作栏 ==========
    local barH = 50
    local barY = H - barH
    nvgBeginPath(vg); nvgRect(vg, 0, barY, W, barH)
    nvgFillColor(vg, nvgRGBA(20, 10, 35, 240)); nvgFill(vg)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, barY); nvgLineTo(vg, W, barY)
    nvgStrokeColor(vg, nvgRGBA(100, 60, 160, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 已选数量
    local selCount = 0
    for _ in pairs(sealInvFilterState.selectedIds) do selCount = selCount + 1 end
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 180, 255, 200))
    nvgText(vg, 14, barY + barH / 2, "已选 " .. selCount .. " 件", nil)

    -- 按钮
    local sbW2 = 76
    local sbH = 34
    local sbY = barY + (barH - sbH) / 2
    local sbGap = 8

    -- 全选
    local allX = W - 14 - sbW2 * 3 - sbGap * 2
    nvgBeginPath(vg); nvgRoundedRect(vg, allX, sbY, sbW2, sbH, 5)
    nvgFillColor(vg, nvgRGBA(50, 50, 90, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 100, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(allX + sbW2 / 2, sbY + sbH / 2, "全选")
    sealInvFilterBtnRects.selectAll = { x = allX, y = sbY, w = sbW2, h = sbH }

    -- 确认分解
    local confirmX = allX + sbW2 + sbGap
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, sbY, sbW2, sbH, 5)
    if selCount > 0 then
        nvgFillColor(vg, nvgRGBA(160, 40, 40, 230)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(220, 80, 80, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    else
        nvgFillColor(vg, nvgRGBA(60, 30, 40, 180)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 60, 70, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end
    nvgFontSize(vg, 22)
    DrawWhiteInkText(confirmX + sbW2 / 2, sbY + sbH / 2, "分解")
    sealInvFilterBtnRects.selectDoDecomp = { x = confirmX, y = sbY, w = sbW2, h = sbH }

    -- 取消
    local cancelX = confirmX + sbW2 + sbGap
    nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, sbY, sbW2, sbH, 5)
    nvgFillColor(vg, nvgRGBA(50, 35, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 90, 170, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 22)
    DrawWhiteInkText(cancelX + sbW2 / 2, sbY + sbH / 2, "取消")
    sealInvFilterBtnRects.selectCancelMode = { x = cancelX, y = sbY, w = sbW2, h = sbH }
end


-- ============================================================================
-- 兵符选中分解确认弹窗
-- ============================================================================
function DrawSealSelectDecompConfirm()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2

    -- 遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 3, 15, 210)); nvgFill(vg)

    local selCount, selReturns = CalcSealSelectDecomp(sealInvFilterState.selectedIds)

    -- 弹窗面板
    local pW = W * 0.78
    local pH = 240
    local pX = cx - pW / 2
    local pY = H / 2 - pH / 2

    local pGrad = nvgLinearGradient(vg, pX, pY, pX, pY + pH,
        nvgRGBA(50, 20, 30, 250), nvgRGBA(30, 12, 22, 252))
    nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
    nvgFillPaint(vg, pGrad); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, pX, pY, pW, pH, 12)
    nvgStrokeColor(vg, nvgRGBA(220, 80, 80, 160)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, pY + 32, "确认分解选中兵符？")

    nvgFontSize(vg, 24)
    nvgFillColor(vg, nvgRGBA(200, 180, 220, 220))
    nvgText(vg, cx, pY + 68, "将分解 " .. selCount .. " 件兵符", nil)

    -- 返还预览
    local parts = {}
    for idx = 1, #SEAL_EXP_ITEMS do
        if selReturns[idx] and selReturns[idx] > 0 then
            table.insert(parts, SEAL_EXP_ITEMS[idx].name .. "x" .. selReturns[idx])
        end
    end
    if #parts > 0 then
        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(200, 180, 255, 180))
        nvgText(vg, cx, pY + 95, "返还: " .. table.concat(parts, " "), nil)
    end
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(255, 130, 80, 200))
    nvgText(vg, cx, pY + 120, "此操作不可撤销!", nil)

    -- 按钮
    local btnW = 110
    local btnH2 = 40
    local btnY = pY + pH - btnH2 - 20
    local btnGap = 30

    local confirmX = cx - btnW - btnGap / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, confirmX, btnY, btnW, btnH2, 6)
    nvgFillColor(vg, nvgRGBA(160, 40, 40, 230)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(220, 80, 80, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(confirmX + btnW / 2, btnY + btnH2 / 2, "确认分解")
    sealInvFilterBtnRects.selectConfirm = { x = confirmX, y = btnY, w = btnW, h = btnH2 }

    local cancelX = cx + btnGap / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, cancelX, btnY, btnW, btnH2, 6)
    nvgFillColor(vg, nvgRGBA(50, 35, 70, 230)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 90, 170, 150)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 18)
    DrawWhiteInkText(cancelX + btnW / 2, btnY + btnH2 / 2, "取消")
    sealInvFilterBtnRects.selectCancel = { x = cancelX, y = btnY, w = btnW, h = btnH2 }
end
