--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

local ScriptManager = QTip.ScriptManager
local TooltipManager = QTip.TooltipManager

---@class LibQTip-2.0.Line: LibQTip-2.0.ScriptFrame
---@field Cells (LibQTip-2.0.Cell|nil)[] Cells indexed by Column.
---@field ColSpanCells (true|nil)[] A value of true means the Column index is part of a ColSpan.
---@field Height number Height, in pixels.
---@field Index integer The Line's index on its Tooltip
---@field IsHeader? true Determines whether the Tooltip's normal or header Font should be used for Cells in this Line.
---@field Tooltip LibQTip-2.0.Tooltip
local Line = TooltipManager.LinePrototype

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

---@param columnIndex integer Column index of the Cell.
---@param cellProvider? LibQTip-2.0.CellProvider The CellProvider to use. Defaults to the Cell's Tooltip's default CellProvider.
---@return LibQTip-2.0.Cell
---@nodiscard
function Line:GetCell(columnIndex, cellProvider)
    local tooltip = self.Tooltip
    local lineCells = self.Cells
    local colSpanCells = self.ColSpanCells

    local cell ---@type LibQTip-2.0.Cell|nil

    if colSpanCells[columnIndex] then
        error(("Overlapping Cells at column %d"):format(columnIndex), 3)
    end

    -- Check for the existence of a previous Cell on the Column.
    local existingCell = lineCells[columnIndex]

    if existingCell then
        -- If no CellProvider was supplied, or the supplied CellProvider matches that of the existing Cell, use that Cell.
        -- Otherwise, the existing Cell needs to be released to make way for the new one.
        if cellProvider == nil or existingCell.CellProvider == cellProvider then
            cell = existingCell
            cellProvider = existingCell.CellProvider
        else
            lineCells[columnIndex] = nil

            TooltipManager:ReleaseCell(existingCell)
        end
    else
        cellProvider = cellProvider or tooltip.CellProvider
    end

    if not cell then
        cell = TooltipManager:AcquireCell(self.Tooltip, self, tooltip:GetColumn(columnIndex), cellProvider)
    end

    return cell
end

-- Sets the background color for the Line.
---@param r? number Red color value of the Line. Defaults to the Tooltip's current red value.
---@param g? number Green color value of the Line. Defaults to the Tooltip's current green value.
---@param b? number Blue color value of the Line. Defaults to the Tooltip's current blue value.
---@param a? number Alpha level of the Line. Defaults to 1.
---@return LibQTip-2.0.Line
function Line:SetColor(r, g, b, a)
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

-- Assigns a script to the Line.
---@param scriptType LibQTip-2.0.ScriptType The column ScriptType.
---@param handler fun(frame: Frame, ...) The function called when the script is run. Parameters conform to the given ScriptType.
---@param arg? string Data to be passed to the script handler.
---@return LibQTip-2.0.Line
function Line:SetScript(scriptType, handler, arg)
    ScriptManager:SetScript(self, scriptType, handler, arg)

    return self
end

-- Sets the text color for every Cell in the Line.
---@param r? number Red color value of the Line's text. Defaults to the red value of the Tooltip's default Font.
---@param g? number Green color value of the Line's text. Defaults to the green value of the Tooltip's default Font.
---@param b? number Blue color value of the Line's text. Defaults to the blue value of the Tooltip's default Font.
---@param a? number Alpha level of the Line's text. Defaults to 1.
---@return LibQTip-2.0.Line
function Line:SetTextColor(r, g, b, a)
    if not r then
        r, g, b, a = self.Tooltip:GetDefaultFont():GetTextColor()
    end

    for cellIndex = 1, #self.Cells do
        self.Cells[cellIndex]:SetTextColor(r, g, b, a)
    end

    return self
end
