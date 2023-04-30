local Version = {
    Major = "LibQTip-2.0",
    Minor = 1,
}

assert(LibStub, ("%s requires LibStub"):format(Version.Major))

--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

---@class LibQTip-2.0
---@field CellPrototype LibQTip-2.0.Cell
---@field CellMetatable table<"__index", LibQTip-2.0.Cell>
---@field DefaultCellPrototype LibQTip-2.0.Cell
---@field DefaultCellProvider LibQTip-2.0.CellProvider
---@field CellProviderMetatable table<"__index", LibQTip-2.0.CellProvider>
---@field CellProviderPrototype LibQTip-2.0.CellProvider
---@field FrameMetatable table<"__index", Frame>
---@field ScriptManager LibQTip-2.0.ScriptManager
---@field TooltipManager LibQTip-2.0.TooltipManager
local QTip, oldMinor = LibStub:NewLibrary(Version.Major, Version.Minor)

if not QTip then
    return
end -- No upgrade needed

QTip.Version = Version
QTip.Version.OldMinor = oldMinor or 0

QTip.FrameMetatable = QTip.FrameMetatable or { __index = CreateFrame("Frame") }

QTip.CellProviderPrototype = QTip.CellProviderPrototype or {}
QTip.CellProviderMetatable = QTip.CellProviderMetatable or { __index = QTip.CellProviderPrototype }

QTip.CellPrototype = QTip.CellPrototype or setmetatable({}, QTip.FrameMetatable)
QTip.CellMetatable = QTip.CellMetatable or { __index = QTip.CellPrototype }

QTip.ScriptManager = QTip.ScriptManager or {}
QTip.TooltipManager = QTip.TooltipManager or CreateFrame("Frame")

local TooltipManager = QTip.TooltipManager

--------------------------------------------------------------------------------
---- Internal Functions
--------------------------------------------------------------------------------

---@param templateCellProvider? LibQTip-2.0.CellProvider An existing provider used as a template for the new provider.
local function GetCellPrototype(templateCellProvider)
    if templateCellProvider and templateCellProvider.GetCellPrototype then
        return templateCellProvider:GetCellPrototype()
    else
        return QTip.CellPrototype, QTip.CellMetatable
    end
end

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

-- Create or retrieve the tooltip with the given key.
--
-- If additional arguments are passed, they are passed to :SetColumnLayout for the acquired tooltip.
---@param key string The tooltip key. Any value that can be used as a table key is accepted though you should try to provide unique keys to avoid conflicts.<br>Numbers and booleans should be avoided and strings should be carefully chosen to avoid namespace clashes - no "MyTooltip" - you have been warned!
---@param numColumns? number Minimum number of columns
---@param ... JustifyH Column horizontal justifications ("CENTER", "LEFT" or "RIGHT"). Defaults to "LEFT".
-- Example tooltip with 5 columns justified as left, center, left, left, left:
--
-- local tooltip = LibStub('LibQTip-2.0'):Acquire('MyFooBarTooltip', 5, "LEFT", "CENTER")
---@return LibQTip-2.0.Tooltip
function QTip:Acquire(key, numColumns, ...)
    if key == nil then
        error("attempt to use a nil key", 2)
    end

    local tooltip = TooltipManager.ActiveTooltips[key]

    if not tooltip then
        tooltip = TooltipManager:AcquireTooltip(key)
        TooltipManager.ActiveTooltips[key] = tooltip
    end

    -- Here we catch any error to properly report it for the calling code
    local isOk, message = pcall(tooltip.SetColumnLayout, tooltip, numColumns, ...)

    if not isOk then
        error(message, 2)
    end

    return tooltip
end

-- Convenience method to create a new cell provider.
--
-- Although one can use anything that matches the CellProvider and Cell interfaces, this method provides an easy way to create new providers.
---@param templateCellProvider? LibQTip-2.0.CellProvider An existing provider used as a template for the new provider.
---@return LibQTip-2.0.CellProvider newCellProvider The new CellProvider.
---@return LibQTip-2.0.Cell newCellPrototype The prototype of the new cell. It must be extended with the mandatory :Initialize() and :Setup() methods.
---@return LibQTip-2.0.Cell baseCellPrototype The prototype of baseProvider cells. It may be used to call base cell methods.
function QTip:CreateCellProvider(templateCellProvider)
    local baseCellPrototype, baseCellMetatable = GetCellPrototype(templateCellProvider)

    ---@type LibQTip-2.0.Cell
    local newCellPrototype = setmetatable({}, baseCellMetatable)

    ---@type LibQTip-2.0.CellProvider
    local newCellProvider = setmetatable({}, self.CellProviderMetatable)

    newCellProvider.CellHeap = {}
    newCellProvider.Cells = {}
    newCellProvider.CellPrototype = newCellPrototype
    newCellProvider.CellMetatable = { __index = newCellPrototype }

    return newCellProvider, newCellPrototype, baseCellPrototype
end

-- Check if a given tooltip has been acquired.
---@param key string - The tooltip key.
---@return boolean
function QTip:IsAcquired(key)
    if key == nil then
        error("attempt to use a nil key", 2)
    end

    return not not TooltipManager.ActiveTooltips[key]
end

-- Return an iterator on the acquired tooltips.
function QTip:IterateTooltips()
    return pairs(TooltipManager.ActiveTooltips)
end

-- Return an acquired tooltip to the heap. The tooltip is cleared and hidden.
---@param tooltip LibQTip-2.0.Tooltip The tooltip to release. Any invalid values are silently ignored.
function QTip:Release(tooltip)
    local key = tooltip and tooltip.Key

    if not key or TooltipManager.ActiveTooltips[key] ~= tooltip then
        return
    end

    TooltipManager:ReleaseTooltip(tooltip)
end

------------------------------------------------------------------------------
-- Default CellProvider and Cell
------------------------------------------------------------------------------

if not QTip.DefaultCellProvider then
    QTip.DefaultCellProvider, QTip.DefaultCellPrototype = QTip:CreateCellProvider()
end
