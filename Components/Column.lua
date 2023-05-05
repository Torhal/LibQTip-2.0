--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

local ScriptManager = QTip.ScriptManager
local TooltipManager = QTip.TooltipManager

---@class LibQTip-2.0.Column: LibQTip-2.0.ScriptFrame
---@field Cells LibQTip-2.0.Cell[] Cells indexed by Line.
---@field HorizontalJustification JustifyH
---@field Index integer The Column's index on its Tooltip
---@field Tooltip LibQTip-2.0.Tooltip
---@field Width number
local Column = TooltipManager.ColumnPrototype

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

---@param lineIndex integer Line index of the Cell.
---@param cellProvider? LibQTip-2.0.CellProvider CellProvider to use instead of the default one. Defaults to LibQTip.DefaultCellProvider.
---@return LibQTip-2.0.Cell
function Column:GetCell(lineIndex, cellProvider)
    return self.Tooltip:GetLine(lineIndex):GetCell(self.Index, cellProvider)
end

-- Sets the background color for the Column.
---@param r? number Red color value of the Column. Defaults to the Tooltip's current red value.
---@param g? number Green color value of the Column. Defaults to the Tooltip's current green value.
---@param b? number Blue color value of the Column. Defaults to the Tooltip's current blue value.
---@param a? number Alpha level of the Column. Defaults to 1.
---@return LibQTip-2.0.Column column
function Column:SetColor(r, g, b, a)
    local red, green, blue, alpha

    if r and g and b and a then
        red, green, blue, alpha = r, g, b, a
    else
        red, green, blue, alpha = self.Tooltip:GetBackdropColor()
    end

    self:SetBackdrop(TooltipManager.DefaultBackdrop)
    self:SetBackdropColor(red, green, blue, alpha)

    return self
end

---@param scriptType LibQTip-2.0.ScriptType The ScriptType to assign to the Column.
---@param handler fun(frame: Frame, ...) The function called when the script is run. Parameters conform to the given ScriptType.
---@param arg? unknown Data to be passed to the script function.
---@return LibQTip-2.0.Column column
function Column:SetScript(scriptType, handler, arg)
    ScriptManager:SetScript(self, scriptType, handler, arg)

    return self
end

-- Sets the text color for every Cell in the Column.
---@param r? number Red color value of the Cell's text. Defaults to the red value of the Cell's FontString.
---@param g? number Green color value of the Cell's text. Defaults to the green value of the Cell's FontString.
---@param b? number Blue color value of the Cell's text. Defaults to the blue value of the Cell's FontString.
---@param a? number Alpha level of the Cell's text. Defaults to 1.
---@return LibQTip-2.0.Column column
function Column:SetTextColor(r, g, b, a)
    for lineIndex = 1, #self.Tooltip.Lines do
        self:GetCell(lineIndex):SetTextColor(r, g, b, a)
    end

    return self
end
