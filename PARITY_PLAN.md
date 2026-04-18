# Rimvale PC — Mobile Parity Plan
*Generated from full code audit of both codebases*

---

## How to read this document

Each phase is ordered by gameplay importance. Within each phase, steps are ordered from most-blocking to least-blocking. A step marked **[ENGINE]** requires changes to `rimvale_fallback_engine.gd` or the GDExtension C++. A step marked **[UI]** is purely a Godot scene/script change. Steps marked **[BLOCKER]** must be done before dependent steps.

---

## PHASE 1 — Core Gameplay Loops (Nothing Playable Without These)

### 1.1  Quest Completion & Rewards  **[ENGINE + UI] [BLOCKER]**
*Mobile: quests have 3 parts × 3 challenges each; completing all 9 challenges pays gold + XP and saves to StorageManager.*

**What's missing:**
- Dungeon Dive currently only configures an encounter — it never launches and never returns a result.
- Quest progress is never written to `GameState` between sessions.
- Gold/XP rewards are never granted.

**Steps:**
1. Add `quest_state` dict to `GameState` (active missions, progress per challenge, completed IDs).
2. Add `complete_quest(quest_id, gold, xp)` to `GameState` that calls `save_game()`.
3. In `world.gd` → Quests tab: wire "Deploy" button to actually launch the dungeon scene, passing the mission's enemy config.
4. When `dungeon.gd` exits with a "victory" result, write outcome to `GameState.quest_state` and call `complete_quest()`.
5. Show a reward summary dialog (gold + XP gained) before returning to the World tab.

---

### 1.2  Dungeon Dive — All Six Encounter Types  **[ENGINE + UI] [BLOCKER]**
*Mobile: Standard / Kaiju / Apex / Militia / Mob all launch properly with distinct enemy configs. PC currently has the selector UI but never calls `start_dungeon` with the right params.*

**Steps:**
1. **Standard**: already partially working. Verify `start_dungeon(handles, difficulty, terrain_style, encounter_type=0)` is called correctly.
2. **Kaiju** (type 1): Pass the selected kaiju name and level (12–15); spawn a single high-HP enemy with boss loot table.
3. **Apex** (type 2): 21 pre-set bosses (Varnok, Lady Nyssara, Malgrin, etc.) — each needs a stat block in `rimvale_fallback_engine.gd`. Mobile uses levels 1–20.
4. **Militia** (type 3): Spawn a squad with shared HP/AP/SP pool. Add `militia_pool_hp` to entity group logic.
5. **Mob** (type 4): Spawn 10–100 enemies using the configurable size/level sliders in `world.gd`.
6. Wire the "Launch" button in each `world.gd` sub-panel to call the correct `start_dungeon` variant.

---

### 1.3  XP & Player-Level Progression  **[ENGINE + UI]**
*Mobile: player (summoner) level progresses via XP, gates unit level caps and spell learning. PC has the UI but XP never increases from gameplay.*

**Steps:**
1. In `rimvale_fallback_engine.gd` → `_dung_get_xp_reward()`: calculate `15 + (round * 2)` and return it.
2. In `dungeon.gd` → `_handle_victory()`: call `GameState.player_xp += xp_reward`, check level-up threshold, call `save_game()`.
3. In `profile.gd` → rank progression table: map level → rank string (Recruit → Agent → Operative → … → Grandmaster).
4. Enforce level cap on unit level-up: unit level ≤ player level.
5. Add XP from quest completion (50–500 range based on difficulty) in `world.gd`.

---

### 1.4  Crafting — Full Timer & Result Loop  **[ENGINE + UI]**
*Mobile: crafting tasks run for `cost_gp / 5 * 8` hours, produce the item on completion, auto-save progress.*

**Steps:**
1. Add to `GameState`: `crafting_tasks` (Array of `CraftingTask` — already defined but never populated from UI).
2. In `world.gd` → Crafting tab → "Start" button: validate gold, deduct 50% market cost, create `CraftingTask` with `end_time = Time.get_unix_time_from_system() + duration_seconds`.
3. Mark character as `busy` in `GameState.busy_handles`.
4. On tab revisit / game load: scan tasks, complete any whose `end_time` has passed — call `_e.add_item_to_inventory(handle, item_name)`, remove from task list, unmark busy.
5. Display time-remaining countdown per active task.
6. Persist tasks in `save_game()` / `load_game()` (the `CraftingTask` class exists in `GameState` already).

