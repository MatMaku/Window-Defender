extends Node
class_name EnemyManager

@export var playfield_layer: Control
@export var system_manager: SystemManager
@export var shooting_manager: ShootingManager
@export var window_manager: WindowManager

@export_category("Enemy Scenes")

@export var basic_virus_scene: PackedScene

@export_category("Testing")

@export var spawn_test_enemy_on_ready: bool = true

@export_range(0.0, 200.0, 1.0)
var spawn_margin: float = 24.0

var _active_viruses: Array[BasicVirus] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

var _test_enemy_spawned: bool = false


func _ready() -> void:
	if playfield_layer == null:
		push_error("EnemyManager requires a PlayfieldLayer reference.")
		return

	if system_manager == null:
		push_error("EnemyManager requires a SystemManager reference.")
		return

	if shooting_manager == null:
		push_error("EnemyManager requires a ShootingManager reference.")
		return

	if window_manager == null:
		push_error("EnemyManager requires a WindowManager reference.")
		return

	if basic_virus_scene == null:
		push_error("EnemyManager requires a BasicVirus scene.")
		return

	_random.randomize()

	shooting_manager.shot_fired.connect(
		_on_shot_fired
	)

	system_manager.system_target_registered.connect(
		_on_system_target_registered
	)

	call_deferred("_try_spawn_initial_enemy")


func spawn_basic_virus_from_random_edge() -> BasicVirus:
	var virus: BasicVirus = (
		basic_virus_scene.instantiate() as BasicVirus
	)

	if virus == null:
		push_error(
			"Basic virus scene must inherit from BasicVirus."
		)
		return null

	virus.configure(
		system_manager,
		window_manager
	)

	playfield_layer.add_child(virus)

	virus.global_position = _get_random_spawn_position(
		virus.size
	)

	virus.died.connect(_on_virus_died)

	_active_viruses.append(virus)

	return virus


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
	var hit_virus: BasicVirus = (
		_get_virus_at_global_position(
			target_global_position
		)
	)

	if hit_virus == null:
		return

	hit_virus.receive_damage(damage_amount)


func _get_virus_at_global_position(
	target_global_position: Vector2
) -> BasicVirus:
	_prune_invalid_viruses()

	var closest_virus: BasicVirus = null
	var closest_distance: float = INF

	for virus: BasicVirus in _active_viruses:
		if not is_instance_valid(virus):
			continue

		var virus_rect: Rect2 = virus.get_global_rect()

		if not virus_rect.has_point(target_global_position):
			continue

		var virus_center: Vector2 = virus_rect.get_center()

		var distance_to_target: float = (
			virus_center.distance_to(target_global_position)
		)

		if distance_to_target >= closest_distance:
			continue

		closest_distance = distance_to_target
		closest_virus = virus

	return closest_virus


func _get_random_spawn_position(
	virus_size: Vector2
) -> Vector2:
	var layer_rect: Rect2 = playfield_layer.get_global_rect()
	var layer_end: Vector2 = layer_rect.end

	var minimum_x: float = layer_rect.position.x
	var maximum_x: float = maxf(
		minimum_x,
		layer_end.x - virus_size.x
	)

	var minimum_y: float = layer_rect.position.y
	var maximum_y: float = maxf(
		minimum_y,
		layer_end.y - virus_size.y
	)

	var edge: int = _random.randi_range(0, 3)

	match edge:
		0:
			return Vector2(
				_random.randf_range(minimum_x, maximum_x),
				layer_rect.position.y - virus_size.y - spawn_margin
			)

		1:
			return Vector2(
				layer_end.x + spawn_margin,
				_random.randf_range(minimum_y, maximum_y)
			)

		2:
			return Vector2(
				_random.randf_range(minimum_x, maximum_x),
				layer_end.y + spawn_margin
			)

		_:
			return Vector2(
				layer_rect.position.x - virus_size.x - spawn_margin,
				_random.randf_range(minimum_y, maximum_y)
			)


func _on_virus_died(virus: BasicVirus) -> void:
	_active_viruses.erase(virus)


func _prune_invalid_viruses() -> void:
	for index: int in range(
		_active_viruses.size() - 1,
		-1,
		-1
	):
		var virus: BasicVirus = _active_viruses[index]

		if not is_instance_valid(virus):
			_active_viruses.remove_at(index)
