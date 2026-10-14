## Interface for drone abstraction
##
## This interface allows AI systems to interact with drones without direct dependency
## on RigidBody3D, enabling unit testing with mock drone implementations.
class_name IDrone extends RefCounted

## Gets the current global position of the drone
func get_position() -> Vector3:
	assert(false, "get_position() must be implemented by subclass")
	return Vector3.ZERO

## Gets the current velocity of the drone
func get_velocity() -> Vector3:
	assert(false, "get_velocity() must be implemented by subclass")
	return Vector3.ZERO

## Gets the current forward direction of the drone
func get_forward() -> Vector3:
	assert(false, "get_forward() must be implemented by subclass")
	return Vector3.FORWARD

## Gets the current basis (rotation) of the drone
func get_basis() -> Basis:
	assert(false, "get_basis() must be implemented by subclass")
	return Basis.IDENTITY

## Checks if the drone is still valid (not freed/destroyed)
func is_valid() -> bool:
	assert(false, "is_valid() must be implemented by subclass")
	return false

## Gets the health system component
func get_health_system():
	assert(false, "get_health_system() must be implemented by subclass")
	return null

## Gets the energy system component
func get_energy_system():
	assert(false, "get_energy_system() must be implemented by subclass")
	return null

## Gets the weapon controller component
func get_weapon_controller():
	assert(false, "get_weapon_controller() must be implemented by subclass")
	return null

## Gets the motion controller component
func get_motion_controller():
	assert(false, "get_motion_controller() must be implemented by subclass")
	return null

## Gets the hover physics component
func get_hover_physics():
	assert(false, "get_hover_physics() must be implemented by subclass")
	return null

## Gets the faction ID of the drone
func get_faction_id() -> int:
	assert(false, "get_faction_id() must be implemented by subclass")
	return -1

## Gets the underlying RigidBody3D node (for production code that still needs it)
## This will be phased out as we complete the refactoring
func get_rigid_body() -> RigidBody3D:
	assert(false, "get_rigid_body() must be implemented by subclass")
	return null
