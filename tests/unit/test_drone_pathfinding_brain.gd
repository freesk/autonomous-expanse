extends GutTest
## Unit tests for DronePathfindingBrain - pure logic, NO Godot dependencies
##
## These tests verify every function in DronePathfindingBrain with 100% coverage

const DronePathfindingBrain = preload("res://scripts/ai/brains/drone_pathfinding_brain.gd")

var brain: DronePathfindingBrain

func before_each():
	brain = DronePathfindingBrain.new()
	# Verify default configuration
	assert_eq(brain.waypoint_reached_threshold, 5.0, "Default waypoint threshold should be 5")
	assert_eq(brain.desired_height_above_terrain, 15.0, "Default desired height should be 15")
	assert_eq(brain.max_height_above_terrain, 200.0, "Default max height should be 200")

# ===== has_reached_waypoint tests =====

func test_has_reached_waypoint_true_when_within_threshold():
	# Arrange
	var distance = 3.0  # Within threshold (5.0)

	# Act
	var reached = brain.has_reached_waypoint(distance)

	# Assert
	assert_true(reached, "Should have reached waypoint when within threshold")

func test_has_reached_waypoint_false_when_beyond_threshold():
	# Arrange
	var distance = 10.0  # Beyond threshold

	# Act
	var reached = brain.has_reached_waypoint(distance)

	# Assert
	assert_false(reached, "Should not have reached waypoint when beyond threshold")

func test_has_reached_waypoint_at_threshold_boundary():
	# Arrange
	var distance = 5.0  # Exactly at threshold

	# Act
	var reached = brain.has_reached_waypoint(distance)

	# Assert
	assert_false(reached, "Should not be reached when exactly at threshold (not within)")

func test_has_reached_waypoint_with_zero_distance():
	# Arrange
	var distance = 0.0  # Edge case: exactly at waypoint

	# Act
	var reached = brain.has_reached_waypoint(distance)

	# Assert
	assert_true(reached, "Should be reached when distance is zero")

# ===== calculate_movement_to_waypoint tests =====

func test_calculate_movement_to_waypoint_normalizes_direction():
	# Arrange
	var to_waypoint = Vector3(10, 5, 8)  # Y component should be ignored

	# Act
	var movement = brain.calculate_movement_to_waypoint(to_waypoint)

	# Assert
	var expected = Vector2(10, 8).normalized()
	assert_almost_eq(movement.x, expected.x, 0.01, "Movement X should match normalized XZ")
	assert_almost_eq(movement.y, expected.y, 0.01, "Movement Y should match normalized XZ")
	assert_almost_eq(movement.length(), 1.0, 0.01, "Movement should be normalized")

func test_calculate_movement_to_waypoint_with_negative_coords():
	# Arrange
	var to_waypoint = Vector3(-5, 0, -3)

	# Act
	var movement = brain.calculate_movement_to_waypoint(to_waypoint)

	# Assert
	var expected = Vector2(-5, -3).normalized()
	assert_almost_eq(movement.x, expected.x, 0.01, "Should handle negative X")
	assert_almost_eq(movement.y, expected.y, 0.01, "Should handle negative Z")

func test_calculate_movement_to_waypoint_with_zero_xz():
	# Arrange
	var to_waypoint = Vector3(0, 100, 0)  # Only Y component

	# Act
	var movement = brain.calculate_movement_to_waypoint(to_waypoint)

	# Assert
	assert_eq(movement, Vector2.ZERO, "Should return zero when no XZ component")

# ===== calculate_climb_rate tests =====

func test_calculate_climb_rate_ascends_when_below_target():
	# Arrange
	var current_height = 10.0
	var terrain_height = 0.0
	var waypoint_height = 20.0

	# Act
	var climb = brain.calculate_climb_rate(current_height, terrain_height, waypoint_height)

	# Assert
	# Target = terrain (0) + desired (15) = 15
	# Error = 15 - 10 = 5
	# Climb = 5 / 10 = 0.5
	assert_almost_eq(climb, 0.5, 0.01, "Should ascend when below target height")

