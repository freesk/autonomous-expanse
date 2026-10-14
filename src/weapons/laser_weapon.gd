extends "res://src/weapons/energy_weapon.gd"
class_name LaserWeapon

## Laser Weapon - Hitscan continuous beam weapon
## Centralized configuration for all laser weapons
## All laser stats are defined here - scene files should only attach this class

## LASER WEAPON CONFIGURATION - SINGLE SOURCE OF TRUTH
## These values define ALL laser weapons in the game

# Core Stats
const LASER_NAME: String = "Light Laser"
const LASER_DAMAGE: float = 6.0 # Damage per hit (reduced from 12.0 for balance)
const LASER_FIRE_RATE: float = 8.0 # Hits per second
const LASER_DPS: float = LASER_DAMAGE * LASER_FIRE_RATE # 48 DPS (was 96)

# Range and Accuracy
const LASER_MAX_RANGE: float = 400.0
const LASER_ACCURACY: float = 0.95

# Energy Consumption
const LASER_ENERGY_PER_SECOND: float = 25.0 # Energy cost while firing (increased to force energy management)

# Visual Properties
const LASER_BEAM_WIDTH: float = 0.05
const LASER_BEAM_DURATION: float = 0.15
const LASER_BEAM_COLOR: Color = Color(1.0, 0.2, 0.2, 1.0) # Red beam

# Physical Properties
const LASER_WEIGHT: float = 8.0


func _ready() -> void:
	# Set energy weapon type
	energy_type = EnergyType.LASER

	# Apply centralized stats
	weapon_name = LASER_NAME
	weapon_type = "laser"
	damage_type = "energy"

	base_damage = LASER_DAMAGE
	fire_rate = LASER_FIRE_RATE
	max_range = LASER_MAX_RANGE
	accuracy = LASER_ACCURACY

	energy_cost_per_shot = 0.0 # Not used for lasers
	energy_cost_per_second = LASER_ENERGY_PER_SECOND

	beam_width = LASER_BEAM_WIDTH
	beam_duration = LASER_BEAM_DURATION
	beam_color = LASER_BEAM_COLOR

	weight = LASER_WEIGHT

	# Projectile speed not used for lasers (instant hit)
	projectile_speed = 0.0

	# Call parent _ready to set up raycast and visuals
	super._ready()

	print("[LaserWeapon] Initialized: %s | Damage: %.1f | Fire Rate: %.1f | DPS: %.1f" % [
		weapon_name, base_damage, fire_rate, LASER_DPS
	])


## Get weapon description for UI
func get_weapon_description() -> String:
	return "Continuous beam laser weapon. High accuracy, instant hit."


## Get weapon stats for balance tuning reference
static func get_balance_info() -> Dictionary:
	return {
		"name": LASER_NAME,
		"damage_per_hit": LASER_DAMAGE,
		"fire_rate": LASER_FIRE_RATE,
		"dps": LASER_DPS,
		"energy_per_second": LASER_ENERGY_PER_SECOND,
		"max_range": LASER_MAX_RANGE,
		"accuracy": LASER_ACCURACY,
		"ttk_vs_140hp": 140.0 / LASER_DPS, # Time to kill Explorer drone
		"ttk_vs_220hp": 220.0 / LASER_DPS # Time to kill Fighter drone
	}
