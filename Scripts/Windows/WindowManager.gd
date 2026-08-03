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
@export var enemy_manager: EnemyManager
@export var system_error_window_scene: PackedScene

var _z_index_counter: int = 100
var _desktop_band_z_index_counter: int = 0

var _single_instance_windows: Dictionary = {}
var _error_window: SystemErrorWindow
var _windows_pending_restore_reveal: Array[AppWindow] = []


func _ready() -> void:
	_resolve_references()
	_validate_dependencies()


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
	if not _can_open_program_request(program_data):
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
		_instantiate_app_window(program_data)
	)

	if window == null:
		ram_manager.release_ram(ram_cost)
		return null

	window_layer.add_child(window)

	window.allocated_ram = ram_cost

	window.setup(program_data)
	window.position = _get_centered_position(window)

	window.focus_requested.connect(focus_window)
	window.close_requested.connect(close_window)

	_register_window(
		program_data,
		window
	)

	focus_window(window)

	window.play_open_animation(
		open_duration_multiplier
	)

	window_opened.emit(
		window,
		program_data
	)

	return window


func create_windows_save_snapshot() -> Array[Dictionary]:
	var sorted_windows: Array[AppWindow] = _get_app_windows()
	sorted_windows.sort_custom(_sort_windows_by_z_order)

	var snapshot: Array[Dictionary] = []
	for window: AppWindow in sorted_windows:
		window.cancel_drag_for_save()
		snapshot.append({
			"program_id": str(window.program_id),
			"position": SaveDataCodec.vector2_to_data(
				window.position
			),
			"z_order": window.z_index,
			"app_state": (
				window.create_save_snapshot().duplicate(true)
			)
		})

	return snapshot


func clear_windows_for_restore() -> void:
	if window_layer == null:
		return

	for child: Node in window_layer.get_children():
		var window: AppWindow = child as AppWindow
		if window == null:
			continue

		_unregister_window(window)
		window_closed.emit(window)
		window.free()

	_single_instance_windows.clear()
	_windows_pending_restore_reveal.clear()
	_error_window = null
	_z_index_counter = 100
	_desktop_band_z_index_counter = 0


func restore_windows(
	windows_snapshot: Array,
	content_registry: GameContentRegistry
) -> PersistenceResult:
	if content_registry == null:
		return PersistenceResult.failure(
			&"missing_content_registry",
			"Cannot restore windows without a content registry."
		)

	clear_windows_for_restore()

	var sorted_snapshot: Array = windows_snapshot.duplicate(
		true
	)
	sorted_snapshot.sort_custom(_sort_window_snapshots)

	for value: Variant in sorted_snapshot:
		if not value is Dictionary:
			return PersistenceResult.failure(
				&"invalid_window_snapshot",
				"A window snapshot is not an object."
			)

		var window_data: Dictionary = value as Dictionary
		var program_id: StringName = StringName(
			str(window_data.get("program_id", ""))
		)
		var program: ProgramData = (
			content_registry.get_program(program_id)
		)
		if program == null:
			return PersistenceResult.failure(
				&"unknown_program",
				"Cannot restore unknown program '%s'."
					% str(program_id)
			)

		var restore_result: PersistenceResult = (
			_restore_program_window(
				program,
				window_data
			)
		)
		if not restore_result.success:
			return restore_result

	return PersistenceResult.ok()


func reveal_restored_windows(
	maximum_total_duration: float = 0.6
) -> void:
	if _windows_pending_restore_reveal.is_empty():
		return

	var windows: Array[AppWindow] = (
		_windows_pending_restore_reveal.duplicate()
	)
	_windows_pending_restore_reveal.clear()
	windows.sort_custom(_sort_windows_by_z_order)

	var duration_per_window: float = clampf(
		maximum_total_duration / float(windows.size()),
		0.03,
		0.1
	)
	for window: AppWindow in windows:
		if not is_instance_valid(window):
			continue

		await window.play_restore_reveal_animation(
			duration_per_window
		)


