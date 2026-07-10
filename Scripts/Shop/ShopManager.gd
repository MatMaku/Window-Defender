extends Node
class_name ShopManager

@export var desktop: Desktop
@export var window_manager: WindowManager
@export var upgrade_manager: UpgradeManager

var _active_shop_windows: Array = []


func _ready() -> void:
	_resolve_references()

	if not _validate_dependencies():
		return

	window_manager.window_opened.connect(
		_on_window_opened
	)

	window_manager.window_closed.connect(
		_on_window_closed
	)

	upgrade_manager.upgrades_changed.connect(
		_on_upgrades_changed
	)


func _resolve_references() -> void:
	if desktop == null:
		desktop = get_parent() as Desktop

	if desktop == null:
		desktop = (
			get_node_or_null("../Desktop")
			as Desktop
		)

	if window_manager == null:
		window_manager = (
			get_node_or_null("../WindowManager")
			as WindowManager
		)

	if upgrade_manager == null:
		upgrade_manager = (
			get_node_or_null("../UpgradeManager")
			as UpgradeManager
		)


func _validate_dependencies() -> bool:
	if desktop == null:
		push_error("ShopManager requires a Desktop reference.")
		return false

	if window_manager == null:
		push_error("ShopManager requires a WindowManager reference.")
		return false

	if upgrade_manager == null:
		push_error("ShopManager requires an UpgradeManager reference.")
		return false

	return true


func _on_window_opened(
	window: AppWindow,
	_program_data: ProgramData
) -> void:
	var shop_window: ShopWindow = window as ShopWindow

	if shop_window == null:
		return

	_bind_shop_window(shop_window)


func _on_window_closed(window: AppWindow) -> void:
	var shop_window: ShopWindow = window as ShopWindow

	if shop_window == null:
		return

	_active_shop_windows.erase(shop_window)


func _bind_shop_window(shop_window: ShopWindow) -> void:
	if _active_shop_windows.has(shop_window):
		return

	_active_shop_windows.append(shop_window)

	shop_window.set_upgrade_manager(upgrade_manager)

	if not shop_window.app_purchase_requested.is_connected(
		_on_app_purchase_requested
	):
		shop_window.app_purchase_requested.connect(
			_on_app_purchase_requested
		)

	if not shop_window.upgrade_purchase_requested.is_connected(
		_on_upgrade_purchase_requested
	):
		shop_window.upgrade_purchase_requested.connect(
			_on_upgrade_purchase_requested
		)

	shop_window.set_hidden_program_ids(
		desktop.get_existing_program_ids()
	)


func _on_app_purchase_requested(
	shop_window: ShopWindow,
	offer: ShopAppOfferData
) -> void:
	if offer == null:
		return

	if offer.program_data == null:
		return

	var program_id: StringName = offer.get_program_id()

	if program_id == StringName():
		return

	if desktop.has_program_shortcut(program_id):
		_hide_program_offer_in_all_shops(program_id)
		return

	var price: int = maxi(0, offer.price)

	var paid: bool = true

	if price > 0:
		paid = GameState.try_spend_crypto(price)

	if not paid:
		shop_window.rebuild_shop()
		return

	var executable: DesktopExecutable = (
		desktop.add_program_shortcut(
			offer.program_data
		)
	)

	if executable == null:
		if price > 0:
			GameState.add_crypto(price)

		shop_window.rebuild_shop()
		return

	_hide_program_offer_in_all_shops(program_id)


func _on_upgrade_purchase_requested(
	shop_window: ShopWindow,
	offer: ShopUpgradeOfferData
) -> void:
	if offer == null:
		return

	if not upgrade_manager.purchase_upgrade(offer):
		shop_window.rebuild_shop()
		return

	_refresh_all_shop_windows()


func _on_upgrades_changed() -> void:
	_refresh_all_shop_windows()


func _hide_program_offer_in_all_shops(
	program_id: StringName
) -> void:
	for shop_window_variant in _active_shop_windows:
		var shop_window: ShopWindow = (
			shop_window_variant as ShopWindow
		)

		if not is_instance_valid(shop_window):
			continue

		shop_window.hide_program_offer(program_id)


func _refresh_all_shop_windows() -> void:
	_prune_invalid_shop_windows()

	for shop_window_variant in _active_shop_windows:
		var shop_window: ShopWindow = (
			shop_window_variant as ShopWindow
		)

		if not is_instance_valid(shop_window):
			continue

		shop_window.set_upgrade_manager(upgrade_manager)

		shop_window.set_hidden_program_ids(
			desktop.get_existing_program_ids()
		)


func _prune_invalid_shop_windows() -> void:
	for index: int in range(
		_active_shop_windows.size() - 1,
		-1,
		-1
	):
		var shop_window: ShopWindow = (
			_active_shop_windows[index]
			as ShopWindow
		)

		if is_instance_valid(shop_window):
			continue

		_active_shop_windows.remove_at(index)
