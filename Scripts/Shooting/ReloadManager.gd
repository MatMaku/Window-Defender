extends Node
class_name ReloadManager

enum ReloadState {
	IDLE,
	RELOADING,
	PENALTY,
	PERFECT_FINISH
}

enum ReloadRejectionReason {
	ALREADY_RELOADING,
	AMMO_FULL,
	WEAPON_BUSY
}

signal reload_started()
signal reload_penalty_started()
signal perfect_reload_triggered()
signal reload_completed()
signal reload_rejected(reason: int)

@export var window_manager: WindowManager
@export var shooting_manager: ShootingManager

@export_category("Reload Timing Fallback")

@export_range(0.1, 5.0, 0.01)
var normal_reload_duration: float = 1.45

@export_range(0.01, 1.0, 0.01)
var perfect_finish_delay: float = 0.10

@export_range(0.1, 5.0, 0.01)
var failure_penalty_duration: float = 0.85

@export_category("Active Reload Zone")

@export_range(0.0, 0.95, 0.01)
var perfect_zone_start: float = 0.60

@export_range(0.01, 0.40, 0.01)
var perfect_zone_width: float = 0.14

var _state: int = ReloadState.IDLE

var _normal_elapsed: float = 0.0
var _penalty_remaining: float = 0.0
var _perfect_finish_remaining: float = 0.0

var _perfect_check_available: bool = false

var _reload_window: ReloadWindow


func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	_connect_signals()
	_apply_reload_stats_from_game_state()
	_register_existing_reload_window()


func _process(delta: float) -> void:
	match _state:
		ReloadState.RELOADING:
			_advance_normal_reload(delta)

		ReloadState.PENALTY:
			_advance_penalty(delta)

		ReloadState.PERFECT_FINISH:
			_advance_perfect_finish(delta)


# ================================================================
# SETUP
# ================================================================

func _resolve_references() -> void:
	if window_manager == null:
		window_manager = (
			get_node_or_null("../WindowManager")
			as WindowManager
		)

	if shooting_manager == null:
		shooting_manager = (
			get_node_or_null("../ShootingManager")
			as ShootingManager
		)


func _validate_dependencies() -> bool:
	if window_manager == null:
		push_error("ReloadManager requires a WindowManager reference.")
		return false

	if shooting_manager == null:
		push_error("ReloadManager requires a ShootingManager reference.")
		return false

	return true


func _connect_signals() -> void:
	if not window_manager.window_opened.is_connected(
		_on_window_opened
	):
		window_manager.window_opened.connect(
			_on_window_opened
		)

	if not window_manager.window_closed.is_connected(
		_on_window_closed
	):
		window_manager.window_closed.connect(
			_on_window_closed
		)

	if not GameState.reload_stats_changed.is_connected(
		_on_game_state_reload_stats_changed
	):
		GameState.reload_stats_changed.connect(
			_on_game_state_reload_stats_changed
		)


func _apply_reload_stats_from_game_state() -> void:
	_apply_reload_stats(
		GameState.normal_reload_duration,
		GameState.perfect_reload_finish_delay,
		GameState.reload_failure_penalty_duration
	)


func _on_game_state_reload_stats_changed(
	new_normal_reload_duration: float,
	new_perfect_finish_delay: float,
	new_failure_penalty_duration: float
) -> void:
	_apply_reload_stats(
		new_normal_reload_duration,
		new_perfect_finish_delay,
		new_failure_penalty_duration
	)


func _apply_reload_stats(
	new_normal_reload_duration: float,
	new_perfect_finish_delay: float,
	new_failure_penalty_duration: float
) -> void:
	normal_reload_duration = maxf(
		0.05,
		new_normal_reload_duration
	)

	perfect_finish_delay = maxf(
		0.0,
		new_perfect_finish_delay
	)

	failure_penalty_duration = maxf(
		0.0,
		new_failure_penalty_duration
	)

	_clamp_current_timers_to_reload_stats()
	_sync_reload_window()


func _clamp_current_timers_to_reload_stats() -> void:
	_normal_elapsed = clampf(
		_normal_elapsed,
		0.0,
		normal_reload_duration
	)

	_penalty_remaining = clampf(
		_penalty_remaining,
		0.0,
		failure_penalty_duration
	)

	_perfect_finish_remaining = clampf(
		_perfect_finish_remaining,
		0.0,
		perfect_finish_delay
	)


# ================================================================
# WINDOW BINDING
# ================================================================

func _on_window_opened(
	window: AppWindow,
	_program_data: ProgramData
) -> void:
	var reload_window: ReloadWindow = window as ReloadWindow

	if reload_window == null:
		return

	_bind_reload_window(reload_window)


func _on_window_closed(window: AppWindow) -> void:
	if window != _reload_window:
		return

	_reload_window = null


func _bind_reload_window(window: ReloadWindow) -> void:
	if _reload_window == window:
		return

	_reload_window = window

	if not window.reload_input_requested.is_connected(
		_on_reload_input_requested
	):
		window.reload_input_requested.connect(
			_on_reload_input_requested
		)

	_sync_reload_window()


func _register_existing_reload_window() -> void:
	if window_manager.window_layer == null:
		return

	for child: Node in window_manager.window_layer.get_children():
		var reload_window: ReloadWindow = child as ReloadWindow

		if reload_window == null:
			continue

		_bind_reload_window(reload_window)
		return


# ================================================================
# INPUT
# ================================================================

func _on_reload_input_requested(window: ReloadWindow) -> void:
	if window != _reload_window:
		_bind_reload_window(window)

	match _state:
		ReloadState.IDLE:
			_try_start_reload()

		ReloadState.RELOADING:
			_try_active_reload()


