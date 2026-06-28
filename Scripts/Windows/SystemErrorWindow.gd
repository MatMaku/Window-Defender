extends AppWindow
class_name SystemErrorWindow

@onready var error_message_label: Label = %ErrorMessageLabel
@onready var ok_button: Button = %OkButton


func _ready() -> void:
	super._ready()

	ok_button.pressed.connect(_on_ok_button_pressed)


func present_error(
	error_title: String,
	error_message: String
) -> void:
	title_label.text = error_title
	error_message_label.text = error_message


func _on_ok_button_pressed() -> void:
	close_requested.emit(self)
