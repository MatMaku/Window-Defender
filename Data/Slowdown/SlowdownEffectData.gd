extends Resource
class_name SlowdownEffectData

@export_range(0.0, 2000.0, 1.0)
var effect_radius: float = 180.0

@export_range(0.0, 1.0, 0.01)
var speed_multiplier: float = 0.65


func get_effect_radius() -> float:
	return maxf(0.0, effect_radius)


func get_speed_multiplier() -> float:
	return clampf(speed_multiplier, 0.0, 1.0)
