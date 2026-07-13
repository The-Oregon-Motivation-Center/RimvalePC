## tutorial_hint.gd
## Lightweight contextual-hint overlay. Anchored to the bottom-center of
## the active viewport. Auto-dismisses after a timeout or on click/Esc.
## Each hint is keyed by a `step_id` string. GameState tracks which steps
## have already been shown so a hint never appears twice across sessions.
##
## Usage from anywhere:
##     RimvaleUtils.show_hint(self, "movement",
##         "Use arrow keys or the D-pad to move. Q/E rotate the camera.")

extends CanvasLayer

const COL_BG     := Color(0.05, 0.04, 0.10, 0.95)
const COL_BORDER := Color(0.95, 0.78, 0.32, 1.0)
const COL_TITLE  := Color(0.95, 0.78, 0.32, 1.0)
const COL_TEXT   := Color(0.92, 0.92, 0.95, 1.0)
const COL_DIM    := Color(0.65, 0.65, 0.72, 1.0)

var _step_id: String = ""
var _root: Control
var _auto_dismiss_seconds: float = 14.0
var _elapsed: float = 0.0


func open(step_id: String, body_text: String, title: String = "Tip") -> void:
	_step_id = step_id
	_build(title, body_text)
	# Subtle audio cue.
	if typeof(AudioManager) != TYPE_NIL:
		AudioManager.play_ui("ui_open", -6.0)


func _build(title: String, body_text: String) -> void:
	layer = 90
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Panel anchored bottom-center
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -160
	panel.offset_bottom = -40
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	# Title row: "Tip" badge + step id (subtle)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)

	var badge := Label.new()
	badge.text = "✦ " + title
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", COL_TITLE)
	head.add_child(badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	var dismiss_lbl := Label.new()
	dismiss_lbl.text = "Click or press Esc to dismiss"
	dismiss_lbl.add_theme_font_size_override("font_size", 10)
	dismiss_lbl.add_theme_color_override("font_color", COL_DIM)
	head.add_child(dismiss_lbl)

	# Body
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", COL_TEXT)
	body.custom_minimum_size = Vector2(520, 0)
	col.add_child(body)

	# Fade in
	_root.modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(_root, "modulate", Color(1, 1, 1, 1), 0.25)

	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > _auto_dismiss_seconds:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE \
				or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_close()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var jb := (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_A or jb == JOY_BUTTON_B:
			_close()
			get_viewport().set_input_as_handled()


func _close() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	if _step_id != "":
		GameState.mark_tutorial_step_shown(_step_id)
	var t := create_tween()
	t.tween_property(_root, "modulate", Color(1, 1, 1, 0), 0.2)
	t.tween_callback(Callable(self, "queue_free"))
