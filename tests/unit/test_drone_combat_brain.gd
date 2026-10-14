extends GutTest
## Unit tests for DroneCombatBrain - pure logic, NO Godot dependencies
##
## These tests verify every function in DroneCombatBrain with 100% coverage

const DroneCombatBrain = preload("res://scripts/ai/brains/drone_combat_brain.gd")

var brain: DroneCombatBrain

func before_each():
	brain = DroneCombatBrain.new()
	# Use default configuration
	assert_eq(brain.optimal_range, 60.0, "Default optimal range should be 60")
	assert_eq(brain.min_range, 40.0, "Default min range should be 40")
	assert_eq(brain.max_range, 80.0, "Default max range should be 80")
	assert_eq(brain.retreat_health_threshold, 15.0, "Default retreat threshold should be 15")

# ===== decide_combat_behavior tests =====

func test_decide_combat_behavior_disengage_on_low_health():
	# Arrange
	var has_los = true
	var distance = 100.0  # Distance doesn't matter
	var health_pct = 10.0  # Below threshold (15%)
	var energy = 100.0

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.DISENGAGE,
		"Should disengage when health below threshold and not cornered")

func test_decide_combat_behavior_retreat_fire_when_cornered():
	# Arrange
	var has_los = true
	var distance = 30.0  # Within cornered distance (50m)
	var health_pct = 10.0  # Below threshold
	var energy = 100.0

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.RETREAT_FIRE,
		"Should fight to death when cornered with low health")

func test_decide_combat_behavior_disengage_on_low_energy():
	# Arrange
	var has_los = true
	var distance = 60.0
	var health_pct = 100.0
	var energy = 10.0  # Below minimum (20)

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.DISENGAGE,
		"Should disengage when energy too low to fight")

func test_decide_combat_behavior_chase_when_no_los():
	# Arrange
	var has_los = false
	var distance = 60.0  # At optimal range
	var health_pct = 100.0
	var energy = 100.0

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.CHASE,
		"Should chase to regain line of sight")

func test_decide_combat_behavior_chase_when_too_far():
	# Arrange
	var has_los = true
	var distance = 100.0  # Beyond max range (80)
	var health_pct = 100.0
	var energy = 100.0

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.CHASE,
		"Should chase when beyond max range")

func test_decide_combat_behavior_strafe_in_optimal_range():
	# Arrange
	var has_los = true
	var distance = 60.0  # At optimal range
	var health_pct = 100.0
	var energy = 100.0

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.STRAFE,
		"Should strafe when in optimal range with full health")

func test_decide_combat_behavior_strafe_at_min_range_boundary():
	# Arrange
	var has_los = true
	var distance = 40.0  # Exactly at min range
	var health_pct = 100.0
	var energy = 100.0

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.STRAFE,
		"Should strafe when exactly at min range")

func test_decide_combat_behavior_strafe_at_max_range_boundary():
	# Arrange
	var has_los = true
	var distance = 80.0  # Exactly at max range
	var health_pct = 100.0
	var energy = 100.0

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.STRAFE,
		"Should strafe when exactly at max range")

func test_decide_combat_behavior_retreat_fire_when_too_close():
	# Arrange
	var has_los = true
	var distance = 30.0  # Below min range (40)
	var health_pct = 100.0
	var energy = 100.0

	# Act
	var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

	# Assert
	assert_eq(behavior, DroneCombatBrain.CombatBehavior.RETREAT_FIRE,
		"Should retreat while firing when too close")

# ===== calculate_combat_movement tests =====

func test_calculate_combat_movement_chase_moves_toward_target():
	# Arrange
	var behavior = DroneCombatBrain.CombatBehavior.CHASE
	var to_target = Vector3(10, 0, 5)
	var forward = Vector3(0, 0, -1)
	var strafe_dir = 1.0

	# Act
	var movement = brain.calculate_combat_movement(behavior, to_target, forward, strafe_dir)

	# Assert
	assert_gt(movement.length(), 0.0, "Should produce movement")
	assert_almost_eq(movement.length(), 1.0, 0.01, "Movement should be normalized")

	# Movement should point toward target (XZ plane)
	var expected_dir = Vector2(10, 5).normalized()
	assert_almost_eq(movement.x, expected_dir.x, 0.01, "Movement X should point toward target")
	assert_almost_eq(movement.y, expected_dir.y, 0.01, "Movement Y should point toward target")

