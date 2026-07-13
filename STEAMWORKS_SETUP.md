# Steamworks Setup for Rimvale

The code-side scaffolding for Steam achievements is already in place via
`autoload/steam_integration.gd`. The game runs identically without the
Steamworks plugin — every Steam call becomes a no-op that logs to the console.
When the plugin is installed and the Steam client is running, the same calls
forward to the real Steam API.

This doc lists the one-time setup steps to switch on live Steam integration.

## Prerequisites

1. **Steam Developer account.** Sign up at https://partner.steamgames.com.
   The Steam Direct submission fee is $100 USD per app.
2. **A reserved App ID.** Steamworks issues this once your app is approved.
   Until you have one, use **480** (Spacewar) for testing — every Steam
   client recognizes it and accepts achievement/stat calls.

## Install GodotSteam plugin

GodotSteam is the community-standard Steam binding for Godot 4. Two ways to
install it:

### Option A — Pre-compiled plugin (recommended)

1. Download the matching build from:
   https://github.com/CoaguCo-Industries/GodotSteam/releases
   Pick the release for **Godot 4.6** and your target platform(s).
2. Extract the archive. You'll find an `addons/godotsteam/` directory.
3. Drop `addons/godotsteam/` into `C:\Users\Acata\RimvaleGodot\addons\`.
   (The directory `addons/rimvale_engine/` already exists alongside it.)
4. Open the Rimvale project in the Godot editor. Go to
   **Project → Project Settings → Plugins** and tick GodotSteam on.

### Option B — Custom Godot build

If you want the most control, you can build Godot from source with
GodotSteam compiled in as a module. Most teams find Option A faster.

## Add Steam runtime files

Steam's native API requires the platform DLL to live next to your executable.

- **Windows:**
  Copy `steam_api64.dll` from the GodotSteam release into the directory
  containing `Rimvale.exe` (currently `C:\Users\Acata\RimvaleGodot\`).
- **Linux:** `libsteam_api.so` next to the Linux export.
- **macOS:** `libsteam_api.dylib` next to the .app bundle's binary.

## Configure your App ID

Create a file named `steam_appid.txt` next to `Rimvale.exe`, containing only
your App ID, e.g.:

```
480
```

When running through the Steam client this file is ignored — the App ID is
inherited from the Steam launch context. The file is only needed for
development launches outside Steam.

Also update `autoload/steam_integration.gd`:

```gdscript
var _app_id: int = 480   # ← replace with your assigned App ID
```

## Register achievements on Steamworks

The local registry at the bottom of `steam_integration.gd` enumerates every
achievement Rimvale will trigger. Each one must also exist on the Steamworks
partner site with **matching API name** (the dictionary key, e.g.
`first_blood`, `grandmaster`, `explorer_plains`).

For each entry in `REGISTRY`:

1. Open https://partner.steamgames.com → your app → Stats and Achievements.
2. Add a new achievement with API name = the registry key, display name =
   the `title` field, description = the `desc` field.
3. Upload a 64×64 icon for unlocked, and a 64×64 grayscale variant for locked.
4. Publish.

## Test cycle

1. Launch the game through the Steam client (or with `steam_appid.txt` in
   place).
2. The console should print `[Steam] Initialized OK — App ID <n>`.
3. Trigger an achievement in-game (e.g. level up to 3, or enter a region).
4. Steam should show its standard achievement-unlocked toast.
5. The unlock also persists locally in `GameState.achievements_unlocked`
   so the in-game collection UI can show it even when Steam is offline.

## Cloud saves (optional but recommended)

To enable Steam Cloud for save files:

1. In the Steamworks site, go to your app → Installation → Cloud and tick
   "Enable Cloud support for this application".
2. Add a User File Auto-Cloud entry pointing at:
   `%APPDATA%/Godot/app_userdata/Rimvale/` (Windows)
   `~/.local/share/godot/app_userdata/Rimvale/` (Linux)
   `~/Library/Application Support/Godot/app_userdata/Rimvale/` (macOS)
3. Pattern: `*.json` (the slot saves) plus `settings.cfg`.

No code change is required — Godot writes to `user://` which maps to the
above directories, and Steam picks the files up automatically.

## What this scaffold gives you for free

- `SteamIntegration.unlock("first_blood")` — single call to unlock + cache.
- `SteamIntegration.on_player_level(n)` — wired from `GameState.check_level_up`.
- `SteamIntegration.on_region_entered(id)` — wired from `scenes/explore/explore.gd`.
- `SteamIntegration.on_enemy_killed()` — call site TODO (engine).
- `SteamIntegration.on_vehicle_acquired()` — call site TODO (garage flow).
- `SteamIntegration.on_mythic_equipped()` — call site TODO (inventory).
- `SteamIntegration.on_story_badge_earned(count)` — call site TODO (story).
- `SteamIntegration.on_revive_from_cemetery()` — call site TODO (cemetery).
- A 24-achievement registry covering progression, region exploration,
  collection, and story milestones — easy to extend by adding new dict
  entries.

The TODO call sites are all single-line additions where the relevant event
already fires. Wire them as you reach each system.
