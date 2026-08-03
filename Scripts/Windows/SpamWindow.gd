extends AppWindow
class_name SpamWindow

@export var advertisement_textures: Array[Texture2D] = []

@onready var advertisement_image: TextureRect = %AdvertisementImage

var _advertisement_index: int = -1
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_random.randomize()

	if _advertisement_index < 0:
		_select_random_advertisement()
	else:
		_apply_advertisement()


func create_save_snapshot() -> Dictionary:
	return {
		"advertisement_index": _advertisement_index
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	var maximum_index: int = advertisement_textures.size() - 1
	_advertisement_index = clampi(
		int(snapshot.get("advertisement_index", -1)),
		-1,
		maximum_index
	)

	if _advertisement_index < 0 and not advertisement_textures.is_empty():
		_select_random_advertisement()
	else:
		_apply_advertisement()


func _select_random_advertisement() -> void:
	if advertisement_textures.is_empty():
		_advertisement_index = -1
		_apply_advertisement()
		return

	_advertisement_index = _random.randi_range(
		0,
		advertisement_textures.size() - 1
	)
	_apply_advertisement()


func _apply_advertisement() -> void:
	if advertisement_image == null:
		return

	if (
		_advertisement_index < 0
		or _advertisement_index >= advertisement_textures.size()
	):
		advertisement_image.texture = null
		return

	advertisement_image.texture = advertisement_textures[
		_advertisement_index
	]
