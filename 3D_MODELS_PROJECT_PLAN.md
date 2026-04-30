# 3D Models Project Plan — Free-Only Edition

**Goal:** replace the 2D PNG sprites currently used for the 164 lineages, plus
all armor/clothing and weapons, with 3D-looking models that animate in
Godot 4. **Zero budget for paid services.**

You mentioned "image wrap" — that's actually one of the viable free
techniques. Below are five free approaches ranked by effort vs. result,
plus a recommended hybrid path that combines the best parts.

---

## The Five Free Techniques (Ranked)

### Option A — Imposter Billboards (Octopath Traveler / Paper Mario style)

This is what "image wrap" most often means in game-dev.

- Take the existing PNG sprite for each lineage
- Render it on a 3D `QuadMesh` that always faces the camera (Sprite3D
  with `BILLBOARD_ENABLED`) — your game already does this for vehicles
- Add a small amount of "fake 3D" by:
  - Tilting the quad slightly toward the ground (15°)
  - Using a soft drop shadow on the floor
  - Optionally, generating 3 versions of each PNG (front, side, 3/4 back)
    and swapping based on camera angle

**Cost:** $0. Uses existing PNGs.
**Effort:** ~2 days. Just shader/Sprite3D work.
**Result:** Looks like Octopath Traveler — clearly stylized, characters
have presence in 3D space, but they're still 2D. Many AAA games ship
this and players love the look.
**Best for:** if you want it shipped fast and beautiful, this is the
answer.

### Option B — Texture-Wrap Existing PNGs onto a Free Humanoid Base

Closest to what "image wrap" technically describes:

- Download a **free Mixamo humanoid mesh** (T-pose, rigged, animated)
- Take each lineage's existing PNG and use it as the **face texture**
  on the humanoid's head — UV-mapped so it wraps the head mesh
- Or, use the PNG as a flat decal on the chest (like a printed shirt)
- Body texture comes from Mixamo defaults or a procedural skin shader
  tinted by lineage (e.g. Goldscale = gold; Frostborn = pale blue)

**Cost:** $0. Mixamo is free for commercial use, no attribution.
**Effort:** ~1 week. Need to manually UV-fit the existing PNGs to a
head once (template), then it auto-applies for every lineage.
**Result:** Real 3D model with proper animation. Faces look "stickered
on" (stylized rather than photoreal — actually fine for an RPG aesthetic).
Body is consistent across all lineages.
**Best for:** middle ground — real 3D that uses your existing art.

### Option C — Free Local AI Image-to-3D (open source, runs on your GPU)

If you have an NVIDIA GPU with 8 GB+ VRAM:

- **Hunyuan3D** (Tencent, open source) — image → 3D mesh, runs locally
- **InstantMesh** (open source) — same idea, faster
- **TripoSR** (open source from Stability AI) — image → mesh in seconds
- **Wonder3D** (open source)

All are 100% free if you can run them locally. Model quality is good
for stylized characters (better than the paid services for low-poly
fantasy aesthetic).

**Cost:** $0 (electricity).
**Effort:** ~1 week to install, debug CUDA, and write a batch script.
164 lineages takes ~3–4 hours of GPU time once it's running.
**Result:** True 3D meshes from PNG input. Quality is inconsistent
(20–30% need re-rolls), but the rolls are free so just run more.
**Best for:** if you have a gaming GPU and don't mind a setup weekend.

**Hardware requirement:** GTX 1080 / RTX 3060 minimum. If you have
an integrated GPU only, skip this option.

### Option D — Free Tier of "Paid" Services (no purchase)

The paid services have free tiers that may cover what you need:

- **Meshy free tier** — 200 generation credits/month, no card required
- **Tripo3D free tier** — ~50 generations/month
- **Rodin Hyper3D** — generous trial credits on signup
- **Sloyd.ai** — text → 3D, free for limited use
- **Common Sense Machines (CSM)** — free demo credits

Stack the free tiers across multiple services and you can plausibly
cover 164 lineages over 2–3 months without paying anything. Each
service has different style/quality, so spread your most-important
lineages across the best one.

**Cost:** $0.
**Effort:** ~1 week scripted, plus 2–3 months of "wait for next
month's credits to refresh".
**Result:** Same as paid version, just slower delivery.

### Option E — CC0 Asset Pack Re-Skinning

Free 3D asset packs that already have humanoid characters:

- **Quaternius** (quaternius.com) — CC0, has a 100+ character pack
  with low-poly fantasy humanoids (warriors, mages, etc.)
- **Kenney.nl** — CC0, character packs (smaller variety)
- **Mixamo** — has ~40 pre-made characters in addition to the X-Bot base
- **Sketchfab** — filter for "downloadable + CC0" models, hundreds of
  fantasy characters
- **Itch.io free asset bundles** — frequent free game-asset giveaways

You won't get 164 unique designs from CC0 alone. But you can get
~20–30 distinct base looks and re-tint/re-skin to cover the lineage
set. Goldscale → gold-tinted human warrior; Frostborn → pale-blue
human ranger; etc.

