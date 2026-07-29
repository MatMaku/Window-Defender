extends Control
class_name Desktop

signal executable_spawned(
	executable: DesktopExecutable,
	program_data: ProgramData
)

@export var executable_scene: PackedScene
@export var shortcuts: Array[DesktopShortcutData] = []
@export var initialization_is_coordinated: bool = false

@export_category("Shortcut Placement")

@export_range(0.0, 300.0, 1.0)
var shortcut_edge_margin: float = 40.0

@export_range(10.0, 300.0, 1.0)
var shortcut_spacing: float = 100.0

@onready var icon_layer: Control = %IconLayer
@onready var window_manager: WindowManager = %WindowManager

var _executables_by_program_id: Dictionary = {}
var _desktop_state: GameDesktopState


func _ready() -> void:
	_desktop_state = GameState.desktop_state

	if _desktop_state == null:
		push_error("Desktop requires GameDesktopState.")
		return

	if not initialization_is_coordinated:
		spawn_initial_shortcuts()


func spawn_initial_shortcuts() -> void:
	_spawn_shortcuts()


func get_executable_by_program_id(
	program_id: StringName
) -> DesktopExecutable:
	if not _executables_by_program_id.has(program_id):
		return null

	var executable: DesktopExecutable = (
		_executables_by_program_id[program_id]
		as DesktopExecutable
	)

	if not is_instance_valid(executable):
		_executables_by_program_id.erase(program_id)
		return null

	return executable


func has_program_shortcut(
	program_id: StringName
) -> bool:
	return get_executable_by_program_id(program_id) != null


func get_existing_program_ids() -> Array[StringName]:
	var ids: Array[StringName] = []

	for key in _executables_by_program_id.keys():
		ids.append(key)

	return ids


func add_program_shortcut(
	program_data: ProgramData
) -> DesktopExecutable:
	if program_data == null:
		return null

	if has_program_shortcut(program_data.program_id):
		return get_executable_by_program_id(
			program_data.program_id
		)

	var shortcut: DesktopShortcutData = (
		DesktopShortcutData.new()
	)

	shortcut.program_data = program_data
	shortcut.start_position = _find_free_shortcut_position()

	return _spawn_shortcut(shortcut)


func create_shortcuts_save_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []

	for key: Variant in _executables_by_program_id.keys():
		var executable: DesktopExecutable = (
			_executables_by_program_id[key]
			as DesktopExecutable
		)
		if not is_instance_valid(executable):
			continue

		executable.cancel_drag_for_save()
		var program_id: StringName = executable.get_program_id()
		if program_id == StringName():
			continue

		_desktop_state.update_desktop_shortcut_position(
			program_id,
			executable.position
		)
		snapshot.append({
			"program_id": str(program_id),
			"position": SaveDataCodec.vector2_to_data(
				executable.position
			)
		})

	return snapshot


func clear_shortcuts_for_restore() -> void:
	for child: Node in icon_layer.get_children():
		var executable: DesktopExecutable = (
			child as DesktopExecutable
		)
		if executable == null:
			continue

		executable.free()

	_executables_by_program_id.clear()
	_desktop_state.clear_desktop_shortcuts()


