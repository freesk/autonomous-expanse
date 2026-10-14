extends Control
## Mothership UI controller
## Handles drone switching, weapon equipping, upgrades, and inventory management

# Tab buttons
@onready var drone_bay_button: Button = $MarginContainer/HBoxContainer/LeftPanel/TabButtons/DroneBayButton
@onready var armory_button: Button = $MarginContainer/HBoxContainer/LeftPanel/TabButtons/ArmoryButton
@onready var upgrades_button: Button = $MarginContainer/HBoxContainer/LeftPanel/TabButtons/UpgradesButton
@onready var storage_button: Button = $MarginContainer/HBoxContainer/LeftPanel/TabButtons/StorageButton
@onready var map_button: Button = $MarginContainer/HBoxContainer/LeftPanel/TabButtons/MapButton
@onready var exit_button: Button = $MarginContainer/HBoxContainer/LeftPanel/ExitButton

# Resource labels
@onready var metal_label: Label = $MarginContainer/HBoxContainer/LeftPanel/ResourcesPanel/VBoxContainer/MetalLabel
@onready var energy_label: Label = $MarginContainer/HBoxContainer/LeftPanel/ResourcesPanel/VBoxContainer/EnergyLabel
@onready var artifacts_label: Label = $MarginContainer/HBoxContainer/LeftPanel/ResourcesPanel/VBoxContainer/ArtifactsLabel

# Tab content panels
@onready var drone_bay_tab: VBoxContainer = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/DroneBayTab
@onready var armory_tab: VBoxContainer = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/ArmoryTab
@onready var upgrades_tab: VBoxContainer = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/UpgradesTab
@onready var storage_tab: VBoxContainer = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/StorageTab
@onready var map_tab: VBoxContainer = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/MapTab

# Drone Bay
@onready var drones_list: VBoxContainer = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/DroneBayTab/ScrollContainer/DronesList

# Armory
@onready var weapons_list: ItemList = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/ArmoryTab/HBoxContainer/LeftPanel/WeaponsList
@onready var loadout_info: RichTextLabel = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/ArmoryTab/HBoxContainer/RightPanel/LoadoutInfo
@onready var equip_button: Button = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/ArmoryTab/HBoxContainer/RightPanel/EquipButton

# Upgrades
@onready var upgrades_list: VBoxContainer = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/UpgradesTab/ScrollContainer/UpgradesList

# Storage
@onready var storage_grid: GridContainer = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/StorageTab/GridContainer

# Map
@onready var locations_list: ItemList = $MarginContainer/HBoxContainer/ContentPanel/MarginContainer/TabContent/MapTab/HBoxContainer/JournalPanel/LocationsList

# State
var current_tab: String = "drone_bay"
var selected_drone: String = ""
var player_resources: Dictionary = {
	"metal": 0,
	"energy": 0,
	"artifacts": 0
}

var available_drones: Array[Dictionary] = []
var available_weapons: Array[Dictionary] = []
var available_upgrades: Array[Dictionary] = []
var inventory_items: Array[Dictionary] = []
var discovered_locations: Array[String] = []

signal drone_switched(drone_name: String)
signal weapon_equipped(weapon_name: String, slot: String)
signal upgrade_purchased(upgrade_name: String)
signal mothership_exited


func _ready() -> void:
	# Connect tab buttons
	drone_bay_button.pressed.connect(_on_tab_selected.bind("drone_bay"))
	armory_button.pressed.connect(_on_tab_selected.bind("armory"))
	upgrades_button.pressed.connect(_on_tab_selected.bind("upgrades"))
	storage_button.pressed.connect(_on_tab_selected.bind("storage"))
	map_button.pressed.connect(_on_tab_selected.bind("map"))
	exit_button.pressed.connect(_on_exit_pressed)

	# Connect armory button
	equip_button.pressed.connect(_on_equip_weapon_pressed)

	# Initialize UI
	_show_tab("drone_bay")
	_update_resources_display()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_exit_pressed()
		get_viewport().set_input_as_handled()


func show_mothership_ui() -> void:
	## Show the mothership UI
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Refresh data
	_refresh_all_tabs()


func hide_mothership_ui() -> void:
	## Hide the mothership UI
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_resources(metal: int, energy: int, artifacts: int) -> void:
	## Set player resources
	player_resources["metal"] = metal
	player_resources["energy"] = energy
	player_resources["artifacts"] = artifacts
	_update_resources_display()


func add_resources(metal: int = 0, energy: int = 0, artifacts: int = 0) -> void:
	## Add resources
	player_resources["metal"] += metal
	player_resources["energy"] += energy
	player_resources["artifacts"] += artifacts
	_update_resources_display()


func set_available_drones(drones: Array[Dictionary]) -> void:
	## Set available drones
	available_drones = drones
	_populate_drone_bay()


func set_available_weapons(weapons: Array[Dictionary]) -> void:
	## Set available weapons
	available_weapons = weapons
	_populate_armory()


func set_available_upgrades(upgrades: Array[Dictionary]) -> void:
	## Set available upgrades
	available_upgrades = upgrades
	_populate_upgrades()


func set_inventory(items: Array[Dictionary]) -> void:
	## Set inventory items
	inventory_items = items
	_populate_storage()


func set_discovered_locations(locations: Array[String]) -> void:
	## Set discovered locations
	discovered_locations = locations
	_populate_map()


func _update_resources_display() -> void:
	## Update resource labels
	metal_label.text = "Metal: %d" % player_resources["metal"]
	energy_label.text = "Energy: %d" % player_resources["energy"]
	artifacts_label.text = "Artifacts: %d" % player_resources["artifacts"]