func test_calculate_combat_movement_chase_with_zero_vector():
	# Arrange
	var behavior = DroneCombatBrain.CombatBehavior.CHASE
	var to_target = Vector3.ZERO  # Edge case: already at target
	var forward = Vector3(0, 0, -1)
	var strafe_dir = 1.0

	# Act
	var movement = brain.calculate_combat_movement(behavior, to_target, forward, strafe_dir)

	# Assert
	assert_eq(movement, Vector2.ZERO, "Should return zero movement when already at target")

func test_calculate_combat_movement_strafe_moves_perpendicular():
	# Arrange
	var behavior = DroneCombatBrain.CombatBehavior.STRAFE
	var to_target = Vector3(10, 0, 0)  # Target to the right
	var forward = Vector3(0, 0, -1)
	var strafe_dir = 1.0  # Clockwise

	# Act
	var movement = brain.calculate_combat_movement(behavior, to_target, forward, strafe_dir)

	# Assert
	assert_gt(movement.length(), 0.0, "Should produce movement")
	assert_almost_eq(movement.length(), 1.0, 0.01, "Movement should be normalized")

	# Perpendicular to (10, 0) in XZ is (0, 10) or (0, -10)
	# With strafe_dir = 1, should be (0, -10) normalized = (0, -1)
	assert_almost_eq(movement.x, 0.0, 0.01, "Strafe should be perpendicular (X=0)")
	assert_almost_eq(abs(movement.y), 1.0, 0.01, "Strafe should be perpendicular (|Y|=1)")

func test_calculate_combat_movement_strafe_direction_affects_rotation():
	# Arrange
	var behavior = DroneCombatBrain.CombatBehavior.STRAFE
	var to_target = Vector3(10, 0, 0)
	var forward = Vector3(0, 0, -1)

	# Act
	var movement_cw = brain.calculate_combat_movement(behavior, to_target, forward, 1.0)
	var movement_ccw = brain.calculate_combat_movement(behavior, to_target, forward, -1.0)

	# Assert
	assert_ne(movement_cw, movement_ccw, "Strafe direction should affect movement direction")
	# Should be opposite directions
	assert_almost_eq(movement_cw.x, -movement_ccw.x, 0.01, "Opposite strafe directions")
	assert_almost_eq(movement_cw.y, -movement_ccw.y, 0.01, "Opposite strafe directions")

func test_calculate_combat_movement_retreat_fire_moves_away():
	# Arrange
	var behavior = DroneCombatBrain.CombatBehavior.RETREAT_FIRE
	var to_target = Vector3(10, 0, 5)
	var forward = Vector3(0, 0, -1)
	var strafe_dir = 1.0

	# Act
	var movement = brain.calculate_combat_movement(behavior, to_target, forward, strafe_dir)

	# Assert
	assert_gt(movement.length(), 0.0, "Should produce movement")
	assert_almost_eq(movement.length(), 1.0, 0.01, "Movement should be normalized")

	# Movement should point away from target
	var expected_dir = Vector2(-10, -5).normalized()
	assert_almost_eq(movement.x, expected_dir.x, 0.01, "Should move away from target (X)")
	assert_almost_eq(movement.y, expected_dir.y, 0.01, "Should move away from target (Y)")

func test_calculate_combat_movement_disengage_moves_away():
	# Arrange
	var behavior = DroneCombatBrain.CombatBehavior.DISENGAGE
	var to_target = Vector3(10, 0, 5)
	var forward = Vector3(0, 0, -1)
	var strafe_dir = 1.0

	# Act
	var movement = brain.calculate_combat_movement(behavior, to_target, forward, strafe_dir)

	# Assert
	assert_gt(movement.length(), 0.0, "Should produce movement")
	assert_almost_eq(movement.length(), 1.0, 0.01, "Movement should be normalized")

	# Movement should point away from target
	var expected_dir = Vector2(-10, -5).normalized()
	assert_almost_eq(movement.x, expected_dir.x, 0.01, "Should flee away from target (X)")
	assert_almost_eq(movement.y, expected_dir.y, 0.01, "Should flee away from target (Y)")

