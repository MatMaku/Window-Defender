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

	set_integrity(0, 1)


func set_integrity(
	current_integrity: int,
	max_integrity: int
) -> void:
	var safe_max_integrity: int = maxi(
		1,
		max_integrity
	)

	var safe_current_integrity: int = clampi(
		current_integrity,
		0,
		safe_max_integrity
	)

	var integrity_percent: int = roundi(
		(
			float(safe_current_integrity)
			/ float(safe_max_integrity)
		) * 100.0
	)

	integrity_progress_bar.max_value = float(
		safe_max_integrity
	)

	integrity_progress_bar.value = float(
		safe_current_integrity
	)

	integrity_header_label.text = (
		"SYSTEM INTEGRITY: %d%%"
		% integrity_percent
	)

func present_system_failure() -> void:
	integrity_header_label.text = "SYSTEM FAILURE"
	integrity_progress_bar.value = 0.0
