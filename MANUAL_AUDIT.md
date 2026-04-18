# Rimvale PC — Manual Audit Report
*Generated from PHB v0.943, GMG v0.942, WG v0.942 cross-referenced against Rimvale PC Godot codebase*

---

## ✅ Fixed This Session (Session 4 — AC, AP Regen, Level-Up, Shop)

| Issue | File(s) Changed | Notes |
|---|---|---|
| **Unarmored AC flat 10** — should be `10 + Speed` (PHB) | rimvale_fallback_engine.gd | `_compute_ac()` now returns `10 + SPD` when no armor equipped |
| **Light armor ignoring Speed** — PHB: `11/12 + Speed` | rimvale_fallback_engine.gd | `_armor_ac_with_speed()` added; Padded/Leather = 11+SPD, Studded = 12+SPD |
| **Medium armor ignoring Speed** — PHB: `12–15 + Speed (max 2)` | rimvale_fallback_engine.gd | Hide/Chain Shirt/Scale/Breastplate/Half Plate use `+ mini(SPD, 2)` |
| **Shield AC bonus not applied** — Standard +2, Tower +3 stored but never added to AC | rimvale_fallback_engine.gd | `_compute_ac()` adds shield bonus; `equip_item()` and `unequip_item()` call it |
| **AP regeneration wrong** — full AP restore each round (PHB: regain STR score AP) | rimvale_fallback_engine.gd | Round start reduces `ap_spent` by STR score (min 1) for player characters |
| **Level up granted no points** — no skill/stat points awarded on level | game_state.gd, rimvale_fallback_engine.gd | `level_up_character()` grants 1 stat + 3 skill pts; called from `check_level_up()` |
| **Sell price 40%** — PHB: sell-to-director is 50% | shop.gd | Changed to 50% |

---

## ✅ Fixed This Session (Session 3 — Spell/Feat/Lineage Implementation)

| Issue | File(s) Changed | Notes |
|---|---|---|
| **Attack roll formula wrong** — all attacks used flat +3 bonus | rimvale_fallback_engine.gd | Now: STR weapons = D20+STR+Exertion; SPD/finesse/ranged = D20+SPD+Nimble; hit_bonus_buff field supports trait/feat bonuses |
| **Spell attack roll wrong** — used flat +3 | rimvale_fallback_engine.gd | Now: D20+DIV+Arcane (reads from character sheet) |
| **Only 15 lineages had trait mappings** — 145+ got generic fallback | rimvale_fallback_engine.gd | _lineage_traits_for() now maps all 160+ lineages to their specific trait IDs |
| **Trait dispatch used keyword guessing** — effects were random | rimvale_fallback_engine.gd | _dung_dispatch_trait() now has proper per-trait-ID effects: healing, AoE damage, conditions, debuffs, self-buffs |
| **Feat passive bonuses not applied** — stored but never used | rimvale_fallback_engine.gd | recalculate_derived_stats() now applies Iron Vitality (HP×2/3), Arcane Wellspring (SP×2/3), Martial Focus (AP×2/3), Unyielding Defender (+1-3 AC) |
| **Dungeon entities missing hit_bonus_buff field** | rimvale_fallback_engine.gd | Player entities now start with hit_bonus_buff=0 and feat_ac_bonus applied to AC |
| **_get_enemies_in_burst() helper missing** | rimvale_fallback_engine.gd | Added: returns all enemies within Chebyshev radius N of actor |

---

## ✅ Fixed This Session (Session 2 — Manual Audit)

