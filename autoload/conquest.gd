## conquest.gd
## Region Conquest — the Battle Mode meta-campaign. Win a skirmish to claim a
## region; the difficulty escalates as your holdings grow; conquer all 10 for
## the triumph screen. Progress persists to its OWN save file and NEVER touches
## the story save system in game_state.gd.
##
## Registered as autoload `Conquest`. The world-map scene (conquest_map.gd)
## reads `owned` to paint the grid and calls `begin_attempt(rid)` to launch a
## battle; battle_rts._show_over reads `pending_region` and calls `claim(rid)`
## on a player victory.
extends Node

const SAVE_PATH := "user://conquest.save"

## Regions the player holds (gold on the map). Order = the order they fell.
var owned: Array[String] = []
## region_id -> number of times attacked (wins + losses), for flavor.
var attempts: Dictionary = {}
## Set by the map right before start_battle; read in battle_rts._show_over.
## "" means "this is an ordinary skirmish, not a conquest battle".
var pending_region: String = ""


func _ready() -> void:
	_load()


# ── Queries ──────────────────────────────────────────────────────────────────

## All region ids in the campaign — the 10 REGION_CONFIG keys.
func all_regions() -> Array:
	return BattleSystem.get_region_ids()

func is_owned(rid: String) -> bool:
	return owned.has(rid)

func owned_count() -> int:
	return owned.size()

func total_count() -> int:
	return all_regions().size()

## True once every region is held — triggers the victory lap.
func is_complete() -> bool:
	return total_count() > 0 and owned_count() >= total_count()

## Difficulty ramp keyed on how many regions you already hold. Returns the
## args for BattleSystem.start_battle (minus region + heroes), plus a `tag`
## label for the map's escalation preview.
##   0-2 held → easy,   3 teams, level 2, medium resources
##   3-5 held → medium, 4 teams, level 4, medium resources
##   6-8 held → hard,   5 teams, level 6, low resources
##   9   held → hard,   6 teams, level 8, low resources ("the last stand")
func settings_for_next() -> Dictionary:
	var n: int = owned_count()
	if n <= 2:
		return {"teams": 3, "level": 2, "difficulty": "easy",
			"resources": "medium", "tag": "Skirmish"}
	elif n <= 5:
		return {"teams": 4, "level": 4, "difficulty": "medium",
			"resources": "medium", "tag": "Campaign"}
	elif n <= 8:
		return {"teams": 5, "level": 6, "difficulty": "hard",
			"resources": "low", "tag": "War"}
	else:
		return {"teams": 6, "level": 8, "difficulty": "hard",
			"resources": "low", "tag": "The Last Stand"}


# ── Actions ──────────────────────────────────────────────────────────────────

## Launch a conquest battle for `rid`. Fog is always on; no heroes by default
## (the map is a pure meta-loop). Returns false if the region is unknown or
## already held. The caller changes scene to battle_rts on true.
func begin_attempt(rid: String, heroes: Array = []) -> bool:
	if not all_regions().has(rid) or is_owned(rid):
		return false
	var s: Dictionary = settings_for_next()
	pending_region = rid
	attempts[rid] = int(attempts.get(rid, 0)) + 1
	_save()
	BattleSystem.fog_enabled = true
	BattleSystem.start_battle(rid, int(s["teams"]), int(s["level"]),
		str(s["difficulty"]), str(s["resources"]), heroes)
	return true

## Record a victory: add the region to `owned`, clear the pending flag, persist.
func claim(rid: String) -> void:
	if rid != "" and not owned.has(rid):
		owned.append(rid)
	pending_region = ""
	_save()

## Clear the pending flag without claiming (a loss, or leaving mid-battle).
func abandon() -> void:
	pending_region = ""

## Wipe all campaign progress (used by a "reset" option / new campaign).
func reset_campaign() -> void:
	owned.clear()
	attempts.clear()
	pending_region = ""
	_save()


# ── Persistence (own file — never the story save) ────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("conquest", "owned", owned)
	cfg.set_value("conquest", "attempts", attempts)
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	owned.clear()
	for r in cfg.get_value("conquest", "owned", []):
		owned.append(str(r))
	var a = cfg.get_value("conquest", "attempts", {})
	if a is Dictionary:
		attempts = a
