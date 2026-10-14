extends GutTest
## Unit tests for SquadCohesionBrain - pure logic, NO Godot dependencies
##
## Covers the squad speed-matching fix: every squad member must fly at the
## SAME actual speed (the slowest member's max), which requires a per-drone
## throttle fraction, not one shared fraction.

const SquadCohesionBrainScript = preload("res://scripts/ai/brains/squad_cohesion_brain.gd")

# Real fleet physics from src/drones/*_type*.gd (thrust, mass, linear drag)
const FIGHTER1 := {"thrust": 30000.0, "mass": 1200.0, "drag": 0.5}   # 50.0 m/s
const FIGHTER2 := {"thrust": 32000.0, "mass": 900.0, "drag": 0.35}   # ~101.6 m/s
const EXPLORER := {"thrust": 28000.0, "mass": 800.0, "drag": 0.4}    # 87.5 m/s
const CARGO := {"thrust": 45000.0, "mass": 2000.0, "drag": 0.55}     # ~40.9 m/s


func _max_speed(d: Dictionary) -> float:
	return SquadCohesionBrainScript.max_horizontal_speed(d.thrust, d.mass, d.drag)


# ===== max_horizontal_speed =====

func test_max_speed_uses_linear_drag_model():
	# Terminal speed: thrust / (mass * drag). Fighter1: 30000/(1200*0.5)=50
	assert_almost_eq(_max_speed(FIGHTER1), 50.0, 0.001, "Fighter1 max speed")
	assert_almost_eq(_max_speed(CARGO), 40.909, 0.001, "Cargo max speed")

func test_max_speed_accounts_for_mass():
	# Regression: old formula sqrt(thrust/drag) ignored mass, ranking the
	# heavy cargo drone FASTER than fighter1. Correct model ranks it slower.
	assert_lt(_max_speed(CARGO), _max_speed(FIGHTER1),
		"Cargo (heavy) must be slower than Fighter1 despite higher thrust")

func test_max_speed_degenerate_inputs_return_zero():
	assert_eq(SquadCohesionBrainScript.max_horizontal_speed(0.0, 1200.0, 0.5), 0.0, "zero thrust")
	assert_eq(SquadCohesionBrainScript.max_horizontal_speed(30000.0, 0.0, 0.5), 0.0, "zero mass")
	assert_eq(SquadCohesionBrainScript.max_horizontal_speed(30000.0, 1200.0, 0.0), 0.0, "zero drag")
	assert_eq(SquadCohesionBrainScript.max_horizontal_speed(-1.0, 1200.0, 0.5), 0.0, "negative thrust")


# ===== squad_cruise_speed =====

func test_cruise_speed_is_slowest_member():
	var speeds := [_max_speed(FIGHTER1), _max_speed(FIGHTER2), _max_speed(CARGO)]
	assert_almost_eq(SquadCohesionBrainScript.squad_cruise_speed(speeds),
		_max_speed(CARGO), 0.001, "Cruise speed must equal slowest member's max")

func test_cruise_speed_ignores_unknown_speeds():
	# A drone whose physics couldn't be read (0.0) must not drag cruise to 0
	var speeds := [0.0, 50.0, 87.5]
	assert_eq(SquadCohesionBrainScript.squad_cruise_speed(speeds), 50.0,
		"Zero entries (unknown physics) must be ignored")

func test_cruise_speed_empty_or_all_unknown_returns_zero():
	assert_eq(SquadCohesionBrainScript.squad_cruise_speed([]), 0.0, "empty squad")
	assert_eq(SquadCohesionBrainScript.squad_cruise_speed([0.0, 0.0]), 0.0, "all unknown")

func test_cruise_speed_single_drone():
	assert_eq(SquadCohesionBrainScript.squad_cruise_speed([87.5]), 87.5,
		"Single drone cruises at its own max")


# ===== speed_fraction_for =====

