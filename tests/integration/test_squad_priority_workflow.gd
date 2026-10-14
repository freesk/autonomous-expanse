extends GutTest
## Integration tests for squad priority workflow
##
## Tests the full lifecycle of priority state transitions during squad operations

const DronePriorityManager = preload("res://src/ai/drone/drone_priority_manager.gd")
const MockNode3DTarget = preload("res://tests/mocks/mock_node3d_target.gd")

var priority_manager: DronePriorityManager
var test_targets: Array = []  # Track created nodes for cleanup

func before_each():
	# Create a fresh priority manager for each test
	priority_manager = DronePriorityManager.new()

	# Initialize priority manager as squad member (drone param not used in state logic)
	priority_manager.initialize(null, true)

	# Clear test targets array
	test_targets = []

func after_each():
	# Clean up any created Node3D mocks
	for target in test_targets:
		if is_instance_valid(target):
			target.queue_free()
	test_targets.clear()

# ===== Squad Behavior Workflow Test =====

func test_squad_workflow_resource_combat_resource():
	# This test simulates:
	# 1. Squad member navigating to resource
	# 2. Player appears (interrupts with combat priority)
	# 3. Player is destroyed
	# 4. Returns to squad duties (resource gathering)

	# PHASE 1: Squad member gathering resources
	# Arrange - drone starts in PART_OF_SQUAD state
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.PART_OF_SQUAD,
		"Drone should start in PART_OF_SQUAD state")

	# PHASE 2: Player appears - squad assigns combat target
	# Act - squad detects player and assigns target
	var player_target = MockNode3DTarget.new()
	player_target.valid = true
	test_targets.append(player_target)

	var transition = priority_manager.on_target_assigned(player_target)

	# Assert - should transition to COMBAT
	assert_true(transition.changed, "Should transition state when target assigned")
	assert_eq(transition.state, DronePriorityManager.AIState.COMBAT,
		"Should transition to COMBAT state")
	assert_eq(transition.reason, "target_assigned",
		"Transition reason should be target_assigned")
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.COMBAT,
		"Priority manager should now be in COMBAT state")
	assert_eq(priority_manager.get_target(), player_target,
		"Target should be stored in priority manager")

	# PHASE 3: Combat engagement (simulated frames)
	# Simulate several frames of combat
	for i in range(10):
		var delta = 0.1  # 100ms per frame
		priority_manager.update_target_tracking(delta)
		var combat_update = priority_manager.validate_current_state()
		# During combat with valid target, should remain in COMBAT state
		if combat_update.changed:
			assert_eq(combat_update.state, DronePriorityManager.AIState.COMBAT,
				"Should remain in COMBAT while target is valid")

	# PHASE 4: Player destroyed
	# Act - player is destroyed, target becomes invalid
	player_target.valid = false
	var target_lost_transition = priority_manager.on_target_invalid()

	# Assert - should transition back to PART_OF_SQUAD
	assert_true(target_lost_transition.changed,
		"Should transition when target becomes invalid")
	assert_eq(target_lost_transition.state, DronePriorityManager.AIState.PART_OF_SQUAD,
		"Should return to PART_OF_SQUAD after target lost")
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.PART_OF_SQUAD,
		"Should be back in PART_OF_SQUAD state")
	assert_null(priority_manager.get_target(),
		"Target should be cleared")

	# PHASE 5: Resume squad duties
	# Simulate returning to resource gathering
	for i in range(5):
		var delta = 0.1
		priority_manager.update_target_tracking(delta)
		var squad_update = priority_manager.validate_current_state()
		# Should remain in PART_OF_SQUAD state (no changes expected)
		assert_false(squad_update.changed,
			"Should remain in PART_OF_SQUAD during resource gathering")

