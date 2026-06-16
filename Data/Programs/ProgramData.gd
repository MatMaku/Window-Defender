extends Resource
class_name ProgramData

@export var program_id: StringName
@export var display_name: String = "program.exe"
@export var icon: Texture2D
@export var window_scene: PackedScene

@export var allow_multiple_instances: bool = false
@export var default_window_position: Vector2 = Vector2(220, 120)
@export var default_window_size: Vector2 = Vector2(360, 240)
