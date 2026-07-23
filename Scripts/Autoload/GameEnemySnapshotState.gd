extends Node
class_name GameEnemySnapshotState

signal enemy_snapshots_changed(enemy_snapshots: Array)

var active_enemy_snapshots: Array = []


func reset() -> void:
	active_enemy_snapshots.clear()
	_emit_enemy_snapshots_changed()


func set_enemy_snapshots(enemy_snapshots: Array) -> void:
	active_enemy_snapshots = enemy_snapshots.duplicate(true)
	_emit_enemy_snapshots_changed()


func get_enemy_snapshots() -> Array:
	return active_enemy_snapshots.duplicate(true)


func clear_enemy_snapshots() -> void:
	active_enemy_snapshots.clear()
	_emit_enemy_snapshots_changed()


func _emit_enemy_snapshots_changed() -> void:
	enemy_snapshots_changed.emit(
		get_enemy_snapshots()
	)
