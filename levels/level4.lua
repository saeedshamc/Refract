--[[ Level 4: Color Fusion
  Two prisms split light; a combiner merges red + green into yellow.
  Route yellow light to the yellow receiver.
]]

return {
  name = "Color Fusion",
  cols = 14,
  rows = 9,

  emitters = {
    { x = 1, y = 3, direction = "right", color = "white" },
    { x = 1, y = 7, direction = "right", color = "white" },
  },

  receivers = {
    { x = 12, y = 5, color = "yellow" },
  },

  entities = {
    { type = "prism",    x = 4, y = 3, rotation = 0, rotatable = true },
    { type = "prism",    x = 4, y = 7, rotation = 0, rotatable = true },
    { type = "mirror",   x = 7, y = 3, rotation = 0, rotatable = true },
    { type = "mirror",   x = 7, y = 7, rotation = 0, rotatable = true },
    { type = "combiner", x = 9, y = 5, fixed = true },
    { type = "mirror",   x = 11, y = 5, rotation = 0, rotatable = true },
    { type = "wall",     x = 6, y = 5, fixed = true },
  },
}
