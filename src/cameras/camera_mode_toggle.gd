extends Node

## Camera Mode Toggle System
## Switches between Debug (FreeCamera) and Player (DroneCamera) modes
## Press Tab to toggle

enum ViewMode {
	DEBUG,   # Free camera mode
	PLAYER   # Following player drone
}

@export var free_camera: Camera3D
@export var player_camera: Camera3D
@export var player_drone: Node3D
@export var debug_ui: CanvasLayer
@export var player_hud: CanvasLayer

var current_mode: ViewMode = ViewMode.PLAYER

func _ready() -> void:
	# Wait for scene tree to be ready
	call_deferred("_initialize")

func _initialize() -> void:
	# Resolve node paths if they weren't set in editor
	if not free_camera and has_node("../FreeCamera"):
		free_camera = get_node("../FreeCamera")
	if not player_camera and has_node("../PlayerCamera"):
		player_camera = get_node("../PlayerCamera")
	if not player_drone and has_node("../Player"):
		player_drone = get_node("../Player")
	if not debug_ui and has_node("../DebugUI"):
		debug_ui = get_node("../DebugUI")
	if not player_hud and has_node("../PlayerHUD"):
		player_hud = get_node("../PlayerHUD")

	print("[CameraToggle] Initialized - Press Tab to switch modes")
	print("[CameraToggle] Free camera: %s" % free_camera)
	print("[CameraToggle] Player camera: %s" % player_camera)
	print("[CameraToggle] Player drone: %s" % player_drone)
	print("[CameraToggle] Debug UI: %s" % debug_ui)
	print("[CameraToggle] Player HUD: %s" % player_hud)

	# Start in player mode
	_set_mode(ViewMode.PLAYER)

func _input(event: InputEvent) -> void:
	# Check for Tab key directly
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_TAB:
			print("[CameraToggle] Tab key detected!")
			_toggle_mode()
			get_viewport().set_input_as_handled()

func _toggle_mode() -> void:
	if current_mode == ViewMode.DEBUG:
		_set_mode(ViewMode.PLAYER)
	else:
		_set_mode(ViewMode.DEBUG)

func _set_mode(mode: ViewMode) -> void:
	current_mode = mode

	match mode:
		ViewMode.DEBUG:
			_activate_debug_mode()
		ViewMode.PLAYER:
			_activate_player_mode()

func _activate_debug_mode() -> void:
	print("[CameraToggle] Switching to DEBUG mode (FreeCamera)")

	# Position free camera above terrain at a safe height
	_position_free_camera_safely()

	# Switch cameras
	if player_camera:
		player_camera.current = false
	if free_camera:
		free_camera.current = true

	# Switch UI and disconnect HUD
	if debug_ui:
		debug_ui.visible = true
	if player_hud:
		player_hud.visible = false
		# Disconnect HUD from player drone
		if player_hud.has_method("set_drone"):
			player_hud.set_drone(null)

	# Disable player drone input
	if player_drone and player_drone.has_node("MotionController"):
		var input_controller = player_drone.get_node("MotionController")
		input_controller.control_mode = 2  # Disabled mode

func _activate_player_mode() -> void:
	print("[CameraToggle] Switching to PLAYER mode (DroneCamera)")

	# Switch cameras
	if free_camera:
		free_camera.current = false
		print("[CameraToggle] - Disabled FreeCamera")
	if player_camera:
		player_camera.current = true
		print("[CameraToggle] - Enabled PlayerCamera at position: %v" % player_camera.global_position)

	# Switch UI
	if debug_ui:
		debug_ui.visible = false
		print("[CameraToggle] - Hidden DebugUI")
	if player_hud:
		player_hud.visible = true
		print("[CameraToggle] - Shown PlayerHUD")

		# Connect HUD to player drone
		if player_drone and player_hud.has_method("set_drone"):
			player_hud.set_drone(player_drone)
			print("[CameraToggle] - Connected HUD to player drone")

	# Enable player drone input
	if player_drone:
		print("[CameraToggle] - Player drone position: %v" % player_drone.global_position)
		if player_drone.has_node("MotionController"):
			var input_controller = player_drone.get_node("MotionController")
			input_controller.control_mode = 0  # Player mode
			print("[CameraToggle] - Set player drone to control_mode 0 (Player)")
		else:
			print("[CameraToggle] ERROR: Player drone has no MotionController!")
	else:
		print("[CameraToggle] ERROR: No player drone found!")

func _position_free_camera_safely() -> void:
	"""Position free camera at a safe location above terrain"""
	if not free_camera:
		return

	# Get WorldGenerator to query terrain height
	var world_gen = get_tree().root.find_child("WorldGenerator", true, false)
	if not world_gen or not world_gen.has_method("get_terrain_height_at"):
		print("[CameraToggle] No WorldGenerator found, using default safe position")
		# Default safe position high above origin
		free_camera.global_position = Vector3(0, 200, 300)
		return

	# Determine where to position camera
	var target_pos: Vector3

	# If player drone exists and is valid, position camera above it
	if player_drone and is_instance_valid(player_drone):
		target_pos = player_drone.global_position
		# Check if player is dead (underground or invalid position)
		var health_system = player_drone.get_node_or_null("HealthSystem")
		if health_system and health_system.has_method("is_dead") and health_system.is_dead():
			# Player is dead, use last known position but ensure safe height
			var terrain_height = world_gen.get_terrain_height_at(target_pos.x, target_pos.z)
			# Position camera 100m above terrain at player's X/Z location
			free_camera.global_position = Vector3(target_pos.x, terrain_height + 100, target_pos.z)
			print("[CameraToggle] Player dead - positioned free camera at (%v, %v, %v) - 100m above terrain (%.1fm)" % [
				target_pos.x, terrain_height + 100, target_pos.z, terrain_height
			])
		else:
			# Player alive, position camera 50m above and behind player
			var offset = Vector3(0, 50, 50)
			free_camera.global_position = target_pos + offset
			print("[CameraToggle] Positioned free camera 50m above player at %v" % free_camera.global_position)
	else:
		# No player drone, use safe default position
		var terrain_height = world_gen.get_terrain_height_at(0, 0)
		free_camera.global_position = Vector3(0, terrain_height + 200, 300)
		print("[CameraToggle] No player - positioned free camera at safe default: %v" % free_camera.global_position)
