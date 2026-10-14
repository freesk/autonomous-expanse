extends GutTest
## Integration tests for AI Controller system
##
## These tests verify that AI components work together correctly

const DroneCombatBrain = preload("res://scripts/ai/brains/drone_combat_brain.gd")
const DronePathfindingBrain = preload("res://scripts/ai/brains/drone_pathfinding_brain.gd")
const DroneWeaponBrain = preload("res://scripts/ai/brains/drone_weapon_brain.gd")
const MockDrone = preload("res://tests/mocks/mock_drone.gd")
const MockPhysicsQuery = preload("res://tests/mocks/mock_physics_query.gd")
const MockTargetable = preload("res://tests/mocks/mock_targetable.gd")
const MockMotionSystem = preload("res://tests/mocks/mock_motion_system.gd")
const MockWeaponSystem = preload("res://tests/mocks/mock_weapon_system.gd")
const AICommandContext = preload("res://scripts/ai/commands/ai_command_context.gd")
const CommandQueue = preload("res://scripts/ai/commands/command_queue.gd")
const MoveCommand = preload("res://scripts/ai/commands/move_command.gd")
const FireWeaponCommand = preload("res://scripts/ai/commands/fire_weapon_command.gd")

var combat_brain: DroneCombatBrain
var pathfinding_brain: DronePathfindingBrain
var weapon_brain: DroneWeaponBrain
var command_queue: CommandQueue
var mock_drone: MockDrone
var mock_physics: MockPhysicsQuery
var mock_motion: MockMotionSystem
var mock_weapon: MockWeaponSystem
var context: AICommandContext

func before_each():
	# Create AI brains
	combat_brain = DroneCombatBrain.new()
	pathfinding_brain = DronePathfindingBrain.new()
	weapon_brain = DroneWeaponBrain.new()

	# Create mocks
	mock_drone = MockDrone.new()
	mock_drone.position = Vector3.ZERO
	mock_drone.forward = Vector3(0, 0, -1)
	mock_drone.health_percentage = 100.0
	mock_drone.energy = 100.0

	mock_physics = MockPhysicsQuery.new()
	mock_motion = MockMotionSystem.new()
	mock_weapon = MockWeaponSystem.new()

	# Create command queue and context
	command_queue = CommandQueue.new()
	context = AICommandContext.new(mock_drone, mock_physics, mock_motion, mock_weapon)

# ===== Full Combat Scenario Tests =====

func test_combat_scenario_engage_target_at_optimal_range():
	# Arrange - target at optimal range with clear LOS
	var target = MockTargetable.new()
	target.position = Vector3(60, 0, 0)  # At optimal range
	target.velocity = Vector3.ZERO
	target.valid = true

	# Clear line of sight
	mock_physics.set_raycast_result(
		mock_drone.position,
		target.position,
		{}  # No collision = clear LOS
	)

	# Act - make combat decision
	var distance = mock_drone.position.distance_to(target.position)
	var to_target = target.position - mock_drone.position
	var has_los = mock_physics.raycast(mock_drone.position, target.position).is_empty()

	var behavior = combat_brain.decide_combat_behavior(
		has_los, distance, mock_drone.health_percentage, mock_drone.energy
	)

	var movement = combat_brain.calculate_combat_movement(
		behavior, to_target, mock_drone.forward, 1.0
	)

	# For testing, assume drone is aimed at target (forward facing target)
	mock_drone.forward = to_target.normalized()
	var is_aimed = weapon_brain.is_aimed_at_target(mock_drone.forward, to_target)

	var should_fire = combat_brain.should_fire_weapons(
		has_los,
		is_aimed,
		mock_drone.energy,
		behavior
	)

	# Issue commands
	var move_cmd = MoveCommand.new(movement, 0.0, combat_brain.get_combat_speed_fraction(behavior))
	command_queue.enqueue(move_cmd)

	if should_fire:
		var aim_point = combat_brain.calculate_aim_point(
			target.position, target.velocity, mock_weapon.get_projectile_speed(), distance
		)
		var fire_cmd = FireWeaponCommand.new(aim_point, true, false)
		command_queue.enqueue(fire_cmd)

	# Execute commands
	var executed = command_queue.execute_all(context)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.STRAFE,
		"Should strafe at optimal range")
	assert_true(should_fire, "Should fire when aimed at target")
	assert_eq(executed, 2, "Should execute move and fire commands")
	assert_gt(mock_motion.command_count, 0, "Motion system should receive commands")
	assert_gt(mock_weapon.fire_count, 0, "Weapon system should receive fire command")

