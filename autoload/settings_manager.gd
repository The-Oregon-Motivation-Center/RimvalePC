## settings_manager.gd
## Persistent user preferences (audio, display, gameplay, accessibility).
## Reads / writes user://settings.cfg via ConfigFile. Applies values on load
## and any time a setter is called.
##
## Autoloaded as `Settings` (see project.godot).
## Other systems just read `Settings.combat_speed`, `Settings.reduce_motion`,
## etc., or connect to the `setting_changed(key)` signal.

extends Node

signal setting_changed(key: String)
signal all_applied()

const PATH := "user://settings.cfg"

# ── Defaults ──────────────────────────────────────────────────────────────────
const DEF := {
	# Audio (0..1 linear)
	"audio_master": 0.85,
	"audio_music":  0.65,
	"audio_sfx":    0.85,
	"audio_ui":     0.75,

	# Display
	"display_fullscreen": false,
	"display_vsync":      true,
	"display_resolution": "1920x1080",   # ignored in fullscreen
	"display_render_2d":  false,         # DEBUG: top-down orthographic "2D" mode

	# Gameplay
	"combat_speed":      1.0,   # 0.5 .. 2.0 multiplier on animation tweens
	"autosave_freq":     3,     # in-game days between autosaves; 0 = off
	"verbose_tooltips":  true,
	"verbose_battle_log": true,

	# Accessibility
	"text_scale":    1.0,       # 0.85 .. 1.5
	"colorblind":    "off",     # off | protan | deutan | tritan
	"reduce_motion": false,
}

# Live values (start as defaults, overwritten by load).
var _values: Dictionary = DEF.duplicate(true)


# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_from_disk()
	# Defer the first apply by a frame so other autoloads (AudioManager, etc.)
	# have completed _ready() and added their AudioStreamPlayers.
	call_deferred("apply_all")


# ─────────────────────────────────────────────────────────────────────────────
# Get / set
# ─────────────────────────────────────────────────────────────────────────────
func get_value(key: String, fallback = null):
	return _values.get(key, DEF.get(key, fallback))


func set_value(key: String, value, save: bool = true) -> void:
	if not DEF.has(key):
		push_warning("SettingsManager: unknown key '%s'" % key)
		return
	_values[key] = value
	_apply_one(key)
	emit_signal("setting_changed", key)
	if save:
		save_to_disk()


# Convenience typed accessors (the common ones — saves callers writing
# get_value() everywhere with a default).
func audio_master() -> float:    return float(_values.audio_master)
func audio_music() -> float:     return float(_values.audio_music)
func audio_sfx() -> float:       return float(_values.audio_sfx)
func audio_ui() -> float:        return float(_values.audio_ui)
func combat_speed() -> float:    return float(_values.combat_speed)
func autosave_freq() -> int:     return int(_values.autosave_freq)
func verbose_tooltips() -> bool: return bool(_values.verbose_tooltips)
func verbose_battle_log() -> bool: return bool(_values.verbose_battle_log)
func text_scale() -> float:      return float(_values.text_scale)
func colorblind() -> String:     return str(_values.colorblind)
func reduce_motion() -> bool:    return bool(_values.reduce_motion)
func render_2d() -> bool:        return bool(_values.display_render_2d)


# ─────────────────────────────────────────────────────────────────────────────
# Persistence
# ─────────────────────────────────────────────────────────────────────────────
func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK:
		# First run — write the defaults so the file exists.
		save_to_disk()
		return
	for k in DEF.keys():
		var key_str: String = str(k)
		var section: String = _section_for(key_str)
		var leaf: String = key_str
		if key_str.length() > section.length():
			leaf = key_str.substr(section.length() + 1)
		# We store as section/leaf, but the dict key is the full id.
		if cfg.has_section_key(section, leaf):
			_values[key_str] = cfg.get_value(section, leaf, DEF[key_str])


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	for k in _values.keys():
		var key_str: String = str(k)
		var section: String = _section_for(key_str)
		var leaf: String = key_str
		if key_str.length() > section.length():
			leaf = key_str.substr(section.length() + 1)
		cfg.set_value(section, leaf, _values[key_str])
	cfg.save(PATH)


func reset_to_defaults(save: bool = true) -> void:
	_values = DEF.duplicate(true)
	apply_all()
	if save:
		save_to_disk()


# Helper: prefix before first underscore is the section name.
func _section_for(key: String) -> String:
	var i := key.find("_")
	return key.substr(0, i) if i > 0 else key


# ─────────────────────────────────────────────────────────────────────────────
# Apply: push values into the engine / subsystems
# ─────────────────────────────────────────────────────────────────────────────
func apply_all() -> void:
	for k in _values.keys():
		_apply_one(k)
	emit_signal("all_applied")


func _apply_one(key: String) -> void:
	match key:
		"audio_master":
			if typeof(AudioManager) != TYPE_NIL:
				AudioManager.set_master_volume(audio_master())
		"audio_music":
			if typeof(AudioManager) != TYPE_NIL:
				AudioManager.set_music_volume(audio_music())
		"audio_sfx":
			if typeof(AudioManager) != TYPE_NIL:
				AudioManager.set_sfx_volume(audio_sfx())
		"audio_ui":
			if typeof(AudioManager) != TYPE_NIL:
				AudioManager.set_ui_volume(audio_ui())

		"display_fullscreen":
			var on: bool = bool(_values.display_fullscreen)
			if on:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

		"display_vsync":
			var v: bool = bool(_values.display_vsync)
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if v else DisplayServer.VSYNC_DISABLED)

		"display_resolution":
			# Only apply in windowed mode (fullscreen tracks the display).
			if not bool(_values.display_fullscreen):
				var parts := str(_values.display_resolution).split("x")
				if parts.size() == 2:
					var w := int(parts[0])
					var h := int(parts[1])
					if w > 0 and h > 0:
						DisplayServer.window_set_size(Vector2i(w, h))

		"combat_speed":
			Engine.set_meta("combat_speed", combat_speed())

		"autosave_freq":
			Engine.set_meta("autosave_freq", autosave_freq())

		"text_scale":
			# Update the project's default theme font sizes — apply at root.
			Engine.set_meta("text_scale", text_scale())
			_apply_text_scale_to_tree()

		"colorblind":
			Engine.set_meta("colorblind", colorblind())

		"reduce_motion":
			Engine.set_meta("reduce_motion", reduce_motion())

		"verbose_tooltips":
			Engine.set_meta("verbose_tooltips", verbose_tooltips())

		"verbose_battle_log":
			Engine.set_meta("verbose_battle_log", verbose_battle_log())


func _apply_text_scale_to_tree() -> void:
	# Lightweight: set a CanvasLayer transform isn't great. Instead we walk
	# the active Control tree and apply font-size overrides to root themes.
	var t := Engine.get_main_loop() as SceneTree
	if t == null or t.root == null:
		return
	var s := text_scale()
	# Push the scale into the theme defaults if a custom theme is set.
	var theme: Theme = t.root.theme
	if theme != null:
		# We don't want to permanently mutate the user's theme; only stash the
		# scale and let UI code read it via Engine.get_meta("text_scale").
		pass


# ─────────────────────────────────────────────────────────────────────────────
# Resolution helpers (for the settings UI dropdown)
# ────────────────────────────────────────────────────────────────