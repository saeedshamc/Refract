--[[
  lever.lua — Valve/lever drag rotation for rotatable entities.

  The player grabs a knob on an entity and rotates it with the mouse,
  like turning a valve. Visual angle is continuous; game logic snaps
  to one of four 90° orientations (rotation 0–3).
]]

local Lever = {}

--- Initialize visual angle from discrete rotation if missing.
function Lever.ensureAngle(entity)
  if entity.visualAngle == nil then
    entity.visualAngle = entity.rotation * (math.pi / 2)
  end
end

--- Begin lever drag: record offset between knob angle and mouse angle.
function Lever.startDrag(entity, cx, cy, mx, my)
  Lever.ensureAngle(entity)
  local mouseAngle = math.atan2(my - cy, mx - cx)
  entity._dragOffset = entity.visualAngle - mouseAngle
  entity._dragLastRotation = entity.rotation
end

--- Update lever angle while dragging; snap rotation to nearest quarter-turn.
function Lever.updateDrag(entity, cx, cy, mx, my)
  local mouseAngle = math.atan2(my - cy, mx - cx)
  entity.visualAngle = mouseAngle + (entity._dragOffset or 0)
  local quarter = math.pi / 2
  entity.rotation = (math.floor(entity.visualAngle / quarter + 0.5) % 4 + 4) % 4
end

--- End lever drag; finalize snap.
function Lever.endDrag(entity)
  entity.visualAngle = entity.rotation * (math.pi / 2)
  entity._dragOffset = nil
  entity._dragLastRotation = nil
end

--- Hit-test: is mouse within knob radius of entity center?
function Lever.isKnobHit(cx, cy, size, mx, my)
  local knobR = size * 0.38
  local dx, dy = mx - cx, my - cy
  return (dx * dx + dy * dy) <= (knobR * knobR)
end

--- Draw valve knob with handle indicator (on top of entity).
function Lever.drawKnob(entity, cx, cy, size, isActive)
  Lever.ensureAngle(entity)
  local r = size * 0.22
  local handleLen = size * 0.28

  -- Outer ring
  love.graphics.setColor(0.35, 0.38, 0.45, isActive and 1 or 0.85)
  love.graphics.circle("fill", cx, cy, r)
  love.graphics.setColor(0.55, 0.6, 0.7, isActive and 1 or 0.7)
  love.graphics.setLineWidth(isActive and 2.5 or 1.5)
  love.graphics.circle("line", cx, cy, r)

  -- Handle spoke (shows current angle)
  local hx = cx + math.cos(entity.visualAngle) * handleLen
  local hy = cy + math.sin(entity.visualAngle) * handleLen
  love.graphics.setColor(isActive and 1 or 0.85, isActive and 0.85 or 0.7, 0.4, 1)
  love.graphics.setLineWidth(isActive and 4 or 2.5)
  love.graphics.line(cx, cy, hx, hy)

  -- Grip notches (4 ticks at 90°)
  love.graphics.setColor(0.5, 0.55, 0.65, 0.6)
  for i = 0, 3 do
    local a = i * math.pi / 2
    local x1 = cx + math.cos(a) * (r + 2)
    local y1 = cy + math.sin(a) * (r + 2)
    local x2 = cx + math.cos(a) * (r + 6)
    local y2 = cy + math.sin(a) * (r + 6)
    love.graphics.line(x1, y1, x2, y2)
  end
end

return Lever
