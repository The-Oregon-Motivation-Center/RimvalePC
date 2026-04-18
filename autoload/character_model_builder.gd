## character_model_builder.gd
## Procedural 3D character model builder for Rimvale.
## Autoloaded as "CharacterModelBuilder".
##
## Builds a Node3D hierarchy from primitive meshes based on:
##   - Lineage  → body archetype, skin colour, features
##   - Armor    → overlay meshes on torso / limbs / head
##   - Weapon   → attached to right hand anchor
##   - Shield   → attached to left hand anchor

extends Node

# ═══════════════════════════════════════════════════════════════════════════════
#   BODY ARCHETYPE DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════
# Each archetype is a Dictionary keyed by id.
#
#   height       : float — total model height in world units (head-to-foot)
#   width        : float — shoulder width multiplier (1.0 = standard)
#   head_shape   : String — "sphere" | "box" | "capsule"
#   head_scale   : Vector3 — xyz scale of the head mesh
#   torso_shape  : String — "capsule" | "box"
#   torso_scale  : Vector3 — xyz scale
#   limb_radius  : float — capsule radius for arms/legs
#   arm_len      : float — total arm length (upper + lower)
#   leg_len      : float — total leg length
#   skin         : Color — default skin/body colour
#   eye          : Color — eye accent colour
#   features     : Array[String] — "tail","wings","horns","long_ears","snout",
#                                   "antenna","shell","tendrils","fins","glow",
#                                   "extra_arms","no_legs","floating","bulky"

const ARCHETYPE_HUMANOID := {
	"height": 1.8, "width": 1.0,
	"head_shape": "sphere", "head_scale": Vector3(0.24, 0.26, 0.24),
	"torso_shape": "capsule", "torso_scale": Vector3(0.32, 0.48, 0.20),
	"limb_radius": 0.07, "arm_len": 0.70, "leg_len": 0.80,
	"skin": Color(0.82, 0.70, 0.55), "eye": Color(0.35, 0.55, 0.85),
	"features": [],
}
const ARCHETYPE_HUMANOID_STOCKY := {
	"height": 1.3, "width": 1.2,
	"head_shape": "sphere", "head_scale": Vector3(0.26, 0.26, 0.26),
	"torso_shape": "box", "torso_scale": Vector3(0.38, 0.40, 0.24),
	"limb_radius": 0.09, "arm_len": 0.55, "leg_len": 0.55,
	"skin": Color(0.65, 0.55, 0.42), "eye": Color(0.50, 0.40, 0.20),
	"features": [],
}
const ARCHETYPE_HUMANOID_TALL := {
	"height": 2.2, "width": 1.15,
	"head_shape": "sphere", "head_scale": Vector3(0.26, 0.28, 0.26),
	"torso_shape": "capsule", "torso_scale": Vector3(0.36, 0.55, 0.22),
	"limb_radius": 0.08, "arm_len": 0.85, "leg_len": 0.95,
	"skin": Color(0.70, 0.60, 0.50), "eye": Color(0.55, 0.45, 0.30),
	"features": [],
}
const ARCHETYPE_HUMANOID_SLIM := {
	"height": 1.7, "width": 0.85,
	"head_shape": "sphere", "head_scale": Vector3(0.22, 0.24, 0.22),
	"torso_shape": "capsule", "torso_scale": Vector3(0.26, 0.44, 0.16),
	"limb_radius": 0.055, "arm_len": 0.68, "leg_len": 0.78,
	"skin": Color(0.88, 0.80, 0.72), "eye": Color(0.45, 0.70, 0.55),
	"features": ["long_ears"],
}
const ARCHETYPE_HUMANOID_SMALL := {
	"height": 1.0, "width": 0.85,
	"head_shape": "sphere", "head_scale": Vector3(0.22, 0.24, 0.22),
	"torso_shape": "capsule", "torso_scale": Vector3(0.24, 0.30, 0.16),
	"limb_radius": 0.05, "arm_len": 0.40, "leg_len": 0.40,
	"skin": Color(0.75, 0.68, 0.55), "eye": Color(0.60, 0.40, 0.15),
	"features": [],
}
const ARCHETYPE_BEAST_CANINE := {
	"height": 1.7, "width": 1.0,
	"head_shape": "capsule", "head_scale": Vector3(0.22, 0.26, 0.28),
	"torso_shape": "capsule", "torso_scale": Vector3(0.30, 0.46, 0.20),
	"limb_radius": 0.07, "arm_len": 0.65, "leg_len": 0.78,
	"skin": Color(0.60, 0.45, 0.30), "eye": Color(0.85, 0.65, 0.15),
	"features": ["snout", "tail"],
}
const ARCHETYPE_BEAST_FELINE := {
	"height": 1.65, "width": 0.95,
	"head_shape": "sphere", "head_scale": Vector3(0.22, 0.24, 0.24),
	"torso_shape": "capsule", "torso_scale": Vector3(0.28, 0.44, 0.18),
	"limb_radius": 0.06, "arm_len": 0.65, "leg_len": 0.76,
	"skin": Color(0.78, 0.62, 0.35), "eye": Color(0.95, 0.75, 0.10),
	"features": ["tail", "long_ears"],
}
const ARCHETYPE_BEAST_REPTILE := {
	"height": 1.75, "width": 1.05,
	"head_shape": "capsule", "head_scale": Vector3(0.24, 0.24, 0.30),
	"torso_shape": "box", "torso_scale": Vector3(0.34, 0.48, 0.22),
	"limb_radius": 0.075, "arm_len": 0.68, "leg_len": 0.78,
	"skin": Color(0.35, 0.50, 0.30), "eye": Color(0.90, 0.70, 0.10),
	"features": ["snout", "tail"],
}
const ARCHETYPE_BEAST_AVIAN := {
	"height": 1.65, "width": 0.95,
	"head_shape": "sphere", "head_scale": Vector3(0.22, 0.24, 0.26),
	"torso_shape": "capsule", "torso_scale": Vector3(0.28, 0.44, 0.18),
	"limb_radius": 0.06, "arm_len": 0.65, "leg_len": 0.76,
	"skin": Color(0.20, 0.20, 0.25), "eye": Color(0.90, 0.40, 0.10),
	"features": ["wings"],
}
const ARCHETYPE_BEAST_INSECT := {
	"height": 1.5, "width": 1.1,
	"head_shape": "sphere", "head_scale": Vector3(0.26, 0.22, 0.26),
	"torso_shape": "box", "torso_scale": Vector3(0.36, 0.42, 0.26),
	"limb_radius": 0.06, "arm_len": 0.60, "leg_len": 0.65,
	"skin": Color(0.30, 0.28, 0.22), "eye": Color(0.80, 0.20, 0.10),
	"features": ["antenna", "shell"],
}
const ARCHETYPE_PLANT := {
	"height": 1.6, "width": 1.0,
	"head_shape": "sphere", "head_scale": Vector3(0.26, 0.28, 0.26),
	"torso_shape": "capsule", "torso_scale": Vector3(0.30, 0.46, 0.22),
	"limb_radius": 0.07, "arm_len": 0.62, "leg_len": 0.72,
	"skin": Color(0.30, 0.55, 0.25), "eye": Color(0.50, 0.85, 0.30),
	"features": ["tendrils"],
}
const ARCHETYPE_UNDEAD := {
	"height": 1.75, "width": 0.92,
	"head_shape": "sphere", "head_scale": Vector3(0.24, 0.26, 0.24),
	"torso_shape": "box", "torso_scale": Vector3(0.30, 0.46, 0.18),
	"limb_radius": 0.055, "arm_len": 0.68, "leg_len": 0.78,
	"skin": Color(0.55, 0.50, 0.45), "eye": Color(0.40, 0.90, 0.30),
	"features": ["glow"],
}
const ARCHETYPE_ELEMENTAL := {
	"height": 1.8, "width": 1.05,
	"head_shape": "sphere", "head_scale": Vector3(0.24, 0.26, 0.24),
	"torso_shape": "capsule", "torso_scale": Vector3(0.32, 0.48, 0.20),
	"limb_radius": 0.07, "arm_len": 0.70, "leg_len": 0.80,
	"skin": Color(0.90, 0.50, 0.15), "eye": Color(1.00, 0.85, 0.20),
	"features": ["glow"],
}
const ARCHETYPE_CONSTRUCT := {
	"height": 1.7, "width": 1.1,
	"head_shape": "box", "head_scale": Vector3(0.24, 0.24, 0.24),
	"torso_shape": "box", "torso_scale": Vector3(0.36, 0.46, 0.24),
	"limb_radius": 0.08, "arm_len": 0.68, "leg_len": 0.76,
	"skin": Color(0.50, 0.48, 0.42), "eye": Color(0.30, 0.85, 0.95),
	"features": [],
}
const ARCHETYPE_ABERRATION := {
	"height": 1.7, "width": 1.0,
	"head_shape": "sphere", "head_scale": Vector3(0.30, 0.30, 0.28),
	"torso_shape": "capsule", "torso_scale": Vector3(0.32, 0.44, 0.22),
	"limb_radius": 0.065, "arm_len": 0.72, "leg_len": 0.74,
	"skin": Color(0.40, 0.30, 0.50), "eye": Color(0.85, 0.20, 0.80),
	"features": ["tendrils"],
}
const ARCHETYPE_AQUATIC := {
	"height": 1.75, "width": 1.0,
	"head_shape": "capsule", "head_scale": Vector3(0.24, 0.26, 0.26),
	"torso_shape": "capsule", "torso_scale": Vector3(0.32, 0.48, 0.20),
	"limb_radius": 0.065, "arm_len": 0.70, "leg_len": 0.78,
	"skin": Color(0.25, 0.50, 0.55), "eye": Color(0.20, 0.80, 0.65),
	"features": ["fins"],
}
const ARCHETYPE_AMORPHOUS := {
	"height": 1.2, "width": 1.3,
	"head_shape": "sphere", "head_scale": Vector3(0.28, 0.28, 0.28),
	"torso_shape": "capsule", "torso_scale": Vector3(0.40, 0.50, 0.36),
	"limb_radius": 0.10, "arm_len": 0.50, "leg_len": 0.35,
	"skin": Color(0.40, 0.55, 0.35), "eye": Color(0.70, 0.95, 0.25),
	"features": ["no_legs"],
}


