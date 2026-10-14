class_name MockTargetable extends ITargetable
## Mock targetable for testing - NO Godot dependencies

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var valid: bool = true
var faction_id: String = "enemy_faction"
var radius: float = 1.0

func get_position() -> Vector3:
	return position

func get_velocity() -> Vector3:
	return velocity

func is_valid() -> bool:
	return valid

func get_faction_id() -> String:
	return faction_id

func get_radius() -> float:
	return radius
