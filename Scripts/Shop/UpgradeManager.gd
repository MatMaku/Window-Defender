extends Node
class_name UpgradeManager

signal upgrade_purchased(
	offer: ShopUpgradeOfferData,
	new_purchase_count: int
)

signal upgrades_changed

var _economy_state: GameEconomyState
var _upgrade_state: GameUpgradeState
var _desktop_state: GameDesktopState
var _weapon_state: GameWeaponState
var _reload_stats_state: GameReloadStatsState
var _miner_state: GameMinerState
var _ram_state: GameRamState


func _ready() -> void:
	_economy_state = GameState.economy_state
	_upgrade_state = GameState.upgrade_state
	_desktop_state = GameState.desktop_state
	_weapon_state = GameState.weapon_state
	_reload_stats_state = GameState.reload_stats_state
	_miner_state = GameState.miner_state
	_ram_state = GameState.ram_state

	if (
		_economy_state == null
		or _upgrade_state == null
		or _desktop_state == null
		or _weapon_state == null
		or _reload_stats_state == null
		or _miner_state == null
		or _ram_state == null
	):
		push_error("UpgradeManager could not resolve required states.")


func get_purchase_count(
	offer: ShopUpgradeOfferData
) -> int:
	if offer == null:
		return 0

	return _upgrade_state.get_upgrade_purchase_count(
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

	if is_upgrade_maxed(offer) and not offer.show_when_maxed:
		return false

	if not _has_required_program(offer):
		return false

	if not _has_required_upgrade(offer):
		return false

	return true


func can_purchase_upgrade(
	offer: ShopUpgradeOfferData
) -> bool:
	if not can_show_upgrade(offer):
		return false

	if is_upgrade_maxed(offer):
		return false

	return _economy_state.can_afford_resources(
		get_crypto_cost(offer),
		get_virus_data_cost(offer)
	)


func purchase_upgrade(
	offer: ShopUpgradeOfferData
) -> bool:
	if not can_purchase_upgrade(offer):
		return false

	var level_index: int = get_purchase_count(offer)

	if not _economy_state.try_spend_resources(
		get_crypto_cost(offer),
		get_virus_data_cost(offer)
	):
		return false

	_apply_upgrade_effect(
		offer,
		level_index
	)

	var new_purchase_count: int = (
		_upgrade_state.increment_upgrade_purchase_count(
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

	var purchase_count: int = get_purchase_count(offer)
	var maximum_count: int = maxi(
		1,
		offer.max_purchase_count
	)
	if offer.show_when_maxed:
		if is_upgrade_maxed(offer):
			return "%s %d/%d MAX" % [
				offer.display_name,
				purchase_count,
				maximum_count
			]

		return "%s %d/%d" % [
			offer.display_name,
			purchase_count,
			maximum_count
		]

	if is_upgrade_maxed(offer):
		return "%s MAX" % offer.display_name

	var level_index: int = purchase_count

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
	if is_upgrade_maxed(offer):
		return "MAX"

	return "$%d / D %d" % [
		get_crypto_cost(offer),
		get_virus_data_cost(offer)
	]


func _has_required_program(
	offer: ShopUpgradeOfferData
) -> bool:
	if offer.required_program_id == StringName():
		return true

	return _desktop_state.has_desktop_shortcut(
		offer.required_program_id
	)


func _has_required_upgrade(
	offer: ShopUpgradeOfferData
) -> bool:
	if offer.required_upgrade_id == StringName():
		return true

	return (
		_upgrade_state.get_upgrade_purchase_count(
			offer.required_upgrade_id
		)
		>= maxi(1, offer.required_upgrade_level)
	)


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
			_weapon_state.set_shot_damage(
				_weapon_state.shot_damage + value
			)

		ShopUpgradeOfferData.EffectType.FIRE_COOLDOWN_MULTIPLY:
			_weapon_state.set_fire_cooldown(
				_weapon_state.fire_cooldown_seconds * value
			)

		ShopUpgradeOfferData.EffectType.MAX_AMMO_ADD:
			_weapon_state.set_max_ammo(
				_weapon_state.max_ammo + int(value),
				true
			)

		ShopUpgradeOfferData.EffectType.NORMAL_RELOAD_DURATION_MULTIPLY:
			_reload_stats_state.set_normal_reload_duration(
				_reload_stats_state.normal_reload_duration * value
			)

		ShopUpgradeOfferData.EffectType.MINER_CRYPTO_PER_TICK_ADD:
			_miner_state.set_miner_crypto_per_tick(
				_miner_state.miner_crypto_per_tick + int(value)
			)

		ShopUpgradeOfferData.EffectType.MINER_INTERVAL:
			_miner_state.set_miner_interval_seconds(
				_miner_state.miner_interval_seconds - value
			)

		ShopUpgradeOfferData.EffectType.MAX_RAM_ADD:
			_ram_state.set_max_ram(
				_ram_state.max_ram + int(value)
			)

		ShopUpgradeOfferData.EffectType.DESKTOP_RESOLUTION_TIER_ADD:
			_desktop_state.set_desktop_resolution_tier(
				_desktop_state.desktop_resolution_tier + int(value)
			)

		ShopUpgradeOfferData.EffectType.UNLOCK_AUTO_FIRE:
			_upgrade_state.set_auto_fire_unlocked(true)

		ShopUpgradeOfferData.EffectType.UNLOCK_AREA_SHOT:
			_upgrade_state.set_area_shot_unlocked(true)

		ShopUpgradeOfferData.EffectType.AREA_SHOT_TARGETS_ADD:
			_upgrade_state.add_area_shot_max_targets(
				int(value)
			)

		ShopUpgradeOfferData.EffectType.UNLOCK_AUTO_RELOAD:
			_upgrade_state.set_auto_reload_unlocked(true)

		ShopUpgradeOfferData.EffectType.FIREWALL_SIZE_LEVEL:
			pass

		ShopUpgradeOfferData.EffectType.SLOWDOWN_STRENGTH_LEVEL:
			pass

		ShopUpgradeOfferData.EffectType.TURRET_PERFORMANCE_LEVEL:
			pass

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
