extends RefCounted
class_name GameSaveValidator

const GAME_SCHEMA_VERSION: int = 1

const REQUIRED_STATE_KEYS: Array[String] = [
	"system",
	"weapon",
	"reload_stats",
	"miner",
	"economy",
	"ram",
	"desktop",
	"upgrades",
	"clock",
	"run"
]


static func validate(
	snapshot: Dictionary,
	content_registry: GameContentRegistry
) -> PersistenceResult:
	if snapshot.get("schema_version", -1) != GAME_SCHEMA_VERSION:
		return PersistenceResult.failure(
			&"incompatible_game_schema",
			"Unsupported game snapshot schema version."
		)

	if content_registry == null:
		return PersistenceResult.failure(
			&"missing_content_registry",
			"Game content registry is not configured."
		)

	var registry_result: PersistenceResult = (
		content_registry.validate_registry()
	)
	if not registry_result.success:
		return registry_result

	var states_variant: Variant = snapshot.get("states")
	if not states_variant is Dictionary:
		return _missing_field("states")

	var states: Dictionary = states_variant as Dictionary
	for state_key: String in REQUIRED_STATE_KEYS:
		if not states.get(state_key) is Dictionary:
			return _missing_field("states.%s" % state_key)

	var states_result: PersistenceResult = _validate_states(
		states,
		content_registry
	)
	if not states_result.success:
		return states_result

	var desktop_variant: Variant = snapshot.get("desktop")
	if not desktop_variant is Dictionary:
		return _missing_field("desktop")

	var desktop_result: PersistenceResult = _validate_desktop(
		desktop_variant as Dictionary,
		content_registry,
		int(
			(states.get("ram", {}) as Dictionary).get(
				"max_ram",
				0
			)
		)
	)
	if not desktop_result.success:
		return desktop_result

	var enemies_variant: Variant = snapshot.get("enemies")
	if not enemies_variant is Array:
		return _missing_field("enemies")

	for enemy_variant: Variant in enemies_variant as Array:
		if not enemy_variant is Dictionary:
			return PersistenceResult.failure(
				&"invalid_enemy_snapshot",
				"An enemy snapshot is not an object."
			)

		var enemy: Dictionary = enemy_variant as Dictionary
		var enemy_id: StringName = StringName(
			str(enemy.get("archetype_id", ""))
		)
		if not content_registry.has_enemy_archetype(enemy_id):
			return PersistenceResult.failure(
				&"unknown_enemy_archetype",
				"Enemy archetype '%s' is not registered."
					% str(enemy_id)
			)

		if not _is_vector_data(enemy.get("position")):
			return _invalid_field("enemies.position")

		if not SaveDataCodec.is_number(
			enemy.get("current_health")
		):
			return _invalid_field("enemies.current_health")

		var runtime_stats_variant: Variant = enemy.get(
			"runtime_stats"
		)
		if not runtime_stats_variant is Dictionary:
			return _invalid_field("enemies.runtime_stats")

		var runtime_stats: Dictionary = (
			runtime_stats_variant as Dictionary
		)
		if str(runtime_stats.get("enemy_id", "")) != str(
			enemy_id
		):
			return PersistenceResult.failure(
				&"enemy_archetype_mismatch",
				"Enemy snapshot and runtime stats use different IDs."
			)

		for stats_field: String in [
			"max_health",
			"movement_speed",
			"attack_damage",
			"attack_interval_seconds",
			"attack_arrival_distance",
			"attack_overlap_distance",
			"virus_data_reward"
		]:
			if not SaveDataCodec.is_number(
				runtime_stats.get(stats_field)
			):
				return _invalid_field(
					"enemies.runtime_stats.%s" % stats_field
				)

		var maximum_health: float = float(
			runtime_stats.get("max_health", 0.0)
		)
		var current_health: float = float(
			enemy.get("current_health", 0.0)
		)
		if maximum_health <= 0.0 or current_health <= 0.0 or (
			current_health > maximum_health
		):
			return _invalid_field("enemies.health")

		if (
			float(runtime_stats.get("movement_speed", -1.0)) < 0.0
			or float(runtime_stats.get("attack_damage", -1.0)) < 0.0
			or float(
				runtime_stats.get(
					"attack_interval_seconds",
					0.0
				)
			) <= 0.0
			or int(runtime_stats.get("virus_data_reward", -1)) < 0
		):
			return _invalid_field("enemies.runtime_stats")

		if not enemy.get("behavior_state") is Dictionary:
			return _invalid_field("enemies.behavior_state")

		var behavior_state: Dictionary = (
			enemy.get("behavior_state", {}) as Dictionary
		)
		if enemy_id == &"basic_virus" and (
			not behavior_state.has(
				"attack_cooldown_remaining"
			)
		):
			return _missing_field(
				"enemies.behavior_state.attack_cooldown_remaining"
			)

		if behavior_state.has("attack_cooldown_remaining") and (
			not SaveDataCodec.is_number(
				behavior_state["attack_cooldown_remaining"]
			)
		):
			return _invalid_field(
				"enemies.behavior_state.attack_cooldown_remaining"
			)

		if float(
			behavior_state.get(
				"attack_cooldown_remaining",
				0.0
			)
		) < 0.0:
			return _invalid_field(
				"enemies.behavior_state.attack_cooldown_remaining"
			)

	var processes_variant: Variant = snapshot.get("processes")
	if not processes_variant is Dictionary:
		return _missing_field("processes")

	var processes_result: PersistenceResult = (
		_validate_processes(processes_variant as Dictionary)
	)
	if not processes_result.success:
		return processes_result

	if not SaveDataCodec.is_json_safe(snapshot):
		return PersistenceResult.failure(
			&"non_serializable_snapshot",
			"The game snapshot contains a non-serializable value."
		)

	return PersistenceResult.ok()


