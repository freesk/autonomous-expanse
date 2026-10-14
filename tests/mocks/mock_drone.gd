class_name MockDrone extends IDrone
## Mock drone for testing - NO Godot dependencies
##
## Allows setting arbitrary state for testing AI logic

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var forward: Vector3 = Vector3.FORWARD
var health_percentage: float = 100.0
var energy: float = 100.0
var max_speed: float = 60.0
var faction_id: String = "test_faction"
var valid: bool = true

func get_position() -> Vector3:
	return position

func get_velocity() -> Vector3:
	return velocity

func get_forward() -> Vector3:
	return forward

func get_health_percentage() -> float:
	return health_percentage

func get_energy() -> float:
	return energy

func get_max_speed() -> float:
	return max_speed

func get_faction_id() -> String:
	return faction_id

func is_valid() -> bool:
	return valid
