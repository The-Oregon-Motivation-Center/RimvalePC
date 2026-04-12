# Phase 1 — Build Instructions

Follow these steps once, in order. After this Phase 1 setup is complete you can
open the Godot project and the engine will be available from any GDScript.

---

## Step 1 — Install tools

### Godot 4
Download **Godot 4.3** (or latest 4.x stable) from https://godotengine.org/download
- Install the standard version (not .NET/Mono)
- Add Godot to your PATH so you can run it from the terminal (optional but handy)

### C++ build tools (Windows)
Download and install **Visual Studio 2022 Build Tools**
- Installer: https://visualstudio.microsoft.com/downloads/ → "Build Tools for Visual Studio 2022"
- In the installer select: **"Desktop development with C++"**

### CMake
- Usually installed with VS Build Tools. Verify with: `cmake --version`
- If missing: https://cmake.org/download/

### Git
- Required for the godot-cpp submodule. https://git-scm.com/

---

## Step 2 — Clone godot-cpp

Open a terminal in `C:\Users\Acata\RimvaleGodot\` and run:

```bash
cd gdextension
git init          # only needed if RimvaleGodot is not already a git repo
git submodule add https://github.com/godotengine/godot-cpp.git godot-cpp
git submodule update --init --recursive
```

> **Version match:** godot-cpp must match your Godot editor version.
> After cloning, check out the correct branch:
> ```bash
> cd godot-cpp
> git checkout godot-4.3-stable   # replace with your Godot version tag
> ```

---

## Step 3 — Build the GDExtension (Windows 64-bit)

From a **Developer Command Prompt for VS 2022** (search Start menu):

```bash
cd C:\Users\Acata\RimvaleGodot\gdextension

cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Debug
```

This compiles `librimvale_engine.windows.debug.x86_64.dll` and places it at:
`C:\Users\Acata\RimvaleGodot\addons\rimvale_engine\bin\`

For a release build replace `Debug` with `Release`.

---

## Step 4 — Open the project in Godot

1. Launch Godot 4
2. Click **Import** → navigate to `C:\Users\Acata\RimvaleGodot\` → select `project.godot`
3. Godot will detect the `.gdextension` file and load the compiled library automatically
4. Open `scenes/test/engine_test.tscn` and press **F5** (Play)
5. Check the **Output** panel at the bottom — you should see:

```
=== Phase 1 GDExtension Test ===
PASS  get_all_lineages()  ->  N lineages, first = '...'
...
=== ALL TESTS PASSED — Phase 1 complete ===
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `godot-cpp not found` CMake error | Run Step 2 again; make sure the submodule is initialised |
| `Unable to load addon: rimvale_engine` in Godot | The .dll is missing — rerun Step 3 and confirm the file exists in `addons/rimvale_engine/bin/` |
| Compile errors about `__android_log_print` | The wrong `AndroidOut.h` is being picked up. Ensure `gdextension/src/` comes before the engine source in include paths (CMakeLists.txt already handles this). |
| Godot crashes on launch | Open Godot from a terminal to see the crash log. Usually a missing symbol — check that all 4 engine .cpp files compiled successfully. |

---

## Next steps after Phase 1 passes

Once all tests pass, report back and Phase 2 begins:
**Dungeon scene** — tile-based 2D dungeon with animated sprites, lighting, and effects.
