extends Node
class_name OrchestratorAI

## Orchestrator AI - Individual Drone AI Execution Layer
##
## This is the EXECUTION layer that:
## - Detects combat/health state
## - Reports events to DronePriorityManager
## - Executes states decided by priority manager
## - Commands PathfindingAI and CombatAI subsystems
##
## Decision-making is handled by DronePriorityManager
## This keeps orchestrator focused on execution, not policy

# Preload child AI classes
const PathfindingAIScript = preload("res://src/ai/drone/drone_pathfinding_ai.gd")
const CombatAIScript = preload("res://src/ai/drone/drone_combat_ai.gd")

# Type aliases (reference enums from DronePriorityManager)
const AIState = DronePriorityManager.AIState

## References
@export_node_path("RigidBody3D") var drone_path: NodePath
var drone: RigidBody3D
var patrol_waypoints: Array[Vector3] = []

## AI Configuration
const DEFAULT_FOV_DEG: float = 120.0
const DEFAULT_FLEE_THRESHOLD: float = 15.0
const DEFAULT_PATROL_SPEED: float = 0.4
const RETREAT_FLEE_DISTANCE: float = 100.0

var field_of_view_deg: float = DEFAULT_FOV_DEG
var flee_health_threshold: float = DEFAULT_FLEE_THRESHOLD
var patrol_speed_fraction: float = DEFAULT_PATROL_SPEED

## Squad membership (set by DroneSquad)
var parent_squad: Node = null
var is_squad_member: bool = false

## AI Systems
var priority_manager: DronePriorityManager = null
var pathfinding_ai: Node = null  # PathfindingAI
var combat_ai: Node = null  # CombatAI

## Component references (cached)
var health_system: Node
var hover_physics: Node
var initialized: bool = false
var ai_id: int = 0

## Configs received before _deferred_ready created the subsystems
var _pending_config: Dictionary = {}
var _pending_combat_config: Dictionary = {}

## Convenience property for squad compatibility
var target: Node3D:
	get:
		return priority_manager.target if priority_manager else null
	set(value):
		if priority_manager and value:
			priority_manager.on_target_assigned(value)

## Convenience property for squad compatibility
var current_state: AIState:
	get:
		return priority_manager.get_current_state() if priority_manager else AIState.PART_OF_SQUAD

func _ready() -> void:
	call_deferred("_deferred_ready")


func _deferred_ready() -> void:
	ai_id = randi() % 10000

	# Resolve drone NodePath
	if drone_path != NodePath():
		drone = get_node_or_null(drone_path) as RigidBody3D

	if not drone:
		push_error("[OrchestratorAI #%d] CRITICAL: No drone assigned! drone_path=%s" % [ai_id, drone_path])
		return

	# Cache component references
	health_system = drone.get_node_or_null("HealthSystem")
	if not health_system:
		push_warning("[OrchestratorAI #%d] Warning: No HealthSystem found" % ai_id)
	hover_physics = drone

	# Create priority manager first
	priority_manager = DronePriorityManager.new()
	priority_manager.name = "DronePriorityManager"
	add_child(priority_manager)
	priority_manager.initialize(drone, is_squad_member)

	# Create PathfindingAI
	pathfinding_ai = get_node_or_null("PathfindingAI")
	if not pathfinding_ai:
		pathfinding_ai = PathfindingAIScript.new()
		pathfinding_ai.name = "PathfindingAI"
		add_child(pathfinding_ai)

		if drone:
			pathfinding_ai.drone = drone
			pathfinding_ai.patrol_waypoints = patrol_waypoints
	else:
		if drone:
			pathfinding_ai.drone = drone
			pathfinding_ai.patrol_waypoints = patrol_waypoints

	if not pathfinding_ai:
		push_error("[OrchestratorAI #%d] CRITICAL: Failed to initialize PathfindingAI!" % ai_id)

	# Create CombatAI
	combat_ai = get_node_or_null("CombatAI")
	if not combat_ai:
		combat_ai = CombatAIScript.new()
		combat_ai.name = "CombatAI"
		add_child(combat_ai)

	if combat_ai and combat_ai.has_method("initialize") and drone:
		combat_ai.initialize(drone)
	else:
		push_error("[OrchestratorAI #%d] CRITICAL: Failed to initialize CombatAI!" % ai_id)

	# Apply configs that arrived before the subsystems existed
	if not _pending_config.is_empty():
		priority_manager.configure(_pending_config)
		_pending_config = {}
	if not _pending_combat_config.is_empty() and combat_ai and combat_ai.has_method("configure"):
		combat_ai.configure(_pending_combat_config)
		_pending_combat_config = {}

	initialized = true
	AIDebugLogger.log_decision(AIDebugLogger.drone_entity(drone), "Orchestrator",
		"initialized", "ai_ready", {
			"state": AIState.keys()[priority_manager.get_current_state()],
			"squad_member": is_squad_member
		})


func _physics_process(delta: float) -> void:
	if not initialized or not drone or not is_instance_valid(drone) or not priority_manager:
		return

	# Update target tracking in priority manager
	priority_manager.update_target_tracking(delta)

	# Detect state changes and report to priority manager
	_update_priorities(delta)

	# Execute current state
	_execute_current_state(delta)


# ============================================================================
# PRIORITY DETECTION & EVENT DISPATCH
# ============================================================================