func test_combat_scenario_disengage_when_health_low():
	# Arrange - low health scenario
	mock_drone.health_percentage = 10.0  # Critical
	mock_drone.energy = 100.0

	var target = MockTargetable.new()
	target.position = Vector3(100, 0, 0)
	target.valid = true

	mock_physics.set_raycast_result(mock_drone.position, target.position, {})

	# Act
	var distance = mock_drone.position.distance_to(target.position)
	var has_los = true

	var behavior = combat_brain.decide_combat_behavior(
		has_los, distance, mock_drone.health_percentage, mock_drone.energy
	)

	var to_target = target.position - mock_drone.position
	var movement = combat_brain.calculate_combat_movement(
		behavior, to_target, mock_drone.forward, 1.0
	)

	# Issue retreat command
	var move_cmd = MoveCommand.new(movement, 0.0, 1.0)  # Full speed retreat
	command_queue.enqueue(move_cmd)
	command_queue.execute_all(context)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.DISENGAGE,
		"Should disengage when health critical")
	# Movement should point away from target
	var dot = movement.normalized().dot(Vector2(to_target.x, to_target.z).normalized())
	assert_lt(dot, 0.0, "Should move away from target (negative dot product)")

func test_combat_scenario_no_fire_when_los_blocked():
	# Arrange - target with blocked LOS
	var target = MockTargetable.new()
	target.position = Vector3(60, 0, 0)
	target.valid = true

	# LOS blocked by obstacle
	mock_physics.set_raycast_result(
		mock_drone.position,
		target.position,
		{"collider": "obstacle", "position": Vector3(30, 0, 0)}
	)

	# Act
	var distance = mock_drone.position.distance_to(target.position)
	var has_los = mock_physics.raycast(mock_drone.position, target.position).is_empty()

	var behavior = combat_brain.decide_combat_behavior(
		has_los, distance, mock_drone.health_percentage, mock_drone.energy
	)

	var should_fire = combat_brain.should_fire_weapons(
		has_los,
		true,  # Aimed
		mock_drone.energy,
		behavior
	)

	# Assert
	assert_false(has_los, "LOS should be blocked")
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.CHASE,
		"Should chase when no LOS")
	assert_false(should_fire, "Should not fire when LOS blocked")

# ===== Full Pathfinding Scenario Tests =====

func test_pathfinding_scenario_navigate_to_waypoint():
	# Arrange
	var waypoint = Vector3(100, 20, 50)
	mock_drone.position = Vector3(0, 10, 0)

	# Set terrain height
	mock_physics.set_terrain_height(mock_drone.position.x, mock_drone.position.z, 0.0)
	mock_physics.set_terrain_height(waypoint.x, waypoint.z, 5.0)

	# Act
	var to_waypoint = waypoint - mock_drone.position
	var distance = to_waypoint.length()

	var movement = pathfinding_brain.calculate_movement_to_waypoint(to_waypoint)
	var terrain_height = mock_physics.get_terrain_height(mock_drone.position.x, mock_drone.position.z)
	var climb = pathfinding_brain.calculate_climb_rate(
		mock_drone.position.y, terrain_height, waypoint.y
	)
	var speed = pathfinding_brain.calculate_speed_fraction(distance, false)

	# Issue command
	var move_cmd = MoveCommand.new(movement, climb, speed)
	command_queue.enqueue(move_cmd)
	command_queue.execute_all(context)

	# Assert
	assert_gt(movement.length(), 0.0, "Should produce movement toward waypoint")
	assert_gt(climb, 0.0, "Should climb to reach waypoint height")
	assert_eq(speed, 1.0, "Should move at full speed when far from waypoint")
	assert_true(mock_motion.command_count > 0, "Motion system should receive command")

func test_pathfinding_scenario_slow_down_near_waypoint():
	# Arrange
	var waypoint = Vector3(10, 15, 0)  # Close but not reached yet
	mock_drone.position = Vector3(0, 15, 0)

	mock_physics.set_terrain_height(0, 0, 0)

	# Act
	var to_waypoint = waypoint - mock_drone.position
	var distance = to_waypoint.length()  # Should be 10.0

	var movement = pathfinding_brain.calculate_movement_to_waypoint(to_waypoint)
	var speed = pathfinding_brain.calculate_speed_fraction(distance, false)

	# Assert - with slow_down_distance = 15, speed at 10m should be reduced
	assert_lt(speed, 1.0, "Should slow down near waypoint")
	# Distance of 10 is within slow_down_distance (15) but not reached threshold (5)
	assert_false(pathfinding_brain.has_reached_waypoint(distance),
		"Should not consider waypoint reached until within threshold")

func test_pathfinding_scenario_avoid_obstacle():
	# Arrange
	var waypoint = Vector3(0, 15, 100)  # Forward
	mock_drone.position = Vector3(0, 15, 0)

	var obstacle_direction = Vector3(1, 0, 0)  # Obstacle to the right
	var obstacles = [obstacle_direction]

	# Act
	var to_waypoint = waypoint - mock_drone.position
	var desired_movement = pathfinding_brain.calculate_movement_to_waypoint(to_waypoint)
	# Desired is (0, 1) pointing forward

	var adjusted_movement = pathfinding_brain.calculate_obstacle_avoidance(
		obstacles, desired_movement
	)

	# Issue command
	var move_cmd = MoveCommand.new(adjusted_movement, 0.0, 0.6)  # Slower due to obstacles
	command_queue.enqueue(move_cmd)
	command_queue.execute_all(context)

	# Assert - with obstacle to the right, should be pushed left (negative X)
	assert_true(mock_motion.command_count > 0, "Should issue movement command")
	# The avoidance algorithm blends desired (70%) and avoidance (30%)
	# Obstacle at (1,0) creates avoidance force (-1,0), resulting in leftward push
	assert_lt(adjusted_movement.x, -0.01, "Should be pushed left away from right obstacle")

