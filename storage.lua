--[[
  storage.lua — Persist procedurally generated levels to LÖVE save directory.

  Saved files live in the user's save folder (love.filesystem.getSaveDirectory):
    generated/index.lua   — list of { id, name, seed, difficulty, completed, date }
    generated/level_N.lua — full level data table
]]

local Storage = {}

local INDEX_PATH = "generated/index.lua"
local LEVEL_DIR = "generated"

--- Ensure save directory exists.
function Storage.init()
  if not love.filesystem.getInfo(LEVEL_DIR) then
    love.filesystem.createDirectory(LEVEL_DIR)
  end
end

--- Load the index of saved generated levels.
function Storage.loadIndex()
  Storage.init()
  if not love.filesystem.getInfo(INDEX_PATH) then
    return { levels = {} }
  end
  local chunk = love.filesystem.load(INDEX_PATH)
  if not chunk then return { levels = {} } end
  local ok, data = pcall(chunk)
  if ok and data and data.levels then return data end
  return { levels = {} }
end

--- Write index back to disk.
local function saveIndex(index)
  local lines = { "return { levels = {" }
  for _, entry in ipairs(index.levels) do
    table.insert(lines, string.format(
      "  { id = %q, name = %q, seed = %d, difficulty = %d, completed = %s, date = %q },",
      entry.id, entry.name, entry.seed, entry.difficulty,
      tostring(entry.completed), entry.date or ""
    ))
  end
  table.insert(lines, "} }")
  love.filesystem.write(INDEX_PATH, table.concat(lines, "\n"))
end

--- Serialize a level data table to a Lua file string.
local function serializeLevel(data)
  local function esc(s) return string.format("%q", s) end
  local parts = { "return {" }
  table.insert(parts, "  name = " .. esc(data.name) .. ",")
  table.insert(parts, "  cols = " .. data.cols .. ",")
  table.insert(parts, "  rows = " .. data.rows .. ",")
  if data.seed then
    table.insert(parts, "  seed = " .. data.seed .. ",")
  end

  table.insert(parts, "  emitters = {")
  for _, e in ipairs(data.emitters or {}) do
    table.insert(parts, string.format(
      "    { x = %d, y = %d, direction = %s, color = %s },",
      e.x, e.y, esc(e.direction or "right"), esc(e.color or "white")
    ))
  end
  table.insert(parts, "  },")

  table.insert(parts, "  receivers = {")
  for _, r in ipairs(data.receivers or {}) do
    table.insert(parts, string.format(
      "    { x = %d, y = %d, color = %s },",
      r.x, r.y, esc(r.color or "white")
    ))
  end
  table.insert(parts, "  },")

  table.insert(parts, "  entities = {")
  for _, ent in ipairs(data.entities or {}) do
    local rot = ent.rotation or 0
    local extra = ""
    if ent.visualAngle then
      extra = extra .. ", visualAngle = " .. ent.visualAngle
    end
    if ent.rotateInterval then
      extra = extra .. ", rotateInterval = " .. ent.rotateInterval
    end
    if ent.fixed then extra = extra .. ", fixed = true" end
    if ent.rotatable == false then extra = extra .. ", rotatable = false" end
    table.insert(parts, string.format(
      "    { type = %s, x = %d, y = %d, rotation = %d%s },",
      esc(ent.type), ent.x, ent.y, rot, extra
    ))
  end
  table.insert(parts, "  },")
  table.insert(parts, "}")
  return table.concat(parts, "\n")
end

--- Save a generated level; returns entry id.
function Storage.saveLevel(data, meta)
  Storage.init()
  meta = meta or {}
  local index = Storage.loadIndex()
  local id = meta.id or ("gen_" .. os.time() .. "_" .. math.random(1000, 9999))
  local path = LEVEL_DIR .. "/level_" .. id .. ".lua"

  love.filesystem.write(path, serializeLevel(data))

  -- Update or insert index entry
  local found = false
  for _, entry in ipairs(index.levels) do
    if entry.id == id then
      entry.name = data.name or entry.name
      entry.completed = meta.completed or entry.completed
      found = true
      break
    end
  end
  if not found then
    table.insert(index.levels, {
      id = id,
      name = data.name or ("Generated " .. (#index.levels + 1)),
      seed = data.seed or 0,
      difficulty = meta.difficulty or 1,
      completed = false,
      date = os.date("%Y-%m-%d %H:%M"),
    })
  end
  saveIndex(index)
  return id
end

--- Load a saved generated level by id.
function Storage.loadLevel(id)
  local path = LEVEL_DIR .. "/level_" .. id .. ".lua"
  local chunk = love.filesystem.load(path)
  if not chunk then return nil end
  return chunk()
end

--- Mark a generated level as completed.
function Storage.markCompleted(id)
  local index = Storage.loadIndex()
  for _, entry in ipairs(index.levels) do
    if entry.id == id then
      entry.completed = true
      saveIndex(index)
      return
    end
  end
end

--- Delete a saved level.
function Storage.deleteLevel(id)
  local index = Storage.loadIndex()
  local path = LEVEL_DIR .. "/level_" .. id .. ".lua"
  if love.filesystem.getInfo(path) then
    love.filesystem.remove(path)
  end
  for i = #index.levels, 1, -1 do
    if index.levels[i].id == id then
      table.remove(index.levels, i)
    end
  end
  saveIndex(index)
end

--- Export level data from a Level instance (for saving after edits).
function Storage.exportFromLevel(level)
  local DIR_NAMES = { "up", "right", "down", "left" }
  local data = {
    name = level.name,
    cols = level.cols,
    rows = level.rows,
    seed = level.seed,
    emitters = {},
    receivers = {},
    entities = {},
  }
  for _, em in ipairs(level.emitters) do
    table.insert(data.emitters, {
      x = em.x, y = em.y,
      direction = DIR_NAMES[em.emitDir] or "right",
      color = em.emitColor,
    })
  end
  for _, rc in ipairs(level.receivers) do
    table.insert(data.receivers, {
      x = rc.x, y = rc.y, color = rc.requiredColor,
    })
  end
  for y = 1, level.grid.rows do
    for x = 1, level.grid.cols do
      local e = level.grid:getEntity(x, y)
      if e and e.type ~= "receiver" and e.type ~= "emitter" then
        local ent = {
          type = e.type, x = x, y = y,
          rotation = e.rotation,
          visualAngle = e.visualAngle,
        }
        if e.fixed then ent.fixed = true end
        if e.rotatable == false then ent.rotatable = false end
        if e.rotateInterval then ent.rotateInterval = e.rotateInterval end
        table.insert(data.entities, ent)
      end
    end
  end
  return data
end

return Storage
