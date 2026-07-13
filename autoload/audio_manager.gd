## audio_manager.gd
## Central audio orchestration: music playback (with crossfade),
## SFX and UI playback (multi-channel pool), and a named catalog so callers
## can `AudioManager.play_sfx("attack_hit")` without worrying about file paths.
##
## Registered as autoload in project.godot. Free Kenney audio packs live
## under res://audio/ (ui/, sfx/footstep, sfx/impact, sfx/rpg, music/jingles,
## music/tracks). All CC0 — see res://audio/credits/.

extends Node

# ── Audio bus indices ─────────────────────────────────────────────────────────
const BUS_MASTER := 0
const BUS_MUSIC  := 1
const BUS_SFX    := 2
const BUS_UI     := 3

# ── Channel pools ─────────────────────────────────────────────────────────────
const SFX_VOICES := 8        # concurrent SFX
const UI_VOICES  := 4        # concurrent UI clicks
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _ui_cursor := 0

# ── Music players (two, for crossfade) ────────────────────────────────────────
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer = null
var _current_music_id: String = ""
var _music_target_db: float = 0.0
var _music_paused: bool = false   # NEW: tracks pause-due-to-loss-of-focus etc.

# ── Stream cache + catalog ────────────────────────────────────────────────────
var _stream_cache: Dictionary = {}       # path -> AudioStream
var _catalog: Dictionary = {}            # id -> Array[path]   (one or more files)
var _initialized: bool = false


# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	# SFX pool
	for i in range(SFX_VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	# UI pool
	for i in range(UI_VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_ui_players.append(p)

	# Music: two players that we crossfade between.
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	_music_a.volume_db = -80
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	_music_b.volume_db = -80
	add_child(_music_b)

	_build_catalog()


# ─────────────────────────────────────────────────────────────────────────────
# Catalog construction — maps friendly id → list of candidate file paths.
# play_sfx("attack_hit") picks one at random from its list.
# ─────────────────────────────────────────────────────────────────────────────
func _build_catalog() -> void:
	# ── UI ────────────────────────────────────────────────────────────────────
	_catalog["ui_click"]    = _ls("res://audio/ui/click*.ogg")
	_catalog["ui_press"]    = _ls("res://audio/ui/mouseclick*.ogg")
	_catalog["ui_release"]  = _ls("res://audio/ui/mouserelease*.ogg")
	_catalog["ui_hover"]    = _ls("res://audio/ui/rollover*.ogg")
	_catalog["ui_switch"]   = _ls("res://audio/ui/switch*.ogg")
	_catalog["ui_tab"]      = _ls("res://audio/ui/switch3.ogg")
	_catalog["ui_back"]     = _ls("res://audio/ui/switch7.ogg")
	_catalog["ui_open"]     = _ls("res://audio/sfx/rpg/bookOpen.ogg")
	_catalog["ui_close"]    = _ls("res://audio/sfx/rpg/bookClose.ogg")
	_catalog["ui_page"]     = _ls("res://audio/sfx/rpg/bookFlip*.ogg")

	# ── Footsteps ─────────────────────────────────────────────────────────────
	_catalog["footstep"]          = _ls("res://audio/sfx/footstep/footstep_grass_*.ogg")
	_catalog["footstep_grass"]    = _ls("res://audio/sfx/footstep/footstep_grass_*.ogg")
	_catalog["footstep_stone"]    = _ls("res://audio/sfx/footstep/footstep_concrete_*.ogg")
	_catalog["footstep_wood"]     = _ls("res://audio/sfx/footstep/footstep_wood_*.ogg")
	_catalog["footstep_snow"]     = _ls("res://audio/sfx/footstep/footstep_snow_*.ogg")
	_catalog["footstep_carpet"]   = _ls("res://audio/sfx/footstep/footstep_carpet_*.ogg")

	# ── Combat ───────────────────────────────────────────────────────────────
	# Slashing
	_catalog["attack_slash"]    = _ls("res://audio/sfx/rpg/knifeSlice*.ogg")
	# Piercing — drawKnife has a sharper "thrust" sound
	_catalog["attack_pierce"]   = _ls("res://audio/sfx/rpg/drawKnife*.ogg")
	# Bludgeoning — heavy metal/plate impact
	_catalog["attack_bludgeon"] = _ls("res://audio/sfx/impact/impactPlate_heavy_*.ogg")
	# Unarmed
	_catalog["attack_punch"]    = _ls("res://audio/sfx/impact/impactPunch_*.ogg")
	# Generic attack fallback
	_catalog["attack"]          = _ls("res://audio/sfx/impact/impactGeneric_light_*.ogg")
	# Critical hit — bell heavy is dramatic
	_catalog["attack_crit"]     = _ls("res://audio/sfx/impact/impactBell_heavy_*.ogg")
	# Miss — soft impact
	_catalog["attack_miss"]     = _ls("res://audio/sfx/impact/impactSoft_medium_*.ogg")
	# Block / parry — metal
	_catalog["block"]           = _ls("res://audio/sfx/impact/impactMetal_medium_*.ogg")
	# Generic hit / damage taken
	_catalog["hit_light"]       = _ls("res://audio/sfx/impact/impactSoft_medium_*.ogg")
	_catalog["hit_heavy"]       = _ls("res://audio/sfx/impact/impactPunch_heavy_*.ogg")
	# Death — heavy plate fall
	_catalog["death"]           = _ls("res://audio/sfx/impact/impactPlank_medium_*.ogg")

	# ── Spell / ability ──────────────────────────────────────────────────────
	# Generic spell cast (chimes)
	_catalog["spell_cast"]      = _ls("res://audio/sfx/impact/impactBell_heavy_*.ogg")
	# Fire
	_catalog["spell_fire"]      = _ls("res://audio/sfx/impact/impactMining_*.ogg")
	# Ice — glass shatter
	_catalog["spell_ice"]       = _ls("res://audio/sfx/impact/impactGlass_heavy_*.ogg")
	# Lightning — metal heavy
	_catalog["spell_lightning"] = _ls("res://audio/sfx/impact/impactMetal_heavy_*.ogg")
	# Heal — soft chime (use light bell)
	_catalog["spell_heal"]      = _ls("res://audio/sfx/impact/impactBell_heavy_002.ogg")

	# ── Inventory / economy ──────────────────────────────────────────────────
	_catalog["coin"]            = _ls("res://audio/sfx/rpg/handleCoins*.ogg")
	_catalog["equip"]           = _ls("res://audio/sfx/rpg/metalClick.ogg")
	_catalog["equip_armor"]     = _ls("res://audio/sfx/rpg/cloth*.ogg")
	_catalog["equip_weapon"]    = _ls("res://audio/sfx/rpg/drawKnife*.ogg")
	_catalog["unequip"]         = _ls("res://audio/sfx/rpg/metalLatch.ogg")
	_catalog["potion"]          = _ls("res://audio/sfx/rpg/handleSmallLeather*.ogg")

	# ── Environment ──────────────────────────────────────────────────────────
	_catalog["door_open"]       = _ls("res://audio/sfx/rpg/doorOpen_*.ogg")
	_catalog["door_close"]      = _ls("res://audio/sfx/rpg/doorClose_*.ogg")
	_catalog["chest_open"]      = _ls("res://audio/sfx/rpg/creak*.ogg")
	_catalog["chop"]            = _ls("res://audio/sfx/rpg/chop.ogg")

	# ── Jingles (one-shots over music bus) ───────────────────────────────────
	_catalog["jingle_victory"]  = _ls("res://audio/music/jingles/jingles_PIZZI04.ogg")
	_catalog["jingle_defeat"]   = _ls("res://audio/music/jingles/jingles_HIT09.ogg")
	_catalog["jingle_levelup"]  = _ls("res://audio/music/jingles/jingles_PIZZI07.ogg")
	_catalog["jingle_quest"]    = _ls("res://audio/music/jingles/jingles_NES03.ogg")
	_catalog["jingle_discover"] = _ls("res://audio/music/jingles/jingles_PIZZI02.ogg")

	# ── Music tracks (long) ──────────────────────────────────────────────────
	# Title / menus — Sax tracks have a cinematic feel
	_catalog["music_title"]     = _ls("res://audio/music/tracks/jingles_SAX01.ogg")
	_catalog["music_menu"]      = _ls("res://audio/music/tracks/jingles_SAX01.ogg")

	# Region maps — pizzicato strings feel exploratory
	_catalog["music_region"]    = _ls("res://audio/music/jingles/jingles_PIZZI01.ogg")
	_catalog["music_region_metro"]   = _ls("res://audio/music/tracks/jingles_SAX03.ogg")
	_catalog["music_region_plains"]  = _ls("res://audio/music/tracks/jingles_SAX05.ogg")
	_catalog["music_region_peaks"]   = _ls("res://audio/music/tracks/jingles_STEEL02.ogg")
	_catalog["music_region_shadows"] = _ls("res://audio/music/tracks/jingles_SAX08.ogg")
	_catalog["music_region_glass"]   = _ls("res://audio/music/tracks/jingles_STEEL05.ogg")
	_catalog["music_region_isles"]   = _ls("res://audio/music/tracks/jingles_SAX10.ogg")
	_catalog["music_region_titans"]  = _ls("res://audio/music/tracks/jingles_STEEL08.ogg")
	_catalog["music_region_astral"]  = _ls("res://audio/music/tracks/jingles_SAX12.ogg")
	_catalog["music_region_terminus"]  = _ls("res://audio/music/tracks/jingles_STEEL11.ogg")
	_catalog["music_region_sublimini"] = _ls("res://audio/music/tracks/jingles_STEEL14.ogg")

	# Combat — punchier Steel tracks
	_catalog["music_combat"]    = _ls("res://audio/music/tracks/jingles_STEEL01.ogg")
	_catalog["music_combat_boss"] = _ls("res://audio/music/tracks/jingles_STEEL07.ogg")

	# Dungeon — moodier Sax
	_catalog["music_dungeon"]   = _ls("res://audio/music/tracks/jingles_SAX14.ogg")
	_catalog["music_dungeon_crawl"] = _ls("res://audio/music/tracks/jingles_SAX09.ogg")

	# Hub / city — lighter pizzicato
	_catalog["music_hub"]       = _ls("res://audio/music/jingles/jingles_PIZZI13.ogg")
	# Cemetery / sombre — slow steel
	_catalog["music_cemetery"]  = _ls("res://audio/music/tracks/jingles_STEEL00.ogg")


# Listing helper: takes a glob-style "res://x/y/z_*.ogg" and returns a list of
# actual files that exist. (Godot doesn't have a native glob — we scan the dir.)
func _ls(pattern: String) -> Array:
	# Single file? Just check existence.
	if not pattern.contains("*"):
		if ResourceLoader.exists(pattern):
			return [pattern]
		return []

	# Glob: parse "res://dir/prefix*.ogg" or "res://dir/prefix_*.ogg"
	var dir_end := pattern.rfind("/")
	if dir_end < 0:
		return []
	var dir_path := pattern.substr(0, dir_end)
	var file_pat := pattern.substr(dir_end + 1)
	var star := file_pat.find("*")
	var prefix := file_pat.substr(0, star)
	var suffix := file_pat.substr(star + 1)

	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	while true:
		var fn := d.get_next()
		if fn == "":
			break
		if fn.begins_with(".") or d.current_is_dir():
			continue
		if fn.begins_with(prefix) and fn.ends_with(suffix):
			out.append(dir_path + "/" + fn)
	d.list_dir_end()
	out.sort()
	return out


func _get_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	_stream_cache[path] = s
	return s


func _pick(id: String) -> AudioStream:
	if not _catalog.has(id):
		return null
	var arr: Array = _catalog[id]
	if arr.is_empty():
		return null
	var pick: String = arr[randi() % arr.size()]
	return _get_stream(pick)


# ─────────────────────────────────────────────────────────────────────────────
# Public API — SFX / UI
# ─────────────────────────────────────────────────────────────────────────────
func play_sfx(id: String, pitch_var: float = 0.0, vol_db: float = 0.0) -> void:
	var s := _pick(id)
	if s == null:
		return
	var p := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % SFX_VOICES
	p.stream = s
	p.pitch_scale = 1.0 + (randf() - 0.5) * 2.0 * pitch_var
	p.volume_db = vol_db
	p.play()


func play_ui(id: String, vol_db: float = 0.0) -> void:
	var s := _pick(id)
	if s == null:
		return
	var p := _ui_players[_ui_cursor]
	_ui_cursor = (_ui_cursor + 1) % UI_VOICES
	p.stream = s
	p.pitch_scale = 1.0
	p.volume_db = vol_db
	p.play()


# Convenience — used by button factories.
func click() -> void: play_ui("ui_click")
func hover() -> void: play_ui("ui_hover", -6.0)
func switch() -> void: play_ui("ui_switch")
func tab() -> void: play_ui("ui_tab")
func back() -> void: play_ui("ui_back")
func open_panel() -> void: play_ui("ui_open", -3.0)
func close_panel() -> void: play_ui("ui_close", -3.0)


# ─────────────────────────────────────────────────────────────────────────────
# Public API — Music with crossfade
# ─────────────────────────────────────────────────────────────────────────────
func play_music(id: String, fade_seconds: float = 1.5, loop: bool = true) -> void:
	if id == _current_music_id:
		return    # same track already playing
	var s := _pick(id)
	if s == null:
		# Stop everything if no such track.
		stop_music(fade_seconds)
		return

	# Try to enable looping on the stream resource itself if it supports it.
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = loop
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop \
			else AudioStreamWAV.LOOP_DISABLED

	# Pick the *other* player to fade in.
	var fade_in: AudioStreamPlayer = _music_b if _music_active == _music_a else _music_a
	var fade_out: AudioStreamPlayer = _music_active

	fade_in.stream = s
	fade_in.volume_db = -80.0
	fade_in.play()

	# Tween fade
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(fade_in, "volume_db", _music_target_db, fade_seconds)
	if fade_out != null and fade_out.playing:
		t.tween_property(fade_out, "volume_db", -80.0, fade_seconds)
		t.chain().tween_callback(Callable(fade_out, "stop"))

	_music_active = fade_in
	_current_music_id = id


func stop_music(fade_seconds: float = 0.8) -> void:
	if _music_active == null or not _music_active.playing:
		_current_music_id = ""
		return
	var p := _music_active
	var t := create_tween()
	t.tween_property(p, "volume_db", -80.0, fade_seconds)
	t.tween_callback(Callable(p, "stop"))
	_current_music_id = ""


func current_music() -> String:
	return _current_music_id


# ─────────────────────────────────────────────────────────────────────────────
# Bus volume helpers — used by SettingsManager
# ─────────────────────────────────────────────────────────────────────────────
# Settings UI works in 0..1 linear; convert to dB.
func set_master_volume(linear: float) -> void:
	_set_bus_linear(BUS_MASTER, linear)


func set_music_volume(linear: float) -> void:
	_set_bus_linear(BUS_MUSIC, linear)


func set_sfx_volume(linear: float) -> void:
	_set_bus_linear(BUS_SFX, linear)


func set_ui_volume(linear: float) -> void:
	_set_bus_linear(BUS_UI, linear)


func get_master_volume() -> float: return _bus_linear(BUS_MASTER)
func get_music_volume() -> float:  return _bus_linear(BUS_MUSIC)
func get_sfx_volume() -> float:    return _bus_linear(BUS_SFX)
func get_ui_volume() -> float:     return _bus_linear(BUS_UI)


func _set_bus_linear(bus: int, lin: float) -> void:
	lin = clampf(lin, 0.0, 1.0)
	if bus < 0 or bus >= AudioServer.bus_count:
		return
	if lin <= 0.0001:
		AudioServer.set_bus_mute(bus, true)
		AudioServer.set_bus_volume_db(bus, -80.0)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(lin))


func _bus_linear(bus: int) -> float:
	if bus < 0 or bus >= AudioServer.bus_count:
		return 0.0
	if AudioServer.is_bus_mute(bus):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.0, 1.0)


# ─────────────────────────────────────────────────────────────────────────────
# Diagnostics
# ─────────────────────────────────────────────────────────────────────────────
func catalog_summary() -> Dictionary:
	var out := {}
	for k in _catalog.keys():
		out[k] = (_catalog[k] as Array).size()
	return out
