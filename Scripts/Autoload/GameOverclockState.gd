extends Node
class_name GameOverclockState

signal phase_changed(phase: int)
signal overclock_ready
signal overclock_started(multiplier: float, duration_seconds: float)
signal overclock_time_changed(remaining_seconds: int)
signal overclock_finished
signal overclock_cooldown_changed(remaining_seconds: int)
signal attempt_resolved(success: bool)

enum Phase {
	COOLDOWN,
	READY,
	TYPING,
	ACTIVE
}

@export var config: OverclockConfigData

var phase: int:
	get:
		return _phase

var cooldown_remaining: float:
	get:
		return _cooldown_remaining

var effect_remaining: float:
	get:
		return _effect_remaining

var current_instruction: String:
	get:
		return _current_instruction

var _phase: int = Phase.COOLDOWN
var _cooldown_remaining: float = 0.0
var _effect_remaining: float = 0.0
var _active_income_multiplier: float = 1.0
var _current_instruction: String = ""
var _last_instruction: String = ""

var _last_emitted_cooldown_second: int = -1
var _last_emitted_effect_second: int = -1
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_ensure_config()
	_random.randomize()


func reset() -> void:
	_ensure_config()
	_phase = Phase.COOLDOWN
	_cooldown_remaining = maxf(
		0.0,
		config.initial_cooldown_seconds
	)
	_effect_remaining = 0.0
	_active_income_multiplier = 1.0
	_current_instruction = ""
	_last_instruction = ""
	_reset_emitted_seconds()

	if _cooldown_remaining <= 0.0:
		_enter_ready()
		return

	phase_changed.emit(_phase)
	_emit_cooldown_time(true)
	overclock_time_changed.emit(0)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return

	match _phase:
		Phase.COOLDOWN:
			_advance_cooldown(delta)
		Phase.ACTIVE:
			_advance_active_effect(delta)


func begin_typing() -> bool:
	if _phase != Phase.READY:
		return false

	_set_phase(Phase.TYPING)
	return true


func cancel_typing() -> void:
	if _phase != Phase.TYPING:
		return

	_set_phase(Phase.READY)


func submit_attempt(input_text: String) -> bool:
	if _phase != Phase.READY and _phase != Phase.TYPING:
		return false

	var succeeded: bool = input_text == _current_instruction
	if succeeded:
		_start_active_effect()
	else:
		_start_cooldown()

	attempt_resolved.emit(succeeded)
	return succeeded


func is_effect_active() -> bool:
	return _phase == Phase.ACTIVE and _effect_remaining > 0.0


func get_income_multiplier() -> float:
	if not is_effect_active():
		return 1.0

	return maxf(1.0, _active_income_multiplier)


func get_cooldown_display_seconds() -> int:
	return ceili(maxf(0.0, _cooldown_remaining))


func get_effect_display_seconds() -> int:
	return ceili(maxf(0.0, _effect_remaining))


