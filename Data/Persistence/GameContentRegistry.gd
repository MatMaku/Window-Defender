extends Resource
class_name GameContentRegistry

@export var programs: Array[ProgramData] = []
@export var enemy_archetypes: Array[EnemyArchetypeData] = []
@export var upgrades: Array[ShopUpgradeOfferData] = []


func get_program(program_id: StringName) -> ProgramData:
	if program_id == StringName():
		return null

	for program: ProgramData in programs:
		if program == null:
			continue

		if program.program_id == program_id:
			return program

	return null


func has_program(program_id: StringName) -> bool:
	return get_program(program_id) != null


func get_enemy_archetype(
	enemy_id: StringName
) -> EnemyArchetypeData:
	if enemy_id == StringName():
		return null

	for archetype: EnemyArchetypeData in enemy_archetypes:
		if archetype == null:
			continue

		if archetype.enemy_id == enemy_id:
			return archetype

	return null


func has_enemy_archetype(enemy_id: StringName) -> bool:
	return get_enemy_archetype(enemy_id) != null


func has_upgrade(upgrade_id: StringName) -> bool:
	if upgrade_id == StringName():
		return false

	for upgrade: ShopUpgradeOfferData in upgrades:
		if upgrade == null:
			continue

		if upgrade.offer_id == upgrade_id:
			return true

	return false


func validate_registry() -> PersistenceResult:
	var program_ids: Dictionary = {}

	for program: ProgramData in programs:
		if program == null:
			return PersistenceResult.failure(
				&"invalid_content_registry",
				"The content registry contains an empty program."
			)

		var program_key: String = str(program.program_id)
		if program_key.is_empty():
			return PersistenceResult.failure(
				&"invalid_content_registry",
				"A registered program has an empty ID."
			)

		if program.window_scene == null:
			return PersistenceResult.failure(
				&"invalid_content_registry",
				"Program '%s' has no window scene."
					% program_key
			)

		if program_ids.has(program_key):
			return PersistenceResult.failure(
				&"duplicate_program_id",
				"Program ID '%s' is registered more than once."
					% program_key
			)

		program_ids[program_key] = true

	var enemy_ids: Dictionary = {}

	for archetype: EnemyArchetypeData in enemy_archetypes:
		if archetype == null or not archetype.is_valid_archetype():
			return PersistenceResult.failure(
				&"invalid_content_registry",
				"The content registry contains an invalid enemy archetype."
			)

		var enemy_key: String = str(archetype.enemy_id)
		if enemy_ids.has(enemy_key):
			return PersistenceResult.failure(
				&"duplicate_enemy_id",
				"Enemy ID '%s' is registered more than once."
					% enemy_key
			)

		enemy_ids[enemy_key] = true

	var upgrade_ids: Dictionary = {}

	for upgrade: ShopUpgradeOfferData in upgrades:
		if upgrade == null:
			return PersistenceResult.failure(
				&"invalid_content_registry",
				"The content registry contains an empty upgrade."
			)

		var upgrade_key: String = str(upgrade.offer_id)
		if upgrade_key.is_empty():
			return PersistenceResult.failure(
				&"invalid_content_registry",
				"A registered upgrade has an empty ID."
			)

		if upgrade_ids.has(upgrade_key):
			return PersistenceResult.failure(
				&"duplicate_upgrade_id",
				"Upgrade ID '%s' is registered more than once."
					% upgrade_key
			)

		upgrade_ids[upgrade_key] = true

	return PersistenceResult.ok()
