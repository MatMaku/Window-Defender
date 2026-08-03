extends AppWindow
class_name TurretWindow

const TurretShotTracerClass = preload(
	"res://Scripts/Turret/TurretShotTracer.gd"
)

@export_category("Combat")

@export_range(0.0, 9999.0, 0.1)
var attack_damage: float = 2.0

@export_range(1.0, 4000.0, 1.0)
var attack_range: float = 150.0

@export_range(0.05, 60.0, 0.05)
var fire_cooldown_seconds: float = 1.25

@export_range(0.0, 30.0, 0.1)
var rotation_speed_radians: float = 12.0

@export_range(0.0, 45.0, 0.1)
var aim_tolerance_degrees: float = 2.0

@export_range(-360.0, 360.0, 0.5)
var sprite_angle_offset_degrees: float = 0.0

@export_category("Tracer")

@export var tracer_scene: PackedScene

@export_range(0.01, 1.0, 0.01)
var tracer_duration_seconds: float = 0.2

@export_category("Recoil")

@export_range(0.0, 32.0, 0.5)
var recoil_distance: float = 6.0

@export_range(0.01, 1.0, 0.01)
var recoil_out_duration: float = 0.04

@export_range(0.01, 1.0, 0.01)
var recoil_return_duration: float = 0.09

@onready var turret_pivot: Control = %TurretPivot
@onready var recoil_container: Control = %RecoilContainer
@onready var aim_origin: Marker2D = %AimOrigin
@onready var muzzle_point: Marker2D = %MuzzlePoint

var _window_manager: WindowManager
var _enemy_manager: EnemyManager
var _target: DesktopVirus
var _cooldown_remaining: float = 0.0
var _was_dragging: bool = false
var _recoil_base_position: Vector2 = Vector2.ZERO
var _recoil_tween: Tween


func configure_runtime_services(
	window_manager: WindowManager,
	enemy_manager: EnemyManager
) -> void:
	_window_manager = window_manager
	_enemy_manager = enemy_manager


func _ready() -> void:
	super._ready()

	_configure_rotation_geometry()
	_recoil_base_position = recoil_container.position
	_cooldown_remaining = maxf(0.0, fire_cooldown_seconds)

	if _window_manager == null:
		push_error("TurretWindow requires WindowManager.")

	if _enemy_manager == null:
		push_error("TurretWindow requires EnemyManager.")


func _exit_tree() -> void:
	_target = null

	if _recoil_tween != null and _recoil_tween.is_running():
		_recoil_tween.kill()


func _process(delta: float) -> void:
	if _window_manager == null or _enemy_manager == null:
		return

	if is_opening():
		return

	if is_being_dragged():
		_suspend_for_drag()
		return

	if _was_dragging:
		_was_dragging = false
		_target = null

	_cooldown_remaining = maxf(
		0.0,
		_cooldown_remaining - delta
	)

	var active_enemies: Array[DesktopVirus] = (
		_enemy_manager.get_active_enemies()
	)
	if not _is_target_valid(_target, active_enemies):
		_target = _find_nearest_visible_enemy(active_enemies)

	if _target == null:
		return

	_rotate_towards_target(_target, delta)

	if _cooldown_remaining > 0.0:
		return

	if not _is_target_valid(_target, active_enemies):
		_target = null
		return

	if not _is_aim_aligned(_target):
		return

	_fire_at_target(_target)