# ===== should_fire_weapons tests =====

func test_should_fire_weapons_false_when_disengaging():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 100.0
	var behavior = DroneCombatBrain.CombatBehavior.DISENGAGE

	# Act
	var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

	# Assert
	assert_false(should_fire, "Should not fire when disengaging")

func test_should_fire_weapons_false_when_no_los():
	# Arrange
	var has_los = false
	var is_aimed = true
	var energy = 100.0
	var behavior = DroneCombatBrain.CombatBehavior.STRAFE

	# Act
	var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

	# Assert
	assert_false(should_fire, "Should not fire without line of sight")

func test_should_fire_weapons_false_when_not_aimed():
	# Arrange
	var has_los = true
	var is_aimed = false
	var energy = 100.0
	var behavior = DroneCombatBrain.CombatBehavior.STRAFE

	# Act
	var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

	# Assert
	assert_false(should_fire, "Should not fire when not aimed at target")

func test_should_fire_weapons_false_when_low_energy():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 10.0  # Below min_firing_energy (20)
	var behavior = DroneCombatBrain.CombatBehavior.STRAFE

	# Act
	var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

	# Assert
	assert_false(should_fire, "Should not fire with insufficient energy")

func test_should_fire_weapons_true_when_all_conditions_met():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 100.0
	var behavior = DroneCombatBrain.CombatBehavior.STRAFE

	# Act
	var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

	# Assert
	assert_true(should_fire, "Should fire when all conditions met")

func test_should_fire_weapons_true_for_chase_behavior():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 100.0
	var behavior = DroneCombatBrain.CombatBehavior.CHASE

	# Act
	var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

	# Assert
	assert_true(should_fire, "Should fire while chasing if conditions met")

func test_should_fire_weapons_true_for_retreat_fire_behavior():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 100.0
	var behavior = DroneCombatBrain.CombatBehavior.RETREAT_FIRE

	# Act
	var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

	# Assert
	assert_true(should_fire, "Should fire while retreating if conditions met")

# ===== calculate_aim_point tests =====

func test_calculate_aim_point_predicts_target_movement():
	# Arrange
	var target_pos = Vector3(0, 0, 0)
	var target_vel = Vector3(10, 0, 0)  # Moving right at 10 m/s
	var projectile_speed = 100.0
	var distance = 100.0

	# Act
	var aim_point = brain.calculate_aim_point(target_pos, target_vel, projectile_speed, distance)

	# Assert
	var time_to_impact = distance / projectile_speed  # 1.0 second
	var expected_pos = target_pos + (target_vel * time_to_impact)  # (10, 0, 0)
	assert_almost_eq(aim_point.x, expected_pos.x, 0.01, "Should predict target X position")
	assert_almost_eq(aim_point.y, expected_pos.y, 0.01, "Should predict target Y position")
	assert_almost_eq(aim_point.z, expected_pos.z, 0.01, "Should predict target Z position")

func test_calculate_aim_point_no_prediction_when_zero_projectile_speed():
	# Arrange
	var target_pos = Vector3(5, 10, 15)
	var target_vel = Vector3(10, 0, 0)
	var projectile_speed = 0.0  # Edge case
	var distance = 100.0

	# Act
	var aim_point = brain.calculate_aim_point(target_pos, target_vel, projectile_speed, distance)

	# Assert
	assert_eq(aim_point, target_pos, "Should return target position when projectile speed is zero")

func test_calculate_aim_point_with_3d_velocity():
	# Arrange
	var target_pos = Vector3(0, 0, 0)
	var target_vel = Vector3(10, 5, -3)  # 3D movement
	var projectile_speed = 50.0
	var distance = 50.0

	# Act
	var aim_point = brain.calculate_aim_point(target_pos, target_vel, projectile_speed, distance)

	# Assert
	var time_to_impact = distance / projectile_speed  # 1.0 second
	var expected_pos = target_pos + (target_vel * time_to_impact)
	assert_almost_eq(aim_point.x, expected_pos.x, 0.01, "Should predict 3D position (X)")
	assert_almost_eq(aim_point.y, expected_pos.y, 0.01, "Should predict 3D position (Y)")
	assert_almost_eq(aim_point.z, expected_pos.z, 0.01, "Should predict 3D position (Z)")

