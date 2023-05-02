--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

local ScriptManager = QTip.ScriptManager

---@alias LibQTip-2.0.ReleaseHandler fun(frame: Frame, delay: number)

---@class LibQTip-2.0.TooltipManager: Frame
---@field ActiveReleases table<LibQTip-2.0.Tooltip, true|nil>
---@field ActiveTooltips table<string, LibQTip-2.0.Tooltip|nil>
---@field ColumnHeap LibQTip-2.0.Column[]
---@field ColumnMetatable table<"__index", LibQTip-2.0.Column>
---@field ColumnPrototype LibQTip-2.0.Column
---@field DefaultBackdrop backdropInfo
---@field PixelSize TooltipPixelSize
---@field LayoutRegistry table<LibQTip-2.0.Tooltip, true|nil>
---@field LineHeap LibQTip-2.0.Line[]
---@field LineMetatable table<"__index", LibQTip-2.0.Line>
---@field LinePrototype LibQTip-2.0.Line
---@field OnReleaseHandlers table<LibQTip-2.0.Tooltip, LibQTip-2.0.ReleaseHandler>
---@field TableHeap table[]
---@field TimerHeap LibQTip-2.0.Timer[]
---@field TooltipHeap LibQTip-2.0.Tooltip[]
---@field TooltipMetatable table<"__index", LibQTip-2.0.Tooltip>
---@field TooltipPrototype LibQTip-2.0.Tooltip
local TooltipManager = QTip.TooltipManager

TooltipManager.ActiveReleases = TooltipManager.ActiveReleases or {}
TooltipManager.ActiveTooltips = TooltipManager.ActiveTooltips or {}
TooltipManager.ColumnHeap = TooltipManager.ColumnHeap or {}
TooltipManager.ColumnPrototype = TooltipManager.ColumnPrototype or setmetatable({}, QTip.FrameMetatable)
TooltipManager.ColumnMetatable = TooltipManager.ColumnMetatable or { __index = TooltipManager.ColumnPrototype }
TooltipManager.LayoutRegistry = TooltipManager.LayoutRegistry or {}
TooltipManager.LineHeap = TooltipManager.LineHeap or {}
TooltipManager.LinePrototype = TooltipManager.LinePrototype or setmetatable({}, QTip.FrameMetatable)
TooltipManager.LineMetatable = TooltipManager.LineMetatable or { __index = TooltipManager.LinePrototype }
TooltipManager.OnReleaseHandlers = TooltipManager.OnReleaseHandlers or {}
TooltipManager.TableHeap = TooltipManager.TableHeap or {}
TooltipManager.TimerHeap = TooltipManager.TimerHeap or {}
TooltipManager.TooltipHeap = TooltipManager.TooltipHeap or {}
TooltipManager.TooltipPrototype = TooltipManager.TooltipPrototype or setmetatable({}, QTip.FrameMetatable)
TooltipManager.TooltipMetatable = TooltipManager.TooltipMetatable or { __index = TooltipManager.TooltipPrototype }

TooltipManager.DefaultBackdrop = TooltipManager.DefaultBackdrop
    or {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    }

---@class TooltipPixelSize
---@field CellPadding 10
---@field HorizontalCellMargin 6
---@field VerticalCellMargin 3
local PixelSize = {
    CellPadding = 10,
    HorizontalCellMargin = 6,
    VerticalCellMargin = 3,
}

TooltipManager.PixelSize = TooltipManager.PixelSize or PixelSize

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

-- Returns a cell for the given tooltip from the given provider
---@param tooltip LibQTip-2.0.Tooltip
---@param line LibQTip-2.0.Line Line index for the Cell.
---@param column LibQTip-2.0.Column Column index for the Cell.
---@param rightColumnIndex integer
---@param cellProvider LibQTip-2.0.CellProvider
---@return LibQTip-2.0.Cell
function TooltipManager:AcquireCell(tooltip, line, column, rightColumnIndex, cellProvider)
    local cell = cellProvider:AcquireCell()

    cell.ColumnIndex = column.Index
    cell.LineIndex = line.Index
    cell.Tooltip = tooltip

    cell:SetParent(tooltip.ScrollChild)
    cell:SetFrameLevel(tooltip.ScrollChild:GetFrameLevel() + 3)
    cell:SetPoint("LEFT", column)
    cell:SetPoint("RIGHT", tooltip.Columns[rightColumnIndex])
    cell:SetPoint("TOP", line)
    cell:SetPoint("BOTTOM", line)
    cell:SetJustifyH(column.HorizontalJustification)
    cell:Show()

    column.Cells[line.Index] = cell
    line.Cells[column.Index] = cell

    return cell
end

