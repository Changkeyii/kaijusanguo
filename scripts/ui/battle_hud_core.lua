-- ui/battle_hud_core.lua - 涓夊浗姝︾伒褰?(浠?battle_hud.lua 鎷嗗垎)
-- ============================================================================
-- ui/battle_hud.lua - 涓夊浗姝︾伒褰?
-- ============================================================================


--- 缁樺埗鎶€鑳藉簭鍒楀抚鐨勫崟甯?(璁捐鍧愭爣)
function DrawSkillFrame(cx, cy, renderW, frameIdx, alpha, techIdx)
    -- 鏍规嵁鎶€鑳界殑 iconIdx 鏌ユ壘瀵瑰簲鐨?FX 绮剧伒鍥?
    local skill = techIdx and SKILL_DEFS[techIdx]
    local iconIdx = skill and skill.iconIdx or 20
    local fxData = SKILL_FX_SHEETS[iconIdx]

    -- 鏈変笓灞炵簿鐏靛浘 >> 鐢?crop-aware 娓叉煋
    if fxData and fxData.handle > 0 then
        local cols = fxData.cols
        local rows = fxData.rows
        local totalFrames = fxData.frames
        local fi = math.min(frameIdx % totalFrames, totalFrames - 1)
        local fcol = fi % cols
        local frow = math.floor(fi / cols)
        local crop = fxData.crop

        local imgW, imgH = nvgImageSize(vg, fxData.handle)
        local cellW = imgW / cols
        local cellH = imgH / rows

        -- crop 鍊煎熀浜庡師濮嬪浘鐗囧昂瀵? 闇€鎸夊疄闄呭昂瀵哥缉鏀?
        local cropScale = fxData.origW and (imgW / fxData.origW) or 1
        local srcX = fcol * cellW + crop.x * cropScale
        local srcY = frow * cellH + crop.y * cropScale
        local srcW = crop.w * cropScale
        local srcH = crop.h * cropScale

        -- 鎸夊搴︾缉鏀? 纭繚鍙瀹藉害 == renderW (鍖归厤鐬勫噯鍦堢洿寰?
        local contentScale = renderW / srcW
        local scaledW = renderW
        local scaledH = srcH * contentScale
        local centeredX = cx - scaledW / 2
        local centeredY = cy - scaledH / 2

        -- 閫愬抚瑙嗚涓績鏍℃ (娑堥櫎搴忓垪甯ф姈鍔?
        local offsets = fxData.frameOffsets
        if offsets then
            local fo = offsets[fi + 1]  -- Lua 1-based
            if fo then
                centeredX = centeredX + fo[1] * contentScale
                centeredY = centeredY + fo[2] * contentScale
            end
        end

        local patX = centeredX - srcX * contentScale
        local patY = centeredY - srcY * contentScale

        local pat = nvgImagePattern(vg, patX, patY, imgW * contentScale, imgH * contentScale, 0, fxData.handle, alpha)
        nvgBeginPath(vg)
        nvgRect(vg, centeredX, centeredY, scaledW, scaledH)
        nvgFillPaint(vg, pat)
        nvgFill(vg)
        return
    end

    -- 鏃犱笓灞炵簿鐏靛浘 >> 閫氱敤绮掑瓙鐖嗗彂鏁堟灉 (鍩轰簬鎶€鑳介鑹?
    local sc = skill and skill.color or { 255, 160, 60 }
    local progress = frameIdx / 15  -- 0~1
    local burstR = renderW * 0.4 * (0.3 + progress * 0.7)
    local burstAlpha = math.floor(255 * alpha * (1.0 - progress * 0.6))
    -- 澶栧湀鍏夋檿
    local glow = nvgRadialGradient(vg, cx, cy, burstR * 0.2, burstR,
        nvgRGBA(sc[1], sc[2], sc[3], math.floor(burstAlpha * 0.6)),
        nvgRGBA(sc[1], sc[2], sc[3], 0))
    nvgBeginPath(vg); nvgCircle(vg, cx, cy, burstR)
    nvgFillPaint(vg, glow); nvgFill(vg)
    -- 鍐呮牳
    local coreR = burstR * 0.3
    local coreGlow = nvgRadialGradient(vg, cx, cy, 0, coreR,
        nvgRGBA(255, 255, 255, math.floor(burstAlpha * 0.8)),
        nvgRGBA(sc[1], sc[2], sc[3], math.floor(burstAlpha * 0.3)))
    nvgBeginPath(vg); nvgCircle(vg, cx, cy, coreR)
    nvgFillPaint(vg, coreGlow); nvgFill(vg)
end


--- 缁樺埗搴曞眰鎶€鑳界壒鏁?(renderBehind=true, 鍦?DrawBattleUnits 涔嬪墠璋冪敤)
function DrawGroundSkillEffects()
    for _, eff in ipairs(activeSkillEffects) do
        local skill = SKILL_DEFS[eff.skillIdx]
        if not skill or not skill.renderBehind then goto continue end

        local progress = eff.timer / eff.duration
        -- alpha: 娓愬叆娓愬嚭
        local alpha = 1.0
        if progress < 0.15 then
            alpha = progress / 0.15
        elseif progress > 0.75 then
            alpha = (1.0 - progress) / 0.25
        end
        alpha = math.max(0, math.min(1, alpha))

        local sc = skill.color
        -- ======== 搴曞眰娓叉煋: 鏌斿拰鍏夊湀 + 搴忓垪甯?========
        local glowPulse = 0.4 + 0.3 * math.sin(eff.timer * 4)  -- 缂撴參鍛煎惛
        local isRectBehind = skill.skillType == "rect" and skill.rectW

        if isRectBehind then
            -- 鐭╁舰鎶€鑳藉簳灞? 鐭╁舰鍏夊湀
            local rw = skill.rectW * (0.7 + progress * 0.3)
            local rh = skill.rectH * (0.7 + progress * 0.3)
            local rx, ry = eff.x - rw / 2, eff.y - rh / 2
            local groundGlow = nvgBoxGradient(vg, rx, ry, rw, rh, 10, rw * 0.3,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(35 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgRoundedRect(vg, rx - rw * 0.15, ry - rh * 0.15, rw * 1.3, rh * 1.3, 10)
            nvgFillPaint(vg, groundGlow); nvgFill(vg)
            -- 搴忓垪甯?
            DrawSkillFrame(eff.x, eff.y, rw, eff.frameIdx, alpha * 0.85, eff.skillIdx)
        else
            -- 鍦嗗舰鎶€鑳藉簳灞? 鍦嗗舰鍏夊湀 (娌荤枟/鍖哄煙)
            local glowR = skill.radius * (0.7 + progress * 0.3)

            -- 搴曞眰鏌斿厜鍦?(鏇村ぇ鑼冨洿, 浣庨€忔槑搴?
            local groundGlow = nvgRadialGradient(vg, eff.x, eff.y, glowR * 0.1, glowR * 1.2,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(35 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, eff.x, eff.y, glowR * 1.2)
            nvgFillPaint(vg, groundGlow); nvgFill(vg)

            -- 鍐呭眰鍏夊湀 (杈冧寒)
            local innerGlow = nvgRadialGradient(vg, eff.x, eff.y, glowR * 0.05, glowR * 0.7,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(50 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, eff.x, eff.y, glowR * 0.7)
            nvgFillPaint(vg, innerGlow); nvgFill(vg)

            -- 搴忓垪甯у姩鐢?
            local effectDiameter = skill.radius * 2
            DrawSkillFrame(eff.x, eff.y, effectDiameter * (0.7 + progress * 0.3), eff.frameIdx, alpha * 0.85, eff.skillIdx)
        end

        ::continue::
    end
end


--- 缁樺埗鎵€鏈夋椿璺冪殑鎶€鑳界壒鏁?(璁捐鍧愭爣, 鍦?DrawBattleUnits 涔嬪悗璋冪敤)
function DrawSkillEffects()
    for _, eff in ipairs(activeSkillEffects) do
        local skill = SKILL_DEFS[eff.skillIdx]
        if not skill then goto continue end
        -- renderBehind 鏁堟灉宸插湪 DrawGroundSkillEffects 涓粯鍒?
        if skill.renderBehind then goto continue end
        local progress = eff.timer / eff.duration
        -- alpha: 娓愬叆娓愬嚭
        local alpha = 1.0
        if progress < 0.15 then
            alpha = progress / 0.15
        elseif progress > 0.75 then
            alpha = (1.0 - progress) / 0.25
        end
        alpha = math.max(0, math.min(1, alpha))

        local sc = skill.color

        if eff.isLine then
            -- ======== 绾垮瀷鎶€鑳芥覆鏌? 妯悜鍏夊甫灏捐抗 ========
            local halfH = (skill.lineWidth or 50) / 2
            local trailLen = 80  -- 灏捐抗闀垮害

            -- 鍏夊甫涓讳綋 (妯睆: 娌縓杞撮琛? 浠庡綋鍓嶄綅缃悜鍚庢嫋灏?
            local headX = eff.x
            local tailX
            if eff.isEnemySkill then
                tailX = math.min(headX + trailLen, BATTLE_ZONE.enemyLine)
            else
                tailX = math.max(headX - trailLen, BATTLE_ZONE.playerLine)
            end
            local glowPulse = 0.7 + 0.3 * math.sin(eff.timer * 10)
            local bodyAlpha = math.floor(50 * alpha * glowPulse)

            -- 鍏夊甫娓愬彉 (澶撮儴浜? 灏鹃儴鏆?
            local gradX1 = math.min(headX, tailX)
            local gradX2 = math.max(headX, tailX)
            local grad
            if eff.isEnemySkill then
                grad = nvgLinearGradient(vg, headX, eff.y, tailX, eff.y,
                    nvgRGBA(sc[1], sc[2], sc[3], math.floor(bodyAlpha * 1.2)),
                    nvgRGBA(sc[1], sc[2], sc[3], 0))
            else
                grad = nvgLinearGradient(vg, headX, eff.y, tailX, eff.y,
                    nvgRGBA(sc[1], sc[2], sc[3], math.floor(bodyAlpha * 1.2)),
                    nvgRGBA(sc[1], sc[2], sc[3], 0))
            end
            nvgBeginPath(vg)
            nvgRect(vg, gradX1, eff.y - halfH, gradX2 - gradX1, halfH * 2)
            nvgFillPaint(vg, grad); nvgFill(vg)

            -- 澶撮儴楂樹寒鍏夋檿
            local headGlow = nvgRadialGradient(vg, headX, eff.y, 5, halfH * 1.5,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(100 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, headX, eff.y, halfH * 1.5)
            nvgFillPaint(vg, headGlow); nvgFill(vg)

            -- 搴忓垪甯у姩鐢?(鍦ㄥ脊澶翠綅缃粯鍒?
            local frameSize = skill.renderSize * (0.8 + 0.2 * glowPulse)
            DrawSkillFrame(eff.x, eff.y, frameSize, eff.frameIdx, alpha, eff.skillIdx)
        elseif skill.skillType == "rect" then
            -- ======== 鐭╁舰鎶€鑳芥覆鏌? 鐭╁舰鍏夋 + 搴忓垪甯?========
            local rw, rh = skill.rectW, skill.rectH
            local glowPulse = 0.5 + 0.5 * math.sin(eff.timer * 8)
            local rectScale = 0.6 + progress * 0.4
            local gw, gh = rw * rectScale, rh * rectScale

            -- 鐭╁舰鑼冨洿鍏夋檿
            local rx, ry = eff.x - gw / 2, eff.y - gh / 2
            local grad = nvgLinearGradient(vg, rx, ry, rx, ry + gh,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(50 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(15 * alpha * glowPulse)))
            nvgBeginPath(vg); nvgRect(vg, rx, ry, gw, gh)
            nvgFillPaint(vg, grad); nvgFill(vg)

            -- 鐭╁舰杈规
            nvgBeginPath(vg); nvgRect(vg, rx, ry, gw, gh)
            nvgStrokeColor(vg, nvgRGBA(sc[1], sc[2], sc[3], math.floor(40 * alpha * glowPulse)))
            nvgStrokeWidth(vg, 1.0); nvgStroke(vg)

            -- 搴忓垪甯у姩鐢?(鐢ㄧ煩褰㈠搴﹀尮閰?
            local fxScale = 0.7 + progress * 0.3
            DrawSkillFrame(eff.x, eff.y, rw * fxScale, eff.frameIdx, alpha, eff.skillIdx)
        else
            -- ======== AOE鎶€鑳芥覆鏌? 鍦嗗舰鍏夊湀 + 搴忓垪甯?========
            -- 搴曢儴鍏夊湀(鑼冨洿鎸囩ず, 浣跨敤鎶€鑳介鑹?
            local glowPulse = 0.5 + 0.5 * math.sin(eff.timer * 8)
            local glowR = skill.radius * (0.6 + progress * 0.4)
            local glow = nvgRadialGradient(vg, eff.x, eff.y, glowR * 0.2, glowR,
                nvgRGBA(sc[1], sc[2], sc[3], math.floor(60 * alpha * glowPulse)),
                nvgRGBA(sc[1], sc[2], sc[3], 0))
            nvgBeginPath(vg); nvgCircle(vg, eff.x, eff.y, glowR)
            nvgFillPaint(vg, glow); nvgFill(vg)

            -- 搴忓垪甯у姩鐢?(鐢?radius*2 鍖归厤鐬勫噯鍦堢洿寰?
            local effectDiameter = skill.radius * 2
            DrawSkillFrame(eff.x, eff.y, effectDiameter * (0.7 + progress * 0.3), eff.frameIdx, alpha, eff.skillIdx)
        end
        ::continue::
    end
end


--- 缁樺埗鎶€鑳界瀯鍑嗘寚绀哄櫒 (璁捐鍧愭爣, 鎷栨嫿涓皟鐢?
function DrawSkillTargetingDesign()
    if not skillTargeting.active then return end
    local skill = SKILL_DEFS[skillTargeting.skillIdx]
    if not skill then return end

    local tx, ty = skillTargeting.dx, skillTargeting.dy
    local bz = BATTLE_ZONE
    local t = gameState.gameTime

    -- 妫€鏌ユ槸鍚﹀湪鎴樺満鑼冨洿鍐?(妯睆: X鍦ㄤ袱鏉′复鐣岀嚎涔嬮棿, Y鍦ㄦ垬鍖鸿寖鍥村唴)
    local inZone = tx >= bz.playerLine and tx <= bz.enemyLine
        and ty >= bz.top and ty <= bz.bottom

    local baseAlpha = inZone and 180 or 80
    local pulseAlpha = math.floor(baseAlpha * (0.6 + 0.4 * math.sin(t * 5)))

    if skill.skillType == "line" then
        -- ======== 绾垮瀷鎶€鑳界瀯鍑? 楂樹寒鏁存潯姘村钩杞﹂亾 ========
        local laneIdx = math.floor((ty - bz.top) / LANE_WIDTH) + 1
        laneIdx = math.max(1, math.min(NUM_LANES, laneIdx))
        local laneCY = GetLaneCenterY(laneIdx)
        local laneTop = bz.top + (laneIdx - 1) * LANE_WIDTH
        local laneLeft = bz.playerLine
        local laneRight = bz.enemyLine
        local laneW = laneRight - laneLeft
        local pulse = 0.6 + 0.4 * math.sin(t * 5)

        if inZone then
            -- 杞﹂亾鑳屾櫙楂樹寒
            local grad = nvgLinearGradient(vg, laneLeft, laneCY, laneRight, laneCY,
                nvgRGBA(255, 120, 40, math.floor(55 * pulse)),
                nvgRGBA(255, 80, 20, math.floor(20 * pulse)))
            nvgBeginPath(vg)
            nvgRect(vg, laneLeft, laneTop, laneW, LANE_WIDTH)
            nvgFillPaint(vg, grad); nvgFill(vg)

            -- 杞﹂亾杈规
            nvgBeginPath(vg)
            nvgRect(vg, laneLeft, laneTop, laneW, LANE_WIDTH)
            nvgStrokeColor(vg, nvgRGBA(255, 140, 60, math.floor(pulseAlpha * 0.8)))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

            -- 绠ご鎸囩ず (妯睆: 浠庡乏鍚戝彸鐨勬柟鍚戠澶?
            local arrowY = laneCY
            for ax = laneLeft + 40, laneRight - 20, 80 do
                local aAlpha = math.floor(120 * pulse * ((ax - laneLeft) / laneW))
                nvgBeginPath(vg)
                nvgMoveTo(vg, ax - 8, arrowY - 8)
                nvgLineTo(vg, ax + 4, arrowY)
                nvgLineTo(vg, ax - 8, arrowY + 8)
                nvgStrokeColor(vg, nvgRGBA(255, 200, 100, math.max(30, aAlpha)))
                nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
            end
        else
            -- 瓒呭嚭鑼冨洿: 娣¤壊鎻愮ず
            nvgBeginPath(vg)
            nvgRect(vg, laneLeft, laneTop, laneW, LANE_WIDTH)
            nvgFillColor(vg, nvgRGBA(150, 130, 110, math.floor(15 * pulse)))
            nvgFill(vg)
        end

        -- 鎶€鑳藉悕 (妯睆: 鏄剧ず鍦ㄨ溅閬撳乏渚?
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, pulseAlpha))
            nvgText(vg, laneLeft - 6, laneCY, skill.name, nil)
        end
    elseif skill.skillType == "rect" then
        -- ======== 鐭╁舰鎶€鑳界瀯鍑? 鐭╁舰鑼冨洿妗?========
        local rw, rh = skill.rectW, skill.rectH
        local rx, ry = tx - rw / 2, ty - rh / 2
        local pulse = 0.6 + 0.4 * math.sin(t * 5)

        nvgBeginPath(vg); nvgRect(vg, rx, ry, rw, rh)
        nvgStrokeWidth(vg, 1.5)
        if inZone then
            nvgStrokeColor(vg, nvgRGBA(255, 120, 40, pulseAlpha))
            -- 濉厖娣¤壊娓愬彉
            local fill = nvgLinearGradient(vg, rx, ry, rx, ry + rh,
                nvgRGBA(255, 100, 30, math.floor(50 * pulse)),
                nvgRGBA(255, 60, 10, math.floor(15 * pulse)))
            nvgFillPaint(vg, fill); nvgFill(vg)
        else
            nvgStrokeColor(vg, nvgRGBA(180, 150, 130, math.floor(pulseAlpha * 0.5)))
        end
        nvgStroke(vg)

        -- 鍗佸瓧鍑嗘槦
        local crossSize = 10
        nvgBeginPath(vg)
        nvgMoveTo(vg, tx - crossSize, ty); nvgLineTo(vg, tx + crossSize, ty)
        nvgMoveTo(vg, tx, ty - crossSize); nvgLineTo(vg, tx, ty + crossSize)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, pulseAlpha))
        nvgStrokeWidth(vg, 1.0); nvgStroke(vg)

        -- 鎶€鑳藉悕
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, pulseAlpha))
            nvgText(vg, tx, ry - 6, skill.name, nil)
        end
    else
        -- ======== AOE鎶€鑳界瀯鍑? 鑼冨洿鍦?========
        -- 鑼冨洿鍦?
        nvgBeginPath(vg); nvgCircle(vg, tx, ty, skill.radius)
        nvgStrokeWidth(vg, 1.5)
        if inZone then
            nvgStrokeColor(vg, nvgRGBA(255, 120, 40, pulseAlpha))
            -- 濉厖娣¤壊
            local fill = nvgRadialGradient(vg, tx, ty, 5, skill.radius,
                nvgRGBA(255, 100, 30, math.floor(40 * (0.6 + 0.4 * math.sin(t * 5)))),
                nvgRGBA(255, 60, 10, 0))
            nvgFillPaint(vg, fill); nvgFill(vg)
        else
            nvgStrokeColor(vg, nvgRGBA(180, 150, 130, math.floor(pulseAlpha * 0.5)))
        end
        nvgStroke(vg)

        -- 鍗佸瓧鍑嗘槦
        local crossSize = 10
        nvgBeginPath(vg)
        nvgMoveTo(vg, tx - crossSize, ty); nvgLineTo(vg, tx + crossSize, ty)
        nvgMoveTo(vg, tx, ty - crossSize); nvgLineTo(vg, tx, ty + crossSize)
        nvgStrokeColor(vg, nvgRGBA(255, 220, 100, pulseAlpha))
        nvgStrokeWidth(vg, 1.0); nvgStroke(vg)

        -- 鎶€鑳藉悕
        if fontId >= 0 then
            nvgFontFaceId(vg, GetMainFont())
            nvgFontSize(vg, 15)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(vg, nvgRGBA(255, 200, 100, pulseAlpha))
            nvgText(vg, tx, ty - skill.radius - 6, skill.name, nil)
        end
    end
end


-- ============================================================================
-- 娓叉煋涓绘祦绋?
-- ============================================================================

function HandleNanoVGRender(eventType, eventData)
    if not vg then return end

    local g = GetGraphics()
    local physW = g:GetWidth()
    local physH = g:GetHeight()
    local dpr = g:GetDPR()

    -- DPR 瀹夊叏鏍￠獙锛氶儴鍒嗗崕涓?楦胯挋璁惧鍙兘杩斿洖寮傚父鍊?
    if dpr ~= dpr or dpr <= 0 then dpr = 1.0 end  -- NaN/璐熷€?闆?鈫?鍥為€€1.0
    if dpr > 4.0 then dpr = 3.0 end                -- 鐩墠鏃?DPR>4 鐨勬墜鏈?

    screenW = physW / dpr
    screenH = physH / dpr

    -- 棣栧抚璁惧璇婃柇鏃ュ織锛堝府鍔╁畾浣嶅崕涓虹瓑璁惧鐨勫吋瀹规€ч棶棰橈級
    if not _deviceInfoLogged then
        _deviceInfoLogged = true
        local rawDpr = g:GetDPR()
        print(string.format("[DeviceInfo] physW=%d physH=%d rawDPR=%.3f usedDPR=%.3f logW=%.1f logH=%.1f",
            physW, physH, rawDpr, dpr, screenW, screenH))
        local platform = GetPlatform and GetPlatform() or "unknown"
        print(string.format("[DeviceInfo] platform=%s designW=%d designH=%d", platform, DESIGN_W, DESIGN_H))
    end

    -- 鎴樻枟鐣岄潰棰勭暀搴曢儴鍟嗗簵鍖哄煙锛屽叾浠栫晫闈㈠叏灞?
    local isBattle = (gameState.phase == "BATTLE" or gameState.phase == "WIN" or gameState.phase == "LOSE" or gameState.phase == "SHOP")
    local reservedH = isBattle and SHOP_RESERVED_H or 0
    local availH = screenH - reservedH
    local scaleX = screenW / DESIGN_W
    local scaleY = availH / DESIGN_H
    scale = math.min(scaleX, scaleY)
    offsetX = (screenW - DESIGN_W * scale) / 2
    offsetY = (availH - DESIGN_H * scale) / 2

    -- 甯冨眬瀹夊叏闄愬埗锛氶槻姝㈤儴鍒嗚澶囧洜鍒嗚鲸鐜囨姤鍛婂紓甯稿鑷撮潰鏉胯繃搴︿笅绉?
    -- 姝ｅ父鎵嬫満 offsetY 涓€鑸笉瓒呰繃 screenH 鐨?15%
    local maxOffsetY = screenH * 0.18
    if offsetY > maxOffsetY then
        if not _layoutWarnLogged then
            _layoutWarnLogged = true
            print(string.format("[LayoutWarn] offsetY=%.1f > max=%.1f, clamped. physW=%d physH=%d dpr=%.3f scaleX=%.4f scaleY=%.4f scale=%.4f",
                offsetY, maxOffsetY, physW, physH, dpr, scaleX, scaleY, scale))
        end
        offsetY = maxOffsetY
    end
    if offsetX > screenW * 0.18 then
        offsetX = screenW * 0.18
    end

    -- 鍒樻捣灞忓畨鍏ㄥ尯: 鐗╃悊鍍忕礌 >> 閫昏緫鍍忕礌 >> 璁捐鍧愭爣
    local safeRect = GetSafeAreaInsets(false)
    if safeRect then
        safeInsets.top    = (safeRect.min.y / dpr) / scale
        safeInsets.bottom = (safeRect.max.y / dpr) / scale
        safeInsets.left   = (safeRect.min.x / dpr) / scale
        safeInsets.right  = (safeRect.max.x / dpr) / scale
    end

    CalcShopLayout()

    -- 灏嗗睆骞曞昂瀵镐紶閫掔粰 EquipUI overlay锛堥伩鍏嶅叏灞€浜嬩欢涓?graphics 杩斿洖閿欒鍊硷級
    if EquipUI then
        EquipUI._physW = physW
        EquipUI._physH = physH
        EquipUI._dpr = dpr
        EquipUI._logW = screenW
        EquipUI._logH = screenH
    end

    nvgBeginFrame(vg, physW, physH, dpr)
    nvgSave(vg)

    -- 榛戣壊搴曡壊
    nvgBeginPath(vg); nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(28, 24, 38, 255)); nvgFill(vg)

    -- 瀛椾綋棰勭儹锛氱敤閫忔槑鑹叉覆鏌撳父鐢ㄥ瓧绗︼紝閬垮厤鍚庣画棣栨鏄剧ず鏃跺崱椤匡紙灏ゅ叾楂楧PI鍗庝负璁惧锛?
    if not fontsWarmed and fontId >= 0 then
        nvgSave(vg)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 0))  -- 瀹屽叏閫忔槑锛屼笉鍙
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        local warmStr = "Loading battle HUD 123456789% Confirm Cancel Back Start Continue Exit "
            .. "Settings Save Equip Bag Skills Shop Ranked Stage Victory Defeat Battle EXP Gold "
            .. "Jade Stamina Attack Defense HP Crit Dodge Speed Avatar Title Server Match "
            .. "Alliance Friends Mail Trade Formation Progress Welfare Rewards Login "
            .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        local warmFonts = { fontId, fontArt, fontGame, fontKai, fontFZ }
        local warmedCount = 0
        for _, fid in ipairs(warmFonts) do
            if fid and fid >= 0 then
                nvgFontFaceId(vg, fid)
                nvgFontSize(vg, 24)
                nvgText(vg, -9999, -9999, warmStr, nil)  -- 灞忓箷澶栨覆鏌?
                warmedCount = warmedCount + 1
            end
        end
        -- 鍙湁鑷冲皯涓诲瓧浣撻鐑垚鍔熸墠鏍囪瀹屾垚
        if warmedCount > 0 then
            fontsWarmed = true
        end
        nvgRestore(vg)
    end

    -- === LOADING 鐣岄潰 (灞忓箷閫昏緫鍧愭爣锛屼笉鐢ㄨ璁″潗鏍? ===
    if gameState.phase == "LOADING" then
        local cx = screenW / 2
        local cy = screenH / 2
        local t = menuAnimTimer

        -- 娓告垙鏍囬 (琛屼功瀛椾綋)
        nvgFontFaceId(vg, GetMainFont())
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        -- 鏍囬鎶曞奖
        nvgFontSize(vg, 30)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
        nvgText(vg, cx + 2, cy - 35 + 2, "Loading", nil)
        -- 鏍囬涓诲眰
        DrawWhiteInkText(cx, cy - 35, "Loading")

        -- 杩涘害鏉?
        local barW = screenW * 0.6
        local barH = 8
        local barX = cx - barW / 2
        local barY = cy + 10
        local pct = blockingLoadState.progress or 0

        -- 杩涘害鏉¤儗鏅?
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, barW, barH, 4)
        nvgFillColor(vg, nvgRGBA(40, 40, 55, 200)); nvgFill(vg)

        -- 杩涘害濉厖
        local fillW = barW * pct
        if fillW > 1 then
            local grad = nvgLinearGradient(vg, barX, barY, barX + fillW, barY,
                nvgRGBA(180, 150, 90, 220), nvgRGBA(220, 190, 120, 220))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, fillW, barH, 4)
            nvgFillPaint(vg, grad); nvgFill(vg)
        end

        -- 杩涘害鏂囧瓧
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(215, 190, 120, 220))
        local loadText = string.format("姝ｅ湪鍔犺浇 %d%%", math.floor(pct * 100))
        nvgText(vg, cx, barY + barH + 8, loadText, nil)

        -- 搴曢儴鎻愮ず (鍛煎惛)
        local tipAlpha = math.floor(100 + 60 * math.sin(t * 2.0))
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(140, 130, 110, tipAlpha))
        nvgText(vg, cx, barY + barH + 32, "璁ㄤ紣灏嗗惎锛岃绋嶅€?..", nil)

        -- 鍏蜂綋杩涘害鏁板瓧
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(120, 115, 100, 160))
        local detailText = string.format("(%d/%d)", blockingLoadState.completedCount or 0, blockingLoadState.totalCount or 0)
        nvgText(vg, cx, barY + barH + 50, detailText, nil)

        -- 鐐瑰嚮鎻愮ず锛堢帺瀹剁偣鍑诲睆骞曟椂鏄剧ず锛?
        if loadingClickTipTimer and loadingClickTipTimer > 0 then
            local tipA = math.min(1, loadingClickTipTimer / 0.3)
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 120, math.floor(220 * tipA)))
            nvgText(vg, cx, cy + 80, "璧勬簮鍔犺浇涓紝璇疯€愬績绛夊緟~", nil)
        end

        nvgRestore(vg)
        nvgEndFrame(vg)
        return  -- LOADING 闃舵涓嶆覆鏌撳叾浠栧唴瀹?
    end

    -- === 娓告垙鍖哄煙 (璁捐鍧愭爣) ===
    nvgSave(vg)
    nvgTranslate(vg, offsetX, offsetY)
    nvgScale(vg, scale, scale)

    if gameState.phase == "PROFILE" then
        DrawProfileScreen()
        DrawFloatTexts()
    elseif gameState.phase == "MENU" then
        if settingsPage.btnAdjustMode then
            DrawBtnAdjustMode()
        else
            DrawMenuScreen()
            DrawFloatTexts()
            if settingsPage.isOpen then DrawSettingsScreen() end
            if cdkState.inputOpen then DrawCDKPopup() end
            DrawPowerExplainPopup()  -- 鎴樺姏璇存槑寮圭獥
        end
    -- elseif gameState.phase == "GACHA" then  -- 宸茬Щ闄ゆ娊鍗＄郴缁?
    --     DrawGachaScreen()
    --     DrawFloatTexts()
    elseif gameState.phase == "CODEX" then
        DrawCodexScreen()
        DrawFloatTexts()
    elseif gameState.phase == "HERO_DETAIL" then
        DrawHeroDetailScreen()
        DrawFloatTexts()
    elseif gameState.phase == "PLAYER_DETAIL" then
        DrawPlayerDetailScreen()
        DrawFloatTexts()
        DrawPowerExplainPopup()  -- 鎴樺姏璇存槑寮圭獥 (瑕嗙洊鍦ㄨ鎯呬笂灞?
    elseif gameState.phase == "SKILL_CODEX" then
        DrawSkillCodexScreen()
        DrawFloatTexts()
    elseif gameState.phase == "SKILL_DETAIL" then
        DrawSkillDetailScreen()
        DrawFloatTexts()
    elseif gameState.phase == "WELFARE" then
        DrawWelfareScreen()
        DrawFloatTexts()
    elseif gameState.phase == "PROGRESS" then
        DrawDailyTasksAndAchievements()
        DrawFloatTexts()
    elseif gameState.phase == "EQUIP" then
        DrawEquipScreen()
    elseif gameState.phase == "EQUIP_CODEX" then
        DrawEquipCodexScreen()
    elseif gameState.phase == "SEAL_MGR" then
        DrawSealMgrScreen()
        DrawFloatTexts()
    elseif gameState.phase == "MAIL_BOX" then
        DrawMailBoxScreen()
        DrawFloatTexts()
    elseif gameState.phase == "POWER_RANK" then
        DrawPowerRankScreen()
        DrawFloatTexts()
    elseif gameState.phase == "TRADE" then
        DrawTradeScreen()
        DrawFloatTexts()
    elseif gameState.phase == "FACTION" then
        DrawFactionScreen()
        DrawFloatTexts()
    elseif gameState.phase == "FRIENDS" then
        DrawFriendsScreen()
        DrawFloatTexts()
    elseif gameState.phase == "FORMATION" then
        DrawFormationScreen()
        DrawFloatTexts()
    elseif gameState.phase == "CONTRIB_RANK" then
        DrawContribRankScreen()
        DrawFloatTexts()
    elseif gameState.phase == "WORLD_MAP" then
        DrawWorldMapScreen()
        WorldMap.DrawMarch()
        WorldMap.DrawGuide()
        DrawFloatTexts()
    --[=[ 宸茬Щ闄ゅ叧鍗?鍓湰绯荤粺
    elseif gameState.phase == "STAGE_SELECT" then
        DrawStageSelectScreen()
        DrawFloatTexts()
    elseif gameState.phase == "DAILY_DUNGEON" then
        DrawDailyDungeonScreen()
        DrawFloatTexts()
    elseif gameState.phase == "RESOURCE_DUNGEON" then
        DrawResourceDungeonScreen()
        DrawFloatTexts()
    --]=]
    elseif gameState.phase == "BATTLE_PASS" then
        DrawBattlePassScreen()
        DrawFloatTexts()
    --[=[ 宸茬Щ闄? 璁ㄤ紣/鐖/鎺掍綅/鎺㈢储
    elseif gameState.phase == "ABYSS_SELECT" then
        DrawAbyssSelectScreen()
        DrawFloatTexts()
    elseif gameState.phase == "EXPLORATION" then
        Exploration.Draw(DESIGN_W, DESIGN_H, gameState.gameTime)
        DrawFloatTexts()
    elseif gameState.phase == "TOWER_SELECT" then
        DrawTowerSelectScreen()
        DrawFloatTexts()
    elseif gameState.phase == "RANKED_SELECT" then
        DrawRankedSelectScreen()
        DrawFloatTexts()
    --]=]
    elseif gameState.phase == "DUMMY_SELECT" then
        DrawDummySelectScreen()
        DrawFloatTexts()
    elseif gameState.phase == "DUMMY_RESULT" then
        DrawDummyResultScreen()
        DrawFloatTexts()
    elseif gameState.phase == "DEV_EDITOR" then
        DrawDevEditorScreen()
        DrawFloatTexts()
        DrawFloatTexts()
    else
        DrawBackground()
        DrawCriticalLines()
        DrawLaneDividers()
        DrawBaseHPBars()
        DrawGroundSkillEffects() -- 搴曞眰鎶€鑳界壒鏁?(鍦ㄥ崟浣嶄箣涓? 濡傛不鐤楁硶闃?
        DrawBattleUnits()
        DrawSkillEffects()       -- 姝︽妧鎶€鑳界壒鏁?(鍦ㄥ崟浣嶄箣涓?
        DrawSkillTargetingDesign()  -- 鎶€鑳界瀯鍑嗘寚绀哄櫒
        DrawParticles()
        UpdateAndDrawProjectiles(time:GetTimeStep())
        DrawCardSlots()
        DrawSlotHighlights()  -- 鎷栨嫿鏃剁殑妲戒綅楂樹寒
        DrawHUD()
        DrawBattleButtons()  -- 鍙充晶鎸夐挳鍦ㄨ璁″潗鏍囩┖闂寸粯鍒?
        DrawBottomActionBar()  -- 鍙充笅瑙掓搷浣滄爮(鑷姩琛屽啗+鎶€鑳介鐣?
        DrawStrategyWheel()   -- 绛栫暐杞洏(闀挎寜鑷姩琛屽啗寮瑰嚭)
        DrawFloatTexts()
        DrawGameResultOverlay()
        DrawRewardPopup()
        DrawExploreExitConfirmPopup()  -- 鎺㈢储閫€鍑?姝讳骸纭寮圭獥
        DrawBattleRulesPopup()  -- 鎴樻枟瑙勫垯寮圭獥
        -- DrawSkillInfoPopup()    -- 宸茬Щ闄ゆ鎶€璇︽儏寮圭獥 (鏀逛负鎸変笅鍗虫嫋鎷?
    end

    -- === 缁熶竴瑙勫垯寮圭獥 (鍙犲姞鍦ㄦ墍鏈夌晫闈箣涓? ===
    DrawPhaseRulePopup()

    nvgRestore(vg)

    -- === 浠ヤ笅鍏ㄩ儴鍦ㄥ睆骞曢€昏緫鍧愭爣 ===
    if gameState.phase == "BATTLE" or gameState.phase == "WIN" or gameState.phase == "LOSE" then
        DrawShop()
        DrawDragCardScreen()   -- 鈽?鎷栨嫿鍗＄墝鍦ㄥ睆骞曞潗鏍囨覆鏌?
        DrawInfoPanel()
        DrawLongPressTip()     -- (宸插簾寮? 绌哄嚱鏁?
        DrawInfoPopup()        -- 鈽?鍗曞嚮淇℃伅寮圭獥 (鍚溅閬撻€夋嫨)
    end

    -- 鍏ㄥ眬 Toast 鎻愮ず锛堣鐩栧湪鏈€涓婂眰锛?
    DrawToast(DESIGN_W, DESIGN_H)

    -- 浜戞暟鎹姞杞戒腑閬僵锛堝崐閫忔槑锛屾樉绀哄姞杞芥彁绀猴級
    if CloudManager.IsCloudLoading() then
        local cW, cH = DESIGN_W, DESIGN_H
        nvgBeginPath(vg); nvgRect(vg, 0, 0, cW, cH)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 160)); nvgFill(vg)
        -- 鍔犺浇鎻愮ず妗?
        local boxW, boxH = 260, 80
        local boxX, boxY = (cW - boxW) / 2, (cH - boxH) / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 12)
        nvgFillColor(vg, nvgRGBA(30, 30, 40, 230)); nvgFill(vg)
        -- 鏃嬭浆鍔犺浇鐐瑰姩鐢?
        local dotPhase = (os.clock() * 3) % 3
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(220, 220, 220, 255))
        local dots = dotPhase < 1 and "." or (dotPhase < 2 and ".." or "...")
        nvgText(vg, cW / 2, cH / 2, "姝ｅ湪鍚屾浜戠鏁版嵁" .. dots)
    end

    -- 灏佺鍏ㄥ睆閬僵锛堟渶楂樺眰绾э紝闃绘涓€鍒囨搷浣滐級
    if gameState.isBanned then
        local bW, bH = DESIGN_W, DESIGN_H
        nvgBeginPath(vg); nvgRect(vg, 0, 0, bW, bH)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 220)); nvgFill(vg)

        local bcx, bcy = bW / 2, bH / 2
        -- 绾㈣壊璀﹀憡妗?
        local boxW, boxH = 380, 160
        local boxX, boxY = bcx - boxW / 2, bcy - boxH / 2
        nvgBeginPath(vg); nvgRoundedRect(vg, boxX, boxY, boxW, boxH, 14)
        nvgFillColor(vg, nvgRGBA(40, 10, 10, 240)); nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 60, 60, 200)); nvgStrokeWidth(vg, 2); nvgStroke(vg)

        nvgFontSize(vg, 20); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 100, 100, 255))
        nvgText(vg, bcx, boxY + 40, "Account Suspended", nil)

        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(220, 200, 200, 220))
        nvgText(vg, bcx, boxY + 75, "Suspicious account activity was detected.", nil)
        nvgText(vg, bcx, boxY + 100, "Please contact support for review.", nil)

        nvgFontSize(vg, 12); nvgFillColor(vg, nvgRGBA(150, 150, 160, 160))
        nvgText(vg, bcx, boxY + 130, "Use the community feedback channel if needed.", nil)
    end

    nvgRestore(vg)
    nvgEndFrame(vg)
