# Battle Mode "Make It Cooler" Plan

Five phases, each shippable on its own. Ordered so every phase makes the
game feel different immediately, and later phases build on earlier ones.

## Phase 1 — Battlefield awareness  ✅ SHIPPED
The tension pass. Fog of war turns scouting, raids and map control into
real decisions; alerts make being attacked an *event*.
- **Fog of war**: per-player vision (units see ~9 tiles, turrets 10).
  Unexplored map is black shroud; explored terrain stays revealed but
  enemy UNITS are only visible inside your sight. Enemy structures and
  resource nodes are remembered once explored. Minimap respects fog.
  Full map reveals when the battle ends (or in free play). Setup screen
  toggle for players who want the old all-seeing view.
- **Alerts**: throttled "🚨 Base under attack!" / "⚔ Forces under attack"
  toasts + a red blinking minimap ping. **B** jumps the camera to the
  last alert, C&C style.

## Phase 2 — The Rimvale signature  ✅ SHIPPED
## Phase 3 (below) — ✅ SHIPPED
What no other RTS has: YOUR game inside the battles.
- **Story-party hero units**: bring campaign characters into a battle as
  unique heroes with their real stats, feats, gear and crafted spells
  (handle-backed). Un-producible, one each, "retreat" instead of death
  so story mode is never at risk. Picked on the setup screen from the
  active save.
- **Region personalities**: per-region battlefield rules driven by the
  condition system — Peaks blizzards (periodic `slowed` bursts), Titan's
  Lament lava vents (area burn eruptions), Astral rifts (paired teleport
  tiles), Mirecoast spore fog (`fever` pockets). Region choice becomes a
  strategic pick.

## Phase 3 — A living map
Reasons to leave your base between fights.
- **Neutral kaiju event**: at ~8:00 a wild kaiju spawns mid-map and
  attacks everyone; the team that kills it earns a fat supply bounty.
- **Supply crates**: random drops — supply, a free unit, an instant
  heal, a temporary speed buff. Roaming scouts get paid.
- **Neutral tech buildings**: 1-2 derelict structures per map an
  Engineer can capture for passive perks (healing aura / +sight /
  +income). Engineers matter beyond base sniping.

## Phase 4 — Army depth
- **Stances**: guard (hold ground, never chase), patrol (loop between
  two points), return-fire-only. Pairs with the attack-mode system.
- **Walls & gates**: cheap buildable wall segments for real base design.
- **AI personalities**: each AI team rolls Rusher / Turtler / Boomer at
  start (wave timing, structure priorities, taunts in the battle log).

## Phase 5 — The wrapper
- ✅ **Score screen**: post-battle stats — kills, supply mined, biggest
  blast, MVP veteran — plus a Rematch button.
- ✅ **Region conquest campaign**: a world map (`scenes/battle/conquest_map`)
  driven by the `Conquest` autoload; win skirmishes to claim all 10 regions
  with escalating difficulty (easy→last stand); persistent progress in
  `user://conquest.save`; triumph screen on 10/10. Title screen → 🗺 Conquest.
- ✅ **Sound pass**: sim events drive the existing `AudioManager` — hit
  thuds / bow pierces (distance-inferred), spell whooshes by element, death
  thuds, strike & kaiju booms, capture/promote stings, EVA-style alert
  klaxons, a looping `music_combat` theme, and a 🔊/🔇 battle mute toggle.
  All loads guarded; audio can never crash a battle.

Phase 5 complete. ✅

## Order of work
P1 (shipped) → P2 hero units → P2 region rules → P3 → P5 score screen →
P4 → P5 campaign → P5 sound. The score screen jumps the queue because it
is cheap and makes every test battle satisfying to finish.