func _try_start_reload() -> void:
	if shooting_manager.is_reloading():
		_reject_reload(ReloadRejectionReason.ALREADY_RELOADING)
		return

	if shooting_manager.has_full_ammo():
		_reject_reload(ReloadRejectionReason.AMMO_FULL)
		return

	if not shooting_manager.can_start_reload():
		_reject_reload(ReloadRejectionReason.WEAPON_BUSY)
		return

	_state = ReloadState.RELOADING

	_normal_elapsed = 0.0
	_penalty_remaining = 0.0
	_perfect_finish_remaining = 0.0
	_perfect_check_available = true

	shooting_manager.set_reloading(true)

	_present_reload_started()
	_present_reload_progress(0.0)

	reload_started.emit()


func _try_active_reload() -> void:
	if not _perfect_check_available:
		return

	var current_progress: float = _get_normal_progress()

	if _is_inside_perfect_zone(current_progress):
		_start_perfect_finish()
		return

	_start_penalty()


# ================================================================
# STATE ADVANCE
# ================================================================

func _advance_normal_reload(delta: float) -> void:
	_normal_elapsed = minf(
		_normal_elapsed + delta,
		normal_reload_duration
	)

	var current_progress: float = _get_normal_progress()

	_present_reload_progress(current_progress)

	if _normal_elapsed >= normal_reload_duration:
		_complete_reload()


func _advance_penalty(delta: float) -> void:
	_penalty_remaining = maxf(
		0.0,
		_penalty_remaining - delta
	)

	if _penalty_remaining > 0.0:
		return

	_state = ReloadState.RELOADING
	_present_penalty_finished()


func _advance_perfect_finish(delta: float) -> void:
	_perfect_finish_remaining = maxf(
		0.0,
		_perfect_finish_remaining - delta
	)

	if _perfect_finish_remaining > 0.0:
		return

	_complete_reload()


# ================================================================
# STATE CHANGES
# ================================================================

func _start_penalty() -> void:
	_state = ReloadState.PENALTY

	_penalty_remaining = failure_penalty_duration
	_perfect_check_available = false

	_present_penalty_started()
	reload_penalty_started.emit()


func _start_perfect_finish() -> void:
	_state = ReloadState.PERFECT_FINISH

	_perfect_finish_remaining = perfect_finish_delay
	_perfect_check_available = false

	_present_perfect_reload()
	perfect_reload_triggered.emit()


func _complete_reload() -> void:
	shooting_manager.complete_reload()
	shooting_manager.set_reloading(false)

	_state = ReloadState.IDLE

	_normal_elapsed = 0.0
	_penalty_remaining = 0.0
	_perfect_finish_remaining = 0.0
	_perfect_check_available = false

	_present_reload_completed()
	reload_completed.emit()


func _reject_reload(reason: int) -> void:
	reload_rejected.emit(reason)

	match reason:
		ReloadRejectionReason.ALREADY_RELOADING:
			_present_rejection("RELOAD ALREADY ACTIVE")

		ReloadRejectionReason.AMMO_FULL:
			_present_rejection("MAGAZINE FULL")

		ReloadRejectionReason.WEAPON_BUSY:
			_present_rejection("WEAPON BUSY")


# ================================================================
# HELPERS
# ================================================================

func _get_normal_progress() -> float:
	if normal_reload_duration <= 0.0:
		return 1.0

	return clampf(
		_normal_elapsed / normal_reload_duration,
		0.0,
		1.0
	)


func _is_inside_perfect_zone(progress: float) -> bool:
	var zone_start: float = clampf(
		perfect_zone_start,
		0.0,
		1.0
	)

	var zone_end: float = minf(
		1.0,
		zone_start + perfect_zone_width
	)

	return (
		progress >= zone_start
		and progress <= zone_end
	)


# ================================================================
# PRESENTATION
# ================================================================

func _present_reload_started() -> void:
	if not is_instance_valid(_reload_window):
		return

	_reload_window.present_reload_started(
		perfect_zone_start,
		perfect_zone_width
	)


func _present_reload_progress(progress: float) -> void:
	if not is_instance_valid(_reload_window):
		return

	_reload_window.present_reload_progress(progress)


func _present_penalty_started() -> void:
	if not is_instance_valid(_reload_window):
		return

	_reload_window.present_penalty_started()


func _present_penalty_finished() -> void:
	if not is_instance_valid(_reload_window):
		return

	_reload_window.present_penalty_finished()


func _present_perfect_reload() -> void:
	if not is_instance_valid(_reload_window):
		return

	_reload_window.present_perfect_reload()


func _present_reload_completed() -> void:
	if not is_instance_valid(_reload_window):
		return

	_reload_window.present_reload_completed()


func _present_rejection(message: String) -> void:
	if not is_instance_valid(_reload_window):
		return

	_reload_window.show_rejection(message)


func _sync_reload_window() -> void:
	if not is_instance_valid(_reload_window):
		return

	match _state:
		ReloadState.IDLE:
			_reload_window.present_idle()

		ReloadState.RELOADING:
			_reload_window.present_reload_started(
				perfect_zone_start,
				perfect_zone_width
			)

			_reload_window.present_reload_progress(
				_get_normal_progress()
			)

			if not _perfect_check_available:
				_reload_window.present_penalty_finished()

		ReloadState.PENALTY:
			_reload_window.present_reload_started(
				perfect_zone_start,
				perfect_zone_width
			)

			_reload_window.present_reload_progress(
				_get_normal_progress()
			)

			_reload_window.present_penalty_started()

		ReloadState.PERFECT_FINISH:
			_reload_window.present_perfect_reload()
