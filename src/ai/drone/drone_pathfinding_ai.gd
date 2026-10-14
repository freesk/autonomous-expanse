extends Node
# PathfindingAI - No class_name to avoid conflicts, use preload instead

## Pathfinding AI - Universal pathfinding that can clear obstacles
## Handles navigation, obstacle avoidance, patrol paths
## Used by both patrol and combat states

## References
var drone: RigidBody3D = null
var world_generator: Node = null  # Reference to WorldGenerator for terrain height queries

## Patrol configuration
@export var patrol_waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var waypoint_reach_distance: float = 5.0

## Navigation state
var target_position: Vector3 = Vector3.ZERO
var patrol_mode: bool = true
var speed_fraction: float = 1.0 # 0.0-1.0, fraction of drone's max speed
var combat_mode_los: bool = false # When true, CombatAI controls rotation (has line of sight)

## Waypoint navigation
var navigation_waypoints: Array[Vector3] = []  # Waypoints to final destination
var current_nav_waypoint_index: int = 0
const WAYPOINT_SPACING: float = 100.0  # Generate waypoints every 100m
const NAV_WAYPOINT_REACH_DISTANCE: float = 15.0  # Distance to consider waypoint reached

## Tracking for climb logging (REQUIREMENT 2)
var last_y_position: float = 0.0
var climb_threshold: float = 0.5 # Must climb at least 0.5m to log (reduced for better detection)

## Climb state (for sustained jumping over obstacles)
var is_climbing: bool = false
var climb_timer: float = 0.0
const CLIMB_DURATION: float = 3.0 # Increased to 3 seconds to clear obstacles

## Obstacle avoidance
var avoidance_raycast_distance: float = 15.0
var avoidance_force_strength: float = 2.0
var obstacle_check_angles: Array[float] = [-45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0]

## Physics cache
var hover_physics: Node = null
var input_controller: Node = null
var _components_cached: bool = false # Track if we already cached to prevent duplicate logs

func _ready() -> void:
	# Cache components (but drone might not be set yet if called from add_child)
	# Only attempt if drone is already set
	if drone:
		_cache_components()

	# Cache WorldGenerator reference
	world_generator = get_tree().root.find_child("WorldGenerator", true, false)

func _cache_components() -> void:
	"""Cache drone components - can be called multiple times safely"""
	if drone and not _components_cached:
		hover_physics = drone
		input_controller = drone.get_node_or_null("MotionController")
		if not input_controller:
			push_warning("[PathfindingAI] Warning: No MotionController found on drone")
		# Components cached successfully
		_components_cached = true

func _physics_process(delta: float) -> void:
	if not drone:
		return # Silently skip if not initialized yet

	# Ensure components are cached (only if not already cached)
	if not hover_physics:
		_cache_components()

	if not hover_physics:
		return # Still no components, skip this frame

	# Track Y position changes for REQUIREMENT 2 (climb logging)
	if last_y_position == 0.0:
		last_y_position = drone.global_position.y

	var y_change = drone.global_position.y - last_y_position
	if y_change >= climb_threshold:
		print("[AI:%s] CLIMBED %.1fm | Height: %.1f→%.1f" % [drone.name, y_change, last_y_position, drone.global_position.y])
		last_y_position = drone.global_position.y

	# Update climb timer
	if is_climbing:
		climb_timer -= delta
		if climb_timer <= 0.0:
			is_climbing = false
			print("[PathfindingAI] Climb duration complete, resuming normal navigation")

	# If currently climbing, FORCE upward movement and skip normal navigation
	if is_climbing:
		if hover_physics.has_method("set_ai_movement"):
			var move = Vector2(0.0, 1.0) # Full forward thrust
			var climb = 1.0 # Full upward thrust
			hover_physics.set_ai_movement(move, climb)
		return # Skip normal navigation while climbing

	# Determine target
	var nav_target: Vector3
	if patrol_mode and patrol_waypoints.size() > 0:
		nav_target = _get_current_patrol_waypoint()
	else:
		# Use waypoint navigation system for non-patrol movement
		nav_target = _get_current_navigation_waypoint()

	# Navigate toward target
	_navigate_to(nav_target, delta)

## PATROL WAYPOINT SYSTEM
func _get_current_patrol_waypoint() -> Vector3:
	if patrol_waypoints.size() == 0:
		return drone.global_position

	# Get current waypoint
	var waypoint = patrol_waypoints[current_waypoint_index]

	# Check if reached
	var distance = drone.global_position.distance_to(waypoint)
	if distance < waypoint_reach_distance:
		# Move to next waypoint
		current_waypoint_index = (current_waypoint_index + 1) % patrol_waypoints.size()

	return waypoint

