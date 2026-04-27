extends AcceptDialog
class_name ForagingPopup

# ─────────────────────────────────────────────────────────────────────────────
# Foraging popup for region-map POIs (ACF HQ, Outposts).
# Mirrors world.gd::_build_foraging_tab but fully self-contained.
# ─────────────────────────────────────────────────────────────────────────────

var _active_handles: Array = []
var _char_dd: OptionButton
var _type_lbl: Label
var _tasks_vbox: VBoxContainer
var _forage_type: String = "hunting"
var _refresh_timer: Timer

func _init() -> void:
	title = "Outpost — Foraging"
	min_size = Vector2i(520, 560)
	get_ok_button().text = "Close"
	visibility_changed.connect(_on_visibility_changed)
	close_requested.connect(queue_free)
	confirmed.connect(queue_free)

func _on_visibility_changed() -> void:
	if not visible:
		queue_free()

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	vbox.add_child(RimvaleUtils.label("Assign Foraging Tasks", 16, RimvaleColors.ACCENT))

	# Selected forage type label
	_type_lbl = RimvaleUtils.label("Type: Hunting", 12, RimvaleColors.CYAN)
	vbox.add_child(_type_lbl)

	# Forage type buttons
	var forage_types: Array = [
		["🏹 Hunting", "hunting"],
		["🎣 Fishing", "fishing"],
		["⛏ Mining", "mining"],
		["🌿 Gathering", "gathering"],
	]
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	for fd in forage_types:
		var btn := RimvaleUtils.button(fd[0], RimvaleColors.CYAN, 44, 12)
		var ft: String = fd[1]
		btn.pressed.connect(func():
			_forage_type = ft
			_type_lbl.text = "Type: " + ft.capitalize())
		hbox.add_child(btn)
	vbox.add_child(hbox)

	# Character dropdown
	_active_handles = GameState.get_active_handles()
	if _active_handles.size() > 0:
		var ch := HBoxContainer.new()
		ch.add_child(RimvaleUtils.label("Character:", 12, RimvaleColors.TEXT_WHITE))
		_char_dd = OptionButton.new()
		for h in _active_handles:
			_char_dd.add_item(str(RimvaleAPI.engine.get_character_name(h)))
		_char_dd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.add_child(_char_dd)
		vbox.add_child(ch)
	else:
		vbox.add_child(RimvaleUtils.label("No active party members.", 12, RimvaleColors.DANGER))

	var start_btn := RimvaleUtils.button("Start Foraging", RimvaleColors.GOLD, 44, 13)
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	vbox.add_child(RimvaleUtils.separator())

	vbox.add_child(RimvaleUtils.label("Active Tasks", 14, RimvaleColors.ACCENT))
	_tasks_vbox = VBoxContainer.new()
	_tasks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tasks_vbox)
	_refresh_tasks()

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh_tasks)
	add_child(_refresh_timer)

func _on_start_pressed() -> void:
	if _active_handles.is_empty():
		push_warning("[Foraging Popup] No active party members")
		return
	var sel_idx: int = _char_dd.selected if _char_dd != null else 0
	sel_idx = clamp(sel_idx, 0, _active_handles.size() - 1)
	var handle: int = _active_handles[sel_idx]
	if GameState.is_busy(handle):
		push_warning("[Foraging Popup] Character is already busy")
		return
	var gold_by_type: Dictionary = {"hunting": 25, "fishing": 20, "mining": 30, "gathering": 15}
	var task: Dictionary = {
		"character_handle": handle,
		"character_name":   str(RimvaleAPI.engine.get_character_name(handle)),
		"forage_type":      _forage_type,
		"end_time":         Time.get_unix_time_from_system() + 45.0,
		"gold_reward":      gold_by_type.get(_forage_type, 15),
	}
	GameState.forage_tasks.append(task)
	GameState.set_busy(handle, true)
	_refresh_tasks()
	print("[Foraging Popup] %s started %s (45s, +%dg)" % [task["character_name"], _forage_type, task["gold_reward"]])

func _refresh_tasks() -> void:
	if _tasks_vbox == null or not is_instance_valid(_tasks_vbox):
		return
	for c in _tasks_vbox.get_children():
		c.queue_free()
	if GameState.forage_tasks.is_empty():
		_tasks_vbox.add_child(RimvaleUtils.label("No active foraging tasks.", 12, RimvaleColors.TEXT_GRAY))
		return
	var now: float = Time.get_unix_time_from_system()
	for task in GameState.forage_tasks:
		var remaining: float = maxf(0.0, float(task["end_time"]) - now)
		var row := HBoxContainer.new()
		var info: String = "%s → %s  (%.0fs, +%dg)" % [
			task["character_name"], str(task["forage_type"]).capitalize(), remaining, int(task["gold_reward"])]
		row.add_child(RimvaleUtils.label(info, 12, RimvaleColors.TEXT_WHITE))
		_tasks_vbox.add_child(row)
