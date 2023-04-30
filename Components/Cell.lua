--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

local ScriptManager = QTip.ScriptManager
local TooltipManager = QTip.TooltipManager

---@class LibQTip-2.0.Cell: LibQTip-2.0.ScriptFrame, ColorMixin
---@field CellProvider LibQTip-2.0.CellProvider
---@field ColSpan integer The number of columns the cell will span. Defaults to 1.
---@field ColumnIndex integer
---@field FontString FontString
---@field HorizontalJustification JustifyH Cell-specific justification to use ("CENTER", "LEFT" or "RIGHT"). Defaults to the justification of the Column where the Cell resides.
---@field LineIndex integer
---@field LeftPadding integer Pixel padding on the left side of the Cell's value. Defaults to 0.
---@field MaxWidth? integer The maximum width (in pixels) of the Cell. If the Cell's value is textual and exceeds this width, it will wrap to a new line. Must not be less than the value of MinWidth.
---@field MinWidth? integer The minimum width (in pixels) of the Cell. Must not exceed the value of MaxWidth.
---@field RightPadding integer Pixel padding on the right side of the Cell's value. Defaults to 0.
---@field Tooltip LibQTip-2.0.Tooltip
local Cell = QTip.DefaultCellPrototype

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

---@return number height
function Cell:GetContentHeight()
    local fontString = self.FontString
    fontString:SetWidth(self:GetWidth() - (self.LeftPadding + self.RightPadding))

    local height = self.FontString:GetHeight()
    fontString:SetWidth(0)

    return height
end

-- Returns the cell's position within the containing tooltip.
---@return number lineIndex The line index of cell.
---@return number columnIndex The column index of cell.
function Cell:GetPosition()
    return self.LineIndex, self.ColumnIndex
end

-- Returns the size of the Cell.
---@return number width The width of the Cell.
---@return number height The height of the Cell.
function Cell:GetSize()
    if not self.FontString then
        error("The Cell's CellProvider did not assign a FontString field", 2)
    end

    local fontString = self.FontString

    -- Detatch the FontString from the Cell to calculate size
    fontString:ClearAllPoints()

    local leftPadding = self.LeftPadding
    local rightPadding = self.RightPadding

    ---@type number
    local width = fontString:GetStringWidth() + leftPadding + rightPadding
    local minWidth = self.MinWidth
    local maxWidth = self.MaxWidth

    if minWidth and width < minWidth then
        width = minWidth
    end

    if maxWidth and maxWidth < width then
        width = maxWidth
    end

    fontString:SetWidth(width - (leftPadding + rightPadding))

    -- Use GetHeight() instead of GetStringHeight() so lines which are longer than width will wrap.
    local height = fontString:GetHeight()

    fontString:SetWidth(0)
    fontString:SetPoint("TOPLEFT", self, "TOPLEFT", leftPadding, 0)
    fontString:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -rightPadding, 0)

    return width, height
end

-- This method is called on newly created Cells for initialization.
function Cell:OnCreation()
    self.ColSpan = 1
    self.LeftPadding = 0
    self.RightPadding = 0
    self.FontString = self:CreateFontString()
    self.FontString:SetFontObject(GameTooltipText)
    self:SetJustifyH("LEFT")
end

function Cell:OnRelease()
    self:SetJustifyH("LEFT")
    self.FontString:SetFontObject(GameTooltipText)

    -- TODO: See if this can be changed to use something else, negating the need to store RGBA on the Cell itself.
    if self.r then
        self.FontString:SetTextColor(self.r, self.g, self.b, self.a)
    end

    self.ColSpan = 1
    self.ColumnIndex = 0
    self.HorizontalJustification = "LEFT"
    self.LineIndex = 0
    self.LeftPadding = 0
    self.MaxWidth = nil
    self.MinWidth = nil
    self.RightPadding = 0
    self.Tooltip = nil
end

-- Sets the background color for the Cell.
---@param r? number Red color value of the Cell. Defaults to the Tooltip's current red value.
---@param g? number Green color value of the Cell. Defaults to the Tooltip's current green value.
---@param b? number Blue color value of the Cell. Defaults to the Tooltip's current blue value.
---@param a? number Alpha level of the Cell. Defaults to 1.
---@return LibQTip-2.0.Cell cell
function Cell:SetColor(r, g, b, a)
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

