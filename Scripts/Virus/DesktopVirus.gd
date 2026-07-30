extends Control
class_name DesktopVirus

signal health_changed(
	current_health: float,
	max_health: float
)

signal died(virus: DesktopVirus)

signal dragging_changed(
	virus: DesktopVirus,
	is_dragging: bool
)

@export_category("Identity")

@export var enemy_id: StringName = &"desktop_virus"
@export var display_name: String = "Desktop Virus"

@export_category("Stats")

@export_range(0.1, 999.0, 0.1)
var max_health: float = 2.0

@export_category("Rewards")

@export_range(0, 999, 1)
var virus_data_reward: int = 1

@export_category("Dragging")

@export var drag_enabled: bool = true
@export var release_drag_over_windows: bool = true

@export_category("Navigation")

@export_range(1.0, 32.0, 0.5)
var waypoint_reach_distance: float = 8.0

@export_category("Visual")

@export var visual_node_path: NodePath = ^"VirusTexture"

var _system_manager: SystemManager
var _window_manager: WindowManager
var _navigation_manager: Node

var _current_health: float = 0.0

var _is_dragging: bool = false
var _is_dead: bool = false
var _restore_prepared: bool = false

var _drag_offset: Vector2 = Vector2.ZERO

var _visual_node: Control
var _hit_tween: Tween

var _navigation_path: PackedVector2Array = (
	PackedVector2Array()
)
var _navigation_path_index: int = 0
var _navigation_revision: int = -1
var _navigation_target: Vector2 = Vector2.INF
var _navigation_recovery_pending: bool = false


func configure(
	system_manager: SystemManager,
	window_manager: WindowManager,
	navigation_manager: Node = null
) -> void:
	_system_manager = system_manager
	_window_manager = window_manager
	_navigation_manager = navigation_manager
	invalidate_navigation_path()


func apply_runtime_stats(
	runtime_stats: EnemyRuntimeStats
) -> void:
	if runtime_stats == null:
		return

	enemy_id = runtime_stats.enemy_id
	display_name = runtime_stats.display_name

	max_health = maxf(
		0.1,
		runtime_stats.max_health
	)

	virus_data_reward = maxi(
		0,
		runtime_stats.virus_data_reward
	)

	if is_node_ready():
		_reset_health_to_max()


func prepare_for_restore(
	runtime_stats: EnemyRuntimeStats
) -> void:
	_restore_prepared = true
	apply_runtime_stats(runtime_stats)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_visual_node = (
		get_node_or_null(visual_node_path)
		as Control
	)

	if _restore_prepared:
		_current_health = max_health
	else:
		_reset_health_to_max()


func _process(delta: float) -> void:
	if _is_dead:
		return

	if _is_dragging:
		_update_dragging()
		return

	if not _try_recover_navigation_position():
		return

	_process_virus(delta)


