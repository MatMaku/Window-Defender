extends AppWindow
class_name ShopWindow

signal app_purchase_requested(
	shop_window: ShopWindow,
	offer: ShopAppOfferData
)

signal upgrade_purchase_requested(
	shop_window: ShopWindow,
	offer: ShopUpgradeOfferData
)

enum ShopTab {
	APPS,
	UPGRADES
}

@export var app_offers: Array[ShopAppOfferData] = []
@export var upgrade_offers: Array[ShopUpgradeOfferData] = []

@export var offer_row_scene: PackedScene
@export var upgrade_manager: UpgradeManager

@export_category("Scrollbars")

@export var hide_scrollbars: bool = true

@onready var apps_button: Button = %AppsButton
@onready var upgrades_button: Button = %UpgradesButton

@onready var apps_panel: Control = %AppsPanel
@onready var upgrades_panel: Control = %UpgradesPanel

@onready var apps_scroll: ScrollContainer = %AppsScroll
@onready var upgrades_scroll: ScrollContainer = %UpgradesScroll

@onready var apps_list: VBoxContainer = %AppsList
@onready var upgrades_list: VBoxContainer = %UpgradesList

var _current_tab: int = ShopTab.APPS

var _hidden_program_ids: Dictionary = {}
var _app_rows_by_offer_id: Dictionary = {}
var _upgrade_rows: Array = []


func _ready() -> void:
	super._ready()

	if offer_row_scene == null:
		push_error("ShopWindow requires an offer row scene.")
		return

	_resolve_upgrade_manager()
	_connect_buttons()
	_connect_game_state_signals()

	_configure_scroll_containers()
	rebuild_shop()
	_show_tab(ShopTab.APPS)


func set_upgrade_manager(
	new_upgrade_manager: UpgradeManager
) -> void:
	if upgrade_manager == new_upgrade_manager:
		return

	if upgrade_manager != null:
		if upgrade_manager.upgrades_changed.is_connected(
			_on_upgrades_changed
		):
			upgrade_manager.upgrades_changed.disconnect(
				_on_upgrades_changed
			)

	upgrade_manager = new_upgrade_manager

	if upgrade_manager != null:
		if not upgrade_manager.upgrades_changed.is_connected(
			_on_upgrades_changed
		):
			upgrade_manager.upgrades_changed.connect(
				_on_upgrades_changed
			)

	if is_node_ready():
		rebuild_shop()


func set_hidden_program_ids(program_ids: Array) -> void:
	_hidden_program_ids.clear()

	for id_variant in program_ids:
		if id_variant == null:
			continue

		var program_id: StringName = StringName(
			str(id_variant)
		)

		if program_id == StringName():
			continue

		_hidden_program_ids[program_id] = true

	rebuild_shop()


func hide_program_offer(program_id: StringName) -> void:
	if program_id == StringName():
		return

	_hidden_program_ids[program_id] = true
	rebuild_shop()


func rebuild_shop() -> void:
	if apps_list == null or upgrades_list == null:
		return

	_clear_container(apps_list)
	_clear_container(upgrades_list)

	_app_rows_by_offer_id.clear()
	_upgrade_rows.clear()

	_build_app_rows()
	_build_upgrade_rows()

	_refresh_all_rows_affordability()


func _resolve_upgrade_manager() -> void:
	if upgrade_manager != null:
		set_upgrade_manager(upgrade_manager)
		return

	var resolved_upgrade_manager: UpgradeManager = (
		get_node_or_null("../../UpgradeManager")
		as UpgradeManager
	)

	if resolved_upgrade_manager == null:
		resolved_upgrade_manager = (
			get_node_or_null("../UpgradeManager")
			as UpgradeManager
		)

	if resolved_upgrade_manager != null:
		set_upgrade_manager(resolved_upgrade_manager)


func _connect_buttons() -> void:
	if not apps_button.pressed.is_connected(
		_on_apps_button_pressed
	):
		apps_button.pressed.connect(
			_on_apps_button_pressed
		)

	if not upgrades_button.pressed.is_connected(
		_on_upgrades_button_pressed
	):
		upgrades_button.pressed.connect(
			_on_upgrades_button_pressed
		)


func _connect_game_state_signals() -> void:
	if not GameState.crypto_changed.is_connected(
		_on_crypto_changed
	):
		GameState.crypto_changed.connect(
			_on_crypto_changed
		)

	if not GameState.virus_data_changed.is_connected(
		_on_virus_data_changed
	):
		GameState.virus_data_changed.connect(
			_on_virus_data_changed
		)

	if not GameState.upgrade_purchase_counts_changed.is_connected(
		_on_upgrade_purchase_counts_changed
	):
		GameState.upgrade_purchase_counts_changed.connect(
			_on_upgrade_purchase_counts_changed
		)


