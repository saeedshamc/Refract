--[[ Level 1: First Reflection
  A single mirror redirecting a white beam to a white receiver.
  Rotate the mirror to bounce the light into the goal.
]]

return {
  name = "First Reflection",
  cols = 10,
  rows = 7,

  emitters = {
    { x = 1, y = 4, direction = "right", color = "white" },
  },

  receivers = {
    { x = 8, y = 2, color = "white" },
  },

  entities = {
    { type = "mirror", x = 4, y = 4, rotation = 0, rotatable = true },
  },
}
