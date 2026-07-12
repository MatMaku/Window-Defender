extends AppWindow
class_name RepairWindow

enum RepairPresentationState {
	IDLE,
	REPAIRING,
	BLOCKED,
	FULL,
	NO_TARGET
}

@export_category("Node Paths")

@export var repair_area_path: NodePath = (
	^"MainVBox/ContentRoot/RepairArea"
)

@export var repair_pulse_path: NodePath = (
	^"MainVBox/ContentRoot/RepairArea/RepairPulse"
)

@export var status_label_path: NodePath = (
	^"MainVBox/ContentRoot/RepairArea/StatusLabel"
)

@export_category("Status Text")

@export var idle_text: String = "PLACE ON SYSTEM.EXE"
@export var repairing_text: String = "REPAIRING..."
@export var blocked_text: String = "CONTACT BLOCKED"
@export var full_text: String = "SYSTEM FULL"
@export var no_target_text: String = "NO SYSTEM TARGET"

@export_category("Pulse")

@export var pulse_enabled: bool = true

@export_range(0.05, 2.0, 0.01)
var pulse_duration: float = 0.42

@export_range(0.0, 1.0, 0.01)
var pulse_min_alpha: float = 0.18

@export_range(0.0, 1.0, 0.01)
var pulse_max_alpha: float = 0.75

@export var pulse_color: Color = Color(0.15, 1.0, 0.35, 1.0)

@onready var repair_area: Control = (
	get_node_or_null(repair_area_path)
	as Control
)

@onready var repair_pulse: Control = (
	get_node_or_null(repair_pulse_path)
	as Control
)

@onready var status_label: Label = (
	get_node_or_null(status_label_path)
	as Label
)

var _presentation_state: int = RepairPresentationState.IDLE
var _pulse_tween: Tween


func _ready() -> void:
	super._ready()

	blocks_shots = true

	_configure_repair_area()
	_configure_repair_pulse()
	_configure_status_label()

	present_idle()


func get_repair_global_rect() -> Rect2:
	if repair_area != null:
		return repair_area.get_global_rect()

	return get_global_rect()


func present_idle() -> void:
	_set_presentation_state(
		RepairPresentationState.IDLE,
		idle_text,
		false
	)


func present_repairing() -> void:
	_set_presentation_state(
		RepairPresentationState.REPAIRING,
		repairing_text,
		true
	)


func present_blocked() -> void:
	_set_presentation_state(
		RepairPresentationState.BLOCKED,
		blocked_text,
		false
	)


func present_full() -> void:
	_set_presentation_state(
		RepairPresentationState.FULL,
		full_text,
		false
	)


func present_no_target() -> void:
	_set_presentation_state(
		RepairPresentationState.NO_TARGET,
		no_target_text,
		false
	)


func _configure_repair_area() -> void:
	if repair_area == null:
		return

	repair_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_repair_pulse() -> void:
	if repair_pulse == null:
		return

	repair_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	repair_pulse.visible = false
	repair_pulse.modulate = Color(
		1.0,
		1.0,
		1.0,
		pulse_min_alpha
	)

	var pulse_panel: Panel = repair_pulse as Panel

	if pulse_panel == null:
		return

	var style_box: StyleBoxFlat = StyleBoxFlat.new()

	style_box.bg_color = Color(
		pulse_color.r,
		pulse_color.g,
		pulse_color.b,
		0.04
	)

	style_box.border_color = pulse_color
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(2)

	pulse_panel.add_theme_stylebox_override(
		"panel",
		style_box
	)


func _configure_status_label() -> void:
	if status_label == null:
		return

	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _set_presentation_state(
	new_state: int,
	status_text: String,
	should_pulse: bool
) -> void:
	if _presentation_state == new_state:
		return

	_presentation_state = new_state

	if status_label != null:
		status_label.text = status_text

	if should_pulse:
		_start_repair_pulse()
	else:
		_stop_repair_pulse()


func _start_repair_pulse() -> void:
	if not pulse_enabled:
		return

	if repair_pulse == null:
		return

	repair_pulse.visible = true

	if _pulse_tween != null and _pulse_tween.is_running():
		return

	repair_pulse.modulate = Color(
		1.0,
		1.0,
		1.0,
		pulse_min_alpha
	)

	_pulse_tween = create_tween()
	_pulse_tween.set_loops()

	_pulse_tween.tween_property(
		repair_pulse,
		"modulate:a",
		pulse_max_alpha,
		pulse_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_pulse_tween.tween_property(
		repair_pulse,
		"modulate:a",
		pulse_min_alpha,
		pulse_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_repair_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_running():
		_pulse_tween.kill()

	if repair_pulse == null:
		return

	repair_pulse.visible = false
