extends LineEdit
class_name OverclockCommandInput

signal command_submitted(command: String)


func _gui_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return

	if not key_event.pressed or key_event.echo:
		return

	if (
		key_event.keycode != KEY_ENTER
		and key_event.keycode != KEY_KP_ENTER
	):
		return

	accept_event()
	if key_event.shift_pressed:
		return

	command_submitted.emit(text)
