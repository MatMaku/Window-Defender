extends Node
class_name ShootingManager

enum ShotRejectionReason {
	EMPTY_AMMO,
	COOLDOWN_ACTIVE,
	RELOADING
}

signal ammo_changed(
	current_ammo: int,
	max_ammo: int
)

signal cooldown_started(duration: float)
signal cooldown_finished()

signal shot_fired(
	target_global_position: Vector2,
	damage_amount: float
)

signal shot_blocked(
	target_global_position: Vector2
)

signal shot_rejected(reason: ShotRejectionReason)

signal reload_lock_changed(is_reloading: bool)

@export var window_manager: WindowManager

@onready var cooldown_timer: Timer = (
	get_node_or_null("CooldownTimer") as Timer
)

var _shooting_window: ShootingWindow
var _is_reloading: bool = false


func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	_configure_cooldown_timer()
	_connect_signals()
	_register_existing_windows()
	_emit_current_ammo_state()


# ================================================================
# PUBLIC API
# ================================================================

func get_current_ammo() -> int:
	return GameState.current_ammo


func get_max_ammo() -> int:
	return GameState.max_ammo


func is_reloading() -> bool:
	return _is_reloading


func has_full_ammo() -> bool:
	return GameState.current_ammo >= GameState.max_ammo


func can_start_reload() -> bool:
	return (
		not _is_reloading
		and cooldown_timer.is_stopped()
		and not has_full_ammo()
	)


func set_reloading(active: bool) -> void:
	if _is_reloading == active:
		return

	_is_reloading = active

	reload_lock_changed.emit(
		_is_reloading
	)


func refill_ammo() -> void:
	GameState.refill_ammo()


func complete_reload() -> void:
	GameState.refill_ammo()


# ================================================================
# SETUP
# ================================================================

func _resolve_references() -> void:
	if window_manager == null:
		window_manager = (
			get_node_or_null("../WindowManager")
			as WindowManager
		)


func _validate_dependencies() -> bool:
	if window_manager == null:
		push_error(
			"ShootingManager requires a WindowManager reference."
		)
		return false

	if cooldown_timer == null:
		push_error(
			"ShootingManager requires a CooldownTimer child node."
		)
		return false

	return true


func _configure_cooldown_timer() -> void:
	cooldown_timer.one_shot = true


func _connect_signals() -> void:
	if not cooldown_timer.timeout.is_connected(
		_on_cooldown_finished
	):
		cooldown_timer.timeout.connect(
			_on_cooldown_finished
		)

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

	if not GameState.ammo_changed.is_connected(
		_on_game_state_ammo_changed
	):
		GameState.ammo_changed.connect(
			_on_game_state_ammo_changed
		)


# ================================================================
# WINDOW BINDING
# ================================================================

func _on_window_opened(
	window: AppWindow,
	_program_data: ProgramData
) -> void:
	_bind_window_if_relevant(window)


func _on_window_closed(window: AppWindow) -> void:
	var shooting_window: ShootingWindow = (
		window as ShootingWindow
	)

	if shooting_window != null:
		_unbind_shooting_window(shooting_window)

	var ammo_window: AmmoWindow = window as AmmoWindow

	if ammo_window != null:
		_unbind_ammo_window(ammo_window)


func _bind_window_if_relevant(window: AppWindow) -> void:
	if window == null:
		return

	var shooting_window: ShootingWindow = (
		window as ShootingWindow
	)

	if shooting_window != null:
		_bind_shooting_window(shooting_window)

	var ammo_window: AmmoWindow = (
		window as AmmoWindow
	)

	if ammo_window != null:
		_bind_ammo_window(ammo_window)


func _bind_shooting_window(
	window: ShootingWindow
) -> void:
	if _shooting_window == window:
		return

	_shooting_window = window

	if not window.fire_requested.is_connected(
		_on_fire_requested
	):
		window.fire_requested.connect(
			_on_fire_requested
		)


func _unbind_shooting_window(
	window: ShootingWindow
) -> void:
	if window == null:
		return

	if window == _shooting_window:
		_shooting_window = null

	if window.fire_requested.is_connected(
		_on_fire_requested
	):
		window.fire_requested.disconnect(
			_on_fire_requested
		)


func _bind_ammo_window(window: AmmoWindow) -> void:
	if window == null:
		return

	var update_ammo_callable: Callable = (
		window.set_ammo
	)

	if not ammo_changed.is_connected(update_ammo_callable):
		ammo_changed.connect(update_ammo_callable)

	window.set_ammo(
		GameState.current_ammo,
		GameState.max_ammo,
		false
	)


func _unbind_ammo_window(window: AmmoWindow) -> void:
	if window == null:
		return

	var update_ammo_callable: Callable = (
		window.set_ammo
	)

	if ammo_changed.is_connected(update_ammo_callable):
		ammo_changed.disconnect(update_ammo_callable)


func _register_existing_windows() -> void:
	if window_manager.window_layer == null:
		return

	for child: Node in window_manager.window_layer.get_children():
		var window: AppWindow = child as AppWindow

		if window == null:
			continue

		_bind_window_if_relevant(window)


# ================================================================
# FIRE FLOW
# ================================================================

func _on_fire_requested(
	shooter: ShootingWindow,
	target_global_position: Vector2
) -> void:
	if shooter == null:
		return

	if not is_instance_valid(shooter):
		return

	if _is_reloading:
		shot_rejected.emit(
			ShotRejectionReason.RELOADING
		)
		return

	if not cooldown_timer.is_stopped():
		shot_rejected.emit(
			ShotRejectionReason.COOLDOWN_ACTIVE
		)
		return

	if not _try_consume_shot_ammo():
		shot_rejected.emit(
			ShotRejectionReason.EMPTY_AMMO
		)
		return

	var cooldown_duration: float = (
		GameState.fire_cooldown_seconds
	)

	_start_cooldown(cooldown_duration)

	shooter.play_shot_feedback(
		cooldown_duration
	)

	if _is_shot_blocked_by_window(
		shooter,
		target_global_position
	):
		shot_blocked.emit(
			target_global_position
		)
		return

	shot_fired.emit(
		target_global_position,
		GameState.shot_damage
	)


func _try_consume_shot_ammo() -> bool:
	if GameState.current_ammo <= 0:
		return false

	return GameState.consume_ammo(1)


func _start_cooldown(duration: float) -> void:
	var safe_duration: float = maxf(
		0.01,
		duration
	)

	cooldown_timer.start(safe_duration)

	cooldown_started.emit(
		safe_duration
	)


func _is_shot_blocked_by_window(
	shooter: ShootingWindow,
	target_global_position: Vector2
) -> bool:
	if window_manager == null:
		return false

	return window_manager.is_shot_blocked_at_global_point(
		target_global_position,
		shooter
	)


# ================================================================
# GAMESTATE SYNC
# ================================================================

func _on_game_state_ammo_changed(
	current_ammo: int,
	max_ammo: int
) -> void:
	ammo_changed.emit(
		current_ammo,
		max_ammo
	)


func _emit_current_ammo_state() -> void:
	ammo_changed.emit(
		GameState.current_ammo,
		GameState.max_ammo
	)


# ================================================================
# COOLDOWN
# ================================================================

func _on_cooldown_finished() -> void:
	cooldown_finished.emit()
