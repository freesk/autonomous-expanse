extends Node
# CombatAI - No class_name to avoid conflicts, use preload instead

## Combat AI - Coordinates combat behavior
## Signals pathfinding_ai and weapon_ai
## Attempts to find line of fire and destroy the player

# Preload child AI classes
const WeaponAIScript = preload("res://src/ai/drone/drone_weapon_ai.gd")

# NEW: Preload testable AI brain
const DroneCombatBrain = preload("res://scripts/ai/brains/drone_combat_brain.gd")

## References
var drone: RigidBody3D = null
var target: Node3D = null

## Configuration (set by orchestrator based on drone type)
const DEFAULT_OPTIMAL_RANGE: float = 60.0
const DEFAULT_MIN_RANGE: float = 10.0  # Reduced to be more aggressive
const DEFAULT_MAX_RANGE: float = 100.0
const DEFAULT_COMBAT_SPEED: float = 0.8
const STRAFE_OFFSET_DISTANCE: float = 20.0
const RETREAT_DISTANCE: float = 50.0
const SAFE_DISTANCE: float = 300.0
const CORNERED_DISTANCE: float = 50.0
const LOS_LOST_TIMEOUT: float = 10.0
const JUMP_OBSTACLE_TIMEOUT: float = 3.0

var optimal_weapon_range: float = DEFAULT_OPTIMAL_RANGE
var min_weapon_range: float = DEFAULT_MIN_RANGE
var max_weapon_range: float = DEFAULT_MAX_RANGE
var combat_speed_fraction: float = DEFAULT_COMBAT_SPEED

## Combat state
var has_line_of_sight: bool = false
var time_since_last_los: float = 0.0
var current_combat_behavior: String = "chase"  # chase, strafe, maintain
var jump_cooldown_timer: float = 0.0
const JUMP_COOLDOWN: float = 4.0  # Wait 4 seconds between climb attempts (matches climb duration + margin)

## Performance optimization for LOS checks
const LOS_CHECK_INTERVAL: float = 0.2  # Check LOS 5 times per second instead of every frame
var los_check_timer: float = 0.0

## Logging throttle
var log_timer: float = 0.0
const LOG_INTERVAL: float = 2.0  # Log pursuit every 2 seconds

## Child AI components
var pathfinding_ai: Node = null  # Reference to parent's PathfindingAI
var weapon_ai: Node = null  # WeaponAI

## Component references (cached during initialization to avoid repeated lookups)
var hover_physics: Node = null
var energy_system: Node = null
var motion_controller: Node = null

## Energy management
var min_energy_for_weapons: float = 5.0  # Reserve only 5% energy - be aggressive with weapons
var critical_energy_threshold: float = 3.0  # Below 3% = critical energy state

## Testable AI brain (created eagerly so configure() works before initialize())
var combat_brain: DroneCombatBrain = DroneCombatBrain.new()

func initialize(p_drone: RigidBody3D) -> void:
	if not p_drone:
		push_error("[CombatAI] CRITICAL: No drone provided to initialize()")
		return

	drone = p_drone

	# Get pathfinding from parent (orchestrator)
	if get_parent() and get_parent().get("pathfinding_ai"):
		pathfinding_ai = get_parent().get("pathfinding_ai")
	else:
		push_error("[CombatAI] CRITICAL: PathfindingAI not found in parent OrchestratorAI!")

	# Create child combat components
	_setup_weapon_ai()

	# Cache component references to avoid repeated get_node_or_null calls
	if drone:
		hover_physics = drone
		energy_system = drone.get_node_or_null("EnergySystem")
		motion_controller = drone.get_node_or_null("MotionController")
		if not energy_system:
			push_warning("[CombatAI] Warning: No EnergySystem found on drone")
		if not motion_controller:
			push_warning("[CombatAI] Warning: No MotionController found on drone")

	# Sync brain ranges with this drone's configured weapon ranges so the
	# brain's decisions match the drone's actual capabilities
	_sync_brain_config()

