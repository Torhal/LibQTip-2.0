--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

local ScriptManager = QTip.ScriptManager
local TooltipManager = QTip.TooltipManager

---@class LibQTip-2.0.Tooltip: LibQTip-2.0.ScriptFrame
---@field AutoHideTimerFrame? LibQTip-2.0.Timer
---@field HorizontalCellMargin number
---@field VerticalCellMargin number
---@field CellProvider LibQTip-2.0.CellProvider
---@field ColSpanWidths table<string, number|nil>
---@field Columns (LibQTip-2.0.Column|nil)[]
---@field HeaderFont Font
---@field Height number
---@field Key string
---@field Lines (LibQTip-2.0.Line|nil)[]
---@field RegularFont Font
---@field Scripts? table<LibQTip-2.0.ScriptType, true|nil>
---@field ScrollChild Frame
---@field ScrollFrame ScrollFrame
---@field ScrollStep number
---@field Slider LibQTip-2.0.Slider
---@field Width number
local Tooltip = TooltipManager.TooltipPrototype

---@class LibQTip-2.0.Slider: BackdropTemplate, Slider
---@field ScrollFrame ScrollFrame

---@class LibQTip-2.0.Timer: LibQTip-2.0.ScriptFrame
---@field AlternateFrame? Frame
---@field CheckElapsed number
---@field Delay number
---@field Elapsed number
---@field Tooltip LibQTip-2.0.Tooltip

--------------------------------------------------------------------------------
---- Constants
--------------------------------------------------------------------------------

---@type backdropInfo
local SliderBackdrop = BACKDROP_SLIDER_8_8
    or {
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
        tile = true,
        tileEdge = true,
        tileSize = 8,
    }

--------------------------------------------------------------------------------
---- Validators
--------------------------------------------------------------------------------

local function ValidateFont(font, level, silent)
    local bad = false

    if not font then
        bad = true
    elseif type(font) == "string" then
        local ref = _G[font]

        if not ref or type(ref) ~= "table" or type(ref.IsObjectType) ~= "function" or not ref:IsObjectType("Font") then
            bad = true
        end
    elseif type(font) ~= "table" or type(font.IsObjectType) ~= "function" or not font:IsObjectType("Font") then
        bad = true
    end

    if bad then
        if silent then
            return false
        end

        error(
            "font must be a Font instance or a string matching the name of a global Font instance, not: "
                .. tostring(font),
            level + 1
        )
    end
    return true
end

---@param justification JustifyH
---@param level integer
---@param silent? boolean
local function ValidateJustification(justification, level, silent)
    if justification ~= "LEFT" and justification ~= "CENTER" and justification ~= "RIGHT" then
        if silent then
            return false
        end

        error("invalid justification, must one of LEFT, CENTER or RIGHT, not: " .. tostring(justification), level + 1)
    end

    return true
end

---@param tooltip LibQTip-2.0.Tooltip
---@param lineIndex integer
---@param level integer
---@return boolean isValid
local function ValidateLineIndex(tooltip, lineIndex, level)
    local callerLevel = level + 1
    local lineIndexType = type(lineIndex)

    if lineIndexType ~= "number" then
        error(("The lineIndex must be a number, not '%s'"):format(lineIndexType), callerLevel)
    end

    return true
end

--------------------------------------------------------------------------------
---- Internal Functions
--------------------------------------------------------------------------------

---@param frame Frame The frame that will serve as the tooltip anchor.
local function GetTooltipAnchor(frame)
    local x, y = frame:GetCenter()

    if not x or not y then
        return "TOPLEFT", "BOTTOMLEFT"
    end

    local horizontalHalf = (x > UIParent:GetWidth() * 2 / 3) and "RIGHT"
        or (x < UIParent:GetWidth() / 3) and "LEFT"
        or ""

    local verticalHalf = (y > UIParent:GetHeight() / 2) and "TOP" or "BOTTOM"

    return verticalHalf .. horizontalHalf, frame, (verticalHalf == "TOP" and "BOTTOM" or "TOP") .. horizontalHalf
end

--------------------------------------------------------------------------------
---- Scripts
--------------------------------------------------------------------------------

