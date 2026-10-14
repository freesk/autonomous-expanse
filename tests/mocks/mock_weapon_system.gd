class_name MockWeaponSystem extends IWeaponSystem
## Mock weapon system for testing - NO Godot dependencies
##
## Records weapon commands for verification in tests

var last_target: Vector3 = Vector3.ZERO
var last_fire_primary: bool = false
var last_fire_secondary: bool = false
var fire_count: int = 0
var optimal_range: float = 60.0
var projectile_speed: float = 1000.0

func set_target(target_pos: Vector3) -> void:
	last_target = target_pos

func fire(primary: bool = true, secondary: bool = false) -> void:
	last_fire_primary = primary
	last_fire_secondary = secondary
	fire_count += 1

func get_optimal_range() -> float:
	return optimal_range

func get_projectile_speed() -> float:
	return projectile_speed

func reset() -> void:
	last_target = Vector3.ZERO
	last_fire_primary = false
	last_fire_secondary = false
	fire_count = 0
