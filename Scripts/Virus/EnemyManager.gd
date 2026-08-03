extends Node
class_name EnemyManager

signal enemy_spawned(enemy: DesktopVirus)
signal enemy_removed(enemy: DesktopVirus)

@export var playfield_layer: Control
@export var system_manager: SystemManager
@export var shooting_manager: ShootingManager
@export var window_manager: WindowManager
@export var navigation_manager: Node

@export_category("Enemy Scenes")

@export var basic_virus_scene: PackedScene

@export_category("Testing")

@export var spawn_test_enemy_on_ready: bool = false

@export_range(0.0, 200.0, 1.0)
var spawn_margin: float = 24.0

@export_category("Rewards Fallback")

@export_range(0, 999, 1)
var virus_data_reward_per_kill: int = 1

@export_category("Enemy Separation")

@export var enemy_separation_enabled: bool = true

@export_range(0.0, 200.0, 1.0)
var enemy_separation_distance: float = 34.0

@export_range(0.0, 500.0, 1.0)
var enemy_separation_strength: float = 80.0

@export_range(0.0, 30.0, 0.5)
var max_separation_push_per_frame: float = 3.0

@export_category("Slowdown Areas")

@export_range(0.01, 1.0, 0.01)
var slowdown_evaluation_interval_seconds: float = 0.05

var _active_enemies: Array[DesktopVirus] = []
var _slowdown_sources: Array[SlowdownAreaSource] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

var _test_enemy_spawned: bool = false
var _economy_state: GameEconomyState
var _slowdown_evaluation_elapsed: float = 0.0


func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	_random.randomize()

	shooting_manager.shot_fired.connect(
		_on_shot_fired
	)

	system_manager.system_target_registered.connect(
		_on_system_target_registered
	)
	_connect_navigation_obstacle_changes()

	call_deferred("_try_spawn_initial_enemy")


func _process(delta: float) -> void:
	_update_slowdown_areas(delta)

	if not _can_apply_enemy_separation():
		return

	_apply_enemy_separation(delta)


func _exit_tree() -> void:
	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		enemy.set_active_slow_multiplier(1.0)

	_slowdown_sources.clear()


func register_slowdown_source(source: SlowdownAreaSource) -> void:
	if source == null or not source.is_active():
		return

	_prune_invalid_slowdown_sources()
	var runtime_id: int = source.get_runtime_id()
	for registered_source: SlowdownAreaSource in _slowdown_sources:
		if registered_source == source:
			return

		if (
			runtime_id != 0
			and registered_source.get_runtime_id() == runtime_id
		):
			return

	if runtime_id == 0:
		return

	_slowdown_sources.append(source)
	_evaluate_slowdown_areas()


func unregister_slowdown_source(source: SlowdownAreaSource) -> void:
	if source == null:
		return

	_slowdown_sources.erase(source)
	_evaluate_slowdown_areas()


func refresh_slowdown_source(source: SlowdownAreaSource) -> void:
	if source == null:
		return

	if not _slowdown_sources.has(source):
		return

	_evaluate_slowdown_areas()


func spawn_basic_virus_from_random_edge() -> BasicVirus:
	var enemy: DesktopVirus = spawn_enemy_from_random_edge(
		basic_virus_scene
	)

	return enemy as BasicVirus


func spawn_enemy_from_random_edge(
	enemy_scene: PackedScene
) -> DesktopVirus:
	if enemy_scene == null:
		push_error("Cannot spawn enemy: enemy scene is null.")
		return null

	var enemy: DesktopVirus = _instantiate_enemy(enemy_scene)

	if enemy == null:
		return null

	enemy.virus_data_reward = maxi(
		0,
		virus_data_reward_per_kill
	)

	if not _register_spawned_enemy(enemy):
		return null

	_place_enemy_at_random_edge(enemy)

	return enemy


func spawn_enemy_from_wave_entry(
	wave_entry: WaveEnemyEntry,
	daily_wave: DailyWaveData,
	additional_health_multiplier: float = 1.0,
	additional_damage_multiplier: float = 1.0
) -> DesktopVirus:
	if wave_entry == null:
		push_error("Cannot spawn enemy: wave entry is null.")
		return null

	if not wave_entry.is_configured():
		push_error(
			"Cannot spawn enemy: wave entry is not configured."
		)
		return null

	var archetype: EnemyArchetypeData = (
		wave_entry.archetype
	)

	var enemy: DesktopVirus = _instantiate_enemy(
		archetype.enemy_scene
	)

	if enemy == null:
		return null

	var runtime_stats: EnemyRuntimeStats = (
		wave_entry.create_runtime_stats(
			daily_wave,
			additional_health_multiplier,
			additional_damage_multiplier
		)
	)

	if runtime_stats == null:
		return null

	enemy.apply_archetype_presentation(archetype)
	enemy.apply_runtime_stats(runtime_stats)

	if not _register_spawned_enemy(enemy):
		return null

	_place_enemy_at_random_edge(enemy)

	return enemy


