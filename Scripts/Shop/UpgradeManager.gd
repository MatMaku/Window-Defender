extends Node
class_name UpgradeManager

signal upgrade_purchased(
	offer: ShopUpgradeOfferData,
	new_purchase_count: int
)

signal upgrades_changed


func get_purchase_count(
	offer: ShopUpgradeOfferData
) -> int:
	if offer == null:
		return 0

	return GameState.get_upgrade_purchase_count(
		offer.offer_id
	)


func is_upgrade_maxed(
	offer: ShopUpgradeOfferData
) -> bool:
	if offer == null:
		return true

	return get_purchase_count(offer) >= maxi(
		1,
		offer.max_purchase_count
	)


func can_show_upgrade(
	offer: ShopUpgradeOfferData
) -> bool:
	if offer == null:
		return false

	if offer.offer_id == StringName():
		return false

	if is_upgrade_maxed(offer):
		return false

	if offer.required_upgrade_id == StringName():
		return true

	return (
		GameState.get_upgrade_purchase_count(
			offer.required_upgrade_id
		)
		>= maxi(1, offer.required_upgrade_level)
	)


func can_purchase_upgrade(
	offer: ShopUpgradeOfferData
) -> bool:
	if not can_show_upgrade(offer):
		return false

	return GameState.can_afford_resources(
		get_crypto_cost(offer),
		get_virus_data_cost(offer)
	)


func purchase_upgrade(
	offer: ShopUpgradeOfferData
) -> bool:
	if not can_purchase_upgrade(offer):
		return false

	var level_index: int = get_purchase_count(offer)

	if not GameState.try_spend_resources(
		get_crypto_cost(offer),
		get_virus_data_cost(offer)
	):
		return false

	_apply_upgrade_effect(
		offer,
		level_index
	)

	var new_purchase_count: int = (
		GameState.increment_upgrade_purchase_count(
			offer.offer_id,
			1
		)
	)

	upgrade_purchased.emit(
		offer,
		new_purchase_count
	)

	upgrades_changed.emit()

	return true


func get_display_name(
	offer: ShopUpgradeOfferData
) -> String:
	if offer == null:
		return "Unknown Upgrade"

	var level_index: int = get_purchase_count(offer)

	if (
		level_index >= 0
		and level_index < offer.level_names.size()
	):
		var level_name: String = offer.level_names[level_index]

		if level_name != "":
			return level_name

	if offer.max_purchase_count <= 1:
		return offer.display_name

	return "%s %s" % [
		offer.display_name,
		_to_roman(level_index + 1)
	]


func get_crypto_cost(
	offer: ShopUpgradeOfferData
) -> int:
	if offer == null:
		return 0

	return _get_int_from_array(
		offer.crypto_costs,
		get_purchase_count(offer),
		0
	)


func get_virus_data_cost(
	offer: ShopUpgradeOfferData
) -> int:
	if offer == null:
		return 0

	return _get_int_from_array(
		offer.virus_data_costs,
		get_purchase_count(offer),
		0
	)


func get_price_text(
	offer: ShopUpgradeOfferData
) -> String:
	return "$%d / D %d" % [
		get_crypto_cost(offer),
		get_virus_data_cost(offer)
	]


func _apply_upgrade_effect(
	offer: ShopUpgradeOfferData,
	level_index: int
) -> void:
	var value: float = _get_float_from_array(
		offer.effect_values,
		level_index,
		0.0
	)

	match offer.effect_type:
		ShopUpgradeOfferData.EffectType.SHOT_DAMAGE_ADD:
			GameState.set_shot_damage(
				GameState.shot_damage + value
			)

		ShopUpgradeOfferData.EffectType.FIRE_COOLDOWN_MULTIPLY:
			GameState.set_fire_cooldown(
				GameState.fire_cooldown_seconds * value
			)

		ShopUpgradeOfferData.EffectType.MAX_AMMO_ADD:
			GameState.set_max_ammo(
				GameState.max_ammo + int(value),
				true
			)

		ShopUpgradeOfferData.EffectType.NORMAL_RELOAD_DURATION_MULTIPLY:
			GameState.set_normal_reload_duration(
				GameState.normal_reload_duration * value
			)

		ShopUpgradeOfferData.EffectType.MINER_CRYPTO_PER_TICK_ADD:
			GameState.set_miner_crypto_per_tick(
				GameState.miner_crypto_per_tick + int(value)
			)

		ShopUpgradeOfferData.EffectType.MINER_INTERVAL:
			GameState.set_miner_interval_seconds(
				GameState.miner_interval_seconds - value
			)

		ShopUpgradeOfferData.EffectType.MAX_RAM_ADD:
			GameState.set_max_ram(
				GameState.max_ram + int(value)
			)

		ShopUpgradeOfferData.EffectType.DESKTOP_RESOLUTION_TIER_ADD:
			GameState.set_desktop_resolution_tier(
				GameState.desktop_resolution_tier + int(value)
			)

		ShopUpgradeOfferData.EffectType.UNLOCK_AUTO_FIRE:
			GameState.set_auto_fire_unlocked(true)

		ShopUpgradeOfferData.EffectType.UNLOCK_AREA_SHOT:
			GameState.set_area_shot_unlocked(true)

		ShopUpgradeOfferData.EffectType.AREA_SHOT_TARGETS_ADD:
			GameState.add_area_shot_max_targets(
				int(value)
			)

		_:
			push_warning(
				"Upgrade '%s' has no effect configured."
				% offer.display_name
			)


func _get_int_from_array(
	values: Array[int],
	index: int,
	fallback_value: int
) -> int:
	if values.is_empty():
		return fallback_value

	var safe_index: int = clampi(
		index,
		0,
		values.size() - 1
	)

	return values[safe_index]


func _get_float_from_array(
	values: Array[float],
	index: int,
	fallback_value: float
) -> float:
	if values.is_empty():
		return fallback_value

	var safe_index: int = clampi(
		index,
		0,
		values.size() - 1
	)

	return values[safe_index]


func _to_roman(number: int) -> String:
	match number:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		6:
			return "VI"
		7:
			return "VII"
		8:
			return "VIII"
		9:
			return "IX"
		10:
			return "X"
		_:
			return str(number)
