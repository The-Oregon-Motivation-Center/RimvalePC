---
name: rimvale-mobile-performance
description: Profile and optimize Rimvale on Android — frame time, UI rebuild cost, texture memory, APK size, and battery drain. Use when mobile builds stutter, overheat, drain battery, run out of memory, or when the APK/AAB is too large.
---

# Rimvale — mobile performance

Target: **60 fps** on mid-range hardware, no thermal throttling in a 20-minute
gauntlet run. The TCG is UI-heavy rather than 3D-heavy, so the bottlenecks are
different from Battle Mode's.

## Measure first

```bash
adb logcat -s godot:V                        # engine warnings
adb shell dumpsys gfxinfo <package> framestats
adb shell top -m 10                          # CPU while playing
```
In-game, use Godot's `Performance` singleton and print on a timer:
`TIME_FPS`, `TIME_PROCESS`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`,
`MEMORY_STATIC`, `OBJECT_NODE_COUNT`.

## The TCG's #1 cost: full-board UI rebuilds

`card_mode.gd::_refresh_board()` frees and rebuilds large parts of the UI —
including `_rebuild_opponent_area()`, which rebuilds **every opponent's strip
and 6-slot row from scratch** — and it is called after every action and on
nearly every `card_event`. In a 4-player match that is 24 card panels, each
with a portrait `TextureRect`, HP bar, chips, and several labels.

On desktop this is invisible. On a phone it's a visible hitch per tap.

Fix in this order:
1. **Coalesce refreshes.** Multiple events often fire per action. Set a
   `_refresh_pending` flag and do the real work once in `_process`:
   ```gdscript
   func _refresh_board() -> void:
       _refresh_pending = true
   func _process(_d: float) -> void:
       if _refresh_pending:
           _refresh_pending = false
           _do_refresh_board()
   ```
2. **Update in place instead of rebuilding.** Keep the slot panels alive and
   only set label text / bar values. Rebuild only when a slot's *occupant
   identity* changes (compare the card `id`).
3. **Cache portrait textures.** `_portrait_box()` calls
   `RimvaleUtils.get_portrait()` per panel per rebuild; that raw-loads a PNG
   from disk when import metadata is missing. Add a `Dictionary` cache keyed
   by lineage name — this alone is a large win.

## Textures

The lineage portraits in `assets/characters/` are the TCG's whole art budget
(169 PNGs). On Android:
- Import them as **VRAM Compressed** (ETC2/ASTC) rather than Lossless.
- Cap dimensions — cards display them at ~64–96 px tall; 1024² source art is
  ~16× more texels than needed. Consider a mobile-sized variant set.
- Only the portraits actually dealt into a match get loaded; the cache above
  keeps that bounded.

## APK/AAB size

Rimvale's repo carries several 3D kits the TCG never renders (`kenney_*`,
`fantasy-town-kit`, `modular-dungeon-kit`, `assets/characters_3d`,
`assets/vehicles_3d`). Excluding them via export filters (see the
`rimvale-android-export` skill) is the single biggest size win. Check the
result:
```bash
unzip -l build/rimvale.aab | sort -k1 -n | tail -30   # biggest entries
```

## Battery and thermals

- The TCG is turn-based — it does **not** need to render at max rate while
  waiting for input. Consider `Engine.max_fps = 60` and, on menus/handoff
  screens, dropping to 30.
- `OS.low_processor_usage_mode = true` is very effective for a card game and
  costs nothing visually. Test that animations/tweens still look right.
- The AI turn uses `await get_tree().create_timer(AI_ACTION_DELAY)` — that's
  already idle-friendly. Don't replace it with a polling loop.

## Battle Mode on mobile (if it ships)

Battle Mode is a different beast: a 10 Hz sim with up to 400 entities, a
spatial hash, A* pathfinding, and fog/minimap `Image` rebuilds. The desktop
optimizations already in `battle_system.gd` (per-team caches, LOD culling,
path budget) are the right foundation, but expect to:
- lower `MAX_TEAM_UNITS` and the AI army caps on mobile,
- reduce map size options,
- raise `AI_THINK_PERIOD` and the fog/minimap timers.
Gate these behind `OS.has_feature("mobile")` rather than forking the code.

## Regression guard

Record a baseline before optimizing and re-measure after each change:
| Metric | Where | Target |
|---|---|---|
| FPS during a 4-player match | Performance.TIME_FPS | ≥ 60 |
| Frame time after a card play | gfxinfo framestats | < 16 ms |
| Static memory after 10 rounds | Performance.MEMORY_STATIC | stable, no growth |
| APK size | `ls -lh` | as small as the art allows |
