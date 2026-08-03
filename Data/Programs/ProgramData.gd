extends Resource
class_name ProgramData

@export_category("Program")

@export var program_id: StringName
@export var display_name: String = "program.exe"
@export var icon: Texture2D
@export var window_scene: PackedScene

@export var allow_multiple_instances: bool = false
@export var requires_desktop_shortcut: bool = true

@export_category("Window")

@export var default_window_position: Vector2 = Vector2(220, 120)
@export var default_window_size: Vector2 = Vector2(360, 240)

@export_category("RAM")

@export_range(0, 10000, 1)
var ram_cost: int = 0
