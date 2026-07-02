extends Node
class_name TaskbarManager

@export var window_manager: WindowManager
@export var taskbar: Taskbar
@export var taskbar_app_button_scene: PackedScene

var _buttons_by_window_id: Dictionary = {}
var _focused_window: AppWindow = null

var _layout_refresh_queued: bool = false
var _initialized: bool = false


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	if _initialized:
		return

	_resolve_references()

	if not _validate_dependencies():
		return

	var app_button_area: HBoxContainer = (
		_get_app_button_area()
	)

	if app_button_area == null:
		push_error(
			"TaskbarManager could not access AppButtonArea "
			+ "through Taskbar."
		)
		return

	_initialized = true

	window_manager.window_opened.connect(
		_on_window_opened
	)

	window_manager.window_closed.connect(
		_on_window_closed
	)

	window_manager.window_focused.connect(
		_on_window_focused
	)

	app_button_area.resized.connect(
		_queue_layout_refresh
	)

	_register_existing_windows()
	_queue_layout_refresh()


func _resolve_references() -> void:
	if window_manager == null:
		window_manager = (
			get_node_or_null("../WindowManager")
			as WindowManager
		)

	if taskbar == null:
		taskbar = (
			get_node_or_null("../StatusLayer/Taskbar")
			as Taskbar
		)


func _validate_dependencies() -> bool:
	if window_manager == null:
		push_error(
			"TaskbarManager requires a WindowManager reference."
		)
		return false

	if taskbar == null:
		push_error(
			"TaskbarManager requires a Taskbar reference."
		)
		return false

	if taskbar_app_button_scene == null:
		push_error(
			"TaskbarManager requires a TaskbarAppButton scene."
		)
		return false

	return true


func _get_app_button_area() -> HBoxContainer:
	if taskbar == null:
		return null

	return taskbar.get_app_button_area()


func _on_window_opened(
	window: AppWindow,
	program_data: ProgramData
) -> void:
	if not _is_taskbar_eligible_window(window):
		return

	_create_taskbar_button(
		window,
		program_data
	)

	_set_active_window(window)


func _on_window_closed(window: AppWindow) -> void:
	_remove_taskbar_button(window)

	if _focused_window == window:
		_focused_window = null
		_refresh_active_button_states()


func _on_window_focused(window: AppWindow) -> void:
	if not _has_taskbar_button(window):
		return

	_set_active_window(window)


func _on_taskbar_button_focus_requested(
	window: AppWindow
) -> void:
	if not is_instance_valid(window):
		return

	window_manager.focus_window(window)


func _on_taskbar_button_drag_started(
	_button: TaskbarAppButton
) -> void:
	pass


func _on_taskbar_button_drag_moved(
	button: TaskbarAppButton,
	global_mouse_position: Vector2
) -> void:
	_reorder_button_at_global_position(
		button,
		global_mouse_position
	)


func _on_taskbar_button_drag_ended(
	button: TaskbarAppButton,
	global_mouse_position: Vector2
) -> void:
	_reorder_button_at_global_position(
		button,
		global_mouse_position
	)

	_queue_layout_refresh()


func _create_taskbar_button(
	window: AppWindow,
	program_data: ProgramData
) -> void:
	if _has_taskbar_button(window):
		return

	var app_button_area: HBoxContainer = (
		_get_app_button_area()
	)

	if app_button_area == null:
		return

	var taskbar_button: TaskbarAppButton = (
		taskbar_app_button_scene.instantiate()
		as TaskbarAppButton
	)

	if taskbar_button == null:
		push_error(
			"TaskbarAppButton scene must inherit "
			+ "from TaskbarAppButton."
		)
		return

	app_button_area.add_child(taskbar_button)

	taskbar_button.bind_window(
		window,
		program_data
	)

	taskbar_button.focus_requested.connect(
		_on_taskbar_button_focus_requested
	)

	taskbar_button.reorder_drag_started.connect(
		_on_taskbar_button_drag_started
	)

	taskbar_button.reorder_drag_moved.connect(
		_on_taskbar_button_drag_moved
	)

	taskbar_button.reorder_drag_ended.connect(
		_on_taskbar_button_drag_ended
	)

	_buttons_by_window_id[
		window.get_instance_id()
	] = taskbar_button

	_queue_layout_refresh()


func _remove_taskbar_button(window: AppWindow) -> void:
	var taskbar_button: TaskbarAppButton = (
		_get_taskbar_button(window)
	)

	if taskbar_button != null:
		var app_button_area: HBoxContainer = (
			_get_app_button_area()
		)

		if taskbar_button.get_parent() == app_button_area:
			app_button_area.remove_child(taskbar_button)

		taskbar_button.queue_free()

	_buttons_by_window_id.erase(
		window.get_instance_id()
	)

	_queue_layout_refresh()


func _set_active_window(window: AppWindow) -> void:
	_focused_window = window
	_refresh_active_button_states()


