-- ============================================================================
-- ui/settings.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 设置界面 (设计坐标, 覆盖在菜单上方)
-- ============================================================================
function DrawSettingsScreen()
    local W = DESIGN_W
    local H = DESIGN_H
    local cx = W / 2
    local t = gameState.gameTime

    -- 半透明全屏遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 95)); nvgFill(vg)

    -- 设置面板 (横屏适配: 宽面板+紧凑行距)
    local panW = 520
    local panH = 480
    local panX = cx - panW / 2
    local panY = (H - panH) / 2

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 8)
    nvgFillColor(vg, nvgRGBA(30, 38, 58, 220)); nvgFill(vg)
    -- 铜色边框
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 8)
    nvgStrokeWidth(vg, 2)
    nvgStrokeColor(vg, nvgRGBA(162, 128, 78, 200)); nvgStroke(vg)

    nvgFontFaceId(vg, GetMainFont())

    -- 金币结算?
    nvgFontSize(vg, 30)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cx, panY + 32, "设置")

    -- UID 显示 + 一键复制按钮 (分隔线下方独立行)
    local leftM = panX + 24
    local rightM = panX + panW - 24
    local uidRowY = panY + 80
    do
        local uid = CloudAPI.GetUserId()  -- 内部已含全部 fallback
        local uidStr = uid ~= 0 and tostring(uid) or "---"
        -- UID 标签 + 数值
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 135, 120, 180))
        nvgText(vg, leftM, uidRowY, "UID:", nil)
        nvgFillColor(vg, nvgRGBA(220, 215, 200, 230))
        nvgText(vg, leftM + 40, uidRowY, uidStr, nil)
        -- 复制按钮
        local cpBtnW, cpBtnH = 60, 28
        local cpBtnX = leftM + 40 + nvgTextBounds(vg, 0, 0, uidStr, nil) + 10
        local cpBtnY = uidRowY - cpBtnH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, cpBtnX, cpBtnY, cpBtnW, cpBtnH, 4)
        -- 复制成功闪烁效果
        local copyFlash = settingsPage.uidCopyTimer and settingsPage.uidCopyTimer > 0
        if copyFlash then
            nvgFillColor(vg, nvgRGBA(60, 160, 80, 220))
        else
            nvgFillColor(vg, nvgRGBA(60, 80, 120, 200))
        end
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(100, 140, 200, 150)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 230, 255, 230))
        nvgText(vg, cpBtnX + cpBtnW / 2, cpBtnY + cpBtnH / 2, copyFlash and "已复制" or "复制", nil)
        settingsPage.uidCopyBtnRect = { x = cpBtnX, y = cpBtnY, w = cpBtnW, h = cpBtnH }
        settingsPage.uidValue = uidStr
        -- 复制成功提示计时衰减
        if settingsPage.uidCopyTimer and settingsPage.uidCopyTimer > 0 then
            settingsPage.uidCopyTimer = settingsPage.uidCopyTimer - (1.0 / 60.0)
        end
    end

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, panX + 20, panY + 56)
    nvgLineTo(vg, panX + panW - 20, panY + 56)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local contentW = rightM - leftM
    local rowY = panY + 100
    local rowGap = 46

    -- ======== 音乐音量 ========
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "音乐")

    local sliderX = leftM + 80
    local sliderW = contentW - 80
    local sliderH = 8
    local sliderY = rowY - sliderH / 2
    -- 滑条背景
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, sliderY, sliderW, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
    -- 滑条填充
    local musicFill = sliderW * gameSettings.musicVolume
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, sliderY, musicFill, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(120, 50, 55, 200)); nvgFill(vg)
    -- 滑块
    local knobX = sliderX + musicFill
    nvgBeginPath(vg); nvgCircle(vg, knobX, rowY, 8)
    nvgFillColor(vg, nvgRGBA(200, 180, 190, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    -- 百分比 (显示在滑条右端上方)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    DrawWhiteInkText(rightM, rowY - 10, math.floor(gameSettings.musicVolume * 100) .. "%")
    settingsPage.musicSliderRect = { x = sliderX, y = sliderY - 10, w = sliderW, h = sliderH + 20 }

    -- ======== 音效音量 ========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "音效")

    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, rowY - sliderH / 2, sliderW, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
    local sfxFill = sliderW * gameSettings.sfxVolume
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, rowY - sliderH / 2, sfxFill, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(120, 50, 55, 200)); nvgFill(vg)
    local sfxKnobX = sliderX + sfxFill
    nvgBeginPath(vg); nvgCircle(vg, sfxKnobX, rowY, 8)
    nvgFillColor(vg, nvgRGBA(200, 180, 190, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    DrawWhiteInkText(rightM, rowY - 10, math.floor(gameSettings.sfxVolume * 100) .. "%")
    settingsPage.sfxSliderRect = { x = sliderX, y = rowY - sliderH / 2 - 10, w = sliderW, h = sliderH + 20 }

    -- ======== 精灵上限 ========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "精灵")

    local spLimit = gameSettings.spriteLimit or 1000
    local spMin, spMax = 500, 5000
    local spRatio = (spLimit - spMin) / (spMax - spMin)
    -- 滑条背景
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, rowY - sliderH / 2, sliderW, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(40, 45, 60, 200)); nvgFill(vg)
    -- 滑条填充
    local spFill = sliderW * spRatio
    nvgBeginPath(vg); nvgRoundedRect(vg, sliderX, rowY - sliderH / 2, spFill, sliderH, 4)
    nvgFillColor(vg, nvgRGBA(50, 120, 80, 200)); nvgFill(vg)
    -- 滑块
    local spKnobX = sliderX + spFill
    nvgBeginPath(vg); nvgCircle(vg, spKnobX, rowY, 8)
    nvgFillColor(vg, nvgRGBA(180, 220, 190, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(50, 100, 70, 200)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    -- 数值 + 比例说明
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    DrawWhiteInkText(rightM, rowY - 10, tostring(spLimit))
    -- "1精灵≈N人" 提示 (滑条下方)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(160, 155, 140, 150))
    nvgText(vg, sliderX, rowY + sliderH / 2 + 3,
        "每方上限" .. spLimit .. "精灵  (值越大画面越密集)", nil)
    settingsPage.spriteLimitSliderRect = { x = sliderX, y = rowY - sliderH / 2 - 10, w = sliderW, h = sliderH + 20 }

    -- ======== CDK 兑换 ========
    rowY = rowY + rowGap
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(leftM, rowY, "CDK兑换")

    local cdkBtnW = 80
    local cdkBtnH = 32
    local cdkBtnX = rightM - cdkBtnW
    local cdkBtnY = rowY - cdkBtnH / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, cdkBtnX, cdkBtnY, cdkBtnW, cdkBtnH, 6)
    nvgFillPaint(vg, nvgLinearGradient(vg, cdkBtnX, cdkBtnY, cdkBtnX, cdkBtnY + cdkBtnH,
        nvgRGBA(80, 140, 180, 220), nvgRGBA(50, 100, 140, 220)))
    nvgFill(vg)
    nvgFontSize(vg, 25)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(cdkBtnX + cdkBtnW / 2, cdkBtnY + cdkBtnH / 2, "兑换码")
    settingsPage.cdkBtnRect = { x = cdkBtnX, y = cdkBtnY, w = cdkBtnW, h = cdkBtnH }

    -- ======== 关闭按钮 ========
    local btnRowY = panY + panH - 48
    local closeBtnW = 100
    local closeBtnH = 36
    local closeBtnX = cx - closeBtnW / 2
    nvgBeginPath(vg); nvgRoundedRect(vg, closeBtnX, btnRowY, closeBtnW, closeBtnH, 6)
    nvgFillColor(vg, nvgRGBA(50, 45, 60, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 27)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(closeBtnX + closeBtnW / 2, btnRowY + closeBtnH / 2, "关闭")
    settingsPage.closeBtnRect = { x = closeBtnX, y = btnRowY, w = closeBtnW, h = closeBtnH }
end


-- ============================================================================
-- CDK 兑换弹窗 (使用原生键盘输入)
-- ============================================================================
function DrawCDKPopup()
    if not cdkState.inputOpen then return end
    local W = DESIGN_W
    local H = DESIGN_H
    -- 遮罩
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(5, 5, 12, 130)); nvgFill(vg)

    -- 紧凑弹窗面板
    local pw, ph = 420, 200
    local px = (W - pw) / 2
    local py = (H - ph) / 2 - 80  -- 偏上，给原生键盘留空间
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(30, 28, 40, 240)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 180)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 金币结算?
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(px + pw / 2, py + 24, "输入兑换码")

    -- 输入框
    local inputX = px + 20
    local inputY = py + 50
    local inputW = pw - 40
    local inputH = 46
    nvgBeginPath(vg); nvgRoundedRect(vg, inputX, inputY, inputW, inputH, 6)
    nvgFillColor(vg, nvgRGBA(15, 14, 22, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 80, 50, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    cdkState.inputBoxRect = { x = inputX, y = inputY, w = inputW, h = inputH }
    -- 输入文字 / 占位符
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local textY = inputY + inputH / 2
    if #cdkState.inputText > 0 then
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, inputX + 10, textY, cdkState.inputText, nil)
        -- 光标闪烁
        if math.floor(os.clock() * 2) % 2 == 0 then
            local tw = nvgTextBounds(vg, 0, 0, cdkState.inputText, nil)
            nvgBeginPath(vg); nvgRect(vg, inputX + 10 + tw + 2, inputY + 8, 2, inputH - 16)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 200)); nvgFill(vg)
        end
    else
        nvgFillColor(vg, nvgRGBA(150, 140, 130, 120))
        nvgText(vg, inputX + 10, textY, "请输入兑换码", nil)
        -- 光标
        if math.floor(os.clock() * 2) % 2 == 0 then
            nvgBeginPath(vg); nvgRect(vg, inputX + 10, inputY + 8, 2, inputH - 16)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 200)); nvgFill(vg)
        end
    end

    -- 结果反馈 (在输入框下方)
    local feedbackY = inputY + inputH + 4
    if cdkState.resultTimer > 0 then
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if cdkState.resultOk then
            nvgFillColor(vg, nvgRGBA(80, 230, 80, 230))
        else
            nvgFillColor(vg, nvgRGBA(255, 80, 80, 230))
        end
        nvgText(vg, W / 2, feedbackY + 8, cdkState.resultText, nil)
    end

    -- ======== 按钮行: 粘贴 | 清空 | 兑换 | 关闭 ========
    local btnY = inputY + inputH + 32
    local btnH = 42
    local btnGap = 8
    local btnTotalW = pw - 40
    local btnStartX = px + 20
    -- 4个按钮均分宽度
    local btnW = math.floor((btnTotalW - btnGap * 3) / 4)

    -- 粘贴
    local pasteX = btnStartX
    nvgBeginPath(vg); nvgRoundedRect(vg, pasteX, btnY, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(50, 80, 120, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 150, 200, 140)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawWhiteInkText(pasteX + btnW / 2, btnY + btnH / 2, "粘贴")
    cdkState.pasteBtnRect = { x = pasteX, y = btnY, w = btnW, h = btnH }

    -- 清空
    local clearX = pasteX + btnW + btnGap
    nvgBeginPath(vg); nvgRoundedRect(vg, clearX, btnY, btnW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 55, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(clearX + btnW / 2, btnY + btnH / 2, "清空")
    cdkState.clearBtnRect = { x = clearX, y = btnY, w = btnW, h = btnH }

    -- 兑换
    local redeemX = clearX + btnW + btnGap
    nvgBeginPath(vg); nvgRoundedRect(vg, redeemX, btnY, btnW, btnH, 6)
    nvgFillPaint(vg, nvgLinearGradient(vg, redeemX, btnY, redeemX, btnY + btnH,
        nvgRGBA(160, 120, 40, 230), nvgRGBA(120, 80, 20, 230)))
    nvgFill(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(redeemX + btnW / 2, btnY + btnH / 2, "兑换")
    cdkState.redeemBtnRect = { x = redeemX, y = btnY, w = btnW, h = btnH }

    -- 关闭按钮
    local closeX = redeemX + btnW + btnGap
    local closeW = btnStartX + btnTotalW - closeX  -- 最后一个按钮吃掉余量
    nvgBeginPath(vg); nvgRoundedRect(vg, closeX, btnY, closeW, btnH, 6)
    nvgFillColor(vg, nvgRGBA(60, 55, 70, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(90, 45, 55, 100)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 20)
    DrawWhiteInkText(closeX + closeW / 2, btnY + btnH / 2, "关闭")
    cdkState.closeBtnRect = { x = closeX, y = btnY, w = closeW, h = btnH }
end