static func _validate_desktop(
	desktop: Dictionary,
	content_registry: GameContentRegistry,
	maximum_ram: int
) -> PersistenceResult:
	var shortcuts_variant: Variant = desktop.get("shortcuts")
	if not shortcuts_variant is Array:
		return _missing_field("desktop.shortcuts")

	var shortcut_programs: Dictionary = {}
	for shortcut_variant: Variant in shortcuts_variant as Array:
		var shortcut_result: PersistenceResult = _validate_program_entry(
			shortcut_variant,
			content_registry,
			"shortcut"
		)
		if not shortcut_result.success:
			return shortcut_result

		var shortcut_data: Dictionary = (
			shortcut_variant as Dictionary
		)
		if not _is_vector_data(shortcut_data.get("position")):
			return _invalid_field(
				"desktop.shortcuts.position"
			)

		var shortcut_id: String = str(
			shortcut_data.get("program_id", "")
		)
		if shortcut_programs.has(shortcut_id):
			return PersistenceResult.failure(
				&"duplicate_shortcut",
				"Program '%s' has more than one shortcut."
					% shortcut_id
			)
		shortcut_programs[shortcut_id] = true

	var windows_variant: Variant = desktop.get("windows")
	if not windows_variant is Array:
		return _missing_field("desktop.windows")

	var single_instance_programs: Dictionary = {}
	var required_ram: int = 0

	for window_variant: Variant in windows_variant as Array:
		var window_result: PersistenceResult = _validate_program_entry(
			window_variant,
			content_registry,
			"window"
		)
		if not window_result.success:
			return window_result

		var window_data: Dictionary = window_variant as Dictionary
		if not _is_vector_data(window_data.get("position")):
			return _invalid_field("desktop.windows.position")

		if not SaveDataCodec.is_number(
			window_data.get("z_order")
		):
			return _invalid_field("desktop.windows.z_order")

		if not window_data.get("app_state") is Dictionary:
			return _invalid_field("desktop.windows.app_state")

		var program_id: StringName = StringName(
			str(window_data.get("program_id", ""))
		)
		if not shortcut_programs.has(str(program_id)):
			return PersistenceResult.failure(
				&"window_without_shortcut",
				"Window '%s' has no saved shortcut."
					% str(program_id)
			)

		var program: ProgramData = content_registry.get_program(
			program_id
		)
		if program == null:
			return _invalid_field(
				"desktop.windows.program_id"
			)

		var app_state: Dictionary = (
			window_data.get("app_state", {}) as Dictionary
		)
		if program_id == &"Miner":
			if typeof(app_state.get("is_mining")) != TYPE_BOOL:
				return _invalid_field(
					"desktop.windows.app_state.is_mining"
				)

			if not SaveDataCodec.is_number(
				app_state.get("elapsed_since_tick")
			):
				return _invalid_field(
					"desktop.windows.app_state.elapsed_since_tick"
				)

			if float(
				app_state.get("elapsed_since_tick", -1.0)
			) < 0.0:
				return _invalid_field(
					"desktop.windows.app_state.elapsed_since_tick"
				)

		if program_id == &"Firewall":
			if app_state.has("orientation"):
				var orientation: String = str(
					app_state.get("orientation", "")
				)
				if orientation not in [
					"horizontal",
					"vertical"
				]:
					return _invalid_field(
						"desktop.windows.app_state.orientation"
					)

			if (
				app_state.has("is_established")
				and typeof(
					app_state.get("is_established")
				) != TYPE_BOOL
			):
				return _invalid_field(
					"desktop.windows.app_state.is_established"
				)

		if program_id == &"Turret":
			if app_state.has("cooldown_remaining"):
				if not SaveDataCodec.is_number(
					app_state.get("cooldown_remaining")
				):
					return _invalid_field(
						"desktop.windows.app_state.cooldown_remaining"
					)

				if float(
					app_state.get("cooldown_remaining", -1.0)
				) < 0.0:
					return _invalid_field(
						"desktop.windows.app_state.cooldown_remaining"
					)

		required_ram += maxi(0, program.ram_cost)
		if not program.allow_multiple_instances:
			var program_key: String = str(program_id)
			if single_instance_programs.has(program_key):
				return PersistenceResult.failure(
					&"duplicate_single_instance_window",
					"Program '%s' cannot have multiple saved windows."
						% program_key
				)
			single_instance_programs[program_key] = true

	if required_ram > maximum_ram:
		return PersistenceResult.failure(
			&"saved_windows_exceed_ram",
			"Saved windows require more RAM than the saved maximum."
		)

	return PersistenceResult.ok()