func create_save_snapshot() -> Dictionary:
	var saved_phase: int = _phase
	if saved_phase == Phase.TYPING:
		saved_phase = Phase.READY

	return {
		"phase": saved_phase,
		"cooldown_remaining": maxf(0.0, _cooldown_remaining),
		"effect_remaining": maxf(0.0, _effect_remaining),
		"income_multiplier": get_income_multiplier(),
		"current_instruction": _current_instruction
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	_ensure_config()
	if snapshot.is_empty():
		reset()
		return

	_phase = clampi(
		int(snapshot.get("phase", Phase.COOLDOWN)),
		Phase.COOLDOWN,
		Phase.ACTIVE
	)
	if _phase == Phase.TYPING:
		_phase = Phase.READY

	_cooldown_remaining = maxf(
		0.0,
		float(snapshot.get("cooldown_remaining", 0.0))
	)
	_effect_remaining = maxf(
		0.0,
		float(snapshot.get("effect_remaining", 0.0))
	)
	_active_income_multiplier = maxf(
		1.0,
		float(snapshot.get("income_multiplier", 1.0))
	)
	_current_instruction = str(
		snapshot.get("current_instruction", "")
	)
	_last_instruction = _current_instruction

	_normalize_restored_state()
	_reset_emitted_seconds()
	phase_changed.emit(_phase)
	_emit_cooldown_time(true)
	_emit_effect_time(true)


func _advance_cooldown(delta: float) -> void:
	_cooldown_remaining = maxf(
		0.0,
		_cooldown_remaining - delta
	)
	_emit_cooldown_time()

	if _cooldown_remaining <= 0.0:
		_enter_ready()


func _advance_active_effect(delta: float) -> void:
	_effect_remaining = maxf(
		0.0,
		_effect_remaining - delta
	)
	_emit_effect_time()

	if _effect_remaining > 0.0:
		return

	overclock_finished.emit()
	_start_cooldown()


func _start_active_effect() -> void:
	_current_instruction = ""
	_cooldown_remaining = 0.0
	_effect_remaining = maxf(
		0.05,
		config.effect_duration_seconds
	)
	_active_income_multiplier = maxf(
		1.0,
		config.income_multiplier
	)
	_set_phase(Phase.ACTIVE)
	_emit_effect_time(true)
	overclock_started.emit(
		_active_income_multiplier,
		_effect_remaining
	)


func _start_cooldown() -> void:
	_current_instruction = ""
	_effect_remaining = 0.0
	_active_income_multiplier = 1.0
	_cooldown_remaining = maxf(
		0.0,
		config.cooldown_duration_seconds
	)
	_set_phase(Phase.COOLDOWN)
	_emit_effect_time(true)
	_emit_cooldown_time(true)

	if _cooldown_remaining <= 0.0:
		_enter_ready()


func _enter_ready() -> void:
	_cooldown_remaining = 0.0
	_effect_remaining = 0.0
	_active_income_multiplier = 1.0
	_select_next_instruction()
	_set_phase(Phase.READY)
	_emit_cooldown_time(true)
	overclock_ready.emit()


func _select_next_instruction() -> void:
	var instructions: Array[String] = config.get_instructions_copy()
	if instructions.is_empty():
		_current_instruction = "overclock economy --apply"
		_last_instruction = _current_instruction
		return

	var selected_index: int = _random.randi_range(
		0,
		instructions.size() - 1
	)
	if instructions.size() > 1 and instructions[selected_index] == (
		_last_instruction
	):
		selected_index = (selected_index + 1) % instructions.size()

	_current_instruction = instructions[selected_index]
	_last_instruction = _current_instruction


func _normalize_restored_state() -> void:
	match _phase:
		Phase.ACTIVE:
			_current_instruction = ""
			_cooldown_remaining = 0.0
			if _effect_remaining <= 0.0:
				_start_cooldown_without_signals()
		Phase.READY:
			_effect_remaining = 0.0
			_active_income_multiplier = 1.0
			_cooldown_remaining = 0.0
			if _current_instruction.is_empty():
				_select_next_instruction()
		_:
			_effect_remaining = 0.0
			_active_income_multiplier = 1.0
			_current_instruction = ""
			if _cooldown_remaining <= 0.0:
				_phase = Phase.READY
				_select_next_instruction()


func _start_cooldown_without_signals() -> void:
	_phase = Phase.COOLDOWN
	_effect_remaining = 0.0
	_active_income_multiplier = 1.0
	_cooldown_remaining = maxf(
		0.0,
		config.cooldown_duration_seconds
	)
	if _cooldown_remaining <= 0.0:
		_phase = Phase.READY
		_select_next_instruction()


func _set_phase(new_phase: int) -> void:
	if _phase == new_phase:
		return

	_phase = new_phase
	phase_changed.emit(_phase)


func _emit_cooldown_time(force: bool = false) -> void:
	var display_seconds: int = get_cooldown_display_seconds()
	if not force and display_seconds == _last_emitted_cooldown_second:
		return

	_last_emitted_cooldown_second = display_seconds
	overclock_cooldown_changed.emit(display_seconds)


func _emit_effect_time(force: bool = false) -> void:
	var display_seconds: int = get_effect_display_seconds()
	if not force and display_seconds == _last_emitted_effect_second:
		return

	_last_emitted_effect_second = display_seconds
	overclock_time_changed.emit(display_seconds)


func _reset_emitted_seconds() -> void:
	_last_emitted_cooldown_second = -1
	_last_emitted_effect_second = -1


func _ensure_config() -> void:
	if config != null:
		return

	config = OverclockConfigData.new()
