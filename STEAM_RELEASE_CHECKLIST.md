# Rimvale — Steam Release Checklist

Practical, in-order steps from here to "Release" button. Companion to
STEAMWORKS_SETUP.md (plugin mechanics) and LEGAL_ATTRIBUTION.md (legal musts).
Status as of 2026-07-12: code side is READY — all 24 achievements are wired
in-game, the Steam layer auto-activates when GodotSteam is present, and the
"Rimvale PC (Steam Release)" export preset is configured. The RTS **Battle Mode
+ Region Conquest** campaign is also complete and ships in this build (feature
it on the store page — see section 4).

## 1. GodotSteam install (your machine, ~15 min)

- [ ] Download the GodotSteam **GDExtension** build matching Godot 4.6:
      https://godotsteam.com/ → GDExtension → 4.6-compatible release.
- [ ] Copy its `addons/godotsteam/` folder into the project `addons/`.
- [ ] Put `steam_api64.dll` next to the exported `Rimvale.exe` (GodotSteam
      docs cover this; the plugin zip includes it).
- [ ] Create `steam_appid.txt` next to the exe containing ONLY your App ID
      (during dev you can use `480` = Spacewar for smoke-testing).
- [ ] Launch with the Steam client running. Console should print
      `[Steam] Initialized OK` instead of "stub mode". No code changes needed.
- [ ] In `autoload/steam_integration.gd` line ~32, replace `_app_id: int = 480`
      with your real App ID (cosmetic/logging only, but do it).

## 2. Steamworks App Admin — achievements (~30 min)

Create these 24 achievements with EXACTLY these API names (they must match
the code's REGISTRY in `autoload/steam_integration.gd`):

```
first_blood        agent              specialist         veteran
elite              master             grandmaster
explorer_plains    explorer_peaks     explorer_shadows   explorer_glass
explorer_isles     explorer_titans    explorer_astral    explorer_terminus
explorer_sublimini explorer_metro
mythic_collector   motor_pool         feat_master        loremaster
cemetery_visit     badge_first        badge_nine
```

Titles/descriptions to paste are in the REGISTRY dict (steam_integration.gd
~line 140). Each needs a 64x64 achieved + unachieved icon. After editing,
**Publish** the Steamworks changes (they don't go live until published).

All triggers are wired in-game: kills (first_blood), levels 3/5/9/12/16/20,
region entry (all 10 regions), Legendary/Apex item attunement, first vehicle,
10 party feats, 50 codex entries viewed, cemetery revival, story badges 1 & 9.

> Note: these 24 are all STORY-mode achievements. **Battle Mode has no
> achievements yet** — optional future work (e.g. claim a first region,
> complete the Conquest campaign, win a "last stand"). Not required for 1.0.

## 3. Build the release (~10 min)

- [ ] Godot → Project → Export → "Rimvale PC (Steam Release)" preset.
      It exports to `export/steam/Rimvale.exe` with the PCK embedded and the
      unused C++ debug extension excluded (the GDScript engine is the shipping
      engine). Use **Export Project (Release)**, not Debug.
- [ ] Add `export/` to .gitignore if it isn't.
- [ ] Set a real icon: preset currently has `application/icon` empty — make a
      256x256 .ico and set it before the final build.
- [ ] Test the exported exe on a machine (or clean folder) WITHOUT Godot:
      title screen → new game → one combat → save → load.
- [ ] Ship alongside the exe: `steam_api64.dll`. (Do NOT ship steam_appid.txt
      in the final depot — Steam injects the ID; the txt is for local testing.)

## 4. Store page (start EARLY — it gates your release date)

- [ ] Capsule images (Steam requires several sizes), 5+ screenshots, a trailer.
      Include 2-3 **Battle Mode** shots (a big multi-team fight, the Conquest
      world map) — it's a headline feature, show it off.
- [ ] Description: cover BOTH pillars — the story RPG (party-based, magic/feat
      customization, 10 regions) AND **Battle Mode**, the Command & Conquer–style
      RTS with a 10-region Conquest campaign. See RELEASE_PLAN "Battle Mode +
      Region Conquest — SHIPPED" for feature copy to draw from.
- [ ] Tags: RPG, Turn-Based Tactics, Party-Based, Character Customization —
      PLUS Strategy, Real-Time Tactics, RTS, Base Building (for Battle Mode).
- [ ] System requirements.
- [ ] The page must pass Valve review, then be public ("Coming Soon") for at
      least ~2 weeks before you can release. Build review is separate and also
      takes a few days the first time. Plan for 3-4 weeks total lead time.

## 5. Upload the build (SteamPipe)

- [ ] Steamworks → your app → SteamPipe → create a depot (Windows 64).
- [ ] Upload `export/steam/` contents with the SteamPipe GUI tool or
      `steamcmd` + app_build script.
- [ ] Set the build live on a private **beta branch** first; install through
      Steam yourself and verify: achievements pop, overlay works, saves work.
- [ ] Only then set the build live on `default`.

## 6. Recommended before launch (not blocking)

- [ ] **Steam Cloud**: saves live in `user://` — enable Steam Auto-Cloud for
      the Godot user path in Steamworks (5-minute config, big player win).
- [ ] Playtest pass per RELEASE_PLAN Phase 3 checklist (full playthrough).
- [ ] Verify the Credits s