func test_slowest_drone_gets_full_throttle():
	var cargo := _max_speed(CARGO)
	assert_almost_eq(SquadCohesionBrainScript.speed_fraction_for(cargo, cargo), 1.0, 0.001,
		"The slowest drone itself must fly at 100%, not be throttled further")

func test_each_drone_gets_its_own_fraction():
	# Regression: old code applied ONE fraction (slowest/fastest) to every
	# drone, so mid-speed drones went SLOWER than the slowest member.
	var cruise := _max_speed(CARGO)
	var f1 := SquadCohesionBrainScript.speed_fraction_for(_max_speed(FIGHTER1), cruise)
	var f2 := SquadCohesionBrainScript.speed_fraction_for(_max_speed(FIGHTER2), cruise)
	var fe := SquadCohesionBrainScript.speed_fraction_for(_max_speed(EXPLORER), cruise)
	assert_ne(f1, f2, "Different drones need different throttle fractions")
	assert_ne(f2, fe, "Different drones need different throttle fractions")

func test_fractions_equalize_actual_speeds_across_mixed_fleet():
	# THE invariant behind the fix: fraction * own_max == shared cruise speed
	var fleet := [FIGHTER1, FIGHTER2, EXPLORER, CARGO]
	var speeds: Array = []
	for d in fleet:
		speeds.append(_max_speed(d))
	var cruise: float = SquadCohesionBrainScript.squad_cruise_speed(speeds)

	for i in fleet.size():
		var fraction: float = SquadCohesionBrainScript.speed_fraction_for(speeds[i], cruise)
		var actual_speed: float = fraction * speeds[i]
		assert_almost_eq(actual_speed, cruise, 0.001,
			"Drone %d actual speed must equal squad cruise speed" % i)

func test_fraction_below_old_clamp_is_allowed():
	# Regression: old clamp(0.5, 1.0) blocked the ~0.40 fraction fighter2
	# needs to match cargo, so it could never slow down enough.
	var fraction := SquadCohesionBrainScript.speed_fraction_for(
		_max_speed(FIGHTER2), _max_speed(CARGO))
	assert_between(fraction, 0.35, 0.45, "Fighter2 must be able to throttle to ~0.40")

func test_fraction_degenerate_inputs_return_full_throttle():
	assert_eq(SquadCohesionBrainScript.speed_fraction_for(0.0, 50.0), 1.0,
		"Unknown own max -> full throttle, don't stall")
	assert_eq(SquadCohesionBrainScript.speed_fraction_for(50.0, 0.0), 1.0,
		"Unknown cruise speed -> full throttle")

func test_fraction_clamped_to_minimum():
	# Extreme mismatch must not throttle a drone to a crawl
	var fraction := SquadCohesionBrainScript.speed_fraction_for(1000.0, 1.0)
	assert_eq(fraction, SquadCohesionBrainScript.MIN_SPEED_FRACTION,
		"Fraction must not go below MIN_SPEED_FRACTION")

func test_fraction_never_exceeds_one():
	# Cruise faster than own max (shouldn't happen, but must not over-throttle)
	assert_eq(SquadCohesionBrainScript.speed_fraction_for(40.0, 50.0), 1.0,
		"Fraction capped at 1.0")


# ===== MotionSystem.get_max_horizontal_speed (glue) =====

func test_motion_system_exposes_max_speed_from_its_config():
	var motion_system: Node = load("res://src/systems/motion_system.gd").new()
	autofree(motion_system)
	motion_system.thrust_force = FIGHTER1.thrust
	motion_system.drone_mass = FIGHTER1.mass
	motion_system.air_drag = FIGHTER1.drag
	assert_almost_eq(motion_system.get_max_horizontal_speed(), 50.0, 0.001,
		"MotionSystem must report terminal speed from its configured physics")

func test_motion_system_reports_zero_before_initialization():
	var motion_system: Node = load("res://src/systems/motion_system.gd").new()
	autofree(motion_system)
	assert_eq(motion_system.get_max_horizontal_speed(), 0.0,
		"Uninitialized physics must read as unknown (0.0)")