# ═══════════════════════════════════════════════════════════════════════════════
#   LINEAGE → ARCHETYPE MAPPING
# ═══════════════════════════════════════════════════════════════════════════════
# Each lineage maps to: [archetype_dict, skin_override_or_null, eye_override_or_null, extra_features]
# "extra_features" is an Array of additional feature tags appended to the archetype defaults.
# A null skin/eye means "use archetype default".

var _lineage_map_cache: Dictionary = {}

func _get_lineage_map() -> Dictionary:
	if not _lineage_map_cache.is_empty():
		return _lineage_map_cache
	var H  = ARCHETYPE_HUMANOID
	var HS = ARCHETYPE_HUMANOID_STOCKY
	var HT = ARCHETYPE_HUMANOID_TALL
	var HL = ARCHETYPE_HUMANOID_SLIM
	var HM = ARCHETYPE_HUMANOID_SMALL
	var BC = ARCHETYPE_BEAST_CANINE
	var BF = ARCHETYPE_BEAST_FELINE
	var BR = ARCHETYPE_BEAST_REPTILE
	var BA = ARCHETYPE_BEAST_AVIAN
	var BI = ARCHETYPE_BEAST_INSECT
	var PL = ARCHETYPE_PLANT
	var UN = ARCHETYPE_UNDEAD
	var EL = ARCHETYPE_ELEMENTAL
	var CO = ARCHETYPE_CONSTRUCT
	var AB = ARCHETYPE_ABERRATION
	var AQ = ARCHETYPE_AQUATIC
	var AM = ARCHETYPE_AMORPHOUS
	# fmt: [archetype, skin_override, eye_override, extra_features]
	_lineage_map_cache = {
		# ── Standard Humans & near-humans ──
		"Regal Human":       [H,  Color(0.85, 0.72, 0.58), null, []],
		"Gilded Human":      [H,  Color(0.90, 0.78, 0.50), Color(0.85, 0.75, 0.30), []],
		"Arcanite Human":    [H,  Color(0.70, 0.65, 0.80), Color(0.60, 0.40, 0.90), ["glow"]],
		"Boreal Human":      [H,  Color(0.80, 0.82, 0.88), Color(0.55, 0.75, 0.95), []],
		"Cragborn Human":    [H,  Color(0.62, 0.55, 0.48), Color(0.50, 0.40, 0.30), []],
		"Sandstrider Human": [H,  Color(0.75, 0.60, 0.40), Color(0.65, 0.50, 0.20), []],
		"Scavenger Human":   [H,  Color(0.68, 0.58, 0.48), null, []],
		"Tiderunner Human":  [H,  Color(0.60, 0.65, 0.70), Color(0.30, 0.60, 0.75), []],
		"Fae-Touched Human": [HL, Color(0.85, 0.82, 0.78), Color(0.40, 0.80, 0.50), ["long_ears"]],
		"Thornwrought Human":[H,  Color(0.58, 0.55, 0.42), Color(0.45, 0.55, 0.30), ["tendrils"]],
		"Bloodsilk Human":   [H,  Color(0.78, 0.60, 0.60), Color(0.85, 0.20, 0.20), []],
		"Cryptkin Human":    [UN, Color(0.62, 0.58, 0.52), Color(0.35, 0.80, 0.35), []],
		"Hollowborn Human":  [UN, Color(0.55, 0.52, 0.48), Color(0.50, 0.90, 0.40), ["glow"]],
		"Mireborn Human":    [H,  Color(0.55, 0.52, 0.42), Color(0.45, 0.55, 0.30), []],
		"Nightborne Human":  [H,  Color(0.35, 0.30, 0.40), Color(0.70, 0.50, 0.90), ["glow"]],
		"Luminar Human":     [H,  Color(0.92, 0.88, 0.75), Color(0.95, 0.90, 0.50), ["glow"]],
		"Kelpheart Human":   [AQ, Color(0.40, 0.55, 0.50), Color(0.30, 0.70, 0.55), ["fins"]],
		"Madness-Touched Human":[AB, Color(0.55, 0.40, 0.55), Color(0.90, 0.20, 0.80), ["tendrils"]],
		"Riftborn Human":    [H,  Color(0.60, 0.55, 0.70), Color(0.70, 0.40, 0.90), ["glow"]],
		"Weirkin Human":     [AB, Color(0.50, 0.45, 0.55), Color(0.80, 0.30, 0.70), []],
		"Oblivari Human":    [AB, Color(0.30, 0.25, 0.35), Color(0.60, 0.20, 0.80), ["glow"]],
		"Sunderborn Human":  [HT, Color(0.65, 0.55, 0.48), Color(0.80, 0.50, 0.25), []],
		"Runeborn Human":    [H,  Color(0.72, 0.65, 0.60), Color(0.40, 0.65, 0.90), ["glow"]],
		"Galesworn Human":   [H,  Color(0.75, 0.72, 0.68), Color(0.50, 0.70, 0.85), []],
		"Sparkforged Human": [CO, Color(0.60, 0.55, 0.50), Color(0.30, 0.85, 0.95), ["glow"]],
		"Scourling Human":   [H,  Color(0.58, 0.50, 0.42), Color(0.70, 0.40, 0.20), []],
		"Mistborn Human":    [H,  Color(0.72, 0.72, 0.78), Color(0.60, 0.65, 0.80), []],
		"Ashrot Human":      [UN, Color(0.48, 0.42, 0.38), Color(0.80, 0.40, 0.15), ["glow"]],
		"Jackal Human":      [BC, Color(0.65, 0.50, 0.35), Color(0.85, 0.60, 0.15), ["snout"]],
		# ── Elves & Fae ──
		"Elf":            [HL, Color(0.85, 0.80, 0.72), Color(0.35, 0.65, 0.45), ["long_ears"]],
		"Twilightkin":    [HL, Color(0.55, 0.50, 0.65), Color(0.70, 0.50, 0.90), ["long_ears", "glow"]],
		"Starborn":       [HL, Color(0.70, 0.70, 0.85), Color(0.80, 0.80, 1.00), ["glow"]],
		"Starweaver":     [HL, Color(0.65, 0.65, 0.80), Color(0.90, 0.85, 1.00), ["glow"]],
		"Lightbound":     [H,  Color(0.92, 0.88, 0.75), Color(1.00, 0.92, 0.50), ["glow"]],
		"Auroran":        [H,  Color(0.95, 0.85, 0.65), Color(1.00, 0.90, 0.40), ["glow"]],
		"Dreamer":        [HL, Color(0.75, 0.72, 0.80), Color(0.65, 0.55, 0.90), []],
		"Lifeborne":      [HL, Color(0.80, 0.85, 0.70), Color(0.50, 0.85, 0.40), ["glow"]],
		# ── Beast-folk (Canine) ──
		"Canidar":        [BC, Color(0.55, 0.42, 0.30), Color(0.70, 0.55, 0.20), ["tail", "snout"]],
		"Vulpin":         [BC, Color(0.85, 0.50, 0.20), Color(0.90, 0.65, 0.15), ["tail", "snout"]],
		"Ursari":         [HT, Color(0.50, 0.40, 0.30), Color(0.45, 0.35, 0.20), ["snout"]],
		"Taurin":         [HT, Color(0.55, 0.40, 0.28), Color(0.60, 0.40, 0.15), ["horns", "tail"]],
		# ── Beast-folk (Feline) ──
		"Felinar":        [BF, Color(0.78, 0.60, 0.35), Color(0.90, 0.75, 0.10), ["tail"]],
		# ── Beast-folk (Reptile / Dragon) ──
		"Goldscale":      [BR, Color(0.85, 0.75, 0.30), Color(0.90, 0.70, 0.10), ["tail"]],
		"Serpentine":     [BR, Color(0.35, 0.50, 0.30), Color(0.80, 0.65, 0.10), ["tail"]],
		"Saurian":        [BR, Color(0.40, 0.45, 0.30), Color(0.75, 0.60, 0.15), ["tail"]],
		"Drakari":        [BR, Color(0.30, 0.40, 0.35), Color(0.90, 0.50, 0.10), ["tail", "wings"]],
		# ── Beast-folk (Avian) ──
		"Corvian":        [BA, Color(0.15, 0.15, 0.20), Color(0.85, 0.40, 0.10), ["wings"]],
		"Quillari":       [BA, Color(0.55, 0.50, 0.40), Color(0.80, 0.55, 0.20), ["wings"]],
		# ── Beast-folk (Misc) ──
		"Cervin":         [H,  Color(0.60, 0.50, 0.35), Color(0.55, 0.45, 0.20), ["horns"]],
		"Bouncian":       [HM, Color(0.85, 0.80, 0.70), Color(0.55, 0.70, 0.35), []],
		"Tetrasimian":    [H,  Color(0.55, 0.42, 0.30), Color(0.65, 0.50, 0.20), ["tail", "extra_arms"]],
		"Duckslings":     [HM, Color(0.85, 0.80, 0.50), Color(0.40, 0.45, 0.35), []],
		"Pangol":         [HS, Color(0.55, 0.50, 0.38), Color(0.50, 0.42, 0.25), ["shell"]],
		# ── Insectoid ──
		"Beetlefolk":     [BI, Color(0.30, 0.28, 0.22), Color(0.60, 0.40, 0.10), ["shell", "antenna"]],
		"Hexshell":       [BI, Color(0.35, 0.30, 0.25), Color(0.50, 0.70, 0.20), ["shell"]],
		"Hexkin":         [BI, Color(0.38, 0.28, 0.35), Color(0.70, 0.30, 0.60), ["antenna"]],
		"Bilecrawler":    [BI, Color(0.35, 0.40, 0.25), Color(0.65, 0.80, 0.15), ["antenna"]],
		# ── Plant-folk ──
		"Bramblekin":     [PL, Color(0.35, 0.50, 0.25), Color(0.55, 0.75, 0.30), ["tendrils"]],
		"Myconid":        [PL, Color(0.55, 0.48, 0.38), Color(0.60, 0.80, 0.25), []],
		"Mossling":       [PL, Color(0.30, 0.55, 0.30), Color(0.40, 0.70, 0.25), ["tendrils"]],
		"Hollowroot":     [PL, Color(0.40, 0.35, 0.28), Color(0.50, 0.65, 0.20), []],
		"Hearthkin":      [PL, Color(0.60, 0.50, 0.35), Color(0.70, 0.55, 0.20), []],
		"Blackroot":      [PL, Color(0.22, 0.20, 0.18), Color(0.40, 0.55, 0.15), ["tendrils"]],
		"Verdant":        [PL, Color(0.28, 0.55, 0.28), Color(0.45, 0.80, 0.30), []],
		"Blightmire":     [PL, Color(0.30, 0.28, 0.22), Color(0.55, 0.60, 0.15), ["tendrils"]],
		# ── Undead & Death-touched ──
		"Skulkin":        [UN, Color(0.75, 0.72, 0.65), Color(0.40, 0.90, 0.30), []],
		"Gravetouched":   [UN, Color(0.50, 0.48, 0.45), Color(0.35, 0.85, 0.35), ["glow"]],
		"Gravemantle":    [UN, Color(0.42, 0.40, 0.38), Color(0.30, 0.75, 0.30), ["glow"]],
		"Tombwalker":     [UN, Color(0.55, 0.50, 0.42), Color(0.40, 0.90, 0.40), []],
		"Myrrhkin":       [UN, Color(0.60, 0.55, 0.45), Color(0.50, 0.80, 0.35), []],
		"Rotborn Herald": [UN, Color(0.38, 0.35, 0.32), Color(0.50, 0.85, 0.20), ["tendrils"]],
		"Carrionari":     [UN, Color(0.45, 0.38, 0.32), Color(0.60, 0.80, 0.15), []],
		"Graveleaps":     [UN, Color(0.52, 0.48, 0.42), Color(0.45, 0.85, 0.30), []],
		"Crimson Veil":   [UN, Color(0.65, 0.30, 0.30), Color(0.90, 0.20, 0.20), ["glow"]],
		# ── Elemental (Fire) ──
		"Emberkin":       [EL, Color(0.90, 0.45, 0.10), Color(1.00, 0.70, 0.10), ["glow"]],
		"Cindervolk":     [EL, Color(0.75, 0.35, 0.10), Color(0.95, 0.55, 0.10), ["glow"]],
		"Volcant":        [EL, Color(0.80, 0.30, 0.08), Color(1.00, 0.60, 0.05), ["glow"]],
		"Kindlekin":      [EL, Color(0.92, 0.60, 0.15), Color(1.00, 0.80, 0.20), ["glow"]],
		"Hellforged":     [CO, Color(0.55, 0.25, 0.10), Color(0.95, 0.40, 0.05), ["glow"]],
		"Sunforged":      [EL, Color(0.95, 0.80, 0.30), Color(1.00, 0.92, 0.40), ["glow"]],
		# ── Elemental (Ice/Wind/Storm) ──
		"Frostborn":      [EL, Color(0.70, 0.82, 0.95), Color(0.50, 0.75, 1.00), ["glow"]],
		"Glaceari":       [EL, Color(0.65, 0.78, 0.92), Color(0.45, 0.70, 0.95), ["glow"]],
		"Windswept":      [H,  Color(0.78, 0.80, 0.85), Color(0.55, 0.72, 0.90), []],
		"Stormclad":      [HT, Color(0.50, 0.55, 0.70), Color(0.40, 0.60, 0.95), ["glow"]],
		"Skysworn":       [H,  Color(0.70, 0.75, 0.85), Color(0.50, 0.65, 0.95), ["wings"]],
		"Zephyrkin":      [HL, Color(0.78, 0.82, 0.88), Color(0.55, 0.75, 0.95), []],
		"Zephyrite":      [HL, Color(0.75, 0.80, 0.90), Color(0.50, 0.70, 0.95), []],
		"Cloudling":      [HM, Color(0.85, 0.88, 0.92), Color(0.60, 0.75, 0.95), ["floating"]],
		"Nimbari":        [H,  Color(0.65, 0.70, 0.82), Color(0.45, 0.60, 0.90), ["glow"]],
		# ── Elemental (Light/Dark) ──
		"Sable":          [H,  Color(0.25, 0.22, 0.28), Color(0.55, 0.40, 0.70), ["glow"]],
		"Duskling":       [HL, Color(0.35, 0.30, 0.38), Color(0.60, 0.45, 0.75), ["glow"]],
		"Gloomling":      [HM, Color(0.30, 0.28, 0.35), Color(0.50, 0.40, 0.70), ["glow"]],
		"Lanternborn":    [H,  Color(0.88, 0.82, 0.55), Color(0.95, 0.85, 0.30), ["glow"]],
		"Candlites":      [HM, Color(0.90, 0.80, 0.45), Color(1.00, 0.90, 0.30), ["glow"]],
		# ── Construct / Mechanical ──
		"Chronogears":    [CO, Color(0.55, 0.50, 0.40), Color(0.40, 0.80, 0.90), []],
		"Voxshell":       [CO, Color(0.48, 0.45, 0.42), Color(0.30, 0.75, 0.85), []],
		"Voxilite":       [CO, Color(0.50, 0.48, 0.45), Color(0.35, 0.80, 0.90), ["glow"]],
		"Marionox":       [CO, Color(0.45, 0.40, 0.38), Color(0.50, 0.70, 0.80), []],
		"Ironjaw":        [CO, Color(0.52, 0.48, 0.42), Color(0.40, 0.60, 0.50), []],
		"Ironhide":       [HS, Color(0.50, 0.48, 0.45), Color(0.45, 0.55, 0.40), ["shell"]],
		"Ferrusk":        [CO, Color(0.55, 0.45, 0.35), Color(0.60, 0.50, 0.30), []],
		"Rustspawn":      [CO, Color(0.55, 0.40, 0.28), Color(0.65, 0.45, 0.20), []],
		"Scrapwright":    [CO, Color(0.52, 0.48, 0.40), Color(0.45, 0.65, 0.70), []],
		"Kettlekyn":      [CO, Color(0.58, 0.50, 0.38), Color(0.70, 0.55, 0.25), []],
		"Echoform Warden":[CO, Color(0.48, 0.50, 0.55), Color(0.40, 0.70, 0.85), ["glow"]],
		# ── Aberration / Void ──
		"Abyssari":       [AB, Color(0.20, 0.15, 0.30), Color(0.50, 0.20, 0.80), ["tendrils", "glow"]],
		"Nullborn":       [AB, Color(0.15, 0.12, 0.20), Color(0.40, 0.15, 0.60), ["glow"]],
		"Nullborn Ascetic":[AB,Color(0.18, 0.15, 0.25), Color(0.45, 0.20, 0.65), ["glow"]],
		"Nihilian":       [AB, Color(0.10, 0.08, 0.15), Color(0.35, 0.10, 0.55), ["glow"]],
		"Brain Eater":    [AB, Color(0.50, 0.35, 0.50), Color(0.80, 0.30, 0.70), ["tendrils"]],
		"Whisperspawn":   [AB, Color(0.35, 0.30, 0.40), Color(0.65, 0.40, 0.75), ["tendrils"]],
		"Shadewretch":    [AB, Color(0.25, 0.20, 0.30), Color(0.55, 0.35, 0.65), ["glow"]],
		"Parallax Watchers":[AB, Color(0.40, 0.38, 0.50), Color(0.70, 0.50, 0.90), ["glow"]],
		"Voidwatcher":    [AB, Color(0.15, 0.10, 0.25), Color(0.50, 0.20, 0.75), ["glow"]],
		"Echo-Touched":   [H,  Color(0.60, 0.58, 0.65), Color(0.55, 0.50, 0.75), ["glow"]],
		"Huskdrone":      [CO, Color(0.35, 0.30, 0.28), Color(0.50, 0.35, 0.55), []],
		# ── Aquatic ──
		"Fathomari":      [AQ, Color(0.20, 0.45, 0.55), Color(0.25, 0.75, 0.60), ["fins"]],
		"Tidewoven":      [AQ, Color(0.30, 0.50, 0.55), Color(0.20, 0.70, 0.55), ["fins"]],
		"Hydrakari":      [AQ, Color(0.25, 0.42, 0.48), Color(0.30, 0.65, 0.55), ["fins", "tail"]],
		"Trenchborn":     [AQ, Color(0.22, 0.35, 0.40), Color(0.20, 0.55, 0.50), ["fins"]],
		"Mireling":       [AQ, Color(0.35, 0.45, 0.35), Color(0.40, 0.60, 0.30), ["fins"]],
		"Bogtender":      [PL, Color(0.38, 0.45, 0.30), Color(0.45, 0.60, 0.25), ["tendrils"]],
		"Bloatfen Whisperer":[AM, Color(0.40, 0.45, 0.30), Color(0.55, 0.65, 0.20), []],
		# ── Amorphous / Slime ──
		"Oozeling":       [AM, Color(0.35, 0.55, 0.30), Color(0.50, 0.80, 0.25), []],
		"Sludgeling":     [AM, Color(0.40, 0.38, 0.28), Color(0.55, 0.50, 0.20), []],
		"Dregspawn":      [AM, Color(0.32, 0.30, 0.25), Color(0.45, 0.42, 0.18), []],
		# ── Swamp / Corrupted ──
		"Mirevenom":      [BR, Color(0.35, 0.45, 0.28), Color(0.55, 0.70, 0.15), ["tail"]],
		"Snareling":      [HM, Color(0.45, 0.38, 0.30), Color(0.60, 0.45, 0.15), ["snout"]],
		"Scornshard":     [HS, Color(0.40, 0.32, 0.25), Color(0.55, 0.40, 0.15), ["shell"]],
		"Chokeling":      [HM, Color(0.38, 0.35, 0.28), Color(0.50, 0.45, 0.20), ["tendrils"]],
		"Flenskin":       [UN, Color(0.52, 0.42, 0.35), Color(0.65, 0.40, 0.20), []],
		"Filthlit Spawn": [HM, Color(0.35, 0.32, 0.25), Color(0.48, 0.42, 0.15), ["glow"]],
		# ── Glass / Crystal ──
		"Glassborn":      [H,  Color(0.75, 0.85, 0.90), Color(0.60, 0.80, 0.95), ["glow"]],
		"Prismari":       [HL, Color(0.80, 0.85, 0.92), Color(0.70, 0.85, 1.00), ["glow"]],
		"Shardkin":       [H,  Color(0.70, 0.78, 0.85), Color(0.55, 0.72, 0.90), []],
		"Shardwraith":    [UN, Color(0.65, 0.72, 0.82), Color(0.50, 0.70, 0.85), ["glow"]],
		"Porcelari":      [HL, Color(0.90, 0.88, 0.85), Color(0.70, 0.75, 0.80), []],
		# ── Silver / Holy ──
		"Silverblood":    [H,  Color(0.80, 0.82, 0.85), Color(0.70, 0.75, 0.85), []],
		"Obsidian Seraph":[HT, Color(0.20, 0.18, 0.22), Color(0.85, 0.75, 0.30), ["wings"]],
		"Obsidian":       [HS, Color(0.18, 0.16, 0.20), Color(0.55, 0.45, 0.25), ["shell"]],
		"Convergents":    [H,  Color(0.78, 0.75, 0.70), Color(0.65, 0.60, 0.50), ["glow"]],
		"Pulsebound Hierophant":[HT, Color(0.82, 0.78, 0.65), Color(0.90, 0.80, 0.40), ["glow"]],
		"Soulbinder":     [AB, Color(0.50, 0.40, 0.55), Color(0.70, 0.45, 0.80), ["glow"]],
		"Threnody Warden":[HT, Color(0.55, 0.50, 0.60), Color(0.65, 0.55, 0.75), ["glow"]],
		# ── Gremlin / Goblinoid ──
		"Gremlin":        [HM, Color(0.45, 0.55, 0.35), Color(0.60, 0.70, 0.20), ["long_ears"]],
		"Gremlidian":     [HM, Color(0.42, 0.52, 0.32), Color(0.55, 0.65, 0.18), ["long_ears"]],
		"Groblodyte":     [HS, Color(0.38, 0.48, 0.30), Color(0.50, 0.60, 0.15), []],
		"Gutterborn":     [HM, Color(0.48, 0.45, 0.38), Color(0.55, 0.48, 0.25), []],
		"Gullet Mimes":   [HM, Color(0.50, 0.48, 0.42), Color(0.45, 0.42, 0.35), []],
		# ── Dark / Infernal ──
		"Hagborn Crone":  [H,  Color(0.45, 0.38, 0.42), Color(0.65, 0.35, 0.55), ["horns"]],
		"Umbrawyrm":      [BR, Color(0.18, 0.15, 0.22), Color(0.50, 0.30, 0.65), ["tail", "wings"]],
		"Cavernborn":     [HS, Color(0.45, 0.42, 0.38), Color(0.40, 0.50, 0.35), []],
		# ── Special / Unique ──
		"Aetherian":      [HL, Color(0.80, 0.82, 0.90), Color(0.70, 0.75, 0.95), ["glow", "floating"]],
		"Archivist":      [H,  Color(0.72, 0.68, 0.62), Color(0.50, 0.55, 0.60), []],
		"Bookborn":       [H,  Color(0.70, 0.65, 0.55), Color(0.55, 0.50, 0.40), []],
		"Lorekeeper":     [H,  Color(0.75, 0.70, 0.60), Color(0.55, 0.55, 0.50), []],
		"Bespoker":       [AB, Color(0.45, 0.40, 0.50), Color(0.65, 0.50, 0.75), ["tendrils"]],
		"Warden":         [HT, Color(0.55, 0.50, 0.42), Color(0.50, 0.55, 0.35), []],
		"Panoplian":      [H,  Color(0.80, 0.75, 0.65), Color(0.70, 0.65, 0.50), []],
		"Mercenary":      [H,  Color(0.72, 0.62, 0.50), Color(0.55, 0.45, 0.30), []],
		"Gladiator":      [HT, Color(0.75, 0.60, 0.45), Color(0.60, 0.50, 0.25), []],
		"Wandering Duelist":[H,Color(0.70, 0.60, 0.50), Color(0.55, 0.45, 0.30), []],
		"Guildmaster":    [H,  Color(0.78, 0.72, 0.60), Color(0.65, 0.58, 0.40), []],
		"Blood Spawn":    [AB, Color(0.65, 0.20, 0.20), Color(0.90, 0.15, 0.15), ["glow"]],
		"Ashenborn":      [EL, Color(0.50, 0.45, 0.40), Color(0.70, 0.50, 0.20), ["glow"]],
		"Disjointed Hounds":[BC,Color(0.45, 0.35, 0.30), Color(0.60, 0.40, 0.20), ["snout"]],
		"Driftwood Woken":[CO, Color(0.55, 0.48, 0.35), Color(0.45, 0.55, 0.30), []],
		"Dustborn":       [H,  Color(0.65, 0.58, 0.45), Color(0.55, 0.48, 0.30), []],
		"Glimmerfolk":    [HL, Color(0.82, 0.85, 0.88), Color(0.75, 0.80, 0.90), ["glow"]],
		"Grimshell":      [HS, Color(0.38, 0.35, 0.30), Color(0.48, 0.42, 0.25), ["shell"]],
		"Lithari":        [HS, Color(0.58, 0.55, 0.50), Color(0.50, 0.48, 0.42), []],
		"Gravari":        [HT, Color(0.55, 0.52, 0.48), Color(0.48, 0.45, 0.38), []],
		"Lost":           [UN, Color(0.50, 0.48, 0.50), Color(0.55, 0.50, 0.60), ["glow"]],
		"Moonkin":        [HL, Color(0.72, 0.72, 0.82), Color(0.65, 0.65, 0.85), ["glow"]],
		"Mistborne Hatchling":[HM, Color(0.60, 0.58, 0.65), Color(0.55, 0.50, 0.65), []],
		# ── Missing lineages (added) ──
		"Corrupted Wyrmblood":[BR, Color(0.35, 0.25, 0.30), Color(0.80, 0.20, 0.20), ["tail", "wings", "glow"]],
		"Venari":         [BC, Color(0.50, 0.42, 0.30), Color(0.65, 0.50, 0.20), ["snout", "tail"]],
		"Watchling":      [HM, Color(0.55, 0.58, 0.62), Color(0.50, 0.70, 0.85), ["glow"]],
	}
	return _lineage_map_cache


