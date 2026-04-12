## main_menu.gd
## Title screen — entry point of the game.

extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ── Dark background ─────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Centered column ─────────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(520, 0)
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "RIMVALE"
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Tactical RPG"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.65, 0.65, 0.60, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	_spacer(vbox, 50)

	# Buttons
	var new_btn := _make_btn("NEW GAME", Color(0.95, 0.80, 0.30, 1.0))
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var quit_btn := _make_btn("QUIT", Color(0.65, 0.65, 0.65, 1.0))
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)

	# Version label bottom-right
	var ver := Label.new()
	ver.text = "v2.0 — PC Alpha"
	ver.add_theme_font_size_override("font_size", 14)
	ver.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1.0))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position -= Vector2(220, 40)
	add_child(ver)

# ── Helpers ─────────────────────────────────────────────────────────────────

func _make_btn(txt: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(0, 68)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", col)
	return btn

func _spacer(parent: Node, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

# ── Navigation ───────────────────────────────────────────────────────────────

func _on_new_game() -> void:
	GameState.clear_party()
	get_tree().change_scene_to_file("res://scenes/character_creation/character_creation.tscn")

func _on_quit() -> void:
	get_tree().quit()
