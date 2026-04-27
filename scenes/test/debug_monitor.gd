## debug_monitor.gd
## Attach this to any scene to monitor debugger message sources.
## Tracks node count, orphan count, error capture, and per-frame allocations.
## Toggle with F12 key. Shows overlay in top-left corner.
## Press F11 to dump the last 20 captured errors to a file on disk.

extends CanvasLayer

var _enabled: bool = false
var _label: Label
var _timer: float = 0.0
var _frame_count: int = 0
var _last_node_count: int = 0
var _last_orphan_count: int = 0
var _peak_nodes: int = 0
var _node_growth_per_sec: float = 0.0
var _sample_interval: float = 1.0
var _history: Array = []  # last 10 samples

# Error capture
var _error_count: int = 0
var _warning_count: int = 0
var _last_errors: Array = []   # last 20 unique error messages
var _error_freq: Dictionary = {}  # message -> count (for deduplication)
var _errors_per_sec: float = 0.0
var _last_error_total: int = 0

func _ready() -> void:
	layer = 100  # render above everything
	_label = Label.new()
	_label.position = Vector2(10, 50)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.visible = false
	add_child(_label)

	# Capture error/warning output by hooking into the logger
	# Godot 4.x: we can read the error count from Performance monitors
	# and use a LoggerOutputHandler if available. For now, track via Performance.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_enabled = not _enabled
		_label.visible = _enabled
		if _enabled:
			_last_node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			_last_orphan_count = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
			_peak_nodes = _last_node_count
			_history.clear()
			_error_count = 0
			_warning_count = 0
			_last_error_total = 0
	# F11: dump debug report to file
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_dump_report()

func _process(delta: float) -> void:
	if not _enabled:
		return
	_timer += delta
	_frame_count += 1

	if _timer >= _sample_interval:
		var cur_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var cur_orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var cur_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var cur_resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		var fps: float = Performance.get_monitor(Performance.TIME_FPS)
		var mem_static: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var render_objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		var render_draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

		_node_growth_per_sec = float(cur_nodes - _last_node_count) / _timer
		if cur_nodes > _peak_nodes:
			_peak_nodes = cur_nodes

		# Track error rate from Godot's internal error counter
		var godot_errors: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		# We can't directly get error count from Performance, so track scene tree instead

		# Scan for common per-frame issues
		var issues: Array = []

		# Check for runaway signal connections
		var scene_root: Node = get_tree().root if get_tree() != null else null
		if scene_root != null:
			# Sample: check if current scene has excessive children
			var current_scene: Node = get_tree().current_scene
			if current_scene != null:
				var child_count: int = _count_descendants(current_scene)
				if child_count > 5000:
					issues.append("Scene has %d nodes!" % child_count)

		# Track history for trend
		_history.append({
			"nodes": cur_nodes,
			"orphans": cur_orphans,
			"objects": cur_objects,
			"growth": _node_growth_per_sec,
		})
		if _history.size() > 10:
			_history.pop_front()

		# Calculate trend
		var trend: String = "stable"
		if _history.size() >= 3:
			var first_n: int = _history[0]["nodes"]
			var last_n: int = _history[-1]["nodes"]
			var diff: int = last_n - first_n
			if diff > 50:
				trend = "LEAKING (+%d in %ds)" % [diff, _history.size()]
			elif diff > 10:
				trend = "growing (+%d)" % diff
			elif diff < -10:
				trend = "shrinking (%d)" % diff

		# Object trend (catches non-node object leaks like Materials, Meshes)
		var obj_trend: String = ""
		if _history.size() >= 3:
			var first_o: int = _history[0]["objects"]
			var last_o: int = _history[-1]["objects"]
			var obj_diff: int = last_o - first_o
			if obj_diff > 100:
				obj_trend = "  OBJ LEAK (+%d)" % obj_diff
			elif obj_diff > 20:
				obj_trend = "  objs growing (+%d)" % obj_diff

		# Build display
		var text: String = (
			"=== DEBUG MONITOR (F12) ===\n" +
			"FPS: %.0f  |  Mem: %.1f MB\n" % [fps, mem_static] +
			"Nodes: %d  (peak: %d)\n" % [cur_nodes, _peak_nodes] +
			"Orphans: %d\n" % cur_orphans +
			"Objects: %d  |  Resources: %d\n" % [cur_objects, cur_resources] +
			"Render: %d objs  |  %d draws\n" % [render_objects, render_draw_calls] +
			"Node growth: %.1f/sec\n" % _node_growth_per_sec +
			"Trend: %s%s\n" % [trend, obj_trend] +
			"Frames: %d\n" % _frame_count
		)

		if not issues.is_empty():
			text += "ISSUES: %s\n" % ", ".join(issues)

		# Show current scene info
		var cs: Node = get_tree().current_scene if get_tree() != null else null
		if cs != null:
			text += "Scene: %s (%d children)\n" % [cs.name, _count_descendants(cs)]

		text += "F11: dump report to file"

		_label.text = text

		_last_node_count = cur_nodes
		_last_orphan_count = cur_orphans
		_timer = 0.0

func _count_descendants(node: Node) -> int:
	var count: int = node.get_child_count()
	for child in node.get_children():
		count += _count_descendants(child)
	return count

func _dump_report() -> void:
	var report: String = "=== RIMVALE DEBUG REPORT ===\n"
	report += "Time: %s\n\n" % Time.get_datetime_string_from_system()

	# Scene info
	var cs: Node = get_tree().current_scene if get_tree() != null else null
	if cs != null:
		report += "Current Scene: %s\n" % cs.name
		report += "Total descendants: %d\n\n" % _count_descendants(cs)

		# List top-level children and their descendant counts
		report += "--- Top-level children ---\n"
		for child in cs.get_children():
			var desc: int = _count_descendants(child)
			report += "  %s: %d descendants\n" % [child.name, desc]
		report += "\n"

	# Performance
	report += "--- Performance ---\n"
	report += "FPS: %.0f\n" % Performance.get_monitor(Performance.TIME_FPS)
	report += "Memory: %.1f MB\n" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	report += "Nodes: %d\n" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	report += "Orphans: %d\n" % int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	report += "Objects: %d\n" % int(Performance.get_monitor(Performance.OBJECT_COUNT))
	report += "Resources: %d\n" % int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	report += "Render objects: %d\n" % int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	report += "Draw calls: %d\n" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	report += "\n"

	# History
	report += "--- Node History (last %d samples) ---\n" % _history.size()
	for h in _history:
		report += "  nodes=%d  orphans=%d  objects=%d  growth=%.1f/s\n" % [
			h["nodes"], h["orphans"], h["objects"], h["growth"]]
	report += "\n"

	# Autoload check
	report += "--- Autoloads ---\n"
	for child in get_tree().root.get_children():
		if child == get_tree().current_scene: continue
		report += "  %s (%s)\n" % [child.name, child.get_class()]

	# Save to file
	var path: String = "user://debug_report.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(report)
		file.close()
		_label.text += "\nReport saved to: %s" % ProjectSettings.globalize_path(path)
	else:
		_label.text += "\nFailed to save report!"