---@param tooltip LibQTip-2.0.Tooltip The tooltip for which the Column is being acquired
---@param columnIndex integer Column number to set.
---@param horizontalJustification JustifyH The horizontal justification of cells in this column ("CENTER", "LEFT" or "RIGHT"). Defaults to "LEFT".
---@return LibQTip-2.0.Column
function TooltipManager:AcquireColumn(tooltip, columnIndex, horizontalJustification)
    ---@type LibQTip-2.0.Column|nil
    local column = tremove(self.ColumnHeap)

    if not column then
        column = setmetatable(CreateFrame("Frame", nil, nil, "BackdropTemplate"), self.ColumnMetatable) --[[@as LibQTip-2.0.Column]]
    end

    local scrollChild = tooltip.ScrollChild

    column:SetParent(scrollChild)
    column:SetFrameLevel(scrollChild:GetFrameLevel() + 1)
    column:SetWidth(1)
    column:SetPoint("TOP", scrollChild)
    column:SetPoint("BOTTOM", scrollChild)

    if columnIndex > 1 then
        local horizontalMargin = tooltip.HorizontalCellMargin or TooltipManager.PixelSize.HorizontalCellMargin

        column:SetPoint("LEFT", tooltip.Columns[columnIndex - 1], "RIGHT", horizontalMargin, 0)
        TooltipManager:SetTooltipSize(tooltip, tooltip.Width + horizontalMargin, tooltip.Height)
    else
        column:SetPoint("LEFT", tooltip.ScrollChild)
    end

    column.Cells = column.Cells or {}
    column.HorizontalJustification = horizontalJustification
    column.Index = columnIndex
    column.Tooltip = tooltip
    column.Width = 0

    column:Show()

    return column
end

---@param tooltip LibQTip-2.0.Tooltip
---@param lineIndex integer
---@return LibQTip-2.0.Line
function TooltipManager:AcquireLine(tooltip, lineIndex)
    ---@type LibQTip-2.0.Line|nil
    local line = tremove(self.LineHeap)

    if not line then
        line = setmetatable(CreateFrame("Frame", nil, nil, "BackdropTemplate"), self.LineMetatable) --[[@as LibQTip-2.0.Line]]
    end

    line:SetParent(tooltip.ScrollChild)
    line:SetFrameLevel(tooltip.ScrollChild:GetFrameLevel() + 2)
    line:SetHeight(1)
    line:SetPoint("LEFT", tooltip.ScrollChild)
    line:SetPoint("RIGHT", tooltip.ScrollChild)

    if lineIndex > 1 then
        local verticalMargin = tooltip.VerticalCellMargin or TooltipManager.PixelSize.VerticalCellMargin

        line:SetPoint("TOP", tooltip.Lines[lineIndex - 1], "BOTTOM", 0, -verticalMargin)
        TooltipManager:SetTooltipSize(tooltip, tooltip.Width, tooltip.Height + verticalMargin)
    else
        line:SetPoint("TOP", tooltip.ScrollChild)
    end

    line:Show()

    line.Cells = line.Cells or {}
    line.Height = 0
    line.Index = lineIndex
    line.Tooltip = tooltip

    return line
end

---@param tooltip LibQTip-2.0.Tooltip
---@return LibQTip-2.0.Timer
function TooltipManager:AcquireTimer(tooltip)
    ---@type LibQTip-2.0.Timer
    local timer = tremove(self.TimerHeap) or CreateFrame("Frame")

    timer:SetParent(tooltip)

    return timer
end

