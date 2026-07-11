extends Resource
class_name GameStartData

@export_category("System")

@export var max_system_integrity: float = 100.0

@export_category("Weapon")

@export var shot_damage: float = 1.0
@export var fire_cooldown_seconds: float = 1.0
@export var max_ammo: int = 6

@export_category("Reload")

@export var normal_reload_duration: float = 1.45
@export var perfect_reload_finish_delay: float = 0.35
@export var reload_failure_penalty_duration: float = 0.85

@export_category("Miner")

@export var miner_crypto_per_tick: int = 1
@export var miner_interval_seconds: float = 5.0

@export_category("Economy")

@export var starting_crypto: int = 1000
@export var starting_virus_data: int = 1000

@export_category("RAM")

@export var max_ram: int = 100

@export_category("Desktop Resolution")

@export var starting_desktop_resolution_tier: int = 0

@export var desktop_resolution_tiers: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]