func _setup_weapon_ai() -> void:
	weapon_ai = get_node_or_null("WeaponAI")
	if not weapon_ai:
		weapon_ai = WeaponAIScript.new()
		weapon_ai.name = "WeaponAI"
		add_child(weapon_ai)

	if weapon_ai and weapon_ai.has_method("initialize"):
		weapon_ai.initialize(drone)
		# Enable weapons for AI-controlled drones
		if weapon_ai.has_method("enable_weapons"):
			weapon_ai.enable_weapons(true)
	else:
		push_warning("[CombatAI] Warning: WeaponAI failed to initialize")

## COMBAT UPDATE (called by orchestrator)
func update_combat(delta: float, p_target: Node3D) -> void:
	target = p_target

	if not target or not is_instance_valid(target) or not drone or not is_instance_valid(drone):
		if target and not is_instance_valid(target):
			target = null  # Clear freed reference
		return

	# Update timers
	log_timer += delta
	jump_cooldown_timer = max(0.0, jump_cooldown_timer - delta)
	los_check_timer += delta

	# Check current energy level
	var current_energy_pct = _get_energy_percentage()

	# Cache LOS checks - only check every LOS_CHECK_INTERVAL (0.2s = 5 checks/sec instead of 60/sec)
	# This reduces raycast count by 92%
	if los_check_timer >= LOS_CHECK_INTERVAL:
		has_line_of_sight = _check_line_of_sight()
		los_check_timer = 0.0

	if has_line_of_sight:
		time_since_last_los = 0.0
	else:
		time_since_last_los += delta

	# Get distance to target
	var distance = drone.global_position.distance_to(target.global_position)

	# Determine combat behavior (energy-aware)
	_determine_combat_behavior(distance, current_energy_pct)

	# PRIORITY 1: Execute combat movement (always prioritize pathfinding)
	# Disable pathfinding rotation when we have LOS - CombatAI will handle aiming
	if pathfinding_ai and is_instance_valid(pathfinding_ai):
		pathfinding_ai.combat_mode_los = has_line_of_sight
	_execute_combat_movement(delta, distance, current_energy_pct)

	# PRIORITY 2: Signal weapon AI to fire ONLY if we have enough energy
	# Weapons are secondary to movement - only fire if we can afford it
	var can_fire_weapons = current_energy_pct >= min_energy_for_weapons
	var should_fire = has_line_of_sight and can_fire_weapons

	# Log combat status occasionally (throttled by the logger)
	AIDebugLogger.log_status(AIDebugLogger.drone_entity(drone), "CombatAI", "combat_status", {
		"behavior": current_combat_behavior,
		"energy_pct": current_energy_pct,
		"weapons": "OK" if can_fire_weapons else "LOW_ENERGY",
		"has_los": has_line_of_sight
	}, 5.0)

	if weapon_ai and is_instance_valid(weapon_ai) and weapon_ai.has_method("update_targeting"):
		weapon_ai.update_targeting(delta, target, should_fire)

	# CRITICAL: Override pathfinding rotation with weapon aim during combat
	# This ensures the drone faces the target to shoot, not the movement direction
	if has_line_of_sight and target and is_instance_valid(target):
		if motion_controller and motion_controller.has_method("set_ai_look_target"):
			motion_controller.set_ai_look_target(target.global_position)

## LINE OF SIGHT CHECK
func _check_line_of_sight() -> bool:
	if not drone or not is_instance_valid(drone) or not target or not is_instance_valid(target):
		return false

	var space_state = drone.get_world_3d().direct_space_state
	if not space_state:
		return false

	# Raycast from drone to target
	var query = PhysicsRayQueryParameters3D.create(
		drone.global_position,
		target.global_position
	)
	query.exclude = [drone]

	var result = space_state.intersect_ray(query)

	# If we hit the target directly, we have LOS (validate collider is still valid)
	if result and result.has("collider") and is_instance_valid(result.collider) and result.collider == target:
		return true

	# If nothing hit, we have LOS
	if not result:
		return true

	return false

