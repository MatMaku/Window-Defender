extends AppWindow
class_name ShootingWindow

signal fire_requested(
	shooter: ShootingWindow,
	aim_global_position: Vector2
)

@export_category("Auto Fire Layout")

@export var shrink_when_auto_fire_enabled: bool = true

@export_category("Cooldown Feedback")

@export_range(0.01, 1.0, 0.01)
var feedback_expand_duration: float = 0.06

@export_category("Shot Feedback")

@export var shake_target_path: NodePath = NodePath()

@export_range(0.01, 1.0, 0.01)
var shake_duration: float = 0.15

@export_range(0.0, 40.0, 0.5)
var shake_distance: float = 4.0

@export_range(0.0, 1.0, 0.05)
var auto_fire_shake_multiplier: float = 1.0

@export_category("Area Shot Marker")

@export_range(0.05, 2.0, 0.01)
var area_shot_marker_lifetime: float = 0.18

@export_range(0.01, 1.0, 0.01)
var area_shot_marker_fade_duration: float = 0.12

@export_range(0.05, 2.0, 0.05)
var area_shot_marker_start_scale: float = 0.25

@export_range(0.05, 2.0, 0.05)
var area_shot_marker_end_scale: float = 1.0

@export var keep_area_marker_fully_inside_window: bool = true

@onready var shoot_button: Button = %ShootButton
@onready var crosshair_texture: TextureRect = %CrosshairTexture
@onready var cooldown_indicator: ColorRect = %CooldownIndicator

@onready var aim_area: Control = (
	get_node_or_null("MainVBox/ContentRoot/ShootingVBox/AimArea")
	as Control
)

@onready var area_shot_marker_layer: Control = (
	get_node_or_null(
		"MainVBox/ContentRoot/ShootingVBox/AimArea/AreaShotMarkerLayer"
	)
	as Control
)

@onready var area_shot_marker_template: TextureRect = (
	get_node_or_null(
		"MainVBox/ContentRoot/ShootingVBox/AimArea/AreaShotMarkerLayer/AreaShotMarkerTemplate"
	)
	as TextureRect
)

var _cooldown_tween: Tween
var _shake_tween: Tween

var _shake_target: Control
var _shake_target_rest_position: Vector2 = Vector2.ZERO

var _auto_fire_enabled: bool = false
var _area_shot_enabled: bool = false

var _manual_size: Vector2 = Vector2.ZERO
var _manual_custom_minimum_size: Vector2 = Vector2.ZERO
var _manual_size_stored: bool = false

var _automatic_window_size_applied: bool = false

var _crosshair_base_modulate: Color = Color.WHITE


func _ready() -> void:
	super._ready()

	_crosshair_base_modulate = crosshair_texture.modulate

	if not shoot_button.pressed.is_connected(
		_on_shoot_button_pressed
	):
		shoot_button.pressed.connect(
			_on_shoot_button_pressed
		)

	cooldown_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_indicator.visible = false

	if not cooldown_indicator.resized.is_connected(
		_update_cooldown_pivot
	):
		cooldown_indicator.resized.connect(
			_update_cooldown_pivot
		)

	_configure_aim_area()
	_configure_area_shot_marker_layer()
	_resolve_shake_target()

	call_deferred("_prepare_cooldown_indicator")
	call_deferred("_apply_upgrade_layout")


func _exit_tree() -> void:
	_restore_shake_target_position()


func set_auto_fire_enabled(enabled: bool) -> void:
	if _auto_fire_enabled == enabled:
		return

	_auto_fire_enabled = enabled

	if not is_node_ready():
		return

	_apply_upgrade_layout()


func set_area_shot_enabled(enabled: bool) -> void:
	if _area_shot_enabled == enabled:
		return

	_area_shot_enabled = enabled

	if not is_node_ready():
		return

	_apply_upgrade_layout()


func is_auto_fire_enabled() -> bool:
	return _auto_fire_enabled


func is_area_shot_enabled() -> bool:
	return _area_shot_enabled