**Cost:** $0.
**Effort:** ~3 days. Pure asset-pack browsing + Godot import.
**Result:** Real 3D with full animations, but ~20 unique looks
covering 164 lineages by tint variation. Less unique, but ships fast.
**Best for:** if you want to be done in a week and don't mind some
visual repetition.

---

## Recommended Hybrid: Option A + Option E + Option B

The best free path stacks the cheapest techniques:

1. **Option E (CC0 base bodies)** — Pick 4–5 humanoid base meshes
   from Quaternius/Kenney that cover the major silhouettes (warrior,
   mage, ranger, scholar, rogue). Each is a fully rigged Mixamo-compatible
   humanoid with animations. ~$0, ~1 day.

2. **Option B (image-wrap heads)** — For each lineage, use the existing
   PNG portrait as a UV-mapped face texture on the base mesh's head.
   Body color/tint per lineage. ~$0, ~3 days.

3. **Option A (billboards for non-humanoids)** — The ~30 non-humanoid
   lineages (Bouncian, Beetlefolk, Myconid, Saurian, etc.) that don't
   fit a humanoid silhouette stay as Octopath-style billboards using
   existing PNGs at 3 angles. ~$0, ~2 days.

4. **Equipment** — Quaternius weapon pack (CC0, 50+ weapons)
   + Quaternius armor pack (CC0, 20+ armor sets). Tinted in shader
   for material variety. ~$0, ~2 days.

**Total:** ~1.5 weeks of work, **$0 cost**, all 164 lineages have
3D-feeling presence, full animations on the humanoid bipedals.

If you later want to upgrade specific high-profile lineages to true
unique 3D meshes (e.g. main story characters), drop Option C in just
for those — the rest stays as the free hybrid.

---

## Phase Breakdown (Free Hybrid)

### Phase 1 — Bootstrap (~3 days)

1. Download a Mixamo X-Bot humanoid (free, fully rigged)
2. Set up `Skeleton3D` scene with `BoneAttachment3D` sockets:
   `Head`, `RightHand`, `LeftHand`, `Spine`, `Hips`
3. Import 5 default Mixamo animations: Idle, Walk, Run, Attack_Melee,
   Death
4. Wire `AnimationTree` state machine
5. Confirm one humanoid character renders + animates in the dungeon

**Pass gate:** A character walks, swings a sword, and dies on screen.

### Phase 2 — Existing PNG → Face Texture Pipeline (~3 days)

1. UV-unwrap the X-Bot's head mesh so the front face is mapped to a
   square region of the texture (use Blender, free, one-time setup)
2. Write a **GDScript loader** that:
   - Takes a lineage name
   - Loads the corresponding existing PNG from
     `assets/lineages/portraits/<lineage>.png`
   - Generates a new combined texture (full head atlas with the face
     PNG embedded in the right spot) — `Image.blit_rect()`
   - Sets that texture on the head mesh's material
3. Test with all 134 humanoid lineages — verify each face wraps
   correctly

**Pass gate:** All 134 humanoid lineages render as humanoids with their
existing PNG art as the face. Looks somewhat like a paper-mâché doll —
that's the intended Hades/Octopath aesthetic.

### Phase 3 — Body-Tint Variation (~1 day)

To make lineages feel distinct beyond just the face, tint the body
shader per lineage:

```gdscript
# Read region/lineage culture from existing data
var tint_map: Dictionary = {
    "Goldscale": Color(1.0, 0.85, 0.30),       # gold
    "Frostborn": Color(0.75, 0.85, 1.00),       # pale blue
    "Cindervolk": Color(0.85, 0.40, 0.20),     # ember red
    # ... per lineage
}
```

This is a 2-line shader change, applied per character at spawn.

**Pass gate:** Goldscale gleams gold, Frostborn looks frozen, etc.

### Phase 4 — Equipment (~2 days)

1. Download Quaternius weapon pack (CC0)
2. Download Quaternius armor pack (CC0)
3. Map your `_ITEM_REGISTRY` weapon names to mesh files:
   `"Longsword"` → `quaternius_longsword.glb`,
   `"Greatsword"` → `quaternius_greatsword.glb`, etc.
4. `BoneAttachment3D` to `RightHand` for weapon, `Spine` for chest armor
5. Magical/legendary items get a glow shader on top (already free)

**Pass gate:** Equipping a weapon updates the 3D model in real time;
plate armor visibly covers the character.

### Phase 5 — Non-Humanoid Billboards (~2 days)

For the ~30 lineages that don't fit a humanoid silhouette:

1. Generate 3 angles of each (front, 3/4, side) via your existing
   ChatGPT image flow — 90 PNGs total
2. In `CharacterModelBuilder`, when `lineage_kind == "non_humanoid"`,
   build a `Sprite3D` with billboard enabled and dynamic angle
   selection based on `_player_facing - _cam_yaw`