static func _validate_states(
	states: Dictionary,
	content_registry: GameContentRegistry
) -> PersistenceResult:
	var numeric_fields: Dictionary = {
		"system": [
			"max_system_integrity",
			"current_system_integrity"
		],
		"weapon": [
			"shot_damage",
			"fire_cooldown_seconds",
			"max_ammo",
			"current_ammo"
		],
		"reload_stats": [
			"normal_reload_duration",
			"perfect_reload_finish_delay",
			"reload_failure_penalty_duration"
		],
		"miner": [
			"miner_crypto_per_tick",
			"miner_interval_seconds"
		],
		"economy": [
			"crypto",
			"virus_data",
			"total_enemy_kills"
		],
		"ram": ["max_ram"],
		"desktop": ["desktop_resolution_tier"],
		"upgrades": ["area_shot_max_targets"],
		"clock": [
			"total_game_minutes",
			"game_minutes_per_real_second"
		],
		"run": [
			"spawn_mode",
			"spawn_phase",
			"game_day_index",
			"spawn_budget_remaining",
			"spawn_budget_maximum",
			"last_spawn_game_minute"
		]
	}

	for state_key: Variant in numeric_fields.keys():
		var state: Dictionary = (
			states.get(str(state_key), {}) as Dictionary
		)
		var fields: Array = numeric_fields[state_key] as Array
		for field_variant: Variant in fields:
			var field: String = str(field_variant)
			if not state.has(field):
				return _missing_field(
					"states.%s.%s" % [state_key, field]
				)

			if not SaveDataCodec.is_number(state[field]):
				return _invalid_field(
					"states.%s.%s" % [state_key, field]
				)

	var desktop_state: Dictionary = (
		states.get("desktop", {}) as Dictionary
	)
	if not _is_vector_data(
		desktop_state.get("desktop_resolution")
	):
		return _invalid_field(
			"states.desktop.desktop_resolution"
		)

	var upgrades: Dictionary = (
		states.get("upgrades", {}) as Dictionary
	)
	if not upgrades.get("purchased_upgrade_counts") is Dictionary:
		return _invalid_field(
			"states.upgrades.purchased_upgrade_counts"
		)

	var purchase_counts: Dictionary = (
		upgrades.get("purchased_upgrade_counts", {})
		as Dictionary
	)
	for upgrade_key: Variant in purchase_counts.keys():
		if not upgrade_key is String:
			return _invalid_field(
				"states.upgrades.purchased_upgrade_counts"
			)

		if not SaveDataCodec.is_number(
			purchase_counts[upgrade_key]
		):
			return _invalid_field(
				"states.upgrades.purchased_upgrade_counts.%s"
					% str(upgrade_key)
			)

		if not content_registry.has_upgrade(
			StringName(str(upgrade_key))
		):
			return PersistenceResult.failure(
				&"unknown_upgrade",
				"Upgrade '%s' is not registered."
					% str(upgrade_key)
			)

		if int(purchase_counts[upgrade_key]) < 0:
			return _invalid_field(
				"states.upgrades.purchased_upgrade_counts.%s"
					% str(upgrade_key)
			)

	for boolean_field: String in [
		"auto_fire_unlocked",
		"area_shot_unlocked",
		"auto_reload_unlocked"
	]:
		if typeof(upgrades.get(boolean_field)) != TYPE_BOOL:
			return _invalid_field(
				"states.upgrades.%s" % boolean_field
			)

	var run: Dictionary = states.get("run", {}) as Dictionary
	if typeof(
		run.get("spawning_exhausted_for_period")
	) != TYPE_BOOL:
		return _invalid_field(
			"states.run.spawning_exhausted_for_period"
		)

	var system: Dictionary = states.get("system", {}) as Dictionary
	var maximum_integrity: float = float(
		system.get("max_system_integrity", 0.0)
	)
	var current_integrity: float = float(
		system.get("current_system_integrity", -1.0)
	)
	if maximum_integrity <= 0.0 or current_integrity < 0.0 or (
		current_integrity > maximum_integrity
	):
		return _invalid_field("states.system.integrity")

	var weapon: Dictionary = states.get("weapon", {}) as Dictionary
	var maximum_ammo: int = int(weapon.get("max_ammo", 0))
	var current_ammo: int = int(weapon.get("current_ammo", -1))
	if maximum_ammo <= 0 or current_ammo < 0 or (
		current_ammo > maximum_ammo
	):
		return _invalid_field("states.weapon.ammo")

	if int(
		(states.get("ram", {}) as Dictionary).get(
			"max_ram",
			0
		)
	) <= 0:
		return _invalid_field("states.ram.max_ram")

	var clock: Dictionary = states.get("clock", {}) as Dictionary
	if float(clock.get("total_game_minutes", -1.0)) < 0.0 or (
		float(
			clock.get(
				"game_minutes_per_real_second",
				-1.0
			)
		) < 0.0
	):
		return _invalid_field("states.clock")

	var budget_remaining: float = float(
		run.get("spawn_budget_remaining", -1.0)
	)
	var budget_maximum: float = float(
		run.get("spawn_budget_maximum", -1.0)
	)
	if budget_remaining < 0.0 or budget_maximum < 0.0 or (
		budget_remaining > budget_maximum
	):
		return _invalid_field("states.run.spawn_budget")

	var last_spawn_minute: float = float(
		run.get("last_spawn_game_minute", -1.0)
	)
	if last_spawn_minute < 0.0 or last_spawn_minute > float(
		clock.get("total_game_minutes", 0.0)
	):
		return _invalid_field(
			"states.run.last_spawn_game_minute"
		)

	var spawn_mode: int = int(run.get("spawn_mode", -1))
	if (
		spawn_mode != GameRunState.SpawnMode.DAILY_CYCLE
		and spawn_mode != GameRunState.SpawnMode.INFINITE
	):
		return _invalid_field("states.run.spawn_mode")

	var spawn_phase: int = int(run.get("spawn_phase", -1))
	if (
		spawn_phase < GameRunState.SpawnPhase.REST
		or spawn_phase > GameRunState.SpawnPhase.STOPPED
	):
		return _invalid_field("states.run.spawn_phase")

	var expected_game_day: int = floori(
		float(clock.get("total_game_minutes", 0.0))
		/ float(GameClockState.MINUTES_PER_DAY)
	)
	if int(run.get("game_day_index", -1)) != expected_game_day:
		return PersistenceResult.failure(
			&"inconsistent_game_day",
			"Run day does not match the fictional clock."
		)

	if states.has("overclock"):
		var overclock_result: PersistenceResult = (
			_validate_optional_overclock_state(
				states.get("overclock")
			)
		)
		if not overclock_result.success:
			return overclock_result

	return PersistenceResult.ok()


