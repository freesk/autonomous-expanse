extends "res://src/weapons/energy_weapon.gd"
class_name EnergyBurstWeapon

## Energy Burst Weapon - Projectile-based burst fire weapon
## Centralized configuration for all energy burst weapons
## All burst weapon stats are defined here - scene files should only attach this class

## ENERGY BURST WEAPON CONFIGURATION - SINGLE SOURCE OF TRUTH
## These values define ALL energy burst weapons in the game

# Core Stats
const BURST_NAME: String = "Energy Burst"
const BURST_DAMAGE: float = 30.0  # Damage per projectile (reduced from 60.0 for balance)
const BURST_FIRE_RATE: float = 0.5  # Shots per second (one every 2 seconds)
const BURST_AVERAGE_DPS: float = BURST_DAMAGE * BURST_FIRE_RATE  # 15 DPS (was 30)

# Burst Properties
const BURST_SIZE: int = 1  # Projectiles per burst
const BURST_DELAY: float = 0.0  # Delay between projectiles in burst

# Range and Accuracy
const BURST_MAX_RANGE: float = 400.0
const BURST_ACCURACY: float = 0.9
const BURST_PROJECTILE_SPEED: float = 150.0  # m/s

# Energy Consumption
const BURST_ENERGY_PER_SHOT: float = 40.0

# Visual Properties
const BURST_COLOR: Color = Color(0.5, 0.8, 1.0, 1.0)  # Blue projectile
const BURST_PROJECTILE_LIFETIME: float = 3.0  # Seconds before despawn

# Physical Properties
const BURST_WEIGHT: float = 15.0


func _ready() -> void:
	# Set energy weapon type
	energy_type = EnergyType.ENERGY_BURST

	# Apply centralized stats
	weapon_name = BURST_NAME
	weapon_type = "energy_burst"
	damage_type = "energy"

	base_damage = BURST_DAMAGE
	fire_rate = BURST_FIRE_RATE
	burst_size = BURST_SIZE
	burst_delay = BURST_DELAY

	max_range = BURST_MAX_RANGE
	accuracy = BURST_ACCURACY
	projectile_speed = BURST_PROJECTILE_SPEED

	energy_cost_per_shot = BURST_ENERGY_PER_SHOT
	energy_cost_per_second = 0.0  # Not used for projectile weapons

	burst_color = BURST_COLOR
	burst_projectile_lifetime = BURST_PROJECTILE_LIFETIME

	weight = BURST_WEIGHT

	# Call parent _ready
	super._ready()

	print("[EnergyBurstWeapon] Initialized: %s | Damage: %.1f | Fire Rate: %.1f | Avg DPS: %.1f" % [
		weapon_name, base_damage, fire_rate, BURST_AVERAGE_DPS
	])


## Get weapon description for UI
func get_weapon_description() -> String:
	return "High-damage energy projectile. Slow fire rate, high impact."


## Get weapon stats for balance tuning reference
static func get_balance_info() -> Dictionary:
	return {
		"name": BURST_NAME,
		"damage_per_shot": BURST_DAMAGE,
		"fire_rate": BURST_FIRE_RATE,
		"average_dps": BURST_AVERAGE_DPS,
		"energy_per_shot": BURST_ENERGY_PER_SHOT,
		"projectile_speed": BURST_PROJECTILE_SPEED,
		"max_range": BURST_MAX_RANGE,
		"accuracy": BURST_ACCURACY,
		"shots_to_kill_140hp": ceil(140.0 / BURST_DAMAGE),  # Shots to kill Explorer drone
		"shots_to_kill_220hp": ceil(220.0 / BURST_DAMAGE),  # Shots to kill Fighter drone
		"ttk_vs_140hp": (ceil(140.0 / BURST_DAMAGE) - 1) / BURST_FIRE_RATE,
		"ttk_vs_220hp": (ceil(220.0 / BURST_DAMAGE) - 1) / BURST_FIRE_RATE
	}
