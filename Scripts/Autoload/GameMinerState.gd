extends Node
class_name GameMinerState

var miner_crypto_per_tick: int = 1
var miner_interval_seconds: float = 5.0


func reset_from_start_data(start_data: GameStartData) -> void:
	miner_crypto_per_tick = maxi(
		0,
		start_data.miner_crypto_per_tick
	)

	miner_interval_seconds = maxf(
		0.05,
		start_data.miner_interval_seconds
	)


func set_miner_crypto_per_tick(new_amount: int) -> void:
	miner_crypto_per_tick = maxi(
		0,
		new_amount
	)


func set_miner_interval_seconds(new_interval: float) -> void:
	miner_interval_seconds = maxf(
		0.05,
		new_interval
	)
