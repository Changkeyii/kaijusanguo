-- ============================================================================
-- systems/skill.lua - 三国武灵录
-- ============================================================================


-- ============================================================================
-- 武技系统: 广告解锁 + 技能施放 + 伤害逻辑
-- ============================================================================

--- 解锁或升层武技（统一入口）
--- 返回 layer (新层数) 或 nil (失败)
function UnlockOrUpgradeSkill(skillIdx)
    local skill = SKILL_DEFS[skillIdx]
    if not skill then return nil end
    if not skill.unlocked then
        -- 首次解锁
        skill.unlocked = true
        skillLayers[skillIdx] = 1
        return 1
    else
        -- 已解锁，升层
        local cur = skillLayers[skillIdx] or 1
        if cur >= SKILL_MAX_LAYER then
            return nil  -- 已满层
        end
        skillLayers[skillIdx] = cur + 1
        return cur + 1
    end
end


-- (已移除看广告升层武技功能，武技只能通过召唤或残片合成升层)

--- 初始化AI对手技能系统 (排位/讨伐模式)
function InitAISkills()
    aiSkillState.enabled = false
    aiSkillState.availableSkills = {}
    aiSkillState.cooldowns = {}
    aiSkillState.castTimer = 0
    aiSkillState.nextCastTime = 4.0 + math.random() * 3.0  -- 首次释放4~7秒

    -- 仅排位或讨伐模式启用
    if not gameState.isRanked and not gameState.abyssFloor then return end

    -- 筛选有特效的可用武技 (排除 notAvailable 和治疗技能)
    local allAvailable = {}
    for i, skill in ipairs(SKILL_DEFS) do
        if not skill.notAvailable and skill.skillType ~= "heal" then
            table.insert(allAvailable, i)
        end
    end

    -- 从所有可用技能中随机选2个，整局只用这2个
    if #allAvailable >= 2 then
        -- Fisher-Yates 洗牌取前2
        for i = #allAvailable, 2, -1 do
            local j = math.random(1, i)
            allAvailable[i], allAvailable[j] = allAvailable[j], allAvailable[i]
        end
        aiSkillState.availableSkills = { allAvailable[1], allAvailable[2] }
    elseif #allAvailable == 1 then
        aiSkillState.availableSkills = { allAvailable[1] }
    end

    for _, idx in ipairs(aiSkillState.availableSkills) do
        aiSkillState.cooldowns[idx] = 0
    end

    if #aiSkillState.availableSkills > 0 then
        aiSkillState.enabled = true
        -- 讨伐模式高层加快释放频率
        local floor = gameState.abyssFloor or 0
        if floor >= 5 then
            aiSkillState.castInterval = 4.0
        elseif floor >= 3 then
            aiSkillState.castInterval = 5.0
        else
            aiSkillState.castInterval = 6.0
        end
        local names = {}
        for _, idx in ipairs(aiSkillState.availableSkills) do
            table.insert(names, SKILL_DEFS[idx].name)
        end
        print("=== AI技能系统启用: 本局随机选定 " .. table.concat(names, ", ") .. " ===")
    end
end


