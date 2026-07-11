extends Resource
class_name ShopAppOfferData

@export var offer_id: StringName
@export var program_data: ProgramData

@export_range(0, 999999, 1)
var price: int = 10

@export var display_name_override: String = ""
@export var icon_override: Texture2D


func get_display_name() -> String:
	if display_name_override != "":
		return display_name_override

	if program_data != null:
		return program_data.display_name

	return "Unknown App"


func get_icon() -> Texture2D:
	if icon_override != null:
		return icon_override

	if program_data != null:
		return program_data.icon

	return null


func get_program_id() -> StringName:
	if program_data == null:
		return StringName()

	return program_data.program_id


func get_offer_id() -> StringName:
	if offer_id != StringName():
		return offer_id

	return get_program_id()
