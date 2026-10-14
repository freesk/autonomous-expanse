extends Node
class_name SquadOrchestratorAI

## SquadOrchestratorAI - Strategic AI Layer
##
## This is the EXECUTION layer that:
## - Detects world state (enemies, cargo, POIs, etc.)
## - Reports events to SquadPriorityManager
## - Executes goals decided by priority manager
## - Commands individual drones and squad subsystems
##
## Decision-making is handled by SquadPriorityManager
## This keeps orchestrator focused on execution, not policy
##
## This is an AI component that controls a Squad entity

# ============================================================================
# PRELOAD DEPENDENCIES
# ============================================================================

const Squad = preload("res://src/squad/squad.gd")

# ============================================================================
# TYPE ALIASES (reference enums from SquadPriorityManager)
# ============================================================================

const AIGoal = SquadPriorityManager.AIGoal
const MoveToTarget = SquadPriorityManager.MoveToTarget

# ============================================================================
# SQUAD ENTITY REFERENCE
# ============================================================================

var squad: Squad = null  # Reference to parent Squad entity

# ============================================================================
# AI SYSTEMS
# ============================================================================

var priority_manager: Node = null  # SquadPriorityManager

# ============================================================================
# EXECUTION STATE
# ============================================================================

var _navigation_commanded: bool = false
var _last_logged_target: Vector3 = Vector3.ZERO

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Get squad reference from parent
	squad = get_parent() as Squad
	if not squad:
		push_error("[SquadOrchestratorAI] Parent must be Squad entity!")
		return

	# Create priority manager
	priority_manager = preload("res://src/ai/squad/squad_priority_manager.gd").new()
	priority_manager.name = "SquadPriorityManager"
	add_child(priority_manager)
	priority_manager.initialize(squad, squad.faction_id, squad.starting_squad_size)

	set_physics_process(true)

	print("[Squad %d] AI INITIALIZED | Faction: %d | Drones: %d | Goal: %s" % [
		squad.squad_id, squad.faction_id, squad.drones.size(), AIGoal.keys()[priority_manager.get_current_goal()]
	])


func _physics_process(delta: float) -> void:
	if not squad or not is_instance_valid(squad):
		return

	if squad.drones.is_empty():
		return  # Squad entity will handle destruction

	# DETECT world state and send events to priority manager
	_update_priorities()

	# EXECUTE current goal
	_execute_current_goal(delta)

	# UPDATE label
	_update_squad_label()


func initialize(p_squad: Squad) -> void:
	squad = p_squad


func on_squad_destroyed() -> void:
	"""Called by Squad entity when it's being destroyed"""
	var targets: Dictionary = priority_manager.get_target_info()
	if targets.poi and is_instance_valid(targets.poi):
		if targets.poi.has_method("stop_harvest"):
			targets.poi.stop_harvest()

# ============================================================================
# PRIORITY DETECTION & EVENT DISPATCH
# ============================================================================

func _update_priorities() -> void:
	# Check for enemies (highest priority)
	var enemies: Array[Squad] = _detect_enemies_in_range()
	var player_nearby: bool = _is_player_nearby()

	if enemies.size() > 0 or player_nearby:
		var should_flee := _should_flee(enemies)
		var transition: Dictionary = priority_manager.on_enemies_detected(enemies, should_flee)
		_apply_transition(transition)
		return

	# Get mining system
	var mining_ai = squad.get_node_or_null("SquadMiningAI")

	# Check cargo full during mining
	if priority_manager.get_current_goal() == AIGoal.GATHER_RESOURCE:
		if mining_ai and mining_ai.has_method("is_squad_cargo_full") and mining_ai.is_squad_cargo_full():
			# Stop mining before transitioning
			if mining_ai.has_method("stop_gathering"):
				mining_ai.stop_gathering()

			var nearest_mothership := _find_nearest_friendly_mothership()
			var assembly_zone := _pick_assembly_zone(nearest_mothership)
			if nearest_mothership:
				nearest_mothership.global_position = assembly_zone.global_position if assembly_zone else nearest_mothership.global_position

			var transition: Dictionary = priority_manager.on_cargo_full(nearest_mothership)
			_apply_transition(transition)
			return

	# Validate current goal is still valid
	var transition: Dictionary = priority_manager.validate_current_goal()
	_apply_transition(transition)

