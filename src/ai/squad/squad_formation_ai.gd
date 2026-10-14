extends Node
class_name SquadFormationSystem

## SquadFormationSystem - Manages drone formation and positioning
## Responsible for:
## - Updating squad center position
## - Maintaining formation shape
## - Cleaning up invalid drones

var squad: Node3D  # Reference to parent DroneSquad


func _ready() -> void:
	squad = get_parent()


## Update squad position to center of drones
func update_squad_center() -> void:
	if not squad or not squad.drones or squad.drones.is_empty():
		return

	var center := Vector3.ZERO
	var valid_count: int = 0

	for drone in squad.drones:
		if is_instance_valid(drone):
			center += drone.global_position
			valid_count += 1

	if valid_count > 0:
		center /= float(valid_count)
		squad.global_position = center


## Calculate formation offset for a drone at specific index
func get_formation_offset(drone_index: int, total_drones: int, spacing: float = 5.0) -> Vector3:
	if total_drones <= 1:
		return Vector3.ZERO

	var angle_step: float = TAU / float(total_drones)
	var angle: float = angle_step * float(drone_index)

	return Vector3(
		cos(angle) * spacing,
		0.0,
		sin(angle) * spacing
	)


## Clean up invalid drone references
func cleanup_invalid_drones() -> int:
	if not squad or not squad.drones:
		return 0

	var removed_count: int = 0
	var to_remove: Array = []

	for drone in squad.drones:
		if not is_instance_valid(drone):
			to_remove.append(drone)

	for drone in to_remove:
		squad.drones.erase(drone)
		removed_count += 1

	return removed_count


## Get average squad health
func get_average_health() -> float:
	if not squad or not squad.drones or squad.drones.is_empty():
		return 0.0

	var total_health: float = 0.0
	var valid_count: int = 0

	for drone in squad.drones:
		if not is_instance_valid(drone):
			continue

		var health_sys = drone.get_node_or_null("HealthSystem")
		if health_sys and health_sys.has_method("get_health_percentage"):
			total_health += health_sys.get_health_percentage()
			valid_count += 1

	if valid_count > 0:
		return total_health / float(valid_count) / 100.0

	return 0.0