func receive_damage(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	if _is_dead:
		return 0.0

	var previous_health: float = _current_health

	_current_health = maxf(
		_current_health - amount,
		0.0
	)

	var applied_damage: float = (
		previous_health - _current_health
	)

	if applied_damage <= 0.0:
		return 0.0

	health_changed.emit(
		_current_health,
		max_health
	)

	_play_damage_feedback()

	if _current_health <= 0.0:
		_die()

	return applied_damage


func get_current_health() -> float:
	return _current_health


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0

	return _current_health / max_health


func get_virus_data_reward() -> int:
	return maxi(
		0,
		virus_data_reward
	)


func get_visual_node() -> Control:
	return _visual_node


func is_dead() -> bool:
	return _is_dead


func is_dragging() -> bool:
	return _is_dragging


func can_receive_separation_push() -> bool:
	return (
		not _is_dead
		and not _is_dragging
	)


func get_center_global_position() -> Vector2:
	return get_global_rect().get_center()


func contains_global_point(
	global_point: Vector2
) -> bool:
	if _is_dead:
		return false

	return get_global_rect().has_point(global_point)


func apply_external_push(
	global_push_delta: Vector2
) -> void:
	if global_push_delta == Vector2.ZERO:
		return

	if not can_receive_separation_push():
		return

	var has_firewalls: bool = _has_established_firewalls()
	if not has_firewalls:
		global_position += global_push_delta
		return

	if _is_navigation_update_pending():
		return

	var current_center: Vector2 = get_center_global_position()
	var desired_center: Vector2 = (
		current_center + global_push_delta
	)
	var valid_center: Vector2 = (
		_get_closest_navigation_point(
			desired_center
		)
	)
	if not _is_navigation_segment_clear(
		current_center,
		valid_center
	):
		return

	var applied_push: Vector2 = (
		valid_center - current_center
	)
	if applied_push.length_squared() <= 0.0001:
		return

	global_position += applied_push

	if not _is_cached_navigation_path_reachable():
		invalidate_navigation_path()


func get_navigation_movement_target(
	target_global_position: Vector2
) -> Vector2:
	if _navigation_manager == null:
		return target_global_position

	if not _has_established_firewalls():
		invalidate_navigation_path()
		return target_global_position

	if bool(
		_navigation_manager.call(
			"is_navigation_update_pending"
		)
	):
		return get_center_global_position()

	var current_revision: int = (
		int(
			_navigation_manager.call(
				"get_navigation_revision"
			)
		)
	)
	var target_changed: bool = (
		_navigation_target == Vector2.INF
		or _navigation_target.distance_to(
			target_global_position
		) > 8.0
	)
	if (
		_navigation_path.is_empty()
		or _navigation_revision != current_revision
		or target_changed
	):
		_navigation_path = (
			_navigation_manager.call(
				"get_navigation_path",
				get_center_global_position(),
				target_global_position
			) as PackedVector2Array
		)
		_navigation_path_index = 0
		_navigation_revision = current_revision
		_navigation_target = target_global_position

	if _navigation_path.is_empty():
		return get_center_global_position()

	var current_center: Vector2 = get_center_global_position()
	while (
		_navigation_path_index
		< _navigation_path.size()
		and current_center.distance_to(
			_navigation_path[_navigation_path_index]
		) <= waypoint_reach_distance
	):
		var following_index: int = (
			_navigation_path_index + 1
		)
		if (
			following_index < _navigation_path.size()
			and not _is_navigation_segment_clear(
				current_center,
				_navigation_path[following_index]
			)
		):
			break
		_navigation_path_index += 1

	if _navigation_path_index >= _navigation_path.size():
		if _is_navigation_segment_clear(
			current_center,
			target_global_position
		):
			return target_global_position

		invalidate_navigation_path()
		return current_center

	var next_waypoint: Vector2 = (
		_navigation_path[_navigation_path_index]
	)
	if not _is_navigation_segment_clear(
		current_center,
		next_waypoint
	):
		invalidate_navigation_path()
		return current_center

	return next_waypoint


func create_save_snapshot() -> Dictionary:
	_set_dragging(false)

	return {
		"archetype_id": str(enemy_id),
		"position": SaveDataCodec.vector2_to_data(position),
		"current_health": _current_health,
		"runtime_stats": (
			_create_runtime_stats_snapshot()
		),
		"behavior_state": (
			_create_behavior_save_snapshot()
		)
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	var stats_variant: Variant = snapshot.get(
		"runtime_stats",
		{}
	)
	if stats_variant is Dictionary and not _restore_prepared:
		var runtime_stats: EnemyRuntimeStats = (
			EnemyRuntimeStats.from_save_snapshot(
				stats_variant as Dictionary
			)
		)
		apply_runtime_stats(runtime_stats)

	position = SaveDataCodec.data_to_vector2(
		snapshot.get("position"),
		position
	)
	_current_health = clampf(
		float(snapshot.get("current_health", max_health)),
		0.01,
		max_health
	)
	_is_dead = false
	_restore_prepared = false
	_set_dragging(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color.WHITE

	var behavior_variant: Variant = snapshot.get(
		"behavior_state",
		{}
	)
	if behavior_variant is Dictionary:
		_restore_behavior_from_save_snapshot(
			behavior_variant as Dictionary
		)

	health_changed.emit(_current_health, max_health)


func _create_runtime_stats_snapshot() -> Dictionary:
	return _create_runtime_stats().create_save_snapshot()


func _create_runtime_stats() -> EnemyRuntimeStats:
	var runtime_stats: EnemyRuntimeStats = EnemyRuntimeStats.new()
	runtime_stats.enemy_id = enemy_id
	runtime_stats.display_name = display_name
	runtime_stats.max_health = max_health
	runtime_stats.movement_speed = 0.0
	runtime_stats.attack_damage = 0.0
	runtime_stats.attack_interval_seconds = 1.0
	runtime_stats.attack_arrival_distance = 0.0
	runtime_stats.attack_overlap_distance = 0.0
	runtime_stats.virus_data_reward = virus_data_reward
	return runtime_stats


func _create_behavior_save_snapshot() -> Dictionary:
	return {}


func _restore_behavior_from_save_snapshot(
	_snapshot: Dictionary
) -> void:
	pass


func _process_virus(_delta: float) -> void:
	pass


func _before_die() -> void:
	pass


func _reset_health_to_max() -> void:
	_current_health = max_health

	health_changed.emit(
		_current_health,
		max_health
	)


func _gui_input(event: InputEvent) -> void:
	if _is_dead:
		return

	if not drag_enabled:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)


func _handle_mouse_button(
	event: InputEventMouseButton
) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_drag_offset = (
			global_position - get_global_mouse_position()
		)

		_set_dragging(true)
		accept_event()
		return

	if _is_dragging:
		_set_dragging(false)
		accept_event()


func _update_dragging() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_set_dragging(false)
		return

	var mouse_global_position: Vector2 = (
		get_global_mouse_position()
	)

	if (
		release_drag_over_windows
		and is_instance_valid(_window_manager)
		and _window_manager.is_global_point_covered_by_window(
			mouse_global_position
		)
	):
		_set_dragging(false)
		return

	global_position = _get_clamped_global_position(
		mouse_global_position + _drag_offset
	)


func _set_dragging(active: bool) -> void:
	if _is_dragging == active:
		return

	_is_dragging = active
	invalidate_navigation_path()

	if active:
		_navigation_recovery_pending = false
	else:
		_navigation_recovery_pending = (
			_has_established_firewalls()
		)
		_try_recover_navigation_position()

	dragging_changed.emit(
		self,
		_is_dragging
	)


func invalidate_navigation_path() -> void:
	_navigation_path = PackedVector2Array()
	_navigation_path_index = 0
	_navigation_revision = -1
	_navigation_target = Vector2.INF


func _has_established_firewalls() -> bool:
	return (
		_navigation_manager != null
		and bool(
			_navigation_manager.call(
				"has_established_firewalls"
			)
		)
	)


func _try_recover_navigation_position() -> bool:
	if not _navigation_recovery_pending:
		return true

	if not _has_established_firewalls():
		_navigation_recovery_pending = false
		return true

	if _is_navigation_update_pending():
		return false

	var current_center: Vector2 = get_center_global_position()
	var valid_center: Vector2 = (
		_get_closest_navigation_point(
			current_center
		)
	)
	var recovery_delta: Vector2 = (
		valid_center - current_center
	)
	if recovery_delta.length_squared() > 0.0001:
		global_position += recovery_delta

	_navigation_recovery_pending = false
	invalidate_navigation_path()
	return true


func _is_navigation_update_pending() -> bool:
	if _navigation_manager == null:
		return false

	if not _navigation_manager.has_method(
		"is_navigation_update_pending"
	):
		return false

	return bool(
		_navigation_manager.call(
			"is_navigation_update_pending"
		)
	)


func _get_closest_navigation_point(
	global_point: Vector2
) -> Vector2:
	if _navigation_manager == null:
		return global_point

	if not _navigation_manager.has_method(
		"get_closest_navigation_point"
	):
		return global_point

	return (
		_navigation_manager.call(
			"get_closest_navigation_point",
			global_point
		) as Vector2
	)


func _is_cached_navigation_path_reachable() -> bool:
	if _navigation_path.is_empty():
		return true

	if _navigation_path_index >= _navigation_path.size():
		return true

	return _is_navigation_segment_clear(
		get_center_global_position(),
		_navigation_path[_navigation_path_index]
	)


func _is_navigation_segment_clear(
	from_global_position: Vector2,
	to_global_position: Vector2
) -> bool:
	if _navigation_manager == null:
		return true

	if not _navigation_manager.has_method(
		"is_navigation_segment_clear"
	):
		return true

	return bool(
		_navigation_manager.call(
			"is_navigation_segment_clear",
			from_global_position,
			to_global_position
		)
	)


func _get_clamped_global_position(
	desired_global_position: Vector2
) -> Vector2:
	var parent_control: Control = get_parent() as Control

	if parent_control == null:
		return desired_global_position

	var parent_rect: Rect2 = parent_control.get_global_rect()
	var maximum_position: Vector2 = parent_rect.end - _get_effective_size()

	return Vector2(
		clampf(
			desired_global_position.x,
			parent_rect.position.x,
			maximum_position.x
		),
		clampf(
			desired_global_position.y,
			parent_rect.position.y,
			maximum_position.y
		)
	)


func _get_effective_size() -> Vector2:
	if size != Vector2.ZERO:
		return size

	if custom_minimum_size != Vector2.ZERO:
		return custom_minimum_size

	return Vector2(48.0, 48.0)


func _play_damage_feedback() -> void:
	if _hit_tween != null and _hit_tween.is_running():
		_hit_tween.kill()

	modulate = Color.WHITE

	_hit_tween = create_tween()

	_hit_tween.tween_property(
		self,
		"modulate",
		Color(1.0, 0.35, 0.35, 1.0),
		0.04
	)

	_hit_tween.tween_property(
		self,
		"modulate",
		Color.WHITE,
		0.08
	)


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_before_die()

	if _hit_tween != null and _hit_tween.is_running():
		_hit_tween.kill()

	died.emit(self)
	queue_free()
