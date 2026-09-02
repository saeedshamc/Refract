--[[
  entities.lua — Entity definitions and beam-interaction behavior for Prism Echo.

  Each entity is a plain Lua table with:
    type       — string identifier
    rotation   — 0–3 (90° steps clockwise)
    rotatable  — whether the player can rotate it
    fixed      — if true, cannot be moved from inventory
    onBeamEnter(entity, entryDir, color) → list of {dir, color} | nil (absorbed)
    draw(entity, cx, cy, size) — render the entity icon

  Direction constants use dx/dy: up(0,-1), right(1,0), down(0,1), left(-1,0).
]]

local Entities = {}

-- ── Direction helpers ──────────────────────────────────────────────────────

Entities.DIRS = {
  { dx = 0,  dy = -1, name = "up"    },
  { dx = 1,  dy = 0,  name = "right" },
  { dx = 0,  dy = 1,  name = "down"  },
  { dx = -1, dy = 0,  name = "left"  },
}

--- Return direction index (1–4) from dx/dy.
function Entities.dirIndex(dx, dy)
  for i, d in ipairs(Entities.DIRS) do
    if d.dx == dx and d.dy == dy then return i end
  end
  return 1
end

--- Rotate a direction index clockwise by `steps` quarter-turns.
function Entities.rotateDir(dirIdx, steps)
  return ((dirIdx - 1 + steps) % 4) + 1
end

--- Get dx/dy for a direction index.
function Entities.getDir(dirIdx)
  local d = Entities.DIRS[dirIdx]
  return d.dx, d.dy
end

--- Opposite direction index.
function Entities.oppositeDir(dirIdx)
  return ((dirIdx - 1 + 2) % 4) + 1
end

-- ── Color helpers ───────────────────────────────────────────────────────────

Entities.COLORS = {
  white   = { 1.0, 1.0, 1.0 },
  red     = { 1.0, 0.2, 0.2 },
  green   = { 0.2, 1.0, 0.3 },
  blue    = { 0.3, 0.5, 1.0 },
  yellow  = { 1.0, 1.0, 0.2 },
  magenta = { 1.0, 0.2, 1.0 },
  cyan    = { 0.2, 1.0, 1.0 },
}

--- Additive light mixing: combine two RGB colors.
function Entities.mixColors(c1, c2)
  local r = math.min(1, c1[1] + c2[1])
  local g = math.min(1, c1[2] + c2[2])
  local b = math.min(1, c1[3] + c2[3])
  -- Map back to named color for logic checks
  if r > 0.9 and g > 0.9 and b > 0.9 then return "white", { r, g, b } end
  if r > 0.9 and g > 0.9 and b < 0.5 then return "yellow", { r, g, b } end
  if r > 0.9 and g < 0.5 and b > 0.9 then return "magenta", { r, g, b } end
  if r < 0.5 and g > 0.9 and b > 0.9 then return "cyan", { r, g, b } end
  if r > 0.9 and g < 0.5 and b < 0.5 then return "red", { r, g, b } end
  if r < 0.5 and g > 0.9 and b < 0.5 then return "green", { r, g, b } end
  if r < 0.5 and g < 0.5 and b > 0.9 then return "blue", { r, g, b } end
  return "white", { r, g, b }
end

function Entities.getColorRGB(name)
  return Entities.COLORS[name] or Entities.COLORS.white
end

function Entities.isWhite(color)
  return color == "white"
end

-- ── Mirror reflection map ───────────────────────────────────────────────────
-- orientation 0 = "/" mirror: N↔E, S↔W
-- orientation 1 = "\" mirror: N↔W, S↔E
-- Even rotations → "/", odd → "\"

local function mirrorReflect(entryDir, rotation)
  local isSlash = (rotation % 2) == 0
  -- entryDir: 1=up, 2=right, 3=down, 4=left
  if isSlash then
    -- "/" connects: up↔right(1↔2), down↔left(3↔4)
    local map = { [1]=2, [2]=1, [3]=4, [4]=3 }
    return map[entryDir]
  else
    -- "\" connects: up↔left(1↔4), down↔right(3↔2)
    local map = { [1]=4, [4]=1, [3]=2, [2]=3 }
    return map[entryDir]
  end
end

-- ── Entity factories ─────────────────────────────────────────────────────────

local function baseEntity(entityType, opts)
  opts = opts or {}
  return {
    type = entityType,
    rotation = opts.rotation or 0,
    rotatable = opts.rotatable ~= false,
    fixed = opts.fixed or false,
    x = opts.x,
    y = opts.y,
    -- Auto-rotating mirror fields
    autoRotate = opts.autoRotate or false,
    rotateInterval = opts.rotateInterval or 2.0,
    rotateTimer = 0,
    requiredColor = opts.requiredColor,
    emitColor = opts.emitColor or "white",
    emitDir = opts.emitDir or 2, -- default: right
  }