end


-- ============================================================================
-- 鑳屾櫙
-- ============================================================================

function DrawBackground()
    -- 缁熶竴璧?BATTLE_LAYOUTS 鑳屾櫙 (InitBattle 涓凡璁剧疆 currentLayoutIdx)
    local bgHandle = nil
    if currentLayoutIdx and BATTLE_LAYOUTS[currentLayoutIdx] then
        bgHandle = BATTLE_LAYOUTS[currentLayoutIdx].bgHandle
    end

    if not bgHandle or not IsImageReady(bgHandle) then
        -- 鏃犺儗鏅浘(榛樿鎴樺満)鎴栧浘鐗囨湭灏辩华: 缁樺埗绾壊娣辫壊鑳屾櫙
        nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
        nvgFillColor(vg, nvgRGBA(22, 18, 30, 255)); nvgFill(vg)
        -- 濡傛灉鏈夊浘浣嗚繕鍦ㄥ姞杞戒腑锛屾樉绀哄姞杞藉姩鐢?
        if bgHandle and not IsImageReady(bgHandle) then
            DrawSpinner(DESIGN_W / 2, DESIGN_H / 2, 20)
            return
        end
    else
        -- 鏈夎儗鏅浘: 鎵€鏈夋垬鏂楄儗鏅浘鍧囦负 714脳1280 (BG_W脳BG_H)锛岀洿鎺ユ媺浼稿埌璁捐鍒嗚鲸鐜?
        local p = nvgImagePattern(vg, 0, 0, DESIGN_W, DESIGN_H, 0, bgHandle, 1.0)
        nvgBeginPath(vg); nvgRect(vg, 0, 0, DESIGN_W, DESIGN_H)
        nvgFillPaint(vg, p); nvgFill(vg)
    end

    -- 鈽?妯睆鎴樺満閬僵: 宸﹀彸娣诲姞鏆楄壊娓愬彉, 纭繚鐭冲彴鍗＄墝鍖烘竻鏅板彲瑙?
    -- 宸︿晶鐜╁鍖?(X 0~80): 浠庡乏寰€鍙虫笎鍙? 鏆椻啋閫忔槑
    local leftZoneW = 80
    local leftGrad = nvgLinearGradient(vg, 0, 0, leftZoneW, 0,
        nvgRGBA(18, 12, 28, 120), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, leftZoneW, DESIGN_H)
    nvgFillPaint(vg, leftGrad); nvgFill(vg)

    -- 鍙充晶鏁屾柟鍖?(X 940~1024): 浠庡彸寰€宸︽笎鍙? 鏆椻啋閫忔槑
    local rightStart = DESIGN_W - 84
    local rightGrad = nvgLinearGradient(vg, DESIGN_W, 0, rightStart, 0,
        nvgRGBA(18, 12, 28, 140), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, rightStart, 0, DESIGN_W - rightStart, DESIGN_H)
    nvgFillPaint(vg, rightGrad); nvgFill(vg)