# ═══════════════════════════════════════════════════════════════════════════════
#   ARMOR DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════
# weight_class: "none" | "light" | "medium" | "heavy"
# Each class adds overlays at increasing coverage.

const ARMOR_DEFS: Dictionary = {
	"None":            {"weight": "none",   "color": Color(0,0,0,0), "metallic": 0.0, "roughness": 1.0},
	"Padded":          {"weight": "light",  "color": Color(0.55, 0.50, 0.42), "metallic": 0.0, "roughness": 0.85},
	"Leather":         {"weight": "light",  "color": Color(0.45, 0.32, 0.18), "metallic": 0.05, "roughness": 0.75},
	"Studded Leather": {"weight": "light",  "color": Color(0.42, 0.30, 0.18), "metallic": 0.15, "roughness": 0.65},
	"Hide":            {"weight": "medium", "color": Color(0.50, 0.40, 0.28), "metallic": 0.0, "roughness": 0.80},
	"Chain Shirt":     {"weight": "medium", "color": Color(0.65, 0.65, 0.65), "metallic": 0.55, "roughness": 0.40},
	"Scale Mail":      {"weight": "medium", "color": Color(0.60, 0.62, 0.58), "metallic": 0.45, "roughness": 0.45},
	"Breastplate":     {"weight": "medium", "color": Color(0.70, 0.68, 0.60), "metallic": 0.60, "roughness": 0.35},
	"Half Plate":      {"weight": "medium", "color": Color(0.72, 0.70, 0.65), "metallic": 0.65, "roughness": 0.30},
	"Ring Mail":       {"weight": "heavy",  "color": Color(0.55, 0.55, 0.52), "metallic": 0.50, "roughness": 0.45},
	"Chain Mail":      {"weight": "heavy",  "color": Color(0.62, 0.62, 0.60), "metallic": 0.60, "roughness": 0.38},
	"Splint":          {"weight": "heavy",  "color": Color(0.68, 0.66, 0.60), "metallic": 0.70, "roughness": 0.30},
	"Plate":           {"weight": "heavy",  "color": Color(0.78, 0.76, 0.72), "metallic": 0.85, "roughness": 0.20},
}

