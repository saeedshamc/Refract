--[[
  lever.lua — Valve/lever drag rotation for rotatable entities.

  The player grabs a knob and rotates freely; visualAngle drives beam physics
  continuously (any degree), not just 4 snapped positions.
]]

local Lever = {}

function Lever.ensureAngle(entity)
  if entity.visualAngle == nil then
    entity.visualAngle = (entity.rotation or 0) * (math.pi / 2)
  end
end

function Lever.getDegrees(entity)
  Lever.ensureAngle(entity)
  local deg = math.deg(entity.visualAngle) % 360
  if deg < 0 then deg = deg + 360 end
  return deg
end

function Lever.startDrag(entity, cx, cy, mx, my)
  Lever.ensureAngle(entity)
  local mouseAngle = math.atan2(my - cy, mx - cx)
  entity._dragOffset = entity.visualAngle - mouseAngle
end

--- Free rotation — no snapping; angle maps directly to beam direction.
function Lever.updateDrag(entity, cx, cy, mx, my)
  local mouseAngle = math.atan2(my - cy, mx - cx)
  entity.visualAngle = mouseAngle + (entity._dragOffset or 0)
end

function Lever.endDrag(entity)
  entity._dragOffset = nil
end

function Lever.isKnobHit(cx, cy, size, mx, my)
  local knobR = size * 0.38
  local dx, dy = mx - cx, my - cy
  return (dx * dx + dy * dy) <= (knobR * knobR)
end

function Lever.drawKnob(entity, cx, cy, size, isActive)
  Lever.ensureAngle(entity)
  local r = size * 0.22
  local handleLen = size * 0.28

  love.graphics.setColor(0.35, 0.38, 0.45, isActive and 1 or 0.85)
  love.graphics.circle("fill", cx, cy, r)
  love.graphics.setColor(0.55, 0.6, 0.7, isActive and 1 or 0.7)
  love.graphics.setLineWidth(isActive and 2.5 or 1.5)
  love.graphics.circle("line", cx, cy, r)

  local hx = cx + math.cos(entity.visualAngle) * handleLen
  local hy = cy + math.sin(entity.visualAngle) * handleLen
  love.graphics.setColor(isActive and 1 or 0.85, isActive and 0.85 or 0.7, 0.4, 1)
  love.graphics.setLineWidth(isActive and 4 or 2.5)
  love.graphics.line(cx, cy, hx, hy)

  -- Degree readout while dragging
  if isActive then
    local deg = math.floor(Lever.getDegrees(entity) + 0.5)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(deg .. "°", cx - 12, cy - size * 0.45)
  end
end

return Lever
