--[[
  main.lua — Love2D entry point for Prism Echo.

  Manages top-level game state (menu, playing, level-complete) and delegates
  rendering, input, and simulation to the appropriate modules.
]]

local Grid = require("grid")
local Entities = require("entities")
local Raytracer = require("raytracer")
local Level = require("level")
local UI = require("ui")
local Lever = require("lever")
local LevelGen = require("levelgen")
local Storage = require("storage")

-- ── Game state ────────────────────────────────────────────────────────────────

local ui
local currentLevel
local beamSegments = {}
local allSatisfied = false
local satisfiedHoldTimer = 0
local SATISFIED_HOLD_TIME = 0.15

-- Lever drag state: { entity, cx, cy }
local leverDrag = nil

function love.load()
  love.window.setTitle("Prism Echo")
  love.window.setMode(960, 640, { resizable = true, minwidth = 640, minheight = 480 })
  love.graphics.setBackgroundColor(0.08, 0.08, 0.09)

  Storage.init()
  ui = UI.new()
  ui:load()
  ui:resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.update(dt)
  ui:update(dt)

  if ui.state ~= "playing" and ui.state ~= "solved" then return end
  if not currentLevel then return end

  Entities.updateAll(currentLevel.grid, dt)

  local gridSegments
  gridSegments, allSatisfied = Raytracer.trace(
    currentLevel.grid, currentLevel.emitters
  )
  beamSegments = Raytracer.toScreenSegments(currentLevel.grid, gridSegments)

  if allSatisfied and ui.state == "playing" then
    satisfiedHoldTimer = satisfiedHoldTimer + dt
    if satisfiedHoldTimer >= SATISFIED_HOLD_TIME then
      ui:triggerSolved()
      if currentLevel.isGenerated and currentLevel.generatedId then
        Storage.markCompleted(currentLevel.generatedId)
      end
    end
  else
    satisfiedHoldTimer = 0
  end
end

function love.draw()
  love.graphics.clear(0.08, 0.08, 0.09)

  if ui.state == "menu" then
    ui:drawMenu(Level.count(), Storage.loadIndex())
    return
  end

  if not currentLevel then return end

  local grid = currentLevel.grid
  grid:resize(love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight)

  local w, h = love.graphics.getWidth(), love.graphics.getHeight() - ui.hudHeight
  love.graphics.setColor(0.06, 0.06, 0.08)
  love.graphics.rectangle("fill", 0, 0, w, h * 0.5)
  love.graphics.setColor(0.1, 0.08, 0.12)
  love.graphics.rectangle("fill", 0, h * 0.5, w, h * 0.5)

  grid:drawGridLines()
  Entities.drawAll(grid)
  Entities.drawSpecial(grid, currentLevel.emitters)
  Entities.drawSpecial(grid, currentLevel.receivers)

  -- Lever knobs on rotatable entities
  local activeEntity = leverDrag and leverDrag.entity or nil
  Entities.drawLevers(grid, activeEntity)

  Raytracer.drawBeams(beamSegments)

  if ui.dragging then
    ui:drawDragGhost(ui.dragging.type, grid)
  end

  ui:drawHUD(currentLevel, grid)
  ui:drawSolvedOverlay()
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end

  if ui.state == "menu" then
    local action, arg = ui:handleMenuClick(Level.count(), Storage.loadIndex())
    if action == "level" then
      startLevel(arg)
    elseif action == "generate" then
      startGeneratedLevel(arg) -- arg = difficulty
    elseif action == "saved" then
      startSavedLevel(arg) -- arg = id
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

  local hudAction = ui:handleHUDClick()
  if hudAction == "restart" then
    restartLevel()
    return
  elseif hudAction == "menu" then
    ui.state = "menu"
    currentLevel = nil
    return
  elseif hudAction == "save" then
    saveCurrentLevel()
    return
  end

  local grid = currentLevel.grid
  grid:resize(love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight)

  local invType = ui:getInventoryItemAt(currentLevel)
  if invType then
    ui.dragging = { type = invType, startX = x, startY = y }
    return
  end

  -- Grab lever knob on rotatable entity
  local entity, cx, cy = Entities.findKnobAt(grid, x, y)
  if entity then
    Lever.startDrag(entity, cx, cy, x, y)
    leverDrag = { entity = entity, cx = cx, cy = cy }
  end
end

function love.mousemoved(x, y, dx, dy)
  if not leverDrag or not currentLevel then return end
  local grid = currentLevel.grid
  grid:resize(love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight)
  Lever.updateDrag(leverDrag.entity, leverDrag.cx, leverDrag.cy, x, y)
end

function love.mousereleased(x, y, button)
  if button ~= 1 then return end

  if leverDrag then
    Lever.endDrag(leverDrag.entity)
    leverDrag = nil
    return
  end

  if not ui.dragging or not currentLevel then return end

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
      leverDrag = nil
    end
  elseif key == "r" and (ui.state == "playing" or ui.state == "solved") then
    restartLevel()
  elseif key == "g" and ui.state == "menu" then
    startGeneratedLevel(1 + math.floor(math.random() * 3))
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
  leverDrag = nil
end

function startGeneratedLevel(difficulty)
  local seed = os.time() + math.floor(love.timer.getTime() * 1000)
  local data = LevelGen.generate(seed, difficulty or 1)
  data.isGenerated = true
  local id = Storage.saveLevel(data, { difficulty = difficulty or 1 })
  data.generatedId = id
  currentLevel = Level.fromData(data, 0)
  currentLevel.grid:resize(
    love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight
  )
  ui.state = "playing"
  ui:resetSolved()
  satisfiedHoldTimer = 0
  beamSegments = {}
  leverDrag = nil
end

function startSavedLevel(id)
  currentLevel = Level.loadGenerated(id)
  if not currentLevel then return end
  currentLevel.grid:resize(
    love.graphics.getWidth(), love.graphics.getHeight(), ui.hudHeight
  )
  ui.state = "playing"
  ui:resetSolved()
  satisfiedHoldTimer = 0
  beamSegments = {}
  leverDrag = nil
end

function saveCurrentLevel()
  if not currentLevel then return end
  local data = Storage.exportFromLevel(currentLevel)
  data.seed = currentLevel.seed
  local id = Storage.saveLevel(data, {
    id = currentLevel.generatedId,
    difficulty = 1,
  })
  currentLevel.generatedId = id
  currentLevel.isGenerated = true
end

function restartLevel()
  if not currentLevel then return end
  currentLevel:reset()
  ui:resetSolved()
  satisfiedHoldTimer = 0
  leverDrag = nil
end
