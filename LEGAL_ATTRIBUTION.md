# Legal & Attribution

## SRD 5.2.1 Attribution (required — must ship in-game)

Rimvale includes material (weapon tables and weapon mastery properties) adapted
from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast
LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under
the Creative Commons Attribution 4.0 International License, available at
https://creativecommons.org/licenses/by/4.0/legalcode.

**Action required before release:** display the paragraph above in the game's
credits screen (and keep it in this file / the README). The CC-BY license makes
use of that material legal, but only WITH the attribution — the game currently
ships none.

This license covers copyright only. It does NOT grant rights to Wizards of the
Coast trademarks (e.g., "Dungeons & Dragons", "Player's Handbook", "Dungeon
Master"). Do not use those marks in the game, store page, or companion books.

## Remediation checklist (from IP audit, 2026-07-08)

Code fixes (done):
- [x] "Underdark Passage" terrain → "Undervault Passage" (rimvale_fallback_engine.gd)
- [x] "Aasimar" Director Shop hero → "Gravetouched" (team.gd)
- [x] "Holy Avenger" → "Greatsword" (team.gd)
- [x] Drow/Drizzt-like art prompt reworded (CREATURE_ART_PROMPTS.md/.txt)

Companion-book fixes (edit the source .docx files — not done here):
- [ ] Rename "Rimvale Player's Handbook" → e.g. "Rimvale Adventurer's Handbook".
      "Player's Handbook" is a registered WotC trademark. Highest-priority item.
- [ ] World Guide: rename the "Underdark" city-state (5 mentions, ~lines 1044-1072)
      → e.g. "Hollowdeep" or "the Undervault".
- [ ] PHB line ~750: stray "DM" → "GM".
- [ ] WG lines ~2524/2750: "hit die" leftovers → reword to HP recovery (Rimvale
      has no hit dice; the text is also mechanically dead).
- [ ] Optional: NPC "Krynn Ashenblade" → "Krenn"/"Kaelen" (Dragonlance collision).
- [ ] Optional: soften the "5E stuff" designer aside (PHB ~2152) to neutral
      licensing language.
- [ ] Optional: "phylactery" → "soul vessel" (generic word, but the lich pairing
      is a D&D convention).

Verified clean (zero hits): beholder, mind flayer, illithid, yuan-ti, displacer
beast, owlbear, tiefling, dragonborn, Waterdeep, Faerûn, named-wizard spells
(Mordenkainen/Bigby/Tasha/...), "Dungeons & Dragons", "d20 System", and ~40 more
product-identity terms. "Lich", "kobold", "gnoll", "cantrip" are folklore/SRD
and fine to keep.

*This is a lay audit, not legal advice — for a commercial release, a one-hour
review by an IP attorney is cheap insurance.*
