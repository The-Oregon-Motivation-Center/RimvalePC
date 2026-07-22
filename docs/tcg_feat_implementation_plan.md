# Rimvale TCG — Full Feat Implementation Plan
### Stat · Weapons & Combat · Armor · Magic categories

**Scope:** 44 feats in the engine's `_FEAT_REGISTRY` under the four requested
categories. 12 are already live in the TCG; this plan covers the remaining 32
plus deepening the 12 that were ported at reduced fidelity.

**Source of truth:** `autoload/rimvale_fallback_engine.gd` → `_FEAT_REGISTRY`
(tier text) and `_LINEAGE_DETAILS`. Card side: `autoload/card_system.gd` →
`CARD_FEATS`, `_merged_feat_fx()`, `attack()`, `cast_spell()`,
`_recalc_character()`, `_compute_card_ac()`, `_damage_character()`.

---

## 1. Where things stand

The TCG feat system already has the right skeleton:

- `CARD_FEATS[name] = {seq: [tiers], tiers: {N: {desc, fx}}}` — real PHB tier
  ladders (1/3/5, 1/2/3, 1–5) with correct caps.
- Duplicate feat card → `_upgrade_feat()` steps to the next real tier; the new
  tier's `fx` **replaces** the old, matching how tabletop tiers restate benefits.
- `_merged_feat_fx()` unions feat + lineage-trait effects into one dict that
  every combat path reads.
- 28 effect primitives are wired (`hp_vit_mult`, `crit_at`, `dr`, `thorns`,
  `free_on_kill`, `spell_recast`, …).

**Live today (12):** Iron Vitality, Martial Focus, Arcane Wellspring,
Safeguard*, Unyielding Defender, Precise Tactician, Titanic Damage,
Swift Striker, Duelist's Path, Fury's Call, Rest & Recovery, Iron Fist,
Evasive Ward. (*Safeguard is in `_FEAT_REGISTRY` but **not** yet a card.)

**Not yet cards (32):** everything else below.

---

## 2. Triage — what each feat needs

### 2a. Tier A — implementable now with existing primitives (8 feats)

These need only new `CARD_FEATS` entries; no engine changes.

| Feat | Cat | Tiers | Card translation |
|---|---|---|---|
| Crimson Edge | Combat | 2/3/5 | Slashing weapons' die → d6/d8/d10 (`weapon_die_by_type`) |
| Iron Hammer | Combat | 2/3/5 | Bludgeoning die → d8/d10/d12 |
| Iron Thorn | Combat | 2/3/5 | Piercing die → d6/d8/d10; T3 also `ac_debuff_on_hit: 1` |
| Martial Prowess | Combat | 1/2/3 | `hit_bonus` 2/3/4; T3 `graze` (miss deals stat damage) |
| Weapon Mastery | Combat | 1/2/3 | `hit_bonus` +1, `reroll_ones` on damage, `crit_at` −1 |
| Titanic Bastion | Armor | 1/2/3/5 | Heavy armor: `ac_heavy_str`, then `dr` 2 → 4 |
| Balanced Bulwark | Armor | 1/3/5 | Medium armor: `ac_medium_stat`, T5 `counter_on_miss` |
| Unarmored Master | Armor | 1/2/4 | `ac_unarmored_spd_mult` 2, `dr_spd` (Xd4), T4 `dr` 3 |

*Requires 6 small primitives listed in §3 — trivial wiring, no subsystems.*

### 2b. Tier B — needs one new subsystem each (9 feats)

| Feat | Cat | Blocking subsystem |
|---|---|---|
| Elemental Ward | Armor | **Damage types + resist/immune** (§4.1) |
| Assassin's Execution | Combat | **Overkill/execute hooks** (§4.2) |
| Turn the Blade | Combat | **On-miss reactions** (§4.3) |
| Deflective Stance | Armor | On-miss reactions (§4.3) |
| Wall of the Battered | Armor | **Ally-protection redirect** (§4.4) |
| Tower Shield | Armor | Ally-protection redirect (§4.4) |
| Warp | Armor | **Persistent AC debuff stacks** (§4.5) |
| Grasp of the Titan | Combat | **Restrain condition** (§4.6) |
| Linebreaker's Aim | Combat | Cover — see §5, likely re-flavor |

### 2c. Tier C — needs a major subsystem (4 feats)

| Feat | Cat | Subsystem | Notes |
|---|---|---|---|
| Twin Fang | Combat | **Off-hand weapon slot** (§4.7) | 5 tiers, big payoff |
| Improvised Weapon Mastery | Combat | Off-hand + damage types | 5 tiers |
| Magic Expertise | Magic | **Spell attack/damage stats** (§4.8) | |
| Spell Shaper | Magic | Spell DC → card equivalent (§4.8) | |
| Effect Shaper | Combat | Same as Spell Shaper | |

