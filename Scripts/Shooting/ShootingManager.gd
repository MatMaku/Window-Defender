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
@export var enemy_manager: EnemyManager

@onready var cooldown_timer: Timer = (
	get_node_or_null("CooldownTimer") as Timer
)

@export_category("Area Shot Delay")

@export_range(0.0, 0.5, 0.01)
var area_shot_fire_delay_seconds: float = 0.08

var _shooting_window: ShootingWindow
var _is_reloading: bool = false
var _area_shot_pending: bool = false
var _area_shot_delay_remaining: float = 0.0
var _weapon_state: GameWeaponState
var _upgrade_state: GameUpgradeState

func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	_configure_cooldown_timer()
	_connect_signals()
	_register_existing_windows()
	_emit_current_ammo_state()
	_sync_upgrade_state_to_window()


func _process(delta: float) -> void:
	_process_automatic_fire(delta)


# ================================================================
# PUBLIC API
# ================================================================

func get_current_ammo() -> int:
	return _weapon_state.current_ammo


func get_max_ammo() -> int:
	return _weapon_state.max_ammo


func is_reloading() -> bool:
	return _is_reloading


func has_full_ammo() -> bool:
	return _weapon_state.current_ammo >= _weapon_state.max_ammo


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
	_weapon_state.refill_ammo()


func complete_reload() -> void:
	_weapon_state.refill_ammo()