func get_active_enemy_count() -> int:
	_prune_invalid_enemies()

	return _active_enemies.size()


func get_active_enemy_count_by_id(
	enemy_id: StringName
) -> int:
	if enemy_id == StringName():
		return 0

	_prune_invalid_enemies()

	var enemy_count: int = 0

	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.enemy_id != enemy_id:
			continue

		enemy_count += 1

	return enemy_count


func get_active_enemies() -> Array[DesktopVirus]:
	_prune_invalid_enemies()

	var enemies: Array[DesktopVirus] = []

	for enemy_value: Variant in _active_enemies:
		if enemy_value == null:
			continue

		if not is_instance_valid(enemy_value):
			continue

		if not enemy_value is DesktopVirus:
			continue

		var enemy: DesktopVirus = enemy_value as DesktopVirus
		if enemy == null:
			continue

		enemies.append(enemy)

	return enemies


func create_enemies_save_snapshot() -> Array[Dictionary]:
	_prune_invalid_enemies()

	var snapshot: Array[Dictionary] = []
	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.is_dead():
			continue

		snapshot.append(enemy.create_save_snapshot())

	return snapshot


func clear_enemies_for_restore() -> void:
	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		enemy.free()

	_active_enemies.clear()
	_test_enemy_spawned = false


func restore_enemies(
	enemies_snapshot: Array,
	content_registry: GameContentRegistry
) -> PersistenceResult:
	if content_registry == null:
		return PersistenceResult.failure(
			&"missing_content_registry",
			"Cannot restore enemies without a content registry."
		)

	clear_enemies_for_restore()

	for value: Variant in enemies_snapshot:
		if not value is Dictionary:
			return PersistenceResult.failure(
				&"invalid_enemy_snapshot",
				"An enemy snapshot is not an object."
			)

		var enemy_data: Dictionary = value as Dictionary
		var archetype_id: StringName = StringName(
			str(enemy_data.get("archetype_id", ""))
		)
		var archetype: EnemyArchetypeData = (
			content_registry.get_enemy_archetype(
				archetype_id
			)
		)
		if archetype == null:
			return PersistenceResult.failure(
				&"unknown_enemy_archetype",
				"Cannot restore unknown enemy '%s'."
					% str(archetype_id)
			)

		var enemy: DesktopVirus = _instantiate_enemy(
			archetype.enemy_scene
		)
		if enemy == null:
			return PersistenceResult.failure(
				&"enemy_restore_failed",
				"Could not instantiate enemy '%s'."
					% str(archetype_id)
			)

		var runtime_stats_variant: Variant = enemy_data.get(
			"runtime_stats",
			{}
		)
		var runtime_stats: EnemyRuntimeStats = (
			EnemyRuntimeStats.from_save_snapshot(
				runtime_stats_variant as Dictionary
			)
		)
		enemy.apply_archetype_presentation(archetype)
		enemy.prepare_for_restore(runtime_stats)

		if not _attach_enemy(enemy):
			return PersistenceResult.failure(
				&"enemy_restore_failed",
				"Could not attach enemy '%s'."
					% str(archetype_id)
			)

		enemy.restore_from_save_snapshot(enemy_data)

	return PersistenceResult.ok()

func has_enemy_at_global_position(
	target_global_position: Vector2
) -> bool:
	return (
		get_first_enemy_at_global_position(
			target_global_position
		)
		!= null
	)


func get_first_enemy_at_global_position(
	target_global_position: Vector2
) -> DesktopVirus:
	_prune_invalid_enemies()

	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.contains_global_point(
			target_global_position
		):
			return enemy

	return null

func get_enemies_with_center_inside_global_rect(
	global_rect: Rect2,
	max_count: int = 1
) -> Array[DesktopVirus]:
	_prune_invalid_enemies()

	var enemies: Array[DesktopVirus] = []

	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		if not global_rect.has_point(
			enemy.get_center_global_position()
		):
			continue

		enemies.append(enemy)

		if max_count > 0 and enemies.size() >= max_count:
			break

	return enemies

