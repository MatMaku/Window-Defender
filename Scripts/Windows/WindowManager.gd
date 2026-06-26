extends Node
class_name WindowManager

signal window_opened(
	window: AppWindow,
	program_data: ProgramData
)

signal window_closed(window: AppWindow)

@export var window_layer: Control

var _z_index_counter: int = 100
var _single_instance_windows: Dictionary[StringName, AppWindow] = {}


func open_program(program_data: ProgramData) -> AppWindow:
	if program_data == null:
		push_warning("Cannot open null ProgramData.")
		return null

	if program_data.window_scene == null:
		push_warning(
			"Program '%s' has no window scene assigned."
			% program_data.display_name
		)
		return null

	if not program_data.allow_multiple_instances:
		var existing_window: AppWindow = (
			_get_existing_single_instance_window(
				program_data.program_id
			)
		)

		if existing_window != null:
			focus_window(existing_window)
			return existing_window

	var window: AppWindow = (
		program_data.window_scene.instantiate() as AppWindow
	)

	if window == null:
		push_error(
			"Window scene for '%s' must inherit from AppWindow."
			% program_data.display_name
		)
		return null

	window_layer.add_child(window)

	window.setup(program_data)
	window.position = _get_centered_position(window)

	window.focus_requested.connect(focus_window)
	window.close_requested.connect(close_window)

	_register_window(program_data, window)
	focus_window(window)

	window.play_open_animation()

	window_opened.emit(
		window,
		program_data
	)

	return window


func focus_window(window: AppWindow) -> void:
	if window == null:
		return

	_z_index_counter += 1
	window.z_index = _z_index_counter

	if window.get_parent() == window_layer:
		window_layer.move_child(
			window,
			window_layer.get_child_count() - 1
		)


func close_window(window: AppWindow) -> void:
	if window == null:
		return

	window_closed.emit(window)

	_unregister_window(window)
	window.queue_free()


func get_windows_above(
	reference_window: AppWindow
) -> Array[AppWindow]:
	var windows_above: Array[AppWindow] = []

	if window_layer == null:
		return windows_above

	for child: Node in window_layer.get_children():
		var candidate: AppWindow = child as AppWindow

		if candidate == null:
			continue

		if candidate == reference_window:
			continue

		if not candidate.is_visible_in_tree():
			continue

		if _is_window_above(candidate, reference_window):
			windows_above.append(candidate)

	return windows_above


func _get_centered_position(window: AppWindow) -> Vector2:
	if window_layer == null:
		return Vector2.ZERO

	var layer_size: Vector2 = window_layer.size
	var window_size: Vector2 = window.size

	if window_size == Vector2.ZERO:
		window_size = window.custom_minimum_size

	return (layer_size - window_size) * 0.5


func _register_window(
	program_data: ProgramData,
	window: AppWindow
) -> void:
	if program_data.allow_multiple_instances:
		return

	_single_instance_windows[
		program_data.program_id
	] = window


func _unregister_window(window: AppWindow) -> void:
	if window.program_id == StringName():
		return

	if not _single_instance_windows.has(window.program_id):
		return

	if _single_instance_windows[window.program_id] == window:
		_single_instance_windows.erase(window.program_id)


func _get_existing_single_instance_window(
	program_id: StringName
) -> AppWindow:
	if not _single_instance_windows.has(program_id):
		return null

	var window: AppWindow = _single_instance_windows[program_id]

	if not is_instance_valid(window):
		_single_instance_windows.erase(program_id)
		return null

	return window


func _is_window_above(
	candidate: AppWindow,
	reference_window: AppWindow
) -> bool:
	if candidate.z_index != reference_window.z_index:
		return candidate.z_index > reference_window.z_index

	return candidate.get_index() > reference_window.get_index()
