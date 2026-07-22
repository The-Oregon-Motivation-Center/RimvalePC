---
name: rimvale-android-export
description: Set up and produce Android builds of the Rimvale Godot project (APK for testing, AAB for Play). Use when the user mentions Android, mobile export, APK, AAB, gradle build, Android SDK/JDK setup, keystores, or "get Rimvale/the TCG on my phone".
---

# Rimvale — Android export

Rimvale is **Godot 4.6**, main scene `res://scenes/title/title_screen.tscn`,
viewport 1920×1080 with `canvas_items` stretch. The TCG lives in
`scenes/cards/` and `autoload/card_system.gd`.

## Two project facts that make this much easier — verify, don't assume

1. **The C++ GDExtension is optional.** `autoload/rimvale_engine_singleton.gd`
   tries `ClassDB.class_exists("RimvaleEngine")` and silently falls back to
   `autoload/rimvale_fallback_engine.gd`. The TCG uses the fallback path
   anyway, so **you do not need Android `.so` builds of the GDExtension to
   ship the card game.** Confirm at runtime by checking logcat for
   `DLL not loaded — using GDScript fallback engine` (expected on Android).
   If the user wants the native engine on Android later, that's a separate
   `godot-cpp` cross-compile per ABI (`arm64-v8a`, `armeabi-v7a`) — treat it
   as its own project, not part of shipping the TCG.
2. **Steam is already guarded.** `autoload/steam_integration.gd` gates every
   call behind `Engine.has_singleton("Steam")`, so it no-ops on Android. Do
   not remove the autoload; just verify no hard Steam dependency was added.

## Required project changes before the first export

Renderer — **this is the one people forget**:
- `project.godot` currently declares `Forward Plus`. Android needs the
  **Mobile** renderer. Set `rendering/renderer/rendering_method.mobile="mobile"`
  and confirm `config/features` includes it. Forward Plus on Android either
  fails to start or tanks framerate.

Orientation and input:
- `display/window/handheld/orientation="landscape"` — the TCG board is a wide
  layout (6 slots plus opponent rows); portrait needs the redesign covered in
  the `rimvale-touch-ui` skill.
- `input_devices/pointing/emulate_mouse_from_touch=true` keeps existing
  `gui_input` mouse-button handlers working. **This does NOT fix hover** —
  see the touch skill.

Package identity:
- Unique id, e.g. `com.sparkpointstudios.rimvale`. Never ship the default
  `org.godotengine.*`.

## Toolchain setup

```
JDK 17 (Temurin)          → JAVA_HOME
Android SDK cmdline-tools → platform-tools, build-tools;34.0.0, platforms;android-34
```
In Godot: **Editor → Editor Settings → Export → Android**, set `Android Sdk Path`
(and `Java Sdk Path` on 4.x). Then **Project → Install Android Build Template**
(required for custom builds and for any plugin use).

Debug keystore (Godot can generate one) and a **release keystore** — back the
release keystore up somewhere permanent; losing it means you can never update
the app on Play.

```bash
keytool -genkey -v -keystore rimvale-release.keystore -alias rimvale \
  -keyalg RSA -keysize 2048 -validity 10000
```
Put the path/alias/password in **Export → Android → Release** fields, and keep
credentials out of `export_presets.cfg` if that file is committed (Godot 4.6
supports env-var indirection for this — check before hardcoding).

## Export presets

`export_presets.cfg` currently holds only Windows presets. Add an Android one:
- Architectures: `arm64-v8a` on (required by Play), `armeabi-v7a` optional,
  `x86_64` only if you want emulator builds.
- **Export format: APK** for device testing, **AAB** for Play upload.
- Min SDK 24+, target SDK to whatever Play currently requires.

### Shrink the package — Rimvale carries a lot the TCG never touches
The repo includes many 3D kits (`kenney_*`, `fantasy-town-kit`,
`modular-dungeon-kit`, `assets/characters_3d`, `assets/vehicles_3d`). A
TCG-focused build only needs `assets/characters/` (the 2D lineage portraits
the cards render), `audio/`, and the card scenes.

Use the preset's **Resources → Export selected resources** or filters:
```
Filters to exclude: kenney_*/*, fantasy-town-kit/*, modular-dungeon-kit/*, assets/characters_3d/*, assets/vehicles_3d/*
```
Verify afterwards that no exported scene still references an excluded path —
if the user wants Battle Mode on Android too, most of these come back.

## Build commands

```bash
# Headless CLI build (CI-friendly)
godot --headless --export-debug "Android" build/rimvale-debug.apk
godot --headless --export-release "Android" build/rimvale.aab

# Install + watch logs
adb install -r build/rimvale-debug.apk
adb logcat -s godot:V
```

## Verification checklist

- [ ] App launches to the title screen; the three-game menu renders
- [ ] logcat shows the **fallback engine** message (expected, not an error)
- [ ] Rimvale TCG → deck builder → a match starts and a card can be played
- [ ] No `Forward Plus` renderer warnings
- [ ] Back gesture/button doesn't kill the app mid-match (wire it to the
      TCG's existing quit-confirm dialog — see `rimvale-touch-ui`)
- [ ] APK size is sane (excluded 3D kits actually excluded)

## Common failures

| Symptom | Cause |
|---|---|
| Black screen on launch | Forward Plus renderer still set |
| "Invalid package name" | default `org.godotengine.*` id |
| Export button greyed out | Android build template not installed |
| Gradle build fails on JDK | JDK ≠ 17 |
| Fonts/portraits missing | over-aggressive export filters |
