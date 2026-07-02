extends Button
class_name TaskbarAppButton

signal focus_requested(window: AppWindow)

signal reorder_drag_started(button: TaskbarAppButton)

signal reorder_drag_moved(
	button: TaskbarAppButton,
	global_mouse_position: Vector2
)

signal reorder_drag_ended(
	button: TaskbarAppButton,
	global_mouse_position: Vector2
)

@export_category("Taskbar Size")

@export_range(1.0, 1000.0, 1.0)
var minimum_taskbar_width: float = 50.0

@export_range(1.0, 1000.0, 1.0)
var maximum_taskbar_width: float = 150.0

@export_range(1.0, 100.0, 1.0)
var taskbar_height: float = 28.0

@export_category("Reorder Drag")

@export_range(1.0, 30.0, 1.0)
var drag_threshold: float = 6.0

var _bound_window: AppWindow

var _pointer_down: bool = false
var _is_dragging: bool = false

var _press_global_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	toggle_mode = true
	clip_text = true

	mouse_filter = Control.MOUSE_FILTER_STOP

	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	apply_layout_width(minimum_taskbar_width)


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


func bind_window(
	window: AppWindow,
	program_data: ProgramData
) -> void:
	_bound_window = window

	if program_data != null:
		text = program_data.display_name
		icon = program_data.icon
	else:
		text = window.title_label.text
		icon = window.window_icon.texture

	tooltip_text = text


func get_bound_window() -> AppWindow:
	return _bound_window


func set_active(active: bool) -> void:
	if button_pressed == active:
		return

	set_pressed_no_signal(active)


func apply_layout_width(target_width: float) -> void:
	var safe_width: float = clampf(
		target_width,
		minimum_taskbar_width,
		maximum_taskbar_width
	)

	custom_minimum_size = Vector2(
		safe_width,
		taskbar_height
	)


func _gui_input(event: InputEvent) -> void:
	var mouse_button: InputEventMouseButton = (
		event as InputEventMouseButton
	)

	if mouse_button == null:
		return

	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mouse_button.pressed:
		return

	_pointer_down = true
	_is_dragging = false

	_press_global_position = get_global_mouse_position()

	accept_event()


func _input(event: InputEvent) -> void:
	if not _pointer_down:
		return

	var mouse_motion: InputEventMouseMotion = (
		event as InputEventMouseMotion
	)

	if mouse_motion != null:
		_handle_mouse_motion()
		return

	var mouse_button: InputEventMouseButton = (
		event as InputEventMouseButton
	)

	if mouse_button == null:
		return

	if mouse_button.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_button.pressed:
		return

	_finish_pointer_interaction()


func _handle_mouse_motion() -> void:
	var current_global_position: Vector2 = (
		get_global_mouse_position()
	)

	if not _is_dragging:
		var distance_from_press: float = (
			_press_global_position.distance_to(
				current_global_position
			)
		)

		if distance_from_press < drag_threshold:
			return

		_is_dragging = true

		modulate = Color(
			1.0,
			1.0,
			1.0,
			0.60
		)

		reorder_drag_started.emit(self)

	reorder_drag_moved.emit(
		self,
		current_global_position
	)

	get_viewport().set_input_as_handled()


func _finish_pointer_interaction() -> void:
	var release_global_position: Vector2 = (
		get_global_mouse_position()
	)

	_pointer_down = false

	if _is_dragging:
		_is_dragging = false
		modulate = Color.WHITE

		reorder_drag_ended.emit(
			self,
			release_global_position
		)

		get_viewport().set_input_as_handled()
		return

	if not is_instance_valid(_bound_window):
		queue_free()
		return

	focus_requested.emit(_bound_window)

	get_viewport().set_input_as_handled()
