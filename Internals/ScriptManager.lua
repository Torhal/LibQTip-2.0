--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

---@class LibQTip-2.0.ScriptManager
local ScriptManager = QTip.ScriptManager

---@alias LibQTip-2.0.ScriptType
---|"OnEnter"
---|"OnLeave"
---|"OnMouseDown"
---|"OnMouseUp"
---|"OnReceiveDrag"

---@class LibQTip-2.0.ScriptFrame: BackdropTemplate, Frame
---@field _OnEnter_arg? unknown
---@field _OnEnter_func? fun(arg, ...)
---@field _OnLeave_arg? unknown
---@field _OnLeave_func? fun(arg, ...)
---@field _OnMouseDown_arg? unknown
---@field _OnMouseDown_func? fun(arg, ...)
---@field _OnMouseUp_arg? unknown
---@field _OnMouseUp_func? fun(arg, ...)
---@field _OnReceiveDrag_arg? unknown
---@field _OnReceiveDrag_func? fun(arg, ...)

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

local DefaultHighlightTexturePath = [[Interface\QuestFrame\UI-QuestTitleHighlight]]

local HighlightFrame = CreateFrame("Frame", nil, UIParent)
HighlightFrame:SetFrameStrata("TOOLTIP")
HighlightFrame:Hide()

local HighlightTexture = HighlightFrame:CreateTexture(nil, "OVERLAY")
HighlightTexture:SetTexture(DefaultHighlightTexturePath)
HighlightTexture:SetBlendMode("ADD")
HighlightTexture:SetAllPoints(HighlightFrame)

ScriptManager.HighlightTexture = HighlightTexture
ScriptManager.DefaultHighlightTexturePath = DefaultHighlightTexturePath

---@type table<LibQTip-2.0.ScriptType, fun(frame: LibQTip-2.0.ScriptFrame, ...)>
local FrameScriptHandler = {
    OnEnter = function(frame, ...)
        HighlightFrame:SetParent(frame)
        HighlightFrame:SetAllPoints(frame)
        HighlightFrame:Show()

        if frame._OnEnter_func then
            frame:_OnEnter_func(frame._OnEnter_arg, ...)
        end
    end,
    OnLeave = function(frame, ...)
        HighlightFrame:Hide()
        HighlightFrame:ClearAllPoints()
        HighlightFrame:SetParent(nil)

        if frame._OnLeave_func then
            frame:_OnLeave_func(frame._OnLeave_arg, ...)
        end
    end,
    OnMouseDown = function(frame, ...)
        frame:_OnMouseDown_func(frame._OnMouseDown_arg, ...)
    end,
    OnMouseUp = function(frame, ...)
        frame:_OnMouseUp_func(frame._OnMouseUp_arg, ...)
    end,
    OnReceiveDrag = function(frame, ...)
        frame:_OnReceiveDrag_func(frame._OnReceiveDrag_arg, ...)
    end,
}

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

---@param frame LibQTip-2.0.ScriptFrame
function ScriptManager:ClearFrameScripts(frame)
    if
        frame._OnEnter_func
        or frame._OnLeave_func
        or frame._OnMouseDown_func
        or frame._OnMouseUp_func
        or frame._OnReceiveDrag_func
    then
        frame:EnableMouse(false)

        self:RawSetScript(frame, "OnEnter", nil)
        frame._OnEnter_func = nil
        frame._OnEnter_arg = nil

        self:RawSetScript(frame, "OnLeave", nil)
        frame._OnLeave_func = nil
        frame._OnLeave_arg = nil

        self:RawSetScript(frame, "OnReceiveDrag", nil)
        frame._OnReceiveDrag_func = nil
        frame._OnReceiveDrag_arg = nil

        self:RawSetScript(frame, "OnMouseDown", nil)
        frame._OnMouseDown_func = nil
        frame._OnMouseDown_arg = nil

        self:RawSetScript(frame, "OnMouseUp", nil)
        frame._OnMouseUp_func = nil
        frame._OnMouseUp_arg = nil
    end
end

---@param frame LibQTip-2.0.ScriptFrame
---@param scriptType ScriptFrame
---@param handler? function
function ScriptManager:RawSetScript(frame, scriptType, handler)
    QTip.FrameMetatable.__index.SetScript(frame, scriptType, handler)
end

---@param frame LibQTip-2.0.ScriptFrame
---@param scriptType LibQTip-2.0.ScriptType
---@param handler? fun(arg, ...)
---@param arg? string Data to be passed to the script function.
function ScriptManager:SetScript(frame, scriptType, handler, arg)
    if not FrameScriptHandler[scriptType] then
        return
    end

    frame["_" .. scriptType .. "_func"] = handler
    frame["_" .. scriptType .. "_arg"] = arg

    if scriptType == "OnMouseDown" or scriptType == "OnMouseUp" or scriptType == "OnReceiveDrag" then
        if handler then
            self:RawSetScript(frame, scriptType, FrameScriptHandler[scriptType])
        else
            self:RawSetScript(frame, scriptType, nil)
        end
    end

    if
        frame._OnEnter_func
        or frame._OnLeave_func
        or frame._OnMouseDown_func
        or frame._OnMouseUp_func
        or frame._OnReceiveDrag_func
    then
        frame:EnableMouse(true)
        self:RawSetScript(frame, "OnEnter", FrameScriptHandler.OnEnter)
        self:RawSetScript(frame, "OnLeave", FrameScriptHandler.OnLeave)
    else
        frame:EnableMouse(false)
        self:RawSetScript(frame, "OnEnter", nil)
        self:RawSetScript(frame, "OnLeave", nil)
    end
end
