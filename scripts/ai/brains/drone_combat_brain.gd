class_name DroneCombatBrain extends RefCounted
## Pure logic for drone combat decisions - 100% testable with NO Godot dependencies
##
## This class makes all combat-related decisions based on input parameters.
## It has no awareness of Godot types, nodes, or scenes.

# Configuration
var optimal_range: float = 60.0
var min_range: float = 40.0
var max_range: float = 80.0
var retreat_health_threshold: float = 15.0
var retreat_safe_distance: float = 300.0
var cornered_distance: float = 50.0

# State
enum CombatBehavior {
	CHASE,  ## Move toward target
	STRAFE,  ## Circle around target
	RETREAT_FIRE,  ## Back away while firing
	DISENGAGE  ## Flee without firing
}

## Decide what combat behavior to use based on current state
func decide_combat_behavior(
	has_los: bool,
	distance: float,
	health_pct: float,
	energy: float
) -> CombatBehavior:

	# Disengage if critically low health
	if health_pct < retreat_health_threshold:
		# Unless cornered - then fight to the death
		if distance < cornered_distance:
			return CombatBehavior.RETREAT_FIRE
		return CombatBehavior.DISENGAGE

	# Can't fight effectively without energy
	if energy < 20.0:
		return CombatBehavior.DISENGAGE

	# No LOS = must chase to regain sight
	if not has_los:
		return CombatBehavior.CHASE

	# Too far = chase into range
	if distance > max_range:
		return CombatBehavior.CHASE

	# In optimal range = strafe for mobility
	if distance >= min_range and distance <= max_range:
		return CombatBehavior.STRAFE

	# Too close = back up while firing
	if distance < min_range:
		return CombatBehavior.RETREAT_FIRE

	return CombatBehavior.CHASE

## Calculate movement direction for a given combat behavior
func calculate_combat_movement(
	behavior: CombatBehavior,
	to_target: Vector3,
	forward: Vector3,
	strafe_direction: float  ## -1 to 1, changes over time
) -> Vector2:

	match behavior:
		CombatBehavior.CHASE:
			# Move directly toward target
			var dir_xz = Vector2(to_target.x, to_target.z)
			if dir_xz.length() > 0:
				return dir_xz.normalized()
			return Vector2.ZERO

		CombatBehavior.STRAFE:
			# Circle around target
			var dir_xz = Vector2(to_target.x, to_target.z)
			if dir_xz.length() > 0:
				dir_xz = dir_xz.normalized()
				# Perpendicular vector for strafing
				var perpendicular = Vector2(-dir_xz.y, dir_xz.x) * strafe_direction
				return perpendicular.normalized()
			return Vector2.ZERO

		CombatBehavior.RETREAT_FIRE:
			# Back away from target while maintaining LOS
			var dir_xz = Vector2(to_target.x, to_target.z)
			if dir_xz.length() > 0:
				return -dir_xz.normalized()
			return Vector2.ZERO

		CombatBehavior.DISENGAGE:
			# Flee directly away
			var dir_xz = Vector2(to_target.x, to_target.z)
			if dir_xz.length() > 0:
				return -dir_xz.normalized()
			return Vector2.ZERO

	return Vector2.ZERO

## Determine if weapons should fire given current state
func should_fire_weapons(
	has_los: bool,
	is_aimed: bool,
	energy: float,
	behavior: CombatBehavior
) -> bool:

	# Don't fire when disengaging
	if behavior == CombatBehavior.DISENGAGE:
		return false

	# Need minimum energy to fire
	if energy < 20.0:
		return false

	# Need line of sight
	if not has_los:
		return false

	# Need to be aimed at target
	if not is_aimed:
		return false

	return true

## Calculate aim point with target velocity prediction
func calculate_aim_point(
	target_pos: Vector3,
	target_vel: Vector3,
	projectile_speed: float,
	distance: float
) -> Vector3:

	# Simple linear prediction
	if projectile_speed <= 0:
		return target_pos

	var time_to_impact = distance / projectile_speed
	return target_pos + (target_vel * time_to_impact)

## Should drone retreat to safety?
func should_retreat(health_pct: float, distance_to_safety: float) -> bool:
	return health_pct < retreat_health_threshold

## Has drone reached safety?
func is_safe(health_pct: float, distance_to_threat: float) -> bool:
	# Safe if health recovered
	if health_pct > retreat_health_threshold * 2.0:
		return true

	# Safe if far from threat
	if distance_to_threat > retreat_safe_distance:
		return true

	return false

## Get speed fraction for combat behavior
func get_combat_speed_fraction(behavior: CombatBehavior) -> float:
	match behavior:
		CombatBehavior.CHASE:
			return 1.0  # Full speed pursuit
		CombatBehavior.STRAFE:
			return 0.8  # Slightly slower for accuracy
		CombatBehavior.RETREAT_FIRE:
			return 0.7  # Controlled retreat
		CombatBehavior.DISENGAGE:
			return 1.0  # Full speed flee

	return 0.8
