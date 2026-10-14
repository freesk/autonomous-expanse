## Production implementation of IPhysicsQuery using Godot's physics engine
##
## This class wraps PhysicsDirectSpaceState3D to implement the IPhysicsQuery interface.
## It's used in production code, while MockPhysicsQuery is used for testing.

extends "res://src/ai/interfaces/i_physics_query.gd"

class_name GodotPhysicsQuery

var space_state: PhysicsDirectSpaceState3D

func _init(p_space_state: PhysicsDirectSpaceState3D = null):
	space_state = p_space_state

## Sets the physics space state to use for queries
func set_space_state(p_space_state: PhysicsDirectSpaceState3D) -> void:
	space_state = p_space_state

## Performs a raycast from one point to another
func raycast(from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	if not space_state:
		push_warning("GodotPhysicsQuery: space_state is null, cannot perform raycast")
		return {}

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude

	return space_state.intersect_ray(query)

## Performs a sphere cast from one point to another
func sphere_cast(from: Vector3, to: Vector3, radius: float, exclude: Array) -> Dictionary:
	if not space_state:
		push_warning("GodotPhysicsQuery: space_state is null, cannot perform sphere cast")
		return {}

	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), from)
	query.exclude = exclude

	# Note: This is a simplified version. For full sphere cast along a path,
	# you may need to perform multiple queries or use a different approach
	var results = space_state.intersect_shape(query, 1)
	if results.size() > 0:
		return results[0]
	return {}

## Checks if there is a clear line of sight between two points
func has_line_of_sight(from: Vector3, to: Vector3, exclude: Array) -> bool:
	var result = raycast(from, to, exclude)
	return result.is_empty()

## Helper function to check line of sight to a specific target
## Returns true if the raycast hits the target, false otherwise
func has_line_of_sight_to_target(from: Vector3, target_pos: Vector3, target_object, exclude: Array) -> bool:
	var result = raycast(from, target_pos, exclude)

	if result.is_empty():
		return false

	# Check if we hit the target
	return result.has("collider") and result["collider"] == target_object
