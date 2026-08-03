extends AppWindow
class_name FirewallWindow

enum Orientation {
	HORIZONTAL,
	VERTICAL
}

const ORIENTATION_HORIZONTAL: String = "horizontal"
const ORIENTATION_VERTICAL: String = "vertical"

@export_category("Firewall Layout")

@export var horizontal_base_size: Vector2 = Vector2(340.0, 150.0)
@export var vertical_base_size: Vector2 = Vector2(180.0, 310.0)
@export var horizontal_size: Vector2 = Vector2(460.0, 190.0)
@export var vertical_size: Vector2 = Vector2(220.0, 430.0)

@export_category("Upgrade")

@export var size_upgrade_offer: ShopUpgradeOfferData

@export_range(0.0, 1.0, 0.05)
var mobile_wall_alpha: float = 0.5

@export_range(0.0, 64.0, 0.5)
var unestablish_drag_threshold: float = 4.0

@export_range(0.1, 10.0, 0.1)
var status_message_duration: float = 2.5

@onready var wall_texture: TextureRect = %WallTexture
@onready var status_label: Label = %StatusLabel
@onready var button_row: Control = %ButtonRow
@onready var rotate_button: Button = %RotateButton
@onready var establish_button: Button = %EstablishButton
@onready var status_timer: Timer = %StatusTimer

var _orientation: int = Orientation.HORIZONTAL
var _is_established: bool = false
var _restore_established_requested: bool = false

var _navigation_manager: Node
var _established_drag_press_position: Vector2 = Vector2.ZERO
var _upgrade_state: GameUpgradeState
var _effective_horizontal_size: Vector2 = Vector2.ZERO
var _effective_vertical_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	_resolve_upgrade_state()

	rotate_button.pressed.connect(
		_on_rotate_button_pressed
	)
	establish_button.pressed.connect(
		_on_establish_button_pressed
	)
	status_timer.timeout.connect(
		_on_status_timer_timeout
	)

	status_timer.one_shot = true
	status_label.visible = false
	_apply_orientation(false)
	_refresh_firewall_visuals()


func setup(program_data: ProgramData) -> void:
	super.setup(program_data)
	_apply_orientation(false)


func set_navigation_manager(
	navigation_manager: Node
) -> void:
	_navigation_manager = navigation_manager
	_apply_size_upgrade()

	if _restore_established_requested:
		_navigation_manager.call(
			"queue_restored_firewall",
			self
		)


func is_established() -> bool:
	return _is_established


func get_orientation() -> int:
	return _orientation


func apply_established_state_from_navigation(
	established: bool
) -> void:
	_is_established = established
	_restore_established_requested = false
	_refresh_firewall_visuals()


func create_save_snapshot() -> Dictionary:
	return {
		"orientation": (
			ORIENTATION_HORIZONTAL
			if _orientation == Orientation.HORIZONTAL
			else ORIENTATION_VERTICAL
		),
		"is_established": _is_established
	}


func restore_from_save_snapshot(
	snapshot: Dictionary
) -> void:
	var orientation_name: String = str(
		snapshot.get(
			"orientation",
			ORIENTATION_HORIZONTAL
		)
	)
	_orientation = (
		Orientation.VERTICAL
		if orientation_name == ORIENTATION_VERTICAL
		else Orientation.HORIZONTAL
	)
	_restore_established_requested = bool(
		snapshot.get("is_established", false)
	)
	_is_established = false
	_apply_orientation(false)
	_refresh_firewall_visuals()


func _gui_input(event: InputEvent) -> void:
	if _is_established:
		return

	super._gui_input(event)


func _handle_title_bar_mouse_button(
	event: InputEventMouseButton
) -> void:
	if not _is_established:
		super._handle_title_bar_mouse_button(event)
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_is_dragging = true
		_established_drag_press_position = (
			get_global_mouse_position()
		)
		_drag_offset = (
			global_position
			- _established_drag_press_position
		)
		accept_event()
		return

	_is_dragging = false
	_established_drag_press_position = Vector2.ZERO
	accept_event()


func _handle_title_bar_mouse_motion(
	event: InputEventMouseMotion
) -> void:
	if not _is_established:
		super._handle_title_bar_mouse_motion(event)
		return

	if not _is_dragging:
		return

	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)
	if mouse_position.distance_to(
		_established_drag_press_position
	) < unestablish_drag_threshold:
		accept_event()
		return

	if _navigation_manager == null:
		_show_status_message(
			"No se pudo actualizar la navegación."
		)
		_is_dragging = false
		return

	_navigation_manager.call(
		"unestablish_firewall",
		self,
		true
	)

	global_position = _get_clamped_global_position(
		mouse_position + _drag_offset
	)
	accept_event()