end

--- Mirror: reflects beam 90°.
function Entities.createMirror(opts)
  local e = baseEntity("mirror", opts)
  function e.onBeamEnter(self, entryDir, color)
    local outDir = mirrorReflect(entryDir, self.rotation)
    if outDir then
      return { { dir = outDir, color = color } }
    end
    return nil
  end
  function e.draw(self, cx, cy, size)
    local s = size * 0.35
    love.graphics.setColor(0.7, 0.85, 1.0, 0.9)
    love.graphics.setLineWidth(3)
    if self.rotation % 2 == 0 then
      love.graphics.line(cx - s, cy + s, cx + s, cy - s)
    else
      love.graphics.line(cx - s, cy - s, cx + s, cy + s)
    end
  end
  return e
end

--- Auto-Rotating Mirror: same as mirror but rotates continuously.
function Entities.createAutoMirror(opts)
  local e = Entities.createMirror(opts)
  e.type = "auto_mirror"
  e.autoRotate = true
  e.rotatable = false
  e.fixed = true
  function e.update(self, dt)
    if not self.autoRotate then return end
    self.rotateTimer = self.rotateTimer + dt
    if self.rotateTimer >= self.rotateInterval then
      self.rotateTimer = self.rotateTimer - self.rotateInterval
      self.rotation = (self.rotation + 1) % 4
    end
  end
  function e.draw(self, cx, cy, size)
    Entities.createMirror({}).draw(self, cx, cy, size)
    love.graphics.setColor(1, 0.8, 0.3, 0.6)
    love.graphics.circle("line", cx, cy, size * 0.15)
  end
  return e
end

--- Prism: splits white light into R/G/B; colored beams pass through.
-- At rotation 0: red→right(2), green→down(3), blue→left(4)
-- Rotating the prism rotates all exit directions together.
function Entities.createPrism(opts)
  local e = baseEntity("prism", opts)
  function e.onBeamEnter(self, entryDir, color)
    if Entities.isWhite(color) then
      local r = self.rotation
      local redDir   = Entities.rotateDir(2, r)   -- base: right
      local greenDir = Entities.rotateDir(3, r)   -- base: down
      local blueDir  = Entities.rotateDir(4, r)   -- base: left
      return {
        { dir = redDir,   color = "red"   },
        { dir = greenDir, color = "green" },
        { dir = blueDir,  color = "blue"  },
      }
    end
    -- Colored beam passes straight through
    local outDir = Entities.oppositeDir(entryDir)
    return { { dir = outDir, color = color } }
  end
  function e.draw(self, cx, cy, size)
    local s = size * 0.32
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.polygon("fill",
      cx, cy - s,
      cx + s, cy + s * 0.6,
      cx - s, cy + s * 0.6)
    love.graphics.setColor(1, 0.2, 0.2, 0.7)
    love.graphics.circle("fill", cx + s * 0.5, cy, s * 0.15)
    love.graphics.setColor(0.2, 1, 0.3, 0.7)
    love.graphics.circle("fill", cx, cy + s * 0.4, s * 0.15)
    love.graphics.setColor(0.3, 0.5, 1, 0.7)
    love.graphics.circle("fill", cx - s * 0.5, cy, s * 0.15)
  end
  return e
end

--- Color Combiner: merges two differently-colored beams from different edges.
-- Single beam passes through unchanged. Actual merging handled in raytracer.
function Entities.createCombiner(opts)
  local e = baseEntity("combiner", opts)
  e.rotatable = false
  function e.onBeamEnter(self, entryDir, color)
    -- Raytracer handles multi-beam logic; single-beam fallback here
    local outDir = Entities.oppositeDir(entryDir)
    return { { dir = outDir, color = color } }
  end
  function e.draw(self, cx, cy, size)
    local s = size * 0.3
    love.graphics.setColor(0.8, 0.6, 1.0, 0.85)
    love.graphics.rectangle("fill", cx - s, cy - s, s * 2, s * 2, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx - s, cy - s, s * 2, s * 2, 4, 4)
  end
  return e
end

--- Refractive Crystal: bends beam ~45° (one diagonal step on orthogonal grid).
-- Approach: incoming cardinal direction is bent to an adjacent cardinal direction
-- that is 90° from the incoming (simulating partial refraction on a square grid).
-- rotation shifts which adjacent direction is chosen.
function Entities.createCrystal(opts)
  local e = baseEntity("crystal", opts)
  function e.onBeamEnter(self, entryDir, color)
    -- Bend clockwise by 1 step from incoming, modified by rotation
    local bendSteps = 1 + self.rotation
    local outDir = Entities.rotateDir(entryDir, bendSteps)
    return { { dir = outDir, color = color } }
  end
  function e.draw(self, cx, cy, size)
    local s = size * 0.28
    love.graphics.setColor(0.5, 0.9, 1.0, 0.7)
    love.graphics.polygon("fill",
      cx, cy - s,
      cx + s * 0.7, cy,
      cx, cy + s,
      cx - s * 0.7, cy)
    love.graphics.setColor(0.8, 1, 1, 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line",
      cx, cy - s,
      cx + s * 0.7, cy,
      cx, cy + s,
      cx - s * 0.7, cy)
  end
  return e
