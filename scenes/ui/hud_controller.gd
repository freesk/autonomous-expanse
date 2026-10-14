extends CanvasLayer
## HUD Controller for DroneWorld
## Manages all HUD elements and updates them based on drone state

# Node references
@onready var health_bar: Control = $MarginContainer/MainLayout/TopLeft/HealthShieldContainer/HealthBar
@onready var shield_bar: Control = $MarginContainer/MainLayout/TopLeft/HealthShieldContainer/ShieldBar
@onready var energy_bar: Control = $MarginContainer/MainLayout/TopLeft/HealthShieldContainer/EnergyBar
@onready var drone_name_label: Label = $MarginContainer/MainLayout/TopLeft/DroneInfoPanel/VBoxContainer/DroneNameLabel
@onready var speed_label: Label = $MarginContainer/MainLayout/TopLeft/DroneInfoPanel/VBoxContainer/SpeedLabel
@onready var altitude_label: Label = $MarginContainer/MainLayout/TopLeft/DroneInfoPanel/VBoxContainer/AltitudeLabel

@onready var primary_weapon_label: Label = $MarginContainer/MainLayout/TopRight/WeaponStatusPanel/VBoxContainer/PrimaryWeaponLabel
@onready var primary_ammo_bar: ProgressBar = $MarginContainer/MainLayout/TopRight/WeaponStatusPanel/VBoxContainer/PrimaryAmmoBar
@onready var primary_ammo_label: Label = $MarginContainer/MainLayout/TopRight/WeaponStatusPanel/VBoxContainer/PrimaryAmmoLabel
@onready var secondary_weapon_label: Label = $MarginContainer/MainLayout/TopRight/WeaponStatusPanel/VBoxContainer/SecondaryWeaponLabel
@onready var secondary_cooldown_bar: ProgressBar = $MarginContainer/MainLayout/TopRight/WeaponStatusPanel/VBoxContainer/SecondaryCooldownBar
@onready var secondary_cooldown_label: Label = $MarginContainer/MainLayout/TopRight/WeaponStatusPanel/VBoxContainer/SecondaryCooldownLabel
@onready var heat_bar: ProgressBar = $MarginContainer/MainLayout/TopRight/HeatPanel/VBoxContainer/HeatBar

@onready var boost_bar: ProgressBar = $MarginContainer/MainLayout/BottomLeft/BoostPanel/VBoxContainer/BoostBar

@onready var cargo_panel: PanelContainer = $MarginContainer/MainLayout/BottomLeft/CargoPanel
@onready var cargo_label: Label = $MarginContainer/MainLayout/BottomLeft/CargoPanel/VBoxContainer/CargoLabel
@onready var cargo_bar: ProgressBar = $MarginContainer/MainLayout/BottomLeft/CargoPanel/VBoxContainer/CargoBar

@onready var compass_label: Label = $MarginContainer/MainLayout/BottomRight/CompassPanel/VBoxContainer/CompassLabel
@onready var heading_label: Label = $MarginContainer/MainLayout/BottomRight/CompassPanel/VBoxContainer/HeadingLabel

@onready var enemy_lock_alert: Label = $MarginContainer/MainLayout/AlertsContainer/EnemyLockAlert
@onready var low_health_alert: Label = $MarginContainer/MainLayout/AlertsContainer/LowHealthAlert
@onready var overheat_alert: Label = $MarginContainer/MainLayout/AlertsContainer/OverheatAlert

@onready var damage_indicators: Control = $MarginContainer/MainLayout/DamageIndicators
@onready var top_indicator: ColorRect = $MarginContainer/MainLayout/DamageIndicators/TopIndicator
@onready var bottom_indicator: ColorRect = $MarginContainer/MainLayout/DamageIndicators/BottomIndicator
@onready var left_indicator: ColorRect = $MarginContainer/MainLayout/DamageIndicators/LeftIndicator
@onready var right_indicator: ColorRect = $MarginContainer/MainLayout/DamageIndicators/RightIndicator

@onready var notifications_container: VBoxContainer = $MarginContainer/MainLayout/NotificationsContainer
@onready var alert_flash_timer: Timer = $AlertFlashTimer
@onready var damage_indicator_timer: Timer = $DamageIndicatorTimer

# Current drone reference
var current_drone: RigidBody3D = null

