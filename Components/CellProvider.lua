--------------------------------------------------------------------------------
---- Library Namespace
--------------------------------------------------------------------------------

local QTip = LibStub:GetLibrary("LibQTip-2.0")

---@class LibQTip-2.0.CellProvider
---@field CellHeap LibQTip-2.0.Cell[]
---@field CellMetatable table<"__index", LibQTip-2.0.Cell>
---@field CellPrototype LibQTip-2.0.Cell
---@field Cells table<LibQTip-2.0.Cell, true|nil>
local CellProvider = QTip.CellProviderPrototype

--------------------------------------------------------------------------------
---- Methods
--------------------------------------------------------------------------------

-- Acquire a new cell to be displayed in the tooltip. LibQTip manages parent, framelevel, anchors, visibility and size of the cell.
---@return LibQTip-2.0.Cell cell The acquired cell.
function CellProvider:AcquireCell()
    ---@type LibQTip-2.0.Cell|nil
    local cell = tremove(self.CellHeap)

    if not cell then
        cell = setmetatable(CreateFrame("Frame", nil, UIParent, "BackdropTemplate"), self.CellMetatable) --[[@as LibQTip-2.0.Cell]]

        Mixin(cell, ColorMixin)

        if type(cell.OnCreation) == "function" then
            cell:OnCreation()
        end
    end

    cell.CellProvider = self

    self.Cells[cell] = true

    return cell
end

-- Return the prototype and metatable used to create new cells.
---@return LibQTip-2.0.Cell cellPrototype The prototype on which cells are based.
---@return LibQTip-2.0.Cell cellMetatable The metatable used to create a new cell.
function CellProvider:GetCellPrototype()
    return self.CellPrototype, self.CellMetatable
end

-- Return an iterator on currently acquired cells.
---@return fun(tooltip: table<LibQTip-2.0.Cell, true|nil>, index?: LibQTip-2.0.Cell): LibQTip-2.0.Cell, true|nil
---@return table<LibQTip-2.0.Cell, true|nil>
function CellProvider:IterateCells()
    return pairs(self.Cells)
end

-- Release a cell that LibQTip is no longer using. The cell has already been hidden, unanchored and orphaned by LibQTip.
---@param cell LibQTip-2.0.Cell The cell to release.
function CellProvider:ReleaseCell(cell)
    if not self.Cells[cell] then
        return
    end

    if type(cell.OnRelease) == "function" then
        cell:OnRelease()
    end

    self.Cells[cell] = nil
    tinsert(self.CellHeap, cell)
end
