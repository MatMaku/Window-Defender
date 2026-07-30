extends Node
class_name FirewallNavigationManager

signal firewall_established(window: AppWindow)
signal firewall_unestablished(window: AppWindow)
signal firewall_obstacles_changed
signal navigation_rebuilt(revision: int)

const ESTABLISH_OK: StringName = &""
const ERROR_ENEMY_OVERLAP: StringName = &"enemy_overlap"
const ERROR_SHORTCUT_OVERLAP: StringName = &"shortcut_overlap"
const ERROR_FIREWALL_OVERLAP: StringName = &"firewall_overlap"
const ERROR_PATH_BLOCKED: StringName = &"path_blocked"
const ERROR_NAVIGATION_UNAVAILABLE: StringName = &"navigation_unavailable"
const NAVIGATION_SYNC_TIMEOUT_FRAMES: int = 16
const NAVIGATION_CLEARANCE_EPSILON: float = 0.5

@export var navigation_region: NavigationRegion2D
@export var desktop: Desktop
@export var playfield_layer: Control
@export var window_manager: WindowManager
@export var enemy_manager: EnemyManager
@export var system_manager: SystemManager

@export_category("Navigation Geometry")

@export_range(1.0, 64.0, 1.0)
var navigation_cell_size: float = 8.0

@export_range(0.0, 128.0, 1.0)
var maximum_enemy_radius: float = 24.0

@export_range(0.0, 32.0, 0.5)
var obstacle_margin: float = 8.0

@export_range(8.0, 256.0, 1.0)
var spawn_validation_spacing: float = 32.0

var _established_firewalls: Array[AppWindow] = []
var _pending_restore_firewalls: Array[AppWindow] = []
var _synchronized_obstacle_rects: Array[Rect2] = []

var _navigation_revision: int = 0
var _navigation_change_generation: int = 0
var _synchronized_generation: int = 0
var _rebuild_queued: bool = false
var _rebuild_in_progress: bool = false
var _playfield_resize_queued: bool = false
var _restore_in_progress: bool = false


func _ready() -> void:
	_validate_dependencies()
	_connect_window_manager()
	_connect_playfield()
	_queue_navigation_rebuild()


func try_establish_firewall(
	firewall: AppWindow
) -> StringName:
	if not is_instance_valid(firewall):
		return ERROR_NAVIGATION_UNAVAILABLE

	var validation_error: StringName = (
		_validate_firewall_candidate(firewall)
	)
	if validation_error != ESTABLISH_OK:
		return validation_error

	if not _established_firewalls.has(firewall):
		_established_firewalls.append(firewall)

	firewall.call(
		"apply_established_state_from_navigation",
		true
	)
	window_manager.place_window_in_desktop_band(firewall)
	firewall_established.emit(firewall)
	_notify_obstacles_changed()
	return ESTABLISH_OK


func unestablish_firewall(
	firewall: AppWindow,
	restore_normal_window_order: bool = true
) -> void:
	if not is_instance_valid(firewall):
		return

	var was_registered: bool = _established_firewalls.has(
		firewall
	)
	_established_firewalls.erase(firewall)
	_pending_restore_firewalls.erase(firewall)

	firewall.call(
		"apply_established_state_from_navigation",
		false
	)

	if restore_normal_window_order:
		window_manager.restore_window_to_normal_band(firewall)

	if not was_registered:
		return

	firewall_unestablished.emit(firewall)
	_notify_obstacles_changed()


func queue_restored_firewall(
	firewall: AppWindow
) -> void:
	if not is_instance_valid(firewall):
		return

	if not _pending_restore_firewalls.has(firewall):
		_pending_restore_firewalls.append(firewall)

	if not _restore_in_progress:
		finish_restore()


func begin_restore() -> void:
	_restore_in_progress = true
	_navigation_change_generation += 1
	_pending_restore_firewalls.clear()

	for firewall: AppWindow in _established_firewalls:
		if not is_instance_valid(firewall):
			continue

		firewall.call(
			"apply_established_state_from_navigation",
			false
		)

	_established_firewalls.clear()
	_rebuild_queued = false