# ============================================================================
# GOAL EXECUTION
# ============================================================================

func _execute_current_goal(delta: float) -> void:
	match priority_manager.get_current_goal():
		AIGoal.MOVE_TO:
			_execute_move_to()
		AIGoal.GATHER_RESOURCE:
			_execute_gather_resource(delta)
		AIGoal.ATTACK:
			_execute_attack(delta)
		AIGoal.RETREAT:
			_execute_retreat()


func _execute_move_to() -> void:
	var target_pos: Vector3 = priority_manager.target_position
	var targets: Dictionary = priority_manager.get_target_info()

	# Ensure we have a valid target
	if priority_manager.get_move_to_target_type() == MoveToTarget.RESOURCE:
		if not targets.poi or not is_instance_valid(targets.poi):
			# Find new POI
			var nearby_poi := _find_nearest_unclaimed_poi()
			if nearby_poi and not nearby_poi.is_depleted():
				priority_manager.target_poi = nearby_poi
				priority_manager.target_position = nearby_poi.global_position
				target_pos = nearby_poi.global_position
				_navigation_commanded = false
			else:
				# No POIs available - patrol near mothership
				var mothership := _find_nearest_friendly_mothership()
				if mothership:
					var angle := randf() * TAU
					var offset := Vector3(cos(angle) * 100.0, 0, sin(angle) * 100.0)
					target_pos = mothership.global_position + offset
					priority_manager.target_position = target_pos
					_navigation_commanded = false

	# Command navigation once
	if not _navigation_commanded:
		_set_squad_target(target_pos)
		_navigation_commanded = true

	# Check if reached destination
	if _reached_destination(target_pos):
		var transition: Dictionary = priority_manager.on_reached_destination()
		_apply_transition(transition)


func _execute_gather_resource(delta: float) -> void:
	var targets: Dictionary = priority_manager.get_target_info()
	var poi: Node3D = targets.poi

	if not poi or not is_instance_valid(poi):
		var transition: Dictionary = priority_manager.on_poi_depleted()
		_apply_transition(transition)
		return

	if poi.is_depleted():
		var transition: Dictionary = priority_manager.on_poi_depleted()
		_apply_transition(transition)
		return

	# Mining is handled by SquadMiningAI
	var mining_ai = squad.get_node_or_null("SquadMiningAI")
	if not mining_ai:
		return

	# Check if mining has started
	if "is_mining" in mining_ai and mining_ai.is_mining:
		return  # Mining in progress

	# Check if squad navigation complete
	var navigation_ai = squad.get_node_or_null("SquadNavigationAI")
	var squad_still_navigating: bool = navigation_ai and navigation_ai.is_navigating if navigation_ai else false

	if squad_still_navigating:
		return

	# Wait for drones to settle
	var avg_velocity := _get_average_squad_velocity()
	if avg_velocity > 2.0:
		return

	# Check if at POI
	var squad_pos_2d := Vector2(squad.global_position.x, squad.global_position.z)
	var poi_pos_2d := Vector2(poi.global_position.x, poi.global_position.z)
	var distance_to_poi: float = squad_pos_2d.distance_to(poi_pos_2d)

	if distance_to_poi > 30.0:
		# Not at POI yet, command navigation
		if not _navigation_commanded:
			_set_squad_target(poi.global_position)
			_navigation_commanded = true
	else:
		# At POI, start mining
		if mining_ai.has_method("start_gathering"):
			mining_ai.start_gathering(poi)


func _execute_attack(delta: float) -> void:
	var targets: Dictionary = priority_manager.get_target_info()
	var enemy_squad: Squad = targets.enemy_squad

	# Check if enemy squad still valid
	if enemy_squad and is_instance_valid(enemy_squad):
		if enemy_squad.drones.is_empty():
			# Enemy destroyed
			var transition: Dictionary = priority_manager.on_enemies_cleared()
			_apply_transition(transition)
			return
		else:
			_engage_enemy(delta, enemy_squad)
			return

	# No squad target - check for player
	if _is_player_nearby():
		_command_drones_to_engage()
	else:
		# No enemies
		var transition: Dictionary = priority_manager.on_enemies_cleared()
		_apply_transition(transition)


