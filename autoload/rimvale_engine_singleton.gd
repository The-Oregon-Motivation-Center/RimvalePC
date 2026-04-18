## rimvale_engine_singleton.gd
## Autoloaded as "RimvaleAPI" throughout the project.

extends Node

var engine

const _FallbackEngine = preload("res://autoload/rimvale_fallback_engine.gd")

func _ready() -> void:
	if ClassDB.class_exists("RimvaleEngine"):
		engine = ClassDB.instantiate("RimvaleEngine")
		if engine == null:
			push_warning("[Rimvale] ClassDB.instantiate('RimvaleEngine') returned null — using fallback")
			engine = _FallbackEngine.new()
		else:
			print("[Rimvale] RimvaleEngine (C++ DLL) loaded OK")
	else:
		push_warning("[Rimvale] DLL not loaded — using GDScript fallback engine")
		engine = _FallbackEngine.new()
		print("[Rimvale] Fallback engine active. Summon and collection work.")