func _build_app_rows() -> void:
	var sorted_offers: Array[ShopAppOfferData] = []

	for offer: ShopAppOfferData in app_offers:
		if offer == null:
			continue

		sorted_offers.append(offer)

	sorted_offers.sort_custom(_sort_app_offers_by_price)

	var visible_count: int = 0

	for offer: ShopAppOfferData in sorted_offers:
		var program_id: StringName = offer.get_program_id()

		if program_id == StringName():
			continue

		if _hidden_program_ids.has(program_id):
			continue

		var row: ShopOfferRow = _create_offer_row()

		if row == null:
			continue

		apps_list.add_child(row)

		row.bind_app_offer(offer)

		row.app_purchase_requested.connect(
			_on_app_row_purchase_requested
		)

		_app_rows_by_offer_id[
			offer.get_offer_id()
		] = row

		visible_count += 1


func _build_upgrade_rows() -> void:
	var sorted_offers: Array[ShopUpgradeOfferData] = []

	for offer: ShopUpgradeOfferData in upgrade_offers:
		if offer == null:
			continue

		sorted_offers.append(offer)

	sorted_offers.sort_custom(_sort_upgrade_offers_by_price)

	var visible_count: int = 0

	for offer: ShopUpgradeOfferData in sorted_offers:
		if upgrade_manager != null:
			if not upgrade_manager.can_show_upgrade(offer):
				continue

		var row: ShopOfferRow = _create_offer_row()

		if row == null:
			continue

		upgrades_list.add_child(row)

		row.bind_upgrade_offer(
			offer,
			upgrade_manager
		)

		row.upgrade_purchase_requested.connect(
			_on_upgrade_row_purchase_requested
		)

		_upgrade_rows.append(row)

		visible_count += 1


func _create_offer_row() -> ShopOfferRow:
	var row: ShopOfferRow = (
		offer_row_scene.instantiate()
		as ShopOfferRow
	)

	if row == null:
		push_error(
			"Offer row scene must inherit from ShopOfferRow."
		)
		return null

	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return row


func _on_app_row_purchase_requested(
	offer: ShopAppOfferData
) -> void:
	app_purchase_requested.emit(
		self,
		offer
	)


func _on_upgrade_row_purchase_requested(
	offer: ShopUpgradeOfferData
) -> void:
	upgrade_purchase_requested.emit(
		self,
		offer
	)


func _on_crypto_changed(_current_crypto: int) -> void:
	_refresh_all_rows_affordability()


func _on_virus_data_changed(_current_virus_data: int) -> void:
	_refresh_all_rows_affordability()


func _on_upgrade_purchase_counts_changed(
	_purchase_counts_snapshot: Dictionary
) -> void:
	rebuild_shop()


func _on_upgrades_changed() -> void:
	rebuild_shop()


func _refresh_all_rows_affordability() -> void:
	for key in _app_rows_by_offer_id.keys():
		var row: ShopOfferRow = (
			_app_rows_by_offer_id[key]
			as ShopOfferRow
		)

		if row == null:
			continue

		row.refresh_affordability(GameState.crypto)

	for row_variant in _upgrade_rows:
		var row: ShopOfferRow = row_variant as ShopOfferRow

		if row == null:
			continue

		row.refresh_affordability(GameState.crypto)


func _on_apps_button_pressed() -> void:
	_show_tab(ShopTab.APPS)


func _on_upgrades_button_pressed() -> void:
	_show_tab(ShopTab.UPGRADES)


func _show_tab(tab: int) -> void:
	_current_tab = tab

	var showing_apps: bool = (
		_current_tab == ShopTab.APPS
	)

	apps_panel.visible = showing_apps
	upgrades_panel.visible = not showing_apps

	apps_button.set_pressed_no_signal(showing_apps)
	upgrades_button.set_pressed_no_signal(not showing_apps)


func _configure_scroll_containers() -> void:
	_configure_scroll_container(apps_scroll)
	_configure_scroll_container(upgrades_scroll)


func _configure_scroll_container(
	scroll_container: ScrollContainer
) -> void:
	if scroll_container == null:
		return

	scroll_container.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	if hide_scrollbars:
		scroll_container.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_SHOW_NEVER
		)
	else:
		scroll_container.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_AUTO
		)


func _clear_container(container: Control) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _add_empty_label(
	parent: Control,
	text: String
) -> void:
	var label: Label = Label.new()

	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	parent.add_child(label)


func _sort_app_offers_by_price(
	a: ShopAppOfferData,
	b: ShopAppOfferData
) -> bool:
	return a.price < b.price


func _sort_upgrade_offers_by_price(
	a: ShopUpgradeOfferData,
	b: ShopUpgradeOfferData
) -> bool:
	if upgrade_manager != null:
		return (
			upgrade_manager.get_crypto_cost(a)
			< upgrade_manager.get_crypto_cost(b)
		)

	return (
		_get_first_upgrade_crypto_cost(a)
		< _get_first_upgrade_crypto_cost(b)
	)


func _get_first_upgrade_crypto_cost(
	offer: ShopUpgradeOfferData
) -> int:
	if offer == null:
		return 0

	if offer.crypto_costs.is_empty():
		return 0

	return offer.crypto_costs[0]