| Issue | File(s) Changed | Notes |
|---|---|---|
| **Item categories in shop** — Scimitar, Rapier, Katana, Flail, Maul, Halberd, Pike, Whip, Trident, Blowgun, Musket, Pistol, Padded, Leather, Hide, Studded Leather all fell through to "Misc" | shop.gd | Now uses registry type directly; fallback expanded |
| **equip_item() missed many items** — Padded, Studded Leather, Chain Shirt, Hide, Breastplate, Half Plate, Splint, Scimitar, Rapier, etc. not recognized | rimvale_fallback_engine.gd | Added `_ARMOR_EXACT`, `_WEAPON_EXACT`, `_LIGHT_EXACT` lookup arrays |
| **Consumables shop tab** — Potions etc. had no filter category | shop.gd | Added "Consumable" filter tab |
| **HP/AP/SP formulas wrong** — game used hardcoded defaults instead of PHB formulas | character_creation.gd, rimvale_fallback_engine.gd | HP=3+3×Lv+VIT; AP=3+STR; SP=3+Lv+DIV; `recalculate_derived_stats()` added |
| **Starting skill points = 3** (should be 12 per PHB) | character_creation.gd | Fixed to 12 |
| **Skill names were D&D 5e names** — Athletics, Acrobatics, etc. | character_creation.gd | Changed to Rimvale PHB names: Arcane, Crafting, Creature Handling, Cunning, Exertion, Intuition, Learnedness, Medical, Nimble, Perception, Perform, Sneak, Speechcraft, Survival |
| **Creation rank cap missing** — could go to rank 10 at creation | character_creation.gd | Capped at rank 5 (PHB: higher ranks require leveling) |
| **Starting stat points = 5** (PHB says 6) | character_creation.gd | Fixed to 6 |
| **Starting gold = age × 10** (PHB: 30 + (age-20) × 5) | character_creation.gd | Fixed to PHB formula (age 34 → 100 gold) |
| **Combat screen missing Dodge, Ranged, Item buttons** | combat.gd | Added all three plus loot properly pushed to GameState.stash + XP award |

---

## 🔴 High Priority — Missing from PC (not yet implemented)

### HP and AC Formulas
- ~~**Unarmored AC**~~ ✅ Fixed: `10 + Speed` (PHB). `_compute_ac()` handles all armor types with Speed modifier.
- **Age factor**: HP should degrade at ages 80–89 (2 HP/level instead of 3) and 90+ (1 HP/level). Not implemented.
- ~~**AP regeneration**~~ ✅ Fixed: Players regain STR score AP per round (min 1). Enemies still get full reset.

### Stat-Based Calculations
- ~~**Attack rolls**~~ ✅ Fixed: Strength weapons: D20+STR+Exertion; Speed weapons: D20+SPD+Nimble; Spell attacks: D20+DIV+Arcane
- **Initiative** should be a Speed check (D20 + Speed).
- **Jump distance**: (Exertion + Intellect) × Strength (min 5ft). Not implemented.

### Character Sheet Display
- **Stat descriptions** don't show influence on derived stats in UI. Need tooltips or descriptions showing "STR affects AP, carry capacity" etc.
- **Favored Skills**: Characters can have Intellect-score number of favored skills (take-10 passively). Not wired to gameplay.

### Skill System
- **Skill checks in non-combat**: Minor (DC 1–10), Moderate (DC 11–20), Major (DC 21–30). No skill check system outside of dungeon.
- **Taking 10**: Cost 1 hour, take 10 + skill + INT instead of rolling. Not implemented.
- **Skill usage in dialogue/exploration**: Speechcraft, Intuition, Learnedness etc. have no moment of use in PC.

### Combat Depth
- **AP costs are wrong**: PHB says Basic actions cost 1 AP (2nd use = 2, 3rd = 3), Move action costs 0 (2nd = 1). Currently fixed costs.
- **AP regeneration per turn**: Characters regain Strength AP at start of turn. Missing.
- **Repeated action costs**: Same action twice in a round = doubled AP cost. Not tracked.
- **Reactions**: Opportunity attacks, parry, defense reaction (trade AP for damage reduction) — partially implemented, need full wiring.
- **Death saving throws**: DC 10 flat roll; 3 passes = stable, 3 fails = dead; nat 20 = 2 passes; nat 1 = 2 fails. Not implemented.
- **Dying/Death states**: Near Death, Dying, Dead statuses. Currently just HP = 0 = dead.

### Injury System (partial)
- PHB has two injury tables: **Bloodied** (d12, triggered at <2/3 HP) and **Near Death** (d12, triggered at <1/3 HP). Both tables exist in PHB but only basic injury names are in the engine.
- Recovery conditions (DC 12 Medicine check, long rest, magical healing) not tracked.

---

## 🔮 Magic System Audit (PHB Ch. 13 vs. Implementation)

