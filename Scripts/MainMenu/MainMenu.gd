extends Control
class_name MainMenu

@export var main_menu_resolution: Vector2i = Vector2i(
	2560,
	1440
)

@onready var login_window: MainMenuWindow = %LoginWindow
@onready var profile_list: ItemList = %ProfileList
@onready var profile_name_input: LineEdit = %ProfileNameInput
@onready var error_label: Label = %ErrorLabel
@onready var load_button: Button = %LoadButton
@onready var delete_profile_button: Button = %DeleteProfileButton
@onready var new_game_button: Button = %NewGameButton
@onready var exit_button: Button = %ExitButton
@onready var delete_confirmation_overlay: Control = (
	%DeleteConfirmationOverlay
)
@onready var delete_confirmation_message: Label = (
	%DeleteConfirmationMessage
)
@onready var confirm_delete_button: Button = %ConfirmDeleteButton
@onready var cancel_delete_button: Button = %CancelDeleteButton

var _selected_profile_id: String = ""
var _selected_profile_name: String = ""
var _selected_profile_has_save: bool = false
var _action_in_progress: bool = false
var _delete_confirmation_open: bool = false
var _delete_in_progress: bool = false


func _ready() -> void:
	get_tree().paused = false
	_apply_main_menu_resolution()
	_connect_signals()
	_reset_ui()
	_refresh_profiles()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return

	if not key_event.pressed or key_event.echo:
		return

	if _delete_confirmation_open:
		if key_event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode not in [KEY_ENTER, KEY_KP_ENTER]:
		return

	if profile_name_input.has_focus():
		return

	if (
		profile_name_input.text.is_empty()
		and not _selected_profile_id.is_empty()
		and not load_button.disabled
	):
		get_viewport().set_input_as_handled()
		_begin_load_selected_profile()


func _connect_signals() -> void:
	login_window.close_requested.connect(_request_exit)
	profile_list.item_selected.connect(
		_on_profile_selected
	)
	profile_list.item_activated.connect(
		_on_profile_activated
	)
	profile_name_input.text_changed.connect(
		_on_profile_name_changed
	)
	profile_name_input.text_submitted.connect(
		_on_profile_name_submitted
	)
	load_button.pressed.connect(
		_begin_load_selected_profile
	)
	delete_profile_button.pressed.connect(
		_open_delete_confirmation
	)
	new_game_button.pressed.connect(
		_begin_new_game
	)
	exit_button.pressed.connect(_request_exit)
	confirm_delete_button.pressed.connect(
		_confirm_profile_deletion
	)
	cancel_delete_button.pressed.connect(
		_cancel_profile_deletion
	)


func _apply_main_menu_resolution() -> void:
	var game_window: Window = get_window()
	if game_window == null:
		push_error(
			"MainMenu could not access the game window."
		)
		return

	var safe_resolution: Vector2i = Vector2i(
		maxi(320, main_menu_resolution.x),
		maxi(180, main_menu_resolution.y)
	)
	game_window.content_scale_mode = (
		Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	)
	game_window.content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_KEEP
	)
	game_window.content_scale_size = safe_resolution


func _reset_ui() -> void:
	_selected_profile_id = ""
	_selected_profile_name = ""
	_selected_profile_has_save = false
	profile_list.deselect_all()
	profile_name_input.clear()
	load_button.disabled = true
	delete_profile_button.disabled = true
	new_game_button.disabled = true
	exit_button.disabled = false
	delete_confirmation_overlay.visible = false
	_delete_confirmation_open = false
	_delete_in_progress = false
	_clear_error()


func _refresh_profiles() -> void:
	profile_list.clear()
	_selected_profile_id = ""
	_selected_profile_name = ""
	_selected_profile_has_save = false
	load_button.disabled = true
	delete_profile_button.disabled = true

	var result: PersistenceResult = ProfileService.get_profiles()
	if not result.success:
		_show_error(result.message)
		return

	var profiles_value: Variant = result.get_data_copy()
	if not profiles_value is Array:
		_show_error(
			"No se pudo interpretar la lista de perfiles."
		)
		return

	var profiles: Array = profiles_value as Array
	for profile_value: Variant in profiles:
		if not profile_value is Dictionary:
			continue

		var profile: Dictionary = profile_value as Dictionary
		var display_name: String = str(
			profile.get("display_name", "")
		)
		var profile_id: String = str(
			profile.get("profile_id", "")
		)

		if display_name.is_empty() or profile_id.is_empty():
			continue

		var item_index: int = profile_list.item_count
		profile_list.add_item(display_name)
		profile_list.set_item_metadata(
			item_index,
			profile_id
		)


func _on_profile_selected(item_index: int) -> void:
	if _action_in_progress:
		return

	var metadata: Variant = profile_list.get_item_metadata(
		item_index
	)
	_selected_profile_id = str(metadata)
	_selected_profile_name = profile_list.get_item_text(
		item_index
	)
	_selected_profile_has_save = false
	load_button.disabled = true
	delete_profile_button.disabled = (
		_selected_profile_id.is_empty()
	)
	_clear_error()

	if _selected_profile_id.is_empty():
		return

	var result: PersistenceResult = (
		ProfileService.profile_has_save(
			_selected_profile_id
		)
	)
	if not result.success:
		_show_error(result.message)
		return

	_selected_profile_has_save = bool(
		result.get_data_copy()
	)
	load_button.disabled = not _selected_profile_has_save


func _on_profile_activated(_item_index: int) -> void:
	if _action_in_progress:
		return

	if not profile_name_input.text.is_empty():
		return

	if load_button.disabled:
		return

	_begin_load_selected_profile()


func _on_profile_name_changed(_new_text: String) -> void:
	if _action_in_progress:
		return

	_update_new_game_availability(true)


