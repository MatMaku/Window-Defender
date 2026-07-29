extends RefCounted
class_name ProfileStore

const PROFILE_SCHEMA_VERSION: int = 1
const SAVE_SCHEMA_VERSION: int = 1

const PROFILE_FILE_NAME: String = "profile.json"
const SAVE_FILE_NAME: String = "savegame.json"

var _profiles_root: String
var _maximum_display_name_length: int


func _init(
	profiles_root: String = "user://profiles",
	maximum_display_name_length: int = 32
) -> void:
	_profiles_root = profiles_root.trim_suffix("/")
	_maximum_display_name_length = maxi(
		1,
		maximum_display_name_length
	)


func get_profiles() -> PersistenceResult:
	var directory_result: PersistenceResult = (
		_ensure_profiles_directory()
	)
	if not directory_result.success:
		return directory_result

	var directory: DirAccess = DirAccess.open(_profiles_root)
	if directory == null:
		return PersistenceResult.failure(
			&"profile_directory_unavailable",
			"Could not open the profiles directory."
		)

	var profiles: Array[Dictionary] = []
	directory.list_dir_begin()

	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if directory.current_is_dir() and _is_valid_profile_id(
			entry_name
		):
			var profile_result: PersistenceResult = load_profile(
				entry_name
			)
			if not profile_result.success:
				directory.list_dir_end()
				return profile_result

			var profile: Dictionary = (
				profile_result.get_data_copy() as Dictionary
			)
			profile["has_save"] = FileAccess.file_exists(
				_get_save_path(entry_name)
			)
			profiles.append(profile)

		entry_name = directory.get_next()

	directory.list_dir_end()
	profiles.sort_custom(_sort_profiles)

	return PersistenceResult.ok(profiles)


func validate_new_profile_name(
	display_name: String
) -> PersistenceResult:
	var trimmed_name: String = display_name.strip_edges()

	if trimmed_name.is_empty():
		return PersistenceResult.failure(
			&"empty_profile_name",
			"Profile name cannot be empty."
		)

	if trimmed_name.length() > _maximum_display_name_length:
		return PersistenceResult.failure(
			&"profile_name_too_long",
			"Profile name cannot exceed %d characters."
				% _maximum_display_name_length
		)

	for index: int in range(trimmed_name.length()):
		var codepoint: int = trimmed_name.unicode_at(index)
		if codepoint < 32 or (
			codepoint >= 127
			and codepoint <= 159
		):
			return PersistenceResult.failure(
				&"profile_name_has_control_characters",
				"Profile name contains control characters."
			)

	var profiles_result: PersistenceResult = get_profiles()
	if not profiles_result.success:
		return profiles_result

	var comparison_name: String = trimmed_name.to_lower()
	var profiles: Array = profiles_result.get_data_copy() as Array
	for profile_variant: Variant in profiles:
		if not profile_variant is Dictionary:
			continue

		var profile: Dictionary = profile_variant as Dictionary
		var existing_name: String = str(
			profile.get("display_name", "")
		)
		if existing_name.to_lower() == comparison_name:
			return PersistenceResult.failure(
				&"duplicate_profile_name",
				"Ya existe un usuario con ese nombre."
			)

	return PersistenceResult.ok(trimmed_name)


func create_profile(display_name: String) -> PersistenceResult:
	var validation_result: PersistenceResult = (
		validate_new_profile_name(display_name)
	)
	if not validation_result.success:
		return validation_result

	var safe_name: String = str(
		validation_result.get_data_copy()
	)
	var profile_id: String = _create_profile_id()
	if profile_id.is_empty():
		return PersistenceResult.failure(
			&"profile_id_generation_failed",
			"Could not generate a unique profile ID."
		)

	var created_at: String = _get_current_timestamp()

	var profile: Dictionary = {
		"schema_version": PROFILE_SCHEMA_VERSION,
		"profile_id": profile_id,
		"display_name": safe_name,
		"created_at": created_at,
		"last_activity": created_at,
		"has_save": false
	}

	var directory_result: PersistenceResult = (
		_ensure_profile_directory(profile_id)
	)
	if not directory_result.success:
		return directory_result

	var write_result: PersistenceResult = _write_json_atomic(
		_get_profile_path(profile_id),
		profile
	)
	if not write_result.success:
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				_get_profile_directory(profile_id)
			)
		)
		return write_result

	return PersistenceResult.ok(profile)


