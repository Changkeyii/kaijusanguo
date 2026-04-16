-- admin/admin_mail_keyboard.lua - 管理员邮件键盘输入（仅管理员构建时加载）
-- 此文件包含：写信弹窗的文本输入和按键处理

local M = {}

--- 处理写信弹窗的文本输入
--- 返回 true 表示已消费
---@param ch string 输入字符
---@return boolean
function M.HandleTextInput(ch)
    if gameState.phase ~= "MAIL_BOX" then return false end
    if not welfareState.mail.composing or not welfareState.mail.composeData then return false end

    local cd = welfareState.mail.composeData
    if cd.inputFocus == "uid" then
        if ch:match("^[0-9]$") then
            if #cd.targetUid < 15 then cd.targetUid = cd.targetUid .. ch end
        end
    elseif cd.inputFocus == "subject" then
        local subLen = utf8.len(cd.subject) or 0
        if subLen < 20 then cd.subject = cd.subject .. ch end
    elseif cd.inputFocus == "body" then
        local bodyLen = utf8.len(cd.body) or 0
        if bodyLen < 100 then cd.body = cd.body .. ch end
    elseif cd.inputFocus == "jade" then
        if ch:match("^[0-9]$") then
            local s = cd.jadeInputText or "0"
            if #s < 8 then cd.jadeInputText = s .. ch end
            cd.rewardJade = tonumber(cd.jadeInputText) or 0
        end
    end
    return true
end

--- 处理写信弹窗的按键事件
--- 返回 true 表示已消费
---@param key number 按键码
---@return boolean
function M.HandleKeyDown(key)
    if gameState.phase ~= "MAIL_BOX" then return false end
    if not welfareState.mail.composing or not welfareState.mail.composeData then return false end

    local cd = welfareState.mail.composeData
    if key == KEY_BACKSPACE then
        local field = cd.inputFocus
        if field == "uid" then
            if #cd.targetUid > 0 then cd.targetUid = cd.targetUid:sub(1, -2) end
        elseif field == "subject" then
            local s = cd.subject
            if #s > 0 then
                local bytes = { string.byte(s, 1, #s) }
                local i = #bytes
                while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do i = i - 1 end
                if i > 0 then i = i - 1 end
                cd.subject = string.sub(s, 1, i)
            end
        elseif field == "body" then
            local s = cd.body
            if #s > 0 then
                local bytes = { string.byte(s, 1, #s) }
                local i = #bytes
                while i > 0 and bytes[i] >= 0x80 and bytes[i] < 0xC0 do i = i - 1 end
                if i > 0 then i = i - 1 end
                cd.body = string.sub(s, 1, i)
            end
        elseif field == "jade" then
            local s = cd.jadeInputText or "0"
            if #s > 1 then cd.jadeInputText = s:sub(1, -2)
            else cd.jadeInputText = "0" end
            cd.rewardJade = tonumber(cd.jadeInputText) or 0
        end
    elseif key == KEY_TAB then
        if cd.isManage then
            cd.inputFocus = "uid"
        else
            if cd.inputFocus == "uid" then cd.inputFocus = "subject"
            elseif cd.inputFocus == "subject" then cd.inputFocus = "body"
            elseif cd.inputFocus == "body" then cd.inputFocus = cd.isAdmin and "jade" or "uid"
            else cd.inputFocus = "uid" end
        end
    elseif key == KEY_ESCAPE then
        welfareState.mail.composing = false
        welfareState.mail.composeData = nil
        input:SetScreenKeyboardVisible(false)
    end
    return true
end

return M