-- Script of the auto-hiding child frame
---@param timer LibQTip-2.0.Timer
---@param elapsed number
local function AutoHideTimerFrame_OnUpdate(timer, elapsed)
    timer.CheckElapsed = timer.CheckElapsed + elapsed

    if timer.CheckElapsed > 0.1 then
        if timer.Tooltip:IsMouseOver() or (timer.AlternateFrame and timer.AlternateFrame:IsMouseOver()) then
            timer.Elapsed = 0
        else
            timer.Elapsed = timer.Elapsed + timer.CheckElapsed

            if timer.Elapsed >= timer.Delay then
                QTip:Release(timer.Tooltip)
            end
        end

        timer.CheckElapsed = 0
    end
end

---@param slider LibQTip-2.0.Slider
local function Slider_OnValueChanged(slider)
    slider.ScrollFrame:SetVerticalScroll(slider:GetValue())
end

---@param self LibQTip-2.0.Tooltip
---@param delta number
local function Tooltip_OnMouseWheel(self, delta)
    local slider = self.Slider
    local currentValue = slider:GetValue()
    local minValue, maxValue = slider:GetMinMaxValues()
    local stepValue = self.ScrollStep or 10

    if delta < 0 and currentValue < maxValue then
        slider:SetValue(min(maxValue, currentValue + stepValue))
    elseif delta > 0 and currentValue > minValue then
        slider:SetValue(max(minValue, currentValue - stepValue))
    end
end

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

-- Add a new column to the right of the tooltip.
---@param horizontalJustification? JustifyH The horizontal justification of cells in this column ("CENTER", "LEFT" or "RIGHT"). Defaults to "LEFT".
function Tooltip:AddColumn(horizontalJustification)
    horizontalJustification = horizontalJustification or "LEFT"
    ValidateJustification(horizontalJustification, 2)

    local columnIndex = #self.Columns + 1
    local column = self.Columns[columnIndex] or TooltipManager:AcquireColumn(self, columnIndex, horizontalJustification)

    self.Columns[columnIndex] = column

    return column
end

-- Add a new header line at the bottom of the tooltip.
--
-- Provided values are displayed on the line with the header font. Nil values are ignored. If the number of values is greater than the number of columns, an error is raised.
---@param ... string Value to be displayed in each column of the line.
---@return LibQTip-2.0.Line line
function Tooltip:AddHeader(...)
    local line = self:AddLine(...)

    line.IsHeader = true

    return line
end

-- Add a new line at the bottom of the tooltip.
-- Provided values are displayed on the line with the regular font. Nil values are ignored. If the number of values is greater than the number of columns, an error is raised.
---@param ... string Value to be displayed in each column of the line.
---@return LibQTip-2.0.Line line
function Tooltip:AddLine(...)
    if #self.Columns == 0 then
        error("Column layout should be defined before adding a Line", 3)
    end

    local lineIndex = #self.Lines + 1
    local line = self.Lines[lineIndex] or TooltipManager:AcquireLine(self, lineIndex)

    self.Lines[lineIndex] = line

    for columnIndex = 1, #self.Columns do
        local value = select(columnIndex, ...)

        if value ~= nil then
            line:GetCell(columnIndex):SetText(value)
        end
    end

    return line
end

-- Adds a graphical separator line at the bottom of the tooltip.
---@param height? number Height, in pixels, of the separator. Defaults to 1.
---@param r? number Red color value of the separator. Defaults to NORMAL_FONT_COLOR.r
---@param g? number Green color value of the separator. Defaults to NORMAL_FONT_COLOR.g
---@param b? number Blue color value of the separator. Defaults to NORMAL_FONT_COLOR.b
---@param a? number Alpha level of the separator. Defaults to 1.
---@return LibQTip-2.0.Line line
function Tooltip:AddSeparator(height, r, g, b, a)
    local line = self:AddLine()
    local color = NORMAL_FONT_COLOR

    height = height or 1

    TooltipManager:SetTooltipSize(self, self.Width, self.Height + height)

    line.Height = height
    line:SetHeight(height)
    line:SetBackdrop(TooltipManager.DefaultBackdrop)
    line:SetBackdropColor(r or color.r, g or color.g, b or color.b, a or 1)

    return line
end