# ===== should_retreat tests =====

func test_should_retreat_true_when_health_low():
	# Arrange
	var health_pct = 10.0  # Below threshold (15%)
	var distance_to_safety = 100.0

	# Act
	var should_retreat = brain.should_retreat(health_pct, distance_to_safety)

	# Assert
	assert_true(should_retreat, "Should retreat when health below threshold")

func test_should_retreat_false_when_health_high():
	# Arrange
	var health_pct = 50.0  # Above threshold
	var distance_to_safety = 100.0

	# Act
	var should_retreat = brain.should_retreat(health_pct, distance_to_safety)

	# Assert
	assert_false(should_retreat, "Should not retreat when health is good")

func test_should_retreat_at_threshold_boundary():
	# Arrange
	var health_pct = 15.0  # Exactly at threshold
	var distance_to_safety = 100.0

	# Act
	var should_retreat = brain.should_retreat(health_pct, distance_to_safety)

	# Assert
	assert_false(should_retreat, "Should not retreat when exactly at threshold (not below)")

# ===== is_safe tests =====

func test_is_safe_true_when_health_recovered():
	# Arrange
	var health_pct = 50.0  # Above threshold * 2 (30%)
	var distance_to_threat = 100.0

	# Act
	var is_safe = brain.is_safe(health_pct, distance_to_threat)

	# Assert
	assert_true(is_safe, "Should be safe when health recovered above threshold * 2")

func test_is_safe_true_when_far_from_threat():
	# Arrange
	var health_pct = 20.0  # Still low
	var distance_to_threat = 400.0  # Beyond retreat_safe_distance (300)

	# Act
	var is_safe = brain.is_safe(health_pct, distance_to_threat)

	# Assert
	assert_true(is_safe, "Should be safe when far from threat")

func test_is_safe_false_when_health_low_and_close():
	# Arrange
	var health_pct = 20.0  # Low but not recovered
	var distance_to_threat = 100.0  # Close

	# Act
	var is_safe = brain.is_safe(health_pct, distance_to_threat)

	# Assert
	assert_false(is_safe, "Should not be safe when health low and still close to threat")

func test_is_safe_at_distance_boundary():
	# Arrange
	var health_pct = 20.0
	var distance_to_threat = 300.0  # Exactly at retreat_safe_distance

	# Act
	var is_safe = brain.is_safe(health_pct, distance_to_threat)

	# Assert
	assert_false(is_safe, "Should not be safe when exactly at boundary (not beyond)")

# ===== get_combat_speed_fraction tests =====

func test_get_combat_speed_fraction_chase_is_full_speed():
	# Act
	var speed = brain.get_combat_speed_fraction(DroneCombatBrain.CombatBehavior.CHASE)

	# Assert
	assert_eq(speed, 1.0, "Chase should be full speed")

func test_get_combat_speed_fraction_strafe_is_reduced():
	# Act
	var speed = brain.get_combat_speed_fraction(DroneCombatBrain.CombatBehavior.STRAFE)

	# Assert
	assert_eq(speed, 0.8, "Strafe should be slightly slower for accuracy")

func test_get_combat_speed_fraction_retreat_fire_is_reduced():
	# Act
	var speed = brain.get_combat_speed_fraction(DroneCombatBrain.CombatBehavior.RETREAT_FIRE)

	# Assert
	assert_eq(speed, 0.7, "Retreat fire should be controlled speed")

func test_get_combat_speed_fraction_disengage_is_full_speed():
	# Act
	var speed = brain.get_combat_speed_fraction(DroneCombatBrain.CombatBehavior.DISENGAGE)

	# Assert
	assert_eq(speed, 1.0, "Disengage should be full speed flee")

