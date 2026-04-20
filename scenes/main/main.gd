## main.gd
## Root scene — 5-tab top navigation shell.
## Content area loads each tab's scene on demand.

extends Control

const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const NAV_HEIGHT = 72
const TAB_SCENES = [
	"res://scenes/team/team.tscn",
	"res://scenes/world/world.tscn",
	"res://scenes/shop/shop.tscn",
	"res://scenes/codex/codex.tscn",
	"res://scenes/profile/profile.tscn",
]
const TAB_LABELS = ["⚔ Units", "🌍 World", "🛒 Shop", "📖 Codex", "👤 Profile"]

var _content_area: Control
var _tab_buttons: Array = []
var _current_scene: Node = null
var _current_scene_path: String = ""
var _nav_bar: Control
var _screen_stack: Array = []   # stack of pushed screen paths for pop_screen()

# Screens that hide the nav bar (full-screen takeover)
var _hide_nav_scenes = [
	"res://scenes/level_up/level_up.tscn",
	"res://scenes/inventory/inventory.tscn",
	"res://scenes/combat/combat.tscn",
	"res://scenes/character_creation/character_creation.tscn",
	"res://scenes/dungeon/dungeon.tscn",
	"res://scenes/explore/explore.tscn",
]

# ── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Safety net: if launched directly from editor (not via title screen),
	# make sure the game state is initialised.
	GameState.ensure_init()

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, RimvaleColors.BG_DARK)

	# Top nav bar
	_nav_bar = _build_nav_bar()
	add_child(_nav_bar)

	# Content area (fills everything below top nav)
	_content_area = Control.new()
	_content_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.offset_top = NAV_HEIGHT
	add_child(_content_area)

	# Load first tab
	_switch_tab(GameState.current_tab)

# ── Nav bar ───────────────────────────────────────────────────────────────────

func _build_nav_bar() -> Control:
	var bar = Control.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, NAV_HEIGHT)
	bar.offset_bottom = NAV_HEIGHT

	var bg = ColorRect.new()
	bg.color = RimvaleColors.BG_NAV
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)

	# Bottom border line
	var line = ColorRect.new()
	line.color = RimvaleColors.DIVIDER
	line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	line.custom_minimum_size = Vector2(0, 1)
	bar.add_child(line)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	bar.add_child(hbox)

	for i in range(TAB_LABELS.size()):
		var btn = _make_tab_button(TAB_LABELS[i], i)
		_tab_buttons.append(btn)
		hbox.add_child(btn)

	return bar

func _make_tab_button(label_txt: String, idx: int) -> Button:
	var btn = Button.new()
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
	_screen_stack.clear()
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
	_current_scene_path = path
	_current_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.add_child(_current_scene)

	# Show/hide nav bar
	var hide_nav: bool = path in _hide_nav_scenes
	_nav_bar.visible = not hide_nav

# ── Public API (called by child scenes to navigate) ──────────────────────────

## Navigate to a named full-screen overlay (hides nav bar).
func push_screen(path: String) -> void:
	# Remember what screen we came from so pop_screen can return to it
	if _current_scene_path != "":
		_screen_stack.append(_current_scene_path)
	_load_scene(path)

## Return to the previous screen (or current tab if stack is empty).
func pop_screen() -> void:
	if _screen_stack.size() > 0:
		var prev: String = _screen_stack.pop_back()
		_load_scene(prev)
	else:
		_load_scene(TAB_SCENES[GameState.current_tab])
		_nav_bar.visible = true

## Navigate directly to a specific scene, clearing the screen stack.
func go_to_scene(path: String) -> void:
	_screen_stack.clear()
	_load_scene(path)

## Switch to a specific tab by index.
func go_to_tab(idx: int) -> void:
	_switch_tab(idx)

## Save and return to the title / main menu screen.
func exit_to_title() -> void:
	GameState.save_game()
	GameState.reset_loaded_flag()
	get_tree().change_scene_to_file(TITLE_SCENE)
