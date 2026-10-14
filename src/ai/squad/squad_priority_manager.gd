extends Node
class_name SquadPriorityManager

## SquadPriorityManager - Event-driven goal priority system
##
## Responsibilities:
## - Evaluate which goal should be active based on current state
## - Handle interrupt/resume logic for high-priority goals
## - Maintain single source of truth for squad's strategic intent
##
## Design:
## - Event-driven: React to world events (enemies, cargo full, etc.)
## - Stateless decisions: Pure functions based on current state
## - Clear priority hierarchy: 0=URGENT, 1=HIGH, 2=MEDIUM, 3=LOW

# Goal types (must match SquadOrchestratorAI.AIGoal)
enum AIGoal {
	MOVE_TO,
	GATHER_RESOURCE,
	ATTACK,
	RETREAT
}

enum MoveToTarget {
	RESOURCE,
	MOTHERSHIP
}

# Priority levels
enum Priority {
	URGENT = 0,    # Combat/survival (ATTACK, RETREAT)
	HIGH = 1,      # Critical operations (cargo full, damage)
	MEDIUM = 2,    # Normal operations
	LOW = 3        # Idle/patrol
}

## Current goal state
var current_goal: AIGoal = AIGoal.MOVE_TO
var current_priority: int = Priority.LOW
var move_to_target_type: MoveToTarget = MoveToTarget.RESOURCE

## Goal targets
var target_position: Vector3 = Vector3.ZERO
var target_poi: Node3D = null
var target_mothership: Node3D = null
var target_enemy_squad: Node3D = null

## Interrupt state (for resuming after high-priority goals)
var interrupted_goal: AIGoal = AIGoal.MOVE_TO
var interrupted_priority: int = Priority.LOW
var interrupted_move_to_target: MoveToTarget = MoveToTarget.RESOURCE
var interrupted_target_position: Vector3 = Vector3.ZERO
var interrupted_target_poi: Node3D = null
var interrupted_target_mothership: Node3D = null

## Squad context (references for decision-making)
var squad: Node3D = null
var faction_id: int = -1
var starting_squad_size: int = 0

## Decision flags
var _has_interrupted_goal: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func initialize(p_squad: Node3D, p_faction_id: int, p_starting_size: int) -> void:
	squad = p_squad
	faction_id = p_faction_id
	starting_squad_size = p_starting_size


func _entity() -> String:
	## Logging identity for this squad
	if squad and is_instance_valid(squad) and "squad_id" in squad:
		return AIDebugLogger.squad_entity(squad.squad_id)
	return "squad:?"

# ============================================================================
# EVENT HANDLERS - World events that may change priority
# ============================================================================

## Called when enemies are detected in range
func on_enemies_detected(enemies: Array, should_flee: bool) -> Dictionary:
	# Determine if we should attack or retreat
	var new_goal: AIGoal = AIGoal.RETREAT if should_flee else AIGoal.ATTACK

	# Save interrupted goal if this is a new combat engagement
	if current_goal != AIGoal.ATTACK and current_goal != AIGoal.RETREAT:
		_save_interrupted_goal()

	# Set high-priority combat goal
	return _create_goal_transition(new_goal, Priority.URGENT, {
		"reason": "fleeing_superior_enemies" if should_flee else "engaging_enemies",
		"enemy_count": enemies.size(),
		"target_enemy_squad": enemies[0] if enemies.size() > 0 else null
	})


## Called when cargo becomes full during mining
func on_cargo_full(nearest_mothership: Node3D) -> Dictionary:
	# Interrupt current goal to return home
	if current_goal != AIGoal.MOVE_TO or move_to_target_type != MoveToTarget.MOTHERSHIP:
		# Only save interrupt if we're not already going to mothership
		if current_goal == AIGoal.GATHER_RESOURCE:
			_save_interrupted_goal()

	return _create_goal_transition(AIGoal.MOVE_TO, Priority.HIGH, {
		"reason": "cargo_full_returning_home",
		"move_to_target_type": MoveToTarget.MOTHERSHIP,
		"target_mothership": nearest_mothership,
		"target_position": nearest_mothership.global_position if nearest_mothership else Vector3.ZERO
	})