-- Reset the contents of the tootip. The column layout is preserved but all lines are wiped.
---@return LibQTip-2.0.Tooltip
function Tooltip:Clear()
    for lineIndex, line in ipairs(self.Lines) do
        for _, cell in pairs(line.Cells) do
            if cell then
                TooltipManager:ReleaseCell(cell)
            end
        end

        TooltipManager:ReleaseLine(line)

        self.Lines[lineIndex] = nil
    end

    for _, column in ipairs(self.Columns) do
        column.Width = 0
        column:SetWidth(1)
    end

    wipe(self.ColSpanWidths)

    self.HorizontalCellMargin = nil
    self.VerticalCellMargin = nil

    TooltipManager:AdjustTooltipSize(self)

    return self
end

---@param columnIndex integer
---@return LibQTip-2.0.Column
function Tooltip:GetColumn(columnIndex)
    ValidateLineIndex(self, columnIndex, 2)

    local column = self.Columns[columnIndex]

    if not column then
        error(("There is no column at index %d"):format(columnIndex), 2)
    end

    return column
end

-- Returns the total number of columns of the tooltip.
---@return number columnCount The number of columns added using :SetColumnLayout or :AddColumn.
function Tooltip:GetColumnCount()
    return #self.Columns
end

-- Return the CellProvider used for cell functionality.
---@return LibQTip-2.0.CellProvider
function Tooltip:GetDefaultCellProvider()
    return self.CellProvider
end

-- Return the font used for regular lines.
function Tooltip:GetFont()
    return self.RegularFont
end

-- Return the font used for header lines.
---@return Font
function Tooltip:GetHeaderFont()
    return self.HeaderFont
end

---@param lineIndex integer
---@return LibQTip-2.0.Line
function Tooltip:GetLine(lineIndex)
    ValidateLineIndex(self, lineIndex, 2)

    local line = self.Lines[lineIndex]

    if not line then
        error(("There is no line at index %d"):format(lineIndex), 2)
    end

    return line
end

-- Returns the total number of lines of the tooltip.
---@return number lineCount The number of lines added using :AddLine or :AddHeader.
function Tooltip:GetLineCount()
    return #self.Lines
end

-- Disallow the use of the HookScript method to avoid one AddOn breaking all others.
function Tooltip:HookScript()
    geterrorhandler()(":HookScript is not allowed on LibQTip tooltips")
end

-- Determine whether or not the tooltip has been acquired by the specified key.
---@param key string The key to check.
---@return boolean
function Tooltip:IsAcquiredBy(key)
    return key ~= nil and self.Key == key
end

-- Release the tooltip
function Tooltip:Release()
    QTip:Release(self)
end

-- Sets the length of time in which the mouse pointer can be outside of the tooltip, or an alternate frame, before the tooltip is automatically hidden and then released.
---@param delay? number Whole or fractional seconds.
---@param alternateFrame? Frame If specified, the tooltip will not be automatically hidden while the mouse pointer is over it.
---@param releaseHandler? LibQTip-2.0.ReleaseHandler Called when the tooltip is released. Generally used to clean up a reference an AddOn has to the tooltip frame, since another AddOn can subsequently acquire it.
-- Usage:
--
-- :SetAutoHideDelay(0.25) => hides after 0.25sec outside of the tooltip
--
-- :SetAutoHideDelay(0.25, someFrame) => hides after 0.25sec outside of both the tooltip and someFrame
--
-- :SetAutoHideDelay() => disable auto-hiding (default)
---@return LibQTip-2.0.Tooltip
function Tooltip:SetAutoHideDelay(delay, alternateFrame, releaseHandler)
    local timerFrame = self.AutoHideTimerFrame
    delay = tonumber(delay) or 0

    if releaseHandler then
        if type(releaseHandler) ~= "function" then
            error("releaseHandler must be a function", 2)
        end

        TooltipManager.OnReleaseHandlers[self] = releaseHandler
    end

    if delay > 0 then
        if not timerFrame then
            timerFrame = TooltipManager:AcquireTimer(self)
            timerFrame:SetScript("OnUpdate", AutoHideTimerFrame_OnUpdate)

            self.AutoHideTimerFrame = timerFrame
        end

        timerFrame.AlternateFrame = alternateFrame
        timerFrame.CheckElapsed = 0
        timerFrame.Delay = delay
        timerFrame.Elapsed = 0
        timerFrame.Tooltip = self

        timerFrame:Show()
    elseif timerFrame then
        self.AutoHideTimerFrame = nil

        TooltipManager:ReleaseTimer(timerFrame)
    end

    return self
end

