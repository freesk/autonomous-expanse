extends Node
class_name SquadMiningSystem

## SquadMiningSystem - Handles resource gathering and delivery
## Responsible for:
## - Micromanaging drone positions around resource nodes
## - Assigning specific positions to each drone
## - Commanding drones to aim and fire lasers at resource nodes
## - Monitoring individual drone cargo capacity
## - Triggering return trips when squad cargo is full

var squad: Node3D # Reference to parent DroneSquad
var world_generator: Node = null

@export var gather_rate: float = 2.0 # Base resources per second per drone
@export var mining_radius: float = 15.0 # Distance from node for mining positions (increased from 8m for better spacing)
# NO height offset - hover physics maintains 3m altitude automatically!

var current_poi: Node3D = null
var drone_mining_positions: Dictionary = {} # drone -> Vector3 position
var drone_position_commanded: Dictionary = {} # drone -> bool (true if position already commanded)
var drone_resource_buffer: Dictionary = {} # drone -> float (accumulated resources not yet added to cargo)
var is_mining: bool = false


func _ready() -> void:
	squad = get_parent()
	# Cache world generator reference for terrain raycasting
	world_generator = get_tree().root.find_child("WorldGenerator", true, false)


func _process(delta: float) -> void:
	if is_mining and current_poi and is_instance_valid(current_poi):
		_manage_mining_drones(delta)