func _execute_retreat() -> void:
	var target_pos: Vector3 = priority_manager.target_position

	# Command navigation once
	if not _navigation_commanded:
		_set_squad_target(target_pos)
		_navigation_commanded = true

	# Check if reached safety
	if _reached_destination(target_pos) or _at_mothership():
		var transition: Dictionary = priority_manager.on_enemies_cleared()
		_apply_transition(transition)

# ============================================================================
# BEHAVIOR IMPLEMENTATIONS
# ============================================================================

func _engage_enemy(delta: float, enemy_squad: Squad) -> void:
	if not enemy_squad or not is_instance_valid(enemy_squad):
		return

	var distance: float = squad.global_position.distance_to(enemy_squad.global_position)

	if distance > squad.combat_range:
		if not _navigation_commanded:
			_set_squad_target(enemy_squad.global_position)
			_navigation_commanded = true

	_command_drones_to_engage()


func _command_drones_to_engage() -> void:
	for drone in squad.drones:
		if not is_instance_valid(drone):
			continue

		var orchestrator = drone.get_node_or_null("OrchestratorAI")
		if not orchestrator:
			continue

		var nearest_enemy := _find_nearest_enemy_drone_for(drone)
		if nearest_enemy:
			orchestrator.target = nearest_enemy

# ============================================================================
# TRANSITION APPLICATION
# ============================================================================

func _apply_transition(transition: Dictionary) -> void:
	if not transition.changed:
		return

	# Reset navigation flag on goal change
	_navigation_commanded = false

	# Handle goal entry/exit
	_on_goal_change(transition.goal)


func _on_goal_change(new_goal: AIGoal) -> void:
	var mining_ai = squad.get_node_or_null("SquadMiningAI")
	var targets: Dictionary = priority_manager.get_target_info()

	match new_goal:
		AIGoal.GATHER_RESOURCE:
			# Start mining if we have a POI
			if mining_ai and targets.poi and is_instance_valid(targets.poi):
				if mining_ai.has_method("start_gathering"):
					mining_ai.start_gathering(targets.poi)

		AIGoal.MOVE_TO:
			# Stop mining if leaving GATHER_RESOURCE
			if mining_ai and mining_ai.has_method("stop_gathering"):
				mining_ai.stop_gathering()

		AIGoal.ATTACK:
			# Clear mining state
			if mining_ai and mining_ai.has_method("stop_gathering"):
				mining_ai.stop_gathering()

# ============================================================================
# DETECTION & AWARENESS
# ============================================================================

func _detect_enemies_in_range() -> Array[Squad]:
	var enemies: Array[Squad] = []

	if not FactionManager or not FactionManager.has_method("is_hostile"):
		return enemies

	var all_squads: Array = FactionManager.all_squads

	for other_squad in all_squads:
		if not is_instance_valid(other_squad) or other_squad == squad:
			continue

		if FactionManager.is_hostile(squad.faction_id, other_squad.faction_id):
			if squad.global_position.distance_to(other_squad.global_position) <= squad.detection_radius:
				enemies.append(other_squad)

	return enemies


func _is_player_nearby() -> bool:
	var faction = FactionManager.get_faction(squad.faction_id) if FactionManager else null
	if not faction or not faction.is_hostile_to_player():
		return false

	var player_drone = get_tree().get_first_node_in_group("player")
	if not player_drone or not is_instance_valid(player_drone):
		return false

	return squad.global_position.distance_to(player_drone.global_position) <= squad.detection_radius


func _should_flee(enemies: Array) -> bool:
	var faction = FactionManager.get_faction(squad.faction_id) if FactionManager else null

	# Check squad losses
	if squad.starting_squad_size > 0:
		var size_ratio: float = float(squad.drones.size()) / float(squad.starting_squad_size)
		var flee_threshold: float = faction.run_away_ratio if faction else 0.5
		if size_ratio < flee_threshold:
			return true

	# Check numerical superiority
	var total_enemy_drones: int = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			total_enemy_drones += enemy.drones.size()

	if total_enemy_drones > 0 and squad.drones.size() > 0:
		var our_ratio: float = float(squad.drones.size()) / float(total_enemy_drones)
		var enemy_threshold: float = faction.run_away_vs_enemy if faction else 1.5
		if our_ratio < (1.0 / enemy_threshold):
			return true

	return false