-- Ensure the tooltip has at least the passed number of columns, adding new columns if need be.
--
-- The justification of existing columns is reset to the passed values.
---@param columnCount number Minimum number of columns
---@param ...? JustifyH Column horizontal justifications ("CENTER", "LEFT" or "RIGHT"). Defaults to "LEFT".
-- Example tooltip with 5 columns justified as left, center, left, left, left:
--
-- tooltip:SetColumnLayout(5, "LEFT", "CENTER")
---@return LibQTip-2.0.Tooltip
function Tooltip:SetColumnLayout(columnCount, ...)
    if type(columnCount) ~= "number" or columnCount < 1 then
        error(("totalColumns must be a positive number, not '%s'"):format(tostring(columnCount)), 2)
    end

    for columnIndex = 1, columnCount do
        ---@type JustifyH
        local horizontalJustification = select(columnIndex, ...) or "LEFT"

        ValidateJustification(horizontalJustification, 2)

        if self.Columns[columnIndex] then
            self.Columns[columnIndex].HorizontalJustification = horizontalJustification
        else
            self:AddColumn(horizontalJustification)
        end
    end

    return self
end

-- Define the CellProvider to be used for all cell functionality.
---@param cellProvider LibQTip-2.0.CellProvider The new default CellProvider.
---@return LibQTip-2.0.Tooltip
function Tooltip:SetDefaultCellProvider(cellProvider)
    if cellProvider then
        self.CellProvider = cellProvider
    end

    return self
end

-- Define the font used when adding new lines.
---@param font FontObject|Font The new default font.
---@return LibQTip-2.0.Tooltip
function Tooltip:SetDefaultFont(font)
    ValidateFont(font, 2)

    self.RegularFont = type(font) == "string" and _G[font] or font --[[@as Font]]

    return self
end

-- Define the font used when adding new header lines.
---@param font FontObject|Font The new default font.
---@return LibQTip-2.0.Tooltip
function Tooltip:SetDefaultHeaderFont(font)
    ValidateFont(font, 2)

    self.HeaderFont = type(font) == "string" and _G[font] or font --[[@as Font]]

    return self
end

-- Works identically to the default UI's texture:SetTexCoord() API, for the tooltip's highlight texture.
---@param ... number Arguments to pass to texture:SetTexCoord()
---@overload fun(ULx: number, ULy: number, LLx: number, LLy: number, URx: number, URy: number, LRx: number, LRy: number)
---@overload fun(minX: number, maxX: number, minY: number, maxY: number)
---@return LibQTip-2.0.Tooltip
function Tooltip:SetHighlightTexCoord(...)
    ScriptManager.HighlightTexture:SetTexCoord(...)

    return self
end

-- Sets the texture of the highlight when mousing over a line or cell that has a script assigned to it.
--
-- Works identically to the default UI's texture:SetTexture() API.
---@param ... string Arguments to pass to texture:SetTexture()
---@overload fun(file: string|number, horizWrap?: HorizWrap, vertWrap?: string, filterMode?: FilterMode)
---@return LibQTip-2.0.Tooltip
function Tooltip:SetHighlightTexture(...)
    ScriptManager.HighlightTexture:SetTexture(...)

    return self
end

-- Sets the horizontal margin size of all cells within the tooltip. This function can only be used before the tooltip has had lines set.
---@param size integer The desired margin size. Must be a positive number or zero.
---@return LibQTip-2.0.Tooltip
function Tooltip:SetHorizontalCellMargin(size)
    if #self.Lines > 0 then
        -- TODO: Allow this by adjusting the cells using the new margin size
        error("Unable to set horizontal margin while the tooltip has lines.", 2)
    end

    if not size or type(size) ~= "number" or size < 0 then
        error("Margin size must be a positive number or zero.", 2)
    end

    self.HorizontalCellMargin = size

    return self
end

---@param scriptType LibQTip-2.0.ScriptType|"OnMouseWheel"
---@param handler? fun(arg, ...)
---@return LibQTip-2.0.Tooltip
function Tooltip:SetScript(scriptType, handler)
    ScriptManager:RawSetScript(self, scriptType, handler)

    self.Scripts[scriptType] = handler and true or nil

    return self
end

-- Set the step size for the scroll bar
---@param step number The new step size.
---@return LibQTip-2.0.Tooltip
function Tooltip:SetScrollStep(step)
    self.ScrollStep = step

    return self
end

