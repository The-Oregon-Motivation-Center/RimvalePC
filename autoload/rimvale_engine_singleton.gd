## rimvale_engine_singleton.gd
## Autoloaded as "RimvaleAPI" throughout the project.
## Every scene accesses the C++ engine through RimvaleAPI.engine
## e.g.  RimvaleAPI.engine.create_character("Vargas", "Regal Human", 20)

extends Node

var engine: RimvaleEngine

func _ready() -> void:
	engine = RimvaleEngine.new()
	print("[Rimvale] RimvaleEngine GDExtension loaded OK")
