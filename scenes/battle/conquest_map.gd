## conquest_map.gd
## Region Conquest world map — the Battle Mode meta-campaign screen. Shows all
## 10 regions as a grid: gold = held, highlighted = attackable. Click a region
## to launch an escalating skirmish; win to claim it. Hold all 10 for the
## triumph screen. Progress persists via the Conquest autoload.
##
## Reached from the title screen ("🗺 Conquest") and returned to by a conquest
## battle's "Back to World Map" button. Entirely separate from story saves.
extends Control

const TITLE_SCENE := "res://scenes/title/title_screen.tscn"
const BATTLE_RTS_SCENE := "res://scenes/battle/battle_rts.tscn"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RimvaleUtils.add_bg(self, Color(0.04, 0.03, 0.09, 1.0))
	# We can land here straight from a conquest battle — make sure no stale
	# battle is still flagged active behind the map.
	if BattleSystem.active:
		BattleSystem.end_battle()
	# Ambient world-map music (guarded internally against missing assets).
	AudioManager.play_music("music_region")
	if Conquest.is_complete():
		_build_triumph()
	else:
		_build_map()


# ── Map screen ───────────────────────────────────────────────────────────────
func _build_map() -> void:
	var vbox := _scaffold()

	vbox.add_child(RimvaleUtils.spacer(24))
	var title := RimvaleUtils.label("🗺 REGION CONQUEST", 28, RimvaleColors.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var held: int = Conquest.owned_count()
	var total: int = Conquest.total_count()
	var subtitle := RimvaleUtils.label(
		"Claim every region to win the war. %d / %d held." % [held, total],
		13, RimvaleColors.TEXT_GRAY)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Escalation preview for the next battle.
	var s: Dictionary = Conquest.settings_for_next()
	var tier := RimvaleUtils.label(
		"Next front: %s — %d teams · level %d · %s · %s resources" % [
			str(s["tag"]), int(s["teams"]), int(s["level"]),
			str(s["difficulty"]).capitalize(), str(s["resources"]).capitalize()],
		12, RimvaleColors.ACCENT)
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tier)

	vbox.add_child(RimvaleUtils.separator())

	# Region grid.
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	for rid_v in Conquest.all_regions():
		var rid: String = str(rid_v)
		grid.add_child(_region_button(rid))

	vbox.add_child(RimvaleUtils.separator())

	var back := RimvaleUtils.button("← Back to Title", RimvaleColors.TEXT_GRAY, 44, 15)
	back.custom_minimum_size = Vector2(220, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file(TITLE_SCENE))
	vbox.add_child(back)

	vbox.add_child(RimvaleUtils.spacer(24))


## A single region tile: gold + ✔ when held, highlighted + ⚔ when attackable.
func _region_button(rid: String) -> Button:
	var owned: bool = Conquest.is_owned(rid)
	var rname: String = BattleSystem.get_region_display(rid)
	var b := Button.new()
	b.custom_minimum_size = Vector2(178, 58)
	b.add_theme_font_size_override("font_size", 13)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	sb.set_border_width_all(2)
	if owned:
		b.text = "✔ %s" % rname
		b.add_theme_color_override("font_color", RimvaleColors.GOLD)
		sb.bg_color = Color(RimvaleColors.GOLD.r, RimvaleColors.GOLD.g, RimvaleColors.GOLD.b, 0.14)
		sb.border_color = Color(RimvaleColors.GOLD.r, RimvaleColors.GOLD.g, RimvaleColors.GOLD.b, 0.55)
		b.disabled = true
	else:
		b.text = "⚔ %s" % rname
		b.add_theme_color_override("font_color", RimvaleColors.TEXT_WHITE)
		sb.bg_color = Color(RimvaleColors.ORANGE.r, RimvaleColors.ORANGE.g, RimvaleColors.ORANGE.b, 0.10)
		sb.border_color = Color(RimvaleColors.ORANGE.r, RimvaleColors.ORANGE.g, RimvaleColors.ORANGE.b, 0.45)
		b.tooltip_text = "Attack %s to claim it." % rname
		b.pressed.connect(func(): _attack(rid))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("disabled", sb)
	return b


func _attack(rid: String) -> void:
	if Conquest.is_owned(rid):
		return
	if Conquest.begin_attempt(rid):
		get_tree().change_scene_to_file(BATTLE_RTS_SCENE)


# ── Triumph screen (all regions held) ────────────────────────────────────────
func _build_triumph() -> void:
	AudioManager.play_sfx("jingle_victory")
	var vbox := _scaffold()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(RimvaleUtils.spacer(60))

	var crown := RimvaleUtils.label("👑", 64, RimvaleColors.GOLD)
	crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(crown)

	var title := RimvaleUtils.label("THE REALM IS YOURS", 34, RimvaleColors.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body := RimvaleUtils.label(
		"All %d regions of Rimvale fly your banner. Every warband has bent the\nknee. The conquest is complete." % Conquest.total_count(),
		15, RimvaleColors.TEXT_LIGHT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(body)

	vbox.add_child(RimvaleUtils.spacer(24))

	var again := RimvaleUtils.button("⚔ New Campaign", RimvaleColors.ORANGE, 46, 15)
	again.custom_minimum_size = Vector2(240, 46)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func():
		Conquest.reset_campaign()
		get_tree().reload_current_scene())
	vbox.add_child(again)

	var back := RimvaleUtils.button("← Back to Title", RimvaleColors.TEXT_GRAY, 44, 15)
	back.custom_minimum_size = Vector2(240, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file(TITLE_SCENE))
	vbox.add_child(back)


# ── Shared layout scaffold (scroll → centered column) ────────────────────────
func _scaffold() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(940, 0)
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 14)
	outer.add_child(vbox)
	return v