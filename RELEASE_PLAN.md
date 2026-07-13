# Rimvale PC — Release Plan

Goal: playable, polished magic/feat systems + Steam-ready build.
Audit date: 2026-07-08. All line refs are to `autoload/rimvale_fallback_engine.gd` unless noted.

> **STATUS UPDATE (2026-07-08): Phase 1 is DONE**, implemented against the PHB
> V0.944 conditions tables. Completed: 1.1 exhaustion bug; 1.2 all 8 dead
> conditions (+ calm, fever, invulnerable, resistant, unconscious from the
> bless/curse tables — frightened blocks approach, charmed protects the
> charmer, vulnerable doubles damage, invisible/glowing drive advantage);
> 1.3 spell-builder condition mapping + PHB per-condition SP costs +
> validation + legacy-save normalization; 1.4/1.5 Apex registry rebuilt as 18
> real feats, Lycanthropic Curse + Temporal Touch ported, 6 alignment feats
> wired to SP discounts, 6 unimplementable utility feats hidden from the
> picker. BIGGEST FIX: added the feat-activation button generator
> (`FEAT_ACTIVATIONS`, engine ~9860) — ~60 apex/ascendant/pact/misc feat
> activations had working combat code but NO UI buttons, so none were
> reachable in play. Also fixed a latent crash in Safeguard T3 and a WotC IP
> pass (see LEGAL_ATTRIBUTION.md). Remaining phases below are unchanged.

**Key context:** The GDScript fallback engine is what actually runs (only a Debug DLL of the C++ engine ships), so all fixes below target the fallback. The good news: the systems are ~90% built. What's missing is exactly what you felt — a set of effects that are defined but never fire.

---

## Phase 1 — Make effects actually work (highest impact)

### 1.1 One-line bug: exhaustion never triggers
Hollow Touch applies `"exhaustion"` (line 5224) but the tick handler checks `"exhausted"` (14663). Rename at 5224.

### 1.2 Implement the 8 dead conditions
These are applied by ~30 spells/abilities but have **no mechanical effect** anywhere:

| Condition | Applied by (examples) | Intended effect to implement |
|---|---|---|
| `frightened` | ~15 spells/abilities (Curse: Frightened 8578, fear auras) | Disadvantage on attacks; can't move toward source |
| `charmed` | Mind Link, Mind Shackle, Mind Control, Memory Edit (8555-8590) | Can't target charmer; charmer advantage — all mind-control spells are currently cosmetic |
| `vulnerable` | Curse: Vulnerable (8584, "double damage") | Double incoming damage |
| `invisible` | Shadow Veil 8538, Invisibility | Attackers disadvantage / untargetable at range |
| `cursed` | Soulbrand 5078, Voidbrand 6488 | Define an effect (e.g., -2 saves) or fold into another condition |
| `deafened` | Curse: Deafened 8573, Thunder auto-cond 13097 | Fail sound-based checks; flavor penalty |
| `glowing` | Faerie Fire 4928 ("attacks have advantage") | Attackers advantage; cancels invisible |
| `exhausted` (partial) | See 1.1 | Already handled at 14663 once name fixed |

Implementation points: `_dung_tick_conditions` (14560), `_dung_do_attack` (13577), targeting logic. Follow the existing patterns for blinded/prone (13581/13585).

### 1.3 Fix custom spell builder — conditions silently do nothing
`scenes/level_up/level_up.gd`: the builder's condition names (`Bleed, Charm, Fear, Squeeze, Poisoned...`, lines 857-866) never match engine strings (`bleeding, charmed, frightened, squeezed, poisoned...`) — case and vocabulary both. Every custom spell's conditions are non-functional.
- Add a mapping dict UI-name → engine string at registration (`_do_register_spell` 1673 / engine `add_custom_spell` 8109).
- Remove or implement conditions with no engine handler: Calm, Invulnerable, Resistance, Shielded, Silent, Stoneskin, Diseased, Fever.
- Add real validation in `_do_register_spell` (currently only checks non-empty name, 1675): require ≥1 effect, cap cost, reject dupes.

### 1.4 Wire the 15 description-only feats
Purchasable in the UI but never checked by gameplay code (registry line refs):

