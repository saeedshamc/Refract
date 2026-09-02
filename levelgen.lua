--[[
  levelgen.lua — Procedural level generation for Prism Echo.

  Builds solvable mirror-routing puzzles from a seed using a random path
  with turns, places mirrors at each bend with scrambled rotations, and
  optionally adds walls. Validates solvability via the raytracer.
]]

local LevelGen = {}

-- Seeded LCG random number generator
local function makeRng(seed)
  local state = (seed or os.time()) % 2147483647
  if state <= 0 then state = state + 2147483646 end
  return function()
    state = (state * 16807) % 2147483647
    return (state - 1) / 2147483646
  end
end

local DIR = { UP = 1, RIGHT = 2, DOWN = 3, LEFT = 4 }

local DX = { [1] = 0, [2] = 1, [3] = 0, [4] = -1 }
local DY = { [1] = -1, [2] = 0, [3] = 1, [4] = 0 }

--- Mirror rotation that reflects incoming `inDir` to outgoing `outDir`.
local function mirrorRotationFor(inDir, outDir)
  -- Try all 4 rotations and pick the one that maps inDir → outDir
  for rot = 0, 3 do
    local isSlash = (rot % 2) == 0
    local map
    if isSlash then
      map = { [1]=2, [2]=1, [3]=4, [4]=3 }
    else
      map = { [1]=4, [4]=1, [3]=2, [2]=3 }
    end
    if map[inDir] == outDir then return rot end
  end
  return 0
end

--- Opposite direction.
local function opposite(d) return ((d - 1 + 2) % 4) + 1 end

--- Turn clockwise from `from` to get new direction.
local function turnRight(d) return (d % 4) + 1 end
local function turnLeft(d) return ((d - 2) % 4) + 1 end

--- Build a random orthogonal path from start to end cell.
local function buildPath(cols, rows, rng, startX, startY, endX, endY)
  local path = {}
  local occupied = {}
  local function key(x, y) return x .. "," .. y end

  local x, y = startX, startY
  local dir = DIR.RIGHT
  table.insert(path, { x = x, y = y })
  occupied[key(x, y)] = true

  local maxSteps = cols * rows * 2
  local steps = 0

  while (x ~= endX or y ~= endY) and steps < maxSteps do
    steps = steps + 1
    local options = {}

    -- Prefer moving toward target
    if x < endX then table.insert(options, DIR.RIGHT) end
    if x > endX then table.insert(options, DIR.LEFT) end
    if y < endY then table.insert(options, DIR.DOWN) end
    if y > endY then table.insert(options, DIR.UP) end

    -- Add perpendicular options for interesting paths
    if dir == DIR.RIGHT or dir == DIR.LEFT then
      table.insert(options, DIR.UP)
      table.insert(options, DIR.DOWN)
    else
      table.insert(options, DIR.LEFT)
      table.insert(options, DIR.RIGHT)
    end

    -- Shuffle and pick first valid
    for i = #options, 2, -1 do
      local j = math.floor(rng() * i) + 1
      options[i], options[j] = options[j], options[i]
    end

    local moved = false
    for _, d in ipairs(options) do
      local nx = x + DX[d]
      local ny = y + DY[d]
      if nx >= 1 and nx <= cols and ny >= 1 and ny <= rows and not occupied[key(nx, ny)] then
        x, y = nx, ny
        dir = d
        table.insert(path, { x = x, y = y })
        occupied[key(x, y)] = true
        moved = true
        break
      end
    end

    if not moved then break end
  end

  return path, (x == endX and y == endY)
end

--- Extract turn points from path with incoming/outgoing directions.
local function extractTurns(path)
  local turns = {}
  if #path < 3 then return turns end

  local function deltaDir(x1, y1, x2, y2)
    if x2 > x1 then return DIR.RIGHT end
    if x2 < x1 then return DIR.LEFT end
    if y2 > y1 then return DIR.DOWN end
    return DIR.UP
  end

  for i = 2, #path - 1 do
    local prev, curr, next = path[i - 1], path[i], path[i + 1]
    local inDir = opposite(deltaDir(prev.x, prev.y, curr.x, curr.y))
    local outDir = deltaDir(curr.x, curr.y, next.x, next.y)
    if inDir ~= outDir then
      table.insert(turns, {
        x = curr.x, y = curr.y,
        inDir = inDir, outDir = outDir,
        solutionRot = mirrorRotationFor(inDir, outDir),
      })
    end
  end
  return turns
end

--- Validate level is solvable with current entity rotations.
function LevelGen.validate(data)
  local Level = require("level")
  local Raytracer = require("raytracer")
  local ok, level = pcall(function() return Level.fromData(data, 0) end)
  if not ok or not level then return false end
  local _, solved = Raytracer.trace(level.grid, level.emitters)
  return solved
