--[[ Level 5: Timing Gate
  An auto-rotating mirror cycles every 2 seconds.
  Route a white beam through the mirror to hit the receiver during the correct window.
  A second fixed mirror helps aim the beam.
]]

return {
  name = "Timing Gate",
  cols = 12,
  rows = 9,

  emitters = {
    { x = 1, y = 5, direction = "right", color = "white" },
  },

  receivers = {
    { x = 10, y = 2, color = "white" },
  },

  entities = {
    { type = "mirror",      x = 3, y = 5, rotation = 0, rotatable = true },
    { type = "auto_mirror", x = 6, y = 5, rotation = 0, rotateInterval = 2.0 },
    { type = "mirror",      x = 6, y = 2, rotation = 0, rotatable = true },
    { type = "wall",        x = 8, y = 4, fixed = true },
    { type = "wall",        x = 8, y = 5, fixed = true },
    { type = "wall",        x = 8, y = 6, fixed = true },
  },
}