-- Sets the vertical margin size of all cells within the tooltip. This function can only be used before the tooltip has had lines set.
---@param size integer The desired margin size. Must be a positive number or zero.
---@return LibQTip-2.0.Tooltip
function Tooltip:SetVerticalCellMargin(size)
    if #self.Lines > 0 then
        -- TODO: Allow this by adjusting the cells using the new margin size
        error("Unable to set vertical margin while the tooltip has lines.", 2)
    end

    if not size or type(size) ~= "number" or size < 0 then
        error("Margin size must be a positive number or zero.", 2)
    end

    self.VerticalCellMargin = size

    return self
end

-- Smartly anchor the tooltip to the given frame and ensure that it is always on screen.
---@param frame Frame The frame that will serve as the tooltip anchor.
---@return LibQTip-2.0.Tooltip
function Tooltip:SmartAnchorTo(frame)
    if not frame then
        error("Invalid frame provided.", 2)
    end

    self:ClearAllPoints()
    self:SetClampedToScreen(true)
    self:SetPoint(GetTooltipAnchor(frame))

    return self
end

-- Resizes the tooltip to fit the screen and show a scrollbar if needed.
---@param maxHeight? number Maximum tooltip height in pixels.
---@return LibQTip-2.0.Tooltip
function Tooltip:UpdateScrolling(maxHeight)
    self:SetClampedToScreen(false)

    -- All data is in the tooltip; fix colspan width and prevent the TooltipManager from messing up the tooltip later
    TooltipManager:AdjustCellSizes(self)
    TooltipManager.LayoutRegistry[self] = nil

    local scale = self:GetScale()
    local topSide = self:GetTop()
    local bottomSide = self:GetBottom()
    local screenSize = UIParent:GetHeight() / scale
    local tooltipSize = (topSide - bottomSide)

    -- if the tooltip would be too high, limit its height and show the slider
    if bottomSide < 0 or topSide > screenSize or (maxHeight and tooltipSize > maxHeight) then
        local shrink = (bottomSide < 0 and (5 - bottomSide) or 0)
            + (topSide > screenSize and (topSide - screenSize + 5) or 0)

        if maxHeight and tooltipSize - shrink > maxHeight then
            shrink = tooltipSize - maxHeight
        end

        self:SetHeight(2 * TooltipManager.PixelSize.CellPadding + self.Height - shrink)
        self:SetWidth(2 * TooltipManager.PixelSize.CellPadding + self.Width + 20)

        self.ScrollFrame:SetPoint("RIGHT", self, "RIGHT", -(TooltipManager.PixelSize.CellPadding + 20), 0)

        if not self.Slider then
            local slider = CreateFrame("Slider", nil, self, "BackdropTemplate") --[[@as LibQTip-2.0.Slider]]
            slider.ScrollFrame = self.ScrollFrame

            slider:SetOrientation("VERTICAL")
            slider:SetPoint(
                "TOPRIGHT",
                self,
                "TOPRIGHT",
                -TooltipManager.PixelSize.CellPadding,
                -TooltipManager.PixelSize.CellPadding
            )
            slider:SetPoint(
                "BOTTOMRIGHT",
                self,
                "BOTTOMRIGHT",
                -TooltipManager.PixelSize.CellPadding,
                TooltipManager.PixelSize.CellPadding
            )
            slider:SetBackdrop(SliderBackdrop)
            slider:SetThumbTexture([[Interface\Buttons\UI-SliderBar-Button-Vertical]])
            slider:SetMinMaxValues(0, 1)
            slider:SetValueStep(1)
            slider:SetWidth(12)
            slider:SetScript("OnValueChanged", Slider_OnValueChanged)
            slider:SetValue(0)

            self.Slider = slider
        end

        self.Slider:SetMinMaxValues(0, shrink)
        self.Slider:Show()

        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", Tooltip_OnMouseWheel)
    else
        self:SetHeight(2 * TooltipManager.PixelSize.CellPadding + self.Height)
        self:SetWidth(2 * TooltipManager.PixelSize.CellPadding + self.Width)

        self.ScrollFrame:SetPoint("RIGHT", self, "RIGHT", -TooltipManager.PixelSize.CellPadding, 0)

        if self.Slider then
            self.Slider:SetValue(0)
            self.Slider:Hide()

            self:EnableMouseWheel(false)
            self:SetScript("OnMouseWheel", nil)
        end
    end

    return self
end
