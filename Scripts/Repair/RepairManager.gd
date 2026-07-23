extends Node
class_name RepairManager

enum RepairStatus {
	NO_WINDOW,
	NO_TARGET,
	NO_CONTACT,
	BLOCKED,
	FULL,
	REPAIRING
}

signal repair_started
signal repair_stopped
signal repair_tick(healed_amount: float)

@export var window_manager: WindowManager
@export var system_manager: SystemManager

@export_category("Repair")

@export_range(0.01, 100.0, 0.01)
var repair_percent_per_tick: float = 1.0

@export_range(0.05, 30.0, 0.05)
var repair_tick_interval: float = 5.0

@export_range(0.0, 9999.0, 1.0)
var minimum_contact_area: float = 16.0

@export_category("Block Check")

@export var any_window_blocks_contact: bool = true

@export_range(0.0, 20.0, 0.5)
var contact_sample_inset: float = 2.0

var _repair_window: RepairWindow
var _repair_tick_elapsed: float = 0.0
var _was_repairing: bool = false
var _system_state: GameSystemState


func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	_connect_signals()
	_register_existing_repair_window()


func _process(delta: float) -> void:
	_update_repair(delta)


# ================================================================
# SETUP
# ================================================================

func _resolve_references() -> void:
	_system_state = GameState.system_state

	if window_manager == null:
		window_manager = (
			get_node_or_null("../WindowManager")
			as WindowManager
		)

	if system_manager == null:
		system_manager = (
			get_node_or_null("../SystemManager")
			as SystemManager
		)


func _validate_dependencies() -> bool:
	if _system_state == null:
		push_error("RepairManager requires GameSystemState.")
		return false

	if window_manager == null:
		push_error("RepairManager requires a WindowManager reference.")
		return false

	if system_manager == null:
		push_error("RepairManager requires a SystemManager reference.")
		return false

	return true


func _connect_signals() -> void:
	if not window_manager.window_opened.is_connected(
		_on_window_opened
	):
		window_manager.window_opened.connect(
			_on_window_opened
		)

	if not window_manager.window_closed.is_connected(
		_on_window_closed
	):
		window_manager.window_closed.connect(
			_on_window_closed
		)


func _register_existing_repair_window() -> void:
	if window_manager.window_layer == null:
		return

	for child: Node in window_manager.window_layer.get_children():
		var repair_window: RepairWindow = child as RepairWindow

		if repair_window == null:
			continue

		_bind_repair_window(repair_window)
		return


# ================================================================
# WINDOW BINDING
# ================================================================

func _on_window_opened(
	window: AppWindow,
	_program_data: ProgramData
) -> void:
	var repair_window: RepairWindow = window as RepairWindow

	if repair_window == null:
		return

	_bind_repair_window(repair_window)


func _on_window_closed(window: AppWindow) -> void:
	if window != _repair_window:
		return

	_set_repairing(false)

	_repair_window = null
	_repair_tick_elapsed = 0.0


func _bind_repair_window(window: RepairWindow) -> void:
	if _repair_window == window:
		return

	_repair_window = window
	_repair_window.blocks_shots = true

	_repair_tick_elapsed = 0.0
	_update_repair_presentation(
		_get_repair_status()
	)


# ================================================================
# REPAIR LOOP
# ================================================================

func _update_repair(delta: float) -> void:
	var status: int = _get_repair_status()

	_update_repair_presentation(status)

	if status != RepairStatus.REPAIRING:
		_repair_tick_elapsed = 0.0
		_set_repairing(false)
		return

	_set_repairing(true)

	_repair_tick_elapsed += delta

	while _repair_tick_elapsed >= repair_tick_interval:
		_repair_tick_elapsed -= repair_tick_interval

		var healed_amount: float = (
			system_manager.heal_system(
				_get_repair_amount_for_tick()
			)
		)

		if healed_amount <= 0.0:
			break

		repair_tick.emit(healed_amount)


func _set_repairing(active: bool) -> void:
	if _was_repairing == active:
		return

	_was_repairing = active

	if _was_repairing:
		repair_started.emit()
	else:
		repair_stopped.emit()


