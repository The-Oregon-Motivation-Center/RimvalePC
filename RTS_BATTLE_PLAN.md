# Battle Mode → Real-Time Strategy Conversion Plan

> **STATUS (July 2026): R1–R3 SHIPPED.** BattleSystem now runs a 10 Hz
> real-time sim (`_process` → `_sim_step`): cooldown movement/attacks (one
> attack per unit, C&C style), production queues with build times + rally
> points, spell loadouts where SP cost = cooldown in seconds (Arcane Spire),
> Barracks-gated weapon/class modification, timed AI/income/conditions.
> Battles launch into `scenes/battle/battle_rts.tscn` (persistent nodes,
> health bars, drag-select, right-click orders, attack-move, command card,
> production UI, minimap, victory modal). Remaining: R4 sound/edge polish,
> R5 balance pass.

Goal: true RTS mechanics (C&C: Yuri's Revenge vibe) — continuous time, no
turns, no phases, no AP. Units execute orders simultaneously while the player
commands anything at any moment.

## Why turn-based happened, and what real-time actually requires

The story engine resolves everything in player/enemy phases with AP budgets.
The first Battle Mode reused that clock. RTS needs a different clock — but
NOT a different game: combat math, map generation, entities, economy,
production, squads, orders, and AI logic all carry over. The conversion is
two rebuilds (clock + renderer) plus input polish, not a rewrite.

## What survives unchanged (already built & tested)

- Entity model (dicts with hp/ac/speed/weapon/battle_team/orders)
- Combat resolution: `_dung_do_attack` — per-hit math incl. conditions,
  crits, weapon damage parsing (this is why upgrades apply instantly)
- Team ring placement + lane/plaza carving + resource node logic (the map
  SOURCE changes to region-style terrain — see renderer section — but the
  placement/carving algorithms carry over)
- GMG NPC classes (Divine Champion … Storyteller) drive infantry builds
- Economy: supply, node depletion, exclusive mining, income telemetry
- Production: catalog, structures (Barracks/War Factory), vehicles, costs
- Orders: order_dest / order_target fields + squads (1-4 control groups)
- AI decision logic: target/march/mine/produce/build (needs re-scheduling only)
- Team colors, victory logic, setup screen, session isolation

## What gets rebuilt

### 1. The clock — `BattleSystem.tick(delta)` (replaces phases)
- Fixed-timestep simulation: accumulate `delta`, step the sim at 10 Hz.
- Per sim-step,每 unit acts independently on cooldowns:
  - `move_cd`: unit advances 1 tile along its path every `1.0 / speed_tps`
    seconds (speed_tps ≈ speed stat × 0.6 tiles/sec)
  - `attack_cd`: when target in range and cooldown elapsed → one
    `_dung_do_attack` → cooldown = attack_interval (1.2-2.0 s by unit;
    superweapons hit harder AND faster instead of multi-swing)
- Pathing: engine `_crawl_pathfind(fx, fy, tx, ty)` (already exists!);
  cache path per unit, re-path when blocked or every 2 s.
- Conditions: `_dung_tick_conditions(ent)` every 3 s ≈ one old "round"
  (burn/bleed/stun durations keep their balance).
- Economy: income tick every 5 s (same amounts as per-round today).
- Production: build QUEUES with real build times (mob 4 s → kaiju 45 s);
  supply deducted on queue, unit spawns at rally point when timer completes.
- AI: each AI team "thinks" every 2 s (staggered) running the existing
  decision logic. No AP, no phases, no player queue.
- Victory: checked on elimination events. Sudden death → timed (8 min).
- Pause (Space) and game speed (1x/2x) = trivial with a tick multiplier.

### 2. The renderer — new `scenes/battle/battle_rts.tscn` (replaces dungeon.tscn for battles)

**Map direction (per Blaine): battles happen on REGION-STYLE maps, not
dungeon caves.** The battlefield uses the explore renderer's visual
language, not the dungeon's:
- Terrain: the region-map look — outskirts-style ground tiles with rolling
  `_terrain_height_at` hills flattened in build zones, trees/rocks/grass
  props, region palette + daylight lighting (each of the 10 regions keeps
  its distinct look: Plains grassland, Peaks snow, Shadows gloom...).
- Structures render like region-map BUILDINGS: the Command Post, Barracks
  and War Factory are drawn with the explore facade language — wall-block
  bodies, roofs, doors, lit windows, floating name signs (reuse the city
  builder code from explore.gd, tinted with the owner's team color).
- Resource nodes become region-styled deposits (crystal/ore piles with the
  glint light) instead of dungeon chests.
- Map source: generate from the same wilderness generator the region
  outskirts use (open terrain + scattered obstacles), NOT the dungeon room
  generator — open fields with chokepoints suit RTS armies; lanes/plaza
  carving carries over as road carving (explore road tiles).

The dungeon scene rebuilds meshes every refresh — fine per-turn, fatal at
60fps. The RTS scene keeps ONE persistent node per entity:
- Spawn: create sprite/vehicle model once (reuse CharacterModelBuilder +
  team tint). Death: swap to corpse marker, fade.
- Every frame: lerp node position toward tile position (smooth motion from
  a 10 Hz sim), update health bar (billboard above unit), selection rings.
- Camera: classic RTS — WASD/edge pan, scroll zoom, no rotation by default.
- Map mesh: build once at load (50×50 static, no per-frame cost); fog as a
  darkening overlay updated on a 2 Hz timer from per-team vision.
- HUD: top bar (supply, +rate, teams alive), bottom command card (selected
  units, production queue with progress bars), battle log ticker, minimap
  (team-colored dots + camera rect + click-to-jump) — minimap becomes
  essential in real-time and is part of this phase.

### 3. Input — RTS grammar
- Left-click select · left-drag box multi-select · Shift-click add
- Right-click context order: ground = move, enemy = attack, node = mine
- A + click = attack-move (engage anything en route) — the C&C staple
- Ctrl+1..4 assign / 1..4 recall control groups (logic already exists)
- Double-tap group key = center camera on group
- Structure selected: set rally point with right-click; production buttons
  queue units (queue shown with progress + cancel)

## Phases

| Phase | Deliverable | Success test |
|---|---|---|
| R1 | Tick engine in BattleSystem (sim loop, cooldowns, paths, queues, timed AI/economy) driven headless by dungeon scene temporarily | Units auto-fight in real time with existing UI watching |
| R2 | battle_rts.tscn renderer (persistent nodes, health bars, RTS camera, static map, fog overlay) | Full battle watchable at 60 fps, 100+ units |
| R3 | Input grammar (drag-select, right-click orders, attack-move, rally, queue UI) | Playable end-to-end without keyboard help text |
| R4 | Minimap + polish (pause/speed, edge pan, sounds, hit flashes) + retire dungeon.tscn battle hooks | Feels like an RTS |
| R5 | Balance pass: DPS-based costs, build times, AI difficulty tiers | 1v3 comeback is possible; kaiju feels worth 600⛃ |

## Risks
1. **Renderer perf** — mitigated by persistent nodes + static map + capped
   simultaneous battles (10 teams × ~20 units is the design ceiling).
2. **Pathfinding load** — path caching + 2 s re-path + lanes already carved.
3. **Engine coupling** — `_dung_do_attack` mutates shared state safely
   (single-threaded tick), but conditions arrays must only tick on the 3 s
   timer or DoTs melt everything; guarded in R1.

## Kept for later rounds
Mind control (charm + battle_team flip), Engineer base capture, superweapon
strikes on cooldown, defense turrets, unit veterancy from kills — all layer
cleanly on the tick engine once R1-R3 land.
