extends Node3D
class_name MockNode3DTarget
## Simple Node3D mock for integration tests

var valid: bool = true
var faction_id: String = "enemy_faction"

func is_valid() -> bool:
	return valid

func get_faction_id() -> String:
	return faction_id
