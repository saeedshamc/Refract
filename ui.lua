--[[
  ui.lua — HUD, menus, and UI rendering for Prism Echo.

  Handles level select menu, in-game HUD (level name, restart, inventory palette),
  solved banner, and level-complete burst animation.
]]

local Entities = require("entities")

local UI = {}
UI.__index = UI

local SOLVED_ADVANCE_DELAY = 1.2

function UI.new()
  local self = setmetatable({}, UI)
  self.state = "menu" -- "menu", "playing", "solved"
  self.selectedLevel = 1
  self.hudHeight = 80
  self.font = nil
  self.titleFont = nil
  self.solvedTimer = 0
  self.burstAlpha = 0
  self.dragging = nil -- { type, startX, startY }
  return self
end

function UI:load()
  self.font = love.graphics.newFont(16)
  self.titleFont = love.graphics.newFont(32)
  self.smallFont = love.graphics.newFont(13)
  love.graphics.setFont(self.font)
end

function UI:resize(w, h)
  self.windowW = w
  self.windowH = h
end

--- Draw the main level-select menu.
function UI:drawMenu(levelCount, savedIndex)
  savedIndex = savedIndex or { levels = {} }
  love.graphics.setColor(0.07, 0.07, 0.07)
  love.graphics.rectangle("fill", 0, 0, self.windowW, self.windowH)

  love.graphics.setFont(self.titleFont)
  love.graphics.setColor(0.9, 0.95, 1.0)
  local title = "Prism Echo"
  local tw = self.titleFont:getWidth(title)
  love.graphics.print(title, (self.windowW - tw) / 2, self.windowH * 0.08)

  love.graphics.setFont(self.font)
  love.graphics.setColor(0.6, 0.65, 0.75)
  local sub = "Drag levers to redirect light  |  G = new random level"
  local sw = self.font:getWidth(sub)
  love.graphics.print(sub, (self.windowW - sw) / 2, self.windowH * 0.08 + 42)

  -- Two columns: built-in levels (left) and generated (right)
  local leftX = self.windowW * 0.12
  local rightX = self.windowW * 0.55
  local btnW, btnH = 200, 40

  love.graphics.setColor(0.5, 0.6, 0.8, 0.8)
  love.graphics.setFont(self.smallFont)
  love.graphics.print("Campaign Levels", leftX, self.windowH * 0.22)

  local startY = self.windowH * 0.28
  for i = 1, levelCount do
    local by = startY + (i - 1) * (btnH + 10)
    self:drawMenuButton(leftX, by, btnW, btnH, "Level " .. i, "level_" .. i)
  end

  -- Generate buttons
  love.graphics.setColor(0.5, 0.8, 0.6, 0.8)
  love.graphics.print("Generate New", rightX, self.windowH * 0.22)

  local diffs = { "Easy", "Medium", "Hard" }
  for i, label in ipairs(diffs) do
    local by = startY + (i - 1) * (btnH + 10)
    self:drawMenuButton(rightX, by, btnW, btnH, label, "gen_" .. i)
  end

  -- Saved generated levels
  local saved = savedIndex.levels or {}
  if #saved > 0 then
    love.graphics.setColor(0.8, 0.7, 0.5, 0.8)
    love.graphics.print("Saved Levels", rightX, startY + 3 * (btnH + 10) + 10)
    local sy = startY + 3 * (btnH + 10) + 30
    for i, entry in ipairs(saved) do
      if i > 4 then break end -- show max 4
      local by = sy + (i - 1) * (btnH + 8)
      local label = entry.name .. (entry.completed and " ✓" or "")
      self:drawMenuButton(rightX, by, btnW, btnH, label, "saved_" .. entry.id)
    end
  end

  love.graphics.setFont(self.smallFont)
  love.graphics.setColor(0.4, 0.45, 0.55)
  local hint = "Grab the valve knob and rotate with mouse to aim light"
  love.graphics.print(hint, (self.windowW - self.smallFont:getWidth(hint)) / 2, self.windowH - 30)
end

function UI:drawMenuButton(bx, by, btnW, btnH, label, _)
  local hovered = self:isMouseOver(bx, by, btnW, btnH)
  if hovered then
    love.graphics.setColor(0.25, 0.35, 0.55, 0.9)
  else
    love.graphics.setColor(0.15, 0.18, 0.28, 0.9)
  end
  love.graphics.rectangle("fill", bx, by, btnW, btnH, 6, 6)
  love.graphics.setColor(0.7, 0.8, 1.0, hovered and 1 or 0.7)
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", bx, by, btnW, btnH, 6, 6)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.setFont(self.font)
  love.graphics.print(label, bx + (btnW - self.font:getWidth(label)) / 2, by + 10)
end

