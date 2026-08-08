# Prism Echo — Full Development Prompt (Love2D / Lua)

## Project Overview
Build a complete 2D puzzle game called **Prism Echo** using the **Love2D (LÖVE) framework, version 11.4 or later**, written entirely in **Lua**. The game is a light-redirection puzzle game: the player rotates optical elements on a grid to guide light beams from source emitters to color-matched receivers. The visual identity is minimal and moody — dark backgrounds with glowing, colorful light trails.

---

## Core Gameplay Mechanics

### Grid System
- The play area is a rectangular grid (default **12 columns × 9 rows**, configurable per level via level data).
- Each grid cell can hold at most one interactive entity.
- Grid cell size should scale to fit the window while preserving a square aspect ratio per cell, and re-scale correctly on window resize.

### Light Sources
- One or more **fixed emitter** entities sit on the edge of the grid (or a fixed interior cell) and continuously emit a light beam in a fixed initial direction (up/down/left/right) at a fixed color (default: white/full-spectrum).
- Emitters cannot be moved or rotated by the player.

### Interactive Entities (player-placed or pre-placed, rotatable)
1. **Mirror** — reflects an incoming beam at a 90° angle. Orientation determines which two of the four cell edges connect (e.g. `/` connects north↔east and south↔west; `\` connects north↔west and south↔east). Left-click rotates it 90° clockwise.
2. **Prism** — when struck by a white/full-spectrum beam, splits it into three separate beams: red, green, and blue, each exiting the prism in a distinct, deterministic direction relative to the prism's current rotation (define the exact exit-direction mapping in code and keep it consistent across rotations). A prism struck by an already-colored beam simply passes it through unchanged (does not re-split).
3. **Color Combiner** — a passive cell that, when two beams of different colors enter it from two different edges in the same tick, outputs a new beam whose color is the additive mix of the two inputs, following standard additive light mixing:
   - Red + Green = Yellow
   - Red + Blue = Magenta
   - Green + Blue = Cyan
   - Red + Green + Blue = White
   - If only one beam enters, it passes through unchanged in its original direction.
4. **Refractive Crystal** — bends an incoming beam by a partial angle (e.g. 30–45° instead of a full 90° reflection) rather than reflecting it. Implement this as a discrete direction change on the grid (since the grid is orthogonal, approximate refraction as an offset diagonal path segment, or as a deterministic bend to an adjacent diagonal-equivalent direction — document whichever approach you choose clearly in code comments).
5. **Wall / Obstacle** — a static, non-rotatable blocking cell. Any beam entering a wall cell is fully absorbed and stops.
6. **Auto-Rotating Mirror** — behaves like a Mirror but rotates automatically and continuously at a fixed, level-defined angular speed (e.g. 90° every N seconds), independent of player input. Used in advanced levels to require timing-based solutions.

### Receivers (goals)
- One or more **fixed receiver** entities, each requiring a **specific color** of light (red, green, blue, yellow, magenta, cyan, or white) to be considered "satisfied."
- A level is **solved** when all receivers on that level are simultaneously satisfied by beams of the correct color, for at least one full simulation tick (to avoid false positives from a single-frame flicker during recalculation).

### Beam Simulation / Ray-Tracing Logic
- On every relevant state change (entity placed, entity rotated, auto-rotating mirror's angle updates), fully recompute the beam paths from scratch using a deterministic ray-casting algorithm across the grid:
  1. Start from each emitter's origin cell and direction.
  2. Step cell-by-cell in the current direction.
  3. At each cell, apply that cell's entity behavior (empty = pass through, mirror = redirect, prism = split, combiner = merge-or-pass, crystal = bend, wall = absorb, receiver = check color match and terminate that beam's path, grid boundary = terminate).
  4. Support beam branching (e.g., from a prism or combiner) as multiple independent beam paths tracked simultaneously.
  5. Include a maximum step/recursion limit (e.g., 500 steps total across all beams) to guard against infinite loops (e.g., two mirrors facing each other in a closed loop).
- Recompute this simulation every frame (or only on state-change events, whichever you implement — but the result must always be accurate to the current entity configuration; no stale beam paths).

---

## Project Structure

Organize the code into clearly separated modules:

- **`main.lua`** — Love2D entry point (`love.load`, `love.update`, `love.draw`, `love.mousepressed`, `love.resize`, etc.). Handles top-level game state (menu, playing, level-complete) and delegates to the appropriate module.
- **`grid.lua`** — Grid data structure: dimensions, cell size, screen-to-grid and grid-to-screen coordinate conversion, and per-cell entity storage.
- **`entities.lua`** — Definitions and behavior for all entity types listed above (Mirror, Prism, Combiner, Crystal, Wall, AutoRotatingMirror, Emitter, Receiver), each as its own table/class with a consistent interface (e.g. `entity:onBeamEnter(direction, color)` returning the resulting outgoing beam(s), or nil if absorbed).
- **`raytracer.lua`** — The beam simulation engine described above: given the current grid state and list of emitters, returns a list of beam path segments (for rendering) and a table of receiver-satisfaction states (for win checking).
- **`level.lua`** — Level loading and parsing. Store level definitions as plain Lua tables (an array of level files under a `levels/` folder, each returning a table via `return {...}`) describing grid size, emitter positions/directions/colors, receiver positions/required colors, pre-placed entities (fixed or player-movable), and player inventory (which entity types/quantities the player has available to place, if applicable).
- **`ui.lua`** — HUD elements: level name/number display, a "Solved!" banner/animation trigger, a restart button, a level-select menu, and an inventory palette (if the level provides a limited set of placeable entities rather than pre-filled ones).

Include a **`levels/` folder** with at least **5 example levels** of increasing difficulty:
1. A single mirror redirecting a beam to one receiver.
2. Two mirrors forming an L-shaped or Z-shaped path.
3. A prism splitting white light, requiring one colored sub-beam to reach a receiver (other sub-beams may be discarded or must be blocked/wasted deliberately).
4. Two prisms plus a color combiner, requiring the player to produce a secondary color (e.g. yellow) to satisfy a receiver.
5. A level using at least one auto-rotating mirror, requiring the player to also route other beams so that satisfaction lines up with the rotating mirror's timing window.

---

## Visual Style & Rendering
- Background: minimal dark theme, base color approximately `#1a1a1a`–`#111111`, with a very faint grid overlay (thin lines at ~10% opacity) to indicate cell boundaries.
- Light beams: rendered as lines colored per their current light color, with a **layered glow effect** — draw the same beam segment 3–4 times with progressively larger line width and lower alpha underneath a thin, fully-opaque core line, to simulate bloom without needing shaders (though a simple shader-based bloom is a welcome enhancement if straightforward in Love2D).
- Entities: simple, clean vector-style icons (drawn with `love.graphics` primitives — no external art required, though the code should be structured so image-based sprites could be swapped in later).
- Receivers: should visually shift from a dim/unsatisfied state to a bright, filled/glowing state when correctly lit.
- Level-complete animation: when a level is solved, trigger a brief (1–2 second) full-screen light "burst" or bloom-intensity increase, plus a UI banner, before allowing the player to proceed to level select/next level.
- Optional ambient particle motes or a subtle background gradient for atmosphere — nice-to-have, not required for MVP.

---

## Input & Controls
- **Left-click** on a rotatable entity: rotate it 90° clockwise.
- **Left-click-drag** (if the level allows free placement from an inventory): drag entities from a palette UI onto empty grid cells; dragging off-grid or onto an occupied cell should cancel the placement.
- **R key** or an on-screen restart button: reset the current level to its initial state.
- **Escape key** or menu button: return to level select.

---

## Technical Requirements
- Use **Love2D 11.4+** APIs only (no external Lua libraries beyond what ships with LÖVE, unless explicitly justified).
- Code must be **thoroughly commented**, explaining the purpose of each module, function, and any non-obvious logic (especially the ray-tracing direction/rotation math).
- Structure the code to be **easily extensible**: adding a new entity type, a new level, or a new light color should not require rewriting core systems.
- Handle **window resizing** gracefully — grid and UI should reflow/rescale rather than clip or distort.
- Target **60 FPS**, with the ray-tracing recalculation optimized enough not to cause frame drops on grids up to at least 20×15.
- No crashes on edge cases: overlapping beams, beams exiting the grid boundary, entities being rotated mid-simulation, or infinite reflection loops (must be caught by the step limit).

---

## Deliverables
1. All Lua source files (`main.lua`, `grid.lua`, `entities.lua`, `raytracer.lua`, `level.lua`, `ui.lua`) plus the `levels/` folder with 5 level files.
2. A short `README.md` explaining:
   - How to run the game (`love .` from the project root, or how to package it).
   - The project's folder structure.
   - How to add a new level (data format explanation).
   - How to add a new entity type (interface explanation).
3. An `assets/` folder placeholder (even if empty or containing only a `.gitkeep`) for future fonts/sound, with the code structured so audio and image assets can be dropped in later without refactoring.

---

## Out of Scope (for this initial build — do not implement unless asked)
- Sound effects or music.
- Save/progress persistence across sessions.
- Level editor UI.
- Mobile touch input handling.
- Multiplayer or networking of any kind.
