extends Node
class_name DronePriorityManager

## DronePriorityManager - Event-driven state priority system for individual drones
##
## Responsibilities:
## - Evaluate which tactical state should be active
## - Handle state transitions based on combat/health/squad events
## - Maintain single source of truth for drone's tactical intent
##
## Design:
## - Event-driven: React to combat events (target assigned, health low, etc.)
## - Stateless decisions: Pure functions based on current state
## - Clear state hierarchy: PART_OF_SQUAD → COMBAT → RETREAT

# State types
enum AIState {
	PART_OF_SQUAD,  # Following squad commands
	COMBAT,         # Individual combat engagement
	RETREAT         # Panic/flee mode
}

# Configuration constants
const DEFAULT_FLEE_THRESHOLD: float = 15.0  # Health % to trigger retreat
const DEFAULT_RECOVERY_MULTIPLIER: float = 2.0  # Health % multiplier to exit retreat
const DEFAULT_TARGET_LOST_TIMEOUT: float = 10.0  # Seconds before forgetting target
const DEFAULT_SAFE_RETREAT_DISTANCE: float = 300.0  # Distance to be "safe"
const DEFAULT_CORNERED_DISTANCE: float = 50.0  # Distance threshold for "cornered"
const DEFAULT_LAST_STAND_HEALTH: float = 10.0  # Health % for desperate last stand

## Current state
var current_state: AIState = AIState.PART_OF_SQUAD
var target: Node3D = null
var time_since_last_saw_target: float = 0.0

## Configuration
var flee_health_threshold: float = DEFAULT_FLEE_THRESHOLD
var recovery_health_threshold: float = DEFAULT_FLEE_THRESHOLD * DEFAULT_RECOVERY_MULTIPLIER
var target_lost_timeout: float = DEFAULT_TARGET_LOST_TIMEOUT
var safe_retreat_distance: float = DEFAULT_SAFE_RETREAT_DISTANCE
var cornered_distance: float = DEFAULT_CORNERED_DISTANCE
var last_stand_health: float = DEFAULT_LAST_STAND_HEALTH

## Squad membership
var is_squad_member: bool = false
var parent_squad: Node = null

## Drone context (references for decision-making)
var drone: RigidBody3D = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(p_drone: RigidBody3D, p_is_squad_member: bool = false) -> void:
	drone = p_drone
	is_squad_member = p_is_squad_member


func configure(config: Dictionary) -> void:
	"""Apply configuration settings"""
	if config.has("flee_health_threshold"):
		flee_health_threshold = config.flee_health_threshold
		recovery_health_threshold = flee_health_threshold * DEFAULT_RECOVERY_MULTIPLIER

	if config.has("target_lost_timeout"):
		target_lost_timeout = config.target_lost_timeout

	if config.has("safe_retreat_distance"):
		safe_retreat_distance = config.safe_retreat_distance

	if config.has("cornered_distance"):
		cornered_distance = config.cornered_distance

	if config.has("last_stand_health"):
		last_stand_health = config.last_stand_health

# ============================================================================
# EVENT HANDLERS - Combat/health events that may change state
# ============================================================================

## Called when squad assigns a combat target
func on_target_assigned(p_target: Node3D) -> Dictionary:
	if p_target != target:
		AIDebugLogger.log_decision(AIDebugLogger.drone_entity(drone), "DronePriority",
			"target_switched", "target_assigned", {"old": target, "new": p_target})

	target = p_target
	time_since_last_saw_target = 0.0

	# Only transition to COMBAT if we're in PART_OF_SQUAD
	# (Don't override RETREAT state)
	if current_state == AIState.PART_OF_SQUAD:
		return _create_state_transition(AIState.COMBAT, {
			"reason": "target_assigned",
			"target": target
		})

	return _create_no_change()


## Called when target becomes invalid (freed, despawned)
func on_target_invalid() -> Dictionary:
	# Clear target
	var old_target := target
	target = null
	time_since_last_saw_target = 0.0

	# Return to squad control
	if current_state == AIState.COMBAT and is_squad_member:
		return _create_state_transition(AIState.PART_OF_SQUAD, {
			"reason": "target_invalid",
			"old_target": old_target
		})

	return _create_no_change()


## Called when target is eliminated (killed)
func on_target_eliminated() -> Dictionary:
	# Clear target
	var old_target := target
	target = null
	time_since_last_saw_target = 0.0

	# Return to squad control
	if current_state == AIState.COMBAT and is_squad_member:
		return _create_state_transition(AIState.PART_OF_SQUAD, {
			"reason": "target_eliminated",
			"old_target": old_target
		})

	return _create_no_change()