---

### 1.5  Foraging — Full Timer & Reward Loop  **[ENGINE + UI]**
*Mobile: 4-hour foraging tasks yield random items + gold. Same pattern as crafting.*

**Steps:**
1. In `world.gd` → Foraging tab → "Send" button: create `ForageTask(handle, forage_type, end_time = now + 4*3600, gold_reward)`.
2. On revisit: complete expired tasks — grant gold via `GameState.earn_gold(task.gold_reward)`, log "recent findings".
3. Persist `forage_tasks` in save/load (struct already in `GameState`).
4. Show task status and ETA per character in the Foraging tab.

---

### 1.6  Ritual System — Full Execution  **[ENGINE + UI]**
*Mobile: requires Ritualist feat, lets players design spells, roll against DC (10 + SP committed), retry with +1 SP, succeed → spell becomes active in dungeon.*

**Steps:**
1. In `world.gd` → Rituals tab: pull the Spell Builder form from `level_up.gd`'s Magic tab (refactor into a shared scene or helper function).
2. Add "Commit SP" input and "Cast Ritual" button.
3. On cast: call `_e.ritual_check(handle, spell_def, sp_committed)` — implement in fallback engine as a dice roll vs `10 + sp_committed`.
4. On success: push to `GameState.active_rituals` (already defined); remove from `ritual_tasks`.
5. On failure: keep task, increment required SP by 1, log result.
6. In `dungeon.gd`: wire ritual spells into the cast menu for the matching character.
7. Persist `ritual_tasks` and `active_rituals` in save/load (both arrays exist in `GameState` already).

---

## PHASE 2 — Story & Mission Systems

### 2.1  Story Tab — Section Unlock Chain & Badge System  **[UI]**
*Mobile: 9 regional story sections unlock in chain; completing all 3 missions in a section earns a badge; all 9 badges unlock the Final Confrontation.*

**Steps:**
1. `world.gd` Missions/Story tab: check `GameState.story_completed_missions` before rendering each mission as enabled/locked.
2. On mission complete: add mission ID to `story_completed_missions`, check if all 3 in a section are done → add section badge to `story_earned_badges`.
3. "Final Confrontation" unlock button: only enabled when `story_earned_badges.size() == 9`.
4. Persist both arrays (already in `GameState`).
5. Display earned badges visually in the Story tab (check marks or badge icons per section).

---

### 2.2  Random Contract Generation & Deployment  **[ENGINE + UI]**
*Mobile: "Mission Control" generates random contracts by region, shows objectives, tracks 3-part progress.*

**Steps:**
1. Implement `_e.generate_contracts(region)` in fallback engine — return 3–5 randomized contract dicts with name, description, part count, difficulty, gold reward.
2. In `world.gd` → Quests tab: "Generate" button calls this and populates the list.
3. "Accept" button sets contract as active, writing to `GameState.quest_state`.
4. Progress (parts 1–3 each with 3 challenges) advances on dungeon victory tied to that contract's difficulty.

---

## PHASE 3 — Combat & Dungeon Depth

### 3.1  Dungeon — All 22 Action Types Fully Wired  **[ENGINE + UI]**
*Mobile has 22 distinct action types. The PC fallback engine has most, but not all are wired to buttons in `dungeon.gd`.*

**Missing actions to add:**
- **Reload (15)**: Ranged weapons need ammo reload action; button should appear only when ranged weapon is equipped and out of ammo.
- **Interact (14)**: Object interaction on dungeon tiles (doors, chests, levers). Currently no object entities exist.
- **Spell Matrix Trigger (16)**: Activate a prepared spell matrix — sustained spells must persist turn-to-turn. The action column needs a "Matrices" sub-category showing active matrices.
- **Matrix End (17)**: Button per active matrix to terminate and reclaim SP.
- **Lineage trait actions**: 40+ lineage traits. Currently the fallback engine handles `ACT_LINEAGE_TRAIT` generically but the action list returned per character doesn't include lineage-specific entries. Need `get_lineage_actions(handle)` in fallback engine that returns trait dicts based on character lineage.
- **Feat actions**: Deep Reserves, Reroll, Advantage, Unstoppable Assault etc. — map `ACT_FEAT_ACTION` types.

