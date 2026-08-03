extends RefCounted
class_name SlowdownAreaSource

var _source_owner: Node
var _effect_origin: Node2D
var _effect_data: SlowdownEffectData
var _speed_multiplier_override: float = -1.0


func configure(
	source_owner: Node,
	effect_origin: Node2D,
	effect_data: SlowdownEffectData
) -> void:
	_source_owner = source_owner
	_effect_origin = effect_origin
	_effect_data = effect_data


func set_speed_multiplier(speed_multiplier: float) -> void:
	_speed_multiplier_override = clampf(
		speed_multiplier,
		0.0,
		1.0
	)


func is_active() -> bool:
	return (
		is_instance_valid(_source_owner)
		and _source_owner.is_inside_tree()
		and is_instance_valid(_effect_origin)
		and _effect_data != null
	)


func get_runtime_id() -> int:
	if not is_instance_valid(_source_owner):
		return 0

	return _source_owner.get_instance_id()


func get_center_global_position() -> Vector2:
	if not is_instance_valid(_effect_origin):
		return Vector2.INF

	return _effect_origin.global_position


func get_effect_radius() -> float:
	if _effect_data == null:
		return 0.0

	return _effect_data.get_effect_radius()


func get_speed_multiplier() -> float:
	if _speed_multiplier_override >= 0.0:
		return _speed_multiplier_override

	if _effect_data == null:
		return 1.0

	return _effect_data.get_speed_multiplier()