func get_enemies_inside_or_intersecting_global_rect(
	global_rect: Rect2,
	max_count: int = 1
) -> Array[DesktopVirus]:
	_prune_invalid_enemies()

	var enemies: Array[DesktopVirus] = []

	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		var enemy_rect: Rect2 = enemy.get_global_rect()
		var enemy_center: Vector2 = (
			enemy.get_center_global_position()
		)

		var center_is_inside: bool = global_rect.has_point(
			enemy_center
		)

		var rect_intersects: bool = global_rect.intersects(
			enemy_rect,
			true
		)

		if not center_is_inside and not rect_intersects:
			continue

		enemies.append(enemy)

		if max_count > 0 and enemies.size() >= max_count:
			break

	return enemies

func _resolve_references() -> void:
	_economy_state = GameState.economy_state

	if playfield_layer == null:
		playfield_layer = (
			get_node_or_null("../PlayfieldLayer")
			as Control
		)

	if system_manager == null:
		system_manager = (
			get_node_or_null("../SystemManager")
			as SystemManager
		)

	if shooting_manager == null:
		shooting_manager = (
			get_node_or_null("../ShootingManager")
			as ShootingManager
		)

	if window_manager == null:
		window_manager = (
			get_node_or_null("../WindowManager")
			as WindowManager
		)

	if navigation_manager == null:
		navigation_manager = get_node_or_null(
			"../FirewallNavigationManager"
		)


func _validate_dependencies() -> bool:
	if _economy_state == null:
		push_error("EnemyManager requires GameEconomyState.")
		return false

	if playfield_layer == null:
		push_error(
			"EnemyManager requires a PlayfieldLayer reference."
		)
		return false

	if system_manager == null:
		push_error(
			"EnemyManager requires a SystemManager reference."
		)
		return false

	if shooting_manager == null:
		push_error(
			"EnemyManager requires a ShootingManager reference."
		)
		return false

	if window_manager == null:
		push_error(
			"EnemyManager requires a WindowManager reference."
		)
		return false

	if navigation_manager == null:
		push_error(
			"EnemyManager requires FirewallNavigationManager."
		)
		return false

	if basic_virus_scene == null and spawn_test_enemy_on_ready:
		push_error(
			"EnemyManager requires a BasicVirus scene for test spawn."
		)
		return false

	return true


func _connect_navigation_obstacle_changes() -> void:
	if navigation_manager == null:
		return

	if not navigation_manager.has_signal(
		"firewall_obstacles_changed"
	):
		return

	var obstacle_changed_callable: Callable = Callable(
		self,
		"_on_navigation_obstacles_changed"
	)
	if navigation_manager.is_connected(
		"firewall_obstacles_changed",
		obstacle_changed_callable
	):
		return

	navigation_manager.connect(
		"firewall_obstacles_changed",
		obstacle_changed_callable
	)


func _on_navigation_obstacles_changed() -> void:
	_prune_invalid_enemies()

	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		enemy.invalidate_navigation_path()


func _instantiate_enemy(
	enemy_scene: PackedScene
) -> DesktopVirus:
	var enemy: DesktopVirus = (
		enemy_scene.instantiate()
		as DesktopVirus
	)

	if enemy == null:
		push_error(
			"Enemy scene must inherit from DesktopVirus."
		)
		return null

	return enemy


func _register_spawned_enemy(enemy: DesktopVirus) -> bool:
	if not _attach_enemy(enemy):
		return false

	enemy_spawned.emit(enemy)
	return true


func _attach_enemy(enemy: DesktopVirus) -> bool:
	if enemy == null:
		return false

	if enemy.get_parent() != null or _active_enemies.has(enemy):
		push_error("Cannot attach an enemy more than once.")
		return false

	enemy.configure(
		system_manager,
		window_manager,
		navigation_manager
	)

	playfield_layer.add_child(enemy)

	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)

	_active_enemies.append(enemy)
	_apply_slowdown_to_enemy(enemy)
	return true


func _update_slowdown_areas(delta: float) -> void:
	_slowdown_evaluation_elapsed += maxf(0.0, delta)

	var interval: float = maxf(
		0.01,
		slowdown_evaluation_interval_seconds
	)
	if _slowdown_evaluation_elapsed < interval:
		return

	_slowdown_evaluation_elapsed = fmod(
		_slowdown_evaluation_elapsed,
		interval
	)
	_evaluate_slowdown_areas()


