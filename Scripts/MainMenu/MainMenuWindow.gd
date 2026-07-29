extends PanelContainer
class_name MainMenuWindow

signal close_requested

@export var draggable: bool = true
@export var keep_inside_parent: bool = true

@export_category("Window Transition")

@export_range(0.03, 0.2, 0.01)
var transition_step_duration: float = 0.09

@onready var title_bar: Control = %TitleBar
@onready var close_button: Button = %CloseButton
@onready var content_margin: Control = %ContentMargin
@onready var animation_input_blocker: Control = (
	%AnimationInputBlocker
)

var _is_dragging: bool = false
var _is_transitioning: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _transition_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(_on_title_bar_gui_input)
	close_button.pressed.connect(_on_close_button_pressed)
	animation_input_blocker.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	animation_input_blocker.visible = false

	var viewport: Viewport = get_viewport()
	if not viewport.size_changed.is_connected(
		_on_viewport_size_changed
	):
		viewport.size_changed.connect(_on_viewport_size_changed)

	visible = false
	call_deferred("_show_initial_window")


func _exit_tree() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null and viewport.size_changed.is_connected(
		_on_viewport_size_changed
	):
		viewport.size_changed.disconnect(
			_on_viewport_size_changed
		)


func _on_title_bar_gui_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if not draggable:
		return

	if event is InputEventMouseButton:
		_handle_title_bar_mouse_button(
			event as InputEventMouseButton
		)
	elif event is InputEventMouseMotion:
		_handle_title_bar_mouse_motion()


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
	else:
		_is_dragging = false

	accept_event()


func _handle_title_bar_mouse_motion() -> void:
	if not _is_dragging:
		return

	var target_global_position: Vector2 = (
		get_global_mouse_position()
		+ _drag_offset
	)

	if keep_inside_parent:
		global_position = _get_clamped_global_position(
			target_global_position
		)
	else:
		global_position = target_global_position

	accept_event()


func _center_in_parent() -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		return

	position = (parent_control.size - size) * 0.5
	position = _get_clamped_local_position(position)


func play_close_animation() -> void:
	if _is_transitioning:
		return

	_kill_transition_tween()
	_set_transitioning(true)
	_is_dragging = false
	pivot_offset = size * 0.5
	content_margin.visible = false

	var title_scale: float = _get_title_height_scale()
	_transition_tween = create_tween()
	_transition_tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)
	_transition_tween.tween_property(
		self,
		"scale:y",
		title_scale,
		transition_step_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)
	await _transition_tween.finished

	if not is_inside_tree():
		return

	_transition_tween = create_tween()
	_transition_tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)
	_transition_tween.tween_property(
		self,
		"scale:x",
		0.015,
		transition_step_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)
	await _transition_tween.finished

	visible = false
	scale = Vector2.ONE
	_set_transitioning(false)


func play_open_animation() -> void:
	if _is_transitioning:
		return

	_kill_transition_tween()
	_set_transitioning(true)
	pivot_offset = size * 0.5
	content_margin.visible = false
	scale = Vector2(
		0.015,
		_get_title_height_scale()
	)
	visible = true

	_transition_tween = create_tween()
	_transition_tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)
	_transition_tween.tween_property(
		self,
		"scale:x",
		1.0,
		transition_step_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
	await _transition_tween.finished

	if not is_inside_tree():
		return

	_transition_tween = create_tween()
	_transition_tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)
	_transition_tween.tween_property(
		self,
		"scale:y",
		1.0,
		transition_step_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
	await _transition_tween.finished

	content_margin.visible = true
	scale = Vector2.ONE
	_set_transitioning(false)


func _on_viewport_size_changed() -> void:
	if not keep_inside_parent:
		return

	call_deferred("_clamp_current_position")


func _clamp_current_position() -> void:
	position = _get_clamped_local_position(position)


func _get_clamped_global_position(
	desired_global_position: Vector2
) -> Vector2:
	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		return desired_global_position

	var parent_rect: Rect2 = parent_control.get_global_rect()
	var desired_local_position: Vector2 = (
		desired_global_position
		- parent_rect.position
	)
	return (
		parent_rect.position
		+ _get_clamped_local_position(
			desired_local_position
		)
	)


func _get_clamped_local_position(
	desired_position: Vector2
) -> Vector2:
	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		return desired_position

	var maximum_position: Vector2 = Vector2(
		maxf(0.0, parent_control.size.x - size.x),
		maxf(0.0, parent_control.size.y - size.y)
	)

	return Vector2(
		clampf(
			desired_position.x,
			0.0,
			maximum_position.x
		),
		clampf(
			desired_position.y,
			0.0,
			maximum_position.y
		)
	)


func _on_close_button_pressed() -> void:
	if _is_transitioning:
		return

	close_requested.emit()


func _show_initial_window() -> void:
	_center_in_parent()
	await play_open_animation()


func _get_title_height_scale() -> float:
	if size.y <= 0.0:
		return 0.06

	return clampf(
		title_bar.size.y / size.y,
		0.03,
		0.25
	)


func _set_transitioning(active: bool) -> void:
	_is_transitioning = active
	animation_input_blocker.visible = active


func _kill_transition_tween() -> void:
	if _transition_tween == null:
		return

	if _transition_tween.is_running():
		_transition_tween.kill()

	_transition_tween = null