# Alert flash state
var _alert_flash_state: bool = false

# Boost bar color thresholds
const BOOST_COLOR_FULL := Color(0, 1, 0)  # Green
const BOOST_COLOR_MID := Color(1, 1, 0)  # Yellow
const BOOST_COLOR_LOW := Color(0.5, 0.5, 0.5)  # Gray


func _ready() -> void:
	# Connect alert flash timer
	alert_flash_timer.timeout.connect(_on_alert_flash_timeout)
	damage_indicator_timer.timeout.connect(_on_damage_indicator_timeout)

	# Initialize health bar labels
	if health_bar and health_bar.has_method("set_label_text"):
		health_bar.set_label_text("Health")
	if shield_bar and shield_bar.has_method("set_label_text"):
		shield_bar.set_label_text("Shield")

	# Set energy bar label directly (avoid @onready issue with dynamic instantiation)
	var energy_bar_node = get_node_or_null("MarginContainer/MainLayout/TopLeft/HealthShieldContainer/EnergyBar")
	if energy_bar_node and energy_bar_node.has_method("set_label_text"):
		energy_bar_node.set_label_text("Energy")


func _process(_delta: float) -> void:
	if current_drone == null:
		return

	# Update speed and altitude
	_update_movement_info()

	# Update compass
	_update_compass()


func set_drone(drone: RigidBody3D) -> void:
	## Connect HUD to a drone
	if current_drone != null:
		_disconnect_drone_signals()

	current_drone = drone

	if current_drone != null:
		_connect_drone_signals()
		_update_drone_info()


func _connect_drone_signals() -> void:
	## Connect to drone signals for reactive updates
	if current_drone.has_signal("health_changed"):
		current_drone.health_changed.connect(_on_health_changed)
	if current_drone.has_signal("shields_changed"):
		current_drone.shields_changed.connect(_on_shield_changed)
	if current_drone.has_signal("energy_changed"):
		current_drone.energy_changed.connect(_on_energy_changed)


func _disconnect_drone_signals() -> void:
	## Disconnect from previous drone signals
	if current_drone.has_signal("health_changed"):
		current_drone.health_changed.disconnect(_on_health_changed)
	if current_drone.has_signal("shields_changed"):
		current_drone.shields_changed.disconnect(_on_shield_changed)
	if current_drone.has_signal("energy_changed"):
		current_drone.energy_changed.disconnect(_on_energy_changed)


func _update_drone_info() -> void:
	## Update HUD elements based on drone type and stats
	# Set drone name (defensive check - node may not exist in scene)
	if drone_name_label:
		drone_name_label.text = _get_drone_name()

	# Show/hide panels based on drone type
	_update_panel_visibility()

	# Initialize bars
	_update_health_shield()


func _get_drone_name() -> String:
	## Get display name for current drone
	if current_drone == null:
		return "No Drone"

	# Try to get from drone script
	if current_drone.has_method("get_drone_name"):
		return current_drone.get_drone_name()

	# Fallback to node name
	return current_drone.name


func _update_panel_visibility() -> void:
	## Show/hide panels based on drone type
	var drone_type := _get_drone_type()

	if cargo_panel:
		cargo_panel.visible = (drone_type == "cargo")


func _get_drone_type() -> String:
	## Get drone type from current drone
	if current_drone == null:
		return "unknown"

	if current_drone.has_method("get_drone_type"):
		return current_drone.get_drone_type()

	# Fallback: parse from name
	var drone_name := current_drone.name.to_lower()
	if "cargo" in drone_name:
		return "cargo"
	elif "explorer" in drone_name:
		return "explorer"
	elif "fighter" in drone_name:
		return "fighter"

	return "unknown"


func _update_movement_info() -> void:
	## Update speed and altitude displays
	if current_drone == null:
		return

	# Get speed (RigidBody3D uses linear_velocity, not velocity)
	var speed := 0.0
	if current_drone.has_method("get_current_speed"):
		speed = current_drone.get_current_speed()
	elif current_drone is RigidBody3D:
		speed = current_drone.linear_velocity.length()
	else:
		speed = 0.0

	speed_label.text = "Speed: %d m/s" % int(speed)

	# Get altitude using hover_physics get_altitude() for accurate ground distance
	var altitude := 0.0
	if current_drone.has_method("get_altitude"):
		altitude = current_drone.get_altitude()
	else:
		# Fallback to Y position
		altitude = current_drone.global_position.y

	altitude_label.text = "Altitude: %d m" % int(altitude)