func delete_profile(profile_id: String) -> PersistenceResult:
	var paths_result: PersistenceResult = (
		_get_validated_deletion_paths(profile_id)
	)
	if not paths_result.success:
		return paths_result

	var paths: Dictionary = (
		paths_result.get_data_copy() as Dictionary
	)
	var profile_directory: String = str(
		paths.get("profile_directory", "")
	)
	var deletion_directory: String = str(
		paths.get("deletion_directory", "")
	)
	if not DirAccess.dir_exists_absolute(profile_directory):
		return PersistenceResult.failure(
			&"profile_not_found",
			"The selected profile no longer exists."
		)

	var profiles_directory: DirAccess = DirAccess.open(
		profile_directory.get_base_dir()
	)
	if profiles_directory == null:
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"Could not open the profiles directory."
		)

	if profiles_directory.is_link(profile_id):
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"Refused to delete a linked profile directory."
		)

	if DirAccess.dir_exists_absolute(deletion_directory):
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"A previous deletion of this profile is incomplete."
		)

	var rename_error: Error = DirAccess.rename_absolute(
		profile_directory,
		deletion_directory
	)
	if rename_error != OK:
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"Could not prepare the profile for deletion."
		)

	var deletion_result: PersistenceResult = (
		_delete_directory_contents(
			deletion_directory,
			deletion_directory
		)
	)
	if deletion_result.success:
		var remove_error: Error = DirAccess.remove_absolute(
			deletion_directory
		)
		if remove_error == OK:
			return PersistenceResult.ok_with_code(
				&"profile_deleted",
				{"profile_id": profile_id},
				"Profile deleted."
			)

		deletion_result = PersistenceResult.failure(
			&"profile_delete_failed",
			"Could not remove the empty profile directory."
		)

	var rollback_error: Error = DirAccess.rename_absolute(
		deletion_directory,
		profile_directory
	)
	if rollback_error != OK:
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"Profile deletion failed and its directory could not be restored.",
			{"profile_id": profile_id, "rollback_failed": true}
		)

	return deletion_result


func load_profile(profile_id: String) -> PersistenceResult:
	if not _is_valid_profile_id(profile_id):
		return PersistenceResult.failure(
			&"invalid_profile_id",
			"Profile ID is invalid."
		)

	var profile_result: PersistenceResult = _read_json(
		_get_profile_path(profile_id)
	)
	if not profile_result.success:
		return profile_result

	var value: Variant = profile_result.get_data_copy()
	if not value is Dictionary:
		return PersistenceResult.failure(
			&"corrupt_profile",
			"Profile metadata is not an object."
		)

	var profile: Dictionary = value as Dictionary
	if profile.get("schema_version", -1) != PROFILE_SCHEMA_VERSION:
		return PersistenceResult.failure(
			&"incompatible_profile_schema",
			"Unsupported profile schema version."
		)

	if str(profile.get("profile_id", "")) != profile_id:
		return PersistenceResult.failure(
			&"profile_id_mismatch",
			"Profile metadata does not match its directory."
		)

	if str(profile.get("display_name", "")).strip_edges().is_empty():
		return PersistenceResult.failure(
			&"corrupt_profile",
			"Profile display name is missing."
		)

	if str(profile.get("created_at", "")).is_empty() or str(
		profile.get("last_activity", "")
	).is_empty():
		return PersistenceResult.failure(
			&"corrupt_profile",
			"Profile timestamps are missing."
		)

	if typeof(profile.get("has_save")) != TYPE_BOOL:
		return PersistenceResult.failure(
			&"corrupt_profile",
			"Profile save status is invalid."
		)

	profile["has_save"] = FileAccess.file_exists(
		_get_save_path(profile_id)
	)
	return PersistenceResult.ok(profile)


func profile_has_save(profile_id: String) -> PersistenceResult:
	var profile_result: PersistenceResult = load_profile(profile_id)
	if not profile_result.success:
		return profile_result

	return PersistenceResult.ok(
		FileAccess.file_exists(_get_save_path(profile_id))
	)