func test_calculate_climb_rate_descends_when_above_target():
	# Arrange
	var current_height = 25.0
	var terrain_height = 0.0
	var waypoint_height = 20.0

	# Act
	var climb = brain.calculate_climb_rate(current_height, terrain_height, waypoint_height)

	# Assert
	# Target = terrain (0) + desired (15) = 15
	# Error = 15 - 25 = -10
	# Climb = -10 / 10 = -1.0
	assert_almost_eq(climb, -1.0, 0.01, "Should descend when above target height")

func test_calculate_climb_rate_forces_descent_when_too_high():
	# Arrange
	var current_height = 250.0  # Way above max (200)
	var terrain_height = 0.0
	var waypoint_height = 20.0

	# Act
	var climb = brain.calculate_climb_rate(current_height, terrain_height, waypoint_height)

	# Assert
	assert_eq(climb, -1.0, "Should force full descent when above max height")

func test_calculate_climb_rate_clamps_to_range():
	# Arrange
	var current_height = 0.0
	var terrain_height = 0.0
	var waypoint_height = 500.0  # Would result in climb > 1.0

	# Act
	var climb = brain.calculate_climb_rate(current_height, terrain_height, waypoint_height)

	# Assert
	assert_lte(climb, 1.0, "Climb rate should be clamped to 1.0")
	assert_gte(climb, -1.0, "Climb rate should be clamped to -1.0")

func test_calculate_climb_rate_accounts_for_terrain_height():
	# Arrange
	var current_height = 105.0
	var terrain_height = 100.0  # Elevated terrain
	var waypoint_height = 120.0

	# Act
	var climb = brain.calculate_climb_rate(current_height, terrain_height, waypoint_height)

	# Assert
	# Target = terrain (100) + desired (15) = 115
	# Current height above terrain = 105 - 100 = 5 (within limits)
	# Error = 115 - 105 = 10
	# Climb = 10 / 10 = 1.0
	assert_almost_eq(climb, 1.0, 0.01, "Should account for terrain elevation")

# ===== calculate_obstacle_avoidance tests =====

func test_calculate_obstacle_avoidance_no_obstacles_returns_desired():
	# Arrange
	var obstacles = []
	var desired_direction = Vector2(1, 0)

	# Act
	var result = brain.calculate_obstacle_avoidance(obstacles, desired_direction)

	# Assert
	assert_eq(result, desired_direction, "Should return desired direction when no obstacles")

func test_calculate_obstacle_avoidance_pushes_away_from_obstacle():
	# Arrange
	var obstacles = [Vector3(1, 0, 0)]  # Obstacle to the right
	var desired_direction = Vector2(0, 1)  # Want to go forward (perpendicular to obstacle)

	# Act
	var result = brain.calculate_obstacle_avoidance(obstacles, desired_direction)

	# Assert
	assert_gt(result.length(), 0.0, "Should produce movement")
	assert_almost_eq(result.length(), 1.0, 0.01, "Result should be normalized")
	# Result should be pushed away from obstacle (to the left)
	# Since obstacle is at (1,0) and desired is (0,1), avoidance is (-1,0)
	# Result = 0.7*(0,1) + 0.3*(-1,0) = (-0.3, 0.7)
	assert_lt(result.x, 0.0, "Should be pushed left (negative X) away from right obstacle")

func test_calculate_obstacle_avoidance_combines_desired_and_avoidance():
	# Arrange
	var obstacles = [Vector3(0, 0, 1)]  # Obstacle forward
	var desired_direction = Vector2(1, 0)  # Want to go right

	# Act
	var result = brain.calculate_obstacle_avoidance(obstacles, desired_direction)

	# Assert
	# Result should be a combination: 70% desired + 30% avoidance
	assert_gt(result.length(), 0.0, "Should produce movement")
	assert_almost_eq(result.length(), 1.0, 0.01, "Result should be normalized")

func test_calculate_obstacle_avoidance_with_multiple_obstacles():
	# Arrange
	var obstacles = [
		Vector3(1, 0, 0),   # Right
		Vector3(0, 0, 1),   # Forward
		Vector3(-1, 0, 0)   # Left
	]
	var desired_direction = Vector2(0, 1)  # Want to go forward

	# Act
	var result = brain.calculate_obstacle_avoidance(obstacles, desired_direction)

	# Assert
	assert_gt(result.length(), 0.0, "Should produce movement despite obstacles")
	assert_almost_eq(result.length(), 1.0, 0.01, "Result should be normalized")