func show_system_error(
	error_title: String,
	error_message: String
) -> void:
	if window_layer == null:
		push_error(
			"Cannot show system error: WindowLayer is not assigned."
		)
		return

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

	error_window.allocated_ram = 0
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


func place_window_in_desktop_band(
	window: AppWindow
) -> void:
	if window == null:
		return

	_desktop_band_z_index_counter = mini(
		_desktop_band_z_index_counter + 1,
		99
	)
	window.z_index = _desktop_band_z_index_counter

	if window.get_parent() == window_layer:
		window_layer.move_child(window, 0)


func restore_window_to_normal_band(
	window: AppWindow
) -> void:
	focus_window(window)


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


func get_shot_blocking_window_at_global_point(
	global_point: Vector2,
	ignored_window: AppWindow = null
) -> AppWindow:
	if window_layer == null:
		return null

	for index: int in range(
		window_layer.get_child_count() - 1,
		-1,
		-1
	):
		var child: Node = window_layer.get_child(index)
		var window: AppWindow = child as AppWindow

		if window == null:
			continue

		if window == ignored_window:
			continue

		if not window.is_visible_in_tree():
			continue

		if not window.blocks_shots:
			continue

		if not window.get_global_rect().has_point(global_point):
			continue

		return window

	return null


func is_shot_blocked_at_global_point(
	global_point: Vector2,
	ignored_window: AppWindow = null
) -> bool:
	return (
		get_shot_blocking_window_at_global_point(
			global_point,
			ignored_window
		)
		!= null
	)


func get_shot_blocking_window_on_global_segment(
	from_global_position: Vector2,
	to_global_position: Vector2,
	ignored_window: AppWindow = null
) -> AppWindow:
	if window_layer == null:
		return null

	for index: int in range(
		window_layer.get_child_count() - 1,
		-1,
		-1
	):
		var child: Node = window_layer.get_child(index)
		var window: AppWindow = child as AppWindow

		if window == null or window == ignored_window:
			continue

		if not window.is_visible_in_tree():
			continue

		if not window.blocks_shots:
			continue

		if _global_segment_intersects_window(
			from_global_position,
			to_global_position,
			window
		):
			return window

	return null


func is_shot_path_blocked(
	from_global_position: Vector2,
	to_global_position: Vector2,
	ignored_window: AppWindow = null
) -> bool:
	return (
		get_shot_blocking_window_on_global_segment(
			from_global_position,
			to_global_position,
			ignored_window
		)
		!= null
	)


func _resolve_references() -> void:
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

	if enemy_manager == null:
		enemy_manager = (
			get_node_or_null("../EnemyManager")
			as EnemyManager
		)


func _validate_dependencies() -> void:
	if window_layer == null:
		push_error(
			"WindowManager could not find WindowLayer."
		)

	if ram_manager == null:
		push_error(
			"WindowManager could not find RamManager."
		)

	if enemy_manager == null:
		push_warning(
			"WindowManager has no EnemyManager; enemy-aware "
			+ "applications will remain inactive."
		)


func _can_open_program_request(
	program_data: ProgramData
) -> bool:
	if window_layer == null:
		push_error(
			"Cannot open program: WindowLayer is not assigned."
		)
		return false

	if ram_manager == null:
		push_error(
			"Cannot open program: RamManager is not assigned."
		)
		return false

	if program_data == null:
		push_warning("Cannot open null ProgramData.")
		return false

	if program_data.window_scene == null:
		push_warning(
			"Program '%s' has no window scene assigned."
			% program_data.display_name
		)
		return false

	return true


func _instantiate_app_window(
	program_data: ProgramData
) -> AppWindow:
	var window: AppWindow = (
		program_data.window_scene.instantiate()
		as AppWindow
	)

	if window == null:
		push_error(
			"Window scene for '%s' must inherit from AppWindow."
			% program_data.display_name
		)
		return null

	window.configure_runtime_services(
		self,
		enemy_manager
	)

	return window


