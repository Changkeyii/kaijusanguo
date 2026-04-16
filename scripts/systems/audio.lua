-- ============================================================================
-- systems/audio.lua - 三国武灵录
-- ============================================================================


function Stop()
    if vg then nvgDelete(vg); vg = nil end
    if audioState.bgmSource then audioState.bgmSource:Stop() end
end


-- ============================================================================
-- 音频播放函数
-- ============================================================================

--- 播放/切换 BGM
function PlayBGM(path)
    if not audioState.bgmSource or path == audioState.currentBGM then return end
    local snd = cache:GetResource("Sound", path)
    if snd then
        snd.looped = true
        audioState.bgmSource:Stop()
        audioState.bgmSource.gain = gameSettings.musicVolume
        audioState.bgmSource:Play(snd)
        audioState.currentBGM = path
    end
end


--- 停止 BGM
function StopBGM()
    if audioState.bgmSource then audioState.bgmSource:Stop() end
    audioState.currentBGM = ""
end


--- 广告播放结束后恢复 BGM（无论成功或失败都调用）
function ResumeAfterAd()
    -- pcall 保护：广告返回后引擎音频状态可能不稳定
    local ok, err = pcall(function()
        if audioState.currentBGM ~= "" and audioState.bgmSource then
            local snd = cache:GetResource("Sound", audioState.currentBGM)
            if snd then
                snd.looped = true
                audioState.bgmSource.gain = gameSettings.musicVolume
                audioState.bgmSource:Play(snd)
            end
        end
    end)
    if not ok then
        print("[广告] ResumeAfterAd 异常(已忽略): " .. tostring(err))
    end
end


--- 播放一次性音效
function PlaySFX(path)
    if not audioState.sfxNode then return end
    local snd = cache:GetResource("Sound", path)
    if not snd then return end
    local src = audioState.sfxNode:CreateComponent("SoundSource")
    src.soundType = "Effect"
    src.gain = gameSettings.sfxVolume
    src.autoRemoveMode = REMOVE_COMPONENT
    src:Play(snd)
end
