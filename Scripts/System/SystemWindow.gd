extends AppWindow
class_name SystemWindow

@onready var integrity_header_label: Label = (
	%IntegrityHeaderLabel
)

@onready var integrity_progress_bar: ProgressBar = (
	%IntegrityProgressBar
)

func _ready() -> void:
	super._ready()

	set_integrity(0.0, 1.0)


func set_integrity(
	current_integrity: float,
	max_integrity: float
) -> void:
	var safe_max_integrity: float = maxf(
		0.001,
		max_integrity
	)

	var safe_current_integrity: float = clampf(
		current_integrity,
		0.0,
		safe_max_integrity
	)

	var integrity_percent: int = roundi(
		(
			safe_current_integrity
			/ safe_max_integrity
		) * 100.0
	)

	integrity_progress_bar.max_value = safe_max_integrity
	integrity_progress_bar.value = safe_current_integrity

	integrity_header_label.text = (
		"SYSTEM INTEGRITY: %d%%"
		% integrity_percent
	)

func present_system_failure() -> void:
	integrity_header_label.text = "SYSTEM FAILURE"
	integrity_progress_bar.value = 0.0


func _format_integrity(value: float) -> String:
	var rounded_value: float = roundf(value)

	if is_equal_approx(value, rounded_value):
		return str(int(rounded_value))

	return "%.1f" % value
