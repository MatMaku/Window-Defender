extends DesktopVirus
class_name AdwareVirus

enum Phase {
	SEARCHING,
	MOVING,
	HIDDEN
}

const PHASE_SEARCHING: String = "searching"
const PHASE_MOVING: String = "moving"
const PHASE_HIDDEN: String = "hidden"

@export_category("Hiding")

@export_range(0.0, 1000.0, 0.1)
var movement_speed: float = 42.0

@export_range(0.05, 10.0, 0.05)
var search_retry_interval_seconds: float = 0.5

@export_range(0.5, 1.0, 0.01)
var minimum_hidden_coverage_ratio: float = 0.9

@export_range(0.0, 64.0, 0.5)
var hiding_inner_margin: float = 6.0

@export_range(0.0, 32.0, 0.5)
var hiding_arrival_distance: float = 2.0

@export_category("Spam")

@export_range(0.05, 300.0, 0.05)
var spam_interval_seconds: float = 12.0

@export_range(0.0, 120.0, 0.05)
var spam_interval_variation_seconds: float = 2.0

var _phase: Phase = Phase.SEARCHING
var _target_window: AppWindow
var _hidden_window_rect: Rect2

var _search_time_remaining: float = 0.0
var _spam_time_remaining: float = -1.0

var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_random.randomize()

	if not dragging_changed.is_connected(_on_dragging_changed):
		dragging_changed.connect(_on_dragging_changed)

	if _spam_time_remaining <= 0.0:
		_schedule_next_spam()


func apply_runtime_stats(
	runtime_stats: EnemyRuntimeStats
) -> void:
	if runtime_stats == null:
		return

	super.apply_runtime_stats(runtime_stats)
	movement_speed = maxf(0.0, runtime_stats.movement_speed)


func can_receive_separation_push() -> bool:
	return (
		_phase != Phase.HIDDEN
		and super.can_receive_separation_push()
	)


func _process_virus(delta: float) -> void:
	match _phase:
		Phase.SEARCHING:
			_process_searching(delta)
		Phase.MOVING:
			_process_moving(delta)
		Phase.HIDDEN:
			_process_hidden(delta)


func _create_runtime_stats() -> EnemyRuntimeStats:
	var runtime_stats: EnemyRuntimeStats = super._create_runtime_stats()
	runtime_stats.movement_speed = movement_speed
	return runtime_stats


func _create_behavior_save_snapshot() -> Dictionary:
	return {
		"phase": _phase_to_save_value(_phase),
		"spam_time_remaining": maxf(
			0.0,
			_spam_time_remaining
		)
	}


func _restore_behavior_from_save_snapshot(
	snapshot: Dictionary
) -> void:
	var restored_spam_time: float = maxf(
		0.0,
		float(snapshot.get("spam_time_remaining", 0.0))
	)
	if restored_spam_time <= 0.0:
		_schedule_next_spam()
	else:
		_spam_time_remaining = restored_spam_time

	var saved_phase: String = str(
		snapshot.get("phase", PHASE_SEARCHING)
	)
	if saved_phase == PHASE_HIDDEN:
		var covering_window: AppWindow = _find_covering_window()
		if covering_window != null:
			_target_window = covering_window
			_enter_hidden()
			return

	_enter_searching(0.0)


func _before_die() -> void:
	_target_window = null


func _process_searching(delta: float) -> void:
	_search_time_remaining = maxf(
		0.0,
		_search_time_remaining - delta
	)
	if _search_time_remaining > 0.0:
		return

	if _try_acquire_hiding_window():
		return

	_search_time_remaining = maxf(
		0.05,
		search_retry_interval_seconds
	)


func _process_moving(delta: float) -> void:
	if not _is_target_window_valid():
		_enter_searching(0.0)
		return

	if _get_window_coverage_ratio(_target_window) >= (
		minimum_hidden_coverage_ratio
	):
		_enter_hidden()
		return

	var hiding_center: Vector2 = _get_safe_hiding_center(
		_target_window
	)
	var movement_target: Vector2 = get_navigation_movement_target(
		hiding_center
	)
	var current_center: Vector2 = get_center_global_position()
	var distance: float = current_center.distance_to(
		movement_target
	)
	if distance <= hiding_arrival_distance:
		return

	var movement_distance: float = minf(
		movement_speed * get_active_slow_multiplier() * delta,
		distance
	)
	global_position += current_center.direction_to(
		movement_target
	) * movement_distance


func _process_hidden(delta: float) -> void:
	if (
		not _is_target_window_valid()
		or _has_hidden_window_rect_changed()
		or _get_window_coverage_ratio(_target_window) < (
			minimum_hidden_coverage_ratio
		)
	):
		_enter_searching(0.0)
		return

	_spam_time_remaining = maxf(
		0.0,
		_spam_time_remaining - delta
	)
	if _spam_time_remaining > 0.0:
		return

	_window_manager.open_spam_window()
	_schedule_next_spam()


