# Regional NPCs — Design Document

A proposal for permanent, schedule-driven, interactable (but not recruitable) NPCs that populate every region map. Written 2026-04-23, pending Blaine's review before any code lands.

---

## 1. Problem statement

Today, region maps feel empty. The only NPCs there are:

- **Random NPCs** (`_init_random_npcs` in `explore.gd` lines 3711–3830) — spawn deterministically per subregion from a seed, but are drawn from a shallow pool and give generic interactions.
- **Named NPCs** from `WorldSystems.NAMED_NPCS` — there are currently only 20, assigned to major regions, not subregions, and they stand still.
- **ACF Stationed agents** — only appear *inside the ACF HQ panel*, not on the map itself.

None of them walk around. None of them have schedules. Most regions have 0–1 handcrafted characters.

**Goal:** every region map has 5–10 permanent NPCs that (a) always appear when the player visits, (b) move between scheduled positions four times a day (6am, 12pm, 6pm, 12am), and (c) open a region-specific dialogue on click, tied to local missions / story beats.

---

## 2. Region map catalog (CORRECTED — real source is `explore_maps.gd`)

My first draft referenced `WorldSystems.SUBREGIONS`; that dict is stale and not used for actual map routing. The real source of truth is the `ExploreMaps.get_map()` match block in `scenes/explore/explore_maps.gd`. Ground truth: **28 unique subregion maps across 10 parent regions**. (Some `region_id` aliases like "Metropolitan"→Upper Forty are default-map fallbacks, not additional maps.)

Per-subregion confirmed by Blaine. Population tiers also set: Metropolitan = 10, Glass Passage = 5, everything else placed on a tier between.

| Region (id) | Subregion map | Tier | NPC count |
|---|---|---|---|
| Metropolitan (metro) | Upper Forty | Urban-peak | **10** |
| Metropolitan (metro) | Lower Forty | Urban-peak | **10** |
| Metropolitan (metro) | Eternal Library | Urban-peak | **10** |
| Metropolitan (metro) | West End Gullet | Urban-peak | **10** |
| Metropolitan (metro) | Cradling Depths | Urban-peak | **10** |
| The Plains (plains) | Kingdom of Qunorum | Capital-settled | **8** |
| The Plains (plains) | Mortal Arena | Bustling-specialty | **8** |
| The Plains (plains) | Wilds of Endero | Frontier | **6** |
| The Plains (plains) | Forest of SubEden | Frontier | **6** |
| Peaks of Isolation (peaks) | Pharaoh's Den | Remote | **5** |
| Shadows Beneath (shadows) | The Darkness | Dangerous-underground | **5** |
| Shadows Beneath (shadows) | House of Arachana | Dangerous-underground | **5** |
| Shadows Beneath (shadows) | Crypt at End of Valley | Dangerous-underground | **5** |
| Shadows Beneath (shadows) | Spindle York's Schism | Dangerous-underground | **5** |
| Glass Passage (glass) | Argent Hall | Remote-sparse | **5** |
| Glass Passage (glass) | Sacral Separation | Remote-sparse | **5** |
| The Isles (isles) | Depths of Denorim | Coastal-settled | **6** |
| The Isles (isles) | Corrupted Marshes | Hostile-wilds | **6** |
| The Isles (isles) | Gloamfen Hollow | Hostile-wilds | **6** |
| The Isles (isles) | Moroboros | Coastal-settled | **6** |
| Titan's Lament (titans) | Vulcan Valley | Industrial-fringe | **6** |
| Titan's Lament (titans) | Infernal Machine | Industrial-fringe | **6** |
| The Astral Tear (astral) | Arcane Collapse | Otherworldly-hostile | **5** |
| The Astral Tear (astral) | L.I.T.O. | Otherworldly-hostile | **5** |
| The Astral Tear (astral) | Land of Tomorrow | Otherworldly-hostile | **5** |
| Terminus Volarus (terminus) | City of Eternal Light | Holy-city | **8** |
| Terminus Volarus (terminus) | Hallowed Sacrament | Holy-sanctum | **7** |
| Sublimini Dominus (sublimini) | Beating Heart of The Void | Void-remote | **5** |