func save_game(
	profile_id: String,
	game_snapshot: Dictionary
) -> PersistenceResult:
	var profile_result: PersistenceResult = load_profile(profile_id)
	if not profile_result.success:
		return profile_result

	if not SaveDataCodec.is_json_safe(game_snapshot):
		return PersistenceResult.failure(
			&"non_serializable_snapshot",
			"The game snapshot contains a non-serializable value."
		)

	var saved_at: String = _get_current_timestamp()
	var save_file: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"saved_at": saved_at,
		"profile_id": profile_id,
		"game": game_snapshot.duplicate(true)
	}

	var save_result: PersistenceResult = _write_json_atomic(
		_get_save_path(profile_id),
		save_file
	)
	if not save_result.success:
		return save_result

	var profile: Dictionary = (
		profile_result.get_data_copy() as Dictionary
	)
	profile["last_activity"] = saved_at
	profile["has_save"] = true

	var metadata_result: PersistenceResult = _write_json_atomic(
		_get_profile_path(profile_id),
		profile
	)
	if not metadata_result.success:
		return PersistenceResult.failure(
			&"profile_metadata_write_failed",
			"The save was written, but profile metadata could not be updated.",
			{"save_written": true}
		)

	return PersistenceResult.ok(save_file)


func load_game(profile_id: String) -> PersistenceResult:
	var profile_result: PersistenceResult = load_profile(profile_id)
	if not profile_result.success:
		return profile_result

	var save_result: PersistenceResult = _read_json(
		_get_save_path(profile_id)
	)
	if not save_result.success:
		if save_result.code == &"file_not_found":
			return PersistenceResult.failure(
				&"save_not_found",
				"This profile does not have a saved game."
			)
		return save_result

	var value: Variant = save_result.get_data_copy()
	if not value is Dictionary:
		return PersistenceResult.failure(
			&"corrupt_save",
			"Save data is not an object."
		)

	var save_file: Dictionary = value as Dictionary
	if save_file.get("schema_version", -1) != SAVE_SCHEMA_VERSION:
		return PersistenceResult.failure(
			&"incompatible_save_schema",
			"Unsupported save schema version."
		)

	if str(save_file.get("profile_id", "")) != profile_id:
		return PersistenceResult.failure(
			&"save_profile_mismatch",
			"Save data belongs to a different profile."
		)

	if str(save_file.get("saved_at", "")).is_empty():
		return PersistenceResult.failure(
			&"corrupt_save",
			"Save timestamp is missing."
		)

	if not save_file.get("game") is Dictionary:
		return PersistenceResult.failure(
			&"corrupt_save",
			"Save data does not contain a game snapshot."
		)

	return PersistenceResult.ok(save_file)


func touch_profile(profile_id: String) -> PersistenceResult:
	var profile_result: PersistenceResult = load_profile(profile_id)
	if not profile_result.success:
		return profile_result

	var profile: Dictionary = (
		profile_result.get_data_copy() as Dictionary
	)
	profile["last_activity"] = _get_current_timestamp()
	profile["has_save"] = FileAccess.file_exists(
		_get_save_path(profile_id)
	)

	var write_result: PersistenceResult = _write_json_atomic(
		_get_profile_path(profile_id),
		profile
	)
	if not write_result.success:
		return write_result

	return PersistenceResult.ok(profile)


func _ensure_profiles_directory() -> PersistenceResult:
	var absolute_path: String = ProjectSettings.globalize_path(
		_profiles_root
	)
	var error: Error = DirAccess.make_dir_recursive_absolute(
		absolute_path
	)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return PersistenceResult.failure(
			&"profile_directory_create_failed",
			"Could not create the profiles directory."
		)

	return PersistenceResult.ok()


func _ensure_profile_directory(
	profile_id: String
) -> PersistenceResult:
	var root_result: PersistenceResult = (
		_ensure_profiles_directory()
	)
	if not root_result.success:
		return root_result

	var absolute_path: String = ProjectSettings.globalize_path(
		_get_profile_directory(profile_id)
	)
	var error: Error = DirAccess.make_dir_recursive_absolute(
		absolute_path
	)
	if error != OK and error != ERR_ALREADY_EXISTS:
		return PersistenceResult.failure(
			&"profile_directory_create_failed",
			"Could not create the profile directory."
		)

	return PersistenceResult.ok()


func _read_json(path: String) -> PersistenceResult:
	var recovery_result: PersistenceResult = (
		_recover_backup_if_needed(path)
	)
	if not recovery_result.success:
		return recovery_result

	if not FileAccess.file_exists(path):
		return PersistenceResult.failure(
			&"file_not_found",
			"Persistent file does not exist."
		)

	var file: FileAccess = FileAccess.open(
		path,
		FileAccess.READ
	)
	if file == null:
		return PersistenceResult.failure(
			&"file_read_failed",
			"Could not open persistent file for reading."
		)

	var contents: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()

	if read_error != OK:
		return PersistenceResult.failure(
			&"file_read_failed",
			"Could not read persistent file."
		)

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(contents)
	if parse_error != OK:
		return PersistenceResult.failure(
			&"invalid_json",
			"JSON is invalid at line %d: %s" % [
				json.get_error_line(),
				json.get_error_message()
			]
		)

	return PersistenceResult.ok(json.data)