func get_aim_global_position() -> Vector2:
	return crosshair_texture.get_global_rect().get_center()


func get_area_shot_global_rect() -> Rect2:
	if aim_area != null:
		return aim_area.get_global_rect()

	return get_global_rect()


# ================================================================
# SETUP
# ================================================================

func _configure_aim_area() -> void:
	if aim_area == null:
		return

	aim_area.clip_contents = true
	aim_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_area_shot_marker_layer() -> void:
	if area_shot_marker_layer != null:
		area_shot_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area_shot_marker_layer.clip_contents = true
		area_shot_marker_layer.visible = false
		area_shot_marker_layer.z_index = 0
		area_shot_marker_layer.z_as_relative = true

	if area_shot_marker_template != null:
		area_shot_marker_template.visible = false
		area_shot_marker_template.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ================================================================
# AREA SHOT MARKER
# ================================================================

func present_area_shot_marker(
	target_global_position: Vector2
) -> void:
	if not _area_shot_enabled:
		return

	if area_shot_marker_layer == null:
		return

	if area_shot_marker_template == null:
		return

	if not _is_global_position_inside_aim_area(
		target_global_position
	):
		return

	var marker_size: Vector2 = _get_marker_template_size()

	if marker_size == Vector2.ZERO:
		return

	var local_center: Vector2 = (
		_global_position_to_marker_layer_local(
			target_global_position
		)
	)

	if keep_area_marker_fully_inside_window:
		local_center = _clamp_marker_center_inside_layer(
			local_center,
			marker_size,
			area_shot_marker_end_scale
		)

	var marker_root: Control = _create_area_marker_root(
		local_center
	)

	var marker_texture: TextureRect = (
		_create_area_marker_texture(marker_size)
	)

	marker_root.add_child(marker_texture)
	area_shot_marker_layer.add_child(marker_root)

	marker_root.scale = (
		Vector2.ONE
		* area_shot_marker_start_scale
	)

	_play_area_marker_animation(marker_root)


func _create_area_marker_root(
	local_center: Vector2
) -> Control:
	var marker_root: Control = Control.new()

	marker_root.name = "AreaShotMarker"
	marker_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_root.position = local_center
	marker_root.z_index = 0
	marker_root.z_as_relative = true
	marker_root.size = Vector2.ZERO
	marker_root.pivot_offset = Vector2.ZERO

	var marker_color: Color = area_shot_marker_template.modulate
	marker_color.a = 1.0
	marker_root.modulate = marker_color

	return marker_root


func _create_area_marker_texture(
	marker_size: Vector2
) -> TextureRect:
	var marker_texture: TextureRect = (
		area_shot_marker_template.duplicate()
		as TextureRect
	)

	if marker_texture == null:
		marker_texture = TextureRect.new()
		marker_texture.texture = area_shot_marker_template.texture
		marker_texture.expand_mode = (
			area_shot_marker_template.expand_mode
		)

		marker_texture.stretch_mode = (
			area_shot_marker_template.stretch_mode
		)

	marker_texture.name = "AreaShotMarkerTexture"
	marker_texture.visible = true
	marker_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE

	marker_texture.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)

	marker_texture.position = -marker_size * 0.5
	marker_texture.size = marker_size
	marker_texture.custom_minimum_size = marker_size
	marker_texture.pivot_offset = Vector2.ZERO

	var marker_color: Color = marker_texture.modulate
	marker_color.a = 1.0
	marker_texture.modulate = marker_color

	return marker_texture