**Steps:**
1. Add `get_lineage_actions(handle)` to fallback engine — look up lineage in `LINEAGE_REGISTRY`, return appropriate action dicts.
2. In `dungeon.gd` → `_populate_action_columns()`: add a 4th "Traits" column or integrate lineage actions into Abilities column.
3. Wire Reload, Interact, Matrix Trigger/End into the action dispatcher.
4. Add "Matrices" section to right panel showing sustained spells with terminate buttons.

---

### 3.2  Enemy AI — Elevation, Retreat, and Ranged Behaviour  **[ENGINE]**
*Mobile's `DungeonViewModel` enemy AI accounts for elevation advantage, ranged weapon fallback when melee is out of reach, and retreat when HP < 25%.*

**Current PC AI**: Enemies simply move toward nearest player and attack. No ranged, no retreat, no elevation logic.

**Steps:**
1. In fallback engine → `_run_enemy_turn()`: 
   - If enemy has ranged weapon and player is >2 tiles away, use ranged attack instead of closing.
   - If HP < 25% and there are allies alive, move away from players.
   - Check elevation: prefer moving to higher tile (elev 2) when adjacent.
2. Ranged attack range check: skip pathfinding, directly call `_dung_do_attack(ent, target, weapon, true)` with `is_ranged = true`.
3. Add `sight_range` check — enemies shouldn't charge from across the entire map.

---

### 3.3  Conditions — Full 33-Condition System  **[ENGINE + UI]**
*Mobile tracks 10 beneficial + 23 harmful conditions. PC engine has the array but only a handful affect gameplay.*

**Steps:**
1. In fallback engine: implement per-condition effects in `_dung_tick_conditions()` and attack/defence calculations:
   - **Blinded**: Disadvantage on attacks, cannot target beyond adjacent.
   - **Stunned**: Skip turn.
   - **Paralyzed**: Auto-fail STR/DEX saves, attacks against have advantage.
   - **Prone**: Ranged attacks have disadvantage, melee attacks have advantage, costs extra movement to rise.
   - **Restrained**: Speed 0, disadvantage on attacks, attacks against have advantage.
   - **Slowed**: Speed halved, -2 AC and DEX saves.
   - **Bleeding**: Take 1d4 damage at start of turn until treated.
   - **Dodging**: +2 AC until start of next turn.
   - **Hidden**: Cannot be targeted until revealed.
   - **Flying**: Ignore ground elevation, enemies without reach/ranged can't attack.
2. In `dungeon.gd` entity card: display active conditions as coloured tags (beneficial = green, harmful = red).

---

### 3.4  Dungeon Objects — Doors, Chests, Triggers  **[ENGINE + UI]**
*Mobile dungeons include interactive objects. PC dungeons are currently flat empty rooms.*

**Steps:**
1. Add `_dungeon_objects: Array` to fallback engine — each object has `{type, x, y, state, loot}`.
2. During map generation: randomly place 1–3 chests (loot on interact), 0–2 locked doors.
3. In `dungeon.gd` 3D view: render chest/door meshes in `_rebuild_3d_tiles()`.
4. Interact action (type 14): check `_dung_entity_at(tx, ty)` for objects, open chest or door.
5. Chest loot: add items to stash, show loot popup (already implemented for enemy corpses).

---

## PHASE 4 — Tab & Screen Completeness

### 4.1  Team Tab — Trading & Stash Improvements  **[UI]**
*Mobile: trading tab fully functional. PC shows "trading coming soon" notice.*

**Steps:**
1. Replace the "coming soon" notice with an actual trade flow: select unit from collection → set offer (gold + items) → resolve.
2. For MVP: implement a simple "buy from director" market — fixed list of available lineages at token prices.

---

### 4.2  Character Creation — Skill Points Step  **[UI]**
*Mobile: step 4 is a full skill points allocation screen. PC currently says "assign during leveling" (stub).*