func restore_shortcuts(
	shortcuts_snapshot: Array,
	content_registry: GameContentRegistry
) -> PersistenceResult:
	if content_registry == null:
		return PersistenceResult.failure(
			&"missing_content_registry",
			"Cannot restore shortcuts without a content registry."
		)

	clear_shortcuts_for_restore()

	for value: Variant in shortcuts_snapshot:
		if not value is Dictionary:
			return PersistenceResult.failure(
				&"invalid_shortcut_snapshot",
				"A shortcut snapshot is not an object."
			)

		var shortcut_data: Dictionary = value as Dictionary
		var program_id: StringName = StringName(
			str(shortcut_data.get("program_id", ""))
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

		var shortcut: DesktopShortcutData = (
			DesktopShortcutData.new()
		)
		shortcut.program_data = program
		shortcut.start_position = (
			SaveDataCodec.data_to_vector2(
				shortcut_data.get("position")
			)
		)

		if _spawn_shortcut(shortcut) == null:
			return PersistenceResult.failure(
				&"shortcut_restore_failed",
				"Could not restore shortcut '%s'."
					% str(program_id)
			)

	return PersistenceResult.ok()


func _spawn_shortcuts() -> void:
	for shortcut: DesktopShortcutData in shortcuts:
		_spawn_shortcut(shortcut)


func _spawn_shortcut(
	shortcut: DesktopShortcutData
) -> DesktopExecutable:
	if shortcut == null:
		return null

	if shortcut.program_data == null:
		push_warning(
			"DesktopShortcutData has no ProgramData assigned."
		)
		return null

	if executable_scene == null:
		push_error(
			"Desktop executable scene is not assigned."
		)
		return null

	var program_id: StringName = (
		shortcut.program_data.program_id
	)

	if program_id == StringName():
		push_warning(
			"ProgramData has an empty program_id."
		)
		return null

	var existing_executable: DesktopExecutable = (
		get_executable_by_program_id(program_id)
	)

	if existing_executable != null:
		return existing_executable

	var executable: DesktopExecutable = (
		executable_scene.instantiate()
		as DesktopExecutable
	)

	if executable == null:
		push_error(
			"Executable scene must inherit from DesktopExecutable."
		)
		return null

	icon_layer.add_child(executable)

	executable.program_data = shortcut.program_data
	executable.position = _get_shortcut_spawn_position(
		shortcut
	)

	executable.open_requested.connect(
		_on_executable_open_requested
	)

	_connect_executable_tracking(
		executable,
		program_id
	)

	_executables_by_program_id[
		program_id
	] = executable

	_register_shortcut_in_state(
		program_id,
		executable.position
	)

	executable_spawned.emit(
		executable,
		shortcut.program_data
	)

	return executable


func _connect_executable_tracking(
	executable: DesktopExecutable,
	program_id: StringName
) -> void:
	if executable == null:
		return

	if not executable.has_signal("moved"):
		return

	var moved_callable: Callable = (
		Callable(
			self,
			"_on_executable_moved"
		).bind(program_id)
	)

	if executable.is_connected(
		"moved",
		moved_callable
	):
		return

	executable.connect(
		"moved",
		moved_callable
	)


func _get_shortcut_spawn_position(
	shortcut: DesktopShortcutData
) -> Vector2:
	if shortcut == null:
		return Vector2.ZERO

	if shortcut.program_data == null:
		return shortcut.start_position

	var program_id: StringName = (
		shortcut.program_data.program_id
	)

	if _desktop_state.has_desktop_shortcut(program_id):
		return _desktop_state.get_desktop_shortcut_position(
			program_id,
			shortcut.start_position
		)

	return shortcut.start_position


func _register_shortcut_in_state(
	program_id: StringName,
	shortcut_position: Vector2
) -> void:
	if program_id == StringName():
		return

	_desktop_state.register_desktop_shortcut(
		program_id,
		shortcut_position
	)


func _find_free_shortcut_position() -> Vector2:
	var layer_size: Vector2 = icon_layer.size

	var maximum_x: float = maxf(
		shortcut_edge_margin,
		layer_size.x - shortcut_edge_margin
	)

	var maximum_y: float = maxf(
		shortcut_edge_margin,
		layer_size.y - shortcut_edge_margin
	)

	var y: float = shortcut_edge_margin

	while y <= maximum_y:
		var x: float = shortcut_edge_margin

		while x <= maximum_x:
			var candidate_position: Vector2 = Vector2(
				x,
				y
			)

			if _is_shortcut_position_free(
				candidate_position
			):
				return candidate_position

			x += shortcut_spacing

		y += shortcut_spacing

	return Vector2(
		shortcut_edge_margin,
		shortcut_edge_margin
	)


func _is_shortcut_position_free(
	candidate_position: Vector2
) -> bool:
	for key in _executables_by_program_id.keys():
		var executable: DesktopExecutable = (
			_executables_by_program_id[key]
			as DesktopExecutable
		)

		if not is_instance_valid(executable):
			continue

		var distance_to_candidate: float = (
			executable.position.distance_to(
				candidate_position
			)
		)

		if distance_to_candidate < shortcut_spacing:
			return false

	return true


func _on_executable_moved(
	new_position: Vector2,
	program_id: StringName
) -> void:
	_desktop_state.update_desktop_shortcut_position(
		program_id,
		new_position
	)


func _on_executable_open_requested(
	program_data: ProgramData
) -> void:
	window_manager.open_program(program_data)
