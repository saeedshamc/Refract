--[[
  main.lua — Love2D entry point for Prism Echo.

  Manages top-level game states (menu, playing, solved) and delegates
  rendering, input, and simulation to the appropriate modules.
]]

local Grid = require("grid")
local Entities = require("entities")
local Raytracer = require("raytracer")
local Level = require("level")
local UI = require("ui")

-- ── Game state ────────────────────────────────────────────────────────────────

local ui
local currentLevel
local beamSegments = {}
local allSatisfied = false
local satisfiedHoldTimer = 0
local SATISFIED_HOLD_TIME = 0.15 -- require satisfaction for this many seconds

function love.load()
  love.window.setTitle("Prism Echo")
  love.window.setMode(960, 640, { resizable = true, minwidth = 640, minheight = 480 })
  love.graphics.setBackgroundColor(0.08, 0.08, 0.09)

  ui = UI.new()
  ui:load()
  ui:resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.update(dt)
  ui:update(dt)

  if ui.state ~= "playing" and ui.state ~= "solved" then return end
  if not currentLevel then return end

  -- Update auto-rotating mirrors
  Entities.updateAll(currentLevel.grid, dt)

  -- Recompute beam paths every frame
  local gridSegments
  gridSegments, allSatisfied = Raytracer.trace(
    currentLevel.grid, currentLevel.emitters
  )
  beamSegments = Raytracer.toScreenSegments(currentLevel.grid, gridSegments)

  -- Win detection: require sustained satisfaction to avoid flicker false positives
  if allSatisfied and ui.state == "playing" then
    satisfiedHoldTimer = satisfiedHoldTimer + dt
    if satisfiedHoldTimer >= SATISFIED_HOLD_TIME then
      ui:triggerSolved()
    end
  else
    satisfiedHoldTimer = 0
  end
end

function love.draw()
  love.graphics.clear(0.08, 0.08, 0.09)

  if ui.state == "menu" then
    ui:drawMenu(Level.count())
    return
  end

  if not currentLevel then return end

  local grid = currentLevel.grid
  grid:resize(love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight)

  -- Subtle background gradient
  local w, h = love.graphics.getWidth(), love.graphics.getHeight() - ui.hudHeight
  love.graphics.setColor(0.06, 0.06, 0.08)
  love.graphics.rectangle("fill", 0, 0, w, h * 0.5)
  love.graphics.setColor(0.1, 0.08, 0.12)
  love.graphics.rectangle("fill", 0, h * 0.5, w, h * 0.5)

  grid:drawGridLines()

  -- Draw entities (walls, mirrors, prisms, etc.)
  Entities.drawAll(grid)

  -- Draw emitters and receivers
  Entities.drawSpecial(grid, currentLevel.emitters)
  Entities.drawSpecial(grid, currentLevel.receivers)

  -- Draw light beams with glow
  Raytracer.drawBeams(beamSegments)

  -- Drag ghost
  if ui.dragging then
    ui:drawDragGhost(ui.dragging.type, grid)
  end

  ui:drawHUD(currentLevel, grid)
  ui:drawSolvedOverlay()
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end

  if ui.state == "menu" then
    local selected = ui:handleMenuClick(Level.count())
    if selected then
      startLevel(selected)
    end
    return
  end

  if ui.state == "solved" then
    if ui.solvedTimer >= 0.5 then
      ui.state = "menu"
      ui:resetSolved()
      currentLevel = nil
    end
    return
  end

  if not currentLevel then return end

  -- HUD buttons
  local hudAction = ui:handleHUDClick()
  if hudAction == "restart" then
    restartLevel()
    return
  elseif hudAction == "menu" then
    ui.state = "menu"
    currentLevel = nil
    return
  end

  local grid = currentLevel.grid
  grid:resize(love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight)

  -- Inventory drag start
  local invType = ui:getInventoryItemAt(currentLevel)
  if invType then
    ui.dragging = { type = invType, startX = x, startY = y }
    return
  end

  -- Rotate entity on click
  local gx, gy = grid:screenToGrid(x, y)
  if gx and gy then
    local entity = grid:getEntity(gx, gy)
    if entity and entity.rotatable then
      Entities.rotate(entity)
    end
  end
end

function love.mousereleased(x, y, button)
  if button ~= 1 or not ui.dragging or not currentLevel then return end

  local grid = currentLevel.grid
  grid:resize(love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight)
  local gx, gy = grid:screenToGrid(x, y)

  if gx and gy and not grid:getEntity(gx, gy) then
    currentLevel:placeFromInventory(ui.dragging.type, gx, gy)
  end

  ui.dragging = nil
end

function love.keypressed(key)
  if key == "escape" then
    if ui.state == "playing" or ui.state == "solved" then
      ui.state = "menu"
      ui:resetSolved()
      currentLevel = nil
    end
  elseif key == "r" and (ui.state == "playing" or ui.state == "solved") then
    restartLevel()
  end
end

function love.resize(w, h)
  ui:resize(w, h)
  if currentLevel then
    currentLevel.grid:resize(w, h, ui.hudHeight)
  end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

function startLevel(index)
  currentLevel = Level.load(index)
  currentLevel.grid:resize(
    love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight
  )
  ui.state = "playing"
  ui:resetSolved()
  satisfiedHoldTimer = 0
  beamSegments = {}
end

function restartLevel()
  if not currentLevel then return end
  currentLevel:reset()
  ui:resetSolved()
  satisfiedHoldTimer = 0
end