--- AI对手释放技能 (每帧在UpdateBattle中调用)
function UpdateAISkills(dt)
    if not aiSkillState.enabled then return end
    if #enemyUnits == 0 then return end  -- 没有敌方单位不释放

    -- 冷却递减
    for idx, cd in pairs(aiSkillState.cooldowns) do
        if cd > 0 then
            aiSkillState.cooldowns[idx] = cd - dt
            if aiSkillState.cooldowns[idx] < 0 then aiSkillState.cooldowns[idx] = 0 end
        end
    end

    -- 释放计时
    aiSkillState.castTimer = aiSkillState.castTimer + dt
    if aiSkillState.castTimer < aiSkillState.nextCastTime then return end

    -- 时间到了，尝试释放一个技能
    aiSkillState.castTimer = 0
    aiSkillState.nextCastTime = aiSkillState.castInterval + (math.random() - 0.5) * 2.0  -- 随机浮动

    -- 筛选当前可用(不在CD中)的技能
    local readySkills = {}
    for _, idx in ipairs(aiSkillState.availableSkills) do
        if aiSkillState.cooldowns[idx] <= 0 then
            table.insert(readySkills, idx)
        end
    end
    if #readySkills == 0 then return end

    -- 随机选一个技能
    local chosenIdx = readySkills[math.random(1, #readySkills)]
    local skill = SKILL_DEFS[chosenIdx]
    if not skill then return end

    -- 设置冷却 (AI冷却比玩家稍长)
    aiSkillState.cooldowns[chosenIdx] = skill.maxCooldown * 1.5

    -- 计算目标位置
    local targetX, targetY
    if skill.skillType == "line" then
        -- 线型技能: 随机选一个车道
        local laneIdx = math.random(1, NUM_LANES)
        targetX = GetLaneCenterX(laneIdx)
        targetY = BATTLE_ZONE.centerY
    else
        -- AOE/矩形/区域技能: 优先瞄准玩家单位密集区域
        if #playerUnits > 0 then
            -- 随机选一个玩家单位作为目标中心
            local target = playerUnits[math.random(1, #playerUnits)]
            if target and target.alive then
                targetX = target.x + (math.random() - 0.5) * 40
                targetY = target.y + (math.random() - 0.5) * 30
            end
        end
        -- 如果没有合适目标，随机选战场玩家侧区域 (横屏: 左半部)
        if not targetX then
            targetX = BATTLE_ZONE.playerLine + math.random() * (BATTLE_ZONE.centerX - BATTLE_ZONE.playerLine) * 0.8
            targetY = BATTLE_ZONE.top + math.random() * (BATTLE_ZONE.bottom - BATTLE_ZONE.top)
        end
    end

    -- 释放音效
    if skill.skillType == "line" then
        PlaySFX(AUDIO.sfx_slash)
    else
        PlaySFX(AUDIO.sfx_cast)
    end

    -- 创建技能特效 (标记 isEnemySkill = true)
    if skill.skillType == "line" then
        -- 横屏: 车道沿Y轴排列, 用targetY确定车道
        local laneIdx = math.floor((targetY - BATTLE_ZONE.top) / LANE_WIDTH) + 1
        laneIdx = math.max(1, math.min(NUM_LANES, laneIdx))
        local laneCY = GetLaneCenterY(laneIdx)
        -- AI线型技能: 从敌方线出发向玩家线飞行 (横屏: X减小=向左)
        local startX = BATTLE_ZONE.enemyLine - 20
        local endX   = BATTLE_ZONE.playerLine - 30
        local dist   = startX - endX  -- 飞行总距离
        local fxData = SKILL_FX_SHEETS[skill.iconIdx]
        local frames = fxData and fxData.frames or 8
        local fps    = fxData and fxData.fps or 12
        local dur    = frames / fps
        local speed  = dist / dur
        table.insert(activeSkillEffects, {
            x = startX,
            y = laneCY,
            startX = startX,
            endX = endX,
            skillIdx = chosenIdx,
            timer = 0,
            frameIdx = 0,
            damaged = false,
            duration = dur,
            lineSpeed = speed,
            isLine = true,
            laneIdx = laneIdx,
            hitUnits = {},
            isEnemySkill = true,  -- 标记为AI技能
        })
    else
        table.insert(activeSkillEffects, {
            x = targetX,
            y = targetY,
            skillIdx = chosenIdx,
            timer = 0,
            frameIdx = 0,
            damaged = false,
            duration = skill.animDuration,
            isEnemySkill = true,  -- 标记为AI技能
        })
    end

    AddFloatText(targetX, targetY - 60, "敌方: " .. skill.name .. "!", 1.2,
        { math.min(255, skill.color[1] + 40), math.max(0, skill.color[2] - 30), math.max(0, skill.color[3] - 30) }, 20)
    print("=== AI释放武技: " .. skill.name .. " at (" .. math.floor(targetX) .. "," .. math.floor(targetY) .. ") ===")
end


--- 在目标位置释放技能
function CastSkill(skillIdx, targetX, targetY)
    local skill = SKILL_DEFS[skillIdx]
    if not skill or not skill.unlocked then return end
    if skill.cooldown > 0 then return end

    -- 设置冷却 (INT加成: 缩减冷却时间)
    skill.cooldown = skill.maxCooldown * (1 - (battleIntCdReduction or 0))

    -- 释放音效
    if skill.skillType == "line" then
        PlaySFX(AUDIO.sfx_slash)
    else
        PlaySFX(AUDIO.sfx_cast)
    end

    -- 创建技能特效
    if skill.skillType == "line" then
        -- 线型技能: 横屏吸附到最近车道中心(Y轴), 从玩家线出发向敌方飞行(X轴向右)
        local laneIdx = math.floor((targetY - BATTLE_ZONE.top) / LANE_WIDTH) + 1
        laneIdx = math.max(1, math.min(NUM_LANES, laneIdx))
        local laneCY = GetLaneCenterY(laneIdx)
        local startX = BATTLE_ZONE.playerLine + 20
        local endX   = BATTLE_ZONE.enemyLine + 30
        local dist   = endX - startX  -- 飞行总距离 (像素)
        -- 动画恰好播完一次 = 飞行全程, 速度自动计算
        local fxData = SKILL_FX_SHEETS[skill.iconIdx]
        local frames = fxData and fxData.frames or 8
        local fps    = fxData and fxData.fps or 12
        local dur    = frames / fps              -- 动画总时长(秒)
        local speed  = dist / dur                -- 自动算出飞行速度
        table.insert(activeSkillEffects, {
            x = startX,
            y = laneCY,
            startX = startX,
            endX = endX,
            skillIdx = skillIdx,
            timer = 0,
            frameIdx = 0,
            damaged = false,
            duration = dur,
            lineSpeed = speed,
            isLine = true,
            laneIdx = laneIdx,
            hitUnits = {},
        })
    else
        -- AOE技能: 固定位置爆发
        table.insert(activeSkillEffects, {
            x = targetX,
            y = targetY,
            skillIdx = skillIdx,
            timer = 0,
            frameIdx = 0,
            damaged = false,
            duration = skill.animDuration,
        })
    end

    AddFloatText(targetX, targetY - 60, skill.name .. "!", 1.2, { skill.color[1], skill.color[2], skill.color[3] }, 20)
    print("=== 释放武技: " .. skill.name .. " at (" .. math.floor(targetX) .. "," .. math.floor(targetY) .. ") ===")
end


--- 更新技能特效 (在 UpdateBattle 中调用)
function UpdateSkillEffects(dt)
    -- 冷却递减
    for _, skill in ipairs(SKILL_DEFS) do
        if skill.cooldown > 0 then
            skill.cooldown = skill.cooldown - dt
            if skill.cooldown < 0 then skill.cooldown = 0 end
        end
    end

    -- 更新活跃特效
    for i = #activeSkillEffects, 1, -1 do
        local eff = activeSkillEffects[i]
        eff.timer = eff.timer + dt

        local skill = SKILL_DEFS[eff.skillIdx]
        if not skill then
            table.remove(activeSkillEffects, i)
            goto continue_fx
        end

        local fxData = SKILL_FX_SHEETS[skill.iconIdx]
        local frameCount = fxData and fxData.frames or SKILL_FRAME_COUNT

        if eff.isLine then
            -- ======== 线型技能: 向目标基地飞行, 持续命中 ========
            if eff.isEnemySkill then
                eff.x = eff.x - eff.lineSpeed * dt  -- AI技能: 向左飞行(X减小=向玩家)
            else
                eff.x = eff.x + eff.lineSpeed * dt  -- 玩家技能: 向右飞行(X增大=向敌方)
            end
            -- 帧动画只播一次 (clamp到最后一帧)
            local fps = fxData and fxData.fps or 12
            eff.frameIdx = math.min(math.floor(eff.timer * fps), frameCount - 1)

            -- 飞行过程中持续检测命中 (横向宽度内的单位)
            local halfW = (skill.lineWidth or 50) / 2
            local lineLayerMul = 1 + ((skillLayers[eff.skillIdx] or 1) - 1) * 0.2
            -- INT加成: 仅玩家技能享受智力伤害加成
            if not eff.isEnemySkill then lineLayerMul = lineLayerMul * (battleIntSkillMult or 1) end
            local targetUnits = eff.isEnemySkill and playerUnits or enemyUnits
            for _, u in ipairs(targetUnits) do
                if u.alive and not eff.hitUnits[u] then
                    if math.abs(u.y - eff.y) <= halfW and math.abs(u.x - eff.x) <= 25 then
                        eff.hitUnits[u] = true
                        PlaySFX(AUDIO.sfx_hit)
                        local dmg = math.ceil(skill.damage * lineLayerMul)
                        u.hp = u.hp - dmg
                        u.flashTimer = 0.3
                        local isCrit = math.random() < 0.2
                        if isCrit then
                            dmg = math.ceil(dmg * 1.8)
                            u.hp = u.hp - math.ceil(skill.damage * lineLayerMul * 0.8)
                        end
                        AddFloatText(u.x, u.y - 12, math.floor(dmg) .. (isCrit and "!" or ""),
                            0.8, isCrit and { 255, 220, 50 } or { skill.color[1], skill.color[2], skill.color[3] },
                            isCrit and 28 or 22)
                        for _ = 1, 3 do
                            AddParticle(u.x, u.y, {
                                vx = (math.random() - 0.5) * 60,
                                vy = -(math.random() * 30 + 10),
                                life = 0.3, size = 2,
                                color = { skill.color[1], skill.color[2], skill.color[3] },
                            })
                        end
                        if u.hp <= 0 then
                            u.alive = false
                            if not eff.isEnemySkill then
                                gameState.totalKills = gameState.totalKills + 1
                            end
                            for _ = 1, 8 do
                                AddParticle(u.x, u.y, {
                                    vx = (math.random() - 0.5) * 120,
                                    vy = -(math.random() * 60 + 15),
                                    life = 0.5, size = 3,
                                    color = { skill.color[1], math.random(100, 200), 40 },
                                })
                            end
                        end
                    end
                end
            end

            -- 尾迹粒子 (横屏: 沿X轴拖尾)
            if math.random() < 0.6 then
                local sc = skill.color
                local trailOffX = eff.isEnemySkill and 20 or -20
                AddParticle(eff.x + trailOffX, eff.y + (math.random() - 0.5) * 30, {
                    vx = eff.isEnemySkill and (math.random() * 15 + 5) or -(math.random() * 15 + 5),
                    vy = (math.random() - 0.5) * 20,
                    life = 0.3 + math.random() * 0.2,
                    size = 1.5 + math.random() * 2,
                    color = { sc[1], sc[2], sc[3] },
                })
            end

            -- 动画播完 / 到达终点 >> 移除 (横屏: X轴判断)
            local reachedEnd
            if eff.isEnemySkill then
                reachedEnd = eff.x <= (eff.endX or BATTLE_ZONE.playerLine - 30)
            else
                reachedEnd = eff.x >= (eff.endX or BATTLE_ZONE.enemyLine + 30)
            end
            if eff.timer >= eff.duration or reachedEnd then
                table.remove(activeSkillEffects, i)
            end
        elseif skill.skillType == "heal" then
            -- ======== 治疗技能: 中间帧延长停留 + 持续回血 ========
            -- 帧播放策略: 前8帧正常播 >> 中间帧(7-9)停留holdTime >> 后6帧正常播
            local fps = 12
            local holdStart = 7    -- 停留起始帧 (0-indexed)
            local holdEnd   = 9    -- 停留结束帧
            local holdTime  = 3.0  -- 中间帧停留总时长(秒)
            local introTime = (holdStart + 1) / fps   -- 前段: 帧0~7 = 8帧
            local outroFrames = frameCount - holdEnd - 1  -- 后段帧数
            local outroTime = outroFrames / fps
            local totalDur = introTime + holdTime + outroTime

            if eff.timer < introTime then
                -- 前段: 正常播放 0~holdStart
                eff.frameIdx = math.min(holdStart, math.floor(eff.timer * fps))
            elseif eff.timer < introTime + holdTime then
                -- 中间段: 在 holdStart~holdEnd 之间缓慢循环
                local holdProgress = (eff.timer - introTime) / holdTime
                local holdRange = holdEnd - holdStart + 1
                eff.frameIdx = holdStart + math.floor(holdProgress * holdRange * 3) % holdRange
            else
                -- 后段: 从 holdEnd+1 播放到结束
                local outroElapsed = eff.timer - introTime - holdTime
                eff.frameIdx = math.min(frameCount - 1, holdEnd + 1 + math.floor(outroElapsed * fps))
            end

            -- 持续治疗己方单位 (每 healInterval 秒一次)
            if not eff.lastHealTime then eff.lastHealTime = 0 end
            if eff.timer - eff.lastHealTime >= skill.healInterval then
                eff.lastHealTime = eff.timer
                local healAmt = math.ceil(skill.healPerTick * (battleIntSkillMult or 1))
                local sc = skill.color
                for _, u in ipairs(playerUnits) do
                    if u.alive then
                        local ddx = u.x - eff.x
                        local ddy = u.y - eff.y
                        if math.sqrt(ddx * ddx + ddy * ddy) <= skill.radius then
                            u.hp = math.min(u.maxHp or u.hp + healAmt, u.hp + healAmt)
                            -- 绿色回血浮字
                            AddFloatText(u.x, u.y - 12, "+" .. healAmt, 0.6, { 80, 230, 80 }, 18)
                        end
                    end
                end
            end

            -- 治疗粒子 (绿色上升)
            if math.random() < 0.35 then
                local sc = skill.color
                local angle = math.random() * 6.28
                local dist = skill.radius * 0.5 * math.random()
                AddParticle(eff.x + math.cos(angle) * dist, eff.y + math.sin(angle) * dist, {
                    vx = (math.random() - 0.5) * 20,
                    vy = -(math.random() * 25 + 15),
                    life = 0.5 + math.random() * 0.4,
                    size = 1.5 + math.random() * 2,
                    color = { sc[1], sc[2], sc[3] },
                })
            end

            -- 动画结束 >> 移除
            if eff.timer >= totalDur then
                table.remove(activeSkillEffects, i)
            end
        elseif skill.skillType == "zone" then
            -- ======== 区域技能(冰狱封疆): 中间帧延长 + 持续伤害 + 减速 ========
            local fps = 12
            local holdStart = 7
            local holdEnd   = 9
            local holdTime  = 3.0
            local introTime = (holdStart + 1) / fps
            local outroFrames = frameCount - holdEnd - 1
            local outroTime = outroFrames / fps
            local totalDurZ = introTime + holdTime + outroTime

            if eff.timer < introTime then
                eff.frameIdx = math.min(holdStart, math.floor(eff.timer * fps))
            elseif eff.timer < introTime + holdTime then
                local holdProgress = (eff.timer - introTime) / holdTime
                local holdRange = holdEnd - holdStart + 1
                eff.frameIdx = holdStart + math.floor(holdProgress * holdRange * 3) % holdRange
            else
                local outroElapsed = eff.timer - introTime - holdTime
                eff.frameIdx = math.min(frameCount - 1, holdEnd + 1 + math.floor(outroElapsed * fps))
            end

            -- 持续伤害 + 减速 (每 tickInterval 秒一次)
            if not eff.lastZoneTick then eff.lastZoneTick = 0 end
            if eff.timer - eff.lastZoneTick >= skill.tickInterval then
                eff.lastZoneTick = eff.timer
                local zoneLayerMul = 1 + ((skillLayers[eff.skillIdx] or 1) - 1) * 0.2
                -- INT加成: 仅玩家技能享受智力伤害加成
                if not eff.isEnemySkill then zoneLayerMul = zoneLayerMul * (battleIntSkillMult or 1) end
                local dmg = math.ceil(skill.dmgPerTick * zoneLayerMul)
                local sc = skill.color
                local zoneTargets = eff.isEnemySkill and playerUnits or enemyUnits
                for _, u in ipairs(zoneTargets) do
                    if u.alive then
                        local ddx = u.x - eff.x
                        local ddy = u.y - eff.y
                        if math.sqrt(ddx * ddx + ddy * ddy) <= skill.radius then
                            u.hp = u.hp - dmg
                            AddFloatText(u.x, u.y - 12, "-" .. dmg, 0.6, { 100, 180, 255 }, 18)
                            -- 标记减速 (每帧会被重置,只在zone存活期间生效)
                            u.zoneSlowUntil = gameState.gameTime + skill.tickInterval + 0.1
                            u.zoneSlowFactor = skill.slowFactor
                            if u.hp <= 0 then
                                u.hp = 0
                                u.alive = false
                            end
                        end
                    end
                end
            end

            -- 冰霜粒子 (蓝/青色)
            if math.random() < 0.4 then
                local angle = math.random() * 6.28
                local dist = skill.radius * 0.5 * math.random()
                AddParticle(eff.x + math.cos(angle) * dist, eff.y + math.sin(angle) * dist, {
                    vx = (math.random() - 0.5) * 15,
                    vy = -(math.random() * 20 + 10),
                    life = 0.5 + math.random() * 0.4,
                    size = 1.5 + math.random() * 2,
                    color = { 100 + math.random(80), 180 + math.random(60), 255 },
                })
            end

            -- 动画结束 >> 移除
            if eff.timer >= totalDurZ then
                table.remove(activeSkillEffects, i)
            end
        else
            -- ======== AOE/矩形技能: 固定位置爆发 ========
            local frameTime = eff.duration / frameCount
            eff.frameIdx = math.min(frameCount - 1, math.floor(eff.timer / frameTime))

            -- 在伤害帧触发范围伤害 (只触发一次)
            if not eff.damaged and eff.frameIdx >= skill.damageFrame then
                eff.damaged = true
                PlaySFX(AUDIO.sfx_hit)
                ApplySkillDamage(eff.x, eff.y, skill, eff.skillIdx, eff.isEnemySkill)
            end

            -- 矩形持续伤害 (夜影蚀径等: dmgPerTick + tickInterval)
            if skill.dmgPerTick and skill.tickInterval then
                if not eff.lastRectTick then eff.lastRectTick = 0 end
                if eff.timer - eff.lastRectTick >= skill.tickInterval then
                    eff.lastRectTick = eff.timer
                    local halfW = skill.rectW and (skill.rectW / 2) or skill.radius
                    local halfH = skill.rectH and (skill.rectH / 2) or skill.radius
                    local rectTargets = eff.isEnemySkill and playerUnits or enemyUnits
                    for _, u in ipairs(rectTargets) do
                        if u.alive then
                            local ddx = math.abs(u.x - eff.x)
                            local ddy = math.abs(u.y - eff.y)
                            if ddx <= halfW and ddy <= halfH then
                                local rectLayerMul = 1 + ((skillLayers[eff.skillIdx] or 1) - 1) * 0.2
                                -- INT加成: 仅玩家技能享受智力伤害加成
                                if not eff.isEnemySkill then rectLayerMul = rectLayerMul * (battleIntSkillMult or 1) end
                                local rectDmg = math.ceil(skill.dmgPerTick * rectLayerMul)
                                u.hp = u.hp - rectDmg
                                AddFloatText(u.x, u.y - 12, "-" .. rectDmg, 0.6, { 160, 80, 220 }, 18)
                                if u.hp <= 0 then u.hp = 0; u.alive = false end
                            end
                        end
                    end
                end
            end

            -- 每帧产生粒子 (矩形用矩形分布, AOE用圆形分布)
            if math.random() < 0.4 then
                local sc = skill.color
                local px, py
                if skill.skillType == "rect" then
                    px = eff.x + (math.random() - 0.5) * skill.rectW * 0.4
                    py = eff.y + (math.random() - 0.5) * skill.rectH * 0.4
                else
                    local angle = math.random() * 6.28
                    local dist = skill.radius * 0.4 * math.random()
                    px = eff.x + math.cos(angle) * dist
                    py = eff.y + math.sin(angle) * dist
                end
                AddParticle(px, py, {
                    vx = (math.random() - 0.5) * 40,
                    vy = -(math.random() * 30 + 10),
                    life = 0.3 + math.random() * 0.3,
                    size = 1.5 + math.random() * 2,
                    color = { sc[1], sc[2], sc[3] },
                })
            end

            -- 动画结束 >> 移除
            if eff.timer >= eff.duration then
                table.remove(activeSkillEffects, i)
            end
        end
        ::continue_fx::
    end
end


--- 对目标区域内的单位造成伤害 (isEnemy=true时伤害玩家单位)
function ApplySkillDamage(cx, cy, skill, skillIdx, isEnemySkill)
    local radius = skill.radius
    local layerMul = 1.0
    if skillIdx then
        local layer = skillLayers[skillIdx] or 1
        layerMul = 1 + (layer - 1) * 0.2  -- 每层+20%伤害
    end
    -- INT加成: 仅玩家技能享受智力伤害加成
    if not isEnemySkill then layerMul = layerMul * (battleIntSkillMult or 1) end
    local baseDmg = math.ceil(skill.damage * layerMul)
    local hitCount = 0
    local isRect = skill.skillType == "rect"
    local halfW = isRect and (skill.rectW / 2) or 0
    local halfH = isRect and (skill.rectH / 2) or 0

    local dmgTargets = isEnemySkill and playerUnits or enemyUnits
    for _, u in ipairs(dmgTargets) do
        if u.alive then
            local ddx = u.x - cx
            local ddy = u.y - cy
            local inRange
            if isRect then
                inRange = math.abs(ddx) <= halfW and math.abs(ddy) <= halfH
            else
                inRange = math.sqrt(ddx * ddx + ddy * ddy) <= radius
            end
            if inRange then
                local dist = math.sqrt(ddx * ddx + ddy * ddy)
                local maxDist = isRect and math.sqrt(halfW * halfW + halfH * halfH) or radius
                -- 距离衰减: 中心全额, 边缘50%
                local falloff = 1.0 - (dist / maxDist) * 0.5
                local dmg = math.ceil(baseDmg * falloff)
                u.hp = u.hp - dmg
                u.flashTimer = 0.3

                -- 击飞微位移
                if dist > 1 then
                    u.x = u.x + (ddx / dist) * 8
                    u.y = u.y + (ddy / dist) * 8
                end

                local isCrit = math.random() < 0.15
                if isCrit then
                    dmg = math.ceil(dmg * 1.8)
                    u.hp = u.hp - math.ceil(baseDmg * falloff * 0.8)  -- 暴击额外伤害
                end

                AddFloatText(u.x, u.y - 12, math.floor(dmg) .. (isCrit and "!" or ""),
                    0.8, isCrit and { 255, 220, 50 } or { 255, 160, 60 },
                    isCrit and 28 or 22)

                -- 命中粒子
                for _ = 1, 4 do
                    AddParticle(u.x, u.y, {
                        vx = (math.random() - 0.5) * 80,
                        vy = -(math.random() * 40 + 10),
                        life = 0.4 + math.random() * 0.3,
                        size = 2 + math.random() * 2,
                        color = { 255, math.random(80, 160), 30 },
                    })
                end

                if u.hp <= 0 then
                    u.alive = false
                    if not isEnemySkill then
                        gameState.totalKills = gameState.totalKills + 1
                    end
                    -- 击杀爆炸粒子
                    for _ = 1, 10 do
                        AddParticle(u.x, u.y, {
                            vx = (math.random() - 0.5) * 140,
                            vy = -(math.random() * 70 + 15),
                            life = 0.6 + math.random() * 0.5,
                            size = 2.5 + math.random() * 3,
                            color = { 255, math.random(100, 200), 40 },
                        })
                    end
                end
                hitCount = hitCount + 1
            end
        end
    end

    if hitCount > 0 then
        AddFloatText(cx, cy - 80, "命中 " .. hitCount .. " 个目标!", 1.5, { 255, 200, 80 }, 18)
    else
        AddFloatText(cx, cy - 50, "未命中", 1.0, { 180, 160, 140 }, 18)
    end
end


--- 武技残片合成，返回 true 表示已处理
function TryComposeSkillFrag(skillIdx)
    local cnt = skillFragments[skillIdx] or 0
    if cnt < SKILL_FRAG_EXCHANGE then return false end
    local layer = UnlockOrUpgradeSkill(skillIdx)
    if not layer then
        -- 已满层: 消耗残片, 返还玉壁
        skillFragments[skillIdx] = cnt - SKILL_FRAG_EXCHANGE
        if skillFragments[skillIdx] <= 0 then skillFragments[skillIdx] = nil end
        local refund = SKILL_MAX_REFUND_JADE or 30
        playerInfo.jade = playerInfo.jade + refund
        local tech = SKILL_TECHNIQUES[skillIdx]
        local skName = tech and tech.name or ("武技#" .. skillIdx)
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, skName .. " 已满层! 返还 " .. refund .. " 玉壁", 2.0, { 255, 215, 0 }, 18)
        PlaySFX(AUDIO.sfx_click)
        SaveGameProgress()
        return true
    end
    skillFragments[skillIdx] = cnt - SKILL_FRAG_EXCHANGE
    if skillFragments[skillIdx] <= 0 then skillFragments[skillIdx] = nil end
    local tech = SKILL_TECHNIQUES[skillIdx]
    local skName = tech and tech.name or ("武技#" .. skillIdx)
    local msg = layer == 1
        and ("合成成功! 获得武技: " .. skName)
        or ("合成成功! " .. skName .. " 升至 " .. layer .. " 层")
    AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, msg, 2.0, { 255, 220, 100 }, 20)
    PlaySFX(AUDIO.sfx_click)
    SaveGameProgress()
    print("=== 合成武技: " .. skName .. " Lv" .. layer .. " ===")
    return true
end


--- 武灵残片合成辅助函数
function TryComposeHeroFrag(cardIdx)
    local card = HERO_CARDS[cardIdx]
    local need = HERO_FRAG_EXCHANGE[card.quality] or 20
    local cnt = heroFragments[cardIdx] or 0
    if cnt >= need then
        heroFragments[cardIdx] = cnt - need
        if heroFragments[cardIdx] <= 0 then heroFragments[cardIdx] = nil end
        local hero = playerHeroes[cardIdx]
        if hero and hero.owned then
            if hero.constellation < GameConfig.MAX_CONSTELLATION then
                hero.constellation = hero.constellation + 1
            end
        else
            playerHeroes[cardIdx] = { owned = true, constellation = 0 }
        end
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3,
            "合成成功! 获得武灵: " .. card.name, 2.0, { 255, 220, 100 }, 20)
        PlaySFX(AUDIO.sfx_click)
        SaveGameProgress()
    end
end


--- 一键合成：批量合成所有够数量的残片
function OneKeyCompose()
    local heroCount = 0
    local skillCount = 0
    local totalJadeRefund = 0

    -- 武灵残片合成（反复合成直到不够）
    for cardIdx, cnt in pairs(heroFragments) do
        local card = HERO_CARDS[cardIdx]
        if card then
            local need = HERO_FRAG_EXCHANGE[card.quality] or 20
            while (heroFragments[cardIdx] or 0) >= need do
                heroFragments[cardIdx] = heroFragments[cardIdx] - need
                if heroFragments[cardIdx] <= 0 then heroFragments[cardIdx] = nil end
                local hero = playerHeroes[cardIdx]
                if hero and hero.owned then
                    if hero.constellation < GameConfig.MAX_CONSTELLATION then
                        hero.constellation = hero.constellation + 1
                    end
                    -- 满命座不额外处理，碎片正常消耗
                else
                    playerHeroes[cardIdx] = { owned = true, constellation = 0 }
                end
                heroCount = heroCount + 1
            end
        end
    end

    -- 武技残片合成（反复合成直到不够）
    for skillIdx, cnt in pairs(skillFragments) do
        while (skillFragments[skillIdx] or 0) >= SKILL_FRAG_EXCHANGE do
            local layer = UnlockOrUpgradeSkill(skillIdx)
            skillFragments[skillIdx] = skillFragments[skillIdx] - SKILL_FRAG_EXCHANGE
            if skillFragments[skillIdx] <= 0 then skillFragments[skillIdx] = nil end
            if not layer then
                -- 已满层，返还玉壁
                local refund = SKILL_MAX_REFUND_JADE or 30
                playerInfo.jade = playerInfo.jade + refund
                totalJadeRefund = totalJadeRefund + refund
            end
            skillCount = skillCount + 1
        end
    end

    local total = heroCount + skillCount
    if total > 0 then
        local msg = "一键合成完成! "
        if heroCount > 0 then msg = msg .. "武灵×" .. heroCount .. " " end
        if skillCount > 0 then msg = msg .. "武技×" .. skillCount .. " " end
        if totalJadeRefund > 0 then msg = msg .. "(返还" .. totalJadeRefund .. "玉壁)" end
        AddFloatText(DESIGN_W / 2, DESIGN_H * 0.3, msg, 2.5, { 255, 220, 80 }, 18)
        PlaySFX(AUDIO.sfx_click)
        SaveGameProgress()
    end
    return total
end
