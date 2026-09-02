# Prism Echo

A 2D light-redirection puzzle game built with [LÖVE (Love2D) 11.4+](https://love2d.org/) and Lua. Rotate mirrors, split beams through prisms, combine colors, and guide light to color-matched receivers.

## How to Run

1. Install LÖVE 11.4 or later from [love2d.org](https://love2d.org/).
2. From the project root, run:

```bash
love .
```

Alternatively, drag the project folder onto the LÖVE executable.

## Controls

| Input | Action |
|-------|--------|
| Left-click on entity | Rotate 90° clockwise |
| Left-click-drag from inventory | Place entity on grid |
| R | Restart current level |
| ESC | Return to level select |

## Project Structure

```
Prism Echo/
├── main.lua        — Love2D entry point, game state machine
├── grid.lua        — Grid layout, coordinate conversion, cell storage
├── entities.lua    — Entity types and beam-interaction behavior
├── raytracer.lua   — Beam simulation and glow rendering
├── level.lua       — Level loading, reset, inventory management
├── ui.lua          — Menus, HUD, solved animation
├── levels/         — Level definition files (level1.lua … level5.lua)
├── assets/         — Placeholder for future fonts, sounds, sprites
└── README.md
```

## Adding a New Level

Create a file `levels/levelN.lua` that returns a Lua table:

```lua
return {
  name = "My Level",
  cols = 12,          -- grid width
  rows = 9,           -- grid height

  emitters = {
    { x = 1, y = 5, direction = "right", color = "white" },
  },

  receivers = {
    { x = 10, y = 3, color = "red" },
  },

  entities = {
    { type = "mirror", x = 5, y = 5, rotation = 0, rotatable = true },
    { type = "wall",   x = 7, y = 4, fixed = true },
  },

  -- Optional: limited placement inventory
  inventory = {
    mirror = 2,
    prism  = 1,
  },
}
```

**Directions:** `"up"`, `"right"`, `"down"`, `"left"`

**Colors:** `"white"`, `"red"`, `"green"`, `"blue"`, `"yellow"`, `"magenta"`, `"cyan"`

**Entity types:** `mirror`, `auto_mirror`, `prism`, `combiner`, `crystal`, `wall`

## Adding a New Entity Type

1. In `entities.lua`, create a factory function (e.g. `Entities.createMyEntity(opts)`).
2. Implement two methods on the entity table:
   - `onBeamEnter(self, entryDir, color)` → list of `{ dir, color }` outgoing beams, or `nil` to absorb.
   - `draw(self, cx, cy, size)` → render the entity icon.
3. Register the type in the `Entities.create()` factory dispatch table.
4. Optionally add it to the inventory palette in `ui.lua`.

Direction indices: 1 = up, 2 = right, 3 = down, 4 = left.

## License

See [LICENSE](LICENSE).
