extends PanelContainer
class_name ShopOfferRow

signal app_purchase_requested(offer: ShopAppOfferData)
signal upgrade_purchase_requested(offer: ShopUpgradeOfferData)

@export_category("Price Colors")

@export var affordable_price_color: Color = Color(0.0, 0.55, 0.0, 1.0)
@export var unaffordable_price_color: Color = Color(0.75, 0.0, 0.0, 1.0)

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton

var _app_offer: ShopAppOfferData
var _upgrade_offer: ShopUpgradeOfferData
var _upgrade_manager: UpgradeManager

var _is_upgrade: bool = false


func _ready() -> void:
	if not buy_button.pressed.is_connected(
		_on_buy_button_pressed
	):
		buy_button.pressed.connect(
			_on_buy_button_pressed
		)


func bind_app_offer(offer: ShopAppOfferData) -> void:
	_app_offer = offer
	_upgrade_offer = null
	_upgrade_manager = null
	_is_upgrade = false

	_refresh_app_visuals()
	refresh_affordability(GameState.crypto)


func bind_upgrade_offer(
	offer: ShopUpgradeOfferData,
	upgrade_manager: UpgradeManager
) -> void:
	_app_offer = null
	_upgrade_offer = offer
	_upgrade_manager = upgrade_manager
	_is_upgrade = true

	_refresh_upgrade_visuals()
	refresh_affordability(GameState.crypto)


func refresh_affordability(
	_current_crypto: int
) -> void:
	if _is_upgrade:
		_refresh_upgrade_affordability()
		return

	_refresh_app_affordability()


func _refresh_app_visuals() -> void:
	if _app_offer == null:
		_set_empty_state()
		return

	icon_texture.texture = _app_offer.get_icon()
	name_label.text = _app_offer.get_display_name()
	price_label.text = "$%d" % _app_offer.price
	buy_button.text = "BUY"


func _refresh_upgrade_visuals() -> void:
	if _upgrade_offer == null:
		_set_empty_state()
		return

	icon_texture.texture = _upgrade_offer.icon
	buy_button.text = "BUY"

	if _upgrade_manager == null:
		name_label.text = _upgrade_offer.display_name
		price_label.text = "$?"
		return

	name_label.text = _upgrade_manager.get_display_name(
		_upgrade_offer
	)

	price_label.text = _upgrade_manager.get_price_text(
		_upgrade_offer
	)


func _refresh_app_affordability() -> void:
	if _app_offer == null:
		_apply_affordability(false)
		return

	var can_afford: bool = (
		GameState.crypto >= maxi(0, _app_offer.price)
	)

	_apply_affordability(can_afford)


func _refresh_upgrade_affordability() -> void:
	if _upgrade_offer == null:
		_apply_affordability(false)
		return

	if _upgrade_manager == null:
		_apply_affordability(false)
		return

	_refresh_upgrade_visuals()

	var can_afford: bool = (
		_upgrade_manager.can_purchase_upgrade(
			_upgrade_offer
		)
	)

	_apply_affordability(can_afford)


func _apply_affordability(can_afford: bool) -> void:
	buy_button.disabled = not can_afford

	if can_afford:
		price_label.add_theme_color_override(
			"font_color",
			affordable_price_color
		)
	else:
		price_label.add_theme_color_override(
			"font_color",
			unaffordable_price_color
		)


func _set_empty_state() -> void:
	icon_texture.texture = null
	name_label.text = "UNKNOWN"
	price_label.text = "$?"
	buy_button.text = "BUY"

	_apply_affordability(false)


func _on_buy_button_pressed() -> void:
	if _is_upgrade:
		if _upgrade_offer == null:
			return

		upgrade_purchase_requested.emit(
			_upgrade_offer
		)

		return

	if _app_offer == null:
		return

	app_purchase_requested.emit(
		_app_offer
	)