func _play_area_marker_animation(marker_root: Control) -> void:
	var fade_duration: float = minf(
		area_shot_marker_fade_duration,
		area_shot_marker_lifetime
	)

	var grow_duration: float = maxf(
		0.01,
		area_shot_marker_lifetime
	)

	var hold_duration: float = maxf(
		0.0,
		area_shot_marker_lifetime - fade_duration
	)

	var start_color: Color = marker_root.modulate

	var end_color: Color = Color(
		start_color.r,
		start_color.g,
		start_color.b,
		0.0
	)

	var tween: Tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		marker_root,
		"scale",
		Vector2.ONE * area_shot_marker_end_scale,
		grow_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.set_parallel(false)

	if hold_duration > 0.0:
		tween.tween_interval(hold_duration)

	tween.tween_property(
		marker_root,
		"modulate",
		end_color,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.tween_callback(marker_root.queue_free)


func _get_marker_template_size() -> Vector2:
	var marker_size: Vector2 = area_shot_marker_template.size

	if marker_size == Vector2.ZERO:
		marker_size = area_shot_marker_template.custom_minimum_size

	if marker_size == Vector2.ZERO:
		marker_size = (
			area_shot_marker_template
			.get_combined_minimum_size()
		)

	if marker_size == Vector2.ZERO:
		if area_shot_marker_template.texture != null:
			marker_size = (
				area_shot_marker_template.texture.get_size()
			)

	return marker_size


func _global_position_to_marker_layer_local(
	target_global_position: Vector2
) -> Vector2:
	var inverse_global_transform: Transform2D = (
		area_shot_marker_layer
		.get_global_transform()
		.affine_inverse()
	)

	return inverse_global_transform * target_global_position


func _is_global_position_inside_aim_area(
	target_global_position: Vector2
) -> bool:
	if aim_area == null:
		return false

	var inverse_global_transform: Transform2D = (
		aim_area
		.get_global_transform()
		.affine_inverse()
	)

	var local_position: Vector2 = (
		inverse_global_transform * target_global_position
	)

	return Rect2(
		Vector2.ZERO,
		aim_area.size
	).has_point(local_position)


func _clamp_marker_center_inside_layer(
	local_center: Vector2,
	marker_size: Vector2,
	maximum_scale: float
) -> Vector2:
	var safe_scale: float = maxf(
		0.01,
		maximum_scale
	)

	var half_size: Vector2 = (
		marker_size
		* safe_scale
		* 0.5
	)

	var layer_size: Vector2 = area_shot_marker_layer.size

	if layer_size.x <= half_size.x * 2.0:
		local_center.x = layer_size.x * 0.5
	else:
		local_center.x = clampf(
			local_center.x,
			half_size.x,
			layer_size.x - half_size.x
		)

	if layer_size.y <= half_size.y * 2.0:
		local_center.y = layer_size.y * 0.5
	else:
		local_center.y = clampf(
			local_center.y,
			half_size.y,
			layer_size.y - half_size.y
		)

	return local_center


# ================================================================
# SHOT FEEDBACK
# ================================================================

func play_shot_feedback(cooldown_duration: float) -> void:
	play_cooldown_feedback(cooldown_duration)
	_play_visual_shake()


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

	_cooldown_tween.tween_callback(
		_hide_cooldown_indicator
	)


func _on_shoot_button_pressed() -> void:
	if _is_automatic_shooting_enabled():
		return

	fire_requested.emit(
		self,
		get_aim_global_position()
	)


# ================================================================
# UPGRADE LAYOUT
# ================================================================

func _apply_upgrade_layout() -> void:
	_apply_button_layout()
	_apply_crosshair_layout()
	_apply_area_marker_layout()


func _apply_button_layout() -> void:
	_store_manual_window_size()

	if _is_automatic_shooting_enabled():
		shoot_button.visible = false
		shoot_button.disabled = true
		shoot_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if shrink_when_auto_fire_enabled:
			call_deferred("_apply_automatic_window_size")

		return

	shoot_button.visible = true
	shoot_button.disabled = false
	shoot_button.mouse_filter = Control.MOUSE_FILTER_STOP

	if shrink_when_auto_fire_enabled:
		call_deferred("_restore_manual_window_size")


func _apply_crosshair_layout() -> void:
	crosshair_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_texture.visible = not _area_shot_enabled

	var next_modulate: Color = _crosshair_base_modulate
	next_modulate.a = _crosshair_base_modulate.a
	crosshair_texture.modulate = next_modulate


func _apply_area_marker_layout() -> void:
	if area_shot_marker_layer != null:
		area_shot_marker_layer.visible = _area_shot_enabled

	if area_shot_marker_template != null:
		area_shot_marker_template.visible = false


func _is_automatic_shooting_enabled() -> bool:
	return (
		_auto_fire_enabled
		or _area_shot_enabled
	)


func _store_manual_window_size() -> void:
	if _manual_size_stored:
		return

	_manual_size = size
	_manual_custom_minimum_size = custom_minimum_size
	_manual_size_stored = true


func _get_shoot_button_reserved_height() -> float:
	var reserved_height: float = shoot_button.size.y

	if reserved_height <= 0.0:
		reserved_height = shoot_button.get_combined_minimum_size().y

	var parent_box: BoxContainer = (
		shoot_button.get_parent() as BoxContainer
	)

	if parent_box != null:
		reserved_height += float(
			parent_box.get_theme_constant("separation")
		)

	return maxf(
		0.0,
		reserved_height
	)


func _apply_automatic_window_size() -> void:
	if _automatic_window_size_applied:
		return

	var removed_height: float = (
		_get_shoot_button_reserved_height()
	)

	if removed_height <= 0.0:
		return

	var minimum_size: Vector2 = get_combined_minimum_size()

	if custom_minimum_size != Vector2.ZERO:
		custom_minimum_size.y = maxf(
			0.0,
			custom_minimum_size.y - removed_height
		)

	size.y = maxf(
		minimum_size.y,
		_manual_size.y - removed_height
	)

	_automatic_window_size_applied = true


func _restore_manual_window_size() -> void:
	if not _manual_size_stored:
		return

	custom_minimum_size = _manual_custom_minimum_size
	size = _manual_size

	_automatic_window_size_applied = false


# ================================================================
# COOLDOWN FEEDBACK
# ================================================================

func _prepare_cooldown_indicator() -> void:
	_update_cooldown_pivot()
	cooldown_indicator.scale = Vector2(0.0, 1.0)


func _update_cooldown_pivot() -> void:
	cooldown_indicator.pivot_offset = cooldown_indicator.size * 0.5


func _hide_cooldown_indicator() -> void:
	cooldown_indicator.visible = false


# ================================================================
# VISUAL SHAKE
# ================================================================

func _resolve_shake_target() -> void:
	_shake_target = null

	if shake_target_path != NodePath():
		_shake_target = (
			get_node_or_null(shake_target_path)
			as Control
		)

	if _shake_target == null:
		_shake_target = crosshair_texture

	if _shake_target == null:
		return

	_shake_target_rest_position = _shake_target.position


func _play_visual_shake() -> void:
	if _area_shot_enabled:
		return

	if _shake_target == null:
		return

	if not is_instance_valid(_shake_target):
		return

	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
		_shake_target.position = _shake_target_rest_position
	else:
		_shake_target_rest_position = _shake_target.position

	var segment_duration: float = shake_duration / 4.0
	var effective_shake_distance: float = shake_distance

	if _is_automatic_shooting_enabled():
		effective_shake_distance *= auto_fire_shake_multiplier

	_shake_tween = create_tween()
	_shake_tween.set_trans(Tween.TRANS_SINE)
	_shake_tween.set_ease(Tween.EASE_IN_OUT)

	_shake_tween.tween_property(
		_shake_target,
		"position",
		_shake_target_rest_position + Vector2(
			effective_shake_distance,
			0.0
		),
		segment_duration
	)

	_shake_tween.tween_property(
		_shake_target,
		"position",
		_shake_target_rest_position + Vector2(
			-effective_shake_distance,
			0.0
		),
		segment_duration
	)

	_shake_tween.tween_property(
		_shake_target,
		"position",
		_shake_target_rest_position + Vector2(
			effective_shake_distance * 0.45,
			0.0
		),
		segment_duration
	)

	_shake_tween.tween_property(
		_shake_target,
		"position",
		_shake_target_rest_position,
		segment_duration
	)


func _restore_shake_target_position() -> void:
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()

	if _shake_target == null:
		return

	if not is_instance_valid(_shake_target):
		return

	_shake_target.position = _shake_target_rest_position