const SHIELD_DEFS: Dictionary = {
	"Standard Shield": {"size": Vector3(0.40, 0.55, 0.06), "color": Color(0.50, 0.38, 0.18), "metallic": 0.15},
	"Tower Shield":    {"size": Vector3(0.50, 0.80, 0.08), "color": Color(0.58, 0.55, 0.48), "metallic": 0.35},
}


# ═══════════════════════════════════════════════════════════════════════════════
#   WEAPON DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════
# shape: "blade" | "axe" | "hammer" | "polearm" | "staff" | "dagger" | "bow" | "crossbow" | "gun" | "whip" | "fist"
# size: Vector3 — rough bounding dimensions
# color: Color — primary material colour
# metallic: float — metallic factor

const WEAPON_DEFS: Dictionary = {
	"Club":            {"shape": "hammer",  "size": Vector3(0.08, 0.50, 0.08), "color": Color(0.45, 0.35, 0.22), "metallic": 0.0},
	"Dagger":          {"shape": "dagger",  "size": Vector3(0.04, 0.28, 0.02), "color": Color(0.70, 0.70, 0.68), "metallic": 0.7},
	"Greatclub":       {"shape": "hammer",  "size": Vector3(0.12, 0.70, 0.12), "color": Color(0.42, 0.32, 0.20), "metallic": 0.0},
	"Handaxe":         {"shape": "axe",     "size": Vector3(0.14, 0.35, 0.04), "color": Color(0.65, 0.60, 0.55), "metallic": 0.5},
	"Javelin":         {"shape": "polearm", "size": Vector3(0.03, 0.80, 0.03), "color": Color(0.55, 0.45, 0.30), "metallic": 0.2},
	"Light Hammer":    {"shape": "hammer",  "size": Vector3(0.08, 0.32, 0.08), "color": Color(0.60, 0.58, 0.55), "metallic": 0.5},
	"Mace":            {"shape": "hammer",  "size": Vector3(0.10, 0.45, 0.10), "color": Color(0.65, 0.62, 0.58), "metallic": 0.6},
	"Quarterstaff":    {"shape": "staff",   "size": Vector3(0.04, 0.90, 0.04), "color": Color(0.50, 0.40, 0.25), "metallic": 0.0},
	"Sickle":          {"shape": "dagger",  "size": Vector3(0.10, 0.30, 0.02), "color": Color(0.60, 0.58, 0.52), "metallic": 0.4},
	"Spear":           {"shape": "polearm", "size": Vector3(0.04, 0.95, 0.04), "color": Color(0.52, 0.42, 0.28), "metallic": 0.3},
	"Shortsword":      {"shape": "blade",   "size": Vector3(0.05, 0.50, 0.02), "color": Color(0.72, 0.70, 0.68), "metallic": 0.7},
	"Chakram":         {"shape": "dagger",  "size": Vector3(0.20, 0.20, 0.02), "color": Color(0.68, 0.65, 0.60), "metallic": 0.6},
	"Dart":            {"shape": "dagger",  "size": Vector3(0.02, 0.18, 0.02), "color": Color(0.60, 0.58, 0.55), "metallic": 0.5},
	"Light Crossbow":  {"shape": "crossbow","size": Vector3(0.25, 0.30, 0.10), "color": Color(0.48, 0.38, 0.25), "metallic": 0.3},
	"Shortbow":        {"shape": "bow",     "size": Vector3(0.05, 0.65, 0.05), "color": Color(0.50, 0.40, 0.25), "metallic": 0.0},
	"Sling":           {"shape": "whip",    "size": Vector3(0.04, 0.35, 0.04), "color": Color(0.45, 0.35, 0.22), "metallic": 0.0},
	"Battleaxe":       {"shape": "axe",     "size": Vector3(0.18, 0.55, 0.05), "color": Color(0.65, 0.62, 0.58), "metallic": 0.6},
	"Flail":           {"shape": "hammer",  "size": Vector3(0.10, 0.50, 0.10), "color": Color(0.62, 0.58, 0.55), "metallic": 0.6},
	"Glaive":          {"shape": "polearm", "size": Vector3(0.10, 1.10, 0.04), "color": Color(0.65, 0.60, 0.55), "metallic": 0.5},
	"Greataxe":        {"shape": "axe",     "size": Vector3(0.22, 0.75, 0.06), "color": Color(0.60, 0.58, 0.55), "metallic": 0.6},
	"Greatsword":      {"shape": "blade",   "size": Vector3(0.08, 0.90, 0.03), "color": Color(0.75, 0.73, 0.70), "metallic": 0.8},
	"Halberd":         {"shape": "polearm", "size": Vector3(0.14, 1.10, 0.05), "color": Color(0.62, 0.60, 0.55), "metallic": 0.5},
	"Katana":          {"shape": "blade",   "size": Vector3(0.05, 0.65, 0.02), "color": Color(0.75, 0.72, 0.68), "metallic": 0.8},
	"Lance":           {"shape": "polearm", "size": Vector3(0.06, 1.20, 0.06), "color": Color(0.55, 0.48, 0.35), "metallic": 0.3},
	"Longsword":       {"shape": "blade",   "size": Vector3(0.06, 0.70, 0.02), "color": Color(0.73, 0.71, 0.68), "metallic": 0.75},
	"Maul":            {"shape": "hammer",  "size": Vector3(0.15, 0.75, 0.12), "color": Color(0.58, 0.55, 0.50), "metallic": 0.6},
	"Morningstar":     {"shape": "hammer",  "size": Vector3(0.12, 0.55, 0.12), "color": Color(0.62, 0.58, 0.55), "metallic": 0.65},
	"Pike":            {"shape": "polearm", "size": Vector3(0.04, 1.30, 0.04), "color": Color(0.55, 0.48, 0.35), "metallic": 0.3},
	"Rapier":          {"shape": "blade",   "size": Vector3(0.03, 0.65, 0.02), "color": Color(0.76, 0.74, 0.72), "metallic": 0.8},
	"Scimitar":        {"shape": "blade",   "size": Vector3(0.06, 0.55, 0.02), "color": Color(0.72, 0.68, 0.60), "metallic": 0.7},
	"Trident":         {"shape": "polearm", "size": Vector3(0.10, 0.95, 0.04), "color": Color(0.65, 0.60, 0.55), "metallic": 0.5},
	"Warhammer":       {"shape": "hammer",  "size": Vector3(0.12, 0.55, 0.10), "color": Color(0.60, 0.58, 0.55), "metallic": 0.65},
	"War Pick":        {"shape": "axe",     "size": Vector3(0.10, 0.50, 0.04), "color": Color(0.62, 0.60, 0.56), "metallic": 0.6},
	"Whip":            {"shape": "whip",    "size": Vector3(0.03, 0.80, 0.03), "color": Color(0.42, 0.30, 0.18), "metallic": 0.0},
	"Blowgun":         {"shape": "staff",   "size": Vector3(0.03, 0.60, 0.03), "color": Color(0.48, 0.40, 0.28), "metallic": 0.0},
	"Hand Crossbow":   {"shape": "crossbow","size": Vector3(0.18, 0.22, 0.08), "color": Color(0.50, 0.40, 0.28), "metallic": 0.3},
	"Heavy Crossbow":  {"shape": "crossbow","size": Vector3(0.30, 0.38, 0.12), "color": Color(0.48, 0.38, 0.25), "metallic": 0.35},
	"Longbow":         {"shape": "bow",     "size": Vector3(0.05, 0.90, 0.05), "color": Color(0.50, 0.40, 0.25), "metallic": 0.0},
	"Heavy Sling":     {"shape": "whip",    "size": Vector3(0.06, 0.45, 0.06), "color": Color(0.45, 0.35, 0.22), "metallic": 0.0},
	"Musket":          {"shape": "gun",     "size": Vector3(0.06, 0.80, 0.06), "color": Color(0.45, 0.38, 0.28), "metallic": 0.5},
	"Pistol":          {"shape": "gun",     "size": Vector3(0.06, 0.28, 0.04), "color": Color(0.42, 0.35, 0.25), "metallic": 0.5},
}