func _try_acquire_hiding_window() -> bool:
	if not is_instance_valid(_window_manager):
		return false

	var current_center: Vector2 = get_center_global_position()
	var closest_window: AppWindow
	var closest_distance_squared: float = INF

	for window: AppWindow in (
		_window_manager.get_adware_hiding_windows()
	):
		var distance_squared: float = current_center.distance_squared_to(
			window.get_global_rect().get_center()
		)
		if distance_squared >= closest_distance_squared:
			continue

		closest_window = window
		closest_distance_squared = distance_squared

	if closest_window == null:
		return false

	_target_window = closest_window
	_phase = Phase.MOVING
	invalidate_navigation_path()
	return true


func _find_covering_window() -> AppWindow:
	if not is_instance_valid(_window_manager):
		return null

	var best_window: AppWindow
	var best_coverage: float = minimum_hidden_coverage_ratio
	for window: AppWindow in (
		_window_manager.get_adware_hiding_windows()
	):
		var coverage: float = _get_window_coverage_ratio(window)
		if coverage < best_coverage:
			continue

		best_window = window
		best_coverage = coverage

	return best_window


func _is_target_window_valid() -> bool:
	if not is_instance_valid(_window_manager):
		return false

	if not is_instance_valid(_target_window):
		return false

	return _window_manager.is_adware_hiding_window_valid(
		_target_window
	)


func _get_safe_hiding_center(window: AppWindow) -> Vector2:
	var window_rect: Rect2 = window.get_global_rect()
	var enemy_size: Vector2 = get_global_rect().size
	var half_enemy_size: Vector2 = enemy_size * 0.5
	var preferred_center: Vector2 = window_rect.get_center()

	var safe_center: Vector2 = Vector2(
		_clamp_center_axis(
			preferred_center.x,
			window_rect.position.x,
			window_rect.end.x,
			half_enemy_size.x + hiding_inner_margin
		),
		_clamp_center_axis(
			preferred_center.y,
			window_rect.position.y,
			window_rect.end.y,
			half_enemy_size.y + hiding_inner_margin
		)
	)

	var desktop_rect: Rect2 = (
		_window_manager.get_window_area_global_rect()
	)
	if desktop_rect.size == Vector2.ZERO:
		return safe_center

	return Vector2(
		_clamp_center_axis(
			safe_center.x,
			desktop_rect.position.x,
			desktop_rect.end.x,
			half_enemy_size.x
		),
		_clamp_center_axis(
			safe_center.y,
			desktop_rect.position.y,
			desktop_rect.end.y,
			half_enemy_size.y
		)
	)


func _get_window_coverage_ratio(window: AppWindow) -> float:
	if window == null or not is_instance_valid(window):
		return 0.0

	var enemy_rect: Rect2 = get_global_rect()
	var enemy_area: float = enemy_rect.get_area()
	if enemy_area <= 0.0:
		return 0.0

	var overlap: Rect2 = enemy_rect.intersection(
		window.get_global_rect()
	)
	return clampf(overlap.get_area() / enemy_area, 0.0, 1.0)


func _enter_searching(delay: float) -> void:
	_target_window = null
	_hidden_window_rect = Rect2()
	_phase = Phase.SEARCHING
	_search_time_remaining = maxf(0.0, delay)
	invalidate_navigation_path()


func _enter_hidden() -> void:
	if not _is_target_window_valid():
		_enter_searching(0.0)
		return

	_hidden_window_rect = _target_window.get_global_rect()
	_phase = Phase.HIDDEN
	invalidate_navigation_path()


func _has_hidden_window_rect_changed() -> bool:
	if not _is_target_window_valid():
		return true

	var current_rect: Rect2 = _target_window.get_global_rect()
	return (
		not current_rect.position.is_equal_approx(
			_hidden_window_rect.position
		)
		or not current_rect.size.is_equal_approx(
			_hidden_window_rect.size
		)
	)


func _schedule_next_spam() -> void:
	var base_interval: float = maxf(0.05, spam_interval_seconds)
	var variation: float = maxf(
		0.0,
		spam_interval_variation_seconds
	)
	_spam_time_remaining = maxf(
		0.05,
		base_interval + _random.randf_range(
			-variation,
			variation
		)
	)


func _on_dragging_changed(
	virus: DesktopVirus,
	is_now_dragging: bool
) -> void:
	if virus != self:
		return

	if is_now_dragging:
		_enter_searching(search_retry_interval_seconds)
		return

	_enter_searching(0.0)


func _phase_to_save_value(value: Phase) -> String:
	match value:
		Phase.MOVING:
			return PHASE_MOVING
		Phase.HIDDEN:
			return PHASE_HIDDEN
		_:
			return PHASE_SEARCHING


func _clamp_center_axis(
	value: float,
	minimum_edge: float,
	maximum_edge: float,
	required_inset: float
) -> float:
	var minimum_center: float = minimum_edge + required_inset
	var maximum_center: float = maximum_edge - required_inset
	if minimum_center > maximum_center:
		return (minimum_edge + maximum_edge) * 0.5

	return clampf(value, minimum_center, maximum_center)