3. Group lineages: Bouncian uses bouncing-creature template,
   Beetlefolk uses insect template, etc. Reduces the ChatGPT
   generation to ~10 unique templates × 3 angles = 30 PNGs.

**Pass gate:** Bouncian appears as a 3D-feeling sprite on the dungeon
map, animations swap based on camera yaw.

### Phase 6 — Godot Integration (~3 days)

Replace the existing `CharacterModelBuilder.build_sprite_model` with
the new humanoid-or-billboard chooser:

```gdscript
func build_character_model_3d(lineage: String, ...) -> Node3D:
    if _is_humanoid_lineage(lineage):
        return _build_humanoid_model(lineage, weapon, armor, shield)
    else:
        return _build_billboard_model(lineage)
```

All existing call sites in dungeon.gd / explore.gd / level_up.gd
swap to the new function.

**Pass gate:** Region map, dungeon, level-up screen all show 3D
characters with correct lineage face + equipment.

---

## File / Folder Structure (Free Hybrid)

```
assets/
├── models/
│   ├── humanoid_base/
│   │   ├── x_bot.glb                   # Mixamo, ~2 MB
│   │   ├── x_bot_skeleton.tres
│   │   └── animations/
│   │       ├── idle.tres
│   │       ├── walk.tres
│   │       ├── attack_melee.tres
│   │       └── death.tres
│   ├── armor/                          # Quaternius CC0
│   │   ├── plate.glb
│   │   ├── chain.glb
│   │   └── ... (~10)
│   ├── weapons/                        # Quaternius CC0
│   │   ├── longsword.glb
│   │   ├── dagger.glb
│   │   └── ... (~50)
│   └── non_humanoid/
│       ├── bouncian/
│       │   ├── front.png
│       │   ├── three_quarter.png
│       │   └── side.png
│       └── ... (~30 lineage folders)
├── lineages/
│   └── portraits/                      # YOUR EXISTING PNGS
│       ├── boreal_human.png            # already there
│       ├── elf.png
│       └── ... (164 files)
└── shaders/
    ├── tint_body.gdshader              # per-lineage body color
    └── magic_glow.gdshader             # equipment magical effect
```

The existing PNG portraits stay where they are — they become the face
textures.

---

## What "Image Wrap" Means in Each Approach

You used the term casually so let me clarify which is which:

| Term | What it actually means | In this plan |
|---|---|---|
| **UV mapping / texture wrap** | Painting a 2D image onto a 3D mesh so it follows the curves | Option B — face onto humanoid head |
| **Billboard** | 2D quad that always faces the camera | Option A — Octopath style |
| **Imposter** | Pre-rendered 3D from N angles, swap based on view | Option A's smarter cousin |
| **Decal** | 2D image projected onto a 3D surface like a sticker | Same idea as UV mapping for our purposes |
| **Photogrammetry** | Combine many photos into a 3D mesh | Not applicable — needs many real photos |

The free hybrid uses the first three: UV mapping for humanoid faces,
billboard for non-humanoids.

---

## Tools You'll Need (All Free)

- **Blender** (free, open source) — UV unwrap the X-Bot head once,
  then never open it again unless something breaks. ~1 hour learning
  curve for this specific task.
- **Mixamo** (Adobe, free account) — base humanoid + animation library
- **Quaternius.com** — CC0 weapon/armor packs
- **Kenney.nl** — backup CC0 character packs
- **GIMP / Paint.NET** (free image editors) — only if you need to crop
  existing PNGs to fit the head UV layout
- **Godot 4** — already have

**No subscriptions, no API keys, no GPU requirements.**

---

## What I (Claude) Can Do

Once you confirm the free-hybrid approach:

1. Write the `build_character_model_3d` function in
   `CharacterModelBuilder` that handles both the humanoid + face
   texture path and the billboard path
2. Write the GDScript loader that reads your existing PNGs and
   generates the head atlas texture per lineage
3. Wire the `AnimationTree` state machine to gameplay events
   (attack triggers `Attack_Melee`, HP=0 triggers `Death`, etc.)
4. Map every existing weapon/armor name in `_ITEM_REGISTRY` to a
   Quaternius mesh filename
5. Build the non-humanoid billboard fallback path

What I CAN'T do:
- Download the X-Bot or Quaternius packs for you (you'll need to do
  that part — both are 1-click downloads from the linked sites)
- Open Blender to do the one-time UV unwrap of the head (I can write
  step-by-step instructions for that 5-minute operation)
- Inspect render quality

---

## Recommended Next Step

If you're in: I'll start with **Phase 2** (the GDScript loader that
turns your existing PNGs into face textures on a 3D head). It's the
most novel part of this plan and would prove the concept works
before you bother downloading X-Bot or Quaternius. I can write the
loader code dry-run against your existing PNG paths and you can
inspect what it produces.

Or: tell me to start with Phase 1 instead and I'll write the
Skeleton3D scene + AnimationTree first so the rig is ready when the
face textures land.

Either path: zero dollars, zero new accounts, ships in ~2 weeks.