## COMBAT BEHAVIOR DETERMINATION (Using testable AI brain)
func _determine_combat_behavior(distance: float, energy_pct: float) -> void:
	var old_behavior = current_combat_behavior

	# Use testable DroneCombatBrain
	var health_pct = _get_health_percentage()
	var behavior_enum = combat_brain.decide_combat_behavior(
		has_line_of_sight,
		distance,
		health_pct,
		energy_pct
	)

	# Map enum to string for compatibility with existing system
	match behavior_enum:
		DroneCombatBrain.CombatBehavior.CHASE:
			current_combat_behavior = "chase"
		DroneCombatBrain.CombatBehavior.STRAFE:
			current_combat_behavior = "strafe"
		DroneCombatBrain.CombatBehavior.RETREAT_FIRE:
			current_combat_behavior = "retreat"
		DroneCombatBrain.CombatBehavior.DISENGAGE:
			current_combat_behavior = "retreat"

	# Log behavior changes with the inputs that drove the decision
	if old_behavior != current_combat_behavior:
		AIDebugLogger.log_decision(AIDebugLogger.drone_entity(drone), "CombatAI",
			current_combat_behavior,
			"brain_decision:%s" % DroneCombatBrain.CombatBehavior.keys()[behavior_enum],
			{
				"distance": distance,
				"has_los": has_line_of_sight,
				"health_pct": health_pct,
				"energy_pct": energy_pct,
				"target": target
			})

## COMBAT MOVEMENT EXECUTION (Energy-Aware)
func _execute_combat_movement(delta: float, distance: float, energy_pct: float) -> void:
	if not pathfinding_ai or not is_instance_valid(pathfinding_ai):
		push_error("[CombatAI] PathfindingAI is null or invalid during combat movement")
		return

	match current_combat_behavior:
		"chase":
			_behavior_chase(energy_pct)
		"strafe":
			_behavior_strafe(delta, energy_pct)
		"maintain":
			_behavior_maintain(energy_pct)
		"retreat":
			_behavior_retreat(energy_pct)

## CHASE: Move toward target to find line of fire
func _behavior_chase(energy_pct: float) -> void:
	if not target or not is_instance_valid(target):
		return

	# Move directly toward target
	if pathfinding_ai and is_instance_valid(pathfinding_ai) and pathfinding_ai.has_method("set_target"):
		pathfinding_ai.set_target(target.global_position)
	else:
		push_error("[CombatAI] PathfindingAI not available for set_target!")

	# Log pursuit behavior (throttled)
	if not has_line_of_sight and log_timer >= LOG_INTERVAL:
		var distance = drone.global_position.distance_to(target.global_position)
		AIDebugLogger.log_status(AIDebugLogger.drone_entity(drone), "CombatAI", "pursuing_without_los", {
			"target": target,
			"distance": distance,
			"seconds_without_los": time_since_last_los
		}, LOG_INTERVAL)
		log_timer = 0.0

	# Full combat speed
	if pathfinding_ai and is_instance_valid(pathfinding_ai) and pathfinding_ai.has_method("set_speed_fraction"):
		pathfinding_ai.set_speed_fraction(combat_speed_fraction)

## STRAFE: Circle target while maintaining distance
func _behavior_strafe(delta: float, energy_pct: float) -> void:
	if not target or not is_instance_valid(target) or not drone or not is_instance_valid(drone):
		return

	# Calculate strafe position (circle around target)
	var to_drone = (drone.global_position - target.global_position).normalized()
	var strafe_direction = to_drone.rotated(Vector3.UP, PI / 2.0)  # 90 degrees

	var strafe_target = target.global_position + to_drone * optimal_weapon_range + strafe_direction * STRAFE_OFFSET_DISTANCE

	pathfinding_ai.set_target(strafe_target)

	# Normal strafe speed
	var speed = combat_speed_fraction * 0.7
	pathfinding_ai.set_speed_fraction(speed)