func finish_restore() -> bool:
	var restore_candidates: Array[AppWindow] = (
		_pending_restore_firewalls.duplicate()
	)
	_pending_restore_firewalls.clear()
	_established_firewalls.clear()

	for firewall: AppWindow in restore_candidates:
		if not is_instance_valid(firewall):
			continue

		var validation_error: StringName = (
			_validate_firewall_candidate(firewall)
		)
		if validation_error != ESTABLISH_OK:
			firewall.call(
				"apply_established_state_from_navigation",
				false
			)
			push_warning(
				"Restored Firewall was left mobile [%s]."
				% str(validation_error)
			)
			continue

		_established_firewalls.append(firewall)
		firewall.call(
			"apply_established_state_from_navigation",
			true
		)
		window_manager.place_window_in_desktop_band(firewall)
		firewall_established.emit(firewall)

	_restore_in_progress = false
	_notify_obstacles_changed()
	var required_generation: int = (
		_navigation_change_generation
	)
	return await _wait_for_navigation_generation(
		required_generation
	)


func cancel_restore() -> void:
	_restore_in_progress = false
	_pending_restore_firewalls.clear()
	_established_firewalls.clear()
	_notify_obstacles_changed()


func has_established_firewalls() -> bool:
	_prune_invalid_firewalls()
	return not _established_firewalls.is_empty()


func get_navigation_revision() -> int:
	return _navigation_revision


func is_navigation_update_pending() -> bool:
	return (
		_rebuild_queued
		or _rebuild_in_progress
		or _restore_in_progress
	)


func get_navigation_path(
	from_global_position: Vector2,
	to_global_position: Vector2
) -> PackedVector2Array:
	if is_navigation_update_pending():
		return PackedVector2Array()

	if navigation_region == null:
		return PackedVector2Array()

	var navigation_map: RID = (
		navigation_region.get_navigation_map()
	)
	if not navigation_map.is_valid():
		return PackedVector2Array()

	var path: PackedVector2Array = (
		NavigationServer2D.map_get_path(
			navigation_map,
			from_global_position,
			to_global_position,
			true
		)
	)
	if not _is_path_clear_of_synchronized_obstacles(path):
		return PackedVector2Array()

	return path


func is_navigation_segment_clear(
	from_global_position: Vector2,
	to_global_position: Vector2
) -> bool:
	if is_navigation_update_pending():
		return false

	return _is_segment_clear_of_synchronized_obstacles(
		from_global_position,
		to_global_position
	)


func _wait_for_navigation_generation(
	required_generation: int
) -> bool:
	for _frame: int in range(
		NAVIGATION_SYNC_TIMEOUT_FRAMES
	):
		if _synchronized_generation >= required_generation:
			return true
		await get_tree().physics_frame

	return (
		_synchronized_generation
		>= required_generation
	)


func get_closest_navigation_point(
	global_position: Vector2
) -> Vector2:
	if is_navigation_update_pending():
		return global_position

	if navigation_region == null:
		return global_position

	var navigation_map: RID = (
		navigation_region.get_navigation_map()
	)
	if not navigation_map.is_valid():
		return global_position

	var map_point: Vector2 = (
		NavigationServer2D.map_get_closest_point(
			navigation_map,
			global_position
		)
	)
	return _get_closest_clear_navigation_point(
		global_position,
		map_point
	)


func get_established_firewall_rects() -> Array[Rect2]:
	_prune_invalid_firewalls()

	var obstacle_rects: Array[Rect2] = []
	for firewall: AppWindow in _established_firewalls:
		obstacle_rects.append(
			firewall.get_global_rect()
		)

	return obstacle_rects


func _connect_window_manager() -> void:
	if window_manager == null:
		return

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


func _connect_playfield() -> void:
	if playfield_layer == null:
		return

	if not playfield_layer.resized.is_connected(
		_on_playfield_resized
	):
		playfield_layer.resized.connect(
			_on_playfield_resized
		)


func _on_playfield_resized() -> void:
	if _playfield_resize_queued:
		return

	_playfield_resize_queued = true
	call_deferred(
		"_defer_playfield_navigation_rebuild"
	)