**Total: 184 NPCs across 28 subregion maps.** Sits squarely in the 150–300 range Blaine specified.

**Authoring cost recompute:** ~184 NPCs × ~15 min per full definition (name, lineage, 4 waypoints, dialogue tree, social actions) = **~46 hours of writing**. Same order of magnitude as my first estimate. Still the dominant cost of the feature.

---

## 3. Data model

### 3.1 New static data: `scenes/explore/regional_npcs.gd`

A new autoload-free data module (keeps `world_systems.gd` from ballooning). Exposes one big `const REGIONAL_NPCS: Dictionary` keyed by subregion display name → `Array[Dictionary]` of NPC definitions.

```gdscript
# scenes/explore/regional_npcs.gd
class_name RegionalNpcs extends RefCounted

const REGIONAL_NPCS: Dictionary = {
    "The Argent Expanse": [
        {
            "id": "argent_hedda",
            "name": "Hedda the Wayfinder",
            "lineage": "Boreal Human",
            "role": "scout",            # visual/portrait hint, not mechanical
            "recruitable": false,
            "portrait_color": Color(0.80, 0.70, 0.50),
            "schedule": {
                6:  Vector2i(4, 18),    # 6 am — camp at south road
                12: Vector2i(14, 10),   # noon — patrolling ridge
                18: Vector2i(22, 12),   # 6 pm — watchtower
                0:  Vector2i(4, 18),    # midnight — back at camp
            },
            "dialogue_tree_id": "argent_hedda_default",
            "quest_hooks": ["argent_bandit_caravan"],  # references mission IDs
        },
        # ... 4 to 9 more
    ],
    "The Hearthlands": [ ... ],
    # ... one entry per subregion
}
```

**Why a dictionary of literals, not generated?** Deterministic, save-safe (NPC IDs are stable across sessions), diff-friendly in Git. The roster is *content*, not randomized state.

### 3.2 Runtime state: `GameState.regional_npc_state`

Per-NPC mutable state that needs to persist. Keyed by NPC `id` for O(1) lookup across regions:

```gdscript
# autoload/game_state.gd  (add near the other dicts)
var regional_npc_state: Dictionary = {}
# Shape:
# {
#   "argent_hedda": {
#       "trust": 0,                       # -100..100
#       "dialogue_flags": {"intro_done": true},
#       "last_interaction_day": 3,
#       "quest_progress": {"argent_bandit_caravan": "accepted"},
#   }
# }
```

Populated lazily: only NPCs the player has actually interacted with end up in the dict. Save size stays tiny.

### 3.3 Dialogue storage

Two options for where dialogue trees live:

- **Inline in `regional_npcs.gd`** — every NPC carries its full tree. Fast to author; file gets huge (~200 NPCs × 3–10 nodes each).
- **Separate `scenes/explore/regional_dialogues.gd` registry** — NPC references `dialogue_tree_id`; dialogues live in a second dict keyed by that ID. Cleaner; one file for characters, one for what they say. Recommended.

Dialogue shape matches the existing `TAVERN_DIALOGUES`, `ACF_DIALOGUES`, `LIBRARY_DIALOGUES` pattern (`explore.gd:4585+`) so we can reuse `_start_dialogue()` and `_show_dialogue_node()` unchanged. Each node is:

```gdscript
{ "speaker": String, "text": String, "choices": [
    { "label": String, "skill": "", "dc_offset": 0, "next_pass": 1, "next_fail": -1,
      "reward": "intel:Bandits hit the south caravan at dawn", "fail_reward": "" },
    # ...
]}
```

Rewards use the pipe-delimited string already supported by `_apply_social_reward` (`gold:`, `xp:`, `intel:`, `rep:`, `consequence:`, etc.) so tying dialogue to missions and faction reputation is already free.

---

## 4. Schedule and movement

### 4.1 Schedule resolution

Each NPC has four waypoints: **6, 12, 18, 0 hours**. At any moment, the NPC's current "scheduled tile" is the waypoint for the most recent past key hour:

```
_current_hour in [ 6, 12)  → waypoint at hour 6
_current_hour in [12, 18)  → waypoint at hour 12
_current_hour in [18, 24)  → waypoint at hour 18
_current_hour in [ 0,  6)  → waypoint at hour 0
```