static func _validate_optional_overclock_state(
	state_variant: Variant
) -> PersistenceResult:
	if not state_variant is Dictionary:
		return _invalid_field("states.overclock")

	var overclock: Dictionary = state_variant as Dictionary
	for numeric_field: String in [
		"phase",
		"cooldown_remaining",
		"effect_remaining",
		"income_multiplier"
	]:
		if not SaveDataCodec.is_number(
			overclock.get(numeric_field)
		):
			return _invalid_field(
				"states.overclock.%s" % numeric_field
			)

	if typeof(overclock.get("current_instruction")) != TYPE_STRING:
		return _invalid_field(
			"states.overclock.current_instruction"
		)

	var phase: int = int(overclock.get("phase", -1))
	if (
		phase < GameOverclockState.Phase.COOLDOWN
		or phase > GameOverclockState.Phase.ACTIVE
	):
		return _invalid_field("states.overclock.phase")

	if (
		float(overclock.get("cooldown_remaining", -1.0)) < 0.0
		or float(overclock.get("effect_remaining", -1.0)) < 0.0
		or float(overclock.get("income_multiplier", 0.0)) < 1.0
	):
		return _invalid_field("states.overclock")

	return PersistenceResult.ok()


static func _validate_processes(
	processes: Dictionary
) -> PersistenceResult:
	for process_key: String in [
		"shooting",
		"reload",
		"repair"
	]:
		if not processes.get(process_key) is Dictionary:
			return _missing_field(
				"processes.%s" % process_key
			)

	var shooting: Dictionary = (
		processes.get("shooting", {}) as Dictionary
	)
	if not SaveDataCodec.is_number(
		shooting.get("cooldown_remaining")
	):
		return _invalid_field(
			"processes.shooting.cooldown_remaining"
		)

	if float(shooting.get("cooldown_remaining", -1.0)) < 0.0:
		return _invalid_field(
			"processes.shooting.cooldown_remaining"
		)

	var reload: Dictionary = (
		processes.get("reload", {}) as Dictionary
	)
	for field: String in [
		"state",
		"normal_elapsed",
		"penalty_remaining",
		"perfect_finish_remaining"
	]:
		if not SaveDataCodec.is_number(reload.get(field)):
			return _invalid_field(
				"processes.reload.%s" % field
			)

	var reload_state: int = int(reload.get("state", -1))
	if reload_state < 0 or reload_state > 3:
		return _invalid_field("processes.reload.state")

	if typeof(
		reload.get("perfect_check_available")
	) != TYPE_BOOL:
		return _invalid_field(
			"processes.reload.perfect_check_available"
		)

	for timer_field: String in [
		"normal_elapsed",
		"penalty_remaining",
		"perfect_finish_remaining"
	]:
		if float(reload.get(timer_field, -1.0)) < 0.0:
			return _invalid_field(
				"processes.reload.%s" % timer_field
			)

	var repair: Dictionary = (
		processes.get("repair", {}) as Dictionary
	)
	if not SaveDataCodec.is_number(
		repair.get("repair_tick_elapsed")
	):
		return _invalid_field(
			"processes.repair.repair_tick_elapsed"
		)

	if float(repair.get("repair_tick_elapsed", -1.0)) < 0.0:
		return _invalid_field(
			"processes.repair.repair_tick_elapsed"
		)

	return PersistenceResult.ok()


