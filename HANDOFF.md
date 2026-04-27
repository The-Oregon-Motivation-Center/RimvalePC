# Rimvale — Session Handoff

Persistent notes for Claude sessions working on this project. Save edits here (not to scratch directories) so the next session can read them. Last updated: 2026-04-23 (post-popup session).

## Project snapshot

- Engine: Godot 4.6, Vulkan/Forward+.
- GDExtension C++ lib under `gdextension/` (see `BUILD_INSTRUCTIONS.md`, `nuclear_rebuild.bat`).
- Main scenes: `scenes/world/world.gd` (city/hub UI, ~6800 lines), `scenes/explore/explore.gd` (region map + POIs, ~5000 lines).
- Autoloads: `autoload/game_state.gd`, `autoload/world_systems.gd`, `autoload/rimvale_fallback_engine.gd`.
- POI constants live at the top of `explore.gd`: `POI_ACF=0`, `POI_REST=2`, `POI_BLACKSMITH=5`, `POI_TOWN_HALL=10`, etc.
- Panel entry points in explore.gd: `_show_acf_panel`, `_show_rest_panel`, `_show_blacksmith_panel`, `_show_town_hall_panel` — they render into `_info_vbox`.

## Build health (as of last session)

- 60 FPS, 162 MB memory, ~1869 nodes stable, zero node-leak growth.
- Debugger-tab counter spam is Godot internal Vulkan/shader noise — not from our code.
- Debug monitor writes `user://debug_report.txt` on F11 (Windows: `%APPDATA%/Godot/app_userdata/Rimvale/`).

## Pending features

### 1. POI Activity Popups — IMPLEMENTED (unverified in-game)

All four popups shipped as standalone `AcceptDialog` scenes under `scenes/popups/`. Each one `queue_free`s itself on hide. `world.gd`'s tab builders were NOT touched — zero regression risk on existing hub UI.

| POI | Button | Popup | Notes |
|-----|--------|-------|-------|
| POI_BLACKSMITH | "🔨 Crafting…" | `scenes/popups/crafting_popup.gd` | Full port: crafter picker, recipe dropdown + recipe detail, Start, active-tasks list, repair list (equipped + stash). |
| POI_ACF       | "🌿 Outpost (Foraging)…" | `scenes/popups/foraging_popup.gd` | Full port: hunting/fishing/mining/gathering type selector, character dropdown, Start, active tasks. |
| POI_ACF, POI_REST | "✨ Arcane Rituals…" | `scenes/popups/rituals_popup.gd` | **Compromise:** shows in-progress rituals + learned ritual spell cards. The 700-line spell-builder overlay was NOT duplicated; popup has an "Open Full Ritual Builder…" button that jumps to the World tab (idx 1) where it lives. |
| POI_TOWN_HALL | "🏛 Base Management…" | `scenes/popups/base_popup.gd` | **Compromise:** shows base tier / facilities / supplies / defense / morale / upgrade hint at a glance; full facilities + allies management stays in the world tab, reached via "Open Full Base Management…". |

Why the compromises: the tab builders in `world.gd` mutate ~20 class-level state vars (`_ritual_overlay`, `_ritual_inner`, `_rb_*` constants, etc.) and call dozens of helper funcs. Duplicating the full spell-builder or facilities/allies UI into popups would create ~2000 lines of parallel code that drifts the moment `world.gd` changes. The view-and-jump pattern gives players instant visibility in the region while keeping one source of truth for editing.

**Open follow-ups on this feature:**
- Verify in-game: launch, walk to a Blacksmith / ACF HQ / Rest House / Town Hall POI, click each new button, confirm no orphan leak after closing (use the existing debug monitor / F11 report).
- "Buy a base in this town" from the original plan implies **multi-region bases**, but `GameState` currently models a single base (one `base_tier`, one `base_facilities` array). Real implementation requires a schema change (e.g. `GameState.bases: Dictionary[region_key] -> base_dict`) and a UI for selecting which base is "active". Deferred — discuss with Blaine before starting.
- If the ritual view's compromise feels too thin, next step is extracting the spell-builder into a reusable scene (`scenes/popups/ritual_builder.tscn`) and refactoring `world.gd` to instantiate it too — avoids drift.

### 1a. Wiring touchpoints in explore.gd

