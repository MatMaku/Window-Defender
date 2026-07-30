extends Control
class_name DesktopExecutable

signal open_requested(program_data: ProgramData)
signal moved(new_position: Vector2)

@export var program_data: ProgramData:
	set(value):
		program_data = value
		_refresh_visuals()

@export var drag_enabled: bool = true

@export_range(0.0, 64.0, 0.5)
var drag_threshold: float = 6.0

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel

var _is_pressed: bool = false
var _is_dragging: bool = false

var _press_global_position: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO
var _window_manager: WindowManager


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_visuals()


func get_program_id() -> StringName:
	if program_data == null:
		return StringName()

	return program_data.program_id


func force_position(new_position: Vector2) -> void:
	position = new_position

	moved.emit(position)


func configure_window_manager(
	window_manager: WindowManager
) -> void:
	_window_manager = window_manager


func cancel_drag_for_save() -> void:
	_is_pressed = false
	_is_dragging = false
	_press_global_position = Vector2.ZERO
	_drag_offset = Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(
	event: InputEventMouseButton
) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_handle_left_button_pressed(event)
		return

	_handle_left_button_released()


func _handle_left_button_pressed(
	event: InputEventMouseButton
) -> void:
	if event.double_click:
		_request_open()
		accept_event()
		return

	_is_pressed = true
	_is_dragging = false

	_press_global_position = get_global_mouse_position()
	_drag_offset = global_position - _press_global_position

	accept_event()


func _handle_left_button_released() -> void:
	if _is_dragging:
		moved.emit(position)

	_is_pressed = false
	_is_dragging = false

	accept_event()


func _handle_mouse_motion(
	_event: InputEventMouseMotion
) -> void:
	if not _is_pressed:
		return

	if not drag_enabled:
		return

	var mouse_global_position: Vector2 = (
		get_global_mouse_position()
	)

	if not _is_dragging:
		var distance_from_press: float = (
			_press_global_position.distance_to(
				mouse_global_position
			)
		)

		if distance_from_press < drag_threshold:
			return

		_is_dragging = true

	if (
		is_instance_valid(_window_manager)
		and _window_manager.is_global_point_covered_by_window(
			mouse_global_position
		)
	):
		_finish_drag(true)
		accept_event()
		return

	global_position = _get_clamped_global_position(
		mouse_global_position + _drag_offset
	)

	accept_event()


func _request_open() -> void:
	if program_data == null:
		push_warning(
			"DesktopExecutable has no ProgramData assigned."
		)
		return

	open_requested.emit(program_data)


func _finish_drag(emit_moved: bool) -> void:
	if emit_moved and _is_dragging:
		moved.emit(position)

	_is_pressed = false
	_is_dragging = false
	_press_global_position = Vector2.ZERO
	_drag_offset = Vector2.ZERO


func _refresh_visuals() -> void:
	if not is_node_ready():
		return

	if program_data == null:
		icon_texture.texture = null
		name_label.text = "missing.exe"
		return

	icon_texture.texture = program_data.icon
	name_label.text = program_data.display_name


func _get_clamped_global_position(
	desired_global_position: Vector2
) -> Vector2:
	var parent_control: Control = get_parent() as Control

	if parent_control == null:
		return desired_global_position

	var parent_rect: Rect2 = parent_control.get_global_rect()
	var executable_size: Vector2 = _get_effective_size()

	var maximum_position: Vector2 = (
		parent_rect.end - executable_size
	)

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

	return Vector2(64.0, 72.0)
