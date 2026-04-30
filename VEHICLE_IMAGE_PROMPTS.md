# Specialty Vehicle Image Prompts

Drop the generated images at `assets/vehicles_3d/` with the filenames listed below. The engine looks them up via `CharacterModelBuilder._load_vehicle_sprite()` — naming convention is `vehicle_<lowercase_underscored_name>.png`.

The renderer uses these as **billboarded sprites** on the region map (3D world map). Until images ship, a coloured placeholder box with a floating name label is shown.

## Image Specs

- **Format:** PNG with transparent background.
- **Aspect:** roughly 3:2 wide (vehicles look better wider than tall when seen as a top-isometric token).
- **Angle:** **3/4 isometric / forward 30° tilt** — never pure side-view, never pure top-down. The vehicle should be readable as an iconic silhouette.
- **Lighting:** even diffuse with a subtle rim from the upper-front so the form reads.
- **Style:** semi-realistic with arcane/fantasy detailing — glowing rune accents, brass + dark steel plating, visible spark-tank canisters where the GMG fluff calls for them.
- **Resolution:** 1024×1024 is fine; the engine downscales.
- **No background, no text, no shadow blob.**

## Prompts

Paste each block into ChatGPT with the standard image-gen kickoff. Wait the full pacing window between prompts.

### `vehicle_arcane_motorcycle.png` — Uncommon, Land
A sleek arcane motorcycle for one rider. Single seat, low-slung silhouette, brass fork and dark-steel chassis, faint blue rune-glow along the tank and exhaust. Twin spark-canister capsules mounted behind the rider. Studded leather saddle. 3/4 view, transparent background, semi-realistic fantasy-tech style.

### `vehicle_arcane_quad.png` — Rare, Land
A rugged four-wheel arcane quad with bullbar, knobby tires, two seats. Reinforced roll-cage, two visible spark-tanks bolted to the side panels. Heavy suspension, mud-splattered fenders. Steel/brass and matte-black paint with rune-etched glowing seams. 3/4 view, transparent background.

### `vehicle_arcane_sedan.png` — Uncommon, Land
A compact four-person arcane sedan. Streamlined retro-arcane silhouette, four passenger doors, smoked rune-glass windows. Brass trim, three spark-tank canisters mounted in a triangular pattern at the rear. Faintly glowing leyline runes along the side panels. 3/4 view, transparent background.

### `vehicle_arcane_rover.png` — Rare, Land
A robust six-person arcane rover for urban and rugged terrain. Boxy SUV silhouette with raised suspension, light bar, five spark-tanks mounted in an external rack on the roof. Brass and dark-green paint, rune-engraved bumpers. Heavy off-road tires. 3/4 view, transparent background.

### `vehicle_arcane_juggernaut.png` — Legendary, Land
A heavily armored six-wheeled arcane juggernaut military vehicle. Mounted dorsal Arcane Cannon with rune-glow muzzle, layered armor plating, gun ports, 10 spark-tanks visible in a recessed array. Riot/control variant — searchlights, dome cap, intimidating silhouette. Battered brass-and-charcoal finish with bright power-rune lines. 3/4 view, transparent background.

### `vehicle_arcane_copter.png` — Very Rare, Air
A nimble two-person arcane helicopter. Skeletal frame, single main rotor with rune-edged blades, tail boom with twin stabilizer fins, glassy bubble cockpit. Two passengers visible faintly. 5 spark-tanks slung underneath. Brass + dark navy paint, glowing leyline runes spiralling around the rotor housing. 3/4 view, hovering pose, transparent background.

### `vehicle_arcane_skimmer.png` — Uncommon, Water
A horse-sized one-rider arcane jetski/skimmer. Sleek hydrofoil hull, single seat with handlebars, twin spark-canisters at the stern. Etched runes along the prow, water-spray effect at the foils. Brass and teal paint. 3/4 view, transparent background.

### `vehicle_arcane_catamaran.png` — Rare, Water
A twin-hulled four-person arcane catamaran. Two slender hulls connected by a centre platform, twin Spark engines mounted between the hulls glowing softly. Open cockpit with passenger benches. Brass railings, weathered teak deck, faint rune-script along the spine. 3/4 view, on calm water, transparent background.

### `vehicle_arcane_barge.png` — Very Rare, Water
A massive arcane river barge — twelve-passenger floating fortress with a central cargo hold and a brass arcane crane mounted aft. Reinforced hull plating, ten spark-tank columns visible. Wheelhouse with smoked windows. Brass and dark-iron paint, glowing leyline channels along the gunwale. 3/4 view, transparent background.

### `vehicle_arcane_diver.png` — Very Rare, Submarine
A sleek arcane submersible for four. Teardrop hull with rune-inscribed void-tempered alloy plating, viewport bubble at the prow, dorsal fin with eight spark-tank canisters embedded. Glowing pressure-rune seams. Dark navy with brass trim. 3/4 view, slightly submerged with bubble trail, transparent background.

### `vehicle_arcane_drifter.png` — Very Rare, Void / Zero-G
A gravity-neutral arcane vessel for void travel. Six-passenger angular hull with no wings or wheels — replaced by inertia-dampener rings and three large directional spark-thruster nozzles. Hovering 5 ft off the ground. Modular cargo pods slung underneath. Pale silver and ultraviolet rune-glow finish, ghostly afterimage trail. 3/4 view, transparent background.

### `vehicle_aegis_ultima.png` — Apex, Mecha
A 60-foot-tall arcane sentinel mecha. Towering humanoid automaton with heavy plate armor, glowing Spark-Core chest reactor, dual shoulder-mounted Arcane Cannons, and a riot-shield gauntlet on one arm. Two cockpit canopies in the head and chest (Gunner + Controller positions). Suppression runes etched across every plate. Brass + steel + polished black paint, electric-blue rune-glow. Standing pose, 3/4 view, transparent background, towering over a faint city skyline silhouette for scale.

## Workflow notes

- Run them through ChatGPT one at a time. The previous creature-art batch settled at **3-minute / 4-minute alternating** pacing to dodge the rate cap.
- After each render, save as the exact filename above into `C:\Users\Acata\RimvaleGodot\assets\vehicles_3d\`.
- The engine reloads textures the next time `explore.gd` builds the player model — re-enter a region to see the new image.
- If a render comes back too dark / wrong angle, regenerate with the same prompt; the assets folder is the source of truth and any matching filename overrides the placeholder.