- **Magic (4):** Create Demiplane 3958, Scryer 3976, Soul Weaver 3986, Transmuter's Precision 3992
- **Alignment (6):** Chaos Initiate 3997, Unity Scholar Initiate 4005, Void Initiate 4013, Chaos Scholar 4129, Unity Scholar 4263, Void Scholar 4281 — note `_alignment_sp_modifier` (13233) keys off the character's alignment *string*, not these feats; decide whether feats should grant/stack that bonus
- **Exploration (3):** Explorer's Grit 4043, Stealth & Subterfuge 4064, Temporal Touch 4068 (C++ has it: `CombatManager.cpp:5315`; port it)
- **Apex (1):** Apex 4103 — see 1.5
- **Ascendant (1):** Lycanthropic Curse 4199 (C++: `CombatManager.cpp:5830`; port it)

Options per feat: implement, or temporarily hide from the level-up UI until implemented. Don't ship purchasable no-ops.

### 1.5 Resolve the Apex mismatch
Registry offers one "Apex" tree (never checked); combat code checks 18 apex feat names that don't exist in the registry (6346-6506: Arcane Overdrive, Iron Tempest, Soulflare Pulse, etc. — the C++ Feats.h:543-560 list). Recommended: replace the single "Apex" registry entry with the 18 real apex feats so the existing (already-written!) combat code becomes reachable. This is cheap content: the effects code already exists.

### 1.6 Engine decision
Ship 1.0 on the GDScript fallback (it's complete and authoritative). Remove or clearly gate the Debug-only C++ DLL — a Debug DLL must not ship. Revisit C++ post-launch if performance demands it.

---

## Phase 2 — UI/UX polish for magic & feats

> **STATUS UPDATE (2026-07-08): Phase 2 core items DONE.** Condition ticks now
> print to the battle log (bleed/burn/poison/squeeze damage, stunned/dazed
> lost turns, deaths from DoT — engine `_stash_tick_log`, drained in
> `dungeon_advance_enemy_phase`); condition chips on the entity card cover all
> ~35 conditions with hover tooltips explaining each effect (dungeon.gd
> `COND_TOOLTIPS`), and the enemy inspect panel lists per-condition effects;
> spell buttons show the EFFECTIVE SP cost after alignment/domain/feat/
> wellspring discounts (new engine `get_effective_spell_cost`, shown as
> "SP 8→6") plus "Save DC N" or "Attack roll" per spell; the feat picker has a
> debounced text search across all trees; `get_feat_action_states` and
> `get_feat_trees_by_character` stubs are implemented. Remaining nice-to-haves
> below (feat-proc log lines for passive bonuses, spell-builder live preview
> of mapped conditions) are lower priority.

- **Combat feedback:** when a feat procs (bonus dice, charge use, SP discount) show it in the combat log — players can't feel feats that fire silently. Same for condition application/tick ("X is Frightened: disadvantage on attacks").
- **Condition tooltips/icons:** every condition on an entity should be visible with a one-line effect description in the dungeon UI (`scenes/dungeon/dungeon.gd`).
- **Feat cards** (`level_up.gd` `_build_feat_card` 749): show current tier vs next-tier delta clearly; show per-rest/encounter charges; add search across the 143 trees.
- **Spellbook/casting flow:** show SP cost after all modifiers (alignment/domain/feat discounts) before cast, not after; surface save DC and overreach risk.
- **Spell builder:** live preview of what the spell will actually do (post-mapping conditions, computed cost breakdown).
- **Stubbed helpers:** implement `get_feat_action_states` (870) so the UI can grey out spent feat actions.

---

## Phase 3 — Playability pass (full game)

> **STATUS UPDATE (2026-07-08): Phase 3 investigated + fixed.**
> Good news first — most doc-claimed gaps were stale: skill-point allocation,
> the base tab, enemy loot tables, and ALL 28 subregion NPC rosters (full at
> target counts, 184 dialogue trees verified) were already done.
> REAL bugs found & fixed in save/load: five character fields were saved but
> never restored (apex_tiers, mastered_weapons, wm_can_rechoose,