# ═══════════════════════════════════════════════════════════════════════════════
#   PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Build a full 3D character model for the given lineage, equipment, and scale.
## Returns a Node3D ready to add as a child.
func build_model(lineage_name: String, weapon_name: String = "None",
		armor_name: String = "None", shield_name: String = "None",
		model_scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "CharModel_%s" % lineage_name.replace(" ", "_")

	# Resolve archetype
	var lmap: Dictionary = _get_lineage_map()
	var entry: Array = lmap.get(lineage_name, [ARCHETYPE_HUMANOID, null, null, []])
	var arch: Dictionary  = entry[0]
	var skin_col: Color   = entry[1] if entry[1] != null else arch["skin"]
	var eye_col: Color    = entry[2] if entry[2] != null else arch["eye"]
	var feats: Array      = Array(arch["features"]).duplicate()
	for f in entry[3]:
		if f not in feats:
			feats.append(f)

	# Resolve armor
	var armor_def: Dictionary = ARMOR_DEFS.get(armor_name, ARMOR_DEFS["None"])
	var armor_weight: String  = armor_def.get("weight", "none")

	# ── Build body ──────────────────────────────────────────────────────────
	var body := Node3D.new(); body.name = "Body"
	root.add_child(body)

	var h: float = arch["height"] * model_scale
	var w: float = arch["width"]

	# --- Torso ---
	var torso_node := Node3D.new(); torso_node.name = "Torso"
	var torso_scale: Vector3 = arch["torso_scale"]
	var torso_y: float = (arch["leg_len"] + torso_scale.y * 0.5) * model_scale
	torso_node.position = Vector3(0, torso_y, 0)
	body.add_child(torso_node)

	var torso_mi := _make_body_part(arch["torso_shape"], torso_scale * model_scale * Vector3(w, 1, 1), skin_col)
	torso_node.add_child(torso_mi)

	# --- Head ---
	var head_scale: Vector3 = arch["head_scale"]
	var head_y: float = torso_y + torso_scale.y * 0.5 * model_scale + head_scale.y * 0.5 * model_scale + 0.02 * model_scale
	var head_node := Node3D.new(); head_node.name = "Head"
	head_node.position = Vector3(0, head_y, 0)
	body.add_child(head_node)

	var head_mi := _make_body_part(arch["head_shape"], head_scale * model_scale, skin_col)
	head_node.add_child(head_mi)

	# Eyes (two small spheres)
	_add_eyes(head_node, head_scale * model_scale, eye_col)

	# --- Arms ---
	var arm_half: float = arch["arm_len"] * 0.5 * model_scale
	var limb_r: float   = arch["limb_radius"] * model_scale
	var shoulder_y: float = torso_y + torso_scale.y * 0.35 * model_scale
	var shoulder_x: float = torso_scale.x * 0.5 * w * model_scale + limb_r * 1.5

	for side in [-1.0, 1.0]:
		var arm_root := Node3D.new()
		arm_root.name = "Arm_L" if side < 0 else "Arm_R"
		arm_root.position = Vector3(shoulder_x * side, shoulder_y, 0)
		body.add_child(arm_root)

		# Upper arm
		var upper := _make_limb(limb_r, arm_half, skin_col)
		upper.position = Vector3(0, -arm_half * 0.5, 0)
		arm_root.add_child(upper)
		# Lower arm
		var lower := _make_limb(limb_r * 0.85, arm_half, skin_col)
		lower.position = Vector3(0, -arm_half * 1.5, 0)
		arm_root.add_child(lower)

		# Hand anchor (bottom of arm)
		var hand := Node3D.new()
		hand.name = "HandAnchor"
		hand.position = Vector3(0, -arm_half * 2.0 - limb_r, 0)
		arm_root.add_child(hand)

	# --- Legs ---
	if "no_legs" not in feats:
		var leg_half: float = arch["leg_len"] * 0.5 * model_scale
		var hip_x: float = torso_scale.x * 0.25 * w * model_scale
		for side in [-1.0, 1.0]:
			var leg_root := Node3D.new()
			leg_root.name = "Leg_L" if side < 0 else "Leg_R"
			leg_root.position = Vector3(hip_x * side, torso_y - torso_scale.y * 0.5 * model_scale, 0)
			body.add_child(leg_root)
			var upper_leg := _make_limb(limb_r * 1.1, leg_half, skin_col)
			upper_leg.position = Vector3(0, -leg_half * 0.5, 0)
			leg_root.add_child(upper_leg)
			var lower_leg := _make_limb(limb_r * 0.9, leg_half, skin_col)
			lower_leg.position = Vector3(0, -leg_half * 1.5, 0)
			leg_root.add_child(lower_leg)
	else:
		# Floating/no-legs: base blob
		var blob_mi := _make_body_part("sphere",
			Vector3(torso_scale.x * 0.7 * w, 0.15, torso_scale.z * 0.7) * model_scale, skin_col)
		blob_mi.position = Vector3(0, 0.08 * model_scale, 0)
		body.add_child(blob_mi)

	# ── Features ────────────────────────────────────────────────────────────
	if "tail" in feats:
		_add_tail(body, torso_y, torso_scale, model_scale, skin_col)
	if "wings" in feats:
		_add_wings(body, shoulder_y, torso_scale, model_scale, skin_col)
	if "horns" in feats:
		_add_horns(head_node, head_scale, model_scale, skin_col)
	if "long_ears" in feats:
		_add_long_ears(head_node, head_scale, model_scale, skin_col)
	if "snout" in feats:
		_add_snout(head_node, head_scale, model_scale, skin_col)
	if "antenna" in feats:
		_add_antenna(head_node, head_scale, model_scale, eye_col)
	if "shell" in feats:
		_add_shell(torso_node, torso_scale, model_scale, skin_col)
	if "tendrils" in feats:
		_add_tendrils(body, torso_y, model_scale, skin_col)
	if "fins" in feats:
		_add_fins(body, torso_y, torso_scale, model_scale, skin_col)
	if "glow" in feats:
		_add_glow(body, torso_y, model_scale, eye_col)

	# ── Armor overlay ───────────────────────────────────────────────────────
	if armor_weight != "none":
		_add_armor_overlay(root, arch, armor_def, model_scale, w)

	# ── Shield ──────────────────────────────────────────────────────────────
	if shield_name != "None" and SHIELD_DEFS.has(shield_name):
		_add_shield(root, arch, SHIELD_DEFS[shield_name], model_scale)

	# ── Weapon ──────────────────────────────────────────────────────────────
	if weapon_name != "None" and WEAPON_DEFS.has(weapon_name):
		_add_weapon(root, arch, WEAPON_DEFS[weapon_name], model_scale)

	return root


# ═══════════════════════════════════════════════════════════════════════════════
#   SPRITE3D LINEAGE MODEL — billboard character art for dungeon
# ═══════════════════════════════════════════════════════════════════════════════

const SPRITE_PORTRAIT_BASE := "res://assets/characters_3d/"
const SPRITE_PORTRAIT_FALLBACK := "res://assets/characters_3d/regal_human.png"

## Build a Sprite3D billboard model from the lineage's transparent portrait.
## Returns a Node3D containing the billboard sprite, sized to fit a dungeon tile.
## Falls back to procedural model if no sprite portrait is found.
func build_sprite_model(lineage_name: String, weapon_name: String = "None",
		armor_name: String = "None", shield_name: String = "None",
		model_scale: float = 1.0, team_color: Color = Color.WHITE) -> Node3D:
	var tex: Texture2D = _load_sprite_portrait(lineage_name)
	if tex == null:
		# Fall back to procedural model if no sprite portrait exists
		return build_model(lineage_name, weapon_name, armor_name, shield_name, model_scale)

	var root := Node3D.new()
	root.name = "SpriteModel_%s" % lineage_name.replace(" ", "_").replace("'", "")

	# ── Sprite3D billboard ──────────────────────────────────────────────
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.double_sided = true
	sprite.no_depth_test = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS

	# Size the sprite to fit nicely on a tile (~0.9 units wide max)
	# The sprite's pixel_size converts pixels → world units
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())
	var desired_height: float = 0.95 * model_scale  # ~0.95 world units tall at scale 1
	sprite.pixel_size = desired_height / tex_h
	# Cap width so wide sprites don't overflow tiles
	var actual_w: float = tex_w * sprite.pixel_size
	if actual_w > 0.85 * model_scale:
		sprite.pixel_size = (0.85 * model_scale) / tex_w

	# Vertical offset: center the sprite so feet touch ground
	sprite.offset = Vector2(0, tex_h * 0.5)
	sprite.name = "LineageSprite"
	root.add_child(sprite)

	# ── Team colour rim light ───────────────────────────────────────────
	# A subtle coloured point light behind the sprite for team identification
	var rim_light := OmniLight3D.new()
	rim_light.light_color = team_color
	rim_light.light_energy = 0.5
	rim_light.omni_range = 0.6
	rim_light.omni_attenuation = 1.5
	rim_light.position = Vector3(0, desired_height * 0.5, -0.15)
	rim_light.name = "TeamRimLight"
	root.add_child(rim_light)

	return root