## NAVIGATION WAYPOINT SYSTEM (for non-patrol movement)
func _get_current_navigation_waypoint() -> Vector3:
	# If no waypoints generated yet, or if waypoints are for a different target, regenerate
	if navigation_waypoints.is_empty() or _should_regenerate_waypoints():
		_generate_navigation_waypoints()

	# If still no waypoints (target is very close), just go directly
	if navigation_waypoints.is_empty():
		return target_position

	# Get current waypoint
	var waypoint: Vector3 = navigation_waypoints[current_nav_waypoint_index]

	# Check if reached
	var distance: float = drone.global_position.distance_to(waypoint)
	if distance < NAV_WAYPOINT_REACH_DISTANCE:
		# Move to next waypoint
		current_nav_waypoint_index += 1

		# Check if reached final destination
		if current_nav_waypoint_index >= navigation_waypoints.size():
			# Stay at last waypoint (final destination)
			current_nav_waypoint_index = navigation_waypoints.size() - 1
			return waypoint
		else:
			waypoint = navigation_waypoints[current_nav_waypoint_index]
			# No logging for waypoint progression - reduces spam

	return waypoint

## Check if waypoints need to be regenerated (target changed significantly)
func _should_regenerate_waypoints() -> bool:
	if navigation_waypoints.is_empty():
		return true

	# Check if final waypoint is close to current target
	var final_waypoint: Vector3 = navigation_waypoints[navigation_waypoints.size() - 1]
	var distance_to_target: float = final_waypoint.distance_to(target_position)

	# Regenerate if target moved more than 20m
	return distance_to_target > 20.0

## Generate waypoints from current position to target
func _generate_navigation_waypoints() -> void:
	if not drone:
		return

	navigation_waypoints.clear()
	current_nav_waypoint_index = 0

	var start: Vector3 = drone.global_position
	var end: Vector3 = target_position
	var total_distance: float = start.distance_to(end)

	# If target is close, just go directly
	if total_distance < WAYPOINT_SPACING:
		navigation_waypoints.append(end)
		# No logging for direct paths - reduces spam
		return

	# Generate intermediate waypoints
	var num_waypoints: int = int(ceil(total_distance / WAYPOINT_SPACING))
	var direction: Vector3 = (end - start).normalized()

	AIDebugLogger.log_status(AIDebugLogger.drone_entity(drone), "Pathfinding",
		"waypoints_generated", {
			"count": num_waypoints,
			"distance": total_distance
		}, 2.0)

	for i in range(num_waypoints):
		var distance: float = WAYPOINT_SPACING * (i + 1)
		if distance > total_distance:
			distance = total_distance

		var waypoint: Vector3 = start + direction * distance
		navigation_waypoints.append(waypoint)

## NAVIGATION
func _navigate_to(target: Vector3, delta: float) -> void:
	if not drone:
		return

	# Check horizontal distance only (ignore Y for arrival check)
	var to_target_2d = Vector2(target.x - drone.global_position.x, target.z - drone.global_position.z)

	const STOP_DISTANCE_SQ: float = 9.0 # Within 3m of target horizontally
	if to_target_2d.length_squared() < STOP_DISTANCE_SQ:
		# STOP the drone by sending zero movement commands
		if hover_physics and hover_physics.has_method("set_ai_movement"):
			hover_physics.set_ai_movement(Vector2.ZERO, 0.0)

			AIDebugLogger.log_status(AIDebugLogger.drone_entity(drone), "Pathfinding",
				"holding_at_target", {
					"distance": sqrt(to_target_2d.length_squared()),
					"target": target
				}, 3.0)
		return # Already at target

	# ALTITUDE MANAGEMENT - Maintain constant height above terrain
	const DESIRED_HEIGHT_ABOVE_TERRAIN: float = 15.0 # Cruise at 15m above terrain
	const MAX_HEIGHT_ABOVE_TERRAIN: float = 200.0 # Maximum 200m above terrain

	var vertical_input: float = 0.0
	var has_terrain_data: bool = world_generator and world_generator.has_method("get_terrain_height_at")

	if has_terrain_data:
		var terrain_height: float = _get_terrain_height_at(drone.global_position.x, drone.global_position.z)
		var height_above_terrain: float = drone.global_position.y - terrain_height

		if height_above_terrain > MAX_HEIGHT_ABOVE_TERRAIN:
			# FORCE immediate descent - override all navigation
			if hover_physics and hover_physics.has_method("set_ai_movement"):
				hover_physics.set_ai_movement(Vector2.ZERO, -1.0) # Full downward thrust
				if Engine.get_process_frames() % 180 == 0: # Log every 3 seconds
					print("[PathfindingAI:%s] ALTITUDE LIMIT! %.1fm above terrain (%.1fm absolute) - forcing descent" % [
						drone.name, height_above_terrain, drone.global_position.y
					])
			return # Skip normal navigation
		elif height_above_terrain < DESIRED_HEIGHT_ABOVE_TERRAIN - 2.0:
			# Too low - climb gently
			vertical_input = 0.5
		elif height_above_terrain > DESIRED_HEIGHT_ABOVE_TERRAIN + 2.0:
			# Too high - descend gently
			vertical_input = -0.5
		else:
			# Within acceptable range - maintain altitude
			vertical_input = 0.0
	else:
		# If terrain data is unavailable, keep current altitude to avoid runaway climb/descent.
		vertical_input = 0.0

	# Get desired HORIZONTAL direction only (ignore Y component from waypoint)
	var to_target_3d = target - drone.global_position
	var desired_direction = Vector3(to_target_3d.x, 0.0, to_target_3d.z).normalized()

	# Apply obstacle avoidance (horizontal only)
	var avoidance_direction = _calculate_avoidance(desired_direction)
	var steering = desired_direction + (avoidance_direction * 0.35)
	var final_direction = desired_direction
	if steering.length_squared() > 0.001:
		final_direction = steering.normalized()

	# Rotate drone to face movement direction FIRST (horizontal only for rotation)
	# SKIP rotation if CombatAI has line of sight (it will handle aiming)
	if not combat_mode_los:
		# Extract horizontal component for rotation (yaw only)
		var horizontal_direction = Vector3(final_direction.x, 0.0, final_direction.z)
		if horizontal_direction.length_squared() > 0.01:
			_rotate_toward(horizontal_direction, delta)

	# Calculate movement input for hover physics
	# Convert world direction to local drone space AFTER rotation is commanded
	var local_direction = drone.global_transform.basis.inverse() * final_direction

	# Apply to drone's movement with terrain-relative altitude
	_apply_movement_input_with_altitude(local_direction, vertical_input)

