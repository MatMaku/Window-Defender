extends AppWindow
class_name AmmoWindow

@export_category("Ammo Feedback")

@export_range(0.01, 1.0, 0.01)
var shrink_duration: float = 0.03

@export_range(0.01, 1.0, 0.01)
var rebound_duration: float = 0.10

@export_range(0.01, 1.0, 0.01)
var settle_duration: float = 0.03

@export var compressed_scale: Vector2 = Vector2(0.82, 0.82)
@export var rebound_scale: Vector2 = Vector2(1.12, 1.12)

@onready var ammo_label: Label = %AmmoLabel

var _ammo_feedback_tween: Tween
var _weapon_state: GameWeaponState

var _displayed_current_ammo: int = -1
var _displayed_max_ammo: int = -1


func _ready() -> void:
	super._ready()
	_weapon_state = GameState.weapon_state

	if _weapon_state == null:
		push_error("AmmoWindow requires GameWeaponState.")
		return

	if not ammo_label.resized.is_connected(
		_update_label_pivot
	):
		ammo_label.resized.connect(
			_update_label_pivot
		)

	set_ammo(
		_weapon_state.current_ammo,
		_weapon_state.max_ammo,
		false
	)

	call_deferred("_update_label_pivot")


func set_ammo(
	current_ammo: int,
	max_ammo: int,
	play_feedback: bool = true
) -> void:
	var safe_current_ammo: int = maxi(
		0,
		current_ammo
	)

	var safe_max_ammo: int = maxi(
		0,
		max_ammo
	)

	var has_changed: bool = (
		safe_current_ammo != _displayed_current_ammo
		or safe_max_ammo != _displayed_max_ammo
	)

	_displayed_current_ammo = safe_current_ammo
	_displayed_max_ammo = safe_max_ammo

	_refresh_ammo_label()

	if has_changed and play_feedback:
		call_deferred("_play_ammo_change_feedback")


func _refresh_ammo_label() -> void:
	var current_text: String = (
		str(_displayed_current_ammo).pad_zeros(2)
	)

	var max_text: String = (
		str(_displayed_max_ammo).pad_zeros(2)
	)

	ammo_label.text = "%s/%s" % [
		current_text,
		max_text
	]


func _play_ammo_change_feedback() -> void:
	if _ammo_feedback_tween != null and _ammo_feedback_tween.is_running():
		_ammo_feedback_tween.kill()

	_update_label_pivot()

	ammo_label.scale = Vector2.ONE

	_ammo_feedback_tween = create_tween()

	_ammo_feedback_tween.tween_property(
		ammo_label,
		"scale",
		compressed_scale,
		shrink_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_ammo_feedback_tween.tween_property(
		ammo_label,
		"scale",
		rebound_scale,
		rebound_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_ammo_feedback_tween.tween_property(
		ammo_label,
		"scale",
		Vector2.ONE,
		settle_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_label_pivot() -> void:
	ammo_label.pivot_offset = ammo_label.size * 0.5
