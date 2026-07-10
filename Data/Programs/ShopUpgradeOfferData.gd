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
	AREA_SHOT_TARGETS_ADD
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

@export_category("Costs")

@export var crypto_costs: Array[int] = [10]
@export var virus_data_costs: Array[int] = [1]

@export_category("Requirements")

@export var required_upgrade_id: StringName = StringName()

@export_range(1, 99, 1)
var required_upgrade_level: int = 1

@export_category("Effect")

@export var effect_type: EffectType = EffectType.NONE
@export var effect_values: Array[float] = [1.0]
