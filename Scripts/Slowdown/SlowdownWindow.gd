extends AppWindow
class_name SlowdownWindow

@export_category("Slowdown Effect")

@export var effect_data: SlowdownEffectData

@export_category("Upgrade")

@export var strength_upgrade_offer: ShopUpgradeOfferData

@onready var effect_origin: Marker2D = %EffectOrigin

var _enemy_manager: EnemyManager
var _area_source: SlowdownAreaSource
var _upgrade_state: GameUpgradeState
var _effective_speed_multiplier: float = 1.0


func configure_runtime_services(
	_window_manager: WindowManager,
	enemy_manager: EnemyManager
) -> void:
	_enemy_manager = enemy_manager


func _ready() -> void:
	super._ready()
	_resolve_upgrade_state()


func play_open_animation(
	duration_multiplier: float = 1.0
) -> void:
	_register_effect()
	super.play_open_animation(duration_multiplier)


func prepare_after_restore() -> void:
	super.prepare_after_restore()
	_register_effect()


func _exit_tree() -> void:
	_unregister_effect()


func _register_effect() -> void:
	if _area_source != null:
		return

	if not is_inside_tree():
		return

	if _enemy_manager == null:
		push_error("SlowdownWindow requires EnemyManager.")
		return

	if effect_data == null:
		push_error("SlowdownWindow requires SlowdownEffectData.")
		return

	_area_source = SlowdownAreaSource.new()
	_area_source.configure(
		self,
		effect_origin,
		effect_data
	)
	_area_source.set_speed_multiplier(
		_effective_speed_multiplier
	)
	_enemy_manager.register_slowdown_source(_area_source)


func _unregister_effect() -> void:
	if _area_source == null:
		return

	if is_instance_valid(_enemy_manager):
		_enemy_manager.unregister_slowdown_source(_area_source)

	_area_source = null


func _resolve_upgrade_state() -> void:
	_upgrade_state = GameState.upgrade_state
	if _upgrade_state == null:
		push_error("SlowdownWindow requires GameUpgradeState.")
		_apply_strength_upgrade()
		return

	if not _upgrade_state.upgrade_purchase_counts_changed.is_connected(
		_on_upgrade_purchase_counts_changed
	):
		_upgrade_state.upgrade_purchase_counts_changed.connect(
			_on_upgrade_purchase_counts_changed
		)

	_apply_strength_upgrade()


func _on_upgrade_purchase_counts_changed(
	_purchase_counts_snapshot: Dictionary
) -> void:
	_apply_strength_upgrade()


func _apply_strength_upgrade() -> void:
	var base_multiplier: float = 1.0
	if effect_data != null:
		base_multiplier = effect_data.get_speed_multiplier()

	var next_multiplier: float = base_multiplier
	if _upgrade_state != null and strength_upgrade_offer != null:
		var purchase_count: int = (
			_upgrade_state.get_upgrade_purchase_count(
				strength_upgrade_offer.offer_id
			)
		)
		next_multiplier = (
			strength_upgrade_offer.get_primary_effect_for_purchase_count(
				purchase_count,
				base_multiplier
			)
		)

	_effective_speed_multiplier = clampf(
		next_multiplier,
		0.0,
		1.0
	)
	if _area_source == null:
		return

	_area_source.set_speed_multiplier(
		_effective_speed_multiplier
	)
	if is_instance_valid(_enemy_manager):
		_enemy_manager.refresh_slowdown_source(
			_area_source
		)