func _find_nearest_enemy_drone_for(our_drone: Node3D) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = INF

	var targets: Dictionary = priority_manager.get_target_info()
	var enemy_squad: Squad = targets.enemy_squad

	if enemy_squad and is_instance_valid(enemy_squad):
		for enemy_drone in enemy_squad.drones:
			if not is_instance_valid(enemy_drone):
				continue

			var dist: float = our_drone.global_position.distance_to(enemy_drone.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy_drone

	# Check for player
	var faction = FactionManager.get_faction(squad.faction_id) if FactionManager else null
	if faction and faction.is_hostile_to_player():
		var player_drone = get_tree().get_first_node_in_group("player")
		if player_drone and is_instance_valid(player_drone):
			var dist: float = our_drone.global_position.distance_to(player_drone.global_position)
			if dist <= squad.detection_radius and dist < nearest_dist:
				nearest = player_drone

	return nearest


func _find_nearest_unclaimed_poi() -> Node3D:
	if not FactionManager:
		return null

	var all_pois: Array = FactionManager.all_pois
	var nearest: Node3D = null
	var nearest_dist: float = INF

	for poi in all_pois:
		if not is_instance_valid(poi) or poi.is_depleted():
			continue

		var dist: float = squad.global_position.distance_to(poi.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = poi

	return nearest


func _find_nearest_friendly_mothership() -> Mothership:
	if not FactionManager or not FactionManager.has_method("get_faction_motherships"):
		return null

	var friendly_motherships: Array = FactionManager.get_faction_motherships(squad.faction_id)
	if friendly_motherships.is_empty():
		return null

	var nearest: Mothership = null
	var nearest_dist: float = INF

	for mothership in friendly_motherships:
		if not is_instance_valid(mothership):
			continue

		var dist: float = squad.global_position.distance_to(mothership.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = mothership

	return nearest


func _pick_assembly_zone(mothership: Mothership) -> Node3D:
	if not mothership or not is_instance_valid(mothership):
		return null

	if not mothership.has_method("get_all_assembly_zones"):
		return null

	var zones: Array = mothership.get_all_assembly_zones()
	if zones.is_empty():
		return null

	return zones[randi() % zones.size()]

# ============================================================================
# NAVIGATION & MOVEMENT
# ============================================================================

func _set_squad_target(target_pos: Vector3) -> void:
	if _last_logged_target.distance_to(target_pos) > 1.0:
		AIDebugLogger.log_decision(AIDebugLogger.squad_entity(squad.squad_id), "SquadNav",
			"navigate_to", AIGoal.keys()[priority_manager.get_current_goal()].to_lower(), {
				"target": target_pos,
				"distance": squad.global_position.distance_to(target_pos)
			})
		_last_logged_target = target_pos

	var navigation_ai = squad.get_node_or_null("SquadNavigationAI")
	if navigation_ai and navigation_ai.has_method("navigate_to"):
		var is_fleeing: bool = (priority_manager.get_current_goal() == AIGoal.RETREAT)
		navigation_ai.navigate_to(target_pos, is_fleeing)


func _reached_destination(target_pos: Vector3) -> bool:
	if target_pos == Vector3.ZERO:
		return false

	var navigation_ai = squad.get_node_or_null("SquadNavigationAI")
	if navigation_ai and navigation_ai.has_method("reached_destination"):
		var threshold: float = 20.0
		return navigation_ai.reached_destination(target_pos, threshold)

	return squad.global_position.distance_to(target_pos) < 20.0


func _at_mothership() -> bool:
	var targets: Dictionary = priority_manager.get_target_info()
	var mothership = targets.mothership

	if not mothership or not is_instance_valid(mothership):
		return false

	return mothership.is_in_landing_zone(squad.global_position)


func _get_average_squad_velocity() -> float:
	var avg_velocity: float = 0.0
	var valid_count: int = 0

	for drone in squad.drones:
		if is_instance_valid(drone) and "linear_velocity" in drone:
			avg_velocity += drone.linear_velocity.length()
			valid_count += 1

	return avg_velocity / float(valid_count) if valid_count > 0 else 0.0

# ============================================================================
# LABEL UPDATE
# ============================================================================

func _update_squad_label() -> void:
	"""Update squad label via Squad entity"""
	var status: String = AIGoal.keys()[priority_manager.get_current_goal()].capitalize()
	squad.update_squad_label(status)
