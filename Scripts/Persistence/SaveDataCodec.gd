extends RefCounted
class_name SaveDataCodec


static func vector2_to_data(value: Vector2) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}


static func vector2i_to_data(value: Vector2i) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y
	}


static func data_to_vector2(
	value: Variant,
	fallback: Vector2 = Vector2.ZERO
) -> Vector2:
	if not value is Dictionary:
		return fallback

	var data: Dictionary = value as Dictionary
	if not data.has("x") or not data.has("y"):
		return fallback

	if not _is_number(data["x"]) or not _is_number(data["y"]):
		return fallback

	return Vector2(
		float(data["x"]),
		float(data["y"])
	)


static func data_to_vector2i(
	value: Variant,
	fallback: Vector2i = Vector2i.ZERO
) -> Vector2i:
	if not value is Dictionary:
		return fallback

	var data: Dictionary = value as Dictionary
	if not data.has("x") or not data.has("y"):
		return fallback

	if not _is_number(data["x"]) or not _is_number(data["y"]):
		return fallback

	return Vector2i(
		int(data["x"]),
		int(data["y"])
	)


static func is_json_safe(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true

		TYPE_ARRAY:
			for item: Variant in value as Array:
				if not is_json_safe(item):
					return false
			return true

		TYPE_DICTIONARY:
			var dictionary: Dictionary = value as Dictionary
			for key: Variant in dictionary.keys():
				if not key is String:
					return false

				if not is_json_safe(dictionary[key]):
					return false
			return true

		_:
			return false


static func is_number(value: Variant) -> bool:
	return _is_number(value)


static func _is_number(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_INT
		or typeof(value) == TYPE_FLOAT
	)
