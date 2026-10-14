extends GutTest
## Unit tests for DroneWeaponBrain - pure logic, NO Godot dependencies
##
## These tests verify every function in DroneWeaponBrain with 100% coverage

const DroneWeaponBrain = preload("res://scripts/ai/brains/drone_weapon_brain.gd")

var brain: DroneWeaponBrain

func before_each():
	brain = DroneWeaponBrain.new()
	# Verify default configuration
	assert_eq(brain.aim_tolerance_degrees, 5.0, "Default aim tolerance should be 5 degrees")
	assert_eq(brain.min_firing_energy, 20.0, "Default min firing energy should be 20")
	assert_eq(brain.burst_fire_duration, 0.5, "Default burst duration should be 0.5s")
	assert_eq(brain.burst_cooldown_duration, 1.0, "Default cooldown should be 1.0s")

# ===== is_aimed_at_target tests =====

func test_is_aimed_at_target_true_when_within_tolerance():
	# Arrange
	var forward = Vector3(0, 0, -1)  # Facing forward
	var to_target = Vector3(0, 0, -10).normalized()  # Target directly ahead

	# Act
	var is_aimed = brain.is_aimed_at_target(forward, to_target)

	# Assert
	assert_true(is_aimed, "Should be aimed when target directly ahead")

func test_is_aimed_at_target_false_when_beyond_tolerance():
	# Arrange
	var forward = Vector3(0, 0, -1)  # Facing forward
	var to_target = Vector3(1, 0, 0).normalized()  # Target 90 degrees to the right

	# Act
	var is_aimed = brain.is_aimed_at_target(forward, to_target)

	# Assert
	assert_false(is_aimed, "Should not be aimed when target 90 degrees away")

func test_is_aimed_at_target_at_tolerance_boundary():
	# Arrange
	var forward = Vector3(0, 0, -1)
	# Calculate vector slightly beyond 5 degree tolerance (5.1 degrees)
	var angle_rad = deg_to_rad(5.1)
	var to_target = Vector3(sin(angle_rad), 0, -cos(angle_rad)).normalized()

	# Act
	var is_aimed = brain.is_aimed_at_target(forward, to_target)

	# Assert
	assert_false(is_aimed, "Should not be aimed when beyond tolerance")

func test_is_aimed_at_target_just_within_tolerance():
	# Arrange
	var forward = Vector3(0, 0, -1)
	# Calculate vector just within 5 degree tolerance (4.5 degrees)
	var angle_rad = deg_to_rad(4.5)
	var to_target = Vector3(sin(angle_rad), 0, -cos(angle_rad)).normalized()

	# Act
	var is_aimed = brain.is_aimed_at_target(forward, to_target)

	# Assert
	assert_true(is_aimed, "Should be aimed when just within tolerance")

func test_is_aimed_at_target_with_zero_vector():
	# Arrange
	var forward = Vector3(0, 0, -1)
	var to_target = Vector3.ZERO  # Edge case

	# Act
	var is_aimed = brain.is_aimed_at_target(forward, to_target)

	# Assert
	assert_false(is_aimed, "Should not be aimed when target vector is zero")

func test_is_aimed_at_target_works_in_3d():
	# Arrange
	var forward = Vector3(0, 0, -1)
	# Target slightly above and ahead (should still be within tolerance)
	var to_target = Vector3(0, 0.01, -1).normalized()

	# Act
	var is_aimed = brain.is_aimed_at_target(forward, to_target)

	# Assert
	assert_true(is_aimed, "Should work with 3D angles (not just horizontal)")

# ===== should_fire_this_frame tests =====

func test_should_fire_this_frame_false_when_no_los():
	# Arrange
	var has_los = false
	var is_aimed = true
	var energy = 100.0
	var delta = 0.016

	# Act
	var should_fire = brain.should_fire_this_frame(has_los, is_aimed, energy, delta)

	# Assert
	assert_false(should_fire, "Should not fire without line of sight")

func test_should_fire_this_frame_false_when_not_aimed():
	# Arrange
	var has_los = true
	var is_aimed = false
	var energy = 100.0
	var delta = 0.016

	# Act
	var should_fire = brain.should_fire_this_frame(has_los, is_aimed, energy, delta)

	# Assert
	assert_false(should_fire, "Should not fire when not aimed")

