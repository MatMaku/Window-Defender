extends Node
class_name DisplayManager

signal desktop_resolution_applied(
	new_resolution: Vector2i,
	resolution_tier: int
)

@export_category("Content Scale")

@export var apply_on_ready: bool = true
@export var enforce_canvas_items_scale: bool = true
@export var enforce_keep_aspect: bool = true

@export_category("Fullscreen")

@export var use_fullscreen: bool = true
@export var use_exclusive_fullscreen: bool = false

@export_category("Windowed Debug")

@export var resize_window_when_windowed: bool = true
@export var center_window_when_windowed: bool = true

@export_category("Layout Notification")

@export var notify_layout_nodes_after_change: bool = true

@export_category("Optional References")

@export var desktop: Desktop
@export var window_manager: WindowManager

@export_category("Debug")

@export var debug_print_resolution_changes: bool = false

var _current_resolution: Vector2i = Vector2i.ZERO
var _current_tier: int = -1
var _desktop_state: GameDesktopState


func _ready() -> void:
	_resolve_references()

	if _desktop_state == null:
		push_error("DisplayManager requires GameDesktopState.")
		return

	_connect_state_signals()

	if apply_on_ready:
		apply_game_state_resolution()


func apply_game_state_resolution() -> void:
	apply_desktop_resolution(
		_desktop_state.desktop_resolution,
		_desktop_state.desktop_resolution_tier
	)


func apply_next_resolution_tier() -> void:
	if not _desktop_state.has_next_desktop_resolution_tier():
		return

	_desktop_state.set_desktop_resolution_tier(
		_desktop_state.get_next_desktop_resolution_tier()
	)


func apply_desktop_resolution(
	new_resolution: Vector2i,
	resolution_tier: int
) -> void:
	var safe_resolution: Vector2i = _get_safe_resolution(
		new_resolution
	)

	var game_window: Window = get_window()

	if game_window == null:
		push_error("DisplayManager could not access the game window.")
		return

	_apply_content_scale(
		game_window,
		safe_resolution
	)

	_apply_window_mode(
		game_window,
		safe_resolution
	)

	_current_resolution = safe_resolution
	_current_tier = resolution_tier

	if debug_print_resolution_changes:
		print(
			"DisplayManager applied desktop resolution: ",
			_current_resolution,
			" | tier: ",
			_current_tier
		)

	desktop_resolution_applied.emit(
		_current_resolution,
		_current_tier
	)

	if notify_layout_nodes_after_change:
		call_deferred("_notify_layout_nodes")


func get_current_resolution() -> Vector2i:
	return _current_resolution


func get_current_tier() -> int:
	return _current_tier


func _resolve_references() -> void:
	_desktop_state = GameState.desktop_state

	if desktop == null:
		desktop = get_parent() as Desktop

	if window_manager == null:
		window_manager = (
			get_node_or_null("../WindowManager")
			as WindowManager
		)


func _connect_state_signals() -> void:
	if not _desktop_state.desktop_resolution_changed.is_connected(
		_on_desktop_resolution_changed
	):
		_desktop_state.desktop_resolution_changed.connect(
			_on_desktop_resolution_changed
		)


func _on_desktop_resolution_changed(
	new_resolution: Vector2i,
	resolution_tier: int
) -> void:
	apply_desktop_resolution(
		new_resolution,
		resolution_tier
	)


func _apply_content_scale(
	game_window: Window,
	new_resolution: Vector2i
) -> void:
	if enforce_canvas_items_scale:
		game_window.content_scale_mode = (
			Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		)

	if enforce_keep_aspect:
		game_window.content_scale_aspect = (
			Window.CONTENT_SCALE_ASPECT_KEEP
		)

	game_window.content_scale_size = new_resolution


func _apply_window_mode(
	game_window: Window,
	new_resolution: Vector2i
) -> void:
	if use_fullscreen:
		if use_exclusive_fullscreen:
			game_window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		else:
			game_window.mode = Window.MODE_FULLSCREEN

		return

	game_window.mode = Window.MODE_WINDOWED

	if resize_window_when_windowed:
		game_window.size = new_resolution

	if center_window_when_windowed:
		if game_window.has_method("move_to_center"):
			game_window.call("move_to_center")


func _get_safe_resolution(
	resolution: Vector2i
) -> Vector2i:
	return Vector2i(
		maxi(320, resolution.x),
		maxi(180, resolution.y)
	)


func _notify_layout_nodes() -> void:
	_notify_desktop_layout()
	_notify_window_manager_layout()


func _notify_desktop_layout() -> void:
	if desktop == null:
		return

	if not desktop.has_method(
		"clamp_all_shortcuts_inside_icon_layer"
	):
		return

	desktop.call(
		"clamp_all_shortcuts_inside_icon_layer"
	)


func _notify_window_manager_layout() -> void:
	if window_manager == null:
		return

	if not window_manager.has_method(
		"clamp_all_windows_inside_layer"
	):
		return

	window_manager.call(
		"clamp_all_windows_inside_layer"
	)
