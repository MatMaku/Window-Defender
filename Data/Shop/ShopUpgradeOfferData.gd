extends Resource
class_name ShopUpgradeOfferData

enum EffectType {
	NONE,
	SHOT_DAMAGE_ADD,
	FIRE_COOLDOWN_MULTIPLY,
	MAX_AMMO_ADD,
	NORMAL_RELOAD_DURATION_MULTIPLY,
	MINER_CRYPTO_PER_TICK_ADD,
	MINER_INTERVAL,
	MAX_RAM_ADD,
	DESKTOP_RESOLUTION_TIER_ADD,
	UNLOCK_AUTO_FIRE,
	UNLOCK_AREA_SHOT,
	AREA_SHOT_TARGETS_ADD,
	UNLOCK_AUTO_RELOAD,
	FIREWALL_SIZE_LEVEL,
	SLOWDOWN_STRENGTH_LEVEL,
	TURRET_PERFORMANCE_LEVEL
}

@export_category("Identity")

@export var offer_id: StringName
@export var display_name: String = "Upgrade"
@export var icon: Texture2D
@export_multiline var description: String = ""

@export_category("Progression")

@export_range(1, 99, 1)
var max_purchase_count: int = 1

@export var level_names: Array[String] = []
@export var show_when_maxed: bool = false

@export_category("Costs")

@export var crypto_costs: Array[int] = [10]
@export var virus_data_costs: Array[int] = [1]

@export_category("Requirements")

@export var required_program_id: StringName = StringName()

@export var required_upgrade_id: StringName = StringName()

@export_range(1, 99, 1)
var required_upgrade_level: int = 1

@export_category("Effect")

@export var effect_type: EffectType = EffectType.NONE
@export var effect_values: Array[float] = [1.0]
@export var secondary_effect_values: Array[float] = []
@export var tertiary_effect_values: Array[float] = []


func get_primary_effect_for_purchase_count(
	purchase_count: int,
	fallback_value: float
) -> float:
	return _get_effect_for_purchase_count(
		effect_values,
		purchase_count,
		fallback_value
	)


func get_secondary_effect_for_purchase_count(
	purchase_count: int,
	fallback_value: float
) -> float:
	return _get_effect_for_purchase_count(
		secondary_effect_values,
		purchase_count,
		fallback_value
	)


func get_tertiary_effect_for_purchase_count(
	purchase_count: int,
	fallback_value: float
) -> float:
	return _get_effect_for_purchase_count(
		tertiary_effect_values,
		purchase_count,
		fallback_value
	)


func _get_effect_for_purchase_count(
	values: Array[float],
	purchase_count: int,
	fallback_value: float
) -> float:
	if purchase_count <= 0 or values.is_empty():
		return fallback_value

	var value_index: int = clampi(
		purchase_count - 1,
		0,
		values.size() - 1
	)
	return values[value_index]