func _write_json_atomic(
	target_path: String,
	data: Dictionary
) -> PersistenceResult:
	if not SaveDataCodec.is_json_safe(data):
		return PersistenceResult.failure(
			&"non_serializable_data",
			"Persistent data contains a non-serializable value."
		)

	var recovery_result: PersistenceResult = (
		_recover_backup_if_needed(target_path)
	)
	if not recovery_result.success:
		return recovery_result

	var temporary_path: String = target_path + ".tmp"
	var backup_path: String = target_path + ".bak"
	_remove_if_exists(temporary_path)

	var file: FileAccess = FileAccess.open(
		temporary_path,
		FileAccess.WRITE
	)
	if file == null:
		return PersistenceResult.failure(
			&"file_write_failed",
			"Could not open the temporary file for writing."
		)

	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()

	if write_error != OK:
		_remove_if_exists(temporary_path)
		return PersistenceResult.failure(
			&"file_write_failed",
			"Could not finish writing the temporary file."
		)

	var target_absolute: String = ProjectSettings.globalize_path(
		target_path
	)
	var temporary_absolute: String = ProjectSettings.globalize_path(
		temporary_path
	)
	var backup_absolute: String = ProjectSettings.globalize_path(
		backup_path
	)

	var had_previous_file: bool = FileAccess.file_exists(
		target_path
	)
	if had_previous_file:
		_remove_if_exists(backup_path)
		var backup_error: Error = DirAccess.rename_absolute(
			target_absolute,
			backup_absolute
		)
		if backup_error != OK:
			_remove_if_exists(temporary_path)
			return PersistenceResult.failure(
				&"file_replace_failed",
				"Could not preserve the previous persistent file."
			)

	var replace_error: Error = DirAccess.rename_absolute(
		temporary_absolute,
		target_absolute
	)
	if replace_error != OK:
		if had_previous_file:
			var rollback_error: Error = DirAccess.rename_absolute(
				backup_absolute,
				target_absolute
			)
			if rollback_error != OK:
				_remove_if_exists(temporary_path)
				return PersistenceResult.failure(
					&"file_rollback_failed",
					"Could not replace the file; the previous version remains as a backup."
				)

		_remove_if_exists(temporary_path)
		return PersistenceResult.failure(
			&"file_replace_failed",
			"Could not replace the persistent file."
		)

	if had_previous_file:
		_remove_if_exists(backup_path)

	return PersistenceResult.ok()


func _recover_backup_if_needed(
	target_path: String
) -> PersistenceResult:
	if FileAccess.file_exists(target_path):
		return PersistenceResult.ok()

	var backup_path: String = target_path + ".bak"
	if not FileAccess.file_exists(backup_path):
		return PersistenceResult.ok()

	var recovery_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(backup_path),
		ProjectSettings.globalize_path(target_path)
	)
	if recovery_error != OK:
		return PersistenceResult.failure(
			&"file_recovery_failed",
			"Could not recover the previous persistent file."
		)

	return PersistenceResult.ok()


func _remove_if_exists(path: String) -> void:
	if not FileAccess.file_exists(path):
		return

	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(path)
	)


func _get_validated_deletion_paths(
	profile_id: String
) -> PersistenceResult:
	if not _is_valid_profile_id(profile_id):
		return PersistenceResult.failure(
			&"invalid_profile_id",
			"Profile ID is invalid."
		)

	var user_directory: String = _normalize_absolute_path(
		ProjectSettings.globalize_path("user://")
	)
	var profiles_directory: String = _normalize_absolute_path(
		ProjectSettings.globalize_path(_profiles_root)
	)
	if (
		profiles_directory.to_lower()
		== user_directory.to_lower()
		or not _is_path_inside(
			profiles_directory,
			user_directory
		)
	):
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"The profiles directory is outside user data."
		)

	var profile_directory: String = _normalize_absolute_path(
		ProjectSettings.globalize_path(
			_get_profile_directory(profile_id)
		)
	)
	if (
		profile_directory.get_base_dir().to_lower()
		!= profiles_directory.to_lower()
	):
		return PersistenceResult.failure(
			&"invalid_profile_id",
			"Profile directory is invalid."
		)

	var deletion_directory: String = (
		profile_directory + ".deleting"
	)
	if (
		deletion_directory.get_base_dir().to_lower()
		!= profiles_directory.to_lower()
	):
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"Deletion directory is invalid."
		)

	return PersistenceResult.ok({
		"profile_directory": profile_directory,
		"deletion_directory": deletion_directory
	})