func _defer_playfield_navigation_rebuild() -> void:
	call_deferred(
		"_rebuild_after_playfield_layout"
	)


func _rebuild_after_playfield_layout() -> void:
	_playfield_resize_queued = false
	_notify_obstacles_changed()


func _on_window_opened(
	window: AppWindow,
	_program_data: ProgramData
) -> void:
	if not _is_firewall_window(window):
		return

	window.call("set_navigation_manager", self)


func _on_window_closed(window: AppWindow) -> void:
	if not _is_firewall_window(window):
		return

	var changed: bool = _established_firewalls.has(window)
	_established_firewalls.erase(window)
	_pending_restore_firewalls.erase(window)

	if not changed:
		return

	firewall_unestablished.emit(window)
	_notify_obstacles_changed()


func _is_firewall_window(window: AppWindow) -> bool:
	return (
		window != null
		and window.has_method(
			"apply_established_state_from_navigation"
		)
		and window.has_method("set_navigation_manager")
	)


func _validate_firewall_candidate(
	firewall: AppWindow
) -> StringName:
	if (
		desktop == null
		or enemy_manager == null
		or system_manager == null
	):
		return ERROR_NAVIGATION_UNAVAILABLE

	var candidate_rect: Rect2 = firewall.get_global_rect()

	if not enemy_manager.get_enemies_inside_or_intersecting_global_rect(
		candidate_rect,
		1
	).is_empty():
		return ERROR_ENEMY_OVERLAP

	if desktop.has_shortcut_intersecting_global_rect(
		candidate_rect
	):
		return ERROR_SHORTCUT_OVERLAP

	for established: AppWindow in _established_firewalls:
		if not is_instance_valid(established):
			continue

		if established == firewall:
			continue

		if candidate_rect.intersects(
			established.get_global_rect(),
			false
		):
			return ERROR_FIREWALL_OVERLAP

	if not _candidate_preserves_all_spawn_paths(
		candidate_rect
	):
		return ERROR_PATH_BLOCKED

	return ESTABLISH_OK


func _candidate_preserves_all_spawn_paths(
	candidate_rect: Rect2
) -> bool:
	if playfield_layer == null:
		return false

	var target_rect: Rect2 = (
		system_manager.get_attack_target_global_rect()
	)
	if target_rect.size == Vector2.ZERO:
		return false

	var obstacle_rects: Array[Rect2] = (
		get_established_firewall_rects()
	)
	obstacle_rects.append(candidate_rect)

	var navigation_polygon: NavigationPolygon = (
		_bake_navigation_polygon(obstacle_rects)
	)
	if navigation_polygon == null:
		return false

	var target_position: Vector2 = target_rect.get_center()
	var valid: bool = _all_spawn_samples_reach_target(
		navigation_polygon,
		target_position
	)
	return valid


func _all_spawn_samples_reach_target(
	navigation_polygon: NavigationPolygon,
	target_position: Vector2
) -> bool:
	var point_tolerance: float = maxf(
		navigation_cell_size * 2.0,
		maximum_enemy_radius * 2.0
	)
	var target_polygon_index: int = (
		_find_closest_polygon_index(
			navigation_polygon,
			target_position,
			point_tolerance
		)
	)
	if target_polygon_index < 0:
		return false

	var reachable_polygons: Array[bool] = (
		_find_connected_polygons(
			navigation_polygon,
			target_polygon_index
		)
	)
	var spawn_samples: PackedVector2Array = (
		_get_spawn_validation_points()
	)
	if spawn_samples.is_empty():
		return false

	for spawn_position: Vector2 in spawn_samples:
		var spawn_polygon_index: int = (
			_find_closest_polygon_index(
				navigation_polygon,
				spawn_position,
				INF
			)
		)
		if spawn_polygon_index < 0:
			return false

		if not reachable_polygons[spawn_polygon_index]:
			return false

	return true