static func _validate_program_entry(
	value: Variant,
	content_registry: GameContentRegistry,
	entry_kind: String
) -> PersistenceResult:
	if not value is Dictionary:
		return PersistenceResult.failure(
			&"invalid_desktop_snapshot",
			"A saved %s is not an object." % entry_kind
		)

	var entry: Dictionary = value as Dictionary
	var program_id: StringName = StringName(
		str(entry.get("program_id", ""))
	)
	if not content_registry.has_program(program_id):
		return PersistenceResult.failure(
			&"unknown_program",
			"Program '%s' is not registered." % str(program_id)
		)

	return PersistenceResult.ok()


static func _missing_field(field_path: String) -> PersistenceResult:
	return PersistenceResult.failure(
		&"missing_required_field",
		"Required save field '%s' is missing or invalid."
			% field_path
	)


static func _invalid_field(field_path: String) -> PersistenceResult:
	return PersistenceResult.failure(
		&"invalid_field_type",
		"Save field '%s' has an invalid value."
			% field_path
	)


static func _is_vector_data(value: Variant) -> bool:
	if not value is Dictionary:
		return false

	var vector_data: Dictionary = value as Dictionary
	return (
		SaveDataCodec.is_number(vector_data.get("x"))
		and SaveDataCodec.is_number(vector_data.get("y"))
	)
