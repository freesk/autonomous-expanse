extends StaticBody3D
class_name MothershipController

## Mothership interaction controller
## Handles player interaction zones and triggers UI

@onready var health_system: HealthSystem = $HealthSystem

# Track which zones player is in
var player_in_drone_bay: bool = false
var player_in_armory: bool = false
var player_in_upgrade_terminal: bool = false
var player_in_landing_pad: bool = false

var current_player: CharacterBody3D = null

signal player_docked
signal player_undocked
signal interaction_available(zone_name: String)
signal interaction_unavailable(zone_name: String)

func _ready() -> void:
	# Connect to GameManager
	if GameManager:
		player_docked.connect(GameManager._on_player_docked)
		player_undocked.connect(GameManager._on_player_undocked)

func _process(_delta: float) -> void:
	# Check for interaction input
	if Input.is_action_just_pressed("interact"):
		_handle_interaction()

func _handle_interaction() -> void:
	if player_in_drone_bay:
		_open_drone_bay()
	elif player_in_armory:
		_open_armory()
	elif player_in_upgrade_terminal:
		_open_upgrade_terminal()

func _open_drone_bay() -> void:
	if UIManager:
		UIManager.show_mothership_ui()
		UIManager.mothership_ui.select_tab("drone_bay")

func _open_armory() -> void:
	if UIManager:
		UIManager.show_mothership_ui()
		UIManager.mothership_ui.select_tab("armory")

func _open_upgrade_terminal() -> void:
	if UIManager:
		UIManager.show_mothership_ui()
		UIManager.mothership_ui.select_tab("upgrades")

# Drone Bay signals
func _on_drone_bay_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("get_drone_type"):
		player_in_drone_bay = true
		current_player = body
		interaction_available.emit("Drone Bay")
		if UIManager:
			UIManager.show_notification("Press E to access Drone Bay", UIManager.NotificationType.INFO, 3.0)

func _on_drone_bay_body_exited(body: Node3D) -> void:
	if body == current_player:
		player_in_drone_bay = false
		interaction_unavailable.emit("Drone Bay")

# Armory signals
func _on_armory_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("get_drone_type"):
		player_in_armory = true
		current_player = body
		interaction_available.emit("Armory")
		if UIManager:
			UIManager.show_notification("Press E to access Armory", UIManager.NotificationType.INFO, 3.0)

func _on_armory_body_exited(body: Node3D) -> void:
	if body == current_player:
		player_in_armory = false
		interaction_unavailable.emit("Armory")

# Upgrade Terminal signals
func _on_upgrade_terminal_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("get_drone_type"):
		player_in_upgrade_terminal = true
		current_player = body
		interaction_available.emit("Upgrade Terminal")
		if UIManager:
			UIManager.show_notification("Press E to access Upgrades", UIManager.NotificationType.INFO, 3.0)

func _on_upgrade_terminal_body_exited(body: Node3D) -> void:
	if body == current_player:
		player_in_upgrade_terminal = false
		interaction_unavailable.emit("Upgrade Terminal")

# Landing Pad signals (auto-save trigger)
func _on_landing_pad_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("get_drone_type"):
		player_in_landing_pad = true
		current_player = body
		player_docked.emit()
		if GameManager:
			GameManager.set_at_mothership(true)
		if UIManager:
			UIManager.show_notification("Docked at Mothership - Game Saved", UIManager.NotificationType.SUCCESS, 2.0)

func _on_landing_pad_body_exited(body: Node3D) -> void:
	if body == current_player:
		player_in_landing_pad = false
		player_undocked.emit()
		if GameManager:
			GameManager.set_at_mothership(false)