func _refresh_active_button_states() -> void:
	var invalid_keys: Array = []

	for key in _buttons_by_window_id.keys():
		var taskbar_button: TaskbarAppButton = (
			_buttons_by_window_id[key]
			as TaskbarAppButton
		)

		if not is_instance_valid(taskbar_button):
			invalid_keys.append(key)
			continue

		var is_active: bool = (
			taskbar_button.get_bound_window()
			== _focused_window
		)

		taskbar_button.set_active(is_active)

	for invalid_key in invalid_keys:
		_buttons_by_window_id.erase(invalid_key)


func _reorder_button_at_global_position(
	dragged_button: TaskbarAppButton,
	global_mouse_position: Vector2
) -> void:
	var app_button_area: HBoxContainer = (
		_get_app_button_area()
	)

	if app_button_area == null:
		return

	var target_index: int = (
		_get_insertion_index(
			dragged_button,
			global_mouse_position.x
		)
	)

	if dragged_button.get_index() == target_index:
		return

	app_button_area.move_child(
		dragged_button,
		target_index
	)


func _get_insertion_index(
	dragged_button: TaskbarAppButton,
	global_mouse_x: float
) -> int:
	var buttons: Array = _get_taskbar_buttons()
	var insertion_index: int = 0

	for button_variant in buttons:
		var candidate: TaskbarAppButton = (
			button_variant as TaskbarAppButton
		)

		if candidate == null:
			continue

		if candidate == dragged_button:
			continue

		var candidate_center_x: float = (
			candidate.get_global_rect().get_center().x
		)

		if global_mouse_x < candidate_center_x:
			return insertion_index

		insertion_index += 1

	return insertion_index


func _queue_layout_refresh() -> void:
	if _layout_refresh_queued:
		return

	_layout_refresh_queued = true

	call_deferred("_refresh_taskbar_button_layout")


func _refresh_taskbar_button_layout() -> void:
	_layout_refresh_queued = false

	var app_button_area: HBoxContainer = (
		_get_app_button_area()
	)

	if app_button_area == null:
		return

	var buttons: Array = _get_taskbar_buttons()
	var button_count: int = buttons.size()

	if button_count <= 0:
		return

	var first_button: TaskbarAppButton = (
		buttons[0] as TaskbarAppButton
	)

	if first_button == null:
		return

	var minimum_width: float = (
		first_button.minimum_taskbar_width
	)

	var maximum_width: float = (
		first_button.maximum_taskbar_width
	)

	var spacing: float = float(
		app_button_area.get_theme_constant("separation")
	)

	var total_spacing: float = (
		spacing * float(maxi(0, button_count - 1))
	)

	var available_width: float = maxf(
		0.0,
		app_button_area.size.x - total_spacing
	)

	var desired_width: float = (
		available_width / float(button_count)
	)

	var final_width: float = clampf(
		desired_width,
		minimum_width,
		maximum_width
	)

	for button_variant in buttons:
		var button: TaskbarAppButton = (
			button_variant as TaskbarAppButton
		)

		if button == null:
			continue

		button.apply_layout_width(final_width)


func _get_taskbar_buttons() -> Array:
	var buttons: Array = []

	var app_button_area: HBoxContainer = (
		_get_app_button_area()
	)

	if app_button_area == null:
		return buttons

	for child: Node in app_button_area.get_children():
		var taskbar_button: TaskbarAppButton = (
			child as TaskbarAppButton
		)

		if taskbar_button == null:
			continue

		buttons.append(taskbar_button)

	return buttons


func _has_taskbar_button(
	window: AppWindow
) -> bool:
	return _get_taskbar_button(window) != null


func _get_taskbar_button(
	window: AppWindow
) -> TaskbarAppButton:
	if window == null:
		return null

	var window_id: int = window.get_instance_id()

	if not _buttons_by_window_id.has(window_id):
		return null

	var taskbar_button: TaskbarAppButton = (
		_buttons_by_window_id[window_id]
		as TaskbarAppButton
	)

	if not is_instance_valid(taskbar_button):
		_buttons_by_window_id.erase(window_id)
		return null

	return taskbar_button


func _is_taskbar_eligible_window(
	window: AppWindow
) -> bool:
	if window == null:
		return false

	# Los errores del sistema no tienen program_id.
	if window.program_id == StringName():
		return false

	return true


func _register_existing_windows() -> void:
	if window_manager.window_layer == null:
		return

	var highest_window: AppWindow = null
	var highest_z_index: int = -2147483648

	for child: Node in window_manager.window_layer.get_children():
		var window: AppWindow = child as AppWindow

		if not _is_taskbar_eligible_window(window):
			continue

		_create_taskbar_button(
			window,
			null
		)

		if window.z_index > highest_z_index:
			highest_z_index = window.z_index
			highest_window = window

	if highest_window != null:
		_set_active_window(highest_window)