func _update_compass() -> void:
	## Update compass heading
	if current_drone == null:
		return

	var rotation_y := current_drone.global_rotation.y
	var heading := int(rad_to_deg(-rotation_y)) % 360
	if heading < 0:
		heading += 360

	heading_label.text = "%d°" % heading

	# Update compass direction letter
	if heading >= 337.5 or heading < 22.5:
		compass_label.text = "N"
	elif heading >= 22.5 and heading < 67.5:
		compass_label.text = "NE"
	elif heading >= 67.5 and heading < 112.5:
		compass_label.text = "E"
	elif heading >= 112.5 and heading < 157.5:
		compass_label.text = "SE"
	elif heading >= 157.5 and heading < 202.5:
		compass_label.text = "S"
	elif heading >= 202.5 and heading < 247.5:
		compass_label.text = "SW"
	elif heading >= 247.5 and heading < 292.5:
		compass_label.text = "W"
	else:
		compass_label.text = "NW"


func _update_health_shield() -> void:
	## Update health and shield bars
	if current_drone == null:
		return

	# Try to get from HealthSystem first
	var health_system = current_drone.get_node_or_null("HealthSystem")
	if health_system:
		var health: float = health_system.current_health
		var max_health: float = health_system.max_health
		if health_bar and health_bar.has_method("set_values"):
			health_bar.set_values(health, max_health)

		var shield: float = health_system.current_shields
		var max_shield: float = health_system.max_shields
		if shield_bar and shield_bar.has_method("set_values"):
			shield_bar.set_values(shield, max_shield)

		# Show low health alert
		if health < max_health * 0.3:
			_show_low_health_alert()
		elif low_health_alert:
			low_health_alert.visible = false

	# Initialize energy bar as well so it doesn't stay at default values.
	var energy_system = current_drone.get_node_or_null("EnergySystem")
	if energy_system:
		var energy: float = energy_system.current_energy
		var max_energy: float = energy_system.max_energy
		if energy_bar and energy_bar.has_method("set_values"):
			energy_bar.set_values(energy, max_energy)


func update_weapon_info(primary_weapon: String, secondary_weapon: String) -> void:
	## Update weapon display
	primary_weapon_label.text = "Primary: " + primary_weapon
	secondary_weapon_label.text = "Secondary: " + secondary_weapon


func update_primary_ammo(current: int, maximum: int) -> void:
	## Update primary weapon ammo
	primary_ammo_bar.max_value = maximum
	primary_ammo_bar.value = current
	primary_ammo_label.text = "%d / %d" % [current, maximum]


func update_secondary_cooldown(current_time: float, max_time: float) -> void:
	## Update secondary weapon cooldown
	secondary_cooldown_bar.max_value = max_time
	secondary_cooldown_bar.value = max_time - current_time

	if current_time <= 0:
		secondary_cooldown_label.text = "Ready"
	else:
		secondary_cooldown_label.text = "%.1fs" % current_time


func update_weapon_heat(heat: float, max_heat: float) -> void:
	## Update weapon heat meter
	heat_bar.max_value = max_heat
	heat_bar.value = heat

	# Update color based on heat level
	var heat_percent := (heat / max_heat) * 100.0
	if heat_percent >= 90:
		heat_bar.modulate = Color(1, 0, 0)  # Red
		_show_overheat_alert()
	elif heat_percent >= 70:
		heat_bar.modulate = Color(1, 1, 0)  # Yellow
		if overheat_alert:
			overheat_alert.visible = false
	else:
		heat_bar.modulate = Color(0, 1, 0)  # Green
		if overheat_alert:
			overheat_alert.visible = false


func update_boost(amount: float, max_amount: float) -> void:
	## Update boost meter with color coding
	boost_bar.max_value = max_amount
	boost_bar.value = amount

	var boost_percent := (amount / max_amount) * 100.0
	if boost_percent >= 50:
		boost_bar.modulate = BOOST_COLOR_FULL
	elif boost_percent >= 20:
		boost_bar.modulate = BOOST_COLOR_MID
	else:
		boost_bar.modulate = BOOST_COLOR_LOW


