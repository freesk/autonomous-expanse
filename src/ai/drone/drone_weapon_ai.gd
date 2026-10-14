extends Node
# WeaponAI - No class_name to avoid conflicts, use preload instead

## Weapon AI - Controls weapon firing logic
## Handles aiming, accuracy, burst fire patterns
## All drones use energy weapons only (Laser + Energy Burst)
## CRITICAL: This system doesn not manage drone rotation or movement, it can only aim within the allowed contraints defined by the drone poistion and angle

# NEW: Preload testable AI brain
const DroneWeaponBrain = preload("res://scripts/ai/brains/drone_weapon_brain.gd")


## References
var drone: RigidBody3D = null
var target: Node3D = null

## Weapon configuration
const MIN_ENERGY_TO_FIRE: float = 20.0 # Minimum energy required
const PROJECTILE_SPEED: float = 500.0 # Energy burst speed (m/s)

## Weapon state
var weapons_enabled: bool = false
var is_firing_laser: bool = false

## Component references (cached during initialization to avoid repeated lookups)
var weapon_controller: Node = null
var energy_system: Node = null
var motion_controller: Node = null

## Testable AI brain (created eagerly so configure() works before initialize())
var weapon_brain: DroneWeaponBrain = DroneWeaponBrain.new()

func initialize(p_drone: RigidBody3D) -> void:
	if not p_drone or not is_instance_valid(p_drone):
		push_error("[WeaponAI] Invalid drone provided to initialize()")
		return

	drone = p_drone

	# Cache all component references to avoid repeated get_node_or_null calls
	weapon_controller = drone.get_node_or_null("WeaponController")
	energy_system = drone.get_node_or_null("EnergySystem")
	motion_controller = drone.get_node_or_null("MotionController")

	# Drones can only rotate in yaw (hover physics keeps them level), so the
	# aim check is horizontal-only with a wide tolerance (matches legacy
	# REQUIRED_AIM_ACCURACY dot > 0.75 ~= 41 degrees).
	weapon_brain.aim_tolerance_degrees = 41.0

func update_targeting(delta: float, p_target: Node3D, has_line_of_sight: bool) -> void:
	target = p_target

	if not weapons_enabled or not target or not is_instance_valid(target):
		_stop_firing("no_target_or_weapons_disabled")
		return

	if not drone or not is_instance_valid(drone):
		_stop_firing("drone_invalid")
		return

	if not has_line_of_sight:
		_stop_firing("no_line_of_sight")
		return

	# Check if we have energy
	if not _has_enough_energy():
		_stop_firing("insufficient_energy")
		return

	# Calculate aim point with prediction
	var aim_point = _calculate_aim_point()

	# Set weapon aim target through hover physics
	# CRITICAL: This must be set EVERY frame because hover_physics.handle_weapon_firing()
	# could overwrite it if aim_system exists. We set it here to ensure AI aim takes priority.
	var simple_aim = target.global_position if (target and is_instance_valid(target)) else aim_point
	if drone.has_method("set_ai_weapon_target"):
		drone.set_ai_weapon_target(simple_aim)

	# Rotate drone to face target
	_aim_at_target(aim_point, delta)

	# Check if we're aimed close enough to fire
	if _is_aimed_at_target(aim_point):
		_fire_weapons(delta)
	else:
		# Log aiming status occasionally (throttled by the logger)
		var forward = - drone.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		var to_target = (aim_point - drone.global_position)
		to_target.y = 0
		to_target = to_target.normalized()
		AIDebugLogger.log_status(AIDebugLogger.drone_entity(drone), "WeaponAI", "aiming", {
			"required_deg": weapon_brain.aim_tolerance_degrees,
			"current_deg": rad_to_deg(forward.angle_to(to_target))
		}, 3.0)
		_stop_firing("not_aimed_at_target")

## AIM CALCULATION
func _calculate_aim_point() -> Vector3:
	if not target or not is_instance_valid(target):
		return Vector3.ZERO

	if not drone or not is_instance_valid(drone):
		return Vector3.ZERO

	# Simple prediction: lead target based on velocity
	var target_velocity = Vector3.ZERO
	if target is RigidBody3D:
		target_velocity = target.linear_velocity

	var to_target = target.global_position - drone.global_position
	var distance = to_target.length()

	# Predict where target will be
	var time_to_hit = distance / PROJECTILE_SPEED

	var predicted_position = target.global_position + target_velocity * time_to_hit

	# Apply accuracy error via the weapon brain (deterministic per time seed)
	return weapon_brain.apply_accuracy_error(predicted_position, Time.get_ticks_msec() * 0.001)

## AIM AT TARGET
func _aim_at_target(aim_point: Vector3, delta: float) -> void:
	# WeaponAI does NOT manage rotation - that's CombatAI's job
	# This function exists for potential future weapon-specific aiming logic
	# (e.g., turret rotation, gimbal aiming, etc.)
	pass