## Called when reached destination
func on_reached_destination() -> Dictionary:
	match current_goal:
		AIGoal.MOVE_TO:
			return _handle_move_to_arrival()
		AIGoal.RETREAT:
			# Reached safety, resume interrupted goal or go back to gathering
			return _resume_or_default("reached_safety")
		_:
			return _create_no_change()


## Called when POI is depleted
func on_poi_depleted() -> Dictionary:
	if current_goal == AIGoal.GATHER_RESOURCE:
		# Transition to finding new resource
		return _create_goal_transition(AIGoal.MOVE_TO, Priority.MEDIUM, {
			"reason": "poi_depleted_find_new",
			"move_to_target_type": MoveToTarget.RESOURCE,
			"target_poi": null
		})
	return _create_no_change()


## Called when enemies are cleared (no longer in detection range)
func on_enemies_cleared() -> Dictionary:
	if current_goal == AIGoal.ATTACK or current_goal == AIGoal.RETREAT:
		# Combat over, resume interrupted goal or return to gathering
		return _resume_or_default("enemies_cleared")
	return _create_no_change()


## Called when resources delivered to mothership
func on_resources_delivered() -> Dictionary:
	# Go back to gathering resources
	return _create_goal_transition(AIGoal.MOVE_TO, Priority.LOW, {
		"reason": "resources_delivered",
		"move_to_target_type": MoveToTarget.RESOURCE,
		"target_poi": null
	})


## Called when squad should check if goal is still valid
func validate_current_goal() -> Dictionary:
	# Check if targets are still valid
	match current_goal:
		AIGoal.MOVE_TO:
			if move_to_target_type == MoveToTarget.RESOURCE:
				if target_poi and not is_instance_valid(target_poi):
					return _create_goal_transition(AIGoal.MOVE_TO, current_priority, {
						"reason": "target_poi_freed_find_new",
						"move_to_target_type": MoveToTarget.RESOURCE,
						"target_poi": null
					})

		AIGoal.GATHER_RESOURCE:
			if not target_poi or not is_instance_valid(target_poi):
				return _create_goal_transition(AIGoal.MOVE_TO, Priority.MEDIUM, {
					"reason": "gather_target_invalid_find_new",
					"move_to_target_type": MoveToTarget.RESOURCE,
					"target_poi": null
				})

		AIGoal.ATTACK:
			if not target_enemy_squad or not is_instance_valid(target_enemy_squad):
				# Enemy destroyed, check for other enemies or resume
				return on_enemies_cleared()

	return _create_no_change()

# ============================================================================
# GOAL TRANSITION LOGIC
# ============================================================================

func _handle_move_to_arrival() -> Dictionary:
	match move_to_target_type:
		MoveToTarget.RESOURCE:
			# Arrived at resource, start gathering
			return _create_goal_transition(AIGoal.GATHER_RESOURCE, Priority.MEDIUM, {
				"reason": "arrived_at_resource",
				"target_poi": target_poi
			})

		MoveToTarget.MOTHERSHIP:
			# Arrived at mothership, resources will be delivered
			# Transition will come from on_resources_delivered()
			return _create_no_change()

	return _create_no_change()


func _resume_or_default(trigger: String) -> Dictionary:
	if _has_interrupted_goal:
		return _resume_interrupted_goal(trigger)
	else:
		# No interrupted goal, default to gathering
		return _create_goal_transition(AIGoal.MOVE_TO, Priority.LOW, {
			"reason": "%s_default_to_gathering" % trigger,
			"move_to_target_type": MoveToTarget.RESOURCE,
			"target_poi": null
		})

# ============================================================================
# INTERRUPT MANAGEMENT
# ============================================================================

func _save_interrupted_goal() -> void:
	# Don't interrupt combat goals
	if current_goal == AIGoal.ATTACK or current_goal == AIGoal.RETREAT:
		return

	# Save current state
	interrupted_goal = current_goal
	interrupted_priority = current_priority
	interrupted_move_to_target = move_to_target_type
	interrupted_target_position = target_position
	interrupted_target_poi = target_poi
	interrupted_target_mothership = target_mothership
	_has_interrupted_goal = true

	AIDebugLogger.log_decision(_entity(), "SquadPriority", "goal_interrupted",
		"higher_priority_goal", {
			"saved_goal": AIGoal.keys()[interrupted_goal],
			"saved_priority": interrupted_priority
		})