- `_show_blacksmith_panel` — added "🔨 Crafting…" button after Reinforce Armour.
- `_show_acf_panel` — added "✨ Arcane Center (Rituals)…" and "🌿 Outpost (Foraging)…" after intel button.
- `_show_rest_panel` — added "✨ Arcane Rituals…" after Save Game.
- `_show_town_hall_panel` — added "🏛 Base Management…" above AVAILABLE RITES.
- New section "POI Activity Popups" (after blacksmith panel) holds `_show_crafting_popup`, `_show_foraging_popup`, `_show_rituals_popup`, `_show_base_popup`.

### 2. Regional NPCs — P1 plumbing SHIPPED, content in-progress

System design: see `REGIONAL_NPCS_DESIGN.md`. Target = **184 NPCs across 28 subregion maps**, population-tiered (Metropolitan = 10 each, Glass Passage = 5 each, mid-tier between).

**What's built (P1):**
- `scenes/explore/regional_npcs.gd` — `REGIONAL_NPCS` dict keyed by subregion. Every map has a key (empty array = no NPCs until authored).
- `scenes/explore/regional_dialogues.gd` — `DIALOGUE_TREES` dict keyed by `dialogue_tree_id`. Same node shape as existing TAVERN_DIALOGUES so `_start_dialogue()` eats it unchanged.
- `GameState.regional_npc_state: Dictionary` — per-NPC mutable state (trust, dialogue flags, quest progress). Lazy-populated via `GameState.get_regional_npc_state(id)`. Save version bumped 4→5 with defensive default for old saves.
- `explore.gd` — parallel state (`_spawned_regional_npcs`, `_regional_npc_markers`, `_regional_npc_positions`). `_populate_regional_npcs()` runs after `_init_random_npcs()` on map load. Silver-ring icon (distinct from random=gold diamond, named=cyan diamond). Click handler checks regional NPCs first. `_advance_time` triggers `_refresh_regional_npc_schedule()` — V1 snap-teleport at 6/12/18/0 boundaries, no tween yet.
- `_show_regional_npc_panel(npc)` — name + lineage/role + trust readout + Talk button (starts dialogue) + skill-check social row. **No Recruit button.**
- `_snap_to_walkable(target, radius)` — spiral-BFS fallback so authored waypoints that hit walls/POIs pick the nearest walkable tile.

**Content status:**
- **Upper Forty** — fully authored (10 NPCs, 10 dialogue trees). Use this as the template for every other subregion.
- **Other 27 subregions** — empty rosters (stubs). Target counts in `RegionalNpcs.TARGET_COUNT_BY_SUBREGION`.

**Authoring workflow for new subregions:**
1. Add an entry to `REGIONAL_NPCS["<subregion name>"]` with 5–10 NPCs matching the target count.
2. For each NPC, pick 4 schedule waypoints (6/12/18/0) referencing the map's buildings/POIs (see `explore_maps.gd` for tile layout).
3. Add a dialogue tree in `regional_dialogues.gd` keyed by each NPC's `dialogue_tree_id`.
4. `_snap_to_walkable` handles minor waypoint misses; prefer tiles that make narrative sense over pixel-perfect walkability.

**Open follow-ups:**
- V2 polish: tween movement between waypoints (currently snap-teleport).
- Quest system: `quest_hooks` field is defined but not yet wired to active missions.
- Should existing `WorldSystems.NAMED_NPCS` (the 20 legacy named NPCs) get absorbed into this system? Currently they're a parallel, non-schedule system. Blaine should decide before P4 bulk authoring.

### 3. Kaiju overhaul — SPEC-ALIGNED (in progress)

Goal: align the Kaiju system with the Kaiju Creator spec (stats, threat points, area scaling, multi-target, damage threshold, collateral).

**New canonical module:** `autoload/kaiju_system.gd`
- `KAIJU_DEFS` const holds all 6 canonical stat blocks (Pyroclast, Grondar, Thal'Zuur, Ny'Zorrak, Mirecoast Sleeper, Aegis Ultima) with full STR/SPD/INT/VIT/DIV, AC, HP (per feat overrides), immunities, resistances, conditional resistances, abilities, feats, size, height_ft, and recruit cost.
- Static formula helpers: `compute_hp(level, vit, feats)`, `compute_ap(level, str)`, `compute_sp(level, div)`, `threat_points(level)`, `damage_threshold(level)`, `legendary_resistance_uses(vit)`, `movement_ft_per_speed(spd)`, `scaled_area_ft(level, base)` (doubles per 5 levels), `multi_target_count(level)` (+1 per 5 levels), `apply_threshold(damage, threshold, ignore)`, `kaiju_vs_structure_damage(raw)`.
- Query helpers: `get_def(idx)`, `get_def_by_id(id)`, `resolve(idx)` for a live stat snapshot, `generate_procedural(level, …)` for back-compat with older callsites.

