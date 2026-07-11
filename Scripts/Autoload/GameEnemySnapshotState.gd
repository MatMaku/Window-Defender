extends Node
class_name GameEnemySnapshotState

var active_enemy_snapshots: Array = []


func reset() -> void:
	active_enemy_snapshots.clear()


func set_enemy_snapshots(enemy_snapshots: Array) -> void:
	active_enemy_snapshots = enemy_snapshots.duplicate(true)


func get_enemy_snapshots() -> Array:
	return active_enemy_snapshots.duplicate(true)


func clear_enemy_snapshots() -> void:
	active_enemy_snapshots.clear()