func _resume_interrupted_goal(trigger: String) -> Dictionary:
	if not _has_interrupted_goal:
		return _create_no_change()

	# Validate that interrupted goal is still valid
	var is_valid := _validate_interrupted_goal()

	if is_valid:
		# Create transition to interrupted goal
		var transition: Dictionary = _create_goal_transition(interrupted_goal, interrupted_priority, {
			"reason": "%s_resume_interrupted" % trigger,
			"move_to_target_type": interrupted_move_to_target,
			"target_position": interrupted_target_position,
			"target_poi": interrupted_target_poi,
			"target_mothership": interrupted_target_mothership
		})

		# Clear interrupt state
		_clear_interrupted_goal()

		return transition
	else:
		_clear_interrupted_goal()

		# Fall back to default (gathering)
		return _create_goal_transition(AIGoal.MOVE_TO, Priority.LOW, {
			"reason": "%s_interrupted_goal_invalid_default_to_gathering" % trigger,
			"move_to_target_type": MoveToTarget.RESOURCE,
			"target_poi": null
		})


func _validate_interrupted_goal() -> bool:
	match interrupted_goal:
		AIGoal.MOVE_TO:
			if interrupted_move_to_target == MoveToTarget.RESOURCE:
				if interrupted_target_poi:
					return is_instance_valid(interrupted_target_poi)
				return true  # Will find new POI
			elif interrupted_move_to_target == MoveToTarget.MOTHERSHIP:
				return interrupted_target_mothership != null and is_instance_valid(interrupted_target_mothership)

		AIGoal.GATHER_RESOURCE:
			return interrupted_target_poi != null and is_instance_valid(interrupted_target_poi)

	return true


func _clear_interrupted_goal() -> void:
	interrupted_goal = AIGoal.MOVE_TO
	interrupted_priority = Priority.LOW
	interrupted_move_to_target = MoveToTarget.RESOURCE
	interrupted_target_position = Vector3.ZERO
	interrupted_target_poi = null
	interrupted_target_mothership = null
	_has_interrupted_goal = false

# ============================================================================
# GOAL TRANSITION HELPERS
# ============================================================================

func _create_goal_transition(new_goal: AIGoal, priority: int, params: Dictionary) -> Dictionary:
	var old_goal := current_goal
	var changed := (new_goal != current_goal) or (priority != current_priority)

	# Apply transition
	current_goal = new_goal
	current_priority = priority

	# Update targets from params
	if params.has("move_to_target_type"):
		move_to_target_type = params.move_to_target_type
	if params.has("target_position"):
		target_position = params.target_position
	if params.has("target_poi"):
		target_poi = params.target_poi
	if params.has("target_mothership"):
		target_mothership = params.target_mothership
	if params.has("target_enemy_squad"):
		target_enemy_squad = params.target_enemy_squad

	if changed:
		var data := params.duplicate()
		data.erase("reason")
		data.erase("move_to_target_type")
		data["from"] = AIGoal.keys()[old_goal]
		data["priority"] = priority
		AIDebugLogger.log_decision(_entity(), "SquadPriority",
			"goal:%s" % AIGoal.keys()[new_goal],
			params.get("reason", "unknown"), data)

	return {
		"changed": changed,
		"goal": new_goal,
		"priority": priority,
		"move_to_target_type": move_to_target_type,
		"target_position": target_position,
		"target_poi": target_poi,
		"target_mothership": target_mothership,
		"target_enemy_squad": target_enemy_squad
	}


func _create_no_change() -> Dictionary:
	return {
		"changed": false,
		"goal": current_goal,
		"priority": current_priority,
		"move_to_target_type": move_to_target_type,
		"target_position": target_position,
		"target_poi": target_poi,
		"target_mothership": target_mothership,
		"target_enemy_squad": target_enemy_squad
	}

# ============================================================================
# PUBLIC API - Query current state
# ============================================================================

func get_current_goal() -> AIGoal:
	return current_goal


func get_current_priority() -> int:
	return current_priority


func get_move_to_target_type() -> MoveToTarget:
	return move_to_target_type


func get_target_info() -> Dictionary:
	return {
		"position": target_position,
		"poi": target_poi,
		"mothership": target_mothership,
		"enemy_squad": target_enemy_squad
	}


func has_interrupted_goal() -> bool:
	return _has_interrupted_goal