**Steps:**
1. In `character_creation.gd` step 3 (Assign Skills): replicate the skill rank +/− UI from `level_up.gd`.
2. Award 5 starting skill points.
3. Enforce rank cap of 5 at creation (higher ranks require leveling).

---

### 4.3  Level-Up — Custom Spell Save Button  **[UI]**
*Mobile: Spell Builder has a "Register Custom Spell" button. PC builds the form and calculates cost but never saves.*

**Steps:**
1. Add "Save Spell" button at the bottom of the Spell Builder in `level_up.gd`.
2. On press: call `_e.register_custom_spell(handle, spell_dict)` — already implemented in fallback engine as `register_custom_spell`.
3. Show the spell in the Spellbook sub-tab after saving.

---

### 4.4  Profile Tab — Rank Progression  **[UI]**
*Mobile: rank advances Recruit → Agent → Specialist → Operative → Veteran → Elite → Master → Grandmaster based on player level.*

**Steps:**
1. Add `_rank_for_level(level: int) -> String` to `profile.gd` using the mobile rank thresholds.
2. Replace the hardcoded "Agent" rank label with the computed value.
3. Save rank to `GameState.player_rank` on level-up.

---

### 4.5  Codex — Make Feats Learnable from Codex  **[UI]**
*Mobile: Codex feats show an "Unlock" button when the player has points. PC is read-only.*

**Steps:**
1. When a character is selected (via `GameState.selected_hero_handle`), show an "Unlock" button on feats the character can afford.
2. This reduces friction — players shouldn't need to navigate to Level-Up just to buy a feat.

---

### 4.6  Shop — Stable Pricing & Sell-to-Director  **[UI + ENGINE]**
*Mobile: item prices are deterministic from item type/rarity, not random per session.*

**Steps:**
1. Add `get_item_base_price(item_name)` to fallback engine — returns fixed gold cost from item database.
2. In `shop.gd`: replace `randi_range()` price generation with this function.
3. Add a "Sell to Director" mode: sells items from stash at 50% fixed price.

---

## PHASE 5 — Polish & Feature Depth

### 5.1  Daily Login Bonus  **[UI]**
*Mobile awards +10 tokens per day on first login.*

**Steps:**
1. Store `last_login_date` in `GameState` save file.
2. On `_init_game()`: if date differs from today, grant 10 tokens and update the date.
3. Show a brief "Daily bonus: +10 tokens" toast notification.

---

### 5.2  Combat Screen (Non-Dungeon)  **[ENGINE + UI]**
*Mobile has a simple turn-based combat screen (no grid map) used for story mission challenges — separate from the dungeon system.*

**Steps:**
1. Create `scenes/combat/combat.gd` (file exists but may be a stub — verify).
2. Layout: enemy card (HP/AC/threshold) + team grid (2×2 status cards) + action menu + combat log.
3. Wire to story missions and quest challenges as the encounter resolver.
4. Actions: Attack, Punch, Cast Spell, Dodge, Rest, End Turn (subset of dungeon actions, no grid movement).

---

### 5.3  Condition Display in All Unit Cards  **[UI]**
*Mobile shows condition badges on every hero card, entity card, and enemy bar.*

**Steps:**
1. In `team.gd` hero cards: add a `HBoxContainer` of condition chip labels below the stat bars.
2. In `dungeon.gd` left-panel entity card: add condition tags (already partially present via `_lp_conditions` label — replace text with coloured chips).
3. In `dungeon.gd` bottom bar badge: display first 3 conditions as abbreviated tags.

---

### 5.4  Light Sources in Dungeon  **[ENGINE + UI]**
*Mobile: equipped light sources (Torch/Lantern/Lamp/Candle) affect vision radius (base 12–24 ft). PC fog-of-war doesn't account for equipped items.*

**Steps:**
1. In fallback engine → `_update_fog()`: check each player entity's `equipped_light` item, set vision radius accordingly (Candle=12ft, Torch=18ft, Lantern=24ft, Lamp=18ft, Dark=8ft).
2. Radius in tiles = vision_radius / 5.

---

