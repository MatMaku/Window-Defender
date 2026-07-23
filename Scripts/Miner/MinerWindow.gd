extends AppWindow
class_name MinerWindow

@export_category("Mining")

@export_range(1, 999, 1)
var crypto_per_tick: int = 1

@export_range(0.05, 60.0, 0.05)
var mining_interval_seconds: float = 1.0

@export var start_after_open_animation: bool = true

@export_category("Mining Animation")

@export var mining_frames: Array[Texture2D] = []

@export_range(0.1, 60.0, 0.1)
var mining_animation_frames_per_second: float = 8.0

@export var animate_only_while_mining: bool = true

@onready var status_label: Label = %StatusLabel
@onready var mining_animation_texture: TextureRect = (
	%MiningAnimationTexture
)

@onready var rate_label: Label = %RateLabel
@onready var mining_progress_bar: ProgressBar = (
	%MiningProgressBar
)

var _is_mining: bool = false
var _elapsed_since_tick: float = 0.0

var _current_frame_index: int = 0
var _animation_elapsed: float = 0.0
var _miner_state: GameMinerState
var _economy_state: GameEconomyState


func _ready() -> void:
	super._ready()
	_miner_state = GameState.miner_state
	_economy_state = GameState.economy_state

	if _miner_state == null or _economy_state == null:
		push_error("MinerWindow requires miner and economy states.")
		return

	_connect_state_signals()
	_apply_miner_stats_from_state()

	opening_finished.connect(
		_on_opening_finished
	)

	_refresh_static_labels()
	_refresh_progress()
	_present_idle_state()
	_apply_current_animation_frame()

	if not start_after_open_animation:
		start_mining()


func _process(delta: float) -> void:
	_update_mining(delta)
	_update_mining_animation(delta)


func start_mining() -> void:
	if _is_mining:
		return

	_is_mining = true
	_elapsed_since_tick = 0.0

	status_label.text = "MINING ACTIVE"

	_refresh_progress()


func stop_mining() -> void:
	if not _is_mining:
		return

	_is_mining = false
	_elapsed_since_tick = 0.0

	_present_idle_state()
	_refresh_progress()
	_apply_current_animation_frame()


func is_mining() -> bool:
	return _is_mining


func _connect_state_signals() -> void:
	if not _miner_state.miner_stats_changed.is_connected(
		_on_miner_stats_changed
	):
		_miner_state.miner_stats_changed.connect(
			_on_miner_stats_changed
		)


func _apply_miner_stats_from_state() -> void:
	crypto_per_tick = maxi(
		0,
		_miner_state.miner_crypto_per_tick
	)

	mining_interval_seconds = maxf(
		0.05,
		_miner_state.miner_interval_seconds
	)


func _on_miner_stats_changed(
	new_crypto_per_tick: int,
	new_mining_interval_seconds: float
) -> void:
	crypto_per_tick = maxi(
		0,
		new_crypto_per_tick
	)

	mining_interval_seconds = maxf(
		0.05,
		new_mining_interval_seconds
	)

	_elapsed_since_tick = clampf(
		_elapsed_since_tick,
		0.0,
		mining_interval_seconds
	)

	_refresh_static_labels()
	_refresh_progress()


func _update_mining(delta: float) -> void:
	if not _is_mining:
		return

	if mining_interval_seconds <= 0.0:
		return

	_elapsed_since_tick += delta

	while _elapsed_since_tick >= mining_interval_seconds:
		_elapsed_since_tick -= mining_interval_seconds
		_generate_crypto_tick()

	_refresh_progress()


func _update_mining_animation(delta: float) -> void:
	if mining_frames.is_empty():
		return

	if animate_only_while_mining and not _is_mining:
		return

	var safe_frames_per_second: float = maxf(
		0.1,
		mining_animation_frames_per_second
	)

	var frame_duration: float = (
		1.0 / safe_frames_per_second
	)

	_animation_elapsed += delta

	while _animation_elapsed >= frame_duration:
		_animation_elapsed -= frame_duration
		_advance_animation_frame()


func _advance_animation_frame() -> void:
	if mining_frames.is_empty():
		return

	_current_frame_index += 1

	if _current_frame_index >= mining_frames.size():
		_current_frame_index = 0

	_apply_current_animation_frame()


func _apply_current_animation_frame() -> void:
	if mining_frames.is_empty():
		return

	var safe_index: int = clampi(
		_current_frame_index,
		0,
		mining_frames.size() - 1
	)

	mining_animation_texture.texture = mining_frames[
		safe_index
	]


func _on_opening_finished(_window: AppWindow) -> void:
	if start_after_open_animation:
		start_mining()


func _generate_crypto_tick() -> void:
	_economy_state.add_crypto(
		crypto_per_tick
	)


func _refresh_static_labels() -> void:
	rate_label.text = "RATE: $%d / %.1fs" % [
		crypto_per_tick,
		mining_interval_seconds
	]


func _refresh_progress() -> void:
	mining_progress_bar.max_value = maxf(
		0.01,
		mining_interval_seconds
	)

	mining_progress_bar.value = clampf(
		_elapsed_since_tick,
		0.0,
		mining_progress_bar.max_value
	)


func _present_idle_state() -> void:
	if is_opening():
		status_label.text = "MINER BOOTING..."
		return

	status_label.text = "MINER IDLE"
