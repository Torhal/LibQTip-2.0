--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local Version = {
    Major = "LibQTip-2.0",
    Minor = 1,
}

assert(LibStub, ("%s requires LibStub"):format(Version.Major))

---@class LibQTip-2.0
---@field CellPrototype LibQTip-2.0.Cell The prototype all Cells are derived from.
---@field CellMetatable table<"__index", LibQTip-2.0.Cell> The base metatable for all Cells.
---@field DefaultCellPrototype LibQTip-2.0.Cell The library default Cell interface.
---@field DefaultCellProvider LibQTip-2.0.CellProvider The library default CellProvider interface.
---@field CellProviderMetatable table<"__index", LibQTip-2.0.CellProvider> The base metatable for all CellProviders.
---@field CellProviderPrototype LibQTip-2.0.CellProvider The prototype all CellProviders are derived from.
---@field FrameMetatable table<"__index", Frame> Used for default Frame methods.
---@field CallbackHandlers LibQTip-2.0.HandlerRegistry
---@field RegisterCallback fun(target: table, eventName: LibQTip-2.0.EventName, handler: string|fun(eventName: LibQTip-2.0.EventName, ...: unknown))
---@field ScriptManager LibQTip-2.0.ScriptManager Manages all library Script interactions.
---@field TooltipManager LibQTip-2.0.TooltipManager Manages all library Tooltip interactions.
---@field UnregisterCallback fun(target: table, eventName: LibQTip-2.0.EventName)
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

QTip.CallbackHandlers = QTip.CallbackHandlers or LibStub:GetLibrary("CallbackHandler-1.0"):New(QTip)

--------------------------------------------------------------------------------
---- Internal Functions
--------------------------------------------------------------------------------

---@param templateCellProvider? LibQTip-2.0.CellProvider An existing provider used as a template for the new provider.
---@return LibQTip-2.0.Cell
---@return table<"__index", LibQTip-2.0.Cell>
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

local TooltipManager = QTip.TooltipManager

-- Create or retrieve the Tooltip with the given key.
--
-- If additional arguments are passed, they are passed to :SetColumnLayout for the acquired Tooltip.
---@param key string The Tooltip key. A key unique to this Tooltip should be provided to avoid conflicts.
---@param numColumns? number Minimum number of Columns
---@param ... JustifyH Column horizontal justifications ("CENTER", "LEFT" or "RIGHT"). Defaults to "LEFT".
-- ***
-- Example Tooltip with 5 Columns justified as left, center, left, left, left:
-- ``` lua
-- local tooltip = LibStub('LibQTip-2.0'):Acquire('MyFooBarTooltip', 5, "LEFT", "CENTER")
-- ```
-- ***
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

-- Check if a Tooltip has been acquired with the specified key.
---@param key string The tooltip key.
---@return boolean
function QTip:IsAcquired(key)
    if key == nil then
        error("attempt to use a nil key", 2)
    end

    return not not TooltipManager.ActiveTooltips[key]
end

-- Return an acquired Tooltip to the heap. The Tooltip is cleared and hidden.
---@param tooltip LibQTip-2.0.Tooltip The Tooltip to release. Any invalid values are silently ignored.
function QTip:Release(tooltip)
    local key = tooltip and tooltip.Key

    if not key or TooltipManager.ActiveTooltips[key] ~= tooltip then
        return
    end

    TooltipManager:ReleaseTooltip(tooltip)
end

-- Return an iterator on the acquired Tooltips.
function QTip:TooltipPairs()
    return pairs(TooltipManager.ActiveTooltips)
end

------------------------------------------------------------------------------
-- Default CellProvider and Cell
------------------------------------------------------------------------------

if not QTip.DefaultCellProvider then
    QTip.DefaultCellProvider, QTip.DefaultCellPrototype = QTip:CreateCellProvider()
end

--------------------------------------------------------------------------------
---- Types
--------------------------------------------------------------------------------

---@class LibQTip-2.0.HandlerRegistry: CallbackHandlerRegistry
---@field Fire fun(self: LibQTip-2.0.HandlerRegistry, eventName: LibQTip-2.0.EventName, ...: unknown)

---@alias LibQTip-2.0.EventName
---|"OnReleaseTooltip"
