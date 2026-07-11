extends Node
class_name GameDesktopState

var desktop_resolution_tiers: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

var desktop_resolution_tier: int = 0
var desktop_resolution: Vector2i = Vector2i(1280, 720)

var desktop_shortcuts: Dictionary = {}


func reset_resolution_from_start_data(start_data: GameStartData) -> void:
	desktop_resolution_tiers = (
		start_data.desktop_resolution_tiers.duplicate()
	)

	if desktop_resolution_tiers.is_empty():
		desktop_resolution_tiers.append(
			Vector2i(1280, 720)
		)

	desktop_resolution_tier = clampi(
		start_data.starting_desktop_resolution_tier,
		0,
		desktop_resolution_tiers.size() - 1
	)

	_sync_desktop_resolution_from_tier()


func set_resolution_tiers(
	new_tiers: Array[Vector2i]
) -> void:
	desktop_resolution_tiers = new_tiers.duplicate()

	if desktop_resolution_tiers.is_empty():
		desktop_resolution_tiers.append(
			Vector2i(1280, 720)
		)

	desktop_resolution_tier = clampi(
		desktop_resolution_tier,
		0,
		desktop_resolution_tiers.size() - 1
	)

	_sync_desktop_resolution_from_tier()


func set_desktop_resolution_tier(new_tier: int) -> bool:
	if desktop_resolution_tiers.is_empty():
		return false

	var safe_tier: int = clampi(
		new_tier,
		0,
		desktop_resolution_tiers.size() - 1
	)

	if desktop_resolution_tier == safe_tier:
		return false

	desktop_resolution_tier = safe_tier
	_sync_desktop_resolution_from_tier()

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

	if new_tier >= 0 and desktop_resolution_tier != new_tier:
		desktop_resolution_tier = new_tier
		changed = true

	if desktop_resolution != safe_resolution:
		desktop_resolution = safe_resolution
		changed = true

	return changed


func get_next_desktop_resolution_tier() -> int:
	if desktop_resolution_tiers.is_empty():
		return desktop_resolution_tier

	return mini(
		desktop_resolution_tier + 1,
		desktop_resolution_tiers.size() - 1
	)


func has_next_desktop_resolution_tier() -> bool:
	return (
		not desktop_resolution_tiers.is_empty()
		and desktop_resolution_tier
			< desktop_resolution_tiers.size() - 1
	)


func _sync_desktop_resolution_from_tier() -> void:
	if desktop_resolution_tiers.is_empty():
		return

	desktop_resolution_tier = clampi(
		desktop_resolution_tier,
		0,
		desktop_resolution_tiers.size() - 1
	)

	desktop_resolution = desktop_resolution_tiers[
		desktop_resolution_tier
	]


func register_desktop_shortcut(
	program_id: StringName,
	position: Vector2
) -> void:
	if program_id == StringName():
		return

	desktop_shortcuts[str(program_id)] = position


func unregister_desktop_shortcut(program_id: StringName) -> bool:
	if program_id == StringName():
		return false

	var key: String = str(program_id)

	if not desktop_shortcuts.has(key):
		return false

	desktop_shortcuts.erase(key)
	return true


func update_desktop_shortcut_position(
	program_id: StringName,
	position: Vector2
) -> bool:
	if program_id == StringName():
		return false

	var key: String = str(program_id)

	if not desktop_shortcuts.has(key):
		return false

	desktop_shortcuts[key] = position
	return true


func has_desktop_shortcut(program_id: StringName) -> bool:
	if program_id == StringName():
		return false

	return desktop_shortcuts.has(
		str(program_id)
	)


func get_desktop_shortcut_position(
	program_id: StringName,
	fallback_position: Vector2 = Vector2.ZERO
) -> Vector2:
	if program_id == StringName():
		return fallback_position

	var key: String = str(program_id)

	if not desktop_shortcuts.has(key):
		return fallback_position

	var stored_position: Variant = desktop_shortcuts[key]

	if stored_position is Vector2:
		return stored_position

	return fallback_position


func get_desktop_shortcuts_snapshot() -> Dictionary:
	return desktop_shortcuts.duplicate(true)


func set_desktop_shortcuts_from_snapshot(
	shortcuts_snapshot: Dictionary
) -> void:
	desktop_shortcuts = shortcuts_snapshot.duplicate(true)


func clear_desktop_shortcuts() -> void:
	desktop_shortcuts.clear()