## CHECK IF AIMED
func _is_aimed_at_target(aim_point: Vector3) -> bool:
	if not drone or not is_instance_valid(drone):
		return false

	# Horizontal-only check: the drone can only rotate in yaw, so comparing
	# full 3D angles would make elevated/lower targets unhittable
	var forward = - drone.global_transform.basis.z
	forward.y = 0
	var to_target = aim_point - drone.global_position
	to_target.y = 0
	return weapon_brain.is_aimed_at_target(forward, to_target)

## FIRE WEAPONS
func _fire_weapons(delta: float) -> void:
	if not weapon_controller or not is_instance_valid(weapon_controller):
		return

	# Use testable DroneWeaponBrain burst fire logic
	var has_los = true  # We're already in firing function, so we have LOS
	var is_aimed = true  # We're already in firing function, so we're aimed
	var energy = _get_energy_percentage()
	var should_fire = weapon_brain.should_fire_this_frame(has_los, is_aimed, energy, delta)

	# Fire both weapons (continuous laser + burst fire secondary)
	_fire_both_weapons(should_fire)

## FIRE BOTH WEAPONS (replaces _fire_laser and _fire_energy_burst)
func _fire_both_weapons(fire_secondary: bool) -> void:
	if not weapon_controller or not is_instance_valid(weapon_controller):
		return

	if not is_firing_laser:
		is_firing_laser = true
		AIDebugLogger.log_decision(AIDebugLogger.drone_entity(drone), "WeaponAI",
			"open_fire", "aimed_with_los_and_energy", {"secondary": fire_secondary})

	# Use cached MotionController reference to fire weapons
	if motion_controller and motion_controller.has_method("set_ai_fire"):
		# Set both weapons in one call - primary always on, secondary when burst ready
		motion_controller.set_ai_fire(true, fire_secondary)
	else:
		# Fallback to direct weapon controller methods
		if weapon_controller.has_method("start_primary_fire"):
			weapon_controller.start_primary_fire()
		elif weapon_controller.has_method("fire_primary"):
			weapon_controller.fire_primary()

		if fire_secondary and weapon_controller.has_method("fire_secondary"):
			weapon_controller.fire_secondary()

## STOP FIRING
func _stop_firing(reason: String = "unspecified") -> void:
	if not is_firing_laser:
		return # Already stopped

	is_firing_laser = false
	AIDebugLogger.log_decision(AIDebugLogger.drone_entity(drone), "WeaponAI",
		"cease_fire", reason)

	# Stop firing through cached MotionController reference
	if motion_controller and motion_controller.has_method("set_ai_fire"):
		motion_controller.set_ai_fire(false, false)
	else:
		# Fallback to weapon controller
		if weapon_controller and weapon_controller.has_method("stop_primary_fire"):
			weapon_controller.stop_primary_fire()

## UTILITY
func _has_enough_energy() -> bool:
	if not energy_system or not is_instance_valid(energy_system):
		return true # Assume yes if no energy system

	if energy_system.has_method("get_current_energy"):
		var energy = energy_system.get_current_energy()
		return energy > MIN_ENERGY_TO_FIRE

	if "current_energy" in energy_system:
		return energy_system.current_energy > MIN_ENERGY_TO_FIRE

	return true

func _get_energy_percentage() -> float:
	"""Get current energy as percentage (0-100)"""
	if not energy_system or not is_instance_valid(energy_system):
		return 100.0  # Assume full energy if no system

	if energy_system.has_method("get_energy_percentage"):
		return energy_system.get_energy_percentage()

	# Fallback: calculate manually
	if "current_energy" in energy_system and "max_energy" in energy_system:
		var max_energy = energy_system.max_energy
		if max_energy <= 0.0:
			return 100.0
		return (energy_system.current_energy / max_energy) * 100.0

	return 100.0

## PUBLIC API
func enable_weapons(enabled: bool) -> void:
	if weapons_enabled != enabled:
		AIDebugLogger.log_decision(AIDebugLogger.drone_entity(drone), "WeaponAI",
			"weapons_enabled" if enabled else "weapons_disabled", "combat_state_change")
	weapons_enabled = enabled

	if not enabled:
		_stop_firing("weapons_disabled")

## CONFIGURATION
func configure(config: Dictionary) -> void:
	if config.has("base_accuracy"):
		weapon_brain.accuracy = config.base_accuracy
	if config.has("weapon_burst_rate"):
		# burst rate (bursts/sec) -> cooldown between bursts
		var rate: float = maxf(0.1, config.weapon_burst_rate)
		weapon_brain.burst_cooldown_duration = maxf(0.1, (1.0 / rate) - weapon_brain.burst_fire_duration)
