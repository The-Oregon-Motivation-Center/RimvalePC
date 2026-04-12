## main.gd
## Root scene — 5-tab bottom navigation shell.
## Content area loads each tab's scene on demand.

extends Control

const NAV_HEIGHT := 72
const TAB_SCENES := [
	"res://scenes/team/team.tscn",
	"res://scenes/world/world.tscn",
	"res://scenes/shop/shop.tscn",
	"res://scenes/codex/codex.tscn",
	"res://scenes/profile/profile.tscn",
]
const TAB_LABELS := ["⚔ Units", "🌍 World", "🛒 Shop", "📖 Codex", "👤 Profile"]

var _content_area: Control
var _tab_buttons: Array = []
var _current_scene: Node = null
var _nav_bar: Control

# Screens that hide the nav bar (full-screen takeover)
var _hide_nav_scenes := [
	"res://scenes/level_up/level_up.tscn",
	"res://scenes/inventory/inventory.tscn",
	"res://scenes/combat/combat.tscn",
	"res://scenes/character_creation/character_creation.tscn",
]

# ── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	# Content area (fills everything except bottom nav)
	_content_area = Control.new()
	_content_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.offset_bottom = -NAV_HEIGHT
	add_child(_content_area)

	# Bottom nav bar
	_nav_bar = _build_nav_bar()
	add_child(_nav_bar)

	# Load first tab
	_switch_tab(GameState.current_tab)

# ── Nav bar ───────────────────────────────────────────────────────────────────

func _build_nav_bar() -> Control:
	var bar := Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0, NAV_HEIGHT)
	bar.offset_top = -NAV_HEIGHT

	var bg := ColorRect.new()
	bg.color = RimvaleColors.BG_NAV
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)

	# Top border line
	var line := ColorRect.new()
	line.color = RimvaleColors.DIVIDER
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.custom_minimum_size = Vector2(0, 1)
	bar.add_child(line)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	bar.add_child(hbox)

	for i in range(TAB_LABELS.size()):
		var btn := _make_tab_button(TAB_LABELS[i], i)
		_tab_buttons.append(btn)
		hbox.add_child(btn)

	return bar

func _make_tab_button(label_txt: String, idx: int) -> Button:
	var btn := Button.new()
	btn.text = label_txt
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)
	btn.add_theme_color_override("font_pressed_color", RimvaleColors.ACCENT)
	btn.add_theme_color_override("font_hover_color", RimvaleColors.TEXT_LIGHT)
	btn.pressed.connect(func(): _switch_tab(idx))
	return btn

func _update_tab_highlight() -> void:
	for i in range(_tab_buttons.size()):
		var btn: Button = _tab_buttons[i]
		if i == GameState.current_tab:
			btn.add_theme_color_override("font_color", RimvaleColors.ACCENT)
		else:
			btn.add_theme_color_override("font_color", RimvaleColors.TEXT_GRAY)

# ── Tab switching ─────────────────────────────────────────────────────────────

func _switch_tab(idx: int) -> void:
	GameState.current_tab = idx
	_update_tab_highlight()
	_load_scene(TAB_SCENES[idx])

func _load_scene(path: String) -> void:
	# Free old scene
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null

	var packed: PackedScene = load(path)
	if not packed:
		push_error("Main: could not load scene: " + path)
		return

	_current_scene = packed.instantiate()
	_current_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.add_child(_current_scene)

	# Show/hide nav bar
	var hide := path in _hide_nav_scenes
	_nav_bar.visible = !hide

# ── Public API (called by child scenes to navigate) ──────────────────────────

## Navigate to a named full-screen overlay (hides nav bar).
func push_screen(path: String) -> void:
	_load_scene(path)

## Return to current tab.
func pop_screen() -> void:
	_load_scene(TAB_SCENES[GameState.current_tab])
	_nav_bar.visible = true

## Switch to a specific tab by index.
func go_to_tab(idx: int) -> void:
	_switch_tab(idx)