### ✅ Already Implemented Correctly
| Feature | Where | Notes |
|---|---|---|
| SP pool formula `3 + Level + Divinity` | `recalculate_derived_stats()` | Matches PHB |
| 4 Magic Domains (Biological, Chemical, Physical, Spiritual) | `_SPELL_DB`, spell builder `DOMAIN_EFFECTS` | All spells tagged with domain |
| Spell attack roll `D20 + DIV + Arcane` | `_spell_apply_to_target()` line 4748 | Session 3 fix |
| Sustained Casting via Spell Matrix | `_dung_register_matrix()`, `_dung_tick_matrices()` | Per-caster matrix list with rounds/focus/conds |
| End / Resume matrix as free action | `get_available_matrix_actions()` | Wired to dungeon UI |
| Custom spell builder uses PHB formula | `_calc_spell_cost()` in level_up.gd | Type + (Effect×Dur) + Range + Targets + Conds, × Area |
| Duration multipliers (1, 2, 3, 5, 10) | `DURATION_MULT` | Matches PHB (instant/1m/10m/1h/1d) |
| Range SP cost (0,0,1,2,3,6,10) | `RANGE_SP_COST` | Matches PHB table |
| Area multipliers (×1, ×2, ×3, ×10) | `AREA_MULT` | Matches single/10ft/30ft/100ft |
| Beneficial cost −2, Harmful cost +3 | `_calc_spell_cost()` | Matches PHB |
| Teleport distance SP scaling | `_dung_dispatch_spell()` teleport branch | 1 SP per 3 tiles (≈ 10 ft) |
| Bless/Curse condition effects | `_SPELL_DB` has 20+ entries | Tracked via condition system |
| Revivify at 1 HP | `_spell_apply_to_target()` | Triggers when healing a dead target |
| Learn/forget spells | `learn_spell()`, `forget_spell()` | Spellbook + spell builder save both register to `_SPELL_DB` |
| Character alignment + domain fields stored | `create_character()` | Default: `Unity` / `Physical` |

### 🔴 Missing — High Priority Magic Gaps

