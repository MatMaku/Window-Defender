extends Node
class_name GameUpgradeState

signal upgrade_purchase_counts_changed(purchase_counts_snapshot: Dictionary)
signal auto_fire_changed(enabled: bool)
signal auto_reload_changed(enabled: bool)
signal area_shot_changed(
	enabled: bool,
	max_targets: int
)

var purchased_upgrade_counts: Dictionary:
	get:
		return _purchased_upgrade_counts.duplicate(true)

var auto_fire_unlocked: bool:
	get:
		return _auto_fire_unlocked

var area_shot_unlocked: bool:
	get:
		return _area_shot_unlocked

var auto_reload_unlocked: bool:
	get:
		return _auto_reload_unlocked

var area_shot_max_targets: int:
	get:
		return _area_shot_max_targets

var _purchased_upgrade_counts: Dictionary = {}
var _auto_fire_unlocked: bool = false
var _area_shot_unlocked: bool = false
var _auto_reload_unlocked: bool = false
var _area_shot_max_targets: int = 0


func reset() -> void:
	_purchased_upgrade_counts.clear()

	_auto_fire_unlocked = false
	_area_shot_unlocked = false
	_auto_reload_unlocked = false

	_area_shot_max_targets = 0

	_emit_upgrade_purchase_counts_changed()
	auto_reload_changed.emit(_auto_reload_unlocked)
	auto_fire_changed.emit(_auto_fire_unlocked)
	_emit_area_shot_changed()


func get_upgrade_purchase_count(upgrade_id: StringName) -> int:
	if upgrade_id == StringName():
		return 0

	var key: String = str(upgrade_id)

	if not _purchased_upgrade_counts.has(key):
		return 0

	return maxi(
		0,
		int(_purchased_upgrade_counts[key])
	)


func set_upgrade_purchase_count(
	upgrade_id: StringName,
	purchase_count: int
) -> void:
	if upgrade_id == StringName():
		return

	_purchased_upgrade_counts[str(upgrade_id)] = maxi(
		0,
		purchase_count
	)
	_emit_upgrade_purchase_counts_changed()


func increment_upgrade_purchase_count(
	upgrade_id: StringName,
	amount: int = 1
) -> int:
	if upgrade_id == StringName():
		return 0

	var new_count: int = (
		get_upgrade_purchase_count(upgrade_id)
		+ maxi(0, amount)
	)

	set_upgrade_purchase_count(
		upgrade_id,
		new_count
	)

	return new_count


func get_upgrade_purchase_counts_snapshot() -> Dictionary:
	return _purchased_upgrade_counts.duplicate(true)


func set_upgrade_purchase_counts_from_snapshot(
	snapshot: Dictionary
) -> void:
	_purchased_upgrade_counts = snapshot.duplicate(true)
	_emit_upgrade_purchase_counts_changed()


func clear_upgrade_purchase_counts() -> void:
	_purchased_upgrade_counts.clear()
	_emit_upgrade_purchase_counts_changed()


func set_auto_reload_unlocked(enabled: bool) -> bool:
	if _auto_reload_unlocked == enabled:
		return false

	_auto_reload_unlocked = enabled
	auto_reload_changed.emit(_auto_reload_unlocked)
	return true


func set_auto_fire_unlocked(enabled: bool) -> bool:
	if _auto_fire_unlocked == enabled:
		return false

	_auto_fire_unlocked = enabled
	auto_fire_changed.emit(_auto_fire_unlocked)
	return true


func set_area_shot_unlocked(enabled: bool) -> bool:
	if _area_shot_unlocked == enabled:
		return false

	_area_shot_unlocked = enabled
	_emit_area_shot_changed()
	return true


func set_area_shot_max_targets(new_amount: int) -> bool:
	var safe_amount: int = maxi(
		0,
		new_amount
	)

	var changed: bool = (
		_area_shot_max_targets != safe_amount
	)

	_area_shot_max_targets = safe_amount

	if _area_shot_max_targets > 0:
		_area_shot_unlocked = true

	if changed:
		_emit_area_shot_changed()

	return changed


func add_area_shot_max_targets(amount: int) -> bool:
	if amount <= 0:
		return false

	return set_area_shot_max_targets(
		_area_shot_max_targets + amount
	)


func _emit_upgrade_purchase_counts_changed() -> void:
	upgrade_purchase_counts_changed.emit(
		get_upgrade_purchase_counts_snapshot()
	)


func _emit_area_shot_changed() -> void:
	area_shot_changed.emit(
		_area_shot_unlocked,
		_area_shot_max_targets
	)
