extends AcceptDialog
class_name RitualsPopup

# ─────────────────────────────────────────────────────────────────────────────
# Rituals popup for region-map POIs (ACF HQ, Rest House).
#
# Shows in-progress rituals and learned ritual spells at a glance. The full
# PHB-style spell builder lives on the World tab (world.gd) — this popup's
# "Open Full Builder…" button jumps the player there rather than duplicating
# ~700 lines of tightly-coupled UI.
# ─────────────────────────────────────────────────────────────────────────────

var _tasks_vbox: VBoxContainer
var _active_vbox: VBoxContainer
var _refresh_timer: Timer

func _init() -> void:
	title = "Arcane Center — Rituals"
	min_size = Vector2i(560, 640)
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

	# Header
	vbox.add_child(RimvaleUtils.label("Arcane Rituals", 16, RimvaleColors.ACCENT))
	var desc := RimvaleUtils.label(
		"Design spells via extended casting. Passes an Arcane check to learn.",
		11, RimvaleColors.TEXT_GRAY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Open full builder (world tab)
	var open_builder_btn := RimvaleUtils.button(
		"✨ Open Full Ritual Builder…",
		RimvaleColors.SP_PURPLE, 44, 13)
	open_builder_btn.pressed.connect(_on_open_world_tab)
	vbox.add_child(open_builder_btn)

	vbox.add_child(RimvaleUtils.separator())

	# In-progress rituals
	vbox.add_child(RimvaleUtils.label("In Progress", 13, RimvaleColors.TEXT_LIGHT))
	_tasks_vbox = VBoxContainer.new()
	_tasks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tasks_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_tasks_vbox)

	vbox.add_child(RimvaleUtils.separator())

	# Learned (castable in dungeons)
	vbox.add_child(RimvaleUtils.label(
		"Learned Ritual Spells (Castable in Dungeons)",
		13, RimvaleColors.TEXT_LIGHT))
	_active_vbox = VBoxContainer.new()
	_active_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_active_vbox)

	_refresh_all()

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_refresh_all)
	add_child(_refresh_timer)

func _on_open_world_tab() -> void:
	# Jump to the World tab where the full spell builder lives.
	var main_node = get_tree().root.get_child(0)
	if main_node and main_node.has_method("go_to_tab"):
		main_node.go_to_tab(1)  # World tab
	hide()

func _refresh_all() -> void:
	_refresh_tasks()
	_refresh_active()

func _refresh_tasks() -> void:
	if _tasks_vbox == null or not is_instance_valid(_tasks_vbox):
		return
	for c in _tasks_vbox.get_children():
		c.queue_free()
	if GameState.ritual_tasks.is_empty():
		_tasks_vbox.add_child(RimvaleUtils.label(
			"No rituals in progress.", 12, RimvaleColors.TEXT_GRAY))
		return
	var now: float = Time.get_unix_time_from_system()
	for task in GameState.ritual_tasks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name: String = str(task.get("spell_name", task.get("name", "Ritual")))
		var end_time: float = float(task.get("end_time", now))
		var remaining: float = maxf(0.0, end_time - now)
		var info: String = "%s  (%.0fs remaining)" % [name, remaining]
		row.add_child(RimvaleUtils.label(info, 12, RimvaleColors.TEXT_WHITE))
		_tasks_vbox.add_child(row)

func _refresh_active() -> void:
	if _active_vbox == null or not is_instance_valid(_active_vbox):
		return
	for c in _active_vbox.get_children():
		c.queue_free()
	if GameState.active_rituals.is_empty():
		_active_vbox.add_child(RimvaleUtils.label(
			"No ritual spells learned yet.\nUse 'Open Full Ritual Builder…' to design one.",
			12, RimvaleColors.TEXT_GRAY))
		return
	for r in GameState.active_rituals:
		var card := RimvaleUtils.card(RimvaleColors.BG_CARD, RimvaleColors.DIVIDER, 6, 8)
		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 2)
		card.add_child(cvbox)

		var sp_name: String = str(r.get("spell_name", r.get("name", "Unnamed Ritual")))
		cvbox.add_child(RimvaleUtils.label(sp_name, 13, RimvaleColors.TEXT_WHITE))

		var bits: PackedStringArray = PackedStringArray()
		if r.has("sp_cost"):
			bits.append("%d SP" % int(r["sp_cost"]))
		if r.has("domain"):
			bits.append(str(r["domain"]))
		if r.has("effect"):
			bits.append(str(r["effect"]))
		if bits.size() > 0:
			var meta := RimvaleUtils.label(
				" · ".join(bits), 10, RimvaleColors.TEXT_GRAY)
			meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cvbox.add_child(meta)

		if r.has("description"):
			var d := RimvaleUtils.label(str(r["description"]), 10, RimvaleColors.TEXT_GRAY)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cvbox.add_child(d)

		_active_vbox.add_child(card)