func _find_closest_polygon_index(
	navigation_polygon: NavigationPolygon,
	point: Vector2,
	maximum_distance: float
) -> int:
	var vertices: PackedVector2Array = (
		navigation_polygon.get_vertices()
	)
	var closest_polygon_index: int = -1
	var closest_distance: float = INF

	for polygon_index: int in range(
		navigation_polygon.get_polygon_count()
	):
		var polygon: PackedInt32Array = (
			navigation_polygon.get_polygon(
				polygon_index
			)
		)
		var outline: PackedVector2Array = (
			_get_polygon_outline(
				vertices,
				polygon
			)
		)
		if Geometry2D.is_point_in_polygon(
			point,
			outline
		):
			return polygon_index

		var distance: float = (
			_get_distance_to_polygon(
				point,
				outline
			)
		)
		if distance >= closest_distance:
			continue

		closest_distance = distance
		closest_polygon_index = polygon_index

	if closest_distance > maximum_distance:
		return -1

	return closest_polygon_index


func _find_connected_polygons(
	navigation_polygon: NavigationPolygon,
	start_polygon_index: int
) -> Array[bool]:
	var polygon_count: int = (
		navigation_polygon.get_polygon_count()
	)
	var connected: Array[bool] = []
	connected.resize(polygon_count)
	connected.fill(false)

	var pending: Array[int] = [start_polygon_index]
	connected[start_polygon_index] = true

	while not pending.is_empty():
		var current_index: int = pending.pop_front()
		var current_polygon: PackedInt32Array = (
			navigation_polygon.get_polygon(
				current_index
			)
		)

		for other_index: int in range(polygon_count):
			if connected[other_index]:
				continue

			var other_polygon: PackedInt32Array = (
				navigation_polygon.get_polygon(
					other_index
				)
			)
			if not _polygons_share_edge(
				current_polygon,
				other_polygon
			):
				continue

			connected[other_index] = true
			pending.append(other_index)

	return connected


func _polygons_share_edge(
	first: PackedInt32Array,
	second: PackedInt32Array
) -> bool:
	var shared_vertex_count: int = 0

	for vertex_index: int in first:
		if not second.has(vertex_index):
			continue

		shared_vertex_count += 1
		if shared_vertex_count >= 2:
			return true

	return false


func _get_polygon_outline(
	vertices: PackedVector2Array,
	polygon: PackedInt32Array
) -> PackedVector2Array:
	var outline: PackedVector2Array = (
		PackedVector2Array()
	)
	for vertex_index: int in polygon:
		outline.append(vertices[vertex_index])

	return outline


func _get_distance_to_polygon(
	point: Vector2,
	outline: PackedVector2Array
) -> float:
	if outline.is_empty():
		return INF

	var closest_distance: float = INF
	for index: int in range(outline.size()):
		var next_index: int = (
			(index + 1) % outline.size()
		)
		var closest_point: Vector2 = (
			_get_closest_point_on_segment(
				point,
				outline[index],
				outline[next_index]
			)
		)
		closest_distance = minf(
			closest_distance,
			point.distance_to(closest_point)
		)

	return closest_distance


func _get_closest_point_on_segment(
	point: Vector2,
	start: Vector2,
	end: Vector2
) -> Vector2:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if is_zero_approx(length_squared):
		return start

	var ratio: float = clampf(
		(point - start).dot(segment)
			/ length_squared,
		0.0,
		1.0
	)
	return start + segment * ratio


func _get_spawn_validation_points() -> PackedVector2Array:
	var playfield_rect: Rect2 = (
		playfield_layer.get_global_rect()
	)
	var points: PackedVector2Array = PackedVector2Array()
	var spacing: float = maxf(
		navigation_cell_size,
		spawn_validation_spacing
	)

	var x: float = playfield_rect.position.x
	while x <= playfield_rect.end.x:
		points.append(Vector2(x, playfield_rect.position.y))
		points.append(Vector2(x, playfield_rect.end.y))
		x += spacing

	var y: float = playfield_rect.position.y + spacing
	while y < playfield_rect.end.y:
		points.append(Vector2(playfield_rect.position.x, y))
		points.append(Vector2(playfield_rect.end.x, y))
		y += spacing

	points.append(playfield_rect.end)
	return points


func _notify_obstacles_changed() -> void:
	firewall_obstacles_changed.emit()
	_queue_navigation_rebuild()


