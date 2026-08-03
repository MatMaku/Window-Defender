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

@export_range(0.05, 60.0, 0.05)
var minimum_fire_cooldown_seconds: float = 0.35

@export_range(0.0, 30.0, 0.1)
var rotation_speed_radians: float = 12.0

@export_range(0.0, 45.0, 0.1)
var aim_tolerance_degrees: float = 2.0

@export_range(-360.0, 360.0, 0.5)
var sprite_angle_offset_degrees: float = 0.0

@export_category("Upgrade")

@export var performance_upgrade_offer: ShopUpgradeOfferData

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
var _upgrade_state: GameUpgradeState
var _effective_attack_damage: float = 0.0
var _effective_attack_range: float = 0.0
var _effective_fire_cooldown_seconds: float = 0.0


func configure_runtime_services(
	window_manager: WindowManager,
	enemy_manager: EnemyManager
) -> void:
	_window_manager = window_manager
	_enemy_manager = enemy_manager


func _ready() -> void:
	super._ready()

	_resolve_upgrade_state()
	_configure_rotation_geometry()
	_recoil_base_position = recoil_container.position
	_cooldown_remaining = maxf(
		0.0,
		_effective_fire_cooldown_seconds
	)

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

	if _target != null and not is_instance_valid(_target):
		_target = null

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
					_effective_fire_cooldown_seconds
				)
			),
		0.0,
		_effective_fire_cooldown_seconds
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
	var nearest_enemy: DesktopVirus = null
	var nearest_distance_squared: float = INF
	var origin: Vector2 = aim_origin.global_position

	for enemy_value: Variant in active_enemies:
		if not _is_target_valid(enemy_value, active_enemies):
			continue

		var enemy: DesktopVirus = enemy_value as DesktopVirus
		if enemy == null:
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
	enemy_value: Variant,
	active_enemies: Array[DesktopVirus]
) -> bool:
	if enemy_value == null:
		return false

	if not is_instance_valid(enemy_value):
		return false

	if not enemy_value is DesktopVirus:
		return false

	var enemy: DesktopVirus = enemy_value as DesktopVirus
	if enemy == null:
		return false

	if enemy.is_dead() or not active_enemies.has(enemy):
		return false

	var range_origin: Vector2 = aim_origin.global_position
	var target_position: Vector2 = (
		enemy.get_center_global_position()
	)
	if range_origin.distance_to(target_position) > _effective_attack_range:
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
		_target = null
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

	# receive_damage() can synchronously kill and free the enemy. Do not keep
	# the potentially stale reference as this turret's current target.
	_target = null

	var applied_damage: float = enemy.receive_damage(
		maxf(0.0, _effective_attack_damage)
	)
	if applied_damage <= 0.0:
		return

	_spawn_tracer(
		start_global_position,
		end_global_position
	)
	_play_recoil()
	_cooldown_remaining = maxf(
		0.0,
		_effective_fire_cooldown_seconds
	)

	if is_instance_valid(enemy) and not enemy.is_dead():
		_target = enemy


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


func _resolve_upgrade_state() -> void:
	_upgrade_state = GameState.upgrade_state
	if _upgrade_state == null:
		push_error("TurretWindow requires GameUpgradeState.")
		_apply_performance_upgrade(false)
		return

	if not _upgrade_state.upgrade_purchase_counts_changed.is_connected(
		_on_upgrade_purchase_counts_changed
	):
		_upgrade_state.upgrade_purchase_counts_changed.connect(
			_on_upgrade_purchase_counts_changed
		)

	_apply_performance_upgrade(false)


func _on_upgrade_purchase_counts_changed(
	_purchase_counts_snapshot: Dictionary
) -> void:
	_apply_performance_upgrade(true)


func _apply_performance_upgrade(
	preserve_cooldown_progress: bool
) -> void:
	var purchase_count: int = 0
	if _upgrade_state != null and performance_upgrade_offer != null:
		purchase_count = _upgrade_state.get_upgrade_purchase_count(
			performance_upgrade_offer.offer_id
		)

	var damage_multiplier: float = 1.0
	var range_multiplier: float = 1.0
	var fire_rate_multiplier: float = 1.0
	if performance_upgrade_offer != null:
		damage_multiplier = (
			performance_upgrade_offer.get_primary_effect_for_purchase_count(
				purchase_count,
				1.0
			)
		)
		range_multiplier = (
			performance_upgrade_offer.get_secondary_effect_for_purchase_count(
				purchase_count,
				1.0
			)
		)
		fire_rate_multiplier = (
			performance_upgrade_offer.get_tertiary_effect_for_purchase_count(
				purchase_count,
				1.0
			)
		)

	var previous_cooldown_duration: float = maxf(
		0.0,
		_effective_fire_cooldown_seconds
	)
	_effective_attack_damage = maxf(
		0.0,
		attack_damage * maxf(0.0, damage_multiplier)
	)
	_effective_attack_range = maxf(
		0.0,
		attack_range * maxf(0.0, range_multiplier)
	)
	_effective_fire_cooldown_seconds = maxf(
		maxf(0.05, minimum_fire_cooldown_seconds),
		fire_cooldown_seconds / maxf(0.01, fire_rate_multiplier)
	)

	if not preserve_cooldown_progress:
		return

	if previous_cooldown_duration <= 0.0:
		return

	var remaining_ratio: float = clampf(
		_cooldown_remaining / previous_cooldown_duration,
		0.0,
		1.0
	)
	_cooldown_remaining = (
		_effective_fire_cooldown_seconds * remaining_ratio
	)