--- Draw in-game HUD bar at the bottom.
function UI:drawHUD(level, grid)
  local hudY = self.windowH - self.hudHeight
  love.graphics.setColor(0.1, 0.1, 0.12, 0.95)
  love.graphics.rectangle("fill", 0, hudY, self.windowW, self.hudHeight)

  love.graphics.setFont(self.font)
  love.graphics.setColor(0.85, 0.9, 1.0)
  love.graphics.print(level.name, 16, hudY + 12)

  -- Button layout (right to left): Restart | Save | Menu
  local rbW, rbH = 90, 32
  local rby = hudY + (self.hudHeight - rbH) / 2
  local rbx = self.windowW - rbW - 16

  local rbHover = self:isMouseOver(rbx, rby, rbW, rbH)
  love.graphics.setColor(rbHover and 0.35 or 0.22, rbHover and 0.25 or 0.18, 0.18, 0.9)
  love.graphics.rectangle("fill", rbx, rby, rbW, rbH, 4, 4)
  love.graphics.setColor(1, 0.7, 0.6, 0.9)
  love.graphics.rectangle("line", rbx, rby, rbW, rbH, 4, 4)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.setFont(self.smallFont)
  love.graphics.print("Restart (R)", rbx + 8, rby + 9)

  local sbW = 70
  local sbx = rbx - sbW - 10
  local sbHover = self:isMouseOver(sbx, rby, sbW, rbH)
  love.graphics.setColor(sbHover and 0.2 or 0.15, sbHover and 0.35 or 0.28, 0.2, 0.9)
  love.graphics.rectangle("fill", sbx, rby, sbW, rbH, 4, 4)
  love.graphics.setColor(0.5, 1, 0.6, 0.8)
  love.graphics.rectangle("line", sbx, rby, sbW, rbH, 4, 4)
  love.graphics.setColor(1, 1, 1, 0.85)
  love.graphics.print("Save", sbx + 16, rby + 9)

  local mbW = 80
  local mbx = sbx - mbW - 10
  local mbHover = self:isMouseOver(mbx, rby, mbW, rbH)
  love.graphics.setColor(mbHover and 0.25 or 0.18, mbHover and 0.28 or 0.2, 0.35, 0.9)
  love.graphics.rectangle("fill", mbx, rby, mbW, rbH, 4, 4)
  love.graphics.setColor(0.7, 0.8, 1, 0.8)
  love.graphics.rectangle("line", mbx, rby, mbW, rbH, 4, 4)
  love.graphics.setColor(1, 1, 1, 0.85)
  love.graphics.print("Menu (ESC)", mbx + 6, rby + 9)

  -- Inventory palette
  self:drawInventory(level, hudY)
end

--- Draw inventory palette icons.
function UI:drawInventory(level, hudY)
  local hasInventory = false
  for _, count in pairs(level.inventory) do
    if count > 0 then hasInventory = true; break end
  end
  if not hasInventory then return end

  local types = { "mirror", "prism", "combiner", "crystal" }
  local startX = 200
  local iconSize = 36
  local iy = hudY + (self.hudHeight - iconSize) / 2

  love.graphics.setFont(self.smallFont)
  love.graphics.setColor(0.5, 0.55, 0.65)
  love.graphics.print("Inventory:", startX - 80, iy + 10)

  for i, etype in ipairs(types) do
    local count = level.inventory[etype] or 0
    if count > 0 or (level.placedInventory[etype] or 0) > 0 then
      local ix = startX + (i - 1) * (iconSize + 16)
      local hover = self:isMouseOver(ix, iy, iconSize, iconSize)
      love.graphics.setColor(hover and 0.25 or 0.15, hover and 0.3 or 0.18, 0.35, 0.8)
      love.graphics.rectangle("fill", ix, iy, iconSize, iconSize, 4, 4)
      love.graphics.setColor(0.6, 0.7, 0.9, 0.7)
      love.graphics.rectangle("line", ix, iy, iconSize, iconSize, 4, 4)

      -- Draw mini entity icon
      local entity = Entities.create(etype, {})
      if entity.draw then
        entity:draw(ix + iconSize / 2, iy + iconSize / 2, iconSize)
      end

      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.print(tostring(count), ix + iconSize - 12, iy + iconSize - 14)
    end
  end
end