func test_should_fire_this_frame_false_when_low_energy():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 10.0  # Below min_firing_energy (20)
	var delta = 0.016

	# Act
	var should_fire = brain.should_fire_this_frame(has_los, is_aimed, energy, delta)

	# Assert
	assert_false(should_fire, "Should not fire with insufficient energy")

func test_should_fire_this_frame_true_starts_burst():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 100.0
	var delta = 0.016
	brain.reset_timers()

	# Act
	var should_fire = brain.should_fire_this_frame(has_los, is_aimed, energy, delta)

	# Assert
	assert_true(should_fire, "Should fire when all conditions met and no cooldown")
	assert_gt(brain.burst_timer, 0.0, "Should start burst timer")
	# Cooldown starts AFTER burst ends, not immediately
	assert_eq(brain.cooldown_timer, 0.0, "Cooldown should not start until burst ends")

func test_should_fire_this_frame_continues_during_burst():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 100.0
	brain.reset_timers()

	# Start a burst
	brain.should_fire_this_frame(has_los, is_aimed, energy, 0.016)

	# Act - check next frame during burst
	var should_fire = brain.should_fire_this_frame(has_los, is_aimed, energy, 0.016)

	# Assert
	assert_true(should_fire, "Should continue firing during burst")

func test_should_fire_this_frame_false_during_cooldown():
	# Arrange
	var has_los = true
	var is_aimed = true
	var energy = 100.0
	brain.reset_timers()

	# Start burst
	brain.should_fire_this_frame(has_los, is_aimed, energy, 0.016)

	# Fast forward past burst duration to trigger cooldown
	var large_delta = brain.burst_fire_duration + 0.1
	brain.should_fire_this_frame(has_los, is_aimed, energy, large_delta)

	# Act - check during cooldown
	var should_fire = brain.should_fire_this_frame(has_los, is_aimed, energy, 0.016)

	# Assert
	assert_false(should_fire, "Should not fire during cooldown")
	assert_gt(brain.cooldown_timer, 0.0, "Should still be in cooldown")

func test_should_fire_this_frame_timers_decrement():
	# Arrange
	brain.burst_timer = 1.0
	brain.cooldown_timer = 0.0  # Cooldown doesn't count during burst
	var delta = 0.5

	# Act
	brain.should_fire_this_frame(true, true, 100.0, delta)

	# Assert
	assert_almost_eq(brain.burst_timer, 0.5, 0.01, "Burst timer should decrement during burst")
	# Cooldown only counts down when burst is done
	assert_eq(brain.cooldown_timer, 0.0, "Cooldown should not decrement during burst")

# ===== apply_accuracy_error tests =====

func test_apply_accuracy_error_perfect_accuracy_no_change():
	# Arrange
	var aim_point = Vector3(10, 5, 8)
	brain.accuracy = 1.0  # Perfect
	var random_seed = 0.5

	# Act
	var result = brain.apply_accuracy_error(aim_point, random_seed)

	# Assert
	assert_eq(result, aim_point, "Perfect accuracy should not change aim point")

func test_apply_accuracy_error_zero_accuracy_max_error():
	# Arrange
	var aim_point = Vector3(10, 5, 8)
	brain.accuracy = 0.0  # Worst
	var random_seed = 0.5

	# Act
	var result = brain.apply_accuracy_error(aim_point, random_seed)

	# Assert
	assert_ne(result, aim_point, "Zero accuracy should change aim point")
	var error = result.distance_to(aim_point)
	assert_lte(error, 10.0 * 1.8, "Error should be within max error magnitude")  # sqrt(3) * 10 ~= 17.3

func test_apply_accuracy_error_medium_accuracy():
	# Arrange
	var aim_point = Vector3(10, 5, 8)
	brain.accuracy = 0.5  # Medium
	var random_seed = 0.5

	# Act
	var result = brain.apply_accuracy_error(aim_point, random_seed)

	# Assert
	assert_ne(result, aim_point, "Medium accuracy should add some error")
	var error = result.distance_to(aim_point)
	assert_lte(error, 5.0 * 1.8, "Error should scale with accuracy")

