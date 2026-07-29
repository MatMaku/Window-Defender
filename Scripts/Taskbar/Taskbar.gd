extends Control
class_name Taskbar

signal save_requested
signal return_to_main_menu_requested

@export_category("Start Menu Animation")

@export_range(0.01, 1.0, 0.01)
var open_animation_duration: float = 0.14

@export_range(0.0, 50.0, 1.0)
var menu_slide_distance: float = 10.0

@export var menu_start_scale: Vector2 = Vector2(0.98, 0.94)

@onready var start_button: Button = (
	get_node_or_null("UiLayer/TaskbarBar/StartButton")
	as Button
)

@onready var taskbar_bar: Control = (
	get_node_or_null("UiLayer/TaskbarBar")
	as Control
)

@onready var app_button_area: HBoxContainer = (
	get_node_or_null("UiLayer/TaskbarBar/AppButtonArea")
	as HBoxContainer
)

@onready var start_menu: PanelContainer = (
	get_node_or_null("UiLayer/StartMenu")
	as PanelContainer
)

@onready var pause_overlay: Control = (
	get_node_or_null("UiLayer/PauseOverlay")
	as Control
)

@onready var shutdown_button: Button = (
	get_node_or_null(
		"UiLayer/StartMenu/MenuMargin/MenuVBox/ShutDownButton"
	)
	as Button
)

@onready var save_button: Button = (
	get_node_or_null(
		"UiLayer/StartMenu/MenuMargin/MenuVBox/SaveButton"
	)
	as Button
)

