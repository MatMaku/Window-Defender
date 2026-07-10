extends Control
class_name BasicVirus

signal health_changed(
	current_health: float,
	max_health: float
)

signal died(virus: BasicVirus)

signal dragging_changed(
	virus: BasicVirus,
	is_dragging: bool
)

@export_category("Stats")

@export_range(0.1, 999.0, 0.1)
var max_health: float = 2.0

@export_range(0.0, 1000.0, 0.1)
var movement_speed: float = 48.0

@export_range(0.01, 999.0, 0.01)
var attack_damage: float = 0.5

@export_range(0.05, 10.0, 0.05)
var attack_interval_seconds: float = 1.25

@export_range(0.0, 10.0, 0.1)
var attack_arrival_distance: float = 0.75

@export_range(0.0, 40.0, 0.5)
var attack_overlap_distance: float = 12.0

@export_category("Dragging")

@export var drag_enabled: bool = true
@export var release_drag_over_windows: bool = true

@export_category("Attack Feedback")

@export_range(0.01, 1.0, 0.01)
var attack_shake_duration: float = 0.10

@export_range(0.0, 20.0, 0.5)
var attack_shake_distance: float = 3.0

@onready var virus_texture: TextureRect = $VirusTexture

var _system_manager: SystemManager
var _window_manager: WindowManager

var _current_health: float = 0.0
var _attack_cooldown_remaining: float = 0.0

var _is_dragging: bool = false
var _is_dead: bool = false

var _drag_offset: Vector2 = Vector2.ZERO
var _visual_rest_position: Vector2 = Vector2.ZERO

var _hit_tween: Tween
var _attack_tween: Tween


func configure(
	system_manager: SystemManager,
	window_manager: WindowManager
) -> void:
	_system_manager = system_manager
	_window_manager = window_manager


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_current_health = max_health

	if virus_texture != null:
		_visual_rest_position = virus_texture.position

	health_changed.emit(
		_current_health,
		max_health
	)


func _process(delta: float) -> void:
	if _is_dead:
		return

	if _is_dragging:
		_update_dragging()
		return

	if not is_instance_valid(_system_manager):
		return

	_update_movement_and_attack(delta)


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
	var maximum_position: Vector2 = parent_rect.end - size

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


func _play_attack_feedback() -> void:
	if virus_texture == null:
		return

	if _attack_tween != null and _attack_tween.is_running():
		_attack_tween.kill()

	virus_texture.position = _visual_rest_position

	var segment_duration: float = (
		attack_shake_duration / 4.0
	)

	_attack_tween = create_tween()

	_attack_tween.tween_property(
		virus_texture,
		"position",
		_visual_rest_position + Vector2(
			attack_shake_distance,
			0.0
		),
		segment_duration
	)

	_attack_tween.tween_property(
		virus_texture,
		"position",
		_visual_rest_position + Vector2(
			-attack_shake_distance,
			0.0
		),
		segment_duration
	)

	_attack_tween.tween_property(
		virus_texture,
		"position",
		_visual_rest_position + Vector2(
			attack_shake_distance * 0.4,
			0.0
		),
		segment_duration
	)

	_attack_tween.tween_property(
		virus_texture,
		"position",
		_visual_rest_position,
		segment_duration
	)


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _attack_tween != null and _attack_tween.is_running():
		_attack_tween.kill()

	if _hit_tween != null and _hit_tween.is_running():
		_hit_tween.kill()

	died.emit(self)
	queue_free()
