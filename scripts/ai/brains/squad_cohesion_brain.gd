class_name SquadCohesionBrain extends RefCounted
## Pure logic for squad speed cohesion - 100% testable with NO Godot dependencies
##
## A squad maintains formation by having every member fly at the same actual
## speed: the top speed of its slowest member. Because members have different
## physics (thrust, mass, drag), each one needs its OWN throttle fraction to
## hit that shared speed.

## Never throttle a drone below this fraction of its own max speed; keeps the
## squad moving even with extreme fleet mismatches.
const MIN_SPEED_FRACTION: float = 0.1


## Terminal horizontal speed of a hover drone driven by a constant thrust force
## against Godot's linear damping: at equilibrium thrust/mass == speed * drag.
## Returns 0.0 for degenerate physics (unknown — caller must treat as "no data").
static func max_horizontal_speed(thrust_force: float, mass: float, linear_drag: float) -> float:
	if thrust_force <= 0.0 or mass <= 0.0 or linear_drag <= 0.0:
		return 0.0
	return thrust_force / (mass * linear_drag)


## The squad's shared cruise speed: the slowest member's max speed.
## Ignores non-positive entries (drones whose physics we couldn't read).
## Returns 0.0 when no member has a known speed.
static func squad_cruise_speed(max_speeds: Array) -> float:
	var slowest: float = 0.0
	for speed in max_speeds:
		if speed > 0.0 and (slowest == 0.0 or speed < slowest):
			slowest = speed
	return slowest


## Throttle fraction THIS drone needs so its actual speed equals cruise_speed.
## A drone with unknown max speed, or any degenerate input, gets full throttle
## rather than stalling the squad.
static func speed_fraction_for(drone_max_speed: float, cruise_speed: float) -> float:
	if drone_max_speed <= 0.0 or cruise_speed <= 0.0:
		return 1.0
	return clampf(cruise_speed / drone_max_speed, MIN_SPEED_FRACTION, 1.0)
