--[[
  raytracer.lua — Beam simulation engine for Prism Echo.

  Traces light beams from emitters across the grid using a deterministic
  cell-by-cell algorithm. Supports branching (prisms), merging (combiners),
  and guards against infinite loops via a global step limit.

  Returns:
    segments  — list of {x1,y1,x2,y2,color} screen-space line segments for rendering
    receivers — list of receiver entities with updated .satisfied flags
]]

local Entities = require("entities")

local Raytracer = {}

local MAX_STEPS = 500

--- Trace a single beam from (gx,gy) in direction dirIdx with given color.
-- Returns path segments (grid coords) and combiner inputs collected.
local function traceBeam(grid, gx, gy, dirIdx, color, segments, combinerInputs, stepBudget, receivers)
  local dx, dy = Entities.getDir(dirIdx)

  while stepBudget > 0 do
    stepBudget = stepBudget - 1

    -- Move to next cell
    local nx, ny = gx + dx, gy + dy
    if not grid:inBounds(nx, ny) then
      -- Draw segment to grid edge
      local ex = gx + dx * 0.5
      local ey = gy + dy * 0.5
      table.insert(segments, {
        x1 = gx, y1 = gy, x2 = ex, y2 = ey, color = color
      })
      break
    end

    -- Segment from current cell center to next cell center
    table.insert(segments, {
      x1 = gx, y1 = gy, x2 = nx, y2 = ny, color = color
    })

    gx, gy = nx, ny
    local entity = grid:getEntity(gx, gy)

    if not entity then
      -- Empty cell: continue straight
      dx, dy = Entities.getDir(dirIdx)
    elseif entity.type == "combiner" then
      -- Record input; merging handled after all primary traces
      local key = gx .. "," .. gy
      if not combinerInputs[key] then
        combinerInputs[key] = { x = gx, y = gy, inputs = {} }
      end
      -- entryDir is opposite of travel direction
      local entryDir = Entities.oppositeDir(Entities.dirIndex(dx, dy))
      table.insert(combinerInputs[key].inputs, {
        entryDir = entryDir,
        color = color,
        travelDir = Entities.dirIndex(dx, dy),
      })
      break
    elseif entity.type == "receiver" then
      entity.onBeamEnter(entity, Entities.oppositeDir(Entities.dirIndex(dx, dy)), color)
      table.insert(receivers, entity)
      break
    elseif entity.onBeamEnter then
      local entryDir = Entities.oppositeDir(Entities.dirIndex(dx, dy))
      local outputs = entity.onBeamEnter(entity, entryDir, color)
      if not outputs or #outputs == 0 then
        break -- absorbed
      elseif #outputs == 1 then
        dirIdx = outputs[1].dir
        color = outputs[1].color
        dx, dy = Entities.getDir(dirIdx)
      else
        -- Branch (prism split): trace each outgoing beam independently
        for _, out in ipairs(outputs) do
          stepBudget = traceBeam(grid, gx, gy, out.dir, out.color, segments, combinerInputs, stepBudget, receivers)
        end
        break
      end
    else
      break
    end
  end

  return stepBudget
end

-- Note: refractive crystal uses a discrete 90° bend on the orthogonal grid
-- (rotation offsets which adjacent cardinal direction is chosen). This approximates
-- partial refraction without requiring diagonal grid cells.

--- Process combiner cells: merge beams from different edges, continue tracing.
local function processCombiners(grid, combinerInputs, segments, stepBudget, receivers)
  for _, combo in pairs(combinerInputs) do
    local inputs = combo.inputs
    if #inputs == 0 then goto continue end

    if #inputs == 1 then
      -- Single beam passes through in original travel direction
      local inp = inputs[1]
      local outDir = inp.travelDir
      stepBudget = traceBeam(grid, combo.x, combo.y, outDir, inp.color, segments, {}, stepBudget, receivers)
    elseif #inputs >= 2 then
      -- Find two beams from different entry edges with different colors
      local merged = false
      for i = 1, #inputs do
        for j = i + 1, #inputs do
          local a, b = inputs[i], inputs[j]
          if a.entryDir ~= b.entryDir and a.color ~= b.color then
            local mixedName = Entities.mixColors(
              Entities.getColorRGB(a.color),
              Entities.getColorRGB(b.color)
            )
            -- Output continues in the direction of the first beam's travel
            local outDir = a.travelDir
            stepBudget = traceBeam(grid, combo.x, combo.y, outDir, mixedName, segments, {}, stepBudget, receivers)
            merged = true
            break
          end
        end
        if merged then break end
      end
      if not merged then
        -- No valid pair: each beam passes through individually
        for _, inp in ipairs(inputs) do
          stepBudget = traceBeam(grid, combo.x, combo.y, inp.travelDir, inp.color, segments, {}, stepBudget, receivers)
        end
      end
    end
    ::continue::
  end
end

--- Main trace function: recompute all beam paths from emitters.
-- @param grid Grid       The game grid with entities
-- @param emitters table  List of emitter entities (with x, y, emitDir, emitColor)
-- @return segments table, allSatisfied boolean, satisfiedTicks number
function Raytracer.trace(grid, emitters, receivers)
  -- Reset receiver satisfaction
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
  local combinerInputs = {}
  local stepBudget = MAX_STEPS
  local hitReceivers = {}

  for _, emitter in ipairs(emitters) do
    if stepBudget <= 0 then break end
    stepBudget = traceBeam(
      grid, emitter.x, emitter.y, emitter.emitDir, emitter.emitColor,
      segments, combinerInputs, stepBudget, hitReceivers
    )
  end

  processCombiners(grid, combinerInputs, segments, stepBudget, hitReceivers)

  -- Check if all receivers satisfied
  local allSatisfied = #receiverList > 0
  for _, r in ipairs(receiverList) do
    if not r.satisfied then
      allSatisfied = false
      break
    end
  end

  return segments, allSatisfied, receiverList
end

--- Convert grid-coordinate segments to screen-coordinate segments for rendering.
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

--- Draw beam segments with layered glow effect.
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

  -- Bright core
  for _, seg in ipairs(segments) do
    local rgb = Entities.getColorRGB(seg.color)
    love.graphics.setColor(rgb[1], rgb[2], rgb[3], 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(seg.x1, seg.y1, seg.x2, seg.y2)
  end
end

return Raytracer
