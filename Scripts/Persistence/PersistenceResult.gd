extends RefCounted
class_name PersistenceResult

var success: bool:
	get:
		return _success

var code: StringName:
	get:
		return _code

var message: String:
	get:
		return _message

var data: Variant:
	get:
		return _duplicate_value(_data)

var _success: bool = false
var _code: StringName = &"unknown"
var _message: String = ""
var _data: Variant = null


static func ok(
	result_data: Variant = null,
	result_message: String = ""
) -> PersistenceResult:
	return _create(
		true,
		&"ok",
		result_message,
		result_data
	)


static func ok_with_code(
	result_code: StringName,
	result_data: Variant = null,
	result_message: String = ""
) -> PersistenceResult:
	return _create(
		true,
		result_code,
		result_message,
		result_data
	)


static func failure(
	error_code: StringName,
	error_message: String,
	error_data: Variant = null
) -> PersistenceResult:
	return _create(
		false,
		error_code,
		error_message,
		error_data
	)


func get_data_copy() -> Variant:
	return _duplicate_value(_data)


static func _create(
	result_success: bool,
	result_code: StringName,
	result_message: String,
	result_data: Variant
) -> PersistenceResult:
	var result: PersistenceResult = PersistenceResult.new()
	result._success = result_success
	result._code = result_code
	result._message = result_message
	result._data = _duplicate_value(result_data)
	return result


static func _duplicate_value(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)

	if value is Array:
		return (value as Array).duplicate(true)

	return value