func _global_segment_intersects_window(
	from_global_position: Vector2,
	to_global_position: Vector2,
	window: AppWindow
) -> bool:
	if window == null:
		return false

	var window_rect: Rect2 = window.get_global_rect()
	if window_rect.has_point(from_global_position):
		return true

	if window_rect.has_point(to_global_position):
		return true

	var top_left: Vector2 = window_rect.position
	var top_right: Vector2 = Vector2(
		window_rect.end.x,
		window_rect.position.y
	)
	var bottom_right: Vector2 = window_rect.end
	var bottom_left: Vector2 = Vector2(
		window_rect.position.x,
		window_rect.end.y
	)
	return (
		_segments_intersect(
			from_global_position,
			to_global_position,
			top_left,
			top_right
		)
		or _segments_intersect(
			from_global_position,
			to_global_position,
			top_right,
			bottom_right
		)
		or _segments_intersect(
			from_global_position,
			to_global_position,
			bottom_right,
			bottom_left
		)
		or _segments_intersect(
			from_global_position,
			to_global_position,
			bottom_left,
			top_left
		)
	)


func _segments_intersect(
	first_start: Vector2,
	first_end: Vector2,
	second_start: Vector2,
	second_end: Vector2
) -> bool:
	return Geometry2D.segment_intersects_segment(
		first_start,
		first_end,
		second_start,
		second_end
	) != null


func _restore_program_window(
	program_data: ProgramData,
	window_data: Dictionary
) -> PersistenceResult:
	if not _can_open_program_request(program_data):
		return PersistenceResult.failure(
			&"window_restore_failed",
			"Program '%s' cannot be instantiated."
				% str(program_data.program_id)
		)

	var ram_cost: int = maxi(0, program_data.ram_cost)
	if not ram_manager.reserve_ram(ram_cost):
		return PersistenceResult.failure(
			&"window_restore_insufficient_ram",
			"Not enough RAM to restore '%s'."
				% str(program_data.program_id)
		)

	var window: AppWindow = _instantiate_app_window(program_data)
	if window == null:
		ram_manager.release_ram(ram_cost)
		return PersistenceResult.failure(
			&"window_restore_failed",
			"Could not instantiate '%s'."
				% str(program_data.program_id)
		)

	window_layer.add_child(window)
	window.allocated_ram = ram_cost
	window.setup(program_data)

	window.focus_requested.connect(focus_window)
	window.close_requested.connect(close_window)
	_register_window(program_data, window)

	window.z_index = maxi(
		100,
		int(window_data.get("z_order", 100))
	)
	_z_index_counter = maxi(
		_z_index_counter,
		window.z_index
	)

	var app_state_variant: Variant = window_data.get(
		"app_state",
		{}
	)
	var app_state: Dictionary = {}
	if app_state_variant is Dictionary:
		app_state = (
			app_state_variant as Dictionary
		).duplicate(true)

	window.restore_from_save_snapshot(app_state)
	window.position = SaveDataCodec.data_to_vector2(
		window_data.get("position"),
		_get_centered_position(window)
	)
	window.prepare_after_restore()
	window.prepare_for_restore_reveal()
	_windows_pending_restore_reveal.append(window)
	window_opened.emit(window, program_data)
	return PersistenceResult.ok(window)


func _show_insufficient_ram_error(
	program_data: ProgramData
) -> void:
	var required_ram: int = maxi(
		0,
		program_data.ram_cost
	)

	var available_ram: int = ram_manager.get_available_ram()

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


func _get_app_windows() -> Array[AppWindow]:
	var windows: Array[AppWindow] = []
	if window_layer == null:
		return windows

	for child: Node in window_layer.get_children():
		var window: AppWindow = child as AppWindow
		if window == null:
			continue

		if window.program_id == StringName():
			continue

		windows.append(window)

	return windows


func _sort_windows_by_z_order(
	first: AppWindow,
	second: AppWindow
) -> bool:
	if first.z_index == second.z_index:
		return first.get_index() < second.get_index()

	return first.z_index < second.z_index


func _sort_window_snapshots(
	first: Dictionary,
	second: Dictionary
) -> bool:
	return int(first.get("z_order", 100)) < int(
		second.get("z_order", 100)
	)
