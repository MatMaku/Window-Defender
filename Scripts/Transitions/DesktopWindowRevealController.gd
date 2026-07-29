extends Node
class_name DesktopWindowRevealController

@export var save_coordinator: DesktopSaveCoordinator
@export var window_manager: WindowManager

@export_range(0.1, 1.0, 0.05)
var maximum_reveal_duration: float = 0.6

var _reveal_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if save_coordinator == null:
		push_error(
			"DesktopWindowRevealController requires "
			+ "DesktopSaveCoordinator."
		)
		return

	if window_manager == null:
		push_error(
			"DesktopWindowRevealController requires "
			+ "WindowManager."
		)
		return

	if not save_coordinator.restore_finished.is_connected(
		_on_restore_finished
	):
		save_coordinator.restore_finished.connect(
			_on_restore_finished
		)


func _on_restore_finished(
	result: PersistenceResult
) -> void:
	if _reveal_started:
		return

	_reveal_started = true
	var scene_tree: SceneTree = get_tree()
	var was_paused: bool = scene_tree.paused
	var viewport: Viewport = get_viewport()
	var gui_was_disabled: bool = viewport.gui_disable_input
	scene_tree.paused = true
	viewport.gui_disable_input = true

	if result.success:
		await window_manager.reveal_restored_windows(
			maximum_reveal_duration
		)

	if is_instance_valid(viewport):
		viewport.gui_disable_input = gui_was_disabled

	if is_inside_tree():
		scene_tree.paused = was_paused