## OBSTACLE AVOIDANCE
func _calculate_avoidance(desired_direction: Vector3) -> Vector3:
	if not drone:
		return Vector3.ZERO

	var avoidance = Vector3.ZERO
	var space_state = drone.get_world_3d().direct_space_state
	var avoidance_exclusions: Array = _get_avoidance_exclusions()

	# Cast rays in multiple directions to detect obstacles
	for angle_deg in obstacle_check_angles:
		var angle_rad = deg_to_rad(angle_deg)

		# Rotate desired direction by angle
		var check_direction = desired_direction.rotated(Vector3.UP, angle_rad)

		# Raycast
		var ray_origin = drone.global_position
		var ray_target = ray_origin + check_direction * avoidance_raycast_distance

		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
		query.exclude = avoidance_exclusions
		# Only check layer 1 (world/terrain) for obstacle avoidance
		# This avoids terrain but allows drones to navigate to resource nodes
		query.collision_mask = 1  # Only check layer 1 (world terrain)

		var result = space_state.intersect_ray(query)

		if result:
			# Obstacle detected, push away
			var obstacle_distance = ray_origin.distance_to(result.position)
			var avoidance_strength = 1.0 - (obstacle_distance / avoidance_raycast_distance)

			# Push away from obstacle normal
			if result.has("normal"):
				var horizontal_normal: Vector3 = result.normal
				horizontal_normal.y = 0.0

				# Ignore floor/ceiling normals for horizontal steering.
				if horizontal_normal.length_squared() > 0.001:
					avoidance += horizontal_normal.normalized() * avoidance_strength * avoidance_force_strength

	# Keep avoidance from overwhelming desired movement direction.
	if avoidance.length_squared() > 1.0:
		avoidance = avoidance.normalized()

	return avoidance

func _get_avoidance_exclusions() -> Array:
	# Ignore ourselves and squadmates so formation movement does not self-repel.
	var exclusions: Array = [drone]
	var orchestrator: Node = get_parent()
	if orchestrator and "parent_squad" in orchestrator:
		var squad = orchestrator.parent_squad
		if squad and "drones" in squad:
			for squad_drone in squad.drones:
				if is_instance_valid(squad_drone) and squad_drone != drone:
					exclusions.append(squad_drone)
	return exclusions

## MOVEMENT APPLICATION
func _apply_movement_input(local_direction: Vector3) -> void:
	if not hover_physics:
		return

	# Map direction to input values
	# local_direction.x = strafe (right positive)
	# local_direction.z = forward (backward positive in Godot)
	# local_direction.y = vertical (up positive)

	var forward = - local_direction.z * speed_fraction # Forward
	var strafe = local_direction.x * speed_fraction # Strafe
	var vertical = local_direction.y * speed_fraction # Vertical movement to reach waypoint Y

	# Apply to hover physics through its AI control interface
	if hover_physics.has_method("set_ai_movement"):
		# Use the existing hover physics AI interface
		var move = Vector2(strafe, forward)
		hover_physics.set_ai_movement(move, vertical)

