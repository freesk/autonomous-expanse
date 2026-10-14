extends Node
class_name ThrusterController

## ThrusterController - Animates thruster visual effects based on drone movement
##
## This component automatically discovers and controls thruster flame and glow effects
## on any drone. It responds to forward movement, climbing, and boost states by
## dynamically adjusting the brightness and intensity of the thruster visuals.
##
## USAGE:
## 1. Add this node as a child of a drone (RigidBody3D with MotionSystem)
## 2. In ModelMount, create Engine nodes (e.g., EngineLeft, EngineRight)
## 3. Add ThrusterMesh (with shader material) and GlowBall (with emissive material) as children
## 4. The controller will auto-discover and animate them
##
## The thruster effects respond to:
## - Forward velocity (brighter when moving forward)
## - Vertical velocity (brighter when climbing)
## - Boost state (multiplied brightness)

## Manual assignment of thruster meshes (optional - auto-discovers if empty)
## Note: Untyped to avoid Godot scene serialization issues with NodePaths
@export var thruster_meshes: Array = []
## Manual assignment of glow ball meshes (optional - auto-discovers if empty)
## Note: Untyped to avoid Godot scene serialization issues with NodePaths
@export var glow_balls: Array = []

@export_group("Flame Intensity")
## Base flame brightness when idle/hovering
@export var base_intensity: float = 0.3
## Maximum flame brightness at full thrust
@export var max_intensity: float = 3.0

@export_group("Glow Ball Emission")
## Base glow ball emission energy when idle
@export var base_glow_emission: float = 0.5
## Maximum glow ball emission energy at full thrust
@export var max_glow_emission: float = 8.0

@export_group("Animation")
## How fast intensity changes (higher = more responsive)
@export var intensity_smoothing: float = 8.0

var drone: RigidBody3D = null
var motion_system: MotionSystem = null
var current_intensity: float = 0.0
var target_intensity: float = 0.0


func _ready() -> void:
	# Find the parent drone (RigidBody3D)
	drone = get_parent() as RigidBody3D

	if not drone:
		push_error("[ThrusterController] Parent must be a RigidBody3D (drone)!")
		return

	# Find MotionSystem
	motion_system = drone.get_node_or_null("MotionSystem")
	if not motion_system:
		push_warning("[ThrusterController] MotionSystem not found!")
		return

	# If no meshes specified, auto-discover them in the tree
	if thruster_meshes.is_empty() or glow_balls.is_empty():
		_auto_discover_thrusters()

	print("[ThrusterController] Initialized with ", thruster_meshes.size(), " thruster meshes and ", glow_balls.size(), " glow balls")

	# Set initial intensity for thruster meshes
	for mesh in thruster_meshes:
		if mesh and mesh.get_surface_override_material(0):
			var mat = mesh.get_surface_override_material(0) as ShaderMaterial
			if mat:
				mat.set_shader_parameter("color_intensity", base_intensity)

	# Create unique materials for each glow ball so they can be animated independently
	for ball in glow_balls:
		if not ball:
			continue
		var original_mat = ball.get_surface_override_material(0) as StandardMaterial3D
		if original_mat:
			var unique_mat = original_mat.duplicate()
			ball.set_surface_override_material(0, unique_mat)
			print("[ThrusterController] Created unique material for glow ball")


func _auto_discover_thrusters() -> void:
	## Auto-discover thruster meshes in the ModelMount
	thruster_meshes.clear()
	glow_balls.clear()

	var model_mount = drone.get_node_or_null("ModelMount")
	if not model_mount:
		push_warning("[ThrusterController] ModelMount not found!")
		return

	# Find all Thruster instances (or legacy Engine nodes)
	for child in model_mount.get_children():
		# Support both new Thruster instances and legacy Engine nodes
		var is_thruster = child.name == "Thruster" or child.name.begins_with("Engine")

		if is_thruster:
			# Look for ThrusterMesh and GlowBall children
			var thruster_mesh = child.get_node_or_null("ThrusterMesh")
			var glow_ball = child.get_node_or_null("GlowBall")

			if thruster_mesh and thruster_mesh is MeshInstance3D:
				thruster_meshes.append(thruster_mesh)
				print("[ThrusterController] Found ThrusterMesh: ", thruster_mesh.get_path())

			if glow_ball and glow_ball is MeshInstance3D:
				glow_balls.append(glow_ball)
				print("[ThrusterController] Found GlowBall: ", glow_ball.get_path())


func _process(delta: float) -> void:
	if not drone or not motion_system:
		return

	# Calculate target intensity based on motion state
	target_intensity = calculate_thrust_intensity()

	# Smooth interpolation toward target
	current_intensity = lerp(current_intensity, target_intensity, intensity_smoothing * delta)

	# Apply to all thruster meshes
	update_thruster_visuals()


func calculate_thrust_intensity() -> float:
	## Calculate how much thrust the drone is currently using
	var intensity: float = base_intensity

	# Check if we're near ground and hovering (active suspension)
	var is_hovering: bool = false
	for raycast in motion_system.hover_raycasts:
		if raycast.is_colliding():
			is_hovering = true
			break

	if is_hovering:
		intensity = base_intensity

	# Get forward velocity (in local space)
	var local_velocity = drone.global_transform.basis.inverse() * drone.linear_velocity
	var forward_speed = -local_velocity.z  # Negative Z is forward in Godot

	# Add intensity based on forward movement
	if forward_speed > 0.5:
		var forward_intensity = remap(forward_speed, 0.0, 20.0, 0.0, max_intensity - base_intensity)
		intensity += forward_intensity

	# Add intensity based on vertical velocity (climbing = more thrust)
	var vertical_velocity := drone.linear_velocity.y
	if vertical_velocity > 0.1:
		var climb_intensity = remap(vertical_velocity, 0.0, 10.0, 0.0, (max_intensity - base_intensity) * 0.5)
		intensity += climb_intensity

	# Boost increases intensity
	if motion_system.is_boosting:
		intensity *= motion_system.boost_multiplier

	# Clamp to max
	return clamp(intensity, base_intensity, max_intensity)


func update_thruster_visuals() -> void:
	## Apply current intensity to all thruster materials
	for mesh in thruster_meshes:
		if not mesh:
			continue

		var mat = mesh.get_surface_override_material(0) as ShaderMaterial
		if not mat:
			continue

		mat.set_shader_parameter("color_intensity", current_intensity)

		# Also adjust dissolve length for more dramatic effect
		var dissolve: float = remap(current_intensity, base_intensity, max_intensity, 0.8, 1.2)
		mat.set_shader_parameter("dissolve_length", dissolve)

	# Update glow ball emission intensity
	var glow_emission = remap(current_intensity, base_intensity, max_intensity, base_glow_emission, max_glow_emission)
	for ball in glow_balls:
		if not ball:
			continue

		var mat = ball.get_surface_override_material(0) as StandardMaterial3D
		if not mat:
			continue

		mat.emission_energy_multiplier = glow_emission