## MAINTAIN: Hold current distance and position
func _behavior_maintain(energy_pct: float) -> void:
	if not target or not is_instance_valid(target) or not drone or not is_instance_valid(drone):
		return

	var to_drone = (drone.global_position - target.global_position).normalized()
	var maintain_target = target.global_position + to_drone * optimal_weapon_range

	pathfinding_ai.set_target(maintain_target)

	# Minimal movement when maintaining
	var speed = combat_speed_fraction * 0.3
	pathfinding_ai.set_speed_fraction(speed)

## RETREAT: Back away from target
func _behavior_retreat(energy_pct: float) -> void:
	if not target or not is_instance_valid(target) or not drone or not is_instance_valid(drone):
		return

	var away_from_target = (drone.global_position - target.global_position).normalized()
	var retreat_target = drone.global_position + away_from_target * RETREAT_DISTANCE

	pathfinding_ai.set_target(retreat_target)

	# Full retreat speed
	pathfinding_ai.set_speed_fraction(1.0)

## ENTRY/EXIT
func enter_combat(p_target: Node3D) -> void:
	target = p_target
	time_since_last_los = 0.0

	if weapon_ai and is_instance_valid(weapon_ai) and weapon_ai.has_method("enable_weapons"):
		weapon_ai.enable_weapons(true)

func exit_combat() -> void:
	target = null

	if weapon_ai and is_instance_valid(weapon_ai) and weapon_ai.has_method("enable_weapons"):
		weapon_ai.enable_weapons(false)

## CONFIGURATION
func configure(config: Dictionary) -> void:
	if config.has("optimal_weapon_range"):
		optimal_weapon_range = config.optimal_weapon_range
	if config.has("min_weapon_range"):
		min_weapon_range = config.min_weapon_range
	if config.has("max_weapon_range"):
		max_weapon_range = config.max_weapon_range
	if config.has("combat_speed_fraction"):
		combat_speed_fraction = config.combat_speed_fraction

	_sync_brain_config()

	# Pass weapon-specific configuration to weapon AI
	if weapon_ai and weapon_ai.has_method("configure"):
		weapon_ai.configure(config)


func _sync_brain_config() -> void:
	## Keep the decision brain's ranges in line with this drone's weapon ranges
	combat_brain.optimal_range = optimal_weapon_range
	combat_brain.min_range = min_weapon_range
	combat_brain.max_range = max_weapon_range

## ENERGY MANAGEMENT
func _get_energy_percentage() -> float:
	"""Get current energy as percentage (0-100)"""
	if not energy_system or not is_instance_valid(energy_system):
		return 100.0  # Assume full energy if no system

	if energy_system.has_method("get_energy_percentage"):
		return energy_system.get_energy_percentage()

	# Fallback: calculate manually (with division by zero protection)
	if "current_energy" in energy_system and "max_energy" in energy_system:
		var max_energy = energy_system.max_energy
		if max_energy <= 0.0:
			push_error("[CombatAI] max_energy is zero or negative, defaulting to full energy")
			return 100.0
		return (energy_system.current_energy / max_energy) * 100.0

	return 100.0

func _get_health_percentage() -> float:
	"""Get current health as percentage (0-100)"""
	var health_system = drone.get_node_or_null("HealthSystem") if drone else null
	if not health_system or not is_instance_valid(health_system):
		return 100.0  # Assume full health if no system

	if health_system.has_method("get_health_percentage"):
		return health_system.get_health_percentage()

	# Fallback: calculate manually
	if "current_health" in health_system and "max_health" in health_system:
		var max_health = health_system.max_health
		if max_health <= 0.0:
			return 100.0
		return (health_system.current_health / max_health) * 100.0

	return 100.0  # Default to full energy

func get_energy_state() -> Dictionary:
	"""Get energy state for debugging/display (public API)"""
	var energy_pct = _get_energy_percentage()
	return {
		"percentage": energy_pct,
		"can_fire_weapons": energy_pct >= min_energy_for_weapons,
		"is_critical": energy_pct < critical_energy_threshold
	}
