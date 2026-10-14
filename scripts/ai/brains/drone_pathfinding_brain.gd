class_name DronePathfindingBrain extends RefCounted
## Pure logic for pathfinding decisions - 100% testable with NO Godot dependencies
##
## This class makes all pathfinding decisions based on input parameters.
## It has no awareness of Godot types, nodes, or scenes.

# Configuration
var waypoint_reached_threshold: float = 5.0
var desired_height_above_terrain: float = 15.0
var max_height_above_terrain: float = 200.0
var obstacle_avoidance_distance: float = 30.0
var slow_down_distance: float = 15.0  # Start slowing when this close to waypoint

## Check if close enough to waypoint to consider it reached
func has_reached_waypoint(distance_to_waypoint: float) -> bool:
	return distance_to_waypoint < waypoint_reached_threshold

## Calculate movement direction toward waypoint
func calculate_movement_to_waypoint(to_waypoint: Vector3) -> Vector2:
	var dir_xz = Vector2(to_waypoint.x, to_waypoint.z)
	if dir_xz.length() > 0:
		return dir_xz.normalized()
	return Vector2.ZERO

## Calculate climb rate for altitude management
func calculate_climb_rate(
	current_height: float,
	terrain_height: float,
	waypoint_height: float
) -> float:

	var height_above_terrain = current_height - terrain_height
	var target_height = terrain_height + desired_height_above_terrain

	# Force descent if too high above terrain
	if height_above_terrain > max_height_above_terrain:
		return -1.0

	# Calculate climb toward target height
	var height_error = target_height - current_height

	# Clamp to [-1, 1] and scale
	var climb_rate = clampf(height_error / 10.0, -1.0, 1.0)

	return climb_rate

## Calculate obstacle avoidance direction
## @param obstacles: Array of directions to obstacles (not normalized)
## @param desired_direction: Where we want to go
## @return Adjusted direction avoiding obstacles
func calculate_obstacle_avoidance(
	obstacles: Array,  # Array of Vector3
	desired_direction: Vector2
) -> Vector2:

	if obstacles.is_empty():
		return desired_direction

	# Calculate avoidance force
	var avoidance = Vector2.ZERO
	for obstacle_dir in obstacles:
		if obstacle_dir is Vector3:
			var obs_xz = Vector2(obstacle_dir.x, obstacle_dir.z)
			if obs_xz.length() > 0:
				obs_xz = obs_xz.normalized()
				# Push away from obstacle (weighted by inverse distance)
				avoidance -= obs_xz

	if avoidance.length() > 0:
		avoidance = avoidance.normalized()

	# Combine desired direction with avoidance
	# Weight: 70% desired, 30% avoidance
	var final_dir = (desired_direction * 0.7) + (avoidance * 0.3)

	if final_dir.length() > 0:
		return final_dir.normalized()

	return desired_direction

## Calculate speed fraction based on context
func calculate_speed_fraction(
	distance_to_waypoint: float,
	has_obstacles: bool
) -> float:

	# Slow down near waypoint for precision
	if distance_to_waypoint < slow_down_distance:
		var fraction = distance_to_waypoint / slow_down_distance
		return maxf(fraction, 0.3)  # Minimum 30% speed

	# Slow down if obstacles detected
	if has_obstacles:
		return 0.6

	# Full speed otherwise
	return 1.0

## Should generate new waypoint? (waypoint spacing logic)
func should_generate_next_waypoint(
	distance_to_waypoint: float,
	waypoint_spacing: float
) -> bool:
	# Generate next waypoint when we're close to current one
	return distance_to_waypoint < waypoint_spacing * 0.5

## Calculate waypoint height based on terrain
func calculate_waypoint_height(terrain_height: float) -> float:
	return terrain_height + desired_height_above_terrain
