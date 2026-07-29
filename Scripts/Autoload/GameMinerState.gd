extends Node
class_name GameMinerState

signal miner_stats_changed(
	crypto_per_tick: int,
	mining_interval_seconds: float
)

var miner_crypto_per_tick: int:
	get:
		return _miner_crypto_per_tick

var miner_interval_seconds: float:
	get:
		return _miner_interval_seconds

var _miner_crypto_per_tick: int = 1
var _miner_interval_seconds: float = 5.0


func reset_from_start_data(start_data: GameStartData) -> void:
	_miner_crypto_per_tick = maxi(
		0,
		start_data.miner_crypto_per_tick
	)

	_miner_interval_seconds = maxf(
		0.05,
		start_data.miner_interval_seconds
	)

	_emit_miner_stats_changed()


func set_miner_crypto_per_tick(new_amount: int) -> void:
	_miner_crypto_per_tick = maxi(
		0,
		new_amount
	)

	_emit_miner_stats_changed()


func set_miner_interval_seconds(new_interval: float) -> void:
	_miner_interval_seconds = maxf(
		0.05,
		new_interval
	)

	_emit_miner_stats_changed()


func create_save_snapshot() -> Dictionary:
	return {
		"miner_crypto_per_tick": _miner_crypto_per_tick,
		"miner_interval_seconds": _miner_interval_seconds
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	_miner_crypto_per_tick = maxi(
		0,
		int(snapshot.get("miner_crypto_per_tick", 0))
	)
	_miner_interval_seconds = maxf(
		0.05,
		float(snapshot.get("miner_interval_seconds", 0.05))
	)

	_emit_miner_stats_changed()


func _emit_miner_stats_changed() -> void:
	miner_stats_changed.emit(
		_miner_crypto_per_tick,
		_miner_interval_seconds
	)
