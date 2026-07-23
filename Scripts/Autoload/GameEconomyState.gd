extends Node
class_name GameEconomyState

signal crypto_changed(current_crypto: int)
signal virus_data_changed(current_virus_data: int)
signal enemy_kills_changed(total_enemy_kills: int)

var crypto: int:
	get:
		return _crypto

var virus_data: int:
	get:
		return _virus_data

var total_enemy_kills: int:
	get:
		return _total_enemy_kills

var _crypto: int = 0
var _virus_data: int = 0
var _total_enemy_kills: int = 0


func reset_from_start_data(start_data: GameStartData) -> void:
	_crypto = maxi(
		0,
		start_data.starting_crypto
	)

	_virus_data = maxi(
		0,
		start_data.starting_virus_data
	)

	_total_enemy_kills = 0

	crypto_changed.emit(_crypto)
	virus_data_changed.emit(_virus_data)
	enemy_kills_changed.emit(_total_enemy_kills)


func add_crypto(amount: int) -> bool:
	if amount <= 0:
		return false

	_crypto += amount
	crypto_changed.emit(_crypto)
	return true


func can_spend_crypto(amount: int) -> bool:
	if amount < 0:
		return false

	return _crypto >= amount


func try_spend_crypto(amount: int) -> bool:
	if amount <= 0:
		return false

	if not can_spend_crypto(amount):
		return false

	_crypto -= amount
	crypto_changed.emit(_crypto)
	return true


func add_virus_data(amount: int) -> bool:
	if amount <= 0:
		return false

	_virus_data += amount
	virus_data_changed.emit(_virus_data)
	return true


func can_spend_virus_data(amount: int) -> bool:
	if amount < 0:
		return false

	return _virus_data >= amount


func try_spend_virus_data(amount: int) -> bool:
	if amount <= 0:
		return false

	if not can_spend_virus_data(amount):
		return false

	_virus_data -= amount
	virus_data_changed.emit(_virus_data)
	return true


func register_enemy_kill(virus_data_reward: int = 1) -> void:
	_total_enemy_kills += 1
	enemy_kills_changed.emit(_total_enemy_kills)

	if virus_data_reward > 0:
		_virus_data += virus_data_reward
		virus_data_changed.emit(_virus_data)


func can_afford_resources(
	crypto_cost: int,
	virus_data_cost: int
) -> bool:
	return (
		can_spend_crypto(crypto_cost)
		and can_spend_virus_data(virus_data_cost)
	)


func try_spend_resources(
	crypto_cost: int,
	virus_data_cost: int
) -> bool:
	if not can_afford_resources(
		crypto_cost,
		virus_data_cost
	):
		return false

	if crypto_cost > 0:
		_crypto -= crypto_cost
		crypto_changed.emit(_crypto)

	if virus_data_cost > 0:
		_virus_data -= virus_data_cost
		virus_data_changed.emit(_virus_data)

	return true