func _show_tab(tab_name: String) -> void:
	## Show a specific tab
	current_tab = tab_name

	# Hide all tabs
	drone_bay_tab.visible = false
	armory_tab.visible = false
	upgrades_tab.visible = false
	storage_tab.visible = false
	map_tab.visible = false

	# Unpress all buttons
	drone_bay_button.button_pressed = false
	armory_button.button_pressed = false
	upgrades_button.button_pressed = false
	storage_button.button_pressed = false
	map_button.button_pressed = false

	# Show selected tab
	match tab_name:
		"drone_bay":
			drone_bay_tab.visible = true
			drone_bay_button.button_pressed = true
		"armory":
			armory_tab.visible = true
			armory_button.button_pressed = true
		"upgrades":
			upgrades_tab.visible = true
			upgrades_button.button_pressed = true
		"storage":
			storage_tab.visible = true
			storage_button.button_pressed = true
		"map":
			map_tab.visible = true
			map_button.button_pressed = true


func _refresh_all_tabs() -> void:
	## Refresh all tab content
	_populate_drone_bay()
	_populate_armory()
	_populate_upgrades()
	_populate_storage()
	_populate_map()


func _populate_drone_bay() -> void:
	## Populate drone bay with available drones
	# Clear existing drone entries
	for child in drones_list.get_children():
		child.queue_free()

	# Add drone entries
	for drone in available_drones:
		var drone_panel := _create_drone_entry(drone)
		drones_list.add_child(drone_panel)


func _create_drone_entry(drone_data: Dictionary) -> PanelContainer:
	## Create a drone entry panel
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = drone_data.get("name", "Unknown Drone")
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	var type_label := Label.new()
	type_label.text = "Type: " + drone_data.get("type", "Unknown")
	vbox.add_child(type_label)

	var health_label := Label.new()
	health_label.text = "Health: %d / %d" % [drone_data.get("current_health", 100), drone_data.get("max_health", 100)]
	vbox.add_child(health_label)

	var select_button := Button.new()
	select_button.text = "Select"
	select_button.custom_minimum_size = Vector2(120, 40)
	select_button.pressed.connect(_on_drone_selected.bind(drone_data.get("name", "")))
	hbox.add_child(select_button)

	return panel


func _populate_armory() -> void:
	## Populate armory with available weapons
	weapons_list.clear()

	for weapon in available_weapons:
		weapons_list.add_item(weapon.get("name", "Unknown Weapon"))


func _populate_upgrades() -> void:
	## Populate upgrades list
	# Clear existing upgrade entries
	for child in upgrades_list.get_children():
		child.queue_free()

	# Add upgrade entries
	for upgrade in available_upgrades:
		var upgrade_panel := _create_upgrade_entry(upgrade)
		upgrades_list.add_child(upgrade_panel)


func _create_upgrade_entry(upgrade_data: Dictionary) -> PanelContainer:
	## Create an upgrade entry panel
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = upgrade_data.get("name", "Unknown Upgrade")
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = upgrade_data.get("description", "")
	vbox.add_child(desc_label)

	var cost_label := Label.new()
	cost_label.text = "Cost: %d Metal" % upgrade_data.get("cost", 0)
	vbox.add_child(cost_label)

	var purchase_button := Button.new()
	purchase_button.text = "Purchase"
	purchase_button.custom_minimum_size = Vector2(120, 40)
	purchase_button.pressed.connect(_on_upgrade_purchased.bind(upgrade_data))
	purchase_button.disabled = player_resources["metal"] < upgrade_data.get("cost", 0)
	hbox.add_child(purchase_button)

	return panel


func _populate_storage() -> void:
	## Populate storage grid with inventory items
	# Clear existing items
	for child in storage_grid.get_children():
		child.queue_free()

	# Add inventory items
	for item in inventory_items:
		var item_button := Button.new()
		item_button.custom_minimum_size = Vector2(80, 80)
		item_button.text = item.get("name", "Item")
		storage_grid.add_child(item_button)


func _populate_map() -> void:
	## Populate map with discovered locations
	locations_list.clear()

	for location in discovered_locations:
		locations_list.add_item(location)


func _on_tab_selected(tab_name: String) -> void:
	## Handle tab button press
	_show_tab(tab_name)


func _on_drone_selected(drone_name: String) -> void:
	## Handle drone selection
	selected_drone = drone_name
	drone_switched.emit(drone_name)
	print("Selected drone: ", drone_name)


func _on_equip_weapon_pressed() -> void:
	## Handle weapon equip button
	var selected_indices := weapons_list.get_selected_items()
	if selected_indices.is_empty():
		return

	var weapon_index := selected_indices[0]
	var weapon_name := weapons_list.get_item_text(weapon_index)

	# TODO: Implement weapon slot selection
	weapon_equipped.emit(weapon_name, "primary")
	print("Equipped weapon: ", weapon_name)


func _on_upgrade_purchased(upgrade_data: Dictionary) -> void:
	## Handle upgrade purchase
	var cost: int = upgrade_data.get("cost", 0)

	if player_resources["metal"] >= cost:
		player_resources["metal"] -= cost
		_update_resources_display()
		upgrade_purchased.emit(upgrade_data.get("name", ""))
		print("Purchased upgrade: ", upgrade_data.get("name", ""))

		# Refresh upgrades list
		_populate_upgrades()


func _on_exit_pressed() -> void:
	## Handle exit button
	hide_mothership_ui()
	mothership_exited.emit()