end


-- ============================================================================
-- 涓寸晫绾?(绐佺牬鎵ｈ绾?
-- ============================================================================

function DrawCriticalLines()
    local t = gameState.gameTime
    local bz = BATTLE_ZONE

    -- 鏁屾柟涓寸晫绾?(妯睆: 鍙充晶鍨傜洿绾? 缁胯壊 鈥?鐜╁鍏靛埌杈炬澶勬墸鏁屾柟琛€)
    local ePulse = 0.4 + 0.3 * math.sin(t * 3)
    local eLineX = bz.enemyLine
    -- 娓愬彉鍙戝厜甯?
    local eGlow = nvgLinearGradient(vg, eLineX - 6, 0, eLineX + 6, 0,
        nvgRGBA(80, 255, 150, 0),
        nvgRGBA(80, 255, 150, math.floor(25 * ePulse)))
    nvgBeginPath(vg); nvgRect(vg, eLineX - 6, bz.top, 12, bz.bottom - bz.top)
    nvgFillPaint(vg, eGlow); nvgFill(vg)
    -- 涓荤嚎
    nvgBeginPath(vg)
    nvgMoveTo(vg, eLineX, bz.top + 10); nvgLineTo(vg, eLineX, bz.bottom - 10)
    nvgStrokeColor(vg, nvgRGBA(80, 255, 150, math.floor(50 + 40 * ePulse)))
    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)

    -- 鐜╁涓寸晫绾?(妯睆: 宸︿晶鍨傜洿绾? 绾㈣壊 鈥?鏁屾柟鍏靛埌杈炬澶勬墸鐜╁琛€)
    local pPulse = 0.4 + 0.3 * math.sin(t * 3 + 1.5)
    local pLineX = bz.playerLine
    -- 娓愬彉鍙戝厜甯?
    local pGlow = nvgLinearGradient(vg, pLineX - 6, 0, pLineX + 6, 0,
        nvgRGBA(255, 80, 60, math.floor(25 * pPulse)),
        nvgRGBA(255, 80, 60, 0))
    nvgBeginPath(vg); nvgRect(vg, pLineX - 6, bz.top, 12, bz.bottom - bz.top)
    nvgFillPaint(vg, pGlow); nvgFill(vg)
    -- 涓荤嚎
    nvgBeginPath(vg)
    nvgMoveTo(vg, pLineX, bz.top + 10); nvgLineTo(vg, pLineX, bz.bottom - 10)
    nvgStrokeColor(vg, nvgRGBA(255, 80, 60, math.floor(50 + 40 * pPulse)))
    nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