var _is_start_menu_open: bool = false
var _return_to_main_menu_in_progress: bool = false
var _reopen_start_menu_on_return_failure: bool = false
var _menu_rest_position: Vector2 = Vector2.ZERO
var _menu_base_modulate: Color = Color.WHITE
var _menu_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if start_button == null:
		push_error(
			"Taskbar could not find "
			+ "UiLayer/TaskbarBar/StartButton."
		)
		return

	if taskbar_bar == null:
		push_error(
			"Taskbar could not find UiLayer/TaskbarBar."
		)
		return

	if app_button_area == null:
		push_error(
			"Taskbar could not find "
			+ "UiLayer/TaskbarBar/AppButtonArea."
		)
		return

	if start_menu == null:
		push_error(
			"Taskbar could not find UiLayer/StartMenu."
		)
		return

	if pause_overlay == null:
		push_error(
			"Taskbar could not find UiLayer/PauseOverlay."
		)
		return

	if shutdown_button == null:
		push_error(
			"Taskbar could not find ShutDownButton."
		)
		return

	if save_button == null:
		push_error("Taskbar could not find SaveButton.")
		return

	start_button.pressed.connect(_on_start_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	shutdown_button.pressed.connect(
		_on_shutdown_button_pressed
	)
	start_menu.resized.connect(_update_start_menu_pivot)

	resized.connect(_on_taskbar_resized)

	_set_start_menu_open(false)
	call_deferred("_cache_start_menu_rest_state")


func _exit_tree() -> void:
	_kill_menu_tween()

	var scene_tree: SceneTree = get_tree()

	if scene_tree != null:
		scene_tree.paused = false


func _input(event: InputEvent) -> void:
	if not _is_start_menu_open:
		return

	var mouse_event: InputEventMouseButton = (
		event as InputEventMouseButton
	)

	if mouse_event == null:
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mouse_event.pressed:
		return

	var click_global_position: Vector2 = (
		get_global_mouse_position()
	)

	if _is_click_inside_start_interface(click_global_position):
		return

	if not taskbar_bar.get_global_rect().has_point(
		click_global_position
	):
		get_viewport().set_input_as_handled()

	close_start_menu()


func get_app_button_area() -> HBoxContainer:
	return app_button_area


func toggle_start_menu() -> void:
	if _is_start_menu_open:
		close_start_menu()
	else:
		open_start_menu()


func open_start_menu() -> void:
	_set_start_menu_open(true)


func close_start_menu() -> void:
	_set_start_menu_open(false)


func complete_return_to_main_menu(
	return_succeeded: bool
) -> void:
	if return_succeeded:
		return

	_return_to_main_menu_in_progress = false
	start_button.disabled = false
	save_button.disabled = false
	shutdown_button.disabled = false

	if _reopen_start_menu_on_return_failure:
		open_start_menu()

	_reopen_start_menu_on_return_failure = false


func _set_start_menu_open(open: bool) -> void:
	var state_changed: bool = _is_start_menu_open != open
	_is_start_menu_open = open

	start_button.set_pressed_no_signal(open)
	pause_overlay.visible = open
	get_tree().paused = open

	if not state_changed:
		return

	if open:
		_animate_start_menu_open()
	else:
		_animate_start_menu_close()


func _animate_start_menu_open() -> void:
	_kill_menu_tween()
	_update_start_menu_pivot()

	var initial_position: Vector2 = (
		_menu_rest_position
		+ Vector2(0.0, menu_slide_distance)
	)

	var initial_modulate: Color = _menu_base_modulate
	initial_modulate.a = 0.0

	start_menu.visible = true
	start_menu.position = initial_position
	start_menu.scale = menu_start_scale
	start_menu.modulate = initial_modulate

	_menu_tween = create_tween()
	_menu_tween.set_parallel(true)

	_menu_tween.tween_property(
		start_menu,
		"position",
		_menu_rest_position,
		open_animation_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	_menu_tween.tween_property(
		start_menu,
		"scale",
		Vector2.ONE,
		open_animation_duration
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	_menu_tween.tween_property(
		start_menu,
		"modulate:a",
		_menu_base_modulate.a,
		open_animation_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)


func _animate_start_menu_close() -> void:
	_kill_menu_tween()

	var final_position: Vector2 = (
		_menu_rest_position
		+ Vector2(0.0, menu_slide_distance)
	)

	_menu_tween = create_tween()
	_menu_tween.set_parallel(true)

	_menu_tween.tween_property(
		start_menu,
		"position",
		final_position,
		open_animation_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	_menu_tween.tween_property(
		start_menu,
		"scale",
		menu_start_scale,
		open_animation_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	_menu_tween.tween_property(
		start_menu,
		"modulate:a",
		0.0,
		open_animation_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN
	)

	_menu_tween.chain().tween_callback(
		_finish_close_start_menu
	)


func _on_start_button_pressed() -> void:
	toggle_start_menu()


func _on_save_button_pressed() -> void:
	save_requested.emit()


func _on_shutdown_button_pressed() -> void:
	if _return_to_main_menu_in_progress:
		return

	_return_to_main_menu_in_progress = true
	_reopen_start_menu_on_return_failure = (
		_is_start_menu_open
	)

	_set_start_menu_open(false)
	start_button.disabled = true
	save_button.disabled = true
	shutdown_button.disabled = true
	return_to_main_menu_requested.emit()


func _is_click_inside_start_interface(
	global_position: Vector2
) -> bool:
	if start_button.get_global_rect().has_point(global_position):
		return true

	if start_menu.get_global_rect().has_point(global_position):
		return true

	return false


func _cache_start_menu_rest_state() -> void:
	_menu_rest_position = start_menu.position
	_menu_base_modulate = start_menu.modulate

	_update_start_menu_pivot()


func _update_start_menu_pivot() -> void:
	start_menu.pivot_offset = Vector2(
		0.0,
		start_menu.size.y
	)


func _on_taskbar_resized() -> void:
	if _is_start_menu_open:
		return

	call_deferred("_cache_start_menu_rest_state")


func _finish_close_start_menu() -> void:
	start_menu.visible = false
	start_menu.position = _menu_rest_position
	start_menu.scale = Vector2.ONE
	start_menu.modulate = _menu_base_modulate


func _kill_menu_tween() -> void:
	if _menu_tween == null:
		return

	if _menu_tween.is_running():
		_menu_tween.kill()
