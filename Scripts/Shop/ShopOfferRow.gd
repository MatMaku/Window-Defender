extends PanelContainer
class_name ShopOfferRow

signal app_purchase_requested(offer: ShopAppOfferData)
signal upgrade_purchase_requested(offer: ShopUpgradeOfferData)

@export var affordable_color: Color = Color(0.25, 1.0, 0.35, 1.0)
@export var unaffordable_color: Color = Color(1.0, 0.25, 0.25, 1.0)

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton

var _app_offer: ShopAppOfferData
var _upgrade_offer: ShopUpgradeOfferData
var _price: int = 0


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_button_pressed)


func bind_app_offer(offer: ShopAppOfferData) -> void:
	_app_offer = offer
	_upgrade_offer = null

	if offer == null:
		return

	_price = maxi(0, offer.price)

	icon_texture.texture = offer.get_icon()
	name_label.text = offer.get_display_name()
	price_label.text = "$%d" % _price
	buy_button.text = "BUY"

	refresh_affordability(GameState.crypto)


func bind_upgrade_offer(offer: ShopUpgradeOfferData) -> void:
	_upgrade_offer = offer
	_app_offer = null

	if offer == null:
		return

	_price = maxi(0, offer.price)

	icon_texture.texture = offer.icon
	name_label.text = offer.display_name
	price_label.text = "$%d" % _price
	buy_button.text = "BUY"

	refresh_affordability(GameState.crypto)


func refresh_affordability(current_crypto: int) -> void:
	var can_afford: bool = current_crypto >= _price

	if can_afford:
		price_label.modulate = affordable_color
	else:
		price_label.modulate = unaffordable_color

	buy_button.disabled = not can_afford


func get_app_offer() -> ShopAppOfferData:
	return _app_offer


func get_upgrade_offer() -> ShopUpgradeOfferData:
	return _upgrade_offer


func _on_buy_button_pressed() -> void:
	if _app_offer != null:
		app_purchase_requested.emit(_app_offer)
		return

	if _upgrade_offer != null:
		upgrade_purchase_requested.emit(_upgrade_offer)