func create_save_snapshot() -> Dictionary:
	return {
		"cooldown_remaining": (
			0.0
			if cooldown_timer.is_stopped()
			else cooldown_timer.time_left
		)
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	cooldown_timer.stop()
	_cancel_pending_area_shot()
	set_reloading(false)

	var cooldown_remaining: float = maxf(
		0.0,
		float(snapshot.get("cooldown_remaining", 0.0))
	)
	if cooldown_remaining > 0.0:
		cooldown_timer.start(cooldown_remaining)
		cooldown_started.emit(cooldown_remaining)


# ================================================================
# SETUP
# ================================================================

func _resolve_references() -> void:
	_weapon_state = GameState.weapon_state
	_upgrade_state = GameState.upgrade_state

	if window_manager == null:
		window_manager = (
			get_node_or_null("../WindowManager")
			as WindowManager
		)

	if enemy_manager == null:
		enemy_manager = (
			get_node_or_null("../EnemyManager")
			as EnemyManager
		)


func _validate_dependencies() -> bool:
	if _weapon_state == null:
		push_error("ShootingManager requires GameWeaponState.")
		return false

	if _upgrade_state == null:
		push_error("ShootingManager requires GameUpgradeState.")
		return false

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

	if enemy_manager == null:
		push_warning(
			"ShootingManager has no EnemyManager reference. Automatic enemy targeting will not work."
		)

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

	if not _weapon_state.ammo_changed.is_connected(
		_on_weapon_ammo_changed
	):
		_weapon_state.ammo_changed.connect(
			_on_weapon_ammo_changed
		)

	if not _upgrade_state.auto_fire_changed.is_connected(
		_on_auto_fire_changed
	):
		_upgrade_state.auto_fire_changed.connect(
			_on_auto_fire_changed
		)

	if not _upgrade_state.area_shot_changed.is_connected(
		_on_area_shot_changed
	):
		_upgrade_state.area_shot_changed.connect(
			_on_area_shot_changed
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
		_sync_upgrade_state_to_window()
		return

	_shooting_window = window

	if not window.fire_requested.is_connected(
		_on_fire_requested
	):
		window.fire_requested.connect(
			_on_fire_requested
		)

	_sync_upgrade_state_to_window()


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
		_weapon_state.current_ammo,
		_weapon_state.max_ammo,
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
	_try_fire_at_position(
		shooter,
		target_global_position,
		true,
		false,
		false
	)


func _try_fire_at_position(
	shooter: ShootingWindow,
	target_global_position: Vector2,
	emit_rejections: bool,
	require_enemy_target: bool,
	prevent_blocked_shot_before_ammo: bool
) -> bool:
	if shooter == null:
		return false

	if not is_instance_valid(shooter):
		return false

	if _is_reloading:
		if emit_rejections:
			shot_rejected.emit(
				ShotRejectionReason.RELOADING
			)

		return false

	if not cooldown_timer.is_stopped():
		if emit_rejections:
			shot_rejected.emit(
				ShotRejectionReason.COOLDOWN_ACTIVE
			)

		return false

	if _weapon_state.current_ammo <= 0:
		if emit_rejections:
			shot_rejected.emit(
				ShotRejectionReason.EMPTY_AMMO
			)

		return false

	if require_enemy_target:
		if not _has_enemy_target_at_position(
			target_global_position
		):
			return false

	if prevent_blocked_shot_before_ammo:
		if _is_shot_blocked_by_window(
			shooter,
			target_global_position
		):
			return false

	if not _try_consume_shot_ammo():
		if emit_rejections:
			shot_rejected.emit(
				ShotRejectionReason.EMPTY_AMMO
			)

		return false

	var cooldown_duration: float = (
		_weapon_state.fire_cooldown_seconds
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

		return true

	shot_fired.emit(
		target_global_position,
		_weapon_state.shot_damage
	)

	return true


func _try_fire_area_targets(
	shooter: ShootingWindow,
	target_enemies: Array[DesktopVirus]
) -> bool:
	if shooter == null:
		return false

	if not is_instance_valid(shooter):
		return false

	if _is_reloading:
		return false

	if not cooldown_timer.is_stopped():
		return false

	if _weapon_state.current_ammo <= 0:
		return false

	if target_enemies.is_empty():
		return false

	var target_positions: Array[Vector2] = []

	for enemy: DesktopVirus in target_enemies:
		if not is_instance_valid(enemy):
			continue

		var target_position: Vector2 = (
			enemy.get_center_global_position()
		)

		if _is_shot_blocked_by_window(
			shooter,
			target_position
		):
			continue

		target_positions.append(target_position)

	if target_positions.is_empty():
		return false

	if not _try_consume_shot_ammo():
		return false

	var cooldown_duration: float = (
		_weapon_state.fire_cooldown_seconds
	)

	_start_cooldown(cooldown_duration)

	shooter.play_shot_feedback(
		cooldown_duration
	)

	for target_position: Vector2 in target_positions:
		shooter.present_area_shot_marker(
			target_position
		)

		shot_fired.emit(
			target_position,
			_weapon_state.shot_damage
		)

	return true


func _try_consume_shot_ammo() -> bool:
	if _weapon_state.current_ammo <= 0:
		return false

	return _weapon_state.consume_ammo(1)


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
# AUTOMATIC FIRE
# ================================================================

func _process_automatic_fire(delta: float) -> void:
	if _upgrade_state.area_shot_unlocked:
		_process_area_shot(delta)
		return

	_cancel_pending_area_shot()

	if _upgrade_state.auto_fire_unlocked:
		_process_center_auto_fire()


func _process_center_auto_fire() -> void:
	if not is_instance_valid(_shooting_window):
		return

	var target_global_position: Vector2 = (
		_shooting_window.get_aim_global_position()
	)

	_try_fire_at_position(
		_shooting_window,
		target_global_position,
		false,
		true,
		true
	)


func _process_area_shot(delta: float) -> void:
	if not _can_process_area_shot():
		_cancel_pending_area_shot()
		return

	if _area_shot_pending:
		_advance_pending_area_shot(delta)
		return

	var target_enemies: Array[DesktopVirus] = (
		_get_current_area_shot_targets()
	)

	if target_enemies.is_empty():
		return

	_start_pending_area_shot()


func _can_process_area_shot() -> bool:
	if enemy_manager == null:
		return false

	if not is_instance_valid(_shooting_window):
		return false

	if _is_reloading:
		return false

	if not cooldown_timer.is_stopped():
		return false

	if _weapon_state.current_ammo <= 0:
		return false

	return true


func _start_pending_area_shot() -> void:
	_area_shot_pending = true

	_area_shot_delay_remaining = maxf(
		0.0,
		area_shot_fire_delay_seconds
	)

	if _area_shot_delay_remaining <= 0.0:
		_fire_pending_area_shot()


func _advance_pending_area_shot(delta: float) -> void:
	_area_shot_delay_remaining = maxf(
		0.0,
		_area_shot_delay_remaining - delta
	)

	if _area_shot_delay_remaining > 0.0:
		return

	_fire_pending_area_shot()


func _fire_pending_area_shot() -> void:
	_area_shot_pending = false
	_area_shot_delay_remaining = 0.0

	if not _can_process_area_shot():
		return

	var target_enemies: Array[DesktopVirus] = (
		_get_current_area_shot_targets()
	)

	if target_enemies.is_empty():
		return

	_try_fire_area_targets(
		_shooting_window,
		target_enemies
	)


func _cancel_pending_area_shot() -> void:
	_area_shot_pending = false
	_area_shot_delay_remaining = 0.0


func _get_current_area_shot_targets() -> Array[DesktopVirus]:
	if enemy_manager == null:
		return []

	if not is_instance_valid(_shooting_window):
		return []

	var area_rect: Rect2 = (
		_shooting_window.get_area_shot_global_rect()
	)

	if area_rect.size.x <= 0.0 or area_rect.size.y <= 0.0:
		return []

	return enemy_manager.get_enemies_with_center_inside_global_rect(
		area_rect,
		_get_area_shot_max_targets()
	)


func _get_area_shot_max_targets() -> int:
	if not _upgrade_state.area_shot_unlocked:
		return 0

	return maxi(
		1,
		_upgrade_state.area_shot_max_targets
	)


func _has_enemy_target_at_position(
	target_global_position: Vector2
) -> bool:
	if enemy_manager == null:
		return false

	return enemy_manager.has_enemy_at_global_position(
		target_global_position
	)


func _on_auto_fire_changed(_enabled: bool) -> void:
	_sync_upgrade_state_to_window()


func _on_area_shot_changed(
	unlocked: bool,
	_max_targets: int
) -> void:
	if not unlocked:
		_cancel_pending_area_shot()

	_sync_upgrade_state_to_window()


func _sync_upgrade_state_to_window() -> void:
	if not is_instance_valid(_shooting_window):
		return

	_shooting_window.set_auto_fire_enabled(
		_upgrade_state.auto_fire_unlocked
		or _upgrade_state.area_shot_unlocked
	)

	_shooting_window.set_area_shot_enabled(
		_upgrade_state.area_shot_unlocked
	)

# ================================================================
# WEAPON STATE SYNC
# ================================================================

func _on_weapon_ammo_changed(
	current_ammo: int,
	max_ammo: int
) -> void:
	ammo_changed.emit(
		current_ammo,
		max_ammo
	)


func _emit_current_ammo_state() -> void:
	ammo_changed.emit(
		_weapon_state.current_ammo,
		_weapon_state.max_ammo
	)


# ================================================================
# COOLDOWN
# ================================================================

func _on_cooldown_finished() -> void:
	cooldown_finished.emit()