func _queue_navigation_rebuild() -> void:
	_navigation_change_generation += 1

	if _restore_in_progress:
		return

	if _rebuild_queued or _rebuild_in_progress:
		return

	_rebuild_queued = true
	call_deferred("_rebuild_navigation_map")


func _rebuild_navigation_map() -> void:
	_rebuild_queued = false

	if _restore_in_progress or _rebuild_in_progress:
		return

	if navigation_region == null:
		return

	_rebuild_in_progress = true

	while not _restore_in_progress:
		var rebuild_generation: int = (
			_navigation_change_generation
		)
		var obstacle_rects: Array[Rect2] = (
			get_established_firewall_rects()
		)
		var navigation_polygon: NavigationPolygon = (
			_bake_navigation_polygon(
				obstacle_rects
			)
		)
		if navigation_polygon == null:
			break

		navigation_region.navigation_polygon = (
			navigation_polygon
		)

		await get_tree().physics_frame

		if not is_inside_tree() or _restore_in_progress:
			break

		if rebuild_generation != _navigation_change_generation:
			continue

		_synchronized_obstacle_rects = (
			obstacle_rects.duplicate()
		)
		_synchronized_generation = rebuild_generation
		_navigation_revision += 1
		navigation_rebuilt.emit(_navigation_revision)
		break

	_rebuild_in_progress = false


func _bake_navigation_polygon(
	obstacle_rects: Array[Rect2]
) -> NavigationPolygon:
	if playfield_layer == null:
		return null

	var navigation_polygon: NavigationPolygon = (
		NavigationPolygon.new()
	)
	navigation_polygon.agent_radius = maximum_enemy_radius
	navigation_polygon.cell_size = navigation_cell_size

	var source_geometry: NavigationMeshSourceGeometryData2D = (
		NavigationMeshSourceGeometryData2D.new()
	)
	source_geometry.add_traversable_outline(
		_rect_to_outline(
			playfield_layer.get_global_rect()
		)
	)

	for obstacle_rect: Rect2 in obstacle_rects:
		source_geometry.add_obstruction_outline(
			_rect_to_outline(
				obstacle_rect.grow(obstacle_margin)
			)
		)

	NavigationServer2D.bake_from_source_geometry_data(
		navigation_polygon,
		source_geometry
	)
	return navigation_polygon


func _rect_to_outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.position.x, rect.end.y),
		rect.end,
		Vector2(rect.end.x, rect.position.y)
	])


func _is_path_clear_of_synchronized_obstacles(
	path: PackedVector2Array
) -> bool:
	if path.size() < 2:
		return path.is_empty()

	for index: int in range(path.size() - 1):
		if not _is_segment_clear_of_synchronized_obstacles(
			path[index],
			path[index + 1]
		):
			return false

	return true


func _is_segment_clear_of_synchronized_obstacles(
	from_global_position: Vector2,
	to_global_position: Vector2
) -> bool:
	var enemy_clearance: float = (
		_get_synchronized_obstacle_clearance()
	)
	for obstacle_rect: Rect2 in _synchronized_obstacle_rects:
		var clearance_rect: Rect2 = obstacle_rect.grow(
			enemy_clearance
		)
		if _segment_intersects_rect(
			from_global_position,
			to_global_position,
			clearance_rect
		):
			return false

	return true


func _get_closest_clear_navigation_point(
	reference_point: Vector2,
	map_point: Vector2
) -> Vector2:
	if _is_clear_navigation_point(map_point):
		return map_point

	var candidates: Array[Vector2] = []
	var obstacle_clearance: float = (
		_get_synchronized_obstacle_clearance()
	)
	for obstacle_rect: Rect2 in _synchronized_obstacle_rects:
		var clearance_rect: Rect2 = obstacle_rect.grow(
			obstacle_clearance
		)
		if (
			not _rect_contains_point_inclusive(
				clearance_rect,
				reference_point
			)
			and not _rect_contains_point_inclusive(
				clearance_rect,
				map_point
			)
		):
			continue

		_append_clearance_candidates(
			candidates,
			clearance_rect,
			reference_point
		)

	var closest_point: Vector2 = map_point
	var closest_distance_squared: float = INF
	for candidate: Vector2 in candidates:
		if not _is_clear_navigation_point(candidate):
			continue

		var distance_squared: float = (
			reference_point.distance_squared_to(
				candidate
			)
		)
		if distance_squared >= closest_distance_squared:
			continue

		closest_point = candidate
		closest_distance_squared = distance_squared

	return closest_point