--- Draw "Solved!" banner and burst overlay.
function UI:drawSolvedOverlay()
  if self.state ~= "solved" then return end

  -- Full-screen light burst
  if self.burstAlpha > 0 then
    love.graphics.setColor(1, 1, 1, self.burstAlpha * 0.35)
    love.graphics.rectangle("fill", 0, 0, self.windowW, self.windowH)
  end

  -- Banner
  local bannerW, bannerH = 320, 70
  local bx = (self.windowW - bannerW) / 2
  local by = self.windowH * 0.35
  local scale = math.min(1.2, 1 + (1.5 - self.solvedTimer) * 0.15)

  love.graphics.push()
  love.graphics.translate(bx + bannerW / 2, by + bannerH / 2)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-(bx + bannerW / 2), -(by + bannerH / 2))

  love.graphics.setColor(0.1, 0.5, 0.3, 0.92)
  love.graphics.rectangle("fill", bx, by, bannerW, bannerH, 8, 8)
  love.graphics.setColor(0.4, 1, 0.6, 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bx, by, bannerW, bannerH, 8, 8)

  love.graphics.setFont(self.titleFont)
  love.graphics.setColor(0.5, 1, 0.7)
  local text = "Solved!"
  love.graphics.print(text, bx + (bannerW - self.titleFont:getWidth(text)) / 2, by + 16)
  love.graphics.pop()

  if self.solvedTimer < SOLVED_ADVANCE_DELAY then
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(1, 1, 1, 0.7)
    local hint = "Next level..."
    love.graphics.print(hint, (self.windowW - self.smallFont:getWidth(hint)) / 2, by + bannerH + 20)
  end
end

--- Update solved animation timers.
function UI:update(dt)
  if self.state == "solved" then
    self.solvedTimer = self.solvedTimer + dt
    if self.solvedTimer < 0.5 then
      self.burstAlpha = self.solvedTimer / 0.5
    else
      self.burstAlpha = math.max(0, 1.0 - (self.solvedTimer - 0.5) * 2)
    end
  end
end

function UI:triggerSolved()
  self.state = "solved"
  self.solvedTimer = 0
  self.burstAlpha = 0
end

function UI:resetSolved()
  self.state = "playing"
  self.solvedTimer = 0
  self.burstAlpha = 0
end

--- Check if mouse is over a rectangle.
function UI:isMouseOver(x, y, w, h)
  local mx, my = love.mouse.getPosition()
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

--- Handle menu click; returns action, arg.
function UI:handleMenuClick(levelCount, savedIndex)
  savedIndex = savedIndex or { levels = {} }
  local leftX = self.windowW * 0.12
  local rightX = self.windowW * 0.55
  local btnW, btnH = 200, 40
  local startY = self.windowH * 0.28

  -- Campaign levels
  for i = 1, levelCount do
    local by = startY + (i - 1) * (btnH + 10)
    if self:isMouseOver(leftX, by, btnW, btnH) then
      return "level", i
    end
  end

  -- Generate buttons
  for i = 1, 3 do
    local by = startY + (i - 1) * (btnH + 10)
    if self:isMouseOver(rightX, by, btnW, btnH) then
      return "generate", i
    end
  end

  -- Saved levels
  local saved = savedIndex.levels or {}
  local sy = startY + 3 * (btnH + 10) + 30
  for i, entry in ipairs(saved) do
    if i > 4 then break end
    local by = sy + (i - 1) * (btnH + 8)
    if self:isMouseOver(rightX, by, btnW, btnH) then
      return "saved", entry.id
    end
  end

  return nil
end

--- Handle HUD button clicks. Returns "restart", "menu", "save", or nil.
function UI:handleHUDClick()
  local hudY = self.windowH - self.hudHeight
  local rbW, rbH = 90, 32
  local rbx = self.windowW - rbW - 16
  local rby = hudY + (self.hudHeight - rbH) / 2

  if self:isMouseOver(rbx, rby, rbW, rbH) then return "restart" end

  local sbW = 70
  local sbx = rbx - sbW - 10
  if self:isMouseOver(sbx, rby, sbW, rbH) then return "save" end

  local mbW = 80
  local mbx = sbx - mbW - 10
  if self:isMouseOver(mbx, rby, mbW, rbH) then return "menu" end

  return nil
end

--- Get inventory item type under mouse, or nil.
function UI:getInventoryItemAt(level)
  local hudY = self.windowH - self.hudHeight
  local types = { "mirror", "prism", "combiner", "crystal" }
  local startX = 200
  local iconSize = 36
  local iy = hudY + (self.hudHeight - iconSize) / 2

  for i, etype in ipairs(types) do
    local count = level.inventory[etype] or 0
    if count > 0 then
      local ix = startX + (i - 1) * (iconSize + 16)
      if self:isMouseOver(ix, iy, iconSize, iconSize) then
        return etype
      end
    end
  end
  return nil
end

--- Draw dragging ghost entity at mouse position.
function UI:drawDragGhost(entityType, grid)
  if not self.dragging then return end
  local mx, my = love.mouse.getPosition()
  local entity = Entities.create(entityType, {})
  love.graphics.setColor(1, 1, 1, 0.5)
  if entity.draw then
    entity:draw(mx, my, grid.cellSize * 0.8)
  end
end

return UI
