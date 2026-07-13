# HANDOFF — Finishing the Battle Mode Plan (for Claude Opus 4.8)

Blaine's Godot 4.6 game **Rimvale** (this folder) has a C&C-style RTS
"Battle Mode". Phases 1-4 of `BATTLE_FUN_PLAN.md` are SHIPPED, plus the
score screen. **Your job: finish Phase 5 — (A) the region conquest
campaign, (B) the sound pass — plus playtest fixes Blaine reports.**
Read this whole file before touching anything; it encodes several days of
hard-won pitfalls.

---
## 1. Architecture in 60 seconds

- **`autoload/battle_system.gd` (~4200 lines)** — the entire battle rules
  engine, registered autoload `BattleSystem`. Real-time sim: `_process`
  accumulates time and runs `_sim_step(0.1)` at 10 Hz. Per-unit brains in
  `_sim_unit_step` (cooldowns → target resolution → attack/chase → move
  orders/stances/mining → spell autocast).
- **`scenes/battle/battle_rts.gd/.tscn` (~2900 lines)** — renderer + input
  + HUD. Persistent Node3D per entity (`_nodes`/`_parts`), fog of war,
  minimap, command card, projectiles. It NEVER mutates sim state except
  through BattleSystem's public API.
- **`scenes/battle/battle_setup.gd`** — the pre-battle screen (region,
  teams, level, difficulty, resources, fog checkbox, hero picker). Calls
  `BattleSystem.start_battle(region, teams, level, difficulty, resources,
  hero_handles)` then `change_scene_to_file(battle_rts.tscn)`.
- **Game engine**: `RimvaleAPI.engine` (autoload/rimvale_fallback_engine.gd,
  ~17k lines — NEVER read it whole; grep targeted line ranges). Battle
  entities are Dictionaries in the LIVE array `e._dungeon_entities`.
  `e.get_dungeon_entities()` returns a DEEP COPY — never use for mutation.
- Battle entities: `handle: -1` always (no story character behind them).
  Hero units COPY character data read-only; **never** call engine
  functions that mutate `_chars` from battle code.

## 2. NON-NEGOTIABLE WORKFLOW RULES (each one broke the game once)

1. **The Linux-sandbox mount of edited files GOES STALE.** After in-place
   edits, `/sessions/.../mnt/RimvaleGodot/<file>` shows old truncated
   content. NEVER trust it for these files. Verify against the HOST file
   with Read/Grep. NEW files sync fine.
2. **Parse verification**: gdparse lives at `~/.local/bin/gdparse` in the
   sandbox. Because of rule 1, copy every new/changed function VERBATIM
   into a harness `.gd` (with minimal stubs) in the session outputs dir
   (new file → syncs) and parse THAT. All existing harnesses are named
   `syntax_test_*.gd` in outputs — follow their style.
3. **gdparse is syntax-only.** Godot's analyzer additionally hard-fails
   the WHOLE script on: stray statements after `return` (this happened —
   one leftover line killed the autoload and broke the setup screen),
   undeclared identifiers, duplicate declarations. After editing, grep
   your new symbols on the host file and Read ±5 lines around every edit
   site to check for orphaned fragments.
4. **For deep verification** (suspected compile error): spawn an agent to
   Read the entire host file in chunks, Write a verbatim copy to outputs,
   gdparse it, and scan for the analyzer-level issues above. This caught
   both past compile-breakers.
5. **`GameState` has NO battle fields.** Assigning an unknown property to
   an autoload is a hard runtime error that silently kills the calling
   function. `BattleSystem.active` is the canonical battle flag.
6. **Blaine must fully RESTART the game** after autoload edits — running
   instances don't hot-reload; he has "reported bugs" that were stale
   builds twice. Always remind him.
7. Tabs for indentation. GDScript 2.0. Every `e.*` engine call must be
   grep-confirmed to exist before use.

## 3. Key sim facts you'll need

