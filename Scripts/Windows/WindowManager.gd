extends Node
class_name WindowManager

@export var window_layer: Control

var _z_index_counter: int = 100
var _single_instance_windows: Dictionary = {}


func open_program(program_data: ProgramData) -> AppWindow:
	if program_data == null:
		push_warning("Cannot open null ProgramData.")
		return null

	if program_data.window_scene == null:
		push_warning("Program '%s' has no window scene assigned." % program_data.display_name)
		return null

	if not program_data.allow_multiple_instances:
		var existing_window := _get_existing_single_instance_window(program_data.program_id)

		if existing_window != null:
			focus_window(existing_window)
			return existing_window

	var window := program_data.window_scene.instantiate() as AppWindow

	if window == null:
		push_error("Window scene for '%s' must inherit from AppWindow." % program_data.display_name)
		return null

	window_layer.add_child(window)

	window.setup(program_data)
	window.position = program_data.default_window_position

	window.focus_requested.connect(focus_window)
	window.close_requested.connect(close_window)

	_register_window(program_data, window)
	focus_window(window)

	return window


func focus_window(window: AppWindow) -> void:
	if window == null:
		return

	_z_index_counter += 1
	window.z_index = _z_index_counter

	if window.get_parent() == window_layer:
		window_layer.move_child(window, window_layer.get_child_count() - 1)


func close_window(window: AppWindow) -> void:
	if window == null:
		return

	_unregister_window(window)
	window.queue_free()


func _register_window(program_data: ProgramData, window: AppWindow) -> void:
	if not program_data.allow_multiple_instances:
		_single_instance_windows[program_data.program_id] = window


func _unregister_window(window: AppWindow) -> void:
	if window.program_id == StringName():
		return

	if not _single_instance_windows.has(window.program_id):
		return

	if _single_instance_windows[window.program_id] == window:
		_single_instance_windows.erase(window.program_id)


func _get_existing_single_instance_window(program_id: StringName) -> AppWindow:
	if not _single_instance_windows.has(program_id):
		return null

	var window := _single_instance_windows[program_id] as AppWindow

	if not is_instance_valid(window):
		_single_instance_windows.erase(program_id)
		return null

	return window
