## game_state.gd
## Global game state — autoloaded as "GameState".
## Mirrors the mobile app's player state, team, collection, and economy.

extends Node

# ── Player / Summoner ─────────────────────────────────────────────────────────
var player_name: String = "Agent"
var player_level: int = 1
var player_xp: int = 0
var player_xp_required: int = 1000
var player_rank: String = "Recruit"

# ── Economy ───────────────────────────────────────────────────────────────────
var gold: int = 500
var tokens: int = 5
var remnant_fragments: int = 0

const TOKENS_PER_RF_TRADE: int = 100   # 100 RF → 10 tokens
const RF_TO_TOKENS_RATE: int = 10

# ── Team ──────────────────────────────────────────────────────────────────────
const ACTIVE_TEAM_SIZE: int = 5

## Active strike team — array of int handles (or -1 for empty slot)
var active_team: Array = [-1, -1, -1, -1, -1]

## Full character collection — all owned character handles
var collection: Array = []

## Handles currently busy with crafting / foraging tasks
var busy_handles: Array = []

# ── Director ──────────────────────────────────────────────────────────────────
var director_message: String = "Welcome back, Agent. Your units await orders."

# ── Navigation ────────────────────────────────────────────────────────────────
var current_tab: int = 0   # 0=Units 1=World 2=Shop 3=Codex 4=Profile

# ── Crafting / Foraging ───────────────────────────────────────────────────────
class CraftingTask:
	var character_handle: int = -1
	var character_name: String = ""
	var item_type: String = ""
	var end_time: float = 0.0  # OS.get_unix_time() + duration

class ForageTask:
	var character_handle: int = -1
	var character_name: String = ""
	var forage_type: String = ""  # Hunting / Fishing / Mining / Gathering
	var end_time: float = 0.0
	var gold_reward: int = 0

var crafting_tasks: Array = []
var forage_tasks: Array = []

# ── Rituals ───────────────────────────────────────────────────────────────────
var active_rituals: Array = []

# ── Rest tracking ─────────────────────────────────────────────────────────────
var short_rests_used: int = 0
const MAX_SHORT_RESTS: int = 3

# ── Player stash (shared item storage) ───────────────────────────────────────
var stash: Array = []   # Array of item name Strings

func add_to_stash(item_name: String) -> void:
	if item_name not in stash:
		stash.append(item_name)

func remove_from_stash(item_name: String) -> void:
	stash.erase(item_name)

# ── Selected hero (for level-up / inventory screens) ─────────────────────────
var selected_hero_handle: int = -1

# ── ─────────────────────────────────────────────────────────────────────────
# Team helpers
# ── ─────────────────────────────────────────────────────────────────────────

func add_to_collection(handle: int) -> void:
	if handle not in collection:
		collection.append(handle)

func remove_from_collection(handle: int) -> void:
	collection.erase(handle)
	# Also remove from active team
	for i in range(ACTIVE_TEAM_SIZE):
		if active_team[i] == handle:
			active_team[i] = -1

func set_team_slot(slot: int, handle: int) -> void:
	if slot >= 0 and slot < ACTIVE_TEAM_SIZE:
		active_team[slot] = handle

func clear_team_slot(slot: int) -> void:
	if slot >= 0 and slot < ACTIVE_TEAM_SIZE:
		active_team[slot] = -1

func get_active_handles() -> Array:
	var result: Array = []
	for h in active_team:
		if h != -1:
			result.append(h)
	return result

func is_in_active_team(handle: int) -> bool:
	return handle in active_team

func is_busy(handle: int) -> bool:
	return handle in busy_handles

func set_busy(handle: int, busy: bool) -> void:
	if busy and handle not in busy_handles:
		busy_handles.append(handle)
	elif not busy:
		busy_handles.erase(handle)

func collection_has_any() -> bool:
	return collection.size() > 0

# ── Economy helpers ──────────────────────────────────────────────────────────

func can_trade_rf_for_tokens() -> bool:
	return remnant_fragments >= TOKENS_PER_RF_TRADE

func trade_rf_for_tokens() -> bool:
	if not can_trade_rf_for_tokens():
		return false
	remnant_fragments -= TOKENS_PER_RF_TRADE
	tokens += RF_TO_TOKENS_RATE
	return true

func spend_tokens(amount: int) -> bool:
	if tokens < amount:
		return false
	tokens -= amount
	return true

func earn_gold(amount: int) -> void:
	gold += amount

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true

# ── Rest helpers ──────────────────────────────────────────────────────────────

func can_short_rest() -> bool:
	return short_rests_used < MAX_SHORT_RESTS

func do_short_rest() -> bool:
	if not can_short_rest():
		return false
	short_rests_used += 1
	var e: RimvaleEngine = RimvaleAPI.engine
	var active := get_active_handles()
	if active.size() > 0:
		e.rest_party(active)
	return true

func do_long_rest() -> void:
	short_rests_used = 0
	var e: RimvaleEngine = RimvaleAPI.engine
	for h in collection:
		e.long_rest(h)

# ── Wipe ─────────────────────────────────────────────────────────────────────

func wipe_all() -> void:
	var e: RimvaleEngine = RimvaleAPI.engine
	for h in collection:
		e.destroy_character(h)
	collection.clear()
	active_team = [-1, -1, -1, -1, -1]
	busy_handles.clear()
	crafting_tasks.clear()
	forage_tasks.clear()
	active_rituals.clear()
	gold = 500
	tokens = 5
	remnant_fragments = 0
	player_level = 1
	player_xp = 0
	short_rests_used = 0
	stash.clear()
	selected_hero_handle = -1
