## vehicle_data.gd
## Specialty arcane vehicles from the GMG. These are NOT magic-attunement items
## — they're owned by the party and tracked in GameState.owned_vehicles. Each
## vehicle has a Spark Tank pool that drains over time and is refilled with SP
## (cost varies by location: cheap inside the Metropolitan, expensive outside).
##
## Autoload as `VehicleData`.
##
## Each entry:
##   { rarity, type, capacity, speed_paved, speed_unpaved, turn_45, turn_90,
##     st_max, sp_refill_in_metro, sp_refill_outside, hp, special }
##
## `type` is one of:
##   "land"   — wheeled / driving (paved/unpaved speeds)
##   "water"  — boats (open/rough water in the speed fields)
##   "air"    — flying (paved=cruise, unpaved=combat speed; turn_* still tiles)
##   "submarine" — underwater (paved=submerged, unpaved=surfaced)
##   "void"   — zero-G / astral (paved=zero-G, unpaved=low-grav)
##   "mecha"  — Aegis Ultima (also a Kaiju entity in combat)

extends Node

const ALL_VEHICLES: Dictionary = {
	"Arcane Motorcycle": {
		"rarity": "Uncommon", "type": "land",
		"capacity": 1, "speed_paved": 75, "speed_unpaved": 40,
		"turn_45": 15, "turn_90": 30,
		"st_max": 1, "sp_refill_in_metro": 3, "sp_refill_outside": 6,
		"hp": 75,
		"special": "Evasive Surge: spend 1 tank for +4 AC until next turn, ignore opportunity attacks during movement.",
	},
	"Arcane Quad": {
		"rarity": "Rare", "type": "land",
		"capacity": 2, "speed_paved": 50, "speed_unpaved": 35,
		"turn_45": 20, "turn_90": 40,
		"st_max": 2, "sp_refill_in_metro": 5, "sp_refill_outside": 10,
		"hp": 90,
		"special": "Stabilizer Field: spend 1 tank to negate difficult terrain and prevent prone for 1 round.",
	},
	"Arcane Sedan": {
		"rarity": "Uncommon", "type": "land",
		"capacity": 4, "speed_paved": 60, "speed_unpaved": 20,
		"turn_45": 60, "turn_90": 120,
		"st_max": 3, "sp_refill_in_metro": 4, "sp_refill_outside": 8,
		"hp": 100,
		"special": "Force Field: spend 1 tank for +2 AC to all occupants for 1 round.",
	},
	"Arcane Rover": {
		"rarity": "Rare", "type": "land",
		"capacity": 6, "speed_paved": 45, "speed_unpaved": 30,
		"turn_45": 30, "turn_90": 60,
		"st_max": 5, "sp_refill_in_metro": 6, "sp_refill_outside": 12,
		"hp": 150,
		"special": "All-Terrain Mode: spend 1 tank to ignore difficult terrain for 10 minutes.",
	},
	"Arcane Juggernaut": {
		"rarity": "Legendary", "type": "land",
		"capacity": 8, "speed_paved": 30, "speed_unpaved": 20,
		"turn_45": 45, "turn_90": 90,
		"st_max": 15, "sp_refill_in_metro": 15, "sp_refill_outside": 30,
		"hp": 300,
		"special": "Armor Plating (resist non-magical piercing/slashing). Mounted Arcane Cannon (4d10 force, 300 ft, 2 ST/shot). Disruption Blast (4 ST, 20 ft AoE, VIT save 12+DIV or stunned). Bulwark Mode (10 ST, 30 ft dome +4 AC for 3 rounds). Reinforced Hull (advantage on save vs immobilise).",
	},
	"Arcane Copter": {
		"rarity": "Very Rare", "type": "air",
		"capacity": 2, "speed_paved": 30, "speed_unpaved": 30,
		"turn_45": 30, "turn_90": 60,
		"st_max": 10, "sp_refill_in_metro": 10, "sp_refill_outside": 20,
		"hp": 50,
		"special": "Emergency Hover: spend 5 ST as a reaction to prevent forced movement / falling for 1 round. Each 6 minutes of flight = 1 ST.",
	},
	"Arcane Skimmer": {
		"rarity": "Uncommon", "type": "water",
		"capacity": 1, "speed_paved": 60, "speed_unpaved": 30,
		"turn_45": 15, "turn_90": 30,
		"st_max": 2, "sp_refill_in_metro": 3, "sp_refill_outside": 6,
		"hp": 60,
		"special": "Wave Cutter Mode: spend 1 tank to ignore wave penalties and gain +2 to Speed saves for 1 round.",
	},
	"Arcane Catamaran": {
		"rarity": "Rare", "type": "water",
		"capacity": 4, "speed_paved": 40, "speed_unpaved": 25,
		"turn_45": 30, "turn_90": 60,
		"st_max": 3, "sp_refill_in_metro": 5, "sp_refill_outside": 10,
		"hp": 120,
		"special": "Buoyancy Field: spend 1 tank to prevent capsizing and gain resistance to environmental damage for 10 minutes.",
	},
	"Arcane Barge": {
		"rarity": "Very Rare", "type": "water",
		"capacity": 12, "speed_paved": 25, "speed_unpaved": 15,
		"turn_45": 60, "turn_90": 120,
		"st_max": 10, "sp_refill_in_metro": 10, "sp_refill_outside": 20,
		"hp": 250,
		"special": "Hull Shielding (resist non-magical damage, prevents aquatic-monster breaches). Arcane Crane lifts heavy cargo as a basic action. 10-ton cargo hold.",
	},
	"Arcane Diver": {
		"rarity": "Very Rare", "type": "submarine",
		"capacity": 4, "speed_paved": 20, "speed_unpaved": 30,
		"turn_45": 30, "turn_90": 60,
		"st_max": 8, "sp_refill_in_metro": 8, "sp_refill_outside": 16,
		"hp": 180,
		"special": "Void Hull (immune to pressure damage, resist necrotic/cold while submerged). Emergency Breach Protocol: spend 1 tank as a reaction to teleport to nearest surface or leyline anchor (1/long rest).",
	},
	"Arcane Drifter": {
		"rarity": "Very Rare", "type": "void",
		"capacity": 6, "speed_paved": 40, "speed_unpaved": 20,
		"turn_45": 0, "turn_90": 30,    # instant pivot in zero-G
		"st_max": 3, "sp_refill_in_metro": 6, "sp_refill_outside": 12,
		"hp": 100,
		"special": "Inertia Dampeners (no collision damage, instant directional change). Void Thrusters: 500 ft burst movement (1 tank). Dimensional Stabilizer: resist dimensional distortion, anchor to coordinates for 1 hour (1 tank). Cannot fly in normal gravity — hovers 5 ft, 30 ft hover speed.",
	},
	"Aegis Ultima": {
		"rarity": "Legendary", "type": "mecha",
		"capacity": 2, "speed_paved": 15, "speed_unpaved": 15,
		"turn_45": 60, "turn_90": 120,
		"st_max": 15, "sp_refill_in_metro": 2, "sp_refill_outside": 10,
		"hp": 138,
		"special": "Two-pilot mecha (Gunner + Controller). Arcane Baton 6d6 force / paralyse. Arcane Cannon 8d10 force, 150/300 ft, 2 ST/shot. Disruption Blast 4 ST, 20 ft AoE stun (DC 18 VIT). Force Field 2 ST, +4 AC to allies in 30 ft. Bulwark Mode 5 ST, 30 ft dome +4 AC for 3 rounds. Ash Protocol 2 ST, smoke + morale check. Teleport 1 ST, 300 ft. Damage threshold 13. Resist non-magical phys, piercing, slashing, thunder, radiant. Immune force, paralysis, charm. See kaiju entry for full combat stat block.",
	},
}

## Returns vehicle stat dict for `name`, or {} if unknown.
func get_stats(name: String) -> Dictionary:
	return ALL_VEHICLES.get(name, {})

## All vehicle names sorted by rarity (Common→Legendary) then alphabetically.
func all_names_by_rarity() -> Array:
	var rarity_order: Dictionary = {
		"Common": 0, "Uncommon": 1, "Rare": 2,
		"Very Rare": 3, "Legendary": 4
	}
	var names: Array = ALL_VEHICLES.keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = rarity_order.get(ALL_VEHICLES[a].get("rarity", ""), 99)
		var rb: int = rarity_order.get(ALL_VEHICLES[b].get("rarity", ""), 99)
		if ra != rb: return ra < rb
		return a < b
	)
	return names

## Filter vehicles by terrain compatibility. `terrain` is "land", "water",
## "air", "submarine", "void", or "any".
func vehicles_for_terrain(terrain: String) -> Array:
	if terrain == "any": return all_names_by_rarity()
	var out: Array = []
	for name in all_names_by_rarity():
		var t: String = str(ALL_VEHICLES[name].get("type", ""))
		if t == terrain or (terrain == "land" and t == "mecha"):
			out.append(name)
	return out
