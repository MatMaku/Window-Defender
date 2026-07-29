extends Node
class_name ProfileSessionService

enum SessionMode {
	NONE,
	NEW_GAME,
	LOAD_GAME
}

signal profiles_changed
signal active_profile_changed(profile_id: String)
signal session_requested(mode: SessionMode, profile_id: String)
signal session_initialization_completed(result: PersistenceResult)
signal save_completed(result: PersistenceResult)

@export var content_registry: GameContentRegistry
@export var desktop_scene: PackedScene
@export var main_menu_scene: PackedScene
@export var profiles_root: String = "user://profiles"

@export_range(1, 128, 1)
var maximum_profile_name_length: int = 32

var active_profile_id: String:
	get:
		return _active_profile_id

var active_profile: Dictionary:
	get:
		return _active_profile.duplicate(true)

var pending_session_mode: SessionMode:
	get:
		return _pending_session_mode

var _store: ProfileStore
var _active_profile_id: String = ""
var _active_profile: Dictionary = {}
var _pending_session_mode: SessionMode = SessionMode.NONE
var _pending_game_snapshot: Dictionary = {}


func _ready() -> void:
	_store = ProfileStore.new(
		profiles_root,
		maximum_profile_name_length
	)

	if content_registry == null:
		push_error(
			"ProfileService requires a GameContentRegistry."
		)
		return

	var registry_result: PersistenceResult = (
		content_registry.validate_registry()
	)
	if not registry_result.success:
		push_error(registry_result.message)


func get_profiles() -> PersistenceResult:
	return _store.get_profiles()


func validate_new_profile_name(
	display_name: String
) -> PersistenceResult:
	return _store.validate_new_profile_name(display_name)


func create_profile(display_name: String) -> PersistenceResult:
	var result: PersistenceResult = _store.create_profile(
		display_name
	)
	if result.success:
		profiles_changed.emit()

	return result


func delete_profile(profile_id: String) -> PersistenceResult:
	if profile_id == _active_profile_id:
		return PersistenceResult.failure(
			&"active_profile_cannot_be_deleted",
			"An active profile cannot be deleted."
		)

	var result: PersistenceResult = _store.delete_profile(
		profile_id
	)
	if result.success:
		profiles_changed.emit()

	return result


func get_profiles_directory_path() -> String:
	return ProjectSettings.globalize_path(profiles_root)


func select_profile(profile_id: String) -> PersistenceResult:
	var result: PersistenceResult = _store.touch_profile(
		profile_id
	)
	if not result.success:
		return result

	_active_profile_id = profile_id
	_active_profile = result.get_data_copy() as Dictionary
	active_profile_changed.emit(_active_profile_id)
	return PersistenceResult.ok(_active_profile)


func profile_has_save(profile_id: String) -> PersistenceResult:
	var existence_result: PersistenceResult = (
		_store.profile_has_save(profile_id)
	)
	if not existence_result.success:
		return existence_result

	if not bool(existence_result.get_data_copy()):
		return PersistenceResult.ok(false)

	var load_result: PersistenceResult = _store.load_game(
		profile_id
	)
	if not load_result.success:
		return load_result

	var save_file: Dictionary = (
		load_result.get_data_copy() as Dictionary
	)
	var validation_result: PersistenceResult = (
		GameSaveValidator.validate(
			save_file.get("game", {}) as Dictionary,
			content_registry
		)
	)
	if not validation_result.success:
		return validation_result

	return PersistenceResult.ok(true)


func start_new_game(profile_id: String) -> PersistenceResult:
	_clear_pending_session()

	var selection_result: PersistenceResult = select_profile(
		profile_id
	)
	if not selection_result.success:
		return selection_result

	_set_pending_session(
		SessionMode.NEW_GAME,
		{}
	)
	return _change_to_desktop()


