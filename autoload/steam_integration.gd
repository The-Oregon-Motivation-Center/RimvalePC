## steam_integration.gd
## Steamworks integration layer with a graceful-fallback design.
##
## When the GodotSteam plugin is installed, all calls forward to the native
## Steam class. When it isn't (development without the plugin, or running
## standalone outside Steam), every call becomes a no-op that logs to the
## console — so the rest of the codebase can call `SteamIntegration.unlock(...)`
## from anywhere without conditional checks.
##
## Autoloaded as `SteamIntegration`. Reads SteamAppId from a file or
## defaults to 480 (Spacewar) for local testing.
##
## Setup steps (one-time, per platform):
##   1. Download GodotSteam Plugin from https://github.com/CoaguCo-Industries/GodotSteam
##      — pick the build that matches your Godot version (4.6).
##   2. Drop the `addons/godotsteam/` folder into res://addons/.
##   3. Place steam_api64.dll next to Rimvale.exe (Windows).
##   4. Create a `steam_appid.txt` next to the exe containing your App ID.
##   5. The next time the game starts, `Steam` will appear as a registered
##      class and this script will switch to live mode automatically.
##
## Reference: https://godotsteam.com/

extends Node

signal achievement_unlocked(id: String)
signal stats_received()

# ── Lifecycle state ───────────────────────────────────────────────────────────
var _is_available: bool = false
var _is_running: bool = false   # true when Steam client is detected on launch
var _app_id: int = 480           # Spacewar — replace with your assigned app id

## Returns true iff the GodotSteam plugin is loaded AND the Steam client is
## running. Other systems should check this before relying on Steam-specific
## behaviour (cloud saves, friends, rich presence).
func is_available() -> bool:
	return _is_available and _is_running


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_available = ClassDB.class_exists("Steam")
	if not _is_available:
		print("[Steam] GodotSteam not detected — running in stub mode.")
		return

	# Live mode — call the plugin only via dynamic dispatch so this file
	# still parses when the plugin isn't installed.
	var steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if steam == null:
		print("[Steam] GodotSteam class exists but singleton missing.")
		_is_available = false
		return

	var init_result = steam.call("steamInit")
	# steamInit returns a dict in modern GodotSteam:
	# {"status": int, "verbal": String}
	if init_result is Dictionary:
		var status: int = int((init_result as Dictionary).get("status", -1))
		if status == 1:
			_is_running = true
			print("[Steam] Initialized OK — App ID %d" % _app_id)
		else:
			var verbal: String = str((init_result as Dictionary).get("verbal", "unknown"))
			print("[Steam] Init failed: %s" % verbal)
	elif typeof(init_result) == TYPE_BOOL and bool(init_result):
		_is_running = true
		print("[Steam] Initialized OK (legacy bool API).")

	if _is_running:
		# Wire common signals.
		if steam.has_signal("current_stats_received"):
			steam.connect("current_stats_received", Callable(self, "_on_stats_received"))
		steam.call("requestCurrentStats")


func _process(_delta: float) -> void:
	if not is_available():
		return
	var steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if steam != null:
		steam.call("runCallbacks")


# ─────────────────────────────────────────────────────────────────────────────
# Achievements (data-driven via AchievementRegistry below)
# ─────────────────────────────────────────────────────────────────────────────
func unlock(achievement_id: String) -> void:
	# Already unlocked — skip so repeat triggers (every kill, every codex view)
	# don't re-fire Steam calls or spam save_game().
	if GameState.has_method("has_achievement") and GameState.has_achievement(achievement_id):
		return
	# Cache the unlock locally so the game can show its own celebration UI
	# even when Steam isn't running.
	if not GameState.has_method("mark_achievement_unlocked"):
		# Stub-only mode: just log.
		print("[Steam] (stub) unlock %s" % achievement_id)
		return
	GameState.mark_achievement_unlocked(achievement_id)
	emit_signal("achievement_unlocked", achievement_id)

	if not is_available():
		print("[Steam] (offline) unlock %s" % achievement_id)
		return
	var steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if steam == null:
		return
	steam.call("setAchievement", achievement_id)
	steam.call("storeStats")
	print("[Steam] unlocked %s" % achievement_id)


func set_stat_int(stat_id: String, value: int) -> void:
	if not is_available():
		return
	var steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if steam == null:
		return
	steam.call("setStatInt", stat_id, value)
	steam.call("storeStats")


func set_stat_float(stat_id: String, value: float) -> void:
	if not is_available():
		return
	var steam = Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
	if steam == null:
		return
	steam.call("setStatFloat", stat_id, value)
	steam.call("storeStats")


func _on_stats_received(_app_id_received: int, _result: int, _user_id: int) -> void:
	emit_signal("stats_received")