## Find nearest unclaimed POI with resources
func find_nearest_poi() -> Node3D:
	if not FactionManager:
		return null

	var all_pois: Array = FactionManager.all_pois
	var nearest: Node3D = null
	var nearest_dist: float = INF

	for poi in all_pois:
		if not is_instance_valid(poi):
			continue

		# Check if has resources
		if poi.has_method("is_depleted") and poi.is_depleted():
			continue

		# Check distance
		var dist: float = squad.global_position.distance_to(poi.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = poi

	return nearest


## Start gathering from POI
func start_gathering(poi: Node3D) -> void:
	current_poi = poi
	is_mining = true

	print("[SquadMining:%s] START GATHERING from POI at %v" % [
		squad.name if squad else "Unknown",
		poi.global_position if poi else Vector3.ZERO
	])

	if poi and poi.has_method("start_harvest"):
		poi.start_harvest()

	# Assign mining positions to all drones
	_assign_mining_positions()


## Stop gathering from current POI
func stop_gathering() -> void:
	print("[SquadMining:%s] STOP GATHERING (is_mining=%s, current_poi=%s)" % [
		squad.name if squad else "Unknown",
		is_mining,
		current_poi != null
	])

	is_mining = false

	if current_poi and current_poi.has_method("stop_harvest"):
		current_poi.stop_harvest()

	# Stop all drones from firing AND clear their individual targets
	for drone in squad.drones:
		if not is_instance_valid(drone):
			continue

		# Clear mining metadata
		if drone.has_meta("mining_started"):
			drone.remove_meta("mining_started")

		# Stop firing directly on the drone
		if drone.has_method("set_ai_fire"):
			drone.set_ai_fire(false, false)

		# CRITICAL: Clear drone's pathfinding target so it stops navigating to mining position
		var orchestrator = drone.get_node_or_null("OrchestratorAI")
		if orchestrator:
			var pathfinding = orchestrator.get_node_or_null("PathfindingAI")
			if pathfinding and pathfinding.has_method("clear_target"):
				pathfinding.clear_target()

	current_poi = null
	drone_mining_positions.clear()
	drone_position_commanded.clear()
	drone_resource_buffer.clear()

	print("[SquadMining:%s] STOP GATHERING COMPLETE" % [squad.name if squad else "Unknown"])


## Check if all drones are in their assigned mining positions
func are_all_drones_in_position() -> bool:
	if not squad or not squad.drones or drone_mining_positions.is_empty():
		return false

	var total_drones: int = 0
	var drones_in_position: int = 0

	for drone in squad.drones:
		if not is_instance_valid(drone):
			continue

		var mining_pos: Vector3 = drone_mining_positions.get(drone, Vector3.ZERO)
		if mining_pos == Vector3.ZERO:
			continue

		total_drones += 1
		var distance: float = drone.global_position.distance_to(mining_pos)
		if distance < 20.0:  # Same threshold as _manage_mining_drones
			drones_in_position += 1

	return total_drones > 0 and drones_in_position == total_drones


## Manage mining drones - micromanage positions and firing
func _manage_mining_drones(delta: float) -> void:
	if not squad or not squad.drones:
		return

	for i in range(squad.drones.size()):
		var drone: Node3D = squad.drones[i]
		if not is_instance_valid(drone):
			continue

		# Get assigned mining position
		var mining_pos: Vector3 = drone_mining_positions.get(drone, Vector3.ZERO)
		if mining_pos == Vector3.ZERO:
			continue

		var orchestrator = drone.get_node_or_null("OrchestratorAI")
		if not orchestrator:
			continue

		# Check if drone is in position (increased threshold to 20m due to nav oscillation)
		var distance_to_pos: float = drone.global_position.distance_to(mining_pos)
		var in_position: bool = distance_to_pos < 20.0

		if not in_position:
			# Not in position yet - check if we've already commanded this drone
			var already_commanded: bool = drone_position_commanded.get(drone, false)

			if not already_commanded:
				# Command ONCE to navigate to mining spot
				var pathfinding = orchestrator.pathfinding_ai
				if pathfinding:
					# Force retarget so drones do not keep stale waypoints from prior squad tasks.
					if pathfinding.has_method("set_target"):
						pathfinding.set_target(mining_pos, true)
					pathfinding.speed_fraction = 0.8
					drone_position_commanded[drone] = true # Mark as commanded
					print("[SquadMining:%s] Commanded drone %s to navigate to mining position at %v" % [
						squad.name if squad else "Unknown",
						drone.name,
						mining_pos
					])

			# DEBUG: Monitor progress (read-only, no commanding)
			if Engine.get_process_frames() % 180 == 0:
				var velocity: Vector3 = drone.linear_velocity if "linear_velocity" in drone else Vector3.ZERO
				var speed: float = velocity.length()
				print("[SquadMining:%s] Drone %s moving to mining position | Distance: %.1fm | Speed: %.1fm/s" % [
					squad.name if squad else "Unknown",
					drone.name,
					distance_to_pos,
					speed
				])
		else:
			# In position - STOP navigating and hold position while mining
			_hold_position_and_mine(drone, mining_pos, delta)


## Assign circular positions around resource node
func _assign_mining_positions() -> void:
	drone_mining_positions.clear()

	if not current_poi or not squad or not squad.drones:
		return

	var node_pos: Vector3 = current_poi.global_position

	# All drones in squad can mine (previously filtered to cargo drones only)
	var mining_drones: Array = []
	for drone in squad.drones:
		if is_instance_valid(drone):
			mining_drones.append(drone)

	var mining_drone_count: int = mining_drones.size()

	print("[SquadMining:%s] Assigning mining positions around POI at %v for %d drones" % [
		squad.name if squad else "Unknown",
		node_pos,
		mining_drone_count
	])

	# Assign mining positions to all drones
	for i in range(mining_drone_count):
		var drone = mining_drones[i]
		if not is_instance_valid(drone):
			continue

		# Calculate circular position around node (XZ plane only, ignore Y)
		var angle: float = (TAU / float(mining_drone_count)) * float(i)
		var offset_xz := Vector2(
			cos(angle) * mining_radius,
			sin(angle) * mining_radius
		)

		# Calculate mining position: POI's XZ + circular offset
		var mining_x: float = node_pos.x + offset_xz.x
		var mining_z: float = node_pos.z + offset_xz.y

		# Raycast to find terrain height at THIS drone's specific XZ position
		var mining_y: float = _calculate_terrain_relative_y(mining_x, mining_z)

		var mining_pos := Vector3(mining_x, mining_y, mining_z)

		drone_mining_positions[drone] = mining_pos

		print("[SquadMining:%s]   Drone %s -> Position: %v (POI Y: %.1f, Calculated Y: %.1f)" % [
			squad.name if squad else "Unknown",
			drone.name,
			mining_pos,
			node_pos.y,
			mining_pos.y
		])


## Hold position and mine - stop all movement and fire at resource
func _hold_position_and_mine(drone: Node3D, target_pos: Vector3, delta: float) -> void:
	# Log once when drone first starts mining (use a flag to avoid spam)
	if not drone.has_meta("mining_started"):
		drone.set_meta("mining_started", true)
		print("[SquadMining:%s] Drone %s IN POSITION - Starting to mine at %v" % [
			squad.name if squad else "Unknown",
			drone.name,
			drone.global_position
		])

		# Stop pathfinding updates so hold-position corrections are not overwritten.
		var orchestrator = drone.get_node_or_null("OrchestratorAI")
		if orchestrator and orchestrator.pathfinding_ai and orchestrator.pathfinding_ai.has_method("clear_target"):
			orchestrator.pathfinding_ai.clear_target()

	# Calculate offset from assigned mining position
	var offset_from_position: Vector3 = target_pos - drone.global_position
	var distance_from_assigned: float = offset_from_position.length()

	# If drone drifted more than 3m from assigned position, nudge it back gently
	if distance_from_assigned > 3.0:
		var correction_direction := offset_from_position.normalized()
		var correction_strength: float = min(distance_from_assigned / 10.0, 0.3) # Max 30% correction
		var horizontal_correction := Vector2(correction_direction.x, correction_direction.z) * correction_strength
		var vertical_correction: float = correction_direction.y * correction_strength
		if drone.has_method("set_ai_movement"):
			drone.set_ai_movement(horizontal_correction, vertical_correction)
	else:
		# Close enough to assigned position - hold still
		if drone.has_method("set_ai_movement"):
			drone.set_ai_movement(Vector2.ZERO, 0.0)

	# DON'T directly control drone rotation - let the weapon controller handle aiming
	# The hover physics and pathfinding AI manage drone orientation
	# Only the weapon controller should aim at the target

	# Aim weapons at resource and fire
	_aim_and_fire_at_node(drone, delta)


## Aim at resource node and fire lasers only
func _aim_and_fire_at_node(drone: Node3D, delta: float) -> void:
	# Get drone's cargo system (optional - some drones may not have cargo)
	var cargo_system = drone.get_node_or_null("CargoSystem")
	var has_cargo: bool = cargo_system != null

	# Get weapon controller and set aim target to resource node
	var weapon_controller = drone.get_node_or_null("WeaponController")
	if weapon_controller and weapon_controller.has_method("set_aim_target"):
		weapon_controller.set_aim_target(current_poi.global_position)

	# Command drone to fire primary weapon (lasers) via hover physics AI interface
	var fired: bool = false
	if drone.has_method("set_ai_fire"):
		drone.set_ai_fire(true, false) # Primary only (lasers), no secondary
		fired = true

	# Log firing status periodically
	if Engine.get_process_frames() % 120 == 0: # Every 2 seconds at 60fps
		print("[SquadMining:%s] Drone %s mining at resource | Firing: %s | Has Cargo: %s" % [
			squad.name if squad else "Unknown",
			drone.name,
			"YES" if fired else "NO",
			"YES" if has_cargo else "NO"
		])

	# Gradually fill cargo as lasers fire (if drone has cargo system)
	if has_cargo:
		var resources_mined: float = gather_rate * delta

		# Accumulate resources in buffer
		var current_buffer: float = drone_resource_buffer.get(drone, 0.0)
		current_buffer += resources_mined
		drone_resource_buffer[drone] = current_buffer

		# Add full resource units to cargo when buffer >= 1.0
		while current_buffer >= 1.0:
			var cargo_item := {
				"cargo_type": CargoSystem.CargoType.RESOURCE,
				"name": "Resources",
				"amount": 1,
				"value": 1
			}
			var added: bool = cargo_system.add_cargo(cargo_item)

			if added:
				current_buffer -= 1.0
				drone_resource_buffer[drone] = current_buffer
			else:
				# Cargo full - stop trying to add
				break

		# Log cargo status
		if Engine.get_process_frames() % 120 == 0:
			var cargo_used: float = cargo_system.current_cargo_used if "current_cargo_used" in cargo_system else 0.0
			var cargo_max: float = cargo_system.max_cargo_capacity if "max_cargo_capacity" in cargo_system else 0.0
			var cargo_percent: float = (cargo_used / cargo_max * 100.0) if cargo_max > 0 else 0.0
			var buffer_amount: float = drone_resource_buffer.get(drone, 0.0)
			print("[SquadMining:%s]   → Cargo: %.1f/%.1f (%.0f%%) | Buffer: %.2f" % [
				squad.name if squad else "Unknown",
				cargo_used,
				cargo_max,
				cargo_percent,
				buffer_amount
			])


## Check if at POI
func at_poi() -> bool:
	if not current_poi or not is_instance_valid(current_poi):
		return false
	return squad.global_position.distance_to(current_poi.global_position) < 20.0


## Get average squad cargo capacity (0.0 to 1.0)
func get_squad_cargo_percentage() -> float:
	if not squad or squad.drones.is_empty():
		return 0.0

	var total_capacity: float = 0.0
	var total_used: float = 0.0
	var valid_drones: int = 0

	for drone in squad.drones:
		if not is_instance_valid(drone):
			continue

		var cargo_system = drone.get_node_or_null("CargoSystem")
		if not cargo_system:
			continue

		if "max_cargo_capacity" in cargo_system and "current_cargo_used" in cargo_system:
			total_capacity += cargo_system.max_cargo_capacity
			total_used += cargo_system.current_cargo_used
			valid_drones += 1

	if valid_drones == 0 or total_capacity == 0.0:
		return 0.0

	return total_used / total_capacity


## Check if squad cargo is full (100% average capacity)
func is_squad_cargo_full() -> bool:
	var cargo_pct: float = get_squad_cargo_percentage()
	var is_full: bool = cargo_pct >= 1.0

	if is_full:
		print("[SquadMining:%s] SQUAD CARGO FULL! Average capacity: %.0f%%" % [
			squad.name if squad else "Unknown",
			cargo_pct * 100.0
		])

	return is_full


## Find nearest friendly mothership
func find_nearest_mothership() -> Node3D:
	if not FactionManager or not FactionManager.has_method("get_faction_motherships"):
		return null

	var friendly_motherships: Array = FactionManager.get_faction_motherships(squad.faction_id)
	if friendly_motherships.is_empty():
		return null

	var nearest = null
	var nearest_dist: float = INF

	for mothership in friendly_motherships:
		if not is_instance_valid(mothership):
			continue

		var dist: float = squad.global_position.distance_to(mothership.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = mothership

	return nearest


## Check if at mothership
func at_mothership(mothership: Node3D) -> bool:
	if not mothership or not is_instance_valid(mothership):
		return false

	if mothership.has_method("is_in_landing_zone"):
		return mothership.is_in_landing_zone(squad.global_position)

	return false


## Deliver resources to mothership - unload all drone cargo
func deliver_resources(mothership: Node3D) -> void:
	if not mothership:
		return

	var total_delivered: int = 0

	# Unload cargo from each drone
	for drone in squad.drones:
		if not is_instance_valid(drone):
			continue

		var cargo_system = drone.get_node_or_null("CargoSystem")
		if not cargo_system:
			continue

		# Transfer all cargo to mothership
		if cargo_system.has_method("transfer_all_to_storage"):
			var cargo_items: Array = cargo_system.transfer_all_to_storage()

			# Count total resources delivered
			for item in cargo_items:
				if item.has("amount"):
					total_delivered += item.amount

	# Deliver to mothership
	if total_delivered > 0:
		if mothership.has_method("receive_resources"):
			mothership.receive_resources(total_delivered)

		# Update faction stats
		if FactionManager and FactionManager.has_method("get_faction"):
			var faction = FactionManager.get_faction(squad.faction_id)
			if faction:
				faction.total_resources_collected += total_delivered

		print("[Squad %d] Delivered %d resources to mothership" % [squad.squad_id, total_delivered])


## Check if should return home (cargo full or damaged)
func should_return_home() -> bool:
	# Check if squad cargo is full
	if is_squad_cargo_full():
		return true

	# Check squad health
	if squad.has_method("_get_average_squad_health"):
		var avg_health: float = squad._get_average_squad_health()
		if avg_health < 0.3:
			return true

	# Check squad losses
	if "starting_squad_size" in squad and squad.starting_squad_size > 0:
		var size_ratio: float = float(squad.drones.size()) / float(squad.starting_squad_size)
		if size_ratio < 0.3:
			return true

	return false


## Calculate terrain-relative Y position using vertical raycasting
## Uses raycasting to find terrain height, then adds mining height offset
func _calculate_terrain_relative_y(x: float, z: float) -> float:
	# Use raycasting to get terrain height at this XZ position
	var terrain_height: float = _get_terrain_height_at(x, z)

	# If raycasting failed (returned 0 or very low), use POI's Y as reference
	# The resource node is placed ON terrain, so its Y IS the terrain height
	if terrain_height < 1.0 and current_poi and is_instance_valid(current_poi):
		var poi_y: float = current_poi.global_position.y
		print("[SquadMining] Raycasting failed (height=%.1f), using POI terrain level Y=%.1f as fallback" % [terrain_height, poi_y])
		# Return POI's terrain level - hover physics will add 3m automatically
		return poi_y

	# Return terrain height at drone's XZ - hover physics will add 3m clearance automatically
	return terrain_height


## Get terrain height at position
func _get_terrain_height_at(x: float, z: float) -> float:

	var height: float = world_generator.get_terrain_height_at(x, z)
	return height