func load_profile_game(profile_id: String) -> PersistenceResult:
	_clear_pending_session()

	var selection_result: PersistenceResult = select_profile(
		profile_id
	)
	if not selection_result.success:
		return selection_result

	var load_result: PersistenceResult = _store.load_game(
		profile_id
	)
	if not load_result.success:
		return load_result

	var save_file: Dictionary = (
		load_result.get_data_copy() as Dictionary
	)
	var game_snapshot: Dictionary = (
		save_file.get("game", {}) as Dictionary
	)
	var validation_result: PersistenceResult = (
		GameSaveValidator.validate(
			game_snapshot,
			content_registry
		)
	)
	if not validation_result.success:
		return validation_result

	_set_pending_session(
		SessionMode.LOAD_GAME,
		game_snapshot
	)
	return _change_to_desktop()


func save_active_game(
	game_snapshot: Dictionary
) -> PersistenceResult:
	if _active_profile_id.is_empty():
		var missing_profile_result: PersistenceResult = (
			PersistenceResult.failure(
				&"no_active_profile",
				"Cannot save without an active profile."
			)
		)
		save_completed.emit(missing_profile_result)
		return missing_profile_result

	var validation_result: PersistenceResult = (
		GameSaveValidator.validate(
			game_snapshot,
			content_registry
		)
	)
	if not validation_result.success:
		save_completed.emit(validation_result)
		return validation_result

	var result: PersistenceResult = _store.save_game(
		_active_profile_id,
		game_snapshot
	)
	if result.success:
		var profile_result: PersistenceResult = (
			_store.load_profile(_active_profile_id)
		)
		if profile_result.success:
			_active_profile = (
				profile_result.get_data_copy() as Dictionary
			)
		profiles_changed.emit()

	save_completed.emit(result)
	return result


func consume_pending_session() -> PersistenceResult:
	var payload: Dictionary = {
		"mode": _pending_session_mode,
		"profile_id": _active_profile_id,
		"game_snapshot": _pending_game_snapshot.duplicate(true)
	}

	_pending_session_mode = SessionMode.NONE
	_pending_game_snapshot.clear()
	return PersistenceResult.ok(payload)


func complete_session_initialization(
	result: PersistenceResult
) -> void:
	session_initialization_completed.emit(result)


func return_to_main_menu() -> PersistenceResult:
	if main_menu_scene == null:
		return PersistenceResult.failure(
			&"main_menu_not_configured",
			"The main menu scene has not been created yet."
		)

	var scene_tree: SceneTree = get_tree()
	var was_paused: bool = scene_tree.paused
	scene_tree.paused = false

	_clear_pending_session()
	var change_error: Error = get_tree().change_scene_to_packed(
		main_menu_scene
	)
	if change_error != OK:
		scene_tree.paused = was_paused
		return PersistenceResult.failure(
			&"main_menu_scene_change_failed",
			"Could not change to the main menu scene."
		)

	_active_profile_id = ""
	_active_profile.clear()
	active_profile_changed.emit(_active_profile_id)
	return PersistenceResult.ok()


func _set_pending_session(
	mode: SessionMode,
	game_snapshot: Dictionary
) -> void:
	_pending_session_mode = mode
	_pending_game_snapshot = game_snapshot.duplicate(true)
	session_requested.emit(mode, _active_profile_id)


func _change_to_desktop() -> PersistenceResult:
	if desktop_scene == null:
		_clear_pending_session()
		return PersistenceResult.failure(
			&"desktop_scene_not_configured",
			"Desktop scene is not configured."
		)

	var change_error: Error = get_tree().change_scene_to_packed(
		desktop_scene
	)
	if change_error != OK:
		_clear_pending_session()
		return PersistenceResult.failure(
			&"desktop_scene_change_failed",
			"Could not change to the Desktop scene."
		)

	return PersistenceResult.ok({
		"mode": _pending_session_mode,
		"profile_id": _active_profile_id
	})


func _clear_pending_session() -> void:
	_pending_session_mode = SessionMode.NONE
	_pending_game_snapshot.clear()