end

--- Generate a level from seed and difficulty (1–5).
function LevelGen.generate(seed, difficulty)
  difficulty = difficulty or 1
  local rng = makeRng(seed)

  local cols = 10 + math.floor(rng() * 3)
  local rows = 7 + math.floor(rng() * 2)

  local startY = 2 + math.floor(rng() * (rows - 3))
  local endY = 2 + math.floor(rng() * (rows - 3))
  local startX, endX = 1, cols

  local path, reached = buildPath(cols, rows, rng, startX, startY, endX, endY)

  -- Retry with new endpoints if path failed
  local attempts = 0
  while not reached and attempts < 10 do
    startY = 2 + math.floor(rng() * (rows - 3))
    endY = 2 + math.floor(rng() * (rows - 3))
    path, reached = buildPath(cols, rows, rng, startX, startY, endX, endY)
    attempts = attempts + 1
  end

  if not reached then
    -- Fallback simple L-shaped level
    path = {
      { x = 1, y = startY },
      { x = math.floor(cols / 2), y = startY },
      { x = math.floor(cols / 2), y = endY },
      { x = cols, y = endY },
    }
    endY = endY
  end

  local turns = extractTurns(path)
  local entities = {}
  local pathSet = {}
  for _, p in ipairs(path) do pathSet[p.x .. "," .. p.y] = true end

  -- Place mirrors at turns with scrambled rotation
  for _, t in ipairs(turns) do
    local wrongRot = t.solutionRot
    while wrongRot == t.solutionRot do
      wrongRot = math.floor(rng() * 4)
    end
    table.insert(entities, {
      type = "mirror",
      x = t.x, y = t.y,
      rotation = wrongRot,
      rotatable = true,
    })
  end

  -- Add random walls off the path (more at higher difficulty)
  local wallCount = math.floor(difficulty * 1.5)
  for _ = 1, wallCount do
    local wx = 2 + math.floor(rng() * (cols - 3))
    local wy = 2 + math.floor(rng() * (rows - 3))
    if not pathSet[wx .. "," .. wy] and wx ~= endX and wy ~= startY then
      local blocked = false
      for _, e in ipairs(entities) do
        if e.x == wx and e.y == wy then blocked = true; break end
      end
      if not blocked then
        table.insert(entities, { type = "wall", x = wx, y = wy, fixed = true })
      end
    end
  end

  -- Difficulty 3+: add a prism and colored receiver
  local emitColor = "white"
  local recvColor = "white"
  if difficulty >= 3 and #turns >= 1 then
    -- Replace last mirror with prism, change receiver to red
    for i, e in ipairs(entities) do
      if e.type == "mirror" then
        entities[i] = {
          type = "prism", x = e.x, y = e.y,
          rotation = math.floor(rng() * 4), rotatable = true,
        }
        recvColor = "red"
        break
      end
    end
  end

  local data = {
    name = "Generated #" .. (seed % 10000),
    cols = cols,
    rows = rows,
    seed = seed,
    emitters = {
      { x = startX, y = startY, direction = "right", color = emitColor },
    },
    receivers = {
      { x = endX, y = endY, color = recvColor },
    },
    entities = entities,
  }

  -- Verify solvable by applying solution rotations in a test copy
  local solutionData = LevelGen.copyData(data)
  for _, t in ipairs(turns) do
    for _, e in ipairs(solutionData.entities) do
      if e.x == t.x and e.y == t.y and e.type == "mirror" then
        e.rotation = t.solutionRot
      end
    end
  end

  if not LevelGen.validate(solutionData) then
    -- Regenerate with different seed offset
    return LevelGen.generate(seed + 1, difficulty)
  end

  return data
end

--- Deep-copy level data table.
function LevelGen.copyData(data)
  local copy = {
    name = data.name, cols = data.cols, rows = data.rows, seed = data.seed,
    emitters = {}, receivers = {}, entities = {},
  }
  for _, e in ipairs(data.emitters or {}) do
    table.insert(copy.emitters, { x=e.x, y=e.y, direction=e.direction, color=e.color })
  end
  for _, r in ipairs(data.receivers or {}) do
    table.insert(copy.receivers, { x=r.x, y=r.y, color=r.color })
  end
  for _, ent in ipairs(data.entities or {}) do
    table.insert(copy.entities, {
      type=ent.type, x=ent.x, y=ent.y, rotation=ent.rotation or 0,
      rotatable=ent.rotatable, fixed=ent.fixed,
      rotateInterval=ent.rotateInterval,
    })
  end
  return copy
end

return LevelGen