func test_apply_accuracy_error_deterministic_with_same_seed():
	# Arrange
	var aim_point = Vector3(10, 5, 8)
	brain.accuracy = 0.5
	var seed1 = 0.5

	# Act
	var result1 = brain.apply_accuracy_error(aim_point, seed1)
	var result2 = brain.apply_accuracy_error(aim_point, seed1)

	# Assert
	assert_eq(result1, result2, "Same seed should produce same result (deterministic)")

func test_apply_accuracy_error_different_with_different_seed():
	# Arrange
	var aim_point = Vector3(10, 5, 8)
	brain.accuracy = 0.5

	# Act
	var result1 = brain.apply_accuracy_error(aim_point, 0.1)
	var result2 = brain.apply_accuracy_error(aim_point, 0.9)

	# Assert
	assert_ne(result1, result2, "Different seeds should produce different results")

# ===== reset_timers tests =====

func test_reset_timers_clears_burst_timer():
	# Arrange
	brain.burst_timer = 5.0

	# Act
	brain.reset_timers()

	# Assert
	assert_eq(brain.burst_timer, 0.0, "Should reset burst timer to zero")

func test_reset_timers_clears_cooldown_timer():
	# Arrange
	brain.cooldown_timer = 5.0

	# Act
	brain.reset_timers()

	# Assert
	assert_eq(brain.cooldown_timer, 0.0, "Should reset cooldown timer to zero")

# ===== get_time_until_can_fire tests =====

func test_get_time_until_can_fire_returns_cooldown_time():
	# Arrange
	brain.cooldown_timer = 3.5

	# Act
	var time = brain.get_time_until_can_fire()

	# Assert
	assert_eq(time, 3.5, "Should return cooldown time remaining")

func test_get_time_until_can_fire_zero_when_ready():
	# Arrange
	brain.cooldown_timer = 0.0

	# Act
	var time = brain.get_time_until_can_fire()

	# Assert
	assert_eq(time, 0.0, "Should return zero when ready to fire")

func test_get_time_until_can_fire_zero_when_negative():
	# Arrange
	brain.cooldown_timer = -1.0  # Edge case

	# Act
	var time = brain.get_time_until_can_fire()

	# Assert
	assert_eq(time, 0.0, "Should return zero even if cooldown is negative")

# ===== is_on_cooldown tests =====

func test_is_on_cooldown_true_when_cooldown_active():
	# Arrange
	brain.cooldown_timer = 0.5

	# Act
	var on_cooldown = brain.is_on_cooldown()

	# Assert
	assert_true(on_cooldown, "Should be on cooldown when timer > 0")

func test_is_on_cooldown_false_when_ready():
	# Arrange
	brain.cooldown_timer = 0.0

	# Act
	var on_cooldown = brain.is_on_cooldown()

	# Assert
	assert_false(on_cooldown, "Should not be on cooldown when timer = 0")

func test_is_on_cooldown_false_when_negative():
	# Arrange
	brain.cooldown_timer = -0.1  # Edge case

	# Act
	var on_cooldown = brain.is_on_cooldown()

	# Assert
	assert_false(on_cooldown, "Should not be on cooldown when timer < 0")

# ===== Integration scenario tests =====

func test_full_burst_cycle():
	# Arrange
	brain.reset_timers()
	brain.burst_fire_duration = 0.5
	brain.burst_cooldown_duration = 1.0
	var has_los = true
	var is_aimed = true
	var energy = 100.0

	# Act & Assert - First frame should start burst
	var fired_first = brain.should_fire_this_frame(has_los, is_aimed, energy, 0.016)
	assert_true(fired_first, "Should fire on first frame")

	# Continue firing during burst
	var fired_during = brain.should_fire_this_frame(has_los, is_aimed, energy, 0.3)
	assert_true(fired_during, "Should continue firing during burst")

	# After burst duration, should be in cooldown
	brain.should_fire_this_frame(has_los, is_aimed, energy, 0.3)  # Finish burst
	var fired_cooldown = brain.should_fire_this_frame(has_los, is_aimed, energy, 0.1)
	assert_false(fired_cooldown, "Should not fire during cooldown")

	# After full cooldown, should be able to fire again
	brain.should_fire_this_frame(has_los, is_aimed, energy, 1.5)  # Wait out cooldown
	var fired_again = brain.should_fire_this_frame(has_los, is_aimed, energy, 0.016)
	assert_true(fired_again, "Should be able to fire again after cooldown")