### 2d. CUT — incompatible with the SP model (3 feats) ✅ decided

**Blood Magic**, **Master of Ceremonies**, and **Arcane Seal** all assume SP is
a *spendable pool consumed per cast*. In the TCG, SP is a **loadout budget** —
spent once when equipping spell cards, never at cast time.

**Decision: cut all three.** The SP budget model stays exactly as it is; no
spendable-pool refactor. This avoids approximating three feats into effects
that wouldn't resemble their tabletop versions, and keeps caster balance
untouched. (Arcane Seal was additionally redundant with Arcane Wellspring T5.)

### 2e. CUT — not portable to cards (5 feats) ✅ decided

Exploration/utility feats with no card-board analogue. **Decision: exclude**
them from the TCG pool rather than inventing unrelated effects:

- **Create Demiplane** (hidden) — item storage across sessions
- **Scryer** (hidden) — map-scale remote viewing
- **Transmuter's Precision** (hidden) — crafting economy
- **Soul Weaver** (hidden) — 24-hour resurrection ritual
- **Shapeshifter's Path** — full creature-builder subsystem (5 tiers)

Four of five are already `hidden: true` in the registry, so excluding them is
consistent with how the story game treats them.

**Partial exception:** **Grasp of the Forgotten** is portable and *fun* —
T1/T2/T3 summon spectral hands that become a Spectral Servant. In cards this
becomes a **token character card** placed into an empty slot (AC 10/13,
HP = level or 2×level). Needs §4.9.

---

## 3. New effect primitives (small, no subsystem)

Each is a key in a feat's `fx` dict, read at one wiring point.

| Primitive | Meaning | Wire into |
|---|---|---|
| `weapon_die_by_type` | `{"slashing": 8}` — floor a damage type's die | `attack()` damage roll |
| `ac_heavy_str` | Add STR to AC in heavy armor | `_compute_card_ac()` |
| `ac_medium_stat` | Add full STR *or* SPD in medium armor | `_compute_card_ac()` |
| `ac_unarmored_spd_mult` | AC = 10 + N×SPD unarmored | `_compute_card_ac()` |
| `dr_spd` | Reduce damage by Xd4, X = SPD | `_damage_character()` |
| `graze` | Misses still deal the attacking stat | `attack()` miss branch |
| `reroll_ones` | Reroll damage dice showing 1 | `attack()` damage roll |
| `ac_debuff_on_hit` | Target loses N AC until its turn | `attack()` hit branch |
| `execute_threshold` | Kill outright at ≤N HP remaining | `_damage_character()` |
| `counter_on_miss` | Free counterattack when missed | `attack()` miss branch |
| `temp_hp` | Temporary HP pool absorbing damage first | `_damage_character()` + card model |

**Estimated effort:** ~1 hour total. All follow the existing `fx.get(...)`
pattern already used by 28 primitives.

---

## 4. New subsystems

### 4.1 Damage types + resistance/immunity — *moderate, high value*
Weapons and spells already carry `dt` (`slashing`, `fire`, …). Add
`resist: [types]` / `immune: [types]` to `fx`; in `_damage_character()`, halve
or zero damage by the incoming `dt`. Requires threading `dt` through the damage
call (currently `_damage_character(player, slot, dmg, source)` → add a `dt`
param, default `""`).
**Unlocks:** Elemental Ward, Titanic Bastion T3/T5, Unarmored Master T4,
Crimson Edge/Iron Hammer/Iron Thorn "ignore resistance" clauses, and 20+
lineage traits that could use it later.

### 4.2 Overkill / execute — *small*
Track excess damage in `_damage_character()`; expose it so Assassin's Execution
T2 ("excess ≥ max HP → instant death") and T3 can fire.

### 4.3 On-miss reactions — *small*
The miss branch of `attack()` already has both cards in scope. Add a defender
hook: `counter_on_miss` (free counterattack), `ac_on_evade` (+1 AC until its
next turn). **Guard against infinite loops** — a counterattack must not itself
trigger counters (pass a `is_counter` flag).

### 4.4 Ally-protection redirect — *moderate*
"When an ally within 5 ft is hit, take the hit instead." Cards have no
adjacency; translate to **any friendly slot**, with the protector limited to
once per round (`protect_used`). Needs a pre-damage hook in `attack()` that
scans the target's side for a protector.
**Unlocks:** Wall of the Battered (5 tiers), Tower Shield (3 tiers).

### 4.5 Persistent AC debuff stacks — *small*
Warp reduces target AC cumulatively. Add `ac_penalty: int` on the character
card, decremented/cleared at the start of its turn; `_compute_card_ac()`
subtracts it.

### 4.6 Restrained condition — *small*
Add `restrained` to `COND_DURATION` (no actions this turn, −2 AC). Grasp of the
Titan applies it on hit; also gives future lineages/spells something to use.

