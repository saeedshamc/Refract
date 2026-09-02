--[[
  level.lua — Level loading, parsing, and state management for Prism Echo.

  Levels are Lua files in levels/ that return a table with:
    name, cols, rows, emitters, receivers, entities, inventory (optional)
]]

local Grid = require("grid")
local Entities = require("entities")

local Level = {}
Level.__index = Level

--- Direction name → index map for level data parsing.
local DIR_MAP = { up = 1, right = 2, down = 3, left = 4 }

--- Deep-copy an entity for level reset snapshots.
local function copyEntity(entity)
  local copy = Entities.create(entity.type, {
    rotation = entity.rotation,
    rotatable = entity.rotatable,
    fixed = entity.fixed,
    x = entity.x,
    y = entity.y,
    autoRotate = entity.autoRotate,
    rotateInterval = entity.rotateInterval,
    requiredColor = entity.requiredColor,
    emitColor = entity.emitColor,
    emitDir = entity.emitDir,
  })
  if copy.rotateTimer ~= nil then
    copy.rotateTimer = 0
  end
  return copy
end

--- Load a level file by index (1-based).
function Level.load(index)
  local path = "levels/level" .. index .. ".lua"
  local chunk, err = love.filesystem.load(path)
  if not chunk then
    error("Failed to load level: " .. tostring(err))
  end
  local data = chunk()
  return Level.fromData(data, index)
end

--- Build a Level instance from a data table.
function Level.fromData(data, index)
  local self = setmetatable({}, Level)
  self.index = index or 1
  self.name = data.name or ("Level " .. self.index)
  self.cols = data.cols or 12
  self.rows = data.rows or 9
  self.grid = Grid.new(self.cols, self.rows)
  self.emitters = {}
  self.receivers = {}
  self.inventory = data.inventory or {}
  self.placedInventory = {} -- tracks placed items from inventory

  -- Parse emitters (not on grid cells, but positioned at grid coords)
  for _, em in ipairs(data.emitters or {}) do
    local emitter = Entities.create("emitter", {
      x = em.x, y = em.y,
      emitDir = DIR_MAP[em.direction or "right"] or em.direction or 2,
      emitColor = em.color or "white",
      fixed = true,
    })
    table.insert(self.emitters, emitter)
  end

  -- Parse receivers (placed on grid)
  for _, rc in ipairs(data.receivers or {}) do
    local receiver = Entities.create("receiver", {
      x = rc.x, y = rc.y,
      requiredColor = rc.color or "white",
      fixed = true,
    })
    self.grid:setEntity(rc.x, rc.y, receiver)
    table.insert(self.receivers, receiver)
  end

  -- Parse pre-placed entities
  for _, ent in ipairs(data.entities or {}) do
    local entity = Entities.create(ent.type, {
      x = ent.x, y = ent.y,
      rotation = ent.rotation or 0,
      rotatable = ent.rotatable,
      fixed = ent.fixed,
      rotateInterval = ent.rotateInterval,
      autoRotate = ent.autoRotate,
    })
    self.grid:setEntity(ent.x, ent.y, entity)
  end

  -- Snapshot for restart
  self:saveSnapshot()

  return self
end

--- Save initial state for restart (R key).
function Level:saveSnapshot()
  self.snapshot = {
    entities = {},
    inventory = {},
  }
  for y = 1, self.grid.rows do
    for x = 1, self.grid.cols do
      local e = self.grid:getEntity(x, y)
      if e and e.type ~= "receiver" then
        table.insert(self.snapshot.entities, copyEntity(e))
      end
    end
  end
  for k, v in pairs(self.inventory) do
    self.snapshot.inventory[k] = v
  end
  self.placedInventory = {}
end

--- Reset level to initial snapshot state.
function Level:reset()
  -- Clear non-receiver entities
  for y = 1, self.grid.rows do
    for x = 1, self.grid.cols do
      local e = self.grid:getEntity(x, y)
      if e and e.type ~= "receiver" then
        self.grid:removeEntity(x, y)
      end
    end
  end

  -- Restore entities from snapshot
  for _, e in ipairs(self.snapshot.entities) do
    local copy = copyEntity(e)
    self.grid:setEntity(copy.x, copy.y, copy)
  end

  -- Reset receivers
  for _, r in ipairs(self.receivers) do
    r.satisfied = false
  end

  -- Restore inventory
  self.inventory = {}
  for k, v in pairs(self.snapshot.inventory) do
    self.inventory[k] = v
  end
  self.placedInventory = {}
end

--- Get total number of available levels.
function Level.count()
  local n = 0
  while love.filesystem.getInfo("levels/level" .. (n + 1) .. ".lua") do
    n = n + 1
  end
  return n
end

--- Try placing an entity from inventory at grid position.
function Level:placeFromInventory(entityType, gx, gy)
  if not self.inventory[entityType] or self.inventory[entityType] <= 0 then
    return false
  end
  if self.grid:getEntity(gx, gy) then return false end

  local entity = Entities.create(entityType, { x = gx, y = gy })
  if self.grid:setEntity(gx, gy, entity) then
    self.inventory[entityType] = self.inventory[entityType] - 1
    if not self.placedInventory[entityType] then
      self.placedInventory[entityType] = 0
    end
    self.placedInventory[entityType] = self.placedInventory[entityType] + 1
    return true
  end
  return false
end

--- Return an inventory item when removed from grid.
function Level:returnToInventory(entityType)
  if self.placedInventory[entityType] and self.placedInventory[entityType] > 0 then
    self.placedInventory[entityType] = self.placedInventory[entityType] - 1
    self.inventory[entityType] = (self.inventory[entityType] or 0) + 1
  end
end

return Level
