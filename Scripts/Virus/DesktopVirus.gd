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

@export_category("Visual")

@export var visual_node_path: NodePath = ^"VirusTexture"

var _system_manager: SystemManager
var _window_manager: WindowManager

var _current_health: float = 0.0

var _is_dragging: bool = false
var _is_dead: bool = false

var _drag_offset: Vector2 = Vector2.ZERO

var _visual_node: Control
var _hit_tween: Tween


func configure(
	system_manager: SystemManager,
	window_manager: WindowManager
) -> void:
	_system_manager = system_manager
	_window_manager = window_manager


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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_visual_node = (
		get_node_or_null(visual_node_path)
		as Control
	)

	_reset_health_to_max()


func _process(delta: float) -> void:
	if _is_dead:
		return

	if _is_dragging:
		_update_dragging()
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

	global_position += global_push_delta


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

	dragging_changed.emit(
		self,
		_is_dragging
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
