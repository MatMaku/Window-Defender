extends Node
class_name EnemyManager

signal enemy_spawned(enemy: BasicVirus)
signal enemy_removed(enemy: BasicVirus)

@export var playfield_layer: Control
@export var system_manager: SystemManager
@export var shooting_manager: ShootingManager
@export var window_manager: WindowManager

@export_category("Enemy Scenes")

@export var basic_virus_scene: PackedScene

@export_category("Testing")

@export var spawn_test_enemy_on_ready: bool = false

@export_range(0.0, 200.0, 1.0)
var spawn_margin: float = 24.0

@export_category("Enemy Separation")

@export var enemy_separation_enabled: bool = true

@export_range(0.0, 200.0, 1.0)
var enemy_separation_distance: float = 34.0

@export_range(0.0, 500.0, 1.0)
var enemy_separation_strength: float = 80.0

@export_range(0.0, 30.0, 0.5)
var max_separation_push_per_frame: float = 3.0

var _active_viruses: Array[BasicVirus] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

var _test_enemy_spawned: bool = false


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

	call_deferred("_try_spawn_initial_enemy")


func _process(delta: float) -> void:
	if not enemy_separation_enabled:
		return

	_apply_enemy_separation(delta)


func spawn_basic_virus_from_random_edge() -> BasicVirus:
	return spawn_enemy_from_random_edge(
		basic_virus_scene
	)


func spawn_enemy_from_random_edge(
	enemy_scene: PackedScene
) -> BasicVirus:
	if enemy_scene == null:
		push_error("Cannot spawn enemy: enemy scene is null.")
		return null

	var enemy: BasicVirus = _instantiate_enemy(enemy_scene)

	if enemy == null:
		return null

	_register_spawned_enemy(enemy)

	enemy.global_position = _get_random_spawn_position(
		_get_enemy_spawn_size(enemy)
	)

	return enemy


func get_active_enemy_count() -> int:
	_prune_invalid_viruses()

	return _active_viruses.size()


func get_active_enemies() -> Array[BasicVirus]:
	_prune_invalid_viruses()

	var enemies: Array[BasicVirus] = []

	for virus: BasicVirus in _active_viruses:
		if not is_instance_valid(virus):
			continue

		enemies.append(virus)

	return enemies


func _resolve_references() -> void:
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


func _validate_dependencies() -> bool:
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

	if basic_virus_scene == null and spawn_test_enemy_on_ready:
		push_error(
			"EnemyManager requires a BasicVirus scene for test spawn."
		)
		return false

	return true


func _instantiate_enemy(
	enemy_scene: PackedScene
) -> BasicVirus:
	var enemy: BasicVirus = (
		enemy_scene.instantiate()
		as BasicVirus
	)

	if enemy == null:
		push_error(
			"Enemy scene must inherit from BasicVirus."
		)
		return null

	return enemy


func _register_spawned_enemy(enemy: BasicVirus) -> void:
	enemy.configure(
		system_manager,
		window_manager
	)

	playfield_layer.add_child(enemy)

	if not enemy.died.is_connected(_on_virus_died):
		enemy.died.connect(_on_virus_died)

	_active_viruses.append(enemy)

	enemy_spawned.emit(enemy)


func _on_system_target_registered(
	_executable: DesktopExecutable
) -> void:
	_try_spawn_initial_enemy()


func _try_spawn_initial_enemy() -> void:
	if not spawn_test_enemy_on_ready:
		return

	if _test_enemy_spawned:
		return

	var system_executable: DesktopExecutable = (
		system_manager.get_system_executable()
	)

	if system_executable == null:
		return

	var virus: BasicVirus = (
		spawn_basic_virus_from_random_edge()
	)

	_test_enemy_spawned = virus != null


func _on_shot_fired(
	target_global_position: Vector2,
	damage_amount: float
) -> void:
	var hit_viruses: Array[BasicVirus] = (
		_get_viruses_at_global_position(
			target_global_position
		)
	)

	if hit_viruses.is_empty():
		return

	for virus: BasicVirus in hit_viruses:
		if not is_instance_valid(virus):
			continue

		virus.receive_damage(damage_amount)


func _get_viruses_at_global_position(
	target_global_position: Vector2
) -> Array[BasicVirus]:
	_prune_invalid_viruses()

	var hit_viruses: Array[BasicVirus] = []

	for virus: BasicVirus in _active_viruses:
		if not is_instance_valid(virus):
			continue

		if not virus.contains_global_point(
			target_global_position
		):
			continue

		hit_viruses.append(virus)

	return hit_viruses


func _apply_enemy_separation(delta: float) -> void:
	if enemy_separation_distance <= 0.0:
		return

	if enemy_separation_strength <= 0.0:
		return

	var enemies: Array[BasicVirus] = get_active_enemies()
	var enemy_count: int = enemies.size()

	if enemy_count <= 1:
		return

	for first_index: int in range(enemy_count):
		var first_enemy: BasicVirus = enemies[first_index]

		if not is_instance_valid(first_enemy):
			continue

		for second_index: int in range(
			first_index + 1,
			enemy_count
		):
			var second_enemy: BasicVirus = enemies[second_index]

			if not is_instance_valid(second_enemy):
				continue

			_apply_separation_between_pair(
				first_enemy,
				second_enemy,
				delta
			)


func _apply_separation_between_pair(
	first_enemy: BasicVirus,
	second_enemy: BasicVirus,
	delta: float
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
	var distance: float = offset.length()

	if distance >= enemy_separation_distance:
		return

	var direction: Vector2 = Vector2.ZERO

	if distance <= 0.001:
		direction = Vector2.RIGHT.rotated(
			_random.randf_range(
				0.0,
				TAU
			)
		)
	else:
		direction = offset / distance

	var overlap_ratio: float = 1.0 - (
		distance / enemy_separation_distance
	)

	var raw_push_amount: float = (
		enemy_separation_strength
		* overlap_ratio
		* delta
	)

	var push_amount: float = minf(
		raw_push_amount,
		max_separation_push_per_frame
	)

	if push_amount <= 0.0:
		return

	var push_vector: Vector2 = direction * push_amount

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


func _get_enemy_spawn_size(enemy: BasicVirus) -> Vector2:
	var enemy_size: Vector2 = enemy.size

	if enemy_size != Vector2.ZERO:
		return enemy_size

	enemy_size = enemy.custom_minimum_size

	if enemy_size != Vector2.ZERO:
		return enemy_size

	return Vector2(48.0, 48.0)


func _on_virus_died(virus: BasicVirus) -> void:
	_active_viruses.erase(virus)

	enemy_removed.emit(virus)


func _prune_invalid_viruses() -> void:
	for index: int in range(
		_active_viruses.size() - 1,
		-1,
		-1
	):
		var virus: BasicVirus = _active_viruses[index]

		if not is_instance_valid(virus):
			_active_viruses.remove_at(index)