| PHB Rule | Status | Fix Location |
|---|---|---|
| **Spell save DC = `10 + Divinity`** | Not implemented — engine always does attack rolls, even for "saving throw" spells | `_dung_dispatch_spell()` needs to branch on `atk`=false spells that target unwilling foes → roll `D20 + target stat` vs `10 + caster DIV` |
| **Damage type special effects** (PHB Ch. 13 damage table) | `damage_type` stored in spell dict but never read during resolution | `_spell_apply_to_target()` should apply: Fire=1/turn burn, Cold=Slowed, Lightning=Stunned 1 rnd, Radiant=Blinded, Psychic=Dazed, Thunder=Deafened, Acid=−AC, Force=Prone, Poison=Poisoned, Necrotic=Bleed |
| **Damage type +SP cost modifier** | `DIE_SIDES_MOD` handles die bumps, but no per-type SP cost (PHB: some types cost +1–2 SP) | `_calc_spell_cost()` should add damage-type cost; `add_custom_spell()` needs it in formula |
| **Overreach / SP risk tables** | Not implemented — you just can't cast if SP < cost | Need 4 domain-keyed d10 risk tables; allow casting when SP < cost and roll consequences |
| **Magic source alignment** (Chaos / Unity / Void) | Stored on character but no effect | Aligned source → SP discount; cross-source → SP penalty. Needs region-aware flag too (regions currently list benefits/risks but aren't wired) |
| **Domain affinity** | Domain stored but no bonus for matching domain | Matched-domain spells should cost `−1` or `−2` SP (or floor at 1). Add to `_dung_dispatch_spell()` before deducting SP |
| **Life sacrifice for SP** | Not implemented | Needs Vitality DC 10 check + d4–d12 aging table → convert age to SP pool restore |
| **Can't cast new spell while sustaining** (PHB Spell Matrix rule) | Not enforced — you can stack arbitrary sustains | `_dung_dispatch_spell()` should reject new sustained casts above a limit (PHB: one matrix per Divinity score, or similar) |
| **Sustained spells suppressed when caster is incapacitated** | Partial — `"suppressed"` field exists on matrix but never toggled by conditions | Tick matrices: if caster has `incapacitated`/`unconscious`/`stunned`, flip `suppressed=true` and strip conditions from focus; restore on recovery |
| **Multi-target cost formula wrong** | `target_cost = 2^(N−2) × 2` gives only the last extra target's cost — PHB says cumulative sum | Should be `2 + 4 + 8 + … + 2^(N−1)` for N extra targets. Fix in `_calc_spell_cost()` |

### 🟡 Medium — Magic Polish Items

| PHB Rule | Status |
|---|---|
| **Dice step cost** | `DIE_SIDES_MOD = [0,1,2,3,4]` gives d4=0, d6=+1, d8=+2… but PHB says d4→d6→d8 step pattern is finer: see PHB healing/damage scaling table (1d4=1 SP, 1d6=2 SP, 1d8=3 SP, 1d10=4 SP, 1d12=5 SP, 2d4=3, 2d6=5, 2d8=7…). Confirm current formula matches; if not, rebuild table from PHB |
| **Ritual casting** | PHB allows permanent effects that commit SP from pool until dispelled. Not implemented. |
| **SP pool regional modifier** | Regions have `benefits: ["Spellcasting cost -1"]` or `risks: ["Spellcasting cost x2"]` in text, but not applied at cast time |
| **Spell Shaper feat** | Feat registry mentions it but no mechanics wired |
| **Domain-SP penalty reduction feats** (Bio/Chem/Phys/Spiritual Mastery) | Feats exist but not applied — should reduce off-domain penalty once domain penalties are implemented |
| **Hexkin Witchblood +2 Spell DC (1/SR)** | Trait text exists but spell DC system missing upstream |
| **Arcane Surge +2 spell attack/DC** | Trait dispatches a bonus buff to `hit_bonus_buff` but spell DC path absent |
| **Devour Essence regain SP = DIV** | Trait exists but may not wire to `restore_character_sp()` |

### 🟢 Low — Magic Flavor / Content

- **Rituals & crafted magic items** — PHB has full rules for permanently committing SP to items. Not implemented.
- **Crafting kits** (Alchemy, Tinker, Poisoner) — no in-game use yet.
- **Shape / empower / extend spell meta-options** — PHB implies advanced casters can modify spells mid-cast; out of scope for now.

---

## 🟡 Medium Priority — Incomplete or Placeholder

### Equipment
- **Weapon durability**: Each weapon has HP (Dagger=10, Longsword=20, Plate=60 etc.) that degrades on hit. PHB has full table. Not tracked in PC.
- **Armor durability**: Same — armor takes HP on each hit. Not implemented.
- **Weapon/Armor HP table** from PHB (Tables 44 & 45) should be in `_ITEM_REGISTRY`.
- ~~**Shields give +2 AC**~~ ✅ Fixed: Standard +2, Tower +3 applied via `_compute_ac()`.
- **Two-handed weapons**: Can't dual-wield heavy weapons without "Titan's Reach" feat. No enforcement.
- ~~**Armor AC formula for Light/Medium**~~ ✅ Fixed: Light = `11/12 + Speed`, Medium = `12–15 + Speed (max 2)` via `_armor_ac_with_speed()`.

### Character Stats
- **Carry capacity**: 100 lb + 100 lb per STR (Large = ×2, Small = ÷2). Not tracked.
- **Languages**: 2 from lineage + INT score more. Not tracked.
- **Age limits**: Age 20–80 range for creation; natural lifespan 80 + 2d20 years. GM rolls secretly.
- **Societal Role primary/secondary effects** not applied to character stats. Roles exist as a label but don't modify anything.

### Shop
- **Item prices should use registry prices** where available, not just hash-based. Registry already has correct PHB prices. `_load_shop_items()` should fall back to registry price when available.
- ~~**Sell price**~~ ✅ Fixed: 50% of buy price (PHB Sell-to-Director rate).

### Level Up
- ~~**Skill points on level up**~~ ✅ Fixed: `level_up_character()` in engine grants 1 stat + 3 skill pts; called from `check_level_up()` in game_state.gd.
- **XP thresholds**: PHB option 2 = creature level = XP. Three XP to level up (simple option the PHB prefers for group play).
- **Level 20 cap** and stat cap of 10 (costs 2 pts for ranks 6–10) are noted in PHB. Need enforcement.

---

## 🟢 Low Priority — Polish

### Alignments & Domains
- **Bonus feat at creation**: PHB says choosing an Alignment gives Tier 1 pact/scholar feat for free; choosing a Domain gives Tier 1 domain feat for free. Character creation only stores the choice but doesn't award the free feat.

### Conditions
- **Calm** condition: cannot take hostile actions. Not in `COND_BENEFICIAL`/`COND_HARMFUL` lists.
- **Invulnerable**: immune to damage. Not tracked.
- **Depleted**: doesn't auto-regenerate AP. Not tracked.
- **Enraged**: focused on single enemy, double AP to attack others. Not tracked.

### Magic System
- **SP costs**: PHB has a detailed spell cost formula: `SP = (Type + (Effect × Duration) + Range + Targets – Benefits + Harms) × Area`. The current spell builder uses a simplified cost. Should use this formula or at least display it.
- **Unity / Void / Chaos alignment**: Casting a spell aligned to your alignment is more effective; off-alignment spells are less effective. Not implemented.
- **Domain affinities**: Biological, Chemical, Physical, Spiritual each have spell domains. Domain-matched spells should cost less SP. Not implemented.

### Lineage Traits
- ~~**Lineage trait actions**~~ ✅ Fixed: All 160+ lineages now mapped to their specific trait IDs; `_dung_dispatch_trait()` has proper per-trait effects (healing, AoE, conditions, debuffs, self-buffs); `get_available_lineage_trait_actions()` already wires into dungeon UI

### Base Tab
- **Building slots** for Command Center, Alchemy Lab, Archives, Armory, Garden of Echoes, Resonance Chamber exist in the UI but have no game mechanics attached.

---

## 📋 Item Category Reference (from PHB)

| Category | Items |
|---|---|
| **Simple Melee Weapons** | Chakram, Club, Dagger, Greatclub, Handaxe, Javelin, Light Hammer, Mace, Quarterstaff, Sickle, Spear, Shortsword |
| **Simple Ranged Weapons** | Dart, Light Crossbow, Shortbow, Sling |
| **Martial Melee Weapons** | Battleaxe, Flail, Glaive, Greataxe, Greatsword, Halberd, Katana, Lance, Longsword, Maul, Morningstar, Pike, Rapier, Scimitar, Trident, Warhammer, War Pick, Whip |
| **Martial Ranged Weapons** | Blowgun, Hand Crossbow, Heavy Crossbow, Longbow, Heavy Sling, Musket, Pistol |
| **Light Armor** | Padded (AC 11+SPD), Leather (AC 11+SPD), Studded Leather (AC 12+SPD) |
| **Medium Armor** | Hide (AC 12+SPD max 2), Chain Shirt (AC 13+SPD max 2), Scale Mail (AC 14+SPD max 2), Breastplate (AC 14+SPD max 2), Half Plate (AC 15+SPD max 2) |
| **Heavy Armor** | Ring Mail (AC 14), Chain Mail (AC 16, Str 2 req), Splint (AC 17, Str 3 req), Plate (AC 18, Str 3 req) |
| **Shields** | Standard Shield (+2 AC), Tower Shield (+3 AC, Str 3 req) |

---

## 📋 PHB Formulas Quick Reference

| Stat | Formula |
|---|---|
| HP | 3 + 3 × Level + Vitality score |
| AP (max) | 3 + Strength score |
| SP (max) | 3 + Level + Divinity score |
| Unarmored AC | 10 + Speed score |
| Light Armor AC | 11 or 12 + Speed score |
| Medium Armor AC | 12–15 + Speed score (max +2 from Speed) |
| Heavy Armor AC | 14–18 (flat, no Speed bonus) |
| Initiative | D20 + Speed |
| Strength Weapon Attack | D20 + Strength (+ Exertion if proficient) |
| Speed Weapon Attack | D20 + Speed (+ Nimble if proficient) |
| Spell Attack | D20 + Divinity (+ Arcane if proficient) |
| Starting Gold | 30 + (Age − 20) × 5 |
| Starting Skill Points | 12 at Level 1 |
| Skill Points per Level | 3 per level after Level 1 |
| Stat Points at Level 1 | 6 |
| Stat Points per Level | 1 per level after Level 1 |
| Ranks 1–5 cost | 1 stat/skill point each |
| Ranks 6–10 cost | 2 stat/skill points each |
| Feat Points | awarded by GM; track in `feat_pts` |

---

*This report was generated after reading all three Rimvale game manuals (PHB v0.943, GMG v0.942, WG v0.942) and cross-referencing against the Godot 4 PC codebase.*
