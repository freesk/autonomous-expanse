extends "res://src/drones/base_drone.gd"
class_name CargoDroneType1

## Cargo Drone Type 1
## Heavy transport drone with large cargo capacity
## Mass: 2000kg, Health: 150, Shields: 80
## Stats from DRONE_SPEC.md

## Health & Energy Stats
const MAX_HEALTH: float = 150.0
const MAX_SHIELDS: float = 80.0
const SHIELD_REGEN_RATE: float = 8.0
const SHIELD_REGEN_DELAY: float = 4.0
const MAX_ENERGY: float = 100.0
const ENERGY_REGEN_RATE: float = 15.0

## Motion Stats
const DRONE_MASS: float = 2000.0
const THRUST_FORCE: float = 45000.0
const STRAFE_FORCE: float = 36000.0
const CLIMB_FORCE: float = 28000.0
const TURN_TORQUE: float = 8500.0
const JUMP_IMPULSE: float = 18000.0
const AIR_DRAG: float = 0.55
const ROTATION_DRAG: float = 2.0
const BOOST_MULTIPLIER: float = 1.5
const BOOST_DURATION: float = 2.5
const BOOST_COOLDOWN: float = 10.0

## AI Configuration - Heavy drone behavior
const AI_DETECTION_RANGE: float = 100.0
const AI_FIELD_OF_VIEW_DEG: float = 90.0  # Limited FOV
const AI_FLEE_HEALTH_THRESHOLD: float = 0.15
const AI_PATROL_SPEED_FRACTION: float = 0.36  # ~10 m/s patrol
const AI_COMBAT_SPEED_FRACTION: float = 0.71  # ~20 m/s combat
const AI_BASE_ACCURACY: float = 0.8  # Slow but accurate
const AI_WEAPON_BURST_RATE: float = 0.5  # Slow burst fire
const AI_OPTIMAL_WEAPON_RANGE: float = 70.0

## Cargo Configuration
const CARGO_CAPACITY: int = 50  # Large cargo capacity for cargo drone

func _ready() -> void:
	# Call parent to find and connect components
	super._ready()

	# Initialize MotionSystem with drone-specific stats
	if motion_system:
		motion_system.initialize({
			"drone_mass": DRONE_MASS,
			"thrust_force": THRUST_FORCE,
			"strafe_force": STRAFE_FORCE,
			"climb_force": CLIMB_FORCE,
			"turn_torque": TURN_TORQUE,
			"jump_impulse": JUMP_IMPULSE,
			"air_drag": AIR_DRAG,
			"rotation_drag": ROTATION_DRAG,
			"boost_multiplier": BOOST_MULTIPLIER,
			"boost_duration": BOOST_DURATION,
			"boost_cooldown": BOOST_COOLDOWN
		})

	# Initialize HealthSystem
	if health_system:
		health_system.initialize({
			"max_health": MAX_HEALTH,
			"max_shields": MAX_SHIELDS,
			"shield_regen_rate": SHIELD_REGEN_RATE,
			"shield_regen_delay": SHIELD_REGEN_DELAY
		})

	# Initialize EnergySystem
	if energy_system:
		energy_system.initialize({
			"max_energy": MAX_ENERGY,
			"energy_regen_rate": ENERGY_REGEN_RATE
		})

	# Initialize CargoSystem
	if cargo_system:
		cargo_system.max_cargo_capacity = CARGO_CAPACITY

	# Setup AI if needed
	setup_ai(
		{
			"field_of_view_deg": AI_FIELD_OF_VIEW_DEG,
			"flee_health_threshold": AI_FLEE_HEALTH_THRESHOLD,
			"patrol_speed_fraction": AI_PATROL_SPEED_FRACTION,
			"combat_speed_fraction": AI_COMBAT_SPEED_FRACTION
		},
		{
			"optimal_weapon_range": AI_OPTIMAL_WEAPON_RANGE,
			"base_accuracy": AI_BASE_ACCURACY,
			"weapon_burst_rate": AI_WEAPON_BURST_RATE,
			"combat_speed_fraction": AI_COMBAT_SPEED_FRACTION
		}
	)
