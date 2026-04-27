## creature_size.gd
## Canonical creature-size → tile-footprint rules.
##
## COMPRESSED LADDER (game-grid tuned; 25×25 dungeons):
## Literal spec math is compromised — a spec-scale Colossal would be 16×16
## tiles, which on our 25×25 arena would eat 64 % of the map and can't even
## spawn in the designated zone. Instead we shrink the ladder so a Colossal
## Kaiju "fills the middle" but leaves real maneuvering room:
##
##   Tiny       = 1 × 1  (1 tile — Tiny creatures may share a tile)
##   Small      = 1 × 1  (1 tile)
##   Medium     = 1 × 1  (1 tile)
##   Large      = 1 × 2  (2 tiles — rectangle)
##   Huge       = 2 × 2  (4 tiles)
##   Gargantuan = 3 × 3  (9 tiles)
##   Colossal   = 4 × 4  (16 tiles) ← Kaiju default
##
## Edge-length progression: 1 → 1 → 1 → 2 → 2 → 3 → 4.
## Reach is set to the footprint edge × 5 ft so Colossal Kaiju get a 20 ft
## melee reach (vs. the 80 ft pen-and-paper value). All mechanical rules
## (multi-target, area-scaling, threshold, LR uses, HP/AP/SP formulas) still
## follow the spec — only the grid footprint + reach are compressed.
class_name CreatureSize
extends RefCounted

# ══════════════════════════════════════════════════════════════════════════════
# SIZE TIER CATALOG — COMPRESSED
# ══════════════════════════════════════════════════════════════════════════════
## Ordered ascending. `spaces` = total tile count (= width × height).
## `width_tiles` × `height_tiles` = rectangular footprint.
## `reach_ft` = longest edge × 5 ft (so Medium = 5 ft, Colossal = 20 ft).
## `height_ft_min`/`_max` — used by tier_for_height_ft() fallback.
const SIZES: Array = [
	{"id": "tiny",       "name": "Tiny",       "spaces":  1, "width_tiles": 1, "height_tiles": 1, "reach_ft":  5, "height_ft_min":  1, "height_ft_max":  2, "shares_tile": true},
	{"id": "small",      "name": "Small",      "spaces":  1, "width_tiles": 1, "height_tiles": 1, "reach_ft":  5, "height_ft_min":  2, "height_ft_max":  4, "shares_tile": false},
	{"id": "medium",     "name": "Medium",     "spaces":  1, "width_tiles": 1, "height_tiles": 1, "reach_ft":  5, "height_ft_min":  4, "height_ft_max":  8, "shares_tile": false},
	{"id": "large",      "name": "Large",      "spaces":  2, "width_tiles": 1, "height_tiles": 2, "reach_ft": 10, "height_ft_min":  8, "height_ft_max": 16, "shares_tile": false},
	{"id": "huge",       "name": "Huge",       "spaces":  4, "width_tiles": 2, "height_tiles": 2, "reach_ft": 10, "height_ft_min": 16, "height_ft_max": 30, "shares_tile": false},
	{"id": "gargantuan", "name": "Gargantuan", "spaces":  9, "width_tiles": 3, "height_tiles": 3, "reach_ft": 15, "height_ft_min": 30, "height_ft_max": 50, "shares_tile": false},
	{"id": "colossal",   "name": "Colossal",   "spaces": 16, "width_tiles": 4, "height_tiles": 4, "reach_ft": 20, "height_ft_min": 50, "height_ft_max": 500, "shares_tile": false},
]

# ══════════════════════════════════════════════════════════════════════════════
# QUERIES
# ══════════════════════════════════════════════════════════════════════════════

## Look up a size entry by name (case-insensitive) or id.
## Returns an empty dict if unknown.
static func get_size(name_or_id: String) -> Dictionary:
	var key: String = name_or_id.strip_edges().to_lower()
	for s in SIZES:
		if str(s["id"]).to_lower() == key or str(s["name"]).to_lower() == key:
			return s
	return {}

## Tile count (e.g., Huge → 4, Colossal → 16). Returns 1 if the size is unknown.
static func footprint_tiles(name_or_id: String) -> int:
	var s: Dictionary = get_size(name_or_id)
	if s.is_empty():
		return 1
	return int(s["spaces"])

## Best-fit rectangular footprint as Vector2i(width, height).
## Colossal → (4, 4). Gargantuan → (2, 4). Huge → (2, 2). Large → (1, 2).
static func footprint_dimensions(name_or_id: String) -> Vector2i:
	var s: Dictionary = get_size(name_or_id)
	if s.is_empty():
		return Vector2i(1, 1)
	return Vector2i(int(s["width_tiles"]), int(s["height_tiles"]))

## The ordered index of this tier in SIZES (0 = Tiny, 6 = Colossal). -1 if unknown.
static func tier_index(name_or_id: String) -> int:
	var key: String = name_or_id.strip_edges().to_lower()
	for i in range(SIZES.size()):
		if str(SIZES[i]["id"]).to_lower() == key or str(SIZES[i]["name"]).to_lower() == key:
			return i
	return -1

## Melee reach (in feet) for this size tier. Medium → 5, Large → 10, Huge → 15, etc.
static func reach_ft(name_or_id: String) -> int:
	var s: Dictionary = get_size(name_or_id)
	if s.is_empty():
		return 5
	return int(s["reach_ft"])

## Pick the smallest size tier that covers `height_ft` (e.g. 60 ft → Colossal).
static func tier_for_height_ft(height_ft: int) -> Dictionary:
	for s in SIZES:
		if height_ft >= int(s["height_ft_min"]) and height_ft <= int(s["height_ft_max"]):
			return s
	# Taller than Colossal's stated max → still Colossal.
	return SIZES[SIZES.size() - 1]

## Returns every tile a creature occupies given an origin (its front-left anchor).
## `origin` is the top-left tile of the footprint; returns all tiles within the
## width×height rectangle. Useful for collision, rendering, and
## attack-targeting.
static func footprint_tiles_at(name_or_id: String, origin: Vector2i) -> Array:
	var dim: Vector2i = footprint_dimensions(name_or_id)
	var out: Array = []
	for dy in range(dim.y):
		for dx in range(dim.x):
			out.append(Vector2i(origin.x + dx, origin.y + dy))
	return out

## Movement-cost multiplier — bigger creatures push through terrain faster (no
## penalty here, but Colossal creatures ignore difficult terrain below their
## own tile-height per the Kaiju spec).
static func ignores_difficult_terrain(name_or_id: String) -> bool:
	return tier_index(name_or_id) >= tier_index("colossal")

## Pretty one-line footprint label, e.g. "Colossal (4×4, 16 tiles)".
static func pretty(name_or_id: String) -> String:
	var s: Dictionary = get_size(name_or_id)
	if s.is_empty():
		return "Unknown"
	return "%s (%d×%d, %d tiles)" % [
		str(s["name"]), int(s["width_tiles"]), int(s["height_tiles"]), int(s["spaces"])]