func _evaluate_slowdown_areas() -> void:
	_prune_invalid_slowdown_sources()
	_prune_invalid_enemies()

	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		_apply_slowdown_to_enemy(enemy)


func _apply_slowdown_to_enemy(enemy: DesktopVirus) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return

	if enemy.is_dead():
		enemy.set_active_slow_multiplier(1.0)
		return

	var enemy_center: Vector2 = enemy.get_center_global_position()
	var effective_multiplier: float = 1.0

	for source: SlowdownAreaSource in _slowdown_sources:
		if source == null or not source.is_active():
			continue

		var radius: float = source.get_effect_radius()
		if radius <= 0.0:
			continue

		var source_center: Vector2 = (
			source.get_center_global_position()
		)
		if (
			source_center.distance_squared_to(enemy_center)
			> radius * radius
		):
			continue

		effective_multiplier = minf(
			effective_multiplier,
			source.get_speed_multiplier()
		)

	enemy.set_active_slow_multiplier(effective_multiplier)


func _prune_invalid_slowdown_sources() -> void:
	for index: int in range(
		_slowdown_sources.size() - 1,
		-1,
		-1
	):
		var source: SlowdownAreaSource = _slowdown_sources[index]
		if source != null and source.is_active():
			continue

		_slowdown_sources.remove_at(index)


func _place_enemy_at_random_edge(enemy: DesktopVirus) -> void:
	if enemy == null:
		return

	enemy.global_position = _get_random_spawn_position(
		_get_enemy_spawn_size(enemy)
	)


func _on_system_target_registered(
	_executable: DesktopExecutable
) -> void:
	_try_spawn_initial_enemy()


func _try_spawn_initial_enemy() -> void:
	if not spawn_test_enemy_on_ready:
		return

	if _test_enemy_spawned:
		return

	if system_manager.get_system_executable() == null:
		return

	var enemy: BasicVirus = spawn_basic_virus_from_random_edge()

	_test_enemy_spawned = enemy != null


func _on_shot_fired(
	target_global_position: Vector2,
	damage_amount: float
) -> void:
	var hit_enemies: Array[DesktopVirus] = (
		_get_enemies_at_global_position(
			target_global_position
		)
	)

	if hit_enemies.is_empty():
		return

	for enemy: DesktopVirus in hit_enemies:
		if not is_instance_valid(enemy):
			continue

		enemy.receive_damage(damage_amount)


func _get_enemies_at_global_position(
	target_global_position: Vector2
) -> Array[DesktopVirus]:
	_prune_invalid_enemies()

	var hit_enemies: Array[DesktopVirus] = []

	for enemy: DesktopVirus in _active_enemies:
		if not is_instance_valid(enemy):
			continue

		if not enemy.contains_global_point(
			target_global_position
		):
			continue

		hit_enemies.append(enemy)

	return hit_enemies


func _can_apply_enemy_separation() -> bool:
	if not enemy_separation_enabled:
		return false

	if enemy_separation_distance <= 0.0:
		return false

	if enemy_separation_strength <= 0.0:
		return false

	if _active_enemies.size() <= 1:
		return false

	return true


func _apply_enemy_separation(delta: float) -> void:
	_prune_invalid_enemies()

	var enemy_count: int = _active_enemies.size()

	if enemy_count <= 1:
		return

	var separation_distance_squared: float = (
		enemy_separation_distance
		* enemy_separation_distance
	)

	for first_index: int in range(enemy_count):
		var first_enemy: DesktopVirus = _active_enemies[
			first_index
		]

		if not is_instance_valid(first_enemy):
			continue

		for second_index: int in range(
			first_index + 1,
			enemy_count
		):
			var second_enemy: DesktopVirus = _active_enemies[
				second_index
			]

			if not is_instance_valid(second_enemy):
				continue

			_apply_separation_between_pair(
				first_enemy,
				second_enemy,
				delta,
				separation_distance_squared
			)