## Load the transparent sprite portrait for a lineage.
## Uses the same naming convention as regular portraits but from characters_3d/.
func _load_sprite_portrait(lineage_name: String) -> Texture2D:
	var key: String = lineage_name.to_lower().replace(" ", "_").replace("-", "_").replace("'", "")
	var path: String = SPRITE_PORTRAIT_BASE + key + ".png"

	# Path 1: Godot resource system
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res as Texture2D

	# Path 2: Raw file load via globalize_path (bypasses import system)
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null:
			return ImageTexture.create_from_image(img)

	# Path 3: Direct FileAccess on res:// path
	if FileAccess.file_exists(path):
		var img2 := Image.load_from_file(path)
		if img2 != null:
			return ImageTexture.create_from_image(img2)

	# Fallback: try the regular (non-transparent) portrait from characters/
	var orig_path: String = "res://assets/characters/" + key + ".png"
	var orig_abs: String = ProjectSettings.globalize_path(orig_path)
	if FileAccess.file_exists(orig_abs):
		var orig_img := Image.load_from_file(orig_abs)
		if orig_img != null:
			return ImageTexture.create_from_image(orig_img)
	if FileAccess.file_exists(orig_path):
		var orig_img2 := Image.load_from_file(orig_path)
		if orig_img2 != null:
			return ImageTexture.create_from_image(orig_img2)

	return null


## Convenience: build sprite model from a character handle.
func build_sprite_for_handle(handle: int, team_color: Color = Color.WHITE) -> Node3D:
	var e = RimvaleAPI.engine
	var lineage: String = e.get_character_lineage_name(handle)
	var cd = e.get_char_dict(handle)
	var weapon: String  = str(cd.get("weapon", "None"))
	var armor: String   = str(cd.get("armor",  "None"))
	var shield: String  = str(cd.get("shield", "None"))
	return build_sprite_model(lineage, weapon, armor, shield, 1.0, team_color)


