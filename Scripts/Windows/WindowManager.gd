extends Node
class_name WindowManager

signal window_opened(
	window: AppWindow,
	program_data: ProgramData
)

signal window_closed(window: AppWindow)

signal window_focused(window: AppWindow)

@export var window_layer: Control
@export var ram_manager: RamManager
@export var system_error_window_scene: PackedScene

var _z_index_counter: int = 100

var _single_instance_windows: Dictionary = {}
var _error_window: SystemErrorWindow


func _ready() -> void:
	if window_layer == null:
		window_layer = (
			get_node_or_null("../WindowLayer")
			as Control
		)

	if ram_manager == null:
		ram_manager = (
			get_node_or_null("../RamManager")
			as RamManager
		)

	if window_layer == null:
		push_error(
			"WindowManager could not find WindowLayer."
		)

	if ram_manager == null:
		push_error(
			"WindowManager could not find RamManager."
		)


func _exit_tree() -> void:
	if window_layer == null:
		return

	if ram_manager == null:
		return

	for child: Node in window_layer.get_children():
		var window: AppWindow = child as AppWindow

		if window == null:
			continue

		_release_ram_for_window(window)


func open_program(
	program_data: ProgramData
) -> AppWindow:
	if window_layer == null:
		push_error(
			"Cannot open program: WindowLayer is not assigned."
		)
		return null

	if ram_manager == null:
		push_error(
			"Cannot open program: RamManager is not assigned."
		)
		return null

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

	var ram_cost: int = maxi(
		0,
		program_data.ram_cost
	)

	if not ram_manager.can_reserve_ram(ram_cost):
		_show_insufficient_ram_error(program_data)
		return null

	var open_duration_multiplier: float = (
		ram_manager.get_open_duration_multiplier_for_cost(
			ram_cost
		)
	)

	if not ram_manager.reserve_ram(ram_cost):
		_show_insufficient_ram_error(program_data)
		return null

	var window: AppWindow = (
		program_data.window_scene.instantiate()
		as AppWindow
	)

	if window == null:
		ram_manager.release_ram(ram_cost)

		push_error(
			"Window scene for '%s' must inherit from AppWindow."
			% program_data.display_name
		)
		return null

	window_layer.add_child(window)

	window.allocated_ram = ram_cost
	window.setup(program_data)
	window.position = _get_centered_position(window)

	window.focus_requested.connect(focus_window)
	window.close_requested.connect(close_window)

	_register_window(program_data, window)
	focus_window(window)

	window.play_open_animation(
		open_duration_multiplier
	)

	window_opened.emit(
		window,
		program_data
	)

	return window


func show_system_error(
	error_title: String,
	error_message: String
) -> void:
	if system_error_window_scene == null:
		push_error(
			"WindowManager requires SystemErrorWindow scene."
		)
		return

	if is_instance_valid(_error_window):
		_error_window.present_error(
			error_title,
			error_message
		)

		focus_window(_error_window)
		return

	var error_window: SystemErrorWindow = (
		system_error_window_scene.instantiate()
		as SystemErrorWindow
	)

	if error_window == null:
		push_error(
			"System error window scene must inherit "
			+ "from SystemErrorWindow."
		)
		return

	window_layer.add_child(error_window)

	_error_window = error_window

	error_window.position = _get_centered_position(
		error_window
	)

	error_window.focus_requested.connect(focus_window)
	error_window.close_requested.connect(close_window)

	error_window.present_error(
		error_title,
		error_message
	)

	focus_window(error_window)
	error_window.play_open_animation()


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
	window_focused.emit(window)


func close_window(window: AppWindow) -> void:
	if window == null:
		return

	if window == _error_window:
		_error_window = null

	_unregister_window(window)
	_release_ram_for_window(window)

	window_closed.emit(window)
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

		if _is_window_above(
			candidate,
			reference_window
		):
			windows_above.append(candidate)

	return windows_above


func is_global_point_covered_by_window(
	global_point: Vector2
) -> bool:
	if window_layer == null:
		return false

	for child: Node in window_layer.get_children():
		var window: AppWindow = child as AppWindow

		if window == null:
			continue

		if not window.is_visible_in_tree():
			continue

		if window.get_global_rect().has_point(global_point):
			return true

	return false


func _show_insufficient_ram_error(
	program_data: ProgramData
) -> void:
	var required_ram: int = maxi(
		0,
		program_data.ram_cost
	)

	var available_ram: int = GameState.get_available_ram()

	var error_message: String = (
		"NOT ENOUGH RAM TO OPEN:\n\n"
		+ "%s\n\n"
		+ "REQUIRED: %d RAM\n"
		+ "AVAILABLE: %d RAM\n\n"
		+ "TRY CLOSING PROGRAMS"
	) % [
		program_data.display_name.to_upper(),
		required_ram,
		available_ram
	]

	show_system_error(
		"SYSTEM ERROR",
		error_message
	)


func _get_centered_position(
	window: AppWindow
) -> Vector2:
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

	if not _single_instance_windows.has(
		window.program_id
	):
		return

	var registered_window: AppWindow = (
		_single_instance_windows[
			window.program_id
		]
		as AppWindow
	)

	if registered_window == window:
		_single_instance_windows.erase(
			window.program_id
		)


func _release_ram_for_window(
	window: AppWindow
) -> void:
	if ram_manager == null:
		return

	var ram_cost: int = window.allocated_ram

	if ram_cost <= 0:
		return

	ram_manager.release_ram(ram_cost)
	window.allocated_ram = 0


func _get_existing_single_instance_window(
	program_id: StringName
) -> AppWindow:
	if not _single_instance_windows.has(program_id):
		return null

	var window: AppWindow = (
		_single_instance_windows[program_id]
		as AppWindow
	)

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