## Called when target lost LOS for too long
func on_target_lost_los_timeout(time_without_los: float) -> Dictionary:
	# Only act if timeout exceeded
	if time_without_los < target_lost_timeout:
		return _create_no_change()

	# Clear target
	var old_target := target
	target = null
	time_since_last_saw_target = 0.0

	# Return to squad control if squad member
	if current_state == AIState.COMBAT and is_squad_member:
		return _create_state_transition(AIState.PART_OF_SQUAD, {
			"reason": "target_lost_los",
			"time_without_los": time_without_los
		})

	# Autonomous drones stay in COMBAT and scan for new targets
	return _create_no_change()


## Called when health drops below threshold during combat
func on_health_low(health_pct: float) -> Dictionary:
	# Only trigger retreat if health is actually low
	if health_pct >= flee_health_threshold:
		return _create_no_change()

	# Transition to RETREAT from COMBAT
	if current_state == AIState.COMBAT:
		return _create_state_transition(AIState.RETREAT, {
			"reason": "health_low",
			"health_pct": health_pct
		})

	return _create_no_change()


## Called when health recovers during retreat
func on_health_recovered(health_pct: float) -> Dictionary:
	# Only trigger recovery if health is actually recovered
	if health_pct < recovery_health_threshold:
		return _create_no_change()

	# Exit RETREAT state
	if current_state == AIState.RETREAT:
		# Return to squad or combat depending on membership
		var new_state := AIState.PART_OF_SQUAD if is_squad_member else AIState.COMBAT
		return _create_state_transition(new_state, {
			"reason": "health_recovered",
			"health_pct": health_pct
		})

	return _create_no_change()


## Called when drone reaches safe distance during retreat
func on_reached_safety(distance_to_threat: float) -> Dictionary:
	# Only trigger if actually safe
	if distance_to_threat < safe_retreat_distance:
		return _create_no_change()

	# Exit RETREAT state
	if current_state == AIState.RETREAT:
		# Return to squad or combat depending on membership
		var new_state := AIState.PART_OF_SQUAD if is_squad_member else AIState.COMBAT
		return _create_state_transition(new_state, {
			"reason": "reached_safety",
			"distance": distance_to_threat
		})

	return _create_no_change()


## Called when drone is cornered (close to enemy, low health)
func on_cornered(distance_to_threat: float, health_pct: float) -> Dictionary:
	# Only trigger if actually cornered
	if distance_to_threat >= cornered_distance or health_pct >= last_stand_health:
		return _create_no_change()

	# Last stand: fight instead of fleeing
	if current_state == AIState.RETREAT:
		return _create_state_transition(AIState.COMBAT, {
			"reason": "cornered_last_stand",
			"distance": distance_to_threat,
			"health_pct": health_pct
		})

	return _create_no_change()


## Update target tracking (call every frame)
func update_target_tracking(delta: float) -> void:
	if target and is_instance_valid(target):
		time_since_last_saw_target = 0.0
	else:
		time_since_last_saw_target += delta


## Validate current state and target
func validate_current_state() -> Dictionary:
	# Check if target is still valid
	if target and not is_instance_valid(target):
		return on_target_invalid()

	# Check if target is dead
	if target and is_instance_valid(target):
		var target_health = target.get_node_or_null("HealthSystem")
		if target_health and "is_alive" in target_health and not target_health.is_alive:
			return on_target_eliminated()

	return _create_no_change()

# ============================================================================
# STATE TRANSITION LOGIC
# ============================================================================

func _create_state_transition(new_state: AIState, params: Dictionary) -> Dictionary:
	var changed := (new_state != current_state)

	if changed:
		var data := params.duplicate()
		data.erase("reason")
		data["from"] = AIState.keys()[current_state]
		AIDebugLogger.log_decision(AIDebugLogger.drone_entity(drone), "DronePriority",
			"state:%s" % AIState.keys()[new_state],
			params.get("reason", "unknown"), data)

		current_state = new_state

	return {
		"changed": changed,
		"state": new_state,
		"reason": params.get("reason", ""),
		"target": target,
		"params": params
	}


func _create_no_change() -> Dictionary:
	return {
		"changed": false,
		"state": current_state,
		"reason": "",
		"target": target,
		"params": {}
	}

# ============================================================================
# PUBLIC API - Query current state
# ============================================================================

func get_current_state() -> AIState:
	return current_state


func get_target() -> Node3D:
	return target


func get_time_since_last_saw_target() -> float:
	return time_since_last_saw_target


func should_flee_from_combat(health_pct: float) -> bool:
	"""Check if drone should enter retreat state"""
	return health_pct < flee_health_threshold


func should_exit_retreat(health_pct: float) -> bool:
	"""Check if drone should exit retreat state"""
	return health_pct >= recovery_health_threshold


func is_in_retreat() -> bool:
	return current_state == AIState.RETREAT


func is_in_combat() -> bool:
	return current_state == AIState.COMBAT


func is_following_squad() -> bool:
	return current_state == AIState.PART_OF_SQUAD
