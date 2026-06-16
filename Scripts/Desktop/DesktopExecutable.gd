extends Control
class_name DesktopExecutable

signal open_requested(program_data: ProgramData)
signal moved(new_position: Vector2)

@export var program_data: ProgramData:
	set(value):
		program_data = value
		_refresh_visuals()

@export var drag_enabled: bool = true
@export var drag_threshold: float = 6.0

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel

var _is_pressed: bool = false
var _is_dragging: bool = false
var _press_global_position: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_visuals()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		if event.double_click:
			_request_open()
			accept_event()
			return

		_is_pressed = true
		_is_dragging = false
		_press_global_position = get_global_mouse_position()
		_drag_offset = global_position - _press_global_position
		accept_event()
	else:
		if _is_dragging:
			moved.emit(position)

		_is_pressed = false
		_is_dragging = false
		accept_event()


func _handle_mouse_motion(_event: InputEventMouseMotion) -> void:
	if not _is_pressed:
		return

	if not drag_enabled:
		return

	var mouse_position := get_global_mouse_position()

	if not _is_dragging:
		var distance := _press_global_position.distance_to(mouse_position)
		if distance < drag_threshold:
			return

		_is_dragging = true

	global_position = _get_clamped_global_position(mouse_position + _drag_offset)
	accept_event()


func _request_open() -> void:
	if program_data == null:
		push_warning("DesktopExecutable has no ProgramData assigned.")
		return

	open_requested.emit(program_data)


func _refresh_visuals() -> void:
	if not is_node_ready():
		return

	if program_data == null:
		icon_texture.texture = null
		name_label.text = "missing.exe"
		return

	icon_texture.texture = program_data.icon
	name_label.text = program_data.display_name


func _get_clamped_global_position(desired_global_position: Vector2) -> Vector2:
	var parent_control := get_parent() as Control

	if parent_control == null:
		return desired_global_position

	var parent_rect := parent_control.get_global_rect()
	var max_position := parent_rect.end - size

	return Vector2(
		clamp(desired_global_position.x, parent_rect.position.x, max_position.x),
		clamp(desired_global_position.y, parent_rect.position.y, max_position.y)
	)