# ===== Weapon Brain Integration Tests =====

func test_weapon_brain_burst_fire_cycle():
	# Arrange
	weapon_brain.reset_timers()
	var delta = 0.016  # ~60fps

	# Act & Assert - Start burst
	var fire1 = weapon_brain.should_fire_this_frame(true, true, 100.0, delta)
	assert_true(fire1, "Should fire on first frame")

	# Continue burst
	var fire2 = weapon_brain.should_fire_this_frame(true, true, 100.0, delta)
	assert_true(fire2, "Should continue firing during burst")

	# Fast forward past burst duration
	weapon_brain.should_fire_this_frame(true, true, 100.0, weapon_brain.burst_fire_duration + 0.1)

	# Check cooldown
	var fire_during_cooldown = weapon_brain.should_fire_this_frame(true, true, 100.0, delta)
	assert_false(fire_during_cooldown, "Should not fire during cooldown")
	assert_true(weapon_brain.is_on_cooldown(), "Should be in cooldown")

	# Fast forward past cooldown duration
	var cooldown_remaining = weapon_brain.get_time_until_can_fire()
	weapon_brain.should_fire_this_frame(true, true, 100.0, cooldown_remaining + 0.1)

	# Should be able to fire again
	var fire_after_cooldown = weapon_brain.should_fire_this_frame(true, true, 100.0, delta)
	assert_true(fire_after_cooldown, "Should be able to fire again after cooldown")

# ===== Multi-Brain Coordination Tests =====

func test_full_ai_update_cycle():
	# Arrange - simulated single frame AI update
	var target = MockTargetable.new()
	target.position = Vector3(60, 0, 0)
	target.velocity = Vector3(0, 0, 5)  # Moving
	target.valid = true

	mock_physics.set_raycast_result(mock_drone.position, target.position, {})

	# Act - full AI decision cycle
	var distance = mock_drone.position.distance_to(target.position)
	var to_target = target.position - mock_drone.position
	var has_los = true

	# 1. Combat brain decides behavior
	var behavior = combat_brain.decide_combat_behavior(
		has_los, distance, mock_drone.health_percentage, mock_drone.energy
	)

	# 2. Calculate movement
	var movement = combat_brain.calculate_combat_movement(
		behavior, to_target, mock_drone.forward, 1.0
	)

	# 3. Check if should fire
	var is_aimed = weapon_brain.is_aimed_at_target(mock_drone.forward, to_target)
	var should_fire = weapon_brain.should_fire_this_frame(
		has_los, is_aimed, mock_drone.energy, 0.016
	)

	# 4. Generate commands
	command_queue.clear()
	var move_cmd = MoveCommand.new(movement, 0.0, 0.8)
	command_queue.enqueue(move_cmd)

	if should_fire:
		var aim_point = combat_brain.calculate_aim_point(
			target.position, target.velocity, 1000.0, distance
		)
		var fire_cmd = FireWeaponCommand.new(aim_point, true, false)
		command_queue.enqueue(fire_cmd)

	# 5. Execute commands
	var executed = command_queue.execute_all(context)

	# Assert - verify full pipeline worked
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.STRAFE,
		"Should choose strafe behavior at optimal range")
	assert_gt(executed, 0, "Should execute at least one command")
	assert_true(mock_motion.command_count > 0,
		"Motion system should have received movement commands")

	# Verify command history
	var history = command_queue.get_execution_history()
	assert_gt(history.size(), 0, "Should have recorded command execution")

func test_ai_adapts_to_changing_conditions():
	# Arrange - start healthy
	mock_drone.health_percentage = 100.0
	var target = MockTargetable.new()
	target.position = Vector3(60, 0, 0)

	# Act - Frame 1: Healthy, should engage
	var distance = mock_drone.position.distance_to(target.position)
	var behavior1 = combat_brain.decide_combat_behavior(true, distance, 100.0, 100.0)

	# Simulate taking damage
	mock_drone.health_percentage = 10.0

	# Frame 2: Low health, should disengage
	var behavior2 = combat_brain.decide_combat_behavior(true, distance, 10.0, 100.0)

	# Assert
	assert_eq(behavior1, DroneCombatBrain.CombatBehavior.STRAFE,
		"Should strafe when healthy")
	assert_eq(behavior2, DroneCombatBrain.CombatBehavior.DISENGAGE,
		"Should disengage when damaged")
