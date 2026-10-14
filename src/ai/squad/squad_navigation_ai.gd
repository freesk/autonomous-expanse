extends Node
class_name SquadNavigationSystem

## SquadNavigationSystem - Handles squad movement and pathfinding
## Responsible for:
## - 3D waypoint generation for pathfinding
## - Terrain bypass navigation
## - Squad formation at waypoints
## - Commanding individual drone PathfindingAI
## - Speed control (normal/flee)

var squad: Node3D # Reference to parent DroneSquad
var world_generator: Node = null

const CRUISING_HEIGHT_ABOVE_TERRAIN: float = 3.0 # Reduced from 70m - more reasonable cruising altitude
const WAYPOINT_SPACING: float = 50.0 # Generate waypoints every N meters
const FORMATION_SPACING: float = 10.0 # Drones maintain 10m spacing in formation

# Waypoint navigation state
var waypoints: Array[Vector3] = []
var current_waypoint_index: int = 0
var final_destination: Vector3 = Vector3.ZERO
var is_navigating: bool = false
var waypoint_commanded: bool = false # Track if current waypoint was already commanded
var flee_mode: bool = false # When fleeing, everyone goes full throttle (no cohesion)


func _ready() -> void:
	squad = get_parent()
	# Cache world generator reference
	world_generator = get_tree().root.find_child("WorldGenerator", true, false)


func _entity() -> String:
	## Logging identity for this squad
	if squad and is_instance_valid(squad) and "squad_id" in squad:
		return AIDebugLogger.squad_entity(squad.squad_id)
	return "squad:?"


func _process(delta: float) -> void:
	if not is_navigating or waypoints.is_empty():
		return

	# Calculate distance to current waypoint
	var distance: float = squad.global_position.distance_to(waypoints[current_waypoint_index])

	# Debug: Log navigation progress (throttled by the logger)
	AIDebugLogger.log_status(_entity(), "SquadNav", "waypoint_progress", {
		"waypoint": "%d/%d" % [current_waypoint_index + 1, waypoints.size()],
		"distance": distance
	}, 3.0)

	# Check if reached current waypoint
	if _reached_waypoint(waypoints[current_waypoint_index]):
		current_waypoint_index += 1
		waypoint_commanded = false # Reset flag for next waypoint

		# Check if reached final destination
		if current_waypoint_index >= waypoints.size():
			AIDebugLogger.log_decision(_entity(), "SquadNav",
				"destination_reached", "final_waypoint_reached")
			is_navigating = false
			waypoints.clear()
			current_waypoint_index = 0
			waypoint_commanded = false
			return

		# Move to next waypoint - command ONCE
		_navigate_to_current_waypoint()
		waypoint_commanded = true


## Navigate squad to target position using waypoint system
func navigate_to(target_pos: Vector3, is_fleeing: bool = false) -> void:
	if not squad or not squad.drones:
		return

	# RACE CONDITION FIX: Don't regenerate waypoints if already navigating to same destination
	if is_navigating and final_destination.distance_to(target_pos) < 5.0:
		# Already navigating to this destination, skip
		return

	# Generate waypoints for the path
	final_destination = target_pos
	waypoints = _generate_waypoints(squad.global_position, target_pos)
	current_waypoint_index = 0
	is_navigating = true
	waypoint_commanded = false
	flee_mode = is_fleeing

	# Start navigating to first waypoint - command ONCE
	if not waypoints.is_empty():
		_navigate_to_current_waypoint()
		waypoint_commanded = true # Mark as commanded


