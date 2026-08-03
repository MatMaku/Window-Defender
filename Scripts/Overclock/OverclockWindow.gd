extends AppWindow
class_name OverclockWindow

signal typing_started(window: OverclockWindow)
signal attempt_submitted(
	window: OverclockWindow,
	input_text: String
)

@export_category("Console")

@export_range(4, 100, 1)
var maximum_history_lines: int = 24

@export var correct_input_color: Color = Color(
	0.25,
	1.0,
	0.35,
	1.0
)

@export var incorrect_input_color: Color = Color(
	1.0,
	0.25,
	0.25,
	1.0
)

@export var inactive_input_color: Color = Color(
	0.55,
	0.65,
	0.55,
	1.0
)

@onready var output_text: RichTextLabel = %OutputText
@onready var command_input: OverclockCommandInput = %CommandInput

var _overclock_state: GameOverclockState
var _history_lines: Array[String] = []


func _ready() -> void:
	super._ready()
	_overclock_state = GameState.overclock_state
	if not _validate_dependencies():
		return

	_connect_input_signals()
	_connect_state_signals()
	opening_finished.connect(_on_opening_finished)

	_append_history("Securitysoft(R) Overclock Console")
	_append_history("Copyright 1998 Defender 98")
	_refresh_presentation()


func play_restore_reveal_animation(
	total_duration: float = 0.1
) -> void:
	await super.play_restore_reveal_animation(total_duration)
	_focus_input_if_available()


func _connect_input_signals() -> void:
	command_input.text_changed.connect(_on_input_text_changed)
	command_input.command_submitted.connect(
		_on_command_submitted
	)


func _connect_state_signals() -> void:
	_overclock_state.phase_changed.connect(_on_phase_changed)
	_overclock_state.overclock_time_changed.connect(
		_on_remaining_time_changed
	)
	_overclock_state.overclock_cooldown_changed.connect(
		_on_remaining_time_changed
	)
	_overclock_state.attempt_resolved.connect(
		_on_attempt_resolved
	)


func _on_input_text_changed(new_text: String) -> void:
	if not _can_accept_input():
		return

	if (
		not new_text.is_empty()
		and _overclock_state.phase
		== GameOverclockState.Phase.READY
	):
		typing_started.emit(self)

	var expected_command: String = (
		_overclock_state.current_instruction
	)
	var input_color: Color = correct_input_color
	if (
		not new_text.is_empty()
		and not expected_command.begins_with(new_text)
	):
		input_color = incorrect_input_color

	command_input.add_theme_color_override(
		"font_color",
		input_color
	)


func _on_command_submitted(input_text: String) -> void:
	if not _can_accept_input():
		return

	_append_history("> %s" % input_text)
	command_input.clear()
	attempt_submitted.emit(self, input_text)


func _on_phase_changed(_phase: int) -> void:
	_refresh_presentation()
	_focus_input_if_available()


func _on_remaining_time_changed(
	_remaining_seconds: int
) -> void:
	_refresh_output()


func _on_attempt_resolved(success: bool) -> void:
	if success:
		var multiplier: float = maxf(
			1.0,
			_overclock_state.config.income_multiplier
		)
		_append_history("OVERCLOCK ENABLED")
		_append_history(
			"Income output multiplier active: %.0f%%."
				% (multiplier * 100.0)
		)
	else:
		_append_history("COMMAND FAILED")
		_append_history(
			"Input does not match the required sequence."
		)

	_refresh_presentation()


func _on_opening_finished(_window: AppWindow) -> void:
	_focus_input_if_available()


func _refresh_presentation() -> void:
	_refresh_input_state()
	_refresh_output()


func _refresh_input_state() -> void:
	var can_type: bool = _can_accept_input()
	command_input.editable = can_type
	command_input.placeholder_text = (
		"> type command"
		if can_type
		else "> unavailable"
	)

	if not can_type:
		command_input.clear()
		command_input.add_theme_color_override(
			"font_uneditable_color",
			inactive_input_color
		)
		return

	_on_input_text_changed(command_input.text)


func _refresh_output() -> void:
	var lines: Array[String] = _history_lines.duplicate()
	lines.append("")
	lines.append_array(_get_status_lines())
	output_text.text = "\n".join(lines)
	call_deferred("_scroll_output_to_bottom")


func _get_status_lines() -> Array[String]:
	match _overclock_state.phase:
		GameOverclockState.Phase.COOLDOWN:
			return [
				"Cooling down.",
				"Available in: %s" % _format_duration(
					_overclock_state.get_cooldown_display_seconds()
				)
			]
		GameOverclockState.Phase.ACTIVE:
			return [
				"OVERCLOCK ACTIVE",
				"Income multiplier: %.2fx" % (
					_overclock_state.get_income_multiplier()
				),
				"Time remaining: %s" % _format_duration(
					_overclock_state.get_effect_display_seconds()
				)
			]
		_:
			return [
				"Overclock ready. Type the required command:",
				_overclock_state.current_instruction
			]


func _append_history(line: String) -> void:
	_history_lines.append(line)
	while _history_lines.size() > maxi(4, maximum_history_lines):
		_history_lines.remove_at(0)


func _scroll_output_to_bottom() -> void:
	if output_text == null:
		return

	output_text.scroll_to_line(
		maxi(0, output_text.get_line_count() - 1)
	)


func _focus_input_if_available() -> void:
	if not is_inside_tree() or not visible:
		return

	if not _can_accept_input():
		return

	command_input.grab_focus()
	command_input.caret_column = command_input.text.length()


func _can_accept_input() -> bool:
	if _overclock_state == null:
		return false

	return (
		_overclock_state.phase == GameOverclockState.Phase.READY
		or _overclock_state.phase
		== GameOverclockState.Phase.TYPING
	)


func _format_duration(total_seconds: int) -> String:
	var safe_seconds: int = maxi(0, total_seconds)
	return "%02d:%02d" % [
		safe_seconds / 60,
		safe_seconds % 60
	]


func _validate_dependencies() -> bool:
	if _overclock_state == null:
		push_error("OverclockWindow requires GameOverclockState.")
		return false

	if output_text == null:
		push_error("OverclockWindow could not find OutputText.")
		return false

	if command_input == null:
		push_error("OverclockWindow could not find CommandInput.")
		return false

	return true