This matches your request verbatim ("at 6am be here, at 12pm be there, at 6 pm be over here, at 12 AM be over somewhere else") and is trivially predictable.

### 4.2 Movement policy — two phases

**V1 (simple, ship first):** NPC markers snap to the current scheduled tile whenever `_current_hour` advances past a key threshold. Player sees the world "re-populate" at 6am/noon/6pm/midnight. Minimal code, zero pathfinding.

**V2 (polish, later):** between key hours, linearly interpolate position along a straight line between the previous and next waypoint, so NPCs appear to walk. One `Tween` per NPC, driven by `_advance_time`. Still no real pathfinding — the waypoints are author-approved tiles, so we trust the line. Tiles blocked by water / POIs are the author's problem.

**V3 (far future):** real A* along walkable tiles, probably overkill.

I recommend shipping V1 first, confirming it feels right, then promoting to V2 only if the pop-in is jarring.

### 4.3 Integration with `_advance_time`

`_advance_time(hours)` in `explore.gd` already mutates `_current_hour`. Hook point: right after the hour changes, call a new `_refresh_npc_schedules()` that walks `_spawned_regional_npcs` and repositions markers whose "current waypoint" changed. Cheap — only diffs.

---

## 5. Rendering

Reuse the existing marker pipeline in `explore.gd`:

- New state: `_spawned_regional_npcs: Array[Dictionary]` and `_regional_npc_markers: Dictionary[Vector2i, Node3D]`, mirroring the existing `_spawned_npcs` / `_npc_markers`.
- On subregion load, call `_populate_regional_npcs()` which reads `RegionalNpcs.REGIONAL_NPCS.get(_subregion, [])` and builds a marker per NPC at its current scheduled tile.
- Marker model = `CharacterModelBuilder.build_sprite_model()` — same as today — tinted by `portrait_color` so regulars are visually distinguishable from the random/named NPCs.
- Floating icon above the marker: **gold diamond** → random NPC (existing), **cyan diamond** → named NPC (existing), **silver ring** → regional regular (new, so player can tell at a glance who's the permanent local).

Click handling: piggyback on the existing NPC-click path. The click handler resolves a tile to an NPC by checking three dicts in order: regional regulars first (most specific), then `_npc_positions`, then random. If it's a regional regular, open a new `_show_regional_npc_panel(npc)` instead of the existing random-NPC panel — because the UI needs to hide recruit-related buttons and show the dialogue entry-point instead.

---

## 6. Interaction / dialogue panel

`_show_regional_npc_panel(npc)` mirrors `_show_npc_panel` but stripped of recruitment:

- Portrait, name, lineage, one-line role description.
- Current "mood" / trust line (reading `GameState.regional_npc_state[id].trust`).
- **"Talk" button** → kicks off `_start_dialogue(RegionalDialogues.get_tree(dialogue_tree_id), _show_regional_npc_panel.bind(npc))`, reusing the existing dialogue machinery.
- **Skill-check social section** (`_add_social_section`) — same pattern the Blacksmith/Library/Tavern use today, so there's always a small spread of one-shot interactions even without pulling the full dialogue tree. Per-NPC customization via the `social_interactions` key.
- **No Recruit button.** Explicit flag: `recruitable: false` is the default and is checked before showing any recruit UI.

Cooldown story: dialogue flags live in `regional_npc_state[id].dialogue_flags`, so repeated talks don't re-award intel/gold. Standard pattern: set a flag in the reward string (`consequence:intro_done`) and the first node checks `if flag present → skip to small-talk node`.

---

## 7. Save / load

`GameState.save_game()` (lines 972–1135) serializes everything into a single JSON blob with a version field (currently 4). Plan:

1. Add `regional_npc_state` to the save dict around line 1110 (near `bounty_per_region`).
2. Add restoration in `load_game()` at ~1196: `regional_npc_state = Dictionary(data.get("regional_npc_state", {}))`.
3. Bump save version to 5. Add a migration branch that treats absent `regional_npc_state` as `{}` so existing save files still load cleanly.

Static data (`REGIONAL_NPCS`, dialogue trees) is **not** saved — it's code. Only mutable per-NPC state is serialized.

---

## 8. Implementation phases

| Phase | Scope | Delivers |
|-------|-------|----------|
| **P1** | Plumbing | `regional_npcs.gd` skeleton (empty dict), `regional_npc_state` on GameState, marker spawn path in explore.gd, `_show_regional_npc_panel` stub. Save/load wiring. |
| **P2** | One subregion end-to-end | Author **The Argent Expanse** with 7 NPCs, full schedules, full dialogue trees, quest hooks. Ship. Playtest. |
| **P3** | V1 scheduling | Hook `_advance_time` → `_refresh_npc_schedules()`, snap-to-waypoint at hour boundaries. |
| **P4** | Expand content | Author remaining 29 subregions, 5–10 NPCs each. Biggest chunk of work — ~200 NPCs, ~200 dialogue trees. Can be parallelized by region or split into follow-up sessions. |
| **P5** | V2 polish | Tween-based walking between waypoints, path authoring helpers, silver-ring marker visual. |
| **P6** | Quest integration | Wire `quest_hooks` to real mission objects; add region-specific story beats that unlock new dialogue nodes. |

Each phase ends in a playable build. P1+P2+P3 is the minimum "feature complete" ship for one region; P4 is the content mountain.

---

## 9. Scope / scale estimate

- **Code:** ~600–800 LoC in explore.gd + a new 200-LoC `regional_npcs.gd` module + ~50 LoC save/load + ~150 LoC `regional_dialogues.gd` loader.
- **Content:** 30 subregions × 7 NPCs avg = **~210 NPC definitions**. Each with name, lineage, 4 waypoints, portrait color, 3–5-node dialogue tree, 2–3 skill-check social actions. Rough authoring cost: **~15 minutes per NPC × 210 ≈ 50 hours of writing** if you do it yourself. I can generate draft rosters per region in bulk, but they'll need your pass for tone and story continuity.
- **Asset work:** none — reusing `CharacterModelBuilder.build_sprite_model()`. Could swap to distinct portraits later.

---

## 10. Open questions for Blaine

1. **Granularity** — per-subregion (30 rosters, ~210 NPCs) or per-region (10 rosters, ~70 NPCs shared across sibling maps)? *Design above assumes per-subregion.*
2. **Movement in V1** — is snap-teleport at hour thresholds acceptable, or is smooth walking required from day one?
3. **Dialogue density** — does every NPC need a branching tree with skill checks, or is a "linear 3-line monologue + 2 skill-check social actions" enough for most? The latter is ~5× faster to author.
4. **Quest hooks** — should NPCs drive brand-new missions, or just *hint at / reflect* existing missions (bounty board, ACF briefings)? The latter is a drop-in; the former means designing new mission structures.
5. **Name reuse** — the existing 20 `NAMED_NPCS` are assigned by region; should they *become* the region's regulars (and we fill around them), or stay separate?
6. **Visibility** — should regulars be visible on the tactical minimap, or only the explore map? (Existing random NPCs are explore-only.)
7. **First region to ship** — P2 picks one subregion for the end-to-end prototype. Default = The Argent Expanse (plains, well-understood). Any reason to pick a different one?

---

## 11. Risks

- **Content bloat** — 200+ NPCs is a real writing commitment; if half get shipped with placeholder "Hello, traveler" lines, the feature will feel worse than the current empty maps. Mitigation: don't ship a subregion until its roster is fully written.
- **Hour-boundary pop-in** — V1 snap-teleport may look strange. Mitigation: V2 tweening behind a toggle.
- **Save schema drift** — any change to the NPC-state shape after ship requires a migration. Mitigation: version bump + defensive `get(…, default)` everywhere.
- **Click ambiguity** — with 5–10 regulars plus random NPCs plus POIs on a 30×22 grid, tile collisions become likely. Mitigation: marker z-priority (regulars > random), and a tiebreak rule when multiple NPCs share a tile.

---

## Recommendation

Ship P1–P3 as a tight vertical slice with The Argent Expanse fully authored (~7 NPCs). That proves the system, catches UX issues early, and gives us a template to copy-paste for the remaining 29 subregions. Don't pre-author content for subregions before the plumbing is validated.