## Generate waypoints from start to end, bypassing obstacles (motherships, terrain)
func _generate_waypoints(start: Vector3, end: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []

	# Calculate total distance
	var direction: Vector3 = end - start
	var total_distance: float = direction.length()

	# If destination is very close, just use direct path
	if total_distance <= WAYPOINT_SPACING:
		var waypoint := _calculate_terrain_relative_position(end)
		path.append(waypoint)
		AIDebugLogger.log_decision(_entity(), "SquadNav", "path_planned",
			"destination_close_direct_path", {"distance": total_distance})
		return path

	direction = direction.normalized()

	# Check if path is blocked by obstacles (motherships, terrain)
	var obstacle_hit = _raycast_for_obstacle(start, end)

	if obstacle_hit:
		# Path is blocked - generate detour waypoints around obstacle
		AIDebugLogger.log_decision(_entity(), "SquadNav", "path_planned",
			"obstacle_ahead_taking_detour", {
				"obstacle_distance": start.distance_to(obstacle_hit.position)
			})

		# Generate detour around obstacle
		var detour_waypoints = _generate_detour_path(start, end, obstacle_hit)
		path.append_array(detour_waypoints)
	else:
		# No obstacles - generate straight-line waypoints
		var num_waypoints: int = ceili(total_distance / WAYPOINT_SPACING)

		AIDebugLogger.log_decision(_entity(), "SquadNav", "path_planned",
			"clear_path_straight_line", {
				"waypoints": num_waypoints,
				"distance": total_distance
			})

		# Calculate Y coordinates for start and end positions
		var start_y: float = _get_terrain_height_at(start.x, start.z) + CRUISING_HEIGHT_ABOVE_TERRAIN
		var end_y: float = _get_terrain_height_at(end.x, end.z) + CRUISING_HEIGHT_ABOVE_TERRAIN

		for i in range(1, num_waypoints + 1):
			var t: float = float(i) / float(num_waypoints)
			var distance: float = min(float(i) * WAYPOINT_SPACING, total_distance)
			var waypoint_pos: Vector3 = start + direction * distance

			# Smoothly interpolate Y altitude
			var interpolated_y: float = lerp(start_y, end_y, t)
			var waypoint := Vector3(waypoint_pos.x, interpolated_y, waypoint_pos.z)
			path.append(waypoint)

	return path


## Raycast from start to end to detect obstacles (motherships, terrain)
func _raycast_for_obstacle(start: Vector3, end: Vector3) -> Dictionary:
	var space_state = squad.get_world_3d().direct_space_state
	if not space_state:
		return {}

	var query = PhysicsRayQueryParameters3D.create(start, end)
	query.collision_mask = 1 # Layer 1: terrain and motherships
	query.exclude = [] # Don't exclude anything

	var result = space_state.intersect_ray(query)
	return result


## Generate detour path around an obstacle
func _generate_detour_path(start: Vector3, end: Vector3, obstacle_hit: Dictionary) -> Array[Vector3]:
	var path: Array[Vector3] = []

	# Calculate detour point perpendicular to obstacle
	var to_obstacle: Vector3 = obstacle_hit.position - start
	var obstacle_distance: float = to_obstacle.length()

	# Get perpendicular direction (rotate 90 degrees on XZ plane)
	var perpendicular: Vector3 = Vector3(-to_obstacle.z, 0, to_obstacle.x).normalized()

	# Detour distance: 100m perpendicular + obstacle avoidance margin
	const DETOUR_DISTANCE: float = 100.0
	const OBSTACLE_CLEARANCE: float = 50.0 # Stay 50m away from obstacle

	# Try detour to the right first
	var detour_point: Vector3 = obstacle_hit.position + (perpendicular * DETOUR_DISTANCE)
	var detour_height: float = _get_terrain_height_at(detour_point.x, detour_point.z) + CRUISING_HEIGHT_ABOVE_TERRAIN
	detour_point.y = detour_height

	# Check if right detour is blocked
	var right_blocked = _raycast_for_obstacle(start, detour_point)
	if right_blocked:
		# Try left detour instead
		detour_point = obstacle_hit.position + (-perpendicular * DETOUR_DISTANCE)
		detour_height = _get_terrain_height_at(detour_point.x, detour_point.z) + CRUISING_HEIGHT_ABOVE_TERRAIN
		detour_point.y = detour_height

		AIDebugLogger.log_decision(_entity(), "SquadNav", "detour_side_switch",
			"right_detour_blocked_trying_left")

	# Generate waypoints: start -> detour_point -> end
	# Waypoints from start to detour
	var to_detour: Vector3 = detour_point - start
	var detour_dist: float = to_detour.length()
	var detour_waypoints: int = max(1, ceili(detour_dist / WAYPOINT_SPACING))

	var start_y: float = _get_terrain_height_at(start.x, start.z) + CRUISING_HEIGHT_ABOVE_TERRAIN

	for i in range(1, detour_waypoints + 1):
		var t: float = float(i) / float(detour_waypoints)
		var wp: Vector3 = start.lerp(detour_point, t)
		var wp_height: float = _get_terrain_height_at(wp.x, wp.z) + CRUISING_HEIGHT_ABOVE_TERRAIN
		wp.y = wp_height
		path.append(wp)

	# Waypoints from detour to end
	var from_detour: Vector3 = end - detour_point
	var final_dist: float = from_detour.length()
	var final_waypoints: int = max(1, ceili(final_dist / WAYPOINT_SPACING))

	var end_y: float = _get_terrain_height_at(end.x, end.z) + CRUISING_HEIGHT_ABOVE_TERRAIN

	for i in range(1, final_waypoints + 1):
		var t: float = float(i) / float(final_waypoints)
		var wp: Vector3 = detour_point.lerp(end, t)
		var wp_height: float = _get_terrain_height_at(wp.x, wp.z) + CRUISING_HEIGHT_ABOVE_TERRAIN
		wp.y = wp_height
		path.append(wp)

	AIDebugLogger.log_decision(_entity(), "SquadNav", "detour_generated",
		"routing_around_obstacle", {
			"waypoints": path.size(),
			"via": detour_point
		})

	return path


## Calculate terrain-relative position using vertical raycasting
func _calculate_terrain_relative_position(pos: Vector3) -> Vector3:
	var terrain_height: float = _get_terrain_height_at(pos.x, pos.z)
	return Vector3(pos.x, terrain_height + CRUISING_HEIGHT_ABOVE_TERRAIN, pos.z)


## Navigate to current waypoint with formation
func _navigate_to_current_waypoint() -> void:
	if current_waypoint_index >= waypoints.size():
		return

	var waypoint: Vector3 = waypoints[current_waypoint_index]

	# CRITICAL: Squad moves at the ACTUAL speed of its slowest drone. Drones
	# have different physics, so each one gets its own throttle fraction that
	# lands it on the shared cruise speed. Fleeing squads skip cohesion.
	var max_speeds: Array = _collect_drone_max_speeds()
	var cruise_speed: float = SquadCohesionBrain.squad_cruise_speed(max_speeds)

	AIDebugLogger.log_decision(_entity(), "SquadNav", "waypoint_advance",
		"flee_full_throttle" if flee_mode else "previous_waypoint_reached", {
			"waypoint": "%d/%d" % [current_waypoint_index + 1, waypoints.size()],
			"position": waypoint,
			"cruise_speed": cruise_speed
		})

	# Calculate formation positions for all squad members around waypoint
	for i in range(squad.drones.size()):
		var drone: Node3D = squad.drones[i]
		if not is_instance_valid(drone):
			continue

		var orchestrator = drone.get_node_or_null("OrchestratorAI")
		if not orchestrator:
			continue

		# Calculate circular formation position around waypoint
		var formation_offset: Vector3 = _calculate_formation_offset(i, squad.drones.size())
		var drone_target: Vector3 = waypoint + formation_offset

		# Set target and let drone use its own waypoint generation for efficient pathfinding
		var pathfinding = orchestrator.pathfinding_ai
		if pathfinding:
			# Use the drone's built-in set_target which handles waypoint generation
			# The drone will generate its own intermediate waypoints every 100m
			pathfinding.set_target(drone_target)
			if flee_mode:
				pathfinding.set_speed_fraction(1.0)
			else:
				pathfinding.set_speed_fraction(
					SquadCohesionBrain.speed_fraction_for(max_speeds[i], cruise_speed))


## Check if squad reached current waypoint (horizontal distance only - ignore Y)
## CRITICAL: Waypoint is only reached when ALL alive drones reach their formation positions
func _reached_waypoint(waypoint: Vector3, threshold: float = 25.0) -> bool:
	if not squad or not squad.drones:
		return false

	# Count how many drones are within threshold of their formation positions
	var drones_at_waypoint: int = 0
	var valid_drones: int = 0

	for i in range(squad.drones.size()):
		var drone = squad.drones[i]
		if not is_instance_valid(drone):
			continue
		valid_drones += 1

		# Calculate this drone's formation position around the waypoint
		var formation_offset: Vector3 = _calculate_formation_offset(i, squad.drones.size())
		var drone_target: Vector3 = waypoint + formation_offset

		# Check horizontal (XZ) distance to formation position - drones may be at different altitudes
		var drone_pos_2d := Vector2(drone.global_position.x, drone.global_position.z)
		var target_2d := Vector2(drone_target.x, drone_target.z)

		if drone_pos_2d.distance_to(target_2d) < threshold:
			drones_at_waypoint += 1

	# CRITICAL FIX: ALL alive drones must reach waypoint before squad can advance
	if valid_drones == 0:
		return false

	return drones_at_waypoint == valid_drones


## Check if squad reached destination (public API)
## CRITICAL: ALL alive drones must reach their formation positions around the target
func reached_destination(target_pos: Vector3, threshold: float = 20.0) -> bool:
	if not squad or not squad.drones:
		return false

	# Count how many drones are within threshold of their formation positions
	var drones_at_destination: int = 0
	var valid_drones: int = 0

	for i in range(squad.drones.size()):
		var drone: Node3D = squad.drones[i]
		if not is_instance_valid(drone):
			continue
		valid_drones += 1

		# Calculate this drone's formation position around the target
		var formation_offset: Vector3 = _calculate_formation_offset(i, squad.drones.size())
		var drone_target: Vector3 = target_pos + formation_offset

		# Check horizontal (XZ) distance only
		var drone_pos_2d := Vector2(drone.global_position.x, drone.global_position.z)
		var target_2d := Vector2(drone_target.x, drone_target.z)

		if drone_pos_2d.distance_to(target_2d) < threshold:
			drones_at_destination += 1

	# ALL alive drones must reach destination
	if valid_drones == 0:
		return false

	return drones_at_destination == valid_drones


## Get terrain height at position
func _get_terrain_height_at(x: float, z: float) -> float:
	return world_generator.get_terrain_height_at(x, z)


## Max horizontal speed of every squad member, index-aligned with squad.drones.
## Invalid drones or drones without readable physics get 0.0 (= unknown).
func _collect_drone_max_speeds() -> Array:
	var max_speeds: Array = []
	if not squad or not squad.drones:
		return max_speeds

	for drone in squad.drones:
		var max_speed: float = 0.0
		if is_instance_valid(drone):
			var motion_system = drone.get_node_or_null("MotionSystem")
			if motion_system and motion_system.has_method("get_max_horizontal_speed"):
				max_speed = motion_system.get_max_horizontal_speed()
		max_speeds.append(max_speed)

	return max_speeds


## Calculate formation offset for drone at index
func _calculate_formation_offset(drone_index: int, total_drones: int) -> Vector3:
	if total_drones <= 1:
		return Vector3.ZERO

	# Use the class-level FORMATION_SPACING constant (line 17)
	var angle_step: float = TAU / float(total_drones)
	var angle: float = angle_step * float(drone_index)

	return Vector3(
		cos(angle) * FORMATION_SPACING,
		0.0,
		sin(angle) * FORMATION_SPACING
	)