func _update_priorities(delta: float) -> void:
	var current_target := priority_manager.get_target()

	# Validate current state
	var transition := priority_manager.validate_current_state()
	_apply_transition(transition)

	# Check health for retreat/recovery
	if health_system and is_instance_valid(health_system) and health_system.has_method("get_health_percentage"):
		var health_pct: float = health_system.get_health_percentage()

		match priority_manager.get_current_state():
			AIState.COMBAT:
				# Check for low health retreat
				if health_pct < flee_health_threshold:
					transition = priority_manager.on_health_low(health_pct)
					_apply_transition(transition)

			AIState.RETREAT:
				# Check for health recovery
				if health_pct >= flee_health_threshold * 2.0:
					transition = priority_manager.on_health_recovered(health_pct)
					_apply_transition(transition)
					return

				# Check if cornered (last stand)
				if current_target and is_instance_valid(current_target):
					var distance := drone.global_position.distance_to(current_target.global_position)
					if distance < priority_manager.cornered_distance and health_pct < priority_manager.last_stand_health:
						transition = priority_manager.on_cornered(distance, health_pct)
						_apply_transition(transition)
						return

					# Check if reached safety
					if distance > priority_manager.safe_retreat_distance:
						transition = priority_manager.on_reached_safety(distance)
						_apply_transition(transition)

	# Check LOS timeout (only in COMBAT)
	if priority_manager.get_current_state() == AIState.COMBAT:
		if combat_ai and is_instance_valid(combat_ai):
			var combat_los_time = combat_ai.get("time_since_last_los")
			if combat_los_time != null:
				transition = priority_manager.on_target_lost_los_timeout(combat_los_time)
				_apply_transition(transition)


# ============================================================================
# STATE EXECUTION
# ============================================================================

func _execute_current_state(delta: float) -> void:
	match priority_manager.get_current_state():
		AIState.PART_OF_SQUAD:
			_execute_part_of_squad(delta)
		AIState.COMBAT:
			_execute_combat(delta)
		AIState.RETREAT:
			_execute_retreat(delta)


func _execute_part_of_squad(delta: float) -> void:
	# Passive state - squad controls PathfindingAI
	# Just wait for squad to assign target via priority_manager.on_target_assigned()
	pass


func _execute_combat(delta: float) -> void:
	var current_target := priority_manager.get_target()

	if not current_target or not is_instance_valid(current_target):
		return

	# Delegate to combat AI
	if combat_ai and is_instance_valid(combat_ai) and combat_ai.has_method("update_combat"):
		combat_ai.update_combat(delta, current_target)
	else:
		push_error("[OrchestratorAI #%d] CombatAI is null or invalid during combat" % ai_id)


func _execute_retreat(delta: float) -> void:
	if not drone or not is_instance_valid(drone):
		return

	var current_target := priority_manager.get_target()

	# Flee from target
	if pathfinding_ai and is_instance_valid(pathfinding_ai):
		if current_target and is_instance_valid(current_target):
			var flee_direction := (drone.global_position - current_target.global_position).normalized()
			var flee_target := drone.global_position + flee_direction * RETREAT_FLEE_DISTANCE
			pathfinding_ai.patrol_mode = false
			pathfinding_ai.set_target(flee_target, true)
			pathfinding_ai.speed_fraction = 1.0
		else:
			# No target - flee in random direction
			var random_dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			var flee_target := drone.global_position + random_dir * RETREAT_FLEE_DISTANCE
			pathfinding_ai.patrol_mode = false
			pathfinding_ai.set_target(flee_target, true)
			pathfinding_ai.speed_fraction = 1.0


# ============================================================================
# TRANSITION APPLICATION
# ============================================================================

func _apply_transition(transition: Dictionary) -> void:
	if not transition.changed:
		return

	# Handle state entry/exit (DronePriorityManager already logged the
	# transition itself with its reason)
	_on_state_change(transition.state)


func _on_state_change(new_state: AIState) -> void:
	match new_state:
		AIState.PART_OF_SQUAD:
			# PathfindingAI will be controlled by DroneSquad
			# Exit combat if we were in it
			if combat_ai and is_instance_valid(combat_ai) and combat_ai.has_method("exit_combat"):
				combat_ai.exit_combat()

		AIState.COMBAT:
			# Enter combat mode
			if combat_ai and is_instance_valid(combat_ai) and combat_ai.has_method("enter_combat"):
				combat_ai.enter_combat(priority_manager.get_target())

		AIState.RETREAT:
			# Exit combat if we were in it
			if combat_ai and is_instance_valid(combat_ai) and combat_ai.has_method("exit_combat"):
				combat_ai.exit_combat()


# ============================================================================
# PUBLIC API (for squad compatibility)
# ============================================================================

func transition_to_state(new_state: AIState) -> void:
	"""Public method for squad to command state transitions"""
	if new_state == priority_manager.get_current_state():
		return

	AIDebugLogger.log_decision(AIDebugLogger.drone_entity(drone), "Orchestrator",
		"forced_state:%s" % AIState.keys()[new_state], "squad_command")

	# Force state transition
	priority_manager.current_state = new_state
	_on_state_change(new_state)


func configure(config: Dictionary) -> void:
	"""Configure AI parameters"""
	if config.has("field_of_view_deg"):
		field_of_view_deg = config.field_of_view_deg
	if config.has("flee_health_threshold"):
		flee_health_threshold = config.flee_health_threshold
	if config.has("patrol_speed_fraction"):
		patrol_speed_fraction = config.patrol_speed_fraction

	# Pass config to priority manager (or queue it until _deferred_ready)
	if priority_manager:
		priority_manager.configure(config)
	else:
		_pending_config = config


func configure_combat(config: Dictionary) -> void:
	"""Configure combat AI parameters (queued if CombatAI not created yet)"""
	if combat_ai and is_instance_valid(combat_ai) and combat_ai.has_method("configure"):
		combat_ai.configure(config)
	else:
		_pending_combat_config = config