### 4.7 Off-hand weapon slot — *large, highest risk*
Add an `offhand` equipment slot to the character card (UI: fourth gear slot,
equip validation, gear line, detail popup). Attacks with a filled off-hand roll
a second attack at the normal cost. Twin Fang and Improvised Weapon Mastery
both depend on it.
**Recommend deferring** to its own phase — this touches the card model, the
equip UI, the AI, and the attack loop.

### 4.8 Spell power / spell DC translation — *moderate*
Card spells resolve as d20 + DIV vs target AC (no DCs). Map:
- "Spell DC = 10 + 2×DIV" → `spell_hit_bonus: DIV` (aim scales harder)
- "Add Arcane/DIV to magic attack **and damage**" → `spell_power` (exists) plus
  new `spell_hit_bonus`
- "Force reroll of a successful save" → **reroll a missed spell attack once**
  (`spell_reroll: 1`, once per round)
**Unlocks:** Magic Expertise, Spell Shaper, Effect Shaper.

### 4.9 Token summon cards — *moderate*
`summon_token(player, slot, template)` builds a minimal character card (name,
AC, HP, no deck origin, `is_token: true`) and places it in an empty slot. Dies
normally; never returns to hand or graveyard.
**Unlocks:** Grasp of the Forgotten, and later any summon spell card.

---

## 5. Concepts with no card analogue — the translation table

Applied consistently so players can predict what a feat will do:

| Tabletop concept | Card translation |
|---|---|
| Once per short rest / encounter | Once per **round** |
| Once per long rest | Once per **match** |
| Saving throw | Attacker's d20 vs the target's AC |
| Advantage / disadvantage | ±3 to the roll (cards roll one die) |
| Cover, 5 ft / 30 ft ranges, positioning | Dropped — free targeting, no geometry |
| Opportunity attacks, movement | Dropped |
| Proficiency grants | Dropped (cards have no proficiency gate) |
| Grapple | `restrained` condition |
| Temp HP | New `temp_hp` pool (§3) |
| Initiative | Dropped (fixed seat order) |

Feats whose *entire* tier is a dropped concept (e.g. Linebreaker's Aim T1
"ignore half cover") get a re-flavored equivalent of similar power — for
Linebreaker's that's `hit_bonus` vs targets behind other characters, or simply
exclude the feat. **Flag for decision.**

---

## 6. SP economy — settled ✅

**SP stays a loadout budget.** A card with 7 SP holds spell cards totalling
≤7 SP; casting is free, limited by AP and the once-per-round rule (twice with
Arcane Wellspring T5).

No spendable-SP-pool refactor will be done. The three feats that required one
(Blood Magic, Master of Ceremonies, Arcane Seal) are **cut** — see §2d. This
keeps cast validation, the AI's casting logic, every SP display, and all
caster balance exactly as they are today.

---

## 7. Phased implementation

Each phase ends with the static checker plus a play test, and is independently
shippable.

**Phase 1 — Tier A feats + primitives** ✅ **SHIPPED**
Added Crimson Edge, Iron Hammer, Iron Thorn, Martial Prowess, Weapon Mastery,
Titanic Bastion, Balanced Bulwark, Unarmored Master, and **Safeguard** (the
missing Stat feat, translated as a condition **ward**: d20 + ward vs 12 to
shrug off an incoming condition, with T5 healing on a successful ward).
Pool **12 → 21 feats**, all ladders verified against `_FEAT_REGISTRY`.

Primitives wired: `weapon_die_by_type`, `ac_heavy_bonus`, `ac_heavy_str`,
`ac_medium_bonus`, `ac_medium_stat`, `ac_unarmored_spd_mult`, `dr_spd`,
`graze`, `reroll_ones`, `ac_debuff_on_hit`, `counter_on_miss`, `cond_ward`,
`ward_heal`. Also shipped early from later phases: the **`DR_CAP = 6`**
ceiling (§8) and a centralized `_apply_condition()` that every condition
source now routes through (immunity → ward → apply).

**Phase 2 — Damage types + reactions** ✅ **SHIPPED**
Added Elemental Ward, Turn the Blade, Deflective Stance, Warp, Grasp of the
Titan, Assassin's Execution. Pool **21 → 27**, all ladders verified.