- Per-step lookup structures (perf, rebuilt each 0.1 s step):
  `_ent_index` (id→entity), `_occ` (tile key `y*_occ_ms+x` → occupant id).
  Movement goes through `_rt_step` (the ONLY place tiles change — rifts
  and crate pickups hook there). Pathfinding budget `PATH_BUDGET=8`/step;
  units blocked by UNITS wait, blocked by TERRAIN use A* with failure
  backoff. Corpses pruned after 10 s. Army cap `MAX_TEAM_UNITS=40`.
- Weapon damage is keyword-parsed from `equipped_weapon` NAME ("bow" →
  ranged 6 tiles). Armor must set BOTH `equipped_armor` and `ac`.
- Spells: `e._ensure_spell_db()` → static `e._SPELL_DB`. Battle loadouts
  are `ent["spells"] = [{name, cd_left}]`; **SP cost = cooldown seconds**
  (Blaine's core design). AOE via `area`/`mt` fields; element color from
  `dt` field is passed in the "spell" sim_event.
- `sim_event(kind, data)` signal kinds: attack, spell, death, spawn,
  structure, income, elim, over, strike, mind_control, capture, promote,
  raid, region_fx, kaiju, crate, crate_drop. Renderer ignores unknown
  kinds safely — add new kinds freely.
- Neutral things use `battle_team = NEUTRAL_TEAM (99)` — out of range of
  all per-team arrays by design; every guard is `t >= 0 and t < num_teams`.
- Score data: `get_battle_stats()`; `rematch()` restarts with stored args.

## 4. TASK A — Region Conquest Campaign (the big one)

Goal per plan: a world-map meta-game — win skirmishes to claim all 10
regions, escalating difficulty, persistent progress.

Suggested design (keep it this simple):
- **New file** `autoload/conquest.gd` (register in project.godot autoloads
  — grep how BattleSystem is registered) holding: `owned: Array[String]`
  (region ids), `attempts: Dictionary`, save/load via its own
  `user://conquest.save` (ConfigFile or JSON — do NOT touch the story
  save system in game_state.gd).
- **New scene** `scenes/battle/conquest_map.gd/.tscn` (new files → mount
  syncs, easier verification): a screen listing the 10 regions from
  `BattleSystem.REGION_CONFIG` as a stylized grid (reuse the setup
  screen's `RimvaleUtils` button style + region-personality icons).
  Owned regions gold; next conquerable regions highlighted; clicking one
  launches a battle with computed settings.
- **Escalation** by number of owned regions: 0-2 owned → easy, 3 teams,
  level 2, medium resources; 3-5 → medium, 4 teams, level 4; 6-8 → hard,
  5 teams, level 6, low resources; 9 → hard, 6 teams, level 8 ("the last
  stand"). Fog always on. Heroes allowed (pass through the hero picker or
  reuse `BattleSystem._last_heroes`-style default of none).
- **Wiring the result**: conquest sets `Conquest.pending_region = rid`
  before `start_battle`; in battle_rts's `_show_over`, if
  `Conquest.pending_region != ""` and winner == player_team → 
  `Conquest.claim(pending_region)`; the "Back to Title" button becomes
  "Back to World Map" (change_scene to conquest_map.tscn) when a conquest
  battle. Losing does nothing (retry allowed). Clear pending_region in
  both paths.
- Title screen: add a "🗺 Conquest" button next to "⚔ Battle Mode"
  (scenes/title/title_screen.gd — grep the existing Battle Mode button
  block and mirror it).
- Victory lap: when all 10 owned, show a simple triumphant screen/label.

## 5. TASK B — Sound pass

There is currently NO battle audio. Check `assets/` for any existing
sfx/music (grep project for AudioStream usage in other scenes to follow
conventions — the story mode may already have helpers).
- If no assets exist: generate simple procedural sounds with
  `AudioStreamGenerator` OR (better) ask Blaine to drop .ogg files into
  `assets/sfx/battle/` with agreed names: `hit.ogg, bow.ogg, spell.ogg,
  explosion.ogg, alert.ogg, promote.ogg, capture.ogg, battle_theme.ogg`.
- Renderer-side only: a pooled `AudioStreamPlayer3D` set (cap ~8, reuse —
  mirror `_spawn_effect_light`'s pool pattern) driven from `_on_sim_event`
  (attack→hit/bow by distance-check, spell→spell, strike/region lava→
  explosion, alert→alert 2D, promote/capture stings). One looping
  `AudioStreamPlayer` for the theme, volume ~-12 dB. All `load()` calls
  guarded with `ResourceLoader.exists()` so missing files never crash.
- Add a mute toggle 🔇 next to the pause button.

## 6. Smaller loose ends (nice-to-have, in priority order)

1. Playtest feedback from Blaine — always first priority.
2. `end_battle()` doesn't reset `_ai_personas`/`_crates`/`_kaiju_spawned`
   — they're re-initialized in start_battle so it's harmless, but tidy it
   if you're in there.
3. Balance pass (plan R5): kaiju 600⛃ vs apex 250⛃ value, Fireball's 69 s
   cooldown, wild-kaiju HP, insane-resources kaiju rushes. Ask Blaine
   what felt off before changing numbers.
4. Battle Mode is excluded from story saves BY DESIGN — don't "fix" that.
5. `RELEASE_PLAN.md` / `STEAM_RELEASE_CHECKLIST.md` — update when the
   plan completes; Battle Mode should be mentioned on the Steam page copy.

## ✅ SESSION LOG — Phase 5 finished (Opus 4.8, 2026-07-12)

Both remaining Phase 5 items are shipped and parse-verified. Summary:

**Task A — Region Conquest campaign**
- NEW `autoload/conquest.gd` (autoload `Conquest`, registered in project.godot
  right after BattleSystem). Holds `owned: Array[String]`, `attempts`,
  `pending_region`; persists to `user://conquest.save` via ConfigFile (never
  the story save). `settings_for_next()` is the escalation curve
  (easy/3-team/L2 → … → hard/6-team/L8 "last stand"); `begin_attempt()`,
  `claim()`, `abandon()`, `reset_campaign()`, `is_complete()`.
- NEW `scenes/battle/conquest_map.gd/.tscn`: 10-region grid (gold=held,
  ⚔=attackable), escalation preview, click→battle, triumph screen at 10/10.
- Wiring: `battle_rts._show_over` claims on a conquest win and swaps the back
  button to “🗺 Back to World Map” (`_leave_to_map`). `_leave_battle` and
  `battle_setup._on_start_pressed` both call `Conquest.abandon()` so a manual
  skirmish can never inherit a stale conquest flag. Title screen gains a
  “🗺 Conquest” button.
- Retry semantics: a loss leaves `pending_region` set so 🔁 Rematch retries the
  same conquest battle; a win’s `claim()` clears it (no double-claim).

**Task B — Sound pass** (reuses the existing `AudioManager` autoload — it
already had a full combat/spell/jingle/region-music catalog, so no new pooled
player was needed):
- `battle_rts` drives `AudioManager.play_sfx/play_music` from `_on_sim_event`:
  attack (pierce/slash by attacker→target distance ≥1.6, matching
  `_fire_projectile`), spell (element→fire/ice/lightning/heal/cast), death,
  strike & kaiju booms, capture/promote stings, plus alert klaxons in
  `_raise_alert`. Looping `music_combat` theme starts in `_ready`.
- Combat SFX are throttled (`_sfx_atk_cd`/`_sfx_spell_cd`/`_sfx_death_cd`,
  decremented in `_process`) so a busy field doesn’t machine-gun the pool.
- 🔊/🔇 mute button next to Pause (`_toggle_mute`): gates `_play_sfx` and
  stops/restarts the theme; local to the battle, doesn’t touch global settings.
- All audio goes through AudioManager, which guards every load with
  `ResourceLoader.exists()` — missing assets are silent no-ops, never crashes.

**Verification**: gdparse (installed via `pip install gdtoolkit` — NOT
pre-present in a fresh sandbox) run clean on both new files and on a harness
(`outputs/syntax_test_battle_edits.gd`) holding verbatim copies of every
in-place edit. Host files scanned around each edit site — no stray-after-return
or orphaned fragments. `BATTLE_FUN_PLAN.md` Phase 5 marked ✅.

**Still open (playtest-driven)**: balance suspects from §6.3 (Fireball 69 s
cooldown, kaiju 600⛃ pricing, wild-kaiju HP) — left for Blaine’s notes. The
region-music-per-region ids in AudioManager (`music_region_<rid>`) are unused
by the battle scene, which plays the generic `music_combat`; wiring per-region
combat themes is an easy future polish.

**⚠️ RESTART REQUIRED**: this touched autoloads (`conquest.gd`, `project.godot`)
and battle scripts — Blaine must fully quit and relaunch Godot; a running
instance won’t hot-reload these.

## ✅ BALANCE PASS — spell tuning + bigger maps (2026-07-12)

Battle-Mode-only tuning in `battle_system.gd`; the shared story `_SPELL_DB` and
`MAP_SIZE_CRAWL` are untouched.
- **Spell range HALVED**: new `_battle_spell_range(s)` (0.5×, floored at 1 tile)
  now feeds both `_offensive_spell_range` (caster hold distance) and
  `_try_cast_battle_spell` (`rng`). Consistent between positioning and casting.
- **Spell cooldown HALVED**: the one cooldown-set site now does
  `cd_left = maxf(0.5, sc * BATTLE_SPELL_CD_MUL)`. SP semantics unchanged, so
  the spell-picker still shows the true "(N SP)" tier; only the live battle
  cooldown is halved (e.g. Fireball 69→~34.5 s, addressing the §6.3 suspect).
  NOTE: the "(N SP)" label in the loadout UI still shows full `sc`; if the
  seconds mental-model matters, relabel it there — deliberately left as SP.
- **Battle maps 50→75** (`BATTLE_MAP_SIZE`): in `start_battle`, right after the
  crawl boot and before `_open_battlefield`, MAP_SIZE is bumped and the three
  map-indexed arrays (`_dungeon_map`/`_elevation`/`_fog`) are resized+filled.
  Every dungeon entry resets MAP_SIZE for itself, so story crawls stay 50×50.
  Watch perf on 10-team fights (2.25× the tiles); dial `BATTLE_MAP_SIZE` down if
  it drags. Parse-verified via `outputs/syntax_test_spell_map.gd`.

## ✅ DEBUG MODE — battle playtest tools (2026-07-12)

Gated on the existing global `GameState.debug_mode` (the checkbox in the profile
screen — same flag the dungeon's enemy-debug panel uses). When it's on, the
battle HUD shows a 🐞 button that opens a debug panel.

- New public debug API in `battle_system.gd` (all no-op when no battle active):
  `debug_add_supply(team, amt)`, `debug_player_win()` → `_finish_battle`,
  `debug_spawn_kaiju()` → `_spawn_wild_kaiju`, `debug_charge_strike(team)` →
  `_strike_cd[team]=0`, `debug_eliminate_enemy_units()` (collects then kills all
  non-player MOBILE units via `_rt_handle_death`, leaving every structure/base).
- `battle_rts.gd` panel: +100 / +1000 / +10000 supply, 👁 Reveal map (toggles,
  reusing the fog engine's `_fog_revealed` latch), ☄ Charge strike, 🦖 Spawn
  kaiju, 💀 Eliminate enemy units, 🏆 Instant win, Close. The 🐞 button only
  builds when `GameState.debug_mode` is true at HUD-build time.
- Reads `GameState.debug_mode` only (never assigns to GameState). Parse-verified
  via `outputs/syntax_test_debug.gd`. RESTART Godot (autoload change).

## 7. Definition of done

Conquest campaign playable start→finish (fresh file → 10 regions → win
screen), sound audible and mutable, everything parse-verified per §2,
`BATTLE_FUN_PLAN.md` updated with ✅ marks, and a restart reminder to
Blaine in your summary.
