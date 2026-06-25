extends AppWindow
class_name ReloadWindow

signal reload_input_requested(window: ReloadWindow)

@export_category("Visuals")
@export var perfect_zone_color: Color = Color(0.40, 1.0, 0.50, 0.5)
@export var penalty_color: Color = Color(1.0, 0.45, 0.45, 0.5)
@export var perfect_color: Color = Color(0.4, 0.502, 1.0, 0.502)

@onready var reload_button: Button = %ReloadButton
@onready var reload_progress_bar: ProgressBar = %ReloadProgressBar
@onready var perfect_zone_marker: ColorRect = %PerfectZoneMarker
@onready var status_label: Label = %StatusLabel

var _perfect_zone_start: float = 0.0
var _perfect_zone_width: float = 0.0


func _ready() -> void:
	super._ready()

	reload_button.pressed.connect(_on_reload_button_pressed)
	reload_progress_bar.resized.connect(_update_perfect_zone_layout)

	present_idle()
	call_deferred("_update_perfect_zone_layout")


func present_idle() -> void:
	reload_progress_bar.value = 0.0
	reload_progress_bar.modulate = Color.WHITE

	perfect_zone_marker.visible = false
	reload_button.disabled = false
	status_label.text = "READY"


func present_reload_started(
	perfect_zone_start: float,
	perfect_zone_width: float
) -> void:
	_perfect_zone_start = clampf(perfect_zone_start, 0.0, 1.0)
	_perfect_zone_width = clampf(perfect_zone_width, 0.01, 1.0)

	reload_progress_bar.value = 0.0
	reload_progress_bar.modulate = Color.WHITE

	perfect_zone_marker.color = perfect_zone_color
	perfect_zone_marker.visible = true

	reload_button.disabled = false
	status_label.text = "PRESS RELOAD ON THE MARKER"

	call_deferred("_update_perfect_zone_layout")


func present_reload_progress(progress_ratio: float) -> void:
	var clamped_progress: float = clampf(progress_ratio, 0.0, 1.0)

	reload_progress_bar.value = clamped_progress * 100.0


func present_penalty_started() -> void:
	perfect_zone_marker.visible = false
	reload_progress_bar.modulate = penalty_color

	reload_button.disabled = true
	status_label.text = "JAMMED"


func present_penalty_finished() -> void:
	reload_progress_bar.modulate = Color.WHITE

	reload_button.disabled = true
	status_label.text = "RELOADING..."


func present_perfect_reload() -> void:
	perfect_zone_marker.visible = false
	reload_progress_bar.value = 100.0
	reload_progress_bar.modulate = perfect_color

	reload_button.disabled = true
	status_label.text = "PERFECT RELOAD"


func present_reload_completed() -> void:
	reload_progress_bar.value = 0
	reload_progress_bar.modulate = Color.WHITE

	perfect_zone_marker.visible = false
	reload_button.disabled = false
	status_label.text = "RELOADED"


func show_rejection(message: String) -> void:
	status_label.text = message


func _on_reload_button_pressed() -> void:
	reload_input_requested.emit(self)


func _update_perfect_zone_layout() -> void:
	var safe_start: float = clampf(_perfect_zone_start, 0.0, 1.0)
	var safe_width: float = minf(
		_perfect_zone_width,
		1.0 - safe_start
	)

	var marker_width: float = maxf(
		8.0,
		reload_progress_bar.size.x * safe_width
	)

	var marker_x: float = reload_progress_bar.size.x * safe_start

	perfect_zone_marker.position = reload_progress_bar.position + Vector2(
		marker_x,
		0.0
	)

	perfect_zone_marker.size = Vector2(
		marker_width,
		reload_progress_bar.size.y
	)