## MOVEMENT APPLICATION WITH SEPARATE ALTITUDE CONTROL
func _apply_movement_input_with_altitude(local_direction: Vector3, vertical_input: float) -> void:
	if not hover_physics:
		return

	# Map direction to input values (horizontal only)
	var forward = - local_direction.z * speed_fraction # Forward
	var strafe = local_direction.x * speed_fraction # Strafe
	var vertical = vertical_input # Use terrain-relative altitude control

	# Apply to hover physics through its AI control interface
	if hover_physics.has_method("set_ai_movement"):
		var move = Vector2(strafe, forward)
		hover_physics.set_ai_movement(move, vertical)


## ROTATION
func _rotate_toward(target_direction: Vector3, delta: float) -> void:
	if not drone or target_direction.length_squared() < 0.01:
		return

	# Calculate target position to look at
	var look_target = drone.global_position + target_direction.normalized() * 100.0

	# Send to input controller if available
	if input_controller and input_controller.has_method("set_ai_look_target"):
		input_controller.set_ai_look_target(look_target)

## JUMP/CLIMB OBSTACLES
func try_jump_obstacle() -> bool:
	"""
	Initiate sustained climb maneuver (NOT a jump - this is continuous upward thrust)
	Used when AI needs to gain altitude to clear obstacles or obtain line of sight
	Returns true if climb was initiated
	"""
	if not hover_physics or not is_instance_valid(hover_physics):
		return false

	# Check if already climbing
	if is_climbing:
		return false # Already climbing, don't restart

	# Calculate energy required to climb to target height
	var energy_system = drone.get_node_or_null("EnergySystem") if drone else null
	if energy_system and is_instance_valid(energy_system):
		# Estimate height difference to target
		var height_diff = target_position.y - drone.global_position.y if target_position.y > drone.global_position.y else 0.0

		# Calculate energy needed:
		# climb_cost_per_second * time_needed
		# time_needed ≈ height_diff / estimated_climb_speed (rough estimate: 5 m/s climb rate)
		var estimated_climb_speed = 5.0 # m/s
		var time_needed = height_diff / estimated_climb_speed if height_diff > 0 else CLIMB_DURATION
		const FLY_UP_COST_PER_SEC = 15.0 # From EnergySystem.FLY_UP_ENERGY_COST_PER_SECOND
		var energy_needed = FLY_UP_COST_PER_SEC * time_needed

		# Check if we have enough energy
		if energy_system.current_energy < energy_needed:
			print("[AI:%s] CLIMB CANCELLED - Need %.0fm climb (%.1fs), requires %.0f energy, have %.0f" % [
				drone.name,
				height_diff,
				time_needed,
				energy_needed,
				energy_system.current_energy
			])
			return false

		# Check minimum energy threshold (need some buffer beyond the calculated need)
		var energy_buffer = energy_needed * 1.5 # 50% buffer on top of calculated need
		if energy_system.current_energy < energy_buffer:
			print("[AI:%s] CLIMB CANCELLED - Energy too low: have %.0f, need %.0f (calc: %.0f + 50%% buffer)" % [
				drone.name,
				energy_system.current_energy,
				energy_buffer,
				energy_needed
			])
			return false

		print("[AI:%s] CLIMB INITIATED - Target height: +%.0fm | Energy: %.0f/%.0f (%.0f%% cost)" % [
			drone.name,
			height_diff,
			energy_system.current_energy,
			energy_needed,
			(energy_needed / energy_system.current_energy) * 100.0
		])

	# Initiate sustained climb (continuous upward thrust, NOT a jump)
	is_climbing = true
	climb_timer = CLIMB_DURATION
	return true

## PUBLIC API
func set_target(new_target: Vector3, force_regenerate: bool = false) -> void:
	var target_changed_significantly: bool = target_position.distance_to(new_target) > 5.0
	target_position = new_target
	patrol_mode = false

	if force_regenerate or target_changed_significantly:
		navigation_waypoints.clear()
		current_nav_waypoint_index = 0

func clear_target() -> void:
	# Stop active navigation and hold current position.
	target_position = drone.global_position if drone else Vector3.ZERO
	patrol_mode = false
	navigation_waypoints.clear()
	current_nav_waypoint_index = 0

	if hover_physics and hover_physics.has_method("set_ai_movement"):
		hover_physics.set_ai_movement(Vector2.ZERO, 0.0)

func start_patrol() -> void:
	patrol_mode = true
	navigation_waypoints.clear()
	current_nav_waypoint_index = 0

func set_speed_fraction(fraction: float) -> void:
	speed_fraction = clamp(fraction, 0.0, 1.0)

## Get terrain height at position
func _get_terrain_height_at(x: float, z: float) -> float:
	return world_generator.get_terrain_height_at(x, z)
