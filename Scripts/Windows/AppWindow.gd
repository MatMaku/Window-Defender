extends PanelContainer
class_name AppWindow

signal focus_requested(window: AppWindow)
signal close_requested(window: AppWindow)

@export var draggable: bool = true
@export var keep_inside_parent: bool = true

@export_category("Open Animation")

@export var use_open_animation: bool = true
@export var open_animation_duration: float = 0.12
@export var open_start_scale: Vector2 = Vector2(0.92, 0.92)

@export_category("Gameplay")

@export var blocks_shots: bool = true

@onready var title_bar: Control = %TitleBar
@onready var window_icon: TextureRect = %WindowIcon
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var content_root: Control = %ContentRoot

var program_id: StringName
var allocated_ram: int = 0

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _open_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_gui_input)

	close_button.pressed.connect(_on_close_button_pressed)


func setup(program_data: ProgramData) -> void:
	if program_data == null:
		return

	program_id = program_data.program_id
	title_label.text = program_data.display_name
	window_icon.texture = program_data.icon

	if program_data.default_window_size != Vector2.ZERO:
		custom_minimum_size = program_data.default_window_size
		size = program_data.default_window_size


func play_open_animation(
	duration_multiplier: float = 1.0
) -> void:
	if not use_open_animation:
		return

	if _open_tween != null and _open_tween.is_running():
		_open_tween.kill()

	var safe_multiplier: float = maxf(
		1.0,
		duration_multiplier
	)

	var effective_duration: float = maxf(
		0.01,
		open_animation_duration * safe_multiplier
	)

	pivot_offset = size * 0.5
	scale = open_start_scale

	var original_modulate: Color = modulate

	modulate = Color(
		original_modulate.r,
		original_modulate.g,
		original_modulate.b,
		0.0
	)

	_open_tween = create_tween()
	_open_tween.set_parallel(true)

	_open_tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		effective_duration
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	_open_tween.tween_property(
		self,
		"modulate:a",
		original_modulate.a,
		effective_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event

		if (
			mouse_button.button_index == MOUSE_BUTTON_LEFT
			and mouse_button.pressed
		):
			focus_requested.emit(self)


func _on_title_bar_gui_input(
	event: InputEvent
) -> void:
	if not draggable:
		return

	if event is InputEventMouseButton:
		_handle_title_bar_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_title_bar_mouse_motion(event)


func _handle_title_bar_mouse_button(
	event: InputEventMouseButton
) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		_is_dragging = true
		_drag_offset = (
			global_position
			- get_global_mouse_position()
		)

		focus_requested.emit(self)
		accept_event()
		return

	_is_dragging = false
	accept_event()


func _handle_title_bar_mouse_motion(
	_event: InputEventMouseMotion
) -> void:
	if not _is_dragging:
		return

	var target_position: Vector2 = (
		get_global_mouse_position()
		+ _drag_offset
	)

	if keep_inside_parent:
		global_position = _get_clamped_global_position(
			target_position
		)
	else:
		global_position = target_position

	accept_event()


func _get_clamped_global_position(
	desired_global_position: Vector2
) -> Vector2:
	var parent_control: Control = get_parent() as Control

	if parent_control == null:
		return desired_global_position

	var parent_rect: Rect2 = parent_control.get_global_rect()
	var max_position: Vector2 = parent_rect.end - size

	return Vector2(
		clampf(
			desired_global_position.x,
			parent_rect.position.x,
			max_position.x
		),
		clampf(
			desired_global_position.y,
			parent_rect.position.y,
			max_position.y
		)
	)


func _on_close_button_pressed() -> void:
	close_requested.emit(self)
