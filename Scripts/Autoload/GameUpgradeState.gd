extends Node
class_name GameUpgradeState

var purchased_upgrade_counts: Dictionary = {}

var auto_fire_unlocked: bool = false
var area_shot_unlocked: bool = false
var auto_reload_unlocked: bool = false

var area_shot_max_targets: int = 0


func reset() -> void:
	purchased_upgrade_counts.clear()

	auto_fire_unlocked = false
	area_shot_unlocked = false
	auto_reload_unlocked = false

	area_shot_max_targets = 0


func get_upgrade_purchase_count(upgrade_id: StringName) -> int:
	if upgrade_id == StringName():
		return 0

	var key: String = str(upgrade_id)

	if not purchased_upgrade_counts.has(key):
		return 0

	return maxi(
		0,
		int(purchased_upgrade_counts[key])
	)


func set_upgrade_purchase_count(
	upgrade_id: StringName,
	purchase_count: int
) -> void:
	if upgrade_id == StringName():
		return

	purchased_upgrade_counts[str(upgrade_id)] = maxi(
		0,
		purchase_count
	)


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
	return purchased_upgrade_counts.duplicate(true)


func set_upgrade_purchase_counts_from_snapshot(
	snapshot: Dictionary
) -> void:
	purchased_upgrade_counts = snapshot.duplicate(true)


func clear_upgrade_purchase_counts() -> void:
	purchased_upgrade_counts.clear()


func set_auto_reload_unlocked(enabled: bool) -> bool:
	if auto_reload_unlocked == enabled:
		return false

	auto_reload_unlocked = enabled
	return true


func set_auto_fire_unlocked(enabled: bool) -> bool:
	if auto_fire_unlocked == enabled:
		return false

	auto_fire_unlocked = enabled
	return true


func set_area_shot_unlocked(enabled: bool) -> bool:
	if area_shot_unlocked == enabled:
		return false

	area_shot_unlocked = enabled
	return true


func set_area_shot_max_targets(new_amount: int) -> bool:
	var safe_amount: int = maxi(
		0,
		new_amount
	)

	var changed: bool = (
		area_shot_max_targets != safe_amount
	)

	area_shot_max_targets = safe_amount

	if area_shot_max_targets > 0:
		area_shot_unlocked = true

	return changed


func add_area_shot_max_targets(amount: int) -> bool:
	if amount <= 0:
		return false

	return set_area_shot_max_targets(
		area_shot_max_targets + amount
	)