func _on_rotate_button_pressed() -> void:
	if _is_established:
		return

	_orientation = (
		Orientation.VERTICAL
		if _orientation == Orientation.HORIZONTAL
		else Orientation.HORIZONTAL
	)
	_apply_orientation(true)


func _on_establish_button_pressed() -> void:
	if _is_established:
		return

	if _navigation_manager == null:
		_show_status_message(
			"No se pudo actualizar la navegación."
		)
		return

	var result: StringName = StringName(
		_navigation_manager.call(
			"try_establish_firewall",
			self
		)
	)
	if result == StringName():
		return

	_show_status_message(
		_get_establish_error_message(result)
	)


func _apply_orientation(
	preserve_center: bool
) -> void:
	var previous_center: Vector2 = (
		get_global_rect().get_center()
	)
	var target_size: Vector2 = (
		_effective_horizontal_size
		if _orientation == Orientation.HORIZONTAL
		else _effective_vertical_size
	)
	if target_size == Vector2.ZERO:
		target_size = (
			horizontal_base_size
			if _orientation == Orientation.HORIZONTAL
			else vertical_base_size
		)

	custom_minimum_size = target_size
	custom_maximum_size = target_size
	size = target_size

	if preserve_center:
		global_position = _get_clamped_global_position(
			previous_center - target_size * 0.5
		)

	pivot_offset = size * 0.5


func _resolve_upgrade_state() -> void:
	_upgrade_state = GameState.upgrade_state
	if _upgrade_state == null:
		push_error("FirewallWindow requires GameUpgradeState.")
		_effective_horizontal_size = horizontal_base_size
		_effective_vertical_size = vertical_base_size
		return

	if not _upgrade_state.upgrade_purchase_counts_changed.is_connected(
		_on_upgrade_purchase_counts_changed
	):
		_upgrade_state.upgrade_purchase_counts_changed.connect(
			_on_upgrade_purchase_counts_changed
		)

	_apply_size_upgrade()


func _on_upgrade_purchase_counts_changed(
	_purchase_counts_snapshot: Dictionary
) -> void:
	_apply_size_upgrade()


func _apply_size_upgrade() -> void:
	var purchase_count: int = 0
	var size_progress: float = 0.0
	if _upgrade_state != null and size_upgrade_offer != null:
		purchase_count = _upgrade_state.get_upgrade_purchase_count(
			size_upgrade_offer.offer_id
		)
		size_progress = (
			size_upgrade_offer.get_primary_effect_for_purchase_count(
				purchase_count,
				0.0
			)
		)

	size_progress = clampf(size_progress, 0.0, 1.0)
	var next_horizontal_size: Vector2 = horizontal_base_size.lerp(
		horizontal_size,
		size_progress
	)
	var next_vertical_size: Vector2 = vertical_base_size.lerp(
		vertical_size,
		size_progress
	)
	if (
		next_horizontal_size.is_equal_approx(
			_effective_horizontal_size
		)
		and next_vertical_size.is_equal_approx(
			_effective_vertical_size
		)
	):
		return

	var geometry_update_started: bool = false
	if _is_established:
		if _navigation_manager == null:
			push_error(
				"Cannot resize an established Firewall without navigation."
			)
			return

		geometry_update_started = bool(
			_navigation_manager.call(
				"begin_established_firewall_geometry_update",
				self
			)
		)
		if not geometry_update_started:
			return

	_effective_horizontal_size = next_horizontal_size
	_effective_vertical_size = next_vertical_size
	_apply_orientation(true)

	if not geometry_update_started:
		return

	var validation_error: StringName = StringName(
		_navigation_manager.call(
			"finish_established_firewall_geometry_update",
			self
		)
	)
	if validation_error != StringName():
		_show_status_message(
			_get_establish_error_message(validation_error)
		)


func _refresh_firewall_visuals() -> void:
	if not is_node_ready():
		return

	wall_texture.modulate.a = (
		1.0
		if _is_established
		else mobile_wall_alpha
	)
	button_row.visible = not _is_established
	rotate_button.disabled = _is_established
	establish_button.disabled = _is_established


func _show_status_message(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()

	if message.is_empty():
		status_timer.stop()
		return

	status_timer.start(status_message_duration)


func _on_status_timer_timeout() -> void:
	status_label.text = ""
	status_label.visible = false


func _get_establish_error_message(
	error_code: StringName
) -> String:
	match error_code:
		&"enemy_overlap":
			return "Hay un virus debajo."
		&"shortcut_overlap":
			return "Hay un acceso directo debajo."
		&"firewall_overlap":
			return "Hay otro firewall debajo."
		&"path_blocked":
			return "Bloquearía todas las rutas al sistema."
		_:
			return "No se pudo establecer el firewall."
