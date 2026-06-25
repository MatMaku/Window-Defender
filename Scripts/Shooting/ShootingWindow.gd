extends AppWindow
class_name ShootingWindow

signal fire_requested(
	shooter: ShootingWindow,
	aim_global_position: Vector2
)

@export_category("Cooldown Feedback")
@export_range(0.01, 1.0, 0.01)
var feedback_expand_duration: float = 0.06

@onready var shoot_button: Button = %ShootButton
@onready var crosshair_texture: TextureRect = %CrosshairTexture
@onready var cooldown_indicator: ColorRect = %CooldownIndicator

var _cooldown_tween: Tween

@export_category("Shot Feedback")
@export_range(0.01, 1.0, 0.01)
var shake_duration: float = 0.10

@export_range(0.0, 40.0, 0.5)
var shake_distance: float = 3.0

var _shake_tween: Tween


func _ready() -> void:
	super._ready()

	shoot_button.pressed.connect(_on_shoot_button_pressed)

	cooldown_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_indicator.visible = false
	cooldown_indicator.resized.connect(_update_cooldown_pivot)

	call_deferred("_prepare_cooldown_indicator")


func get_aim_global_position() -> Vector2:
	return crosshair_texture.get_global_rect().get_center()


func play_cooldown_feedback(total_duration: float) -> void:
	if total_duration <= 0.0:
		return

	if _cooldown_tween != null and _cooldown_tween.is_running():
		_cooldown_tween.kill()

	_update_cooldown_pivot()

	var expand_duration: float = minf(
		feedback_expand_duration,
		total_duration * 0.5
	)

	var retract_duration: float = maxf(
		total_duration - expand_duration,
		0.01
	)

	cooldown_indicator.visible = true
	cooldown_indicator.scale = Vector2(0.0, 1.0)
	cooldown_indicator.modulate = Color.WHITE

	_cooldown_tween = create_tween()

	_cooldown_tween.tween_property(
		cooldown_indicator,
		"scale",
		Vector2.ONE,
		expand_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_cooldown_tween.tween_property(
		cooldown_indicator,
		"scale",
		Vector2(0.0, 1.0),
		retract_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)

	_cooldown_tween.tween_callback(_hide_cooldown_indicator)


func _on_shoot_button_pressed() -> void:
	fire_requested.emit(
		self,
		get_aim_global_position()
	)


func _prepare_cooldown_indicator() -> void:
	_update_cooldown_pivot()
	cooldown_indicator.scale = Vector2(0.0, 1.0)


func _update_cooldown_pivot() -> void:
	cooldown_indicator.pivot_offset = cooldown_indicator.size * 0.5


func _hide_cooldown_indicator() -> void:
	cooldown_indicator.visible = false

func play_shot_feedback(cooldown_duration: float) -> void:
	play_cooldown_feedback(cooldown_duration)
	_play_window_shake()


func _play_window_shake() -> void:
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()

	var rest_position: Vector2 = position
	var segment_duration: float = shake_duration / 4.0

	_shake_tween = create_tween()
	_shake_tween.set_trans(Tween.TRANS_SINE)
	_shake_tween.set_ease(Tween.EASE_IN_OUT)

	_shake_tween.tween_property(
		self,
		"position",
		rest_position + Vector2(shake_distance, 0.0),
		segment_duration
	)

	_shake_tween.tween_property(
		self,
		"position",
		rest_position + Vector2(-shake_distance, 0.0),
		segment_duration
	)

	_shake_tween.tween_property(
		self,
		"position",
		rest_position + Vector2(shake_distance * 0.45, 0.0),
		segment_duration
	)

	_shake_tween.tween_property(
		self,
		"position",
		rest_position,
		segment_duration
	)