**Wired into existing code:**
- `world_systems.gd::generate_kaiju(level)` now delegates to `_KaijuSystem.generate_procedural()`, keeping the legacy `hit_zones` + `area_attacks` output shape but with spec-correct HP/AP/SP/threshold and area/multi-target scaled per-level.
- `GameState.KAIJU_RECRUITS` HP/AC resynced to spec values (136/13, 137/16, 149/14, 158/15, 150/12, 138/25) with a new `def_idx` field pointing into `KaijuSystem.KAIJU_DEFS`.
- `GameState.recruit_kaiju(idx)` now pulls the full spec stat block (STR/SPD/INT/VIT/DIV, threshold, multi_target, scaled_area_ft, LR uses, full abilities/feats/immunities/resistances arrays) into the recruited ally entry — with a fallback for safety if KaijuSystem can't resolve.

**Creature size → tile footprint (`autoload/creature_size.gd`):**
Shared module used by all creature sizing code. **COMPRESSED LADDER** tuned for 25×25 dungeon arenas — literal spec math (Colossal = 16×16 = 256 tiles) would eat 64 % of the map and can't even spawn in the designated zone. Ladder:

| Size | Footprint | Tiles | Reach |
|---|---|---|---|
| Tiny | 1×1 | 1 (shares tile) | 5 ft |
| Small | 1×1 | 1 | 5 ft |
| Medium | 1×1 | 1 | 5 ft |
| Large | 1×2 | 2 | 10 ft |
| Huge | 2×2 | 4 | 10 ft |
| Gargantuan | 3×3 | 9 | 15 ft |
| **Colossal** | **4×4** | **16** | **20 ft** |

Compromise: grid footprint + reach are compressed, but every other spec rule (HP/AP/SP formulas, threat points, damage threshold, LR uses, area-doubling per 5 levels, multi-target per 5 levels, 40 ft/SPD movement, structure-damage-threshold bypass) is untouched. Height bands: Huge 16–30 ft, Gargantuan 30–50 ft, Colossal 50+ ft, so `tier_for_height_ft(ft)` auto-lands Kaiju on Colossal.

API: `footprint_tiles(name)`, `footprint_dimensions(name)` → Vector2i(w, h), `tier_index(name)`, `reach_ft(name)`, `tier_for_height_ft(ft)`, `footprint_tiles_at(name, origin)` returning all tiles in the rectangle, `ignores_difficult_terrain(name)` (Colossals trample), `pretty(name)` labels.

- `KaijuSystem.resolve(idx)` and `generate_procedural(level)` both now emit `size`, `size_id`, `size_tile_count`, `footprint_tiles` (Vector2i), `reach_ft`, `height_ft` alongside the existing stats.
- `GameState.recruit_kaiju()` serializes the footprint as `footprint_w` + `footprint_h` ints (JSON-friendly) plus `size`, `size_id`, `size_tile_count`, `reach_ft`, `height_ft` on the recruited ally entry — so the combat/render code can look up the 4×4 footprint without re-resolving the Kaiju def.

**C++ already matches (`gdextension/src/Creature.h`):**
- `Creature::get_max_hp()` for CreatureCategory::Kaiju: `(10 × level) + VIT + 2` ✓
- `Creature::get_max_ap()` for Kaiju: `10 + level + STR` ✓
- `Creature::get_max_sp()` for Kaiju: `10 + level + DIV` ✓
- `Creature::get_movement_speed()` for Kaiju: `40 × SPD` ✓
- `Dungeon.h::kaiju_defs` for all 6 Kaiju: stats, AC, immunities, resistances, abilities ✓

**What still needs C++ work before shipping full spec compliance:**
1. **Area attack auto-scaling** — abilities in `kaiju_defs` describe fixed-ft ranges (e.g. `30ft cube`). The spec says area should double per 5 levels. Need CombatManager to apply `level / 5` doublings to area-ability ranges at resolve-time, or bake the scaled values into ability strings at spawn.
2. **Multi-target per 5 levels** — the `+1 target per 5 levels within 15 ft` rule isn't yet enforced in single-target attack resolution. CombatManager needs a check for `category_ == Kaiju` and expand target lists accordingly.
3. **Structure damage threshold bypass** — when a Kaiju hits a building/ship, the target's damage threshold should be ignored. Currently threshold logic applies uniformly.
4. **Kaiju visual scale** — Kaiju should render Colossal on the map. This is a view-layer change in `combat.gd` or the spawn path; no C++ needed, but worth a dedicated pass.
5. **Threat Points budget enforcement** — not a runtime concern (Kaiju are pre-built by the game, not player-tuned), but if you later add a Kaiju builder UI, the TP-per-ability rule will need `1 TP per ability + 1 TP per feat`.

