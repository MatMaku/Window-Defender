extends PanelContainer
class_name AppWindow

signal focus_requested(window: AppWindow)
signal close_requested(window: AppWindow)

signal opening_started(window: AppWindow)
signal opening_finished(window: AppWindow)

@export var draggable: bool = true
@export var keep_inside_parent: bool = true

@export_category("Open Animation")

@export var use_open_animation: bool = true
@export var open_animation_duration: float = 0.12
@export var open_start_scale: Vector2 = Vector2(0.92, 0.92)

@export_category("Gameplay")

@export var blocks_shots: bool = true
@export var allows_adware_hiding: bool = true
@export var show_in_taskbar: bool = true

@onready var title_bar: Control = %TitleBar
@onready var window_icon: TextureRect = %WindowIcon
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var content_root: Control = %ContentRoot

@onready var opening_input_blocker: Control = %OpeningInputBlocker

var program_id: StringName
var allocated_ram: int = 0

var _is_dragging: bool = false
var _is_opening: bool = false
var _is_restore_reveal_pending: bool = false

var _drag_offset: Vector2 = Vector2.ZERO
var _open_tween: Tween

var _open_target_modulate: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_gui_input)

	close_button.pressed.connect(_on_close_button_pressed)

	opening_input_blocker.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	opening_input_blocker.focus_mode = (
		Control.FOCUS_ALL
	)

	opening_input_blocker.visible = false


func setup(program_data: ProgramData) -> void:
	if program_data == null:
		return

	program_id = program_data.program_id
	title_label.text = program_data.display_name
	window_icon.texture = program_data.icon

	if program_data.default_window_size != Vector2.ZERO:
		custom_minimum_size = program_data.default_window_size
		size = program_data.default_window_size


func configure_runtime_services(
	_window_manager: WindowManager,
	_enemy_manager: EnemyManager
) -> void:
	pass


func play_open_animation(
	duration_multiplier: float = 1.0
) -> void:
	_set_opening_state(true)

	if not use_open_animation:
		_finish_open_animation()
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

	_open_target_modulate = modulate

	modulate = Color(
		_open_target_modulate.r,
		_open_target_modulate.g,
		_open_target_modulate.b,
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
		_open_target_modulate.a,
		effective_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)

	_open_tween.finished.connect(
		_finish_open_animation
	)


func is_opening() -> bool:
	return _is_opening


func is_being_dragged() -> bool:
	return _is_dragging


func can_hide_adware_under() -> bool:
	return (
		allows_adware_hiding
		and is_inside_tree()
		and (
			not _is_opening
			or _is_restore_reveal_pending
		)
		and (
			is_visible_in_tree()
			or _is_restore_reveal_pending
		)
		and not is_queued_for_deletion()
	)


func should_show_in_taskbar() -> bool:
	return show_in_taskbar


func cancel_drag_for_save() -> void:
	_is_dragging = false
	_drag_offset = Vector2.ZERO


func create_save_snapshot() -> Dictionary:
	return {}


func restore_from_save_snapshot(_snapshot: Dictionary) -> void:
	pass


func prepare_after_restore() -> void:
	if _open_tween != null and _open_tween.is_running():
		_open_tween.kill()

	_open_tween = null
	_is_dragging = false
	_is_opening = false
	_is_restore_reveal_pending = false
	scale = Vector2.ONE
	modulate = Color(
		modulate.r,
		modulate.g,
		modulate.b,
		1.0
	)
	opening_input_blocker.visible = false


func prepare_for_restore_reveal() -> void:
	if _open_tween != null and _open_tween.is_running():
		_open_tween.kill()

	_open_tween = null
	_is_dragging = false
	_is_opening = true
	_is_restore_reveal_pending = true
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	content_root.visible = false
	opening_input_blocker.visible = true
	visible = false


func play_restore_reveal_animation(
	total_duration: float = 0.1
) -> void:
	var safe_duration: float = maxf(0.03, total_duration)
	var step_duration: float = safe_duration * 0.5
	var title_scale: float = 0.08
	if size.y > 0.0:
		title_scale = clampf(
			title_bar.size.y / size.y,
			0.03,
			0.25
		)

	pivot_offset = size * 0.5
	scale = Vector2(0.02, title_scale)
	content_root.visible = false
	opening_input_blocker.visible = true
	visible = true

	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.tween_property(
		self,
		"scale:x",
		1.0,
		step_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
	await _open_tween.finished

	if not is_inside_tree():
		return

	_open_tween = create_tween()
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_open_tween.tween_property(
		self,
		"scale:y",
		1.0,
		step_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
	await _open_tween.finished

	scale = Vector2.ONE
	content_root.visible = true
	opening_input_blocker.visible = false
	_is_opening = false
	_is_restore_reveal_pending = false
	_open_tween = null


func _finish_open_animation() -> void:
	scale = Vector2.ONE
	modulate = _open_target_modulate

	_set_opening_state(false)

	opening_finished.emit(self)


func _set_opening_state(active: bool) -> void:
	if _is_opening == active:
		return

	_is_opening = active

	if active:
		_is_dragging = false

		opening_input_blocker.visible = true
		opening_input_blocker.grab_focus()

		opening_started.emit(self)
		return

	opening_input_blocker.visible = false

	if opening_input_blocker.has_focus():
		opening_input_blocker.release_focus()


func _gui_input(event: InputEvent) -> void:
	if _is_opening:
		return

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
	if _is_opening:
		return

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
	if _is_opening:
		return

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
	if _is_opening:
		return

	close_requested.emit(self)
