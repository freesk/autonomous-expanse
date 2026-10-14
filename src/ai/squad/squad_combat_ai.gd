extends Node
class_name SquadCombatSystem

## SquadCombatSystem - Handles combat detection and engagement
## Responsible for:
## - Enemy detection within range
## - Target assignment to individual drones
## - Flee decision logic
## - Combat engagement coordination

var squad: Node3D  # Reference to parent DroneSquad

@export var detection_radius: float = 200.0  # Increased to allow drones to engage at their detection range
@export var combat_range: float = 100.0  # Increased to match individual drone weapon ranges


func _ready() -> void:
	squad = get_parent()


## Detect enemies in detection radius
func detect_enemies() -> Array:
	var enemies: Array = []

	if not FactionManager or not FactionManager.has_method("is_hostile"):
		return enemies

	# Check for enemy squads
	var all_squads: Array = FactionManager.all_squads

	for other_squad in all_squads:
		if not is_instance_valid(other_squad) or other_squad == squad:
			continue

		# Check if hostile
		if FactionManager.is_hostile(squad.faction_id, other_squad.faction_id):
			# Check distance
			if squad.global_position.distance_to(other_squad.global_position) <= detection_radius:
				enemies.append(other_squad)

	# Check for player (if hostile)
	_detect_player_if_hostile(enemies)

	return enemies


## Detect player as enemy if faction is hostile to player
func _detect_player_if_hostile(enemies: Array) -> void:
	# Find player in the scene
	var player_group = get_tree().get_nodes_in_group("player")
	if player_group.is_empty():
		return

	var player = player_group[0]
	if not is_instance_valid(player):
		return

	# Get faction and check if hostile to player
	var faction = FactionManager.get_faction(squad.faction_id)
	if not faction:
		return

	# Only engage player if faction is hostile to player
	if faction.is_hostile_to_player():
		# Check if player is in range
		if squad.global_position.distance_to(player.global_position) <= detection_radius:
			enemies.append(player)


## Get closest enemy from list
func get_closest_enemy(enemies: Array) -> Node3D:
	if enemies.is_empty():
		return null

	var closest = null
	var closest_dist: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var dist: float = squad.global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	return closest


## Check if squad should flee from enemies
func should_flee(enemies: Array) -> bool:
	if enemies.is_empty():
		return false

	# Get faction flee settings
	var faction = null
	if FactionManager and FactionManager.has_method("get_faction"):
		faction = FactionManager.get_faction(squad.faction_id)

	# Check squad size ratio (lost too many drones)
	if squad.starting_squad_size > 0:
		var size_ratio: float = float(squad.drones.size()) / float(squad.starting_squad_size)
		var flee_threshold: float = faction.run_away_ratio if faction else 0.5

		if size_ratio < flee_threshold:
			return true

	# Check numerical superiority
	var total_enemy_drones: int = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and "drones" in enemy:
			total_enemy_drones += enemy.drones.size()

	if total_enemy_drones > 0 and squad.drones.size() > 0:
		var our_ratio: float = float(squad.drones.size()) / float(total_enemy_drones)
		var enemy_threshold: float = faction.run_away_vs_enemy if faction else 1.5

		if our_ratio < (1.0 / enemy_threshold):
			return true

	return false


## Engage target enemy squad or player
func engage_enemy(target_enemy: Node3D) -> void:
	if not target_enemy or not is_instance_valid(target_enemy):
		return

	# Check if target is the player
	var is_player: bool = target_enemy.is_in_group("player")

	# Command individual drones to engage specific targets
	for drone in squad.drones:
		if not is_instance_valid(drone):
			continue

		var orchestrator = drone.get_node_or_null("OrchestratorAI")
		if not orchestrator:
			continue

		# If target is player, all drones attack the player directly
		if is_player:
			orchestrator.target = target_enemy
		else:
			# Find nearest enemy drone for this drone
			var nearest_enemy: Node3D = _find_nearest_enemy_drone(drone, target_enemy)
			if nearest_enemy:
				# Set target - OrchestratorAI will handle state transitions
				orchestrator.target = nearest_enemy


## Calculate flee direction away from enemies
func calculate_flee_direction(enemies: Array) -> Vector3:
	if enemies.is_empty():
		return squad.global_position

	# Calculate average enemy position
	var enemy_center := Vector3.ZERO
	var valid_count: int = 0

	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy_center += enemy.global_position
			valid_count += 1

	if valid_count > 0:
		enemy_center /= float(valid_count)
		# Flee in opposite direction
		var flee_dir: Vector3 = (squad.global_position - enemy_center).normalized()
		return squad.global_position + flee_dir * 200.0

	return squad.global_position


## Check if reached safety during flee
func reached_safety() -> bool:
	var enemies: Array = detect_enemies()
	if enemies.is_empty():
		return true

	# Need to be outside 1.5x detection range
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var dist: float = squad.global_position.distance_to(enemy.global_position)
		if dist < detection_radius * 1.5:
			return false

	return true


## Find nearest enemy drone for a specific friendly drone
func _find_nearest_enemy_drone(our_drone: Node3D, enemy_squad: Node3D) -> Node3D:
	if not enemy_squad or not "drones" in enemy_squad:
		return null

	var nearest: Node3D = null
	var nearest_dist: float = INF

	for enemy_drone in enemy_squad.drones:
		if not is_instance_valid(enemy_drone):
			continue

		var dist: float = our_drone.global_position.distance_to(enemy_drone.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy_drone

	return nearest
