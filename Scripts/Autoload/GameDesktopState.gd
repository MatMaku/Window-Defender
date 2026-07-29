extends Node
class_name GameDesktopState

signal desktop_resolution_changed(
	new_resolution: Vector2i,
	resolution_tier: int
)

signal desktop_shortcuts_changed(shortcuts_snapshot: Dictionary)

var desktop_resolution_tiers: Array[Vector2i]:
	get:
		return _desktop_resolution_tiers.duplicate()

var desktop_resolution_tier: int:
	get:
		return _desktop_resolution_tier

var desktop_resolution: Vector2i:
	get:
		return _desktop_resolution

var desktop_shortcuts: Dictionary:
	get:
		return _desktop_shortcuts.duplicate(true)

var _desktop_resolution_tiers: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

var _desktop_resolution_tier: int = 0
var _desktop_resolution: Vector2i = Vector2i(1280, 720)

var _desktop_shortcuts: Dictionary = {}


func reset_resolution_from_start_data(start_data: GameStartData) -> void:
	_desktop_resolution_tiers = (
		start_data.desktop_resolution_tiers.duplicate()
	)

	if _desktop_resolution_tiers.is_empty():
		_desktop_resolution_tiers.append(
			Vector2i(1280, 720)
		)

	_desktop_resolution_tier = clampi(
		start_data.starting_desktop_resolution_tier,
		0,
		_desktop_resolution_tiers.size() - 1
	)

	_sync_desktop_resolution_from_tier()
	_emit_desktop_resolution_changed()


func set_resolution_tiers(
	new_tiers: Array[Vector2i]
) -> void:
	_desktop_resolution_tiers = new_tiers.duplicate()

	if _desktop_resolution_tiers.is_empty():
		_desktop_resolution_tiers.append(
			Vector2i(1280, 720)
		)

	_desktop_resolution_tier = clampi(
		_desktop_resolution_tier,
		0,
		_desktop_resolution_tiers.size() - 1
	)

	_sync_desktop_resolution_from_tier()
	_emit_desktop_resolution_changed()


func set_desktop_resolution_tier(new_tier: int) -> bool:
	if _desktop_resolution_tiers.is_empty():
		return false

	var safe_tier: int = clampi(
		new_tier,
		0,
		_desktop_resolution_tiers.size() - 1
	)

	if _desktop_resolution_tier == safe_tier:
		return false

	_desktop_resolution_tier = safe_tier
	_sync_desktop_resolution_from_tier()
	_emit_desktop_resolution_changed()

	return true


func set_desktop_resolution(
	new_resolution: Vector2i,
	new_tier: int = -1
) -> bool:
	var safe_resolution: Vector2i = Vector2i(
		maxi(320, new_resolution.x),
		maxi(180, new_resolution.y)
	)

	var changed: bool = false

	if new_tier >= 0 and _desktop_resolution_tier != new_tier:
		_desktop_resolution_tier = new_tier
		changed = true

	if _desktop_resolution != safe_resolution:
		_desktop_resolution = safe_resolution
		changed = true

	if changed:
		_emit_desktop_resolution_changed()

	return changed


func get_next_desktop_resolution_tier() -> int:
	if _desktop_resolution_tiers.is_empty():
		return _desktop_resolution_tier

	return mini(
		_desktop_resolution_tier + 1,
		_desktop_resolution_tiers.size() - 1
	)


func has_next_desktop_resolution_tier() -> bool:
	return (
		not _desktop_resolution_tiers.is_empty()
		and _desktop_resolution_tier
			< _desktop_resolution_tiers.size() - 1
	)


func _sync_desktop_resolution_from_tier() -> void:
	if _desktop_resolution_tiers.is_empty():
		return

	_desktop_resolution_tier = clampi(
		_desktop_resolution_tier,
		0,
		_desktop_resolution_tiers.size() - 1
	)

	_desktop_resolution = _desktop_resolution_tiers[
		_desktop_resolution_tier
	]


func register_desktop_shortcut(
	program_id: StringName,
	position: Vector2
) -> void:
	if program_id == StringName():
		return

	_desktop_shortcuts[str(program_id)] = position
	_emit_desktop_shortcuts_changed()


func unregister_desktop_shortcut(program_id: StringName) -> bool:
	if program_id == StringName():
		return false

	var key: String = str(program_id)

	if not _desktop_shortcuts.has(key):
		return false

	_desktop_shortcuts.erase(key)
	_emit_desktop_shortcuts_changed()
	return true


func update_desktop_shortcut_position(
	program_id: StringName,
	position: Vector2
) -> bool:
	if program_id == StringName():
		return false

	var key: String = str(program_id)

	if not _desktop_shortcuts.has(key):
		return false

	_desktop_shortcuts[key] = position
	_emit_desktop_shortcuts_changed()
	return true


func has_desktop_shortcut(program_id: StringName) -> bool:
	if program_id == StringName():
		return false

	return _desktop_shortcuts.has(
		str(program_id)
	)


func get_desktop_shortcut_position(
	program_id: StringName,
	fallback_position: Vector2 = Vector2.ZERO
) -> Vector2:
	if program_id == StringName():
		return fallback_position

	var key: String = str(program_id)

	if not _desktop_shortcuts.has(key):
		return fallback_position

	var stored_position: Variant = _desktop_shortcuts[key]

	if stored_position is Vector2:
		return stored_position

	return fallback_position


func get_desktop_shortcuts_snapshot() -> Dictionary:
	return _desktop_shortcuts.duplicate(true)


func set_desktop_shortcuts_from_snapshot(
	shortcuts_snapshot: Dictionary
) -> void:
	_desktop_shortcuts = shortcuts_snapshot.duplicate(true)
	_emit_desktop_shortcuts_changed()


func clear_desktop_shortcuts() -> void:
	_desktop_shortcuts.clear()
	_emit_desktop_shortcuts_changed()


func create_save_snapshot() -> Dictionary:
	return {
		"desktop_resolution_tier": _desktop_resolution_tier,
		"desktop_resolution": SaveDataCodec.vector2i_to_data(
			_desktop_resolution
		)
	}


func restore_from_save_snapshot(snapshot: Dictionary) -> void:
	var restored_tier: int = int(
		snapshot.get("desktop_resolution_tier", 0)
	)
	var restored_resolution: Vector2i = (
		SaveDataCodec.data_to_vector2i(
			snapshot.get("desktop_resolution"),
			_desktop_resolution
		)
	)

	_desktop_resolution_tier = clampi(
		restored_tier,
		0,
		maxi(0, _desktop_resolution_tiers.size() - 1)
	)
	_desktop_resolution = Vector2i(
		maxi(320, restored_resolution.x),
		maxi(180, restored_resolution.y)
	)
	_emit_desktop_resolution_changed()


func _emit_desktop_resolution_changed() -> void:
	desktop_resolution_changed.emit(
		_desktop_resolution,
		_desktop_resolution_tier
	)


func _emit_desktop_shortcuts_changed() -> void:
	desktop_shortcuts_changed.emit(
		get_desktop_shortcuts_snapshot()
	)