## Convenience: build model from a character handle (reads lineage + equipment).
func build_model_for_handle(handle: int) -> Node3D:
	var e = RimvaleAPI.engine
	var lineage: String = e.get_character_lineage_name(handle)
	var cd = e.get_char_dict(handle)
	var weapon: String  = str(cd.get("weapon", "None"))
	var armor: String   = str(cd.get("armor",  "None"))
	var shield: String  = str(cd.get("shield", "None"))
	return build_model(lineage, weapon, armor, shield)


# ═══════════════════════════════════════════════════════════════════════════════
#   INTERNAL — MESH PRIMITIVES
# ═══════════════════════════════════════════════════════════════════════════════

func _mat(col: Color, metallic: float = 0.1, roughness: float = 0.6,
		emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = roughness
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


func _make_body_part(shape: String, scale: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match shape:
		"sphere":
			var s := SphereMesh.new()
			s.radius = scale.x; s.height = scale.y * 2.0
			mi.mesh = s
		"box":
			var b := BoxMesh.new()
			b.size = scale * 2.0
			mi.mesh = b
		"capsule":
			var c := CapsuleMesh.new()
			c.radius = scale.x; c.height = scale.y * 2.0
			mi.mesh = c
		_:
			var s2 := SphereMesh.new()
			s2.radius = scale.x; s2.height = scale.y * 2.0
			mi.mesh = s2
	mi.set_surface_override_material(0, _mat(col))
	return mi


func _make_limb(radius: float, length: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = length
	mi.mesh = c
	mi.set_surface_override_material(0, _mat(col))
	return mi


# ── Eye helpers ──────────────────────────────────────────────────────────────

func _add_eyes(head_node: Node3D, head_s: Vector3, eye_col: Color) -> void:
	var eye_r: float = head_s.x * 0.15
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = eye_r; sm.height = eye_r * 2.0
		eye.mesh = sm
		eye.set_surface_override_material(0, _mat(eye_col, 0.3, 0.3, eye_col, 0.8))
		eye.position = Vector3(head_s.x * 0.35 * side, head_s.y * 0.15, head_s.z * 0.75)
		head_node.add_child(eye)


# ── Feature helpers ──────────────────────────────────────────────────────────

func _add_tail(body: Node3D, torso_y: float, torso_s: Vector3, sc: float, col: Color) -> void:
	var tail := _make_limb(0.04 * sc, 0.50 * sc, col)
	tail.position = Vector3(0, torso_y - torso_s.y * 0.45 * sc, -torso_s.z * 0.5 * sc - 0.15 * sc)
	tail.rotation_degrees = Vector3(45, 0, 0)
	body.add_child(tail)

func _add_wings(body: Node3D, shoulder_y: float, torso_s: Vector3, sc: float, col: Color) -> void:
	var wing_col: Color = col.lerp(Color.WHITE, 0.2)
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45 * sc, 0.55 * sc, 0.03 * sc)
		wing.mesh = bm
		wing.set_surface_override_material(0, _mat(wing_col, 0.1, 0.5))
		wing.position = Vector3(torso_s.x * 0.4 * side * sc, shoulder_y + 0.1 * sc, -torso_s.z * 0.5 * sc)
		wing.rotation_degrees = Vector3(0, 0, -30.0 * side)
		body.add_child(wing)

func _add_horns(head: Node3D, hs: Vector3, sc: float, col: Color) -> void:
	var horn_col: Color = col.lerp(Color(0.85, 0.80, 0.70), 0.5)
	for side in [-1.0, 1.0]:
		var horn := _make_limb(0.03 * sc, 0.18 * sc, horn_col)
		horn.position = Vector3(hs.x * 0.6 * side * sc, hs.y * 0.7 * sc, 0)
		horn.rotation_degrees = Vector3(0, 0, -25.0 * side)
		head.add_child(horn)

func _add_long_ears(head: Node3D, hs: Vector3, sc: float, col: Color) -> void:
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02 * sc, 0.12 * sc, 0.06 * sc)
		ear.mesh = bm
		ear.set_surface_override_material(0, _mat(col))
		ear.position = Vector3(hs.x * 0.9 * side * sc, hs.y * 0.2 * sc, 0)
		ear.rotation_degrees = Vector3(0, 0, -35.0 * side)
		head.add_child(ear)

func _add_snout(head: Node3D, hs: Vector3, sc: float, col: Color) -> void:
	var snout := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.10 * sc, 0.08 * sc, 0.14 * sc)
	snout.mesh = bm
	snout.set_surface_override_material(0, _mat(col.lerp(Color(0.30, 0.22, 0.15), 0.3)))
	snout.position = Vector3(0, -hs.y * 0.15 * sc, hs.z * 0.85 * sc)
	head.add_child(snout)

func _add_antenna(head: Node3D, hs: Vector3, sc: float, col: Color) -> void:
	for side in [-1.0, 1.0]:
		var ant := _make_limb(0.015 * sc, 0.18 * sc, col)
		ant.position = Vector3(hs.x * 0.4 * side * sc, hs.y * 0.9 * sc, hs.z * 0.3 * sc)
		ant.rotation_degrees = Vector3(-20, 0, -15.0 * side)
		head.add_child(ant)

func _add_shell(torso: Node3D, ts: Vector3, sc: float, col: Color) -> void:
	var shell_col: Color = col.lerp(Color(0.40, 0.35, 0.25), 0.4)
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = ts.x * 1.15 * sc; sm.height = ts.y * 1.8 * sc
	shell.mesh = sm
	shell.set_surface_override_material(0, _mat(shell_col, 0.2, 0.55))
	shell.position = Vector3(0, 0, -ts.z * 0.3 * sc)
	torso.add_child(shell)

func _add_tendrils(body: Node3D, torso_y: float, sc: float, col: Color) -> void:
	var tendril_col: Color = col.lerp(Color(0.20, 0.45, 0.20), 0.4)
	for i in range(3):
		var t := _make_limb(0.02 * sc, 0.25 * sc, tendril_col)
		var angle: float = float(i) * 120.0
		t.position = Vector3(
			sin(deg_to_rad(angle)) * 0.15 * sc,
			torso_y - 0.30 * sc,
			cos(deg_to_rad(angle)) * 0.15 * sc)
		t.rotation_degrees = Vector3(randf_range(-20, 20), angle, randf_range(-15, 15))
		body.add_child(t)

func _add_fins(body: Node3D, torso_y: float, ts: Vector3, sc: float, col: Color) -> void:
	var fin_col: Color = col.lerp(Color(0.20, 0.60, 0.50), 0.3)
	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02 * sc, 0.20 * sc, 0.12 * sc)
		fin.mesh = bm
		fin.set_surface_override_material(0, _mat(fin_col, 0.2, 0.4))
		fin.position = Vector3(ts.x * 0.6 * side * sc, torso_y + 0.05 * sc, -ts.z * 0.2 * sc)
		fin.rotation_degrees = Vector3(0, 0, -20.0 * side)
		body.add_child(fin)

func _add_glow(body: Node3D, torso_y: float, sc: float, col: Color) -> void:
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 0.6
	light.omni_range = 1.5 * sc
	light.shadow_enabled = false
	light.position = Vector3(0, torso_y, 0)
	body.add_child(light)


# ═══════════════════════════════════════════════════════════════════════════════
#   ARMOR OVERLAY
# ═══════════════════════════════════════════════════════════════════════════════

func _add_armor_overlay(root: Node3D, arch: Dictionary, armor_def: Dictionary,
		sc: float, w: float) -> void:
	var armor_node := Node3D.new(); armor_node.name = "Armor"
	root.add_child(armor_node)

	var col: Color      = armor_def["color"]
	var metal: float    = armor_def["metallic"]
	var rough: float    = armor_def["roughness"]
	var weight: String  = armor_def["weight"]
	var ts: Vector3     = arch["torso_scale"]
	var leg_len: float  = arch["leg_len"]
	var torso_y: float  = (leg_len + ts.y * 0.5) * sc

	# Torso plate (all armor)
	var torso_pad: float = 0.02 if weight == "light" else 0.04 if weight == "medium" else 0.06
	var chest := MeshInstance3D.new()
	var chest_mesh: Mesh
	if weight == "heavy":
		var bm := BoxMesh.new()
		bm.size = Vector3((ts.x * w + torso_pad) * 2.0 * sc, ts.y * 1.8 * sc, (ts.z + torso_pad) * 2.0 * sc)
		chest_mesh = bm
	else:
		var cm := CapsuleMesh.new()
		cm.radius = (ts.x * w + torso_pad) * sc
		cm.height = ts.y * 1.85 * sc
		chest_mesh = cm
	chest.mesh = chest_mesh
	chest.set_surface_override_material(0, _mat(col, metal, rough))
	chest.position = Vector3(0, torso_y, 0)
	armor_node.add_child(chest)

	# Shoulder pads (medium, heavy)
	if weight == "medium" or weight == "heavy":
		var shoulder_y: float = torso_y + ts.y * 0.35 * sc
		var shoulder_x: float = ts.x * 0.5 * w * sc + arch["limb_radius"] * 1.5 * sc
		for side in [-1.0, 1.0]:
			var pad := MeshInstance3D.new()
			var pm := SphereMesh.new()
			pm.radius = (arch["limb_radius"] + 0.03) * sc
			pm.height = (arch["limb_radius"] + 0.03) * 2.0 * sc
			pad.mesh = pm
			pad.set_surface_override_material(0, _mat(col, metal, rough))
			pad.position = Vector3(shoulder_x * side, shoulder_y, 0)
			armor_node.add_child(pad)

	# Greaves (medium, heavy)
	if weight == "medium" or weight == "heavy":
		var lr: float = arch["limb_radius"]
		var leg_half: float = arch["leg_len"] * 0.5 * sc
		var hip_x: float = ts.x * 0.25 * w * sc
		for side in [-1.0, 1.0]:
			var greave := MeshInstance3D.new()
			var gm := CapsuleMesh.new()
			gm.radius = (lr * 1.1 + 0.02) * sc
			gm.height = leg_half * 0.9
			greave.mesh = gm
			greave.set_surface_override_material(0, _mat(col, metal, rough))
			greave.position = Vector3(hip_x * side, leg_half * 0.5, 0)
			armor_node.add_child(greave)

	# Helm (heavy only)
	if weight == "heavy":
		var hs: Vector3 = arch["head_scale"]
		var head_y: float = torso_y + ts.y * 0.5 * sc + hs.y * 0.5 * sc + 0.02 * sc
		var helm := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = (hs.x + 0.03) * sc
		hm.height = (hs.y + 0.03) * 2.0 * sc
		helm.mesh = hm
		helm.set_surface_override_material(0, _mat(col, metal, rough))
		helm.position = Vector3(0, head_y, 0)
		armor_node.add_child(helm)

		# Visor slit
		var visor := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(hs.x * 1.2 * sc, 0.03 * sc, 0.02 * sc)
		visor.mesh = vm
		visor.set_surface_override_material(0, _mat(Color(0.1, 0.1, 0.1), 0.0, 0.9))
		visor.position = Vector3(0, head_y + hs.y * 0.1 * sc, (hs.z + 0.04) * sc)
		armor_node.add_child(visor)