func _update_new_game_availability(
	show_validation_error: bool
) -> void:
	new_game_button.disabled = true

	if profile_name_input.text.is_empty():
		_clear_error()
		return

	var result: PersistenceResult = (
		ProfileService.validate_new_profile_name(
			profile_name_input.text
		)
	)
	if result.success:
		new_game_button.disabled = false
		_clear_error()
		return

	if show_validation_error:
		_show_error(result.message)


func _on_profile_name_submitted(
	submitted_text: String
) -> void:
	if _action_in_progress:
		return

	if submitted_text.is_empty():
		if (
			not _selected_profile_id.is_empty()
			and not load_button.disabled
		):
			_begin_load_selected_profile()
		return

	_update_new_game_availability(true)
	if not new_game_button.disabled:
		_begin_new_game()


func _begin_load_selected_profile() -> void:
	if _action_in_progress:
		return

	if _selected_profile_id.is_empty():
		_show_error("Seleccioná un perfil para cargar.")
		return

	var has_save_result: PersistenceResult = (
		ProfileService.profile_has_save(
			_selected_profile_id
		)
	)
	if not has_save_result.success:
		_show_error(has_save_result.message)
		return

	if not bool(has_save_result.get_data_copy()):
		_selected_profile_has_save = false
		load_button.disabled = true
		_show_error(
			"El perfil seleccionado no tiene una partida guardada."
		)
		return

	_set_action_in_progress(true)
	await login_window.play_close_animation()

	var result: PersistenceResult = (
		ProfileService.load_profile_game(
			_selected_profile_id
		)
	)
	if result.success:
		return

	await _recover_from_action_failure(result)


func _begin_new_game() -> void:
	if _action_in_progress:
		return

	var validation_result: PersistenceResult = (
		ProfileService.validate_new_profile_name(
			profile_name_input.text
		)
	)
	if not validation_result.success:
		_show_error(validation_result.message)
		_update_new_game_availability(false)
		return

	_set_action_in_progress(true)
	await login_window.play_close_animation()

	var create_result: PersistenceResult = (
		ProfileService.create_profile(
			profile_name_input.text
		)
	)
	if not create_result.success:
		await _recover_from_action_failure(create_result)
		return

	var profile_data_value: Variant = (
		create_result.get_data_copy()
	)
	if not profile_data_value is Dictionary:
		await _recover_from_action_failure(
			PersistenceResult.failure(
				&"invalid_profile_result",
				"No se pudo identificar el perfil creado."
			)
		)
		return

	var profile_data: Dictionary = (
		profile_data_value as Dictionary
	)
	var profile_id: String = str(
		profile_data.get("profile_id", "")
	)
	if profile_id.is_empty():
		await _recover_from_action_failure(
			PersistenceResult.failure(
				&"missing_profile_id",
				"No se pudo identificar el perfil creado."
			)
		)
		return

	var start_result: PersistenceResult = (
		ProfileService.start_new_game(profile_id)
	)
	if start_result.success:
		return

	_refresh_profiles()
	await _recover_from_action_failure(start_result)


func _recover_from_action_failure(
	result: PersistenceResult
) -> void:
	await login_window.play_open_animation()
	_set_action_in_progress(false)
	_show_error(result.message)


func _set_action_in_progress(active: bool) -> void:
	_action_in_progress = active
	profile_list.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
		if active
		else Control.MOUSE_FILTER_STOP
	)
	profile_list.focus_mode = (
		Control.FOCUS_NONE
		if active
		else Control.FOCUS_ALL
	)
	profile_name_input.editable = not active
	load_button.disabled = (
		active
		or _selected_profile_id.is_empty()
		or not _selected_profile_has_save
	)
	delete_profile_button.disabled = (
		active
		or _selected_profile_id.is_empty()
	)
	new_game_button.disabled = active
	exit_button.disabled = active
	login_window.close_button.disabled = active

	if not active:
		_update_new_game_availability(false)


func _show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = not message.is_empty()


func _clear_error() -> void:
	error_label.text = ""
	error_label.visible = false


func _open_delete_confirmation() -> void:
	if _action_in_progress:
		return

	if _selected_profile_id.is_empty():
		_show_error("Seleccioná un perfil para borrar.")
		return

	_delete_confirmation_open = true
	_delete_in_progress = false
	delete_confirmation_message.text = (
		"¿Seguro que deseas borrar el usuario \"%s\"?\n\n"
		+ "La partida guardada de este usuario también "
		+ "será eliminada."
	) % _selected_profile_name
	_set_action_in_progress(true)
	confirm_delete_button.disabled = false
	cancel_delete_button.disabled = false
	delete_confirmation_overlay.visible = true
	cancel_delete_button.grab_focus()


func _cancel_profile_deletion() -> void:
	if not _delete_confirmation_open:
		return

	if _delete_in_progress:
		return

	_close_delete_confirmation()


func _confirm_profile_deletion() -> void:
	if not _delete_confirmation_open:
		return

	if _delete_in_progress:
		return

	_delete_in_progress = true
	confirm_delete_button.disabled = true
	cancel_delete_button.disabled = true

	var result: PersistenceResult = (
		ProfileService.delete_profile(
			_selected_profile_id
		)
	)
	if result.success:
		_close_delete_confirmation()
		_refresh_profiles()
		_update_new_game_availability(false)
		_clear_error()
		return

	_close_delete_confirmation()
	_show_error(result.message)


func _close_delete_confirmation() -> void:
	delete_confirmation_overlay.visible = false
	_delete_confirmation_open = false
	_delete_in_progress = false
	_set_action_in_progress(false)


func _request_exit() -> void:
	if _action_in_progress:
		return

	get_tree().quit()
