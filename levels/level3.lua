--[[ Level 3: Prism Split
  A prism splits white light into R/G/B. Route the red beam to the red receiver.
  Other colored beams can be wasted or blocked by walls.
]]

return {
  name = "Prism Split",
  cols = 12,
  rows = 9,

  emitters = {
    { x = 1, y = 5, direction = "right", color = "white" },
  },

  receivers = {
    { x = 10, y = 3, color = "red" },
  },

  entities = {
    { type = "prism",  x = 5, y = 5, rotation = 0, rotatable = true },
    { type = "mirror", x = 8, y = 3, rotation = 0, rotatable = true },
    { type = "wall",   x = 8, y = 7, fixed = true },
    { type = "wall",   x = 9, y = 7, fixed = true },
    { type = "wall",   x = 5, y = 8, fixed = true },
  },
}