end


-- ============================================================================
-- 杞﹂亾鍒嗗壊绾?(鎴樻枟涓樉绀? 璁捐鍧愭爣)
-- ============================================================================

function DrawLaneDividers()
    if gameState.battlePhase ~= "FIGHT" then return end

    local bz = BATTLE_ZONE
    local t = gameState.gameTime

    -- 妫€娴嬫嫋鎷芥偓鍋滆溅閬?(妯睆: 杞﹂亾娌縔杞存帓鍒? 鐢╠dy妫€娴?
    local highlightLane = 0
    local isDraggingSlot = dragState.active and dragState.fromSlot and dragState.card
    if isDraggingSlot then
        local ddx, ddy = LogicalToDesign(dragState.lx, dragState.ly)
        local hitMarginLane = 60
        if ddx >= bz.playerLine - hitMarginLane and ddx <= bz.enemyLine + hitMarginLane
           and ddy >= bz.top and ddy <= bz.bottom then
            highlightLane = math.floor((ddy - bz.top) / LANE_WIDTH) + 1
            highlightLane = math.max(1, math.min(NUM_LANES, highlightLane))
        end
    end

    -- 鎷栨嫿鏃舵樉绀烘墍鏈夎溅閬撹儗鏅?+ 楂樹寒鎮仠杞﹂亾
    if isDraggingSlot then
        for i = 1, NUM_LANES do
            local laneY = bz.top + (i - 1) * LANE_WIDTH
            local laneW = bz.enemyLine - bz.playerLine
            nvgBeginPath(vg)
            nvgRect(vg, bz.playerLine, laneY, laneW, LANE_WIDTH)
            if i == highlightLane then
                -- 楂樹寒杞﹂亾: 鏄庝寒钃濊壊
                local pulse = 0.6 + 0.4 * math.sin(t * 4)
                nvgFillColor(vg, nvgRGBA(80, 180, 255, math.floor(45 * pulse)))
            else
                -- 鍏朵粬杞﹂亾: 娣¤壊
                nvgFillColor(vg, nvgRGBA(100, 140, 180, 12))
            end
            nvgFill(vg)
        end
    end

    -- 缁樺埗4鏉¤溅閬撳垎鍓茬嚎 (妯睆: 姘村钩绾? 5鏉¤溅閬撴湁4鏉″垎鍓茬嚎)
    for i = 1, NUM_LANES - 1 do
        local ly = bz.top + i * LANE_WIDTH
        local isNearHighlight = (highlightLane > 0) and (i == highlightLane or i == highlightLane - 1)
        local alpha = isNearHighlight
            and math.floor(80 + 40 * math.sin(t * 3))
            or math.floor(18 + 8 * math.sin(t * 1.5 + i * 0.8))
        local lineW = isNearHighlight and 1.2 or 0.6

        -- 铏氱嚎鏁堟灉 (姘村钩)
        local dashLen = 8
        local gapLen = 6
        local x = bz.playerLine + 4
        while x < bz.enemyLine - 4 do
            local segEnd = math.min(x + dashLen, bz.enemyLine - 4)
            nvgBeginPath(vg)
            nvgMoveTo(vg, x, ly)
            nvgLineTo(vg, segEnd, ly)
            if isNearHighlight then
                nvgStrokeColor(vg, nvgRGBA(100, 200, 255, alpha))
            else
                nvgStrokeColor(vg, nvgRGBA(140, 180, 220, alpha))
            end
            nvgStrokeWidth(vg, lineW)
            nvgStroke(vg)
            x = segEnd + gapLen
        end
    end

    -- 杞﹂亾缂栧彿 (鎷栨嫿鏃舵洿鏄庢樉, 妯睆: 鏄剧ず鍦ㄥ乏渚т复鐣岀嚎鏃?
    if fontId >= 0 then
        nvgFontFaceId(vg, GetMainFont())
        local lblSize = isDraggingSlot and 18 or 12
        nvgFontSize(vg, lblSize)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local laneNames = { "涓€", "浜?, "涓?, "鍥?, "浜? }
        for i = 1, NUM_LANES do
            local cy = GetLaneCenterY(i)
            if isDraggingSlot then
                local isHL = (i == highlightLane)
                local a = isHL and 220 or 90
                nvgFillColor(vg, nvgRGBA(isHL and 120 or 160, isHL and 220 or 180, 255, a))
                nvgText(vg, bz.playerLine - 12, cy, laneNames[i], nil)
            else
                nvgFillColor(vg, nvgRGBA(160, 180, 210, 40))
                nvgText(vg, bz.playerLine - 6, cy, tostring(i), nil)
            end
        end
    end
end


-- ============================================================================
-- 鐭冲彴鍗＄墝 (閫忔槑瑙掕壊 + 鍝佽川搴曞厜)
-- ============================================================================

-- 鏍规嵁鍗＄墝杩斿洖瀵瑰簲鐨勭簿鐏靛浘鍙ユ焺 (鎵€鏈夋鐏靛潎涓虹嫭绔嬪浘)
function GetHeroSheet(card)
    if card.singleImg then return IMG[card.singleImg] or -1 end
    return -1
end


--- 鑾峰彇鏃犺儗鏅増绮剧伒鍥?(鐭冲彴涓婃覆鏌撶敤锛屾鐏电嫭绔嬪浘澶嶇敤鍘熷浘)
function GetHeroSheetNoBg(card)
    if card.singleImg then return IMG[card.singleImg] or -1 end
    return -1
end


-- 杩斿洖绮剧伒鍥惧彞鏌勫強鍏剁綉鏍煎垪鏁?琛屾暟 (鎵€鏈夋鐏靛潎涓?脳1鐙珛鍥?
function GetHeroSheetInfo(card)
    return GetHeroSheet(card), 1, 1
end


--- 缁樺埗鍗曚釜绋嬪簭鍖栫煶鍙?
function DrawSinglePlatform(cx, cy, w, h, colors, t)
    local r = 6      -- 鍦嗚
    local sideH = 8  -- 渚ч潰鍘氬害
    local shadowOff = 4

    -- 1) 闃村奖 (妯＄硦妞渾)
    local sc = colors.shadow
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy + sideH + shadowOff, w * 0.48, h * 0.22)
    nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 100))
    nvgFill(vg)

    -- 2) 渚ч潰 (娣辫壊鐭╁舰, 琛ㄧず鐭冲彴鍘氬害)
    local sd = colors.side
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w / 2, cy - h / 2 + sideH, w, h, r)
    nvgFillColor(vg, nvgRGBA(sd[1], sd[2], sd[3], 220))
    nvgFill(vg)
    -- 渚ч潰搴曢儴楂樺厜绾?
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w / 2 + r, cy + h / 2 + sideH - 1)
    nvgLineTo(vg, cx + w / 2 - r, cy + h / 2 + sideH - 1)
    nvgStrokeColor(vg, nvgRGBA(sd[1] + 30, sd[2] + 30, sd[3] + 30, 80))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 3) 椤堕潰 (娓愬彉鐭╁舰, 浠庝寒鍒版殫)
    local tl = colors.topLight
    local td = colors.topDark
    local topGrad = nvgLinearGradient(vg,
        cx, cy - h / 2, cx, cy + h / 2,
        nvgRGBA(tl[1], tl[2], tl[3], 200),
        nvgRGBA(td[1], td[2], td[3], 210))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w / 2, cy - h / 2, w, h, r)
    nvgFillPaint(vg, topGrad)
    nvgFill(vg)

    -- 4) 椤堕潰鍐呴儴绾圭悊绾?(妯℃嫙鐭崇汗)
    nvgSave(vg)
    nvgScissor(vg, cx - w / 2, cy - h / 2, w, h)
    for li = 1, 3 do
        local offX = math.sin(li * 2.7 + cx * 0.1) * (w * 0.3)
        local offY = -h * 0.3 + li * (h * 0.25)
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - w / 2 + 4 + offX, cy - h / 2 + offY)
        nvgQuadTo(vg, cx + offX * 0.3, cy - h / 2 + offY + 6,
                      cx + w / 2 - 4 + offX * 0.5, cy - h / 2 + offY - 2)
        nvgStrokeColor(vg, nvgRGBA(tl[1] + 15, tl[2] + 15, tl[3] + 15, 25))
        nvgStrokeWidth(vg, 0.6)
        nvgStroke(vg)
    end
    nvgRestore(vg)

    -- 5) 闃佃惀鑹茶竟缂樺厜 (椤堕潰澶栨弿杈?+ 寰急鑴夊姩)
    local rm = colors.rim
    local pulse = 0.5 + 0.3 * math.sin((t or 0) * 2.0 + cx * 0.05)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w / 2, cy - h / 2, w, h, r)
    nvgStrokeColor(vg, nvgRGBA(rm[1], rm[2], rm[3], math.floor(50 * pulse)))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    -- 6) 椤堕潰楂樺厜 (宸︿笂瑙掑井寮遍珮鍏夌偣)
    local hlGrad = nvgRadialGradient(vg,
        cx - w * 0.25, cy - h * 0.25, 2, w * 0.4,
        nvgRGBA(255, 255, 255, 30), nvgRGBA(255, 255, 255, 0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w / 2, cy - h / 2, w, h, r)
    nvgFillPaint(vg, hlGrad)
    nvgFill(vg)
end


function DrawSlotPlatforms()
    local layout = BATTLE_LAYOUTS[currentLayoutIdx] or BATTLE_LAYOUTS[1]
    local faction = layout.platformFaction or "shu"
    local colors = PLATFORM_COLORS[faction] or PLATFORM_COLORS.shu
    local platW = SLOT_CARD_W + 14
    local platH = SLOT_CARD_H + 12
    local t = gameState and gameState.gameTime or 0
    for _, slot in ipairs(ENEMY_SLOTS) do
        DrawSinglePlatform(slot.cx, slot.cy, platW, platH, colors, t)
    end
    for _, slot in ipairs(PLAYER_SLOTS) do
        DrawSinglePlatform(slot.cx, slot.cy, platW, platH, colors, t)
    end
end


function DrawCardSlots()
    -- DrawSlotPlatforms()  -- 鐭冲彴宸茶瀺鍏ヨ儗鏅浘
    for _, slot in ipairs(ENEMY_SLOTS) do DrawSlotCard(slot, false) end
    for _, slot in ipairs(PLAYER_SLOTS) do DrawSlotCard(slot, true) end
end


function DrawSlotCard(slot, isPlayer)
    local cx, cy = slot.cx, slot.cy
    local w, h = SLOT_CARD_W, SLOT_CARD_H

    if slot.filled and slot.card then
        local card = slot.card
        local t = gameState.gameTime
        local qg = QUALITY_GLOW[card.quality]
        local qc = QUALITY_COLORS[card.quality]

        -- 瑙掕壊鍥?(浣跨敤鍘熷甯﹁儗鏅崱鐗屽浘)
        local useSheet, useRow, useCol, useCols, useRows
        -- 鎵€鏈夊崱鐗岀粺涓€浣跨敤姝︾伒鐙珛鍥?
        local _sh, _sc, _sr = GetHeroSheetInfo(card)
        useSheet = _sh; useRow = card.row; useCol = card.col
        useCols = _sc; useRows = _sr
        if useSheet and useSheet > 0 then
            DrawCardImage(cx - w / 2, cy - h / 2, w, h, useSheet, useRow, useCol, useCols, useRows)
        end

        -- 绛夐樁鏍囩 (N/R/SR/SSR, 宸︿笅瑙?
        if fontId >= 0 then
            local qTag = QUALITY_TAGS[card.quality] or "N"
            local qc2 = QUALITY_COLORS[card.quality] or { 200, 195, 180 }
            local tagW = #qTag > 2 and 24 or (#qTag > 1 and 18 or 12)
            local tagH = 11
            local tagX = cx - w / 2 + 1
            local tagY = cy + h / 2 - tagH - 1
            nvgBeginPath(vg); nvgRoundedRect(vg, tagX, tagY, tagW, tagH, 2)
            nvgFillColor(vg, nvgRGBA(qc2[1], qc2[2], qc2[3], 180)); nvgFill(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 13)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(tagX + tagW / 2, tagY + tagH / 2, qTag)
        end

        -- 绛夌骇鏍囪 (Lv2+ 鍙ら摐鏍囪)
        if fontId >= 0 and card.level and card.level > 1 then
            local lvW = 22
            local lvH = 10
            local lvX = cx - lvW / 2
            local lvY = cy - h / 2 - lvH - 1
            nvgBeginPath(vg); nvgRoundedRect(vg, lvX, lvY, lvW, lvH, 2)
            nvgFillColor(vg, nvgRGBA(20, 15, 5, 180)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 210, 70, 60))
            nvgStrokeWidth(vg, 0.4); nvgStroke(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(cx, lvY + lvH / 2, "Lv" .. card.level)
        end

        -- === 鍏电寰界珷 (鍙充笅瑙? 鎴樹簤鐗? ===
        if card.troopType and rawget(_G, "TROOP_TYPES") then
            local tt = TROOP_TYPES[card.troopType]
            if tt then
                local tbW, tbH = 14, 11
                local tbX = cx + w / 2 - tbW - 1
                local tbY = cy + h / 2 - tbH - 1
                nvgBeginPath(vg); nvgRoundedRect(vg, tbX, tbY, tbW, tbH, 2)
                nvgFillColor(vg, nvgRGBA(tt.color[1], tt.color[2], tt.color[3], 200)); nvgFill(vg)
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 12)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(tbX + tbW / 2, tbY + tbH / 2, tt.icon)
            end
        end

        -- 鍛芥牸寰芥爣 (C0涓嶆樉绀? C1+鏄剧ず)
        local cons = card.constellation or 0
        if fontId >= 0 and cons > 0 then
            local cc = GameConfig.CONSTELLATION_COLORS[cons] or { 180, 175, 165 }
            local badgeR = 6
            local badgeX = cx + w / 2 - 2
            local badgeY = cy - h / 2 - 2
            nvgBeginPath(vg); nvgCircle(vg, badgeX, badgeY, badgeR)
            nvgFillColor(vg, nvgRGBA(cc[1], cc[2], cc[3], 220)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 150))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
            nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            DrawWhiteInkText(badgeX, badgeY, "C" .. cons)
        end

        -- === 闃佃惀鏍囪瘑 (鎴樹簤鐗? ===
        -- 鏈夊懡鏍兼椂鏀惧湪鍛芥牸寰芥爣宸︿晶, 鏃犲懡鏍兼椂鏀惧湪鍙充笂瑙?
        if card.faction and rawget(_G, "FACTIONS") then
            local fc = FACTIONS[card.faction]
            if fc then
                local fbR = 5
                local fbX, fbY
                if cons > 0 then
                    -- 鍛芥牸瀛樺湪: 闃佃惀鏍囪瘑鎸埌宸︿笂瑙?
                    fbX = cx - w / 2 + 2
                    fbY = cy - h / 2 - 2
                else
                    -- 鏃犲懡鏍? 鍗犵敤鍙充笂瑙?
                    fbX = cx + w / 2 - 2
                    fbY = cy - h / 2 - 2
                end
                nvgBeginPath(vg); nvgCircle(vg, fbX, fbY, fbR)
                nvgFillColor(vg, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 220)); nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(0, 0, 0, 100))
                nvgStrokeWidth(vg, 0.6); nvgStroke(vg)
                nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 10)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(fbX, fbY, fc.icon)
            end
        end

        -- 鍑哄叺璁℃暟 (鎴樻枟涓樉绀?
        if slot.filled and card and fontId >= 0 and gameState.battlePhase == "FIGHT" then
            -- 鍑哄叺璁℃暟 (鍗＄墝宸︿笂瑙掗啋鐩樉绀?
            local sc = slot.spawnCount or 0
            if sc > 0 then
                local isFlashing = slot.spawnFlash and slot.spawnFlash > 0
                local flashP = isFlashing and math.min(1, slot.spawnFlash / 0.3) or 0

                -- 鍑哄叺鏁板瓧鑳屾櫙鍦?(鏀惧湪鍗＄墝涓婃柟, 閬垮厤琚簿鐏甸伄鎸?
                local badgeX = cx - w / 2 + 6
                local badgeY = cy - h / 2 - 14
                local badgeR = 9 + (isFlashing and (4 * flashP) or 0)
                -- 闂厜鏃舵斁澶?楂樹寒
                nvgBeginPath(vg); nvgCircle(vg, badgeX, badgeY, badgeR)
                if isFlashing then
                    nvgFillColor(vg, nvgRGBA(80, 255, 120, math.floor(180 + 75 * flashP)))
                else
                    nvgFillColor(vg, nvgRGBA(40, 160, 80, 200))
                end
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(200, 255, 200, 180))
                nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

                -- 鏁板瓧
                nvgFontFaceId(vg, GetMainFont())
                nvgFontSize(vg, isFlashing and 17 or 14)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                DrawWhiteInkText(badgeX, badgeY, tostring(sc))

                -- 鍑哄叺闂厜: 鍚戜笂椋樺姩鐨?"鍏? 瀛楀姩鐢?
                if isFlashing then
                    local floatY = cy - h / 2 - 18 - (1 - flashP) * 20
                    local floatA = math.floor(220 * flashP)
                    nvgFontSize(vg, 16)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(120, 255, 160, floatA))
                    nvgText(vg, cx, floatY, "+1", nil)
                end
            end

            -- 閮ㄧ讲鍐峰嵈瑕嗙洊灞?(宸辨柟鍗＄墝, 鍐峰嵈涓殫鍖栧苟鏄剧ず鍊掕鏃?
            if isPlayer and slot.deployCD and slot.deployCD > 0 then
                -- 鏆楄壊閬僵
                nvgBeginPath(vg); nvgRoundedRect(vg, cx - w / 2, cy - h / 2, w, h, 3)
                nvgFillColor(vg, nvgRGBA(5, 5, 12, 110)); nvgFill(vg)

                -- 鍐峰嵈杩涘害鐜?(鍦嗗姬)
                local cdRatio = slot.deployCD / DEPLOY_CD
                local arcR = math.min(w, h) / 2 - 4
                nvgBeginPath(vg)
                nvgArc(vg, cx, cy, arcR, -math.pi / 2, -math.pi / 2 + cdRatio * math.pi * 2, 1)
                nvgStrokeColor(vg, nvgRGBA(255, 200, 100, 160))
                nvgStrokeWidth(vg, 2.5); nvgStroke(vg)

                -- CD鍊掕鏃舵暟瀛?
                if fontId >= 0 then
                    nvgFontFaceId(vg, GetMainFont()); nvgFontSize(vg, 20)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    DrawWhiteInkText(cx, cy, string.format("%.1f", slot.deployCD))
                end
            end
        end
    end
end


-- 鎷栨嫿鏃剁殑妲戒綅楂樹寒 (璁捐鍧愭爣, 鐢ㄥ渾褰㈠尮閰嶇煶鍙拌瑙?
function DrawSlotHighlights()
    if not dragState.active then return end
    local t = gameState.gameTime
    for _, slot in ipairs(PLAYER_SLOTS) do
        local pulse = 0.5 + 0.5 * math.sin(t * 5)
        -- 鐭冲彴鏄繎浼煎渾褰? 鐢ㄥ渾褰㈤珮浜尮閰?
        local r = SLOT_CARD_W / 2 + 3
        nvgBeginPath(vg); nvgCircle(vg, slot.cx, slot.cy, r)
        nvgStrokeColor(vg, nvgRGBA(255, 230, 100, math.floor(50 + 80 * pulse)))
        nvgStrokeWidth(vg, 1.8); nvgStroke(vg)
        -- 鍐呭湀寰厜
        local innerGrad = nvgRadialGradient(vg, slot.cx, slot.cy, r * 0.3, r,
            nvgRGBA(255, 230, 100, math.floor(15 * pulse)),
            nvgRGBA(255, 230, 100, 0))
        nvgBeginPath(vg); nvgCircle(vg, slot.cx, slot.cy, r)
        nvgFillPaint(vg, innerGrad); nvgFill(vg)
    end
end


-- 缁熶竴鑿滃崟鑳屾櫙锛堜笌棣栭〉鐩稿悓锛氳儗鏅浘 + 閬僵 + 娓愬彉锛?
function DrawMenuBg(W, H)
    DrawBgImage(IMG.menuBg, W, H, 1376, 768, 0)
    -- 杞诲井鏆楄壊瑕嗙洊 (鍥介浜屾鍏冿紝淇濇寔鏄庝寒)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 15)); nvgFill(vg)
    -- 搴曢儴杞诲井娓愭殫 (涓嶉伄鎸″簳鏍?
    local botGrad = nvgLinearGradient(vg, 0, H * 0.75, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(60, 40, 20, 40))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.75, W, H * 0.25)
    nvgFillPaint(vg, botGrad); nvgFill(vg)
    -- 椤堕儴杞诲井娓愭殫 (璁╂爣棰樺彲璇?
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, H * 0.10,
        nvgRGBA(60, 40, 20, 25), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H * 0.10)
    nvgFillPaint(vg, topGrad); nvgFill(vg)
end

-- 閫氱敤鍦烘櫙鑳屾櫙锛堟寚瀹氬浘鐗?+ 缁熶竴鍥介閬僵娓愬彉锛?
local function DrawSceneBg(imgHandle, W, H)
    DrawBgImage(imgHandle or IMG.menuBg, W, H, 1376, 768, 0)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(60, 40, 20, 12)); nvgFill(vg)
    local botGrad = nvgLinearGradient(vg, 0, H * 0.78, 0, H,
        nvgRGBA(0, 0, 0, 0), nvgRGBA(60, 40, 20, 35))
    nvgBeginPath(vg); nvgRect(vg, 0, H * 0.78, W, H * 0.22)
    nvgFillPaint(vg, botGrad); nvgFill(vg)
    local topGrad = nvgLinearGradient(vg, 0, 0, 0, H * 0.08,
        nvgRGBA(60, 40, 20, 20), nvgRGBA(0, 0, 0, 0))
    nvgBeginPath(vg); nvgRect(vg, 0, 0, W, H * 0.08)
    nvgFillPaint(vg, topGrad); nvgFill(vg)
