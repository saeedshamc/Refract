--[[
  raytracer.lua — Continuous-angle beam simulation for Prism Echo.

  Beams travel at any angle (radians) controlled by entity lever rotation.
  Mirrors use specular reflection from visualAngle; no 90°/180° snapping.
]]

local Entities = require("entities")

local Raytracer = {}

local MAX_STEPS = 500
local EPS = 1e-6

--- Cell containing grid-space point (cell centers at integer coords).
local function cellAt(x, y)
  return math.floor(x + 0.5), math.floor(y + 0.5)
end

--- Distance along ray to exit current cell boundary.
local function nextBoundaryT(x, y, dx, dy, cx, cy)
  local tMin = math.huge
  if dx > EPS then
    local t = (cx + 0.5 - x) / dx
    if t > EPS then tMin = math.min(tMin, t) end
  elseif dx < -EPS then
    local t = (cx - 0.5 - x) / dx
    if t > EPS then tMin = math.min(tMin, t) end
  end
  if dy > EPS then
    local t = (cy + 0.5 - y) / dy
    if t > EPS then tMin = math.min(tMin, t) end
  elseif dy < -EPS then
    local t = (cy - 0.5 - y) / dy
    if t > EPS then tMin = math.min(tMin, t) end
  end
  return tMin
end

--- Trace one continuous beam; splits recursively for prisms.
local function traceContinuous(grid, x, y, angle, color, segments, budget, receivers, visited, combinerInputs)
  visited = visited or {}
  combinerInputs = combinerInputs or {}
  local cx, cy = cellAt(x, y)

  for _ = 1, budget do
    if not grid:inBounds(cx, cy) then break end

    local vkey = cx .. "," .. cy .. "," .. math.floor(angle * 57.2958)
    visited[vkey] = (visited[vkey] or 0) + 1
    if visited[vkey] > 4 then break end

    local dx, dy = math.cos(angle), math.sin(angle)
    local t = nextBoundaryT(x, y, dx, dy, cx, cy)
    if t == math.huge then break end

    local nx, ny = x + dx * t, y + dy * t
    table.insert(segments, { x1 = x, y1 = y, x2 = nx, y2 = ny, color = color })

    local ncx, ncy = cellAt(nx + dx * EPS, ny + dy * EPS)
    if not grid:inBounds(ncx, ncy) then break end

    x = nx + dx * EPS
    y = ny + dy * EPS
    cx, cy = ncx, ncy

    local entity = grid:getEntity(cx, cy)
    if not entity then
      -- empty cell
    elseif entity.type == "wall" then
      break
    elseif entity.type == "receiver" then
      if color == entity.requiredColor then entity.satisfied = true end
      table.insert(receivers, entity)
      break
    elseif entity.type == "combiner" then
      local key = cx .. "," .. cy
      combinerInputs[key] = combinerInputs[key] or { x = cx, y = cy, inputs = {} }
      table.insert(combinerInputs[key].inputs, { angle = angle, color = color })
      return
    elseif entity.type == "mirror" or entity.type == "auto_mirror" then
      angle = Entities.reflectMirror(entity, angle)
    elseif entity.type == "prism" then
      if Entities.isWhite(color) then
        local base = Entities.getAngle(entity)
        for i, beamColor in ipairs({ "red", "green", "blue" }) do
          local splitAngle = base + (i - 1) * (2 * math.pi / 3)
          traceContinuous(grid, x, y, splitAngle, beamColor, segments, budget - 1, receivers, visited, combinerInputs)
        end
        return
      else
        angle = angle + math.pi
      end
    elseif entity.type == "crystal" then
      local orient = Entities.getAngle(entity)
      angle = orient + (angle - orient) * 0.5 + math.pi / 5
    end
  end
end

local function angleDiff(a, b)
  local d = math.abs(a - b) % (2 * math.pi)
  return math.min(d, 2 * math.pi - d)
end

local function processCombiners(grid, combinerInputs, segments, receivers)
  for _, combo in pairs(combinerInputs) do
    local inputs = combo.inputs
    if #inputs == 0 then goto continue end

    if #inputs == 1 then
      traceContinuous(grid, combo.x, combo.y, inputs[1].angle, inputs[1].color, segments, MAX_STEPS, receivers, {}, {})
    else
      local merged = false
      for i = 1, #inputs do
        for j = i + 1, #inputs do
          local a, b = inputs[i], inputs[j]
          if a.color ~= b.color and angleDiff(a.angle, b.angle) > math.pi / 4 then
            local mixedName = Entities.mixColors(
              Entities.getColorRGB(a.color), Entities.getColorRGB(b.color)
            )
            traceContinuous(grid, combo.x, combo.y, a.angle, mixedName, segments, MAX_STEPS, receivers, {}, {})
            merged = true
            break
          end
        end
        if merged then break end
      end
      if not merged then
        for _, inp in ipairs(inputs) do
          traceContinuous(grid, combo.x, combo.y, inp.angle, inp.color, segments, MAX_STEPS, receivers, {}, {})
        end
      end
    end
    ::continue::
  end
end

--- Main trace: recompute all beam paths from emitters.
function Raytracer.trace(grid, emitters)
  local receiverList = {}
  for y = 1, grid.rows do
    for x = 1, grid.cols do
      local e = grid:getEntity(x, y)
      if e and e.type == "receiver" then
        e.satisfied = false
        table.insert(receiverList, e)
      end
    end
  end

  local segments = {}
  local hitReceivers = {}
  local combinerInputs = {}

  for _, emitter in ipairs(emitters) do
    local angle = Entities.dirToAngle(emitter.emitDir)
    traceContinuous(
      grid, emitter.x, emitter.y, angle, emitter.emitColor,
      segments, MAX_STEPS, hitReceivers, {}, combinerInputs
    )
  end

  processCombiners(grid, combinerInputs, segments, hitReceivers)

  local allSatisfied = #receiverList > 0
  for _, r in ipairs(receiverList) do
    if not r.satisfied then
      allSatisfied = false
      break
    end
  end

  return segments, allSatisfied, receiverList
end

function Raytracer.toScreenSegments(grid, gridSegments)
  local screenSegs = {}
  for _, seg in ipairs(gridSegments) do
    local sx1, sy1 = grid:gridToScreen(seg.x1, seg.y1)
    local sx2, sy2 = grid:gridToScreen(seg.x2, seg.y2)
    table.insert(screenSegs, {
      x1 = sx1, y1 = sy1, x2 = sx2, y2 = sy2, color = seg.color
    })
  end
  return screenSegs
end

function Raytracer.drawBeams(segments)
  local glowLayers = {
    { width = 12, alpha = 0.06 },
    { width = 8,  alpha = 0.12 },
    { width = 5,  alpha = 0.25 },
    { width = 2,  alpha = 0.7  },
  }

  for _, layer in ipairs(glowLayers) do
    for _, seg in ipairs(segments) do
      local rgb = Entities.getColorRGB(seg.color)
      love.graphics.setColor(rgb[1], rgb[2], rgb[3], layer.alpha)
      love.graphics.setLineWidth(layer.width)
      love.graphics.line(seg.x1, seg.y1, seg.x2, seg.y2)
    end
  end

  for _, seg in ipairs(segments) do
    local rgb = Entities.getColorRGB(seg.color)
    love.graphics.setColor(rgb[1], rgb[2], rgb[3], 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(seg.x1, seg.y1, seg.x2, seg.y2)
  end
end

return Raytracer