func update_cargo(current: int, maximum: int) -> void:
	## Update cargo display
	cargo_label.text = "Cargo: %d / %d" % [current, maximum]
	cargo_bar.max_value = maximum
	cargo_bar.value = current


func show_damage_indicator(direction: Vector3) -> void:
	## Show directional damage indicator
	if current_drone == null:
		return

	# Convert world direction to camera-relative direction
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var local_dir := camera.global_transform.basis.inverse() * direction.normalized()

	# Determine which indicator to show
	var abs_x: float = abs(local_dir.x)
	var abs_z: float = abs(local_dir.z)

	if abs_z > abs_x:
		# Front or back
		if local_dir.z < 0:
			if top_indicator:
				top_indicator.visible = true
		else:
			if bottom_indicator:
				bottom_indicator.visible = true
	else:
		# Left or right
		if local_dir.x < 0:
			if left_indicator:
				left_indicator.visible = true
		else:
			if right_indicator:
				right_indicator.visible = true

	# Start timer to hide indicator
	if damage_indicator_timer:
		damage_indicator_timer.start()


func show_enemy_lock_alert() -> void:
	## Show enemy lock-on warning
	if enemy_lock_alert:
		enemy_lock_alert.visible = true
	if alert_flash_timer and not alert_flash_timer.is_stopped():
		return
	if alert_flash_timer:
		alert_flash_timer.start()


func hide_enemy_lock_alert() -> void:
	## Hide enemy lock-on warning
	if enemy_lock_alert:
		enemy_lock_alert.visible = false
	if alert_flash_timer:
		alert_flash_timer.stop()


func _show_low_health_alert() -> void:
	## Show low health warning
	if low_health_alert:
		low_health_alert.visible = true
	if alert_flash_timer and not alert_flash_timer.is_stopped():
		return
	if alert_flash_timer:
		alert_flash_timer.start()


func _show_overheat_alert() -> void:
	## Show weapon overheat warning
	if overheat_alert:
		overheat_alert.visible = true


func add_notification(message: String, duration: float = 3.0) -> void:
	## Add a notification message to the HUD
	var notification_scene := preload("res://scenes/ui/components/notification.tscn")
	var notification := notification_scene.instantiate()
	notifications_container.add_child(notification)

	if notification.has_method("show_message"):
		notification.show_message(message, duration)


func _on_alert_flash_timeout() -> void:
	## Toggle alert visibility for flashing effect
	_alert_flash_state = not _alert_flash_state

	if enemy_lock_alert and enemy_lock_alert.visible:
		enemy_lock_alert.modulate.a = 1.0 if _alert_flash_state else 0.3

	if low_health_alert and low_health_alert.visible:
		low_health_alert.modulate.a = 1.0 if _alert_flash_state else 0.3


func _on_damage_indicator_timeout() -> void:
	## Hide damage indicators after timeout
	if top_indicator:
		top_indicator.visible = false
	if bottom_indicator:
		bottom_indicator.visible = false
	if left_indicator:
		left_indicator.visible = false
	if right_indicator:
		right_indicator.visible = false


func _on_health_changed(new_health: float, max_health: float) -> void:
	## Handle health change signal from drone
	if health_bar.has_method("set_values"):
		health_bar.set_values(new_health, max_health)

	if new_health < max_health * 0.3:
		_show_low_health_alert()
	else:
		low_health_alert.visible = false


func _on_shield_changed(new_shield: float, max_shield: float) -> void:
	## Handle shield change signal from drone
	if shield_bar.has_method("set_values"):
		shield_bar.set_values(new_shield, max_shield)


func _on_energy_changed(new_energy: float, max_energy: float) -> void:
	## Handle energy change signal from drone
	# Get energy_bar directly instead of using @onready (can be null if dynamically instantiated)
	var energy_bar_node = get_node_or_null("MarginContainer/MainLayout/TopLeft/HealthShieldContainer/EnergyBar")
	if energy_bar_node and energy_bar_node.has_method("set_values"):
		energy_bar_node.set_values(new_energy, max_energy)


func _on_damage_received(damage_direction: Vector3) -> void:
	## Handle damage received signal
	show_damage_indicator(damage_direction)
