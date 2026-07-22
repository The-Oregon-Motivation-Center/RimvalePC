---
name: rimvale-play-store-release
description: Ship Rimvale TCG to Google Play — signed AAB, store listing copy and assets, content rating, data-safety form, versioning, and staged rollout. Use when preparing a Play Store submission, a store update, release notes, or when a submission is rejected.
---

# Rimvale TCG — Google Play release

Rimvale already has desktop release process docs (`RELEASE_PLAN.md`,
`STEAM_RELEASE_CHECKLIST.md`, `LEGAL_ATTRIBUTION.md`). **Read
`LEGAL_ATTRIBUTION.md` before writing any store listing** — the project uses
SRD 5.2.1 under CC-BY, and that attribution requirement follows the game onto
Play.

## Build

```bash
godot --headless --export-release "Android" build/rimvale.aab
```
- **AAB**, not APK, for Play.
- Signed with the **release keystore** (back it up; losing it ends your
  ability to update the listing).
- Prefer **Play App Signing** — Google holds the app signing key, you keep an
  upload key you can rotate.

Versioning in `project.godot` / export preset:
- `version/code` — integer, **must increase every upload**.
- `version/name` — human string; Rimvale desktop is at `2.0`, so the TCG's
  first mobile release might be `1.0` under its own name or `2.1` if unified.
  Decide once and stay consistent.

## Listing

| Asset | Spec |
|---|---|
| App icon | 512×512 PNG, 32-bit |
| Feature graphic | 1024×500 PNG/JPG |
| Phone screenshots | ≥ 2, 16:9 or 9:16, min 320 px short side |
| 7"/10" tablet shots | recommended if you declare tablet support |
| Short description | ≤ 80 chars |
| Full description | ≤ 4000 chars |

Screenshot suggestions that actually sell this game — capture from a real
match, not a mockup:
1. A 2-player board mid-combat with the roll breakdown visible in the log
   ("🎲 14+4 = 18 vs AC 15") — shows the tabletop math.
2. A character card close-up with lineage portrait, traits, and stat chips.
3. The deck builder showing a region's card pool.
4. The gauntlet with a challenger countdown and kill counter.
5. A 4-player board.

Copy angles grounded in what's actually built: 164 lineages with working
traits, real PHB-derived feats with tier progression, custom spell creation,
1–4 players hotseat or vs AI at three difficulties, and an endless gauntlet.

## Content rating

Fill the IARC questionnaire honestly. Rimvale TCG is fantasy combat with no
gore, no real-money gambling, no user-generated content sharing (the custom
spell builder is local-only — say so). Expect roughly **Everyone 10+ / PEGI 7**.

## Data safety form

This is where indie submissions most often stall. For a fully offline TCG:
- Data collected: **none** — no accounts, no analytics, no ads (verify this is
  still true; adding any SDK later changes the answer).
- Data shared: none.
- If a save file exists, it's local-only.
Do not leave the form blank; an inaccurate declaration is a policy violation.

## Pre-launch checklist

- [ ] Target SDK meets Play's current requirement
- [ ] 64-bit (`arm64-v8a`) included
- [ ] Unique package id (not `org.godotengine.*`)
- [ ] Release keystore backed up in two places
- [ ] SRD 5.2.1 CC-BY attribution present in-app (Credits screen) **and** in
      the store listing where required
- [ ] Privacy policy URL live (required even for no-data apps)
- [ ] Back button/gesture handled everywhere (Play tests this)
- [ ] App doesn't crash on rotate or on resume from background mid-match
- [ ] Tested on a real device, not only the emulator

## Rollout

Use **internal testing → closed → open → production**. For the first release,
a staged production rollout at 20% catches device-specific crashes before
everyone gets them. Watch the Play Console's **Android vitals** for ANRs and
crash clusters during the first week.

## Updates

Every update needs a higher `version/code`. Write release notes in the same
voice as the game; keep them specific ("Gauntlet challengers now scale by
wave") rather than "bug fixes and improvements".
