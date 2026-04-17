-- ============================================================================
-- utils.lua - 三国武灵录
-- ============================================================================

--- 获取当前玩家 UID（服务端权威，统一入口）
---@return number
function GetMyUid()
    return (rawget(_G, "netState") and netState.userId and netState.userId ~= 0)
        and netState.userId or 0
end

function nvgText(ctx, x, y, text, endPtr)
    nvgSave(ctx)
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 150))
    _nvgTextOrig(ctx, x - 1, y, text, endPtr)
    _nvgTextOrig(ctx, x + 1, y, text, endPtr)
    _nvgTextOrig(ctx, x, y - 1, text, endPtr)
    _nvgTextOrig(ctx, x, y + 1, text, endPtr)
    nvgRestore(ctx)
    return _nvgTextOrig(ctx, x, y, text, endPtr)
end


--- 格式化战力数值 (带颜色)
function FormatPower(power)
    if power >= 10000 then
        return string.format("%.1fw", power / 10000)
    elseif power >= 1000 then
        return string.format("%.1fk", power / 1000)
    end
    return tostring(math.floor(power))
end


--- 格式化虎符数量 (超1000用k, 超100万用m, 超10亿用b)
function FormatJade(amount)
    if amount >= 1000000000 then
        return string.format("%.1fb", amount / 1000000000)
    elseif amount >= 1000000 then
        return string.format("%.1fm", amount / 1000000)
    elseif amount >= 1000 then
        return string.format("%.1fk", amount / 1000)
    end
    return tostring(math.floor(amount))
end


-- ============================================================================
-- 每日任务: 重置 & 追踪
-- ============================================================================
function GetTodayString()
    return os.date("%Y-%m-%d")
end


-- ============================================================================
-- 周任务: 重置 & 追踪
-- ============================================================================
function GetWeekString()
    return os.date("%Y-%W")
end


--- 获取当前主字体 ID (统一使用 MiSans)
function GetMainFont()
    local style = gameSettings.fontStyle or "misans"
    if style == "kuaile" and fontGame >= 0 then return fontGame end
    if style == "wenkai" and fontFZ >= 0 then return fontFZ end
    if style == "xingshu" and fontArt >= 0 then return fontArt end
    return fontId  -- misans 默认
end


function DeepCopy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = (type(v) == "table") and DeepCopy(v) or v end
    return c
end


--- 获取当天日期字符串 (格式: "YYYY-MM-DD")
function GetTodayDateStr()
    return os.date("%Y-%m-%d")
end


--- 检查当前平台是否为移动端 (Android/iOS)
--- @return boolean
function IsMobilePlatform()
    local p = GetPlatform and GetPlatform() or "unknown"
    return p == "Android" or p == "iOS"
end


--- 安全写入剪贴板 (优先系统剪贴板，Web平台仅用内部剪贴板)
function SafeSetClipboard(text)
    _internalClipboard = text or ""
    -- Web/WASM平台: 系统剪贴板API会导致JS崩溃，直接跳过
    if _isWebPlatform() then
        pcall(function()
            ui.useSystemClipboard = false
            ui:SetClipboardText(text)
        end)
        return false
    end
    -- 原生平台: 尝试系统剪贴板
    local ok = pcall(function()
        ui.useSystemClipboard = true
        ui:SetClipboardText(text)
    end)
    if not ok then
        pcall(function()
            ui.useSystemClipboard = false
            ui:SetClipboardText(text)
        end)
    end
    return ok
end


--- 安全读取剪贴板 (优先系统剪贴板，Web平台仅用内部剪贴板)
function SafeGetClipboard()
    -- Web/WASM平台: 不调用系统剪贴板
    if not _isWebPlatform() then
        local ok, text = pcall(function()
            ui.useSystemClipboard = true
            return ui:GetClipboardText()
        end)
        if ok and text and type(text) == "string" and #text > 0 then
            return text
        end
    end
    -- 内部剪贴板
    local ok2, text2 = pcall(function()
        ui.useSystemClipboard = false
        return ui:GetClipboardText()
    end)
    if ok2 and text2 and type(text2) == "string" and #text2 > 0 then
        return text2
    end
    if #_internalClipboard > 0 then return _internalClipboard end
    return nil
end


-- ============================================================================
-- 坐标转换 (含华为/HarmonyOS 触摸坐标系自动检测)
-- ============================================================================

--- 获取触摸坐标的有效DPR（自动检测设备是返回物理像素还是逻辑像素）
--- @return number effectiveDPR 1.0表示触摸坐标已是逻辑像素，>1表示物理像素需要除DPR
function GetTouchDPR()
    if touchCoordDPR then return touchCoordDPR end
    return GetGraphics():GetDPR()
end


--- 自动检测触摸坐标系统（在前N次触摸时调用）
--- 原理：如果触摸坐标超过了逻辑像素范围(physW/dpr)，则一定是物理像素
--- 如果N次采样都未超出，且DPR>1，则很可能设备返回的已经是逻辑像素
function DetectTouchCoordSystem(sx, sy)
    if touchCoordDPR then return end  -- 已检测完毕
    if screenW <= 0 or screenH <= 0 then return end  -- 渲染尚未初始化

    _touchDetectSamples = _touchDetectSamples + 1
    local g = GetGraphics()
    local dpr = g:GetDPR()

    -- 如果DPR≈1，无需检测，物理和逻辑像素相同
    if dpr < 1.05 then
        touchCoordDPR = 1.0
        print(string.format("[TouchDetect] DPR≈1 (%.2f), 无需坐标转换", dpr))
        return
    end

    -- 检查触摸坐标是否超出逻辑像素范围（加少量容差避免边缘误判）
    local margin = 2
    if sx > screenW + margin or sy > screenH + margin then
        _touchExceedsLogical = true
    end

    if _touchExceedsLogical then
        -- 有坐标超出逻辑范围 → 确认是物理像素
        touchCoordDPR = dpr
        print(string.format("[TouchDetect] 物理像素坐标确认 (DPR=%.2f, sample=%d, sx=%.0f>logW=%.0f)",
            dpr, _touchDetectSamples, sx, screenW))
        return
    end

    if _touchDetectSamples >= _touchDetectMax then
        -- 采样完毕，所有坐标都在逻辑像素范围内
        -- 再做一个额外验证：如果最大触摸坐标非常小（远小于物理像素范围），
        -- 那大概率是逻辑像素
        touchCoordDPR = 1.0
        print(string.format("[TouchDetect] 逻辑像素坐标推断 (DPR=%.2f, %d次采样均未超出logW=%.0f×logH=%.0f)",
            dpr, _touchDetectSamples, screenW, screenH))
    end
end


function ScreenToDesign(sx, sy)
    local dpr = GetTouchDPR()
    local lx, ly = sx / dpr, sy / dpr
    return (lx - offsetX) / scale, (ly - offsetY) / scale
end


function ScreenToLogical(sx, sy)
    local dpr = GetTouchDPR()
    return sx / dpr, sy / dpr
end


function DesignToLogical(dx, dy)
    return dx * scale + offsetX, dy * scale + offsetY
end


function LogicalToDesign(lx, ly)
    return (lx - offsetX) / scale, (ly - offsetY) / scale
end


-- Toast 提示系统
function ShowToast(text, dur)
    toastState.text = text
    toastState.timer = dur or 2.0
    toastState.duration = dur or 2.0
end


-- ============================================================================
function GetScreenJoystickPatchString()
    return "<patch><add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "<attribute name=\"Is Visible\" value=\"false\" /></add></patch>"
end