end

--- Wall: absorbs all light.
function Entities.createWall(opts)
  local e = baseEntity("wall", opts)
  e.rotatable = false
  e.fixed = true
  function e.onBeamEnter(self, entryDir, color)
    return nil
  end
  function e.draw(self, cx, cy, size)
    local s = size * 0.42
    love.graphics.setColor(0.25, 0.25, 0.3, 1)
    love.graphics.rectangle("fill", cx - s, cy - s, s * 2, s * 2)
    love.graphics.setColor(0.4, 0.4, 0.45, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", cx - s, cy - s, s * 2, s * 2)
  end
  return e
end

--- Emitter: fixed light source (handled specially by raytracer, not placed on grid cells).
function Entities.createEmitter(opts)
  local e = baseEntity("emitter", opts)
  e.rotatable = false
  e.fixed = true
  function e.onBeamEnter(self, entryDir, color)
    return nil
  end
  function e.draw(self, cx, cy, size)
    local rgb = Entities.getColorRGB(self.emitColor)
    love.graphics.setColor(rgb[1], rgb[2], rgb[3], 0.9)
    love.graphics.circle("fill", cx, cy, size * 0.25)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, size * 0.25)
    -- Direction indicator
    local dx, dy = Entities.getDir(self.emitDir)
    love.graphics.line(cx, cy, cx + dx * size * 0.35, cy + dy * size * 0.35)
  end
  return e
end

--- Receiver: goal cell; beam terminates here if color matches.
function Entities.createReceiver(opts)
  local e = baseEntity("receiver", opts)
  e.rotatable = false
  e.fixed = true
  e.satisfied = false
  function e.onBeamEnter(self, entryDir, color)
    if color == self.requiredColor then
      self.satisfied = true
    end
    return nil -- beam always terminates at receiver
  end
  function e.draw(self, cx, cy, size)
    local rgb = Entities.getColorRGB(self.requiredColor)
    local alpha = self.satisfied and 1.0 or 0.25
    local glow = self.satisfied and 0.6 or 0.1
    love.graphics.setColor(rgb[1], rgb[2], rgb[3], glow)
    love.graphics.circle("fill", cx, cy, size * 0.38)
    love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha)
    love.graphics.setLineWidth(self.satisfied and 3 or 1.5)
    love.graphics.circle("line", cx, cy, size * 0.38)
    if self.satisfied then
      love.graphics.setColor(1, 1, 1, 0.8)
      love.graphics.circle("fill", cx, cy, size * 0.12)
    end
  end
  return e
end

--- Factory dispatch: create entity by type string.
function Entities.create(entityType, opts)
  local factories = {
    mirror      = Entities.createMirror,
    auto_mirror = Entities.createAutoMirror,
    prism       = Entities.createPrism,
    combiner    = Entities.createCombiner,
    crystal     = Entities.createCrystal,
    wall        = Entities.createWall,
    emitter     = Entities.createEmitter,
    receiver    = Entities.createReceiver,
  }
  local fn = factories[entityType]
  if fn then return fn(opts) end
  error("Unknown entity type: " .. tostring(entityType))
end

--- Rotate entity 90° clockwise (if rotatable).
function Entities.rotate(entity)
  if entity and entity.rotatable then
    entity.rotation = (entity.rotation + 1) % 4
    return true
  end
  return false
end

--- Update time-based entities (auto-rotating mirrors).
function Entities.updateAll(grid, dt)
  for y = 1, grid.rows do
    for x = 1, grid.cols do
      local e = grid.cells[y][x]
      if e and e.update then e:update(dt) end
    end
  end
end

--- Draw all entities on the grid.
function Entities.drawAll(grid)
  for y = 1, grid.rows do
    for x = 1, grid.cols do
      local e = grid.cells[y][x]
      if e and e.draw and e.type ~= "emitter" and e.type ~= "receiver" then
        local cx, cy = grid:gridToScreen(x, y)
        e:draw(cx, cy, grid.cellSize)
      end
    end
  end
end

--- Draw emitters and receivers (may be on grid edge cells).
function Entities.drawSpecial(grid, specialList)
  for _, e in ipairs(specialList) do
    if e.draw then
      local cx, cy = grid:gridToScreen(e.x, e.y)
      e:draw(cx, cy, grid.cellSize)
    end
  end
end

return Entities