func _apply_separation_between_pair(
	first_enemy: DesktopVirus,
	second_enemy: DesktopVirus,
	delta: float,
	separation_distance_squared: float
) -> void:
	var first_can_push: bool = (
		first_enemy.can_receive_separation_push()
	)

	var second_can_push: bool = (
		second_enemy.can_receive_separation_push()
	)

	if not first_can_push and not second_can_push:
		return

	var first_center: Vector2 = (
		first_enemy.get_center_global_position()
	)

	var second_center: Vector2 = (
		second_enemy.get_center_global_position()
	)

	var offset: Vector2 = second_center - first_center
	var distance_squared: float = offset.length_squared()

	if distance_squared >= separation_distance_squared:
		return

	var distance: float = sqrt(distance_squared)
	var direction: Vector2 = _get_separation_direction(
		offset,
		distance
	)

	var overlap_ratio: float = 1.0 - (
		distance / enemy_separation_distance
	)

	var push_amount: float = _get_separation_push_amount(
		overlap_ratio,
		delta
	)

	if push_amount <= 0.0:
		return

	var push_vector: Vector2 = direction * push_amount

	_apply_push_to_pair(
		first_enemy,
		second_enemy,
		push_vector,
		first_can_push,
		second_can_push
	)


func _get_separation_direction(
	offset: Vector2,
	distance: float
) -> Vector2:
	if distance <= 0.001:
		return Vector2.RIGHT.rotated(
			_random.randf_range(
				0.0,
				TAU
			)
		)

	return offset / distance


func _get_separation_push_amount(
	overlap_ratio: float,
	delta: float
) -> float:
	var raw_push_amount: float = (
		enemy_separation_strength
		* clampf(overlap_ratio, 0.0, 1.0)
		* delta
	)

	return minf(
		raw_push_amount,
		max_separation_push_per_frame
	)


func _apply_push_to_pair(
	first_enemy: DesktopVirus,
	second_enemy: DesktopVirus,
	push_vector: Vector2,
	first_can_push: bool,
	second_can_push: bool
) -> void:
	if first_can_push and second_can_push:
		first_enemy.apply_external_push(
			-push_vector * 0.5
		)

		second_enemy.apply_external_push(
			push_vector * 0.5
		)

		return

	if first_can_push:
		first_enemy.apply_external_push(
			-push_vector
		)
		return

	if second_can_push:
		second_enemy.apply_external_push(
			push_vector
		)


func _get_random_spawn_position(
	enemy_size: Vector2
) -> Vector2:
	var layer_rect: Rect2 = playfield_layer.get_global_rect()
	var layer_end: Vector2 = layer_rect.end

	var minimum_x: float = layer_rect.position.x
	var maximum_x: float = maxf(
		minimum_x,
		layer_end.x - enemy_size.x
	)

	var minimum_y: float = layer_rect.position.y
	var maximum_y: float = maxf(
		minimum_y,
		layer_end.y - enemy_size.y
	)

	var edge: int = _random.randi_range(0, 3)

	match edge:
		0:
			return Vector2(
				_random.randf_range(
					minimum_x,
					maximum_x
				),
				layer_rect.position.y
				- enemy_size.y
				- spawn_margin
			)

		1:
			return Vector2(
				layer_end.x + spawn_margin,
				_random.randf_range(
					minimum_y,
					maximum_y
				)
			)

		2:
			return Vector2(
				_random.randf_range(
					minimum_x,
					maximum_x
				),
				layer_end.y + spawn_margin
			)

		_:
			return Vector2(
				layer_rect.position.x
				- enemy_size.x
				- spawn_margin,
				_random.randf_range(
					minimum_y,
					maximum_y
				)
			)


func _get_enemy_spawn_size(enemy: DesktopVirus) -> Vector2:
	if enemy == null:
		return Vector2(48.0, 48.0)

	if enemy.size != Vector2.ZERO:
		return enemy.size

	if enemy.custom_minimum_size != Vector2.ZERO:
		return enemy.custom_minimum_size

	return Vector2(48.0, 48.0)


func _on_enemy_died(enemy: DesktopVirus) -> void:
	_active_enemies.erase(enemy)

	var virus_data_reward: int = _get_virus_data_reward_for_enemy(
		enemy
	)

	_economy_state.register_enemy_kill(
		virus_data_reward
	)

	enemy_removed.emit(enemy)


func _get_virus_data_reward_for_enemy(
	enemy: DesktopVirus
) -> int:
	if enemy == null:
		return virus_data_reward_per_kill

	return maxi(
		0,
		enemy.get_virus_data_reward()
	)


func _prune_invalid_enemies() -> void:
	for index: int in range(
		_active_enemies.size() - 1,
		-1,
		-1
	):
		var enemy_value: Variant = _active_enemies[index]

		if (
			enemy_value != null
			and is_instance_valid(enemy_value)
			and enemy_value is DesktopVirus
		):
			continue

		_active_enemies.remove_at(index)