func test_squad_workflow_multiple_interruptions():
	# Test multiple combat interruptions during squad operations
	# Simulates: resource → combat1 → resource → combat2 → resource

	# Start in squad mode
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.PART_OF_SQUAD)

	# First interruption
	var target1 = MockNode3DTarget.new()
	target1# Position not needed for priority logic tests
	#.global_position = Vector3(50, 0, 0)
	target1.valid = true
	test_targets.append(target1)

	var transition1 = priority_manager.on_target_assigned(target1)
	assert_eq(transition1.state, DronePriorityManager.AIState.COMBAT,
		"Should enter combat for first target")

	# First target destroyed
	var clear1 = priority_manager.on_target_invalid()
	assert_eq(clear1.state, DronePriorityManager.AIState.PART_OF_SQUAD,
		"Should return to squad after first combat")

	# Second interruption
	var target2 = MockNode3DTarget.new()
	target2# Position not needed for priority logic tests
	#.global_position = Vector3(80, 0, 0)
	target2.valid = true
	test_targets.append(target2)

	var transition2 = priority_manager.on_target_assigned(target2)
	assert_eq(transition2.state, DronePriorityManager.AIState.COMBAT,
		"Should enter combat for second target")

	# Second target destroyed
	var clear2 = priority_manager.on_target_invalid()
	assert_eq(clear2.state, DronePriorityManager.AIState.PART_OF_SQUAD,
		"Should return to squad after second combat")

func test_squad_workflow_damaged_during_combat():
	# Test that low health triggers retreat even during squad combat

	# Enter combat
	var target = MockNode3DTarget.new()
	target# Position not needed for priority logic tests
	#.global_position = Vector3(100, 0, 0)
	target.valid = true
	test_targets.append(target)
	priority_manager.on_target_assigned(target)

	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.COMBAT)

	# Take damage during combat
	var critical_health = 10.0

	var health_check = priority_manager.on_health_low(critical_health)

	# Assert - should override combat with retreat
	assert_true(health_check.changed, "Should transition when health becomes critical")
	assert_eq(health_check.state, DronePriorityManager.AIState.RETREAT,
		"Should retreat when health critical, even during combat")
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.RETREAT,
		"Should now be in RETREAT state")

func test_squad_workflow_recovery_after_retreat():
	# Test full cycle: squad → combat → damaged → retreat → recover → squad

	# Phase 1: Combat
	var target = MockNode3DTarget.new()
	target# Position not needed for priority logic tests
	#.global_position = Vector3(100, 0, 0)
	target.valid = true
	test_targets.append(target)
	priority_manager.on_target_assigned(target)
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.COMBAT)

	# Phase 2: Damaged - enter retreat
	var critical_health = 10.0
	priority_manager.on_health_low(critical_health)
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.RETREAT)

	# Phase 3: Escape to safety (simulate moving far away)
	var safe_distance = 400.0  # Far from target
	var safety_transition = priority_manager.on_reached_safety(safe_distance)

	# Assert - should exit retreat when reaching safety
	assert_true(safety_transition.changed, "Should transition when reaching safety")
	assert_eq(safety_transition.state, DronePriorityManager.AIState.PART_OF_SQUAD,
		"Should return to PART_OF_SQUAD after reaching safety")

	# Phase 4: Recover health (already in PART_OF_SQUAD from safety, so no transition expected)
	var recovered_health = 50.0  # Above recovery threshold (30%)
	var recovery_check = priority_manager.on_health_recovered(recovered_health)

	# Should not change state since already back in PART_OF_SQUAD
	assert_false(recovery_check.changed, "Should not change state - already recovered via safety")
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.PART_OF_SQUAD,
		"Should be back in squad mode")

func test_squad_workflow_target_timeout():
	# Test that losing line of sight for too long returns to squad mode

	# Enter combat
	var target = MockNode3DTarget.new()
	target# Position not needed for priority logic tests
	#.global_position = Vector3(100, 0, 0)
	target.valid = true
	test_targets.append(target)
	priority_manager.on_target_assigned(target)
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.COMBAT)

	# Simulate losing target (no LOS) for extended period
	# We simulate losing LOS by not seeing the target, not by clearing it
	# The priority manager will track time since last saw target

	# Manually set the time_since_last_saw_target to simulate timeout
	# In a real scenario, the orchestrator would call update_target_tracking with no LOS
	var simulated_time_without_los = 11.0  # More than 10s timeout

	# Trigger the timeout
	var timeout_transition = priority_manager.on_target_lost_los_timeout(simulated_time_without_los)

	# After timeout, should return to squad
	assert_true(timeout_transition.changed, "Should transition after timeout")
	assert_eq(timeout_transition.state, DronePriorityManager.AIState.PART_OF_SQUAD,
		"Should return to PART_OF_SQUAD after target timeout")
	assert_eq(priority_manager.get_current_state(), DronePriorityManager.AIState.PART_OF_SQUAD,
		"Should return to squad after target timeout")
	assert_null(priority_manager.get_target(),
		"Target should be cleared after timeout")
