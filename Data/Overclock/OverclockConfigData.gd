extends Resource
class_name OverclockConfigData

@export_category("Timing")

@export_range(0.0, 3600.0, 0.1)
var initial_cooldown_seconds: float = 30.0

@export_range(0.05, 3600.0, 0.05)
var effect_duration_seconds: float = 120.0

@export_range(0.05, 3600.0, 0.05)
var cooldown_duration_seconds: float = 180.0

@export_category("Economy")

@export_range(1.0, 10.0, 0.05)
var income_multiplier: float = 2.0

@export_category("Commands")

@export var instructions: Array[String] = []


func get_instructions_copy() -> Array[String]:
	return instructions.duplicate()