func _delete_directory_contents(
	directory_path: String,
	deletion_root: String
) -> PersistenceResult:
	var safe_directory_path: String = (
		_normalize_absolute_path(directory_path)
	)
	var safe_deletion_root: String = (
		_normalize_absolute_path(deletion_root)
	)
	if not _is_path_inside(
		safe_directory_path,
		safe_deletion_root
	):
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"Refused to delete a path outside the profile directory."
		)

	var directory: DirAccess = DirAccess.open(
		safe_directory_path
	)
	if directory == null:
		return PersistenceResult.failure(
			&"profile_delete_failed",
			"Could not open the profile directory for deletion."
		)

	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name == "." or entry_name == "..":
			entry_name = directory.get_next()
			continue

		var entry_path: String = _normalize_absolute_path(
			safe_directory_path.path_join(entry_name)
		)
		if not _is_path_inside(
			entry_path,
			safe_deletion_root
		):
			directory.list_dir_end()
			return PersistenceResult.failure(
				&"profile_delete_failed",
				"Refused to delete an invalid profile entry."
			)

		var is_directory: bool = directory.current_is_dir()
		var is_link: bool = directory.is_link(entry_name)
		if is_directory and not is_link:
			var child_result: PersistenceResult = (
				_delete_directory_contents(
					entry_path,
					safe_deletion_root
				)
			)
			if not child_result.success:
				directory.list_dir_end()
				return child_result

		var remove_error: Error = DirAccess.remove_absolute(
			entry_path
		)
		if remove_error != OK:
			directory.list_dir_end()
			return PersistenceResult.failure(
				&"profile_delete_failed",
				"Could not delete a profile file or directory."
			)

		entry_name = directory.get_next()

	directory.list_dir_end()
	return PersistenceResult.ok()


func _normalize_absolute_path(path: String) -> String:
	return path.replace("\\", "/").simplify_path().trim_suffix("/")


func _is_path_inside(
	candidate_path: String,
	root_path: String
) -> bool:
	var candidate: String = (
		_normalize_absolute_path(candidate_path).to_lower()
	)
	var root: String = (
		_normalize_absolute_path(root_path).to_lower()
	)
	return candidate == root or candidate.begins_with(root + "/")


func _get_profile_directory(profile_id: String) -> String:
	return "%s/%s" % [
		_profiles_root,
		profile_id
	]


func _get_profile_path(profile_id: String) -> String:
	return "%s/%s" % [
		_get_profile_directory(profile_id),
		PROFILE_FILE_NAME
	]


func _get_save_path(profile_id: String) -> String:
	return "%s/%s" % [
		_get_profile_directory(profile_id),
		SAVE_FILE_NAME
	]


func _create_profile_id() -> String:
	var crypto: Crypto = Crypto.new()
	for _attempt: int in range(16):
		var profile_id: String = (
			crypto.generate_random_bytes(16).hex_encode()
		)
		if not _is_valid_profile_id(profile_id):
			continue

		if DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(
				_get_profile_directory(profile_id)
			)
		):
			continue

		return profile_id

	return ""


func _is_valid_profile_id(profile_id: String) -> bool:
	if profile_id.length() != 32:
		return false

	for index: int in range(profile_id.length()):
		var character: String = profile_id.substr(index, 1)
		if "0123456789abcdef".find(character) < 0:
			return false

	return true


func _get_current_timestamp() -> String:
	return Time.get_datetime_string_from_system(
		true,
		true
	)


func _sort_profiles(
	first: Dictionary,
	second: Dictionary
) -> bool:
	var first_activity: String = str(
		first.get("last_activity", "")
	)
	var second_activity: String = str(
		second.get("last_activity", "")
	)

	if first_activity == second_activity:
		return str(
			first.get("display_name", "")
		).to_lower() < str(
			second.get("display_name", "")
		).to_lower()

	return first_activity > second_activity