end

-- 鍥鹃壌/鑻遍泟/鎶€鑳?瑁呭鑳屾櫙
function DrawCodexBg(W, H)  DrawSceneBg(IMG.codexBg, W, H) end
-- 璁剧疆鐣岄潰鑳屾櫙
function DrawSettingsBg(W, H) DrawSceneBg(IMG.settingsBg, W, H) end
-- 绀句氦闈㈡澘鑳屾櫙锛堥偖浠?濂藉弸/浜ゆ槗/鍔垮姏锛?
function DrawSocialBg(W, H) DrawSceneBg(IMG.panelBg, W, H) end
-- 寰侀€?鎴樻枟閫夋嫨鑳屾櫙
function DrawCombatBg(W, H) DrawSceneBg(IMG.battleBgNew, W, H) end
-- 鍑哄緛/閮ㄧ讲鑳屾櫙
function DrawDeployBg(W, H) DrawSceneBg(IMG.deployBg, W, H) end
-- 绂忓埄/绛惧埌鑳屾櫙
function DrawWelfareBg(W, H) DrawSceneBg(IMG.homeBg, W, H) end


function DrawToast(W, H)
    if toastState.timer <= 0 then return end
    local alpha = math.min(1.0, toastState.timer * 3.0) -- 娣″嚭
    local a = math.floor(alpha * 220)
    local msg = toastState.text
    nvgSave(vg)
    nvgFontFaceId(vg, GetMainFont())
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local tw = nvgTextBounds(vg, 0, 0, msg, nil) + 30
    local th = 36
    local tx = W / 2 - tw / 2
    local ty = H * 0.38
    -- 鑳屾櫙
    nvgBeginPath(vg)
    nvgRoundedRect(vg, tx, ty, tw, th, 8)
    nvgFillColor(vg, nvgRGBA(235, 215, 175, a)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(180, 140, 60, math.floor(alpha * 150)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    -- 鏂囧瓧
    nvgFillColor(vg, nvgRGBA(80, 40, 10, a))
    nvgText(vg, W / 2, ty + th / 2, msg, nil)
    nvgRestore(vg)
end


