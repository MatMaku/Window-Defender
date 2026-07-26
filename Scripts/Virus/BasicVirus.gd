extends DesktopVirus
class_name BasicVirus

@export_category("Chaser Stats")

@export_range(0.0, 1000.0, 0.1)
var movement_speed: float = 48.0

@export_range(0.0, 999.0, 0.01)
var attack_damage: float = 0.5

@export_range(0.05, 10.0, 0.05)
var attack_interval_seconds: float = 1.25

@export_range(0.0, 10.0, 0.1)
var attack_arrival_distance: float = 0.75

@export_range(0.0, 40.0, 0.5)
var attack_overlap_distance: float = 12.0

@export_category("Attack Feedback")

@export_range(0.01, 1.0, 0.01)
var attack_shake_duration: float = 0.10

@export_range(0.0, 20.0, 0.5)
var attack_shake_distance: float = 3.0

var _attack_cooldown_remaining: float = 0.0
var _visual_rest_position: Vector2 = Vector2.ZERO

var _attack_tween: Tween


func _ready() -> void:
	super._ready()

	var visual_node: Control = get_visual_node()

	if visual_node != null:
		_visual_rest_position = visual_node.position


func apply_runtime_stats(
	runtime_stats: EnemyRuntimeStats
) -> void:
	if runtime_stats == null:
		return

	super.apply_runtime_stats(runtime_stats)

	movement_speed = maxf(
		0.0,
		runtime_stats.movement_speed
	)

	attack_damage = maxf(
		0.0,
		runtime_stats.attack_damage
	)

	attack_interval_seconds = maxf(
		0.05,
		runtime_stats.attack_interval_seconds
	)

	attack_arrival_distance = maxf(
		0.0,
		runtime_stats.attack_arrival_distance
	)

	attack_overlap_distance = maxf(
		0.0,
		runtime_stats.attack_overlap_distance
	)


func _process_virus(delta: float) -> void:
	if not is_instance_valid(_system_manager):
		return

	_update_movement_and_attack(delta)


func _update_movement_and_attack(delta: float) -> void:
	var target_rect: Rect2 = (
		_system_manager.get_attack_target_global_rect()
	)

	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return

	var current_center: Vector2 = get_center_global_position()

	var attack_anchor: Vector2 = (
		_get_attack_anchor_global_position(
			target_rect,
			current_center
		)
	)

	var distance_to_target: float = (
		current_center.distance_to(attack_anchor)
	)

	if distance_to_target <= attack_arrival_distance:
		_attack_system(delta)
		return

	_move_towards(
		attack_anchor,
		distance_to_target,
		delta
	)


func _move_towards(
	target_global_position: Vector2,
	distance_to_target: float,
	delta: float
) -> void:
	var current_center: Vector2 = get_center_global_position()

	var direction: Vector2 = (
		current_center.direction_to(target_global_position)
	)

	var movement_distance: float = minf(
		movement_speed * delta,
		distance_to_target
	)

	global_position += direction * movement_distance


func _attack_system(delta: float) -> void:
	if attack_damage <= 0.0:
		return

	_attack_cooldown_remaining = maxf(
		0.0,
		_attack_cooldown_remaining - delta
	)

	if _attack_cooldown_remaining > 0.0:
		return

	var applied_damage: float = (
		_system_manager.damage_system(attack_damage)
	)

	_attack_cooldown_remaining = attack_interval_seconds

	if applied_damage > 0.0:
		_play_attack_feedback()


func _get_attack_anchor_global_position(
	target_rect: Rect2,
	from_global_position: Vector2
) -> Vector2:
	if target_rect.has_point(from_global_position):
		return from_global_position

	var target_end: Vector2 = target_rect.end

	var closest_point: Vector2 = Vector2(
		clampf(
			from_global_position.x,
			target_rect.position.x,
			target_end.x
		),
		clampf(
			from_global_position.y,
			target_rect.position.y,
			target_end.y
		)
	)

	var inward_direction: Vector2 = (
		closest_point.direction_to(target_rect.get_center())
	)

	if inward_direction == Vector2.ZERO:
		return closest_point

	var maximum_overlap: float = minf(
		target_rect.size.x,
		target_rect.size.y
	) * 0.4

	var overlap_distance: float = minf(
		attack_overlap_distance,
		maximum_overlap
	)

	return closest_point + (
		inward_direction * overlap_distance
	)


func _play_attack_feedback() -> void:
	var visual_node: Control = get_visual_node()

	if visual_node == null:
		return

	if _attack_tween != null and _attack_tween.is_running():
		_attack_tween.kill()

	visual_node.position = _visual_rest_position

	var segment_duration: float = (
		attack_shake_duration / 4.0
	)

	_attack_tween = create_tween()

	_attack_tween.tween_property(
		visual_node,
		"position",
		_visual_rest_position + Vector2(
			attack_shake_distance,
			0.0
		),
		segment_duration
	)

	_attack_tween.tween_property(
		visual_node,
		"position",
		_visual_rest_position + Vector2(
			-attack_shake_distance,
			0.0
		),
		segment_duration
	)

	_attack_tween.tween_property(
		visual_node,
		"position",
		_visual_rest_position + Vector2(
			attack_shake_distance * 0.4,
			0.0
		),
		segment_duration
	)

	_attack_tween.tween_property(
		visual_node,
		"position",
		_visual_rest_position,
		segment_duration
	)


func _before_die() -> void:
	if _attack_tween != null and _attack_tween.is_running():
		_attack_tween.kill()