# ═══════════════════════════════════════════════════════════════════════════════
#   SHIELD
# ═══════════════════════════════════════════════════════════════════════════════

func _add_shield(root: Node3D, arch: Dictionary, shield_def: Dictionary, sc: float) -> void:
	# Attach to left arm hand anchor
	var body = root.get_node_or_null("Body")
	if body == null: return
	var arm_l = body.get_node_or_null("Arm_L")
	if arm_l == null: return
	var hand = arm_l.get_node_or_null("HandAnchor")
	if hand == null: return

	var shield := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var sz: Vector3 = shield_def["size"] * sc
	bm.size = sz
	shield.mesh = bm
	var col: Color = shield_def["color"]
	var metal: float = shield_def.get("metallic", 0.15)
	shield.set_surface_override_material(0, _mat(col, metal, 0.5))
	shield.position = Vector3(-0.08 * sc, 0.12 * sc, 0.10 * sc)
	hand.add_child(shield)


# ═══════════════════════════════════════════════════════════════════════════════
#   WEAPON MESH
# ═══════════════════════════════════════════════════════════════════════════════

func _add_weapon(root: Node3D, arch: Dictionary, weapon_def: Dictionary, sc: float) -> void:
	# Attach to right arm hand anchor
	var body = root.get_node_or_null("Body")
	if body == null: return
	var arm_r = body.get_node_or_null("Arm_R")
	if arm_r == null: return
	var hand = arm_r.get_node_or_null("HandAnchor")
	if hand == null: return

	var sz: Vector3   = weapon_def["size"] * sc
	var col: Color    = weapon_def["color"]
	var metal: float  = weapon_def.get("metallic", 0.5)
	var shape: String = weapon_def["shape"]

	var weapon_node := Node3D.new(); weapon_node.name = "Weapon"
	hand.add_child(weapon_node)

	match shape:
		"blade":
			# Handle
			var handle := _make_limb(sz.x * 0.4, sz.y * 0.25, Color(0.35, 0.25, 0.15))
			handle.position = Vector3(0, sz.y * 0.12, 0)
			weapon_node.add_child(handle)
			# Blade
			var blade := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(sz.x, sz.y * 0.75, sz.z)
			blade.mesh = bm
			blade.set_surface_override_material(0, _mat(col, metal, 0.25))
			blade.position = Vector3(0, sz.y * 0.62, 0)
			weapon_node.add_child(blade)
			# Cross-guard
			var guard := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(sz.x * 2.5, sz.y * 0.04, sz.z * 2.0)
			guard.mesh = gm
			guard.set_surface_override_material(0, _mat(col.lerp(Color.BLACK, 0.3), metal, 0.35))
			guard.position = Vector3(0, sz.y * 0.25, 0)
			weapon_node.add_child(guard)

		"axe":
			var handle := _make_limb(sz.x * 0.2, sz.y * 0.85, Color(0.40, 0.30, 0.18))
			handle.position = Vector3(0, sz.y * 0.42, 0)
			weapon_node.add_child(handle)
			var head := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(sz.x, sz.y * 0.22, sz.z)
			head.mesh = hm
			head.set_surface_override_material(0, _mat(col, metal, 0.30))
			head.position = Vector3(sz.x * 0.4, sz.y * 0.80, 0)
			weapon_node.add_child(head)

		"hammer":
			var handle := _make_limb(sz.x * 0.25, sz.y * 0.75, Color(0.40, 0.30, 0.18))
			handle.position = Vector3(0, sz.y * 0.37, 0)
			weapon_node.add_child(handle)
			var head := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(sz.x, sz.y * 0.18, sz.z)
			head.mesh = hm
			head.set_surface_override_material(0, _mat(col, metal, 0.35))
			head.position = Vector3(0, sz.y * 0.80, 0)
			weapon_node.add_child(head)

		"polearm":
			var shaft := _make_limb(sz.x * 0.5, sz.y * 0.85, Color(0.45, 0.35, 0.22))
			shaft.position = Vector3(0, sz.y * 0.42, 0)
			weapon_node.add_child(shaft)
			var tip := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(sz.x * 1.5, sz.y * 0.12, sz.z * 0.5)
			tip.mesh = tm
			tip.set_surface_override_material(0, _mat(col, metal, 0.25))
			tip.position = Vector3(0, sz.y * 0.92, 0)
			weapon_node.add_child(tip)

		"staff":
			var staff := _make_limb(sz.x * 0.6, sz.y, Color(0.45, 0.35, 0.22))
			staff.position = Vector3(0, sz.y * 0.5, 0)
			weapon_node.add_child(staff)
			var orb := MeshInstance3D.new()
			var om := SphereMesh.new()
			om.radius = sz.x * 1.5; om.height = sz.x * 3.0
			orb.mesh = om
			orb.set_surface_override_material(0, _mat(col.lerp(Color(0.40, 0.60, 0.90), 0.5), 0.3, 0.3,
				col.lerp(Color(0.40, 0.60, 0.90), 0.5), 0.5))
			orb.position = Vector3(0, sz.y + sz.x * 1.5, 0)
			weapon_node.add_child(orb)

		"dagger":
			var handle := _make_limb(sz.x * 0.6, sz.y * 0.35, Color(0.35, 0.25, 0.15))
			handle.position = Vector3(0, sz.y * 0.17, 0)
			weapon_node.add_child(handle)
			var blade := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(sz.x, sz.y * 0.65, sz.z)
			blade.mesh = bm
			blade.set_surface_override_material(0, _mat(col, metal, 0.25))
			blade.position = Vector3(0, sz.y * 0.67, 0)
			weapon_node.add_child(blade)

		"bow":
			# Arc shape approximated with thin box
			var limb := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(sz.x, sz.y, sz.z * 0.5)
			limb.mesh = bm
			limb.set_surface_override_material(0, _mat(col, 0.0, 0.6))
			limb.position = Vector3(0, sz.y * 0.5, 0)
			weapon_node.add_child(limb)
			# String
			var string := _make_limb(0.005 * sc, sz.y * 0.9, Color(0.60, 0.55, 0.45))
			string.position = Vector3(sz.z * 0.5, sz.y * 0.5, 0)
			weapon_node.add_child(string)

		"crossbow":
			# Stock
			var stock := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(sz.x * 0.3, sz.y * 0.7, sz.z)
			stock.mesh = sm
			stock.set_surface_override_material(0, _mat(col, 0.1, 0.6))
			stock.position = Vector3(0, sz.y * 0.35, 0)
			weapon_node.add_child(stock)
			# Prod (crossbar)
			var prod := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(sz.x, sz.y * 0.06, sz.z * 0.3)
			prod.mesh = pm
			prod.set_surface_override_material(0, _mat(col.lerp(Color(0.55, 0.50, 0.42), 0.5), 0.2, 0.5))
			prod.position = Vector3(0, sz.y * 0.70, 0)
			weapon_node.add_child(prod)

		"gun":
			var barrel := _make_limb(sz.x * 0.4, sz.y * 0.7, col)
			barrel.position = Vector3(0, sz.y * 0.55, 0)
			weapon_node.add_child(barrel)
			var grip := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(sz.x * 0.8, sz.y * 0.25, sz.z)
			grip.mesh = gm
			grip.set_surface_override_material(0, _mat(Color(0.35, 0.25, 0.15), 0.0, 0.7))
			grip.position = Vector3(0, sz.y * 0.12, 0)
			weapon_node.add_child(grip)

		"whip":
			var handle := _make_limb(sz.x * 0.8, sz.y * 0.2, Color(0.35, 0.25, 0.15))
			handle.position = Vector3(0, sz.y * 0.1, 0)
			weapon_node.add_child(handle)
			var lash := _make_limb(sz.x * 0.3, sz.y * 0.8, col)
			lash.position = Vector3(0.05 * sc, sz.y * 0.6, 0)
			lash.rotation_degrees = Vector3(0, 0, 15)
			weapon_node.add_child(lash)

		_:  # fist / unknown
			var fist := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.05 * sc; fm.height = 0.10 * sc
			fist.mesh = fm
			fist.set_surface_override_material(0, _mat(col, 0.1, 0.5))
			weapon_node.add_child(fist)