**Known quirks:**
- `Creature::get_max_hp()` adds a `+2` minimum buffer. At Kaiju scale (HP 130+) this is noise but is technically off-spec by 2 HP. Remove the buffer for Kaiju if strict compliance matters.
- Pyroclast spec HP = 136 comes from its Iron Vitality Tier 1 feat `(2×VIT) + (3×Level) + 3 = 55`… which actually gives 55, not 136. The spec's own math is `10×12 + (8×2)=16 = 136`, which is `10L + 2×VIT`. `KaijuSystem.compute_hp` treats Iron Vitality Tier 1 as the spec's alternate `(2 VIT) + (3 L) + 3` formula; the canonical 136 for Pyroclast is stored as `hp: 136` directly in KAIJU_DEFS to match the printed example exactly.

### 4. Mob system — SPEC-ALIGNED

Goal: align GameState mob recruiting with the Chaotic Mob Formation spec (mood states, instincts, shared stats, size cohesion, surge, frenzied tactics, emergent traits, mob leaders).

**New canonical module:** `autoload/mob_system.gd`
- `MOODS` — 8 mood states (Enraged, Terrified, Jubilant, Desperate, Opportunistic, Frenzied, Panicked, Zealous).
- `SIZES` — 4 tiers (Small 5–20 / 20 ft cohesion, Medium 21–50 / 40 ft, Large 51–100 / 60 ft, Huge 101+ / 60 ft). Includes `move_adjust_ft` so the 30 ft humanoid base slides correctly per size.
- `INSTINCT_TABLE` (1d6): Frenzy / Scatter / Rally / Grab / Loot / Chant — rolled when the morale check fails.
- `FRENZIED_TACTICS` (1d4): Focused Assault / Wild Swing / Defensive Huddle / Mob Madness — rolled each round while under half HP.
- `TRAITS` (12) and `LEADERS` (10) — full descriptions per spec.
- Formulas: `member_solo_hp(level, vit) = 3L + VIT`, `compute_ap(str) = 10 + STR`, `compute_sp(level, div) = 5 + L + DIV`, `mob_hp_pool(members) = members` (1:1 rule), `base_morale(level)` scaling (10→15 at L20), `morale_check_dc(damage) = 10 + damage`, `morale_check_trigger(max_hp) = ⌈25%⌉`, `base_move_ft(size_adjust, nimble) = 30 + size + (10 if Nimble Feet)`, `momentum_swell`, `splintered_move_ft`, `is_frenzied`, `frenzy_damage_bonus(members) = +1 per 5`.
- Attack dice: `improvised_attack_dice(members) = (members/2)d4`, `thrown_attack_dice(members) = (members/10)d4 range 20/60`, `trap_dice(members, intel) = (members/10)d4 DC 10+INT`.
- Environmental Mayhem: `environmental_mayhem_save_dc(str) = 10 + STR`, 1d4 fail-table (Immobilized / Hazardous Passage / Blocked-or-Swept / Knocked Prone).
- `stat_points_for(level) = 5 + L` — matches the L1=6 … L20=25 table exactly.
- **13 canonical example mobs** (Arcanite Rabble, Nightborne Shadow, Venari Tide, Groblodyte Scavenger, Beast Swarm, Emberkin Street, Ironclad Militia, Nightborne Shadow Host, Venari Tide Guard, Arcane Militia, Sacred Zealots, Titan's Vanguard, The Chosen) at levels 1 through 20.
- `generate_procedural(level, members, …)` + `resolve_example(idx)` + `_to_live(def)` return full live stat blocks with attack dice, movement, morale trigger, cohesion distance, etc.

**GameState wiring:**
- `MOB_TRAITS` / `MOB_LEADERS` descriptions resynced to spec text (MOB_MOODS now has all 8 moods).
- `recruit_mob(members, trait_idx, leader_idx, name)` rewritten to call `MobSystem.generate_procedural()` and store spec-correct `hp / ap / sp / morale / morale_trigger_hp / attack_dice / thrown_dice / trap_dice / size / max_cohesion_ft / solo_hp_per_member / move_ft / momentum_move_ft / mood / stats`. Upper member cap raised from 50 → 200 (Huge mobs).

**Combat integration TBD:** MobSystem returns the right numbers but the combat engine doesn't yet enforce cohesion splitting, morale-check triggers on 25% HP loss, instinct-table rolls, frenzied-tactics rolls, surge mechanic, or environmental mayhem. Those are C++ combat-manager changes for a later pass.

### 5. Militia system — MP-BUDGET SPEC ALIGNED

Goal: implement the full Militia Point (MP) economy from the spec.

**New canonical module:** `autoload/militia_system.gd`
- MP budget helpers: `compute_mp(starting_gold, built_from_base, faction_backed, region_in_chaos, player_gold, player_sp)` and `encounter_mp(level) = (level/2) × 5`. Constants for all modifiers (100g/5MP, +5 faction, -5 chaos, 50g/MP player, 1SP/MP player).
- 15 **TYPES** (Guard, Raid, Recon, Sacred, Arcane, Hunter, Merchant Guard, Engineer, Nomad, Seafaring, Crusader, Shadow, Arcane Reclaimer, Storm, Iron Legionnaire) each with `modifiers` dict so combat code can read mechanical bonuses directly (e.g. `{ac: 3}`, `{atk: 2, dmg: 2}`, `{resist: ["lightning","thunder"]}`).
- 4 **EQUIPMENT_TIERS** (Improvised / Standard / Elite / Advanced Tech) with melee/ranged dice, AC, dmg bonus, MP cost, `restricted` + `requires_trait` flags for Tier 4.
- 17 **TRAITS** (all Step-5 options) — first trait free, `MP_PER_EXTRA_TRAIT = 5`, plus `mp_extra_cost` flags for the +5 MP ones (Void-Touched Frenzy, Advanced Tech) and `dangerous`/`restricted` tags.
- 4 **COMMANDER_ROLES** (Veteran, Tactician, Priest, Mage) — 1 MP each, stackable on one unit, `COMMANDER_HP_BONUS = 10`, `COMMANDER_AC_BONUS = 2`.
- **Stat allocation helpers:** `cost_for_stat(target)` enforces the soft-cap-at-5 rule (1:1 below, 2:1 above). `STAT_POINTS_PER_MP = 3`, `MAX_STAT_MP = 8`, `MAX_STAT_POINTS = 24`. Feats: `FEATS_PER_MP = 3`.
- **Formulas:** `compute_hp(level, vit) = 10L + VIT`, `compute_ap(str) = 10 + STR`, `compute_sp(level, div) = 3 + L + DIV`.
- **Morale:** `compute_morale(equip_tier, vit, victories, casualties, hp, max_hp, mp_invested)` applies all the bullets from Step 7 (equipment +1/tier, victories +1/win, VIT +1/point, losses -1/casualty, below 2/3 HP -2, below 1/3 HP -5, +1 per MP invested in morale). `morale_damage_dc(damage_above_threshold) = 10 + damage`.
- **Upgrades:** `VEHICLES` (Cavalry, Chariots, Ships, Siege), `SPECIAL_TRAININGS` (Siege, Naval, Arcane, Elemental, Monster Hunting, Urban Warfare), `UNIQUE_ASSETS` (Divine Blessing 5 MP, Faction Prototype 10 MP). Elite Status 5 MP/unit (+10 HP, +1 AC, +1 atk/dmg, free extra trait).
- **`compute_build_cost(...)`** — validates a build against its MP budget with one function call; sums everything (stats MP, size, extras, equipment, trait slots, commanders, vehicles, special trainings, elite units, unique assets, feats, morale investment).
- **2 example militias** — Ironroot Guard Militia (25 MP, Medium, Tier 2, Shield Wall, Veteran) and Emberveil Recon Militia (17 MP, Small, Tier 1, Ambush Tactics, Tactician) — exactly matching the spec examples.

**GameState wiring:**
- `recruit_militia(type_idx, equip_tier, member_count, name)` (legacy UI path) rewritten to use `MilitiaSystem.compute_hp/compute_ap/compute_sp/compute_morale` — produces spec-correct HP/AP/SP/morale with sensible default stat distribution.
- **New `recruit_militia_mp_build(build_dict, mp_budget, name)`** — advanced MP-budget builder. Takes a full spec-style build (type_id, stats, stats_mp, size_idx, extra_members, equip_tier_idx, trait_ids, commander_role_ids, vehicle_ids, special_trainings, elite_units, unique_asset_ids, feats_count, morale_mp) and validates against `mp_budget` via `MilitiaSystem.compute_build_cost()`. Returns `{ok, mp_spent, mp_remaining}` or `{ok:false, reason}`. Stores full build on the recruited ally for combat/UI reference.

**Open follow-ups:**
- Build UI: the MP-budget builder is exposed as a function but has no UI yet. The existing world.gd base tab recruit panel still uses the simpler 4-arg recruit_militia call — it can stay for now.
- Combat integration: `traits`, `commanders`, `vehicles`, `special_trainings`, and `elite_units` arrays are stored on the recruited ally entry but the combat engine doesn't yet read them when resolving attacks. Next pass.

### 6. Kaiju overhaul
See section 3 above.

### 8. Dungeon Crawl mode — SHIPPED

Goal: extended (50×50) dungeons where enemies only react after detecting players (line of sight + perception range), with treasure chests for loot.

**Plumbing:**
- `MAP_SIZE` converted from `const` to `var` in both `dungeon.gd:154` and `rimvale_fallback_engine.gd:7569`. Both files keep the same name; existing loops/index math work unchanged. New constants `MAP_SIZE_STANDARD = 25` and `MAP_SIZE_CRAWL = 50` document the two valid sizes. Crawl-active flag `_crawl_active: bool` on the engine.
- `start_dungeon()` resets `MAP_SIZE = 25` at the top **only if `_crawl_active` is false**, so crawl entry points (which set `_crawl_active = true` and `MAP_SIZE = 50` first) aren't clobbered.
- `dungeon.gd::_first_3d_build()` reads `_e.get("MAP_SIZE")` so the renderer's loops, fog/elevation arrays, and camera centering all use the engine's value.

**`start_dungeon_crawl(player_handles, enemy_level, terrain_style, extra_enemies=5)`** in `rimvale_fallback_engine.gd`:
1. Flips `_crawl_active = true` and `MAP_SIZE = MAP_SIZE_CRAWL`.
2. Delegates to `start_dungeon(handles, level, -1, terrain)` for the full setup (procedural map, fog/elevation arrays sized to 50×50, players spawned).
3. Tags every enemy with detection state: `is_alerted: false`, `alert_radius: 6`, `perception_range: 12 + DIV`, `last_seen_x/y: -1`.
4. Calls `_spawn_crawl_extra_enemies(level, n)` to add 5 extra patrols on the outer ring (Manhattan ≥ 18 from any player). Each gets the same detection fields.
5. Calls `_spawn_crawl_chests(n)` — 5–8 chests scattered in the middle ring (distance 6–38 from spawn). Loot scales with distance via `_generate_creature_loot(level + dist/8)`.

**Detection AI:**
- `process_enemy_phase()` early-returns with `"%s remains unaware."` log if `_crawl_active` and `not is_alerted`. Once alerted, the standard AI (heal at low HP, otherwise attack nearest player) takes over.
- `_run_crawl_perception_pass()` runs after every player move (hooked into `move_dungeon_player`). For every un-alerted enemy: Chebyshev distance to each living player ≤ `perception_range` AND `_los_clear()` returns true → mark `is_alerted = true` and call `_propagate_alert(enemy)`.
- `_propagate_alert(source)` — Manhattan-distance check against `alert_radius`; allies in range also flip to alerted with the same `last_seen` coords. So one cry alerts the whole pack, but isolated outliers stay quiet.
- LOS reuses the existing `_los_clear()` Bresenham at line 8121.

**Treasure chests:**
- Chest entities have `is_chest: true`, `looted: false`, and a pre-rolled `inventory: _generate_creature_loot(level)`.
- `_try_loot_chest_at(tx, ty)` runs at the end of `move_dungeon_player`. If the player's new tile has an un-looted chest, transfer every item to `GameState.add_to_stash()`, mark `looted = true`, and write a combat-log line like "Opened Treasure Chest — found Iron Sword, Health Potion."
- `dungeon.gd::_update_3d_entities()` short-circuits the regular entity render for `is_chest: true`: closed chests are gold (Color 0.78/0.55/0.18) with an emissive glint and an `OmniLight3D`. Looted chests render flatter and dimmer (no glint, no light).

**UI:** New "🗺 Dungeon Crawl" button (encounter type 6) on `world.gd::_build_dungeon_tab`. Routes through `_dd_launch` to `RimvaleAPI.engine.start_dungeon_crawl(handles, _dd_enemy_level, _dd_terrain_style)`. The Crawl config panel shows the description ("Extended 50×50 dungeon. Enemies don't act until they detect you …") + an enemy level slider (1–15). The legacy Siege launch case shifted to type 7.

**What's still ahead (next pass, optional):**
- **Sneak-vs-Perception roll.** Right now detection is purely deterministic (LOS + range). Adding a stealth check vs. perception roll would let stealthy parties slip past patrols.
- **Patrol patterns.** Un-alerted enemies could wander between waypoints instead of standing still.
- **Lock + key chests.** Tag some chests `is_locked: true`, require a Lockpicking check or a key item to open.
- **Crawl-specific encounter scaling.** The 50×50 map is 4× the area of standard but only spawns +5 enemies. Tuning encounter density to room density would feel better.
- **Mini-map.** A 50×50 map without a mini-map is hard to navigate; the existing fog-of-war helps but a top-down overlay would improve UX.
- **Kaiju/Apex variants of crawl.** Same 50×50 map but with a single Colossal target — turns the crawl into a hunt.

Each of these is additive behind the existing `_crawl_active` flag — none require touching the plumbing.

### 7. Dungeon render-style toggle — Phase 1 shipped

Goal: let the player pick between **Classic Dungeon** (grid-token tactical) and **Region Map Style** (explore-map-styled visuals) for dungeon encounters. Toggle lives on the World → Dungeon tab.

**Infrastructure wired (this pass):**
- `GameState.dungeon_render_style: String` — `"classic"` or `"region"`. Default `"classic"`. Serialized to save_game / load_game with a defensive default so old saves load cleanly.
- World Dungeon tab (`world.gd::_build_dungeon_tab`) — new "Map Style" section sits under the header with two buttons: **🏰 Classic Dungeon** and **🗺 Region Map Style**. Clicking either writes the preference and calls `save_game()`. The active button gets brighter font so the current choice is obvious at a glance.
- `dungeon.gd` — new `_render_style: String` class var read from `GameState.dungeon_render_style` during map load (right after `_load_terrain_palette()`). Logs `[Dungeon] render style = …` to the console each time a dungeon opens.
- `_apply_region_style_overrides()` — runs when style == "region". Substitutes the biome palette with explore-style values: grassy green floors, cool stone walls, warm path accents, daylight cream ambient light, soft sky-haze fog at low density. `_biome_prop_set = "region_outdoor"` so the existing prop-spawner gracefully no-ops unknown keys until Phase 2 ports real props.

**What Region Map Style gives you right now (Phase 1):**
- Palette swap: the dungeon reads as an outdoor region — grass floors, blue-grey stone walls, warm road accents, bright ambient light, thin atmospheric fog — instead of the dark-cavern look.
- No geometry changes: the 25×25 grid, tile layout, fog-of-war, and combat rules are unchanged.

**Phase 2 — region-style prop overlay SHIPPED**

- New class var `_region_prop_root: Node3D` hangs off `_world3d_root`; created alongside the other scene roots so toggling back to classic cleanly wipes it.
- New `_rebuild_region_style_props()` function (`dungeon.gd` after `_apply_region_style_overrides`) runs after the classic tile/wall rebuild when `_render_style == "region"`. Hooked from `_update_3d_view()` — classic mode takes the `else` branch and clears any leftover region children.
- Deterministic RNG seeded by `MAP_SIZE` for stable visuals across rebuilds.
- What it spawns, layered on top of the Phase 1 palette swap:
  - **Daylight** — warm cream `DirectionalLight3D` (energy 1.3, shadows on) + a cool-blue fill light (energy 0.4) mirroring explore.gd's outdoor rig. Visible lift over the cavern torchlight.
  - **Grass tufts** — ~22 % of walkable tiles, 2–4 randomized `BoxMesh` blades each, hue-varied per blade.
  - **Path markings** — thin warm-cream accent boxes on every 4th diagonal walkable tile, at 35 % spawn chance — reads as road markings / flagstones.
  - **Streetlamps** — at every 6-tile grid intersection on walkable tiles: cylinder post + emissive sphere bulb + `OmniLight3D` (warm 0.8 energy, 4-unit range).
  - **Benches** — ~2 % of walkable tiles get a wooden bench (seat + 4 legs) with random 90° facing.
  - **Stone cornices** — wall tiles adjacent to walkable tiles get a stone ledge projecting toward the walkable side, oriented via `_region_wall_walkable_neighbour()`.
- `_region_wall_walkable_neighbour(tx, ty)` helper returns the `Vector2i` step direction from a wall toward its first walkable neighbour (N, S, E, W priority). Returns `Vector2i.ZERO` for interior walls with no walkable neighbour so no cornice is spawned there.
- All meshes use existing `_make_mesh_inst()` / `_make_mat()` helpers — no new material factory code.

**Combined visual effect:** palette swap (Phase 1) turns floors grassy and walls into cool stone. Phase 2 adds warm daylight, scattered grass, path markings along regular routes, perimeter streetlamps with actual lighting, wooden benches, and cornices on wall edges that turn them into building facades rather than cave walls.

**Phase 3 — polish pass SHIPPED**

- **Default flipped to Region Map Style.** `GameState.dungeon_render_style` now defaults to `"region"` (both the var initializer and the `load_game` defensive fallback). Existing saves with `"classic"` keep their preference; new saves and saves missing the field land on region.
- **Building signposts from wall clusters.** New `_spawn_region_building_signposts(rng)` runs at the end of `_rebuild_region_style_props()`. It flood-fills the dungeon's wall tiles into contiguous clusters, then for each cluster ≥ 4 tiles it picks the wall tile with the most walkable neighbours (the "front door"), spawns a wooden post + emissive sign-plate one tile out, plus a warm `OmniLight3D` so the plate glows. Larger buildings get richer plate tints (3 size tiers driving plate emission and color). Helper `_REGION_BUILDING_NAMES` array of 20 procedural names — Guildhall, Stonemarket, Ironward Watch, etc. — rotated across clusters.
- **Outdoor sky + daylight in `_update_biome_environment()`.** Region branch swaps `BG_SKY` with a `ProceduralSkyMaterial` (deep-cool top, warm horizon haze, sun curve set), thin daylight fog (0.012 density vs. 0.024+ cavern), bright cream ambient (energy 1.10), and overrides any existing `SunLight`/`FillLight` directional children with daylight cream (1.00 / 0.95 / 0.82, energy 1.20) and cool-blue fill (0.75 / 0.85 / 1.00, energy 0.40). Early-returns from the function so cavern overrides don't fight back. Classic mode path is untouched.
- **Softer enemy / ally tokens in region mode.** `_update_3d_entities()` now applies a region-mode override after the classic body-color block: player tokens shift from saturated blue to a softer `0.34/0.58/0.86`, allies from neon green to `0.40/0.72/0.46`, enemies from harsh `0.88/0.22/0.22` to a warmer `0.78/0.32/0.30`. Emission strengths drop ~25% so tokens read as creatures-on-grass instead of glowing markers in a cavern. Dead tokens use the existing palette unchanged.

**What's optional from here:**
- **Painted building names on the plates.** Right now plates are blank glowing rectangles; `Label3D` or `MeshInstance3D` with text-baked-into-material would print the actual name from `_REGION_BUILDING_NAMES`.
- **Per-cluster building roofs / silhouettes.** Tall `BoxMesh` over each cluster's bounding box would push the look further toward "town district" vs. "dungeon with signposts".
- **POI-landmark spawning** (ACF pillar, blacksmith anvil) at known dungeon features (chest tiles, stairs) — needs new metadata on the dungeon map.
- **Toggle visibility back on the world tab.** Currently the toggle persists silently; consider showing a small "Now: Region Map Style" badge or in-game indicator.

All optional polish stays additive behind `if _render_style == "region":` so nothing risks classic-mode regressions.

### 3. Mobs / militia
`gdextension/src/Militia.h` exists. TBD — confirm scope before starting.

## Godot 4 gotchas hit this session

- `Window.popup_hide` **does not exist** in Godot 4 (it was a Godot 3 signal). For popup/dialog cleanup on close, connect a combination of:
  - `close_requested` — user clicked the X / pressed Esc
  - `confirmed` — user pressed the AcceptDialog OK button
  - `visibility_changed` with an `if not visible` check — catches programmatic `hide()` calls too
  See the four popup scripts in `scenes/popups/` for the exact pattern.
- `String.join` takes a `PackedStringArray` in Godot 4. Building one with `.map()` and passing it to the `PackedStringArray(...)` constructor is flaky; prefer appending to a `PackedStringArray()` directly.

## Working preferences (Blaine)

- Direct action > process. If a prior session promised something, honor it; don't loop on clarifying questions.
- Keep popup/panel code connecting `popup_hide -> queue_free` for cleanup.
- When a session is going to run out of context, write a real handoff file **into the project folder**, not the scratch outputs dir (which vanishes between sessions).

## Key files

- `scenes/explore/explore.gd` — POI panels
- `scenes/world/world.gd` — tab builders to mirror
- `autoload/game_state.gd` — party, gold, XP, save/load
- `autoload/rimvale_fallback_engine.gd` — engine API used by `RimvaleAPI.engine`
- `MANUAL_AUDIT.md`, `PARITY_PLAN.md` — prior planning docs
