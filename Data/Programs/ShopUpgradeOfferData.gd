extends Resource
class_name ShopUpgradeOfferData

@export var offer_id: StringName
@export var display_name: String = "Upgrade"
@export var icon: Texture2D

@export_range(0, 999999, 1)
var price: int = 10

@export_multiline var description: String = ""