---@param font? FontObject|Font The rendering font. Defaults to regular or header font, depending on the cell's designation.
---@return LibQTip-2.0.Cell cell
function Cell:SetFont(font)
    if not self.FontString then
        error("The Cell's CellProvider did not assign a FontString field", 2)
    end

    self.FontString:SetFontObject(
        type(font) == "string" and _G[font]
            or font
            or (
                self.Tooltip:GetLine(self.LineIndex).IsHeader and self.Tooltip:GetHeaderFont() or self.Tooltip:GetFont()
            )
    )

    return self
end

---@param horizontalJustification JustifyH Cell-specific justification to use.
---@return LibQTip-2.0.Cell cell
function Cell:SetJustifyH(horizontalJustification)
    self.HorizontalJustification = horizontalJustification
    self.FontString:SetJustifyH(horizontalJustification)

    return self
end

---@param pixels integer
---@return LibQTip-2.0.Cell cell
function Cell:SetLeftPadding(pixels)
    self.LeftPadding = pixels

    return self
end

---@param maxWidth? integer
---@return LibQTip-2.0.Cell cell
function Cell:SetMaxWidth(maxWidth)
    local minWidth = self.MinWidth

    if maxWidth and minWidth and (maxWidth < minWidth) then
        error(("maxWidth (%d) cannot be less than the Cell's MinWidth (%d)"):format(maxWidth, minWidth), 2)
    end

    if maxWidth and (maxWidth < (self.LeftPadding + self.RightPadding)) then
        error(
            ("maxWidth (%d) cannot be less than the sum of the Cell's LeftPadding (%d) and RightPadding (%d)"):format(
                maxWidth,
                self.LeftPadding,
                self.RightPadding
            ),
            2
        )
    end

    self.MaxWidth = maxWidth

    return self
end

---@param minWidth? integer
---@return LibQTip-2.0.Cell cell
function Cell:SetMinWidth(minWidth)
    local maxWidth = self.MaxWidth

    if maxWidth and minWidth and (minWidth > maxWidth) then
        error(("minWidth (%d) cannot be greater than the Cell's MaxWidth (%d)"):format(minWidth, maxWidth), 2)
    end

    self.MinWidth = minWidth

    return self
end

---@param pixels integer
---@return LibQTip-2.0.Cell cell
function Cell:SetRightPadding(pixels)
    self.RightPadding = pixels

    return self
end

---@param scriptType LibQTip-2.0.ScriptType The ScriptType to assign to the Cell.
---@param handler fun(frame: Frame, ...) The function called when the script is run. Parameters conform to the given ScriptType.
---@param arg? unknown Data to be passed to the script function.
---@return LibQTip-2.0.Cell cell
function Cell:SetScript(scriptType, handler, arg)
    ScriptManager:SetScript(self, scriptType, handler, arg)

    return self
end

---@param text string The text to display in the cell.
---@return LibQTip-2.0.Cell cell
function Cell:SetText(text)
    if not self.FontString then
        error("The Cell's CellProvider did not assign a FontString field", 2)
    end

    self.FontString:SetText(tostring(text))

    local tooltip = self.Tooltip
    local line = tooltip:GetLine(self.LineIndex)
    local columnIndex = self.ColumnIndex
    local column = tooltip:GetColumn(columnIndex)
    local width, height = self:GetSize()
    local colSpan = self.ColSpan

    if colSpan > 1 then
        local columnRange = ("%d-%d"):format(columnIndex, columnIndex + colSpan - 1)

        tooltip.ColSpanWidths[columnRange] = max(tooltip.ColSpanWidths[columnRange] or 0, width)
        TooltipManager:RegisterForCleanup(tooltip)
    else
        TooltipManager:AdjustColumnWidth(self.Tooltip, column, width)
    end

    if height > line.Height then
        TooltipManager:SetTooltipSize(self.Tooltip, self.Tooltip.Width, self.Tooltip.Height + height - line.Height)

        line.Height = height
        line:SetHeight(height)
    end

    return self
end

-- Sets the text color for the Cell.
---@param r? number Red color value of the Cell's text. Defaults to the red value of the Cell's FontString.
---@param g? number Green color value of the Cell's text. Defaults to the green value of the Cell's FontString.
---@param b? number Blue color value of the Cell's text. Defaults to the blue value of the Cell's FontString.
---@param a? number Alpha level of the Cell's text. Defaults to 1.
---@return LibQTip-2.0.Cell cell
function Cell:SetTextColor(r, g, b, a)
    if not self.FontString then
        error("The Cell's CellProvider did not assign a FontString field", 2)
    end

    if not self.r then
        self:SetRGBA(self.FontString:GetTextColor())
    end

    if not r then
        r, g, b, a = self:GetRGBA()
    end

    self.FontString:SetTextColor(r, g, b, a)

    return self
end
