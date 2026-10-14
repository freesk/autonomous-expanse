extends Node

## WorldManager - World state and environmental management
##
## Manages world boundaries, spawn points, and basic zone tracking.
## Autoloaded as a singleton for global access.

signal world_bounds_exited(object: Node3D)
signal environment_changed(environment_name: String)
signal spawn_point_registered(spawn_id: String, position: Vector3)
signal zone_entered(zone_name: String, is_safe: bool)
signal zone_exited(zone_name: String)

const WORLD_BOUNDARY: float = 5000.0  # Maximum distance from origin

var world_bounds: AABB = AABB(Vector3(-WORLD_BOUNDARY, -WORLD_BOUNDARY, -WORLD_BOUNDARY),
							  Vector3(WORLD_BOUNDARY * 2, WORLD_BOUNDARY * 2, WORLD_BOUNDARY * 2))

var spawn_points: Dictionary = {}  # spawn_id -> Vector3
var current_environment: String = "default"
var active_zones: Array[Node3D] = []
var world_root: Node3D = null

# Zone tracking
var current_zone: String = ""
var current_zone_safe: bool = true


func _ready() -> void:
	print("WorldManager initialized")


func set_world_root(root: Node3D) -> void:
	world_root = root
	print("World root set: ", root.name)


func register_spawn_point(spawn_id: String, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	spawn_points[spawn_id] = {
		"position": position,
		"rotation": rotation
	}
	spawn_point_registered.emit(spawn_id, position)


func get_spawn_point(spawn_id: String) -> Dictionary:
	if spawn_points.has(spawn_id):
		return spawn_points[spawn_id]
	else:
		push_warning("Spawn point not found: " + spawn_id)
		return {"position": Vector3.ZERO, "rotation": Vector3.ZERO}


func get_default_spawn() -> Dictionary:
	if spawn_points.has("default"):
		return spawn_points["default"]
	return {"position": Vector3(0, 10, 0), "rotation": Vector3.ZERO}


func is_within_bounds(position: Vector3) -> bool:
	return world_bounds.has_point(position)


func check_bounds(object: Node3D) -> bool:
	if not is_within_bounds(object.global_position):
		world_bounds_exited.emit(object)
		return false
	return true


func clamp_to_bounds(position: Vector3) -> Vector3:
	return Vector3(
		clampf(position.x, world_bounds.position.x, world_bounds.end.x),
		clampf(position.y, world_bounds.position.y, world_bounds.end.y),
		clampf(position.z, world_bounds.position.z, world_bounds.end.z)
	)


func set_environment(environment_name: String) -> void:
	current_environment = environment_name
	environment_changed.emit(environment_name)


func register_zone(zone: Node3D) -> void:
	if not active_zones.has(zone):
		active_zones.append(zone)


func unregister_zone(zone: Node3D) -> void:
	active_zones.erase(zone)


func get_nearest_zone(position: Vector3) -> Node3D:
	if active_zones.is_empty():
		return null

	var nearest: Node3D = null
	var nearest_distance: float = INF

	for zone in active_zones:
		var distance = position.distance_to(zone.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = zone

	return nearest


func enter_zone(zone_name: String, is_safe: bool) -> void:
	if current_zone == zone_name:
		return

	if current_zone != "":
		zone_exited.emit(current_zone)

	current_zone = zone_name
	current_zone_safe = is_safe

	zone_entered.emit(zone_name, is_safe)


func get_current_zone() -> String:
	return current_zone


func is_current_zone_safe() -> bool:
	return current_zone_safe


func reset() -> void:
	spawn_points.clear()
	active_zones.clear()
	current_environment = "default"
	world_root = null
	current_zone = ""
	current_zone_safe = true