# ===== calculate_speed_fraction tests =====

func test_calculate_speed_fraction_slows_near_waypoint():
	# Arrange
	var distance = 10.0  # Within slow_down_distance (15)
	var has_obstacles = false

	# Act
	var speed = brain.calculate_speed_fraction(distance, has_obstacles)

	# Assert
	# Fraction = 10 / 15 = 0.666...
	assert_almost_eq(speed, 0.666, 0.01, "Should slow down near waypoint")
	assert_gte(speed, 0.3, "Should not go below minimum speed")

func test_calculate_speed_fraction_minimum_speed_enforced():
	# Arrange
	var distance = 1.0  # Very close
	var has_obstacles = false

	# Act
	var speed = brain.calculate_speed_fraction(distance, has_obstacles)

	# Assert
	assert_almost_eq(speed, 0.3, 0.01, "Should enforce minimum 30% speed")

func test_calculate_speed_fraction_slows_for_obstacles():
	# Arrange
	var distance = 100.0  # Far from waypoint
	var has_obstacles = true

	# Act
	var speed = brain.calculate_speed_fraction(distance, has_obstacles)

	# Assert
	assert_eq(speed, 0.6, "Should slow to 60% when obstacles detected")

func test_calculate_speed_fraction_full_speed_when_clear():
	# Arrange
	var distance = 100.0  # Far from waypoint
	var has_obstacles = false

	# Act
	var speed = brain.calculate_speed_fraction(distance, has_obstacles)

	# Assert
	assert_eq(speed, 1.0, "Should be full speed when clear path and far from waypoint")

func test_calculate_speed_fraction_at_slow_down_boundary():
	# Arrange
	var distance = 15.0  # Exactly at slow_down_distance
	var has_obstacles = false

	# Act
	var speed = brain.calculate_speed_fraction(distance, has_obstacles)

	# Assert
	# At boundary: should return full speed (not within threshold)
	assert_eq(speed, 1.0, "Should be full speed when exactly at boundary")

# ===== should_generate_next_waypoint tests =====

func test_should_generate_next_waypoint_true_when_close():
	# Arrange
	var distance = 20.0
	var waypoint_spacing = 50.0  # Threshold = 25.0

	# Act
	var should_generate = brain.should_generate_next_waypoint(distance, waypoint_spacing)

	# Assert
	assert_true(should_generate, "Should generate next waypoint when close to current")

func test_should_generate_next_waypoint_false_when_far():
	# Arrange
	var distance = 40.0
	var waypoint_spacing = 50.0  # Threshold = 25.0

	# Act
	var should_generate = brain.should_generate_next_waypoint(distance, waypoint_spacing)

	# Assert
	assert_false(should_generate, "Should not generate next waypoint when still far")

func test_should_generate_next_waypoint_at_threshold():
	# Arrange
	var distance = 25.0
	var waypoint_spacing = 50.0  # Threshold = 25.0

	# Act
	var should_generate = brain.should_generate_next_waypoint(distance, waypoint_spacing)

	# Assert
	assert_false(should_generate, "Should not generate when exactly at threshold")

# ===== calculate_waypoint_height tests =====

func test_calculate_waypoint_height_adds_desired_height():
	# Arrange
	var terrain_height = 100.0

	# Act
	var waypoint_height = brain.calculate_waypoint_height(terrain_height)

	# Assert
	var expected = terrain_height + brain.desired_height_above_terrain
	assert_eq(waypoint_height, expected, "Should add desired height to terrain height")

func test_calculate_waypoint_height_with_negative_terrain():
	# Arrange
	var terrain_height = -50.0  # Below sea level

	# Act
	var waypoint_height = brain.calculate_waypoint_height(terrain_height)

	# Assert
	var expected = terrain_height + brain.desired_height_above_terrain
	assert_eq(waypoint_height, expected, "Should work with negative terrain heights")

func test_calculate_waypoint_height_with_zero_terrain():
	# Arrange
	var terrain_height = 0.0

	# Act
	var waypoint_height = brain.calculate_waypoint_height(terrain_height)

	# Assert
	assert_eq(waypoint_height, brain.desired_height_above_terrain,
		"Should return desired height when terrain is at sea level")

