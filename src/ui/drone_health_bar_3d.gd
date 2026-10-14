extends Node3D
class_name DroneHealthBar3D

## 3D floating health/shield bar above drones
## Shows current health and shields as colored bars

## Configuration
@export var bar_width: float = 1.5  ## Reasonable size
@export var bar_height: float = 0.15  ## Thin bar
@export var bar_offset_y: float = 2.0  ## Height above drone
@export var health_color: Color = Color(1.0, 0.0, 0.0, 0.7)  ## Red, semi-transparent
@export var shield_color: Color = Color(0.0, 0.5, 1.0, 0.7)  ## Blue, semi-transparent
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.6)  ## Gray, semi-transparent
@export var always_visible: bool = false  ## If false, only show when damaged
@export var visibility_duration: float = 3.0  ## How long to show bar after taking damage

## References
var health_system = null  # HealthSystem
var camera: Camera3D = null

## Visual elements
var background_mesh: MeshInstance3D
var shield_mesh: MeshInstance3D
var health_mesh: MeshInstance3D

## State
var current_health_percent: float = 1.0
var current_shield_percent: float = 1.0
var is_visible_state: bool = false
var hide_timer: Timer = null


func _ready() -> void:
	# Find health system in parent
	health_system = get_parent().get_node_or_null("HealthSystem")
	if not health_system:
		push_warning("[DroneHealthBar3D] No HealthSystem found on parent")
		queue_free()
		return

	# Connect to health system signals
	health_system.health_changed.connect(_on_health_changed)
	health_system.shields_changed.connect(_on_shields_changed)
	health_system.damage_taken.connect(_on_damage_taken)
	health_system.died.connect(_on_died)

	# Create visual elements
	_create_bar_visuals()

	# Position above drone
	position = Vector3(0, bar_offset_y, 0)

	# Create hide timer
	hide_timer = Timer.new()
	add_child(hide_timer)
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)

	# Start hidden if not always visible
	if not always_visible:
		visible = false
		is_visible_state = false


func _process(_delta: float) -> void:
	# Billboard effect - always face camera
	if camera or _find_camera():
		# Calculate direction to camera
		var to_camera = camera.global_position - global_position
		to_camera.y = 0  # Keep it level (no pitch)

		if to_camera.length() > 0.001:
			# Look at camera position (keeping Y axis up)
			var target_pos = global_position + to_camera.normalized()
			look_at(target_pos, Vector3.UP)


func _find_camera() -> bool:
	camera = get_viewport().get_camera_3d()
	return camera != null


func _create_bar_visuals() -> void:
	## Create 3 layered bar meshes: background, shield, health

	# Background bar (full width, bottom position)
	background_mesh = _create_bar_mesh(bar_width, background_color)
	add_child(background_mesh)
	background_mesh.position.y = -bar_height  # Bottom bar
	background_mesh.position.z = 0.02  # Slightly behind

	# Health bar (red, bottom position)
	health_mesh = _create_bar_mesh(bar_width * current_health_percent, health_color)
	add_child(health_mesh)
	health_mesh.position.y = -bar_height  # Bottom bar
	health_mesh.position.z = 0.0

	# Shield bar (blue, top position)
	shield_mesh = _create_bar_mesh(bar_width * current_shield_percent, shield_color)
	add_child(shield_mesh)
	shield_mesh.position.y = 0.0  # Top bar
	shield_mesh.position.z = 0.0


func _create_bar_mesh(width: float, color: Color) -> MeshInstance3D:
	## Create a colored bar mesh using BoxMesh
	var mesh_instance = MeshInstance3D.new()

	# Use BoxMesh for better rendering reliability
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(width, bar_height, 0.05)  # Very thin box
	mesh_instance.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true  # Always render on top
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Render both sides
	mesh_instance.material_override = material

	return mesh_instance


func _update_bar_visuals() -> void:
	## Update bar widths and positions based on current health/shields
	if not health_mesh or not shield_mesh:
		return

	# Update shield bar (top, blue)
	var shield_width = bar_width * current_shield_percent
	if shield_mesh.mesh is BoxMesh:
		shield_mesh.mesh.size = Vector3(shield_width, bar_height, 0.05)
	# Center the bar horizontally, keep at top
	shield_mesh.position.x = -(bar_width - shield_width) / 2.0
	shield_mesh.position.y = 0.0

	# Update health bar (bottom, red)
	var health_width = bar_width * current_health_percent
	if health_mesh.mesh is BoxMesh:
		health_mesh.mesh.size = Vector3(health_width, bar_height, 0.05)
	# Center the bar horizontally, keep at bottom
	health_mesh.position.x = -(bar_width - health_width) / 2.0
	health_mesh.position.y = -bar_height


func _on_health_changed(current: float, maximum: float) -> void:
	current_health_percent = current / maximum if maximum > 0 else 0.0
	_update_bar_visuals()


func _on_shields_changed(current: float, maximum: float) -> void:
	current_shield_percent = current / maximum if maximum > 0 else 0.0
	_update_bar_visuals()


func _on_damage_taken(_amount: float, attacker: Node3D) -> void:
	# Only show bar when damaged by player (not by other AI drones)
	if not always_visible:
		# Check if attacker is the player
		var is_player_attack = false
		if attacker:
			# Player drone usually has name "Player" or has MotionController in manual mode
			if attacker.name == "Player":
				is_player_attack = true
			elif attacker.has_node("MotionController"):
				var input_controller = attacker.get_node("MotionController")
				if input_controller.control_mode == 0:  # 0 = Manual (player)
					is_player_attack = true

		if is_player_attack:
			# Show bar and start timer
			visible = true
			is_visible_state = true

			# Restart timer (reset if already counting)
			if hide_timer:
				hide_timer.start(visibility_duration)


func _on_hide_timer_timeout() -> void:
	# Hide bar after timer expires
	if not always_visible:
		visible = false
		is_visible_state = false


func _on_died() -> void:
	# Hide bar when drone dies
	visible = false
