class_name IWeaponSystem extends RefCounted
## Interface for weapon control
##
## Abstracts weapon firing so AI can command weapons without coupling
## to specific weapon implementations.

## Set the target position for weapon aiming
func set_target(target_pos: Vector3) -> void:
	assert(false, "Must implement set_target()")

## Fire weapons
## @param primary: Fire primary weapon
## @param secondary: Fire secondary weapon
func fire(primary: bool = true, secondary: bool = false) -> void:
	assert(false, "Must implement fire()")

## Get optimal range for equipped weapons
func get_optimal_range() -> float:
	assert(false, "Must implement get_optimal_range()")
	return 60.0

## Get projectile speed for lead calculation
func get_projectile_speed() -> float:
	assert(false, "Must implement get_projectile_speed()")
	return 1000.0
