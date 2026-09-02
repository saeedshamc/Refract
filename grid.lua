--[[
  grid.lua — Grid data structure for Prism Echo.

  Manages grid dimensions, cell size, coordinate conversion between
  screen space and grid space, and per-cell entity storage.
]]

local Grid = {}
Grid.__index = Grid

--- Create a new grid with the given column/row counts.
-- @param cols number  Column count (default 12)
-- @param rows number  Row count (default 9)
-- @return Grid
function Grid.new(cols, rows)
  local self = setmetatable({}, Grid)
  self.cols = cols or 12
  self.rows = rows or 9
  self.cellSize = 48
  self.offsetX = 0
  self.offsetY = 0
  self.cells = {}
  for y = 1, self.rows do
    self.cells[y] = {}
    for x = 1, self.cols do
      self.cells[y][x] = nil
    end
  end
  return self
end

--- Recalculate cell size and offsets so the grid fits inside the window.
-- Preserves square cells and centers the grid horizontally; leaves room for HUD.
-- @param windowW number  Window width in pixels
-- @param windowH number  Window height in pixels
-- @param hudHeight number  Reserved pixels at the bottom for inventory/HUD
function Grid:resize(windowW, windowH, hudHeight)
  hudHeight = hudHeight or 80
  local availableH = windowH - hudHeight
  local sizeByW = math.floor(windowW / self.cols)
  local sizeByH = math.floor(availableH / self.rows)
  self.cellSize = math.min(sizeByW, sizeByH)
  local gridW = self.cellSize * self.cols
  local gridH = self.cellSize * self.rows
  self.offsetX = math.floor((windowW - gridW) / 2)
  self.offsetY = math.floor((availableH - gridH) / 2)
end

--- Convert screen coordinates to grid cell (1-based). Returns nil if out of bounds.
function Grid:screenToGrid(sx, sy)
  local gx = math.floor((sx - self.offsetX) / self.cellSize) + 1
  local gy = math.floor((sy - self.offsetY) / self.cellSize) + 1
  if gx >= 1 and gx <= self.cols and gy >= 1 and gy <= self.rows then
    return gx, gy
  end
  return nil, nil
end

--- Convert grid cell center to screen coordinates.
function Grid:gridToScreen(gx, gy)
  local sx = self.offsetX + (gx - 0.5) * self.cellSize
  local sy = self.offsetY + (gy - 0.5) * self.cellSize
  return sx, sy
end

--- Get the screen rectangle for a cell (top-left corner + size).
function Grid:getCellRect(gx, gy)
  return self.offsetX + (gx - 1) * self.cellSize,
         self.offsetY + (gy - 1) * self.cellSize,
         self.cellSize,
         self.cellSize
end

--- Check whether grid coordinates are inside the grid.
function Grid:inBounds(gx, gy)
  return gx >= 1 and gx <= self.cols and gy >= 1 and gy <= self.rows
end

--- Place an entity at (gx, gy). Returns false if occupied or out of bounds.
function Grid:setEntity(gx, gy, entity)
  if not self:inBounds(gx, gy) then return false end
  if self.cells[gy][gx] ~= nil then return false end
  self.cells[gy][gx] = entity
  entity.x = gx
  entity.y = gy
  return true
end

--- Remove and return the entity at (gx, gy).
function Grid:removeEntity(gx, gy)
  if not self:inBounds(gx, gy) then return nil end
  local e = self.cells[gy][gx]
  self.cells[gy][gx] = nil
  return e
end

--- Get entity at (gx, gy), or nil.
function Grid:getEntity(gx, gy)
  if not self:inBounds(gx, gy) then return nil end
  return self.cells[gy][gx]
end

--- Clear all entities from the grid.
function Grid:clear()
  for y = 1, self.rows do
    for x = 1, self.cols do
      self.cells[y][x] = nil
    end
  end
end

--- Draw faint grid overlay lines.
function Grid:drawGridLines()
  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.setLineWidth(1)
  for x = 0, self.cols do
    local px = self.offsetX + x * self.cellSize
    love.graphics.line(px, self.offsetY, px, self.offsetY + self.rows * self.cellSize)
  end
  for y = 0, self.rows do
    local py = self.offsetY + y * self.cellSize
    love.graphics.line(self.offsetX, py, self.offsetX + self.cols * self.cellSize, py)
  end
end

return Grid
