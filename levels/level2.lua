--[[ Level 2: Double Bounce
  Two mirrors forming an L-shaped path to reach the receiver.
  Both mirrors must be rotated correctly.
]]

return {
  name = "Double Bounce",
  cols = 12,
  rows = 8,

  emitters = {
    { x = 1, y = 6, direction = "right", color = "white" },
  },

  receivers = {
    { x = 10, y = 2, color = "white" },
  },

  entities = {
    { type = "mirror", x = 4, y = 6, rotation = 0, rotatable = true },
    { type = "mirror", x = 4, y = 3, rotation = 0, rotatable = true },
    { type = "wall",   x = 7, y = 4, fixed = true },
    { type = "wall",   x = 7, y = 5, fixed = true },
  },
}