Shipped subsystems: **damage types** (`dt` now threads through
`_damage_character`, with `resist_elemental` halving and `immune_elemental`
zeroing the four elemental types); **execute thresholds** (`execute_hp`);
**on-miss reactions** (`ac_on_evade` sets the dodging guard, `ap_on_evade`
grants tempo, `counter_on_miss` retaliates); **AC-strip stacks**
(`ac_debuff_on_hit` → `ac_penalty`, cleared at the victim's turn start); and
the **restrained** condition (−3 AC, halved AP, cannot attack but may cast).
New primitive: `dr_stat` (soak damage equal to SPD).

Deviation from plan: Elemental Ward's "choose an element" is not portable —
cards have no prompt at equip time — so it wards **all four elemental types**
at once, scaling resist → immune across its tiers. Its T2 "return half damage
to origin" was **dropped**: `_damage_character` has no reference to the
attacker, and threading one through purely for that clause wasn't worth the
churn. T2 grants +1 AC instead.

**Phase 3 — Ally protection + magic feats** ✅ **SHIPPED**
Added Wall of the Battered, Tower Shield, Magic Expertise, Spell Shaper,
Effect Shaper. Pool **27 → 32**, all ladders verified.

Shipped subsystems: **team auras** (`_team_aura()` takes the strongest source,
never the sum — `team_ac` stiffens the whole line, `ward_ally` penalises
attacks on comrades); **guardian interception** (`protect_ally` — once per
round a defender steps into a blow aimed at an ally, and from that point the
guardian *is* the victim: damage, on-hit riders, thorns and the kill check all
follow them); **spell accuracy** (`spell_hit_bonus` folded into `spell_mod()`
so it also shows on the cast button, plus `spell_reroll` and `spell_pierce`);
and **condition potency** (`cond_potency` weakens a target's Safeguard ward,
`cond_extend` lengthens what lands — `_apply_condition()` now takes the
inflicter's fx).

Deviation: Tower Shield's cover/positioning clauses have no board geometry to
attach to, so its tiers became shield-AC scaling plus the same guardian and
ally-ward mechanics — thematically "the big shield protects the people behind
it" without needing ranks or facing.

**Phase 4 — Off-hand slot + summons** ✅ **SHIPPED**
Added Twin Fang, Improvised Weapon Mastery, Grasp of the Forgotten.
Pool **32 → 35**.

Shipped subsystems: the **off-hand weapon slot** (a second, different weapon
auto-routes there when the character can dual-wield — duplicates still forge
the main hand; attacks make a full second strike with its own to-hit roll,
costing +1 AP at Twin Fang T1 and free from T2, with a both-hit flourish die);
and **token summons** (`_summon_tokens()` places Spectral Hands/Servants into
empty slots when their summoner enters play; tokens fight and die normally but
never touch a deck, hand or graveyard — they dissipate, and cannot be stowed).

**Phase 5 — Linebreaker's Aim** ✅ **SHIPPED**
Re-flavored per §9.1: weapons now carry a `ranged` flag (Longbow, Heavy
Crossbow), and the feat grants `ranged_hit_bonus` / `ranged_dmg_bonus` that
apply only when firing one. Its T3 "ignore cover" became `ignore_ward` —
shots punch straight through the `ward_ally` protection a shield-wall grants,
which is the same fantasy expressed in card terms. Pool **35 → 36**.

**FINAL: 36 of 44 feats — Stat 4/4, Combat 20/20, Armor 9/9, Magic 3/11.**
All 36 tier ladders verified against `_FEAT_REGISTRY`. Three of the four
categories are COMPLETE. The 8 remaining are all Magic and all cut by
decision: 5 utility feats (§2e) and 3 SP-economy feats (§2d).

---

## 8. Balance notes

- **Feat budget is the natural brake.** 6 + 4/level points; a T5 feat costs 5.
  A level-1 card can hold one T5 or several T1s. Deep specialization requires
  levels, which requires XP, sacrifice, or the Ascension boon — that's a good
  pressure loop and should stay untouched.
- **Watch the stacking ceiling.** `dr` (damage reduction) from Titanic Bastion
  + Fury's Call + a lineage trait could zero out small hits. Recommend a global
  cap: `dr` may not exceed 6, enforced in `_damage_character()`.
- **On-miss counters + thorns + Duelist's Path** can create long chains. The
  `is_counter` flag (§4.3) must prevent recursion.
- **Deck presence:** the pool deals 8 feat cards per player from a growing
  roster. At 38 feats the odds of drawing a duplicate (needed for tier-ups)
  drop sharply. Consider weighting the deal toward duplicates, or letting
  the Reclaim banish boon fetch feats specifically.

---

## 9. Open decisions for Blaine

Settled: SP economy stays loadout-only (§6); the 5 utility feats and the 3
SP-economy feats are cut (§2d, §2e).

Still open:

1. **Linebreaker's Aim** — its whole T1 is "ignore half cover", a concept cards
   don't have. Re-flavor as a hit bonus, or cut it too? *Recommend re-flavor.*
2. **Off-hand slot (Phase 4)** — worth the card-model churn for 2 feats, or
   defer indefinitely? *Recommend build it; dual-wielding is a distinct and
   satisfying card archetype.*
3. **`dr` cap at 6** — agree?