### 5.5  Injury System  **[ENGINE + UI]**
*Mobile: characters can sustain named injuries ("Limping", "Broken Arm") that impose ongoing penalties. These are separate from conditions.*

**Steps:**
1. Add `injuries: Array` to entity dict in fallback engine.
2. When HP drops below 25%: roll a d6; on 1–2 apply a random injury.
3. Injuries persist after dungeon (saved to character in `GameState`).
4. Display in hero card under conditions.

---

### 5.6  Loot Table Depth  **[ENGINE]**
*Mobile enemy loot tables include equipment, consumables, and gold amounts scaled to enemy level. PC loot is currently stub-level.*

**Steps:**
1. Add `_dung_loot_table(enemy_name, level)` to fallback engine returning a dict `{items: [], gold: int}`.
2. Scale gold to `3 + level * 2` + `randi_range(0, level)`.
3. Item pool: tier 1 items for levels 1–5, tier 2 for 6–10, magic items possible at 8+.

---

### 5.7  Mob & Kaiju Boss Stat Blocks  **[ENGINE]**
*Mobile has full stat blocks for 6 kaiju and 21 apex bosses. PC has names but no engine data.*

**Steps:**
1. Add `KAIJU_STATS` and `APEX_STATS` dictionaries to fallback engine with HP/AC/AP/SP/speed/attacks for each boss.
2. `start_dungeon` with type 1 (kaiju) or type 2 (apex): use these dictionaries to spawn the boss entity.

---

### 5.8  World Tab — Base Tab Placeholder Replacement  **[UI]**
*Mobile shows "Base — Coming Soon." PC should match this or add basic base functionality.*

**Steps:**
1. If implementing: add a "Base" tab in `world.gd` that shows a building slots grid (5 slots), lets players assign units to "staff" buildings for passive bonuses.
2. If not ready: add a styled "Coming Soon" placeholder matching mobile's layout.

---

## PHASE 6 — Data & Persistence Completeness

### 6.1  Save/Load — All Missing Fields  **[ENGINE]**
*The current `game_state.gd` save does not persist: quest_state, crafting tasks, forage tasks, active rituals, conditions on characters, injuries.*

**Steps:**
1. Add `quest_state` serialization to `save_game()` / `load_game()`.
2. Add `crafting_tasks` to save — serialize `CraftingTask` dicts (the class exists but save doesn't write it).
3. Add `forage_tasks` to save.
4. Add `active_rituals` and `ritual_tasks` to save.
5. Add per-character `conditions` and `injuries` to the character data block in `chars_data`.

---

### 6.2  Character Stat Persistence — Full Round-Trip  **[ENGINE]**
*Currently only `hp`, `max_hp`, `ac`, `speed`, `xp` are saved per character. Skills, feats, spells, alignment, domain, societal roles, light source, shield are all lost on restart.*

**Steps:**
1. Expand `save_game()` character entry to include: `skills`, `feats` (learned feat IDs), `spells` (learned spell list), `alignment`, `domain`, `roles`, `equipped_shield`, `equipped_light`.
2. Expand `load_game()` to restore all these via `_e.spend_feat_point()`, `_e.learn_spell()`, etc.
3. Restore `sp` (spark points) and `max_sp` — currently only `hp`/`max_hp` are round-tripped.

---

## Priority Order Summary

| Priority | Phase | Description |
|---|---|---|
| P0 | 1.1, 1.2 | Quest completion + all dungeon types — game is not playable without these |
| P1 | 1.3, 3.1 | XP system + full action types in dungeon |
| P2 | 1.4, 1.5, 1.6 | Crafting / Foraging / Rituals timers |
| P3 | 2.1, 2.2 | Story progression + contract system |
| P4 | 3.2, 3.3 | Enemy AI depth + full condition effects |
| P5 | 4.1–4.6 | Tab-level polish (skills step, custom spell save, rank, etc.) |
| P6 | 5.1–5.8 | Polish & feature depth (loot, boss stat blocks, injuries, etc.) |
| P7 | 6.1–6.2 | Full save/load round-trip for all fields |

---

*Total estimated steps: ~65 discrete tasks across both engine and UI layers.*
