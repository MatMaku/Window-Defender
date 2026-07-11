extends Node
class_name GameEconomyState

var crypto: int = 0
var virus_data: int = 0

var total_enemy_kills: int = 0


func reset_from_start_data(start_data: GameStartData) -> void:
	crypto = maxi(
		0,
		start_data.starting_crypto
	)

	virus_data = maxi(
		0,
		start_data.starting_virus_data
	)

	total_enemy_kills = 0


func add_crypto(amount: int) -> bool:
	if amount <= 0:
		return false

	crypto += amount
	return true


func can_spend_crypto(amount: int) -> bool:
	if amount < 0:
		return false

	return crypto >= amount


func try_spend_crypto(amount: int) -> bool:
	if amount <= 0:
		return false

	if not can_spend_crypto(amount):
		return false

	crypto -= amount
	return true


func add_virus_data(amount: int) -> bool:
	if amount <= 0:
		return false

	virus_data += amount
	return true


func can_spend_virus_data(amount: int) -> bool:
	if amount < 0:
		return false

	return virus_data >= amount


func try_spend_virus_data(amount: int) -> bool:
	if amount <= 0:
		return false

	if not can_spend_virus_data(amount):
		return false

	virus_data -= amount
	return true


func register_enemy_kill(virus_data_reward: int = 1) -> void:
	total_enemy_kills += 1

	add_virus_data(
		virus_data_reward
	)


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
		crypto -= crypto_cost

	if virus_data_cost > 0:
		virus_data -= virus_data_cost

	return true
