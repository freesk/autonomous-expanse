class_name DroneWeaponBrain extends RefCounted
## Pure logic for weapon targeting and firing - 100% testable with NO Godot dependencies
##
## This class makes all weapon-related decisions based on input parameters.
## It has no awareness of Godot types, nodes, or scenes.

# Configuration
var aim_tolerance_degrees: float = 5.0
var min_firing_energy: float = 20.0
var burst_fire_duration: float = 0.5
var burst_cooldown_duration: float = 1.0
var accuracy: float = 1.0  # 0.0 to 1.0

# State
var burst_timer: float = 0.0
var cooldown_timer: float = 0.0

## Check if we're aimed at target within tolerance
func is_aimed_at_target(forward: Vector3, to_target: Vector3) -> bool:
	if to_target.length() == 0:
		return false

	var angle = forward.angle_to(to_target)
	var angle_deg = rad_to_deg(angle)
	return angle_deg < aim_tolerance_degrees

## Determine if weapons should fire this frame
func should_fire_this_frame(
	has_los: bool,
	is_aimed: bool,
	energy: float,
	delta: float
) -> bool:

	# Check prerequisites first
	if not has_los:
		return false

	if not is_aimed:
		return false

	if energy < min_firing_energy:
		return false

	# Update cooldown timer (only counts down when burst is not active)
	if cooldown_timer > 0 and burst_timer <= 0:
		cooldown_timer -= delta
		return false  # In cooldown, don't fire

	# Update burst timer
	if burst_timer > 0:
		burst_timer -= delta
		# Still in burst, keep firing
		if burst_timer > 0:
			return true
		else:
			# Burst just ended, start cooldown
			cooldown_timer = burst_cooldown_duration
			return false

	# Not in burst or cooldown - can start new burst
	if burst_timer <= 0 and cooldown_timer <= 0:
		burst_timer = burst_fire_duration
		return true

	return false

## Apply accuracy error to aim point
func apply_accuracy_error(aim_point: Vector3, random_seed: float) -> Vector3:
	if accuracy >= 1.0:
		return aim_point  # Perfect accuracy

	var error_magnitude = (1.0 - accuracy) * 10.0  # Max 10m error

	# Use deterministic random based on seed for testability
	var offset = Vector3(
		_pseudo_random(random_seed) * error_magnitude,
		_pseudo_random(random_seed + 0.33) * error_magnitude,
		_pseudo_random(random_seed + 0.66) * error_magnitude
	)

	return aim_point + offset

## Reset firing timers (e.g., when target changes)
func reset_timers() -> void:
	burst_timer = 0.0
	cooldown_timer = 0.0

## Simple pseudo-random function for testability
## Returns value between -1 and 1
func _pseudo_random(seed_value: float) -> float:
	var x = sin(seed_value * 12.9898) * 43758.5453
	return (x - floor(x)) * 2.0 - 1.0

## Get time until next shot possible
func get_time_until_can_fire() -> float:
	return maxf(cooldown_timer, 0.0)

## Is weapon system on cooldown?
func is_on_cooldown() -> bool:
	return cooldown_timer > 0.0
