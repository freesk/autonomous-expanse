class_name IDrone extends RefCounted
## Interface for drone control and queries
##
## This interface defines all the operations AI can perform on a drone
## without coupling to Godot's RigidBody3D implementation.

## Get current world position
func get_position() -> Vector3:
	assert(false, "Must implement get_position()")
	return Vector3.ZERO

## Get current velocity vector
func get_velocity() -> Vector3:
	assert(false, "Must implement get_velocity()")
	return Vector3.ZERO

## Get forward direction vector (where drone is facing)
func get_forward() -> Vector3:
	assert(false, "Must implement get_forward()")
	return Vector3.FORWARD

## Get current health as percentage (0-100)
func get_health_percentage() -> float:
	assert(false, "Must implement get_health_percentage()")
	return 100.0

## Get current energy level
func get_energy() -> float:
	assert(false, "Must implement get_energy()")
	return 100.0

## Get maximum speed this drone can achieve
func get_max_speed() -> float:
	assert(false, "Must implement get_max_speed()")
	return 60.0

## Get faction ID for this drone
func get_faction_id() -> String:
	assert(false, "Must implement get_faction_id()")
	return ""

## Check if this drone is still valid (not destroyed/freed)
func is_valid() -> bool:
	assert(false, "Must implement is_valid()")
	return true