func create_save_snapshot() -> Dictionary:
	return {
		"cooldown_remaining": maxf(
			0.0,
			_cooldown_remaining
		)
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	_cooldown_remaining = clampf(
		float(
			snapshot.get(
				"cooldown_remaining",
				fire_cooldown_seconds
			)
		),
		0.0,
		fire_cooldown_seconds
	)
	_target = null
	_was_dragging = false
	_reset_recoil()


func prepare_after_restore() -> void:
	super.prepare_after_restore()
	_target = null
	_was_dragging = false
	_reset_recoil()


func get_cooldown_remaining() -> float:
	return maxf(0.0, _cooldown_remaining)


func _suspend_for_drag() -> void:
	if _was_dragging:
		return

	_was_dragging = true
	_target = null


func _find_nearest_visible_enemy(
	active_enemies: Array[DesktopVirus]
) -> DesktopVirus:
	var nearest_enemy: DesktopVirus
	var nearest_distance_squared: float = INF
	var origin: Vector2 = aim_origin.global_position

	for enemy: DesktopVirus in active_enemies:
		if not _is_target_valid(enemy, active_enemies):
			continue

		var distance_squared: float = origin.distance_squared_to(
			enemy.get_center_global_position()
		)
		if distance_squared >= nearest_distance_squared:
			continue

		nearest_enemy = enemy
		nearest_distance_squared = distance_squared

	return nearest_enemy


func _is_target_valid(
	enemy: DesktopVirus,
	active_enemies: Array[DesktopVirus]
) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false

	if enemy.is_dead() or not active_enemies.has(enemy):
		return false

	var range_origin: Vector2 = aim_origin.global_position
	var target_position: Vector2 = (
		enemy.get_center_global_position()
	)
	if range_origin.distance_to(target_position) > attack_range:
		return false

	return not _window_manager.is_shot_path_blocked(
		muzzle_point.global_position,
		target_position,
		self
	)


func _rotate_towards_target(
	enemy: DesktopVirus,
	delta: float
) -> void:
	var pivot_global_position: Vector2 = aim_origin.global_position
	var target_direction: Vector2 = (
		pivot_global_position.direction_to(
			enemy.get_center_global_position()
		)
	)
	if target_direction == Vector2.ZERO:
		return

	var barrel_direction: Vector2 = _get_local_barrel_direction()
	var desired_rotation: float = (
		target_direction.angle()
		- barrel_direction.angle()
		+ deg_to_rad(sprite_angle_offset_degrees)
	)
	if rotation_speed_radians <= 0.0:
		turret_pivot.rotation = desired_rotation
		return

	var maximum_rotation: float = (
		rotation_speed_radians * delta
	)
	turret_pivot.rotation = rotate_toward(
		turret_pivot.rotation,
		desired_rotation,
		maximum_rotation
	)


func _is_aim_aligned(enemy: DesktopVirus) -> bool:
	var aim_position: Vector2 = aim_origin.global_position
	var target_direction: Vector2 = aim_position.direction_to(
		enemy.get_center_global_position()
	)
	if target_direction == Vector2.ZERO:
		return true

	var barrel_direction: Vector2 = aim_position.direction_to(
		muzzle_point.global_position
	)
	if barrel_direction == Vector2.ZERO:
		return false

	var angular_error: float = absf(
		barrel_direction.angle_to(target_direction)
	)
	return angular_error <= deg_to_rad(
		maxf(0.0, aim_tolerance_degrees)
	)


func _fire_at_target(enemy: DesktopVirus) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	var start_global_position: Vector2 = (
		muzzle_point.global_position
	)
	var end_global_position: Vector2 = (
		enemy.get_center_global_position()
	)
	if _window_manager.is_shot_path_blocked(
		start_global_position,
		end_global_position,
		self
	):
		_target = null
		return

	var applied_damage: float = enemy.receive_damage(
		maxf(0.0, attack_damage)
	)
	if applied_damage <= 0.0:
		_target = null
		return

	_spawn_tracer(
		start_global_position,
		end_global_position
	)
	_play_recoil()
	_cooldown_remaining = maxf(
		0.0,
		fire_cooldown_seconds
	)

	if enemy.is_dead():
		_target = null


func _spawn_tracer(
	start_global_position: Vector2,
	end_global_position: Vector2
) -> void:
	if tracer_scene == null:
		return

	if _window_manager.window_layer == null:
		return

	var tracer: TurretShotTracerClass = (
		tracer_scene.instantiate()
		as TurretShotTracerClass
	)
	if tracer == null:
		push_error(
			"Turret tracer scene must inherit TurretShotTracer."
		)
		return

	_window_manager.window_layer.add_child(tracer)
	tracer.z_index = z_index
	tracer.play(
		start_global_position,
		end_global_position,
		tracer_duration_seconds
	)


func _play_recoil() -> void:
	_reset_recoil()

	var muzzle_direction: Vector2 = _get_local_barrel_direction()

	var recoil_position: Vector2 = (
		_recoil_base_position
		- muzzle_direction * recoil_distance
	)
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(
		recoil_container,
		"position",
		recoil_position,
		maxf(0.01, recoil_out_duration)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(
		recoil_container,
		"position",
		_recoil_base_position,
		maxf(0.01, recoil_return_duration)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _configure_rotation_geometry() -> void:
	turret_pivot.pivot_offset = aim_origin.position


func _get_local_barrel_direction() -> Vector2:
	var direction: Vector2 = (
		muzzle_point.position - aim_origin.position
	)
	if direction == Vector2.ZERO:
		return Vector2.RIGHT

	return direction.normalized()


func _reset_recoil() -> void:
	if _recoil_tween != null and _recoil_tween.is_running():
		_recoil_tween.kill()

	_recoil_tween = null
	if recoil_container != null:
		recoil_container.position = _recoil_base_position