-- Returns a tooltip
---@param key string
---@return LibQTip-2.0.Tooltip
function TooltipManager:AcquireTooltip(key)
    ---@type LibQTip-2.0.Tooltip|nil
    local tooltip = tremove(self.TooltipHeap)

    if not tooltip then
        local cellPadding = PixelSize.CellPadding

        tooltip = setmetatable(CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate"), self.TooltipMetatable) --[[@as LibQTip-2.0.Tooltip]]

        local scrollFrame = CreateFrame("ScrollFrame", nil, tooltip)
        scrollFrame:SetPoint("TOP", tooltip, "TOP", 0, -cellPadding)
        scrollFrame:SetPoint("BOTTOM", tooltip, "BOTTOM", 0, cellPadding)
        scrollFrame:SetPoint("LEFT", tooltip, "LEFT", cellPadding, 0)
        scrollFrame:SetPoint("RIGHT", tooltip, "RIGHT", -cellPadding, 0)
        tooltip.ScrollFrame = scrollFrame

        local scrollChild = CreateFrame("Frame", nil, tooltip.ScrollFrame)
        scrollFrame:SetScrollChild(scrollChild)
        tooltip.ScrollChild = scrollChild
    end

    tooltip.CellProvider = QTip.DefaultCellProvider
    tooltip.ColSpanWidths = tooltip.ColSpanWidths or {}
    tooltip.Columns = tooltip.Columns or {}
    tooltip.HeaderFont = GameTooltipHeaderText
    tooltip.HorizontalCellMargin = tooltip.HorizontalCellMargin or PixelSize.HorizontalCellMargin
    tooltip.Key = key
    tooltip.Lines = tooltip.Lines or {}
    tooltip.RegularFont = GameTooltipText
    tooltip.Scripts = tooltip.Scripts or {}
    tooltip.VerticalCellMargin = tooltip.VerticalCellMargin or PixelSize.VerticalCellMargin

    tooltip.layoutType = GameTooltip.layoutType

    NineSlicePanelMixin.OnLoad(tooltip.NineSlice)

    if GameTooltip.layoutType then
        tooltip.NineSlice:SetCenterColor(GameTooltip.NineSlice:GetCenterColor())
        tooltip.NineSlice:SetBorderColor(GameTooltip.NineSlice:GetBorderColor())
    end

    tooltip:SetAlpha(1)
    tooltip:SetClampedToScreen(false)
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetScale(GameTooltip:GetScale())
    tooltip:SetAutoHideDelay(nil)
    tooltip:Hide()

    self:AdjustTooltipSize(tooltip)

    return tooltip
end

---@param tooltip LibQTip-2.0.Tooltip
function TooltipManager:AdjustCellSizes(tooltip)
    local colSpanWidths = tooltip.ColSpanWidths
    local columns = tooltip.Columns
    local horizontalMargin = tooltip.HorizontalCellMargin or PixelSize.HorizontalCellMargin

    -- resize columns to make room for the colspans
    while next(colSpanWidths) do
        local maxNeedColumns
        local maxNeedWidthPerColumn = 0

        -- calculate the colspan with the highest additional width need per column
        for columnRange, width in pairs(colSpanWidths) do
            local left, right = columnRange:match("^(%d+)%-(%d+)$")

            left = tonumber(left)
            right = tonumber(right)

            for columnIndex = left, right - 1 do
                width = width - columns[columnIndex].Width - horizontalMargin
            end

            width = width - columns[right].Width

            if width <= 0 then
                colSpanWidths[columnRange] = nil
            else
                width = width / (right - left + 1)

                if width > maxNeedWidthPerColumn then
                    maxNeedColumns = columnRange
                    maxNeedWidthPerColumn = width
                end
            end
        end

        -- resize all columns for that colspan
        if maxNeedColumns then
            local leftIndex, rightIndex = maxNeedColumns:match("^(%d+)%-(%d+)$")

            for columnIndex = leftIndex, rightIndex do
                self:AdjustColumnWidth(
                    tooltip,
                    columns[columnIndex],
                    columns[columnIndex].Width + maxNeedWidthPerColumn
                )
            end

            colSpanWidths[maxNeedColumns] = nil
        end
    end

    local lines = tooltip.Lines

    -- Now that the cell width is set, recalculate the rows' height values.
    for _, line in ipairs(lines) do
        if #line.Cells > 0 then
            local lineHeight = 0

            for _, cell in ipairs(line.Cells) do
                if cell then
                    lineHeight = max(lineHeight, cell:GetContentHeight())
                end
            end

            if lineHeight > 0 then
                self:SetTooltipSize(tooltip, tooltip.Width, tooltip.Height + lineHeight - line.Height)

                line.Height = lineHeight
                line:SetHeight(lineHeight)
            end
        end
    end
end

---@param tooltip LibQTip-2.0.Tooltip
---@param column LibQTip-2.0.Column
---@param width number
function TooltipManager:AdjustColumnWidth(tooltip, column, width)
    if width > column.Width then
        self:SetTooltipSize(tooltip, tooltip.Width + width - column.Width, tooltip.Height)

        column.Width = width
        column:SetWidth(width)
    end
end

-- Add 2 pixels to height so dangling letters (g, y, p, j, etc) are not clipped.
---@param tooltip LibQTip-2.0.Tooltip
function TooltipManager:AdjustTooltipSize(tooltip)
    local horizontalMargin = tooltip.HorizontalCellMargin or PixelSize.HorizontalCellMargin

    TooltipManager:SetTooltipSize(
        tooltip,
        max(0, (horizontalMargin * (#tooltip.Columns - 1)) + (horizontalMargin / 2)),
        2
    )
end

function TooltipManager:CleanupLayouts()
    self:Hide()

    for tooltip in pairs(self.LayoutRegistry) do
        TooltipManager:AdjustCellSizes(tooltip)
    end

    wipe(self.LayoutRegistry)
end

---@param tooltip LibQTip-2.0.Tooltip
function TooltipManager:RegisterForCleanup(tooltip)
    self.LayoutRegistry[tooltip] = true
    self:Show()
end

-- Cleans the cell hands it to its provider for storing
---@param cell LibQTip-2.0.Cell
function TooltipManager:ReleaseCell(cell)
    cell:Hide()
    cell:SetParent(nil)
    cell:ClearAllPoints()
    cell:ClearBackdrop()

    ScriptManager:ClearFrameScripts(cell)

    cell.CellProvider:ReleaseCell(cell)
    cell.CellProvider = nil
end

---@param column LibQTip-2.0.Column
function TooltipManager:ReleaseColumn(column)
    column:Hide()
    column:SetParent(nil)
    column:ClearAllPoints()
    column:ClearBackdrop()

    wipe(column.Cells)

    column.HorizontalJustification = "LEFT"
    column.Index = 0
    column.Tooltip = nil
    column.Width = 0

    ScriptManager:ClearFrameScripts(column)

    tinsert(self.ColumnHeap, column)
end

---@param line LibQTip-2.0.Line
function TooltipManager:ReleaseLine(line)
    line:Hide()
    line:SetParent(nil)
    line:ClearAllPoints()
    line:ClearBackdrop()

    wipe(line.Cells)

    line.Height = 0
    line.Index = 0
    line.IsHeader = nil
    line.Tooltip = nil

    ScriptManager:ClearFrameScripts(line)

    tinsert(self.LineHeap, line)
end

---@param timerFrame LibQTip-2.0.Timer
function TooltipManager:ReleaseTimer(timerFrame)
    timerFrame.AlternateFrame = nil
    timerFrame:Hide()
    timerFrame:SetParent(nil)
    timerFrame:SetScript("OnUpdate", nil)

    ScriptManager:ClearFrameScripts(timerFrame)

    tinsert(self.TimerHeap, timerFrame)
end

-- Cleans the tooltip and stores it in the cache
---@param tooltip LibQTip-2.0.Tooltip
function TooltipManager:ReleaseTooltip(tooltip)
    if self.ActiveReleases[tooltip] then
        return
    end

    self.ActiveReleases[tooltip] = true
    self.ActiveTooltips[tooltip.Key] = nil

    tooltip:Hide()

    local releaseHandler = self.OnReleaseHandlers[tooltip]

    if releaseHandler then
        self.OnReleaseHandlers[tooltip] = nil

        local success, errorMessage = pcall(releaseHandler, tooltip)

        if not success then
            geterrorhandler()(errorMessage)
        end
    elseif tooltip.OnRelease then
        local success, errorMessage = pcall(tooltip.OnRelease, tooltip)
        if not success then
            geterrorhandler()(errorMessage)
        end

        tooltip.OnRelease = nil
    end

    self.ActiveReleases[tooltip] = nil

    tooltip.Key = nil
    tooltip.ScrollStep = nil

    tooltip:SetAutoHideDelay(nil)
    tooltip:ClearAllPoints()
    tooltip:Clear()

    if tooltip.Slider then
        tooltip.Slider:SetValue(0)
        tooltip.Slider:Hide()
        tooltip.ScrollFrame:SetPoint("RIGHT", tooltip, "RIGHT", -PixelSize.CellPadding, 0)
        tooltip:EnableMouseWheel(false)
    end

    for i, column in ipairs(tooltip.Columns) do
        tooltip.Columns[i] = self:ReleaseColumn(column)
    end

    wipe(tooltip.ColSpanWidths)
    wipe(tooltip.Columns)
    wipe(tooltip.Lines)

    for scriptType in pairs(tooltip.Scripts) do
        ScriptManager:RawSetScript(tooltip, scriptType, nil)
    end

    wipe(tooltip.Scripts)

    self.LayoutRegistry[tooltip] = nil

    tinsert(self.TooltipHeap, tooltip)

    ScriptManager.HighlightTexture:SetTexture(ScriptManager.DefaultHighlightTexturePath)
    ScriptManager.HighlightTexture:SetTexCoord(0, 1, 0, 1)
end

---@param tooltip LibQTip-2.0.Tooltip
---@param width number
---@param height number
function TooltipManager:SetTooltipSize(tooltip, width, height)
    tooltip.Height = height
    tooltip.Width = width

    tooltip:SetSize(2 * PixelSize.CellPadding + width, 2 * PixelSize.CellPadding + height)

    tooltip.ScrollChild:SetSize(width, height)
end

--------------------------------------------------------------------------------
---- Layout Handling
--------------------------------------------------------------------------------

TooltipManager:SetScript("OnUpdate", TooltipManager.CleanupLayouts)
