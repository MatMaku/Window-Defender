extends Control
class_name Taskbar

@export_category("Start Menu Animation")

@export_range(0.01, 1.0, 0.01)
var open_animation_duration: float = 0.14

@export_range(0.0, 50.0, 1.0)
var menu_slide_distance: float = 10.0

@export var menu_start_scale: Vector2 = Vector2(0.98, 0.94)

@onready var start_button: Button = (
	get_node_or_null("TaskbarBar/StartButton")
	as Button
)

@onready var app_button_area: HBoxContainer = (
	get_node_or_null("TaskbarBar/AppButtonArea")
	as HBoxContainer
)

@onready var start_menu: PanelContainer = (
	get_node_or_null("StartMenu")
	as PanelContainer
)

var _is_start_menu_open: bool = false
var _menu_rest_position: Vector2 = Vector2.ZERO
var _menu_base_modulate: Color = Color.WHITE
var _menu_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if start_button == null:
		push_error(
			"Taskbar could not find TaskbarBar/StartButton."
		)
		return

	if app_button_area == null:
		push_error(
			"Taskbar could not find TaskbarBar/AppButtonArea."
		)
		return

	if start_menu == null:
		push_error(
			"Taskbar could not find StartMenu."
		)
		return

	start_button.pressed.connect(_on_start_button_pressed)
	start_menu.resized.connect(_update_start_menu_pivot)

	start_menu.visible = false

	resized.connect(_on_taskbar_resized)

	call_deferred("_cache_start_menu_rest_state")


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

	close_start_menu()


func get_app_button_area() -> HBoxContainer:
	return app_button_area


func toggle_start_menu() -> void:
	if _is_start_menu_open:
		close_start_menu()
	else:
		open_start_menu()


func open_start_menu() -> void:
	if _is_start_menu_open:
		return

	_is_start_menu_open = true

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


func close_start_menu() -> void:
	if not _is_start_menu_open:
		return

	_is_start_menu_open = false

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