# ─────────────────────────────────────────────────────────────────────────────
# Achievement registry — friendly metadata for the in-game celebration UI.
# Steam-side achievements must be defined in the Steamworks partner site with
# matching API names; this dict is the single source of truth for what we
# trigger and how we describe it locally.
# ─────────────────────────────────────────────────────────────────────────────
const REGISTRY: Dictionary = {
	# ── Progression ─────────────────────────────────────────────────────────
	"first_blood": {
		"title": "First Blood",
		"desc":  "Defeat your first enemy in combat.",
	},
	"agent": {
		"title": "Agent",
		"desc":  "Reach Player Level 3.",
	},
	"specialist": {
		"title": "Specialist",
		"desc":  "Reach Player Level 5.",
	},
	"veteran": {
		"title": "Veteran",
		"desc":  "Reach Player Level 9.",
	},
	"elite": {
		"title": "Elite",
		"desc":  "Reach Player Level 12.",
	},
	"master": {
		"title": "Master",
		"desc":  "Reach Player Level 16.",
	},
	"grandmaster": {
		"title": "Grandmaster",
		"desc":  "Reach the maximum Player Level (20).",
	},
	# ── Regions ─────────────────────────────────────────────────────────────
	"explorer_plains":   { "title": "Plains Wanderer",   "desc": "Explore Verdant Plains."},
	"explorer_peaks":    { "title": "Peak Climber",      "desc": "Explore the Argent Peaks."},
	"explorer_shadows":  { "title": "Shadow Walker",     "desc": "Explore the Shadow Reaches."},
	"explorer_glass":    { "title": "Glass Strider",     "desc": "Explore the Glass Wastes."},
	"explorer_isles":    { "title": "Isle Hopper",       "desc": "Explore the Cerulean Isles."},
	"explorer_titans":   { "title": "Titan-Slayer",      "desc": "Explore the Land of Titans."},
	"explorer_astral":   { "title": "Star-Touched",      "desc": "Explore the Astral Verge."},
	"explorer_terminus": { "title": "Terminus Pilgrim",  "desc": "Explore Terminus Volarus."},
	"explorer_sublimini":{ "title": "The Deep Below",    "desc": "Explore Sublimini."},
	"explorer_metro":    { "title": "City Slicker",      "desc": "Explore the Metropolitan."},
	# ── Collection / mastery ────────────────────────────────────────────────
	"mythic_collector": {
		"title": "Mythic Collector",
		"desc":  "Attune a Legendary-tier magic item.",
	},
	"motor_pool": {
		"title": "Motor Pool",
		"desc":  "Acquire your first arcane vehicle.",
	},
	"feat_master": {
		"title": "Feat Master",
		"desc":  "Earn 10 feats across your party.",
	},
	"loremaster": {
		"title": "Loremaster",
		"desc":  "View 50 codex entries.",
	},
	"cemetery_visit": {
		"title": "Memento Mori",
		"desc":  "Revive a fallen ally from the cemetery.",
	},
	# ── Story ───────────────────────────────────────────────────────────────
	"badge_first": {
		"title": "First Badge",
		"desc":  "Complete your first regional story chapter.",
	},
	"badge_nine": {
		"title": "Nine Banners",
		"desc":  "Earn all nine regional badges.",
	},
}


func describe(achievement_id: String) -> Dictionary:
	return REGISTRY.get(achievement_id, {"title": achievement_id, "desc": ""})


# ─────────────────────────────────────────────────────────────────────────────
# Convenience triggers — called from game systems at natural points
# ─────────────────────────────────────────────────────────────────────────────
## Call from game_state.check_level_up() when a level threshold crosses.
func on_player_level(level: int) -> void:
	match level:
		3:  unlock("agent")
		5:  unlock("specialist")
		9:  unlock("veteran")
		12: unlock("elite")
		16: unlock("master")
		20: unlock("grandmaster")


func on_region_entered(region_id: String) -> void:
	var key := "explorer_" + str(region_id).to_lower()
	if REGISTRY.has(key):
		unlock(key)


func on_enemy_killed() -> void:
	unlock("first_blood")


func on_vehicle_acquired() -> void:
	unlock("motor_pool")


func on_mythic_equipped() -> void:
	unlock("mythic_collector")


func on_story_badge_earned(badge_count: int) -> void:
	if badge_count >= 1:
		unlock("badge_first")
	if badge_count >= 9:
		unlock("badge_nine")


func on_revive_from_cemetery() -> void:
	unlock("cemetery_visit")


## Call after a feat purchase with the party-wide total feat count.
func on_feat_unlocked(total_party_feats: int) -> void:
	if total_party_feats >= 10:
		unlock("feat_master")


## Call when a codex detail entry is opened, with the running unique count.
func on_codex_viewed(unique_entries_viewed: int) -> void:
	if unique_entries_viewed >= 50:
		unlock("loremaster")