func _append_clearance_candidates(
	candidates: Array[Vector2],
	clearance_rect: Rect2,
	reference_point: Vector2
) -> void:
	var outside_offset: float = NAVIGATION_CLEARANCE_EPSILON
	var clamped_x: float = clampf(
		reference_point.x,
		clearance_rect.position.x,
		clearance_rect.end.x
	)
	var clamped_y: float = clampf(
		reference_point.y,
		clearance_rect.position.y,
		clearance_rect.end.y
	)
	var left: float = (
		clearance_rect.position.x - outside_offset
	)
	var right: float = (
		clearance_rect.end.x + outside_offset
	)
	var top: float = (
		clearance_rect.position.y - outside_offset
	)
	var bottom: float = (
		clearance_rect.end.y + outside_offset
	)

	candidates.append(Vector2(left, clamped_y))
	candidates.append(Vector2(right, clamped_y))
	candidates.append(Vector2(clamped_x, top))
	candidates.append(Vector2(clamped_x, bottom))
	candidates.append(Vector2(left, top))
	candidates.append(Vector2(right, top))
	candidates.append(Vector2(right, bottom))
	candidates.append(Vector2(left, bottom))


func _is_clear_navigation_point(
	global_point: Vector2
) -> bool:
	if playfield_layer == null:
		return false

	var navigable_bounds: Rect2 = (
		playfield_layer.get_global_rect().grow(
			-maximum_enemy_radius
		)
	)
	if not _rect_contains_point_inclusive(
		navigable_bounds,
		global_point
	):
		return false

	var obstacle_clearance: float = (
		_get_synchronized_obstacle_clearance()
	)
	for obstacle_rect: Rect2 in _synchronized_obstacle_rects:
		if _rect_contains_point_inclusive(
			obstacle_rect.grow(
				obstacle_clearance
			),
			global_point
		):
			return false

	return true


func _get_synchronized_obstacle_clearance() -> float:
	return maxf(
		0.0,
		maximum_enemy_radius
			+ obstacle_margin
			- NAVIGATION_CLEARANCE_EPSILON
	)


func _rect_contains_point_inclusive(
	rect: Rect2,
	point: Vector2
) -> bool:
	return (
		point.x >= rect.position.x
		and point.x <= rect.end.x
		and point.y >= rect.position.y
		and point.y <= rect.end.y
	)


func _segment_intersects_rect(
	start: Vector2,
	end: Vector2,
	rect: Rect2
) -> bool:
	if rect.has_point(start) or rect.has_point(end):
		return true

	var corners: PackedVector2Array = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])
	for index: int in range(corners.size()):
		var next_index: int = (
			(index + 1) % corners.size()
		)
		if Geometry2D.segment_intersects_segment(
			start,
			end,
			corners[index],
			corners[next_index]
		) != null:
			return true

	return false


func _prune_invalid_firewalls() -> void:
	for index: int in range(
		_established_firewalls.size() - 1,
		-1,
		-1
	):
		if is_instance_valid(
			_established_firewalls[index]
		):
			continue

		_established_firewalls.remove_at(index)


func _validate_dependencies() -> void:
	if navigation_region == null:
		push_error(
			"FirewallNavigationManager requires a NavigationRegion2D."
		)

	if desktop == null:
		push_error(
			"FirewallNavigationManager requires Desktop."
		)

	if playfield_layer == null:
		push_error(
			"FirewallNavigationManager requires PlayfieldLayer."
		)

	if window_manager == null:
		push_error(
			"FirewallNavigationManager requires WindowManager."
		)

	if enemy_manager == null:
		push_error(
			"FirewallNavigationManager requires EnemyManager."
		)

	if system_manager == null:
		push_error(
			"FirewallNavigationManager requires SystemManager."
		)