func _get_repair_status() -> int:
	if not is_instance_valid(_repair_window):
		return RepairStatus.NO_WINDOW

	var system_executable: DesktopExecutable = (
		system_manager.get_system_executable()
	)

	if not is_instance_valid(system_executable):
		return RepairStatus.NO_TARGET

	var repair_rect: Rect2 = (
		_repair_window.get_repair_global_rect()
	)

	var system_rect: Rect2 = (
		system_executable.get_global_rect()
	)

	var contact_rect: Rect2 = _get_rect_intersection(
		repair_rect,
		system_rect
	)

	if not _has_valid_contact(contact_rect):
		return RepairStatus.NO_CONTACT

	if _is_contact_blocked(contact_rect):
		return RepairStatus.BLOCKED

	if (
		_system_state.current_system_integrity
		>= _system_state.max_system_integrity
	):
		return RepairStatus.FULL

	return RepairStatus.REPAIRING


func _update_repair_presentation(status: int) -> void:
	if not is_instance_valid(_repair_window):
		return

	match status:
		RepairStatus.NO_TARGET:
			_repair_window.present_no_target()

		RepairStatus.NO_CONTACT:
			_repair_window.present_idle()

		RepairStatus.BLOCKED:
			_repair_window.present_blocked()

		RepairStatus.FULL:
			_repair_window.present_full()

		RepairStatus.REPAIRING:
			_repair_window.present_repairing()

		_:
			_repair_window.present_idle()

func _get_repair_amount_for_tick() -> float:
	var max_integrity: float = maxf(
		1.0,
		_system_state.max_system_integrity
	)

	return max_integrity * (
		repair_percent_per_tick / 100.0
	)

# ================================================================
# CONTACT CHECK
# ================================================================

func _has_valid_contact(contact_rect: Rect2) -> bool:
	if contact_rect.size.x <= 0.0:
		return false

	if contact_rect.size.y <= 0.0:
		return false

	var contact_area: float = (
		contact_rect.size.x
		* contact_rect.size.y
	)

	return contact_area >= minimum_contact_area


func _get_rect_intersection(
	first_rect: Rect2,
	second_rect: Rect2
) -> Rect2:
	var intersection_position: Vector2 = Vector2(
		maxf(
			first_rect.position.x,
			second_rect.position.x
		),
		maxf(
			first_rect.position.y,
			second_rect.position.y
		)
	)

	var intersection_end: Vector2 = Vector2(
		minf(
			first_rect.end.x,
			second_rect.end.x
		),
		minf(
			first_rect.end.y,
			second_rect.end.y
		)
	)

	var intersection_size: Vector2 = (
		intersection_end - intersection_position
	)

	if intersection_size.x <= 0.0 or intersection_size.y <= 0.0:
		return Rect2()

	return Rect2(
		intersection_position,
		intersection_size
	)


func _is_contact_blocked(contact_rect: Rect2) -> bool:
	if not any_window_blocks_contact:
		return false

	if window_manager.window_layer == null:
		return false

	var sample_points: Array[Vector2] = (
		_get_contact_sample_points(contact_rect)
	)

	if sample_points.is_empty():
		return true

	for point: Vector2 in sample_points:
		if not _is_contact_point_blocked(point):
			return false

	return true


func _is_contact_point_blocked(global_point: Vector2) -> bool:
	if window_manager.window_layer == null:
		return false

	for child: Node in window_manager.window_layer.get_children():
		var candidate: AppWindow = child as AppWindow

		if candidate == null:
			continue

		if candidate == _repair_window:
			continue

		if not candidate.is_visible_in_tree():
			continue

		if candidate.get_global_rect().has_point(global_point):
			return true

	return false


func _get_contact_sample_points(
	contact_rect: Rect2
) -> Array[Vector2]:
	var points: Array[Vector2] = []

	var inset: float = minf(
		contact_sample_inset,
		minf(
			contact_rect.size.x,
			contact_rect.size.y
		) * 0.45
	)

	var left: float = contact_rect.position.x + inset
	var right: float = contact_rect.end.x - inset
	var top: float = contact_rect.position.y + inset
	var bottom: float = contact_rect.end.y - inset

	var center: Vector2 = contact_rect.get_center()

	points.append(center)

	points.append(Vector2(left, top))
	points.append(Vector2(right, top))
	points.append(Vector2(left, bottom))
	points.append(Vector2(right, bottom))

	points.append(Vector2(center.x, top))
	points.append(Vector2(center.x, bottom))
	points.append(Vector2(left, center.y))
	points.append(Vector2(right, center.y))

	return points
